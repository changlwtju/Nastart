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

    func schedule(_ request: PlaybackPreloadRequest, ioContext: PlaybackIOContext) async throws {
        activeRequests.append(request)
        try await ioContext.preload(range: request.range, budget: request.budgetBytes)
        activeRequests.removeAll { $0.id == request.id }
        completedRequests.append(request)
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
