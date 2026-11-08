import XCTest
@testable import NetworkMedia

final class SavedConnectionTests: XCTestCase {
    struct Source: ReadOnlyDirectorySource {
        let fails: Bool
        func list(_ path: DAVPath) async throws -> [RemoteMediaEntry] {
            if fails { throw NetworkMediaError.http(403) }
            return [RemoteMediaEntry(path: DAVPath(validated: path.encodedSegments + ["movie.mkv"]), isDirectory: false, size: 42, modified: "version-one")]
        }
    }
    func fixture(catalog: UserDefaults? = nil) async throws -> (URL, NetworkLibraryStore, NetworkStorageConnection, [NetworkLibrary]) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = NetworkLibraryStore(directory: dir, catalog: catalog)
        let connection = NetworkStorageConnection(name: "NAS", scope: try WebDAVScope(address: "http://example.test:5005/video/"))
        try await store.addConnection(connection)
        for path in ["movies", "shows"] {
            let lib = NetworkLibrary(name: path, scope: try WebDAVScope(address: "http://example.test:5005/video/"), root: try DAVPath(path), connectionID: connection.id)
            try await store.add(lib); try await store.scan(lib, source: Source(fails: false))
        }
        return (dir, store, connection, try await store.libraries())
    }
    func testLegacyAdoptionKeepsLibraryIdentityFilesAndReopens() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = NetworkLibraryStore(directory: dir)
        let old = NetworkLibrary(name: "Movies", scope: try WebDAVScope(address: "http://example.test/video/"), root: try DAVPath())
        try await store.add(old); try await store.scan(old, source: Source(fails: false))
        let before = try await store.libraries()
        let connection = NetworkStorageConnection(name: "Server", scope: try WebDAVScope(address: old.address))
        try await store.adoptConnections(expected: before, connections: [connection], assignments: [old.id: connection.id])
        var expected = before; expected[0].connectionID = connection.id
        let reloaded = NetworkLibraryStore(directory: dir)
        let saved = try await reloaded.libraries(), connections = try await reloaded.connections()
        XCTAssertEqual(saved, expected); XCTAssertEqual(connections, [connection])
        let raw = try String(contentsOf: dir.appendingPathComponent("libraries-v1.json"))
        XCTAssertFalse(raw.contains("password")); XCTAssertFalse(raw.contains("username"))
    }
    func testInvalidConnectionReferencesCannotPartiallyCommit() async throws {
        let (dir, store, connection, libraries) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let bytes = try Data(contentsOf: dir.appendingPathComponent("libraries-v1.json"))
        let foreign = NetworkLibrary(name: "wrong server", scope: try WebDAVScope(address: "https://other.test/"), root: try DAVPath(), connectionID: connection.id)
        do { try await store.add(foreign); XCTFail() } catch { }
        let unassigned = NetworkLibrary(name: "missing", scope: try WebDAVScope(address: connection.address), root: try DAVPath(), connectionID: UUID())
        do { try await store.add(unassigned); XCTFail() } catch { }
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("libraries-v1.json")), bytes)
        let saved = try await store.libraries(); XCTAssertEqual(saved, libraries)
    }
    func testLastFolderRemovalAndTVCacheEvictionKeepSavedConnection() async throws {
        let suite = "saved-connection-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let (dir, store, connection, libraries) = try await fixture(catalog: defaults)
        defer { try? FileManager.default.removeItem(at: dir) }
        for library in libraries { try await store.remove(library.id) }
        try FileManager.default.removeItem(at: dir)
        let recovered = NetworkLibraryStore(directory: dir, catalog: defaults)
        let saved = try await recovered.libraries(), connections = try await recovered.connections()
        XCTAssertTrue(saved.isEmpty); XCTAssertEqual(connections, [connection])
    }
    func testRenameDoesNotRenameFoldersOrInvalidateTheirIndex() async throws {
        let (dir, store, connection, libraries) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        try await store.renameConnection(connection, name: "Living room")
        let saved = try await store.libraries(), connections = try await store.connections()
        XCTAssertEqual(saved, libraries); XCTAssertEqual(connections[0].id, connection.id)
        XCTAssertEqual(connections[0].name, "Living room")
        do { try await store.renameConnection(connection, name: "stale"); XCTFail() } catch { }
    }
    func testReplacementRebuildsAllLinkedFoldersTogetherAndPreservesTheirPaths() async throws {
        let (dir, store, connection, libraries) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let other = NetworkLibrary(name: "other", scope: try WebDAVScope(address: "https://unrelated.test/"), root: try DAVPath())
        try await store.add(other)
        let next = NetworkStorageConnection(name: "New server", scope: try WebDAVScope(address: "https://new.test:5443/different-start/"))
        let folders = try libraries.map { (original: $0, replacement: try next.replacement(for: $0)) }
        try await store.replaceConnection(connection, replacement: next, folders: folders, preservingCorrections: false, source: { _ in Source(fails: false) })
        let saved = try await store.libraries(), connections = try await store.connections()
        XCTAssertEqual(connections, [next]); XCTAssertEqual(saved.last, other)
        XCTAssertEqual(Array(saved.prefix(2)).map(\.folderPath), libraries.map(\.folderPath))
        XCTAssertEqual(saved[0].address, "https://new.test:5443/video/")
        XCTAssertEqual(saved[0].root, libraries[0].root)
        XCTAssertEqual(saved[0].connectionID, next.id); XCTAssertNotEqual(saved[0].id, libraries[0].id)
        XCTAssertEqual(saved[0].files, libraries[0].files)
        let reloaded = try await NetworkLibraryStore(directory: dir).libraries(); XCTAssertEqual(reloaded, saved)
    }
    func testSecondFolderFailureAndCancellationKeepExactOldBytes() async throws {
        let (dir, store, connection, libraries) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("libraries-v1.json"), bytes = try Data(contentsOf: file)
        let next = NetworkStorageConnection(name: "New", scope: try WebDAVScope(address: "https://new.test/"))
        let folders = try libraries.map { (original: $0, replacement: try next.replacement(for: $0)) }
        do {
            try await store.replaceConnection(connection, replacement: next, folders: folders, preservingCorrections: false, source: { Source(fails: $0.name == "shows") })
            XCTFail("partial server replacement")
        } catch { }
        let task = Task {
            try await store.replaceConnection(connection, replacement: next, folders: folders, preservingCorrections: false, source: { _ in Source(fails: false) }) { _ in
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        do { try await task.value; XCTFail() } catch is CancellationError { }
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        let saved = try await store.libraries(), connections = try await store.connections()
        XCTAssertEqual(saved, libraries); XCTAssertEqual(connections, [connection])
    }
    func testNewerScanInvalidatesWholeConnectionReplacement() async throws {
        let (dir, store, connection, libraries) = try await fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let next = NetworkStorageConnection(name: "New", scope: try WebDAVScope(address: "https://new.test/"))
        let folders = try libraries.map { (original: $0, replacement: try next.replacement(for: $0)) }
        do {
            try await store.replaceConnection(connection, replacement: next, folders: folders, preservingCorrections: false, source: { _ in Source(fails: false) }) { _ in
                _ = try? await store.beginScan(libraries[0].id)
            }
            XCTFail("late result overwrote a newer scan")
        } catch { }
        let saved = try await store.libraries(), connections = try await store.connections()
        XCTAssertEqual(saved, libraries); XCTAssertEqual(connections, [connection])
    }
    func testFieldsRoundTripLiteralPercentChineseAndIPv6() throws {
        for address in ["http://example.test:5005/video/%E7%94%B5%E5%BD%B1%20100%25/", "https://[2001:db8::1]:5443/Movies/"] {
            let scope = try WebDAVScope(address: address)
            let fields = try WebDAVConnectionFields(scope: scope)
            XCTAssertEqual(try fields.scope().baseURL, scope.baseURL)
        }
    }
}
