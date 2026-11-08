import XCTest

@testable import NetworkMedia

final class FTPClientContractTests: XCTestCase {
  func testEndpointIdentityIncludesSecurityAndPortAndDecodingRevalidates() throws {
    let a = try FTPServer(host: "NAS.Example", security: .explicitTLS)
    XCTAssertEqual(a.host, "nas.example")
    XCTAssertEqual(a.port, 21)
    XCTAssertNotEqual(a, try FTPServer(host: "nas.example", security: .plainFTP))
    XCTAssertNotEqual(a, try FTPServer(host: "nas.example", port: 990))
    XCTAssertEqual(try FTPServer(host: "[::1]", security: .implicitTLS).port, 990)
    let json = try JSONEncoder().encode(a)
    XCTAssertEqual(try JSONDecoder().decode(FTPServer.self, from: json), a)
    for value in [
      "http://nas", "user@nas", "nas:21", "nas/path", "nas?x=1", "nas#x", "nas%2F", "a..b", "-nas",
      "nas-", "256.300.4.1", "bad\r\nQUIT", "中文.local",
    ] {
      XCTAssertThrowsError(try FTPServer(host: value), value)
    }
    for port in [0, -1, 65536] { XCTAssertThrowsError(try FTPServer(host: "nas", port: port)) }
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        FTPServer.self, from: Data(#"{"host":"nas/path","port":21,"security":"explicitTLS"}"#.utf8))
    )
    XCTAssertThrowsError(
      try JSONDecoder().decode(
        FTPServer.self, from: Data(#"{"host":"nas","port":21,"security":"auto"}"#.utf8)))
    XCTAssertFalse(String(decoding: json, as: UTF8.self).contains("password"))
  }
  func testCredentialsRejectCommandInjectionAndPreserveLiteralSpaces() throws {
    let credential = try FTPCredential(username: " user ", password: " a b ")
    XCTAssertEqual(credential.username, " user ")
    XCTAssertEqual(credential.password, " a b ")
    for text in ["\rPASS other", "\nQUIT", "\0", String(repeating: "a", count: 1025)] {
      XCTAssertThrowsError(try FTPCredential(username: "fixture", password: text))
    }
    XCTAssertThrowsError(try FTPCredential(username: "", password: ""))
    XCTAssertNoThrow(try FTPCredential(username: "fixture", password: ""))
  }
  func testFTPListingKeepsLiteralAndUnicodeByteDistinctNames() throws {
    let names = ["电影 100%.mkv", "%2F.NFO", "é.nfo", "e\u{301}.nfo"]
    let text = names.map { "type=file;size=1;modify=20261027000000;unique=fixture; \($0)\r\n" }
      .joined()
    let entries = try FTPMLSDListing.parse(Data(text.utf8)).entries
    XCTAssertEqual(entries.count, 4)
    for (name, entry) in zip(names, entries) {
      XCTAssertEqual(Data(name.utf8), Data(entry.name.utf8))
    }
    XCTAssertFalse(entries[2].byteEqual(entries[3]))
    XCTAssertThrowsError(
      try FTPMLSDListing.parse(
        Data((text + "type=file;size=1;modify=20261027000000; %2F.NFO\r\n").utf8)))
  }
  func testLibraryListingSkipsUnreadableRowsAndKeepsTheRest() throws {
    var data = Data("type=file;size=1;modify=20261027000000; A.mkv\r\n".utf8)
    data.append(Data("type=file;size=1;modify=20261027000000; ".utf8) + Data([0xD0, 0xC2]) + Data("\r\n".utf8))
    data.append(Data("type=file;size=1;modify=20261027000000; B/C.mkv\r\n".utf8))
    data.append(Data("type=file;size=1;modify=20261027000000; D.mkv\r\n".utf8))
    XCTAssertEqual(try FTPMLSDListing.parse(data, limits: .library).entries.map(\.name), ["A.mkv", "D.mkv"])
    XCTAssertThrowsError(try FTPMLSDListing.parse(data))
  }
  func testFactValuesMayContainSpaces() throws {
    let row = "modify=20261027000000;type=file;size=1;UNIX.group=Domain Users; 电影 1.mkv\r\n"
    XCTAssertEqual(try FTPMLSDListing.parse(Data(row.utf8)).entries.map(\.name), ["电影 1.mkv"])
  }
  func testListingLateInvalidEntryFailsWholeDirectory() throws {
    let valid = "type=file;size=1;modify=20261027000000; Movie.mkv\r\n"
    for row in [
      "type=OS.unix=slink; escape\r\n", "type=file;size=1;size=2; X.nfo\r\n",
      "type=file;modify=20260230000000; X.nfo\r\n", "type=file; ../X.nfo\r\n",
      "type=file; A/B.nfo\r\n", "type=file; X.nfo\n",
    ] {
      XCTAssertThrowsError(try FTPMLSDListing.parse(Data((valid + row).utf8)))
    }
  }
  func testFactSelectionIsSkippedOnlyWhenEveryRequiredFactIsActive() {
    let reply = { (mlst: String) in ["211- Extensions supported:", mlst, " UTF8", "211 End."] }
    XCTAssertTrue(FTPFeatureReply.requiredFactsAreActive(reply(
      " MLST modify*;type*;unique*;size*;UNIX.mode*;UNIX.owner*;UNIX.group*;")))
    XCTAssertFalse(FTPFeatureReply.requiredFactsAreActive(reply(" MLST type*;size*;modify*;unique;")))
    XCTAssertFalse(FTPFeatureReply.requiredFactsAreActive(reply(" MLST type*;size*;modify*;")))
    XCTAssertFalse(FTPFeatureReply.requiredFactsAreActive(reply(" MLSD type*;size*;modify*;unique*;")))
    XCTAssertFalse(FTPFeatureReply.requiredFactsAreActive(["211 End"]))
  }
  func testFeaturesRequireUTF8MLSTAndTVFSWithoutInferringFromSuccessfulLogin() throws {
    let valid = ["211-Features", " UTF8", " MLST type*;size*;modify*;unique*;", " TVFS", "211 End"]
    XCTAssertNoThrow(try FTPFeatureReply.validate(valid))
    for missing in ["UTF8", "MLST", "TVFS"] {
      XCTAssertThrowsError(try FTPFeatureReply.validate(valid.filter { !$0.contains(missing) }))
    }
    XCTAssertThrowsError(try FTPFeatureReply.validate(["211 success"]))
  }
  func testMetadataPathAndMissingVersionCannotAlias() throws {
    let facts = "type=file;size=7;modify=20261027000000;unique=inode;"
    let path = "/video/%2F.NFO"
    let entry = try FTPMetadataReply.mlst(
      ["250-Listing", " " + facts + " " + path, "250 End"], relative: path, absolute: path,
      name: "%2F.NFO")
    XCTAssertEqual(entry.name, "%2F.NFO")
    for wrong in ["/other/%2F.NFO", "/video//.NFO", "%2F.NFO"] {
      XCTAssertThrowsError(
        try FTPMetadataReply.mlst(
          ["250-Listing", " " + facts + " " + wrong, "250 End"], relative: path, absolute: path,
          name: "%2F.NFO"))
    }
    let changed = FTPListingEntry(
      name: entry.name, kind: .file, size: 7, modify: entry.modify, unique: nil)
    XCTAssertFalse(FTPMetadataReply.sameVersion(entry, changed))
  }
  func testRootAndAuthorizationFailBeforeOpeningNetwork() async throws {
    let server = try FTPServer(host: "fixture.invalid", security: .plainFTP)
    let client = try FTPReadOnlyClient(
      server: server, credential: FTPCredential(username: "fixture", password: ""),
      root: FTPPath("/video/media"))
    do {
      _ = try await client.list(FTPPath("/video/mediabox"))
      XCTFail("outside root")
    } catch { XCTAssertEqual(error as? FTPReadError, .outsideRoot) }
    let foreign = FTPRemoteEntry(
      path: try FTPPath("/video/media/Movie.nfo"), authorization: UUID(),
      version: FTPListingEntry(
        name: "Movie.nfo", kind: .file, size: 1, modify: "20261027000000", unique: nil))
    do {
      _ = try await client.readNFO(foreign)
      XCTFail("foreign authorization")
    } catch { XCTAssertEqual(error as? FTPReadError, .staleEntry) }
  }
}
