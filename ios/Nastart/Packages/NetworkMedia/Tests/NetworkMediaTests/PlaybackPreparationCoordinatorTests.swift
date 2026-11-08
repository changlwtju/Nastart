import XCTest
@testable import NetworkMedia

final class PlaybackPreparationCoordinatorTests: XCTestCase {
    @MainActor func testConcurrentPreparationRequestsOnceAndCommittedValueCannotRepeat() async throws {
        let coordinator = PlaybackPreparationCoordinator<Int>(), source = DeferredPreparation()
        var requested = 0, discarded: [Int] = []
        let pending = Task {
            try await coordinator.prepare(operation: { _ in
                requested += 1
                return try await source.read()
            }, discard: { discarded.append($0) })
        }
        await source.waitUntilRequested()
        let duplicate = try await coordinator.prepare(operation: { _ in requested += 1; return 2 }, discard: { discarded.append($0) })
        XCTAssertNil(duplicate)
        await source.finish(.success(1))
        let delivered = try await pending.value
        XCTAssertEqual(delivered, 1)
        let repeated = try await coordinator.prepare(operation: { _ in requested += 1; return 3 }, discard: { discarded.append($0) })
        XCTAssertNil(repeated)
        XCTAssertEqual(requested, 1)
        XCTAssertTrue(discarded.isEmpty)
    }

    @MainActor func testCloseDisposesLateValueEvenIfSourceIgnoresCancellation() async throws {
        let coordinator = PlaybackPreparationCoordinator<Int>(), source = DeferredPreparation()
        var discarded: [Int] = []
        let pending = Task { try await coordinator.prepare(operation: { _ in try await source.read() }, discard: { discarded.append($0) }) }
        await source.waitUntilRequested()
        coordinator.close(); coordinator.close()
        await source.finish(.success(8))
        let delivered = try await pending.value
        XCTAssertNil(delivered)
        XCTAssertEqual(discarded, [8])
        let closed = try await coordinator.prepare(operation: { _ in XCTFail("closed source requested"); return 9 }, discard: { _ in XCTFail("unexpected discard") })
        XCTAssertNil(closed)
    }

    @MainActor func testCancelledLateValueIsDisposedAndRetryUsesIndependentResource() async throws {
        let coordinator = PlaybackPreparationCoordinator<Int>(), source = DeferredPreparation(), cleanup = DeferredPreparation()
        var discarded: [Int] = []
        let pending = Task { try await coordinator.prepare(operation: { _ in try await source.read() }, discard: { value in
            discarded.append(value)
            _ = try? await cleanup.read()
        }) }
        await source.waitUntilRequested(); pending.cancel()
        await source.finish(.success(11)); await cleanup.waitUntilRequested()
        let retry = try await coordinator.prepare(operation: { _ in 12 }, discard: { _ in XCTFail("new resource discarded") })
        XCTAssertEqual(retry, 12)
        await cleanup.finish(.success(0))
        let delivered = try await pending.value
        XCTAssertNil(delivered)
        XCTAssertEqual(discarded, [11])
    }

    @MainActor func testCheckCurrentPreventsAllocationAfterClosedLookup() async throws {
        let coordinator = PlaybackPreparationCoordinator<Int>(), lookup = DeferredPreparation()
        var allocated = false
        let pending = Task { try await coordinator.prepare(operation: { checkCurrent in
            _ = try await lookup.read()
            try checkCurrent()
            allocated = true
            return 1
        }, discard: { _ in XCTFail("nothing allocated") }) }
        await lookup.waitUntilRequested(); coordinator.close()
        await lookup.finish(.success(0))
        let delivered = try await pending.value
        XCTAssertNil(delivered)
        XCTAssertFalse(allocated)
    }

    @MainActor func testCancelledCallerAwaitsUncancelledCleanup() async throws {
        let coordinator = PlaybackPreparationCoordinator<Int>(), source = DeferredPreparation(), cleanup = DeferredPreparation()
        var completedCleanup = false
        let pending = Task { try await coordinator.prepare(operation: { _ in try await source.read() }, discard: { _ in
            XCTAssertFalse(Task.isCancelled, "release must not inherit the caller's cancellation")
            _ = try? await cleanup.read()
            completedCleanup = true
        }) }
        await source.waitUntilRequested(); pending.cancel()
        await source.finish(.success(1)); await cleanup.waitUntilRequested()
        XCTAssertFalse(completedCleanup)
        await cleanup.finish(.success(0))
        let delivered = try await pending.value
        XCTAssertNil(delivered)
        XCTAssertTrue(completedCleanup, "preparation must not finish before owned cleanup")
    }

    @MainActor func testCurrentFailureThrowsAndCanRetryButLateFailureIsSuppressed() async throws {
        let coordinator = PlaybackPreparationCoordinator<Int>()
        do {
            _ = try await coordinator.prepare(operation: { _ in throw URLError(.cannotConnectToHost) }, discard: { _ in XCTFail("no result") })
            XCTFail("current error was suppressed")
        } catch { XCTAssertEqual((error as? URLError)?.code, .cannotConnectToHost) }
        let source = DeferredPreparation()
        let pending = Task { try await coordinator.prepare(operation: { _ in try await source.read() }, discard: { _ in XCTFail("no result") }) }
        await source.waitUntilRequested(); coordinator.close()
        await source.finish(.failure(URLError(.timedOut)))
        let delivered = try await pending.value
        XCTAssertNil(delivered)
    }

    @MainActor func testCancellationBeforeOperationMakesNoSourceRequest() async throws {
        let coordinator = PlaybackPreparationCoordinator<Int>(), barrier = DeferredPreparation()
        let pending = Task {
            _ = try await barrier.read()
            return try await coordinator.prepare(operation: { _ in XCTFail("cancelled source requested"); return 1 }, discard: { _ in XCTFail("no result") })
        }
        await barrier.waitUntilRequested(); pending.cancel(); await barrier.finish(.success(0))
        let delivered = try await pending.value
        XCTAssertNil(delivered)
        let retry = try await coordinator.prepare(operation: { _ in 2 }, discard: { _ in XCTFail("no rejection") })
        XCTAssertEqual(retry, 2)
    }
}

/// Deliberately non-cooperative to exercise the production coordinator's late
/// result handling without relying on cancellation of a fake network request.
private actor DeferredPreparation {
    private var continuation: CheckedContinuation<Int, Error>?
    private var waiter: CheckedContinuation<Void, Never>?
    private var requested = false
    func read() async throws -> Int {
        try await withCheckedThrowingContinuation {
            continuation = $0; requested = true
            waiter?.resume(); waiter = nil
        }
    }
    func waitUntilRequested() async {
        if requested { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func finish(_ result: Result<Int, Error>) {
        continuation?.resume(with: result); continuation = nil
    }
}
