#if os(macOS)
import XCTest
@testable import NetworkMedia

/// A real loopback HTTP peer, with no NAS/account dependency and no remote writes.
final class TransportIntegrationTests: XCTestCase {
    private var process: Process!
    private var directory: URL!
    private var port = 0
    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-u", "-c", #"""
import http.server,sys,pathlib,time,json,urllib.parse
root=pathlib.Path(sys.argv[1])
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_POST(self):
  p=urllib.parse.parse_qs(self.rfile.read(int(self.headers.get('Content-Length','0'))).decode())
  with (root/'requests').open('a') as f:f.write(self.command+' '+self.path+' '+p.get('method',[''])[0]+'\n')
  if self.path.startswith('/redirect/'):
   self.send_response(307);self.send_header('Location','/forbidden/');self.end_headers();return
  self.send_response(200);self.end_headers()
  try:
   if self.path.startswith('/slow/'):time.sleep(2)
   if self.path.startswith('/large/'):
    for _ in range(80):self.wfile.write(b'x'*65536)
    return
   if p['method']==['query']:data={p['query'][0]:{'path':'entry.cgi','minVersion':1,'maxVersion':2}}
   else:
    assert p['_sid']==['private+sid&body']
    data={'shares':[{'path':'/video','isdir':True}],'total':1}
   self.wfile.write(json.dumps({'success':True,'data':data}).encode())
  except (BrokenPipeError,ConnectionResetError):pass
 def do_GET(self):
  with (root/'requests').open('a') as f: f.write(self.command+' '+self.path+' -\n')
  if self.path.startswith('/public-'):
   with (root/'public-headers').open('a') as f:f.write(json.dumps({'authorization':self.headers.get('Authorization')is not None,'cookie':self.headers.get('Cookie')is not None,'method':self.command})+'\n')
   if self.path.startswith('/public-auth/'):
    self.send_response(401);self.send_header('WWW-Authenticate','Basic realm="public-probe"');self.end_headers();return
   if self.path.startswith('/public-redirect/'):
    self.send_response(302);self.send_header('Location','/forbidden/');self.end_headers();return
   self.send_response(200);self.end_headers()
   try:
    if self.path.startswith('/public-slow/'):time.sleep(2)
    if self.path.startswith('/public-large/'):
     for _ in range(20):self.wfile.write(b'x'*65536)
    elif self.path.startswith('/public-plex/'):self.wfile.write(b'<MediaContainer machineIdentifier="owned-plex" version="1.40"/>')
    elif self.path.startswith('/public-music/'):self.wfile.write(json.dumps({'subsonic-response':{'status':'failed','version':'1.16.1','type':'navidrome','error':{'code':10}}}).encode())
    elif self.path.startswith('/public-html/'):self.wfile.write(b'<html>sign in</html>')
    else:self.wfile.write(json.dumps({'ProductName':'Emby Server'if self.path.startswith('/public-emby/')else'Jellyfin Server','Id':'owned-server','Version':'1.0'}).encode())
   except (BrokenPipeError,ConnectionResetError):pass
   return
  if self.path.endswith('.jpg'):
   with (root/'image-requests').open('a') as f:f.write(self.command+' '+self.path+' '+str(self.headers.get('If-Match'))+'\n')
   if self.path=='/auth.jpg' and self.headers.get('Authorization')!='Basic dGVzdDp0ZXN0':
    self.send_response(401);self.send_header('WWW-Authenticate','Basic realm="fixture"');self.end_headers();return
   if self.path=='/redirect.jpg':
    self.send_response(302);self.send_header('Location','/forbidden.jpg');self.end_headers();return
   if self.path=='/denied.jpg':self.send_response(403);self.end_headers();return
   self.send_response(200)
   if self.path=='/large-header.jpg':self.send_header('Content-Length',str(3*1024*1024))
   self.end_headers()
   try:
    if self.path=='/slow.jpg':time.sleep(2)
    if self.path.startswith('/large-'):
     for _ in range(48):self.wfile.write(b'x'*65536)
    else:self.wfile.write(b'image-fixture')
   except (BrokenPipeError,ConnectionResetError):pass
   return
  if self.path=='/auth.nfo' and self.headers.get('Authorization')!='Basic dGVzdDp0ZXN0':
   self.send_response(401);self.send_header('WWW-Authenticate','Basic realm="fixture"');self.end_headers();return
  if self.path=='/redirect.nfo':
   self.send_response(302);self.send_header('Location','http://127.0.0.1:'+str(self.server.server_port)+'/forbidden.nfo');self.end_headers();return
  if self.path=='/denied.nfo':self.send_response(403);self.end_headers();return
  self.send_response(200)
  if self.path=='/large-header.nfo':
   self.send_header('Content-Length',str(600*1024));self.end_headers()
   try:self.wfile.write(b'x'*(600*1024))
   except (BrokenPipeError,ConnectionResetError):pass
   return
  self.end_headers()
  try:
   if self.path=='/slow.nfo':time.sleep(2)
   if self.path=='/large-stream.nfo':
    for _ in range(12):self.wfile.write(b'x'*65536)
   else:self.wfile.write(b'<movie><title>Fixture title</title><thumb>http://external.invalid/p.jpg</thumb></movie>')
  except (BrokenPipeError,ConnectionResetError):pass
 def do_PROPFIND(self):
  with (root/'requests').open('a') as f: f.write(self.command+' '+self.path+' '+str(self.headers.get('Depth'))+'\n')
  if self.path=='/auth/' and self.headers.get('Authorization')!='Basic dGVzdDp0ZXN0':
   self.send_response(401);self.send_header('WWW-Authenticate','Basic realm="fixture"');self.end_headers();return
  if self.path=='/redirect/':
   self.send_response(302);self.send_header('Location','/forbidden/');self.end_headers();return
  if self.path=='/denied/': self.send_response(403);self.end_headers();return
  self.send_response(207)
  if self.path=='/large-header/': self.send_header('Content-Length',str(5*1024*1024));self.end_headers();return
  self.end_headers()
  try:
   if self.path=='/slow/': time.sleep(2)
   if self.path=='/large-stream/':
    for _ in range(80): self.wfile.write(b'x'*65536)
   else:
    body='<d:multistatus xmlns:d="DAV:"><d:response><d:href>'+self.path+'</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>'
    self.wfile.write(body.encode())
  except (BrokenPipeError,ConnectionResetError): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
(root/'port').write_text(str(server.server_port))
server.serve_forever()
"""#, directory.path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run()
        for _ in 0..<200 {
            if let string = try? String(contentsOf: directory.appendingPathComponent("port")), let value = Int(string) { port = value; return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw NetworkMediaError.invalidResponse
    }
    override func tearDown() async throws {
        if process?.isRunning == true { process.terminate(); process.waitUntilExit() }
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }
    func testFileStationRealPOSTKeepsSessionOutOfURLAndRejectsRedirect() async throws {
        let source = try FileStationSource(address: "http://127.0.0.1:\(port)/", sid: "private+sid&body", validate: {})
        let shares = try await source.list(DAVPath())
        XCTAssertEqual(shares.map(\.path.name), ["video"])
        let redirected = try FileStationSource(address: "http://127.0.0.1:\(port)/redirect/", sid: "private+sid&body", validate: {})
        do { _ = try await redirected.list(DAVPath()); XCTFail() }
        catch { XCTAssertEqual(error as? NetworkMediaError, .redirect) }
        let log = try String(contentsOf: directory.appendingPathComponent("requests"))
        XCTAssertFalse(log.contains("forbidden")); XCTAssertFalse(log.contains("private")); XCTAssertFalse(log.contains("?"))
        XCTAssertTrue(log.contains("POST /webapi/entry.cgi list_share"))
    }
    func testFileStationRealBodyLimitAndCancellation() async throws {
        let large = try FileStationSource(address: "http://127.0.0.1:\(port)/large/", sid: "private+sid&body", validate: {})
        do { _ = try await large.list(DAVPath()); XCTFail() }
        catch { XCTAssertEqual(error as? NetworkMediaError, .responseTooLarge) }
        let slow = try FileStationSource(address: "http://127.0.0.1:\(port)/slow/", sid: "private+sid&body", validate: {})
        let task = Task { try await slow.list(DAVPath()) }
        try await Task.sleep(nanoseconds: 80_000_000); task.cancel()
        do { _ = try await task.value; XCTFail() } catch is CancellationError { }
    }
    func testPublicMediaIdentityRealHTTPNeverSendsCredentialsAndKeepsProviderDistinct() async throws {
        for (path, hint, expected) in [("jellyfin", MediaServiceProduct.jellyfin, MediaServiceProduct.jellyfin), ("emby", .jellyfin, .emby), ("plex", .plex, .plex), ("music", .navidrome, .navidrome)] {
            let candidate = MediaServiceCandidate(id:path,name:path,hint:hint,running:nil,endpoints:[URL(string:"http://127.0.0.1:\(port)/public-\(path)/")!])
            let value = try await MediaServiceProbe().inspect(candidate)
            XCTAssertEqual(value.identity?.product,expected)
        }
        for path in ["auth", "html", "redirect"] {
            let candidate = MediaServiceCandidate(id:path,name:path,hint:.jellyfin,running:nil,endpoints:[URL(string:"http://127.0.0.1:\(port)/public-\(path)/")!])
            let value = try await MediaServiceProbe().inspect(candidate)
            XCTAssertNil(value.identity)
            if path == "auth" { XCTAssertTrue(value.requiresAuthorization); XCTAssertEqual(value.reachability,.reachable) }
            if path == "redirect" { XCTAssertEqual(value.reachability,.redirect) }
        }
        let headers = try String(contentsOf:directory.appendingPathComponent("public-headers")).split(separator:"\n")
        XCTAssertEqual(headers.count,7)
        for row in headers {
            let value = try JSONSerialization.jsonObject(with:Data(row.utf8)) as! [String:Any]
            XCTAssertEqual(value["authorization"]as?Bool,false);XCTAssertEqual(value["cookie"]as?Bool,false)
        }
        XCTAssertFalse(try String(contentsOf:directory.appendingPathComponent("requests")).contains("forbidden"))
    }
    func testPublicMediaRealHTTPBodyBudgetAndCancellation() async throws {
        let large = MediaServiceCandidate(id:"large",name:"large",hint:.jellyfin,running:nil,endpoints:[URL(string:"http://127.0.0.1:\(port)/public-large/")!])
        let result = try await MediaServiceProbe().inspect(large)
        XCTAssertNil(result.identity)
        let slow = MediaServiceCandidate(id:"slow",name:"slow",hint:.jellyfin,running:nil,endpoints:[URL(string:"http://127.0.0.1:\(port)/public-slow/")!])
        let task = Task { try await MediaServiceProbe().inspect(slow) }
        try await Task.sleep(nanoseconds:80_000_000);task.cancel()
        do { _ = try await task.value;XCTFail() } catch is CancellationError { }
    }
    func testPublicMediaTLSUsesOnlyExactApprovedCertificateWithoutMutatingTrust() async throws {
        let key = directory.appendingPathComponent("owned-key.pem"), pem = directory.appendingPathComponent("owned-cert.pem"), der = directory.appendingPathComponent("owned-cert.der")
        func openssl(_ args: [String]) throws {
            let process = Process();process.executableURL=URL(fileURLWithPath:"/usr/bin/openssl");process.arguments=args
            process.standardOutput=FileHandle.nullDevice;process.standardError=FileHandle.nullDevice
            try process.run();process.waitUntilExit();XCTAssertEqual(process.terminationStatus,0)
        }
        try openssl(["req","-x509","-newkey","rsa:2048","-nodes","-keyout",key.path,"-out",pem.path,"-days","1","-subj","/CN=127.0.0.1"])
        try openssl(["x509","-in",pem.path,"-outform","DER","-out",der.path])
        let peer = Process();peer.executableURL=URL(fileURLWithPath:"/usr/bin/python3")
        peer.arguments=["-u","-c",#"""
import http.server,ssl,sys,pathlib,json
root=pathlib.Path(sys.argv[1])
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  self.send_response(200);self.end_headers();self.wfile.write(json.dumps({'Id':'tls-peer','Version':'1','ProductName':'Jellyfin Server'}).encode())
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain(str(root/'owned-cert.pem'),str(root/'owned-key.pem'));server.socket=ctx.wrap_socket(server.socket,server_side=True)
(root/'tls-port').write_text(str(server.server_port));server.serve_forever()
"""#,directory.path];peer.standardOutput=FileHandle.nullDevice;peer.standardError=FileHandle.nullDevice
        try peer.run();defer { if peer.isRunning { peer.terminate();peer.waitUntilExit() } }
        var port: Int?
        for _ in 0..<200 {
            if let text = try? String(contentsOf:directory.appendingPathComponent("tls-port")), let value=Int(text) { port=value;break }
            try await Task.sleep(nanoseconds:10_000_000)
        }
        let url = URL(string:"https://127.0.0.1:\(try XCTUnwrap(port))/")!
        let candidate = MediaServiceCandidate(id:"tls",name:"tls",hint:.jellyfin,running:nil,endpoints:[url])
        let data = try Data(contentsOf:der)
        let accepted = try await MediaServiceProbe(transport:PublicMediaServiceHTTP(trustedCertificates:[url:data])).inspect(candidate)
        XCTAssertEqual(accepted.identity?.serverID,"tls-peer")
        let rejected = try await MediaServiceProbe(transport:PublicMediaServiceHTTP(trustedCertificates:[url:Data("wrong certificate".utf8)])).inspect(candidate)
        XCTAssertNil(rejected.identity)
        XCTAssertEqual(try Data(contentsOf:der),data)
    }
    private func client(_ path: String, credential: WebDAVCredential? = nil) throws -> WebDAVClient {
        WebDAVClient(scope: try WebDAVScope(address: "http://127.0.0.1:\(port)/\(path)/"), credential: credential)
    }
    func testRealHTTPBasicChallengeAndDepthOne() async throws {
        let entries = try await client("auth", credential: WebDAVCredential(username: "test", password: "test")).list(DAVPath())
        XCTAssertTrue(entries.isEmpty)
        let requests = try String(contentsOf: directory.appendingPathComponent("requests"))
        XCTAssertFalse(requests.isEmpty)
        XCTAssertTrue(requests.split(separator: "\n").allSatisfy { $0 == "PROPFIND /auth/ 1" })
    }
    func testArtworkRealGETAuthenticationVersionAndScope() async throws {
        let client = try client("", credential: .init(username: "test", password: "test"))
        let file = RemoteMediaEntry(path: try DAVPath("auth.jpg"), isDirectory: false, size: 13, etag: "\"image-v1\"")
        let data = try await client.readArtwork(LocalArtworkReference(file), root: DAVPath())
        XCTAssertEqual(data, Data("image-fixture".utf8))
        for path in ["video.mkv", "outside/a.jpg"] {
            do { _ = try await client.readArtwork(LocalArtworkReference(.init(path: DAVPath(path), isDirectory: false)), root: DAVPath("chosen")); XCTFail() } catch { }
        }
        let requests = try String(contentsOf: directory.appendingPathComponent("image-requests"))
        XCTAssertTrue(requests.contains("GET /auth.jpg \"image-v1\"")); XCTAssertFalse(requests.contains("outside")); XCTAssertFalse(requests.contains("video"))
    }
    func testArtworkRealRedirectPermissionByteBoundsAndCancellation() async throws {
        func reference(_ name: String) throws -> LocalArtworkReference { LocalArtworkReference(.init(path: try DAVPath(name + ".jpg"), isDirectory: false)) }
        let client = try client("")
        for name in ["redirect", "denied", "large-header", "large-stream"] {
            do { _ = try await client.readArtwork(reference(name), root: DAVPath()); XCTFail(name) } catch { }
        }
        let task = Task { try await client.readArtwork(reference("slow"), root: DAVPath()) }
        try await Task.sleep(nanoseconds: 100_000_000); task.cancel()
        do { _ = try await task.value; XCTFail() } catch is CancellationError { }
        let requests = try String(contentsOf: directory.appendingPathComponent("image-requests"))
        XCTAssertFalse(requests.contains("forbidden.jpg"))
    }
    func testAuthenticationRejectionWithoutCredentialsIsHTTP401() async throws {
        do { _ = try await client("auth").list(DAVPath()); XCTFail("Authentication must be required") }
        catch { XCTAssertEqual(error as? NetworkMediaError, .http(401)) }
        do { _ = try await nfoClient().readNFO(DAVPath("auth.nfo"), root: DAVPath()); XCTFail("Metadata must require authentication") }
        catch { XCTAssertEqual(error as? NetworkMediaError, .http(401)) }
    }
    func testAuthenticationRejectionAfterWrongCredentialsIsHTTP401() async throws {
        let credential = WebDAVCredential(username: "test", password: "rejected")
        do { _ = try await client("auth", credential: credential).list(DAVPath()); XCTFail("Rejected credentials must fail") }
        catch { XCTAssertEqual(error as? NetworkMediaError, .http(401)) }
        do { _ = try await nfoClient(credential: credential).readNFO(DAVPath("auth.nfo"), root: DAVPath()); XCTFail("Rejected metadata credentials must fail") }
        catch { XCTAssertEqual(error as? NetworkMediaError, .http(401)) }
        let requests = try String(contentsOf: directory.appendingPathComponent("requests"))
        XCTAssertLessThanOrEqual(requests.split(separator: "\n").count, 4, "Do not repeatedly retry rejected credentials")
    }
    func testRedirectIsNeverFollowed() async throws {
        do { _ = try await client("redirect").list(DAVPath()); XCTFail() }
        catch { XCTAssertEqual(error as? NetworkMediaError, .redirect) }
        let requests = try String(contentsOf: directory.appendingPathComponent("requests"))
        XCTAssertEqual(requests, "PROPFIND /redirect/ 1\n")
    }
    func testHTTPPermissionFailure() async throws {
        do { _ = try await client("denied").list(DAVPath()); XCTFail() }
        catch { XCTAssertEqual(error as? NetworkMediaError, .http(403)) }
    }
    func testBoundedBodyWithAndWithoutContentLength() async throws {
        for path in ["large-header", "large-stream"] {
            do { _ = try await client(path).list(DAVPath()); XCTFail(path) }
            catch { XCTAssertEqual(error as? NetworkMediaError, .responseTooLarge, path) }
        }
    }
    func testCancellationStopsOwnedRequest() async throws {
        let source = try client("slow")
        let task = Task { try await source.list(DAVPath()) }
        try await Task.sleep(nanoseconds: 80_000_000)
        task.cancel()
        do { _ = try await task.value; XCTFail() } catch is CancellationError { }
    }
    private func nfoClient(credential: WebDAVCredential? = nil) throws -> WebDAVClient {
        WebDAVClient(scope: try WebDAVScope(address: "http://127.0.0.1:\(port)/"), credential: credential)
    }
    func testRealNFOGETUsesFileURLAndNeverFollowsEmbeddedLinks() async throws {
        let source = try nfoClient(credential: WebDAVCredential(username: "test", password: "test"))
        let path = try DAVPath("auth.nfo")
        let data = try await source.readNFO(path, root: DAVPath())
        let metadata = try NFOReader.parse(data, fallback: .init(title: "x"), path: path)
        XCTAssertEqual(metadata.title, "Fixture title")
        let requests = try String(contentsOf: directory.appendingPathComponent("requests"))
        XCTAssertTrue(requests.split(separator: "\n").allSatisfy { $0 == "GET /auth.nfo -" })
    }
    func testNFOGETRejectsRedirectAndPermissionFailure() async throws {
        let source = try nfoClient()
        for (name, expected) in [("redirect.nfo", NetworkMediaError.redirect), ("denied.nfo", .http(403))] {
            do { _ = try await source.readNFO(DAVPath(name), root: DAVPath()); XCTFail() }
            catch { XCTAssertEqual(error as? NetworkMediaError, expected) }
        }
        let requests = try String(contentsOf: directory.appendingPathComponent("requests"))
        XCTAssertFalse(requests.contains("forbidden"))
    }
    func testNFOGETHasSeparateBoundAndCancellation() async throws {
        let source = try nfoClient()
        for name in ["large-header.nfo", "large-stream.nfo"] {
            do { _ = try await source.readNFO(DAVPath(name), root: DAVPath()); XCTFail() }
            catch { XCTAssertEqual(error as? NetworkMediaError, .responseTooLarge, "\(name): \(type(of: error)) / \((error as NSError).code)") }
        }
        let task = Task { try await source.readNFO(DAVPath("slow.nfo"), root: DAVPath()) }
        try await Task.sleep(nanoseconds: 80_000_000); task.cancel()
        do { _ = try await task.value; XCTFail() } catch is CancellationError { }
    }
    func testNFOClientRejectsVideosAndOutOfRootBeforeRequest() async throws {
        let source = try nfoClient()
        for name in ["Movies/a.mp4", "Other/a.nfo"] {
            do { _ = try await source.readNFO(DAVPath(name), root: DAVPath("Movies")); XCTFail() }
            catch { XCTAssertEqual(error as? NetworkMediaError, .outsideRoot) }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("requests").path))
    }
}
#endif
