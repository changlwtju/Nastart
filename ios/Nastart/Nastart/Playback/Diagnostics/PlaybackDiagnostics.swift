import AVFoundation
import CryptoKit
import Foundation

/// Route-owned, bounded evidence. URI digests are comparison keys only and are
/// never exported. No global fallback can attach an old request to a new route.
final class PlaybackProxyRequestDiagnostics: @unchecked Sendable {
    private struct Record {
        let localKey: SHA256.Digest
        let upstreamKey: SHA256.Digest
        let transferID: UUID
        let role: String
        let childID: String
    }
    let routeID = UUID()
    private let lock = NSLock()
    private var records: [Record] = []
    private var historyTruncated = false
    private static let limit = 64

    static func safeTrace(_ value: String?) -> String {
        guard let value else { return "unknown" }
        if let uuid = UUID(uuidString: value) { return uuid.uuidString }
        if value.count == 8, value.utf8.allSatisfy({
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }) { return value.uppercased() }
        return "unknown"
    }

    static func role(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ext == "m3u8" { return url.path.lowercased().contains("master") ? "masterPlaylist" : "mediaPlaylist" }
        if ["m4s", "ts", "mp4", "aac", "mp3", "ac3", "vtt"].contains(ext) { return "segment" }
        if ["key", "bin"].contains(ext) { return "key" }
        return "unknown"
    }

    func record(localURL: URL, upstreamURL: URL, transferID: UUID, childID: String?) {
        let safeChild = childID.flatMap { value -> String? in
            guard value.count <= 80, !value.isEmpty,
                  value.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 46 }) else { return nil }
            return value
        }
        let record = Record(localKey: SHA256.hash(data: Data(localURL.absoluteString.utf8)),
            upstreamKey: SHA256.hash(data: Data(upstreamURL.absoluteString.utf8)),
            transferID: transferID, role: Self.role(for: upstreamURL),
            childID: childID == nil ? "root" : (safeChild ?? "unknown"))
        lock.lock(); defer { lock.unlock() }
        if records.count == Self.limit { records.removeFirst(); historyTruncated = true }
        records.append(record)
    }

    func fields(uri: String?) -> [String: String] {
        lock.lock(); defer { lock.unlock() }
        var fields = ["proxyDiagnosticRouteID": routeID.uuidString,
                      "binding": "missingURI", "hlsRole": "unknown",
                      "playlistChildID": "unknown", "transferID": "unknown",
                      "matchingTransfers": "0", "historyTruncated": String(historyTruncated)]
        guard let uri, let url = URL(string: uri),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return fields }
        let key = SHA256.hash(data: Data(url.absoluteString.utf8))
        let matches = records.filter { $0.localKey == key || $0.upstreamKey == key }
        fields["matchingTransfers"] = String(matches.count)
        guard let first = matches.first else { fields["binding"] = "unmatchedURI"; return fields }
        let unique = matches.count == 1 && !historyTruncated
        fields["binding"] = unique ? "exactSingleTransfer" : "ambiguousOrTruncated"
        fields["transferID"] = unique ? first.transferID.uuidString : "unknown"
        if matches.allSatisfy({ $0.role == first.role && $0.childID == first.childID }) {
            fields["hlsRole"] = first.role; fields["playlistChildID"] = first.childID
        }
        return fields
    }
}

enum PlaybackAVFailureDiagnostics {
    private static func safeDomain(_ domain: String) -> String {
        [NSURLErrorDomain, AVFoundationErrorDomain, NSOSStatusErrorDomain,
         NSPOSIXErrorDomain, "CoreMediaErrorDomain", "kCFErrorDomainCFNetwork"].contains(domain) ? domain : "other"
    }

    struct ErrorEvent {
        let domain: String
        let status: Int
        let date: Date?
        let uri: String?
    }

    /// Only typed fields and exact request bindings cross the diagnostic boundary.
    /// Raw URI, server address and error comment are deliberately absent.
    static func fields(events: [ErrorEvent], eventCount: Int? = nil, candidateCurrent: Bool,
                       resource: (String?) -> [String: String]) -> [String: String] {
        var fields = ["candidateCurrentAtFailure": String(candidateCurrent),
                      "candidateErrorLogEvents": String(eventCount ?? events.count),
                      "candidateErrorLogRecorded": String(min(events.count, 4))]
        for (index, event) in events.suffix(4).enumerated() {
            let prefix = "candidateError\(index)_"
            fields[prefix + "domain"] = safeDomain(event.domain)
            fields[prefix + "status"] = String(event.status)
            fields[prefix + "epochSeconds"] = event.date.flatMap {
                $0.timeIntervalSince1970.isFinite ? String($0.timeIntervalSince1970) : nil
            } ?? "unknown"
            for (key, value) in resource(event.uri) { fields[prefix + key] = value }
        }
        return fields
    }

    /// AV errorLog can be empty even when item.error is populated. Inspect only
    /// typed failing-URL keys and one bounded underlying chain; never descriptions
    /// or arbitrary userInfo, which may contain credentials or private paths.
    static func errorChainFields(_ error: NSError?, resource: (String?) -> [String: String]) -> [String: String] {
        var current = error
        var visited = Set<ObjectIdentifier>()
        var fields = ["candidateNSErrorEnd": error == nil ? "missing" : "leaf"]
        var count = 0
        while let error = current, count < 4 {
            guard visited.insert(ObjectIdentifier(error)).inserted else {
                fields["candidateNSErrorEnd"] = "cycle"; break
            }
            let prefix = "candidateNSError\(count)_"
            fields[prefix + "domain"] = safeDomain(error.domain)
            fields[prefix + "code"] = String(error.code)
            let uri = (error.userInfo[NSURLErrorFailingURLErrorKey] as? URL)?.absoluteString
                ?? (error.userInfo[NSURLErrorFailingURLStringErrorKey] as? String)
            for (key, value) in resource(uri) { fields[prefix + key] = value }
            count += 1
            current = error.userInfo[NSUnderlyingErrorKey] as? NSError
            if count == 4, current != nil { fields["candidateNSErrorEnd"] = "limit" }
        }
        fields["candidateNSErrorCount"] = String(count)
        return fields
    }
}

/// Call under the transfer's buffer lock. Upstream received bytes are supplied
/// separately; a partial playlist has sent zero response bytes to AVPlayer.
struct PlaybackPlaylistDeliveryDiagnostics {
    private(set) var headerSendCompleted = false
    private(set) var bodySendCompletedBytes = 0
    mutating func headerCompleted() { headerSendCompleted = true }
    mutating func bodyCompleted(bytes: Int) { bodySendCompletedBytes += max(bytes, 0) }
    func fields(upstreamReceived: Int) -> [String: String] {
        ["playlistUpstreamBodyReceivedBytes": String(upstreamReceived),
         "playlistClientHeaderSendCompleted": String(headerSendCompleted),
         "playlistClientBodySendCompletedBytes": String(bodySendCompletedBytes),
         "deliveredBytesMeaning": "legacyUpstreamPlaylistBodyReceived"]
    }
}

/// A correlation candidate for Jellyfin 10.11.11, never an authentication token
/// or proof that a server job exists. Keep paths and request headers out of logs.
enum PlaybackJellyfinOutputDiagnostics {
    static func mediaPath(path: String?, encoderPath: String?, hasEncoderProtocol: Bool) -> String? {
        if hasEncoderProtocol, let encoderPath, !encoderPath.isEmpty { return encoderPath }
        return path?.isEmpty == false ? path : nil
    }

    static func fields(mediaPath: String?, request: URLRequest, redirectCount: Int) -> [String: String] {
        guard let mediaPath, !mediaPath.isEmpty else { return [:] }
        func unavailable(_ reason: String) -> [String: String] {
            ["jellyfinOutputKeyCandidate": "unknown", "jellyfinOutputKeyBasis": reason]
        }
        guard redirectCount == 0 else { return unavailable("redirectedRequest") }
        guard let agent = request.value(forHTTPHeaderField: "User-Agent"), !agent.isEmpty
        else { return unavailable("missingRequestUserAgent") }
        guard let url = request.url,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return unavailable("missingRequestQuery") }
        let packed = items.filter { $0.name.lowercased() == "params" }
        guard packed.count <= 1 else { return unavailable("repeatedParams") }
        let positional = (packed.first?.value ?? "").components(separatedBy: ";")
        func unique(_ name: String, position: Int) -> String? {
            let values = items.filter { $0.name.lowercased() == name }
            guard values.count <= 1 else { return nil }
            // StreamingHelpers.ParseParams overrides explicit query values
            // only for non-whitespace slots. Keep the slot's original bytes.
            if position < positional.count,
               !positional[position].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return positional[position]
            }
            guard let value = values.first?.value, !value.isEmpty else { return nil }
            return value
        }
        guard let device = unique("deviceid", position: 1) else { return unavailable("missingOrRepeatedDeviceId") }
        guard let session = unique("playsessionid", position: 20) else { return unavailable("missingOrRepeatedPlaySessionId") }
        guard let data = "\(mediaPath)-\(agent)-\(device)-\(session)".data(using: .utf16LittleEndian)
        else { return unavailable("unencodableInput") }
        // .NET constructs Guid from the digest, reversing its first 4/2/2
        // byte groups before ToString("N"). This is not a plain MD5 hex string.
        let digest = Array(Insecure.MD5.hash(data: data))
        let order = [3, 2, 1, 0, 5, 4, 7, 6, 8, 9, 10, 11, 12, 13, 14, 15]
        return ["jellyfinOutputKeyCandidate": order.map { String(format: "%02x", digest[$0]) }.joined(),
                "jellyfinOutputKeyBasis": "10.11.11FormulaActualMetricsRequest"]
    }
}

enum PlaybackStageTiming {
    /// Zero denotes a stage that has not been observed, not a zero-cost stage.
    static func milliseconds(start: Double, end: Double) -> String {
        guard start.isFinite, end.isFinite, start > 0, end >= start else { return "unknown" }
        return String((end - start) * 1000)
    }
}

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
        PlaybackBufferedReservePolicy.seconds(
            at: playbackSeconds ?? item.currentTime().seconds,
            ranges: item.loadedTimeRanges.map {
                let range = $0.timeRangeValue
                return (start: range.start.seconds, end: range.end.seconds)
            })
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
