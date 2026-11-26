import XCTest
@testable import NetworkMedia

final class NetworkMediaPlaybackSourceTests: XCTestCase {
    private func fixture() throws -> (NetworkLibrary, RemoteMediaEntry) {
        var library = NetworkLibrary(name: "fixture", scope: try WebDAVScope(address: "https://nas.example.test/dav/"), root: try DAVPath("media"))
        let file = RemoteMediaEntry(path: try DAVPath("media/movie.mkv"), isDirectory: false, size: 4096, etag: "\"one\"")
        library.files = [file]; return (library, file)
    }
    func testRendererCapabilityAndOriginRemainSeparate() throws {
        let (library, file) = try fixture()
        let renderer = URL(string: "http://127.0.0.1:49152/capability/video.mkv")!
        let source = try NetworkMediaPlaybackSource(library: library, file: file, playbackURL: renderer, title: "Movie")
        XCTAssertEqual(source.playbackURL, renderer)
        XCTAssertEqual(source.originURL, URL(string: "https://nas.example.test/dav/"))
        XCTAssertEqual(source.byteCount, 4096); XCTAssertEqual(source.fileExtension, "mkv")
        XCTAssertNil(source.originURL.user); XCTAssertNil(source.originURL.password); XCTAssertNil(source.playbackURL?.query)
    }
    func testReaderUsesSameVersionIdentityWithoutStartingABridge() throws {
        let (library, file) = try fixture()
        let direct = try NetworkMediaPlaybackSource(library: library, file: file, credential: nil, title: "Movie")
        let bridge = try NetworkMediaPlaybackSource(library: library, file: file,
            playbackURL: URL(string: "http://127.0.0.1:49152/capability/video.mkv")!, title: "Movie")
        guard case .reader(let reader) = direct.transport else { return XCTFail("Expected direct Reader") }
        XCTAssertNil(direct.playbackURL)
        XCTAssertEqual(reader.byteCount, direct.byteCount)
        XCTAssertEqual(reader.fileName, "movie.mkv")
        XCTAssertEqual(direct.stableID, bridge.stableID)
        XCTAssertEqual(direct.originURL, bridge.originURL)
    }
    func testReopeningBridgeDoesNotChangeFileIdentity() throws {
        let (library, file) = try fixture()
        let first = try NetworkMediaPlaybackSource(library: library, file: file,
            playbackURL: URL(string: "http://127.0.0.1:49152/first/video.mkv")!, title: "First title")
        let reopened = try NetworkMediaPlaybackSource(library: library, file: file,
            playbackURL: URL(string: "http://127.0.0.1:49153/second/video.mkv")!, title: "Corrected title")
        XCTAssertEqual(first.stableID, reopened.stableID)
    }
    func testDifferentSourceVersionsAndLibraryScopesDoNotShareBookmarks() throws {
        var (library, file) = try fixture()
        let renderer = URL(string: "http://127.0.0.1:49152/capability/video.mkv")!
        let original = try NetworkMediaPlaybackSource(library: library, file: file, playbackURL: renderer, title: "Movie")
        file = RemoteMediaEntry(path: file.path, isDirectory: false, size: 4096, etag: "\"two\"")
        library.files = [file]
        let changed = try NetworkMediaPlaybackSource(library: library, file: file, playbackURL: renderer, title: "Movie")
        let (otherLibrary, otherFile) = try fixture()
        let otherScope = try NetworkMediaPlaybackSource(library: otherLibrary, file: otherFile, playbackURL: renderer, title: "Movie")
        XCTAssertNotEqual(original.stableID, changed.stableID)
        XCTAssertNotEqual(original.stableID, otherScope.stableID)
    }
    func testOriginCannotReplaceRendererOrCarryCredentials() throws {
        let (library, file) = try fixture()
        for text in ["https://nas.example.test/dav/media/movie.mkv", "http://user:secret@127.0.0.1:49152/video.mkv",
            "http://127.0.0.1:49152/video.mkv?token=secret", "http://127.0.0.1:49152/video.mkv#fragment"] {
            XCTAssertThrowsError(try NetworkMediaPlaybackSource(library: library, file: file, playbackURL: URL(string: text)!, title: "Movie"))
        }
    }
    func testDescriptorDoesNotBypassIndexedVersionOrRootGuards() throws {
        var (library, file) = try fixture()
        let renderer = URL(string: "http://127.0.0.1:49152/capability/video.mkv")!
        library.files = []
        XCTAssertThrowsError(try NetworkMediaPlaybackSource(library: library, file: file, playbackURL: renderer, title: "Movie"))
        let unknownVersion = RemoteMediaEntry(path: file.path, isDirectory: false, size: 4096)
        library.files = [unknownVersion]
        XCTAssertThrowsError(try NetworkMediaPlaybackSource(library: library, file: unknownVersion, playbackURL: renderer, title: "Movie"))
        XCTAssertThrowsError(try NetworkMediaPlaybackSource(library: library, file: unknownVersion, credential: nil, title: "Movie"))
    }
}
