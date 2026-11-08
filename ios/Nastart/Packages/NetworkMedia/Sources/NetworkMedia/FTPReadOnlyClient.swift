import Foundation
import Network

public enum FTPReadError: Error, LocalizedError, Equatable {
  case invalidInput, unsupportedMode, unsupportedServer, invalidReply, limit, unreachable
  case unexpected(Int)
  case tlsUnverified, peerUnavailable, invalidPassive, deadline, closed
  case sourceChanged, metadataUnavailable, outsideRoot, staleEntry, unsupportedResource
  public var errorDescription: String? {
    switch self {
    case .invalidInput: return networkL("请核对 FTP 地址、端口、账号和目录；地址中不填写协议或登录信息。")
    case .unsupportedMode: return networkL("请选择 FTP、显式 FTPS 或隐式 FTPS，不会自动降低连接安全性。")
    case .unsupportedServer: return networkL("服务器未声明所需的 UTF-8、MLST 和标准目录能力，暂无法建立此媒体库。")
    case .tlsUnverified: return networkL("FTPS 证书未通过校验，请核对连接域名及证书。")
    case .unexpected(530): return networkL("FTP 服务器未接受本次登录，请检查账号及 FTP 服务权限。")
    case .unexpected(550): return networkL("FTP 目录或文件不可读取，请核对路径和读取权限。")
    case .unexpected(let code): return networkL("FTP 服务器拒绝本次操作（响应 \(code)）。")
    case .unreachable: return networkL("无法连接 FTP 服务，请确认服务已开启，并核对地址、端口和所选协议。")
    case .deadline: return networkL("FTP 连接或读取超时。")
    case .outsideRoot, .staleEntry: return networkL("文件不属于本次连接或所选目录，请重新读取目录。")
    case .sourceChanged: return networkL("FTP 文件资料已变化，本次读取未保存。")
    case .metadataUnavailable: return networkL("FTP 文件缺少可核对的大小或修改时间，暂无法读取资料。")
    case .unsupportedResource: return networkL("此读取入口仅支持已列出的 NFO 或已有图片。")
    case .limit: return networkL("FTP 目录或资料超过读取上限，请选择更小的文件夹。")
    case .invalidReply, .peerUnavailable, .invalidPassive, .closed: return networkL("FTP 连接或目录读取未完成。")
    }
  }
}

public enum FTPSecurity: String, Codable, Sendable {
  case explicitTLS, implicitTLS, plainFTP
  public var defaultPort: Int { self == .implicitTLS ? 990 : 21 }
  /// Saved library addresses name the mode, so a connection cannot silently change it.
  static let schemes: Set<String> = ["ftp", "ftpes", "ftps"]
  init?(scheme: String) {
    switch scheme.lowercased() {
    case "ftp": self = .plainFTP
    case "ftpes": self = .explicitTLS
    case "ftps": self = .implicitTLS
    default: return nil
    }
  }
}

/// Only endpoint identity is serializable. Passwords and certificate file paths
/// never belong to a saved source configuration. TLS mode is part of identity.
public struct FTPServer: Codable, Hashable, Sendable {
  public let host: String
  public let port: Int
  public let security: FTPSecurity
  public init(host: String, port: Int? = nil, security: FTPSecurity = .explicitTLS) throws {
    var host = host.trimmingCharacters(in: .whitespacesAndNewlines)
    if host.hasPrefix("["), host.hasSuffix("]") { host = String(host.dropFirst().dropLast()) }
    guard !host.isEmpty, host.utf8.count <= 253, !host.contains("%"),
      !host.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    else { throw FTPReadError.invalidInput }
    if let ip = IPv6Address(host) {
      host = ip.debugDescription
    } else if let ip = IPv4Address(host) {
      host = ip.debugDescription
    } else {
      guard !host.contains(":"), !host.allSatisfy({ $0.isNumber || $0 == "." }) else {
        throw FTPReadError.invalidInput
      }
      let dns = host.hasSuffix(".") ? String(host.dropLast()) : host
      let labels = dns.split(separator: ".", omittingEmptySubsequences: false)
      guard
        labels.allSatisfy({ label in
          !label.isEmpty && label.utf8.count <= 63 && label.first != "-" && label.last != "-"
            && label.utf8.allSatisfy {
              (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0)
                || $0 == 45
            }
        })
      else { throw FTPReadError.invalidInput }
      host = host.lowercased()
    }
    let port = port ?? security.defaultPort
    guard (1...65535).contains(port) else { throw FTPReadError.invalidInput }
    self.host = host
    self.port = port
    self.security = security
  }
  private enum CodingKeys: CodingKey { case host, port, security }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      host: c.decode(String.self, forKey: .host), port: c.decode(Int.self, forKey: .port),
      security: c.decode(FTPSecurity.self, forKey: .security))
  }
}

/// Deliberately not Codable. A host may store this in its own scoped Keychain.
public struct FTPCredential: Sendable {
  let username: String
  let password: String
  public init(username: String, password: String) throws {
    guard !username.isEmpty, username.utf8.count <= 256, password.utf8.count <= 1024,
      ![username, password].contains(where: {
        $0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
      })
    else { throw FTPReadError.invalidInput }
    self.username = username
    self.password = password
  }
}

/// A listed item belongs to this exact client authorization and selected root.
/// It is not a reusable URL and cannot borrow another connection's account.
public struct FTPRemoteEntry: Equatable, Sendable {
  public let path: FTPPath
  public var isDirectory: Bool { version.kind == .directory }
  public var size: Int64? { version.size }
  public var modified: String? { version.modify }
  let authorization: UUID
  let version: FTPListingEntry
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.authorization == rhs.authorization && lhs.path == rhs.path
      && lhs.version.byteEqual(rhs.version)
  }
}

extension FTPListingEntry {
  func byteEqual(_ other: Self) -> Bool {
    name.utf8.elementsEqual(other.name.utf8) && kind == other.kind && size == other.size
      && modify == other.modify && unique == other.unique
  }
}

/// Read-only UTF-8/TVFS client. Containment is lexical, not a physical filesystem
/// snapshot: a server changing aliases without version changes remains a risk.
/// No remote writes, URL redirects or automatic TLS downgrade.
public struct FTPReadOnlyClient: Sendable {
  public let server: FTPServer
  public let root: FTPPath
  private let credential: FTPCredential
  private let authorization: UUID
  private let timeoutMilliseconds: Int
  private let allowsPASV: Bool
  private let testAnchor: Data?
  public init(
    server: FTPServer, credential: FTPCredential, root: FTPPath,
    timeoutMilliseconds: Int = 10_000, allowsPASV: Bool = true
  ) throws {
    try self.init(
      server: server, credential: credential, root: root, timeoutMilliseconds: timeoutMilliseconds,
      allowsPASV: allowsPASV, testAnchor: nil)
  }
  // In-memory trust material is available only to module tests. No source can
  // configure a disk path, disable hostname checks, or trust an arbitrary leaf.
  init(
    server: FTPServer, credential: FTPCredential, root: FTPPath,
    timeoutMilliseconds: Int, allowsPASV: Bool, testAnchor: Data?
  ) throws {
    guard (1...60_000).contains(timeoutMilliseconds) else { throw FTPReadError.invalidInput }
    self.server = server
    self.credential = credential
    self.root = root
    self.timeoutMilliseconds = timeoutMilliseconds
    self.allowsPASV = allowsPASV
    self.authorization = UUID()
    self.testAnchor = testAnchor
  }
  public func list(_ directory: FTPPath) async throws -> [FTPRemoteEntry] {
    guard root.contains(directory) else { throw FTPReadError.outsideRoot }
    let result = try await run(directory: directory, resource: nil)
    return try result.entries.map { entry in
      FTPRemoteEntry(
        path: try directory.appending(name: entry.name), authorization: authorization,
        version: entry)
    }
  }
  public func readNFO(_ entry: FTPRemoteEntry) async throws -> Data {
    try await read(entry, extensions: ["nfo"], maximum: min(NFOReader.maxBytes, 64 * 1024))
  }
  public func readArtwork(_ entry: FTPRemoteEntry) async throws -> Data {
    try await read(
      entry, extensions: ["jpg", "jpeg", "png"], maximum: LocalArtworkReference.maximumBytes)
  }
  private func read(_ entry: FTPRemoteEntry, extensions: Set<String>, maximum: Int) async throws
    -> Data
  {
    guard entry.authorization == authorization else { throw FTPReadError.staleEntry }
    guard root.contains(entry.path), entry.path != root, let parent = entry.path.parent else {
      throw FTPReadError.outsideRoot
    }
    guard !entry.isDirectory,
      extensions.contains((entry.path.name as NSString).pathExtension.lowercased())
    else { throw FTPReadError.unsupportedResource }
    guard let size = entry.size, size >= 0, entry.modified != nil else {
      throw FTPReadError.metadataUnavailable
    }
    guard size <= maximum else { throw FTPReadError.limit }
    let result = try await run(directory: parent, resource: (entry, maximum))
    guard let data = result.data else { throw FTPReadError.invalidReply }
    return data
  }
  private func run(directory: FTPPath, resource: (FTPRemoteEntry, Int)?) async throws -> (
    entries: [FTPListingEntry], data: Data?
  ) {
    let owned = FTPOwnedConnections()
    let timer = Task {
      try? await Task.sleep(for: .milliseconds(timeoutMilliseconds))
      if !Task.isCancelled { owned.stop(2) }
    }
    defer {
      timer.cancel()
      owned.stop(3)
    }
    do {
      return try await withTaskCancellationHandler {
        try Task.checkCancellation()
        let session = FTPControlSession(
          server: server, credential: credential, anchor: testAnchor, allowsPASV: allowsPASV,
          owned: owned)
        try await session.open()
        let listing = try await session.listing(directory)
        var result: Data?
        if let (expected, maximum) = resource {
          guard
            let listed = listing.entries.first(where: {
              $0.name.utf8.elementsEqual(expected.path.name.utf8)
            }), listed.byteEqual(expected.version)
          else { throw FTPReadError.sourceChanged }
          let path = expected.path
          let before = try await session.metadata(path)
          guard FTPMetadataReply.sameVersion(listed, before) else {
            throw FTPReadError.sourceChanged
          }
          let data = try await session.transfer(
            "RETR " + path.commandArgument, maximum: maximum, expectedLength: Int(expected.size!))
          let after = try await session.metadata(path)
          guard FTPMetadataReply.sameVersion(before, after) else {
            throw FTPReadError.sourceChanged
          }
          result = data
        }
        try await session.quit()
        try owned.check()
        try Task.checkCancellation()
        return (listing.entries, result)
      } onCancel: {
        owned.stop(1)
      }
    } catch {
      try owned.check()
      throw error
    }
  }
}

/// Require the server's explicit UTF-8/MLST capability before interpreting
/// non-ASCII names or sending commands that assume TVFS absolute paths.
enum FTPFeatureReply {
  static func validate(_ lines: [String]) throws {
    guard lines.count >= 3, lines.first?.hasPrefix("211-") == true,
      lines.last?.hasPrefix("211 ") == true
    else { throw FTPReadError.unsupportedServer }
    let features = lines.dropFirst().dropLast().map {
      $0.trimmingCharacters(in: .whitespaces).uppercased().split(separator: " ", maxSplits: 1).first
        .map(String.init) ?? ""
    }
    guard features.contains("UTF8"), features.contains("MLST"), features.contains("TVFS") else {
      throw FTPReadError.unsupportedServer
    }
  }
  /// RFC 3659 marks the facts a server already returns with `*`. Selecting them is then
  /// unnecessary, and some servers (Synology DSM) refuse `OPTS MLST` with 501 regardless.
  static func requiredFactsAreActive(_ lines: [String]) -> Bool {
    for line in lines {
      let parts = line.trimmingCharacters(in: .whitespaces).lowercased()
        .split(separator: " ", maxSplits: 1)
      guard parts.count == 2, parts[0] == "mlst" else { continue }
      let facts = Set(parts[1].split(separator: ";").map(String.init))
      return ["type*", "size*", "modify*", "unique*"].allSatisfy(facts.contains)
    }
    return false
  }
}
