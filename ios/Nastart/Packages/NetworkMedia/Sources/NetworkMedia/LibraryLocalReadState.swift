import Foundation

/// Owns only the outcome of reading saved client data, independently of scans.
struct LibraryLocalReadState: Equatable, Sendable {
    enum Phase: Equatable, Sendable { case idle, loading, ready, failed }
    private(set) var phase: Phase = .idle
    private(set) var failureMessage: String?
    private var request: UUID?

    mutating func begin() -> UUID {
        let ticket = UUID()
        request = ticket; phase = .loading; failureMessage = nil
        return ticket
    }
    func isCurrent(_ ticket: UUID) -> Bool { request == ticket && phase == .loading }
    @discardableResult mutating func succeed(_ ticket: UUID) -> Bool {
        guard isCurrent(ticket) else { return false }
        request = nil; phase = .ready; failureMessage = nil
        return true
    }
    @discardableResult mutating func fail(_ ticket: UUID, message: String) -> Bool {
        guard isCurrent(ticket) else { return false }
        request = nil; phase = .failed; failureMessage = message
        return true
    }
    @discardableResult mutating func cancel(_ ticket: UUID) -> Bool {
        guard isCurrent(ticket) else { return false }
        request = nil; phase = .idle; failureMessage = nil
        return true
    }
}
