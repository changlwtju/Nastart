import Foundation

public struct LocalSeriesMetadata: Codable, Equatable, Sendable {
    public let folder: DAVPath
    public let title: String
    public let year: Int?
    public let plot: String?
    public var artwork: LocalArtworkReference?
    init(folder: DAVPath, title: String, year: Int? = nil, plot: String? = nil, artwork: LocalArtworkReference? = nil) {
        self.folder = folder; self.title = title; self.year = year; self.plot = plot; self.artwork = artwork
    }
    func isValid(root: DAVPath, video: DAVPath) -> Bool {
        folder.isWithin(root) && video.isWithin(folder) && !title.isEmpty && title.count <= 512
            && (artwork.map { $0.isValid(root: root) && $0.path.parent == folder } ?? true)
    }
}

enum MediaCategory: String, CaseIterable, Identifiable, Sendable {
    case movies, television, animation, unclassified
    var id: String { rawValue }
    var title: String {
        switch self { case .movies: return networkL("电影"); case .television: return networkL("电视剧"); case .animation: return networkL("动漫"); case .unclassified: return networkL("待分类") }
    }
}

enum SeriesLayout {
    static func explicitTitle(_ file: RemoteMediaEntry) -> String? {
        if let title = file.metadata?.showTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { return title }
        let parsed = MediaFilenameParser.identify(file.path)
        guard parsed.kind == .episode, parsed.title != (file.path.name as NSString).deletingPathExtension else { return nil }
        // A filename containing only S01E01 has no show identity.
        guard !parsed.title.isEmpty, parsed.title.range(of: #"(?i)^s\d+e\d+"#, options: .regularExpression) == nil else { return nil }
        return parsed.title
    }
    static func season(_ name: String) -> Int? {
        if ["specials", "特典", "特别篇"].contains(name.lowercased()) { return 0 }
        for pattern in [#"(?i)^(?:season|s)[ ._\-]*([0-9]{1,3})$"#, #"^第([0-9]{1,3})季$"#] {
            if let match = name.range(of: pattern, options: .regularExpression) {
                let numbers = name[match].filter(\.isNumber)
                if let number = Int(numbers) { return number }
            }
        }
        return nil
    }
    static func folder(_ file: RemoteMediaEntry, root: DAVPath) -> DAVPath {
        if let info = file.metadata?.series, info.isValid(root: root, video: file.path) { return info.folder }
        let parent = file.path.parent ?? root
        if season(parent.name) != nil, let show = parent.parent, show.isWithin(root) { return show }
        return parent
    }
}

struct MediaSeason: Identifiable, Sendable {
    let number: Int?
    let files: [RemoteMediaEntry]
    var id: String { number.map(String.init) ?? "unknown" }
    var title: String { number.map { $0 == 0 ? networkL("特别篇") : networkL("第 \($0) 季") } ?? networkL("未分季") }
}

struct MediaSeries: Identifiable, Sendable {
    let id: String
    let title: String
    let folder: DAVPath
    let files: [RemoteMediaEntry]
    var info: LocalSeriesMetadata? { files.compactMap { $0.metadata?.series }.first }
    var seasons: [MediaSeason] {
        let buckets = Dictionary(grouping: files) { file in
            file.metadata?.season ?? MediaFilenameParser.identify(file.path).season ?? file.path.parent.flatMap { SeriesLayout.season($0.name) }
        }
        return buckets.map { number, files in
            MediaSeason(number: number, files: files.sorted {
                let a = $0.metadata?.episode ?? MediaFilenameParser.identify($0.path).episode
                let b = $1.metadata?.episode ?? MediaFilenameParser.identify($1.path).episode
                if a != b { return (a ?? Int.max) < (b ?? Int.max) }
                return $0.path.displayPath.localizedStandardCompare($1.path.displayPath) == .orderedAscending
            })
        }.sorted { ($0.number ?? Int.max) < ($1.number ?? Int.max) }
    }
}

struct MediaCatalogItem: Identifiable, Sendable {
    let id: String
    let category: MediaCategory
    let movie: MediaPresentationGroup?
    let series: MediaSeries?
    var title: String { series?.title ?? movie!.title }
    var files: [RemoteMediaEntry] { series?.files ?? movie!.files }
}

/// Build presentation projections away from the UI executor. A complete index
/// snapshot, including local corrections, is the revision: an unchanged library
/// reuses its projection and removed libraries release their cached files.
actor MediaCatalogCache {
    private var entries: [UUID: (library: NetworkLibrary, items: [MediaCatalogItem])] = [:]

    func catalogs(for libraries: [NetworkLibrary]) throws -> [UUID: [MediaCatalogItem]] {
        var next: [UUID: (library: NetworkLibrary, items: [MediaCatalogItem])] = [:]
        for library in libraries {
            try Task.checkCancellation()
            if let prior = entries[library.id], prior.library == library {
                next[library.id] = prior
            } else {
                next[library.id] = (library, MediaCatalog.items(library))
            }
        }
        try Task.checkCancellation()
        entries = next
        return next.mapValues(\.items)
    }
}

enum MediaCatalog {
    private static let animations: Set<String> = ["动漫", "动画", "动画片", "anime", "animation", "animations"]
    private static let movies: Set<String> = ["电影", "影片", "movies", "movie", "films"]
    private static let shows: Set<String> = ["电视剧", "剧集", "电视", "tv", "tv shows", "tvshows", "shows", "series"]
    static func category(_ file: RemoteMediaEntry, library: NetworkLibrary) -> MediaCategory {
        let base = URL(string: library.address)?.path.split(separator: "/").map(String.init) ?? []
        let folders = base + file.path.encodedSegments.dropLast().map { $0.removingPercentEncoding ?? $0 }
        // Animation is a library category even for an animated feature film.
        if folders.contains(where: { animations.contains($0.lowercased()) }) { return .animation }
        let kind = file.metadata?.kind ?? MediaFilenameParser.identify(file.path).kind
        if kind == .episode { return .television }
        if kind == .movie { return .movies }
        if let explicit = folders.reversed().first(where: { movies.contains($0.lowercased()) || shows.contains($0.lowercased()) }) {
            return movies.contains(explicit.lowercased()) ? .movies : .television
        }
        return .unclassified
    }
    // Display corrections are overlays. The original NFO/index and the file
    // version used to validate a correction must never be rewritten here.
    static func effectiveFile(_ file: RemoteMediaEntry, library: NetworkLibrary) -> RemoteMediaEntry {
        guard let correction = library.correction(for: file), correction.applies(to: file) else { return file }
        let values = correction.values
        var result = file, metadata = file.metadata ?? MediaFilenameParser.identify(file.path)
        metadata.title = values.title; metadata.year = values.year; metadata.kind = values.kind
        metadata.season = values.season; metadata.episode = values.episode; metadata.episodeEnd = values.episodeEnd
        if values.kind != .episode { metadata.series = nil; metadata.showTitle = nil }
        result.metadata = metadata
        return result
    }
    static func items(_ library: NetworkLibrary) -> [MediaCatalogItem] {
        var episodes: [String: [RemoteMediaEntry]] = [:], remaining: [RemoteMediaEntry] = []
        for original in library.files {
            let file = effectiveFile(original, library: library)
            let kind = file.metadata?.kind ?? MediaFilenameParser.identify(file.path).kind
            if kind == .episode {
                let folder = SeriesLayout.folder(file, root: library.root)
                let category = category(file, library: library)
                let discriminator = (file.metadata?.series?.title ?? SeriesLayout.explicitTitle(file))?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let key = category.rawValue + ":" + folder.key + ":" + discriminator
                episodes[key, default: []].append(file)
            } else { remaining.append(file) }
        }
        var result = episodes.map { key, members -> MediaCatalogItem in
            let files = members.sorted { $0.id < $1.id }, first = files[0], folder = SeriesLayout.folder(first, root: library.root)
            let baseName = URL(string: library.address)?.lastPathComponent ?? ""
            let title = first.metadata?.series?.title ?? SeriesLayout.explicitTitle(first) ?? (folder.name.isEmpty ? baseName : folder.name)
            let series = MediaSeries(id: "series:" + key, title: title.isEmpty ? networkL("未命名剧集") : title, folder: folder, files: files)
            return .init(id: series.id, category: category(first, library: library), movie: nil, series: series)
        }
        result += MediaPresentation.groups(remaining, root: library.root).map {
            .init(id: $0.id, category: category($0.representative, library: library), movie: $0, series: nil)
        }
        return result.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}
