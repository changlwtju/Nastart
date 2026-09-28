import AVFoundation
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
    case telemetrySample = "telemetry_sample"
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
    private let playbackTraceID: String?

    init(playbackTraceID: String? = nil) {
        self.playbackTraceID = playbackTraceID?.isEmpty == false ? playbackTraceID : nil
    }

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
        details["playbackTraceID"] = playbackTraceID ?? "-"
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

@MainActor
final class PlaybackTelemetrySampler {
    private let recorder: PlaybackDiagnosticsRecorder
    private let plan: PlaybackPlan
    private let engineName: String
    private let sampleInterval: TimeInterval
    private let startedAt = Date()

    private var sampleIndex = 0
    private var lastEmissionAt = Date.distantPast
    private var lastPlaybackSeconds: TimeInterval?
    private var lastProgressAt = Date()
    private var stallStartedAt: Date?
    private var stallCount = 0
    private var lastKSPlayerState: String?
    private var lastAVTimeControlStatus: AVPlayer.TimeControlStatus?

    init(
        recorder: PlaybackDiagnosticsRecorder,
        plan: PlaybackPlan,
        engineName: String,
        sampleInterval: TimeInterval = 1.0
    ) {
        self.recorder = recorder
        self.plan = plan
        self.engineName = engineName
        self.sampleInterval = max(sampleInterval, 0.25)
    }

    func sampleAVPlayer(
        _ player: AVPlayer,
        item: AVPlayerItem?,
        reason: String,
        force: Bool = false
    ) {
        let now = Date()
        guard force || now.timeIntervalSince(lastEmissionAt) >= sampleInterval else { return }
        lastEmissionAt = now

        let currentSeconds = player.currentTime().seconds
        let playbackSeconds = currentSeconds.isFinite ? currentSeconds : nil
        // Paused replacement items can have empty buffers by design. On resume,
        // give the clock a fresh progress baseline instead of counting the pause.
        if player.timeControlStatus == .paused ||
            (player.timeControlStatus == .playing && lastAVTimeControlStatus != .playing) {
            lastProgressAt = now
        }
        lastAVTimeControlStatus = player.timeControlStatus
        let deltaSeconds = updatePlaybackProgress(playbackSeconds, now: now)
        let timeControlStatus = Self.describe(player.timeControlStatus)
        let waitingReason = Self.describe(player.reasonForWaitingToPlay)
        let itemStatus = item.map { Self.describe($0.status) } ?? "-"
        let bufferAhead = item.flatMap { Self.bufferAheadSeconds(for: $0, playbackSeconds: playbackSeconds) }
        let accessLog = item?.accessLog()?.events.last
        let observedBitrate = accessLog?.observedBitrate
        let indicatedBitrate = accessLog?.indicatedBitrate
        let transferDuration = accessLog?.transferDuration
        let bytesTransferred = accessLog?.numberOfBytesTransferred
        let accessLogThroughput = Self.throughputMbps(
            bytes: bytesTransferred,
            duration: transferDuration
        )
        let isWaiting = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        let isBufferEmpty = item?.isPlaybackBufferEmpty == true
        let isLikelyToKeepUp = item?.isPlaybackLikelyToKeepUp == true
        let stallState = updateStallState(
            isWaitingOrEmpty: isWaiting || (player.timeControlStatus == .playing && isBufferEmpty),
            isPlaying: player.timeControlStatus == .playing,
            now: now
        )

        var metrics = baseMetrics(reason: reason, now: now)
        metrics["timeControlStatus"] = timeControlStatus
        metrics["reasonForWaiting"] = waitingReason
        metrics["itemStatus"] = itemStatus
        metrics["rate"] = Self.format(Double(player.rate))
        metrics["currentSeconds"] = Self.format(playbackSeconds)
        metrics["deltaSeconds"] = Self.format(deltaSeconds)
        metrics["bufferAheadSeconds"] = Self.format(bufferAhead)
        metrics["bufferEmpty"] = isBufferEmpty ? "yes" : "no"
        metrics["likelyToKeepUp"] = isLikelyToKeepUp ? "yes" : "no"
        metrics["loadedRangeCount"] = item.map { String($0.loadedTimeRanges.count) } ?? "-"
        metrics["observedBitrate"] = Self.formatBitrate(observedBitrate)
        metrics["indicatedBitrate"] = Self.formatBitrate(indicatedBitrate)
        metrics["accessLogStalls"] = accessLog.map { String($0.numberOfStalls) } ?? "-"
        metrics["accessLogBytes"] = bytesTransferred.map { String($0) } ?? "-"
        metrics["accessLogTransferMs"] = transferDuration.map { String(Int(($0 * 1000).rounded())) } ?? "-"
        metrics["accessLogThroughputMbps"] = Self.format(accessLogThroughput)
        metrics.merge(stallState) { _, new in new }
        emit(metrics)
    }

    func sampleKSPlayer(
        state: String? = nil,
        currentTime: TimeInterval? = nil,
        totalTime: TimeInterval? = nil,
        bufferedCount: Int? = nil,
        consumeTime: TimeInterval? = nil,
        runtimeMetrics: [String: String] = [:],
        reason: String,
        force: Bool = false
    ) {
        let now = Date()
        if let state {
            if lastKSPlayerState == "paused", state == "bufferFinished" || state == "playing" {
                lastProgressAt = now
                lastPlaybackSeconds = nil
            }
            lastKSPlayerState = state
        }
        guard force || now.timeIntervalSince(lastEmissionAt) >= sampleInterval else { return }
        lastEmissionAt = now

        let playbackSeconds = Self.sanitizedKSPlayerSeconds(currentTime)
        let durationSeconds = Self.sanitizedKSPlayerSeconds(totalTime)
        let deltaSeconds = updatePlaybackProgress(playbackSeconds, now: now)
        let isPlaying = lastKSPlayerState == "playing" || lastKSPlayerState == "bufferFinished"
            || (lastKSPlayerState != "paused" && (deltaSeconds ?? 0) > 0.05)
        let isBuffering = lastKSPlayerState == "buffering"
        let stallState = updateStallState(
            isWaitingOrEmpty: isBuffering,
            isPlaying: isPlaying,
            now: now
        )

        var metrics = baseMetrics(reason: reason, now: now)
        metrics["ksPlayerState"] = state ?? "-"
        metrics["currentSeconds"] = Self.format(playbackSeconds)
        metrics["deltaSeconds"] = Self.format(deltaSeconds)
        metrics["durationSeconds"] = Self.format(durationSeconds)
        metrics["bufferedCount"] = bufferedCount.map(String.init) ?? "-"
        metrics["consumeMs"] = consumeTime.map { String(Int(($0 * 1000).rounded())) } ?? "-"
        metrics.merge(runtimeMetrics) { _, latest in latest }
        metrics.merge(stallState) { _, new in new }
        emit(metrics)
    }

    func stop(reason: String) {
        var metrics = baseMetrics(reason: reason, now: Date())
        metrics["stallActive"] = stallStartedAt == nil ? "no" : "yes"
        metrics["stallCount"] = String(stallCount)
        emit(metrics)
    }

    private func baseMetrics(reason: String, now: Date) -> [String: String] {
        sampleIndex += 1
        return [
            "sampleReason": reason,
            "sampleIndex": String(sampleIndex),
            "elapsedMs": String(Int((now.timeIntervalSince(startedAt) * 1000).rounded())),
            "engine": engineName,
            "routeKind": plan.primaryRoute.routeKind.rawValue,
            "playMethod": plan.primaryRoute.playMethod.rawValue,
            "networkClass": plan.intent.networkContext.networkClass.rawValue,
            "addressKind": plan.intent.connectionContext.addressKind.rawValue
        ]
    }

    private func emit(_ metrics: [String: String]) {
        Task {
            await recorder.record(
                .telemetrySample,
                plan: plan,
                engineName: engineName,
                metrics: metrics
            )
        }
    }

    private func updatePlaybackProgress(
        _ playbackSeconds: TimeInterval?,
        now: Date
    ) -> TimeInterval? {
        guard let playbackSeconds else { return nil }
        defer { lastPlaybackSeconds = playbackSeconds }
        guard let lastPlaybackSeconds else {
            lastProgressAt = now
            return nil
        }
        let delta = playbackSeconds - lastPlaybackSeconds
        if delta > 0.05 {
            lastProgressAt = now
        }
        return delta
    }

    private func updateStallState(
        isWaitingOrEmpty: Bool,
        isPlaying: Bool,
        now: Date
    ) -> [String: String] {
        var metrics: [String: String] = [:]
        let progressRecentlyAdvanced = now.timeIntervalSince(lastProgressAt) < 1.5
        let isStalled = isWaitingOrEmpty || (isPlaying && !progressRecentlyAdvanced)
        if isStalled {
            if stallStartedAt == nil {
                stallStartedAt = now
                stallCount += 1
            }
            metrics["stallActive"] = "yes"
            metrics["stallCount"] = String(stallCount)
            if let stallStartedAt {
                metrics["stallDurationMs"] = String(
                    Int((now.timeIntervalSince(stallStartedAt) * 1000).rounded())
                )
            }
        } else {
            if let stallStartedAt {
                metrics["lastStallDurationMs"] = String(
                    Int((now.timeIntervalSince(stallStartedAt) * 1000).rounded())
                )
            }
            stallStartedAt = nil
            metrics["stallActive"] = "no"
            metrics["stallCount"] = String(stallCount)
        }
        return metrics
    }

    private static func bufferAheadSeconds(
        for item: AVPlayerItem,
        playbackSeconds: TimeInterval?
    ) -> TimeInterval? {
        let currentSeconds = playbackSeconds ?? item.currentTime().seconds
        guard currentSeconds.isFinite else { return nil }
        let ranges = item.loadedTimeRanges
            .map(\.timeRangeValue)
            .filter { $0.start.seconds.isFinite && $0.duration.seconds.isFinite }
        guard let containingRange = ranges.first(where: { range in
            let start = range.start.seconds
            let end = start + range.duration.seconds
            return currentSeconds >= start && currentSeconds <= end
        }) ?? ranges.first else {
            return nil
        }
        return max(
            containingRange.start.seconds + containingRange.duration.seconds - currentSeconds,
            0
        )
    }

    private static func throughputMbps(
        bytes: Int64?,
        duration: TimeInterval?
    ) -> Double? {
        guard let bytes, let duration, duration > 0 else { return nil }
        return Double(bytes) * 8 / duration / 1_000_000
    }

    private static func sanitizedKSPlayerSeconds(_ value: TimeInterval?) -> TimeInterval? {
        let maximumPlausibleMediaDuration: TimeInterval = 24 * 60 * 60
        guard let value,
              value.isFinite,
              value >= 0,
              value <= maximumPlausibleMediaDuration
        else {
            return nil
        }
        return value
    }

    private static func describe(_ status: AVPlayer.TimeControlStatus) -> String {
        switch status {
        case .paused: return "paused"
        case .waitingToPlayAtSpecifiedRate: return "waitingToPlayAtSpecifiedRate"
        case .playing: return "playing"
        @unknown default: return "unknown"
        }
    }

    private static func describe(_ status: AVPlayerItem.Status) -> String {
        switch status {
        case .unknown: return "unknown"
        case .readyToPlay: return "readyToPlay"
        case .failed: return "failed"
        @unknown default: return "unknown"
        }
    }

    private static func describe(_ reason: AVPlayer.WaitingReason?) -> String {
        guard let reason else { return "-" }
        if reason == .evaluatingBufferingRate { return "evaluatingBufferingRate" }
        if reason == .toMinimizeStalls { return "toMinimizeStalls" }
        if reason == .noItemToPlay { return "noItemToPlay" }
        return reason.rawValue
    }

    private static func format(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "-" }
        return String(format: "%.3f", value)
    }

    private static func formatBitrate(_ value: Double?) -> String {
        guard let value, value.isFinite, value > 0 else { return "-" }
        return String(Int(value.rounded()))
    }
}

struct PlaybackMetricKeys {
    static let tapToResolveMs = "tapToResolveMs"
    static let resolveToRouteMs = "resolveToRouteMs"
    static let routeToOpenMs = "routeToOpenMs"
    static let openToReadyMs = "openToReadyMs"
    static let tapToFirstFrameMs = "tapToFirstFrameMs"
    static let firstFramePositionSeconds = "firstFramePositionSeconds"
    static let firstFrameSignal = "firstFrameSignal"
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
