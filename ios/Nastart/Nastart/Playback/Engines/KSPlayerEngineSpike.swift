import Foundation

final class KSPlayerEngineSpike: PlaybackEngine {
    let name = "KSPlayerEngineSpike"
    let supportedCandidates: Set<PlaybackEngineCandidate> = [.ksPlayer]

    private var plan: PlaybackPlan?
    private var runtimeState = PlaybackRuntimeState()

    func prepare(_ plan: PlaybackPlan) async throws {
        guard supports(plan.enginePolicy) else {
            throw PlaybackEngineError.unsupportedPlan("Expected ksPlayer engine policy.")
        }
        self.plan = plan
        runtimeState = PlaybackRuntimeState(
            state: .preparing,
            position: plan.timeline.startTime,
            duration: plan.timeline.duration,
            playbackRate: plan.intent.playbackRate,
            selectedAudioTrackID: plan.tracks.selectedSourceAudioTrackID,
            selectedSubtitleTrackID: plan.tracks.selectedSourceSubtitleTrackID
        )

        throw PlaybackEngineError.unsupportedPlan(
            "KSPlayer is not linked yet. This spike defines the integration boundary first."
        )
    }

    func play() async throws {
        runtimeState.state = .playing
    }

    func pause() async {
        runtimeState.state = .paused
    }

    func stop() async {
        runtimeState.state = .ended
    }

    func seek(to seconds: TimeInterval, mode: PlaybackSeekMode) async throws {
        _ = mode
        runtimeState.position = max(seconds, 0)
    }

    func setRate(_ rate: Float) async throws {
        runtimeState.playbackRate = min(max(rate, 0.25), 4)
    }

    func selectAudioTrack(id: String?) async throws {
        runtimeState.selectedAudioTrackID = id
    }

    func selectSubtitleTrack(id: String?) async throws {
        runtimeState.selectedSubtitleTrackID = id
    }

    func enterPictureInPicture() async throws {
        throw PlaybackEngineError.pictureInPictureUnavailable
    }

    func leavePictureInPicture() async {}

    func snapshotRuntimeState() async -> PlaybackRuntimeState {
        runtimeState
    }
}
