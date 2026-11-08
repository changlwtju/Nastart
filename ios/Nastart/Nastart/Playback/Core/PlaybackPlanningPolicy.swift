import Foundation

/// Repeating the same pending track choice must not invalidate its candidate.
/// Timeline/PiP ownership and non-track requests remain distinct user intents.
struct PlaybackSourceChangeRequestTracker {
    struct Tracks: Equatable {
        let audio: Int?
        let subtitle: Int?
        let seekGeneration: Int
        let pictureInPictureGeneration: Int
    }

    private var latestTracks: Tracks?

    mutating func accept(_ tracks: Tracks?) -> Bool {
        if let tracks, latestTracks == tracks { return false }
        latestTracks = tracks
        return true
    }

    mutating func finish() { latestTracks = nil }
}

/// A missing Jellyfin index asks the server to choose its default subtitle.
/// Off and a client-rendered sidecar must explicitly suppress that stream.
enum PlaybackJellyfinSubtitleDeliveryPolicy {
    static func serverIndex(selected: Int?, usesExternalText: Bool, usesGreenfield: Bool) -> Int? {
        guard usesGreenfield else { return selected }
        return usesExternalText ? -1 : (selected ?? -1)
    }
}

/// Metadata defaults may be absent even when a movie has usable subtitles.
/// Saved user selections (including Off) are applied separately afterwards.
enum PlaybackDefaultSubtitlePolicy {
    struct Track {
        let index: Int
        let language: String?
        var isForced = false
        var isDefault = false
    }

    static func select(tracks: [Track], serverDefault: Int?,
                       preferredLanguages: [String] = Locale.preferredLanguages) -> Int? {
        let available = tracks.filter { $0.index >= 0 }
        if let serverDefault, available.contains(where: { $0.index == serverDefault }) {
            return serverDefault
        }
        if let forced = available.first(where: { $0.isForced }) { return forced.index }
        if let marked = available.first(where: { $0.isDefault }) { return marked.index }
        for language in preferredLanguages {
            let preferred = languageFamily(language)
            if let matching = available.first(where: {
                $0.language.map(languageFamily) == preferred
            }) { return matching.index }
        }
        return available.first?.index
    }

    private static func languageFamily(_ value: String) -> String {
        let base = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
        switch base {
        case "chi", "zho", "cmn", "yue": return "zh"
        case "eng": return "en"
        case "jpn": return "ja"
        case "kor": return "ko"
        case "fra", "fre": return "fr"
        case "deu", "ger": return "de"
        case "spa": return "es"
        case "rus": return "ru"
        case "ita": return "it"
        case "por": return "pt"
        default: return base
        }
    }
}

/// Jellyfin repeats the playlist request's query on every VOD segment URI.
/// Its existing Params contract can express optional hints without repeating
/// their names. Keep codecs, authentication and source/device/play-session
/// identity explicit, and leave unknown or ambiguous requests untouched.
enum PlaybackJellyfinPlaylistQuery {
    static func compact(_ url: URL) -> URL? {
        let path = url.path.split(separator: "/").map(String.init)
        guard path.count >= 3, path[path.count - 3].lowercased() == "videos",
              ["master.m3u8", "main.m3u8"].contains(path.last?.lowercased() ?? ""),
              UUID(uuidString: path[path.count - 2]) != nil
                || path[path.count - 2].count == 32
                    && path[path.count - 2].allSatisfy({ $0.isHexDigit }),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems,
              !items.contains(where: { $0.name.lowercased() == "params" }),
              items.contains(where: { $0.name.lowercased() == "playsessionid" }),
              items.contains(where: { ["api_key", "apikey", "token", "access_token"].contains($0.name.lowercased()) }) else { return nil }
        // Positional fields in Jellyfin StreamingHelpers.ParseParams.
        let integers = ["audiostreamindex": 6, "subtitlestreamindex": 7,
            "videobitrate": 8, "audiobitrate": 9, "maxaudiochannels": 10,
            "maxwidth": 12, "maxheight": 13, "starttimeticks": 14,
            "maxrefframes": 16, "maxvideobitdepth": 17, "transcodingmaxaudiochannels": 26]
        let booleans = ["static": 3, "copytimestamps": 24, "requireavc": 29,
            "enablesubtitlesinmanifest": 27, "requirenonanamorphic": 31, "deinterlace": 32]
        // The master endpoint validates its required mediaSourceId query
        // before ParseParams runs; moving it to slot 2 causes HTTP 400.
        let identifiers = ["profile": 18]
        let decimals = ["maxframerate": 11, "level": 15]
        var fields = Array(repeating: "", count: 33)
        var remaining: [URLQueryItem] = []
        var moved = Set<String>()
        for item in items {
            let name = item.name.lowercased()
            guard let position = integers[name] ?? booleans[name] ?? identifiers[name] ?? decimals[name] else {
                remaining.append(item); continue
            }
            guard moved.insert(name).inserted, let value = item.value,
                  !value.isEmpty else { return nil }
            if integers[name] != nil {
                guard Int64(value) != nil, value.utf8.allSatisfy({ (48...57).contains($0) || $0 == 45 }) else { return nil }
                guard position == 14 || Int32(value) != nil else { return nil }
            } else if booleans[name] != nil {
                guard ["true", "false"].contains(value.lowercased()) else { return nil }
            } else if identifiers[name] != nil {
                // Params uses semicolons as delimiters. Preserve identifiers
                // byte-for-byte and leave unusual values on the original URL.
                guard value.utf8.allSatisfy({
                    (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                        || [45, 95, 44].contains($0)
                }) else { return nil }
            } else {
                guard value.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
                      let number = Float(value), number.isFinite else { return nil }
            }
            fields[position] = value
        }
        guard moved.count >= 3 else { return nil }
        while fields.last == "" { fields.removeLast() }
        remaining.append(URLQueryItem(name: "Params", value: fields.joined(separator: ";")))
        let originalBytes = components.percentEncodedQuery?.utf8.count ?? 0
        components.queryItems = remaining
        guard (components.percentEncodedQuery?.utf8.count ?? 0) + 16 < originalBytes else { return nil }
        return components.url
    }
}

/// Complete VOD media and single-variant masters backed by that media are
/// reusable within one route. Keep raw text for current URI/seek rewriting.
final class PlaybackVODPlaylistCache: @unchecked Sendable {
    private struct Entry { let route: String; let data: Data; let vodChildKey: String? }
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var order: [String] = []
    private let maximumBytes: Int
    private let maximumEntryBytes: Int
    init(maximumBytes: Int = 8 * 1024 * 1024, maximumEntryBytes: Int = 4 * 1024 * 1024) {
        self.maximumBytes = maximumBytes
        self.maximumEntryBytes = maximumEntryBytes
    }
    private func key(route: String, url: URL) -> String { route + "|" + url.absoluteString }
    func data(route: String, url: URL) -> Data? {
        lock.lock(); defer { lock.unlock() }
        guard let entry = entries[key(route: route, url: url)] else { return nil }
        if let child = entry.vodChildKey {
            guard let media = entries[child], media.vodChildKey == nil else { return nil }
        }
        return entry.data
    }
    func store(_ data: Data, route: String, url: URL) {
        guard data.count <= maximumEntryBytes, data.count <= maximumBytes,
              let text = String(data: data, encoding: .utf8),
              text.hasPrefix("#EXTM3U"),
              text.components(separatedBy: .newlines).contains("#EXT-X-ENDLIST") else { return }
        insert(data, route: route, url: url, vodChildKey: nil)
    }
    /// A master alone cannot establish VOD. Its sole media dependency must
    /// still be cached in this exact route at every read, including eviction.
    func storeMaster(_ data: Data, route: String, url: URL, childURL: URL) {
        guard data.count <= maximumEntryBytes, data.count <= maximumBytes,
              let text = String(data: data, encoding: .utf8),
              Self.singleVariantURI(in: text) != nil,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              childURL.scheme == url.scheme, childURL.host == url.host, childURL.port == url.port,
              childURL.user == nil, childURL.password == nil, childURL.fragment == nil,
              childURL.pathExtension.lowercased() == "m3u8", childURL != url else { return }
        insert(data, route: route, url: url, vodChildKey: key(route: route, url: childURL))
    }
    static func singleVariantURI(in text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard lines.first == "#EXTM3U",
              lines.filter({ $0.hasPrefix("#EXT-X-STREAM-INF:") }).count == 1,
              lines.filter({ !$0.hasPrefix("#") }).count == 1,
              !lines.contains(where: { line in
                  line.hasPrefix("#EXT") && line != "#EXTM3U"
                      && line != "#EXT-X-INDEPENDENT-SEGMENTS"
                      && !line.hasPrefix("#EXT-X-VERSION:")
                      && !line.hasPrefix("#EXT-X-STREAM-INF:")
              }),
              let index = lines.firstIndex(where: { $0.hasPrefix("#EXT-X-STREAM-INF:") }),
              lines.indices.contains(index + 1), !lines[index + 1].hasPrefix("#"),
              !lines[index].contains("URI=") else { return nil }
        return lines[index + 1]
    }
    private func insert(_ data: Data, route: String, url: URL, vodChildKey: String?) {
        lock.lock(); defer { lock.unlock() }
        let k = key(route: route, url: url)
        entries[k] = Entry(route: route, data: data, vodChildKey: vodChildKey)
        order.removeAll { $0 == k }; order.append(k)
        while entries.values.reduce(0, { $0 + $1.data.count }) > maximumBytes,
              let oldest = order.first {
            entries[oldest] = nil; order.removeFirst()
        }
    }
    func remove(route: String) {
        lock.lock(); defer { lock.unlock() }
        entries = entries.filter { $0.value.route != route }
        order.removeAll { entries[$0] == nil }
    }
}

/// Restrict optional startup work to an already complete, unencrypted TS VOD.
/// No URI is guessed from a duration, and resumed/nonzero timelines opt out.
enum PlaybackHLSStartupPrimerPolicy {
    static func candidate(in text: String, playlistURL: URL) -> URL? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard lines.first == "#EXTM3U", lines.contains("#EXT-X-ENDLIST"),
              lines.contains(where: { $0.hasPrefix("#EXTINF:") }),
              !lines.contains(where: { line in
                  ["#EXT-X-STREAM-INF", "#EXT-X-MEDIA:", "#EXT-X-KEY:", "#EXT-X-MAP:",
                   "#EXT-X-BYTERANGE:", "#EXT-X-START:", "#EXT-X-PART:", "#EXT-X-SKIP:"].contains {
                      line.hasPrefix($0)
                  }
              }),
              !lines.contains(where: { $0.hasPrefix("#EXT-X-MEDIA-SEQUENCE:") && $0 != "#EXT-X-MEDIA-SEQUENCE:0" }),
              let first = lines.first(where: { !$0.isEmpty && !$0.hasPrefix("#") }),
              let url = URL(string: first, relativeTo: playlistURL)?.absoluteURL,
              url.scheme == playlistURL.scheme, url.host == playlistURL.host,
              url.port == playlistURL.port, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil,
              url.path.split(separator: "/").count == 4,
              url.path.split(separator: "/").prefix(2) == playlistURL.path.split(separator: "/").prefix(2),
              url.path.split(separator: "/")[2] == "child",
              url.pathExtension == "ts" else { return nil }
        return url
    }

    static func accepts(status: Int, contentRange: String?, contentLength: String?) -> Bool {
        guard status == 206, contentLength == "1", let range = contentRange?.lowercased(),
              range.hasPrefix("bytes 0-0/"),
              let total = Int64(range.dropFirst("bytes 0-0/".count)), total > 0 else { return false }
        return true
    }
}

/// Read-only numeric evidence. Advertised seekability and already downloaded
/// media are different facts, especially for a server-generated VOD playlist.
enum PlaybackSeekRangeDiagnostics {
    static func fields(target: Double, current: Double,
                       loaded: [(start: Double, duration: Double)],
                       seekable: [(start: Double, duration: Double)]) -> [String: String] {
        func valid(_ ranges: [(start: Double, duration: Double)]) -> [(start: Double, end: Double)] {
            ranges.compactMap { range in
                let end = range.start + range.duration
                guard range.start.isFinite, range.duration.isFinite,
                      range.duration > 0, end.isFinite, end > range.start else { return nil }
                return (range.start, end)
            }
        }
        let loaded = valid(loaded), seekable = valid(seekable)
        func contains(_ ranges: [(start: Double, end: Double)]) -> Bool {
            target.isFinite && target >= 0 && ranges.contains { $0.start <= target && target < $0.end }
        }
        var fields = ["seekTargetSeconds": target.isFinite && target >= 0 ? String(target) : "unknown",
                      "engineCurrentSeconds": current.isFinite && current >= 0 ? String(current) : "unknown",
                      "validLoadedRangeCount": String(loaded.count),
                      "validSeekableRangeCount": String(seekable.count),
                      "targetAlreadyLoaded": String(contains(loaded)),
                      "targetAdvertisedSeekable": String(contains(seekable))]
        for (prefix, ranges) in [("loaded", loaded), ("seekable", seekable)] {
            fields[prefix + "FirstStart"] = ranges.map(\.start).min().map { String($0) } ?? "unknown"
            fields[prefix + "LastEnd"] = ranges.map(\.end).max().map { String($0) } ?? "unknown"
        }
        return fields
    }
}

/// Reactive downshift only: bandwidth estimates alone must not interrupt a
/// healthy original stream. Times use monotonic uptime, never playback time.
struct PlaybackStallDownshiftPolicy {
    // A server-backed Jellyfin or verified DSM file rendition may request a
    // lower bitrate. A DSM file with only its original Range route has no
    // quality-switch loader.
    static let isEnabled = true
    private var previousTime: TimeInterval?
    private var generation: Int?
    private var graceUntil: TimeInterval = 0
    private var cooldownUntil: TimeInterval = 0
    private var stalledSamples: [(time: TimeInterval, duration: TimeInterval)] = []
    private var stallStarts: [TimeInterval] = []
    private var consecutive: TimeInterval = 0
    private var wasBuffering = false

    mutating func sample(now: TimeInterval, eligible: Bool, buffering: Bool,
                         seekGeneration: Int) -> Bool {
        guard now.isFinite else { return false }
        defer { previousTime = now }
        if generation != seekGeneration || !eligible {
            generation = seekGeneration
            graceUntil = now + 10
            stalledSamples.removeAll()
            stallStarts.removeAll()
            consecutive = 0
            wasBuffering = false
            return false
        }
        let delta = previousTime.map { now - $0 } ?? 0
        guard delta > 0, delta <= 2.5, now >= graceUntil, now >= cooldownUntil else {
            consecutive = 0
            wasBuffering = false
            return false
        }
        stalledSamples.removeAll { now - $0.time > 60 }
        stallStarts.removeAll { now - $0 > 30 }
        if buffering && !wasBuffering { stallStarts.append(now) }
        let stalled = buffering && wasBuffering ? delta : 0
        wasBuffering = buffering
        consecutive = buffering ? consecutive + stalled : 0
        if stalled > 0 { stalledSamples.append((now, stalled)) }
        // Several brief stalls are conspicuous even when their aggregate
        // duration is below the old 12-second threshold. This is the common
        // pattern when a high-bitrate original outruns an uneven Wi-Fi link.
        guard consecutive >= 8 || stallStarts.count >= 3
            || stalledSamples.reduce(0, { $0 + $1.duration }) >= 12 else { return false }
        cooldownUntil = now + 60
        consecutive = 0
        stalledSamples.removeAll()
        stallStarts.removeAll()
        return true
    }
}

/// Recent completed Range and HLS segment transfers are a better guide to
/// sustained delivery than the small Jellyfin startup probe. Discard samples where the local
/// proxy paused the upstream task because those measure player consumption.
struct PlaybackBodyWindowCapacityPolicy {
    private var previous: (rate: Double, end: TimeInterval)?

    mutating func sample(bytes: Int64, seconds: TimeInterval,
                         totalBackpressure: TimeInterval, queuedBytes: Int,
                         now: TimeInterval) -> Int? {
        guard bytes >= 131_072, seconds.isFinite, (2...4).contains(seconds),
              totalBackpressure == 0, (0...131_072).contains(queuedBytes),
              now.isFinite else { previous = nil; return nil }
        let rate = Double(bytes) * 8 / seconds
        guard rate.isFinite, rate > 0, rate < Double(Int.max) else {
            previous = nil; return nil
        }
        let prior = previous
        previous = (rate, now)
        guard let prior, abs(now - prior.end - seconds) <= 0.25,
              max(rate, prior.rate) <= min(rate, prior.rate) * 2 else { return nil }
        // A slow first response alone must not lower a healthy original.
        return Int(max(rate, prior.rate))
    }
}

/// Measures a single client media stream, including its consecutive finite
/// upstream ranges. Response boundaries must not discard a partly read window
/// or the preceding stable sample. Request latency is included in wall time.
struct PlaybackBodyWindowSampler {
    struct Window {
        let bytes: Int64
        let seconds: TimeInterval
        let pressured: Bool
        let capacity: Int?
    }
    private var startedAt: TimeInterval?
    private var bytes: Int64 = 0
    private var pressured = false
    private var policy = PlaybackBodyWindowCapacityPolicy()

    mutating func beginResponse(now: TimeInterval) {
        guard now.isFinite else { return }
        if startedAt == nil { startedAt = now }
    }

    mutating func receive(bytes count: Int, now: TimeInterval,
                         totalBackpressure: TimeInterval, queuedBytes: Int,
                         eligible: Bool) -> Window? {
        guard count > 0, let start = startedAt, now.isFinite, now >= start else { return nil }
        bytes += Int64(count)
        pressured = pressured || !totalBackpressure.isFinite || totalBackpressure != 0
        let seconds = now - start
        guard seconds >= 2 else { return nil }
        let capacity = eligible ? policy.sample(bytes: bytes, seconds: seconds,
            totalBackpressure: pressured ? 1 : 0, queuedBytes: queuedBytes, now: now) : nil
        if !eligible { policy = PlaybackBodyWindowCapacityPolicy() }
        let window = Window(bytes: bytes, seconds: seconds, pressured: pressured, capacity: capacity)
        startedAt = now
        bytes = 0
        pressured = false
        return window
    }
}

/// A prepared/seeked AV item may already hold a large absolute position while
/// paused. Startup clock evidence requires two advancing playback samples.
/// This establishes clock progress, not decoder/compositor/audio presentation.
struct PlaybackClockStartupPolicy {
    private var previous: (seconds: Double, uptime: TimeInterval, generation: Int, playing: Bool)?

    mutating func sample(seconds: Double, uptime: TimeInterval, isPlaying: Bool,
                         seekGeneration: Int, rate: Double) -> Bool {
        guard seconds.isFinite, seconds >= 0, uptime.isFinite, rate.isFinite, rate > 0 else {
            previous = nil
            return false
        }
        let last = previous
        previous = (seconds, uptime, seekGeneration, isPlaying)
        guard isPlaying, let last, last.playing, last.generation == seekGeneration else { return false }
        let wall = uptime - last.uptime
        let media = seconds - last.seconds
        return wall > 0 && wall <= 2.5 && media > 0.05
            && media <= wall * max(rate, 1) * 1.25 + 0.5
    }
}

struct PlaybackPredictiveGracePolicy {
    private var generation: Int?
    private var normalUntil: TimeInterval = .infinity
    private var initialBodyUntil: TimeInterval = .infinity

    mutating func allows(now: TimeInterval, seekGeneration: Int,
                         qualifiedBodyWindow: Bool) -> Bool {
        guard now.isFinite else { return false }
        if generation != seekGeneration {
            initialBodyUntil = generation == nil ? now + 3 : .infinity
            normalUntil = now + 10
            generation = seekGeneration
        }
        return now >= normalUntil || qualifiedBodyWindow && now >= initialBodyUntil
    }
}

/// Owned by the playback presentation, rather than a rendition's sampling task.
/// Preparing, abandoning or committing an automatic replacement must not erase
/// the interval between predictive requests. Reactive stall recovery is separate.
struct PlaybackPredictiveCooldownPolicy {
    private var nextAllowedUptime: TimeInterval = -.infinity

    func allows(now: TimeInterval) -> Bool {
        now.isFinite && now >= nextAllowedUptime
    }

    mutating func requested(now: TimeInterval) {
        guard now.isFinite else { return }
        nextAllowedUptime = max(nextAllowedUptime, now + 60)
    }

    mutating func manualSourceCommitted() {
        nextAllowedUptime = -.infinity
    }
}

/// HLS spends reserve while requesting every segment, before its body arrives.
/// A continuous Range body retains its existing response-body measurement.
enum PlaybackTransferCapacityPolicy {
    static func seconds(isHLSSegment: Bool, fetchStart: Date?,
                        responseStart: Date?, responseEnd: Date?) -> TimeInterval? {
        guard let responseStart, let responseEnd else { return nil }
        let bodyDuration = responseEnd.timeIntervalSince(responseStart)
        guard bodyDuration.isFinite, bodyDuration > 0 else { return nil }
        guard isHLSSegment else { return bodyDuration }
        guard let fetchStart else { return nil }
        let requestDuration = responseStart.timeIntervalSince(fetchStart)
        guard requestDuration.isFinite, requestDuration >= 0 else { return nil }
        let duration = responseEnd.timeIntervalSince(fetchStart)
        guard duration.isFinite, duration > 0 else { return nil }
        return duration
    }
}

/// Observation only: URLSession retains its delegate through cancellation,
/// while the proxy releases its active task when the client finishes.
/// Keep numeric identity, never the task/session, to recognize late callbacks.
enum PlaybackResponseBodyDiagnostics {
    /// Transaction counters are observations, not a cellular billing total.
    /// Received bytes include framing/encoding; decoded bytes describe what
    /// URLSession delivers. Compression can legitimately reverse their order.
    static func fields(received: Int64, decoded: Int64, contentLength: String?,
                       contentEncoding: String?, status: Int?) -> [String: String] {
        let length = contentLength.flatMap {
            Int64($0.trimmingCharacters(in: .whitespacesAndNewlines))
        }.flatMap { $0 >= 0 ? $0 : nil }
        let encoding = contentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let codings = encoding.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let safeEncoding = encoding.isEmpty ? "unspecified"
            : codings.allSatisfy({ ["identity", "gzip", "deflate", "br", "zstd"].contains($0) })
                ? codings.joined(separator: ",") : "other"
        return [
            "responseBodyBytesReceivedIncludingProtocol": received >= 0 ? String(received) : "unknown",
            "responseBodyBytesAfterDecoding": decoded >= 0 ? String(decoded) : "unknown",
            "responseContentLength": length.map(String.init) ?? "unknown",
            "responseContentEncoding": safeEncoding,
            "responseStatusCode": status.flatMap { (100...599).contains($0) ? String($0) : nil } ?? "unknown"
        ]
    }
}

enum PlaybackRequestPhaseDiagnostics {
    /// URLSession dates describe transport phases, not isolated server work.
    /// Report missing/reversed boundaries as unknown rather than zero latency.
    static func fields(created: Date, firstFetch: Date?, lastFetch: Date?,
                       requestStart: Date?, requestEnd: Date?, responseStart: Date?,
                       responseEnd: Date?, callback: Date) -> [String: String] {
        func milliseconds(_ start: Date?, _ end: Date?) -> String {
            guard let start, let end else { return "unknown" }
            let elapsed = end.timeIntervalSince(start)
            guard elapsed.isFinite, elapsed >= 0,
                  elapsed * 1_000 < Double(Int.max) else { return "unknown" }
            return String(Int(elapsed * 1_000))
        }
        return [
            "taskCreatedToFirstFetchMs": milliseconds(created, firstFetch),
            "lastFetchToRequestMs": milliseconds(lastFetch, requestStart),
            "lastRequestSendMs": milliseconds(requestStart, requestEnd),
            "lastRequestEndToFirstByteMs": milliseconds(requestEnd, responseStart),
            "lastResponseBodyMs": milliseconds(responseStart, responseEnd),
            "lastResponseEndToMetricsCallbackMs": milliseconds(responseEnd, callback)
        ]
    }
}

final class PlaybackProxyTaskDiagnostics: @unchecked Sendable {
    struct Snapshot {
        let taskID: Int
        let issuedAt: TimeInterval
        var clientFinished = false
        var cancelledAt: TimeInterval?
        var completionObserved = false
        var headersReceivedAt: TimeInterval?
        var receivedBodyBytes: Int64 = 0
        var firstBodyReceivedAt: TimeInterval?
        var lastBodyReceivedAt: TimeInterval?
        var finalBackpressure: TimeInterval = 0
        var finalSuspendCount = 0
        var finalQueuedBytes = 0

        func fields(at now: TimeInterval) -> [String: String] {
            var result: [String: String] = [
                "callbackAfterClientFinish": String(clientFinished),
                "upstreamCancellationRequested": String(cancelledAt != nil),
                "upstreamCompletionObserved": String(completionObserved),
                "upstreamHeadersObserved": String(headersReceivedAt != nil),
                "upstreamTaskBodyBytes": String(receivedBodyBytes),
                "upstreamIssuedToCallbackMs": String(Int(max(now - issuedAt, 0) * 1_000))
            ]
            func bodyMilliseconds(_ time: TimeInterval?) -> String {
                guard let time else { return "unknown" }
                return String(Int((time - issuedAt) * 1_000))
            }
            result["upstreamIssueToFirstBodyCallbackMs"] = bodyMilliseconds(firstBodyReceivedAt)
            result["upstreamIssueToLastBodyCallbackMs"] = bodyMilliseconds(lastBodyReceivedAt)
            if let cancelledAt {
                result["upstreamCancelToCallbackMs"] = String(Int(max(now - cancelledAt, 0) * 1_000))
            }
            if let headersReceivedAt {
                result["upstreamIssueToHeadersCallbackMs"] = String(Int(max(headersReceivedAt - issuedAt, 0) * 1_000))
            }
            return result
        }
    }

    private let lock = NSLock()
    private var latest: Snapshot?

    func issued(taskID: Int, now: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        latest = Snapshot(taskID: taskID, issuedAt: now)
    }

    func clientFinished(backpressure: TimeInterval, suspendCount: Int, queuedBytes: Int) {
        lock.lock(); defer { lock.unlock() }
        guard latest?.clientFinished == false else { return }
        latest?.clientFinished = true
        latest?.finalBackpressure = backpressure
        latest?.finalSuspendCount = suspendCount
        latest?.finalQueuedBytes = queuedBytes
    }

    func responseHeadersReceived(taskID: Int, now: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        guard let current = latest, current.taskID == taskID,
              current.headersReceivedAt == nil, now.isFinite, now >= current.issuedAt else { return }
        latest?.headersReceivedAt = now
    }

    func cancellationRequested(now: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        guard latest?.completionObserved == false, latest?.cancelledAt == nil else { return }
        latest?.cancelledAt = now
    }

    /// Count delegate-delivered bytes for both buffered playlists and media.
    /// This is an upstream callback boundary, not delivery to the local client.
    func receivedBody(taskID: Int, bytes: Int64, now: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        guard let current = latest, current.taskID == taskID, !current.completionObserved,
              bytes > 0, now.isFinite, now >= current.issuedAt,
              (now - current.issuedAt).isFinite,
              now - current.issuedAt < Double(Int.max) / 1_000,
              now >= (current.lastBodyReceivedAt ?? current.issuedAt) else { return }
        let (total, overflow) = current.receivedBodyBytes.addingReportingOverflow(bytes)
        guard !overflow else { return }
        latest?.receivedBodyBytes = total
        if current.firstBodyReceivedAt == nil { latest?.firstBodyReceivedAt = now }
        latest?.lastBodyReceivedAt = now
    }

    func callback(taskID: Int, completed: Bool = false) -> Snapshot? {
        lock.lock(); defer { lock.unlock() }
        guard latest?.taskID == taskID else { return nil }
        if completed { latest?.completionObserved = true }
        return latest
    }
}

final class PlaybackRecentThroughputStore: @unchecked Sendable {
    static let shared = PlaybackRecentThroughputStore()

    struct Estimate {
        enum Source: String { case completedTransfer, bodyWindow }
        let bitrate: Int
        let source: Source
        // A single startup/tail completion is a conservative budget hint,
        // not enough evidence to replace a stream that is already advancing.
        let predictiveBitrate: Int?
        // Oldest observation supporting this prediction, rather than the
        // time a caller reread it. Recovery must not reuse pre-request supply.
        let predictionEvidenceUptime: TimeInterval?
    }

    private struct Sample {
        let traceID: String
        let bitrate: Int
        let uptime: TimeInterval
    }

    private let lock = NSLock()
    private var samples: [Sample] = []
    private var bodySamples: [Sample] = []

    func recordQualifiedBodyWindow(traceID: String?, bitrate: Int, now: TimeInterval) {
        guard let traceID, !traceID.isEmpty, bitrate > 0, now.isFinite else { return }
        lock.lock(); defer { lock.unlock() }
        guard !bodySamples.contains(where: { $0.traceID == traceID && $0.uptime > now }) else { return }
        // Two adjacent, unpressured body windows are newer delivery evidence
        // than startup/tail requests. Retire those older completions so their
        // lower quartile cannot pin the estimate after supply has recovered.
        // Completions recorded after this window still take precedence, and
        // expired body evidence must not resurrect the superseded samples.
        samples.removeAll { $0.traceID == traceID && $0.uptime <= now }
        bodySamples.removeAll { now - $0.uptime > 6 || now < $0.uptime || $0.traceID == traceID }
        bodySamples.append(Sample(traceID: traceID, bitrate: bitrate, uptime: now))
        if bodySamples.count > 32 { bodySamples.removeFirst(bodySamples.count - 32) }
    }

    func record(traceID: String?, bytes: Int64, seconds: TimeInterval,
                backpressureSeconds: TimeInterval, now: TimeInterval) {
        guard let traceID, !traceID.isEmpty, bytes >= 1_048_576,
              seconds.isFinite, seconds >= 0.25,
              backpressureSeconds < 0.1, now.isFinite else { return }
        let rate = Double(bytes) * 8 / seconds
        guard rate.isFinite, rate > 0, rate < Double(Int.max) else { return }
        lock.lock()
        samples.removeAll { now - $0.uptime > 90 || now < $0.uptime }
        samples.append(Sample(traceID: traceID, bitrate: Int(rate), uptime: now))
        if samples.count > 32 { samples.removeFirst(samples.count - 32) }
        lock.unlock()
    }

    func estimate(traceID: String, now: TimeInterval) -> Int? {
        estimateSample(traceID: traceID, now: now)?.bitrate
    }

    func estimateSample(traceID: String, now: TimeInterval) -> Estimate? {
        lock.lock(); defer { lock.unlock() }
        let current = samples.filter { $0.traceID == traceID
            && now >= $0.uptime && now - $0.uptime <= 60 }
        let rates = current.map(\.bitrate).sorted()
        if !rates.isEmpty {
            // Confirm the prediction with a majority of the latest three
            // completions. The lower quartile can otherwise remain pinned by
            // one first-segment generation wait after later supply recovers.
            let observations = current.sorted { $0.uptime < $1.uptime }.suffix(3)
            let recent = observations.map(\.bitrate).sorted()
            return Estimate(bitrate: rates[(rates.count - 1) / 4], source: .completedTransfer,
                predictiveBitrate: recent.count == 3 ? recent[1] : nil,
                predictionEvidenceUptime: recent.count == 3 ? observations.first?.uptime : nil)
        }
        guard let body = bodySamples.last(where: { $0.traceID == traceID
            && now >= $0.uptime && now - $0.uptime <= 6 }) else { return nil }
        return Estimate(bitrate: body.bitrate, source: .bodyWindow, predictiveBitrate: body.bitrate,
            predictionEvidenceUptime: body.uptime)
    }
}

enum PlaybackAdaptiveBitratePolicy {
    static let ladder = [30_000_000, 20_000_000, 12_000_000,
                         10_000_000, 8_000_000, 4_000_000,
                         2_000_000, 1_500_000, 1_000_000,
                         750_000, 500_000, 375_000, 250_000]

    static func allowsAutomaticAdjustment(selectedQualityID: String?) -> Bool {
        selectedQualityID == nil || selectedQualityID == "auto"
    }

    /// A file's size and the decoder's complete duration provide its average
    /// demand even while the opening credits have a very low runtime bitrate.
    /// Explicit rendition/source metadata retains precedence. Unknown length
    /// or duration must not invent a demand estimate.
    static func sourceBitrate(streamBitrateCeiling: Int?, estimatedBitrate: Int?,
                              byteLength: Int64?, durationSeconds: Double) -> Int? {
        if let explicit = streamBitrateCeiling ?? estimatedBitrate {
            return explicit > 0 ? explicit : nil
        }
        guard let byteLength, byteLength > 0,
              durationSeconds.isFinite, durationSeconds > 0 else { return nil }
        let bitrate = Double(byteLength) * 8 / durationSeconds
        guard bitrate.isFinite, bitrate >= 1, bitrate < Double(Int.max) else { return nil }
        return Int(bitrate)
    }

    static func isOriginalClearlyUnsustainable(sourceBitrate: Int?,
                                               measuredCapacity: Int?,
                                               isPrivateRoute: Bool,
                                               forcesOriginal: Bool) -> Bool {
        guard !isPrivateRoute, !forcesOriginal,
              let sourceBitrate, sourceBitrate > 0,
              let measuredCapacity, measuredCapacity > 0 else { return false }
        return Double(sourceBitrate) > Double(measuredCapacity) * 1.5
    }

    /// Keep delivery well above the rendition's target bitrate. Each retry
    /// must select a lower rendition, even if the old capacity sample is high.
    static func target(currentCeiling: Int, capacity: Int?, networkKey: String) -> Int? {
        guard currentCeiling > 250_000 else { return nil }
        let safeCapacity = capacity.map { Int(Double($0) * 0.5) }
        let unknownCapacityLimit = networkKey == "cellular" ? 4_000_000 : 8_000_000
        let limit = min(currentCeiling - 1, safeCapacity ?? unknownCapacityLimit)
        return ladder.first { $0 <= limit } ?? 250_000
    }
}

/// Keep only the failed candidate's negotiation continuation, never its player
/// or tracker. An uncommitted candidate still provides a newer ceiling and
/// throughput trace than the original request's fallback closure.
struct PlaybackFailedCandidateRetry<Loader> {
    let sourceID: UUID
    private var pendingTicket: UUID?
    private var continuation: Loader?

    init(sourceID: UUID) { self.sourceID = sourceID }

    func loader(or original: Loader) -> Loader { continuation ?? original }

    mutating func begin() -> UUID {
        let ticket = UUID()
        pendingTicket = ticket
        return ticket
    }

    mutating func withdraw(ticket: UUID) {
        if pendingTicket == ticket { pendingTicket = nil }
    }

    @discardableResult
    mutating func failed(ticket: UUID, currentSourceID: UUID,
                         cancelled: Bool, candidateStillCurrent: Bool,
                         continuation: Loader?) -> Bool {
        guard pendingTicket == ticket, currentSourceID == sourceID,
              !cancelled, candidateStillCurrent else { return false }
        pendingTicket = nil
        guard let continuation else { return false }
        self.continuation = continuation
        return true
    }
}

/// A recovered prediction must not consume both later stall-recovery attempts.
/// Refund at most two such preparations, keeping the overall work bounded.
struct PlaybackDownshiftAttemptBudget {
    private(set) var attempts = 0
    private(set) var recoveredWithdrawals = 0
    private var sequence = 0
    private var refundableTicket: Int?

    var canWithdrawStaticPrediction: Bool { recoveredWithdrawals < 2 }

    mutating func begin(staticPrediction: Bool) -> Int? {
        guard attempts < 2 else { return nil }
        attempts += 1
        sequence += 1
        refundableTicket = staticPrediction && canWithdrawStaticPrediction ? sequence : nil
        return sequence
    }

    @discardableResult
    mutating func withdrawRecoveredPrediction(ticket: Int) -> Bool {
        guard refundableTicket == ticket, canWithdrawStaticPrediction, attempts > 0 else { return false }
        refundableTicket = nil
        recoveredWithdrawals += 1
        attempts -= 1
        return true
    }
}

/// Withdraw only a static prediction that has lost its basis while the original
/// is advancing with a healthy reserve. Reactive recovery uses a separate path.
struct PlaybackPredictiveRecoveryPolicy {
    private struct Sample {
        let time: TimeInterval
        let clock: TimeInterval
        let ahead: TimeInterval
        let target: TimeInterval
        let rate: Double
    }
    let startedAt: TimeInterval
    private var samples: [Sample] = []
    private(set) var recovered = false

    init(startedAt: TimeInterval) { self.startedAt = startedAt }

    mutating func sample(now: TimeInterval, eligible: Bool,
                         currentSeconds: TimeInterval, aheadSeconds: TimeInterval?,
                         targetSeconds: TimeInterval?, sourceBitrate: Int?,
                         runtimeDemand: Int?, rate: Double, capacity: Int?,
                         evidenceUptime: TimeInterval?) -> Bool {
        if recovered { return true }
        guard eligible, startedAt.isFinite, now.isFinite, now >= startedAt,
              currentSeconds.isFinite, currentSeconds >= 0,
              let aheadSeconds, aheadSeconds.isFinite, aheadSeconds >= 0,
              let targetSeconds, targetSeconds.isFinite, targetSeconds > 0,
              aheadSeconds >= targetSeconds * 1.5,
              let sourceBitrate, sourceBitrate > 0,
              let runtimeDemand, runtimeDemand > 0,
              rate.isFinite, rate > 0,
              let capacity, capacity > 0,
              let evidenceUptime, evidenceUptime.isFinite,
              evidenceUptime >= startedAt, evidenceUptime <= now,
              now - evidenceUptime <= 6,
              Double(sourceBitrate) * rate <= Double(capacity) * 1.5,
              Double(runtimeDemand) * 1.5 <= Double(capacity) else {
            samples.removeAll()
            return false
        }
        if let previous = samples.last {
            let delta = now - previous.time
            // Warmup checks can run every 20ms; those are not independent
            // advancing observations and must not manufacture confirmation.
            if delta > 0, delta < 0.75 { return false }
            if delta <= 0 || delta > 2.5 || currentSeconds <= previous.clock + 0.25
                || abs(targetSeconds - previous.target) > 0.001
                || abs(rate - previous.rate) > 0.001 {
                samples.removeAll()
            }
        }
        samples.append(Sample(time: now, clock: currentSeconds, ahead: aheadSeconds,
                              target: targetSeconds, rate: rate))
        if samples.count > 3 { samples.removeFirst(samples.count - 3) }
        guard samples.count == 3, let first = samples.first,
              now - first.time >= 2, aheadSeconds >= first.ahead - 0.25 else { return false }
        recovered = true
        return true
    }
}

/// Reserve must be reachable from the current item clock without a buffer hole.
enum PlaybackBufferedReservePolicy {
    static func seconds(at current: TimeInterval,
                        ranges: [(start: Double, end: Double)]) -> TimeInterval? {
        guard current.isFinite, current >= 0 else { return nil }
        let valid = ranges.filter {
            $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end >= $0.start
        }.sorted { $0.start < $1.start }
        guard !valid.isEmpty else { return nil }
        guard let index = valid.firstIndex(where: { $0.start <= current && current <= $0.end }) else {
            return 0
        }
        var end = valid[index].end
        for range in valid.dropFirst(index + 1) {
            guard range.start <= end else { break }
            end = max(end, range.end)
        }
        return end - current
    }
}

/// Limit the muted candidate's future target to media the live stream can play.
enum PlaybackReplacementLeadPolicy {
    static func mediaSeconds(expectedPreparation: TimeInterval, rate: Double,
                             isAdvancing: Bool, availableReserve: TimeInterval?) -> TimeInterval {
        guard isAdvancing, expectedPreparation.isFinite, expectedPreparation >= 0,
              rate.isFinite, rate > 0 else { return 0 }
        let expected = expectedPreparation * rate
        guard expected.isFinite else { return 0 }
        guard let availableReserve, availableReserve.isFinite, availableReserve >= 0 else {
            return expected
        }
        // A future candidate must not depend on the original surviving beyond
        // its known reserve when delivery is already falling behind demand.
        return min(expected, max(availableReserve - 0.25, 0))
    }
}

/// Correct a muted candidate only when the live position is already buffered.
/// Never turn a slow candidate into a new server seek or an unbounded retry.
enum PlaybackBufferedHandoffSeekPolicy {
    static func target(candidate: Double, live: Double, rate: Double,
                       isAdvancing: Bool, duration: Double?,
                       ranges: [(start: Double, end: Double)]) -> Double? {
        guard candidate.isFinite, live.isFinite, candidate >= 0, live >= 0,
              rate.isFinite, rate > 0 else { return nil }
        // A slightly ahead candidate otherwise waits for a stalled original
        // indefinitely, even though its buffer contains the original's frame.
        // Do not disturb a progressing source or relax the alignment tolerance.
        let stalledOvershoot = !isAdvancing && candidate - live > 0.1
        guard live - candidate >= 2 || stalledOvershoot else { return nil }
        let target = live + (isAdvancing ? 0.25 * rate : 0)
        guard target.isFinite,
              duration.map({ $0.isFinite && target + 0.5 < $0 }) ?? true,
              ranges.contains(where: {
                  $0.start.isFinite && $0.end.isFinite && $0.start >= 0
                      && $0.start <= target && $0.end >= target + 0.5
              }) else { return nil }
        return target
    }
}

/// A decoded still frame alone cannot carry a playing replacement.
enum PlaybackHandoffReadinessPolicy {
    static func canCommit(candidate: Double, live: Double,
                          ranges: [(start: Double, end: Double)]) -> Bool {
        guard candidate.isFinite, live.isFinite, candidate >= 0, live >= 0,
              abs(candidate - live) <= 0.1 else { return false }
        return ranges.contains {
            $0.start.isFinite && $0.end.isFinite && $0.start >= 0
                && $0.start <= candidate && $0.end >= candidate + 0.5
        }
    }

    static func isReady(candidate: Double, live: Double, frame: Double,
                        ranges: [(start: Double, end: Double)]) -> Bool {
        guard frame.isFinite, frame >= 0, abs(frame - candidate) <= 0.15 else { return false }
        // Match the candidate's existing half-second forward-buffer request.
        // A disjoint future range is not reserve at the frame being committed.
        return canCommit(candidate: candidate, live: live, ranges: ranges)
    }
}

/// A detail probe cannot choose a route after that route or bearer has changed.
enum PlaybackOriginalWarmupPolicy {
    static func matches(warmedEndpoint: URL, currentEndpoint: URL,
                        warmedNetwork: String, currentNetwork: String) -> Bool {
        func origin(_ url: URL) -> String? {
            guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
                  let host = url.host?.lowercased(), !host.isEmpty else { return nil }
            return "\(scheme)://\(host):\(url.port ?? (scheme == "https" ? 443 : 80))"
        }
        guard !warmedNetwork.isEmpty, warmedNetwork == currentNetwork,
              let warmed = origin(warmedEndpoint), let current = origin(currentEndpoint) else { return false }
        return warmed == current
    }
}

/// Whole-file bitrate can hide a sustained high-bitrate section. Require both
/// insufficient measured delivery and a shrinking, low reserve; a GOP peak or
/// a stale bitrate during pause/buffering must not lower a healthy original.
struct PlaybackReserveDepletionPolicy {
    private struct Sample {
        let time: TimeInterval
        let current: TimeInterval
        let ahead: TimeInterval
        let target: TimeInterval
        let demand: Int
        let capacity: Int
    }
    private var generation: Int?
    private var samples: [Sample] = []

    static func demandBitrate(video: Int?, audio: Int?, rate: Double) -> Int? {
        guard let video, video > 0, let audio, audio >= 0,
              rate.isFinite, rate > 0 else { return nil }
        let (total, overflow) = video.addingReportingOverflow(audio)
        let scaled = Double(total) * rate
        guard !overflow, scaled.isFinite, scaled > 0,
              scaled < Double(Int.max) else { return nil }
        return Int(scaled)
    }

    mutating func sample(now: TimeInterval, eligible: Bool, seekGeneration: Int,
                         currentSeconds: TimeInterval, aheadSeconds: TimeInterval?,
                         targetSeconds: TimeInterval?, demandBitrate: Int?,
                         measuredCapacity: Int?) -> Bool {
        if generation != seekGeneration {
            generation = seekGeneration
            samples.removeAll()
        }
        guard eligible, now.isFinite, currentSeconds.isFinite, currentSeconds >= 0,
              let aheadSeconds, aheadSeconds.isFinite, aheadSeconds >= 0,
              let targetSeconds, targetSeconds.isFinite, targetSeconds > 0,
              let demandBitrate, demandBitrate > 0,
              let measuredCapacity, measuredCapacity > 0 else {
            samples.removeAll()
            return false
        }
        if let previous = samples.last {
            let delta = now - previous.time
            if delta <= 0 || delta > 2.5
                || currentSeconds <= previous.current + 0.25
                || abs(targetSeconds - previous.target) > 0.001 {
                samples.removeAll()
            }
        }
        samples.append(Sample(time: now, current: currentSeconds, ahead: aheadSeconds,
                              target: targetSeconds, demand: demandBitrate,
                              capacity: measuredCapacity))
        if samples.count > 3 { samples.removeFirst(samples.count - 3) }
        guard samples.count == 3, let first = samples.first,
              now - first.time >= 2, aheadSeconds < targetSeconds,
              (first.ahead - aheadSeconds) / (now - first.time) >= 0.15,
              zip(samples, samples.dropFirst()).allSatisfy({ pair in pair.1.ahead < pair.0.ahead - 0.05 }),
              let lowestDemand = samples.map(\.demand).min(),
              let highestCapacity = samples.map(\.capacity).max() else { return false }
        return Double(lowestDemand) > Double(highestCapacity) * 1.5
    }
}

/// A title is only a discovery hint; file identity is checked independently.
enum VerifiedFileLookupPolicy {
    struct Page<Item> {
        let items: [Item]
        let totalCount: Int?
    }

    struct Outcome<Item> {
        let items: [Item]
        let isComplete: Bool
        let broadenedSearch: Bool
    }

    static func load<Item>(searchHint: String?, pageSize: Int = 200,
                           maximumPages: Int = 3,
                           fetch: (String?, Int) async throws -> Page<Item>,
                           hasExactMatch: ([Item]) -> Bool) async throws -> Outcome<Item> {
        func collect(hint: String?, pages: Int, broadened: Bool) async throws -> Outcome<Item> {
            var items: [Item] = []
            for pageIndex in 0..<pages {
                try Task.checkCancellation()
                let page = try await fetch(hint, pageIndex * pageSize)
                try Task.checkCancellation()
                items.append(contentsOf: page.items)
                let complete = page.totalCount.map { $0 >= 0 && items.count >= $0 }
                    ?? (page.items.count < pageSize)
                if complete {
                    return Outcome(items: items, isComplete: true, broadenedSearch: broadened)
                }
                if page.items.count < pageSize {
                    // A short page cannot overrule a reported unread total.
                    // Advancing by pageSize would also skip unreturned items.
                    return Outcome(items: items, isComplete: false, broadenedSearch: broadened)
                }
            }
            return Outcome(items: items, isComplete: false, broadenedSearch: broadened)
        }
        guard pageSize > 0, maximumPages > 0 else {
            return Outcome(items: [], isComplete: false, broadenedSearch: false)
        }
        if let hint = searchHint, !hint.isEmpty {
            let hinted = try await collect(hint: hint, pages: 1, broadened: false)
            // Do not infer uniqueness from a truncated page or hide ambiguity
            // by discarding matching candidates and searching a different scope.
            if !hinted.isComplete || hasExactMatch(hinted.items) { return hinted }
            return try await collect(hint: nil, pages: maximumPages, broadened: true)
        }
        return try await collect(hint: nil, pages: maximumPages, broadened: false)
    }
}

enum VerifiedFileIdentityPolicy {
    static func matches(dsmPath: String, dsmSize: Int64,
                        jellyfinPath: String, jellyfinSize: Int64) -> Bool {
        guard dsmSize > 0, dsmSize == jellyfinSize else { return false }
        let expected = dsmPath.replacingOccurrences(of: "\\", with: "/").lowercased()
        let candidate = jellyfinPath.replacingOccurrences(of: "\\", with: "/").lowercased()
        let expectedName = (expected as NSString).lastPathComponent
        guard !expectedName.isEmpty,
              (candidate as NSString).lastPathComponent == expectedName else { return false }
        if candidate.hasSuffix(expected) { return true }
        let expectedParent = (expected as NSString).deletingLastPathComponent
        let candidateParent = (candidate as NSString).deletingLastPathComponent
        let tail = expectedParent.split(separator: "/").suffix(2).joined(separator: "/")
        return !tail.isEmpty && candidateParent.hasSuffix("/" + tail)
    }
}

/// Reconsider a restrictive Wi-Fi sample on a later playback attempt, without
/// probing on every tap or treating a failed sample as proof of more bandwidth.
enum GreenfieldBandwidthSamplePolicy {
    static func canReuse(age: TimeInterval, networkKey: String, wasMeasured: Bool,
                         safeBitrate: Int, originalSourceBitrate: Int?, rawBitrate: Int? = nil) -> Bool {
        let originalBudget = GreenfieldOriginalPlaybackPolicy.maximumOriginalBitrate(
            networkKey: networkKey, wasMeasured: wasMeasured,
            rawBitrate: rawBitrate ?? safeBitrate, conservativeBitrate: safeBitrate)
        let restrictsOriginal = networkKey == "wifi"
            && originalSourceBitrate.map { $0 > 0 && (!wasMeasured || originalBudget < $0) } == true
        let lifetime: TimeInterval = restrictsOriginal ? 30 : 600
        return age >= 0 && age < lifetime
    }
}

/// Original playback is a decoder decision followed by a network decision.
/// Container size alone must not override measured, sufficient Wi-Fi bandwidth.
enum GreenfieldOriginalPlaybackPolicy {
    static func bitmapSubtitleDecoderName(_ codec: String?) -> String? {
        switch codec?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pgssub", "hdmv_pgs_subtitle": return "pgssub"
        case "dvdsub", "dvd_subtitle": return "dvdsub"
        case "dvbsub", "dvb_subtitle": return "dvbsub"
        default: return nil
        }
    }

    /// HLS encoder ceilings are not limits on measured Wi-Fi file delivery.
    /// Do not inflate the sample; retain conservative budgets off Wi-Fi or
    /// when no successful measurement is available.
    static func maximumOriginalBitrate(networkKey: String, wasMeasured: Bool,
                                       rawBitrate: Int, conservativeBitrate: Int) -> Int {
        guard networkKey == "wifi", wasMeasured, rawBitrate > 0 else { return conservativeBitrate }
        return rawBitrate
    }

    static func allowsOriginal(forcedServerBitrate: Int?, audioRequiresTranscode: Bool,
                               subtitleRequiresServer: Bool, routeIsPrivate: Bool,
                               explicitOriginal: Bool, remoteBitrateFits: Bool,
                               experimentalOriginal: Bool = false, originalFirst: Bool = false) -> Bool {
        forcedServerBitrate == nil
            && (!audioRequiresTranscode || experimentalOriginal)
            && (!subtitleRequiresServer || experimentalOriginal)
            && (originalFirst || routeIsPrivate || explicitOriginal || remoteBitrateFits || experimentalOriginal)
    }

    static func audioDecoderName(_ codec: String?) -> String? {
        guard let codec = codec?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !codec.isEmpty else { return nil }
        switch codec {
        case "eac3-joc": return "eac3"
        case "dts-hd", "dtshd", "dts-hd ma": return "dca"
        case "dts": return "dca"
        // "Atmos" describes an extension, not its underlying audio codec.
        case "atmos": return nil
        default: return codec
        }
    }

    static func requiresAudioTranscode(codec: String?, decoderAvailable: Bool) -> Bool {
        guard let codec, !codec.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false // Missing metadata: let the demuxer discover the track.
        }
        return !decoderAvailable
    }

    static func retainsLargeRemoteGuard(networkKey: String, bandwidthBasis: String,
                                        sourceBitrate: Int?, originalBudget: Int) -> Bool {
        guard networkKey == "wifi", bandwidthBasis == "measured",
              let sourceBitrate, sourceBitrate > 0, originalBudget >= sourceBitrate else { return true }
        return false
    }
}

/// Source evidence only. Neither codec recognition nor PCM decoding certifies
/// Dolby rendering or Atmos object output on the current device/audio route.
struct PlaybackDolbySourceInfo: Hashable, Sendable {
    var visionProfile: Int?
    var visionLevel: Int?
    var baseLayerCompatibilityID: Int?
    var audioCodec: String?
    var audioProfile: String?
    var audioSpatialFormat: String?

    var audioEvidence: String {
        let codec = audioCodec?.lowercased() ?? ""
        let profile = audioProfile?.uppercased() ?? ""
        let declaresAtmos = audioSpatialFormat?.lowercased() == "dolbyatmos"
        if codec == "eac3-joc" || (codec == "eac3" && (profile.contains("JOC") || declaresAtmos)) {
            return "eac3JOC"
        }
        if codec == "truehd" || codec == "mlp" {
            return profile.contains("ATMOS") || declaresAtmos ? "trueHDAtmos" : "trueHDAtmosUnknown"
        }
        if codec == "eac3" { return "eac3AtmosUnknown" }
        return "unknown"
    }

    var diagnosticDetails: [String: String] {
        ["sourceDVProfile": visionProfile.map(String.init) ?? "unknown",
         "sourceDVLevel": visionLevel.map(String.init) ?? "unknown",
         "sourceDVCompatibilityID": baseLayerCompatibilityID.map(String.init) ?? "unknown",
         "sourceDolbyAudio": audioEvidence,
         "sourceAudioSpatialFormat": audioSpatialFormat ?? "unknown",
         "dolbyVisionOutput": "unverified", "dolbyAtmosOutput": "unverified"]
    }
}

enum PlaybackSourceResolverError: Error, Equatable {
    case unsupportedSource(PlaybackSourceKind)
    case missingPlayableURL
}

enum PlaybackPlanningPolicy {
    static func makePlan(
        intent: PlaybackIntent,
        url: URL,
        originURL: URL? = nil,
        fileExtensionHint: String? = nil,
        mimeHint: String? = nil,
        certificatePolicy: PlaybackCertificatePolicy = .systemTrust,
        byteLength: Int64? = nil,
        duration: TimeInterval? = nil,
        estimatedBitrate: Int? = nil,
        tracks: TrackCatalog = TrackCatalog(),
        subtitles: SubtitlePlan? = nil,
        alternateRoutes: [PlaybackRoute] = []
    ) -> PlaybackPlan {
        let extensionHint = normalizedExtension(fileExtensionHint, url: url)
        let routeKind = routeKind(
            sourceKind: intent.sourceKind,
            url: url,
            fileExtensionHint: extensionHint
        )
        let playMethod = playMethod(
            sourceKind: intent.sourceKind,
            routeKind: routeKind,
            timelineOffset: intent.preferredStartTime
        )
        let route = PlaybackRoute(
            routeKind: routeKind,
            playMethod: playMethod,
            url: url,
            originURL: originURL,
            certificatePolicy: certificatePolicy,
            containerHint: extensionHint,
            mimeHint: mimeHint,
            duration: duration,
            byteLength: byteLength,
            rangeCapability: rangeCapability(routeKind: routeKind, fileExtensionHint: extensionHint),
            codecSummary: PlaybackCodecSummary(
                container: extensionHint,
                bitrate: estimatedBitrate
            )
        )
        return PlaybackPlan(
            intent: intent,
            timeline: PlaybackTimeline(
                startTime: intent.preferredStartTime ?? 0,
                duration: duration
            ),
            primaryRoute: route,
            alternateRoutes: alternateRoutes,
            tracks: tracks,
            subtitles: subtitles ?? subtitlePlan(from: tracks),
            cachePolicy: cachePolicy(routeKind: routeKind),
            preloadPolicy: preloadPolicy(routeKind: routeKind, intent: intent),
            startupPolicy: startupPolicy(intent: intent, routeKind: routeKind),
            trackSwitchPolicy: trackSwitchPolicy(routeKind: routeKind, subtitles: subtitles ?? subtitlePlan(from: tracks)),
            pictureInPicturePolicy: pictureInPicturePolicy(routeKind: routeKind),
            recoveryPolicy: recoveryPolicy(intent: intent),
            enginePolicy: engineCandidate(
                preference: intent.playbackModePreference,
                routeKind: routeKind,
                fileExtensionHint: extensionHint
            )
        )
    }

    static func routeKind(
        sourceKind: PlaybackSourceKind,
        url: URL,
        fileExtensionHint: String?
    ) -> PlaybackRouteKind {
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        if scheme == "file" {
            return .localFile
        }
        if host == "127.0.0.1" || host == "localhost" {
            return fileExtensionHint == "m3u8" ? .localHLS : .localRangeProxy
        }
        if fileExtensionHint == "m3u8" {
            return sourceKind == .jellyfin ? .serverHLS : .directHTTP
        }
        return .directHTTP
    }

    static func playMethod(
        sourceKind: PlaybackSourceKind,
        routeKind: PlaybackRouteKind,
        timelineOffset: TimeInterval?
    ) -> PlaybackMethod {
        switch routeKind {
        case .serverHLS:
            return sourceKind == .jellyfin ? .serverTranscode : .directStream
        case .localHLS, .remuxedHLS:
            return .localRemux
        case .directHTTP, .localRangeProxy, .localFile:
            return .directPlay
        }
    }

    static func engineCandidate(
        preference: PlaybackModePreference,
        routeKind: PlaybackRouteKind,
        fileExtensionHint: String?
    ) -> PlaybackEngineCandidate {
        switch preference {
        case .system:
            return .systemAVPlayer
        case .localRemux:
            return .localHLS
        case .automatic, .original, .compatible, .external:
            break
        }

        switch routeKind {
        case .serverHLS, .localHLS, .remuxedHLS:
            return .systemAVPlayer
        case .directHTTP, .localRangeProxy, .localFile:
            return .ksPlayer
        }
    }

    static func rangeCapability(
        routeKind: PlaybackRouteKind,
        fileExtensionHint: String?
    ) -> PlaybackRangeCapability {
        if fileExtensionHint == "m3u8" {
            return .unsupported
        }
        switch routeKind {
        case .directHTTP, .localRangeProxy, .localFile:
            return .supported
        case .serverHLS, .localHLS, .remuxedHLS:
            return .unsupported
        }
    }

    static func cachePolicy(routeKind: PlaybackRouteKind) -> PlaybackCachePolicy {
        switch routeKind {
        case .directHTTP, .localRangeProxy:
            return PlaybackCachePolicy(
                isEnabled: true,
                memoryBudgetBytes: 64 * 1024 * 1024,
                diskBudgetBytes: 2 * 1024 * 1024 * 1024,
                preferredWindowBytes: 32 * 1024 * 1024
            )
        case .localFile:
            return PlaybackCachePolicy(isEnabled: false)
        case .serverHLS, .localHLS, .remuxedHLS:
            return PlaybackCachePolicy(
                isEnabled: true,
                memoryBudgetBytes: 32 * 1024 * 1024,
                diskBudgetBytes: 512 * 1024 * 1024,
                preferredWindowBytes: 8 * 1024 * 1024
            )
        }
    }

    static func preloadPolicy(
        routeKind: PlaybackRouteKind,
        intent: PlaybackIntent
    ) -> PlaybackPreloadPolicy {
        if isWeakNetwork(intent.networkContext) {
            switch routeKind {
            case .directHTTP, .localRangeProxy:
                return PlaybackPreloadPolicy(
                    isEnabled: true,
                    startupBytes: 512 * 1024,
                    seekTargetBytes: 2 * 1024 * 1024,
                    nextItemBytes: 16 * 1024 * 1024
                )
            case .serverHLS, .localHLS, .remuxedHLS:
                return PlaybackPreloadPolicy(
                    isEnabled: true,
                    startupBytes: 0,
                    seekTargetBytes: 512 * 1024,
                    nextItemBytes: 8 * 1024 * 1024
                )
            case .localFile:
                return PlaybackPreloadPolicy(isEnabled: false)
            }
        }

        switch routeKind {
        case .directHTTP, .localRangeProxy:
            return PlaybackPreloadPolicy(
                isEnabled: true,
                startupBytes: 16 * 1024 * 1024,
                seekTargetBytes: 8 * 1024 * 1024,
                nextItemBytes: 200 * 1024 * 1024
            )
        case .serverHLS, .localHLS, .remuxedHLS:
            return PlaybackPreloadPolicy(
                isEnabled: true,
                startupBytes: 4 * 1024 * 1024,
                seekTargetBytes: 2 * 1024 * 1024,
                nextItemBytes: 32 * 1024 * 1024
            )
        case .localFile:
            return PlaybackPreloadPolicy(isEnabled: false)
        }
    }

    static func startupPolicy(
        intent: PlaybackIntent,
        routeKind: PlaybackRouteKind
    ) -> PlaybackStartupPolicy {
        if isWeakNetwork(intent.networkContext) {
            return PlaybackStartupPolicy(
                firstFrameTargetMs: 3_000,
                startupPreloadBytes: routeKind == .localFile ? 0 : 512 * 1024,
                minimumPlayableBufferSeconds: 0.75,
                blocksFirstFrameUntilStartupPreload: false,
                defersNextItemPreloadUntilFirstFrame: true
            )
        }

        switch (routeKind, intent.connectionContext.addressKind) {
        case (.directHTTP, .privateIP), (.directHTTP, .localDomain), (.localRangeProxy, _):
            return PlaybackStartupPolicy(
                firstFrameTargetMs: 1_500,
                startupPreloadBytes: 4 * 1024 * 1024,
                minimumPlayableBufferSeconds: 1,
                blocksFirstFrameUntilStartupPreload: true,
                defersNextItemPreloadUntilFirstFrame: true
            )
        case (.serverHLS, _), (.localHLS, _), (.remuxedHLS, _):
            return PlaybackStartupPolicy(
                firstFrameTargetMs: 2_000,
                startupPreloadBytes: 0,
                minimumPlayableBufferSeconds: 1.25,
                blocksFirstFrameUntilStartupPreload: false,
                defersNextItemPreloadUntilFirstFrame: true
            )
        case (.localFile, _):
            return PlaybackStartupPolicy(
                firstFrameTargetMs: 800,
                startupPreloadBytes: 0,
                minimumPlayableBufferSeconds: 0,
                blocksFirstFrameUntilStartupPreload: false,
                defersNextItemPreloadUntilFirstFrame: false
            )
        default:
            return PlaybackStartupPolicy()
        }
    }

    /// Retain the fast first frame; raise the reserve only after the playback
    /// clock advances. Private addressing does not guarantee steady delivery:
    /// high-bitrate originals can exhaust the startup reserve on Wi-Fi too.
    static func steadyStateBufferSeconds(
        routeKind: PlaybackRouteKind,
        upstreamAddressKind: PlaybackConnectionAddressKind,
        startupSeconds: TimeInterval
    ) -> TimeInterval {
        guard routeKind == .localRangeProxy else { return startupSeconds }
        switch upstreamAddressKind {
        case .publicDomain, .publicIP, .unknown, .privateIP, .localDomain:
            return max(startupSeconds, 4)
        case .loopback:
            return startupSeconds
        }
    }

    static func trackSwitchPolicy(
        routeKind: PlaybackRouteKind,
        subtitles: SubtitlePlan
    ) -> PlaybackTrackSwitchPolicy {
        PlaybackTrackSwitchPolicy(
            prefersEngineNativeSwitch: routeKind != .serverHLS,
            allowsRouteRebuild: true,
            targetRecoveryMs: subtitles.mode == .serverBurnIn ? 1_500 : 700,
            prewarmsExternalSubtitles: subtitles.mode == .externalText || subtitles.mode == .uiOverlay
        )
    }

    static func pictureInPicturePolicy(routeKind: PlaybackRouteKind) -> PlaybackPictureInPicturePolicy {
        switch routeKind {
        case .serverHLS, .localHLS, .remuxedHLS:
            return PlaybackPictureInPicturePolicy(
                isEnabled: true,
                requiresSystemRenderer: true,
                allowsRendererSwap: false
            )
        case .directHTTP, .localRangeProxy, .localFile:
            return PlaybackPictureInPicturePolicy(
                isEnabled: true,
                requiresSystemRenderer: true,
                allowsRendererSwap: true
            )
        }
    }

    static func recoveryPolicy(intent: PlaybackIntent) -> PlaybackRecoveryPolicy {
        if isWeakNetwork(intent.networkContext) {
            return PlaybackRecoveryPolicy(
                rebufferWarningSeconds: 1,
                stallBeforeRouteRetrySeconds: 5,
                maximumRouteRetryCount: 3
            )
        }
        return PlaybackRecoveryPolicy()
    }

    static func subtitlePlan(from tracks: TrackCatalog) -> SubtitlePlan {
        guard let selectedID = tracks.selectedSourceSubtitleTrackID else {
            return SubtitlePlan(mode: .disabled)
        }
        let selectedTrack = tracks.sourceSubtitleTracks.first { $0.id == selectedID }
        if selectedTrack?.externalURL != nil {
            return SubtitlePlan(
                mode: .externalText,
                primarySubtitleID: selectedID,
                normalization: "utf8-text"
            )
        }
        return SubtitlePlan(mode: .embedded, primarySubtitleID: selectedID)
    }

    static func normalizedExtension(_ fileExtensionHint: String?, url: URL) -> String? {
        if let fileExtensionHint,
           !fileExtensionHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fileExtensionHint.lowercased()
        }
        let urlExtension = url.pathExtension.lowercased()
        return urlExtension.isEmpty ? nil : urlExtension
    }

    private static func isWeakNetwork(_ context: PlaybackNetworkContext) -> Bool {
        context.networkClass == .cellular
            || context.networkClass == .constrained
            || context.isExpensive
            || context.isConstrained
    }
}
