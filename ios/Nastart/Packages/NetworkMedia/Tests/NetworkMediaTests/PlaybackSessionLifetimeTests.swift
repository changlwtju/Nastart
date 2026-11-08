import XCTest
@testable import NetworkMedia

final class PlaybackSessionLifetimeTests: XCTestCase {
    @MainActor func testDuplicateInitialAndRepeatedExitReleaseOnlyInstalledOwnerOnce() async throws {
        var released: [Int] = []
        let lifetime = PlaybackSessionLifetime<Int> { released.append($0) }
        let initial = try XCTUnwrap(lifetime.beginInitial())
        XCTAssertNil(lifetime.beginInitial())
        XCTAssertTrue(lifetime.commit(1, for: initial))
        XCTAssertNil(lifetime.beginInitial())
        XCTAssertTrue(lifetime.isCurrent(initial))
        lifetime.end(); lifetime.end(); lifetime.close()
        await lifetime.waitForCleanup()
        XCTAssertEqual(released, [1])
        XCTAssertNil(lifetime.current)
        XCTAssertFalse(lifetime.isCurrent(initial))
        XCTAssertNil(lifetime.beginInitial())
    }

    @MainActor func testReplacementPreservesOldOwnerAndLatestCandidateWins() async throws {
        var released: [Int] = []
        let lifetime = PlaybackSessionLifetime<Int> { released.append($0) }
        let initial = try XCTUnwrap(lifetime.beginInitial())
        XCTAssertTrue(lifetime.commit(1, for: initial))
        let stale = try XCTUnwrap(lifetime.beginReplacement())
        let latest = try XCTUnwrap(lifetime.beginReplacement())
        XCTAssertEqual(lifetime.current, 1, "preparing must not release the mounted renderer's source")
        XCTAssertFalse(lifetime.isCurrent(initial))
        XCTAssertFalse(lifetime.commit(2, for: stale))
        XCTAssertFalse(lifetime.fail(stale), "a stale error cannot clear the new request")
        XCTAssertTrue(lifetime.hasPendingOperation)
        await lifetime.discard(2)
        XCTAssertTrue(lifetime.commit(3, for: latest))
        await lifetime.waitForCleanup()
        XCTAssertEqual(released, [2, 1])
        XCTAssertEqual(lifetime.current, 3)
        lifetime.close(); await lifetime.waitForCleanup()
        XCTAssertEqual(released, [2, 1, 3])
    }

    @MainActor func testFailureKeepsActiveRouteAndEndCanStartAnotherItem() async throws {
        var released: [Int] = []
        let lifetime = PlaybackSessionLifetime<Int> { released.append($0) }
        let initial = try XCTUnwrap(lifetime.beginInitial())
        XCTAssertTrue(lifetime.commit(1, for: initial))
        let replacement = try XCTUnwrap(lifetime.beginReplacement())
        XCTAssertTrue(lifetime.fail(replacement))
        XCTAssertFalse(lifetime.fail(replacement))
        XCTAssertEqual(lifetime.current, 1)
        XCTAssertTrue(lifetime.isCurrent(initial))
        lifetime.end()
        let next = try XCTUnwrap(lifetime.beginInitial())
        XCTAssertTrue(lifetime.commit(2, for: next))
        lifetime.close(); await lifetime.waitForCleanup()
        XCTAssertEqual(released, [1, 2])
    }

    @MainActor func testRetirementBarrierPrecedesReleaseAndNextCleanup() async throws {
        let barrier = LifetimeBarrier()
        var events: [String] = []
        let lifetime = PlaybackSessionLifetime<Int> { events.append("release\($0)") }
        let first = try XCTUnwrap(lifetime.beginInitial())
        XCTAssertTrue(lifetime.commit(1, for: first))
        let next = try XCTUnwrap(lifetime.beginReplacement())
        XCTAssertTrue(lifetime.commit(2, for: next, retiring: { old in
            events.append("stop\(old)")
            await barrier.wait()
            events.append("reported\(old)")
        }))
        await barrier.waitUntilEntered()
        lifetime.close()
        XCTAssertEqual(events, ["stop1"])
        await barrier.resume()
        await lifetime.waitForCleanup()
        XCTAssertEqual(events, ["stop1", "reported1", "release1", "release2"])
    }

    @MainActor func testCancelledLateDeliveryCannotInstallAndAwaitsUncancelledCleanup() async throws {
        let loader = LifetimeBarrier(), cleanup = LifetimeBarrier()
        var released: [Int] = []
        let lifetime = PlaybackSessionLifetime<Int> { resource in
            XCTAssertFalse(Task.isCancelled)
            await cleanup.wait()
            released.append(resource)
        }
        let ticket = try XCTUnwrap(lifetime.beginInitial())
        let pending = Task {
            await loader.wait() // Simulates a loader that ignores cancellation.
            guard lifetime.commit(1, for: ticket) else {
                await lifetime.discard(1)
                return false
            }
            return true
        }
        await loader.waitUntilEntered()
        pending.cancel(); lifetime.close(); await loader.resume()
        await cleanup.waitUntilEntered()
        XCTAssertNil(lifetime.current)
        XCTAssertTrue(released.isEmpty)
        await cleanup.resume()
        let installed = await pending.value
        XCTAssertFalse(installed)
        XCTAssertEqual(released, [1])
    }

    @MainActor func testCloseRejectsLateErrorAndLateCommitWithoutReopening() async throws {
        var released: [Int] = []
        let lifetime = PlaybackSessionLifetime<Int> { released.append($0) }
        let ticket = try XCTUnwrap(lifetime.beginInitial())
        lifetime.close()
        XCTAssertFalse(lifetime.fail(ticket))
        XCTAssertFalse(lifetime.commit(1, for: ticket))
        await lifetime.discard(1)
        XCTAssertEqual(released, [1])
        XCTAssertNil(lifetime.beginReplacement())
    }
}

private actor LifetimeBarrier {
    private var continuation: CheckedContinuation<Void, Never>?
    private var entered: CheckedContinuation<Void, Never>?
    private var started = false
    func wait() async {
        await withCheckedContinuation {
            continuation = $0; started = true
            entered?.resume(); entered = nil
        }
    }
    func waitUntilEntered() async {
        if started { return }
        await withCheckedContinuation { entered = $0 }
    }
    func resume() { continuation?.resume(); continuation = nil }
}
