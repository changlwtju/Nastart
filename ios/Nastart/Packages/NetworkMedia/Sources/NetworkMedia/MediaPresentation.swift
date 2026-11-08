import Foundation

/// A presentation projection only: every physical file remains in the index.
struct MediaPresentationGroup: Identifiable, Equatable, Sendable {
    enum Kind { case video, bluRay, segments, supplement }
    let id: String
    let kind: Kind
    let files: [RemoteMediaEntry]
    let folder: DAVPath?
    var representative: RemoteMediaEntry { files.first { $0.metadata?.artwork != nil } ?? files.first { $0.metadata?.origin == .nfo } ?? files[0] }
    var title: String {
        if kind == .bluRay, representative.metadata?.origin != .nfo { return folder?.name ?? representative.path.name }
        let title = representative.metadata?.title ?? MediaFilenameParser.identify(representative.path).title
        if kind == .segments, representative.metadata?.origin != .nfo {
            return title.replacingOccurrences(of: #"(?i)[ ._\-]+(?:cd|disc|disk)[ ._\-]*[1-9][0-9]?$"#, with: "", options: .regularExpression)
        }
        return title
    }
}

enum BluRayLayout {
    static func metadataProxy(in folder: DAVPath, siblings: [RemoteMediaEntry]) throws -> RemoteMediaEntry? {
        guard siblings.filter({ $0.isDirectory && $0.path.name.lowercased() == "bdmv" }).count == 1,
              !siblings.contains(where: \.isVideo) else { return nil }
        let name = try DAVPath((folder.name.isEmpty ? "movie" : folder.name) + ".mkv").key
        return RemoteMediaEntry(path: DAVPath(validated: folder.encodedSegments + [name]), isDirectory: false)
    }
    static func movieFolder(for path: DAVPath) -> DAVPath? {
        guard (path.name as NSString).pathExtension.lowercased() == "m2ts",
              let stream = path.parent, stream.name.lowercased() == "stream",
              let bdmv = stream.parent, bdmv.name.lowercased() == "bdmv" else { return nil }
        return bdmv.parent
    }
}

enum MediaPresentation {
    private static let splitExpression = try! NSRegularExpression(pattern: #"(?i)^(.+?)[ ._\-]+(?:cd|disc|disk)[ ._\-]*([1-9][0-9]?)$"#)
    static func sharesMovieFolder(_ videos: [RemoteMediaEntry]) -> Bool {
        guard let first = videos.first, let parent = first.path.parent,
              videos.allSatisfy({ $0.path.parent == parent && ($0.metadata ?? MediaFilenameParser.identify($0.path)).kind != .episode }) else { return false }
        if videos.count == 1 { return true }
        let values = groups(videos, root: parent)
        return values.count == 1 && values[0].kind == .segments
    }
    static func groups(_ files: [RemoteMediaEntry], root: DAVPath) -> [MediaPresentationGroup] {
        var disc: [DAVPath: [RemoteMediaEntry]] = [:], rest: [RemoteMediaEntry] = []
        for file in files {
            if let folder = BluRayLayout.movieFolder(for: file.path), folder.isWithin(root) {
                disc[folder, default: []].append(file)
            } else { rest.append(file) }
        }
        var result = disc.map { folder, files in
            MediaPresentationGroup(id: "disc:" + folder.key, kind: .bluRay, files: ordered(files), folder: folder)
        }
        var splits: [String: [(Int, RemoteMediaEntry)]] = [:]
        for file in rest {
            if !isSupplement(file, root: root), let (base, number) = segment(file) {
                splits[(file.path.parent?.key ?? "") + "/" + base, default: []].append((number, file))
            }
        }
        var merged = Set<String>()
        for (key, candidates) in splits {
            let sorted = candidates.sorted { $0.0 < $1.0 }
            guard sorted.count >= 2, sorted.map(\.0) == Array(1...sorted.count), compatible(sorted.map(\.1)) else { continue }
            let members = sorted.map(\.1); merged.formUnion(members.map(\.id))
            result.append(.init(id: "segments:" + key, kind: .segments, files: members, folder: members[0].path.parent))
        }
        for file in rest where !merged.contains(file.id) {
            result.append(.init(id: "file:" + file.id, kind: isSupplement(file, root: root) ? .supplement : .video, files: [file], folder: nil))
        }
        return result.sorted { $0.files[0].path.displayPath.localizedStandardCompare($1.files[0].path.displayPath) == .orderedAscending }
    }
    private static func ordered(_ files: [RemoteMediaEntry]) -> [RemoteMediaEntry] { files.sorted { $0.id < $1.id } }
    private static func segment(_ file: RemoteMediaEntry) -> (String, Int)? {
        guard (file.metadata ?? MediaFilenameParser.identify(file.path)).kind != .episode else { return nil }
        let stem = (file.path.name as NSString).deletingPathExtension
        // Part/第N部 often denotes a genuine sequel. Only explicit terminal
        // disc/CD markers in the same folder can qualify for automatic merging.
        guard let match = splitExpression.firstMatch(in: stem, range: NSRange(stem.startIndex..., in: stem)),
              let number = Int((stem as NSString).substring(with: match.range(at: 2))) else { return nil }
        return ((stem as NSString).substring(with: match.range(at: 1)).lowercased(), number)
    }
    private static func compatible(_ files: [RemoteMediaEntry]) -> Bool {
        let metadata = files.compactMap(\.metadata)
        guard Set(metadata.compactMap(\.year)).count <= 1,
              Set(metadata.filter { $0.origin == .nfo }.map { $0.title.lowercased() }).count <= 1 else { return false }
        for provider in ["tmdb", "imdb", "tvdb"] {
            if Set(metadata.compactMap { $0.providerIDs[provider] }).count > 1 { return false }
        }
        return true
    }
    static func isSupplement(_ file: RemoteMediaEntry, root: DAVPath) -> Bool {
        guard (file.metadata ?? MediaFilenameParser.identify(file.path)).kind != .episode else { return false }
        let folders = file.path.encodedSegments.dropFirst(root.encodedSegments.count).dropLast().map { ($0.removingPercentEncoding ?? $0).lowercased() }
        let names: Set<String> = ["extras", "featurettes", "trailers", "samples", "behind the scenes", "花絮", "预告片", "样片"]
        if folders.contains(where: names.contains) { return true }
        let stem = (file.path.name as NSString).deletingPathExtension
        return stem.range(of: #"(?i)[._\-](?:sample|trailer|featurette)$"#, options: .regularExpression) != nil
    }
}
