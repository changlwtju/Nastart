import Foundation

enum PlaybackSourceKind: String, Codable, Sendable {
    case jellyfin
    case dsmFile
    case smbFile
    case webDAVFile
    case localFile
    case directURL
    case cloudFile
}

enum PlaybackContentKind: String, Codable, Sendable {
    case automatic
    case video
    case audio
    case discImage
}

enum PlaybackModePreference: String, Codable, Sendable {
    case automatic
    case original
    case compatible
    case system
    case localRemux
    case external
}

enum PlaybackNetworkClass: String, Codable, Sendable {
    case local
    case wifi
    case cellular
    case constrained
    case offline
    case unknown
}

enum PlaybackConnectionAddressKind: String, Codable, Sendable {
    case loopback
    case privateIP
    case publicIP
    case localDomain
    case publicDomain
    case unknown
}

struct PlaybackConnectionContext: Codable, Equatable, Sendable {
    var addressKind: PlaybackConnectionAddressKind
    var scheme: String?
    var host: String?
    var port: Int?

    init(
        addressKind: PlaybackConnectionAddressKind = .unknown,
        scheme: String? = nil,
        host: String? = nil,
        port: Int? = nil
    ) {
        self.addressKind = addressKind
        self.scheme = scheme?.lowercased()
        self.host = host?.lowercased()
        self.port = port
    }

    static func make(url: URL?) -> PlaybackConnectionContext {
        guard let url else { return PlaybackConnectionContext() }
        return PlaybackConnectionContext(
            addressKind: addressKind(for: url.host),
            scheme: url.scheme,
            host: url.host,
            port: url.port
        )
    }

    private static func addressKind(for host: String?) -> PlaybackConnectionAddressKind {
        guard var host = host?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !host.isEmpty else {
            return .unknown
        }

        if host.hasPrefix("[") && host.hasSuffix("]") {
            host.removeFirst()
            host.removeLast()
        }
        host = host.split(separator: "%", maxSplits: 1).first.map(String.init) ?? host

        if host == "localhost" || host == "::1" || host == "127.0.0.1" {
            return .loopback
        }
        if host.hasSuffix(".local") || host.hasSuffix(".lan") {
            return .localDomain
        }

        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        if octets.count == 4,
           let first = Int(octets[0]),
           let second = Int(octets[1]),
           octets.allSatisfy({ Int($0).map { (0...255).contains($0) } ?? false }) {
            let isPrivate = first == 10
                || (first == 169 && second == 254)
                || (first == 172 && (16...31).contains(second))
                || (first == 192 && second == 168)
            return isPrivate ? .privateIP : .publicIP
        }

        if host.contains(":"),
           let firstHextet = host.split(separator: ":").first,
           let value = UInt16(firstHextet, radix: 16) {
            let isPrivate = value & 0xfe00 == 0xfc00 || value & 0xffc0 == 0xfe80
            return isPrivate ? .privateIP : .publicIP
        }

        return .publicDomain
    }
}

struct PlaybackNetworkContext: Codable, Equatable, Sendable {
    var networkClass: PlaybackNetworkClass
    var isPrivateRoute: Bool?
    var estimatedBitrate: Int?
    var isExpensive: Bool
    var isConstrained: Bool

    init(
        networkClass: PlaybackNetworkClass = .unknown,
        isPrivateRoute: Bool? = nil,
        estimatedBitrate: Int? = nil,
        isExpensive: Bool = false,
        isConstrained: Bool = false
    ) {
        self.networkClass = networkClass
        self.isPrivateRoute = isPrivateRoute
        self.estimatedBitrate = estimatedBitrate
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }
}

struct PlaybackItemIdentity: Codable, Equatable, Hashable, Sendable {
    var sourceKind: PlaybackSourceKind
    var serverID: String?
    var itemID: String?
    var mediaSourceID: String?
    var stablePath: String?

    init(
        sourceKind: PlaybackSourceKind,
        serverID: String? = nil,
        itemID: String? = nil,
        mediaSourceID: String? = nil,
        stablePath: String? = nil
    ) {
        self.sourceKind = sourceKind
        self.serverID = serverID
        self.itemID = itemID
        self.mediaSourceID = mediaSourceID
        self.stablePath = stablePath
    }
}

struct PlaybackIntent: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var requestedAt: Date
    var sourceKind: PlaybackSourceKind
    var contentKind: PlaybackContentKind
    var itemIdentity: PlaybackItemIdentity
    var displayTitle: String
    var directURL: URL?
    var preferredStartTime: TimeInterval?
    var preferredAudioTrackID: String?
    var preferredSubtitleTrackID: String?
    var playbackModePreference: PlaybackModePreference
    var playbackRate: Float
    var connectionContext: PlaybackConnectionContext
    var networkContext: PlaybackNetworkContext

    init(
        id: UUID = UUID(),
        requestedAt: Date = Date(),
        sourceKind: PlaybackSourceKind,
        contentKind: PlaybackContentKind = .automatic,
        itemIdentity: PlaybackItemIdentity,
        displayTitle: String,
        directURL: URL? = nil,
        preferredStartTime: TimeInterval? = nil,
        preferredAudioTrackID: String? = nil,
        preferredSubtitleTrackID: String? = nil,
        playbackModePreference: PlaybackModePreference = .automatic,
        playbackRate: Float = 1,
        connectionContext: PlaybackConnectionContext? = nil,
        networkContext: PlaybackNetworkContext = PlaybackNetworkContext()
    ) {
        self.id = id
        self.requestedAt = requestedAt
        self.sourceKind = sourceKind
        self.contentKind = contentKind
        self.itemIdentity = itemIdentity
        self.displayTitle = displayTitle
        self.directURL = directURL
        self.preferredStartTime = preferredStartTime.map { max($0, 0) }
        self.preferredAudioTrackID = preferredAudioTrackID
        self.preferredSubtitleTrackID = preferredSubtitleTrackID
        self.playbackModePreference = playbackModePreference
        self.playbackRate = min(max(playbackRate, 0.25), 4)
        self.connectionContext = connectionContext ?? PlaybackConnectionContext.make(url: directURL)
        self.networkContext = networkContext
    }
}
