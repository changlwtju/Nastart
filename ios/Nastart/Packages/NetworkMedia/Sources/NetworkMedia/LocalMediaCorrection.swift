import Foundation

/// User identification is an overlay; the scanned filename/NFO and provider IDs stay untouched.
public struct LocalMediaCorrection: Codable, Equatable, Sendable {
    public struct Values: Codable, Equatable, Sendable {
        public let title: String
        public let year: Int?
        public let kind: LocalMediaMetadata.Kind
        public let season: Int?
        public let episode: Int?
        public let episodeEnd: Int?
        public init(title: String, year: Int? = nil, kind: LocalMediaMetadata.Kind = .unknown,
                    season: Int? = nil, episode: Int? = nil, episodeEnd: Int? = nil) throws {
            let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title.count <= 512, title.utf8.count <= 2048,
                  !title.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  year.map({ (1000...2999).contains($0) }) ?? true else { throw NetworkMediaError.invalidCorrection }
            if kind == .episode {
                guard let season, (0...9999).contains(season), let episode, (0...99999).contains(episode),
                      episodeEnd.map({ (episode...99999).contains($0) }) ?? true else { throw NetworkMediaError.invalidCorrection }
            } else {
                guard season == nil, episode == nil, episodeEnd == nil else { throw NetworkMediaError.invalidCorrection }
            }
            self.title = title; self.year = year; self.kind = kind
            self.season = season; self.episode = episode; self.episodeEnd = episodeEnd
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(title: c.decode(String.self, forKey: .title), year: c.decodeIfPresent(Int.self, forKey: .year),
                          kind: c.decode(LocalMediaMetadata.Kind.self, forKey: .kind), season: c.decodeIfPresent(Int.self, forKey: .season),
                          episode: c.decodeIfPresent(Int.self, forKey: .episode), episodeEnd: c.decodeIfPresent(Int.self, forKey: .episodeEnd))
        }
    }
    public struct Fingerprint: Codable, Equatable, Sendable {
        public let size: Int64?
        public let modified: String?
        public let etag: String?
        public init(_ file: RemoteMediaEntry) { size = file.size; modified = file.modified; etag = file.etag }
        /// These are server version hints, not a content hash or proof of unchanged bytes.
        public var hasVersionHint: Bool {
            !(etag?.isEmpty ?? true) || (size != nil && !(modified?.isEmpty ?? true))
        }
    }
    public let path: DAVPath
    public let values: Values
    public let fingerprint: Fingerprint
    public let savedAt: Date
    init(file: RemoteMediaEntry, values: Values) {
        path = file.path; self.values = values; fingerprint = Fingerprint(file); savedAt = Date()
    }
    public func applies(to file: RemoteMediaEntry) -> Bool {
        path == file.path && fingerprint.hasVersionHint && fingerprint == Fingerprint(file)
    }
}

extension NetworkLibrary {
    public func correction(for file: RemoteMediaEntry) -> LocalMediaCorrection? {
        corrections?.first { $0.path == file.path }
    }
}
