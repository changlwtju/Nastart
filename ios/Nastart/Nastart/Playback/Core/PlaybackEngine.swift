import Foundation

enum PlaybackEngineState: String, Codable, Sendable {
    case idle
    case preparing
    case ready
    case playing
    case paused
    case buffering
    case ended
    case failed
}

struct PlaybackRuntimeState: Codable, Equatable, Sendable {
    var state: PlaybackEngineState
    var position: TimeInterval
    var duration: TimeInterval?
    var playbackRate: Float
    var selectedAudioTrackID: String?
    var selectedSubtitleTrackID: String?

    init(
        state: PlaybackEngineState = .idle,
        position: TimeInterval = 0,
        duration: TimeInterval? = nil,
        playbackRate: Float = 1,
        selectedAudioTrackID: String? = nil,
        selectedSubtitleTrackID: String? = nil
    ) {
        self.state = state
        self.position = max(position, 0)
        self.duration = duration.flatMap { $0 > 0 ? $0 : nil }
        self.playbackRate = min(max(playbackRate, 0.25), 4)
        self.selectedAudioTrackID = selectedAudioTrackID
        self.selectedSubtitleTrackID = selectedSubtitleTrackID
    }
}

enum PlaybackEngineError: Error, Equatable {
    case unsupportedPlan(String)
    case prepareFailed(String)
    case playbackFailed(String)
    case seekFailed(String)
    case trackSelectionFailed(String)
    case pictureInPictureUnavailable
}

protocol PlaybackEngine: AnyObject {
    var name: String { get }
    var supportedCandidates: Set<PlaybackEngineCandidate> { get }

    func prepare(_ plan: PlaybackPlan) async throws
    func play() async throws
    func pause() async
    func stop() async
    func seek(to seconds: TimeInterval, mode: PlaybackSeekMode) async throws
    func setRate(_ rate: Float) async throws
    func selectAudioTrack(id: String?) async throws
    func selectSubtitleTrack(id: String?) async throws
    func enterPictureInPicture() async throws
    func leavePictureInPicture() async
    func snapshotRuntimeState() async -> PlaybackRuntimeState
}

extension PlaybackEngine {
    func supports(_ candidate: PlaybackEngineCandidate) -> Bool {
        supportedCandidates.contains(candidate)
    }
}

protocol PlaybackSourceResolver {
    var sourceKind: PlaybackSourceKind { get }

    func resolve(_ intent: PlaybackIntent) async throws -> PlaybackPlan
}
