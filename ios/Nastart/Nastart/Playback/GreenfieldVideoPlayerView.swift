import SwiftUI
import AVFoundation
import AVKit

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
    init(request: GreenfieldPlaybackLaunchRequest) {
        _request = State(initialValue: request)
    }
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = GreenfieldVideoPlayerModel()
    @StateObject private var ksControls = GreenfieldPlaybackControls()
    @StateObject private var avControls = GreenfieldPlaybackControls()
    private var controls: GreenfieldPlaybackControls { usesKSPlayer ? ksControls : avControls }
    @State private var replacementRequest: GreenfieldPlaybackLaunchRequest?
    @State private var changingSource = false
    @State private var sourceLoadTask: Task<Void, Never>?
    @State private var sourceChangeFailed = false
    @State private var handoffRequest: MediaPlaybackRequest?
    private var activeRequest: GreenfieldPlaybackLaunchRequest { replacementRequest ?? request }
    private var uiRequest: MediaPlaybackRequest {
        activeRequest.mediaRequest ?? MediaPlaybackRequest(url: activeRequest.intent.directURL ?? URL(fileURLWithPath: "/"),
            title: activeRequest.intent.displayTitle, initialOrientationMode: activeRequest.orientationMode)
    }


    private var usesKSPlayer: Bool {
        model.renderingPlan?.enginePolicy == .ksPlayer && PlaybackEngineAvailability.ksPlayerLinked
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let plan = model.renderingPlan,
               plan.enginePolicy == .ksPlayer,
               PlaybackEngineAvailability.ksPlayerLinked {
                SharedBuiltInPlayerView(request: uiRequest, session: controls,
                    close: { dismiss() },
                    useSystemPlayer: { _, _ in controls.pictureInPictureAction?() },
                    compatibilityFailed: { _ in },
                    sourceTrackChange: sourceTrackCallback,
                    serverSeek: serverSeekCallback,
                    qualityChange: qualityCallback,
                    openExternal: { handoffRequest = uiRequest }) {
                GreenfieldKSPlayerRenderer(
                    plan: plan,
                    controls: controls,
                    onUnsupported: model.handleKSPlayerRendererUnsupported,
                    onStateChanged: model.handleKSPlayerStateChanged,
                    onPlaybackTime: model.handleKSPlayerPlaybackTime,
                    onFinished: model.handleKSPlayerFinished,
                    onBufferChanged: model.handleKSPlayerBufferChanged
                )
                .id(plan.primaryRoute.id)
                }
                .id(plan.id)
            } else if let plan = model.renderingPlan {
                SharedBuiltInPlayerView(request: uiRequest, session: avControls,
                    close: { dismiss() },
                    useSystemPlayer: { _, _ in avControls.pictureInPictureAction?() },
                    compatibilityFailed: { _ in },
                    sourceTrackChange: sourceTrackCallback,
                    serverSeek: serverSeekCallback,
                    qualityChange: qualityCallback,
                    openExternal: { handoffRequest = uiRequest }) {
                    GreenfieldAVPlayerSurface(player: model.player, controls: avControls)
                        .ignoresSafeArea()
                }
                .id(plan.id)
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
                        dismiss()
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
                    dismiss()
                }
            }
#else
            ToolbarItem(placement: .cancellationAction) {
                Button("action.done") {
                    dismiss()
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
        .onAppear {
            PlayerOrientationController.setPlayerActive(
                true,
                initialMode: request.orientationMode
            )
            ksControls.onTimelineDiscontinuity = model.resetContinuity
            avControls.onTimelineDiscontinuity = model.resetContinuity
            ksControls.traceID = activeRequest.playbackTraceID
            avControls.traceID = activeRequest.playbackTraceID
            model.avControls = avControls
            model.start(activeRequest)
        }
        .onDisappear {
            sourceLoadTask?.cancel()
            model.stop()
            PlayerOrientationController.setPlayerActive(false)
        }
    }
    private var sourceTrackCallback: ((Int?, Int?, MediaPlaybackRuntimeState) -> Void)? {
        guard let loader = uiRequest.sourceTrackRequestLoader else { return nil }
        return { audio, subtitle, state in
            if usesKSPlayer, model.renderingPlan?.primaryRoute.playMethod == .directPlay,
               audio == nil || controls.audioTracks.contains(where: { Int($0.id) == audio }),
               subtitle == nil || controls.subtitleTracks.contains(where: { Int($0.id) == subtitle }) {
                if let audio, let track = controls.audioTracks.first(where: { Int($0.id) == audio }) {
                    controls.selectAudio(track)
                }
                controls.selectSubtitle(PlaybackUITrack(id: Int32(subtitle ?? -1), name: ""))
            } else { replaceSource { await loader(audio, subtitle, state) } }
        }
    }
    private var serverSeekCallback: ((Double, MediaPlaybackRuntimeState) -> Void)? {
        guard let loader = uiRequest.serverSeekRequestLoader else { return nil }
        return { seconds, state in replaceSource { await loader(seconds, state) } }
    }
    private var qualityCallback: ((String, MediaPlaybackRuntimeState) -> Void)? {
        guard let loader = uiRequest.qualityRequestLoader else { return nil }
        return { quality, state in replaceSource { await loader(quality, state) } }
    }
    private func replaceSource(_ load: @escaping () async -> MediaPlaybackRequest?) {
#if DEBUG
        guard !changingSource else { return }
        changingSource = true
        let wasPaused = !controls.isPlaying
        sourceLoadTask = Task { @MainActor in
            defer { changingSource = false }
            let loaded = await load()
            guard !Task.isCancelled else { return }
            guard let next = loaded else { sourceChangeFailed = true; return }
            let launch = next.greenfieldPlaybackLaunchRequest(playbackModePreference: activeRequest.intent.playbackModePreference)
            model.stop(reportStop: activeRequest.mediaRequest?.playbackTracker !== next.playbackTracker)
            ksControls.startsPaused = wasPaused
            avControls.startsPaused = wasPaused
            ksControls.traceID = launch.playbackTraceID
            avControls.traceID = launch.playbackTraceID
            replacementRequest = launch
            model.start(launch)
        }
#endif
    }

}

@MainActor
private final class GreenfieldVideoPlayerModel: ObservableObject {
    let player = AVPlayer()
    weak var avControls: GreenfieldPlaybackControls?
    private var avWantsPlayback = true
    private var avInitialSeekPending = false
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

    func start(_ request: GreenfieldPlaybackLaunchRequest) {
        guard playbackTask == nil else { return }
        self.request = request
        isPreparing = true
        errorMessage = nil
        debugBadge = "Greenfield preparing"

        playbackTask = Task { [weak self] in
            guard let self else { return }
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
            do {
                let result = try await coordinator.prepare(request.intent)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.recorder = recorder
                    self.coordinator = coordinator
                    self.renderingPlan = result.plan
                    if self.requiresLinkedKSPlayer(for: result.plan) {
                        self.handleRequiredKSPlayerMissing(result.plan)
                    } else if self.shouldUseKSPlayerRenderer(for: result.plan) {
                        self.player.replaceCurrentItem(with: nil)
                        self.installTelemetrySampler(for: result.plan, engineName: "KSPlayer")
                        self.telemetrySampler?.sampleKSPlayer(
                            state: "rendererSelected",
                            reason: "planReady",
                            force: true
                        )
                    } else {
                        self.installPlayerItem(for: result.plan)
                    }
                    self.isPreparing = false
                    self.recordPlanReady(result)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isPreparing = false
                    self.errorMessage = error.localizedDescription
                    self.debugBadge = "Greenfield failed"
                }
            }
        }
    }

    func stop(reportStop: Bool = true) {
        if reportStop { request?.mediaRequest?.playbackTracker?.stopped(failed: errorMessage != nil) }
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
        let item = AVPlayerItem(url: plan.primaryRoute.url)
#if DEBUG
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
        output.suppressesPlayerRendering = false
        item.add(output)
        avFrameOutput = output
#endif
        installTelemetrySampler(for: plan, engineName: fallbackRendererName(for: plan))
        telemetrySampler?.sampleAVPlayer(player, item: item, reason: "itemInstalled", force: true)
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard self?.player.currentItem === item else { return }
                self?.handleItemStatus(item.status)
            }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) {
            [weak self] player, _ in
            Task { @MainActor [weak self] in
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
        connectAVControls(plan: plan)
        avControls?.startsPaused = false
        player.replaceCurrentItem(with: item)
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
        controls.currentSeconds = seconds
        let rawDuration = player.currentItem?.duration.seconds ?? 0
        if let duration = renderingPlan?.timeline.duration { controls.durationSeconds = duration }
        else if rawDuration.isFinite, rawDuration > 0 { controls.durationSeconds = rawDuration + avTimelineOffset }
        controls.isSeekable = !(player.currentItem?.seekableTimeRanges.isEmpty ?? true)
        controls.observeClock(seconds)
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
            let target = max(0, plan.timeline.startTime - avTimelineOffset)
            player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
                Task { @MainActor in
                    guard let self, self.player.currentItem === item else { return }
                    self.avInitialSeekPending = false
                    guard completed else {
                        self.errorMessage = NSLocalizedString("player.load_failed", comment: "")
                        self.recordPlayerFailure(plan: plan, error: nil, stage: "avInitialSeekFailed")
                        return
                    }
                    self.avControls?.isReady = true
                    self.updateAVClock(self.player.currentTime().seconds)
                    if self.avWantsPlayback {
                        self.player.playImmediately(atRate: self.avControls?.rate ?? 1)
                        self.probeAVFrame(reason: "initialSeek")
                    }
                    else {
                        self.player.pause()
                        // Prepare the paused replacement's video output without
                        // briefly starting audio just to obtain a preview frame.
                        self.player.preroll(atRate: self.avControls?.rate ?? 1) { [weak self] ready in
                            Task { @MainActor in
                                guard let self, self.player.currentItem === item else { return }
                                self.avControls?.event("paused_preroll_completed", metrics: ["completed": String(ready)])
                                self.probeAVFrame(reason: "pausedPreroll")
                            }
                        }
                    }
                }
            }
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

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        guard let plan = renderingPlan, lastTimeControlStatus != status else { return }
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
private struct GreenfieldAVPlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    @ObservedObject var controls: GreenfieldPlaybackControls

    final class SurfaceView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
    final class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        var pictureInPicture: AVPictureInPictureController?
        var displayObservation: NSKeyValueObservation?
        func pictureInPictureController(_ controller: AVPictureInPictureController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            completionHandler(true)
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
        pip?.delegate = context.coordinator
        context.coordinator.pictureInPicture = pip
        controls.pictureInPictureAction = { [weak coordinator = context.coordinator, weak controls] in
            guard let pip = coordinator?.pictureInPicture, pip.isPictureInPicturePossible else {
                controls?.pictureInPictureUnavailable = true
                return
            }
            pip.startPictureInPicture()
            controls?.record("pictureInPictureRequested")
        }
        return view
    }
    func updateUIView(_ view: SurfaceView, context: Context) {
        view.playerLayer.player = player
        view.playerLayer.videoGravity = controls.fillsScreen ? .resizeAspectFill : .resizeAspect
    }
    static func dismantleUIView(_ view: SurfaceView, coordinator: Coordinator) {
        coordinator.displayObservation?.invalidate()
        coordinator.displayObservation = nil
        coordinator.pictureInPicture?.stopPictureInPicture()
        coordinator.pictureInPicture = nil
        view.playerLayer.player = nil
    }
}
