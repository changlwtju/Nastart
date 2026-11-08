import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public enum MediaServiceProduct: String, CaseIterable, Codable, Sendable {
    case jellyfin, emby, plex, navidrome, subsonic, audioStation
    public var title: String {
        switch self {
        case .jellyfin: return "Jellyfin"
        case .emby: return "Emby"
        case .plex: return "Plex"
        case .navidrome: return "Navidrome"
        case .subsonic: return networkL("Subsonic 兼容服务")
        case .audioStation: return "Audio Station"
        }
    }
    public var isMusic: Bool { [.navidrome, .subsonic, .audioStation].contains(self) }
    /// Metadata is only a hint, never authenticated product identity.
    public static func hint(name: String, detail: String = "") -> Self? {
        let text = (name + " " + detail).lowercased()
        for (value, patterns) in [(Self.audioStation, ["audio\\s*station"]), (.jellyfin, ["jellyfin"]), (.emby, ["emby"]),
                                  (.plex, ["plex", "plexmediaserver"]), (.navidrome, ["navidrome"]), (.subsonic, ["subsonic", "opensubsonic"])] {
            for pattern in patterns where text.range(of: "(?<![a-z0-9])(?:" + pattern + ")(?![a-z0-9])", options: .regularExpression) != nil { return value }
        }
        return nil
    }
}

/// Exact origin AND base path. Never discard a query containing credentials and then use its URL.
public struct MediaServiceEndpoint: Hashable, Sendable {
    public let url: URL
    private let key: String
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.key == rhs.key }
    public func hash(into hasher: inout Hasher) { hasher.combine(key) }
    public static func matches(_ a: URL, _ b: URL) -> Bool {
        guard let first = try? Self(a), let second = try? Self(b) else { return false }
        return first == second
    }
    public init(_ url: URL) throws {
        let scope = try WebDAVScope(address: url.absoluteString)
        guard URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath.contains("//") == false,
              scope.baseURL.host?.contains("*") == false else { throw NetworkMediaError.invalidAddress }
        var parts = URLComponents(url: scope.baseURL, resolvingAgainstBaseURL: false)!
        parts.scheme = parts.scheme?.lowercased(); parts.host = parts.host?.lowercased()
        if parts.port == (parts.scheme == "https" ? 443 : 80) { parts.port = nil }
        key = parts.url!.absoluteString
        self.url = url // Keychain and explicit user routes retain their original URL spelling.
    }
}

public struct MediaServiceCandidate: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let hint: MediaServiceProduct
    public let running: Bool?
    public let endpoints: [MediaServiceEndpoint]
    public let savedLoginEndpoints: Set<MediaServiceEndpoint>
    public init(id: String, name: String, hint: MediaServiceProduct, running: Bool?, endpoints: [URL], savedLoginEndpoints: [URL] = []) {
        self.id = id; self.name = String(name.prefix(160)); self.hint = hint; self.running = running
        var seen = Set<MediaServiceEndpoint>()
        self.endpoints = endpoints.compactMap { try? MediaServiceEndpoint($0) }.filter { seen.insert($0).inserted }.prefix(4).map { $0 }
        self.savedLoginEndpoints = Set(savedLoginEndpoints.compactMap { try? MediaServiceEndpoint($0) }).intersection(Set(self.endpoints))
    }
    public var hasSavedLogin: Bool { !savedLoginEndpoints.isEmpty }
}

public enum MediaServiceInventory: String, Sendable { case available, partial, unavailable, cached }
public struct MediaServiceIdentity: Equatable, Sendable {
    public let product: MediaServiceProduct
    /// Subsonic does not promise a stable server ID; nil never enables cross-endpoint merging.
    public let serverID: String?
}
public struct MediaServiceObservation: Equatable, Sendable {
    public enum Reachability: String, Sendable { case notChecked, reachable, unavailable, redirect, invalidResponse }
    public let reachability: Reachability
    public let identity: MediaServiceIdentity?
    public let endpoint: MediaServiceEndpoint?
    public let requiresAuthorization: Bool
    public init(reachability: Reachability, identity: MediaServiceIdentity? = nil, endpoint: MediaServiceEndpoint? = nil, requiresAuthorization: Bool = false) {
        self.reachability = reachability; self.identity = identity; self.endpoint = endpoint; self.requiresAuthorization = requiresAuthorization
    }
    public func conflicts(with candidate: MediaServiceCandidate) -> Bool {
        guard let identity else { return false }
        return identity.product != candidate.hint && !([MediaServiceProduct.navidrome, .subsonic].contains(identity.product) && [.navidrome, .subsonic].contains(candidate.hint))
    }
    /// Only the existing Jellyfin client is integrated. Saved credentials still require validation on entry.
    public func nativeEndpoint(for candidate: MediaServiceCandidate) -> MediaServiceEndpoint? {
        guard candidate.hint == .jellyfin, !conflicts(with: candidate) else { return nil }
        if let endpoint, identity?.product == .jellyfin, candidate.endpoints.contains(endpoint) { return endpoint }
        return candidate.endpoints.first { candidate.savedLoginEndpoints.contains($0) }
    }
}

public enum MediaServiceIdentityParser {
    public static func parse(_ data: Data, family: MediaServiceProduct) throws -> MediaServiceIdentity? {
        guard data.count <= 128 * 1024 else { throw NetworkMediaError.responseTooLarge }
        if family == .plex {
            guard let text = String(data: data, encoding: .utf8), !text.uppercased().contains("<!DOCTYPE"), !text.uppercased().contains("<!ENTITY") else { throw NetworkMediaError.invalidResponse }
            let delegate = PlexIdentityXML(); let parser = XMLParser(data: data)
            parser.shouldResolveExternalEntities = false; parser.delegate = delegate
            guard parser.parse(), delegate.valid, let id = delegate.serverID else { return nil }
            return MediaServiceIdentity(product: .plex, serverID: id)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        func text(_ value: Any?) -> String? {
            guard let value = value as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.utf8.count <= 512,
                  !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
            return value
        }
        if [.jellyfin, .emby].contains(family) {
            guard let id = text(object["Id"]), text(object["Version"]) != nil, let name = text(object["ProductName"])?.lowercased() else { return nil }
            let product: MediaServiceProduct
            switch name { case "jellyfin server", "jellyfin": product = .jellyfin; case "emby server", "emby": product = .emby; default: return nil }
            return MediaServiceIdentity(product: product, serverID: id)
        }
        if [.navidrome, .subsonic].contains(family) {
            guard let response = object["subsonic-response"] as? [String: Any], let status = response["status"] as? String,
                  ["ok", "failed"].contains(status), text(response["version"]) != nil else { return nil }
            // An unauthenticated ping may only expose a protocol error, not a product or stable identity.
            if status == "failed" {
                guard let error = response["error"] as? [String: Any], let code = error["code"] as? Int, [10, 20, 30, 40, 41, 42, 43, 44].contains(code) else { return nil }
            }
            return MediaServiceIdentity(product: text(response["type"])?.lowercased() == "navidrome" ? .navidrome : .subsonic, serverID: nil)
        }
        return nil
    }
}

private final class PlexIdentityXML: NSObject, XMLParserDelegate {
    var valid = false
    var serverID: String?
    private var depth = 0
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        depth += 1
        guard depth == 1, name == "MediaContainer", let id = attributes["machineIdentifier"], !id.isEmpty, id.utf8.count <= 512,
              !id.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }), let version = attributes["version"], !version.isEmpty else { valid = false; parser.abortParsing(); return }
        valid = true; serverID = id
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) { depth -= 1 }
}

public struct PublicMediaServiceResponse: Sendable {
    public let statusCode: Int
    public let data: Data
    public init(statusCode: Int, data: Data) { self.statusCode = statusCode; self.data = data }
}
public protocol PublicMediaServiceTransport: Sendable {
    func send(_ request: URLRequest) async throws -> PublicMediaServiceResponse
}
public struct MediaServiceProbe: Sendable {
    private let transport: any PublicMediaServiceTransport
    public init(transport: any PublicMediaServiceTransport = PublicMediaServiceHTTP()) { self.transport = transport }
    public func inspect(_ candidate: MediaServiceCandidate) async throws -> MediaServiceObservation {
        guard candidate.hint != .audioStation, candidate.running != false else { return .init(reachability: .notChecked) }
        var last = MediaServiceObservation(reachability: .notChecked)
        for endpoint in candidate.endpoints.prefix(2) {
            try Task.checkCancellation()
            let suffix: String
            switch candidate.hint {
            case .jellyfin, .emby: suffix = "System/Info/Public"
            case .plex: suffix = "identity"
            case .navidrome, .subsonic: suffix = "rest/ping.view"
            case .audioStation: return .init(reachability: .notChecked)
            }
            var url = endpoint.url.appendingPathComponent(suffix)
            if [.navidrome, .subsonic].contains(candidate.hint) {
                var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                parts.queryItems = [.init(name: "v", value: "1.16.1"), .init(name: "c", value: "Nastart"), .init(name: "f", value: "json")]; url = parts.url!
            }
            var request = URLRequest(url: url); request.httpMethod = "GET"; request.timeoutInterval = 2
            request.setValue(candidate.hint == .plex ? "application/xml" : "application/json", forHTTPHeaderField: "Accept")
            do {
                let reply = try await transport.send(request)
                try Task.checkCancellation()
                if (300..<400).contains(reply.statusCode) { last = .init(reachability: .redirect, endpoint: endpoint); continue }
                guard reply.statusCode == 200 else {
                    last = .init(reachability: .reachable, endpoint: endpoint, requiresAuthorization: [401, 403].contains(reply.statusCode)); continue
                }
                let identity = try MediaServiceIdentityParser.parse(reply.data, family: candidate.hint)
                last = .init(reachability: .reachable, identity: identity, endpoint: endpoint,
                             requiresAuthorization: [.navidrome, .subsonic].contains(candidate.hint))
                if identity != nil { return last }
            } catch is CancellationError { throw CancellationError() }
            catch { last = .init(reachability: .unavailable, endpoint: endpoint) }
        }
        return last
    }
}

/// Protect publication when a new account, inventory or foreground round replaces an old one.
public struct MediaServiceResults: Sendable {
    public private(set) var values: [String: MediaServiceObservation] = [:]
    private var round = UUID()
    public init() {}
    public mutating func begin() -> UUID { round = UUID(); values = [:]; return round }
    public mutating func stop() { round = UUID() }
    @discardableResult public mutating func accept(_ value: MediaServiceObservation, id: String, round: UUID) -> Bool {
        guard round == self.round else { return false }
        values[id] = value; return true
    }
}

public enum MediaServiceCatalog {
    /// Merge only identical nonempty endpoint sets and product hints. Aliases need verified server identity.
    public static func coalesced(_ candidates: [MediaServiceCandidate]) -> [MediaServiceCandidate] {
        var result: [MediaServiceCandidate] = []
        let conflicts = Set(Dictionary(grouping: candidates, by: \.id).compactMap { id, group -> String? in
            guard let first = group.first else { return nil }
            return group.contains { $0.hint != first.hint || Set($0.endpoints) != Set(first.endpoints) } ? id : nil
        })
        for candidate in candidates.filter({ !conflicts.contains($0.id) }).sorted(by: { $0.id < $1.id }) {
            if let index = result.firstIndex(where: { $0.hint == candidate.hint && !$0.endpoints.isEmpty && Set($0.endpoints) == Set(candidate.endpoints) }) {
                let old = result[index]
                result[index] = MediaServiceCandidate(id: old.id, name: old.name, hint: old.hint,
                    running: old.running == true || candidate.running == true ? true : (old.running == false && candidate.running == false ? false : nil),
                    endpoints: (old.endpoints + candidate.endpoints).map(\.url),
                    savedLoginEndpoints: Array(old.savedLoginEndpoints.union(candidate.savedLoginEndpoints)).map(\.url))
            } else { result.append(candidate) }
        }
        return result
    }
}
