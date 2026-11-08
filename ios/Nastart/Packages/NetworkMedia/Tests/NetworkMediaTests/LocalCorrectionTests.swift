import XCTest
@testable import NetworkMedia

final class LocalCorrectionTests: XCTestCase {
    let scope = try! WebDAVScope(address: "https://example.test/dav/")
    func video(etag: String? = "v1", size: Int64? = 42, modified: String? = nil) throws -> RemoteMediaEntry {
        RemoteMediaEntry(path: try DAVPath("Movies/a.mkv"), isDirectory: false, size: size, modified: modified, etag: etag,
                         metadata: .init(title: "原片名", year: 2024, kind: .movie, plot: "原简介", providerIDs: ["tmdb": "12"], origin: .nfo))
    }
    func fixture(catalog: UserDefaults? = nil) async throws -> (URL, NetworkLibraryStore, NetworkLibrary, RemoteMediaEntry) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = NetworkLibraryStore(directory: directory, catalog: catalog)
        let library = NetworkLibrary(name: "test", scope: scope, root: try DAVPath("Movies")), file = try video()
        try await store.add(library)
        let token = try await store.beginScan(library.id)
        try await store.commit(library.id, token: token, files: [file])
        return (directory, store, library, file)
    }
    func testCorrectionPersistsWithoutChangingRawNFOAndCanBeRestored() async throws {
        let (directory, store, library, file) = try await fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let values = try LocalMediaCorrection.Values(title: "本机片名", year: 2025, kind: .movie)
        try await store.saveCorrection(library.id, expected: file, values: values)
        var reloaded = try await NetworkLibraryStore(directory: directory).libraries()[0]
        XCTAssertEqual(reloaded.files, [file]); XCTAssertEqual(reloaded.correction(for: file)?.values, values)
        XCTAssertTrue(reloaded.correction(for: file)!.applies(to: file))
        XCTAssertEqual(reloaded.files[0].metadata?.providerIDs, ["tmdb": "12"])
        try await store.restoreIdentification(library.id, path: file.path)
        reloaded = try await NetworkLibraryStore(directory: directory).libraries()[0]
        XCTAssertNil(reloaded.correction(for: file)); XCTAssertEqual(reloaded.files, [file])
    }
    func testNewScansPreserveOverlayButChangedOrMissingVersionNeedsReview() async throws {
        let (directory, store, library, file) = try await fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.saveCorrection(library.id, expected: file, values: .init(title: "本机片名"))
        let token = try await store.beginScan(library.id), changed = try video(etag: "v2")
        try await store.commit(library.id, token: token, files: [changed])
        let saved = try await store.libraries()[0], correction = saved.correction(for: changed)!
        XCTAssertEqual(correction.values.title, "本机片名"); XCTAssertFalse(correction.applies(to: changed))
        XCTAssertFalse(correction.applies(to: try video(etag: nil)))
        let unknown = LocalMediaCorrection(file: try video(etag: nil), values: try .init(title: "unknown"))
        XCTAssertFalse(unknown.applies(to: try video(etag: nil)))
        let dated = try video(etag: nil, modified: "Mon, 26 Oct 2026 00:00:00 GMT")
        XCTAssertTrue(LocalMediaCorrection(file: dated, values: try .init(title: "dated")).applies(to: dated))
    }
    func testStaleEditorDoesNotReplaceNewerMetadataOrOverlay() async throws {
        let (directory, store, library, file) = try await fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.saveCorrection(library.id, expected: file, values: .init(title: "原修改"))
        var changed = file; changed.metadata?.title = "新NFO"
        let token = try await store.beginScan(library.id)
        try await store.commit(library.id, token: token, files: [changed])
        let url = directory.appendingPathComponent("libraries-v1.json"), before = try Data(contentsOf: url)
        do { try await store.saveCorrection(library.id, expected: file, values: .init(title: "旧表单")); XCTFail() }
        catch { XCTAssertEqual(error as? NetworkMediaError, .staleCorrection) }
        XCTAssertEqual(try Data(contentsOf: url), before)
    }
    func testScopeAndSourceIsolationAndRemoval() async throws {
        let (directory, store, library, file) = try await fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.saveCorrection(library.id, expected: file, values: .init(title: "only first"))
        let other = NetworkLibrary(name: "other", scope: scope, root: library.root)
        try await store.add(other)
        let token = try await store.beginScan(other.id); try await store.commit(other.id, token: token, files: [file])
        let saved = try await store.libraries()
        XCTAssertNil(saved.first { $0.id == other.id }!.correction(for: file))
        do { try await store.saveCorrection(library.id, expected: .init(path: DAVPath("Other/a.mkv"), isDirectory: false), values: .init(title: "outside")); XCTFail() } catch { }
        try await store.remove(library.id)
        do { try await store.saveCorrection(library.id, expected: file, values: .init(title: "late")); XCTFail() } catch { }
        let reloaded = try await NetworkLibraryStore(directory: directory).libraries()
        XCTAssertEqual(reloaded.map(\.id), [other.id]); XCTAssertNil(reloaded[0].corrections)
    }
    func testCancelledSaveDoesNotWrite() async throws {
        let (directory, store, library, file) = try await fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("libraries-v1.json"), before = try Data(contentsOf: url)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await store.saveCorrection(library.id, expected: file, values: .init(title: "cancelled"))
        }
        do { try await task.value; XCTFail() } catch is CancellationError { }
        XCTAssertEqual(try Data(contentsOf: url), before)
    }
    func testInvalidFieldsIncludingDecodedValuesAreRejected() throws {
        for title in [" ", "bad\nname", String(repeating: "a", count: 513)] { XCTAssertThrowsError(try LocalMediaCorrection.Values(title: title)) }
        XCTAssertThrowsError(try LocalMediaCorrection.Values(title: "a", year: 999))
        XCTAssertThrowsError(try LocalMediaCorrection.Values(title: "a", kind: .episode, season: 0))
        XCTAssertThrowsError(try LocalMediaCorrection.Values(title: "a", kind: .episode, season: 0, episode: 2, episodeEnd: 1))
        XCTAssertThrowsError(try LocalMediaCorrection.Values(title: "a", kind: .movie, season: 1, episode: 1))
        let special = try LocalMediaCorrection.Values(title: "special", kind: .episode, season: 0, episode: 0, episodeEnd: 2)
        XCTAssertEqual(special.season, 0)
        XCTAssertThrowsError(try JSONDecoder().decode(LocalMediaCorrection.Values.self, from: Data(#"{"title":"x","year":999,"kind":"movie"}"#.utf8)))
    }
    func testDurableTVOverlaySurvivesCacheLossAndRemovalCannotResurrectIt() async throws {
        let suite = "CorrectionTests." + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let (directory, store, library, file) = try await fixture(catalog: defaults)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.saveCorrection(library.id, expected: file, values: .init(title: "电视修改"))
        let url = directory.appendingPathComponent("libraries-v1.json"), stale = try Data(contentsOf: url)
        try FileManager.default.removeItem(at: url)
        let recoveredStore = NetworkLibraryStore(directory: directory, catalog: defaults)
        var recovered = try await recoveredStore.libraries()[0]
        XCTAssertTrue(recovered.files.isEmpty); XCTAssertNil(recovered.lastCompletedScan)
        XCTAssertEqual(recovered.correction(for: file)?.values.title, "电视修改")
        let token = try await recoveredStore.beginScan(library.id)
        try await recoveredStore.commit(library.id, token: token, files: [file])
        recovered = try await recoveredStore.libraries()[0]
        XCTAssertTrue(recovered.correction(for: file)!.applies(to: file))
        try await recoveredStore.remove(library.id); try stale.write(to: url)
        let final = try await NetworkLibraryStore(directory: directory, catalog: defaults).libraries()
        XCTAssertTrue(final.isEmpty); XCTAssertNil(defaults.data(forKey: "networkMedia.sourceCatalog.v2"))
    }
    func testLegacyTVCatalogMigratesOnlyAfterSuccessfulWrite() async throws {
        let suite = "CorrectionTests." + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let library = NetworkLibrary(name: "legacy", scope: scope, root: try DAVPath("Movies"))
        let legacy = try JSONSerialization.data(withJSONObject: [["id": library.id.uuidString, "name": library.name, "address": library.address, "root": ["encodedSegments": library.root.encodedSegments]]])
        defaults.set(legacy, forKey: "networkMedia.sourceCatalog.v1")
        let store = NetworkLibraryStore(directory: directory, catalog: defaults)
        let recovered = try await store.libraries()
        XCTAssertEqual(recovered.map(\.id), [library.id]); XCTAssertNil(defaults.data(forKey: "networkMedia.sourceCatalog.v2"))
        let token = try await store.beginScan(library.id), file = try video()
        try await store.commit(library.id, token: token, files: [file])
        XCTAssertNil(defaults.data(forKey: "networkMedia.sourceCatalog.v1")); XCTAssertNotNil(defaults.data(forKey: "networkMedia.sourceCatalog.v2"))
    }
    func testWriteFailureKeepsCorrectionAndDurableCatalogUnchanged() async throws {
        let suite = "CorrectionTests." + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let (directory, store, library, file) = try await fixture(catalog: defaults)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.saveCorrection(library.id, expected: file, values: .init(title: "before"))
        let durable = defaults.data(forKey: "networkMedia.sourceCatalog.v2")
        let url = directory.appendingPathComponent("libraries-v1.json")
        try FileManager.default.removeItem(at: url); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        do { try await store.saveCorrection(library.id, expected: file, values: .init(title: "failure")); XCTFail() } catch { }
        XCTAssertEqual(defaults.data(forKey: "networkMedia.sourceCatalog.v2"), durable)
        let current = try await store.libraries()[0]
        XCTAssertEqual(current.correction(for: file)?.values.title, "before")
    }
    func testCorrectionBudgetFailsBeforeReplacingSnapshotOrCatalog() async throws {
        let suite = "CorrectionTests." + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let (directory, store, library, file) = try await fixture(catalog: defaults)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.saveCorrection(library.id, expected: file, values: .init(title: "preserved"))
        let url = directory.appendingPathComponent("libraries-v1.json"), before = try Data(contentsOf: url)
        let durable = defaults.data(forKey: "networkMedia.sourceCatalog.v2")
        var oversized = NetworkLibrary(name: "too many", scope: scope, root: library.root)
        oversized.corrections = try (0..<500).map { index in
            LocalMediaCorrection(file: RemoteMediaEntry(path: try DAVPath("Movies/\(index).mkv"), isDirectory: false),
                                 values: try .init(title: String(repeating: "x", count: 512)))
        }
        XCTAssertGreaterThan(try JSONEncoder().encode(oversized.corrections).count, 256 * 1024)
        do { try await store.add(oversized); XCTFail() } catch { XCTAssertEqual(error as? NetworkMediaError, .correctionLimit) }
        XCTAssertEqual(try Data(contentsOf: url), before)
        XCTAssertEqual(defaults.data(forKey: "networkMedia.sourceCatalog.v2"), durable)
    }
}
