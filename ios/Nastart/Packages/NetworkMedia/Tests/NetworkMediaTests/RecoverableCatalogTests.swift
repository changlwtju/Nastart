import XCTest
@testable import NetworkMedia

final class RecoverableCatalogTests: XCTestCase {
    func testPurgedIndexRestoresConnectionWithoutPretendingScanCompleted() async throws {
        let suite = "NetworkMediaTests." + UUID().uuidString, directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let store = NetworkLibraryStore(directory: directory, catalog: defaults)
        let library = NetworkLibrary(name: "preserved", scope: try WebDAVScope(address: "https://example.test/dav/"), root: try DAVPath("Movies"))
        try await store.add(library)
        let token = try await store.beginScan(library.id)
        try await store.commit(library.id, token: token, files: [RemoteMediaEntry(path: try DAVPath("Movies/a.mkv"), isDirectory: false, metadata: .init(title: "a"))])
        let catalog = defaults.data(forKey: "networkMedia.sourceCatalog.v2")!
        XCTAssertFalse(String(data: catalog, encoding: .utf8)!.contains("files"))
        XCTAssertFalse(String(data: catalog, encoding: .utf8)!.contains("password"))
        try FileManager.default.removeItem(at: directory.appendingPathComponent("libraries-v1.json"))
        let recovered = try await NetworkLibraryStore(directory: directory, catalog: defaults).libraries()
        XCTAssertEqual(recovered.map(\.id), [library.id]); XCTAssertEqual(recovered[0].root, library.root)
        XCTAssertTrue(recovered[0].files.isEmpty); XCTAssertNil(recovered[0].lastCompletedScan)
    }
    func testRemovingSourceCannotBeUndoneByLeftoverIndex() async throws {
        let suite = "NetworkMediaTests." + UUID().uuidString, directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let store = NetworkLibraryStore(directory: directory, catalog: defaults)
        let library = NetworkLibrary(name: "x", scope: try WebDAVScope(address: "https://example.test/"), root: try DAVPath())
        try await store.add(library)
        let file = directory.appendingPathComponent("libraries-v1.json"), stale = try Data(contentsOf: file)
        try await store.remove(library.id)
        XCTAssertNil(defaults.object(forKey: "networkMedia.sourceCatalog.v1"))
        XCTAssertNil(defaults.object(forKey: "networkMedia.sourceCatalog.v2"))
        try stale.write(to: file)
        let recovered = try await NetworkLibraryStore(directory: directory, catalog: defaults).libraries()
        XCTAssertTrue(recovered.isEmpty)
    }
    func testOversizedConfigurationFailsBeforeReplacingEitherStore() async throws {
        let suite = "NetworkMediaTests." + UUID().uuidString, directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let store = NetworkLibraryStore(directory: directory, catalog: defaults)
        let scope = try WebDAVScope(address: "https://example.test/")
        try await store.add(NetworkLibrary(name: "valid", scope: scope, root: DAVPath()))
        let file = directory.appendingPathComponent("libraries-v1.json"), before = try Data(contentsOf: file), catalog = defaults.data(forKey: "networkMedia.sourceCatalog.v2")
        do { try await store.add(NetworkLibrary(name: String(repeating: "x", count: 70_000), scope: scope, root: DAVPath())); XCTFail() } catch { }
        XCTAssertEqual(try Data(contentsOf: file), before)
        XCTAssertEqual(defaults.data(forKey: "networkMedia.sourceCatalog.v2"), catalog)
    }
}
