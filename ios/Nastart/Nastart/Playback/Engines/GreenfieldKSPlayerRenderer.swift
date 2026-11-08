import SwiftUI
import CoreImage
import IOSurface
import AVFoundation
import Combine
import NetworkMedia
#if os(iOS)
import UIKit
#endif

private struct PlaybackSubtitleBottomInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 12
}

extension EnvironmentValues {
    var playbackSubtitleBottomInset: CGFloat {
        get { self[PlaybackSubtitleBottomInsetKey.self] }
        set { self[PlaybackSubtitleBottomInsetKey.self] = newValue }
    }
}

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
    @Published var isPlaying = false {
        didSet {
            if isPlaying { waitingForPausedSeekPreview = false }
            if oldValue && !isPlaying {
                persistResumeBoundary("pause_resume_boundary")
            }
        }
    }
    var resumeBoundaryAction: (() -> Void)?
    private var resumeLifecycleSubscriptions = Set<AnyCancellable>()

    func observeResumeLifecycle() {
#if os(iOS)
        guard resumeLifecycleSubscriptions.isEmpty else { return }
        // The engine controls outlive retained/minimized SwiftUI presentations.
        // Save synchronously on UIKit's transition, before suspension can occur.
        for name in [UIScene.willDeactivateNotification, UIScene.didEnterBackgroundNotification,
                     UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification] {
            NotificationCenter.default.publisher(for: name).sink { [weak self] _ in
                self?.persistResumeBoundary("native_resume_boundary")
            }.store(in: &resumeLifecycleSubscriptions)
        }
#endif
    }

    private func persistResumeBoundary(_ eventName: String) {
        guard canPersistResumeProgress, let resumeBoundaryAction else { return }
        resumeBoundaryAction()
        event(eventName, metrics: ["currentSeconds": String(preciseCurrentSeconds)])
    }
    @Published private var transportBuffering = false
    var isTransportBuffering: Bool {
        get { transportBuffering }
        set {
            guard transportBuffering != newValue else { return }
            transportBuffering = newValue
        }
    }
    @Published var isReady = false
    @Published var subtitleVideoSize = CGSize.zero
    @Published var fillsScreen = false
    @Published var rate: Float = 1
    var togglePlaybackAction: (() -> Void)?
    var seekPlayback: ((Double) -> Void)?
    var readPlaybackClock: (() -> Double)?
    var readRuntimeTelemetry: (() -> [String: String])?
    var readDownloadedBytes: (() -> Int64?)?
    var downloadByteSample: PlaybackDownloadByteSample? {
        guard let bytes = readDownloadedBytes?(), bytes >= 0 else { return nil }
        return PlaybackDownloadByteSample(sourceID: "engine:" + planID, bytes: bytes)
    }
    var preciseCurrentSeconds: Double {
        guard pendingSeekPosition == nil, let seconds = readPlaybackClock?(), seconds.isFinite, seconds >= 0 else { return currentSeconds }
        return seconds
    }
    var onTimelineDiscontinuity: (() -> Void)?
    var updateScale: ((Bool) -> Void)?
    var updateRate: ((Float) -> Void)?

    @Published var isPictureInPictureActive = false
    private(set) var pictureInPictureSessionGeneration = 0
    private(set) var isPictureInPictureStarting = false
    func pictureInPictureWillStart() {
        pictureInPictureSessionGeneration += 1
        isPictureInPictureStarting = true
    }
    func pictureInPictureStartCompleted() { isPictureInPictureStarting = false }
    func canReplacePlaybackSession(pictureInPictureGeneration: Int, seekGeneration: Int? = nil) -> Bool {
        PlaybackHandoffBoundary(seekGeneration: seekGeneration,
            pictureInPictureGeneration: pictureInPictureGeneration).allowsReplacement(
                seekGeneration: self.seekGeneration, pictureInPictureGeneration: pictureInPictureSessionGeneration,
                isPictureInPictureStarting: isPictureInPictureStarting,
                isPictureInPictureActive: isPictureInPictureActive)
    }
    var pipInitialExternalSubtitleURL: URL?
    var pipWillStart: (() -> Void)?
    var pipDidStart: (() -> Void)?
    var pipDidClose: (() -> Void)?
    var pipRestore: ((@escaping (Bool) -> Void) -> Void)?
    var retainRendererForPictureInPicture: ((Bool) -> Void)?
    var pipRendererLifetime: AnyObject?
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
    var sourceRuntimeStreamIndexes: (audio: Int?, subtitle: Int?)?
    var originalStreamIndexesKnown = false
    private enum SubtitleSelection: Equatable {
        case embedded(Int32)
        case external(URL)
    }
    private var lastSubtitleSelection: SubtitleSelection?
    var automaticallySelectsEmbeddedSubtitles = false

    func discoverEmbeddedSubtitle(tracks: [PlaybackDefaultSubtitlePolicy.Track],
                                  readySubtitleIDs: Set<Int>,
                                  preferredLanguages: [String] = Locale.preferredLanguages) {
        guard automaticallySelectsEmbeddedSubtitles, isReady, lastSubtitleSelection == nil,
              let id = PlaybackDefaultSubtitlePolicy.select(tracks: tracks, serverDefault: nil,
                  preferredLanguages: preferredLanguages),
              readySubtitleIDs.contains(id), let trackID = Int32(exactly: id),
              subtitleAction != nil else { return }
        selectSourceSubtitle(trackID, externalURL: nil)
        event("automatic_embedded_subtitle_selected", metrics: ["trackID": String(id)])
    }
    var readPlaybackIntent: (() -> Bool)?
    // A waiting renderer can report no playback while the user still wants it.
    var wantsPlayback: Bool { readPlaybackIntent?() ?? isPlaying }
    var canSeekAbsolute: ((Double) -> Bool)?
    var engineName = "KSPlayer"
    var startsPaused = false
    var traceID: String?
    var planID = "-"
#if DEBUG
    /// The callback can be installed before configure assigns planID.
    /// Bind the requested plan, then validate live ownership on delivery.
    func seekCapacityObserver(for owner: UUID,
                              report: @escaping ([String: String]) -> Void) -> (Int, [String: String]) -> Void {
        let expected = String(owner.uuidString.prefix(8))
        return { [weak self] generation, fields in
            guard let self, self.planID == expected, self.isReady,
                  self.seekGeneration == generation else { return }
            report(fields)
        }
    }
#endif
    private(set) var renderingPlanID: UUID?
    var routeID = "-"
    /// The diagnostic prefix is not an ownership identity. Reject a retiring
    /// renderer before it reads a new session's clock, cue or compositor cache.
    func pictureInPictureFrameTransform(for owner: UUID,
        transform: @escaping (CVPixelBuffer, TimeInterval) -> CVPixelBuffer?)
        -> (CVPixelBuffer, TimeInterval) -> CVPixelBuffer? {
        { [weak self] buffer, seconds in
            guard let self, self.isPictureInPictureActive,
                  self.renderingPlanID == owner else { return nil }
            return transform(buffer, seconds)
        }
    }
    func pictureInPictureFrameTransform<FrameContext>(for owner: UUID,
        transform: @escaping (CVPixelBuffer, TimeInterval, FrameContext) -> CVPixelBuffer?)
        -> (CVPixelBuffer, TimeInterval, FrameContext) -> CVPixelBuffer? {
        { [weak self] buffer, seconds, context in
            guard let self, self.isPictureInPictureActive,
                  self.renderingPlanID == owner else { return nil }
            return transform(buffer, seconds, context)
        }
    }
    private var pausedAt: TimeInterval?
    /// Native PiP commands bypass the full-screen toggle and can stop clock ticks.
    /// Record their actual engine result without changing the user's playback state.
    func pictureInPicturePlaybackObserver(for owner: UUID,
        record: @escaping ([String: String]) -> Void)
        -> (Bool, Bool, TimeInterval, TimeInterval) -> Void {
        { [weak self] requested, actual, seconds, uptime in
            guard let self, self.isPictureInPictureActive, self.renderingPlanID == owner,
                  seconds.isFinite, seconds >= 0, uptime.isFinite, uptime > 0 else { return }
            record(["observationID": UUID().uuidString, "ownerPlanID": owner.uuidString,
                    "requestedPlaying": String(requested), "actualPlaying": String(actual),
                    "currentSeconds": String(seconds), "snapshotUptime": String(uptime),
                    "controlsPlaying": String(self.isPlaying)])
        }
    }
    private var resumeAt: TimeInterval?
    private var resumePosition = 0.0
    private var seekAt: TimeInterval?
    private var seekTarget = 0.0
    private var seekCompleted = false
    @Published private var seekState = PlaybackSeekState()
    private var pendingSeekPosition: Double? { seekState.pendingTarget }
    @Published private var waitingForPausedSeekPreview = false
    var expectsPausedSeekPreview = false
    private var bufferWarmupStartSeconds: Double?
    private var initialResumePosition = 0.0
    private var didObserveResumeTimeline = false
    var hasPendingSeek: Bool { pendingSeekPosition != nil || waitingForPausedSeekPreview }
    /// Engine readiness can precede the initial resume seek. Until its clock
    /// arrives, background/exit saves must preserve the existing bookmark.
    var canPersistResumeProgress: Bool {
        isReady && !hasPendingSeek && (initialResumePosition == 0 || didObserveResumeTimeline)
    }
    var resumePersistenceDiagnostics: [String: String] {
        ["ready": String(isReady), "pendingSeek": String(hasPendingSeek),
         "pendingSeekPosition": String(pendingSeekPosition != nil),
         "waitingForPausedPreview": String(waitingForPausedSeekPreview),
         "ownerPlanID": renderingPlanID?.uuidString ?? "unknown",
         "resumeTimelineConfirmed": String(initialResumePosition == 0 || didObserveResumeTimeline)]
    }
    /// Readiness alone can expose a zero clock before the resume seek lands.
    /// Both reports must use the confirmed, attached engine's absolute clock.
    func reportPlaybackTime(_ seconds: Double, isPaused: Bool, using tracker: MediaPlaybackTracker?) {
        guard canPersistResumeProgress, seconds.isFinite, seconds >= 0 else { return }
        let actualSeconds = readPlaybackClock?() ?? seconds
        guard actualSeconds.isFinite, actualSeconds >= 0 else { return }
        tracker?.started(positionSeconds: actualSeconds)
        tracker?.progressed(positionSeconds: actualSeconds, isPaused: isPaused)
    }
    /// A pause or suspension may leave no subsequent clock tick to flush the
    /// server position. Use the same confirmed timeline as the local bookmark.
    func checkpointPlaybackProgress(using tracker: MediaPlaybackTracker?) {
        guard canPersistResumeProgress else { return }
        tracker?.progressed(positionSeconds: preciseCurrentSeconds,
                            isPaused: !isPlaying, force: true)
    }
    var hasPendingSeekRecovery: Bool { seekAt != nil }
    func shouldRefreshPausedSubtitle(decodedTrackID: Int32, selectedTrackID: Int32?, callbackPlanID: String) -> Bool {
        !isPlaying && planID == callbackPlanID && selectedTrackID == decodedTrackID
    }
    var seekGeneration: Int { seekState.generation }
    func ownsPendingSeek(generation: Int) -> Bool { seekState.owns(generation: generation) }
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
    func beginSession(initialPosition: Double = 0, initialExternalSubtitleURL: URL? = nil,
                      renderingPlanID: UUID? = nil) {
        self.renderingPlanID = renderingPlanID
        subtitleVideoSize = .zero
        initialResumePosition = initialPosition.isFinite ? max(initialPosition, 0) : 0
        didObserveResumeTimeline = false
        isTransportBuffering = false
        lastSubtitleSelection = initialExternalSubtitleURL.map(SubtitleSelection.external)
        sourceRuntimeStreamIndexes = nil
        originalStreamIndexesKnown = false
        automaticallySelectsEmbeddedSubtitles = false
        seekState.invalidate()
        seekAt = nil
        waitingForPausedSeekPreview = false
        expectsPausedSeekPreview = false
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
    func seekDidComplete(_ completed: Bool, generation: Int? = nil) {
        guard seekState.complete(generation: generation ?? seekGeneration) else { return }
        seekCompleted = completed
        if !completed {
            waitingForPausedSeekPreview = false
            // A failed seek resumes at the engine's actual position, not the
            // requested target or the original session's resume position.
            bufferWarmupStartSeconds = (readPlaybackClock?()).flatMap {
                $0.isFinite && $0 >= 0 ? $0 : nil
            }
            if let actualSeconds = bufferWarmupStartSeconds {
                updateClock(actualSeconds)
            }
        }
        event("seek_engine_completed", metrics: ["completed": String(completed), "targetSeconds": String(seekTarget)])
    }
    /// Paused KS seeks acknowledge demuxing before submitting their preview.
    /// Keep requested text hidden until that target reaches the output API.
    func acceptPausedSeekPreview(_ seconds: Double) {
        guard waitingForPausedSeekPreview, seconds.isFinite,
              abs(seconds - seekTarget) <= 0.15 else { return }
        waitingForPausedSeekPreview = false
        event("seek_preview_ready", metrics: ["framePTSSeconds": String(seconds),
            "seekTargetSeconds": String(seekTarget), "evidence": "rendererOutputNotPresentation"])
    }
    func hasAdvancedForSteadyBuffer(_ seconds: Double, initialPosition: Double) -> Bool {
        !hasPendingSeek && seconds.isFinite && seconds >= 0
            && seconds > (bufferWarmupStartSeconds ?? initialPosition) + 0.05
    }
    /// Keep the requested position visible until the engine finishes seeking.
    /// Demux/network work can continue emitting the previous clock meanwhile.
    func updateClock(_ seconds: Double) {
        guard seconds.isFinite, seconds >= 0, pendingSeekPosition == nil else { return }
        // Use the currently attached engine when available, rather than the
        // requested chrome clock or a retiring renderer's late callback.
        let actualSeconds = readPlaybackClock?() ?? seconds
        if actualSeconds.isFinite, actualSeconds >= 0,
           actualSeconds >= initialResumePosition
            || (seekCompleted && abs(actualSeconds - seekTarget) < 2) {
            didObserveResumeTimeline = true
        }
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
    var isBuffering: Bool { !isReady || isTransportBuffering }
    // Ready metadata can precede the resume seek and usable buffered data.
    // Keep this separate from session startup, including later transport waits.
    var showsLoadingIndicator: Bool { isBuffering || hasPendingSeek }
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
              PlaybackSeekState.target(absolute: seconds, duration: durationSeconds) != nil,
              canSeekAbsolute?(seconds) != false else { return false }
        seekSeconds(seconds); return true
    }
    func jump(by seconds: Int) {
        guard let target = seekState.target(relative: Double(seconds), clock: readPlaybackClock?() ?? .nan,
            fallback: currentSeconds, duration: durationSeconds) else { return }
        seekSeconds(target)
    }
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
    func pauseForExternalHandoff() { if wantsPlayback { togglePlayback() } }
    func runtimeState(orientationMode: PlayerOrientationMode) -> MediaPlaybackRuntimeState {
        MediaPlaybackRuntimeState(normalizedPosition: position, positionSeconds: currentSeconds,
            playbackRate: rate, audioTrackOrdinal: sourceRuntimeTracks.map { $0.audio } ?? audioTracks.firstIndex { $0.id == selectedAudioTrackID },
            subtitleTrackOrdinal: sourceRuntimeTracks.map { $0.subtitle } ?? subtitleTracks.filter { $0.id >= 0 }.firstIndex { $0.id == selectedSubtitleTrackID },
            subtitlesDisabled: activeExternalSubtitleURL == nil
                && (sourceRuntimeTracks?.disabled ?? (selectedSubtitleTrackID < 0)),
            subtitleSelectionKnown: isReady && (!automaticallySelectsEmbeddedSubtitles || lastSubtitleSelection != nil),
            orientationMode: orientationMode,
            sourceAudioStreamIndex: sourceRuntimeStreamIndexes?.audio
                ?? (originalStreamIndexesKnown && selectedAudioTrackID >= 0 ? Int(selectedAudioTrackID) : nil),
            sourceSubtitleStreamIndex: sourceRuntimeStreamIndexes?.subtitle
                ?? (originalStreamIndexesKnown && selectedSubtitleTrackID >= 0 ? Int(selectedSubtitleTrackID) : nil),
            activeExternalSubtitleURL: activeExternalSubtitleURL)
    }
    private var activeExternalSubtitleURL: URL? {
        if case let .external(url) = lastSubtitleSelection { return url }
        return pipExternalSubtitle.isEnabled ? pipInitialExternalSubtitleURL : nil
    }
    private static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let value = Int(seconds)
        return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
            : String(format: "%02d:%02d", value / 60, value % 60)
    }

    /// Native audio changes invalidate the same decoded queues as a seek.
    /// Preserve pending user intent and let the shared lifecycle own the only
    /// seek, its short recovery reserve, pause state and completion generation.
    func selectAudioWithSharedSeek(select: () -> Bool) -> Bool {
        guard isReady, isSeekable, durationSeconds.isFinite, durationSeconds > 0,
              seekPlayback != nil else { return false }
        let engineTime = readPlaybackClock?() ?? .nan
        let target = pendingSeekPosition ?? (engineTime.isFinite ? engineTime : currentSeconds)
        guard target.isFinite, target >= 0, select() else { return false }
        seekSeconds(target)
        return true
    }

    func seekSeconds(_ seconds: Double) {
        guard isReady, isSeekable, let seekPlayback,
              let request = seekState.begin(absolute: seconds, duration: durationSeconds) else { return }
        let target = request.target
        onTimelineDiscontinuity?()
        seekAt = ProcessInfo.processInfo.systemUptime; seekTarget = target; seekCompleted = false
        bufferWarmupStartSeconds = target
        event("seek_started", metrics: ["seekTargetSeconds": String(target), "seekDeltaSeconds": String(target - currentSeconds)])
        waitingForPausedSeekPreview = !isPlaying && expectsPausedSeekPreview
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
        renderingPlanID = nil
        retainRendererForPictureInPicture?(false)
        retainRendererForPictureInPicture = nil
        pipRendererLifetime = nil
        seekState.invalidate()
        seekAt = nil; resumeAt = nil; pausedAt = nil
        waitingForPausedSeekPreview = false
        expectsPausedSeekPreview = false
        bufferWarmupStartSeconds = nil
        seekCompleted = false
        canSeekAbsolute = nil
        togglePlaybackAction = nil
        seekPlayback = nil
        readPlaybackClock = nil
        readPlaybackIntent = nil
        readRuntimeTelemetry = nil
        readDownloadedBytes = nil
        updateScale = nil
        updateRate = nil
        muteAction = nil; audioAction = nil; subtitleAction = nil
        externalSubtitleAction = nil; pictureInPictureAction = nil
        isReady = false; isSeekable = false
        didObserveResumeTimeline = false
        isPlaying = false
        isTransportBuffering = false
    }
}

#if canImport(KSPlayer)
import KSPlayer

#if DEBUG
/// A requested seek's sampling window, not proof of decoder-generation ownership.
/// Callers serialize access; delayed UI delivery must check the current owner.
struct PlaybackSeekCapacityObservation {
    let generation: Int
    let started: TimeInterval
    var target: TimeInterval? = nil
    private var lastSample: TimeInterval?
    private var samples = 0
    private var finished = false

    mutating func sample(now: TimeInterval, isSeek: Bool, playable: Bool) -> String? {
        guard !finished, now.isFinite, started.isFinite, now >= started else { return nil }
        if now - started > 10 {
            finished = true
            return "expired"
        }
        // The request can precede the actual queue flush. Old playable queues
        // must not prematurely finish the new observation.
        guard isSeek else { return nil }
        if playable {
            finished = true
            return "playable"
        }
        guard samples < 20, lastSample.map({ now - $0 >= 0.5 }) ?? true else { return nil }
        samples += 1
        lastSample = now
        return "waiting"
    }
}
#endif

private final class GreenfieldKSOptions: KSOptions {
    var sourceAudioID: Int32?
    override func wantedAudio(tracks: [MediaPlayerTrack]) -> Int? {
        guard let sourceAudioID else { return nil }
        return tracks.firstIndex { $0.trackID == sourceAudioID }
    }
#if DEBUG
    private let capacityLock = NSLock()
    private var capacityObservation: PlaybackSeekCapacityObservation?
    var reportSeekCapacity: ((Int, [String: String]) -> Void)?

    func beginSeekCapacity(generation: Int, target: TimeInterval, now: TimeInterval) {
        capacityLock.lock(); defer { capacityLock.unlock() }
        capacityObservation = PlaybackSeekCapacityObservation(generation: generation, started: now, target: target)
    }

    override func playable(capacitys: [CapacityProtocol], isFirst: Bool, isSeek: Bool) -> LoadingState {
        let state = super.playable(capacitys: capacitys, isFirst: isFirst, isSeek: isSeek)
        let now = ProcessInfo.processInfo.systemUptime
        capacityLock.lock()
        let phase = capacityObservation?.sample(now: now, isSeek: isSeek, playable: state.isPlayable)
        let observation = capacityObservation
        capacityLock.unlock()
        if let phase, let observation {
            var fields = ["phase": phase, "seekGeneration": String(observation.generation),
                "sinceRequestMs": String((now - observation.started) * 1_000),
                "sampleUptimeSeconds": String(now), "isSeek": String(isSeek),
                "isFirst": String(isFirst), "playable": String(state.isPlayable),
                "loadedSeconds": String(state.loadedTime),
                "bufferTargetSeconds": String(preferredForwardBufferDuration),
                "evidence": "requestedSeekCapacityWindowNotDecoderGenerationOrPresentation"]
            for (name, media) in [("audio", AVMediaType.audio), ("video", AVMediaType.video)] {
                let tracks = capacitys.filter { $0.mediaType == media }
                fields[name + "CapacityTracks"] = String(tracks.count)
                guard tracks.count == 1, let track = tracks.first else { continue }
                fields[name + "Packets"] = String(track.packetCount)
                fields[name + "Frames"] = String(track.frameCount)
                fields[name + "MaximumFrames"] = String(track.frameMaxCount)
                fields[name + "FPS"] = String(track.fps)
                // KS uses this same counts/FPS definition; this is queue
                // duration, not timestamp coverage or network byte delivery.
                fields[name + "LoadedSeconds"] = track.fps.isFinite && track.fps > 0
                    ? String(Double(track.packetCount + track.frameCount) / Double(track.fps)) : "unknown"
                fields[name + "EOF"] = String(track.isEndOfFile)
                if name == "video", let probe = track as? KSSeekFrameCapacity {
                    let snapshot = probe.seekFrameDiagnosticSnapshot(now: now)
                    if let target = observation.target, let probeTarget = snapshot["videoSeekTargetSeconds"].flatMap(Double.init) {
                        let matches = abs(target - probeTarget) < 0.000_001
                        fields["videoSeekProbeTargetMatchesRequest"] = String(matches)
                        if matches { fields.merge(snapshot) { _, new in new } }
                    }
                }
            }
            reportSeekCapacity?(observation.generation, fields)
        }
        return state
    }
#endif
}

struct GreenfieldSubtitleOverlay: View {
    @ObservedObject var model: SubtitleModel
    let videoSize: CGSize
    let bottomInset: CGFloat

    var fillsScreen = false

    var body: some View {
        ZStack {
            SubtitleBitmapLayer(model: model, videoSize: videoSize, fillsScreen: fillsScreen)
            PlaybackSubtitleViewport(videoSize: videoSize, fillsScreen: fillsScreen,
                screenBottomInset: bottomInset) { viewport in
                VStack(spacing: 4) {
                    ForEach(model.parts.filter { !$0.imageUsesCanvasCoordinates }) { part in
                        if let image = part.image {
                            let size = part.imageDisplaySize(in: viewport, videoSize: videoSize)
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: size.width, height: size.height)
                        } else if let text = part.text?.string, !text.isEmpty {
                            PlaybackSubtitleText(text: text)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct GreenfieldKSPlayerRenderer: View {
    let plan: PlaybackPlan
    @Environment(\.playbackSubtitleBottomInset) private var subtitleBottomInset
    @ObservedObject var controls: GreenfieldPlaybackControls
    let onUnsupported: () -> Void
    let onStateChanged: (String) -> Void
    let onPlaybackTime: (TimeInterval, TimeInterval) -> Void
    let onFinished: (String?, GreenfieldKSPlayerRuntimeSnapshot?) -> Void
    let onBufferChanged: (Int, TimeInterval) -> Void

    @StateObject private var coordinator: KSVideoPlayer.Coordinator
    private let wasPrewarmed: Bool
    @State private var appliedInitialTracks = false
    @State private var didConnectControls = false
    @State private var steadyStateBufferGeneration: Int?
    @State private var reportedStartupTiming = false

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
                // The layer dispatches this callback from state.willSet;
                // its state property still contains the previous transition.
                controls.isPlaying = layer.player.isPlaying
                controls.isTransportBuffering = state == .buffering
                onStateChanged(state.description)
            }
            .onPlay { currentTime, totalTime in
                if currentTime.isFinite, currentTime >= 0 {
                    controls.updateClock(currentTime)
                    if !reportedStartupTiming, currentTime > plan.timeline.startTime + 0.05,
                       let layer = coordinator.playerLayer {
                        reportedStartupTiming = true
                        let options = layer.options
                        let startup = options.videoStartupTiming.snapshot
                        controls.event("engine_startup_timing", metrics: [
                            "openMs": PlaybackStageTiming.milliseconds(start: options.prepareTime, end: options.openTime),
                            "streamInfoMs": PlaybackStageTiming.milliseconds(start: options.openTime, end: options.findTime),
                            "readyMs": PlaybackStageTiming.milliseconds(start: options.findTime, end: options.readyTime),
                            "initialSeekMs": PlaybackStageTiming.milliseconds(start: options.initialSeekStartTime, end: options.initialSeekEndTime),
                            "initialSeekResult": options.initialSeekResult.map(String.init) ?? "notRequested",
                            "firstVideoPacketMs": PlaybackStageTiming.milliseconds(start: options.prepareTime, end: options.readVideoTime),
                            "firstVideoDecodeMs": PlaybackStageTiming.milliseconds(start: options.prepareTime, end: options.decodeVideoTime),
                            "decodeTimerMeaning": "invocationNotAcceptedFrame",
                            "acceptedVideoFrameMs": PlaybackStageTiming.milliseconds(start: options.prepareTime, end: options.videoStartupTiming.snapshot.samples[.acceptedFrame]?.time ?? 0),
                            "outputAttemptMs": PlaybackStageTiming.milliseconds(start: options.prepareTime, end: options.videoStartupTiming.snapshot.samples[.outputAttempt]?.time ?? 0),
                            "outputSubmittedMs": PlaybackStageTiming.milliseconds(start: options.prepareTime, end: options.videoStartupTiming.snapshot.samples[.outputSubmitted]?.time ?? 0),
                            "discardedVideoFramesBeforeAccepted": String(options.videoStartupTiming.snapshot.discardedBeforeFirstAccepted),
                            "readyToClockMs": PlaybackStageTiming.milliseconds(start: options.readyTime, end: CACurrentMediaTime()),
                            "initialPositionSeconds": String(plan.timeline.startTime),
                            "evidence": "engineMonotonicStagesAndAdvancingClock"
                        ].merging(startup.fields(prepare: options.prepareTime)) { _, new in new })
                    }
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
                if let layer = coordinator.playerLayer {
                    // System PiP controls act directly on the player.
                    if controls.isPlaying != layer.player.isPlaying {
                        controls.isPlaying = layer.player.isPlaying
                    }
                    syncTracks(layer)
                }
                onPlaybackTime(currentTime, totalTime)
            }
            .onFinish { layer, error in
                onFinished(error.map(Self.describe), Self.snapshot(layer))
            }
            .onBufferChanged { bufferedCount, consumeTime in
                onBufferChanged(bufferedCount, consumeTime)
            }
            .overlay(alignment: .bottom) {
                if !controls.hasPendingSeek {
                    GreenfieldSubtitleOverlay(model: coordinator.subtitleModel,
                        videoSize: coordinator.playerLayer?.player.naturalSize ?? .zero,
                        bottomInset: subtitleBottomInset, fillsScreen: controls.fillsScreen)
                        .transaction { $0.animation = nil }
                        .allowsHitTesting(false)
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .onAppear {
                Self.configureDefaultEngine()
                if !didConnectControls {
                    connectControls()
                    didConnectControls = true
                }
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
                   controls.renderingPlanID == plan.id {
                    controls.disconnect()
                    didConnectControls = false
                }
            }
        } else {
            Color.black
                .ignoresSafeArea()
                .onAppear(perform: onUnsupported)
        }
    }

    private func connectControls() {
        controls.retainRendererForPictureInPicture = { [weak coordinator, weak controls] retained in
            coordinator?.retainsPlayerForPictureInPicture = retained
            controls?.pipRendererLifetime = retained ? coordinator : nil
        }
        controls.beginSession(initialPosition: plan.timeline.startTime, renderingPlanID: plan.id)
        controls.automaticallySelectsEmbeddedSubtitles = plan.primaryRoute.playMethod == .directPlay
            && plan.subtitles.mode == .embedded
            && plan.tracks.selectedSourceSubtitleTrackID == nil
            && controls.pipInitialExternalSubtitleURL == nil
        controls.planID = String(plan.id.uuidString.prefix(8))
        controls.routeID = String(plan.primaryRoute.id.uuidString.prefix(8))
        controls.rate = plan.intent.playbackRate
        controls.currentSeconds = plan.timeline.startTime
        controls.durationSeconds = plan.timeline.duration ?? 0
        coordinator.isScaleAspectFill = controls.fillsScreen
        controls.togglePlaybackAction = { [weak coordinator, weak controls] in
            guard let layer = coordinator?.playerLayer, let controls else { return }
            if layer.wantsPlayback { layer.pause() } else { layer.play() }
            controls.isPlaying = layer.player.isPlaying
            controls.didTogglePlayback()
            controls.record(controls.isPlaying ? "play" : "pause")
        }
        controls.readPlaybackClock = { [weak coordinator] in coordinator?.playerLayer?.player.currentPlaybackTime ?? .nan }
        controls.readPlaybackIntent = { [weak coordinator] in coordinator?.playerLayer?.wantsPlayback ?? false }
        controls.readDownloadedBytes = { [weak coordinator] in
            guard !plan.primaryRoute.url.isFileURL else { return nil }
            return coordinator?.playerLayer?.player.dynamicInfo?.bytesRead
        }
        controls.readRuntimeTelemetry = { [weak coordinator, weak controls] in
            guard let layer = coordinator?.playerLayer,
                  let info = layer.player.dynamicInfo else { return [:] }
            return [
                "enginePlaying": String(layer.player.isPlaying),
                "enginePlaybackState": String(describing: layer.player.playbackState),
                "layerPlaybackState": layer.state.description,
                "controlsPlaying": String(controls?.isPlaying ?? false),
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
            guard let layer = coordinator?.playerLayer, let controls else { return }
            let native = layer.player, generation = controls.seekGeneration
            coordinator?.subtitleModel.beginSeek()
            for case let track as FFmpegAssetTrack in layer.player.tracks(mediaType: .subtitle) {
                track.invalidatePausedImageSubtitle()
            }
            // A new position needs a fast first frame again. The larger
            // steady-state reserve is restored after its clock advances.
            layer.options.preferredForwardBufferDuration = max(plan.startupPolicy.minimumPlayableBufferSeconds, 0.25)
#if DEBUG
            if let options = layer.options as? GreenfieldKSOptions {
                options.beginSeekCapacity(generation: generation, target: seconds, now: ProcessInfo.processInfo.systemUptime)
            }
#endif
            PlaybackSeekCommandExecutor.submit(target: seconds,
                isCurrent: { [weak coordinator, weak controls, weak layer, weak native] in
                    guard let controls, let layer, let native else { return false }
                    return coordinator?.playerLayer === layer && layer.player === native
                        && controls.ownsPendingSeek(generation: generation)
                }, seek: { [weak layer] target, completion in
                    guard let layer, layer.player.isReadyToPlay, layer.player.seekable else {
                        completion(false); return
                    }
                    layer.seek(time: target, autoPlay: false, completion: completion)
                }, willComplete: { [weak coordinator, weak controls] completed in
                    coordinator?.subtitleModel.endSeek()
                    controls?.seekDidComplete(completed, generation: generation)
                }, restoreIntent: { [weak layer] in
                    guard let layer else { return }
                    if layer.wantsPlayback { layer.play() } else { layer.pause() }
                }, didComplete: { [weak coordinator, weak controls, weak native] completed in
                    guard let controls, let native else { return }
                    let actual = native.currentPlaybackTime
                    if completed, actual.isFinite, actual >= 0 {
                        controls.updateClock(actual)
                        _ = coordinator?.subtitleModel.subtitle(currentTime: actual)
                    }
                })
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
            let coordinated = controls?.selectAudioWithSharedSeek {
                (player as? KSMEPlayer)?.selectAudioTrackForSeek(track) == true
            } ?? false
            if !coordinated { player.select(track: track) }
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
        let size = layer.player.naturalSize
        if size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
           controls.subtitleVideoSize != size { controls.subtitleVideoSize = size }

        // Automatic Home-to-PiP must use the same lifecycle delegate as the
        // button. The engine can replace its controller with the display layer.
        if layer.player.isReadyToPlay, let pip = layer.player.pipController,
           pip.delegate !== controls.pipDelegate {
            controls.pipDelegate.controls = controls
            pip.delegate = controls.pipDelegate
        }
        if layer.player.isReadyToPlay, controls.audioAction != nil, !appliedInitialTracks {
            appliedInitialTracks = true
            let video = layer.player.tracks(mediaType: .video).first
            controls.expectsPausedSeekPreview = layer.player is KSMEPlayer && video != nil
            let dolby = PlaybackDolbySourceInfo(visionProfile: video?.dovi.map { Int($0.dv_profile) },
                visionLevel: video?.dovi.map { Int($0.dv_level) },
                baseLayerCompatibilityID: video?.dovi.map { Int($0.dv_bl_signal_compatibility_id) })
            controls.event("source_capabilities", metrics: dolby.diagnosticDetails.merging([
                "metadataEvidence": "engineTrackInventory", "audioPath": "decodedPCM",
                "initialSubtitleMode": plan.subtitles.mode.rawValue,
                "initialSourceSubtitleID": plan.tracks.selectedSourceSubtitleTrackID ?? "none",
                "initialSourceAudioID": plan.tracks.selectedSourceAudioTrackID ?? "none",
                "initialPlayMethod": plan.primaryRoute.playMethod.rawValue,
                "initialSubtitleModelID": coordinator.subtitleModel.selectedSubtitleInfo?.subtitleID ?? "none",
                "initialSubtitleInfoCount": String(layer.player.subtitleDataSouce?.infos.count ?? 0),
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
                if !controls.automaticallySelectsEmbeddedSubtitles {
                    let subtitleID = plan.subtitles.mode == .disabled ? nil : plan.tracks.selectedSourceSubtitleTrackID.flatMap(Int32.init)
                    controls.selectSourceSubtitle(subtitleID,
                        externalURL: controls.pipInitialExternalSubtitleURL)
                }
            }
        }
        controls.updateTimelineMetadata(duration: nil, seekable: layer.player.seekable)
        // FFmpegAssetTrack.trackID is AVStream.index. AVFoundation track IDs
        // are not the same source identity and must not be mapped this way.
        controls.originalStreamIndexesKnown = plan.primaryRoute.playMethod == .directPlay
            && layer.player is KSMEPlayer
        let audio = layer.player.tracks(mediaType: .audio)
        let subtitles = layer.player.tracks(mediaType: .subtitle)
        controls.discoverEmbeddedSubtitle(tracks: subtitles.map {
            .init(index: Int($0.trackID), language: $0.languageCode)
        }, readySubtitleIDs: Set((layer.player.subtitleDataSouce?.infos ?? [])
            .compactMap { Int($0.subtitleID) }))
        let audioOptions = PlaybackTrackLabels.options(audio, isSubtitle: false)
        let subtitleOptions = [PlaybackUITrack(id: -1, name: NSLocalizedString("player.subtitles.off", comment: ""))]
            + PlaybackTrackLabels.options(subtitles, isSubtitle: true)
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
#if DEBUG
        let observeCapacity = controls.seekCapacityObserver(for: plan.id) { [weak controls] fields in
            controls?.event("seek_capacity_sample", metrics: fields)
        }
        options.reportSeekCapacity = { generation, fields in
            Task { @MainActor in observeCapacity(generation, fields) }
        }
#endif
        let observePlayback = controls.pictureInPicturePlaybackObserver(for: plan.id) { [weak controls] metrics in
            controls?.event("pip_system_playback_changed", metrics: metrics)
        }
        options.pictureInPicturePlaybackChanged = { requested, actual, seconds, uptime in
            Task { @MainActor in observePlayback(requested, actual, seconds, uptime) }
        }
        var lastPiPSubtitleReport = -Double.infinity
        options.pictureInPictureFrameTransformWithContext = controls.pictureInPictureFrameTransform(for: plan.id) {
            [weak controls, weak coordinator] buffer, _, frameContext in
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
            let result = controls.pipSubtitleCompositor.composite(buffer, text: text, images: images,
                videoSize: player.naturalSize, frameContext: frameContext)
            let output = result.pixelBuffer
            if seconds - lastPiPSubtitleReport > 5 || seconds < lastPiPSubtitleReport {
                lastPiPSubtitleReport = seconds
                let transfer = CVBufferCopyAttachment(buffer, kCVImageBufferTransferFunctionKey, nil) as? String
                controls.event("pip_subtitle_frame", metrics: ["seconds": String(seconds),
                    "textLength": String(text?.count ?? 0), "imageCount": String(images.count),
                    "external": String(controls.pipExternalSubtitle.isEnabled), "composited": String(output != nil),
                    "compositionReason": result.reason,
                    "allocationStatus": result.status.map { String($0) } ?? "notAttempted",
                    "sourceTransfer": transfer ?? "unspecified",
                    "sourcePixelFormat": String(CVPixelBufferGetPixelFormatType(buffer)),
                    "sourceWidth": String(CVPixelBufferGetWidth(buffer)),
                    "sourceHeight": String(CVPixelBufferGetHeight(buffer))].merging(
                        GreenfieldPiPFrameInventory.fields(buffer: buffer, context: frameContext)) { _, new in new }
                        .merging(result.metrics) { _, new in new })
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
        var recordedFirstOutputCompletion = false
        options.pausedSeekPreviewSubmitted = { [weak controls] seconds in
            Task { @MainActor [weak controls] in
                guard let controls, controls.planID == expectedPlanID else { return }
                controls.acceptPausedSeekPreview(seconds)
            }
        }
        options.videoFrameSubmitted = { [weak controls, weak options] seconds, forced in
            let startup = options?.videoStartupTiming.snapshot
            let hasOutput = startup?.samples[.outputSubmitted] != nil
            guard forced || !recordedFirstSubmission || (hasOutput && !recordedFirstOutputCompletion) else { return }
            recordedFirstSubmission = true
            recordedFirstOutputCompletion = recordedFirstOutputCompletion || hasOutput
            let prepare = options?.prepareTime ?? 0
            Task { @MainActor [weak controls] in
                guard let controls, controls.planID == expectedPlanID else { return }
                controls.event("video_frame_submitted", metrics: [
                    "framePTSSeconds": String(seconds),
                    "controlSeconds": String(controls.currentSeconds),
                    "forcedPreview": String(forced),
                    "acceptedVideoFrameMs": PlaybackStageTiming.milliseconds(start: prepare, end: startup?.samples[.acceptedFrame]?.time ?? 0),
                    "acceptedVideoFramePTS": startup?.samples[.acceptedFrame].map { String($0.pts) } ?? "missing",
                    "outputAttemptMs": PlaybackStageTiming.milliseconds(start: prepare, end: startup?.samples[.outputAttempt]?.time ?? 0),
                    "outputSubmittedMs": PlaybackStageTiming.milliseconds(start: prepare, end: startup?.samples[.outputSubmitted]?.time ?? 0),
                    "outputSubmittedPTS": startup?.samples[.outputSubmitted].map { String($0.pts) } ?? "missing",
                    "outputPath": startup?.samples[.outputSubmitted]?.path ?? "notConfirmed",
                    "discardedVideoFramesBeforeAccepted": String(startup?.discardedBeforeFirstAccepted ?? 0),
                    "evidence": "rendererAttemptAndOutputAPIBoundaryNotPresentation"
                ].merging(startup?.fields(prepare: prepare) ?? [:]) { _, new in new })
            }
        }
        if plan.primaryRoute.playMethod == .directPlay {
            options.sourceAudioID = plan.tracks.selectedSourceAudioTrackID.flatMap(Int32.init)
            if plan.subtitles.mode != .disabled, controls.pipInitialExternalSubtitleURL == nil {
                options.preferredEmbeddedSubtitleTrackID = plan.tracks.selectedSourceSubtitleTrackID.flatMap(Int32.init)
            }
        }
        PlaybackKSOptionsPolicy.apply(plan, to: options)
        options.autoSelectEmbedSubtitle = false // Explicit source ID controls rendered selection.
        options.canStartPictureInPictureAutomaticallyFromInline = true

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

    private static func configureDefaultEngine() { PlaybackKSOptionsPolicy.configureDefaultEngine() }

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

#if canImport(KSPlayer)
/// Inventory names, types and byte counts only; never copy payloads or change attachments.
enum GreenfieldPiPFrameInventory {
    static func fields(buffer: CVPixelBuffer, context: KSPictureInPictureFrameContext) -> [String: String] {
        func summary(_ values: [String: Any]) -> String {
            values.keys.sorted().map { key in
                let value = values[key]!
                let kind: String
                if let data = value as? Data { kind = "data:\(data.count)" }
                else if let dictionary = value as? [String: Any] {
                    kind = "dictionary{" + summary(dictionary) + "}"
                } else if let values = value as? [Any] { kind = "array:\(values.count)" }
                else if value is String { kind = "string" }
                else if value is NSNumber { kind = "number" }
                else { kind = "other" }
                return key + ":" + kind
            }.joined(separator: "|")
        }
        let propagated = CVBufferCopyAttachments(buffer, .shouldPropagate) as? [String: Any] ?? [:]
        let unpropagated = CVBufferCopyAttachments(buffer, .shouldNotPropagate) as? [String: Any] ?? [:]
        let display = CMFormatDescriptionGetExtensions(context.displayFormatDescription) as? [String: Any] ?? [:]
        let compressed = context.compressedFormatDescription.flatMap {
            CMFormatDescriptionGetExtensions($0) as? [String: Any]
        }
        return ["sourceIsDolbyVision": String(context.isDolbyVision),
                "sourceDolbyProfile": context.dolbyConfiguration.map { String($0.dv_profile) } ?? "unknown",
                "sourceDolbyCompatibilityID": context.dolbyConfiguration.map { String($0.dv_bl_signal_compatibility_id) } ?? "unknown",
                "sourceDolbyBaseLayerPresent": context.dolbyConfiguration.map { String($0.bl_present_flag) } ?? "unknown",
                "sourceDolbyEnhancementLayerPresent": context.dolbyConfiguration.map { String($0.el_present_flag) } ?? "unknown",
                "sourceDolbyRPUPresent": context.dolbyConfiguration.map { String($0.rpu_present_flag) } ?? "unknown",
                "frameHasStaticEDR": String(context.hasStaticEDR),
                "frameMasteringDisplayBytes": String(context.masteringDisplayData?.count ?? 0),
                "frameMasteringMaximumNits": context.masteringMaximumNits.map { String($0) } ?? "unknown",
                "sideDataInspection": context.sideDataInspection,
                "sideDataSizes": context.sideDataSizes.keys.sorted().map {
                    $0 + ":" + String(context.sideDataSizes[$0]!)
                }.joined(separator: "|"),
                "sourceCompressedDescriptionAvailable": String(compressed != nil),
                "sourceCompressedFormatSubtype": context.compressedFormatDescription.map {
                    String(CMFormatDescriptionGetMediaSubType($0))
                } ?? "unknown",
                "compressedExtensionInventory": compressed.map(summary) ?? "unknown",
                "displayExtensionInventory": summary(display),
                "pixelPropagatedInventory": summary(propagated),
                "pixelUnpropagatedInventory": summary(unpropagated)]
    }
}
#endif

#if canImport(KSPlayer)
/// Experimental scope: inspected PQ frames with a verified HDR-compatible base.
/// A transformed base-layer sample carries HDR10 metadata, never an old Dolby RPU.
enum GreenfieldPiPPQAdmission {
    static func rejection(buffer: CVPixelBuffer, context: KSPictureInPictureFrameContext) -> String? {
        guard CVPixelBufferGetWidth(buffer) == 3840, CVPixelBufferGetHeight(buffer) == 2160,
              CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange else {
            return "hdrFixedGeometryUnsupported"
        }
        guard context.sideDataInspection == "avFrameBeforeFilter",
              context.compressedFormatDescription != nil else { return "hdrDynamicInventoryUnknown" }
        let allowed: Set<String> = ["Content light level metadata", "Mastering display metadata",
                                   "Dolby Vision Metadata", "Dolby Vision RPU Data"]
        guard context.sideDataSizes.keys.allSatisfy({ allowed.contains($0) }) else {
            return "hdrSideDataUnhandled"
        }
        let hasDolbyData = context.sideDataSizes.keys.contains { $0.contains("Dolby") }
        if context.isDolbyVision || hasDolbyData {
            guard context.isDolbyVision, let dovi = context.dolbyConfiguration,
                  dovi.bl_present_flag == 1, dovi.rpu_present_flag == 1,
                  (dovi.dv_profile == 7 && dovi.dv_bl_signal_compatibility_id == 6)
                    || (dovi.dv_profile == 8 && dovi.dv_bl_signal_compatibility_id == 1) else {
                return "hdrDolbyBaseCompatibilityUnknown"
            }
        }
        guard context.masteringDisplayData?.count == 24,
              let maximum = context.masteringMaximumNits, maximum.isFinite, maximum >= 203 else {
            return "hdrMasteringMetadataUnavailable"
        }
        func value(_ key: CFString) -> String? { CVBufferCopyAttachment(buffer, key, nil) as? String }
        guard value(kCVImageBufferTransferFunctionKey) == kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String,
              value(kCVImageBufferColorPrimariesKey) == kCVImageBufferColorPrimaries_ITU_R_2020 as String,
              value(kCVImageBufferYCbCrMatrixKey) == kCVImageBufferYCbCrMatrix_ITU_R_2020 as String else {
            return "hdrColorDescriptionUnsupported"
        }
        guard CVBufferCopyAttachment(buffer, kCVImageBufferCleanApertureKey, nil) == nil else {
            return "hdrCleanApertureUnhandled"
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(context.displayFormatDescription)
        guard dimensions.width == 3840, dimensions.height == 2160 else { return "hdrFrameDescriptionMismatch" }
        return nil
    }
}

/// Never retire/replace this pool. A new fifth surface latches the allocator off;
/// no sixth allocation can be attempted even if downstream retains old aliases.
struct GreenfieldPiPSurfaceLedger {
    private(set) var surfaces = Set<UInt32>()
    private(set) var disabled = false
    mutating func disable() { disabled = true }
    mutating func admit(_ id: UInt32) -> Bool {
        guard !disabled else { return false }
        surfaces.insert(id)
        if surfaces.count > 4 { disabled = true; return false }
        return true
    }
}

enum GreenfieldPiPReferenceWhite {
    static func gain(measuredNits: Double) -> Double? {
        guard measuredNits.isFinite, (80...250).contains(measuredNits) else { return nil }
        return 203 / measuredNits
    }
    /// The rendering context performs this matrix in linear BT.2020; only
    /// subtitle RGB is scaled. Alpha and the source movie remain unchanged.
    static func normalized(_ image: CIImage, gain: Double) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: gain, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: gain, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: gain, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)])
    }
}

final class GreenfieldPiPFixedPQBank {
    static let shared = GreenfieldPiPFixedPQBank()
    private let lock = NSLock()
    private let pool: CVPixelBufferPool?
    private let context: CIContext?
    private let pq = CGColorSpace(name: CGColorSpace.itur_2100_PQ)
    private var ledger = GreenfieldPiPSurfaceLedger()
    private var checked = false
    private var validated = false
    private var subtitleGain = 1.0
    private var facts: [String: String] = [:]

    private init() {
        if let linear = CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020) {
            context = CIContext(options: [.workingColorSpace: linear, .workingFormat: CIFormat.RGBAh,
                                          .cacheIntermediates: false])
        } else { context = nil }
        var result: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(nil,
            [kCVPixelBufferPoolMinimumBufferCountKey: 4, kCVPixelBufferPoolMaximumBufferAgeKey: 0] as CFDictionary,
            [kCVPixelBufferWidthKey: 3840, kCVPixelBufferHeightKey: 2160,
             kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
             kCVPixelBufferBytesPerRowAlignmentKey: 64,
             kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &result)
        pool = status == 0 ? result : nil
        facts["hdrPoolCreationStatus"] = String(status)
    }

    private func checkout() -> CVPixelBuffer? {
        guard !ledger.disabled, let pool else { return nil }
        var result: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pool,
            [kCVPixelBufferPoolAllocationThresholdKey: 4] as CFDictionary, &result)
        facts["hdrCheckoutStatus"] = String(status)
        guard status == 0, let result, let surface = CVPixelBufferGetIOSurface(result)?.takeUnretainedValue() else { return nil }
        guard ledger.admit(IOSurfaceGetID(surface)) else {
            facts["hdrPoolDisabled"] = "newFifthSurfaceObserved"
            return nil
        }
        guard IOSurfaceGetAllocSize(surface) <= 32 * 1024 * 1024 else {
            facts["hdrPoolDisabled"] = "unexpectedSurfaceAllocationSize"
            ledger.disable()
            validated = false
            return nil
        }
        return result
    }

    private func stamp(_ buffer: CVPixelBuffer, mastering: Data? = nil) {
        CVBufferRemoveAllAttachments(buffer)
        CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey,
                              kCVImageBufferColorPrimaries_ITU_R_2020, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey,
                              kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey,
                              kCVImageBufferYCbCrMatrix_ITU_R_2020, .shouldPropagate)
        if let mastering {
            CVBufferSetAttachment(buffer, kCVImageBufferMasteringDisplayColorVolumeKey, mastering as CFData, .shouldPropagate)
        }
    }

    private func yCode(_ buffer: CVPixelBuffer) -> Int {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        return Int(CVPixelBufferGetBaseAddressOfPlane(buffer, 0)!.assumingMemoryBound(to: UInt16.self).pointee >> 6)
    }
    private func pqNits(_ code: Int) -> Double {
        let value = max(0, min(1, Double(code - 64) / 876))
        let p = pow(value, 1 / (2523.0 / 32))
        return 10000 * pow(max(p - 3424.0 / 4096, 0) / (2413.0 / 128 - 2392.0 / 128 * p), 1 / (2610.0 / 16384))
    }
    private func validate() -> Bool {
        guard let context, let pq, let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return false }
        func tiny() -> CVPixelBuffer? {
            var result: CVPixelBuffer?
            guard CVPixelBufferCreate(nil, 16, 16, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
                [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &result) == 0 else { return nil }
            return result
        }
        guard let first = tiny(), let second = tiny() else { return false }
        stamp(first); stamp(second)
        let bounds = CGRect(x: 0, y: 0, width: 16, height: 16)
        let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1, colorSpace: srgb)!).cropped(to: bounds)
        context.render(white, to: first, bounds: bounds, colorSpace: pq)
        let nativeNits = pqNits(yCode(first))
        facts["hdrProbeNativeWhiteNits"] = String(nativeNits)
        guard let gain = GreenfieldPiPReferenceWhite.gain(measuredNits: nativeNits) else { return false }
        subtitleGain = gain
        facts["hdrSubtitleLinearGain"] = String(gain)
        context.render(GreenfieldPiPReferenceWhite.normalized(white, gain: gain),
                       to: first, bounds: bounds, colorSpace: pq)
        context.render(CIImage(cvPixelBuffer: first, options: [.colorSpace: pq]), to: second, bounds: bounds, colorSpace: pq)
        let nits = pqNits(yCode(first)), delta = abs(yCode(first) - yCode(second))
        facts["hdrProbeWhiteNits"] = String(nits); facts["hdrProbeRoundtripCodeDelta"] = String(delta)
        guard (190...216).contains(nits), delta <= 2 else { return false }
        var held = [CVPixelBuffer]()
        for _ in 0..<4 { guard let buffer = checkout() else { return false }; held.append(buffer) }
        guard checkout() == nil else { return false }
        func makeAlias() -> CVPixelBuffer? {
            let original = held.removeFirst()
            guard let surface = CVPixelBufferGetIOSurface(original)?.takeUnretainedValue() else { return nil }
            var alias: Unmanaged<CVPixelBuffer>?
            guard CVPixelBufferCreateWithIOSurface(nil, surface, nil, &alias) == 0 else { return nil }
            CVBufferRemoveAllAttachments(original)
            return alias?.takeRetainedValue()
        }
        guard let alias = makeAlias() else { return false }
        let refused = withExtendedLifetime(alias) { checkout() == nil }
        facts["hdrProbeHeldAliasAllocationRefused"] = String(refused)
        facts["hdrNominalOutputSurfaces"] = "4"
        facts["hdrLifetimeSurfaceGuard"] = "disableOnFifthNeverAllocateSixth"
        return refused && ledger.surfaces.count == 4 && !ledger.disabled
    }

    func render(source: CVPixelBuffer, overlay: CIImage, mastering: Data, dolbyBase: Bool)
        -> GreenfieldPiPSubtitleCompositor.Outcome {
        lock.lock(); defer { lock.unlock() }
        if !checked { checked = true; validated = validate() }
        guard validated, !ledger.disabled, let context, let pq else {
            return .init(pixelBuffer: nil, reason: "hdrDeviceValidationFailed", metrics: facts)
        }
        guard let output = checkout() else {
            return .init(pixelBuffer: nil, reason: "hdrFixedPoolUnavailable", metrics: facts)
        }
        stamp(output, mastering: mastering)
        if let aspect = CVBufferCopyAttachment(source, kCVImageBufferPixelAspectRatioKey, nil) {
            CVBufferSetAttachment(output, kCVImageBufferPixelAspectRatioKey, aspect, .shouldPropagate)
        }
        let started = ProcessInfo.processInfo.systemUptime
        context.render(GreenfieldPiPReferenceWhite.normalized(overlay, gain: subtitleGain)
            .composited(over: CIImage(cvPixelBuffer: source, options: [.colorSpace: pq])),
                       to: output, bounds: CGRect(x: 0, y: 0, width: 3840, height: 2160), colorSpace: pq)
        facts["hdrRenderMilliseconds"] = String((ProcessInfo.processInfo.systemUptime - started) * 1000)
        facts["hdrObservedUniqueSurfaces"] = String(ledger.surfaces.count)
        facts["hdrOutputMode"] = dolbyBase ? "compatibleHDR10BaseWithCaptions" : "HDR10WithCaptions"
        facts["hdrDynamicPayloadCopied"] = "false"
        facts["hdrOriginalContentLightMetadataCopied"] = "false"
        return .init(pixelBuffer: output, reason: "hdrPQOutputCreated", status: kCVReturnSuccess, metrics: facts)
    }
}
#endif

/// Subtitles must be inside PiP's video sample buffers; SwiftUI overlays belong
/// only to the full-screen view. This opt-in compositor leaves normal playback
/// untouched and caches the transparent subtitle canvas until its cue changes.
final class GreenfieldPiPSubtitleCompositor {
    struct Outcome {
        let pixelBuffer: CVPixelBuffer?
        let reason: String
        var status: CVReturn? = nil
        var metrics: [String: String] = [:]
    }

    let hdrCandidateEnabled: Bool
    init(hdrCandidateEnabled: Bool = GreenfieldPiPSubtitleCompositor.hdrExperimentEnabled) {
        self.hdrCandidateEnabled = hdrCandidateEnabled
    }
    static var hdrExperimentEnabled: Bool {
#if DEBUG
        // The compatible-base route passed real iPhone/iPad caption checks.
        // Keep an explicit legacy opt-out for comparisons; Release stays off.
        let override = ProcessInfo.processInfo.environment["NASTART_PIP_PQ_CANDIDATE"]
        return override == nil || override == "1"
#else
        false
#endif
    }

    private let context = CIContext(options: [.cacheIntermediates: false])
    private var pool: CVPixelBufferPool?
    private var poolSize = CGSize.zero
    private var lastKey = ""
    private var overlay: CIImage?

    func composite(_ source: CVPixelBuffer, text: String?, images: [(UIImage, CGPoint, CGSize)], videoSize: CGSize) -> Outcome {
        let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty || !images.isEmpty else { return Outcome(pixelBuffer: nil, reason: "noCue") }
        // Do not silently flatten an HDR/Dolby signal into an SDR buffer.
        let transfer = CVBufferCopyAttachment(source, kCVImageBufferTransferFunctionKey, nil) as? String
        if transfer == (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String) {
            return Outcome(pixelBuffer: nil, reason: "hdrPQPreserved")
        }
        if transfer == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String) {
            return Outcome(pixelBuffer: nil, reason: "hdrHLGPreserved")
        }
        let width = CVPixelBufferGetWidth(source), height = CVPixelBufferGetHeight(source)
        let size = CGSize(width: width, height: height)
        _ = subtitleOverlay(text: text, images: images, size: size, videoSize: videoSize)
        if poolSize != size || pool == nil {
            poolSize = size
            let attributes: [String: Any] = [kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height, kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
            let status = CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
            guard status == kCVReturnSuccess else {
                return Outcome(pixelBuffer: nil, reason: "poolCreationFailed", status: status)
            }
        }
        guard let pool else { return Outcome(pixelBuffer: nil, reason: "poolUnavailable") }
        guard let overlay else { return Outcome(pixelBuffer: nil, reason: "overlayUnavailable") }
        var output: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pool,
            [kCVPixelBufferPoolAllocationThresholdKey: 4] as CFDictionary, &output)
        guard status == kCVReturnSuccess, let output else {
            return Outcome(pixelBuffer: nil, reason: "bufferAllocationFailed", status: status)
        }
        context.render(overlay.composited(over: CIImage(cvPixelBuffer: source)), to: output,
            bounds: CGRect(origin: .zero, size: size), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return Outcome(pixelBuffer: output, reason: "outputCreated", status: status)
    }
    private func subtitleOverlay(text: String, images: [(UIImage, CGPoint, CGSize)],
                                 size: CGSize, videoSize: CGSize) -> CIImage? {
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
        return overlay
    }

#if canImport(KSPlayer)
    func composite(_ source: CVPixelBuffer, text: String?, images: [(UIImage, CGPoint, CGSize)],
                   videoSize: CGSize, frameContext: KSPictureInPictureFrameContext) -> Outcome {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let transfer = CVBufferCopyAttachment(source, kCVImageBufferTransferFunctionKey, nil) as? String
        guard hdrCandidateEnabled, (!trimmed.isEmpty || !images.isEmpty),
              transfer == kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String else {
            return composite(source, text: text, images: images, videoSize: videoSize)
        }
        if let reason = GreenfieldPiPPQAdmission.rejection(buffer: source, context: frameContext) {
            return Outcome(pixelBuffer: nil, reason: reason)
        }
        let size = CGSize(width: CVPixelBufferGetWidth(source), height: CVPixelBufferGetHeight(source))
        guard let overlay = subtitleOverlay(text: trimmed, images: images, size: size, videoSize: videoSize) else {
            return Outcome(pixelBuffer: nil, reason: "hdrOverlayUnavailable")
        }
        return GreenfieldPiPFixedPQBank.shared.render(source: source, overlay: overlay,
            mastering: frameContext.masteringDisplayData!, dolbyBase: frameContext.isDolbyVision)
    }
#endif

}

/// Containers often carry only an ISO language code and a codec identifier, and
/// Blu-ray transport streams carry neither for subtitles. Menus need readable names.
enum PlaybackTrackLabels {
    static func options(_ tracks: [any MediaPlayerTrack], isSubtitle: Bool) -> [PlaybackUITrack] {
        let names = tracks.enumerated().map { index, track in
            label(for: track, index: index, isSubtitle: isSubtitle)
        }
        var seen: [String: Int] = [:]
        let totals = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
        return zip(tracks, names).map { track, name in
            guard totals[name, default: 0] > 1 else { return PlaybackUITrack(id: track.trackID, name: name) }
            seen[name, default: 0] += 1
            return PlaybackUITrack(id: track.trackID, name: "\(name) \(seen[name]!)")
        }
    }

    private static func label(for track: any MediaPlayerTrack, index: Int, isSubtitle: Bool) -> String {
        let codec = (track as? FFmpegAssetTrack)?.codecName ?? ""
        let name = track.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasTitle = !name.isEmpty && name != codec && name != track.languageCode
        let primary = hasTitle ? name : languageName(track.languageCode)
        if isSubtitle {
            let heading = primary ?? String(format: NSLocalizedString("player.subtitles.track_format", comment: ""), index + 1)
            return track.isImageSubtitle ? "\(heading) · \(NSLocalizedString("player.subtitles.image", comment: ""))" : heading
        }
        return [primary, codecName(codec)].compactMap { $0 }.joined(separator: " · ")
    }

    static func languageName(_ code: String?) -> String? {
        guard let code = code?.lowercased(), !code.isEmpty, code != "und" else { return nil }
        let bibliographic = ["chi": "zh", "zho": "zh", "cmn": "zh", "yue": "yue", "eng": "en", "jpn": "ja", "kor": "ko",
            "fre": "fr", "fra": "fr", "ger": "de", "deu": "de", "spa": "es", "ita": "it", "rus": "ru", "por": "pt",
            "tha": "th", "vie": "vi", "ara": "ar", "dut": "nl", "nld": "nl", "hin": "hi"]
        let normalized = bibliographic[code] ?? code
        return Locale.current.localizedString(forLanguageCode: normalized) ?? code
    }

    static func codecName(_ codec: String) -> String? {
        let id = codec.split(separator: " ").first.map { $0.lowercased() } ?? ""
        guard !id.isEmpty else { return nil }
        if id.hasPrefix("pcm") { return "LPCM" }
        let known = ["truehd": "TrueHD", "mlp": "MLP", "ac3": "AC3", "eac3": "E-AC3", "dts": "DTS", "dca": "DTS",
            "aac": "AAC", "flac": "FLAC", "opus": "Opus", "mp3": "MP3", "mp3float": "MP3", "vorbis": "Vorbis", "alac": "ALAC"]
        return known[id] ?? id.uppercased()
    }
}
