import Foundation

enum PlaybackRouteKind: String, Codable, Sendable {
    case directHTTP
    case localRangeProxy
    case serverHLS
    case localHLS
    case localFile
    case remuxedHLS
}

enum PlaybackMethod: String, Codable, Sendable {
    case directPlay
    case directStream
    case serverTranscode
    case localRemux
}

enum PlaybackCertificatePolicy: String, Codable, Sendable {
    case systemTrust
    case allowPinnedSelfSigned
    case localLoopback
}

enum PlaybackRangeCapability: String, Codable, Sendable {
    case supported
    case unsupported
    case unknown
}

struct PlaybackCodecSummary: Codable, Equatable, Sendable {
    var container: String?
    var videoCodec: String?
    var audioCodec: String?
    var subtitleCodec: String?
    var bitrate: Int?
    var width: Int?
    var height: Int?
    var framesPerSecond: Double?
    var dynamicRange: String?

    init(
        container: String? = nil,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        subtitleCodec: String? = nil,
        bitrate: Int? = nil,
        width: Int? = nil,
        height: Int? = nil,
        framesPerSecond: Double? = nil,
        dynamicRange: String? = nil
    ) {
        self.container = container
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.subtitleCodec = subtitleCodec
        self.bitrate = bitrate
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
        self.dynamicRange = dynamicRange
    }
}

struct PlaybackRoute: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var routeKind: PlaybackRouteKind
    var playMethod: PlaybackMethod
    var url: URL
    var originURL: URL
    var headers: [String: String]
    var certificatePolicy: PlaybackCertificatePolicy
    var containerHint: String?
    var mimeHint: String?
    var duration: TimeInterval?
    var byteLength: Int64?
    var rangeCapability: PlaybackRangeCapability
    var codecSummary: PlaybackCodecSummary

    init(
        id: UUID = UUID(),
        routeKind: PlaybackRouteKind,
        playMethod: PlaybackMethod,
        url: URL,
        originURL: URL? = nil,
        headers: [String: String] = [:],
        certificatePolicy: PlaybackCertificatePolicy = .systemTrust,
        containerHint: String? = nil,
        mimeHint: String? = nil,
        duration: TimeInterval? = nil,
        byteLength: Int64? = nil,
        rangeCapability: PlaybackRangeCapability = .unknown,
        codecSummary: PlaybackCodecSummary = PlaybackCodecSummary()
    ) {
        self.id = id
        self.routeKind = routeKind
        self.playMethod = playMethod
        self.url = url
        self.originURL = originURL ?? url
        self.headers = headers
        self.certificatePolicy = certificatePolicy
        self.containerHint = containerHint
        self.mimeHint = mimeHint
        self.duration = duration.flatMap { $0 > 0 ? $0 : nil }
        self.byteLength = byteLength.flatMap { $0 > 0 ? $0 : nil }
        self.rangeCapability = rangeCapability
        self.codecSummary = codecSummary
    }
}
