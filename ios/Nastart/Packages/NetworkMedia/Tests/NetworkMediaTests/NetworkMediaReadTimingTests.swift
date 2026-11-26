import XCTest
@testable import NetworkMedia

final class NetworkMediaReadTimingTests: XCTestCase {
    private final class Timings: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: (wait: TimeInterval, work: TimeInterval)] = [:]
        func set(_ name: String, wait: TimeInterval, work: TimeInterval) {
            lock.lock(); values[name] = (wait, work); lock.unlock()
        }
        func get(_ name: String) -> (wait: TimeInterval, work: TimeInterval)? {
            lock.lock(); defer { lock.unlock() }
            return values[name]
        }
    }

    func testRecorderAddsReadsAndHandsThemOverOnce() {
        let recorder = NetworkMediaReadTimingRecorder()
        XCTAssertEqual(recorder.take(), .init())
        recorder.record(queueWait: 0.090, readTime: 0.050)
        recorder.record(queueWait: 0, readTime: 0.095)
        // Unusable clock readings are not timing.
        recorder.record(queueWait: -1, readTime: 0.1)
        recorder.record(queueWait: 0.1, readTime: .nan)
        recorder.record(queueWait: .infinity, readTime: 0.1)
        let taken = recorder.take()
        XCTAssertEqual(taken.reads, 2)
        XCTAssertEqual(taken.queueWait, 0.090, accuracy: 1e-9)
        XCTAssertEqual(taken.readTime, 0.145, accuracy: 1e-9)
        XCTAssertEqual(taken.maxQueueWait, 0.090, accuracy: 1e-9)
        XCTAssertEqual(taken.maxReadTime, 0.095, accuracy: 1e-9)
        // Each read is handed to one chunk only.
        XCTAssertEqual(recorder.take(), .init())
    }

    func testSerialWorkerTellsQueueWaitFromItsOwnDuration() throws {
        let queue = DispatchQueue(label: "NetworkMediaReadTimingTests")
        let done = expectation(description: "both finished")
        done.expectedFulfillmentCount = 2
        let timings = Timings()
        func run(_ name: String, sleep seconds: TimeInterval) {
            SMBWorker.timed(on: queue, timing: { timings.set(name, wait: $0, work: $1) }, {
                Thread.sleep(forTimeInterval: seconds)
                return name
            }, completion: { result in
                XCTAssertEqual(try? result.get(), name)
                done.fulfill()
            })
        }
        // The second request arrives while the first still holds the queue,
        // as a tail read does behind an unfinished body read.
        run("body", sleep: 0.30)
        run("tail", sleep: 0.05)
        wait(for: [done], timeout: 5)
        let body = try XCTUnwrap(timings.get("body")), tail = try XCTUnwrap(timings.get("tail"))
        XCTAssertLessThan(body.wait, 0.15)
        XCTAssertGreaterThanOrEqual(body.work, 0.29)
        XCTAssertGreaterThanOrEqual(tail.wait, 0.25, "the tail waited for the body read")
        XCTAssertGreaterThanOrEqual(tail.work, 0.04)
        XCTAssertLessThan(tail.work, 0.25, "its own read was short")
    }

    func testFailedWorkIsStillTimedAndAReaderWithoutTimingReportsNothing() async throws {
        struct Failure: Error {}
        let queue = DispatchQueue(label: "NetworkMediaReadTimingTests.failure")
        let finished = expectation(description: "failed")
        let recorder = NetworkMediaReadTimingRecorder()
        SMBWorker.timed(on: queue, timing: { recorder.record(queueWait: $0, readTime: $1) }, {
            () throws -> Int in throw Failure()
        }, completion: { result in
            if case .success = result { XCTFail("the work threw, so its result is a failure") }
            finished.fulfill()
        })
        await fulfillment(of: [finished], timeout: 5)
        XCTAssertEqual(recorder.take().reads, 1)

        // A reader that only implements the plain stream is given the recorder
        // and leaves it empty.
        struct Plain: NetworkMediaByteReader {
            let byteCount: Int64 = 4
            let fileName = "fixture.mkv"
            func stream(offset: Int64, count: Int64, deliver: (Data) async throws -> Void) async throws {
                try await deliver(Data([1, 2, 3, 4]))
            }
        }
        var delivered = Data()
        try await Plain().stream(offset: 0, count: 4, timing: recorder) { delivered.append($0) }
        XCTAssertEqual(delivered, Data([1, 2, 3, 4]))
        XCTAssertEqual(recorder.take(), .init())
    }
}
