import Foundation

/// A late read, including a retry for the same item, cannot finish a newer one.
public struct MediaReadState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case idle, loading, ready, failed }
    public struct Ticket: Equatable, Sendable {
        public let identity: String
        fileprivate let generation = UUID()
    }
    public private(set) var ticket: Ticket?
    public private(set) var phase: Phase = .idle
    public init() {}
    public mutating func begin(_ identity: String) -> Ticket {
        let ticket = Ticket(identity: identity)
        self.ticket = ticket; phase = .loading
        return ticket
    }
    public func phase(for identity: String) -> Phase { ticket?.identity == identity ? phase : .idle }
    @discardableResult public mutating func succeed(_ ticket: Ticket) -> Bool { finish(ticket, as: .ready) }
    @discardableResult public mutating func fail(_ ticket: Ticket) -> Bool { finish(ticket, as: .failed) }
    @discardableResult public mutating func cancel(_ ticket: Ticket) -> Bool { finish(ticket, as: .idle) }
    private mutating func finish(_ ticket: Ticket, as phase: Phase) -> Bool {
        guard self.ticket == ticket, self.phase == .loading else { return false }
        self.phase = phase
        return true
    }
}

// Existing detail readers keep the same ticket and transition implementation.
typealias MediaDetailReadState = MediaReadState

/// Availability concerns text, never whether an actor's image has loaded.
public enum MediaCreditsAvailability: Equatable, Sendable {
    case loading, missing, unavailable
    public static func resolve(hasPeople: Bool, metadata: MediaReadState.Phase,
                               credits: MediaReadState.Phase) -> Self? {
        if hasPeople { return nil }
        if metadata == .idle || metadata == .loading || credits == .idle || credits == .loading { return .loading }
        return metadata == .failed || credits == .failed ? .unavailable : .missing
    }
}
