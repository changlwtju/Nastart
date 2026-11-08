#if DEBUG
import Foundation

/// Read only diagnostics. A local codec-flush token is distinct from an App seek generation.
public protocol KSSeekFrameCapacity {
    func seekFrameDiagnosticSnapshot(now: TimeInterval) -> [String: String]
}

final class KSSeekFrameDiagnostics {
    private let lock = NSLock()
    private var revision = 0
    private var epoch = 0
    private var target: TimeInterval?
    private var requestedAt = TimeInterval(0)
    private var flushedAt = TimeInterval(0)
    private var active: Int?
    private var callbacks = 0, discarded = 0, accepted = 0, pushReturned = 0
    private var invalidIntervals = 0
    private var firstCallback: TimeInterval?, firstAccepted: TimeInterval?, firstPushReturned: TimeInterval?
    private var lastStart: TimeInterval?, lastEnd: TimeInterval?
    private var timebaseNum: Int32?, timebaseDen: Int32?
    private var origin: TimeInterval?

    func willSeek(target: TimeInterval, now: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        revision &+= 1
        active = nil
        self.target = target.isFinite && target >= 0 && now.isFinite ? target : nil
        requestedAt = now
    }

    func prepareFlush() -> Int? {
        lock.lock(); defer { lock.unlock() }
        return target == nil ? nil : revision
    }

    func didFlush(revision: Int?, now: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        guard let revision, revision == self.revision, target != nil,
              now.isFinite, now >= requestedAt, now - requestedAt <= 10 else { return }
        epoch &+= 1
        active = epoch
        flushedAt = now
        callbacks = 0; discarded = 0; accepted = 0; pushReturned = 0; invalidIntervals = 0
        firstCallback = nil; firstAccepted = nil; firstPushReturned = nil
        lastStart = nil; lastEnd = nil; timebaseNum = nil; timebaseDen = nil; origin = nil
    }

    private func valid(_ token: Int?, now: TimeInterval) -> Bool {
        token != nil && token == active && now.isFinite && now >= flushedAt && now - requestedAt <= 10
    }

    func token(now: TimeInterval) -> Int? {
        lock.lock(); defer { lock.unlock() }
        return valid(active, now: now) ? active : nil
    }

    /// These frames have completed conversion but have not yet entered the render queue.
    func frame(token: Int?, discarded: Bool, start: TimeInterval?, end: TimeInterval?,
               timebaseNum: Int32, timebaseDen: Int32, origin: TimeInterval, now: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        guard valid(token, now: now), callbacks < 4096 else { return }
        callbacks += 1
        if firstCallback == nil { firstCallback = now }
        if discarded { self.discarded += 1 } else {
            accepted += 1
            if firstAccepted == nil { firstAccepted = now }
        }
        guard let start, let end, start.isFinite, end.isFinite, end > start,
              timebaseNum > 0, timebaseDen > 0, origin.isFinite else {
            invalidIntervals += 1
            return
        }
        self.timebaseNum = timebaseNum; self.timebaseDen = timebaseDen; self.origin = origin
        if !discarded { lastStart = start; lastEnd = end }
    }

    /// A full blocking queue inserts before push returns. This is not an admission timestamp.
    func didReturnFromPush(token: Int?, now: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        guard valid(token, now: now), pushReturned < 4096 else { return }
        pushReturned += 1
        if firstPushReturned == nil { firstPushReturned = now }
    }

    func snapshot(now: TimeInterval) -> (token: Int, fields: [String: String])? {
        lock.lock(); defer { lock.unlock() }
        guard valid(active, now: now), let active, let target else { return nil }
        var f = ["videoSeekEpoch": String(active), "videoSeekTargetSeconds": String(target),
                 "videoSeekCallbacks": String(callbacks), "videoSeekDiscardedBeforeTarget": String(discarded),
                 "videoSeekAcceptedBeforePush": String(accepted), "videoSeekPushReturned": String(pushReturned),
                 "videoSeekInvalidIntervals": String(invalidIntervals),
                 "videoSeekCountsCapped": String(callbacks >= 4096),
                 "videoSeekSinceFlushMs": String((now - flushedAt) * 1000)]
        for (name, value) in [("videoSeekFirstCallbackMs", firstCallback),
                              ("videoSeekFirstAcceptedMs", firstAccepted),
                              ("videoSeekFirstPushReturnedMs", firstPushReturned)] {
            if let value { f[name] = String((value - flushedAt) * 1000) }
        }
        if let lastStart { f["videoSeekLastAcceptedStartSeconds"] = String(lastStart) }
        if let lastEnd { f["videoSeekLastAcceptedEndSeconds"] = String(lastEnd) }
        if let timebaseNum { f["videoSeekTimebaseNum"] = String(timebaseNum) }
        if let timebaseDen { f["videoSeekTimebaseDen"] = String(timebaseDen) }
        if let origin { f["videoSeekTimestampOriginSeconds"] = String(origin) }
        return (active, f)
    }

    /// Union of measured positive intervals, never duration inferred from FPS.
    static func coverage(_ intervals: [(start: TimeInterval, end: TimeInterval)])
        -> (span: TimeInterval, union: TimeInterval, gaps: TimeInterval)? {
        guard !intervals.isEmpty,
              intervals.allSatisfy({ $0.start.isFinite && $0.end.isFinite && $0.end > $0.start }) else { return nil }
        let sorted = intervals.sorted { $0.start < $1.start }
        var end = sorted[0].end, union = sorted[0].end - sorted[0].start
        for item in sorted.dropFirst() {
            if item.end > end { union += item.end - max(end, item.start); end = item.end }
        }
        let span = end - sorted[0].start
        return (span, union, max(0, span - union))
    }
}
#endif
