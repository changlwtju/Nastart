import Foundation

struct PlaybackReadResult: Sendable {
    var range: PlaybackByteRange
    var data: Data
    var source: PlaybackReadSource

    init(range: PlaybackByteRange, data: Data, source: PlaybackReadSource) {
        self.range = range
        self.data = data
        self.source = source
    }
}

enum PlaybackReadSource: String, Codable, Sendable {
    case cache
    case network
    case localFile
    case generated
}

protocol PlaybackIOContext: AnyObject {
    var route: PlaybackRoute { get }

    func open() async throws
    func read(range: PlaybackByteRange) async throws -> PlaybackReadResult
    func seek(to offset: Int64) async throws
    func cachedRanges() async -> [PlaybackByteRange]
    func isRangeCached(_ range: PlaybackByteRange) async -> Bool
    func isRangeUncached(_ range: PlaybackByteRange) async -> Bool
    func preload(range: PlaybackByteRange, budget: Int64) async throws
    func invalidate(reason: String) async
    func close() async
}

final class ObservingPlaybackIOContext: PlaybackIOContext {
    let route: PlaybackRoute
    private let cacheStore: RangeCacheStore

    init(route: PlaybackRoute, cacheStore: RangeCacheStore = RangeCacheStore()) {
        self.route = route
        self.cacheStore = cacheStore
    }

    func open() async throws {}

    func read(range: PlaybackByteRange) async throws -> PlaybackReadResult {
        await cacheStore.recordRead(range)
        return PlaybackReadResult(range: range, data: Data(), source: .network)
    }

    func seek(to offset: Int64) async throws {
        _ = max(offset, 0)
    }

    func cachedRanges() async -> [PlaybackByteRange] {
        await cacheStore.cachedRanges
    }

    func isRangeCached(_ range: PlaybackByteRange) async -> Bool {
        await cacheStore.isCached(range)
    }

    func isRangeUncached(_ range: PlaybackByteRange) async -> Bool {
        await cacheStore.isUncached(range)
    }

    func preload(range: PlaybackByteRange, budget: Int64) async throws {
        let length = min(range.length, max(budget, 0))
        guard length > 0 else { return }
        await cacheStore.markCached(PlaybackByteRange(start: range.start, length: length))
    }

    func invalidate(reason: String) async {
        _ = reason
        await cacheStore.reset()
    }

    func close() async {}
}
