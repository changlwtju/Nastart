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
        options.isSecondOpen = true
        options.nobuffer = plan.intent.networkContext.isExpensive || plan.intent.networkContext.isConstrained
        options.probesize = 5 * 1024 * 1024
        options.maxAnalyzeDuration = 2_000_000
        options.autoSelectEmbedSubtitle = plan.subtitles.mode != .disabled
        options.canStartPictureInPictureAutomaticallyFromInline = true
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

    private func configureDefaultEngine() {
        KSOptions.firstPlayerType = KSMEPlayer.self
        KSOptions.secondPlayerType = KSAVPlayer.self
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
