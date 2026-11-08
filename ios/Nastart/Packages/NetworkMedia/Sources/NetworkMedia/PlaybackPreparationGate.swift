import Foundation

/// Shared admission and completion rules for source-specific playback setup.
/// The caller still owns transport cancellation and disposal of rejected results.
public struct PlaybackPreparationGate: Sendable {
    public struct Ticket: Equatable, Sendable {
        fileprivate let id: UUID
    }
    private enum Phase: Sendable {
        case idle, preparing(Ticket), committed, closed
    }
    private var phase: Phase = .idle
    public init() {}

    /// A presentation may prepare once at a time, and deliver only one result.
    public mutating func begin() -> Ticket? {
        guard case .idle = phase else { return nil }
        let ticket = Ticket(id: UUID())
        phase = .preparing(ticket)
        return ticket
    }
    public func isPending(_ ticket: Ticket) -> Bool {
        guard case .preparing(let current) = phase else { return false }
        return current == ticket
    }
    public mutating func commit(_ ticket: Ticket) -> Bool {
        guard isPending(ticket) else { return false }
        phase = .committed
        return true
    }
    /// A failed attempt may retry; a stale failure cannot revoke a newer one.
    @discardableResult public mutating func fail(_ ticket: Ticket) -> Bool {
        guard isPending(ticket) else { return false }
        phase = .idle
        return true
    }
    public mutating func close() { phase = .closed }
}
