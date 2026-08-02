import Foundation
import Combine
import CryptoKit
import Security
import UserNotifications
import Darwin

private enum DSMURLBuilder {
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

private enum StableIdentifier {
    static func uuid(_ value: String) -> UUID {
        let digest = SHA256.hash(data: Data(value.utf8))
        let hex = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
        let uuidString = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: uuidString) ?? UUID()
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
            guard storedFingerprint == fingerprint else { return nil }
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
    let client: DSMClient

    var kind: NASDataSourceKind {
        .dsm
    }

    init(session: DSMSession, useAgent _: Bool) {
        self.session = session
        self.client = DSMClient(
            baseURL: session.baseURL,
            allowsSelfSignedCertificates: session.allowsSelfSignedCertificates
        )
    }

    func loadSnapshot() async -> AppDataProviding {
        await client.loadSnapshot(session: session, useAgent: false)
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
}

struct DSMSession {
    let baseURL: URL
    let sid: String
    let account: String
    let allowsSelfSignedCertificates: Bool
    let deviceID: String?

    func fileStationOpenURL(path: String) -> URL? {
        fileStationOpenURLs(path: path).first
    }

    func fileStationOpenURLs(path: String) -> [URL] {
        var baseURLs = [baseURL]
        if NetworkHostClassifier.isPrivate(baseURL.host),
           baseURL.scheme?.lowercased() == "https",
           var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) {
            components.scheme = "http"
            if components.port == nil || components.port == 5001 {
                components.port = 5000
            }
            if let httpBaseURL = components.url {
                baseURLs.append(httpBaseURL)
            }
        }

        var seen = Set<String>()
        return baseURLs.compactMap { fileStationOpenURL(path: path, baseURL: $0) }
            .filter { seen.insert($0.absoluteString).inserted }
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
            URLQueryItem(name: "_sid", value: sid)
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

    init(
        baseURLString: String,
        account: String,
        password: String,
        useAgent: Bool,
        allowsSelfSignedCertificates: Bool = false,
        deviceID: String? = nil
    ) {
        self.baseURLString = baseURLString
        self.account = account
        self.password = password
        self.useAgent = useAgent
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.deviceID = deviceID
    }

    enum CodingKeys: String, CodingKey {
        case baseURLString
        case account
        case password
        case useAgent
        case allowsSelfSignedCertificates
        case deviceID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURLString = try container.decode(String.self, forKey: .baseURLString)
        account = try container.decode(String.self, forKey: .account)
        password = try container.decode(String.self, forKey: .password)
        useAgent = try container.decode(Bool.self, forKey: .useAgent)
        allowsSelfSignedCertificates = try container.decodeIfPresent(Bool.self, forKey: .allowsSelfSignedCertificates) ?? false
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID)
    }
}

struct StoredJellyfinSession: Codable {
    let endpointString: String
    let userID: String
    let username: String
    let accessToken: String
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
    let containerInventoryAvailable: Bool
    let packageInventoryAvailable: Bool
    let reverseProxyInventoryAvailable: Bool
}

enum DiagnosticLogLevel: String, Codable {
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

struct DiagnosticLogEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let level: DiagnosticLogLevel
    let categoryKey: String
    let messageKey: String
    let detail: String

    init(
        id: UUID = UUID(),
        date: Date,
        level: DiagnosticLogLevel,
        categoryKey: String,
        messageKey: String,
        detail: String
    ) {
        self.id = id
        self.date = date
        self.level = level
        self.categoryKey = categoryKey
        self.messageKey = messageKey
        self.detail = detail
    }

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

    private let maxEntries = 1000
    private let persistenceKey = "diagnostics.entries.v1"

    private init() {
        guard
            let data = UserDefaults.standard.data(forKey: persistenceKey),
            let savedEntries = try? JSONDecoder().decode([DiagnosticLogEntry].self, from: data)
        else {
            return
        }
        entries = Array(savedEntries.suffix(maxEntries))
    }

    func record(
        _ level: DiagnosticLogLevel,
        categoryKey: String,
        messageKey: String,
        details: [String: String] = [:]
    ) {
        let detail = details
            .filter { !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(Self.redactedDetail($0.value))" }
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
        UserDefaults.standard.removeObject(forKey: persistenceKey)
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

    static func redactedDetail(_ value: String) -> String {
        let patterns: [(String, String)] = [
            (
                #"(?i)((?:_sid|api[_-]?key|apikey|token|access_token|authorization|password|passwd|cookie)\s*[=:]\s*)[^&,;\s]+"#,
                "$1<redacted>"
            ),
            (#"(?i)(bearer\s+)[a-z0-9._~+/=-]+"#, "$1<redacted>")
        ]
        return patterns.reduce(value) { result, replacement in
            result.replacingOccurrences(
                of: replacement.0,
                with: replacement.1,
                options: .regularExpression
            )
        }
    }

    private func append(_ entry: DiagnosticLogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
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
            if code == 403 || code == 404 || code == 406 {
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

    func firstDirectValue(for keys: [String]) -> DSMJSONValue? {
        guard let object = objectValue else { return nil }
        for key in keys {
            if let value = object[key] {
                return value
            }
        }
        return nil
    }

    func firstDirectString(for keys: [String]) -> String? {
        firstDirectValue(for: keys)?.stringValue
    }

    func firstDirectDouble(for keys: [String]) -> Double? {
        firstDirectValue(for: keys)?.doubleValue
    }

    func firstDirectBool(for keys: [String]) -> Bool? {
        firstDirectValue(for: keys)?.boolValue
    }

    func firstDirectArray(for keys: [String]) -> [DSMJSONValue]? {
        firstDirectValue(for: keys)?.arrayValue
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

private final class DSMCertificateTrustDelegate: NSObject, URLSessionTaskDelegate {
    private let trustedHost: String?

    init(trustedHost: String? = nil) {
        self.trustedHost = trustedHost
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let expectedHost = trustedHost
            ?? task.currentRequest?.url?.host
            ?? task.originalRequest?.url?.host
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let expectedHost,
           challenge.protectionSpace.host.caseInsensitiveCompare(expectedHost) != .orderedSame {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let credential = CertificatePinStore.shared.credential(
            for: challenge,
            expectedHost: expectedHost
        ) else {
            let disposition: URLSession.AuthChallengeDisposition =
                challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
                ? .cancelAuthenticationChallenge
                : .performDefaultHandling
            completionHandler(disposition, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }
}

final class DSMClient {
    private static let requestTimeout: TimeInterval = 18
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
            let delegate = DSMCertificateTrustDelegate(trustedHost: baseURL.host)
            self.sessionDelegate = delegate
            self.urlSession = URLSession(
                configuration: Self.sessionConfiguration(),
                delegate: delegate,
                delegateQueue: nil
            )
        } else {
            self.urlSession = URLSession(configuration: Self.sessionConfiguration())
            self.sessionDelegate = nil
        }
    }

    private static func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = 65
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return configuration
    }

    private func record(
        _ level: DiagnosticLogLevel,
        categoryKey: String,
        messageKey: String,
        details: [String: String] = [:]
    ) {
        DiagnosticLogStore.shared.record(level, categoryKey: categoryKey, messageKey: messageKey, details: details)
    }

    static func normalizedBaseURL(
        from input: String,
        defaultScheme: String = "https"
    ) throws -> URL {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw DSMClientError.invalidAddress }
        let hadExplicitScheme = value.contains("://")
        if !hadExplicitScheme {
            let normalizedDefaultScheme = defaultScheme.lowercased()
            guard normalizedDefaultScheme == "http" || normalizedDefaultScheme == "https" else {
                throw DSMClientError.invalidAddress
            }
            value = "\(normalizedDefaultScheme)://\(value)"
        }
        guard var components = URLComponents(string: value), components.host != nil else {
            throw DSMClientError.invalidAddress
        }
        let scheme = components.scheme?.lowercased()
        if scheme == "http", !isPrivateNetworkHost(components.host) {
            throw DSMClientError.insecureHTTP
        }
        if components.port == nil, !hadExplicitScheme {
            components.port = scheme == "http" ? 5000 : 5001
        }
        if components.path == "/" {
            components.path = ""
        }
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw DSMClientError.invalidAddress }
        return url
    }

    func login(
        account: String,
        password: String,
        oneTimeCode: String = "",
        deviceID: String? = nil
    ) async throws -> DSMSession {
        record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.login.started",
            details: [
                "target": DiagnosticLogStore.redactedURL(baseURL),
                "account": account.isEmpty ? "-" : "<redacted>",
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
        var lastError: Error?
        for request in authLoginRequests(
            account: account,
            password: password,
            oneTimeCode: cleanedCode,
            deviceID: deviceID,
            apiInfo: apiInfo
        ) {
            do {
                let data = try await call(path: request.0, queryItems: request.1, timeout: 60)
                if let sid = data.firstString(for: ["sid"]) {
                    let trustedDeviceID = data.firstString(
                        for: ["device_id", "deviceId", "did", "device_token"]
                    ) ?? deviceID
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
                        allowsSelfSignedCertificates: allowsSelfSignedCertificates,
                        deviceID: trustedDeviceID
                    )
                }
            } catch {
                lastError = error
                record(
                    .warning,
                    categoryKey: "diagnostics.category.connection",
                    messageKey: "diagnostics.login.attempt_failed",
                    details: requestSummary(path: request.0, queryItems: request.1).merging(["error": diagnosticMessage(for: error)]) { current, _ in current }
                )
                if shouldRetryAuthVersion(after: error) {
                    continue
                }
                record(
                    .error,
                    categoryKey: "diagnostics.category.connection",
                    messageKey: "diagnostics.login.failed",
                    details: [
                        "target": DiagnosticLogStore.redactedURL(baseURL),
                        "error": diagnosticMessage(for: error)
                    ]
                )
                throw error
            }
        }
        record(
            .error,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.login.failed",
            details: ["target": DiagnosticLogStore.redactedURL(baseURL)]
        )
        throw lastError ?? DSMClientError.missingSession
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

    func isDSMEndpoint() async -> Bool {
        let data = await optionalCall(
            path: "/webapi/query.cgi",
            queryItems: [
                URLQueryItem(name: "api", value: "SYNO.API.Info"),
                URLQueryItem(name: "version", value: "1"),
                URLQueryItem(name: "method", value: "query"),
                URLQueryItem(name: "query", value: "SYNO.API.Auth,SYNO.Core.System")
            ]
        )
        return data?.objectValue?["SYNO.API.Auth"] != nil
    }

    func loadSnapshot(session: DSMSession, useAgent _: Bool) async -> DSMDataSnapshot {
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
                        "SYNO.Core.Certificate.CRT",
                        "SYNO.Core.Terminal",
                        "SYNO.FileStation.List",
                        "SYNO.Core.Package",
                        "SYNO.Core.AppPortal.ReverseProxy",
                        "SYNO.Core.Network.Interface",
                        "SYNO.Storage.CGI.Storage",
                        "SYNO.Storage.CGI.Volume",
                        "SYNO.ContainerManager.Container",
                        "SYNO.Docker.Container",
                        "SYNO.ContainerManager.Container.Resource",
                        "SYNO.Docker.Container.Resource"
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
        async let certificateData = firstSuccessfulCall(apiRequests(
            session,
            apiInfo: apiInfo,
            apiName: "SYNO.Core.Certificate.CRT",
            fallbackPath: "/webapi/entry.cgi",
            fallbackMaxVersion: 1,
            method: "list"
        ))
        async let terminalData = firstSuccessfulCall(apiRequests(
            session,
            apiInfo: apiInfo,
            apiName: "SYNO.Core.Terminal",
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
        async let reverseProxyData = firstSuccessfulCall(apiRequests(
            session,
            apiInfo: apiInfo,
            apiName: "SYNO.Core.AppPortal.ReverseProxy",
            fallbackPath: "/webapi/entry.cgi",
            fallbackMaxVersion: 1,
            method: "list"
        ))
        async let networkInterfaceData = firstSuccessfulCall(apiRequests(
            session,
            apiInfo: apiInfo,
            apiName: "SYNO.Core.Network.Interface",
            fallbackPath: "/webapi/entry.cgi",
            fallbackMaxVersion: 1,
            method: "list"
        ))
        async let storageData = firstSuccessfulCall(storageRequests(session, apiInfo: apiInfo))
        async let dockerData = firstSuccessfulContainerCall(containerRequests(session, apiInfo: apiInfo))
        async let dockerResourceData = firstSuccessfulCall(
            containerResourceRequests(session, apiInfo: apiInfo)
        )

        let system = await systemData
        let utilization = await utilizationData
        let certificate = await certificateData
        let terminal = await terminalData
        let storage = await storageData
        let files = DSMClient.mapSharedFolders(await sharedFolderData)
        let docker = await dockerData
        let dockerResources = await dockerResourceData
        let packages = await packageData
        let reverseProxies = await reverseProxyData
        let hostTotalMemoryBytes = DSMClient.mapMemoryTotalBytes(utilization)
        let resourceSampleCount = DSMClient.mapContainerResources(
            dockerResources,
            hostTotalMemoryBytes: hostTotalMemoryBytes
        ).count
        let mappedContainers = DSMClient.mapContainers(
            docker,
            resourceData: dockerResources,
            hostTotalMemoryBytes: hostTotalMemoryBytes
        )
        let containers = await enrichContainers(
            mappedContainers,
            session: session,
            apiInfo: apiInfo
        )
        let lanHosts = DSMClient.mapLANHosts(await networkInterfaceData)
        let services = await mapServices(
            containers: containers,
            packageData: packages,
            reverseProxyData: reverseProxies,
            lanHosts: lanHosts,
            session: session
        )
        let device = DSMClient.mapDevice(
            system: system,
            utilization: utilization,
            storageData: storage,
            certificateData: certificate,
            terminalData: terminal,
            session: session
        )

        record(
            .info,
            categoryKey: "diagnostics.category.dsm_api",
            messageKey: "diagnostics.snapshot.completed",
            details: [
                "services": "\(services.count)",
                "launchpadServices": "\(services.filter(\.isLaunchpadVisible).count)",
                "containers": "\(containers.count)",
                "containerServices": "\(services.filter { $0.source == .container || $0.source == .reverseProxy }.count)",
                "containerEndpoints": "\(services.filter { ($0.source == .container || $0.source == .reverseProxy) && $0.endpoint != nil }.count)",
                "lanContainerEndpoints": "\(services.filter { $0.source == .container && $0.endpoint != nil }.count)",
                "alternateLANEndpoints": "\(services.filter { $0.alternateEndpoint != nil }.count)",
                "reverseProxyEndpoints": "\(services.filter { $0.source == .reverseProxy && $0.endpoint != nil }.count)",
                "httpEndpoints": "\(services.filter { $0.endpoint?.scheme?.lowercased() == "http" }.count)",
                "httpsEndpoints": "\(services.filter { $0.endpoint?.scheme?.lowercased() == "https" }.count)",
                "connectionLocation": Self.isPrivateNetworkHost(session.baseURL.host) ? "local" : "remote",
                "packages": "\(services.filter { $0.source == .package }.count)",
                "lanHosts": "\(lanHosts.count)",
                "publishedPorts": "\(containers.reduce(0) { $0 + $1.ports.count })",
                "resourceSamples": "\(resourceSampleCount)",
                "uptimeMinutes": device.uptimeMinutes.map { String($0) } ?? "-",
                "volumes": "\(Self.storageVolumeItems(storage).count)",
                "folders": "\(files.count)"
            ]
        )

        return DSMDataSnapshot(
            device: device,
            services: services,
            containers: containers,
            files: files,
            tasks: [],
            videoLibraryItems: [],
            audioLibraryItems: [],
            discoveredDevices: [],
            containerInventoryAvailable: docker != nil,
            packageInventoryAvailable: packages != nil,
            reverseProxyInventoryAvailable: reverseProxies != nil
        )
    }

    func listFolder(session: DSMSession, folderPath: String) async throws -> [FileItem] {
        let normalizedPath = folderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "/" : folderPath
        let apiInfo = await optionalCall(
            path: "/webapi/query.cgi",
            queryItems: [
                URLQueryItem(name: "api", value: "SYNO.API.Info"),
                URLQueryItem(name: "version", value: "1"),
                URLQueryItem(name: "method", value: "query"),
                URLQueryItem(name: "query", value: "SYNO.FileStation.List")
            ]
        )
        let encodedPath = Self.jsonQueryValue(normalizedPath) ?? normalizedPath
        let encodedAdditional = Self.jsonQueryValue(["real_path", "size", "time", "type"])
            ?? "[\"real_path\",\"size\",\"time\",\"type\"]"
        let pageSize = 500
        var offset = 0
        var allItems: [FileItem] = []

        while offset < 25_000 {
            let common = [
                URLQueryItem(name: "limit", value: "\(pageSize)"),
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "sort_by", value: "name"),
                URLQueryItem(name: "sort_direction", value: "asc")
            ]
            let parameterVariants = [
                [
                    URLQueryItem(name: "folder_path", value: encodedPath),
                    URLQueryItem(name: "additional", value: encodedAdditional)
                ] + common,
                [
                    URLQueryItem(name: "folder_path", value: normalizedPath),
                    URLQueryItem(name: "additional", value: encodedAdditional)
                ] + common,
                [URLQueryItem(name: "folder_path", value: normalizedPath)] + common
            ]
            let data = await firstSuccessfulCall(apiRequests(
                session,
                apiInfo: apiInfo,
                apiName: "SYNO.FileStation.List",
                fallbackPath: "/webapi/entry.cgi",
                fallbackMaxVersion: 2,
                method: "list",
                extras: parameterVariants
            ))
            guard let data else { throw DSMClientError.invalidResponse }

            let page = DSMClient.mapFileItems(data, parentPath: normalizedPath)
            allItems.append(contentsOf: page)
            let total = Int(data.firstDouble(for: ["total", "total_count"]) ?? 0)
            offset += page.count
            if page.isEmpty || page.count < pageSize || (total > 0 && offset >= total) {
                break
            }
        }

        let items = Dictionary(grouping: allItems, by: \FileItem.path)
            .compactMap { $0.value.first }
            .sorted(by: DSMClient.sortFiles)
        record(
            .info,
            categoryKey: "diagnostics.category.dsm_api",
            messageKey: "diagnostics.files.folder_loaded",
            details: [
                "pathDepth": "\(normalizedPath.split(separator: "/").count)",
                "items": "\(items.count)"
            ]
        )
        return items
    }

    private static func jsonQueryValue<T: Encodable>(_ value: T) -> String? {
        guard
            let data = try? JSONEncoder().encode(value),
            let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    private func call(
        path: String,
        queryItems: [URLQueryItem],
        timeout: TimeInterval = requestTimeout
    ) async throws -> DSMJSONValue {
        guard
            let requestURL = DSMURLBuilder.url(baseURL: baseURL, appending: path),
            var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)
        else {
            throw DSMClientError.invalidAddress
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw DSMClientError.invalidAddress }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await urlSession.data(for: request)
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
        deviceID: String?,
        apiInfo: DSMJSONValue?
    ) -> [(String, [URLQueryItem])] {
        let entry = apiInfoEntry(apiInfo, apiName: "SYNO.API.Auth")
        let path = normalizedAPIPath(entry?.path ?? "/webapi/auth.cgi")
        let versions = entry.map {
            Array(stride(from: max($0.maxVersion, 1), through: 1, by: -1))
        } ?? [7, 6, 3]
        return versions.map { version in
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
            if version >= 6 {
                items.append(URLQueryItem(name: "enable_device_token", value: "yes"))
                items.append(URLQueryItem(name: "device_name", value: "Nastart"))
                if let deviceID, !deviceID.isEmpty {
                    items.append(URLQueryItem(name: "device_id", value: deviceID))
                }
            }
            return (path, items)
        }
    }

    private func shouldRetryAuthVersion(after error: Error) -> Bool {
        guard
            case DSMClientError.apiFailed(let optionalCode) = error,
            let code = optionalCode
        else {
            return false
        }
        return [102, 103, 104].contains(code)
    }

    private func containerRequests(_ session: DSMSession, apiInfo: DSMJSONValue?) -> [(String, [URLQueryItem])] {
        let commonExtras = [
            URLQueryItem(name: "limit", value: "1000"),
            URLQueryItem(name: "offset", value: "0")
        ]
        let allExtras = commonExtras + [URLQueryItem(name: "type", value: "all")]

        let apiNames = ["SYNO.ContainerManager.Container", "SYNO.Docker.Container"]
        let availableEntries = apiNames.compactMap { apiName -> (String, String, Int)? in
            guard let entry = apiInfoEntry(apiInfo, apiName: apiName) else { return nil }
            return (apiName, normalizedAPIPath(entry.path), max(entry.maxVersion, 1))
        }

        if !availableEntries.isEmpty {
            return availableEntries.flatMap { apiName, path, version in
                [allExtras, commonExtras].map { extras in
                    (
                        path,
                        sessionItems(
                            session,
                            api: apiName,
                            version: "\(version)",
                            method: "list",
                            extra: extras
                        )
                    )
                }
            }
        }

        return [
            (
                "/webapi/entry.cgi",
                sessionItems(
                    session,
                    api: "SYNO.Docker.Container",
                    version: "1",
                    method: "list",
                    extra: allExtras
                )
            ),
            (
                "/webapi/entry.cgi",
                sessionItems(
                    session,
                    api: "SYNO.ContainerManager.Container",
                    version: "1",
                    method: "list",
                    extra: allExtras
                )
            )
        ]
    }

    private func containerResourceRequests(
        _ session: DSMSession,
        apiInfo: DSMJSONValue?
    ) -> [(String, [URLQueryItem])] {
        let apiNames = [
            "SYNO.ContainerManager.Container.Resource",
            "SYNO.Docker.Container.Resource"
        ]
        let availableEntries = apiNames.compactMap { apiName -> (String, String, Int)? in
            guard let entry = apiInfoEntry(apiInfo, apiName: apiName) else { return nil }
            return (apiName, normalizedAPIPath(entry.path), max(entry.maxVersion, 1))
        }

        if !availableEntries.isEmpty {
            return availableEntries.map { apiName, path, version in
                (
                    path,
                    sessionItems(
                        session,
                        api: apiName,
                        version: "\(version)",
                        method: "get"
                    )
                )
            }
        }

        return apiNames.map { apiName in
            (
                "/webapi/entry.cgi",
                sessionItems(
                    session,
                    api: apiName,
                    version: "1",
                    method: "get"
                )
            )
        }
    }

    private func containerDetailRequests(
        _ session: DSMSession,
        apiInfo: DSMJSONValue?,
        containerName: String
    ) -> [(String, [URLQueryItem])] {
        let apiNames = ["SYNO.ContainerManager.Container", "SYNO.Docker.Container"]
        let availableEntries = apiNames.compactMap { apiName -> (String, String, Int)? in
            guard let entry = apiInfoEntry(apiInfo, apiName: apiName) else { return nil }
            return (apiName, normalizedAPIPath(entry.path), max(entry.maxVersion, 1))
        }
        let entries: [(String, String, Int)] = availableEntries.isEmpty
            ? [("SYNO.Docker.Container", "/webapi/entry.cgi", 1)]
            : availableEntries

        return entries.map { apiName, path, version in
            (
                path,
                sessionItems(
                    session,
                    api: apiName,
                    version: "\(version)",
                    method: "get",
                    extra: [URLQueryItem(name: "name", value: containerName)]
                )
            )
        }
    }

    private func enrichContainers(
        _ containers: [DockerContainer],
        session: DSMSession,
        apiInfo: DSMJSONValue?
    ) async -> [DockerContainer] {
        let details = await withTaskGroup(
            of: (UUID, DSMJSONValue?).self,
            returning: [UUID: DSMJSONValue].self
        ) { group in
            for container in containers where container.status == .online {
                group.addTask {
                    let detail = await self.firstSuccessfulCall(
                        self.containerDetailRequests(
                            session,
                            apiInfo: apiInfo,
                            containerName: container.name
                        )
                    )
                    return (container.id, detail)
                }
            }

            var result: [UUID: DSMJSONValue] = [:]
            for await (id, detail) in group {
                if let detail {
                    result[id] = detail
                }
            }
            return result
        }

        return containers.map { container in
            guard let detail = details[container.id] else { return container }
            let ports = Self.uniqueStrings(container.ports + Self.mapPorts(detail))
            guard ports != container.ports else { return container }
            return DockerContainer(
                id: container.id,
                name: container.name,
                image: container.image,
                status: container.status,
                cpu: container.cpu,
                memoryText: container.memoryText,
                memoryBytes: container.memoryBytes,
                memoryPercent: container.memoryPercent,
                ports: ports
            )
        }
    }

    private func storageRequests(_ session: DSMSession, apiInfo: DSMJSONValue?) -> [(String, [URLQueryItem])] {
        var requests: [(String, [URLQueryItem])] = []
        if apiInfoEntry(apiInfo, apiName: "SYNO.Storage.CGI.Storage") != nil || apiInfo == nil {
            requests += apiRequests(
                session,
                apiInfo: apiInfo,
                apiName: "SYNO.Storage.CGI.Storage",
                fallbackPath: "/webapi/entry.cgi",
                fallbackMaxVersion: 1,
                method: "load_info"
            )
        }
        if apiInfoEntry(apiInfo, apiName: "SYNO.Storage.CGI.Volume") != nil || apiInfo == nil {
            for method in ["list", "get"] {
                requests += apiRequests(
                    session,
                    apiInfo: apiInfo,
                    apiName: "SYNO.Storage.CGI.Volume",
                    fallbackPath: "/webapi/entry.cgi",
                    fallbackMaxVersion: 1,
                    method: method
                )
            }
        }
        return requests
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
                details: requestSummary(path: request.0, queryItems: request.1).merging([
                    "count": "\(containers.count)",
                    "running": "\(containers.filter { $0.status == .online }.count)",
                    "stopped": "\(containers.filter { $0.status == .offline }.count)",
                    "mappedPorts": "\(containers.reduce(0) { $0 + $1.ports.count })"
                ]) { current, _ in current }
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

    private func recordAPIInfoCoverage(_ apiInfo: DSMJSONValue?) {
        let apiNames = [
            "SYNO.Core.System",
            "SYNO.Core.System.Utilization",
            "SYNO.Core.Certificate.CRT",
            "SYNO.Core.Terminal",
            "SYNO.FileStation.List",
            "SYNO.Core.Package",
            "SYNO.Core.AppPortal.ReverseProxy",
            "SYNO.Core.Network.Interface",
            "SYNO.Storage.CGI.Storage",
            "SYNO.Storage.CGI.Volume",
            "SYNO.ContainerManager.Container",
            "SYNO.Docker.Container",
            "SYNO.ContainerManager.Container.Resource",
            "SYNO.Docker.Container.Resource"
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

    private static func mapDevice(
        system: DSMJSONValue?,
        utilization: DSMJSONValue?,
        storageData: DSMJSONValue?,
        certificateData: DSMJSONValue?,
        terminalData: DSMJSONValue?,
        session: DSMSession
    ) -> NASDevice {
        let hostName = session.baseURL.host ?? "DSM"
        let model = nonEmptyString(system?.firstString(for: ["model", "model_name", "modelName"]))
        let name = nonEmptyString(system?.firstString(for: ["server_name", "hostname", "serverName"]))
            ?? model
            ?? hostName
        let version = normalizedDSMVersion(system?.firstString(for: ["firmware_ver", "dsm_version", "version", "firmware"]))
        let mode: ConnectionMode = .dsmOnly
        let cpu = mapCPU(utilization)
        let memory = mapMemory(utilization)
        let storage = mapStorage(storageData: storageData, utilization: utilization)
        let certificate = mapCertificate(certificateData, usesCustomTrust: session.allowsSelfSignedCertificates)
        let sshStatus = mapSSHStatus(terminalData)
        let subtitle = model.flatMap { $0.caseInsensitiveCompare(name) == .orderedSame ? nil : $0 }
            ?? "DSM"

        return NASDevice(
            id: StableIdentifier.uuid("device|\(session.baseURL.absoluteString)"),
            name: name,
            subtitle: subtitle,
            model: model,
            dsmVersion: version,
            mode: mode,
            cpu: cpu,
            memory: memory.progress,
            memoryUsedText: memory.usedText,
            memoryTotalText: memory.totalText,
            storageUsed: storage.progress,
            storageUsedText: storage.usedText,
            storageTotalText: storage.totalText,
            storageFreeText: storage.freeText,
            uptimeMinutes: mapUptimeMinutes(system?.firstValue(for: ["uptime", "up_time"])),
            temperatureText: mapTemperature(system: system, utilization: utilization),
            certificate: certificate,
            sshStatus: sshStatus
        )
    }

    private static func mapCPU(_ utilization: DSMJSONValue?) -> Double? {
        guard let cpu = utilization?.firstValue(for: ["cpu"]) else { return nil }
        if let load = cpu.firstDouble(for: ["total_load", "load", "usage"]) {
            return DSMFormatters.percentage(load)
        }
        guard
            cpu.firstDouble(for: ["user_load"]) != nil
                || cpu.firstDouble(for: ["system_load"]) != nil
                || cpu.firstDouble(for: ["other_load"]) != nil
        else {
            return nil
        }
        let user = cpu.firstDouble(for: ["user_load"]) ?? 0
        let system = cpu.firstDouble(for: ["system_load"]) ?? 0
        let other = cpu.firstDouble(for: ["other_load"]) ?? 0
        return DSMFormatters.percentage(user + system + other)
    }

    private static func mapMemory(
        _ utilization: DSMJSONValue?
    ) -> (progress: Double?, usedText: String?, totalText: String?) {
        guard let memory = utilization?.firstValue(for: ["memory"]) else {
            return (nil, nil, nil)
        }
        let reportedProgress = memory.firstDouble(for: ["real_usage", "usage", "memory_usage"]).map {
            DSMFormatters.percentage($0)
        }
        let totalRaw = memory.firstDouble(for: ["memory_size", "total", "total_memory", "mem_total"])
        let availableRaw = memory.firstDouble(for: ["avail_real", "available", "available_memory", "mem_available"])
        let measuredUsedRaw = memory.firstDouble(for: ["used", "used_memory", "mem_used"])
            ?? totalRaw.flatMap { total in availableRaw.map { max(total - $0, 0) } }
        let progress = reportedProgress
            ?? totalRaw.flatMap { total in measuredUsedRaw.map { total > 0 ? min(max($0 / total, 0), 1) : 0 } }
        // DSM's real_usage excludes reclaimable cache. Use the same value for
        // percentage and capacity text so separate screens cannot disagree.
        let displayUsedRaw = totalRaw.flatMap { total in progress.map { total * $0 } }
            ?? measuredUsedRaw
        let totalBytes = totalRaw.map(normalizedMemoryBytes)
        let usedBytes = displayUsedRaw.map(normalizedMemoryBytes)
        return (progress, DSMFormatters.bytes(usedBytes), DSMFormatters.bytes(totalBytes))
    }

    private static func mapMemoryTotalBytes(_ utilization: DSMJSONValue?) -> Double? {
        utilization?
            .firstValue(for: ["memory"])?
            .firstDouble(for: ["memory_size", "total", "total_memory", "mem_total"])
            .map(normalizedMemoryBytes)
    }

    private static func mapStorage(
        storageData: DSMJSONValue?,
        utilization: DSMJSONValue?
    ) -> (progress: Double?, usedText: String?, totalText: String?, freeText: String) {
        let storageCandidates = storageVolumeItems(storageData).compactMap {
            storageUsage(from: $0, assumesBytes: true)
        }
        let utilizationCandidates: [(Double, Double)] = {
            guard let storageRoot = utilization?.firstValue(for: ["space", "volume", "storage"]) else {
                return []
            }
            let items = storageRoot.firstDirectArray(for: ["total", "volumes", "items"])
                ?? allObjects(in: storageRoot)
            return items.compactMap { storageUsage(from: $0, assumesBytes: false) }
        }()
        let candidates = storageCandidates.isEmpty ? utilizationCandidates : storageCandidates
        guard !candidates.isEmpty else { return (nil, nil, nil, "-") }

        let totalBytes = candidates.reduce(0) { $0 + $1.0 }
        let usedBytes = candidates.reduce(0) { $0 + $1.1 }
        let freeBytes = max(totalBytes - usedBytes, 0)
        return (
            min(max(usedBytes / totalBytes, 0), 1),
            DSMFormatters.bytes(usedBytes),
            DSMFormatters.bytes(totalBytes),
            DSMFormatters.bytes(freeBytes) ?? "-"
        )
    }

    private static func storageVolumeItems(_ data: DSMJSONValue?) -> [DSMJSONValue] {
        guard let data else { return [] }
        let root = data.firstDirectValue(for: ["data", "result"]) ?? data
        if let volumes = root.firstDirectArray(for: ["volumes", "volume", "volume_list", "volumeList"]) {
            return volumes
        }
        let listed = arrays(
            in: root,
            matching: Set(["volumes", "volume", "volume_list", "volumelist"])
        ).flatMap { $0 }
        if !listed.isEmpty { return listed }
        return allObjects(in: root).filter { item in
            let identity = directTextValue(
                in: item,
                keys: ["id", "volume_id", "volumeId", "path", "volume_path"]
            )?.lowercased() ?? ""
            return identity.contains("volume") && storageUsage(from: item, assumesBytes: true) != nil
        }
    }

    private static func storageUsage(
        from item: DSMJSONValue,
        assumesBytes: Bool
    ) -> (Double, Double)? {
        let size = item.firstDirectValue(for: ["size", "usage", "space"])
        let totalKeys = [
            "size_total", "total_size", "total", "capacity",
            "total_byte", "total_bytes", "totalByte", "totalBytes"
        ]
        let usedKeys = [
            "size_used", "used_size", "used",
            "used_byte", "used_bytes", "usedByte", "usedBytes"
        ]
        let freeKeys = [
            "size_free", "free_size", "free", "available",
            "free_byte", "free_bytes", "freeByte", "freeBytes"
        ]
        let totalRaw = item.firstDirectDouble(for: totalKeys)
            ?? size?.firstDirectDouble(for: totalKeys)
        let usedRaw = item.firstDirectDouble(for: usedKeys)
            ?? size?.firstDirectDouble(for: usedKeys)
        let freeRaw = item.firstDirectDouble(for: freeKeys)
            ?? size?.firstDirectDouble(for: freeKeys)
        guard let totalRaw, totalRaw > 0 else { return nil }
        let resolvedUsed = usedRaw ?? freeRaw.map { max(totalRaw - $0, 0) }
        guard let resolvedUsed, resolvedUsed >= 0, resolvedUsed <= totalRaw else { return nil }
        if assumesBytes {
            return (totalRaw, resolvedUsed)
        }
        return (normalizedStorageBytes(totalRaw), normalizedStorageBytes(resolvedUsed))
    }

    private static func normalizedMemoryBytes(_ value: Double) -> Double {
        value < 268_435_456 ? value * 1024 : value
    }

    private static func normalizedStorageBytes(_ value: Double) -> Double {
        value < 100_000_000_000 ? value * 1024 : value
    }

    private static func normalizedDSMVersion(_ value: String?) -> String? {
        guard let value = nonEmptyString(value) else { return nil }
        return value.lowercased().hasPrefix("dsm") ? value : "DSM \(value)"
    }

    private static func mapUptimeMinutes(_ value: DSMJSONValue?) -> Int? {
        guard let value else { return nil }
        let totalMinutes: Int?
        if let seconds = value.doubleValue, seconds >= 0 {
            totalMinutes = Int(seconds) / 60
        } else if let text = value.stringValue {
            let parts = text.split(separator: ":").compactMap { Int($0) }
            switch parts.count {
            case 3:
                totalMinutes = parts[0] * 60 + parts[1]
            case 4:
                totalMinutes = parts[0] * 1_440 + parts[1] * 60 + parts[2]
            default:
                totalMinutes = nil
            }
        } else {
            totalMinutes = nil
        }
        return totalMinutes
    }

    private static func mapTemperature(system: DSMJSONValue?, utilization: DSMJSONValue?) -> String? {
        guard let value = system?.firstDouble(for: ["temperature", "temperature_value", "temp"])
            ?? utilization?.firstDouble(for: ["temperature", "temperature_value", "temp"])
        else {
            return nil
        }
        return "\(Int(value.rounded())) C"
    }

    private static func mapCertificate(
        _ data: DSMJSONValue?,
        usesCustomTrust: Bool
    ) -> NASCertificateInfo? {
        guard let data else { return nil }
        let candidates = allObjects(in: data).filter { item in
            item.firstDirectValue(for: ["valid_till", "valid_until", "not_after", "expire", "expiration"]) != nil
                || item.firstDirectValue(for: ["issuer", "issuer_name", "subject", "subject_name", "desc"]) != nil
        }
        guard let item = candidates.first(where: {
            $0.firstDirectBool(for: ["is_default", "default", "isDefault"]) == true
        }) ?? candidates.first else {
            return nil
        }
        return NASCertificateInfo(
            subject: certificateText(
                in: item,
                keys: ["subject", "subject_name", "common_name", "domain", "desc"]
            ),
            issuer: certificateText(
                in: item,
                keys: ["issuer", "issuer_name", "issuer_common_name"]
            ),
            validFrom: mapCertificateDate(item.firstDirectValue(for: ["valid_from", "valid_since", "not_before", "start"])),
            validUntil: mapCertificateDate(item.firstDirectValue(for: ["valid_till", "valid_until", "not_after", "expire", "expiration"])),
            usesCustomTrust: usesCustomTrust
        )
    }

    private static func certificateText(in item: DSMJSONValue, keys: [String]) -> String? {
        guard let value = item.firstDirectValue(for: keys) else { return nil }
        if let text = nonEmptyString(value.stringValue) {
            return text
        }
        return nonEmptyString(value.firstString(for: [
            "common_name", "commonName", "CN", "name", "organization", "O"
        ]))
    }

    private static func mapCertificateDate(_ value: DSMJSONValue?) -> Date? {
        guard let value else { return nil }
        if let timestamp = value.doubleValue {
            let seconds = timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp
            if seconds > 0 {
                return Date(timeIntervalSince1970: seconds)
            }
        }
        guard let text = value.stringValue else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: text) {
            return date
        }
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "MMM d HH:mm:ss yyyy zzz"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }
        return nil
    }

    private static func mapSSHStatus(_ data: DSMJSONValue?) -> NASSSHStatus {
        guard let enabled = data?.firstBool(for: [
            "enable_ssh", "ssh_enabled", "enable_ssh_service", "ssh"
        ]) else {
            return .unavailable
        }
        return enabled ? .enabled : .disabled
    }

    private static func mapSharedFolders(_ data: DSMJSONValue?) -> [FileItem] {
        guard let shares = data?.firstArray(for: ["shares", "items", "list"]) else { return [] }
        return shares.compactMap { share in
            let rawPath = nonEmptyString(share.firstString(for: ["path", "additional_path"]))
            guard let name = nonEmptyString(share.firstString(for: ["name", "display_name"])) ?? lastPathComponent(rawPath ?? "") else { return nil }
            let path = rawPath ?? "/\(name)"
            return FileItem(
                id: StableIdentifier.uuid("file|\(path)"),
                name: name,
                subtitle: path,
                path: path,
                kind: .folder,
                sizeText: nil,
                children: []
            )
        }
        .sorted(by: sortFiles)
    }

    private static func mapFileItems(_ data: DSMJSONValue?, parentPath: String) -> [FileItem] {
        guard let entries = data?.firstArray(for: ["files", "items", "list"]) else { return [] }
        return entries.compactMap { item in
            let path = filePath(for: item, parentPath: parentPath)
            guard let name = fileName(for: item, path: path) else { return nil }
            let kind = fileKind(for: name, item: item)
            return FileItem(
                id: StableIdentifier.uuid("file|\(path ?? normalizedChildPath(parentPath: parentPath, name: name))"),
                name: name,
                subtitle: path ?? normalizedChildPath(parentPath: parentPath, name: name),
                path: path ?? normalizedChildPath(parentPath: parentPath, name: name),
                kind: kind,
                sizeText: kind == .folder ? nil : fileSizeText(item),
                children: []
            )
        }
        .sorted(by: sortFiles)
    }

    private static func filePath(for item: DSMJSONValue, parentPath: String) -> String? {
        if let path = nonEmptyString(item.firstString(for: ["path", "real_path", "filename"])) {
            if path.hasPrefix("/") { return path }
            return normalizedChildPath(parentPath: parentPath, name: path)
        }
        guard let name = nonEmptyString(item.firstString(for: ["name", "display_name"])) else { return nil }
        return normalizedChildPath(parentPath: parentPath, name: name)
    }

    private static func fileName(for item: DSMJSONValue, path: String?) -> String? {
        nonEmptyString(item.firstString(for: ["name", "display_name"])) ?? lastPathComponent(path ?? "")
    }

    private static func normalizedChildPath(parentPath: String, name: String) -> String {
        let parent = parentPath == "/" ? "" : parentPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let child = name.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "/\([parent, child].filter { !$0.isEmpty }.joined(separator: "/"))"
    }

    private static func lastPathComponent(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        guard !trimmed.isEmpty, let last = trimmed.split(separator: "/").last else { return nil }
        return String(last)
    }

    private static func isFolder(_ item: DSMJSONValue) -> Bool {
        if let explicit = item.firstBool(for: ["isdir", "is_dir", "directory", "isFolder"]) {
            return explicit
        }
        let type = (item.firstString(for: ["type", "kind", "filetype"]) ?? "").lowercased()
        return type.contains("dir") || type.contains("folder") || type.contains("share")
    }

    private static func fileKind(for name: String, item: DSMJSONValue) -> FileKind {
        if isFolder(item) { return .folder }
        let mediaType = (item.firstString(for: [
            "content_type", "contentType", "mime_type", "mimeType", "mimetype"
        ]) ?? "").lowercased()
        if mediaType.hasPrefix("video/") { return .video }
        if mediaType.hasPrefix("audio/") { return .audio }
        let ext = (name as NSString).pathExtension.lowercased()
        if [
            "mp4", "mkv", "mov", "m4v", "avi", "wmv", "webm",
            "ts", "m2ts", "mts", "mpeg", "mpg", "flv", "f4v",
            "3gp", "3g2", "vob", "rm", "rmvb", "ogv", "asf",
            "divx", "mxf", "m2v", "m1v", "mpv", "qt", "dv",
            "h264", "h265", "hevc", "av1", "nut", "amv", "bik",
            "roq", "wtv", "dvr-ms", "mod", "tod"
        ].contains(ext) { return .video }
        if [
            "mp3", "flac", "aac", "m4a", "wav", "ogg", "opus",
            "wma", "ape", "alac", "aiff", "aif", "amr", "ac3", "dts"
        ].contains(ext) { return .audio }
        if [
            "jpg", "jpeg", "png", "gif", "heic", "heif", "webp",
            "bmp", "tif", "tiff", "avif", "dng", "svg"
        ].contains(ext) { return .image }
        if ["zip", "rar", "7z", "tar", "gz"].contains(ext) { return .archive }
        return .text
    }

    private static func fileSizeText(_ item: DSMJSONValue) -> String? {
        if let formatted = nonEmptyString(item.firstString(for: ["size_text", "formatted_size"])) {
            return formatted
        }
        return DSMFormatters.bytes(item.firstDouble(for: ["size", "filesize"]))
    }

    private static func sortFiles(_ lhs: FileItem, _ rhs: FileItem) -> Bool {
        if lhs.isFolder != rhs.isFolder { return lhs.isFolder }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func nonEmptyString(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private struct ContainerResourceMetrics {
        let cpu: Double?
        let memoryBytes: Double?
        let memoryPercent: Double?
    }

    private static func mapContainers(
        _ data: DSMJSONValue?,
        resourceData: DSMJSONValue? = nil,
        hostTotalMemoryBytes: Double? = nil
    ) -> [DockerContainer] {
        let items = containerItems(from: data)
        let resources = mapContainerResources(
            resourceData,
            hostTotalMemoryBytes: hostTotalMemoryBytes
        )
        var seen = Set<String>()
        return items.compactMap { item in
            guard let name = directTextValue(
                in: item,
                keys: ["name", "Name", "container_name", "containerName", "container", "service", "title", "id", "Id", "Names"]
            ) else { return nil }
            let identifier = directTextValue(in: item, keys: ["id", "Id", "container_id", "containerId"])
                ?? name.lowercased()
            guard seen.insert(identifier).inserted else { return nil }
            let image = directTextValue(
                in: item,
                keys: ["image", "Image", "image_name", "imageName", "repository", "repo", "tag", "imageTag", "image_tag"]
            ) ?? "-"
            let stateText = directTextValue(
                in: item,
                keys: ["status", "Status", "state", "State", "status_text", "display_status", "up_time", "health"]
            ) ?? ""
            let explicitRunning = item.firstDirectBool(for: ["running", "Running", "is_running", "started", "start"])
            let resource = [
                normalizedContainerIdentity(name),
                normalizedContainerIdentity(identifier)
            ]
            .compactMap { resources[$0] }
            .first
            let cpu = resource?.cpu
                ?? item.firstDirectDouble(for: ["cpu", "CPU", "cpu_usage", "cpu_percent"]).map {
                    DSMFormatters.percentage($0)
                }
            let memoryBytes = resource?.memoryBytes
            let memoryText = DSMFormatters.bytes(memoryBytes) ?? "-"
            return DockerContainer(
                id: StableIdentifier.uuid("container|\(identifier)"),
                name: name,
                image: image,
                status: explicitRunning.map { $0 ? .online : .offline } ?? serviceStatus(from: stateText),
                cpu: cpu,
                memoryText: memoryText,
                memoryBytes: memoryBytes,
                memoryPercent: resource?.memoryPercent,
                ports: mapPorts(item)
            )
        }
    }

    private static func mapContainerResources(
        _ data: DSMJSONValue?,
        hostTotalMemoryBytes: Double? = nil
    ) -> [String: ContainerResourceMetrics] {
        guard let data else { return [:] }
        let items = data.arrayValue ?? data.firstArray(for: ["resources"]) ?? []
        return items.reduce(into: [:]) { result, item in
            guard let name = directTextValue(
                in: item,
                keys: ["name", "Name", "container_name", "containerName", "id", "Id"]
            ) else { return }

            let cpu = item.firstDirectDouble(
                for: ["cpu", "CPU", "cpu_usage", "cpu_percent", "cpuPercent"]
            )
            .map { dsmPercentage($0) }
            let reportedMemoryBytes = item.firstDirectDouble(
                for: ["memory", "Memory", "memory_bytes", "memoryUsage", "mem_usage"]
            )
            let memoryPercent = item.firstDirectDouble(
                for: ["memoryPercent", "memory_percent", "mem_percent", "memoryPercentage"]
            )
            .map { dsmPercentage($0) }
            // DSM's raw counter may include reclaimable file cache. Its percentage
            // tracks active host memory, so derive a matching byte value when possible.
            let memoryBytes = hostTotalMemoryBytes.flatMap { total in
                memoryPercent.map { total * $0 }
            } ?? reportedMemoryBytes
            result[normalizedContainerIdentity(name)] = ContainerResourceMetrics(
                cpu: cpu,
                memoryBytes: memoryBytes,
                memoryPercent: memoryPercent
            )
        }
    }

    private static func normalizedContainerIdentity(_ value: String) -> String {
        value
            .trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
            .lowercased()
    }

    private static func dsmPercentage(_ value: Double) -> Double {
        min(max(value / 100, 0), 1)
    }

    private static func containerItems(from data: DSMJSONValue?) -> [DSMJSONValue] {
        guard let data else { return [] }
        if let directItems = data.firstDirectArray(for: ["containers", "items", "list", "result"]) {
            return directItems.filter(looksLikeContainer)
        }
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
        return directTextValue(in: item, keys: ["name", "Name", "container_name", "containerName", "id", "Id", "Names"]) != nil
            && (
                directTextValue(in: item, keys: ["image", "Image", "image_name", "imageName", "repository", "repo"]) != nil
                || directTextValue(in: item, keys: ["status", "Status", "state", "State", "status_text", "display_status"]) != nil
                || item.firstDirectArray(for: ["ports", "Ports", "port_bindings", "port_mappings", "portMappings"]) != nil
                || item.firstDirectValue(for: ["PortBindings", "portBindings", "ports"]) != nil
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

    private struct DSMReverseProxyRule {
        let name: String
        let sourceHost: String?
        let sourcePort: Int
        let sourceScheme: String
        let sourcePath: String?
        let destinationPort: Int
    }

    private struct ResolvedContainerEndpoint {
        let url: URL
        let source: LaunchpadServiceSource
        let alternateURL: URL?

        init(
            url: URL,
            source: LaunchpadServiceSource,
            alternateURL: URL? = nil
        ) {
            self.url = url
            self.source = source
            self.alternateURL = alternateURL
        }
    }

    private func mapServices(
        containers: [DockerContainer],
        packageData: DSMJSONValue?,
        reverseProxyData: DSMJSONValue?,
        lanHosts: [String],
        session: DSMSession
    ) async -> [LaunchpadService] {
        let reverseProxyRules = Self.mapReverseProxyRules(reverseProxyData)
        record(
            reverseProxyRules.isEmpty ? .warning : .info,
            categoryKey: "diagnostics.category.dsm_api",
            messageKey: reverseProxyRules.isEmpty
                ? "diagnostics.reverse_proxy.empty"
                : "diagnostics.reverse_proxy.loaded",
            details: [
                "count": "\(reverseProxyRules.count)",
                "http": "\(reverseProxyRules.filter { $0.sourceScheme == "http" }.count)",
                "https": "\(reverseProxyRules.filter { $0.sourceScheme == "https" }.count)"
            ]
        )
        let containerEndpoints = await resolvedContainerEndpoints(
            containers,
            reverseProxyRules: reverseProxyRules,
            lanHosts: lanHosts,
            baseURL: session.baseURL
        )
        var services: [LaunchpadService] = [
            LaunchpadService(
                id: StableIdentifier.uuid("service|dsm|\(session.baseURL.absoluteString)"),
                name: "DSM",
                iconText: "DSM",
                category: .favorites,
                status: .online,
                subtitle: session.baseURL.host ?? "DSM",
                detail: "service.dsm.detail",
                isMedia: false,
                cpu: nil,
                memoryText: nil,
                endpoint: session.baseURL,
                source: .dsm
            )
        ]

        services += containers.map { container in
            let resolvedEndpoint = containerEndpoints[container.id]
            return LaunchpadService(
                id: StableIdentifier.uuid("service|container|\(container.id.uuidString.lowercased())"),
                name: Self.displayName(for: container.name),
                iconText: Self.iconText(for: container.name),
                category: Self.category(for: container.name),
                status: container.status,
                subtitle: Self.subtitle(for: container),
                detail: container.image,
                isMedia: Self.isMedia(container.name),
                cpu: container.cpu,
                memoryText: container.memoryText,
                memory: container.memoryPercent,
                ports: container.ports,
                endpoint: resolvedEndpoint?.url,
                alternateEndpoint: resolvedEndpoint?.alternateURL,
                source: resolvedEndpoint?.source ?? .container,
                isLaunchpadVisible: true
            )
        }

        let packageServices = Self.mapPackageServices(packageData, session: session)
        record(
            packageServices.contains(where: { $0.status == .unknown }) ? .warning : .info,
            categoryKey: "diagnostics.category.dsm_api",
            messageKey: "diagnostics.package.status_summary",
            details: [
                "installed": "\(packageServices.filter { $0.status == .installed }.count)",
                "online": "\(packageServices.filter { $0.status == .online }.count)",
                "offline": "\(packageServices.filter { $0.status == .offline }.count)",
                "unknown": "\(packageServices.filter { $0.status == .unknown }.count)"
            ]
        )
        services += packageServices

        var seen = Set<String>()
        return services.filter { service in
            let sourceKey: String
            switch service.source {
            case .dsm: sourceKey = "dsm"
            case .container, .reverseProxy:
                // The container list is already deduplicated by DSM identifier.
                // Keep similarly named instances instead of collapsing them by display name.
                return true
            case .package: sourceKey = "package"
            case .manual: sourceKey = "manual"
            }
            let key = "\(sourceKey)|\(service.name.lowercased())|\(service.detail.lowercased())"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        .sorted { lhs, rhs in
            let lhsRank = Self.serviceSortRank(lhs)
            let rhsRank = Self.serviceSortRank(rhs)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.category.rawValue != rhs.category.rawValue {
                return Self.categorySortRank(lhs.category) < Self.categorySortRank(rhs.category)
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func mapPackageServices(_ data: DSMJSONValue?, session: DSMSession) -> [LaunchpadService] {
        guard let data else { return [] }
        let packageRoot = data.firstDirectValue(for: ["result", "data"]) ?? data
        guard let packages = packageRoot.firstDirectArray(for: ["packages", "items", "list"]) else { return [] }
        return packages.compactMap { item in
            guard let name = directTextValue(
                in: item,
                keys: ["display_name", "displayName", "name", "id", "package", "package_name", "pkgname"]
            ) else { return nil }
            guard isInstalledPackage(item) else { return nil }
            let endpoint = packageEndpoint(for: item, baseURL: session.baseURL)
            let isBuiltIn = item.firstDirectBool(for: ["builtin", "is_builtin", "system", "is_system"]) == true
            guard endpoint != nil || !isBuiltIn || shouldShowPackageService(name) else { return nil }
            let status = packageStatus(item)
            return LaunchpadService(
                id: StableIdentifier.uuid("service|package|\(name.lowercased())"),
                name: displayName(for: name),
                iconText: iconText(for: name),
                category: category(for: name),
                status: status,
                subtitle: directTextValue(
                    in: item,
                    keys: ["version", "install_version", "installed_version", "pkg_version"]
                ) ?? "DSM package",
                detail: name,
                isMedia: isMedia(name),
                cpu: nil,
                memoryText: nil,
                endpoint: endpoint,
                source: .package,
                isLaunchpadVisible: shouldAutomaticallyAddPackageService(name)
            )
        }
    }

    private func resolvedContainerEndpoints(
        _ containers: [DockerContainer],
        reverseProxyRules: [DSMReverseProxyRule],
        lanHosts: [String],
        baseURL: URL
    ) async -> [UUID: ResolvedContainerEndpoint] {
        await withTaskGroup(
            of: (UUID, ResolvedContainerEndpoint?).self,
            returning: [UUID: ResolvedContainerEndpoint].self
        ) { group in
            for container in containers where container.status == .online {
                group.addTask {
                    let candidates = Self.endpointCandidates(
                        for: container,
                        baseURL: baseURL,
                        lanHosts: lanHosts
                    )
                    if Self.isPrivateNetworkHost(baseURL.host) {
                        let reachableEndpoint = await self.firstReachableWebEndpoint(
                            candidates,
                            serviceName: container.name
                        )
                        let endpoint = reachableEndpoint
                            ?? Self.unverifiedFallbackEndpoint(for: container, candidates: candidates)
                        if let endpoint {
                            return (
                                container.id,
                                ResolvedContainerEndpoint(url: endpoint, source: .container)
                            )
                        }
                    }
                    if let endpoint = Self.reverseProxyEndpoint(
                        for: container,
                        rules: reverseProxyRules,
                        baseURL: baseURL
                    ) {
                        let localCandidates = candidates.filter {
                            Self.isPrivateNetworkHost($0.host)
                                && $0.scheme?.lowercased() == "http"
                        }
                        let discoveredLocalEndpoint = await self.firstReachableWebEndpoint(
                            Array(localCandidates.prefix(4)),
                            serviceName: container.name
                        )
                        let localEndpoint = discoveredLocalEndpoint.flatMap { discovered in
                            Self.isPrivateNetworkHost(discovered.host)
                                && discovered.scheme?.lowercased() == "http"
                                ? Self.originURL(for: discovered)
                                : nil
                        }
                        return (
                            container.id,
                            ResolvedContainerEndpoint(
                                url: endpoint,
                                source: .reverseProxy,
                                alternateURL: localEndpoint
                            )
                        )
                    }
                    let reachableEndpoint = await self.firstReachableWebEndpoint(
                        candidates,
                        serviceName: container.name
                    )
                    let endpoint = reachableEndpoint
                        ?? Self.unverifiedFallbackEndpoint(for: container, candidates: candidates)
                    return (
                        container.id,
                        endpoint.map { ResolvedContainerEndpoint(url: $0, source: .container) }
                    )
                }
            }

            var endpoints: [UUID: ResolvedContainerEndpoint] = [:]
            for await (id, endpoint) in group {
                if let endpoint {
                    endpoints[id] = endpoint
                }
            }
            return endpoints
        }
    }

    private static func mapLANHosts(_ data: DSMJSONValue?) -> [String] {
        guard let data else { return [] }
        let hosts = allObjects(in: data).compactMap { item -> String? in
            let status = item.firstDirectString(for: ["status", "state", "link_status"])?.lowercased() ?? ""
            if status.contains("down") || status.contains("disconnect") {
                return nil
            }
            guard let rawAddress = item.firstDirectString(for: [
                "ip", "ipv4", "ip_address", "ipaddr", "address"
            ]) else {
                return nil
            }
            let address = rawAddress.split(separator: "/").first.map(String.init) ?? rawAddress
            return isPrivateIPv4(address) ? address : nil
        }
        return uniqueStrings(hosts)
    }

    private static func isPrivateIPv4(_ address: String) -> Bool {
        let octets = address.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else {
            return false
        }
        return octets[0] == 10
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 192 && octets[1] == 168)
    }

    private static func isPrivateNetworkHost(_ host: String?) -> Bool {
        NetworkHostClassifier.isPrivate(host)
    }

    private static func mapReverseProxyRules(_ data: DSMJSONValue?) -> [DSMReverseProxyRule] {
        guard let data else { return [] }
        let root = data.firstDirectValue(for: ["data", "result"]) ?? data
        let listedItems = root.firstDirectArray(for: ["entries", "rules", "items", "list"])
            ?? arrays(in: root, matching: Set(["entries", "rules"])).flatMap { $0 }
        let items = listedItems.isEmpty
            ? allObjects(in: root).filter {
                let hasNestedRule = $0.firstDirectValue(for: ["frontend", "source", "incoming"]) != nil
                    && $0.firstDirectValue(for: ["backend", "destination", "target"]) != nil
                let hasFlatRule = $0.firstDirectValue(for: ["src_port", "source_port", "frontend_port"]) != nil
                    && $0.firstDirectValue(for: ["dest_port", "destination_port", "backend_port", "target_port"]) != nil
                return hasNestedRule || hasFlatRule
            }
            : listedItems
        return items.compactMap { item in
            let source = item.firstDirectValue(for: ["frontend", "source", "incoming"]) ?? item
            let destination = item.firstDirectValue(for: ["backend", "destination", "target"]) ?? item
            guard
                let sourcePort = numericPort(source.firstDirectString(for: [
                    "port", "source_port", "src_port", "listen_port", "frontend_port"
                ])),
                let destinationPort = numericPort(destination.firstDirectString(for: [
                    "port", "destination_port", "dest_port", "target_port", "backend_port"
                ]))
            else {
                return nil
            }
            let rawProtocol = source.firstDirectString(for: [
                "protocol", "scheme", "type",
                "source_protocol", "src_protocol", "frontend_protocol"
            ])?.lowercased()
            let sourceScheme = rawProtocol == "https"
                || rawProtocol == "1"
                || source.firstDirectBool(for: ["https", "ssl", "tls"]) == true
                ? "https"
                : "http"
            let sourceHost = nonEmptyString(source.firstDirectString(for: [
                "fqdn", "hostname", "host", "source_host", "src_host", "src_hostname", "frontend_host"
            ]))
            let sourcePath = nonEmptyString(source.firstDirectString(for: [
                "path", "source_path", "src_path", "frontend_path"
            ]))
            let name = directTextValue(in: item, keys: ["description", "name", "title", "id"]) ?? ""
            return DSMReverseProxyRule(
                name: name,
                sourceHost: sourceHost,
                sourcePort: sourcePort,
                sourceScheme: sourceScheme,
                sourcePath: sourcePath,
                destinationPort: destinationPort
            )
        }
    }

    private static func reverseProxyEndpoint(
        for container: DockerContainer,
        rules: [DSMReverseProxyRule],
        baseURL: URL
    ) -> URL? {
        let mappings = container.ports.compactMap(portMapping(from:))
        let hostPorts = Set(mappings.map(\.hostPort))

        // An exact published destination port is the only reliable proof that a
        // reverse-proxy rule belongs to this container.
        guard let rule = rules
            .filter({ hostPorts.contains($0.destinationPort) })
            .sorted(by: { $0.sourcePort < $1.sourcePort })
            .first
        else { return nil }
        let configuredHost = rule.sourceHost?.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = configuredHost == nil || configuredHost == "*" ? baseURL.host : configuredHost
        guard let host, !host.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = rule.sourceScheme
        components.host = host
        components.port = rule.sourcePort
        if let sourcePath = rule.sourcePath {
            components.path = sourcePath.hasPrefix("/") ? sourcePath : "/\(sourcePath)"
        }
        return components.url
    }

    private static func originURL(for url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private static func compactServiceIdentifier(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private static func unverifiedFallbackEndpoint(
        for container: DockerContainer,
        candidates: [URL]
    ) -> URL? {
        let name = container.name.lowercased()
        guard !name.contains("jellyfin"), !name.contains("emby") else { return nil }
        return isLikelyWebContainer(container) ? candidates.first : nil
    }

    private func firstReachableWebEndpoint(
        _ candidates: [URL],
        serviceName: String? = nil
    ) async -> URL? {
        if serviceName?.lowercased().contains("jellyfin") == true
            || serviceName?.lowercased().contains("emby") == true {
            return await firstReachableJellyfinEndpoint(candidates)
        }
        return await withTaskGroup(
            of: (Int, URL?).self,
            returning: URL?.self
        ) { group in
            for (index, endpoint) in candidates.prefix(8).enumerated() {
                group.addTask {
                    let resolvedEndpoint = await self.reachableWebEndpoint(endpoint)
                    return (index, resolvedEndpoint)
                }
            }

            var reachable: [(Int, URL)] = []
            for await (index, endpoint) in group {
                if let endpoint {
                    reachable.append((index, endpoint))
                }
            }
            return reachable.min { $0.0 < $1.0 }?.1
        }
    }

    private func firstReachableJellyfinEndpoint(_ candidates: [URL]) async -> URL? {
        var bases: [URL] = []
        var seen = Set<String>()
        for candidate in candidates.prefix(8) {
            let existingPath = candidate.path == "/" ? "" : candidate.path
            for path in [existingPath, "/jellyfin", "/emby"] {
                guard var components = URLComponents(url: candidate, resolvingAgainstBaseURL: false) else {
                    continue
                }
                components.path = path
                components.query = nil
                components.fragment = nil
                guard let base = components.url, seen.insert(base.absoluteString).inserted else {
                    continue
                }
                bases.append(base)
            }
        }

        return await withTaskGroup(of: (Int, URL?).self, returning: URL?.self) { group in
            for (index, base) in bases.enumerated() {
                group.addTask {
                    guard let probeURL = DSMURLBuilder.url(
                        baseURL: base,
                        appending: "/System/Info/Public"
                    ) else {
                        return (index, nil)
                    }
                    var request = URLRequest(url: probeURL)
                    request.timeoutInterval = 3
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    do {
                        let (_, response) = try await self.urlSession.data(for: request)
                        guard
                            let response = response as? HTTPURLResponse,
                            (200..<300).contains(response.statusCode)
                        else {
                            return (index, nil)
                        }
                        return (index, base)
                    } catch {
                        return (index, nil)
                    }
                }
            }

            var reachable: [(Int, URL)] = []
            for await result in group {
                if let endpoint = result.1 {
                    reachable.append((result.0, endpoint))
                }
            }
            return reachable.min { $0.0 < $1.0 }?.1
        }
    }

    private func reachableWebEndpoint(_ endpoint: URL) async -> URL? {
        for method in ["HEAD", "GET"] {
            var request = URLRequest(url: endpoint)
            request.httpMethod = method
            request.timeoutInterval = method == "HEAD" ? 1.5 : 2.5
            request.cachePolicy = .reloadIgnoringLocalCacheData
            if method == "GET" {
                request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
            }
            do {
                let (_, response) = try await urlSession.data(for: request)
                if let response = response as? HTTPURLResponse,
                   (200..<400).contains(response.statusCode)
                    || response.statusCode == 401
                    || response.statusCode == 403 {
                    return response.url ?? endpoint
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private static func isInstalledPackage(_ item: DSMJSONValue) -> Bool {
        if let explicit = item.firstDirectBool(for: ["installed", "is_installed", "isInstalled", "is_install"]) {
            return explicit
        }

        let raw = (directTextValue(
            in: item,
            keys: ["status", "state", "status_text", "display_status", "pkgStatus", "install_status", "package_status"]
        ) ?? "").lowercased()

        if raw.contains("not") && raw.contains("install") { return false }
        if raw.contains("uninstall") || raw.contains("available") || raw.contains("installable") || raw == "none" { return false }
        if raw.contains("running") || raw.contains("stopped") || raw.contains("started") || raw.contains("enabled") || raw.contains("disabled") || raw == "installed" {
            return true
        }

        if nonEmptyString(item.firstDirectString(for: [
            "install_version", "installed_version", "installedVersion", "version", "pkg_version"
        ])) != nil {
            return true
        }
        if item.firstDirectBool(for: ["start", "running", "is_running", "started", "enabled", "is_enable"]) != nil {
            return true
        }
        return false
    }

    private static func packageEndpoint(for item: DSMJSONValue, baseURL: URL) -> URL? {
        guard let text = directTextValue(
            in: item,
            keys: ["url", "URL", "uri", "launch_url", "launchUrl", "web_url", "webUrl", "webui", "homepage", "dsm_url"]
        ) else {
            return nil
        }
        if let absolute = URL(string: text), absolute.scheme != nil {
            return absolute
        }
        return DSMURLBuilder.url(baseURL: baseURL, appending: text)
    }

    private static func packageStatus(_ item: DSMJSONValue) -> ServiceStatus {
        let runningKeys = [
            "start", "running", "is_running", "isRunning", "started",
            "enabled", "run", "is_enable", "run_status", "runStatus"
        ]
        if let isRunning = item.firstDirectBool(for: runningKeys) ?? item.firstBool(for: runningKeys) {
            return isRunning ? .online : .offline
        }
        let statusText = directTextValue(
            in: item,
            keys: [
                "status", "state", "status_text", "display_status", "pkgStatus",
                "package_status", "service_status", "run_status", "runStatus"
            ]
        ) ?? textValue(
            in: item,
            keys: [
                "status", "state", "status_text", "display_status", "pkgStatus",
                "package_status", "service_status", "run_status", "runStatus"
            ]
        ) ?? ""
        let status = serviceStatus(from: statusText)
        if status != .unknown { return status }
        return isInstalledPackage(item) ? .installed : .unknown
    }

    private static func shouldShowPackageService(_ name: String) -> Bool {
        shouldAutomaticallyAddPackageService(name)
    }

    private static func shouldAutomaticallyAddPackageService(_ name: String) -> Bool {
        let compact = compactServiceIdentifier(name)
        // Default to direct, user-facing workflows and service-management entry points.
        // Other discovered packages remain available in launchpad service management.
        let launchpadPackageTokens = [
            "container",
            "docker",
            "filestation",
            "downloadstation",
            "synologyphotos",
            "photostation",
            "videostation",
            "audiostation",
            "synologydrive",
            "cloudstation",
            "surveillancestation",
            "virtualmachinemanager"
        ]
        return launchpadPackageTokens.contains { compact.contains($0) }
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
        let portKeys = [
            "ports", "Ports", "port_bindings", "PortBindings", "portBindings",
            "port_mappings", "portMappings", "PortMapping"
        ]
        let ports = allObjects(in: item).flatMap { object in
            portKeys.flatMap { key -> [String] in
                guard let value = object.firstDirectValue(for: [key]) else { return [] }
                return publishedPortTexts(from: value)
            }
        }
        return uniqueStrings(ports)
    }

    private static func publishedPortTexts(from value: DSMJSONValue) -> [String] {
        if let array = value.arrayValue {
            return array.flatMap { publishedPortTexts(from: $0) }
        }

        if let mapping = directPublishedPort(from: value, inheritedContainerPort: nil) {
            return [mapping]
        }

        guard let object = value.objectValue else { return [] }
        return object.flatMap { key, child -> [String] in
            guard let containerPort = portNumberPrefix(from: key) else { return [] }
            let bindings = child.arrayValue ?? [child]
            return bindings.compactMap {
                directPublishedPort(from: $0, inheritedContainerPort: containerPort)
            }
        }
    }

    private static func directPublishedPort(
        from value: DSMJSONValue,
        inheritedContainerPort: Int?
    ) -> String? {
        guard value.objectValue != nil else { return nil }
        let hostPort = numericPort(directTextValue(
            in: value,
            keys: [
                "host_port", "hostPort", "HostPort",
                "local_port", "localPort", "public_port", "publicPort", "PublicPort",
                "host", "local", "public", "external", "external_port", "externalPort"
            ]
        ))
        let containerPort = numericPort(directTextValue(
            in: value,
            keys: [
                "container_port", "containerPort", "ContainerPort",
                "private_port", "privatePort", "PrivatePort",
                "target_port", "targetPort",
                "container", "private", "target", "internal", "port"
            ]
        )) ?? inheritedContainerPort
        guard let hostPort, let containerPort else { return nil }
        let transport = transportName(directTextValue(in: value, keys: ["protocol", "Protocol", "type"]))
        return "\(hostPort) -> \(containerPort)/\(transport)"
    }

    private static func numericPort(_ text: String?) -> Int? {
        guard
            let text,
            !text.isEmpty,
            text.allSatisfy(\.isNumber),
            let port = Int(text),
            (1...65_535).contains(port)
        else {
            return nil
        }
        return port
    }

    private static func transportName(_ raw: String?) -> String {
        switch raw?.lowercased() {
        case "17", "udp": return "udp"
        default: return "tcp"
        }
    }

    private static func portNumberPrefix(from key: String) -> Int? {
        guard let prefix = key.split(separator: "/").first else { return nil }
        return numericPort(String(prefix))
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
        if normalized.contains("running")
            || normalized.contains("healthy")
            || ["up", "online", "start", "started", "run", "active"].contains(normalized) {
            return .online
        }
        if normalized.contains("stop")
            || normalized.contains("exit")
            || ["down", "offline", "dead", "inactive"].contains(normalized) {
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

    private static func directTextValue(in item: DSMJSONValue, keys: [String]) -> String? {
        guard let value = item.firstDirectValue(for: keys) else { return nil }
        let text = value.stringValue ?? value.arrayValue?.compactMap(\.stringValue).first
        let normalized = text?
            .trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        return normalized?.isEmpty == false ? normalized : nil
    }

    private static func displayName(for rawName: String) -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = name.lowercased()
        let compact = compactServiceIdentifier(name)
        if ["container", "container manager", "docker"].contains(lower) { return "Container Manager" }
        if lower.contains("file station") { return "File Station" }
        if lower.contains("synology photos") || compact.contains("synologyphotos") { return "Synology Photos" }
        if lower.contains("download station") { return "Download Station" }
        if lower.contains("synology drive") || compact.contains("synologydrive")
            || compact.contains("cloudstationserver") {
            return "Synology Drive"
        }
        if lower.contains("video station") { return "Video Station" }
        if lower.contains("audio station") { return "Audio Station" }
        if lower.contains("jellyfin") { return "Jellyfin" }
        if lower.contains("emby") { return "Emby" }
        if lower.contains("plex") { return "Plex" }
        if lower.contains("navidrome") { return "Navidrome" }
        if lower.contains("qbittorrent") { return "qBittorrent" }
        if compact.contains("homeassistant") { return "Home Assistant" }
        if compact.contains("codeserver") { return "code-server" }
        if compact.contains("codexserver") { return "codex-server" }
        if compact.contains("tinymediamanager") { return "tinyMediaManager" }
        if compact.contains("metacubexd") { return "MetaCubeXD" }
        return name.isEmpty ? "Service" : name
    }

    private static func iconText(for name: String) -> String {
        let lower = name.lowercased()
        let compact = compactServiceIdentifier(name)
        if lower.contains("jellyfin") { return "JF" }
        if lower.contains("navidrome") { return "NV" }
        if lower.contains("qbittorrent") { return "QB" }
        if compact.contains("homeassistant") { return "HA" }
        if compact.contains("codeserver") || compact.contains("codexserver") { return "</>" }
        if compact.contains("tinymediamanager") { return "TM" }
        if compact.contains("metacubexd") { return "MX" }
        if ["container", "container manager", "docker"].contains(lower) { return "CT" }
        if lower.contains("file station") { return "FS" }
        if lower.contains("download station") { return "DL" }
        if lower.contains("synology photos") || compact.contains("synologyphotos") { return "PH" }
        if lower.contains("synology drive") || compact.contains("synologydrive")
            || compact.contains("cloudstationserver") {
            return "DR"
        }
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
        let compact = compactServiceIdentifier(name)
        if lower.contains("dsm") || lower.contains("homepage") { return .favorites }
        if lower.contains("jellyfin") || lower.contains("emby") || lower.contains("plex") || lower.contains("navidrome") { return .media }
        if lower.contains("photos") || compact.contains("synologyphotos")
            || lower.contains("video station") || lower.contains("audio station") {
            return .media
        }
        if lower.contains("torrent") || lower.contains("transmission") || lower.contains("aria") { return .downloads }
        if lower.contains("download station") { return .downloads }
        if lower.contains("nginx") || lower.contains("adguard") || lower.contains("tailscale")
            || lower.contains("mihomo") || lower.contains("metacube") || lower.contains("clash") {
            return .network
        }
        if lower.contains("webdav") || lower.contains("vpn") { return .network }
        if compact.contains("codeserver") || compact.contains("codexserver")
            || compact.contains("tinymediamanager") || compact.contains("homeassistant") {
            return .tools
        }
        if lower.contains("container") || lower.contains("docker") || lower.contains("file station")
            || lower.contains("drive") || compact.contains("synologydrive")
            || compact.contains("cloudstationserver") {
            return .favorites
        }
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

    private static func endpointCandidates(
        for container: DockerContainer,
        baseURL: URL,
        lanHosts: [String]
    ) -> [URL] {
        let hosts = uniqueStrings(lanHosts + [baseURL.host].compactMap { $0 })
        guard !hosts.isEmpty else { return [] }
        let preferredContainerPorts = preferredWebPorts(for: container.name)
        var sortedMappings = container.ports.compactMap(portMapping(from:)).filter { $0.transport == "tcp" }
            .sorted { lhs, rhs in
                let lhsRank = preferredContainerPorts.firstIndex(of: lhs.containerPort) ?? Int.max
                let rhsRank = preferredContainerPorts.firstIndex(of: rhs.containerPort) ?? Int.max
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                let lhsWebRank = isLikelyWebPort(lhs.containerPort) ? 0 : 1
                let rhsWebRank = isLikelyWebPort(rhs.containerPort) ? 0 : 1
                if lhsWebRank != rhsWebRank { return lhsWebRank < rhsWebRank }
                return lhs.hostPort < rhs.hostPort
            }
        if sortedMappings.isEmpty {
            sortedMappings = knownWebPorts(for: container.name).map {
                (hostPort: $0, containerPort: $0, transport: "tcp")
            }
        }
        let mappings = Array(sortedMappings.prefix(6))

        var seen = Set<String>()
        return mappings.flatMap { mapping in
            hosts.flatMap { host in
                preferredSchemes(for: mapping.containerPort, serviceName: container.name).compactMap { scheme -> URL? in
                    var components = URLComponents()
                    components.scheme = scheme
                    components.host = host
                    components.port = mapping.hostPort
                    guard let url = components.url, seen.insert(url.absoluteString).inserted else { return nil }
                    return url
                }
            }
        }
    }

    private static func preferredWebPorts(for name: String) -> [Int] {
        knownWebPorts(for: name) + [443, 8443, 9443, 80, 8080, 8000, 5000, 3000]
    }

    private static func knownWebPorts(for name: String) -> [Int] {
        let normalized = name.lowercased()
        let compact = compactServiceIdentifier(name)
        if normalized.contains("homepage") { return [3000, 3001] }
        if normalized.contains("jellyfin") || normalized.contains("emby") { return [8096, 8920] }
        if normalized.contains("plex") { return [32400] }
        if normalized.contains("navidrome") { return [4533] }
        if normalized.contains("qbittorrent") { return [8080] }
        if compact.contains("homeassistant") { return [8123] }
        if normalized.contains("portainer") { return [9443, 9000] }
        if compact.contains("codeserver") || compact.contains("codexserver") {
            return [8443, 8080, 8000]
        }
        if compact.contains("tinymediamanager") {
            return [5800, 4000]
        }
        if compact.contains("metacubexd") {
            return [80, 8080]
        }
        if normalized.contains("mihomo") || normalized.contains("clash") {
            return [9090]
        }
        return []
    }

    private static func isLikelyWebContainer(_ container: DockerContainer) -> Bool {
        if !knownWebPorts(for: container.name).isEmpty {
            return true
        }
        return container.ports
            .compactMap(portMapping(from:))
            .contains { $0.transport == "tcp" && isLikelyWebPort($0.containerPort) }
    }

    private static func isLikelyWebPort(_ port: Int) -> Bool {
        let commonPorts: Set<Int> = [
            80, 443, 3000, 3001, 4000, 5000, 5001, 5800,
            8000, 8001, 8080, 8081, 8090, 8096, 8123,
            8443, 8920, 9000, 9090, 9443
        ]
        if commonPorts.contains(port) {
            return true
        }
        let nonWebPorts: Set<Int> = [
            20, 21, 22, 23, 25, 53, 67, 68, 110, 123, 137, 138, 139,
            143, 389, 445, 465, 514, 587, 636, 873, 993, 995, 1883,
            3306, 5432, 6379, 6881, 27017
        ]
        return port >= 1024 && !nonWebPorts.contains(port)
    }

    private static func preferredSchemes(for port: Int, serviceName: String) -> [String] {
        let compactName = compactServiceIdentifier(serviceName)
        if compactName.contains("codeserver") || compactName.contains("codexserver") {
            return ["http", "https"]
        }
        let tlsPorts: Set<Int> = [443, 4443, 5001, 5443, 7443, 8443, 8920, 9443]
        return tlsPorts.contains(port) ? ["https", "http"] : ["http", "https"]
    }

    private static func portMapping(from text: String) -> (hostPort: Int, containerPort: Int, transport: String)? {
        let compact = text.replacingOccurrences(of: " ", with: "")
        let parts = compact.components(separatedBy: "->")
        guard
            parts.count == 2,
            let hostPort = numericPort(parts[0])
        else {
            return nil
        }
        let target = parts[1].split(separator: "/", maxSplits: 1).map(String.init)
        guard let containerPort = numericPort(target.first) else { return nil }
        let transport = target.count > 1 ? transportName(target[1]) : "tcp"
        return (hostPort, containerPort, transport)
    }
}

final class LANDiscoveryService: NSObject, ObservableObject {
    @Published private(set) var devices: [DiscoveredNASDevice] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorKey: String?

    private let serviceTypes = ["_https._tcp.", "_http._tcp.", "_smb._tcp."]
    private var browsers: [NetServiceBrowser] = []
    private var resolvingServices: [ObjectIdentifier: NetService] = [:]
    private var probedURLs = Set<String>()
    private var searchGeneration = UUID()
    private var subnetScanTask: Task<Void, Never>?
    private var hadBrowserFailure = false
    private let discoverySessionDelegate = DSMCertificateTrustDelegate()
    private lazy var discoverySession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.2
        configuration.timeoutIntervalForResource = 2
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(
            configuration: configuration,
            delegate: discoverySessionDelegate,
            delegateQueue: nil
        )
    }()

    func start() {
        stop()
        devices = []
        errorKey = nil
        probedURLs.removeAll()
        isSearching = true
        hadBrowserFailure = false
        searchGeneration = UUID()
        let generation = searchGeneration
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.discovery.started"
        )

        for type in serviceTypes {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browsers.append(browser)
            browser.searchForServices(ofType: type, inDomain: "local.")
        }

        subnetScanTask = Task { [weak self] in
            await self?.scanLocalSubnets(generation: generation)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self, self.searchGeneration == generation else { return }
            self.finish()
        }
    }

    func stop() {
        browsers.forEach { $0.stop() }
        resolvingServices.values.forEach { $0.stop() }
        subnetScanTask?.cancel()
        subnetScanTask = nil
        browsers.removeAll()
        resolvingServices.removeAll()
        isSearching = false
        searchGeneration = UUID()
    }

    private func finish() {
        guard isSearching else { return }
        browsers.forEach { $0.stop() }
        browsers.removeAll()
        subnetScanTask?.cancel()
        subnetScanTask = nil
        isSearching = false
        if devices.isEmpty, hadBrowserFailure {
            errorKey = "connect.scan.permission"
        }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.discovery.completed",
            details: ["count": "\(devices.count)"]
        )
    }

    private func probe(service: NetService) {
        guard let hostName = service.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")) else {
            return
        }
        let candidates: [URL]
        switch service.type {
        case "_https._tcp.":
            candidates = Self.serviceCandidates(scheme: "https", host: hostName, port: service.port)
        case "_http._tcp.":
            candidates = Self.serviceCandidates(scheme: "http", host: hostName, port: service.port)
        case "_smb._tcp.":
            candidates = Self.defaultDSMCandidates(host: hostName)
        default:
            return
        }
        let unprobedCandidates = candidates.filter { probedURLs.insert($0.absoluteString).inserted }
        guard !unprobedCandidates.isEmpty else { return }

        let displayName = service.name
        let generation = searchGeneration
        Task {
            guard let url = await preferredDSMURL(from: unprobedCandidates) else { return }
            await MainActor.run {
                guard self.searchGeneration == generation else { return }
                self.addDevice(name: displayName, url: url)
            }
        }
    }

    private func scanLocalSubnets(generation: UUID) async {
        let candidates = Self.localIPv4Prefixes().flatMap { prefix in
            (1...254).map { host in "\(prefix).\(host)" }
        }

        guard !candidates.isEmpty else { return }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.discovery.subnet_started",
            details: [
                "hosts": "\(candidates.count)",
                "protocolCandidates": "\(candidates.count * 2)"
            ]
        )

        let batchSize = 32
        for startIndex in stride(from: 0, to: candidates.count, by: batchSize) {
            guard !Task.isCancelled else { return }
            let endIndex = min(startIndex + batchSize, candidates.count)
            let batch = Array(candidates[startIndex..<endIndex])
            let found = await withTaskGroup(of: URL?.self, returning: [URL].self) { group in
                for host in batch {
                    group.addTask {
                        guard !Task.isCancelled else { return nil }
                        return await self.preferredDSMURL(
                            from: Self.defaultDSMCandidates(host: host)
                        )
                    }
                }
                var results: [URL] = []
                for await result in group {
                    if let result {
                        results.append(result)
                    }
                }
                return results
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.searchGeneration == generation else { return }
                for url in found {
                    let name = url.host.map { "DSM \($0)" } ?? "DSM"
                    self.addDevice(name: name, url: url)
                }
            }
        }
    }

    private func resolvedDSMBaseURL(at baseURL: URL) async -> URL? {
        guard
            let probeURL = DSMURLBuilder.url(baseURL: baseURL, appending: "/webapi/query.cgi"),
            var components = URLComponents(url: probeURL, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "api", value: "SYNO.API.Info"),
            URLQueryItem(name: "version", value: "1"),
            URLQueryItem(name: "method", value: "query"),
            URLQueryItem(name: "query", value: "SYNO.API.Auth,SYNO.Core.System")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.2
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await discoverySession.data(for: request)
            guard
                let response = response as? HTTPURLResponse,
                (200..<300).contains(response.statusCode),
                let envelope = try? JSONDecoder().decode(DSMAPIEnvelope.self, from: data),
                envelope.success,
                envelope.data?.objectValue?["SYNO.API.Auth"] != nil
            else {
                return nil
            }
            guard var resolvedComponents = URLComponents(
                url: response.url ?? baseURL,
                resolvingAgainstBaseURL: false
            ) else {
                return baseURL
            }
            let probeSuffix = "/webapi/query.cgi"
            if resolvedComponents.path.hasSuffix(probeSuffix) {
                resolvedComponents.path = String(resolvedComponents.path.dropLast(probeSuffix.count))
            } else {
                resolvedComponents.path = baseURL.path
            }
            resolvedComponents.query = nil
            resolvedComponents.fragment = nil
            return resolvedComponents.url ?? baseURL
        } catch {
            return nil
        }
    }

    private func preferredDSMURL(from candidates: [URL]) async -> URL? {
        await withTaskGroup(of: (Int, URL?).self, returning: URL?.self) { group in
            for (index, candidate) in candidates.enumerated() {
                group.addTask {
                    let resolvedURL = await self.resolvedDSMBaseURL(at: candidate)
                    return (index, resolvedURL)
                }
            }

            var matches: [(Int, URL)] = []
            for await (index, candidate) in group {
                if let candidate {
                    matches.append((index, candidate))
                }
            }
            return matches.min { $0.0 < $1.0 }?.1
        }
    }

    private static func defaultDSMCandidates(host: String) -> [URL] {
        serviceCandidates(scheme: "https", host: host, port: 5001)
            + serviceCandidates(scheme: "http", host: host, port: 5000)
    }

    private static func serviceCandidates(scheme: String, host: String, port: Int) -> [URL] {
        guard (1...65_535).contains(port) else { return [] }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        return components.url.map { [$0] } ?? []
    }

    private func addDevice(name: String, url: URL) {
        if let index = devices.firstIndex(where: {
            URL(string: $0.host)?.host?.caseInsensitiveCompare(url.host ?? "") == .orderedSame
        }) {
            guard
                let existingURL = URL(string: devices[index].host),
                protocolRank(url) < protocolRank(existingURL)
            else { return }
            devices[index] = DiscoveredNASDevice(
                id: devices[index].id,
                name: devices[index].name,
                host: url.absoluteString
            )
            recordDiscoveredDevice(url)
            return
        }
        devices.append(
            DiscoveredNASDevice(
                id: UUID(),
                name: name,
                host: url.absoluteString
            )
        )
        devices.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        recordDiscoveredDevice(url)
    }

    private func protocolRank(_ url: URL) -> Int {
        url.scheme?.lowercased() == "https" ? 0 : 1
    }

    private func recordDiscoveredDevice(_ url: URL) {
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.discovery.found",
            details: [
                "target": DiagnosticLogStore.redactedURL(url),
                "protocol": url.scheme?.uppercased() ?? "-"
            ]
        )
    }

    private static func localIPv4Prefixes() -> [String] {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let firstAddress = addresses else { return [] }
        defer { freeifaddrs(addresses) }

        var prefixes = Set<String>()
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard
                let socketAddress = current.pointee.ifa_addr,
                socketAddress.pointee.sa_family == UInt8(AF_INET),
                current.pointee.ifa_flags & UInt32(IFF_UP) != 0,
                current.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0
            else {
                continue
            }
            let interfaceName = String(cString: current.pointee.ifa_name)
            guard interfaceName.hasPrefix("en") else { continue }

            var address = UnsafeRawPointer(socketAddress)
                .assumingMemoryBound(to: sockaddr_in.self)
                .pointee
                .sin_addr
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
                continue
            }

            let octets = String(cString: buffer).split(separator: ".").compactMap { Int($0) }
            guard octets.count == 4, isPrivateIPv4(octets) else { continue }
            prefixes.insert("\(octets[0]).\(octets[1]).\(octets[2])")
        }
        return prefixes.sorted()
    }

    private static func isPrivateIPv4(_ octets: [Int]) -> Bool {
        octets[0] == 10
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 192 && octets[1] == 168)
    }
}

extension LANDiscoveryService: NetServiceBrowserDelegate {
    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        let identifier = ObjectIdentifier(service)
        resolvingServices[identifier] = service
        service.delegate = self
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        guard browsers.contains(where: { $0 === browser }) else { return }
        browser.stop()
        browsers.removeAll { $0 === browser }
        hadBrowserFailure = true
        let values = errorDict.values.map(\.intValue)
        let code = values.first(where: { $0 < 0 }) ?? values.first ?? 0
        let domain = values.first(where: { $0 >= 0 }) ?? 0
        DiagnosticLogStore.shared.record(
            .warning,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.discovery.failed",
            details: [
                "code": "\(code)",
                "domain": "\(domain)"
            ]
        )
    }
}

extension LANDiscoveryService: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        resolvingServices.removeValue(forKey: ObjectIdentifier(sender))
        probe(service: sender)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        resolvingServices.removeValue(forKey: ObjectIdentifier(sender))
    }
}

private struct PersistedTaskState: Codable {
    let pending: [TaskItem]
    let history: [TaskItem]
}

private enum ReminderNotificationScheduler {
    private static func identifier(for task: TaskItem) -> String {
        "nastart.reminder.\(task.id.uuidString.lowercased())"
    }

    static func schedule(_ task: TaskItem, requestsAuthorization: Bool) {
        let center = UNUserNotificationCenter.current()
        let identifier = identifier(for: task)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard !task.isMuted, let reminderDate = task.nextReminderAt, reminderDate > Date() else {
            return
        }

        Task {
            let settings = await center.notificationSettings()
            var isAuthorized = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            if settings.authorizationStatus == .notDetermined, requestsAuthorization {
                isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true
            }
            guard isAuthorized else { return }

            let content = UNMutableNotificationContent()
            content.title = task.title
            content.body = task.subtitle
            content.sound = .default
            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func cancel(_ task: TaskItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier(for: task)]
        )
    }
}

private final class LocalTaskStore {
    private let storageKey = "tasks.localState.v1"

    func load() -> PersistedTaskState? {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let state = try? JSONDecoder().decode(PersistedTaskState.self, from: data)
        else {
            return nil
        }
        return state
    }

    func save(pending: [TaskItem], history: [TaskItem]) {
        guard let data = try? JSONEncoder().encode(PersistedTaskState(pending: pending, history: history)) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

final class AppDataStore: ObservableObject {
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
    @Published private(set) var isDSMReachable = false
    @Published private(set) var lastRefreshSummaryKey = "data.refresh.ready"
    @Published private(set) var sourceKind: NASDataSourceKind
    @Published private(set) var serviceVisibilityOverrides: [String: Bool]

    private var provider: AppDataProviding
    private var activeDataSource: NASDataSource
    private var manualServiceStore = ManualLaunchpadServiceStore()
    private let launchpadVisibilityStore = LaunchpadVisibilityStore()
    private let localTaskStore: LocalTaskStore
    private var preservedContainerInventoryOnLastMerge = false

    init(provider: AppDataProviding = DisconnectedAppDataProvider()) {
        let taskStore = LocalTaskStore()
        let persistedTasks = taskStore.load()
        self.provider = provider
        localTaskStore = taskStore
        serviceVisibilityOverrides = LaunchpadVisibilityStore().load()
        sourceKind = provider is DSMDataSnapshot ? .dsm : .mock
        activeDataSource = DisconnectedNASDataSource()
        device = provider.device
        services = provider.services + manualServiceStore.load()
        containers = provider.containers
        files = provider.files
        tasks = persistedTasks?.pending ?? provider.tasks
        completedTasks = persistedTasks?.history ?? []
        videoLibraryItems = provider.videoLibraryItems
        audioLibraryItems = provider.audioLibraryItems
        discoveredDevices = provider.discoveredDevices
        tasks.forEach {
            ReminderNotificationScheduler.schedule($0, requestsAuthorization: false)
        }
    }

    @MainActor
    func reload(from provider: AppDataProviding) {
        let previousServices = services
        let previousContainers = containers
        self.provider = provider
        sourceKind = provider is DSMDataSnapshot ? .dsm : .mock
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
        guard !isRefreshing else { return }
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
        isDSMReachable = false
    }

    @MainActor
    func clearConnectionData() {
        activeDataSource = DisconnectedNASDataSource()
        reload(from: DisconnectedAppDataProvider())
        sourceKind = .mock
        isDSMReachable = false
        lastRefreshSummaryKey = "data.refresh.disconnected"
    }

    @MainActor
    @discardableResult
    func refreshDSM(session: DSMSession, useAgent: Bool) async -> Bool {
        guard !isRefreshing else { return isDSMReachable }
        isRefreshing = true
        defer { isRefreshing = false }

        let dataSource = DSMNASDataSource(session: session, useAgent: useAgent)
        activeDataSource = dataSource
        guard await dataSource.isReachable() else {
            markDSMUnavailable()
            return false
        }

        let snapshot = await dataSource.loadSnapshot()
        reload(from: snapshot)
        sourceKind = dataSource.kind
        isDSMReachable = true
        return true
    }

    @MainActor
    func activateDSM(snapshot: DSMDataSnapshot, session: DSMSession, useAgent _: Bool) {
        activeDataSource = DSMNASDataSource(session: session, useAgent: false)
        reload(from: snapshot)
        sourceKind = .dsm
        isDSMReachable = true
    }

    @MainActor
    func loadFolder(path: String) async throws -> [FileItem] {
        if let dataSource = activeDataSource as? DSMNASDataSource {
            do {
                return try await dataSource.loadFolder(path: path)
            } catch {
                DiagnosticLogStore.shared.record(
                    .warning,
                    categoryKey: "diagnostics.category.dsm_api",
                    messageKey: "diagnostics.files.folder_failed",
                    details: [
                        "pathDepth": "\(path.split(separator: "/").count)",
                        "error": "\(error)"
                    ]
                )
                let localItems = localChildren(for: path, in: files)
                if !localItems.isEmpty { return localItems }
                throw error
            }
        }
        return localChildren(for: path, in: files)
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
        guard let credential = KeychainStore.shared.loadNASCredential() else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        var sessionToLogout: DSMSession?

        do {
            let baseURL = try DSMClient.normalizedBaseURL(from: credential.baseURLString)
            let client = DSMClient(
                baseURL: baseURL,
                allowsSelfSignedCertificates: credential.allowsSelfSignedCertificates
            )
            let session = try await client.login(
                account: credential.account,
                password: credential.password,
                deviceID: credential.deviceID
            )
            sessionToLogout = session
            let dataSource = DSMNASDataSource(session: session, useAgent: false)
            let snapshot = await dataSource.loadSnapshot()
            try KeychainStore.shared.saveNASCredential(
                StoredNASCredential(
                    baseURLString: credential.baseURLString,
                    account: credential.account,
                    password: credential.password,
                    useAgent: false,
                    allowsSelfSignedCertificates: credential.allowsSelfSignedCertificates,
                    deviceID: session.deviceID ?? credential.deviceID
                )
            )
            activeDataSource = dataSource
            reload(from: snapshot)
            sourceKind = dataSource.kind
            isDSMReachable = true
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
        }
    }

    @MainActor
    private func markDSMUnavailable() {
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
            details: ["target": "privateDSM"]
        )
    }

    private static func isPrivateNetworkHost(_ host: String?) -> Bool {
        NetworkHostClassifier.isPrivate(host)
    }

    func services(in category: ServiceCategory) -> [LaunchpadService] {
        services.filter { $0.category == category }
    }

    func isServiceVisibleOnLaunchpad(_ service: LaunchpadService) -> Bool {
        serviceVisibilityOverrides[service.launchpadVisibilityKey] ?? service.isLaunchpadVisible
    }

    @MainActor
    func setService(_ service: LaunchpadService, visibleOnLaunchpad isVisible: Bool) {
        if isVisible == service.isLaunchpadVisible {
            serviceVisibilityOverrides.removeValue(forKey: service.launchpadVisibilityKey)
        } else {
            serviceVisibilityOverrides[service.launchpadVisibilityKey] = isVisible
        }
        launchpadVisibilityStore.save(serviceVisibilityOverrides)
        lastRefreshSummaryKey = isVisible ? "launchpad.service.shown" : "launchpad.service.hidden"
    }

    @MainActor
    func resetLaunchpadServiceVisibility() {
        serviceVisibilityOverrides.removeAll()
        launchpadVisibilityStore.save(serviceVisibilityOverrides)
        lastRefreshSummaryKey = "launchpad.services.reset_done"
    }

    @MainActor
    func addManualService(name: String, endpoint: URL, category: ServiceCategory, iconText: String) {
        let service = manualServiceStore.add(
            name: name,
            endpoint: endpoint,
            category: category,
            iconText: iconText
        )
        services.append(service)
        lastRefreshSummaryKey = "manual.service.added"
    }

    @MainActor
    func deleteManualService(id: UUID) {
        manualServiceStore.delete(id: id)
        services.removeAll { $0.id == id && $0.source == .manual }
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

private struct LaunchpadVisibilityStore {
    private let storageKey = "nastart.launchpadServiceVisibility.v1"

    func load() -> [String: Bool] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    func save(_ overrides: [String: Bool]) {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

private struct StoredManualLaunchpadService: Codable, Identifiable {
    let id: UUID
    let name: String
    let endpointString: String
    let categoryRawValue: String
    let iconText: String
    let createdAt: Date

    var launchpadService: LaunchpadService? {
        guard
            let endpoint = URL(string: endpointString),
            UserConfiguredServiceURLPolicy.allows(endpoint),
            let category = ServiceCategory(rawValue: categoryRawValue)
        else {
            return nil
        }
        return LaunchpadService(
            id: id,
            name: name,
            iconText: iconText,
            category: category,
            status: .online,
            subtitle: endpoint.host ?? endpoint.absoluteString,
            detail: "manual.service.detail",
            isMedia: category == .media,
            cpu: nil,
            memoryText: nil,
            ports: endpoint.port.map { ["\($0)"] } ?? [],
            endpoint: endpoint,
            source: .manual
        )
    }
}

private struct ManualLaunchpadServiceStore {
    private let storageKey = "nastart.manualLaunchpadServices.v1"

    func load() -> [LaunchpadService] {
        loadStoredServices().compactMap(\.launchpadService)
    }

    func add(name: String, endpoint: URL, category: ServiceCategory, iconText: String) -> LaunchpadService {
        let stored = StoredManualLaunchpadService(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            endpointString: endpoint.absoluteString,
            categoryRawValue: category.rawValue,
            iconText: Self.normalizedIconText(iconText, fallbackName: name),
            createdAt: Date()
        )
        var services = loadStoredServices()
        services.append(stored)
        save(services)
        return stored.launchpadService ?? LaunchpadService(
            id: stored.id,
            name: stored.name,
            iconText: stored.iconText,
            category: category,
            status: .online,
            subtitle: endpoint.host ?? endpoint.absoluteString,
            detail: "manual.service.detail",
            isMedia: category == .media,
            cpu: nil,
            memoryText: nil,
            endpoint: endpoint,
            source: .manual
        )
    }

    func delete(id: UUID) {
        save(loadStoredServices().filter { $0.id != id })
    }

    private func loadStoredServices() -> [StoredManualLaunchpadService] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([StoredManualLaunchpadService].self, from: data)) ?? []
    }

    private func save(_ services: [StoredManualLaunchpadService]) {
        guard let data = try? JSONEncoder().encode(services) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func normalizedIconText(_ value: String, fallbackName: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return String(trimmed.prefix(3)).uppercased()
        }
        let letters = fallbackName
            .split(separator: " ")
            .compactMap(\.first)
            .map { String($0) }
            .joined()
        if !letters.isEmpty {
            return String(letters.prefix(3)).uppercased()
        }
        return "APP"
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

final class NASConnectionStore: ObservableObject {
    @Published private(set) var connectedDevice: NASDevice?
    @Published private(set) var isConnected: Bool
    @Published private(set) var dsmSession: DSMSession?

    init(device: NASDevice? = nil) {
        connectedDevice = device
        isConnected = device != nil
    }

    var usesAgent: Bool {
        connectedDevice?.mode == .dsmWithAgent || connectedDevice?.mode == .agentOnly
    }

    @MainActor
    func connect(device: NASDevice, session: DSMSession? = nil) {
        connectedDevice = device
        dsmSession = session
        isConnected = true
    }

    @MainActor
    func signOut() async {
        let session = dsmSession
        connectedDevice = nil
        dsmSession = nil
        isConnected = false
        KeychainStore.shared.clearNASCredentials()

        if let session {
            let client = DSMClient(
                baseURL: session.baseURL,
                allowsSelfSignedCertificates: session.allowsSelfSignedCertificates
            )
            await client.logout(session: session)
        }
    }
}

final class EntitlementStore: ObservableObject {
    @Published private(set) var plusStatus: PlusStatus

    init(plusStatus: PlusStatus = .free) {
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

}

enum KeychainStoreError: LocalizedError {
    case encodingFailed
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        NSLocalizedString("keychain.save_failed", comment: "")
    }
}

final class KeychainStore {
    static let shared = KeychainStore()

    private let service = "com.nastart.app.nas"
    private let jellyfinService = "com.nastart.app.jellyfin"
    private let primaryNASAccount = "primary-nas"

    private init() {}

    func saveNASCredential(_ credential: StoredNASCredential) throws {
        guard let data = try? JSONEncoder().encode(credential) else {
            throw KeychainStoreError.encodingFailed
        }
        try save(data: data, query: baseQuery(account: primaryNASAccount))
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
    }

    func saveJellyfinSession(_ session: StoredJellyfinSession, endpoint: URL) throws {
        guard let data = try? JSONEncoder().encode(session) else {
            throw KeychainStoreError.encodingFailed
        }
        try save(data: data, query: jellyfinQuery(endpoint: endpoint))
    }

    func loadJellyfinSession(endpoint: URL) -> StoredJellyfinSession? {
        var query = jellyfinQuery(endpoint: endpoint)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredJellyfinSession.self, from: data)
    }

    func clearJellyfinSession(endpoint: URL) {
        SecItemDelete(jellyfinQuery(endpoint: endpoint) as CFDictionary)
    }

    private func save(data: Data, query: [String: Any]) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }

        var newItem = query
        attributes.forEach { newItem[$0.key] = $0.value }
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(addStatus)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func jellyfinQuery(endpoint: URL) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: jellyfinService,
            kSecAttrAccount as String: endpoint.absoluteString
        ]
    }
}
