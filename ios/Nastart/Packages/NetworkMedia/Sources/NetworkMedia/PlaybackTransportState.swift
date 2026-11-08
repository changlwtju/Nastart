import Foundation

/// Shared command ownership. Native renderers supply clocks/completions;
/// pending targets and late completion rules do not depend on the entry point.
public struct PlaybackSeekState: Equatable, Sendable {
    public struct Request: Equatable, Sendable {
        public let generation: Int
        public let target: Double
    }
    public private(set) var generation = 0
    public private(set) var pendingTarget: Double?
    public init() {}

    /// Preserve the existing mobile boundary, including its 0.1s end margin.
    public static func target(absolute seconds: Double, duration: Double) -> Double? {
        guard seconds.isFinite, duration.isFinite, duration > 0 else { return nil }
        return min(max(seconds, 0), max(duration - 0.1, 0))
    }

    public func target(relative delta: Double, clock: Double, fallback: Double,
                       duration: Double) -> Double? {
        guard delta.isFinite else { return nil }
        let anchor = pendingTarget ?? (clock.isFinite && clock >= 0 ? clock : fallback)
        guard anchor.isFinite, anchor >= 0 else { return nil }
        return Self.target(absolute: anchor + delta, duration: duration)
    }

    public mutating func begin(absolute seconds: Double, duration: Double) -> Request? {
        guard let target = Self.target(absolute: seconds, duration: duration) else { return nil }
        generation += 1
        pendingTarget = target
        return Request(generation: generation, target: target)
    }

    /// A superseded seek or detached renderer cannot clear the latest target.
    public func owns(generation: Int) -> Bool {
        self.generation == generation && pendingTarget != nil
    }

    @discardableResult public mutating func complete(generation: Int) -> Bool {
        guard owns(generation: generation) else { return false }
        pendingTarget = nil
        return true
    }

    public mutating func invalidate() {
        generation += 1
        pendingTarget = nil
    }
}

/// A pause/rate change can be applied at commit. A newer timeline or PiP
/// owner must prevent an awaited candidate from replacing the current session.
public struct PlaybackHandoffBoundary: Equatable, Sendable {
    private let seekGeneration: Int?
    private let pictureInPictureGeneration: Int
    public init(seekGeneration: Int? = nil, pictureInPictureGeneration: Int = 0) {
        self.seekGeneration = seekGeneration
        self.pictureInPictureGeneration = pictureInPictureGeneration
    }
    public func allowsReplacement(seekGeneration: Int, pictureInPictureGeneration: Int = 0,
                                  isPictureInPictureStarting: Bool = false,
                                  isPictureInPictureActive: Bool = false) -> Bool {
        self.pictureInPictureGeneration == pictureInPictureGeneration
            && !isPictureInPictureStarting && !isPictureInPictureActive
            && (self.seekGeneration == nil || self.seekGeneration == seekGeneration)
    }
}
