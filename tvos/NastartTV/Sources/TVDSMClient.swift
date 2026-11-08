import Foundation
import NetworkMedia

struct TVDSMAPI: Codable, Equatable {
    let path: String
    let minVersion: Int
    let maxVersion: Int
}
struct TVNASAccount: Codable, Equatable {
    let server: URL
    let user: String
    let sid: String
    let apis: [String: TVDSMAPI]
}
struct TVNASFile: Decodable, Identifiable, Hashable {
    let name: String
    let path: String
    let isdir: Bool
    let additional: Additional?
    struct Additional: Decodable, Hashable {
        let size: Int64?
        let time: Times?
        struct Times: Decodable, Hashable { let mtime: Double? }
    }
    var id: String { path }
    var isMedia: Bool {
        !isdir && ["mp4", "m4v", "mov", "mkv", "ts", "m2ts", "avi", "mp3", "m4a", "flac", "aac", "wav", "ogg", "opus", "ape", "aif", "aiff", "mka", "wma"].contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }
    var isAudio: Bool { ["mp3", "m4a", "flac", "aac", "wav", "ogg", "opus", "ape", "aif", "aiff", "mka", "wma"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) }
    var formattedSize: String {
        guard !isdir, let size = additional?.size, size >= 0 else { return "未提供" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    var modifiedAt: Date? {
        guard let time = additional?.time?.mtime, time.isFinite, time > 0 else { return nil }
        return Date(timeIntervalSince1970: time)
    }
    var kindDescription: String {
        if isdir { return "文件夹" }
        let ext = URL(fileURLWithPath: path).pathExtension.uppercased()
        return ext.isEmpty ? "文件" : ext + (isAudio ? " 音频" : (isMedia ? " 视频" : " 文件"))
    }
}
enum TVNASFileSort: String, CaseIterable, Identifiable {
    case name, kind, modified, size
    var id: String { rawValue }
    var title: String {
        switch self { case .name: return "名称"; case .kind: return "类型"; case .modified: return "修改时间"; case .size: return "大小" }
    }
    var apiValue: String {
        switch self { case .kind: return "type"; case .modified: return "mtime"; default: return rawValue }
    }
}
struct TVNASFilePage: Decodable {
    let files: [TVNASFile]?
    let shares: [TVNASFile]?
    let total: Int?
    var items: [TVNASFile] { files ?? shares ?? [] }
}
enum TVDSMError: LocalizedError {
    case api(Int), invalidResponse, unavailableAPI, unsafePath
    var errorDescription: String? {
        switch self {
        case .api(let code):
            switch code {
            case 400: return "账号或密码错误。"
            case 401, 402: return "账号已停用或没有访问权限。"
            case 403: return "此账号需要两步验证，请输入验证码。"
            case 404: return "验证码错误，请重新输入。"
            case 106, 107, 119: return "DSM 登录已过期，请在“我的”中重新连接。"
            default: return "DSM 请求失败（\(code)），请重试。"
            }
        case .invalidResponse: return "DSM 返回了无法识别的数据。"
        case .unavailableAPI: return "服务器未提供此功能，或当前账号没有权限。"
        case .unsafePath: return "服务器返回了无效的接口路径。"
        }
    }
}

/// Keep the configured origin for authentication, metadata and file requests.
/// Discover API paths/versions, and send login values and SIDs in POST bodies.
struct TVDSMClient {
    let server: URL
    let account: TVNASAccount?
    let session: URLSession
    init(server: URL, session: URLSession = TVDSMTransport.session) {
        self.server = server; self.session = session; account = nil
    }
    init(account: TVNASAccount, session: URLSession = TVDSMTransport.session) {
        server = account.server; self.account = account; self.session = session
    }
    static func serverURL(_ text: String) throws -> URL {
        let url = try TVJellyfinClient.serverURL(text)
        guard url.path.isEmpty || url.path == "/" else { throw TVClientError.invalidServer }
        return url
    }
    static func apiURL(server: URL, path: String) throws -> URL {
        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.hasPrefix("/"),
              segments.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              !path.contains(":"), !path.contains("?"), !path.contains("#"), !path.contains("%"), !path.contains("\\") else { throw TVDSMError.unsafePath }
        return segments.reduce(server.appendingPathComponent("webapi")) { $0.appendingPathComponent(String($1)) }
    }
    func request(path: String, values: [URLQueryItem]) throws -> URLRequest {
        var request = URLRequest(url: try Self.apiURL(server: server, path: path))
        request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        var form = URLComponents(); form.queryItems = values
        request.httpBody = form.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        return request
    }
    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw TVDSMError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw TVClientError.http(http.statusCode) }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard object?["success"] as? Bool == true else {
            throw TVDSMError.api((object?["error"] as? [String: Any])?["code"] as? Int ?? -1)
        }
        guard let value = object?["data"] else { throw TVDSMError.invalidResponse }
        return try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
    }
    static let supportedAPIs = ["SYNO.API.Auth", "SYNO.Core.System", "SYNO.Core.System.Utilization", "SYNO.FileStation.List", "SYNO.FileStation.Download"]
    func login(user: String, password: String, otp: String) async throws -> TVNASAccount {
        let info = try await send(request(path: "query.cgi", values: [
            .init(name: "api", value: "SYNO.API.Info"), .init(name: "version", value: "1"),
            .init(name: "method", value: "query"), .init(name: "query", value: Self.supportedAPIs.joined(separator: ","))]))
        let apis = try JSONDecoder().decode([String: TVDSMAPI].self, from: info)
        guard let auth = apis["SYNO.API.Auth"], auth.minVersion <= 7, auth.maxVersion >= 3 else { throw TVDSMError.unavailableAPI }
        var values: [URLQueryItem] = [.init(name: "api", value: "SYNO.API.Auth"),
            .init(name: "version", value: String(min(7, auth.maxVersion))), .init(name: "method", value: "login"),
            .init(name: "account", value: user), .init(name: "passwd", value: password),
            .init(name: "session", value: "NastartTV"), .init(name: "format", value: "sid")]
        if !otp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { values.append(.init(name: "otp_code", value: otp.trimmingCharacters(in: .whitespacesAndNewlines))) }
        let data = try await send(request(path: auth.path, values: values))
        struct Login: Decodable { let sid: String }
        let sid = try JSONDecoder().decode(Login.self, from: data).sid
        guard !sid.isEmpty else { throw TVDSMError.invalidResponse }
        return TVNASAccount(server: server, user: user, sid: sid, apis: apis)
    }
    func apiRequest(_ api: String, method: String, version: Int, extras: [URLQueryItem] = []) throws -> URLRequest {
        guard let account, let entry = account.apis[api], entry.minVersion <= version else { throw TVDSMError.unavailableAPI }
        return try request(path: entry.path, values: [
            .init(name: "api", value: api), .init(name: "version", value: String(min(version, entry.maxVersion))),
            .init(name: "method", value: method), .init(name: "_sid", value: account.sid)] + extras)
    }
    func files(path: String, offset: Int = 0, sort: TVNASFileSort = .name, ascending: Bool = true) async throws -> TVNASFilePage {
        // Shared folders do not support size/type sorting. Never send unsupported
        // fields or re-sort just one page while presenting it as a directory sort.
        let effectiveSort = path == "/" && (sort == .size || sort == .kind) ? TVNASFileSort.name : sort
        var extras: [URLQueryItem] = [.init(name: "offset", value: String(max(0, offset))), .init(name: "limit", value: "100"),
            .init(name: "sort_by", value: effectiveSort.apiValue), .init(name: "sort_direction", value: ascending ? "asc" : "desc"),
            .init(name: "additional", value: path == "/" ? "[\"time\"]" : "[\"size\",\"type\",\"time\"]")]
        if path != "/" { extras.append(.init(name: "folder_path", value: path)) }
        let data = try await send(apiRequest("SYNO.FileStation.List", method: path == "/" ? "list_share" : "list", version: 2, extras: extras))
        return try JSONDecoder().decode(TVNASFilePage.self, from: data)
    }
    func systemInfo(utilization: Bool = false) async throws -> [String: Any] {
        let data = try await send(apiRequest(utilization ? "SYNO.Core.System.Utilization" : "SYNO.Core.System",
                                           method: utilization ? "get" : "info", version: 1))
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw TVDSMError.invalidResponse }
        return value
    }
    func mediaURL(path: String) throws -> URL {
        guard let account, let entry = account.apis["SYNO.FileStation.Download"], entry.minVersion <= 2,
              entry.maxVersion >= 2, path.hasPrefix("/"), !path.contains("\0") else { throw TVDSMError.unavailableAPI }
        let encoded = String(data: try JSONEncoder().encode([path]), encoding: .utf8)!
        var parts = URLComponents(url: try Self.apiURL(server: server, path: entry.path), resolvingAgainstBaseURL: false)!
        parts.queryItems = [.init(name: "api", value: "SYNO.FileStation.Download"), .init(name: "version", value: "2"),
            .init(name: "method", value: "download"), .init(name: "mode", value: "\"open\""), .init(name: "path", value: encoded), .init(name: "_sid", value: account.sid)]
        return parts.url!
    }
    func logout() async {
        guard let request = try? apiRequest("SYNO.API.Auth", method: "logout", version: 3, extras: [.init(name: "session", value: "NastartTV")]) else { return }
        // DSM may return success without data for logout.
        _ = try? await session.data(for: request)
    }
}

private final class TVDSMTransport: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let delegate = TVDSMTransport()
    static let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    static func sameOrigin(_ a: URL, _ b: URL) -> Bool {
        a.scheme?.lowercased() == b.scheme?.lowercased() && a.host?.lowercased() == b.host?.lowercased()
            && (a.port ?? (a.scheme == "https" ? 443 : 80)) == (b.port ?? (b.scheme == "https" ? 443 : 80))
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let from = task.originalRequest?.url, let to = request.url, Self.sameOrigin(from, to) else { completionHandler(nil); return }
        completionHandler(request)
    }
}

struct TVDiscoveredService: Identifiable {
    let id: String
    let name: String
    let detail: String
    let kind: String
    let running: Bool?
    let ports: [Int]
    var endpoints: [URL] = []
    var verifiedJellyfin: URL?
    var managementEndpoints: [URL] {
        endpoints.filter { url in
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil,
                  url.user == nil, url.password == nil else { return false }
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return !query.contains { ["sid", "_sid", "api_key", "token", "password", "passwd", "authorization"].contains($0.name.lowercased()) }
        }
    }
    var isJellyfin: Bool { (name + " " + detail).localizedCaseInsensitiveContains("jellyfin") }
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || [name, detail, kind].contains { $0.localizedCaseInsensitiveContains(query) }
    }
}
struct TVServiceDiscovery {
    var services: [TVDiscoveredService] = []
    var warnings: [String] = []
    var containerInventoryAvailable = false
    var packageInventoryAvailable = false
    var reverseProxyInventoryAvailable = false
    var complete: Bool { containerInventoryAvailable && packageInventoryAvailable && reverseProxyInventoryAvailable }
}

extension TVDSMClient {
    static let discoveryAPIs = ["SYNO.ContainerManager.Container", "SYNO.Docker.Container", "SYNO.Core.Package", "SYNO.Core.AppPortal.ReverseProxy"]

    /// Refresh the API catalog without replacing the user's existing DSM session.
    func discoverServices(publicTransport: any PublicMediaServiceTransport = PublicMediaServiceHTTP()) async throws -> TVServiceDiscovery {
        guard let account else { throw TVDSMError.unavailableAPI }
        let catalog = try await send(request(path: "query.cgi", values: [
            .init(name: "api", value: "SYNO.API.Info"), .init(name: "version", value: "1"),
            .init(name: "method", value: "query"), .init(name: "query", value: Self.discoveryAPIs.joined(separator: ","))]))
        let apis = try JSONDecoder().decode([String: TVDSMAPI].self, from: catalog)
        let refreshed = TVDSMClient(account: TVNASAccount(server: account.server, user: account.user, sid: account.sid,
                                                         apis: account.apis.merging(apis) { _, new in new }), session: session)
        var result = TVServiceDiscovery()
        var containerRead = false
        for api in ["SYNO.ContainerManager.Container", "SYNO.Docker.Container"] where apis[api] != nil {
            do {
                let data = try await refreshed.send(refreshed.apiRequest(api, method: "list", version: apis[api]!.maxVersion,
                    extras: [.init(name: "type", value: "all"), .init(name: "offset", value: "0"), .init(name: "limit", value: "1000")]))
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                guard let rows = Self.serviceRows(object, keys: ["containers", "container", "items", "list"]) else { throw TVDSMError.invalidResponse }
                result.services += Self.containerServices(rows)
                containerRead = true; result.containerInventoryAvailable = true; break
            } catch {
                try Task.checkCancellation()
                result.warnings.append("容器查询未完成：" + discoveryError(error))
            }
        }
        if !containerRead && !Self.discoveryAPIs.prefix(2).contains(where: { apis[$0] != nil }) {
            result.warnings.append("此 DSM 未提供容器查询接口，或当前账号没有权限。")
        }
        if apis["SYNO.Core.Package"] != nil {
            do {
                let data = try await refreshed.send(refreshed.apiRequest("SYNO.Core.Package", method: "list", version: 2))
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                guard let rows = Self.serviceRows(object, keys: ["packages", "items", "list"]) else { throw TVDSMError.invalidResponse }
                result.packageInventoryAvailable = true
                result.services += rows.compactMap { row in
                    guard let id = Self.string(row, ["id", "name", "package"]) else { return nil }
                    return TVDiscoveredService(id: "package:" + id, name: Self.string(row, ["dname", "display_name", "name"]) ?? id,
                        detail: Self.string(row, ["version", "description"]) ?? "", kind: "套件", running: Self.running(row), ports: [])
                }
            } catch { try Task.checkCancellation(); result.warnings.append("套件查询未完成：" + discoveryError(error)) }
        } else { result.warnings.append("此 DSM 未提供套件查询接口，或当前账号没有权限。") }
        if apis["SYNO.Core.AppPortal.ReverseProxy"] != nil {
            do {
                let data = try await refreshed.send(refreshed.apiRequest("SYNO.Core.AppPortal.ReverseProxy", method: "list", version: 1))
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                guard let rows = Self.serviceRows(object, keys: ["entries", "rules", "items", "list"]) else { throw TVDSMError.invalidResponse }
                result.reverseProxyInventoryAvailable = true
                for index in result.services.indices {
                    result.services[index].endpoints = Self.reverseProxyEndpoints(rows, ports: result.services[index].ports, fallbackHost: server.host)
                }
            } catch { try Task.checkCancellation(); result.warnings.append("反向代理查询未完成：" + discoveryError(error)) }
        }
        for index in result.services.indices where result.services[index].isJellyfin && result.services[index].running != false {
            var candidates = result.services[index].endpoints
            // Published ports are candidates, never a claim of public reachability.
            for port in result.services[index].ports.prefix(8) {
                var parts = URLComponents(url: server, resolvingAgainstBaseURL: false)!
                parts.port = port; parts.path = ""; parts.query = nil; parts.fragment = nil
                if let url = parts.url, !candidates.contains(url) { candidates.append(url) }
            }
            for endpoint in candidates.prefix(8) {
                if await refreshed.isJellyfin(endpoint, transport: publicTransport) { result.services[index].verifiedJellyfin = endpoint; break }
                try Task.checkCancellation()
            }
        }
        return result
    }
    private func isJellyfin(_ base: URL, transport: any PublicMediaServiceTransport) async -> Bool {
        let candidate = MediaServiceCandidate(id: "identity", name: "Jellyfin", hint: .jellyfin, running: nil, endpoints: [base])
        guard let result = try? await MediaServiceProbe(transport: transport).inspect(candidate) else { return false }
        return result.identity?.product == .jellyfin
    }
    static func serviceRows(_ object: [String: Any], keys: [String]) -> [[String: Any]]? {
        for key in keys { if let rows = object[key] as? [[String: Any]] { return rows } }
        if let data = object["data"] as? [String: Any] { return serviceRows(data, keys: keys) }
        return nil
    }
    static func string(_ object: [String: Any], _ keys: [String]) -> String? {
        for key in keys {
            if let text = object[key] as? String, !text.isEmpty { return text.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
            if let number = object[key] as? NSNumber { return number.stringValue }
        }
        return nil
    }
    static func running(_ object: [String: Any]) -> Bool? {
        if let running = object["running"] as? Bool { return running }
        guard let value = string(object, ["status", "state", "Status", "State"])?.lowercased() else { return nil }
        if value == "running" || value.hasPrefix("up ") || value == "start" { return true }
        if ["stopped", "exited", "stop", "disabled", "error"].contains(value) || value.hasPrefix("exited ") { return false }
        return nil
    }
    static func publishedPorts(_ value: Any) -> [Int] {
        if let rows = value as? [Any] { return Array(Set(rows.flatMap(publishedPorts))).sorted() }
        guard let object = value as? [String: Any] else { return [] }
        var values: [Int] = []
        for key in ["host_port", "hostPort", "HostPort", "local_port", "localPort", "public_port", "PublicPort", "external_port"] {
            if let port = string(object, [key]).flatMap(Int.init), (1...65535).contains(port) { values.append(port) }
        }
        for (key, value) in object where key.contains("/") || ["ports", "Ports", "port_bindings", "PortBindings", "portBindings", "port_mappings"].contains(key) {
            values += publishedPorts(value)
        }
        return Array(Set(values)).sorted()
    }
    static func containerServices(_ rows: [[String: Any]]) -> [TVDiscoveredService] {
        rows.enumerated().map { index, row in
            let name = string(row, ["name", "Name", "container_name", "containerName", "title", "id"]) ?? "容器 \(index + 1)"
            return TVDiscoveredService(id: "container:" + (string(row, ["id", "Id", "container_id"]) ?? name), name: name,
                detail: string(row, ["image", "Image", "image_name"]) ?? "", kind: "容器", running: running(row), ports: publishedPorts(row))
        }
    }
    static func reverseProxyEndpoints(_ rows: [[String: Any]], ports: [Int], fallbackHost: String?) -> [URL] {
        rows.compactMap { row in
            let source = (row["source"] ?? row["frontend"] ?? row["incoming"]) as? [String: Any] ?? row
            let target = (row["destination"] ?? row["backend"] ?? row["target"]) as? [String: Any] ?? row
            guard let targetPort = string(target, ["port", "destination_port", "dest_port", "target_port", "backend_port"]).flatMap(Int.init),
                  ports.contains(targetPort) else { return nil }
            var parts = URLComponents()
            let scheme = string(source, ["protocol", "scheme", "source_protocol", "frontend_protocol"])?.lowercased()
            parts.scheme = scheme == "https" || scheme == "1" || source["https"] as? Bool == true ? "https" : "http"
            let host = string(source, ["fqdn", "hostname", "host", "source_host", "frontend_host"])
            parts.host = host == nil || host == "*" ? fallbackHost : host
            parts.port = string(source, ["port", "source_port", "listen_port", "frontend_port"]).flatMap(Int.init)
            let path = string(source, ["path", "source_path", "frontend_path"]) ?? ""
            parts.path = path.isEmpty ? "" : "/" + path
            guard let url = parts.url, url.user == nil, url.password == nil, let port = parts.port, (1...65535).contains(port) else { return nil }
            return url
        }
    }
}
private func discoveryError(_ error: Error) -> String {
    (error as? TVDSMError)?.localizedDescription ?? (error as? TVClientError)?.localizedDescription ?? "网络请求失败，请重试。"
}


/// A single measured snapshot feeds both Launchpad and resource details.
/// Missing or unauthorized metrics stay unknown, never a healthy zero.
struct TVNASStatusSnapshot {
    var name = "Synology DSM"
    var model = "—"
    var version = "—"
    var cpu: Double?
    var memory: Double?
    var storage: Double?
    var storageTotal: Double?
    var storageUsed: Double?
    var uptimeMinutes: Int?
    var temperature: Double?
    var reachable = false
    var warnings: [String] = []
    var uptimeText: String {
        guard let minutes = uptimeMinutes else { return "未提供" }
        return minutes >= 1440 ? "\(minutes / 1440) 天 \(minutes % 1440 / 60) 小时" : "\(minutes / 60) 小时 \(minutes % 60) 分钟"
    }
    var capacityText: String {
        guard let storageUsed, let storageTotal else { return "容量未提供" }
        return Self.bytes(storageUsed) + " / " + Self.bytes(storageTotal)
    }
    static func bytes(_ value: Double) -> String {
        guard value.isFinite, value >= 0, value < Double(Int64.max) else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }
    static func number(_ object: [String: Any], _ keys: [String]) -> Double? {
        for key in keys {
            let value = (object[key] as? NSNumber)?.doubleValue ?? (object[key] as? String).flatMap(Double.init)
            if let value, value.isFinite, value >= 0 { return value }
        }
        return nil
    }
    static func uptime(_ value: Any?) -> Int? {
        if let n = value as? NSNumber, n.doubleValue.isFinite, n.doubleValue >= 0, n.doubleValue < Double(Int.max) { return n.intValue / 60 }
        guard let text = value as? String else { return nil }
        if let n = Double(text), n.isFinite, n >= 0, n < Double(Int.max) { return Int(n) / 60 }
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.allSatisfy({ $0 >= 0 && $0 < 10_000_000 }) else { return nil }
        if parts.count == 3 { return parts[0] * 60 + parts[1] }
        if parts.count == 4 { return parts[0] * 1440 + parts[1] * 60 + parts[2] }
        return nil
    }
    mutating func apply(system: [String: Any], utilization: [String: Any]) {
        name = (system["server_name"] ?? system["hostname"]) as? String ?? name
        model = system["model"] as? String ?? model
        version = (system["firmware_ver"] ?? system["version"]) as? String ?? version
        uptimeMinutes = Self.uptime(system["uptime"] ?? system["up_time"])
        temperature = Self.number(system, ["temperature", "temperature_value", "temp"])
        let c = utilization["cpu"] as? [String: Any] ?? [:]
        let loads = ["user_load", "system_load", "other_load"].compactMap { Self.number(c, [$0]) }
        cpu = Self.number(c, ["total_load", "load", "usage"]) ?? (loads.isEmpty ? nil : loads.reduce(0, +))
        memory = Self.number(utilization["memory"] as? [String: Any] ?? [:], ["real_usage", "usage", "memory_usage"])
    }
    mutating func apply(storage object: [String: Any]) {
        let rows = ["volumes", "volume", "volume_list", "volumeList"].compactMap { object[$0] as? [[String: Any]] }.first ?? []
        let capacities = rows.compactMap { row -> (Double, Double)? in
            let size = row["size"] as? [String: Any] ?? row
            guard let total = Self.number(size, ["total", "size_total", "total_size", "total_bytes", "capacity"]), total > 0 else { return nil }
            let used = Self.number(size, ["used", "size_used", "used_size", "used_bytes"])
                ?? Self.number(size, ["free", "size_free", "available"]).map { total - $0 }
            guard let used, used >= 0, used <= total else { return nil }
            return (total, used)
        }
        guard !capacities.isEmpty else { return }
        let total = capacities.reduce(0) { $0 + $1.0 }, used = capacities.reduce(0) { $0 + $1.1 }
        guard total.isFinite, used.isFinite, total > 0 else { return }
        storageTotal = total; storageUsed = used; storage = used / total * 100
    }
}

extension TVDSMClient {
    /// Also works with pre-existing accounts whose saved API catalog is older.
    func readDiscovered(_ api: String, method: String) async throws -> [String: Any] {
        guard let account else { throw TVDSMError.unavailableAPI }
        let data = try await send(request(path: "query.cgi", values: [.init(name: "api", value: "SYNO.API.Info"),
            .init(name: "version", value: "1"), .init(name: "method", value: "query"), .init(name: "query", value: api)]))
        let entries = try JSONDecoder().decode([String: TVDSMAPI].self, from: data)
        guard let entry = entries[api], entry.minVersion <= 1 else { throw TVDSMError.unavailableAPI }
        let refreshed = TVDSMClient(account: TVNASAccount(server: server, user: account.user, sid: account.sid,
            apis: account.apis.merging(entries) { _, new in new }), session: session)
        let reply = try await refreshed.send(refreshed.apiRequest(api, method: method, version: 1))
        guard let object = try JSONSerialization.jsonObject(with: reply) as? [String: Any] else { throw TVDSMError.invalidResponse }
        return object
    }
    func statusSnapshot() async throws -> TVNASStatusSnapshot {
        var result = TVNASStatusSnapshot()
        let system = try await systemInfo(); try Task.checkCancellation(); result.reachable = true
        var utilization: [String: Any] = [:]
        do { utilization = try await systemInfo(utilization: true) }
        catch { try Task.checkCancellation(); result.warnings.append("资源利用率：" + error.localizedDescription) }
        result.apply(system: system, utilization: utilization)
        do { result.apply(storage: try await readDiscovered("SYNO.Storage.CGI.Storage", method: "load_info")) }
        catch { try Task.checkCancellation(); result.warnings.append("存储容量：" + error.localizedDescription) }
        return result
    }
}
