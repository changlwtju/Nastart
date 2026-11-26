import Foundation
import CryptoKit
import NetworkMedia

private enum StableIdentifier {
    static func uuid(_ value: String) -> UUID {
        let digest = SHA256.hash(data: Data(value.utf8))
        let hex = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
        let uuidString = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: uuidString) ?? UUID()
    }
}

enum DSMClientError: LocalizedError {
    case invalidAddress
    case insecureHTTP
    case invalidResponse
    case apiFailed(code: Int?)
    /// `SYNO.API.Auth` refused this account or source address. Repeating the
    /// request cannot succeed and can trigger DSM auto block.
    case loginRejected(code: Int)
    case missingSession

    /// Auth codes that a retry cannot fix. 403/404/406 stay `apiFailed`: they ask for a 2FA code.
    static func rejectedLoginError(from error: Error) -> Error {
        guard case DSMClientError.apiFailed(let code?) = error,
              [400, 401, 402, 407, 408, 409, 410, 411].contains(code) else { return error }
        return DSMClientError.loginRejected(code: code)
    }

    /// Only a changed DSM setting can fix these, so retrying with the same credential is still useful.
    var allowsRetryWithSameCredential: Bool {
        guard case .loginRejected(let code) = self else { return true }
        return code == 402 || code == 407
    }

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
        case .loginRejected(let code):
            switch code {
            case 400: return NSLocalizedString("connect.error.login.credentials", comment: "")
            case 401: return NSLocalizedString("connect.error.login.disabled", comment: "")
            case 402: return NSLocalizedString("connect.error.login.denied", comment: "")
            case 407: return NSLocalizedString("connect.error.login.blocked_ip", comment: "")
            case 408, 409, 410: return NSLocalizedString("connect.error.login.password_expired", comment: "")
            default: return NSLocalizedString("connect.error.login.locked", comment: "")
            }
        case .missingSession:
            return NSLocalizedString("connect.error.missing_session", comment: "")
        }
    }
}

enum DSMJSONValue: Decodable {
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

struct DSMAPIEnvelope: Decodable {
    let success: Bool
    let data: DSMJSONValue?
    let error: DSMAPIErrorPayload?
}

struct DSMAPIErrorPayload: Decodable {
    let code: Int?
}

/// Label a folder operation without retaining its path or authentication data.
struct DSMFolderDiagnosticContext {
    enum Origin: String { case snapshot, browserRoot, browserFolder }
    let origin: Origin
    let session: DSMSession
    // Random operation identity only; never derive a token from credentials.
    let operationID = String(UUID().uuidString.prefix(8))

    func fields(attempt: Int) -> [String: String] {
        session.authenticationObservationFields.merging([
            "folderOrigin": origin.rawValue, "folderOperationID": operationID,
            "sessionRole": session.fileStationSID != nil ? "fileStation" : "dsmFallback",
            "requestAuthenticationGeneration": (session.fileStationGeneration ?? session.authenticationGeneration).uuidString,
            "folderAttempt": String(attempt)]) { _, new in new }
    }
}

/// Classify responses without copying URLs, headers or payloads into logs.
/// Keep the API's existing result and error semantics.
enum DSMAPIResponseDecoder {
    static func decode(_ data: Data, response: URLResponse,
                       report: ([String: String]) -> Void) throws -> DSMJSONValue {
        let mime = response.mimeType?.lowercased()
        let contentType: String
        switch mime {
        case "application/json", "text/json": contentType = "json"
        case "text/html": contentType = "html"
        case "text/plain": contentType = "plainText"
        case nil: contentType = "unknown"
        default: contentType = "other"
        }
        var fields = ["bodyBytes": String(data.count), "contentType": contentType]
        guard let http = response as? HTTPURLResponse else {
            fields["responseKind"] = "nonHTTP"
            report(fields)
            throw DSMClientError.invalidResponse
        }
        fields["httpStatus"] = String(http.statusCode)
        guard (200..<300).contains(http.statusCode) else {
            fields["responseKind"] = "httpFailure"
            report(fields)
            throw DSMClientError.invalidResponse
        }
        let envelope: DSMAPIEnvelope
        do {
            envelope = try JSONDecoder().decode(DSMAPIEnvelope.self, from: data)
        } catch {
            fields["responseKind"] = "malformedEnvelope"
            report(fields)
            throw error
        }
        fields["envelopeSuccess"] = String(envelope.success)
        fields["hasData"] = String(envelope.data != nil)
        if let code = envelope.error?.code { fields["apiErrorCode"] = String(code) }
        fields["responseKind"] = envelope.success ? "success" : "apiFailure"
        report(fields)
        guard envelope.success else { throw DSMClientError.apiFailed(code: envelope.error?.code) }
        return envelope.data ?? .object([:])
    }
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

final class DSMCertificateTrustDelegate: NSObject, URLSessionTaskDelegate {
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

struct DSMLoginResult {
    let client: DSMClient
    let session: DSMSession
}

final class DSMClient {
    private static let requestTimeout: TimeInterval = 18
    // Snapshot enrichment is deliberately best-effort. A slow optional DSM
    // package/container endpoint must not keep the login sheet spinning after
    // authentication and shared folders are already available.
    private static let snapshotRequestTimeout: TimeInterval = 8
    private static let packageSnapshotRequestTimeout: TimeInterval = 2.5
    private let baseURL: URL
    private let urlSession: URLSession
    private let allowsSelfSignedCertificates: Bool
    private let sessionDelegate: URLSessionDelegate?
    private let apiInfoCacheLock = NSLock()
    private var cachedFileStationAPIInfo: DSMJSONValue?
    private let diagnosticClientID = String(UUID().uuidString.prefix(8))

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
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
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
        guard
            var components = URLComponents(string: value),
            let host = components.host,
            !host.isEmpty
        else {
            throw DSMClientError.invalidAddress
        }
        guard
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            components.user == nil,
            components.password == nil
        else {
            throw DSMClientError.invalidAddress
        }
        if scheme == "http", !isPrivateNetworkHost(host) {
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

    private enum AuthenticationAPIInfo {
        case query
        case prepared(DSMJSONValue?)
    }

    /// Manual login retains the configured order. Automatic restore can first
    /// race credential-free metadata on those same URLs, without rewriting hosts
    /// or sending concurrent credential POSTs.
    static func login(
        endpoints: DSMConnectionEndpoints,
        allowsSelfSignedCertificates: Bool = false,
        account: String,
        password: String,
        oneTimeCode: String = "",
        deviceID: String? = nil,
        preferredRoute: DSMConnectionRoute? = nil,
        sessionName: String = "Nastart",
        prepareConfiguredEndpoints: Bool = false,
        urlSession: URLSession? = nil
    ) async throws -> DSMLoginResult {
        let candidates = endpoints
            .candidates(preferredRoute: preferredRoute)
            .filter { candidate in
                guard
                    let scheme = candidate.url.scheme?.lowercased(),
                    scheme == "http" || scheme == "https",
                    let host = candidate.url.host,
                    !host.isEmpty,
                    candidate.url.user == nil,
                    candidate.url.password == nil,
                    candidate.url.query == nil,
                    candidate.url.fragment == nil,
                    candidate.url.port.map({ (1...65_535).contains($0) }) ?? true
                else {
                    return false
                }
                return scheme == "https" || isPrivateNetworkHost(host)
            }
        guard !candidates.isEmpty else {
            throw DSMClientError.invalidAddress
        }

        let clients = candidates.map {
            DSMClient(baseURL: $0.url, allowsSelfSignedCertificates: allowsSelfSignedCertificates,
                      urlSession: urlSession)
        }
        var order = Array(candidates.indices)
        var prepared = Array(repeating: AuthenticationAPIInfo.query, count: candidates.count)
        if prepareConfiguredEndpoints, candidates.count > 1 {
            let preparation = await prepareAuthenticationEndpoints(clients)
            prepared = preparation.info
            if let first = preparation.first {
                order = [first] + order.filter { $0 != first }
            }
        }
        try Task.checkCancellation()
        var lastError: Error?
        for index in order {
            try Task.checkCancellation()
            let candidate = candidates[index]
            let client = clients[index]
            do {
                let authenticatedSession = try await client.login(
                    account: account,
                    password: password,
                    oneTimeCode: oneTimeCode,
                    deviceID: deviceID,
                    sessionName: sessionName,
                    apiInfoPreparation: prepared[index]
                )
                let session = authenticatedSession.replacingConnection(
                    endpoints: endpoints,
                    actualRoute: DSMConnectionRouteResolver.route(
                        for: candidate.url,
                        endpoints: endpoints
                    )
                )
                return DSMLoginResult(client: client, session: session)
            } catch {
                lastError = error
                guard shouldRetryLogin(on: error) else { throw error }
            }
        }
        throw lastError ?? DSMClientError.missingSession
    }

    private static func prepareAuthenticationEndpoints(
        _ clients: [DSMClient]
    ) async -> (first: Int?, info: [AuthenticationAPIInfo]) {
        await withTaskGroup(of: (Int, AuthenticationAPIInfo).self) { group in
            for (index, client) in clients.enumerated() {
                group.addTask {
                    do {
                        let info = try await client.authenticationEndpointInfo()
                        return (index, .prepared(info))
                    } catch {
                        // Cancelled losers have no completed metadata query. A
                        // later safe connect failure may query them normally.
                        return (index, Task.isCancelled ? .query : .prepared(nil))
                    }
                }
            }
            var first: Int?
            var info = Array(repeating: AuthenticationAPIInfo.query, count: clients.count)
            for await (index, result) in group {
                info[index] = result
                if first == nil, case .prepared(.some) = result {
                    first = index
                    group.cancelAll()
                }
            }
            return (first, info)
        }
    }

    /// A bounded GET, with no account, SID, password or OTP. Only metadata from
    /// the configured origin can select a route; this is not authentication.
    private func authenticationEndpointInfo() async throws -> DSMJSONValue {
        guard let target = DSMURLBuilder.url(baseURL: baseURL, appending: "/webapi/query.cgi"),
              var components = URLComponents(url: target, resolvingAgainstBaseURL: false) else {
            throw DSMClientError.invalidAddress
        }
        components.queryItems = [
            URLQueryItem(name: "api", value: "SYNO.API.Info"),
            URLQueryItem(name: "version", value: "1"),
            URLQueryItem(name: "method", value: "query"),
            URLQueryItem(name: "query", value: "SYNO.API.Auth")
        ]
        guard let url = components.url else { throw DSMClientError.invalidAddress }
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.snapshotRequestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        try Task.checkCancellation()
        let (data, response) = try await dataWithAbsoluteTimeout(for: request, timeout: Self.snapshotRequestTimeout)
        try Task.checkCancellation()
        func port(_ url: URL) -> Int { url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80) }
        guard let origin = response.url,
              origin.scheme?.lowercased() == url.scheme?.lowercased(),
              origin.host?.lowercased() == url.host?.lowercased(),
              port(origin) == port(url), origin.path == url.path else {
            throw DSMClientError.invalidResponse
        }
        let info = try DSMAPIResponseDecoder.decode(data, response: response) { _ in }
        // Reject malformed/unbounded version ranges before authLoginRequests
        // materializes the compatibility list from this unauthenticated data.
        guard let auth = info.objectValue?["SYNO.API.Auth"],
              let path = auth.firstString(for: ["path"]), !path.isEmpty,
              let version = auth.firstDouble(for: ["maxVersion", "max_version"]),
              version.isFinite, (1...100).contains(version), version.rounded(.down) == version else {
            throw DSMClientError.invalidResponse
        }
        return info
    }

    static func shouldRetryLogin(on error: Error) -> Bool {
        if let dsmError = error as? DSMClientError {
            switch dsmError {
            case .invalidAddress, .insecureHTTP, .invalidResponse, .apiFailed, .loginRejected, .missingSession:
                return false
            }
        }
        guard let error = error as? URLError else { return false }
        switch error.code {
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet:
            return true
        default:
            // A lost response or timeout does not prove that authentication
            // failed on the server. Preserve the outcome instead of replaying.
            return false
        }
    }

    func login(
        account: String,
        password: String,
        oneTimeCode: String = "",
        deviceID: String? = nil,
        sessionName: String = "Nastart"
    ) async throws -> DSMSession {
        try await login(account: account, password: password, oneTimeCode: oneTimeCode,
                        deviceID: deviceID, sessionName: sessionName, apiInfoPreparation: .query)
    }

    private func login(
        account: String,
        password: String,
        oneTimeCode: String,
        deviceID: String?,
        sessionName: String,
        apiInfoPreparation: AuthenticationAPIInfo
    ) async throws -> DSMSession {
        try Task.checkCancellation()
        record(
            .info,
            categoryKey: "diagnostics.category.connection",
            messageKey: "diagnostics.login.started",
            details: [
                "target": DiagnosticLogStore.redactedURL(baseURL),
                "account": account.isEmpty ? "-" : "<redacted>",
                "session": sessionName,
                "2fa": oneTimeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "off" : "on",
                "selfSigned": allowsSelfSignedCertificates ? "on" : "off"
            ]
        )

        let apiInfo: DSMJSONValue?
        switch apiInfoPreparation {
        case .prepared(let value):
            apiInfo = value
        case .query:
            apiInfo = await optionalCall(
                path: "/webapi/query.cgi",
                queryItems: [
                    URLQueryItem(name: "api", value: "SYNO.API.Info"),
                    URLQueryItem(name: "version", value: "1"),
                    URLQueryItem(name: "method", value: "query"),
                    URLQueryItem(name: "query", value: "SYNO.API.Auth")
                ]
            )
        }
        try Task.checkCancellation()
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
            apiInfo: apiInfo,
            sessionName: sessionName
        ) {
            do {
                // Authentication values must stay out of the URL. Apart from showing up
                // in proxy history, URLSession can include a failed request URL in system
                // diagnostics, which would expose the DSM account password and OTP.
                let data = try await postFormCall(
                    path: request.0,
                    formItems: request.1,
                    timeout: Self.requestTimeout
                )
                // A successful envelope without a usable SID is ambiguous:
                // DSM may already have created the session. Do not submit the
                // same credentials again with an older API version.
                guard let sid = data.firstString(for: ["sid"]),
                      !sid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw DSMClientError.missingSession
                }
                let trustedDeviceID = data.firstString(
                    for: ["device_id", "deviceId", "did", "device_token"]
                ) ?? deviceID
                let session = DSMSession(
                    baseURL: baseURL,
                    sid: sid,
                    fileStationSID: nil,
                    account: account,
                    allowsSelfSignedCertificates: allowsSelfSignedCertificates,
                    deviceID: trustedDeviceID
                )
                record(.info, categoryKey: "diagnostics.category.connection",
                    messageKey: "diagnostics.login.succeeded",
                    details: requestSummary(path: request.0, queryItems: request.1)
                        .merging(session.authenticationObservationFields) { _, new in new })
                return session
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
                throw DSMClientError.rejectedLoginError(from: error)
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
        await logoutObserved(session: session, sid: session.sid, sessionName: "Nastart", generation: session.authenticationGeneration)
        if let fileStationSID = session.fileStationSID {
            await logoutObserved(session: session, sid: fileStationSID, sessionName: "FileStation",
                                 generation: session.fileStationGeneration ?? session.authenticationGeneration)
        }
    }

    /// A losing connection task may clean up only SIDs unused by the current login.
    @MainActor
    func logout(session: DSMSession, protectingCurrentSession: @MainActor () -> DSMSession?) async {
        if Self.mayLogout(sid: session.sid, session: session, current: protectingCurrentSession()) {
            await logoutObserved(session: session, sid: session.sid, sessionName: "Nastart", generation: session.authenticationGeneration)
        }
        if let sid = session.fileStationSID,
           Self.mayLogout(sid: sid, session: session, current: protectingCurrentSession()) {
            await logoutObserved(session: session, sid: sid, sessionName: "FileStation",
                                 generation: session.fileStationGeneration ?? session.authenticationGeneration)
        }
    }

    static func mayLogout(sid: String, session: DSMSession, current: DSMSession?) -> Bool {
        guard let current else { return true }
        func origin(_ url: URL) -> String {
            let scheme = url.scheme?.lowercased() ?? ""
            let port = url.port ?? (scheme == "https" ? 443 : 80)
            return "\(scheme)://\(url.host?.lowercased() ?? ""):\(port)"
        }
        let oldOrigins = Set(([session.baseURL] + session.endpoints.candidates.map { $0.url }).map(origin))
        let currentOrigins = Set(([current.baseURL] + current.endpoints.candidates.map { $0.url }).map(origin))
        guard !oldOrigins.isDisjoint(with: currentOrigins) else { return true }
        return sid != current.sid && sid != current.fileStationSID
    }

    private func logoutObserved(session: DSMSession, sid: String, sessionName: String, generation: UUID) async {
        func report(_ stage: DSMAuthenticationStage, error: Error? = nil) {
            var fields = session.authenticationObservationFields.merging([
                "authenticationStage": stage.rawValue,
                "sessionRole": sessionName == "FileStation" ? "fileStation" : "dsmFallback",
                "requestAuthenticationGeneration": generation.uuidString]) { _, new in new }
            if let dsmError = error as? DSMClientError, case .apiFailed(let code) = dsmError, let code {
                fields["apiErrorCode"] = String(code)
            }
            record(stage == .logoutFailed ? .warning : .info, categoryKey: "diagnostics.category.connection",
                messageKey: "diagnostics.connection.session_lifecycle",
                details: fields)
        }
        report(.logoutStarted)
        do { try await logout(sid: sid, sessionName: sessionName); report(.logoutSucceeded) }
        catch { report(.logoutFailed, error: error) }
    }

    func addingFileStationSession(
        to session: DSMSession,
        account: String,
        password: String,
        oneTimeCode: String = ""
    ) async -> DSMSession {
        let fileStationSession = try? await login(
            account: account,
            password: password,
            oneTimeCode: oneTimeCode,
            deviceID: session.deviceID,
            sessionName: "FileStation"
        )
        let combined = session.attachingFileStationSession(fileStationSession)
        combined.recordAuthenticationStage(fileStationSession == nil ? .fileStationUnavailable : .fileStationAttached)
        return combined
    }

    private func logout(sid: String, sessionName: String) async throws {
        _ = try await call(
            path: "/webapi/auth.cgi",
            queryItems: [
                URLQueryItem(name: "api", value: "SYNO.API.Auth"),
                URLQueryItem(name: "version", value: "6"),
                URLQueryItem(name: "method", value: "logout"),
                URLQueryItem(name: "session", value: sessionName),
                URLQueryItem(name: "_sid", value: sid)
            ]
        )
    }

    func isDSMEndpoint() async -> Bool {
        let data = try? await callWithAbsoluteTimeout(
            path: "/webapi/query.cgi",
            queryItems: [
                URLQueryItem(name: "api", value: "SYNO.API.Info"),
                URLQueryItem(name: "version", value: "1"),
                URLQueryItem(name: "method", value: "query"),
                URLQueryItem(name: "query", value: "SYNO.API.Auth,SYNO.Core.System")
            ],
            timeout: 4
        )
        return data?.objectValue?["SYNO.API.Auth"] != nil
    }

    func loadSnapshot(session: DSMSession, useAgent _: Bool) async -> DSMDataSnapshot {
        let snapshotStartedAt = Date()
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
        cacheFileStationAPIInfo(apiInfo)
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
        ), folderContext: .init(origin: .snapshot, session: session))
        async let packageData = firstSuccessfulCall(apiRequests(
            session,
            apiInfo: apiInfo,
            apiName: "SYNO.Core.Package",
            fallbackPath: "/webapi/entry.cgi",
            fallbackMaxVersion: 2,
            method: "list",
            // Running state is only returned on request; without it every package reads "unknown".
            extras: [[URLQueryItem(name: "additional", value: "[\"status\"]")]]
        ), timeout: Self.packageSnapshotRequestTimeout, maximumAttempts: 1)
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
                "durationMs": "\(Int(Date().timeIntervalSince(snapshotStartedAt) * 1_000))",
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
            reverseProxyInventoryAvailable: reverseProxies != nil,
            agentHealth: nil
        )
    }

    func listFolder(session: DSMSession, folderPath: String) async throws -> [FileItem] {
        let normalizedPath = folderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "/" : folderPath
        let folderContext = DSMFolderDiagnosticContext(
            origin: normalizedPath == "/" ? .browserRoot : .browserFolder,
            session: session)
        let startedAt = Date()
        let cachedAPIInfo = fileStationAPIInfo()
        let apiInfo: DSMJSONValue?
        if let cachedAPIInfo {
            apiInfo = cachedAPIInfo
        } else {
            let loadedAPIInfo = await optionalCall(
                path: "/webapi/query.cgi",
                queryItems: [
                    URLQueryItem(name: "api", value: "SYNO.API.Info"),
                    URLQueryItem(name: "version", value: "1"),
                    URLQueryItem(name: "method", value: "query"),
                    URLQueryItem(name: "query", value: "SYNO.FileStation.List")
                ]
            )
            cacheFileStationAPIInfo(loadedAPIInfo)
            apiInfo = loadedAPIInfo
        }
        if normalizedPath == "/" {
            let data = try await firstSuccessfulFolderCall(apiRequests(
                session,
                apiInfo: apiInfo,
                apiName: "SYNO.FileStation.List",
                fallbackPath: "/webapi/entry.cgi",
                fallbackMaxVersion: 2,
                method: "list_share"
            ), folderContext: folderContext)
            let items = DSMClient.mapSharedFolders(data)
            record(
                .info,
                categoryKey: "diagnostics.category.dsm_api",
                messageKey: "diagnostics.files.folder_loaded",
                details: [
                    "pathDepth": "0",
                    "items": "\(items.count)",
                    "pages": "1",
                    "apiInfo": cachedAPIInfo == nil ? "network" : "cache",
                    "durationMs": "\(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000))"
                ]
            )
            return items
        }
        let encodedAdditional = Self.jsonQueryValue(["real_path", "size", "type", "time"])
            ?? "[\"real_path\",\"size\",\"type\",\"time\"]"
        let pageSize = 500
        var offset = 0
        var allItems: [FileItem] = []
        var pageCount = 0

        while offset < 25_000 {
            let common = [
                URLQueryItem(name: "limit", value: "\(pageSize)"),
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "sort_by", value: "name"),
                URLQueryItem(name: "sort_direction", value: "asc")
            ]
            let parameterVariants = [
                [
                    URLQueryItem(name: "folder_path", value: normalizedPath),
                    URLQueryItem(name: "additional", value: encodedAdditional)
                ] + common,
                [URLQueryItem(name: "folder_path", value: normalizedPath)] + common
            ]
            let data = try await firstSuccessfulFolderCall(apiRequests(
                session,
                apiInfo: apiInfo,
                apiName: "SYNO.FileStation.List",
                fallbackPath: "/webapi/entry.cgi",
                fallbackMaxVersion: 2,
                method: "list",
                extras: parameterVariants
            ), folderContext: folderContext)

            let page = DSMClient.mapFileItems(data, parentPath: normalizedPath)
            pageCount += 1
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
                "items": "\(items.count)",
                "pages": "\(pageCount)",
                "apiInfo": cachedAPIInfo == nil ? "network" : "cache",
                "durationMs": "\(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000))"
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
        timeout: TimeInterval = requestTimeout,
        folderContext: DSMFolderDiagnosticContext? = nil,
        folderAttempt: Int = 0
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
        let (data, response) = try await idempotentData(for: request)
        try Task.checkCancellation()
        return try DSMAPIResponseDecoder.decode(data, response: response) { fields in
            // File-list failures used to collapse into invalidResponse after
            // all variants failed. Keep each HTTP/envelope boundary separately.
            guard queryItems.contains(where: { $0.name == "api" && $0.value == "SYNO.FileStation.List" }) else { return }
            var details = fields
            if let folderContext {
                details.merge(folderContext.fields(attempt: folderAttempt)) { _, new in new }
                details["diagnosticClientID"] = diagnosticClientID
            }
            if let version = queryItems.first(where: { $0.name == "version" })?.value,
               let number = Int(version), number > 0 { details["apiVersion"] = String(number) }
            if let method = queryItems.first(where: { $0.name == "method" })?.value,
               ["list", "list_share"].contains(method) { details["method"] = method }
            self.record(fields["responseKind"] == "success" ? .info : .warning,
                categoryKey: "diagnostics.category.dsm_api",
                messageKey: "diagnostics.files.folder_response", details: details)
        }
    }

    private func idempotentData(for request: URLRequest) async throws -> (Data, URLResponse) {
        var attempt = 0
        while true {
            try Task.checkCancellation()
            do {
                return try await urlSession.data(for: request)
            } catch {
                guard attempt < 1, Self.isTransientNetworkError(error), !Task.isCancelled else {
                    throw error
                }
                attempt += 1
                try await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func callWithAbsoluteTimeout(
        path: String,
        queryItems: [URLQueryItem],
        timeout: TimeInterval,
        folderContext: DSMFolderDiagnosticContext? = nil,
        folderAttempt: Int = 0
    ) async throws -> DSMJSONValue {
        try await withThrowingTaskGroup(of: DSMJSONValue.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                try await self.call(path: path, queryItems: queryItems, timeout: timeout,
                                    folderContext: folderContext, folderAttempt: folderAttempt)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: Self.nanoseconds(for: timeout))
                throw URLError(.timedOut)
            }
            guard let value = try await group.next() else {
                throw CancellationError()
            }
            return value
        }
    }

    private static func nanoseconds(for timeout: TimeInterval) -> UInt64 {
        UInt64(max(timeout, 0.1) * 1_000_000_000)
    }

    private static func isTransientNetworkError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost,
             .notConnectedToInternet, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private func postFormCall(
        path: String,
        formItems: [URLQueryItem],
        timeout: TimeInterval = requestTimeout
    ) async throws -> DSMJSONValue {
        guard let url = DSMURLBuilder.url(baseURL: baseURL, appending: path) else {
            throw DSMClientError.invalidAddress
        }
        var formComponents = URLComponents()
        formComponents.queryItems = formItems
        guard let body = formComponents.percentEncodedQuery?.data(using: .utf8) else {
            throw DSMClientError.invalidAddress
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "application/x-www-form-urlencoded; charset=utf-8",
            forHTTPHeaderField: "Content-Type"
        )
        try Task.checkCancellation()
        let (data, response) = try await dataWithAbsoluteTimeout(for: request, timeout: timeout)
        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw DSMClientError.invalidResponse
        }

        let envelope = try JSONDecoder().decode(DSMAPIEnvelope.self, from: data)
        guard envelope.success else {
            throw DSMClientError.apiFailed(code: envelope.error?.code)
        }
        return envelope.data ?? .object([:])
    }

    /// Credential POSTs use a wall deadline, not URLSession's inactivity timer.
    /// Cancellation also cancels the underlying data task; POST is never retried here.
    func dataWithAbsoluteTimeout(for request: URLRequest, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            defer { group.cancelAll() }
            group.addTask { try await self.urlSession.data(for: request) }
            group.addTask {
                try await Task.sleep(nanoseconds: Self.nanoseconds(for: timeout))
                throw URLError(.timedOut)
            }
            guard let response = try await group.next() else { throw CancellationError() }
            return response
        }
    }

    private func optionalCall(path: String, queryItems: [URLQueryItem]) async -> DSMJSONValue? {
        try? await callWithAbsoluteTimeout(
            path: path,
            queryItems: queryItems,
            timeout: Self.snapshotRequestTimeout
        )
    }

    private func fileStationAPIInfo() -> DSMJSONValue? {
        apiInfoCacheLock.lock()
        defer { apiInfoCacheLock.unlock() }
        return cachedFileStationAPIInfo
    }

    private func cacheFileStationAPIInfo(_ apiInfo: DSMJSONValue?) {
        guard let apiInfo, apiInfoEntry(apiInfo, apiName: "SYNO.FileStation.List") != nil else {
            return
        }
        apiInfoCacheLock.lock()
        cachedFileStationAPIInfo = apiInfo
        apiInfoCacheLock.unlock()
    }

    private func firstSuccessfulCall(
        _ requests: [(String, [URLQueryItem])],
        timeout: TimeInterval = DSMClient.snapshotRequestTimeout,
        maximumAttempts: Int? = nil,
        folderContext: DSMFolderDiagnosticContext? = nil
    ) async -> DSMJSONValue? {
        try? await firstSuccessfulCallThrowing(requests, timeout: timeout,
            maximumAttempts: maximumAttempts, folderContext: folderContext,
            stopOnInvalidSession: false)
    }

    private func firstSuccessfulFolderCall(
        _ requests: [(String, [URLQueryItem])],
        folderContext: DSMFolderDiagnosticContext
    ) async throws -> DSMJSONValue {
        try await firstSuccessfulCallThrowing(requests, timeout: Self.snapshotRequestTimeout,
            folderContext: folderContext, stopOnInvalidSession: true)
    }

    private func firstSuccessfulCallThrowing(
        _ requests: [(String, [URLQueryItem])],
        timeout: TimeInterval,
        maximumAttempts: Int? = nil,
        folderContext: DSMFolderDiagnosticContext?,
        stopOnInvalidSession: Bool
    ) async throws -> DSMJSONValue {
        let attempts = maximumAttempts.map { Array(requests.prefix(max($0, 0))) } ?? requests
        var lastError: Error = DSMClientError.invalidResponse
        for (index, request) in attempts.enumerated() {
            try Task.checkCancellation()
            do {
                return try await callWithAbsoluteTimeout(
                    path: request.0, queryItems: request.1, timeout: timeout,
                    folderContext: folderContext, folderAttempt: index + 1)
            } catch {
                try Task.checkCancellation()
                record(
                    .warning,
                    categoryKey: "diagnostics.category.dsm_api",
                    messageKey: "diagnostics.api_request.failed",
                    details: requestSummary(path: request.0, queryItems: request.1).merging(["error": diagnosticMessage(for: error)]) { current, _ in current }
                )
                // A different path/version with the same SID cannot restore it.
                // Snapshot enrichment remains best-effort; browsing retains 119.
                if stopOnInvalidSession, case DSMClientError.apiFailed(code: 119) = error {
                    throw error
                }
                // Directory fallbacks negotiate API compatibility. A URL loading
                // failure supplies no compatibility response, so changing query
                // parameters on the same endpoint only repeats the transport wait.
                // Leave HTTP/API/decoding fallbacks and optional snapshot calls alone.
                if stopOnInvalidSession, error is URLError {
                    throw error
                }
                lastError = error
            }
        }
        throw lastError
    }

    private func sessionItems(_ session: DSMSession, api: String, version: String, method: String, extra: [URLQueryItem] = []) -> [URLQueryItem] {
        let sid = api.hasPrefix("SYNO.FileStation.")
            ? session.fileStationSID ?? session.sid
            : session.sid
        return [
            URLQueryItem(name: "api", value: api),
            URLQueryItem(name: "version", value: version),
            URLQueryItem(name: "method", value: method),
            URLQueryItem(name: "_sid", value: sid)
        ] + extra
    }

    private func authLoginRequests(
        account: String,
        password: String,
        oneTimeCode: String,
        deviceID: String?,
        apiInfo: DSMJSONValue?,
        sessionName: String
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
                URLQueryItem(name: "session", value: sessionName),
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
            for container in containers where container.status == .online
                && !LaunchpadDefaultVisibilityPolicy.isInfrastructureContainer(image: container.image) {
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
                value = try await callWithAbsoluteTimeout(
                    path: request.0,
                    queryItems: request.1,
                    timeout: Self.snapshotRequestTimeout
                )
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
        NetworkErrorKind.diagnosticMessage(for: error)
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
        return "\(Int(value.rounded())) °C"
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

    static func mapFileItems(_ data: DSMJSONValue?, parentPath: String) -> [FileItem] {
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
                children: [],
                sizeBytes: kind == .folder ? nil : fileSizeBytes(item),
                modifiedAt: fileModifiedAt(item)
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
        if AudioFormatPolicy.extensions.contains(ext) { return .audio }
        if [
            "jpg", "jpeg", "png", "gif", "heic", "heif", "webp",
            "bmp", "tif", "tiff", "avif", "dng", "svg"
        ].contains(ext) { return .image }
        if ext == "iso" { return .discImage }
        if ["zip", "rar", "7z", "tar", "gz"].contains(ext) { return .archive }
        return .text
    }

    private static func fileSizeText(_ item: DSMJSONValue) -> String? {
        if let formatted = nonEmptyString(item.firstString(for: ["size_text", "formatted_size"])) {
            return formatted
        }
        return DSMFormatters.bytes(item.firstDouble(for: ["size", "filesize"]))
    }

    private static func fileSizeBytes(_ item: DSMJSONValue) -> Int64? {
        guard let value = item.firstDouble(for: ["size", "filesize"]),
              value.isFinite, value >= 0, value < Double(Int64.max) else { return nil }
        return Int64(value)
    }

    private static func fileModifiedAt(_ item: DSMJSONValue) -> Date? {
        let value = item["additional"]?["time"]?["mtime"]?.doubleValue
            ?? item["time"]?["mtime"]?.doubleValue
            ?? item.firstDirectDouble(for: ["mtime", "modified_time"])
        guard let value, value.isFinite, value > 0 else { return nil }
        return Date(timeIntervalSince1970: value)
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

    static func mapContainers(
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
                keys: DSMServiceIdentity.containerNameKeys
            ) else { return nil }
            let identifier = directTextValue(in: item, keys: ["id", "Id", "container_id", "containerId"])
                ?? name.lowercased()
            guard seen.insert(identifier).inserted else { return nil }
            let image = directTextValue(
                in: item,
                keys: DSMServiceIdentity.containerImageKeys
            ) ?? DSMServiceIdentity.missingImage
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
        let endpointDiscoveryStartedAt = Date()
        let containerEndpoints = await resolvedContainerEndpoints(
            containers,
            reverseProxyRules: reverseProxyRules,
            lanHosts: Self.uniqueStrings([session.endpoints.lanAddress?.host].compactMap { $0 } + lanHosts),
            baseURL: session.baseURL
        )
        record(
            .info,
            categoryKey: "diagnostics.category.dsm_api",
            messageKey: "diagnostics.endpoints.completed",
            details: ["durationMs": "\(Int(Date().timeIntervalSince(endpointDiscoveryStartedAt) * 1_000))",
                      "count": "\(containerEndpoints.count)"]
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
            return Self.mapContainerService(
                container, endpoint: resolvedEndpoint?.url, alternateEndpoint: resolvedEndpoint?.alternateURL,
                source: resolvedEndpoint?.source ?? .container
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

    static func mapContainerService(
        _ container: DockerContainer,
        endpoint: URL? = nil,
        alternateEndpoint: URL? = nil,
        source: LaunchpadServiceSource = .container
    ) -> LaunchpadService {
        return LaunchpadService(
            id: StableIdentifier.uuid("service|container|\(container.id.uuidString.lowercased())"),
            name: DSMServiceIdentity.containerDisplayName(name: container.name, image: container.image),
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
            endpoint: endpoint,
            alternateEndpoint: alternateEndpoint,
            source: source,
            isLaunchpadVisible: Self.shouldAutomaticallyShowContainerService(
                container,
                endpoint: endpoint
            )
        )
    }

    private static func mapPackageServices(_ data: DSMJSONValue?, session: DSMSession) -> [LaunchpadService] {
        guard let data else { return [] }
        let packageRoot = data.firstDirectValue(for: ["result", "data"]) ?? data
        guard let packages = packageRoot.firstDirectArray(for: ["packages", "items", "list"]) else { return [] }
        return packages.compactMap { item in
            guard let name = directTextValue(
                in: item,
                keys: DSMServiceIdentity.packageNameKeys
            ) else { return nil }
            guard isInstalledPackage(item) else { return nil }
            let endpoint = packageEndpoint(for: item, baseURL: session.baseURL)
            let status = packageStatus(item)
            return LaunchpadService(
                id: StableIdentifier.uuid("service|package|\(name.lowercased())"),
                name: DSMServiceIdentity.displayName(for: name),
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
                isLaunchpadVisible: shouldAutomaticallyAddPackageService(name, endpoint: endpoint)
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
                                ResolvedContainerEndpoint(url: endpoint, source: .container,
                                    alternateURL: Self.reverseProxyEndpoint(for: container, rules: reverseProxyRules, baseURL: baseURL))
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
                        let discoveredLocalEndpoint = Self.isPrivateNetworkHost(baseURL.host)
                            ? await self.firstReachableWebEndpoint(
                            Array(localCandidates.prefix(4)),
                            serviceName: container.name
                        ) : nil
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

    static func unverifiedFallbackEndpoint(
        for container: DockerContainer,
        candidates: [URL]
    ) -> URL? {
        let name = container.name.lowercased()
        guard !name.contains("jellyfin"), !name.contains("emby") else { return nil }
        // A published Docker port is a LAN observation, not evidence of a
        // router mapping or reverse proxy on the DSM login domain.
        return isLikelyWebContainer(container)
            ? candidates.first { isPrivateNetworkHost($0.host) }
            : nil
    }

    private func firstReachableWebEndpoint(
        _ candidates: [URL],
        serviceName: String? = nil
    ) async -> URL? {
        if serviceName?.lowercased().contains("jellyfin") == true
            || serviceName?.lowercased().contains("emby") == true {
            return await firstReachableJellyfinEndpoint(candidates, expectedProduct: serviceName?.lowercased().contains("emby") == true ? .emby : .jellyfin)
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

            var completed = Set<Int>()
            var best: (Int, URL)?
            for await (index, endpoint) in group {
                completed.insert(index)
                if let endpoint, best == nil || index < best!.0 {
                    best = (index, endpoint)
                }
                // Preserve candidate priority, but don't wait for lower-priority
                // addresses once every preferred candidate has completed.
                if let best, (0..<best.0).allSatisfy({ completed.contains($0) }) {
                    group.cancelAll()
                    return best.1
                }
            }
            return best?.1
        }
    }

    private func firstReachableJellyfinEndpoint(_ candidates: [URL], expectedProduct: MediaServiceProduct) async -> URL? {
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
                    let candidate = MediaServiceCandidate(id: String(index), name: expectedProduct.title,
                        hint: expectedProduct, running: nil, endpoints: [base])
                    var certificates: [URL: Data] = [:]
                    if self.allowsSelfSignedCertificates, base.host?.lowercased() == self.baseURL.host?.lowercased(),
                       let data = CertificatePinStore.shared.trustedCertificateData(host: base.host, port: base.port) { certificates[base] = data }
                    guard let observation = try? await MediaServiceProbe(transport: PublicMediaServiceHTTP(trustedCertificates: certificates)).inspect(candidate),
                          observation.identity?.product == expectedProduct else { return (index, nil) }
                    return (index, base)
                }
            }

            var completed = Set<Int>()
            var best: (Int, URL)?
            for await (index, endpoint) in group {
                completed.insert(index)
                if let endpoint, best == nil || index < best!.0 {
                    best = (index, endpoint)
                }
                // Preserve candidate priority, but don't wait for lower-priority
                // addresses once every preferred candidate has completed.
                if let best, (0..<best.0).allSatisfy({ completed.contains($0) }) {
                    group.cancelAll()
                    return best.1
                }
            }
            return best?.1
        }
    }

    /// URLSession's request timeout measures inactivity. A service that keeps
    /// sending bytes (or waits for connectivity) must not hold up NAS discovery.
    func endpointProbeResponse(for request: URLRequest) async throws -> URLResponse {
        try await withThrowingTaskGroup(of: URLResponse.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                let (_, response) = try await self.urlSession.data(for: request)
                return response
            }
            group.addTask {
                try await Task.sleep(nanoseconds: Self.nanoseconds(for: request.timeoutInterval))
                throw URLError(.timedOut)
            }
            guard let response = try await group.next() else { throw CancellationError() }
            return response
        }
    }

    private func reachableWebEndpoint(_ endpoint: URL) async -> URL? {
        for method in ["HEAD", "GET"] {
            guard !Task.isCancelled else { return nil }
            var request = URLRequest(url: endpoint)
            request.httpMethod = method
            request.timeoutInterval = method == "HEAD" ? 1.5 : 2.5
            request.cachePolicy = .reloadIgnoringLocalCacheData
            if method == "GET" {
                request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
            }
            do {
                let response = try await endpointProbeResponse(for: request)
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

    private static func shouldAutomaticallyAddPackageService(
        _ name: String,
        endpoint: URL?
    ) -> Bool {
        LaunchpadDefaultVisibilityPolicy.shouldShowPackage(
            name: name,
            hasEndpoint: endpoint != nil
        )
    }

    private static func shouldAutomaticallyShowContainerService(
        _ container: DockerContainer,
        endpoint: URL?
    ) -> Bool {
        guard container.status == .online, endpoint != nil else { return false }
        return LaunchpadDefaultVisibilityPolicy.shouldShowContainer(
            name: container.name,
            image: container.image,
            hasEndpoint: true
        )
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
        return DSMServiceIdentity.discoveryText(text)
    }

    private static func iconText(for name: String) -> String {
        let lower = name.lowercased()
        let compact = compactServiceIdentifier(name)
        if let badgeText = ServiceIconRegistry.identity(name: name).badgeText {
            return badgeText
        }
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
        if let category = ServiceIconRegistry.identity(name: name).category {
            return category
        }
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

    static func endpointCandidates(
        for container: DockerContainer,
        baseURL: URL,
        lanHosts: [String]
    ) -> [URL] {
        let knownLANHosts = lanHosts.filter { Self.isPrivateNetworkHost($0) }
        let hosts = uniqueStrings(Self.isPrivateNetworkHost(baseURL.host)
            ? [baseURL.host].compactMap { $0 } + knownLANHosts
            : knownLANHosts + [baseURL.host].compactMap { $0 })
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
