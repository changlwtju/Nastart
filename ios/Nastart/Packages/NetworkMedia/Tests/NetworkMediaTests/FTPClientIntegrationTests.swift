#if os(macOS)
  import XCTest
  @testable import NetworkMedia

  final class FTPClientIntegrationTests: XCTestCase {
    private var directory: URL!
    private var process: Process?
    private var port: Int = 0
    private var anchor: Data?
    override func setUp() async throws {
      directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "Nastart-FTP-" + UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDown() async throws {
      if let process {
        try Data().write(to: directory.appendingPathComponent("stop"))
        for _ in 0..<100 {
          if !process.isRunning { break }
          try await Task.sleep(for: .milliseconds(50))
        }
        if process.isRunning {
          process.terminate()
          XCTFail("Owned FTP fixture did not stop")
        }
        process.waitUntilExit()
        let state = try self.state()
        XCTAssertEqual(state["allWorkersStopped"] as? Bool, true)
        XCTAssertEqual(state["unexpected"] as? [String], [])
      }
      try FileManager.default.removeItem(at: directory)
    }
    private func openssl(_ arguments: [String]) throws {
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
      p.arguments = arguments
      p.standardOutput = FileHandle.nullDevice
      p.standardError = FileHandle.nullDevice
      try p.run()
      p.waitUntilExit()
      XCTAssertEqual(p.terminationStatus, 0)
    }
    private func start(mode: String = "plain", behavior: String = "normal") async throws {
      if mode != "plain" {
        let name = behavior == "wrong-name" ? "wrong.invalid" : "localhost"
        let config =
          "[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n[dn]\nCN=\(name)\n[ext]\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,digitalSignature,keyEncipherment,keyCertSign\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:\(name)\n"
        let cfg = directory.appendingPathComponent("cert.cnf")
        try Data(config.utf8).write(to: cfg)
        let pem = directory.appendingPathComponent("valid.pem").path
        let key = directory.appendingPathComponent("valid.key").path
        try openssl([
          "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-sha256", "-days", "2", "-config",
          cfg.path, "-keyout", key, "-out", pem,
        ])
        let der = directory.appendingPathComponent("ca.der")
        try openssl(["x509", "-in", pem, "-outform", "DER", "-out", der.path])
        anchor = try Data(contentsOf: der)
        if behavior == "data-other" {
          let csr = directory.appendingPathComponent("other.csr").path
          let otherKey = directory.appendingPathComponent("other.key").path
          try openssl([
            "req", "-new", "-newkey", "rsa:2048", "-nodes", "-subj", "/CN=localhost", "-keyout",
            otherKey, "-out", csr,
          ])
          try openssl([
            "x509", "-req", "-in", csr, "-CA", pem, "-CAkey", key, "-CAcreateserial", "-days", "2",
            "-sha256", "-extfile", cfg.path, "-extensions", "ext", "-out",
            directory.appendingPathComponent("other.pem").path,
          ])
        }
      }
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
      let script = try XCTUnwrap(
        Bundle.module.url(
          forResource: "ftp_readonly_fixture", withExtension: "py", subdirectory: "Fixtures"))
      p.arguments = ["-u", script.path, directory.path, mode, behavior]
      p.standardOutput = FileHandle.nullDevice
      let log = directory.appendingPathComponent("fixture.log")
      _ = FileManager.default.createFile(atPath: log.path, contents: nil)
      p.standardError = try FileHandle(forWritingTo: log)
      try p.run()
      process = p
      for _ in 0..<100 {
        if let raw = try? String(contentsOf: directory.appendingPathComponent("port")),
          let value = Int(raw)
        {
          port = value
          return
        }
        if !p.isRunning {
          XCTFail("Owned fixture exited before ready")
          throw FTPReadError.closed
        }
        try await Task.sleep(for: .milliseconds(30))
      }
      throw FTPReadError.deadline
    }
    private func client(mode: FTPSecurity = .plainFTP, timeout: Int = 3000, trusted: Bool = true)
      throws -> FTPReadOnlyClient
    {
      try FTPReadOnlyClient(
        server: FTPServer(host: "localhost", port: port, security: mode),
        credential: FTPCredential(username: "fixture", password: "local-only"),
        root: FTPPath("/video/media"), timeoutMilliseconds: timeout, allowsPASV: true,
        testAnchor: trusted ? anchor : nil)
    }
    private func state() throws -> [String: Any] {
      try XCTUnwrap(
        JSONSerialization.jsonObject(
          with: Data(contentsOf: directory.appendingPathComponent("state.json"))) as? [String: Any])
    }
    private func waitForPeerClose(data: Bool = false) async throws {
      for _ in 0..<100 {
        let s = try state()
        if (s["closed"] as? Int ?? 0) > 0 && (!data || s["dataEOF"] as? Bool == true) { return }
        try await Task.sleep(for: .milliseconds(10))
      }
      XCTFail("Client did not close its own peer before fixture teardown")
    }
    private func entry(_ client: FTPReadOnlyClient, name: String = "Movie.nfo") async throws
      -> FTPRemoteEntry
    {
      let entries = try await client.list(FTPPath("/video/media"))
      return try XCTUnwrap(entries.first { $0.path.name.utf8.elementsEqual(name.utf8) })
    }
    private func fail(_ operation: () async throws -> Void, error expected: FTPReadError? = nil)
      async
    {
      do {
        try await operation()
        XCTFail("Expected read failure")
      } catch { if let expected { XCTAssertEqual(error as? FTPReadError, expected) } }
    }
    func testPlainLiteralNFOAndPosterAndNoVideoRETR() async throws {
      try await start()
      let c = try client()
      let entries = try await c.list(FTPPath("/video/media"))
      XCTAssertEqual(entries.count, 6)
      for name in ["%2F.NFO", "é.nfo", "e\u{301}.nfo"] {
        let item = try XCTUnwrap(entries.first { $0.path.name.utf8.elementsEqual(name.utf8) })
        let data = try await c.readNFO(item)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("owned fixture"))
      }
      let poster = try XCTUnwrap(entries.first { $0.path.name == "poster.jpg" })
      let data = try await c.readArtwork(poster)
      XCTAssertEqual(data.count, 1903)
      let video = try XCTUnwrap(entries.first { $0.path.name == "Movie.mkv" })
      await fail({ _ = try await c.readNFO(video) }, error: .unsupportedResource)
      let s = try state()
      XCTAssertEqual((s["retrieved"] as? [String])?.count, 4)
      XCTAssertFalse((s["retrieved"] as? [String] ?? []).contains { $0.hasSuffix(".mkv") })
    }
    func testExplicitTLSAndProtectedData() async throws {
      try await start(mode: "explicit")
      let c = try client(mode: .explicitTLS)
      let item = try await entry(c)
      _ = try await c.readNFO(item)
      let s = try state()
      XCTAssertEqual(s["plaintextCredentials"] as? Int, 0)
      XCTAssertEqual((s["dataTLS"] as? [String])?.count, 3)
    }
    func testImplicitTLSAndProtectedData() async throws {
      try await start(mode: "implicit")
      let c = try client(mode: .implicitTLS)
      let item = try await entry(c)
      _ = try await c.readNFO(item)
      XCTAssertEqual(try state()["plaintextCredentials"] as? Int, 0)
    }
    func testUntrustedControlStopsBeforeLogin() async throws {
      try await start(mode: "implicit")
      let c = try client(mode: .implicitTLS, trusted: false)
      await fail({ _ = try await c.list(FTPPath("/video/media")) }, error: .tlsUnverified)
      XCTAssertFalse(try (state()["commands"] as? [String] ?? []).contains("USER"))
    }
    func testWrongHostnameStopsBeforeLogin() async throws {
      try await start(mode: "explicit", behavior: "wrong-name")
      let c = try client(mode: .explicitTLS)
      await fail({ _ = try await c.list(FTPPath("/video/media")) }, error: .tlsUnverified)
      XCTAssertFalse(try (state()["commands"] as? [String] ?? []).contains("USER"))
    }
    func testSameAnchorDifferentDataLeafRejected() async throws {
      try await start(mode: "implicit", behavior: "data-other")
      let c = try client(mode: .implicitTLS)
      await fail({ _ = try await c.list(FTPPath("/video/media")) }, error: .tlsUnverified)
      XCTAssertEqual(try state()["plaintextCredentials"] as? Int, 0)
    }
    func testPASVAdvertisedAddressNeverUsed() async throws {
      try await start(behavior: "pasv")
      let c = try client()
      let rows = try await c.list(FTPPath("/video/media"))
      XCTAssertEqual(rows.count, 6)
      XCTAssertTrue(try (state()["commands"] as? [String] ?? []).contains("PASV"))
    }
    func testChangedBetweenListingAndReadStopsBeforeRETR() async throws {
      try await start(behavior: "changed-list")
      let c = try client()
      let item = try await entry(c)
      await fail({ _ = try await c.readNFO(item) }, error: .sourceChanged)
      XCTAssertEqual(try state()["retrieved"] as? [String], [])
    }
    func testChangedAfterReadDoesNotReturnBytes() async throws {
      try await start(behavior: "changed-after")
      let c = try client()
      let item = try await entry(c)
      await fail({ _ = try await c.readNFO(item) }, error: .sourceChanged)
      XCTAssertEqual((try state()["retrieved"] as? [String])?.count, 1)
    }
    func testWrongMetadataPathDoesNotRetrieve() async throws {
      try await start(behavior: "wrong-path")
      let c = try client()
      let item = try await entry(c)
      await fail({ _ = try await c.readNFO(item) }, error: .sourceChanged)
      XCTAssertEqual(try state()["retrieved"] as? [String], [])
    }
    func testShortReadAndCompletionFailureDoNotReturnBytes() async throws {
      try await start(behavior: "short")
      let c = try client()
      let item = try await entry(c)
      await fail({ _ = try await c.readNFO(item) }, error: .sourceChanged)
    }
    func testCompletionFailureDoesNotReturnBytes() async throws {
      try await start(behavior: "completion-fail")
      let c = try client()
      await fail({ _ = try await c.list(FTPPath("/video/media")) }, error: .unexpected(426))
    }
    func testMissingVersionAndOversizeDoNotOpenAnotherSession() async throws {
      try await start(behavior: "missing-version")
      let c = try client()
      let item = try await entry(c)
      let before = try state()["accepted"] as? Int
      await fail({ _ = try await c.readNFO(item) }, error: .metadataUnavailable)
      XCTAssertEqual(try state()["accepted"] as? Int, before)
    }
    func testMaximumNFOIsReadWithExactLength() async throws {
      try await start(behavior: "maximum-nfo")
      let c = try client()
      let item = try await entry(c)
      let bytes = try await c.readNFO(item)
      XCTAssertEqual(bytes.count, 65536)
    }
    func testExplicitTLSRejectionDoesNotDowngradeOrSendCredentials() async throws {
      try await start(mode: "explicit", behavior: "reject-tls")
      let c = try client(mode: .explicitTLS)
      await fail({ _ = try await c.list(FTPPath("/video/media")) })
      let commands = try state()["commands"] as? [String] ?? []
      XCTAssertTrue(commands.contains("AUTH TLS"))
      XCTAssertFalse(commands.contains("USER"))
    }
    func testOversizeDoesNotOpenAnotherSession() async throws {
      try await start(behavior: "oversized")
      let c = try client()
      let item = try await entry(c)
      let before = try state()["accepted"] as? Int
      await fail({ _ = try await c.readNFO(item) }, error: .limit)
      XCTAssertEqual(try state()["accepted"] as? Int, before)
    }
    func testForeignAuthorizationDoesNotReadAnotherAccount() async throws {
      try await start()
      let c = try client()
      let item = try await entry(c)
      let other = try client()
      let before = try state()["accepted"] as? Int
      await fail({ _ = try await other.readNFO(item) }, error: .staleEntry)
      XCTAssertEqual(try state()["accepted"] as? Int, before)
    }
    func testMissingFeaturesAndLateInvalidListingFail() async throws {
      try await start(behavior: "no-utf8")
      let c = try client()
      await fail({ _ = try await c.list(FTPPath("/video/media")) }, error: .unsupportedServer)
      XCTAssertFalse(try (state()["commands"] as? [String] ?? []).contains { $0.hasPrefix("MLSD") })
      XCTAssertFalse(try (state()["commands"] as? [String] ?? []).contains("USER"))
    }
    func testLateInvalidListingDoesNotReturnPartialDirectory() async throws {
      try await start(behavior: "bad-listing")
      let c = try client()
      await fail({ _ = try await c.list(FTPPath("/video/media")) })
    }
    func testAuthenticationIsNotRetried() async throws {
      try await start(behavior: "auth-reject")
      let c = try client()
      await fail({ _ = try await c.list(FTPPath("/video/media")) }, error: .unexpected(530))
      XCTAssertEqual(try (state()["commands"] as? [String] ?? []).filter { $0 == "USER" }.count, 1)
    }
    func testDeadlineClosesControlAndCancellationClosesData() async throws {
      try await start(behavior: "silent")
      let c = try client(timeout: 150)
      await fail({ _ = try await c.list(FTPPath("/video/media")) }, error: .deadline)
      try await waitForPeerClose()
    }
    func testCancellationClosesActiveDataWithoutPublishing() async throws {
      try await start(behavior: "data-silent")
      let c = try client(timeout: 3000)
      let task = Task { try await c.list(FTPPath("/video/media")) }
      for _ in 0..<100 {
        if (try state()["commands"] as? [String] ?? []).contains(where: { $0.hasPrefix("MLSD") }) {
          break
        }
        try await Task.sleep(for: .milliseconds(10))
      }
      task.cancel()
      do {
        _ = try await task.value
        XCTFail("Cancelled list returned")
      } catch { XCTAssertTrue(error is CancellationError) }
      try await waitForPeerClose(data: true)
    }
  }
#endif
