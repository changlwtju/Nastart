#if os(macOS)
import XCTest
@testable import NetworkMedia

final class FTPLibrarySourceTests: XCTestCase {
    private var directory: URL!
    private var process: Process?
    private var port = 0
    private let video = (0..<3_000_000).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ ($0 >> 8)) }

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("Nastart-FTPMedia-" + UUID().uuidString)
        let folder = directory.appendingPathComponent("root/电影 100%/盗梦空间")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(video).write(to: folder.appendingPathComponent("Inception.mkv"))
        try Data("<movie><title>盗梦空间</title></movie>".utf8).write(to: folder.appendingPathComponent("Inception.nfo"))
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        let script = try XCTUnwrap(Bundle.module.url(forResource: "ftp_media_fixture", withExtension: "py", subdirectory: "Fixtures"))
        p.arguments = ["-I", "-u", script.path, directory.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        process = p
        for _ in 0..<200 {
            if let raw = try? String(contentsOf: directory.appendingPathComponent("port")), let value = Int(raw) { port = value; return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Fixture did not start")
    }
    override func tearDown() async throws {
        try Data().write(to: directory.appendingPathComponent("stop"))
        for _ in 0..<100 where process?.isRunning == true { try await Task.sleep(for: .milliseconds(20)) }
        if process?.isRunning == true { process?.terminate() }
        try? FileManager.default.removeItem(at: directory)
    }
    private var scope: WebDAVScope { get throws { try WebDAVScope(storageAddress: "ftp://127.0.0.1:\(port)/") } }
    private let credential = WebDAVCredential(username: "fixture", password: "local-only")
    private func commands() throws -> [String] {
        try JSONDecoder().decode([String].self, from: Data(contentsOf: directory.appendingPathComponent("commands.json")))
    }
    private func indexed() async throws -> (library: NetworkLibrary, file: RemoteMediaEntry) {
        var library = NetworkLibrary(name: "FTP", scope: try scope, root: try DAVPath())
        let source = try networkStorageSource(scope: try scope, credential: credential)
        library.files = try await ReadOnlyLibraryScanner.scan(source: source, root: library.root)
        return (library, try XCTUnwrap(library.files.first { $0.path.name == "Inception.mkv" }))
    }

    func testOnlyStorageAddressesMayNameFTP() throws {
        XCTAssertThrowsError(try WebDAVScope(address: "ftp://nas.example/"))
        XCTAssertThrowsError(try WebDAVScope(address: "ftpes://nas.example/"))
        XCTAssertEqual(try WebDAVScope(storageAddress: "ftp://nas.example/").ftpSecurity, .plainFTP)
        XCTAssertEqual(try WebDAVScope(storageAddress: "ftpes://nas.example/").ftpSecurity, .explicitTLS)
        XCTAssertEqual(try WebDAVScope(storageAddress: "ftps://nas.example/").ftpSecurity, .implicitTLS)
        XCTAssertNil(try WebDAVScope(storageAddress: "https://nas.example/").ftpSecurity)
        XCTAssertThrowsError(try WebDAVScope(storageAddress: "afp://nas.example/"))
        XCTAssertTrue(try WebDAVScope(storageAddress: "ftpes://nas.example/").sameOrigin(URL(string: "ftpes://nas.example:21/x")!))
        XCTAssertFalse(try WebDAVScope(storageAddress: "ftpes://nas.example/").sameOrigin(URL(string: "ftp://nas.example:21/x")!))
    }
    func testFieldsKeepTheChosenFTPMode() throws {
        let fields = WebDAVConnectionFields(scheme: .ftpes, host: "nas.example", port: "", path: "/电影")
        let scope = try fields.scope()
        XCTAssertEqual(scope.ftpSecurity, .explicitTLS)
        XCTAssertEqual(scope.basePathDisplay, "电影")
        XCTAssertEqual(try WebDAVConnectionFields(scope: scope).scheme, .ftpes)
    }
    func testScanFindsVideosWhenTheAddressNamesASubfolder() async throws {
        let scope = try WebDAVConnectionFields(scheme: .ftp, host: "127.0.0.1", port: String(port), path: "/电影 100%").scope()
        let source = try networkStorageSource(scope: scope, credential: credential)
        let files = try await ReadOnlyLibraryScanner.scan(source: source, root: try DAVPath())
        XCTAssertEqual(files.map(\.path.displayPath), ["盗梦空间/Inception.mkv"])
    }
    func testScanWorksOnAServerThatRefusesFactSelection() async throws {
        try Data().write(to: directory.appendingPathComponent("synology"))
        let bracketed = directory.appendingPathComponent("root/电影 100%/[碟].Disc [1080p]")
        try FileManager.default.createDirectory(at: bracketed, withIntermediateDirectories: true)
        try Data(video).write(to: bracketed.appendingPathComponent("[片].Bracket.mkv"))
        try Data("<movie><title>括号片</title></movie>".utf8).write(to: bracketed.appendingPathComponent("[片].Bracket.nfo"))
        let (library, file) = try await indexed()
        let bracket = try XCTUnwrap(library.files.first { $0.path.name == "[片].Bracket.mkv" })
        XCTAssertEqual(bracket.metadata?.title, "括号片")
        XCTAssertEqual(file.size, Int64(video.count))
        // Chinese names only arrive as UTF-8 after asking; MLST facts are refused and never selected.
        XCTAssertEqual(try commands().filter { $0 == "OPTS" }.count, 1)
        XCTAssertEqual(file.metadata?.title, "盗梦空间")
    }
    func testScanReadsANamedFolderWithOneLoginAndSkipsLinks() async throws {
        let (library, file) = try await indexed()
        XCTAssertEqual(file.path.displayPath, "电影 100%/盗梦空间/Inception.mkv")
        XCTAssertEqual(file.size, Int64(video.count))
        XCTAssertEqual(library.files.count, 1)
        XCTAssertEqual(file.metadata?.title, "盗梦空间")
        XCTAssertEqual(try commands().filter { $0 == "PASS" }.count, 1)
        XCTAssertFalse(try commands().contains("STOR"))
    }
    func testWrongPasswordIsNotRetried() async throws {
        let source = try networkStorageSource(scope: try scope, credential: WebDAVCredential(username: "fixture", password: "wrong"))
        do { _ = try await source.list(try DAVPath()); XCTFail("Expected refusal") }
        catch { XCTAssertEqual(error as? FTPReadError, .unexpected(530)) }
        XCTAssertEqual(try commands().filter { $0 == "PASS" }.count, 1)
    }
    func testRangeDeliversExactBytesFromOffset() async throws {
        let (library, file) = try await indexed()
        let reader = try networkMediaReader(library: library, file: file, credential: credential)
        var received = Data()
        try await reader.stream(offset: 1_000_000, count: 500_000) { received.append($0) }
        XCTAssertEqual(received, Data(video[1_000_000..<1_500_000]))
        var tail = Data()
        try await reader.stream(offset: Int64(video.count) - 100, count: 100) { tail.append($0) }
        XCTAssertEqual(tail, Data(video.suffix(100)))
    }
    func testChangedFileStopsPlayback() async throws {
        let (library, file) = try await indexed()
        let path = directory.appendingPathComponent("root/电影 100%/盗梦空间/Inception.mkv")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: path.path)
        let reader = try networkMediaReader(library: library, file: file, credential: credential)
        do { try await reader.stream(offset: 0, count: 10) { _ in }; XCTFail("Expected stale file") }
        catch { XCTAssertEqual(error as? NetworkMediaPlaybackError, .staleFile) }
    }
    func testLocalBridgeServesFTPRanges() async throws {
        let (library, file) = try await indexed()
        let bridge = WebDAVPlaybackSession(reader: try networkMediaReader(library: library, file: file, credential: credential))
        let url = try await bridge.start()
        defer { bridge.stop() }
        XCTAssertNoThrow(try NetworkMediaPlaybackSource(library: library, file: file, playbackURL: url, title: "x"))
        var request = URLRequest(url: url)
        request.setValue("bytes=2000000-2000999", forHTTPHeaderField: "Range")
        let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 206)
        XCTAssertEqual(data, Data(video[2_000_000..<2_001_000]))
    }
}
#endif
