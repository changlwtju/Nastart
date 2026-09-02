import SwiftUI

#if canImport(KSPlayer)
import KSPlayer

struct GreenfieldKSPlayerRenderer: View {
    let plan: PlaybackPlan
    let onUnsupported: () -> Void
    let onStateChanged: (String) -> Void
    let onPlaybackTime: (TimeInterval, TimeInterval) -> Void
    let onFinished: (String?) -> Void
    let onBufferChanged: (Int, TimeInterval) -> Void

    @StateObject private var coordinator = KSVideoPlayer.Coordinator()

    var body: some View {
        if #available(iOS 16.0, *) {
            KSVideoPlayer(
                coordinator: coordinator,
                url: plan.primaryRoute.url,
                options: makeOptions()
            )
            .onStateChanged { _, state in
                onStateChanged(state.description)
            }
            .onPlay { currentTime, totalTime in
                onPlaybackTime(currentTime, totalTime)
            }
            .onFinish { _, error in
                onFinished(error.map(Self.describe))
            }
            .onBufferChanged { bufferedCount, consumeTime in
                onBufferChanged(bufferedCount, consumeTime)
            }
            .ignoresSafeArea()
            .onAppear {
                configureDefaultEngine()
                onStateChanged("rendererAppeared")
            }
        } else {
            Color.black
                .ignoresSafeArea()
                .onAppear(perform: onUnsupported)
        }
    }

    private func makeOptions() -> KSOptions {
        let options = KSOptions()
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
            options.probesize = 1 * 1024 * 1024
            options.maxAnalyzeDuration = 1_000_000
            options.formatContextOptions["seekable"] = 0
            options.formatContextOptions["skip_estimate_duration_from_pts"] = 1
        } else if plan.primaryRoute.routeKind == .localRangeProxy {
            options.formatContextOptions["seekable"] = 1
        }
        options.autoSelectEmbedSubtitle = plan.subtitles.mode != .disabled
        options.canStartPictureInPictureAutomaticallyFromInline = true
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

        return options
    }

    private func ffmpegInputFormatName(for route: PlaybackRoute) -> String? {
        let container = (route.containerHint ?? route.url.pathExtension)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch container {
        case "ts", "m2ts", "mts":
            return "mpegts"
        case "mkv", "webm":
            return "matroska,webm"
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

    private func shouldTreatAsTransportStream(_ route: PlaybackRoute) -> Bool {
        let container = (route.containerHint ?? route.url.pathExtension)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return container == "ts" || container == "m2ts" || container == "mts"
    }

    private func configureDefaultEngine() {
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSMEPlayer.self
        KSOptions.logLevel = .info
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain):\(nsError.code):\(nsError.localizedDescription)"
    }
}
#else
struct GreenfieldKSPlayerRenderer: View {
    let plan: PlaybackPlan
    let onUnsupported: () -> Void
    let onStateChanged: (String) -> Void
    let onPlaybackTime: (TimeInterval, TimeInterval) -> Void
    let onFinished: (String?) -> Void
    let onBufferChanged: (Int, TimeInterval) -> Void

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .onAppear(perform: onUnsupported)
    }
}
#endif
