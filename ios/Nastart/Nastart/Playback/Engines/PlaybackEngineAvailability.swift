import Foundation

enum PlaybackEngineAvailability {
    /// Settings on every platform describe the shared video pipeline.
    /// Audio keeps its existing adapter and is not covered by this summary.
    static var videoEngineSummary: String {
        ksPlayerLinked ? "KSPlayer / AVFoundation" : "AVFoundation"
    }

    static var ksPlayerLinked: Bool {
        #if canImport(KSPlayer)
        return true
        #else
        return false
        #endif
    }

    static func isLinked(_ candidate: PlaybackEngineCandidate) -> Bool {
        switch candidate {
        case .ksPlayer:
            return ksPlayerLinked
        case .systemAVPlayer, .localHLS:
            return true
        }
    }

    static func displayName(for candidate: PlaybackEngineCandidate) -> String {
        switch candidate {
        case .ksPlayer:
            return ksPlayerLinked ? "KSPlayer" : "KSPlayer pending"
        case .systemAVPlayer:
            return "AVPlayer"
        case .localHLS:
            return "Local HLS"
        }
    }
}
