import Foundation

public struct WebDAVConnectionFields: Sendable {
    public enum Scheme: String, CaseIterable, Sendable {
        case https, http, ftpes, ftps, ftp, smb
        public var isFTP: Bool { [.ftpes, .ftps, .ftp].contains(self) }
    }
    public var scheme: Scheme
    public var host: String
    public var port: String
    public var path: String
    public init(scheme: Scheme = .https, host: String = "", port: String = "", path: String = "") {
        self.scheme = scheme; self.host = host; self.port = port; self.path = path
    }
    public init(scope: WebDAVScope) throws {
        guard let parts = URLComponents(url: scope.baseURL, resolvingAgainstBaseURL: false),
              let scheme = parts.scheme.flatMap({ Scheme(rawValue: $0.lowercased()) }), let host = parts.host else { throw FieldError.host }
        self.scheme = scheme; self.host = host; port = parts.port.map(String.init) ?? ""
        path = "/" + (try DAVPath(encodedPath: parts.percentEncodedPath)).displayPath
    }
    public func scope() throws -> WebDAVScope {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !host.contains("://"), !host.contains(where: { "/?#@".contains($0) || $0.isWhitespace }) else { throw FieldError.host }
        let value = port.trimmingCharacters(in: .whitespacesAndNewlines)
        let number: Int?
        if value.isEmpty { number = nil }
        else {
            guard value.utf8.allSatisfy({ (48...57).contains($0) }), let parsed = Int(value), (1...65535).contains(parsed) else { throw FieldError.port }
            number = parsed
        }
        var parts = URLComponents()
        if host.contains(":") && host.filter({ $0 == ":" }).count < 2 { throw FieldError.host }
        parts.scheme = scheme.rawValue
        parts.host = host.contains(":") && !host.hasPrefix("[") ? "[" + host + "]" : host
        parts.port = number
        // Doubled and missing slashes are typing slips, not names: no path segment can be empty.
        let segments = path.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "/", omittingEmptySubsequences: true)
        parts.path = "/" + segments.joined(separator: "/") + (path.hasSuffix("/") && !segments.isEmpty ? "/" : "")
        guard let url = parts.url, url.host != nil, url.user == nil, url.password == nil else { throw FieldError.host }
        return try WebDAVScope(storageAddress: url.absoluteString)
    }
    public enum FieldError: Error, LocalizedError {
        case host, port
        public var errorDescription: String? {
            switch self {
            case .host: return networkL("地址栏只填写域名或 IP；协议、端口和路径请在各自栏目填写。")
            case .port: return networkL("端口应为 1–65535 的数字，或留空使用所选协议的默认端口。")
            }
        }
    }
}

/// The one place a saved endpoint's scheme picks the protocol that reads it, so a
/// credential only ever travels over the protocol its connection was saved with.
func networkStorageSource(scope: WebDAVScope, credential: WebDAVCredential?) throws -> any ReadOnlyDirectorySource {
    if scope.ftpSecurity != nil { return try FTPLibrarySource(scope: scope, credential: credential) }
    if scope.isSMB { return try SMBLibrarySource(scope: scope, credential: credential) }
    return WebDAVClient(scope: scope, credential: credential)
}

func networkMediaReader(library: NetworkLibrary, file: RemoteMediaEntry, credential: WebDAVCredential?) throws -> any NetworkMediaByteReader {
    let scope = try WebDAVScope(storageAddress: library.address)
    if scope.ftpSecurity != nil { return try FTPMediaResource(library: library, file: file, credential: credential) }
    if scope.isSMB { return try SMBMediaResource(library: library, file: file, credential: credential) }
    return WebDAVMediaByteReader(resource: try WebDAVMediaResource(library: library, file: file), credential: credential)
}
