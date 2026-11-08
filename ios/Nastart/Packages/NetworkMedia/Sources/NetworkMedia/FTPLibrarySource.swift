import Foundation

/// The library's view of one FTP endpoint. Paths stay relative to the address's
/// folder, as with WebDAV. One login serves a whole scan, so a large library does
/// not reconnect per directory.
public struct FTPLibrarySource: ReadOnlyMetadataSource, ReadOnlyArtworkSource, Sendable {
  private let holder: FTPSessionHolder
  private let base: FTPPath

  init(scope: WebDAVScope, credential: WebDAVCredential?, anchor: Data? = nil) throws {
    guard let security = scope.ftpSecurity, let host = scope.baseURL.host else {
      throw NetworkMediaError.invalidAddress
    }
    holder = FTPSessionHolder(
      server: try FTPServer(host: host, port: scope.baseURL.port, security: security),
      credential: try FTPCredential(networkCredential: credential), anchor: anchor)
    base = try FTPPath("/" + scope.basePathDisplay)
  }

  fileprivate func remotePath(_ path: DAVPath) throws -> FTPPath {
    let joined = path.encodedSegments.map { $0.removingPercentEncoding ?? $0 }
    return try joined.reduce(base) { try $0.appending(name: $1) }
  }

  public func list(_ directory: DAVPath) async throws -> [RemoteMediaEntry] {
    let remote = try remotePath(directory)
    let listing = try await holder.run { try await $0.listing(remote) }
    return listing.entries.compactMap { entry in
      // A name no library path can represent is left out, not a failed scan.
      guard let path = try? DAVPath(directory.displayPath + "/" + entry.name), path.parent == directory
      else { return nil }
      return RemoteMediaEntry(
        path: path, isDirectory: entry.kind == .directory, size: entry.size, modified: entry.modify,
        etag: entry.unique)
    }
  }

  public func readNFO(_ path: DAVPath, root: DAVPath) async throws -> Data {
    guard path.isWithin(root), path != root,
      (path.name as NSString).pathExtension.lowercased() == "nfo"
    else { throw NetworkMediaError.outsideRoot }
    let remote = try remotePath(path)
    return try await holder.run { try await $0.readFile(remote, maximum: NFOReader.maxBytes) }
  }

  public func readArtwork(_ reference: LocalArtworkReference, root: DAVPath) async throws -> Data {
    guard reference.isValid(root: root) else { throw NetworkMediaError.outsideRoot }
    let remote = try remotePath(reference.path)
    return try await holder.run {
      try await $0.readFile(remote, maximum: LocalArtworkReference.maximumBytes)
    }
  }
}

extension FTPCredential {
  /// FTP's convention for a connection saved without an account.
  init(networkCredential credential: WebDAVCredential?) throws {
    guard let credential, !credential.username.isEmpty else {
      try self.init(username: "anonymous", password: "")
      return
    }
    try self.init(username: credential.username, password: credential.password)
  }
}

/// Serializes operations on the one session and replaces it after a failure. A
/// refused login is not retried here, so it cannot count against an account twice.
private actor FTPSessionHolder {
  private let server: FTPServer
  private let credential: FTPCredential
  private let anchor: Data?
  private var session: FTPControlSession?
  private var tail: Task<Void, Never>?

  init(server: FTPServer, credential: FTPCredential, anchor: Data?) {
    self.server = server
    self.credential = credential
    self.anchor = anchor
  }
  deinit { session?.owned.stop(3) }

  func run<T: Sendable>(_ operation: @escaping @Sendable (FTPControlSession) async throws -> T)
    async throws -> T
  {
    // The control stream carries one exchange at a time.
    let previous = tail
    let work = Task<Result<T, Error>, Never> { [self] in
      await previous?.value
      do { return .success(try await perform(operation)) } catch { return .failure(error) }
    }
    tail = Task { _ = await work.value }
    return try await withTaskCancellationHandler {
      try await work.value.get()
    } onCancel: {
      work.cancel()
    }
  }

  private func perform<T: Sendable>(
    _ operation: @Sendable (FTPControlSession) async throws -> T
  ) async throws -> T {
    try Task.checkCancellation()
    let current: FTPControlSession
    let owned: FTPOwnedConnections
    if let session {
      current = session
      owned = session.owned
    } else {
      owned = FTPOwnedConnections()
      current = FTPControlSession(
        server: server, credential: credential, anchor: anchor, limits: .library, owned: owned)
    }
    let timer = Task {
      try? await Task.sleep(for: .seconds(30))
      if !Task.isCancelled { owned.stop(2) }
    }
    defer { timer.cancel() }
    do {
      return try await withTaskCancellationHandler {
        if session == nil {
          try await current.open()
          session = current
        }
        return try await operation(current)
      } onCancel: {
        owned.stop(1)
      }
    } catch {
      session = nil
      let stopped = FTPOwnedConnections.stoppedError(owned)
      owned.stop(3)
      if let stopped { throw stopped }
      throw error
    }
  }
}

extension FTPOwnedConnections {
  /// Why the connections were stopped, ahead of the socket error that caused.
  fileprivate static func stoppedError(_ owned: FTPOwnedConnections) -> Error? {
    do {
      try owned.check()
      return nil
    } catch { return error }
  }
}

/// One indexed video on an FTP server. Each read is its own login and transfer,
/// which keeps a seek from depending on the state of an abandoned one.
public struct FTPMediaResource: NetworkMediaByteReader {
  public let byteCount: Int64
  public let fileName: String
  private let server: FTPServer
  private let credential: FTPCredential
  private let remote: FTPPath
  private let modified: String?
  private let unique: String?
  private let anchor: Data?

  init(library: NetworkLibrary, file: RemoteMediaEntry, credential: WebDAVCredential?, anchor: Data? = nil) throws {
    guard file.isVideo, file.path != library.root, file.path.isWithin(library.root),
      library.files.contains(file), let bytes = file.size, bytes > 0
    else { throw NetworkMediaPlaybackError.staleFile }
    guard file.modified != nil else { throw NetworkMediaPlaybackError.versionUnavailable }
    let scope = try WebDAVScope(storageAddress: library.address)
    guard let security = scope.ftpSecurity, let host = scope.baseURL.host else {
      throw NetworkMediaPlaybackError.unsupportedSource
    }
    server = try FTPServer(host: host, port: scope.baseURL.port, security: security)
    self.credential = try FTPCredential(networkCredential: credential)
    remote = try file.path.encodedSegments.map { $0.removingPercentEncoding ?? $0 }
      .reduce(try FTPPath("/" + scope.basePathDisplay)) { try $0.appending(name: $1) }
    byteCount = bytes
    fileName = file.path.name
    modified = file.modified
    unique = file.etag
    self.anchor = anchor
  }

  public func stream(offset: Int64, count: Int64, deliver: (Data) async throws -> Void) async throws
  {
    guard offset >= 0, count > 0, offset < byteCount, count <= byteCount - offset else {
      throw NetworkMediaPlaybackError.invalidRange
    }
    let owned = FTPOwnedConnections()
    let activity = FTPReadActivity(timeout: 20)
    let watchdog = Task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        if activity.expired {
          owned.stop(2)
          return
        }
      }
    }
    defer {
      watchdog.cancel()
      owned.stop(3)
    }
    do {
      try await withTaskCancellationHandler {
        let session = FTPControlSession(
          server: server, credential: credential, anchor: anchor, owned: owned)
        try await session.open()
        let current = try await session.metadata(remote)
        guard current.size == byteCount, current.modify == modified,
          unique == nil || current.unique == unique
        else { throw NetworkMediaPlaybackError.staleFile }
        try await session.stream(
          remote, offset: offset, count: count, activity: activity, deliver: deliver)
      } onCancel: {
        owned.stop(1)
      }
    } catch {
      try owned.check()
      throw error
    }
  }
}
