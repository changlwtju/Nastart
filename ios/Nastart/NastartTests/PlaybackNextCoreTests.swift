import XCTest
import AVFoundation
import Network
@testable import Nastart

final class PlaybackNextCoreTests: XCTestCase {
    @MainActor
    func testCompressedPlaylistIsDecodedBeforeRewritingAndSendingContentLength() async throws {
        let compressed = try XCTUnwrap(Data(base64Encoded: "H4sIAAAAAAAC/1N2jQjxNQ7lUgbSuhG6vq4uno66wa6Boa5+zq5WBmBxTz83K0MDHa7i1PTc1LwSA72SYmzihjBxoDmufi4+nsEhXABFPVjkXwAAAA=="))
        let server = try PlaybackRangeTestServer(playlist: "", compressedPlaylist: compressed)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(upstreamURL: XCTUnwrap(server.url),
            filename: "fixture.m3u8", allowsSelfSignedCertificates: false)
        AuthenticatedMediaStreamProxy.shared.setPlaylistStart(proxy, seconds: 12.5)
        let (data, response) = try await URLSession.shared.data(from: proxy)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("TIME-OFFSET=12.500"))
        XCTAssertTrue(text.contains("/child/"))
        XCTAssertEqual(response.expectedContentLength, Int64(data.count))
        XCTAssertNil((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Encoding"))
        let request = try XCTUnwrap(server.receivedRequests.first).lowercased()
        XCTAssertTrue(request.contains("gzip"))
        XCTAssertFalse(request.contains("accept-encoding: identity"))
    }

    @MainActor
    func testLargePlaylistUsesStableShortURLsAndPreservesChildAuthentication() async throws {
        let longQuery = String(repeating: "a", count: 700)
        let playlist = "#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:0\n#EXT-X-KEY:METHOD=AES-128,URI=\"key.bin?api_key=child-token\"\n"
            + (0..<7_525).map { "#EXTINF:1,\nsegment\($0).ts?options=\(longQuery)\n" }.joined()
            + "#EXT-X-ENDLIST\n"
        let server = try PlaybackRangeTestServer(playlist: playlist)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        var upstream = URLComponents(url: try XCTUnwrap(server.url), resolvingAgainstBaseURL: false)!
        upstream.queryItems = [URLQueryItem(name: "api_key", value: "parent-token"),
                               URLQueryItem(name: "PlaySessionId", value: "session-1")]
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(upstreamURL: XCTUnwrap(upstream.url),
            filename: "长片名.m3u8", allowsSelfSignedCertificates: false)
        AuthenticatedMediaStreamProxy.shared.setPlaylistStart(proxy, seconds: 5_432.5)
        let (data, _) = try await URLSession.shared.data(from: proxy)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertLessThan(data.count, playlist.utf8.count / 4)
        XCTAssertFalse(text.contains("parent-token"))
        XCTAssertFalse(text.contains("child-token"))
        XCTAssertEqual(text.components(separatedBy: "#EXTINF:").count, 7_526)
        XCTAssertTrue(text.contains("TIME-OFFSET=5432.500"))
        let segments = text.components(separatedBy: "\n").filter { $0.hasPrefix("http://") }
        let (reloaded, _) = try await URLSession.shared.data(from: proxy)
        XCTAssertEqual(data, reloaded, "Stable URLs keep repeated playlist loads cache-compatible")
        for index in [0, 5_432, 7_524] {
            let (_, response) = try await URLSession.shared.data(from: XCTUnwrap(URL(string: segments[index])))
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 206)
            let request = try XCTUnwrap(server.receivedRequests.last)
            XCTAssertTrue(request.contains("/segment\(index).ts?options="))
            XCTAssertTrue(request.contains("api_key=parent-token"))
            XCTAssertTrue(request.contains("PlaySessionId=session-1"))
            XCTAssertTrue(request.lowercased().contains("x-emby-token: parent-token"))
            XCTAssertTrue(request.lowercased().contains("accept-encoding: identity"))
        }
        let keyLine = try XCTUnwrap(text.components(separatedBy: "\n").first { $0.hasPrefix("#EXT-X-KEY:") })
        let keyURL = try XCTUnwrap(URL(string: keyLine.components(separatedBy: "\"")[1]))
        _ = try await URLSession.shared.data(from: keyURL)
        let keyRequest = try XCTUnwrap(server.receivedRequests.last)
        XCTAssertTrue(keyRequest.contains("api_key=child-token"))
        XCTAssertFalse(keyRequest.contains("parent-token"))
        let unknown = keyURL.deletingLastPathComponent().appendingPathComponent("unknown.ts")
        let (_, missing) = try await URLSession.shared.data(from: unknown)
        XCTAssertEqual((missing as? HTTPURLResponse)?.statusCode, 404)
        AuthenticatedMediaStreamProxy.shared.unregister(proxy)
        let (_, released) = try await URLSession.shared.data(from: keyURL)
        XCTAssertEqual((released as? HTTPURLResponse)?.statusCode, 404,
                       "Stopping a session must release its large segment index")
    }

    @MainActor
    func testExplicitOriginalUsesTheLinkedAudioDecoderCapabilities() {
        XCTAssertTrue(GreenfieldPlaybackControls.canDecodeOriginalAudio("truehd"))
        XCTAssertTrue(GreenfieldPlaybackControls.canDecodeOriginalAudio("ac3"))
        XCTAssertFalse(GreenfieldPlaybackControls.canDecodeOriginalAudio("h264"))
        XCTAssertFalse(GreenfieldPlaybackControls.canDecodeOriginalAudio("unknown-codec"))
        XCTAssertFalse(GreenfieldPlaybackControls.canDecodeOriginalAudio(nil))
    }

    @MainActor
    func testVODProxyStartsAtRequestedPositionWithoutChangingLivePlaylists() async throws {
        let vod = "#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:10,\nsegment0.ts\n#EXTINF:10,\nsegment1.ts\n#EXT-X-ENDLIST\n"
        let server = try PlaybackRangeTestServer(playlist: vod)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(upstreamURL: XCTUnwrap(server.url),
            filename: "fixture.m3u8", allowsSelfSignedCertificates: false)
        AuthenticatedMediaStreamProxy.shared.setPlaylistStart(proxy, seconds: 12.5)
        let (data, response) = try await URLSession.shared.data(from: proxy)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let rewritten = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(rewritten.contains("#EXT-X-START:TIME-OFFSET=12.500,PRECISE=YES"))
        XCTAssertTrue(rewritten.contains("/media/"))
        for unchanged in [vod.replacingOccurrences(of: "#EXT-X-ENDLIST", with: ""),
                          vod.replacingOccurrences(of: "MEDIA-SEQUENCE:0", with: "MEDIA-SEQUENCE:42"),
                          "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000\nmain.m3u8\n"] {
            XCTAssertEqual(PlaybackHLSStartOffset.applying(12.5, to: unchanged), unchanged)
        }
        for invalid in [Double.nan, .infinity, -1, 20] {
            XCTAssertEqual(PlaybackHLSStartOffset.applying(invalid, to: vod), vod)
        }
        XCTAssertEqual(PlaybackHLSStartOffset.applying(13, to: rewritten).components(separatedBy: "#EXT-X-START:").count, 2)
    }

    @MainActor
    func testNativeVideoConfiguresAudioWithoutCreatingKSPlayer() throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.ambient)
        try GreenfieldPlaybackAudioSession.activate()
        XCTAssertEqual(audio.category, .playback)
        XCTAssertEqual(audio.mode, .moviePlayback)
    }

    @MainActor
    func testReusedAVSurfaceReconnectsPictureInPictureAfterSessionDisconnect() {
        let controls = GreenfieldPlaybackControls()
        let surface = GreenfieldAVPlayerSurface.Coordinator()
        surface.connectControls(controls)
        XCTAssertNotNil(controls.pictureInPictureAction)
        controls.disconnect()
        XCTAssertNil(controls.pictureInPictureAction)
        surface.connectControls(controls)
        XCTAssertNotNil(controls.pictureInPictureAction)
        // Even an unavailable controller must report feedback instead of a
        // dead button after the model replaces its media session.
        controls.pictureInPictureAction?()
        XCTAssertTrue(controls.pictureInPictureUnavailable)
    }

    func testLocalVideoProxyPreservesPublicDomainAndIPv6NetworkPolicy() {
        for origin in ["https://media.example.com:8097/master.m3u8", "https://[2001:db8::42]:8097/master.m3u8"] {
            let request = MediaPlaybackRequest(url: URL(string: "http://127.0.0.1:49152/media/movie.m3u8")!,
                title: "Public NAS", source: .jellyfin, isPrivateNetworkRoute: false,
                externalHandoffResource: MediaPlaybackResource(url: URL(string: origin)!))
            let intent = request.greenfieldPlaybackLaunchRequest().intent
            XCTAssertEqual(intent.directURL?.host, "127.0.0.1")
            XCTAssertEqual(intent.connectionContext.port, 8097)
            XCTAssertEqual(intent.connectionContext.addressKind, origin.contains("example") ? .publicDomain : .publicIP)
            XCTAssertEqual(intent.networkContext.isPrivateRoute, false)
            XCTAssertNotEqual(intent.networkContext.networkClass, .local)
        }
    }

    @MainActor
    func testProxyStreamsSeparateRequestsOverAReusedUpstreamConnection() async throws {
        let server = try PlaybackRangeTestServer()
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let upstream = try XCTUnwrap(server.url)
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(upstreamURL: upstream,
            filename: "fixture.mp4", allowsSelfSignedCertificates: false)
        for _ in 0..<2 {
            let client = URLSession(configuration: .ephemeral)
            defer { client.invalidateAndCancel() }
            var request = URLRequest(url: proxy)
            request.timeoutInterval = 3
            request.setValue("bytes=0-3", forHTTPHeaderField: "Range")
            let (data, response) = try await client.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 206)
            XCTAssertEqual(data, Data("test".utf8))
        }
        XCTAssertEqual(server.requestCount, 2)
        XCTAssertEqual(server.connectionCount, 1, "Finishing a proxy transfer must keep its upstream connection reusable")
    }

    @MainActor
    func testSidecarTextSurvivesAudioChangesAndClearsWhenDisabled() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".srt")
        defer { try? FileManager.default.removeItem(at: url) }
        try "1\n00:37:28,760 --> 00:37:30,080\n我信任你\n{\\rEng}I trust you.\n\n"
            .write(to: url, atomically: true, encoding: .utf8)
        let model = CJKSubtitleOverlayModel()
        model.update(time: 2249)
        model.setURL(url)
        for _ in 0..<100 where model.text == nil { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(model.text, "我信任你\nI trust you.")
        model.setURL(url)
        XCTAssertEqual(model.text, "我信任你\nI trust you.")
        model.setURL(nil)
        XCTAssertNil(model.text)
        XCTAssertFalse(model.isEnabled)
    }

    @MainActor
    func testAudioTrackChangeKeepsSidecarAsTheOnlySubtitleRenderer() {
        let controls = GreenfieldPlaybackControls()
        let sidecar = URL(fileURLWithPath: "/tmp/subtitle.srt")
        var embedded: [Int32] = []
        var external: [URL?] = []
        controls.subtitleAction = { embedded.append($0) }
        controls.externalSubtitleAction = { external.append($0) }
        controls.selectSourceSubtitle(5, externalURL: sidecar)
        controls.selectSourceSubtitle(5, externalURL: sidecar) // Audio changed; subtitle stayed selected.
        XCTAssertTrue(embedded.isEmpty)
        XCTAssertEqual(external.compactMap { $0 }, [sidecar, sidecar])
        controls.selectSourceSubtitle(nil, externalURL: nil)
        XCTAssertEqual(embedded, [-1])
        controls.selectSourceSubtitle(6, externalURL: nil) // An embedded image subtitle.
        XCTAssertEqual(embedded, [-1, 6])
    }

    func testAbandonedWarmupReleasesEncoderWithoutReportingPlayback() {
        var releases = 0
        var reports = 0
        var tracker: MediaPlaybackTracker? = MediaPlaybackTracker(releaseResources: { releases += 1 }) { _ in reports += 1 }
        tracker?.stopped()
        tracker?.releasePreparedResources()
        tracker = nil
        XCTAssertEqual(releases, 1)
        XCTAssertEqual(reports, 0)
        var active: MediaPlaybackTracker? = MediaPlaybackTracker(releaseResources: { releases += 1 }) { _ in reports += 1 }
        active?.started(positionSeconds: 120)
        active?.stopped()
        active = nil
        XCTAssertEqual(releases, 2)
        XCTAssertEqual(reports, 2)
    }

    func testQualityMenuUsesMatchingEncoderDimensions() {
        for (bitrate, width, height) in [(30_000_000, 3840, 2160), (20_000_000, 1920, 1080),
            (12_000_000, 1920, 1080), (8_000_000, 1280, 720), (4_000_000, 854, 480), (2_000_000, 854, 480)] {
            let size = GreenfieldQualityPolicy.maximumVideoSize(bitrate: bitrate)
            XCTAssertEqual(size.width, width)
            XCTAssertEqual(size.height, height)
        }
    }

    @MainActor
    func testLargeMediaSeekKeepsTargetUntilEngineCompletion() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 7_535
        controls.isReady = true
        controls.isSeekable = true
        controls.currentSeconds = 120
        controls.readPlaybackClock = { 120.125 }
        XCTAssertEqual(controls.preciseCurrentSeconds, 120.125)
        var requests: [Double] = []
        controls.seekPlayback = { requests.append($0) }
        controls.seek(to: 0.75)
        controls.updateClock(120.5)
        controls.updateClock(121)
        XCTAssertEqual(controls.currentSeconds, 5_651.25)
        XCTAssertEqual(controls.preciseCurrentSeconds, 5_651.25)
        XCTAssertEqual(requests, [5_651.25])
        controls.seekDidComplete(true)
        controls.updateClock(5_651.28)
        XCTAssertEqual(controls.currentSeconds, 5_651.28)
    }

    @MainActor
    func testFailedSeekAndSessionReplacementReleasePendingClock() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 7_535
        controls.isReady = true
        controls.isSeekable = true
        controls.seekPlayback = { _ in }
        controls.seek(to: 0.8)
        controls.seekDidComplete(false)
        controls.updateClock(42)
        XCTAssertEqual(controls.currentSeconds, 42)
        controls.seek(to: 0.3)
        let generation = controls.seekGeneration
        controls.beginSession()
        controls.updateClock(9)
        XCTAssertEqual(controls.currentSeconds, 9)
        XCTAssertGreaterThan(controls.seekGeneration, generation)
    }

    @MainActor
    func testDisconnectedRendererDoesNotAcceptOrDisplayAnUnsubmittedSeek() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 7_535
        controls.isReady = true
        controls.isSeekable = true
        controls.currentSeconds = 120
        XCTAssertFalse(controls.seek(toAbsoluteSeconds: 600))
        controls.seek(to: 0.8)
        XCTAssertEqual(controls.currentSeconds, 120)
    }

#if canImport(KSPlayer)
    @MainActor
    func testOriginalReplacementDecodesPausedPreviewBeforeHandoff() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 90,
            AVVideoCompressionPropertiesKey: [AVVideoMaxKeyFrameIntervalKey: 30]
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                         kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 90])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for index in 0..<180 {
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw writer.error ?? NSError(domain: "Fixture", code: 1) }
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            var buffer: CVPixelBuffer?
            let pool = try XCTUnwrap(adaptor.pixelBufferPool)
            XCTAssertEqual(CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer), kCVReturnSuccess)
            let frame = try XCTUnwrap(buffer)
            CVPixelBufferLockBaseAddress(frame, [])
            memset(CVPixelBufferGetBaseAddress(frame), Int32(index % 128 * 2), CVPixelBufferGetBytesPerRow(frame) * 90)
            CVPixelBufferUnlockBaseAddress(frame, [])
            XCTAssertTrue(adaptor.append(frame, withPresentationTime: CMTime(value: Int64(index), timescale: 30)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
        let controls = GreenfieldPlaybackControls()
        let model = GreenfieldVideoPlayerModel()
        model.avControls = controls
        let native = MediaPlaybackRequest(url: url, title: "Native lifecycle", initialPosition: 0.25, totalDurationSeconds: 6)
            .greenfieldPlaybackLaunchRequest()
        let prepared = try await GreenfieldVideoPlayerModel.prepareSession(native)
        var nativeResult = prepared.result
        nativeResult.plan.enginePolicy = .systemAVPlayer
        model.start(native, preparedSession: .init(recorder: prepared.recorder,
            coordinator: prepared.coordinator, result: nativeResult))
        for _ in 0..<300 where !controls.isReady { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(controls.isReady)
        XCTAssertEqual(controls.engineName, "AVPlayer")
        XCTAssertFalse(model.player.isMuted)
        XCTAssertEqual(model.player.currentTime().seconds, 1.5, accuracy: 0.3,
                       "Startup must decode the saved position, not the beginning")
        controls.seekSeconds(2)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertGreaterThan(model.player.rate, 0, "Playing seek must resume the transport")
        controls.togglePlayback()
        controls.seekSeconds(1)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(model.player.rate, 0, "Paused seek must remain paused")
        model.stop()
        controls.startsPaused = true
        model.start(native, preparedSession: .init(recorder: prepared.recorder,
            coordinator: prepared.coordinator, result: nativeResult))
        for _ in 0..<300 where !controls.isReady { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(controls.isReady)
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(model.player.rate, 0)
        XCTAssertEqual(model.player.currentTime().seconds, 1.5, accuracy: 0.1)
        model.stop()
        // Exercise the AV handoff against actual decoded frames, including a
        // queued seek completing before AVPlayer becomes ready on iOS 16.
        let request = MediaPlaybackRequest(url: url, title: "AV warmup", initialPosition: 0.25,
                                           totalDurationSeconds: 6)
        let avPaused = await GreenfieldAVPlayerWarmup.prepare(request,
            liveClock: { 1.5 }, isPlaying: { false })
        XCTAssertNotNil(avPaused)
        XCTAssertEqual(avPaused?.currentTime().seconds ?? -1, 1.5, accuracy: 0.1)
        XCTAssertEqual(avPaused?.rate, 0)
        avPaused?.replaceCurrentItem(with: nil)
        let avStarted = ProcessInfo.processInfo.systemUptime
        let avMoving = await GreenfieldAVPlayerWarmup.prepare(request,
            liveClock: { 0.5 + ProcessInfo.processInfo.systemUptime - avStarted }, isPlaying: { true })
        XCTAssertNotNil(avMoving)
        XCTAssertEqual(avMoving?.currentTime().seconds ?? -1,
                       0.5 + ProcessInfo.processInfo.systemUptime - avStarted, accuracy: 0.15)
        avMoving?.pause()
        avMoving?.replaceCurrentItem(with: nil)
        let intent = PlaybackIntent(sourceKind: .directURL, itemIdentity: PlaybackItemIdentity(sourceKind: .directURL),
                                    displayTitle: "Warmup regression", directURL: url)
        let plan = PlaybackPlan(intent: intent, timeline: PlaybackTimeline(startTime: 0.5, duration: 6),
            primaryRoute: PlaybackRoute(routeKind: .localFile, playMethod: .directPlay, url: url))
        var stages: [String] = []
        let candidate = await GreenfieldKSPlayerRenderer.prepareReplacement(plan: plan,
            controls: GreenfieldPlaybackControls(), liveClock: { 1.5 }, isPlaying: { false },
            report: { stage, metrics in stages.append(stage); print("WARMUP_TEST", stage, metrics) })
        defer { candidate?.resetPlayer() }
        XCTAssertNotNil(candidate, "Warmup stages: \(stages)")
        XCTAssertTrue(stages.contains("candidate_aligned"))
        XCTAssertEqual(candidate?.playerLayer?.player.currentPlaybackTime ?? -1, 1.5, accuracy: 0.1)
        XCTAssertFalse(candidate?.playerLayer?.player.isPlaying ?? true)
        candidate?.resetPlayer()
        let started = ProcessInfo.processInfo.systemUptime
        let moving = await GreenfieldKSPlayerRenderer.prepareReplacement(plan: plan,
            controls: GreenfieldPlaybackControls(),
            liveClock: { 0.5 + ProcessInfo.processInfo.systemUptime - started }, isPlaying: { true },
            report: { stage, metrics in print("MOVING_WARMUP_TEST", stage, metrics) })
        defer { moving?.resetPlayer() }
        XCTAssertNotNil(moving)
        XCTAssertEqual(moving?.playerLayer?.player.currentPlaybackTime ?? -1,
                       0.5 + ProcessInfo.processInfo.systemUptime - started, accuracy: 0.15)
    }
    @MainActor
    func testOriginalReplacementFailureAndCancellationKeepExistingControls() async {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        let intent = PlaybackIntent(sourceKind: .directURL, itemIdentity: PlaybackItemIdentity(sourceKind: .directURL),
                                    displayTitle: "Missing fixture", directURL: missing)
        let plan = PlaybackPlan(intent: intent, timeline: PlaybackTimeline(duration: 6),
            primaryRoute: PlaybackRoute(routeKind: .localFile, playMethod: .directPlay, url: missing))
        let controls = GreenfieldPlaybackControls()
        controls.isPlaying = true
        controls.currentSeconds = 42
        let failed = await GreenfieldKSPlayerRenderer.prepareReplacement(plan: plan, controls: controls,
            liveClock: { 1 }, isPlaying: { true }, report: { _, _ in })
        XCTAssertNil(failed)
        XCTAssertTrue(controls.isPlaying)
        XCTAssertEqual(controls.currentSeconds, 42)
        let task = Task { @MainActor in
            await GreenfieldKSPlayerRenderer.prepareReplacement(plan: plan, controls: controls,
                liveClock: { 1 }, isPlaying: { true }, report: { _, _ in })
        }
        task.cancel()
        let cancelled = await task.value
        XCTAssertNil(cancelled)
        XCTAssertTrue(controls.isPlaying)
    }
#endif

    func testByteRangeMergesOverlappingAndTouchingRanges() async {
        let store = RangeCacheStore()

        await store.markCached(PlaybackByteRange(start: 100, endExclusive: 200))
        await store.markCached(PlaybackByteRange(start: 0, endExclusive: 50))
        await store.markCached(PlaybackByteRange(start: 50, endExclusive: 100))
        await store.markCached(PlaybackByteRange(start: 180, endExclusive: 220))

        let ranges = await store.cachedRanges
        let cachedBytes = await store.cachedBytes
        XCTAssertEqual(ranges, [PlaybackByteRange(start: 0, endExclusive: 220)])
        XCTAssertEqual(cachedBytes, 220)
    }

    func testRangeCacheReportsGapsInsideRequestedWindow() async {
        let store = RangeCacheStore()

        await store.markCached(PlaybackByteRange(start: 0, endExclusive: 100))
        await store.markCached(PlaybackByteRange(start: 200, endExclusive: 300))

        let gaps = await store.gaps(in: PlaybackByteRange(start: 50, endExclusive: 250))
        let wholeWindowIsCached = await store.isCached(PlaybackByteRange(start: 50, endExclusive: 250))
        let innerWindowIsCached = await store.isCached(PlaybackByteRange(start: 20, endExclusive: 80))
        XCTAssertEqual(gaps.map(\.range), [
            PlaybackByteRange(start: 100, endExclusive: 200)
        ])
        XCTAssertFalse(wholeWindowIsCached)
        XCTAssertTrue(innerWindowIsCached)
    }

    func testObservedPreloadHonorsBudget() async throws {
        let intent = PlaybackIntent(
            sourceKind: .directURL,
            itemIdentity: PlaybackItemIdentity(sourceKind: .directURL),
            displayTitle: "Sample",
            directURL: URL(string: "https://example.com/video.mkv")
        )
        let route = PlaybackRoute(
            routeKind: .directHTTP,
            playMethod: .directPlay,
            url: URL(string: "https://example.com/video.mkv")!,
            byteLength: 1_000,
            rangeCapability: .supported
        )
        let plan = PlaybackPlan(
            intent: intent,
            timeline: PlaybackTimeline(duration: 100),
            primaryRoute: route
        )
        let context = ObservingPlaybackIOContext(route: route)
        let coordinator = PreloadCoordinator()

        try await coordinator.schedule(
            PlaybackPreloadRequest(
                planID: plan.id,
                routeID: route.id,
                range: PlaybackByteRange(start: 0, endExclusive: 500),
                budgetBytes: 128,
                reason: .startup
            ),
            ioContext: context
        )

        let cachedRanges = await context.cachedRanges()
        let completedCount = await coordinator.completedRequests.count
        XCTAssertEqual(cachedRanges, [
            PlaybackByteRange(start: 0, endExclusive: 128)
        ])
        XCTAssertEqual(completedCount, 1)
    }

    func testScenarioMatrixCoversAgreedPlaybackEnvironments() {
        let scenarioIDs = Set(PlaybackScenarioMatrix.baseline.map(\.id))

        XCTAssertTrue(scenarioIDs.isSuperset(of: Set(PlaybackScenarioID.allCases)))
    }

    func testURLResolverBuildsJellyfinHLSPlan() async throws {
        let intent = PlaybackIntent(
            sourceKind: .jellyfin,
            contentKind: .video,
            itemIdentity: PlaybackItemIdentity(sourceKind: .jellyfin, itemID: "movie-1"),
            displayTitle: "Movie",
            directURL: URL(string: "https://jellyfin.example/videos/movie/master.m3u8")!,
            preferredStartTime: 120,
            networkContext: PlaybackNetworkContext(networkClass: .wifi, isPrivateRoute: false)
        )
        let resolver = URLPlaybackSourceResolver(
            sourceKind: .jellyfin,
            fileExtensionHint: "m3u8",
            mimeHint: "application/vnd.apple.mpegurl",
            duration: 3_600
        )

        let plan = try await resolver.resolve(intent)

        XCTAssertEqual(plan.primaryRoute.routeKind, .serverHLS)
        XCTAssertEqual(plan.primaryRoute.playMethod, .serverTranscode)
        XCTAssertEqual(plan.enginePolicy, .systemAVPlayer)
        XCTAssertEqual(plan.timeline.startTime, 120)
        XCTAssertEqual(plan.primaryRoute.rangeCapability, .unsupported)
    }

    func testConnectionContextClassifiesExternalDomainAndPrivateIPPorts() {
        let external = PlaybackConnectionContext.make(
            url: URL(string: "https://media.example.com:8920/video.mkv")!
        )
        let privateIP = PlaybackConnectionContext.make(
            url: URL(string: "http://192.168.1.8:5000/video.mkv")!
        )
        let localProxy = PlaybackConnectionContext.make(
            url: URL(string: "http://127.0.0.1:49152/video.mkv")!
        )
        let localDomain = PlaybackConnectionContext.make(
            url: URL(string: "http://nas.local:8096/video.mkv")!
        )

        XCTAssertEqual(external.addressKind, .publicDomain)
        XCTAssertEqual(external.port, 8920)
        XCTAssertEqual(privateIP.addressKind, .privateIP)
        XCTAssertEqual(privateIP.port, 5000)
        XCTAssertEqual(localProxy.addressKind, .loopback)
        XCTAssertEqual(localDomain.addressKind, .localDomain)
        let publicIPv6 = PlaybackConnectionContext.make(url: URL(string: "https://[2001:db8::42]:8097/video.mkv")!)
        let privateIPv6 = PlaybackConnectionContext.make(url: URL(string: "http://[fd12::42]:8096/video.mkv")!)
        XCTAssertEqual(publicIPv6.addressKind, .publicIP)
        XCTAssertEqual(publicIPv6.port, 8097)
        XCTAssertEqual(privateIPv6.addressKind, .privateIP)
    }

    func testPlanningPolicySeparatesDSMPrivateRangeFromExternalJellyfinDomain() async throws {
        let dsmIntent = PlaybackIntent(
            sourceKind: .dsmFile,
            contentKind: .video,
            itemIdentity: PlaybackItemIdentity(sourceKind: .dsmFile, stablePath: "/video/demo.mkv"),
            displayTitle: "DSM Demo",
            directURL: URL(string: "http://192.168.1.8:5000/video/demo.mkv")!,
            networkContext: PlaybackNetworkContext(networkClass: .local, isPrivateRoute: true)
        )
        let jellyfinIntent = PlaybackIntent(
            sourceKind: .jellyfin,
            contentKind: .video,
            itemIdentity: PlaybackItemIdentity(sourceKind: .jellyfin, itemID: "jf-1"),
            displayTitle: "Jellyfin Demo",
            directURL: URL(string: "https://media.example.com:8920/videos/jf-1/master.m3u8")!,
            networkContext: PlaybackNetworkContext(networkClass: .unknown, isPrivateRoute: false)
        )

        let dsmPlan = try await URLPlaybackSourceResolver(
            sourceKind: .dsmFile,
            fileExtensionHint: "mkv"
        ).resolve(dsmIntent)
        let jellyfinPlan = try await URLPlaybackSourceResolver(
            sourceKind: .jellyfin,
            fileExtensionHint: "m3u8"
        ).resolve(jellyfinIntent)

        XCTAssertEqual(dsmPlan.intent.connectionContext.addressKind, .privateIP)
        XCTAssertEqual(dsmPlan.primaryRoute.routeKind, .directHTTP)
        XCTAssertEqual(dsmPlan.enginePolicy, .ksPlayer)
        XCTAssertEqual(jellyfinPlan.intent.connectionContext.addressKind, .publicDomain)
        XCTAssertEqual(jellyfinPlan.intent.connectionContext.port, 8920)
        XCTAssertEqual(jellyfinPlan.primaryRoute.routeKind, .serverHLS)
        XCTAssertEqual(jellyfinPlan.enginePolicy, .systemAVPlayer)
    }

    func testEngineAvailabilityKeepsKSPlayerPolicySeparateFromLinkedBinary() async throws {
        let intent = PlaybackIntent(
            sourceKind: .dsmFile,
            contentKind: .video,
            itemIdentity: PlaybackItemIdentity(sourceKind: .dsmFile, stablePath: "/video/demo.mkv"),
            displayTitle: "DSM Demo",
            directURL: URL(string: "http://192.168.1.8:5000/video/demo.mkv")!,
            networkContext: PlaybackNetworkContext(networkClass: .local, isPrivateRoute: true)
        )

        let plan = try await URLPlaybackSourceResolver(
            sourceKind: .dsmFile,
            fileExtensionHint: "mkv"
        ).resolve(intent)

        XCTAssertEqual(plan.enginePolicy, .ksPlayer)
        XCTAssertTrue(PlaybackEngineAvailability.ksPlayerLinked)
        XCTAssertEqual(
            PlaybackEngineAvailability.isLinked(.ksPlayer),
            PlaybackEngineAvailability.ksPlayerLinked
        )
        XCTAssertTrue(PlaybackEngineAvailability.isLinked(.systemAVPlayer))
        XCTAssertTrue(PlaybackEngineAvailability.isLinked(.localHLS))
    }

    func testWeakCellularLargeFilePrioritizesFirstFrameOverStartupPreload() async throws {
        let recorder = PlaybackDiagnosticsRecorder()
        let intent = PlaybackIntent(
            sourceKind: .jellyfin,
            contentKind: .video,
            itemIdentity: PlaybackItemIdentity(sourceKind: .jellyfin, itemID: "large-remote-1"),
            displayTitle: "Remote Large File",
            directURL: URL(string: "https://media.example.com:8920/videos/large-original.mkv")!,
            networkContext: PlaybackNetworkContext(
                networkClass: .cellular,
                isPrivateRoute: false,
                isExpensive: true,
                isConstrained: true
            )
        )
        let resolver = URLPlaybackSourceResolver(
            sourceKind: .jellyfin,
            fileExtensionHint: "mkv",
            byteLength: 50 * 1024 * 1024 * 1024,
            duration: 7_200
        )
        let coordinator = PlaybackSessionCoordinator(
            resolver: resolver,
            diagnostics: recorder
        )

        let result = try await coordinator.prepare(intent)
        let routeEvents = await recorder.events.filter { $0.name == .routeSelected }
        let preloadEvents = await recorder.events.filter { $0.name == .preloadCancelled }

        XCTAssertEqual(result.plan.enginePolicy, .ksPlayer)
        XCTAssertEqual(result.plan.preloadPolicy.startupBytes, 512 * 1024)
        XCTAssertEqual(result.plan.startupPolicy.startupPreloadBytes, 512 * 1024)
        XCTAssertFalse(result.plan.startupPolicy.blocksFirstFrameUntilStartupPreload)
        XCTAssertEqual(result.completedPreloadBytes, 0)
        XCTAssertEqual(preloadEvents.first?.metrics["reason"], "first_frame_priority")
        XCTAssertEqual(routeEvents.first?.metrics[PlaybackMetricKeys.firstFrameTargetMs], "3000")
        XCTAssertEqual(routeEvents.first?.metrics[PlaybackMetricKeys.blocksFirstFrameUntilStartupPreload], "false")
    }

    func testSessionCoordinatorRecordsColdStartAndRuntimeEvents() async throws {
        let recorder = PlaybackDiagnosticsRecorder()
        let intent = PlaybackIntent(
            sourceKind: .directURL,
            contentKind: .video,
            itemIdentity: PlaybackItemIdentity(sourceKind: .directURL),
            displayTitle: "Movie",
            directURL: URL(string: "http://192.168.1.8:5000/movie.mkv")!,
            networkContext: PlaybackNetworkContext(networkClass: .local, isPrivateRoute: true)
        )
        let resolver = URLPlaybackSourceResolver(
            sourceKind: .directURL,
            fileExtensionHint: "mkv",
            byteLength: 1_000,
            duration: 100,
            tracks: TrackCatalog(
                sourceAudioTracks: [
                    PlaybackTrack(id: "1", index: 1, title: "Mandarin", codec: "aac")
                ],
                sourceSubtitleTracks: [
                    PlaybackTrack(id: "2", index: 2, title: "Chinese", codec: "srt")
                ],
                selectedSourceAudioTrackID: "1",
                selectedSourceSubtitleTrackID: "2"
            )
        )
        let coordinator = PlaybackSessionCoordinator(
            resolver: resolver,
            diagnostics: recorder
        )

        let result = try await coordinator.prepare(intent)
        try await coordinator.seek(plan: result.plan, to: 30, mode: .accurate)
        try await coordinator.selectAudioTrack(plan: result.plan, id: "1")
        try await coordinator.selectSubtitleTrack(plan: result.plan, id: "2")
        await coordinator.markFirstFrame(plan: result.plan, position: 0.25)
        await coordinator.markContinuousPlayback(plan: result.plan, seconds: 30)
        await coordinator.pause(plan: result.plan)
        try await coordinator.resume(plan: result.plan)
        await coordinator.updateNetwork(
            plan: result.plan,
            context: PlaybackNetworkContext(networkClass: .constrained)
        )
        await coordinator.updateBuffer(plan: result.plan, bufferAheadSeconds: 1.2)
        await coordinator.markStreamInterrupted(
            plan: result.plan,
            reason: "testDrop",
            fallbackRoute: result.plan.primaryRoute
        )
        let replacementRoute = PlaybackRoute(
            routeKind: .serverHLS,
            playMethod: .serverTranscode,
            url: URL(string: "https://example.com/movie-720p.m3u8")!,
            rangeCapability: .unsupported
        )
        let replacementPlan = PlaybackPlan(
            intent: intent,
            timeline: result.plan.timeline,
            primaryRoute: replacementRoute,
            enginePolicy: .systemAVPlayer
        )
        await coordinator.switchQuality(
            from: result.plan,
            to: replacementPlan,
            qualityID: "720p"
        )

        let allNames = await recorder.events.map(\.name)
        let names = await recorder.events(for: result.plan.id).map(\.name)
        XCTAssertTrue(allNames.contains(.intentCreated))
        XCTAssertTrue(allNames.contains(.sourceResolveStarted))
        XCTAssertTrue(allNames.contains(.qualityChanged))
        XCTAssertTrue(allNames.contains(.routeSelected))
        XCTAssertTrue(names.contains(.ioOpened))
        XCTAssertTrue(names.contains(.preloadCompleted))
        XCTAssertTrue(names.contains(.seekRecovered))
        XCTAssertTrue(names.contains(.audioTrackChanged))
        XCTAssertTrue(names.contains(.subtitleChanged))
        XCTAssertTrue(names.contains(.firstFrame))
        XCTAssertTrue(names.contains(.continuousPlaybackCheckpoint))
        XCTAssertTrue(names.contains(.paused))
        XCTAssertTrue(names.contains(.resumed))
        XCTAssertTrue(names.contains(.networkConditionChanged))
        XCTAssertTrue(names.contains(.bufferUpdated))
        XCTAssertTrue(names.contains(.streamInterrupted))
        XCTAssertTrue(names.contains(.fallbackSelected))
        XCTAssertTrue(names.contains(.qualityChanged))
        XCTAssertEqual(result.completedPreloadBytes, 1_000)
    }
}

private final class PlaybackRangeTestServer: @unchecked Sendable {
    let ready = XCTestExpectation(description: "HTTP range fixture listening")
    private let listener: NWListener
    private let queue = DispatchQueue(label: "PlaybackRangeTestServer")
    private var connections: [NWConnection] = []
    private var requests = 0
    private var requestHeaders: [String] = []
    private let playlist: String?
    private let compressedPlaylist: Data?
    var url: URL? { listener.port.flatMap { URL(string: "http://127.0.0.1:\($0.rawValue)/fixture.\(playlist == nil ? "mp4" : "m3u8")") } }
    var connectionCount: Int { queue.sync { connections.count } }
    var requestCount: Int { queue.sync { requests } }
    var receivedRequests: [String] { queue.sync { requestHeaders } }
    init(playlist: String? = nil, compressedPlaylist: Data? = nil) throws {
        self.playlist = playlist
        self.compressedPlaylist = compressedPlaylist
        listener = try NWListener(using: .tcp, on: .any)
        listener.stateUpdateHandler = { [weak self] state in
            if case .ready = state { self?.ready.fulfill() }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            self.connections.append(connection)
            connection.start(queue: self.queue)
            self.receive(connection)
        }
        listener.start(queue: queue)
    }
    func stop() {
        listener.cancel()
        queue.sync { connections.forEach { $0.cancel() } }
    }
    private func receive(_ connection: NWConnection, pending: Data = Data()) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, done, error in
            guard let self, let data, error == nil, !done else { return }
            let received = pending + data
            guard received.range(of: Data("\r\n\r\n".utf8)) != nil else {
                self.receive(connection, pending: received); return
            }
            self.requests += 1
            let request = String(decoding: received, as: UTF8.self)
            self.requestHeaders.append(request)
            let response: String
            if let playlist = self.playlist, request.components(separatedBy: " ").dropFirst().first?.contains(".m3u8") == true {
                response = "HTTP/1.1 200 OK\r\nContent-Type: application/vnd.apple.mpegurl\r\nContent-Length: \(playlist.utf8.count)\r\nConnection: keep-alive\r\n\r\n" + playlist
            } else {
                response = "HTTP/1.1 206 Partial Content\r\nContent-Type: video/mp4\r\nContent-Length: 4\r\nContent-Range: bytes 0-3/4\r\nAccept-Ranges: bytes\r\nConnection: keep-alive\r\n\r\ntest"
            }
            let responseData: Data
            if let compressed = self.compressedPlaylist {
                responseData = Data("HTTP/1.1 200 OK\r\nContent-Type: application/vnd.apple.mpegurl\r\nContent-Encoding: gzip\r\nContent-Length: \(compressed.count)\r\nConnection: keep-alive\r\n\r\n".utf8) + compressed
            } else { responseData = Data(response.utf8) }
            connection.send(content: responseData, completion: .contentProcessed { [weak self] error in
                if error == nil { self?.receive(connection) }
            })
        }
    }
}
