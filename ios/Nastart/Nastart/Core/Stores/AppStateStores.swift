import Foundation
import Combine
import Security

protocol AppDataProviding {
    var device: NASDevice { get }
    var services: [LaunchpadService] { get }
    var containers: [DockerContainer] { get }
    var files: [FileItem] { get }
    var tasks: [TaskItem] { get }
    var videoLibraryItems: [MediaItem] { get }
    var audioLibraryItems: [MediaItem] { get }
    var discoveredDevices: [DiscoveredNASDevice] { get }
}

enum NASDataSourceKind {
    case mock
    case dsm
    case agent
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
    let useAgent: Bool
    let client: DSMClient

    var kind: NASDataSourceKind {
        useAgent ? .agent : .dsm
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
        await client.loadSnapshot(session: session, useAgent: useAgent)
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
        mode: .manualOnly,
        cpu: 0,
        memory: 0,
        storageUsed: 0,
        storageFreeText: "-",
        uptimeText: "-",
        certificateDaysRemaining: 999
    )
    let services: [LaunchpadService] = []
    let containers: [DockerContainer] = []
    let files: [FileItem] = []
    let tasks: [TaskItem] = []
    let videoLibraryItems: [MediaItem] = []
    let audioLibraryItems: [MediaItem] = []
    let discoveredDevices: [DiscoveredNASDevice] = []
}

struct DSMSession {
    let baseURL: URL
    let sid: String
    let account: String
    let allowsSelfSignedCertificates: Bool
}

struct StoredNASCredential: Codable {
    let baseURLString: String
    let account: String
    let password: String
    let useAgent: Bool
    let allowsSelfSignedCertificates: Bool

    init(
        baseURLString: String,
        account: String,
        password: String,
        useAgent: Bool,
        allowsSelfSignedCertificates: Bool = false
    ) {
        self.baseURLString = baseURLString
        self.account = account
        self.password = password
        self.useAgent = useAgent
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
    }

    enum CodingKeys: String, CodingKey {
        case baseURLString
        case account
        case password
        case useAgent
        case allowsSelfSignedCertificates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURLString = try container.decode(String.self, forKey: .baseURLString)
        account = try container.decode(String.self, forKey: .account)
        password = try container.decode(String.self, forKey: .password)
        useAgent = try container.decode(Bool.self, forKey: .useAgent)
        allowsSelfSignedCertificates = try container.decodeIfPresent(Bool.self, forKey: .allowsSelfSignedCertificates) ?? false
    }
}

struct DSMDataSnapshot: AppDataProviding {
    let device: NASDevice
    let services: [LaunchpadService]
    let containers: [DockerContainer]
    let files: [FileItem]
    let tasks: [TaskItem]
    let videoLibraryItems: [MediaItem]
    let audioLibraryItems: [MediaItem]
    let discoveredDevices: [DiscoveredNASDevice]
}

enum DiagnosticLogLevel: String {
    case info
    case warning
    case error

    var titleKey: String {
        switch self {
        case .info: return "diagnostics.level.info"
        case .warning: return "diagnostics.level.warning"
        case .error: return "diagnostics.level.error"
        }
    }
}

struct DiagnosticLogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let level: DiagnosticLogLevel
    let categoryKey: String
    let messageKey: String
    let detail: String

    var exportLine: String {
        let timestamp = Self.timestampFormatter.string(from: date)
        let localizedCategory = NSLocalizedString(categoryKey, comment: "")
        let localizedMessage = NSLocalizedString(messageKey, comment: "")
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDetail.isEmpty {
            return "[\(timestamp)] \(level.rawValue.uppercased()) \(localizedCategory) - \(localizedMessage)"
        }
        return "[\(timestamp)] \(level.rawValue.uppercased()) \(localizedCategory) - \(localizedMessage) | \(trimmedDetail)"
    }

    var displayTime: String {
        Self.displayFormatter.string(from: date)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

final class DiagnosticLogStore: ObservableObject {
    static let shared = DiagnosticLogStore()

    @Published private(set) var entries: [DiagnosticLogEntry] = []

    private let maxEntries = 200

    private init() {}

    func record(
        _ level: DiagnosticLogLevel,
        categoryKey: String,
        messageKey: String,
        details: [String: String] = [:]
    ) {
        let detail = details
            .filter { !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")

        Task { @MainActor in
            self.append(DiagnosticLogEntry(
                date: Date(),
                level: level,
                categoryKey: categoryKey,
                messageKey: messageKey,
                detail: detail
            ))
        }
    }

    @MainActor
    func clear() {
        entries.removeAll()
    }

    @MainActor
    func exportText() -> String {
        if entries.isEmpty {
            return NSLocalizedString("diagnostics.empty", comment: "")
        }
        return entries.map(\.exportLine).joined(separator: "\n")
    }

    static func redactedHost(_ host: String?) -> String {
        guard let host, !host.isEmpty else { return "-" }
        let parts = host.split(separator: ".").map(String.init)
        if parts.count == 4, parts.allSatisfy({ Int($0) != nil }) {
            return "\(parts[0]).\(parts[1]).*.*"
        }
        guard host.count > 8 else { return host }
        let prefix = host.prefix(3)
        let suffix = host.suffix(5)
        return "\(prefix)...\(suffix)"
    }

    static func redactedURL(_ url: URL) -> String {
        let host = redactedHost(url.host)
        if let port = url.port {
            return "\(url.scheme ?? "https")://\(host):\(port)"
        }
        return "\(url.scheme ?? "https")://\(host)"
    }

    private func append(_ entry: DiagnosticLogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}

enum DSMClientError: LocalizedError {
    case invalidAddress
    case insecureHTTP
    case invalidResponse
    case apiFailed(code: Int?)
    case missingSession

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return NSLocalizedString("connect.error.invalid_address", comment: "")
        case .insecureHTTP:
            return NSLocalizedString("connect.error.insecure_http", comment: "")
        case .invalidResponse:
            return NSLocalizedString("connect.error.invalid_response", comment: "")
        case .apiFailed(let code):
            if code == 403 || code == 404 {
                return NSLocalizedString("connect.error.otp_required", comment: "")
            }
            if let code {
                return String(format: NSLocalizedString("connect.error.api_code", comment: ""), code)
            }
            return NSLocalizedString("connect.error.api", comment: "")
        case .missingSession:
            return NSLocalizedString("connect.error.missing_session", comment: "")
        }
    }
}

private enum DSMJSONValue: Decodable {
    case object([String: DSMJSONValue])
    case array([DSMJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: DSMJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([DSMJSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    var objectValue: [String: DSMJSONValue]? {
        if case .object(let object) = self { return object }
        return nil
    }

    var arrayValue: [DSMJSONValue]? {
        if case .array(let array) = self { return array }
        return nil
    }

    var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .number(let value): return DSMFormatters.shortNumber(value)
        case .bool(let value): return value ? "true" : "false"
        case .object, .array, .null: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value): return value
        case .string(let value): return Double(value)
        case .bool(let value): return value ? 1 : 0
        case .object, .array, .null: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        case .number(let value):
            return value != 0
        case .string(let value):
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "yes", "enabled", "running", "started", "1"].contains(normalized) { return true }
            if ["false", "no", "disabled", "stopped", "0"].contains(normalized) { return false }
            return nil
        case .object, .array, .null:
            return nil
        }
    }

    subscript(key: String) -> DSMJSONValue? {
        objectValue?[key]
    }

    func firstValue(for keys: [String]) -> DSMJSONValue? {
        for key in keys {
            if let value = firstValue(for: key) {
                return value
            }
        }
        return nil
    }

    func firstString(for keys: [String]) -> String? {
        firstValue(for: keys)?.stringValue
    }

    func firstDouble(for keys: [String]) -> Double? {
        firstValue(for: keys)?.doubleValue
    }

    func firstBool(for keys: [String]) -> Bool? {
        firstValue(for: keys)?.boolValue
    }

    func firstArray(for keys: [String]) -> [DSMJSONValue]? {
        firstValue(for: keys)?.arrayValue
    }

    private func firstValue(for key: String) -> DSMJSONValue? {
        switch self {
        case .object(let object):
            if let value = object[key] {
                return value
            }
            for child in object.values {
                if let value = child.firstValue(for: key) {
                    return value
                }
            }
        case .array(let array):
            for child in array {
                if let value = child.firstValue(for: key) {
                    return value
                }
            }
        case .string, .number, .bool, .null:
            break
        }
        return nil
    }
}

private struct DSMAPIEnvelope: Decodable {
    let success: Bool
    let data: DSMJSONValue?
    let error: DSMAPIErrorPayload?
}

private struct DSMAPIErrorPayload: Decodable {
    let code: Int?
}

private enum DSMFormatters {
    static func shortNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    static func percentage(_ value: Double?) -> Double {
        guard let value else { return 0 }
        if value > 1 {
            return min(max(value / 100, 0), 1)
        }
        return min(max(value, 0), 1)
    }

    static func bytes(_ value: Double?) -> String? {
        guard let value, value > 0 else { return nil }
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var amount = value
        var index = 0
        while amount >= 1024, index < units.count - 1 {
            amount /= 1024
            index += 1
        }
        let valueText = amount >= 10 ? String(format: "%.0f", amount) : String(format: "%.1f", amount)
        return "\(valueText) \(units[index])"
    }
}

private final class DSMCertificateTrustDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

final class DSMClient {
    private let baseURL: URL
    private let urlSession: URLSession
    private let allowsSelfSignedCertificates: Bool
    private let sessionDelegate: URLSessionDelegate?

    init(
        baseURL: URL,
        allowsSelfSignedCertificates: Bool = false,
        urlSession: URLSession? = nil
    ) {
        self.baseURL = baseURL
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates

        if let urlSession {
            self.urlSession = urlSession
            self.sessionDelegate = nil
        } else if allowsSelfSignedCertificates {
            let delegate = DSMCertificateTrustDelegate()
            self.sessionDelegate = delegate
            self.urlSession = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        } else {
            self.urlSession = .shared
            self.sessionDelegate = nil
        }
    }

    private func record(
        _ level: DiagnosticLogLevel,
        categoryKey: String,
        messageKey: String,
        details: [String: String] = [:]
    ) {
        DiagnosticLogStore.shared.record(level, categoryKey: categoryKey, messageKey: messageKey, details: details)
    }

    static func normalizedBaseURL(from input: String) throws -> URL {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw DSMClientError.invalidAddress }
        if !value.contains("://") {
            value = "https://\(value)"
        }
        guard var components = URLComponents(string: value), components.host != nil else {
            throw DSMClientError.invalidAddress
        }
        if components.scheme?.lowercased() == "http" {
            throw DSMClientError.insecureHTTP
        }
        if components.path == "/" {
            components.path = ""
        }
        guard let url = components.url else { throw DSMClientError.invalidAddress }
        return url
    }

    func login(account: String, password: String, oneTimeCode: String = "") async throws -> DSMSession {
        record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.login.started",
            details: [
                "target": DiagnosticLogStore.redactedURL(baseURL),
                "account": DiagnosticLogStore.redactedHost(account),
                "2fa": oneTimeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "off" : "on",
                "selfSigned": allowsSelfSignedCertificates ? "on" : "off"
            ]
        )

        let apiInfo = await optionalCall(
            path: "/webapi/query.cgi",
            queryItems: [
                URLQueryItem(name: "api", value: "SYNO.API.Info"),
                URLQueryItem(name: "version", value: "1"),
                URLQueryItem(name: "method", value: "query"),
                URLQueryItem(name: "query", value: "SYNO.API.Auth")
            ]
        )
        record(
            apiInfo == nil ? .warning : .info,
            categoryKey: "diagnostics.category.dsm_api",
            messageKey: apiInfo == nil ? "diagnostics.api_info.missing" : "diagnostics.api_info.loaded",
            details: ["api": "SYNO.API.Auth"]
        )

        let cleanedCode = oneTimeCode.trimmingCharacters(in: .whitespacesAndNewlines)
        for request in authLoginRequests(
            account: account,
            password: password,
            oneTimeCode: cleanedCode,
            apiInfo: apiInfo
        ) {
            do {
                let data = try await call(path: request.0, queryItems: request.1)
                if let sid = data.firstString(for: ["sid"]) {
                    record(
                        .info,
                        categoryKey: "diagnostics.category.connection",
                        messageKey: "diagnostics.login.succeeded",
                        details: requestSummary(path: request.0, queryItems: request.1)
                    )
                    return DSMSession(
                        baseURL: baseURL,
                        sid: sid,
                        account: account,
                        allowsSelfSignedCertificates: allowsSelfSignedCertificates
                    )
                }
            } catch {
                record(
                    .warning,
                    categoryKey: "diagnostics.category.connection",
                    messageKey: "diagnostics.login.attempt_failed",
                    details: requestSummary(path: request.0, queryItems: request.1).merging(["error": diagnosticMessage(for: error)]) { current, _ in current }
                )
                continue
            }
        }
        record(
            .error,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.login.failed",
            details: ["target": DiagnosticLogStore.redactedURL(baseURL)]
        )
        throw DSMClientError.missingSession
    }

    func logout(session: DSMSession) async {
        _ = try? await call(
            path: "/webapi/auth.cgi",
            queryItems: [
                URLQueryItem(name: "api", value: "SYNO.API.Auth"),
                URLQueryItem(name: "version", value: "6"),
                URLQueryItem(name: "method", value: "logout"),
                URLQueryItem(name: "session", value: "Nastart"),
                URLQueryItem(name: "_sid", value: session.sid)
            ]
        )
    }

    func loadSnapshot(session: DSMSession, useAgent: Bool) async -> DSMDataSnapshot {
        record(
            .info,
            categoryKey: "diagnostics.category.dsm_api",
            messageKey: "diagnostics.snapshot.started",
            details: ["target": DiagnosticLogStore.redactedURL(session.baseURL)]
        )

        let apiInfo = await optionalCall(
            path: "/webapi/query.cgi",
            queryItems: [
                URLQueryItem(name: "api", value: "SYNO.API.Info"),
                URLQueryItem(name: "version", value: "1"),
                URLQueryItem(name: "method", value: "query"),
                URLQueryItem(
                    name: "query",
                    value: [
                        "SYNO.Core.System",
                        "SYNO.Core.System.Utilization",
                        "SYNO.FileStation.List",
                        "SYNO.Core.Package",
                        "SYNO.ContainerManager.Container",
                        "SYNO.Docker.Container"
                    ].joined(separator: ",")
                )
            ]
        )
        recordAPIInfoCoverage(apiInfo)

        async let systemData = firstSuccessfulCall(apiRequests(
            session,
            apiInfo: apiInfo,
            apiName: "SYNO.Core.System",
            fallbackPath: "/webapi/entry.cgi",
            fallbackMaxVersion: 1,
            method: "info"
        ))
        async let utilizationData = firstSuccessfulCall(apiRequests(
            session,
            apiInfo: apiInfo,
            apiName: "SYNO.Core.System.Utilization",
            fallbackPath: "/webapi/entry.cgi",
            fallbackMaxVersion: 1,
            method: "get"
        ))
        async let sharedFolderData = firstSuccessfulCall(apiRequests(
            session,
            apiInfo: apiInfo,
            apiName: "SYNO.FileStation.List",
            fallbackPath: "/webapi/entry.cgi",
            fallbackMaxVersion: 2,
            method: "list_share"
        ))
        async let packageData = firstSuccessfulCall(apiRequests(
            session,
            apiInfo: apiInfo,
            apiName: "SYNO.Core.Package",
            fallbackPath: "/webapi/entry.cgi",
            fallbackMaxVersion: 2,
            method: "list"
        ))
        async let dockerData = firstSuccessfulContainerCall(containerRequests(session, apiInfo: apiInfo))

        let system = await systemData
        let utilization = await utilizationData
        let files = DSMClient.mapSharedFolders(await sharedFolderData)
        let containers = DSMClient.mapContainers(await dockerData)
        let services = DSMClient.mapServices(containers: containers, packageData: await packageData, session: session)

        record(
            .info,
            categoryKey: "diagnostics.category.dsm_api",
            messageKey: "diagnostics.snapshot.completed",
            details: [
                "services": "\(services.count)",
                "containers": "\(containers.count)",
                "folders": "\(files.count)"
            ]
        )

        return DSMDataSnapshot(
            device: DSMClient.mapDevice(system: system, utilization: utilization, session: session, useAgent: useAgent),
            services: services,
            containers: containers,
            files: files,
            tasks: [],
            videoLibraryItems: [],
            audioLibraryItems: [],
            discoveredDevices: []
        )
    }

    private func call(path: String, queryItems: [URLQueryItem]) async throws -> DSMJSONValue {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw DSMClientError.invalidAddress
        }
        components.path = path
        components.queryItems = queryItems
        guard let url = components.url else { throw DSMClientError.invalidAddress }

        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw DSMClientError.invalidResponse
        }

        let envelope = try JSONDecoder().decode(DSMAPIEnvelope.self, from: data)
        guard envelope.success else {
            throw DSMClientError.apiFailed(code: envelope.error?.code)
        }
        return envelope.data ?? .object([:])
    }

    private func optionalCall(path: String, queryItems: [URLQueryItem]) async -> DSMJSONValue? {
        try? await call(path: path, queryItems: queryItems)
    }

    private func firstSuccessfulCall(_ requests: [(String, [URLQueryItem])]) async -> DSMJSONValue? {
        for request in requests {
            do {
                let value = try await call(path: request.0, queryItems: request.1)
                return value
            } catch {
                record(
                    .warning,
                    categoryKey: "diagnostics.category.dsm_api",
                    messageKey: "diagnostics.api_request.failed",
                    details: requestSummary(path: request.0, queryItems: request.1).merging(["error": diagnosticMessage(for: error)]) { current, _ in current }
                )
            }
        }
        return nil
    }

    private func sessionItems(_ session: DSMSession, api: String, version: String, method: String, extra: [URLQueryItem] = []) -> [URLQueryItem] {
        [
            URLQueryItem(name: "api", value: api),
            URLQueryItem(name: "version", value: version),
            URLQueryItem(name: "method", value: method),
            URLQueryItem(name: "_sid", value: session.sid)
        ] + extra
    }

    private func authLoginRequests(
        account: String,
        password: String,
        oneTimeCode: String,
        apiInfo: DSMJSONValue?
    ) -> [(String, [URLQueryItem])] {
        let entry = apiInfoEntry(apiInfo, apiName: "SYNO.API.Auth")
        let path = normalizedAPIPath(entry?.path ?? "/webapi/auth.cgi")
        let maxVersion = max(entry?.maxVersion ?? 7, 1)
        return (1...maxVersion).reversed().map { version in
            var items = [
                URLQueryItem(name: "api", value: "SYNO.API.Auth"),
                URLQueryItem(name: "version", value: "\(version)"),
                URLQueryItem(name: "method", value: "login"),
                URLQueryItem(name: "account", value: account),
                URLQueryItem(name: "passwd", value: password),
                URLQueryItem(name: "session", value: "Nastart"),
                URLQueryItem(name: "format", value: "sid")
            ]
            if !oneTimeCode.isEmpty {
                items.append(URLQueryItem(name: "otp_code", value: oneTimeCode))
            }
            return (path, items)
        }
    }

    private func containerRequests(_ session: DSMSession, apiInfo: DSMJSONValue?) -> [(String, [URLQueryItem])] {
        let commonExtras = [
            URLQueryItem(name: "limit", value: "1000"),
            URLQueryItem(name: "offset", value: "0")
        ]
        let allExtras = commonExtras + [URLQueryItem(name: "type", value: "all")]

        var requests: [(String, [URLQueryItem])] = []
        requests += apiInfoRequests(
            session,
            apiInfo: apiInfo,
            apiName: "SYNO.ContainerManager.Container",
            fallbackPath: "/webapi/entry.cgi",
            fallbackMaxVersion: 3,
            extras: [allExtras, commonExtras]
        )
        requests += apiInfoRequests(
            session,
            apiInfo: apiInfo,
            apiName: "SYNO.Docker.Container",
            fallbackPath: "/webapi/entry.cgi",
            fallbackMaxVersion: 2,
            extras: [allExtras, commonExtras]
        )
        requests += [
            ("/webapi/entry.cgi", sessionItems(session, api: "SYNO.ContainerManager.Container", version: "1", method: "list", extra: allExtras)),
            ("/webapi/entry.cgi", sessionItems(session, api: "SYNO.ContainerManager.Container", version: "2", method: "list", extra: allExtras)),
            ("/webapi/entry.cgi", sessionItems(session, api: "SYNO.ContainerManager.Container", version: "3", method: "list", extra: allExtras)),
            ("/webapi/entry.cgi", sessionItems(session, api: "SYNO.ContainerManager.Container", version: "1", method: "list", extra: commonExtras)),
            ("/webapi/entry.cgi", sessionItems(session, api: "SYNO.ContainerManager.Container", version: "2", method: "list", extra: commonExtras)),
            ("/webapi/entry.cgi", sessionItems(session, api: "SYNO.Docker.Container", version: "1", method: "list", extra: allExtras)),
            ("/webapi/entry.cgi", sessionItems(session, api: "SYNO.Docker.Container", version: "2", method: "list", extra: allExtras)),
            ("/webapi/entry.cgi", sessionItems(session, api: "SYNO.Docker.Container", version: "1", method: "list", extra: commonExtras)),
            ("/webapi/entry.cgi", sessionItems(session, api: "SYNO.Docker.Container", version: "2", method: "list", extra: commonExtras)),
            ("/webapi/Docker/Container.cgi", sessionItems(session, api: "SYNO.Docker.Container", version: "1", method: "list", extra: commonExtras)),
            ("/webapi/Docker/Container.cgi", sessionItems(session, api: "SYNO.Docker.Container", version: "2", method: "list", extra: commonExtras))
        ]
        var seen = Set<String>()
        return requests.filter { path, items in
            let signature = path + "?" + items.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            if seen.contains(signature) { return false }
            seen.insert(signature)
            return true
        }
    }

    private func apiInfoRequests(
        _ session: DSMSession,
        apiInfo: DSMJSONValue?,
        apiName: String,
        fallbackPath: String,
        fallbackMaxVersion: Int,
        extras: [[URLQueryItem]]
    ) -> [(String, [URLQueryItem])] {
        apiRequests(
            session,
            apiInfo: apiInfo,
            apiName: apiName,
            fallbackPath: fallbackPath,
            fallbackMaxVersion: fallbackMaxVersion,
            method: "list",
            extras: extras
        )
    }

    private func apiRequests(
        _ session: DSMSession,
        apiInfo: DSMJSONValue?,
        apiName: String,
        fallbackPath: String,
        fallbackMaxVersion: Int,
        method: String,
        extras: [[URLQueryItem]] = [[]]
    ) -> [(String, [URLQueryItem])] {
        let entry = apiInfoEntry(apiInfo, apiName: apiName)
        let path = normalizedAPIPath(entry?.path ?? fallbackPath)
        let maxVersion = max(entry?.maxVersion ?? fallbackMaxVersion, 1)
        return (1...maxVersion).reversed().flatMap { version in
            extras.map { extra in
                (path, sessionItems(session, api: apiName, version: "\(version)", method: method, extra: extra))
            }
        }
    }

    private func apiInfoEntry(_ apiInfo: DSMJSONValue?, apiName: String) -> (path: String, maxVersion: Int)? {
        guard let item = apiInfo?.objectValue?[apiName] else { return nil }
        guard let path = item.firstString(for: ["path"]) else { return nil }
        let maxVersion = Int(item.firstDouble(for: ["maxVersion", "max_version"]) ?? 1)
        return (path, maxVersion)
    }

    private func normalizedAPIPath(_ path: String) -> String {
        if path.hasPrefix("/") { return path }
        if path.hasPrefix("webapi/") { return "/\(path)" }
        return "/webapi/\(path)"
    }

    private func firstSuccessfulContainerCall(_ requests: [(String, [URLQueryItem])]) async -> DSMJSONValue? {
        var fallback: DSMJSONValue?
        for request in requests {
            let value: DSMJSONValue
            do {
                value = try await call(path: request.0, queryItems: request.1)
            } catch {
                record(
                    .warning,
                    categoryKey: "diagnostics.category.container",
                    messageKey: "diagnostics.container.request_failed",
                    details: requestSummary(path: request.0, queryItems: request.1).merging(["error": diagnosticMessage(for: error)]) { current, _ in current }
                )
                continue
            }
            if fallback == nil {
                fallback = value
            }
            let containers = DSMClient.mapContainers(value)
            record(
                containers.isEmpty ? .warning : .info,
                categoryKey: "diagnostics.category.container",
                messageKey: containers.isEmpty ? "diagnostics.container.empty_response" : "diagnostics.container.loaded",
                details: requestSummary(path: request.0, queryItems: request.1).merging(["count": "\(containers.count)"]) { current, _ in current }
            )
            if !containers.isEmpty {
                return value
            }
        }
        return fallback
    }

    private func requestSummary(path: String, queryItems: [URLQueryItem]) -> [String: String] {
        var summary = ["path": path]
        for key in ["api", "version", "method", "type"] {
            if let value = queryItems.first(where: { $0.name == key })?.value {
                summary[key] = value
            }
        }
        return summary
    }

    private func diagnosticMessage(for error: Error) -> String {
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

    private func recordAPIInfoCoverage(_ apiInfo: DSMJSONValue?) {
        let apiNames = [
            "SYNO.Core.System",
            "SYNO.Core.System.Utilization",
            "SYNO.FileStation.List",
            "SYNO.Core.Package",
            "SYNO.ContainerManager.Container",
            "SYNO.Docker.Container"
        ]
        guard let apiInfo else {
            record(
                .warning,
                categoryKey: "diagnostics.category.dsm_api",
                messageKey: "diagnostics.api_info.missing",
                details: ["api": "snapshot"]
            )
            return
        }
        let found = apiNames.filter { apiInfoEntry(apiInfo, apiName: $0) != nil }
        let missing = apiNames.filter { !found.contains($0) }
        record(
            missing.isEmpty ? .info : .warning,
            categoryKey: "diagnostics.category.dsm_api",
            messageKey: "diagnostics.api_info.coverage",
            details: [
                "found": found.joined(separator: "|"),
                "missing": missing.joined(separator: "|")
            ]
        )
    }

    private static func mapDevice(system: DSMJSONValue?, utilization: DSMJSONValue?, session: DSMSession, useAgent: Bool) -> NASDevice {
        let hostName = session.baseURL.host ?? "DSM"
        let name = system?.firstString(for: ["server_name", "hostname", "model", "model_name"]) ?? hostName
        let version = system?.firstString(for: ["firmware_ver", "version", "firmware"]) ?? "DSM"
        let mode: ConnectionMode = useAgent ? .dsmWithAgent : .dsmOnly
        let cpu = mapCPU(utilization)
        let memory = DSMFormatters.percentage(utilization?.firstValue(for: ["memory"])?.firstDouble(for: ["real_usage", "usage", "memory_usage"]))
        let storage = mapStorage(utilization)

        return NASDevice(
            id: UUID(),
            name: name,
            subtitle: "\(version) · \(mode == .dsmWithAgent ? "Agent" : "DSM")",
            mode: mode,
            cpu: cpu,
            memory: memory,
            storageUsed: storage.usedProgress,
            storageFreeText: storage.freeText,
            uptimeText: system?.firstString(for: ["uptime", "up_time"]) ?? "-",
            certificateDaysRemaining: 999
        )
    }

    private static func mapCPU(_ utilization: DSMJSONValue?) -> Double {
        guard let cpu = utilization?.firstValue(for: ["cpu"]) else { return 0 }
        if let load = cpu.firstDouble(for: ["total_load", "load", "usage"]) {
            return DSMFormatters.percentage(load)
        }
        let user = cpu.firstDouble(for: ["user_load"]) ?? 0
        let system = cpu.firstDouble(for: ["system_load"]) ?? 0
        let other = cpu.firstDouble(for: ["other_load"]) ?? 0
        return DSMFormatters.percentage(user + system + other)
    }

    private static func mapStorage(_ utilization: DSMJSONValue?) -> (usedProgress: Double, freeText: String) {
        guard let disk = utilization?.firstValue(for: ["disk", "volume", "storage"]) else {
            return (0, "-")
        }
        let total = disk.firstDouble(for: ["total", "total_size", "size_total"])
        let used = disk.firstDouble(for: ["used", "used_size", "size_used"])
        if let total, let used, total > 0 {
            let free = max(total - used, 0)
            return (min(max(used / total, 0), 1), DSMFormatters.bytes(free) ?? "-")
        }
        return (0, "-")
    }

    private static func mapSharedFolders(_ data: DSMJSONValue?) -> [FileItem] {
        guard let shares = data?.firstArray(for: ["shares", "items"]) else { return [] }
        return shares.compactMap { share in
            guard let name = share.firstString(for: ["name", "path"]) else { return nil }
            let path = share.firstString(for: ["path"]) ?? "/\(name)"
            return FileItem(id: UUID(), name: name, subtitle: path, kind: .folder, sizeText: nil, children: [])
        }
    }

    private static func mapContainers(_ data: DSMJSONValue?) -> [DockerContainer] {
        let items = containerItems(from: data)
        return items.compactMap { item in
            guard let name = textValue(
                in: item,
                keys: ["name", "Name", "container_name", "containerName", "container", "service", "title", "id", "Id", "Names"]
            ) else { return nil }
            let image = textValue(
                in: item,
                keys: ["image", "Image", "image_name", "imageName", "repository", "repo", "tag", "imageTag", "image_tag"]
            ) ?? "-"
            let stateText = textValue(
                in: item,
                keys: ["status", "Status", "state", "State", "status_text", "display_status", "up_time", "health"]
            ) ?? ""
            let explicitRunning = item.firstBool(for: ["running", "Running", "is_running", "started", "start"])
            let cpu = DSMFormatters.percentage(item.firstDouble(for: ["cpu", "CPU", "cpu_usage", "cpu_percent"]))
            let memoryText = textValue(in: item, keys: ["memory", "Memory", "memory_usage", "memory_text", "mem_usage"])
                ?? DSMFormatters.bytes(item.firstDouble(for: ["memory_bytes", "mem_usage", "memoryUsage"]))
                ?? "-"
            return DockerContainer(
                id: UUID(),
                name: name,
                image: image,
                status: explicitRunning.map { $0 ? .online : .offline } ?? serviceStatus(from: stateText),
                cpu: cpu,
                memoryText: memoryText,
                ports: mapPorts(item)
            )
        }
    }

    private static func containerItems(from data: DSMJSONValue?) -> [DSMJSONValue] {
        guard let data else { return [] }
        let preferredKeys = Set(["containers", "container", "items", "list", "result"])
        let candidates = arrays(in: data, matching: preferredKeys).flatMap { $0 }
        let scored = candidates.filter(looksLikeContainer)
        if !scored.isEmpty { return scored }
        if let rootArray = data.arrayValue {
            return rootArray.filter(looksLikeContainer)
        }
        return allObjects(in: data).filter(looksLikeContainer)
    }

    private static func arrays(in value: DSMJSONValue, matching keys: Set<String>) -> [[DSMJSONValue]] {
        switch value {
        case .object(let object):
            return object.flatMap { key, child -> [[DSMJSONValue]] in
                let own = keys.contains(key.lowercased()) ? (child.arrayValue.map { [$0] } ?? []) : []
                return own + arrays(in: child, matching: keys)
            }
        case .array(let array):
            return array.flatMap { arrays(in: $0, matching: keys) }
        case .string, .number, .bool, .null:
            return []
        }
    }

    private static func looksLikeContainer(_ item: DSMJSONValue) -> Bool {
        guard item.objectValue != nil else { return false }
        return textValue(in: item, keys: ["name", "Name", "container_name", "containerName", "id", "Id", "Names"]) != nil
            && (
                textValue(in: item, keys: ["image", "Image", "image_name", "imageName", "repository", "repo"]) != nil
                || textValue(in: item, keys: ["status", "Status", "state", "State", "status_text", "display_status"]) != nil
                || item.firstArray(for: ["ports", "Ports", "port_bindings", "port_mappings", "portMappings"]) != nil
                || item.firstValue(for: ["PortBindings", "portBindings", "ports"]) != nil
            )
    }

    private static func allObjects(in value: DSMJSONValue) -> [DSMJSONValue] {
        switch value {
        case .object(let object):
            return [value] + object.values.flatMap { allObjects(in: $0) }
        case .array(let array):
            return array.flatMap { allObjects(in: $0) }
        case .string, .number, .bool, .null:
            return []
        }
    }

    private static func mapServices(containers: [DockerContainer], packageData: DSMJSONValue?, session: DSMSession) -> [LaunchpadService] {
        var services: [LaunchpadService] = [
            LaunchpadService(
                id: UUID(),
                name: "DSM",
                iconText: "DSM",
                category: .favorites,
                status: .online,
                subtitle: session.baseURL.host ?? "DSM",
                detail: "service.dsm.detail",
                isMedia: false,
                cpu: nil,
                memoryText: nil,
                endpoint: session.baseURL
            )
        ]

        services += containers.map { container in
            LaunchpadService(
                id: UUID(),
                name: displayName(for: container.name),
                iconText: iconText(for: container.name),
                category: category(for: container.name),
                status: container.status,
                subtitle: subtitle(for: container),
                detail: container.image,
                isMedia: isMedia(container.name),
                cpu: container.cpu,
                memoryText: container.memoryText,
                ports: container.ports,
                endpoint: endpoint(for: container, baseURL: session.baseURL)
            )
        }

        services += mapPackageServices(packageData, session: session)

        var seen = Set<String>()
        return services.filter { service in
            let key = service.name.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        .sorted { lhs, rhs in
            let lhsRank = serviceSortRank(lhs)
            let rhsRank = serviceSortRank(rhs)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.category.rawValue != rhs.category.rawValue {
                return categorySortRank(lhs.category) < categorySortRank(rhs.category)
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func mapPackageServices(_ data: DSMJSONValue?, session: DSMSession) -> [LaunchpadService] {
        guard let packages = data?.firstArray(for: ["packages", "items"]) else { return [] }
        return packages.compactMap { item in
            guard let name = item.firstString(for: ["name", "id", "package"]) else { return nil }
            guard shouldShowPackageService(name) else { return nil }
            let status = packageStatus(item)
            return LaunchpadService(
                id: UUID(),
                name: displayName(for: name),
                iconText: iconText(for: name),
                category: category(for: name),
                status: status,
                subtitle: item.firstString(for: ["version"]) ?? "DSM package",
                detail: name,
                isMedia: isMedia(name),
                cpu: nil,
                memoryText: nil,
                endpoint: packageEndpoint(for: item, baseURL: session.baseURL)
            )
        }
    }

    private static func packageEndpoint(for item: DSMJSONValue, baseURL: URL) -> URL? {
        guard let text = textValue(
            in: item,
            keys: ["url", "URL", "uri", "launch_url", "launchUrl", "web_url", "webUrl", "webui", "homepage", "dsm_url"]
        ) else {
            return nil
        }
        if let absolute = URL(string: text), absolute.scheme != nil {
            return absolute
        }
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = text.hasPrefix("/") ? text : "/\(text)"
        return components.url
    }

    private static func packageStatus(_ item: DSMJSONValue) -> ServiceStatus {
        if let isRunning = item.firstBool(for: ["start", "running", "is_running", "started", "enabled", "run", "is_enable"]) {
            return isRunning ? .online : .offline
        }
        return serviceStatus(from: textValue(in: item, keys: ["status", "state", "status_text", "display_status", "pkgStatus"]) ?? "")
    }

    private static func shouldShowPackageService(_ name: String) -> Bool {
        let lower = name.lowercased()
        let importantTokens = [
            "container",
            "docker",
            "file station",
            "download station",
            "synology photos",
            "photo station",
            "video station",
            "audio station",
            "synology drive",
            "webdav",
            "vpn server",
            "active backup",
            "virtual machine"
        ]
        return importantTokens.contains { lower.contains($0) }
    }

    private static func serviceSortRank(_ service: LaunchpadService) -> Int {
        let lower = service.name.lowercased()
        if lower == "dsm" { return 0 }
        if lower.contains("container") || lower.contains("docker") { return 1 }
        if service.isMedia { return 2 }
        if service.category == .downloads { return 3 }
        if lower.contains("file station") || lower.contains("drive") || lower.contains("photos") { return 4 }
        return 9
    }

    private static func categorySortRank(_ category: ServiceCategory) -> Int {
        switch category {
        case .favorites: return 0
        case .media: return 1
        case .downloads: return 2
        case .network: return 3
        case .tools: return 4
        }
    }

    private static func mapPorts(_ item: DSMJSONValue) -> [String] {
        var ports: [String] = []

        if let array = item.firstArray(for: ["ports", "Ports", "port_bindings", "PortBindings", "port_mappings", "portMappings"]) {
            ports += array.compactMap(portText)
        }

        if let bindings = item.firstValue(for: ["port_bindings", "PortBindings", "portBindings", "port_mappings", "portMappings"]) {
            ports += portBindingTexts(bindings)
        }

        return uniqueStrings(ports)
    }

    private static func portText(_ port: DSMJSONValue) -> String? {
        if let text = port.stringValue, !text.isEmpty {
            return text
        }

        let local = textValue(
            in: port,
            keys: [
                "local_port", "localPort", "host_port", "hostPort",
                "public_port", "publicPort", "PublicPort", "HostPort",
                "external", "external_port", "externalPort", "host"
            ]
        )
        let container = textValue(
            in: port,
            keys: [
                "container_port", "containerPort", "private_port", "privatePort",
                "PrivatePort", "ContainerPort", "target", "target_port", "targetPort", "port"
            ]
        )
        if let local, let container {
            return "\(local):\(container)"
        }
        return local ?? container
    }

    private static func portBindingTexts(_ value: DSMJSONValue) -> [String] {
        if let text = portText(value) {
            return [text]
        }

        if let array = value.arrayValue {
            return array.flatMap(portBindingTexts)
        }

        guard let object = value.objectValue else { return [] }

        return object.flatMap { key, child -> [String] in
            let nested = portBindingTexts(child)
            guard !nested.isEmpty else { return [] }

            return nested.map { text in
                guard let containerPort = key.split(separator: "/").first.map(String.init), !text.contains(":") else {
                    return text
                }
                return "\(text):\(containerPort)"
            }
        }
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seen.contains(normalized) else { return false }
            seen.insert(normalized)
            return true
        }
    }

    private static func serviceStatus(from text: String) -> ServiceStatus {
        let normalized = text.lowercased()
        if normalized.contains("running") || normalized.contains("healthy") || normalized == "up" || normalized == "online" || normalized == "started" {
            return .online
        }
        if normalized.contains("stop") || normalized.contains("exit") || normalized == "down" || normalized == "offline" {
            return .offline
        }
        if normalized.isEmpty || normalized == "installed" {
            return .unknown
        }
        return .warning
    }

    private static func textValue(in item: DSMJSONValue, keys: [String]) -> String? {
        guard let value = item.firstValue(for: keys) else { return nil }
        let text = value.stringValue ?? value.arrayValue?.compactMap(\.stringValue).first
        let normalized = text?
            .trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        return normalized?.isEmpty == false ? normalized : nil
    }

    private static func displayName(for rawName: String) -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = name.lowercased()
        if lower.contains("container") { return "Container" }
        if lower.contains("file station") { return "File Station" }
        if lower.contains("synology photos") { return "Synology Photos" }
        if lower.contains("download station") { return "Download Station" }
        if lower.contains("synology drive") { return "Synology Drive" }
        if lower.contains("video station") { return "Video Station" }
        if lower.contains("audio station") { return "Audio Station" }
        if lower.contains("jellyfin") { return "Jellyfin" }
        if lower.contains("emby") { return "Emby" }
        if lower.contains("plex") { return "Plex" }
        if lower.contains("navidrome") { return "Navidrome" }
        if lower.contains("qbittorrent") { return "qBittorrent" }
        if lower.contains("code-server") { return "code-server" }
        if lower.contains("codex-server") { return "codex-server" }
        return name.isEmpty ? "Service" : name
    }

    private static func iconText(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("jellyfin") { return "JF" }
        if lower.contains("navidrome") { return "NV" }
        if lower.contains("qbittorrent") { return "QB" }
        if lower.contains("container") { return "CT" }
        if lower.contains("file station") { return "FS" }
        if lower.contains("download station") { return "DL" }
        if lower.contains("synology photos") { return "PH" }
        if lower.contains("synology drive") { return "DR" }
        if lower.contains("video station") { return "VD" }
        if lower.contains("audio station") { return "AU" }
        if lower.contains("code") { return "</>" }
        let letters = name.split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
        let fallback = letters.isEmpty ? String(name.prefix(2)) : String(letters)
        return fallback.uppercased()
    }

    private static func category(for name: String) -> ServiceCategory {
        let lower = name.lowercased()
        if lower.contains("dsm") || lower.contains("homepage") { return .favorites }
        if lower.contains("jellyfin") || lower.contains("emby") || lower.contains("plex") || lower.contains("navidrome") { return .media }
        if lower.contains("photos") || lower.contains("video station") || lower.contains("audio station") { return .media }
        if lower.contains("torrent") || lower.contains("transmission") || lower.contains("aria") { return .downloads }
        if lower.contains("download station") { return .downloads }
        if lower.contains("nginx") || lower.contains("adguard") || lower.contains("tailscale") { return .network }
        if lower.contains("webdav") || lower.contains("vpn") { return .network }
        if lower.contains("container") || lower.contains("docker") || lower.contains("file station") || lower.contains("drive") { return .favorites }
        return .tools
    }

    private static func isMedia(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("jellyfin") || lower.contains("emby") || lower.contains("plex") || lower.contains("navidrome")
    }

    private static func subtitle(for container: DockerContainer) -> String {
        if isMedia(container.name) {
            return container.name.lowercased().contains("navidrome") ? "media.audio.title" : "media.video.title"
        }
        if container.ports.isEmpty {
            return container.image
        }
        return container.ports.joined(separator: " · ")
    }

    private static func endpoint(for container: DockerContainer, baseURL: URL) -> URL? {
        guard let host = baseURL.host else { return nil }
        let preferredPort = preferredWebPort(for: container)
        guard let port = preferredPort else { return nil }
        var components = URLComponents()
        components.scheme = webScheme(for: port, fallback: baseURL.scheme)
        components.host = host
        components.port = port
        return components.url
    }

    private static func preferredWebPort(for container: DockerContainer) -> Int? {
        let normalizedName = container.name.lowercased()
        let preferredPorts: [Int]
        if normalizedName.contains("jellyfin") {
            preferredPorts = [8096, 8920]
        } else if normalizedName.contains("emby") {
            preferredPorts = [8096, 8920]
        } else if normalizedName.contains("plex") {
            preferredPorts = [32400]
        } else if normalizedName.contains("navidrome") {
            preferredPorts = [4533]
        } else if normalizedName.contains("qbittorrent") {
            preferredPorts = [8080]
        } else if normalizedName.contains("code-server") || normalizedName.contains("codex-server") {
            preferredPorts = [8443, 8080, 8000]
        } else if normalizedName.contains("portainer") {
            preferredPorts = [9443, 9000]
        } else if normalizedName.contains("home") {
            preferredPorts = [8123]
        } else {
            preferredPorts = [443, 8443, 9443, 80, 8080, 8000, 5000, 3000]
        }

        let ports = container.ports.compactMap(hostPort(from:))
        for port in preferredPorts where ports.contains(port) {
            return port
        }
        return ports.first
    }

    private static func hostPort(from text: String) -> Int? {
        let compact = text.replacingOccurrences(of: " ", with: "")
        let leftSide = compact.components(separatedBy: "->").first ?? compact
        let numbers = leftSide
            .split { !$0.isNumber }
            .compactMap { Int($0) }
            .filter { $0 > 0 && $0 <= 65_535 }

        if leftSide.contains(":") {
            if numbers.count >= 2 {
                return numbers[numbers.count - 2]
            }
            if let port = numbers.last {
                return port
            }
        }
        return compact
            .split { !$0.isNumber }
            .compactMap { Int($0) }
            .first { $0 > 0 && $0 <= 65_535 }
    }

    private static func webScheme(for port: Int, fallback: String?) -> String {
        if [443, 5001, 8443, 8920, 9443].contains(port) {
            return "https"
        }
        if [80, 5000, 8000, 8080, 8096, 8123, 9000].contains(port) {
            return "http"
        }
        return fallback == "http" ? "http" : "https"
    }
}

final class AppDataStore: ObservableObject {
    @Published private(set) var device: NASDevice
    @Published private(set) var services: [LaunchpadService]
    @Published private(set) var containers: [DockerContainer]
    @Published private(set) var files: [FileItem]
    @Published private(set) var tasks: [TaskItem]
    @Published private(set) var videoLibraryItems: [MediaItem]
    @Published private(set) var audioLibraryItems: [MediaItem]
    @Published private(set) var discoveredDevices: [DiscoveredNASDevice]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshSummaryKey = "data.refresh.ready"
    @Published private(set) var sourceKind: NASDataSourceKind

    private var provider: AppDataProviding
    private var activeDataSource: NASDataSource

    init(provider: AppDataProviding = DisconnectedAppDataProvider()) {
        self.provider = provider
        sourceKind = provider is DSMDataSnapshot ? .dsm : .mock
        activeDataSource = DisconnectedNASDataSource()
        device = provider.device
        services = provider.services
        containers = provider.containers
        files = provider.files
        tasks = provider.tasks
        videoLibraryItems = provider.videoLibraryItems
        audioLibraryItems = provider.audioLibraryItems
        discoveredDevices = provider.discoveredDevices
    }

    func reload(from provider: AppDataProviding) {
        self.provider = provider
        sourceKind = provider is DSMDataSnapshot ? .dsm : .mock
        device = provider.device
        services = provider.services
        containers = provider.containers
        files = provider.files
        tasks = provider.tasks
        videoLibraryItems = provider.videoLibraryItems
        audioLibraryItems = provider.audioLibraryItems
        discoveredDevices = provider.discoveredDevices
        lastRefreshSummaryKey = provider is DSMDataSnapshot ? "data.refresh.dsm_done" : "data.refresh.mock_done"
    }

    func refreshAll() {
        isRefreshing = true
        reload(from: provider)
        isRefreshing = false
    }

    @MainActor
    func refreshActiveDataSource() async {
        await load(from: activeDataSource)
    }

    @MainActor
    func load(from dataSource: NASDataSource) async {
        isRefreshing = true
        defer { isRefreshing = false }

        activeDataSource = dataSource
        let snapshot = await dataSource.loadSnapshot()
        reload(from: snapshot)
        sourceKind = dataSource.kind
    }

    @MainActor
    func resetToMockData() {
        activeDataSource = MockNASDataSource()
        reload(from: MockAppDataProvider())
        sourceKind = .mock
    }

    @MainActor
    func clearConnectionData() {
        activeDataSource = DisconnectedNASDataSource()
        reload(from: DisconnectedAppDataProvider())
        sourceKind = .mock
        lastRefreshSummaryKey = "data.refresh.disconnected"
    }

    @MainActor
    func refreshDSM(session: DSMSession, useAgent: Bool) async {
        await load(from: DSMNASDataSource(session: session, useAgent: useAgent))
    }

    @MainActor
    func restoreDSMConnection(using connectionStore: NASConnectionStore) async {
        guard let credential = KeychainStore.shared.loadNASCredential() else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let baseURL = try DSMClient.normalizedBaseURL(from: credential.baseURLString)
            let client = DSMClient(
                baseURL: baseURL,
                allowsSelfSignedCertificates: credential.allowsSelfSignedCertificates
            )
            let session = try await client.login(account: credential.account, password: credential.password)
            let dataSource = DSMNASDataSource(session: session, useAgent: credential.useAgent)
            let snapshot = await dataSource.loadSnapshot()
            activeDataSource = dataSource
            reload(from: snapshot)
            sourceKind = dataSource.kind
            connectionStore.connect(device: snapshot.device, session: session)
        } catch {
            lastRefreshSummaryKey = "data.refresh.restore_failed"
        }
    }

    func services(in category: ServiceCategory) -> [LaunchpadService] {
        services.filter { $0.category == category }
    }

    func mediaItems(for service: LaunchpadService) -> [MediaItem] {
        service.name == "Navidrome" ? audioLibraryItems : videoLibraryItems
    }

    func selectDiscoveredDevice(_ discoveredDevice: DiscoveredNASDevice) -> NASDevice {
        NASDevice(
            id: device.id,
            name: discoveredDevice.name,
            subtitle: device.subtitle,
            mode: device.mode,
            cpu: device.cpu,
            memory: device.memory,
            storageUsed: device.storageUsed,
            storageFreeText: device.storageFreeText,
            uptimeText: device.uptimeText,
            certificateDaysRemaining: device.certificateDaysRemaining
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
    static let showCardCPU = "appearance.card.showCPU"
    static let showCardMemory = "appearance.card.showMemory"
    static let showCardPorts = "appearance.card.showPorts"
    static let showCardLibraryCounts = "appearance.card.showLibraryCounts"
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
        }
    }

    @Published var compactMetrics: Bool {
        didSet {
            UserDefaults.standard.set(compactMetrics, forKey: AppearancePreferenceKeys.compactMetrics)
        }
    }

    @Published var showServiceStatus: Bool {
        didSet {
            UserDefaults.standard.set(showServiceStatus, forKey: AppearancePreferenceKeys.showServiceStatus)
        }
    }

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: LaunchpadTheme.storageKey)
        launchpadTheme = savedTheme.flatMap(LaunchpadTheme.init(rawValue:)) ?? .cleanGrid
        compactMetrics = UserDefaults.standard.object(forKey: AppearancePreferenceKeys.compactMetrics) as? Bool ?? true
        showServiceStatus = UserDefaults.standard.object(forKey: AppearancePreferenceKeys.showServiceStatus) as? Bool ?? true
    }
}

final class ProfileStore: ObservableObject {
    @Published var nickname: String {
        didSet {
            UserDefaults.standard.set(nickname, forKey: Self.nicknameKey)
        }
    }

    @Published var avatarInitial: String {
        didSet {
            UserDefaults.standard.set(avatarInitial, forKey: Self.avatarInitialKey)
        }
    }

    init() {
        nickname = UserDefaults.standard.string(forKey: Self.nicknameKey) ?? NSLocalizedString("mine.profile.name", comment: "")
        avatarInitial = UserDefaults.standard.string(forKey: Self.avatarInitialKey) ?? "N"
    }

    private static let nicknameKey = "profile.nickname"
    private static let avatarInitialKey = "profile.avatarInitial"
}

final class NASConnectionStore: ObservableObject {
    @Published private(set) var connectedDevice: NASDevice?
    @Published private(set) var isConnected: Bool
    @Published private(set) var dsmSession: DSMSession?

    init(device: NASDevice? = nil) {
        connectedDevice = device
        isConnected = device != nil
    }

    var profileSubtitleKey: String {
        isConnected ? "mine.profile.connected" : "mine.profile.not_connected"
    }

    var usesAgent: Bool {
        connectedDevice?.mode == .dsmWithAgent || connectedDevice?.mode == .agentOnly
    }

    func connect(device: NASDevice, session: DSMSession? = nil) {
        connectedDevice = device
        dsmSession = session
        isConnected = true
    }

    func signOut() {
        connectedDevice = nil
        dsmSession = nil
        isConnected = false
        KeychainStore.shared.clearNASCredentials()
    }
}

final class EntitlementStore: ObservableObject {
    @Published private(set) var plusStatus: PlusStatus
    @Published private(set) var isRestoring = false

    init(plusStatus: PlusStatus = .active) {
        self.plusStatus = plusStatus
    }

    var hasPlus: Bool {
        plusStatus == .active
    }

    func canUse(_ feature: PlusFeature) -> Bool {
        switch feature {
        case .unlimitedCards, .multipleDevices, .iCloudSync, .advancedThemes, .moreReminders:
            return hasPlus
        }
    }

    func activatePreviewPlus() {
        plusStatus = .active
    }

    func restorePurchases() {
        isRestoring = true
        plusStatus = .active
        isRestoring = false
    }

    func refreshEntitlements() {
        // StoreKit 2 transaction refresh will update this state in the real purchase layer.
    }
}

final class KeychainStore {
    static let shared = KeychainStore()

    private let service = "com.nastart.app.nas"
    private let primaryNASAccount = "primary-nas"

    private init() {}

    func saveNASCredential(_ credential: StoredNASCredential) {
        guard let data = try? JSONEncoder().encode(credential) else { return }
        var item = baseQuery(account: primaryNASAccount)
        SecItemDelete(item as CFDictionary)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    func loadNASCredential() -> StoredNASCredential? {
        var query = baseQuery(account: primaryNASAccount)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredNASCredential.self, from: data)
    }

    func clearNASCredentials() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ] as CFDictionary)
        // Agent tokens and service API keys will be deleted here after those credential types land.
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
