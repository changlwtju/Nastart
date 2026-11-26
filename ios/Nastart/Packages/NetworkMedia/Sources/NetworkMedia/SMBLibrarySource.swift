import Foundation

/// Splits a library path into the share and the path inside it. The first segment
/// of a saved SMB location is always the share.
private func smbLocation(base: [String], path: DAVPath) throws -> (share: String, path: String)? {
  let segments = base + path.encodedSegments.map { $0.removingPercentEncoding ?? $0 }
  guard !segments.contains(where: { $0.contains("\\") || $0.contains(":") || $0.utf8.contains(0) }) else {
    throw SMBReadError.invalidPath
  }
  guard let share = segments.first else { return nil }
  return (share, segments.dropFirst().joined(separator: "/"))
}

private func smbBaseSegments(_ scope: WebDAVScope) -> [String] {
  scope.basePathDisplay.split(separator: "/").map(String.init)
}

/// The library's view of one SMB server. An empty path lists its shares, so choosing
/// a folder starts from the shares the account can see.
public struct SMBLibrarySource: ReadOnlyMetadataSource, ReadOnlyArtworkSource, Sendable {
  private let endpoint: SMBEndpoint
  private let base: [String]

  init(scope: WebDAVScope, credential: WebDAVCredential?) throws {
    endpoint = try SMBEndpoint(scope: scope, credential: credential)
    base = smbBaseSegments(scope)
  }

  private func worker(_ share: String) -> SMBWorker {
    SMBWorkerPool.shared.worker(endpoint: endpoint, share: share)
  }

  public func list(_ directory: DAVPath) async throws -> [RemoteMediaEntry] {
    guard let location = try smbLocation(base: base, path: directory) else {
      let names = try await worker("IPC$").run { try $0.listShares() }
      return names.compactMap { name in
        guard let path = try? DAVPath(name) else { return nil }
        return RemoteMediaEntry(path: path, isDirectory: true, size: nil, modified: nil, etag: nil)
      }
    }
    let entries = try await worker(location.share).run { try $0.list(location.path) }
    return entries.compactMap { entry in
      // A link could lead outside the chosen folder, and a name no library path
      // can represent is left out instead of failing the scan.
      guard !entry.isLink, let path = try? DAVPath(directory.displayPath + "/" + entry.name), path.parent == directory
      else { return nil }
      return RemoteMediaEntry(
        path: path, isDirectory: entry.isDirectory, size: entry.isDirectory ? nil : entry.size,
        modified: String(entry.modified), etag: nil)
    }
  }

  private func read(_ path: DAVPath, maximum: Int) async throws -> Data {
    guard let location = try smbLocation(base: base, path: path), !location.path.isEmpty else {
      throw SMBReadError.invalidPath
    }
    return try await worker(location.share).run { try $0.readFile(location.path, maximum: maximum) }
  }

  public func readNFO(_ path: DAVPath, root: DAVPath) async throws -> Data {
    guard path.isWithin(root), path != root, (path.name as NSString).pathExtension.lowercased() == "nfo" else {
      throw NetworkMediaError.outsideRoot
    }
    return try await read(path, maximum: NFOReader.maxBytes)
  }

  public func readArtwork(_ reference: LocalArtworkReference, root: DAVPath) async throws -> Data {
    guard reference.isValid(root: root) else { throw NetworkMediaError.outsideRoot }
    return try await read(reference.path, maximum: LocalArtworkReference.maximumBytes)
  }
}

/// One indexed video on an SMB share, read over a connection of its own.
public struct SMBMediaResource: NetworkMediaByteReader {
  public let byteCount: Int64
  public let fileName: String
  private let worker: SMBWorker
  private let path: String
  private let modified: String

  init(library: NetworkLibrary, file: RemoteMediaEntry, credential: WebDAVCredential?) throws {
    guard file.isVideo, file.path != library.root, file.path.isWithin(library.root),
      library.files.contains(file), let bytes = file.size, bytes > 0
    else { throw NetworkMediaPlaybackError.staleFile }
    guard let modified = file.modified else { throw NetworkMediaPlaybackError.versionUnavailable }
    let scope = try WebDAVScope(storageAddress: library.address)
    guard scope.isSMB, let location = try smbLocation(base: smbBaseSegments(scope), path: file.path),
      !location.path.isEmpty
    else { throw NetworkMediaPlaybackError.unsupportedSource }
    worker = SMBWorker(endpoint: try SMBEndpoint(scope: scope, credential: credential), share: location.share)
    path = location.path
    byteCount = bytes
    fileName = file.path.name
    self.modified = modified
  }

  public func stream(offset: Int64, count: Int64, deliver: (Data) async throws -> Void) async throws {
    try await stream(offset: offset, count: count, timing: nil, deliver: deliver)
  }

  /// Each delivered chunk is one read on the playback connection. `timing`
  /// hears how long that read waited for the connection and how long it took.
  public func stream(offset: Int64, count: Int64, timing: NetworkMediaReadTimingRecorder?,
                     deliver: (Data) async throws -> Void) async throws {
    guard offset >= 0, count > 0, offset < byteCount, count <= byteCount - offset else {
      throw NetworkMediaPlaybackError.invalidRange
    }
    var position = offset
    let end = offset + count
    let (path, size, modified) = (path, byteCount, modified)
    let observe: (@Sendable (TimeInterval, TimeInterval) -> Void)?
    if let timing {
      observe = { queueWait, work in timing.record(queueWait: queueWait, readTime: work) }
    } else {
      observe = nil
    }
    while position < end {
      try Task.checkCancellation()
      let (start, wanted) = (position, Int(min(end - position, 1 << 20)))
      let data = try await worker.run(timing: observe) {
        try $0.read(path, size: size, modified: modified, offset: start, count: wanted)
      }
      try await deliver(data)
      position += Int64(data.count)
    }
  }
}
