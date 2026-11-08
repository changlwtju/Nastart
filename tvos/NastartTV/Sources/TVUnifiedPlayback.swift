import SwiftUI
import AVKit
import Combine
import KSPlayer
import NetworkMedia
import CryptoKit

/// Source adapters provide locations and server hooks; they never choose a decoder.
@MainActor struct TVPlaybackSourceAdapter {
    struct Resource {
        let url: URL
        let origin: URL?
        let kind: PlaybackSourceKind
        let identity: String
        var start: Double = 0
        var duration: Double? = nil
        var bytes: Int64? = nil
        var resumeKey: String? = nil
        var serverRoute: TVPlaybackRoute? = nil
        var report: ((String, Double, Bool) async -> Void)? = nil
        var release: (() async -> Void)? = nil
    }
    let title: String
    let load: () async throws -> Resource
    var compatibility: ((Double) async throws -> Resource)? = nil
    var tracks: ((TVSourceSelection, Double) async throws -> Resource)? = nil

    static func file(client: TVDSMClient, file: TVNASFile) -> Self {
        let value = Data((client.server.absoluteString + "|" + (client.account?.user ?? "") + "|" + file.path).utf8)
        let bookmark = "tv.playback.resume." + SHA256.hash(data: value).map { String(format: "%02x", $0) }.joined()
        let key = LocalPlaybackResumeStore.key(server: client.server, account: client.account?.user ?? "",
            path: file.path, byteLength: file.additional?.size,
            modifiedAt: file.additional?.time?.mtime.map(Date.init(timeIntervalSince1970:)))
        return Self(title: file.name, load: {
            let saved = LocalPlaybackResumeStore.shared.entry(for: key)
            return Resource(url: try client.mediaURL(path: file.path), origin: client.server,
                kind: .dsmFile, identity: file.path,
                start: saved?.positionSeconds ?? max(0, UserDefaults.standard.double(forKey: bookmark)),
                duration: saved?.durationSeconds, bytes: file.additional?.size, resumeKey: key)
        })
    }

    static func network(_ source: NetworkMediaPlaybackSource) -> Self {
        let key = "network-file:" + source.stableID
        return Self(title: source.title, load: {
            let saved = LocalPlaybackResumeStore.shared.entry(for: key)
            return Resource(url: source.playbackURL, origin: source.originURL,
                kind: .webDAVFile, identity: source.stableID,
                start: saved?.positionSeconds ?? 0, duration: saved?.durationSeconds,
                bytes: source.byteCount, resumeKey: key)
        })
    }

    static func jellyfin(client: TVJellyfinClient, item: TVMediaItem, resume: Bool) -> Self {
        func resource(_ route: TVPlaybackRoute, start: Double) -> Resource {
            Resource(url: route.url, origin: client.server, kind: .jellyfin, identity: item.Id,
                start: start, duration: item.RunTimeTicks.map { Double($0) / 10_000_000 },
                serverRoute: route,
                report: { event, seconds, paused in
                    try? await client.report(event, itemID: item.Id, route: route, seconds: seconds, paused: paused)
                }, release: {
                    if let id = route.playSessionID { try? await client.stopEncoding(id) }
                })
        }
        return Self(title: item.Name, load: {
            let start = resume ? item.resumeSeconds : 0
            do { return resource(try await client.prepare(item.Id, isAudio: item.isAudio, originalStream: true), start: start) }
            catch is CancellationError { throw CancellationError() }
            catch { return resource(try await client.prepare(item.Id, isAudio: item.isAudio), start: start) }
        }, compatibility: { seconds in
            resource(try await client.prepare(item.Id, isAudio: item.isAudio), start: seconds)
        }, tracks: { selection, seconds in
            resource(try await client.prepare(item.Id, isAudio: item.isAudio, selection: selection), start: seconds)
        })
    }
}

/// The TV adapter uses the exact mobile planning/coordinator sources. The two
/// renderers below only translate platform controls; no entry-specific policy lives here.
@MainActor final class TVUnifiedPlaybackSession: ObservableObject {
    @Published private(set) var plan: PlaybackPlan?
    @Published private(set) var loading = true
    @Published private(set) var error: String?
    @Published private(set) var switching = false
    let controls = TVUnifiedPlaybackControls()
    private let source: TVPlaybackSourceAdapter
    private let lifetime = PlaybackSessionLifetime<TVPlaybackSourceAdapter.Resource> { item in
        await item.release?()
    }
    private var resource: TVPlaybackSourceAdapter.Resource? { lifetime.current }
    private var core: PlaybackSessionCoordinator?
    private var stopped = false
    private var usedCompatibility = false
    private var replacement: Task<Void, Never>?
    private var timer: AnyCancellable?
    private var reportTask: Task<Void, Never>?
    private var lastReport = -Double.infinity
    private var lastResumeSave = -Double.infinity
    private var reportedStart = false
    private var status: NSKeyValueObservation?
    init(source: TVPlaybackSourceAdapter) { self.source = source }

    func prepare() async {
        guard !stopped, let ticket = lifetime.beginInitial() else { return }
        do {
            let next = try await source.load()
            try await install(next, ticket: ticket)
        } catch {
            guard lifetime.fail(ticket), !stopped, !Task.isCancelled else { return }
            self.error = "无法准备播放，请返回后重试。"; loading = false
        }
    }

    private func install(_ next: TVPlaybackSourceAdapter.Resource,
                         ticket: PlaybackSessionLifetime<TVPlaybackSourceAdapter.Resource>.Ticket,
                         handoff: PlaybackHandoffBoundary? = nil) async throws {
        guard lifetime.isCurrent(ticket), !Task.isCancelled,
              handoff?.allowsReplacement(seekGeneration: controls.seekGeneration) != false else {
            await lifetime.discard(next); throw CancellationError()
        }
        let connection = PlaybackConnectionContext.make(url: next.origin)
        let intent = PlaybackIntent(sourceKind: next.kind,
            itemIdentity: PlaybackItemIdentity(sourceKind: next.kind, stablePath: next.identity),
            displayTitle: source.title, directURL: next.url, preferredStartTime: next.start,
            connectionContext: connection,
            networkContext: PlaybackNetworkContext(networkClass: .unknown))
        let resolver = URLPlaybackSourceResolver(sourceKind: next.kind, originURL: next.origin, fileExtensionHint: next.url.pathExtension,
            byteLength: next.bytes, duration: next.duration)
        let coordinator = PlaybackSessionCoordinator(resolver: resolver)
        let prepared: PlaybackSessionStartupResult
        do { prepared = try await coordinator.prepare(intent) }
        catch { await lifetime.discard(next); throw error }
        guard !stopped, !Task.isCancelled, lifetime.isCurrent(ticket),
              handoff?.allowsReplacement(seekGeneration: controls.seekGeneration) != false else {
            await lifetime.discard(next); throw CancellationError()
        }
        let old = resource
        let runtime = old == nil ? nil : controls.snapshot
        if let old {
            saveProgress(old, force: true)
        }
        let retiring = retireCurrent()
        controls.stop(); status = nil
        guard lifetime.commit(next, for: ticket, retiring: retiring) else {
            await lifetime.discard(next); throw CancellationError()
        }
        core = coordinator; plan = prepared.plan
        loading = true; error = nil; reportedStart = false; lastReport = -Double.infinity
        reportTask = nil
        controls.configure(prepared.plan, sourceRoute: next.serverRoute, restoring: runtime)
        controls.onFailure = { [weak self] in self?.fallback() }
        controls.onReady = { [weak self] in self?.loading = false }
        controls.av.onSelectSource = { [weak self] selection in self?.select(selection) }
        if let player = controls.player, let item = player.currentItem {
            status = item.observe(\.status, options: [.initial, .new]) { [weak self, weak player] item, _ in
                Task { @MainActor [weak self, weak player] in
                    guard let self, let player, !self.stopped, self.lifetime.isCurrent(ticket),
                          self.controls.player === player else { return }
                    if item.status == .failed { self.fallback() }
                    else if item.status == .readyToPlay {
                        if next.start > 0 {
                            let done = await player.seek(to: CMTime(seconds: next.start, preferredTimescale: 600),
                                toleranceBefore: .zero, toleranceAfter: .zero)
                            guard done, !self.stopped, self.lifetime.isCurrent(ticket) else { return }
                        }
                        self.controls.av.restorePlaybackIntent(); self.loading = false
                    }
                }
            }
        }
        if timer == nil {
            timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.sample() }
            }
        }
    }

    private func sample() {
        guard !stopped, resource != nil else { return }
        if controls.seconds > (plan?.timeline.startTime ?? 0) { loading = false }
        guard !loading else { return }
        if !reportedStart { reportedStart = true; report("Playing") }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastReport >= 10 { lastReport = now; report("Playing/Progress") }
        if let resource { saveProgress(resource) }
    }
    private func saveProgress(_ resource: TVPlaybackSourceAdapter.Resource, force: Bool = false) {
        guard let key = resource.resumeKey, !loading else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastResumeSave >= 5 else { return }
        lastResumeSave = now
        _ = LocalPlaybackResumeStore.shared.save(key: key, position: controls.seconds,
            duration: controls.duration, audioTrackID: controls.selectedAudio >= 0 ? controls.selectedAudio : nil,
            subtitleTrackID: controls.selectedSubtitle >= 0 ? controls.selectedSubtitle : nil,
            subtitlesDisabled: controls.selectedSubtitle < 0)
    }
    private func report(_ event: String) {
        guard let resource else { return }
        let previous = reportTask, seconds = controls.seconds, paused = !controls.playing
        reportTask = Task { await previous?.value; await resource.report?(event, seconds, paused) }
    }
    private func fallback() {
        guard !stopped, !usedCompatibility, let load = source.compatibility else {
            error = "播放失败，请返回后重试。"; loading = false; return
        }
        usedCompatibility = true
        replace { [controls] in try await load(controls.seconds) }
    }
    private func select(_ selection: TVSourceSelection) {
        guard let load = source.tracks, !stopped else { return }
        replace { [controls] in try await load(selection, controls.seconds) }
    }
    private func replace(_ load: @escaping () async throws -> TVPlaybackSourceAdapter.Resource) {
        guard let ticket = lifetime.beginReplacement() else { return }
        let handoff = PlaybackHandoffBoundary(seekGeneration: controls.seekGeneration)
        replacement?.cancel(); switching = true
        replacement = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.lifetime.isCurrent(ticket) || !self.lifetime.hasPendingOperation {
                    self.switching = false
                }
            }
            do {
                guard handoff.allowsReplacement(seekGeneration: self.controls.seekGeneration) else {
                    self.lifetime.fail(ticket); return
                }
                let next = try await load()
                try await self.install(next, ticket: ticket, handoff: handoff)
            } catch {
                guard self.lifetime.fail(ticket), !Task.isCancelled, !self.stopped else { return }
                guard !(error is CancellationError) else { return }
                self.error = "切换未完成，请返回后重试。"
            }
        }
    }
    /// Capture the outgoing route and clock before detaching its renderer.
    /// The shared lifetime serializes this barrier before source release.
    private func retireCurrent() -> @MainActor (TVPlaybackSourceAdapter.Resource) async -> Void {
        let previous = reportTask, seconds = controls.seconds, started = reportedStart
        let coordinator = core, oldPlan = plan
        return { old in
            await previous?.value
            if started { await old.report?("Playing/Stopped", seconds, true) }
            if let coordinator, let oldPlan { await coordinator.finishPlayback(plan: oldPlan) }
        }
    }
    func stop() {
        guard !stopped else { return }
        stopped = true
        replacement?.cancel(); replacement = nil
        timer?.cancel(); timer = nil; status = nil
        if let resource { saveProgress(resource, force: true) }
        let retiring = retireCurrent()
        controls.stop()
        lifetime.close(retiring: retiring)
        reportTask = nil; core = nil; plan = nil; switching = false
    }
}

@MainActor final class TVUnifiedPlaybackControls: ObservableObject, TVPlaybackControlling {
    let ks = TVKSPlaybackControls()
    let av = TVPlayerControlsModel()
    let options = KSOptions()
    private(set) var player: AVPlayer?
    private(set) var engine = PlaybackEngineCandidate.ksPlayer
    var onFailure: (() -> Void)?
    var onReady: (() -> Void)?
    struct Snapshot {
        let playing: Bool
        let muted: Bool
        let rate: Float
        let fillsScreen: Bool
    }
    var snapshot: Snapshot { Snapshot(playing: playing, muted: muted, rate: rate, fillsScreen: fillsScreen) }
    private var subscriptions = Set<AnyCancellable>()
    init() {
        ks.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        av.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
    }
    private var active: any TVPlaybackControlling { engine == .ksPlayer ? ks : av }
    var seconds: Double { active.seconds }
    var duration: Double { active.duration }
    var playing: Bool { active.playing }
    var muted: Bool { active.muted }
    var rate: Float { active.rate }
    var audio: [TVPlayerControlsModel.Track] { active.audio }
    var subtitles: [TVPlayerControlsModel.Track] { active.subtitles }
    var selectedAudio: Int { active.selectedAudio }
    var selectedSubtitle: Int { active.selectedSubtitle }
    var seekGeneration: Int { active.seekGeneration }
    var canDisableSubtitles: Bool { active.canDisableSubtitles }
    var fillsScreen: Bool {
        get { active.fillsScreen }
        set { if engine == .ksPlayer { ks.fillsScreen = newValue } else { av.fillsScreen = newValue } }
    }
    func configure(_ plan: PlaybackPlan, sourceRoute: TVPlaybackRoute?, restoring snapshot: Snapshot? = nil) {
        engine = plan.enginePolicy
        if engine == .ksPlayer {
            PlaybackKSOptionsPolicy.apply(plan, to: options)
            options.startPlayTime = plan.timeline.startTime
            options.startPlayRate = snapshot?.rate ?? plan.intent.playbackRate
            ks.restoreIntent(playing: snapshot?.playing ?? true, muted: snapshot?.muted ?? false,
                rate: snapshot?.rate ?? plan.intent.playbackRate, fillsScreen: snapshot?.fillsScreen ?? false)
            ks.onReady = { [weak self] in self?.onReady?() }
            ks.coordinator.onFinish = { [weak self] _, failure in
                if failure != nil { self?.onFailure?() }
            }
            ks.start()
        } else {
            let next = AVPlayer(playerItem: AVPlayerItem(url: plan.primaryRoute.url))
            next.defaultRate = plan.intent.playbackRate
            player = next; av.sourceRoute = sourceRoute
            av.attach(next, restoring: TVPlayerControlsModel.RuntimeSnapshot(seconds: plan.timeline.startTime,
                wantsPlayback: false, rate: snapshot?.rate ?? plan.intent.playbackRate,
                muted: snapshot?.muted ?? false, revision: 0))
            av.setPlaybackIntent(snapshot?.playing ?? true)
            av.fillsScreen = snapshot?.fillsScreen ?? false
        }
        objectWillChange.send()
    }
    func stop() {
        ks.stop(); player?.pause(); player?.replaceCurrentItem(with: nil)
        av.onSelectSource = nil; av.detach(); player = nil; onFailure = nil; onReady = nil
    }
    func toggle() { active.toggle() }
    func toggleMute() { active.toggleMute() }
    func seek(delta: Double) { active.seek(delta: delta) }
    func restart() { active.restart() }
    func setRate(_ rate: Float) { active.setRate(rate) }
    func selectAudio(_ index: Int) { active.selectAudio(index) }
    func selectSubtitle(_ index: Int) { active.selectSubtitle(index) }
}

struct TVUnifiedPlaybackView: View {
    let title: String
    let close: () -> Void
    @StateObject private var session: TVUnifiedPlaybackSession
    @State private var closing = false
    init(source: TVPlaybackSourceAdapter, close: @escaping () -> Void) {
        title = source.title; self.close = close
        _session = StateObject(wrappedValue: TVUnifiedPlaybackSession(source: source))
    }
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let plan = session.plan {
                TVPlaybackPresentation(title: title, info: "", controls: session.controls, finish: finish) { fillsScreen in
                    Group {
                        if plan.enginePolicy == .ksPlayer {
                            KSVideoPlayerSurface(coordinator: session.controls.ks.coordinator,
                                url: plan.primaryRoute.url, options: session.controls.options)
                                .allowsHitTesting(false)
                                .onChange(of: fillsScreen) { session.controls.ks.coordinator.isScaleAspectFill = $0 }
                        } else if let player = session.controls.player {
                            TVAVVideoSurface(player: player, fillsScreen: fillsScreen)
                        }
                    }
                }
            }
            if session.loading { ProgressView("正在准备播放").padding(30).background(.black.opacity(0.8)).cornerRadius(16) }
            if session.switching { VStack { Text("正在切换音轨或字幕…").padding(18).background(.black.opacity(0.8)); Spacer() }.padding(.top, 90) }
            if let error = session.error {
                VStack(spacing: 24) { Text(error); Button("返回", action: finish) }.padding(40).background(.black.opacity(0.9))
            }
        }.foregroundStyle(.white).environment(\.colorScheme, .dark)
            .task { await session.prepare() }
            .onExitCommand(perform: finish)
            .onDisappear { session.stop() }
    }
    private func finish() {
        guard !closing else { return }; closing = true; session.stop(); close()
    }
}
