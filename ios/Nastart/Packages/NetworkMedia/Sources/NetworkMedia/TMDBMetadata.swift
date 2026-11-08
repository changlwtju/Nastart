import Foundation
import CryptoKit

/// Optional, user-enabled gap filling. The scanned index and the NAS are never changed:
/// a match only overlays what local files lack, and a doubtful match is treated as none.
enum TMDBMediaKind: String, Codable, Sendable { case movie, tv }

struct TMDBLookup: Hashable, Codable, Sendable {
    let kind: TMDBMediaKind
    let title: String
    let year: Int?
    let knownID: Int?
    init(kind: TMDBMediaKind, title: String, year: Int? = nil, knownID: Int? = nil) {
        self.kind = kind; self.title = title.trimmingCharacters(in: .whitespacesAndNewlines); self.year = year; self.knownID = knownID
    }
    var identity: String { [kind.rawValue, title, year.map(String.init) ?? "", knownID.map(String.init) ?? ""].joined(separator: "|") }
    /// `功夫 Kung Fu Hustle` is one release name holding two titles; neither is a substring TMDB can match whole.
    var searchTitles: [String] {
        guard !title.isEmpty else { return [] }
        var result = [title]
        if let match = try? NSRegularExpression(pattern: #"^(\p{Han}\S*)\s+(.*[A-Za-z].*)$"#).firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let han = Range(match.range(at: 1), in: title), let latin = Range(match.range(at: 2), in: title) {
            result += [String(title[han]), String(title[latin])]
        }
        return result
    }
}

struct TMDBMatch: Codable, Equatable, Sendable {
    struct Person: Codable, Equatable, Sendable { let name: String; let role: String }
    let id: Int
    let kind: TMDBMediaKind
    let title: String
    var originalTitle: String?
    var year: Int?
    var overview: String?
    var tagline: String?
    var runtimeMinutes: Int?
    var rating: Double?
    var genres: [String] = []
    var studios: [String] = []
    var directors: [String] = []
    var cast: [Person] = []
    var posterPath: String?
    var backdropPath: String?

    /// Local facts always win, field by field.
    func filling(_ local: LocalMediaDetails?, displayTitle: String) -> LocalMediaDetails {
        var result = local ?? LocalMediaDetails()
        if result.originalTitle == nil, let originalTitle, originalTitle != displayTitle { result.originalTitle = originalTitle }
        if result.tagline == nil { result.tagline = tagline }
        if result.runtimeMinutes == nil { result.runtimeMinutes = runtimeMinutes }
        if result.rating == nil { result.rating = rating }
        if result.genres.isEmpty { result.genres = genres }
        if result.studios.isEmpty { result.studios = studios }
        if result.directors.isEmpty { result.directors = directors }
        if result.people.isEmpty { result.people = cast.map { .init(name: $0.name, role: $0.role) } }
        return result
    }
}

enum TMDBError: Error, Equatable { case missingCredential, invalidCredential, rateLimited, unavailable, unreachable }

struct TMDBCredential: Sendable, CustomStringConvertible {
    let value: String
    /// Accepts the API Read Access Token, or the shorter v3 API Key.
    init?(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (16...2048).contains(text.count), text.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) }) else { return nil }
        value = text
    }
    var isV3Key: Bool { value.count == 32 && value.allSatisfy(\.isHexDigit) }
    var description: String { "TMDBCredential(redacted)" }
}

enum TMDBMatcher {
    struct Candidate: Decodable, Sendable {
        let id: Int
        var title: String?, name: String?, originalTitle: String?, originalName: String?
        var releaseDate: String?, firstAirDate: String?
        var names: [String] { [title, name, originalTitle, originalName].compactMap { $0 } }
        var year: Int? { (releaseDate ?? firstAirDate).flatMap { Int($0.prefix(4)) } }
    }
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil).filter { $0.isLetter || $0.isNumber }
    }
    private static func yearFits(_ candidate: Candidate, _ lookup: TMDBLookup, query: String) -> Bool {
        guard let wanted = lookup.year else { return true }
        guard let year = candidate.year else { return false }
        // A show's folder may carry a later season's year, never one before the show began.
        return lookup.kind == .tv ? year <= wanted + 1 : abs(year - wanted) <= 1
    }
    /// Exact name first, then a sequel subtitle (`奇异博士2` → `奇异博士2：疯狂多元宇宙`).
    /// More than one equally good result means no match: a blank poster beats a wrong film.
    static func choose(_ candidates: [Candidate], lookup: TMDBLookup, query: String) -> Int? {
        let wanted = normalized(query)
        guard !wanted.isEmpty else { return nil }
        let fitting = candidates.filter { yearFits($0, lookup, query: query) }
        let exact = fitting.filter { $0.names.contains { normalized($0) == wanted } }
        if exact.count == 1 { return exact[0].id }
        if exact.count > 1 {
            let sameYear = exact.filter { $0.year == lookup.year && lookup.year != nil }
            return sameYear.count == 1 ? sameYear[0].id : nil
        }
        let subtitled = fitting.filter { candidate in candidate.names.contains { name in
            guard wanted.count >= 2, name.lowercased().hasPrefix(query.lowercased()) else { return false }
            guard let next = name.dropFirst(query.count).first else { return false }
            return !next.isLetter && !next.isNumber
        } }
        return subtitled.count == 1 ? subtitled[0].id : nil
    }
    static func validImagePath(_ path: String?) -> String? {
        guard let path, path.count <= 128, path.range(of: #"^/[A-Za-z0-9_-]+\.(jpg|jpeg|png)$"#, options: .regularExpression) != nil else { return nil }
        return path
    }
}

protocol TMDBTransport: Sendable {
    func response(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// No shared cookies or cache, and no redirects, so the credential only ever reaches the named host.
final class URLSessionTMDBTransport: NSObject, TMDBTransport, URLSessionTaskDelegate, @unchecked Sendable {
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15; configuration.timeoutIntervalForResource = 30
        configuration.httpCookieStorage = nil; configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    func response(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TMDBError.unavailable }
        return (data, http)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Rebuildable local copies, kept no longer than TMDB's terms allow (six months).
actor TMDBService {
    enum ImageSize: String, Sendable { case poster = "w500", backdrop = "w1280" }
    static let retention: TimeInterval = 180 * 86_400
    static let noMatchRetention: TimeInterval = 30 * 86_400
    private struct Entry: Codable { let fetched: Date; let match: TMDBMatch? }
    private struct Page: Decodable { let results: [TMDBMatcher.Candidate] }
    private struct Named: Decodable { let name: String? }
    private struct Details: Decodable {
        struct Cast: Decodable { let name: String?; let character: String? }
        struct Crew: Decodable { let name: String?; let job: String? }
        struct Credits: Decodable { let cast: [Cast]?; let crew: [Crew]? }
        var title: String?, name: String?, originalTitle: String?, originalName: String?
        var releaseDate: String?, firstAirDate: String?, overview: String?, tagline: String?
        var runtime: Int?, episodeRunTime: [Int]?, voteAverage: Double?, voteCount: Int?
        var genres: [Named]?, productionCompanies: [Named]?, createdBy: [Named]?
        var credits: Credits?, posterPath: String?, backdropPath: String?
    }
    private let directory: URL
    private let transport: any TMDBTransport
    private let credential: @Sendable () -> TMDBCredential?
    private let language: String
    private let now: @Sendable () -> Date
    private let maximumBytes: Int
    private var active = 0
    private var blockedUntil = Date.distantPast
    /// `api.themoviedb.org` times out on some networks, including mainland China, where `api.tmdb.org` still answers.
    /// The credential only ever goes to these two hosts. Once one fails, the other is tried first from then on.
    private var apiHosts = ["api.tmdb.org", "api.themoviedb.org"]
    init(directory: URL, transport: any TMDBTransport = URLSessionTMDBTransport(), language: String? = nil,
         maximumBytes: Int = 128 * 1024 * 1024, now: @escaping @Sendable () -> Date = { Date() },
         credential: @escaping @Sendable () -> TMDBCredential?) {
        self.directory = directory; self.transport = transport; self.credential = credential; self.now = now
        self.maximumBytes = max(1, maximumBytes)
        self.language = language ?? (Locale.preferredLanguages.first?.hasPrefix("en") == true ? "en-US" : "zh-CN")
    }

    func verify(_ candidate: TMDBCredential) async throws {
        _ = try await get(path: "/3/authentication", query: [], credential: candidate)
    }

    /// `nil` means TMDB has nothing certain for this title. Network failures throw and are not remembered.
    func match(_ lookup: TMDBLookup) async throws -> TMDBMatch? {
        try Task.checkCancellation()
        let file = directory.appendingPathComponent(Self.hash("match|" + language + "|" + lookup.identity) + ".json")
        if let entry = (try? Data(contentsOf: file)).flatMap({ try? JSONDecoder().decode(Entry.self, from: $0) }),
           now().timeIntervalSince(entry.fetched) < (entry.match == nil ? Self.noMatchRetention : Self.retention),
           now() >= entry.fetched { return entry.match }
        guard let credential = credential() else { throw TMDBError.missingCredential }
        try await acquire(); defer { active -= 1 }
        var id = lookup.knownID
        var result: TMDBMatch?
        if let known = id {
            do { result = try await details(id: known, kind: lookup.kind, credential: credential) }
            catch TMDBError.unavailable { id = nil }
        }
        if result == nil, lookup.knownID == nil || id == nil {
            for query in lookup.searchTitles {
                let data = try await get(path: "/3/search/" + lookup.kind.rawValue, query: [
                    .init(name: "query", value: query), .init(name: "language", value: language),
                    .init(name: "include_adult", value: "false")], credential: credential)
                guard let page = try? Self.decoder.decode(Page.self, from: data) else { throw TMDBError.unavailable }
                if let chosen = TMDBMatcher.choose(page.results, lookup: lookup, query: query) {
                    result = try await details(id: chosen, kind: lookup.kind, credential: credential)
                    break
                }
            }
        }
        write(try JSONEncoder().encode(Entry(fetched: now(), match: result)), to: file)
        return result
    }

    func image(path: String, size: ImageSize) async throws -> Data {
        guard let path = TMDBMatcher.validImagePath(path), let url = URL(string: "https://image.tmdb.org/t/p/" + size.rawValue + path) else { throw TMDBError.unavailable }
        let file = directory.appendingPathComponent(Self.hash("image|" + size.rawValue + path) + ".img")
        if let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           now().timeIntervalSince(modified) < Self.retention, let data = try? Data(contentsOf: file),
           (try? LocalArtworkDecoder.validate(data)) != nil { return data }
        try await acquire(); defer { active -= 1 }
        let data = try await send(URLRequest(url: url))
        do { try LocalArtworkDecoder.validate(data) } catch { throw TMDBError.unavailable }
        write(data, to: file)
        return data
    }

    func clear() { try? FileManager.default.removeItem(at: directory) }

    private func details(id: Int, kind: TMDBMediaKind, credential: TMDBCredential) async throws -> TMDBMatch {
        let path = "/3/\(kind.rawValue)/\(id)"
        let data = try await get(path: path, query: [.init(name: "language", value: language), .init(name: "append_to_response", value: "credits")], credential: credential)
        guard let details = try? Self.decoder.decode(Details.self, from: data) else { throw TMDBError.unavailable }
        var overview = Self.text(details.overview)
        if overview == nil, language != "en-US",
           let english = try? await get(path: path, query: [.init(name: "language", value: "en-US")], credential: credential),
           let fallback = try? Self.decoder.decode(Details.self, from: english) { overview = Self.text(fallback.overview) }
        var directors = (details.credits?.crew ?? []).filter { $0.job == "Director" }.compactMap { Self.text($0.name) }
        if directors.isEmpty { directors = (details.createdBy ?? []).compactMap { Self.text($0.name) } }
        return TMDBMatch(id: id, kind: kind, title: Self.text(details.title ?? details.name) ?? "",
            originalTitle: Self.text(details.originalTitle ?? details.originalName),
            year: (details.releaseDate ?? details.firstAirDate).flatMap { Int($0.prefix(4)) },
            overview: overview, tagline: Self.text(details.tagline),
            runtimeMinutes: (details.runtime ?? details.episodeRunTime?.first).flatMap { $0 > 0 ? $0 : nil },
            rating: (details.voteCount ?? 0) > 0 ? details.voteAverage : nil,
            genres: (details.genres ?? []).compactMap { Self.text($0.name) },
            studios: Array((details.productionCompanies ?? []).compactMap { Self.text($0.name) }.prefix(3)),
            directors: Array(directors.prefix(4)),
            cast: Array((details.credits?.cast ?? []).compactMap { person in
                Self.text(person.name).map { TMDBMatch.Person(name: $0, role: Self.text(person.character) ?? "演员") }
            }.prefix(18)),
            posterPath: TMDBMatcher.validImagePath(details.posterPath), backdropPath: TMDBMatcher.validImagePath(details.backdropPath))
    }

    private func get(path: String, query: [URLQueryItem], credential: TMDBCredential) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"; components.path = path
        var items = query
        if credential.isV3Key { items.append(.init(name: "api_key", value: credential.value)) }
        components.queryItems = items.isEmpty ? nil : items
        for host in apiHosts {
            components.host = host
            guard let url = components.url else { throw TMDBError.unavailable }
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if !credential.isV3Key { request.setValue("Bearer " + credential.value, forHTTPHeaderField: "Authorization") }
            do { return try await send(request) }
            catch TMDBError.unreachable {
                try Task.checkCancellation()
                if apiHosts.first == host { apiHosts.append(apiHosts.removeFirst()) }
            }
        }
        throw TMDBError.unavailable
    }

    private func send(_ request: URLRequest) async throws -> Data {
        guard now() >= blockedUntil else { throw TMDBError.rateLimited }
        let data: Data, response: HTTPURLResponse
        do { (data, response) = try await transport.response(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        // System errors can quote the URL, which may hold a v3 key. They stay here.
        catch { throw TMDBError.unreachable }
        switch response.statusCode {
        case 200..<300: return data
        case 401: throw TMDBError.invalidCredential
        case 429:
            let wait = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init) ?? 10
            blockedUntil = now().addingTimeInterval(min(max(wait, 1), 120))
            throw TMDBError.rateLimited
        default: throw TMDBError.unavailable
        }
    }

    /// Only visible cards ask, and a card scrolled away gives up its place in the queue.
    private func acquire() async throws {
        while active >= 4 { try await Task.sleep(nanoseconds: 50_000_000) }
        try Task.checkCancellation()
        active += 1
    }

    private func write(_ data: Data, to file: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            trim()
        } catch { }
    }

    private func trim() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))) ?? [])
            .compactMap { url -> (URL, Int, Date)? in
                guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
                return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
            }.sorted { $0.2 < $1.2 }
        var bytes = files.reduce(0) { $0 + $1.1 }
        for (url, size, _) in files where bytes > maximumBytes {
            if (try? FileManager.default.removeItem(at: url)) != nil { bytes -= size }
        }
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    private static func text(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
    private static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension MediaSeries {
    /// An episode's provider ID is not the show's, so a show is always found by name.
    var tmdbLookup: TMDBLookup? {
        let title = info?.title ?? self.title
        return title.isEmpty ? nil : TMDBLookup(kind: .tv, title: title, year: info?.year)
    }
}

extension NetworkLibrary {
    func tmdbLookup(group: MediaPresentationGroup) -> TMDBLookup? {
        guard group.kind != .supplement else { return nil }
        let file = group.representative
        let saved = correction(for: file)
        let values = saved?.applies(to: file) == true ? saved?.values : nil
        let metadata = file.metadata ?? MediaFilenameParser.identify(file.path)
        guard (values?.kind ?? metadata.kind) != .episode else { return nil }
        let title = values?.title ?? group.title
        guard !title.isEmpty else { return nil }
        // A correction says the scanned identity was wrong, including any ID it carried.
        return TMDBLookup(kind: .movie, title: title, year: values?.year ?? metadata.year,
                          knownID: values == nil ? metadata.providerIDs["tmdb"].flatMap(Int.init) : nil)
    }
}
