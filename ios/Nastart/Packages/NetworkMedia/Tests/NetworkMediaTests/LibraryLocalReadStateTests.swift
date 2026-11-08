import XCTest
@testable import NetworkMedia

final class LibraryLocalReadStateTests: XCTestCase {
    func testOnlyLatestReadMayComplete() {
        var state = LibraryLocalReadState()
        XCTAssertEqual(state.phase, .idle)
        let old = state.begin()
        let latest = state.begin()
        XCTAssertFalse(state.succeed(old))
        XCTAssertFalse(state.fail(old, message: "stale failure"))
        XCTAssertFalse(state.cancel(old))
        XCTAssertTrue(state.isCurrent(latest))
        XCTAssertEqual(state.phase, .loading)
        XCTAssertNil(state.failureMessage)
        XCTAssertTrue(state.succeed(latest))
        XCTAssertEqual(state.phase, .ready)
    }
    func testRetryClearsOnlyItsReadFailureAndRejectsLateError() {
        var state = LibraryLocalReadState()
        let failed = state.begin()
        XCTAssertTrue(state.fail(failed, message: "local read failed"))
        XCTAssertEqual(state.phase, .failed)
        XCTAssertEqual(state.failureMessage, "local read failed")
        let retry = state.begin()
        XCTAssertNil(state.failureMessage)
        XCTAssertFalse(state.fail(failed, message: "late failure"))
        XCTAssertTrue(state.succeed(retry))
        XCTAssertFalse(state.fail(retry, message: "after completion"))
        XCTAssertFalse(state.cancel(retry))
        XCTAssertEqual(state.phase, .ready)
        XCTAssertNil(state.failureMessage)
    }
    func testCancellationLeavesRetryableIdleInsteadOfLoading() {
        var state = LibraryLocalReadState()
        let cancelled = state.begin()
        XCTAssertTrue(state.cancel(cancelled))
        XCTAssertEqual(state.phase, .idle)
        XCTAssertFalse(state.isCurrent(cancelled))
        XCTAssertFalse(state.succeed(cancelled))
        XCTAssertFalse(state.fail(cancelled, message: "late failure"))
        let retry = state.begin()
        XCTAssertTrue(state.succeed(retry))
        XCTAssertEqual(state.phase, .ready)
    }
}
