import SwiftUI

@MainActor
final class GreenfieldPlaybackControls: PlaybackUIEngineSession {
    @Published var currentSeconds: Double = 0
    @Published var durationSeconds: Double = 0
    @Published var isPlaying = false
    @Published var isReady = false
    @Published var fillsScreen = false
    @Published var rate: Float = 1
    var togglePlaybackAction: (() -> Void)?
    var seekPlayback: ((Double) -> Void)?
    var onTimelineDiscontinuity: (() -> Void)?
    var updateScale: ((Bool) -> Void)?
    var updateRate: ((Float) -> Void)?

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
    private(set) var seekGeneration = 0
    /// A control adapter may be reused after the other engine has played.
    /// Recovery timers and pending seek completions belong to one plan only.
    func beginSession() {
        seekGeneration += 1
        seekAt = nil
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
        event("seek_engine_completed", metrics: ["completed": String(completed), "targetSeconds": String(seekTarget)])
    }
    func observeClock(_ seconds: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        if let resumeAt, isPlaying, seconds > resumePosition + 0.05 {
            event("resumed", metrics: ["resumeRecoveryMs": String(Int((now - resumeAt) * 1000)),
                "pauseDurationMs": String(Int((resumeAt - (pausedAt ?? resumeAt)) * 1000)), "evidence": "advancingPlaybackClock"])
            self.resumeAt = nil; pausedAt = nil
        }
        if let seekAt, seekCompleted, abs(seconds - seekTarget) < 2 {
            event("seek_recovered", metrics: ["seekRecoveryMs": String(Int((now - seekAt) * 1000)),
                "currentSeconds": String(seconds), "seekTargetSeconds": String(seekTarget), "evidence": "engineCompletionAndClock"])
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
        guard isSeekable, canSeekAbsolute?(seconds) != false else { return false }
        seekSeconds(seconds); return true
    }
    func jump(by seconds: Int) { seekSeconds(currentSeconds + Double(seconds)) }
    func setPlaybackRate(_ rate: Float) { self.rate = rate; updateRate?(rate); record("playbackRate", value: String(rate)) }
    func selectAudio(_ track: PlaybackUITrack) { audioAction?(track.id) }
    func selectSubtitle(_ track: PlaybackUITrack) { subtitleAction?(track.id) }
    func selectExternalSubtitle(_ url: URL?) -> Bool { externalSubtitleAction?(url); return externalSubtitleAction != nil }
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
        guard isReady, isSeekable, seconds.isFinite, durationSeconds > 0 else { return }
        let target = min(max(seconds, 0), max(durationSeconds - 0.1, 0))
        onTimelineDiscontinuity?()
        seekGeneration += 1
        seekAt = ProcessInfo.processInfo.systemUptime; seekTarget = target; seekCompleted = false
        event("seek_started", metrics: ["seekTargetSeconds": String(target), "seekDeltaSeconds": String(target - currentSeconds)])
        seekPlayback?(target)
        record("seekRequested", value: String(format: "%.3f", target))
    }

    func record(_ action: String, value: String = "-") {
        event("control_action", metrics: ["action": action, "value": value])
    }

    func disconnect() {
        seekGeneration += 1
        seekAt = nil; resumeAt = nil; pausedAt = nil
        seekCompleted = false
        canSeekAbsolute = nil
        togglePlaybackAction = nil
        seekPlayback = nil
        updateScale = nil
        updateRate = nil
        muteAction = nil; audioAction = nil; subtitleAction = nil
        externalSubtitleAction = nil; pictureInPictureAction = nil
        isReady = false; isSeekable = false
        isPlaying = false
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
                let scale = min(geometry.size.width / videoSize.width,
                                geometry.size.height / videoSize.height)
                VStack(spacing: 4) {
                    Spacer(minLength: 0)
                    ForEach(model.parts) { part in
                        if let image = part.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: min(geometry.size.width, image.size.width * scale),
                                       height: image.size.height * scale)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            VideoSubtitleView(model: model)
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

    @StateObject private var coordinator = KSVideoPlayer.Coordinator()
    @State private var appliedInitialTracks = false

    var body: some View {
        if #available(iOS 16.0, *) {
            KSVideoPlayer(
                coordinator: coordinator,
                url: plan.primaryRoute.url,
                options: makeOptions()
            )
            .onStateChanged { layer, state in
                controls.isReady = layer.player.isReadyToPlay
                syncTracks(layer)
                controls.isPlaying = layer.state.isPlaying
                onStateChanged(state.description)
            }
            .onPlay { currentTime, totalTime in
                if currentTime.isFinite, currentTime >= 0 {
                    controls.currentSeconds = currentTime
                    controls.observeClock(currentTime)
                }
                if let duration = plan.timeline.duration, duration.isFinite, duration > 0 {
                    controls.durationSeconds = duration
                } else if totalTime.isFinite, totalTime > 0 {
                    controls.durationSeconds = totalTime
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
                    .padding(.horizontal, 24).padding(.bottom, 72)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
            .onAppear {
                configureDefaultEngine()
                connectControls()
                onStateChanged("rendererAppeared")
            }
            .onDisappear { controls.disconnect() }
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
        controls.seekPlayback = { [weak coordinator, weak controls] seconds in
            guard let layer = coordinator?.playerLayer else { return }
            let wasPlaying = layer.state.isPlaying
            let generation = controls?.seekGeneration
            layer.seek(time: seconds, autoPlay: wasPlaying) { completed in
                Task { @MainActor [weak coordinator, weak controls] in
                    guard let controls, controls.seekGeneration == generation,
                          let player = coordinator?.playerLayer?.player else { return }
                    controls.seekDidComplete(completed)
                    let actual = player.currentPlaybackTime
                    if completed, actual.isFinite, actual >= 0 {
                        controls.currentSeconds = actual
                        controls.observeClock(actual)
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
            player.select(track: track)
            let selected = player.tracks(mediaType: .audio).first { $0.isEnabled }?.trackID ?? -1
            controls?.selectedAudioTrackID = selected
            controls?.record("audioTrackRequested", value: String(id))
            controls?.event("audio_track_changed", metrics: ["engineTrackID": String(selected), "requestedTrackID": String(id), "evidence": "engineTrackInventory"] )
        }
        controls.subtitleAction = { [weak coordinator, weak controls] id in
            guard let coordinator, let player = coordinator.playerLayer?.player else { return }
            coordinator.subtitleModel.selectedSubtitleInfo = nil
            let tracks = player.tracks(mediaType: .subtitle)
            for track in tracks { track.isEnabled = false }
            if let track = tracks.first(where: { $0.trackID == id }) { player.select(track: track) }
            if let info = player.subtitleDataSouce?.infos.first(where: { $0.subtitleID == String(id) }) {
                coordinator.subtitleModel.selectedSubtitleInfo = info
            }
            _ = coordinator.subtitleModel.subtitle(currentTime: player.currentPlaybackTime)
            controls?.selectedSubtitleTrackID = id
            controls?.record("subtitleTrackRequested", value: String(id))
        }
        controls.externalSubtitleAction = { [weak coordinator] _ in
            coordinator?.subtitleModel.selectedSubtitleInfo = nil
            _ = coordinator?.subtitleModel.subtitle(currentTime: coordinator?.playerLayer?.player.currentPlaybackTime ?? 0)
            for track in coordinator?.playerLayer?.player.tracks(mediaType: .subtitle) ?? [] { track.isEnabled = false }
        }
        controls.pictureInPictureAction = { [weak coordinator, weak controls] in
            guard let layer = coordinator?.playerLayer, let pip = layer.player.pipController, pip.isPictureInPicturePossible else {
                controls?.pictureInPictureUnavailable = true
                controls?.event("pip_unavailable"); return
            }
            pip.delegate = layer
            pip.startPictureInPicture()
            controls?.record("pictureInPictureRequested")
        }
    }

    private func syncTracks(_ layer: KSPlayerLayer) {
        if layer.player.isReadyToPlay, controls.audioAction != nil, !appliedInitialTracks {
            appliedInitialTracks = true
            if controls.startsPaused {
                layer.pause()
                let expectedPlanID = controls.planID
                layer.seek(time: plan.timeline.startTime, autoPlay: false) { [weak layer, weak controls] completed in
                    Task { @MainActor in
                        guard completed, let layer, let controls,
                              controls.planID == expectedPlanID else { return }
                        let actual = layer.player.currentPlaybackTime
                        if actual.isFinite { controls.currentSeconds = actual }
                    }
                }
                controls.startsPaused = false
            }
            if plan.primaryRoute.playMethod == .directPlay {
                if let id = plan.tracks.selectedSourceAudioTrackID.flatMap(Int32.init) {
                    controls.audioAction?(id)
                }
                let subtitleID = plan.subtitles.mode == .disabled ? nil : plan.tracks.selectedSourceSubtitleTrackID.flatMap(Int32.init)
                controls.subtitleAction?(subtitleID ?? -1)
            }
        }
        controls.isSeekable = layer.player.seekable
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
        controls.selectedSubtitleTrackID = coordinator.subtitleModel.selectedSubtitleInfo.flatMap { Int32($0.subtitleID) } ?? -1
    }

    private func makeOptions() -> KSOptions {
        let options = GreenfieldKSOptions()
        let expectedPlanID = String(plan.id.uuidString.prefix(8))
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
            options.isSeekImageSubtitle = plan.intent.contentKind == .discImage
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

    private func ffmpegInputFormatName(for route: PlaybackRoute) -> String? {
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

    private func shouldTreatAsTransportStream(_ route: PlaybackRoute) -> Bool {
        let container = (route.containerHint ?? route.url.pathExtension)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return container == "ts" || container == "m2ts" || container == "mts"
    }

    private func configureDefaultEngine() {
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
