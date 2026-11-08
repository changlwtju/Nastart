import XCTest
import SwiftUI
import AVFoundation
import AVKit
import CoreVideo
import Network
import Darwin
import Combine
import JellyfinAPI
import NetworkMedia
#if canImport(KSPlayer)
@testable import KSPlayer
import Libavcodec
import Libavformat
import UIKit
#endif
@testable import Nastart

final class PlaybackNextCoreTests: XCTestCase {
    @MainActor func testSharedSeekCompletionRejectsOldAndDetachedRendererCallbacks() {
        let controls = GreenfieldPlaybackControls()
        controls.isReady = true; controls.isSeekable = true; controls.durationSeconds = 600
        controls.seekPlayback = { _ in }
        controls.seekSeconds(100)
        let old = controls.seekGeneration
        controls.seekSeconds(200)
        let latest = controls.seekGeneration
        controls.seekDidComplete(true, generation: old)
        XCTAssertTrue(controls.hasPendingSeek)
        XCTAssertEqual(controls.currentSeconds, 200)
        controls.seekDidComplete(true, generation: latest)
        XCTAssertFalse(controls.hasPendingSeek)
        controls.seekSeconds(300)
        let detached = controls.seekGeneration
        controls.beginSession()
        controls.seekDidComplete(true, generation: detached)
        XCTAssertFalse(controls.hasPendingSeek)
    }

    @MainActor func testInvalidSharedSeekDoesNotDispatchOrInvalidatePendingCommand() {
        let controls = GreenfieldPlaybackControls()
        controls.isReady = true; controls.isSeekable = true; controls.durationSeconds = 600
        var requested: [Double] = []
        controls.seekPlayback = { requested.append($0) }
        controls.seekSeconds(100)
        let generation = controls.seekGeneration
        controls.durationSeconds = .infinity
        XCTAssertFalse(controls.seek(toAbsoluteSeconds: 200))
        controls.seekSeconds(200)
        controls.durationSeconds = 600
        controls.seekSeconds(.nan)
        XCTAssertEqual(requested, [100])
        XCTAssertEqual(controls.seekGeneration, generation)
        XCTAssertTrue(controls.hasPendingSeek)
    }

    @MainActor func testUnifiedLifetimeRetiresTheActuallyInstalledFallbackPlan() async throws {
        let intent = PlaybackIntent(sourceKind: .jellyfin,
            itemIdentity: PlaybackItemIdentity(sourceKind: .jellyfin, stablePath: "offline-fixture"),
            displayTitle: "Offline fixture", directURL: URL(string: "https://fixture.example.test/original.mkv")!)
        let fallback = PlaybackRoute(routeKind: .directHTTP, playMethod: .directPlay,
            url: URL(string: "https://fixture.example.test/alternate.mkv")!)
        let request = GreenfieldPlaybackLaunchRequest(intent: intent, alternateRoutes: [fallback])
        let prepared = try await GreenfieldVideoPlayerModel.prepareSession(request)
        let model = GreenfieldVideoPlayerModel()
        defer { model.stop() }
        model.start(request, preparedSession: prepared)
        model.handleKSPlayerFinished("fixture engine failure", snapshot: nil)
        XCTAssertEqual(model.renderingPlan?.primaryRoute.url, fallback.url)
        XCTAssertEqual(prepared.finishingPlan.id, model.renderingPlan?.id)
        XCTAssertNotEqual(prepared.finishingPlan.id, prepared.result.plan.id)
    }

    @MainActor func testUnifiedModelRestartsEachSourceThroughTheSamePreparedLifetime() async throws {
        let model = GreenfieldVideoPlayerModel()
        defer { model.stop() }
        for kind in [PlaybackSourceKind.jellyfin, .dsmFile, .webDAVFile] {
            let intent = PlaybackIntent(sourceKind: kind,
                itemIdentity: PlaybackItemIdentity(sourceKind: kind, stablePath: "offline-fixture"),
                displayTitle: "Offline fixture", directURL: URL(string: "https://fixture.example.test/movie.mkv")!)
            let request = GreenfieldPlaybackLaunchRequest(intent: intent)
            let prepared = try await GreenfieldVideoPlayerModel.prepareSession(request)
            model.start(request, preparedSession: prepared)
            XCTAssertEqual(model.renderingPlan?.intent.sourceKind, kind)
            XCTAssertEqual(model.renderingPlan?.id, prepared.result.plan.id)
            XCTAssertEqual(model.renderingPlan?.enginePolicy, .ksPlayer)
            model.start(request, preparedSession: prepared)
            XCTAssertEqual(model.renderingPlan?.id, prepared.result.plan.id, "duplicate start cannot replace ownership")
            model.stop(); model.stop()
            XCTAssertNil(model.renderingPlan)
        }
    }

    @MainActor
    func testCandidateLabUsesNormalFullscreenHostAndReleasesRouteOnlyAfterDismissal() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        var releases = 0
        let tracker = MediaPlaybackTracker(releaseResources: { releases += 1 }) { _ in }
        let media = MediaPlaybackRequest(url: file, title: "Local presentation lifecycle", playbackTracker: tracker)
        var request: GreenfieldPlaybackLaunchRequest? = media.greenfieldPlaybackLaunchRequest()
        let binding = Binding(get: { request }, set: { request = $0 })
        let root = UIHostingController(rootView: PlaybackLabGreenfieldPresentation(request: binding))
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer {
            root.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        for _ in 0..<150 where root.presentedViewController == nil {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        let player = try XCTUnwrap(root.presentedViewController)
        XCTAssertTrue(String(describing: type(of: player)).contains("GreenfieldPlaybackHostingController"))
        XCTAssertEqual(player.modalPresentationStyle, .fullScreen)
        XCTAssertTrue(player.prefersHomeIndicatorAutoHidden)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(releases, 0, "Covering the diagnostic root must not revoke the player's active route")
        request = nil
        root.rootView = PlaybackLabGreenfieldPresentation(request: binding)
        for _ in 0..<150 where root.presentedViewController != nil || releases == 0 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertNil(root.presentedViewController)
        XCTAssertNil(request)
        XCTAssertEqual(releases, 1, "Normal dismissal must stop and release the owned route exactly once")
        root.rootView = PlaybackLabGreenfieldPresentation(request: binding)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(root.presentedViewController, "A finished diagnostic request must not present again")
        XCTAssertEqual(releases, 1)
    }


    func testFailedCandidateRetryUsesCandidateCeilingAndCapacityInsteadOfOriginalAgain() throws {
        let source = UUID()
        // These closures model the actual request loaders' captured ceiling and
        // trace-specific supply. The original is still playing after failure.
        let original = { PlaybackAdaptiveBitratePolicy.target(currentCeiling: 20_000_000,
            capacity: 38_052_257, networkKey: "wifi") }
        let failedCandidate = { PlaybackAdaptiveBitratePolicy.target(currentCeiling: 12_000_000,
            capacity: 2_586_237, networkKey: "wifi") }
        var retry = PlaybackFailedCandidateRetry<() -> Int?>(sourceID: source)
        XCTAssertEqual(retry.loader(or: original)(), 12_000_000)
        let ticket = retry.begin()
        XCTAssertTrue(retry.failed(ticket: ticket, currentSourceID: source,
            cancelled: false, candidateStillCurrent: true, continuation: failedCandidate))
        XCTAssertEqual(original(), 12_000_000, "Reusing the original context repeats the failed rendition")
        XCTAssertEqual(retry.loader(or: original)(), 1_000_000)
    }

    func testFailedCandidateRetryStillStepsDownWithStaleHighOrMissingCapacity() {
        for capacity: Int? in [38_052_257, nil] {
            let source = UUID()
            var retry = PlaybackFailedCandidateRetry<() -> Int?>(sourceID: source)
            let ticket = retry.begin()
            XCTAssertTrue(retry.failed(ticket: ticket, currentSourceID: source,
                cancelled: false, candidateStillCurrent: true, continuation: {
                    PlaybackAdaptiveBitratePolicy.target(currentCeiling: 12_000_000,
                        capacity: capacity, networkKey: "wifi")
                }))
            let result = retry.loader(or: { 12_000_000 })()
            XCTAssertEqual(result, capacity == nil ? 8_000_000 : 10_000_000)
        }
    }

    func testFailedCandidateRetryRejectsCancellationInvalidationAndDifferentSource() {
        for reason in ["cancel", "seek", "track", "pip", "source"] {
            let source = UUID()
            var retry = PlaybackFailedCandidateRetry<Int>(sourceID: source)
            let ticket = retry.begin()
            XCTAssertFalse(retry.failed(ticket: ticket,
                currentSourceID: reason == "source" ? UUID() : source,
                cancelled: reason == "cancel",
                candidateStillCurrent: reason == "source" || reason == "cancel", continuation: 1))
            XCTAssertEqual(retry.loader(or: 12), 12, reason)
        }
    }

    func testFailedCandidateRetryWithdrawnAndStaleTicketsCannotReplaceValidContinuation() {
        let source = UUID()
        var retry = PlaybackFailedCandidateRetry<Int>(sourceID: source)
        let first = retry.begin()
        XCTAssertTrue(retry.failed(ticket: first, currentSourceID: source,
            cancelled: false, candidateStillCurrent: true, continuation: 8))
        let recovered = retry.begin()
        retry.withdraw(ticket: recovered)
        XCTAssertFalse(retry.failed(ticket: recovered, currentSourceID: source,
            cancelled: false, candidateStillCurrent: true, continuation: 2))
        let stale = retry.begin()
        let current = retry.begin()
        retry.withdraw(ticket: stale)
        XCTAssertFalse(retry.failed(ticket: stale, currentSourceID: source,
            cancelled: false, candidateStillCurrent: true, continuation: 1))
        XCTAssertFalse(retry.failed(ticket: current, currentSourceID: source,
            cancelled: false, candidateStillCurrent: true, continuation: nil))
        XCTAssertEqual(retry.loader(or: 12), 8)
        XCTAssertFalse(retry.failed(ticket: first, currentSourceID: source,
            cancelled: false, candidateStillCurrent: true, continuation: 1))
        XCTAssertEqual(PlaybackFailedCandidateRetry<Int>(sourceID: UUID()).loader(or: 20), 20)
    }

#if DEBUG && canImport(KSPlayer)
    func testSeekFrameProbeSeparatesDiscardAcceptanceAndPushReturn() throws {
        let probe = KSSeekFrameDiagnostics()
        probe.willSeek(target: 10, now: 100)
        XCTAssertNil(probe.token(now: 100.1))
        probe.didFlush(revision: probe.prepareFlush(), now: 100.2)
        let token = try XCTUnwrap(probe.token(now: 100.3))
        probe.frame(token: token, discarded: true, start: 9.8, end: 9.9,
            timebaseNum: 1, timebaseDen: 90000, origin: 30, now: 100.3)
        probe.frame(token: token, discarded: false, start: 9.99, end: 10.03,
            timebaseNum: 1, timebaseDen: 90000, origin: 30, now: 100.4)
        var fields = try XCTUnwrap(probe.snapshot(now: 100.5)).fields
        XCTAssertEqual(fields["videoSeekCallbacks"], "2")
        XCTAssertEqual(fields["videoSeekDiscardedBeforeTarget"], "1")
        XCTAssertEqual(fields["videoSeekAcceptedBeforePush"], "1")
        XCTAssertEqual(fields["videoSeekPushReturned"], "0", "Passing the seek filter does not prove queue admission")
        XCTAssertNil(fields["videoSeekFirstPushReturnedMs"])
        XCTAssertEqual(fields["videoSeekTimebaseDen"], "90000", "Read the actual post-conversion unit, never infer milliseconds")
        XCTAssertEqual(fields["videoSeekTimestampOriginSeconds"], "30.0")
        XCTAssertEqual(try XCTUnwrap(Double(fields["videoSeekFirstAcceptedMs"]!)), 200, accuracy: 0.001)
        probe.didReturnFromPush(token: token, now: 100.8)
        fields = try XCTUnwrap(probe.snapshot(now: 100.9)).fields
        XCTAssertEqual(fields["videoSeekPushReturned"], "1")
        XCTAssertEqual(try XCTUnwrap(Double(fields["videoSeekFirstPushReturnedMs"]!)), 600, accuracy: 0.001)
    }

    func testSeekFrameProbeRejectsRetiredFlushAndDelayedCallbacks() throws {
        let probe = KSSeekFrameDiagnostics()
        probe.willSeek(target: 10, now: 20)
        let oldRevision = probe.prepareFlush()
        probe.didFlush(revision: oldRevision, now: 20.1)
        let oldToken = try XCTUnwrap(probe.token(now: 20.2))
        probe.willSeek(target: 30, now: 21)
        XCTAssertNil(probe.snapshot(now: 21.1))
        probe.didFlush(revision: oldRevision, now: 21.2)
        XCTAssertNil(probe.snapshot(now: 21.3), "A retired flush must not activate the new target")
        probe.didFlush(revision: probe.prepareFlush(), now: 21.4)
        let newToken = try XCTUnwrap(probe.token(now: 21.5))
        XCTAssertNotEqual(oldToken, newToken)
        probe.frame(token: oldToken, discarded: false, start: 10, end: 11,
            timebaseNum: 1, timebaseDen: 1000, origin: 0, now: 21.6)
        probe.didReturnFromPush(token: oldToken, now: 21.7)
        let fields = try XCTUnwrap(probe.snapshot(now: 21.8)).fields
        XCTAssertEqual(fields["videoSeekCallbacks"], "0")
        XCTAssertEqual(fields["videoSeekPushReturned"], "0")
        XCTAssertEqual(fields["videoSeekTargetSeconds"], "30.0")
        XCTAssertNil(probe.token(now: 31.001))
        XCTAssertNil(probe.snapshot(now: .nan))
    }

    func testSeekFrameProbeBoundsCountsAndKeepsUnknownDurationUnknown() throws {
        let probe = KSSeekFrameDiagnostics()
        probe.willSeek(target: 1, now: 0)
        probe.didFlush(revision: probe.prepareFlush(), now: 0.1)
        let token = try XCTUnwrap(probe.token(now: 0.2))
        for _ in 0..<5000 {
            probe.frame(token: token, discarded: false, start: 1, end: 1,
                timebaseNum: 1, timebaseDen: 1000, origin: 0, now: 0.3)
        }
        let fields = try XCTUnwrap(probe.snapshot(now: 0.4)).fields
        XCTAssertEqual(fields["videoSeekCallbacks"], "4096")
        XCTAssertEqual(fields["videoSeekInvalidIntervals"], "4096")
        XCTAssertEqual(fields["videoSeekCountsCapped"], "true")
        XCTAssertNil(fields["videoSeekLastAcceptedEndSeconds"])
        XCTAssertNil(fields["videoSeekTimebaseDen"])
        probe.willSeek(target: .infinity, now: 1)
        XCTAssertNil(probe.prepareFlush())
        XCTAssertNil(probe.snapshot(now: 1.1))
    }

    func testSeekFrameCoverageMergesOverlapAndPreservesRealGaps() throws {
        let coverage = try XCTUnwrap(KSSeekFrameDiagnostics.coverage([(3, 4), (1, 2), (1.5, 2.5), (1.6, 1.7)]))
        XCTAssertEqual(coverage.span, 3, accuracy: 0.00001)
        XCTAssertEqual(coverage.union, 2.5, accuracy: 0.00001)
        XCTAssertEqual(coverage.gaps, 0.5, accuracy: 0.00001)
        XCTAssertNil(KSSeekFrameDiagnostics.coverage([]))
        XCTAssertNil(KSSeekFrameDiagnostics.coverage([(1, 1)]))
        XCTAssertNil(KSSeekFrameDiagnostics.coverage([(1, .nan)]))
    }

    func testSeekFrameQueueSnapshotDoesNotConsumeAndRefusesPartialCoverage() throws {
        let queue = CircularBuffer<VideoVTBFrame>(initialCapacity: 4, sorted: true, expanding: false)
        for timestamp in [300, 100, 200] {
            let frame = VideoVTBFrame(fps: 24, isDovi: false)
            frame.timestamp = Int64(timestamp); frame.duration = 40
            queue.push(frame)
        }
        XCTAssertNil(queue.diagnosticSnapshot(limit: 2) { $0.timestamp })
        let snapshot = try XCTUnwrap(queue.diagnosticSnapshot(limit: 4) { $0.timestamp })
        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(snapshot.values, [100, 200, 300])
        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(queue.pop()?.timestamp, 100)
        queue.flush()
        XCTAssertEqual(queue.diagnosticSnapshot(limit: 4) { $0.timestamp }?.count, 0)
        queue.shutdown()
        XCTAssertNil(queue.diagnosticSnapshot(limit: 4) { $0.timestamp })
    }

    @MainActor
    func testSeekCapacityObserverBindsFuturePlanAndRejectsRetiredDelivery() {
        let controls = GreenfieldPlaybackControls(), owner = UUID()
        var rows: [[String: String]] = []
        let observe = controls.seekCapacityObserver(for: owner) { rows.append($0) }
        let generation = controls.seekGeneration
        controls.isReady = true
        observe(generation, ["phase": "waiting"])
        XCTAssertTrue(rows.isEmpty, "The plan is not configured yet")
        controls.planID = String(owner.uuidString.prefix(8))
        observe(generation, ["phase": "waiting"])
        XCTAssertEqual(rows.count, 1, "A callback installed before configure must accept its future owner")
        observe(generation + 1, ["phase": "playable"])
        XCTAssertEqual(rows.count, 1, "A different seek must not populate this window")
        controls.isReady = false
        observe(generation, ["phase": "playable"])
        controls.isReady = true
        controls.planID = "retired"
        observe(generation, ["phase": "playable"])
        XCTAssertEqual(rows.count, 1, "Disconnected and retired plans must not log delayed data")
    }

    func testSeekCapacityObservationIgnoresPreSeekQueuesAndFinishesOnReadiness() {
        var observation = PlaybackSeekCapacityObservation(generation: 7, started: 100)
        XCTAssertNil(observation.sample(now: 100.1, isSeek: false, playable: true))
        XCTAssertEqual(observation.sample(now: 100.2, isSeek: true, playable: false), "waiting")
        XCTAssertNil(observation.sample(now: 100.3, isSeek: true, playable: false))
        XCTAssertEqual(observation.sample(now: 100.4, isSeek: true, playable: true), "playable")
        XCTAssertNil(observation.sample(now: 101, isSeek: true, playable: false))
        XCTAssertEqual(observation.generation, 7)
    }

    func testSeekCapacityObservationBoundsVolumeAndKeepsTerminalSample() {
        var observation = PlaybackSeekCapacityObservation(generation: 2, started: 0)
        let waiting = (0..<1_000).compactMap {
            observation.sample(now: Double($0) / 100, isSeek: true, playable: false)
        }
        XCTAssertEqual(waiting.count, 20)
        XCTAssertEqual(observation.sample(now: 10, isSeek: true, playable: true), "playable")
        XCTAssertNil(observation.sample(now: 11, isSeek: true, playable: true))
    }

    func testSeekCapacityObservationRejectsInvalidTimeAndExpiresWithoutSeek() {
        var observation = PlaybackSeekCapacityObservation(generation: 3, started: 20)
        XCTAssertNil(observation.sample(now: .nan, isSeek: true, playable: false))
        XCTAssertNil(observation.sample(now: 19, isSeek: true, playable: false))
        XCTAssertNil(observation.sample(now: 20.1, isSeek: false, playable: true))
        XCTAssertEqual(observation.sample(now: 30.1, isSeek: false, playable: false), "expired")
        XCTAssertNil(observation.sample(now: 31, isSeek: true, playable: true))
        observation = PlaybackSeekCapacityObservation(generation: 4, started: 40)
        XCTAssertEqual(observation.sample(now: 40, isSeek: true, playable: false), "waiting")
    }
#endif

    @MainActor
    func testSystemPiPPlaybackObserverReportsActualResultWithoutChangingControls() {
        let controls = GreenfieldPlaybackControls(), owner = UUID()
        controls.beginSession(renderingPlanID: owner)
        controls.isPictureInPictureActive = true
        controls.isPlaying = true
        var rows: [[String: String]] = []
        let observe = controls.pictureInPicturePlaybackObserver(for: owner) { rows.append($0) }
        observe(false, false, 12.25, 123)
        observe(true, false, 12.25, 124)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["ownerPlanID"], owner.uuidString)
        XCTAssertEqual(rows[0]["requestedPlaying"], "false")
        XCTAssertEqual(rows[0]["actualPlaying"], "false")
        XCTAssertEqual(rows[1]["requestedPlaying"], "true")
        XCTAssertEqual(rows[1]["actualPlaying"], "false", "A requested play is not proof of its effect")
        XCTAssertEqual(rows[0]["snapshotUptime"], "123.0")
        XCTAssertNotEqual(rows[0]["observationID"], rows[1]["observationID"])
        XCTAssertTrue(controls.isPlaying, "The observation hook must not change playback behavior")
    }

    @MainActor
    func testSystemPiPPlaybackObserverRejectsRetiredSamePrefixAndDisconnectedOwners() throws {
        let old = try XCTUnwrap(UUID(uuidString: "12345678-0000-0000-0000-000000000001"))
        let current = try XCTUnwrap(UUID(uuidString: "12345678-0000-0000-0000-000000000002"))
        let controls = GreenfieldPlaybackControls()
        var rows: [[String: String]] = []
        let observe = controls.pictureInPicturePlaybackObserver(for: old) { rows.append($0) }
        controls.isPictureInPictureActive = true
        observe(false, false, 1, 1)
        controls.beginSession(renderingPlanID: old)
        controls.isPictureInPictureActive = false
        observe(false, false, 1, 1)
        controls.isPictureInPictureActive = true
        observe(false, false, 1, 1)
        XCTAssertEqual(rows.count, 1)
        controls.beginSession(renderingPlanID: current)
        observe(false, false, 2, 2)
        controls.disconnect()
        controls.isPictureInPictureActive = true
        observe(false, false, 3, 3)
        XCTAssertEqual(rows.count, 1, "A late callback must not label a new or retired renderer")
    }

    @MainActor
    func testSystemPiPPlaybackObserverRejectsInvalidSnapshotsAndDoesNotRetainOwner() throws {
        var controls: GreenfieldPlaybackControls? = GreenfieldPlaybackControls()
        weak var released = controls
        let owner = UUID()
        controls?.beginSession(renderingPlanID: owner)
        controls?.isPictureInPictureActive = true
        var rows: [[String: String]] = []
        let observe = try XCTUnwrap(controls?.pictureInPicturePlaybackObserver(for: owner) { rows.append($0) })
        for (seconds, uptime) in [(Double.nan, 1.0), (-1.0, 1.0), (1.0, Double.infinity), (1.0, 0.0)] {
            observe(false, false, seconds, uptime)
        }
        XCTAssertTrue(rows.isEmpty)
        controls = nil
        XCTAssertNil(released)
        observe(false, false, 1, 1)
        XCTAssertTrue(rows.isEmpty)
    }

#if canImport(KSPlayer)
    @MainActor
    func testSystemPiPPlaybackCommandObservesEngineAfterApplyingEachCommand() {
        let options = KSOptions()
        options.registerRemoteControll = false
        let player = KSMEPlayer(url: URL(fileURLWithPath: "/unused-system-pip-observation.mkv"), options: options)
        defer { player.shutdown() }
        var samples: [(Bool, Bool, Double)] = []
        options.pictureInPicturePlaybackChanged = { requested, actual, _, uptime in
            XCTAssertEqual(actual, player.isPlaying)
            samples.append((requested, actual, uptime))
        }
        defer { options.pictureInPicturePlaybackChanged = nil }
        player.applySystemPictureInPicturePlayback(false)
        player.applySystemPictureInPicturePlayback(true)
        player.applySystemPictureInPicturePlayback(false)
        XCTAssertEqual(samples.map { $0.0 }, [false, true, false])
        XCTAssertEqual(samples.map { $0.1 }, [false, true, false])
        XCTAssertTrue(samples.allSatisfy { $0.2.isFinite && $0.2 > 0 })
    }
#endif

    private func pipFrameBuffer() throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(nil, 16, 16, kCVPixelFormatType_32BGRA,
            nil, &buffer), kCVReturnSuccess)
        return try XCTUnwrap(buffer)
    }

    func testPiPDecodedFrameContextRetainsIndependentDolbyAndCompressedDescription() throws {
        let buffer = try pipFrameBuffer()
        var description: CMVideoFormatDescription?
        XCTAssertEqual(CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
            imageBuffer: buffer, formatDescriptionOut: &description), noErr)
        let display = try XCTUnwrap(description)
        var compressed: CMVideoFormatDescription?
        XCTAssertEqual(CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault,
            codecType: kCMVideoCodecType_HEVC, width: 16, height: 16, extensions: nil,
            formatDescriptionOut: &compressed), noErr)
        let frame = VideoVTBFrame(fps: 24, isDovi: true)
        frame.dolbyConfiguration = DOVIDecoderConfigurationRecord(dv_version_major: 1, dv_version_minor: 0,
            dv_profile: 7, dv_level: 6, rpu_present_flag: 1, el_present_flag: 1, bl_present_flag: 1,
            dv_bl_signal_compatibility_id: 6)
        frame.sideDataInspection = "avFrameBeforeFilter"
        frame.sideDataSizes = ["Dolby Vision RPU Data": 420]
        frame.compressedFormatDescription = compressed
        let context = frame.pictureInPictureContext(displayFormatDescription: display)
        frame.sideDataSizes = [:] // Snapshot must not follow later mutation.
        frame.dolbyConfiguration = nil
        XCTAssertEqual(context.dolbyConfiguration?.dv_profile, 7)
        XCTAssertEqual(context.dolbyConfiguration?.dv_bl_signal_compatibility_id, 6)
        XCTAssertEqual(context.dolbyConfiguration?.bl_present_flag, 1)
        XCTAssertEqual(context.dolbyConfiguration?.el_present_flag, 1)
        XCTAssertTrue(context.isDolbyVision)
        XCTAssertFalse(context.hasStaticEDR)
        XCTAssertEqual(context.sideDataInspection, "avFrameBeforeFilter")
        XCTAssertEqual(context.sideDataSizes, ["Dolby Vision RPU Data": 420])
        XCTAssertTrue(context.displayFormatDescription === display)
        XCTAssertTrue(context.compressedFormatDescription === compressed)
        XCTAssertEqual(CMFormatDescriptionGetMediaSubType(try XCTUnwrap(context.compressedFormatDescription)),
                       kCMVideoCodecType_HEVC)
    }

    @MainActor
    func testContextualPiPCallbackRejectsRetiredAndReleasedOwnersBeforeAnyRead() throws {
        var controls: GreenfieldPlaybackControls? = GreenfieldPlaybackControls()
        weak var released = controls
        let owner = try XCTUnwrap(UUID(uuidString: "12345678-0000-0000-0000-000000000001"))
        let next = try XCTUnwrap(UUID(uuidString: "12345678-0000-0000-0000-000000000002"))
        let buffer = try pipFrameBuffer()
        var observations: [String] = []
        let callback: (CVPixelBuffer, TimeInterval, String) -> CVPixelBuffer? =
            try XCTUnwrap(controls).pictureInPictureFrameTransform(for: owner) { source, _, context in
                observations.append(context)
                return source
            }
        controls?.isPictureInPictureActive = true
        XCTAssertNil(callback(buffer, 1, "unconnected"))
        controls?.beginSession(renderingPlanID: owner)
        controls?.isPictureInPictureActive = false
        XCTAssertNil(callback(buffer, 1, "inactive"))
        controls?.isPictureInPictureActive = true
        XCTAssertTrue(callback(buffer, 1, "same-frame") === buffer)
        controls?.beginSession(renderingPlanID: next)
        XCTAssertNil(callback(buffer, 2, "same-prefix-retired"))
        controls?.beginSession(renderingPlanID: owner)
        controls?.disconnect()
        XCTAssertNil(callback(buffer, 3, "disconnected"))
        controls = nil
        XCTAssertNil(released)
        XCTAssertNil(callback(buffer, 4, "released"))
        XCTAssertEqual(observations, ["same-frame"])
    }

    func testPiPFrameInventoryDoesNotExportPayloadsOrChangeAttachments() throws {
        let buffer = try pipFrameBuffer()
        let payload = Data("PRIVATE_PAYLOAD_MUST_NOT_BE_LOGGED".utf8)
        CVBufferSetAttachment(buffer, "DolbyVisionRPUData" as CFString, payload as CFData, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey,
                              kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ, .shouldPropagate)
        let before = CVBufferCopyAttachments(buffer, .shouldPropagate) as NSDictionary?
        var description: CMVideoFormatDescription?
        XCTAssertEqual(CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
            imageBuffer: buffer, formatDescriptionOut: &description), noErr)
        let context = KSPictureInPictureFrameContext(isDolbyVision: false, hasStaticEDR: true,
            sideDataInspection: "notExposedByVideoToolbox", sideDataSizes: [:],
            compressedFormatDescription: nil, displayFormatDescription: try XCTUnwrap(description))
        let fields = GreenfieldPiPFrameInventory.fields(buffer: buffer, context: context)
        XCTAssertEqual(fields["sourceIsDolbyVision"], "false")
        XCTAssertEqual(fields["sourceDolbyProfile"], "unknown")
        XCTAssertEqual(fields["sourceDolbyCompatibilityID"], "unknown")
        XCTAssertEqual(fields["frameHasStaticEDR"], "true")
        XCTAssertEqual(fields["sideDataInspection"], "notExposedByVideoToolbox")
        XCTAssertEqual(fields["sourceCompressedDescriptionAvailable"], "false")
        XCTAssertEqual(fields["compressedExtensionInventory"], "unknown")
        XCTAssertTrue(try XCTUnwrap(fields["pixelPropagatedInventory"]).contains("DolbyVisionRPUData:data:"))
        XCTAssertFalse(fields.values.joined().contains(String(decoding: payload, as: UTF8.self)))
        XCTAssertEqual(CVBufferCopyAttachments(buffer, .shouldPropagate) as NSDictionary?, before)
    }

    func testPiPMasteringPayloadUsesGBRBigEndianAndNormalizedLuminance() throws {
        let rgb = [[0.68, 0.32], [0.265, 0.69], [0.15, 0.06]]
        let payload = try XCTUnwrap(KSPiPMasteringDisplayEncoder.encode(rgb: rgb,
            white: [0.3127, 0.329], maximumNits: 1000, minimumNits: 0.005))
        XCTAssertEqual(payload.map { String(format: "%02x", $0) }.joined(),
                       "33c286c41d4c0bb884d03e803d1340420098968000000032")
        for maximum in [Double.nan, .infinity, -1, 0, 10001] {
            XCTAssertNil(KSPiPMasteringDisplayEncoder.encode(rgb: rgb, white: [0.3127, 0.329],
                maximumNits: maximum, minimumNits: 0))
        }
        XCTAssertNil(KSPiPMasteringDisplayEncoder.encode(rgb: [[.nan, 0], [0, 0], [0, 0]],
            white: [0, 0], maximumNits: 1000, minimumNits: 0))
        XCTAssertNil(KSPiPMasteringDisplayEncoder.encode(rgb: [[0, 0]],
            white: [0, 0], maximumNits: 1000, minimumNits: 0))
        XCTAssertNil(KSPiPMasteringDisplayEncoder.encode(rgb: rgb,
            white: [0, 0], maximumNits: 1000, minimumNits: 1001))
    }

    func testPiPReferenceWhiteUsesMeasuredPlatformValueInsteadOfFixedMultiplier() throws {
        XCTAssertEqual(try XCTUnwrap(GreenfieldPiPReferenceWhite.gain(measuredNits: 100)), 2.03, accuracy: 0.00001)
        XCTAssertEqual(try XCTUnwrap(GreenfieldPiPReferenceWhite.gain(measuredNits: 203)), 1, accuracy: 0.00001)
        for bad in [Double.nan, .infinity, 0, 79, 251] {
            XCTAssertNil(GreenfieldPiPReferenceWhite.gain(measuredNits: bad))
        }
    }

    func testPiPSurfaceLedgerLatchesAfterNewFifthSurface() {
        var ledger = GreenfieldPiPSurfaceLedger()
        for id in UInt32(1)...4 { XCTAssertTrue(ledger.admit(id)) }
        for _ in 0..<24 { XCTAssertTrue(ledger.admit(1)) }
        XCTAssertEqual(ledger.surfaces.count, 4)
        XCTAssertFalse(ledger.admit(5))
        XCTAssertTrue(ledger.disabled)
        XCTAssertFalse(ledger.admit(1))
        XCTAssertFalse(ledger.admit(6))
        XCTAssertEqual(ledger.surfaces.count, 5)
        var invalidSize = GreenfieldPiPSurfaceLedger()
        invalidSize.disable()
        XCTAssertFalse(invalidSize.admit(1))
        XCTAssertTrue(invalidSize.surfaces.isEmpty)
    }

    private func pqPiPFixture(profile: UInt8 = 7, compatibility: UInt8 = 6,
                              sideData: [String: Int] = ["Mastering display metadata": 88,
                                                        "Dolby Vision RPU Data": 388]) throws
        -> (CVPixelBuffer, KSPictureInPictureFrameContext) {
        var result: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(nil, 3840, 2160, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &result), 0)
        let buffer = try XCTUnwrap(result)
        CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey,
                              kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey,
                              kCVImageBufferColorPrimaries_ITU_R_2020, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey,
                              kCVImageBufferYCbCrMatrix_ITU_R_2020, .shouldPropagate)
        var display: CMVideoFormatDescription?, compressed: CMVideoFormatDescription?
        XCTAssertEqual(CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil,
            imageBuffer: buffer, formatDescriptionOut: &display), 0)
        XCTAssertEqual(CMVideoFormatDescriptionCreate(allocator: nil, codecType: kCMVideoCodecType_HEVC,
            width: 3840, height: 2160, extensions: nil, formatDescriptionOut: &compressed), 0)
        let metadata = try XCTUnwrap(KSPiPMasteringDisplayEncoder.encode(
            rgb: [[0.68, 0.32], [0.265, 0.69], [0.15, 0.06]], white: [0.3127, 0.329],
            maximumNits: 1000, minimumNits: 0.005))
        return (buffer, KSPictureInPictureFrameContext(isDolbyVision: true,
            dolbyConfiguration: .init(dv_version_major: 1, dv_version_minor: 0, dv_profile: profile,
                dv_level: 6, rpu_present_flag: 1, el_present_flag: 1, bl_present_flag: 1,
                dv_bl_signal_compatibility_id: compatibility),
            masteringDisplayData: metadata, masteringMaximumNits: 1000, hasStaticEDR: true,
            sideDataInspection: "avFrameBeforeFilter", sideDataSizes: sideData,
            compressedFormatDescription: compressed, displayFormatDescription: try XCTUnwrap(display)))
    }

    func testPiPPQAdmissionRejectsIncompatibleDolbyAndUnknownDynamicData() throws {
        let (buffer, context) = try pqPiPFixture()
        XCTAssertNil(GreenfieldPiPPQAdmission.rejection(buffer: buffer, context: context))
        let (p8, c8) = try pqPiPFixture(profile: 8, compatibility: 1)
        XCTAssertNil(GreenfieldPiPPQAdmission.rejection(buffer: p8, context: c8))
        let (p5, c5) = try pqPiPFixture(profile: 5, compatibility: 0)
        XCTAssertEqual(GreenfieldPiPPQAdmission.rejection(buffer: p5, context: c5),
                       "hdrDolbyBaseCompatibilityUnknown")
        let (dynamic, dynamicContext) = try pqPiPFixture(sideData: ["HDR Dynamic Metadata SMPTE2094-40": 32])
        XCTAssertEqual(GreenfieldPiPPQAdmission.rejection(buffer: dynamic, context: dynamicContext),
                       "hdrSideDataUnhandled")
        CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey,
                              kCVImageBufferTransferFunction_ITU_R_2100_HLG, .shouldPropagate)
        XCTAssertEqual(GreenfieldPiPPQAdmission.rejection(buffer: buffer, context: context),
                       "hdrColorDescriptionUnsupported")
        XCTAssertEqual(GreenfieldPiPPQAdmission.rejection(buffer: try pipFrameBuffer(), context: context),
                       "hdrFixedGeometryUnsupported")
    }

    @MainActor
    func testPiPPQCandidateProducesTenBitSubtitlePixelsWithoutMutatingSource() throws {
        let (source, context) = try pqPiPFixture()
        let pq = try XCTUnwrap(CGColorSpace(name: CGColorSpace.itur_2100_PQ))
        let linear = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020))
        let ci = CIContext(options: [.workingColorSpace: linear, .workingFormat: CIFormat.RGBAh])
        ci.render(CIImage(color: .black), to: source,
            bounds: CGRect(x: 0, y: 0, width: 3840, height: 2160), colorSpace: pq)
        let before = CVBufferCopyAttachments(source, .shouldPropagate) as NSDictionary?
        let normal = GreenfieldPiPSubtitleCompositor(hdrCandidateEnabled: false)
        XCTAssertEqual(normal.composite(source, text: "字幕 CAPTION", images: [],
            videoSize: CGSize(width: 3840, height: 2160), frameContext: context).reason, "hdrPQPreserved")
        let compositor = GreenfieldPiPSubtitleCompositor(hdrCandidateEnabled: true)
        let outcome = compositor.composite(source, text: "字幕 CAPTION", images: [],
            videoSize: CGSize(width: 3840, height: 2160), frameContext: context)
        XCTAssertEqual(outcome.reason, "hdrPQOutputCreated", String(describing: outcome.metrics))
        let output = try XCTUnwrap(outcome.pixelBuffer)
        XCTAssertEqual(CVPixelBufferGetPixelFormatType(output), kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        XCTAssertEqual(CVBufferCopyAttachment(output, kCVImageBufferMasteringDisplayColorVolumeKey, nil) as? Data,
                       context.masteringDisplayData)
        XCTAssertEqual(outcome.metrics["hdrDynamicPayloadCopied"], "false")
        XCTAssertNil(CVBufferCopyAttachment(output, kCVImageBufferContentLightLevelInfoKey, nil))
        CVPixelBufferLockBaseAddress(output, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(output, .readOnly) }
        let row = CVPixelBufferGetBytesPerRowOfPlane(output, 0) / 2
        let pixels = try XCTUnwrap(CVPixelBufferGetBaseAddressOfPlane(output, 0)).assumingMemoryBound(to: UInt16.self)
        var bright = 0
        for y in 1600..<2050 { for x in 200..<3640 where pixels[y * row + x] >> 6 > 400 { bright += 1 } }
        XCTAssertGreaterThan(bright, 1000, "A created buffer alone does not prove subtitle pixels")
        XCTAssertLessThan(pixels[100 * row + 100] >> 6, 80, "Unchanged black area must stay black")
        XCTAssertEqual(CVBufferCopyAttachments(source, .shouldPropagate) as NSDictionary?, before)
        CVPixelBufferLockBaseAddress(source, .readOnly)
        let original = try XCTUnwrap(CVPixelBufferGetBaseAddressOfPlane(source, 0)).assumingMemoryBound(to: UInt16.self)
        XCTAssertLessThan(original[1900 * CVPixelBufferGetBytesPerRowOfPlane(source, 0) / 2 + 1920] >> 6, 80)
        CVPixelBufferUnlockBaseAddress(source, .readOnly)
    }

    @MainActor
    func testPiPFrameCallbackDefersAllWorkUntilItsFullPlanIsActive() throws {
        let controls = GreenfieldPlaybackControls()
        let plan = UUID()
        let source = try pipFrameBuffer(), output = try pipFrameBuffer()
        var calls: [(CVPixelBuffer, TimeInterval)] = []
        let callback = controls.pictureInPictureFrameTransform(for: plan) { buffer, seconds in
            calls.append((buffer, seconds))
            return output
        }
        controls.isPictureInPictureActive = true
        XCTAssertNil(callback(source, 123.25), "An unconnected renderer cannot refresh cues")
        controls.beginSession(renderingPlanID: plan)
        controls.isPictureInPictureActive = false
        XCTAssertNil(callback(source, 123.25))
        XCTAssertTrue(calls.isEmpty)
        controls.isPictureInPictureActive = true
        XCTAssertTrue(callback(source, 123.25) === output)
        XCTAssertEqual(calls.count, 1)
        XCTAssertTrue(calls[0].0 === source)
        XCTAssertEqual(calls[0].1, 123.25)
        controls.isPictureInPictureActive = false
        XCTAssertNil(callback(source, 124))
        controls.isPictureInPictureActive = true
        XCTAssertTrue(callback(source, 125) === output, "Restoring PiP does not retire the same plan")
        XCTAssertEqual(calls.count, 2)
    }

    @MainActor
    func testPiPFrameCallbackRejectsRetiredPlanWithTheSameDiagnosticPrefix() throws {
        let old = try XCTUnwrap(UUID(uuidString: "12345678-0000-0000-0000-000000000001"))
        let current = try XCTUnwrap(UUID(uuidString: "12345678-0000-0000-0000-000000000002"))
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(renderingPlanID: old)
        controls.planID = "12345678"
        controls.isPictureInPictureActive = true
        let source = try pipFrameBuffer()
        var oldCueUpdates = 0
        let retired = controls.pictureInPictureFrameTransform(for: old) { buffer, _ in
            oldCueUpdates += 1
            return buffer
        }
        XCTAssertTrue(retired(source, 10) === source)
        controls.beginSession(renderingPlanID: current)
        // The same controls can now belong to a KS replacement or AV session.
        XCTAssertNil(retired(source, 11))
        XCTAssertEqual(oldCueUpdates, 1, "Reject before any old cue/cache side effects")
        let live = controls.pictureInPictureFrameTransform(for: current) { buffer, _ in buffer }
        XCTAssertTrue(live(source, 12) === source)
    }

    @MainActor
    func testPiPDisconnectRetiresFrameCallbacksBeforeActiveStateChanges() throws {
        let controls = GreenfieldPlaybackControls()
        let plan = UUID(), source = try pipFrameBuffer()
        controls.beginSession(renderingPlanID: plan)
        controls.isPictureInPictureActive = true
        var calls = 0
        let callback = controls.pictureInPictureFrameTransform(for: plan) { _, _ in
            calls += 1
            return nil
        }
        XCTAssertNil(callback(source, 1), "A supported owner can still choose original-frame fallback")
        XCTAssertEqual(calls, 1)
        controls.disconnect()
        controls.isPictureInPictureActive = true // A late delegate callback must not revive ownership.
        XCTAssertNil(callback(source, 2))
        XCTAssertNil(controls.renderingPlanID)
        XCTAssertEqual(calls, 1)
    }

    @MainActor
    func testPiPFrameCallbackDoesNotRetainItsControls() throws {
        var controls: GreenfieldPlaybackControls? = GreenfieldPlaybackControls()
        weak var released = controls
        let plan = UUID(), source = try pipFrameBuffer()
        controls?.beginSession(renderingPlanID: plan)
        controls?.isPictureInPictureActive = true
        var calls = 0
        let callback = try XCTUnwrap(controls?.pictureInPictureFrameTransform(for: plan) { buffer, _ in
            calls += 1
            return buffer
        })
        controls = nil
        XCTAssertNil(released)
        XCTAssertNil(callback(source, 1))
        XCTAssertEqual(calls, 0)
    }

    @MainActor
    func testCandidateLabRequiresExplicitSameOriginAndKnownDuration() async throws {
        let valid = ["NASTART_PLAYBACK_LAB_CANDIDATE": "1",
            "NASTART_PLAYBACK_LAB_ARCHITECTURE": "greenfield",
            "NASTART_PLAYBACK_LAB_URL": "http://127.0.0.1:8123/original.m3u8",
            "NASTART_PLAYBACK_LAB_CANDIDATE_URL": "http://127.0.0.1:8123/candidate.m3u8",
            "NASTART_PLAYBACK_LAB_CANDIDATE_DURATION": "120"]
        XCTAssertNotNil(PlaybackLabLaunchRequest.candidateConfiguration(environment: valid))
        let ordinary = PlaybackLabLaunchRequest.makeRequest(environment: valid)
        XCTAssertNil(ordinary?.compatibilityFallbackRequestLoader, "Manual lab admission must not enable automatic adaptation")
        for key in valid.keys {
            var missing = valid
            missing.removeValue(forKey: key)
            XCTAssertNil(PlaybackLabLaunchRequest.candidateConfiguration(environment: missing), key)
        }
        for (key, value) in [("NASTART_PLAYBACK_LAB_CANDIDATE", "0"),
            ("NASTART_PLAYBACK_LAB_CANDIDATE_DURATION", "NaN"),
            ("NASTART_PLAYBACK_LAB_CANDIDATE_DURATION", "-1"),
            ("NASTART_PLAYBACK_LAB_CANDIDATE_URL", "http://127.0.0.1:8124/candidate.m3u8"),
            ("NASTART_PLAYBACK_LAB_CANDIDATE_URL", "http://another.test:8123/candidate.m3u8"),
            ("NASTART_PLAYBACK_LAB_CANDIDATE_URL", "http://user:password@127.0.0.1:8123/candidate.m3u8"),
            ("NASTART_PLAYBACK_LAB_CANDIDATE_URL", "file:///candidate.m3u8")] {
            var invalid = valid
            invalid[key] = value
            XCTAssertNil(PlaybackLabLaunchRequest.candidateConfiguration(environment: invalid), value)
        }
    }

    @MainActor
    func testManualCandidateLabResumeFractionReachesGreenfieldAsAbsoluteTime() throws {
        let environment = ["NASTART_PLAYBACK_LAB_CANDIDATE": "1",
            "NASTART_PLAYBACK_LAB_ARCHITECTURE": "greenfield",
            "NASTART_PLAYBACK_LAB_URL": "http://127.0.0.1:8123/original.mkv",
            "NASTART_PLAYBACK_LAB_CANDIDATE_URL": "http://127.0.0.1:8123/candidate.m3u8",
            "NASTART_PLAYBACK_LAB_CANDIDATE_DURATION": "7524.768",
            "NASTART_PLAYBACK_LAB_POSITION": String(4000 / 7524.768),
            "NASTART_PLAYBACK_LAB_SOURCE": "jellyfin"]
        let request = try XCTUnwrap(PlaybackLabLaunchRequest.makeRequest(environment: environment))
        let launch = request.greenfieldPlaybackLaunchRequest()
        XCTAssertEqual(try XCTUnwrap(launch.duration), 7524.768, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(launch.intent.preferredStartTime), 4000, accuracy: 0.001)
        XCTAssertNil(request.compatibilityFallbackRequestLoader,
            "Supplying manual diagnostic timing must not enable automatic retry")
    }

    @MainActor
    func testManualCandidateLabDoesNotTakeDurationFromUnadmittedConfiguration() throws {
        let valid = ["NASTART_PLAYBACK_LAB_CANDIDATE": "1",
            "NASTART_PLAYBACK_LAB_ARCHITECTURE": "greenfield",
            "NASTART_PLAYBACK_LAB_URL": "http://127.0.0.1:8123/original.mkv",
            "NASTART_PLAYBACK_LAB_CANDIDATE_URL": "http://127.0.0.1:8123/candidate.m3u8",
            "NASTART_PLAYBACK_LAB_CANDIDATE_DURATION": "120",
            "NASTART_PLAYBACK_LAB_POSITION": "0.5",
            "NASTART_PLAYBACK_LAB_SOURCE": "jellyfin"]
        for (key, value) in [("NASTART_PLAYBACK_LAB_CANDIDATE", "0"),
            ("NASTART_PLAYBACK_LAB_CANDIDATE_DURATION", "NaN"),
            ("NASTART_PLAYBACK_LAB_CANDIDATE_DURATION", "0"),
            ("NASTART_PLAYBACK_LAB_CANDIDATE_URL", "http://another.test:8123/candidate.m3u8")] {
            var environment = valid
            environment[key] = value
            let request = try XCTUnwrap(PlaybackLabLaunchRequest.makeRequest(environment: environment))
            XCTAssertNil(request.totalDurationSeconds, key)
            XCTAssertNil(request.greenfieldPlaybackLaunchRequest().intent.preferredStartTime, key)
            XCTAssertNil(request.compatibilityFallbackRequestLoader, key)
        }
    }

    @MainActor
    func testAutomaticRetryLabAdmissionIsExplicitSameOriginAndDoesNotEnableManualTrigger() {
        let valid = ["NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY": "1",
            "NASTART_PLAYBACK_LAB_ARCHITECTURE": "greenfield",
            "NASTART_PLAYBACK_LAB_URL": "http://127.0.0.1:8123/original.mkv",
            "NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_URL": "http://127.0.0.1:8123/candidate.m3u8",
            "NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_DURATION": "90"]
        XCTAssertNotNil(PlaybackLabLaunchRequest.automaticRetryConfiguration(environment: valid))
        XCTAssertNil(PlaybackLabLaunchRequest.candidateConfiguration(environment: valid))
        let request = PlaybackLabLaunchRequest.makeRequest(environment: valid)
        XCTAssertNotNil(request?.compatibilityFallbackRequestLoader)
        XCTAssertEqual(request?.streamBitrateCeiling, 20_000_000)
        XCTAssertEqual(request?.selectedQualityID, "auto")
        for key in valid.keys {
            var missing = valid
            missing.removeValue(forKey: key)
            XCTAssertNil(PlaybackLabLaunchRequest.automaticRetryConfiguration(environment: missing), key)
            if key == "NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY" {
                XCTAssertNil(PlaybackLabLaunchRequest.makeRequest(environment: missing)?.compatibilityFallbackRequestLoader)
            } else { XCTAssertNil(PlaybackLabLaunchRequest.makeRequest(environment: missing), key) }
        }
        for (key, value) in [("NASTART_PLAYBACK_LAB_PROXY", "1"),
            ("NASTART_PLAYBACK_LAB_CANDIDATE", "1"),
            ("NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_DURATION", "infinity"),
            ("NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_URL", "http://127.0.0.1:8124/candidate.m3u8"),
            ("NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_URL", "https://127.0.0.1:8123/candidate.m3u8"),
            ("NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_URL", "http://user:secret@127.0.0.1:8123/candidate.m3u8"),
            ("NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_URL", "file:///candidate.m3u8")] {
            var invalid = valid
            invalid[key] = value
            XCTAssertNil(PlaybackLabLaunchRequest.makeRequest(environment: invalid), key)
        }
    }

    @MainActor
    func testAutomaticRetryLabRealRequestContinuationSurvivesResourceReleaseAndUsesNewTrace() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let upstream = try XCTUnwrap(server.url)
        let originalTrace = UUID().uuidString
        let environment = ["NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY": "1",
            "NASTART_PLAYBACK_LAB_ARCHITECTURE": "greenfield",
            "NASTART_PLAYBACK_LAB_URL": upstream.absoluteString,
            "NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_URL": upstream.absoluteString,
            "NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_DURATION": "4"]
        for source in ["jellyfin", "file"] {
            var env = environment
            env["NASTART_PLAYBACK_LAB_SOURCE"] = source
            PlaybackRecentThroughputStore.shared.record(traceID: originalTrace, bytes: 4_756_532,
                seconds: 1, backpressureSeconds: 0, now: ProcessInfo.processInfo.systemUptime)
            let original = try XCTUnwrap(PlaybackLabLaunchRequest.makeRequest(environment: env, traceID: originalTrace))
            let loader = try XCTUnwrap(original.compatibilityFallbackRequestLoader)
            let firstLoaded = await loader(nil)
            let first = try XCTUnwrap(firstLoaded)
            XCTAssertEqual(first.streamBitrateCeiling, 12_000_000)
            XCTAssertEqual(first.source, source == "jellyfin" ? .jellyfin : .dsmFile)
            let trace = try XCTUnwrap(first.playbackTraceID)
            XCTAssertNotEqual(trace, originalTrace)
            PlaybackRecentThroughputStore.shared.record(traceID: trace, bytes: 6_053_412,
                seconds: 18.725, backpressureSeconds: 0, now: ProcessInfo.processInfo.systemUptime)
            var retry = PlaybackFailedCandidateRetry<(MediaPlaybackRuntimeState?) async -> MediaPlaybackRequest?>(sourceID: original.id)
            let ticket = retry.begin()
            XCTAssertTrue(retry.failed(ticket: ticket, currentSourceID: original.id,
                cancelled: false, candidateStillCurrent: true, continuation: first.compatibilityFallbackRequestLoader))
            first.playbackTracker?.releasePreparedResources()
            first.playbackTracker?.releasePreparedResources()
            let secondLoaded = await retry.loader(or: loader)(nil)
            let second = try XCTUnwrap(secondLoaded)
            defer { second.playbackTracker?.releasePreparedResources() }
            XCTAssertEqual(second.streamBitrateCeiling, 1_000_000)
            XCTAssertNotEqual(second.playbackTraceID, trace)
            XCTAssertNil(second.localResumeKey)
            XCTAssertEqual(server.requestCount, 0, "Neither negotiation nor retiring the first route may fetch media")
            let (_, response) = try await URLSession.shared.data(from: first.url)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
            XCTAssertTrue(AuthenticatedMediaStreamProxy.shared.isRegisteredPlaylistRoot(second.url))
            XCTAssertEqual(server.requestCount, 0)
        }
    }

    @MainActor
    func testAutomaticRetryLabCancelledNegotiationReturnsNoPreparedRoute() async throws {
        let env = ["NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY": "1",
            "NASTART_PLAYBACK_LAB_ARCHITECTURE": "greenfield",
            "NASTART_PLAYBACK_LAB_URL": "http://127.0.0.1:8123/original.mkv",
            "NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_URL": "http://127.0.0.1:8123/candidate.m3u8",
            "NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_DURATION": "90"]
        let original = try XCTUnwrap(PlaybackLabLaunchRequest.makeRequest(environment: env))
        let loader = try XCTUnwrap(original.compatibilityFallbackRequestLoader)
        let task = Task { @MainActor in await loader(nil) }
        task.cancel()
        let result = await task.value
        XCTAssertNil(result)
    }

    @MainActor
    func testCandidateLabRegistersColdRouteAndReleasesWithoutFetchingMedia() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let url = try XCTUnwrap(server.url)
        let environment = ["NASTART_PLAYBACK_LAB_CANDIDATE": "1",
            "NASTART_PLAYBACK_LAB_ARCHITECTURE": "greenfield",
            "NASTART_PLAYBACK_LAB_URL": url.absoluteString,
            "NASTART_PLAYBACK_LAB_CANDIDATE_URL": url.absoluteString,
            "NASTART_PLAYBACK_LAB_CANDIDATE_DURATION": "4"]
        let request = try await PlaybackLabLaunchRequest.makeCandidateRequest(environment: environment)
        XCTAssertTrue(AuthenticatedMediaStreamProxy.shared.isRegisteredPlaylistRoot(request.url))
        XCTAssertEqual(request.totalDurationSeconds, 4)
        XCTAssertEqual(server.requestCount, 0, "The real warmup, not the lab factory, must own complete-manifest preparation")
        request.playbackTracker?.releasePreparedResources()
        request.playbackTracker?.releasePreparedResources()
        let (_, response) = try await URLSession.shared.data(from: request.url)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
        XCTAssertEqual(server.requestCount, 0)
    }

    @MainActor
    func testPlaybackLabProxyRequiresExplicitFlagAndPreservesColdRequest() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let upstream = try XCTUnwrap(server.url)
        var environment = ["NASTART_PLAYBACK_LAB_URL": upstream.absoluteString,
                           "NASTART_PLAYBACK_LAB_SOURCE": "jellyfin",
                           "NASTART_PLAYBACK_LAB_POSITION": "0.25"]
        XCTAssertFalse(PlaybackLabLaunchRequest.usesProxy(environment: environment))
        XCTAssertEqual(PlaybackLabLaunchRequest.makeRequest(environment: environment)?.url, upstream)
        do {
            _ = try await PlaybackLabLaunchRequest.makeProxiedRequest(environment: environment)
            XCTFail("A diagnostic proxy must require explicit opt-in")
        } catch { XCTAssertEqual((error as? URLError)?.code, .unsupportedURL) }
        environment["NASTART_PLAYBACK_LAB_PROXY"] = "1"
        let request = try await PlaybackLabLaunchRequest.makeProxiedRequest(environment: environment)
        XCTAssertEqual(server.requestCount, 0, "Cold preparation must not fetch a manifest or segment")
        XCTAssertNotEqual(request.url, upstream)
        XCTAssertEqual(request.url.host, "127.0.0.1")
        XCTAssertEqual(request.externalHandoffResource?.url, upstream)
        XCTAssertEqual(request.initialPosition, 0.25)
        XCTAssertEqual(request.source, .jellyfin)
        request.playbackTracker?.releasePreparedResources()
        request.playbackTracker?.releasePreparedResources()
        let (_, response) = try await URLSession.shared.data(from: request.url)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
        XCTAssertEqual(server.requestCount, 0)
    }

    @MainActor
    func testPlaybackLabProxyPrewarmOnlyFetchesManifestsAndReleaseRevokesChildren() async throws {
        let server = try PlaybackRangeTestServer(
            playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n",
            masterPlaylist: "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500000\nmain.m3u8\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let environment = ["NASTART_PLAYBACK_LAB_URL": try XCTUnwrap(server.url).absoluteString,
                           "NASTART_PLAYBACK_LAB_PROXY": "1", "NASTART_PLAYBACK_LAB_PREWARM": "1"]
        let request = try await PlaybackLabLaunchRequest.makeProxiedRequest(environment: environment)
        defer { request.playbackTracker?.releasePreparedResources() }
        XCTAssertEqual(server.requestCount, 2)
        XCTAssertFalse(server.receivedRequests.contains { $0.contains(".ts ") })
        let child = try await firstRewrittenHLSChild(request.url)
        XCTAssertEqual(server.requestCount, 2, "A validated single-variant VOD master and media must both be reused")
        request.playbackTracker?.releasePreparedResources()
        let (_, response) = try await URLSession.shared.data(from: child)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
    }

    @MainActor
    func testPlaybackLabProxyCancelledPrewarmCancelsItsPendingTransfer() async throws {
        let server = try PlaybackRangeTestServer(
            playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n", holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let trace = "LAB-CANCEL-\(UUID().uuidString)"
        let environment = ["NASTART_PLAYBACK_LAB_URL": try XCTUnwrap(server.url).absoluteString,
                           "NASTART_PLAYBACK_LAB_PROXY": "1", "NASTART_PLAYBACK_LAB_PREWARM": "1"]
        let task = Task { try await PlaybackLabLaunchRequest.makeProxiedRequest(environment: environment, traceID: trace) }
        try await awaitProxyFixture { server.requestCount == 1 }
        task.cancel()
        do {
            let request = try await task.value
            request.playbackTracker?.releasePreparedResources()
            XCTFail("Cancelled preparation must not return a live route")
        } catch { XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled) }
        try await awaitProxyFixture {
            self.proxyFixtureDetails(trace).contains { $0.contains("stage=upstreamCancellationRequested") }
        }
        server.releaseResponses()
        XCTAssertEqual(server.requestCount, 1)
    }

    func testJellyfinOutputCorrelationUsesDotNetUnicodeGuidVectorWithoutLoggingInputs() {
        var request = URLRequest(url: URL(string: "https://example.com/0.ts?DeviceId=device-fixture&PlaySessionId=session-fixture&ApiKey=secret-fixture")!)
        request.setValue("Nastart/1 CFNetwork/1 Darwin/1", forHTTPHeaderField: "User-Agent")
        let fields = PlaybackJellyfinOutputDiagnostics.fields(
            mediaPath: "/media/电影😀.mkv", request: request, redirectCount: 0)
        XCTAssertEqual(fields["jellyfinOutputKeyCandidate"], "48d22d3a0db54b7ceb4eac3f7bd01537")
        XCTAssertEqual(fields.count, 2)
        for value in fields.values {
            for secret in ["secret-fixture", "device-fixture", "session-fixture", "/media/", "CFNetwork"] {
                XCTAssertFalse(value.contains(secret))
            }
        }
        request.setValue("Different agent", forHTTPHeaderField: "User-Agent")
        XCTAssertNotEqual(PlaybackJellyfinOutputDiagnostics.fields(
            mediaPath: "/media/电影😀.mkv", request: request, redirectCount: 0)["jellyfinOutputKeyCandidate"], fields["jellyfinOutputKeyCandidate"])
    }

    func testJellyfinOutputCorrelationRejectsAbsentOrAmbiguousIdentityAndParams() {
        for query in ["DeviceId=d", "PlaySessionId=s", "DeviceId=&PlaySessionId=s",
                      "DeviceId=d&deviceid=other&PlaySessionId=s",
                      "DeviceId=d&PlaySessionId=s&playsessionid=other",
                      "DeviceId=d&PlaySessionId=s&Params=one&params=two"] {
            var request = URLRequest(url: URL(string: "https://example.com/0.ts?" + query)!)
            request.setValue("agent", forHTTPHeaderField: "User-Agent")
            XCTAssertEqual(PlaybackJellyfinOutputDiagnostics.fields(
                mediaPath: "/media/movie.mkv", request: request, redirectCount: 0)["jellyfinOutputKeyCandidate"], "unknown")
        }
    }

    func testJellyfinOutputCorrelationPackedIdentityFollowsServerOverrideAndBlankRules() throws {
        func fields(device: String?, session: String?, packed: [String]?) throws -> [String: String] {
            var url = URLComponents(string: "https://example.com/0.ts")!
            var items: [URLQueryItem] = []
            if let device { items.append(URLQueryItem(name: "DeviceId", value: device)) }
            if let session { items.append(URLQueryItem(name: "PlaySessionId", value: session)) }
            if let packed { items.append(URLQueryItem(name: "Params", value: packed.joined(separator: ";"))) }
            url.queryItems = items
            var request = URLRequest(url: try XCTUnwrap(url.url))
            request.setValue("agent", forHTTPHeaderField: "User-Agent")
            return PlaybackJellyfinOutputDiagnostics.fields(mediaPath: "/media/movie.mkv", request: request, redirectCount: 0)
        }
        let explicit = try fields(device: "device", session: "session", packed: nil)
        var slots = Array(repeating: "", count: 21)
        slots[6] = "1"; slots[8] = "2000000"
        XCTAssertEqual(try fields(device: "device", session: "session", packed: slots), explicit)
        slots[1] = " \t"; slots[20] = "\n"
        XCTAssertEqual(try fields(device: "device", session: "session", packed: slots), explicit)
        slots[1] = "device"; slots[20] = "session"
        XCTAssertEqual(try fields(device: "old-device", session: "old-session", packed: slots), explicit)
        XCTAssertEqual(try fields(device: nil, session: nil, packed: slots), explicit)
        slots[1] = " device "
        XCTAssertNotEqual(try fields(device: "device", session: "session", packed: slots), explicit)
        XCTAssertEqual(try fields(device: nil, session: nil, packed: ["unused"])["jellyfinOutputKeyCandidate"], "unknown")
    }

    func testJellyfinOutputCorrelationKeepsMissingHeadersAndRedirectsUnknown() {
        var request = URLRequest(url: URL(string: "https://example.com/0.ts?deviceid=d&playsessionid=s")!)
        XCTAssertEqual(PlaybackJellyfinOutputDiagnostics.fields(
            mediaPath: "/media/movie.mkv", request: request, redirectCount: 0)["jellyfinOutputKeyCandidate"], "unknown")
        XCTAssertEqual(PlaybackJellyfinOutputDiagnostics.fields(
            mediaPath: "/media/movie.mkv", request: request, redirectCount: 0)["jellyfinOutputKeyBasis"], "missingRequestUserAgent")
        request.setValue("agent", forHTTPHeaderField: "User-Agent")
        XCTAssertEqual(PlaybackJellyfinOutputDiagnostics.fields(
            mediaPath: "/media/movie.mkv", request: request, redirectCount: 1)["jellyfinOutputKeyCandidate"], "unknown")
        XCTAssertEqual(PlaybackJellyfinOutputDiagnostics.fields(
            mediaPath: "/media/movie.mkv", request: request, redirectCount: 1)["jellyfinOutputKeyBasis"], "redirectedRequest")
        XCTAssertTrue(PlaybackJellyfinOutputDiagnostics.fields(mediaPath: nil, request: request, redirectCount: 0).isEmpty)
        XCTAssertTrue(PlaybackJellyfinOutputDiagnostics.fields(mediaPath: "", request: request, redirectCount: 0).isEmpty)
    }

    func testJellyfinOutputCorrelationSelectsEncoderPathOnlyWithItsProtocol() {
        XCTAssertEqual(PlaybackJellyfinOutputDiagnostics.mediaPath(
            path: "/source", encoderPath: "/encoder", hasEncoderProtocol: true), "/encoder")
        XCTAssertEqual(PlaybackJellyfinOutputDiagnostics.mediaPath(
            path: "/source", encoderPath: "/encoder", hasEncoderProtocol: false), "/source")
        XCTAssertEqual(PlaybackJellyfinOutputDiagnostics.mediaPath(
            path: "/source", encoderPath: "", hasEncoderProtocol: true), "/source")
        XCTAssertNil(PlaybackJellyfinOutputDiagnostics.mediaPath(path: nil, encoderPath: nil, hasEncoderProtocol: false))
    }

    func testDownshiftAttemptBudgetRecoveredPredictionsPreserveTwoRealRecoveryAttempts() throws {
        var budget = PlaybackDownshiftAttemptBudget()
        for _ in 0..<2 {
            let ticket = try XCTUnwrap(budget.begin(staticPrediction: true))
            XCTAssertTrue(budget.withdrawRecoveredPrediction(ticket: ticket))
            XCTAssertEqual(budget.attempts, 0)
        }
        XCTAssertFalse(budget.canWithdrawStaticPrediction)
        XCTAssertNotNil(budget.begin(staticPrediction: false))
        XCTAssertNotNil(budget.begin(staticPrediction: false))
        XCTAssertNil(budget.begin(staticPrediction: false))
        XCTAssertEqual(budget.attempts, 2)
    }

    func testDownshiftAttemptBudgetRejectsDuplicateAndStaleRefunds() throws {
        var budget = PlaybackDownshiftAttemptBudget()
        let first = try XCTUnwrap(budget.begin(staticPrediction: true))
        XCTAssertTrue(budget.withdrawRecoveredPrediction(ticket: first))
        XCTAssertFalse(budget.withdrawRecoveredPrediction(ticket: first))
        let second = try XCTUnwrap(budget.begin(staticPrediction: true))
        XCTAssertFalse(budget.withdrawRecoveredPrediction(ticket: first))
        XCTAssertEqual(budget.attempts, 1)
        XCTAssertTrue(budget.withdrawRecoveredPrediction(ticket: second))
    }

    func testDownshiftAttemptBudgetNeverRefundsReactiveOrUnrecoveredFailures() throws {
        var budget = PlaybackDownshiftAttemptBudget()
        let reactive = try XCTUnwrap(budget.begin(staticPrediction: false))
        XCTAssertFalse(budget.withdrawRecoveredPrediction(ticket: reactive))
        let prediction = try XCTUnwrap(budget.begin(staticPrediction: true))
        XCTAssertEqual(budget.attempts, 2)
        XCTAssertNil(budget.begin(staticPrediction: true))
        XCTAssertTrue(budget.withdrawRecoveredPrediction(ticket: prediction))
        XCTAssertEqual(budget.attempts, 1)
    }

    func testDownshiftAttemptBudgetCapsTotalPreparationsAtFour() throws {
        var budget = PlaybackDownshiftAttemptBudget()
        for _ in 0..<2 {
            let ticket = try XCTUnwrap(budget.begin(staticPrediction: true))
            XCTAssertTrue(budget.withdrawRecoveredPrediction(ticket: ticket))
        }
        for _ in 0..<2 {
            let ticket = try XCTUnwrap(budget.begin(staticPrediction: true))
            XCTAssertFalse(budget.withdrawRecoveredPrediction(ticket: ticket))
        }
        XCTAssertNil(budget.begin(staticPrediction: true))
        XCTAssertEqual(budget.recoveredWithdrawals, 2)
    }

    func testPredictiveRecoveryRecordedCapacityReturnWithdrawsOnlyAfterStableProgress() {
        var policy = PlaybackPredictiveRecoveryPolicy(startedAt: 10.897)
        let times = [12.986062, 14.032702, 15.050264]
        let clocks = [7.717, 8.816, 9.829]
        let reserves = [14.854, 15.5621666667, 14.8846666667]
        let demands = [7_276_730, 12_335_887, 16_873_677]
        for i in times.indices {
            XCTAssertEqual(policy.sample(now: times[i], eligible: true,
                currentSeconds: clocks[i], aheadSeconds: reserves[i], targetSeconds: 4,
                sourceBitrate: 57_416_722, runtimeDemand: demands[i], rate: 1,
                capacity: 46_605_599, evidenceUptime: 12.98), i == 2)
        }
    }

    func testPredictiveRecoveryRetainsCandidateForInsufficientDeliveryOrDrainingReserve() {
        for scenario in ["lowCapacity", "draining", "lowReserve", "peakDemand", "doubleRate"] {
            var policy = PlaybackPredictiveRecoveryPolicy(startedAt: 10)
            for i in 0..<4 {
                let ahead = scenario == "draining" ? 10 - Double(i) : scenario == "lowReserve" ? 4.1 : 12
                XCTAssertFalse(policy.sample(now: 11 + Double(i), eligible: true,
                    currentSeconds: Double(i + 1), aheadSeconds: ahead, targetSeconds: 4,
                    sourceBitrate: 57_416_722,
                    runtimeDemand: scenario == "peakDemand" ? 40_000_000 : 8_000_000,
                    rate: scenario == "doubleRate" ? 2 : 1,
                    capacity: scenario == "lowCapacity" ? 34_059_542 : 46_605_599,
                    evidenceUptime: 11), scenario)
            }
        }
    }

    func testPredictiveRecoveryRejectsMissingStaleFutureAndPreRequestCapacity() {
        let evidences: [Double?] = [nil, 9.9, 3, 100]
        for evidence in evidences {
            var policy = PlaybackPredictiveRecoveryPolicy(startedAt: 10)
            for i in 0..<4 {
                XCTAssertFalse(policy.sample(now: 11 + Double(i), eligible: true,
                    currentSeconds: Double(i + 1), aheadSeconds: 12, targetSeconds: 4,
                    sourceBitrate: 57_416_722, runtimeDemand: 8_000_000, rate: 1,
                    capacity: 46_605_599, evidenceUptime: evidence))
            }
        }
        var expired = PlaybackPredictiveRecoveryPolicy(startedAt: 10)
        XCTAssertFalse(expired.sample(now: 17.01, eligible: true, currentSeconds: 1,
            aheadSeconds: 12, targetSeconds: 4, sourceBitrate: 57_416_722,
            runtimeDemand: 8_000_000, rate: 1, capacity: 46_605_599, evidenceUptime: 11))
    }

    func testPredictiveRecoveryDoesNotCountFastPollsPauseOrLongEvidenceGaps() {
        var policy = PlaybackPredictiveRecoveryPolicy(startedAt: 10)
        func sample(_ time: Double, clock: Double, eligible: Bool = true) -> Bool {
            policy.sample(now: time, eligible: eligible, currentSeconds: clock,
                aheadSeconds: 12, targetSeconds: 4, sourceBitrate: 57_416_722,
                runtimeDemand: 8_000_000, rate: 1, capacity: 46_605_599,
                evidenceUptime: time)
        }
        XCTAssertFalse(sample(11, clock: 1))
        XCTAssertFalse(sample(11.1, clock: 1.1))
        XCTAssertFalse(sample(11.2, clock: 1.2))
        XCTAssertFalse(sample(12, clock: 2, eligible: false))
        XCTAssertFalse(sample(13, clock: 2))
        XCTAssertFalse(sample(14, clock: 2))
        XCTAssertFalse(sample(18, clock: 3))
        XCTAssertFalse(sample(19, clock: 4))
        XCTAssertTrue(sample(20, clock: 5))
    }

    func testPredictiveRecoveryRejectsInvalidClocksTargetsAndRates() {
        for scenario in ["nanTime", "nanClock", "negativeReserve", "zeroTarget", "nanRate", "zeroDemand"] {
            var policy = PlaybackPredictiveRecoveryPolicy(startedAt: 10)
            for i in 0..<3 {
                XCTAssertFalse(policy.sample(now: scenario == "nanTime" ? .nan : 11 + Double(i),
                    eligible: true, currentSeconds: scenario == "nanClock" ? .nan : Double(i + 1),
                    aheadSeconds: scenario == "negativeReserve" ? -1 : 12,
                    targetSeconds: scenario == "zeroTarget" ? 0 : 4,
                    sourceBitrate: 57_416_722, runtimeDemand: scenario == "zeroDemand" ? 0 : 8_000_000,
                    rate: scenario == "nanRate" ? .nan : 1,
                    capacity: 46_605_599, evidenceUptime: 11), scenario)
            }
        }
    }

    func testPredictiveRecoveryRestartsConfirmationWhenBufferTargetOrRateChanges() {
        for mode in ["target", "rate"] {
            var policy = PlaybackPredictiveRecoveryPolicy(startedAt: 10)
            for i in 0..<5 {
                XCTAssertEqual(policy.sample(now: 11 + Double(i), eligible: true,
                    currentSeconds: Double(i + 1), aheadSeconds: 12,
                    targetSeconds: mode == "target" && i >= 2 ? 6 : 4,
                    sourceBitrate: 57_416_722, runtimeDemand: 8_000_000,
                    rate: mode == "rate" && i >= 2 ? 0.75 : 1,
                    capacity: 46_605_599, evidenceUptime: 11), i == 4, mode)
            }
        }
    }

    func testThroughputRecoveryEvidenceUsesOldestOfThreeCompletionsOrNewBodyEpoch() throws {
        let store = PlaybackRecentThroughputStore()
        for time in [8.0, 10.0, 12.0] {
            store.record(traceID: "A", bytes: 8_000_000, seconds: 1,
                backpressureSeconds: 0, now: time)
        }
        XCTAssertEqual(try XCTUnwrap(store.estimateSample(traceID: "A", now: 13)).predictionEvidenceUptime, 8)
        store.record(traceID: "A", bytes: 8_000_000, seconds: 1, backpressureSeconds: 0, now: 14)
        XCTAssertEqual(try XCTUnwrap(store.estimateSample(traceID: "A", now: 14)).predictionEvidenceUptime, 10)
        store.recordQualifiedBodyWindow(traceID: "A", bitrate: 46_605_599, now: 15)
        XCTAssertEqual(try XCTUnwrap(store.estimateSample(traceID: "A", now: 16)).predictionEvidenceUptime, 15)
        XCTAssertNil(store.estimateSample(traceID: "A", now: 21.1))
        XCTAssertNil(store.estimateSample(traceID: "other", now: 16))
    }

    @MainActor
    func testOriginalRaceFastFileStationCancelsReusedJellyfinProbe() async {
        let slowStarted = expectation(description: "original probe started")
        var slowCancelled = false
        let warmup = Task<URL?, Never> { @MainActor in
            slowStarted.fulfill()
            do { try await Task.sleep(nanoseconds: 8_000_000_000) }
            catch { slowCancelled = true; return nil }
            XCTFail("A usable file original must not wait for the Jellyfin timeout")
            return nil
        }
        await fulfillment(of: [slowStarted], timeout: 1)
        let url = URL(string: "https://file.example.test/original")!
        let start = ProcessInfo.processInfo.systemUptime
        let result = await PlaybackOriginalRouteRace.resolve(
            jellyfin: { await PlaybackOriginalRouteRace.consume(warmup) }, fileStation: { url })
        XCTAssertEqual(result?.url, url)
        XCTAssertEqual(result?.source, .fileStation)
        XCTAssertTrue(slowCancelled)
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 1)
    }

    @MainActor
    func testOriginalRaceFastJellyfinCancelsFileProbeAndDoesNotWait() async {
        let started = expectation(description: "file probe started")
        var cancelled = false
        let url = URL(string: "https://jellyfin.example.test/original")!
        let task = Task { @MainActor in
            await PlaybackOriginalRouteRace.resolve(jellyfin: {
                await self.fulfillment(of: [started], timeout: 1)
                return url
            }, fileStation: {
                started.fulfill()
                do { try await Task.sleep(nanoseconds: 8_000_000_000) }
                catch { cancelled = true }
                return nil
            })
        }
        let start = ProcessInfo.processInfo.systemUptime
        let result = await task.value
        XCTAssertEqual(result?.source, .jellyfin)
        XCTAssertEqual(result?.url, url)
        XCTAssertTrue(cancelled)
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 1.5)
    }

    @MainActor
    func testOriginalRaceFailedFirstResultDoesNotDiscardOtherOriginal() async {
        let url = URL(string: "https://media.example.test/original")!
        for jellyfinSucceeds in [true, false] {
            let result = await PlaybackOriginalRouteRace.resolve(jellyfin: {
                if jellyfinSucceeds { try? await Task.sleep(nanoseconds: 20_000_000); return url }
                return nil
            }, fileStation: {
                if !jellyfinSucceeds { try? await Task.sleep(nanoseconds: 20_000_000); return url }
                return nil
            })
            XCTAssertEqual(result?.url, url)
            XCTAssertEqual(result?.source, jellyfinSucceeds ? .jellyfin : .fileStation)
        }
        let absent = await PlaybackOriginalRouteRace.resolve(jellyfin: { nil }, fileStation: { nil })
        XCTAssertNil(absent)
        let noDSM = await PlaybackOriginalRouteRace.resolve(jellyfin: { url })
        XCTAssertEqual(noDSM?.source, .jellyfin)
    }

    @MainActor
    func testOriginalRaceParentCancellationReleasesBothAndRejectsLateURLs() async {
        let started = expectation(description: "both original probes started")
        started.expectedFulfillmentCount = 2
        var cancelled = 0
        let lateURL = URL(string: "https://media.example.test/late")!
        let probe: @MainActor () async -> URL? = {
            started.fulfill()
            do { try await Task.sleep(nanoseconds: 8_000_000_000) }
            catch { cancelled += 1 }
            return lateURL
        }
        let task = Task { @MainActor in
            await PlaybackOriginalRouteRace.resolve(jellyfin: probe, fileStation: probe)
        }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        let result = await task.value
        XCTAssertNil(result)
        XCTAssertEqual(cancelled, 2)
        var calls = 0
        let alreadyCancelled = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return await PlaybackOriginalRouteRace.resolve(jellyfin: { calls += 1; return lateURL })
        }
        let absent = await alreadyCancelled.value
        XCTAssertNil(absent)
        XCTAssertEqual(calls, 0)
    }

    func testFilePublicPriorityRequiresCellularAndConfiguredHTTPSCandidates() {
        let publicURL = URL(string: "https://media.example.test/file?sid=own")!
        XCTAssertTrue(PlaybackFileOriginalRouteSelection.prefersPublicFirst(
            networkKey: "cellular", remoteCandidates: [publicURL]))
        for key in ["wifi", "unknown", "offline"] {
            XCTAssertFalse(PlaybackFileOriginalRouteSelection.prefersPublicFirst(
                networkKey: key, remoteCandidates: [publicURL]))
        }
        for urls in [[], [URL(string: "http://media.example.test/file")!],
                     [URL(string: "https://192.168.1.2/file")!],
                     [publicURL, URL(string: "http://media.example.test/file")!],
                     [URL(string: "https://user:password@media.example.test/file")!]] {
            XCTAssertFalse(PlaybackFileOriginalRouteSelection.prefersPublicFirst(
                networkKey: "cellular", remoteCandidates: urls))
        }
    }

    @MainActor
    func testFilePublicSuccessDoesNotWaitForPrivateProbes() async {
        let url = URL(string: "https://media.example.test/file")!
        var calls: [String] = []
        let result = await PlaybackFileOriginalRouteSelection.resolve(publicFirst: true,
            isCurrent: { true }, local: { calls.append("local"); return nil },
            remote: { calls.append("remote"); return url })
        XCTAssertEqual(result, url)
        XCTAssertEqual(calls, ["remote"])
    }

    @MainActor
    func testFileFailedPublicProbeRetainsPrivateVPNFallbackWithoutRetryingPublic() async {
        let url = URL(string: "https://192.168.1.2/file")!
        var calls: [String] = []
        let result = await PlaybackFileOriginalRouteSelection.resolve(publicFirst: true,
            isCurrent: { true }, local: { calls.append("local"); return url },
            remote: { calls.append("remote"); return nil })
        XCTAssertEqual(result, url)
        XCTAssertEqual(calls, ["remote", "local"])
    }

    @MainActor
    func testFileWiFiKeepsPrivatePriorityAndPublicFallback() async {
        let lan = URL(string: "http://192.168.1.2/file")!
        let publicURL = URL(string: "https://media.example.test/file")!
        for localSucceeds in [true, false] {
            var calls: [String] = []
            let result = await PlaybackFileOriginalRouteSelection.resolve(publicFirst: false,
                isCurrent: { true }, local: { calls.append("local"); return localSucceeds ? lan : nil },
                remote: { calls.append("remote"); return publicURL })
            XCTAssertEqual(result, localSucceeds ? lan : publicURL)
            XCTAssertEqual(calls, localSucceeds ? ["local"] : ["local", "remote"])
        }
    }

    @MainActor
    func testFileLocalRaceStartsRangeBeforeOptionalLookupFinishes() async {
        let lookupStarted = expectation(description: "optional same-file lookup started")
        var lookupCancelled = false
        var publicCalls = 0
        let url = URL(string: "http://192.168.1.2/verified-file")!
        let startedAt = ProcessInfo.processInfo.systemUptime
        let result = await PlaybackFileOriginalRouteSelection.resolve(publicFirst: false,
            isCurrent: { true }, local: {
                await PlaybackOriginalRouteRace.resolve(jellyfin: {
                    lookupStarted.fulfill()
                    do { try await Task.sleep(nanoseconds: 8_000_000_000) }
                    catch { lookupCancelled = true }
                    return nil
                }, fileStation: {
                    await self.fulfillment(of: [lookupStarted], timeout: 1)
                    return url
                })?.url
            }, remote: { publicCalls += 1; return nil })
        XCTAssertEqual(result, url)
        XCTAssertTrue(lookupCancelled)
        XCTAssertEqual(publicCalls, 0)
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - startedAt, 1.5)
    }

    @MainActor
    func testFileLocalRaceRejectsWinnerAfterPreparationOwnershipChanges() async {
        let lookupStarted = expectation(description: "optional lookup started")
        var lookupCancelled = false
        var current = true
        var publicCalls = 0
        let result = await PlaybackFileOriginalRouteSelection.resolve(publicFirst: false,
            isCurrent: { current }, local: {
                await PlaybackOriginalRouteRace.resolve(jellyfin: {
                    lookupStarted.fulfill()
                    do { try await Task.sleep(nanoseconds: 8_000_000_000) }
                    catch { lookupCancelled = true }
                    return URL(string: "http://192.168.1.2/retired-jellyfin-file")
                }, fileStation: {
                    await self.fulfillment(of: [lookupStarted], timeout: 1)
                    current = false
                    return URL(string: "http://192.168.1.2/retired-dsm-file")
                })?.url
            }, remote: { publicCalls += 1; return nil })
        XCTAssertNil(result)
        XCTAssertTrue(lookupCancelled)
        XCTAssertEqual(publicCalls, 0)
    }

    @MainActor
    func testFilePreparationOwnershipRejectsLateResultAndStopsFallback() async {
        for publicFirst in [true, false] {
            var current = true
            var calls = 0
            let first: () async -> URL? = {
                calls += 1; current = false
                return URL(string: "https://media.example.test/file")!
            }
            let fallback: () async -> URL? = { calls += 1; return nil }
            let result = await PlaybackFileOriginalRouteSelection.resolve(publicFirst: publicFirst,
                isCurrent: { current }, local: publicFirst ? fallback : first,
                remote: publicFirst ? first : fallback)
            XCTAssertNil(result)
            XCTAssertEqual(calls, 1)
        }
        var calls = 0
        let absent = await PlaybackFileOriginalRouteSelection.resolve(publicFirst: true,
            isCurrent: { false }, local: { calls += 1; return nil }, remote: { calls += 1; return nil })
        XCTAssertNil(absent)
        XCTAssertEqual(calls, 0)
    }

    @MainActor
    func testFileCancelledPreparationCannotPublishOrStartFallback() async {
        var calls = 0
        let task = Task { @MainActor in
            await PlaybackFileOriginalRouteSelection.resolve(publicFirst: true,
                isCurrent: { true }, local: { calls += 1; return nil }, remote: {
                    calls += 1
                    withUnsafeCurrentTask { $0?.cancel() }
                    return URL(string: "https://media.example.test/file")!
                })
        }
        let result = await task.value
        XCTAssertNil(result)
        XCTAssertEqual(calls, 1)
    }

    func testBandwidthProbeSeparatesFirstByteWaitFromDeliveryCapacity() throws {
        let sample = try XCTUnwrap(PlaybackBandwidthProbeSample.estimate(bytes: 1024 * 1024,
            totalSeconds: 5, networkBodyBytes: 1024 * 1024, networkBodySeconds: 0.2))
        XCTAssertTrue(sample.usesNetworkBodyTiming)
        XCTAssertEqual(sample.bitrate, 41_943_040)
        XCTAssertEqual(sample.totalSeconds, 5)
        XCTAssertEqual(sample.bodySeconds, 0.2)
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 50_000_000, measuredCapacity: sample.bitrate,
            isPrivateRoute: false, forcesOriginal: false))
    }

    func testBandwidthProbeAcceptsFramingWithoutCountingItAsMediaCapacity() throws {
        let payload: Int64 = 1024 * 1024
        // HTTP/2 framing and HTTP/1.1 chunk markers increase wire bytes even
        // when there is no content compression. The former equality rejected
        // these complete network responses.
        for (wire, transfer) in [(payload + 576, nil), (payload + 2048, "chunked"),
                                  (payload, "identity"), (payload, nil)] as [(Int64, String?)] {
            let bytes = try XCTUnwrap(PlaybackBandwidthProbeSample.networkPayloadBytes(
                received: wire, decoded: payload, contentEncoding: nil, transferEncoding: transfer))
            XCTAssertEqual(bytes, payload)
            let sample = try XCTUnwrap(PlaybackBandwidthProbeSample.estimate(bytes: Int(payload),
                totalSeconds: 5, networkBodyBytes: bytes, networkBodySeconds: 0.2))
            XCTAssertTrue(sample.usesNetworkBodyTiming)
            XCTAssertEqual(sample.bitrate, 41_943_040)
        }
    }

    func testBandwidthProbeStillRejectsCompressionAndIncompletePayload() throws {
        let payload: Int64 = 1024 * 1024
        for (wire, decoded, content, transfer) in [
            (payload, payload, "gzip", nil), (payload, payload, "br", nil),
            (payload, payload, nil, "gzip, chunked"), (payload - 1, payload, nil, nil),
            (0, 0, nil, nil)
        ] as [(Int64, Int64, String?, String?)] {
            XCTAssertNil(PlaybackBandwidthProbeSample.networkPayloadBytes(received: wire,
                decoded: decoded, contentEncoding: content, transferEncoding: transfer))
        }
        let incomplete = try XCTUnwrap(PlaybackBandwidthProbeSample.networkPayloadBytes(
            received: payload + 576, decoded: payload - 1,
            contentEncoding: " identity ", transferEncoding: nil))
        let sample = try XCTUnwrap(PlaybackBandwidthProbeSample.estimate(bytes: Int(payload),
            totalSeconds: 5, networkBodyBytes: incomplete, networkBodySeconds: 0.2))
        XCTAssertFalse(sample.usesNetworkBodyTiming)
        XCTAssertEqual(sample.bitrate, 1_677_721)
    }

    func testBandwidthProbeRejectsIncompleteOrUnusableBodyEvidence() throws {
        let bytes = 1024 * 1024
        for (bodyBytes, seconds) in [(Int64(bytes - 1), 0.2), (nil, nil),
                                     (Int64(bytes), -.infinity), (Int64(bytes), .nan),
                                     (Int64(bytes), 0), (Int64(bytes), 6)] as [(Int64?, Double?)] {
            let sample = try XCTUnwrap(PlaybackBandwidthProbeSample.estimate(bytes: bytes,
                totalSeconds: 5, networkBodyBytes: bodyBytes, networkBodySeconds: seconds))
            XCTAssertFalse(sample.usesNetworkBodyTiming)
            XCTAssertNil(sample.bodySeconds)
            XCTAssertEqual(sample.bitrate, 1_677_721)
        }
        XCTAssertFalse(try XCTUnwrap(PlaybackBandwidthProbeSample.estimate(bytes: 4,
            totalSeconds: 1, networkBodyBytes: 4, networkBodySeconds: 0.1)).usesNetworkBodyTiming)
        for seconds in [0, -1, Double.infinity, .nan] {
            XCTAssertNil(PlaybackBandwidthProbeSample.estimate(bytes: bytes,
                totalSeconds: seconds, networkBodyBytes: Int64(bytes), networkBodySeconds: 0.2))
        }
    }

    func testBandwidthProbeRetainsWeakNetworkDownshiftFromSlowBody() throws {
        let sample = try XCTUnwrap(PlaybackBandwidthProbeSample.estimate(bytes: 1024 * 1024,
            totalSeconds: 9, networkBodyBytes: 1024 * 1024, networkBodySeconds: 8))
        XCTAssertTrue(sample.usesNetworkBodyTiming)
        XCTAssertEqual(sample.bitrate, 1_048_576)
        XCTAssertTrue(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 50_000_000, measuredCapacity: sample.bitrate,
            isPrivateRoute: false, forcesOriginal: false))
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.target(currentCeiling: 50_000_000,
            capacity: sample.bitrate, networkKey: "cellular"), 500_000)
    }

    @MainActor
    func testBandwidthProbeReceivesSDKNetworkMetricsAfterDelayedHeaders() async throws {
        let payload = Data(repeating: 0x61, count: 1024 * 1024)
        let server = try PlaybackRangeTestServer(payload: payload,
            pacedBodyChunkBytes: 128 * 1024, pacedBodyDelay: 0.05,
            payloadIsPlaylist: true, holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let client = JellyfinClient(configuration: .init(url: try XCTUnwrap(server.url),
            accessToken: nil, client: "probe-fixture", deviceName: "fixture",
            deviceID: "fixture", version: "1"))
        let delegate = PlaybackBandwidthProbeDelegate()
        let started = ProcessInfo.processInfo.systemUptime
        let download = Task { try await client.send(
            Paths.getBitrateTestBytes(size: payload.count), delegate: delegate).value }
        defer { download.cancel() }
        while server.requestCount == 0, ProcessInfo.processInfo.systemUptime - started < 3 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(server.requestCount, 1)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        server.releaseResponses()
        let bytes = try await download.value
        XCTAssertEqual(bytes, payload)
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        let sample = try XCTUnwrap(delegate.sample(bytes: bytes.count, totalSeconds: elapsed))
        XCTAssertTrue(sample.usesNetworkBodyTiming, "The SDK must forward actual task metrics")
        XCTAssertGreaterThan(elapsed - (sample.bodySeconds ?? elapsed), 0.8)
        XCTAssertGreaterThan(Double(sample.bitrate), Double(bytes.count) * 8 / elapsed * 1.5)
    }

    func testPublicCellularPreparedResponseRetainsOnlySameTrustedLibraryEndpoint() {
        let original = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 3)
        let current = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 4)
        let library = URL(string: "https://media.example.test:8097/jellyfin")!
        func permits(_ endpoint: URL, libraryEndpoint: URL? = nil) -> Bool {
            JellyfinPublicCellularPreparationPolicy.permitsPathChange(startedOn: original,
                current: current, currentConnectionIsCellular: true, endpoint: endpoint,
                libraryEndpoint: libraryEndpoint ?? library, selectsLibraryEndpoint: true,
                allowsSelfSignedCertificates: false)
        }
        XCTAssertTrue(permits(library))
        for value in ["http://media.example.test:8097/jellyfin", "https://other.example.test:8097/jellyfin",
                      "https://media.example.test:8098/jellyfin", "https://media.example.test:8097/emby",
                      "https://media.example.test:8097/jellyfin?source=other"] {
            XCTAssertFalse(permits(URL(string: value)!))
        }
        for value in ["https://192.168.1.2:8096", "https://127.0.0.1:8096",
                      "https://localhost:8096", "https://[fd00::1]:8096"] {
            let url = URL(string: value)!
            XCTAssertFalse(permits(url, libraryEndpoint: url), "LAN and loopback proof remains path scoped")
        }
    }

    func testPublicCellularPreparedResponseRejectsNetworkSwitchFallbackAndTrustOverride() {
        let library = URL(string: "https://media.example.test/jellyfin")!
        func permits(from: String = "cellular", to: String = "cellular", started: UInt64 = 3,
                     current: UInt64 = 4, connected: Bool = true,
                     librarySelected: Bool = true, selfSigned: Bool = false) -> Bool {
            JellyfinPublicCellularPreparationPolicy.permitsPathChange(
                startedOn: .init(cacheKey: from, bitrateCap: nil, fallbackBitrate: 1, pathGeneration: started),
                current: .init(cacheKey: to, bitrateCap: nil, fallbackBitrate: 1, pathGeneration: current),
                currentConnectionIsCellular: connected, endpoint: library, libraryEndpoint: library,
                selectsLibraryEndpoint: librarySelected, allowsSelfSignedCertificates: selfSigned)
        }
        XCTAssertTrue(permits())
        for key in ["wifi", "unknown", "constrained", "other"] {
            XCTAssertFalse(permits(from: key)); XCTAssertFalse(permits(to: key))
        }
        XCTAssertFalse(permits(started: 0)); XCTAssertFalse(permits(current: 0))
        XCTAssertFalse(permits(current: 3)); XCTAssertFalse(permits(connected: false))
        XCTAssertFalse(permits(librarySelected: false)); XCTAssertFalse(permits(selfSigned: true))
    }

    func testRetainedPublicPlaybackDoesNotReusePathScopedAuthenticationOrLANProof() {
        let original = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 1, pathGeneration: 3)
        let current = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 1, pathGeneration: 4)
        let login = UUID()
        XCTAssertFalse(JellyfinAuthenticatedIdentity.canPublish(startedOn: original, current: current,
            startedSession: login, currentSession: login, cancelled: false))
        var lan = JellyfinLANPlaybackRouteCache()
        XCTAssertTrue(lan.publish(URL(string: "http://192.168.1.2:8096")!,
            startedOn: original, current: original))
        XCTAssertNil(lan.endpoint(on: current))
        XCTAssertFalse(JellyfinAuthenticatedIdentity.canPublish(startedOn: current, current: current,
            startedSession: login, currentSession: UUID(), cancelled: false))
        XCTAssertFalse(JellyfinAuthenticatedIdentity.canPublish(startedOn: current, current: current,
            startedSession: login, currentSession: login, cancelled: true))
    }

    func testPublicCellularPublicationReasonsKeepTrustEndpointAndPathFailuresDistinct() {
        let library = URL(string: "https://media.example.test/jellyfin")!
        func reason(network: String = "cellular", connected: Bool = true, generation: UInt64 = 4,
                    selected: Bool = true, override: Bool = false, endpoint: URL? = nil) -> String? {
            JellyfinPublicCellularPreparationPolicy.rejectionReason(
                startedOn: .init(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 3),
                current: .init(cacheKey: network, bitrateCap: nil, fallbackBitrate: 1, pathGeneration: generation),
                currentConnectionIsCellular: connected, endpoint: endpoint ?? library,
                libraryEndpoint: library, selectsLibraryEndpoint: selected,
                allowsSelfSignedCertificates: override)
        }
        XCTAssertNil(reason())
        XCTAssertEqual(reason(network: "wifi"), "networkBucketChanged")
        XCTAssertEqual(reason(connected: false), "connectionNotCellular")
        XCTAssertEqual(reason(generation: 0), "pathIdentityUnknown")
        XCTAssertEqual(reason(generation: 3), "pathGenerationUnchanged")
        XCTAssertEqual(reason(selected: false), "alternateEndpointSelection")
        XCTAssertEqual(reason(override: true), "certificateOverrideEnabled")
        XCTAssertEqual(reason(endpoint: URL(string: "https://other.example.test/jellyfin")!),
                       "libraryEndpointMismatch")
    }

    func testPreparedLibraryReferenceRequiresExactOwnPublicOrigin() {
        let cell = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 2)
        let own = URL(string: "https://media.example.test/jellyfin")!
        func permits(_ endpoint: URL? = nil, library: URL? = nil, saved: URL? = nil,
                     selected: Bool = true, credentials: Bool = true, network: PlaybackNetworkSnapshot? = nil) -> Bool {
            JellyfinPreparedLibraryRevalidation.permitsReference(startedOn: network ?? cell,
                endpoint: endpoint ?? own, libraryEndpoint: library ?? own, savedEndpoint: saved ?? own,
                librarySelected: selected, ownCredentialsMatch: credentials)
        }
        XCTAssertTrue(permits())
        XCTAssertFalse(permits(selected: false)); XCTAssertFalse(permits(credentials: false))
        for key in ["wifi", "unknown", "constrained"] {
            XCTAssertFalse(permits(network: .init(cacheKey: key, bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 2)))
        }
        XCTAssertFalse(permits(network: .init(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 0)))
        for text in ["https://other.example.test/jellyfin", "https://media.example.test/emby", "https://media.example.test:8443/jellyfin"] {
            let other = URL(string: text)!
            XCTAssertFalse(permits(library: other)); XCTAssertFalse(permits(saved: other))
        }
        for text in ["http://media.example.test/jellyfin", "https://192.168.1.2/jellyfin", "https://localhost/jellyfin", "https://[fd00::1]/jellyfin"] {
            let other = URL(string: text)!
            XCTAssertFalse(permits(other, library: other, saved: other))
        }
    }

    func testPreparedLibraryRevalidationRequiresChangedKnownCellularPathAndRecentReference() {
        let a = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 2)
        func permits(key: String = "cellular", generation: UInt64 = 3, cell: Bool = true, age: Double = 1) -> Bool {
            JellyfinPreparedLibraryRevalidation.permitsRevalidation(startedOn: a,
                current: .init(cacheKey: key, bitrateCap: nil, fallbackBitrate: 1, pathGeneration: generation),
                cellular: cell, referenceAge: age)
        }
        XCTAssertTrue(permits())
        XCTAssertFalse(permits(generation: 0)); XCTAssertFalse(permits(generation: 2)); XCTAssertFalse(permits(cell: false))
        for key in ["wifi", "unknown", "constrained"] { XCTAssertFalse(permits(key: key)) }
        for age in [-1.0, 301, .infinity, .nan] { XCTAssertFalse(permits(age: age)) }
    }

    @MainActor
    func testPreparedLibraryFreshAuthenticationDoesNotBorrowIdentityOrPublishAfterLoginChange() async {
        let own = JellyfinAuthenticatedIdentity(userID: "user", serverID: "server")
        let network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 3)
        for response in [own, nil, .init(userID: "other", serverID: "server"), .init(userID: "user", serverID: "other")] as [JellyfinAuthenticatedIdentity?] {
            for loginChanged in [false, true] {
                var owns = true
                var probes = 0
                let result = await JellyfinPreparedFallbackRevalidation.authenticate(expected: own, userID: "user",
                    session: UUID(), network: { network }, ownershipCurrent: { owns }, probe: {
                        probes += 1; await Task.yield(); owns = !loginChanged; return response
                    })
                XCTAssertEqual(probes, 1)
                XCTAssertEqual(result != nil, response == own && !loginChanged)
            }
        }
        // No missing-reference substitute: authenticated responses require both IDs.
        XCTAssertNil(JellyfinAuthenticatedIdentity.response(data: Data("{\"Id\":\"user\"}".utf8), status: 200))
    }

    @MainActor
    func testPreparedLibraryBoundedAuthenticationRetriesOnlyMatchedPathChange() async {
        let identity = JellyfinAuthenticatedIdentity(userID: "user", serverID: "server")
        var network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 3)
        var calls = 0
        var outcomes: [String] = []
        let result = await JellyfinPreparedLibraryRevalidation.authenticate(expected: identity, userID: "user",
            session: UUID(), network: { network }, ownershipCurrent: { true }, probe: {
                calls += 1; await Task.yield()
                if calls == 1 { network = .init(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 4) }
                return identity
            }, observed: { attempt, outcome in outcomes.append("\(attempt):\(outcome.rejection?.rawValue ?? "accepted")") })
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(result.network?.pathGeneration, 4)
        XCTAssertEqual(outcomes, ["1:pathChanged", "2:accepted"])
        calls = 0
        let unchanged = await JellyfinPreparedLibraryRevalidation.authenticate(expected: identity, userID: "user",
            session: UUID(), network: { network }, ownershipCurrent: { true }, probe: { calls += 1; return identity })
        XCTAssertEqual(calls, 1); XCTAssertEqual(unchanged.network?.pathGeneration, 4)
    }

    @MainActor
    func testPreparedLibraryBoundedAuthenticationStopsOnSecondPathChange() async {
        let identity = JellyfinAuthenticatedIdentity(userID: "user", serverID: "server")
        var generation: UInt64 = 3
        var calls = 0
        let result = await JellyfinPreparedLibraryRevalidation.authenticate(expected: identity, userID: "user",
            session: UUID(), network: { .init(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: generation) },
            ownershipCurrent: { true }, probe: { calls += 1; generation += 1; return identity })
        XCTAssertNil(result.network); XCTAssertEqual(result.rejection, .pathChanged); XCTAssertEqual(calls, 2)
    }

    @MainActor
    func testPreparedLibraryBoundedAuthenticationDoesNotRetryMissingOrWrongIdentity() async {
        let identity = JellyfinAuthenticatedIdentity(userID: "user", serverID: "server")
        for response in [nil, .init(userID: "other", serverID: "server"), .init(userID: "user", serverID: "other")] as [JellyfinAuthenticatedIdentity?] {
            for rejectSecond in [false, true] {
                var generation: UInt64 = 3
                var calls = 0
                let result = await JellyfinPreparedLibraryRevalidation.authenticate(expected: identity, userID: "user",
                    session: UUID(), network: { .init(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: generation) },
                    ownershipCurrent: { true }, probe: {
                        calls += 1; generation += 1
                        return rejectSecond && calls == 1 ? identity : response
                    })
                XCTAssertNil(result.network)
                XCTAssertEqual(result.rejection, response == nil ? .missingIdentity : .identityMismatch)
                XCTAssertEqual(calls, rejectSecond ? 2 : 1)
            }
        }
    }

    @MainActor
    func testPreparedLibraryBoundedAuthenticationRejectsOwnershipAndNetworkChanges() async {
        let identity = JellyfinAuthenticatedIdentity(userID: "user", serverID: "server")
        for change in ["credentials", "login", "endpoint", "expiredReference", "wifi", "unknown", "zeroGeneration"] {
            for rejectSecond in [false, true] {
                var network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 3)
                var owns = true
                var calls = 0
                let result = await JellyfinPreparedLibraryRevalidation.authenticate(expected: identity, userID: "user",
                    session: UUID(), network: { network }, ownershipCurrent: { owns }, probe: {
                        calls += 1; await Task.yield()
                        if rejectSecond && calls == 1 {
                            network = .init(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 4)
                        } else if ["credentials", "login", "endpoint", "expiredReference"].contains(change) {
                            owns = false
                        } else {
                            network = .init(cacheKey: change == "zeroGeneration" ? "cellular" : change,
                                bitrateCap: nil, fallbackBitrate: 1, pathGeneration: change == "zeroGeneration" ? 0 : 5)
                        }
                        return identity
                    })
                XCTAssertNil(result.network, change)
                XCTAssertEqual(calls, rejectSecond ? 2 : 1, change)
                XCTAssertEqual(result.rejection, !owns ? .ownershipChanged
                    : change == "wifi" ? .nonCellularPath : .unknownPath, change)
            }
        }
    }

    @MainActor
    func testPreparedLibraryBoundedAuthenticationRechecksBeforeRetryAndHonorsCancellation() async {
        let identity = JellyfinAuthenticatedIdentity(userID: "user", serverID: "server")
        for change in ["ownership", "cancel", "wifi", "unknown"] {
            var network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 3)
            var owns = true
            var calls = 0
            let task = Task { @MainActor in
                await JellyfinPreparedLibraryRevalidation.authenticate(expected: identity, userID: "user",
                    session: UUID(), network: { network }, ownershipCurrent: { owns }, probe: {
                        calls += 1; network = .init(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 4)
                        return identity
                    }, observed: { attempt, _ in
                        guard attempt == 1 else { return }
                        if change == "ownership" { owns = false }
                        else if change == "cancel" { withUnsafeCurrentTask { $0?.cancel() } }
                        else { network = .init(cacheKey: change, bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 5) }
                    })
            }
            let result = await task.value
            XCTAssertNil(result.network, change); XCTAssertEqual(calls, 1, change)
            XCTAssertEqual(result.rejection, change == "ownership" ? .ownershipChanged
                : change == "cancel" ? .cancelled : change == "wifi" ? .nonCellularPath : .unknownPath, change)
        }
        var calls = 0
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return await JellyfinPreparedLibraryRevalidation.authenticate(expected: identity, userID: "user",
                session: UUID(), network: { .init(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 3) },
                ownershipCurrent: { true }, probe: { calls += 1; return identity })
        }
        let result = await task.value
        XCTAssertNil(result.network); XCTAssertEqual(result.rejection, .cancelled); XCTAssertEqual(calls, 0)
    }

    func testPreparedFallbackRevalidationRequiresSameTrustedOwnCellularOrigin() {
        let a = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 2)
        let b = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 3)
        let url = URL(string: "https://media.example.test/jellyfin")!
        func permits(_ endpoint: URL = URL(string: "https://media.example.test/jellyfin")!,
                     saved: URL? = nil, own: Bool = true, cell: Bool = true, trust: Bool = false,
                     current: PlaybackNetworkSnapshot? = nil) -> Bool {
            JellyfinPreparedFallbackRevalidation.permitsProbe(startedOn: a, current: current ?? b,
                endpoint: endpoint, savedEndpoint: saved ?? url, ownFallback: own,
                cellular: cell, allowsSelfSignedCertificates: trust)
        }
        XCTAssertTrue(permits())
        XCTAssertFalse(permits(own: false)); XCTAssertFalse(permits(cell: false)); XCTAssertFalse(permits(trust: true))
        XCTAssertFalse(permits(current: a))
        for key in ["wifi", "unknown", "constrained"] {
            XCTAssertFalse(permits(current: .init(cacheKey: key, bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 3)))
        }
        for text in ["http://media.example.test/jellyfin", "https://192.168.1.2/jellyfin",
                     "https://localhost/jellyfin", "https://[fd00::1]/jellyfin"] {
            let endpoint = URL(string: text)!
            XCTAssertFalse(permits(endpoint, saved: endpoint))
        }
        for text in ["https://other.example.test/jellyfin", "https://media.example.test/emby",
                     "https://media.example.test:8443/jellyfin"] {
            XCTAssertFalse(permits(saved: URL(string: text)!))
        }
    }

    @MainActor
    func testPreparedFallbackNeedsFreshAuthenticatedResponseBeforePublishing() async {
        let network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 3)
        let identity = JellyfinAuthenticatedIdentity(userID: "user", serverID: "server")
        var calls = 0
        let result = await JellyfinPreparedFallbackRevalidation.authenticate(expected: identity, userID: "user", session: UUID(),
            network: { network }, ownershipCurrent: { true }, probe: { calls += 1; await Task.yield(); return identity })
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(result?.pathGeneration, 3)
        for response in [nil, .init(userID: "other", serverID: "server"), .init(userID: "user", serverID: "other")] as [JellyfinAuthenticatedIdentity?] {
            let rejected = await JellyfinPreparedFallbackRevalidation.authenticate(expected: identity, userID: "user", session: UUID(),
                network: { network }, ownershipCurrent: { true }, probe: { response })
            XCTAssertNil(rejected)
        }
    }

    @MainActor
    func testPreparedFallbackRejectsPathOrCredentialChangeDuringFreshProbe() async {
        let identity = JellyfinAuthenticatedIdentity(userID: "user", serverID: "server")
        for change in ["path", "wifi", "ownership"] {
            var network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 3)
            var owns = true
            let result = await JellyfinPreparedFallbackRevalidation.authenticate(expected: identity, userID: "user", session: UUID(),
                network: { network }, ownershipCurrent: { owns }, probe: {
                    await Task.yield()
                    if change == "ownership" { owns = false }
                    else { network = .init(cacheKey: change == "wifi" ? "wifi" : "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 4) }
                    return identity
                })
            XCTAssertNil(result, change)
        }
    }

    @MainActor
    func testPreparedFallbackCancellationCannotPublishOrStartAnotherProbe() async {
        let identity = JellyfinAuthenticatedIdentity(userID: "user", serverID: "server")
        let network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil, fallbackBitrate: 1, pathGeneration: 3)
        var entered = false
        let task = Task { @MainActor in
            await JellyfinPreparedFallbackRevalidation.authenticate(expected: identity, userID: "user", session: UUID(),
                network: { network }, ownershipCurrent: { true }, probe: {
                    entered = true
                    while !Task.isCancelled { await Task.yield() }
                    return identity
                })
        }
        while !entered { await Task.yield() }
        task.cancel()
        let result = await task.value
        XCTAssertNil(result)
        var calls = 0
        let cancelled = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return await JellyfinPreparedFallbackRevalidation.authenticate(expected: identity, userID: "user", session: UUID(),
                network: { network }, ownershipCurrent: { true }, probe: { calls += 1; return identity })
        }
        let rejected = await cancelled.value
        XCTAssertNil(rejected); XCTAssertEqual(calls, 0)
    }

    func testRepeatedPendingTrackChoiceDoesNotReplaceCandidateOrLatestDifferentChoice() {
        var tracker = PlaybackSourceChangeRequestTracker()
        let a = PlaybackSourceChangeRequestTracker.Tracks(audio: 1, subtitle: 8,
            seekGeneration: 0, pictureInPictureGeneration: 0)
        let b = PlaybackSourceChangeRequestTracker.Tracks(audio: 2, subtitle: 8,
            seekGeneration: 0, pictureInPictureGeneration: 0)
        let c = PlaybackSourceChangeRequestTracker.Tracks(audio: 2, subtitle: 9,
            seekGeneration: 0, pictureInPictureGeneration: 0)
        var accepted = [PlaybackSourceChangeRequestTracker.Tracks]()
        for request in [a, a, b, b, c, c] where tracker.accept(request) {
            accepted.append(request)
        }
        XCTAssertEqual(accepted, [a, b, c], "Repeated taps cannot add a pending closure that invalidates the prepared candidate")
        XCTAssertTrue(tracker.accept(a), "Returning to the original track is a new choice, not a duplicate")
    }

    func testPendingTrackChoiceAfterSeekOrPiPRetainsNewOwnership() {
        var tracker = PlaybackSourceChangeRequestTracker()
        let before = PlaybackSourceChangeRequestTracker.Tracks(audio: 1, subtitle: 8,
            seekGeneration: 0, pictureInPictureGeneration: 0)
        let afterSeek = PlaybackSourceChangeRequestTracker.Tracks(audio: 1, subtitle: 8,
            seekGeneration: 1, pictureInPictureGeneration: 0)
        let afterPiP = PlaybackSourceChangeRequestTracker.Tracks(audio: 1, subtitle: 8,
            seekGeneration: 1, pictureInPictureGeneration: 1)
        XCTAssertTrue(tracker.accept(before))
        XCTAssertTrue(tracker.accept(afterSeek), "A candidate invalidated by seek cannot swallow a fresh selection")
        XCTAssertFalse(tracker.accept(afterSeek))
        XCTAssertTrue(tracker.accept(afterPiP))
    }

    func testFinishedOrInterruptedTrackPreparationAllowsRetryAndExplicitOff() {
        var tracker = PlaybackSourceChangeRequestTracker()
        let track = PlaybackSourceChangeRequestTracker.Tracks(audio: 1, subtitle: 8,
            seekGeneration: 0, pictureInPictureGeneration: 0)
        let off = PlaybackSourceChangeRequestTracker.Tracks(audio: 1, subtitle: nil,
            seekGeneration: 0, pictureInPictureGeneration: 0)
        XCTAssertTrue(tracker.accept(track))
        tracker.finish() // Failed/committed/cancelled preparation has released ownership.
        XCTAssertTrue(tracker.accept(track), "An unapplied choice can be retried")
        XCTAssertTrue(tracker.accept(off))
        XCTAssertFalse(tracker.accept(off))
        XCTAssertTrue(tracker.accept(nil), "Automatic, quality and server-seek requests are never deduplicated")
        XCTAssertTrue(tracker.accept(nil))
        XCTAssertTrue(tracker.accept(off), "A track choice after another source operation must be delivered")
    }

    func testPlaybackDownloadSpeedUsesElapsedReceiveBytesAndResetsAcrossSources() throws {
        var sampler = PlaybackDownloadRateSampler()
        let a = PlaybackDownloadByteSample(sourceID: "a", bytes: 2_000_000)
        XCTAssertNil(sampler.update(a, now: 10))
        XCTAssertEqual(try XCTUnwrap(sampler.update(.init(sourceID: "a", bytes: 3_500_000), now: 11)), 1_500_000)
        XCTAssertEqual(sampler.update(.init(sourceID: "a", bytes: 3_500_000), now: 12), 0,
                       "A full buffer with no new downloads must not keep showing the previous burst")
        XCTAssertNil(sampler.update(.init(sourceID: "b", bytes: 50_000_000), now: 13))
        XCTAssertNil(sampler.update(.init(sourceID: "b", bytes: 0), now: 14))
        XCTAssertNil(sampler.update(.init(sourceID: "b", bytes: 1_000_000), now: 30))
        XCTAssertNil(sampler.update(nil, now: 31))
        XCTAssertNil(sampler.update(a, now: 32))
        XCTAssertNil(sampler.update(a, now: .nan))
        XCTAssertEqual(PlaybackDownloadRateSampler.text(bytesPerSecond: 1_500_000), "1.5 MB/s")
        XCTAssertEqual(PlaybackDownloadRateSampler.text(bytesPerSecond: 120_000), "120 KB/s")
        XCTAssertEqual(PlaybackDownloadRateSampler.text(bytesPerSecond: 0), "0 KB/s")
        XCTAssertEqual(PlaybackDownloadRateSampler.text(bytesPerSecond: .infinity), "— KB/s")
    }

    func testPlaybackDownloadMeterCountsConcurrentReceiversAndKeepsTraceIsolation() {
        let meter = PlaybackDownloadMeter()
        DispatchQueue.concurrentPerform(iterations: 100) { _ in meter.receive(bytes: 1_000, traceID: "movie-a") }
        meter.receive(bytes: 7_000, traceID: "movie-b")
        meter.receive(bytes: -1, traceID: "movie-a")
        meter.receive(bytes: 1_000, traceID: nil)
        XCTAssertEqual(meter.sample(traceID: "movie-a")?.bytes, 100_000)
        XCTAssertEqual(meter.sample(traceID: "movie-b")?.bytes, 7_000)
        XCTAssertNil(meter.sample(traceID: "missing"))
        XCTAssertNil(meter.sample(traceID: nil))
        for i in 0..<40 { meter.receive(bytes: 1, traceID: "new-\(i)", now: 1_000_000_000 + Double(i)) }
        XCTAssertNil(meter.sample(traceID: "movie-a"), "Finished sessions must not grow the meter without a bound")
        XCTAssertEqual(meter.sample(traceID: "new-39")?.bytes, 1)
    }

    @MainActor
    func testTimelineClockKeepsSliderOriginAcrossHourBoundary() {
        for size in [ContentSizeCategory.extraSmall, .large, .accessibilityExtraExtraExtraLarge] {
            let short = timelineClockSize(time: "00:39", duration: "2:03:35", size: size)
            let hour = timelineClockSize(time: "1:19:10", duration: "2:03:35", size: size)
            XCTAssertEqual(short.width, hour.width, accuracy: 0.01,
                           "Scrubbing past one hour must not move the slider under the finger: \(size)")
            XCTAssertEqual(short.height, hour.height, accuracy: 0.01)
        }
    }

    @MainActor
    func testTimelineClockKeepsSliderOriginAcrossMinuteAndTenHourBoundaries() {
        for duration in ["59:59", "12:03:35"] {
            let labels = duration == "59:59" ? ["00:00", "09:59", "59:58"]
                : ["00:00", "9:59:59", "10:00:00"]
            let sizes = labels.map { timelineClockSize(time: $0, duration: duration, size: .large) }
            for size in sizes.dropFirst() {
                XCTAssertEqual(size.width, sizes[0].width, accuracy: 0.01)
            }
        }
    }

    @MainActor
    private func timelineClockSize(time: String, duration: String, size: ContentSizeCategory) -> CGSize {
        let view = PlaybackTimelineClock(timeText: time, durationText: duration)
            .font(.caption.monospacedDigit())
            .environment(\.sizeCategory, size)
        let host = UIHostingController(rootView: view)
        return host.sizeThatFits(in: CGSize(width: 1_000, height: 1_000))
    }

    func testRecordingTemporaryTailKeepsPositionThroughColdAppendAndLaunch() async throws {
        let suite = "recording-tail-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let bytes = Data(repeating: 0x47, count: LocalPlaybackResumeStore.recordingSampleBytes * 3)
        let server = try XCTUnwrap(URL(string: "https://nas.example/"))
        let date = Date(timeIntervalSince1970: 100)
        for position in [399.0, 400.0] {
            let store = LocalPlaybackResumeStore(defaults: defaults)
            let prepared = await store.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
                byteLength: Int64(bytes.count), modifiedAt: date,
                readRange: { offset, length in bytes.subdata(in: Int(offset)..<(Int(offset) + length)) })
            let key = try XCTUnwrap(prepared)
            store.save(key: key, position: position, duration: 400, audioTrackID: 2,
                       subtitleTrackID: 7, subtitlesDisabled: false)
            let cold = LocalPlaybackResumeStore(defaults: defaults)
            XCTAssertNil(cold.entry(for: key), "Cold restore still requires content evidence")
            let appended = bytes + Data(repeating: 0x99, count: LocalPlaybackResumeStore.recordingSampleBytes)
            let next = await cold.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
                byteLength: Int64(appended.count), modifiedAt: date.addingTimeInterval(60),
                readRange: { offset, length in appended.subdata(in: Int(offset)..<(Int(offset) + length)) })
            XCTAssertEqual(next, key)
            let saved = try XCTUnwrap(cold.entry(for: key))
            XCTAssertEqual(saved.positionSeconds, position, "The duration snapshot is not proof that recording ended")
            let request = MediaPlaybackRequest(url: server.appendingPathComponent("r.ts"), title: "Recording",
                source: .dsmFile, fileExtensionOverride: "ts", localResumeKey: key)
            let launch = request.greenfieldPlaybackLaunchRequest(resumeStore: cold)
            XCTAssertEqual(launch.intent.preferredStartTime, position)
            XCTAssertEqual(launch.tracks.selectedSourceAudioTrackID, "2")
            XCTAssertEqual(launch.tracks.selectedSourceSubtitleTrackID, "7")
        }
    }

    func testRecordingClockBeyondDurationSnapshotIsNotClampedOrMarkedComplete() async throws {
        let suite = "recording-stale-duration-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let bytes = Data(repeating: 0x47, count: LocalPlaybackResumeStore.recordingSampleBytes * 3)
        let server = try XCTUnwrap(URL(string: "https://nas.example/"))
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let prepared = await store.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
            byteLength: Int64(bytes.count), modifiedAt: Date(timeIntervalSince1970: 100),
            readRange: { offset, length in bytes.subdata(in: Int(offset)..<(Int(offset) + length)) })
        let key = try XCTUnwrap(prepared)
        store.save(key: key, position: 421, duration: 400, audioTrackID: 2,
                   subtitleTrackID: nil, subtitlesDisabled: true)
        let saved = try XCTUnwrap(store.entry(for: key))
        XCTAssertEqual(saved.positionSeconds, 421)
        XCTAssertEqual(saved.durationSeconds, 421, "Persisted duration must cover the observed position")
        XCTAssertEqual(saved.audioTrackID, 2)
        XCTAssertTrue(saved.subtitlesDisabled)
    }

    func testRecordingMigratesOnlyExactLegacyRevisionAndKeepsOldBookmark() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "recording-legacy-" + UUID().uuidString))
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let server = URL(string: "http://nas.example/")!
        let bytes = Data(repeating: 0x47, count: LocalPlaybackResumeStore.recordingSampleBytes * 3)
        let date = Date(timeIntervalSince1970: 100)
        let oldKey = LocalPlaybackResumeStore.key(server: server, account: "alice", path: "/r.ts", byteLength: Int64(bytes.count), modifiedAt: date)
        store.save(key: oldKey, position: 130, duration: 400, audioTrackID: 2, subtitleTrackID: 7, subtitlesDisabled: false)
        let key = await store.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
            byteLength: Int64(bytes.count), modifiedAt: date,
            readRange: { offset, length in bytes.subdata(in: Int(offset)..<(Int(offset) + length)) })
        let recordingKey = try XCTUnwrap(key)
        XCTAssertEqual(store.entry(for: recordingKey)?.positionSeconds, 130)
        XCTAssertEqual(store.entry(for: recordingKey)?.audioTrackID, 2)
        XCTAssertEqual(store.entry(for: oldKey)?.positionSeconds, 130)
        let differentPath = await store.prepareRecordingKey(server: server, account: "alice", path: "/other.ts",
            byteLength: Int64(bytes.count), modifiedAt: date,
            readRange: { offset, length in bytes.subdata(in: Int(offset)..<(Int(offset) + length)) })
        XCTAssertNil(store.entry(for: try XCTUnwrap(differentPath)))
    }

    func testRecordingResumeSurvivesAppendAndColdStoreWithoutSharingFixedIdentity() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "recording-append-" + UUID().uuidString))
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let count = LocalPlaybackResumeStore.recordingSampleBytes
        let initial = Data(repeating: 0x47, count: count * 3)
        let server = try XCTUnwrap(URL(string: "https://user:secret@nas.example/?sid=token"))
        let date = Date(timeIntervalSince1970: 100)
        let preparedKey = await store.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
            byteLength: Int64(initial.count), modifiedAt: date,
            readRange: { offset, length in initial.subdata(in: Int(offset)..<(Int(offset) + length)) })
        let key = try XCTUnwrap(preparedKey)
        store.save(key: key, position: 130, duration: 400, audioTrackID: 1, subtitleTrackID: 7, subtitlesDisabled: false)
        let cold = LocalPlaybackResumeStore(defaults: defaults)
        XCTAssertNil(cold.entry(for: key), "A persisted recording cannot be exposed before content validation")
        let appended = initial + Data(repeating: 0x99, count: count)
        let nextKey = await cold.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
            byteLength: Int64(appended.count), modifiedAt: date.addingTimeInterval(60),
            readRange: { offset, length in appended.subdata(in: Int(offset)..<(Int(offset) + length)) })
        XCTAssertEqual(nextKey, key)
        let saved = try XCTUnwrap(cold.entry(for: key))
        XCTAssertEqual(saved.positionSeconds, 130)
        XCTAssertEqual(saved.subtitleTrackID, 7)
        XCTAssertNotEqual(key, LocalPlaybackResumeStore.key(server: server, account: "alice", path: "/r.ts",
            byteLength: Int64(initial.count), modifiedAt: date))
        XCTAssertNotEqual(key, LocalPlaybackResumeStore.recordingKey(server: server, account: "bob", path: "/r.ts", prefix: initial.prefix(count)))
        XCTAssertNotEqual(key, LocalPlaybackResumeStore.recordingKey(server: server, account: "alice", path: "/other.ts", prefix: initial.prefix(count)))
        XCTAssertEqual(key, LocalPlaybackResumeStore.recordingKey(server: URL(string: "https://nas.example/")!, account: "alice", path: "/r.ts", prefix: initial.prefix(count)))
    }

    func testRecordingReplacementWithSamePrefixRejectsPreviousPositionAndTracks() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "recording-replace-" + UUID().uuidString))
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let count = LocalPlaybackResumeStore.recordingSampleBytes
        let initial = Data(repeating: 0x47, count: count * 3)
        let server = URL(string: "http://nas.example/")!
        let date = Date(timeIntervalSince1970: 100)
        let preparedKey = await store.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
            byteLength: Int64(initial.count), modifiedAt: date,
            readRange: { offset, length in initial.subdata(in: Int(offset)..<(Int(offset) + length)) })
        let key = try XCTUnwrap(preparedKey)
        store.save(key: key, position: 130, duration: 400, audioTrackID: 1, subtitleTrackID: 7, subtitlesDisabled: false)
        let cold = LocalPlaybackResumeStore(defaults: defaults)
        let replacement = Data(initial.prefix(count)) + Data(repeating: 0x99, count: count * 3)
        let replacementKey = await cold.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
            byteLength: Int64(replacement.count), modifiedAt: date.addingTimeInterval(60),
            readRange: { offset, length in replacement.subdata(in: Int(offset)..<(Int(offset) + length)) })
        XCTAssertEqual(replacementKey, key, "Prefix alone is insufficient; the old checkpoint must also match")
        XCTAssertNil(cold.entry(for: key))
        cold.save(key: key, position: 10, duration: 500, audioTrackID: 2, subtitleTrackID: nil, subtitlesDisabled: true)
        XCTAssertEqual(cold.entry(for: key)?.positionSeconds, 10)
        XCTAssertEqual(cold.entry(for: key)?.audioTrackID, 2)
        XCTAssertTrue(cold.entry(for: key)?.subtitlesDisabled == true)
    }

    func testRecordingTruncationAndBackwardsModificationRejectResume() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "recording-truncate-" + UUID().uuidString))
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let count = LocalPlaybackResumeStore.recordingSampleBytes
        let bytes = Data(repeating: 0x47, count: count * 3)
        let server = URL(string: "http://nas.example/")!
        let date = Date(timeIntervalSince1970: 100)
        let read: (Int64, Int) async -> Data? = { offset, length in bytes.subdata(in: Int(offset)..<(Int(offset) + length)) }
        let preparedKey = await store.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
            byteLength: Int64(bytes.count), modifiedAt: date, readRange: read)
        let key = try XCTUnwrap(preparedKey)
        store.save(key: key, position: 130, duration: 400, audioTrackID: 1, subtitleTrackID: nil, subtitlesDisabled: false)
        for (length, modified) in [(Int64(count * 2), date.addingTimeInterval(1)), (Int64(bytes.count), date.addingTimeInterval(-1))] {
            let cold = LocalPlaybackResumeStore(defaults: defaults)
            _ = await cold.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
                byteLength: length, modifiedAt: modified, readRange: read)
            XCTAssertNil(cold.entry(for: key))
        }
    }

    func testRecordingMissingOrIncompleteContentEvidenceDoesNotCreateResumeIdentity() async {
        let store = LocalPlaybackResumeStore(defaults: UserDefaults(suiteName: "recording-missing-" + UUID().uuidString)!)
        let server = URL(string: "http://nas.example/")!
        for length in [nil, Int64(0), Int64(200_000)] {
            let key = await store.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
                byteLength: length, modifiedAt: Date(), readRange: { _, _ in Data([0x47]) })
            XCTAssertNil(key)
        }
        let missing = await store.prepareRecordingKey(server: server, account: "alice", path: "/r.ts",
            byteLength: 200_000, modifiedAt: nil, readRange: { _, _ in nil })
        XCTAssertNil(missing)
    }

    @MainActor
    func testRecordingContentWitnessUsesBoundedHTTPRangeAndExactBytes() async throws {
        let payload = Data((0..<200_000).map { UInt8($0 % 251) })
        let server = try PlaybackRangeTestServer(payload: payload)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let bytes = await AuthenticatedMediaPlaybackResolver.recordingIdentityBytes(url: try XCTUnwrap(server.url),
            offset: 120_000, count: 65_536, allowsSelfSignedCertificates: false, minimumLength: 190_000)
        XCTAssertEqual(bytes, payload.subdata(in: 120_000..<185_536))
        XCTAssertTrue(server.receivedRequests.contains { $0.contains("bytes=120000-185535") })
    }

    func testRecordingWitnessRejectsIgnoredRangeAuthCompressedAndWrongOffsets() throws {
        let url = URL(string: "https://nas.example/recording.ts")!
        let validHeaders = ["Content-Type": "video/mp2t", "Content-Range": "bytes 0-65535/200000"]
        let good = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 206, httpVersion: nil, headerFields: validHeaders))
        XCTAssertTrue(AuthenticatedMediaPlaybackResolver.recordingIdentityResponseIsValid(good, offset: 0, count: 65536, minimumLength: 190000))
        let invalid: [(Int, [String: String])] = [(200, validHeaders), (401, validHeaders),
            (206, validHeaders.merging(["Content-Type": "text/html"], uniquingKeysWith: { _, new in new })),
            (206, validHeaders.merging(["Content-Encoding": "gzip"], uniquingKeysWith: { _, new in new })),
            (206, ["Content-Range": "bytes 1-65536/200000"]), (206, ["Content-Range": "bytes 0-65534/200000"]),
            (206, ["Content-Range": "bytes 0-65535/100000"]), (206, [:])]
        for (status, headers) in invalid {
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers))
            XCTAssertFalse(AuthenticatedMediaPlaybackResolver.recordingIdentityResponseIsValid(response, offset: 0, count: 65536, minimumLength: 190000))
        }
    }

    @MainActor
    func testRecordingGrowthProbeAllowsAppendedBytesWithoutWeakeningFixedFileCache() async throws {
        let server = try PlaybackRangeTestServer(payload: Data(repeating: 0x47, count: 256))
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let url = try XCTUnwrap(server.url)
        func probe(_ expected: Int, grows: Bool) async -> URL? {
            await AuthenticatedMediaPlaybackResolver.firstPlayableURL(candidates: [url],
                allowsSelfSignedCertificates: false, diagnosticStage: "recordingGrowthTest",
                expectedContentLength: expected, allowsContentGrowth: grows)
        }
        let staleFixed = await probe(128, grows: false)
        XCTAssertNil(staleFixed)
        let appended = await probe(128, grows: true)
        XCTAssertEqual(appended, url)
        let stillStrict = await probe(128, grows: false)
        XCTAssertNil(stillStrict, "A growing-file cache entry must not bypass the fixed-file identity check")
        let truncated = await probe(512, grows: true)
        XCTAssertNil(truncated)
        let unchanged = await probe(256, grows: false)
        XCTAssertEqual(unchanged, url)
    }

    func testGrowingRecordingStillRejectsAuthenticationAndErrorResponses() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/recording.ts"))
        for (status, mime) in [(200, "application/json"), (200, "text/html"),
                               (401, "video/mp2t"), (416, "video/mp2t")] {
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status,
                httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime, "Content-Length": "256"]))
            XCTAssertFalse(AuthenticatedMediaPlaybackResolver.isPlayableResponse(response,
                expectedContentLength: 128, allowsContentGrowth: true))
        }
    }

#if canImport(KSPlayer)
    func testRecordedTransportStreamClockKeepsTimestampOriginBeyond24Hours() {
        // These are source timestamps; the user-facing position remains
        // elapsed time, including after a seek or cold resume.
        let origin = MEPlayerItem.normalizedStartTime(86_998_623_200)
        let firstFrame = CMTime(value: 86_998_733_000, timescale: 1_000_000)
        XCTAssertEqual((firstFrame - origin).seconds, 0.1098, accuracy: 0.000001)
        let resumedFrame = origin + CMTime(seconds: 600, preferredTimescale: 1_000_000)
        XCTAssertEqual((resumedFrame - origin).seconds, 600, accuracy: 0.000001)
    }

    func testKnownNegativeTimestampOriginIsDistinctFromMissingTimestamp() {
        let origin = MEPlayerItem.normalizedStartTime(-2_500_000)
        let frame = CMTime(value: -2_000_000, timescale: 1_000_000)
        XCTAssertEqual((frame - origin).seconds, 0.5, accuracy: 0.000001)
        XCTAssertEqual(MEPlayerItem.normalizedStartTime(Int64.min), .zero)
        XCTAssertEqual(MEPlayerItem.normalizedStartTime(0), .zero)
    }

    func testTransportStreamColdSeekUsesTimestampUnitsRatherThanByteOffset() {
        let origin = MEPlayerItem.normalizedStartTime(86_998_623_200)
        let parameters = MEPlayerItem.initialSeekParameters(startTime: origin,
            position: 716.8429444444445, accurate: true)
        XCTAssertLessThanOrEqual(abs(parameters.timestamp - 87_715_466_144), 1)
        XCTAssertEqual(parameters.maximum, parameters.timestamp)
        XCTAssertEqual(parameters.flags, 0)
        XCTAssertEqual(MEPlayerItem.initialSeekParameters(startTime: .zero,
            position: 600, accurate: false).maximum, Int64.max)
    }

    func testAccurateDiscontinuousTimelineSeekRejectsEstimatedBytePosition() {
        // A paused preview updates video but leaves audio's byte position from
        // before the seek. A second relative seek must still target media time,
        // rather than estimating bytes from that stale position/average bitrate.
        for name in ["mpegts", "mpeg", "otherDiscontinuousTimeline"] {
            XCTAssertFalse(MEPlayerItem.usesByteSeeking(formatFlags: AVFMT_TS_DISCONT,
                formatName: name, accurate: true, prefersTimestampSeeking: false))
        }
    }

    func testNonAccurateByteSeekRetainsFormatCapabilitiesAndExplicitTimestampChoice() {
        XCTAssertTrue(MEPlayerItem.usesByteSeeking(formatFlags: AVFMT_TS_DISCONT,
            formatName: "mpegts", accurate: false, prefersTimestampSeeking: false))
        for (flags, name, prefersTime) in [(Int32(0), "mpegts", false),
            (AVFMT_TS_DISCONT | AVFMT_NO_BYTE_SEEK, "mpegts", false),
            (AVFMT_TS_DISCONT, "ogg", false), (AVFMT_TS_DISCONT, "mpegts", true)] {
            XCTAssertFalse(MEPlayerItem.usesByteSeeking(formatFlags: flags,
                formatName: name, accurate: false, prefersTimestampSeeking: prefersTime))
        }
    }

    func testAccurateSeekComparesMediaFramesAndSubtitlesOnPlaybackTimeline() throws {
        let origin = MEPlayerItem.normalizedStartTime(86_998_623_200)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let frame = AudioFrame(dataSize: 1, audioFormat: format)
        frame.timebase = Timebase(num: 1, den: 1_000_000)
        frame.timestamp = 87_598_523_200 // target minus 0.1 seconds
        frame.duration = 20_000
        XCTAssertTrue(frame.endsBeforeSeekTarget(600, timestampOrigin: origin))
        frame.timestamp = 87_598_723_200
        XCTAssertFalse(frame.endsBeforeSeekTarget(600, timestampOrigin: origin))
        let subtitle = SubtitleFrame(part: SubtitlePart(599, 601, "Current cue"), timebase: .defaultValue)
        XCTAssertFalse(subtitle.endsBeforeSeekTarget(600, timestampOrigin: origin),
                       "Decoded subtitle intervals are already relative to the playback origin")
        frame.timestamp = -2_000_000
        frame.duration = 0
        XCTAssertFalse(frame.endsBeforeSeekTarget(0.4,
            timestampOrigin: MEPlayerItem.normalizedStartTime(-2_500_000)))
    }
#endif

    func testSidecarAndOffExplicitlySuppressJellyfinDefaultSubtitleInRequestBody() throws {
        for selection: Int? in [5, nil] {
            let body = PlaybackInfoDto(subtitleStreamIndex:
                PlaybackJellyfinSubtitleDeliveryPolicy.serverIndex(
                    selected: selection, usesExternalText: selection != nil, usesGreenfield: true))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])
            XCTAssertEqual(object["SubtitleStreamIndex"] as? Int, -1,
                           "Omitting the field lets the server burn its default subtitle underneath the sidecar")
        }
        let image = PlaybackInfoDto(subtitleStreamIndex:
            PlaybackJellyfinSubtitleDeliveryPolicy.serverIndex(selected: 7,
                usesExternalText: false, usesGreenfield: true))
        let imageObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(image)) as? [String: Any])
        XCTAssertEqual(imageObject["SubtitleStreamIndex"] as? Int, 7,
                       "A PGS choice still needs the selected server-rendered stream")
        XCTAssertNil(PlaybackJellyfinSubtitleDeliveryPolicy.serverIndex(selected: nil,
            usesExternalText: false, usesGreenfield: false), "Preserve legacy default negotiation")
    }

    @MainActor
    func testPiPStartInvalidatesPreparedReplacementEvenAfterRestoreOrFailedStart() {
        let controls = GreenfieldPlaybackControls()
        let preparedGeneration = controls.pictureInPictureSessionGeneration
        XCTAssertTrue(controls.canReplacePlaybackSession(pictureInPictureGeneration: preparedGeneration))
        controls.pictureInPictureWillStart()
        XCTAssertFalse(controls.canReplacePlaybackSession(pictureInPictureGeneration: preparedGeneration),
                       "WillStart precedes active=true and must already protect the decoder")
        controls.isPictureInPictureActive = true
        controls.pictureInPictureStartCompleted()
        XCTAssertFalse(controls.canReplacePlaybackSession(
            pictureInPictureGeneration: controls.pictureInPictureSessionGeneration))
        controls.isPictureInPictureActive = false
        XCTAssertFalse(controls.canReplacePlaybackSession(pictureInPictureGeneration: preparedGeneration),
                       "Restoring must not revive a candidate prepared for the retired presentation")
        let afterRestore = controls.pictureInPictureSessionGeneration
        XCTAssertTrue(controls.canReplacePlaybackSession(pictureInPictureGeneration: afterRestore))
        controls.pictureInPictureWillStart()
        controls.pictureInPictureStartCompleted() // Failed start.
        XCTAssertFalse(controls.canReplacePlaybackSession(pictureInPictureGeneration: afterRestore))
        XCTAssertTrue(controls.canReplacePlaybackSession(
            pictureInPictureGeneration: controls.pictureInPictureSessionGeneration))
    }

    @MainActor
    func testLiveTrackReplacementRejectsASeekButAllowsPauseAtTheSamePosition() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 300
        controls.isReady = true
        controls.isSeekable = true
        controls.seekPlayback = { _ in }
        let pip = controls.pictureInPictureSessionGeneration
        let seek = controls.seekGeneration
        controls.isPlaying = true
        XCTAssertTrue(controls.canReplacePlaybackSession(pictureInPictureGeneration: pip, seekGeneration: seek))
        controls.isPlaying = false
        XCTAssertTrue(controls.canReplacePlaybackSession(pictureInPictureGeneration: pip, seekGeneration: seek),
                      "A paused clock can still accept the prepared track at that position")
        XCTAssertTrue(controls.seek(toAbsoluteSeconds: 90))
        XCTAssertFalse(controls.canReplacePlaybackSession(pictureInPictureGeneration: pip, seekGeneration: seek),
                       "The old track candidate cannot undo a newer seek")
        XCTAssertTrue(controls.canReplacePlaybackSession(pictureInPictureGeneration: pip),
                      "Blocking replacements retain the existing optional seek ownership")
    }

    @MainActor
    func testLiveTrackPreferenceRefreshRetainsRequestedOffAndNewSubtitle() {
        for desiredOff in [true, false] {
            let request = MediaPlaybackRequest(url: URL(string: "https://example.com/track.m3u8")!,
                title: "fixture", source: .jellyfin, preferredAudioTrackOrdinal: 2,
                preferredSubtitleTrackOrdinal: desiredOff ? nil : 3,
                prefersSubtitlesDisabled: desiredOff)
            let outgoing = fallbackRuntime(disabled: !desiredOff)
            let refreshed = request.applyingRuntimePreferences(outgoing, preservingRequestedSubtitleSelection: true)
            XCTAssertEqual(refreshed.prefersSubtitlesDisabled, desiredOff)
            XCTAssertEqual(refreshed.preferredSubtitleTrackOrdinal, desiredOff ? nil : 3)
            XCTAssertEqual(refreshed.preferredAudioTrackOrdinal, 2)
            XCTAssertEqual(refreshed.initialPosition, outgoing.normalizedPosition)
            XCTAssertEqual(refreshed.initialPlaybackRate, outgoing.playbackRate)
            XCTAssertEqual(refreshed.initialOrientationMode, outgoing.orientationMode)
            XCTAssertEqual(request.applyingRuntimePreferences(outgoing).prefersSubtitlesDisabled, !desiredOff,
                           "Automatic replacements continue to follow the committed runtime selection")
        }
    }

    func testManualTrackSelectionSurvivesLoaderThenLiveRuntimeRefresh() {
        let textURL = URL(string: "https://example.com/subtitle.srt")!
        for desiredOff in [true, false] {
            for sidecar in [false, true] {
                let subtitleURL = desiredOff || !sidecar ? nil : textURL
                let negotiated = MediaPlaybackRequest(
                    url: URL(string: "https://example.com/track.m3u8")!, title: "fixture",
                    source: .jellyfin, externalSubtitleURL: subtitleURL,
                    preferredAudioTrackOrdinal: 2,
                    preferredSubtitleTrackOrdinal: desiredOff ? nil : 3,
                    prefersSubtitlesDisabled: desiredOff,
                    sourceSubtitleTracks: [.init(id: 8, name: "requested", externalURL: subtitleURL)],
                    selectedSourceAudioTrackID: 1,
                    selectedSourceSubtitleTrackID: desiredOff ? nil : 8)
                let outgoing = fallbackRuntime(disabled: !desiredOff)
                // These are the actual two manual call sites: the negotiated
                // loader copies playback preferences, then the view refreshes
                // the live state before preparing its replacement renderer.
                let loaded = negotiated.applyingSourceTrackRuntimePreferences(outgoing)
                let live = MediaPlaybackRuntimeState(
                    normalizedPosition: outgoing.normalizedPosition, positionSeconds: outgoing.positionSeconds,
                    playbackRate: 1.5, audioTrackOrdinal: outgoing.audioTrackOrdinal,
                    subtitleTrackOrdinal: outgoing.subtitleTrackOrdinal,
                    subtitlesDisabled: outgoing.subtitlesDisabled, subtitleSelectionKnown: true,
                    orientationMode: outgoing.orientationMode)
                let ready = loaded.applyingSourceTrackRuntimePreferences(live)
                for candidate in [loaded, ready] {
                    XCTAssertEqual(candidate.prefersSubtitlesDisabled, desiredOff)
                    XCTAssertEqual(candidate.selectedSourceSubtitleTrackID, desiredOff ? nil : 8)
                    XCTAssertEqual(candidate.externalSubtitleURL, subtitleURL)
                    XCTAssertEqual(candidate.preferredSubtitleTrackOrdinal, desiredOff ? nil : 3)
                    XCTAssertEqual(candidate.selectedSourceAudioTrackID, 1)
                }
                XCTAssertEqual(ready.initialPlaybackRate, 1.5)
                XCTAssertEqual(ready.initialPosition, live.normalizedPosition)
                XCTAssertEqual(negotiated.applyingRuntimePreferences(live).prefersSubtitlesDisabled, !desiredOff,
                    "Automatic fallback still follows the outgoing committed selection")
            }
        }
    }

    func testNativeOffSurvivesAbandonedAutomaticCandidateWithStaleRequest() {
        let srt = URL(string: "https://example.com/subtitles/5.srt")!
        let request = MediaPlaybackRequest(url: URL(string: "https://example.com/video.mkv")!,
            title: "fixture", externalSubtitleURL: srt,
            sourceSubtitleTracks: [.init(id: 5, name: "ASS", externalURL: srt), .init(id: 7, name: "PGS")],
            selectedSourceSubtitleTrackID: 5)
        let off = MediaPlaybackRuntimeState(normalizedPosition: nil, positionSeconds: 4379,
            playbackRate: 1, audioTrackOrdinal: 0, subtitleTrackOrdinal: nil,
            subtitlesDisabled: true, subtitleSelectionKnown: true, orientationMode: .portrait)
        XCTAssertNil(request.committedSourceSubtitleTrackID(forRuntimeState: off),
            "A successful native Off must not revert to the stale ASS request when automatic preparation ends")
        let failedSelection = MediaPlaybackRuntimeState(normalizedPosition: nil, positionSeconds: 4379,
            playbackRate: 1, audioTrackOrdinal: 0, subtitleTrackOrdinal: nil,
            subtitlesDisabled: false, subtitleSelectionKnown: true, orientationMode: .portrait,
            activeExternalSubtitleURL: srt)
        XCTAssertEqual(request.committedSourceSubtitleTrackID(forRuntimeState: failedSelection), 5,
            "An unapplied replacement retains the renderer's previous external subtitle")
    }

    func testCommittedSourceSubtitleUsesLiveIndexesAndDeclinesUnknownSidecar() {
        let request = MediaPlaybackRequest(url: URL(string: "https://example.com/video.mkv")!,
            title: "fixture", sourceSubtitleTracks: [.init(id: 5, name: "ASS"), .init(id: 7, name: "PGS")],
            selectedSourceSubtitleTrackID: 5)
        var state = MediaPlaybackRuntimeState(normalizedPosition: nil, positionSeconds: 4400,
            playbackRate: 1, audioTrackOrdinal: 0, subtitleTrackOrdinal: 1,
            subtitlesDisabled: false, subtitleSelectionKnown: true, orientationMode: .portrait,
            sourceSubtitleStreamIndex: 7)
        XCTAssertEqual(request.committedSourceSubtitleTrackID(forRuntimeState: state), 7)
        state.activeExternalSubtitleURL = URL(fileURLWithPath: "/fixture/unlisted.srt")
        XCTAssertNil(request.committedSourceSubtitleTrackID(forRuntimeState: state))
    }

    @MainActor
    func testNormalizedExternalSubtitleKeepsSourceChoiceThroughGreenfieldAndResume() throws {
        let srt = URL(string: "https://example.com/subtitles/5.srt")!
        let request = MediaPlaybackRequest(url: URL(string: "https://example.com/video.mkv")!,
            title: "fixture", source: .jellyfin, externalSubtitleURL: srt,
            prefersSubtitlesDisabled: true, totalDurationSeconds: 7_535,
            sourceSubtitleTracks: [.init(id: 7, name: "PGS"), .init(id: 5, name: "ASS", externalURL: srt)],
            selectedSourceSubtitleTrackID: 5)
        XCTAssertFalse(request.greenfieldSubtitlesDisabled,
                       "Disabling embedded ASS must not disable the normalized text overlay")
        let launch = request.greenfieldPlaybackLaunchRequest()
        XCTAssertEqual(launch.subtitles?.mode, .externalText)
        XCTAssertEqual(launch.tracks.selectedSourceSubtitleTrackID, "5")
        let suite = "ExternalSubtitleResumeTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        store.save(key: "fixture", position: 4014, duration: 7_535, audioTrackID: 1,
                   subtitleTrackID: request.sourceSubtitleTrackID(forExternalURL: srt), subtitlesDisabled: false)
        let saved = try XCTUnwrap(LocalPlaybackResumeStore(defaults: defaults).entry(for: "fixture"))
        XCTAssertEqual(saved.subtitleTrackID, 5, "Cold resume must retain ASS rather than adopt default PGS")
        XCTAssertFalse(saved.subtitlesDisabled)
        let off = MediaPlaybackRequest(url: request.url, title: "fixture", source: .jellyfin,
                                      prefersSubtitlesDisabled: true)
        XCTAssertTrue(off.greenfieldSubtitlesDisabled)
        XCTAssertEqual(off.greenfieldPlaybackLaunchRequest().subtitles?.mode, .disabled)
    }

    func testExternalSubtitleResumeDeclinesUnknownAndAmbiguousSourceIdentity() {
        let srt = URL(string: "https://example.com/subtitles/5.srt")!
        let request = MediaPlaybackRequest(url: URL(string: "https://example.com/video.mkv")!,
            title: "fixture", sourceSubtitleTracks: [.init(id: 5, name: "one", externalURL: srt),
                .init(id: 6, name: "two", externalURL: srt), .init(id: -2, name: "sidecar", externalURL: srt)])
        XCTAssertNil(request.sourceSubtitleTrackID(forExternalURL: srt))
        XCTAssertNil(request.sourceSubtitleTrackID(forExternalURL: URL(fileURLWithPath: "/fixture/unlisted.srt")))
    }

    func testVideoStartupTimingDistinguishesAttemptFromSuccessfulOutput() {
        let timing = KSVideoStartupTiming()
        let token = timing.snapshot.generation
        timing.discardedBeforeTarget(generation: token)
        timing.discardedBeforeTarget(generation: token)
        XCTAssertNil(timing.snapshot.samples[.acceptedFrame])
        timing.record(.acceptedFrame, time: 10, pts: 900, path: "decode", generation: token)
        timing.discardedBeforeTarget(generation: token)
        timing.record(.outputAttempt, time: 11, pts: 900, path: "attempt", generation: token)
        XCTAssertNil(timing.snapshot.samples[.outputSubmitted], "Missing drawable/sample is not a submission")
        timing.record(.outputSubmitted, time: 12, pts: 901, path: "sampleBufferEnqueued", generation: token)
        timing.record(.acceptedFrame, time: 13, pts: 902, path: "later", generation: token)
        timing.record(.outputSubmitted, time: 14, pts: 902, path: "later", generation: token)
        XCTAssertEqual(timing.snapshot.samples[.acceptedFrame]?.time, 10)
        XCTAssertEqual(timing.snapshot.samples[.outputSubmitted]?.pts, 901)
        XCTAssertEqual(timing.snapshot.discardedBeforeFirstAccepted, 2)
    }

    func testVideoStartupTimingRejectsInvalidSamplesAndOldDecodeGeneration() {
        let timing = KSVideoStartupTiming()
        let old = timing.snapshot.generation
        timing.record(.acceptedFrame, time: .nan, pts: 0, path: "bad", generation: old)
        timing.record(.acceptedFrame, time: 0, pts: 0, path: "bad", generation: old)
        timing.record(.acceptedFrame, time: 1, pts: .infinity, path: "bad", generation: old)
        XCTAssertTrue(timing.snapshot.samples.isEmpty)
        timing.discardedBeforeTarget(generation: old)
        timing.record(.acceptedFrame, time: 2, pts: 10, path: "old", generation: old)
        timing.reset()
        timing.record(.acceptedFrame, time: 3, pts: 11, path: "lateOld", generation: old)
        timing.discardedBeforeTarget(generation: old)
        XCTAssertTrue(timing.snapshot.samples.isEmpty)
        XCTAssertEqual(timing.snapshot.discardedBeforeFirstAccepted, 0)
        let new = timing.snapshot.generation
        timing.record(.acceptedFrame, time: 4, pts: 20, path: "new", generation: new)
        XCTAssertEqual(timing.snapshot.samples[.acceptedFrame]?.pts, 20)
    }

    func testStartupWorkClipsLateCallsAndKeepsOverlappingLanesSeparate() throws {
        let timing = KSVideoStartupTiming()
        let token = timing.snapshot.generation
        timing.recordWork(.demuxRead, start: 1, end: 3, generation: token)
        timing.record(.acceptedFrame, time: 5, pts: 90, path: "accepted", generation: token)
        timing.recordWork(.demuxRead, start: 4, end: 7, generation: token)
        timing.recordWork(.videoDecodeCall, start: 2, end: 8, generation: token)
        timing.recordWork(.demuxRead, start: 5, end: 6, generation: token)
        let snapshot = timing.snapshot
        let read = try XCTUnwrap(snapshot.work[.demuxRead])
        XCTAssertEqual(read.calls, 2)
        XCTAssertEqual(read.seconds, 3)
        XCTAssertEqual(read.maximumSeconds, 2)
        XCTAssertEqual(read.clippedCalls, 1)
        XCTAssertEqual(snapshot.work[.videoDecodeCall]?.seconds, 3)
        XCTAssertEqual(snapshot.fields(prepare: 1)["demuxReadWallMs"], "3000.000")
        XCTAssertEqual(snapshot.fields(prepare: 1)["workMeaning"], "overlappingWallIntervalsClippedAtAcceptedFrameNotCPUOrNetwork")
    }

    func testStartupPacketAndCapacityEvidenceRejectsInvalidAndStaleValues() throws {
        let timing = KSVideoStartupTiming()
        let token = timing.snapshot.generation
        timing.recordWork(.demuxRead, start: .nan, end: 3, generation: token)
        timing.recordWork(.demuxRead, start: 3, end: 2, generation: token)
        timing.recordPacket(media: "subtitle", time: 1, bytes: 9, pts: 1, keyFrame: true, generation: token)
        timing.recordPacket(media: "video", time: 1, bytes: 0, pts: 1, keyFrame: true, generation: token)
        XCTAssertTrue(timing.snapshot.work.isEmpty)
        XCTAssertTrue(timing.snapshot.packets.isEmpty)
        timing.recordPacket(media: "video", time: 2, bytes: 10, pts: 89, keyFrame: true, generation: token)
        timing.record(.acceptedFrame, time: 3, pts: 90, path: "accepted", generation: token)
        timing.recordPacket(media: "video", time: 4, bytes: 20, pts: 91, keyFrame: false, generation: token)
        XCTAssertEqual(timing.snapshot.packets["video"]?.bytes, 10)
        XCTAssertEqual(timing.snapshot.packets["video"]?.firstKeyPTS, 89)
        let valid = KSVideoStartupTiming.CapacitySample(media: "video", packets: 2, frames: 4, maximumFrames: 8, fps: 24)
        let invalid = KSVideoStartupTiming.CapacitySample(media: "audio", packets: 0, frames: 0, maximumFrames: 8, fps: .nan)
        timing.recordCapacity(.firstPlayable, time: 3, tracks: [invalid], generation: token)
        XCTAssertNil(timing.snapshot.capacities[.firstPlayable])
        timing.recordCapacity(.firstPlayable, time: 4, tracks: [valid], generation: token)
        timing.recordCapacity(.firstPlayable, time: 5, tracks: [valid], generation: token)
        XCTAssertEqual(timing.snapshot.capacities[.firstPlayable]?.time, 4)
        timing.reset()
        timing.recordWork(.demuxRead, start: 1, end: 2, generation: token)
        timing.recordPacket(media: "video", time: 2, bytes: 10, pts: 1, keyFrame: true, generation: token)
        timing.recordCapacity(.firstOutput, time: 3, tracks: [valid], generation: token)
        XCTAssertTrue(timing.snapshot.work.isEmpty)
        XCTAssertTrue(timing.snapshot.packets.isEmpty)
        XCTAssertTrue(timing.snapshot.capacities.isEmpty)
    }

    func testProxyDiagnosticsRetainCancelledCallbackAfterActiveTaskIsReleased() throws {
        let diagnostics = PlaybackProxyTaskDiagnostics()
        diagnostics.issued(taskID: 7, now: 10)
        diagnostics.clientFinished(backpressure: 2, suspendCount: 1, queuedBytes: 4096)
        diagnostics.cancellationRequested(now: 12)
        let late = try XCTUnwrap(diagnostics.callback(taskID: 7, completed: true))
        XCTAssertTrue(late.clientFinished)
        XCTAssertTrue(late.completionObserved)
        XCTAssertEqual(late.finalBackpressure, 2)
        XCTAssertEqual(late.finalQueuedBytes, 4096)
        XCTAssertEqual(late.fields(at: 12.25)["upstreamCancelToCallbackMs"], "250")
        XCTAssertEqual(late.fields(at: 12.25)["upstreamIssuedToCallbackMs"], "2250")
    }

    func testResponseBodyDiagnosticsDistinguishCompressionFramingAndDecodedPayload() {
        let gzip = PlaybackResponseBodyDiagnostics.fields(received: 32_000, decoded: 2_700_000,
            contentLength: "31900", contentEncoding: "GZip", status: 200)
        XCTAssertEqual(gzip["responseBodyBytesReceivedIncludingProtocol"], "32000")
        XCTAssertEqual(gzip["responseBodyBytesAfterDecoding"], "2700000")
        XCTAssertEqual(gzip["responseContentEncoding"], "gzip")
        XCTAssertEqual(gzip["responseContentLength"], "31900")
        let framed = PlaybackResponseBodyDiagnostics.fields(received: 2_700_123, decoded: 2_700_000,
            contentLength: "2700000", contentEncoding: nil, status: 200)
        XCTAssertEqual(framed["responseContentEncoding"], "unspecified")
        XCTAssertEqual(framed["responseBodyBytesReceivedIncludingProtocol"], "2700123")
        XCTAssertEqual(framed["responseStatusCode"], "200")
    }

    func testResponseBodyDiagnosticsKeepUnknownValuesAndNeverEchoArbitraryHeaders() {
        for header in ["unexpected-private-value", "gzip,,br", "gzip;private=value"] {
            let fields = PlaybackResponseBodyDiagnostics.fields(received: -1, decoded: -1,
                contentLength: "bad-private-value", contentEncoding: header, status: nil)
            XCTAssertEqual(fields["responseContentEncoding"], "other")
            XCTAssertEqual(fields["responseContentLength"], "unknown")
            XCTAssertEqual(fields["responseBodyBytesAfterDecoding"], "unknown")
            XCTAssertEqual(fields["responseBodyBytesReceivedIncludingProtocol"], "unknown")
            XCTAssertFalse(fields.values.contains { $0.contains("private") })
        }
        let zero = PlaybackResponseBodyDiagnostics.fields(received: 0, decoded: 0,
            contentLength: " 0 ", contentEncoding: "identity", status: 401)
        XCTAssertEqual(zero["responseBodyBytesAfterDecoding"], "0")
        XCTAssertEqual(zero["responseStatusCode"], "401", "An error response is observed, not silently accepted as media")
    }

    func testTransportPhasesKeepFirstFetchAndRedirectedRequestSeparate() {
        func date(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }
        let fields = PlaybackRequestPhaseDiagnostics.fields(created: date(0), firstFetch: date(2),
            lastFetch: date(5), requestStart: date(8), requestEnd: date(9),
            responseStart: date(17), responseEnd: date(23), callback: date(30))
        XCTAssertEqual(fields["taskCreatedToFirstFetchMs"], "2000")
        XCTAssertEqual(fields["lastFetchToRequestMs"], "3000", "do not attribute earlier redirects to the last request")
        XCTAssertEqual(fields["lastRequestSendMs"], "1000")
        XCTAssertEqual(fields["lastRequestEndToFirstByteMs"], "8000")
        XCTAssertEqual(fields["lastResponseBodyMs"], "6000")
        XCTAssertEqual(fields["lastResponseEndToMetricsCallbackMs"], "7000", "late metrics delivery is not download time")
        XCTAssertFalse(fields.keys.contains { $0.lowercased().contains("server") || $0.lowercased().contains("queue") })
    }

    func testTransportPhasesLeaveMissingReversedAndNonFiniteBoundariesUnknown() {
        let now = Date(timeIntervalSince1970: 10)
        let fields = PlaybackRequestPhaseDiagnostics.fields(created: now, firstFetch: nil,
            lastFetch: now, requestStart: now.addingTimeInterval(-1), requestEnd: nil,
            responseStart: now, responseEnd: Date(timeIntervalSince1970: .infinity), callback: now)
        XCTAssertTrue(fields.values.allSatisfy { $0 == "unknown" })
        let zero = PlaybackRequestPhaseDiagnostics.fields(created: now, firstFetch: now,
            lastFetch: now, requestStart: now, requestEnd: now,
            responseStart: now, responseEnd: now, callback: now)
        XCTAssertTrue(zero.values.allSatisfy { $0 == "0" }, "measured zero differs from an absent boundary")
    }

    func testHeadersDiagnosticsRejectOldRetryAndPreserveFirstHeadersTime() throws {
        let diagnostics = PlaybackProxyTaskDiagnostics()
        diagnostics.issued(taskID: 1, now: 1)
        diagnostics.issued(taskID: 2, now: 10)
        diagnostics.responseHeadersReceived(taskID: 1, now: 12)
        diagnostics.responseHeadersReceived(taskID: 2, now: 9)
        diagnostics.responseHeadersReceived(taskID: 2, now: .nan)
        XCTAssertEqual(try XCTUnwrap(diagnostics.callback(taskID: 2)).fields(at: 15)["upstreamHeadersObserved"], "false")
        diagnostics.responseHeadersReceived(taskID: 2, now: 15)
        diagnostics.responseHeadersReceived(taskID: 2, now: 20)
        let fields = try XCTUnwrap(diagnostics.callback(taskID: 2)).fields(at: 21)
        XCTAssertEqual(fields["upstreamHeadersObserved"], "true")
        XCTAssertEqual(fields["upstreamIssueToHeadersCallbackMs"], "5000")
        diagnostics.issued(taskID: 3, now: 22)
        XCTAssertNil(try XCTUnwrap(diagnostics.callback(taskID: 3)).fields(at: 23)["upstreamIssueToHeadersCallbackMs"])
    }

    func testProxyDiagnosticsRejectStaleRetryCallbacksAndResetCancellation() throws {
        let diagnostics = PlaybackProxyTaskDiagnostics()
        diagnostics.issued(taskID: 1, now: 0)
        diagnostics.cancellationRequested(now: 1)
        diagnostics.issued(taskID: 2, now: 2)
        XCTAssertNil(diagnostics.callback(taskID: 1, completed: true))
        let current = try XCTUnwrap(diagnostics.callback(taskID: 2))
        XCTAssertFalse(current.clientFinished)
        XCTAssertFalse(current.completionObserved)
        XCTAssertNil(current.cancelledAt)
    }

    func testBodyDiagnosticsCountBufferedBytesAndKeepFirstAndLastBoundaries() throws {
        let diagnostics = PlaybackProxyTaskDiagnostics()
        diagnostics.issued(taskID: 1, now: 10)
        XCTAssertEqual(try XCTUnwrap(diagnostics.callback(taskID: 1)).fields(at: 11)["upstreamIssueToFirstBodyCallbackMs"], "unknown")
        diagnostics.receivedBody(taskID: 1, bytes: 65_536, now: 12)
        diagnostics.receivedBody(taskID: 1, bytes: 10, now: 14)
        let fields = try XCTUnwrap(diagnostics.callback(taskID: 1, completed: true)).fields(at: 15)
        XCTAssertEqual(fields["upstreamTaskBodyBytes"], "65546")
        XCTAssertEqual(fields["upstreamIssueToFirstBodyCallbackMs"], "2000")
        XCTAssertEqual(fields["upstreamIssueToLastBodyCallbackMs"], "4000")
        diagnostics.receivedBody(taskID: 1, bytes: 100, now: 16)
        XCTAssertEqual(try XCTUnwrap(diagnostics.callback(taskID: 1)).receivedBodyBytes, 65_546)
    }

    func testBodyDiagnosticsRejectStaleRetryAndInvalidBoundaries() throws {
        let diagnostics = PlaybackProxyTaskDiagnostics()
        diagnostics.issued(taskID: 1, now: 1)
        diagnostics.receivedBody(taskID: 1, bytes: 50, now: 2)
        diagnostics.issued(taskID: 2, now: 10)
        diagnostics.receivedBody(taskID: 1, bytes: 100, now: 12)
        for (bytes, now) in [(Int64(0), 12.0), (-1, 12), (10, 9), (10, .nan), (10, .infinity), (10, Double.greatestFiniteMagnitude)] {
            diagnostics.receivedBody(taskID: 2, bytes: bytes, now: now)
        }
        XCTAssertEqual(try XCTUnwrap(diagnostics.callback(taskID: 2)).receivedBodyBytes, 0)
        diagnostics.receivedBody(taskID: 2, bytes: 25, now: 13)
        diagnostics.receivedBody(taskID: 2, bytes: 100, now: 12)
        XCTAssertEqual(try XCTUnwrap(diagnostics.callback(taskID: 2)).receivedBodyBytes, 25)
    }

    func testBodyDiagnosticsRetainProgressAfterClientClosesWithoutOverflow() throws {
        let diagnostics = PlaybackProxyTaskDiagnostics()
        diagnostics.issued(taskID: 1, now: 1)
        diagnostics.clientFinished(backpressure: 0, suspendCount: 0, queuedBytes: 0)
        diagnostics.receivedBody(taskID: 1, bytes: .max, now: 2)
        diagnostics.receivedBody(taskID: 1, bytes: 1, now: 3)
        let snapshot = try XCTUnwrap(diagnostics.callback(taskID: 1))
        XCTAssertTrue(snapshot.clientFinished)
        XCTAssertEqual(snapshot.receivedBodyBytes, .max)
        XCTAssertEqual(snapshot.fields(at: 4)["upstreamIssueToLastBodyCallbackMs"], "1000")
    }

    func testProxyDiagnosticsNormalCompletionIsNotReportedAsCancellation() throws {
        let diagnostics = PlaybackProxyTaskDiagnostics()
        diagnostics.issued(taskID: 3, now: 1)
        _ = diagnostics.callback(taskID: 3, completed: true)
        diagnostics.clientFinished(backpressure: 0, suspendCount: 0, queuedBytes: 0)
        diagnostics.cancellationRequested(now: 4)
        let metrics = try XCTUnwrap(diagnostics.callback(taskID: 3))
        XCTAssertTrue(metrics.completionObserved)
        XCTAssertNil(metrics.fields(at: 5)["upstreamCancelToCallbackMs"])
        XCTAssertEqual(metrics.fields(at: 5)["upstreamCancellationRequested"], "false")
    }

    func testProxyDiagnosticsRepeatedClientFinishPreservesOriginalPressureAndCancelTime() throws {
        let diagnostics = PlaybackProxyTaskDiagnostics()
        diagnostics.issued(taskID: 4, now: 1)
        diagnostics.clientFinished(backpressure: 3, suspendCount: 2, queuedBytes: 100)
        diagnostics.cancellationRequested(now: 2)
        diagnostics.clientFinished(backpressure: 0, suspendCount: 0, queuedBytes: 0)
        diagnostics.cancellationRequested(now: 8)
        let late = try XCTUnwrap(diagnostics.callback(taskID: 4))
        XCTAssertEqual(late.finalBackpressure, 3)
        XCTAssertEqual(late.finalSuspendCount, 2)
        XCTAssertEqual(late.cancelledAt, 2)
    }

    func testStartupClockRejectsPreparedPausedAndWaitingPosition() {
        var policy = PlaybackClockStartupPolicy()
        XCTAssertFalse(policy.sample(seconds: 120, uptime: 0, isPlaying: false, seekGeneration: 0, rate: 1))
        XCTAssertFalse(policy.sample(seconds: 120, uptime: 1, isPlaying: false, seekGeneration: 0, rate: 1))
        XCTAssertFalse(policy.sample(seconds: 120, uptime: 2, isPlaying: true, seekGeneration: 0, rate: 1))
        XCTAssertTrue(policy.sample(seconds: 120.5, uptime: 2.5, isPlaying: true, seekGeneration: 0, rate: 1))
    }

    func testStartupClockRejectsSeekJumpAndResetsAcrossPlaybackIntent() {
        var policy = PlaybackClockStartupPolicy()
        XCTAssertFalse(policy.sample(seconds: 2, uptime: 0, isPlaying: true, seekGeneration: 0, rate: 1))
        XCTAssertFalse(policy.sample(seconds: 200, uptime: 1, isPlaying: true, seekGeneration: 1, rate: 1))
        XCTAssertFalse(policy.sample(seconds: 400, uptime: 1.5, isPlaying: true, seekGeneration: 1, rate: 1))
        XCTAssertFalse(policy.sample(seconds: 400, uptime: 2, isPlaying: false, seekGeneration: 1, rate: 1))
        XCTAssertFalse(policy.sample(seconds: 400.5, uptime: 2.5, isPlaying: true, seekGeneration: 1, rate: 1))
        XCTAssertTrue(policy.sample(seconds: 401, uptime: 3, isPlaying: true, seekGeneration: 1, rate: 1))
    }

    func testStartupClockRejectsInvalidAndLongGapSamplesButAllowsPlaybackRate() {
        var policy = PlaybackClockStartupPolicy()
        XCTAssertFalse(policy.sample(seconds: .nan, uptime: 0, isPlaying: true, seekGeneration: 0, rate: 1))
        XCTAssertFalse(policy.sample(seconds: 0, uptime: 1, isPlaying: true, seekGeneration: 0, rate: 2))
        XCTAssertTrue(policy.sample(seconds: 1, uptime: 1.5, isPlaying: true, seekGeneration: 0, rate: 2))
        XCTAssertFalse(policy.sample(seconds: 9, uptime: 5.5, isPlaying: true, seekGeneration: 0, rate: 2))
        XCTAssertFalse(policy.sample(seconds: 9, uptime: 5.5, isPlaying: true, seekGeneration: 0, rate: 2))
        XCTAssertFalse(policy.sample(seconds: 8, uptime: 6, isPlaying: true, seekGeneration: 0, rate: 2))
    }

    private func largeFallbackFile(size: Int64 = 32 * 1024 * 1024 * 1024) -> FileItem {
        FileItem(id: UUID(), name: "fixture.mkv", subtitle: "/video/fixture.mkv",
                 kind: .video, sizeText: nil, children: [], sizeBytes: size)
    }

    @MainActor
    private func fallbackMatch(audioIndex: Int? = 1) -> JellyfinMatchedFileStream.Match {
        let client = JellyfinClient(configuration: .init(url: URL(string: "https://example.com")!,
            accessToken: "fixture", client: "Test", deviceName: "Test", deviceID: "Test", version: "1"))
        return .init(client: client, itemID: "item", mediaSourceID: "source",
            sourceBitrate: 80_000_000, durationSeconds: 7200, measuredCapacity: 40_000_000,
            measuredAt: Date(), firstAudioStreamIndex: audioIndex,
            mediaStreams: audioIndex.map { [MediaStream(codec: "aac", index: $0, type: .audio)] } ?? [])
    }

    private func fallbackRuntime(audio: Int? = 0, subtitle: Int? = nil,
                                 disabled: Bool = true, known: Bool = true,
                                 position: Double? = 38.25) -> MediaPlaybackRuntimeState {
        .init(normalizedPosition: 0.2, positionSeconds: position, playbackRate: 1.5,
              audioTrackOrdinal: audio, subtitleTrackOrdinal: subtitle,
              subtitlesDisabled: disabled, subtitleSelectionKnown: known,
              orientationMode: .landscape, sourceAudioStreamIndex: audio == 0 ? 1 : nil)
    }

    @MainActor
    func testWiFiOriginalFallbackIsLazyAndKeepsVerifiedPositionAndPlaybackPreferences() async throws {
        var resolutions = 0
        var preparations = 0
        let match = fallbackMatch()
        let loader = try XCTUnwrap(JellyfinMatchedFileStream.originalFallbackRequestLoader(
            file: largeFallbackFile(), sourceTraceID: UUID().uuidString, networkKey: "wifi",
            subtitleURL: nil, localResumeKey: "fixture", resolveMatch: {
                resolutions += 1
                return match
            }, prepareRequest: { resolved, bitrate, seconds, tracks in
                XCTAssertEqual(tracks.audioIndex, 1)
                XCTAssertNil(tracks.subtitleIndex)
                preparations += 1
                XCTAssertEqual(resolved.mediaSourceID, "source")
                XCTAssertEqual(resolved.firstAudioStreamIndex, 1)
                XCTAssertEqual(bitrate, 20_000_000)
                XCTAssertEqual(seconds, 38.25)
                return MediaPlaybackRequest(url: URL(string: "https://example.com/candidate.m3u8")!,
                    title: "Fixture", source: .dsmFile, fileExtensionOverride: "m3u8",
                    timelineOffsetSeconds: seconds, estimatedBitrate: bitrate,
                    selectedQualityID: "auto", localResumeKey: "fixture")
            }))
        XCTAssertEqual(resolutions, 0, "Healthy original startup must not resolve/transcode")
        XCTAssertEqual(preparations, 0)
        let result = await loader(fallbackRuntime())
        let request = try XCTUnwrap(result)
        XCTAssertEqual(resolutions, 1)
        XCTAssertEqual(preparations, 1)
        XCTAssertNil(request.initialPosition)
        XCTAssertEqual(request.timelineOffsetSeconds, 38.25)
        XCTAssertEqual(request.initialPlaybackRate, 1.5)
        XCTAssertTrue(request.prefersSubtitlesDisabled)
        XCTAssertEqual(request.localResumeKey, "fixture")
        XCTAssertEqual(request.selectedQualityID, "auto")
    }

    @MainActor
    func testOriginalFallbackKeepsUnsupportedOrUnknownUserTracksOnOriginal() async throws {
        var resolutions = 0
        let loader = try XCTUnwrap(JellyfinMatchedFileStream.originalFallbackRequestLoader(
            file: largeFallbackFile(), sourceTraceID: UUID().uuidString, networkKey: "wifi",
            subtitleURL: nil, localResumeKey: nil, resolveMatch: {
                resolutions += 1
                return self.fallbackMatch()
            }))
        for runtime in [fallbackRuntime(audio: 1), fallbackRuntime(audio: nil),
                        fallbackRuntime(subtitle: 2, disabled: false), fallbackRuntime(known: false),
                        fallbackRuntime(position: nil), fallbackRuntime(position: .nan)] {
            let result = await loader(runtime)
            XCTAssertNil(result, "Unmapped state must never silently select a different track/time")
        }
        XCTAssertEqual(resolutions, 0)
        XCTAssertNil(JellyfinMatchedFileStream.originalFallbackRequestLoader(
            file: largeFallbackFile(size: 1024), sourceTraceID: UUID().uuidString,
            networkKey: "wifi", subtitleURL: nil, localResumeKey: nil, resolveMatch: { nil }))
    }

    @MainActor
    func testOriginalFallbackNeedsUniqueVerifiedSourceAndKnownAudioIndex() async throws {
        for match in [nil, fallbackMatch(audioIndex: nil)] {
            var preparations = 0
            let loader = try XCTUnwrap(JellyfinMatchedFileStream.originalFallbackRequestLoader(
                file: largeFallbackFile(), sourceTraceID: UUID().uuidString, networkKey: "wifi",
                subtitleURL: nil, localResumeKey: nil, resolveMatch: { match },
                prepareRequest: { _, _, _, _ in preparations += 1; return nil }))
            let request = await loader(fallbackRuntime())
            XCTAssertNil(request)
            XCTAssertEqual(preparations, 0, "An unavailable strict match cannot create a stream")
        }
    }

    @MainActor
    func testCancelledOriginalFallbackReleasesLatePreparedCandidate() async throws {
        var continuation: CheckedContinuation<MediaPlaybackRequest?, Never>?
        var releases = 0
        let candidate = MediaPlaybackRequest(url: URL(string: "https://example.com/candidate.m3u8")!,
            title: "Fixture", playbackTracker: MediaPlaybackTracker(releaseResources: {
                releases += 1
            }, eventHandler: { _ in }))
        let loader = try XCTUnwrap(JellyfinMatchedFileStream.originalFallbackRequestLoader(
            file: largeFallbackFile(), sourceTraceID: UUID().uuidString, networkKey: "wifi",
            subtitleURL: nil, localResumeKey: nil, resolveMatch: { self.fallbackMatch() },
            prepareRequest: { _, _, _, _ in
                await withCheckedContinuation { continuation = $0 }
            }))
        let task = Task { await loader(self.fallbackRuntime()) }
        for _ in 0..<100 where continuation == nil { await Task.yield() }
        let resume = try XCTUnwrap(continuation)
        task.cancel()
        resume.resume(returning: candidate)
        let result = await task.value
        XCTAssertNil(result)
        XCTAssertEqual(releases, 1)
    }

    @MainActor
    func testOriginalFallbackUsesAbsoluteNonfirstAudioAndEmbeddedOrActiveExternalSubtitle() async throws {
        var match = fallbackMatch()
        // S03's original counterexample uses source index 4, ordinal 3, Off.
        // Reordered metadata must not reinterpret ordinal 3 as another index.
        match.mediaStreams = [MediaStream(codec: "ass", index: 5, type: .subtitle),
            MediaStream(codec: "aac", index: 4, type: .audio),
            MediaStream(codec: "truehd", index: 1, type: .audio)]
        let external = URL(fileURLWithPath: "/fixture/current.srt")
        let stale = URL(fileURLWithPath: "/fixture/stale.srt")
        var prepared: [JellyfinMatchedFileStream.TrackSelection] = []
        let loader = try XCTUnwrap(JellyfinMatchedFileStream.originalFallbackRequestLoader(
            file: largeFallbackFile(), sourceTraceID: UUID().uuidString, networkKey: "wifi",
            subtitleURL: stale, localResumeKey: "fixture", resolveMatch: { match },
            prepareRequest: { _, _, seconds, tracks in
                prepared.append(tracks)
                XCTAssertEqual(seconds, 38.25)
                return MediaPlaybackRequest(url: URL(string: "https://example.com/stream.m3u8")!,
                    title: "fixture", timelineOffsetSeconds: seconds)
            }))
        var off = fallbackRuntime(audio: 3)
        off.sourceAudioStreamIndex = 4
        var embedded = fallbackRuntime(subtitle: 0, disabled: false)
        embedded.sourceSubtitleStreamIndex = 5
        var sidecar = fallbackRuntime(disabled: false)
        sidecar.activeExternalSubtitleURL = external
        for state in [off, embedded, sidecar] {
            let result = await loader(state)
            XCTAssertNotNil(result)
        }
        XCTAssertEqual(prepared, [.init(audioIndex: 4, subtitleIndex: nil, externalSubtitleURL: nil),
            .init(audioIndex: 1, subtitleIndex: 5, externalSubtitleURL: nil),
            .init(audioIndex: 1, subtitleIndex: nil, externalSubtitleURL: external)])
    }

    @MainActor
    func testSourceReplacementKeepsPlayingIntentWhileTransportIsWaiting() {
        let controls = GreenfieldPlaybackControls()
        var intent = true
        controls.isPlaying = false
        controls.isTransportBuffering = true
        controls.readPlaybackIntent = { intent }
        controls.togglePlaybackAction = { intent.toggle() }
        XCTAssertTrue(controls.wantsPlayback, "Buffering is not a user pause")
        controls.pauseForExternalHandoff()
        XCTAssertFalse(intent, "Preparing a replacement must suspend the outgoing renderer even while it waits")
        controls.disconnect()
        XCTAssertNil(controls.readPlaybackIntent, "An old renderer must not supply the next session's intent")
    }

    @MainActor
    func testSourceReplacementDoesNotResumeAnExplicitlyPausedIntent() {
        let controls = GreenfieldPlaybackControls()
        var intent = false
        // A late engine observation may still report the previous playing state.
        controls.isPlaying = true
        controls.readPlaybackIntent = { intent }
        controls.togglePlaybackAction = { intent.toggle() }
        XCTAssertFalse(controls.wantsPlayback)
        controls.pauseForExternalHandoff()
        XCTAssertFalse(intent, "A handoff must never toggle an explicit pause back into playback")
    }

    @MainActor
    func testSourceMenuRuntimePreservesVerifiedFileSeekTracks() {
        var match = fallbackMatch()
        match.mediaStreams += [.init(codec: "aac", index: 4, type: .audio),
                               .init(codec: "ass", index: 5, type: .subtitle)]
        let external = URL(fileURLWithPath: "/fixture/current.srt")
        let request = MediaPlaybackRequest(url: URL(string: "https://example.com/fixture.m3u8")!,
            title: "fixture", source: .dsmFile,
            sourceAudioTracks: [.init(id: 1, name: "first"), .init(id: 4, name: "fourth")],
            sourceSubtitleTracks: [.init(id: 5, name: "embedded"), .init(id: -2, name: "external", externalURL: external)])
        let before = fallbackRuntime(position: 123)
        for subtitle in [nil, 5, -2] as [Int?] {
            let runtime = request.runtimeStateForSourceChange(before, selectedAudioID: 4, selectedSubtitleID: subtitle)
            XCTAssertEqual(runtime.positionSeconds, before.positionSeconds)
            XCTAssertEqual(runtime.playbackRate, before.playbackRate)
            XCTAssertEqual(runtime.orientationMode, before.orientationMode)
            XCTAssertEqual(runtime.audioTrackOrdinal, 1)
            XCTAssertEqual(runtime.sourceAudioStreamIndex, 4, "A menu ordinal is not the source stream index")
            XCTAssertEqual(JellyfinMatchedFileStream.verifiedTracks(match: match, runtime: runtime),
                .init(audioIndex: 4, subtitleIndex: subtitle == 5 ? 5 : nil,
                      externalSubtitleURL: subtitle == -2 ? external : nil))
        }
    }

    @MainActor
    func testSourceMenuRuntimeDoesNotInventMissingOrAmbiguousSourceIDs() {
        let before = fallbackRuntime()
        for audio in [[MediaPlaybackSourceTrack(id: 4, name: "fourth")],
                      [.init(id: 1, name: "first"), .init(id: 1, name: "duplicate")]] {
            let request = MediaPlaybackRequest(url: URL(string: "https://example.com/fixture.m3u8")!,
                title: "fixture", sourceAudioTracks: audio,
                sourceSubtitleTracks: [.init(id: 5, name: "embedded")])
            let runtime = request.runtimeStateForSourceChange(before, selectedAudioID: 1, selectedSubtitleID: 99)
            XCTAssertNil(runtime.sourceAudioStreamIndex)
            XCTAssertNil(runtime.sourceSubtitleStreamIndex)
            XCTAssertNil(runtime.activeExternalSubtitleURL)
            XCTAssertFalse(runtime.subtitleSelectionKnown)
            XCTAssertNil(JellyfinMatchedFileStream.verifiedTracks(match: fallbackMatch(), runtime: runtime))
        }
    }

    @MainActor
    func testInitialMatchedHLSKeepsSourceTracksAndResumePosition() throws {
        var match = fallbackMatch()
        match.mediaStreams += [.init(codec: "aac", index: 4, type: .audio),
                               .init(codec: "ass", index: 5, type: .subtitle)]
        let saved = LocalPlaybackResumeStore.Entry(positionSeconds: 900, durationSeconds: 7200,
            audioTrackID: 4, subtitleTrackID: 5, subtitlesDisabled: false, updatedAt: Date())
        let selection = try XCTUnwrap(JellyfinMatchedFileStream.initialSelection(
            match: match, resume: saved, playsFromBeginning: false, externalSubtitleURL: nil))
        XCTAssertEqual(selection.tracks, .init(audioIndex: 4, subtitleIndex: 5, externalSubtitleURL: nil))
        XCTAssertEqual(selection.initialPosition, 0.125)
        let head = try XCTUnwrap(JellyfinMatchedFileStream.initialSelection(
            match: match, resume: saved, playsFromBeginning: true, externalSubtitleURL: nil))
        XCTAssertEqual(head.tracks, selection.tracks, "Starting over must retain track preferences")
        XCTAssertEqual(head.initialPosition, 0)
    }

    @MainActor
    func testInitialMatchedHLSPreservesOffAndVerifiedSidecar() throws {
        let match = fallbackMatch()
        let sidecar = URL(string: "https://example.com/subtitle.srt")!
        let off = LocalPlaybackResumeStore.Entry(positionSeconds: 90, durationSeconds: 7200,
            audioTrackID: 1, subtitleTrackID: 5, subtitlesDisabled: true, updatedAt: Date())
        let disabled = try XCTUnwrap(JellyfinMatchedFileStream.initialSelection(
            match: match, resume: off, playsFromBeginning: false, externalSubtitleURL: sidecar))
        XCTAssertEqual(disabled.tracks, .init(audioIndex: 1, subtitleIndex: nil, externalSubtitleURL: nil))
        let on = LocalPlaybackResumeStore.Entry(positionSeconds: 90, durationSeconds: 7200,
            audioTrackID: 1, subtitleTrackID: -2, subtitlesDisabled: false, updatedAt: Date())
        XCTAssertEqual(JellyfinMatchedFileStream.initialSelection(match: match, resume: on,
            playsFromBeginning: false, externalSubtitleURL: sidecar)?.tracks.externalSubtitleURL, sidecar)
        XCTAssertNil(JellyfinMatchedFileStream.initialSelection(match: match, resume: on,
            playsFromBeginning: false, externalSubtitleURL: nil))
        XCTAssertEqual(JellyfinMatchedFileStream.initialSelection(match: match, resume: nil,
            playsFromBeginning: true, externalSubtitleURL: nil)?.tracks.audioIndex, 1)
    }

    @MainActor
    func testInitialMatchedHLSDeclinesUnknownSourceIdentityAndUnmappedResume() {
        var match = fallbackMatch()
        let saved = LocalPlaybackResumeStore.Entry(positionSeconds: 900, durationSeconds: 7200,
            audioTrackID: 4, subtitleTrackID: 5, subtitlesDisabled: false, updatedAt: Date())
        XCTAssertNil(JellyfinMatchedFileStream.initialSelection(match: match, resume: saved,
            playsFromBeginning: false, externalSubtitleURL: nil))
        match.mediaStreams += [.init(codec: "aac", index: 4, type: .audio),
                               .init(codec: "ass", index: 5, type: .subtitle)]
        match = .init(client: match.client, itemID: match.itemID, mediaSourceID: match.mediaSourceID,
            sourceBitrate: match.sourceBitrate, durationSeconds: nil,
            measuredCapacity: match.measuredCapacity, measuredAt: match.measuredAt,
            firstAudioStreamIndex: match.firstAudioStreamIndex, mediaStreams: match.mediaStreams)
        XCTAssertNil(JellyfinMatchedFileStream.initialSelection(match: match, resume: saved,
            playsFromBeginning: false, externalSubtitleURL: nil))
        XCTAssertNotNil(JellyfinMatchedFileStream.initialSelection(match: match, resume: saved,
            playsFromBeginning: true, externalSubtitleURL: nil))
        match.mediaStreams.append(.init(codec: "aac", index: 4, type: .audio))
        XCTAssertNil(JellyfinMatchedFileStream.initialSelection(match: match, resume: saved,
            playsFromBeginning: true, externalSubtitleURL: nil))
    }

    @MainActor
    func testVerifiedFileTracksRejectUnknownIDsWrongTypesAndDuplicateIndexes() {
        var match = fallbackMatch()
        var state = fallbackRuntime()
        state.sourceAudioStreamIndex = 4
        XCTAssertNil(JellyfinMatchedFileStream.verifiedTracks(match: match, runtime: state))
        match.mediaStreams.append(.init(codec: "ass", index: 4, type: .subtitle))
        XCTAssertNil(JellyfinMatchedFileStream.verifiedTracks(match: match, runtime: state))
        match.mediaStreams.append(.init(codec: "aac", index: 4, type: .audio))
        XCTAssertNil(JellyfinMatchedFileStream.verifiedTracks(match: match, runtime: state))
        match = fallbackMatch()
        var embedded = fallbackRuntime(subtitle: 0, disabled: false)
        embedded.sourceSubtitleStreamIndex = 1
        XCTAssertNil(JellyfinMatchedFileStream.verifiedTracks(match: match, runtime: embedded))
        match.mediaStreams.append(.init(codec: "ass", index: 5, isExternal: true, type: .subtitle))
        embedded.sourceSubtitleStreamIndex = 5
        XCTAssertNil(JellyfinMatchedFileStream.verifiedTracks(match: match, runtime: embedded))
    }

    @MainActor
    func testNegotiatedHLSRejectsTrackChangesDuplicatesAndUnconfirmedSubtitleDelivery() {
        func url(_ query: String) -> URL { URL(string: "https://example.com/master.m3u8?" + query)! }
        XCTAssertTrue(JellyfinMatchedFileStream.negotiatedTracksMatch(
            url: url("AudioStreamIndex=4&SubtitleStreamIndex=-1"), audioIndex: 4, subtitleIndex: nil))
        XCTAssertTrue(JellyfinMatchedFileStream.negotiatedTracksMatch(
            url: url("audiostreamindex=1&SubtitleStreamIndex=5&SubtitleMethod=Encode"), audioIndex: 1, subtitleIndex: 5))
        for query in ["AudioStreamIndex=1&SubtitleStreamIndex=-1",
                      "AudioStreamIndex=4&AudioStreamIndex=1&SubtitleStreamIndex=-1",
                      "AudioStreamIndex=4", "SubtitleStreamIndex=-1"] {
            XCTAssertFalse(JellyfinMatchedFileStream.negotiatedTracksMatch(url: url(query), audioIndex: 4, subtitleIndex: nil))
        }
        XCTAssertTrue(JellyfinMatchedFileStream.negotiatedTracksMatch(
            url: url("AudioStreamIndex=4&SubtitleMethod=Encode"), audioIndex: 4, subtitleIndex: nil,
            negotiatedAudioIndex: 4, negotiatedSubtitleIndex: -1))
        XCTAssertFalse(JellyfinMatchedFileStream.negotiatedTracksMatch(
            url: url("AudioStreamIndex=4&SubtitleMethod=Encode"), audioIndex: 4, subtitleIndex: nil,
            negotiatedAudioIndex: 4, negotiatedSubtitleIndex: 5))
        XCTAssertFalse(JellyfinMatchedFileStream.negotiatedTracksMatch(
            url: url("AudioStreamIndex=4&SubtitleStreamIndex=-1"), audioIndex: 4, subtitleIndex: nil,
            negotiatedAudioIndex: 1, negotiatedSubtitleIndex: -1))
        XCTAssertFalse(JellyfinMatchedFileStream.negotiatedTracksMatch(
            url: url("AudioStreamIndex=4&SubtitleStreamIndex=-1&SubtitleStreamIndex"),
            audioIndex: 4, subtitleIndex: nil, negotiatedSubtitleIndex: -1))
        for method in ["Embed", "External", ""] {
            XCTAssertFalse(JellyfinMatchedFileStream.negotiatedTracksMatch(
                url: url("AudioStreamIndex=1&SubtitleStreamIndex=5&SubtitleMethod=" + method), audioIndex: 1, subtitleIndex: 5))
        }
    }

    @MainActor
    func testRuntimeReportsVerifiedOriginalIndexesAndActiveSidecarSeparatelyFromOff() {
        let controls = GreenfieldPlaybackControls()
        controls.isReady = true
        controls.audioTracks = [.init(id: 4, name: "fourth")]
        controls.selectedAudioTrackID = 4
        XCTAssertNil(controls.runtimeState(orientationMode: .landscape).sourceAudioStreamIndex,
                     "AVFoundation IDs cannot be assumed to be FFmpeg stream indexes")
        controls.originalStreamIndexesKnown = true
        controls.subtitleAction = { _ in }
        controls.externalSubtitleAction = { _ in }
        controls.selectSourceSubtitle(nil, externalURL: nil)
        let off = controls.runtimeState(orientationMode: .landscape)
        XCTAssertEqual(off.sourceAudioStreamIndex, 4)
        XCTAssertTrue(off.subtitlesDisabled)
        let external = URL(fileURLWithPath: "/fixture/current.srt")
        controls.selectSourceSubtitle(nil, externalURL: external)
        let sidecar = controls.runtimeState(orientationMode: .landscape)
        XCTAssertFalse(sidecar.subtitlesDisabled)
        XCTAssertEqual(sidecar.activeExternalSubtitleURL, external)
        controls.selectSourceSubtitle(nil, externalURL: nil)
        XCTAssertNil(controls.runtimeState(orientationMode: .landscape).activeExternalSubtitleURL)
        controls.beginSession()
        XCTAssertNil(controls.runtimeState(orientationMode: .landscape).sourceAudioStreamIndex)
    }

    @MainActor
    func testSidecarRemainsAvailableInCatalogWhileCurrentSelectionIsOff() {
        var match = fallbackMatch()
        match.mediaStreams.append(.init(codec: "ass", index: 5, type: .subtitle))
        let url = URL(fileURLWithPath: "/fixture/current.srt")
        let catalog = JellyfinMatchedFileStream.subtitleCatalog(match: match, availableExternalSubtitleURL: url)
        XCTAssertEqual(catalog.map(\.id), [5, -2])
        XCTAssertEqual(catalog.last?.externalURL, url)
        XCTAssertEqual(JellyfinMatchedFileStream.verifiedTracks(match: match, runtime: fallbackRuntime()),
                       .init(audioIndex: 1, subtitleIndex: nil, externalSubtitleURL: nil))
    }

    @MainActor
    func testVerifiedFileHLSTimelineDoesNotAddServerStartToAnAbsoluteClock() {
        let request = MediaPlaybackRequest(url: URL(string: "https://example.com/file.m3u8")!,
            title: "fixture", source: .dsmFile, fileExtensionOverride: "m3u8",
            timelineOffsetSeconds: 72.919333, timelineDomain: .sourceAbsolute)
        let runtime = fallbackRuntime(position: 78.878)
        XCTAssertEqual(78.876667 + request.rendererTimelineOffsetSeconds, 78.876667, accuracy: 0.000001)
        XCTAssertEqual(request.timelineOffsetSeconds, 72.919333)
        XCTAssertEqual(request.applyingRuntimePreferences(runtime).rendererTimelineOffsetSeconds, 0)
        let copied = request.playbackRequest(using: .init(url: request.url, fileExtensionOverride: "m3u8"), runtimeState: runtime)
        XCTAssertEqual(copied.rendererTimelineOffsetSeconds, 0)
        let relative = MediaPlaybackRequest(url: URL(string: "https://example.com/fragment.mp4")!,
            title: "fixture", source: .dsmFile, timelineOffsetSeconds: 12)
        XCTAssertEqual(relative.rendererTimelineOffsetSeconds, 12)
        let jellyfin = MediaPlaybackRequest(url: request.url, title: "fixture", source: .jellyfin,
            fileExtensionOverride: "m3u8", timelineOffsetSeconds: 72.919333)
        XCTAssertEqual(jellyfin.rendererTimelineOffsetSeconds, 0)
    }

    @MainActor
    func testNegotiatedFileReplacementDoesNotRestoreStaleBookmarkTracksOrOff() throws {
        let suite = "fixture-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        store.save(key: "file", position: 12, duration: 7200,
                   audioTrackID: 4, subtitleTrackID: nil, subtitlesDisabled: true)
        let request = MediaPlaybackRequest(url: URL(string: "https://example.com/stream.m3u8")!,
            title: "fixture", source: .dsmFile, fileExtensionOverride: "m3u8",
            timelineOffsetSeconds: 38.25, totalDurationSeconds: 7200,
            sourceAudioTracks: [.init(id: 1, name: "live")],
            sourceSubtitleTracks: [.init(id: 5, name: "live")],
            selectedSourceAudioTrackID: 1, selectedSourceSubtitleTrackID: 5,
            sourceTrackRequestLoader: { _, _, _ in nil }, localResumeKey: "file")
        let launch = request.greenfieldPlaybackLaunchRequest(resumeStore: store)
        XCTAssertEqual(launch.tracks.selectedSourceAudioTrackID, "1")
        XCTAssertEqual(launch.tracks.selectedSourceSubtitleTrackID, "5")
        XCTAssertEqual(launch.subtitles?.mode, .embedded)
        XCTAssertEqual(launch.mediaRequest?.timelineOffsetSeconds, 38.25)
    }

    func testUnmarkedSubtitleInventorySelectsPreferredLanguageAndKeepsDefaults() {
        let inventory: [PlaybackDefaultSubtitlePolicy.Track] = [
            .init(index: 3, language: "eng"),
            .init(index: 5, language: "chi"),
            .init(index: 8, language: "jpn")
        ]
        XCTAssertEqual(PlaybackDefaultSubtitlePolicy.select(tracks: inventory,
            serverDefault: nil, preferredLanguages: ["zh-Hans-CN", "en-US"]), 5)
        XCTAssertEqual(PlaybackDefaultSubtitlePolicy.select(tracks: inventory,
            serverDefault: nil, preferredLanguages: ["ja-JP"]), 8)
        XCTAssertEqual(PlaybackDefaultSubtitlePolicy.select(tracks: inventory,
            serverDefault: 3, preferredLanguages: ["zh-Hans"]), 3)
        XCTAssertEqual(PlaybackDefaultSubtitlePolicy.select(tracks: inventory,
            serverDefault: 99, preferredLanguages: ["zh-Hant"]), 5)
        XCTAssertEqual(PlaybackDefaultSubtitlePolicy.select(tracks: inventory,
            serverDefault: nil, preferredLanguages: ["unknown"]), 3)
        XCTAssertNil(PlaybackDefaultSubtitlePolicy.select(tracks: [], serverDefault: 3))
        let invalidAndForced: [PlaybackDefaultSubtitlePolicy.Track] = [
            .init(index: -1, language: "chi", isDefault: true),
            .init(index: 3, language: "eng", isForced: true),
            .init(index: 5, language: "chi", isDefault: true)
        ]
        XCTAssertEqual(PlaybackDefaultSubtitlePolicy.select(tracks: invalidAndForced,
            serverDefault: -1, preferredLanguages: ["zh-Hans"]), 3)
        XCTAssertEqual(PlaybackDefaultSubtitlePolicy.select(tracks: [.init(index: 7, language: nil)],
            serverDefault: nil, preferredLanguages: ["zh-Hans"]), 7)
    }

    func testPlaybackClientFinishesWeakProbeBeyondDirectoryLookupBudget() async throws {
        let payload = Data(repeating: 0x57, count: 1024 * 1024)
        let server = try PlaybackRangeTestServer(payload: payload,
            pacedBodyChunkBytes: 64 * 1024, pacedBodyDelay: 0.8)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 5)
        let url = try XCTUnwrap(server.url)
        let shortConfiguration = URLSessionConfiguration.ephemeral
        shortConfiguration.timeoutIntervalForRequest = 5
        shortConfiguration.timeoutIntervalForResource = 10
        let directorySession = URLSession(configuration: shortConfiguration)
        let playbackSession = URLSession(configuration: JellyfinPlaybackSessionPolicy.configuration())
        defer {
            directorySession.invalidateAndCancel()
            playbackSession.invalidateAndCancel()
        }
        // Same local source and pacing; no NAS credential or device state is touched.
        async let completeProbe = playbackSession.data(from: url)
        do {
            _ = try await directorySession.data(from: url)
            XCTFail("The former directory client must fail this >10-second continuous probe")
        } catch {
            XCTAssertEqual((error as NSError).domain, NSURLErrorDomain)
            XCTAssertEqual((error as NSError).code, NSURLErrorTimedOut)
        }
        let (data, response) = try await completeProbe
        XCTAssertEqual(data, payload)
        XCTAssertEqual(response.expectedContentLength, Int64(payload.count))
    }

    @MainActor
    func testLateDSMDiscoveryReachesPlaybackWithoutReturningToLibrary() throws {
        let connection = NASConnectionStore()
        let domain = try XCTUnwrap(URL(string: "https://nas.example:5001"))
        let lan = try XCTUnwrap(URL(string: "http://192.168.1.8:5000"))
        let device = NASDevice(id: UUID(), name: "Test NAS", subtitle: "DSM",
            model: nil, dsmVersion: nil, mode: .dsmOnly, cpu: nil, memory: nil,
            memoryUsedText: nil, memoryTotalText: nil, storageUsed: nil,
            storageUsedText: nil, storageTotalText: nil, storageFreeText: "-",
            uptimeMinutes: nil, temperatureText: nil, certificate: nil, sshStatus: .unavailable)
        let initial = DSMSession(baseURL: domain, sid: "same-session",
            fileStationSID: nil, account: "test", allowsSelfSignedCertificates: false,
            deviceID: nil, endpoints: DSMConnectionEndpoints(primaryDomain: domain))
        connection.connect(device: device, session: initial)
        var received: [DSMSession?] = []
        var observer: JellyfinDSMPlaybackContextObserver? = JellyfinDSMPlaybackContextObserver(
            connectionStore: connection, update: { received.append($0) })
        XCTAssertNil(received.last.flatMap { $0 }?.endpoints.lanAddress)

        // The same authentication session gains File Station and LAN context
        // after navigation has already opened a detail page. No view task or
        // onAppear is needed to deliver the discovered route.
        let discovered = DSMSession(baseURL: domain, sid: initial.sid,
            fileStationSID: "file-session", account: "test", allowsSelfSignedCertificates: false,
            deviceID: nil, endpoints: DSMConnectionEndpoints(primaryDomain: domain, lanAddress: lan))
        connection.connect(device: device, session: discovered)
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received.last.flatMap { $0 }?.sid, initial.sid)
        XCTAssertEqual(received.last.flatMap { $0 }?.endpoints.lanAddress, lan)
        XCTAssertEqual(received.last.flatMap { $0 }?.fileStationSID, "file-session")

        weak var releasedObserver = observer
        observer = nil
        XCTAssertNil(releasedObserver, "Playback teardown must release the context subscription")
        connection.connect(device: device, session: initial)
        XCTAssertEqual(received.count, 2, "A closed library must stop receiving session updates")
    }

    func testBufferedReserveMergesTouchingAndOverlappingRangesInAnyOrder() {
        XCTAssertEqual(PlaybackBufferedReservePolicy.seconds(at: 32,
            ranges: [(35, 40), (30, 34), (33, 35), (41, 50)]), 8)
        XCTAssertEqual(PlaybackBufferedReservePolicy.seconds(at: 34,
            ranges: [(34, 37), (30, 34)]), 3)
        XCTAssertEqual(PlaybackBufferedReservePolicy.seconds(at: 37,
            ranges: [(30, 37)]), 0)
    }

    func testBufferedReserveNeverCountsDisjointFutureOrPastRanges() {
        XCTAssertEqual(PlaybackBufferedReservePolicy.seconds(at: 32,
            ranges: [(35, 40)]), 0, "The old diagnostic reported eight seconds across this hole")
        XCTAssertEqual(PlaybackBufferedReservePolicy.seconds(at: 32,
            ranges: [(20, 25), (35, 40)]), 0)
        XCTAssertEqual(PlaybackBufferedReservePolicy.seconds(at: 32,
            ranges: [(30, 33), (33.001, 50)]), 1)
    }

    func testBufferedReservePreservesUnknownAndRejectsInvalidRanges() {
        for clock in [Double.nan, .infinity, -1] {
            XCTAssertNil(PlaybackBufferedReservePolicy.seconds(at: clock, ranges: [(0, 10)]))
        }
        XCTAssertNil(PlaybackBufferedReservePolicy.seconds(at: 2, ranges: []))
        XCTAssertNil(PlaybackBufferedReservePolicy.seconds(at: 2,
            ranges: [(.nan, 10), (0, .infinity), (-1, 10), (5, 4)]))
        XCTAssertEqual(PlaybackBufferedReservePolicy.seconds(at: 2,
            ranges: [(.nan, 100), (0, 5)]), 3)
    }

    func testAVItemReserveConstrainsReplacementLeadWithoutContentOffset() {
        let reserve = PlaybackBufferedReservePolicy.seconds(at: 32,
            ranges: [(30, 33.266), (40, 60)])
        let lead = PlaybackReplacementLeadPolicy.mediaSeconds(expectedPreparation: 11,
            rate: 1, isAdvancing: true, availableReserve: reserve)
        XCTAssertEqual(lead, 1.016, accuracy: 0.000001)
        XCTAssertEqual(PlaybackReplacementLeadPolicy.mediaSeconds(expectedPreparation: 11,
            rate: 1, isAdvancing: true,
            availableReserve: PlaybackBufferedReservePolicy.seconds(at: 32,
                ranges: [(40, 60)])), 0)
        // A content offset belongs to the absolute handoff target, not to item ranges.
        XCTAssertEqual(500 + 32 + lead, 533.016, accuracy: 0.000001)
    }

    func testReplacementLeadCannotOutrunDepletingOriginalReserve() {
        let lead = PlaybackReplacementLeadPolicy.mediaSeconds(expectedPreparation: 11,
            rate: 1, isAdvancing: true, availableReserve: 1.5232082913893663)
        XCTAssertEqual(lead, 1.2732082913893663, accuracy: 0.000001)
        // The observed old target was 16.607 + 11 while the live clock stalled
        // at 19.102. The bounded candidate no longer waits for that future time.
        XCTAssertLessThan(16.607 + lead, 19.102)
        XCTAssertEqual(PlaybackReplacementLeadPolicy.mediaSeconds(expectedPreparation: 11,
            rate: 1, isAdvancing: true, availableReserve: 14), 11)
        XCTAssertEqual(PlaybackReplacementLeadPolicy.mediaSeconds(expectedPreparation: 11,
            rate: 2, isAdvancing: true, availableReserve: 4), 3.75)
        XCTAssertEqual(PlaybackReplacementLeadPolicy.mediaSeconds(expectedPreparation: 11,
            rate: 1, isAdvancing: true, availableReserve: 0.1), 0)
    }

    func testReplacementLeadHandlesPauseUnknownReserveAndInvalidRate() {
        XCTAssertEqual(PlaybackReplacementLeadPolicy.mediaSeconds(expectedPreparation: 11,
            rate: 1, isAdvancing: false, availableReserve: 10), 0)
        for reserve: Double? in [nil, .nan, -1] {
            XCTAssertEqual(PlaybackReplacementLeadPolicy.mediaSeconds(expectedPreparation: 11,
                rate: 1, isAdvancing: true, availableReserve: reserve), 11)
        }
        for rate in [Double.nan, .infinity, -1, 0] {
            XCTAssertEqual(PlaybackReplacementLeadPolicy.mediaSeconds(expectedPreparation: 11,
                rate: rate, isAdvancing: true, availableReserve: 10), 0)
        }
        XCTAssertEqual(PlaybackReplacementLeadPolicy.mediaSeconds(expectedPreparation: .infinity,
            rate: 1, isAdvancing: true, availableReserve: 10), 0)
    }

    func testReserveDepletionDetectsPeakHiddenByWholeFileBitrate() {
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 64_048_290, measuredCapacity: 50_984_888,
            isPrivateRoute: false, forcesOriginal: false))
        var policy = PlaybackReserveDepletionPolicy()
        let times = [17.72, 18.72, 19.82]
        let positions = [10.484, 11.486, 12.574]
        let reserves = [3.84, 3.55, 3.34]
        var decisions: [Bool] = []
        for index in times.indices {
            decisions.append(policy.sample(now: times[index], eligible: true, seekGeneration: 0,
                currentSeconds: positions[index], aheadSeconds: reserves[index], targetSeconds: 4,
                demandBitrate: 98_000_000, measuredCapacity: 50_984_888))
        }
        XCTAssertEqual(decisions, [false, false, true])
    }

    func testPeakDemandDoesNotLowerGrowingOrSufficientReserve() {
        for (reserves, capacity) in [([3.86, 4.11, 4.27], 50_000_000),
                                     ([5.0, 4.5, 4.0], 50_000_000),
                                     ([3.8, 3.4, 3.0], 70_000_000)] {
            var policy = PlaybackReserveDepletionPolicy()
            for index in reserves.indices {
                XCTAssertFalse(policy.sample(now: Double(index), eligible: true, seekGeneration: 0,
                    currentSeconds: Double(index + 10), aheadSeconds: reserves[index], targetSeconds: 4,
                    demandBitrate: 93_000_000, measuredCapacity: capacity))
            }
        }
    }

    func testReservePredictionRequiresSustainedDemandAndKnownCapacity() {
        var policy = PlaybackReserveDepletionPolicy()
        for index in 0..<3 {
            XCTAssertFalse(policy.sample(now: Double(index), eligible: true, seekGeneration: 0,
                currentSeconds: Double(index + 10), aheadSeconds: 3.8 - Double(index) * 0.4,
                targetSeconds: 4, demandBitrate: index == 1 ? 120_000_000 : 64_000_000,
                measuredCapacity: 50_000_000))
        }
        XCTAssertFalse(policy.sample(now: 3, eligible: true, seekGeneration: 0,
            currentSeconds: 13, aheadSeconds: 2.6, targetSeconds: 4,
            demandBitrate: 100_000_000, measuredCapacity: nil))
        XCTAssertFalse(policy.sample(now: 4, eligible: true, seekGeneration: 0,
            currentSeconds: 14, aheadSeconds: 2.2, targetSeconds: 4,
            demandBitrate: 100_000_000, measuredCapacity: 50_000_000))
    }

    func testReservePredictionRejectsPausedClockSeekAndSamplingGap() {
        for mode in ["pause", "clock", "seek", "gap", "target", "invalid"] {
            var policy = PlaybackReserveDepletionPolicy()
            for index in 0..<3 {
                let interrupted = index == 2
                XCTAssertFalse(policy.sample(now: interrupted && mode == "gap" ? 10 : Double(index),
                    eligible: !(interrupted && mode == "pause"),
                    seekGeneration: interrupted && mode == "seek" ? 1 : 0,
                    currentSeconds: interrupted && mode == "clock" ? 11 : Double(index + 10),
                    aheadSeconds: interrupted && mode == "invalid" ? .nan : 3.8 - Double(index) * 0.4,
                    targetSeconds: interrupted && mode == "target" ? 8 : 4,
                    demandBitrate: 100_000_000, measuredCapacity: 50_000_000), mode)
            }
        }
    }

    func testRuntimeDemandScalesByPlaybackRateAndRejectsInvalidMetrics() {
        XCTAssertEqual(PlaybackReserveDepletionPolicy.demandBitrate(video: 90_000_000,
            audio: 3_000_000, rate: 2), 186_000_000)
        XCTAssertEqual(PlaybackReserveDepletionPolicy.demandBitrate(video: 90_000_000,
            audio: 0, rate: 0.5), 45_000_000)
        XCTAssertNil(PlaybackReserveDepletionPolicy.demandBitrate(video: Int.max, audio: 1, rate: 1))
        XCTAssertNil(PlaybackReserveDepletionPolicy.demandBitrate(video: 90_000_000, audio: nil, rate: 1))
        XCTAssertNil(PlaybackReserveDepletionPolicy.demandBitrate(video: 90_000_000, audio: -1, rate: 1))
        XCTAssertNil(PlaybackReserveDepletionPolicy.demandBitrate(video: 90_000_000, audio: 0, rate: .nan))
    }

#if DEBUG
    func testISOStopReleasesOnlyItsTitleAndPreservesWatchReports() async throws {
        let source = try XCTUnwrap(URL(string: "http://127.0.0.1:1/unused.iso"))
        let proxy = ISOPlaybackProxy.shared
        let first = try await proxy.register(sourceURL: source, allowsSelfSignedCertificates: false,
            segments: [ISOSegment(sourceOffset: 0, length: 64)], fileExtension: "m2ts")
        let other = try await proxy.register(sourceURL: source, allowsSelfSignedCertificates: false,
            segments: [ISOSegment(sourceOffset: 0, length: 128)], fileExtension: "m2ts")
        defer { proxy.unregister(first); proxy.unregister(other) }
        let preparation = ISOPlaybackPreparation(playbackURL: first, fileExtension: "m2ts",
            selectedPath: "title", titleCount: 1)
        var reports: [String] = []
        var releases = 0
        let upstream = MediaPlaybackTracker(releaseResources: { releases += 1 }) { event in
            switch event {
            case .started(let position): reports.append("start:\(position)")
            case .progressed(let position, let paused): reports.append("progress:\(position):\(paused)")
            case .stopped(let position, let failed): reports.append("stop:\(position):\(failed)")
            }
        }
        let tracker = preparation.makePlaybackTracker(reportingTo: upstream)
        tracker.started(positionSeconds: 120)
        tracker.progressed(positionSeconds: 135, isPaused: true)
        let activeStatus = try await isoRouteStatus(first)
        XCTAssertEqual(activeStatus, 200, "Active/PiP playback must retain its title")
        tracker.stopped(positionSeconds: 140)
        tracker.releasePreparedResources()
        tracker.stopped(positionSeconds: 0)
        let releasedStatus = try await isoRouteStatus(first)
        let otherStatus = try await isoRouteStatus(other)
        XCTAssertEqual(releasedStatus, 404)
        XCTAssertEqual(otherStatus, 200, "Stopping one title must not invalidate another")
        XCTAssertEqual(reports, ["start:120.0", "progress:135.0:true", "stop:140.0:false"])
        XCTAssertEqual(releases, 1)
    }

    func testAbandonedISORequestReleasesRouteWithoutWatchReports() async throws {
        let proxy = ISOPlaybackProxy.shared
        let url = try await proxy.register(sourceURL: URL(string: "http://127.0.0.1:1/unused.iso")!,
            allowsSelfSignedCertificates: false,
            segments: [ISOSegment(sourceOffset: 0, length: 64)], fileExtension: "m2ts")
        defer { proxy.unregister(url) }
        var reports = 0
        var releases = 0
        let upstream = MediaPlaybackTracker(releaseResources: { releases += 1 }) { _ in reports += 1 }
        let preparation = ISOPlaybackPreparation(playbackURL: url, fileExtension: "m2ts",
            selectedPath: "title", titleCount: 1)
        var tracker: MediaPlaybackTracker? = preparation.makePlaybackTracker(reportingTo: upstream)
        tracker?.releasePreparedResources()
        tracker?.started(positionSeconds: 0)
        tracker = nil
        let releasedStatus = try await isoRouteStatus(url)
        XCTAssertEqual(releasedStatus, 404)
        XCTAssertEqual(reports, 0)
        XCTAssertEqual(releases, 1)
    }

    private func isoRouteStatus(_ url: URL) async throws -> Int {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (_, response) = try await URLSession.shared.data(for: request)
        return try XCTUnwrap(response as? HTTPURLResponse).statusCode
    }

    func testISOProxyRebuildsStaleCachedListenerBeforeReturningURL() async throws {
        try await verifyISOProxyRecovery(preservingCachedPort: true)
    }

    func testISOProxyRebuildsAfterListenerCancellation() async throws {
        try await verifyISOProxyRecovery(preservingCachedPort: false)
    }

    private func verifyISOProxyRecovery(preservingCachedPort: Bool) async throws {
        let payload = Data((0..<128).map(UInt8.init))
        let server = try PlaybackRangeTestServer(payload: payload)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let upstream = try XCTUnwrap(server.url)
        let proxy = ISOPlaybackProxy()
        let initial = try await proxy.register(sourceURL: upstream, allowsSelfSignedCertificates: false,
            segments: [ISOSegment(sourceOffset: 16, length: 64)], fileExtension: "m2ts")
        defer { proxy.unregister(initial) }
        await proxy.stopListenerForTesting(preservingCachedPort: preservingCachedPort)
        let recovered = try await proxy.register(sourceURL: upstream, allowsSelfSignedCertificates: false,
            segments: [ISOSegment(sourceOffset: 16, length: 64)], fileExtension: "m2ts")
        defer { proxy.unregister(recovered) }
        var request = URLRequest(url: recovered)
        request.timeoutInterval = 3
        request.setValue("bytes=8-15", forHTTPHeaderField: "Range")
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 206)
        XCTAssertEqual(http.value(forHTTPHeaderField: "Content-Range"), "bytes 8-15/64")
        XCTAssertEqual(data, payload.subdata(in: 24..<32), "Recovered proxy must still map ISO offsets correctly")
        proxy.unregister(initial)
        var oldRouteAtNewPort = try XCTUnwrap(URLComponents(url: initial, resolvingAgainstBaseURL: false))
        oldRouteAtNewPort.port = recovered.port
        var releasedRequest = URLRequest(url: try XCTUnwrap(oldRouteAtNewPort.url))
        releasedRequest.httpMethod = "HEAD"
        releasedRequest.timeoutInterval = 3
        let (_, releasedResponse) = try await URLSession.shared.data(for: releasedRequest)
        XCTAssertEqual((releasedResponse as? HTTPURLResponse)?.statusCode, 404,
            "Routes created on the old listener must still be releasable after restart")
    }

    func testISOProxyConcurrentRegistrationsShareListener() async throws {
        let proxy = ISOPlaybackProxy()
        let source = try XCTUnwrap(URL(string: "http://127.0.0.1:1/unused.iso"))
        async let first = proxy.register(sourceURL: source, allowsSelfSignedCertificates: false,
            segments: [ISOSegment(sourceOffset: 0, length: 64)], fileExtension: "m2ts")
        async let second = proxy.register(sourceURL: source, allowsSelfSignedCertificates: false,
            segments: [ISOSegment(sourceOffset: 0, length: 128)], fileExtension: "m2ts")
        let urls = try await [first, second]
        defer { urls.forEach { proxy.unregister($0) } }
        XCTAssertEqual(urls[0].port, urls[1].port)
        XCTAssertNotEqual(urls[0].path, urls[1].path)
        for (url, expectedLength) in zip(urls, [64, 128]) {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 3
            let (_, response) = try await URLSession.shared.data(for: request)
            let http = try XCTUnwrap(response as? HTTPURLResponse)
            XCTAssertEqual(http.statusCode, 200)
            XCTAssertEqual(http.value(forHTTPHeaderField: "Content-Length"), String(expectedLength))
        }
    }

    @MainActor
    func testPreparedResultHoldCancelsPromptlyAndReleasesWithoutPresenting() async {
        let preparation = PlaybackPreparation()
        let held = expectation(description: "prepared result reached hold")
        let released = expectation(description: "prepared resources released")
        var releaseCount = 0
        var presented = false
        preparation.start { id in
            held.fulfill()
            await preparation.holdPreparedResultForDebugIfRequested(id, entry: "test", delaySeconds: 10)
            guard preparation.isCurrent(id) else {
                releaseCount += 1
                released.fulfill()
                return
            }
            presented = true
        }
        await fulfillment(of: [held], timeout: 2)
        preparation.cancel()
        await fulfillment(of: [released], timeout: 2)
        XCTAssertEqual(releaseCount, 1)
        XCTAssertFalse(presented)
        XCTAssertFalse(preparation.isPreparing)
    }
#endif

    @MainActor
    func testPlaybackPreparationRejectsLateResultAfterLeavingDetail() async {
        let preparation = PlaybackPreparation()
        let started = expectation(description: "request started")
        let returned = expectation(description: "cancel-ignoring service returned")
        var response: CheckedContinuation<Void, Never>?
        var presented = false
        preparation.start { id in
            await withCheckedContinuation { response = $0; started.fulfill() }
            defer { returned.fulfill() }
            guard preparation.isCurrent(id) else { return }
            presented = true
        }
        await fulfillment(of: [started], timeout: 3)
        preparation.cancel()
        XCTAssertFalse(preparation.isPreparing)
        response?.resume()
        await fulfillment(of: [returned], timeout: 3)
        XCTAssertFalse(presented, "A late response must not reopen a dismissed detail's player")
    }

    @MainActor
    func testPlaybackPreparationOldCompletionCannotClearOrReplaceNewRequest() async {
        let preparation = PlaybackPreparation()
        let oldStarted = expectation(description: "old started")
        let newStarted = expectation(description: "new started")
        let oldReturned = expectation(description: "old returned")
        let newReturned = expectation(description: "new returned")
        var oldResponse: CheckedContinuation<Void, Never>?
        var newResponse: CheckedContinuation<Void, Never>?
        var presented: [String] = []
        preparation.start { id in
            await withCheckedContinuation { oldResponse = $0; oldStarted.fulfill() }
            defer { oldReturned.fulfill() }
            guard preparation.isCurrent(id) else { return }
            presented.append("old")
        }
        await fulfillment(of: [oldStarted], timeout: 3)
        preparation.start { id in
            await withCheckedContinuation { newResponse = $0; newStarted.fulfill() }
            defer { newReturned.fulfill() }
            guard preparation.isCurrent(id) else { return }
            presented.append("new")
        }
        await fulfillment(of: [newStarted], timeout: 3)
        oldResponse?.resume()
        await fulfillment(of: [oldReturned], timeout: 3)
        XCTAssertTrue(preparation.isPreparing, "Old completion must not enable actions during the new preparation")
        XCTAssertTrue(presented.isEmpty)
        newResponse?.resume()
        await fulfillment(of: [newReturned], timeout: 3)
        XCTAssertEqual(presented, ["new"])
        XCTAssertFalse(preparation.isPreparing)
    }

    func testFileStationDownloadUsesItsOwnSession() throws {
        let session = DSMSession(
            baseURL: try XCTUnwrap(URL(string: "https://nas.example:5001")),
            sid: "main-session",
            fileStationSID: "file-session",
            account: "test",
            allowsSelfSignedCertificates: false,
            deviceID: nil
        )
        let url = try XCTUnwrap(session.fileStationOpenURL(path: "/video/movie.mp4"))
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "_sid" })?.value, "file-session")
    }

    func testFileStationDownloadFallsBackToMainSessionBeforeSecondaryLogin() throws {
        let session = DSMSession(
            baseURL: try XCTUnwrap(URL(string: "https://nas.example:5001")),
            sid: "main-session",
            fileStationSID: nil,
            account: "test",
            allowsSelfSignedCertificates: false,
            deviceID: nil
        )
        let url = try XCTUnwrap(session.fileStationOpenURL(path: "/video/movie.mp4"))
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "_sid" })?.value, "main-session")
    }

    func testFileStationPlaybackOffersDiscoveredLANBeforePublicDomain() throws {
        let domain = try XCTUnwrap(URL(string: "https://nas.example:5001"))
        let lan = try XCTUnwrap(URL(string: "http://192.168.1.8:5000"))
        let session = DSMSession(
            baseURL: domain,
            sid: "main-session",
            fileStationSID: "file-session",
            account: "test",
            allowsSelfSignedCertificates: false,
            deviceID: nil,
            endpoints: DSMConnectionEndpoints(primaryDomain: domain, lanAddress: lan)
        )
        let candidates = session.fileStationOpenURLs(path: "/video/movie.mkv")
        XCTAssertEqual(candidates.first?.host, lan.host)
        XCTAssertEqual(candidates.last?.host, domain.host)
        XCTAssertEqual(session.fileStationOpenURL(path: "/video/movie.mkv")?.host, domain.host)
        XCTAssertTrue(candidates.allSatisfy { url in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first(where: { $0.name == "_sid" })?.value == "file-session"
        })
    }

    func testAutomaticDownshiftRequiresSustainedBufferingAndCoolsDown() {
        var policy = PlaybackStallDownshiftPolicy()
        var triggers: [Int] = []
        for second in 0...90 {
            if policy.sample(now: Double(second), eligible: true, buffering: true, seekGeneration: 0) {
                triggers.append(second)
            }
        }
        XCTAssertEqual(triggers, [18, 86])
    }

    func testAutomaticDownshiftIgnoresHealthyPlaybackPauseAndSeek() {
        var policy = PlaybackStallDownshiftPolicy()
        for second in 0...120 {
            XCTAssertFalse(policy.sample(now: Double(second), eligible: true,
                buffering: false, seekGeneration: 0))
        }
        for second in 121...160 {
            XCTAssertFalse(policy.sample(now: Double(second), eligible: false,
                buffering: true, seekGeneration: 0))
        }
        for second in 161...190 {
            XCTAssertFalse(policy.sample(now: Double(second), eligible: true,
                buffering: true, seekGeneration: second / 5))
        }
    }

    func testRepeatedShortStallsDownshiftButIsolatedStallsExpire() {
        var frequent = PlaybackStallDownshiftPolicy()
        var isolated = PlaybackStallDownshiftPolicy()
        var frequentTriggers = 0
        for second in 0...180 {
            if frequent.sample(now: Double(second), eligible: true,
                buffering: second % 10 < 5, seekGeneration: 0) { frequentTriggers += 1 }
            XCTAssertFalse(isolated.sample(now: Double(second), eligible: true,
                buffering: second % 70 < 5, seekGeneration: 0))
        }
        XCTAssertGreaterThan(frequentTriggers, 0)
    }

    func testThreeBriefRebuffersTriggerBeforeTwelveSecondsOfTotalStall() {
        var policy = PlaybackStallDownshiftPolicy()
        var triggers: [Int] = []
        for second in 0...35 {
            let buffering = (12...13).contains(second)
                || (18...19).contains(second)
                || (24...25).contains(second)
            if policy.sample(now: Double(second), eligible: true,
                             buffering: buffering, seekGeneration: 0) {
                triggers.append(second)
            }
        }
        XCTAssertEqual(triggers, [24])
    }

    func testSuspendedSamplerDoesNotCountBackgroundTimeAsBuffering() {
        var policy = PlaybackStallDownshiftPolicy()
        XCTAssertFalse(policy.sample(now: 0, eligible: true, buffering: true, seekGeneration: 0))
        XCTAssertFalse(policy.sample(now: 100, eligible: true, buffering: true, seekGeneration: 0))
        XCTAssertFalse(policy.sample(now: 101, eligible: true, buffering: true, seekGeneration: 0))
    }

    func testHLSSegmentCapacityIncludesRequestLatency() throws {
        let seconds = try XCTUnwrap(PlaybackTransferCapacityPolicy.seconds(isHLSSegment: true,
            fetchStart: Date(timeIntervalSince1970: 100),
            responseStart: Date(timeIntervalSince1970: 108),
            responseEnd: Date(timeIntervalSince1970: 110)))
        XCTAssertEqual(seconds, 10)
        let store = PlaybackRecentThroughputStore()
        store.record(traceID: "hls", bytes: 4_000_000, seconds: seconds,
            backpressureSeconds: 0, now: 10)
        XCTAssertEqual(store.estimate(traceID: "hls", now: 10), 3_200_000)
        XCTAssertTrue(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 8_000_000, measuredCapacity: store.estimate(traceID: "hls", now: 10),
            isPrivateRoute: false, forcesOriginal: false))
    }

    func testRangeCapacityKeepsResponseBodyBoundary() throws {
        let seconds = try XCTUnwrap(PlaybackTransferCapacityPolicy.seconds(isHLSSegment: false,
            fetchStart: Date(timeIntervalSince1970: 100),
            responseStart: Date(timeIntervalSince1970: 108),
            responseEnd: Date(timeIntervalSince1970: 110)))
        XCTAssertEqual(seconds, 2)
        let store = PlaybackRecentThroughputStore()
        store.record(traceID: "range", bytes: 4_000_000, seconds: seconds,
            backpressureSeconds: 0, now: 10)
        XCTAssertEqual(store.estimate(traceID: "range", now: 10), 16_000_000)
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 8_000_000, measuredCapacity: store.estimate(traceID: "range", now: 10),
            isPrivateRoute: false, forcesOriginal: false))
    }

    func testTransferCapacityRejectsUnknownOrInvertedBoundaries() {
        let start = Date(timeIntervalSince1970: 100), end = Date(timeIntervalSince1970: 102)
        XCTAssertNil(PlaybackTransferCapacityPolicy.seconds(isHLSSegment: true,
            fetchStart: nil, responseStart: start, responseEnd: end))
        XCTAssertNil(PlaybackTransferCapacityPolicy.seconds(isHLSSegment: true,
            fetchStart: end, responseStart: start, responseEnd: end))
        XCTAssertNil(PlaybackTransferCapacityPolicy.seconds(isHLSSegment: true,
            fetchStart: start, responseStart: nil, responseEnd: end))
        XCTAssertNil(PlaybackTransferCapacityPolicy.seconds(isHLSSegment: false,
            fetchStart: nil, responseStart: end, responseEnd: start))
        XCTAssertNil(PlaybackTransferCapacityPolicy.seconds(isHLSSegment: true,
            fetchStart: Date(timeIntervalSince1970: .nan), responseStart: start, responseEnd: end))
        XCTAssertEqual(PlaybackTransferCapacityPolicy.seconds(isHLSSegment: false,
            fetchStart: nil, responseStart: start, responseEnd: end), 2)
    }

    func testHLSTransferCapacityKeepsBackpressureAndTraceIsolation() throws {
        let seconds = try XCTUnwrap(PlaybackTransferCapacityPolicy.seconds(isHLSSegment: true,
            fetchStart: Date(timeIntervalSince1970: 100),
            responseStart: Date(timeIntervalSince1970: 108),
            responseEnd: Date(timeIntervalSince1970: 110)))
        let store = PlaybackRecentThroughputStore()
        store.record(traceID: "pressured", bytes: 4_000_000, seconds: seconds,
            backpressureSeconds: 1, now: 10)
        store.record(traceID: "hls", bytes: 4_000_000, seconds: seconds,
            backpressureSeconds: 0, now: 10)
        store.record(traceID: "other", bytes: 4_000_000, seconds: 1,
            backpressureSeconds: 0, now: 11)
        XCTAssertNil(store.estimate(traceID: "pressured", now: 11))
        XCTAssertEqual(store.estimate(traceID: "hls", now: 11), 3_200_000)
        XCTAssertEqual(store.estimate(traceID: "other", now: 11), 32_000_000)
        XCTAssertNil(store.estimate(traceID: "hls", now: 71))
    }

    func testRecentRangeCapacityRejectsPlayerBackpressureAndExpires() {
        let samples = PlaybackRecentThroughputStore()
        samples.record(traceID: "A", bytes: 3_000_000, seconds: 2,
                       backpressureSeconds: 0, now: 10)
        samples.record(traceID: "A", bytes: 3_000_000, seconds: 8,
                       backpressureSeconds: 4, now: 11)
        samples.record(traceID: "B", bytes: 3_000_000, seconds: 1,
                       backpressureSeconds: 0, now: 12)
        XCTAssertEqual(samples.estimate(traceID: "A", now: 12), 12_000_000)
        XCTAssertNil(samples.estimate(traceID: "A", now: 72))
    }

    func testBufferedHandoffSeekCannotJumpAcrossMissingOrInsufficientBuffer() {
        let target: ([(Double, Double)], Bool) -> Double? = { ranges, advancing in
            PlaybackBufferedHandoffSeekPolicy.target(candidate: 17.5, live: 30,
                rate: 1, isAdvancing: advancing, duration: 120,
                ranges: ranges.map { (start: $0.0, end: $0.1) })
        }
        XCTAssertNil(target([(16, 24)], true))
        XCTAssertNil(target([(16, 29), (31, 40)], true))
        XCTAssertNil(target([(16, 30.7)], true))
        XCTAssertEqual(target([(16, 34)], true), 30.25)
        XCTAssertEqual(target([(16, 34)], false), 30)
        XCTAssertNil(PlaybackBufferedHandoffSeekPolicy.target(candidate: 29, live: 30,
            rate: 1, isAdvancing: true, duration: 120, ranges: [(0, 120)]))
        XCTAssertNil(PlaybackBufferedHandoffSeekPolicy.target(candidate: 17.5, live: .nan,
            rate: 1, isAdvancing: true, duration: 120, ranges: [(0, 120)]))
        XCTAssertNil(PlaybackBufferedHandoffSeekPolicy.target(candidate: 17.5, live: 30,
            rate: 1, isAdvancing: true, duration: 30.5, ranges: [(0, 120)]))
    }

    func testBufferedHandoffCorrectsAheadCandidateWhenOriginalStops() {
        // Actual failed warmup: decoded candidate 6.339, original stalled at
        // 6.131. Pausing the candidate cannot make the original catch up.
        XCTAssertEqual(PlaybackBufferedHandoffSeekPolicy.target(
            candidate: 6.339233899, live: 6.131, rate: 1,
            isAdvancing: false, duration: 1000,
            ranges: [(start: 5, end: 10)]), 6.131)
        XCTAssertNil(PlaybackBufferedHandoffSeekPolicy.target(
            candidate: 6.339233899, live: 6.131, rate: 1,
            isAdvancing: true, duration: 1000,
            ranges: [(start: 5, end: 10)]))
        XCTAssertNil(PlaybackBufferedHandoffSeekPolicy.target(
            candidate: 6.18, live: 6.131, rate: 1,
            isAdvancing: false, duration: 1000,
            ranges: [(start: 5, end: 10)]))
    }

    func testBufferedOvershootCorrectionCannotCrossUnloadedTime() {
        let target: ([(Double, Double)]) -> Double? = { ranges in
            PlaybackBufferedHandoffSeekPolicy.target(candidate: 6.339233899,
                live: 6.131, rate: 1, isAdvancing: false, duration: 1000,
                ranges: ranges.map { (start: $0.0, end: $0.1) })
        }
        XCTAssertNil(target([]))
        XCTAssertNil(target([(6.2, 10)]))
        XCTAssertNil(target([(5, 6.5)]))
        XCTAssertNil(target([(5, 6.3), (6.4, 10)]))
        XCTAssertNil(target([(.nan, 10)]))
        XCTAssertEqual(target([(0, 1), (5, 10)]), 6.131)
    }

    func testHandoffRequiresAlignedFrameAndContinuousForwardReserve() {
        let ready: (Double, Double, [(Double, Double)]) -> Bool = { candidate, frame, ranges in
            PlaybackHandoffReadinessPolicy.isReady(candidate: candidate, live: 6.281,
                frame: frame, ranges: ranges.map { (start: $0.0, end: $0.1) })
        }
        // This real baseline frame passed the old clock/frame-only gate with
        // zero candidate reserve, followed by two live AV buffering counts.
        XCTAssertFalse(ready(6.203634334, 6.172822222, []))
        XCTAssertFalse(ready(6.203634334, 6.172822222, [(5, 6.4)]))
        XCTAssertFalse(ready(6.203634334, 6.172822222, [(5, 6.4), (6.5, 10)]))
        XCTAssertFalse(ready(6.203634334, 6.172822222, [(6.3, 10)]))
        XCTAssertTrue(ready(6.203634334, 6.172822222, [(5, 10)]))
        XCTAssertFalse(ready(6.5, 6.48, [(5, 10)]))
        XCTAssertFalse(ready(6.28, 6.0, [(5, 10)]))
        XCTAssertFalse(ready(.nan, 6.28, [(5, 10)]))
        XCTAssertFalse(ready(6.28, .infinity, [(5, 10)]))
    }

    func testHandoffRevalidatesClockAfterAsyncSessionPreparation() {
        XCTAssertTrue(PlaybackHandoffReadinessPolicy.canCommit(candidate: 5.650946251,
            live: 5.598, ranges: [(start: 4.004, end: 6.436)]))
        XCTAssertFalse(PlaybackHandoffReadinessPolicy.canCommit(candidate: 5.777352731,
            live: 5.598, ranges: [(start: 4.004, end: 6.436)]))
        XCTAssertFalse(PlaybackHandoffReadinessPolicy.canCommit(candidate: 5.65,
            live: 5.65, ranges: [(start: 4.004, end: 6.0)]))
    }

    func testOriginalWarmupCannotOverrideLateLANOrBearerChange() {
        let remote = URL(string: "https://media.example:8097")!
        let local = URL(string: "http://192.168.10.20:8096")!
        XCTAssertFalse(PlaybackOriginalWarmupPolicy.matches(warmedEndpoint: remote,
            currentEndpoint: local, warmedNetwork: "wifi", currentNetwork: "wifi"))
        XCTAssertFalse(PlaybackOriginalWarmupPolicy.matches(warmedEndpoint: remote,
            currentEndpoint: remote, warmedNetwork: "wifi", currentNetwork: "cellular"))
        XCTAssertFalse(PlaybackOriginalWarmupPolicy.matches(warmedEndpoint: remote,
            currentEndpoint: URL(string: "https://media.example:8098")!,
            warmedNetwork: "wifi", currentNetwork: "wifi"))
        XCTAssertTrue(PlaybackOriginalWarmupPolicy.matches(warmedEndpoint: local,
            currentEndpoint: local, warmedNetwork: "wifi", currentNetwork: "wifi"))
    }

    func testLANPlaybackVerificationIsReusableOnlyOnItsObservedPath() {
        let lan = URL(string: "http://192.168.10.20:8096")!
        let wifi = PlaybackNetworkSnapshot(cacheKey: "wifi", bitrateCap: nil,
            fallbackBitrate: 8_000_000, pathGeneration: 1)
        var cache = JellyfinLANPlaybackRouteCache()
        XCTAssertNil(cache.endpoint(on: wifi))
        XCTAssertTrue(cache.publish(lan, startedOn: wifi, current: wifi))
        XCTAssertEqual(cache.endpoint(on: wifi), lan)
    }

    func testAuthenticatedOriginIdentityRequiresSuccessfulCurrentUserResponse() throws {
        let data = Data(#"{"Id":"account-A","ServerId":"server-A"}"#.utf8)
        let identity = try XCTUnwrap(JellyfinAuthenticatedIdentity.response(data: data, status: 200))
        XCTAssertTrue(JellyfinAuthenticatedIdentity.matches(primary: identity, candidate: identity,
            expectedUserID: "account-A"))
        for status in [302, 401, 403, 500] {
            XCTAssertNil(JellyfinAuthenticatedIdentity.response(data: data, status: status))
        }
    }

    @MainActor
    func testOverlappedPublicProofWaitsForPrivateTransportFailure() async {
        let primary = ControlledIdentityProbe()
        let candidate = ControlledIdentityProbe()
        let session = UUID()
        let network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 7)
        let pair = JellyfinOverlappingIdentityProbes(candidateEndpoint: URL(string: "https://public.invalid")!,
            network: network, session: session, primary: { await primary.run() }, candidate: { await candidate.run() })
        defer { pair.cancel() }
        await fulfillment(of: [primary.started, candidate.started], timeout: 2)
        let identity = JellyfinAuthenticatedIdentity(userID: "account-A", serverID: "server-A")
        candidate.finish(with: (identity, 200, nil))
        let early = await pair.candidateResult(on: network, session: session, credentialsCurrent: true)
        XCTAssertNil(early, "A fast public reply must not overrule a still-pending private route")
        primary.finish(with: (nil, nil, "URL_-1001"))
        let base = await pair.primaryResult()
        XCTAssertEqual(base.failure, "URL_-1001")
        let usable = await pair.candidateResult(on: network, session: session, credentialsCurrent: true)
        XCTAssertEqual(usable?.identity, identity)
    }

    @MainActor
    func testOverlappedReachablePrivateRouteCancelsPendingPublicWithoutWaitingForIt() async {
        let primary = ControlledIdentityProbe()
        let candidate = ControlledIdentityProbe()
        let session = UUID()
        let network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 7)
        let pair = JellyfinOverlappingIdentityProbes(candidateEndpoint: URL(string: "https://public.invalid")!,
            network: network, session: session, primary: { await primary.run() }, candidate: { await candidate.run() })
        defer { pair.cancel() }
        await fulfillment(of: [primary.started, candidate.started], timeout: 2)
        let identity = JellyfinAuthenticatedIdentity(userID: "account-A", serverID: "server-A")
        primary.finish(with: (identity, 200, nil))
        let base = await pair.primaryResult()
        XCTAssertEqual(base.identity, identity)
        let fallback = await pair.candidateResult(on: network, session: session, credentialsCurrent: true)
        XCTAssertNil(fallback)
        await fulfillment(of: [candidate.finished], timeout: 2)
        XCTAssertTrue(candidate.wasCancelled)
    }

    @MainActor
    func testOverlappedPublicProofCannotOverridePrivateHTTPRejection() async {
        for status in [302, 401, 403, 500] {
            let primary = ControlledIdentityProbe()
            let candidate = ControlledIdentityProbe()
            let session = UUID()
            let network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
                fallbackBitrate: 2_000_000, pathGeneration: 7)
            let pair = JellyfinOverlappingIdentityProbes(candidateEndpoint: URL(string: "https://public.invalid")!,
                network: network, session: session, primary: { await primary.run() }, candidate: { await candidate.run() })
            await fulfillment(of: [primary.started, candidate.started], timeout: 2)
            candidate.finish(with: (.init(userID: "account-A", serverID: "server-A"), 200, nil))
            primary.finish(with: (nil, status, nil))
            let base = await pair.primaryResult()
            XCTAssertEqual(base.status, status)
            let fallback = await pair.candidateResult(on: network, session: session, credentialsCurrent: true)
            XCTAssertNil(fallback)
            pair.cancel()
        }
    }

    @MainActor
    func testOverlappedPublicRequestIsDiscardedForChangedPathLoginOrCredentials() async {
        for fault in 0..<4 {
            let primary = ControlledIdentityProbe()
            let candidate = ControlledIdentityProbe()
            let session = UUID()
            let network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
                fallbackBitrate: 2_000_000, pathGeneration: 7)
            let pair = JellyfinOverlappingIdentityProbes(candidateEndpoint: URL(string: "https://public.invalid")!,
                network: network, session: session, primary: { await primary.run() }, candidate: { await candidate.run() })
            await fulfillment(of: [primary.started, candidate.started], timeout: 2)
            primary.finish(with: (nil, nil, "URL_-1004"))
            _ = await pair.primaryResult()
            let current = PlaybackNetworkSnapshot(cacheKey: fault == 3 ? "unknown" : "cellular", bitrateCap: nil,
                fallbackBitrate: 2_000_000, pathGeneration: fault == 0 ? 8 : 7)
            let fallback = await pair.candidateResult(on: current,
                session: fault == 1 ? UUID() : session, credentialsCurrent: fault != 2)
            XCTAssertNil(fallback)
            await fulfillment(of: [candidate.finished], timeout: 2)
            XCTAssertTrue(candidate.wasCancelled)
            pair.cancel()
        }
    }

    @MainActor
    func testParentCancellationReachesBothOverlappingIdentityRequests() async {
        let primary = ControlledIdentityProbe()
        let candidate = ControlledIdentityProbe()
        let network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 7)
        let pair = JellyfinOverlappingIdentityProbes(candidateEndpoint: URL(string: "https://public.invalid")!,
            network: network, session: UUID(), primary: { await primary.run() }, candidate: { await candidate.run() })
        defer { pair.cancel() }
        let parent = Task { await pair.primaryResult() }
        await fulfillment(of: [primary.started, candidate.started], timeout: 2)
        parent.cancel()
        let result = await parent.value
        XCTAssertEqual(result.failure, "URL_-999")
        await fulfillment(of: [primary.finished, candidate.finished], timeout: 2)
        XCTAssertTrue(primary.wasCancelled)
        XCTAssertTrue(candidate.wasCancelled)
    }

    @MainActor
    func testParentCancellationWhileConsumingPublicProofCancelsItsRequest() async {
        let primary = ControlledIdentityProbe()
        let candidate = ControlledIdentityProbe()
        let session = UUID()
        let network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 7)
        let pair = JellyfinOverlappingIdentityProbes(candidateEndpoint: URL(string: "https://public.invalid")!,
            network: network, session: session, primary: { await primary.run() }, candidate: { await candidate.run() })
        defer { pair.cancel() }
        await fulfillment(of: [primary.started, candidate.started], timeout: 2)
        primary.finish(with: (nil, nil, "URL_-1001"))
        _ = await pair.primaryResult()
        let parent = Task { await pair.candidateResult(on: network, session: session, credentialsCurrent: true) }
        await Task.yield()
        parent.cancel()
        _ = await parent.value
        await fulfillment(of: [candidate.finished], timeout: 2)
        XCTAssertTrue(candidate.wasCancelled)
    }

    @MainActor
    func testPreparedContextsKeepSeparateClientsAndRoutesAcrossConcurrentAwaits() async throws {
        let network = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 4)
        func context(_ host: String, _ token: String) -> JellyfinPreparedContext {
            let url = URL(string: "https://\(host).invalid:8097")!
            let client = JellyfinClient(configuration: .init(url: url,
                accessToken: token, client: "Fixture", deviceName: "Fixture", deviceID: "Fixture", version: "1"))
            return .init(client: client, endpoint: url, owner: UUID(), session: UUID(), network: network,
                primary: nil, selected: nil, selection: "fixture")
        }
        let left = context("left", "left-own-token")
        let right = context("right", "right-own-token")
        @Sendable func observe(_ context: JellyfinPreparedContext) async -> [String] {
            await JellyfinPreparedContextScope.$current.withValue(context) {
                var observations = [String]()
                for _ in 0..<20 {
                    await Task.yield()
                    if let current = JellyfinPreparedContextScope.current {
                        observations.append(current.endpoint.absoluteString + "|" + (current.client.accessToken ?? ""))
                    }
                }
                let child = await Task { JellyfinPreparedContextScope.current?.owner }.value
                if child != context.owner { observations.append("wrong-child-owner") }
                return observations
            }
        }
        XCTAssertNil(JellyfinPreparedContextScope.current)
        async let leftObservations = observe(left)
        async let rightObservations = observe(right)
        let (a, b) = await (leftObservations, rightObservations)
        XCTAssertEqual(a.count, 20)
        XCTAssertEqual(b.count, 20)
        XCTAssertTrue(a.allSatisfy { $0 == left.endpoint.absoluteString + "|left-own-token" })
        XCTAssertTrue(b.allSatisfy { $0 == right.endpoint.absoluteString + "|right-own-token" })
        XCTAssertNil(JellyfinPreparedContextScope.current)
    }

    func testPrivateTransportFailureMayTriggerFreshPublicProofButNeverPublishPriorPathIdentity() {
        let login = UUID()
        func path(_ generation: UInt64, _ key: String = "cellular") -> PlaybackNetworkSnapshot {
            .init(cacheKey: key, bitrateCap: nil, fallbackBitrate: 2_000_000, pathGeneration: generation)
        }
        func permits(_ current: PlaybackNetworkSnapshot, status: Int? = nil, failure: String? = "URL_-1001",
                     session: UUID? = nil, credentials: Bool = true, cancelled: Bool = false) -> Bool {
            JellyfinAuthenticatedFallbackPolicy.canProbeCurrentPublic(startedOn: path(3), current: current,
                startedSession: login, currentSession: session ?? login, primaryStatus: status,
                primaryFailure: failure, credentialsUnchanged: credentials, cancelled: cancelled)
        }
        XCTAssertTrue(permits(path(5)))
        XCTAssertFalse(JellyfinAuthenticatedIdentity.canPublish(startedOn: path(3), current: path(5),
            startedSession: login, currentSession: login, cancelled: false))
        XCTAssertTrue(JellyfinAuthenticatedIdentity.canPublish(startedOn: path(5), current: path(5),
            startedSession: login, currentSession: login, cancelled: false))
        XCTAssertFalse(permits(path(6, "wifi")))
        XCTAssertFalse(permits(path(0)))
        for code in [200, 302, 401, 403, 500] { XCTAssertFalse(permits(path(5), status: code)) }
        XCTAssertFalse(permits(path(5), failure: "URL_-999"))
        XCTAssertFalse(permits(path(5), session: UUID()))
        XCTAssertFalse(permits(path(5), credentials: false))
        XCTAssertFalse(permits(path(5), cancelled: true))
    }

    func testEquivalentPathNotificationKeepsAuthenticationAndLANCacheButChangedWiFiInvalidates() {
        // Same coarse "wifi" class is insufficient: the path identity includes
        // the actual routes/interfaces as compared by Network.NWPath equality.
        var counter = PlaybackPathGeneration<String>()
        XCTAssertTrue(counter.observe("wifi-route-A"))
        let initial = PlaybackNetworkSnapshot(cacheKey: "wifi", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: counter.generation)
        var lan = JellyfinLANPlaybackRouteCache()
        let endpoint = URL(string: "http://192.168.1.1:8096")!
        XCTAssertTrue(lan.publish(endpoint, startedOn: initial, current: initial))
        XCTAssertFalse(counter.observe("wifi-route-A"))
        let duplicate = PlaybackNetworkSnapshot(cacheKey: "wifi", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: counter.generation)
        let login = UUID()
        XCTAssertEqual(lan.endpoint(on: duplicate), endpoint)
        XCTAssertTrue(JellyfinAuthenticatedIdentity.canPublish(startedOn: initial, current: duplicate,
            startedSession: login, currentSession: login, cancelled: false))
        XCTAssertTrue(counter.observe("wifi-route-B"))
        let changed = PlaybackNetworkSnapshot(cacheKey: "wifi", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: counter.generation)
        XCTAssertNil(lan.endpoint(on: changed))
        XCTAssertFalse(JellyfinAuthenticatedIdentity.canPublish(startedOn: initial, current: changed,
            startedSession: login, currentSession: login, cancelled: false))
    }

    func testFreshPreparationWaitsForSettledPathAndExpiresDuringContinuedChange() {
        func path(_ generation: UInt64, _ key: String = "cellular") -> PlaybackNetworkSnapshot {
            .init(cacheKey: key, bitrateCap: nil, fallbackBitrate: 2_000_000, pathGeneration: generation)
        }
        var stable = JellyfinPlaybackPathSettling()
        XCTAssertEqual(stable.observe(path(5), elapsed: 0), .waiting)
        XCTAssertEqual(stable.observe(path(5), elapsed: 3), .waiting)
        XCTAssertEqual(stable.observe(path(6), elapsed: 3.7), .waiting)
        XCTAssertEqual(stable.observe(path(6), elapsed: 7.69), .waiting)
        XCTAssertEqual(stable.observe(path(6), elapsed: 7.7), .ready)
        var changing = JellyfinPlaybackPathSettling()
        XCTAssertEqual(changing.observe(path(5), elapsed: 0), .waiting)
        XCTAssertEqual(changing.observe(path(6), elapsed: 3), .waiting)
        XCTAssertEqual(changing.observe(path(7), elapsed: 6), .waiting)
        XCTAssertEqual(changing.observe(path(7), elapsed: 8), .expired)
        var unknown = JellyfinPlaybackPathSettling()
        XCTAssertEqual(unknown.observe(path(0, "unknown"), elapsed: 0), .waiting)
        XCTAssertEqual(unknown.observe(path(1), elapsed: 3), .waiting)
        XCTAssertEqual(unknown.observe(path(1), elapsed: 7), .ready)
        XCTAssertEqual(unknown.observe(path(1), elapsed: .nan), .expired)
    }

    func testNetworkChangedPreparationCanRestartOnlyOnceWithinSameCredentialsAndLogin() {
        let session = UUID()
        let first = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 2)
        let second = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 3)
        func permits(_ current: PlaybackNetworkSnapshot, attempt: Int = 0,
                     login: UUID? = nil, credentials: Bool = true, cancelled: Bool = false) -> Bool {
            JellyfinAuthenticatedFallbackPolicy.canRestart(attempt: attempt, startedOn: first,
                current: current, startedSession: session, currentSession: login ?? session,
                credentialsUnchanged: credentials, cancelled: cancelled)
        }
        XCTAssertTrue(permits(second))
        XCTAssertFalse(permits(first))
        XCTAssertFalse(permits(second, attempt: 1))
        XCTAssertFalse(permits(second, login: UUID()))
        XCTAssertFalse(permits(second, credentials: false))
        XCTAssertFalse(permits(second, cancelled: true))
        XCTAssertFalse(permits(.init(cacheKey: "unknown", bitrateCap: nil, fallbackBitrate: 2_000_000)))
    }

    func testAuthenticatedFallbackRejectsHTTPAndCancellationEvenWithPriorIdentity() {
        for status in [200, 302, 401, 403, 500] {
            XCTAssertFalse(JellyfinAuthenticatedFallbackPolicy.primaryIsUnreachable(status: status, failure: "URL_-1001"))
        }
        for failure in [nil, "URL_-999", "requestFailed", "invalidStoredScope"] as [String?] {
            XCTAssertFalse(JellyfinAuthenticatedFallbackPolicy.primaryIsUnreachable(status: nil, failure: failure))
        }
        XCTAssertTrue(JellyfinAuthenticatedFallbackPolicy.primaryIsUnreachable(status: nil, failure: "URL_-1001"))
        XCTAssertTrue(JellyfinAuthenticatedFallbackPolicy.primaryIsUnreachable(status: nil, failure: "URL_-1004"))
    }

    func testAuthenticatedFallbackIdentityAndContextExpireAndRejectInvalidClock() {
        XCTAssertTrue(JellyfinAuthenticatedFallbackPolicy.canUsePrimaryIdentity(age: 299))
        XCTAssertFalse(JellyfinAuthenticatedFallbackPolicy.canUsePrimaryIdentity(age: 300))
        XCTAssertTrue(JellyfinAuthenticatedFallbackPolicy.canReuse(age: 119))
        XCTAssertFalse(JellyfinAuthenticatedFallbackPolicy.canReuse(age: 120))
        for age in [-1, Double.infinity, Double.nan] {
            XCTAssertFalse(JellyfinAuthenticatedFallbackPolicy.canUsePrimaryIdentity(age: age))
            XCTAssertFalse(JellyfinAuthenticatedFallbackPolicy.canReuse(age: age))
        }
    }

    func testPublicInfoAndIncompleteUserResponsesDoNotAuthenticateAnOrigin() {
        for body in [#"{"Id":"server-A"}"#, #"{"Id":"account-A","ServerId":""}"#,
                     #"{"Id":" ","ServerId":"server-A"}"#, #"{"ServerId":"server-A"}"#,
                     #"{"Id":17,"ServerId":"server-A"}"#, "not JSON"] {
            XCTAssertNil(JellyfinAuthenticatedIdentity.response(data: Data(body.utf8), status: 200))
        }
    }

    func testAuthenticatedOriginCannotBorrowAnotherServerOrAccountIdentity() {
        let primary = JellyfinAuthenticatedIdentity(userID: "account-A", serverID: "server-A")
        XCTAssertFalse(JellyfinAuthenticatedIdentity.matches(primary: primary,
            candidate: .init(userID: "account-A", serverID: "server-B"), expectedUserID: "account-A"))
        XCTAssertFalse(JellyfinAuthenticatedIdentity.matches(primary: primary,
            candidate: .init(userID: "account-B", serverID: "server-A"), expectedUserID: "account-A"))
        XCTAssertFalse(JellyfinAuthenticatedIdentity.matches(primary: primary,
            candidate: primary, expectedUserID: "account-B"))
        XCTAssertFalse(JellyfinAuthenticatedIdentity.matches(primary: nil,
            candidate: primary, expectedUserID: "account-A"))
        XCTAssertFalse(JellyfinAuthenticatedIdentity.matches(primary: primary,
            candidate: nil, expectedUserID: "account-A"))
    }

    func testAuthenticatedProbeRejectsLateResultsAfterCancellationLoginOrNetworkChange() {
        let session = UUID()
        let wifi = PlaybackNetworkSnapshot(cacheKey: "wifi", bitrateCap: nil,
            fallbackBitrate: 8_000_000, pathGeneration: 7)
        func accepts(_ current: PlaybackNetworkSnapshot, _ currentSession: UUID, cancelled: Bool = false) -> Bool {
            JellyfinAuthenticatedIdentity.canPublish(startedOn: wifi, current: current,
                startedSession: session, currentSession: currentSession, cancelled: cancelled)
        }
        XCTAssertTrue(accepts(wifi, session))
        XCTAssertFalse(accepts(wifi, session, cancelled: true))
        XCTAssertFalse(accepts(wifi, UUID()))
        XCTAssertFalse(accepts(.init(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 8), session))
        XCTAssertFalse(accepts(.init(cacheKey: "wifi", bitrateCap: nil,
            fallbackBitrate: 8_000_000, pathGeneration: 9), session))
        let unknown = PlaybackNetworkSnapshot(cacheKey: "unknown", bitrateCap: nil,
            fallbackBitrate: 2_000_000)
        XCTAssertFalse(JellyfinAuthenticatedIdentity.canPublish(startedOn: unknown, current: unknown,
            startedSession: session, currentSession: session, cancelled: false))
    }

    func testNetworkChangeRejectsCachedLANAndLateProbeCompletion() {
        let lan = URL(string: "http://192.168.10.20:8096")!
        let wifi = PlaybackNetworkSnapshot(cacheKey: "wifi", bitrateCap: nil,
            fallbackBitrate: 8_000_000, pathGeneration: 1)
        let cellular = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 2)
        var cache = JellyfinLANPlaybackRouteCache()
        XCTAssertTrue(cache.publish(lan, startedOn: wifi, current: wifi))
        XCTAssertNil(cache.endpoint(on: cellular))
        XCTAssertFalse(cache.publish(lan, startedOn: wifi, current: cellular))
        XCTAssertNil(cache.endpoint(on: cellular))
    }

    func testReturningToWiFiCannotResurrectAnOldLANVerification() {
        let lan = URL(string: "http://192.168.10.20:8096")!
        let oldWiFi = PlaybackNetworkSnapshot(cacheKey: "wifi", bitrateCap: nil,
            fallbackBitrate: 8_000_000, pathGeneration: 1)
        let newWiFi = PlaybackNetworkSnapshot(cacheKey: "wifi", bitrateCap: nil,
            fallbackBitrate: 8_000_000, pathGeneration: 3)
        var cache = JellyfinLANPlaybackRouteCache()
        XCTAssertTrue(cache.publish(lan, startedOn: oldWiFi, current: oldWiFi))
        XCTAssertNil(cache.endpoint(on: newWiFi))
        XCTAssertFalse(cache.publish(lan, startedOn: oldWiFi, current: newWiFi))
        XCTAssertTrue(cache.publish(lan, startedOn: newWiFi, current: newWiFi))
        XCTAssertEqual(cache.endpoint(on: newWiFi), lan)
    }

    func testUnknownPathCannotVerifyLANButFreshCellularVerificationCan() {
        let lan = URL(string: "http://192.168.10.20:8096")!
        let unknown = PlaybackNetworkSnapshot(cacheKey: "unknown", bitrateCap: nil,
            fallbackBitrate: 6_000_000)
        let cellular = PlaybackNetworkSnapshot(cacheKey: "cellular", bitrateCap: nil,
            fallbackBitrate: 2_000_000, pathGeneration: 2)
        var cache = JellyfinLANPlaybackRouteCache()
        XCTAssertFalse(cache.publish(lan, startedOn: unknown, current: unknown))
        XCTAssertNil(cache.endpoint(on: unknown))
        // A newly verified VPN route may still be reachable over cellular.
        XCTAssertTrue(cache.publish(lan, startedOn: cellular, current: cellular))
        XCTAssertEqual(cache.endpoint(on: cellular), lan)
    }

    func testOriginalWarmupOriginIgnoresPathsButRejectsInvalidEndpoints() {
        XCTAssertTrue(PlaybackOriginalWarmupPolicy.matches(
            warmedEndpoint: URL(string: "https://MEDIA.example/old?q=one")!,
            currentEndpoint: URL(string: "https://media.example:443/new?q=two")!,
            warmedNetwork: "wifi", currentNetwork: "wifi"))
        XCTAssertFalse(PlaybackOriginalWarmupPolicy.matches(
            warmedEndpoint: URL(fileURLWithPath: "/tmp/movie"),
            currentEndpoint: URL(fileURLWithPath: "/tmp/movie"),
            warmedNetwork: "wifi", currentNetwork: "wifi"))
        XCTAssertFalse(PlaybackOriginalWarmupPolicy.matches(
            warmedEndpoint: URL(string: "https://media.example")!,
            currentEndpoint: URL(string: "http://media.example")!,
            warmedNetwork: "wifi", currentNetwork: "wifi"))
    }

    func testBodyWindowCapacityRequiresAdjacentUnthrottledStableWindows() {
        var policy = PlaybackBodyWindowCapacityPolicy()
        XCTAssertNil(policy.sample(bytes: 5_661_389, seconds: 2.112,
            totalBackpressure: 0, queuedBytes: 46_336, now: 4.152))
        let failedCapacity = policy.sample(bytes: 5_498_056, seconds: 2,
            totalBackpressure: 0, queuedBytes: 5_792, now: 6.152)
        XCTAssertTrue(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 64_048_290, measuredCapacity: failedCapacity,
            isPrivateRoute: false, forcesOriginal: false))
        var healthy = PlaybackBodyWindowCapacityPolicy()
        XCTAssertNil(healthy.sample(bytes: 10_648_713, seconds: 2,
            totalBackpressure: 0, queuedBytes: 2_896, now: 3.643))
        let healthyCapacity = healthy.sample(bytes: 20_358_267, seconds: 2,
            totalBackpressure: 0, queuedBytes: 2_896, now: 5.643)
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 64_048_290, measuredCapacity: healthyCapacity,
            isPrivateRoute: false, forcesOriginal: false))
        for invalid in ["pressure", "queue", "short", "gap", "spike"] {
            var guarded = PlaybackBodyWindowCapacityPolicy()
            XCTAssertNil(guarded.sample(bytes: 2_000_000, seconds: 2,
                totalBackpressure: 0, queuedBytes: 0, now: 2))
            XCTAssertNil(guarded.sample(bytes: invalid == "spike" ? 20_000_000 : 2_000_000,
                seconds: invalid == "short" ? 1 : 2,
                totalBackpressure: invalid == "pressure" ? 0.01 : 0,
                queuedBytes: invalid == "queue" ? 131_073 : 0,
                now: invalid == "gap" ? 8 : 4), invalid)
        }
    }

    func testBodyCapacityExpiresAndCannotOverrideNewerCompletedOrOtherTrace() {
        let store = PlaybackRecentThroughputStore()
        store.recordQualifiedBodyWindow(traceID: "A", bitrate: 22_000_000, now: 10)
        XCTAssertEqual(store.estimateSample(traceID: "A", now: 12)?.source, .bodyWindow)
        XCTAssertEqual(store.estimate(traceID: "A", now: 12), 22_000_000)
        XCTAssertNil(store.estimate(traceID: "B", now: 12))
        XCTAssertNil(store.estimate(traceID: "A", now: 9))
        XCTAssertNil(store.estimate(traceID: "A", now: 16.001))
        store.recordQualifiedBodyWindow(traceID: "A", bitrate: 40_000_000, now: 20)
        store.record(traceID: "A", bytes: 3_000_000, seconds: 2,
            backpressureSeconds: 0, now: 21)
        XCTAssertEqual(store.estimateSample(traceID: "A", now: 22)?.source, .completedTransfer)
        XCTAssertEqual(store.estimate(traceID: "A", now: 22), 12_000_000)
    }

    func testPredictiveCapacityDoesNotTreatFirstHLSSegmentWaitAsSustainedLowSupply() throws {
        let store = PlaybackRecentThroughputStore()
        // Same-trace device evidence: first segment spends 6.086 seconds
        // before headers, then two later segments arrive above 30 Mbps.
        store.record(traceID: "movie", bytes: 1_984_152, seconds: 6.662,
            backpressureSeconds: 0, now: 18.956)
        XCTAssertNil(store.estimateSample(traceID: "movie", now: 19)?.predictiveBitrate)
        store.record(traceID: "movie", bytes: 6_326_200, seconds: 1.513,
            backpressureSeconds: 0, now: 20.480)
        XCTAssertNil(store.estimateSample(traceID: "movie", now: 21)?.predictiveBitrate)
        store.record(traceID: "movie", bytes: 5_051_936, seconds: 0.948,
            backpressureSeconds: 0, now: 21.410)
        let sample = try XCTUnwrap(store.estimateSample(traceID: "movie", now: 22))
        XCTAssertLessThan(sample.bitrate, 3_000_000) // Existing budget hint is preserved.
        XCTAssertGreaterThan(try XCTUnwrap(sample.predictiveBitrate), 30_000_000)
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 10_000_000, measuredCapacity: sample.predictiveBitrate,
            isPrivateRoute: false, forcesOriginal: false))
    }

    func testPredictiveCapacityStillDetectsRepeatedLowSupplyAndRecoversFromOldSamples() throws {
        let store = PlaybackRecentThroughputStore()
        func record(_ seconds: Double, at time: Double) {
            store.record(traceID: "A", bytes: 3_000_000, seconds: seconds,
                backpressureSeconds: 0, now: time)
        }
        record(12, at: 12); record(12, at: 24); record(0.5, at: 25)
        let low = try XCTUnwrap(store.estimateSample(traceID: "A", now: 25)?.predictiveBitrate)
        XCTAssertEqual(low, 2_000_000)
        XCTAssertTrue(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 10_000_000, measuredCapacity: low,
            isPrivateRoute: false, forcesOriginal: false))
        record(0.5, at: 26)
        XCTAssertEqual(store.estimateSample(traceID: "A", now: 26)?.predictiveBitrate, 48_000_000)
        XCTAssertNil(store.estimateSample(traceID: "B", now: 26))
        XCTAssertNil(store.estimateSample(traceID: "A", now: 11))
        XCTAssertNil(store.estimateSample(traceID: "A", now: 87))
    }

    func testPredictiveCapacityKeepsQualifiedBodyEvidenceButRejectsUnqualifiedCompletions() {
        let store = PlaybackRecentThroughputStore()
        store.recordQualifiedBodyWindow(traceID: "A", bitrate: 2_000_000, now: 10)
        XCTAssertEqual(store.estimateSample(traceID: "A", now: 11)?.predictiveBitrate, 2_000_000)
        store.record(traceID: "A", bytes: 100, seconds: 1, backpressureSeconds: 0, now: 12)
        store.record(traceID: "A", bytes: 3_000_000, seconds: 1, backpressureSeconds: 1, now: 12)
        XCTAssertEqual(store.estimateSample(traceID: "A", now: 12)?.predictiveBitrate, 2_000_000)
        XCTAssertNil(store.estimateSample(traceID: "A", now: 16.001))
        store.record(traceID: "A", bytes: 3_000_000, seconds: 8, backpressureSeconds: 0, now: 17)
        XCTAssertEqual(store.estimate(traceID: "A", now: 17), 3_000_000)
        XCTAssertNil(store.estimateSample(traceID: "A", now: 17)?.predictiveBitrate)
    }

    func testQualifiedMediaWindowsRetireOlderCompletedTailCapacity() throws {
        let store = PlaybackRecentThroughputStore()
        // Device counterexample: a short tail read finishes before two
        // qualified body windows of the current, continuous media stream.
        store.record(traceID: "movie", bytes: 4_823_696, seconds: 2.538405,
            backpressureSeconds: 0, now: 6.946)
        var windows = PlaybackBodyWindowCapacityPolicy()
        XCTAssertNil(windows.sample(bytes: 10_059_740, seconds: 2.001378,
            totalBackpressure: 0, queuedBytes: 65_536, now: 9.575))
        let capacity = try XCTUnwrap(windows.sample(bytes: 14_057_472, seconds: 2.006379,
            totalBackpressure: 0, queuedBytes: 65_536, now: 11.579))
        store.recordQualifiedBodyWindow(traceID: "movie", bitrate: capacity, now: 11.579)
        XCTAssertEqual(store.estimateSample(traceID: "movie", now: 12)?.source, .bodyWindow)
        XCTAssertEqual(store.estimate(traceID: "movie", now: 12), capacity)

        // The newer completed request still counts. The obsolete tail must
        // not turn its roughly 50 Mbps estimate into a 15 Mbps lower quartile.
        store.record(traceID: "movie", bytes: 33_554_432, seconds: 5.401,
            backpressureSeconds: 0, now: 12.974)
        let current = try XCTUnwrap(store.estimate(traceID: "movie", now: 13.205))
        XCTAssertEqual(store.estimateSample(traceID: "movie", now: 13.205)?.source, .completedTransfer)
        XCTAssertEqual(current, Int(Double(33_554_432) * 8 / 5.401))
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.target(currentCeiling: 81_851_565,
            capacity: current, networkKey: "cellular"), 20_000_000)
    }

    func testSupersededCapacityDoesNotReturnWhenBodyWindowExpires() {
        let store = PlaybackRecentThroughputStore()
        store.record(traceID: "A", bytes: 3_000_000, seconds: 2,
            backpressureSeconds: 0, now: 10)
        store.recordQualifiedBodyWindow(traceID: "A", bitrate: 56_000_000, now: 12)
        XCTAssertNil(store.estimate(traceID: "A", now: 18.001))
        store.record(traceID: "A", bytes: 3_000_000, seconds: 8,
            backpressureSeconds: 0, now: 19)
        XCTAssertEqual(store.estimate(traceID: "A", now: 19), 3_000_000)
        XCTAssertTrue(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 81_851_565, measuredCapacity: store.estimate(traceID: "A", now: 19),
            isPrivateRoute: false, forcesOriginal: false))
    }

    func testQualifiedBodyRetirementPreservesOtherTracesAndNewerCompletions() {
        let store = PlaybackRecentThroughputStore()
        store.record(traceID: "A", bytes: 3_000_000, seconds: 2,
            backpressureSeconds: 0, now: 10)
        store.record(traceID: "B", bytes: 4_000_000, seconds: 10,
            backpressureSeconds: 0, now: 11)
        store.recordQualifiedBodyWindow(traceID: "A", bitrate: 56_000_000, now: 12)
        store.record(traceID: "A", bytes: 3_000_000, seconds: 8,
            backpressureSeconds: 0, now: 13)
        XCTAssertEqual(store.estimate(traceID: "B", now: 14), 3_200_000)
        XCTAssertEqual(store.estimate(traceID: "A", now: 14), 3_000_000)
        store.recordQualifiedBodyWindow(traceID: "A", bitrate: 2_000_000, now: 15)
        XCTAssertEqual(store.estimate(traceID: "A", now: 15), 2_000_000)
    }

    func testInvalidOrDelayedBodyEvidenceCannotEraseNewerCapacity() {
        let store = PlaybackRecentThroughputStore()
        store.recordQualifiedBodyWindow(traceID: "A", bitrate: 56_000_000, now: 12)
        store.recordQualifiedBodyWindow(traceID: "A", bitrate: 1_000_000, now: 11)
        XCTAssertEqual(store.estimate(traceID: "A", now: 12), 56_000_000)
        store.record(traceID: "A", bytes: 3_000_000, seconds: 8,
            backpressureSeconds: 0, now: 13)
        store.recordQualifiedBodyWindow(traceID: "A", bitrate: 0, now: 14)
        store.recordQualifiedBodyWindow(traceID: "A", bitrate: 99_000_000, now: .nan)
        XCTAssertEqual(store.estimate(traceID: "A", now: 14), 3_000_000)
    }

    func testBodySamplerPreservesPartialWindowAndPreviousSampleAcrossRanges() throws {
        var sampler = PlaybackBodyWindowSampler()
        sampler.beginResponse(now: 0)
        XCTAssertNil(sampler.receive(bytes: 8_000_000, now: 1,
            totalBackpressure: 0, queuedBytes: 0, eligible: true))
        let first = try XCTUnwrap(sampler.receive(bytes: 8_000_000, now: 2,
            totalBackpressure: 0, queuedBytes: 0, eligible: true))
        XCTAssertNil(first.capacity)
        XCTAssertNil(sampler.receive(bytes: 8_000_000, now: 3,
            totalBackpressure: 0, queuedBytes: 0, eligible: true))
        sampler.beginResponse(now: 3.1)
        let second = try XCTUnwrap(sampler.receive(bytes: 8_000_000, now: 4,
            totalBackpressure: 0, queuedBytes: 0, eligible: true))
        XCTAssertEqual(second.bytes, 16_000_000)
        XCTAssertEqual(second.seconds, 2)
        XCTAssertEqual(second.capacity, 64_000_000)
    }

    func testBodySamplerQualifiesWeakSupplyButNotOneSlowResponse() throws {
        var sampler = PlaybackBodyWindowSampler()
        sampler.beginResponse(now: 0)
        XCTAssertNil(try XCTUnwrap(sampler.receive(bytes: 195_000, now: 2,
            totalBackpressure: 0, queuedBytes: 0, eligible: true)).capacity)
        XCTAssertEqual(try XCTUnwrap(sampler.receive(bytes: 195_000, now: 4,
            totalBackpressure: 0, queuedBytes: 0, eligible: true)).capacity, 780_000)
        var tiny = PlaybackBodyWindowCapacityPolicy()
        XCTAssertNil(tiny.sample(bytes: 131_071, seconds: 2,
            totalBackpressure: 0, queuedBytes: 0, now: 2))
        XCTAssertNil(tiny.sample(bytes: 195_000, seconds: 2,
            totalBackpressure: 0, queuedBytes: 0, now: 4))
        XCTAssertNil(tiny.sample(bytes: 195_000, seconds: 5,
            totalBackpressure: 0, queuedBytes: 0, now: 9))
    }

    func testBodySamplerCannotErasePressureAtRangeBoundaryOrMixEligibility() throws {
        var sampler = PlaybackBodyWindowSampler()
        sampler.beginResponse(now: 0)
        _ = sampler.receive(bytes: 195_000, now: 2,
            totalBackpressure: 0, queuedBytes: 0, eligible: true)
        _ = sampler.receive(bytes: 100_000, now: 3,
            totalBackpressure: 0.1, queuedBytes: 0, eligible: true)
        sampler.beginResponse(now: 3.1)
        let pressured = try XCTUnwrap(sampler.receive(bytes: 95_000, now: 4,
            totalBackpressure: 0, queuedBytes: 0, eligible: true))
        XCTAssertTrue(pressured.pressured)
        XCTAssertNil(pressured.capacity)
        XCTAssertNil(try XCTUnwrap(sampler.receive(bytes: 195_000, now: 6,
            totalBackpressure: 0, queuedBytes: 0, eligible: false)).capacity)
        XCTAssertNil(try XCTUnwrap(sampler.receive(bytes: 195_000, now: 8,
            totalBackpressure: 0, queuedBytes: 0, eligible: true)).capacity)
        XCTAssertEqual(try XCTUnwrap(sampler.receive(bytes: 195_000, now: 10,
            totalBackpressure: 0, queuedBytes: 0, eligible: true)).capacity, 780_000)
    }

    func testOnlyQualifiedInitialBodyEstimateCanShortenPredictionGrace() {
        var initial = PlaybackPredictiveGracePolicy()
        XCTAssertFalse(initial.allows(now: 10, seekGeneration: 0, qualifiedBodyWindow: true))
        XCTAssertFalse(initial.allows(now: 12.99, seekGeneration: 0, qualifiedBodyWindow: true))
        XCTAssertFalse(initial.allows(now: 13, seekGeneration: 0, qualifiedBodyWindow: false))
        XCTAssertTrue(initial.allows(now: 13, seekGeneration: 0, qualifiedBodyWindow: true))
        XCTAssertFalse(initial.allows(now: 14, seekGeneration: 1, qualifiedBodyWindow: true))
        XCTAssertFalse(initial.allows(now: 23.99, seekGeneration: 1, qualifiedBodyWindow: true))
        XCTAssertTrue(initial.allows(now: 24, seekGeneration: 1, qualifiedBodyWindow: false))
        XCTAssertFalse(initial.allows(now: .nan, seekGeneration: 1, qualifiedBodyWindow: true))
    }

    func testPredictiveCooldownSurvivesAutomaticHandoffAndFreshGrace() {
        var cooldown = PlaybackPredictiveCooldownPolicy()
        XCTAssertTrue(cooldown.allows(now: 9.863))
        cooldown.requested(now: 9.863)
        // The replacement gets its own sampling/grace task, as in the S19
        // counterexample. A fresh grace must not authorize another prediction.
        var replacementGrace = PlaybackPredictiveGracePolicy()
        XCTAssertFalse(replacementGrace.allows(now: 19.010, seekGeneration: 0,
            qualifiedBodyWindow: false))
        XCTAssertTrue(replacementGrace.allows(now: 30.673, seekGeneration: 0,
            qualifiedBodyWindow: false))
        XCTAssertFalse(cooldown.allows(now: 30.673))
        XCTAssertFalse(cooldown.allows(now: 69.862))
        XCTAssertTrue(cooldown.allows(now: 69.863))
    }

    func testPredictionCooldownDoesNotBlockReactiveStallRecovery() {
        var cooldown = PlaybackPredictiveCooldownPolicy()
        cooldown.requested(now: 100)
        var reactive = PlaybackStallDownshiftPolicy()
        var triggers: [Int] = []
        for second in 100...130 {
            XCTAssertFalse(cooldown.allows(now: Double(second)))
            if reactive.sample(now: Double(second), eligible: true,
                buffering: true, seekGeneration: 0) {
                triggers.append(second)
            }
        }
        XCTAssertEqual(triggers, [118])
    }

    func testManualNewSourceStartsFreshPredictionBudget() {
        var cooldown = PlaybackPredictiveCooldownPolicy()
        cooldown.requested(now: 100)
        XCTAssertFalse(cooldown.allows(now: 110))
        cooldown.manualSourceCommitted()
        XCTAssertTrue(cooldown.allows(now: 110))
        cooldown.requested(now: 110)
        XCTAssertFalse(cooldown.allows(now: 169.999))
        XCTAssertTrue(cooldown.allows(now: 170))
    }

    func testReactiveRequestExtendsCooldownWithoutAllowingClockRollback() {
        var cooldown = PlaybackPredictiveCooldownPolicy()
        cooldown.requested(now: 100)
        // Reactive recovery bypasses the prediction gate but records its own
        // request, preventing an immediate predictive follow-up on the new flow.
        cooldown.requested(now: 120)
        cooldown.requested(now: 90)
        XCTAssertFalse(cooldown.allows(now: 160))
        XCTAssertTrue(cooldown.allows(now: 180))
        for invalid in [Double.nan, .infinity, -.infinity] {
            cooldown.requested(now: invalid)
            XCTAssertFalse(cooldown.allows(now: invalid))
        }
        XCTAssertFalse(cooldown.allows(now: 179.999))
        XCTAssertTrue(cooldown.allows(now: 180))
    }

    func testFileSizeAndDecoderDurationRestoreMissingOriginalDemand() throws {
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: nil, measuredCapacity: 38_000_000,
            isPrivateRoute: false, forcesOriginal: false))
        let bitrate = try XCTUnwrap(PlaybackAdaptiveBitratePolicy.sourceBitrate(
            streamBitrateCeiling: nil, estimatedBitrate: nil,
            byteLength: 64_000_000, durationSeconds: 8))
        XCTAssertEqual(bitrate, 64_000_000)
        XCTAssertTrue(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: bitrate, measuredCapacity: 38_000_000,
            isPrivateRoute: false, forcesOriginal: false))
    }

    func testFileAverageDoesNotReplaceExplicitRenditionOrSourceBitrate() {
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.sourceBitrate(
            streamBitrateCeiling: 2_000_000, estimatedBitrate: 64_000_000,
            byteLength: 64_000_000, durationSeconds: 8), 2_000_000)
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.sourceBitrate(
            streamBitrateCeiling: nil, estimatedBitrate: 50_000_000,
            byteLength: 64_000_000, durationSeconds: 8), 50_000_000)
        XCTAssertNil(PlaybackAdaptiveBitratePolicy.sourceBitrate(
            streamBitrateCeiling: 0, estimatedBitrate: 50_000_000,
            byteLength: 64_000_000, durationSeconds: 8))
    }

    func testFileAverageRejectsUnknownInvalidAndOverflowingMetadata() {
        for duration in [0, -1, Double.nan, Double.infinity] {
            XCTAssertNil(PlaybackAdaptiveBitratePolicy.sourceBitrate(
                streamBitrateCeiling: nil, estimatedBitrate: nil,
                byteLength: 64_000_000, durationSeconds: duration))
        }
        let lengths: [Int64?] = [nil, 0, -1, Int64.max]
        for length in lengths {
            XCTAssertNil(PlaybackAdaptiveBitratePolicy.sourceBitrate(
                streamBitrateCeiling: nil, estimatedBitrate: nil,
                byteLength: length, durationSeconds: 1))
        }
        XCTAssertNil(PlaybackAdaptiveBitratePolicy.sourceBitrate(
            streamBitrateCeiling: nil, estimatedBitrate: nil,
            byteLength: 1, durationSeconds: 60))
    }

    func testFileAverageKeepsHealthyAndForcedOriginalProtection() throws {
        let bitrate = try XCTUnwrap(PlaybackAdaptiveBitratePolicy.sourceBitrate(
            streamBitrateCeiling: nil, estimatedBitrate: nil,
            byteLength: 64_000_000, durationSeconds: 8))
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: bitrate, measuredCapacity: 60_000_000,
            isPrivateRoute: false, forcesOriginal: false))
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: bitrate, measuredCapacity: 20_000_000,
            isPrivateRoute: false, forcesOriginal: true))
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: bitrate, measuredCapacity: nil,
            isPrivateRoute: false, forcesOriginal: false))
    }

    func testAdaptiveTargetFitsCapacityAndStepsDownAgain() {
        XCTAssertTrue(PlaybackAdaptiveBitratePolicy.allowsAutomaticAdjustment(
            selectedQualityID: "auto"))
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.allowsAutomaticAdjustment(
            selectedQualityID: "original"))
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.allowsAutomaticAdjustment(
            selectedQualityID: "8000000"))
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.target(
            currentCeiling: 12_000_000, capacity: 20_000_000,
            networkKey: "cellular"), 10_000_000)
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.target(
            currentCeiling: 8_000_000, capacity: 5_000_000,
            networkKey: "cellular"), 2_000_000)
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.target(
            currentCeiling: 12_000_000, capacity: nil,
            networkKey: "cellular"), 4_000_000)
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.target(
            currentCeiling: 4_000_000, capacity: 2_200_000,
            networkKey: "cellular"), 1_000_000)
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.target(
            currentCeiling: 1_000_000, capacity: 1_500_000,
            networkKey: "cellular"), 750_000)
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.target(
            currentCeiling: 500_000, capacity: 1_000_000,
            networkKey: "cellular"), 375_000)
        XCTAssertNil(PlaybackAdaptiveBitratePolicy.target(
            currentCeiling: 250_000, capacity: 1_000_000,
            networkKey: "cellular"))
    }

    func testWeakCellularCeilingKeepsHeadroomBelowOldMinimum() {
        // Real 0.78 Mbps conditioner samples measured only 0.5–0.6 Mbps;
        // the former 500 kbps floor exceeded the policy's 50% safe capacity.
        for measured in [500_000, 565_156, 600_000] {
            let target = PlaybackAdaptiveBitratePolicy.target(
                currentCeiling: 1_500_000, capacity: measured, networkKey: "cellular")
            XCTAssertEqual(target, 250_000)
            XCTAssertLessThanOrEqual(try! XCTUnwrap(target), measured / 2)
        }
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.target(
            currentCeiling: 750_000, capacity: 780_000, networkKey: "cellular"), 375_000)
        XCTAssertEqual(PlaybackAdaptiveBitratePolicy.target(
            currentCeiling: 375_000, capacity: 1_000_000, networkKey: "cellular"), 250_000)
    }

    func testVerifiedFileLookupBroadenedHintStillRequiresExactFileIdentity() async throws {
        let dsm = "/video/media/movie/Film 4K REMUX [HDR]/Film.mkv"
        let sameFile = "/mnt/media/movie/Film 4K REMUX [HDR]/Film.mkv"
        let otherFile = "/mnt/media/movie/Other/Film.mkv"
        let exact: ([String]) -> Bool = { paths in
            paths.contains { VerifiedFileIdentityPolicy.matches(dsmPath: dsm, dsmSize: 54_000_000_000,
                jellyfinPath: $0, jellyfinSize: 54_000_000_000) }
        }
        for hintedItems in [[], [otherFile]] {
            var requests: [String?] = []
            let found = try await VerifiedFileLookupPolicy.load(searchHint: "Film 4K REMUX [HDR]",
                fetch: { hint, _ in
                    requests.append(hint)
                    let paths = hint == nil ? [sameFile, otherFile] : hintedItems
                    return .init(items: paths, totalCount: paths.count)
                }, hasExactMatch: exact)
            XCTAssertEqual(requests.count, 2)
            XCTAssertNil(requests.last!)
            XCTAssertTrue(found.broadenedSearch)
            XCTAssertTrue(found.isComplete)
            XCTAssertTrue(exact(found.items))
            XCTAssertEqual(found.items.filter { exact([$0]) }, [sameFile])
        }
    }

    func testVerifiedFileLookupKeepsMatchingAndAmbiguousHintResults() async throws {
        for paths in [["exact"], ["exact", "exact"]] {
            var requests = 0
            let found = try await VerifiedFileLookupPolicy.load(searchHint: "Film",
                fetch: { _, _ in requests += 1; return .init(items: paths, totalCount: paths.count) },
                hasExactMatch: { $0.contains("exact") })
            XCTAssertEqual(requests, 1)
            XCTAssertEqual(found.items, paths, "Do not discard duplicate identities to manufacture uniqueness")
            XCTAssertFalse(found.broadenedSearch)
            XCTAssertTrue(found.isComplete)
        }
    }

    func testVerifiedFileLookupRejectsTruncatedHintUniqueness() async throws {
        var requests = 0
        let found = try await VerifiedFileLookupPolicy.load(searchHint: "Film", pageSize: 2,
            fetch: { _, _ in requests += 1; return .init(items: ["exact", "other"], totalCount: 5) },
            hasExactMatch: { $0.contains("exact") })
        XCTAssertEqual(requests, 1)
        XCTAssertFalse(found.isComplete, "A hidden duplicate may exist on the next page")
        XCTAssertFalse(found.broadenedSearch)
    }

    func testVerifiedFileLookupBoundsUnfilteredScanAndReportsCompleteness() async throws {
        for total in [3, 5] {
            var offsets: [Int] = []
            let found = try await VerifiedFileLookupPolicy.load(searchHint: nil, pageSize: 2, maximumPages: 2,
                fetch: { _, offset in
                    offsets.append(offset)
                    let items = Array(offset..<min(offset + 2, total))
                    return .init(items: items, totalCount: total)
                }, hasExactMatch: { $0.contains(0) })
            XCTAssertEqual(offsets, [0, 2], "An early match cannot establish uniqueness for the rest of the scan")
            XCTAssertEqual(found.isComplete, total == 3)
            XCTAssertFalse(found.broadenedSearch)
            XCTAssertEqual(found.items.count, min(total, 4))
        }
    }

    func testVerifiedFileLookupDoesNotBroadenOnNetworkFailureOrCancellation() async {
        for failure in [URLError(.timedOut) as Error, CancellationError() as Error] {
            var requests = 0
            do {
                let _: VerifiedFileLookupPolicy.Outcome<String> = try await VerifiedFileLookupPolicy.load(
                    searchHint: "Film", fetch: { _, _ in requests += 1; throw failure },
                    hasExactMatch: { _ in true })
                XCTFail("A failed request cannot establish file identity")
            } catch {
                XCTAssertEqual(requests, 1)
            }
        }
    }

    func testVerifiedFileLookupShortPageCannotOverruleReportedUnreadTotal() async throws {
        for hint in [nil, "Film"] as [String?] {
            var requests = 0
            let result: VerifiedFileLookupPolicy.Outcome<String> = try await VerifiedFileLookupPolicy.load(
                searchHint: hint, pageSize: 2,
                fetch: { _, _ in
                    requests += 1
                    return .init(items: ["exact"], totalCount: 3)
                }, hasExactMatch: { $0.contains("exact") })
            XCTAssertFalse(result.isComplete)
            XCTAssertFalse(result.broadenedSearch)
            XCTAssertEqual(requests, 1)
        }
    }

    func testVerifiedFileIdentityAllowsDifferentMountPrefixButRejectsWrongFile() {
        let dsm = "/video/media/movie/Film (2001)/Film.2160p.mkv"
        let jellyfin = "/mnt/media/movie/Film (2001)/Film.2160p.mkv"
        XCTAssertTrue(VerifiedFileIdentityPolicy.matches(
            dsmPath: dsm, dsmSize: 128_795_641_934,
            jellyfinPath: jellyfin, jellyfinSize: 128_795_641_934))
        XCTAssertFalse(VerifiedFileIdentityPolicy.matches(
            dsmPath: dsm, dsmSize: 128_795_641_934,
            jellyfinPath: jellyfin, jellyfinSize: 128_795_641_933))
        XCTAssertFalse(VerifiedFileIdentityPolicy.matches(
            dsmPath: dsm, dsmSize: 128_795_641_934,
            jellyfinPath: "/mnt/media/other/Film (2001)/Film.2160p.mkv",
            jellyfinSize: 128_795_641_934))
        XCTAssertFalse(VerifiedFileIdentityPolicy.matches(
            dsmPath: dsm, dsmSize: 128_795_641_934,
            jellyfinPath: "/mnt/media/movie/Film (2001)/Other.2160p.mkv",
            jellyfinSize: 128_795_641_934))
    }

    func testClearlyInsufficientMeasuredBandwidthSkipsOriginalWithoutAStartupProbe() {
        XCTAssertTrue(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 82_000_000, measuredCapacity: 20_000_000,
            isPrivateRoute: false, forcesOriginal: false))
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 82_000_000, measuredCapacity: nil,
            isPrivateRoute: false, forcesOriginal: false))
        XCTAssertFalse(PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
            sourceBitrate: 82_000_000, measuredCapacity: 20_000_000,
            isPrivateRoute: false, forcesOriginal: true))
    }

    func testPrewarmedCandidateDoesNotStealCurrentPlaybackOwnership() {
        let scope = PlaybackActivityScope()
        let playing = scope.prepare()
        scope.activate(playing)
        let abandonedCandidate = scope.prepare()
        XCTAssertTrue(scope.isCurrent(playing))
        XCTAssertFalse(scope.isCurrent(abandonedCandidate))
    }

    func testQuickReopenRejectsOldStopSnapshotAndKeepsNewOwner() {
        let scope = PlaybackActivityScope()
        let first = scope.prepare()
        scope.activate(first)
        let reopened = scope.prepare()
        scope.activate(reopened)
        var visiblePosition = 0
        if scope.isCurrent(first) { visiblePosition = 6311 }
        XCTAssertEqual(visiblePosition, 0)
        XCTAssertTrue(scope.isCurrent(reopened))
    }

    func testLogoutRejectsLateActivationFromOldTracker() {
        let scope = PlaybackActivityScope()
        let old = scope.prepare()
        scope.invalidate()
        let current = scope.prepare()
        scope.activate(current)
        scope.activate(old)
        XCTAssertTrue(scope.isCurrent(current))
        XCTAssertFalse(scope.isCurrent(old))
    }

    func testStopRefreshLosesOwnershipWhenAnotherPlaybackStarts() {
        let activity = PlaybackActivityScope()
        var responses = PlaybackResponseScope()
        let first = activity.prepare()
        activity.activate(first)
        let pendingResume = responses.beginResumeRequest()
        XCTAssertTrue(activity.isCurrent(first))
        activity.activate(activity.prepare())
        // Even with no newer resume request, the old stop's response is stale.
        XCTAssertTrue(responses.acceptsResumeResponse(pendingResume))
        XCTAssertFalse(activity.isCurrent(first))
    }

    func testReportBufferCoalescesBurstAndKeepsFinalStop() {
        var buffer = MediaPlaybackEventBuffer()
        buffer.append(.started(positionSeconds: 100))
        for position in 101...1100 {
            buffer.append(.started(positionSeconds: 0))
            buffer.append(.progressed(positionSeconds: Double(position), isPaused: position == 1100))
            XCTAssertLessThanOrEqual(buffer.count, 2)
        }
        if case .started(let position)? = buffer.next() { XCTAssertEqual(position, 100) }
        else { XCTFail("Start must remain first") }
        if case .progressed(let position, let paused)? = buffer.next() {
            XCTAssertEqual(position, 1100)
            XCTAssertTrue(paused)
        } else { XCTFail("Latest pending progress must survive") }
        buffer.append(.progressed(positionSeconds: 1200, isPaused: false))
        buffer.append(.stopped(positionSeconds: 0, failed: true))
        buffer.append(.stopped(positionSeconds: 999, failed: false))
        buffer.append(.progressed(positionSeconds: 1300, isPaused: false))
        if case .stopped(let position, let failed)? = buffer.next() {
            XCTAssertEqual(position, 0)
            XCTAssertTrue(failed)
        } else { XCTFail("First stop must replace unsent progress") }
        XCTAssertNil(buffer.next())
    }

    func testReportBufferStopBeforeStartIsTerminalWithoutFictitiousReport() {
        var buffer = MediaPlaybackEventBuffer()
        buffer.append(.stopped(positionSeconds: 0, failed: false))
        buffer.append(.started(positionSeconds: 10))
        buffer.append(.progressed(positionSeconds: 20, isPaused: false))
        XCTAssertNil(buffer.next())
    }

    func testTrackerReentrantStopIsDeliveredAfterStartCallbackReturns() {
        var events: [String] = []
        var tracker: MediaPlaybackTracker!
        tracker = MediaPlaybackTracker { event in
            switch event {
            case .started:
                events.append("start-enter")
                tracker.progressed(positionSeconds: 120, isPaused: false, force: true)
                tracker.stopped(positionSeconds: 140)
                events.append("start-return")
            case .progressed: events.append("progress")
            case .stopped: events.append("stop")
            }
        }
        tracker.started(positionSeconds: 100)
        XCTAssertEqual(events, ["start-enter", "start-return", "stop"])
        tracker = nil
    }

    @MainActor
    func testReportQueueWaitsForStartAndDrainsStopAfterHandledFailure() async {
        let started = expectation(description: "start request suspended")
        let stopped = expectation(description: "stop request completed")
        let probe = PlaybackReportQueueTestProbe()
        let queue = MediaPlaybackReportQueue { event in
            switch event {
            case .started:
                probe.events.append("start")
                await withCheckedContinuation { continuation in
                    probe.releaseStart = continuation
                    started.fulfill()
                }
                // reportPlayback handles transport errors and returns normally.
                do { throw NSError(domain: "test.transport", code: 1) }
                catch { probe.events.append("handled-error") }
            case .progressed:
                probe.events.append("progress")
            case .stopped(let position, _):
                probe.events.append("stop-\(Int(position))")
                stopped.fulfill()
            }
        }
        queue.enqueue(.started(positionSeconds: 0))
        await fulfillment(of: [started], timeout: 2)
        for i in 1...1000 { queue.enqueue(.progressed(positionSeconds: Double(i), isPaused: false)) }
        queue.enqueue(.stopped(positionSeconds: 6311, failed: false))
        queue.enqueue(.stopped(positionSeconds: 0, failed: false))
        XCTAssertEqual(probe.events, ["start"])
        probe.releaseStart?.resume()
        probe.releaseStart = nil
        await fulfillment(of: [stopped], timeout: 2)
        XCTAssertEqual(probe.events, ["start", "handled-error", "stop-6311"])
    }

    func testOldPlaybackReportCannotUseReplacementLoginEvenForSameAccount() {
        var scope = PlaybackResponseScope()
        let trackerSession = scope.sessionID
        XCTAssertTrue(scope.acceptsSession(trackerSession))
        scope.invalidateSession() // Sign out invalidates queued callbacks.
        scope.invalidateSession() // A fresh login never revives that tracker.
        XCTAssertFalse(scope.acceptsSession(trackerSession))
        XCTAssertTrue(scope.acceptsSession(scope.sessionID))
    }

    func testResumeResponsesCompletingInReverseOrderKeepNewestRequest() {
        var scope = PlaybackResponseScope()
        let homeLoad = scope.beginResumeRequest()
        let afterStop = scope.beginResumeRequest()
        var visiblePosition = 100
        if scope.acceptsResumeResponse(afterStop) { visiblePosition = 6311 }
        if scope.acceptsResumeResponse(homeLoad) { visiblePosition = 100 }
        XCTAssertEqual(visiblePosition, 6311)
        XCTAssertFalse(scope.acceptsResumeResponse(homeLoad))
    }

    func testSignOutRejectsResumeResponseBeforeAnotherRequestExists() {
        var scope = PlaybackResponseScope()
        let request = scope.beginResumeRequest()
        scope.invalidateSession()
        XCTAssertFalse(scope.acceptsResumeResponse(request))
        let replacement = scope.beginResumeRequest()
        XCTAssertTrue(scope.acceptsResumeResponse(replacement))
        XCTAssertFalse(scope.acceptsResumeResponse(request))
    }

    func testFailedNewResumeLoadDoesNotMakeOlderResponseCurrentAgain() {
        var scope = PlaybackResponseScope()
        let old = scope.beginResumeRequest()
        _ = scope.beginResumeRequest() // New request fails; retain visible data.
        XCTAssertFalse(scope.acceptsResumeResponse(old))
        let retry = scope.beginResumeRequest()
        XCTAssertTrue(scope.acceptsResumeResponse(retry))
    }

    func testCancelledWarmupRejectsLateStartProgressAndDuplicateStop() {
        for explicitRelease in [false, true] {
            var releases = 0
            var reports = 0
            var tracker: MediaPlaybackTracker? = MediaPlaybackTracker(
                releaseResources: { releases += 1 }, eventHandler: { _ in reports += 1 })
            if explicitRelease { tracker?.releasePreparedResources() }
            else { tracker?.stopped() }
            // A renderer readiness callback can arrive after its candidate was abandoned.
            tracker?.started(positionSeconds: 120)
            tracker?.progressed(positionSeconds: 150, isPaused: false, force: true)
            tracker?.stopped(positionSeconds: 160)
            tracker?.releasePreparedResources()
            tracker = nil
            XCTAssertEqual(reports, 0)
            XCTAssertEqual(releases, 1)
        }
    }

    func testInvalidClockDoesNotPoisonLastConfirmedStopPosition() {
        for invalid in [Double.nan, .infinity, -.infinity] {
            var positions: [Double] = []
            let tracker = MediaPlaybackTracker { event in
                switch event {
                case .started(let position), .progressed(let position, _), .stopped(let position, _):
                    positions.append(position)
                }
            }
            tracker.started(positionSeconds: invalid)
            tracker.started(positionSeconds: 120)
            tracker.progressed(positionSeconds: 140, isPaused: true)
            tracker.progressed(positionSeconds: invalid, isPaused: false, force: true)
            tracker.stopped(positionSeconds: invalid)
            tracker.stopped(positionSeconds: 0)
            XCTAssertEqual(positions, [120, 140, 140])
        }
    }

    func testStopReleasesResourcesOnceAndRejectsReentrantPlayback() {
        var releases = 0
        var reports = 0
        var tracker: MediaPlaybackTracker?
        tracker = MediaPlaybackTracker(releaseResources: {
            releases += 1
            tracker?.started(positionSeconds: 1)
            tracker?.stopped()
        }) { _ in reports += 1 }
        tracker?.started(positionSeconds: 120)
        tracker?.stopped(positionSeconds: 140)
        tracker?.progressed(positionSeconds: 150, isPaused: false, force: true)
        tracker = nil
        XCTAssertEqual(reports, 2)
        XCTAssertEqual(releases, 1)
    }

    func testJellyfinTicksHandleInvalidAndOverflowingClocks() {
        for invalid in [Double.nan, .infinity, -.infinity, -1, 0] {
            XCTAssertEqual(PlaybackPositionPolicy.ticks(for: invalid), 0)
        }
        XCTAssertEqual(PlaybackPositionPolicy.ticks(for: 6311.8), 63_118_000_000)
        XCTAssertEqual(PlaybackPositionPolicy.ticks(for: Double(Int.max)), Int.max)
        XCTAssertEqual(PlaybackPositionPolicy.ticks(for: .greatestFiniteMagnitude), Int.max)
        let boundarySeconds = Double(Int.max) / 10_000_000
        XCTAssertEqual(PlaybackPositionPolicy.ticks(for: boundarySeconds), Int.max)
        XCTAssertLessThan(PlaybackPositionPolicy.ticks(for: boundarySeconds.nextDown), Int.max)
    }

    @MainActor
    func testResumeStartupReadyMetadataCannotOverwritePersistedPositionAndTracks() throws {
        let suite = "ResumeStartupTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        store.save(key: "file", position: 6200, duration: 14000,
                   audioTrackID: 3, subtitleTrackID: 8, subtitlesDisabled: false)
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 6200)
        controls.currentSeconds = 6200 // Requested chrome position is not the engine clock.
        controls.isReady = true
        controls.durationSeconds = 14000
        controls.readPlaybackClock = { 0 }
        if controls.canPersistResumeProgress {
            store.save(key: "file", position: controls.preciseCurrentSeconds, duration: controls.durationSeconds,
                       audioTrackID: 1, subtitleTrackID: nil, subtitlesDisabled: true)
        }
        let persisted = try XCTUnwrap(LocalPlaybackResumeStore(defaults: defaults).entry(for: "file"))
        XCTAssertEqual(persisted.positionSeconds, 6200)
        XCTAssertEqual(persisted.audioTrackID, 3)
        XCTAssertEqual(persisted.subtitleTrackID, 8)
        XCTAssertFalse(persisted.subtitlesDisabled)
    }

    @MainActor
    func testResumeStartupIgnoresEarlyClocksUntilRequestedPositionArrives() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 6200)
        controls.isReady = true
        for seconds in [0.0, 0.1, 500, 6199] {
            controls.updateClock(seconds)
            XCTAssertFalse(controls.canPersistResumeProgress)
        }
        controls.updateClock(6200.1)
        XCTAssertTrue(controls.canPersistResumeProgress)
    }

    @MainActor
    func testResumeStartupArrivalPersistsTheNewActualClock() throws {
        let suite = "ResumeStartupTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 6200)
        controls.isReady = true
        controls.durationSeconds = 14000
        controls.updateClock(6200.1)
        XCTAssertTrue(controls.canPersistResumeProgress)
        if controls.canPersistResumeProgress {
            store.save(key: "file", position: controls.preciseCurrentSeconds, duration: controls.durationSeconds,
                       audioTrackID: 3, subtitleTrackID: 8, subtitlesDisabled: false)
        }
        XCTAssertEqual(LocalPlaybackResumeStore(defaults: defaults).entry(for: "file")?.positionSeconds, 6200.1)
    }

    @MainActor
    func testResumeStartupEstablishedSessionStillPersistsBackwardSeek() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 6200)
        controls.isReady = true
        controls.isSeekable = true
        controls.durationSeconds = 14000
        controls.seekPlayback = { _ in }
        controls.updateClock(6200.1)
        controls.seekSeconds(500)
        XCTAssertFalse(controls.canPersistResumeProgress)
        controls.seekDidComplete(true)
        controls.updateClock(500)
        XCTAssertTrue(controls.canPersistResumeProgress)
        XCTAssertEqual(controls.preciseCurrentSeconds, 500)
    }

    @MainActor
    func testResumeStartupNewPlanDoesNotInheritPreviousArrival() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 10)
        controls.isReady = true
        controls.updateClock(10.1)
        XCTAssertTrue(controls.canPersistResumeProgress)
        controls.beginSession(initialPosition: 6200)
        controls.updateClock(0)
        XCTAssertFalse(controls.canPersistResumeProgress)
        controls.updateClock(6200)
        XCTAssertTrue(controls.canPersistResumeProgress)
        controls.disconnect()
        XCTAssertFalse(controls.canPersistResumeProgress)
    }

    @MainActor
    func testResumeStartupExplicitSeekRequiresCompletedMatchingEngineClock() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 6200)
        controls.isReady = true
        controls.isSeekable = true
        controls.durationSeconds = 14000
        controls.seekPlayback = { _ in }
        controls.seekSeconds(1000)
        controls.updateClock(1000)
        XCTAssertFalse(controls.canPersistResumeProgress)
        controls.seekDidComplete(true)
        controls.updateClock(500)
        XCTAssertFalse(controls.canPersistResumeProgress)
        controls.updateClock(1000)
        XCTAssertTrue(controls.canPersistResumeProgress)
    }

    @MainActor
    func testResumeStartupPausedPreparedClockAtTargetCanBePersisted() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 6200)
        controls.isReady = true
        controls.isPlaying = false
        controls.updateClock(6200)
        XCTAssertTrue(controls.canPersistResumeProgress)
    }

    @MainActor
    func testResumeStartupExplicitBeginningAllowsZeroAndReadinessStillApplies() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 0)
        controls.updateClock(0)
        XCTAssertFalse(controls.canPersistResumeProgress)
        controls.isReady = true
        XCTAssertTrue(controls.canPersistResumeProgress)
        XCTAssertEqual(controls.preciseCurrentSeconds, 0)
    }

    func testLocalResumeIdentityIsolatesAccountsFilesAndRevisionsWithoutCredentials() {
        let server = URL(string: "https://user:secret@nas.example:5001/?sid=token#fragment")!
        let clean = URL(string: "https://nas.example:5001/")!
        let key = LocalPlaybackResumeStore.key(server: server, account: "alice", path: "/video/a.mkv", byteLength: 100, modifiedAt: nil)
        XCTAssertEqual(key, LocalPlaybackResumeStore.key(server: clean, account: "alice", path: "/video/a.mkv", byteLength: 100, modifiedAt: nil))
        for (account, path, bytes) in [("bob", "/video/a.mkv", Int64(100)), ("alice", "/other/a.mkv", 100), ("alice", "/video/a.mkv", 101)] {
            XCTAssertNotEqual(key, LocalPlaybackResumeStore.key(server: clean, account: account, path: path, byteLength: bytes, modifiedAt: nil))
        }
        XCTAssertEqual(key.count, 64)
        XCTAssertFalse(key.contains("secret"))
    }

    func testLocalResumePersistsPositionTracksAndCompletionWithoutInvalidOverwrites() throws {
        let suite = "LocalResumeTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        store.save(key: "file", position: 6200, duration: 13698, audioTrackID: 3, subtitleTrackID: 8, subtitlesDisabled: false)
        let restored = try XCTUnwrap(LocalPlaybackResumeStore(defaults: defaults).entry(for: "file"))
        XCTAssertEqual(restored.positionSeconds, 6200)
        XCTAssertEqual(restored.audioTrackID, 3)
        XCTAssertEqual(restored.subtitleTrackID, 8)
        store.save(key: "file", position: .nan, duration: 100, audioTrackID: nil, subtitleTrackID: nil, subtitlesDisabled: true)
        XCTAssertEqual(store.entry(for: "file")?.positionSeconds, 6200)
        store.save(key: "file", position: 13690, duration: 13698, audioTrackID: 3, subtitleTrackID: nil, subtitlesDisabled: true)
        XCTAssertEqual(store.entry(for: "file")?.positionSeconds, 0)
        XCTAssertTrue(store.entry(for: "file")?.subtitlesDisabled == true)
        for i in 0..<130 { store.save(key: "file-\(i)", position: 50, duration: 100, audioTrackID: nil, subtitleTrackID: nil, subtitlesDisabled: true) }
        XCTAssertNil(store.entry(for: "file"))
        XCTAssertNotNil(store.entry(for: "file-129"))
    }

    @MainActor
    func testLocalResumeBackgroundSaveNotifiesAfterPersistenceOnMainThread() async throws {
        let suite = "LocalResumeObservationTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let changed = expectation(description: "Persisted bookmark visible to preview observer")
        let observation = store.objectWillChange.sink {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(store.entry(for: "file")?.positionSeconds, 101)
            XCTAssertEqual(LocalPlaybackResumeStore(defaults: defaults).entry(for: "file")?.positionSeconds, 101)
            changed.fulfill()
        }
        DispatchQueue.global().async {
            store.save(key: "file", position: 101, duration: 1000,
                       audioTrackID: 3, subtitleTrackID: 8, subtitlesDisabled: false)
        }
        await fulfillment(of: [changed], timeout: 2)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func testLocalResumeObservationKeepsFileIdentityAndUpdatesCompletion() async throws {
        let suite = "LocalResumeObservationTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let server = URL(string: "https://nas.example/")!
        let currentKey = LocalPlaybackResumeStore.key(server: server, account: "alice", path: "/a.mkv", byteLength: 100, modifiedAt: nil)
        let otherKey = LocalPlaybackResumeStore.key(server: server, account: "bob", path: "/a.mkv", byteLength: 100, modifiedAt: nil)
        var observedPositions: [Double?] = []
        var changed = expectation(description: "Other account cannot supply the preview bookmark")
        let observation = store.objectWillChange.sink {
            observedPositions.append(store.entry(for: currentKey)?.positionSeconds)
            changed.fulfill()
        }
        store.save(key: otherKey, position: 300, duration: 1000, audioTrackID: nil, subtitleTrackID: nil, subtitlesDisabled: true)
        await fulfillment(of: [changed], timeout: 2)
        changed = expectation(description: "Preview sees its own saved progress")
        store.save(key: currentKey, position: 100, duration: 1000, audioTrackID: nil, subtitleTrackID: nil, subtitlesDisabled: true)
        await fulfillment(of: [changed], timeout: 2)
        changed = expectation(description: "Completed file no longer offers resume")
        store.save(key: currentKey, position: 999, duration: 1000, audioTrackID: nil, subtitleTrackID: nil, subtitlesDisabled: true)
        await fulfillment(of: [changed], timeout: 2)
        XCTAssertEqual(observedPositions.count, 3)
        XCTAssertNil(observedPositions[0])
        XCTAssertEqual(observedPositions[1], 100)
        XCTAssertEqual(observedPositions[2], 0)
        XCTAssertEqual(store.entry(for: otherKey)?.positionSeconds, 300)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func testLocalResumeInvalidSaveDoesNotInvalidatePreview() async throws {
        let suite = "LocalResumeObservationTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let changed = expectation(description: "Invalid progress must not trigger preview refresh")
        changed.isInverted = true
        let observation = store.objectWillChange.sink { changed.fulfill() }
        store.save(key: "file", position: .nan, duration: 1000, audioTrackID: nil, subtitleTrackID: nil, subtitlesDisabled: true)
        store.save(key: "file", position: 10, duration: 0, audioTrackID: nil, subtitleTrackID: nil, subtitlesDisabled: true)
        await fulfillment(of: [changed], timeout: 0.1)
        XCTAssertNil(store.entry(for: "file"))
        withExtendedLifetime(observation) {}
    }

    func testLocalResumeBridgeRestoresTracksAndExplicitBeginningPreservesThem() throws {
        let suite = "LocalResumeBridgeTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        store.save(key: "file", position: 6200, duration: 13698, audioTrackID: 3, subtitleTrackID: 8, subtitlesDisabled: false)
        let request = MediaPlaybackRequest(url: URL(string: "https://example.com/a.mkv")!, title: "Movie", source: .dsmFile, localResumeKey: "file")
        let resumed = request.greenfieldPlaybackLaunchRequest(resumeStore: store)
        XCTAssertEqual(resumed.intent.preferredStartTime, 6200)
        XCTAssertEqual(resumed.tracks.selectedSourceAudioTrackID, "3")
        XCTAssertEqual(resumed.tracks.selectedSourceSubtitleTrackID, "8")
        XCTAssertEqual(resumed.subtitles?.mode, .embedded)
        XCTAssertEqual(resumed.mediaRequest?.selectedSourceSubtitleTrackID, 8)
        var beginning = request
        beginning.initialPosition = 0
        let fresh = beginning.greenfieldPlaybackLaunchRequest(resumeStore: store)
        XCTAssertEqual(fresh.intent.preferredStartTime, 0)
        XCTAssertEqual(fresh.tracks.selectedSourceSubtitleTrackID, "8")
        let jellyfin = MediaPlaybackRequest(url: request.url, title: "Movie", source: .jellyfin, timelineOffsetSeconds: 300, totalDurationSeconds: 1000, localResumeKey: "file")
            .greenfieldPlaybackLaunchRequest(resumeStore: store)
        XCTAssertEqual(jellyfin.intent.preferredStartTime, 300)
        XCTAssertNil(jellyfin.mediaRequest?.initialPosition)
        XCTAssertNil(jellyfin.tracks.selectedSourceAudioTrackID,
                     "Jellyfin position and prepared selection must not be overridden in the bridge")
        XCTAssertEqual(request.playbackRequest(using: MediaPlaybackResource(url: request.url)).localResumeKey, "file")
    }

    func testUnknownFileSubtitleMetadataRemainsAutomaticButSavedOffStaysOff() throws {
        let suite = "UnknownSubtitleTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let request = MediaPlaybackRequest(url: URL(string: "http://127.0.0.1/movie.m2ts")!,
            title: "Disc", source: .dsmFile, contentKind: .discImage, localResumeKey: "disc")
        let fresh = request.greenfieldPlaybackLaunchRequest(resumeStore: store)
        XCTAssertEqual(fresh.subtitles?.mode, .embedded)
        XCTAssertNil(fresh.tracks.selectedSourceSubtitleTrackID)
        store.save(key: "disc", position: 100, duration: 1000,
            audioTrackID: nil, subtitleTrackID: nil, subtitlesDisabled: false)
        XCTAssertEqual(request.greenfieldPlaybackLaunchRequest(resumeStore: store).subtitles?.mode, .embedded)
        store.save(key: "disc", position: 100, duration: 1000,
            audioTrackID: nil, subtitleTrackID: nil, subtitlesDisabled: true)
        var beginning = request
        beginning.initialPosition = 0
        XCTAssertEqual(beginning.greenfieldPlaybackLaunchRequest(resumeStore: store).subtitles?.mode, .disabled,
            "Starting over must not erase an explicit saved Off selection")
    }

    @MainActor
    func testAutomaticSubtitleWaitsForPreferredTrackAndSelectsOnlyOnce() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession()
        controls.automaticallySelectsEmbeddedSubtitles = true
        controls.isReady = true
        var selections: [Int32] = []
        controls.subtitleAction = { id in selections.append(id); controls.selectedSubtitleTrackID = id }
        let tracks: [PlaybackDefaultSubtitlePolicy.Track] = [
            .init(index: 3, language: "eng"), .init(index: 6, language: "zho")
        ]
        controls.discoverEmbeddedSubtitle(tracks: [], readySubtitleIDs: [], preferredLanguages: ["zh-Hans"])
        controls.discoverEmbeddedSubtitle(tracks: tracks, readySubtitleIDs: [3], preferredLanguages: ["zh-Hans"])
        XCTAssertTrue(selections.isEmpty, "Do not pick English while the preferred Chinese model is still arriving")
        XCTAssertFalse(controls.runtimeState(orientationMode: .landscape).subtitleSelectionKnown)
        controls.discoverEmbeddedSubtitle(tracks: tracks, readySubtitleIDs: [3, 6], preferredLanguages: ["zh-Hans"])
        controls.discoverEmbeddedSubtitle(tracks: tracks, readySubtitleIDs: [3, 6], preferredLanguages: ["zh-Hans"])
        XCTAssertEqual(selections, [6])
        XCTAssertTrue(controls.runtimeState(orientationMode: .landscape).subtitleSelectionKnown)
        controls.subtitleAction = nil
    }

    @MainActor
    func testExplicitOffDuringSubtitleDiscoveryAndNewSessionAreRespected() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession()
        controls.automaticallySelectsEmbeddedSubtitles = true
        controls.isReady = true
        var selections: [Int32] = []
        controls.subtitleAction = { selections.append($0) }
        controls.selectSourceSubtitle(nil, externalURL: nil)
        controls.discoverEmbeddedSubtitle(tracks: [.init(index: 6, language: "zho")],
            readySubtitleIDs: [6], preferredLanguages: ["zh-Hans"])
        XCTAssertEqual(selections, [-1])
        XCTAssertTrue(controls.runtimeState(orientationMode: .landscape).subtitleSelectionKnown)
        controls.beginSession()
        XCTAssertFalse(controls.automaticallySelectsEmbeddedSubtitles)
        controls.discoverEmbeddedSubtitle(tracks: [.init(index: 6, language: "zho")],
            readySubtitleIDs: [6], preferredLanguages: ["zh-Hans"])
        XCTAssertEqual(selections, [-1], "Old discovery state must not leak into the next explicit plan")
    }

    func testSavedJellyfinTracksRespectSubtitleOffAndChangedInventory() {
        let saved = LocalPlaybackResumeStore.Entry(positionSeconds: 700, durationSeconds: 1000,
            audioTrackID: 2, subtitleTrackID: 8, subtitlesDisabled: true, updatedAt: Date())
        let restored = saved.restoredTrackSelection(audioIDs: [1, 2], subtitleIDs: [8],
            defaultAudio: 1, defaultSubtitle: 8)
        XCTAssertEqual(restored.audio, 2)
        XCTAssertNil(restored.subtitle)
        let changed = saved.restoredTrackSelection(audioIDs: [5], subtitleIDs: [9],
            defaultAudio: 5, defaultSubtitle: 9)
        XCTAssertEqual(changed.audio, 5)
        XCTAssertNil(changed.subtitle)
        let enabled = LocalPlaybackResumeStore.Entry(positionSeconds: 700, durationSeconds: 1000,
            audioTrackID: 2, subtitleTrackID: 8, subtitlesDisabled: false, updatedAt: Date())
        XCTAssertEqual(enabled.restoredTrackSelection(audioIDs: [5], subtitleIDs: [9],
            defaultAudio: 5, defaultSubtitle: 9).subtitle, 9)
    }

    func testExitAfterPausedSeekReportsConfirmedPositionIncludingBeginning() {
        for target in [0.0, 140.681, 6200.0] {
            var stopped: [Double] = []
            let tracker = MediaPlaybackTracker { event in
                if case .stopped(let position, _) = event { stopped.append(position) }
            }
            tracker.started(positionSeconds: 6100)
            tracker.progressed(positionSeconds: 6105, isPaused: true)
            tracker.stopped(positionSeconds: target)
            tracker.stopped(positionSeconds: 1)
            tracker.progressed(positionSeconds: 6105, isPaused: true)
            XCTAssertEqual(stopped, [target])
        }
    }

    @MainActor
    func testResumeBoundaryReportsPrecisePositionInsideNormalProgressThrottle() {
        for playing in [false, true] {
            var reports: [(Double, Bool)] = []
            let tracker = MediaPlaybackTracker { event in
                if case .progressed(let position, let paused) = event {
                    reports.append((position, paused))
                }
            }
            tracker.started(positionSeconds: 600)
            tracker.progressed(positionSeconds: 601, isPaused: !playing)
            reports.removeAll()
            let controls = GreenfieldPlaybackControls()
            controls.beginSession()
            controls.isReady = true
            controls.currentSeconds = 602
            controls.readPlaybackClock = { 602.75 }
            controls.isPlaying = playing
            controls.checkpointPlaybackProgress(using: tracker)
            XCTAssertEqual(reports.count, 1, "Suspension need not produce another clock tick")
            XCTAssertEqual(reports.first?.0, 602.75)
            XCTAssertEqual(reports.first?.1, !playing)
            tracker.stopped()
            controls.checkpointPlaybackProgress(using: tracker)
            XCTAssertEqual(reports.count, 1, "An ended tracker must not be revived")
        }
    }

    @MainActor
    func testResumeBoundaryDoesNotReportUnconfirmedStartupOrPendingSeek() {
        var reports: [Double] = []
        let tracker = MediaPlaybackTracker { event in
            if case .progressed(let position, _) = event { reports.append(position) }
        }
        tracker.started(positionSeconds: 6200)
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 6200)
        controls.isReady = true
        controls.updateClock(0)
        controls.checkpointPlaybackProgress(using: tracker)
        XCTAssertTrue(reports.isEmpty, "The stale pre-resume clock must not overwrite server progress")
        controls.updateClock(6200.1)
        controls.checkpointPlaybackProgress(using: tracker)
        XCTAssertEqual(reports, [6200.1])
        controls.isSeekable = true
        controls.durationSeconds = 10000
        controls.seekPlayback = { _ in }
        controls.seek(to: 0.8)
        controls.checkpointPlaybackProgress(using: tracker)
        XCTAssertEqual(reports, [6200.1], "An in-flight seek is not a confirmed server position")
    }
    @MainActor
    func testLoadingFeedbackSurvivesReadyResumeWhileTransportIsBuffering() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 600)
        XCTAssertTrue(controls.showsLoadingIndicator)
        controls.isReady = true
        controls.isPlaying = true
        controls.isTransportBuffering = true
        controls.updateClock(0)
        XCTAssertTrue(controls.showsLoadingIndicator, "Ready metadata and an old clock are not finished buffering")
        controls.updateClock(600)
        XCTAssertTrue(controls.showsLoadingIndicator, "The resume clock alone must not hide transport waiting")
        controls.isTransportBuffering = false
        XCTAssertFalse(controls.showsLoadingIndicator)
    }

    @MainActor
    func testLoadingFeedbackReturnsForRebufferingAndClearsForPreparedPause() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession()
        controls.isReady = true
        controls.updateClock(0)
        XCTAssertFalse(controls.showsLoadingIndicator, "A prepared paused frame does not need an advancing clock")
        controls.isPlaying = true
        controls.updateClock(1)
        controls.isTransportBuffering = true
        XCTAssertTrue(controls.showsLoadingIndicator, "Later transport stalls need the same visible feedback")
        controls.isTransportBuffering = false
        controls.isPlaying = false
        XCTAssertFalse(controls.showsLoadingIndicator)
        controls.disconnect()
        controls.beginSession(initialPosition: 120)
        XCTAssertTrue(controls.showsLoadingIndicator, "Reusing the controls must not retain the previous ready state")
        controls.isReady = true
        XCTAssertFalse(controls.showsLoadingIndicator)
    }

    @MainActor
    func testLoadingFeedbackPublishesTransportOnlyChangesWithoutClockTicks() {
        let controls = GreenfieldPlaybackControls()
        controls.isReady = true
        var invalidations = 0
        let subscription = controls.objectWillChange.sink { invalidations += 1 }
        controls.isTransportBuffering = true
        XCTAssertEqual(invalidations, 1, "A stopped clock cannot be relied upon to refresh loading chrome")
        controls.isTransportBuffering = true
        XCTAssertEqual(invalidations, 1, "Repeated engine polling must not invalidate identical loading state")
        controls.isTransportBuffering = false
        XCTAssertEqual(invalidations, 2)
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    func testServerStartWaitsForConfirmedResumeClock() {
        var starts: [Double] = []
        var progress: [Double] = []
        let tracker = MediaPlaybackTracker { event in
            if case .started(let position) = event { starts.append(position) }
            if case .progressed(let position, _) = event { progress.append(position) }
        }
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 6200)
        controls.isReady = true
        for seconds in [0.0, 10, 6199] {
            controls.updateClock(seconds)
            controls.reportPlaybackTime(seconds, isPaused: false, using: tracker)
        }
        XCTAssertTrue(starts.isEmpty)
        XCTAssertTrue(progress.isEmpty)
        controls.updateClock(6200.125)
        controls.reportPlaybackTime(6200.125, isPaused: false, using: tracker)
        controls.reportPlaybackTime(6200.5, isPaused: false, using: tracker)
        XCTAssertEqual(starts, [6200.125])
        XCTAssertEqual(progress, [6200.125])
    }

    @MainActor
    func testServerStartAbandonedResumeReleasesWithoutReportingZero() {
        for failed in [false, true] {
            var reports = 0
            var releases = 0
            let tracker = MediaPlaybackTracker(releaseResources: { releases += 1 }) { _ in reports += 1 }
            let controls = GreenfieldPlaybackControls()
            controls.beginSession(initialPosition: 600)
            controls.isReady = true
            controls.updateClock(0)
            controls.reportPlaybackTime(0, isPaused: false, using: tracker)
            tracker.stopped(failed: failed)
            controls.updateClock(600)
            controls.reportPlaybackTime(600, isPaused: false, using: tracker)
            tracker.stopped()
            XCTAssertEqual(reports, 0)
            XCTAssertEqual(releases, 1)
        }
    }

    @MainActor
    func testServerStartFromBeginningAllowsRealZeroAfterReadiness() {
        var starts: [Double] = []
        let tracker = MediaPlaybackTracker { event in
            if case .started(let position) = event { starts.append(position) }
        }
        let controls = GreenfieldPlaybackControls()
        controls.beginSession()
        controls.reportPlaybackTime(0, isPaused: false, using: tracker)
        XCTAssertTrue(starts.isEmpty)
        controls.isReady = true
        controls.updateClock(0)
        controls.reportPlaybackTime(0, isPaused: false, using: tracker)
        XCTAssertEqual(starts, [0])
    }

    @MainActor
    func testServerClockRejectsInvalidSamplesAndUsesAttachedEngine() {
        var starts: [Double] = []
        var progress: [Double] = []
        let tracker = MediaPlaybackTracker { event in
            if case .started(let position) = event { starts.append(position) }
            if case .progressed(let position, _) = event { progress.append(position) }
        }
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 600)
        controls.isReady = true
        var actual = 0.0
        controls.readPlaybackClock = { actual }
        controls.updateClock(600)
        controls.reportPlaybackTime(600, isPaused: false, using: tracker)
        XCTAssertTrue(starts.isEmpty, "A retiring engine's callback cannot confirm the attached engine")
        actual = 600.25
        controls.updateClock(600)
        for invalid in [Double.nan, .infinity, -1] {
            controls.reportPlaybackTime(invalid, isPaused: false, using: tracker)
        }
        XCTAssertTrue(starts.isEmpty)
        actual = .nan
        controls.reportPlaybackTime(600, isPaused: false, using: tracker)
        XCTAssertTrue(starts.isEmpty)
        actual = 600.25
        controls.reportPlaybackTime(0, isPaused: false, using: tracker)
        XCTAssertEqual(starts, [600.25])
        XCTAssertEqual(progress, [600.25])
    }

    @MainActor
    func testServerClockPreservesConfirmedPositionDuringSeekAndAllowsBackwardZero() {
        var progress: [Double] = []
        var stopped: [Double] = []
        let tracker = MediaPlaybackTracker { event in
            if case .progressed(let position, _) = event { progress.append(position) }
            if case .stopped(let position, _) = event { stopped.append(position) }
        }
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 600)
        controls.isReady = true
        controls.updateClock(600.25)
        controls.reportPlaybackTime(600.25, isPaused: false, using: tracker)
        controls.isSeekable = true
        controls.durationSeconds = 1000
        controls.seekPlayback = { _ in }
        controls.seek(to: 0)
        controls.updateClock(0)
        controls.reportPlaybackTime(0, isPaused: true, using: tracker)
        XCTAssertEqual(progress, [600.25])
        controls.seekDidComplete(true)
        controls.updateClock(0)
        controls.reportPlaybackTime(0, isPaused: true, using: tracker)
        tracker.stopped()
        XCTAssertEqual(progress, [600.25, 0])
        XCTAssertEqual(stopped, [0])
    }

    @MainActor
    func testServerClockFailedSeekKeepsActualPositionInsteadOfTarget() {
        var progress: [Double] = []
        let tracker = MediaPlaybackTracker { event in
            if case .progressed(let position, _) = event { progress.append(position) }
        }
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 600)
        controls.isReady = true
        controls.readPlaybackClock = { 601.5 }
        controls.updateClock(601.5)
        controls.reportPlaybackTime(601.5, isPaused: false, using: tracker)
        controls.isSeekable = true
        controls.durationSeconds = 1000
        controls.seekPlayback = { _ in }
        controls.seek(to: 0.9)
        controls.reportPlaybackTime(900, isPaused: true, using: tracker)
        controls.seekDidComplete(false)
        controls.reportPlaybackTime(900, isPaused: true, using: tracker)
        XCTAssertEqual(progress, [601.5, 601.5])
    }

    @MainActor
    func testServerStartUsesAbsoluteTimelineAndResetsAcrossPlans() {
        var starts: [Double] = []
        let tracker = MediaPlaybackTracker { event in
            if case .started(let position) = event { starts.append(position) }
        }
        let controls = GreenfieldPlaybackControls()
        controls.engineName = "AVPlayer"
        controls.beginSession(initialPosition: 600)
        controls.isReady = true
        controls.readPlaybackClock = { 600.125 } // AV adapter adds the server HLS offset.
        controls.updateClock(600.125)
        controls.reportPlaybackTime(600.125, isPaused: false, using: tracker)
        XCTAssertEqual(starts, [600.125])
        tracker.stopped()
        let next = MediaPlaybackTracker { event in
            if case .started(let position) = event { starts.append(position) }
        }
        controls.beginSession(initialPosition: 1200)
        controls.readPlaybackClock = { 0 }
        controls.updateClock(0)
        controls.reportPlaybackTime(0, isPaused: false, using: next)
        XCTAssertEqual(starts, [600.125])
        controls.readPlaybackClock = { 1200.25 }
        controls.updateClock(1200.25)
        controls.reportPlaybackTime(1200.25, isPaused: false, using: next)
        XCTAssertEqual(starts, [600.125, 1200.25])
    }

    func testSubtitleViewportTracksPortraitLandscapeAndFill() throws {
        let video = CGSize(width: 3840, height: 2160)
        let portrait = try XCTUnwrap(PlaybackSubtitleViewportPolicy.videoRect(
            viewport: CGSize(width: 390, height: 844), video: video))
        XCTAssertEqual(portrait.width, 390)
        XCTAssertEqual(portrait.height, 219.375)
        XCTAssertEqual(portrait.midY, 422)
        XCTAssertLessThan(portrait.maxY, 600)
        XCTAssertEqual(PlaybackSubtitleViewportPolicy.bottomInset(viewport: CGSize(width: 390, height: 844),
            videoRect: portrait, screenBottomInset: 46), 12)
        let landscape = try XCTUnwrap(PlaybackSubtitleViewportPolicy.videoRect(
            viewport: CGSize(width: 844, height: 390), video: video))
        XCTAssertEqual(landscape.height, 390)
        XCTAssertEqual(landscape.midX, 422, accuracy: 0.000001)
        XCTAssertEqual(PlaybackSubtitleViewportPolicy.bottomInset(viewport: CGSize(width: 844, height: 390),
            videoRect: landscape, screenBottomInset: 33), 33)
        XCTAssertEqual(PlaybackSubtitleViewportPolicy.videoRect(viewport: CGSize(width: 390, height: 844),
            video: video, fillsScreen: true), CGRect(x: 0, y: 0, width: 390, height: 844))
        for invalid in [CGSize.zero, CGSize(width: CGFloat.nan, height: 1), CGSize(width: 1, height: CGFloat.infinity),
                        CGSize(width: -1, height: 1)] {
            XCTAssertNil(PlaybackSubtitleViewportPolicy.videoRect(viewport: invalid, video: video))
            XCTAssertNil(PlaybackSubtitleViewportPolicy.videoRect(viewport: video, video: invalid))
        }
    }

    @MainActor
    func testPortraitBilingualSubtitlePixelsUseLessOfTheVideoThanFixedTwentyPoints() throws {
        let viewport = CGSize(width: 430, height: 932)
        let video = CGSize(width: 3840, height: 1632)
        let rect = try XCTUnwrap(PlaybackSubtitleViewportPolicy.videoRect(viewport: viewport, video: video))
        let cue = "你之前让我以为我招募她\nYou made it sound as if I was recruiting her"
        func renderedRows(fixedSize: CGFloat?) throws -> [Int] {
            let view = PlaybackSubtitleViewport(videoSize: video, screenBottomInset: 46) { _ in
                Group {
                    if let fixedSize {
                        PlaybackSubtitleText(text: cue).environment(\.playbackSubtitleTextPointSize, fixedSize)
                    } else {
                        PlaybackSubtitleText(text: cue)
                    }
                }.padding(.horizontal, 24)
            }.frame(width: viewport.width, height: viewport.height).background(Color.black)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.uiImage)
            let cg = try XCTUnwrap(image.cgImage)
            let context = try XCTUnwrap(CGContext(data: nil, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(origin: .zero, size: viewport))
            let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
            let attachment = XCTAttachment(image: image)
            attachment.name = fixedSize == nil ? "portrait-adaptive-bilingual" : "portrait-fixed-20pt-reference"
            attachment.lifetime = .keepAlways
            add(attachment)
            return (0..<cg.height).filter { y in
                (0..<cg.width).contains { x in
                    let i = (y * cg.width + x) * 4
                    return pixels[i] > 220 && pixels[i + 1] > 220 && pixels[i + 2] > 220
                }
            }
        }
        let adaptive = try renderedRows(fixedSize: nil), old = try renderedRows(fixedSize: 20)
        let span = try XCTUnwrap(adaptive.last) - XCTUnwrap(adaptive.first) + 1
        let oldSpan = try XCTUnwrap(old.last) - XCTUnwrap(old.first) + 1
        XCTAssertLessThan(span, oldSpan)
        XCTAssertLessThan(CGFloat(span), rect.height * 0.2)
        XCTAssertGreaterThanOrEqual(CGFloat(try XCTUnwrap(adaptive.first)), rect.minY)
        XCTAssertLessThanOrEqual(CGFloat(try XCTUnwrap(adaptive.last)), rect.maxY - 12)
        XCTAssertEqual(PlaybackSubtitleViewportPolicy.textPointSize(
            videoRect: CGRect(x: 0, y: 0, width: 844, height: 390)), 20)
    }

    @MainActor
    func testExternalTextSubtitleActuallyStaysInsidePortraitVideo() throws {
        let viewport = CGSize(width: 390, height: 844)
        let video = CGSize(width: 3840, height: 2160)
        let view = PlaybackSubtitleViewport(videoSize: video, screenBottomInset: 46) { _ in
            PlaybackSubtitleText(text: "字幕测试\nEnglish caption").padding(.horizontal, 24)
        }.frame(width: viewport.width, height: viewport.height).background(Color.black)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage)
        let cg = try XCTUnwrap(image.cgImage)
        let context = try XCTUnwrap(CGContext(data: nil, width: cg.width, height: cg.height,
            bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cg, in: CGRect(origin: .zero, size: viewport))
        let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let rows = (0..<cg.height).filter { y in
            (0..<cg.width).contains { x in
                let i = (y * cg.width + x) * 4
                return pixels[i] > 220 && pixels[i + 1] > 220 && pixels[i + 2] > 220
            }
        }
        let rect = try XCTUnwrap(PlaybackSubtitleViewportPolicy.videoRect(viewport: viewport, video: video))
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(rows.first), Int(rect.minY))
        XCTAssertLessThanOrEqual(try XCTUnwrap(rows.last), Int(rect.maxY - 12))
        XCTAssertLessThan(try XCTUnwrap(rows.last), 600)
        let attachment = XCTAttachment(image: image)
        attachment.name = "portrait-external-caption-video-edge"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSubtitleAnchorUsesTheScreenEdgeAndItsSafeArea() {
        XCTAssertEqual(PlaybackSubtitleScreenEdgePolicy.bottomInset(safeAreaBottom: 0), 12)
        XCTAssertEqual(PlaybackSubtitleScreenEdgePolicy.bottomInset(safeAreaBottom: 21), 33)
        XCTAssertEqual(PlaybackSubtitleScreenEdgePolicy.bottomInset(safeAreaBottom: 34), 46)
    }

    func testSubtitleAnchorRejectsInvalidSafeAreaMeasurements() {
        for value: CGFloat in [-10, .nan, .infinity, -.infinity] {
            XCTAssertEqual(PlaybackSubtitleScreenEdgePolicy.bottomInset(safeAreaBottom: value), 12)
        }
    }

    func testPlaybackButtonsReserveSpaceAboveTheScreenEdgeCaptionBand() {
        XCTAssertGreaterThan(PlaybackSubtitleScreenEdgePolicy.captionBand,
            PlaybackSubtitleScreenEdgePolicy.edgeInset + 20,
            "Playback buttons must leave room for captions instead of lifting them above the timeline")
    }

    #if canImport(KSPlayer)
    @MainActor
    func testNativeBitmapSubtitleActuallyRendersAtTheVideoBottom() throws {
        let track = try makePausedPGSFixture()
        let cue = SubtitlePart(0, .infinity, attributedString: nil)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        cue.image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 40), format: format).image { context in
            UIColor.magenta.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 40))
        }
        cue.imageCanvasSize = CGSize(width: 1920, height: 1080)
        track.subtitle?.outputRenderQueue.push(SubtitleFrame(part: cue, timebase: .defaultValue))
        let model = SubtitleModel()
        model.selectedSubtitleInfo = track
        _ = model.subtitle(currentTime: 1)
        for viewport in [CGSize(width: 390, height: 844), CGSize(width: 844, height: 390), CGSize(width: 1024, height: 768)] {
            let view = GreenfieldSubtitleOverlay(model: model,
                videoSize: CGSize(width: 3840, height: 2160), bottomInset: 12)
                .frame(width: viewport.width, height: viewport.height)
                .background(Color.black)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.uiImage)
            let cgImage = try XCTUnwrap(image.cgImage)
            let width = cgImage.width, height = cgImage.height
            let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            let data = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
            let colouredRows = (0..<height).filter { y in
                let offset = (y * width + width / 2) * 4
                return data[offset] > 200 && data[offset + 1] < 40 && data[offset + 2] > 200
            }
            let lastRow = try XCTUnwrap(colouredRows.last)
            let rect = try XCTUnwrap(PlaybackSubtitleViewportPolicy.videoRect(viewport: viewport,
                video: CGSize(width: 3840, height: 2160)))
            XCTAssertEqual(Double(lastRow + 1), Double(rect.maxY - 12), accuracy: 1,
                "Caption pixels must follow the video bottom, including portrait letterboxing")
            let attachment = XCTAttachment(image: image)
            attachment.name = "native-caption-video-edge-\(width)x\(height)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testBitmapSubtitleUsesItsOwnCanvasAndFallsBackForUnknownCanvas() {
        let part = SubtitlePart(0, 1, attributedString: nil)
        part.image = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 100)).image { _ in UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 1000, height: 100)) }
        let video = CGSize(width: 3840, height: 2160)
        let bounds = CGSize(width: 800, height: 450)
        part.imageCanvasSize = CGSize(width: 1920, height: 1080)
        XCTAssertEqual(part.imageDisplaySize(in: bounds, videoSize: video).height, 100 * 800 / 1920, accuracy: 0.01)
        part.imageCanvasSize = .zero
        XCTAssertEqual(part.imageDisplaySize(in: bounds, videoSize: video).height, 100 * 800 / 3840, accuracy: 0.01)
        XCTAssertEqual(part.imageDisplaySize(in: .zero, videoSize: video), .zero)
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

    @MainActor
    func testAuthoredBitmapPixelsStayAtOriginInBothSharedAndMobileViews() throws {
        let track = try makePausedPGSFixture()
        let cue = SubtitlePart(0, .infinity, attributedString: nil)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        cue.image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 60), format: format).image { context in
            UIColor.magenta.setFill(); context.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
        }
        cue.origin = CGPoint(x: 96, y: 54)
        cue.imageCanvasSize = CGSize(width: 1920, height: 1080)
        let video = CGSize(width: 3840, height: 2160)
        XCTAssertNil(cue.imageDisplayFrame(videoFrame: CGRect(x: 0, y: 0, width: 960, height: 540), videoSize: video),
            "Unpositioned legacy images must keep their existing dialogue route")
        cue.imageUsesCanvasCoordinates = true
        track.subtitle?.outputRenderQueue.push(SubtitleFrame(part: cue, timebase: .defaultValue))
        let model = SubtitleModel(); model.selectedSubtitleInfo = track
        _ = model.subtitle(currentTime: 1)
        for viewport in [CGSize(width: 960, height: 540), CGSize(width: 390, height: 844)] {
            let frame = try XCTUnwrap(SubtitleViewportGeometry.videoFrame(viewport: viewport, video: video))
            let expected = try XCTUnwrap(cue.imageDisplayFrame(videoFrame: frame, videoSize: video))
            for shared in [true, false] {
                let content = Group {
                    if shared { SubtitleBitmapLayer(model: model, videoSize: video) }
                    else { GreenfieldSubtitleOverlay(model: model, videoSize: video, bottomInset: 46) }
                }.frame(width: viewport.width, height: viewport.height).background(Color.black)
                let renderer = ImageRenderer(content: content); renderer.scale = 1
                let image = try XCTUnwrap(renderer.uiImage), cg = try XCTUnwrap(image.cgImage)
                let context = try XCTUnwrap(CGContext(data: nil, width: cg.width, height: cg.height,
                    bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(cg, in: CGRect(origin: .zero, size: viewport))
                let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
                var xs = [Int](), ys = [Int]()
                for y in 0..<cg.height { for x in 0..<cg.width {
                    let i = (y * cg.width + x) * 4
                    if pixels[i] > 200 && pixels[i + 1] < 40 && pixels[i + 2] > 200 { xs.append(x); ys.append(y) }
                } }
                XCTAssertEqual(CGFloat(try XCTUnwrap(xs.min())), expected.minX, accuracy: 1)
                XCTAssertEqual(CGFloat(try XCTUnwrap(ys.min())), expected.minY, accuracy: 1)
                XCTAssertEqual(CGFloat(try XCTUnwrap(xs.max()) + 1), expected.maxX, accuracy: 1)
                XCTAssertEqual(CGFloat(try XCTUnwrap(ys.max()) + 1), expected.maxY, accuracy: 1,
                    "Mobile must not draw a second copy at the dialogue bottom")
                let attachment = XCTAttachment(image: image); attachment.lifetime = .keepAlways
                attachment.name = "authored-origin-\(shared ? "shared" : "mobile")-\(cg.width)x\(cg.height)"; add(attachment)
            }
        }
        cue.origin = .zero
        XCTAssertEqual(cue.imageDisplayFrame(videoFrame: CGRect(x: 0, y: 0, width: 960, height: 540), videoSize: video),
            CGRect(x: 0, y: 0, width: 60, height: 30), "Zero is a real authored coordinate")
    }

    func testBitmapQueueKeepsNewestDisplayIncludingClearAndReleasesSkippedFrames() {
        let queue = CircularBuffer<BitmapQueueTestFrame>(initialCapacity: 4, sorted: true)
        weak var released: BitmapQueueTestFrame?
        do {
            let frame = BitmapQueueTestFrame(1)
            released = frame
            queue.push(frame)
        }
        queue.push(BitmapQueueTestFrame(2))
        queue.push(BitmapQueueTestFrame(3, isClear: true))
        queue.push(BitmapQueueTestFrame(5))
        XCTAssertEqual(queue.popLatest { $0.timestamp <= 2 }?.timestamp, 2)
        XCTAssertNil(released)
        XCTAssertEqual(queue.count, 2)
        XCTAssertTrue(queue.popLatest { $0.timestamp <= 4 }?.isClear == true)
        XCTAssertNil(queue.popLatest { $0.timestamp <= 4 })
        XCTAssertEqual(queue.count, 1)
        queue.flush()
        for index in 0..<100 {
            queue.push(BitmapQueueTestFrame(Int64(index)))
            XCTAssertEqual(queue.popLatest { _ in true }?.timestamp, Int64(index))
        }
        queue.shutdown()
        XCTAssertNil(queue.popLatest { _ in true })
    }
    #endif
    func testRestrictiveWiFiSampleIsReconsideredWithoutReprobingEveryTap() {
        for measured in [true, false] {
            XCTAssertTrue(GreenfieldBandwidthSamplePolicy.canReuse(age: 29, networkKey: "wifi",
                wasMeasured: measured, safeBitrate: 45_000_000, originalSourceBitrate: 63_000_000))
            XCTAssertFalse(GreenfieldBandwidthSamplePolicy.canReuse(age: 30, networkKey: "wifi",
                wasMeasured: measured, safeBitrate: 45_000_000, originalSourceBitrate: 63_000_000))
        }
        XCTAssertFalse(GreenfieldBandwidthSamplePolicy.canReuse(age: 30, networkKey: "wifi",
            wasMeasured: false, safeBitrate: 80_000_000, originalSourceBitrate: 63_000_000),
            "A fallback budget is not a successful throughput measurement")
        XCTAssertTrue(GreenfieldOriginalPlaybackPolicy.retainsLargeRemoteGuard(networkKey: "wifi",
            bandwidthBasis: "networkFallback", sourceBitrate: 63_000_000, originalBudget: 80_000_000),
            "Expiring a low sample must not itself authorize original playback")
    }

    func testSufficientSamplesAndNonCandidatePlaybackKeepNormalCacheLifetime() {
        XCTAssertTrue(GreenfieldBandwidthSamplePolicy.canReuse(age: 599, networkKey: "wifi",
            wasMeasured: true, safeBitrate: 63_000_000, originalSourceBitrate: 63_000_000))
        for network in ["cellular", "constrained", "unknown"] {
            XCTAssertTrue(GreenfieldBandwidthSamplePolicy.canReuse(age: 599, networkKey: network,
                wasMeasured: true, safeBitrate: 10_000_000, originalSourceBitrate: 63_000_000))
        }
        for source in [nil, 0, -1] as [Int?] {
            XCTAssertTrue(GreenfieldBandwidthSamplePolicy.canReuse(age: 599, networkKey: "wifi",
                wasMeasured: false, safeBitrate: 10_000_000, originalSourceBitrate: source))
        }
        for age in [-1.0, 600, .infinity, .nan] {
            XCTAssertFalse(GreenfieldBandwidthSamplePolicy.canReuse(age: age, networkKey: "wifi",
                wasMeasured: true, safeBitrate: 80_000_000, originalSourceBitrate: 63_000_000))
        }
    }

    @MainActor
    func testAutomaticOriginalUsesKSDecodersAndPreservesQualityAndNetworkConstraints() {
        for codec in ["truehd", "flac", "eac3-joc", "dts-hd ma", " AC3 "] {
            let needsTranscode = GreenfieldOriginalPlaybackPolicy.requiresAudioTranscode(codec: codec,
                decoderAvailable: GreenfieldPlaybackControls.canDecodeOriginalAudio(codec))
            XCTAssertFalse(needsTranscode, codec)
            XCTAssertTrue(GreenfieldOriginalPlaybackPolicy.allowsOriginal(forcedServerBitrate: nil,
                audioRequiresTranscode: needsTranscode, subtitleRequiresServer: false,
                routeIsPrivate: true, explicitOriginal: false, remoteBitrateFits: false))
            XCTAssertFalse(GreenfieldOriginalPlaybackPolicy.allowsOriginal(forcedServerBitrate: 12_000_000,
                audioRequiresTranscode: needsTranscode, subtitleRequiresServer: false,
                routeIsPrivate: true, explicitOriginal: false, remoteBitrateFits: true),
                "An explicit lower quality must still use Jellyfin")
        }
        for codec in ["atmos", "unknown-codec", "h264"] {
            XCTAssertTrue(GreenfieldOriginalPlaybackPolicy.requiresAudioTranscode(codec: codec,
                decoderAvailable: GreenfieldPlaybackControls.canDecodeOriginalAudio(codec)))
        }
        XCTAssertFalse(GreenfieldOriginalPlaybackPolicy.allowsOriginal(forcedServerBitrate: nil,
            audioRequiresTranscode: true, subtitleRequiresServer: false, routeIsPrivate: true,
            explicitOriginal: true, remoteBitrateFits: true))
        XCTAssertFalse(GreenfieldOriginalPlaybackPolicy.allowsOriginal(forcedServerBitrate: nil,
            audioRequiresTranscode: false, subtitleRequiresServer: true, routeIsPrivate: true,
            explicitOriginal: false, remoteBitrateFits: true))
        XCTAssertFalse(GreenfieldOriginalPlaybackPolicy.allowsOriginal(forcedServerBitrate: nil,
            audioRequiresTranscode: false, subtitleRequiresServer: false, routeIsPrivate: false,
            explicitOriginal: false, remoteBitrateFits: false))
    }

    func testOriginalFirstIgnoresRemoteBudgetButPreservesQualityAndCapabilityFallbacks() {
        // Includes low cellular budgets and unknown source bitrate: neither is
        // evidence that KSPlayer cannot decode the original stream.
        for budgetFits in [false, true] {
            XCTAssertTrue(GreenfieldOriginalPlaybackPolicy.allowsOriginal(forcedServerBitrate: nil,
                audioRequiresTranscode: false, subtitleRequiresServer: false,
                routeIsPrivate: false, explicitOriginal: false, remoteBitrateFits: budgetFits,
                originalFirst: true))
            for forcedBitrate in [1_500_000, 12_000_000] {
                XCTAssertFalse(GreenfieldOriginalPlaybackPolicy.allowsOriginal(forcedServerBitrate: forcedBitrate,
                    audioRequiresTranscode: false, subtitleRequiresServer: false,
                    routeIsPrivate: false, explicitOriginal: false, remoteBitrateFits: budgetFits,
                    originalFirst: true), "Quality switches and adaptive fallback must remain effective")
            }
        }
        for (audio, subtitle) in [(true, false), (false, true)] {
            XCTAssertFalse(GreenfieldOriginalPlaybackPolicy.allowsOriginal(forcedServerBitrate: nil,
                audioRequiresTranscode: audio, subtitleRequiresServer: subtitle,
                routeIsPrivate: false, explicitOriginal: false, remoteBitrateFits: false,
                originalFirst: true))
        }
    }

    func testLargeOriginalOnlyBypassesSizeGuardWithSufficientMeasuredWiFi() {
        XCTAssertFalse(GreenfieldOriginalPlaybackPolicy.retainsLargeRemoteGuard(networkKey: "wifi",
            bandwidthBasis: "measured", sourceBitrate: 63_000_000, originalBudget: 70_000_000))
        for network in ["cellular", "constrained", "unknown"] {
            XCTAssertTrue(GreenfieldOriginalPlaybackPolicy.retainsLargeRemoteGuard(networkKey: network,
                bandwidthBasis: "measured", sourceBitrate: 63_000_000, originalBudget: 70_000_000))
        }
        XCTAssertTrue(GreenfieldOriginalPlaybackPolicy.retainsLargeRemoteGuard(networkKey: "wifi",
            bandwidthBasis: "networkFallback", sourceBitrate: 63_000_000, originalBudget: 80_000_000))
        for bitrate in [nil, 0, 81_000_000] as [Int?] {
            XCTAssertTrue(GreenfieldOriginalPlaybackPolicy.retainsLargeRemoteGuard(networkKey: "wifi",
                bandwidthBasis: "measured", sourceBitrate: bitrate, originalBudget: 80_000_000))
        }
    }

    func testMeasuredWiFiOriginalBudgetIsIndependentOfHLSEncoderCeiling() {
        let source = 81_851_565 // S19 exceeded the former fixed 80 Mbps ceiling.
        let budget = GreenfieldOriginalPlaybackPolicy.maximumOriginalBitrate(networkKey: "wifi",
            wasMeasured: true, rawBitrate: 95_000_000, conservativeBitrate: 76_000_000)
        XCTAssertEqual(budget, 95_000_000)
        XCTAssertFalse(GreenfieldOriginalPlaybackPolicy.retainsLargeRemoteGuard(networkKey: "wifi",
            bandwidthBasis: "measured", sourceBitrate: source, originalBudget: budget))
        XCTAssertTrue(GreenfieldOriginalPlaybackPolicy.allowsOriginal(forcedServerBitrate: nil,
            audioRequiresTranscode: false, subtitleRequiresServer: false, routeIsPrivate: false,
            explicitOriginal: false, remoteBitrateFits: source <= budget))
        XCTAssertFalse(GreenfieldOriginalPlaybackPolicy.allowsOriginal(forcedServerBitrate: 20_000_000,
            audioRequiresTranscode: false, subtitleRequiresServer: false, routeIsPrivate: false,
            explicitOriginal: false, remoteBitrateFits: source <= budget))
        XCTAssertTrue(GreenfieldBandwidthSamplePolicy.canReuse(age: 599, networkKey: "wifi",
            wasMeasured: true, safeBitrate: 76_000_000, originalSourceBitrate: source, rawBitrate: 95_000_000),
            "A valid original budget must not be re-probed just because the HLS budget is lower")
        let slowBudget = GreenfieldOriginalPlaybackPolicy.maximumOriginalBitrate(networkKey: "wifi",
            wasMeasured: true, rawBitrate: 75_000_000, conservativeBitrate: 60_000_000)
        XCTAssertTrue(GreenfieldOriginalPlaybackPolicy.retainsLargeRemoteGuard(networkKey: "wifi",
            bandwidthBasis: "measured", sourceBitrate: source, originalBudget: slowBudget))
    }

    func testOriginalBudgetDoesNotPromoteUnmeasuredOrCellularThroughput() {
        for network in ["cellular", "constrained", "unknown"] {
            XCTAssertEqual(GreenfieldOriginalPlaybackPolicy.maximumOriginalBitrate(networkKey: network,
                wasMeasured: true, rawBitrate: 200_000_000, conservativeBitrate: 20_000_000), 20_000_000)
        }
        XCTAssertEqual(GreenfieldOriginalPlaybackPolicy.maximumOriginalBitrate(networkKey: "wifi",
            wasMeasured: false, rawBitrate: 200_000_000, conservativeBitrate: 20_000_000), 20_000_000)
        for invalid in [0, -1] {
            XCTAssertEqual(GreenfieldOriginalPlaybackPolicy.maximumOriginalBitrate(networkKey: "wifi",
                wasMeasured: true, rawBitrate: invalid, conservativeBitrate: 20_000_000), 20_000_000)
        }
    }

    func testDolbySourceMetadataDoesNotCertifyOutputOrInferAtmosFromCodecAlone() {
        let vision = PlaybackDolbySourceInfo(visionProfile: 5, visionLevel: 6, baseLayerCompatibilityID: 0,
            audioCodec: "eac3", audioProfile: nil)
        XCTAssertEqual(vision.diagnosticDetails["sourceDVProfile"], "5")
        XCTAssertEqual(vision.audioEvidence, "eac3AtmosUnknown")
        XCTAssertEqual(vision.diagnosticDetails["dolbyVisionOutput"], "unverified")
        XCTAssertEqual(vision.diagnosticDetails["dolbyAtmosOutput"], "unverified")
        XCTAssertEqual(PlaybackDolbySourceInfo(audioCodec: "eac3", audioProfile: "Dolby Digital Plus + JOC").audioEvidence, "eac3JOC")
        XCTAssertEqual(PlaybackDolbySourceInfo(audioCodec: "truehd").audioEvidence, "trueHDAtmosUnknown")
        XCTAssertEqual(PlaybackDolbySourceInfo(audioCodec: "truehd", audioProfile: "TrueHD Atmos").audioEvidence, "trueHDAtmos")
        XCTAssertEqual(PlaybackDolbySourceInfo(audioCodec: "truehd", audioSpatialFormat: "DolbyAtmos").audioEvidence, "trueHDAtmos")
        XCTAssertEqual(PlaybackDolbySourceInfo(audioCodec: "eac3", audioSpatialFormat: "DolbyAtmos").audioEvidence, "eac3JOC")
        XCTAssertEqual(PlaybackDolbySourceInfo(audioCodec: "eac3", audioSpatialFormat: "None").audioEvidence, "eac3AtmosUnknown")
        XCTAssertEqual(PlaybackDolbySourceInfo(audioCodec: "aac", audioProfile: "Atmos").audioEvidence, "unknown")
        XCTAssertEqual(PlaybackDolbySourceInfo().diagnosticDetails["sourceDVProfile"], "unknown")
    }

    func testJellyfinPlaylistCompactQueryPreservesServerValuesAndIdentity() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/jellyfin/Videos/00000000000000000000000000000001/main.m3u8?api_key=test-token&PlaySessionId=test-session&VideoCodec=h264&AudioCodec=aac&VideoBitrate=122000&AudioBitrate=128000&MaxWidth=854&MaxHeight=480&AudioStreamIndex=1&SubtitleStreamIndex=-1&StartTimeTicks=123456789012&AllowVideoStreamCopy=false"))
        let compacted = try XCTUnwrap(PlaybackJellyfinPlaylistQuery.compact(url))
        let items = try XCTUnwrap(URLComponents(url: compacted, resolvingAgainstBaseURL: false)?.queryItems)
        let values = try XCTUnwrap(items.first { $0.name == "Params" }?.value)
            .components(separatedBy: ";")
        XCTAssertEqual(values, ["", "", "", "", "", "", "1", "-1", "122000", "128000", "", "", "854", "480", "123456789012"])
        for name in ["api_key", "PlaySessionId", "VideoCodec", "AudioCodec", "AllowVideoStreamCopy"] {
            let original = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }
            XCTAssertEqual(items.first { $0.name == name }, original)
        }
        XCTAssertEqual(compacted.path, url.path)
        XCTAssertLessThan(compacted.absoluteString.count, url.absoluteString.count)
    }

    func testJellyfinPlaylistCompactQueryRejectsAmbiguousAndForeignRequests() throws {
        let base = "https://example.com/Videos/00000000000000000000000000000001/main.m3u8?api_key=t&PlaySessionId=s&VideoBitrate=122000&AudioBitrate=128000&MaxWidth=854&MaxHeight=480"
        for value in [base + "&Params=existing", base + "&videobitrate=1", base + "&Static=unexpected", base + "&MaxVideoBitDepth=999999999999",
                      base.replacingOccurrences(of: "/Videos/", with: "/other/"),
                      base.replacingOccurrences(of: "main.m3u8", with: "0.ts"),
                      base.replacingOccurrences(of: "api_key=t&", with: "")] {
            XCTAssertNil(PlaybackJellyfinPlaylistQuery.compact(try XCTUnwrap(URL(string: value))))
        }
    }

    func testCompactPlaylistKeepsSourceDeviceAndDecimalHintsWithoutChangingAuthentication() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/Videos/00000000000000000000000000000001/master.m3u8?api_key=test-token&PlaySessionId=test-session&DeviceId=device-id&MediaSourceId=source-id&VideoCodec=h264&AudioCodec=aac&VideoBitrate=122000&AudioBitrate=128000&MaxFramerate=23.976&Level=41&Profile=high&TranscodingMaxAudioChannels=2&EnableSubtitlesInManifest=false"))
        let result = try XCTUnwrap(PlaybackJellyfinPlaylistQuery.compact(url))
        let items = try XCTUnwrap(URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems)
        let fields = try XCTUnwrap(items.first { $0.name == "Params" }?.value).components(separatedBy: ";")
        XCTAssertEqual(fields[1], "")
        XCTAssertEqual(fields[2], "")
        XCTAssertEqual(fields[11], "23.976")
        XCTAssertEqual(fields[15], "41")
        XCTAssertEqual(fields[18], "high")
        XCTAssertEqual(fields[26], "2")
        XCTAssertEqual(fields[27], "false")
        for name in ["api_key", "PlaySessionId", "DeviceId", "MediaSourceId", "VideoCodec", "AudioCodec"] {
            XCTAssertEqual(items.first { $0.name == name },
                URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name })
        }
        for (before, after) in [("Profile=high", "Profile=injected%3Bvalue"),
                                ("Level=41", "Level=NaN"),
                                ("MaxFramerate=23.976", "MaxFramerate=Infinity")] {
            XCTAssertNil(PlaybackJellyfinPlaylistQuery.compact(try XCTUnwrap(URL(string:
                url.absoluteString.replacingOccurrences(of: before, with: after)))))
        }
    }

    func testCompactMasterRetainsMediaSourceQueryBeforeParamsAreParsed() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\n0.ts\n#EXT-X-ENDLIST\n",
            requiresExplicitMediaSource: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        var components = URLComponents(url: try XCTUnwrap(server.url), resolvingAgainstBaseURL: false)!
        components.path = "/Videos/00000000000000000000000000000001/master.m3u8"
        components.query = "api_key=test-token&PlaySessionId=test-session&MediaSourceId=source-id&VideoBitrate=122000&AudioBitrate=128000&MaxWidth=854&MaxHeight=480"
        let compact = try XCTUnwrap(PlaybackJellyfinPlaylistQuery.compact(XCTUnwrap(components.url)))
        var missing = URLComponents(url: compact, resolvingAgainstBaseURL: false)!
        missing.queryItems = missing.queryItems?.filter { $0.name.lowercased() != "mediasourceid" }
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let (_, rejected) = try await session.data(from: XCTUnwrap(missing.url))
        XCTAssertEqual((rejected as? HTTPURLResponse)?.statusCode, 400)
        let (body, accepted) = try await session.data(from: compact)
        XCTAssertEqual((accepted as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(String(decoding: body, as: UTF8.self).contains("#EXT-X-ENDLIST"))
    }

    @MainActor
    func testVODPrewarmUsesItsFullDeadlineWhileProxyBuffersAMovingResponse() async throws {
        let prefix = "#EXTM3U\n#EXTINF:4,\n0.ts\n#"
        let payload = Data((prefix + String(repeating: "x", count: 1024 * 1024 - prefix.utf8.count - 18)
            + "\n#EXT-X-ENDLIST\n").utf8)
        let server = try PlaybackRangeTestServer(payload: payload,
            pacedBodyChunkBytes: 64 * 1024, pacedBodyDelay: 2, payloadIsPlaylist: true)
        defer { print("VOD_PACING_OBSERVATIONS", server.pacedResponseProgress) }
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 5)
        var components = URLComponents(url: try XCTUnwrap(server.url), resolvingAgainstBaseURL: false)!
        components.path = "/Videos/00000000000000000000000000000001/main.m3u8"
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(
            upstreamURL: XCTUnwrap(components.url), filename: "vod.m3u8", allowsSelfSignedCertificates: false)
        defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
        let oldConfiguration = URLSessionConfiguration.ephemeral
        oldConfiguration.timeoutIntervalForRequest = 30
        oldConfiguration.timeoutIntervalForResource = 35
        let oldSession = URLSession(configuration: oldConfiguration)
        defer { oldSession.invalidateAndCancel() }
        // The upstream is moving for 32 seconds; the buffering proxy sends
        // no local headers until complete. The enclosing budget is still 35.
        async let warmed = AuthenticatedMediaStreamProxy.shared.prewarmVODPlaylist(proxy)
        do {
            _ = try await oldSession.data(from: proxy)
            XCTFail("The former inner 30-second deadline must fail this buffered response")
        } catch {
            XCTAssertEqual((error as NSError).code, NSURLErrorTimedOut)
        }
        let cached = try await warmed
        XCTAssertTrue(cached)
        let completed = server.pacedResponseProgress.filter { $0.bytes == payload.count }
        XCTAssertFalse(completed.isEmpty, "The source must actually complete its paced response")
        XCTAssertTrue(completed.allSatisfy { $0.elapsed >= 30 && $0.elapsed < 35 },
                      "The fixture must exercise the original 30/35-second boundary")
    }

    @MainActor
    func testCompactPlaylistRejectionRetriesOriginalOnceWithoutOldTaskCancellation() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n", rejectsCompactQuery: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        var upstream = URLComponents(url: try XCTUnwrap(server.url), resolvingAgainstBaseURL: false)!
        upstream.path = "/Videos/00000000000000000000000000000001/main.m3u8"
        upstream.query = "api_key=test-token&PlaySessionId=test-session&VideoBitrate=122000&AudioBitrate=128000&MaxWidth=854&MaxHeight=480"
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(upstreamURL: XCTUnwrap(upstream.url), filename: "vod.m3u8", allowsSelfSignedCertificates: false)
        defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
        let (data, response) = try await URLSession.shared.data(from: proxy)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("#EXT-X-ENDLIST"))
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("/child/"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("test-token"))
        let requests = server.receivedRequests
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests[0].lowercased().contains("params="))
        XCTAssertFalse(requests[1].lowercased().contains("params="))
        XCTAssertTrue(requests[1].contains("VideoBitrate=122000"))
        XCTAssertTrue(requests.allSatisfy { $0.lowercased().contains("x-emby-token: test-token") })
    }

    func testVODPlaylistCacheRejectsLiveAndBoundsAndPartitionsRoutes() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/main.m3u8"))
        let body = Data("#EXTM3U\n#EXTINF:4,\na.ts\n#EXT-X-ENDLIST\n".utf8)
        let cache = PlaybackVODPlaylistCache(maximumBytes: body.count * 2, maximumEntryBytes: body.count)
        cache.store(Data("#EXTM3U\n#EXTINF:4,\na.ts\n".utf8), route: "live", url: url)
        XCTAssertNil(cache.data(route: "live", url: url))
        cache.store(body + Data([10]), route: "oversized", url: url)
        XCTAssertNil(cache.data(route: "oversized", url: url))
        cache.store(body, route: "one", url: url)
        XCTAssertNil(cache.data(route: "two", url: url))
        cache.store(body, route: "two", url: url)
        cache.store(body, route: "three", url: url)
        XCTAssertNil(cache.data(route: "one", url: url))
        XCTAssertEqual(cache.data(route: "two", url: url), body)
        cache.remove(route: "two")
        XCTAssertNil(cache.data(route: "two", url: url))
        XCTAssertEqual(cache.data(route: "three", url: url), body)
    }

    func testVODMasterCacheRequiresExactCompleteChildInSameRoute() throws {
        let root = try XCTUnwrap(URL(string: "https://example.com/master.m3u8?PlaySessionId=one"))
        let child = try XCTUnwrap(URL(string: "https://example.com/media.m3u8?PlaySessionId=one"))
        let master = Data("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500000\nmedia.m3u8\n".utf8)
        let vod = Data("#EXTM3U\n#EXTINF:4,\na.ts\n#EXT-X-ENDLIST\n".utf8)
        let cache = PlaybackVODPlaylistCache()
        cache.storeMaster(master, route: "a", url: root, childURL: child)
        XCTAssertNil(cache.data(route: "a", url: root))
        cache.store(Data("#EXTM3U\n#EXTINF:4,\na.ts\n".utf8), route: "a", url: child)
        XCTAssertNil(cache.data(route: "a", url: root), "A live child must not make its master reusable")
        cache.store(vod, route: "b", url: child)
        var differentSession = URLComponents(url: child, resolvingAgainstBaseURL: false)!
        differentSession.query = "PlaySessionId=two"
        cache.store(vod, route: "a", url: try XCTUnwrap(differentSession.url))
        XCTAssertNil(cache.data(route: "a", url: root), "Neither a different route nor session can validate this master")
        cache.store(vod, route: "a", url: child)
        XCTAssertEqual(cache.data(route: "a", url: root), master)
        cache.remove(route: "a")
        XCTAssertNil(cache.data(route: "a", url: root))
        XCTAssertEqual(cache.data(route: "b", url: child), vod)
    }

    func testVODMasterCacheRejectsAdaptiveRenditionsKeysAndUnsafeChildren() throws {
        let root = try XCTUnwrap(URL(string: "https://example.com/master.m3u8"))
        let child = try XCTUnwrap(URL(string: "https://example.com/media.m3u8"))
        let valid = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-INDEPENDENT-SEGMENTS\n#EXT-X-STREAM-INF:BANDWIDTH=500000\nmedia.m3u8\n"
        XCTAssertEqual(PlaybackVODPlaylistCache.singleVariantURI(in: valid), "media.m3u8")
        for tag in ["#EXT-X-MEDIA:TYPE=AUDIO,URI=\"audio.m3u8\"", "#EXT-X-SESSION-KEY:METHOD=AES-128,URI=\"key\"",
                    "#EXT-X-CONTENT-STEERING:SERVER-URI=\"steering\"", "#EXT-X-I-FRAME-STREAM-INF:URI=\"iframe.m3u8\"",
                    "#EXTINF:4,", "#EXT-X-ENDLIST", "#EXT-X-PART:URI=\"partial.ts\""] {
            XCTAssertNil(PlaybackVODPlaylistCache.singleVariantURI(in: valid + tag + "\n"), tag)
        }
        XCTAssertNil(PlaybackVODPlaylistCache.singleVariantURI(in: valid + "#EXT-X-STREAM-INF:BANDWIDTH=1000000\nhigh.m3u8\n"))
        let cache = PlaybackVODPlaylistCache()
        let body = Data("#EXTM3U\n#EXTINF:4,\na.ts\n#EXT-X-ENDLIST\n".utf8)
        for value in ["https://other.example/media.m3u8", "http://example.com/media.m3u8",
                      "https://example.com:444/media.m3u8", "https://user:pass@example.com/media.m3u8",
                      "https://example.com/media.m3u8#fragment", "https://example.com/a.ts"] {
            let unsafe = try XCTUnwrap(URL(string: value))
            cache.store(body, route: "a", url: unsafe)
            cache.storeMaster(Data(valid.utf8), route: "a", url: root, childURL: unsafe)
            XCTAssertNil(cache.data(route: "a", url: root), value)
        }
        cache.remove(route: "a")
        cache.storeMaster(Data(valid.utf8), route: "a", url: root, childURL: root)
        XCTAssertNil(cache.data(route: "a", url: root))
        cache.store(body, route: "a", url: child)
        cache.storeMaster(Data((valid + "#EXT-X-STREAM-INF:BANDWIDTH=1000000\nhigh.m3u8\n").utf8), route: "a", url: root, childURL: child)
        XCTAssertNil(cache.data(route: "a", url: root))
    }

    func testVODMasterCacheBecomesUnavailableWhenChildIsEvicted() throws {
        let root = try XCTUnwrap(URL(string: "https://example.com/master.m3u8"))
        let child = try XCTUnwrap(URL(string: "https://example.com/media.m3u8"))
        let master = Data("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500000\nmedia.m3u8\n".utf8)
        let body = Data("#EXTM3U\n#EXTINF:4,\na.ts\n#EXT-X-ENDLIST\n".utf8)
        let cache = PlaybackVODPlaylistCache(maximumBytes: master.count + body.count,
                                            maximumEntryBytes: master.count + body.count)
        cache.store(body, route: "a", url: child)
        cache.storeMaster(master, route: "a", url: root, childURL: child)
        XCTAssertEqual(cache.data(route: "a", url: root), master)
        cache.store(body, route: "b", url: child)
        XCTAssertNil(cache.data(route: "a", url: child))
        XCTAssertNil(cache.data(route: "a", url: root), "Do not serve an orphan master after bounded-cache eviction")
        XCTAssertEqual(cache.data(route: "b", url: child), body)
    }

    @MainActor
    func testCandidateManifestRequiresRegisteredRootAndKnownDuration() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = AuthenticatedMediaStreamProxy.shared
        let url = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "vod.m3u8",
                                          allowsSelfSignedCertificates: false)
        defer { proxy.unregister(url) }
        XCTAssertTrue(proxy.isRegisteredPlaylistRoot(url))
        var wrongPort = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        wrongPort.port = url.port == 1 ? 2 : 1
        XCTAssertFalse(proxy.isRegisteredPlaylistRoot(try XCTUnwrap(wrongPort.url)))
        XCTAssertFalse(proxy.isRegisteredPlaylistRoot(url.appendingPathComponent("child/0.m3u8")))
        XCTAssertFalse(proxy.isRegisteredPlaylistRoot(try XCTUnwrap(server.url)))
        for duration: Double? in [nil, 0, .infinity] {
            let request = MediaPlaybackRequest(url: url, title: "Unknown duration", totalDurationSeconds: duration)
            try await GreenfieldAVPlayerWarmup.prepareManifest(request, deadline: ProcessInfo.processInfo.systemUptime + 2)
        }
        let direct = MediaPlaybackRequest(url: try XCTUnwrap(server.url), title: "Unregistered", totalDurationSeconds: 4)
        try await GreenfieldAVPlayerWarmup.prepareManifest(direct, deadline: ProcessInfo.processInfo.systemUptime + 2)
        XCTAssertEqual(server.requestCount, 0)
        proxy.unregister(url)
        XCTAssertFalse(proxy.isRegisteredPlaylistRoot(url))
    }

    @MainActor
    func testCandidateManifestCachesOnlyCompleteVODBeforeAVPreparation() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n",
            masterPlaylist: "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500000\nmain.m3u8\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = AuthenticatedMediaStreamProxy.shared
        let url = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "vod.m3u8",
                                          allowsSelfSignedCertificates: false)
        defer { proxy.unregister(url) }
        var stages: [String] = []
        var cached: String?
        let request = MediaPlaybackRequest(url: url, title: "Candidate manifest", totalDurationSeconds: 4)
        try await GreenfieldAVPlayerWarmup.prepareManifest(request, deadline: ProcessInfo.processInfo.systemUptime + 5,
            report: { stage, fields in stages.append(stage); cached = fields["cachedVOD"] ?? cached })
        XCTAssertEqual(stages, ["candidate_manifest_preparing", "candidate_manifest_prepared"])
        XCTAssertEqual(cached, "true")
        XCTAssertEqual(server.requestCount, 2)
        let child = try await firstRewrittenHLSChild(url)
        let (body, response) = try await URLSession.shared.data(from: child)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(String(decoding: body, as: UTF8.self).contains("#EXT-X-ENDLIST"))
        XCTAssertEqual(server.requestCount, 2, "Validated VOD master and media must not repeat upstream reads")
        XCTAssertFalse(server.receivedRequests.contains { $0.contains(".ts ") })
    }

    @MainActor
    func testCandidateManifestLiveResultKeepsOrdinaryAVPathAvailable() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = AuthenticatedMediaStreamProxy.shared
        let url = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "live.m3u8",
                                          allowsSelfSignedCertificates: false)
        defer { proxy.unregister(url) }
        var cached: String?
        let request = MediaPlaybackRequest(url: url, title: "Live fallback", totalDurationSeconds: 4)
        try await GreenfieldAVPlayerWarmup.prepareManifest(request, deadline: ProcessInfo.processInfo.systemUptime + 5,
            report: { _, fields in cached = fields["cachedVOD"] ?? cached })
        XCTAssertEqual(cached, "false")
        XCTAssertTrue(proxy.isRegisteredPlaylistRoot(url), "A non-cacheable result must not revoke the candidate")
        let (_, response) = try await URLSession.shared.data(from: url)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(server.requestCount, 2)
    }

    @MainActor
    func testCandidateInvalidationStopsManifestBeforeAVItemAndPreservesOtherRoute() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n",
                                                holdsResponses: true)
        let other = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n")
        defer { server.stop(); other.stop() }
        await fulfillment(of: [server.ready, other.ready], timeout: 3)
        let proxy = AuthenticatedMediaStreamProxy.shared
        let trace = "MANIFEST-INVALIDATE-\(UUID().uuidString)"
        let url = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "vod.m3u8",
                                          allowsSelfSignedCertificates: false, playbackTraceID: trace)
        let otherURL = try await proxy.register(upstreamURL: XCTUnwrap(other.url), filename: "other.m3u8",
                                               allowsSelfSignedCertificates: false)
        defer { proxy.unregister(url); proxy.unregister(otherURL) }
        var current = true
        var events: [(String, [String: String])] = []
        let request = MediaPlaybackRequest(url: url, title: "Invalidated", totalDurationSeconds: 4)
        let task = Task { await GreenfieldAVPlayerWarmup.prepare(request, candidateStillCurrent: { current },
            report: { events.append(($0, $1)) }) }
        try await awaitProxyFixture { server.requestCount == 1 }
        current = false
        let candidate = await task.value
        XCTAssertNil(candidate)
        XCTAssertFalse(events.contains { $0.0 == "candidate_preparing" }, "No AV consumer before complete manifest")
        XCTAssertEqual(events.last?.0, "warmup_failed")
        XCTAssertEqual(events.last?.1["stage"], "manifestPreparation")
        try await awaitProxyFixture {
            self.proxyFixtureDetails(trace).contains { $0.contains("stage=upstreamCancellationRequested") }
        }
        let (_, response) = try await URLSession.shared.data(from: otherURL)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        server.releaseResponses()
        XCTAssertEqual(server.requestCount, 1, "Late data must not reopen a cancelled manifest")
    }

    @MainActor
    func testCandidateManifestCancellationAndDeadlineStopOwnTransfer() async throws {
        for cancel in [true, false] {
            let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n",
                                                    holdsResponses: true)
            defer { server.stop() }
            await fulfillment(of: [server.ready], timeout: 3)
            let trace = "MANIFEST-END-\(UUID().uuidString)"
            let proxy = AuthenticatedMediaStreamProxy.shared
            let url = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "vod.m3u8",
                                              allowsSelfSignedCertificates: false, playbackTraceID: trace)
            defer { proxy.unregister(url) }
            let request = MediaPlaybackRequest(url: url, title: "Bounded", totalDurationSeconds: 4)
            let deadline = ProcessInfo.processInfo.systemUptime + (cancel ? 5 : 0.5)
            let task = Task { try await GreenfieldAVPlayerWarmup.prepareManifest(request, deadline: deadline) }
            try await awaitProxyFixture { server.requestCount == 1 }
            if cancel { task.cancel() }
            do { try await task.value; XCTFail("Cancelled/expired manifest preparation must not succeed") }
            catch {
                if cancel { XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled) }
                else { XCTAssertEqual((error as? URLError)?.code, .timedOut) }
            }
            try await awaitProxyFixture {
                self.proxyFixtureDetails(trace).contains { $0.contains("stage=upstreamCancellationRequested") }
            }
            server.releaseResponses()
            XCTAssertEqual(server.requestCount, 1)
        }
    }

    @MainActor
    func testCandidateManifestCancelPreservesIndependentReaderOfSameRoute() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n",
                                                holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = AuthenticatedMediaStreamProxy.shared
        let trace = "MANIFEST-SHARED-\(UUID().uuidString)"
        let url = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "vod.m3u8",
                                          allowsSelfSignedCertificates: false, playbackTraceID: trace)
        defer { proxy.unregister(url) }
        let reader = Task { try await URLSession.shared.data(from: url) }
        defer { reader.cancel() }
        try await awaitProxyFixture { server.requestCount == 1 }
        let request = MediaPlaybackRequest(url: url, title: "Separate consumer", totalDurationSeconds: 4)
        let preparation = Task { try await GreenfieldAVPlayerWarmup.prepareManifest(request,
            deadline: ProcessInfo.processInfo.systemUptime + 5) }
        try await awaitProxyFixture { server.requestCount == 2 }
        preparation.cancel()
        do { try await preparation.value; XCTFail("Preparation must stop") }
        catch { XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled) }
        try await awaitProxyFixture {
            self.proxyFixtureDetails(trace).filter { $0.contains("stage=upstreamCancellationRequested") }.count == 1
        }
        XCTAssertTrue(proxy.isRegisteredPlaylistRoot(url))
        server.releaseResponses()
        let (data, response) = try await reader.value
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("#EXT-X-ENDLIST"))
        XCTAssertFalse(server.receivedRequests.contains { $0.lowercased().contains("x-nastart-manifest-preparation") },
                       "Preparation identity stays on the loopback request")
    }

    @MainActor
    func testExpiredCandidateManifestDeadlineDoesNotStartTransfer() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = AuthenticatedMediaStreamProxy.shared
        let url = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "vod.m3u8",
                                          allowsSelfSignedCertificates: false)
        defer { proxy.unregister(url) }
        do {
            try await GreenfieldAVPlayerWarmup.prepareManifest(
                MediaPlaybackRequest(url: url, title: "Expired", totalDurationSeconds: 4),
                deadline: ProcessInfo.processInfo.systemUptime - 1)
            XCTFail("An expired budget must not fetch a manifest")
        } catch { XCTAssertEqual((error as? URLError)?.code, .timedOut) }
        XCTAssertEqual(server.requestCount, 0)
    }

    @MainActor
    func testVODPrewarmReusesManifestAndRewritesNewSeekWithoutFetchingSegments() async throws {
        let playlist = "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXTINF:4,\nsegment1.ts\n#EXT-X-ENDLIST\n"
        let server = try PlaybackRangeTestServer(playlist: playlist,
            masterPlaylist: "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500000\nmain.m3u8\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(upstreamURL: XCTUnwrap(server.url),
            filename: "vod.m3u8", allowsSelfSignedCertificates: false)
        defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
        let warmed = try await AuthenticatedMediaStreamProxy.shared.prewarmVODPlaylist(proxy)
        XCTAssertTrue(warmed)
        XCTAssertEqual(server.receivedRequests.count, 2, "Only master and media text, no segments or keys")
        AuthenticatedMediaStreamProxy.shared.setPlaylistStart(proxy, seconds: 5.25)
        let (master, _) = try await URLSession.shared.data(from: proxy)
        let child = try XCTUnwrap(String(decoding: master, as: UTF8.self).components(separatedBy: "\n")
            .first(where: { $0.hasPrefix("http://") }).flatMap(URL.init(string:)))
        let (data, response) = try await URLSession.shared.data(from: child)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(response.expectedContentLength, Int64(data.count))
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("TIME-OFFSET=5.250"))
        XCTAssertEqual(server.receivedRequests.count, 2, "Decoder read must reuse both validated master and complete media text")
        AuthenticatedMediaStreamProxy.shared.unregister(proxy)
        let (_, removed) = try await URLSession.shared.data(from: child)
        XCTAssertEqual((removed as? HTTPURLResponse)?.statusCode, 404)
    }

    @MainActor
    func testLivePlaylistPrewarmDoesNotClaimReusableVOD() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(upstreamURL: XCTUnwrap(server.url),
            filename: "live.m3u8", allowsSelfSignedCertificates: false)
        defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
        let warmed = try await AuthenticatedMediaStreamProxy.shared.prewarmVODPlaylist(proxy)
        XCTAssertFalse(warmed)
        _ = try await URLSession.shared.data(from: proxy)
        XCTAssertEqual(server.receivedRequests.count, 2)
    }

    @MainActor
    func testVODMasterWithLiveChildKeepsBothUpstreamReadsAvailable() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n",
            masterPlaylist: "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500000\nmain.m3u8\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(upstreamURL: XCTUnwrap(server.url),
            filename: "live-master.m3u8", allowsSelfSignedCertificates: false)
        defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
        let warmed = try await AuthenticatedMediaStreamProxy.shared.prewarmVODPlaylist(proxy)
        XCTAssertFalse(warmed)
        XCTAssertEqual(server.requestCount, 2)
        let child = try await firstRewrittenHLSChild(proxy)
        _ = try await URLSession.shared.data(from: child)
        XCTAssertEqual(server.requestCount, 4, "A master must not be reused merely because its first child was fetched")
    }

    @MainActor
    func testVODMasterReuseResolvesInheritedSessionAndRewritesOpaqueChildren() async throws {
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\nsegment0.ts\n#EXT-X-ENDLIST\n",
            masterPlaylist: "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500000\nmain.m3u8\n")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        var upstream = try XCTUnwrap(URLComponents(url: XCTUnwrap(server.url), resolvingAgainstBaseURL: false))
        upstream.query = "api_key=test-token&PlaySessionId=session-one&MediaSourceId=source-one"
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(upstreamURL: XCTUnwrap(upstream.url),
            filename: "master.m3u8", allowsSelfSignedCertificates: false)
        defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
        let warmed = try await AuthenticatedMediaStreamProxy.shared.prewarmVODPlaylist(proxy)
        XCTAssertTrue(warmed)
        let child = try await firstRewrittenHLSChild(proxy)
        XCTAssertFalse(child.absoluteString.contains("test-token"))
        XCTAssertFalse(child.absoluteString.contains("session-one"))
        _ = try await URLSession.shared.data(from: child)
        XCTAssertEqual(server.requestCount, 2)
        XCTAssertTrue(server.receivedRequests[1].contains("PlaySessionId=session-one"))
        XCTAssertTrue(server.receivedRequests[1].lowercased().contains("x-emby-token: test-token"))
    }

    func testStartupPrimerPolicyRejectsLiveMasterExternalAndOffsetPlaylists() throws {
        let root = try XCTUnwrap(URL(string: "http://127.0.0.1:8000/media/route/main.m3u8"))
        let nested = try XCTUnwrap(URL(string: "http://127.0.0.1:8000/media/route/child/0.m3u8"))
        let valid = "#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:4,\nhttp://127.0.0.1:8000/media/route/child/1.ts\n#EXT-X-ENDLIST\n"
        XCTAssertNotNil(PlaybackHLSStartupPrimerPolicy.candidate(in: valid, playlistURL: root))
        XCTAssertNotNil(PlaybackHLSStartupPrimerPolicy.candidate(in: valid, playlistURL: nested))
        for invalid in [valid.replacingOccurrences(of: "#EXT-X-ENDLIST", with: ""),
            valid.replacingOccurrences(of: "SEQUENCE:0", with: "SEQUENCE:25"),
            valid.replacingOccurrences(of: "/media/route/child/1.ts", with: "/media/other/child/1.ts"),
            valid.replacingOccurrences(of: ":8000/media", with: ":8001/media"),
            valid.replacingOccurrences(of: "1.ts", with: "1.ts?api_key=secret"),
            valid.replacingOccurrences(of: "1.ts", with: "1.m4s")] {
            XCTAssertNil(PlaybackHLSStartupPrimerPolicy.candidate(in: invalid, playlistURL: root))
        }
        for tag in ["#EXT-X-STREAM-INF:BANDWIDTH=1", "#EXT-X-KEY:METHOD=AES-128,URI=key",
                    "#EXT-X-MAP:URI=init.mp4", "#EXT-X-BYTERANGE:1@0", "#EXT-X-START:TIME-OFFSET=4"] {
            XCTAssertNil(PlaybackHLSStartupPrimerPolicy.candidate(in: valid.replacingOccurrences(of: "#EXTINF", with: tag + "\n#EXTINF"), playlistURL: root))
        }
        XCTAssertTrue(PlaybackHLSStartupPrimerPolicy.accepts(status: 206, contentRange: "bytes 0-0/123", contentLength: "1"))
        for (status, range, length) in [(200, "bytes 0-0/123", "1"), (206, "bytes 0-3/123", "4"),
                                       (206, "bytes 0-0/*", "1"), (206, "bytes 0-0/0", "1"), (206, "bytes 0-0/123", "123")] {
            XCTAssertFalse(PlaybackHLSStartupPrimerPolicy.accepts(status: status, contentRange: range, contentLength: length))
        }
    }

    @MainActor
    func testStartupPrimerReturnsBeforeHeadersIsSingleAndRouteCancellationIsIsolated() async throws {
        let response = "HTTP/1.1 206 Partial Content\r\nContent-Length: 1\r\nContent-Range: bytes 0-0/4\r\nConnection: close\r\n\r\nt"
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\n0.ts\n#EXT-X-ENDLIST\n",
            startupSegmentResponse: response, holdsSegmentResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = AuthenticatedMediaStreamProxy.shared
        let aTrace = "primer-a-" + UUID().uuidString, bTrace = "primer-b-" + UUID().uuidString
        let a = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "a.m3u8", allowsSelfSignedCertificates: false,
            playbackTraceID: aTrace, jellyfinMediaPath: "/fixture/a.mkv")
        let b = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "b.m3u8", allowsSelfSignedCertificates: false,
            playbackTraceID: bTrace, jellyfinMediaPath: "/fixture/b.mkv")
        defer { proxy.unregister(a); proxy.unregister(b) }
        let warmed = try await proxy.prewarmVODPlaylist(a, primesFirstSegment: true)
        XCTAssertTrue(warmed, "Preparation returns while the primer headers are still held")
        try await awaitProxyFixture { server.requestCount == 2 }
        _ = try await proxy.prewarmVODPlaylist(a, primesFirstSegment: true)
        XCTAssertEqual(server.requestCount, 2, "One route must not create a second primer")
        _ = try await proxy.prewarmVODPlaylist(b, primesFirstSegment: true)
        try await awaitProxyFixture { server.requestCount == 4 }
        proxy.unregister(a)
        try await awaitProxyFixture { self.proxyFixtureDetails(aTrace).contains { $0.contains("stage=upstreamCancellationRequested") } }
        XCTAssertFalse(proxyFixtureDetails(bTrace).contains { $0.contains("stage=upstreamCancellationRequested") })
        server.releaseResponses()
        try await awaitProxyFixture { DiagnosticLogStore.shared.entries.contains {
            $0.messageKey == "diagnostics.media.startup_segment_primer" && $0.detail.contains(bTrace) && $0.detail.contains("result=complete") } }
        XCTAssertNil(PlaybackRecentThroughputStore.shared.estimate(traceID: bTrace, now: ProcessInfo.processInfo.systemUptime))
        XCTAssertEqual(server.receivedRequests.filter { $0.contains("bytes=0-0") }.count, 2)
        XCTAssertTrue(server.receivedRequests.allSatisfy { !$0.lowercased().contains("x-nastart-startup-primer") }, "Local ownership header must not leave the proxy")
    }

    @MainActor
    func testStartupPrimerRejectsIgnoredRangeAndRedirectBeforeBody() async throws {
        for response in ["HTTP/1.1 200 OK\r\nContent-Type: video/mp2t\r\nContent-Length: 10000000\r\nConnection: close\r\n\r\nx",
                         "HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:9/must-not-follow\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"] {
            let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\n0.ts\n#EXT-X-ENDLIST\n", startupSegmentResponse: response)
            defer { server.stop() }
            await fulfillment(of: [server.ready], timeout: 3)
            let trace = "primer-reject-" + UUID().uuidString
            let proxy = try await AuthenticatedMediaStreamProxy.shared.register(upstreamURL: XCTUnwrap(server.url), filename: "test.m3u8",
                allowsSelfSignedCertificates: false, playbackTraceID: trace, jellyfinMediaPath: "/fixture/test.mkv")
            defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
            _ = try await AuthenticatedMediaStreamProxy.shared.prewarmVODPlaylist(proxy, primesFirstSegment: true)
            try await awaitProxyFixture { self.proxyFixtureDetails(trace).contains { $0.contains("finishSource=startupPrimerRejected") } }
            XCTAssertEqual(server.requestCount, 2)
            XCTAssertFalse(proxyFixtureDetails(trace).contains { $0.contains("stage=upstreamBodyProgress") })
        }
    }

    @MainActor
    func testStartupPrimerSkipsResumedNonzeroAndCancelledPreparation() async throws {
        let proxy = AuthenticatedMediaStreamProxy.shared
        for (segment, offset) in [("25.ts", 0.0), ("0.ts", 5.25)] {
            let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\n" + segment + "\n#EXT-X-ENDLIST\n")
            defer { server.stop() }
            await fulfillment(of: [server.ready], timeout: 3)
            let local = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "resume.m3u8", allowsSelfSignedCertificates: false,
                jellyfinMediaPath: "/fixture/test.mkv")
            defer { proxy.unregister(local) }
            if offset > 0 { proxy.setPlaylistStart(local, seconds: offset) }
            _ = try await proxy.prewarmVODPlaylist(local, primesFirstSegment: true)
            XCTAssertEqual(server.requestCount, 1, "Never warm the zero segment of a resumed timeline")
        }
        let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\n0.ts\n#EXT-X-ENDLIST\n", holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let local = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "cancel.m3u8", allowsSelfSignedCertificates: false,
            jellyfinMediaPath: "/fixture/test.mkv")
        defer { proxy.unregister(local) }
        let task = Task { try await proxy.prewarmVODPlaylist(local, primesFirstSegment: true) }
        try await awaitProxyFixture { server.requestCount == 1 }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled preparation must throw") } catch {}
        server.releaseResponses()
        XCTAssertEqual(server.requestCount, 1)
    }

    @MainActor
    func testStartupPrimerDeadlineCancelsUpstreamWithoutHeadersAndSeekCancelsOwnedTask() async throws {
        let proxy = AuthenticatedMediaStreamProxy.shared
        for missingType in [true, false] {
            // CFNetwork can defer the response callback while sniffing an
            // untyped, incomplete body. The independent deadline must still
            // cancel the owned upstream instead of waiting for that callback.
            let response = missingType
                ? "HTTP/1.1 200 OK\r\nContent-Length: 10000000\r\nConnection: close\r\n\r\nx"
                : "HTTP/1.1 206 Partial Content\r\nContent-Length: 1\r\nContent-Range: bytes 0-0/4\r\nConnection: close\r\n\r\nt"
            let server = try PlaybackRangeTestServer(playlist: "#EXTM3U\n#EXTINF:4,\n0.ts\n#EXT-X-ENDLIST\n",
                startupSegmentResponse: response, holdsSegmentResponses: !missingType)
            defer { server.stop() }
            await fulfillment(of: [server.ready], timeout: 3)
            let trace = "primer-deadline-" + UUID().uuidString
            let local = try await proxy.register(upstreamURL: XCTUnwrap(server.url), filename: "test.m3u8",
                allowsSelfSignedCertificates: false, playbackTraceID: trace, jellyfinMediaPath: "/fixture/test.mkv")
            defer { proxy.unregister(local) }
            let started = ProcessInfo.processInfo.systemUptime
            _ = try await proxy.prewarmVODPlaylist(local, primesFirstSegment: true)
            try await awaitProxyFixture { server.requestCount == 2 }
            if !missingType { proxy.setPlaylistStart(local, seconds: 45) }
            for _ in 0..<750 {
                if proxyFixtureDetails(trace).contains(where: { $0.contains("stage=upstreamCancellationRequested") }) { break }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTAssertTrue(proxyFixtureDetails(trace).contains { $0.contains("stage=upstreamCancellationRequested") })
            XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, missingType ? 8 : 3)
            XCTAssertEqual(server.requestCount, 2, "No automatic loopback retry")
            XCTAssertFalse(proxyFixtureDetails(trace).contains { $0.contains("stage=upstreamBodyProgress") })
        }
    }

    func testMediaRangePolicyRejectsMalformedRangesWithoutInventingFileHead() {
        for value in ["", "bytes=", "items=0-1", "bytes=-0", "bytes=-", "bytes=2-1",
                      "bytes=0-1,3-4", "bytes=+1-2", "bytes=1-+2", "bytes=0-no",
                      "bytes=0--1", "bytes= 0-1", "bytes=9223372036854775808-",
                      "bytes=-9223372036854775808"] {
            XCTAssertNil(MediaRangePolicy.requestedRange(value), value)
            XCTAssertNil(MediaRangePolicy.boundedRange(value), value)
            XCTAssertFalse(MediaRangePolicy.isOpenEnded(value), value)
        }
    }

    func testMediaRangePolicyResolvesSuffixAndClampsWithoutOverflow() {
        XCTAssertEqual(MediaRangePolicy.requestedRange("bytes=-500"), .suffix(500))
        XCTAssertNil(MediaRangePolicy.boundedRange("bytes=-500"))
        XCTAssertEqual(MediaRangePolicy.boundedRange("bytes=-500", totalLength: 1_000), "bytes=500-999")
        XCTAssertEqual(MediaRangePolicy.boundedRange("bytes=-500", maximumLength: 100, totalLength: 1_000), "bytes=500-599")
        XCTAssertEqual(MediaRangePolicy.boundedRange("bytes=-500", totalLength: 10), "bytes=0-9")
        XCTAssertNil(MediaRangePolicy.boundedRange("bytes=-500", totalLength: 0))
        XCTAssertEqual(MediaRangePolicy.boundedRange("bytes=9223372036854775807-"), "bytes=9223372036854775807-9223372036854775807")
        XCTAssertEqual(MediaRangePolicy.boundedRange("bytes=9223372036854775800-", maximumLength: .max), "bytes=9223372036854775800-9223372036854775807")
        XCTAssertEqual(MediaRangePolicy.boundedRange(" BYTES=100-199 ", maximumLength: 20), "bytes=100-119")
        XCTAssertNil(MediaRangePolicy.boundedRange("bytes=0-", maximumLength: 0))
        XCTAssertNil(MediaRangePolicy.boundedRange("bytes=10-", totalLength: 10))
    }

    @MainActor
    func testOriginalProxyResolvesSuffixWithFiniteProbeAndRejectsInvalidRangesLocally() async throws {
        let payload = Data((0..<1_024).map { UInt8($0 % 251) })
        let server = try PlaybackRangeTestServer(payload: payload)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = try await AuthenticatedMediaStreamProxy.shared.registerOriginalStream(
            upstreamURL: XCTUnwrap(server.url), filename: "fixture.mkv", allowsSelfSignedCertificates: false)
        defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
        let client = URLSession(configuration: .ephemeral)
        defer { client.invalidateAndCancel() }
        for (range, start) in [("bytes=-500", 524), ("bytes=-2000", 0)] {
            var request = URLRequest(url: proxy)
            request.timeoutInterval = 5
            request.setValue(range, forHTTPHeaderField: "Range")
            let (data, response) = try await client.data(for: request)
            let http = try XCTUnwrap(response as? HTTPURLResponse)
            XCTAssertEqual(http.statusCode, 206)
            XCTAssertEqual(http.value(forHTTPHeaderField: "Content-Range"), "bytes \(start)-1023/1024")
            XCTAssertEqual(data, payload.subdata(in: start..<payload.count))
        }
        let issued = server.requestCount
        XCTAssertEqual(issued, 4)
        for value in ["bytes=-0", "bytes=100-99", "bytes=0-0,999-999", "bytes=9223372036854775808-"] {
            var request = URLRequest(url: proxy)
            request.timeoutInterval = 5
            request.setValue(value, forHTTPHeaderField: "Range")
            let (data, response) = try await client.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 416, value)
            XCTAssertTrue(data.isEmpty)
        }
        XCTAssertEqual(server.requestCount, issued, "Malformed requests must not read the upstream")
        let headers = server.receivedRequests.map { $0.lowercased() }
        XCTAssertTrue(headers[0].contains("range: bytes=0-0\r\n"))
        XCTAssertTrue(headers[1].contains("range: bytes=524-1023\r\n"))
    }

    @MainActor
    func testOriginalProxySuffixRejectsEmptyIgnoredAndChangedRepresentations() async throws {
        let probe = "HTTP/1.1 206 Partial Content\r\nContent-Type: video/mp4\r\nContent-Length: 1\r\nContent-Range: bytes 0-0/10\r\nETag: \"v1\"\r\nConnection: close\r\n\r\nx"
        let ignored = "HTTP/1.1 200 OK\r\nContent-Type: video/mp4\r\nContent-Length: 10\r\nETag: \"v2\"\r\nConnection: close\r\n\r\n0123456789"
        let empty = "HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */0\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        let changedLength = "HTTP/1.1 206 Partial Content\r\nContent-Type: video/mp4\r\nContent-Length: 3\r\nContent-Range: bytes 7-9/11\r\nConnection: close\r\n\r\n789"
        let cases: [(responses: [String], status: Int)] = [([empty], 416), ([ignored], 502),
            ([probe, ignored], 502), ([probe, changedLength], 502)]
        // Repeat fresh routes to cover cancellation callbacks racing the local
        // error response; no rejected response may expose a file-head body.
        for scenario in cases {
            for _ in 0..<3 {
                let server = try PlaybackRangeTestServer(rawResponses: scenario.responses)
                defer { server.stop() }
                await fulfillment(of: [server.ready], timeout: 3)
                let proxy = try await AuthenticatedMediaStreamProxy.shared.registerOriginalStream(
                    upstreamURL: XCTUnwrap(server.url), filename: "fixture.mkv", allowsSelfSignedCertificates: false)
                defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
                let client = URLSession(configuration: .ephemeral)
                defer { client.invalidateAndCancel() }
                var request = URLRequest(url: proxy)
                request.timeoutInterval = 5
                request.setValue("bytes=-3", forHTTPHeaderField: "Range")
                let (data, response) = try await client.data(for: request)
                let http = try XCTUnwrap(response as? HTTPURLResponse)
                XCTAssertEqual(http.statusCode, scenario.status)
                XCTAssertTrue(data.isEmpty)
                XCTAssertEqual(server.requestCount, scenario.responses.count)
                if scenario.status == 416 {
                    XCTAssertEqual(http.value(forHTTPHeaderField: "Content-Range"), "bytes */0")
                }
                if scenario.responses.count == 2 {
                    XCTAssertTrue(server.receivedRequests[1].lowercased().contains("if-range: \"v1\"\r\n"))
                    XCTAssertTrue(server.receivedRequests[1].contains("bytes=7-9"))
                }
            }
        }
    }

    @MainActor
    func testNetworkLibraryBridgeThroughSharedProxyPreservesRangeAndRevokesLease() async throws {
        let window = Int(MediaRangePolicy.upstreamWindowBytes)
        let reader = ProxyBridgeFixture(byteCount: Int64(window + 32))
        let bridge = WebDAVPlaybackSession(reader: reader)
        defer { bridge.stop() }
        let upstream = try await bridge.start()
        let proxy = AuthenticatedMediaStreamProxy.shared
        let trace = "network-bridge-" + UUID().uuidString
        let url = try await proxy.registerOriginalStream(upstreamURL: upstream, filename: "video.mkv",
            allowsSelfSignedCertificates: false, playbackTraceID: trace, upstreamIsNetworkLibraryBridge: true)
        var lease: PlaybackProxyRouteLease? = PlaybackProxyRouteLease(url: url)
        XCTAssertEqual(lease?.url, url)
        let client = URLSession(configuration: .ephemeral)
        defer { client.invalidateAndCancel() }
        var head = URLRequest(url: url)
        head.httpMethod = "HEAD"
        let (headBody, headResponse) = try await client.data(for: head)
        XCTAssertTrue(headBody.isEmpty)
        XCTAssertEqual(headResponse.expectedContentLength, Int64(window + 32))
        try await awaitProxyFixture {
            proxyFixtureDetails(trace).contains { $0.contains("finishSource=clientTerminalSend") }
        }
        let headEvents = proxyFixtureDetails(trace)
        XCTAssertEqual(headEvents.filter { $0.contains("stage=upstreamTaskCompleted") }.count, 1)
        XCTAssertTrue(headEvents.contains { $0.contains("finishSource=clientTerminalSend") && $0.contains("upstreamTaskIndex=1") })
        XCTAssertFalse(headEvents.contains { $0.contains("stage=continuationResponse") })
        for (range, offset, count) in [("bytes=-\(window + 16)", 16, window + 16), ("bytes=4-7", 4, 4)] {
            var request = URLRequest(url: url)
            request.setValue(range, forHTTPHeaderField: "Range")
            request.timeoutInterval = 12
            let (data, response) = try await client.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 206)
            XCTAssertEqual(response.expectedContentLength, Int64(count))
            XCTAssertEqual(data, ProxyBridgeFixture.bytes(offset: Int64(offset), count: count))
        }
        let override = try XCTUnwrap(URL(string: url.absoluteString + "?u=http%3A%2F%2F127.0.0.1%3A1%2Fother"))
        let (_, denied) = try await client.data(from: override)
        XCTAssertEqual((denied as? HTTPURLResponse)?.statusCode, 404)
        try await awaitProxyFixture {
            proxyFixtureDetails(trace).contains { $0.contains("adaptiveMeasurementBoundary=ineligibleBridgeDelivery") }
        }
        XCTAssertTrue(proxyFixtureDetails(trace).contains { $0.contains("measurementBoundary=bridgeDelivery") })
        lease = nil
        let (_, revoked) = try await client.data(from: url)
        XCTAssertEqual((revoked as? HTTPURLResponse)?.statusCode, 404)
        let (_, bridgeStillLive) = try await client.data(for: URLRequest(url: upstream, cachePolicy: .reloadIgnoringLocalCacheData))
        XCTAssertEqual((bridgeStillLive as? HTTPURLResponse)?.statusCode, 200)
    }

    @MainActor
    func testNetworkLibraryBridgeAdmitsFourReadersAndRecoversAfterRejection() async throws {
        let reader = ProxyBridgeFixture(byteCount: 64, initiallyHeld: true)
        let bridge = WebDAVPlaybackSession(reader: reader)
        defer { bridge.stop() }
        let url = try await bridge.start()
        // Separate sessions avoid CFNetwork queuing the fifth request itself.
        let clients = (0..<5).map { _ in URLSession(configuration: .ephemeral) }
        defer { clients.forEach { $0.invalidateAndCancel() } }
        var requests = [URLRequest]()
        for index in 0..<5 {
            var request = URLRequest(url: url, timeoutInterval: 5)
            request.setValue("bytes=\(index)-\(index)", forHTTPHeaderField: "Range")
            requests.append(request)
        }
        let active = (0..<4).map { index in Task { try await clients[index].data(for: requests[index]) } }
        defer { active.forEach { $0.cancel() } }
        for _ in 0..<200 {
            if await reader.activeCount == 4 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let admitted = await reader.activeCount
        XCTAssertEqual(admitted, 4)
        let (body, rejected) = try await clients[4].data(for: requests[4])
        XCTAssertTrue(body.isEmpty)
        XCTAssertEqual((rejected as? HTTPURLResponse)?.statusCode, 503)
        await reader.release()
        for (index, task) in active.enumerated() {
            let (bytes, response) = try await task.value
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 206)
            XCTAssertEqual(bytes, ProxyBridgeFixture.bytes(offset: Int64(index), count: 1))
        }
        let (bytes, recovered) = try await clients[4].data(for: requests[4])
        XCTAssertEqual((recovered as? HTTPURLResponse)?.statusCode, 206)
        XCTAssertEqual(bytes, ProxyBridgeFixture.bytes(offset: 4, count: 1))
    }

    @MainActor
    func testOriginalProxyLargeSuffixContinuesAcrossFiniteWindows() async throws {
        let window = Int(MediaRangePolicy.upstreamWindowBytes)
        let payload = Data(repeating: 0x43, count: window + 32)
        let server = try PlaybackRangeTestServer(payload: payload)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = try await AuthenticatedMediaStreamProxy.shared.registerOriginalStream(
            upstreamURL: XCTUnwrap(server.url), filename: "fixture.mkv", allowsSelfSignedCertificates: false)
        defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
        let client = URLSession(configuration: .ephemeral)
        defer { client.invalidateAndCancel() }
        var request = URLRequest(url: proxy)
        request.timeoutInterval = 10
        request.setValue("bytes=-\(window + 16)", forHTTPHeaderField: "Range")
        let (data, response) = try await client.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 206)
        XCTAssertEqual(response.expectedContentLength, Int64(window + 16))
        XCTAssertEqual(data, payload.subdata(in: 16..<payload.count))
        XCTAssertEqual(server.requestCount, 3)
        let headers = server.receivedRequests.map { $0.lowercased() }
        XCTAssertTrue(headers[1].contains("range: bytes=16-\(window + 15)\r\n"))
        XCTAssertTrue(headers[2].contains("range: bytes=\(window + 16)-\(window + 31)\r\n"))
    }

    @MainActor
    func testOriginalProxyProvidesContinuousLengthAcrossWindowsAndBackwardSeek() async throws {
        let window = Int(MediaRangePolicy.upstreamWindowBytes)
        var payload = Data(repeating: 0x61, count: window)
        payload.append(Data(repeating: 0x7b, count: 16))
        let server = try PlaybackRangeTestServer(payload: payload)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = try await AuthenticatedMediaStreamProxy.shared.registerOriginalStream(
            upstreamURL: XCTUnwrap(server.url), filename: "fixture.mkv", allowsSelfSignedCertificates: false)
        defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
        let client = URLSession(configuration: .ephemeral)
        defer { client.invalidateAndCancel() }
        for (range, expected) in [("bytes=0-", payload), ("bytes=4-7", Data(payload[4...7]))] {
            var request = URLRequest(url: proxy)
            request.timeoutInterval = 10
            request.setValue(range, forHTTPHeaderField: "Range")
            let (data, response) = try await client.data(for: request)
            let http = try XCTUnwrap(response as? HTTPURLResponse)
            XCTAssertEqual(http.statusCode, 206)
            XCTAssertEqual(response.expectedContentLength, Int64(expected.count))
            XCTAssertNil(http.value(forHTTPHeaderField: "Transfer-Encoding"))
            XCTAssertEqual(data, expected)
        }
        let requests = server.receivedRequests.map { $0.lowercased() }
        XCTAssertEqual(requests.count, 3)
        XCTAssertTrue(requests[0].contains("range: bytes=0-\(window - 1)"))
        XCTAssertTrue(requests[1].contains("range: bytes=\(window)-\(window + 15)"))
        XCTAssertTrue(requests[2].contains("range: bytes=4-7"))
    }

    @MainActor
    func testPacedOriginalProxyQualifiesSupplyAcrossFiniteRangeBoundary() async throws {
        let window = Int(MediaRangePolicy.upstreamWindowBytes)
        // At 64KiB / 5ms, 1.5 windows finish in 3.84s and cannot contain
        // two 2s measurement windows on a fast host. Keep the first rollover
        // before 4s, but provide enough total body time for qualification.
        let payload = Data(repeating: 0x61, count: window * 2)
        let server = try PlaybackRangeTestServer(payload: payload,
            pacedBodyChunkBytes: 64 * 1024, pacedBodyDelay: 0.005)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let trace = "body-boundary-" + UUID().uuidString
        let proxy = try await AuthenticatedMediaStreamProxy.shared.registerOriginalStream(
            upstreamURL: XCTUnwrap(server.url), filename: "fixture.mkv",
            allowsSelfSignedCertificates: false, playbackTraceID: trace)
        defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
        let client = URLSession(configuration: .ephemeral)
        defer { client.invalidateAndCancel() }
        var request = URLRequest(url: proxy)
        request.setValue("bytes=0-", forHTTPHeaderField: "Range")
        request.timeoutInterval = 15
        let (data, response) = try await client.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 206)
        XCTAssertEqual(data, payload)
        XCTAssertEqual(server.receivedRequests.count, 2)
        XCTAssertTrue(server.receivedRequests[0].contains("bytes=0-\(window - 1)"))
        XCTAssertTrue(server.receivedRequests[1].contains("bytes=\(window)-\(payload.count - 1)"))
        try await Task.sleep(nanoseconds: 100_000_000)
        let events = DiagnosticLogStore.shared.entries.filter { $0.detail.contains("playbackTraceID=\(trace)") }
        let issued = try XCTUnwrap(events.first { $0.detail.contains("stage=upstreamRequestIssued") })
        let rollover = try XCTUnwrap(events.first { $0.detail.contains("stage=continuationResponse") })
        XCTAssertLessThan(rollover.date.timeIntervalSince(issued.date), 4,
            "Fixture must finish the first Range before two full body windows fit inside it")
        let windows = events.filter {
            $0.detail.contains("playbackTraceID=\(trace)")
                && $0.detail.contains("measurementBoundary=receivedBodyWindow")
        }
        XCTAssertGreaterThanOrEqual(windows.count, 2)
        XCTAssertTrue(windows.contains { $0.detail.contains("recordedForAdaptiveEstimate=true") },
            "Two stable body windows must survive a valid finite Range rollover")
    }

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

    func testSeekEvidenceDistinguishesAdvertisedVODFromDownloadedRanges() {
        let fields = PlaybackSeekRangeDiagnostics.fields(target: 7_451, current: 12,
            loaded: [(8, 20)], seekable: [(0, 13_698)])
        XCTAssertEqual(fields["targetAdvertisedSeekable"], "true")
        XCTAssertEqual(fields["targetAlreadyLoaded"], "false")
        XCTAssertEqual(fields["loadedFirstStart"], "8.0")
        XCTAssertEqual(fields["loadedLastEnd"], "28.0")
        XCTAssertEqual(PlaybackSeekRangeDiagnostics.fields(target: 28, current: 8,
            loaded: [(8, 20)], seekable: [])["targetAlreadyLoaded"], "false")
        XCTAssertEqual(PlaybackSeekRangeDiagnostics.fields(target: 8, current: 8,
            loaded: [(8, 20)], seekable: [])["targetAlreadyLoaded"], "true")
    }

    func testSeekEvidenceRejectsUnknownOverflowAndDisjointRanges() {
        let fields = PlaybackSeekRangeDiagnostics.fields(target: .nan, current: .infinity,
            loaded: [(.nan, 10), (0, .infinity), (3, -1), (4, 0),
                     (.greatestFiniteMagnitude, .greatestFiniteMagnitude)], seekable: [])
        XCTAssertEqual(fields["validLoadedRangeCount"], "0")
        XCTAssertEqual(fields["seekTargetSeconds"], "unknown")
        XCTAssertEqual(fields["engineCurrentSeconds"], "unknown")
        XCTAssertEqual(fields["targetAlreadyLoaded"], "false")
        let gap = PlaybackSeekRangeDiagnostics.fields(target: 20, current: 0,
            loaded: [(100, 5), (0, 10)], seekable: [(0, 200)])
        XCTAssertEqual(gap["targetAlreadyLoaded"], "false", "An overall min/max span must not fill holes")
        XCTAssertEqual(gap["loadedFirstStart"], "0.0")
        XCTAssertEqual(gap["loadedLastEnd"], "105.0")
        let preroll = PlaybackSeekRangeDiagnostics.fields(target: 0, current: 0,
            loaded: [(-1, 3)], seekable: [(-1, 3)])
        XCTAssertEqual(preroll["targetAlreadyLoaded"], "true", "Valid negative preroll starts still cover media zero")
        XCTAssertEqual(preroll["loadedFirstStart"], "-1.0")
    }

    func testHLSStructuralEvidenceNeverCopiesResourceNamesOrCredentials() {
        XCTAssertEqual(PlaybackHLSRequestDiagnostics.segmentOrdinal(
            URL(string: "https://example.com/private-library/17.ts?api_key=secret")!), 17)
        XCTAssertNil(PlaybackHLSRequestDiagnostics.segmentOrdinal(
            URL(string: "https://example.com/private-movie17.mp4?api_key=secret")!))
        XCTAssertNil(PlaybackHLSRequestDiagnostics.segmentOrdinal(URL(string: "https://example.com/17.m3u8")!))
        let fields = PlaybackHLSRequestDiagnostics.playlistFields(
            "#EXTM3U\r\n#EXT-X-MEDIA-SEQUENCE:17\r\n#EXTINF:4.004,\r\n17.ts?api_key=secret\r\n#EXTINF:4.004,\r\nprivate-title.ts?token=secret\r\n#EXT-X-ENDLIST\r\n")
        XCTAssertEqual(fields["playlistMediaSequence"], "17")
        XCTAssertEqual(fields["playlistSegments"], "2")
        XCTAssertEqual(fields["playlistFirstSegmentOrdinal"], "17")
        XCTAssertEqual(fields["playlistEndlist"], "true")
        XCTAssertFalse(String(describing: fields).contains("secret"))
        XCTAssertFalse(String(describing: fields).contains("private"))
    }

    func testHLSManifestTimingEvidenceDoesNotInferMissingOrInvalidFirstDuration() {
        let valid = PlaybackHLSRequestDiagnostics.playlistFields(
            "#EXTM3U\r\n#EXT-X-TARGETDURATION:5\r\n#EXTINF:4.004,private title\r\n0.ts?token=secret\r\n#EXT-X-ENDLIST\r\n")
        XCTAssertEqual(valid["playlistTargetDurationSeconds"], "5")
        XCTAssertEqual(valid["playlistFirstSegmentDurationSeconds"], "4.004")
        XCTAssertFalse(String(describing: valid).contains("secret"))
        XCTAssertFalse(String(describing: valid).contains("private"))
        for value in ["", "NaN", "inf", "-1", "0", "secret"] {
            let fields = PlaybackHLSRequestDiagnostics.playlistFields(
                "#EXTM3U\n#EXTINF:\(value),\n0.ts\n#EXTINF:4.004,\n1.ts\n#EXT-X-ENDLIST\n")
            XCTAssertEqual(fields["playlistFirstSegmentDurationSeconds"], "unknown", value)
            XCTAssertEqual(fields["playlistTargetDurationSeconds"], "unknown")
        }
        for tag in ["#EXT-X-TARGETDURATION:NaN", "#EXT-X-TARGETDURATION:4.5",
                    "#EXT-X-TARGETDURATION:-1", "#EXT-X-TARGETDURATION:0",
                    "#EXT-X-TARGETDURATION:5\n#EXT-X-TARGETDURATION:5"] {
            let fields = PlaybackHLSRequestDiagnostics.playlistFields("#EXTM3U\n\(tag)\n")
            XCTAssertEqual(fields["playlistTargetDurationSeconds"], "unknown")
        }
        let master = PlaybackHLSRequestDiagnostics.playlistFields(
            "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000\nprivate.m3u8?token=secret\n")
        XCTAssertEqual(master["playlistTargetDurationSeconds"], "unknown")
        XCTAssertEqual(master["playlistFirstSegmentDurationSeconds"], "unknown")
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

    func testPinnedRoutePoolRestrictsOriginAndHasNoAmbientCredentials() throws {
        let first = PlaybackPinnedRouteTransport(upstreamURL: try XCTUnwrap(URL(string: "https://NAS.example:443/video?token=one")))
        let second = PlaybackPinnedRouteTransport(upstreamURL: try XCTUnwrap(URL(string: "https://nas.example/video?token=two")))
        defer { first.invalidate(); second.invalidate() }
        XCTAssertTrue(first.accepts(try XCTUnwrap(URL(string: "https://nas.example/another?token=one"))))
        for uri in ["http://nas.example/video", "https://other.example/video", "https://nas.example:5001/video", "file:///video"] {
            XCTAssertFalse(first.accepts(try XCTUnwrap(URL(string: uri))))
        }
        XCTAssertFalse(first.session === second.session, "Separate registrations must not share pinned TLS decisions")
        XCTAssertNil(first.session.configuration.httpCookieStorage)
        XCTAssertNil(first.session.configuration.urlCredentialStorage)
        XCTAssertNil(first.session.configuration.httpAdditionalHeaders)
    }

    @MainActor
    func testPinnedRouteReusesConnectionsAndRevocationLeavesPeerAlive() async throws {
        let server = try PlaybackRangeTestServer()
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = AuthenticatedMediaStreamProxy.shared
        let upstream = try XCTUnwrap(server.url)
        let first = try await proxy.registerOriginalStream(upstreamURL: upstream, filename: "first.mkv", allowsSelfSignedCertificates: true)
        let peer = try await proxy.registerOriginalStream(upstreamURL: upstream, filename: "peer.mkv", allowsSelfSignedCertificates: true)
        defer { proxy.unregister(first); proxy.unregister(peer) }
        let client = URLSession(configuration: .ephemeral)
        defer { client.invalidateAndCancel() }
        func read(_ url: URL) async throws -> Int? {
            var request = URLRequest(url: url)
            request.setValue("bytes=0-3", forHTTPHeaderField: "Range")
            let (data, response) = try await client.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 206 { XCTAssertEqual(data, Data("test".utf8)) }
            return (response as? HTTPURLResponse)?.statusCode
        }
        let one = try await read(first), two = try await read(first)
        XCTAssertEqual(one, 206); XCTAssertEqual(two, 206)
        XCTAssertEqual(server.connectionCount, 1)
        let peerBefore = try await read(peer)
        XCTAssertEqual(peerBefore, 206)
        XCTAssertEqual(server.connectionCount, 2, "Pinned transport is scoped to one registration")
        proxy.unregister(first)
        let revoked = try await read(first), peerAfter = try await read(peer)
        XCTAssertEqual(revoked, 404); XCTAssertEqual(peerAfter, 206)
        XCTAssertEqual(server.connectionCount, 2)
    }

    @MainActor
    func testPinnedRouteReaderResetDoesNotInvalidateReplacementTransport() async throws {
        let server = try PlaybackRangeTestServer(holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let trace = String(UUID().uuidString.prefix(8))
        let proxy = try await AuthenticatedMediaStreamProxy.shared.registerOriginalStream(
            upstreamURL: XCTUnwrap(server.url), filename: "fixture.mkv", allowsSelfSignedCertificates: true, playbackTraceID: trace)
        defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
        let abandoned = try PlaybackRawHTTPClient(url: proxy)
        defer { abandoned.close() }
        try await awaitProxyFixture { server.requestCount == 1 }
        try abandoned.reset()
        let replacement = try PlaybackRawHTTPClient(url: proxy)
        defer { replacement.close() }
        try await awaitProxyFixture { server.requestCount == 2 }
        server.releaseResponses()
        let response = try await replacement.response()
        XCTAssertTrue(response.contains("206 Partial Content") && response.hasSuffix("test"))
        try await awaitProxyFixture { self.proxyFixtureDetails(trace).contains { $0.contains("result=complete") } }
    }

    @MainActor
    func testCancelledProxyMetricsRetainSelectedTransportScope() async throws {
        for pinned in [false, true] {
            let server = try PlaybackRangeTestServer(holdsResponses: true)
            defer { server.stop() }
            await fulfillment(of: [server.ready], timeout: 3)
            let trace = String(UUID().uuidString.prefix(8))
            let proxy = try await AuthenticatedMediaStreamProxy.shared.registerOriginalStream(
                upstreamURL: XCTUnwrap(server.url), filename: "fixture.mkv",
                allowsSelfSignedCertificates: pinned, playbackTraceID: trace)
            defer { AuthenticatedMediaStreamProxy.shared.unregister(proxy) }
            let reader = try PlaybackRawHTTPClient(url: proxy)
            defer { reader.close() }
            try await awaitProxyFixture { server.requestCount == 1 }
            try reader.reset()
            try await awaitProxyFixture {
                self.proxyFixtureDetails(trace).contains {
                    $0.contains("stage=urlSessionTaskMetrics") && $0.contains("callbackAfterClientFinish=true")
                }
            }
            let metrics = proxyFixtureDetails(trace).filter { $0.contains("stage=urlSessionTaskMetrics") }
            XCTAssertFalse(metrics.isEmpty)
            XCTAssertTrue(metrics.allSatisfy {
                $0.contains("transportScope=\(pinned ? "pinnedRoute" : "systemShared")")
            }, "Late metrics must describe the selected transport after its session reference is released")
        }
    }

    @MainActor
    private func awaitProxyFixture(_ condition: () -> Bool) async throws {
        for _ in 0..<300 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for a controlled proxy fixture event")
        throw URLError(.timedOut)
    }

    @MainActor
    private func proxyFixtureDetails(_ trace: String) -> [String] {
        DiagnosticLogStore.shared.entries.filter {
            $0.detail.contains("playbackTraceID=\(trace)")
        }.map(\.detail)
    }

    @MainActor
    func testRangeFixtureAcceptsRequestWithWriteHalfClose() async throws {
        let server = try PlaybackRangeTestServer(holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let client = try PlaybackRawHTTPClient(url: XCTUnwrap(server.url))
        defer { client.close() }
        try client.writeHalfClose()
        try await awaitProxyFixture { server.requestCount == 1 }
        server.releaseResponses()
        let response = try await client.response()
        XCTAssertTrue(response.contains("206 Partial Content"))
        XCTAssertTrue(response.hasSuffix("\r\n\r\ntest"))
    }

    @MainActor
    func testRevokedProxyRouteStopsItsActiveTransferWithoutCancellingPeerRoute() async throws {
        let server = try PlaybackRangeTestServer(holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let revokedTrace = String(UUID().uuidString.prefix(8))
        let peerTrace = String(UUID().uuidString.prefix(8))
        let proxy = AuthenticatedMediaStreamProxy.shared
        let first = try await proxy.register(upstreamURL: XCTUnwrap(server.url),
            filename: "fixture.mp4", allowsSelfSignedCertificates: false, playbackTraceID: revokedTrace)
        let peer = try await proxy.register(upstreamURL: XCTUnwrap(server.url),
            filename: "fixture.mp4", allowsSelfSignedCertificates: false, playbackTraceID: peerTrace)
        defer { proxy.unregister(first); proxy.unregister(peer) }
        let firstClient = try PlaybackRawHTTPClient(url: first)
        let peerClient = try PlaybackRawHTTPClient(url: peer)
        defer { firstClient.close(); peerClient.close() }
        try await awaitProxyFixture { server.requestCount == 2 }
        var wrongPort = URLComponents(url: first, resolvingAgainstBaseURL: false)!
        wrongPort.port = first.port == 65_535 ? 1 : first.port! + 1
        proxy.unregister(try XCTUnwrap(wrongPort.url))
        // A subsequent request proves that the wrong-port operation was processed
        // without revoking the route or cancelling its two independent readers.
        let stillValid = try PlaybackRawHTTPClient(url: first)
        defer { stillValid.close() }
        try await awaitProxyFixture { server.requestCount == 3 }
        XCTAssertFalse(proxyFixtureDetails(revokedTrace).contains { $0.contains("stage=upstreamCancellationRequested") })
        proxy.unregister(first)
        proxy.unregister(first) // Duplicate cleanup must remain idempotent.
        try await awaitProxyFixture { self.proxyFixtureDetails(revokedTrace).filter {
            $0.contains("stage=upstreamCancellationRequested")
        }.count == 2 }
        XCTAssertFalse(proxyFixtureDetails(peerTrace).contains { $0.contains("stage=upstreamCancellationRequested") })
        let closed = try await firstClient.response()
        XCTAssertTrue(closed.isEmpty, "A released route must close its already accepted local reader")
        server.releaseResponses()
        let response = try await peerClient.response()
        XCTAssertTrue(response.contains("206 Partial Content") && response.hasSuffix("test"),
            "Cancelling one route must not invalidate the shared upstream session")
        let (_, missing) = try await URLSession.shared.data(from: first)
        XCTAssertEqual((missing as? HTTPURLResponse)?.statusCode, 404)
    }

    @MainActor
    func testProxyWriteHalfCloseStillDeliversFullDelayedResponse() async throws {
        let server = try PlaybackRangeTestServer(holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let trace = String(UUID().uuidString.prefix(8))
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(
            upstreamURL: XCTUnwrap(server.url), filename: "fixture.mp4",
            allowsSelfSignedCertificates: false, playbackTraceID: trace)
        let client = try PlaybackRawHTTPClient(url: proxy)
        defer { client.close() }
        try client.writeHalfClose()
        try await awaitProxyFixture {
            server.requestCount == 1 && self.proxyFixtureDetails(trace).contains {
                $0.contains("stage=clientReadEnded") && $0.contains("clientReadComplete=true")
            }
        }
        XCTAssertFalse(proxyFixtureDetails(trace).contains { $0.contains("stage=upstreamCancellationRequested") })
        server.releaseResponses()
        let response = try await client.response()
        XCTAssertTrue(response.contains("206 Partial Content"))
        XCTAssertTrue(response.hasSuffix("test"))
        try await awaitProxyFixture { self.proxyFixtureDetails(trace).contains { $0.contains("result=complete") } }
    }

    @MainActor
    func testProxyObservesResetBeforeDelayedUpstreamResponse() async throws {
        let server = try PlaybackRangeTestServer(holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let trace = String(UUID().uuidString.prefix(8))
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(
            upstreamURL: XCTUnwrap(server.url), filename: "fixture.mp4",
            allowsSelfSignedCertificates: false, playbackTraceID: trace)
        let client = try PlaybackRawHTTPClient(url: proxy)
        defer { client.close() }
        try await awaitProxyFixture { server.requestCount == 1 }
        try client.reset()
        try await awaitProxyFixture { self.proxyFixtureDetails(trace).contains {
            $0.contains("stage=clientReadEnded") && $0.contains("clientReadErrorKind=posix")
                && $0.contains("clientReadErrorCode=54")
        } }
        // No upstream headers have been released: this is read-side evidence,
        // not an error inferred later from attempting to write the response.
        XCTAssertFalse(proxyFixtureDetails(trace).contains { $0.contains("status=206") })
        server.releaseResponses()
        try await awaitProxyFixture { self.proxyFixtureDetails(trace).contains { $0.contains("stage=upstreamTaskCompleted") } }
    }

    @MainActor
    func testOverlappingIdenticalProxyRequestsRemainIndependentAfterHalfClose() async throws {
        let server = try PlaybackRangeTestServer(holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let trace = String(UUID().uuidString.prefix(8))
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(
            upstreamURL: XCTUnwrap(server.url), filename: "fixture.mp4",
            allowsSelfSignedCertificates: false, playbackTraceID: trace)
        let first = try PlaybackRawHTTPClient(url: proxy)
        let second = try PlaybackRawHTTPClient(url: proxy)
        defer { first.close(); second.close() }
        try await awaitProxyFixture { server.requestCount == 2 }
        try first.writeHalfClose()
        try await awaitProxyFixture { self.proxyFixtureDetails(trace).contains { $0.contains("stage=clientReadEnded") } }
        XCTAssertFalse(proxyFixtureDetails(trace).contains { $0.contains("stage=upstreamCancellationRequested") })
        server.releaseResponses()
        async let firstResponse = first.response()
        async let secondResponse = second.response()
        let responses = try await [firstResponse, secondResponse]
        XCTAssertTrue(responses.allSatisfy { $0.contains("206 Partial Content") && $0.hasSuffix("test") })
        XCTAssertEqual(server.requestCount, 2)
        try await awaitProxyFixture { self.proxyFixtureDetails(trace).filter { $0.contains("result=complete") }.count == 2 }
    }

    @MainActor
    private func firstRewrittenHLSChild(_ proxy: URL) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(from: proxy)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        return try XCTUnwrap(String(decoding: data, as: UTF8.self).components(separatedBy: "\n")
            .first(where: { $0.hasPrefix("http://") }).flatMap(URL.init(string:)))
    }

    @MainActor
    private func attachHLSFixtureDiagnostics(_ traces: [String]) {
        let details = traces.flatMap { proxyFixtureDetails($0) }.joined(separator: "\n")
        let attachment = XCTAttachment(string: details)
        attachment.name = "Controlled HLS child transfer events"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testHLSChildDelayedFirstSegmentKeepsThreeHalfClosedReadersAlive() async throws {
        let server = try PlaybackRangeTestServer(
            playlist: "#EXTM3U\n#EXTINF:4,\n0.ts\n#EXT-X-ENDLIST\n",
            segmentBody: "delayed-ts-body")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let trace = String(UUID().uuidString.prefix(8))
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(
            upstreamURL: XCTUnwrap(server.url), filename: "vod.m3u8",
            allowsSelfSignedCertificates: false, playbackTraceID: trace)
        defer {
            AuthenticatedMediaStreamProxy.shared.unregister(proxy)
            attachHLSFixtureDiagnostics([trace])
        }
        let child = try await firstRewrittenHLSChild(proxy)
        XCTAssertTrue(child.path.contains("/child/"))
        server.holdResponses()
        let first = try PlaybackRawHTTPClient(url: child, range: nil)
        defer { first.close() }
        try await awaitProxyFixture { server.requestCount == 2 }
        try first.writeHalfClose()
        let second = try PlaybackRawHTTPClient(url: child, range: nil)
        defer { second.close() }
        try await awaitProxyFixture { server.requestCount == 3 }
        try second.writeHalfClose()
        let third = try PlaybackRawHTTPClient(url: child, range: nil)
        defer { third.close() }
        try third.writeHalfClose()
        try await awaitProxyFixture {
            server.requestCount == 4 && self.proxyFixtureDetails(trace).filter {
                $0.contains("stage=clientReadEnded") && $0.contains("proxyKind=hlsChild")
                    && $0.contains("clientReadComplete=true")
            }.count == 3
        }
        let pending = proxyFixtureDetails(trace)
        XCTAssertFalse(pending.contains { $0.contains("stage=upstreamCancellationRequested") })
        XCTAssertFalse(pending.contains { $0.contains("proxyKind=hlsChild") && $0.contains("status=200") })
        // Delayed HTTP headers are released by the fixture, not a timing guess.
        // All three valid half-closed readers must still receive a full response.
        server.releaseResponses()
        async let firstResponse = first.response()
        async let secondResponse = second.response()
        async let thirdResponse = third.response()
        let responses = try await [firstResponse, secondResponse, thirdResponse]
        XCTAssertTrue(responses.allSatisfy {
            $0.hasPrefix("HTTP/1.1 200 ") && $0.hasSuffix("\r\n\r\ndelayed-ts-body")
        })
        let segmentRequests = server.receivedRequests.filter { $0.hasPrefix("GET /0.ts ") }
        XCTAssertEqual(segmentRequests.count, 3, "Current transfers are independent; this is not a coalescing test")
        XCTAssertTrue(segmentRequests.allSatisfy { !$0.lowercased().contains("\r\nrange:") })
        try await awaitProxyFixture { self.proxyFixtureDetails(trace).filter {
            $0.contains("proxyKind=hlsChild") && $0.contains("result=complete")
        }.count == 3 }
        let completed = proxyFixtureDetails(trace).filter {
            $0.contains("proxyKind=hlsChild") && $0.contains("result=complete")
        }
        XCTAssertTrue(completed.allSatisfy {
            $0.contains("playlistChildID=\(child.lastPathComponent)") && $0.contains("segmentOrdinal=0")
        })
    }

    @MainActor
    func testHLSChildResetDoesNotAbortReplacementReader() async throws {
        let server = try PlaybackRangeTestServer(
            playlist: "#EXTM3U\n#EXTINF:4,\n0.ts\n#EXT-X-ENDLIST\n",
            segmentBody: "replacement-ts-body")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let trace = String(UUID().uuidString.prefix(8))
        let proxy = try await AuthenticatedMediaStreamProxy.shared.register(
            upstreamURL: XCTUnwrap(server.url), filename: "vod.m3u8",
            allowsSelfSignedCertificates: false, playbackTraceID: trace)
        defer {
            AuthenticatedMediaStreamProxy.shared.unregister(proxy)
            attachHLSFixtureDiagnostics([trace])
        }
        let child = try await firstRewrittenHLSChild(proxy)
        server.holdResponses()
        let abandoned = try PlaybackRawHTTPClient(url: child, range: nil)
        defer { abandoned.close() }
        try await awaitProxyFixture { server.requestCount == 2 }
        try abandoned.reset()
        try await awaitProxyFixture { self.proxyFixtureDetails(trace).contains {
            $0.contains("stage=clientReadEnded") && $0.contains("clientReadErrorKind=posix")
                && $0.contains("clientReadErrorCode=54")
        } }
        try await awaitProxyFixture { self.proxyFixtureDetails(trace).contains {
            $0.contains("proxyKind=hlsChild") && $0.contains("stage=upstreamCancellationRequested")
        } }
        XCTAssertFalse(proxyFixtureDetails(trace).contains {
            $0.contains("proxyKind=hlsChild") && $0.contains("status=200")
        }, "A real reset must cancel the abandoned transfer before the held upstream headers arrive")
        let replacement = try PlaybackRawHTTPClient(url: child, range: nil)
        defer { replacement.close() }
        try await awaitProxyFixture { server.requestCount == 3 }
        server.releaseResponses()
        let response = try await replacement.response()
        XCTAssertTrue(response.hasPrefix("HTTP/1.1 200 ") && response.hasSuffix("\r\n\r\nreplacement-ts-body"))
        try await awaitProxyFixture { self.proxyFixtureDetails(trace).contains {
            $0.contains("proxyKind=hlsChild") && $0.contains("stage=upstreamCancellationRequested")
        } }
        try await awaitProxyFixture { self.proxyFixtureDetails(trace).contains {
            $0.contains("proxyKind=hlsChild") && $0.contains("result=complete")
        } }
        XCTAssertEqual(server.receivedRequests.filter { $0.hasPrefix("GET /0.ts ") }.count, 2)
    }

    @MainActor
    func testRevokingHLSRootCancelsPendingChildrenWithoutAffectingPeerRoute() async throws {
        let server = try PlaybackRangeTestServer(
            playlist: "#EXTM3U\n#EXTINF:4,\n0.ts\n#EXT-X-ENDLIST\n",
            segmentBody: "peer-ts-body")
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let proxy = AuthenticatedMediaStreamProxy.shared
        let revokedTrace = String(UUID().uuidString.prefix(8))
        let peerTrace = String(UUID().uuidString.prefix(8))
        let root = try await proxy.register(upstreamURL: XCTUnwrap(server.url),
            filename: "vod.m3u8", allowsSelfSignedCertificates: false, playbackTraceID: revokedTrace)
        let peer = try await proxy.register(upstreamURL: XCTUnwrap(server.url),
            filename: "vod.m3u8", allowsSelfSignedCertificates: false, playbackTraceID: peerTrace)
        defer {
            proxy.unregister(root); proxy.unregister(peer)
            attachHLSFixtureDiagnostics([revokedTrace, peerTrace])
        }
        let child = try await firstRewrittenHLSChild(root)
        let peerChild = try await firstRewrittenHLSChild(peer)
        XCTAssertNotEqual(child, peerChild, "Identical segment names must retain their route ownership")
        server.holdResponses()
        let first = try PlaybackRawHTTPClient(url: child, range: nil)
        let second = try PlaybackRawHTTPClient(url: child, range: nil)
        let remaining = try PlaybackRawHTTPClient(url: peerChild, range: nil)
        defer { first.close(); second.close(); remaining.close() }
        try await awaitProxyFixture { server.requestCount == 5 }
        proxy.unregister(root)
        proxy.unregister(root)
        try await awaitProxyFixture { self.proxyFixtureDetails(revokedTrace).filter {
            $0.contains("proxyKind=hlsChild") && $0.contains("stage=upstreamCancellationRequested")
        }.count == 2 }
        XCTAssertFalse(proxyFixtureDetails(peerTrace).contains { $0.contains("stage=upstreamCancellationRequested") })
        async let firstClosed = first.response()
        async let secondClosed = second.response()
        let closed = try await [firstClosed, secondClosed]
        XCTAssertTrue(closed.allSatisfy(\.isEmpty))
        server.releaseResponses()
        let response = try await remaining.response()
        XCTAssertTrue(response.hasPrefix("HTTP/1.1 200 ") && response.hasSuffix("\r\n\r\npeer-ts-body"))
        let (_, missing) = try await URLSession.shared.data(from: child)
        XCTAssertEqual((missing as? HTTPURLResponse)?.statusCode, 404)
        XCTAssertFalse(proxyFixtureDetails(peerTrace).contains { $0.contains("stage=upstreamCancellationRequested") })
    }

    @MainActor
    func testJellyfinTextConsumersShareOnePendingExtraction() async throws {
        let server = try PlaybackRangeTestServer(payload: Data("1\n00:00:01,000 --> 00:00:10,000\nshared cue\n\n".utf8), holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        var parts = try XCTUnwrap(URLComponents(url: XCTUnwrap(server.url), resolvingAgainstBaseURL: false))
        parts.queryItems = [URLQueryItem(name: "api_key", value: "test-account-a")]
        let url = try XCTUnwrap(parts.url)
        let screen = CJKSubtitleOverlayModel(), pip = CJKSubtitleOverlayModel()
        screen.update(time: 5); pip.update(time: 5)
        screen.setURL(url); pip.setURL(url)
        try await awaitProxyFixture { server.requestCount >= 1 }
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(server.requestCount, 1, "Fullscreen and PiP must not ask Jellyfin to extract the same subtitle twice")
        server.releaseResponses()
        try await awaitProxyFixture { screen.text != nil && pip.text != nil }
        XCTAssertEqual(screen.text, "shared cue")
        XCTAssertEqual(pip.text, "shared cue")
    }

    @MainActor
    func testCancellingOneJellyfinTextConsumerKeepsPeerLoadAlive() async throws {
        let server = try PlaybackRangeTestServer(payload: Data("1\n00:00:01,000 --> 00:00:10,000\nremaining cue\n\n".utf8), holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        var parts = try XCTUnwrap(URLComponents(url: XCTUnwrap(server.url), resolvingAgainstBaseURL: false))
        parts.queryItems = [URLQueryItem(name: "api_key", value: "test-account-b")]
        let url = try XCTUnwrap(parts.url)
        let screen = CJKSubtitleOverlayModel(), pip = CJKSubtitleOverlayModel()
        screen.update(time: 5); pip.update(time: 5)
        screen.setURL(url); pip.setURL(url)
        try await awaitProxyFixture { server.requestCount >= 1 }
        try await Task.sleep(nanoseconds: 100_000_000)
        screen.setURL(nil)
        XCTAssertEqual(server.requestCount, 1)
        server.releaseResponses()
        try await awaitProxyFixture { pip.text != nil }
        XCTAssertNil(screen.text)
        XCTAssertEqual(pip.text, "remaining cue")
    }

    @MainActor
    func testJellyfinTextLoadsNeverShareAcrossDifferentTokens() async throws {
        let server = try PlaybackRangeTestServer(payload: Data("1\n00:00:01,000 --> 00:00:10,000\nisolated cue\n\n".utf8), holdsResponses: true)
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let a = CJKSubtitleOverlayModel(), b = CJKSubtitleOverlayModel()
        for (token, model) in [("account-a", a), ("account-b", b)] {
            var parts = try XCTUnwrap(URLComponents(url: XCTUnwrap(server.url), resolvingAgainstBaseURL: false))
            parts.queryItems = [URLQueryItem(name: "api_key", value: token)]
            model.update(time: 5); model.setURL(try XCTUnwrap(parts.url))
        }
        try await awaitProxyFixture { server.requestCount == 2 }
        server.releaseResponses()
        try await awaitProxyFixture { a.text != nil && b.text != nil }
        XCTAssertEqual(a.text, "isolated cue")
        XCTAssertEqual(b.text, "isolated cue")
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
    func testRemoteJellyfinSRTLoadsInOverlayAndKeepsCurrentPlaybackPosition() async throws {
        let srt = "1\n00:37:28,760 --> 00:37:30,080\n我信任你\n{\\rEng}I trust you.\n\n"
        let server = try PlaybackRangeTestServer(payload: Data(srt.utf8))
        defer { server.stop() }
        await fulfillment(of: [server.ready], timeout: 3)
        let model = CJKSubtitleOverlayModel()
        model.update(time: 2249)
        model.setURL(try XCTUnwrap(server.url))
        XCTAssertTrue(model.isEnabled)
        for _ in 0..<100 where model.text == nil { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(model.text, "我信任你\nI trust you.")
        XCTAssertEqual(server.requestCount, 1, "The overlay loads and parses the remote SRT in one request")
        model.setURL(nil)
        XCTAssertNil(model.text)
    }

    @MainActor
    func testSubtitleStressUsesCachedCuesAndLastSelectionWins() async throws {
        let urls = (0..<2).map { _ in FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".srt") }
        defer { for url in urls { try? FileManager.default.removeItem(at: url) } }
        for (index, url) in urls.enumerated() {
            try "1\n00:00:01,000 --> 00:00:10,000\nTrack \(index)\n\n".write(to: url, atomically: true, encoding: .utf8)
        }
        let model = CJKSubtitleOverlayModel()
        model.update(time: 5)
        for (index, url) in urls.enumerated() {
            model.setURL(url)
            for _ in 0..<100 where model.text == nil { try await Task.sleep(nanoseconds: 10_000_000) }
            XCTAssertEqual(model.text, "Track \(index)")
            try FileManager.default.removeItem(at: url)
        }
        for index in 0..<50 {
            model.setURL(nil)
            XCTAssertNil(model.text)
            model.setURL(urls[index % 2])
            XCTAssertEqual(model.text, "Track \(index % 2)", "A previously loaded track must reappear without a download")
        }
        // An uncached load finishing after a cached choice must not clear it.
        model.setURL(FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        model.setURL(urls[1])
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.text, "Track 1")
    }

    @MainActor
    func testPausedBitmapSelectionClearsLoadedSidecarWithoutAnotherClockTick() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".srt")
        defer { try? FileManager.default.removeItem(at: url) }
        try "1\n00:00:01,000 --> 00:00:10,000\nOld text\n\n".write(to: url, atomically: true, encoding: .utf8)
        let controls = GreenfieldPlaybackControls()
        controls.isReady = true
        controls.externalSubtitleAction = { _ in }
        controls.subtitleAction = { controls.selectedSubtitleTrackID = $0 }
        controls.selectSourceSubtitle(5, externalURL: url)
        let overlay = CJKSubtitleOverlayModel()
        overlay.update(time: 5)
        func selectedURL() -> URL? {
            CJKSubtitleOverlayModel.resolvedURL(requestURL: url, requestDisabled: false,
                usesCommittedSelection: true, state: controls.runtimeState(orientationMode: .landscape))
        }
        overlay.setURL(selectedURL())
        for _ in 0..<100 where overlay.text == nil { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(overlay.text, "Old text")
        controls.selectSourceSubtitle(7, externalURL: nil)
        XCTAssertFalse(controls.isPlaying)
        overlay.setURL(selectedURL())
        XCTAssertNil(overlay.text)
        XCTAssertFalse(overlay.isEnabled)
        // A recreated full-screen view receives the original sidecar request.
        // The committed bitmap choice still has priority, even while paused.
        let restoredOverlay = CJKSubtitleOverlayModel()
        restoredOverlay.update(time: 5)
        restoredOverlay.setURL(selectedURL())
        XCTAssertFalse(restoredOverlay.isEnabled)
        controls.selectSourceSubtitle(nil, externalURL: nil)
        XCTAssertNil(selectedURL())
        controls.selectSourceSubtitle(5, externalURL: url)
        overlay.setURL(selectedURL())
        XCTAssertEqual(overlay.text, "Old text")
    }

    @MainActor
    func testAVSessionRetainsInitialSidecarWithoutNativeLegibleTracks() {
        let controls = GreenfieldPlaybackControls()
        let url = URL(fileURLWithPath: "/fixture/initial-av.srt")
        controls.beginSession(initialPosition: 5843, initialExternalSubtitleURL: url)
        controls.engineName = "AVPlayer"
        controls.sourceRuntimeTracks = (nil, 0, false)
        controls.isReady = true
        XCTAssertTrue(controls.subtitleTracks.isEmpty)
        let state = controls.runtimeState(orientationMode: .landscape)
        XCTAssertTrue(state.subtitleSelectionKnown)
        XCTAssertFalse(state.subtitlesDisabled)
        XCTAssertEqual(state.activeExternalSubtitleURL, url)
        XCTAssertEqual(CJKSubtitleOverlayModel.resolvedURL(requestURL: url, requestDisabled: false,
            usesCommittedSelection: true, state: state), url)
        controls.beginSession(initialPosition: 5843)
        controls.sourceRuntimeTracks = (nil, nil, true)
        let off = controls.runtimeState(orientationMode: .landscape)
        XCTAssertNil(off.activeExternalSubtitleURL)
        XCTAssertNil(CJKSubtitleOverlayModel.resolvedURL(requestURL: url, requestDisabled: false,
            usesCommittedSelection: true, state: off))
    }

    @MainActor
    func testUnconfirmedAndLegacySubtitleSelectionUseRequestUntilRendererCommits() {
        let controls = GreenfieldPlaybackControls()
        let url = URL(fileURLWithPath: "/fixture/original.srt")
        func selectedURL(committed: Bool, disabled: Bool = false) -> URL? {
            CJKSubtitleOverlayModel.resolvedURL(requestURL: url, requestDisabled: disabled,
                usesCommittedSelection: committed, state: controls.runtimeState(orientationMode: .landscape))
        }
        controls.automaticallySelectsEmbeddedSubtitles = true
        XCTAssertEqual(selectedURL(committed: true), url)
        controls.isReady = true
        XCTAssertEqual(selectedURL(committed: true), url)
        controls.subtitleAction = { controls.selectedSubtitleTrackID = $0 }
        controls.selectSourceSubtitle(7, externalURL: nil)
        XCTAssertNil(selectedURL(committed: true))
        XCTAssertEqual(selectedURL(committed: false), url)
        XCTAssertNil(selectedURL(committed: false, disabled: true))
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
        XCTAssertEqual(external.compactMap { $0 }, [sidecar], "An audio change must not reload the unchanged subtitle")
        controls.selectSourceSubtitle(nil, externalURL: nil)
        XCTAssertEqual(embedded, [-1])
        controls.selectSourceSubtitle(6, externalURL: nil) // An embedded image subtitle.
        XCTAssertEqual(embedded, [-1, 6])
    }

    @MainActor
    func testRepeatedEmbeddedSelectionDoesNotClearSubtitleAndNewSessionReappliesIt() {
        let controls = GreenfieldPlaybackControls()
        var selected: [Int32] = []
        controls.subtitleAction = { selected.append($0) }
        controls.selectSourceSubtitle(8, externalURL: nil)
        controls.selectSourceSubtitle(8, externalURL: nil)
        controls.selectSubtitle(PlaybackUITrack(id: 8, name: "PGS"))
        XCTAssertEqual(selected, [8])
        controls.selectSourceSubtitle(nil, externalURL: nil)
        controls.selectSourceSubtitle(nil, externalURL: nil)
        XCTAssertEqual(selected, [8, -1])
        controls.beginSession()
        controls.selectSourceSubtitle(nil, externalURL: nil)
        XCTAssertEqual(selected, [8, -1, -1])
    }

    @MainActor
    func testUnchangedAudioDoesNotDispatchAnotherDemuxSelection() {
        let controls = GreenfieldPlaybackControls()
        controls.selectedAudioTrackID = 1
        var selected: [Int32] = []
        controls.audioAction = { selected.append($0); controls.selectedAudioTrackID = $0 }
        controls.selectAudio(PlaybackUITrack(id: 1, name: "TrueHD"))
        controls.selectAudio(PlaybackUITrack(id: 2, name: "AC3"))
        controls.selectAudio(PlaybackUITrack(id: 2, name: "AC3"))
        XCTAssertEqual(selected, [2])
    }

    @MainActor
    func testPGSOriginalUsesTheActualSubtitleDecoderAndPreservesSelection() {
        XCTAssertTrue(GreenfieldPlaybackControls.canDecodeBitmapSubtitle("PGSSUB"))
        XCTAssertTrue(GreenfieldPlaybackControls.canDecodeBitmapSubtitle("hdmv_pgs_subtitle"))
        XCTAssertFalse(GreenfieldPlaybackControls.canDecodeBitmapSubtitle("unknown"))
        XCTAssertFalse(GreenfieldPlaybackControls.canDecodeBitmapSubtitle("truehd"))
        XCTAssertFalse(GreenfieldPlaybackControls.canDecodeBitmapSubtitle("xsub"))
        let request = MediaPlaybackRequest(url: URL(string: "http://127.0.0.1/movie.mkv")!,
            title: "PGS original", source: .jellyfin, contentKind: .video,
            sourceSubtitleTracks: [MediaPlaybackSourceTrack(id: 8, name: "PGS")],
            selectedSourceSubtitleTrackID: 8)
        let launch = request.greenfieldPlaybackLaunchRequest()
        XCTAssertEqual(launch.intent.preferredSubtitleTrackID, "8")
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
    func testVerifiedFileHLSRequestSendsEncoderDimensionsOnTheWire() throws {
        for (bitrate, width, height) in [(30_000_000, 3840, 2160), (20_000_000, 1920, 1080),
            (12_000_000, 1920, 1080), (8_000_000, 1280, 720), (4_000_000, 854, 480), (2_000_000, 854, 480)] {
            let request = JellyfinMatchedFileStream.playbackInfoRequest(for: fallbackMatch(),
                bitrate: bitrate, startSeconds: 0, preferredAudioStreamIndex: 1)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
            let profile = try XCTUnwrap(object["DeviceProfile"] as? [String: Any])
            let codecs = try XCTUnwrap(profile["CodecProfiles"] as? [[String: Any]],
                "Bitrate alone let the verified file route negotiate 1440p for the 1080p rung")
            let h264 = try XCTUnwrap(codecs.first { $0["Codec"] as? String == "h264" })
            XCTAssertEqual(h264["Type"] as? String, "Video")
            let conditions = try XCTUnwrap(h264["Conditions"] as? [[String: Any]])
            for (property, value) in [("Width", width), ("Height", height)] {
                let matches = conditions.filter { $0["Property"] as? String == property }
                XCTAssertEqual(matches.count, 1)
                XCTAssertEqual(matches.first?["Value"] as? String, String(value))
                XCTAssertEqual(matches.first?["Condition"] as? String, "LessThanEqual")
                XCTAssertEqual(matches.first?["IsRequired"] as? Bool, true)
            }
        }
    }

    @MainActor
    func testVerifiedFileHLSRequestKeepsSourceTracksAndAbsoluteStart() throws {
        var match = fallbackMatch()
        match.mediaStreams.append(.init(codec: "pgssub", index: 8, type: .subtitle))
        for subtitle: Int? in [nil, 8] {
            let request = JellyfinMatchedFileStream.playbackInfoRequest(for: match,
                bitrate: 20_000_000, startSeconds: 6800.25,
                preferredAudioStreamIndex: 1, preferredSubtitleStreamIndex: subtitle)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
            XCTAssertEqual(object["AudioStreamIndex"] as? Int, 1)
            XCTAssertEqual(object["SubtitleStreamIndex"] as? Int, subtitle ?? -1)
            XCTAssertEqual(object["StartTimeTicks"] as? Int, 68_002_500_000)
            XCTAssertEqual(object["MediaSourceId"] as? String, match.mediaSourceID)
            XCTAssertEqual(object["MaxStreamingBitrate"] as? Int, 20_000_000)
            let formats = request.deviceProfile?.transcodingProfiles
            XCTAssertEqual(formats?.count, 1)
            XCTAssertEqual(formats?.first?.container, "ts")
            XCTAssertEqual(formats?.first?.videoCodec, "h264")
            XCTAssertEqual(formats?.first?.segmentLength, 4)
            XCTAssertEqual(formats?.first?.minSegments, 1)
            XCTAssertEqual(request.deviceProfile?.subtitleProfiles?.first?.format, subtitle == nil ? nil : "pgssub")
        }
    }

    @MainActor
    func testVerifiedFileHLSRequestCannotChangeIntoOriginalOrStreamCopy() {
        let request = JellyfinMatchedFileStream.playbackInfoRequest(for: fallbackMatch(),
            bitrate: 4_000_000, startSeconds: nil)
        XCTAssertEqual(request.enableDirectPlay, false)
        XCTAssertEqual(request.enableDirectStream, false)
        XCTAssertEqual(request.allowAudioStreamCopy, false)
        XCTAssertEqual(request.allowVideoStreamCopy, false)
        XCTAssertEqual(request.enableTranscoding, true)
        XCTAssertNil(request.startTimeTicks)
        XCTAssertNil(request.audioStreamIndex)
        XCTAssertNil(request.subtitleStreamIndex)
    }

    @MainActor
    func testUnchangedEngineMetadataDoesNotInvalidatePlayerButChangesStillPublish() {
        let controls = GreenfieldPlaybackControls()
        var notifications = 0
        let subscription = controls.objectWillChange.sink { notifications += 1 }
        defer { subscription.cancel() }
        controls.updateTimelineMetadata(duration: 7_535, seekable: true)
        XCTAssertEqual(notifications, 2)
        for _ in 0..<100 {
            controls.updateTimelineMetadata(duration: 7_535, seekable: true)
        }
        controls.updateTimelineMetadata(duration: .nan)
        controls.updateTimelineMetadata(duration: .infinity)
        controls.updateTimelineMetadata(duration: 0)
        controls.updateTimelineMetadata(duration: -1)
        XCTAssertEqual(notifications, 2, "Polling and unknown duration must not redraw or erase valid metadata")
        controls.updateTimelineMetadata(duration: 8_000, seekable: false)
        XCTAssertEqual(notifications, 4)
        XCTAssertEqual(controls.durationSeconds, 8_000)
        XCTAssertFalse(controls.isSeekable)
        controls.updateClock(120.125)
        controls.updateClock(120.25)
        XCTAssertEqual(controls.currentSeconds, 120.25, "Playback clock keeps its original precision")
    }

    @MainActor
    func testNativeAudioSharedSeekKeepsPausedFrameAndWaitsForPreview() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 7_535
        controls.isReady = true
        controls.isSeekable = true
        controls.isPlaying = false
        controls.expectsPausedSeekPreview = true
        controls.currentSeconds = 90
        controls.readPlaybackClock = { 91.125 }
        var selections = 0
        var targets: [Double] = []
        controls.seekPlayback = { targets.append($0) }
        XCTAssertTrue(controls.selectAudioWithSharedSeek { selections += 1; return true })
        XCTAssertEqual(selections, 1)
        XCTAssertEqual(targets, [91.125])
        XCTAssertFalse(controls.isPlaying)
        XCTAssertTrue(controls.hasPendingSeek)
        controls.seekDidComplete(true)
        XCTAssertTrue(controls.hasPendingSeek, "Demux completion is not a paused target preview")
        controls.acceptPausedSeekPreview(91.125)
        XCTAssertFalse(controls.hasPendingSeek)
        XCTAssertFalse(controls.isPlaying)
        XCTAssertFalse(controls.hasAdvancedForSteadyBuffer(91.125, initialPosition: 0))
        XCTAssertTrue(controls.hasAdvancedForSteadyBuffer(91.2, initialPosition: 0))
    }

    @MainActor
    func testNativeAudioSharedSeekPreservesNewerPendingPosition() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 7_535
        controls.isReady = true
        controls.isSeekable = true
        controls.isPlaying = true
        controls.currentSeconds = 90
        controls.readPlaybackClock = { 90.25 }
        var targets: [Double] = []
        controls.seekPlayback = { targets.append($0) }
        controls.seekSeconds(3600.125)
        let previousGeneration = controls.seekGeneration
        XCTAssertTrue(controls.selectAudioWithSharedSeek { true })
        XCTAssertEqual(targets, [3600.125, 3600.125], "Changing audio must not undo a pending deep seek")
        XCTAssertEqual(controls.seekGeneration, previousGeneration + 1)
        XCTAssertTrue(controls.isPlaying)
    }

    @MainActor
    func testNativeAudioRejectedSelectionDoesNotStartSeekOrInvalidateTimeline() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 600
        controls.isReady = true
        controls.isSeekable = true
        controls.currentSeconds = 42
        controls.readPlaybackClock = { 42.5 }
        var seeks = 0
        var discontinuities = 0
        controls.seekPlayback = { _ in seeks += 1 }
        controls.onTimelineDiscontinuity = { discontinuities += 1 }
        let generation = controls.seekGeneration
        XCTAssertFalse(controls.selectAudioWithSharedSeek { false })
        XCTAssertEqual(seeks, 0)
        XCTAssertEqual(discontinuities, 0)
        XCTAssertEqual(controls.seekGeneration, generation)
        XCTAssertEqual(controls.currentSeconds, 42)
    }

    @MainActor
    func testNativeAudioSharedSeekChecksTransportBeforeMutatingTrack() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 600
        controls.isSeekable = true
        controls.readPlaybackClock = { 42 }
        var selections = 0
        let select = { selections += 1; return true }
        XCTAssertFalse(controls.selectAudioWithSharedSeek(select: select))
        controls.isReady = true
        XCTAssertFalse(controls.selectAudioWithSharedSeek(select: select))
        controls.seekPlayback = { _ in }
        controls.isSeekable = false
        XCTAssertFalse(controls.selectAudioWithSharedSeek(select: select))
        controls.isSeekable = true
        controls.durationSeconds = .infinity
        XCTAssertFalse(controls.selectAudioWithSharedSeek(select: select))
        controls.durationSeconds = 600
        controls.currentSeconds = .nan
        controls.readPlaybackClock = { .nan }
        XCTAssertFalse(controls.selectAudioWithSharedSeek(select: select))
        XCTAssertEqual(selections, 0)
    }

    @MainActor
    func testPausedRelativeJumpUsesEngineClockAndReturnsToSamePosition() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 7_535
        controls.isReady = true
        controls.isSeekable = true
        controls.isPlaying = false
        controls.currentSeconds = 91
        var engineClock = 91.125
        controls.readPlaybackClock = { engineClock }
        var targets: [Double] = []
        controls.seekPlayback = { targets.append($0) }
        controls.jump(by: -15)
        XCTAssertEqual(targets, [76.125], "A paused cue must be anchored to the actual engine frame")
        engineClock = 76.125
        controls.seekDidComplete(true)
        controls.updateClock(engineClock)
        controls.jump(by: 15)
        XCTAssertEqual(targets, [76.125, 91.125], "A completed back/forward pair must return to the same paused cue")
        XCTAssertFalse(controls.isPlaying)
    }

    @MainActor
    func testRapidRelativeJumpsExtendPendingIntentInsteadOfOldEngineClock() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 7_535
        controls.isReady = true
        controls.isSeekable = true
        controls.currentSeconds = 100
        controls.readPlaybackClock = { 100.25 }
        var targets: [Double] = []
        controls.seekPlayback = { targets.append($0) }
        controls.jump(by: 15)
        controls.updateClock(100.3)
        controls.jump(by: 15)
        controls.jump(by: -15)
        XCTAssertEqual(targets, [115.25, 130.25, 115.25])
        XCTAssertEqual(controls.currentSeconds, 115.25)
        XCTAssertTrue(controls.hasPendingSeek)
    }

    @MainActor
    func testRelativeJumpFallsBackFromInvalidClockAndKeepsSeekBounds() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 100
        controls.isReady = true
        controls.isSeekable = true
        controls.currentSeconds = 5
        controls.readPlaybackClock = { .nan }
        var targets: [Double] = []
        controls.seekPlayback = { targets.append($0) }
        controls.jump(by: -15)
        XCTAssertEqual(targets, [0])
        controls.seekDidComplete(true)
        controls.updateClock(90)
        controls.readPlaybackClock = { -1 }
        controls.jump(by: 15)
        XCTAssertEqual(targets, [0, 99.9])
    }

    @MainActor
    func testPausedSeekPublishesWaitingBoundaryWithoutTransportBuffering() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 100)
        controls.isReady = true
        controls.isSeekable = true
        controls.durationSeconds = 1_000
        controls.updateClock(100)
        controls.seekPlayback = { _ in }
        controls.jump(by: 15)
        XCTAssertEqual(controls.currentSeconds, 115, "Keep the user's requested timeline target")
        XCTAssertTrue(controls.hasPendingSeek)
        XCTAssertFalse(controls.isPlaying)
        XCTAssertFalse(controls.isBuffering, "Paused network seeks need not enter AV transport waiting")
        XCTAssertTrue(controls.showsLoadingIndicator, "The paused user still needs seek waiting feedback")
        controls.updateClock(100.5)
        XCTAssertEqual(controls.currentSeconds, 115, "Late old clock samples must not undo the request")
        var notifications = 0
        let subscription = controls.objectWillChange.sink { notifications += 1 }
        controls.seekDidComplete(true)
        subscription.cancel()
        XCTAssertGreaterThan(notifications, 0, "A paused completion must redraw even without another clock tick")
        XCTAssertFalse(controls.hasPendingSeek)
        XCTAssertFalse(controls.showsLoadingIndicator)
        XCTAssertFalse(controls.isPlaying)
        controls.seekSeconds(200)
        XCTAssertTrue(controls.showsLoadingIndicator)
        controls.beginSession(initialPosition: 40)
        XCTAssertFalse(controls.hasPendingSeek, "A replacement cannot inherit the outgoing seek spinner")
        XCTAssertFalse(controls.showsLoadingIndicator)
    }

    @MainActor
    func testFailedPausedSeekRestoresActualClockBeforeReleasingWaitingFeedback() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 100)
        controls.isReady = true
        controls.isSeekable = true
        controls.durationSeconds = 1_000
        controls.updateClock(100)
        controls.readPlaybackClock = { 100.25 }
        controls.seekPlayback = { _ in }
        controls.expectsPausedSeekPreview = true
        controls.jump(by: 15)
        XCTAssertTrue(controls.showsLoadingIndicator)
        controls.seekDidComplete(false)
        XCTAssertFalse(controls.hasPendingSeek)
        XCTAssertFalse(controls.showsLoadingIndicator)
        XCTAssertEqual(controls.currentSeconds, 100.25,
                       "A failed paused seek must not leave captions and chrome at the unapplied target")
        XCTAssertFalse(controls.isPlaying)
        controls.disconnect()
        XCTAssertFalse(controls.hasPendingSeek)
    }

    @MainActor
    func testPausedSeekWaitsForMatchingPreviewAndReleasesOnResumeOrReplacement() {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 100)
        controls.isReady = true
        controls.isSeekable = true
        controls.durationSeconds = 1_000
        controls.expectsPausedSeekPreview = true
        controls.seekPlayback = { _ in }
        controls.seekSeconds(115)
        controls.seekDidComplete(true)
        XCTAssertTrue(controls.hasPendingSeek, "Demux completion can precede the paused video preview")
        controls.acceptPausedSeekPreview(.nan)
        controls.acceptPausedSeekPreview(100)
        XCTAssertTrue(controls.showsLoadingIndicator, "An old frame cannot validate the requested caption")
        controls.seekSeconds(130)
        controls.acceptPausedSeekPreview(115)
        XCTAssertTrue(controls.hasPendingSeek, "A late first seek frame cannot finish the second seek")
        controls.acceptPausedSeekPreview(129.96)
        XCTAssertTrue(controls.hasPendingSeek, "A preview arriving first still needs engine completion")
        controls.seekDidComplete(true)
        XCTAssertFalse(controls.hasPendingSeek)
        XCTAssertFalse(controls.isPlaying)
        controls.seekSeconds(145)
        controls.seekDidComplete(true)
        controls.isPlaying = true
        XCTAssertFalse(controls.hasPendingSeek, "Resuming leaves the paused-preview wait")
        controls.isPlaying = false
        controls.seekSeconds(160)
        controls.beginSession(initialPosition: 40)
        XCTAssertFalse(controls.hasPendingSeek)
        XCTAssertFalse(controls.expectsPausedSeekPreview)
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
    func testSeekRecoveryWaitsForPlayingNonbufferingClockAdvancement() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 7_535
        controls.isReady = true
        controls.isSeekable = true
        controls.isPlaying = true
        controls.seekPlayback = { _ in }
        controls.seekSeconds(6_144)
        controls.seekDidComplete(true)
        controls.updateClock(6_144)
        XCTAssertTrue(controls.hasPendingSeekRecovery, "Seek callback at the target is not resumed playback")
        controls.isTransportBuffering = true
        controls.updateClock(6_144.5)
        XCTAssertTrue(controls.hasPendingSeekRecovery, "Buffered clock updates must not report recovery")
        controls.isTransportBuffering = false
        controls.isPlaying = false
        controls.updateClock(6_144.6)
        XCTAssertTrue(controls.hasPendingSeekRecovery, "Paused seeks cannot claim playback recovery")
        controls.isPlaying = true
        controls.updateClock(6_144.7)
        XCTAssertFalse(controls.hasPendingSeekRecovery)
        controls.seekSeconds(100)
        controls.seekDidComplete(false)
        controls.updateClock(100.5)
        XCTAssertTrue(controls.hasPendingSeekRecovery, "Failed engine completion cannot report successful recovery")
        controls.beginSession()
        XCTAssertFalse(controls.hasPendingSeekRecovery, "A replacement session must release recovery state")
    }

    @MainActor
    func testBackwardSeekRestoresSteadyBufferBeforeOriginalResumePosition() {
        let controls = GreenfieldPlaybackControls()
        controls.durationSeconds = 7_535
        controls.isReady = true
        controls.isSeekable = true
        controls.currentSeconds = 6_232
        controls.seekPlayback = { _ in }
        XCTAssertFalse(controls.hasAdvancedForSteadyBuffer(6_232, initialPosition: 6_232))
        XCTAssertTrue(controls.hasAdvancedForSteadyBuffer(6_233, initialPosition: 6_232))
        controls.seekSeconds(6_144)
        XCTAssertFalse(controls.hasAdvancedForSteadyBuffer(6_233, initialPosition: 6_232),
                       "Old callbacks while seeking cannot restore the steady buffer")
        controls.seekDidComplete(true)
        XCTAssertFalse(controls.hasAdvancedForSteadyBuffer(6_144, initialPosition: 6_232))
        XCTAssertTrue(controls.hasAdvancedForSteadyBuffer(6_144.1, initialPosition: 6_232),
                      "Backward seek must not wait until playback passes 6,232 again")
        controls.seekSeconds(6_400)
        controls.seekDidComplete(true)
        XCTAssertFalse(controls.hasAdvancedForSteadyBuffer(6_144.2, initialPosition: 6_232))
        XCTAssertTrue(controls.hasAdvancedForSteadyBuffer(6_400.1, initialPosition: 6_232))
        controls.readPlaybackClock = { 6_400.2 }
        controls.seekSeconds(7_000)
        controls.seekDidComplete(false)
        XCTAssertTrue(controls.hasAdvancedForSteadyBuffer(6_400.3, initialPosition: 6_232))
        controls.beginSession()
        XCTAssertFalse(controls.hasAdvancedForSteadyBuffer(.nan, initialPosition: 100))
        XCTAssertTrue(controls.hasAdvancedForSteadyBuffer(100.1, initialPosition: 100))
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
    func testPausedPGSReturnRestoresDisplayedCueAfterAnotherLanguageSelection() throws {
        let track = try makePausedPGSFixture()
        let part = try pausedPGSPart(start: 85, end: 89)
        track.subtitle?.outputRenderQueue.push(SubtitleFrame(part: part, timebase: .defaultValue))
        let model = SubtitleModel()
        model.selectedSubtitleInfo = track
        _ = model.subtitle(currentTime: 86.623)
        XCTAssertTrue(model.parts.first === part)
        model.rememberPausedImageSubtitle(currentTime: 86.623, token: "plan:4")
        model.selectedSubtitleInfo = ResetSubtitleProbe()
        XCTAssertTrue(model.parts.isEmpty, "The previous language must disappear before a new track is shown")
        XCTAssertTrue(track.restorePausedImageSubtitle(at: 86.623, token: "plan:4"))
        model.selectedSubtitleInfo = track
        _ = model.subtitle(currentTime: 86.623)
        XCTAssertTrue(model.parts.first === part, "A popped display set can be restored without rereading the media")
        XCTAssertEqual(track.subtitle?.frameCount, 0)
    }

    @MainActor
    func testPausedPGSExternalOverlayReturnCapturesBeforeProviderIsCleared() throws {
        let track = try makePausedPGSFixture()
        track.delay = 0.25
        let part = try pausedPGSPart(start: 85, end: 89)
        track.subtitle?.outputRenderQueue.push(SubtitleFrame(part: part, timebase: .defaultValue))
        let model = SubtitleModel()
        model.subtitleDelay = 0.5
        model.selectedSubtitleInfo = track
        let currentTime = 87.373
        _ = model.subtitle(currentTime: currentTime)
        XCTAssertTrue(model.parts.first === part)
        model.rememberPausedImageSubtitle(currentTime: currentTime, token: "plan:4")
        // External ASS and subtitle-off both clear the engine provider.
        model.selectedSubtitleInfo = nil
        XCTAssertTrue(model.parts.isEmpty)
        model.rememberPausedImageSubtitle(currentTime: currentTime, token: "plan:4")
        XCTAssertTrue(track.restorePausedImageSubtitle(at: 86.623, token: "plan:4"))
        model.selectedSubtitleInfo = track
        _ = model.subtitle(currentTime: currentTime)
        XCTAssertTrue(model.parts.first === part)
        XCTAssertEqual(track.subtitle?.frameCount, 0)
        XCTAssertFalse(track.restorePausedImageSubtitle(at: 86.623, token: "plan:5"))
    }

    @MainActor
    func testPausedPGSReplayCannotCarryInfiniteCueToAnotherPosition() throws {
        let track = try makePausedPGSFixture()
        let part = try pausedPGSPart(start: 85, end: .infinity)
        track.rememberPausedImageSubtitle(part, at: 86.623, token: "plan:4")
        XCTAssertTrue(track.restorePausedImageSubtitle(at: 86.623, token: "plan:4"))
        XCTAssertTrue(track.search(for: 86.623).first === part)
        XCTAssertTrue(track.search(for: 86.624).isEmpty)
        XCTAssertFalse(track.restorePausedImageSubtitle(at: 86.623, token: "plan:4"),
                       "Playback advancement must also release the retained bitmap")
    }

    @MainActor
    func testPausedPGSReplayRejectsNewPlanSeekAndDifferentTrack() throws {
        let track = try makePausedPGSFixture()
        let part = try pausedPGSPart(start: 85, end: 89)
        for token in ["next-plan:4", "plan:5"] {
            track.rememberPausedImageSubtitle(part, at: 86.623, token: "plan:4")
            XCTAssertFalse(track.restorePausedImageSubtitle(at: 86.623, token: token))
            XCTAssertTrue(track.search(for: 86.623).isEmpty)
        }
        track.rememberPausedImageSubtitle(part, at: 86.623, token: "plan:4")
        let other = try makePausedPGSFixture()
        XCTAssertFalse(other.restorePausedImageSubtitle(at: 86.623, token: "plan:4"))
        XCTAssertTrue(other.search(for: 86.623).isEmpty)
    }

    @MainActor
    func testPausedPGSReplayRejectsOutOfCueTextAndChangedDisplayEnd() throws {
        let track = try makePausedPGSFixture()
        let valid = try pausedPGSPart(start: 85, end: 89)
        let expired = try pausedPGSPart(start: 80, end: 84)
        let future = try pausedPGSPart(start: 87, end: 89)
        let text = SubtitlePart(85, 89, "ASS cue")
        for invalid in [expired, future, text] {
            track.rememberPausedImageSubtitle(valid, at: 86.623, token: "plan:4")
            track.rememberPausedImageSubtitle(invalid, at: 86.623, token: "plan:4")
            XCTAssertFalse(track.restorePausedImageSubtitle(at: 86.623, token: "plan:4"))
        }
        track.rememberPausedImageSubtitle(valid, at: 86.623, token: "plan:4")
        valid.end = 86
        XCTAssertFalse(track.restorePausedImageSubtitle(at: 86.623, token: "plan:4"),
                       "A decoder's later clear/end must supersede the retained image")
        track.rememberPausedImageSubtitle(expired, at: .nan, token: "plan:4")
        XCTAssertFalse(track.restorePausedImageSubtitle(at: .nan, token: "plan:4"))
    }

    @MainActor
    func testDecodedPGSClearSetSupersedesRestoredBitmapInSubtitleModel() throws {
        let track = try makePausedPGSFixture()
        let part = try pausedPGSPart(start: 85, end: .infinity)
        track.rememberPausedImageSubtitle(part, at: 86.623, token: "plan:4")
        XCTAssertTrue(track.restorePausedImageSubtitle(at: 86.623, token: "plan:4"))
        let model = SubtitleModel()
        model.selectedSubtitleInfo = track
        _ = model.subtitle(currentTime: 86.623)
        XCTAssertNotNil(model.parts.first?.image)
        let clear = SubtitlePart(86, .infinity, attributedString: nil)
        track.subtitle?.outputRenderQueue.push(SubtitleFrame(part: clear, timebase: .defaultValue))
        _ = model.subtitle(currentTime: 86.623)
        XCTAssertNil(model.parts.first?.image)
        XCTAssertFalse(track.restorePausedImageSubtitle(at: 86.623, token: "plan:4"))
    }

    func testBitmapSubtitleCompositionKeepsCompactRowsAndTransparentGaps() throws {
        func block(_ color: CGColor) throws -> CGImage {
            let context = try XCTUnwrap(CGContext(data: nil, width: 4, height: 4,
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(color)
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            return try XCTUnwrap(context.makeImage())
        }
        let red = try block(UIColor.red.cgColor)
        let green = try block(UIColor.green.cgColor)
        let combined = try XCTUnwrap(CGImage.combine(images: [
            (CGRect(x: 0, y: 0, width: 4, height: 4), red),
            (CGRect(x: 316, y: 56, width: 4, height: 4), green)
        ]))
        XCTAssertEqual(combined.width, 320)
        XCTAssertEqual(combined.height, 60)
        XCTAssertLessThanOrEqual(combined.bytesPerRow, 320 * 4 + 64,
            "Combining subtitle rectangles must not retain an oversized pixel buffer")
        let bytes = try XCTUnwrap(combined.dataProvider?.data) as Data
        XCTAssertEqual(bytes[30 * combined.bytesPerRow + 160 * 4 + 3], 0,
            "The space between subtitle rectangles must remain transparent")

        // Compare rendered pixels against the former lossless PNG path, also
        // checking orientation, colour and alpha.
        let direct = UIImage(cgImage: combined)
        let png = try XCTUnwrap(UIImage(data: try XCTUnwrap(direct.pngData())))
        func renderedPixels(_ image: UIImage) throws -> Data {
            let context = try XCTUnwrap(CGContext(data: nil, width: 320, height: 60,
                bitsPerComponent: 8, bytesPerRow: 320 * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(try XCTUnwrap(image.cgImage), in: CGRect(x: 0, y: 0, width: 320, height: 60))
            return Data(bytes: try XCTUnwrap(context.data), count: 320 * 4 * 60)
        }
        XCTAssertEqual(try renderedPixels(direct), try renderedPixels(png))
        XCTAssertEqual(direct.size, png.size)
        XCTAssertEqual(direct.imageOrientation, png.imageOrientation)
    }

    @MainActor
    func testSeekDoesNotCarryAnInfiniteBitmapToEitherSideOfTheTimeline() throws {
        for target in [7533.0, 0.0] {
            let track = try makePausedPGSFixture()
            let old = try pausedPGSPart(start: 0, end: .infinity)
            track.subtitle?.outputRenderQueue.push(SubtitleFrame(part: old, timebase: .defaultValue))
            let model = SubtitleModel()
            model.selectedSubtitleInfo = track
            _ = model.subtitle(currentTime: 80)
            XCTAssertTrue(model.parts.first === old)
            let enabledBeforeSeek = track.isEnabled
            model.beginSeek()
            XCTAssertTrue(model.parts.isEmpty)
            _ = model.subtitle(currentTime: 80.1) // A late callback from the old clock.
            XCTAssertTrue(model.parts.isEmpty)
            model.endSeek()
            _ = model.subtitle(currentTime: target)
            XCTAssertTrue(model.parts.isEmpty,
                "Until the target display set arrives, show no caption instead of the old infinite cue")
            XCTAssertEqual(model.selectedSubtitleInfo?.subtitleID, track.subtitleID)
            XCTAssertEqual(track.isEnabled, enabledBeforeSeek)
        }
    }

    @MainActor
    func testSeekSuspendsSubtitleQueueConsumptionUntilEngineCompletion() throws {
        let track = try makePausedPGSFixture()
        let model = SubtitleModel()
        model.selectedSubtitleInfo = track
        model.beginSeek()
        let target = try pausedPGSPart(start: 7530, end: 7538)
        track.subtitle?.outputRenderQueue.push(SubtitleFrame(part: target, timebase: .defaultValue))
        _ = model.subtitle(currentTime: 7533)
        XCTAssertTrue(model.parts.isEmpty)
        XCTAssertEqual(track.subtitle?.frameCount, 1)
        model.endSeek()
        _ = model.subtitle(currentTime: 7533)
        XCTAssertTrue(model.parts.first === target)
        XCTAssertEqual(track.subtitle?.frameCount, 0)
    }

    @MainActor
    func testSeekInvalidatesThePausedBitmapReplayEvenAtTheOriginalPosition() throws {
        let track = try makePausedPGSFixture()
        let cue = try pausedPGSPart(start: 80, end: .infinity)
        track.rememberPausedImageSubtitle(cue, at: 86, token: "plan:4")
        XCTAssertTrue(track.restorePausedImageSubtitle(at: 86, token: "plan:4"))
        track.invalidatePausedImageSubtitle()
        XCTAssertFalse(track.restorePausedImageSubtitle(at: 86, token: "plan:4"))
        XCTAssertTrue(track.search(for: 86).isEmpty)
    }

    @MainActor
    private func makePausedPGSFixture() throws -> FFmpegAssetTrack {
        var parameters = AVCodecParameters()
        parameters.codec_type = AVMEDIA_TYPE_SUBTITLE
        parameters.codec_id = AV_CODEC_ID_HDMV_PGS_SUBTITLE
        let track = try XCTUnwrap(FFmpegAssetTrack(codecpar: parameters))
        track.subtitle = SyncPlayerItemTrack<SubtitleFrame>(mediaType: .subtitle,
            frameCapacity: 8, options: KSOptions())
        return track
    }

    @MainActor
    private func pausedPGSPart(start: TimeInterval, end: TimeInterval) throws -> SubtitlePart {
        let part = SubtitlePart(start, end, attributedString: nil)
        part.image = try XCTUnwrap(UIImage(systemName: "star"))
        return part
    }

    func testAccurateSeekKeepsSubtitleSpanningThePausedTarget() {
        let frame = SubtitleFrame(part: SubtitlePart(81, 84, "Current cue"),
            timebase: Timebase(num: 1, den: 1_000))
        frame.timestamp = 81_000
        XCTAssertEqual(frame.duration, 0)
        XCTAssertFalse(frame.endsBeforeSeekTarget(82.542), "Packet start is not the subtitle display end")
        XCTAssertFalse(frame.endsBeforeSeekTarget(84), "The subtitle renderer includes the end boundary")
        XCTAssertTrue(frame.endsBeforeSeekTarget(84.001), "An expired cue must still be discarded")
    }

    func testAccurateSeekPreservesSubtitleClearAndFutureDisplaySets() {
        let clear = SubtitleFrame(part: SubtitlePart(80, .infinity, attributedString: nil),
            timebase: Timebase(num: 1, den: 1_000))
        clear.timestamp = 80_000
        XCTAssertFalse(clear.endsBeforeSeekTarget(82.542), "A clear display set must not leave an old bitmap behind")
        let future = SubtitleFrame(part: SubtitlePart(85, 87, "Next cue"),
            timebase: Timebase(num: 1, den: 1_000))
        future.timestamp = 85_000
        XCTAssertFalse(future.endsBeforeSeekTarget(82.542))
    }

    func testAccurateSeekRetainsAudioPacketEndFiltering() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let frame = AudioFrame(dataSize: 1, audioFormat: format)
        frame.timebase = Timebase(num: 1, den: 1_000)
        frame.timestamp = 81_000
        frame.duration = 400
        XCTAssertTrue(frame.endsBeforeSeekTarget(82.542))
        frame.duration = 2_000
        XCTAssertFalse(frame.endsBeforeSeekTarget(82.542))
        frame.timestamp = 0
        frame.duration = 0
        XCTAssertTrue(frame.endsBeforeSeekTarget(82.542))
    }

    @MainActor
    func testPausedSubtitleDecodeRefreshRejectsPlayingDisabledAndStaleTracks() {
        let controls = GreenfieldPlaybackControls()
        controls.planID = "current"
        controls.isPlaying = false
        XCTAssertTrue(controls.shouldRefreshPausedSubtitle(decodedTrackID: 7, selectedTrackID: 7, callbackPlanID: "current"))
        XCTAssertFalse(controls.shouldRefreshPausedSubtitle(decodedTrackID: 7, selectedTrackID: nil, callbackPlanID: "current"))
        XCTAssertFalse(controls.shouldRefreshPausedSubtitle(decodedTrackID: 7, selectedTrackID: 8, callbackPlanID: "current"))
        XCTAssertFalse(controls.shouldRefreshPausedSubtitle(decodedTrackID: 7, selectedTrackID: 7, callbackPlanID: "retired"))
        controls.isPlaying = true
        XCTAssertFalse(controls.shouldRefreshPausedSubtitle(decodedTrackID: 7, selectedTrackID: 7, callbackPlanID: "current"))
    }

    @MainActor
    private func drainPlayerTeardown() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { DispatchQueue.main.async { continuation.resume() } }
        }
    }

    @MainActor
    func testDismantleDoesNotPublishSubtitleWhileSwiftUIIsDestroyingItsGraph() async {
        let coordinator = KSVideoPlayer.Coordinator()
        let options = KSOptions()
        options.registerRemoteControll = false
        coordinator.playerLayer = KSPlayerLayer(url: URL(fileURLWithPath: "/unused-detach.mkv"),
                                                isAutoPlay: false, options: options)
        let subtitle = ResetSubtitleProbe()
        var disabled = 0
        subtitle.onDisable = { disabled += 1; XCTAssertNotNil(coordinator.playerLayer) }
        coordinator.subtitleModel.selectedSubtitleInfo = subtitle
        var dismantling = true
        var publications = 0
        let subscription = coordinator.subtitleModel.objectWillChange.sink {
            XCTAssertFalse(dismantling, "No synchronous publication may re-enter SwiftUI dismantle")
            publications += 1
        }
        defer { subscription.cancel() }
        KSVideoPlayer.dismantleUIView(UIView(), coordinator: coordinator)
        XCTAssertEqual(publications, 0)
        XCTAssertEqual(disabled, 0)
        dismantling = false
        await drainPlayerTeardown()
        XCTAssertNil(coordinator.playerLayer)
        XCTAssertNil(coordinator.subtitleModel.selectedSubtitleInfo)
        XCTAssertEqual(disabled, 1)
        XCTAssertGreaterThan(publications, 0)
    }

    @MainActor
    func testDeferredDetachCannotDestroyAViewRemountedOnTheSameCoordinator() async {
        let coordinator = KSVideoPlayer.Coordinator()
        let url = URL(fileURLWithPath: "/unused-remount.mkv")
        let options = KSOptions()
        options.registerRemoteControll = false
        let layer = KSPlayerLayer(url: url, isAutoPlay: false, options: options)
        coordinator.playerLayer = layer
        coordinator.subtitleModel.url = url
        await drainPlayerTeardown()
        let subtitle = ResetSubtitleProbe()
        var disabled = 0
        subtitle.onDisable = { disabled += 1 }
        coordinator.subtitleModel.selectedSubtitleInfo = subtitle
        KSVideoPlayer.dismantleUIView(UIView(), coordinator: coordinator)
        _ = coordinator.makeView(url: url, options: options)
        await drainPlayerTeardown()
        XCTAssertTrue(coordinator.playerLayer === layer)
        XCTAssertTrue(coordinator.subtitleModel.selectedSubtitleInfo === subtitle)
        XCTAssertEqual(disabled, 0)
        coordinator.resetPlayer()
        XCTAssertEqual(disabled, 1)
    }

    @MainActor
    func testRepeatedResetOfAlreadyEmptySubtitlesDoesNotPublish() {
        let coordinator = KSVideoPlayer.Coordinator()
        var publications = 0
        let subscription = coordinator.subtitleModel.objectWillChange.sink { publications += 1 }
        defer { subscription.cancel() }
        coordinator.resetPlayer()
        coordinator.resetPlayer()
        XCTAssertEqual(publications, 0)
    }

    @MainActor
    func testPlayerResetClearsSubtitleBeforeReleasingLayerAndIsIdempotent() {
        let coordinator = KSVideoPlayer.Coordinator()
        let options = KSOptions()
        options.registerRemoteControll = false
        coordinator.playerLayer = KSPlayerLayer(
            url: URL(fileURLWithPath: "/unused-reset-fixture.mkv"),
            isAutoPlay: false, options: options
        )
        let subtitle = ResetSubtitleProbe()
        var disableCount = 0
        subtitle.onDisable = {
            disableCount += 1
            XCTAssertNotNil(coordinator.playerLayer,
                            "Embedded subtitle must be detached while its stream owner is alive")
        }
        coordinator.subtitleModel.selectedSubtitleInfo = subtitle
        coordinator.resetPlayer()
        XCTAssertNil(coordinator.subtitleModel.selectedSubtitleInfo)
        XCTAssertNil(coordinator.playerLayer)
        XCTAssertEqual(disableCount, 1)
        coordinator.resetPlayer()
        XCTAssertEqual(disableCount, 1, "Repeated teardown must not touch a retired stream")
    }

    @MainActor
    func testPiPViewDetachKeepsDecoderSubtitleAndCallbacksUntilSessionStops() async {
        let coordinator = KSVideoPlayer.Coordinator()
        let options = KSOptions()
        options.registerRemoteControll = false
        let layer = KSPlayerLayer(url: URL(fileURLWithPath: "/unused-pip-fixture.mkv"),
                                  isAutoPlay: false, options: options)
        coordinator.playerLayer = layer
        let subtitle = ResetSubtitleProbe()
        var disabled = 0
        subtitle.onDisable = { disabled += 1 }
        coordinator.subtitleModel.selectedSubtitleInfo = subtitle
        var progress: Double?
        coordinator.onPlay = { seconds, _ in progress = seconds }
        coordinator.retainsPlayerForPictureInPicture = true
        KSVideoPlayer.dismantleUIView(UIView(), coordinator: coordinator)
        coordinator.onPlay?(120, 300)
        XCTAssertEqual(progress, 120)
        XCTAssertTrue(coordinator.playerLayer === layer)
        XCTAssertTrue(coordinator.subtitleModel.selectedSubtitleInfo === subtitle)
        XCTAssertEqual(disabled, 0)
        coordinator.retainsPlayerForPictureInPicture = false
        KSVideoPlayer.dismantleUIView(UIView(), coordinator: coordinator)
        await drainPlayerTeardown()
        XCTAssertNil(coordinator.playerLayer)
        XCTAssertNil(coordinator.onPlay)
        XCTAssertEqual(disabled, 1)
        coordinator.detachView()
        await drainPlayerTeardown()
        XCTAssertEqual(disabled, 1)
    }

    @MainActor
    func testExplicitStopReleasesDecoderEvenWhilePiPRetentionIsSet() {
        let coordinator = KSVideoPlayer.Coordinator()
        coordinator.retainsPlayerForPictureInPicture = true
        coordinator.onPlay = { _, _ in XCTFail("A stopped session must not publish playback") }
        coordinator.resetPlayer()
        XCTAssertNil(coordinator.onPlay)
        XCTAssertFalse(coordinator.retainsPlayerForPictureInPicture)
    }

    @MainActor
    func testSameURLPiPRemountDoesNotClearSelectedSubtitle() async {
        let coordinator = KSVideoPlayer.Coordinator()
        let url = URL(fileURLWithPath: "/unused-pip-remount-fixture.mkv")
        let options = KSOptions()
        options.registerRemoteControll = false
        let layer = KSPlayerLayer(url: url, isAutoPlay: false, options: options)
        coordinator.playerLayer = layer
        coordinator.subtitleModel.url = url
        func drainDeferredSubtitleUpdates() async {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.main.async { DispatchQueue.main.async { continuation.resume() } }
            }
        }
        await drainDeferredSubtitleUpdates()
        let subtitle = ResetSubtitleProbe()
        var disabled = 0
        subtitle.onDisable = { disabled += 1 }
        coordinator.subtitleModel.selectedSubtitleInfo = subtitle
        coordinator.retainsPlayerForPictureInPicture = true
        KSVideoPlayer.dismantleUIView(UIView(), coordinator: coordinator)
        _ = coordinator.makeView(url: url, options: options)
        await drainDeferredSubtitleUpdates()
        XCTAssertTrue(coordinator.playerLayer === layer)
        XCTAssertTrue(coordinator.subtitleModel.selectedSubtitleInfo === subtitle)
        XCTAssertEqual(disabled, 0, "Returning to the same PiP video must keep the user's subtitle")
        coordinator.resetPlayer()
        XCTAssertEqual(disabled, 1)
    }

    @MainActor
    func testPiPRestoreAndCloseHaveDifferentSessionLifetimes() throws {
        let controls = GreenfieldPlaybackControls()
        let delegate = GreenfieldPiPDelegate()
        delegate.controls = controls
        guard let pip = AVPictureInPictureController(playerLayer: AVPlayerLayer(player: AVPlayer())) else {
            throw XCTSkip("This simulator cannot create a PiP controller; real-device PiP remains required")
        }
        var retention: [Bool] = []
        var closed = 0
        controls.retainRendererForPictureInPicture = { retention.append($0) }
        controls.pipDidClose = { closed += 1 }
        controls.pipRestore = { completion in completion(true) }
        delegate.pictureInPictureControllerDidStartPictureInPicture(pip)
        XCTAssertTrue(controls.isPictureInPictureActive)
        var restored = false
        delegate.pictureInPictureController(pip,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: { restored = $0 })
        delegate.pictureInPictureControllerDidStopPictureInPicture(pip)
        XCTAssertTrue(restored)
        XCTAssertEqual(closed, 0, "Restore changes the presentation, not the media session")
        XCTAssertFalse(controls.isPictureInPictureActive)
        delegate.pictureInPictureControllerDidStartPictureInPicture(pip)
        delegate.pictureInPictureControllerDidStopPictureInPicture(pip)
        XCTAssertEqual(closed, 1, "System close must stop the retained playback")
        XCTAssertEqual(retention, [true, false, true, false])
    }

    @MainActor
    func testAudioConfigurationChangeRestartsOnlyPlayingOutput() async throws {
        let output = AudioEnginePlayer()
        output.prepare(audioFormat: try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)))
        output.play()
        output.flush() // Drain the control queue before simulating Core Audio's stop.
        XCTAssertTrue(output.engine.isRunning)
        output.engine.stop()
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: output.engine)
        output.flush()
        XCTAssertTrue(output.engine.isRunning, "A hardware format notification must recover the stopped output")
        output.pause()
        output.flush()
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: output.engine)
        output.flush()
        XCTAssertFalse(output.engine.isRunning, "A late notification must not undo user pause")
    }

    @MainActor
    func testAudioFormatStressReleasesOldNodesAndKeepsPause() throws {
        let output = AudioEnginePlayer()
        let mono = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let stereo = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        output.prepare(audioFormat: stereo)
        let nodeCount = output.engine.attachedNodes.count
        output.pause()
        for index in 0..<30 {
            output.prepare(audioFormat: index % 2 == 0 ? mono : stereo)
            XCTAssertEqual(output.engine.attachedNodes.count, nodeCount, "Track switches must detach the previous source node")
            XCTAssertFalse(output.engine.isRunning, "A queued format rebuild must preserve paused playback")
        }
    }

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
        XCTAssertTrue(controls.hasPendingSeek)
        XCTAssertTrue(controls.showsLoadingIndicator,
                      "Actual AV paused seeking needs feedback even without transport waiting")
        try await Task.sleep(nanoseconds: 300_000_000)
        for _ in 0..<100 where controls.hasPendingSeek {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(controls.hasPendingSeek)
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
        // Regression: S01 stalled at 247.710s while playback intent stayed true.
        // The replacement must decode at that frozen clock, without startup lead.
        var bufferingTarget: Double?
        let avBuffering = await GreenfieldAVPlayerWarmup.prepare(request,
            liveClock: { 1.5 }, isPlaying: { true }, isAdvancing: { false },
            report: { stage, metrics in
                if stage == "candidate_decoded" { bufferingTarget = metrics["target"].flatMap(Double.init) }
            })
        XCTAssertNotNil(avBuffering, "A buffering source must accept an aligned decoded replacement")
        XCTAssertEqual(bufferingTarget ?? -1, 1.5, accuracy: 0.001)
        XCTAssertEqual(avBuffering?.currentTime().seconds ?? -1, 1.5, accuracy: 0.1)
        XCTAssertGreaterThan(avBuffering?.rate ?? 0, 0, "Recovery must retain the user playback intent")
        avBuffering?.pause()
        avBuffering?.replaceCurrentItem(with: nil)
        // Automatic handoff holds the muted frame across asynchronous session
        // preparation; adopting that frame must still resume playback intent.
        let avHeld = await GreenfieldAVPlayerWarmup.prepare(request,
            liveClock: { 1.5 }, isPlaying: { true }, isAdvancing: { false }, holdForCommit: true)
        XCTAssertNotNil(avHeld)
        XCTAssertEqual(avHeld?.rate, 0)
        XCTAssertEqual(avHeld?.currentTime().seconds ?? -1, 1.5, accuracy: 0.1)
#if DEBUG
        // Attaching a fresh diagnostic output to an already decoded item can
        // flush its pipeline and report an artificial empty-buffer wait. The
        // output that verified the held frame must survive real model adoption.
        let heldOutput = try XCTUnwrap(avHeld?.currentItem?.outputs.compactMap {
            $0 as? AVPlayerItemVideoOutput
        }.first)
        let heldItem = avHeld?.currentItem
#endif
        controls.startsPaused = false
        model.start(native, preparedPlayer: avHeld, preparedSession: .init(recorder: prepared.recorder,
            coordinator: prepared.coordinator, result: nativeResult))
        for _ in 0..<300 where model.player.rate == 0 { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertGreaterThan(model.player.rate, 0, "Committed held candidate must resume the user's play intent")
        XCTAssertFalse(model.player.isMuted)
#if DEBUG
        XCTAssertTrue(model.player.currentItem === heldItem)
        let adoptedOutputs = model.player.currentItem?.outputs.compactMap { $0 as? AVPlayerItemVideoOutput } ?? []
        XCTAssertEqual(adoptedOutputs.count, 1)
        XCTAssertTrue(adoptedOutputs.first === heldOutput,
                      "Diagnostic adoption must reuse the output that decoded the held frame")
        let adoptionClock = model.player.currentTime().seconds
        var resumedFrame = false
        for _ in 0..<200 where !resumedFrame {
            var pts = CMTime.invalid
            let clock = model.player.currentTime()
            if heldOutput.copyPixelBuffer(forItemTime: clock, itemTimeForDisplay: &pts) != nil,
               pts.seconds.isFinite, abs(pts.seconds - clock.seconds) < 0.15,
               clock.seconds > adoptionClock + 0.1 { resumedFrame = true }
            else { try await Task.sleep(nanoseconds: 10_000_000) }
        }
        XCTAssertTrue(resumedFrame, "The adopted output must continue delivering decoded frames as playback advances")
#endif
        model.stop()
        let avStarted = ProcessInfo.processInfo.systemUptime
        let avMoving = await GreenfieldAVPlayerWarmup.prepare(request,
            liveClock: { 0.5 + ProcessInfo.processInfo.systemUptime - avStarted }, isPlaying: { true })
        XCTAssertNotNil(avMoving)
        XCTAssertEqual(avMoving?.currentTime().seconds ?? -1,
                       0.5 + ProcessInfo.processInfo.systemUptime - avStarted, accuracy: 0.15)
        avMoving?.pause()
        avMoving?.replaceCurrentItem(with: nil)
        // The source can stall immediately after the candidate aligns. A held
        // candidate must not run ahead while any queued preparation finishes.
        let heldStarted = ProcessInfo.processInfo.systemUptime
        var frozenLive: Double?
        let preparedHeldMoving = await GreenfieldAVPlayerWarmup.prepare(request,
            liveClock: { frozenLive ?? (0.5 + ProcessInfo.processInfo.systemUptime - heldStarted) },
            isPlaying: { true }, isAdvancing: { true }, holdForCommit: true,
            report: { stage, metrics in
                if stage == "candidate_aligned" { frozenLive = metrics["current"].flatMap(Double.init) }
            })
        let heldMoving = try XCTUnwrap(preparedHeldMoving)
        defer { heldMoving.pause(); heldMoving.replaceCurrentItem(with: nil) }
        XCTAssertEqual(heldMoving.rate, 0, "holdForCommit must freeze even an advancing candidate")
        let frozenClock = try XCTUnwrap(frozenLive)
        // Reproduce a late original stall during asynchronous session work,
        // exceeding the unchanged 100ms commit tolerance with the old code.
        _ = try await GreenfieldVideoPlayerModel.prepareSession(native)
        try await Task.sleep(nanoseconds: 300_000_000)
        let delayedClock = heldMoving.currentTime().seconds
        print("HELD_HANDOFF_TEST", "live", frozenClock, "candidate", delayedClock,
              "delta", delayedClock - frozenClock, "rate", heldMoving.rate)
        XCTAssertTrue(PlaybackHandoffReadinessPolicy.canCommit(candidate: delayedClock,
            live: frozenClock, ranges: heldMoving.currentItem?.loadedTimeRanges.map {
                (start: $0.timeRangeValue.start.seconds, end: $0.timeRangeValue.end.seconds)
            } ?? []), "Async preparation must not undo a held decoded alignment")
        heldMoving.pause()
        heldMoving.replaceCurrentItem(with: nil)
        // A telemetry snapshot can observe a later live clock than the one
        // checked before it. Model that queued source advance with real decode.
        var decodedSnapshotClock: Double?
        var snapshotClockReads = 0
        let snapshotCandidate = await GreenfieldAVPlayerWarmup.prepare(request,
            liveClock: {
                guard let decodedSnapshotClock else { return 0.5 }
                snapshotClockReads += 1
                return decodedSnapshotClock + (snapshotClockReads < 4 ? 0.05 : 0.25)
            }, isPlaying: { true }, isAdvancing: { true }, holdForCommit: true,
            report: { stage, metrics in
                if stage == "candidate_decoded" {
                    decodedSnapshotClock = metrics["candidateSeconds"].flatMap(Double.init)
                }
            })
        let heldSnapshot = try XCTUnwrap(snapshotCandidate)
        defer { heldSnapshot.pause(); heldSnapshot.replaceCurrentItem(with: nil) }
        let latestSnapshotClock = try XCTUnwrap(decodedSnapshotClock) + 0.25
        print("SNAPSHOT_HANDOFF_TEST", "candidate", heldSnapshot.currentTime().seconds,
              "live", latestSnapshotClock, "reads", snapshotClockReads)
        XCTAssertEqual(heldSnapshot.rate, 0)
        XCTAssertTrue(PlaybackHandoffReadinessPolicy.canCommit(
            candidate: heldSnapshot.currentTime().seconds, live: latestSnapshotClock,
            ranges: heldSnapshot.currentItem?.loadedTimeRanges.map {
                (start: $0.timeRangeValue.start.seconds, end: $0.timeRangeValue.end.seconds)
            } ?? []), "Telemetry must precede the final held-clock readiness check")
        heldSnapshot.replaceCurrentItem(with: nil)
        // Exercise the buffered jump against real AV decoding, not just a
        // policy return. A still-current source can have advanced while loading.
        var hasDecodedBufferedCandidate = false
        var bufferedStages: [String] = []
        let avBufferedJump = await GreenfieldAVPlayerWarmup.prepare(request,
            liveClock: { hasDecodedBufferedCandidate ? 4 : 1.5 }, isPlaying: { false },
            isAdvancing: { false }, report: { stage, _ in
                bufferedStages.append(stage)
                if stage == "candidate_decoded" { hasDecodedBufferedCandidate = true }
            })
        XCTAssertNotNil(avBufferedJump)
        XCTAssertTrue(bufferedStages.contains("candidate_buffered_seek_completed"))
        XCTAssertTrue(bufferedStages.contains("candidate_aligned"))
        XCTAssertEqual(avBufferedJump?.currentTime().seconds ?? -1, 4, accuracy: 0.1)
        XCTAssertEqual(avBufferedJump?.rate, 0)
        avBufferedJump?.replaceCurrentItem(with: nil)
        // iPad's first frame arrived 18.766 seconds behind the live source,
        // without a user seek. Keep trying within the existing deadline; a
        // real preference/seek invalidation must still abandon the candidate.
        var decodedAt: Double?
        var lagFailure: [String: String] = [:]
        let avLagging = await GreenfieldAVPlayerWarmup.prepare(request,
            liveClock: { decodedAt == nil ? 1.5 : 20.266 }, isPlaying: { true },
            isAdvancing: { false },
            candidateStillCurrent: {
                decodedAt.map { ProcessInfo.processInfo.systemUptime - $0 < 0.1 } ?? true
            }, report: { stage, metrics in
                if stage == "candidate_decoded" { decodedAt = ProcessInfo.processInfo.systemUptime }
                if stage == "warmup_failed" { lagFailure = metrics }
            })
        XCTAssertNotNil(decodedAt)
        XCTAssertNil(avLagging)
        XCTAssertEqual(lagFailure["reason"], "candidateInvalidated",
                       "Elapsed preparation lag must not masquerade as a user seek")
        // A paused source can await readiness after the first decoded frame.
        // Keep a deliberately unalignable still candidate alive until a real
        // invalidation arrives, rather than treating pause as cancellation.
        var pausedDecodedAt: Double?
        var pausedFailure: [String: String] = [:]
        let pausedWaiting = await GreenfieldAVPlayerWarmup.prepare(request,
            liveClock: { pausedDecodedAt == nil ? 1.5 : 20.266 }, isPlaying: { false },
            candidateStillCurrent: {
                pausedDecodedAt.map { ProcessInfo.processInfo.systemUptime - $0 < 0.1 } ?? true
            }, report: { stage, metrics in
                if stage == "candidate_decoded" { pausedDecodedAt = ProcessInfo.processInfo.systemUptime }
                if stage == "warmup_failed" { pausedFailure = metrics }
            })
        XCTAssertNotNil(pausedDecodedAt)
        XCTAssertNil(pausedWaiting)
        XCTAssertEqual(pausedFailure["reason"], "candidateInvalidated",
                       "Pause must await readiness until the candidate actually becomes invalid")
        var invalidated = false
        var invalidationStage: String?
        let avInvalidated = await GreenfieldAVPlayerWarmup.prepare(request,
            liveClock: { 1.5 }, isPlaying: { false },
            candidateStillCurrent: { !invalidated }, report: { stage, metrics in
                if stage == "candidate_preparing" { invalidated = true }
                if stage == "warmup_failed" { invalidationStage = metrics["stage"] }
            })
        XCTAssertNil(avInvalidated)
        XCTAssertEqual(invalidationStage, "candidateInvalidated")
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
        let context = VerifiedMemoryPlaybackIOContext(route: route, bytes: Data(repeating: 42, count: 1_000))
        let coordinator = PreloadCoordinator()

        let completedBytes = try await coordinator.schedule(
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
        XCTAssertEqual(completedBytes, 128)
        let read = try await context.read(range: PlaybackByteRange(start: 0, length: completedBytes))
        XCTAssertEqual(read.data, Data(repeating: 42, count: 128))
    }

    func testObservationOnlyIODoesNotInventCachedBytes() async throws {
        let route = PlaybackRoute(routeKind: .directHTTP, playMethod: .directPlay,
            url: URL(string: "https://example.com/video.mkv")!, rangeCapability: .supported)
        let context = ObservingPlaybackIOContext(route: route)
        let range = PlaybackByteRange(start: 0, length: 128)
        try await context.preload(range: range, budget: 128)
        let cached = await context.cachedRanges()
        let claimsCached = await context.isRangeCached(range)
        XCTAssertTrue(cached.isEmpty)
        XCTAssertFalse(claimsCached)
        do {
            _ = try await context.read(range: range)
            XCTFail("An observer must not return a fabricated network read")
        } catch { XCTAssertEqual((error as? URLError)?.code, .unsupportedURL) }
    }

    func testObservationOnlyStartupReportsZeroActualPreload() async throws {
        let recorder = PlaybackDiagnosticsRecorder()
        let intent = PlaybackIntent(sourceKind: .directURL,
            itemIdentity: PlaybackItemIdentity(sourceKind: .directURL), displayTitle: "Movie",
            directURL: URL(string: "http://192.168.1.8/movie.mkv")!,
            networkContext: PlaybackNetworkContext(networkClass: .local, isPrivateRoute: true))
        let coordinator = PlaybackSessionCoordinator(
            resolver: URLPlaybackSourceResolver(sourceKind: .directURL,
                fileExtensionHint: "mkv", byteLength: 1_000), diagnostics: recorder)
        let result = try await coordinator.prepare(intent)
        let events = await recorder.events
        XCTAssertEqual(result.completedPreloadBytes, 0)
        XCTAssertFalse(events.contains { $0.name == .preloadCompleted })
        XCTAssertEqual(events.first { $0.name == .preloadCancelled }?.metrics["reason"], "bytesNotMaterialized")
    }

    func testFailedPreloadDoesNotRemainActiveOrCompleted() async throws {
        let route = PlaybackRoute(routeKind: .directHTTP, playMethod: .directPlay,
            url: URL(string: "https://example.com/video.mkv")!, rangeCapability: .supported)
        let context = VerifiedMemoryPlaybackIOContext(route: route,
            bytes: Data(repeating: 42, count: 1_000), failsPreload: true)
        let coordinator = PreloadCoordinator()
        do {
            try await coordinator.schedule(PlaybackPreloadRequest(planID: UUID(), routeID: route.id,
                range: PlaybackByteRange(start: 0, length: 128), budgetBytes: 128, reason: .startup),
                ioContext: context)
            XCTFail("A failed byte transfer must propagate its error")
        } catch { XCTAssertEqual((error as? URLError)?.code, .networkConnectionLost) }
        let active = await coordinator.activeRequests
        let completed = await coordinator.completedRequests
        XCTAssertTrue(active.isEmpty)
        XCTAssertTrue(completed.isEmpty)
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

    func testNetworkUpstreamBehindLocalRangeProxyRaisesReserveAfterStartup() {
        let intent = PlaybackIntent(
            sourceKind: .dsmFile,
            contentKind: .video,
            itemIdentity: PlaybackItemIdentity(sourceKind: .dsmFile, stablePath: "/video/large.mkv"),
            displayTitle: "Large Remote File",
            directURL: URL(string: "http://127.0.0.1:62403/large.mkv")!,
            connectionContext: PlaybackConnectionContext.make(
                url: URL(string: "https://nas.example.com:5001/webapi/entry.cgi")
            ),
            networkContext: PlaybackNetworkContext(networkClass: .wifi)
        )
        let policy = PlaybackPlanningPolicy.startupPolicy(intent: intent, routeKind: .localRangeProxy)
        XCTAssertEqual(policy.minimumPlayableBufferSeconds, 1)
        XCTAssertEqual(PlaybackPlanningPolicy.steadyStateBufferSeconds(
            routeKind: .localRangeProxy,
            upstreamAddressKind: intent.connectionContext.addressKind,
            startupSeconds: policy.minimumPlayableBufferSeconds
        ), 4)

        var localIntent = intent
        localIntent.connectionContext = PlaybackConnectionContext.make(
            url: URL(string: "https://192.168.1.8:5001/webapi/entry.cgi")
        )
        let localPolicy = PlaybackPlanningPolicy.startupPolicy(intent: localIntent, routeKind: .localRangeProxy)
        XCTAssertEqual(localPolicy.minimumPlayableBufferSeconds, 1)
        XCTAssertEqual(PlaybackPlanningPolicy.steadyStateBufferSeconds(
            routeKind: .localRangeProxy,
            upstreamAddressKind: localIntent.connectionContext.addressKind,
            startupSeconds: localPolicy.minimumPlayableBufferSeconds
        ), 4)
        // Neither local playback nor an unrelated renderer route inherits the
        // network proxy's steady-state recovery target.
        XCTAssertEqual(PlaybackPlanningPolicy.steadyStateBufferSeconds(
            routeKind: .localFile, upstreamAddressKind: .privateIP, startupSeconds: 0
        ), 0)
        XCTAssertEqual(PlaybackPlanningPolicy.steadyStateBufferSeconds(
            routeKind: .localRangeProxy, upstreamAddressKind: .loopback, startupSeconds: 1
        ), 1)
        XCTAssertEqual(PlaybackPlanningPolicy.steadyStateBufferSeconds(
            routeKind: .localRangeProxy, upstreamAddressKind: .privateIP, startupSeconds: 6
        ), 6)
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
        XCTAssertTrue(names.contains(.preloadCancelled))
        XCTAssertFalse(names.contains(.preloadCompleted))
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
        XCTAssertEqual(result.completedPreloadBytes, 0)
    }
}

/// Raw loopback TCP exposes FIN and RST separately; URLSession cancellation
/// cannot establish which TCP close signal actually reached the proxy.
private final class PlaybackRawHTTPClient: @unchecked Sendable {
    private var descriptor: Int32
    init(url: URL, range: String? = "bytes=0-3") throws {
        descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw POSIXError(.ENOTSOCK) }
        do {
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = UInt16(url.port!).bigEndian
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            let connected = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard connected == 0 else { throw POSIXError(.ECONNREFUSED) }
            var timeout = timeval(tv_sec: 3, tv_usec: 0)
            guard setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout,
                socklen_t(MemoryLayout<timeval>.size)) == 0 else { throw POSIXError(.EINVAL) }
            var noSignal: Int32 = 1
            guard setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSignal,
                socklen_t(MemoryLayout<Int32>.size)) == 0 else { throw POSIXError(.EINVAL) }
            let rangeHeader = range.map { "Range: \($0)\r\n" } ?? ""
            let target = url.path + (url.query.map { "?" + $0 } ?? "")
            let request = Data("GET \(target) HTTP/1.1\r\nHost: 127.0.0.1\r\n\(rangeHeader)Connection: close\r\n\r\n".utf8)
            let written = request.withUnsafeBytes { Darwin.send(descriptor, $0.baseAddress, $0.count, 0) }
            guard written == request.count else { throw POSIXError(.EIO) }
        } catch { close(); throw error }
    }
    func writeHalfClose() throws {
        guard Darwin.shutdown(descriptor, SHUT_WR) == 0 else { throw POSIXError(.EIO) }
    }
    func reset() throws {
        var option = linger(l_onoff: 1, l_linger: 0)
        guard setsockopt(descriptor, SOL_SOCKET, SO_LINGER, &option,
            socklen_t(MemoryLayout<linger>.size)) == 0 else { throw POSIXError(.EINVAL) }
        close()
    }
    func close() {
        if descriptor >= 0 { Darwin.close(descriptor); descriptor = -1 }
    }
    func response() async throws -> String {
        try await Task.detached { [self] in
            var response = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = Darwin.recv(descriptor, &buffer, buffer.count, 0)
                if count == 0 { return String(decoding: response, as: UTF8.self) }
                guard count > 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
                response.append(contentsOf: buffer.prefix(count))
                guard response.count < 64 * 1024 else { throw POSIXError(.EFBIG) }
                if let delimiter = response.range(of: Data("\r\n\r\n".utf8)) {
                    let header = String(decoding: response[..<delimiter.lowerBound], as: UTF8.self)
                    let length = header.components(separatedBy: "\r\n").first {
                        $0.lowercased().hasPrefix("content-length:")
                    }?.split(separator: ":").last.flatMap {
                        Int($0.trimmingCharacters(in: .whitespaces))
                    }
                    if let length, response.count == delimiter.upperBound + length {
                        return String(decoding: response, as: UTF8.self)
                    }
                }
            }
        }.value
    }
}

private actor ProxyBridgeFixture: NetworkMediaByteReader {
    let byteCount: Int64
    let fileName = "fixture.mkv"
    private var held: Bool
    private(set) var activeCount = 0

    init(byteCount: Int64, initiallyHeld: Bool = false) {
        self.byteCount = byteCount
        held = initiallyHeld
    }

    func release() { held = false }

    func stream(offset: Int64, count: Int64, deliver: (Data) async throws -> Void) async throws {
        activeCount += 1
        defer { activeCount -= 1 }
        while held { try await Task.sleep(for: .milliseconds(10)) }
        var position = offset
        while position < offset + count {
            let length = Int(min(512 * 1024, offset + count - position))
            try await deliver(Self.bytes(offset: position, count: length))
            position += Int64(length)
        }
    }

    nonisolated static func bytes(offset: Int64, count: Int) -> Data {
        let pattern = Data((0..<251).map { UInt8($0) })
        var bytes = Data(capacity: count)
        var index = Int(offset % 251)
        while bytes.count < count {
            let end = index + min(pattern.count - index, count - bytes.count)
            bytes.append(pattern[index..<end])
            index = 0
        }
        return bytes
    }
}

private final class PlaybackRangeTestServer: @unchecked Sendable {
    let ready = XCTestExpectation(description: "HTTP range fixture listening")
    private let rawResponses: [String]?
    private let startupSegmentResponse: String?
    private let holdsSegmentResponses: Bool
    private let listener: NWListener
    private let queue = DispatchQueue(label: "PlaybackRangeTestServer")
    private var connections: [NWConnection] = []
    private var requests = 0
    private var requestHeaders: [String] = []
    private var holdsResponses: Bool
    private var heldRequests: [(NWConnection, String)] = []
    private let playlist: String?
    private let masterPlaylist: String?
    private let segmentBody: String?
    private let compressedPlaylist: Data?
    private let payload: Data?
    private let pacedBodyChunkBytes: Int?
    private let pacedBodyDelay: TimeInterval
    private var pacedProgress: [Int: (bytes: Int, elapsed: TimeInterval)] = [:]
    private let payloadIsPlaylist: Bool
    private let requiresExplicitMediaSource: Bool
    private let rejectsCompactQuery: Bool
    var url: URL? { listener.port.flatMap { URL(string: "http://127.0.0.1:\($0.rawValue)/fixture.\(playlist == nil ? "mp4" : "m3u8")") } }
    var connectionCount: Int { queue.sync { connections.count } }
    var requestCount: Int { queue.sync { requests } }
    var receivedRequests: [String] { queue.sync { requestHeaders } }
    var pacedResponseProgress: [(bytes: Int, elapsed: TimeInterval)] {
        queue.sync { pacedProgress.keys.sorted().compactMap { pacedProgress[$0] } }
    }
    init(playlist: String? = nil, compressedPlaylist: Data? = nil, payload: Data? = nil,
         masterPlaylist: String? = nil, segmentBody: String? = nil, pacedBodyChunkBytes: Int? = nil,
         pacedBodyDelay: TimeInterval = 0, rejectsCompactQuery: Bool = false,
         payloadIsPlaylist: Bool = false, requiresExplicitMediaSource: Bool = false,
         holdsResponses: Bool = false, startupSegmentResponse: String? = nil, holdsSegmentResponses: Bool = false,
         rawResponses: [String]? = nil) throws {
        self.rawResponses = rawResponses
        self.startupSegmentResponse = startupSegmentResponse
        self.holdsSegmentResponses = holdsSegmentResponses
        self.holdsResponses = holdsResponses
        self.requiresExplicitMediaSource = requiresExplicitMediaSource
        self.payloadIsPlaylist = payloadIsPlaylist
        self.rejectsCompactQuery = rejectsCompactQuery
        self.pacedBodyChunkBytes = pacedBodyChunkBytes
        self.pacedBodyDelay = pacedBodyDelay
        self.masterPlaylist = masterPlaylist
        self.segmentBody = segmentBody
        self.playlist = playlist
        self.compressedPlaylist = compressedPlaylist
        self.payload = payload
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
    func holdResponses() {
        queue.sync { holdsResponses = true }
    }
    func releaseResponses() {
        queue.async {
            self.holdsResponses = false
            let pending = self.heldRequests
            self.heldRequests.removeAll()
            for (connection, request) in pending { self.respond(to: request, on: connection) }
        }
    }
    private func sendPaced(_ body: Data, on connection: NWConnection, offset: Int, chunk: Int,
                           started: DispatchTime, response: Int) {
        guard offset < body.count else { receive(connection); return }
        let end = min(offset + chunk, body.count)
        // Anchor a fixed-rate source to its first send. Scheduling the next
        // delay from each completion accumulates timer and callback overhead.
        let deadline = started + Double(offset / chunk + 1) * pacedBodyDelay
        queue.asyncAfter(deadline: deadline) { [weak self] in
            connection.send(content: body.subdata(in: offset..<end), completion: .contentProcessed { error in
                if error == nil {
                    self?.pacedProgress[response] = (end, Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000_000)
                    self?.sendPaced(body, on: connection, offset: end, chunk: chunk, started: started, response: response)
                }
            })
        }
    }
    private func receive(_ connection: NWConnection, pending: Data = Data()) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, done, error in
            guard let self else { return }
            let received = pending + (data ?? Data())
            guard received.range(of: Data("\r\n\r\n".utf8)) != nil else {
                if error == nil && !done { self.receive(connection, pending: received) }
                return
            }
            self.requests += 1
            let request = String(decoding: received, as: UTF8.self)
            self.requestHeaders.append(request)
            if self.holdsResponses || (self.holdsSegmentResponses && request.contains(".ts ")) {
                self.heldRequests.append((connection, request))
            } else {
                self.respond(to: request, on: connection)
            }
        }
    }
    private func respond(to request: String, on connection: NWConnection) {
        if let responses = rawResponses, !responses.isEmpty {
            let response = responses[min(max(requests - 1, 0), responses.count - 1)]
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
            return
        }
        if let response = startupSegmentResponse, request.contains(".ts ") {
            connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] error in
                if error == nil { self?.receive(connection) }
            })
            return
        }
        if self.requiresExplicitMediaSource {
            let target = request.components(separatedBy: " ").dropFirst().first ?? ""
            let items = URLComponents(string: "http://fixture" + target)?.queryItems ?? []
            if !items.contains(where: { $0.name.lowercased() == "mediasourceid" && !($0.value ?? "").isEmpty }) {
                connection.send(content: Data("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8), completion: .contentProcessed { _ in connection.cancel() })
                return
            }
        }
        if self.rejectsCompactQuery, request.lowercased().contains("params=") {
            connection.send(content: Data("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8), completion: .contentProcessed { _ in connection.cancel() })
            return
        }
        if let payload = self.payload {
            let range = request.lowercased().components(separatedBy: "\r\n")
                .first { $0.hasPrefix("range:") }?.components(separatedBy: "bytes=").last?
                .components(separatedBy: "-") ?? []
            let start = range.first.flatMap(Int.init) ?? 0
            let end = min(range.last.flatMap(Int.init) ?? (payload.count - 1), payload.count - 1)
            guard start >= 0, end >= start else { connection.cancel(); return }
            let body = payload.subdata(in: start..<(end + 1))
            let header = self.payloadIsPlaylist
                ? "HTTP/1.1 200 OK\r\nContent-Type: application/vnd.apple.mpegurl\r\nContent-Length: \(body.count)\r\nConnection: keep-alive\r\n\r\n"
                : "HTTP/1.1 206 Partial Content\r\nContent-Type: video/mp4\r\nContent-Length: \(body.count)\r\nContent-Range: bytes \(start)-\(end)/\(payload.count)\r\nAccept-Ranges: bytes\r\nConnection: keep-alive\r\n\r\n"
            if let chunk = self.pacedBodyChunkBytes {
                let started = DispatchTime.now()
                let response = self.requests
                connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] error in
                    if error == nil { self?.sendPaced(body, on: connection, offset: 0, chunk: chunk, started: started, response: response) }
                })
            } else {
                connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { [weak self] error in
                    if error == nil { self?.receive(connection) }
                })
            }
            return
        }
        let response: String
        if let playlist = request.contains("/fixture.m3u8") ? (self.masterPlaylist ?? self.playlist) : self.playlist,
           request.components(separatedBy: " ").dropFirst().first?.contains(".m3u8") == true {
            response = "HTTP/1.1 200 OK\r\nContent-Type: application/vnd.apple.mpegurl\r\nContent-Length: \(playlist.utf8.count)\r\nConnection: keep-alive\r\n\r\n" + playlist
        } else if let segmentBody,
                  request.components(separatedBy: " ").dropFirst().first?.hasSuffix(".ts") == true {
            response = "HTTP/1.1 200 OK\r\nContent-Type: video/mp2t\r\nContent-Length: \(segmentBody.utf8.count)\r\nConnection: keep-alive\r\n\r\n" + segmentBody
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

#if canImport(KSPlayer)
private final class BitmapQueueTestFrame: ObjectQueueItem {
    var timebase = Timebase.defaultValue
    var timestamp: Int64
    var duration: Int64 = 0
    var position: Int64 = 0
    var size: Int32 = 0
    let isClear: Bool
    init(_ timestamp: Int64, isClear: Bool = false) { self.timestamp = timestamp; self.isClear = isClear }
}

private final class ResetSubtitleProbe: SubtitleInfo {
    let subtitleID = "reset-probe"
    let name = "Reset probe"
    var delay: TimeInterval = 0
    var onDisable: (() -> Void)?
    var isEnabled = false {
        didSet { if !isEnabled { onDisable?() } }
    }
    func search(for time: TimeInterval) -> [SubtitlePart] { [] }
}
#endif

@MainActor
private final class PlaybackReportQueueTestProbe {
    var events: [String] = []
    var releaseStart: CheckedContinuation<Void, Never>?
}

@MainActor
private final class ControlledIdentityProbe {
    typealias Result = JellyfinOverlappingIdentityProbes.Result
    let started = XCTestExpectation(description: "independent identity request started")
    let finished = XCTestExpectation(description: "independent identity request finished")
    private var continuation: CheckedContinuation<Result, Never>?
    private var completed = false
    private(set) var wasCancelled = false

    func run() async -> Result {
        started.fulfill()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                if Task.isCancelled { cancel() }
            }
        } onCancel: {
            Task { @MainActor in self.cancel() }
        }
    }

    func finish(with result: Result) {
        guard !completed, let continuation else { return }
        completed = true
        self.continuation = nil
        continuation.resume(returning: result)
        finished.fulfill()
    }

    private func cancel() {
        guard !completed else { return }
        wasCancelled = true
        finish(with: (nil, nil, "URL_-999"))
    }
}

/// Materializes fixture bytes before marking a range; the observer cannot stand
/// in for a byte cache when testing successful preloading.
private final class VerifiedMemoryPlaybackIOContext: PlaybackIOContext {
    let route: PlaybackRoute
    private let bytes: Data
    private let cache = RangeCacheStore()
    private let failsPreload: Bool
    init(route: PlaybackRoute, bytes: Data, failsPreload: Bool = false) {
        self.route = route; self.bytes = bytes; self.failsPreload = failsPreload
    }
    func open() async throws {}
    func read(range: PlaybackByteRange) async throws -> PlaybackReadResult {
        guard range.endExclusive <= bytes.count else { throw URLError(.badServerResponse) }
        return PlaybackReadResult(range: range,
            data: bytes.subdata(in: Int(range.start)..<Int(range.endExclusive)), source: .localFile)
    }
    func seek(to offset: Int64) async throws {}
    func cachedRanges() async -> [PlaybackByteRange] { await cache.cachedRanges }
    func isRangeCached(_ range: PlaybackByteRange) async -> Bool { await cache.isCached(range) }
    func isRangeUncached(_ range: PlaybackByteRange) async -> Bool { await cache.isUncached(range) }
    func preload(range: PlaybackByteRange, budget: Int64) async throws {
        if failsPreload { throw URLError(.networkConnectionLost) }
        let bounded = PlaybackByteRange(start: range.start, length: min(range.length, max(budget, 0)))
        let result = try await read(range: bounded)
        guard result.data.count == bounded.length else { throw URLError(.badServerResponse) }
        await cache.markCached(bounded)
    }
    func invalidate(reason: String) async { await cache.reset() }
    func close() async {}
}
