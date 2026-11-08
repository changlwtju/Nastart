import Foundation

/// Executes the shared preparation lifetime on the UI owner's actor. Sources
/// still own their transport and must clean up a partially constructed result
/// if their operation throws. Successfully returned, rejected results are
/// disposed here before this call finishes.
@MainActor public final class PlaybackPreparationCoordinator<Resource> {
    private var gate = PlaybackPreparationGate()
    public init() {}

    /// A nil result means another attempt already owns preparation, or this
    /// presentation was cancelled/closed. Only a current failure is thrown.
    public func prepare(
        operation: (_ checkCurrent: () throws -> Void) async throws -> Resource,
        discard: @escaping @MainActor (Resource) async -> Void
    ) async throws -> Resource? {
        guard let ticket = gate.begin() else { return nil }
        do {
            try Task.checkCancellation()
            let result = try await operation {
                try Task.checkCancellation()
                guard self.gate.isPending(ticket) else { throw CancellationError() }
            }
            guard !Task.isCancelled, gate.commit(ticket) else {
                gate.fail(ticket)
                // Cancellation must reject delivery without cancelling the
                // server's release request too. Await owned cleanup in an
                // independent task; it is still part of this call's lifetime.
                await Task { @MainActor in await discard(result) }.value
                return nil
            }
            return result
        } catch {
            guard gate.fail(ticket), !Task.isCancelled, !(error is CancellationError) else { return nil }
            throw error
        }
    }

    /// Closing is terminal. An uncooperative source may finish later, but its
    /// result will be disposed instead of delivered to a dismissed player.
    public func close() { gate.close() }
}
