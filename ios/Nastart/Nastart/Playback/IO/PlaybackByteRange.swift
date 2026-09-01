import Foundation

struct PlaybackByteRange: Codable, Equatable, Sendable {
    var start: Int64
    var endExclusive: Int64

    init(start: Int64, endExclusive: Int64) {
        self.start = max(start, 0)
        self.endExclusive = max(endExclusive, self.start)
    }

    init(start: Int64, length: Int64) {
        self.init(start: start, endExclusive: start + max(length, 0))
    }

    var length: Int64 {
        max(endExclusive - start, 0)
    }

    var isEmpty: Bool {
        length == 0
    }

    func contains(_ offset: Int64) -> Bool {
        offset >= start && offset < endExclusive
    }

    func contains(_ range: PlaybackByteRange) -> Bool {
        range.start >= start && range.endExclusive <= endExclusive
    }

    func overlapsOrTouches(_ range: PlaybackByteRange) -> Bool {
        start <= range.endExclusive && range.start <= endExclusive
    }

    func merged(with range: PlaybackByteRange) -> PlaybackByteRange {
        PlaybackByteRange(
            start: min(start, range.start),
            endExclusive: max(endExclusive, range.endExclusive)
        )
    }
}

struct PlaybackRangeGap: Codable, Equatable, Sendable {
    var range: PlaybackByteRange
    var reason: String

    init(range: PlaybackByteRange, reason: String = "cacheMiss") {
        self.range = range
        self.reason = reason
    }
}
