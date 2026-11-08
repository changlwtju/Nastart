import Foundation

/// Native adapters dispatch without captured autoplay. Completion admission,
/// main-actor ordering and restoring the latest user intent are shared by AV/KS.
@MainActor public enum PlaybackSeekCommandExecutor {
    public static func submit(
        target: Double,
        isCurrent: @escaping @MainActor () -> Bool,
        seek: (_ target: Double, _ completion: @escaping (Bool) -> Void) -> Void,
        willComplete: @escaping @MainActor (Bool) -> Void = { _ in },
        restoreIntent: @escaping @MainActor () -> Void,
        didComplete: @escaping @MainActor (Bool) -> Void = { _ in }
    ) {
        guard target.isFinite, target >= 0, isCurrent() else { return }
        seek(target) { completed in
            Task { @MainActor in
                guard isCurrent() else { return }
                willComplete(completed)
                // Restore after clearing pending seek state, and read the
                // latest pause/rate choice rather than a dispatch-time copy.
                if completed { restoreIntent() }
                didComplete(completed)
            }
        }
    }
}
