import XCTest
@testable import NetworkMedia

final class JellyfinCreditsSourceTests: XCTestCase {
    private let endpoint = URL(string: "https://media.invalid/jellyfin")!
    private var metadata: LocalMediaMetadata { .init(title: "示例电影", kind: .movie, providerIDs: ["tmdb": "123", "imdb": "tt1234567"], origin: .nfo) }
    private func page(ids: [String: String] = ["Tmdb": "123", "Imdb": "tt1234567"], count: Int = 1, type: String = "Movie", itemCount: Int = 1) throws -> Data {
        let item: [String: Any] = ["Id": "movie-1", "Type": type, "ProviderIds": ids, "People": [
            ["Id": "person-1", "Name": "演员甲", "Type": "Actor", "Role": "主角", "PrimaryImageTag": "tag-1"],
            ["Id": "person-1", "Name": "演员甲", "Type": "Director", "PrimaryImageTag": "tag-1"],
            ["Id": "../../outside", "Name": "无图片演员", "Type": "Actor", "PrimaryImageTag": "tag-2"]]]
        return try JSONSerialization.data(withJSONObject: ["Items": Array(repeating: item, count: itemCount), "TotalRecordCount": count])
    }
    private func source(data: Data, status: Int = 200) throws -> JellyfinCreditsSource {
        try JellyfinCreditsSource(endpoint: endpoint, userID: "user-1", token: "fixture-token") { request, limit in
            XCTAssertEqual(request.httpMethod, "GET"); XCTAssertEqual(request.url?.host, "media.invalid")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Emby-Token"), "fixture-token")
            XCTAssertNil(request.httpBody); XCTAssertFalse(request.url!.absoluteString.contains("fixture-token"))
            XCTAssertEqual(limit, 512 * 1024)
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            XCTAssertEqual(query.first { $0.name == "SearchTerm" }?.value, "示例电影")
            XCTAssertNil(query.first { $0.name == "AnyProviderIdEquals" })
            return .init(statusCode: status, data: data)
        }
    }
    func testExactProviderIdentityAndSharedRoleMerge() async throws {
        let source = try source(data: page())
        let people = try await source.people(for: metadata)
        XCTAssertEqual(people.count, 2); XCTAssertEqual(people.first?.role, "导演 · 主角")
        XCTAssertEqual(people.first?.imageID, "person-1"); XCTAssertNil(people.last?.imageID)
    }
    func testTitleOnlyWrongProviderConflictingProviderAndWrongKindCannotMatch() async throws {
        for data in try [page(ids: [:]), page(ids: ["Tmdb": "999"]), page(ids: ["Tmdb": "123", "Imdb": "tt999"]), page(type: "Episode")] {
            let result = try await source(data: data).people(for: metadata); XCTAssertTrue(result.isEmpty)
        }
    }
    func testDuplicateOrIncompleteSearchNeverPublishesPeople() async throws {
        for data in try [page(count: 2), page(count: 2, itemCount: 2), page(count: 0, itemCount: 0)] {
            let result = try await source(data: data).people(for: metadata); XCTAssertTrue(result.isEmpty)
        }
    }
    func testNoIDsInvalidIDsAndEpisodeMakeNoRequest() async throws {
        let source = try JellyfinCreditsSource(endpoint: endpoint, userID: "user", token: "fixture") { _, _ in
            XCTFail("No film identity must not perform an authenticated lookup"); throw CancellationError()
        }
        for value in [LocalMediaMetadata(title: "x", kind: .movie), .init(title: "x", kind: .episode, providerIDs: ["tmdb": "123"]), .init(title: "x", kind: .movie, providerIDs: ["tmdb": "https://outside.invalid"]) ] {
            let people = try await source.people(for: value); XCTAssertTrue(people.isEmpty)
        }
    }
    func testDeniedRedirectOversizedAndCancellationDoNotPublish() async throws {
        for status in [301, 302, 401, 403, 500] {
            do { _ = try await source(data: page(), status: status).people(for: metadata); XCTFail("status") } catch { }
        }
        do { _ = try await source(data: Data(repeating: 0, count: 512 * 1024 + 1)).people(for: metadata); XCTFail("oversized") } catch { }
        let source = try self.source(data: page())
        let task = Task { try await Task.sleep(nanoseconds: 50_000_000); return try await source.people(for: metadata) }; task.cancel()
        do { _ = try await task.value; XCTFail("cancel") } catch { }
    }
    func testArtworkUsesServerItemIDNotExternalURLAndRejectsInvalidPixels() async throws {
        let source = try JellyfinCreditsSource(endpoint: endpoint, userID: "user", token: "fixture") { request, limit in
            XCTAssertEqual(request.url?.host, "media.invalid"); XCTAssertEqual(request.url?.path, "/jellyfin/Items/person-1/Images/Primary")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Emby-Token"), "fixture"); XCTAssertEqual(limit, 2 * 1024 * 1024)
            return .init(statusCode: 200, data: Data("not an image".utf8))
        }
        let absent = try await source.artwork(for: .init(name: "x", role: "", imageID: nil, imageTag: nil)); XCTAssertNil(absent)
        do { _ = try await source.artwork(for: .init(name: "x", role: "", imageID: "person-1", imageTag: "tag-1")); XCTFail("invalid pixels") } catch { }
    }
    func testEndpointCredentialsAndIdentityIsolation() throws {
        for value in ["https://user:secret@media.invalid", "https://media.invalid?api_key=secret", "file:///tmp/image"] {
            XCTAssertThrowsError(try JellyfinCreditsSource(endpoint: URL(string: value)!, userID: "user", token: "fixture"))
        }
        XCTAssertThrowsError(try JellyfinCreditsSource(endpoint: endpoint, userID: "../user", token: "fixture"))
        let a = try JellyfinCreditsSource(endpoint: endpoint, userID: "user", token: "fixture")
        let b = try JellyfinCreditsSource(endpoint: endpoint, userID: "user", token: "rotated")
        XCTAssertNotEqual(a.identity, b.identity)
    }
}

#if os(macOS)
final class JellyfinCreditsHTTPTests: XCTestCase {
    private var process: Process!
    private var directory: URL!
    private var port = 0
    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-u", "-c", #"""
import http.server,pathlib,sys,json,time,base64
root=pathlib.Path(sys.argv[1])
class H(http.server.BaseHTTPRequestHandler):
 def log_message(self,*a):pass
 def do_GET(self):
  mode=self.path.split('/')[1]
  with (root/'requests').open('a')as f:f.write(json.dumps({'path':self.path,'token':self.headers.get('X-Emby-Token'),'cookie':self.headers.get('Cookie'),'auth':self.headers.get('Authorization')})+'\n')
  if mode=='redirect':
   self.send_response(302);self.send_header('Location','/outside');self.end_headers();return
  if mode=='auth':
   self.send_response(401);self.send_header('WWW-Authenticate','Basic realm="fixture"');self.end_headers();return
  if mode=='slow':time.sleep(2)
  self.send_response(200);self.send_header('Set-Cookie','test=must-not-leak')
  if mode=='large-header':self.send_header('Content-Length','600000');self.end_headers();return
  self.end_headers()
  if mode=='large-body':body=b'x'*600000
  elif '/Images/'in self.path:body=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
  else:body=json.dumps({'Items':[{'Id':'movie-1','Type':'Movie','ProviderIds':{'Tmdb':'123'},'People':[{'Id':'person-1','Name':'Actor','Type':'Actor','PrimaryImageTag':'tag-1'}]}],'TotalRecordCount':1}).encode()
  try:self.wfile.write(body)
  except(BrokenPipeError,ConnectionResetError):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),H);server.daemon_threads=True
(root/'port').write_text(str(server.server_port));server.serve_forever()
"""#, directory.path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice; try process.run()
        for _ in 0..<200 {
            if let value = try? String(contentsOf: directory.appendingPathComponent("port")), let port = Int(value) { self.port = port; return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw URLError(.timedOut)
    }
    override func tearDown() async throws {
        if process?.isRunning == true { process.terminate(); process.waitUntilExit() }
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }
    private func source(_ mode: String) throws -> JellyfinCreditsSource {
        try .init(endpoint: URL(string: "http://127.0.0.1:\(port)/\(mode)")!, userID: "user-1", token: "fixture-token")
    }
    private var metadata: LocalMediaMetadata { .init(title: "Example", kind: .movie, providerIDs: ["tmdb": "123"]) }
    private func requests() throws -> [[String: Any]] {
        let text = (try? String(contentsOf: directory.appendingPathComponent("requests"))) ?? ""
        return try text.split(separator: "\n").map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }
    }
    func testActualAuthenticatedMetadataAndPixelsWithoutCookies() async throws {
        let client = try source("ok"); let people = try await client.people(for: metadata)
        let pixels = try await client.artwork(for: XCTUnwrap(people.first)); XCTAssertNotNil(pixels)
        let rows = try requests(); XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy { $0["token"] as? String == "fixture-token" && $0["cookie"] is NSNull && $0["auth"] is NSNull })
    }
    func testRealRedirectAuthenticationAndByteBoundsFailClosed() async throws {
        for mode in ["redirect", "auth", "large-header", "large-body"] {
            do { _ = try await source(mode).people(for: metadata); XCTFail(mode) } catch { }
        }
        let rows = try requests(); XCTAssertEqual(rows.count, 4)
        XCTAssertFalse(rows.contains { ($0["path"] as? String)?.hasPrefix("/outside") == true })
        XCTAssertTrue(rows.allSatisfy { $0["auth"] is NSNull })
    }
    func testRealInFlightCancellationStopsOwnedRead() async throws {
        let client = try source("slow")
        let task = Task { try await client.people(for: metadata) }
        for _ in 0..<100 {
            if !(try requests()).isEmpty { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let start = Date(); task.cancel()
        do { _ = try await task.value; XCTFail("cancel") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }
}
#endif
