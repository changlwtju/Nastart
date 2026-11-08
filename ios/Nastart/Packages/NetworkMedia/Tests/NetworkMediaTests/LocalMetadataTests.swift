import XCTest
@testable import NetworkMedia

final class LocalMetadataTests: XCTestCase {
    func entry(_ name: String, directory: Bool = false, size: Int64? = nil) throws -> RemoteMediaEntry {
        RemoteMediaEntry(path: try DAVPath(name), isDirectory: directory, size: size)
    }
    func testFilenameYearUnicodeAndAmbiguousNumericTitles() throws {
        let movie = MediaFilenameParser.identify(try DAVPath("Movies/流浪地球.2019.2160p.WEB-DL.mkv"))
        XCTAssertEqual(movie.title, "流浪地球"); XCTAssertEqual(movie.year, 2019)
        XCTAssertEqual(movie.origin, .filename); XCTAssertEqual(movie.kind, .unknown); XCTAssertTrue(movie.providerIDs.isEmpty)
        for name in ["1917", "2001 A Space Odyssey", "Blade Runner 2049"] {
            let result = MediaFilenameParser.identify(try DAVPath(name + ".mkv"))
            XCTAssertEqual(result.title, name); XCTAssertNil(result.year)
        }
        let bracketed = MediaFilenameParser.identify(try DAVPath("电影 (2024).mkv"))
        XCTAssertEqual(bracketed.title, "电影"); XCTAssertEqual(bracketed.year, 2024)
    }
    func testEpisodeSpecialsAndMultiEpisodeHints() throws {
        let a = MediaFilenameParser.identify(try DAVPath("Series/示例剧.S00E01E02.1080p.mkv"))
        XCTAssertEqual(a.title, "示例剧"); XCTAssertEqual(a.kind, .episode)
        XCTAssertEqual(a.season, 0); XCTAssertEqual(a.episode, 1); XCTAssertEqual(a.episodeEnd, 2)
        let b = MediaFilenameParser.identify(try DAVPath("Show 2x03-04.mp4"))
        XCTAssertEqual(b.title, "Show"); XCTAssertEqual(b.season, 2); XCTAssertEqual(b.episode, 3); XCTAssertEqual(b.episodeEnd, 4)
    }
    func parse(_ xml: String, filename: String = "Movie.2024.mkv") throws -> LocalMediaMetadata {
        try NFOReader.parse(Data(xml.utf8), fallback: MediaFilenameParser.identify(DAVPath(filename)), path: DAVPath("Movie.nfo"))
    }
    func testMovieNFOCDATAProviderIDsAndNoURLFollowing() throws {
        let metadata = try parse("""
        <movie><title>本机片名</title><year>2023</year><plot><![CDATA[本机简介 & 文字]]></plot>
        <uniqueid type="tmdb">12345</uniqueid><uniqueid type="imdb">tt1234567</uniqueid>
        <id>untyped-id-is-not-a-provider</id><thumb>https://external.invalid/poster.jpg</thumb>
        <url>https://external.invalid/lookup</url></movie>
        """)
        XCTAssertEqual(metadata.title, "本机片名"); XCTAssertEqual(metadata.year, 2023)
        XCTAssertEqual(metadata.plot, "本机简介 & 文字"); XCTAssertEqual(metadata.origin, .nfo)
        XCTAssertEqual(metadata.providerIDs, ["tmdb": "12345", "imdb": "tt1234567"])
        XCTAssertEqual(metadata.kind, .movie); XCTAssertEqual(metadata.nfoPath?.name, "Movie.nfo")
    }
    func testEpisodeNFODoesNotInheritMovieOrShowIdentity() throws {
        let metadata = try parse("<episodedetails><title>特辑</title><season>0</season><episode>1</episode></episodedetails>", filename: "Show.S00E01E02.mkv")
        XCTAssertEqual(metadata.kind, .episode); XCTAssertEqual(metadata.season, 0); XCTAssertEqual(metadata.episodeEnd, 2)
        XCTAssertThrowsError(try parse("<movie><title>Wrong kind</title></movie>", filename: "Show.S01E01.mkv"))
        XCTAssertThrowsError(try parse("<tvshow><title>Not an episode sidecar</title></tvshow>"))
    }
    func testNFORejectsEntitiesTruncationConflictingIDsAndDuplicateFields() throws {
        for xml in ["<!DOCTYPE movie [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><movie><title>&x;</title></movie>",
                    "<movie><title>x</title>", "<movie><title>a</title><title>b</title></movie>",
                    "<movie><title>x</title><uniqueid type='tmdb'>1</uniqueid><uniqueid type='tmdb'>2</uniqueid></movie>",
                    "<movie xmlns='other'><title>x</title></movie>", "<movie><title></title></movie>"] {
            XCTAssertThrowsError(try parse(xml), xml)
        }
        let data = Data(repeating: 65, count: NFOReader.maxBytes + 1)
        XCTAssertThrowsError(try NFOReader.parse(data, fallback: .init(title: "x"), path: DAVPath("x.nfo")))
        let safe = try parse("<movie><title>x</title><uniqueid type='tmdb'>https://evil.invalid</uniqueid><uniqueid type='default'>42</uniqueid></movie>")
        XCTAssertTrue(safe.providerIDs.isEmpty)
    }
    func testExactSidecarPreferredAndFolderFallbackConservative() throws {
        let video = try entry("Folder/a.mkv"), exact = try entry("Folder/a.nfo"), generic = try entry("Folder/movie.nfo")
        let selection = NFOSidecarSelection(siblings: [video, exact, generic])
        XCTAssertEqual(selection.candidate(video: video).0?.path, exact.path)
        XCTAssertEqual(NFOSidecarSelection(siblings: [video, generic]).candidate(video: video).0?.path, generic.path)
        XCTAssertNil(try NFOSidecarSelection(siblings: [video, entry("Folder/b.mp4"), generic]).candidate(video: video).0)
        let episode = try entry("Folder/Show.S01E01.mkv")
        XCTAssertNil(NFOSidecarSelection(siblings: [episode, generic]).candidate(video: episode).0)
        let ambiguous = try NFOSidecarSelection(siblings: [video, exact, entry("Folder/A.NFO")]).candidate(video: video)
        XCTAssertNil(ambiguous.0); XCTAssertEqual(ambiguous.1, .ambiguousNFO)
    }
    actor Source: ReadOnlyMetadataSource {
        let entries: [String: [RemoteMediaEntry]]
        let data: [String: Data]
        var reads: [String] = []
        init(entries: [String: [RemoteMediaEntry]], data: [String: Data]) { self.entries = entries; self.data = data }
        func list(_ directory: DAVPath) async throws -> [RemoteMediaEntry] { entries[directory.key] ?? [] }
        func readNFO(_ path: DAVPath, root: DAVPath) async throws -> Data {
            reads.append(path.key)
            guard path.isWithin(root), let value = data[path.key] else { throw NetworkMediaError.http(403) }; return value
        }
    }
    func testScannerReadsOnlySelectedSiblingNFOAndPersistsProvenance() async throws {
        let source = try Source(entries: ["Movies": [entry("Movies/a.mkv"), entry("Movies/a.nfo"), entry("Movies/unused.nfo"), entry("Movies/poster.jpg")]],
            data: ["Movies/a.nfo": Data("<movie><title>已有资料</title></movie>".utf8)])
        let files = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath("Movies"))
        XCTAssertEqual(files.count, 1); XCTAssertEqual(files[0].metadata?.title, "已有资料")
        let reads = await source.reads; XCTAssertEqual(reads, ["Movies/a.nfo"])
        let roundTrip = try JSONDecoder().decode([RemoteMediaEntry].self, from: JSONEncoder().encode(files))
        XCTAssertEqual(roundTrip, files)
    }
    func testMalformedAndOversizedSidecarsFallBackWithoutReadingUnboundedData() async throws {
        let source = try Source(entries: ["": [entry("a.mp4"), entry("a.nfo"), entry("b.mp4"), entry("b.nfo", size: Int64(NFOReader.maxBytes + 1))]], data: ["a.nfo": Data("bad nfo".utf8)])
        let files = try await ReadOnlyLibraryScanner.scan(source: source, root: DAVPath())
        XCTAssertEqual(files.map { $0.metadata?.notice }, [.invalidNFO, .oversizedNFO])
        let reads = await source.reads; XCTAssertEqual(reads, ["a.nfo"])
    }
    func testMetadataPermissionFailureAndBudgetKeepOldIndex() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NetworkLibraryStore(directory: directory)
        let library = NetworkLibrary(name: "x", scope: try WebDAVScope(address: "https://example.test/"), root: try DAVPath())
        try await store.add(library)
        let token = try await store.beginScan(library.id); try await store.commit(library.id, token: token, files: [entry("old.mp4")])
        let file = directory.appendingPathComponent("libraries-v1.json"), before = try Data(contentsOf: file)
        let source = try Source(entries: ["": [entry("a.mp4"), entry("a.nfo")]], data: [:])
        do { try await store.scan(library, source: source); XCTFail() } catch { XCTAssertEqual(error as? NetworkMediaError, .http(403)) }
        XCTAssertEqual(try Data(contentsOf: file), before)
        let good = try Source(entries: ["": [entry("a.mp4"), entry("a.nfo")]], data: ["a.nfo": Data("<movie><title>x</title></movie>".utf8)])
        do { _ = try await ReadOnlyLibraryScanner.scan(source: good, root: DAVPath(), maxMetadataBytes: 1); XCTFail() } catch { XCTAssertEqual(error as? NetworkMediaError, .limitExceeded) }
    }
    func testOldIndexWithoutMetadataRemainsReadableAndDeepEncodingRejected() throws {
        let data = Data(#"{"path":{"encodedSegments":["a.mp4"]},"isDirectory":false,"size":42}"#.utf8)
        let old = try JSONDecoder().decode(RemoteMediaEntry.self, from: data)
        XCTAssertNil(old.metadata); XCTAssertEqual(old.path.name, "a.mp4")
        var nested = "%2e%2e"
        for _ in 0..<10 { nested = nested.replacingOccurrences(of: "%", with: "%25") }
        XCTAssertThrowsError(try DAVPath(nested))
    }
    func testRichLocalFactsIgnoreExternalImagesAndNestedSpoofing() throws {
        let result = try parse("""
        <movie><title>本地电影</title><originaltitle>Original</originaltitle><tagline>一句话</tagline>
        <runtime>119</runtime><rating>8.1</rating><mpaa>PG</mpaa><genre>剧情</genre><genre>动画</genre><genre>剧情</genre>
        <studio>本地工作室</studio><director>导演甲</director><actor><name>演员甲</name><role>主角</role><thumb>https://external.invalid/person.jpg</thumb><rating>10</rating></actor>
        <fileinfo><streamdetails><video><codec>hevc</codec><width>3840</width><height>2160</height></video><audio><codec>dts</codec><channels>6</channels><language>jpn</language></audio></streamdetails></fileinfo></movie>
        """)
        let detail = try XCTUnwrap(result.details)
        XCTAssertEqual(detail.originalTitle, "Original"); XCTAssertEqual(detail.tagline, "一句话")
        XCTAssertEqual(detail.runtimeMinutes, 119); XCTAssertEqual(detail.rating, 8.1)
        XCTAssertEqual(detail.genres, ["剧情", "动画"]); XCTAssertEqual(detail.studios, ["本地工作室"])
        XCTAssertEqual(detail.directors, ["导演甲"]); XCTAssertEqual(detail.people.map(\.name), ["演员甲"])
        XCTAssertEqual(detail.people.first?.role, "主角"); XCTAssertEqual(detail.video, "HEVC · 3840×2160")
        XCTAssertEqual(detail.audio, "DTS · 6 声道 · jpn")
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(detail), as: UTF8.self).contains("external.invalid"))
    }
    func testRichFactsBoundsAndPreferredRatingScale() throws {
        let result = try parse("""
        <movie><title>x</title><runtime>-1</runtime><rating>NaN</rating>
        <ratings><rating name="tmdb" max="100" default="true"><value>82</value></rating><rating name="imdb" max="10" default="true"><value>8.3</value></rating></ratings>
        <fileinfo><streamdetails><video><width>9999999</width><height>2160</height></video><audio><channels>999</channels></audio></streamdetails></fileinfo></movie>
        """)
        XCTAssertNil(result.details?.runtimeMinutes); XCTAssertEqual(result.details?.rating, 8.3)
        XCTAssertNil(result.details?.video); XCTAssertNil(result.details?.audio)
        XCTAssertThrowsError(try parse("<movie><title>x</title><runtime>1</runtime><runtime>2</runtime></movie>"))
        XCTAssertThrowsError(try parse("<movie><title>x</title><actor><name>a</name><name>b</name></actor></movie>"))
        let people = (0..<80).map { "<actor><name>Actor\($0)</name></actor>" }.joined()
        XCTAssertEqual(try parse("<movie><title>x</title>" + people + "</movie>").details?.people.count, 60)
    }
    func testOldMetadataWithoutDetailsDecodesAndNewFactsRoundTrip() throws {
        let old = Data(#"{"title":"旧影片","kind":"movie","providerIDs":{},"origin":"nfo"}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(LocalMediaMetadata.self, from: old).details)
        let value = try parse("<movie><title>x</title><genre>动画</genre></movie>")
        XCTAssertEqual(try JSONDecoder().decode(LocalMediaMetadata.self, from: JSONEncoder().encode(value)), value)
    }
    func testDetailReaderReadsOnlySelectedNFOAndNeverVideoOrExternalURL() async throws {
        let video = try entry("Movies/a.mkv"), data = Data("<movie><title>x</title><runtime>120</runtime></movie>".utf8)
        let nfo = try entry("Movies/a.nfo", size: Int64(data.count))
        let source = try Source(entries: ["Movies": [video, nfo, entry("Movies/other.nfo")]], data: [nfo.path.key: data])
        let result = try await LocalMediaDetailReader.load(file: video, root: DAVPath("Movies"), source: source)
        XCTAssertEqual(result?.details?.runtimeMinutes, 120)
        let reads = await source.reads; XCTAssertEqual(reads, [nfo.path.key])
        let missing = Source(entries: ["Movies": [video]], data: [:])
        let absent = try await LocalMediaDetailReader.load(file: video, root: DAVPath("Movies"), source: missing)
        XCTAssertNil(absent)
    }
    actor ChangingDetailSource: ReadOnlyMetadataSource {
        let initial: [RemoteMediaEntry], later: [RemoteMediaEntry], data: Data
        var listings = 0, reads = 0
        init(_ initial: [RemoteMediaEntry], _ later: [RemoteMediaEntry], _ data: Data) { self.initial = initial; self.later = later; self.data = data }
        func list(_ path: DAVPath) async throws -> [RemoteMediaEntry] { listings += 1; return listings == 1 ? initial : later }
        func readNFO(_ path: DAVPath, root: DAVPath) async throws -> Data { reads += 1; return data }
    }
    func testDetailReaderRejectsReplacedSidecarAndOutOfScopeBeforeRead() async throws {
        let video = try entry("Movies/a.mkv"), data = Data("<movie><title>x</title></movie>".utf8)
        let nfo = RemoteMediaEntry(path: try DAVPath("Movies/a.nfo"), isDirectory: false, size: Int64(data.count), etag: "one")
        let changed = RemoteMediaEntry(path: nfo.path, isDirectory: false, size: nfo.size, etag: "two")
        let source = ChangingDetailSource([video, nfo], [video, changed], data)
        do { _ = try await LocalMediaDetailReader.load(file: video, root: DAVPath("Movies"), source: source); XCTFail() } catch { XCTAssertEqual(error as? NetworkMediaError, .incompleteListing) }
        let outside = try Source(entries: ["Movies": [video, nfo, entry("Other/escape.nfo")]], data: [:])
        do { _ = try await LocalMediaDetailReader.load(file: video, root: DAVPath("Movies"), source: outside); XCTFail() } catch { XCTAssertEqual(error as? NetworkMediaError, .incompleteListing) }
        let reads = await outside.reads; XCTAssertTrue(reads.isEmpty)
        do { _ = try await LocalMediaDetailReader.load(file: video, root: DAVPath("Other"), source: outside); XCTFail() } catch { XCTAssertEqual(error as? NetworkMediaError, .outsideRoot) }
    }

    func testDiscDetailUsesTheScannersMovieSidecarAndRichCredits() async throws {
        let movie = try DAVPath("Movies/Disc"), disc = try entry("Movies/Disc/BDMV", directory: true)
        let stream = try entry("Movies/Disc/BDMV/STREAM", directory: true), video = try entry("Movies/Disc/BDMV/STREAM/00001.m2ts")
        let data = Data("<movie><title>Disc film</title><director>Director</director><actor><name>Actor</name><role>Lead</role></actor></movie>".utf8)
        let nfo = try entry("Movies/Disc/movie.nfo", size: Int64(data.count))
        let source = Source(entries: [movie.key: [disc, nfo], disc.path.key: [stream], stream.path.key: [video]], data: [nfo.path.key: data])
        let scanned = try await ReadOnlyLibraryScanner.scan(source: source, root: movie)
        let file = try XCTUnwrap(scanned.first)
        let detail = try await LocalMediaDetailReader.load(file: file, root: movie, source: source)
        XCTAssertEqual(detail?.nfoPath, file.metadata?.nfoPath)
        XCTAssertEqual(detail?.details?.displayPeople.map(\.name), ["Director", "Actor"])
        let reads = await source.reads; XCTAssertEqual(reads, [nfo.path.key, nfo.path.key])
        // Selecting only STREAM never authorizes a read in its ancestors.
        let scoped = Source(entries: [stream.path.key: [video]], data: [:])
        let absent = try await LocalMediaDetailReader.load(file: video, root: stream.path, source: scoped)
        XCTAssertNil(absent); let scopedReads = await scoped.reads; XCTAssertTrue(scopedReads.isEmpty)
    }
    actor ChangingDiscSource: ReadOnlyMetadataSource {
        let entries: [String: [RemoteMediaEntry]], nfo: RemoteMediaEntry, data: Data
        let changeLink: Bool
        var didRead = false
        init(entries: [String: [RemoteMediaEntry]], nfo: RemoteMediaEntry, data: Data, changeLink: Bool) {
            self.entries = entries; self.nfo = nfo; self.data = data; self.changeLink = changeLink
        }
        func list(_ directory: DAVPath) async throws -> [RemoteMediaEntry] {
            (entries[directory.key] ?? []).map { item in
                guard didRead, changeLink ? item.isDirectory : item.path == nfo.path else { return item }
                return RemoteMediaEntry(path: item.path, isDirectory: item.isDirectory, size: item.size, etag: "changed")
            }
        }
        func readNFO(_ path: DAVPath, root: DAVPath) async throws -> Data {
            XCTAssertEqual(path, nfo.path); XCTAssertTrue(path.isWithin(root)); didRead = true; return data
        }
    }
    func testDiscDetailRejectsChangedAncestorOrNFOAndAmbiguousMovieFolders() async throws {
        let disc = try entry("Disc/BDMV", directory: true), stream = try entry("Disc/BDMV/STREAM", directory: true)
        let video = try entry("Disc/BDMV/STREAM/00001.m2ts"), nfo = try entry("Disc/movie.nfo")
        let entries = ["Disc": [disc, nfo], disc.path.key: [stream], stream.path.key: [video]]
        for changeLink in [true, false] {
            let source = ChangingDiscSource(entries: entries, nfo: nfo, data: Data("<movie><title>Disc film</title></movie>".utf8), changeLink: changeLink)
            do { _ = try await LocalMediaDetailReader.load(file: video, root: DAVPath("Disc"), source: source); XCTFail() }
            catch { XCTAssertEqual(error as? NetworkMediaError, .incompleteListing) }
        }
        var ambiguous = entries; ambiguous["Disc"]?.append(try entry("Disc/bdmv", directory: true))
        let source = Source(entries: ambiguous, data: [:])
        let absent = try await LocalMediaDetailReader.load(file: video, root: DAVPath("Disc"), source: source)
        XCTAssertNil(absent); let reads = await source.reads; XCTAssertTrue(reads.isEmpty)
    }
    func testRichDetailsCannotBeAttachedToAChangedMovieIdentity() async throws {
        var video = try entry("Movies/a.mkv")
        video.metadata = .init(title: "Original", origin: .nfo, nfoPath: try DAVPath("Movies/a.nfo"))
        let nfo = try entry("Movies/a.nfo"), source = Source(entries: ["Movies": [video, nfo]], data: [nfo.path.key: Data("<movie><title>Different</title><actor><name>Other actor</name></actor></movie>".utf8)])
        do { _ = try await LocalMediaDetailReader.load(file: video, root: DAVPath("Movies"), source: source); XCTFail() }
        catch { XCTAssertEqual(error as? NetworkMediaError, .invalidMetadata) }
    }
    func testCreditsCombineMultipleJobsWithoutDuplicatePersonCards() throws {
        let metadata = try parse("<movie><title>x</title><director>Person</director><actor><name>person</name><role>Lead</role></actor><actor><name>Other</name></actor></movie>")
        XCTAssertEqual(metadata.details?.displayPeople.map(\.name), ["Person", "Other"])
        XCTAssertEqual(metadata.details?.displayPeople.first?.role, "导演 · Lead")
    }

    func testReleaseNotesNFOKeepsFilenameIdentityAndAudio() throws {
        let path = try DAVPath("movie/功夫.Kung.Fu.Hustle.2004.BluRay.1080p.x265/Kung.Fu.Hustle.2004.BluRay.1080p.x265.nfo")
        let video = try DAVPath("movie/功夫.Kung.Fu.Hustle.2004.BluRay.1080p.x265/Kung.Fu.Hustle.2004.BluRay.1080p.x265.mkv")
        var fallback = MediaFilenameParser.identify(video)
        XCTAssertEqual(fallback.title, "功夫")
        XCTAssertEqual(fallback.year, 2004)
        fallback.details = MediaFilenameParser.technicalDetails(video)
        XCTAssertEqual(fallback.details?.video, "HEVC · 1080p")
        let notes = "Kung.Fu.Hustle\n\nRATiO....: 2.40 : 1\nAUDiO 1.........: Mandarin  AC3 5.1 448kbps\nAUDiO 2.........: Cantonese AC3 5.1 640kbps\n"
        let parsed = try NFOReader.parseOrReleaseNotes(Data(notes.utf8), fallback: fallback, path: path)
        XCTAssertEqual(parsed.details?.audio, "Mandarin AC3 5.1 / Cantonese AC3 5.1")
        XCTAssertNil(parsed.notice)
        XCTAssertEqual(parsed.origin, .filename)
        XCTAssertThrowsError(try NFOReader.parseOrReleaseNotes(Data("<movie><broken".utf8), fallback: fallback, path: path))
    }
    func testFolderTitleNeedsTheFolderToNameTheSameFilm() throws {
        XCTAssertEqual(MediaFilenameParser.identify(try DAVPath("电影/Inception.2010.mkv")).title, "Inception")
        XCTAssertEqual(MediaFilenameParser.identify(try DAVPath("[杀死比尔].Kill.Bill.2003/Kill.Bill.2003.mkv")).title, "杀死比尔")
    }
    func testGenericAndZeroByteImagesInPosterChoice() throws {
        let folder = "movie/Kill Bill"
        let mkv = RemoteMediaEntry(path: try DAVPath(folder + "/Kill.Bill.mkv"), isDirectory: false, size: 1)
        let set = RemoteMediaEntry(path: try DAVPath(folder + "/movieset-poster.jpg"), isDirectory: false, size: 10)
        XCTAssertEqual(LocalArtworkSelection(siblings: [mkv, set]).candidate(video: mkv)?.path, set.path)
        let empty = RemoteMediaEntry(path: try DAVPath(folder + "/Kill.Bill-poster.jpg"), isDirectory: false, size: 0)
        XCTAssertEqual(LocalArtworkSelection(siblings: [mkv, empty, set]).candidate(video: mkv)?.path, set.path)
    }
}
