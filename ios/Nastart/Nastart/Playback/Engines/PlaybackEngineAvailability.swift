import Foundation

enum PlaybackEngineAvailability {
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
