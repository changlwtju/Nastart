import Foundation

/// Owns delivered playback resources across initial preparation, replacement
/// and exit. Platform adapters install/stop their renderer synchronously;
/// authentication, transport and server cleanup stay with the source.
@MainActor public final class PlaybackSessionLifetime<Resource> {
    public struct Ticket: Equatable {
        fileprivate let id = UUID()
    }

    public private(set) var current: Resource?
    private var activeTicket: Ticket?
    private var pendingTicket: Ticket?
    private var closed = false
    private var cleanup: Task<Void, Never>?
    private let release: @MainActor (Resource) async -> Void

    public init(release: @escaping @MainActor (Resource) async -> Void) {
        self.release = release
    }

    public var hasPendingOperation: Bool { pendingTicket != nil }

    public func beginInitial() -> Ticket? {
        guard current == nil, pendingTicket == nil else { return nil }
        return beginReplacement()
    }

    /// The outgoing resource remains owned until a current candidate commits.
    /// Starting another replacement invalidates late delivery and callbacks.
    public func beginReplacement() -> Ticket? {
        guard !closed, !Task.isCancelled else { return nil }
        let ticket = Ticket()
        pendingTicket = ticket
        return ticket
    }

    public func isCurrent(_ ticket: Ticket) -> Bool {
        !closed && (pendingTicket ?? activeTicket) == ticket
    }

    @discardableResult public func fail(_ ticket: Ticket) -> Bool {
        guard !closed, pendingTicket == ticket else { return false }
        pendingTicket = nil
        return true
    }

    /// Call only after stopping/detaching the outgoing renderer, with no await
    /// between the final currentness check and this ownership transfer.
    @discardableResult public func commit(
        _ resource: Resource, for ticket: Ticket,
        retiring: (@MainActor (Resource) async -> Void)? = nil
    ) -> Bool {
        guard !closed, !Task.isCancelled, pendingTicket == ticket else { return false }
        let old = current
        current = resource
        activeTicket = ticket
        pendingTicket = nil
        if let old { enqueueRelease(old, retiring: retiring) }
        return true
    }

    /// A rejected resource was never installed. Wait for its uncancelled
    /// cleanup even when the caller or a non-cooperative loader was cancelled.
    public func discard(_ resource: Resource) async {
        await enqueueRelease(resource).value
    }

    /// End is reusable for an owning model's next item. Close is terminal for
    /// a dismissed presentation. Both detach ownership exactly once.
    public func end(retiring: (@MainActor (Resource) async -> Void)? = nil) {
        pendingTicket = nil
        activeTicket = nil
        let old = current
        current = nil
        if let old { enqueueRelease(old, retiring: retiring) }
    }

    public func close(retiring: (@MainActor (Resource) async -> Void)? = nil) {
        closed = true
        end(retiring: retiring)
    }

    public func waitForCleanup() async { await cleanup?.value }

    @discardableResult private func enqueueRelease(
        _ resource: Resource, retiring: (@MainActor (Resource) async -> Void)? = nil
    ) -> Task<Void, Never> {
        let previous = cleanup, release = release
        let task = Task { @MainActor in
            await previous?.value
            await retiring?(resource)
            await release(resource)
        }
        cleanup = task
        return task
    }
}
