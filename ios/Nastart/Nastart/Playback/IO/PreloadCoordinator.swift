import Foundation

enum PlaybackPreloadReason: String, Codable, Sendable {
    case startup
    case seekTarget
    case nextItem
    case recovery
}

struct PlaybackPreloadRequest: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var planID: UUID
    var routeID: UUID
    var range: PlaybackByteRange
    var budgetBytes: Int64
    var reason: PlaybackPreloadReason

    init(
        id: UUID = UUID(),
        planID: UUID,
        routeID: UUID,
        range: PlaybackByteRange,
        budgetBytes: Int64,
        reason: PlaybackPreloadReason
    ) {
        self.id = id
        self.planID = planID
        self.routeID = routeID
        self.range = range
        self.budgetBytes = max(budgetBytes, 0)
        self.reason = reason
    }
}

actor PreloadCoordinator {
    private(set) var activeRequests: [PlaybackPreloadRequest] = []
    private(set) var completedRequests: [PlaybackPreloadRequest] = []

    @discardableResult
    func schedule(_ request: PlaybackPreloadRequest, ioContext: PlaybackIOContext) async throws -> Int64 {
        try Task.checkCancellation()
        let length = min(request.range.length, request.budgetBytes)
        guard length > 0 else { return 0 }
        let boundedRange = PlaybackByteRange(start: request.range.start, length: length)
        activeRequests.append(request)
        defer { activeRequests.removeAll { $0.id == request.id } }
        try await ioContext.preload(range: boundedRange, budget: length)
        try Task.checkCancellation()
        guard await ioContext.isRangeCached(boundedRange) else { return 0 }
        completedRequests.append(request)
        return length
    }

    func cancel(planID: UUID, reason: String) {
        _ = reason
        activeRequests.removeAll { $0.planID == planID }
    }

    func reset() {
        activeRequests.removeAll()
        completedRequests.removeAll()
    }
}
