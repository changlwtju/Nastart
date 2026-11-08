import XCTest
@testable import NetworkMedia

final class MediaCatalogTests: XCTestCase {
    func testCatalogCacheInvalidatesCorrectionsFileVersionsAndRemovedLibraries() async throws {
        let cache = MediaCatalogCache()
        let raw = RemoteMediaEntry(path: try DAVPath("TV/Show.S01E01.mkv"), isDirectory: false,
            size: 10, etag: "v1", metadata: .init(title: "原集名", kind: .episode, season: 1, episode: 1))
        var value = try library([raw])
        let first = try await cache.catalogs(for: [value])
        XCTAssertEqual(first[value.id]?.first?.category, .television)
        value.corrections = [LocalMediaCorrection(file: raw, values: try .init(title: "本机电影", kind: .movie))]
        let corrected = try await cache.catalogs(for: [value])
        XCTAssertEqual(corrected[value.id]?.first?.title, "本机电影")
        XCTAssertEqual(corrected[value.id]?.first?.category, .movies)
        XCTAssertEqual(value.files, [raw])
        let changed = RemoteMediaEntry(path: raw.path, isDirectory: false, size: raw.size,
            etag: "v2", metadata: raw.metadata)
        value.files = [changed]
        let updated = try await cache.catalogs(for: [value])
        XCTAssertEqual(updated[value.id]?.first?.category, .television)
        XCTAssertEqual(updated[value.id]?.first?.files.first?.etag, "v2")
        let removed = try await cache.catalogs(for: [])
        XCTAssertTrue(removed.isEmpty)
        value.files = []
        let readded = try await cache.catalogs(for: [value])
        XCTAssertEqual(readded[value.id]?.count, 0)
    }

    func testCatalogCacheKeepsLibrariesAndSelectedRootsIndependent() async throws {
        let cache = MediaCatalogCache()
        let file = try entry("Show/Season 1/Show.S01E01.mkv")
        var broad = try library([file]), narrow = try library([file], root: "Show/Season 1")
        let first = try await cache.catalogs(for: [broad, narrow])
        XCTAssertEqual(first[broad.id]?.first?.series?.folder.key, "Show")
        XCTAssertEqual(first[narrow.id]?.first?.series?.folder, narrow.root)
        broad.files = []
        let next = try await cache.catalogs(for: [broad, narrow])
        XCTAssertEqual(next[broad.id]?.count, 0)
        XCTAssertEqual(next[narrow.id]?.first?.files, [file])
    }

    func entry(_ path: String, directory: Bool = false, metadata: LocalMediaMetadata? = nil) throws -> RemoteMediaEntry {
        .init(path: try DAVPath(path), isDirectory: directory, metadata: metadata)
    }
    func library(_ files: [RemoteMediaEntry], root: String = "", address: String = "https://fixture.invalid/dav") throws -> NetworkLibrary {
        var value = NetworkLibrary(name: "Media", scope: try WebDAVScope(address: address), root: try DAVPath(root))
        value.files = files; return value
    }
    func testCategoriesUseDirectoriesNFOAndKeepUnknownHonest() throws {
        let files = try [entry("电影/Film.mkv"), entry("电视剧/Show.S01E01.mkv"), entry("动漫/Anime.S01E01.mkv"),
                         entry("动漫/Feature.mkv", metadata: .init(title: "Feature", kind: .movie)), entry("Uncertain.mkv")]
        let items = MediaCatalog.items(try library(files))
        XCTAssertEqual(items.filter { $0.category == .movies }.count, 1)
        XCTAssertEqual(items.filter { $0.category == .television }.count, 1)
        XCTAssertEqual(items.filter { $0.category == .animation }.count, 2)
        XCTAssertEqual(items.filter { $0.category == .unclassified }.count, 1)
        XCTAssertEqual(Set(items.flatMap(\.files).map(\.id)), Set(files.map(\.id)))
        XCTAssertEqual(MediaCatalog.items(try library([entry("Feature.mkv")], address: "https://fixture.invalid/动漫"))[0].category, .animation)
    }
    func testSeriesSeasonsSpecialsUnknownAndEpisodeOrder() throws {
        let info = LocalSeriesMetadata(folder: try DAVPath("TV/Show"), title: "剧名")
        let files = try [entry("TV/Show/Season 1/Show.S01E10.mkv", metadata: .init(title: "第十集", kind: .episode, season: 1, episode: 10, series: info)),
                         entry("TV/Show/Season 1/Show.S01E02.mkv", metadata: .init(title: "第二集", kind: .episode, season: 1, episode: 2, series: info)),
                         entry("TV/Show/Specials/a.mkv", metadata: .init(title: "特典", kind: .episode, season: 0, episode: 1, series: info)),
                         entry("TV/Show/Unknown.mkv", metadata: .init(title: "无季数", kind: .episode, series: info))]
        let catalog = MediaCatalog.items(try library(files)), series = try XCTUnwrap(catalog.first?.series)
        XCTAssertEqual(catalog.count, 1); XCTAssertEqual(series.title, "剧名")
        XCTAssertEqual(series.seasons.map(\.number), [0, 1, nil]); XCTAssertEqual(series.seasons.last?.title, "未分季")
        XCTAssertEqual(series.seasons[1].files.map { $0.metadata?.episode }, [2, 10])
        XCTAssertEqual(series.files.count, 4)
    }
    func testFlatDifferentShowsAndSeparateEditionsNeverCollapse() throws {
        let files = try [entry("TV/Alpha.S01E01.mkv"), entry("TV/Alpha.S02E01.mkv"), entry("TV/Beta.S01E01.mkv"), entry("Other/Alpha.S01E01.mkv")]
        let items = MediaCatalog.items(try library(files))
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items.first { $0.series?.folder.key == "TV" && $0.title == "Alpha" }?.files.count, 2)
        XCTAssertEqual(Set(items.flatMap(\.files).map(\.id)), Set(files.map(\.id)))
        XCTAssertEqual(MediaCatalog.items(try library(files.reversed())).map(\.id).sorted(), items.map(\.id).sorted())
    }
    func testSeasonFolderFallbackAndSelectedRootAreRespected() throws {
        let files = try [entry("Show/Season 1/Show.S01E01.mkv"), entry("Show/Season 2/Show.S02E01.mkv")]
        XCTAssertEqual(MediaCatalog.items(try library(files))[0].series?.seasons.count, 2)
        let narrow = try library([files[0]], root: "Show/Season 1")
        XCTAssertEqual(MediaCatalog.items(narrow)[0].series?.folder, narrow.root)
        XCTAssertEqual(SeriesLayout.season("第2季"), 2); XCTAssertEqual(SeriesLayout.season("Specials"), 0)
        XCTAssertNil(SeriesLayout.season("Something 2"))
    }
    func testSeriesNFORejectsExternalEntitiesDuplicateForeignAndEpisodeRoots() throws {
        let folder = try DAVPath("TV/Show")
        let info = try NFOReader.parseSeries(Data("<tvshow><title>剧名</title><year>2024</year><plot>已有简介</plot><thumb>https://external.invalid/image.jpg</thumb></tvshow>".utf8), folder: folder)
        XCTAssertEqual(info.title, "剧名"); XCTAssertEqual(info.year, 2024); XCTAssertNil(info.artwork)
        for xml in ["<episodedetails><title>A</title></episodedetails>", "<tvshow><title>A</title><title>B</title></tvshow>", "<tvshow xmlns='foreign'><title>A</title></tvshow>", "<!DOCTYPE tvshow [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><tvshow><title>&x;</title></tvshow>"] {
            XCTAssertThrowsError(try NFOReader.parseSeries(Data(xml.utf8), folder: folder))
        }
        let episode = try NFOReader.parse(Data("<episodedetails><title>单集名称</title><showtitle>剧名</showtitle><episode>3</episode></episodedetails>".utf8), fallback: .init(title: "03"), path: DAVPath("03.nfo"))
        XCTAssertEqual(episode.showTitle, "剧名"); XCTAssertNil(episode.season)
    }
    func testScannerInheritsOnlyListedSeriesPosterWithinSelectedRoot() async throws {
        let source = try LocalMetadataTests.Source(entries: [
            "TV/Show": [entry("TV/Show/tvshow.nfo"), entry("TV/Show/poster.jpg"), entry("TV/Show/Season 1", directory: true)],
            "TV/Show/Season%201": [entry("TV/Show/Season 1/Show.S01E01.mkv"), entry("TV/Show/Season 1/Show.S01E01-thumb.jpg")]
        ], data: ["TV/Show/tvshow.nfo": Data("<tvshow><title>剧名</title></tvshow>".utf8)])
        let files = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath("TV/Show"))
        XCTAssertEqual(files.count, 1); let first = try XCTUnwrap(files.first)
        XCTAssertEqual(first.metadata?.series?.title, "剧名")
        XCTAssertEqual(first.metadata?.series?.artwork?.path.key, "TV/Show/poster.jpg")
        XCTAssertEqual(first.metadata?.artwork?.path.name, "Show.S01E01-thumb.jpg")
        let reads = await source.reads; XCTAssertEqual(reads, ["TV/Show/tvshow.nfo"])
        let narrow = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath("TV/Show/Season 1"))
        XCTAssertNil(try XCTUnwrap(narrow.first).metadata?.series)
        let finalReads = await source.reads; XCTAssertEqual(finalReads, reads)
        XCTAssertEqual(try JSONDecoder().decode([RemoteMediaEntry].self, from: JSONEncoder().encode(files)), files)
    }
    func testAmbiguousFlatShowsDoNotShareGenericSeriesPoster() async throws {
        let source = try LocalMetadataTests.Source(entries: ["TV": [entry("TV/A.S01E01.mkv"), entry("TV/B.S01E01.mkv"), entry("TV/poster.jpg")]], data: [:])
        let files = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath("TV"))
        XCTAssertTrue(files.allSatisfy { $0.metadata?.series == nil && $0.metadata?.artwork == nil })
        XCTAssertEqual(MediaCatalog.items(try library(files, root: "TV")).count, 2)
    }
    func testOutsideSeriesPosterCannotReplaceSavedIndex() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NetworkLibraryStore(directory: directory), value = try library([], root: "TV")
        try await store.add(value)
        let good = try entry("TV/Show/S01E01.mkv", metadata: .init(title: "Episode", kind: .episode, series: .init(folder: DAVPath("TV/Show"), title: "Show")))
        let first = try await store.beginScan(value.id); try await store.commit(value.id, token: first, files: [good])
        let path = directory.appendingPathComponent("libraries-v1.json"), before = try Data(contentsOf: path)
        var bad = good
        bad.metadata?.series?.artwork = LocalArtworkReference(try entry("TV/Other/poster.jpg"))
        let token = try await store.beginScan(value.id)
        do { try await store.commit(value.id, token: token, files: [bad]); XCTFail("cross-folder series poster") } catch { }
        XCTAssertEqual(try Data(contentsOf: path), before)
    }
    func testLocalTypeSeasonEpisodeCorrectionsAffectCatalogWithoutChangingRawNFO() throws {
        let raw = RemoteMediaEntry(path: try DAVPath("TV/Show/01.mkv"), isDirectory: false, size: 10, etag: "v1",
            metadata: .init(title: "原集名", kind: .episode, season: 1, episode: 1, origin: .nfo,
                            series: .init(folder: try DAVPath("TV/Show"), title: "剧名")))
        var value = try library([raw])
        value.corrections = [LocalMediaCorrection(file: raw, values: try .init(title: "本机集名", kind: .episode, season: 2, episode: 3))]
        let series = try XCTUnwrap(MediaCatalog.items(value).first?.series)
        XCTAssertEqual(series.title, "剧名"); XCTAssertEqual(series.seasons.map(\.number), [2])
        XCTAssertEqual(series.files.first?.metadata?.episode, 3)
        XCTAssertEqual(series.files.first?.metadata?.title, "本机集名")
        XCTAssertEqual(value.files, [raw]); XCTAssertEqual(raw.metadata?.season, 1)
        value.corrections = [LocalMediaCorrection(file: raw, values: try .init(title: "其实是电影", kind: .movie))]
        let movie = try XCTUnwrap(MediaCatalog.items(value).first)
        XCTAssertEqual(movie.category, .movies); XCTAssertNil(movie.series)
        XCTAssertEqual(movie.movie?.title, "其实是电影"); XCTAssertNil(movie.files.first?.metadata?.series)
        let changed = RemoteMediaEntry(path: raw.path, isDirectory: false, size: raw.size, etag: "v2", metadata: raw.metadata)
        value.files = [changed]
        XCTAssertEqual(MediaCatalog.items(value).first?.series?.seasons.first?.number, 1)
        value.files = [raw]; value.corrections = nil
        XCTAssertEqual(MediaCatalog.items(value).first?.series?.files.first?.metadata?.title, "原集名")
    }
}
