import Foundation
import Security

struct TVAccount: Codable, Equatable {
    let server: URL
    let userID: String
    let userName: String
    let token: String
}

struct TVItemPage: Decodable { let Items: [TVMediaItem] }
struct TVMediaItem: Decodable, Identifiable, Hashable {
    let Id: String
    let Name: String
    let kind: String?
    enum CodingKeys: String, CodingKey { case Id, Name, kind = "Type", SeriesId, SeriesName, SeriesPrimaryImageTag, IndexNumber, ParentIndexNumber, Overview, ProductionYear, RunTimeTicks, IsFolder, UserData, People, Genres, CommunityRating, OfficialRating, Studios, Taglines, BackdropImageTags, MediaStreams, MediaSources }
    let SeriesId: String?
    let SeriesName: String?
    let SeriesPrimaryImageTag: String?
    let IndexNumber: Int?
    let ParentIndexNumber: Int?
    let Overview: String?
    let ProductionYear: Int?
    let RunTimeTicks: Int64?
    let IsFolder: Bool?
    let UserData: TVUserData?
    let People: [TVPerson]?
    let Genres: [String]?
    let CommunityRating: Double?
    let OfficialRating: String?
    let Studios: [TVStudio]?
    let Taglines: [String]?
    let BackdropImageTags: [String]?
    let MediaStreams: [TVDetailStream]?
    let MediaSources: [TVDetailSource]?
    private var detailStreams: [TVDetailStream] { MediaSources?.first?.MediaStreams ?? MediaStreams ?? [] }
    var videoDescription: String? {
        guard let stream = detailStreams.first(where: { $0.kind == "Video" }) else { return nil }
        let range = stream.VideoRangeType?.lowercased()
        return MediaDetailDesign.videoDescription(height: stream.Height, codec: stream.Codec,
            isHDR: range.map { !["unknown", "sdr"].contains($0) } ?? false, fallback: stream.DisplayTitle)
    }
    var audioDescription: String? {
        guard let stream = detailStreams.first(where: { $0.kind == "Audio" }) else { return nil }
        return MediaDetailDesign.audioDescription(codec: stream.Codec, channels: stream.Channels, fallback: stream.DisplayTitle)
    }
    var posterID: String {
        if kind == "Episode", let series = SeriesId, !series.isEmpty, let tag = SeriesPrimaryImageTag, !tag.isEmpty { return series }
        return Id
    }
    var posterTitle: String { kind == "Episode" ? (SeriesName ?? Name) : Name }
    var posterSubtitle: String {
        if kind == "Episode" {
            let number = IndexNumber.map { "第\($0)集" } ?? ""
            return [number, Name].filter { !$0.isEmpty }.joined(separator: " · ")
        }
        return ProductionYear.map(String.init) ?? (isFolder ? "媒体目录" : "")
    }
    var id: String { Id }
    var isFolder: Bool { IsFolder == true || ["Series", "Season", "CollectionFolder", "Folder", "BoxSet", "MusicAlbum", "MusicArtist", "Playlist"].contains(kind ?? "") }
    var isAudio: Bool { kind == "Audio" }
    var resumeSeconds: Double { Double(UserData?.PlaybackPositionTicks ?? 0) / 10_000_000 }
    var duration: String {
        guard let ticks = RunTimeTicks, ticks > 0 else { return "" }
        return "\(Int(ticks / 600_000_000)) 分钟"
    }
}
/// Read-only source metadata for detail facts, independent of playback negotiation.
struct TVDetailSource: Decodable, Hashable {
    let MediaStreams: [TVDetailStream]?
    let Path: String?
    let Container: String?
    let Size: Int64?
    let Bitrate: Int64?
}
struct TVDetailStream: Decodable, Hashable {
    let kind: String?
    enum CodingKeys: String, CodingKey { case kind = "Type", Codec, Height, Channels, VideoRangeType, DisplayTitle }
    let Codec: String?
    let Height: Int?
    let Channels: Int?
    let VideoRangeType: String?
    let DisplayTitle: String?
}
struct TVPerson: Decodable, Identifiable, Hashable {
    let Id: String?
    let Name: String
    let Role: String?
    let kind: String?
    enum CodingKeys: String, CodingKey { case Id, Name, Role, kind = "Type" }
    var id: String { Id ?? Name + (Role ?? kind ?? "") }
}
struct TVStudio: Decodable, Hashable { let Name: String }
struct TVUserData: Decodable, Hashable { let PlaybackPositionTicks: Int64? }
struct TVLoginResponse: Decodable {
    struct User: Decodable { let Id: String; let Name: String }
    let AccessToken: String
    let User: User
}
struct TVPlaybackInfo: Decodable {
    struct Source: Decodable {
        let Id: String
        let SupportsDirectPlay: Bool?
        let SupportsDirectStream: Bool?
        let Container: String?
        let DirectStreamUrl: String?
        let TranscodingUrl: String?
        let MediaStreams: [TVSourceTrack]?
        let DefaultAudioStreamIndex: Int?
        let DefaultSubtitleStreamIndex: Int?
    }
    let MediaSources: [Source]
    let PlaySessionId: String?
    let ErrorCode: String?
}

struct TVPlaybackRoute {
    let url: URL
    let sourceID: String
    let playSessionID: String?
    let playMethod: String
    var tracks: [TVSourceTrack] = []
    var audioIndex: Int? = nil
    var subtitleIndex: Int = -1
}

/// Jellyfin indices belong to the original source, never to an AV option array.
struct TVSourceTrack: Decodable, Equatable, Identifiable {
    let Index: Int
    let kind: String
    let DisplayTitle: String?
    let Language: String?
    let Codec: String?
    let IsExternal: Bool?
    enum CodingKeys: String, CodingKey { case Index, kind = "Type", DisplayTitle, Language, Codec, IsExternal }
    var id: Int { Index }
    var name: String {
        if let title = DisplayTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { return title }
        let parts = [Language, Codec?.uppercased(), IsExternal == true ? "外置" : nil].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "\(kind == "Audio" ? "音轨" : "字幕") #\(Index)" : parts.joined(separator: " · ")
    }
}

struct TVSourceSelection: Equatable {
    let sourceID: String
    let audioIndex: Int?
    let subtitleIndex: Int

    func isValid(in route: TVPlaybackRoute) -> Bool {
        sourceID == route.sourceID && !sourceID.isEmpty &&
        (audioIndex == nil || route.tracks.contains { $0.kind == "Audio" && $0.Index == audioIndex }) &&
        (subtitleIndex == -1 || route.tracks.contains { $0.kind == "Subtitle" && $0.Index == subtitleIndex })
    }
}

enum TVClientError: LocalizedError {
    case invalidServer, http(Int), invalidResponse, noPlayableSource, unsafeMediaURL, keychain(OSStatus)
    var errorDescription: String? {
        switch self {
        case .invalidServer: return "请输入完整的服务器地址与端口，例如 https://nas.example.com:5001。"
        case .http(let code):
            return code == 401 || code == 403 ? "登录已失效或账号没有播放权限，请重新登录。" : "服务器请求失败（\(code)），请稍后重试。"
        case .invalidResponse: return "服务器返回了无法识别的内容。"
        case .noPlayableSource: return "服务器没有返回 Apple TV 可播放的媒体流，请检查 Jellyfin 转码设置。"
        case .unsafeMediaURL: return "媒体地址与登录的服务器不一致，无法安全地发送播放凭据。"
        case .keychain: return "无法安全保存登录信息，请重试。"
        }
    }
}

/// Logical reading order supplements tvOS spatial focus for a lazily realised grid.
/// Leaving the top/bottom edge returns nil so the surrounding page keeps native focus.
enum TVMediaGridNavigation {
    enum Direction { case left, right, up, down }
    static func target(from index: Int, count: Int, columns: Int, direction: Direction) -> Int? {
        guard count > 0, columns > 0, index >= 0, index < count else { return nil }
        switch direction {
        case .right: return index + 1 < count ? index + 1 : nil
        case .left: return index > 0 ? index - 1 : nil
        case .up: return index >= columns ? index - columns : nil
        case .down:
            guard index / columns < (count - 1) / columns else { return nil }
            return min(index + columns, count - 1)
        }
    }
}
