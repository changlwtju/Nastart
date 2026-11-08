import Foundation
#if canImport(KSPlayer)
import KSPlayer

/// Existing renderer defaults shared by all terminals and sources. Values are
/// extracted unchanged; platform callbacks and presentation remain in adapters.
@MainActor enum PlaybackKSOptionsPolicy {
    static func apply(_ plan: PlaybackPlan, to options: KSOptions) {
        configureDefaultEngine()
        options.preferredForwardBufferDuration = max(plan.startupPolicy.minimumPlayableBufferSeconds, 0.25)
        options.maxBufferDuration = max(plan.startupPolicy.minimumPlayableBufferSeconds * 4, 6)
        options.startPlayTime = plan.timeline.startTime
        options.startPlayRate = plan.intent.playbackRate
        options.isAccurateSeek = true
        options.isSecondOpen = false
        options.nobuffer = plan.intent.networkContext.isExpensive || plan.intent.networkContext.isConstrained
        options.probesize = 5 * 1024 * 1024
        options.maxAnalyzeDuration = 2_000_000
        options.forcedInputFormatName = ffmpegInputFormatName(for: plan.primaryRoute)
        if shouldTreatAsTransportStream(plan.primaryRoute) {
            let isSeekableFile = plan.primaryRoute.routeKind == .localRangeProxy
                || plan.intent.contentKind == .discImage
            options.prefersTimestampSeeking = plan.intent.contentKind == .discImage
            options.isSeekImageSubtitle = false // Selection uses the shared seek lifecycle above.
            options.probesize = isSeekableFile ? 5 * 1024 * 1024 : 1 * 1024 * 1024
            options.maxAnalyzeDuration = isSeekableFile ? 3_000_000 : 1_000_000
            options.formatContextOptions["seekable"] = isSeekableFile ? 1 : 0
            options.formatContextOptions["skip_estimate_duration_from_pts"] = isSeekableFile ? 0 : 1
        } else if plan.primaryRoute.routeKind == .localRangeProxy {
            options.formatContextOptions["seekable"] = 1
        }
        if plan.primaryRoute.certificatePolicy == .allowPinnedSelfSigned {
            options.formatContextOptions["tls_verify"] = "0"
        }
        if !plan.primaryRoute.headers.isEmpty {
            options.appendHeader(plan.primaryRoute.headers)
        }

        if let userAgent = plan.primaryRoute.headers["User-Agent"] {
            options.userAgent = userAgent
        }
        if let referer = plan.primaryRoute.headers["Referer"] {
            options.referer = referer
        }

    }
    private static func ffmpegInputFormatName(for route: PlaybackRoute) -> String? {
        let container = (route.containerHint ?? route.url.pathExtension)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch container {
        case "ts", "m2ts", "mts":
            return "mpegts"
        case "mp4", "m4v", "mov":
            return "mov,mp4,m4a,3gp,3g2,mj2"
        case "avi":
            return "avi"
        case "flv":
            return "flv"
        case "wmv", "asf":
            return "asf"
        case "rm", "rmvb":
            return "rm"
        case "m3u8":
            return "hls"
        default:
            return nil
        }
    }

    private static func shouldTreatAsTransportStream(_ route: PlaybackRoute) -> Bool {
        let container = (route.containerHint ?? route.url.pathExtension)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return container == "ts" || container == "m2ts" || container == "mts"
    }

    static func configureDefaultEngine() {
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.logLevel = .info
    }

}
#endif
