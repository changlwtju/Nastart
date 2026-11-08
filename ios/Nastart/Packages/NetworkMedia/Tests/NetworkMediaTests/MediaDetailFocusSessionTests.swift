import XCTest
@testable import NetworkMedia

final class MediaDetailFocusSessionTests: XCTestCase {
    func testUnavailableFileRestoresOwnerDespiteNativeFallbackToHero() {
        var session = MediaDetailFocusSession(map: map(files: ["f1", "f2"], people: ["A", "B", "C"]))
        session.request("overview"); session.recordFocus("overview")
        XCTAssertEqual(session.move(from: "overview", direction: .down), "f1"); session.recordFocus("f1")
        XCTAssertEqual(session.move(from: "f1", direction: .down), "f2"); session.recordFocus("f2")
        session.recordFocus("overview") // UIKit's automatic fallback is not a user request.
        XCTAssertEqual(session.owner, "f2")
        XCTAssertEqual(session.update(map(files: ["f1"], people: ["A", "B", "C"])), "f1")
        XCTAssertEqual(session.preferredFocus, "f1")
        XCTAssertTrue(session.canRestore("f1"))
        XCTAssertFalse(session.canRestore("f2"))
    }
    func testReorderedPeopleKeepOwnerAndRemovedPersonChoosesExistingPerson() {
        var session = MediaDetailFocusSession(map: map(files: ["f1"], people: ["A", "B", "C"]))
        session.request("B"); session.recordFocus("B")
        session.recordFocus("A")
        XCTAssertEqual(session.update(map(files: ["f1"], people: ["C", "A", "B"])), "B")
        session.recordFocus("B")
        XCTAssertEqual(session.move(from: "B", direction: .left), "A"); session.recordFocus("A")
        XCTAssertEqual(session.update(map(files: ["f1"], people: ["C", "B"])), "C")
    }
    func testNativeEditSurvivesMetadataChangeAndTemporaryFocusGap() {
        var session = MediaDetailFocusSession(map: map(files: [], people: ["C"]), nativeIDs: ["edit"])
        session.request("info"); session.recordFocus("info")
        session.recordFocus("edit")
        XCTAssertNil(session.update(map(files: [], people: [])))
        XCTAssertEqual(session.preferredFocus, "edit")
        XCTAssertFalse(session.canRestore("info"))
        session.recordFocus(nil)
        XCTAssertEqual(session.preferredFocus, "edit")
        XCTAssertFalse(session.canRestore("info"))
        session.recordFocus("info")
        XCTAssertEqual(session.owner, "info")
        XCTAssertTrue(session.canRestore("info"))
    }
    func testConfirmedDestinationIsRememberedForFileAndPersonReturn() {
        var session = MediaDetailFocusSession(map: map(files: ["f1", "f2"], people: ["A", "B"]))
        session.request("f2"); session.recordFocus("f2")
        XCTAssertEqual(session.move(from: "f2", direction: .down), "A"); session.recordFocus("A")
        XCTAssertEqual(session.move(from: "A", direction: .right), "B"); session.recordFocus("B")
        XCTAssertEqual(session.move(from: "B", direction: .up), "f2")
        session.recordFocus("f2")
        XCTAssertEqual(session.move(from: "f2", direction: .down), "A")
        session.recordFocus("A")
        XCTAssertEqual(session.move(from: "A", direction: .down), "info")
        session.recordFocus("info")
        XCTAssertEqual(session.move(from: "info", direction: .up), "A")
    }
    func testInvalidAndExpiredRequestsCannotBeRestored() {
        var session = MediaDetailFocusSession(map: map(files: ["f1"], people: []))
        session.request("f1"); session.recordFocus("f1")
        XCTAssertNil(session.request("not-present"))
        XCTAssertEqual(session.requested, "f1")
        XCTAssertFalse(session.canRestore("not-present"))
        XCTAssertEqual(session.update(map(files: [], people: [])), "overview")
        XCTAssertFalse(session.canRestore("f1"))
        session.request(nil)
        XCTAssertFalse(session.canRestore("overview"))
    }
    func testNativeArrivalBeforeCommandRemembersPersonForRemovalFallback() {
        var session = MediaDetailFocusSession(map: map(files: ["f1"], people: ["C", "A", "B"]))
        session.request("B"); session.recordFocus("B")
        session.recordFocus("A") // Native movement happens before B's left callback.
        XCTAssertEqual(session.move(from: "B", direction: .left), "A")
        // No second recordFocus(A): the actual binding did not change again.
        XCTAssertEqual(session.update(map(files: ["f1"], people: ["C", "B"])), "C")
    }
    func testNativeArrivalBeforeCommandRemembersFileForUpReturn() {
        var session = MediaDetailFocusSession(map: map(files: ["f1", "f2"], people: []))
        session.request("f1"); session.recordFocus("f1")
        session.recordFocus("f2")
        XCTAssertEqual(session.move(from: "f1", direction: .down), "f2")
        session.recordFocus("info")
        XCTAssertEqual(session.move(from: "f2", direction: .down), "info")
        XCTAssertEqual(session.move(from: "info", direction: .up), "f2")
    }
    private func map(files: [String], people: [String]) -> MediaDetailFocusMap {
        .init(actions: ["overview"], people: people, related: [], relatedRetry: nil, files: "info", fileChoices: files)
    }
}
