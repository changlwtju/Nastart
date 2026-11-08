import Foundation

public enum NetworkMediaError: Error, LocalizedError, Equatable {
    case invalidAddress, outsideRoot, invalidResponse, incompleteListing, responseTooLarge, limitExceeded
    case fileStationUnavailable, invalidArtwork
    case http(Int), redirect, localStore, invalidMetadata, invalidCorrection, staleCorrection, correctionLimit
    public var errorDescription: String? {
        switch self {
        case .invalidArtwork: return networkL("已有海报无法读取或图片格式不受支持，影片资料仍保留。")
        case .fileStationUnavailable: return networkL("File Station 会话不可用或没有读取权限，请返回 NAS 检查连接。")
        case .invalidAddress: return networkL("请输入完整的 WebDAV 地址；用户名和密码请分别填写。")
        case .outsideRoot: return networkL("服务器返回了所选目录以外或无法安全识别的路径，本次扫描未保存。")
        case .invalidResponse: return networkL("服务器返回的内容不是有效的 WebDAV 目录。")
        case .incompleteListing: return networkL("目录信息不完整，本次扫描未保存。")
        case .responseTooLarge, .limitExceeded: return networkL("目录内容超过本次扫描上限，请选择更小的文件夹。")
        case .http(let status):
            switch status {
            case 401: return networkL("服务器未接受 WebDAV 账号或密码（HTTP 401）。请核对后重试；已保存的连接可在“连接管理”中更新密码。")
            case 403: return networkL("服务器拒绝读取该目录（HTTP 403），请检查 WebDAV 应用和文件夹的读取权限。")
            case 404: return networkL("WebDAV 地址或目录不存在（HTTP 404），请核对协议、端口和路径。")
            case 405: return networkL("该地址不支持目录读取（HTTP 405），请确认使用 WebDAV 服务地址。")
            default: return networkL("读取目录失败（HTTP \(status)）。")
            }
        case .redirect: return networkL("服务器要求跳转，请使用最终的 WebDAV 地址重新连接。")
        case .localStore: return networkL("无法读取或保存本机媒体库，原数据未被覆盖。")
        case .invalidMetadata: return networkL("资料文件无法识别，已保留文件名识别结果。")
        case .invalidCorrection: return networkL("请填写片名和有效年份；剧集需填写季数和集数，结束集不能早于开始集。")
        case .staleCorrection: return networkL("文件资料已更新，请重新打开后核对。原修改仍保留。")
        case .correctionLimit: return networkL("本机修改已达到保存上限。原修改仍保留，可先恢复不再需要的修改。")
        }
    }
}

/// Identity uses once-decoded, canonically percent-encoded segments. Never a file-system path.
public struct DAVPath: Codable, Hashable, Sendable {
    public let encodedSegments: [String]
    public init(_ displayPath: String = "") throws {
        try self.init(rawSegments: displayPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init), decode: false)
    }
    init(encodedPath: String) throws {
        try self.init(rawSegments: encodedPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init), decode: true)
    }
    private init(rawSegments: [String], decode: Bool) throws {
        var result: [String] = []
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        for raw in rawSegments {
            guard let value = decode ? raw.removingPercentEncoding : raw else { throw NetworkMediaError.outsideRoot }
            var check = value
            // Reject encoded separators/traversal even if a server decodes again.
            for _ in 0..<8 {
                guard ![".", ".."].contains(check), !check.contains("/"), !check.contains("\\"),
                      !check.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw NetworkMediaError.outsideRoot }
                guard let next = check.removingPercentEncoding, next != check else { break }
                check = next
            }
            guard ![".", ".."].contains(check), !check.contains("/"), !check.contains("\\"),
                  !check.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  check.removingPercentEncoding.map({ $0 == check }) ?? true else { throw NetworkMediaError.outsideRoot }
            guard let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) else { throw NetworkMediaError.outsideRoot }
            result.append(encoded)
        }
        encodedSegments = result
    }
    public var displayPath: String { encodedSegments.map { $0.removingPercentEncoding ?? $0 }.joined(separator: "/") }
    public var name: String { encodedSegments.last?.removingPercentEncoding ?? "" }
    public var parent: DAVPath? { encodedSegments.isEmpty ? nil : DAVPath(validated: Array(encodedSegments.dropLast())) }
    public var key: String { encodedSegments.joined(separator: "/") }
    init(validated: [String]) { encodedSegments = validated }
    func isWithin(_ root: DAVPath) -> Bool { encodedSegments.starts(with: root.encodedSegments) }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self).decode([String].self, forKey: .encodedSegments)
        guard values.allSatisfy({ !$0.isEmpty && !$0.contains("/") }) else { throw NetworkMediaError.outsideRoot }
        let checked = try DAVPath(encodedPath: values.joined(separator: "/"))
        guard checked.encodedSegments == values else { throw NetworkMediaError.outsideRoot }
        self = checked
    }
}

public struct WebDAVScope: Sendable {
    public let baseURL: URL
    private let basePath: DAVPath
    /// HTTP(S) only. Service discovery, File Station and WebDAV reads use this, so
    /// they can never be pointed at another protocol.
    public init(address: String) throws { try self.init(address: address, schemes: Self.httpSchemes) }
    /// A saved network-library endpoint, which may also name the FTP family.
    public init(storageAddress: String) throws {
        try self.init(address: storageAddress, schemes: Self.httpSchemes.union(FTPSecurity.schemes).union(["smb"]))
    }
    private static let httpSchemes: Set<String> = ["http", "https"]
    private init(address: String, schemes: Set<String>) throws {
        guard var parts = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              schemes.contains(parts.scheme?.lowercased() ?? ""), let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.port.map({ (1...65535).contains($0) }) ?? true else { throw NetworkMediaError.invalidAddress }
        basePath = try DAVPath(encodedPath: parts.percentEncodedPath)
        parts.percentEncodedPath = "/" + basePath.key + (basePath.key.isEmpty ? "" : "/")
        guard let url = parts.url else { throw NetworkMediaError.invalidAddress }
        baseURL = url
    }
    /// Pure comparison of this scope with an already-saved address string. Only the case of the
    /// http/https scheme is ignored; host, port, path case, trailing slash and encoding stay literal.
    /// An invalid saved address is never "the same".
    func isSameAddress(as saved: String) -> Bool {
        guard (try? WebDAVScope(storageAddress: saved)) != nil,
              let lhs = Self.lowercasingScheme(baseURL.absoluteString),
              let rhs = Self.lowercasingScheme(saved) else { return false }
        return lhs == rhs
    }
    private static func lowercasingScheme(_ text: String) -> String? {
        guard let colon = text.firstIndex(of: ":") else { return nil }
        let scheme = text[..<colon].lowercased()
        guard httpSchemes.union(FTPSecurity.schemes).union(["smb"]).contains(scheme) else { return nil }
        return scheme + String(text[colon...])
    }
    public func directoryURL(_ path: DAVPath) -> URL {
        var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        parts.percentEncodedPath = "/" + (basePath.encodedSegments + path.encodedSegments).joined(separator: "/")
        if !parts.percentEncodedPath.hasSuffix("/") { parts.percentEncodedPath += "/" }
        return parts.url!
    }
    /// The folder an FTP library is rooted at, as named in the address.
    var basePathDisplay: String { basePath.displayPath }
    var ftpSecurity: FTPSecurity? { baseURL.scheme.flatMap { FTPSecurity(scheme: $0) } }
    var isSMB: Bool { baseURL.scheme?.lowercased() == "smb" }
    func fileURL(_ path: DAVPath) -> URL {
        var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        parts.percentEncodedPath = "/" + (basePath.encodedSegments + path.encodedSegments).joined(separator: "/")
        return parts.url!
    }
    func sameOrigin(_ url: URL) -> Bool {
        func port(_ url: URL) -> Int {
            if let port = url.port { return port }
            if let security = url.scheme.flatMap({ FTPSecurity(scheme: $0) }) { return security.defaultPort }
            if url.scheme?.lowercased() == "smb" { return 445 }
            return url.scheme?.lowercased() == "https" ? 443 : 80
        }
        return url.scheme?.lowercased() == baseURL.scheme?.lowercased() && url.host?.lowercased() == baseURL.host?.lowercased() && port(url) == port(baseURL)
    }
    func resolve(href: String, requested: DAVPath) throws -> DAVPath {
        guard let parts = URLComponents(string: href), parts.query == nil, parts.fragment == nil,
              parts.user == nil, parts.password == nil else { throw NetworkMediaError.outsideRoot }
        _ = try DAVPath(encodedPath: parts.percentEncodedPath) // before URL resolves dot segments
        guard let url = URL(string: href, relativeTo: directoryURL(requested))?.absoluteURL, sameOrigin(url) else { throw NetworkMediaError.outsideRoot }
        let absolute = try DAVPath(encodedPath: URLComponents(url: url, resolvingAgainstBaseURL: false)!.percentEncodedPath)
        guard absolute.isWithin(basePath) else { throw NetworkMediaError.outsideRoot }
        let relative = DAVPath(validated: Array(absolute.encodedSegments.dropFirst(basePath.encodedSegments.count)))
        guard relative.isWithin(requested), relative.encodedSegments.count <= requested.encodedSegments.count + 1 else { throw NetworkMediaError.outsideRoot }
        return relative
    }
}

public struct WebDAVCredential: Sendable {
    let username: String
    let password: String
    public init(username: String, password: String) { self.username = username; self.password = password }
}

public struct RemoteMediaEntry: Codable, Equatable, Identifiable, Sendable {
    public let path: DAVPath
    public let isDirectory: Bool
    public let size: Int64?
    public let modified: String?
    public let etag: String?
    public var metadata: LocalMediaMetadata?
    public var id: String { path.key }
    public var isVideo: Bool { !isDirectory && ["mkv", "mp4", "mov", "m4v", "avi", "ts", "m2ts", "webm", "wmv", "mpg", "mpeg", "iso"].contains((path.name as NSString).pathExtension.lowercased()) }
    public init(path: DAVPath, isDirectory: Bool, size: Int64? = nil, modified: String? = nil, etag: String? = nil, metadata: LocalMediaMetadata? = nil) {
        self.path = path; self.isDirectory = isDirectory; self.size = size; self.modified = modified; self.etag = etag
        self.metadata = metadata
    }
}

public protocol ReadOnlyDirectorySource: Sendable {
    func list(_ directory: DAVPath) async throws -> [RemoteMediaEntry]
}

public protocol ReadOnlyMetadataSource: ReadOnlyDirectorySource {
    /// Only a listed NFO sibling inside the user-selected root may be read.
    func readNFO(_ path: DAVPath, root: DAVPath) async throws -> Data
}
