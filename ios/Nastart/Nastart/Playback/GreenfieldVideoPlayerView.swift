import SwiftUI
import AVFoundation
import AVKit
#if canImport(KSPlayer)
import KSPlayer
#endif

struct GreenfieldPlaybackLaunchRequest: Identifiable {
    let id: UUID
    let intent: PlaybackIntent
    let orientationMode: PlayerOrientationMode
    let playbackTraceID: String?
    let fileExtensionHint: String?
    let mimeHint: String?
    let certificatePolicy: PlaybackCertificatePolicy
    let alternateRoutes: [PlaybackRoute]
    let byteLength: Int64?
    let duration: TimeInterval?
    let estimatedBitrate: Int?
    let tracks: TrackCatalog
    let subtitles: SubtitlePlan?
    let mediaRequest: MediaPlaybackRequest?

    init(
        id: UUID = UUID(),
        intent: PlaybackIntent,
        orientationMode: PlayerOrientationMode = .landscape,
        playbackTraceID: String? = nil,
        fileExtensionHint: String? = nil,
        mimeHint: String? = nil,
        certificatePolicy: PlaybackCertificatePolicy = .systemTrust,
        alternateRoutes: [PlaybackRoute] = [],
        byteLength: Int64? = nil,
        duration: TimeInterval? = nil,
        estimatedBitrate: Int? = nil,
        tracks: TrackCatalog = TrackCatalog(),
        subtitles: SubtitlePlan? = nil,
        mediaRequest: MediaPlaybackRequest? = nil
    ) {
        self.id = id
        self.intent = intent
        self.orientationMode = orientationMode
        self.playbackTraceID = playbackTraceID?.isEmpty == false ? playbackTraceID : nil
        self.fileExtensionHint = fileExtensionHint
        self.mimeHint = mimeHint
        self.certificatePolicy = certificatePolicy
        self.alternateRoutes = alternateRoutes
        self.byteLength = byteLength
        self.duration = duration
        self.estimatedBitrate = estimatedBitrate
        self.tracks = tracks
        self.subtitles = subtitles
        self.mediaRequest = mediaRequest
    }
}

struct GreenfieldKSPlayerRuntimeSnapshot {
    let playbackState: String
    let loadState: String
    let isReadyToPlay: Bool
    let isPlaying: Bool
    let isSeekable: Bool
    let currentSeconds: TimeInterval
    let durationSeconds: TimeInterval
    let playableSeconds: TimeInterval
    let bytesRead: Int64?
    let audioBitrate: Int?
    let videoBitrate: Int?
    let displayFPS: Double?

    var diagnostics: [String: String] {
        var metrics = [
            "ksPlaybackState": playbackState,
            "ksLoadState": loadState,
            "ksReady": isReadyToPlay ? "yes" : "no",
            "ksPlaying": isPlaying ? "yes" : "no",
            "ksSeekable": isSeekable ? "yes" : "no",
            "ksCurrentSeconds": Self.format(currentSeconds),
            "ksDurationSeconds": Self.format(durationSeconds),
            "ksPlayableSeconds": Self.format(playableSeconds)
        ]
        if let bytesRead {
            metrics["ksBytesRead"] = "\(bytesRead)"
        }
        if let audioBitrate {
            metrics["ksAudioBitrate"] = "\(audioBitrate)"
        }
        if let videoBitrate {
            metrics["ksVideoBitrate"] = "\(videoBitrate)"
        }
        if let displayFPS {
            metrics["ksDisplayFPS"] = Self.format(displayFPS)
        }
        return metrics
    }

    private static func format(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "-" }
        return String(format: "%.3f", value)
    }
}

struct GreenfieldVideoPlayerView: View {
    @State private var request: GreenfieldPlaybackLaunchRequest
    private let closePresentation: (() -> Void)?
    private let minimizePresentation: (() -> Void)?
    private let restorePresentation: ((@escaping (Bool) -> Void) -> Void)?
    init(request: GreenfieldPlaybackLaunchRequest,
         closePresentation: (() -> Void)? = nil,
         minimizePresentation: (() -> Void)? = nil,
         restorePresentation: ((@escaping (Bool) -> Void) -> Void)? = nil) {
        self.closePresentation = closePresentation
        self.minimizePresentation = minimizePresentation
        self.restorePresentation = restorePresentation
        _request = State(initialValue: request)
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastLocalProgressSave = Date.distantPast
    @StateObject private var model = GreenfieldVideoPlayerModel()
    @StateObject private var ksControls = GreenfieldPlaybackControls()
    @StateObject private var avControls = GreenfieldPlaybackControls()
    private var controls: GreenfieldPlaybackControls { usesKSPlayer ? ksControls : avControls }
    #if canImport(KSPlayer)
    @State private var preparedKSCoordinator: KSVideoPlayer.Coordinator?
    #endif
    @State private var replacementRequest: GreenfieldPlaybackLaunchRequest?
    @State private var didInitializeSession = false
    @State private var episodeNavigation: MediaPlaybackEpisodeNavigation?
    @State private var changingSource = false
    @State private var sourceLoadTask: Task<Void, Never>?
    @State private var pendingSourceChange: (() -> Void)?
    @State private var sourceChangeWasPlaying = false
    @State private var sourceChangeFailed = false
    @State private var handoffRequest: MediaPlaybackRequest?
    private var activeRequest: GreenfieldPlaybackLaunchRequest { replacementRequest ?? request }
    private var uiRequest: MediaPlaybackRequest {
        activeRequest.mediaRequest ?? MediaPlaybackRequest(url: activeRequest.intent.directURL ?? URL(fileURLWithPath: "/"),
            title: activeRequest.intent.displayTitle, initialOrientationMode: activeRequest.orientationMode)
    }


    var presentationOrientation: PlayerOrientationMode { activeRequest.orientationMode }

    private var usesKSPlayer: Bool {
        model.renderingPlan?.enginePolicy == .ksPlayer && PlaybackEngineAvailability.ksPlayerLinked
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let plan = model.renderingPlan,
               plan.enginePolicy == .ksPlayer,
               PlaybackEngineAvailability.ksPlayerLinked {
                SharedBuiltInPlayerView(request: uiRequest, session: ksControls,
                    close: { closePlayer() },
                    useSystemPlayer: { _, _ in controls.pictureInPictureAction?() },
                    compatibilityFailed: { _ in },
                    sourceTrackChange: sourceTrackCallback,
                    serverSeek: serverSeekCallback,
                    qualityChange: nil,
                    previousEpisode: episodeNavigation?.previous.map { loader in { replaceSource(preservePausedState: false, loader) } },
                    nextEpisode: episodeNavigation?.next.map { loader in { replaceSource(preservePausedState: false, loader) } },
                    openExternal: { handoffRequest = uiRequest }) {
                GreenfieldKSPlayerRenderer(
                    plan: plan,
                    controls: ksControls,
                    onUnsupported: model.handleKSPlayerRendererUnsupported,
                    onStateChanged: model.handleKSPlayerStateChanged,
                    onPlaybackTime: model.handleKSPlayerPlaybackTime,
                    onFinished: model.handleKSPlayerFinished,
                    onBufferChanged: model.handleKSPlayerBufferChanged,
                    preparedCoordinator: preparedKSCoordinator
                )
                .id(plan.primaryRoute.id)
                }
                .id(plan.id)
            } else if let plan = model.renderingPlan {
                SharedBuiltInPlayerView(request: uiRequest, session: avControls,
                    close: { closePlayer() },
                    useSystemPlayer: { _, _ in avControls.pictureInPictureAction?() },
                    compatibilityFailed: { _ in },
                    sourceTrackChange: sourceTrackCallback,
                    serverSeek: serverSeekCallback,
                    qualityChange: nil,
                    previousEpisode: episodeNavigation?.previous.map { loader in { replaceSource(preservePausedState: false, loader) } },
                    nextEpisode: episodeNavigation?.next.map { loader in { replaceSource(preservePausedState: false, loader) } },
                    openExternal: { handoffRequest = uiRequest }) {
                    GreenfieldAVPlayerSurface(player: model.player, controls: avControls)
                        .ignoresSafeArea()
                }
            }

            if let errorMessage = model.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                    Text("player.load_failed")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                    Button("action.done") {
                        closePlayer()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                }
                .foregroundStyle(.white)
                .padding(22)
            } else if model.isPreparing || changingSource {
                ProgressView()
                    .tint(.white)
                    .padding(14)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            }


        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle(activeRequest.intent.displayTitle.isEmpty ? "player.title" : activeRequest.intent.displayTitle)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
#endif
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.done") {
                    closePlayer()
                }
            }
#else
            ToolbarItem(placement: .cancellationAction) {
                Button("action.done") {
                    closePlayer()
                }
            }
#endif
        }
        .alert("jellyfin.player.prepare_failed", isPresented: $sourceChangeFailed) {
            Button("action.ok", role: .cancel) {}
        }
        .alert("player.picture_in_picture", isPresented: Binding(get: { controls.pictureInPictureUnavailable }, set: { controls.pictureInPictureUnavailable = $0 })) {
            Button("action.done", role: .cancel) {}
        } message: { Text("player.picture_in_picture_unavailable") }
        .sheet(item: $handoffRequest) { request in
            SharedPlaybackExternalPicker(request: request)
        }
        .task(id: uiRequest.id) {
            episodeNavigation = nil
            let navigation = await uiRequest.episodeNavigationLoader?()
            guard !Task.isCancelled else { return }
            episodeNavigation = navigation
        }
        .onChange(of: controls.currentSeconds) { _ in saveLocalProgress() }
        .onChange(of: scenePhase) { phase in
            if phase != .active { saveLocalProgress(force: true) }
        }
        .onAppear {
            PlayerOrientationController.setPlayerActive(
                true,
                initialMode: request.orientationMode
            )
            guard !didInitializeSession else { return }
            didInitializeSession = true
            for control in [ksControls, avControls] {
                control.pipDidStart = minimizePresentation
                control.pipRestore = restorePresentation
                control.pipDidClose = { [weak model, closePresentation] in
                    model?.stop()
                    closePresentation?()
                }
            }
            ksControls.onTimelineDiscontinuity = model.resetContinuity
            avControls.onTimelineDiscontinuity = model.resetContinuity
            ksControls.pipInitialExternalSubtitleURL = uiRequest.prefersSubtitlesDisabled ? nil : uiRequest.externalSubtitleURL
            ksControls.pipExternalSubtitle.setURL(uiRequest.prefersSubtitlesDisabled ? nil : uiRequest.externalSubtitleURL)
            ksControls.traceID = activeRequest.playbackTraceID
            avControls.traceID = activeRequest.playbackTraceID
            model.avControls = avControls
            model.start(activeRequest)
        }
        .onDisappear {
            guard !ksControls.isPictureInPictureActive && !avControls.isPictureInPictureActive else { return }
            sourceLoadTask?.cancel()
            saveLocalProgress(force: true)
            model.stop(finalPositionSeconds: controls.currentSeconds)
            PlayerOrientationController.setPlayerActive(false)
        }
    }
    private func saveLocalProgress(force: Bool = false) {
        guard uiRequest.source == .dsmFile, let key = uiRequest.localResumeKey,
              controls.isReady, !controls.hasPendingSeek,
              force || Date().timeIntervalSince(lastLocalProgressSave) >= 15 else { return }
        let state = controls.runtimeState(orientationMode: uiRequest.initialOrientationMode)
        LocalPlaybackResumeStore.shared.save(key: key, position: controls.preciseCurrentSeconds,
            duration: controls.durationSeconds,
            audioTrackID: controls.selectedAudioTrackID >= 0 ? Int(controls.selectedAudioTrackID) : nil,
            subtitleTrackID: controls.selectedSubtitleTrackID >= 0 ? Int(controls.selectedSubtitleTrackID) : nil,
            subtitlesDisabled: state.subtitlesDisabled && !controls.pipExternalSubtitle.isEnabled)
        lastLocalProgressSave = Date()
    }

    private func closePlayer() {
        saveLocalProgress(force: true)
        sourceLoadTask?.cancel()
        model.stop(finalPositionSeconds: controls.currentSeconds)
        for control in [ksControls, avControls] {
            control.pipDidStart = nil
            control.pipDidClose = nil
            control.pipRestore = nil
        }
        if let closePresentation { closePresentation() } else { dismiss() }
    }
    private var sourceTrackCallback: ((Int?, Int?, MediaPlaybackRuntimeState) -> Void)? {
        guard let loader = uiRequest.sourceTrackRequestLoader else { return nil }
        return { audio, subtitle, state in
            let externalURL = uiRequest.sourceSubtitleTracks.first { $0.id == subtitle }?.externalURL
            if usesKSPlayer, model.renderingPlan?.primaryRoute.playMethod == .directPlay,
               audio == nil || controls.audioTracks.contains(where: { Int($0.id) == audio }),
               subtitle == nil || externalURL != nil || controls.subtitleTracks.contains(where: { Int($0.id) == subtitle }) {
                if let audio, let track = controls.audioTracks.first(where: { Int($0.id) == audio }) {
                    controls.selectAudio(track)
                }
                controls.selectSourceSubtitle(subtitle.flatMap(Int32.init), externalURL: externalURL)
                controls.sourceRuntimeTracks = (
                    uiRequest.sourceAudioTracks.firstIndex { $0.id == audio },
                    uiRequest.sourceSubtitleTracks.firstIndex { $0.id == subtitle },
                    subtitle == nil
                )
            } else { replaceSource { await loader(audio, subtitle, state) } }
        }
    }
    private var serverSeekCallback: ((Double, MediaPlaybackRuntimeState) -> Void)? {
        guard let loader = uiRequest.serverSeekRequestLoader else { return nil }
        return { seconds, state in replaceSource { await loader(seconds, state) } }
    }
    // Manual quality changes are deferred until server preparation and handoff
    // meet the playback acceptance criteria. Automatic route/fallback stays active.
    private func replaceSource(preservePausedState: Bool = true, keepPlayingDuringPreparation: Bool = false,
                               playbackWasPlaying: Bool? = nil, _ load: @escaping () async -> MediaPlaybackRequest?) {
#if DEBUG
        guard !changingSource else {
            // Finish/clean up the current candidate, then apply the most recent
            // user selection. Dropping this request leaves the menu ahead of the
            // actual audio/subtitle stream after repeated taps.
            let wasPlaying = sourceChangeWasPlaying
            pendingSourceChange = {
                replaceSource(preservePausedState: preservePausedState,
                              keepPlayingDuringPreparation: keepPlayingDuringPreparation,
                              playbackWasPlaying: wasPlaying, load)
            }
            return
        }
        changingSource = true
        let oldControls = controls
        let wasPlaying = playbackWasPlaying ?? oldControls.isPlaying
        sourceChangeWasPlaying = wasPlaying
        let wasPaused = preservePausedState && !wasPlaying
        if !keepPlayingDuringPreparation { oldControls.pauseForExternalHandoff() }
        sourceLoadTask = Task { @MainActor in
            var committed = false
            defer {
                changingSource = false
                if !committed && wasPlaying && !keepPlayingDuringPreparation && !Task.isCancelled { oldControls.togglePlayback() }
                let pending = pendingSourceChange
                pendingSourceChange = nil
                if !Task.isCancelled { pending?() }
            }
            let loaded = await load()
            guard var next = loaded else { sourceChangeFailed = true; return }
            defer {
                if !committed { next.playbackTracker?.releasePreparedResources() }
            }
            guard !Task.isCancelled, pendingSourceChange == nil else { return }
            let preparedPlayer: AVPlayer?
            if next.fileExtensionHint == "m3u8" {
                oldControls.event("replacement_warmup_started")
                preparedPlayer = await GreenfieldAVPlayerWarmup.prepare(next,
                    liveClock: keepPlayingDuringPreparation ? { oldControls.preciseCurrentSeconds } : nil,
                    isPlaying: { keepPlayingDuringPreparation && oldControls.isPlaying },
                    report: { stage, metrics in oldControls.event("replacement_" + stage, metrics: metrics) })
                guard !Task.isCancelled else { return }
                guard preparedPlayer != nil else { sourceChangeFailed = true; return }
                oldControls.event("replacement_warmup_completed")
            } else { preparedPlayer = nil }
            let commitPaused = keepPlayingDuringPreparation ? !oldControls.isPlaying : wasPaused
            if keepPlayingDuringPreparation {
                next = next.applyingRuntimePreferences(oldControls.runtimeState(orientationMode: uiRequest.initialOrientationMode))
            }
            let launch = next.greenfieldPlaybackLaunchRequest(playbackModePreference: activeRequest.intent.playbackModePreference)
            let preparedSession: GreenfieldVideoPlayerModel.PreparedSession
            do { preparedSession = try await GreenfieldVideoPlayerModel.prepareSession(launch) }
            catch { sourceChangeFailed = true; return }
            guard !Task.isCancelled else { return }
#if canImport(KSPlayer)
            var nextKSCoordinator: KSVideoPlayer.Coordinator?
            if preparedSession.result.plan.enginePolicy == .ksPlayer {
                oldControls.event("replacement_warmup_started", metrics: ["candidateEngine": "KSPlayer"])
                nextKSCoordinator = await GreenfieldKSPlayerRenderer.prepareReplacement(
                    plan: preparedSession.result.plan, controls: ksControls,
                    liveClock: { keepPlayingDuringPreparation ? oldControls.preciseCurrentSeconds : preparedSession.result.plan.timeline.startTime },
                    isPlaying: { keepPlayingDuringPreparation && oldControls.isPlaying },
                    report: { stage, metrics in oldControls.event("replacement_" + stage, metrics: metrics) })
                guard !Task.isCancelled else { nextKSCoordinator?.resetPlayer(); return }
                guard nextKSCoordinator != nil else { sourceChangeFailed = true; return }
            }
#endif
            guard pendingSourceChange == nil else {
#if canImport(KSPlayer)
                nextKSCoordinator?.resetPlayer()
#endif
                return
            }
            oldControls.event("replacement_committed", metrics: ["seconds": String(oldControls.currentSeconds),
                "candidateSeconds": String(preparedPlayer?.currentTime().seconds ?? -1)])
            let finalPaused = keepPlayingDuringPreparation ? !oldControls.isPlaying : commitPaused
            oldControls.pauseForExternalHandoff()
            model.stop(reportStop: activeRequest.mediaRequest?.playbackTracker !== next.playbackTracker)
            ksControls.startsPaused = finalPaused
            avControls.startsPaused = finalPaused
            ksControls.traceID = launch.playbackTraceID
            avControls.traceID = launch.playbackTraceID
            ksControls.pipInitialExternalSubtitleURL = next.externalSubtitleURL
            ksControls.pipExternalSubtitle.setURL(next.externalSubtitleURL)
#if canImport(KSPlayer)
            preparedKSCoordinator = nextKSCoordinator
#endif
            replacementRequest = launch
            model.start(launch, preparedPlayer: preparedPlayer, preparedSession: preparedSession)
            committed = true
        }
#endif
    }

}

@MainActor
final class GreenfieldVideoPlayerModel: ObservableObject {
    @Published private(set) var player = AVPlayer()
    private var preparedPlayer: AVPlayer?
    weak var avControls: GreenfieldPlaybackControls?
    private var avWantsPlayback = true
    private var avInitialSeekPending = false
    private var avInitialSeekCompleted = false
    private var avItemWasPrewarmed = false
    private var avTimelineOffset: Double {
        // Jellyfin VOD HLS exposes the full media timeline. StartTimeTicks is
        // the requested position, not a new zero for the returned playlist.
        // Keep the request's start position, but seek AVPlayer to that position
        // and report its absolute clock without adding the position again.
        if request?.intent.sourceKind == .jellyfin,
           request?.fileExtensionHint?.lowercased() == "m3u8" { return 0 }
        return request?.mediaRequest?.timelineOffsetSeconds ?? 0
    }

    @Published private(set) var isPreparing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var debugBadge = "Greenfield"
    @Published private(set) var renderingPlan: PlaybackPlan?

    private var request: GreenfieldPlaybackLaunchRequest?
    private var coordinator: PlaybackSessionCoordinator?
    private var recorder: PlaybackDiagnosticsRecorder?
    private var periodicTimeObserver: Any?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
#if DEBUG
    private var avFrameOutput: AVPlayerItemVideoOutput?
    private var avFrameProbeTask: Task<Void, Never>?
#endif
    private var telemetrySampler: PlaybackTelemetrySampler?
    private var didRecordFirstFrame = false
    private var didRecordThirtySecondCheckpoint = false
    private var continuitySample: (seconds: Double, uptime: Double)?
    private var continuousWallSeconds = 0.0
    func resetContinuity() { continuitySample = nil; continuousWallSeconds = 0 }
    private var lastTimeControlStatus: AVPlayer.TimeControlStatus?
    private var playbackTask: Task<Void, Never>?
    private var failedRouteIDs = Set<UUID>()
    private var lastValidKSPlayerTime: (current: TimeInterval, total: TimeInterval?)?
    private var lastKSPlayerState: String?
    private var didRecordInvalidKSPlayerTime = false

    struct PreparedSession {
        let recorder: PlaybackDiagnosticsRecorder
        let coordinator: PlaybackSessionCoordinator
        let result: PlaybackSessionStartupResult
    }

    static func prepareSession(_ request: GreenfieldPlaybackLaunchRequest) async throws -> PreparedSession {
        let recorder = PlaybackDiagnosticsRecorder(playbackTraceID: request.playbackTraceID)
        let resolver = URLPlaybackSourceResolver(
            sourceKind: request.intent.sourceKind,
            fileExtensionHint: request.fileExtensionHint,
            mimeHint: request.mimeHint,
            certificatePolicy: request.certificatePolicy,
            byteLength: request.byteLength,
            duration: request.duration,
            estimatedBitrate: request.estimatedBitrate,
            tracks: request.tracks,
            subtitles: request.subtitles,
            alternateRoutes: request.alternateRoutes
        )
        let coordinator = PlaybackSessionCoordinator(
            resolver: resolver,
            diagnostics: recorder
        )
        let result = try await coordinator.prepare(request.intent)
        return PreparedSession(recorder: recorder, coordinator: coordinator, result: result)
    }

    func start(_ request: GreenfieldPlaybackLaunchRequest, preparedPlayer: AVPlayer? = nil,
               preparedSession: PreparedSession? = nil) {
        guard playbackTask == nil else { return }
        self.preparedPlayer = preparedPlayer
        self.request = request
        isPreparing = true
        errorMessage = nil
        debugBadge = "Greenfield preparing"
        do {
            // AVPlayer does not configure this itself. A public NAS may start
            // directly in AVPlayer without ever creating the KS renderer.
            try GreenfieldPlaybackAudioSession.activate()
            let audio = AVAudioSession.sharedInstance()
            avControls?.event("audio_session_ready", metrics: [
                "category": audio.category.rawValue, "mode": audio.mode.rawValue,
                "outputVolume": String(audio.outputVolume),
                "outputs": audio.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
            ])
        } catch {
            avControls?.event("audio_session_failed", metrics: ["error": error.localizedDescription])
        }

        if let preparedSession {
            // Publish the ready replacement in the same UI transaction as stop;
            // do not render an intermediate empty/loading surface.
            installPreparedSession(preparedSession)
            playbackTask = Task {}
            return
        }
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                let prepared = try await Self.prepareSession(request)
                guard !Task.isCancelled else { return }
                self.installPreparedSession(prepared)
            } catch {
                guard !Task.isCancelled else { return }
                self.isPreparing = false
                self.errorMessage = error.localizedDescription
                self.debugBadge = "Greenfield failed"
            }
        }
    }

    private func installPreparedSession(_ prepared: PreparedSession) {
        recorder = prepared.recorder
        coordinator = prepared.coordinator
        let result = prepared.result
        renderingPlan = result.plan
        if requiresLinkedKSPlayer(for: result.plan) {
            handleRequiredKSPlayerMissing(result.plan)
        } else if shouldUseKSPlayerRenderer(for: result.plan) {
            player.replaceCurrentItem(with: nil)
            installTelemetrySampler(for: result.plan, engineName: "KSPlayer")
            telemetrySampler?.sampleKSPlayer(state: "rendererSelected", reason: "planReady", force: true)
        } else { installPlayerItem(for: result.plan) }
        isPreparing = false
        recordPlanReady(result)
    }

    func stop(reportStop: Bool = true, finalPositionSeconds: Double? = nil) {
        if reportStop {
            request?.mediaRequest?.playbackTracker?.stopped(failed: errorMessage != nil,
                                                         positionSeconds: finalPositionSeconds)
        }
        playbackTask?.cancel()
        playbackTask = nil
        player.pause()
        if let periodicTimeObserver {
            player.removeTimeObserver(periodicTimeObserver)
            self.periodicTimeObserver = nil
        }
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        telemetrySampler?.stop(reason: "viewDisappear")
        telemetrySampler = nil
        if let coordinator, let renderingPlan {
            Task {
                await coordinator.finishPlayback(plan: renderingPlan)
            }
        }
        player.replaceCurrentItem(with: nil)
#if DEBUG
        avFrameProbeTask?.cancel()
        avFrameProbeTask = nil
        avFrameOutput = nil
#endif
        avControls?.disconnect()
        avInitialSeekPending = false
        renderingPlan = nil
        failedRouteIDs.removeAll()
        lastValidKSPlayerTime = nil
        lastKSPlayerState = nil
        didRecordInvalidKSPlayerTime = false
        didRecordFirstFrame = false
        didRecordThirtySecondCheckpoint = false
        resetContinuity()
        lastTimeControlStatus = nil
    }

    func handleKSPlayerRendererUnsupported() {
        guard let renderingPlan else { return }
        debugBadge = fallbackBadge(for: renderingPlan, reason: "unsupported")
        installPlayerItem(for: renderingPlan)
    }

    func handleKSPlayerStateChanged(_ state: String) {
        guard let plan = renderingPlan else { return }
        lastKSPlayerState = state
        if state == "paused" || state == "buffering" { resetContinuity() }
        debugBadge = [
            "Greenfield",
            "KSPlayer \(state)",
            plan.primaryRoute.routeKind.rawValue,
            plan.intent.connectionContext.addressKind.rawValue
        ].joined(separator: " / ")
        telemetrySampler?.sampleKSPlayer(
            state: state,
            reason: "stateChanged",
            force: state == "error"
        )
        let recorder = recorder
        Task {
            await recorder?.record(
                state == "error" ? .playbackFailed : .engineReady,
                plan: plan,
                engineName: "KSPlayer",
                metrics: ["state": state]
            )
        }
        if state == "error" {
            if activateAlternateRoute(after: plan, reason: "ksPlayerStateError") {
                return
            }
            errorMessage = NSLocalizedString("player.load_failed", comment: "")
        }
    }

    func handleKSPlayerPlaybackTime(_ currentTime: TimeInterval, _ totalTime: TimeInterval) {
        guard let plan = renderingPlan else { return }
        guard let playbackTime = sanitizedKSPlayerTime(
            currentTime: currentTime,
            totalTime: totalTime,
            plan: plan
        ) else {
            if !didRecordInvalidKSPlayerTime {
                didRecordInvalidKSPlayerTime = true
                telemetrySampler?.sampleKSPlayer(
                    state: "invalidTime",
                    reason: "invalidPlaybackTime",
                    force: true
                )
                let recorder = recorder
                let lastState = lastKSPlayerState ?? "-"
                Task {
                    await recorder?.record(
                        .engineReady,
                        plan: plan,
                        engineName: "KSPlayer",
                        metrics: [
                            "state": "invalidPlaybackTime",
                            "currentSecondsRaw": Self.formatDiagnosticSeconds(currentTime),
                            "durationSecondsRaw": Self.formatDiagnosticSeconds(totalTime),
                            "lastState": lastState
                        ]
                    )
                }
            }
            return
        }
        if isSyntheticKSPlayerFinishTime(playbackTime, plan: plan) {
            telemetrySampler?.sampleKSPlayer(
                state: "finishTimeBeforeFirstFrame",
                reason: "syntheticFinishTime",
                force: true
            )
            let recorder = recorder
            Task {
                await recorder?.record(
                    .engineReady,
                    plan: plan,
                    engineName: "KSPlayer",
                    metrics: [
                        "state": "syntheticFinishTime",
                        "currentSeconds": Self.formatDiagnosticSeconds(playbackTime.current),
                        "durationSeconds": Self.formatDiagnosticSeconds(playbackTime.total),
                        "lastState": lastKSPlayerState ?? "-"
                    ]
                )
            }
            return
        }

        lastValidKSPlayerTime = playbackTime
        handlePlaybackTime(playbackTime.current)
        telemetrySampler?.sampleKSPlayer(
            currentTime: playbackTime.current,
            totalTime: playbackTime.total,
            reason: "playbackTick"
        )
        if let duration = playbackTime.total, duration > 0, plan.timeline.duration == nil {
            let recorder = recorder
            Task {
                await recorder?.record(
                    .bufferUpdated,
                    plan: plan,
                    engineName: "KSPlayer",
                    metrics: [
                        "currentSeconds": String(format: "%.1f", playbackTime.current),
                        "durationSeconds": String(format: "%.1f", duration)
                    ]
                )
            }
        }
    }

    func handleKSPlayerFinished(
        _ errorDescription: String?,
        snapshot: GreenfieldKSPlayerRuntimeSnapshot?
    ) {
        guard let plan = renderingPlan else { return }
        let isPrematureEnd = errorDescription == nil && isKSPlayerPrematureEnd(plan: plan)
        let finishState: String
        if isPrematureEnd {
            finishState = "prematureFinished"
        } else if errorDescription == nil {
            finishState = "finished"
        } else {
            finishState = "finishedWithError"
        }
        telemetrySampler?.sampleKSPlayer(
            state: finishState,
            reason: "finished",
            force: true
        )
        if let errorDescription {
            if activateAlternateRoute(after: plan, reason: "ksPlayerFinished") {
                return
            }
            errorMessage = errorDescription
            debugBadge = "KSPlayer failed"
            recordPlayerFailure(
                plan: plan,
                error: nil,
                stage: "ksPlayerFinished:\(errorDescription)",
                snapshot: snapshot
            )
            return
        }
        if isPrematureEnd {
            let stage = didRecordFirstFrame
                ? "ksPlayerPrematureEnd"
                : "ksPlayerFinishedBeforeFirstFrame"
            recordKSPlayerPlaybackEnded(
                plan: plan,
                stage: stage,
                premature: true,
                snapshot: snapshot
            )
            if activateAlternateRoute(after: plan, reason: stage) {
                return
            }
            errorMessage = NSLocalizedString("player.load_failed", comment: "")
            debugBadge = "KSPlayer ended early"
            recordPlayerFailure(plan: plan, error: nil, stage: stage, snapshot: snapshot)
            return
        }
        recordKSPlayerPlaybackEnded(
            plan: plan,
            stage: "ksPlayerFinished",
            premature: false,
            snapshot: snapshot
        )
        let coordinator = coordinator
        Task {
            await coordinator?.finishPlayback(plan: plan)
        }
    }

    private func sanitizedKSPlayerTime(
        currentTime: TimeInterval,
        totalTime: TimeInterval,
        plan: PlaybackPlan
    ) -> (current: TimeInterval, total: TimeInterval?)? {
        let maxStandaloneDuration: TimeInterval = 24 * 60 * 60
        guard currentTime.isFinite, currentTime >= 0 else { return nil }

        let sanitizedTotal: TimeInterval? = {
            guard totalTime.isFinite, totalTime > 0, totalTime <= maxStandaloneDuration else {
                return nil
            }
            return totalTime
        }()
        let expectedDuration = plan.timeline.duration ?? sanitizedTotal
        if let expectedDuration, expectedDuration > 0 {
            let upperBound = max(
                expectedDuration + 10,
                max(plan.timeline.startTime, 0) + 10
            )
            guard currentTime <= upperBound else { return nil }
        } else {
            guard currentTime <= maxStandaloneDuration else { return nil }
        }
        return (currentTime, sanitizedTotal)
    }

    private func isSyntheticKSPlayerFinishTime(
        _ playbackTime: (current: TimeInterval, total: TimeInterval?),
        plan: PlaybackPlan
    ) -> Bool {
        guard !didRecordFirstFrame,
              let total = playbackTime.total,
              total > 1,
              abs(playbackTime.current - total) < 0.001
        else {
            return false
        }
        let startTime = max(plan.timeline.startTime, 0)
        return playbackTime.current > startTime + 1
    }

    private func isKSPlayerPrematureEnd(plan: PlaybackPlan) -> Bool {
        if !didRecordFirstFrame {
            return true
        }
        let expectedDuration = plan.timeline.duration ?? lastValidKSPlayerTime?.total
        guard let expectedDuration, expectedDuration > 30 else {
            return false
        }
        let startTime = max(plan.timeline.startTime, 0)
        let lastCurrent = lastValidKSPlayerTime?.current ?? startTime
        return lastCurrent < min(startTime + 1, expectedDuration - 1)
    }

    private func recordKSPlayerPlaybackEnded(
        plan: PlaybackPlan,
        stage: String,
        premature: Bool,
        snapshot: GreenfieldKSPlayerRuntimeSnapshot? = nil
    ) {
        var metrics = [
            "stage": stage,
            "premature": premature ? "yes" : "no",
            "didRecordFirstFrame": didRecordFirstFrame ? "yes" : "no",
            "lastState": lastKSPlayerState ?? "-"
        ]
        if let lastValidKSPlayerTime {
            metrics["lastCurrentSeconds"] = Self.formatDiagnosticSeconds(lastValidKSPlayerTime.current)
            metrics["lastDurationSeconds"] = Self.formatDiagnosticSeconds(lastValidKSPlayerTime.total)
        }
        if let snapshot {
            metrics.merge(snapshot.diagnostics) { current, _ in current }
        }
        let recorder = recorder
        Task {
            await recorder?.record(
                .playbackEnded,
                plan: plan,
                engineName: "KSPlayer",
                metrics: metrics
            )
        }
    }

    private static func formatDiagnosticSeconds(_ value: TimeInterval?) -> String {
        guard let value, value.isFinite else { return "-" }
        return String(format: "%.3f", value)
    }

    func handleKSPlayerBufferChanged(_ bufferedCount: Int, _ consumeTime: TimeInterval) {
        guard let plan = renderingPlan else { return }
        telemetrySampler?.sampleKSPlayer(
            bufferedCount: bufferedCount,
            consumeTime: consumeTime,
            reason: "bufferChanged"
        )
        let recorder = recorder
        Task {
            await recorder?.record(
                .bufferUpdated,
                plan: plan,
                engineName: "KSPlayer",
                metrics: [
                    "bufferedCount": String(bufferedCount),
                    "consumeMs": String(Int((consumeTime * 1000).rounded()))
                ]
            )
        }
    }

    private func installPlayerItem(for plan: PlaybackPlan) {
        if plan.intent.sourceKind == .jellyfin {
            AuthenticatedMediaStreamProxy.shared.setPlaylistStart(plan.primaryRoute.url, seconds: plan.timeline.startTime)
        }
        let item: AVPlayerItem
        if let preparedPlayer, let preparedItem = preparedPlayer.currentItem,
           (preparedItem.asset as? AVURLAsset)?.url == plan.primaryRoute.url {
            player = preparedPlayer
            item = preparedItem
            avItemWasPrewarmed = true
        } else {
            item = AVPlayerItem(url: plan.primaryRoute.url)
            item.preferredForwardBufferDuration = 0.5
            avItemWasPrewarmed = false
        }
        preparedPlayer = nil
        if let style = AVTextStyleRule(textMarkupAttributes: [
            kCMTextMarkupAttribute_ForegroundColorARGB as String: [1.0, 1.0, 1.0, 1.0],
            kCMTextMarkupAttribute_BackgroundColorARGB as String: [0.0, 0.0, 0.0, 0.0],
            kCMTextMarkupAttribute_CharacterBackgroundColorARGB as String: [0.0, 0.0, 0.0, 0.0],
            kCMTextMarkupAttribute_BaseFontSizePercentageRelativeToVideoHeight as String: 5.0,
            kCMTextMarkupAttribute_TextPositionPercentageRelativeToWritingDirection as String: 50.0
        ]) {
            item.textStyleRules = [style]
        }
#if DEBUG
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
        output.suppressesPlayerRendering = false
        item.add(output)
        avFrameOutput = output
#endif
        installTelemetrySampler(for: plan, engineName: fallbackRendererName(for: plan))
        telemetrySampler?.sampleAVPlayer(player, item: item, reason: "itemInstalled", force: true)
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard self?.player.currentItem === item else { return }
                self?.handleItemStatus(item.status)
            }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) {
            [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard self?.player === player else { return }
                self?.handleTimeControlStatus(player.timeControlStatus)
            }
        }
        periodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.player.currentItem === item else { return }
                self.updateAVClock(time.seconds)
                self.telemetrySampler?.sampleAVPlayer(
                    self.player,
                    item: self.player.currentItem,
                    reason: "playbackTick"
                )
            }
        }
        avWantsPlayback = !(avControls?.startsPaused ?? false)
        avInitialSeekPending = true
        avInitialSeekCompleted = false
        connectAVControls(plan: plan)
        avControls?.startsPaused = false
        if player.currentItem !== item { player.replaceCurrentItem(with: item) }
        if !avItemWasPrewarmed {
            // Queue the real resume target while the asset is loading, just as
            // in quality warmup. Waiting for ready first can prime then flush
            // the first segment a second time. Completion and readiness may
            // arrive in either order on iOS 16; both gate playback/preroll.
            let target = max(0, plan.timeline.startTime - avTimelineOffset)
            player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
                Task { @MainActor in
                    guard let self, self.player.currentItem === item else { return }
                    guard completed else {
                        self.errorMessage = NSLocalizedString("player.load_failed", comment: "")
                        self.recordPlayerFailure(plan: plan, error: nil, stage: "avInitialSeekFailed")
                        return
                    }
                    self.avInitialSeekCompleted = true
                    self.finishInitialAVSeek(item)
                }
            }
        }
    }

    private func connectAVControls(plan: PlaybackPlan) {
        guard let controls = avControls else { return }
        controls.beginSession()
        controls.engineName = "AVPlayer"
        if let catalog = request?.tracks, request?.mediaRequest?.sourceTrackRequestLoader != nil {
            controls.sourceRuntimeTracks = (
                catalog.sourceAudioTracks.firstIndex { $0.id == catalog.selectedSourceAudioTrackID },
                catalog.sourceSubtitleTracks.firstIndex { $0.id == catalog.selectedSourceSubtitleTrackID },
                request?.mediaRequest?.prefersSubtitlesDisabled ?? (catalog.selectedSourceSubtitleTrackID == nil)
            )
        } else { controls.sourceRuntimeTracks = nil }
        controls.planID = String(plan.id.uuidString.prefix(8))
        controls.routeID = String(plan.primaryRoute.id.uuidString.prefix(8))
        controls.rate = plan.intent.playbackRate
        controls.currentSeconds = plan.timeline.startTime
        controls.durationSeconds = plan.timeline.duration ?? 0
        controls.isReady = false
        controls.isPlaying = false
        controls.audioTracks = []; controls.subtitleTracks = []
        controls.selectedAudioTrackID = -1; controls.selectedSubtitleTrackID = -1
        player.isMuted = controls.isMuted
        controls.togglePlaybackAction = { [weak self, weak controls] in
            guard let self, let controls else { return }
            self.avWantsPlayback.toggle()
            if self.avWantsPlayback { self.player.playImmediately(atRate: controls.rate) }
            else { self.player.pause(); self.resetContinuity() }
            controls.isPlaying = self.avWantsPlayback
            controls.didTogglePlayback()
            controls.record(self.avWantsPlayback ? "play" : "pause")
        }
        controls.updateRate = { [weak self] rate in
            guard let self, self.avWantsPlayback else { return }
            self.player.rate = rate
        }
        controls.muteAction = { [weak self] in self?.player.isMuted = $0 }
        controls.canSeekAbsolute = { [weak self] seconds in
            guard let self, let item = self.player.currentItem else { return false }
            let raw = seconds - self.avTimelineOffset
            return raw >= 0 && item.seekableTimeRanges.contains {
                CMTimeRangeContainsTime($0.timeRangeValue, time: CMTime(seconds: raw, preferredTimescale: 600))
            }
        }
        controls.readPlaybackClock = { [weak self] in
            guard let self else { return .nan }
            return self.player.currentTime().seconds + self.avTimelineOffset
        }
        controls.seekPlayback = { [weak self, weak controls] seconds in
            guard let self, let item = self.player.currentItem else { return }
            let generation = controls?.seekGeneration
            self.player.seek(to: CMTime(seconds: max(0, seconds - self.avTimelineOffset), preferredTimescale: 600),
                             toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
                Task { @MainActor in
                    guard let self, self.player.currentItem === item,
                          let controls, controls.seekGeneration == generation else { return }
                    controls.seekDidComplete(completed)
                    if completed {
                        // HLS seeks may leave the transport paused. Restore
                        // the latest user intent, including a pause during seek.
                        if self.avWantsPlayback { self.player.playImmediately(atRate: controls.rate) }
                        else { self.player.pause() }
                        self.updateAVClock(self.player.currentTime().seconds)
                        self.probeAVFrame(reason: "interactiveSeek")
                    }
                }
            }
        }
        controls.audioAction = { [weak self] in self?.selectAVTrack($0, characteristic: .audible) }
        controls.subtitleAction = { [weak self] in self?.selectAVTrack($0, characteristic: .legible) }
        controls.externalSubtitleAction = { [weak self] _ in self?.selectAVTrack(-1, characteristic: .legible) }
    }

    private func selectAVTrack(_ id: Int32, characteristic: AVMediaCharacteristic) {
        guard let item = player.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) else { return }
        guard id < 0 || group.options.indices.contains(Int(id)) else { return }
        item.select(id < 0 ? nil : group.options[Int(id)], in: group)
        syncAVTracks()
        avControls?.record(characteristic == .audible ? "audioTrackRequested" : "subtitleTrackRequested", value: String(id))
    }

    private func syncAVTracks() {
        guard let item = player.currentItem, let controls = avControls else { return }
        for characteristic: AVMediaCharacteristic in [.audible, .legible] {
            guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) else { continue }
            let tracks = group.options.enumerated().map { PlaybackUITrack(id: Int32($0.offset), name: $0.element.displayName) }
            let selected = item.currentMediaSelection.selectedMediaOption(in: group)
            let id = selected.flatMap { group.options.firstIndex(of: $0) }.map(Int32.init) ?? -1
            if characteristic == .audible { controls.audioTracks = tracks; controls.selectedAudioTrackID = id }
            else { controls.subtitleTracks = tracks; controls.selectedSubtitleTrackID = id }
        }
    }

    private func updateAVClock(_ rawSeconds: Double) {
        guard rawSeconds.isFinite, !avInitialSeekPending, let controls = avControls else { return }
        let seconds = max(0, rawSeconds + avTimelineOffset)
        controls.updateClock(seconds)
        let rawDuration = player.currentItem?.duration.seconds ?? 0
        if let duration = renderingPlan?.timeline.duration { controls.durationSeconds = duration }
        else if rawDuration.isFinite, rawDuration > 0 { controls.durationSeconds = rawDuration + avTimelineOffset }
        controls.isSeekable = !(player.currentItem?.seekableTimeRanges.isEmpty ?? true)
        handlePlaybackTime(seconds)
    }

    /// Diagnostic output sampling does not establish compositor presentation.
    /// Bound retries to this item/seek generation so stale results cannot cross plans.
    private func probeAVFrame(reason: String) {
#if DEBUG
        avFrameProbeTask?.cancel()
        guard let item = player.currentItem, let output = avFrameOutput,
              let controls = avControls else { return }
        let generation = controls.seekGeneration
        avFrameProbeTask = Task { @MainActor [weak self, weak controls] in
            for _ in 0..<20 {
                guard !Task.isCancelled, let self, let controls,
                      self.player.currentItem === item, controls.seekGeneration == generation else { return }
                let time = self.player.currentTime()
                var displayTime = CMTime.invalid
                if output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: &displayTime) != nil {
                    controls.event("video_output_sample", metrics: [
                        "rawClockSeconds": String(time.seconds),
                        "outputPTSSeconds": String(displayTime.seconds),
                        "controlSeconds": String(controls.currentSeconds),
                        "reason": reason,
                        "evidence": "AVPlayerItemVideoOutputNotPresentation"
                    ])
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            controls?.event("video_output_unavailable", metrics: ["reason": reason])
        }
#endif
    }

    private func handleItemStatus(_ status: AVPlayerItem.Status) {
        guard let plan = renderingPlan else { return }
        telemetrySampler?.sampleAVPlayer(
            player,
            item: player.currentItem,
            reason: "itemStatusChanged",
            force: status == .readyToPlay || status == .failed
        )
        switch status {
        case .readyToPlay:
            debugBadge = fallbackBadge(for: plan, reason: "ready")
            syncAVTracks()
            guard avInitialSeekPending, let item = player.currentItem else { return }
            if avItemWasPrewarmed {
                avItemWasPrewarmed = false
                avInitialSeekPending = false
                avControls?.isReady = true
                updateAVClock(player.currentTime().seconds)
                if avWantsPlayback { player.playImmediately(atRate: avControls?.rate ?? 1) }
                else { player.pause() }
                probeAVFrame(reason: "preparedHandoff")
                return
            }
            finishInitialAVSeek(item)
        case .failed:
            let itemError = player.currentItem?.error
            errorMessage = itemError?.localizedDescription
                ?? NSLocalizedString("player.load_failed", comment: "")
            debugBadge = "Greenfield player failed"
            recordPlayerFailure(plan: plan, error: itemError, stage: "avPlayerItemFailed")
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func finishInitialAVSeek(_ item: AVPlayerItem) {
        guard player.currentItem === item, item.status == .readyToPlay,
              avInitialSeekPending, avInitialSeekCompleted else { return }
        avInitialSeekPending = false
        avControls?.isReady = true
        updateAVClock(player.currentTime().seconds)
        if avWantsPlayback {
            player.playImmediately(atRate: avControls?.rate ?? 1)
            probeAVFrame(reason: "initialSeek")
        } else {
            player.pause()
            player.preroll(atRate: avControls?.rate ?? 1) { [weak self] ready in
                Task { @MainActor in
                    guard let self, self.player.currentItem === item else { return }
                    self.avControls?.event("paused_preroll_completed", metrics: ["completed": String(ready)])
                    self.probeAVFrame(reason: "pausedPreroll")
                }
            }
        }
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        guard let plan = renderingPlan, lastTimeControlStatus != status else { return }
        if status == .playing {
            // Small startup buffering should not cap the reserve during normal
            // playback on WAN connections. Let AVPlayer size it after startup.
            player.currentItem?.preferredForwardBufferDuration = 0
        }
        avControls?.isPlaying = avWantsPlayback && status != .paused
        if status != .playing { resetContinuity() }
        let previousStatus = lastTimeControlStatus
        lastTimeControlStatus = status
        telemetrySampler?.sampleAVPlayer(
            player,
            item: player.currentItem,
            reason: "timeControlChanged",
            force: true
        )
        let coordinator = coordinator
        Task {
            if status == .paused, previousStatus == .playing {
                await coordinator?.pause(plan: plan)
            } else if status == .playing, previousStatus == .paused {
                try? await coordinator?.resume(plan: plan)
            }
        }
    }

    private func handlePlaybackTime(_ seconds: Double) {
        guard let coordinator, let plan = renderingPlan, seconds.isFinite else { return }
        let paused = plan.enginePolicy == .ksPlayer ? lastKSPlayerState == "paused" : player.timeControlStatus == .paused
        request?.mediaRequest?.playbackTracker?.started(positionSeconds: seconds)
        request?.mediaRequest?.playbackTracker?.progressed(positionSeconds: seconds, isPaused: paused)
        if !didRecordFirstFrame, seconds > max(plan.timeline.startTime, 0) + 0.05 {
            didRecordFirstFrame = true
            if let currentItem = player.currentItem {
                telemetrySampler?.sampleAVPlayer(
                    player,
                    item: currentItem,
                    reason: "firstFrame",
                    force: true
                )
            } else {
                telemetrySampler?.sampleKSPlayer(
                    currentTime: seconds,
                    reason: "firstFrame",
                    force: true
                )
            }
            Task {
                await coordinator.markFirstFrame(plan: plan, position: seconds)
            }
        }
        let uptime = ProcessInfo.processInfo.systemUptime
        if paused { resetContinuity() }
        else {
            if let previous = continuitySample {
                let wallDelta = uptime - previous.uptime
                let mediaDelta = seconds - previous.seconds
                // Repeated clock callbacks are not a discontinuity. Keep the
                // last advancing sample so a real stall still exceeds the
                // wall-time limit when progress resumes.
                if mediaDelta >= 0, mediaDelta <= 0.01, wallDelta < 2.5 { return }
                if wallDelta > 0, wallDelta < 2.5, mediaDelta > 0.01, mediaDelta < wallDelta * 4 + 0.5 {
                    continuousWallSeconds += wallDelta
                } else { continuousWallSeconds = 0 }
            }
            continuitySample = (seconds, uptime)
        }
        if !didRecordThirtySecondCheckpoint,
           didRecordFirstFrame,
           continuousWallSeconds >= 30 {
            didRecordThirtySecondCheckpoint = true
            Task {
                await coordinator.markContinuousPlayback(plan: plan, seconds: 30)
            }
        }
    }

    private func recordPlanReady(_ result: PlaybackSessionStartupResult) {
        let renderer = shouldUseKSPlayerRenderer(for: result.plan)
            ? "KSPlayer"
            : fallbackRendererName(for: result.plan)
        debugBadge = [
            "Greenfield",
            renderer,
            "plan=\(result.plan.enginePolicy.rawValue)",
            result.plan.primaryRoute.routeKind.rawValue,
            result.plan.intent.connectionContext.addressKind.rawValue
        ].joined(separator: " / ")
    }

    private func shouldUseKSPlayerRenderer(for plan: PlaybackPlan) -> Bool {
        plan.enginePolicy == .ksPlayer && PlaybackEngineAvailability.ksPlayerLinked
    }

    private func requiresLinkedKSPlayer(for plan: PlaybackPlan) -> Bool {
        plan.enginePolicy == .ksPlayer && !PlaybackEngineAvailability.ksPlayerLinked
    }

    private func handleRequiredKSPlayerMissing(_ plan: PlaybackPlan) {
        player.replaceCurrentItem(with: nil)
        errorMessage = "KSPlayer is required for this route but is not linked in this build."
        debugBadge = "Greenfield / KSPlayer required / not linked"
        recordPlayerFailure(plan: plan, error: nil, stage: "ksPlayerNotLinked")
    }

    private func fallbackRendererName(for plan: PlaybackPlan) -> String {
        if plan.enginePolicy == .ksPlayer {
            return "AVPlayer fallback"
        }
        return PlaybackEngineAvailability.displayName(for: plan.enginePolicy)
    }

    private func fallbackBadge(for plan: PlaybackPlan, reason: String) -> String {
        [
            "Greenfield",
            "\(fallbackRendererName(for: plan)) \(reason)",
            "plan=\(plan.enginePolicy.rawValue)",
            plan.primaryRoute.routeKind.rawValue,
            plan.intent.connectionContext.addressKind.rawValue
        ].joined(separator: " / ")
    }

    private func activateAlternateRoute(after plan: PlaybackPlan, reason: String) -> Bool {
        failedRouteIDs.insert(plan.primaryRoute.id)
        guard let fallbackRoute = plan.alternateRoutes.first(where: { route in
            !failedRouteIDs.contains(route.id)
                && route.url.absoluteString != plan.primaryRoute.url.absoluteString
        }) else {
            return false
        }

        let remainingRoutes = ([plan.primaryRoute] + plan.alternateRoutes).filter {
            $0.id != fallbackRoute.id
        }
        var replacementIntent = plan.intent
        replacementIntent.directURL = fallbackRoute.url
        replacementIntent.connectionContext = PlaybackConnectionContext.make(url: fallbackRoute.url)
        let replacementPlan = PlaybackPlanningPolicy.makePlan(
            intent: replacementIntent,
            url: fallbackRoute.url,
            originURL: fallbackRoute.originURL,
            fileExtensionHint: fallbackRoute.containerHint,
            mimeHint: fallbackRoute.mimeHint,
            certificatePolicy: fallbackRoute.certificatePolicy,
            byteLength: fallbackRoute.byteLength,
            duration: fallbackRoute.duration,
            estimatedBitrate: fallbackRoute.codecSummary.bitrate,
            tracks: plan.tracks,
            subtitles: plan.subtitles,
            alternateRoutes: remainingRoutes
        )
        errorMessage = nil
        isPreparing = false
        renderingPlan = replacementPlan
        player.replaceCurrentItem(with: nil)
        telemetrySampler?.stop(reason: "alternateRouteActivated")
        telemetrySampler = nil
        debugBadge = [
            "Greenfield",
            "fallback \(reason)",
            "renderer=\(fallbackRendererName(for: replacementPlan))",
            "plan=\(replacementPlan.enginePolicy.rawValue)",
            replacementPlan.primaryRoute.routeKind.rawValue,
            replacementPlan.intent.connectionContext.addressKind.rawValue
        ].joined(separator: " / ")
        if shouldUseKSPlayerRenderer(for: replacementPlan) {
            installTelemetrySampler(for: replacementPlan, engineName: "KSPlayer")
            telemetrySampler?.sampleKSPlayer(
                state: "alternateRouteSelected",
                reason: reason,
                force: true
            )
        } else {
            installPlayerItem(for: replacementPlan)
        }
        let coordinator = coordinator
        Task {
            await coordinator?.markStreamInterrupted(
                plan: plan,
                reason: reason,
                fallbackRoute: fallbackRoute
            )
        }
        return true
    }

    private func installTelemetrySampler(for plan: PlaybackPlan, engineName: String) {
        guard let recorder else { return }
        telemetrySampler?.stop(reason: "routeReplaced")
        telemetrySampler = PlaybackTelemetrySampler(
            recorder: recorder,
            plan: plan,
            engineName: engineName
        )
    }

    private func recordPlayerFailure(
        plan: PlaybackPlan,
        error: Error?,
        stage: String,
        snapshot: GreenfieldKSPlayerRuntimeSnapshot? = nil
    ) {
        var details = [
            "stage": stage,
            "enginePolicy": plan.enginePolicy.rawValue,
            "routeKind": plan.primaryRoute.routeKind.rawValue,
            "sourceKind": plan.intent.sourceKind.rawValue,
            "contentKind": plan.intent.contentKind.rawValue,
            "addressKind": plan.intent.connectionContext.addressKind.rawValue,
            "ksPlayerLinked": "\(PlaybackEngineAvailability.ksPlayerLinked)",
            "playbackTraceID": request?.playbackTraceID ?? "-",
            "target": DiagnosticLogStore.redactedURL(plan.primaryRoute.url)
        ]
        if let error {
            let nsError = error as NSError
            details["errorDomain"] = nsError.domain
            details["errorCode"] = "\(nsError.code)"
            details["error"] = nsError.localizedDescription
        }
        if let snapshot {
            details.merge(snapshot.diagnostics) { current, _ in current }
        }
        DiagnosticLogStore.shared.record(
            .error,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.playback.next.playback_failed",
            details: details
        )
    }
}

// Uses the same targets and credential handoff policy as the legacy player.
private struct SharedPlaybackExternalPicker: View {
    let request: MediaPlaybackRequest
    @Environment(\.dismiss) private var dismiss
    @State private var resolved: MediaPlaybackRequest?
    @State private var pendingTarget: ExternalOpenTarget?
    @State private var confirmsCredentials = false
    @State private var shareURL: URL?
    @State private var showsShare = false
    @State private var preparing = false
    var body: some View {
        NavigationStack {
            List {
                ForEach(ExternalOpenTarget.installedPlayers) { target in
                    Button(target.displayName) { prepare(target) }
                }
                Button("external.browser") { prepare(.safari) }
                Button("external.other_apps") { prepare(nil) }
            }
            .disabled(preparing)
            .overlay { if preparing { ProgressView() } }
            .navigationTitle("service.external.title")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("action.done") { dismiss() }
            } }
            .confirmationDialog("external.credential_warning.title", isPresented: $confirmsCredentials, titleVisibility: .visible) {
                Button("external.credential_warning.continue") { openResolved() }
                Button("action.cancel", role: .cancel) {}
            } message: { Text("external.credential_warning.message") }
            .sheet(isPresented: $showsShare) {
                if let shareURL { SystemShareView(items: [shareURL]) }
            }
        }
    }
    private func prepare(_ target: ExternalOpenTarget?) {
        guard !preparing else { return }
        preparing = true
        pendingTarget = target
        Task { @MainActor in
            defer { preparing = false }
            if resolved == nil {
                if request.externalHandoffResource == nil,
                   let resource = await request.externalHandoffResourceLoader?() {
                    resolved = MediaPlaybackRequest(url: resource.url, title: request.title,
                        externalSubtitleURL: resource.subtitleURL)
                } else { resolved = request }
            }
            if (resolved ?? request).containsSensitiveCredential { confirmsCredentials = true }
            else { openResolved() }
        }
    }
    private func openResolved() {
        let current = resolved ?? request
        guard let target = pendingTarget,
              let url = target.url(endpoint: current.externalHandoffURL,
                  filename: current.externalFilename, subtitleURL: current.externalHandoffSubtitleURL) else {
            shareURL = current.externalHandoffURL; showsShare = true; return
        }
        UIApplication.shared.open(url, options: [:]) { accepted in
            DiagnosticLogStore.shared.record(accepted ? .info : .error, categoryKey: "diagnostics.category.media",
                messageKey: accepted ? "diagnostics.media.external_handoff_accepted" : "diagnostics.media.external_handoff_failed",
                details: ["targetApp": target.diagnosticName])
            if !accepted { shareURL = current.externalHandoffURL; showsShare = true }
        }
    }
}

// AVPlayer supplies video/PiP; the same app chrome owns every playback action.
struct GreenfieldAVPlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    @ObservedObject var controls: GreenfieldPlaybackControls

    final class SurfaceView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
    @MainActor final class Coordinator: NSObject {
        let pipDelegate = GreenfieldPiPDelegate()
        var pictureInPicture: AVPictureInPictureController?
        var displayObservation: NSKeyValueObservation?
        func connectControls(_ controls: GreenfieldPlaybackControls) {
            pipDelegate.controls = controls
            controls.pictureInPictureAction = { [weak self, weak controls] in
                guard let pip = self?.pictureInPicture, pip.isPictureInPicturePossible else {
                    controls?.pictureInPictureUnavailable = true
                    controls?.event("picture_in_picture_unavailable")
                    return
                }
                pip.startPictureInPicture()
                controls?.record("pictureInPictureRequested")
            }
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> SurfaceView {
        let view = SurfaceView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        context.coordinator.displayObservation = view.playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak controls] layer, _ in
            guard layer.isReadyForDisplay else { return }
            Task { @MainActor in
                controls?.event("video_layer_ready", metrics: ["evidence": "AVPlayerLayer.readyForDisplay"])
            }
        }
        let pip = AVPictureInPictureController(playerLayer: view.playerLayer)
        pip?.canStartPictureInPictureAutomaticallyFromInline = true
        pip?.delegate = context.coordinator.pipDelegate
        context.coordinator.pictureInPicture = pip
        context.coordinator.connectControls(controls)
        return view
    }
    func updateUIView(_ view: SurfaceView, context: Context) {
        view.playerLayer.player = player
        view.playerLayer.videoGravity = controls.fillsScreen ? .resizeAspectFill : .resizeAspect
        // A quality change reuses this surface but disconnects the old session.
        // Rebind the action even when makeUIView is not called again.
        context.coordinator.connectControls(controls)
    }
    static func dismantleUIView(_ view: SurfaceView, coordinator: Coordinator) {
        coordinator.displayObservation?.invalidate()
        coordinator.displayObservation = nil
        coordinator.pictureInPicture?.stopPictureInPicture()
        coordinator.pictureInPicture = nil
        view.playerLayer.player = nil
    }
}

@MainActor
enum GreenfieldPlaybackAudioSession {
    static func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
        try session.setActive(true)
    }
}

// Own PiP presentation separately from the media session. The retained hosting
// controller survives dismissal, so closing the full-screen UI does not tear
// down the sample-buffer renderer or AVPlayer used by the system PiP window.
@MainActor
final class GreenfieldPiPDelegate: NSObject, @preconcurrency AVPictureInPictureControllerDelegate {
    weak var controls: GreenfieldPlaybackControls?
    private var restoring = false
    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        restoring = false
        controls?.isPictureInPictureActive = true
        controls?.pipDidStart?()
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        restoring = true
        guard let restore = controls?.pipRestore else { completionHandler(true); return }
        restore { [weak self] success in
            self?.restoring = success
            completionHandler(success)
        }
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        controls?.isPictureInPictureActive = false
        if !restoring { controls?.pipDidClose?() }
        restoring = false
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        controls?.isPictureInPictureActive = false
        controls?.pictureInPictureUnavailable = true
    }
}

extension View {
    func greenfieldPlaybackCover(item: Binding<GreenfieldPlaybackLaunchRequest?>) -> some View {
        background(GreenfieldPlaybackPresenter(request: item).frame(width: 0, height: 0))
    }
}

private struct GreenfieldPlaybackPresenter: UIViewControllerRepresentable {
    @Binding var request: GreenfieldPlaybackLaunchRequest?
    final class Anchor: UIViewController {
        var becameVisible: (() -> Void)?
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becameVisible?()
        }
    }
    @MainActor final class Coordinator {
        private static var retainedPiP: Coordinator?
        var binding: Binding<GreenfieldPlaybackLaunchRequest?>
        weak var anchor: Anchor?
        var host: UIHostingController<GreenfieldVideoPlayerView>?
        var currentID: UUID?
        var minimized = false
        init(binding: Binding<GreenfieldPlaybackLaunchRequest?>) { self.binding = binding }
        func update() {
            guard let request = binding.wrappedValue else {
                if host != nil && !minimized { close() }
                return
            }
            guard currentID != request.id, let anchor, anchor.viewIfLoaded?.window != nil else { return }
            guard host == nil else { return }
            if let prior = Self.retainedPiP, prior !== self { prior.close() }
            currentID = request.id
            let controller = UIHostingController(rootView: GreenfieldVideoPlayerView(request: request,
                closePresentation: { [weak self] in self?.close() },
                minimizePresentation: { [weak self] in self?.minimize() },
                restorePresentation: { [weak self] completion in self?.restore(completion) ?? completion(false) }))
            controller.modalPresentationStyle = .fullScreen
            host = controller
            anchor.present(controller, animated: true)
        }
        func minimize() {
            guard let host else { return }
            minimized = true
            Self.retainedPiP = self
            host.dismiss(animated: true) {
                PlayerOrientationController.setPlayerActive(false)
            }
        }
        func restore(_ completion: @escaping (Bool) -> Void) {
            guard let host else { completion(false); return }
            var presenter: UIViewController? = anchor?.viewIfLoaded?.window != nil ? anchor : nil
            if presenter == nil {
                presenter = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
                while let presented = presenter?.presentedViewController { presenter = presented }
            }
            guard let presenter else { completion(false); return }
            PlayerOrientationController.prepareForPresentation(host.rootView.presentationOrientation)
            presenter.present(host, animated: true) {
                self.minimized = false
                completion(true)
                Self.retainedPiP = nil
            }
        }
        func close() {
            let controller = host
            host = nil
            currentID = nil
            minimized = false
            binding.wrappedValue = nil
            if Self.retainedPiP === self { Self.retainedPiP = nil }
            controller?.dismiss(animated: true)
            PlayerOrientationController.setPlayerActive(false)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(binding: $request) }
    func makeUIViewController(context: Context) -> Anchor {
        let anchor = Anchor()
        anchor.view.backgroundColor = .clear
        context.coordinator.anchor = anchor
        anchor.becameVisible = { [weak coordinator = context.coordinator] in coordinator?.update() }
        return anchor
    }
    func updateUIViewController(_ controller: Anchor, context: Context) {
        context.coordinator.binding = $request
        DispatchQueue.main.async { context.coordinator.update() }
    }
}

@MainActor
enum GreenfieldAVPlayerWarmup {
    private static var networkPreparationSeconds = 4.0
    /// Keep the current renderer running while the muted candidate decodes.
    /// Catch up to the live playhead before committing; retain the old stream
    /// on timeout instead of moving the user to an unprepared replacement.
    static func prepare(_ request: MediaPlaybackRequest,
        liveClock: (() -> Double)? = nil, isPlaying: () -> Bool = { false },
        report: (String, [String: String]) -> Void = { _, _ in }) async -> AVPlayer? {
        let initialSeconds = request.timelineOffsetSeconds > 0 ? request.timelineOffsetSeconds
            : (request.initialPosition ?? 0) * (request.totalDurationSeconds ?? 0)
        let preparationLead = request.url.isFileURL ? 0.1 : networkPreparationSeconds
        let target = min((liveClock?() ?? initialSeconds)
            + (isPlaying() ? preparationLead * Double(request.initialPlaybackRate) : 0),
            max((request.totalDurationSeconds ?? .greatestFiniteMagnitude) - 0.1, 0))
        AuthenticatedMediaStreamProxy.shared.setPlaylistStart(request.url, seconds: target)
        let item = AVPlayerItem(url: request.url)
        item.preferredForwardBufferDuration = 0.5
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
        item.add(output)
        let candidate = AVPlayer(playerItem: item)
        candidate.isMuted = true
        candidate.automaticallyWaitsToMinimizeStalling = false
        let started = ProcessInfo.processInfo.systemUptime
        let deadline = started + 20
        var success = false
        defer {
            candidate.cancelPendingPrerolls()
            item.remove(output)
            if !success {
                candidate.pause()
                item.cancelPendingSeeks()
                candidate.replaceCurrentItem(with: nil)
            }
        }
        // Aim ahead by the measured decoder startup cost. The old player keeps
        // running until this frame's time; this avoids paying startup twice
        // (once decoding, again catching up from the stale selection position).
        var seekResult: Bool?
        // Queue the resume seek before readiness so VOD does not fetch segment zero.
        candidate.seek(to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero, toleranceAfter: .zero) { completed in
            Task { @MainActor in seekResult = completed }
        }
        while (seekResult == nil || candidate.status != .readyToPlay) && item.status != .failed && candidate.status != .failed && !Task.isCancelled,
              ProcessInfo.processInfo.systemUptime < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        guard seekResult == true, candidate.status == .readyToPlay, !Task.isCancelled else {
            report("warmup_failed", ["stage": "initialSeek"]); return nil
        }
        // Full preroll may wait several seconds beyond the first decoded frame.
        // Use an actual output frame as the gate, with the old renderer running.
        if isPlaying() { candidate.playImmediately(atRate: request.initialPlaybackRate) }
        else { candidate.preroll(atRate: request.initialPlaybackRate) { _ in } }
        var firstFrame: Double?
        while firstFrame == nil, item.status != .failed, !Task.isCancelled,
              ProcessInfo.processInfo.systemUptime < deadline {
            var displayTime = CMTime.invalid
            let frameTime = candidate.currentTime()
            if output.copyPixelBuffer(forItemTime: frameTime,
                                      itemTimeForDisplay: &displayTime) != nil,
               displayTime.seconds.isFinite, abs(displayTime.seconds - frameTime.seconds) < 0.15 {
                firstFrame = displayTime.seconds
            } else { try? await Task.sleep(nanoseconds: 20_000_000) }
        }
        guard let firstFrame, !Task.isCancelled else {
            report("warmup_failed", ["stage": "decodedFrame"]); return nil
        }
        if !request.url.isFileURL {
            networkPreparationSeconds = min(max(ProcessInfo.processInfo.systemUptime - started + 0.15, 0.25), 6)
        }
        candidate.cancelPendingPrerolls()
        report("candidate_decoded", ["framePTS": String(firstFrame), "target": String(target),
            "prepareMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000))])
        var lastFrame = firstFrame
        while !Task.isCancelled, item.status != .failed, ProcessInfo.processInfo.systemUptime < deadline {
            let current = candidate.currentTime().seconds
            let live = liveClock?() ?? initialSeconds
            var displayTime = CMTime.invalid
            if output.copyPixelBuffer(forItemTime: candidate.currentTime(), itemTimeForDisplay: &displayTime) != nil,
               displayTime.seconds.isFinite { lastFrame = displayTime.seconds }
            let delta = current - live
            if abs(delta) <= 0.1, abs(lastFrame - current) <= 0.15 {
                if isPlaying() { candidate.playImmediately(atRate: request.initialPlaybackRate) }
                else { candidate.pause() }
                report("candidate_aligned", ["candidate": String(current), "current": String(live),
                    "framePTS": String(lastFrame), "evidence": "decodedFrameAndClock"])
                success = true
                return candidate
            }
            guard abs(delta) < 10 else { break } // A user seek invalidated this warmup.
            if delta > 0.04 { candidate.pause() }
            else if isPlaying() {
                // Catch up once, muted, instead of restarting server transcodes
                // with repeated seeks to a continually moving target.
                candidate.playImmediately(atRate: min(request.initialPlaybackRate * 2, 4))
            } else { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        report("warmup_failed", ["stage": "alignment"])
        return nil
    }

}
