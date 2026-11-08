import Foundation
#if canImport(Security)
import Security
#endif

/// An existing DSM session, used only for read operations. No password or SID is persisted here.
public struct FileStationSource: ReadOnlyMetadataSource, ReadOnlyArtworkSource {
    private let scope: WebDAVScope
    private let sid: String
    private let validate: @Sendable () async throws -> Void
    private let transport: @Sendable (URLRequest, Int) async throws -> Data
    public init(address: String, sid: String, allowsSelfSignedCertificates: Bool = false,
                validate: @escaping @Sendable () async throws -> Void) throws {
        self.scope = try WebDAVScope(address: address); self.sid = sid
        self.validate = validate
        self.transport = { request, limit in
            let operation = DAVRequestOperation(request: request, credential: nil, limit: limit, status: 200,
                                                allowsSelfSignedCertificates: allowsSelfSignedCertificates)
            return try await withTaskCancellationHandler(operation: { try await operation.run() }, onCancel: { operation.cancel() })
        }
    }
    init(address: String, sid: String, validate: @escaping @Sendable () async throws -> Void = {},
         transport: @escaping @Sendable (URLRequest, Int) async throws -> Data) throws {
        scope = try WebDAVScope(address: address); self.sid = sid
        self.validate = validate; self.transport = transport
    }
    private struct API: Decodable { let path: String; let minVersion: Int; let maxVersion: Int }
    private struct Reply<T: Decodable>: Decodable { let success: Bool; let data: T? }
    private struct Page: Decodable {
        let files: [Entry]?
        let shares: [Entry]?
        let total: Int?
        let offset: Int?
    }
    private struct Entry: Decodable {
        let path: String; let isdir: Bool; let additional: Additional?
        struct Additional: Decodable {
            let size: Int64?; let is_symlink: Bool?; let real_path: String?; let time: Times?
            struct Times: Decodable { let mtime: Double? }
        }
    }
    private func request(path: String, values: [URLQueryItem]) throws -> URLRequest {
        guard !path.isEmpty, !path.contains("%"), !path.contains(":"), !path.contains("?"), !path.contains("#"), !path.contains("\\"),
              path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { throw NetworkMediaError.outsideRoot }
        var request = URLRequest(url: scope.baseURL.appendingPathComponent("webapi").appendingPathComponent(path))
        request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        var form = URLComponents(); form.queryItems = values
        request.httpBody = form.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        return request
    }
    private func send(_ request: URLRequest, limit: Int) async throws -> Data {
        try Task.checkCancellation(); try await validate()
        let data = try await transport(request, limit)
        try Task.checkCancellation(); try await validate()
        guard data.count <= limit else { throw NetworkMediaError.responseTooLarge }
        return data
    }
    private func api(_ name: String) async throws -> API {
        let data = try await send(request(path: "query.cgi", values: [.init(name: "api", value: "SYNO.API.Info"), .init(name: "version", value: "1"), .init(name: "method", value: "query"), .init(name: "query", value: name)]), limit: 128 * 1024)
        let reply = try JSONDecoder().decode(Reply<[String: API]>.self, from: data)
        guard reply.success, let api = reply.data?[name], api.minVersion <= 2, api.maxVersion >= 2 else { throw NetworkMediaError.fileStationUnavailable }
        return api
    }
    private func realPath(_ entry: Entry) throws -> DAVPath {
        guard let raw = entry.additional?.real_path, raw.hasPrefix("/") else { throw NetworkMediaError.incompleteListing }
        return try DAVPath(raw)
    }
    private func info(_ path: DAVPath, api: API) async throws -> Entry {
        let encoded = String(data: try JSONEncoder().encode(["/" + path.displayPath]), encoding: .utf8)!
        let data = try await send(request(path: api.path, values: values("SYNO.FileStation.List", method: "getinfo") + [
            .init(name: "path", value: encoded), .init(name: "additional", value: "[\"real_path\"]")]), limit: 128 * 1024)
        let reply = try JSONDecoder().decode(Reply<Page>.self, from: data)
        guard reply.success, let files = reply.data?.files, files.count == 1, try DAVPath(files[0].path) == path else { throw NetworkMediaError.incompleteListing }
        return files[0]
    }
    private func values(_ name: String, method: String) -> [URLQueryItem] {
        [.init(name: "api", value: name), .init(name: "version", value: "2"), .init(name: "method", value: method), .init(name: "_sid", value: sid)]
    }
    public func list(_ directory: DAVPath) async throws -> [RemoteMediaEntry] {
        let name = "SYNO.FileStation.List", api = try await api(name)
        let root = directory.encodedSegments.isEmpty
        let physicalParent: DAVPath?
        if root { physicalParent = nil }
        else {
            let parent = try await info(directory, api: api)
            guard parent.isdir else { throw NetworkMediaError.incompleteListing }
            physicalParent = try realPath(parent)
        }
        var result: [RemoteMediaEntry] = [], seen = Set<DAVPath>(), expected: Int?
        let pageSize = 500
        while true {
            var items = values(name, method: root ? "list_share" : "list")
            items += [.init(name: "offset", value: String(result.count)), .init(name: "limit", value: String(pageSize)),
                      .init(name: "sort_by", value: "name"), .init(name: "sort_direction", value: "asc"),
                      .init(name: "additional", value: "[\"size\",\"time\",\"real_path\"]")]
            if !root { items.append(.init(name: "folder_path", value: "/" + directory.displayPath)) }
            let data = try await send(request(path: api.path, values: items), limit: 4 * 1024 * 1024)
            let reply = try JSONDecoder().decode(Reply<Page>.self, from: data)
            guard reply.success, let page = reply.data, let entries = root ? page.shares : page.files else { throw NetworkMediaError.fileStationUnavailable }
            guard entries.count <= pageSize, page.offset.map({ $0 == result.count }) ?? true else { throw NetworkMediaError.incompleteListing }
            if let total = page.total {
                guard total >= 0, total <= 100_000, expected.map({ $0 == total }) ?? true else { throw NetworkMediaError.incompleteListing }
                expected = total
            } else if !root { throw NetworkMediaError.incompleteListing }
            for entry in entries {
                guard entry.path.hasPrefix("/"), entry.additional?.is_symlink != true else { throw NetworkMediaError.outsideRoot }
                let path = try DAVPath(entry.path)
                guard path.parent == directory, seen.insert(path).inserted,
                      entry.additional?.size.map({ $0 >= 0 }) ?? true else { throw NetworkMediaError.incompleteListing }
                if let physicalParent {
                    let physical = try realPath(entry)
                    guard physical.parent == physicalParent, physical.name == path.name else { throw NetworkMediaError.outsideRoot }
                }
                let modified = entry.additional?.time?.mtime.flatMap { $0.isFinite && $0 >= 0 ? String($0) : nil }
                result.append(RemoteMediaEntry(path: path, isDirectory: entry.isdir, size: entry.additional?.size, modified: modified))
            }
            guard result.count <= 100_000 else { throw NetworkMediaError.limitExceeded }
            if let expected {
                guard result.count <= expected else { throw NetworkMediaError.incompleteListing }
                if result.count == expected { return result }
                guard !entries.isEmpty else { throw NetworkMediaError.incompleteListing }
            } else {
                // Older share enumeration has no total. A full page is ambiguous, never publish it.
                guard entries.count < pageSize else { throw NetworkMediaError.incompleteListing }
                return result
            }
        }
    }
    public func readNFO(_ path: DAVPath, root: DAVPath) async throws -> Data {
        guard path.isWithin(root), path != root, (path.name as NSString).pathExtension.lowercased() == "nfo" else { throw NetworkMediaError.outsideRoot }
        return try await readSidecar(path, root: root, limit: NFOReader.maxBytes)
    }
    public func readArtwork(_ reference: LocalArtworkReference, root: DAVPath) async throws -> Data {
        guard reference.isValid(root: root) else { throw NetworkMediaError.outsideRoot }
        let data = try await readSidecar(reference.path, root: root, limit: LocalArtworkReference.maximumBytes)
        guard reference.size.map({ $0 == Int64(data.count) }) ?? true else { throw NetworkMediaError.invalidArtwork }
        return data
    }
    private func readSidecar(_ path: DAVPath, root: DAVPath, limit: Int) async throws -> Data {
        let listAPI = try await api("SYNO.FileStation.List")
        let rootInfo = try await info(root, api: listAPI), fileInfo = try await info(path, api: listAPI)
        let physicalRoot = try realPath(rootInfo), physicalFile = try realPath(fileInfo)
        let suffix = path.encodedSegments.dropFirst(root.encodedSegments.count)
        guard rootInfo.isdir, !fileInfo.isdir, fileInfo.additional?.is_symlink != true,
              physicalFile.encodedSegments == physicalRoot.encodedSegments + suffix else { throw NetworkMediaError.outsideRoot }
        let name = "SYNO.FileStation.Download", api = try await api(name)
        let encoded = String(data: try JSONEncoder().encode(["/" + path.displayPath]), encoding: .utf8)!
        let data = try await send(request(path: api.path, values: values(name, method: "download") + [.init(name: "mode", value: "\"open\""), .init(name: "path", value: encoded)]), limit: limit)
        // DSM API errors often use HTTP 200. Do not silently replace good NFO metadata with a filename.
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["success"] != nil { throw NetworkMediaError.fileStationUnavailable }
        return data
    }
}
