import XCTest
@testable import NetworkMedia

final class FileStationTests: XCTestCase {
    actor Fixture {
        var requests: [URLRequest] = []
        var total = 501
        var duplicate = false
        var outside = false
        var failNFO = false
        var apiPath = "entry.cgi"
        var revoked = false
        var revokeAfterResponse = false
        func configure(total: Int = 501, duplicate: Bool = false, outside: Bool = false, failNFO: Bool = false, apiPath: String = "entry.cgi", revokeAfterResponse: Bool = false) {
            self.total = total; self.duplicate = duplicate; self.outside = outside; self.failNFO = failNFO
            self.apiPath = apiPath; self.revokeAfterResponse = revokeAfterResponse
        }
        func validate() throws { if revoked { throw NetworkMediaError.fileStationUnavailable } }
        func params(_ request: URLRequest) -> [String: String] {
            let text = String(data: request.httpBody!, encoding: .utf8)!
            return Dictionary(uniqueKeysWithValues: URLComponents(string: "https://example.test/?" + text)!.queryItems!.map { ($0.name, $0.value ?? "") })
        }
        func send(_ request: URLRequest, limit: Int) throws -> Data {
            requests.append(request)
            let p = params(request)
            XCTAssertEqual(request.httpMethod, "POST"); XCTAssertNil(request.url?.query)
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie")); XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let method = p["method"]!
            XCTAssertTrue(["query", "getinfo", "list", "list_share", "download"].contains(method))
            if method != "query" { XCTAssertEqual(p["_sid"], "session+private&value") }
            if revokeAfterResponse { revoked = true }
            func response(_ data: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: ["success": true, "data": data]) }
            if method == "query" { return try response([p["query"]!: ["path": apiPath, "minVersion": 1, "maxVersion": 2]]) }
            if method == "getinfo" {
                let path = (try JSONSerialization.jsonObject(with: Data(p["path"]!.utf8)) as! [String])[0]
                return try response(["files": [["path": path, "isdir": !path.hasSuffix(".nfo"), "additional": ["real_path": "/volume1" + path]]]])
            }
            if method == "download" {
                XCTAssertEqual(p["mode"], "\"open\""); XCTAssertEqual(limit, NFOReader.maxBytes)
                return failNFO ? Data("{\"success\":false,\"error\":{\"code\":119}}".utf8) : Data("<movie><title>本机测试</title></movie>".utf8)
            }
            if method == "list_share" { return try response(["shares": [["path": "/video", "isdir": true]], "total": 1]) }
            let offset = Int(p["offset"]!)!
            let entries: [[String: Any]] = (offset..<min(offset + 500, total)).map { i in
                let name = "电影 \(duplicate && i == 500 ? 0 : i).mkv"
                return ["path": "/video/" + name, "isdir": false, "additional": ["real_path": (outside ? "/other/" : "/volume1/video/") + name, "size": 42, "time": ["mtime": 1234]]]
            }
            return try response(["files": entries, "total": total, "offset": offset])
        }
    }
    func source(_ fixture: Fixture) throws -> FileStationSource {
        try FileStationSource(address: "https://example.test:5001", sid: "session+private&value", validate: { try await fixture.validate() }, transport: { try await fixture.send($0, limit: $1) })
    }
    func testCompletePaginationAndPrivateSessionBody() async throws {
        let fixture = Fixture(), source = try source(fixture)
        let files = try await source.list(DAVPath("video"))
        XCTAssertEqual(files.count, 501); XCTAssertEqual(files.last?.path.name, "电影 500.mkv")
        XCTAssertEqual(files.first?.modified, "1234.0")
        let requests = await fixture.requests
        XCTAssertEqual(requests.count, 4)
    }
    func testSharesAndNFOReadOnlyFlow() async throws {
        let fixture = Fixture(), source = try source(fixture)
        let shares = try await source.list(DAVPath())
        XCTAssertEqual(shares.map(\.path.name), ["video"])
        let data = try await source.readNFO(DAVPath("video/电影.nfo"), root: DAVPath("video"))
        XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("本机测试"))
    }
    func testDuplicatePageAndPhysicalEscapeFailClosed() async throws {
        for outside in [false, true] {
            let fixture = Fixture(); await fixture.configure(duplicate: !outside, outside: outside)
            do { _ = try await source(fixture).list(DAVPath("video")); XCTFail("must reject") } catch { }
        }
    }
    func testUnsafeDiscoveredAPIPathNeverReceivesSID() async throws {
        for path in ["https://evil.test/entry.cgi", "../entry.cgi", "/entry.cgi", "%2e%2e/entry.cgi"] {
            let fixture = Fixture(); await fixture.configure(apiPath: path)
            do { _ = try await source(fixture).list(DAVPath("video")); XCTFail("must reject") } catch { }
            let requests = await fixture.requests; XCTAssertEqual(requests.count, 1)
        }
    }
    func testRevocationRejectsLateResponse() async throws {
        let fixture = Fixture(); await fixture.configure(revokeAfterResponse: true)
        do { _ = try await source(fixture).list(DAVPath()); XCTFail("must reject") } catch { }
        let requests = await fixture.requests; XCTAssertEqual(requests.count, 1)
    }
    func testNFOAPIErrorAndOutsideRootNeverBecomeMetadata() async throws {
        let fixture = Fixture(); await fixture.configure(failNFO: true)
        do { _ = try await source(fixture).readNFO(DAVPath("video/a.nfo"), root: DAVPath("video")); XCTFail("must reject") } catch { }
        let before = await fixture.requests.count
        do { _ = try await source(fixture).readNFO(DAVPath("private/a.nfo"), root: DAVPath("video")); XCTFail("must reject") } catch { }
        let after = await fixture.requests.count; XCTAssertEqual(before, after)
    }
    func testLegacyIndexAndFileStationDurableRecoveryKeepSourceKinds() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let suite = "NetworkMedia-FS-" + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = NetworkLibraryStore(directory: folder, catalog: defaults)
        let library = NetworkLibrary(name: "NAS", scope: try WebDAVScope(address: "https://example.test:5001"), root: try DAVPath("video"), fileStationAccount: "account-a")
        try await store.add(library)
        try FileManager.default.removeItem(at: folder)
        let recovered = try await NetworkLibraryStore(directory: folder, catalog: defaults).libraries()
        XCTAssertEqual(recovered.first?.fileStationAccount, "account-a")
        let webdav = NetworkLibrary(name: "old", scope: try WebDAVScope(address: "https://example.test/dav"), root: try DAVPath())
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(webdav)) as! [String: Any]
        legacy.removeValue(forKey: "fileStationAccount")
        let decoded = try JSONDecoder().decode(NetworkLibrary.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(decoded.fileStationAccount)
    }
}
