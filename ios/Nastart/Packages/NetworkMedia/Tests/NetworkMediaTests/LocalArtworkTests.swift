import XCTest
@testable import NetworkMedia

final class LocalArtworkTests: XCTestCase {
    func entry(_ path: String, size: Int64? = nil, directory: Bool = false) throws -> RemoteMediaEntry {
        RemoteMediaEntry(path: try DAVPath(path), isDirectory: directory, size: size, modified: "2026", etag: "\"v1\"")
    }
    func testDetailBackdropUsesFanartRatherThanPosterAndKeepsLiteralNames() throws {
        let video = try entry("M/中文 100%.mkv"), poster = try entry("M/中文 100%-poster.jpg"),
            exact = try entry("M/中文 100%-fanart.jpg"), generic = try entry("M/fanart.jpg")
        let selected = LocalArtworkSelection(siblings: [video, poster, exact, generic])
        XCTAssertEqual(selected.backdropCandidate(video: video)?.path, exact.path)
        XCTAssertEqual(selected.candidate(video: video)?.path, poster.path)
        XCTAssertNil(LocalArtworkSelection(siblings: [video, poster]).backdropCandidate(video: video))
        XCTAssertEqual(LocalArtworkSelection(siblings: [video, generic]).backdropCandidate(video: video)?.path, generic.path)
    }
    func testDetailBackdropDoesNotBorrowGenericImageAcrossMoviesOrEpisodes() throws {
        let a = try entry("M/A.mkv"), b = try entry("M/B.mkv"), image = try entry("M/fanart.jpg")
        let selection = LocalArtworkSelection(siblings: [a, b, image])
        XCTAssertNil(selection.backdropCandidate(video: a)); XCTAssertNil(selection.backdropCandidate(video: b))
        let episode = try entry("M/Show.S01E01.mkv"), exact = try entry("M/Show.S01E01-backdrop.png")
        XCTAssertNil(LocalArtworkSelection(siblings: [episode, image]).backdropCandidate(video: episode))
        XCTAssertEqual(LocalArtworkSelection(siblings: [episode, image, exact]).backdropCandidate(video: episode)?.path, exact.path)
    }
    func testDetailBackdropRejectsAmbiguityOversizeDirectoryAndOutsideFolder() throws {
        let video = try entry("M/A.mkv")
        for candidates in try [[entry("M/A-fanart.jpg"), entry("M/a-FANART.JPG")],
                              [entry("M/A-fanart.jpg", size: Int64(LocalArtworkReference.maximumBytes + 1))],
                              [entry("Other/A-fanart.jpg")], [entry("M/A-fanart.jpg", directory: true)]] {
            XCTAssertNil(LocalArtworkSelection(siblings: [video] + candidates).backdropCandidate(video: video))
        }
    }
    func testTinyMediaManagerPosterNamesAndPriority() throws {
        let video = try entry("Movies/中文 100%.mkv"), exact = try entry("Movies/中文 100%-poster.jpg"), generic = try entry("Movies/poster.png")
        XCTAssertEqual(LocalArtworkSelection(siblings: [video, exact, generic]).candidate(video: video)?.path, exact.path)
        for name in ["poster.jpg", "movie.jpeg", "folder.png", "cover.jpg", "中文 100%.png", "中文 100%.poster.jpg"] {
            let poster = try entry("Movies/" + name)
            XCTAssertEqual(LocalArtworkSelection(siblings: [video, poster]).candidate(video: video)?.path, poster.path, name)
        }
    }
    func testSharedPosterIsNotAssignedToMultipleMoviesOrEpisodes() throws {
        let a = try entry("M/a.mkv"), b = try entry("M/b.mp4"), generic = try entry("M/poster.jpg"), exact = try entry("M/a-poster.jpg")
        let selection = LocalArtworkSelection(siblings: [a, b, generic, exact])
        XCTAssertEqual(selection.candidate(video: a)?.path, exact.path)
        XCTAssertNil(selection.candidate(video: b))
        let episode = try entry("M/Show.S01E01.mkv")
        XCTAssertNil(LocalArtworkSelection(siblings: [episode, generic]).candidate(video: episode))
    }
    func testTMMEpisodeThumbUsesExactStemAndDoesNotBorrowSeriesOrMovieImages() throws {
        let episode = try entry("M/Show.S01E01.mkv"), thumb = try entry("M/Show.S01E01-thumb.jpg")
        let other = try entry("M/Show.S01E02.mkv"), poster = try entry("M/poster.jpg")
        let selection = LocalArtworkSelection(siblings: [episode, other, thumb, poster])
        XCTAssertEqual(selection.candidate(video: episode)?.path, thumb.path)
        XCTAssertNil(selection.candidate(video: other))
        let movie = try entry("M/Movie.mkv"), movieThumb = try entry("M/Movie-thumb.jpg")
        XCTAssertNil(LocalArtworkSelection(siblings: [movie, movieThumb]).candidate(video: movie))
        let exactPoster = try entry("M/Show.S01E01-poster.png")
        XCTAssertEqual(LocalArtworkSelection(siblings: [episode, thumb, exactPoster]).candidate(video: episode)?.path, exactPoster.path)
        let duplicate = try entry("M/SHOW.S01E01-THUMB.JPG")
        XCTAssertNil(LocalArtworkSelection(siblings: [episode, thumb, duplicate]).candidate(video: episode))
    }
    func testEpisodeNFOIdentityCanSelectThumbWithoutSeasonEpisodeFilename() async throws {
        let video = try entry("M/01.mkv"), nfo = try entry("M/01.nfo"), thumb = try entry("M/01-thumb.png")
        let source = LocalMetadataTests.Source(entries: ["M": [video, nfo, thumb]], data: [nfo.id: Data("<episodedetails><title>Episode</title><season>1</season><episode>1</episode></episodedetails>".utf8)])
        let files = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath("M"))
        XCTAssertEqual(files[0].metadata?.kind, .episode)
        XCTAssertEqual(files[0].metadata?.artwork?.path, thumb.path)
        let generic = try entry("M/poster.jpg")
        let shared = LocalMetadataTests.Source(entries: ["M": [video, nfo, generic]], data: [nfo.id: Data("<episodedetails><title>Episode</title></episodedetails>".utf8)])
        let unassigned = try await ReadOnlyLibraryScanner.scan(source: shared, root: DAVPath("M"))
        XCTAssertNil(unassigned[0].metadata?.artwork)
    }
    func testAmbiguousCaseOversizeAndWrongParentAreNotGuessed() throws {
        let video = try entry("M/a.mkv")
        for siblings in try [[entry("M/a-poster.jpg"), entry("M/A-POSTER.JPG")],
                         [entry("M/a-poster.jpg", size: Int64(LocalArtworkReference.maximumBytes + 1))],
                         [entry("Other/a-poster.jpg")], [entry("M/a-poster.jpg", directory: true)]] {
            XCTAssertNil(LocalArtworkSelection(siblings: [video] + siblings).candidate(video: video))
        }
    }
    func testScannerRecordsArtworkWithoutDownloadingImagesOrVideos() async throws {
        let video = try entry("M/a.mkv"), nfo = try entry("M/a.nfo"), poster = try entry("M/a-poster.jpg", size: 123)
        let source = LocalMetadataTests.Source(entries: ["M": [video, nfo, poster]], data: ["M/a.nfo": Data("<movie><title>已有资料</title><thumb>https://external.invalid/evil.jpg</thumb></movie>".utf8)])
        let files = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath("M"))
        XCTAssertEqual(files[0].metadata?.artwork?.path, poster.path)
        XCTAssertEqual(files[0].metadata?.title, "已有资料")
        let reads = await source.reads; XCTAssertEqual(reads, ["M/a.nfo"])
        XCTAssertEqual(try JSONDecoder().decode([RemoteMediaEntry].self, from: JSONEncoder().encode(files)), files)
    }
    func testOldSnapshotLoadsAndArtworkScopeFailureKeepsCompleteSnapshot() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = NetworkLibrary(name: "old", scope: try WebDAVScope(address: "https://fixture.invalid/dav"), root: try DAVPath("M"))
        let store = NetworkLibraryStore(directory: folder); try await store.add(library)
        let oldFile = try entry("M/a.mkv"), first = try await store.beginScan(library.id)
        try await store.commit(library.id, token: first, files: [oldFile])
        let path = folder.appendingPathComponent("libraries-v1.json"), before = try Data(contentsOf: path)
        var object = try JSONSerialization.jsonObject(with: before) as! [String: Any]
        var rows = object["libraries"] as! [[String: Any]]; rows[0].removeValue(forKey: "artworkScanVersion"); object["libraries"] = rows
        try JSONSerialization.data(withJSONObject: object).write(to: path)
        let loaded = try await NetworkLibraryStore(directory: folder).libraries(); XCTAssertEqual(loaded.first?.files, [oldFile]); XCTAssertNil(loaded.first?.artworkScanVersion)
        var bad = oldFile; bad.metadata = .init(title: "wrong", artwork: LocalArtworkReference(try entry("Outside/a.jpg")))
        let token = try await store.beginScan(library.id), preserved = try Data(contentsOf: path)
        do { try await store.commit(library.id, token: token, files: [bad]); XCTFail("outside artwork must be rejected") } catch { }
        XCTAssertEqual(try Data(contentsOf: path), preserved)
        let actual = try await store.libraries(); XCTAssertEqual(actual[0].files, [oldFile])
    }
    actor Transport: WebDAVArtworkTransport {
        var requests: [URLRequest] = []
        let data: Data
        init(_ data: Data) { self.data = data }
        func propfind(_ request: URLRequest, credential: WebDAVCredential?) async throws -> Data { XCTFail(); return Data() }
        func readArtwork(_ request: URLRequest, credential: WebDAVCredential?) async throws -> Data { requests.append(request); return data }
    }
    func testImageRequestIsLiteralBoundedGETWithVersionAndNoVideoOrOutsideRead() async throws {
        let bytes = Data([1, 2, 3]), transport = Transport(bytes)
        let client = WebDAVClient(scope: try WebDAVScope(address: "https://fixture.invalid/dav"), transport: transport)
        let reference = LocalArtworkReference(try entry("M/中文 100%-poster.jpg", size: 3))
        let actual = try await client.readArtwork(reference, root: DAVPath("M")); XCTAssertEqual(actual, bytes)
        let requests = await transport.requests; XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].httpMethod, "GET"); XCTAssertEqual(requests[0].value(forHTTPHeaderField: "If-Match"), "\"v1\"")
        XCTAssertEqual(requests[0].url?.path, "/dav/M/中文 100%-poster.jpg"); XCTAssertNil(requests[0].url?.query)
        for path in ["M/a.mkv", "Other/a.jpg", "M/a.svg"] {
            do { _ = try await client.readArtwork(LocalArtworkReference(entry(path)), root: DAVPath("M")); XCTFail(path) } catch { }
        }
        let count = await transport.requests.count; XCTAssertEqual(count, 1)
        let wrongSize = LocalArtworkReference(try entry("M/a.jpg", size: 4))
        do { _ = try await client.readArtwork(wrongSize, root: DAVPath("M")); XCTFail() }
        catch { XCTAssertEqual(error as? NetworkMediaError, .invalidArtwork) }
    }
}
