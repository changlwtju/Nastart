import XCTest
@testable import NetworkMedia

final class MediaDetailFocusMapTests: XCTestCase {
    func testVerticalNavigationIncludesRetryAcrossEverySparseLayout() {
        for cast in [false, true] { for related in [false, true] { for retry in [false, true] { for files in [false, true] {
            let map = MediaDetailFocusMap(actions: ["play"], people: cast ? ["person"] : [],
                related: related ? ["film"] : [], relatedRetry: retry ? "retry" : nil, files: files ? "files" : nil)
            let regions = ["play", cast ? "person" : nil, related ? "film" : nil,
                retry ? "retry" : nil, files ? "files" : nil].compactMap { $0 }
            for index in regions.indices {
                XCTAssertEqual(map.target(from: regions[index], direction: .down),
                    index + 1 < regions.count ? regions[index + 1] : nil, "layout=\(regions)")
                XCTAssertEqual(map.target(from: regions[index], direction: .up),
                    index > 0 ? regions[index - 1] : nil, "layout=\(regions)")
            }
        } } } }
    }
    func testHorizontalEdgesStayInsideTheirRows() {
        let map = full
        XCTAssertEqual(map.target(from: "p1", direction: .left), "p1")
        XCTAssertEqual(map.target(from: "p1", direction: .right), "p2")
        XCTAssertEqual(map.target(from: "p2", direction: .right), "p2")
        XCTAssertEqual(map.target(from: "r1", direction: .left), "r1")
        XCTAssertEqual(map.target(from: "r2", direction: .left), "r1")
        XCTAssertEqual(map.target(from: "r2", direction: .right), "r2")
        XCTAssertNil(map.target(from: "retry", direction: .right))
    }
    func testUpFromRetryRestoresLastValidRelatedCard() {
        XCTAssertEqual(full.target(from: "retry", direction: .up, lastRelated: "r2"), "r2")
        XCTAssertEqual(full.target(from: "retry", direction: .up, lastRelated: "removed"), "r1")
        XCTAssertEqual(full.target(from: "r2", direction: .up, lastPerson: "p2"), "p2")
        XCTAssertEqual(full.target(from: "p1", direction: .up, lastAction: "restart"), "restart")
    }
    func testRemovedRetryRecoversToAnExistingNearbyRegion() {
        XCTAssertEqual(full.fallbackAfterRetry(lastRelated: "r2"), "r2")
        XCTAssertEqual(full.fallbackAfterRetry(lastRelated: "removed"), "r1")
        let noRelated = MediaDetailFocusMap(actions: ["play"], people: ["p1", "p2"], related: [], relatedRetry: nil, files: "files")
        XCTAssertEqual(noRelated.fallbackAfterRetry(lastPerson: "p2"), "files")
        let castOnly = MediaDetailFocusMap(actions: ["play"], people: ["p1", "p2"], related: [], relatedRetry: nil, files: nil)
        XCTAssertEqual(castOnly.fallbackAfterRetry(lastPerson: "p2"), "p2")
    }
    func testStaleMemoriesDoNotInventTargets() {
        XCTAssertEqual(full.target(from: "p1", direction: .up, lastAction: "gone"), "play")
        XCTAssertEqual(full.target(from: "r1", direction: .up, lastPerson: "gone"), "p1")
        XCTAssertNil(full.target(from: "gone", direction: .down))
        let empty = MediaDetailFocusMap(actions: [], people: [], related: [], relatedRetry: nil, files: nil)
        XCTAssertNil(empty.fallbackAfterRetry(lastAction: "play", lastPerson: "p1", lastRelated: "r1"))
        XCTAssertNil(empty.target(from: "files", direction: .up))
    }
    func testRetryCanBeReachedWithoutCastRelatedOrFiles() {
        let map = MediaDetailFocusMap(actions: ["play"], people: [], related: [], relatedRetry: "retry", files: nil)
        XCTAssertEqual(map.target(from: "play", direction: .down), "retry")
        XCTAssertEqual(map.target(from: "retry", direction: .up), "play")
        XCTAssertEqual(map.fallbackAfterRetry(), "play")
    }
    func testSingleItemRowsHaveStableEdges() {
        let map = MediaDetailFocusMap(actions: ["play"], people: ["p"], related: ["r"], relatedRetry: nil, files: nil)
        for direction in [MediaDetailFocusMap.Direction.left, .right] {
            XCTAssertEqual(map.target(from: "p", direction: direction), "p")
            XCTAssertEqual(map.target(from: "r", direction: direction), "r")
        }
    }
    func testHeroActionsReachRetryInSemanticOrderAndClampEdges() {
        let map = MediaDetailFocusMap(actions: ["play", "restart", "overview", "detailRetry"],
            people: ["p1"], related: [], relatedRetry: nil, files: nil)
        XCTAssertEqual(map.target(from: "play", direction: .left), "play")
        XCTAssertEqual(map.target(from: "play", direction: .right), "restart")
        XCTAssertEqual(map.target(from: "overview", direction: .right), "detailRetry")
        XCTAssertEqual(map.target(from: "detailRetry", direction: .right), "detailRetry")
        XCTAssertEqual(map.target(from: "detailRetry", direction: .left), "overview")
        XCTAssertEqual(map.target(from: "detailRetry", direction: .down), "p1")
        XCTAssertNil(map.target(from: "play", direction: .up))
    }
    func testRemovedHeroRetryAndOverviewReturnToValidAction() {
        let map = MediaDetailFocusMap(actions: ["play", "restart"], people: ["p1"], related: [], relatedRetry: nil, files: "files")
        for removed in ["retry", "overview"] {
            XCTAssertEqual(map.recoveryAfterActionChange(previousActions: ["play", "restart", removed],
                focused: removed, requested: removed, lastAction: removed), "play")
            XCTAssertEqual(map.recoveryAfterActionChange(previousActions: ["play", "restart", removed],
                focused: removed, requested: nil, lastAction: "restart"), "restart")
        }
    }
    func testActionUpdatePreservesAnotherRegionAndIgnoresStaleRequest() {
        let map = full
        for focused in ["play", "p2", "r2", "retry", "files", "unknown"] {
            XCTAssertNil(map.recoveryAfterActionChange(previousActions: ["play", "removed"],
                focused: focused, requested: "removed", lastAction: "removed"))
        }
        XCTAssertNil(map.recoveryAfterActionChange(previousActions: ["play", "restart"],
            focused: "play", requested: "play"))
    }
    func testPendingRemovedActionRecoversButUnownedUpdateDoesNot() {
        XCTAssertEqual(full.recoveryAfterActionChange(previousActions: ["play", "removed"],
            focused: nil, requested: "removed", lastAction: "restart"), "restart")
        XCTAssertNil(full.recoveryAfterActionChange(previousActions: ["play", "removed"],
            focused: nil, requested: nil))
        XCTAssertNil(full.recoveryAfterActionChange(previousActions: ["play", "removed"],
            focused: nil, requested: "unrelated"))
    }
    func testDefaultActionDiscardsRemovedMemoryAndHandlesNoActions() {
        XCTAssertEqual(full.preferredAction("restart"), "restart")
        XCTAssertEqual(full.preferredAction("removed"), "play")
        let empty = MediaDetailFocusMap(actions: [], people: [], related: [], relatedRetry: nil, files: nil)
        XCTAssertNil(empty.preferredAction("play"))
        XCTAssertNil(empty.recoveryAfterActionChange(previousActions: ["play"], focused: "play", requested: "play"))
    }
    func testFileChoicesRespectVerticalOrderAndRememberLastChoiceFromPeople() {
        let map = withChoices
        XCTAssertEqual(map.target(from: "play", direction: .down), "f1")
        XCTAssertEqual(map.target(from: "f1", direction: .down), "f2")
        XCTAssertEqual(map.target(from: "f2", direction: .down), "p1")
        XCTAssertEqual(map.target(from: "p2", direction: .up, lastFileChoice: "f2"), "f2")
        XCTAssertEqual(map.target(from: "f2", direction: .up), "f1")
        XCTAssertEqual(map.target(from: "f1", direction: .up, lastAction: "restart"), "restart")
        XCTAssertNil(map.target(from: "f1", direction: .left))
        XCTAssertNil(map.target(from: "f2", direction: .right))
    }
    func testSparseFileChoiceRegionsSkipMissingContentInBothDirections() {
        for actions in [false, true] { for choices in [false, true] { for people in [false, true] { for files in [false, true] {
            let map = MediaDetailFocusMap(actions: actions ? ["play"] : [], people: people ? ["p"] : [],
                related: [], relatedRetry: nil, files: files ? "files" : nil, fileChoices: choices ? ["f1", "f2"] : [])
            let expected = (actions ? ["play"] : []) + (choices ? ["f1", "f2"] : []) + (people ? ["p"] : []) + (files ? ["files"] : [])
            XCTAssertEqual(map.entry(), expected.first)
            for i in expected.indices {
                XCTAssertEqual(map.target(from: expected[i], direction: .down), i + 1 < expected.count ? expected[i + 1] : nil)
                XCTAssertEqual(map.target(from: expected[i], direction: .up), i > 0 ? expected[i - 1] : nil)
            }
        } } } }
    }
    func testFileChoiceMemoriesAreValidatedAndReadOnlyFilesAreNotInvented() {
        XCTAssertEqual(withChoices.target(from: "p1", direction: .up, lastFileChoice: "removed"), "f2")
        XCTAssertNil(withChoices.target(from: "readOnlyISO", direction: .down))
        XCTAssertFalse(withChoices.contains("readOnlyISO"))
        XCTAssertTrue(withChoices.contains("f2"))
        let noActions = MediaDetailFocusMap(actions: [], people: [], related: [], relatedRetry: nil, files: "files", fileChoices: ["f1", "f2"])
        XCTAssertEqual(noActions.entry(lastAction: "play", lastFileChoice: "f2"), "f2")
    }
    func testRemovedContentRepairsOnlyItsOwner() {
        let updated = MediaDetailFocusMap(actions: ["play"], people: ["p1"], related: [], relatedRetry: nil, files: "files", fileChoices: ["f1"])
        XCTAssertEqual(updated.recoveryAfterContentChange(previous: withChoices, focused: "f2", requested: "f2"), "f1")
        XCTAssertEqual(updated.recoveryAfterContentChange(previous: withChoices, focused: nil, requested: "p2"), "p1")
        for live in ["play", "p1", "f1", "files", "nativeEdit"] {
            XCTAssertNil(updated.recoveryAfterContentChange(previous: withChoices, focused: live, requested: "f2"))
        }
    }
    func testRemovedHeroFallsBackToFileChoicesWithoutInventingPlay() {
        let map = MediaDetailFocusMap(actions: [], people: [], related: [], relatedRetry: nil, files: "files", fileChoices: ["f1"])
        XCTAssertEqual(map.recoveryAfterContentChange(previous: withChoices, focused: "play", requested: "play"), "f1")
        let empty = MediaDetailFocusMap(actions: [], people: [], related: [], relatedRetry: nil, files: nil)
        XCTAssertNil(empty.recoveryAfterContentChange(previous: withChoices, focused: "f2", requested: "f2"))
        XCTAssertNil(map.recoveryAfterContentChange(previous: withChoices, focused: nil, requested: nil))
    }
    func testPersonIdentitySurvivesArtworkArrivalAndReordering() {
        let a = MediaCredit(name: "演员 A", role: "演员", imageID: nil, imageTag: nil)
        let b = MediaCredit(name: "演员 B", role: "导演", imageID: nil, imageTag: nil)
        let enrichedA = MediaCredit(name: a.name, role: a.role, imageID: "server-a", imageTag: "new-photo")
        let original = MediaDetailFocusMap.personIDs(for: [a, b])
        let updated = MediaDetailFocusMap.personIDs(for: [b, enrichedA])
        XCTAssertEqual(original[0], updated[1])
        XCTAssertEqual(original[1], updated[0])
    }
    func testPersonIdentityDisambiguatesDuplicateAndDelimiterNames() {
        let a = MediaCredit(name: "A|B", role: "C", imageID: nil, imageTag: nil)
        let b = MediaCredit(name: "A", role: "B|C", imageID: nil, imageTag: nil)
        let ids = MediaDetailFocusMap.personIDs(for: [a, b, a])
        XCTAssertEqual(Set(ids).count, 3)
        XCTAssertEqual(ids, MediaDetailFocusMap.personIDs(for: [a, b, a]))
    }
    func testReorderedPendingOwnerRestoresButLiveNativeControlKeepsFocus() {
        let reordered = MediaDetailFocusMap(actions: ["play"], people: ["p2", "p1"], related: [], relatedRetry: nil, files: "files", fileChoices: ["f2", "f1"])
        XCTAssertEqual(reordered.recoveryAfterContentChange(previous: withChoices, focused: nil, requested: "p2"), "p2")
        XCTAssertEqual(reordered.recoveryAfterContentChange(previous: withChoices, focused: nil, requested: "f2"), "f2")
        XCTAssertNil(reordered.recoveryAfterContentChange(previous: withChoices, focused: "p1", requested: "p2"))
        XCTAssertNil(reordered.recoveryAfterContentChange(previous: withChoices, focused: "nativeEdit", requested: "files"))
        XCTAssertNil(reordered.recoveryAfterContentChange(previous: withChoices, focused: nil, requested: "unknown"))
    }
    func testRetryRemovalCanReturnToFileChoicesWhenOtherRegionsAreMissing() {
        let map = MediaDetailFocusMap(actions: ["play"], people: [], related: [], relatedRetry: nil, files: nil, fileChoices: ["f1", "f2"])
        XCTAssertEqual(map.fallbackAfterRetry(lastFileChoice: "f2"), "f2")
        XCTAssertEqual(map.fallbackAfterRetry(lastFileChoice: "removed"), "f1")
        XCTAssertEqual(full.fallbackAfterRetry(lastRelated: "r2", lastFileChoice: "removed"), "r2")
    }
    func testPreUpdateOwnerOutranksNativeFallbackButNotAuxiliaryControl() {
        let map = MediaDetailFocusMap(actions: ["play"], people: ["p2", "p1"], related: [], relatedRetry: nil, files: "files", fileChoices: ["f1"])
        XCTAssertEqual(map.recoveryAfterContentChange(previous: withChoices, focused: "play", requested: "f2", previousOwner: "f2"), "f1")
        XCTAssertEqual(map.recoveryAfterContentChange(previous: withChoices, focused: "p1", requested: "p2", previousOwner: "p2"), "p2")
        XCTAssertNil(map.recoveryAfterContentChange(previous: withChoices, focused: "nativeEdit", requested: "p2", previousOwner: "p2"))
        XCTAssertNil(map.recoveryAfterContentChange(previous: withChoices, focused: "p2", requested: "p2", previousOwner: "p2"))
    }
    private var withChoices: MediaDetailFocusMap {
        .init(actions: ["play", "restart"], people: ["p1", "p2"], related: [], relatedRetry: nil,
            files: "files", fileChoices: ["f1", "f2"])
    }
    private var full: MediaDetailFocusMap {
        .init(actions: ["play", "restart"], people: ["p1", "p2"], related: ["r1", "r2"], relatedRetry: "retry", files: "files")
    }
}
