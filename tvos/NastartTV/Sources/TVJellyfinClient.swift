import Foundation
import CryptoKit
import OSLog

/// Native tvOS API boundary. Range racing and iOS renderer code stay on mobile.
struct TVJellyfinClient {
    let server: URL
    let token: String?
    let userID: String?
    let deviceID: String
    let session: URLSession

    init(server: URL, token: String? = nil, userID: String? = nil,
         deviceID: String, session: URLSession = .shared) {
        self.server = server; self.token = token; self.userID = userID
        self.deviceID = deviceID; self.session = session
    }
    init(account: TVAccount, deviceID: String) {
        self.init(server: account.server, token: account.token, userID: account.userID, deviceID: deviceID)
    }
    static func serverURL(_ value: String) throws -> URL {
        guard var parts = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              parts.host != nil, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil else { throw TVClientError.invalidServer }
        parts.path = parts.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !parts.path.isEmpty { parts.path = "/" + parts.path }
        guard let url = parts.url else { throw TVClientError.invalidServer }
        return url
    }
    func endpoint(_ path: [String], query: [URLQueryItem] = []) -> URL {
        let url = path.reduce(server) { $0.appendingPathComponent($1) }
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        parts.queryItems = query.isEmpty ? nil : query
        return parts.url!
    }
    var authorization: String {
        let identity = "MediaBrowser Client=\"Nastart TV\", Device=\"Apple TV\", DeviceId=\"\(deviceID)\", Version=\"0.1.0\""
        return identity + (token.map { ", Token=\"\($0)\"" } ?? "")
    }
    static func trace(_ event: String, token: String? = nil) {
        let fingerprint = token.map { SHA256.hash(data: Data($0.utf8)).prefix(6).map { String(format: "%02x", $0) }.joined() } ?? "none"
        Logger(subsystem: "com.changliwen.nastart.tv", category: "JellyfinSession")
            .notice("\(event, privacy: .public) tokenFingerprint=\(fingerprint, privacy: .public)")
    }
    func request(_ path: [String], method: String = "GET", query: [URLQueryItem] = [],
                 body: [String: Any]? = nil) throws -> URLRequest {
        var request = URLRequest(url: endpoint(path, query: query))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue(token, forHTTPHeaderField: "X-Emby-Token") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }
    func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw TVClientError.invalidResponse }
        // Route labels only: never log URLs, user IDs, query strings or response bodies.
        let leaf = request.url?.lastPathComponent ?? ""
        let route = ["UserViews", "Views", "Items", "Resume", "AuthenticateByName", "Me"].contains(leaf) ? leaf : "other"
        Self.trace("http route=\(route) status=\(response.statusCode)", token: token)
        guard (200..<300).contains(response.statusCode) else { throw TVClientError.http(response.statusCode) }
        return data
    }
    /// Read only policy flags after catalog authorization fails. Never collect
    /// account names, allowed folder/device IDs, or raw server responses.
    func diagnoseLibraryAuthorization() async {
        struct Policy: Decodable {
            let IsDisabled: Bool?
            let EnableAllDevices: Bool?
            let EnableAllFolders: Bool?
            let EnableMediaPlayback: Bool?
        }
        struct User: Decodable { let Policy: Policy? }
        do {
            let data = try await send(request(["Users", "Me"]))
            let policy = try JSONDecoder().decode(User.self, from: data).Policy
            func flag(_ value: Bool?) -> String { value.map(String.init) ?? "unknown" }
            Self.trace("policy disabled=\(flag(policy?.IsDisabled)) allDevices=\(flag(policy?.EnableAllDevices)) allFolders=\(flag(policy?.EnableAllFolders)) playback=\(flag(policy?.EnableMediaPlayback))", token: token)
        } catch { Self.trace("policy_unavailable_see_http_status", token: token) }
    }
    func login(user: String, password: String) async throws -> TVAccount {
        let data = try await send(request(["Users", "AuthenticateByName"], method: "POST",
            body: ["Username": user, "Pw": password]))
        let response = try JSONDecoder().decode(TVLoginResponse.self, from: data)
        guard !response.AccessToken.isEmpty, !response.User.Id.isEmpty else { throw TVClientError.invalidResponse }
        return TVAccount(server: server, userID: response.User.Id, userName: response.User.Name, token: response.AccessToken)
    }
    func libraries() async throws -> [TVMediaItem] {
        guard let userID else { throw TVClientError.invalidResponse }
        let data: Data
        do {
            data = try await send(request(["UserViews"], query: [.init(name: "UserId", value: userID)]))
        } catch TVClientError.http(let status) where status == 404 || status == 405 {
            data = try await send(request(["Users", userID, "Views"]))
        }
        return try JSONDecoder().decode(TVItemPage.self, from: data).Items
    }
    /// Account-visible movies only; no item list or images are downloaded.
    func movieCount() async throws -> Int? {
        guard let userID else { return nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 6
        let boundedSession = URLSession(configuration: configuration, delegate: TVInventoryTransport(), delegateQueue: nil)
        defer { boundedSession.invalidateAndCancel() }
        let bounded = TVJellyfinClient(server: server, token: token, userID: userID, deviceID: deviceID, session: boundedSession)
        var request = try bounded.request(["Users", userID, "Items"], query: [
            .init(name: "IncludeItemTypes", value: "Movie"), .init(name: "Recursive", value: "true"),
            .init(name: "Limit", value: "0"), .init(name: "EnableTotalRecordCount", value: "true"),
            .init(name: "EnableImages", value: "false"), .init(name: "EnableUserData", value: "false")])
        request.timeoutInterval = 4
        struct Count: Decodable { let TotalRecordCount: Int? }
        let count = try JSONDecoder().decode(Count.self, from: await bounded.send(request)).TotalRecordCount
        return count.flatMap { $0 >= 0 ? $0 : nil }
    }
    func items(parent: String?, search: String = "", start: Int = 0) async throws -> [TVMediaItem] {
        guard let userID else { throw TVClientError.invalidResponse }
        var query = [URLQueryItem(name: "Fields", value: "Overview,UserData"),
                     URLQueryItem(name: "SortBy", value: "SortName"),
                     URLQueryItem(name: "SortOrder", value: "Ascending"),
                     URLQueryItem(name: "StartIndex", value: String(start)),
                     URLQueryItem(name: "Limit", value: "60")]
        if !search.isEmpty {
            query += [.init(name: "SearchTerm", value: search), .init(name: "Recursive", value: "true"),
                      .init(name: "IncludeItemTypes", value: "Movie,Series,Episode,MusicAlbum,MusicArtist,Audio")]
        } else if let parent { query.append(.init(name: "ParentId", value: parent)) }
        let data = try await send(request(["Users", userID, "Items"], query: query))
        return try JSONDecoder().decode(TVItemPage.self, from: data).Items
    }
    func detail(_ id: String) async throws -> TVMediaItem {
        guard let userID else { throw TVClientError.invalidResponse }
        let data = try await send(request(["Users", userID, "Items", id]))
        return try JSONDecoder().decode(TVMediaItem.self, from: data)
    }
    func homeItems(resuming: Bool) async throws -> [TVMediaItem] {
        guard let userID else { throw TVClientError.invalidResponse }
        var query: [URLQueryItem] = [.init(name: "Limit", value: "12"),
            .init(name: "Fields", value: "Overview,UserData"), .init(name: "EnableUserData", value: "true"),
            .init(name: "IncludeItemTypes", value: "Movie,Episode"), .init(name: "EnableTotalRecordCount", value: "false")]
        if !resuming {
            query += [.init(name: "Recursive", value: "true"), .init(name: "SortBy", value: "DateCreated"), .init(name: "SortOrder", value: "Descending")]
        }
        let path = ["Users", userID, "Items"] + (resuming ? ["Resume"] : [])
        return try JSONDecoder().decode(TVItemPage.self, from: await send(request(path, query: query))).Items
    }
    func similar(_ id: String) async throws -> [TVMediaItem] {
        guard let userID else { throw TVClientError.invalidResponse }
        let data = try await send(request(["Items", id, "Similar"], query: [
            .init(name: "UserId", value: userID), .init(name: "Limit", value: "12"), .init(name: "Fields", value: "Overview,UserData")]))
        return try JSONDecoder().decode(TVItemPage.self, from: data).Items
    }
    func imageURL(_ id: String, width: Int = 1000) -> URL {
        endpoint(["Items", id, "Images", "Primary"], query: [
            .init(name: "maxWidth", value: String(width)), .init(name: "quality", value: "92"),
            .init(name: "api_key", value: token)])
    }
    func backdropURL(_ id: String, width: Int = 1920) -> URL {
        endpoint(["Items", id, "Images", "Backdrop", "0"], query: [
            .init(name: "maxWidth", value: String(width)), .init(name: "quality", value: "94"), .init(name: "api_key", value: token)])
    }
    func libraryArtwork(_ id: String) async throws -> TVMediaItem? {
        guard let userID else { return nil }
        let data = try await send(request(["Users", userID, "Items"], query: [
            .init(name: "ParentId", value: id), .init(name: "Recursive", value: "true"),
            .init(name: "IncludeItemTypes", value: "Movie,Series"), .init(name: "Limit", value: "6"),
            .init(name: "SortBy", value: "SortName"), .init(name: "SortOrder", value: "Ascending"),
            .init(name: "EnableImageTypes", value: "Backdrop"), .init(name: "ImageTypeLimit", value: "1"),
            .init(name: "EnableUserData", value: "false")]))
        let items = try JSONDecoder().decode(TVItemPage.self, from: data).Items
        return items.first { $0.BackdropImageTags?.isEmpty == false }
    }

    static var playbackProfile: [String: Any] {
        ["Name": "Nastart TV Native", "MaxStreamingBitrate": 20_000_000,
         "DirectPlayProfiles": [["Type": "Video", "Container": "mp4,m4v,mov",
             "VideoCodec": "h264,hevc", "AudioCodec": "aac,ac3,eac3,alac,mp3"],
             ["Type": "Audio", "Container": "mp3,aac,m4a,flac,wav", "AudioCodec": "mp3,aac,alac,flac,pcm_s16le,pcm_s24le"]],
         "TranscodingProfiles": [["Type": "Video", "Container": "ts", "Protocol": "hls",
             "VideoCodec": "h264", "AudioCodec": "aac", "Context": "Streaming",
             "BreakOnNonKeyFrames": false, "MinSegments": 2],
             ["Type": "Audio", "Container": "ts", "Protocol": "hls", "AudioCodec": "aac", "Context": "Streaming"]],
         "CodecProfiles": [["Type": "Video", "Codec": "h264", "Conditions": [
             ["Condition": "LessThanEqual", "Property": "Width", "Value": "1920", "IsRequired": true],
             ["Condition": "LessThanEqual", "Property": "Height", "Value": "1080", "IsRequired": true]]]],
         "SubtitleProfiles": [["Format": "vtt", "Method": "Hls"],
                              ["Format": "srt", "Method": "Encode"],
                              ["Format": "pgssub", "Method": "Encode"],
                              ["Format": "ass", "Method": "Encode"]]]
    }
    func playbackRequest(_ id: String, selection: TVSourceSelection? = nil) throws -> URLRequest {
        var body: [String: Any] = [
            "UserId": userID ?? "", "StartTimeTicks": 0, "IsPlayback": true,
            "MaxStreamingBitrate": 20_000_000, "EnableDirectPlay": selection == nil,
            "EnableDirectStream": selection == nil, "EnableTranscoding": true,
            "AllowVideoStreamCopy": true, "AllowAudioStreamCopy": true,
            "AutoOpenLiveStream": true, "DeviceProfile": Self.playbackProfile]
        if let selection {
            guard !selection.sourceID.isEmpty, selection.subtitleIndex >= -1, selection.audioIndex.map({ $0 >= 0 }) ?? true else { throw TVClientError.invalidResponse }
            body["MediaSourceId"] = selection.sourceID
            body["AudioStreamIndex"] = selection.audioIndex
            body["SubtitleStreamIndex"] = selection.subtitleIndex
        }
        return try request(["Items", id, "PlaybackInfo"], method: "POST", body: body)
    }

    func mediaURL(_ path: String) throws -> URL {
        guard !path.isEmpty else { throw TVClientError.noPlayableSource }
        let base = URL(string: server.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/")!
        guard let raw = URL(string: path, relativeTo: base)?.absoluteURL,
              raw.scheme == server.scheme, raw.host?.lowercased() == server.host?.lowercased(),
              (raw.port ?? (raw.scheme == "https" ? 443 : 80)) == (server.port ?? (server.scheme == "https" ? 443 : 80)), raw.user == nil, raw.password == nil,
              var parts = URLComponents(url: raw, resolvingAgainstBaseURL: false) else { throw TVClientError.unsafeMediaURL }
        var query = parts.queryItems ?? []
        if !query.contains(where: { $0.name.lowercased() == "api_key" }), let token {
            query.append(.init(name: "api_key", value: token))
        }
        parts.queryItems = query
        guard let url = parts.url else { throw TVClientError.invalidResponse }
        return url
    }
    func route(_ info: TVPlaybackInfo, itemID: String, isAudio: Bool = false, selection: TVSourceSelection? = nil,
               originalStream: Bool = false) throws -> TVPlaybackRoute {
        for source in info.MediaSources {
            if let selection, source.Id != selection.sourceID { continue }
            let tracks = (source.MediaStreams ?? []).filter { $0.Index >= 0 && ["Audio", "Subtitle"].contains($0.kind) }
            guard Set(tracks.map(\.Index)).count == tracks.count else { throw TVClientError.invalidResponse }
            func completed(_ route: TVPlaybackRoute) throws -> TVPlaybackRoute {
                var route = route; route.tracks = tracks
                route.audioIndex = source.DefaultAudioStreamIndex.flatMap { index in tracks.contains { $0.kind == "Audio" && $0.Index == index } ? index : nil }
                route.subtitleIndex = source.DefaultSubtitleStreamIndex.flatMap { index in tracks.contains { $0.kind == "Subtitle" && $0.Index == index } ? index : nil } ?? -1
                if let selection {
                    guard selection.isValid(in: route) else { throw TVClientError.invalidResponse }
                    // An explicit selection must be carried by the negotiated stream.
                    // Static MP4 cannot apply server indices through AV option ordinals.
                    var parts = URLComponents(url: route.url, resolvingAgainstBaseURL: false)!
                    var query = parts.queryItems ?? []
                    // Jellyfin intentionally omits -1 in generated URLs. Make Off
                    // explicit only after rejecting a conflicting returned index.
                    if selection.subtitleIndex == -1, !query.contains(where: { $0.name.lowercased() == "subtitlestreamindex" }) {
                        query.append(.init(name: "SubtitleStreamIndex", value: "-1"))
                        parts.queryItems = query
                        guard let offURL = parts.url else { throw TVClientError.invalidResponse }
                        route = TVPlaybackRoute(url: offURL, sourceID: route.sourceID,
                            playSessionID: route.playSessionID, playMethod: route.playMethod, tracks: tracks,
                            audioIndex: route.audioIndex, subtitleIndex: route.subtitleIndex)
                    }
                    func matches(_ name: String, _ index: Int) -> Bool {
                        let values = query.filter { $0.name.lowercased() == name.lowercased() }
                        return values.count == 1 && values.first?.value == String(index)
                    }
                    guard matches("SubtitleStreamIndex", selection.subtitleIndex),
                          selection.audioIndex.map({ matches("AudioStreamIndex", $0) }) ?? true else { throw TVClientError.invalidResponse }
                    route.audioIndex = selection.audioIndex; route.subtitleIndex = selection.subtitleIndex
                }
                return route
            }
            let nativeContainers = isAudio ? ["mp3", "aac", "m4a", "flac", "wav"] : ["mp4", "mov", "m4v"]
            let originalContainers = ["mkv", "mp4", "mov", "m4v", "m2ts", "ts", "avi", "webm", "mpg", "mpeg",
                "mp3", "aac", "m4a", "flac", "wav", "ogg", "opus"]
            let container = source.Container?.lowercased() ?? ""
            if selection == nil,
               (originalStream ? originalContainers.contains(container)
                    : source.SupportsDirectPlay == true && nativeContainers.contains(container)) {
                let url = endpoint([isAudio ? "Audio" : "Videos", itemID, "stream.\(source.Container!.lowercased())"], query: [
                    .init(name: "Static", value: "true"), .init(name: "MediaSourceId", value: source.Id),
                    .init(name: "PlaySessionId", value: info.PlaySessionId), .init(name: "DeviceId", value: deviceID),
                    .init(name: "api_key", value: token)])
                return try completed(TVPlaybackRoute(url: url, sourceID: source.Id, playSessionID: info.PlaySessionId, playMethod: "DirectPlay"))
            }
            if let path = source.TranscodingUrl, !path.isEmpty {
                return try completed(TVPlaybackRoute(url: try mediaURL(path), sourceID: source.Id,
                    playSessionID: info.PlaySessionId, playMethod: "Transcode"))
            }
            if source.SupportsDirectStream == true, let path = source.DirectStreamUrl,
               nativeContainers.contains(URL(string: path)?.pathExtension.lowercased() ?? "") {
                return try completed(TVPlaybackRoute(url: try mediaURL(path), sourceID: source.Id,
                    playSessionID: info.PlaySessionId, playMethod: "DirectStream"))
            }
        }
        throw TVClientError.noPlayableSource
    }
    func prepare(_ id: String, isAudio: Bool = false, selection: TVSourceSelection? = nil,
                 originalStream: Bool = false) async throws -> TVPlaybackRoute {
        let data = try await send(playbackRequest(id, selection: selection))
        let info = try JSONDecoder().decode(TVPlaybackInfo.self, from: data)
        do { return try route(info, itemID: id, isAudio: isAudio, selection: selection, originalStream: originalStream) }
        catch {
            if let session = info.PlaySessionId { try? await stopEncoding(session) }
            throw error
        }
    }
    func report(_ event: String, itemID: String, route: TVPlaybackRoute,
                seconds: Double, paused: Bool) async throws {
        let ticks = Int64(max(0, seconds.isFinite ? seconds : 0) * 10_000_000)
        var body: [String: Any] = [
            "ItemId": itemID, "MediaSourceId": route.sourceID,
            "PlaySessionId": route.playSessionID ?? "", "PositionTicks": ticks,
            "IsPaused": paused, "CanSeek": true, "PlayMethod": route.playMethod,
            "SubtitleStreamIndex": route.subtitleIndex]
        body["AudioStreamIndex"] = route.audioIndex
        _ = try await send(request(["Sessions"] + event.split(separator: "/").map(String.init), method: "POST", body: body))
    }
    func stopEncoding(_ playSessionID: String) async throws {
        _ = try await send(request(["Videos", "ActiveEncodings"], method: "DELETE", query: [
            .init(name: "deviceId", value: deviceID), .init(name: "playSessionId", value: playSessionID)]))
    }
}

private final class TVInventoryTransport: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct TVQuickConnect: Decodable {
    let Secret: String
    let Code: String
    let Authenticated: Bool
}
extension TVJellyfinClient {
    func initiateQuickConnect() async throws -> TVQuickConnect {
        let data = try await send(request(["QuickConnect", "Initiate"], method: "POST"))
        let result = try JSONDecoder().decode(TVQuickConnect.self, from: data)
        guard !result.Secret.isEmpty, !result.Code.isEmpty else { throw TVClientError.invalidResponse }
        return result
    }
    func completeQuickConnect(_ secret: String) async throws -> TVAccount? {
        let data = try await send(request(["QuickConnect", "Connect"], query: [.init(name: "secret", value: secret)]))
        let result = try JSONDecoder().decode(TVQuickConnect.self, from: data)
        guard result.Authenticated else { return nil }
        let login = try await send(request(["Users", "AuthenticateWithQuickConnect"], method: "POST", body: ["Secret": secret]))
        let response = try JSONDecoder().decode(TVLoginResponse.self, from: login)
        guard !response.AccessToken.isEmpty, !response.User.Id.isEmpty else { throw TVClientError.invalidResponse }
        return TVAccount(server: server, userID: response.User.Id, userName: response.User.Name, token: response.AccessToken)
    }
}
