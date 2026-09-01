import Foundation

enum PlaybackDiagnosticsEventName: String, Codable, CaseIterable, Sendable {
    case intentCreated = "intent_created"
    case sourceResolveStarted = "source_resolve_started"
    case playbackInfoLoaded = "playback_info_loaded"
    case routeProbeStarted = "route_probe_started"
    case routeProbeSucceeded = "route_probe_succeeded"
    case routeProbeFailed = "route_probe_failed"
    case routeSelected = "route_selected"
    case ioOpenStarted = "io_open_started"
    case ioOpened = "io_opened"
    case rangeRequested = "range_requested"
    case rangeReceived = "range_received"
    case cacheHit = "cache_hit"
    case cacheMiss = "cache_miss"
    case preloadStarted = "preload_started"
    case preloadCompleted = "preload_completed"
    case preloadCancelled = "preload_cancelled"
    case enginePrepareStarted = "engine_prepare_started"
    case engineReady = "engine_ready"
    case firstFrame = "first_frame"
    case bufferUpdated = "buffer_updated"
    case continuousPlaybackCheckpoint = "continuous_playback_checkpoint"
    case paused = "paused"
    case resumed = "resumed"
    case seekStarted = "seek_started"
    case seekRecovered = "seek_recovered"
    case audioTrackChanged = "audio_track_changed"
    case subtitleChanged = "subtitle_changed"
    case qualityChanged = "quality_changed"
    case backgroundEntered = "background_entered"
    case backgroundRecovered = "background_recovered"
    case pipStarted = "pip_started"
    case pipStopped = "pip_stopped"
    case playbackEnded = "playback_ended"
    case nextItemStarted = "next_item_started"
    case networkConditionChanged = "network_condition_changed"
    case streamInterrupted = "stream_interrupted"
    case fallbackSelected = "fallback_selected"
    case playbackFailed = "playback_failed"
    case playbackStopped = "playback_stopped"
}

struct PlaybackDiagnosticsEvent: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var date: Date
    var name: PlaybackDiagnosticsEventName
    var planID: UUID?
    var routeID: UUID?
    var engineName: String?
    var metrics: [String: String]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        name: PlaybackDiagnosticsEventName,
        planID: UUID? = nil,
        routeID: UUID? = nil,
        engineName: String? = nil,
        metrics: [String: String] = [:]
    ) {
        self.id = id
        self.date = date
        self.name = name
        self.planID = planID
        self.routeID = routeID
        self.engineName = engineName
        self.metrics = metrics
    }
}

actor PlaybackDiagnosticsRecorder {
    private(set) var events: [PlaybackDiagnosticsEvent] = []

    func record(_ event: PlaybackDiagnosticsEvent) {
        events.append(event)
        mirrorToAppDiagnostics(event)
    }

    func record(
        _ name: PlaybackDiagnosticsEventName,
        plan: PlaybackPlan? = nil,
        route: PlaybackRoute? = nil,
        engineName: String? = nil,
        metrics: [String: String] = [:]
    ) {
        let event = PlaybackDiagnosticsEvent(
            name: name,
            planID: plan?.id,
            routeID: route?.id ?? plan?.primaryRoute.id,
            engineName: engineName,
            metrics: metrics
        )
        events.append(event)
        mirrorToAppDiagnostics(event)
    }

    func events(for planID: UUID) -> [PlaybackDiagnosticsEvent] {
        events.filter { $0.planID == planID }
    }

    func reset() {
        events.removeAll()
    }

    private func mirrorToAppDiagnostics(_ event: PlaybackDiagnosticsEvent) {
        var details = event.metrics
        if let planID = event.planID {
            details["planID"] = planID.uuidString.prefix(8).description
        }
        if let routeID = event.routeID {
            details["routeID"] = routeID.uuidString.prefix(8).description
        }
        if let engineName = event.engineName {
            details["engine"] = engineName
        }
        DiagnosticLogStore.shared.record(
            diagnosticLevel(for: event.name),
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.playback.next.\(event.name.rawValue)",
            details: details
        )
    }

    private func diagnosticLevel(for name: PlaybackDiagnosticsEventName) -> DiagnosticLogLevel {
        switch name {
        case .playbackFailed:
            return .error
        case .routeProbeFailed,
             .preloadCancelled,
             .streamInterrupted,
             .fallbackSelected:
            return .warning
        default:
            return .info
        }
    }
}

struct PlaybackMetricKeys {
    static let tapToResolveMs = "tapToResolveMs"
    static let resolveToRouteMs = "resolveToRouteMs"
    static let routeToOpenMs = "routeToOpenMs"
    static let openToReadyMs = "openToReadyMs"
    static let tapToFirstFrameMs = "tapToFirstFrameMs"
    static let firstFrameMs = "firstFrameMs"
    static let continuousPlaybackSeconds = "continuousPlaybackSeconds"
    static let pauseDurationMs = "pauseDurationMs"
    static let resumeRecoveryMs = "resumeRecoveryMs"
    static let seekTargetSeconds = "seekTargetSeconds"
    static let seekDeltaSeconds = "seekDeltaSeconds"
    static let seekRecoveryMs = "seekRecoveryMs"
    static let bufferAheadSeconds = "bufferAheadSeconds"
    static let rangeRequestCount = "rangeRequestCount"
    static let rangeBytesRead = "rangeBytesRead"
    static let cacheHitBytes = "cacheHitBytes"
    static let cacheMissBytes = "cacheMissBytes"
    static let preloadedBytes = "preloadedBytes"
    static let decodeEngine = "decodeEngine"
    static let renderEngine = "renderEngine"
    static let videoCodec = "videoCodec"
    static let audioCodec = "audioCodec"
    static let subtitleCodec = "subtitleCodec"
    static let routeKind = "routeKind"
    static let playMethod = "playMethod"
    static let networkClass = "networkClass"
    static let connectionAddressKind = "connectionAddressKind"
    static let connectionScheme = "connectionScheme"
    static let connectionPort = "connectionPort"
    static let firstFrameTargetMs = "firstFrameTargetMs"
    static let startupPreloadBytes = "startupPreloadBytes"
    static let blocksFirstFrameUntilStartupPreload = "blocksFirstFrameUntilStartupPreload"
    static let trackSwitchTargetRecoveryMs = "trackSwitchTargetRecoveryMs"
    static let pipRequiresSystemRenderer = "pipRequiresSystemRenderer"
    static let ksPlayerLinked = "ksPlayerLinked"

    private init() {}
}
