import Foundation
import UIKit
import Network

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
        return mediaExtensions.contains(url.pathExtension.lowercased())
            || mediaExtensions.contains { normalizedURL.contains(".\($0)?") }
    }
}

struct PlaybackNetworkSnapshot: Sendable {
    let cacheKey: String
    let bitrateCap: Int?
    let fallbackBitrate: Int
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

final class PlaybackNetworkObserver: @unchecked Sendable {
    static let shared = PlaybackNetworkObserver()

    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var currentSnapshot = PlaybackNetworkSnapshot(
        cacheKey: "unknown",
        bitrateCap: 20_000_000,
        fallbackBitrate: 6_000_000
    )

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let snapshot: PlaybackNetworkSnapshot
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
            self?.lock.lock()
            self?.currentSnapshot = snapshot
            self?.lock.unlock()
        }
        monitor.start(queue: DispatchQueue(label: "com.changliwen.nastart.playback-network"))
    }

    func snapshot() -> PlaybackNetworkSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return currentSnapshot
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

struct MediaPlaybackRequest: Identifiable {
    let id = UUID()
    let requestedAt: Date
    let url: URL
    let title: String
    let allowsSelfSignedCertificates: Bool
    let source: MediaPlaybackSource
    let contentKind: MediaPlaybackContentKind
    let fileExtensionOverride: String?
    let initialPosition: Double?
    let externalSubtitleURL: URL?
    let preferredAudioTrackOrdinal: Int?
    let preferredSubtitleTrackOrdinal: Int?
    let prefersSubtitlesDisabled: Bool
    let initialOrientationMode: PlayerOrientationMode
    let initialPlaybackRate: Float
    let timelineOffsetSeconds: Double
    let totalDurationSeconds: Double?
    let byteLength: Int64?
    let estimatedBitrate: Int?
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
    let selectedSourceAudioTrackID: Int?
    let selectedSourceSubtitleTrackID: Int?
    let sourceTrackRequestLoader: ((Int?, Int?, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?
    let serverSeekRequestLoader: ((Double, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?
    let qualityOptions: [MediaPlaybackQualityOption]
    let selectedQualityID: String?
    let qualityRequestLoader: ((String, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?
    let playbackTraceID: String?

    init(
        requestedAt: Date = Date(),
        url: URL,
        title: String,
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
        totalDurationSeconds: Double? = nil,
        byteLength: Int64? = nil,
        estimatedBitrate: Int? = nil,
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
        playbackTraceID: String? = nil
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
        self.totalDurationSeconds = totalDurationSeconds.flatMap { $0 > 0 ? $0 : nil }
        self.byteLength = byteLength.flatMap { $0 > 0 ? $0 : nil }
        self.estimatedBitrate = estimatedBitrate.flatMap { $0 > 0 ? $0 : nil }
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
    }

    var fileExtensionHint: String {
        if let fileExtensionOverride, !fileExtensionOverride.isEmpty {
            return fileExtensionOverride.lowercased()
        }
        let titleExtension = URL(fileURLWithPath: title).pathExtension.lowercased()
        return titleExtension.isEmpty ? url.pathExtension.lowercased() : titleExtension
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

    private static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "wma",
        "ape", "alac", "aiff", "aif", "amr", "ac3", "dts"
    ]

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
        externalHandoffResource?.url ?? url
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
            totalDurationSeconds: resource.totalDurationSeconds ?? totalDurationSeconds,
            byteLength: byteLength,
            estimatedBitrate: estimatedBitrate,
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
            playbackTraceID: playbackTraceID
        )
    }

    func applyingRuntimePreferences(_ runtimeState: MediaPlaybackRuntimeState) -> MediaPlaybackRequest {
        MediaPlaybackRequest(
            requestedAt: requestedAt,
            url: url,
            title: title,
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
            prefersSubtitlesDisabled: runtimeState.subtitleSelectionKnown
                ? runtimeState.subtitlesDisabled
                : prefersSubtitlesDisabled,
            initialOrientationMode: runtimeState.orientationMode,
            initialPlaybackRate: runtimeState.playbackRate,
            timelineOffsetSeconds: timelineOffsetSeconds,
            totalDurationSeconds: totalDurationSeconds,
            byteLength: byteLength,
            estimatedBitrate: estimatedBitrate,
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
            playbackTraceID: playbackTraceID
        )
    }
}

enum MediaPlaybackTrackingEvent {
    case started(positionSeconds: Double)
    case progressed(positionSeconds: Double, isPaused: Bool)
    case stopped(positionSeconds: Double, failed: Bool)
}

final class MediaPlaybackTracker {
    private let lock = NSLock()
    private let eventHandler: (MediaPlaybackTrackingEvent) -> Void
    private var didStart = false
    private var didStop = false
    private var lastPositionSeconds = 0.0
    private var lastReportedPositionSeconds = -Double.infinity
    private var lastPausedState: Bool?

    init(eventHandler: @escaping (MediaPlaybackTrackingEvent) -> Void) {
        self.eventHandler = eventHandler
    }

    func started(positionSeconds: Double) {
        let position = max(positionSeconds, 0)
        lock.lock()
        guard !didStart, !didStop else {
            lock.unlock()
            return
        }
        didStart = true
        lastPositionSeconds = position
        lastReportedPositionSeconds = position
        lock.unlock()
        eventHandler(.started(positionSeconds: position))
    }

    func progressed(positionSeconds: Double, isPaused: Bool, force: Bool = false) {
        let position = max(positionSeconds, 0)
        lock.lock()
        guard !didStop else {
            lock.unlock()
            return
        }
        lastPositionSeconds = position
        let shouldReport = didStart && (
            force
                || abs(position - lastReportedPositionSeconds) >= 10
                || lastPausedState != isPaused
        )
        if shouldReport {
            lastReportedPositionSeconds = position
            lastPausedState = isPaused
        }
        lock.unlock()
        if shouldReport {
            eventHandler(.progressed(positionSeconds: position, isPaused: isPaused))
        }
    }

    func stopped(failed: Bool = false) {
        lock.lock()
        guard didStart, !didStop else {
            lock.unlock()
            return
        }
        didStop = true
        let position = lastPositionSeconds
        lock.unlock()
        eventHandler(.stopped(positionSeconds: position, failed: failed))
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
