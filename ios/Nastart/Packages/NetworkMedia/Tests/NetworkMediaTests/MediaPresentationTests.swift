import XCTest
@testable import NetworkMedia

final class MediaPresentationTests: XCTestCase {
    func file(_ path: String, metadata: LocalMediaMetadata? = nil) throws -> RemoteMediaEntry {
        .init(path: try DAVPath(path), isDirectory: false, metadata: metadata)
    }
    func testDiscStreamsBecomeOneCardWithoutLosingPhysicalFiles() throws {
        let files = try [file("M/Film/BDMV/STREAM/00001.m2ts"), file("M/Film/BDMV/STREAM/00002.m2ts"), file("M/Other.m2ts")]
        let groups = MediaPresentation.groups(files, root: try DAVPath("M"))
        XCTAssertEqual(groups.count, 2)
        let disc = try XCTUnwrap(groups.first { $0.kind == .bluRay })
        XCTAssertEqual(disc.title, "Film"); XCTAssertEqual(disc.files.count, 2)
        XCTAssertEqual(Set(groups.flatMap(\.files).map(\.id)), Set(files.map(\.id)))
        XCTAssertEqual(MediaPresentation.groups(files.reversed(), root: try DAVPath("M")).map(\.id), groups.map(\.id))
        XCTAssertEqual(MediaPresentation.groups(Array(files.prefix(2)), root: try DAVPath("M/Film/BDMV/STREAM")).count, 2)
    }
    func testOnlyContiguousUnambiguousCDsMerge() throws {
        let files = try [file("M/Film.CD1.mkv"), file("M/Film.CD2.mkv"), file("M/Other.Disc1.mp4"), file("M/Other.Disc3.mp4")]
        let groups = MediaPresentation.groups(files, root: try DAVPath("M"))
        XCTAssertEqual(groups.count, 3); XCTAssertEqual(groups.filter { $0.kind == .segments }.count, 1)
        XCTAssertEqual(groups.first { $0.kind == .segments }?.title, "Film")
        let duplicate = try file("M/Film.CD1.mp4")
        XCTAssertFalse(MediaPresentation.groups(Array(files.prefix(2)) + [duplicate], root: try DAVPath("M")).contains { $0.kind == .segments })
    }
    func testSequelsDifferentFoldersEpisodesAndConflictingNFOStaySeparate() throws {
        for paths in [["M/Film.Part1.mkv", "M/Film.Part2.mkv"], ["M/A/Film.CD1.mkv", "M/B/Film.CD2.mkv"], ["M/Show.S01E01.CD1.mkv", "M/Show.S01E02.CD2.mkv"]] {
            XCTAssertEqual(MediaPresentation.groups(try paths.map { try file($0) }, root: try DAVPath("M")).count, 2)
        }
        for metadata in [[LocalMediaMetadata(title: "A", providerIDs: ["tmdb": "1"], origin: .nfo), .init(title: "A", providerIDs: ["tmdb": "2"], origin: .nfo)], [.init(title: "A", year: 2000), .init(title: "A", year: 2001)], [.init(title: "A", origin: .nfo), .init(title: "B", origin: .nfo)]] {
            let files = try [file("M/Film.CD1.mkv", metadata: metadata[0]), file("M/Film.CD2.mkv", metadata: metadata[1])]
            XCTAssertEqual(MediaPresentation.groups(files, root: try DAVPath("M")).count, 2)
        }
    }
    func testSupplementsAreNotDeletedAndEpisodesAreNotHidden() throws {
        let files = try [file("M/Film-trailer.mp4"), file("M/Extras/Feature.mp4"), file("M/Extras/Show.S00E01.mkv"), file("M/The Trailer.mkv")]
        let groups = MediaPresentation.groups(files, root: try DAVPath("M"))
        XCTAssertEqual(groups.filter { $0.kind == .supplement }.count, 2)
        XCTAssertEqual(groups.flatMap(\.files).count, 4)
    }
    func testExistingDiscFolderNFOAndPosterAreReadOnceWithinRoot() async throws {
        let poster = try file("M/Film/poster.jpg"), nfo = try file("M/Film/movie.nfo")
        let files = try [file("M/Film/BDMV/STREAM/00001.m2ts"), file("M/Film/BDMV/STREAM/00002.m2ts")]
        let source = LocalMetadataTests.Source(entries: ["M/Film": [.init(path: try DAVPath("M/Film/BDMV"), isDirectory: true), nfo, poster], "M/Film/BDMV": [.init(path: try DAVPath("M/Film/BDMV/STREAM"), isDirectory: true)], "M/Film/BDMV/STREAM": files], data: [nfo.id: Data("<movie><title>Disc title</title><year>2000</year></movie>".utf8)])
        let scanned = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath("M/Film"))
        XCTAssertEqual(scanned.count, 2)
        XCTAssertTrue(scanned.allSatisfy { $0.metadata?.title == "Disc title" && $0.metadata?.artwork?.path == poster.path })
        let reads = await source.reads; XCTAssertEqual(reads, [nfo.id])
        let group = try XCTUnwrap(MediaPresentation.groups(scanned, root: try DAVPath("M/Film")).first)
        XCTAssertEqual(group.title, "Disc title")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = NetworkLibrary(name: "Disc", scope: try WebDAVScope(address: "https://fixture.invalid"), root: try DAVPath("M/Film"))
        let store = NetworkLibraryStore(directory: folder); try await store.add(library)
        let token = try await store.beginScan(library.id); try await store.commit(library.id, token: token, files: scanned)
        let restored = try await NetworkLibraryStore(directory: folder).libraries()
        XCTAssertEqual(restored.first?.files, scanned); XCTAssertEqual(restored.first?.artworkScanVersion, 5)
        let narrow = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath("M/Film/BDMV/STREAM"))
        XCTAssertTrue(narrow.allSatisfy { $0.metadata?.artwork == nil })
        let finalReads = await source.reads; XCTAssertEqual(finalReads, [nfo.id])
    }
    func testDiscPosterExceptionDoesNotPermitArbitraryAncestorOrOutsideRoot() throws {
        let video = try DAVPath("M/Film/BDMV/STREAM/00001.m2ts")
        XCTAssertTrue(LocalArtworkReference(try file("M/Film/poster.jpg")).isValid(root: try DAVPath("M"), video: video))
        for path in ["M/poster.jpg", "M/Other/poster.jpg", "M/Film/BDMV/poster.jpg"] {
            XCTAssertFalse(LocalArtworkReference(try file(path)).isValid(root: try DAVPath("M"), video: video))
        }
        XCTAssertFalse(LocalArtworkReference(try file("M/Film/poster.jpg")).isValid(root: try DAVPath("M/Film/BDMV/STREAM"), video: video))
    }
    func testSplitMoviesShareExistingFolderOutputButConflictingNFOBlocksPosterSharing() async throws {
        let a = try file("M/Film.CD1.mkv"), b = try file("M/Film.CD2.mkv"), nfo = try file("M/movie.nfo"), poster = try file("M/poster.jpg")
        let source = LocalMetadataTests.Source(entries: ["M": [a, b, nfo, poster]], data: [nfo.id: Data("<movie><title>Film</title></movie>".utf8)])
        let scanned = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath("M"))
        XCTAssertTrue(scanned.allSatisfy { $0.metadata?.title == "Film" && $0.metadata?.artwork?.path == poster.path })
        let na = try file("M/Film.CD1.nfo"), nb = try file("M/Film.CD2.nfo")
        let conflicting = LocalMetadataTests.Source(entries: ["M": [a, b, na, nb, poster]], data: [na.id: Data("<movie><title>A</title><tmdbid>1</tmdbid></movie>".utf8), nb.id: Data("<movie><title>B</title><tmdbid>2</tmdbid></movie>".utf8)])
        let separate = try await ReadOnlyLibraryScanner.scan(source: conflicting, root: DAVPath("M"))
        XCTAssertTrue(separate.allSatisfy { $0.metadata?.artwork == nil })
        XCTAssertEqual(MediaPresentation.groups(separate, root: try DAVPath("M")).count, 2)
    }
}
