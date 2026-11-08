import Foundation
import CryptoKit

/// The decoder receives a revocable loopback capability. Policy and bookmarks
/// receive the source's separate origin and version identity, never credentials.
public struct NetworkMediaPlaybackSource: Sendable {
    public let playbackURL: URL
    public let originURL: URL
    public let title: String
    public let byteCount: Int64
    public let fileExtension: String
    public let stableID: String
    /// Ignore a saved position for this one playback. The saved position is overwritten as it plays.
    public var startsFromBeginning = false

    init(library: NetworkLibrary, file: RemoteMediaEntry, playbackURL: URL, title: String) throws {
        guard playbackURL.scheme == "http", playbackURL.host == "127.0.0.1",
              playbackURL.port != nil, playbackURL.user == nil, playbackURL.password == nil,
              playbackURL.query == nil, playbackURL.fragment == nil else {
            throw NetworkMediaPlaybackError.unsupportedSource
        }
        let scope = try WebDAVScope(storageAddress: library.address)
        // The source's credential stays with the bridge; this only checks the file.
        let bytes: Int64
        if scope.ftpSecurity != nil { bytes = try FTPMediaResource(library: library, file: file, credential: nil).byteCount }
        else if scope.isSMB { bytes = try SMBMediaResource(library: library, file: file, credential: nil).byteCount }
        else { bytes = try WebDAVMediaResource(library: library, file: file).byteCount }
        self.playbackURL = playbackURL
        originURL = scope.baseURL
        self.title = title; byteCount = bytes
        fileExtension = (file.path.name as NSString).pathExtension.lowercased()
        stableID = try Self.stableID(library: library, file: file, byteCount: bytes)
    }
    static func stableID(library: NetworkLibrary, file: RemoteMediaEntry, byteCount: Int64) throws -> String {
        let identity = [library.id.uuidString, file.path.key, String(byteCount),
            file.etag ?? "", file.modified ?? ""]
        return SHA256.hash(data: try JSONEncoder().encode(identity)).map { String(format: "%02x", $0) }.joined()
    }
}
