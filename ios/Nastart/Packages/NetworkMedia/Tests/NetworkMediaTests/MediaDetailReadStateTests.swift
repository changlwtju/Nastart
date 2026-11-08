import XCTest
@testable import NetworkMedia

final class MediaDetailReadStateTests: XCTestCase {
    func testReturningToSameQueryDoesNotAcceptItsOlderResponse() {
        var state = MediaReadState()
        let firstA = state.begin("A")
        let b = state.begin("B")
        let currentA = state.begin("A")
        XCTAssertFalse(state.succeed(firstA))
        XCTAssertFalse(state.fail(b))
        XCTAssertFalse(state.cancel(firstA))
        XCTAssertEqual(state.phase(for: "A"), .loading)
        XCTAssertTrue(state.succeed(currentA))
        XCTAssertEqual(state.phase(for: "B"), .idle)
    }
    func testClearingAndReenteringQueryInvalidatesTheOriginalTicket() {
        var state = MediaReadState()
        let old = state.begin("query")
        state = MediaReadState()
        XCTAssertNil(state.ticket)
        XCTAssertFalse(state.succeed(old))
        let current = state.begin("query")
        XCTAssertFalse(state.fail(old))
        XCTAssertTrue(state.succeed(current))
    }
    func testCompletedResultCannotBeOverwrittenAndNewQueryHasNoOldPhase() {
        var state = MediaReadState()
        let ticket = state.begin("A")
        XCTAssertTrue(state.succeed(ticket))
        XCTAssertFalse(state.fail(ticket))
        XCTAssertFalse(state.cancel(ticket))
        XCTAssertEqual(state.phase(for: "A"), .ready)
        XCTAssertEqual(state.phase(for: "B"), .idle)
    }
    func testOldSuccessFailureAndCancellationCannotFinishNewItem() {
        var state = MediaDetailReadState()
        let old = state.begin("A"), current = state.begin("B")
        XCTAssertFalse(state.succeed(old)); XCTAssertFalse(state.fail(old)); XCTAssertFalse(state.cancel(old))
        XCTAssertEqual(state.phase(for: "B"), .loading); XCTAssertEqual(state.phase(for: "A"), .idle)
        XCTAssertTrue(state.succeed(current)); XCTAssertEqual(state.phase(for: "B"), .ready)
    }
    func testRetryForSameIdentityRejectsPreviousGeneration() {
        var state = MediaDetailReadState()
        let old = state.begin("same")
        XCTAssertTrue(state.cancel(old)); XCTAssertEqual(state.phase(for: "same"), .idle)
        let retry = state.begin("same")
        XCTAssertNotEqual(old, retry); XCTAssertFalse(state.fail(old)); XCTAssertFalse(state.succeed(old))
        XCTAssertTrue(state.fail(retry)); XCTAssertEqual(state.phase(for: "same"), .failed)
        XCTAssertFalse(state.succeed(retry))
    }
    func testPendingReadsCannotClaimMetadataIsMissing() {
        for metadata in [MediaDetailReadState.Phase.idle, .loading] {
            XCTAssertEqual(MediaCreditsAvailability.resolve(hasPeople: false, metadata: metadata, credits: .ready), .loading)
        }
        XCTAssertEqual(MediaCreditsAvailability.resolve(hasPeople: false, metadata: .ready, credits: .loading), .loading)
        XCTAssertEqual(MediaCreditsAvailability.resolve(hasPeople: false, metadata: .failed, credits: .loading), .loading)
    }
    func testFailureIsNotConfusedWithSuccessfulEmptyRead() {
        XCTAssertEqual(MediaCreditsAvailability.resolve(hasPeople: false, metadata: .ready, credits: .ready), .missing)
        XCTAssertEqual(MediaCreditsAvailability.resolve(hasPeople: false, metadata: .failed, credits: .ready), .unavailable)
        XCTAssertEqual(MediaCreditsAvailability.resolve(hasPeople: false, metadata: .ready, credits: .failed), .unavailable)
    }
    func testExistingPeopleRemainVisibleWhileSupplementalReadFailsOrLoads() {
        for phase in [MediaDetailReadState.Phase.idle, .loading, .ready, .failed] {
            XCTAssertNil(MediaCreditsAvailability.resolve(hasPeople: true, metadata: phase, credits: .failed))
        }
    }
}
