import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public struct LocalMediaMetadata: Codable, Equatable, Sendable {
    public enum Origin: String, Codable, Sendable { case filename, nfo }
    public enum Kind: String, Codable, Sendable { case unknown, movie, episode }
    public enum Notice: String, Codable, Sendable { case invalidNFO, ambiguousNFO, oversizedNFO }
    public var title: String
    public var year: Int?
    public var kind: Kind
    public var season: Int?
    public var episode: Int?
    public var episodeEnd: Int?
    public var plot: String?
    public var providerIDs: [String: String]
    public var origin: Origin
    public var nfoPath: DAVPath?
    public var notice: Notice?
    public var artwork: LocalArtworkReference?
    public var showTitle: String?
    public var series: LocalSeriesMetadata?
    public var details: LocalMediaDetails?
    public init(title: String, year: Int? = nil, kind: Kind = .unknown, season: Int? = nil, episode: Int? = nil,
                episodeEnd: Int? = nil, plot: String? = nil, providerIDs: [String: String] = [:],
                origin: Origin = .filename, nfoPath: DAVPath? = nil, notice: Notice? = nil,
                artwork: LocalArtworkReference? = nil, showTitle: String? = nil, series: LocalSeriesMetadata? = nil, details: LocalMediaDetails? = nil) {
        self.title = title; self.year = year; self.kind = kind; self.season = season; self.episode = episode
        self.episodeEnd = episodeEnd; self.plot = plot; self.providerIDs = providerIDs
        self.origin = origin; self.nfoPath = nfoPath; self.notice = notice
        self.artwork = artwork
        self.showTitle = showTitle; self.series = series; self.details = details
    }
}

/// Optional local sidecar facts. No field is a URL or triggers a provider request.
public struct LocalMediaDetails: Codable, Equatable, Sendable {
    public struct Person: Codable, Equatable, Sendable {
        public var name: String
        public var role: String
    }
    public var originalTitle: String?
    public var tagline: String?
    public var runtimeMinutes: Int?
    public var rating: Double?
    public var officialRating: String?
    public var genres: [String] = []
    public var studios: [String] = []
    public var directors: [String] = []
    public var people: [Person] = []
    public var video: String?
    public var audio: String?

    /// Directors and actors share one stable credits shelf. A person with
    /// multiple jobs keeps one card rather than moving between page sections.
    public var displayPeople: [Person] {
        var result: [Person] = []
        for person in directors.map({ Person(name: $0, role: "导演") }) + people {
            if let index = result.firstIndex(where: { $0.name.caseInsensitiveCompare(person.name) == .orderedSame }) {
                let roles = result[index].role.components(separatedBy: " · ")
                if !person.role.isEmpty, !roles.contains(person.role) {
                    result[index].role = (roles.filter { !$0.isEmpty } + [person.role]).joined(separator: " · ")
                }
            } else { result.append(person) }
        }
        return result
    }
}

/// A hint for display/search, never an assertion of a provider match.
public enum MediaFilenameParser {
    public static func identify(_ path: DAVPath) -> LocalMediaMetadata {
        let stem = (path.name as NSString).deletingPathExtension
        var title = stem, result = LocalMediaMetadata(title: stem)
        func first(_ pattern: String) -> NSTextCheckingResult? {
            try? NSRegularExpression(pattern: pattern, options: .caseInsensitive).firstMatch(in: stem, range: NSRange(stem.startIndex..., in: stem))
        }
        func group(_ match: NSTextCheckingResult, _ index: Int) -> String? {
            guard index < match.numberOfRanges, let range = Range(match.range(at: index), in: stem) else { return nil }
            return String(stem[range])
        }
        let episode = first(#"(?<![A-Za-z0-9])S(\d{1,2})[ ._-]*E(\d{1,3})(?:[ ._-]*E(\d{1,3}))?(?!\d)"#)
            ?? first(#"(?<![A-Za-z0-9])(\d{1,2})x(\d{1,3})(?:-(\d{1,3}))?(?!\d)"#)
        if let episode {
            result.kind = .episode; result.season = group(episode, 1).flatMap(Int.init)
            result.episode = group(episode, 2).flatMap(Int.init)
            if let end = group(episode, 3).flatMap(Int.init), end >= (result.episode ?? 0) { result.episodeEnd = end }
            title = (stem as NSString).substring(to: episode.range.location)
        }
        // Only separated four-digit years. "1917", "2001 A Space Odyssey" and "Blade Runner 2049" stay titles.
        if let yearMatch = first(#"[ ._\[(\-]+((?:18|19|20|21)\d{2})(?=$|[ ._\])\-])"#),
           yearMatch.range.location < (episode?.range.location ?? (stem as NSString).length) {
            result.year = group(yearMatch, 1).flatMap(Int.init)
            title = (stem as NSString).substring(to: yearMatch.range.location)
        }
        // If an unbracketed terminal year could be part of the name, retain it rather than silently changing the title.
        if episode == nil, let year = result.year, stem.hasSuffix(String(year)),
           !stem.contains("(") && !stem.contains("[") && !stem.contains(".") && !stem.contains("_") {
            title = stem; result.year = nil
        }
        title = title.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-[]()")))
        result.title = title.isEmpty ? stem : title
        if episode == nil, let local = localizedFolderTitle(of: path, title: result.title) { result.title = local }
        return result
    }
    /// A release folder often leads with the localized name: `功夫.Kung.Fu.Hustle.2004.BluRay/Kung.Fu.Hustle.2004.BluRay.mkv`.
    /// The folder must also carry the file's own title, so `电影/Inception.mkv` is not renamed "电影".
    private static func localizedFolderTitle(of path: DAVPath, title: String) -> String? {
        guard let folder = path.parent?.name, title.unicodeScalars.allSatisfy({ $0.isASCII }) else { return nil }
        func squeeze(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
        guard !squeeze(title).isEmpty, squeeze(folder).contains(squeeze(title)),
              let match = try? NSRegularExpression(pattern: #"^\[?(\p{Han}[^.\]\s]*)"#).firstMatch(in: folder, range: NSRange(folder.startIndex..., in: folder)),
              let range = Range(match.range(at: 1), in: folder) else { return nil }
        return String(folder[range])
    }
    /// What a release name states about its streams. Only used where no sidecar says otherwise.
    static func technicalDetails(_ path: DAVPath) -> LocalMediaDetails? {
        let name = path.name.lowercased()
        func has(_ pattern: String) -> Bool { name.range(of: pattern, options: .regularExpression) != nil }
        let codec = has(#"(x|h\.?)265|hevc"#) ? "HEVC" : has(#"(x|h\.?)264|avc"#) ? "H264" : nil
        let resolution = has("2160p|4k") ? "2160p" : has("1080p") ? "1080p" : has("720p") ? "720p" : has("480p") ? "480p" : nil
        let video = [codec, resolution].compactMap { $0 }.joined(separator: " · ")
        guard !video.isEmpty else { return nil }
        var details = LocalMediaDetails(); details.video = video
        return details
    }
}

public enum NFOReader {
    public static let maxBytes = 512 * 1024
    public static func parse(_ data: Data, fallback: LocalMediaMetadata, path: DAVPath) throws -> LocalMediaMetadata {
        guard data.count <= maxBytes, let text = String(data: data, encoding: .utf8),
              !text.uppercased().contains("<!DOCTYPE"), !text.uppercased().contains("<!ENTITY") else { throw NetworkMediaError.invalidMetadata }
        let delegate = NFOTags()
        let parser = XMLParser(data: data); parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        guard parser.parse(), !delegate.failed, ["movie", "episodedetails"].contains(delegate.root),
              let title = delegate.fields["title"], !title.isEmpty, title.count <= 512 else { throw NetworkMediaError.invalidMetadata }
        let episodeNFO = delegate.root == "episodedetails"
        // A movie sidecar must not turn a filename identified as an episode into a movie.
        guard episodeNFO || fallback.kind != .episode else { throw NetworkMediaError.invalidMetadata }
        func number(_ key: String, _ range: ClosedRange<Int>) -> Int? {
            guard let n = delegate.fields[key].flatMap(Int.init), range.contains(n) else { return nil }; return n
        }
        var result = LocalMediaMetadata(title: title, year: number("year", 1800...2199) ?? fallback.year,
            kind: episodeNFO ? .episode : .movie, plot: delegate.fields["plot"], providerIDs: delegate.ids,
            origin: .nfo, nfoPath: path)
        result.details = delegate.details
        if episodeNFO {
            result.showTitle = delegate.fields["showtitle"]
            result.season = number("season", 0...999) ?? fallback.season
            result.episode = number("episode", 0...9999) ?? fallback.episode
            // Multi-episode files stay multi-episode only when the starting episode agrees.
            if result.season == fallback.season && result.episode == fallback.episode { result.episodeEnd = fallback.episodeEnd }
        }
        return result
    }
    /// Scene releases ship a plain-text `.nfo` of release notes rather than Kodi XML. It is not a
    /// bad sidecar, and its audio lines are worth keeping beside the filename's identification.
    static func parseOrReleaseNotes(_ data: Data, fallback: LocalMediaMetadata, path: DAVPath) throws -> LocalMediaMetadata {
        do { return try parse(data, fallback: fallback, path: path) } catch NetworkMediaError.invalidMetadata {
            guard data.count <= maxBytes, let text = String(data: data, encoding: .utf8),
                  !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}"))).hasPrefix("<")
            else { throw NetworkMediaError.invalidMetadata }
            var result = fallback
            var details = result.details ?? LocalMediaDetails()
            let audio = text.components(separatedBy: .newlines).compactMap { line -> String? in
                guard line.range(of: #"^\s*audio[ .\d]*:"#, options: [.regularExpression, .caseInsensitive]) != nil,
                      let colon = line.firstIndex(of: ":") else { return nil }
                let value = line[line.index(after: colon)...].replacingOccurrences(of: #"\s+\d+\s*kbps.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
                    .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
                return value.isEmpty ? nil : value
            }
            guard !audio.isEmpty else { throw NetworkMediaError.invalidMetadata }
            details.audio = audio.joined(separator: " / ")
            result.details = details
            result.notice = nil
            return result
        }
    }
    static func parseSeries(_ data: Data, folder: DAVPath) throws -> LocalSeriesMetadata {
        guard data.count <= maxBytes, let text = String(data: data, encoding: .utf8),
              !text.uppercased().contains("<!DOCTYPE"), !text.uppercased().contains("<!ENTITY") else { throw NetworkMediaError.invalidMetadata }
        let delegate = NFOTags(), parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true; parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        guard parser.parse(), !delegate.failed, delegate.root == "tvshow", let title = delegate.fields["title"], !title.isEmpty, title.count <= 512 else { throw NetworkMediaError.invalidMetadata }
        let year = delegate.fields["year"].flatMap(Int.init).flatMap { (1800...2199).contains($0) ? $0 : nil }
        return .init(folder: folder, title: title, year: year, plot: delegate.fields["plot"])
    }
}

private final class NFOTags: NSObject, XMLParserDelegate {
    var root = "", fields: [String: String] = [:], ids: [String: String] = [:], failed = false
    private var stack: [String] = [], texts: [String] = [], provider: String?
    var details = LocalMediaDetails()
    private var actor: [String: String] = [:]
    private var streams: [String: String] = [:]
    private var ratingMaximum: Double?
    private var preferredRating = false
    private let extraSingles: Set<String> = ["originaltitle", "tagline", "runtime", "rating", "mpaa"]
    private let repeated: Set<String> = ["genre", "studio", "director"]
    private let accepted: Set<String> = ["title", "showtitle", "year", "season", "episode", "plot", "imdbid", "tmdbid", "tvdbid", "uniqueid"]
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let key = (namespaceURI == nil || namespaceURI == "") ? name : "foreign"
        if stack.isEmpty { root = key }
        stack.append(key); texts.append("")
        if stack.count > 32 { failed = true; parser.abortParsing() }
        if stack.count == 2 && key == "uniqueid" { provider = attributes["type"]?.lowercased() }
        if stack.count == 2 && key == "actor" { actor = [:] }
        if stack.count == 3 && stack[1] == "ratings" && key == "rating" {
            ratingMaximum = attributes["max"].flatMap(Double.init)
            preferredRating = attributes["default"]?.lowercased() == "true"
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { append(string, parser: parser) }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let text = String(data: CDATABlock, encoding: .utf8) else { failed = true; parser.abortParsing(); return }
        append(text, parser: parser)
    }
    private func append(_ string: String, parser: XMLParser) {
        guard !texts.isEmpty else { return }
        texts[texts.count - 1] += string
        if texts[texts.count - 1].utf8.count > 32_768 { failed = true; parser.abortParsing() }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        guard let key = stack.last, let text = texts.last?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        if stack.count == 2 && accepted.contains(key) {
            if key == "uniqueid" { setID(provider, text) }
            else if key.hasSuffix("id") { setID(String(key.dropLast(2)), text) }
            else if fields[key] != nil { failed = true; parser.abortParsing() }
            else { fields[key] = text }
        }
        if stack.count == 2 && extraSingles.contains(key) {
            // A duplicate singleton is ambiguous, just like the title/plot fields.
            if fields[key] != nil { failed = true; parser.abortParsing() }
            else { fields[key] = text }
        }
        if stack.count == 2 && repeated.contains(key) && !text.isEmpty && text.count <= 512 {
            switch key {
            case "genre": appendUnique(text, to: &details.genres, limit: 32)
            case "studio": appendUnique(text, to: &details.studios, limit: 32)
            default: appendUnique(text, to: &details.directors, limit: 32)
            }
        }
        if stack.count == 3 && stack[1] == "actor" && ["name", "role"].contains(key), text.count <= 512 {
            if actor[key] != nil { failed = true; parser.abortParsing() } else { actor[key] = text }
        }
        if stack.count == 2 && key == "actor", let name = actor["name"], !name.isEmpty, details.people.count < 60 {
            let person = LocalMediaDetails.Person(name: name, role: actor["role"] ?? "")
            if !details.people.contains(person) { details.people.append(person) }
        }
        if stack.count == 4 && stack[1] == "ratings" && stack[2] == "rating" && key == "value",
           preferredRating, ratingMaximum == 10, let value = Double(text), value.isFinite, (0...10).contains(value) {
            details.rating = value
        }
        if stack.count == 5 && stack[1] == "fileinfo" && stack[2] == "streamdetails",
           ["video", "audio"].contains(stack[3]), ["codec", "width", "height", "channels", "language"].contains(key), text.count <= 64 {
            let field = stack[3] + "." + key
            if streams[field] == nil { streams[field] = text }
        }
        if stack.count == 1 {
            details.originalTitle = fields["originaltitle"].flatMap { $0.isEmpty || $0.count > 512 ? nil : $0 }
            details.tagline = fields["tagline"].flatMap { $0.isEmpty || $0.count > 1024 ? nil : $0 }
            details.officialRating = fields["mpaa"].flatMap { $0.isEmpty || $0.count > 128 ? nil : $0 }
            details.runtimeMinutes = fields["runtime"].flatMap(Int.init).flatMap { (1...10000).contains($0) ? $0 : nil }
            if details.rating == nil { details.rating = fields["rating"].flatMap(Double.init).flatMap { $0.isFinite && (0...10).contains($0) ? $0 : nil } }
            let video = [streams["video.codec"]?.uppercased(), streams["video.width"].flatMap(Int.init).flatMap { width in
                streams["video.height"].flatMap(Int.init).flatMap { height in (1...32768).contains(width) && (1...32768).contains(height) ? "\(width)×\(height)" : nil }
            }].compactMap { $0 }.filter { !$0.isEmpty }
            details.video = video.isEmpty ? nil : video.joined(separator: " · ")
            let audio = [streams["audio.codec"]?.uppercased(), streams["audio.channels"].flatMap(Int.init).flatMap { (1...64).contains($0) ? networkL("\($0) 声道") : nil }, streams["audio.language"]].compactMap { $0 }.filter { !$0.isEmpty }
            details.audio = audio.isEmpty ? nil : audio.joined(separator: " · ")
        }
        stack.removeLast(); texts.removeLast()
    }
    private func appendUnique(_ value: String, to values: inout [String], limit: Int) {
        if values.count < limit && !values.contains(value) { values.append(value) }
    }
    private func setID(_ provider: String?, _ value: String) {
        guard let provider, ["imdb", "tmdb", "tvdb"].contains(provider), value.count <= 32 else { return }
        let pattern = provider == "imdb" ? #"^tt\d{5,12}$"# : #"^[1-9]\d{0,11}$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else { return }
        if let previous = ids[provider], previous != value { failed = true } else { ids[provider] = value }
    }
}

struct NFOSidecarSelection {
    private let byStem: [String: [RemoteMediaEntry]]
    private let sharedMovie: Bool
    init(siblings: [RemoteMediaEntry]) {
        sharedMovie = MediaPresentation.sharesMovieFolder(siblings.filter(\.isVideo))
        let nfos = siblings.filter { !$0.isDirectory && ($0.path.name as NSString).pathExtension.lowercased() == "nfo" }
        byStem = Dictionary(grouping: nfos) { ($0.path.name as NSString).deletingPathExtension.lowercased() }
    }
    func candidate(video: RemoteMediaEntry) -> (RemoteMediaEntry?, LocalMediaMetadata.Notice?) {
        let stem = (video.path.name as NSString).deletingPathExtension.lowercased()
        let exact = byStem[stem] ?? []
        if exact.count > 1 { return (nil, .ambiguousNFO) }
        if let match = exact.first { return (match, nil) }
        let generic = sharedMovie ? byStem["movie"] ?? [] : []
        if generic.count > 1 { return (nil, .ambiguousNFO) }
        return (generic.first, nil)
    }
}

/// Fetch only the selected, listed sidecar; keep the previous index untouched.
/// Listing versions are optimistic checks, not an atomic filesystem snapshot.
public enum LocalMediaDetailReader {
    public static func load(file: RemoteMediaEntry, root: DAVPath, source: any ReadOnlyMetadataSource) async throws -> LocalMediaMetadata? {
        guard file.isVideo, file.path != root, file.path.isWithin(root), let folder = file.path.parent,
              folder.isWithin(root) else { throw NetworkMediaError.outsideRoot }
        func valid(_ entries: [RemoteMediaEntry], in directory: DAVPath) -> Bool {
            entries.allSatisfy { $0.path.parent == directory && $0.path.isWithin(root) }
                && Set(entries.map(\.path)).count == entries.count
        }
        let entries = try await source.list(folder)
        try Task.checkCancellation()
        guard valid(entries, in: folder), let listed = entries.first(where: { $0.path == file.path }),
              sameVersion(file, listed) else { throw NetworkMediaError.incompleteListing }
        var watched = [folder: entries], required = [listed]
        var selectionFolder = folder, selectionVideo = file
        var selection = NFOSidecarSelection(siblings: entries).candidate(video: file)
        // Match the scanner's exact movie-folder rule for BDMV/STREAM files;
        // never search arbitrary ancestors or follow an NFO path from an index.
        if selection.0 == nil, selection.1 == nil,
           let movie = BluRayLayout.movieFolder(for: file.path), movie.isWithin(root),
           let bdmv = folder.parent {
            let movieEntries = try await source.list(movie)
            try Task.checkCancellation()
            guard valid(movieEntries, in: movie) else { throw NetworkMediaError.incompleteListing }
            if let proxy = try BluRayLayout.metadataProxy(in: movie, siblings: movieEntries) {
                let bdmvEntries = try await source.list(bdmv)
                try Task.checkCancellation()
                guard valid(bdmvEntries, in: bdmv),
                      let disc = movieEntries.first(where: { $0.path == bdmv && $0.isDirectory }),
                      let stream = bdmvEntries.first(where: { $0.path == folder && $0.isDirectory }) else { throw NetworkMediaError.incompleteListing }
                watched[movie] = movieEntries; watched[bdmv] = bdmvEntries
                required += [disc, stream]
                selectionFolder = movie; selectionVideo = proxy
                selection = NFOSidecarSelection(siblings: movieEntries + [proxy]).candidate(video: proxy)
            }
        }
        guard selection.1 == nil, let sidecar = selection.0 else { return nil }
        guard sidecar.path.parent == selectionFolder, sidecar.path.isWithin(root),
              sidecar.size.map({ $0 >= 0 && $0 <= NFOReader.maxBytes }) ?? true else { throw NetworkMediaError.responseTooLarge }
        let data = try await source.readNFO(sidecar.path, root: root)
        try Task.checkCancellation()
        guard data.count <= NFOReader.maxBytes, sidecar.size.map({ $0 == Int64(data.count) }) ?? true else { throw NetworkMediaError.invalidMetadata }
        required.append(sidecar)
        var after: [DAVPath: [RemoteMediaEntry]] = [:]
        for directory in watched.keys.sorted(by: { $0.key < $1.key }) {
            let current = try await source.list(directory)
            try Task.checkCancellation()
            guard valid(current, in: directory) else { throw NetworkMediaError.incompleteListing }
            after[directory] = current
        }
        for before in required {
            guard let parent = before.path.parent, let last = after[parent]?.first(where: { $0.path == before.path }),
                  sameVersion(before, last) else { throw NetworkMediaError.incompleteListing }
        }
        var finalSiblings = after[selectionFolder] ?? []
        if selectionFolder != folder {
            guard try BluRayLayout.metadataProxy(in: selectionFolder, siblings: finalSiblings) != nil else { throw NetworkMediaError.incompleteListing }
            finalSiblings.append(selectionVideo)
        }
        let finalSelection = NFOSidecarSelection(siblings: finalSiblings).candidate(video: selectionVideo)
        guard finalSelection.1 == nil, finalSelection.0?.path == sidecar.path else { throw NetworkMediaError.incompleteListing }
        var result = try NFOReader.parseOrReleaseNotes(data, fallback: file.metadata ?? MediaFilenameParser.identify(file.path), path: sidecar.path)
        if let old = file.metadata, old.origin == .nfo {
            guard old.nfoPath == sidecar.path, old.title == result.title,
                  old.providerIDs == result.providerIDs else { throw NetworkMediaError.invalidMetadata }
        }
        result.artwork = file.metadata?.artwork; result.series = file.metadata?.series
        return result
    }
    private static func sameVersion(_ a: RemoteMediaEntry, _ b: RemoteMediaEntry) -> Bool {
        a.path == b.path && a.isDirectory == b.isDirectory && a.size == b.size && a.modified == b.modified && a.etag == b.etag
    }
}
