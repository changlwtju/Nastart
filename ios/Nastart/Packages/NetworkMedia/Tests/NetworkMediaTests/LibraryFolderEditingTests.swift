import XCTest
@testable import NetworkMedia

final class LibraryFolderEditingTests: XCTestCase {
    func testBrowsingUsesSameOriginAndLiteralFullFolderWithoutChangingLibrary() throws {
        let lib = NetworkLibrary(name: "Movies", scope: try WebDAVScope(address: "http://example.test:5005/video/media/"), root: try DAVPath("电影 100%"))
        let location = try lib.folderBrowsingLocation()
        XCTAssertEqual(location.scope.baseURL.absoluteString, "http://example.test:5005/")
        XCTAssertEqual(location.path.displayPath, "video/media/电影 100%")
        let sibling = try lib.folderBrowsingLocation(path: "/video/其他")
        XCTAssertEqual(sibling.path.displayPath, "video/其他")
        XCTAssertEqual(sibling.scope.baseURL, location.scope.baseURL)
        XCTAssertEqual(lib.folderPath, "/video/media/电影 100%")
        XCTAssertThrowsError(try lib.folderBrowsingLocation(path: "/video/../outside"))
    }
    func testFileStationBrowsingPreservesSessionAddressAndRoot() throws {
        let lib = NetworkLibrary(name: "NAS", scope: try WebDAVScope(address: "https://example.test:5001/"), root: try DAVPath("video/media"), fileStationAccount: "fixture-account")
        let location = try lib.folderBrowsingLocation(path: "/video/新的目录")
        XCTAssertEqual(location.scope.baseURL.absoluteString, lib.address)
        XCTAssertEqual(location.path.displayPath, "video/新的目录")
        XCTAssertEqual(lib.fileStationAccount, "fixture-account")
        XCTAssertEqual(lib.root.displayPath, "video/media")
    }
    func testChosenAbsoluteFolderDoesNotDuplicateTheSavedMountPath() throws {
        let library = NetworkLibrary(name: "Movies", scope: try WebDAVScope(address: "https://example.test/remote.php/dav/files/user/Movies/"), root: try DAVPath())
        let browser = try library.folderBrowsingLocation()
        XCTAssertEqual(browser.path.displayPath, "remote.php/dav/files/user/Movies")
        let selected = try library.replacingFolder(with: "/remote.php/dav/files/user/TV")
        XCTAssertEqual(selected.folderPath, "/remote.php/dav/files/user/TV")
        XCTAssertEqual(selected.address, "https://example.test/remote.php/dav/files/user/TV/")
        XCTAssertTrue(selected.root.encodedSegments.isEmpty)
        XCTAssertTrue(try WebDAVScope(address: library.address).sameOrigin(WebDAVScope(address: selected.address).baseURL))
    }
    struct Source: ReadOnlyDirectorySource {
        let entries: [RemoteMediaEntry]
        func list(_ path: DAVPath) async throws -> [RemoteMediaEntry] { entries }
    }
    struct Failing: ReadOnlyDirectorySource {
        func list(_ path: DAVPath) async throws -> [RemoteMediaEntry] { throw NetworkMediaError.http(403) }
    }
    func fixture(catalog: UserDefaults? = nil) async throws -> (URL, NetworkLibraryStore, NetworkLibrary) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = NetworkLibraryStore(directory: dir, catalog: catalog)
        let lib = NetworkLibrary(name: "Movies", scope: try WebDAVScope(address: "http://example.test:5005/video/media/"), root: try DAVPath())
        try await store.add(lib)
        try await store.scan(lib, source: Source(entries: [video()]))
        return (dir, store, try await store.libraries()[0])
    }
    func video(_ path: String = "a.mkv") throws -> RemoteMediaEntry {
        .init(path: try DAVPath(path), isDirectory: false, size: 42, etag: "same")
    }
    func testFullPathCanMoveToSiblingAndKeepsLiteralCharacters() throws {
        let lib = NetworkLibrary(name: "Movies", scope: try WebDAVScope(address: "http://example.test:5005/video/media/"), root: try DAVPath("Movies"))
        XCTAssertEqual(lib.folderPath, "/video/media/Movies")
        let next = try lib.replacingFolder(with: "/另一个目录/电影 100%")
        XCTAssertEqual(next.folderPath, "/另一个目录/电影 100%")
        XCTAssertNotEqual(next.id, lib.id)
        XCTAssertTrue(try WebDAVScope(address: lib.address).sameOrigin(WebDAVScope(address: next.address).baseURL))
        XCTAssertTrue(next.root.encodedSegments.isEmpty)
        XCTAssertEqual(URLComponents(string: next.address)?.port, 5005)
        XCTAssertThrowsError(try lib.replacingFolder(with: "/../outside"))
        XCTAssertThrowsError(try lib.replacingFolder(with: "/a/../outside"))
    }
    func testSuccessfulReplacementIsDurableAndKeepsOtherLibraries() async throws {
        let suite = "folder-edit-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let (dir, store, lib) = try await fixture(catalog: defaults)
        defer { try? FileManager.default.removeItem(at: dir) }
        let other = NetworkLibrary(name: "other", scope: try WebDAVScope(address: lib.address), root: try DAVPath("other"))
        try await store.add(other)
        let next = try lib.replacingFolder(with: "/video/new")
        try await store.relocate(lib, replacement: next, source: Source(entries: [video("new.mkv")]))
        let saved = try await store.libraries()
        XCTAssertEqual(saved.map(\.id), [next.id, other.id]); XCTAssertEqual(saved[0].files.map(\.path.name), ["new.mkv"])
        XCTAssertEqual(saved[0].folderPath, "/video/new"); XCTAssertEqual(saved[0].artworkScanVersion, 5)
        let reloaded = try await NetworkLibraryStore(directory: dir, catalog: defaults).libraries()
        XCTAssertEqual(reloaded, saved)
        try FileManager.default.removeItem(at: dir)
        let recovered = try await NetworkLibraryStore(directory: dir, catalog: defaults).libraries()
        XCTAssertEqual(recovered.map(\.id), [next.id, other.id]); XCTAssertEqual(recovered[0].folderPath, "/video/new")
        do { try await store.scan(lib, source: Source(entries: [video("stale.mkv")])); XCTFail("stale source replaced new folder") } catch { }
        let afterStale = try await store.libraries(); XCTAssertEqual(afterStale, saved)
    }
    func testFailuresAndCancellationKeepExactPreviousBytes() async throws {
        let (dir, store, lib) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("libraries-v1.json"), bytes = try Data(contentsOf: file)
        let next = try lib.replacingFolder(with: "/new")
        do { try await store.relocate(lib, replacement: next, source: Failing()); XCTFail() } catch { }
        do { try await store.relocate(lib, replacement: next, source: Source(entries: [video(), video()])); XCTFail() } catch { }
        let task = Task { try await store.relocate(lib, replacement: next, source: Source(entries: [video()])) { _ in withUnsafeCurrentTask { $0?.cancel() } } }
        do { try await task.value; XCTFail() } catch is CancellationError { }
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        let current = try await store.libraries(), reloaded = try await NetworkLibraryStore(directory: dir).libraries()
        XCTAssertEqual(current, [lib]); XCTAssertEqual(reloaded, current)
    }
    func testOriginChangeRejectedAndCorrectionCannotLeakToSameRelativeName() async throws {
        let (dir, store, lib) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let foreign = NetworkLibrary(name: lib.name, scope: try WebDAVScope(address: "https://other.test/"), root: try DAVPath())
        do { try await store.relocate(lib, replacement: foreign, source: Source(entries: [video()])); XCTFail() } catch { }
        try await store.saveCorrection(lib.id, expected: lib.files[0], values: .init(title: "original only"))
        let next = try lib.replacingFolder(with: "/different")
        try await store.relocate(lib, replacement: next, source: Source(entries: [video()]))
        let saved = try await store.libraries()[0]
        XCTAssertNil(saved.corrections); XCTAssertEqual(saved.files.count, 1)
    }
    func testNewerScanInvalidatesPendingFolderEdit() async throws {
        let (dir, store, lib) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let next = try lib.replacingFolder(with: "/new")
        do {
            try await store.relocate(lib, replacement: next, source: Source(entries: [video()])) { _ in
                _ = try? await store.beginScan(lib.id)
            }
            XCTFail("late folder edit committed")
        } catch is CancellationError { }
        let saved = try await store.libraries(); XCTAssertEqual(saved, [lib])
    }
    func testEquivalentFolderEditHasNoReplacementButPreservesLiteralPathDifferences() throws {
        let library = NetworkLibrary(name: "Movies", scope: try WebDAVScope(address: "http://example.test/video/"), root: try DAVPath("电影 100%"))
        for path in [library.folderPath, "/video//电影 100%/", "video/电影 100%"] {
            XCTAssertNil(try library.replacementForFolderEdit(path))
        }
        XCTAssertNotNil(try library.replacementForFolderEdit("/video/电影%20100%25"))
        XCTAssertNotNil(try library.replacementForFolderEdit("/Video/电影 100%"))
        XCTAssertThrowsError(try library.replacementForFolderEdit("/video/../outside"))
        let nas = NetworkLibrary(name: "NAS", scope: try WebDAVScope(address: "https://example.test:5001/"), root: try DAVPath("video/media"), fileStationAccount: "test-only")
        XCTAssertNil(try nas.replacementForFolderEdit("/video/media/"))
    }
    func testFileStationFullPathUsesRootAndPreservesAccount() throws {
        let lib = NetworkLibrary(name: "NAS", scope: try WebDAVScope(address: "https://example.test:5001/"), root: try DAVPath("video/media"), fileStationAccount: "local-test-account")
        let next = try lib.replacingFolder(with: "/video/new")
        XCTAssertEqual(lib.folderPath, "/video/media"); XCTAssertEqual(next.folderPath, "/video/new")
        XCTAssertEqual(next.address, lib.address); XCTAssertEqual(next.fileStationAccount, lib.fileStationAccount)
    }
}
