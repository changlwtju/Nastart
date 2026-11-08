import Foundation

/// An image that was actually listed beside the video. No NFO URL is followed.
public struct LocalArtworkReference: Codable, Equatable, Sendable {
    public static let maximumBytes = 2 * 1024 * 1024
    public let path: DAVPath
    public let size: Int64?
    public let modified: String?
    public let etag: String?
    init(_ entry: RemoteMediaEntry) {
        path = entry.path; size = entry.size; modified = entry.modified; etag = entry.etag
    }
    var hasVersionHint: Bool { !(etag?.isEmpty ?? true) || (size != nil && !(modified?.isEmpty ?? true)) }
    func isValid(root: DAVPath, video: DAVPath? = nil) -> Bool {
        path != root && path.isWithin(root) && Self.isSupported(path.name)
            && (video == nil || path.parent == video?.parent ||
                (video.flatMap(BluRayLayout.movieFolder).map { $0.isWithin(root) && path.parent == $0 } ?? false))
            && (size.map { $0 >= 0 && $0 <= Self.maximumBytes } ?? true)
    }
    static func isSupported(_ name: String) -> Bool {
        ["jpg", "jpeg", "png"].contains((name as NSString).pathExtension.lowercased())
    }
}

/// Exact video-stem posters first. A shared folder poster is used only for a
/// single movie, never guessed for several movies or individual TV episodes.
struct LocalArtworkSelection {
    static func seriesCandidate(siblings: [RemoteMediaEntry], folder: DAVPath) -> LocalArtworkReference? {
        let stem = folder.name.lowercased()
        let named = Dictionary(grouping: siblings.filter { !$0.isDirectory && $0.path.parent == folder && LocalArtworkReference.isSupported($0.path.name) }, by: { $0.path.name.lowercased() })
        for base in [stem + "-poster", stem + ".poster", "poster", "folder", "cover"] {
            for ext in ["jpg", "jpeg", "png"] {
                guard let candidates = named[base + "." + ext] else { continue }
                guard candidates.count == 1 else { return nil }
                let ref = LocalArtworkReference(candidates[0])
                if ref.size.map({ $0 > 0 && $0 <= LocalArtworkReference.maximumBytes }) ?? true { return ref }
            }
        }
        return nil
    }
    private let movieFiles: Set<String>
    private let named: [String: [RemoteMediaEntry]]
    init(siblings: [RemoteMediaEntry]) {
        let videos = siblings.filter(\.isVideo)
        movieFiles = MediaPresentation.sharesMovieFolder(videos) ? Set(videos.map(\.id)) : []
        named = Dictionary(grouping: siblings.filter { !$0.isDirectory && LocalArtworkReference.isSupported($0.path.name) },
                           by: { $0.path.name.lowercased() })
    }
    func candidate(video: RemoteMediaEntry) -> LocalArtworkReference? {
        let stem = (video.path.name as NSString).deletingPathExtension.lowercased()
        var names = ["\(stem)-poster", "\(stem).poster", stem]
        if (video.metadata ?? MediaFilenameParser.identify(video.path)).kind == .episode {
            names.insert("\(stem)-thumb", at: 1)
        }
        if movieFiles.contains(video.id) {
            names += ["poster", "movie", "folder", "cover", "movieset-poster"]
        }
        for name in names {
            for ext in ["jpg", "jpeg", "png"] {
                guard let candidates = named["\(name).\(ext)"] else { continue }
                // Duplicate case variants are ambiguous on case-sensitive servers.
                guard candidates.count == 1, let entry = candidates.first,
                      entry.path.parent == video.path.parent else { return nil }
                let reference = LocalArtworkReference(entry)
                guard reference.size.map({ $0 > 0 && $0 <= LocalArtworkReference.maximumBytes }) ?? true else { continue }
                return reference
            }
        }
        return nil
    }
    /// Backdrops are distinct from posters. Only listed siblings are eligible;
    /// a generic image must never be borrowed by unrelated movies or episodes.
    func backdropCandidate(video: RemoteMediaEntry) -> LocalArtworkReference? {
        let stem = (video.path.name as NSString).deletingPathExtension.lowercased()
        var names = [stem + "-fanart", stem + ".fanart", stem + "-backdrop", stem + ".backdrop"]
        if movieFiles.contains(video.id), (video.metadata ?? MediaFilenameParser.identify(video.path)).kind != .episode {
            names += ["fanart", "backdrop", "background"]
        }
        for name in names {
            for ext in ["jpg", "jpeg", "png"] {
                guard let candidates = named[name + "." + ext] else { continue }
                guard candidates.count == 1, let entry = candidates.first,
                      entry.path.parent == video.path.parent else { return nil }
                let reference = LocalArtworkReference(entry)
                if reference.size.map({ $0 > 0 && $0 <= LocalArtworkReference.maximumBytes }) ?? true { return reference }
            }
        }
        return nil
    }
}

public protocol ReadOnlyArtworkSource: ReadOnlyDirectorySource {
    func readArtwork(_ reference: LocalArtworkReference, root: DAVPath) async throws -> Data
}
