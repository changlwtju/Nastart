import XCTest
import AVFoundation
import KSPlayer
import NetworkMedia
import UIKit
@testable import NastartTV

final class TVClientTests: XCTestCase {
    @MainActor func testAwaitedSourceChangeDoesNotReplaceAnInvalidatedTimeline() async throws {
        let requested = expectation(description: "candidate requested")
        let discarded = expectation(description: "candidate discarded")
        let originalReleased = expectation(description: "original released on exit")
        var continuation: CheckedContinuation<TVPlaybackSourceAdapter.Resource, Never>?
        let source = TVPlaybackSourceAdapter(title: "Offline fixture", load: {
            .init(url: URL(string: "https://fixture.example.test/original.mkv")!, origin: nil,
                kind: .jellyfin, identity: "original", release: { originalReleased.fulfill() })
        }, tracks: { _, _ in
            await withCheckedContinuation { continuation = $0; requested.fulfill() }
        })
        let session = TVUnifiedPlaybackSession(source: source)
        await session.prepare()
        let original = try XCTUnwrap(session.plan?.id)
        session.controls.av.onSelectSource?(.init(sourceID: "fixture", audioIndex: 1, subtitleIndex: -1))
        await fulfillment(of: [requested], timeout: 2)
        session.controls.ks.stop() // A reset, like a new seek, invalidates the timeline generation.
        continuation?.resume(returning: .init(url: URL(string: "https://fixture.example.test/candidate.mkv")!,
            origin: nil, kind: .jellyfin, identity: "candidate", release: { discarded.fulfill() }))
        await fulfillment(of: [discarded], timeout: 2)
        for _ in 0..<100 where session.switching { await Task.yield() }
        XCTAssertEqual(session.plan?.id, original)
        XCTAssertFalse(session.switching)
        XCTAssertNil(session.error, "a superseded candidate is not a playback failure")
        session.stop()
        await fulfillment(of: [originalReleased], timeout: 2)
    }

    @MainActor func testAllUnifiedSourcesUseOnePlanLifetimeAndReleaseOnceOnExit() async throws {
        for kind in [PlaybackSourceKind.jellyfin, .dsmFile, .webDAVFile] {
            let released = expectation(description: "release \(kind)")
            released.assertForOverFulfill = true
            let source = TVPlaybackSourceAdapter(title: "Offline fixture", load: {
                .init(url: URL(string: "https://fixture.example.test/movie.mkv")!,
                      origin: nil, kind: kind, identity: "fixture", release: { released.fulfill() })
            })
            let session = TVUnifiedPlaybackSession(source: source)
            await session.prepare()
            XCTAssertEqual(session.plan?.intent.sourceKind, kind)
            XCTAssertEqual(session.plan?.enginePolicy, .ksPlayer)
            session.stop(); session.stop()
            await fulfillment(of: [released], timeout: 2)
            XCTAssertNil(session.plan)
            XCTAssertNil(session.error)
        }
    }

    @MainActor func testUnifiedExitDiscardsNonCooperativeLateSourceWithoutMountingIt() async {
        let requested = expectation(description: "source requested")
        let released = expectation(description: "late source released")
        released.assertForOverFulfill = true
        var continuation: CheckedContinuation<TVPlaybackSourceAdapter.Resource, Never>?
        let source = TVPlaybackSourceAdapter(title: "Offline fixture", load: {
            await withCheckedContinuation { continuation = $0; requested.fulfill() }
        })
        let session = TVUnifiedPlaybackSession(source: source)
        let pending = Task { await session.prepare() }
        await fulfillment(of: [requested], timeout: 2)
        session.stop(); pending.cancel()
        continuation?.resume(returning: .init(url: URL(string: "https://fixture.example.test/movie.mkv")!,
            origin: nil, kind: .webDAVFile, identity: "fixture", release: {
                XCTAssertFalse(Task.isCancelled)
                released.fulfill()
            }))
        await pending.value
        await fulfillment(of: [released], timeout: 2)
        XCTAssertNil(session.plan)
        XCTAssertNil(session.error)
    }

    private func client() -> TVJellyfinClient {
        TVJellyfinClient(server: URL(string: "https://media.example.test/jellyfin")!,
            token: "fixture-token", userID: "user", deviceID: "tv-fixture")
    }
    private func info(_ sources: String) throws -> TVPlaybackInfo {
        try JSONDecoder().decode(TVPlaybackInfo.self,
            from: Data("{\"MediaSources\":\(sources),\"PlaySessionId\":\"own-session\"}".utf8))
    }
    func testMediaGridWrapsReadingOrderAndPreservesColumns() {
        XCTAssertEqual(TVMediaGridNavigation.target(from: 3, count: 10, columns: 4, direction: .right), 4)
        XCTAssertEqual(TVMediaGridNavigation.target(from: 4, count: 10, columns: 4, direction: .left), 3)
        for i in 0..<4 {
            XCTAssertEqual(TVMediaGridNavigation.target(from: i, count: 12, columns: 4, direction: .down), i + 4)
            XCTAssertEqual(TVMediaGridNavigation.target(from: i + 4, count: 12, columns: 4, direction: .up), i)
        }
        XCTAssertEqual(TVMediaGridNavigation.target(from: 7, count: 10, columns: 4, direction: .down), 9)
        XCTAssertNil(TVMediaGridNavigation.target(from: 9, count: 10, columns: 4, direction: .down))
        XCTAssertNil(TVMediaGridNavigation.target(from: 0, count: 10, columns: 4, direction: .up))
        XCTAssertNil(TVMediaGridNavigation.target(from: 0, count: 0, columns: 4, direction: .right))
        XCTAssertNil(TVMediaGridNavigation.target(from: -1, count: 10, columns: 4, direction: .right))
        XCTAssertNil(TVMediaGridNavigation.target(from: 0, count: 10, columns: 0, direction: .right))
    }

    func testDetailFactsDecodeSourceStreamsAndOmitAbsentMetadata() throws {
        let json = #"{"Id":"movie","Name":"Movie","MediaSources":[{"MediaStreams":[{"Type":"Video","Height":2160,"Codec":"hevc","VideoRangeType":"HDR10"},{"Type":"Audio","Codec":"eac3","Channels":6}]}]}"#
        let item = try JSONDecoder().decode(TVMediaItem.self, from: Data(json.utf8))
        XCTAssertEqual(item.videoDescription, "4K · H.265 · HDR")
        XCTAssertEqual(item.audioDescription, "E-AC3 · 5.1")
        let missing = try JSONDecoder().decode(TVMediaItem.self, from: Data(#"{"Id":"series","Name":"Series"}"#.utf8))
        XCTAssertNil(missing.videoDescription)
        XCTAssertNil(missing.audioDescription)
        let sparse = try JSONDecoder().decode(TVMediaItem.self, from: Data(#"{"Id":"m","Name":"M","MediaStreams":[{"Type":"Audio","DisplayTitle":"Source audio"}]}"#.utf8))
        XCTAssertEqual(sparse.audioDescription, "Source audio")
        XCTAssertNil(sparse.videoDescription)
    }

    func testOverviewFoldingUsesActualWidthAndSubstantialSavedLines() {
        let medium = String(repeating: "这是影片简介，", count: 20)
        XCTAssertFalse(TVOverviewLayout.shouldCollapse(medium, width: 1500))
        XCTAssertTrue(TVOverviewLayout.shouldCollapse(String(repeating: medium, count: 5), width: 1500))
        XCTAssertTrue(TVOverviewLayout.shouldCollapse(medium, width: 350))
        XCTAssertFalse(TVOverviewLayout.shouldCollapse(medium, width: 0))
    }

    func testServerValidationPreservesReverseProxyMount() throws {
        XCTAssertEqual(try TVJellyfinClient.serverURL(" https://media.example.test/jellyfin/ ").absoluteString,
                       "https://media.example.test/jellyfin")
        XCTAssertEqual(client().endpoint(["Users", "user", "Views"]).path, "/jellyfin/Users/user/Views")
        for invalid in ["media.example.test", "file:///tmp/a", "https://user:secret@media.example.test", "https://media.example.test?token=secret", "https://media.example.test/#a"] {
            XCTAssertThrowsError(try TVJellyfinClient.serverURL(invalid))
        }
    }
    func testLoginAndAPIKeepCredentialsInHeadersOrBody() throws {
        let request = try client().request(["Users", "AuthenticateByName"], method: "POST",
            body: ["Username": "name", "Pw": "private-password"])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Emby-Token"), "fixture-token")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: String])
        XCTAssertEqual(body["Pw"], "private-password")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Authorization")?.contains("Nastart TV") == true)
    }
    func testPlaybackWireRequestLimitsActualEncoderDimensions() throws {
        let request = try client().playbackRequest("movie")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["StartTimeTicks"] as? Int, 0)
        XCTAssertEqual(body["EnableTranscoding"] as? Bool, true)
        XCTAssertEqual(body["MaxStreamingBitrate"] as? Int, 20_000_000)
        let profile = try XCTUnwrap(body["DeviceProfile"] as? [String: Any])
        let codec = try XCTUnwrap((profile["CodecProfiles"] as? [[String: Any]])?.first)
        let conditions = try XCTUnwrap(codec["Conditions"] as? [[String: Any]])
        XCTAssertEqual(conditions.map { $0["Value"] as? String }, ["1920", "1080"])
        XCTAssertTrue(conditions.allSatisfy { $0["IsRequired"] as? Bool == true })
    }
    func testUnifiedOriginalMKVUsesSharedKSPlanAndKeepsServerSession() async throws {
        let data = try info(#"[{"Id":"source","Container":"mkv","SupportsDirectPlay":false,"TranscodingUrl":"Videos/movie/master.m3u8"}]"#)
        let route = try client().route(data, itemID: "movie", originalStream: true)
        XCTAssertEqual(route.playMethod, "DirectPlay")
        XCTAssertEqual(route.playSessionID, "own-session")
        XCTAssertEqual(route.url.path, "/jellyfin/Videos/movie/stream.mkv")
        let intent = PlaybackIntent(sourceKind: .jellyfin, itemIdentity: PlaybackItemIdentity(sourceKind: .jellyfin), displayTitle: "Fixture", directURL: route.url)
        let plan = try await URLPlaybackSourceResolver(sourceKind: .jellyfin).resolve(intent)
        XCTAssertEqual(plan.enginePolicy, .ksPlayer)
    }
    func testUnifiedCompatibilityHLSUsesSharedAVPlanAndPreservesResumeTimeline() async throws {
        let data = try info(#"[{"Id":"source","Container":"mkv","TranscodingUrl":"Videos/movie/master.m3u8"}]"#)
        let route = try client().route(data, itemID: "movie")
        let intent = PlaybackIntent(sourceKind: .jellyfin, itemIdentity: PlaybackItemIdentity(sourceKind: .jellyfin), displayTitle: "Fixture", directURL: route.url, preferredStartTime: 125)
        let plan = try await URLPlaybackSourceResolver(sourceKind: .jellyfin).resolve(intent)
        XCTAssertEqual(plan.enginePolicy, .systemAVPlayer)
        XCTAssertEqual(plan.timeline.startTime, 125)
    }
    func testUnifiedOriginalDoesNotTreatDiscImagesAsDirectContainers() throws {
        let data = try info(#"[{"Id":"source","Container":"iso"}]"#)
        XCTAssertThrowsError(try client().route(data, itemID: "movie", originalStream: true))
    }
    func testUnifiedNetworkCapabilityKeepsActualOriginSeparate() async throws {
        let local = URL(string: "http://127.0.0.1:12345/private-capability/movie.mkv")!
        let origin = URL(string: "https://nas.example.test:5006/video")!
        let intent = PlaybackIntent(sourceKind: .webDAVFile, itemIdentity: PlaybackItemIdentity(sourceKind: .webDAVFile), displayTitle: "Fixture", directURL: local)
        let plan = try await URLPlaybackSourceResolver(sourceKind: .webDAVFile, originURL: origin).resolve(intent)
        XCTAssertEqual(plan.primaryRoute.url, local)
        XCTAssertEqual(plan.primaryRoute.originURL, origin)
        XCTAssertEqual(plan.enginePolicy, .ksPlayer)
    }
    @MainActor func testUnifiedKSRestorationKeepsPausedRateAndMuteIntentBeforeReady() {
        let controls = TVKSPlaybackControls()
        controls.restoreIntent(playing: false, muted: true, rate: 1.5, fillsScreen: true)
        XCTAssertFalse(controls.playing)
        XCTAssertTrue(controls.muted)
        XCTAssertEqual(controls.rate, 1.5)
        XCTAssertTrue(controls.fillsScreen)
        controls.stop()
    }

    func testMKVUsesNegotiatedHLSWithoutProbingOriginalOrGuessingFormat() throws {
        let data = try info("[{\"Id\":\"source\",\"SupportsDirectPlay\":true,\"Container\":\"mkv\",\"TranscodingUrl\":\"Videos/movie/master.m3u8?PlaySessionId=own-session\"}]")
        let route = try client().route(data, itemID: "movie")
        XCTAssertEqual(route.url.path, "/jellyfin/Videos/movie/master.m3u8")
        XCTAssertEqual(route.playMethod, "Transcode")
        XCTAssertEqual(route.playSessionID, "own-session")
        XCTAssertEqual(URLComponents(url: route.url, resolvingAgainstBaseURL: false)?.queryItems?.filter { $0.name == "api_key" }.count, 1)
    }
    func testSupportedMP4RetainsAuthenticatedOriginal() throws {
        let data = try info("[{\"Id\":\"source\",\"SupportsDirectPlay\":true,\"Container\":\"mp4\",\"TranscodingUrl\":\"Videos/movie/master.m3u8\"}]")
        let route = try client().route(data, itemID: "movie")
        XCTAssertEqual(route.playMethod, "DirectPlay")
        XCTAssertEqual(route.url.path, "/jellyfin/Videos/movie/stream.mp4")
        XCTAssertEqual(route.sourceID, "source")
    }
    func testMediaURLRejectsForeignOriginAndDoesNotDuplicateToken() throws {
        for value in ["https://other.example.test/video.m3u8", "http://media.example.test/video.m3u8", "https://media.example.test:444/video.m3u8", "https://user:secret@media.example.test/video.m3u8", "//other.example.test/video.m3u8"] {
            XCTAssertThrowsError(try client().mediaURL(value))
        }
        let url = try client().mediaURL("/jellyfin/Videos/m/master.m3u8?api_key=existing")
        let tokens = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.filter { $0.name == "api_key" }
        XCTAssertEqual(tokens?.count, 1)
        XCTAssertEqual(tokens?.first?.value, "existing")
    }
    func testNoPlayableSourceIsAnExplicitFailure() throws {
        let empty = try info("[]")
        XCTAssertThrowsError(try client().route(empty, itemID: "movie"))
        let mkv = try info("[{\"Id\":\"source\",\"SupportsDirectPlay\":true,\"Container\":\"mkv\"}]")
        XCTAssertThrowsError(try client().route(mkv, itemID: "movie"))
    }
    func testAudioUsesAudioEndpointAndNegotiatedSessionRatherThanVideoEndpoint() throws {
        let data = try info("[{\"Id\":\"song-source\",\"SupportsDirectPlay\":true,\"Container\":\"flac\"}]")
        let route = try client().route(data, itemID: "song", isAudio: true)
        XCTAssertEqual(route.url.path, "/jellyfin/Audio/song/stream.flac")
        XCTAssertEqual(route.playMethod, "DirectPlay")
        let query = URLComponents(url: route.url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(query.first { $0.name == "PlaySessionId" }?.value, "own-session")
        XCTAssertEqual(query.first { $0.name == "DeviceId" }?.value, "tv-fixture")
        let album = try JSONDecoder().decode(TVMediaItem.self, from: Data("{\"Id\":\"album\",\"Name\":\"Album\",\"Type\":\"MusicAlbum\"}".utf8))
        XCTAssertTrue(album.isFolder)
    }
    func testSourceCatalogKeepsSparseOriginalIndicesAndExternalIdentity() throws {
        let data = try info(#"[{"Id":"source","Container":"mkv","TranscodingUrl":"Videos/movie/master.m3u8?AudioStreamIndex=7&SubtitleStreamIndex=31","DefaultAudioStreamIndex":7,"DefaultSubtitleStreamIndex":31,"MediaStreams":[{"Index":0,"Type":"Video"},{"Index":7,"Type":"Audio","DisplayTitle":"原声 DTS"},{"Index":12,"Type":"Audio","Language":"zho","Codec":"aac"},{"Index":31,"Type":"Subtitle","Language":"zho","Codec":"srt","IsExternal":true}]}]"#)
        let route = try client().route(data, itemID: "movie")
        XCTAssertEqual(route.tracks.map(\.Index), [7, 12, 31])
        XCTAssertEqual(route.audioIndex, 7); XCTAssertEqual(route.subtitleIndex, 31)
        XCTAssertEqual(route.tracks.last?.name, "zho · SRT · 外置")
        XCTAssertFalse(TVSourceSelection(sourceID: "source", audioIndex: 1, subtitleIndex: 31).isValid(in: route))
        XCTAssertFalse(TVSourceSelection(sourceID: "other", audioIndex: 7, subtitleIndex: -1).isValid(in: route))
    }
    func testExplicitSourceSelectionPinsWireIndicesAndKeepsAbsoluteTimeline() throws {
        let selection = TVSourceSelection(sourceID: "source", audioIndex: 12, subtitleIndex: 31)
        let request = try client().playbackRequest("movie", selection: selection)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["MediaSourceId"] as? String, "source")
        XCTAssertEqual(body["AudioStreamIndex"] as? Int, 12)
        XCTAssertEqual(body["SubtitleStreamIndex"] as? Int, 31)
        XCTAssertEqual(body["EnableDirectPlay"] as? Bool, false)
        XCTAssertEqual(body["EnableDirectStream"] as? Bool, false)
        XCTAssertEqual(body["StartTimeTicks"] as? Int, 0)
        let data = try info(#"[{"Id":"source","SupportsDirectPlay":true,"Container":"mp4","TranscodingUrl":"Videos/movie/master.m3u8?AudioStreamIndex=12&SubtitleStreamIndex=31","MediaStreams":[{"Index":12,"Type":"Audio"},{"Index":31,"Type":"Subtitle"}]}]"#)
        let route = try client().route(data, itemID: "movie", selection: selection)
        XCTAssertEqual(route.playMethod, "Transcode", "A static MP4 cannot apply source stream indices")
        XCTAssertEqual(route.audioIndex, 12); XCTAssertEqual(route.subtitleIndex, 31)
    }
    func testSubtitleOffAcceptsServerOmissionButRejectsConflictingOrDuplicateIndices() throws {
        let selection = TVSourceSelection(sourceID: "source", audioIndex: 7, subtitleIndex: -1)
        func source(_ query: String) throws -> TVPlaybackInfo {
            try info("[{\"Id\":\"source\",\"TranscodingUrl\":\"Videos/movie/master.m3u8?\(query)\",\"MediaStreams\":[{\"Index\":7,\"Type\":\"Audio\"},{\"Index\":31,\"Type\":\"Subtitle\"}]}]")
        }
        let off = try client().route(source("AudioStreamIndex=7"), itemID: "movie", selection: selection)
        XCTAssertEqual(off.subtitleIndex, -1)
        XCTAssertEqual(URLComponents(url: off.url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "SubtitleStreamIndex" }?.value, "-1")
        for query in ["AudioStreamIndex=7&SubtitleStreamIndex=31", "AudioStreamIndex=12", "AudioStreamIndex=7&AudioStreamIndex=12", "AudioStreamIndex=7&SubtitleStreamIndex=-1&SubtitleStreamIndex=-1"] {
            XCTAssertThrowsError(try client().route(source(query), itemID: "movie", selection: selection))
        }
    }
    func testSelectionRejectsMissingCatalogAndDifferentMediaVersion() throws {
        let selection = TVSourceSelection(sourceID: "source", audioIndex: 7, subtitleIndex: 31)
        for json in [#"[{"Id":"other","TranscodingUrl":"Videos/movie/master.m3u8?AudioStreamIndex=7&SubtitleStreamIndex=31"}]"#,
                     #"[{"Id":"source","TranscodingUrl":"Videos/movie/master.m3u8?AudioStreamIndex=7&SubtitleStreamIndex=31"}]"#,
                     #"[{"Id":"source","Container":"mp4","SupportsDirectPlay":true}]"#] {
            XCTAssertThrowsError(try client().route(info(json), itemID: "movie", selection: selection))
        }
    }
    func testFolderAndResumeDecodeUseAbsoluteTicks() throws {
        let data = Data("{\"Id\":\"series\",\"Name\":\"剧集\",\"Type\":\"Series\",\"UserData\":{\"PlaybackPositionTicks\":1230000000}}".utf8)
        let item = try JSONDecoder().decode(TVMediaItem.self, from: data)
        XCTAssertTrue(item.isFolder)
        XCTAssertEqual(item.resumeSeconds, 123)
    }
}

/// Public discovery deliberately owns a separate transport. Inject its fixture
/// explicitly rather than expecting the authenticated DSM session stub to leak
/// into the production anonymous probe.
private struct TVPublicProbeFixture: PublicMediaServiceTransport {
    let session: URLSession
    func send(_ request: URLRequest) async throws -> PublicMediaServiceResponse {
        let (data, response) = try await session.data(for: request)
        return PublicMediaServiceResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, data: data)
    }
}

private final class TVDSMStub: URLProtocol {
    static var reply: ((URLRequest) throws -> [String: Any])?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let object = try Self.reply!(request)
            let data = try JSONSerialization.data(withJSONObject: object)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class TVSourceProtocolTests: XCTestCase {
    override func tearDown() { TVDSMStub.reply = nil; super.tearDown() }
    func testRejectedCandidateCleansOnlyItsNegotiatedSession() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [TVDSMStub.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        var paths: [String] = []
        TVDSMStub.reply = { request in
            paths.append(request.url!.path)
            if request.url!.path.hasSuffix("PlaybackInfo") {
                return ["PlaySessionId": "candidate-only", "MediaSources": [["Id": "different-version", "TranscodingUrl": "Videos/movie/master.m3u8"]]]
            }
            XCTAssertEqual(request.httpMethod, "DELETE")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            XCTAssertEqual(query.first { $0.name == "playSessionId" }?.value, "candidate-only")
            XCTAssertEqual(query.first { $0.name == "deviceId" }?.value, "tv-fixture")
            return [:]
        }
        let client = TVJellyfinClient(server: URL(string: "https://fixture.test")!, deviceID: "tv-fixture", session: session)
        do {
            _ = try await client.prepare("movie", selection: .init(sourceID: "committed-version", audioIndex: 12, subtitleIndex: -1))
            XCTFail("A different source must not replace current playback")
        } catch TVClientError.noPlayableSource { }
        XCTAssertEqual(paths, ["/Items/movie/PlaybackInfo", "/Videos/ActiveEncodings"])
    }
}

final class TVDSMClientTests: XCTestCase {
    private let server = URL(string: "https://nas.example.test:5001")!
    private var apis: [String: TVDSMAPI] {
        ["SYNO.API.Auth": TVDSMAPI(path: "auth.cgi", minVersion: 1, maxVersion: 7),
         "SYNO.FileStation.List": TVDSMAPI(path: "FileStation/list.cgi", minVersion: 1, maxVersion: 2),
         "SYNO.FileStation.Download": TVDSMAPI(path: "entry.cgi", minVersion: 1, maxVersion: 2)]
    }
    private var account: TVNASAccount { TVNASAccount(server: server, user: "fixture", sid: "fixture-sid", apis: apis) }
    private func stubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [TVDSMStub.self]
        return URLSession(configuration: config)
    }
    private func form(_ request: URLRequest) throws -> [String: String] {
        var data = request.httpBody
        if data == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024), body = Data()
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; body.append(buffer, count: n) }
            data = body
        }
        let body = try XCTUnwrap(String(data: try XCTUnwrap(data), encoding: .utf8))
        let query = try XCTUnwrap(URLComponents(string: "https://form.test/?" + body.replacingOccurrences(of: "+", with: "%20"))?.queryItems)
        return Dictionary(query.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, b in b })
    }
    override func tearDown() { TVDSMStub.reply = nil; super.tearDown() }
    func testResourceSnapshotAggregatesVolumesWithoutCountingRAIDTwice() {
        var snapshot = TVNASStatusSnapshot()
        snapshot.apply(storage: ["volumes": [["size": ["total": "1000", "used": "250"]], ["size": ["total": 3000, "free": 1500]]],
            "disks": [["total": 999999, "used": 99999]]])
        XCTAssertEqual(snapshot.storageTotal, 4000); XCTAssertEqual(snapshot.storageUsed, 1750)
        XCTAssertEqual(snapshot.storage ?? -1, 43.75, accuracy: 0.001)
        var missing = TVNASStatusSnapshot(); missing.apply(storage: ["volumes": [["size": ["total": 100, "used": 101]]]])
        XCTAssertNil(missing.storage); XCTAssertNil(missing.storageTotal)
    }
    func testUptimeUsesNASReportedDurationAndMissingMetricsRemainUnknown() {
        XCTAssertEqual(TVNASStatusSnapshot.uptime(90061), 1501)
        XCTAssertEqual(TVNASStatusSnapshot.uptime("02:01:02:03"), 2942)
        XCTAssertEqual(TVNASStatusSnapshot.uptime("49:02:03"), 2942)
        XCTAssertNil(TVNASStatusSnapshot.uptime("unknown"))
        var value = TVNASStatusSnapshot(); value.apply(system: ["uptime": "01:02:03", "temperature": 42], utilization: [:])
        XCTAssertNil(value.cpu); XCTAssertNil(value.memory); XCTAssertNil(value.storage)
        XCTAssertEqual(value.uptimeMinutes, 62); XCTAssertEqual(value.temperature, 42)
    }
    func testExistingSessionDiscoversStorageAPIAndNeverMovesSIDToURL() async throws {
        let session = stubSession(); defer { session.invalidateAndCancel() }; var calls = 0
        TVDSMStub.reply = { [self] request in
            calls += 1; XCTAssertNil(request.url?.query); XCTAssertEqual(request.url?.host, server.host)
            let body = try form(request)
            if calls == 1 {
                XCTAssertEqual(body["query"], "SYNO.Storage.CGI.Storage"); XCTAssertNil(body["_sid"])
                return ["success": true, "data": ["SYNO.Storage.CGI.Storage": ["path": "storage/info.cgi", "minVersion": 1, "maxVersion": 1]]]
            }
            XCTAssertEqual(request.url?.path, "/webapi/storage/info.cgi")
            XCTAssertEqual(body["_sid"], "fixture-sid"); XCTAssertEqual(body["method"], "load_info")
            return ["success": true, "data": ["volumes": []]]
        }
        _ = try await TVDSMClient(account: account, session: session).readDiscovered("SYNO.Storage.CGI.Storage", method: "load_info")
        XCTAssertEqual(calls, 2)
    }
    func testOlderLocalTaskDecodesWithoutLosingItsCompletionState() throws {
        let original = TVTaskRecord(title: "Existing", due: Date(timeIntervalSince1970: 100))
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(TVTaskRecord.self, from: data)
        XCTAssertEqual(restored.id, original.id); XCTAssertEqual(restored.title, "Existing")
        XCTAssertNil(restored.kind); XCTAssertNil(restored.target); XCTAssertNil(restored.createdAt)
    }
    func testLoginDiscoversAuthPathAndKeepsPasswordAndOTPOutOfURL() async throws {
        let direct = try TVDSMClient(server: server).request(path: "auth.cgi", values: [.init(name: "passwd", value: "p+a&ss=中")])
        XCTAssertTrue(String(data: try XCTUnwrap(direct.httpBody), encoding: .utf8)!.contains("%2B"))
        let session = stubSession(); defer { session.invalidateAndCancel() }
        var calls = 0
        TVDSMStub.reply = { [self] request in
            calls += 1
            XCTAssertEqual(request.httpMethod, "POST"); XCTAssertNil(request.url?.query)
            XCTAssertEqual(request.url?.host, server.host); XCTAssertEqual(request.url?.port, 5001)
            let values = try form(request)
            if calls == 1 {
                XCTAssertEqual(values["api"], "SYNO.API.Info")
                return ["success": true, "data": ["SYNO.API.Auth": ["path": "auth/session.cgi", "minVersion": 1, "maxVersion": 7]]]
            }
            XCTAssertEqual(request.url?.path, "/webapi/auth/session.cgi")
            XCTAssertEqual(values["passwd"], "p+a&ss=中"); XCTAssertEqual(values["otp_code"], "123456")
            XCTAssertEqual(values["account"], "fixture"); XCTAssertEqual(values["version"], "7")
            return ["success": true, "data": ["sid": "own-sid"]]
        }
        let account = try await TVDSMClient(server: server, session: session).login(user: "fixture", password: "p+a&ss=中", otp: " 123456 ")
        XCTAssertEqual(account.server, server); XCTAssertEqual(account.sid, "own-sid"); XCTAssertEqual(calls, 2)
    }
    func testListingUsesDiscoveredPathPaginationAndDecodedSharePaths() async throws {
        let session = stubSession(); defer { session.invalidateAndCancel() }
        TVDSMStub.reply = { [self] request in
            XCTAssertEqual(request.url?.path, "/webapi/FileStation/list.cgi"); XCTAssertNil(request.url?.query)
            let values = try form(request)
            XCTAssertEqual(values["method"], "list"); XCTAssertEqual(values["folder_path"], "/video/中 文")
            XCTAssertEqual(values["offset"], "100"); XCTAssertEqual(values["limit"], "100"); XCTAssertEqual(values["_sid"], "fixture-sid")
            return ["success": true, "data": ["total": 101, "files": [["name": "电影.mkv", "path": "/video/中 文/电影.mkv", "isdir": false, "additional": ["size": 12345]]]]]
        }
        let page = try await TVDSMClient(account: account, session: session).files(path: "/video/中 文", offset: 100)
        XCTAssertEqual(page.total, 101); XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.path, "/video/中 文/电影.mkv"); XCTAssertEqual(page.items.first?.isMedia, true)
    }
    func testSessionExpiryIsExplicitWithoutAutomaticCredentialRetry() async throws {
        let session = stubSession(); defer { session.invalidateAndCancel() }; var calls = 0
        TVDSMStub.reply = { _ in calls += 1; return ["success": false, "error": ["code": 119]] }
        do { _ = try await TVDSMClient(account: account, session: session).files(path: "/"); XCTFail("Expected expired session") }
        catch TVDSMError.api(let code) { XCTAssertEqual(code, 119) }
        XCTAssertEqual(calls, 1)
    }
    func testDirectorySortIsSentToNASOnEveryPageAndKeepsCredentialsInBody() async throws {
        let session = stubSession(); defer { session.invalidateAndCancel() }
        var calls = 0
        TVDSMStub.reply = { [self] request in
            let values = try form(request)
            XCTAssertNil(request.url?.query)
            XCTAssertEqual(values["_sid"], "fixture-sid")
            XCTAssertEqual(values["method"], "list")
            XCTAssertEqual(values["folder_path"], "/video/中 文")
            XCTAssertEqual(values["sort_by"], "mtime")
            XCTAssertEqual(values["sort_direction"], "desc")
            XCTAssertEqual(values["offset"], calls == 0 ? "0" : "100")
            XCTAssertEqual(values["limit"], "100")
            XCTAssertEqual(values["additional"], "[\"size\",\"type\",\"time\"]")
            calls += 1
            return ["success": true, "data": ["files": [], "total": 0]]
        }
        let client = TVDSMClient(account: account, session: session)
        _ = try await client.files(path: "/video/中 文", sort: .modified, ascending: false)
        _ = try await client.files(path: "/video/中 文", offset: 100, sort: .modified, ascending: false)
        XCTAssertEqual(calls, 2)
    }
    func testSharedDirectoryNeverSendsUnsupportedSizeOrTypeSort() async throws {
        let session = stubSession(); defer { session.invalidateAndCancel() }
        TVDSMStub.reply = { [self] request in
            let values = try form(request)
            XCTAssertEqual(values["method"], "list_share")
            XCTAssertEqual(values["sort_by"], "name")
            XCTAssertNil(values["folder_path"])
            XCTAssertEqual(values["offset"], "0")
            XCTAssertEqual(values["additional"], "[\"time\"]")
            return ["success": true, "data": ["shares": [], "total": 0]]
        }
        let client = TVDSMClient(account: account, session: session)
        _ = try await client.files(path: "/", offset: -1, sort: .size)
        _ = try await client.files(path: "/", sort: .kind)
    }
    func testFileInformationUsesRealMetadataAndDoesNotReportFolderInodeSizeAsContents() throws {
        func file(_ additional: String, directory: Bool = false) throws -> TVNASFile {
            try JSONDecoder().decode(TVNASFile.self, from: Data("{\"name\":\"样本.txt\",\"path\":\"/video/样本.txt\",\"isdir\":\(directory),\"additional\":\(additional)}".utf8))
        }
        let normal = try file("{\"size\":2048,\"time\":{\"mtime\":1700000000}}")
        XCTAssertEqual(normal.modifiedAt?.timeIntervalSince1970, 1700000000)
        XCTAssertEqual(normal.kindDescription, "TXT 文件")
        XCTAssertFalse(normal.isMedia)
        XCTAssertEqual(try file("{\"size\":4096}", directory: true).formattedSize, "未提供")
        XCTAssertEqual(try file("{\"size\":-1,\"time\":{\"mtime\":0}}").formattedSize, "未提供")
        XCTAssertNil(try file("{\"time\":{\"mtime\":0}}").modifiedAt)
        XCTAssertNil(try file("{}").modifiedAt)
    }
    func testServiceFilterIncludesImageAndKindWithoutChangingDiscoveredRows() {
        let service = TVDiscoveredService(id: "1", name: "电影", detail: "jellyfin/jellyfin:latest", kind: "容器", running: true, ports: [])
        XCTAssertTrue(service.matches(" JELLYFIN "))
        XCTAssertTrue(service.matches("容器"))
        XCTAssertTrue(service.matches("电影"))
        XCTAssertTrue(service.matches("  "))
        XCTAssertFalse(service.matches("absent"))
        XCTAssertEqual(service.name, "电影")
    }
    func testUntrustedAPIPathsCannotMoveCredentialsOffConfiguredOrigin() throws {
        for path in ["https://foreign.test/login", "//foreign.test/login", "../login", "auth/../login", "auth%2f..%2flogin", "auth.cgi?target=x", "auth\\login", "/webapi/auth.cgi"] {
            XCTAssertThrowsError(try TVDSMClient.apiURL(server: server, path: path))
        }
        XCTAssertEqual(try TVDSMClient.apiURL(server: server, path: "FileStation/list.cgi").absoluteString,
                       "https://nas.example.test:5001/webapi/FileStation/list.cgi")
    }
    func testFilePlaybackKeepsConfiguredDomainPortAndJSONEncodedPath() throws {
        let url = try TVDSMClient(account: account).mediaURL(path: "/video/中 & ?.mp4")
        XCTAssertEqual(url.host, server.host); XCTAssertEqual(url.port, 5001)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
        let path = try JSONDecoder().decode([String].self, from: Data(values["path"]!.utf8))
        XCTAssertEqual(path, ["/video/中 & ?.mp4"]); XCTAssertEqual(values["mode"], "\"open\"")
        XCTAssertEqual(values["_sid"], "fixture-sid")
    }
    func testContainerPortsAndReverseProxyMatchActualPublishedPort() throws {
        let rows: [[String: Any]] = [["name": "Jellyfin", "image": "jellyfin/jellyfin", "state": "running",
            "PortBindings": ["8096/tcp": [["HostPort": "18096"]]]],
            ["name": "stopped", "state": "exited", "ports": [["container_port": 8096, "local_port": 28096]]]]
        let services = TVDSMClient.containerServices(rows)
        XCTAssertEqual(services[0].ports, [18096]); XCTAssertTrue(services[0].isJellyfin)
        XCTAssertEqual(services[1].running, false)
        let proxies: [[String: Any]] = [
            ["source": ["protocol": "https", "hostname": "media.example.test", "port": 443], "destination": ["port": 18096]],
            ["source": ["protocol": "https", "hostname": "wrong.example.test", "port": 443], "destination": ["port": 8096]]]
        XCTAssertEqual(TVDSMClient.reverseProxyEndpoints(proxies, ports: services[0].ports, fallbackHost: server.host),
                       [URL(string: "https://media.example.test:443")!])
        XCTAssertEqual(TVDSMClient.publishedPorts(["ports": [["container_port": 8096]]]), [])
    }
    func testDiscoveryRefreshesCatalogForExistingLoginAndPublicProbeNeverReceivesSID() async throws {
        let session = stubSession(); defer { session.invalidateAndCancel() }
        var authenticated = 0, publicProbes = 0
        TVDSMStub.reply = { [self] request in
            if request.url?.path == "/System/Info/Public" {
                publicProbes += 1; XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertNil(request.httpBody); XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                XCTAssertNil(request.value(forHTTPHeaderField: "X-Emby-Token")); XCTAssertNil(request.url?.query)
                return ["Id": "public-id", "ProductName": "Jellyfin Server", "Version": "10.10.0"]
            }
            let values = try form(request)
            if values["api"] == "SYNO.API.Info" {
                XCTAssertNil(values["_sid"])
                return ["success": true, "data": ["SYNO.Docker.Container": ["path": "entry.cgi", "minVersion": 1, "maxVersion": 1]]]
            }
            authenticated += 1; XCTAssertEqual(values["_sid"], "fixture-sid")
            XCTAssertEqual(values["api"], "SYNO.Docker.Container"); XCTAssertEqual(values["method"], "list")
            return ["success": true, "data": ["containers": [["name": "Jellyfin", "status": "running", "ports": [["local_port": 8096]]]]]]
        }
        let found = try await TVDSMClient(account: account, session: session)
            .discoverServices(publicTransport: TVPublicProbeFixture(session: session))
        XCTAssertEqual(authenticated, 1); XCTAssertEqual(publicProbes, 1)
        XCTAssertEqual(found.services.count, 1)
        XCTAssertEqual(found.services[0].verifiedJellyfin, URL(string: "https://nas.example.test:8096"))
        XCTAssertEqual(found.warnings.count, 1) // Missing package API must not silently mean no packages.
    }
    func testDeniedDiscoveryRemainsAnExplicitWarningAndDoesNotInvalidateLogin() async throws {
        let session = stubSession(); defer { session.invalidateAndCancel() }
        TVDSMStub.reply = { [self] request in
            let values = try form(request)
            if values["api"] == "SYNO.API.Info" {
                return ["success": true, "data": ["SYNO.Docker.Container": ["path": "entry.cgi", "minVersion": 1, "maxVersion": 1]]]
            }
            return ["success": false, "error": ["code": 105]]
        }
        let result = try await TVDSMClient(account: account, session: session).discoverServices()
        XCTAssertTrue(result.services.isEmpty); XCTAssertTrue(result.warnings.contains { $0.contains("105") })
        XCTAssertEqual(account.sid, "fixture-sid")
    }
    func testNASAndJellyfinAccountsRemainSeparateAndServerValidationRejectsCredentials() throws {
        let restored = try JSONDecoder().decode(TVNASAccount.self, from: JSONEncoder().encode(account))
        XCTAssertEqual(restored, account)
        for invalid in ["nas.example.test", "https://u:p@nas.example.test:5001", "https://nas.example.test/webman", "https://nas.example.test?sid=x"] {
            XCTAssertThrowsError(try TVDSMClient.serverURL(invalid))
        }
        XCTAssertEqual(try TVDSMClient.serverURL(" https://nas.example.test:5001/ ").host, server.host)
    }
}

final class TVQuickConnectTests: XCTestCase {
    override func tearDown() { TVDSMStub.reply = nil; super.tearDown() }
    func testQuickConnectWaitsForApprovalThenExchangesSecretForSeparateTVAccount() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [TVDSMStub.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        let base = URL(string: "https://media.example.test/jellyfin")!
        let client = TVJellyfinClient(server: base, deviceID: "tv-fixture", session: session)
        var approved = false, exchanges = 0
        TVDSMStub.reply = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "X-Emby-Token"))
            switch request.url!.path {
            case "/jellyfin/QuickConnect/Initiate":
                XCTAssertEqual(request.httpMethod, "POST"); XCTAssertNil(request.url?.query)
                return ["Secret": "own-secret", "Code": "123456", "Authenticated": false]
            case "/jellyfin/QuickConnect/Connect":
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "own-secret")
                return ["Secret": "own-secret", "Code": "123456", "Authenticated": approved]
            case "/jellyfin/Users/AuthenticateWithQuickConnect":
                exchanges += 1; XCTAssertTrue(approved)
                XCTAssertEqual(request.httpMethod, "POST"); XCTAssertNil(request.url?.query)
                return ["AccessToken": "tv-token", "User": ["Id": "tv-user", "Name": "Fixture"]]
            default: throw TVClientError.invalidResponse
            }
        }
        let code = try await client.initiateQuickConnect(); XCTAssertEqual(code.Code, "123456")
        let pending = try await client.completeQuickConnect(code.Secret); XCTAssertNil(pending); XCTAssertEqual(exchanges, 0)
        approved = true
        let account = try await client.completeQuickConnect(code.Secret)
        XCTAssertEqual(account?.server, base); XCTAssertEqual(account?.token, "tv-token"); XCTAssertEqual(exchanges, 1)
    }
    func testQuickConnectDisabledDoesNotFallBackToPasswordOrReuseAnotherToken() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [TVDSMStub.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }; var calls = 0
        TVDSMStub.reply = { _ in calls += 1; throw TVClientError.http(401) }
        let client = TVJellyfinClient(server: URL(string: "https://media.example.test")!, deviceID: "tv-fixture", session: session)
        do { _ = try await client.initiateQuickConnect(); XCTFail("Expected disabled server failure") }
        catch { XCTAssertEqual(calls, 1) }
    }
}

final class TVMediaHomeTests: XCTestCase {
    override func tearDown() { TVDSMStub.reply = nil; super.tearDown() }
    func testHomeRowsUseUserProgressAndRecentOrderWithoutPlaybackOrQueryCredentials() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [TVDSMStub.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        let client = TVJellyfinClient(server: URL(string: "https://media.example.test/jellyfin")!, token: "private-token", userID: "viewer", deviceID: "tv", session: session)
        var paths: [String] = []
        TVDSMStub.reply = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Emby-Token"), "private-token")
            let url = try XCTUnwrap(request.url); paths.append(url.path)
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
            XCTAssertEqual(query.first { $0.name == "Limit" }?.value, "12")
            XCTAssertFalse(query.contains { $0.name == "api_key" || $0.value == "private-token" })
            if url.path.hasSuffix("/Resume") {
                return ["Items": [["Id": "movie", "Name": "Fixture", "Type": "Movie", "RunTimeTicks": 6_000_000_000, "UserData": ["PlaybackPositionTicks": 1_200_000_000]]]]
            }
            XCTAssertEqual(query.first { $0.name == "SortBy" }?.value, "DateCreated")
            XCTAssertEqual(query.first { $0.name == "SortOrder" }?.value, "Descending")
            XCTAssertEqual(query.first { $0.name == "Recursive" }?.value, "true")
            return ["Items": []]
        }
        let resume = try await client.homeItems(resuming: true)
        XCTAssertEqual(resume.first?.resumeSeconds, 120)
        let recent = try await client.homeItems(resuming: false); XCTAssertTrue(recent.isEmpty)
        XCTAssertEqual(paths, ["/jellyfin/Users/viewer/Items/Resume", "/jellyfin/Users/viewer/Items"])
    }
    func testPhoneManagementURLsExcludeCredentialsAndNonWebRoutes() throws {
        let service = TVDiscoveredService(id: "container:fixture", name: "Fixture", detail: "image:1", kind: "容器", running: true, ports: [8080], endpoints: [
            URL(string: "https://nas.example.test/service")!, URL(string: "https://u:p@nas.example.test/")!,
            URL(string: "file:///tmp/private")!, URL(string: "https://nas.example.test/?_sid=secret")!,
            URL(string: "https://nas.example.test/?api_key=secret")!])
        XCTAssertEqual(service.managementEndpoints.map(\.absoluteString), ["https://nas.example.test/service"])
    }
    func testEpisodeUsesSeriesPosterWithoutChangingPlaybackItemAndMissingPosterFallsBack() throws {
        let episode = try JSONDecoder().decode(TVMediaItem.self, from: Data(#"{"Id":"episode-9","Name":"Episode title","Type":"Episode","SeriesId":"series","SeriesName":"Show","SeriesPrimaryImageTag":"poster-tag","IndexNumber":9}"#.utf8))
        XCTAssertEqual(episode.Id, "episode-9")
        XCTAssertEqual(episode.posterID, "series")
        XCTAssertEqual(episode.posterTitle, "Show")
        XCTAssertEqual(episode.posterSubtitle, "第9集 · Episode title")
        let missing = try JSONDecoder().decode(TVMediaItem.self, from: Data(#"{"Id":"episode-no-poster","Name":"Episode title","Type":"Episode","SeriesId":"series"}"#.utf8))
        XCTAssertEqual(missing.posterID, missing.Id)
        let client = TVJellyfinClient(server: URL(string: "https://media.example.test/jellyfin")!, token: "image-token", userID: "viewer", deviceID: "tv")
        let url = client.imageURL(episode.posterID)
        XCTAssertEqual(url.path, "/jellyfin/Items/series/Images/Primary")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(query.first { $0.name == "maxWidth" }?.value, "1000")
        XCTAssertEqual(query.first { $0.name == "quality" }?.value, "92")
    }
    func testDetailDecodesCreditsWithMissingPersonIDAndSimilarItemsUseCurrentUser() async throws {
        let data = Data(#"{"Id":"movie","Name":"Fixture","Genres":["Action"],"CommunityRating":8.1,"People":[{"Name":"No ID","Role":"Lead","Type":"Actor"},{"Id":"director","Name":"Director","Type":"Director"}],"Studios":[{"Name":"Studio"}]}"#.utf8)
        let item = try JSONDecoder().decode(TVMediaItem.self, from: data)
        XCTAssertEqual(item.People?.count, 2); XCTAssertNil(item.People?.first?.Id)
        XCTAssertEqual(item.People?.first?.id, "No IDLead"); XCTAssertEqual(item.CommunityRating, 8.1)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [TVDSMStub.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        TVDSMStub.reply = { request in
            XCTAssertEqual(request.url?.path, "/jellyfin/Items/movie/Similar")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            XCTAssertEqual(query.first { $0.name == "UserId" }?.value, "viewer")
            XCTAssertEqual(query.first { $0.name == "Limit" }?.value, "12")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Emby-Token"), "private-token")
            return ["Items": [["Id": "other", "Name": "Another movie", "ProductionYear": 2000]]]
        }
        let client = TVJellyfinClient(server: URL(string: "https://media.example.test/jellyfin")!, token: "private-token", userID: "viewer", deviceID: "tv", session: session)
        let similar = try await client.similar("movie"); XCTAssertEqual(similar.first?.Id, "other")
    }
}

final class TVSubtitleGeometryTests: XCTestCase {
    func testLetterboxUsesVideoBoundsRatherThanTheScreenBottom() throws {
        let screen = CGSize(width: 1920, height: 1080)
        let rect = try XCTUnwrap(SubtitleViewportGeometry.videoRect(viewport: screen,
            video: CGSize(width: 3840, height: 1632)))
        XCTAssertEqual(rect, CGRect(x: 0, y: 132, width: 1920, height: 816))
        XCTAssertEqual(SubtitleViewportGeometry.bottomInset(viewport: screen,
            videoRect: rect, screenBottomInset: 60), 12)
    }
    func testAuthoredBitmapGeometryPreservesCanvasAndFillCrop() throws {
        let viewport = CGSize(width: 960, height: 540)
        let frame = try XCTUnwrap(SubtitleViewportGeometry.videoFrame(viewport: viewport,
            video: CGSize(width: 3840, height: 2160)))
        XCTAssertEqual(SubtitleViewportGeometry.imageRect(origin: CGPoint(x: 96, y: 54),
            image: CGSize(width: 120, height: 60), canvas: CGSize(width: 1920, height: 1080),
            videoFrame: frame), CGRect(x: 48, y: 27, width: 60, height: 30))
        let fill = try XCTUnwrap(SubtitleViewportGeometry.videoFrame(viewport: CGSize(width: 1920, height: 1080),
            video: CGSize(width: 1440, height: 1080), fillsScreen: true))
        XCTAssertEqual(fill, CGRect(x: 0, y: -180, width: 1920, height: 1440))
        let top = try XCTUnwrap(SubtitleViewportGeometry.imageRect(origin: .zero,
            image: CGSize(width: 120, height: 60), canvas: CGSize(width: 1440, height: 1080), videoFrame: fill))
        XCTAssertEqual(top, CGRect(x: 0, y: -180, width: 160, height: 80),
            "An offscreen authored cue is cropped, not squeezed into the visible rectangle")
        XCTAssertNil(SubtitleViewportGeometry.imageRect(origin: CGPoint(x: CGFloat.nan, y: 0),
            image: CGSize(width: 120, height: 60), canvas: CGSize(width: 1920, height: 1080), videoFrame: frame))
    }

    func testFillUsesVisibleIntersectionAndUnknownDimensionsStayAbsent() {
        let screen = CGSize(width: 1920, height: 1080)
        XCTAssertEqual(SubtitleViewportGeometry.videoRect(viewport: screen,
            video: CGSize(width: 1440, height: 1080), fillsScreen: true),
            CGRect(origin: .zero, size: screen))
        XCTAssertNil(SubtitleViewportGeometry.videoRect(viewport: screen, video: .zero))
        XCTAssertNil(SubtitleViewportGeometry.videoRect(viewport: screen,
            video: CGSize(width: CGFloat.infinity, height: 1080)))
    }
}

@MainActor
final class TVTransportControlTests: XCTestCase {
    private func seekFixture(playing: Bool) -> (TVKSPlaybackControls, KSPlayerLayer, DeferredSeekNativePlayer) {
        let controls = TVKSPlaybackControls()
        let options = KSOptions(); options.registerRemoteControll = false
        let layer = KSPlayerLayer(url: URL(fileURLWithPath: "/unused-command-fixture.mkv"),
                                  isAutoPlay: false, options: options)
        let native = DeferredSeekNativePlayer(url: layer.url, options: options)
        layer.player = native; controls.coordinator.playerLayer = layer
        controls.restoreIntent(playing: playing, muted: false, rate: 1, fillsScreen: false)
        if playing { layer.play() } else { layer.pause() }
        controls.start()
        return (controls, layer, native)
    }

    func testPendingKSSeekRestoresLatestPlayAndRate() async {
        let (controls, layer, native) = seekFixture(playing: false)
        defer { controls.stop() }
        controls.seek(delta: 15)
        controls.toggle(); controls.setRate(1.5)
        native.completeNext(true)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(native.isPlaying)
        XCTAssertTrue(layer.wantsPlayback)
        XCTAssertEqual(native.playbackRate, 1.5)
    }

    func testKSSeekCompletionUsesNativeRemoteIntentInsteadOfStaleChrome() async {
        for initiallyPlaying in [false, true] {
            let (controls, layer, native) = seekFixture(playing: initiallyPlaying)
            controls.seek(delta: 15)
            if initiallyPlaying { layer.pause() } else { layer.play() }
            XCTAssertEqual(controls.playing, initiallyPlaying, "fixture must leave chrome stale")
            native.completeNext(true)
            for _ in 0..<20 { await Task.yield() }
            XCTAssertEqual(native.isPlaying, !initiallyPlaying)
            XCTAssertEqual(layer.wantsPlayback, !initiallyPlaying)
            XCTAssertEqual(controls.playing, !initiallyPlaying)
            controls.stop()
        }
    }

    func testOldAndPostStopKSCallbacksNeverResumePlayback() async {
        let (controls, layer, native) = seekFixture(playing: true)
        defer { controls.stop() }
        controls.seek(delta: 15); controls.seek(delta: 15)
        controls.toggle()
        let plays = native.playCalls
        native.completeNext(true)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertFalse(native.isPlaying)
        XCTAssertFalse(layer.wantsPlayback)
        XCTAssertEqual(native.playCalls, plays)
        controls.stop()
        native.completeNext(true)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(native.playCalls, plays)
    }

    func testUnreadyKSSeekDoesNotOverwriteDesiredPlay() async {
        let (controls, layer, native) = seekFixture(playing: true)
        defer { controls.stop() }
        native.isReadyToPlay = false
        controls.seek(delta: 15)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(native.pendingCount, 0)
        XCTAssertTrue(layer.wantsPlayback)
        XCTAssertTrue(controls.playing)
    }

    func testFailedKSSeekDoesNotIntroduceAutoplay() async {
        let (controls, layer, native) = seekFixture(playing: false)
        defer { controls.stop() }
        controls.seek(delta: 15)
        native.completeNext(false)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(native.playCalls, 0)
        XCTAssertFalse(native.isPlaying)
        XCTAssertFalse(layer.wantsPlayback)
    }

    func testPendingKSSeekMustNotResumeAfterTheUserPauses() async throws {
        let controls = TVKSPlaybackControls()
        let options = KSOptions(); options.registerRemoteControll = false
        let layer = KSPlayerLayer(url: URL(fileURLWithPath: "/unused-command-fixture.mkv"),
                                  isAutoPlay: false, options: options)
        let native = DeferredSeekNativePlayer(url: layer.url, options: options)
        layer.player = native
        controls.coordinator.playerLayer = layer
        defer { controls.stop() }
        layer.play(); controls.start()
        controls.seek(delta: 15)
        XCTAssertEqual(native.pendingCount, 1)
        controls.toggle()
        XCTAssertFalse(controls.playing)
        XCTAssertFalse(layer.wantsPlayback)
        native.completeNext(true)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertFalse(native.isPlaying, "the completion must apply the latest pause, not captured autoPlay")
        XCTAssertFalse(layer.wantsPlayback)
    }

    func testSeekBoundsAndUnknownTimelineDoNotEmitInvalidTargets() {
        XCTAssertEqual(TVPlayerControlsModel.seekTarget(current: 3, delta: -15, duration: 100), 0)
        XCTAssertEqual(TVPlayerControlsModel.seekTarget(current: 95, delta: 15, duration: 100), 99.9)
        XCTAssertNil(TVPlayerControlsModel.seekTarget(current: .nan, delta: 15, duration: 100))
        XCTAssertNil(TVPlayerControlsModel.seekTarget(current: 10, delta: 15, duration: .infinity))
        XCTAssertNil(TVPlayerControlsModel.seekTarget(current: 0, delta: 15, duration: 0))
    }
    func testTransportIntentSurvivesWaitingAndPausedCandidateReplacement() {
        let first = AVPlayer(), next = AVPlayer()
        let controls = TVPlayerControlsModel(); controls.attach(first)
        controls.startPlayback(); controls.setRate(1.5); controls.toggleMute()
        XCTAssertTrue(controls.wantsPlayback, "A zero decoder rate while waiting does not mean user pause")
        controls.toggle()
        XCTAssertFalse(controls.wantsPlayback)
        let snapshot = controls.runtimeSnapshot
        controls.attach(next, restoring: snapshot)
        XCTAssertFalse(controls.wantsPlayback); XCTAssertEqual(next.rate, 0)
        XCTAssertEqual(next.defaultRate, 1.5); XCTAssertTrue(next.isMuted)
        controls.detach()
    }
    func testSourceMenusDoNotOverwritePendingOtherTrackOrUseOutputOrdinals() throws {
        let player = AVPlayer(), controls = TVPlayerControlsModel(); controls.attach(player)
        let data = Data(#"{"MediaSources":[{"Id":"source","Container":"mkv","TranscodingUrl":"Videos/movie/master.m3u8","DefaultAudioStreamIndex":7,"MediaStreams":[{"Type":"Audio","Index":7},{"Type":"Audio","Index":12},{"Type":"Subtitle","Index":31}]}]}"#.utf8)
        controls.sourceRoute = try TVJellyfinClient(server: URL(string: "https://fixture.test")!, deviceID: "tv").route(JSONDecoder().decode(TVPlaybackInfo.self, from: data), itemID: "movie")
        var choices: [TVSourceSelection] = []
        controls.onSelectSource = { choices.append($0); controls.pendingSourceSelection = $0 }
        controls.selectAudio(12); controls.selectSubtitle(31)
        XCTAssertEqual(choices.last, TVSourceSelection(sourceID: "source", audioIndex: 12, subtitleIndex: 31))
        XCTAssertEqual(controls.audio.map(\.id), [7, 12]); XCTAssertEqual(controls.selectedAudio, 7, "Do not show a candidate as committed")
        controls.selectAudio(1); XCTAssertEqual(choices.count, 2)
        controls.onSelectSource = nil; controls.detach()
    }
    func testRateChoiceKeepsPausedPlayerPausedAndUsesSharedMobileOptions() {
        let player = AVPlayer()
        let controls = TVPlayerControlsModel()
        controls.attach(player)
        controls.setRate(0.5)
        XCTAssertEqual(player.defaultRate, 0.5)
        XCTAssertEqual(player.rate, 0)
        XCTAssertEqual(controls.rate, 0.5)
        controls.setRate(3)
        XCTAssertEqual(player.defaultRate, 0.5)
        controls.toggleMute()
        XCTAssertTrue(player.isMuted)
        controls.detach()
        controls.toggleMute()
        XCTAssertTrue(player.isMuted, "Detached controls must not mutate the previous player")
    }
}

/// No decoder, network or media surface. Completions are delivered only when
/// the test requests them, including after pause/reset, to control the race.
private final class DeferredSeekNativePlayer: MediaPlayerProtocol {
    weak var delegate: MediaPlayerDelegate?
    var view: UIView? { nil }
    var duration: TimeInterval { 600 }
    var fileSize: Double { 1 }
    var naturalSize: CGSize { .zero }
    var chapters: [Chapter] { [] }
    var currentPlaybackTime: TimeInterval = 100
    var playableTime: TimeInterval { 150 }
    var isReadyToPlay = true
    var seekable = true
    var playbackState: MediaPlaybackState = .paused
    var loadState: MediaLoadState = .playable
    var isPlaying: Bool { playbackState == .playing }
    var isMuted = false
    var allowsExternalPlayback = false
    var usesExternalPlaybackWhileExternalScreenIsActive = false
    var isExternalPlaybackActive: Bool { false }
    var playbackRate: Float = 1
    var playbackVolume: Float = 1
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var subtitleDataSouce: SubtitleDataSouce? { nil }
    private let clockPlayer = AVPlayer()
    var playbackCoordinator: AVPlaybackCoordinator { clockPlayer.playbackCoordinator }
    var pipController: KSPictureInPictureController? { nil }
    var dynamicInfo: DynamicInfo? { nil }
    private(set) var playCalls = 0
    private var pending: [(TimeInterval, (Bool) -> Void)] = []
    var pendingCount: Int { pending.count }
    init(url: URL, options: KSOptions) {}
    func prepareToPlay() {}
    func replace(url: URL, options: KSOptions) {}
    func play() { playCalls += 1; playbackState = .playing }
    func pause() { playbackState = .paused }
    func shutdown() { playbackState = .stopped }
    func seek(time: TimeInterval, completion: @escaping (Bool) -> Void) {
        pending.append((time, completion))
    }
    func completeNext(_ completed: Bool) {
        guard !pending.isEmpty else { return }
        let next = pending.removeFirst()
        if completed { currentPlaybackTime = next.0 }
        next.1(completed)
    }
    func enterBackground() {}
    func enterForeground() {}
    func thumbnailImageAtCurrentTime() async -> CGImage? { nil }
    func tracks(mediaType: AVMediaType) -> [MediaPlayerTrack] { [] }
    func select(track: some MediaPlayerTrack) {}
}
