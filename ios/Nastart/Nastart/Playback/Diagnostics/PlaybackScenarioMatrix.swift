import Foundation

enum PlaybackScenarioID: String, Codable, CaseIterable, Sendable {
    case coldStart = "cold_start_playback"
    case firstFrame = "first_frame_capture"
    case continuous30s = "continuous_playback_30s"
    case pauseResume = "pause_then_resume"
    case seekForwardBackward = "seek_forward_backward"
    case audioTrackSwitch = "audio_track_switch_during_playback"
    case subtitleSwitch = "subtitle_switch_during_playback"
    case jellyfinQualitySwitch = "jellyfin_quality_switch"
    case backgroundRecovery = "background_recovery"
    case pictureInPictureRoundTrip = "picture_in_picture_enter_exit"
    case endedAndNextItem = "playback_ended_and_next_item"
    case weakNetwork = "weak_network"
    case streamInterruption = "stream_interruption"
}

struct PlaybackScenarioRequirement: Identifiable, Codable, Equatable, Sendable {
    var id: PlaybackScenarioID
    var title: String
    var requiredEvents: [PlaybackDiagnosticsEventName]
    var requiredMetricKeys: [String]

    init(
        id: PlaybackScenarioID,
        title: String,
        requiredEvents: [PlaybackDiagnosticsEventName],
        requiredMetricKeys: [String] = []
    ) {
        self.id = id
        self.title = title
        self.requiredEvents = requiredEvents
        self.requiredMetricKeys = requiredMetricKeys
    }
}

enum PlaybackScenarioMatrix {
    static let baseline: [PlaybackScenarioRequirement] = [
        PlaybackScenarioRequirement(
            id: .coldStart,
            title: "Cold start playback",
            requiredEvents: [
                .intentCreated,
                .sourceResolveStarted,
                .routeSelected,
                .enginePrepareStarted,
                .engineReady
            ],
            requiredMetricKeys: [
                PlaybackMetricKeys.tapToResolveMs,
                PlaybackMetricKeys.resolveToRouteMs,
                PlaybackMetricKeys.openToReadyMs
            ]
        ),
        PlaybackScenarioRequirement(
            id: .firstFrame,
            title: "First frame capture",
            requiredEvents: [.firstFrame],
            requiredMetricKeys: [PlaybackMetricKeys.tapToFirstFrameMs]
        ),
        PlaybackScenarioRequirement(
            id: .continuous30s,
            title: "Continuous playback for 30 seconds",
            requiredEvents: [.continuousPlaybackCheckpoint],
            requiredMetricKeys: [PlaybackMetricKeys.continuousPlaybackSeconds]
        ),
        PlaybackScenarioRequirement(
            id: .pauseResume,
            title: "Pause and resume",
            requiredEvents: [.paused, .resumed],
            requiredMetricKeys: [
                PlaybackMetricKeys.pauseDurationMs,
                PlaybackMetricKeys.resumeRecoveryMs
            ]
        ),
        PlaybackScenarioRequirement(
            id: .seekForwardBackward,
            title: "Seek forward and backward",
            requiredEvents: [.seekStarted, .seekRecovered],
            requiredMetricKeys: [
                PlaybackMetricKeys.seekDeltaSeconds,
                PlaybackMetricKeys.seekTargetSeconds,
                PlaybackMetricKeys.seekRecoveryMs
            ]
        ),
        PlaybackScenarioRequirement(
            id: .audioTrackSwitch,
            title: "Switch audio track during playback",
            requiredEvents: [.audioTrackChanged],
            requiredMetricKeys: [PlaybackMetricKeys.audioCodec]
        ),
        PlaybackScenarioRequirement(
            id: .subtitleSwitch,
            title: "Switch subtitle during playback",
            requiredEvents: [.subtitleChanged],
            requiredMetricKeys: [PlaybackMetricKeys.subtitleCodec]
        ),
        PlaybackScenarioRequirement(
            id: .jellyfinQualitySwitch,
            title: "Switch Jellyfin quality",
            requiredEvents: [.qualityChanged, .routeSelected],
            requiredMetricKeys: [
                PlaybackMetricKeys.routeKind,
                PlaybackMetricKeys.playMethod,
                PlaybackMetricKeys.seekRecoveryMs
            ]
        ),
        PlaybackScenarioRequirement(
            id: .backgroundRecovery,
            title: "Recover after backgrounding",
            requiredEvents: [.backgroundEntered, .backgroundRecovered],
            requiredMetricKeys: [PlaybackMetricKeys.resumeRecoveryMs]
        ),
        PlaybackScenarioRequirement(
            id: .pictureInPictureRoundTrip,
            title: "Enter and leave Picture in Picture",
            requiredEvents: [.pipStarted, .pipStopped],
            requiredMetricKeys: [PlaybackMetricKeys.seekRecoveryMs]
        ),
        PlaybackScenarioRequirement(
            id: .endedAndNextItem,
            title: "Playback ended and next item",
            requiredEvents: [.playbackEnded, .nextItemStarted],
            requiredMetricKeys: [PlaybackMetricKeys.preloadedBytes]
        ),
        PlaybackScenarioRequirement(
            id: .weakNetwork,
            title: "Weak network playback",
            requiredEvents: [.networkConditionChanged, .bufferUpdated],
            requiredMetricKeys: [
                PlaybackMetricKeys.networkClass,
                PlaybackMetricKeys.bufferAheadSeconds,
                PlaybackMetricKeys.cacheMissBytes
            ]
        ),
        PlaybackScenarioRequirement(
            id: .streamInterruption,
            title: "Stream interruption recovery",
            requiredEvents: [.streamInterrupted, .fallbackSelected],
            requiredMetricKeys: [
                PlaybackMetricKeys.rangeRequestCount,
                PlaybackMetricKeys.seekRecoveryMs
            ]
        )
    ]
}
