import XCTest
@testable import NetworkMedia

final class PlaybackPreparationGateTests: XCTestCase {
    @MainActor func testConcurrentEntryMakesOneRequestAndDeliversOnce() async {
        let host = PreparationHost(), source = SuspendedPlaybackSource()
        let first = Task { await host.prepare(source) }
        await source.waitUntilRequested()
        await host.prepare(source)
        XCTAssertEqual(host.requestCount, 1)
        await source.finish(.success(42)); await first.value
        await host.prepare(source)
        XCTAssertEqual(host.delivered, [42])
        XCTAssertEqual(host.requestCount, 1)
        XCTAssertTrue(host.discarded.isEmpty)
    }

    @MainActor func testCloseRejectsLateSuccessEvenWhenSourceIgnoresCancellation() async {
        let host = PreparationHost(), source = SuspendedPlaybackSource()
        let pending = Task { await host.prepare(source) }
        await source.waitUntilRequested()
        host.close(); host.close()
        await source.finish(.success(7)); await pending.value
        await host.prepare(source)
        XCTAssertTrue(host.delivered.isEmpty)
        XCTAssertEqual(host.discarded, [7])
        XCTAssertEqual(host.requestCount, 1)
    }

    @MainActor func testCancelledAttemptDiscardsItsResultAndCanRetry() async {
        let host = PreparationHost(), firstSource = SuspendedPlaybackSource()
        let pending = Task { await host.prepare(firstSource) }
        await firstSource.waitUntilRequested(); pending.cancel()
        await firstSource.finish(.success(1)); await pending.value
        let retrySource = SuspendedPlaybackSource()
        let retry = Task { await host.prepare(retrySource) }
        await retrySource.waitUntilRequested()
        await retrySource.finish(.success(2)); await retry.value
        XCTAssertEqual(host.discarded, [1])
        XCTAssertEqual(host.delivered, [2])
        XCTAssertEqual(host.requestCount, 2)
    }

    @MainActor func testFailureCanRetryButCloseRemainsTerminal() async {
        let host = PreparationHost(), source = SuspendedPlaybackSource()
        let pending = Task { await host.prepare(source) }
        await source.waitUntilRequested()
        await source.finish(.failure(URLError(.cannotConnectToHost))); await pending.value
        host.close()
        await host.prepare(source)
        XCTAssertEqual(host.requestCount, 1)
        XCTAssertTrue(host.delivered.isEmpty)
        XCTAssertTrue(host.discarded.isEmpty)
        XCTAssertEqual(host.failures, 1)
    }

    func testStaleAndForeignTicketsCannotAcceptOrRevokeCurrentAttempt() throws {
        var gate = PlaybackPreparationGate(), other = PlaybackPreparationGate()
        let failed = try XCTUnwrap(gate.begin())
        XCTAssertTrue(gate.fail(failed))
        let current = try XCTUnwrap(gate.begin()), foreign = try XCTUnwrap(other.begin())
        XCTAssertFalse(gate.commit(failed)); XCTAssertFalse(gate.fail(failed))
        XCTAssertFalse(gate.commit(foreign)); XCTAssertFalse(gate.fail(foreign))
        XCTAssertTrue(gate.isPending(current)); XCTAssertTrue(gate.commit(current))
        XCTAssertFalse(gate.fail(current)); XCTAssertNil(gate.begin())
    }
}

/// The source intentionally does not react to Task cancellation. A host must
/// reject and dispose a late result rather than relying on cooperative I/O.
private actor SuspendedPlaybackSource {
    private var continuation: CheckedContinuation<Int, Error>?
    private var requested = false
    private var waiter: CheckedContinuation<Void, Never>?
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

@MainActor private final class PreparationHost {
    private var gate = PlaybackPreparationGate()
    private(set) var requestCount = 0, failures = 0
    private(set) var delivered: [Int] = [], discarded: [Int] = []
    func prepare(_ source: SuspendedPlaybackSource) async {
        guard let ticket = gate.begin() else { return }
        requestCount += 1
        do {
            let value = try await source.read()
            guard !Task.isCancelled, gate.commit(ticket) else {
                gate.fail(ticket); discarded.append(value); return
            }
            delivered.append(value)
        } catch { if gate.fail(ticket) { failures += 1 } }
    }
    func close() { gate.close() }
}
