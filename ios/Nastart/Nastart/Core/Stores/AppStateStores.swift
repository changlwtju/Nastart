import Foundation
import Combine
import CryptoKit
import Security
import UserNotifications
import Darwin

enum DSMURLBuilder {
    static func url(baseURL: URL, appending path: String) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let baseSegments = components.path.split(separator: "/", omittingEmptySubsequences: true)
        let pathSegments = path.split(separator: "/", omittingEmptySubsequences: true)
        components.path = "/" + (baseSegments + pathSegments).joined(separator: "/")
        components.query = nil
        components.fragment = nil
        return components.url
    }
}

final class CertificatePinStore {
    static let shared = CertificatePinStore()

    private let service = "com.nastart.app.certificate-pins"
    private let certificateService = "com.nastart.app.trusted-certificates"
    private let account = "trusted-hosts"
    private let lock = NSLock()

    private init() {}

    func credential(
        for challenge: URLAuthenticationChallenge,
        expectedHost: String?
    ) -> URLCredential? {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            challenge.protectionSpace.host.caseInsensitiveCompare(expectedHost ?? "") == .orderedSame,
            let trust = challenge.protectionSpace.serverTrust,
            let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
            let leafCertificate = certificates.first
        else {
            return nil
        }

        let certificateData = SecCertificateCopyData(leafCertificate) as Data
        let fingerprint = SHA256.hash(data: certificateData)
            .map { String(format: "%02x", $0) }
            .joined()
        let key = "\(challenge.protectionSpace.host.lowercased()):\(challenge.protectionSpace.port)"

        lock.lock()
        defer { lock.unlock() }
        var pins = loadPins()
        if let storedFingerprint = pins[key] {
            if storedFingerprint != fingerprint {
                pins[key] = fingerprint
                guard savePins(pins) else { return nil }
                DiagnosticLogStore.shared.record(
                    .warning,
                    categoryKey: "diagnostics.category.connection",
                    messageKey: "diagnostics.certificate.pin_rotated",
                    details: ["target": "\(challenge.protectionSpace.host):\(challenge.protectionSpace.port)"]
                )
            }
        } else {
            pins[key] = fingerprint
            guard savePins(pins) else { return nil }
        }
        if SecTrustEvaluateWithError(trust, nil) {
            deleteCertificate(key: key)
        } else {
            saveCertificate(certificateData, key: key)
        }
        return URLCredential(trust: trust)
    }

    func trustedCertificateData(host: String?, port: Int?) -> Data? {
        guard let host, !host.isEmpty else { return nil }
        let key = "\(host.lowercased()):\(port ?? 443)"
        var query = certificateQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        SecItemDelete(baseQuery() as CFDictionary)
        let certificatesQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: certificateService
        ]
        SecItemDelete(certificatesQuery as CFDictionary)
    }

    private func loadPins() -> [String: String] {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data,
            let pins = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return pins
    }

    private func savePins(_ pins: [String: String]) -> Bool {
        guard let data = try? JSONEncoder().encode(pins) else { return false }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let query = baseQuery()
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var item = query
        attributes.forEach { item[$0.key] = $0.value }
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    private func saveCertificate(_ data: Data, key: String) {
        let query = certificateQuery(key: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard updateStatus == errSecItemNotFound else { return }
        var item = query
        attributes.forEach { item[$0.key] = $0.value }
        SecItemAdd(item as CFDictionary, nil)
    }

    private func deleteCertificate(key: String) {
        SecItemDelete(certificateQuery(key: key) as CFDictionary)
    }

    private func certificateQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: certificateService,
            kSecAttrAccount as String: key
        ]
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

protocol AppDataProviding {
    var device: NASDevice { get }
    var services: [LaunchpadService] { get }
    var containers: [DockerContainer] { get }
    var files: [FileItem] { get }
    var tasks: [TaskItem] { get }
    var videoLibraryItems: [MediaItem] { get }
    var audioLibraryItems: [MediaItem] { get }
    var discoveredDevices: [DiscoveredNASDevice] { get }
    var agentHealth: AgentHealthSnapshot? { get }
}

enum NASDataSourceKind: Equatable {
    case mock
    case dsm
    case agent
}

enum AppDataRefreshState: Equatable {
    case localPreview
    case refreshing
    case current
    case cached
    case stale
    case unavailable
}

protocol NASDataSource {
    var kind: NASDataSourceKind { get }
    func loadSnapshot() async -> AppDataProviding
}

struct MockNASDataSource: NASDataSource {
    let kind: NASDataSourceKind = .mock

    func loadSnapshot() async -> AppDataProviding {
        MockAppDataProvider()
    }
}

struct DisconnectedNASDataSource: NASDataSource {
    let kind: NASDataSourceKind = .mock

    func loadSnapshot() async -> AppDataProviding {
        DisconnectedAppDataProvider()
    }
}

struct DSMNASDataSource: NASDataSource {
    let session: DSMSession
    let client: DSMClient
    let useAgent: Bool

    var kind: NASDataSourceKind {
        .dsm
    }

    init(session: DSMSession, useAgent: Bool) {
        self.session = session
        self.useAgent = useAgent
        self.client = DSMClient(
            baseURL: session.baseURL,
            allowsSelfSignedCertificates: session.allowsSelfSignedCertificates
        )
    }

    func loadSnapshot() async -> AppDataProviding {
        let dsmSnapshot = await client.loadSnapshot(session: session, useAgent: false)
        guard
            useAgent,
            let connection = KeychainStore.shared.loadAgentConnection(),
            let baseURL = connection.baseURL
        else {
            return dsmSnapshot
        }
        do {
            let agentClient = try AgentClient(
                baseURL: baseURL,
                allowsSelfSignedCertificates: connection.allowsSelfSignedCertificates
            )
            let handshake = try await agentClient.handshake(connection: connection)
            let agentSnapshot = try await agentClient.snapshot(connection: connection)
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.agent",
                messageKey: "diagnostics.agent.refresh_succeeded",
                details: [
                    "containers": "\(agentSnapshot.containers.count)",
                    "host": DiagnosticLogStore.redactedHost(baseURL.host)
                ]
            )
            return AgentSnapshotMerger.merge(
                dsm: dsmSnapshot,
                agent: agentSnapshot,
                agentBaseURL: baseURL,
                health: AgentHealthSnapshot(handshake: handshake)
            )
        } catch let error as AgentClientError {
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.agent",
                messageKey: "diagnostics.agent.refresh_failed",
                details: ["error": String(describing: error)]
            )
            return dsmSnapshot.withAgentHealth(AgentHealthSnapshot(connection: connection, failure: error))
        } catch {
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.agent",
                messageKey: "diagnostics.agent.refresh_failed",
                details: ["error": String(describing: error)]
            )
            return dsmSnapshot.withAgentHealth(
                AgentHealthSnapshot(connection: connection, failure: .invalidResponse)
            )
        }
    }

    func isReachable() async -> Bool {
        await client.isDSMEndpoint()
    }

    func loadFolder(path: String) async throws -> [FileItem] {
        try await client.listFolder(session: session, folderPath: path)
    }
}

protocol NASDeviceProviding {
    func loadDevice() -> NASDevice
    func discoverDevices() -> [DiscoveredNASDevice]
}

protocol LaunchpadServiceProviding {
    func loadServices() -> [LaunchpadService]
}

protocol DockerProviding {
    func loadContainers() -> [DockerContainer]
}

protocol FileSystemProviding {
    func loadFiles() -> [FileItem]
}

protocol MediaLibraryProviding {
    func loadVideoLibraryItems() -> [MediaItem]
    func loadAudioLibraryItems() -> [MediaItem]
}

protocol ReminderProviding {
    func loadTasks() -> [TaskItem]
}

struct MockAppDataProvider: AppDataProviding, NASDeviceProviding, LaunchpadServiceProviding, DockerProviding, FileSystemProviding, MediaLibraryProviding, ReminderProviding {
    let device = SampleData.device
    let services = SampleData.services
    let containers = SampleData.containers
    let files = SampleData.files
    let tasks = SampleData.tasks
    let videoLibraryItems = SampleData.videoLibraryItems
    let audioLibraryItems = SampleData.audioLibraryItems
    let discoveredDevices: [DiscoveredNASDevice] = []
    let agentHealth: AgentHealthSnapshot? = nil

    func loadDevice() -> NASDevice { device }
    func discoverDevices() -> [DiscoveredNASDevice] { discoveredDevices }
    func loadServices() -> [LaunchpadService] { services }
    func loadContainers() -> [DockerContainer] { containers }
    func loadFiles() -> [FileItem] { files }
    func loadVideoLibraryItems() -> [MediaItem] { videoLibraryItems }
    func loadAudioLibraryItems() -> [MediaItem] { audioLibraryItems }
    func loadTasks() -> [TaskItem] { tasks }
}

struct DisconnectedAppDataProvider: AppDataProviding {
    let device = NASDevice(
        id: UUID(),
        name: "Nastart",
        subtitle: NSLocalizedString("mine.profile.not_connected", comment: ""),
        model: nil,
        dsmVersion: nil,
        mode: .manualOnly,
        cpu: nil,
        memory: nil,
        memoryUsedText: nil,
        memoryTotalText: nil,
        storageUsed: nil,
        storageUsedText: nil,
        storageTotalText: nil,
        storageFreeText: "-",
        uptimeMinutes: nil,
        temperatureText: nil,
        certificate: nil,
        sshStatus: .unavailable
    )
    let services: [LaunchpadService] = []
    let containers: [DockerContainer] = []
    let files: [FileItem] = []
    let tasks: [TaskItem] = []
    let videoLibraryItems: [MediaItem] = []
    let audioLibraryItems: [MediaItem] = []
    let discoveredDevices: [DiscoveredNASDevice] = []
    let agentHealth: AgentHealthSnapshot? = nil
}

enum DSMAuthenticationStage: String {
    case fileStationAttached, fileStationUnavailable, connectionPublished, sourcePrepared
    case logoutStarted, logoutSucceeded, logoutFailed
}

struct DSMSession {
    let baseURL: URL
    let sid: String
    let fileStationSID: String?
    let account: String
    let allowsSelfSignedCertificates: Bool
    let deviceID: String?
    let endpoints: DSMConnectionEndpoints
    let actualRoute: DSMConnectionRoute
    // Local login identities only. Never derive these from authentication data
    // or send them to DSM. Endpoint-only copies retain the original identities.
    let authenticationGeneration: UUID
    let fileStationGeneration: UUID?

    init(
        baseURL: URL,
        sid: String,
        fileStationSID: String?,
        account: String,
        allowsSelfSignedCertificates: Bool,
        deviceID: String?,
        endpoints: DSMConnectionEndpoints? = nil,
        actualRoute: DSMConnectionRoute? = nil,
        authenticationGeneration: UUID = UUID(),
        fileStationGeneration: UUID? = nil
    ) {
        let resolvedEndpoints = endpoints ?? DSMConnectionEndpoints(legacyBaseURL: baseURL)
        self.baseURL = baseURL
        self.sid = sid
        self.fileStationSID = fileStationSID
        self.account = account
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.deviceID = deviceID
        self.authenticationGeneration = authenticationGeneration
        self.fileStationGeneration = fileStationSID == nil ? nil : fileStationGeneration ?? UUID()
        self.endpoints = resolvedEndpoints
        self.actualRoute = actualRoute ?? DSMConnectionRouteResolver.route(
            for: baseURL,
            endpoints: resolvedEndpoints
        )
    }

    var authenticationDiagnosticFields: [String: String] {
        var fields = ["authenticationGeneration": authenticationGeneration.uuidString]
        if let fileStationGeneration { fields["fileStationGeneration"] = fileStationGeneration.uuidString }
        return fields
    }

    var authenticationObservationFields: [String: String] {
        authenticationDiagnosticFields.merging([
            "authenticationObservedMonoMs": String(Int64(ProcessInfo.processInfo.systemUptime * 1_000))]) { _, new in new }
    }

    func recordAuthenticationStage(_ stage: DSMAuthenticationStage) {
        DiagnosticLogStore.shared.record(.info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.connection.session_lifecycle",
            details: authenticationObservationFields.merging(["authenticationStage": stage.rawValue]) { _, new in new })
    }

    func replacingConnection(endpoints: DSMConnectionEndpoints,
                             actualRoute: DSMConnectionRoute? = nil) -> DSMSession {
        DSMSession(baseURL: baseURL, sid: sid, fileStationSID: fileStationSID,
            account: account, allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            deviceID: deviceID, endpoints: endpoints, actualRoute: actualRoute ?? self.actualRoute,
            authenticationGeneration: authenticationGeneration, fileStationGeneration: fileStationGeneration)
    }

    func attachingFileStationSession(_ fileStationSession: DSMSession?) -> DSMSession {
        DSMSession(baseURL: baseURL, sid: sid, fileStationSID: fileStationSession?.sid,
            account: account, allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            deviceID: fileStationSession?.deviceID ?? deviceID, endpoints: endpoints, actualRoute: actualRoute,
            authenticationGeneration: authenticationGeneration,
            fileStationGeneration: fileStationSession?.authenticationGeneration)
    }

    func fileStationOpenURL(path: String) -> URL? {
        // Single-URL callers do not probe or fail over. Keep their endpoint
        // tied to the authenticated DSM session.
        fileStationOpenURL(path: path, baseURL: baseURL)
    }

    func fileStationOpenURLs(path: String) -> [URL] {
        var baseURLs: [URL] = []
        var seenBaseURLs = Set<String>()

        func append(_ url: URL?) {
            guard let url, seenBaseURLs.insert(url.absoluteString).inserted else { return }
            baseURLs.append(url)
        }

        func appendPlaybackVariants(for url: URL?) {
            guard let url else { return }
            if NetworkHostClassifier.isPrivate(url.host) {
                append(LANDiscoveryService.localHTTPVariant(for: url))
            }
            append(url)
        }

        // Playback callers probe each candidate with the File Station SID.
        // A discovered LAN endpoint must be offered even when DSM login used
        // the public domain; otherwise large files hairpin through that route.
        appendPlaybackVariants(for: endpoints.lanAddress)
        appendPlaybackVariants(for: baseURL)
        append(publicAddressCandidate)

        var seen = Set<String>()
        return baseURLs.compactMap { fileStationOpenURL(path: path, baseURL: $0) }
            .filter { seen.insert($0.absoluteString).inserted }
    }

    private var publicAddressCandidate: URL? {
        endpoints.primaryDomain ?? endpoints.publicAddress
    }

    private func fileStationOpenURL(path: String, baseURL: URL) -> URL? {
        guard
            let encodedPaths = try? JSONEncoder().encode([path]),
            let pathParameter = String(data: encodedPaths, encoding: .utf8),
            let encodedMode = try? JSONEncoder().encode("open"),
            let modeParameter = String(data: encodedMode, encoding: .utf8),
            let requestURL = DSMURLBuilder.url(baseURL: baseURL, appending: "/webapi/entry.cgi"),
            var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "api", value: "SYNO.FileStation.Download"),
            URLQueryItem(name: "version", value: "2"),
            URLQueryItem(name: "method", value: "download"),
            URLQueryItem(name: "path", value: pathParameter),
            URLQueryItem(name: "mode", value: modeParameter),
            URLQueryItem(name: "_sid", value: fileStationSID ?? sid)
        ]
        return components.url
    }
}

struct StoredNASCredential: Codable {
    let baseURLString: String
    let account: String
    let password: String
    let useAgent: Bool
    let allowsSelfSignedCertificates: Bool
    let deviceID: String?
    let endpoints: DSMConnectionEndpoints
    let lastKnownRoute: DSMConnectionRoute
    let usesOnlyConfiguredAddress: Bool

    init(
        baseURLString: String,
        account: String,
        password: String,
        useAgent: Bool,
        allowsSelfSignedCertificates: Bool = false,
        deviceID: String? = nil,
        endpoints: DSMConnectionEndpoints? = nil,
        lastKnownRoute: DSMConnectionRoute? = nil,
        usesOnlyConfiguredAddress: Bool = false
    ) {
        self.baseURLString = baseURLString
        self.account = account
        self.password = password
        self.useAgent = useAgent
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.deviceID = deviceID
        self.usesOnlyConfiguredAddress = usesOnlyConfiguredAddress
        let legacyURL = URL(string: baseURLString)
        let resolvedEndpoints = endpoints
            ?? legacyURL.map(DSMConnectionEndpoints.init(legacyBaseURL:))
            ?? DSMConnectionEndpoints()
        self.endpoints = resolvedEndpoints
        self.lastKnownRoute = lastKnownRoute
            ?? legacyURL.map {
                DSMConnectionRouteResolver.route(for: $0, endpoints: resolvedEndpoints)
            }
            ?? .external
    }

    enum CodingKeys: String, CodingKey {
        case baseURLString
        case account
        case password
        case useAgent
        case allowsSelfSignedCertificates
        case deviceID
        case endpoints
        case lastKnownRoute
        case usesOnlyConfiguredAddress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURLString = try container.decode(String.self, forKey: .baseURLString)
        account = try container.decode(String.self, forKey: .account)
        password = try container.decode(String.self, forKey: .password)
        useAgent = try container.decode(Bool.self, forKey: .useAgent)
        allowsSelfSignedCertificates = try container.decodeIfPresent(Bool.self, forKey: .allowsSelfSignedCertificates) ?? false
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID)
        usesOnlyConfiguredAddress = try container.decodeIfPresent(Bool.self, forKey: .usesOnlyConfiguredAddress) ?? false
        let legacyURL = URL(string: baseURLString)
        let decodedEndpoints = try container.decodeIfPresent(DSMConnectionEndpoints.self, forKey: .endpoints)
            ?? legacyURL.map(DSMConnectionEndpoints.init(legacyBaseURL:))
            ?? DSMConnectionEndpoints()
        endpoints = decodedEndpoints
        lastKnownRoute = try container.decodeIfPresent(DSMConnectionRoute.self, forKey: .lastKnownRoute)
            ?? legacyURL.map {
                DSMConnectionRouteResolver.route(for: $0, endpoints: decodedEndpoints)
            }
            ?? .external
    }
}

struct StoredJellyfinSession: Codable {
    let endpointString: String
    let userID: String
    let username: String
    let accessToken: String
}

struct DSMDataSnapshot: AppDataProviding, Codable {
    let device: NASDevice
    let services: [LaunchpadService]
    let containers: [DockerContainer]
    let files: [FileItem]
    let tasks: [TaskItem]
    let videoLibraryItems: [MediaItem]
    let audioLibraryItems: [MediaItem]
    let discoveredDevices: [DiscoveredNASDevice]
    let containerInventoryAvailable: Bool
    let packageInventoryAvailable: Bool
    let reverseProxyInventoryAvailable: Bool
    let agentHealth: AgentHealthSnapshot?
}

/// A session-scoped directory cache. Credentials stay private and are never logged.
/// The random generation also changes on explicit clearing of the same session.
final class DSMFolderCache {
    private struct Identity: Equatable {
        let baseURL: URL
        let account: String
        let sid: String
        let fileStationSID: String?
        let allowsSelfSignedCertificates: Bool

        init(_ session: DSMSession) {
            baseURL = session.baseURL
            account = session.account
            sid = session.sid
            fileStationSID = session.fileStationSID
            allowsSelfSignedCertificates = session.allowsSelfSignedCertificates
        }
    }
    private struct Entry {
        let items: [FileItem]
        let loadedAt: Date
    }
    private struct Pending {
        let id: UUID
        let task: Task<[FileItem], Error>
    }
    private var identity: Identity?
    private static let folderCacheLifetime: TimeInterval = 5 * 60
    private var generation = UUID()
    private var entries: [String: Entry] = [:]
    private var pending: [String: Pending] = [:]

    @MainActor
    @discardableResult
    func prepare(for session: DSMSession?) -> Bool {
        let next = session.map(Identity.init)
        guard next != identity else { return false }
        clear()
        identity = next
        return true
    }

    @MainActor
    func clear() {
        generation = UUID()
        identity = nil
        pending.values.forEach { $0.task.cancel() }
        pending.removeAll()
        entries.removeAll()
    }

    @MainActor
    func freshItems(for path: String) -> [FileItem]? {
        guard let entry = entries[path], Date().timeIntervalSince(entry.loadedAt) < Self.folderCacheLifetime else { return nil }
        return entry.items
    }

    @MainActor
    func load(path: String, operation: @escaping () async throws -> [FileItem]) async throws -> [FileItem] {
        let requestGeneration = generation
        if let existing = pending[path] {
            do {
                let items = try await existing.task.value
                try Task.checkCancellation()
                guard requestGeneration == generation else { throw CancellationError() }
                return items
            } catch {
                guard requestGeneration == generation else { throw CancellationError() }
                throw error
            }
        }
        let staleEntry = entries[path]
        let id = UUID()
        let task = Task { try await operation() }
        pending[path] = Pending(id: id, task: task)
        do {
            let items = try await task.value
            try Task.checkCancellation()
            guard requestGeneration == generation else { throw CancellationError() }
            if pending[path]?.id == id { pending[path] = nil }
            entries[path] = Entry(items: items, loadedAt: Date())
            return items
        } catch {
            // Check the generation BEFORE cleanup: a newer task can use this path.
            guard requestGeneration == generation else { throw CancellationError() }
            if pending[path]?.id == id { pending[path] = nil }
            if error is CancellationError || Task.isCancelled { throw CancellationError() }
            if case DSMClientError.apiFailed(code: 119) = error {
                // A known invalid SID affects every directory in this scope.
                clear()
                throw error
            }
            if let staleEntry { return staleEntry.items }
            throw error
        }
    }
}

/// Owns only the visible directory request; transport/cache work has its own scope.
@MainActor
final class FolderBrowserLoader: ObservableObject {
    @Published private(set) var items: [FileItem] = []
    @Published private(set) var didLoad = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorKey: String?
    @Published private(set) var needsRetry = false
    private(set) var sourceID: UUID?
    private var requestID: UUID?

    func invalidate() {
        requestID = nil
        isLoading = false
        needsRetry = false
    }

    func load(sourceID: UUID, forceRefresh: Bool = false,
              isConnected: () -> Bool,
              operation: () async throws -> [FileItem]) async {
        guard !Task.isCancelled else { return }
        if self.sourceID != sourceID {
            invalidate()
            self.sourceID = sourceID
            items = []
            didLoad = false
            errorKey = nil
        }
        guard forceRefresh || !didLoad else { return }
        let id = UUID()
        requestID = id
        isLoading = true
        errorKey = nil
        needsRetry = false
        do {
            let result = try await operation()
            try Task.checkCancellation()
            guard requestID == id, self.sourceID == sourceID else { return }
            items = result
            didLoad = true
            if result.isEmpty && !isConnected() { errorKey = "devices.files.dsm_disconnected" }
        } catch {
            guard requestID == id, self.sourceID == sourceID else { return }
            if error is CancellationError || Task.isCancelled {
                needsRetry = !didLoad
            } else {
                if case DSMClientError.apiFailed(code: 119) = error {
                    items = []
                    didLoad = false
                }
                errorKey = "devices.files.folder_load_failed"
            }
        }
        guard requestID == id else { return }
        requestID = nil
        isLoading = false
    }
}

/// Injectable I/O for deterministic connection lifecycle tests; live calls retain existing routes.
struct DSMConnectionOperations {
    var currentTime: @MainActor () -> Date = { Date() }
    var isReachable: @MainActor (DSMNASDataSource) async -> Bool = { await $0.isReachable() }
    var loadRefreshSnapshot: @MainActor (DSMNASDataSource) async -> AppDataProviding = { await $0.loadSnapshot() }
    var refreshServiceHealth: @MainActor (AppDataStore) async -> Void = { await $0.refreshServiceHealth() }
    var loadCredential: @MainActor () -> StoredNASCredential? = { KeychainStore.shared.loadNASCredential() }
    var usesAgent: @MainActor () -> Bool = { KeychainStore.shared.loadAgentConnection() != nil }
    var login: @MainActor (StoredNASCredential, DSMConnectionEndpoints) async throws -> DSMLoginResult = { credential, endpoints in
        try await DSMClient.login(endpoints: endpoints,
            allowsSelfSignedCertificates: credential.allowsSelfSignedCertificates,
            account: credential.account, password: credential.password, deviceID: credential.deviceID,
            preferredRoute: credential.lastKnownRoute, prepareConfiguredEndpoints: true)
    }
    var discoverFallback: @MainActor () async -> [URL] = { await LANDiscoveryService.discoverDSMEndpoints() }
    var discoverLAN: @MainActor (URL) async -> URL? = { await AppDataStore.discoverSmartLANAddress(for: $0) }
    var attachFileStation: @MainActor (DSMLoginResult, StoredNASCredential, String) async -> DSMSession = { result, credential, code in
        await result.client.addingFileStationSession(to: result.session, account: credential.account,
            password: credential.password, oneTimeCode: code)
    }
    var loadSnapshot: @MainActor (DSMSession, Bool) async -> AppDataProviding = { session, useAgent in
        await DSMNASDataSource(session: session, useAgent: useAgent).loadSnapshot()
    }
    var saveCredential: @MainActor (StoredNASCredential) throws -> Void = { try KeychainStore.shared.saveNASCredential($0) }
    var logout: @MainActor (DSMSession, NASConnectionStore) async -> Void = { session, connection in
        await DSMClient(baseURL: session.baseURL, allowsSelfSignedCertificates: session.allowsSelfSignedCertificates)
            .logout(session: session, protectingCurrentSession: { connection.dsmSession })
    }
}

enum NASConnectionRecoveryState: Equatable {
    case idle, restoring, failed
}

final class AppDataStore: ObservableObject {
    private static let persistedDSMSnapshotKey = "dsm.cachedSnapshot.v1"
    private static let persistedDSMSnapshotFormatVersion = 2
    private static let cachedSnapshotStaleInterval: TimeInterval = 24 * 60 * 60
    @Published private(set) var device: NASDevice
    @Published private(set) var services: [LaunchpadService]
    @Published private(set) var containers: [DockerContainer]
    @Published private(set) var files: [FileItem]
    @Published private(set) var tasks: [TaskItem]
    @Published private(set) var completedTasks: [TaskItem]
    @Published private(set) var videoLibraryItems: [MediaItem]
    @Published private(set) var audioLibraryItems: [MediaItem]
    @Published private(set) var discoveredDevices: [DiscoveredNASDevice]
    @Published private(set) var isRefreshing = false
    @Published private(set) var connectionRecoveryState: NASConnectionRecoveryState = .idle
    /// Set when DSM refused the saved login, as opposed to being unreachable.
    @Published private(set) var connectionRecoveryRejection: DSMClientError?
    var isRestoringConnection: Bool { connectionRecoveryState == .restoring }
    @Published private(set) var isForegroundRefreshing = false
    @Published private(set) var isDSMReachable = false
    @Published private(set) var serviceHealth: [UUID: ServiceHealthSnapshot] = [:]
    @Published private(set) var cachedDSMSnapshotSavedAt: Date?
    @Published private(set) var agentHealth: AgentHealthSnapshot?
    @Published private(set) var lastRefreshEventAt: Date? = nil
    @Published private(set) var lastRefreshSummaryKey = "data.refresh.ready" {
        didSet {
            lastRefreshEventAt = Date()
        }
    }
    @Published private(set) var sourceKind: NASDataSourceKind
    @Published private(set) var folderSourceID = UUID()
    @Published private(set) var serviceVisibilityOverrides: [String: Bool]
    @Published private(set) var launchpadServiceOrder: [String: [String]]

    /// A previously successful snapshot is safe to render while the session is
    /// being restored. Network refresh still replaces it once available.
    var hasCachedDSMSnapshot: Bool {
        guard let snapshot = provider as? DSMDataSnapshot else { return false }
        return !Self.isProvisionalDSMSnapshot(snapshot)
    }

    var isShowingProvisionalDSMSnapshot: Bool {
        guard let snapshot = provider as? DSMDataSnapshot else { return false }
        return Self.isProvisionalDSMSnapshot(snapshot)
    }

    var isCachedDSMSnapshotStale: Bool {
        guard hasCachedDSMSnapshot, let savedAt = cachedDSMSnapshotSavedAt else {
            return false
        }
        return Date().timeIntervalSince(savedAt) >= Self.cachedSnapshotStaleInterval
    }

    /// The launchpad can render a persisted NAS snapshot before the current
    /// session has finished restoring. This is deliberately a display-only
    /// state: file operations still require `NASConnectionStore.dsmSession`.
    var isDSMAvailableForDisplay: Bool {
        isDSMReachable
    }

    /// A single availability state used by pages that render the same NAS
    /// snapshot. It deliberately separates cached data from live data so an
    /// offline screen never presents old values as current.
    var dataRefreshState: AppDataRefreshState {
        if isShowingProvisionalDSMSnapshot { return .refreshing }
        if isRefreshing { return .refreshing }
        if sourceKind == .mock {
            return provider is DisconnectedAppDataProvider ? .unavailable : .localPreview
        }
        if isDSMReachable { return .current }
        if hasCachedDSMSnapshot {
            return isCachedDSMSnapshotStale ? .stale : .cached
        }
        return .unavailable
    }

    var dataSourceLabelKey: String {
        if sourceKind == .dsm, agentHealth != nil {
            return "data.refresh.source.dsm_agent"
        }
        switch sourceKind {
        case .mock:
            return provider is DisconnectedAppDataProvider
                ? "data.refresh.source.none"
                : "data.refresh.source.preview"
        case .dsm:
            return "data.refresh.source.dsm"
        case .agent:
            return "data.refresh.source.agent"
        }
    }

    var shouldShowDataStatus: Bool {
        if isShowingProvisionalDSMSnapshot { return true }
        switch dataRefreshState {
        case .localPreview, .current, .refreshing:
            return false
        case .cached, .stale, .unavailable:
            return true
        }
    }

    var cachedSnapshotStatusKey: String {
        guard hasCachedDSMSnapshot, hasPersistedCachedSnapshot else {
            return "mine.privacy.cache.none"
        }
        return isCachedDSMSnapshotStale
            ? "mine.privacy.cache.stale"
            : "mine.privacy.cache.available"
    }

    var hasPersistedCachedSnapshot: Bool {
        Self.persistedDSMSnapshotData() != nil
    }

    private var provider: AppDataProviding
    private var activeDataSource: NASDataSource
    private var manualServiceStore: ManualLaunchpadServiceStore
    private let launchpadVisibilityStore: LaunchpadVisibilityStore
    private let launchpadOrderStore: LaunchpadOrderStore
    private let localTaskStore: LocalTaskStore
    /// DEBUG offline UI only: synthetic data and an ephemeral preference domain. Never
    /// touches the network, notifications, sync markers or the persisted NAS snapshot.
    private let isOfflineFixture: Bool
    private var preservedContainerInventoryOnLastMerge = false
    private var consecutiveDSMReachabilityFailures = 0
    private var lastSuccessfulDSMContactAt: Date?
    private var lastForegroundRefreshAt: Date?
    private var serviceHealthRefreshID: UUID?
    private var connectionGeneration = UUID()
    private var activeRefreshID: UUID?
    private var foregroundRefreshID: UUID?
    private let folderCache = DSMFolderCache()
    private var folderAuthenticationGeneration: UUID?
    private var folderFileStationGeneration: UUID?
    private var folderSnapshotAuthenticationGeneration: UUID?

    func serviceInventoryMatches(_ session: DSMSession?) -> Bool {
        guard let session, let source = activeDataSource as? DSMNASDataSource else { return false }
        return source.session.authenticationGeneration == session.authenticationGeneration
            && folderSnapshotAuthenticationGeneration == session.authenticationGeneration
            && !isShowingProvisionalDSMSnapshot
    }
    var serviceInventoryIsComplete: Bool {
        guard let snapshot = provider as? DSMDataSnapshot else { return false }
        return snapshot.containerInventoryAvailable && snapshot.packageInventoryAvailable && snapshot.reverseProxyInventoryAvailable
    }

    var folderSnapshotMatchesSource: Bool {
        folderAuthenticationGeneration != nil
            && folderAuthenticationGeneration == folderSnapshotAuthenticationGeneration
    }

    private static let foregroundRefreshCooldown: TimeInterval = 90
    private static let foregroundFreshnessInterval: TimeInterval = 5 * 60

    convenience init(provider: AppDataProviding? = nil) {
        self.init(provider: provider, defaults: .standard, isOfflineFixture: false)
    }

    #if DEBUG
    static func offlineFixture(defaults: UserDefaults) -> AppDataStore {
        AppDataStore(provider: MockAppDataProvider(), defaults: defaults, isOfflineFixture: true)
    }
    #endif

    private init(provider: AppDataProviding?, defaults: UserDefaults, isOfflineFixture: Bool) {
        let taskStore = LocalTaskStore(defaults: defaults)
        let visibilityStore = LaunchpadVisibilityStore(defaults: defaults)
        let orderStore = LaunchpadOrderStore(defaults: defaults)
        let manualStore = ManualLaunchpadServiceStore(defaults: defaults)
        let persistedTasks = isOfflineFixture ? nil : taskStore.load()
        let persistedSnapshot = isOfflineFixture ? nil : Self.loadPersistedDSMSnapshot()
        let initialProvider = provider
            ?? persistedSnapshot?.snapshot
            ?? DisconnectedAppDataProvider()
        self.provider = initialProvider
        self.isOfflineFixture = isOfflineFixture
        localTaskStore = taskStore
        launchpadVisibilityStore = visibilityStore
        launchpadOrderStore = orderStore
        manualServiceStore = manualStore
        serviceVisibilityOverrides = visibilityStore.load()
        launchpadServiceOrder = orderStore.load()
        sourceKind = initialProvider is DSMDataSnapshot ? .dsm : .mock
        cachedDSMSnapshotSavedAt = provider == nil ? persistedSnapshot?.savedAt : nil
        activeDataSource = DisconnectedNASDataSource()
        device = initialProvider.device
        agentHealth = initialProvider.agentHealth
        services = (initialProvider.services + manualStore.load()).map {
            provider == nil ? $0.replacing(status: .unknown) : $0
        }
        containers = initialProvider.containers
        files = initialProvider.files
        tasks = persistedTasks?.pending ?? initialProvider.tasks
        completedTasks = persistedTasks?.history ?? []
        videoLibraryItems = initialProvider.videoLibraryItems
        audioLibraryItems = initialProvider.audioLibraryItems
        discoveredDevices = initialProvider.discoveredDevices
        tasks.forEach {
            scheduleReminder($0, requestsAuthorization: false)
        }
    }

    @MainActor
    func reload(from provider: AppDataProviding, persistSnapshot: Bool = true) {
        serviceHealthRefreshID = nil
        let previousServices = services
        let previousContainers = containers
        self.provider = provider
        sourceKind = provider is DSMDataSnapshot ? .dsm : .mock
        agentHealth = provider.agentHealth
        device = provider is DSMDataSnapshot
            ? Self.mergedDevice(fresh: provider.device, fallback: device)
            : provider.device
        if let snapshot = provider as? DSMDataSnapshot {
            services = mergedServices(
                fresh: snapshot.services,
                previous: previousServices,
                snapshot: snapshot
            ) + manualServiceStore.load()
        } else {
            services = provider.services + manualServiceStore.load()
            preservedContainerInventoryOnLastMerge = false
        }
        if provider is DSMDataSnapshot {
            let baseURL = (activeDataSource as? DSMNASDataSource)?.session.baseURL
            let previousByID = Dictionary(previousServices.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            services = services.map { service in
                if let previous = previousByID[service.id],
                   previous.preferredEndpoint(for: baseURL) == service.preferredEndpoint(for: baseURL),
                   let health = serviceHealth[service.id],
                   Date().timeIntervalSince(health.checkedAt) < 45 {
                    return service.replacing(status: health.status)
                }
                // A package nobody can open is never probed, so its inventory state
                // is the only state it will ever have.
                if service.source == .package, !service.isLaunchpadVisible || service.endpoint == nil {
                    return service
                }
                // Inventory says a process exists/runs, not that its web service
                // is accessible from this device. Await an actual probe.
                return service.replacing(status: .unknown)
            }
            serviceHealth = serviceHealth.filter { id, health in
                services.contains { $0.id == id && $0.status == health.status }
                    && Date().timeIntervalSince(health.checkedAt) < 45
            }
        }
        containers = preservedContainerInventoryOnLastMerge
            ? previousContainers
            : provider.containers
        files = provider.files
        if tasks.isEmpty, completedTasks.isEmpty, !provider.tasks.isEmpty {
            tasks = provider.tasks
            persistTasks()
        }
        videoLibraryItems = provider.videoLibraryItems
        audioLibraryItems = provider.audioLibraryItems
        discoveredDevices = provider.discoveredDevices
        lastRefreshSummaryKey = provider is DSMDataSnapshot ? "data.refresh.dsm_done" : "data.refresh.mock_done"
        if !isOfflineFixture, let snapshot = dsmSnapshotForPersistence(), persistSnapshot, !Self.isProvisionalDSMSnapshot(snapshot) {
            cachedDSMSnapshotSavedAt = Date()
            Self.persistDSMSnapshot(snapshot, savedAt: cachedDSMSnapshotSavedAt ?? Date())
        } else if !(provider is DSMDataSnapshot) {
            cachedDSMSnapshotSavedAt = nil
        }
    }

    /// Persist the inventory actually applied to the UI. A failed partial
    /// refresh can retain services in memory; saving the raw response instead
    /// would silently discard those services on the next cold launch.
    func dsmSnapshotForPersistence() -> DSMDataSnapshot? {
        guard let snapshot = provider as? DSMDataSnapshot else { return nil }
        return DSMDataSnapshot(
            device: device,
            services: services.filter { $0.source != .manual },
            containers: containers,
            files: snapshot.files,
            tasks: snapshot.tasks,
            videoLibraryItems: snapshot.videoLibraryItems,
            audioLibraryItems: snapshot.audioLibraryItems,
            discoveredDevices: snapshot.discoveredDevices,
            containerInventoryAvailable: snapshot.containerInventoryAvailable,
            packageInventoryAvailable: snapshot.packageInventoryAvailable,
            reverseProxyInventoryAvailable: snapshot.reverseProxyInventoryAvailable,
            agentHealth: snapshot.agentHealth
        )
    }

    private struct PersistedDSMSnapshot: Codable {
        let version: Int?
        let snapshot: DSMDataSnapshot
        let savedAt: Date
    }

    private static func loadPersistedDSMSnapshot() -> (snapshot: DSMDataSnapshot, savedAt: Date)? {
        guard let data = persistedDSMSnapshotData() else {
            return nil
        }
        if let persisted = try? JSONDecoder().decode(PersistedDSMSnapshot.self, from: data),
           (persisted.version ?? 1) <= Self.persistedDSMSnapshotFormatVersion {
            if isProvisionalDSMSnapshot(persisted.snapshot) {
                removePersistedDSMSnapshot()
                return nil
            }
            return (persisted.snapshot, persisted.savedAt)
        }
        // Migrate snapshots written before the timestamp envelope existed. The
        // contents remain useful, but their age is unknown and is therefore
        // intentionally treated as stale until a fresh snapshot is saved.
        guard let snapshot = try? JSONDecoder().decode(DSMDataSnapshot.self, from: data) else {
            return nil
        }
        if isProvisionalDSMSnapshot(snapshot) {
            removePersistedDSMSnapshot()
            return nil
        }
        return (snapshot, .distantPast)
    }

    private static func isProvisionalDSMSnapshot(_ snapshot: DSMDataSnapshot) -> Bool {
        snapshot.services.count <= 1
            && snapshot.containers.isEmpty
            && snapshot.files.isEmpty
            && snapshot.videoLibraryItems.isEmpty
            && snapshot.audioLibraryItems.isEmpty
            && snapshot.device.model == nil
            && snapshot.device.dsmVersion == nil
            && snapshot.device.cpu == nil
            && snapshot.device.memory == nil
            && snapshot.device.storageUsed == nil
            && !snapshot.containerInventoryAvailable
            && !snapshot.packageInventoryAvailable
            && !snapshot.reverseProxyInventoryAvailable
    }

    private static func persistDSMSnapshot(_ snapshot: DSMDataSnapshot, savedAt: Date) {
        let persisted = PersistedDSMSnapshot(
            version: Self.persistedDSMSnapshotFormatVersion,
            snapshot: snapshot,
            savedAt: savedAt
        )
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        guard let url = persistedDSMSnapshotURL() else {
            UserDefaults.standard.set(data, forKey: persistedDSMSnapshotKey)
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            UserDefaults.standard.removeObject(forKey: persistedDSMSnapshotKey)
        } catch {
            // Keep the existing fallback so a storage-protected device still
            // retains offline continuity rather than silently losing its cache.
            UserDefaults.standard.set(data, forKey: persistedDSMSnapshotKey)
        }
    }

    private static func persistedDSMSnapshotURL() -> URL? {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }
        return directory
            .appendingPathComponent("Nastart", isDirectory: true)
            .appendingPathComponent("dsm.cachedSnapshot.v1", isDirectory: false)
    }

    private static func persistedDSMSnapshotData() -> Data? {
        if let url = persistedDSMSnapshotURL(),
           let data = try? Data(contentsOf: url) {
            return data
        }
        guard let legacyData = UserDefaults.standard.data(forKey: persistedDSMSnapshotKey) else {
            return nil
        }
        // Migrate older builds that kept this display-only snapshot in defaults.
        if let url = persistedDSMSnapshotURL() {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try legacyData.write(to: url, options: .atomic)
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: url.path
                )
                UserDefaults.standard.removeObject(forKey: persistedDSMSnapshotKey)
            } catch {
                // Legacy data is still readable when migration is unavailable.
            }
        }
        return legacyData
    }

    private static func removePersistedDSMSnapshot() {
        if let url = persistedDSMSnapshotURL() {
            try? FileManager.default.removeItem(at: url)
        }
        UserDefaults.standard.removeObject(forKey: persistedDSMSnapshotKey)
    }

    private func mergedServices(
        fresh: [LaunchpadService],
        previous: [LaunchpadService],
        snapshot: DSMDataSnapshot
    ) -> [LaunchpadService] {
        let previousContainers = previous.filter {
            $0.source == .container || $0.source == .reverseProxy
        }
        let freshContainers = fresh.filter {
            $0.source == .container || $0.source == .reverseProxy
        }
        let previousPackages = previous.filter { $0.source == .package }
        let freshPackages = fresh.filter { $0.source == .package }

        // Preserve the last known inventory only when the corresponding request
        // failed. A successful empty response means the user removed all items.
        let preserveContainers = !snapshot.containerInventoryAvailable
            && freshContainers.isEmpty
            && !previousContainers.isEmpty
        let preservePackages = !snapshot.packageInventoryAvailable
            && freshPackages.isEmpty
            && !previousPackages.isEmpty
        preservedContainerInventoryOnLastMerge = preserveContainers

        var merged = fresh
        if !snapshot.reverseProxyInventoryAvailable {
            let previousByID = Dictionary(
                uniqueKeysWithValues: previousContainers.map { ($0.id, $0) }
            )
            merged = merged.map { service in
                guard
                    service.source == .container || service.source == .reverseProxy,
                    let previousService = previousByID[service.id],
                    previousService.source == .reverseProxy
                else {
                    return service
                }
                return Self.service(
                    service,
                    preservingEndpointFrom: previousService
                )
            }
        }
        if preserveContainers {
            merged.removeAll { $0.source == .container || $0.source == .reverseProxy }
            merged.append(contentsOf: previousContainers)
        }
        if preservePackages {
            merged.removeAll { $0.source == .package }
            merged.append(contentsOf: previousPackages)
        }

        let preservedKinds = [
            preserveContainers ? "containers" : nil,
            preservePackages ? "packages" : nil
        ].compactMap { $0 }.joined(separator: "|")
        DiagnosticLogStore.shared.record(
            preserveContainers || preservePackages ? .warning : .info,
            categoryKey: "diagnostics.category.refresh",
            messageKey: preserveContainers || preservePackages
                ? "diagnostics.refresh.inventory_preserved"
                : "diagnostics.refresh.applied",
            details: [
                "before": "\(previous.filter { $0.source != .manual }.count)",
                "received": "\(fresh.count)",
                "applied": "\(merged.count)",
                "containersBefore": "\(previousContainers.count)",
                "containersReceived": "\(freshContainers.count)",
                "containerInventory": snapshot.containerInventoryAvailable ? "available" : "failed",
                "reverseProxyInventory": snapshot.reverseProxyInventoryAvailable ? "available" : "failed",
                "packagesBefore": "\(previousPackages.count)",
                "packagesReceived": "\(freshPackages.count)",
                "packageInventory": snapshot.packageInventoryAvailable ? "available" : "failed",
                "preserved": preservedKinds
            ]
        )
        return merged
    }

    private static func service(
        _ fresh: LaunchpadService,
        preservingEndpointFrom previous: LaunchpadService
    ) -> LaunchpadService {
        LaunchpadService(
            id: fresh.id,
            name: fresh.name,
            iconText: fresh.iconText,
            category: fresh.category,
            status: fresh.status,
            subtitle: fresh.subtitle,
            detail: fresh.detail,
            isMedia: fresh.isMedia,
            cpu: fresh.cpu,
            memoryText: fresh.memoryText,
            memory: fresh.memory,
            ports: fresh.ports,
            iconURL: fresh.iconURL,
            endpoint: previous.endpoint,
            alternateEndpoint: previous.alternateEndpoint,
            source: previous.source,
            isLaunchpadVisible: fresh.isLaunchpadVisible
        )
    }

    private static func mergedDevice(fresh: NASDevice, fallback: NASDevice) -> NASDevice {
        NASDevice(
            id: fresh.id,
            name: fresh.name,
            subtitle: fresh.subtitle,
            model: fresh.model ?? fallback.model,
            dsmVersion: fresh.dsmVersion ?? fallback.dsmVersion,
            mode: fresh.mode,
            cpu: fresh.cpu ?? fallback.cpu,
            memory: fresh.memory ?? fallback.memory,
            memoryUsedText: fresh.memoryUsedText ?? fallback.memoryUsedText,
            memoryTotalText: fresh.memoryTotalText ?? fallback.memoryTotalText,
            storageUsed: fresh.storageUsed ?? fallback.storageUsed,
            storageUsedText: fresh.storageUsedText ?? fallback.storageUsedText,
            storageTotalText: fresh.storageTotalText ?? fallback.storageTotalText,
            storageFreeText: fresh.storageFreeText == "-" ? fallback.storageFreeText : fresh.storageFreeText,
            uptimeMinutes: fresh.uptimeMinutes ?? fallback.uptimeMinutes,
            temperatureText: fresh.temperatureText ?? fallback.temperatureText,
            certificate: fresh.certificate ?? fallback.certificate,
            sshStatus: fresh.sshStatus == .unavailable ? fallback.sshStatus : fresh.sshStatus
        )
    }

    @MainActor
    func refreshAll() {
        guard !isRefreshing else { return }
        isRefreshing = true
        reload(from: provider)
        isRefreshing = false
    }

    @MainActor
    func refreshServiceHealth() async {
        guard !isOfflineFixture else { return }
        guard serviceHealthRefreshID == nil else { return }
        let candidates = services.compactMap { service -> ServiceHealthTarget? in
            guard
                let endpoint = service.preferredEndpoint(for: (activeDataSource as? DSMNASDataSource)?.session.baseURL),
                UserConfiguredServiceURLPolicy.allows(endpoint)
            else {
                return nil
            }
            let session = (activeDataSource as? DSMNASDataSource)?.session
            return ServiceHealthTarget(id: service.id, url: endpoint,
                allowsSelfSignedCertificates: session?.allowsSelfSignedCertificates == true
                    && endpoint.host?.lowercased() == session?.baseURL.host?.lowercased())
        }
        guard !candidates.isEmpty else {
            serviceHealth.removeAll()
            return
        }

        let refreshID = UUID()
        serviceHealthRefreshID = refreshID
        defer { if serviceHealthRefreshID == refreshID { serviceHealthRefreshID = nil } }

        let candidateIDs = Set(candidates.map(\.id))
        serviceHealth = serviceHealth.filter { candidateIDs.contains($0.key) }
        let grouped = Dictionary(grouping: candidates, by: { $0.url.absoluteString })
        let representatives = grouped.values.compactMap(\.first)
        let probed = await ServiceHealthProbe.check(representatives) { [weak self] id, health in
            guard let self, !Task.isCancelled, self.serviceHealthRefreshID == refreshID else { return }
            let matchingIDs = Set(grouped.values.first(where: { $0.first?.id == id })?.map(\.id) ?? [])
            for targetID in matchingIDs { self.serviceHealth[targetID] = health }
            // Publish each completed endpoint; an unrelated timeout must not
            // hold all successful service cards in the unknown state.
            self.services = self.services.map { service in
                matchingIDs.contains(service.id) ? service.replacing(status: health.status) : service
            }
        }
        var snapshots: [UUID: ServiceHealthSnapshot] = [:]
        for targets in grouped.values {
            guard let first = targets.first, let health = probed[first.id] else { continue }
            for target in targets { snapshots[target.id] = health }
        }
        guard !Task.isCancelled, serviceHealthRefreshID == refreshID, !snapshots.isEmpty else { return }

        serviceHealth.merge(snapshots) { _, latest in latest }
        services = services.map { service in
            guard let snapshot = serviceHealth[service.id] else { return service }
            return service.replacing(status: snapshot.status)
        }
    }

    func healthSnapshot(for service: LaunchpadService) -> ServiceHealthSnapshot? {
        serviceHealth[service.id]
    }

    @MainActor
    func refreshActiveDataSource() async {
        await load(from: activeDataSource)
    }

    @MainActor
    func load(from dataSource: NASDataSource) async {
        guard !isOfflineFixture else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        let refreshID = UUID()
        activeRefreshID = refreshID
        defer {
            if activeRefreshID == refreshID {
                activeRefreshID = nil
                isRefreshing = false
            }
        }

        prepareFolderCache(for: dataSource)
        activeDataSource = dataSource
        let snapshot = await dataSource.loadSnapshot()
        guard !Task.isCancelled, activeRefreshID == refreshID else { return }
        folderSnapshotAuthenticationGeneration = (dataSource as? DSMNASDataSource)?.session.authenticationGeneration
        reload(from: snapshot)
        sourceKind = dataSource.kind
    }

    @MainActor
    func resetToMockData() {
        invalidateActiveRefresh()
        let dataSource = MockNASDataSource()
        prepareFolderCache(for: dataSource)
        activeDataSource = dataSource
        reload(from: MockAppDataProvider())
        sourceKind = .mock
        isDSMReachable = false
        resetDSMReachabilityHistory()
    }

    @MainActor
    func clearConnectionData() {
        invalidateActiveRefresh()
        if !isOfflineFixture { Self.removePersistedDSMSnapshot() }
        let dataSource = DisconnectedNASDataSource()
        prepareFolderCache(for: dataSource)
        activeDataSource = dataSource
        reload(from: DisconnectedAppDataProvider())
        sourceKind = .mock
        isDSMReachable = false
        cachedDSMSnapshotSavedAt = nil
        serviceHealth.removeAll()
        resetDSMReachabilityHistory()
        lastRefreshSummaryKey = "data.refresh.disconnected"
    }

    @MainActor
    func clearCachedSnapshot() {
        invalidateActiveRefresh()
        if !isOfflineFixture { Self.removePersistedDSMSnapshot() }
        folderCache.clear()
        folderSourceID = UUID()
        cachedDSMSnapshotSavedAt = nil
        serviceHealth.removeAll()

        if !isDSMReachable {
            reload(from: DisconnectedAppDataProvider())
            sourceKind = .mock
            resetDSMReachabilityHistory()
        }
        lastRefreshSummaryKey = "data.refresh.cache_cleared"
    }

    @MainActor
    func reconnectDSM(using connectionStore: NASConnectionStore) async {
        guard !isOfflineFixture else { return }
        if let session = connectionStore.dsmSession {
            _ = await refreshDSM(session: session, useAgent: connectionStore.usesAgent)
        } else {
            await restoreDSMConnection(using: connectionStore)
        }
    }

    /// Lightweight foreground monitoring, separate from the expensive inventory refresh.
    @MainActor
    func monitorConnectivity(using connectionStore: NASConnectionStore) async {
        guard !isOfflineFixture else { return }
        let generation = connectionGeneration
        if let session = connectionStore.dsmSession {
            let reachable = await DSMClient(baseURL: session.baseURL,
                allowsSelfSignedCertificates: session.allowsSelfSignedCertificates).isDSMEndpoint()
            guard !Task.isCancelled, generation == connectionGeneration,
                  connectionStore.dsmSession?.sid == session.sid else { return }
            if reachable { recordSuccessfulDSMContact() }
            else { handleDSMReachabilityFailure(target: session.baseURL) }
        }
        await refreshServiceHealth()
    }

    @MainActor
    func refreshForForeground(using connectionStore: NASConnectionStore,
                              operations: DSMConnectionOperations = DSMConnectionOperations()) async {
        guard !isOfflineFixture else { return }
        guard !Task.isCancelled, !isRefreshing else { return }
        let now = operations.currentTime()
        if let lastForegroundRefreshAt,
           now.timeIntervalSince(lastForegroundRefreshAt) < Self.foregroundRefreshCooldown {
            return
        }
        lastForegroundRefreshAt = now

        if let session = connectionStore.dsmSession {
            let secondsSinceContact = lastSuccessfulDSMContactAt.map {
                now.timeIntervalSince($0)
            } ?? .infinity
            guard dataRefreshState != .current
                || secondsSinceContact >= Self.foregroundFreshnessInterval else {
                return
            }
            let foregroundID = UUID()
            foregroundRefreshID = foregroundID
            isForegroundRefreshing = true
            defer {
                if foregroundRefreshID == foregroundID { foregroundRefreshID = nil; isForegroundRefreshing = false }
            }
            _ = await refreshDSM(session: session, useAgent: connectionStore.usesAgent, operations: operations)
            return
        }

        guard operations.loadCredential() != nil else {
            return
        }
        // DSM counts each refused login toward auto block. Returning to the
        // foreground must not repeat one; the user retries from the recovery card.
        guard connectionRecoveryRejection == nil else { return }
        let foregroundID = UUID()
        foregroundRefreshID = foregroundID
        isForegroundRefreshing = true
        defer {
            if foregroundRefreshID == foregroundID { foregroundRefreshID = nil; isForegroundRefreshing = false }
        }
        await restoreDSMConnection(using: connectionStore, operations: operations)
    }

    @MainActor
    @discardableResult
    func refreshDSM(session: DSMSession, useAgent: Bool,
                    operations: DSMConnectionOperations = DSMConnectionOperations()) async -> Bool {
        guard !isOfflineFixture else { return false }
        guard !Task.isCancelled else { return false }
        guard !isRefreshing else { return isDSMReachable }
        isRefreshing = true
        let refreshID = UUID()
        activeRefreshID = refreshID
        defer {
            if activeRefreshID == refreshID {
                activeRefreshID = nil
                isRefreshing = false
            }
        }

        let dataSource = DSMNASDataSource(session: session, useAgent: useAgent)
        prepareFolderCache(for: dataSource)
        activeDataSource = dataSource
        let reachable = await operations.isReachable(dataSource)
        guard !Task.isCancelled, activeRefreshID == refreshID else { return false }
        guard reachable else {
            handleDSMReachabilityFailure(target: session.baseURL)
            return false
        }

        recordSuccessfulDSMContact()
        let snapshot = await operations.loadRefreshSnapshot(dataSource)
        guard !Task.isCancelled, activeRefreshID == refreshID else { return false }
        folderSnapshotAuthenticationGeneration = (dataSource as? DSMNASDataSource)?.session.authenticationGeneration
        reload(from: snapshot)
        sourceKind = dataSource.kind
        recordSuccessfulDSMContact()
        await operations.refreshServiceHealth(self)
        return !Task.isCancelled && activeRefreshID == refreshID
    }

    @MainActor
    private func invalidateActiveRefresh() {
        activeRefreshID = nil
        isRefreshing = false
        connectionRecoveryState = .idle
        connectionRecoveryRejection = nil
        foregroundRefreshID = nil
        isForegroundRefreshing = false
    }

    @MainActor
    func activateDSM(
        snapshot: DSMDataSnapshot,
        session: DSMSession,
        useAgent: Bool,
        persistSnapshot: Bool = true
    ) {
        guard !isOfflineFixture else { return }
        let dataSource = DSMNASDataSource(session: session, useAgent: useAgent)
        prepareFolderCache(for: dataSource)
        activeDataSource = dataSource
        folderSnapshotAuthenticationGeneration = session.authenticationGeneration
        reload(from: snapshot, persistSnapshot: persistSnapshot)
        sourceKind = .dsm
        Task { await refreshServiceHealth() }
    }

    @MainActor
    func activateDSMSession(session: DSMSession, useAgent: Bool) {
        guard !isOfflineFixture else { return }
        activateDSMSession(session: session, useAgent: useAgent, preservingRestoreID: nil)
    }

    @MainActor
    private func activateDSMSession(session: DSMSession, useAgent: Bool, preservingRestoreID: UUID?) {
        if activeRefreshID != nil && activeRefreshID != preservingRestoreID { invalidateActiveRefresh() }
        connectionGeneration = UUID()
        serviceHealthRefreshID = nil
        serviceHealth.removeAll()
        services = services.map { $0.replacing(status: .unknown) }
        let dataSource = DSMNASDataSource(session: session, useAgent: useAgent)
        prepareFolderCache(for: dataSource)
        activeDataSource = dataSource
        if !hasCachedDSMSnapshot, services.filter({ $0.source != .manual }).isEmpty {
            reload(from: Self.provisionalDSMSnapshot(session: session), persistSnapshot: false)
        }
        sourceKind = .dsm
        recordSuccessfulDSMContact()
    }

    private static func sessionByClearingStaleLANIfNeeded(_ session: DSMSession) -> DSMSession {
        guard !NetworkHostClassifier.isPrivate(session.baseURL.host),
              session.endpoints.lanAddress != nil
        else {
            return session
        }
        return session.replacingConnection(endpoints: session.endpoints.removingLANAddress())
    }

    private static func session(
        _ session: DSMSession,
        addingVerifiedLANAddress lanAddress: URL?
    ) -> DSMSession {
        let endpoints = session.endpoints.addingVerifiedLANAddress(lanAddress)
        guard endpoints != session.endpoints else { return session }
        let target = lanAddress.map(DiagnosticLogStore.redactedURL) ?? "-"
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.route.smart_lan_ready",
            details: ["target": target]
        )
        return session.replacingConnection(endpoints: endpoints)
    }

    @MainActor
    fileprivate static func discoverSmartLANAddress(for baseURL: URL) async -> URL? {
        guard !NetworkHostClassifier.isPrivate(baseURL.host) else { return nil }
        let lanAddress = await LANDiscoveryService.discoverDSMPlaybackLANEndpoint(
            timeout: 3,
            requiresSingleHost: true
        )
        guard let lanAddress else { return nil }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.route.smart_lan_found",
            details: ["target": DiagnosticLogStore.redactedURL(lanAddress)]
        )
        return lanAddress
    }

    private static func provisionalDSMSnapshot(session: DSMSession) -> DSMDataSnapshot {
        let trimmedHost = session.baseURL.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = trimmedHost.isEmpty ? "DSM" : trimmedHost
        let device = NASDevice(
            id: UUID(),
            name: displayName,
            subtitle: "DSM",
            model: nil,
            dsmVersion: nil,
            mode: .dsmOnly,
            cpu: nil,
            memory: nil,
            memoryUsedText: nil,
            memoryTotalText: nil,
            storageUsed: nil,
            storageUsedText: nil,
            storageTotalText: nil,
            storageFreeText: "-",
            uptimeMinutes: nil,
            temperatureText: nil,
            certificate: nil,
            sshStatus: .unavailable
        )
        let dsmService = LaunchpadService(
            id: UUID(uuidString: "A1F38D26-9B9F-43B3-965F-001A21D22401") ?? UUID(),
            name: "DSM",
            iconText: "DSM",
            category: .favorites,
            status: .online,
            subtitle: trimmedHost.isEmpty ? "DSM" : trimmedHost,
            detail: "service.dsm.detail",
            isMedia: false,
            cpu: nil,
            memoryText: nil,
            endpoint: session.baseURL,
            source: .dsm
        )
        return DSMDataSnapshot(
            device: device,
            services: [dsmService],
            containers: [],
            files: [],
            tasks: [],
            videoLibraryItems: [],
            audioLibraryItems: [],
            discoveredDevices: [],
            containerInventoryAvailable: false,
            packageInventoryAvailable: false,
            reverseProxyInventoryAvailable: false,
            agentHealth: nil
        )
    }

    @MainActor
    func loadFolder(path: String, forceRefresh: Bool = false) async throws -> [FileItem] {
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "/"
            : path
        if isOfflineFixture { return localChildren(for: normalizedPath, in: files) }
        if !forceRefresh, let cachedItems = folderCache.freshItems(for: normalizedPath) {
            DiagnosticLogStore.shared.record(
                .info, categoryKey: "diagnostics.category.dsm_api",
                messageKey: "diagnostics.files.folder_loaded",
                details: ["pathDepth": "\(normalizedPath.split(separator: "/").count)",
                          "items": "\(cachedItems.count)", "source": "memoryCache", "durationMs": "0"])
            return cachedItems
        }
        if let dataSource = activeDataSource as? DSMNASDataSource {
            do {
                return try await folderCache.load(path: normalizedPath) {
                    try await dataSource.loadFolder(path: normalizedPath)
                }
            } catch {
                if error is CancellationError || Task.isCancelled { throw CancellationError() }
                DiagnosticLogStore.shared.record(
                    .warning,
                    categoryKey: "diagnostics.category.dsm_api",
                    messageKey: "diagnostics.files.folder_failed",
                    details: [
                        "pathDepth": "\(normalizedPath.split(separator: "/").count)",
                        "error": "\(error)"
                    ]
                )
                if case DSMClientError.apiFailed(code: 119) = error { throw error }
                let localItems = localChildren(for: normalizedPath, in: files)
                if !localItems.isEmpty { return localItems }
                throw error
            }
        }
        return localChildren(for: normalizedPath, in: files)
    }

    @MainActor
    private func prepareFolderCache(for dataSource: NASDataSource) {
        let session = (dataSource as? DSMNASDataSource)?.session
        let cacheChanged = folderCache.prepare(for: session)
        if cacheChanged || session == nil
            || folderAuthenticationGeneration != session?.authenticationGeneration
            || folderFileStationGeneration != session?.fileStationGeneration {
            folderSourceID = UUID()
        }
        folderAuthenticationGeneration = session?.authenticationGeneration
        folderFileStationGeneration = session?.fileStationGeneration
        session?.recordAuthenticationStage(.sourcePrepared)
    }

    /// Both readers become ready in one MainActor turn, before inventory I/O.
    @MainActor
    @discardableResult
    func publishFolderSession(_ session: DSMSession, useAgent: Bool,
                              using connectionStore: NASConnectionStore) -> Bool {
        guard !isOfflineFixture else { return false }
        guard !Task.isCancelled,
              connectionStore.dsmSession?.authenticationGeneration == session.authenticationGeneration,
              (activeDataSource as? DSMNASDataSource)?.session.authenticationGeneration == session.authenticationGeneration
        else { return false }
        let dataSource = DSMNASDataSource(session: session, useAgent: useAgent)
        prepareFolderCache(for: dataSource)
        activeDataSource = dataSource
        connectionStore.connect(device: device, session: session)
        return true
    }

    private func localChildren(for path: String, in items: [FileItem]) -> [FileItem] {
        for item in items {
            if item.path == path { return item.children }
            let nested = localChildren(for: path, in: item.children)
            if !nested.isEmpty { return nested }
        }
        return []
    }

    @MainActor
    func beginDSMConnectionAttempt(using connectionStore: NASConnectionStore) -> UUID {
        invalidateActiveRefresh()
        connectionGeneration = UUID()
        return connectionStore.beginDSMConnectionAttempt()
    }

    @MainActor
    private func ownsDSMConnectionWork(_ id: UUID, session: DSMSession, using connectionStore: NASConnectionStore) -> Bool {
        !Task.isCancelled && connectionStore.ownsDSMConnectionAttempt(id)
            && connectionStore.dsmSession?.authenticationGeneration == session.authenticationGeneration
            && (activeDataSource as? DSMNASDataSource)?.session.authenticationGeneration == session.authenticationGeneration
    }

    /// Shared tail for restoration and manual login. Recheck after each suspended I/O.
    @MainActor
    func finishDSMConnection(_ result: DSMLoginResult, credential: StoredNASCredential,
                             operationID: UUID, using connectionStore: NASConnectionStore,
                             useAgent: Bool, saveCredential: Bool = true, oneTimeCode: String = "",
                             operations: DSMConnectionOperations = DSMConnectionOperations(),
                             restoreRefreshID: UUID? = nil) async throws {
        guard !isOfflineFixture else { throw CancellationError() }
        var session = result.session
        func checkOwnership() throws {
            guard ownsDSMConnectionWork(operationID, session: session, using: connectionStore),
                  restoreRefreshID == nil || activeRefreshID == restoreRefreshID else { throw CancellationError() }
        }
        do {
            try checkOwnership()
            let discoveryBaseURL = session.baseURL
            async let discoveredLAN = operations.discoverLAN(discoveryBaseURL)
            session = await operations.attachFileStation(result, credential, oneTimeCode)
            try checkOwnership()
            // The authenticated origin already works. Optional LAN discovery
            // must not delay both file readers adopting the File Station SID.
            guard publishFolderSession(session, useAgent: useAgent, using: connectionStore) else { throw CancellationError() }
            let lan = await discoveredLAN
            try checkOwnership()
            session = Self.session(session, addingVerifiedLANAddress: lan)
            guard publishFolderSession(session, useAgent: useAgent, using: connectionStore) else { throw CancellationError() }
            let snapshot = await operations.loadSnapshot(session, useAgent)
            try checkOwnership()
            // No suspension between the final identity check, credential write and publication.
            if saveCredential {
                try operations.saveCredential(StoredNASCredential(
                    baseURLString: credential.baseURLString, account: credential.account,
                    password: credential.password, useAgent: useAgent,
                    allowsSelfSignedCertificates: credential.allowsSelfSignedCertificates,
                    deviceID: session.deviceID ?? credential.deviceID, endpoints: session.endpoints,
                    lastKnownRoute: session.actualRoute,
                    usesOnlyConfiguredAddress: credential.usesOnlyConfiguredAddress))
            }
            let dataSource = DSMNASDataSource(session: session, useAgent: useAgent)
            prepareFolderCache(for: dataSource)
            activeDataSource = dataSource
            recordSuccessfulDSMContact()
            folderSnapshotAuthenticationGeneration = session.authenticationGeneration
            reload(from: snapshot)
            sourceKind = dataSource.kind
            connectionStore.connect(device: snapshot.device, session: session)
            // Start checking the published inventory immediately, rather than
            // waiting for the next 15-second foreground monitoring tick.
            await operations.refreshServiceHealth(self)
        } catch {
            await operations.logout(session, connectionStore)
            throw error
        }
    }

    @MainActor
    func restoreDSMConnection(using connectionStore: NASConnectionStore,
                              operations: DSMConnectionOperations = DSMConnectionOperations()) async {
        guard !isOfflineFixture else { return }
        guard !Task.isCancelled, !isRefreshing else { return }
        guard let credential = operations.loadCredential() else {
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.connection",
                messageKey: "diagnostics.restore.missing_credentials"
            )
            return
        }
        let restoreID = connectionStore.beginDSMConnectionAttempt()
        activeRefreshID = restoreID
        isRefreshing = true
        connectionRecoveryState = .restoring
        connectionRecoveryRejection = nil
        defer {
            if activeRefreshID == restoreID {
                activeRefreshID = nil
                isRefreshing = false
                if connectionRecoveryState == .restoring { connectionRecoveryState = .idle }
            }
        }
        func checkRestoreOwnership() throws {
            guard !Task.isCancelled, activeRefreshID == restoreID,
                  connectionStore.ownsDSMConnectionAttempt(restoreID) else { throw CancellationError() }
        }
        var sessionToLogout: DSMSession?

        do {
            let baseURL = try DSMClient.normalizedBaseURL(from: credential.baseURLString)
            var endpoints = credential.endpoints.candidates.isEmpty
                ? DSMConnectionEndpoints(legacyBaseURL: baseURL)
                : credential.endpoints
            // A discovered LAN address is useful for optional media routing,
            // but it must not replace a user-pinned DSM authentication origin.
            if credential.usesOnlyConfiguredAddress {
                endpoints = DSMConnectionEndpoints(legacyBaseURL: baseURL)
            }
            let usesStoredAgent = operations.usesAgent()
            let loginResult: DSMLoginResult
            do {
                loginResult = try await operations.login(credential, endpoints)
            } catch {
                try checkRestoreOwnership()
                // A timed-out credential POST may already have reached DSM.
                // Do not silently issue another login or scan the LAN for it.
                guard !credential.usesOnlyConfiguredAddress,
                      DSMClient.shouldRetryLogin(on: error) else { throw error }
                // Older credentials may contain only a stale address. Discover
                // a verified private DSM endpoint before retrying credentials.
                DiagnosticLogStore.shared.record(
                    .warning,
                    categoryKey: "diagnostics.category.connection",
                    messageKey: "diagnostics.restore.fallback_started",
                    details: [
                        "error": Self.restoreDiagnosticMessage(for: error),
                        "configuredEndpoints": "\(endpoints.candidates.count)"
                    ]
                )
                let discoveredEndpoints = await operations.discoverFallback()
                try checkRestoreOwnership()
                let knownURLs = Set(endpoints.candidates.map { $0.url.absoluteString })
                guard let discoveredLAN = discoveredEndpoints.first(where: {
                    NetworkHostClassifier.isPrivate($0.host)
                        && !knownURLs.contains($0.absoluteString)
                }) else {
                    throw error
                }
                endpoints = DSMConnectionEndpoints(
                    primaryDomain: endpoints.primaryDomain,
                    lanAddress: discoveredLAN,
                    publicAddress: endpoints.publicAddress
                )
                DiagnosticLogStore.shared.record(
                    .info,
                    categoryKey: "diagnostics.category.connection",
                    messageKey: "diagnostics.restore.fallback_found",
                    details: ["target": DiagnosticLogStore.redactedURL(discoveredLAN)]
                )
                loginResult = try await operations.login(credential, endpoints)
            }
            let mainSession = Self.sessionByClearingStaleLANIfNeeded(loginResult.session)
            sessionToLogout = mainSession
            try checkRestoreOwnership()
            // Admission, source preparation and connection publication share a MainActor turn.
            activateDSMSession(session: mainSession, useAgent: usesStoredAgent, preservingRestoreID: restoreID)
            connectionStore.connect(device: device, session: mainSession)
            sessionToLogout = nil
            try await finishDSMConnection(
                DSMLoginResult(client: loginResult.client, session: mainSession), credential: credential,
                operationID: restoreID, using: connectionStore, useAgent: usesStoredAgent,
                operations: operations, restoreRefreshID: restoreID)
        } catch {
            let ownsFailure = activeRefreshID == restoreID && connectionStore.ownsDSMConnectionAttempt(restoreID)
                && !Task.isCancelled && !(error is CancellationError)
            if ownsFailure {
                connectionRecoveryState = .failed
                if let dsmError = error as? DSMClientError, case .loginRejected = dsmError {
                    connectionRecoveryRejection = dsmError
                }
                isDSMReachable = false
                lastRefreshSummaryKey = "data.refresh.restore_failed"
                DiagnosticLogStore.shared.record(
                    .error, categoryKey: "diagnostics.category.connection",
                    messageKey: "diagnostics.restore.failed",
                    details: ["error": Self.restoreDiagnosticMessage(for: error)])
            }
            if let session = sessionToLogout {
                await operations.logout(session, connectionStore)
            }
        }
    }

    private static func restoreDiagnosticMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            return "urlError:\(urlError.code.rawValue)"
        }
        if let dsmError = error as? DSMClientError {
            switch dsmError {
            case .invalidAddress: return "invalidAddress"
            case .insecureHTTP: return "insecureHTTP"
            case .invalidResponse: return "invalidResponse"
            case .apiFailed(let code): return "apiFailed:\(code.map(String.init) ?? "-")"
            case .loginRejected(let code): return "loginRejected:\(code)"
            case .missingSession: return "missingSession"
            }
        }
        return String(describing: type(of: error))
    }

    @MainActor
    private func recordSuccessfulDSMContact() {
        consecutiveDSMReachabilityFailures = 0
        lastSuccessfulDSMContactAt = Date()
        isDSMReachable = true
    }

    @MainActor
    private func resetDSMReachabilityHistory() {
        consecutiveDSMReachabilityFailures = 0
        lastSuccessfulDSMContactAt = nil
    }

    @MainActor
    private func handleDSMReachabilityFailure(target: URL) {
        consecutiveDSMReachabilityFailures += 1
        markDSMUnavailable(target: target)
    }

    @MainActor
    private func markDSMUnavailable(target: URL) {
        isDSMReachable = false
        lastRefreshSummaryKey = "data.refresh.unreachable"
        services = services.map { service in
            let shouldMarkOffline = service.status == .online
                && (service.source != .manual || Self.isPrivateNetworkHost(service.endpoint?.host))
            guard shouldMarkOffline else { return service }
            return LaunchpadService(
                id: service.id,
                name: service.name,
                iconText: service.iconText,
                category: service.category,
                status: .offline,
                subtitle: service.subtitle,
                detail: service.detail,
                isMedia: service.isMedia,
                cpu: service.cpu,
                memoryText: service.memoryText,
                memory: service.memory,
                ports: service.ports,
                iconURL: service.iconURL,
                endpoint: service.endpoint,
                alternateEndpoint: service.alternateEndpoint,
                source: service.source,
                isLaunchpadVisible: service.isLaunchpadVisible
            )
        }
        containers = containers.map { container in
            DockerContainer(
                id: container.id,
                name: container.name,
                image: container.image,
                status: container.status == .online ? .offline : container.status,
                cpu: container.cpu,
                memoryText: container.memoryText,
                memoryBytes: container.memoryBytes,
                memoryPercent: container.memoryPercent,
                ports: container.ports
            )
        }
        DiagnosticLogStore.shared.record(
            .warning,
            categoryKey: "diagnostics.category.refresh",
            messageKey: "diagnostics.refresh.unreachable",
            details: [
                "target": DiagnosticLogStore.redactedURL(target),
                "consecutiveFailures": "\(consecutiveDSMReachabilityFailures)"
            ]
        )
    }

    private static func isPrivateNetworkHost(_ host: String?) -> Bool {
        NetworkHostClassifier.isPrivate(host)
    }

    func services(in category: ServiceCategory) -> [LaunchpadService] {
        services.filter { $0.category == category }
    }

    func isServiceVisibleOnLaunchpad(_ service: LaunchpadService) -> Bool {
        if let override = serviceVisibilityOverrides[service.launchpadVisibilityKey] { return override }
        if service.source == .container || service.source == .reverseProxy,
           LaunchpadDefaultVisibilityPolicy.isInfrastructureContainer(image: service.detail) { return false }
        if service.source == .container || service.source == .reverseProxy {
            let imageIdentity = ServiceIconRegistry.identity(name: service.detail)
            if imageIdentity.displayName != nil, imageIdentity.defaultVisibilityReason != .recognizedWebUI { return false }
        }
        return service.isLaunchpadVisible
    }

    /// Presentation identity is the real web endpoint, not a friendly product name.
    /// Keep independent instances on different ports/paths and all monitoring records.
    func uniqueLaunchpadServices(_ candidates: [LaunchpadService]) -> [LaunchpadService] {
        var seen = Set<String>()
        return candidates.filter { service in
            guard let endpoint = service.endpoint,
                  var url = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else { return true }
            url.scheme = url.scheme?.lowercased()
            url.host = url.host?.lowercased()
            if (url.scheme == "http" && url.port == 80) || (url.scheme == "https" && url.port == 443) { url.port = nil }
            url.fragment = nil
            if url.path == "/" { url.path = "" }
            guard let key = url.string else { return true }
            return seen.insert(key).inserted
        }
    }

    func orderedLaunchpadServices(_ services: [LaunchpadService]) -> [LaunchpadService] {
        ServiceCategory.allCases.flatMap { category in
            let categoryServices = services.filter { $0.category == category }
            let savedKeys = launchpadServiceOrder[category.rawValue] ?? []
            let servicesByKey = categoryServices.reduce(into: [String: LaunchpadService]()) { result, service in
                result[service.launchpadOrderingKey] = service
            }
            let savedServices = savedKeys.compactMap { servicesByKey[$0] }
            let savedKeySet = Set(savedKeys)
            let newServices = categoryServices.filter { !savedKeySet.contains($0.launchpadOrderingKey) }
            return savedServices + newServices
        }
    }

    @MainActor
    func moveLaunchpadServices(
        in category: ServiceCategory,
        services: [LaunchpadService],
        from source: IndexSet,
        to destination: Int
    ) {
        guard services.allSatisfy({ $0.category == category }) else { return }
        var orderedKeys = services.map(\.launchpadOrderingKey)
        orderedKeys.move(fromOffsets: source, toOffset: destination)
        launchpadServiceOrder[category.rawValue] = orderedKeys
        launchpadOrderStore.save(launchpadServiceOrder)
        noteLocalChange()
    }

    @MainActor
    func setService(_ service: LaunchpadService, visibleOnLaunchpad isVisible: Bool) {
        if isVisible == service.isLaunchpadVisible {
            serviceVisibilityOverrides.removeValue(forKey: service.launchpadVisibilityKey)
        } else {
            serviceVisibilityOverrides[service.launchpadVisibilityKey] = isVisible
        }
        launchpadVisibilityStore.save(serviceVisibilityOverrides)
        noteLocalChange()
        lastRefreshSummaryKey = isVisible ? "launchpad.service.shown" : "launchpad.service.hidden"
    }

    @MainActor
    func resetLaunchpadServiceVisibility() {
        serviceVisibilityOverrides.removeAll()
        launchpadVisibilityStore.save(serviceVisibilityOverrides)
        noteLocalChange()
        lastRefreshSummaryKey = "launchpad.services.reset_done"
    }

    @MainActor
    func addManualService(name: String, endpoint: URL, category: ServiceCategory, iconText: String) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !normalizedName.isEmpty,
            normalizedName.count <= 80,
            UserConfiguredServiceURLPolicy.allows(endpoint)
        else {
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.launchpad",
                messageKey: "diagnostics.manual_service.rejected"
            )
            return
        }
        let service = manualServiceStore.add(
            name: normalizedName,
            endpoint: endpoint,
            category: category,
            iconText: iconText
        )
        services.append(service)
        noteLocalChange()
        lastRefreshSummaryKey = "manual.service.added"
    }

    @MainActor
    func deleteManualService(id: UUID) {
        manualServiceStore.delete(id: id)
        services.removeAll { $0.id == id && $0.source == .manual }
        noteLocalChange()
        lastRefreshSummaryKey = "manual.service.deleted"
    }

    func mediaItems(for service: LaunchpadService) -> [MediaItem] {
        service.name == "Navidrome" ? audioLibraryItems : videoLibraryItems
    }

    @MainActor
    func addTask(_ task: TaskItem) {
        tasks.insert(task, at: 0)
        persistTasks()
        scheduleReminder(task, requestsAuthorization: true)
    }

    @MainActor
    func setTask(_ task: TaskItem, muted isMuted: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isMuted = isMuted
        persistTasks()
        scheduleReminder(tasks[index], requestsAuthorization: false)
    }

    @MainActor
    func completeTask(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var completedTask = tasks.remove(at: index)
        completedTask.completedAt = Date()
        completedTasks.insert(completedTask, at: 0)
        persistTasks()
        cancelReminder(completedTask)
    }

    private func scheduleReminder(_ task: TaskItem, requestsAuthorization: Bool) {
        guard !isOfflineFixture else { return }
        ReminderNotificationScheduler.schedule(task, requestsAuthorization: requestsAuthorization)
    }

    private func cancelReminder(_ task: TaskItem) {
        guard !isOfflineFixture else { return }
        ReminderNotificationScheduler.cancel(task)
    }

    private func noteLocalChange() {
        guard !isOfflineFixture else { return }
        CloudSyncStore.noteLocalChange()
    }

    private func persistTasks() {
        localTaskStore.save(pending: tasks, history: completedTasks)
        noteLocalChange()
    }

    @MainActor
    func makeCloudSyncSnapshot(updatedAt: Date) -> CloudSyncSnapshot {
        let defaults = UserDefaults.standard
        let taskState = LocalTaskStore.normalizedState(pending: tasks, history: completedTasks)
        let stringKeys = [
            LaunchpadTheme.storageKey,
            AppLanguage.storageKey,
            AppThemeMode.storageKey,
            AppearancePreferenceKeys.groupOrder
        ]
        let booleanKeys = [
            AppearancePreferenceKeys.compactMetrics,
            AppearancePreferenceKeys.showServiceStatus,
            AppearancePreferenceKeys.showCardSubtitle,
            AppearancePreferenceKeys.groupFavoritesExpanded,
            AppearancePreferenceKeys.groupMediaExpanded,
            AppearancePreferenceKeys.groupDownloadsExpanded,
            AppearancePreferenceKeys.groupNetworkExpanded,
            AppearancePreferenceKeys.groupToolsExpanded
        ]
        return CloudSyncSnapshot(
            updatedAt: updatedAt,
            manualServices: manualServiceStore.exportForSync(),
            serviceVisibilityOverrides: serviceVisibilityOverrides,
            pendingTasks: taskState.pending,
            completedTasks: taskState.history,
            stringPreferences: Dictionary(uniqueKeysWithValues: stringKeys.compactMap { key in
                defaults.string(forKey: key).map { (key, $0) }
            }),
            booleanPreferences: Dictionary(uniqueKeysWithValues: booleanKeys.compactMap { key in
                defaults.object(forKey: key).map { _ in (key, defaults.bool(forKey: key)) }
            })
        )
    }

    @MainActor
    func applyCloudSyncSnapshot(_ snapshot: CloudSyncSnapshot) {
        guard !isOfflineFixture else { return }
        snapshot.stringPreferences.forEach { UserDefaults.standard.set($0.value, forKey: $0.key) }
        snapshot.booleanPreferences.forEach { UserDefaults.standard.set($0.value, forKey: $0.key) }
        manualServiceStore.replaceFromSync(snapshot.manualServices)
        serviceVisibilityOverrides = snapshot.serviceVisibilityOverrides
        launchpadVisibilityStore.save(serviceVisibilityOverrides)
        let taskState = LocalTaskStore.normalizedState(
            pending: snapshot.pendingTasks,
            history: snapshot.completedTasks
        )
        tasks.forEach(cancelReminder)
        tasks = taskState.pending
        completedTasks = taskState.history
        localTaskStore.save(pending: tasks, history: completedTasks)
        tasks.forEach {
            scheduleReminder($0, requestsAuthorization: false)
        }
        let nonManualServices = services.filter { $0.source != .manual }
        services = nonManualServices + manualServiceStore.load()
        lastRefreshSummaryKey = "mine.sync.applied"
    }

    func selectDiscoveredDevice(_ discoveredDevice: DiscoveredNASDevice) -> NASDevice {
        NASDevice(
            id: device.id,
            name: discoveredDevice.name,
            subtitle: device.subtitle,
            model: device.model,
            dsmVersion: device.dsmVersion,
            mode: device.mode,
            cpu: device.cpu,
            memory: device.memory,
            memoryUsedText: device.memoryUsedText,
            memoryTotalText: device.memoryTotalText,
            storageUsed: device.storageUsed,
            storageUsedText: device.storageUsedText,
            storageTotalText: device.storageTotalText,
            storageFreeText: device.storageFreeText,
            uptimeMinutes: device.uptimeMinutes,
            temperatureText: device.temperatureText,
            certificate: device.certificate,
            sshStatus: device.sshStatus
        )
    }
}

enum PlusStatus {
    case free
    case active
    case expired

    var titleKey: String {
        switch self {
        case .free: return "plus.status.free"
        case .active: return "plus.status.active"
        case .expired: return "plus.status.expired"
        }
    }
}

enum PlusFeature: String {
    case unlimitedCards
    case multipleDevices
    case iCloudSync
    case advancedThemes
    case moreReminders
}

enum LaunchpadTheme: String, CaseIterable, Identifiable, Hashable {
    case cleanGrid
    case commandCenter
    case glassDeck

    static let storageKey = "appearance.launchpadTheme"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .cleanGrid: return "mine.appearance.theme.clean_grid"
        case .commandCenter: return "mine.appearance.theme.command_center"
        case .glassDeck: return "mine.appearance.theme.glass_deck"
        }
    }

    var descriptionKey: String {
        switch self {
        case .cleanGrid: return "mine.appearance.theme.clean_grid.description"
        case .commandCenter: return "mine.appearance.theme.command_center.description"
        case .glassDeck: return "mine.appearance.theme.glass_deck.description"
        }
    }

    var symbolName: String {
        switch self {
        case .cleanGrid: return "rectangle.grid.1x2"
        case .commandCenter: return "sidebar.left"
        case .glassDeck: return "sparkles"
        }
    }

    var isPremium: Bool {
        self != .cleanGrid
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans
    case en

    static let storageKey = "appearance.appLanguage"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system: return "mine.appearance.language.system"
        case .zhHans: return "mine.appearance.language.zh_hans"
        case .en: return "mine.appearance.language.en"
        }
    }

    /// Text views follow `locale` right away. Strings built outside a view use the bundle's
    /// language, which the system fixes when the app launches, so this takes effect on relaunch.
    func applyToBundleLanguageOnNextLaunch(_ defaults: UserDefaults = .standard) {
        switch self {
        case .system: defaults.removeObject(forKey: "AppleLanguages")
        case .zhHans: defaults.set(["zh-Hans"], forKey: "AppleLanguages")
        case .en: defaults.set(["en"], forKey: "AppleLanguages")
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .zhHans: return Locale(identifier: "zh-Hans")
        case .en: return Locale(identifier: "en")
        }
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearance.themeMode"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system: return "mine.appearance.display.system"
        case .light: return "mine.appearance.display.light"
        case .dark: return "mine.appearance.display.dark"
        }
    }
}

enum AppearancePreferenceKeys {
    static let compactMetrics = "appearance.compactMetrics"
    static let showServiceStatus = "appearance.showServiceStatus"
    static let showCardSubtitle = "appearance.card.showSubtitle"
    static let groupFavoritesExpanded = "appearance.group.favoritesExpanded"
    static let groupMediaExpanded = "appearance.group.mediaExpanded"
    static let groupDownloadsExpanded = "appearance.group.downloadsExpanded"
    static let groupNetworkExpanded = "appearance.group.networkExpanded"
    static let groupToolsExpanded = "appearance.group.toolsExpanded"
    static let groupOrder = "appearance.group.order"
    static let groupDefaultVersion = "appearance.group.defaultVersion"
}

final class AppearanceStore: ObservableObject {
    /// 偏好域与“本地改动”通知均可注入；默认值与以往完全一致（标准偏好域 + iCloud 本地改动标记）。
    /// 隔离宿主（离线界面测试）传入临时偏好域与空通知，避免触碰用户数据或同步。
    private let defaults: UserDefaults
    private let noteChange: () -> Void

    @Published var launchpadTheme: LaunchpadTheme {
        didSet {
            defaults.set(launchpadTheme.rawValue, forKey: LaunchpadTheme.storageKey)
            noteChange()
        }
    }

    @Published var compactMetrics: Bool {
        didSet {
            defaults.set(compactMetrics, forKey: AppearancePreferenceKeys.compactMetrics)
            noteChange()
        }
    }

    @Published var showServiceStatus: Bool {
        didSet {
            defaults.set(showServiceStatus, forKey: AppearancePreferenceKeys.showServiceStatus)
            noteChange()
        }
    }

    init(defaults: UserDefaults = .standard,
         noteChange: @escaping () -> Void = { CloudSyncStore.noteLocalChange() }) {
        self.defaults = defaults
        self.noteChange = noteChange
        let savedTheme = defaults.string(forKey: LaunchpadTheme.storageKey)
        launchpadTheme = savedTheme.flatMap(LaunchpadTheme.init(rawValue:)) ?? .cleanGrid
        compactMetrics = defaults.object(forKey: AppearancePreferenceKeys.compactMetrics) as? Bool ?? true
        showServiceStatus = defaults.object(forKey: AppearancePreferenceKeys.showServiceStatus) as? Bool ?? true
    }

    @MainActor
    func reloadFromDefaults() {
        launchpadTheme = defaults.string(forKey: LaunchpadTheme.storageKey)
            .flatMap(LaunchpadTheme.init(rawValue:)) ?? .cleanGrid
        compactMetrics = defaults.object(forKey: AppearancePreferenceKeys.compactMetrics) as? Bool ?? true
        showServiceStatus = defaults.object(forKey: AppearancePreferenceKeys.showServiceStatus) as? Bool ?? true
    }
}

/// “清理缓存与网页数据”的步骤序列。只负责按顺序执行并汇总结果，不含界面；
/// 确认/取消由界面层决定（取消时根本不会创建或调用它）。
/// 某一步失败不会跳过后面的步骤；失败的步骤名只用于判断是否“部分未清除”，不含路径或内容。
struct PrivacyCacheCleaner {
    struct Step {
        let name: String
        let run: @MainActor () async throws -> Void
    }

    enum Outcome: Equatable {
        case cleared
        case partial(failedSteps: [String])
    }

    let steps: [Step]

    @MainActor
    func clear() async -> Outcome {
        var failed: [String] = []
        for step in steps {
            do {
                try await step.run()
            } catch {
                failed.append(step.name)
            }
        }
        return failed.isEmpty ? .cleared : .partial(failedSteps: failed)
    }

    /// 删除 `base` 下指定名称的目录。目录不存在视为成功；
    /// 其余错误在全部目录都尝试后再抛出第一个，避免一处失败导致另一处不再清理。
    static func removeTemporaryDirectories(named names: [String], in base: URL,
                                           fileManager: FileManager = .default) throws {
        var firstError: Error?
        for name in names {
            let url = base.appendingPathComponent(name, isDirectory: true)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                try fileManager.removeItem(at: url)
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError { throw firstError }
    }
}

final class EntitlementStore: ObservableObject {
    @Published private(set) var plusStatus: PlusStatus

    init(plusStatus: PlusStatus = .free) {
#if DEBUG
        self.plusStatus = .active
#else
        self.plusStatus = plusStatus
#endif
    }

    var hasPlus: Bool {
#if DEBUG
        true
#else
        plusStatus == .active
#endif
    }

    func canUse(_ feature: PlusFeature) -> Bool {
        switch feature {
        case .unlimitedCards, .multipleDevices, .iCloudSync, .advancedThemes, .moreReminders:
            return hasPlus
        }
    }

}
