import CryptoKit
import Foundation

struct StoredAgentConnection: Codable, Equatable {
    let baseURLString: String
    let agentID: String
    let token: String
    let hostIdentity: String
    let providerHint: String
    let capabilities: [String]
    let allowsSelfSignedCertificates: Bool
    let pairedAt: Date

    var baseURL: URL? {
        URL(string: baseURLString)
    }
}

enum AgentHealthState: String, Codable, Equatable {
    case connected
    case stale
    case failed
}

struct AgentHealthSnapshot: Codable, Equatable {
    static let staleInterval: TimeInterval = 15 * 60

    let agentID: String
    let hostIdentity: String
    let providerHint: String
    let agentVersion: String?
    let apiVersion: Int?
    let capabilities: [String]
    let lastSeenAt: Date?
    let failureReasonKey: String?

    var state: AgentHealthState {
        if failureReasonKey != nil { return .failed }
        guard let lastSeenAt else { return .stale }
        return Date().timeIntervalSince(lastSeenAt) >= Self.staleInterval ? .stale : .connected
    }

    var isExpired: Bool {
        state == .stale
    }

    init(handshake: AgentHandshake, seenAt: Date = Date()) {
        agentID = handshake.agentId
        hostIdentity = handshake.hostIdentity
        providerHint = handshake.providerHint
        agentVersion = handshake.agentVersion
        apiVersion = handshake.apiVersion
        capabilities = handshake.capabilities
        lastSeenAt = seenAt
        failureReasonKey = nil
    }

    init(connection: StoredAgentConnection, failure: AgentClientError) {
        agentID = connection.agentID
        hostIdentity = connection.hostIdentity
        providerHint = connection.providerHint
        agentVersion = nil
        apiVersion = nil
        capabilities = connection.capabilities
        lastSeenAt = nil
        failureReasonKey = failure.healthReasonKey
    }
}

struct AgentHandshake: Decodable {
    let agentId: String
    let apiVersion: Int
    let agentVersion: String
    let hostIdentity: String
    let providerHint: String
    let permissionLevel: String
    let capabilities: [String]
    let containerCount: Int
    let timestamp: Int
}

private struct AgentPairResponse: Decodable {
    let token: String
    let agentId: String
    let hostIdentity: String
    let providerHint: String
    let capabilities: [String]
}

struct AgentSnapshot: Decodable {
    struct Host: Decodable {
        struct Memory: Decodable {
            let totalBytes: Double
            let usedBytes: Double
        }

        struct Storage: Decodable {
            let totalBytes: Double
            let usedBytes: Double
            let freeBytes: Double
        }

        let hostname: String
        let platform: String
        let platformRelease: String
        let architecture: String
        let loadAverage: [Double]
        let memory: Memory?
        let storage: Storage
    }

    struct Container: Decodable {
        struct Endpoint: Decodable {
            let scheme: String
            let port: Int
        }

        let id: String
        let name: String
        let image: String
        let state: String
        let status: String
        let ports: [String]
        let endpoints: [Endpoint]
    }

    struct Inventory: Decodable {
        let dockerAvailable: Bool
        let dockerError: String?
    }

    let agentId: String
    let apiVersion: Int
    let agentVersion: String
    let timestamp: Int
    let host: Host
    let containers: [Container]
    let inventory: Inventory
}

enum AgentClientError: LocalizedError {
    case invalidAddress
    case insecureAddress
    case invalidResponse
    case pairingRejected
    case unauthorized
    case unsupportedAPIVersion

    var healthReasonKey: String {
        switch self {
        case .unauthorized, .pairingRejected:
            return "agent.health.auth_failed"
        case .unsupportedAPIVersion:
            return "agent.health.unsupported"
        case .invalidAddress, .insecureAddress:
            return "agent.health.invalid_address"
        case .invalidResponse:
            return "agent.health.unreachable"
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidAddress: return NSLocalizedString("agent.error.invalid_address", comment: "")
        case .insecureAddress: return NSLocalizedString("agent.error.insecure_address", comment: "")
        case .invalidResponse: return NSLocalizedString("agent.error.invalid_response", comment: "")
        case .pairingRejected: return NSLocalizedString("agent.error.pairing_rejected", comment: "")
        case .unauthorized: return NSLocalizedString("agent.error.unauthorized", comment: "")
        case .unsupportedAPIVersion: return NSLocalizedString("agent.error.unsupported_version", comment: "")
        }
    }
}

final class AgentClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, allowsSelfSignedCertificates: Bool) throws {
        guard
            let scheme = baseURL.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = baseURL.host,
            !host.isEmpty,
            baseURL.user == nil,
            baseURL.password == nil,
            baseURL.query == nil,
            baseURL.fragment == nil,
            baseURL.port.map { (1...65_535).contains($0) } ?? true
        else {
            throw AgentClientError.invalidAddress
        }
        guard scheme == "https" || NetworkHostClassifier.isPrivate(host) else {
            throw AgentClientError.insecureAddress
        }
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        if scheme == "https", allowsSelfSignedCertificates {
            session = URLSession(
                configuration: configuration,
                delegate: AgentCertificateTrustDelegate(expectedHost: host),
                delegateQueue: nil
            )
        } else {
            session = URLSession(configuration: configuration)
        }
    }

    func pair(code: String, allowsSelfSignedCertificates: Bool) async throws -> StoredAgentConnection {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCode.count == 6, normalizedCode.allSatisfy(\.isNumber) else {
            throw AgentClientError.pairingRejected
        }
        var request = URLRequest(url: try endpoint("/v1/pair"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["code": normalizedCode])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AgentClientError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw http.statusCode == 401 ? AgentClientError.pairingRejected : AgentClientError.invalidResponse
        }
        let payload = try JSONDecoder().decode(AgentPairResponse.self, from: data)
        return StoredAgentConnection(
            baseURLString: baseURL.absoluteString,
            agentID: payload.agentId,
            token: payload.token,
            hostIdentity: payload.hostIdentity,
            providerHint: payload.providerHint,
            capabilities: payload.capabilities,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            pairedAt: Date()
        )
    }

    func handshake(connection: StoredAgentConnection) async throws -> AgentHandshake {
        let data = try await authenticatedData(path: "/v1/handshake", connection: connection)
        let handshake = try JSONDecoder().decode(AgentHandshake.self, from: data)
        guard handshake.apiVersion == 1 else {
            throw AgentClientError.unsupportedAPIVersion
        }
        guard handshake.agentId == connection.agentID else {
            throw AgentClientError.unauthorized
        }
        return handshake
    }

    func snapshot(connection: StoredAgentConnection) async throws -> AgentSnapshot {
        let data = try await authenticatedData(path: "/v1/snapshot", connection: connection)
        let snapshot = try JSONDecoder().decode(AgentSnapshot.self, from: data)
        guard snapshot.apiVersion == 1, snapshot.agentId == connection.agentID else {
            throw AgentClientError.unsupportedAPIVersion
        }
        return snapshot
    }

    private func authenticatedData(path: String, connection: StoredAgentConnection) async throws -> Data {
        var request = URLRequest(url: try endpoint(path))
        request.setValue("Bearer \(connection.token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AgentClientError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw http.statusCode == 401 ? AgentClientError.unauthorized : AgentClientError.invalidResponse
        }
        return data
    }

    private func endpoint(_ path: String) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw AgentClientError.invalidAddress
        }
        let baseSegments = components.path.split(separator: "/", omittingEmptySubsequences: true)
        let childSegments = path.split(separator: "/", omittingEmptySubsequences: true)
        components.path = "/" + (baseSegments + childSegments).joined(separator: "/")
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw AgentClientError.invalidAddress }
        return url
    }
}

private final class AgentCertificateTrustDelegate: NSObject, URLSessionTaskDelegate {
    private let expectedHost: String

    init(expectedHost: String) {
        self.expectedHost = expectedHost
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let credential = CertificatePinStore.shared.credential(
            for: challenge,
            expectedHost: expectedHost
        ) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }
}

enum AgentSnapshotMerger {
    static func merge(
        dsm: DSMDataSnapshot,
        agent: AgentSnapshot,
        agentBaseURL: URL,
        health: AgentHealthSnapshot
    ) -> DSMDataSnapshot {
        let agentContainers = agent.containers.map(container(from:))
        let agentServices = services(from: agent, baseURL: agentBaseURL)
        var mergedServices = dsm.services
        for agentService in agentServices {
            guard let index = mergedServices.firstIndex(where: { matches($0, agentService) }) else {
                mergedServices.append(agentService)
                continue
            }
            mergedServices[index] = enrichedService(mergedServices[index], with: agentService)
        }
        let memory = agent.host.memory.map { memory in
            memory.totalBytes > 0 ? memory.usedBytes / memory.totalBytes : 0
        }
        let storage = agent.host.storage.totalBytes > 0
            ? agent.host.storage.usedBytes / agent.host.storage.totalBytes
            : 0
        let device = NASDevice(
            id: dsm.device.id,
            name: dsm.device.name,
            subtitle: dsm.device.subtitle,
            model: dsm.device.model,
            dsmVersion: dsm.device.dsmVersion,
            mode: .dsmWithAgent,
            cpu: dsm.device.cpu,
            memory: memory ?? dsm.device.memory,
            memoryUsedText: agent.host.memory.map { byteText($0.usedBytes) } ?? dsm.device.memoryUsedText,
            memoryTotalText: agent.host.memory.map { byteText($0.totalBytes) } ?? dsm.device.memoryTotalText,
            storageUsed: storage,
            storageUsedText: byteText(agent.host.storage.usedBytes),
            storageTotalText: byteText(agent.host.storage.totalBytes),
            storageFreeText: byteText(agent.host.storage.freeBytes),
            uptimeMinutes: dsm.device.uptimeMinutes,
            temperatureText: dsm.device.temperatureText,
            certificate: dsm.device.certificate,
            sshStatus: dsm.device.sshStatus
        )
        return DSMDataSnapshot(
            device: device,
            services: mergedServices,
            containers: agent.inventory.dockerAvailable ? agentContainers : dsm.containers,
            files: dsm.files,
            tasks: dsm.tasks,
            videoLibraryItems: dsm.videoLibraryItems,
            audioLibraryItems: dsm.audioLibraryItems,
            discoveredDevices: dsm.discoveredDevices,
            containerInventoryAvailable: agent.inventory.dockerAvailable || dsm.containerInventoryAvailable,
            packageInventoryAvailable: dsm.packageInventoryAvailable,
            reverseProxyInventoryAvailable: dsm.reverseProxyInventoryAvailable,
            agentHealth: health
        )
    }

    private static func container(from source: AgentSnapshot.Container) -> DockerContainer {
        DockerContainer(
            id: stableUUID("agent-container|\(source.id)"),
            name: source.name,
            image: source.image,
            status: source.state.lowercased() == "running" ? .online : .offline,
            cpu: nil,
            memoryText: "-",
            memoryBytes: nil,
            memoryPercent: nil,
            ports: source.ports
        )
    }

    private static func services(from snapshot: AgentSnapshot, baseURL: URL) -> [LaunchpadService] {
        snapshot.containers.compactMap { container in
            guard let endpoint = container.endpoints.first,
                  var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
                return nil
            }
            components.scheme = endpoint.scheme
            components.port = endpoint.port
            components.path = ""
            components.query = nil
            components.fragment = nil
            guard
                let url = components.url,
                UserConfiguredServiceURLPolicy.allows(url)
            else { return nil }
            let category = serviceCategory(name: container.name, image: container.image)
            return LaunchpadService(
                id: stableUUID("agent-service|\(container.id)|\(endpoint.port)"),
                name: container.name,
                iconText: String(container.name.prefix(3)).uppercased(),
                category: category,
                status: container.state.lowercased() == "running" ? .online : .offline,
                subtitle: container.image,
                detail: "Agent · \(endpoint.port)",
                isMedia: category == .media,
                cpu: nil,
                memoryText: nil,
                ports: container.ports,
                endpoint: url,
                source: .container
            )
        }
    }

    private static func matches(_ lhs: LaunchpadService, _ rhs: LaunchpadService) -> Bool {
        if lhs.name.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(rhs.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame {
            return true
        }
        guard
            let lhsEndpoint = lhs.endpoint,
            let rhsEndpoint = rhs.endpoint,
            lhsEndpoint.host?.lowercased() == rhsEndpoint.host?.lowercased(),
            lhsEndpoint.port == rhsEndpoint.port
        else {
            return false
        }
        return true
    }

    private static func enrichedService(
        _ existing: LaunchpadService,
        with agent: LaunchpadService
    ) -> LaunchpadService {
        LaunchpadService(
            id: existing.id,
            name: existing.name,
            iconText: existing.iconText,
            category: existing.category,
            status: agent.status,
            subtitle: existing.subtitle.isEmpty ? agent.subtitle : existing.subtitle,
            detail: existing.detail.isEmpty ? agent.detail : existing.detail,
            isMedia: existing.isMedia || agent.isMedia,
            cpu: agent.cpu ?? existing.cpu,
            memoryText: agent.memoryText ?? existing.memoryText,
            memory: agent.memory ?? existing.memory,
            ports: Array(Set(existing.ports + agent.ports)).sorted(),
            iconURL: existing.iconURL ?? agent.iconURL,
            endpoint: existing.endpoint ?? agent.endpoint,
            alternateEndpoint: existing.alternateEndpoint ?? agent.alternateEndpoint,
            source: existing.source,
            isLaunchpadVisible: existing.isLaunchpadVisible
        )
    }

    private static func serviceCategory(name: String, image: String) -> ServiceCategory {
        let value = "\(name) \(image)".lowercased()
        if ["jellyfin", "plex", "emby", "navidrome", "immich"].contains(where: value.contains) {
            return .media
        }
        if ["download", "qbittorrent", "transmission", "aria"].contains(where: value.contains) {
            return .downloads
        }
        if ["adguard", "dns", "proxy", "traefik", "nginx"].contains(where: value.contains) {
            return .network
        }
        return .tools
    }

    private static func stableUUID(_ value: String) -> UUID {
        let hex = SHA256.hash(data: Data(value.utf8))
            .prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
        let uuidString = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private static func byteText(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(max(value, 0)), countStyle: .file)
    }
}

extension DSMDataSnapshot {
    func withAgentHealth(_ health: AgentHealthSnapshot) -> DSMDataSnapshot {
        DSMDataSnapshot(
            device: device,
            services: services,
            containers: containers,
            files: files,
            tasks: tasks,
            videoLibraryItems: videoLibraryItems,
            audioLibraryItems: audioLibraryItems,
            discoveredDevices: discoveredDevices,
            containerInventoryAvailable: containerInventoryAvailable,
            packageInventoryAvailable: packageInventoryAvailable,
            reverseProxyInventoryAvailable: reverseProxyInventoryAvailable,
            agentHealth: health
        )
    }
}
