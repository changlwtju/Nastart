#if os(macOS)
import XCTest
@testable import NetworkMedia

/// An owned HTTP peer exercises Foundation authentication, framing and cancel,
/// without reading NAS media or modifying any user account/source.
final class WebDAVMediaHTTPTests: XCTestCase {
    private var process: Process!
    private var directory: URL!
    private var port = 0
    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-u", "-c", #"""
import http.server,pathlib,sys,json,time,re,hashlib
root=pathlib.Path(sys.argv[1])
class Handler(http.server.BaseHTTPRequestHandler):
 protocol_version='HTTP/1.1'
 def log_message(self,*args):pass
 def empty(self,status,headers={}):
  self.send_response(status)
  for k,v in headers.items():self.send_header(k,v)
  self.send_header('Content-Length','0');self.send_header('Connection','close');self.end_headers();self.close_connection=True
 def do_GET(self):
  mode=self.path.split('/')[1]
  with (root/'requests').open('a')as f:f.write(json.dumps({'path':self.path,'range':self.headers.get('Range'),'version':self.headers.get('If-Match'),'date':self.headers.get('If-Unmodified-Since'),'encoding':self.headers.get('Accept-Encoding'),'auth':self.headers.get('Authorization')is not None,'cookie':self.headers.get('Cookie')is not None})+'\n')
  if mode in ['auth','reject-auth']and(self.headers.get('Authorization')!='Basic dGVzdDp0ZXN0'or mode=='reject-auth'):
   return self.empty(401,{'WWW-Authenticate':'Basic realm="fixture"'})
  if mode=='digest':
   auth=self.headers.get('Authorization','')
   fields={k:(v or u)for k,v,u in re.findall(r'(\w+)=(?:"([^"]*)"|([^, ]+))',auth)}
   md5=lambda x:hashlib.md5(x.encode()).hexdigest()
   expected=md5(md5('test:fixture:test')+':0123456789abcdef:'+fields.get('nc','')+':'+fields.get('cnonce','')+':auth:'+md5('GET:'+self.path))
   if not(auth.startswith('Digest ')and fields.get('username')=='test'and fields.get('uri')==self.path and fields.get('nonce')=='0123456789abcdef'and fields.get('qop')=='auth'and fields.get('response')==expected):
    return self.empty(401,{'WWW-Authenticate':'Digest realm="fixture", nonce="0123456789abcdef", algorithm=MD5, qop="auth"'})
  if mode=='redirect':return self.empty(302,{'Location':'/forbidden/video.mp4'})
  if mode=='stale':return self.empty(412)
  if mode=='denied':return self.empty(403)
  if mode=='ignored':return self.empty(200)
  m=re.fullmatch(r'bytes=(\d+)-(\d+)',self.headers.get('Range',''))
  if not m:return self.empty(416)
  start,end=map(int,m.groups());count=end-start+1;total=2097169 if mode in ['bridge','bridge-change']else 65536
  if not(0<=start<=end<total and count<=4194304):return self.empty(416)
  self.send_response(206)
  self.send_header('Content-Range',f'bytes {start+1 if mode=="wrong-start"else start}-{end}/{total+1 if mode=="wrong-size"else total}')
  if mode!='missing-version':self.send_header('ETag','"changed"'if mode=='changed'or(mode=='bridge-change'and start>0)else'"v1"')
  self.send_header('Last-Modified','Tue, 27 Oct 2026 00:00:00 GMT')
  self.send_header('Content-Type','application/json'if mode=='json'else'video/mp4')
  if mode=='encoded':self.send_header('Content-Encoding','gzip')
  if mode not in ['chunked','long-close','short-close']:self.send_header('Content-Length',str(count))
  if mode=='chunked':self.send_header('Transfer-Encoding','chunked')
  self.send_header('Set-Cookie','not-for-next-read=1')
  self.send_header('Connection','close');self.end_headers();self.close_connection=True
  try:
   if mode=='slow':time.sleep(3)
   body=bytes((i%251 for i in range(start,end+1)))
   if mode=='short-close':body=body[:-1]
   if mode=='long-close':body+=b'x'
   if mode=='chunked':self.wfile.write(f'{len(body):x}\r\n'.encode()+body+b'\r\n0\r\n\r\n')
   else:self.wfile.write(body)
  except(BrokenPipeError,ConnectionResetError):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);server.daemon_threads=True
(root/'port').write_text(str(server.server_port));server.serve_forever()
"""#, directory.path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run()
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
    private func resource(_ mode: String, dateVersion: Bool = false) throws -> WebDAVMediaResource {
        var library = NetworkLibrary(name: "fixture", scope: try WebDAVScope(address: "http://127.0.0.1:\(port)/"), root: try DAVPath(mode))
        let file = RemoteMediaEntry(path: try DAVPath(mode + "/video.mp4"), isDirectory: false, size: ["bridge", "bridge-change"].contains(mode) ? 2097169 : 65536,
                                    modified: "Tue, 27 Oct 2026 00:00:00 GMT", etag: dateVersion ? "W/\"weak\"" : "\"v1\"")
        library.files = [file]; return try WebDAVMediaResource(library: library, file: file)
    }
    private func requests() throws -> [[String: Any]] {
        guard let data = try? String(contentsOf: directory.appendingPathComponent("requests")) else { return [] }
        return try data.split(separator: "\n").map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }
    }
    func testFiniteSeekWindowsAndChunkedBodiesUseExactBytesWithoutCookies() async throws {
        for mode in ["ok", "chunked"] {
            let resource = try resource(mode)
            for (offset, count) in [(Int64(0), 16), (32768, 4096), (65520, 16), (7, 20)] {
                let data = try await resource.read(offset: offset, count: count)
                XCTAssertEqual(data, Data((offset..<(offset + Int64(count))).map { UInt8($0 % 251) }))
            }
        }
        let rows = try requests(); XCTAssertEqual(rows.count, 8)
        XCTAssertTrue(rows.allSatisfy { $0["version"] as? String == "\"v1\"" && $0["encoding"] as? String == "identity" && $0["cookie"] as? Bool == false && $0["auth"] as? Bool == false })
        XCTAssertEqual(rows[2]["range"] as? String, "bytes=65520-65535")
        let date = try resource("date", dateVersion: true)
        _ = try await date.read(offset: 0, count: 4)
        XCTAssertEqual(try requests().last?["date"] as? String, "Tue, 27 Oct 2026 00:00:00 GMT")
    }
    func testRealBasicChallengeIsScopedAndRejectedLoginDoesNotLoop() async throws {
        let resource = try resource("auth"), login = WebDAVCredential(username: "test", password: "test")
        do { _ = try await resource.read(offset: 0, count: 4); XCTFail() }
        catch { XCTAssertEqual(error as? NetworkMediaError, .http(401)) }
        let data = try await resource.read(offset: 4, count: 4, credential: login)
        XCTAssertEqual(data, Data([4, 5, 6, 7]))
        let rejected = try self.resource("reject-auth")
        do { _ = try await rejected.read(offset: 0, count: 4, credential: login); XCTFail() }
        catch { XCTAssertEqual(error as? NetworkMediaError, .http(401)) }
        // No ambient credentials from a previous resource/session.
        _ = try await self.resource("ok").read(offset: 0, count: 4)
        let rows = try requests()
        XCTAssertEqual(rows.filter { ($0["path"] as? String)?.contains("reject-auth") == true }.count, 2)
        XCTAssertEqual(rows.last?["auth"] as? Bool, false)
        XCTAssertEqual(rows.first?["auth"] as? Bool, false)
        XCTAssertTrue(rows.contains { $0["auth"] as? Bool == true })
    }
    func testRealDigestChallengeAuthenticatesTheExactRangeResource() async throws {
        let resource = try resource("digest"), login = WebDAVCredential(username: "test", password: "test")
        let first = try await resource.read(offset: 0, count: 4, credential: login)
        let seek = try await resource.read(offset: 32768, count: 4, credential: login)
        XCTAssertEqual(first, Data([0, 1, 2, 3]))
        XCTAssertEqual(seek, Data((32768..<32772).map { UInt8($0 % 251) }))
        let rows = try requests()
        XCTAssertEqual(rows.count, 4); XCTAssertEqual(rows.filter { $0["auth"] as? Bool == true }.count, 2)
        XCTAssertTrue(rows.allSatisfy { $0["version"] as? String == "\"v1\"" && $0["cookie"] as? Bool == false })
    }
    func testRedirectStatusVersionAndRangeFailuresReturnNoMedia() async throws {
        for (mode, expected) in [("redirect", NetworkMediaError.redirect), ("denied", .http(403)), ("ignored", .http(200))] {
            do { _ = try await resource(mode).read(offset: 0, count: 32); XCTFail(mode) }
            catch { XCTAssertEqual(error as? NetworkMediaError, expected, mode) }
        }
        for mode in ["wrong-start", "wrong-size", "changed", "missing-version", "stale", "json", "encoded"] {
            do { _ = try await resource(mode).read(offset: 0, count: 32); XCTFail(mode) }
            catch { XCTAssertTrue(error is NetworkMediaPlaybackError, "\(mode): \(error)") }
        }
        XCTAssertFalse(try requests().contains { ($0["path"] as? String)?.contains("forbidden") == true })
    }
    func testShortAndOversizedBodiesNeverPublishPartialData() async throws {
        for mode in ["short-close", "long-close"] {
            do { _ = try await resource(mode).read(offset: 0, count: 32); XCTFail(mode) }
            catch {
                if mode == "short-close" { XCTAssertEqual(error as? NetworkMediaPlaybackError, .invalidRangeResponse) }
                else { XCTAssertEqual(error as? NetworkMediaError, .responseTooLarge) }
            }
        }
    }
    func testPrecancelAndInFlightCancelStopTheOwnedRead() async throws {
        let reader = try resource("ok")
        let before = try requests().count
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await reader.read(offset: 0, count: 32)
        }
        do { _ = try await cancelled.value; XCTFail() } catch is CancellationError { }
        XCTAssertEqual(try requests().count, before)
        let slow = try resource("slow"), task = Task { try await slow.read(offset: 0, count: 32) }
        for _ in 0..<100 {
            if try requests().contains(where: { ($0["path"] as? String)?.contains("slow") == true }) { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(try requests().contains { ($0["path"] as? String)?.contains("slow") == true })
        let start = Date(); task.cancel()
        do { _ = try await task.value; XCTFail() } catch is CancellationError { }
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }
    func testSequentialWindowsGrowToTheBound() {
        XCTAssertEqual(WebDAVMediaResource.firstReadBytes, 1024 * 1024)
        XCTAssertEqual(WebDAVMediaResource.nextReadBytes(after: 1024 * 1024), 2 * 1024 * 1024)
        XCTAssertEqual(WebDAVMediaResource.nextReadBytes(after: 2 * 1024 * 1024), WebDAVMediaResource.maximumReadBytes)
        XCTAssertEqual(WebDAVMediaResource.nextReadBytes(after: WebDAVMediaResource.maximumReadBytes), WebDAVMediaResource.maximumReadBytes)
    }
    func testLoopbackFullResponseAdvancesFiniteWindowsAndRevokesOnStop() async throws {
        let bridge = WebDAVPlaybackSession(resource: try resource("bridge"), credential: nil)
        defer { bridge.stop() }
        let url = try await bridge.start()
        XCTAssertEqual(url.host, "127.0.0.1"); XCTAssertNil(url.user); XCTAssertNil(url.password); XCTAssertNil(url.query)
        let session = URLSession(configuration: .ephemeral); defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(from: url)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(data.count, 2097169)
        XCTAssertEqual(data, Data((0..<2097169).map { UInt8($0 % 251) }))
        let rows = try requests()
        XCTAssertEqual(rows.compactMap { $0["range"] as? String }, ["bytes=0-1048575", "bytes=1048576-2097168"])
        bridge.stop()
        do { _ = try await bridge.start(); XCTFail() } catch is CancellationError { }
        do { _ = try await session.data(from: url); XCTFail("Revoked URL remained live") } catch { }
    }
    func testLoopbackSeekHeadAndInvalidRequestsDoNotReadOtherFiles() async throws {
        let bridge = WebDAVPlaybackSession(resource: try resource("ok"), credential: nil)
        defer { bridge.stop() }
        let url = try await bridge.start(), session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        var head = URLRequest(url: url); head.httpMethod = "HEAD"
        let (empty, info) = try await session.data(for: head)
        XCTAssertTrue(empty.isEmpty); XCTAssertEqual(info.expectedContentLength, 65536); XCTAssertTrue(try requests().isEmpty)
        for (range, start, count) in [("bytes=20-23", 20, 4), ("bytes=-4", 65532, 4), ("bytes=65532-", 65532, 4)] {
            var request = URLRequest(url: url); request.setValue(range, forHTTPHeaderField: "Range")
            let (data, response) = try await session.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 206)
            XCTAssertEqual(data, Data((start..<(start + count)).map { UInt8($0 % 251) }))
        }
        let before = try requests().count
        for range in ["bytes=65536-", "bytes=1-0", "bytes=0-1,3-4", "bytes=-0", "bytes=9223372036854775808-"] {
            var request = URLRequest(url: url); request.setValue(range, forHTTPHeaderField: "Range")
            let (data, response) = try await session.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 416); XCTAssertTrue(data.isEmpty)
        }
        var wrong = URLComponents(url: url, resolvingAgainstBaseURL: false)!; wrong.path = "/other/video.mp4"
        let (_, denied) = try await session.data(from: wrong.url!)
        XCTAssertEqual((denied as? HTTPURLResponse)?.statusCode, 404)
        var post = URLRequest(url: url); post.httpMethod = "POST"
        let (_, disallowed) = try await session.data(for: post)
        XCTAssertEqual((disallowed as? HTTPURLResponse)?.statusCode, 405)
        XCTAssertEqual(try requests().count, before)
    }
    func testLoopbackRejectsBadUpstreamBeforeSuccessAndCancelsActiveTransfer() async throws {
        let bad = WebDAVPlaybackSession(resource: try resource("changed"), credential: nil)
        defer { bad.stop() }
        let badURL = try await bad.start(), session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: badURL); request.setValue("bytes=0-3", forHTTPHeaderField: "Range")
        let (data, response) = try await session.data(for: request)
        XCTAssertTrue(data.isEmpty); XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 502)
        let slow = WebDAVPlaybackSession(resource: try resource("slow"), credential: nil)
        defer { slow.stop() }
        let slowURL = try await slow.start()
        let task = Task { try await session.data(from: slowURL) }
        for _ in 0..<100 {
            if try requests().contains(where: { ($0["path"] as? String)?.contains("slow") == true }) { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(try requests().contains { ($0["path"] as? String)?.contains("slow") == true })
        slow.stop()
        do { _ = try await task.value; XCTFail("Cancelled bridge delivered media") } catch { }
    }
    func testVersionChangeBetweenWindowsClosesIncompleteBodyInsteadOfReturningEOF() async throws {
        let bridge = WebDAVPlaybackSession(resource: try resource("bridge-change"), credential: nil)
        defer { bridge.stop() }
        let url = try await bridge.start(), session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        do { _ = try await session.data(from: url); XCTFail("Changed version produced a complete response") } catch { }
        // URLSession may retry a disconnected GET. Every attempted second
        // window fails the same version check; no third window is fetched.
        let rows = try requests().compactMap { $0["range"] as? String }
        XCTAssertTrue(rows.contains("bytes=1048576-2097168"))
        XCTAssertEqual(Set(rows), ["bytes=0-1048575", "bytes=1048576-2097168"])
    }
}
#endif
