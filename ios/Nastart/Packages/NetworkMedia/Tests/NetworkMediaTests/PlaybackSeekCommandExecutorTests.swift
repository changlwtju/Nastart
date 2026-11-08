import XCTest
@testable import NetworkMedia

final class PlaybackSeekCommandExecutorTests: XCTestCase {
    @MainActor func testPauseDuringSeekWinsOverDispatchTimePlay() async {
        let driver = DeferredCommandDriver()
        driver.wantsPlayback = true
        driver.submit(115)
        driver.wantsPlayback = false
        driver.takeCompletion()(true)
        await drainCallbacks()
        XCTAssertEqual(driver.events, ["dispatch", "complete:true", "pause", "sample:true"])
        XCTAssertFalse(driver.actualPlaying)
        XCTAssertNil(driver.state.pendingTarget)
    }

    @MainActor func testPlayAndRateChangesDuringSeekAreReadAtCompletion() async {
        let driver = DeferredCommandDriver()
        driver.submit(115)
        driver.wantsPlayback = true; driver.rate = 1.5
        driver.takeCompletion()(true)
        await drainCallbacks()
        XCTAssertTrue(driver.actualPlaying)
        XCTAssertEqual(driver.appliedRate, 1.5)
        XCTAssertEqual(driver.events, ["dispatch", "complete:true", "play", "sample:true"])
    }

    @MainActor func testOldAndRepeatedCallbacksCannotRestoreIntentOrClearNewTarget() async {
        let driver = DeferredCommandDriver()
        driver.submit(115)
        let old = driver.takeCompletion()
        driver.submit(130)
        let latest = driver.takeCompletion()
        old(true)
        await drainCallbacks()
        XCTAssertEqual(driver.events, ["dispatch", "dispatch"])
        XCTAssertEqual(driver.state.pendingTarget, 130)
        latest(true)
        await drainCallbacks()
        let finished = driver.events
        latest(true)
        await drainCallbacks()
        XCTAssertEqual(driver.events, finished)
    }

    @MainActor func testExitInvalidatesCallbackBeforeEveryCompletionSideEffect() async {
        let driver = DeferredCommandDriver()
        driver.submit(115)
        let completion = driver.takeCompletion()
        driver.state.invalidate(); driver.attached = false
        completion(true)
        await drainCallbacks()
        XCTAssertEqual(driver.events, ["dispatch"])
        XCTAssertNil(driver.state.pendingTarget)
    }

    @MainActor func testFailureClearsPendingStateWithoutInventingAutoplay() async {
        let driver = DeferredCommandDriver()
        driver.wantsPlayback = true
        driver.submit(115)
        driver.takeCompletion()(false)
        await drainCallbacks()
        XCTAssertEqual(driver.events, ["dispatch", "complete:false", "sample:false"])
        XCTAssertFalse(driver.actualPlaying)
        XCTAssertNil(driver.state.pendingTarget)
    }

    @MainActor func testInvalidOrDetachedRequestDoesNotReachNativeDriver() {
        var calls = 0
        for target in [Double.nan, .infinity, -1] {
            PlaybackSeekCommandExecutor.submit(target: target, isCurrent: { true },
                seek: { _, _ in calls += 1 }, restoreIntent: { XCTFail("invalid request") })
        }
        PlaybackSeekCommandExecutor.submit(target: 100, isCurrent: { false },
            seek: { _, _ in calls += 1 }, restoreIntent: { XCTFail("detached request") })
        XCTAssertEqual(calls, 0)
    }

    @MainActor private func drainCallbacks() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { DispatchQueue.main.async { continuation.resume() } }
        }
    }
}

@MainActor private final class DeferredCommandDriver {
    var state = PlaybackSeekState()
    var attached = true
    var wantsPlayback = false
    var actualPlaying = false
    var rate: Float = 1
    var appliedRate: Float = 1
    var events: [String] = []
    private var pending: [(Bool) -> Void] = []
    func takeCompletion() -> (Bool) -> Void { pending.removeFirst() }
    func submit(_ target: Double) {
        guard let request = state.begin(absolute: target, duration: 600) else { return }
        PlaybackSeekCommandExecutor.submit(target: request.target,
            isCurrent: { [weak self] in
                self.map { $0.attached && $0.state.owns(generation: request.generation) } ?? false
            }, seek: { [weak self] _, completion in
                self?.events.append("dispatch"); self?.pending.append(completion)
            }, willComplete: { [weak self] completed in
                self?.state.complete(generation: request.generation)
                self?.events.append("complete:\(completed)")
            }, restoreIntent: { [weak self] in
                guard let self else { return }
                self.actualPlaying = self.wantsPlayback
                self.appliedRate = self.rate
                self.events.append(self.wantsPlayback ? "play" : "pause")
            }, didComplete: { [weak self] completed in self?.events.append("sample:\(completed)") })
    }
}
