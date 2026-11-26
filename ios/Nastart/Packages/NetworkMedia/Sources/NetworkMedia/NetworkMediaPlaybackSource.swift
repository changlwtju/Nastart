import Foundation
import CryptoKit

/// Policy and bookmarks use the separate origin and version identity. The
/// transport carries a scoped capability, never raw credentials.
public struct NetworkMediaPlaybackSource: Sendable {
    public enum Transport: Sendable {
        case reader(any NetworkMediaByteReader)
        case bridge(URL)
    }
    public let transport: Transport
    public var playbackURL: URL? {
        if case .bridge(let url) = transport { return url }
        return nil
    }
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
        try self.init(library: library, file: file, transport: .bridge(playbackURL),
                      title: title, bytes: bytes, origin: scope.baseURL)
    }

    init(library: NetworkLibrary, file: RemoteMediaEntry, credential: WebDAVCredential?, title: String) throws {
        let reader = try networkMediaReader(library: library, file: file, credential: credential)
        try self.init(library: library, file: file, transport: .reader(reader), title: title, bytes: reader.byteCount,
                      origin: WebDAVScope(storageAddress: library.address).baseURL)
    }

    private init(library: NetworkLibrary, file: RemoteMediaEntry, transport: Transport, title: String,
                 bytes: Int64, origin: URL) throws {
        self.transport = transport
        originURL = origin
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
