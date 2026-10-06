import SwiftUI
import CoreImage
import AVFoundation

@MainActor
final class GreenfieldPlaybackControls: PlaybackUIEngineSession {
    static func canDecodeBitmapSubtitle(_ codec: String?) -> Bool {
#if canImport(KSPlayer)
        guard let name = GreenfieldOriginalPlaybackPolicy.bitmapSubtitleDecoderName(codec) else { return false }
        return KSOptions.hasSubtitleDecoder(named: name)
#else
        return false
#endif
    }
    static func canDecodeOriginalAudio(_ codec: String?) -> Bool {
#if canImport(KSPlayer)
        guard let decoder = GreenfieldOriginalPlaybackPolicy.audioDecoderName(codec) else { return false }
        return KSOptions.hasAudioDecoder(named: decoder)
#else
        return false
#endif
    }
    @Published var currentSeconds: Double = 0
    @Published var durationSeconds: Double = 0
    @Published var isPlaying = false
    var isTransportBuffering = false
    @Published var isReady = false
    @Published var fillsScreen = false
    @Published var rate: Float = 1
    var togglePlaybackAction: (() -> Void)?
    var seekPlayback: ((Double) -> Void)?
    var readPlaybackClock: (() -> Double)?
    var readRuntimeTelemetry: (() -> [String: String])?
    var preciseCurrentSeconds: Double {
        guard pendingSeekPosition == nil, let seconds = readPlaybackClock?(), seconds.isFinite, seconds >= 0 else { return currentSeconds }
        return seconds
    }
    var onTimelineDiscontinuity: (() -> Void)?
    var updateScale: ((Bool) -> Void)?
    var updateRate: ((Float) -> Void)?

    @Published var isPictureInPictureActive = false
    var pipInitialExternalSubtitleURL: URL?
    var pipDidStart: (() -> Void)?
    var pipDidClose: (() -> Void)?
    var pipRestore: ((@escaping (Bool) -> Void) -> Void)?
    let pipDelegate = GreenfieldPiPDelegate()
    let pipExternalSubtitle = CJKSubtitleOverlayModel()
    let pipSubtitleCompositor = GreenfieldPiPSubtitleCompositor()
    @Published var pictureInPictureUnavailable = false
    @Published var isMuted = false
    @Published var isSeekable = false
    @Published var audioTracks: [PlaybackUITrack] = []
    @Published var subtitleTracks: [PlaybackUITrack] = []
    @Published var selectedAudioTrackID: Int32 = -1
    @Published var selectedSubtitleTrackID: Int32 = -1
    var muteAction: ((Bool) -> Void)?
    var audioAction: ((Int32) -> Void)?
    var subtitleAction: ((Int32) -> Void)?
    var externalSubtitleAction: ((URL?) -> Void)?
    var pictureInPictureAction: (() -> Void)?
    var sourceRuntimeTracks: (audio: Int?, subtitle: Int?, disabled: Bool)?
    private enum SubtitleSelection: Equatable {
        case embedded(Int32)
        case external(URL)
    }
    private var lastSubtitleSelection: SubtitleSelection?
    var canSeekAbsolute: ((Double) -> Bool)?
    var engineName = "KSPlayer"
    var startsPaused = false
    var traceID: String?
    var planID = "-"
    var routeID = "-"
    private var pausedAt: TimeInterval?
    private var resumeAt: TimeInterval?
    private var resumePosition = 0.0
    private var seekAt: TimeInterval?
    private var seekTarget = 0.0
    private var seekCompleted = false
    private var pendingSeekPosition: Double?
    private var bufferWarmupStartSeconds: Double?
    var hasPendingSeek: Bool { pendingSeekPosition != nil }
    var hasPendingSeekRecovery: Bool { seekAt != nil }
    func shouldRefreshPausedSubtitle(decodedTrackID: Int32, selectedTrackID: Int32?, callbackPlanID: String) -> Bool {
        !isPlaying && planID == callbackPlanID && selectedTrackID == decodedTrackID
    }
    private(set) var seekGeneration = 0
    /// Engine polling also runs while the clock is stopped. Publishing the
    /// same metadata at 10 Hz needlessly invalidates the entire player view.
    func updateTimelineMetadata(duration: Double?, seekable: Bool? = nil) {
        if let duration, duration.isFinite, duration > 0, durationSeconds != duration {
            durationSeconds = duration
        }
        if let seekable, isSeekable != seekable { isSeekable = seekable }
    }
    /// A control adapter may be reused after the other engine has played.
    /// Recovery timers and pending seek completions belong to one plan only.
    func beginSession() {
        isTransportBuffering = false
        lastSubtitleSelection = nil
        seekGeneration += 1
        seekAt = nil
        pendingSeekPosition = nil
        bufferWarmupStartSeconds = nil
        seekTarget = 0
        seekCompleted = false
        resumeAt = nil
        resumePosition = 0
        pausedAt = startsPaused ? ProcessInfo.processInfo.systemUptime : nil
    }
    func event(_ name: String, metrics: [String: String] = [:]) {
        var details = metrics
        details.merge(["engine": engineName, "playbackTraceID": traceID ?? "-", "planID": planID, "routeID": routeID]) { _, new in new }
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.playback.next." + name, details: details)
    }
    func didTogglePlayback() {
        let now = ProcessInfo.processInfo.systemUptime
        if isPlaying {
            resumeAt = now; resumePosition = currentSeconds
        } else {
            pausedAt = now
            event("paused", metrics: ["currentSeconds": String(currentSeconds)])
        }
    }
    func seekDidComplete(_ completed: Bool) {
        seekCompleted = completed
        pendingSeekPosition = nil
        if !completed {
            // A failed seek resumes at the engine's actual position, not the
            // requested target or the original session's resume position.
            bufferWarmupStartSeconds = (readPlaybackClock?()).flatMap {
                $0.isFinite && $0 >= 0 ? $0 : nil
            }
        }
        event("seek_engine_completed", metrics: ["completed": String(completed), "targetSeconds": String(seekTarget)])
    }
    func hasAdvancedForSteadyBuffer(_ seconds: Double, initialPosition: Double) -> Bool {
        !hasPendingSeek && seconds.isFinite && seconds >= 0
            && seconds > (bufferWarmupStartSeconds ?? initialPosition) + 0.05
    }
    /// Keep the requested position visible until the engine finishes seeking.
    /// Demux/network work can continue emitting the previous clock meanwhile.
    func updateClock(_ seconds: Double) {
        guard seconds.isFinite, seconds >= 0, pendingSeekPosition == nil else { return }
        currentSeconds = seconds
        observeClock(seconds)
    }
    func observeClock(_ seconds: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        if let resumeAt, isPlaying, seconds > resumePosition + 0.05 {
            event("resumed", metrics: ["resumeRecoveryMs": String(Int((now - resumeAt) * 1000)),
                "pauseDurationMs": String(Int((resumeAt - (pausedAt ?? resumeAt)) * 1000)), "evidence": "advancingPlaybackClock"])
            self.resumeAt = nil; pausedAt = nil
        }
        // Engine completion can publish the requested clock while transport
        // is still buffering. Require advancing playback before reporting
        // recovery; this remains clock evidence, not a visible-frame metric.
        if let seekAt, seekCompleted, isPlaying, !isTransportBuffering,
           seconds > seekTarget + 0.05, abs(seconds - seekTarget) < 2 {
            event("seek_recovered", metrics: ["seekRecoveryMs": String(Int((now - seekAt) * 1000)),
                "currentSeconds": String(seconds), "seekTargetSeconds": String(seekTarget), "evidence": "engineCompletionAndAdvancingClock"])
            self.seekAt = nil
        }
    }
    var errorMessage: String? { nil } // Session coordinator owns failures/recovery.
    var position: Double { durationSeconds > 0 ? currentSeconds / durationSeconds : 0 }
    var isBuffering: Bool { !isReady }
    var hasStartedPlayback: Bool { isReady }
    var currentTimeSeconds: Double { currentSeconds }
    var playbackRate: Float { rate }
    var currentTimeText: String { Self.time(currentSeconds) }
    var durationText: String { Self.time(durationSeconds) }
    var initialLoadTimeoutNanoseconds: UInt64 { 0 }
    var usesSourceTrackSelectionForRuntimeState: Bool { true }
    var supportsPictureMode: Bool { true }
    func setFillsScreen(_ fills: Bool) { fillsScreen = fills; updateScale?(fills); record("pictureMode", value: fills ? "fill" : "fit") }
    func play() {} // Renderer owns lifecycle; mounting chrome must not restart playback.
    func stop() {}
    func failIfStillLoading() {}
    func initialLoadGraceNanosecondsIfNeeded() -> UInt64 { 0 }
    func recoverIfStalled() {}
    func togglePlayback() { togglePlaybackAction?() }
    func toggleMute() { isMuted.toggle(); muteAction?(isMuted); record("mute", value: String(isMuted)) }
    func seek(to position: Double) { seekSeconds(position * durationSeconds) }
    func seek(toAbsoluteSeconds seconds: Double) -> Bool {
        guard isReady, isSeekable, seekPlayback != nil, seconds.isFinite,
              durationSeconds > 0, canSeekAbsolute?(seconds) != false else { return false }
        seekSeconds(seconds); return true
    }
    func jump(by seconds: Int) { seekSeconds(preciseCurrentSeconds + Double(seconds)) }
    func setPlaybackRate(_ rate: Float) { self.rate = rate; updateRate?(rate); record("playbackRate", value: String(rate)) }
    func selectAudio(_ track: PlaybackUITrack) {
        guard selectedAudioTrackID != track.id else { return }
        audioAction?(track.id)
    }
    func selectSubtitle(_ track: PlaybackUITrack) { selectSourceSubtitle(track.id, externalURL: nil) }
    func selectSourceSubtitle(_ id: Int32?, externalURL: URL?) {
        // The shared overlay owns sidecar text. Selecting an audio track must
        // not re-enable the matching embedded subtitle underneath it.
        if let externalURL, externalSubtitleAction != nil {
            let selection = SubtitleSelection.external(externalURL)
            guard lastSubtitleSelection != selection else { return }
            externalSubtitleAction?(externalURL)
            lastSubtitleSelection = selection
            selectedSubtitleTrackID = -1
        } else {
            guard let subtitleAction else { return }
            let selection = SubtitleSelection.embedded(id ?? -1)
            guard lastSubtitleSelection != selection else { return }
            subtitleAction(id ?? -1)
            lastSubtitleSelection = selection
        }
    }
    func selectExternalSubtitle(_ url: URL?) -> Bool {
        guard externalSubtitleAction != nil else { return false }
        selectSourceSubtitle(nil, externalURL: url)
        return true
    }
    func pauseForExternalHandoff() { if isPlaying { togglePlayback() } }
    func runtimeState(orientationMode: PlayerOrientationMode) -> MediaPlaybackRuntimeState {
        MediaPlaybackRuntimeState(normalizedPosition: position, positionSeconds: currentSeconds,
            playbackRate: rate, audioTrackOrdinal: sourceRuntimeTracks.map { $0.audio } ?? audioTracks.firstIndex { $0.id == selectedAudioTrackID },
            subtitleTrackOrdinal: sourceRuntimeTracks.map { $0.subtitle } ?? subtitleTracks.filter { $0.id >= 0 }.firstIndex { $0.id == selectedSubtitleTrackID },
            subtitlesDisabled: sourceRuntimeTracks?.disabled ?? (selectedSubtitleTrackID < 0), subtitleSelectionKnown: isReady,
            orientationMode: orientationMode)
    }
    private static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let value = Int(seconds)
        return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
            : String(format: "%02d:%02d", value / 60, value % 60)
    }

    func seekSeconds(_ seconds: Double) {
        guard isReady, isSeekable, seconds.isFinite, durationSeconds > 0,
              let seekPlayback else { return }
        let target = min(max(seconds, 0), max(durationSeconds - 0.1, 0))
        onTimelineDiscontinuity?()
        seekGeneration += 1
        seekAt = ProcessInfo.processInfo.systemUptime; seekTarget = target; seekCompleted = false
        bufferWarmupStartSeconds = target
        event("seek_started", metrics: ["seekTargetSeconds": String(target), "seekDeltaSeconds": String(target - currentSeconds)])
        pendingSeekPosition = target
        currentSeconds = target
        let dispatchedAt = ProcessInfo.processInfo.systemUptime
        seekPlayback(target)
        event("seek_dispatched", metrics: ["mainThreadSubmissionMs": String((ProcessInfo.processInfo.systemUptime - dispatchedAt) * 1000)])
        record("seekRequested", value: String(format: "%.3f", target))
    }

    func record(_ action: String, value: String = "-") {
        event("control_action", metrics: ["action": action, "value": value])
    }

    func disconnect() {
        seekGeneration += 1
        seekAt = nil; resumeAt = nil; pausedAt = nil
        pendingSeekPosition = nil
        bufferWarmupStartSeconds = nil
        seekCompleted = false
        canSeekAbsolute = nil
        togglePlaybackAction = nil
        seekPlayback = nil
        readPlaybackClock = nil
        readRuntimeTelemetry = nil
        updateScale = nil
        updateRate = nil
        muteAction = nil; audioAction = nil; subtitleAction = nil
        externalSubtitleAction = nil; pictureInPictureAction = nil
        isReady = false; isSeekable = false
        isPlaying = false
        isTransportBuffering = false
    }
}

#if canImport(KSPlayer)
import KSPlayer

private final class GreenfieldKSOptions: KSOptions {
    var sourceAudioID: Int32?
    override func wantedAudio(tracks: [MediaPlayerTrack]) -> Int? {
        guard let sourceAudioID else { return nil }
        return tracks.firstIndex { $0.trackID == sourceAudioID }
    }
}

private struct GreenfieldSubtitleOverlay: View {
    @ObservedObject var model: SubtitleModel
    let videoSize: CGSize

    var body: some View {
        if model.parts.contains(where: { $0.image != nil }), videoSize.width > 0, videoSize.height > 0 {
            GeometryReader { geometry in
                VStack(spacing: 4) {
                    Spacer(minLength: 0)
                    ForEach(model.parts) { part in
                        if let image = part.image {
                            let size = part.imageDisplaySize(in: geometry.size, videoSize: videoSize)
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: size.width, height: size.height)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                ForEach(model.parts) { part in
                    if let text = part.text?.string, !text.isEmpty {
                        PlaybackSubtitleText(text: text)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct GreenfieldKSPlayerRenderer: View {
    let plan: PlaybackPlan
    @ObservedObject var controls: GreenfieldPlaybackControls
    let onUnsupported: () -> Void
    let onStateChanged: (String) -> Void
    let onPlaybackTime: (TimeInterval, TimeInterval) -> Void
    let onFinished: (String?, GreenfieldKSPlayerRuntimeSnapshot?) -> Void
    let onBufferChanged: (Int, TimeInterval) -> Void

    @StateObject private var coordinator: KSVideoPlayer.Coordinator
    private let wasPrewarmed: Bool
    @State private var appliedInitialTracks = false
    @State private var steadyStateBufferGeneration: Int?

    init(plan: PlaybackPlan, controls: GreenfieldPlaybackControls,
         onUnsupported: @escaping () -> Void, onStateChanged: @escaping (String) -> Void,
         onPlaybackTime: @escaping (TimeInterval, TimeInterval) -> Void,
         onFinished: @escaping (String?, GreenfieldKSPlayerRuntimeSnapshot?) -> Void,
         onBufferChanged: @escaping (Int, TimeInterval) -> Void,
         preparedCoordinator: KSVideoPlayer.Coordinator? = nil) {
        self.plan = plan
        self.controls = controls
        self.onUnsupported = onUnsupported
        self.onStateChanged = onStateChanged
        self.onPlaybackTime = onPlaybackTime
        self.onFinished = onFinished
        self.onBufferChanged = onBufferChanged
        self.wasPrewarmed = preparedCoordinator != nil
        _coordinator = StateObject(wrappedValue: preparedCoordinator ?? KSVideoPlayer.Coordinator())
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            KSVideoPlayer(
                coordinator: coordinator,
                url: plan.primaryRoute.url,
                options: Self.makeOptions(plan: plan, controls: controls, coordinator: coordinator)
            )
            .onStateChanged { layer, state in
                controls.isReady = layer.player.isReadyToPlay
                syncTracks(layer)
                controls.isPlaying = layer.state.isPlaying
                controls.isTransportBuffering = state == .buffering
                onStateChanged(state.description)
            }
            .onPlay { currentTime, totalTime in
                if currentTime.isFinite, currentTime >= 0 {
                    controls.updateClock(currentTime)
                    if steadyStateBufferGeneration != controls.seekGeneration,
                       controls.hasAdvancedForSteadyBuffer(currentTime, initialPosition: plan.timeline.startTime),
                       let layer = coordinator.playerLayer {
                        steadyStateBufferGeneration = controls.seekGeneration
                        let seconds = PlaybackPlanningPolicy.steadyStateBufferSeconds(
                            routeKind: plan.primaryRoute.routeKind,
                            upstreamAddressKind: plan.intent.connectionContext.addressKind,
                            startupSeconds: layer.options.preferredForwardBufferDuration
                        )
                        if seconds > layer.options.preferredForwardBufferDuration {
                            layer.options.preferredForwardBufferDuration = seconds
                            layer.options.maxBufferDuration = max(layer.options.maxBufferDuration, seconds * 4)
                            controls.event("steady_state_buffer", metrics: [
                                "seconds": String(seconds),
                                "upstreamAddressKind": plan.intent.connectionContext.addressKind.rawValue
                            ])
                        }
                    }
                }
                if let duration = plan.timeline.duration, duration.isFinite, duration > 0 {
                    controls.updateTimelineMetadata(duration: duration)
                } else if totalTime.isFinite, totalTime > 0 {
                    controls.updateTimelineMetadata(duration: totalTime)
                }
                if let layer = coordinator.playerLayer { syncTracks(layer) }
                onPlaybackTime(currentTime, totalTime)
            }
            .onFinish { layer, error in
                onFinished(error.map(Self.describe), Self.snapshot(layer))
            }
            .onBufferChanged { bufferedCount, consumeTime in
                onBufferChanged(bufferedCount, consumeTime)
            }
            .overlay(alignment: .bottom) {
                GreenfieldSubtitleOverlay(model: coordinator.subtitleModel,
                    videoSize: coordinator.playerLayer?.player.naturalSize ?? .zero)
                    .padding(.horizontal, 24).padding(.bottom, 36)
                    .allowsHitTesting(false)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .onAppear {
                Self.configureDefaultEngine()
                if !controls.isPictureInPictureActive { connectControls() }
                if wasPrewarmed, let layer = coordinator.playerLayer {
                    let paused = controls.startsPaused
                    controls.isReady = layer.player.isReadyToPlay
                    syncTracks(layer)
                    coordinator.isMuted = controls.isMuted
                    layer.options.registerRemoteControll = true
                    layer.registerRemoteControllEvent()
                    if paused { layer.pause() } else { layer.play() }
                    controls.isPlaying = !paused
                    controls.updateClock(layer.player.currentPlaybackTime)
                }
                onStateChanged("rendererAppeared")
            }
            .onDisappear {
                // SwiftUI may retire the previous surface after the replacement
                // has already connected. Only disconnect this surface's plan.
                if !controls.isPictureInPictureActive,
                   controls.planID == String(plan.id.uuidString.prefix(8)) {
                    controls.disconnect()
                }
            }
        } else {
            Color.black
                .ignoresSafeArea()
                .onAppear(perform: onUnsupported)
        }
    }

    private func connectControls() {
        controls.beginSession()
        controls.planID = String(plan.id.uuidString.prefix(8))
        controls.routeID = String(plan.primaryRoute.id.uuidString.prefix(8))
        controls.rate = plan.intent.playbackRate
        controls.currentSeconds = plan.timeline.startTime
        controls.durationSeconds = plan.timeline.duration ?? 0
        coordinator.isScaleAspectFill = controls.fillsScreen
        controls.togglePlaybackAction = { [weak coordinator, weak controls] in
            guard let layer = coordinator?.playerLayer, let controls else { return }
            if layer.state.isPlaying { layer.pause() } else { layer.play() }
            controls.isPlaying = layer.state.isPlaying
            controls.didTogglePlayback()
            controls.record(controls.isPlaying ? "play" : "pause")
        }
        controls.readPlaybackClock = { [weak coordinator] in coordinator?.playerLayer?.player.currentPlaybackTime ?? .nan }
        controls.readRuntimeTelemetry = { [weak coordinator] in
            guard let layer = coordinator?.playerLayer,
                  let info = layer.player.dynamicInfo else { return [:] }
            return [
                "bytesRead": String(info.bytesRead),
                "displayFPS": String(format: "%.1f", info.displayFPS),
                "droppedVideoFrames": String(info.droppedVideoFrameCount),
                "droppedVideoPackets": String(info.droppedVideoPacketCount),
                "videoBitrate": String(info.videoBitrate),
                "audioBitrate": String(info.audioBitrate),
                "bufferedAheadSeconds": String(max(0, layer.player.playableTime - layer.player.currentPlaybackTime)),
                "bufferTargetSeconds": String(layer.options.preferredForwardBufferDuration),
                "bufferLimitSeconds": String(layer.options.maxBufferDuration)
            ]
        }
        controls.seekPlayback = { [weak coordinator, weak controls] seconds in
            guard let layer = coordinator?.playerLayer else { return }
            let wasPlaying = layer.state.isPlaying
            let generation = controls?.seekGeneration
            // A new position needs a fast first frame again. The larger
            // steady-state reserve is restored after its clock advances.
            layer.options.preferredForwardBufferDuration = max(plan.startupPolicy.minimumPlayableBufferSeconds, 0.25)
            layer.seek(time: seconds, autoPlay: wasPlaying) { completed in
                Task { @MainActor [weak coordinator, weak controls] in
                    guard let controls, controls.seekGeneration == generation,
                          let player = coordinator?.playerLayer?.player else { return }
                    controls.seekDidComplete(completed)
                    let actual = player.currentPlaybackTime
                    if completed, actual.isFinite, actual >= 0 {
                        controls.updateClock(actual)
                        _ = coordinator?.subtitleModel.subtitle(currentTime: actual)
                    }
                }
            }
        }
        controls.updateScale = { [weak coordinator] fills in
            coordinator?.isScaleAspectFill = fills
        }
        controls.updateRate = { [weak coordinator] rate in coordinator?.playbackRate = rate }
        controls.muteAction = { [weak coordinator] muted in coordinator?.isMuted = muted }
        controls.audioAction = { [weak coordinator, weak controls] id in
            guard let player = coordinator?.playerLayer?.player,
                  let track = player.tracks(mediaType: .audio).first(where: { $0.trackID == id }) else { return }
            guard !track.isEnabled else { return }
            let started = ProcessInfo.processInfo.systemUptime
            controls?.record("audioTrackRequested", value: String(id))
            player.select(track: track)
            let selected = player.tracks(mediaType: .audio).first { $0.isEnabled }?.trackID ?? -1
            controls?.selectedAudioTrackID = selected
            controls?.event("audio_track_changed", metrics: ["engineTrackID": String(selected), "requestedTrackID": String(id),
                "selectionDispatchMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)),
                "evidence": "engineTrackInventoryNotAudibleRecovery"] )
        }
        controls.subtitleAction = { [weak coordinator, weak controls] id in
            guard let coordinator, let player = coordinator.playerLayer?.player else { return }
            let selectedID = coordinator.subtitleModel.selectedSubtitleInfo.flatMap { Int32($0.subtitleID) } ?? -1
            guard selectedID != id || controls?.pipExternalSubtitle.isEnabled == true else { return }
            let started = ProcessInfo.processInfo.systemUptime
            controls?.record("subtitleTrackRequested", value: String(id))
            controls?.pipExternalSubtitle.setURL(nil)
            let tracks = player.tracks(mediaType: .subtitle)
            let paused = controls?.isPlaying == false
            let displayToken = "\(controls?.planID ?? "-"):\(controls?.seekGeneration ?? -1)"
            let currentTime = player.currentPlaybackTime
            if paused {
                coordinator.subtitleModel.rememberPausedImageSubtitle(currentTime: currentTime, token: displayToken)
            }
            // The demuxer may already have selected this track before opening.
            // Preserve it when connecting the subtitle model to the prepared
            // decoder; paths with image-subtitle seeking must not seek twice.
            let target = tracks.first(where: { $0.trackID == id })
            let returningBitmap = target?.isImageSubtitle == true && target?.isEnabled == false
            let reusedPausedDisplay: Bool
            if paused, returningBitmap, let bitmap = target as? FFmpegAssetTrack {
                reusedPausedDisplay = bitmap.restorePausedImageSubtitle(
                    at: currentTime - bitmap.delay - coordinator.subtitleModel.subtitleDelay,
                    token: displayToken)
            } else { reusedPausedDisplay = false }
            let refreshBitmap = returningBitmap && !reusedPausedDisplay
            if let target, !target.isEnabled { player.select(track: target) }
            coordinator.subtitleModel.selectedSubtitleInfo = player.subtitleDataSouce?.infos
                .first(where: { $0.subtitleID == String(id) })
            for track in tracks where track.trackID != id { track.isEnabled = false }
            _ = coordinator.subtitleModel.subtitle(currentTime: player.currentPlaybackTime)
            controls?.selectedSubtitleTrackID = id
            if reusedPausedDisplay {
                controls?.event("subtitle_paused_display_reused", metrics: [
                    "requestedTrackID": String(id), "currentSeconds": String(currentTime),
                    "evidence": "samePausedPositionDecodedCueNotScreenPresentation"
                ])
            }
            // Re-read the current display set for a newly enabled bitmap track.
            // Use the normal seek lifecycle so paused playback stays paused and
            // a later selection supersedes the previous completion.
            if refreshBitmap { _ = controls?.seek(toAbsoluteSeconds: player.currentPlaybackTime) }
            controls?.event("subtitle_track_changed", metrics: ["requestedTrackID": String(id),
                "selectionDispatchMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)),
                "visibleParts": String(coordinator.subtitleModel.parts.count),
                "evidence": "selectionAndCueInventoryNotScreenPresentation"])
        }
        controls.externalSubtitleAction = { [weak coordinator, weak controls] url in
            if controls?.isPlaying == false, let coordinator,
               let player = coordinator.playerLayer?.player {
                coordinator.subtitleModel.rememberPausedImageSubtitle(
                    currentTime: player.currentPlaybackTime,
                    token: "\(controls?.planID ?? "-"):\(controls?.seekGeneration ?? -1)")
            }
            controls?.pipExternalSubtitle.setURL(url)
            coordinator?.subtitleModel.selectedSubtitleInfo = nil
            _ = coordinator?.subtitleModel.subtitle(currentTime: coordinator?.playerLayer?.player.currentPlaybackTime ?? 0)
            for track in coordinator?.playerLayer?.player.tracks(mediaType: .subtitle) ?? [] { track.isEnabled = false }
        }
        controls.pictureInPictureAction = { [weak coordinator, weak controls] in
            guard let layer = coordinator?.playerLayer, let pip = layer.player.pipController, pip.isPictureInPicturePossible else {
                controls?.pictureInPictureUnavailable = true
                controls?.event("pip_unavailable"); return
            }
            controls?.pipDelegate.controls = controls
            pip.delegate = controls?.pipDelegate
            pip.startPictureInPicture()
            controls?.record("pictureInPictureRequested")
        }
    }

    private func syncTracks(_ layer: KSPlayerLayer) {
        if layer.player.isReadyToPlay, controls.audioAction != nil, !appliedInitialTracks {
            appliedInitialTracks = true
            let video = layer.player.tracks(mediaType: .video).first
            let dolby = PlaybackDolbySourceInfo(visionProfile: video?.dovi.map { Int($0.dv_profile) },
                visionLevel: video?.dovi.map { Int($0.dv_level) },
                baseLayerCompatibilityID: video?.dovi.map { Int($0.dv_bl_signal_compatibility_id) })
            controls.event("source_capabilities", metrics: dolby.diagnosticDetails.merging([
                "metadataEvidence": "engineTrackInventory", "audioPath": "decodedPCM",
                "videoBitDepth": video.map { String($0.bitDepth) } ?? "unknown",
                "dvEnhancementLayer": video?.dovi.map { String($0.el_present_flag) } ?? "unknown",
                "hdrDisplayEligible": String(AVPlayer.eligibleForHDRPlayback),
                "audioOutputPorts": AVAudioSession.sharedInstance().currentRoute.outputs
                    .map { $0.portType.rawValue }.joined(separator: ",")
            ]) { _, new in new })
            if controls.startsPaused {
                layer.pause()
                let expectedPlanID = controls.planID
                if !wasPrewarmed {
                    layer.seek(time: plan.timeline.startTime, autoPlay: false) { [weak layer, weak controls] completed in
                        Task { @MainActor in
                            guard completed, let layer, let controls,
                                  controls.planID == expectedPlanID else { return }
                            let actual = layer.player.currentPlaybackTime
                            if actual.isFinite { controls.currentSeconds = actual }
                        }
                    }
                }
                controls.startsPaused = false
            }
            if plan.primaryRoute.playMethod == .directPlay {
                if let id = plan.tracks.selectedSourceAudioTrackID.flatMap(Int32.init) {
                    controls.audioAction?(id)
                }
                let subtitleID = plan.subtitles.mode == .disabled ? nil : plan.tracks.selectedSourceSubtitleTrackID.flatMap(Int32.init)
                controls.selectSourceSubtitle(subtitleID,
                    externalURL: controls.pipInitialExternalSubtitleURL)
            }
        }
        controls.updateTimelineMetadata(duration: nil, seekable: layer.player.seekable)
        let audio = layer.player.tracks(mediaType: .audio)
        let subtitles = layer.player.tracks(mediaType: .subtitle)
        let audioOptions = audio.map { PlaybackUITrack(id: $0.trackID, name: $0.name) }
        let subtitleOptions = [PlaybackUITrack(id: -1, name: NSLocalizedString("player.subtitles.off", comment: ""))]
            + subtitles.map { PlaybackUITrack(id: $0.trackID, name: $0.name) }
        if controls.audioTracks != audioOptions { controls.audioTracks = audioOptions }
        if controls.subtitleTracks != subtitleOptions {
            controls.subtitleTracks = subtitleOptions
            controls.event("subtitle_inventory", metrics: ["count": String(subtitles.count),
                "trackIDs": subtitles.map { String($0.trackID) }.joined(separator: ",")])
        }
        let audioID = audio.first { $0.isEnabled }?.trackID ?? -1
        if controls.selectedAudioTrackID != audioID {
            controls.selectedAudioTrackID = audioID
            controls.event("audio_track_changed", metrics: ["engineTrackID": String(audioID), "evidence": "engineTrackInventory"])
        }
        let subtitleID = coordinator.subtitleModel.selectedSubtitleInfo.flatMap { Int32($0.subtitleID) } ?? -1
        if controls.selectedSubtitleTrackID != subtitleID { controls.selectedSubtitleTrackID = subtitleID }
    }

    private static func makeOptions(plan: PlaybackPlan, controls: GreenfieldPlaybackControls,
                                    coordinator: KSVideoPlayer.Coordinator) -> KSOptions {
        let options = GreenfieldKSOptions()
        var lastPiPSubtitleReport = -Double.infinity
        options.pictureInPictureFrameTransform = { [weak controls, weak coordinator] buffer, _ in
            guard let controls, controls.isPictureInPictureActive, let coordinator,
                  let player = coordinator.playerLayer?.player else { return nil }
            let seconds = player.currentPlaybackTime
            controls.pipExternalSubtitle.update(time: seconds)
            _ = coordinator.subtitleModel.subtitle(currentTime: seconds)
            let parts = coordinator.subtitleModel.parts
            let text = controls.pipExternalSubtitle.isEnabled
                ? controls.pipExternalSubtitle.text
                : parts.compactMap { $0.text?.string }.joined(separator: "\n")
            let images: [(UIImage, CGPoint, CGSize)] = controls.pipExternalSubtitle.isEnabled ? [] : parts.compactMap { part in
                guard let image = part.image else { return nil }
                return (image, part.origin, part.imageCanvasSize)
            }
            let output = controls.pipSubtitleCompositor.composite(buffer, text: text, images: images,
                videoSize: player.naturalSize)
            if seconds - lastPiPSubtitleReport > 5 || seconds < lastPiPSubtitleReport {
                lastPiPSubtitleReport = seconds
                controls.event("pip_subtitle_frame", metrics: ["seconds": String(seconds),
                    "textLength": String(text?.count ?? 0), "imageCount": String(images.count),
                    "external": String(controls.pipExternalSubtitle.isEnabled), "composited": String(output != nil)])
            }
            return output
        }
        let expectedPlanID = String(plan.id.uuidString.prefix(8))
        options.embeddedSubtitleFrameDecoded = { [weak controls, weak coordinator] trackID in
            Task { @MainActor [weak controls, weak coordinator] in
                guard let controls, let coordinator, let player = coordinator.playerLayer?.player,
                      controls.shouldRefreshPausedSubtitle(decodedTrackID: trackID,
                        selectedTrackID: coordinator.subtitleModel.selectedSubtitleInfo.flatMap { Int32($0.subtitleID) },
                        callbackPlanID: expectedPlanID) else { return }
                // Pausing stops KSPlayerLayer's progress timer. A bitmap arriving
                // after seek completion still needs to update the stopped frame.
                _ = coordinator.subtitleModel.subtitle(currentTime: player.currentPlaybackTime)
            }
        }
        options.videoDecoderSelected = { [weak controls] mode in
            Task { @MainActor [weak controls] in
                guard let controls, controls.planID == expectedPlanID else { return }
                controls.event("video_decoder_selected", metrics: ["mode": mode])
            }
        }
        var recordedFirstSubmission = false
        options.videoFrameSubmitted = { [weak controls] seconds, forced in
            guard forced || !recordedFirstSubmission else { return }
            recordedFirstSubmission = true
            Task { @MainActor [weak controls] in
                guard let controls, controls.planID == expectedPlanID else { return }
                controls.event("video_frame_submitted", metrics: [
                    "framePTSSeconds": String(seconds),
                    "controlSeconds": String(controls.currentSeconds),
                    "forcedPreview": String(forced),
                    "evidence": "rendererSubmissionNotPresentation"
                ])
            }
        }
        if plan.primaryRoute.playMethod == .directPlay {
            options.sourceAudioID = plan.tracks.selectedSourceAudioTrackID.flatMap(Int32.init)
            if plan.subtitles.mode != .disabled, controls.pipInitialExternalSubtitleURL == nil {
                options.preferredEmbeddedSubtitleTrackID = plan.tracks.selectedSourceSubtitleTrackID.flatMap(Int32.init)
            }
        }
        configureDefaultEngine()
        options.preferredForwardBufferDuration = max(plan.startupPolicy.minimumPlayableBufferSeconds, 0.25)
        options.maxBufferDuration = max(plan.startupPolicy.minimumPlayableBufferSeconds * 4, 6)
        options.startPlayTime = plan.timeline.startTime
        options.startPlayRate = plan.intent.playbackRate
        options.isAccurateSeek = true
        options.isSecondOpen = false
        options.nobuffer = plan.intent.networkContext.isExpensive || plan.intent.networkContext.isConstrained
        options.probesize = 5 * 1024 * 1024
        options.maxAnalyzeDuration = 2_000_000
        options.forcedInputFormatName = ffmpegInputFormatName(for: plan.primaryRoute)
        if shouldTreatAsTransportStream(plan.primaryRoute) {
            let isSeekableFile = plan.primaryRoute.routeKind == .localRangeProxy
                || plan.intent.contentKind == .discImage
            options.prefersTimestampSeeking = plan.intent.contentKind == .discImage
            options.isSeekImageSubtitle = false // Selection uses the shared seek lifecycle above.
            options.probesize = isSeekableFile ? 5 * 1024 * 1024 : 1 * 1024 * 1024
            options.maxAnalyzeDuration = isSeekableFile ? 3_000_000 : 1_000_000
            options.formatContextOptions["seekable"] = isSeekableFile ? 1 : 0
            options.formatContextOptions["skip_estimate_duration_from_pts"] = isSeekableFile ? 0 : 1
        } else if plan.primaryRoute.routeKind == .localRangeProxy {
            options.formatContextOptions["seekable"] = 1
        }
        options.autoSelectEmbedSubtitle = false // Explicit source ID controls rendered selection.
        options.canStartPictureInPictureAutomaticallyFromInline = true
        if plan.primaryRoute.certificatePolicy == .allowPinnedSelfSigned {
            options.formatContextOptions["tls_verify"] = "0"
        }
        if !plan.primaryRoute.headers.isEmpty {
            options.appendHeader(plan.primaryRoute.headers)
        }

        if let userAgent = plan.primaryRoute.headers["User-Agent"] {
            options.userAgent = userAgent
        }
        if let referer = plan.primaryRoute.headers["Referer"] {
            options.referer = referer
        }

        return options
    }

    /// Open and decode a muted original stream before replacing the visible one.
    /// Reuse the same coordinator/view at commit so the prepared decoder survives.
    static func prepareReplacement(plan: PlaybackPlan, controls: GreenfieldPlaybackControls,
        liveClock: () -> Double, isPlaying: () -> Bool,
        report: @escaping (String, [String: String]) -> Void) async -> KSVideoPlayer.Coordinator? {
        let coordinator = KSVideoPlayer.Coordinator()
        let options = makeOptions(plan: plan, controls: controls, coordinator: coordinator)
        options.registerRemoteControll = false
        var previewSeconds: Double?
        let recordFrame = options.videoFrameSubmitted
        options.videoFrameSubmitted = { seconds, forced in
            recordFrame?(seconds, forced)
            if forced { Task { @MainActor in previewSeconds = seconds } }
        }
        let layer = KSPlayerLayer(url: plan.primaryRoute.url, isAutoPlay: false,
                                  options: options, delegate: coordinator)
        coordinator.playerLayer = layer
        coordinator.isMuted = true
        layer.prepareToPlay()
        let deadline = ProcessInfo.processInfo.systemUptime + 60
        var success = false
        defer { if !success { coordinator.resetPlayer() } }
        while (!layer.player.isReadyToPlay || previewSeconds == nil), layer.state != .error,
              !Task.isCancelled, ProcessInfo.processInfo.systemUptime < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard layer.player.isReadyToPlay, previewSeconds != nil, !Task.isCancelled else {
            report("warmup_failed", ["stage": "ksInitialFrame", "state": String(describing: layer.player.playbackState),
                                    "ready": String(layer.player.isReadyToPlay)]); return nil
        }
        report("candidate_opened", ["preview": String(previewSeconds ?? -1)])
        var lead = 0.0
        for _ in 0..<4 {
            let started = ProcessInfo.processInfo.systemUptime
            let target = min(max(0, liveClock() + (isPlaying() ? lead : 0)),
                             max(0, (plan.timeline.duration ?? layer.player.duration) - 0.1))
            previewSeconds = nil
            var completed: Bool?
            layer.seek(time: target, autoPlay: false) { result in
                completed = result
                report("candidate_seek_completed", ["target": String(target), "completed": String(result)])
            }
            while (completed == nil || (completed == true && previewSeconds == nil)),
                  !Task.isCancelled, ProcessInfo.processInfo.systemUptime < deadline {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            guard !Task.isCancelled, completed == true, let preview = previewSeconds else {
                report("warmup_failed", ["stage": "ksPreview", "completed": String(describing: completed),
                    "state": String(describing: layer.player.playbackState), "clock": String(layer.player.currentPlaybackTime),
                    "preview": String(describing: previewSeconds)]); return nil
            }
            lead = (ProcessInfo.processInfo.systemUptime - started) * Double(plan.intent.playbackRate) + 0.25
            while isPlaying(), preview - liveClock() > 0.04,
                  !Task.isCancelled, ProcessInfo.processInfo.systemUptime < deadline {
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
            guard !Task.isCancelled, ProcessInfo.processInfo.systemUptime < deadline else { return nil }
            guard abs(preview - liveClock()) < 0.1 else { continue }
            report("candidate_aligned", ["candidate": String(preview), "current": String(liveClock()),
                                         "candidateEngine": "KSPlayer", "evidence": "decodedPreview"])
            // Drop the warmup-only callback before transferring ownership.
            options.videoFrameSubmitted = recordFrame
            success = true
            return coordinator
        }
        report("warmup_failed", ["stage": "ksAlignment"])
        return nil
    }

    private static func ffmpegInputFormatName(for route: PlaybackRoute) -> String? {
        let container = (route.containerHint ?? route.url.pathExtension)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch container {
        case "ts", "m2ts", "mts":
            return "mpegts"
        case "mp4", "m4v", "mov":
            return "mov,mp4,m4a,3gp,3g2,mj2"
        case "avi":
            return "avi"
        case "flv":
            return "flv"
        case "wmv", "asf":
            return "asf"
        case "rm", "rmvb":
            return "rm"
        case "m3u8":
            return "hls"
        default:
            return nil
        }
    }

    private static func shouldTreatAsTransportStream(_ route: PlaybackRoute) -> Bool {
        let container = (route.containerHint ?? route.url.pathExtension)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return container == "ts" || container == "m2ts" || container == "mts"
    }

    private static func configureDefaultEngine() {
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.logLevel = .info
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain):\(nsError.code):\(nsError.localizedDescription)"
    }

    private static func snapshot(_ layer: KSPlayerLayer) -> GreenfieldKSPlayerRuntimeSnapshot {
        let dynamicInfo = layer.player.dynamicInfo
        return GreenfieldKSPlayerRuntimeSnapshot(
            playbackState: String(describing: layer.player.playbackState),
            loadState: String(describing: layer.player.loadState),
            isReadyToPlay: layer.player.isReadyToPlay,
            isPlaying: layer.player.isPlaying,
            isSeekable: layer.player.seekable,
            currentSeconds: layer.player.currentPlaybackTime,
            durationSeconds: layer.player.duration,
            playableSeconds: layer.player.playableTime,
            bytesRead: dynamicInfo?.bytesRead,
            audioBitrate: dynamicInfo?.audioBitrate,
            videoBitrate: dynamicInfo?.videoBitrate,
            displayFPS: dynamicInfo?.displayFPS
        )
    }
}
#else
struct GreenfieldKSPlayerRenderer: View {
    let plan: PlaybackPlan
    @ObservedObject var controls: GreenfieldPlaybackControls
    let onUnsupported: () -> Void
    let onStateChanged: (String) -> Void
    let onPlaybackTime: (TimeInterval, TimeInterval) -> Void
    let onFinished: (String?, GreenfieldKSPlayerRuntimeSnapshot?) -> Void
    let onBufferChanged: (Int, TimeInterval) -> Void

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .onAppear(perform: onUnsupported)
    }
}
#endif

/// Subtitles must be inside PiP's video sample buffers; SwiftUI overlays belong
/// only to the full-screen view. This opt-in compositor leaves normal playback
/// untouched and caches the transparent subtitle canvas until its cue changes.
final class GreenfieldPiPSubtitleCompositor {
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var pool: CVPixelBufferPool?
    private var poolSize = CGSize.zero
    private var lastKey = ""
    private var overlay: CIImage?

    func composite(_ source: CVPixelBuffer, text: String?, images: [(UIImage, CGPoint, CGSize)], videoSize: CGSize) -> CVPixelBuffer? {
        let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty || !images.isEmpty else { return nil }
        // Do not silently flatten an HDR/Dolby signal into an SDR buffer.
        let transfer = CVBufferCopyAttachment(source, kCVImageBufferTransferFunctionKey, nil) as? String
        guard transfer != (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String),
              transfer != (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String) else { return nil }
        let width = CVPixelBufferGetWidth(source), height = CVPixelBufferGetHeight(source)
        let size = CGSize(width: width, height: height)
        let imageKey = images.map { "\(ObjectIdentifier($0.0))-\($0.1)-\($0.2)" }.joined(separator: "/")
        let key = "\(size)-\(videoSize)-\(text)-\(imageKey)"
        if key != lastKey {
            lastKey = key
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
                for (image, origin, subtitleCanvas) in images {
                    let canvas = subtitleCanvas.width > 0 && subtitleCanvas.height > 0 ? subtitleCanvas : videoSize
                    let scale = CGSize(width: size.width / max(canvas.width, 1), height: size.height / max(canvas.height, 1))
                    image.draw(in: CGRect(x: origin.x * scale.width, y: origin.y * scale.height,
                        width: image.size.width * scale.width, height: image.size.height * scale.height))
                }
                if !text.isEmpty {
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.alignment = .center
                    paragraph.lineBreakMode = .byWordWrapping
                    let font = UIFont.systemFont(ofSize: max(18, size.height * 0.05), weight: .medium)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font, .foregroundColor: UIColor.white, .paragraphStyle: paragraph,
                        .strokeColor: UIColor.black.withAlphaComponent(0.8), .strokeWidth: -2
                    ]
                    let bounds = (text as NSString).boundingRect(with: CGSize(width: size.width * 0.9, height: size.height * 0.5),
                        options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
                    (text as NSString).draw(in: CGRect(x: size.width * 0.05,
                        y: size.height * 0.91 - ceil(bounds.height), width: size.width * 0.9, height: ceil(bounds.height)),
                        withAttributes: attributes)
                }
            }
            overlay = image.cgImage.map { CIImage(cgImage: $0) }
        }
        if poolSize != size || pool == nil {
            poolSize = size
            let attributes: [String: Any] = [kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height, kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
            CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
        }
        guard let pool, let overlay else { return nil }
        var output: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pool,
            [kCVPixelBufferPoolAllocationThresholdKey: 4] as CFDictionary, &output) == kCVReturnSuccess, let output else { return nil }
        context.render(overlay.composited(over: CIImage(cvPixelBuffer: source)), to: output,
            bounds: CGRect(origin: .zero, size: size), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return output
    }
}
