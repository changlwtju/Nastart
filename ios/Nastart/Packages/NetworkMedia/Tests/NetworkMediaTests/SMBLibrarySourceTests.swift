#if os(macOS)
import XCTest
@testable import NetworkMedia

final class SMBParsingTests: XCTestCase {
  func testAddressesAndFields() throws {
    XCTAssertTrue(try WebDAVScope(storageAddress: "smb://nas.example/video/").isSMB)
    XCTAssertThrowsError(try WebDAVScope(address: "smb://nas.example/"))
    XCTAssertTrue(try WebDAVScope(storageAddress: "smb://nas.example/").sameOrigin(URL(string: "smb://nas.example:445/x")!))
    let fields = try WebDAVConnectionFields(scope: WebDAVScope(storageAddress: "smb://nas.example:1445/video/"))
    XCTAssertEqual(fields.scheme, .smb)
    XCTAssertEqual(fields.port, "1445")
    XCTAssertEqual(fields.path, "/video")
  }
  func testDomainAccounts() throws {
    let scope = try WebDAVScope(storageAddress: "smb://nas.example/")
    let endpoint = try SMBEndpoint(scope: scope, credential: WebDAVCredential(username: "HOME\\me", password: "x"))
    XCTAssertEqual(endpoint.domain, "HOME")
    XCTAssertEqual(endpoint.username, "me")
    XCTAssertEqual(endpoint.port, 445)
  }
  private func record(name: String, next: UInt32 = 0, attributes: UInt32 = 0x20, size: UInt64 = 5, nameSize: UInt32? = nil) -> Data {
    let encoded = name.data(using: .utf16LittleEndian)!
    var bytes = [UInt8](repeating: 0, count: 64)
    func put<T: FixedWidthInteger>(_ value: T, _ at: Int) {
      withUnsafeBytes(of: value.littleEndian) { bytes.replaceSubrange(at..<(at + $0.count), with: $0) }
    }
    put(next, 0); put(size, 40); put(UInt64(99), 24); put(attributes, 56); put(nameSize ?? UInt32(encoded.count), 60)
    return Data(bytes) + encoded
  }
  func testDirectoryPageParsing() throws {
    var first = record(name: "a.mkv", next: 80, size: 7)
    first += Data(repeating: 0, count: 80 - first.count)
    let parsed = try SMBConnection.parseDirectoryPage(first + record(name: "dir", attributes: 0x410))
    XCTAssertEqual(parsed.map(\.name), ["a.mkv", "dir"])
    XCTAssertEqual(parsed[0].size, 7)
    XCTAssertEqual(parsed[0].modified, 99)
    XCTAssertTrue(parsed[1].isDirectory)
    XCTAssertTrue(parsed[1].isLink)
  }
  func testMalformedPagesAreRejected() {
    XCTAssertThrowsError(try SMBConnection.parseDirectoryPage(Data()))
    XCTAssertThrowsError(try SMBConnection.parseDirectoryPage(Data(repeating: 0, count: 63)))
    XCTAssertThrowsError(try SMBConnection.parseDirectoryPage(record(name: "a", nameSize: 9999)))
    XCTAssertThrowsError(try SMBConnection.parseDirectoryPage(record(name: "a", nameSize: 3)))
    XCTAssertThrowsError(try SMBConnection.parseDirectoryPage(record(name: "a", next: 8)))
    XCTAssertThrowsError(try SMBConnection.parseDirectoryPage(record(name: "a", next: UInt32.max)))
  }
  func testNoAccountIsRefusedWithoutConnecting() async throws {
    let source = try SMBLibrarySource(scope: WebDAVScope(storageAddress: "smb://127.0.0.1:1/"), credential: nil)
    do {
      _ = try await source.list(DAVPath())
      XCTFail("Expected failure")
    } catch { XCTAssertEqual(error as? SMBReadError, .accountRequired) }
  }
  func testClosedPortReportsUnreachable() async throws {
    let source = try SMBLibrarySource(
      scope: WebDAVScope(storageAddress: "smb://127.0.0.1:1/TEST/"), credential: WebDAVCredential(username: "a", password: "b"))
    do {
      _ = try await source.list(DAVPath())
      XCTFail("Expected failure")
    } catch { XCTAssertEqual(error as? SMBReadError, .unreachable) }
  }
}

final class SMBLibrarySourceTests: XCTestCase {
  private var directory: URL!
  private var process: Process?
  private var port = 0
  private let video = (0..<3_000_000).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ ($0 >> 8)) }
  private let credential = WebDAVCredential(username: "fixture", password: "local-only")

  override func setUp() async throws {
    guard let python = ProcessInfo.processInfo.environment["NASTART_SMB_FIXTURE_PYTHON"] else {
      throw XCTSkip("Set NASTART_SMB_FIXTURE_PYTHON to a Python with impacket")
    }
    directory = FileManager.default.temporaryDirectory.appendingPathComponent("Nastart-SMB-" + UUID().uuidString)
    let folder = directory.appendingPathComponent("share/电影 100%/盗梦空间")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data(video).write(to: folder.appendingPathComponent("Inception.mkv"))
    try Data("<movie><title>盗梦空间</title></movie>".utf8).write(to: folder.appendingPathComponent("Inception.nfo"))
    let script = try XCTUnwrap(Bundle.module.url(forResource: "smb_media_fixture", withExtension: "py", subdirectory: "Fixtures"))
    let p = Process()
    p.executableURL = URL(fileURLWithPath: python)
    p.arguments = ["-I", "-u", script.path, directory.path, directory.appendingPathComponent("share").path]
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    try p.run()
    process = p
    for _ in 0..<500 {
      if let raw = try? String(contentsOf: directory.appendingPathComponent("port")), let value = Int(raw) { port = value; return }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTFail("Fixture did not start")
  }
  override func tearDown() async throws {
    guard let directory else { return }
    try Data().write(to: directory.appendingPathComponent("stop"))
    for _ in 0..<100 where process?.isRunning == true { try await Task.sleep(for: .milliseconds(20)) }
    if process?.isRunning == true { process?.terminate() }
    try? FileManager.default.removeItem(at: directory)
  }
  private func scope(_ path: String = "") throws -> WebDAVScope { try WebDAVScope(storageAddress: "smb://127.0.0.1:\(port)/\(path)") }
  private func indexed() async throws -> (library: NetworkLibrary, file: RemoteMediaEntry) {
    let scope = try scope("TEST/")
    var library = NetworkLibrary(name: "SMB", scope: scope, root: try DAVPath())
    library.files = try await ReadOnlyLibraryScanner.scan(source: try networkStorageSource(scope: scope, credential: credential), root: library.root)
    return (library, try XCTUnwrap(library.files.first { $0.path.name == "Inception.mkv" }))
  }
  private func read(_ reader: any NetworkMediaByteReader, offset: Int64, count: Int64) async throws -> [UInt8] {
    var result: [UInt8] = []
    try await reader.stream(offset: offset, count: count) { result += $0 }
    return result
  }

  func testRootListsShares() async throws {
    let names = try await SMBLibrarySource(scope: scope(), credential: credential).list(DAVPath()).map(\.path.name)
    XCTAssertTrue(names.contains("TEST"), "\(names)")
    XCTAssertFalse(names.contains("IPC$"))
  }
  func testScanFindsVideoAndReadsSidecar() async throws {
    let (library, file) = try await indexed()
    XCTAssertEqual(file.size, 3_000_000)
    XCTAssertNotNil(file.modified)
    let source = try SMBLibrarySource(scope: try scope("TEST/"), credential: credential)
    let nfoPath = try DAVPath(file.path.displayPath.replacingOccurrences(of: ".mkv", with: ".nfo"))
    let nfo = try await source.readNFO(nfoPath, root: library.root)
    XCTAssertTrue(String(decoding: nfo, as: UTF8.self).contains("盗梦空间"))
    do {
      _ = try await source.readNFO(file.path, root: library.root)
      XCTFail("Expected refusal")
    } catch { XCTAssertEqual(error as? NetworkMediaError, .outsideRoot) }
  }
  func testPlaybackReadsExactRanges() async throws {
    let (library, file) = try await indexed()
    let reader = try networkMediaReader(library: library, file: file, credential: credential)
    XCTAssertEqual(reader.byteCount, 3_000_000)
    let whole = try await read(reader, offset: 0, count: 3_000_000)
    XCTAssertEqual(whole, video)
    let middle = try await read(reader, offset: 1_234_567, count: 70_000)
    XCTAssertEqual(middle, Array(video[1_234_567..<1_304_567]))
    let tail = try await read(reader, offset: 2_999_999, count: 1)
    XCTAssertEqual(tail, [video[2_999_999]])
  }
  func testChangedFileIsStale() async throws {
    let (library, file) = try await indexed()
    let url = directory.appendingPathComponent("share/" + file.path.displayPath)
    try Data(video.prefix(1000)).write(to: url)
    let reader = try networkMediaReader(library: library, file: file, credential: credential)
    do {
      _ = try await read(reader, offset: 0, count: 10)
      XCTFail("Expected stale file")
    } catch { XCTAssertEqual(error as? NetworkMediaPlaybackError, .staleFile) }
  }
  func testWrongPasswordIsRefusedOnceThenGated() async throws {
    let wrong = WebDAVCredential(username: "fixture", password: "wrong-" + UUID().uuidString)
    let source = try SMBLibrarySource(scope: try scope("TEST/"), credential: wrong)
    for _ in 0..<2 {
      do {
        _ = try await source.list(DAVPath())
        XCTFail("Expected refusal")
      } catch { XCTAssertEqual(error as? SMBReadError, .loginRejected, "\(error)") }
    }
  }
  func testCancellationEndsARead() async throws {
    let (library, file) = try await indexed()
    let reader = try networkMediaReader(library: library, file: file, credential: credential)
    let task = Task { try await self.read(reader, offset: 0, count: 3_000_000) }
    task.cancel()
    do {
      _ = try await task.value
    } catch { XCTAssertTrue(error is CancellationError, "\(error)") }
    let next = try await read(reader, offset: 0, count: 100)
    XCTAssertEqual(next, Array(video.prefix(100)))
  }
}
#endif
