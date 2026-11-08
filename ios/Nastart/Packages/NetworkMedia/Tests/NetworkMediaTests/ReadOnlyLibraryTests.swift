import XCTest
@testable import NetworkMedia

final class ReadOnlyLibraryTests: XCTestCase {
    let scope = try! WebDAVScope(address: "https://example.test/dav/")
    func response(_ href: String, directory: Bool = false, status: Int = 200, extra: String = "") -> String {
        "<d:response><d:href>\(href)</d:href><d:propstat><d:prop><d:resourcetype>\(directory ? "<d:collection/>" : "")</d:resourcetype><d:getcontentlength>42</d:getcontentlength></d:prop><d:status>HTTP/1.1 \(status) OK</d:status></d:propstat>\(extra)</d:response>"
    }
    func listing(_ body: String) -> Data { Data("<d:multistatus xmlns:d=\"DAV:\">\(body)</d:multistatus>".utf8) }
    func parse(_ body: String) throws -> [RemoteMediaEntry] { try DAVListingParser.parse(listing(body), scope: scope, requested: DAVPath()) }
    func testNamespacesUnicodeAndOptionalMissingProperties() throws {
        let optional404 = "<d:propstat><d:prop><d:getetag/></d:prop><d:status>HTTP/1.1 404 Missing</d:status></d:propstat>"
        let entries = try parse(response("/dav/", directory: true) + response("/dav/%E7%94%B5%E5%BD%B1%20A.mkv", extra: optional404))
        XCTAssertEqual(entries.first?.path.name, "电影 A.mkv")
        XCTAssertEqual(entries.first?.size, 42)
        XCTAssertTrue(entries.first?.isVideo == true)
        let defaultNamespace = String(data: listing(response("/dav/", directory: true)), encoding: .utf8)!.replacingOccurrences(of: "d:", with: "").replacingOccurrences(of: "xmlns:d", with: "xmlns")
        XCTAssertTrue(try DAVListingParser.parse(Data(defaultNamespace.utf8), scope: scope, requested: DAVPath()).isEmpty)
    }
    func testRejectsOutOfScopeAndEncodedTraversal() throws {
        for href in ["https://evil.test/dav/a.mp4", "/dav-other/a.mp4", "/dav/%2e%2e/a.mp4", "/dav/%252e%252e", "/dav/a%2fb.mp4", "/dav/sub/a.mp4", "../a.mp4", "/dav/a.mp4?token=secret", "/dav/a.mp4#x"] {
            XCTAssertThrowsError(try parse(response("/dav/", directory: true) + response(href)), href)
        }
    }
    func testRejectsIncompleteAndAmbiguousListings() throws {
        for body in ["", response("/dav/a.mp4"), response("/dav/"), response("/dav/", directory: true) + response("/dav/a.mp4", status: 403), response("/dav/", directory: true) + response("/dav/a.mp4") + response("/dav/a.mp4")] {
            XCTAssertThrowsError(try parse(body))
        }
        XCTAssertThrowsError(try DAVListingParser.parse(Data("<!DOCTYPE x [<!ENTITY a SYSTEM 'file:///etc/passwd'>]><x/>".utf8), scope: scope, requested: DAVPath()))
        XCTAssertThrowsError(try DAVListingParser.parse(listing(response("/dav/", directory: true)).dropLast(6), scope: scope, requested: DAVPath()))
        let foreignType = response("/dav/", directory: true).replacingOccurrences(of: "d:resourcetype", with: "x:resourcetype").replacingOccurrences(of: "<d:response>", with: "<d:response xmlns:x=\"other\">")
        XCTAssertThrowsError(try parse(foreignType))
    }
    func testAddressAndPersistedPathValidation() throws {
        for address in ["smb://example.test/share", "https://user:pass@example.test", "https://example.test/dav/../", "https://example.test:0/", "https://example.test/?a=b"] {
            XCTAssertThrowsError(try WebDAVScope(address: address))
        }
        for segment in ["..", "%2e%2e", "a/b", "a%2Fb", "", "a%00b"] {
            let data = try JSONSerialization.data(withJSONObject: ["encodedSegments": [segment]])
            XCTAssertThrowsError(try JSONDecoder().decode(DAVPath.self, from: data))
        }
        let path = try DAVPath("电影 100%/A.mkv")
        XCTAssertEqual(try JSONDecoder().decode(DAVPath.self, from: JSONEncoder().encode(path)), path)
    }
    struct Source: ReadOnlyDirectorySource {
        var entries: [String: [RemoteMediaEntry]]
        var failAt: String? = nil
        func list(_ directory: DAVPath) async throws -> [RemoteMediaEntry] {
            if failAt == directory.key { throw NetworkMediaError.http(403) }
            guard let result = entries[directory.key] else { throw NetworkMediaError.incompleteListing }
            return result
        }
    }
    func entry(_ path: String, dir: Bool = false) throws -> RemoteMediaEntry { RemoteMediaEntry(path: try DAVPath(path), isDirectory: dir) }
    func testRecursiveScanFiltersMediaKeepsDistinctPathsAndBounds() async throws {
        let source = try Source(entries: ["movies": [entry("movies/a", dir: true), entry("movies/b", dir: true), entry("movies/nfo.nfo")], "movies/a": [entry("movies/a/same.MKV")], "movies/b": [entry("movies/b/same.MKV")]])
        let files = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath("movies"))
        XCTAssertEqual(files.count, 2); XCTAssertNotEqual(files[0].id, files[1].id)
        do { _ = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath("movies"), maxDirectories: 1); XCTFail() } catch { XCTAssertEqual(error as? NetworkMediaError, .limitExceeded) }
        let outside = try Source(entries: ["movies": [entry("other/a.mp4")]])
        do { _ = try await ReadOnlyLibraryScanner.scan(source: outside, root: DAVPath("movies")); XCTFail() } catch { XCTAssertEqual(error as? NetworkMediaError, .incompleteListing) }
    }
    func temporaryStore() throws -> (URL, NetworkLibraryStore) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, NetworkLibraryStore(directory: directory))
    }
    func testFailedAndLateScansKeepPreviousSnapshot() async throws {
        let (directory, store) = try temporaryStore(); defer { try? FileManager.default.removeItem(at: directory) }
        let library = NetworkLibrary(name: "movies", scope: scope, root: try DAVPath("movies"))
        try await store.add(library)
        let old = try entry("movies/old.mp4")
        let first = try await store.beginScan(library.id)
        try await store.commit(library.id, token: first, files: [old])
        let bytes = try Data(contentsOf: directory.appendingPathComponent("libraries-v1.json"))
        let source = try Source(entries: ["movies": [entry("movies/sub", dir: true), entry("movies/new.mp4")]], failAt: "movies/sub")
        do { try await store.scan(library, source: source); XCTFail() } catch { }
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("libraries-v1.json")), bytes)
        let stale = try await store.beginScan(library.id)
        let current = try await store.beginScan(library.id)
        do { try await store.commit(library.id, token: stale, files: []); XCTFail() } catch is CancellationError { }
        await store.abort(library.id, token: current)
        let reloaded = try await NetworkLibraryStore(directory: directory).libraries()
        XCTAssertEqual(reloaded.first?.files, [old])
        XCTAssertFalse(String(data: bytes, encoding: .utf8)!.contains("password"))
    }
    func testCancelledScanKeepsPreviousSnapshot() async throws {
        let (directory, store) = try temporaryStore(); defer { try? FileManager.default.removeItem(at: directory) }
        let library = NetworkLibrary(name: "movies", scope: scope, root: try DAVPath())
        try await store.add(library)
        let source = try Source(entries: ["": [entry("a.mp4")]])
        let task = Task { try await store.scan(library, source: source) { _ in withUnsafeCurrentTask { $0?.cancel() } } }
        do { try await task.value; XCTFail() } catch is CancellationError { }
        let saved = try await store.libraries()
        XCTAssertNil(saved.first?.lastCompletedScan); XCTAssertTrue(saved.first?.files.isEmpty == true)
    }
    func testCorruptStoreIsNotSilentlyReplaced() async throws {
        let (directory, store) = try temporaryStore(); defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("libraries-v1.json"), corrupt = Data("bad json".utf8)
        try corrupt.write(to: file)
        do { try await store.add(NetworkLibrary(name: "x", scope: scope, root: DAVPath())); XCTFail() } catch { }
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
    func testRemovingLocalLibraryRejectsLateScan() async throws {
        let (directory, store) = try temporaryStore(); defer { try? FileManager.default.removeItem(at: directory) }
        let library = NetworkLibrary(name: "x", scope: scope, root: try DAVPath())
        try await store.add(library)
        let token = try await store.beginScan(library.id)
        try await store.remove(library.id)
        do { try await store.commit(library.id, token: token, files: []); XCTFail() } catch is CancellationError { }
        let result = try await NetworkLibraryStore(directory: directory).libraries()
        XCTAssertTrue(result.isEmpty)
    }
    actor RecordingTransport: WebDAVTransport {
        var requests: [URLRequest] = []
        let data: Data
        init(data: Data) { self.data = data }
        func propfind(_ request: URLRequest, credential: WebDAVCredential?) async throws -> Data { requests.append(request); return data }
    }
    func testClientOnlySendsDepthOnePropfindWithNamedProperties() async throws {
        let transport = RecordingTransport(data: listing(response("/dav/", directory: true)))
        _ = try await WebDAVClient(scope: scope, transport: transport).list(DAVPath())
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1); XCTAssertEqual(requests[0].httpMethod, "PROPFIND")
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Depth"), "1")
        XCTAssertNil(requests[0].value(forHTTPHeaderField: "Authorization"))
        XCTAssertFalse(String(data: requests[0].httpBody!, encoding: .utf8)!.contains("allprop"))
        var write = requests[0]; write.httpMethod = "PUT"
        do { _ = try await BoundedWebDAVTransport().propfind(write, credential: nil); XCTFail() } catch { }
    }
}
