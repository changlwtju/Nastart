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

struct DSMSession {
    let baseURL: URL
    let sid: String
    let fileStationSID: String?
    let account: String
    let allowsSelfSignedCertificates: Bool
    let deviceID: String?
    let endpoints: DSMConnectionEndpoints
    let actualRoute: DSMConnectionRoute

    init(
        baseURL: URL,
        sid: String,
        fileStationSID: String?,
        account: String,
        allowsSelfSignedCertificates: Bool,
        deviceID: String?,
        endpoints: DSMConnectionEndpoints? = nil,
        actualRoute: DSMConnectionRoute? = nil
    ) {
        let resolvedEndpoints = endpoints ?? DSMConnectionEndpoints(legacyBaseURL: baseURL)
        self.baseURL = baseURL
        self.sid = sid
        self.fileStationSID = fileStationSID
        self.account = account
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.deviceID = deviceID
        self.endpoints = resolvedEndpoints
        self.actualRoute = actualRoute ?? DSMConnectionRouteResolver.route(
            for: baseURL,
            endpoints: resolvedEndpoints
        )
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

    init(
        baseURLString: String,
        account: String,
        password: String,
        useAgent: Bool,
        allowsSelfSignedCertificates: Bool = false,
        deviceID: String? = nil,
        endpoints: DSMConnectionEndpoints? = nil,
        lastKnownRoute: DSMConnectionRoute? = nil
    ) {
        self.baseURLString = baseURLString
        self.account = account
        self.password = password
        self.useAgent = useAgent
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.deviceID = deviceID
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURLString = try container.decode(String.self, forKey: .baseURLString)
        account = try container.decode(String.self, forKey: .account)
        password = try container.decode(String.self, forKey: .password)
        useAgent = try container.decode(Bool.self, forKey: .useAgent)
        allowsSelfSignedCertificates = try container.decodeIfPresent(Bool.self, forKey: .allowsSelfSignedCertificates) ?? false
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID)
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
    @Published private(set) var isRestoringConnection = false
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
    private var manualServiceStore = ManualLaunchpadServiceStore()
    private let launchpadVisibilityStore = LaunchpadVisibilityStore()
    private let launchpadOrderStore = LaunchpadOrderStore()
    private let localTaskStore: LocalTaskStore
    private var preservedContainerInventoryOnLastMerge = false
    private var consecutiveDSMReachabilityFailures = 0
    private var lastSuccessfulDSMContactAt: Date?
    private var lastForegroundRefreshAt: Date?
    private var serviceHealthRefreshID: UUID?
    private var connectionGeneration = UUID()
    private var activeRefreshID: UUID?
    private struct FolderCacheEntry {
        let items: [FileItem]
        let loadedAt: Date
    }
    private var folderCache: [String: FolderCacheEntry] = [:]
    private var folderLoadTasks: [String: Task<[FileItem], Error>] = [:]
    private var folderCacheScope: String?

    private static let foregroundRefreshCooldown: TimeInterval = 90
    private static let foregroundFreshnessInterval: TimeInterval = 5 * 60
    private static let folderCacheLifetime: TimeInterval = 5 * 60

    init(provider: AppDataProviding? = nil) {
        let taskStore = LocalTaskStore()
        let persistedTasks = taskStore.load()
        let persistedSnapshot = Self.loadPersistedDSMSnapshot()
        let initialProvider = provider
            ?? persistedSnapshot?.snapshot
            ?? DisconnectedAppDataProvider()
        self.provider = initialProvider
        localTaskStore = taskStore
        serviceVisibilityOverrides = LaunchpadVisibilityStore().load()
        launchpadServiceOrder = LaunchpadOrderStore().load()
        sourceKind = initialProvider is DSMDataSnapshot ? .dsm : .mock
        cachedDSMSnapshotSavedAt = provider == nil ? persistedSnapshot?.savedAt : nil
        activeDataSource = DisconnectedNASDataSource()
        device = initialProvider.device
        agentHealth = initialProvider.agentHealth
        services = (initialProvider.services + manualServiceStore.load()).map {
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
            ReminderNotificationScheduler.schedule($0, requestsAuthorization: false)
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
        if let snapshot = provider as? DSMDataSnapshot, persistSnapshot, !Self.isProvisionalDSMSnapshot(snapshot) {
            cachedDSMSnapshotSavedAt = Date()
            Self.persistDSMSnapshot(snapshot, savedAt: cachedDSMSnapshotSavedAt ?? Date())
        } else if !(provider is DSMDataSnapshot) {
            cachedDSMSnapshotSavedAt = nil
        }
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
        let probed = await ServiceHealthProbe.check(representatives)
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
        Self.removePersistedDSMSnapshot()
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
        Self.removePersistedDSMSnapshot()
        folderLoadTasks.values.forEach { $0.cancel() }
        folderLoadTasks.removeAll()
        folderCache.removeAll()
        folderCacheScope = nil
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
        if let session = connectionStore.dsmSession {
            _ = await refreshDSM(session: session, useAgent: connectionStore.usesAgent)
        } else {
            await restoreDSMConnection(using: connectionStore)
        }
    }

    /// Lightweight foreground monitoring, separate from the expensive inventory refresh.
    @MainActor
    func monitorConnectivity(using connectionStore: NASConnectionStore) async {
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
    func refreshForForeground(using connectionStore: NASConnectionStore) async {
        guard !isRefreshing else { return }
        let now = Date()
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
            isForegroundRefreshing = true
            defer { isForegroundRefreshing = false }
            _ = await refreshDSM(session: session, useAgent: connectionStore.usesAgent)
            return
        }

        guard KeychainStore.shared.loadNASCredential() != nil else {
            return
        }
        isForegroundRefreshing = true
        defer { isForegroundRefreshing = false }
        await restoreDSMConnection(using: connectionStore)
    }

    @MainActor
    @discardableResult
    func refreshDSM(session: DSMSession, useAgent: Bool) async -> Bool {
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
        let reachable = await dataSource.isReachable()
        guard !Task.isCancelled, activeRefreshID == refreshID else { return false }
        guard reachable else {
            handleDSMReachabilityFailure(target: session.baseURL)
            return false
        }

        recordSuccessfulDSMContact()
        let snapshot = await dataSource.loadSnapshot()
        guard !Task.isCancelled, activeRefreshID == refreshID else { return false }
        reload(from: snapshot)
        sourceKind = dataSource.kind
        recordSuccessfulDSMContact()
        return true
    }

    @MainActor
    private func invalidateActiveRefresh() {
        activeRefreshID = nil
        isRefreshing = false
        isRestoringConnection = false
        isForegroundRefreshing = false
    }

    @MainActor
    func activateDSM(
        snapshot: DSMDataSnapshot,
        session: DSMSession,
        useAgent: Bool,
        persistSnapshot: Bool = true
    ) {
        let dataSource = DSMNASDataSource(session: session, useAgent: useAgent)
        prepareFolderCache(for: dataSource)
        activeDataSource = dataSource
        reload(from: snapshot, persistSnapshot: persistSnapshot)
        sourceKind = .dsm
        Task { await refreshServiceHealth() }
    }

    @MainActor
    func activateDSMSession(session: DSMSession, useAgent: Bool) {
        if activeRefreshID != nil { invalidateActiveRefresh() }
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
        return DSMSession(
            baseURL: session.baseURL,
            sid: session.sid,
            fileStationSID: session.fileStationSID,
            account: session.account,
            allowsSelfSignedCertificates: session.allowsSelfSignedCertificates,
            deviceID: session.deviceID,
            endpoints: session.endpoints.removingLANAddress(),
            actualRoute: session.actualRoute
        )
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
        return DSMSession(
            baseURL: session.baseURL,
            sid: session.sid,
            fileStationSID: session.fileStationSID,
            account: session.account,
            allowsSelfSignedCertificates: session.allowsSelfSignedCertificates,
            deviceID: session.deviceID,
            endpoints: endpoints,
            actualRoute: session.actualRoute
        )
    }

    @MainActor
    private static func discoverSmartLANAddress(for baseURL: URL) async -> URL? {
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
        let cachedEntry = folderCache[normalizedPath]
        if !forceRefresh,
           let cachedEntry,
           Date().timeIntervalSince(cachedEntry.loadedAt) < Self.folderCacheLifetime {
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.dsm_api",
                messageKey: "diagnostics.files.folder_loaded",
                details: [
                    "pathDepth": "\(normalizedPath.split(separator: "/").count)",
                    "items": "\(cachedEntry.items.count)",
                    "source": "memoryCache",
                    "durationMs": "0"
                ]
            )
            return cachedEntry.items
        }
        if let existingTask = folderLoadTasks[normalizedPath] {
            return try await existingTask.value
        }
        if let dataSource = activeDataSource as? DSMNASDataSource {
            let requestScope = folderCacheScope
            let task = Task {
                try await dataSource.loadFolder(path: normalizedPath)
            }
            folderLoadTasks[normalizedPath] = task
            do {
                let items = try await task.value
                guard requestScope == folderCacheScope else {
                    throw CancellationError()
                }
                folderLoadTasks[normalizedPath] = nil
                folderCache[normalizedPath] = FolderCacheEntry(items: items, loadedAt: Date())
                return items
            } catch {
                folderLoadTasks[normalizedPath] = nil
                guard requestScope == folderCacheScope else { throw CancellationError() }
                DiagnosticLogStore.shared.record(
                    .warning,
                    categoryKey: "diagnostics.category.dsm_api",
                    messageKey: "diagnostics.files.folder_failed",
                    details: [
                        "pathDepth": "\(normalizedPath.split(separator: "/").count)",
                        "error": "\(error)"
                    ]
                )
                if let cachedEntry { return cachedEntry.items }
                let localItems = localChildren(for: normalizedPath, in: files)
                if !localItems.isEmpty { return localItems }
                throw error
            }
        }
        return localChildren(for: normalizedPath, in: files)
    }

    @MainActor
    private func prepareFolderCache(for dataSource: NASDataSource) {
        let newScope: String?
        if let dsmDataSource = dataSource as? DSMNASDataSource {
            newScope = "\(dsmDataSource.session.baseURL.absoluteString)|\(dsmDataSource.session.account)"
        } else {
            newScope = nil
        }
        guard newScope != folderCacheScope else { return }
        folderLoadTasks.values.forEach { $0.cancel() }
        folderLoadTasks.removeAll()
        folderCache.removeAll()
        folderCacheScope = newScope
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
    func restoreDSMConnection(using connectionStore: NASConnectionStore) async {
        guard !isRefreshing else { return }
        guard let credential = KeychainStore.shared.loadNASCredential() else {
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.connection",
                messageKey: "diagnostics.restore.missing_credentials"
            )
            return
        }
        isRefreshing = true
        isRestoringConnection = true
        defer {
            isRefreshing = false
            isRestoringConnection = false
        }
        var sessionToLogout: DSMSession?

        do {
            let baseURL = try DSMClient.normalizedBaseURL(from: credential.baseURLString)
            var endpoints = credential.endpoints.candidates.isEmpty
                ? DSMConnectionEndpoints(legacyBaseURL: baseURL)
                : credential.endpoints
            let usesStoredAgent = KeychainStore.shared.loadAgentConnection() != nil
            let loginResult: DSMLoginResult
            do {
                loginResult = try await DSMClient.login(
                    endpoints: endpoints,
                    allowsSelfSignedCertificates: credential.allowsSelfSignedCertificates,
                    account: credential.account,
                    password: credential.password,
                    deviceID: credential.deviceID,
                    preferredRoute: credential.lastKnownRoute
                )
            } catch {
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
                let discoveredEndpoints = await LANDiscoveryService.discoverDSMEndpoints()
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
                loginResult = try await DSMClient.login(
                    endpoints: endpoints,
                    allowsSelfSignedCertificates: credential.allowsSelfSignedCertificates,
                    account: credential.account,
                    password: credential.password,
                    deviceID: credential.deviceID,
                    preferredRoute: credential.lastKnownRoute
                )
            }
            let client = loginResult.client
            let mainSession = Self.sessionByClearingStaleLANIfNeeded(loginResult.session)
            async let discoveredLANAddress = Self.discoverSmartLANAddress(for: mainSession.baseURL)
            // The authentication session is already usable for live NAS actions.
            // Publish it before the optional File Station session and the full
            // service snapshot, so the UI does not confuse a slow refresh with
            // a disconnected NAS.
            sessionToLogout = mainSession
            activateDSMSession(session: mainSession, useAgent: usesStoredAgent)
            connectionStore.connect(device: device, session: mainSession)

            var session = await client.addingFileStationSession(
                to: mainSession,
                account: credential.account,
                password: credential.password
            )
            session = Self.session(session, addingVerifiedLANAddress: await discoveredLANAddress)
            sessionToLogout = session
            // File playback reads connectionStore directly. Publish the
            // File Station SID and discovered LAN endpoint before the slower
            // full snapshot, so the first playback gets the same candidates
            // as a later reopen.
            guard connectionStore.dsmSession?.sid == mainSession.sid else { return }
            connectionStore.connect(device: device, session: session)
            let dataSource = DSMNASDataSource(session: session, useAgent: usesStoredAgent)
            let snapshot = await dataSource.loadSnapshot()
            guard connectionStore.dsmSession?.sid == mainSession.sid else { return }
            try KeychainStore.shared.saveNASCredential(
                StoredNASCredential(
                    baseURLString: credential.baseURLString,
                    account: credential.account,
                    password: credential.password,
                    useAgent: usesStoredAgent,
                    allowsSelfSignedCertificates: credential.allowsSelfSignedCertificates,
                    deviceID: session.deviceID ?? credential.deviceID,
                    endpoints: session.endpoints,
                    lastKnownRoute: session.actualRoute
                )
            )
            prepareFolderCache(for: dataSource)
            activeDataSource = dataSource
            recordSuccessfulDSMContact()
            reload(from: snapshot)
            sourceKind = dataSource.kind
            connectionStore.connect(device: snapshot.device, session: session)
            sessionToLogout = nil
        } catch {
            isDSMReachable = false
            if let session = sessionToLogout {
                let client = DSMClient(
                    baseURL: session.baseURL,
                    allowsSelfSignedCertificates: session.allowsSelfSignedCertificates
                )
                await client.logout(session: session)
            }
            lastRefreshSummaryKey = "data.refresh.restore_failed"
            DiagnosticLogStore.shared.record(
                .error,
                categoryKey: "diagnostics.category.connection",
                messageKey: "diagnostics.restore.failed",
                details: ["error": Self.restoreDiagnosticMessage(for: error)]
            )
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
        CloudSyncStore.noteLocalChange()
    }

    @MainActor
    func setService(_ service: LaunchpadService, visibleOnLaunchpad isVisible: Bool) {
        if isVisible == service.isLaunchpadVisible {
            serviceVisibilityOverrides.removeValue(forKey: service.launchpadVisibilityKey)
        } else {
            serviceVisibilityOverrides[service.launchpadVisibilityKey] = isVisible
        }
        launchpadVisibilityStore.save(serviceVisibilityOverrides)
        CloudSyncStore.noteLocalChange()
        lastRefreshSummaryKey = isVisible ? "launchpad.service.shown" : "launchpad.service.hidden"
    }

    @MainActor
    func resetLaunchpadServiceVisibility() {
        serviceVisibilityOverrides.removeAll()
        launchpadVisibilityStore.save(serviceVisibilityOverrides)
        CloudSyncStore.noteLocalChange()
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
        CloudSyncStore.noteLocalChange()
        lastRefreshSummaryKey = "manual.service.added"
    }

    @MainActor
    func deleteManualService(id: UUID) {
        manualServiceStore.delete(id: id)
        services.removeAll { $0.id == id && $0.source == .manual }
        CloudSyncStore.noteLocalChange()
        lastRefreshSummaryKey = "manual.service.deleted"
    }

    func mediaItems(for service: LaunchpadService) -> [MediaItem] {
        service.name == "Navidrome" ? audioLibraryItems : videoLibraryItems
    }

    @MainActor
    func addTask(_ task: TaskItem) {
        tasks.insert(task, at: 0)
        persistTasks()
        ReminderNotificationScheduler.schedule(task, requestsAuthorization: true)
    }

    @MainActor
    func setTask(_ task: TaskItem, muted isMuted: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isMuted = isMuted
        persistTasks()
        ReminderNotificationScheduler.schedule(tasks[index], requestsAuthorization: false)
    }

    @MainActor
    func completeTask(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var completedTask = tasks.remove(at: index)
        completedTask.completedAt = Date()
        completedTasks.insert(completedTask, at: 0)
        persistTasks()
        ReminderNotificationScheduler.cancel(completedTask)
    }

    private func persistTasks() {
        localTaskStore.save(pending: tasks, history: completedTasks)
        CloudSyncStore.noteLocalChange()
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
        snapshot.stringPreferences.forEach { UserDefaults.standard.set($0.value, forKey: $0.key) }
        snapshot.booleanPreferences.forEach { UserDefaults.standard.set($0.value, forKey: $0.key) }
        manualServiceStore.replaceFromSync(snapshot.manualServices)
        serviceVisibilityOverrides = snapshot.serviceVisibilityOverrides
        launchpadVisibilityStore.save(serviceVisibilityOverrides)
        let taskState = LocalTaskStore.normalizedState(
            pending: snapshot.pendingTasks,
            history: snapshot.completedTasks
        )
        tasks.forEach(ReminderNotificationScheduler.cancel)
        tasks = taskState.pending
        completedTasks = taskState.history
        localTaskStore.save(pending: tasks, history: completedTasks)
        tasks.forEach {
            ReminderNotificationScheduler.schedule($0, requestsAuthorization: false)
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
    @Published var launchpadTheme: LaunchpadTheme {
        didSet {
            UserDefaults.standard.set(launchpadTheme.rawValue, forKey: LaunchpadTheme.storageKey)
            CloudSyncStore.noteLocalChange()
        }
    }

    @Published var compactMetrics: Bool {
        didSet {
            UserDefaults.standard.set(compactMetrics, forKey: AppearancePreferenceKeys.compactMetrics)
            CloudSyncStore.noteLocalChange()
        }
    }

    @Published var showServiceStatus: Bool {
        didSet {
            UserDefaults.standard.set(showServiceStatus, forKey: AppearancePreferenceKeys.showServiceStatus)
            CloudSyncStore.noteLocalChange()
        }
    }

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: LaunchpadTheme.storageKey)
        launchpadTheme = savedTheme.flatMap(LaunchpadTheme.init(rawValue:)) ?? .cleanGrid
        compactMetrics = UserDefaults.standard.object(forKey: AppearancePreferenceKeys.compactMetrics) as? Bool ?? true
        showServiceStatus = UserDefaults.standard.object(forKey: AppearancePreferenceKeys.showServiceStatus) as? Bool ?? true
    }

    @MainActor
    func reloadFromDefaults() {
        let defaults = UserDefaults.standard
        launchpadTheme = defaults.string(forKey: LaunchpadTheme.storageKey)
            .flatMap(LaunchpadTheme.init(rawValue:)) ?? .cleanGrid
        compactMetrics = defaults.object(forKey: AppearancePreferenceKeys.compactMetrics) as? Bool ?? true
        showServiceStatus = defaults.object(forKey: AppearancePreferenceKeys.showServiceStatus) as? Bool ?? true
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
