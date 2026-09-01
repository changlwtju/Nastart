import XCTest
@testable import Nastart

final class PlaybackNextCoreTests: XCTestCase {
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
