import XCTest
@testable import NetworkMedia

final class MediaWallSelectionTests: XCTestCase {
    private func file(_ path: String, title: String, episode: Int? = nil) throws -> RemoteMediaEntry {
        .init(path: try DAVPath(path), isDirectory: false,
            metadata: .init(title: title, kind: episode == nil ? .movie : .episode,
                season: episode == nil ? nil : 1, episode: episode))
    }
    private func catalog(_ files: [RemoteMediaEntry]) throws -> [MediaCatalogItem] {
        var value = NetworkLibrary(name: "Synthetic", scope: try WebDAVScope(address: "https://fixture.invalid/dav"), root: try DAVPath())
        value.files = files
        return MediaCatalog.items(value)
    }
    private func select(_ catalog: [MediaCatalogItem], preferred: MediaCategory? = nil, query: String = "",
                        expanded: Bool = false) -> MediaWallSelection {
        .init(catalog: catalog, preferredCategory: preferred, query: query, includesSupplements: expanded,
            fileTitle: { $0.metadata?.title ?? $0.path.name })
    }
    func testValidCategoryAndDisplayOrderSurviveCatalogReordering() throws {
        let values = try catalog([file("动漫/Feature.mkv", title: "动画"),
            file("TV/Show.S01E01.mkv", title: "剧集", episode: 1), file("Movies/Film.mkv", title: "电影")])
        for input in [values, Array(values.reversed())] {
            let result = select(input, preferred: .animation)
            XCTAssertEqual(result.categories, [.movies, .television, .animation])
            XCTAssertEqual(result.activeCategory, .animation)
            XCTAssertEqual(result.visibleItems.map(\.title), ["动画"])
            XCTAssertEqual(result.emptyState, .none)
        }
    }
    func testRemovedCategoryFallsBackAndDoesNotReturnWhenOldCategoryReappears() throws {
        let movie = try file("Movies/Film.mkv", title: "电影"), show = try file("TV/Show.S01E01.mkv", title: "剧集", episode: 1)
        let first = select(try catalog([movie, show]), preferred: .television)
        let refreshed = select(try catalog([movie]), preferred: first.activeCategory)
        XCTAssertEqual(refreshed.categories, [.movies])
        XCTAssertEqual(refreshed.activeCategory, .movies)
        XCTAssertEqual(refreshed.visibleItems.flatMap(\.files), [movie])
        XCTAssertEqual(refreshed.emptyState, .none)
        // The view retains the resolved selection after a refresh.
        let returned = select(try catalog([movie, show]), preferred: refreshed.activeCategory)
        XCTAssertEqual(returned.activeCategory, .movies)
    }
    func testWhitespaceIsAnEmptyQueryAndStaleSelectionCannotHideMovies() throws {
        let values = try catalog([file("Movies/Film.mkv", title: "电影")])
        let result = select(values, preferred: .television, query: " \n\t ")
        XCTAssertEqual(result.query, "")
        XCTAssertEqual(result.activeCategory, .movies)
        XCTAssertEqual(result.visibleItems.map(\.id), values.map(\.id))
        XCTAssertEqual(result.emptyState, .none)
    }
    func testInitialResolvedCategoryCanBeRetainedWhenNewCategoryArrives() throws {
        let show = try file("TV/Show.S01E01.mkv", title: "剧集", episode: 1)
        let initial = select(try catalog([show]))
        XCTAssertEqual(initial.activeCategory, .television)
        let refreshed = select(try catalog([file("Movies/New.mkv", title: "新电影"), show]),
            preferred: initial.activeCategory)
        XCTAssertEqual(refreshed.categories, [.movies, .television])
        XCTAssertEqual(refreshed.activeCategory, .television)
        XCTAssertEqual(refreshed.visibleItems.flatMap(\.files), [show])
    }
    func testSearchStaysInCurrentCategoryAndClearingKeepsItSelected() throws {
        let values = try catalog([file("Movies/Film.mkv", title: "仅电影匹配"),
            file("TV/Show.S01E01.mkv", title: "剧集", episode: 1)])
        let result = select(values, preferred: .television, query: "仅电影匹配")
        XCTAssertEqual(result.activeCategory, .television)
        XCTAssertEqual(result.emptyState, .noResults)
        XCTAssertTrue(result.visibleItems.isEmpty)
        let cleared = select(values, preferred: result.activeCategory)
        XCTAssertEqual(cleared.activeCategory, .television)
        XCTAssertEqual(cleared.visibleItems.count, 1)
        XCTAssertEqual(cleared.emptyState, .none)
    }
    func testSearchUsesDisplayCorrectionAndFilenameWithoutChangingFiles() throws {
        let raw = try file("Movies/Archive.Source.mkv", title: "原题名"), values = try catalog([raw])
        let corrected = MediaWallSelection(catalog: values, preferredCategory: .movies, query: " LOCAL MATCH ",
            includesSupplements: false, fileTitle: { _ in "Local Match" })
        XCTAssertEqual(corrected.visibleItems.flatMap(\.files), [raw])
        let filename = select(values, query: "archive.source")
        XCTAssertEqual(filename.visibleItems.flatMap(\.files), [raw])
        XCTAssertEqual(values.flatMap(\.files), [raw])
    }
    func testSearchKeepsWholeSegmentedMovieAndSeries() throws {
        let values = try catalog([file("Movies/Film.CD1.mkv", title: "电影"), file("Movies/Film.CD2.mkv", title: "电影"),
            file("TV/Show.S01E01.mkv", title: "第一集", episode: 1), file("TV/Show.S01E02.mkv", title: "第二集", episode: 2)])
        for (category, query) in [(MediaCategory.movies, "CD2"), (.television, "S01E02")] {
            let result = select(values, preferred: category, query: query)
            XCTAssertEqual(result.visibleItems.count, 1)
            XCTAssertEqual(result.visibleItems.first?.files.count, 2)
            XCTAssertEqual(result.emptyState, .none)
        }
    }
    func testHiddenExtrasAreExplicitAndCanBeRevealedAfterSearch() throws {
        let raw = try file("Movies/extras/Behind.mkv", title: "幕后资料")
        let values = try catalog([file("Movies/Film.mkv", title: "电影"), raw])
        let hidden = select(values, preferred: .movies, query: "幕后资料")
        XCTAssertEqual(hidden.matches.flatMap(\.files), [raw])
        XCTAssertTrue(hidden.visibleItems.isEmpty)
        XCTAssertEqual(hidden.emptyState, .supplementsHidden)
        let shown = select(values, preferred: hidden.activeCategory, query: hidden.query, expanded: true)
        XCTAssertEqual(shown.visibleItems.flatMap(\.files), [raw])
        XCTAssertEqual(shown.emptyState, .none)
        let cleared = select(values, preferred: .movies)
        XCTAssertEqual(cleared.visibleItems.count, 1)
        XCTAssertEqual(cleared.emptyState, .none)
    }
    func testEmptyCatalogIsHonestEvenWithOldCategoryAndQuery() {
        let result = select([], preferred: .animation, query: "旧关键词")
        XCTAssertTrue(result.categories.isEmpty)
        XCTAssertNil(result.activeCategory)
        XCTAssertTrue(result.visibleItems.isEmpty)
        XCTAssertEqual(result.emptyState, .libraryEmpty)
    }
}
