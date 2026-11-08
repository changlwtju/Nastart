import SwiftUI
import AVFoundation
import AVKit
import NetworkMedia
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
    let proxyRouteLease: PlaybackProxyRouteLease?

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
        mediaRequest: MediaPlaybackRequest? = nil,
        proxyRouteLease: PlaybackProxyRouteLease? = nil
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
        self.proxyRouteLease = proxyRouteLease
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
    @State private var downloadStatus = PlaybackDownloadStatus()
    private var controls: GreenfieldPlaybackControls { usesKSPlayer ? ksControls : avControls }
    #if canImport(KSPlayer)
    @State private var preparedKSCoordinator: KSVideoPlayer.Coordinator?
    #endif
    @State private var replacementRequest: GreenfieldPlaybackLaunchRequest?
    @State private var didInitializeSession = false
    @State private var episodeNavigation: MediaPlaybackEpisodeNavigation?
    @State private var changingSource = false
    @State private var sourceChangeBlocksPlayback = false
    @State private var sourceLoadTask: Task<Void, Never>?
    @State private var pendingSourceChange: (() -> Void)?
    @State private var sourceChangeRequests = PlaybackSourceChangeRequestTracker()
    @State private var predictiveCooldown = PlaybackPredictiveCooldownPolicy()
    @State private var sourceChangeWasPlaying = false
    @State private var sourceChangeFailed = false
#if DEBUG
    @State private var debugCandidateRequested = false
#endif
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
                    sourceTrackChangeInProgress: changingSource,
                    serverSeek: serverSeekCallback,
                    qualityChange: nil,
                    previousEpisode: episodeNavigation?.previous.map { loader in { replaceSource(preservePausedState: false, loader) } },
                    nextEpisode: episodeNavigation?.next.map { loader in { replaceSource(preservePausedState: false, loader) } },
                    downloadStatus: downloadStatus,
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
                    sourceTrackChangeInProgress: changingSource,
                    serverSeek: serverSeekCallback,
                    qualityChange: nil,
                    previousEpisode: episodeNavigation?.previous.map { loader in { replaceSource(preservePausedState: false, loader) } },
                    nextEpisode: episodeNavigation?.next.map { loader in { replaceSource(preservePausedState: false, loader) } },
                    downloadStatus: downloadStatus,
                    openExternal: { handoffRequest = uiRequest }) {
                    GreenfieldAVPlayerSurface(player: model.player, controls: avControls)
                        .ignoresSafeArea()
                }
                // A committed AV plan owns new track selections and overlay
                // state, just as the KS branch above. Retaining old chrome can
                // let preparation completion restore the previous plan's menu.
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
                        closePlayer()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                }
                .foregroundStyle(.white)
                .padding(22)
                // The mounted renderer may still show its loading spinner underneath.
                .background(.black, in: RoundedRectangle(cornerRadius: 12))
            } else if (model.isPreparing || (changingSource && (sourceChangeBlocksPlayback || !controls.isPlaying)))
                        && !(model.renderingPlan != nil && controls.errorMessage == nil && controls.showsLoadingIndicator) {
                // The mounted player already presents its buffering speed and
                // spinner. Source preparation must not draw a second copy.
                VStack(spacing: 10) {
                    ProgressView().tint(.white)
                    if !uiRequest.url.isFileURL {
                        PlaybackDownloadSpeed(status: downloadStatus)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("playback.buffering.downloadSpeed")
                    }
                }
                .padding(14)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                .allowsHitTesting(false)
            }


        }
#if DEBUG
        .overlay(alignment: .topLeading) {
            if PlaybackLabLaunchRequest.candidateConfiguration(environment: ProcessInfo.processInfo.environment) != nil,
               !debugCandidateRequested {
                Button("验证候选") {
                    debugCandidateRequested = true
                    controls.event("debug_candidate_lab_requested")
                    replaceSource(keepPlayingDuringPreparation: true, reportsFailure: false) {
                        try? await PlaybackLabLaunchRequest.makeCandidateRequest(environment: ProcessInfo.processInfo.environment)
                    }
                }
                .accessibilityIdentifier("playback.lab.prepareCandidate")
                .buttonStyle(.borderedProminent)
                .disabled(!controls.isReady || controls.hasPendingSeek || changingSource)
                .padding(.leading, 130)
                .padding(.top, 54)
            }
        }
#endif
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
        .task(id: model.renderingPlan?.id) {
            await downloadStatus.follow(controls, request: uiRequest)
        }
        .onChange(of: controls.currentSeconds) { _ in saveLocalProgress() }
        .task(id: activeRequest.id) {
            // This loader negotiates a lower bitrate. A device file's Range
            // proxy fallback is not a transcode and must never be used here.
            guard PlaybackStallDownshiftPolicy.isEnabled,
                  (uiRequest.source == .jellyfin || uiRequest.source == .dsmFile),
                  PlaybackAdaptiveBitratePolicy.allowsAutomaticAdjustment(
                    selectedQualityID: uiRequest.selectedQualityID),
                  let loader = uiRequest.compatibilityFallbackRequestLoader else { return }
            var policy = PlaybackStallDownshiftPolicy()
            var reservePolicy = PlaybackReserveDepletionPolicy()
#if DEBUG
            // Opt-in fixture isolation verifies the reserve branch on a device
            // without the existing static predictor winning the same sample.
            // Reactive stall recovery remains enabled; normal launches are unchanged.
            let reservePredictionIsolation = ProcessInfo.processInfo.environment[
                "NASTART_TEST_PREDICTION_ISOLATION"] == "reserveOnly"
            if reservePredictionIsolation {
                controls.event("debug_prediction_isolation", metrics: [
                    "scope": "staticPredictorDisabled_reactiveRecoveryRetained"
                ])
            }
#else
            let reservePredictionIsolation = false
#endif
            var attemptBudget = PlaybackDownshiftAttemptBudget()
            var failedCandidateRetry = PlaybackFailedCandidateRetry<
                (MediaPlaybackRuntimeState?) async -> MediaPlaybackRequest?>(sourceID: activeRequest.id)
            var predictiveGrace = PlaybackPredictiveGracePolicy()
            var previousPlaybackSeconds: Double?
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) }
                catch { return }
                let session = controls
                // A full-screen player can keep advancing while SwiftUI reports
                // this view's scene as background during XCTest or PiP. Gate on
                // actual playback activity instead; candidate preparation keeps
                // the current stream alive and abandons an unready replacement.
                let eligible = session.isReady
                    && (session.isPlaying || session.isTransportBuffering)
                    && !session.hasPendingSeek && !changingSource && model.errorMessage == nil
                    && (session.durationSeconds <= 0 || session.currentSeconds < session.durationSeconds - 5)
#if DEBUG
                if session.isTransportBuffering {
                    session.event("automatic_downshift_sample", metrics: [
                        "eligible": String(eligible),
                        "scenePhase": String(describing: scenePhase),
                        "ready": String(session.isReady),
                        "playing": String(session.isPlaying),
                        "buffering": String(session.isTransportBuffering),
                        "pendingSeek": String(session.hasPendingSeek),
                        "changingSource": String(changingSource)
                    ])
                }
#endif
                let now = ProcessInfo.processInfo.systemUptime
                let clockAdvanced = previousPlaybackSeconds.map {
                    session.currentSeconds > $0 + 0.25
                } ?? false
                previousPlaybackSeconds = session.currentSeconds
                let repeatedStalls = policy.sample(now: now,
                    eligible: eligible, buffering: session.isTransportBuffering,
                    seekGeneration: session.seekGeneration)
                let deliveryEstimate = uiRequest.playbackTraceID.flatMap {
                    PlaybackRecentThroughputStore.shared.estimateSample(traceID: $0, now: now)
                }
                let deliveryCapacity = deliveryEstimate?.bitrate
                let graceAllowsPrediction = predictiveGrace.allows(now: now,
                    seekGeneration: session.seekGeneration,
                    qualifiedBodyWindow: deliveryEstimate?.source == .bodyWindow)
                let predictiveEligible = eligible && session.isPlaying
                    && !session.isTransportBuffering && !changingSource
                    && clockAdvanced && graceAllowsPrediction
                    && predictiveCooldown.allows(now: now)
                let runtime = session.readRuntimeTelemetry?() ?? [:]
                let runtimeDemand = PlaybackReserveDepletionPolicy.demandBitrate(
                    video: runtime["videoBitrate"].flatMap(Int.init),
                    audio: runtime["audioBitrate"].flatMap(Int.init), rate: Double(session.rate))
                let predictsReserveDepletion = reservePolicy.sample(now: now,
                    eligible: predictiveEligible, seekGeneration: session.seekGeneration,
                    currentSeconds: session.currentSeconds,
                    aheadSeconds: runtime["bufferedAheadSeconds"].flatMap(Double.init),
                    targetSeconds: runtime["bufferTargetSeconds"].flatMap(Double.init),
                    demandBitrate: runtimeDemand, measuredCapacity: deliveryCapacity)
                let sourceBitrate = PlaybackAdaptiveBitratePolicy.sourceBitrate(
                    streamBitrateCeiling: uiRequest.streamBitrateCeiling,
                    estimatedBitrate: uiRequest.estimatedBitrate,
                    byteLength: uiRequest.source == .dsmFile ? uiRequest.byteLength : nil,
                    durationSeconds: session.durationSeconds)
                let predictsUnsustainableDelivery = !reservePredictionIsolation && predictiveEligible
                    && PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
                        sourceBitrate: sourceBitrate,
                        measuredCapacity: deliveryEstimate?.predictiveBitrate,
                        isPrivateRoute: false,
                        forcesOriginal: uiRequest.selectedQualityID == "original")
#if DEBUG
                // Preserve rejected predictions as well as requests. Do not
                // resample telemetry here: that would change stall accounting.
                session.event("automatic_prediction_decision", metrics: [
                    "eligible": String(eligible),
                    "ready": String(session.isReady),
                    "playing": String(session.isPlaying),
                    "buffering": String(session.isTransportBuffering),
                    "pendingSeek": String(session.hasPendingSeek),
                    "changingSource": String(changingSource),
                    "clockAdvanced": String(clockAdvanced),
                    "graceAllowsPrediction": String(graceAllowsPrediction),
                    "cooldownAllowsPrediction": String(predictiveCooldown.allows(now: now)),
                    "predictiveEligible": String(predictiveEligible),
                    "seekGeneration": String(session.seekGeneration),
                    "currentSeconds": String(session.currentSeconds),
                    "deliveryCapacity": deliveryCapacity.map(String.init) ?? "unknown",
                    "deliveryCapacitySource": deliveryEstimate?.source.rawValue ?? "unknown",
                    "predictiveDeliveryCapacity": deliveryEstimate?.predictiveBitrate.map(String.init) ?? "unknown",
                    "sourceBitrate": sourceBitrate.map(String.init) ?? "unknown",
                    "runtimeDemand": runtimeDemand.map(String.init) ?? "unknown",
                    "bufferedAheadSeconds": runtime["bufferedAheadSeconds"] ?? "unknown",
                    "bufferTargetSeconds": runtime["bufferTargetSeconds"] ?? "unknown",
                    "predictsReserveDepletion": String(predictsReserveDepletion),
                    "predictsUnsustainableDelivery": String(predictsUnsustainableDelivery),
                    "repeatedStalls": String(repeatedStalls),
                    "attempt": String(attemptBudget.attempts)
                ])
#endif
                let staticPredictionOnly = predictsUnsustainableDelivery && !repeatedStalls && !predictsReserveDepletion
                let mayWithdrawPrediction = staticPredictionOnly && attemptBudget.canWithdrawStaticPrediction
                guard repeatedStalls || predictsUnsustainableDelivery || predictsReserveDepletion,
                      let attemptTicket = attemptBudget.begin(staticPrediction: staticPredictionOnly) else { continue }
                predictiveCooldown.requested(now: now)
                let retryTicket = failedCandidateRetry.begin()
                let attemptLoader = failedCandidateRetry.loader(or: loader)
                let state = session.runtimeState(orientationMode: uiRequest.initialOrientationMode)
                session.event("automatic_downshift_requested", metrics: [
                    "reason": repeatedStalls ? "sustainedRebuffering"
                        : predictsUnsustainableDelivery ? "deliveryBelowSourceBitrate" : "depletingOriginalReserve",
                    "attempt": String(attemptBudget.attempts),
                    "deliveryCapacity": deliveryCapacity.map(String.init) ?? "unknown",
                    "deliveryCapacitySource": deliveryEstimate?.source.rawValue ?? "unknown",
                    "runtimeDemand": runtimeDemand.map(String.init) ?? "unknown",
                    "bufferedAheadSeconds": runtime["bufferedAheadSeconds"] ?? "unknown",
                    "bufferTargetSeconds": runtime["bufferTargetSeconds"] ?? "unknown"
                ])
                replaceSource(keepPlayingDuringPreparation: true, reportsFailure: false,
                    staticPredictionBitrate: mayWithdrawPrediction ? sourceBitrate : nil,
                    onStaticPredictionRecovered: {
                        failedCandidateRetry.withdraw(ticket: retryTicket)
                        attemptBudget.withdrawRecoveredPrediction(ticket: attemptTicket)
                    }, onCandidatePreparationFailed: { candidate in
                        if failedCandidateRetry.failed(ticket: retryTicket,
                            currentSourceID: activeRequest.id, cancelled: Task.isCancelled,
                            candidateStillCurrent: true,
                            continuation: candidate.compatibilityFallbackRequestLoader) {
                            session.event("automatic_downshift_retry_context_updated", metrics: [
                                "failedCandidateCeiling": candidate.streamBitrateCeiling.map(String.init) ?? "unknown",
                                "failedCandidateTraceID": candidate.playbackTraceID ?? "unknown"
                            ])
                        }
                    }) {
                    await attemptLoader(state)
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                saveLocalProgress(force: true, boundary: .sceneInactive)
                controls.event("scene_inactive", metrics: ["phase": String(describing: phase),
                    "pip": String(controls.isPictureInPictureActive),
                    "currentSeconds": String(controls.preciseCurrentSeconds)])
            } else if didInitializeSession {
                do {
                    try GreenfieldPlaybackAudioSession.activate()
                    controls.event("scene_active", metrics: ["pip": String(controls.isPictureInPictureActive),
                        "currentSeconds": String(controls.preciseCurrentSeconds),
                        "playing": String(controls.isPlaying)])
                } catch {
                    controls.event("foreground_audio_session_failed", metrics: ["error": error.localizedDescription])
                }
            }
        }
#if os(iOS)
        // The retained UIKit player host can keep a stale SwiftUI scene phase.
        // Observe the scene's real transitions independently of that environment.
        .onReceive(NotificationCenter.default.publisher(for: UIScene.willDeactivateNotification)) { _ in
            saveLocalProgress(force: true, boundary: .sceneWillDeactivate)
            controls.event("scene_notification_inactive", metrics: [
                "pip": String(controls.isPictureInPictureActive),
                "currentSeconds": String(controls.preciseCurrentSeconds)
            ])
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.didEnterBackgroundNotification)) { _ in
            saveLocalProgress(force: true, boundary: .sceneDidEnterBackground)
            controls.event("scene_notification_background", metrics: [
                "pip": String(controls.isPictureInPictureActive),
                "currentSeconds": String(controls.preciseCurrentSeconds)
            ])
        }
#endif
        .onAppear {
            PlayerOrientationController.setPlayerActive(
                true,
                initialMode: request.orientationMode
            )
            guard !didInitializeSession else { return }
            didInitializeSession = true
            let resumeRequest = uiRequest
            for control in [ksControls, avControls] {
                control.resumeBoundaryAction = { [weak control, weak model] in
                    guard let control, let model else { return }
                    let activeControls = model.renderingPlan?.enginePolicy == .ksPlayer
                        && PlaybackEngineAvailability.ksPlayerLinked ? model.ksControls : model.avControls
                    guard activeControls === control else { return }
                    Self.persistLocalProgress(controls: control, request: resumeRequest, boundary: .nativeCallback)
                    model.checkpointPlaybackProgress(controls: control)
                }
                control.observeResumeLifecycle()
                control.pipWillStart = { [weak control, weak model] in
                    guard let control, let model else { return }
                    Self.persistLocalProgress(controls: control, request: resumeRequest, boundary: .pipWillStart)
                    model.checkpointPlaybackProgress(controls: control)
                }
                control.pipDidStart = minimizePresentation
                control.pipRestore = restorePresentation
                control.pipDidClose = { [weak model, closePresentation] in
                    model?.stop()
                    closePresentation?()
                }
            }
            ksControls.onTimelineDiscontinuity = model.resetContinuity
            avControls.onTimelineDiscontinuity = model.resetContinuity
            ksControls.pipInitialExternalSubtitleURL = uiRequest.externalSubtitleURL
            ksControls.pipExternalSubtitle.setURL(uiRequest.externalSubtitleURL)
            ksControls.traceID = activeRequest.playbackTraceID
            avControls.traceID = activeRequest.playbackTraceID
            model.avControls = avControls
            model.ksControls = ksControls
            model.start(activeRequest)
        }
        .onDisappear {
            guard !ksControls.isPictureInPictureActive && !avControls.isPictureInPictureActive else { return }
            sourceLoadTask?.cancel()
            saveLocalProgress(force: true, boundary: .viewDisappear)
            model.stop(finalPositionSeconds: controls.currentSeconds)
            PlayerOrientationController.setPlayerActive(false)
        }
    }
    private enum ResumeSaveBoundary: String {
        case close, viewDisappear, sceneInactive, sceneWillDeactivate, sceneDidEnterBackground, nativeCallback, pipWillStart
    }
    private func saveLocalProgress(force: Bool = false, boundary: ResumeSaveBoundary? = nil) {
        // An abrupt process termination cannot run the pause/exit callbacks.
        // Keep periodic checkpoints close to playback without writing each tick.
        guard force || Date().timeIntervalSince(lastLocalProgressSave) >= 2,
              Self.persistLocalProgress(controls: controls, request: uiRequest, boundary: boundary) else { return }
        lastLocalProgressSave = Date()
        if force { model.checkpointPlaybackProgress(controls: controls) }
    }
    @discardableResult
    private static func persistLocalProgress(controls: GreenfieldPlaybackControls, request: MediaPlaybackRequest,
                                             boundary: ResumeSaveBoundary? = nil) -> Bool {
#if DEBUG
        let observeMemory = boundary != nil
#else
        let observeMemory = false
#endif
        let observation = PlaybackLocalResumeCheckpoint.save(controls: controls, request: request,
                                                               observeMemory: observeMemory)
#if DEBUG
        if let boundary {
            controls.event("local_resume_save_boundary", metrics: observation.fields.merging([
                "boundary": boundary.rawValue
            ]) { _, new in new })
        }
#endif
        return observation.enteredStore
    }

    private func closePlayer() {
        saveLocalProgress(force: true, boundary: .close)
        sourceLoadTask?.cancel()
        // Keep the last frame visible through UIKit's dismissal animation.
        // onDisappear owns the final stop after the player is off screen.
        for control in [ksControls, avControls] {
            control.resumeBoundaryAction = nil
            control.pipWillStart = nil
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
                controls.sourceRuntimeStreamIndexes = (audio, subtitle)
                controls.sourceRuntimeTracks = (
                    uiRequest.sourceAudioTracks.firstIndex { $0.id == audio },
                    uiRequest.sourceSubtitleTracks.firstIndex { $0.id == subtitle },
                    subtitle == nil
                )
            } else {
                // Server burn-in/audio changes can take several seconds. Keep
                // the outgoing renderer until the muted candidate is aligned.
                replaceSource(keepPlayingDuringPreparation: true,
                    trackSelection: .init(audio: audio, subtitle: subtitle,
                        seekGeneration: controls.seekGeneration,
                        pictureInPictureGeneration: controls.pictureInPictureSessionGeneration)) {
                    await loader(audio, subtitle, state)
                }
            }
        }
    }
    private var serverSeekCallback: ((Double, MediaPlaybackRuntimeState) -> Void)? {
        guard let loader = uiRequest.serverSeekRequestLoader else { return nil }
        return { seconds, state in replaceSource { await loader(seconds, state) } }
    }
    // Manual quality changes are deferred until server preparation and handoff
    // meet the playback acceptance criteria. Automatic route/fallback stays active.
    // Keep qualityOptions, qualityRequestLoader and source replacement support:
    // only the visible entry is hidden, for a future UI reintroduction.
    private func replaceSource(preservePausedState: Bool = true, keepPlayingDuringPreparation: Bool = false,
                               playbackWasPlaying: Bool? = nil, reportsFailure: Bool = true,
                               staticPredictionBitrate: Int? = nil,
                               onStaticPredictionRecovered: (() -> Void)? = nil,
                               onCandidatePreparationFailed: ((MediaPlaybackRequest) -> Void)? = nil,
                               trackSelection: PlaybackSourceChangeRequestTracker.Tracks? = nil,
                               _ load: @escaping () async -> MediaPlaybackRequest?) {
        guard sourceChangeRequests.accept(trackSelection) else {
            controls.event("source_track_request_coalesced")
            return
        }
        guard !changingSource else {
            // Finish/clean up the current candidate, then apply the most recent
            // user selection. Dropping this request leaves the menu ahead of the
            // actual audio/subtitle stream after repeated taps.
            let wasPlaying = sourceChangeWasPlaying
            pendingSourceChange = {
                replaceSource(preservePausedState: preservePausedState,
                              keepPlayingDuringPreparation: keepPlayingDuringPreparation,
                              playbackWasPlaying: wasPlaying, reportsFailure: reportsFailure,
                              staticPredictionBitrate: staticPredictionBitrate,
                              onStaticPredictionRecovered: onStaticPredictionRecovered,
                              onCandidatePreparationFailed: onCandidatePreparationFailed,
                              trackSelection: trackSelection, load)
            }
            return
        }
        changingSource = true
        sourceChangeBlocksPlayback = !keepPlayingDuringPreparation
        let oldControls = controls
        let initialSeekGeneration = oldControls.seekGeneration
        let initialPiPGeneration = oldControls.pictureInPictureSessionGeneration
        let initialTracks = oldControls.runtimeState(orientationMode: uiRequest.initialOrientationMode)
        var recovery = PlaybackPredictiveRecoveryPolicy(startedAt: ProcessInfo.processInfo.systemUptime)
        var recoveryReported = false
        var lastRecoveryProbeUptime: TimeInterval?
        func automaticCandidateStillCurrent() -> Bool {
            // A PiP start transfers the current renderer to the system. A
            // prepared replacement must not retire that owner while its
            // floating window remains alive, even if restore completes first.
            guard pendingSourceChange == nil,
                  oldControls.canReplacePlaybackSession(pictureInPictureGeneration: initialPiPGeneration,
                    seekGeneration: keepPlayingDuringPreparation ? initialSeekGeneration : nil) else {
                return false
            }
            guard !reportsFailure else { return true }
            let latest = oldControls.runtimeState(orientationMode: uiRequest.initialOrientationMode)
            guard oldControls.seekGeneration == initialSeekGeneration
                && latest.audioTrackOrdinal == initialTracks.audioTrackOrdinal
                && latest.subtitleTrackOrdinal == initialTracks.subtitleTrackOrdinal
                && latest.subtitlesDisabled == initialTracks.subtitlesDisabled
                && latest.sourceAudioStreamIndex == initialTracks.sourceAudioStreamIndex
                && latest.sourceSubtitleStreamIndex == initialTracks.sourceSubtitleStreamIndex
                && latest.activeExternalSubtitleURL == initialTracks.activeExternalSubtitleURL else { return false }
            guard let staticPredictionBitrate else { return true }
            if recovery.recovered { return false }
            let now = ProcessInfo.processInfo.systemUptime
            if let lastRecoveryProbeUptime, now >= lastRecoveryProbeUptime,
               now - lastRecoveryProbeUptime < 0.75 { return true }
            lastRecoveryProbeUptime = now
            let estimate = uiRequest.playbackTraceID.flatMap {
                PlaybackRecentThroughputStore.shared.estimateSample(traceID: $0, now: now)
            }
            let runtime = oldControls.readRuntimeTelemetry?() ?? [:]
            let recovered = recovery.sample(now: now,
                eligible: oldControls.isPlaying && !oldControls.isTransportBuffering
                    && !oldControls.hasPendingSeek,
                currentSeconds: oldControls.preciseCurrentSeconds,
                aheadSeconds: runtime["bufferedAheadSeconds"].flatMap(Double.init),
                targetSeconds: runtime["bufferTargetSeconds"].flatMap(Double.init),
                sourceBitrate: staticPredictionBitrate,
                runtimeDemand: PlaybackReserveDepletionPolicy.demandBitrate(
                    video: runtime["videoBitrate"].flatMap(Int.init),
                    audio: runtime["audioBitrate"].flatMap(Int.init), rate: Double(oldControls.rate)),
                rate: Double(oldControls.rate), capacity: estimate?.predictiveBitrate,
                evidenceUptime: estimate?.predictionEvidenceUptime)
            if recovered, !recoveryReported {
                recoveryReported = true
                onStaticPredictionRecovered?()
                oldControls.event("automatic_downshift_recovered", metrics: [
                    "reason": "staticPredictionNoLongerSupported",
                    "sourceBitrate": String(staticPredictionBitrate),
                    "predictiveCapacity": estimate?.predictiveBitrate.map(String.init) ?? "unknown",
                    "bufferedAheadSeconds": runtime["bufferedAheadSeconds"] ?? "unknown"
                ])
            }
            return !recovered
        }
        let wasPlaying = playbackWasPlaying ?? oldControls.wantsPlayback
        sourceChangeWasPlaying = wasPlaying
        let wasPaused = preservePausedState && !wasPlaying
        if !keepPlayingDuringPreparation { oldControls.pauseForExternalHandoff() }
        sourceLoadTask = Task { @MainActor in
            var committed = false
            // Observe the original while the loader is awaited too, rather
            // than starting confirmation only after a slow candidate is ready.
            let recoveryMonitor: Task<Void, Never>? = staticPredictionBitrate == nil ? nil : Task { @MainActor in
                while !Task.isCancelled {
                    guard automaticCandidateStillCurrent() else { return }
                    do { try await Task.sleep(nanoseconds: 1_000_000_000) }
                    catch { return }
                }
            }
            defer {
                recoveryMonitor?.cancel()
                changingSource = false
                sourceChangeRequests.finish()
                sourceChangeBlocksPlayback = false
                if !committed && !reportsFailure && !Task.isCancelled {
                    oldControls.event("automatic_downshift_abandoned")
                }
                if !committed && wasPlaying && !keepPlayingDuringPreparation && !Task.isCancelled
                    && !oldControls.wantsPlayback { oldControls.togglePlayback() }
                let pending = pendingSourceChange
                pendingSourceChange = nil
                if !Task.isCancelled { pending?() }
            }
            let loaded = await load()
            guard var next = loaded else {
                sourceChangeFailed = reportsFailure && !Task.isCancelled && automaticCandidateStillCurrent()
                return
            }
            defer {
                if !committed { next.playbackTracker?.releasePreparedResources() }
            }
            guard !Task.isCancelled, pendingSourceChange == nil else { return }
            guard automaticCandidateStillCurrent() else { return }
            // Prepare the route before the final decoded alignment. There must
            // be no awaited session work after the held AV candidate returns.
            let commitPaused = keepPlayingDuringPreparation ? !oldControls.wantsPlayback : wasPaused
            if keepPlayingDuringPreparation {
                let liveState = oldControls.runtimeState(orientationMode: uiRequest.initialOrientationMode)
                next = reportsFailure
                    ? next.applyingSourceTrackRuntimePreferences(liveState)
                    : next.applyingRuntimePreferences(liveState)
            }
            let launch = next.greenfieldPlaybackLaunchRequest(playbackModePreference: activeRequest.intent.playbackModePreference)
            let preparedSession: GreenfieldVideoPlayerModel.PreparedSession
            do { preparedSession = try await GreenfieldVideoPlayerModel.prepareSession(launch) }
            catch {
                sourceChangeFailed = reportsFailure && !Task.isCancelled && automaticCandidateStillCurrent()
                return
            }
            guard !Task.isCancelled else { return }
            guard pendingSourceChange == nil, automaticCandidateStillCurrent() else { return }
            let preparedPlayer: AVPlayer?
            if next.fileExtensionHint == "m3u8" {
                oldControls.event("replacement_warmup_started")
                preparedPlayer = await GreenfieldAVPlayerWarmup.prepare(next,
                    liveClock: keepPlayingDuringPreparation ? { oldControls.preciseCurrentSeconds } : nil,
                    isPlaying: { keepPlayingDuringPreparation && oldControls.isPlaying },
                    isAdvancing: { keepPlayingDuringPreparation && oldControls.isPlaying
                        && !oldControls.isTransportBuffering },
                    liveReserve: keepPlayingDuringPreparation ? {
                        oldControls.readRuntimeTelemetry?()["bufferedAheadSeconds"].flatMap(Double.init)
                    } : nil,
                    candidateStillCurrent: automaticCandidateStillCurrent,
                    holdForCommit: keepPlayingDuringPreparation,
                    report: { stage, metrics in oldControls.event("replacement_" + stage, metrics: metrics) })
                guard !Task.isCancelled else { return }
                guard automaticCandidateStillCurrent() else {
                    preparedPlayer?.pause()
                    preparedPlayer?.replaceCurrentItem(with: nil)
                    return
                }
                guard preparedPlayer != nil else {
                    onCandidatePreparationFailed?(next)
                    sourceChangeFailed = reportsFailure
                    return
                }
                oldControls.event("replacement_warmup_completed")
            } else { preparedPlayer = nil }
            defer {
                if !committed {
                    preparedPlayer?.pause()
                    preparedPlayer?.replaceCurrentItem(with: nil)
                }
            }
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
                guard automaticCandidateStillCurrent() else { nextKSCoordinator?.resetPlayer(); return }
                guard nextKSCoordinator != nil else {
                    onCandidatePreparationFailed?(next)
                    sourceChangeFailed = reportsFailure
                    return
                }
            }
#endif
            guard pendingSourceChange == nil,
                  automaticCandidateStillCurrent() else {
#if canImport(KSPlayer)
                nextKSCoordinator?.resetPlayer()
#endif
                return
            }
            let finalPaused = keepPlayingDuringPreparation ? !oldControls.wantsPlayback : commitPaused
            let candidateBufferAhead = preparedPlayer?.currentItem?.loadedTimeRanges
                .map { $0.timeRangeValue.end.seconds - (preparedPlayer?.currentTime().seconds ?? 0) }
                .filter { $0.isFinite && $0 > 0 }.max() ?? 0
            if let preparedPlayer, let item = preparedPlayer.currentItem {
                let candidateSeconds = preparedPlayer.currentTime().seconds
                let liveSeconds = keepPlayingDuringPreparation
                    ? oldControls.preciseCurrentSeconds : preparedPlayer.currentTime().seconds
                guard item.status == .readyToPlay, !item.isPlaybackBufferEmpty,
                      PlaybackHandoffReadinessPolicy.canCommit(candidate: candidateSeconds,
                          live: liveSeconds, ranges: item.loadedTimeRanges.map {
                              (start: $0.timeRangeValue.start.seconds, end: $0.timeRangeValue.end.seconds)
                          }) else {
                    oldControls.event("replacement_warmup_failed", metrics: [
                        "stage": "commitRevalidation", "candidateSeconds": String(candidateSeconds),
                        "liveSeconds": String(liveSeconds), "candidateBufferAheadSeconds": String(candidateBufferAhead)
                    ])
                    sourceChangeFailed = reportsFailure
                    onCandidatePreparationFailed?(next)
                    return
                }
            }
            oldControls.event("replacement_committed", metrics: ["seconds": String(oldControls.currentSeconds),
                "candidateSeconds": String(preparedPlayer?.currentTime().seconds ?? -1),
                "candidateBufferAheadSeconds": String(candidateBufferAhead),
                "startsPaused": String(finalPaused)])
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
            // Automatic replacements restart the sampling task above. Keep
            // their cooldown in this view; only a successful user source
            // change (including another episode) starts a new prediction budget.
            if reportsFailure { predictiveCooldown.manualSourceCommitted() }
            model.start(launch, preparedPlayer: preparedPlayer, preparedSession: preparedSession)
            committed = true
        }
    }

}

@MainActor
final class GreenfieldVideoPlayerModel: ObservableObject {
    @Published private(set) var player = AVPlayer()
    private var preparedPlayer: AVPlayer?
    weak var avControls: GreenfieldPlaybackControls?
    weak var ksControls: GreenfieldPlaybackControls?
    private var avWantsPlayback = true
    private var avInitialSeekPending = false
    private var avInitialSeekCompleted = false
    private var avItemWasPrewarmed = false
    private var avRetainsHandoffBuffer = false
    private var avTimelineOffset: Double {
        // Jellyfin VOD HLS exposes the full media timeline. StartTimeTicks is
        // the requested position, not a new zero for the returned playlist.
        // Keep the request's start position, but seek AVPlayer to that position
        // and report its absolute clock without adding the position again.
        if request?.intent.sourceKind == .jellyfin,
           request?.fileExtensionHint?.lowercased() == "m3u8" { return 0 }
        return request?.mediaRequest?.rendererTimelineOffsetSeconds ?? 0
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
    private var avSeekObservationTask: Task<Void, Never>?
#endif
    private var telemetrySampler: PlaybackTelemetrySampler?
    private var didRecordFirstFrame = false
    private var avStartupClock = PlaybackClockStartupPolicy()
    private var didRecordThirtySecondCheckpoint = false
    private var continuitySample: (seconds: Double, uptime: Double)?
    private var continuousWallSeconds = 0.0
    func resetContinuity() { continuitySample = nil; continuousWallSeconds = 0 }
    private var lastTimeControlStatus: AVPlayer.TimeControlStatus?
    private var playbackTask: Task<Void, Never>?
    private let sessionLifetime = PlaybackSessionLifetime<PreparedSession> { prepared in
        await prepared.coordinator.finishPlayback(plan: prepared.finishingPlan)
    }
    private var failedRouteIDs = Set<UUID>()
    private var lastValidKSPlayerTime: (current: TimeInterval, total: TimeInterval?)?
    private var lastKSPlayerState: String?
    private var didRecordInvalidKSPlayerTime = false

    final class PreparedSession {
        let recorder: PlaybackDiagnosticsRecorder
        let coordinator: PlaybackSessionCoordinator
        let result: PlaybackSessionStartupResult
        // Alternate routes belong to this same session. Retire the installed
        // route rather than the original plan after an engine fallback.
        var finishingPlan: PlaybackPlan
        init(recorder: PlaybackDiagnosticsRecorder, coordinator: PlaybackSessionCoordinator,
             result: PlaybackSessionStartupResult) {
            self.recorder = recorder; self.coordinator = coordinator; self.result = result
            finishingPlan = result.plan
        }
    }

    static func prepareSession(_ request: GreenfieldPlaybackLaunchRequest) async throws -> PreparedSession {
        let recorder = PlaybackDiagnosticsRecorder(playbackTraceID: request.playbackTraceID)
        let resolver = URLPlaybackSourceResolver(
            sourceKind: request.intent.sourceKind,
            originURL: request.mediaRequest?.networkSource?.originURL,
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
        guard playbackTask == nil, let ticket = sessionLifetime.beginInitial() else { return }
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
                "requestSubtitleMode": request.subtitles?.mode.rawValue ?? "none",
                "requestSubtitleID": request.tracks.selectedSourceSubtitleTrackID ?? "none",
                "requestAudioID": request.tracks.selectedSourceAudioTrackID ?? "none",
                "requestSubtitleCount": String(request.tracks.sourceSubtitleTracks.count),
                "mediaSubtitleID": request.mediaRequest?.selectedSourceSubtitleTrackID.map(String.init) ?? "none",
                "mediaSubtitleDisabled": request.mediaRequest.map { String($0.prefersSubtitlesDisabled) } ?? "unknown",
                "outputVolume": String(audio.outputVolume),
                "outputs": audio.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
            ])
        } catch {
            avControls?.event("audio_session_failed", metrics: ["error": error.localizedDescription])
        }

        if let preparedSession {
            // Publish the ready replacement in the same UI transaction as stop;
            // do not render an intermediate empty/loading surface.
            guard sessionLifetime.commit(preparedSession, for: ticket) else {
                Task { await sessionLifetime.discard(preparedSession) }
                return
            }
            installPreparedSession(preparedSession)
            playbackTask = Task {}
            return
        }
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                let prepared = try await Self.prepareSession(request)
                guard self.sessionLifetime.commit(prepared, for: ticket) else {
                    await self.sessionLifetime.discard(prepared)
                    return
                }
                self.installPreparedSession(prepared)
            } catch {
                guard self.sessionLifetime.fail(ticket), !Task.isCancelled else { return }
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
        sessionLifetime.end()
        coordinator = nil
        player.replaceCurrentItem(with: nil)
#if DEBUG
        avFrameProbeTask?.cancel()
        avFrameProbeTask = nil
        avSeekObservationTask?.cancel()
        avSeekObservationTask = nil
        avFrameOutput = nil
#endif
        avControls?.disconnect()
        avInitialSeekPending = false
        avRetainsHandoffBuffer = false
        renderingPlan = nil
        failedRouteIDs.removeAll()
        lastValidKSPlayerTime = nil
        lastKSPlayerState = nil
        didRecordInvalidKSPlayerTime = false
        didRecordFirstFrame = false
        avStartupClock = PlaybackClockStartupPolicy()
        didRecordThirtySecondCheckpoint = false
        resetContinuity()
        lastTimeControlStatus = nil
    }

    func checkpointPlaybackProgress(controls: GreenfieldPlaybackControls) {
        let activeControls = renderingPlan?.enginePolicy == .ksPlayer
            && PlaybackEngineAvailability.ksPlayerLinked ? ksControls : avControls
        guard activeControls === controls else { return }
        controls.checkpointPlaybackProgress(using: request?.mediaRequest?.playbackTracker)
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
            runtimeMetrics: ksControls?.readRuntimeTelemetry?() ?? [:],
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
            runtimeMetrics: ksControls?.readRuntimeTelemetry?() ?? [:],
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
            // Engine text such as "avformat can't open input" stays in diagnostics only.
            errorMessage = NSLocalizedString("player.load_failed.open_input", comment: "")
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
            avRetainsHandoffBuffer = true
            recordAVHandoffBoundary("beforeConfiguration", plan: plan)
            // Warmup disables automatic waiting to align clocks. Restore normal
            // AVPlayer buffering before the candidate becomes the live stream.
            player.automaticallyWaitsToMinimizeStalling = true
            recordAVHandoffBoundary("afterWaitingPolicy", plan: plan)
            item.preferredForwardBufferDuration = 3
            recordAVHandoffBoundary("afterForwardBuffer", plan: plan)
        } else {
            item = AVPlayerItem(url: plan.primaryRoute.url)
            item.preferredForwardBufferDuration = 0.5
            avItemWasPrewarmed = false
            avRetainsHandoffBuffer = false
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
            recordAVHandoffBoundary("afterTextStyle", plan: plan)
        }
#if DEBUG
        // Adding an output to a decoded item can flush its pipeline and create
        // an empty-buffer wait caused by diagnostics. Adopt the warmup output
        // with the prepared item instead of attaching a second consumer.
        let output: AVPlayerItemVideoOutput
        if avRetainsHandoffBuffer,
           let decodedOutput = item.outputs.compactMap({ $0 as? AVPlayerItemVideoOutput }).first {
            output = decodedOutput
        } else {
            output = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
            item.add(output)
        }
        output.suppressesPlayerRendering = false
        avFrameOutput = output
        recordAVHandoffBoundary("afterVideoOutput", plan: plan)
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

    /// Synchronous snapshots keep configuration boundaries independent of the
    /// telemetry sampler's asynchronous emissions and stall bookkeeping.
    private func recordAVHandoffBoundary(_ stage: String, plan: PlaybackPlan) {
#if DEBUG
        guard avRetainsHandoffBuffer, let item = player.currentItem else { return }
        let clock = player.currentTime().seconds
        let reserve = PlaybackBufferedReservePolicy.seconds(at: clock,
            ranges: item.loadedTimeRanges.map {
                (start: $0.timeRangeValue.start.seconds, end: $0.timeRangeValue.end.seconds)
            })
        let details: [String: String] = [
                "stage": stage, "engine": "AVPlayer",
                "playbackTraceID": request?.playbackTraceID ?? "-",
                "planID": String(plan.id.uuidString.prefix(8)),
                "routeID": String(plan.primaryRoute.id.uuidString.prefix(8)),
                "currentSeconds": String(clock), "rate": String(player.rate),
                "bufferAheadSeconds": reserve.map { String($0) } ?? "unknown",
                "avTimeControlState": String(player.timeControlStatus.rawValue),
                "waitingReason": player.reasonForWaitingToPlay?.rawValue ?? "-",
                "bufferEmpty": item.isPlaybackBufferEmpty ? "yes" : "no",
                "likelyToKeepUp": item.isPlaybackLikelyToKeepUp ? "yes" : "no",
                "loadedRangeCount": String(item.loadedTimeRanges.count),
                "automaticallyWaits": player.automaticallyWaitsToMinimizeStalling ? "yes" : "no",
                "preferredForwardBufferSeconds": String(item.preferredForwardBufferDuration),
                "videoOutputCount": String(item.outputs.filter { $0 is AVPlayerItemVideoOutput }.count)
            ]
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.playback.next.av_handoff_boundary", details: details)
#endif
    }

    private func connectAVControls(plan: PlaybackPlan) {
        guard let controls = avControls else { return }
        // A prepared handoff has already passed decoded alignment and reserve
        // checks. Its paused clock can be slightly below the requested target
        // after CMTime quantization and will not advance to that target.
        // Keep the cold-start guard, using the validated attached clock only
        // for an already-ready prepared item.
        let preparedClock = player.currentTime().seconds + avTimelineOffset
        let initialPosition = avItemWasPrewarmed && player.currentItem?.status == .readyToPlay
            && preparedClock.isFinite && preparedClock >= 0
            ? preparedClock : plan.timeline.startTime
        // The AV legible group cannot describe a shared text sidecar. Seed
        // the committed request separately so readiness does not erase it.
        let initialSidecar = request?.mediaRequest?.greenfieldSubtitlesDisabled == true
            ? nil : request?.mediaRequest?.externalSubtitleURL
        controls.beginSession(initialPosition: initialPosition, initialExternalSubtitleURL: initialSidecar,
                              renderingPlanID: plan.id)
        controls.engineName = "AVPlayer"
        if let catalog = request?.tracks, request?.mediaRequest?.sourceTrackRequestLoader != nil {
            controls.sourceRuntimeStreamIndexes = (
                catalog.selectedSourceAudioTrackID.flatMap(Int.init),
                catalog.selectedSourceSubtitleTrackID.flatMap(Int.init))
            controls.sourceRuntimeTracks = (
                catalog.sourceAudioTracks.firstIndex { $0.id == catalog.selectedSourceAudioTrackID },
                catalog.sourceSubtitleTracks.firstIndex { $0.id == catalog.selectedSourceSubtitleTrackID },
                request?.mediaRequest?.greenfieldSubtitlesDisabled ?? (catalog.selectedSourceSubtitleTrackID == nil)
            )
        } else { controls.sourceRuntimeTracks = nil; controls.sourceRuntimeStreamIndexes = nil }
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
        controls.readPlaybackIntent = { [weak self] in self?.avWantsPlayback ?? false }
        controls.readRuntimeTelemetry = { [weak self] in
            guard let self, let item = self.player.currentItem,
                  let ahead = PlaybackBufferedReservePolicy.seconds(
                    at: self.player.currentTime().seconds,
                    ranges: item.loadedTimeRanges.map {
                        let range = $0.timeRangeValue
                        return (start: range.start.seconds, end: range.end.seconds)
                    }) else { return [:] }
            // AV loaded ranges use the item timeline, before the content offset.
            return ["bufferedAheadSeconds": String(ahead)]
        }
        controls.readDownloadedBytes = { [weak self] in
            guard !plan.primaryRoute.url.isFileURL,
                  let events = self?.player.currentItem?.accessLog()?.events, !events.isEmpty else { return nil }
            return events.reduce(Int64(0)) { $0 + max(0, $1.numberOfBytesTransferred) }
        }
        controls.seekPlayback = { [weak self, weak controls] seconds in
            guard let self, let controls, let item = self.player.currentItem else { return }
            let player = self.player, generation = controls.seekGeneration
            let target = max(0, seconds - self.avTimelineOffset)
#if DEBUG
            self.observeAVSeek(item: item, controls: controls, target: seconds, generation: generation)
#endif
            PlaybackSeekCommandExecutor.submit(target: target,
                isCurrent: { [weak self, weak controls, weak player] in
                    guard let self, let controls, let player else { return false }
                    return self.player === player && player.currentItem === item
                        && controls.ownsPendingSeek(generation: generation)
                }, seek: { [weak player] target, completion in
                    guard let player else { completion(false); return }
                    player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: completion)
                }, willComplete: { [weak self, weak controls] completed in
                    guard let self, let controls else { return }
#if DEBUG
                    self.avSeekObservationTask?.cancel()
                    self.avSeekObservationTask = nil
                    self.recordAVSeekBoundary(item: item, controls: controls, target: seconds,
                                              stage: "completion", completed: completed)
#endif
                    controls.seekDidComplete(completed, generation: generation)
                }, restoreIntent: { [weak self, weak controls, weak player] in
                    guard let self, let controls, let player else { return }
                    if self.avWantsPlayback { player.playImmediately(atRate: controls.rate) }
                    else { player.pause() }
                }, didComplete: { [weak self, weak player] completed in
                    guard let self, let player else { return }
                    if completed {
                        self.updateAVClock(player.currentTime().seconds)
                        self.probeAVFrame(reason: "interactiveSeek")
                    }
                })
        }
        controls.audioAction = { [weak self] in self?.selectAVTrack($0, characteristic: .audible) }
        controls.subtitleAction = { [weak self] in self?.selectAVTrack($0, characteristic: .legible) }
        controls.externalSubtitleAction = { [weak self] _ in self?.selectAVTrack(-1, characteristic: .legible) }
    }

#if DEBUG
    private func recordAVSeekBoundary(item: AVPlayerItem, controls: GreenfieldPlaybackControls,
                                      target: Double, stage: String, completed: Bool? = nil) {
        func ranges(_ values: [NSValue]) -> [(start: Double, duration: Double)] {
            values.map { ($0.timeRangeValue.start.seconds, $0.timeRangeValue.duration.seconds) }
        }
        var metrics = PlaybackSeekRangeDiagnostics.fields(
            target: target - avTimelineOffset, current: player.currentTime().seconds,
            loaded: ranges(item.loadedTimeRanges), seekable: ranges(item.seekableTimeRanges))
        metrics["stage"] = stage
        metrics["seekGeneration"] = String(controls.seekGeneration)
        metrics["contentTimelineOffsetSeconds"] = String(avTimelineOffset)
        metrics["itemStatus"] = String(item.status.rawValue)
        metrics["timeControlStatus"] = String(player.timeControlStatus.rawValue)
        metrics["waitingReason"] = player.reasonForWaitingToPlay?.rawValue ?? "none"
        metrics["playbackIntent"] = String(avWantsPlayback)
        metrics["rate"] = String(player.rate)
        metrics["bufferEmpty"] = String(item.isPlaybackBufferEmpty)
        metrics["likelyToKeepUp"] = String(item.isPlaybackLikelyToKeepUp)
        metrics["completed"] = completed.map(String.init) ?? "pending"
        if let error = (item.error ?? player.error) as NSError? {
            metrics["errorDomain"] = error.domain
            metrics["errorCode"] = String(error.code)
        }
        if let access = item.accessLog()?.events.last {
            metrics["accessLogBytes"] = String(access.numberOfBytesTransferred)
            metrics["accessLogRequests"] = String(access.numberOfMediaRequests)
            metrics["accessLogStalls"] = String(access.numberOfStalls)
        }
        if let error = item.errorLog()?.events.last {
            // Error comments, URI and server address can contain private data.
            metrics["accessErrorDomain"] = error.errorDomain
            metrics["accessErrorCode"] = String(error.errorStatusCode)
        }
        controls.event("av_seek_boundary", metrics: metrics)
    }

    private func observeAVSeek(item: AVPlayerItem, controls: GreenfieldPlaybackControls,
                               target: Double, generation: Int) {
        avSeekObservationTask?.cancel()
        recordAVSeekBoundary(item: item, controls: controls, target: target, stage: "dispatch")
        avSeekObservationTask = Task { @MainActor [weak self, weak item, weak controls] in
            var previous = 0
            for seconds in [1, 3, 10, 30, 60] {
                do { try await Task.sleep(nanoseconds: UInt64(seconds - previous) * 1_000_000_000) }
                catch { return }
                previous = seconds
                guard let self, let item, let controls, self.player.currentItem === item,
                      controls.seekGeneration == generation, controls.hasPendingSeek else { return }
                self.recordAVSeekBoundary(item: item, controls: controls, target: target,
                                          stage: "pending\(seconds)s")
            }
        }
    }
#endif

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
        controls.subtitleVideoSize = item.presentationSize
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
        if let size = player.currentItem?.presentationSize,
           size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
           controls.subtitleVideoSize != size { controls.subtitleVideoSize = size }
        let seconds = max(0, rawSeconds + avTimelineOffset)
        controls.updateClock(seconds)
        let rawDuration = player.currentItem?.duration.seconds ?? 0
        let duration = renderingPlan?.timeline.duration
            ?? (rawDuration.isFinite && rawDuration > 0 ? rawDuration + avTimelineOffset : nil)
        controls.updateTimelineMetadata(duration: duration,
            seekable: !(player.currentItem?.seekableTimeRanges.isEmpty ?? true))
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
                recordAVHandoffBoundary("beforeResume", plan: plan)
                if avWantsPlayback { player.playImmediately(atRate: avControls?.rate ?? 1) }
                else { player.pause() }
                recordAVHandoffBoundary("afterResume", plan: plan)
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
        avControls?.isTransportBuffering = status == .waitingToPlayAtSpecifiedRate
        guard let plan = renderingPlan, lastTimeControlStatus != status else { return }
        if status == .playing && !avRetainsHandoffBuffer {
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
        let controls = plan.enginePolicy == .ksPlayer && PlaybackEngineAvailability.ksPlayerLinked
            ? ksControls : avControls
        controls?.reportPlaybackTime(seconds, isPaused: paused, using: request?.mediaRequest?.playbackTracker)
        let clockAdvancing = plan.enginePolicy == .ksPlayer || avStartupClock.sample(
            seconds: seconds, uptime: ProcessInfo.processInfo.systemUptime,
            isPlaying: player.timeControlStatus == .playing && !avInitialSeekPending
                && !(avControls?.hasPendingSeek ?? false),
            seekGeneration: avControls?.seekGeneration ?? 0, rate: Double(avControls?.rate ?? 1))
        if !didRecordFirstFrame, clockAdvancing, seconds > max(plan.timeline.startTime, 0) + 0.05 {
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
        sessionLifetime.current?.finishingPlan = replacementPlan
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
            .alert("external.credential_warning.title", isPresented: $confirmsCredentials) {
                Button("external.credential_warning.continue") { openResolved() }
                Button("action.cancel", role: .cancel) {}
            } message: { Text("external.credential_warning.message") }
            .sheet(isPresented: $showsShare) {
                if let shareURL { SystemShareView(items: [shareURL], includesVideoPlayers: true) }
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
    private var playbackMetrics: [String: String] {
        (controls?.readRuntimeTelemetry?() ?? [:]).merging(
            ["currentSeconds": String(controls?.preciseCurrentSeconds ?? 0),
             "ownerPlanID": controls?.renderingPlanID?.uuidString ?? "-",
             "runtimeSnapshotUptime": String(ProcessInfo.processInfo.systemUptime)]) { _, new in new }
    }
    func pictureInPictureControllerWillStopPictureInPicture(_ controller: AVPictureInPictureController) {
        controls?.event("pip_will_stop", metrics: playbackMetrics)
    }
    func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        controls?.pictureInPictureWillStart()
        controls?.pipWillStart?()
        controls?.event("pip_will_start", metrics: playbackMetrics)
    }
    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        restoring = false
        controls?.pictureInPictureStartCompleted()
        controls?.isPictureInPictureActive = true
        controls?.retainRendererForPictureInPicture?(true)
        controls?.event("pip_started", metrics: playbackMetrics)
        controls?.pipDidStart?()
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        restoring = true
        controls?.event("pip_restore_requested", metrics: playbackMetrics)
        guard let restore = controls?.pipRestore else {
            restoring = false
            completionHandler(false)
            return
        }
        restore { [weak self] success in
            self?.restoring = success
            self?.controls?.event("pip_restore_completed", metrics: (self?.playbackMetrics ?? [:]).merging(
                ["success": String(success)]) { _, new in new })
            completionHandler(success)
        }
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        controls?.pictureInPictureStartCompleted()
        controls?.isPictureInPictureActive = false
        controls?.retainRendererForPictureInPicture?(false)
        controls?.event("pip_stopped", metrics: playbackMetrics.merging(
            ["restoring": String(restoring)]) { _, new in new })
        if !restoring { controls?.pipDidClose?() }
        restoring = false
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        controls?.pictureInPictureStartCompleted()
        controls?.isPictureInPictureActive = false
        controls?.retainRendererForPictureInPicture?(false)
        controls?.pictureInPictureUnavailable = true
        controls?.event("pip_start_failed", metrics: ["error": error.localizedDescription])
    }
}

extension View {
    func greenfieldPlaybackCover(item: Binding<GreenfieldPlaybackLaunchRequest?>) -> some View {
        background(GreenfieldPlaybackPresenter(request: item).frame(width: 0, height: 0))
    }
}

private final class GreenfieldPlaybackHostingController: UIHostingController<GreenfieldVideoPlayerView> {
    // The full-screen surface can place a bitmap subtitle in the lower black
    // bar. Let UIKit hide the idle Home indicator instead of covering that cue.
    override var prefersHomeIndicatorAutoHidden: Bool { true }
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
        // The background representable can be recreated when the underlying
        // Jellyfin detail view updates. Keep the presentation owner alive until
        // UIKit has finished dismissing the full-screen controller.
        private static var retainedPresentation: Coordinator?
        var binding: Binding<GreenfieldPlaybackLaunchRequest?>
        weak var anchor: Anchor?
        var host: UIHostingController<GreenfieldVideoPlayerView>?
        var currentID: UUID?
        var minimized = false
        private var closing = false
        private var proxyRouteLease: PlaybackProxyRouteLease?
        init(binding: Binding<GreenfieldPlaybackLaunchRequest?>) { self.binding = binding }
        func update() {
            guard !closing else { return }
            guard let request = binding.wrappedValue else {
                if host != nil && !minimized { close() }
                return
            }
            if let previous = Self.retainedPresentation, previous !== self,
               previous.currentID == request.id {
                previous.binding = binding
                return
            }
            guard currentID != request.id, let anchor, anchor.viewIfLoaded?.window != nil else { return }
            guard host == nil else { return }
            if let prior = Self.retainedPiP, prior !== self { prior.close() }
            currentID = request.id
            proxyRouteLease = request.proxyRouteLease
            let controller = GreenfieldPlaybackHostingController(rootView: GreenfieldVideoPlayerView(request: request,
                closePresentation: { [weak self] in self?.close() },
                minimizePresentation: { [weak self] in self?.minimize() },
                restorePresentation: { [weak self] completion in self?.restore(completion) ?? completion(false) }))
            controller.modalPresentationStyle = .fullScreen
            host = controller
            Self.retainedPresentation = self
            // Present from the visible hosting hierarchy, not the zero-sized
            // representable. Its anchor may be retired during a SwiftUI update,
            // which otherwise dismisses the player before its first frame.
            var presenter: UIViewController = anchor
            while let parent = presenter.parent { presenter = parent }
            while let presented = presenter.presentedViewController { presenter = presented }
            presenter.present(controller, animated: true)
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
            guard !closing else { return }
            closing = true
            let finish = { [self] in
                host = nil
                currentID = nil
                minimized = false
                binding.wrappedValue = nil
                proxyRouteLease = nil
                if Self.retainedPiP === self { Self.retainedPiP = nil }
                PlayerOrientationController.setPlayerActive(false)
                if Self.retainedPresentation === self { Self.retainedPresentation = nil }
                closing = false
            }
            if let host, host.presentingViewController != nil {
                host.dismiss(animated: true, completion: finish)
            } else {
                finish()
            }
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
    // Jellyfin's long VOD playlist plus first transcoded segment took about
    // eleven seconds on a constrained cellular link. Start the muted HLS
    // candidate ahead so its first decoded frame reaches the live playhead.
    private static var networkPreparationSeconds = 11.0

    /// A slow complete VOD manifest can outlive AV's initial resource wait.
    /// Reuse the route's complete-text cache before creating that consumer,
    /// while keeping this work inside the existing candidate deadline.
    static func prepareManifest(_ request: MediaPlaybackRequest, deadline: TimeInterval,
        candidateStillCurrent: @escaping () -> Bool = { true },
        report: (String, [String: String]) -> Void = { _, _ in }) async throws {
        guard let duration = request.totalDurationSeconds, duration.isFinite, duration > 0,
              AuthenticatedMediaStreamProxy.shared.isRegisteredPlaylistRoot(request.url) else { return }
        try Task.checkCancellation()
        guard candidateStillCurrent() else { throw CancellationError() }
        guard deadline.isFinite, deadline > ProcessInfo.processInfo.systemUptime else { throw URLError(.timedOut) }
        let started = ProcessInfo.processInfo.systemUptime
        report("candidate_manifest_preparing", [:])
        let url = request.url
        let cached = try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                try await AuthenticatedMediaStreamProxy.shared.prewarmVODPlaylist(url)
            }
            group.addTask { @MainActor in
                while candidateStillCurrent() {
                    try Task.checkCancellation()
                    guard ProcessInfo.processInfo.systemUptime < deadline else { throw URLError(.timedOut) }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                throw CancellationError()
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CancellationError() }
            return result
        }
        try Task.checkCancellation()
        guard candidateStillCurrent() else { throw CancellationError() }
        guard ProcessInfo.processInfo.systemUptime < deadline else { throw URLError(.timedOut) }
        // A live/non-cacheable manifest still follows the ordinary AV path.
        report("candidate_manifest_prepared", ["cachedVOD": String(cached),
            "elapsedMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000))])
    }
    /// Keep the current renderer running while the muted candidate decodes.
    /// Catch up to the live playhead before committing; retain the old stream
    /// on timeout instead of moving the user to an unprepared replacement.
    static func prepare(_ request: MediaPlaybackRequest,
        liveClock: (() -> Double)? = nil, isPlaying: () -> Bool = { false },
        isAdvancing: (() -> Bool)? = nil,
        liveReserve: (() -> Double?)? = nil,
        candidateStillCurrent: @escaping () -> Bool = { true },
        holdForCommit: Bool = false,
        report: (String, [String: String]) -> Void = { _, _ in }) async -> AVPlayer? {
        guard candidateStillCurrent(), !Task.isCancelled else { return nil }
        let started = ProcessInfo.processInfo.systemUptime
        let deadline = started + (request.url.pathExtension.lowercased() == "m3u8" ? 40 : 20)
        do {
            try await prepareManifest(request, deadline: deadline,
                candidateStillCurrent: candidateStillCurrent, report: report)
        } catch {
            let failure = error as NSError
            report("warmup_failed", ["stage": "manifestPreparation",
                "elapsedMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)),
                "deadlineRemainingMs": String(Int(max(deadline - ProcessInfo.processInfo.systemUptime, 0) * 1000)),
                "cancelled": String(Task.isCancelled || error is CancellationError),
                "errorDomain": failure.domain, "errorCode": String(failure.code)])
            return nil
        }
        guard candidateStillCurrent(), !Task.isCancelled,
              ProcessInfo.processInfo.systemUptime < deadline else { return nil }
        let initialSeconds = request.timelineOffsetSeconds > 0 ? request.timelineOffsetSeconds
            : (request.initialPosition ?? 0) * (request.totalDurationSeconds ?? 0)
        let availableReserve = liveReserve?()
        let preparationLead = PlaybackReplacementLeadPolicy.mediaSeconds(
            expectedPreparation: request.url.isFileURL ? 0.1 : networkPreparationSeconds,
            rate: Double(request.initialPlaybackRate),
            isAdvancing: isAdvancing?() ?? isPlaying(), availableReserve: availableReserve)
        let target = min((liveClock?() ?? initialSeconds)
            // Playback intent remains true during buffering, but its clock stops.
            // An ahead candidate cannot align until the stalled clock catches up.
            + preparationLead,
            max((request.totalDurationSeconds ?? .greatestFiniteMagnitude) - 0.1, 0))
        AuthenticatedMediaStreamProxy.shared.setPlaylistStart(request.url, seconds: target)
        let item = AVPlayerItem(url: request.url)
        item.preferredForwardBufferDuration = 0.5
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: nil)
#if DEBUG
        output.suppressesPlayerRendering = false
#endif
        item.add(output)
        let candidate = AVPlayer(playerItem: item)
        candidate.isMuted = true
        candidate.automaticallyWaitsToMinimizeStalling = false
        // Jellyfin may return a multi-megabyte VOD playlist for a long movie
        // before its first transcoded segment. Preserve the playing renderer
        // while allowing the HLS candidate enough time to produce a frame.
        var success = false
        defer {
            candidate.cancelPendingPrerolls()
#if DEBUG
            // Keep the already decoded diagnostic output attached through
            // adoption. Failed/invalidated candidates still release it here.
            if !success { item.remove(output) }
#else
            item.remove(output)
#endif
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
        // A failed handoff needs phase, clock and buffer evidence. These are
        // snapshots only: never change readiness, deadlines or playback state.
        func warmupMetrics(_ extra: [String: String] = [:]) -> [String: String] {
            let now = ProcessInfo.processInfo.systemUptime
            let position = candidate.currentTime().seconds
            let ahead = item.loadedTimeRanges.map { $0.timeRangeValue.end.seconds - position }
                .filter { $0.isFinite && $0 >= 0 }.max() ?? 0
            let error = (item.error ?? candidate.error).map { $0 as NSError }
            let access = item.accessLog()?.events.last
            let ranges = item.loadedTimeRanges.map { $0.timeRangeValue }
            var metrics: [String: String] = [
                "elapsedMs": String(Int((now - started) * 1000)),
                "deadlineRemainingMs": String(Int(max(deadline - now, 0) * 1000)),
                "target": String(target),
                "preparationLeadSeconds": String(preparationLead),
                "availableReserveSeconds": availableReserve.map { String($0) } ?? "unknown",
                "candidateSeconds": String(position),
                "liveSeconds": String(liveClock?() ?? initialSeconds),
                "candidateBufferAheadSeconds": String(ahead),
                "candidateRate": String(candidate.rate),
                "candidateStatus": String(candidate.status.rawValue),
                "itemStatus": String(item.status.rawValue),
                "timeControlStatus": String(candidate.timeControlStatus.rawValue),
                "waitingReason": candidate.reasonForWaitingToPlay?.rawValue ?? "-",
                "loadedRangeCount": String(item.loadedTimeRanges.count),
                "loadedRangeFirstStart": ranges.first.map { String($0.start.seconds) } ?? "unknown",
                "loadedRangeFirstEnd": ranges.first.map { String($0.end.seconds) } ?? "unknown",
                "bufferEmpty": String(item.isPlaybackBufferEmpty),
                "likelyToKeepUp": String(item.isPlaybackLikelyToKeepUp),
                "seekResult": seekResult.map { String($0) } ?? "pending",
                "cancelled": String(Task.isCancelled),
                "errorDomain": error?.domain ?? "-",
                "errorCode": error.map { String($0.code) } ?? "-"
            ]
            if let access {
                metrics["observedBitrate"] = String(access.observedBitrate)
                metrics["indicatedBitrate"] = String(access.indicatedBitrate)
                metrics["mediaRequests"] = String(access.numberOfMediaRequests)
                metrics["transferredBytes"] = String(access.numberOfBytesTransferred)
                metrics["transferSeconds"] = String(access.transferDuration)
                metrics["downloadedMediaSeconds"] = String(access.segmentsDownloadedDuration)
                metrics["accessLogStalls"] = String(access.numberOfStalls)
            }
            return metrics.merging(extra) { _, new in new }
        }
        // Snapshot before deferred player teardown and caller route revocation.
        // Binding is exact and route-owned, never inferred from the current
        // global player, raw error comment, host or a previous candidate.
        func reportFailure(_ extra: [String: String]) {
            let errors = item.errorLog()?.events ?? []
            let events = errors.suffix(4).map {
                PlaybackAVFailureDiagnostics.ErrorEvent(domain: $0.errorDomain,
                    status: $0.errorStatusCode, date: $0.date, uri: $0.uri)
            }
            var evidence = PlaybackAVFailureDiagnostics.fields(events: events,
                eventCount: errors.count, candidateCurrent: candidateStillCurrent()) { uri in
                AuthenticatedMediaStreamProxy.shared.diagnosticResource(uri, for: request.url)
            }
            evidence.merge(PlaybackAVFailureDiagnostics.errorChainFields(
                (item.error ?? candidate.error).map { $0 as NSError }) { uri in
                    AuthenticatedMediaStreamProxy.shared.diagnosticResource(uri, for: request.url)
                }) { _, new in new }
            let resources = ["candidateRoot_": request.url.absoluteString,
                             "candidateAccessLast_": item.accessLog()?.events.last?.uri]
            for (prefix, uri) in resources {
                for (key, value) in AuthenticatedMediaStreamProxy.shared.diagnosticResource(uri, for: request.url) {
                    evidence[prefix + key] = value
                }
            }
            report("warmup_failed", warmupMetrics(extra).merging(evidence) { _, new in new })
        }
        // Preserve phase progress for failed candidates too. One snapshot per
        // second and phase is enough to distinguish loading from catch-up;
        // never log access-log URIs, server addresses or credential material.
        var lastProgressPhase = ""
        var lastProgressAt = -Double.infinity
        func reportProgress(_ phase: String, frame: Double? = nil) {
            let now = ProcessInfo.processInfo.systemUptime
            guard phase != lastProgressPhase || now - lastProgressAt >= 1 else { return }
            lastProgressPhase = phase
            lastProgressAt = now
            report("candidate_progress", warmupMetrics([
                "stage": phase, "framePTS": frame.map { String($0) } ?? "pending"
            ]))
        }
        report("candidate_preparing", warmupMetrics())
        // Queue the resume seek before readiness so VOD does not fetch segment zero.
        candidate.seek(to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero, toleranceAfter: .zero) { completed in
            Task { @MainActor in seekResult = completed }
        }
        while (seekResult == nil || candidate.status != .readyToPlay) && item.status != .failed && candidate.status != .failed && !Task.isCancelled && candidateStillCurrent(),
              ProcessInfo.processInfo.systemUptime < deadline {
            reportProgress("initialSeek")
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        guard candidateStillCurrent() else {
            reportFailure(["stage": "candidateInvalidated"]); return nil
        }
        guard seekResult == true, candidate.status == .readyToPlay, !Task.isCancelled else {
            reportFailure(["stage": "initialSeek"]); return nil
        }
        // Full preroll may wait several seconds beyond the first decoded frame.
        // Use an actual output frame as the gate, with the old renderer running.
        if isPlaying() { candidate.playImmediately(atRate: request.initialPlaybackRate) }
        else { candidate.preroll(atRate: request.initialPlaybackRate) { _ in } }
        var firstFrame: Double?
        while firstFrame == nil, item.status != .failed, !Task.isCancelled, candidateStillCurrent(),
              ProcessInfo.processInfo.systemUptime < deadline {
            reportProgress("decodedFrame")
            var displayTime = CMTime.invalid
            let frameTime = candidate.currentTime()
            if output.copyPixelBuffer(forItemTime: frameTime,
                                      itemTimeForDisplay: &displayTime) != nil,
               displayTime.seconds.isFinite, abs(displayTime.seconds - frameTime.seconds) < 0.15 {
                firstFrame = displayTime.seconds
            } else { try? await Task.sleep(nanoseconds: 20_000_000) }
        }
        guard candidateStillCurrent() else {
            reportFailure(["stage": "candidateInvalidated"]); return nil
        }
        guard let firstFrame, !Task.isCancelled else {
            reportFailure(["stage": "decodedFrame"]); return nil
        }
        if !request.url.isFileURL {
            networkPreparationSeconds = min(max(ProcessInfo.processInfo.systemUptime - started + 0.15, 3), 15)
        }
        candidate.cancelPendingPrerolls()
        report("candidate_decoded", warmupMetrics(["framePTS": String(firstFrame),
            "prepareMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000))]))
        var lastFrame = firstFrame
        var usedBufferedSeek = false
        while !Task.isCancelled, candidateStillCurrent(), item.status != .failed, ProcessInfo.processInfo.systemUptime < deadline {
            let current = candidate.currentTime().seconds
            let live = liveClock?() ?? initialSeconds
            var displayTime = CMTime.invalid
            if output.copyPixelBuffer(forItemTime: candidate.currentTime(), itemTimeForDisplay: &displayTime) != nil,
               displayTime.seconds.isFinite { lastFrame = displayTime.seconds }
            let delta = current - live
            reportProgress("alignment", frame: lastFrame)
            if item.status == .readyToPlay, !item.isPlaybackBufferEmpty,
               PlaybackHandoffReadinessPolicy.isReady(candidate: current, live: live,
                   frame: lastFrame, ranges: item.loadedTimeRanges.map {
                       (start: $0.timeRangeValue.start.seconds, end: $0.timeRangeValue.end.seconds)
                   }) {
                if isPlaying(), !holdForCommit {
                    candidate.playImmediately(atRate: request.initialPlaybackRate)
                }
                else { candidate.pause() }
                // AV rate changes and catch-up can settle after the first clock
                // snapshot. Validate the frame actually held for commitment,
                // retaining the same clock, decoded-frame and reserve limits.
                // Access-log/range snapshots can take time while the original
                // clock advances. Collect them before the final clock check.
                var alignmentMetrics = warmupMetrics([
                    "framePTS": String(lastFrame), "evidence": "decodedFrameAndClock"
                ])
                let alignedRanges = item.loadedTimeRanges.map {
                    (start: $0.timeRangeValue.start.seconds, end: $0.timeRangeValue.end.seconds)
                }
                let alignedCurrent = candidate.currentTime().seconds
                let alignedLive = liveClock?() ?? initialSeconds
                if holdForCommit, !PlaybackHandoffReadinessPolicy.isReady(
                    candidate: alignedCurrent, live: alignedLive, frame: lastFrame,
                    ranges: alignedRanges) { continue }
                alignmentMetrics["candidate"] = String(alignedCurrent)
                alignmentMetrics["candidateSeconds"] = String(alignedCurrent)
                alignmentMetrics["current"] = String(alignedLive)
                alignmentMetrics["liveSeconds"] = String(alignedLive)
                report("candidate_aligned", alignmentMetrics)
                success = true
                return candidate
            }
            if !usedBufferedSeek, let bufferedTarget = PlaybackBufferedHandoffSeekPolicy.target(
                candidate: current, live: live, rate: Double(request.initialPlaybackRate),
                isAdvancing: isAdvancing?() ?? isPlaying(), duration: request.totalDurationSeconds,
                ranges: item.loadedTimeRanges.map {
                    let range = $0.timeRangeValue
                    return (start: range.start.seconds, end: range.end.seconds)
                }) {
                usedBufferedSeek = true
                candidate.pause()
                // An earlier output frame must never validate the new position.
                lastFrame = .nan
                var bufferedSeekResult: Bool?
                report("candidate_buffered_seek_started", warmupMetrics([
                    "fromSeconds": String(current), "bufferedTarget": String(bufferedTarget),
                    "reason": current > live ? "stalledOvershoot" : "bufferedCatchup"
                ]))
                candidate.seek(to: CMTime(seconds: bufferedTarget, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero) { completed in
                    Task { @MainActor in bufferedSeekResult = completed }
                }
                while bufferedSeekResult == nil, !Task.isCancelled, candidateStillCurrent(),
                      item.status != .failed, ProcessInfo.processInfo.systemUptime < deadline {
                    reportProgress("bufferedSeek")
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }
                guard bufferedSeekResult == true, !Task.isCancelled, candidateStillCurrent() else {
                    reportFailure([
                        "stage": candidateStillCurrent() ? "bufferedSeek" : "candidateInvalidated"
                    ])
                    return nil
                }
                report("candidate_buffered_seek_completed", warmupMetrics([
                    "bufferedTarget": String(bufferedTarget), "seekResult": "true"
                ]))
                // Decode a fresh frame while the original reaches the small
                // lead; subsequent alignment still checks frame PTS and clock.
                candidate.preroll(atRate: request.initialPlaybackRate) { _ in }
                while !lastFrame.isFinite, !Task.isCancelled, candidateStillCurrent(),
                      item.status != .failed, ProcessInfo.processInfo.systemUptime < deadline {
                    var seekFrameTime = CMTime.invalid
                    let itemTime = candidate.currentTime()
                    if output.copyPixelBuffer(forItemTime: itemTime,
                        itemTimeForDisplay: &seekFrameTime) != nil,
                       seekFrameTime.seconds.isFinite,
                       abs(seekFrameTime.seconds - itemTime.seconds) <= 0.15,
                       abs(itemTime.seconds - bufferedTarget) <= 0.1 {
                        lastFrame = seekFrameTime.seconds
                    } else {
                        reportProgress("bufferedSeekDecodedFrame")
                        try? await Task.sleep(nanoseconds: 20_000_000)
                    }
                }
                guard lastFrame.isFinite, !Task.isCancelled, candidateStillCurrent() else {
                    reportFailure([
                        "stage": candidateStillCurrent() ? "bufferedSeekDecodedFrame" : "candidateInvalidated"
                    ])
                    return nil
                }
                candidate.cancelPendingPrerolls()
                continue
            }
            // Slow playlist/segment preparation can leave a valid candidate
            // far behind the playing source. Seek and track generations above,
            // rather than clock distance, determine whether it is stale.
            if delta > 0.04 { candidate.pause() }
            else if isPlaying() {
                // Catch up once, muted, instead of restarting server transcodes
                // with repeated seeks to a continually moving target.
                candidate.playImmediately(atRate: min(request.initialPlaybackRate * 2, 4))
            } else {
                // Pause is playback intent, not candidate cancellation. A decoded
                // still frame may precede readyToPlay and a contiguous reserve.
                // Keep it held while those asynchronous updates arrive; retain
                // the existing deadline, invalidation and readiness gates.
                candidate.pause()
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        reportFailure(["stage": "alignment",
            "reason": candidateStillCurrent() ? "notAlignedBeforeDeadlineOrPlaybackStopped" : "candidateInvalidated",
            "candidate": String(candidate.currentTime().seconds),
            "current": String(liveClock?() ?? initialSeconds),
            "framePTS": String(lastFrame)])
        return nil
    }

}
