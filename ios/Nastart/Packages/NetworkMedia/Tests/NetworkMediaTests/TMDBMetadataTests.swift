import XCTest
@testable import NetworkMedia

private final class FakeTMDB: TMDBTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var routes: [String: (Int, String)] = [:]
    private var captured: [URLRequest] = []
    var unreachableHosts: Set<String> = []
    var requests: [URLRequest] { lock.withLock { captured } }
    func route(_ path: String, status: Int = 200, _ body: String) { lock.withLock { routes[path] = (status, body) } }
    func response(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        if lock.withLock({ unreachableHosts.contains(url.host ?? "") }) {
            lock.withLock { captured.append(request) }
            throw URLError(.timedOut)
        }
        var key = url.path
        if let language = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "language" })?.value,
           lock.withLock({ routes[key + "#" + language] != nil }) { key += "#" + language }
        if let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "query" })?.value,
           lock.withLock({ routes[key + "?" + query] != nil }) { key += "?" + query }
        let (status, body) = lock.withLock { () -> (Int, String) in
            captured.append(request)
            return routes[key] ?? (404, "{}")
        }
        return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private final class Clock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
}

final class TMDBMetadataTests: XCTestCase {
    private var directory: URL!
    private let token = String(repeating: "t", count: 40)
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }
    private func service(_ fake: FakeTMDB, clock: Clock = Clock(), credential: String? = nil) -> TMDBService {
        let text = credential ?? token
        return TMDBService(directory: directory, transport: fake, language: "zh-CN", now: { clock.date }, credential: { TMDBCredential(text) })
    }
    private func candidate(_ id: Int, _ title: String, _ date: String? = nil) -> TMDBMatcher.Candidate {
        TMDBMatcher.Candidate(id: id, title: title, releaseDate: date)
    }
    private let kungFu = #"{"title":"功夫","original_title":"功夫","release_date":"2004-12-23","overview":"斧头帮","tagline":null,"runtime":99,"vote_average":7.8,"vote_count":10,"genres":[{"name":"喜剧"}],"production_companies":[{"name":"Star Overseas"}],"poster_path":"/abc_1.jpg","backdrop_path":"/../evil","credits":{"cast":[{"name":"周星驰","character":"阿星"},{"name":"元秋","character":""}],"crew":[{"name":"周星驰","job":"Director"},{"name":"X","job":"Writer"}]}}"#

    func testMatcherAcceptsOnlyCertainResults() {
        let movie = TMDBLookup(kind: .movie, title: "功夫", year: 2004)
        XCTAssertEqual(TMDBMatcher.choose([candidate(1, "功夫", "2004-12-23"), candidate(2, "功夫", "1970-01-01")], lookup: movie, query: "功夫"), 1)
        XCTAssertEqual(TMDBMatcher.choose([candidate(1, "功夫", "2005-01-01")], lookup: movie, query: "功夫"), 1)
        XCTAssertNil(TMDBMatcher.choose([candidate(1, "功夫", "1990-01-01")], lookup: movie, query: "功夫"), "wrong year")
        XCTAssertNil(TMDBMatcher.choose([candidate(1, "功夫")], lookup: movie, query: "功夫"), "undated result cannot confirm a year")
        let noYear = TMDBLookup(kind: .movie, title: "功夫")
        XCTAssertNil(TMDBMatcher.choose([candidate(1, "功夫", "2004-01-01"), candidate(2, "功夫", "1970-01-01")], lookup: noYear, query: "功夫"), "ambiguous")
        XCTAssertNil(TMDBMatcher.choose([candidate(1, "功夫熊猫", "2008-01-01")], lookup: noYear, query: "功夫"), "another film sharing a prefix")
        XCTAssertEqual(TMDBMatcher.choose([candidate(1, "Kung-Fu: HUSTLE", "2004-01-01")], lookup: noYear, query: "Kung Fu Hustle"), 1, "punctuation and case")
    }
    func testMatcherAcceptsOneSubtitledSequelButPrefersExact() {
        let lookup = TMDBLookup(kind: .movie, title: "奇异博士2")
        XCTAssertEqual(TMDBMatcher.choose([candidate(9, "奇异博士2：疯狂多元宇宙", "2022-01-01")], lookup: lookup, query: "奇异博士2"), 9)
        XCTAssertNil(TMDBMatcher.choose([candidate(1, "奇异博士2：甲"), candidate(2, "奇异博士2：乙")], lookup: lookup, query: "奇异博士2"))
        XCTAssertEqual(TMDBMatcher.choose([candidate(1, "奇异博士2：甲"), candidate(2, "奇异博士2")], lookup: lookup, query: "奇异博士2"), 2)
    }
    func testShowFolderYearMayBeLaterThanFirstAirDate() {
        let lookup = TMDBLookup(kind: .tv, title: "火影忍者", year: 2010)
        let show = TMDBMatcher.Candidate(id: 3, name: "火影忍者", firstAirDate: "2002-10-03")
        XCTAssertEqual(TMDBMatcher.choose([show], lookup: lookup, query: "火影忍者"), 3)
    }
    func testSearchTitlesSplitAReleaseNameHoldingTwoTitles() {
        XCTAssertEqual(TMDBLookup(kind: .movie, title: "功夫 Kung Fu Hustle").searchTitles, ["功夫 Kung Fu Hustle", "功夫", "Kung Fu Hustle"])
        XCTAssertEqual(TMDBLookup(kind: .movie, title: "Inception").searchTitles, ["Inception"])
    }
    func testMatchMapsDetailsAndRejectsUnsafeImagePath() async throws {
        let fake = FakeTMDB()
        fake.route("/3/search/movie", #"{"results":[{"id":11,"title":"功夫","release_date":"2004-12-23"}]}"#)
        fake.route("/3/movie/11", kungFu)
        let match = try await service(fake).match(TMDBLookup(kind: .movie, title: "功夫", year: 2004))
        XCTAssertEqual(match?.id, 11); XCTAssertEqual(match?.runtimeMinutes, 99); XCTAssertEqual(match?.directors, ["周星驰"])
        XCTAssertEqual(match?.cast, [.init(name: "周星驰", role: "阿星"), .init(name: "元秋", role: "演员")])
        XCTAssertEqual(match?.posterPath, "/abc_1.jpg"); XCTAssertNil(match?.backdropPath)
    }
    func testBearerStaysInHeaderAndV3KeyInQuery() async throws {
        let fake = FakeTMDB()
        fake.route("/3/search/movie", #"{"results":[]}"#)
        _ = try await service(fake).match(TMDBLookup(kind: .movie, title: "A"))
        let bearer = try XCTUnwrap(fake.requests.first)
        XCTAssertEqual(bearer.value(forHTTPHeaderField: "Authorization"), "Bearer " + token)
        XCTAssertFalse(bearer.url!.absoluteString.contains(token))
        XCTAssertEqual(bearer.url?.host, "api.tmdb.org")

        let v3 = FakeTMDB(); v3.route("/3/authentication", "{}")
        let key = String(repeating: "a1", count: 16)
        try await service(v3, credential: key).verify(try XCTUnwrap(TMDBCredential(key)))
        let request = try XCTUnwrap(v3.requests.first)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(request.url!.query!.contains("api_key=" + key))
    }
    func testBlockedHostFallsBackAndIsNotTriedFirstAgain() async throws {
        let fake = FakeTMDB(); fake.unreachableHosts = ["api.tmdb.org"]
        fake.route("/3/search/movie", #"{"results":[]}"#)
        let service = service(fake)
        _ = try await service.match(TMDBLookup(kind: .movie, title: "A"))
        _ = try await service.match(TMDBLookup(kind: .movie, title: "B"))
        XCTAssertEqual(fake.requests.map { $0.url!.host! }, ["api.tmdb.org", "api.themoviedb.org", "api.themoviedb.org"])
    }
    func testNoHostReachableIsNotRememberedAsNoMatch() async throws {
        let fake = FakeTMDB(); fake.unreachableHosts = ["api.tmdb.org", "api.themoviedb.org"]
        let service = service(fake)
        let lookup = TMDBLookup(kind: .movie, title: "A")
        await assertThrows(TMDBError.unavailable) { _ = try await service.match(lookup) }
        fake.unreachableHosts = []
        fake.route("/3/search/movie", #"{"results":[{"id":11,"title":"A"}]}"#); fake.route("/3/movie/11", kungFu)
        let match = try await service.match(lookup)
        XCTAssertEqual(match?.id, 11)
    }
    func testCredentialNeverAppearsInItsDescription() throws {
        let credential = try XCTUnwrap(TMDBCredential("  " + token + "\n"))
        XCTAssertEqual(credential.value, token)
        XCTAssertFalse(String(describing: credential).contains(token))
        XCTAssertNil(TMDBCredential("has space in the middle of it"))
    }
    func testFailuresAreNotRememberedButNoMatchIsUntilItExpires() async throws {
        let fake = FakeTMDB(), clock = Clock(), service = service(fake, clock: clock)
        let lookup = TMDBLookup(kind: .movie, title: "A")
        fake.route("/3/search/movie", status: 401, "{}")
        await assertThrows(TMDBError.invalidCredential) { _ = try await service.match(lookup) }
        fake.route("/3/search/movie", #"{"results":[]}"#)
        let first = try await service.match(lookup); XCTAssertNil(first)
        let count = fake.requests.count
        let second = try await service.match(lookup); XCTAssertNil(second)
        XCTAssertEqual(fake.requests.count, count, "remembered")
        clock.date.addTimeInterval(TMDBService.noMatchRetention + 1)
        _ = try await service.match(lookup)
        XCTAssertEqual(fake.requests.count, count + 1, "asks again after expiry")
    }
    func testMatchIsNotKeptPastSixMonths() async throws {
        let fake = FakeTMDB(), clock = Clock(), service = service(fake, clock: clock)
        fake.route("/3/search/movie", #"{"results":[{"id":11,"title":"功夫"}]}"#); fake.route("/3/movie/11", kungFu)
        let lookup = TMDBLookup(kind: .movie, title: "功夫")
        _ = try await service.match(lookup)
        let count = fake.requests.count
        clock.date.addTimeInterval(TMDBService.retention - 60)
        _ = try await service.match(lookup); XCTAssertEqual(fake.requests.count, count)
        clock.date.addTimeInterval(120)
        _ = try await service.match(lookup); XCTAssertGreaterThan(fake.requests.count, count)
    }
    func testKnownIDSkipsSearchAndUnknownIDFallsBackToSearch() async throws {
        let fake = FakeTMDB()
        fake.route("/3/movie/11", kungFu)
        _ = try await service(fake).match(TMDBLookup(kind: .movie, title: "别名", knownID: 11))
        XCTAssertFalse(fake.requests.contains { $0.url!.path.contains("search") })

        let stale = FakeTMDB()
        stale.route("/3/search/movie", #"{"results":[{"id":11,"title":"功夫"}]}"#); stale.route("/3/movie/11", kungFu)
        let match = try await service(stale).match(TMDBLookup(kind: .movie, title: "功夫", knownID: 999))
        XCTAssertEqual(match?.id, 11)
    }
    func testSecondTitleIsTriedAndEnglishOverviewFillsAnEmptyOne() async throws {
        let fake = FakeTMDB()
        fake.route("/3/search/movie", #"{"results":[]}"#)
        fake.route("/3/search/movie?Kung Fu Hustle", #"{"results":[{"id":11,"title":"Kung Fu Hustle"}]}"#)
        fake.route("/3/movie/11", #"{"title":"功夫","overview":""}"#)
        fake.route("/3/movie/11#en-US", #"{"title":"Kung Fu Hustle","overview":"Axe gang"}"#)
        let match = try await service(fake).match(TMDBLookup(kind: .movie, title: "功夫 Kung Fu Hustle"))
        XCTAssertEqual(match?.overview, "Axe gang")
    }
    func testRateLimitBlocksUntilRetryWindowPasses() async throws {
        let fake = FakeTMDB(), clock = Clock(), service = service(fake, clock: clock)
        fake.route("/3/search/movie", status: 429, "{}")
        let lookup = TMDBLookup(kind: .movie, title: "A")
        await assertThrows(TMDBError.rateLimited) { _ = try await service.match(lookup) }
        let count = fake.requests.count
        await assertThrows(TMDBError.rateLimited) { _ = try await service.match(lookup) }
        XCTAssertEqual(fake.requests.count, count, "no request inside the window")
        clock.date.addTimeInterval(11)
        fake.route("/3/search/movie", #"{"results":[]}"#)
        _ = try await service.match(lookup)
        XCTAssertEqual(fake.requests.count, count + 1)
    }
    func testImagePathMustBeAPlainFileName() async {
        let service = service(FakeTMDB())
        await assertThrows(TMDBError.unavailable) { _ = try await service.image(path: "/../../evil.jpg", size: .poster) }
        XCTAssertNil(TMDBMatcher.validImagePath("https://evil.example/a.jpg"))
        XCTAssertEqual(TMDBMatcher.validImagePath("/a-B_9.jpg"), "/a-B_9.jpg")
    }
    func testFillingKeepsEveryLocalFact() {
        var local = LocalMediaDetails()
        local.originalTitle = "本地原名"; local.rating = 9; local.genres = ["本地"]; local.video = "HEVC"
        local.directors = ["本地导演"]
        let match = TMDBMatch(id: 1, kind: .movie, title: "T", originalTitle: "O", tagline: "G", runtimeMinutes: 99, rating: 1,
            genres: ["远端"], studios: ["S"], directors: ["D"], cast: [.init(name: "C", role: "R")])
        let filled = match.filling(local, displayTitle: "T")
        XCTAssertEqual(filled.originalTitle, "本地原名"); XCTAssertEqual(filled.rating, 9); XCTAssertEqual(filled.genres, ["本地"])
        XCTAssertEqual(filled.directors, ["本地导演"]); XCTAssertEqual(filled.video, "HEVC")
        XCTAssertEqual(filled.runtimeMinutes, 99); XCTAssertEqual(filled.studios, ["S"]); XCTAssertEqual(filled.people.first?.name, "C")
        XCTAssertNil(match.filling(nil, displayTitle: "O").originalTitle, "no repeat of the displayed title")
    }
    private func assertThrows(_ expected: TMDBError, file: StaticString = #filePath, line: UInt = #line, _ body: () async throws -> Void) async {
        do { try await body(); XCTFail("did not throw", file: file, line: line) }
        catch { XCTAssertEqual(error as? TMDBError, expected, file: file, line: line) }
    }
}
