#if canImport(ImageIO)
import XCTest
import ImageIO
@testable import NetworkMedia

final class LocalArtworkCacheTests: XCTestCase {
    static func image() -> Data {
        let bitmap = CGImage(width: 2, height: 3, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 8,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(repeating: 120, count: 24) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let bytes = NSMutableData()
        let encoder = CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(encoder, bitmap, nil); XCTAssertTrue(CGImageDestinationFinalize(encoder)); return bytes as Data
    }
    actor Source: ReadOnlyArtworkSource {
        let bytes: Data
        var count = 0, active = 0, maximumActive = 0
        init(_ bytes: Data) { self.bytes = bytes }
        func list(_ directory: DAVPath) async throws -> [RemoteMediaEntry] { XCTFail(); return [] }
        func readArtwork(_ reference: LocalArtworkReference, root: DAVPath) async throws -> Data {
            count += 1; active += 1; maximumActive = max(active, maximumActive); defer { active -= 1 }
            try await Task.sleep(nanoseconds: 100_000_000); return bytes
        }
    }
    func library(id: UUID = UUID(), address: String = "https://fixture.invalid/dav", account: String? = nil) throws -> NetworkLibrary {
        NetworkLibrary(id: id, name: "fixture", scope: try WebDAVScope(address: address), root: try DAVPath("M"), fileStationAccount: account)
    }
    func file(_ name: String = "a", version: String? = "\"v1\"") throws -> RemoteMediaEntry {
        var file = RemoteMediaEntry(path: try DAVPath("M/\(name).mkv"), isDirectory: false)
        let poster = RemoteMediaEntry(path: try DAVPath("M/\(name)-poster.png"), isDirectory: false, etag: version)
        file.metadata = .init(title: name, artwork: LocalArtworkReference(poster)); return file
    }
    func testRealImageDecoderRejectsHTMLSVGAndOversizedPayload() throws {
        XCTAssertNoThrow(try LocalArtworkDecoder.validate(Self.image()))
        for data in [Data(), Data("<html>login</html>".utf8), Data("<svg></svg>".utf8), Data(repeating: 0, count: LocalArtworkReference.maximumBytes + 1)] {
            XCTAssertThrowsError(try LocalArtworkDecoder.validate(data))
        }
    }
    func testCacheBindsEndpointAccountRootAndSourceAndRecoversCorruption() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = LocalArtworkCache(directory: folder), source = Source(Self.image()), library = try library(), file = try file()
        _ = try await cache.data(library: library, file: file, source: source)
        _ = try await cache.data(library: library, file: file, source: source)
        var count = await source.count; XCTAssertEqual(count, 1)
        let key = try LocalArtworkCache.key(library: library, reference: file.metadata!.artwork!)
        try Data("bad cached image".utf8).write(to: folder.appendingPathComponent(key))
        _ = try await cache.data(library: library, file: file, source: source)
        count = await source.count; XCTAssertEqual(count, 2)
        for changed in try [self.library(), self.library(id: library.id, address: "https://other.invalid/dav"), self.library(id: library.id, account: "other-account")] {
            XCTAssertNotEqual(try LocalArtworkCache.key(library: changed, reference: file.metadata!.artwork!), key)
        }
        var otherRoot = try self.library(id: library.id)
        otherRoot = NetworkLibrary(id: otherRoot.id, name: "same", scope: try WebDAVScope(address: otherRoot.address), root: try DAVPath())
        XCTAssertNotEqual(try LocalArtworkCache.key(library: otherRoot, reference: file.metadata!.artwork!), key)
        await cache.remove(library.id)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }
    func testUnversionedAndInvalidImagesAreNotPersisted() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = LocalArtworkCache(directory: folder), source = Source(Self.image()), library = try library(), file = try file(version: nil)
        _ = try await cache.data(library: library, file: file, source: source)
        _ = try await cache.data(library: library, file: file, source: source)
        let count = await source.count; XCTAssertEqual(count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        do { _ = try await cache.data(library: library, file: self.file(), source: Source(Data("login".utf8))); XCTFail() } catch { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }
    func testTransfersAreBoundedAndCancellationLeavesNoImage() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = LocalArtworkCache(directory: folder, maximumBytes: 1), source = Source(Self.image()), library = try library()
        let files = try (0..<6).map { try file(String($0)) }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for file in files { group.addTask { _ = try await cache.data(library: library, file: file, source: source) } }
            try await group.waitForAll()
        }
        let maximum = await source.maximumActive; XCTAssertLessThanOrEqual(maximum, 2)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        let task = Task { try await cache.data(library: library, file: file("cancelled"), source: source) }
        try await Task.sleep(nanoseconds: 20_000_000); task.cancel()
        do { _ = try await task.value; XCTFail() } catch is CancellationError { }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }
}
#endif
