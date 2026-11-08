import XCTest
@testable import NetworkMedia

final class PlaybackTransportStateTests: XCTestCase {
    func testSharedBoundsKeepMobileEndMarginAndSupportShortClips() throws {
        XCTAssertEqual(PlaybackSeekState.target(absolute: -15, duration: 100), 0)
        XCTAssertEqual(PlaybackSeekState.target(absolute: 115, duration: 100), 99.9)
        XCTAssertEqual(PlaybackSeekState.target(absolute: 1, duration: 0.05), 0)
        XCTAssertEqual(PlaybackSeekState.target(absolute: 128.125, duration: 7_535), 128.125)
    }

    func testRapidCommandsExtendPendingTargetInsteadOfLateClock() throws {
        var state = PlaybackSeekState()
        let first = try XCTUnwrap(state.target(relative: 15, clock: 100.25, fallback: 100, duration: 7_535))
        _ = state.begin(absolute: first, duration: 7_535)
        let second = try XCTUnwrap(state.target(relative: 15, clock: 100.3, fallback: first, duration: 7_535))
        _ = state.begin(absolute: second, duration: 7_535)
        let third = try XCTUnwrap(state.target(relative: -15, clock: 100.5, fallback: second, duration: 7_535))
        XCTAssertEqual([first, second, third], [115.25, 130.25, 115.25])
    }

    func testOnlyCurrentCompletionCanClearPendingTarget() throws {
        var state = PlaybackSeekState()
        let first = try XCTUnwrap(state.begin(absolute: 115, duration: 600))
        let latest = try XCTUnwrap(state.begin(absolute: 130, duration: 600))
        XCTAssertFalse(state.complete(generation: first.generation))
        XCTAssertEqual(state.pendingTarget, 130)
        XCTAssertTrue(state.complete(generation: latest.generation))
        XCTAssertNil(state.pendingTarget)
        XCTAssertFalse(state.complete(generation: latest.generation))
    }

    func testRendererReplacementInvalidatesEvenAnIdenticalPosition() throws {
        var state = PlaybackSeekState()
        let old = try XCTUnwrap(state.begin(absolute: 100, duration: 600))
        state.invalidate()
        let replacement = try XCTUnwrap(state.begin(absolute: 100, duration: 600))
        XCTAssertGreaterThan(replacement.generation, old.generation)
        XCTAssertFalse(state.complete(generation: old.generation))
        XCTAssertEqual(state.pendingTarget, 100)
    }

    func testRejectedCommandsDoNotInvalidateTheCurrentSeek() throws {
        var state = PlaybackSeekState()
        _ = state.begin(absolute: 200, duration: 600)
        let before = state
        for invalid in [Double.nan, .infinity, -.infinity] {
            XCTAssertNil(state.begin(absolute: invalid, duration: 600))
            XCTAssertNil(state.begin(absolute: 10, duration: invalid))
        }
        XCTAssertNil(state.begin(absolute: 10, duration: 0))
        XCTAssertNil(state.begin(absolute: 10, duration: -1))
        XCTAssertEqual(state, before)
    }

    func testRelativeCommandsUseValidClockThenFallbackAndRejectOverflow() {
        let state = PlaybackSeekState()
        XCTAssertEqual(state.target(relative: 15, clock: .nan, fallback: 90, duration: 100), 99.9)
        XCTAssertEqual(state.target(relative: -15, clock: -1, fallback: 5, duration: 100), 0)
        XCTAssertNil(state.target(relative: 15, clock: .nan, fallback: .nan, duration: 100))
        XCTAssertNil(state.target(relative: .infinity, clock: 5, fallback: 5, duration: 100))
        XCTAssertNil(state.target(relative: .greatestFiniteMagnitude, clock: .greatestFiniteMagnitude,
                                  fallback: 0, duration: 600))
    }

    func testHandoffRejectsNewSeekAndEveryPiPOwnershipChange() {
        let boundary = PlaybackHandoffBoundary(seekGeneration: 3, pictureInPictureGeneration: 5)
        XCTAssertTrue(boundary.allowsReplacement(seekGeneration: 3, pictureInPictureGeneration: 5))
        XCTAssertFalse(boundary.allowsReplacement(seekGeneration: 4, pictureInPictureGeneration: 5))
        XCTAssertFalse(boundary.allowsReplacement(seekGeneration: 3, pictureInPictureGeneration: 6))
        XCTAssertFalse(boundary.allowsReplacement(seekGeneration: 3, pictureInPictureGeneration: 5,
                                                  isPictureInPictureStarting: true))
        XCTAssertFalse(boundary.allowsReplacement(seekGeneration: 3, pictureInPictureGeneration: 5,
                                                  isPictureInPictureActive: true))
    }

    func testExplicitReplacementCanOmitSeekConstraintButNeverPiPOwnership() {
        let boundary = PlaybackHandoffBoundary(pictureInPictureGeneration: 5)
        XCTAssertTrue(boundary.allowsReplacement(seekGeneration: 999, pictureInPictureGeneration: 5))
        XCTAssertFalse(boundary.allowsReplacement(seekGeneration: 999, pictureInPictureGeneration: 6))
    }
}
