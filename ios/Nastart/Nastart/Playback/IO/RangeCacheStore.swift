import Foundation

actor RangeCacheStore {
    private(set) var cachedRanges: [PlaybackByteRange] = []
    private(set) var cachedBytes: Int64 = 0
    private(set) var cacheHitBytes: Int64 = 0
    private(set) var cacheMissBytes: Int64 = 0

    func markCached(_ range: PlaybackByteRange) {
        guard !range.isEmpty else { return }
        cachedRanges.append(range)
        cachedRanges.sort { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.endExclusive < rhs.endExclusive
            }
            return lhs.start < rhs.start
        }

        var merged: [PlaybackByteRange] = []
        for candidate in cachedRanges {
            guard let last = merged.last else {
                merged.append(candidate)
                continue
            }
            if last.overlapsOrTouches(candidate) {
                merged[merged.count - 1] = last.merged(with: candidate)
            } else {
                merged.append(candidate)
            }
        }
        cachedRanges = merged
        cachedBytes = merged.reduce(Int64(0)) { $0 + $1.length }
    }

    func isCached(_ range: PlaybackByteRange) -> Bool {
        guard !range.isEmpty else { return true }
        return cachedRanges.contains { $0.contains(range) }
    }

    func isUncached(_ range: PlaybackByteRange) -> Bool {
        !isCached(range)
    }

    func gaps(in range: PlaybackByteRange) -> [PlaybackRangeGap] {
        guard !range.isEmpty else { return [] }
        var cursor = range.start
        var gaps: [PlaybackRangeGap] = []

        for cached in cachedRanges where cached.endExclusive > range.start && cached.start < range.endExclusive {
            if cached.start > cursor {
                gaps.append(PlaybackRangeGap(
                    range: PlaybackByteRange(
                        start: cursor,
                        endExclusive: min(cached.start, range.endExclusive)
                    )
                ))
            }
            cursor = max(cursor, cached.endExclusive)
            if cursor >= range.endExclusive {
                break
            }
        }

        if cursor < range.endExclusive {
            gaps.append(PlaybackRangeGap(
                range: PlaybackByteRange(start: cursor, endExclusive: range.endExclusive)
            ))
        }
        return gaps.filter { !$0.range.isEmpty }
    }

    func recordRead(_ range: PlaybackByteRange) {
        guard !range.isEmpty else { return }
        let missed = gaps(in: range).reduce(Int64(0)) { $0 + $1.range.length }
        let hit = max(range.length - missed, 0)
        cacheHitBytes += hit
        cacheMissBytes += missed
    }

    func reset() {
        cachedRanges = []
        cachedBytes = 0
        cacheHitBytes = 0
        cacheMissBytes = 0
    }
}
