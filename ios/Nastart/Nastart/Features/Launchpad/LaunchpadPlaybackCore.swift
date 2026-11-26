import Foundation
import UIKit
import Network
import Combine
import Get
import KSPlayer
import NetworkMedia

/// Race authenticated probes for the same original file. A transcode or local
/// proxy is created only after a winning original route has been selected.
enum PlaybackOriginalRouteRace {
    enum Source: Sendable { case jellyfin, fileStation }
    struct Route: Sendable {
        let url: URL
        let source: Source
    }

    @MainActor
    static func resolve(
        jellyfin: @escaping @MainActor () async -> URL?,
        fileStation: (@MainActor () async -> URL?)? = nil
    ) async -> Route? {
        guard !Task.isCancelled else { return nil }
        return await withTaskGroup(of: Route?.self) { group in
            group.addTask {
                guard !Task.isCancelled, let url = await jellyfin(), !Task.isCancelled else { return nil }
                return Route(url: url, source: .jellyfin)
            }
            if let fileStation {
                group.addTask {
                    guard !Task.isCancelled, let url = await fileStation(), !Task.isCancelled else { return nil }
                    return Route(url: url, source: .fileStation)
                }
            }
            while let result = await group.next() {
                guard !Task.isCancelled else { group.cancelAll(); return nil }
                if let result { group.cancelAll(); return result }
            }
            return nil
        }
    }

    /// Task.value doesn't propagate cancellation to a reused warmup/probe.
    static func consume(_ task: Task<URL?, Never>) async -> URL? {
        await withTaskCancellationHandler {
            let url = await task.value
            return Task.isCancelled ? nil : url
        } onCancel: {
            task.cancel()
        }
    }
}

/// Try an already configured public media endpoint before private probes on
/// cellular. Both callbacks still perform the full authenticated Range check.
enum PlaybackFileOriginalRouteSelection {
    static func prefersPublicFirst(networkKey: String, remoteCandidates: [URL]) -> Bool {
        networkKey == "cellular" && !remoteCandidates.isEmpty && remoteCandidates.allSatisfy {
            $0.scheme?.lowercased() == "https" && $0.host != nil && $0.user == nil && $0.password == nil
                && !NetworkHostClassifier.isPrivate($0.host)
        }
    }

    @MainActor
    static func resolve(publicFirst: Bool, isCurrent: () -> Bool,
                        local: () async -> URL?, remote: () async -> URL?) async -> URL? {
        guard !Task.isCancelled, isCurrent() else { return nil }
        let first = await (publicFirst ? remote() : local())
        guard !Task.isCancelled, isCurrent() else { return nil }
        if let first { return first }
        let fallback = await (publicFirst ? local() : remote())
        guard !Task.isCancelled, isCurrent() else { return nil }
        return fallback
    }
}

/// A small probe's connection and first-byte wait are startup latency, not a
/// delivery-rate ceiling. Only a complete, uncached network body can rule out
/// original playback; an unavailable body timing remains a rendition hint.
struct PlaybackBandwidthProbeSample: Equatable {
    let bitrate: Int
    let usesNetworkBodyTiming: Bool
    let totalSeconds: TimeInterval
    let bodySeconds: TimeInterval?

    /// Foundation's received count includes protocol framing and transfer
    /// encoding. Compare the delivered payload with the requested bytes, not
    /// that wire count; an HTTP/2 frame or chunk must not disqualify a probe.
    static func networkPayloadBytes(received: Int64, decoded: Int64,
                                    contentEncoding: String?, transferEncoding: String?) -> Int64? {
        let identityContent = contentEncoding.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare("identity") == .orderedSame
        } ?? true
        let framingOnlyTransfer = transferEncoding.map {
            $0.split(separator: ",", omittingEmptySubsequences: false).allSatisfy {
                let coding = $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return coding == "chunked" || coding == "identity"
            }
        } ?? true
        guard identityContent, framingOnlyTransfer, decoded > 0, received >= decoded else { return nil }
        return decoded
    }

    static func estimate(bytes: Int, totalSeconds: TimeInterval,
                         networkBodyBytes: Int64?, networkBodySeconds: TimeInterval?) -> Self? {
        guard bytes > 0, totalSeconds.isFinite, totalSeconds > 0 else { return nil }
        let qualified = bytes >= 128 * 1024 && networkBodyBytes == Int64(bytes)
            && networkBodySeconds.map {
                $0.isFinite && $0 > 0 && $0 <= totalSeconds + 0.1
            } == true
        let seconds = qualified ? networkBodySeconds! : totalSeconds
        let rate = Double(bytes) * 8 / max(seconds, 0.05)
        guard rate.isFinite, rate >= 1, rate < Double(Int.max) else { return nil }
        return Self(bitrate: Int(rate), usesNetworkBodyTiming: qualified,
                    totalSeconds: totalSeconds, bodySeconds: qualified ? seconds : nil)
    }
}

final class PlaybackBandwidthProbeDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var body: (bytes: Int64, seconds: TimeInterval)?

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        let value = metrics.transactionMetrics.last.flatMap { metric -> (Int64, TimeInterval)? in
            guard metric.resourceFetchType == .networkLoad,
                  let response = metric.response as? HTTPURLResponse, response.statusCode == 200,
                  let start = metric.responseStartDate, let end = metric.responseEndDate,
                  let payloadBytes = PlaybackBandwidthProbeSample.networkPayloadBytes(
                    received: metric.countOfResponseBodyBytesReceived,
                    decoded: metric.countOfResponseBodyBytesAfterDecoding,
                    contentEncoding: response.value(forHTTPHeaderField: "Content-Encoding"),
                    transferEncoding: response.value(forHTTPHeaderField: "Transfer-Encoding"))
            else { return nil }
            return (payloadBytes, end.timeIntervalSince(start))
        }
        lock.lock()
        body = value
        lock.unlock()
    }

    func sample(bytes: Int, totalSeconds: TimeInterval) -> PlaybackBandwidthProbeSample? {
        lock.lock()
        let value = body
        lock.unlock()
        return PlaybackBandwidthProbeSample.estimate(bytes: bytes, totalSeconds: totalSeconds,
            networkBodyBytes: value?.bytes, networkBodySeconds: value?.seconds)
    }
}

struct PlaybackDownloadByteSample: Equatable {
    let sourceID: String
    let bytes: Int64
}

/// Counts received media bodies, including prefetch, rather than rendition
/// bitrate or the proxy's loopback delivery. No requests are made by this meter.
final class PlaybackDownloadMeter: @unchecked Sendable {
    static let shared = PlaybackDownloadMeter()
    private let lock = NSLock()
    private var totals: [String: (bytes: Int64, lastReceived: TimeInterval)] = [:]

    func receive(bytes: Int, traceID: String?, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard bytes > 0, let traceID, !traceID.isEmpty, now.isFinite else { return }
        lock.lock()
        defer { lock.unlock() }
        let old = totals[traceID]?.bytes ?? 0
        totals[traceID] = (old > Int64.max - Int64(bytes) ? Int64.max : old + Int64(bytes), now)
        if totals.count > 32, let oldest = totals.min(by: { $0.value.lastReceived < $1.value.lastReceived })?.key {
            totals.removeValue(forKey: oldest)
        }
    }

    func sample(traceID: String?) -> PlaybackDownloadByteSample? {
        guard let traceID else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return totals[traceID].map { PlaybackDownloadByteSample(sourceID: "proxy:" + traceID, bytes: $0.bytes) }
    }
}

struct PlaybackDownloadRateSampler {
    private var previous: (sample: PlaybackDownloadByteSample, time: TimeInterval)?

    mutating func update(_ sample: PlaybackDownloadByteSample?, now: TimeInterval) -> Double? {
        guard let sample, sample.bytes >= 0, now.isFinite else { previous = nil; return nil }
        let old = previous
        previous = (sample, now)
        guard let old, old.sample.sourceID == sample.sourceID,
              sample.bytes >= old.sample.bytes, now > old.time, now - old.time <= 5 else { return nil }
        return Double(sample.bytes - old.sample.bytes) / (now - old.time)
    }

    static func text(bytesPerSecond: Double?) -> String {
        guard let rate = bytesPerSecond, rate.isFinite, rate >= 0 else { return "— KB/s" }
        return rate >= 1_000_000 ? String(format: "%.1f MB/s", rate / 1_000_000)
            : String(format: "%.0f KB/s", rate / 1_000)
    }
}

enum PlaybackConnectionKind {
    case unknown, offline, wifi, cellular, wired, other
    var titleKey: String {
        switch self {
        case .unknown: return "player.status.network_unknown"
        case .offline: return "player.status.network_offline"
        case .wifi: return "player.status.network_wifi"
        case .cellular: return "player.status.network_cellular"
        case .wired: return "player.status.network_wired"
        case .other: return "player.status.network_other"
        }
    }
    var symbol: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .wired: return "network"
        case .offline: return "wifi.slash"
        default: return "network"
        }
    }
}

enum PlaybackSubtitleScreenEdgePolicy {
    static let edgeInset: CGFloat = 12
    // Reserve the same caption band even with subtitles off, so opening menus
    // or changing tracks cannot move either captions or playback buttons.
    static let captionBand: CGFloat = 44

    static func bottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        edgeInset + (safeAreaBottom.isFinite ? max(safeAreaBottom, 0) : 0)
    }
}

/// Captions follow the displayed video, including portrait letterboxing and fill.
/// Unknown geometry has no caption frame until the engine supplies its dimensions.
typealias PlaybackSubtitleViewportPolicy = SubtitleViewportGeometry

/// Playback and its bandwidth probe outlive the short directory-identity lookup.
/// Keep file and library playback on the library's established request budget.
enum JellyfinPlaybackSessionPolicy {
    static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        return configuration
    }
}

enum JellyfinHTTPStatus {
    static func code(for error: Error) -> Int? {
        guard case let APIError.unacceptableStatusCode(status) = error,
              (100...599).contains(status) else { return nil }
        return status
    }
}

/// A 401 for a session the app already holds means the server no longer
/// accepts its token (revoked, server data restored, password changed).
/// Retrying cannot fix that, so the library returns to sign-in; every other
/// failure is connectivity or server state and keeps the session.
enum JellyfinSessionRejectionPolicy {
    static func requiresSignIn(after error: Error) -> Bool {
        JellyfinHTTPStatus.code(for: error) == 401
    }
}

enum JellyfinLibraryError: Error {
    case missingSession
    case missingItem
    case missingPlaybackURL
}

enum JellyfinPlaybackPreparationErrorPolicy {
    /// Cancellation belongs to navigation/user intent, not a playback failure.
    /// Only a missing negotiated URL establishes that no playable stream was
    /// returned; transport failures must not receive that diagnosis.
    static func messageKey(for error: Error) -> String? {
        if error is CancellationError { return nil }
        var underlying: NSError? = error as NSError
        var networkCode: Int?
        for _ in 0..<4 {
            guard let value = underlying else { break }
            if value.domain == NSURLErrorDomain {
                if value.code == NSURLErrorCancelled { return nil }
                if networkCode == nil { networkCode = value.code }
            }
            underlying = value.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        if networkCode == NSURLErrorTimedOut {
            return "jellyfin.player.prepare_timeout"
        }
        if let networkCode, [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                             NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
                             NSURLErrorDNSLookupFailed, NSURLErrorInternationalRoamingOff,
                             NSURLErrorDataNotAllowed].contains(networkCode) {
            return "jellyfin.player.prepare_connection_failed"
        }
        if let networkCode, [NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted,
                             NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateHasUnknownRoot,
                             NSURLErrorServerCertificateNotYetValid].contains(networkCode) {
            return "jellyfin.player.prepare_secure_connection_failed"
        }
        switch JellyfinHTTPStatus.code(for: error) {
        case .some(401), .some(403): return "jellyfin.player.prepare_access_denied"
        case .some(429), .some(500...599): return "jellyfin.player.prepare_server_unavailable"
        default: break
        }
        if let error = error as? JellyfinLibraryError {
            switch error {
            case .missingSession: return "jellyfin.player.prepare_access_denied"
            case .missingPlaybackURL: return "jellyfin.player.prepare_failed_detail"
            case .missingItem: break
            }
        }
        return "jellyfin.player.prepare_unknown_failure"
    }
}

/// Keep late DSM discovery connected to playback while library navigation is
/// covered by search, details or the full-screen player. A view task may stop
/// receiving context as soon as the user leaves the library home.
@MainActor
final class JellyfinDSMPlaybackContextObserver {
    private var subscription: AnyCancellable?

    init(connectionStore: NASConnectionStore, update: @escaping (DSMSession?) -> Void) {
        subscription = connectionStore.$dsmSession.sink(receiveValue: update)
    }
}

/// A failed public-info probe may be transient while the library opens.
/// Keep the retry budget independent of the network request so it can be verified
/// without contacting or changing a real server.
struct JellyfinLANPlaybackProbePolicy {
    enum Decision: Equatable {
        case retryAfter(UInt64)
        case retriesExhausted
        case differentServer
        case verified
    }

    private(set) var retryCount = 0

    mutating func evaluate(publicID: String?, lanID: String?) -> Decision {
        guard let publicID, !publicID.isEmpty,
              let lanID, !lanID.isEmpty else {
            guard retryCount < 2 else { return .retriesExhausted }
            retryCount += 1
            return .retryAfter(retryCount == 1 ? 2_000_000_000 : 6_000_000_000)
        }
        return publicID == lanID ? .verified : .differentServer
    }
}

/// Owns preparation only; presenting a player transfers playback ownership.
/// Identity checks also reject services that return after ignoring cancellation.
@MainActor
final class PlaybackPreparation: ObservableObject {
    @Published private(set) var isPreparing = false
    private var requestID: UUID?
    private var task: Task<Void, Never>?

    func start(_ operation: @escaping @MainActor (UUID) async -> Void) {
        cancel()
        let id = UUID()
        requestID = id
        isPreparing = true
        task = Task {
            await operation(id)
            guard requestID == id else { return }
            requestID = nil
            isPreparing = false
            task = nil
        }
    }

    func isCurrent(_ id: UUID) -> Bool {
        requestID == id && !Task.isCancelled
    }

    /// Creates an observable cancellation window after preparing the stream,
    /// before a decoder is opened. Normal launches never wait here.
    func holdPreparedResultForDebugIfRequested(_ id: UUID, entry: String,
                                               delaySeconds: Double? = nil) async {
#if DEBUG
        let seconds = delaySeconds ?? Double(ProcessInfo.processInfo.environment[
            "NASTART_TEST_PREPARED_RESULT_DELAY_SECONDS"] ?? "") ?? 0
        guard isCurrent(id), seconds.isFinite, seconds > 0, seconds <= 10 else { return }
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.prepared_result_held",
            details: ["requestID": id.uuidString, "entry": entry, "delaySeconds": String(seconds)])
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.prepared_result_released",
            details: ["requestID": id.uuidString, "entry": entry,
                      "cancelled": isCurrent(id) ? "no" : "yes"])
#endif
    }

    func cancel() {
        requestID = nil
        task?.cancel()
        task = nil
        isPreparing = false
    }
}

enum AudioFormatPolicy {
    // Container recognition, not a guarantee that every codec/profile decodes.
    static let extensions: Set<String> = [
        "mp3", "mp2", "m4a", "m4b", "aac", "wav", "wave", "flac", "ogg", "oga", "opus",
        "wma", "ape", "alac", "aiff", "aif", "aifc", "amr", "ac3", "eac3", "dts", "caf",
        "wv", "tta", "mka", "au", "snd", "dsf", "dff"
    ]
}

enum DirectMediaURLPolicy {
    private static let mediaExtensions = [
        "m3u8", "mp4", "mkv", "mov", "m4v", "avi", "wmv", "webm",
        "ts", "m2ts", "mts", "mpeg", "mpg", "flv", "f4v", "3gp", "3g2",
        "vob", "rm", "rmvb", "ogv", "asf", "divx", "mxf", "m2v", "m1v",
        "mpv", "qt", "dv", "h264", "h265", "hevc", "av1", "nut", "amv",
        "bik", "roq", "wtv", "dvr-ms", "mod", "tod",
        "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "wma", "ape",
        "alac", "aiff", "aif", "amr", "ac3", "dts"
    ]

    static func canAttemptPlayback(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        return url.host?.isEmpty == false
    }

    static func isLikelyMediaURL(_ url: URL) -> Bool {
        guard canAttemptPlayback(url) else { return false }
        let normalizedURL = url.absoluteString.lowercased()
        return AudioFormatPolicy.extensions.contains(url.pathExtension.lowercased())
            || mediaExtensions.contains(url.pathExtension.lowercased())
            || mediaExtensions.contains { normalizedURL.contains(".\($0)?") }
    }
}

struct PlaybackNetworkSnapshot: Sendable {
    let cacheKey: String
    let bitrateCap: Int?
    let fallbackBitrate: Int
    // Local path observation identity, separate from the bitrate cache bucket.
    // Returning to Wi-Fi must not resurrect a verification from an old path.
    var pathGeneration: UInt64 = 0
    var playbackContext: PlaybackNetworkContext? = nil
}

/// A saved token or public server-info response alone is not an authenticated
/// route identity. Both identifiers must come from a successful Users/Me reply.
struct JellyfinAuthenticatedIdentity: Equatable, Sendable {
    let userID: String
    let serverID: String
    /// The account name the server reports for this user, when the reply carries one.
    /// No default here: a let with a default cannot be assigned again in init.
    let name: String?

    init(userID: String, serverID: String, name: String? = nil) {
        self.userID = userID
        self.serverID = serverID
        self.name = name
    }

    static func response(data: Data, status: Int) -> Self? {
        guard status == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let user = object["Id"] as? String,
              let server = object["ServerId"] as? String,
              !user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return Self(userID: user, serverID: server, name: object["Name"] as? String)
    }

    static func matches(primary: Self?, candidate: Self?, expectedUserID: String) -> Bool {
        guard !expectedUserID.isEmpty, let primary, let candidate,
              !primary.serverID.isEmpty, !candidate.serverID.isEmpty else { return false }
        return primary.userID == expectedUserID && candidate.userID == expectedUserID
            && primary.serverID == candidate.serverID
    }

    static func canPublish(startedOn: PlaybackNetworkSnapshot, current: PlaybackNetworkSnapshot,
                           startedSession: UUID, currentSession: UUID, cancelled: Bool) -> Bool {
        !cancelled && startedSession == currentSession && startedOn.cacheKey != "unknown"
            && startedOn.cacheKey == current.cacheKey && startedOn.pathGeneration != 0
            && startedOn.pathGeneration == current.pathGeneration
    }
}

/// A completed TLS response from the unchanged public library endpoint does
/// not inherit LAN verification from its carrier path. Keep that preparation
/// across cellular path updates; alternate origins and LAN identity proofs
/// still require the exact path generation that authenticated them.
enum JellyfinPublicCellularPreparationPolicy {
    static func permitsPathChange(startedOn: PlaybackNetworkSnapshot,
                                  current: PlaybackNetworkSnapshot,
                                  currentConnectionIsCellular: Bool,
                                  endpoint: URL, libraryEndpoint: URL,
                                  selectsLibraryEndpoint: Bool,
                                  allowsSelfSignedCertificates: Bool) -> Bool {
        rejectionReason(startedOn: startedOn, current: current,
            currentConnectionIsCellular: currentConnectionIsCellular,
            endpoint: endpoint, libraryEndpoint: libraryEndpoint,
            selectsLibraryEndpoint: selectsLibraryEndpoint,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates) == nil
    }

    /// Preserve the existing publication rules while making a discarded
    /// preparation distinguishable from a slow media response. No URL or
    /// credential is included in this diagnostic reason.
    static func rejectionReason(startedOn: PlaybackNetworkSnapshot,
                                current: PlaybackNetworkSnapshot,
                                currentConnectionIsCellular: Bool,
                                endpoint: URL, libraryEndpoint: URL,
                                selectsLibraryEndpoint: Bool,
                                allowsSelfSignedCertificates: Bool) -> String? {
        guard startedOn.cacheKey == "cellular", current.cacheKey == "cellular" else { return "networkBucketChanged" }
        guard currentConnectionIsCellular else { return "connectionNotCellular" }
        guard startedOn.pathGeneration != 0, current.pathGeneration != 0 else { return "pathIdentityUnknown" }
        guard startedOn.pathGeneration != current.pathGeneration else { return "pathGenerationUnchanged" }
        guard selectsLibraryEndpoint else { return "alternateEndpointSelection" }
        guard !allowsSelfSignedCertificates else { return "certificateOverrideEnabled" }
        guard endpoint == libraryEndpoint else { return "libraryEndpointMismatch" }
        guard endpoint.scheme?.lowercased() == "https" else { return "httpsRequired" }
        guard let host = endpoint.host, !host.isEmpty else { return "hostMissing" }
        guard !NetworkHostClassifier.isPrivate(host) else { return "privateHost" }
        return nil
    }
}

/// Reference capture does not publish media or transfer trust between origins.
/// Even when the user permits certificate overrides, a changed carrier path
/// must authenticate this exact saved library origin again before publication.
enum JellyfinPreparedLibraryRevalidation {
    static func permitsReference(startedOn: PlaybackNetworkSnapshot, endpoint: URL,
                                 libraryEndpoint: URL, savedEndpoint: URL,
                                 librarySelected: Bool, ownCredentialsMatch: Bool) -> Bool {
        librarySelected && ownCredentialsMatch && startedOn.cacheKey == "cellular"
            && startedOn.pathGeneration != 0 && endpoint == libraryEndpoint && endpoint == savedEndpoint
            && endpoint.scheme?.lowercased() == "https"
            && endpoint.host.map { !$0.isEmpty && !NetworkHostClassifier.isPrivate($0) } == true
    }

    /// A matching response on a path that changed in flight permits one fresh
    /// probe, never publication of the old response or full media negotiation.
    /// The caller continues to own and recheck the exact saved library origin.
    @MainActor
    static func authenticate(expected: JellyfinAuthenticatedIdentity, userID: String,
                             session: UUID, network: () -> PlaybackNetworkSnapshot,
                             ownershipCurrent: () -> Bool,
                             probe: () async -> JellyfinAuthenticatedIdentity?,
                             observed: (Int, JellyfinPreparedFallbackRevalidation.Outcome) -> Void = { _, _ in }) async
        -> JellyfinPreparedFallbackRevalidation.Outcome {
        for attempt in 1...2 {
            let result = await JellyfinPreparedFallbackRevalidation.authenticationAttempt(
                expected: expected, userID: userID, session: session, network: network,
                ownershipCurrent: ownershipCurrent, probe: probe)
            observed(attempt, result)
            guard attempt == 1, result.rejection == .pathChanged else { return result }
        }
        return .rejected(.pathChanged)
    }

    static func permitsRevalidation(startedOn: PlaybackNetworkSnapshot, current: PlaybackNetworkSnapshot,
                                    cellular: Bool, referenceAge: TimeInterval) -> Bool {
        cellular && startedOn.cacheKey == "cellular" && current.cacheKey == "cellular"
            && startedOn.pathGeneration != 0 && current.pathGeneration != 0
            && startedOn.pathGeneration != current.pathGeneration
            && JellyfinAuthenticatedFallbackPolicy.canUsePrimaryIdentity(age: referenceAge)
    }
}

/// A prepared alternate origin still needs a fresh authenticated response on
/// the new path. Revalidate that origin without negotiating the media twice.
enum JellyfinPreparedFallbackRevalidation {
    static func permitsProbe(startedOn: PlaybackNetworkSnapshot, current: PlaybackNetworkSnapshot,
                             endpoint: URL, savedEndpoint: URL, ownFallback: Bool,
                             cellular: Bool, allowsSelfSignedCertificates: Bool) -> Bool {
        ownFallback && cellular && !allowsSelfSignedCertificates
            && startedOn.cacheKey == "cellular" && current.cacheKey == "cellular"
            && startedOn.pathGeneration != 0 && current.pathGeneration != 0
            && startedOn.pathGeneration != current.pathGeneration
            && endpoint == savedEndpoint && endpoint.scheme?.lowercased() == "https"
            && endpoint.host.map { !$0.isEmpty && !NetworkHostClassifier.isPrivate($0) } == true
    }

    enum Rejection: String {
        case cancelled, ownershipChanged, unknownPath, nonCellularPath
        case missingIdentity, identityMismatch, pathChanged
    }

    enum Outcome {
        case authenticated(PlaybackNetworkSnapshot)
        case rejected(Rejection)

        var network: PlaybackNetworkSnapshot? {
            if case .authenticated(let network) = self { return network }
            return nil
        }
        var rejection: Rejection? {
            if case .rejected(let reason) = self { return reason }
            return nil
        }
    }

    @MainActor
    static func authenticationAttempt(expected: JellyfinAuthenticatedIdentity, userID: String,
                             session: UUID, network: () -> PlaybackNetworkSnapshot,
                             ownershipCurrent: () -> Bool,
                             probe: () async -> JellyfinAuthenticatedIdentity?) async -> Outcome {
        guard !Task.isCancelled else { return .rejected(.cancelled) }
        guard ownershipCurrent() else { return .rejected(.ownershipChanged) }
        let started = network()
        guard started.cacheKey != "unknown", started.pathGeneration != 0 else { return .rejected(.unknownPath) }
        guard started.cacheKey == "cellular" else { return .rejected(.nonCellularPath) }
        let identity = await probe()
        let current = network()
        guard !Task.isCancelled else { return .rejected(.cancelled) }
        guard ownershipCurrent() else { return .rejected(.ownershipChanged) }
        guard let identity else { return .rejected(.missingIdentity) }
        guard JellyfinAuthenticatedIdentity.matches(primary: expected, candidate: identity, expectedUserID: userID)
            else { return .rejected(.identityMismatch) }
        guard current.cacheKey != "unknown", current.pathGeneration != 0 else { return .rejected(.unknownPath) }
        guard current.cacheKey == "cellular" else { return .rejected(.nonCellularPath) }
        guard JellyfinAuthenticatedIdentity.canPublish(startedOn: started, current: current,
            startedSession: session, currentSession: session, cancelled: Task.isCancelled)
            else { return .rejected(.pathChanged) }
        return .authenticated(current)
    }

    @MainActor
    static func authenticate(expected: JellyfinAuthenticatedIdentity, userID: String,
                             session: UUID, network: () -> PlaybackNetworkSnapshot,
                             ownershipCurrent: () -> Bool,
                             probe: () async -> JellyfinAuthenticatedIdentity?) async -> PlaybackNetworkSnapshot? {
        let result = await authenticationAttempt(expected: expected, userID: userID, session: session,
            network: network, ownershipCurrent: ownershipCurrent, probe: probe)
        return result.network
    }
}

// Only a cancelled preparation waits for a settled path. No previous response
// becomes valid here; the caller must authenticate and prepare afresh.
struct JellyfinPlaybackPathSettling {
    enum Result { case waiting, ready, expired }
    private var lastPath: (key: String, generation: UInt64)?
    private var stableSince: TimeInterval = 0
    mutating func observe(_ network: PlaybackNetworkSnapshot, elapsed: TimeInterval) -> Result {
        guard elapsed.isFinite, elapsed >= 0, elapsed < 8 else { return .expired }
        guard network.cacheKey != "unknown", network.pathGeneration != 0 else {
            lastPath = nil
            stableSince = elapsed
            return .waiting
        }
        if lastPath?.key != network.cacheKey || lastPath?.generation != network.pathGeneration {
            lastPath = (network.cacheKey, network.pathGeneration)
            stableSince = elapsed
        }
        return elapsed - stableSince >= 4 ? .ready : .waiting
    }
}

enum JellyfinAuthenticatedFallbackPolicy {
    static func canProbeCurrentPublic(startedOn: PlaybackNetworkSnapshot, current: PlaybackNetworkSnapshot,
                                      startedSession: UUID, currentSession: UUID, primaryStatus: Int?,
                                      primaryFailure: String?, credentialsUnchanged: Bool, cancelled: Bool) -> Bool {
        !cancelled && credentialsUnchanged && startedSession == currentSession
            && startedOn.cacheKey == "cellular" && current.cacheKey == "cellular" && current.pathGeneration != 0
            && primaryIsUnreachable(status: primaryStatus, failure: primaryFailure)
    }
    static func canRestart(attempt: Int, startedOn: PlaybackNetworkSnapshot,
                           current: PlaybackNetworkSnapshot, startedSession: UUID,
                           currentSession: UUID, credentialsUnchanged: Bool, cancelled: Bool) -> Bool {
        attempt == 0 && !cancelled && credentialsUnchanged && startedSession == currentSession
            && current.cacheKey != "unknown" && current.pathGeneration != 0
            && current.pathGeneration != startedOn.pathGeneration
    }
    static func primaryIsUnreachable(status: Int?, failure: String?) -> Bool {
        guard status == nil else { return false }
        return ["URL_-1001", "URL_-1003", "URL_-1004", "URL_-1005", "URL_-1006",
                "URL_-1009", "URL_-1018"].contains(failure ?? "")
    }
    static func canUsePrimaryIdentity(age: TimeInterval) -> Bool {
        age.isFinite && age >= 0 && age < 300
    }
    static func canReuse(age: TimeInterval) -> Bool {
        age.isFinite && age >= 0 && age < 120
    }
}

/// Overlap only the first saved public origin with the private control probe.
/// A completed public response is not a route decision: the private result and
/// current ownership still gate its consumption, and the caller rechecks after
/// the await before publishing. Each operation owns its ephemeral URLSession.
@MainActor
final class JellyfinOverlappingIdentityProbes {
    typealias Result = (identity: JellyfinAuthenticatedIdentity?, status: Int?, failure: String?)

    let candidateEndpoint: URL
    let candidateNetwork: PlaybackNetworkSnapshot
    private let session: UUID
    private let primaryTask: Task<Result, Never>
    private let candidateTask: Task<Result, Never>
    private var completedPrimary: Result?

    init(candidateEndpoint: URL, network: PlaybackNetworkSnapshot, session: UUID,
         primary: @escaping @MainActor @Sendable () async -> Result,
         candidate: @escaping @MainActor @Sendable () async -> Result) {
        self.candidateEndpoint = candidateEndpoint
        self.candidateNetwork = network
        self.session = session
        primaryTask = Task { await primary() }
        candidateTask = Task { await candidate() }
    }

    func primaryResult() async -> Result {
        let result = await value(of: primaryTask)
        completedPrimary = result
        if !JellyfinAuthenticatedFallbackPolicy.primaryIsUnreachable(status: result.status,
                                                                     failure: result.failure) {
            candidateTask.cancel()
        }
        return result
    }

    func candidateResult(on current: PlaybackNetworkSnapshot, session currentSession: UUID,
                         credentialsCurrent: Bool) async -> Result? {
        guard let primary = completedPrimary,
              JellyfinAuthenticatedFallbackPolicy.primaryIsUnreachable(status: primary.status,
                                                                       failure: primary.failure) else {
            // Checking before the primary finishes must not cancel the useful
            // overlap; a definitive non-transport result cancels it above.
            return nil
        }
        guard credentialsCurrent,
              JellyfinAuthenticatedIdentity.canPublish(startedOn: candidateNetwork, current: current,
                startedSession: session, currentSession: currentSession, cancelled: Task.isCancelled) else {
            candidateTask.cancel()
            return nil
        }
        return await value(of: candidateTask)
    }

    func cancel() {
        primaryTask.cancel()
        candidateTask.cancel()
    }

    private func value(of task: Task<Result, Never>) async -> Result {
        let primary = primaryTask
        let candidate = candidateTask
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            // Awaiting an unstructured task alone does not forward the parent's
            // cancellation to either independent URLSession.data request.
            primary.cancel()
            candidate.cancel()
        }
    }
}

struct JellyfinLANPlaybackRouteCache {
    private var verification: (endpoint: URL, pathGeneration: UInt64)?

    func endpoint(on network: PlaybackNetworkSnapshot) -> URL? {
        guard network.cacheKey != "unknown", network.pathGeneration != 0,
              verification?.pathGeneration == network.pathGeneration else { return nil }
        return verification?.endpoint
    }

    @discardableResult
    mutating func publish(_ endpoint: URL, startedOn: PlaybackNetworkSnapshot,
                          current: PlaybackNetworkSnapshot) -> Bool {
        guard startedOn.cacheKey != "unknown", startedOn.pathGeneration != 0,
              startedOn.pathGeneration == current.pathGeneration else { return false }
        verification = (endpoint, current.pathGeneration)
        return true
    }
}

/// The source media and the device runtime are separate capability inputs.
/// Keep the runtime facts in diagnostics so an iPhone/iPad comparison can
/// prove whether the server plan or the local player is the diverging side.
struct MediaPlaybackCapabilities {
    let deviceFamily: String
    let osVersion: String
    let compatibilityEngineAvailable: Bool

    static var current: MediaPlaybackCapabilities {
        let device = UIDevice.current
        let family: String
        switch device.userInterfaceIdiom {
        case .pad: family = "iPad"
        case .phone: family = "iPhone"
        case .tv: family = "AppleTV"
        default: family = "other"
        }
        return MediaPlaybackCapabilities(
            deviceFamily: family,
            osVersion: device.systemVersion,
            compatibilityEngineAvailable: MediaPlaybackPolicy.hasCompatibilityEngine
        )
    }

    var diagnosticDetails: [String: String] {
        [
            "deviceFamily": deviceFamily,
            "osVersion": osVersion,
            "compatibilityEngine": compatibilityEngineAvailable ? "available" : "unavailable"
        ]
    }
}

struct PlaybackPathGeneration<Path: Equatable> {
    private var previous: Path?
    private(set) var generation: UInt64 = 0
    mutating func observe(_ path: Path) -> Bool {
        guard previous != path else { return false }
        previous = path
        generation &+= 1
        return true
    }
}

final class PlaybackNetworkObserver: @unchecked Sendable {
    static let shared = PlaybackNetworkObserver()

    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var pathGeneration = PlaybackPathGeneration<NWPath>()
    private var currentConnectionKind = PlaybackConnectionKind.unknown
    private var currentSnapshot = PlaybackNetworkSnapshot(
        cacheKey: "unknown",
        bitrateCap: 20_000_000,
        fallbackBitrate: 6_000_000
    )

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            var snapshot: PlaybackNetworkSnapshot
            if path.isConstrained {
                snapshot = PlaybackNetworkSnapshot(
                    cacheKey: "constrained",
                    bitrateCap: 6_000_000,
                    fallbackBitrate: 2_500_000
                )
            } else if path.usesInterfaceType(.cellular) {
                snapshot = PlaybackNetworkSnapshot(
                    cacheKey: "cellular",
                    bitrateCap: path.isExpensive ? 12_000_000 : 16_000_000,
                    fallbackBitrate: 2_000_000
                )
            } else if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) {
                snapshot = PlaybackNetworkSnapshot(
                    cacheKey: "wifi",
                    bitrateCap: 80_000_000,
                    fallbackBitrate: 8_000_000
                )
            } else {
                snapshot = PlaybackNetworkSnapshot(
                    cacheKey: path.isExpensive ? "expensive" : "other",
                    bitrateCap: path.isExpensive ? 10_000_000 : 20_000_000,
                    fallbackBitrate: path.isExpensive ? 3_500_000 : 6_000_000
                )
            }
            guard let self else { return }
            snapshot.playbackContext = PlaybackNetworkContext(
                networkClass: path.status != .satisfied ? .offline
                    : path.isConstrained ? .constrained
                    : path.usesInterfaceType(.cellular) ? .cellular
                    : (path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)) ? .wifi : .unknown,
                isExpensive: path.isExpensive,
                isConstrained: path.isConstrained
            )
            self.lock.lock()
            self.currentConnectionKind = path.status != .satisfied ? .offline
                : path.usesInterfaceType(.wifi) ? .wifi
                : path.usesInterfaceType(.cellular) ? .cellular
                : path.usesInterfaceType(.wiredEthernet) ? .wired : .other
            let changed = self.pathGeneration.observe(path)
            snapshot.pathGeneration = self.pathGeneration.generation
            if changed { self.currentSnapshot = snapshot }
            self.lock.unlock()
#if DEBUG
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.jellyfin.playback_route_state", details: [
                    "stage": "networkPathObserved", "network": snapshot.cacheKey,
                    "networkPathGeneration": String(snapshot.pathGeneration),
                    "pathEquivalent": String(!changed), "status": String(describing: path.status),
                    "supportsIPv4": String(path.supportsIPv4), "supportsIPv6": String(path.supportsIPv6),
                    "supportsDNS": String(path.supportsDNS), "expensive": String(path.isExpensive),
                    "constrained": String(path.isConstrained)])
#endif
        }
        monitor.start(queue: DispatchQueue(label: "com.changliwen.nastart.playback-network"))
    }

    func snapshot() -> PlaybackNetworkSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return currentSnapshot
    }

    func connectionKind() -> PlaybackConnectionKind {
        lock.lock()
        defer { lock.unlock() }
        return currentConnectionKind
    }

    func snapshotForPlayback() async throws -> PlaybackNetworkSnapshot {
        // The monitor's first callback is asynchronous. Every entry shares
        // the same bounded wait and retains unknown evidence on timeout.
        let deadline = ProcessInfo.processInfo.systemUptime + 0.15
        var value = snapshot()
        while value.playbackContext == nil, ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
            value = snapshot()
        }
        try Task.checkCancellation()
        return value
    }
}

struct MediaPlaybackResource {
    let url: URL
    let fileExtensionOverride: String?
    let subtitleURL: URL?
    let playbackTracker: MediaPlaybackTracker?
    let forcesSoftwareDecoding: Bool
    let allowsSelfSignedCertificates: Bool?
    let timelineOffsetSeconds: Double?
    let totalDurationSeconds: Double?

    init(
        url: URL,
        fileExtensionOverride: String? = nil,
        subtitleURL: URL? = nil,
        playbackTracker: MediaPlaybackTracker? = nil,
        forcesSoftwareDecoding: Bool = false,
        allowsSelfSignedCertificates: Bool? = nil,
        timelineOffsetSeconds: Double? = nil,
        totalDurationSeconds: Double? = nil
    ) {
        self.url = url
        self.fileExtensionOverride = fileExtensionOverride
        self.subtitleURL = subtitleURL
        self.playbackTracker = playbackTracker
        self.forcesSoftwareDecoding = forcesSoftwareDecoding
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.timelineOffsetSeconds = timelineOffsetSeconds
        self.totalDurationSeconds = totalDurationSeconds
    }
}

struct MediaPlaybackRuntimeState {
    let normalizedPosition: Double?
    let positionSeconds: Double?
    let playbackRate: Float
    let audioTrackOrdinal: Int?
    let subtitleTrackOrdinal: Int?
    let subtitlesDisabled: Bool
    let subtitleSelectionKnown: Bool
    let orientationMode: PlayerOrientationMode
    // Absolute demuxer/source indexes, distinct from a rendition's ordinals.
    var sourceAudioStreamIndex: Int? = nil
    var sourceSubtitleStreamIndex: Int? = nil
    var activeExternalSubtitleURL: URL? = nil
}

struct MediaPlaybackSourceTrack: Identifiable, Equatable {
    let id: Int
    let name: String
    let externalURL: URL?

    init(id: Int, name: String, externalURL: URL? = nil) {
        self.id = id
        self.name = name
        self.externalURL = externalURL
    }
}

enum MediaPlaybackContentKind {
    case automatic
    case video
    case audio
    case discImage
}

struct MediaPlaybackQualityOption: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String?
}

struct MediaPlaybackEpisodeNavigation {
    let previous: (() async -> MediaPlaybackRequest?)?
    let next: (() async -> MediaPlaybackRequest?)?
}

enum MediaPlaybackTimelineDomain: Equatable {
    case resourceRelative
    case sourceAbsolute
}

struct MediaPlaybackRequest: Identifiable {
    let id = UUID()
    let requestedAt: Date
    let url: URL
    let networkSource: NetworkMediaPlaybackSource?
    let title: String
    let allowsSelfSignedCertificates: Bool
    let source: MediaPlaybackSource
    let contentKind: MediaPlaybackContentKind
    let fileExtensionOverride: String?
    var initialPosition: Double?
    let externalSubtitleURL: URL?
    let preferredAudioTrackOrdinal: Int?
    let preferredSubtitleTrackOrdinal: Int?
    var prefersSubtitlesDisabled: Bool
    let initialOrientationMode: PlayerOrientationMode
    let initialPlaybackRate: Float
    let timelineOffsetSeconds: Double
    let timelineDomain: MediaPlaybackTimelineDomain
    var totalDurationSeconds: Double?
    let byteLength: Int64?
    let estimatedBitrate: Int?
    /// The selected server rendition ceiling, distinct from the source file bitrate.
    let streamBitrateCeiling: Int?
    let isPrivateNetworkRoute: Bool?
    let forcesSoftwareDecoding: Bool
    let playbackTracker: MediaPlaybackTracker?
    let compatibilityResource: MediaPlaybackResource?
    let compatibilityFallbackResource: MediaPlaybackResource?
    let externalHandoffResource: MediaPlaybackResource?
    let compatibilityResourceLoader: (() async -> MediaPlaybackResource?)?
    let compatibilityFallbackResourceLoader: ((MediaPlaybackRuntimeState?) async -> MediaPlaybackResource?)?
    let compatibilityFallbackRequestLoader: ((MediaPlaybackRuntimeState?) async -> MediaPlaybackRequest?)?
    let externalHandoffResourceLoader: (() async -> MediaPlaybackResource?)?
    let sourceAudioTracks: [MediaPlaybackSourceTrack]
    let sourceSubtitleTracks: [MediaPlaybackSourceTrack]
    var selectedSourceAudioTrackID: Int?
    var selectedSourceSubtitleTrackID: Int?
    let sourceTrackRequestLoader: ((Int?, Int?, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?
    let serverSeekRequestLoader: ((Double, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?
    let qualityOptions: [MediaPlaybackQualityOption]
    let selectedQualityID: String?
    let qualityRequestLoader: ((String, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?
    let playbackTraceID: String?
    let audioLyricsURL: URL?
    let episodeNavigationLoader: (() async -> MediaPlaybackEpisodeNavigation?)?
    var localResumeKey: String?

    init(
        requestedAt: Date = Date(),
        url: URL,
        title: String,
        networkSource: NetworkMediaPlaybackSource? = nil,
        allowsSelfSignedCertificates: Bool = false,
        source: MediaPlaybackSource = .directURL,
        contentKind: MediaPlaybackContentKind = .automatic,
        fileExtensionOverride: String? = nil,
        initialPosition: Double? = nil,
        externalSubtitleURL: URL? = nil,
        preferredAudioTrackOrdinal: Int? = nil,
        preferredSubtitleTrackOrdinal: Int? = nil,
        prefersSubtitlesDisabled: Bool = false,
        initialOrientationMode: PlayerOrientationMode = .landscape,
        initialPlaybackRate: Float = 1,
        timelineOffsetSeconds: Double = 0,
        timelineDomain: MediaPlaybackTimelineDomain = .resourceRelative,
        totalDurationSeconds: Double? = nil,
        byteLength: Int64? = nil,
        estimatedBitrate: Int? = nil,
        streamBitrateCeiling: Int? = nil,
        isPrivateNetworkRoute: Bool? = nil,
        forcesSoftwareDecoding: Bool = false,
        playbackTracker: MediaPlaybackTracker? = nil,
        compatibilityResource: MediaPlaybackResource? = nil,
        compatibilityFallbackResource: MediaPlaybackResource? = nil,
        externalHandoffResource: MediaPlaybackResource? = nil,
        compatibilityResourceLoader: (() async -> MediaPlaybackResource?)? = nil,
        compatibilityFallbackResourceLoader: ((MediaPlaybackRuntimeState?) async -> MediaPlaybackResource?)? = nil,
        compatibilityFallbackRequestLoader: ((MediaPlaybackRuntimeState?) async -> MediaPlaybackRequest?)? = nil,
        externalHandoffResourceLoader: (() async -> MediaPlaybackResource?)? = nil,
        sourceAudioTracks: [MediaPlaybackSourceTrack] = [],
        sourceSubtitleTracks: [MediaPlaybackSourceTrack] = [],
        selectedSourceAudioTrackID: Int? = nil,
        selectedSourceSubtitleTrackID: Int? = nil,
        sourceTrackRequestLoader: ((Int?, Int?, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)? = nil,
        serverSeekRequestLoader: ((Double, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)? = nil,
        qualityOptions: [MediaPlaybackQualityOption] = [],
        selectedQualityID: String? = nil,
        qualityRequestLoader: ((String, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)? = nil,
        playbackTraceID: String? = nil,
        audioLyricsURL: URL? = nil,
        episodeNavigationLoader: (() async -> MediaPlaybackEpisodeNavigation?)? = nil,
        localResumeKey: String? = nil
    ) {
        self.requestedAt = requestedAt
        self.url = url
        self.title = title
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.source = source
        self.contentKind = contentKind
        self.fileExtensionOverride = fileExtensionOverride
        self.initialPosition = initialPosition.map { min(max($0, 0), 1) }
        self.externalSubtitleURL = externalSubtitleURL
        self.preferredAudioTrackOrdinal = preferredAudioTrackOrdinal
        self.preferredSubtitleTrackOrdinal = preferredSubtitleTrackOrdinal
        self.prefersSubtitlesDisabled = prefersSubtitlesDisabled
        self.initialOrientationMode = initialOrientationMode
        self.initialPlaybackRate = min(max(initialPlaybackRate, 0.25), 4)
        self.timelineOffsetSeconds = max(timelineOffsetSeconds, 0)
        self.timelineDomain = timelineDomain
        self.totalDurationSeconds = totalDurationSeconds.flatMap { $0 > 0 ? $0 : nil }
        self.networkSource = networkSource
        self.byteLength = byteLength.flatMap { $0 > 0 ? $0 : nil }
        self.estimatedBitrate = estimatedBitrate.flatMap { $0 > 0 ? $0 : nil }
        self.streamBitrateCeiling = streamBitrateCeiling.flatMap { $0 > 0 ? $0 : nil }
        self.isPrivateNetworkRoute = isPrivateNetworkRoute
        self.forcesSoftwareDecoding = forcesSoftwareDecoding
        self.playbackTracker = playbackTracker
        self.compatibilityResource = compatibilityResource
        self.compatibilityFallbackResource = compatibilityFallbackResource
        self.externalHandoffResource = externalHandoffResource
        self.compatibilityResourceLoader = compatibilityResourceLoader
        self.compatibilityFallbackResourceLoader = compatibilityFallbackResourceLoader
        self.compatibilityFallbackRequestLoader = compatibilityFallbackRequestLoader
        self.externalHandoffResourceLoader = externalHandoffResourceLoader
        self.sourceAudioTracks = sourceAudioTracks
        self.sourceSubtitleTracks = sourceSubtitleTracks
        self.selectedSourceAudioTrackID = selectedSourceAudioTrackID
        self.selectedSourceSubtitleTrackID = selectedSourceSubtitleTrackID
        self.sourceTrackRequestLoader = sourceTrackRequestLoader
        self.serverSeekRequestLoader = serverSeekRequestLoader
        self.qualityOptions = qualityOptions
        self.selectedQualityID = selectedQualityID
        self.qualityRequestLoader = qualityRequestLoader
        self.playbackTraceID = playbackTraceID?.isEmpty == false ? playbackTraceID : nil
        self.episodeNavigationLoader = episodeNavigationLoader
        self.audioLyricsURL = audioLyricsURL
        self.localResumeKey = localResumeKey ?? networkSource.map { "network-file:" + $0.stableID }
    }

    var fileExtensionHint: String {
        if let fileExtensionOverride, !fileExtensionOverride.isEmpty {
            return fileExtensionOverride.lowercased()
        }
        let titleExtension = URL(fileURLWithPath: title).pathExtension.lowercased()
        return titleExtension.isEmpty ? url.pathExtension.lowercased() : titleExtension
    }

    var rendererTimelineOffsetSeconds: Double {
        if timelineDomain == .sourceAbsolute || (source == .jellyfin && fileExtensionHint == "m3u8") { return 0 }
        return timelineOffsetSeconds
    }

    var mimeTypeHint: String? {
        switch fileExtensionHint {
        case "mp4", "m4v": return "video/mp4"
        case "mov": return "video/quicktime"
        case "m3u8": return "application/vnd.apple.mpegurl"
        case "ts", "m2ts": return "video/mp2t"
        case "mp3": return "audio/mpeg"
        case "m4a", "aac": return "audio/mp4"
        case "wav": return "audio/wav"
        default: return nil
        }
    }

    var isAudioOnly: Bool {
        switch contentKind {
        case .audio:
            return true
        case .video, .discImage:
            return false
        case .automatic:
            return Self.audioExtensions.contains(fileExtensionHint)
        }
    }

    private static let audioExtensions = AudioFormatPolicy.extensions

    var allowsExternalHandoff: Bool {
        let handoffURL = externalHandoffResource?.url ?? url
        guard let scheme = handoffURL.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        return true
    }

    var containsSensitiveCredential: Bool {
        let sensitiveQueryNames = Set([
            "_sid", "api_key", "apikey", "token", "access_token", "authorization"
        ])
        let handoffURL = externalHandoffResource?.url ?? url
        let queryItems = URLComponents(url: handoffURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return queryItems.contains { sensitiveQueryNames.contains($0.name.lowercased()) }
    }

    var externalFilename: String {
        let extensionHint = externalHandoffFileExtensionHint
        guard !extensionHint.isEmpty,
              URL(fileURLWithPath: title).pathExtension.isEmpty else {
            return title
        }
        return "\(title).\(extensionHint)"
    }

    var externalHandoffURL: URL {
        externalHandoffResource?.url ?? url
    }

    var externalHandoffSubtitleURL: URL? {
        externalHandoffResource?.subtitleURL ?? externalSubtitleURL
    }

    var externalHandoffFileExtensionHint: String {
        if let override = externalHandoffResource?.fileExtensionOverride, !override.isEmpty {
            return override.lowercased()
        }
        return fileExtensionHint
    }

    var networkOriginURL: URL {
        networkSource?.originURL ?? externalHandoffResource?.url ?? url
    }

    // Legacy normalization disables the embedded ASS renderer while supplying
    // an external SRT. Greenfield's shared overlay must still display that SRT.
    var greenfieldSubtitlesDisabled: Bool {
        prefersSubtitlesDisabled && externalSubtitleURL == nil
    }

    func sourceSubtitleTrackID(forExternalURL url: URL) -> Int? {
        let matches = sourceSubtitleTracks.filter { $0.id >= 0 && $0.externalURL == url }
        return matches.count == 1 ? matches[0].id : nil
    }

    func committedSourceSubtitleTrackID(forRuntimeState state: MediaPlaybackRuntimeState) -> Int? {
        guard state.subtitleSelectionKnown else { return selectedSourceSubtitleTrackID }
        guard !state.subtitlesDisabled else { return nil }
        if let url = state.activeExternalSubtitleURL {
            return sourceSubtitleTrackID(forExternalURL: url)
        }
        if let id = state.sourceSubtitleStreamIndex {
            return sourceSubtitleTracks.contains { $0.id == id && id >= 0 } ? id : nil
        }
        return state.subtitleTrackOrdinal.flatMap { ordinal in
            guard sourceSubtitleTracks.indices.contains(ordinal), sourceSubtitleTracks[ordinal].id >= 0 else { return nil }
            return sourceSubtitleTracks[ordinal].id
        }
    }

    var compatibilityPlaybackRequest: MediaPlaybackRequest {
        guard let compatibilityResource else { return self }
        return playbackRequest(using: compatibilityResource)
    }

    func playbackRequest(
        using resource: MediaPlaybackResource,
        initialPositionOverride: Double? = nil,
        runtimeState: MediaPlaybackRuntimeState? = nil,
        retainsFallback: Bool = true
    ) -> MediaPlaybackRequest {
        return MediaPlaybackRequest(
            requestedAt: requestedAt,
            url: resource.url,
            title: title,
            networkSource: networkSource,
            allowsSelfSignedCertificates: resource.allowsSelfSignedCertificates
                ?? allowsSelfSignedCertificates,
            source: source,
            contentKind: contentKind,
            fileExtensionOverride: resource.fileExtensionOverride,
            initialPosition: resource.timelineOffsetSeconds == nil
                ? runtimeState?.normalizedPosition ?? initialPositionOverride ?? initialPosition
                : nil,
            externalSubtitleURL: resource.subtitleURL,
            preferredAudioTrackOrdinal: runtimeState?.audioTrackOrdinal ?? preferredAudioTrackOrdinal,
            preferredSubtitleTrackOrdinal: runtimeState?.subtitleTrackOrdinal ?? preferredSubtitleTrackOrdinal,
            prefersSubtitlesDisabled: runtimeState.map {
                $0.subtitleSelectionKnown ? $0.subtitlesDisabled : prefersSubtitlesDisabled
            } ?? prefersSubtitlesDisabled,
            initialOrientationMode: runtimeState?.orientationMode ?? initialOrientationMode,
            initialPlaybackRate: runtimeState?.playbackRate ?? initialPlaybackRate,
            timelineOffsetSeconds: resource.timelineOffsetSeconds ?? timelineOffsetSeconds,
            timelineDomain: timelineDomain,
            totalDurationSeconds: resource.totalDurationSeconds ?? totalDurationSeconds,
            byteLength: byteLength,
            estimatedBitrate: estimatedBitrate,
            streamBitrateCeiling: streamBitrateCeiling,
            isPrivateNetworkRoute: isPrivateNetworkRoute,
            forcesSoftwareDecoding: resource.forcesSoftwareDecoding,
            playbackTracker: resource.playbackTracker ?? playbackTracker,
            compatibilityFallbackResource: retainsFallback ? compatibilityFallbackResource : nil,
            externalHandoffResource: externalHandoffResource,
            compatibilityFallbackResourceLoader: retainsFallback
                ? compatibilityFallbackResourceLoader
                : nil,
            compatibilityFallbackRequestLoader: retainsFallback
                ? compatibilityFallbackRequestLoader
                : nil,
            externalHandoffResourceLoader: externalHandoffResourceLoader,
            sourceAudioTracks: sourceAudioTracks,
            sourceSubtitleTracks: sourceSubtitleTracks,
            selectedSourceAudioTrackID: selectedSourceAudioTrackID,
            selectedSourceSubtitleTrackID: selectedSourceSubtitleTrackID,
            sourceTrackRequestLoader: sourceTrackRequestLoader,
            serverSeekRequestLoader: serverSeekRequestLoader,
            qualityOptions: qualityOptions,
            selectedQualityID: selectedQualityID,
            qualityRequestLoader: qualityRequestLoader,
            playbackTraceID: playbackTraceID,
            audioLyricsURL: audioLyricsURL,
            episodeNavigationLoader: episodeNavigationLoader,
            localResumeKey: localResumeKey
        )
    }

    func runtimeStateForSourceChange(_ state: MediaPlaybackRuntimeState,
                                     selectedAudioID: Int?, selectedSubtitleID: Int?) -> MediaPlaybackRuntimeState {
        // Menu ordinals describe this catalog, not the absolute source stream.
        // A verified file HLS seek needs both identities, including a sidecar
        // that never appears in AVPlayer's legible group. Reject unknown or
        // duplicate catalog IDs instead of guessing from rendition ordinals.
        let audioMatches = sourceAudioTracks.filter { $0.id == selectedAudioID && $0.id >= 0 }
        let audio = audioMatches.count == 1 ? audioMatches.first : nil
        let subtitleMatches = sourceSubtitleTracks.filter {
            $0.id == selectedSubtitleID && ($0.id >= 0 || $0.externalURL != nil)
        }
        let subtitle = subtitleMatches.count == 1 ? subtitleMatches.first : nil
        return MediaPlaybackRuntimeState(
            normalizedPosition: state.normalizedPosition,
            positionSeconds: state.positionSeconds,
            playbackRate: state.playbackRate,
            audioTrackOrdinal: audio.flatMap { track in sourceAudioTracks.firstIndex { $0.id == track.id } },
            subtitleTrackOrdinal: subtitle.flatMap { track in sourceSubtitleTracks.firstIndex { $0.id == track.id } },
            subtitlesDisabled: selectedSubtitleID == nil,
            subtitleSelectionKnown: selectedSubtitleID == nil || subtitle != nil,
            orientationMode: state.orientationMode,
            sourceAudioStreamIndex: audio?.id,
            sourceSubtitleStreamIndex: subtitle?.externalURL == nil ? subtitle?.id : nil,
            activeExternalSubtitleURL: subtitle?.externalURL
        )
    }

    /// Manual track loading and the final live refresh must both preserve the
    /// negotiated selection; an earlier copy of outgoing Off is irreversible.
    func applyingSourceTrackRuntimePreferences(_ runtimeState: MediaPlaybackRuntimeState) -> MediaPlaybackRequest {
        applyingRuntimePreferences(runtimeState, preservingRequestedSubtitleSelection: true)
    }

    func applyingRuntimePreferences(_ runtimeState: MediaPlaybackRuntimeState,
                                    preservingRequestedSubtitleSelection: Bool = false) -> MediaPlaybackRequest {
        MediaPlaybackRequest(
            requestedAt: requestedAt,
            url: url,
            title: title,
            networkSource: networkSource,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            source: source,
            contentKind: contentKind,
            fileExtensionOverride: fileExtensionOverride,
            // A replacement resource must resume at the live playhead. Keeping
            // the request's original entry.progress here makes a quality or
            // source-track switch jump back to where playback initially began.
            // Transcoded HLS carries an absolute server start time instead, so
            // its relative playhead intentionally remains nil.
            initialPosition: timelineOffsetSeconds > 0
                ? nil
                : runtimeState.normalizedPosition ?? initialPosition,
            externalSubtitleURL: externalSubtitleURL,
            preferredAudioTrackOrdinal: preferredAudioTrackOrdinal,
            preferredSubtitleTrackOrdinal: preferredSubtitleTrackOrdinal,
            // A manual track replacement owns its new selection. Refreshing
            // the outgoing live clock/rate must not restore its old Off state.
            prefersSubtitlesDisabled: !preservingRequestedSubtitleSelection && runtimeState.subtitleSelectionKnown
                ? runtimeState.subtitlesDisabled
                : prefersSubtitlesDisabled,
            initialOrientationMode: runtimeState.orientationMode,
            initialPlaybackRate: runtimeState.playbackRate,
            timelineOffsetSeconds: timelineOffsetSeconds,
            timelineDomain: timelineDomain,
            totalDurationSeconds: totalDurationSeconds,
            byteLength: byteLength,
            estimatedBitrate: estimatedBitrate,
            streamBitrateCeiling: streamBitrateCeiling,
            isPrivateNetworkRoute: isPrivateNetworkRoute,
            forcesSoftwareDecoding: forcesSoftwareDecoding,
            playbackTracker: playbackTracker,
            compatibilityResource: compatibilityResource,
            compatibilityFallbackResource: compatibilityFallbackResource,
            externalHandoffResource: externalHandoffResource,
            compatibilityResourceLoader: compatibilityResourceLoader,
            compatibilityFallbackResourceLoader: compatibilityFallbackResourceLoader,
            compatibilityFallbackRequestLoader: compatibilityFallbackRequestLoader,
            externalHandoffResourceLoader: externalHandoffResourceLoader,
            sourceAudioTracks: sourceAudioTracks,
            sourceSubtitleTracks: sourceSubtitleTracks,
            selectedSourceAudioTrackID: selectedSourceAudioTrackID,
            selectedSourceSubtitleTrackID: selectedSourceSubtitleTrackID,
            sourceTrackRequestLoader: sourceTrackRequestLoader,
            serverSeekRequestLoader: serverSeekRequestLoader,
            qualityOptions: qualityOptions,
            selectedQualityID: selectedQualityID,
            qualityRequestLoader: qualityRequestLoader,
            playbackTraceID: playbackTraceID,
            audioLyricsURL: audioLyricsURL,
            episodeNavigationLoader: episodeNavigationLoader,
            localResumeKey: localResumeKey
        )
    }
}

enum MediaPlaybackTrackingEvent: Sendable {
    case started(positionSeconds: Double)
    case progressed(positionSeconds: Double, isPaused: Bool)
    case stopped(positionSeconds: Double, failed: Bool)
}

/// At most two pending events: start plus latest progress, or start plus stop.
/// An in-flight event lives
/// outside this buffer; stop replaces unsent progress with its final position.
struct MediaPlaybackEventBuffer {
    private var events: [MediaPlaybackTrackingEvent] = []
    private var ended = false
    private var started = false
    var count: Int { events.count }

    mutating func append(_ event: MediaPlaybackTrackingEvent) {
        guard !ended else { return }
        switch event {
        case .started:
            guard !started else { return }
            started = true
            events.append(event)
        case .progressed:
            guard started else { return }
            events.removeAll { if case .progressed = $0 { return true }; return false }
            events.append(event)
        case .stopped:
            ended = true
            guard started else { return }
            events.removeAll { if case .progressed = $0 { return true }; return false }
            events.append(event)
        }
    }

    mutating func next() -> MediaPlaybackTrackingEvent? {
        events.isEmpty ? nil : events.removeFirst()
    }
}

/// The lock protects only admission/dequeue, never network work. One worker
/// owns a tracker queue until drained; no Task is created per progress event.
final class MediaPlaybackReportQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = MediaPlaybackEventBuffer()
    private var draining = false
    private let report: @MainActor @Sendable (MediaPlaybackTrackingEvent) async -> Void

    init(report: @escaping @MainActor @Sendable (MediaPlaybackTrackingEvent) async -> Void) {
        self.report = report
    }

    func enqueue(_ event: MediaPlaybackTrackingEvent) {
        lock.lock()
        pending.append(event)
        let shouldStart = !draining && pending.count > 0
        if shouldStart { draining = true }
        lock.unlock()
        if shouldStart {
            Task { @MainActor in
                while let event = self.takeNext() {
                    await self.report(event)
                }
            }
        }
    }

    private func takeNext() -> MediaPlaybackTrackingEvent? {
        lock.lock()
        defer { lock.unlock() }
        let event = pending.next()
        if event == nil { draining = false }
        return event
    }
}

/// Tickets are allocated during preparation but acquire UI ownership only on
/// actual start. Old-account callbacks cannot acquire ownership after logout.
final class PlaybackActivityScope: @unchecked Sendable {
    struct Ticket: Sendable, Equatable {
        fileprivate let epoch: UUID
        fileprivate let id: UUID
    }

    private let lock = NSLock()
    private var epoch = UUID()
    private var active: Ticket?

    func prepare() -> Ticket {
        lock.lock()
        defer { lock.unlock() }
        return Ticket(epoch: epoch, id: UUID())
    }

    func activate(_ ticket: Ticket) {
        lock.lock()
        defer { lock.unlock() }
        guard ticket.epoch == epoch else { return }
        active = ticket
    }

    func isCurrent(_ ticket: Ticket) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return ticket.epoch == epoch && active == ticket
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        epoch = UUID()
        active = nil
    }
}

/// Main-actor-owned scope for authenticated playback reports and resume loads.
/// Session identity changes even when the same account signs in again.
struct PlaybackResponseScope {
    struct ResumeRequest {
        fileprivate let sessionID: UUID
        fileprivate let requestID: UUID
    }

    private(set) var sessionID = UUID()
    private var resumeRequestID: UUID?

    mutating func invalidateSession() {
        sessionID = UUID()
        resumeRequestID = nil
    }

    func acceptsSession(_ id: UUID) -> Bool { sessionID == id }

    mutating func beginResumeRequest() -> ResumeRequest {
        let id = UUID()
        resumeRequestID = id
        return ResumeRequest(sessionID: sessionID, requestID: id)
    }

    func acceptsResumeResponse(_ request: ResumeRequest) -> Bool {
        acceptsSession(request.sessionID) && resumeRequestID == request.requestID
    }
}

enum PlaybackPositionPolicy {
    static func ticks(for seconds: Double) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        let ticks = seconds * 10_000_000
        // Double(Int.max) rounds up on 64-bit platforms and cannot be
        // converted back to Int. Clamp before performing that conversion.
        guard ticks < Double(Int.max) else { return Int.max }
        return Int(ticks)
    }
}

final class MediaPlaybackTracker {
    private let lock = NSLock()
    private let eventHandler: (MediaPlaybackTrackingEvent) -> Void
    private let releaseResources: () -> Void
    private let progressIntervalSeconds: Double
    private var didReleaseResources = false
    private var didStart = false
    private var didStop = false
    private var lastPositionSeconds = 0.0
    private var lastReportedPositionSeconds = -Double.infinity
    private var lastPausedState: Bool?
    private var pendingEvents = MediaPlaybackEventBuffer()
    private var deliveringEvents = false

    init(progressIntervalSeconds: Double = 10, releaseResources: @escaping () -> Void = {},
         eventHandler: @escaping (MediaPlaybackTrackingEvent) -> Void) {
        self.progressIntervalSeconds = progressIntervalSeconds
        self.releaseResources = releaseResources
        self.eventHandler = eventHandler
    }

    deinit { releasePreparedResources() }

    /// A prewarmed server stream can be abandoned before playback starts.
    /// Release its encoder without reporting a fictitious watched position.
    func releasePreparedResources() {
        lock.lock()
        guard !didReleaseResources else { lock.unlock(); return }
        didReleaseResources = true
        didStop = true
        lock.unlock()
        releaseResources()
    }

    func started(positionSeconds: Double) {
        guard positionSeconds.isFinite else { return }
        let position = max(positionSeconds, 0)
        lock.lock()
        guard !didStart, !didStop else {
            lock.unlock()
            return
        }
        didStart = true
        lastPositionSeconds = position
        lastReportedPositionSeconds = position
        pendingEvents.append(.started(positionSeconds: position))
        lock.unlock()
        deliverPendingEvents()
    }

    func progressed(positionSeconds: Double, isPaused: Bool, force: Bool = false) {
        guard positionSeconds.isFinite else { return }
        let position = max(positionSeconds, 0)
        lock.lock()
        guard !didStop else {
            lock.unlock()
            return
        }
        lastPositionSeconds = position
        let shouldReport = didStart && (
            force
                || abs(position - lastReportedPositionSeconds) >= progressIntervalSeconds
                || lastPausedState != isPaused
        )
        if shouldReport {
            lastReportedPositionSeconds = position
            lastPausedState = isPaused
            pendingEvents.append(.progressed(positionSeconds: position, isPaused: isPaused))
        }
        lock.unlock()
        if shouldReport {
            deliverPendingEvents()
        }
    }

    func stopped(failed: Bool = false, positionSeconds: Double? = nil) {
        defer { releasePreparedResources() }
        lock.lock()
        guard !didStop else {
            lock.unlock()
            return
        }
        didStop = true
        guard didStart else {
            lock.unlock()
            return
        }
        if let positionSeconds, positionSeconds.isFinite, positionSeconds >= 0 {
            lastPositionSeconds = positionSeconds
        }
        let position = lastPositionSeconds
        pendingEvents.append(.stopped(positionSeconds: position, failed: failed))
        lock.unlock()
        deliverPendingEvents()
    }

    private func deliverPendingEvents() {
        lock.lock()
        guard !deliveringEvents else { lock.unlock(); return }
        deliveringEvents = true
        while let event = pendingEvents.next() {
            lock.unlock()
            eventHandler(event)
            lock.lock()
        }
        deliveringEvents = false
        lock.unlock()
    }
}

enum MediaPlaybackSource: String {
    case directURL = "direct"
    case dsmFile = "dsmFile"
    case jellyfin
}

private final class MediaProbeTrustDelegate: NSObject, URLSessionDelegate {
    let trustedHost: String?
    let allowsSelfSignedCertificates: Bool

    init(trustedHost: String?, allowsSelfSignedCertificates: Bool) {
        self.trustedHost = trustedHost
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trustedHost,
           challenge.protectionSpace.host.caseInsensitiveCompare(trustedHost) != .orderedSame {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard
            allowsSelfSignedCertificates,
            let credential = CertificatePinStore.shared.credential(
                for: challenge,
                expectedHost: trustedHost
            )
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }
}

enum MediaPlaybackProbe {
    static func run(_ playback: MediaPlaybackRequest) async {
        guard
            let scheme = playback.url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return
        }
        let diagnostics = DiagnosticLogStore.shared
        diagnostics.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.probe_started",
            details: baseDetails(for: playback)
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        let delegate = MediaProbeTrustDelegate(
            trustedHost: playback.url.host,
            allowsSelfSignedCertificates: playback.allowsSelfSignedCertificates
        )
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: playback.url)
        request.timeoutInterval = 15
        if playback.fileExtensionHint != "m3u8" {
            request.setValue("bytes=0-1", forHTTPHeaderField: "Range")
        }
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                diagnostics.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.probe_failed",
                    details: baseDetails(for: playback).merging(["error": "nonHTTPResponse"]) { current, _ in current }
                )
                return
            }

            let mimeType = httpResponse.mimeType?.lowercased() ?? "-"
            let looksLikeAPIError = mimeType.contains("json") || mimeType.contains("html")
            let accepted = (200...299).contains(httpResponse.statusCode) && !looksLikeAPIError
            diagnostics.record(
                accepted ? .info : .error,
                categoryKey: "diagnostics.category.media",
                messageKey: accepted
                    ? "diagnostics.media.probe_succeeded"
                    : "diagnostics.media.probe_invalid_response",
                details: baseDetails(for: playback).merging([
                    "status": "\(httpResponse.statusCode)",
                    "mime": mimeType,
                    "contentLength": httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "-",
                    "acceptRanges": httpResponse.value(forHTTPHeaderField: "Accept-Ranges") ?? "-",
                    "contentRange": httpResponse.value(forHTTPHeaderField: "Content-Range") ?? "-",
                    "contentDisposition": normalizedDisposition(
                        httpResponse.value(forHTTPHeaderField: "Content-Disposition")
                    )
                ]) { current, _ in current }
            )
            if accepted,
               playback.fileExtensionHint == "m3u8",
               let playlistData = try? await prefixData(from: bytes, limit: 256 * 1024),
               let playlist = String(data: playlistData, encoding: .utf8),
               let childURL = firstPlaylistURL(in: playlist, relativeTo: playback.url) {
                await probePlaylistChild(
                    childURL,
                    playback: playback,
                    session: session,
                    diagnostics: diagnostics
                )
            }
        } catch is CancellationError {
            return
        } catch {
            let nsError = error as NSError
            diagnostics.record(
                .error,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.probe_failed",
                details: baseDetails(for: playback).merging([
                    "errorDomain": nsError.domain,
                    "errorCode": "\(nsError.code)"
                ]) { current, _ in current }
            )
        }
    }

    static func baseDetails(for playback: MediaPlaybackRequest) -> [String: String] {
        MediaPlaybackCapabilities.current.diagnosticDetails.merging([
            "requestID": String(playback.id.uuidString.prefix(8)),
            "playbackTraceID": playback.playbackTraceID ?? "-",
            "title": playback.title
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: ",", with: "，"),
            "contentKind": {
                switch playback.contentKind {
                case .automatic: return "automatic"
                case .video: return "video"
                case .audio: return "audio"
                case .discImage: return "discImage"
                }
            }(),
            "target": DiagnosticLogStore.redactedURL(playback.networkOriginURL),
            "source": playback.source.rawValue,
            "extension": playback.fileExtensionHint.isEmpty ? "-" : playback.fileExtensionHint,
            "selfSigned": playback.allowsSelfSignedCertificates ? "on" : "off",
            "transport": playback.url.host == "127.0.0.1"
                ? "localRangeProxy"
                : "sourceURL",
            "routePrivate": playback.isPrivateNetworkRoute.map { $0 ? "yes" : "no" } ?? "unknown"
        ]) { _, new in new }
    }

    private static func firstPlaylistURL(in playlist: String, relativeTo baseURL: URL) -> URL? {
        for rawLine in playlist.split(whereSeparator: { $0.isNewline }) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            return URL(string: line, relativeTo: baseURL)?.absoluteURL
        }
        return nil
    }

    private static func probePlaylistChild(
        _ url: URL,
        playback: MediaPlaybackRequest,
        session: URLSession,
        diagnostics: DiagnosticLogStore
    ) async {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        do {
            let (_, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse else { return }
            let mimeType = response.mimeType?.lowercased() ?? "-"
            let accepted = (200...299).contains(response.statusCode)
                && !mimeType.contains("json")
                && !mimeType.contains("html")
            diagnostics.record(
                accepted ? .info : .error,
                categoryKey: "diagnostics.category.media",
                messageKey: accepted
                    ? "diagnostics.media.probe_succeeded"
                    : "diagnostics.media.probe_invalid_response",
                details: baseDetails(for: playback).merging([
                    "stage": "hlsChild",
                    "target": DiagnosticLogStore.redactedURL(url),
                    "status": "\(response.statusCode)",
                    "mime": mimeType,
                    "bytesReceived": "headersOnly"
                ]) { _, new in new }
            )
        } catch {
            let nsError = error as NSError
            diagnostics.record(
                .error,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.probe_failed",
                details: baseDetails(for: playback).merging([
                    "stage": "hlsChild",
                    "target": DiagnosticLogStore.redactedURL(url),
                    "errorDomain": nsError.domain,
                    "errorCode": "\(nsError.code)"
                ]) { _, new in new }
            )
        }
    }

    private static func normalizedDisposition(_ value: String?) -> String {
        guard let value else { return "-" }
        let lowercased = value.lowercased()
        if lowercased.contains("attachment") { return "attachment" }
        if lowercased.contains("inline") { return "inline" }
        return "present"
    }

    private static func prefixData(
        from bytes: URLSession.AsyncBytes,
        limit: Int
    ) async throws -> Data {
        var data = Data()
        data.reserveCapacity(min(limit, 32 * 1024))
        for try await byte in bytes {
            data.append(byte)
            if data.count >= limit { break }
        }
        return data
    }
}

enum MediaPlaybackEngine: Equatable {
    case system
    case compatibility
}

enum MediaPlaybackPolicy {
    private static let systemPreferredExtensions: Set<String> = [
        "m3u8", "mp4", "m4v", "mov", "3gp", "3g2",
        "mp3", "m4a", "aac", "wav", "caf"
    ]

    static var hasCompatibilityEngine: Bool {
#if canImport(MobileVLCKit)
        true
#else
        false
#endif
    }

    static func allowsCompatibilityPlayer(for request: MediaPlaybackRequest) -> Bool {
        guard hasCompatibilityEngine else { return false }
        if request.source == .jellyfin || request.source == .dsmFile { return true }
        return request.fileExtensionHint != "m3u8"
            || request.compatibilityResource != nil
            || request.compatibilityResourceLoader != nil
    }

    static func preferredEngine(for request: MediaPlaybackRequest) -> MediaPlaybackEngine {
        guard allowsCompatibilityPlayer(for: request) else { return .system }
        // Jellyfin HLS is authenticated through the local playlist proxy.
        // Once the playlist is local, AVPlayer is the common native HLS path
        // on both iPhone and iPad: it owns the platform's HLS buffering,
        // hardware decode and rendering behavior. MobileVLCKit remains the
        // bounded fallback when AVPlayer reports an error, a black startup
        // surface or a sustained stall.
        if request.source == .jellyfin,
           request.fileExtensionHint == "m3u8" {
            return .system
        }
        if request.fileExtensionHint == "m3u8",
           allowsSystemPlayer(for: request) {
            return .system
        }
        if request.source == .jellyfin || request.source == .dsmFile {
            return .compatibility
        }
        if request.allowsSelfSignedCertificates {
            return .compatibility
        }
        let fileExtension = request.fileExtensionHint
        guard !fileExtension.isEmpty else { return .system }
        return systemPreferredExtensions.contains(fileExtension) ? .system : .compatibility
    }

    static func allowsSystemPlayer(for request: MediaPlaybackRequest) -> Bool {
        guard !request.allowsSelfSignedCertificates else {
            return false
        }
        let fileExtension = request.fileExtensionHint
        guard fileExtension.isEmpty || systemPreferredExtensions.contains(fileExtension) else {
            return false
        }
        return request.source == .directURL
            || request.source == .dsmFile
            || request.source == .jellyfin
    }

    static func requiresCompatibilityEngine(for request: MediaPlaybackRequest) -> Bool {
        if request.allowsSelfSignedCertificates {
            return true
        }
        if request.source == .jellyfin {
            return hasCompatibilityEngine || request.fileExtensionHint != "m3u8"
        }
        if request.source == .dsmFile, hasCompatibilityEngine { return true }
        let fileExtension = request.fileExtensionHint
        return !fileExtension.isEmpty && !systemPreferredExtensions.contains(fileExtension)
    }

    static func shouldAutomaticallyFallback(for request: MediaPlaybackRequest) -> Bool {
        guard allowsCompatibilityPlayer(for: request) else { return false }
        // Jellyfin HLS is the preferred remote transport and normally uses
        // AVPlayer for PiP/background playback.  Keep MobileVLCKit as a
        // bounded in-place fallback as well: AVPlayer can reject a valid
        // Jellyfin playlist because of a transient child-segment response or
        // a server-specific HLS tag.  Without this branch the player stays
        // black until the cover is dismissed, even though VLC can open the
        // same authenticated playlist.
        if request.source == .jellyfin, request.fileExtensionHint == "m3u8" {
            return true
        }
        return request.fileExtensionHint != "m3u8"
            || request.compatibilityResource != nil
            || request.compatibilityResourceLoader != nil
    }
}

/// Keep the negotiated encoder dimensions consistent with the quality menu.
enum GreenfieldQualityPolicy {
    static func maximumVideoSize(bitrate: Int) -> (width: Int, height: Int) {
        switch bitrate {
        case 25_000_000...: return (3840, 2160)
        case 10_000_000...: return (1920, 1080)
        case 5_000_000...: return (1280, 720)
        default: return (854, 480)
        }
    }
}
