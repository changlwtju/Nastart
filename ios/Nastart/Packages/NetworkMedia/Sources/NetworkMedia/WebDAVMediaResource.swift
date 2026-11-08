import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum NetworkMediaPlaybackError: Error, LocalizedError, Equatable {
    case staleFile, versionUnavailable, invalidRange, invalidRangeResponse, unsupportedSource
    public var errorDescription: String? {
        switch self {
        case .staleFile: return networkL("文件已变化，请重新整理此媒体库后播放。")
        case .versionUnavailable: return networkL("服务器未提供可核对的文件版本，请重新整理或使用设备文件入口播放。")
        case .invalidRange: return networkL("播放读取范围无效，请返回后重新播放。")
        case .invalidRangeResponse: return networkL("服务器未返回有效的分段视频，已停止本次读取。")
        case .unsupportedSource: return networkL("此来源暂未接入直接播放。")
        }
    }
}

/// What the local playback bridge needs from any protocol. `deliver` runs in
/// order and only with bytes of the requested range; returning normally means all
/// `count` bytes were delivered.
public protocol NetworkMediaByteReader: Sendable {
    var byteCount: Int64 { get }
    var fileName: String { get }
    func stream(offset: Int64, count: Int64, deliver: (Data) async throws -> Void) async throws
}

/// WebDAV reads stay in bounded windows, each checked against the indexed version.
struct WebDAVMediaByteReader: NetworkMediaByteReader {
    let resource: WebDAVMediaResource
    let credential: WebDAVCredential?
    private let transport = DAVPlaybackTransport()
    init(resource: WebDAVMediaResource, credential: WebDAVCredential?) {
        self.resource = resource; self.credential = credential
    }
    var byteCount: Int64 { resource.byteCount }
    var fileName: String { resource.path.name }
    func stream(offset: Int64, count: Int64, deliver: (Data) async throws -> Void) async throws {
        var position = offset
        let end = offset + count
        var next = WebDAVMediaResource.firstReadBytes
        while position < end {
            try Task.checkCancellation()
            let window = Int(min(Int64(next), end - position))
            try await deliver(try await resource.read(offset: position, count: window, credential: credential, transport: transport))
            position += Int64(window)
            next = WebDAVMediaResource.nextReadBytes(after: next)
        }
    }
}

/// An in-memory capability for one indexed WebDAV video, never a persisted URL
/// or a way to borrow credentials from another NAS/protocol/account.
public struct WebDAVMediaResource: Sendable {
    public static let maximumReadBytes = 4 * 1024 * 1024
    /// A window is delivered only once complete, so small first reads keep seeks and probing quick.
    /// A range that keeps reading is sequential playback, where larger windows cost fewer round trips.
    static let firstReadBytes = 1024 * 1024
    static func nextReadBytes(after current: Int) -> Int { min(current * 2, maximumReadBytes) }
    public let libraryID: UUID
    public let path: DAVPath
    public let byteCount: Int64
    private let scope: WebDAVScope
    private let version: Version

    enum Version: Sendable {
        case etag(String), modified(String)
        var header: (String, String) {
            switch self {
            case .etag(let value): return ("If-Match", value)
            case .modified(let value): return ("If-Unmodified-Since", value)
            }
        }
        func accepts(_ response: HTTPURLResponse) -> Bool {
            switch self {
            case .etag(let value): return response.value(forHTTPHeaderField: "ETag") == value
            case .modified(let value): return response.value(forHTTPHeaderField: "Last-Modified") == value
            }
        }
    }

    public init(library: NetworkLibrary, file: RemoteMediaEntry) throws {
        guard library.fileStationAccount == nil else { throw NetworkMediaPlaybackError.unsupportedSource }
        guard file.isVideo, file.path != library.root, file.path.isWithin(library.root),
              library.files.contains(file), let bytes = file.size, bytes > 0 else { throw NetworkMediaPlaybackError.staleFile }
        scope = try WebDAVScope(address: library.address)
        libraryID = library.id; path = file.path; byteCount = bytes
        if let etag = file.etag, Self.isStrongETag(etag) { version = .etag(etag) }
        else if let modified = file.modified, Self.isHTTPDate(modified) { version = .modified(modified) }
        else { throw NetworkMediaPlaybackError.versionUnavailable }
    }

    /// Every upstream GET is finite. A zero-length or out-of-file read is an
    /// error, and callers must explicitly advance to the next bounded window.
    public func read(offset: Int64, count: Int, credential: WebDAVCredential? = nil) async throws -> Data {
        try await read(offset: offset, count: count, credential: credential, transport: nil)
    }
    func read(offset: Int64, count: Int, credential: WebDAVCredential?, transport: DAVPlaybackTransport?) async throws -> Data {
        try Task.checkCancellation()
        let request = try request(offset: offset, count: count)
        let operation = DAVRequestOperation(request: request, credential: credential,
            limit: count, status: 206, exactBodyLength: count, transport: transport, validateResponse: { response in
                try validate(response, offset: offset, count: count)
            })
        do {
            let data = try await withTaskCancellationHandler(operation: { try await operation.run() }, onCancel: { operation.cancel() })
            try Task.checkCancellation()
            return data
        } catch NetworkMediaError.http(412) { throw NetworkMediaPlaybackError.staleFile }
    }

    func request(offset: Int64, count: Int) throws -> URLRequest {
        guard offset >= 0, count > 0, count <= Self.maximumReadBytes, offset < byteCount,
              Int64(count) <= byteCount - offset else { throw NetworkMediaPlaybackError.invalidRange }
        var request = URLRequest(url: scope.fileURL(path), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "GET"
        request.setValue("bytes=\(offset)-\(offset + Int64(count) - 1)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let (key, value) = version.header
        request.setValue(value, forHTTPHeaderField: key)
        return request
    }

    func validate(_ response: HTTPURLResponse, offset: Int64, count: Int) throws {
        guard response.url == scope.fileURL(path), response.statusCode == 206,
              let range = response.value(forHTTPHeaderField: "Content-Range"),
              range == "bytes \(offset)-\(offset + Int64(count) - 1)/\(byteCount)",
              response.value(forHTTPHeaderField: "Content-Encoding").map({ $0.lowercased() == "identity" }) ?? true,
              response.value(forHTTPHeaderField: "Content-Type").map({ value in
                  let type = value.lowercased().split(separator: ";", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) ?? ""
                  return !type.hasPrefix("multipart/") && !["text/html", "application/json", "application/xml", "text/xml"].contains(type)
              }) ?? true
        else { throw NetworkMediaPlaybackError.invalidRangeResponse }
        // A missing Content-Length is legal for a chunked 206; the completed
        // body must still match exactly. Never accept a conflicting length.
        if let value = response.value(forHTTPHeaderField: "Content-Length") {
            guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }), Int(value) == count else {
                throw NetworkMediaPlaybackError.invalidRangeResponse
            }
        }
        guard version.accepts(response) else { throw NetworkMediaPlaybackError.staleFile }
    }

    private static func isStrongETag(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard (2...1024).contains(bytes.count), bytes.first == 34, bytes.last == 34 else { return false }
        return bytes.dropFirst().dropLast().allSatisfy { $0 == 33 || (35...126).contains($0) || $0 >= 128 }
    }
    private static func isHTTPDate(_ value: String) -> Bool {
        guard value.utf8.count == 29 else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"; formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }
}
