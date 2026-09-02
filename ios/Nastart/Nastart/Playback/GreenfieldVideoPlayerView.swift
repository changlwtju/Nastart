import SwiftUI
import AVFoundation
import AVKit

struct GreenfieldPlaybackLaunchRequest: Identifiable {
    let id: UUID
    let intent: PlaybackIntent
    let fileExtensionHint: String?
    let mimeHint: String?
    let certificatePolicy: PlaybackCertificatePolicy
    let alternateRoutes: [PlaybackRoute]
    let byteLength: Int64?
    let duration: TimeInterval?
    let estimatedBitrate: Int?
    let tracks: TrackCatalog
    let subtitles: SubtitlePlan?

    init(
        id: UUID = UUID(),
        intent: PlaybackIntent,
        fileExtensionHint: String? = nil,
        mimeHint: String? = nil,
        certificatePolicy: PlaybackCertificatePolicy = .systemTrust,
        alternateRoutes: [PlaybackRoute] = [],
        byteLength: Int64? = nil,
        duration: TimeInterval? = nil,
        estimatedBitrate: Int? = nil,
        tracks: TrackCatalog = TrackCatalog(),
        subtitles: SubtitlePlan? = nil
    ) {
        self.id = id
        self.intent = intent
        self.fileExtensionHint = fileExtensionHint
        self.mimeHint = mimeHint
        self.certificatePolicy = certificatePolicy
        self.alternateRoutes = alternateRoutes
        self.byteLength = byteLength
        self.duration = duration
        self.estimatedBitrate = estimatedBitrate
        self.tracks = tracks
        self.subtitles = subtitles
    }
}

struct GreenfieldVideoPlayerView: View {
    let request: GreenfieldPlaybackLaunchRequest
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = GreenfieldVideoPlayerModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let plan = model.renderingPlan,
               plan.enginePolicy == .ksPlayer,
               PlaybackEngineAvailability.ksPlayerLinked {
                GreenfieldKSPlayerRenderer(
                    plan: plan,
                    onUnsupported: model.handleKSPlayerRendererUnsupported,
                    onStateChanged: model.handleKSPlayerStateChanged,
                    onPlaybackTime: model.handleKSPlayerPlaybackTime,
                    onFinished: model.handleKSPlayerFinished,
                    onBufferChanged: model.handleKSPlayerBufferChanged
                )
                .id(plan.primaryRoute.id)
            } else {
                VideoPlayer(player: model.player)
                    .ignoresSafeArea(edges: .bottom)
            }

            if let errorMessage = model.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                    Text("player.load_failed")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                    Button("action.done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                }
                .foregroundStyle(.white)
                .padding(22)
            } else if model.isPreparing {
                ProgressView()
                    .tint(.white)
                    .padding(14)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            }

#if DEBUG
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "switch.2")
                    Text(model.debugBadge)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Spacer()
            }
#endif
        }
        .navigationTitle(request.intent.displayTitle.isEmpty ? "player.title" : request.intent.displayTitle)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
#endif
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.done") {
                    dismiss()
                }
            }
#else
            ToolbarItem(placement: .cancellationAction) {
                Button("action.done") {
                    dismiss()
                }
            }
#endif
        }
        .onAppear {
            model.start(request)
        }
        .onDisappear {
            model.stop()
        }
    }
}

@MainActor
private final class GreenfieldVideoPlayerModel: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var isPreparing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var debugBadge = "Greenfield"
    @Published private(set) var renderingPlan: PlaybackPlan?

    private var request: GreenfieldPlaybackLaunchRequest?
    private var coordinator: PlaybackSessionCoordinator?
    private var recorder: PlaybackDiagnosticsRecorder?
    private var periodicTimeObserver: Any?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var didRecordFirstFrame = false
    private var didRecordThirtySecondCheckpoint = false
    private var lastTimeControlStatus: AVPlayer.TimeControlStatus?
    private var playbackTask: Task<Void, Never>?
    private var failedRouteIDs = Set<UUID>()

    func start(_ request: GreenfieldPlaybackLaunchRequest) {
        guard playbackTask == nil else { return }
        self.request = request
        isPreparing = true
        errorMessage = nil
        debugBadge = "Greenfield preparing"

        playbackTask = Task { [weak self] in
            guard let self else { return }
            let recorder = PlaybackDiagnosticsRecorder()
            let resolver = URLPlaybackSourceResolver(
                sourceKind: request.intent.sourceKind,
                fileExtensionHint: request.fileExtensionHint,
                mimeHint: request.mimeHint,
                certificatePolicy: request.certificatePolicy,
                byteLength: request.byteLength,
                duration: request.duration,
                estimatedBitrate: request.estimatedBitrate,
                tracks: request.tracks,
                subtitles: request.subtitles,
                alternateRoutes: request.alternateRoutes
            )
            let coordinator = PlaybackSessionCoordinator(
                resolver: resolver,
                diagnostics: recorder
            )
            do {
                let result = try await coordinator.prepare(request.intent)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.recorder = recorder
                    self.coordinator = coordinator
                    self.renderingPlan = result.plan
                    if self.requiresLinkedKSPlayer(for: result.plan) {
                        self.handleRequiredKSPlayerMissing(result.plan)
                    } else if self.shouldUseKSPlayerRenderer(for: result.plan) {
                        self.player.replaceCurrentItem(with: nil)
                    } else {
                        self.installPlayerItem(for: result.plan)
                    }
                    self.isPreparing = false
                    self.recordPlanReady(result)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isPreparing = false
                    self.errorMessage = error.localizedDescription
                    self.debugBadge = "Greenfield failed"
                }
            }
        }
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        player.pause()
        if let periodicTimeObserver {
            player.removeTimeObserver(periodicTimeObserver)
            self.periodicTimeObserver = nil
        }
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        if let coordinator, let renderingPlan {
            Task {
                await coordinator.finishPlayback(plan: renderingPlan)
            }
        }
        player.replaceCurrentItem(with: nil)
        renderingPlan = nil
        failedRouteIDs.removeAll()
    }

    func handleKSPlayerRendererUnsupported() {
        guard let renderingPlan else { return }
        debugBadge = fallbackBadge(for: renderingPlan, reason: "unsupported")
        installPlayerItem(for: renderingPlan)
    }

    func handleKSPlayerStateChanged(_ state: String) {
        guard let plan = renderingPlan else { return }
        debugBadge = [
            plan.enginePolicy.rawValue,
            "KSPlayer \(state)",
            plan.primaryRoute.routeKind.rawValue,
            plan.intent.connectionContext.addressKind.rawValue
        ].joined(separator: " / ")
        let recorder = recorder
        Task {
            await recorder?.record(
                state == "error" ? .playbackFailed : .engineReady,
                plan: plan,
                engineName: "KSPlayer",
                metrics: ["state": state]
            )
        }
        if state == "error" {
            if activateAlternateRoute(after: plan, reason: "ksPlayerStateError") {
                return
            }
            errorMessage = NSLocalizedString("player.load_failed", comment: "")
        }
    }

    func handleKSPlayerPlaybackTime(_ currentTime: TimeInterval, _ totalTime: TimeInterval) {
        guard currentTime.isFinite, totalTime.isFinite else { return }
        handlePlaybackTime(currentTime)
        guard let plan = renderingPlan else { return }
        if totalTime > 0, plan.timeline.duration == nil {
            let recorder = recorder
            Task {
                await recorder?.record(
                    .bufferUpdated,
                    plan: plan,
                    engineName: "KSPlayer",
                    metrics: [
                        "currentSeconds": String(format: "%.1f", currentTime),
                        "durationSeconds": String(format: "%.1f", totalTime)
                    ]
                )
            }
        }
    }

    func handleKSPlayerFinished(_ errorDescription: String?) {
        guard let plan = renderingPlan else { return }
        if let errorDescription {
            if activateAlternateRoute(after: plan, reason: "ksPlayerFinished") {
                return
            }
            errorMessage = errorDescription
            debugBadge = "KSPlayer failed"
            recordPlayerFailure(plan: plan, error: nil, stage: "ksPlayerFinished:\(errorDescription)")
            return
        }
        let coordinator = coordinator
        Task {
            await coordinator?.finishPlayback(plan: plan)
        }
    }

    func handleKSPlayerBufferChanged(_ bufferedCount: Int, _ consumeTime: TimeInterval) {
        guard let plan = renderingPlan else { return }
        let recorder = recorder
        Task {
            await recorder?.record(
                .bufferUpdated,
                plan: plan,
                engineName: "KSPlayer",
                metrics: [
                    "bufferedCount": String(bufferedCount),
                    "consumeMs": String(Int((consumeTime * 1000).rounded()))
                ]
            )
        }
    }

    private func installPlayerItem(for plan: PlaybackPlan) {
        let item = AVPlayerItem(url: plan.primaryRoute.url)
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                self?.handleItemStatus(item.status)
            }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) {
            [weak self] player, _ in
            Task { @MainActor [weak self] in
                self?.handleTimeControlStatus(player.timeControlStatus)
            }
        }
        periodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.handlePlaybackTime(time.seconds)
            }
        }
        player.replaceCurrentItem(with: item)
        if plan.timeline.startTime > 0 {
            player.seek(
                to: CMTime(seconds: plan.timeline.startTime, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }
        player.rate = plan.intent.playbackRate
        player.play()
    }

    private func handleItemStatus(_ status: AVPlayerItem.Status) {
        guard let plan = renderingPlan else { return }
        switch status {
        case .readyToPlay:
            debugBadge = fallbackBadge(for: plan, reason: "ready")
        case .failed:
            let itemError = player.currentItem?.error
            errorMessage = itemError?.localizedDescription
                ?? NSLocalizedString("player.load_failed", comment: "")
            debugBadge = "Greenfield player failed"
            recordPlayerFailure(plan: plan, error: itemError, stage: "avPlayerItemFailed")
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        guard let plan = renderingPlan, lastTimeControlStatus != status else { return }
        let previousStatus = lastTimeControlStatus
        lastTimeControlStatus = status
        let coordinator = coordinator
        Task {
            if status == .paused, previousStatus == .playing {
                await coordinator?.pause(plan: plan)
            } else if status == .playing, previousStatus == .paused {
                try? await coordinator?.resume(plan: plan)
            }
        }
    }

    private func handlePlaybackTime(_ seconds: Double) {
        guard let coordinator, let plan = renderingPlan, seconds.isFinite else { return }
        if !didRecordFirstFrame, seconds > max(plan.timeline.startTime, 0) + 0.05 {
            didRecordFirstFrame = true
            Task {
                await coordinator.markFirstFrame(plan: plan, position: seconds)
            }
        }
        if !didRecordThirtySecondCheckpoint,
           didRecordFirstFrame,
           seconds >= max(plan.timeline.startTime, 0) + 30 {
            didRecordThirtySecondCheckpoint = true
            Task {
                await coordinator.markContinuousPlayback(plan: plan, seconds: 30)
            }
        }
    }

    private func recordPlanReady(_ result: PlaybackSessionStartupResult) {
        let renderer = shouldUseKSPlayerRenderer(for: result.plan)
            ? "KSPlayer"
            : fallbackRendererName(for: result.plan)
        debugBadge = [
            result.plan.enginePolicy.rawValue,
            renderer,
            result.plan.primaryRoute.routeKind.rawValue,
            result.plan.intent.connectionContext.addressKind.rawValue
        ].joined(separator: " / ")
    }

    private func shouldUseKSPlayerRenderer(for plan: PlaybackPlan) -> Bool {
        plan.enginePolicy == .ksPlayer && PlaybackEngineAvailability.ksPlayerLinked
    }

    private func requiresLinkedKSPlayer(for plan: PlaybackPlan) -> Bool {
        plan.enginePolicy == .ksPlayer && !PlaybackEngineAvailability.ksPlayerLinked
    }

    private func handleRequiredKSPlayerMissing(_ plan: PlaybackPlan) {
        player.replaceCurrentItem(with: nil)
        errorMessage = "KSPlayer is required for this route but is not linked in this build."
        debugBadge = "Greenfield requires KSPlayer"
        recordPlayerFailure(plan: plan, error: nil, stage: "ksPlayerNotLinked")
    }

    private func fallbackRendererName(for plan: PlaybackPlan) -> String {
        if plan.enginePolicy == .ksPlayer {
            return "AVPlayer fallback"
        }
        return PlaybackEngineAvailability.displayName(for: plan.enginePolicy)
    }

    private func fallbackBadge(for plan: PlaybackPlan, reason: String) -> String {
        [
            plan.enginePolicy.rawValue,
            "\(fallbackRendererName(for: plan)) \(reason)",
            plan.primaryRoute.routeKind.rawValue,
            plan.intent.connectionContext.addressKind.rawValue
        ].joined(separator: " / ")
    }

    private func activateAlternateRoute(after plan: PlaybackPlan, reason: String) -> Bool {
        failedRouteIDs.insert(plan.primaryRoute.id)
        guard let fallbackRoute = plan.alternateRoutes.first(where: { route in
            !failedRouteIDs.contains(route.id)
                && route.url.absoluteString != plan.primaryRoute.url.absoluteString
        }) else {
            return false
        }

        let remainingRoutes = ([plan.primaryRoute] + plan.alternateRoutes).filter {
            $0.id != fallbackRoute.id
        }
        var replacementIntent = plan.intent
        replacementIntent.directURL = fallbackRoute.url
        replacementIntent.connectionContext = PlaybackConnectionContext.make(url: fallbackRoute.url)
        let replacementPlan = PlaybackPlanningPolicy.makePlan(
            intent: replacementIntent,
            url: fallbackRoute.url,
            originURL: fallbackRoute.originURL,
            fileExtensionHint: fallbackRoute.containerHint,
            mimeHint: fallbackRoute.mimeHint,
            certificatePolicy: fallbackRoute.certificatePolicy,
            byteLength: fallbackRoute.byteLength,
            duration: fallbackRoute.duration,
            estimatedBitrate: fallbackRoute.codecSummary.bitrate,
            tracks: plan.tracks,
            subtitles: plan.subtitles,
            alternateRoutes: remainingRoutes
        )
        errorMessage = nil
        isPreparing = false
        renderingPlan = replacementPlan
        player.replaceCurrentItem(with: nil)
        debugBadge = [
            replacementPlan.enginePolicy.rawValue,
            "fallback \(reason)",
            replacementPlan.primaryRoute.routeKind.rawValue,
            replacementPlan.intent.connectionContext.addressKind.rawValue
        ].joined(separator: " / ")
        let coordinator = coordinator
        Task {
            await coordinator?.markStreamInterrupted(
                plan: plan,
                reason: reason,
                fallbackRoute: fallbackRoute
            )
        }
        return true
    }

    private func recordPlayerFailure(plan: PlaybackPlan, error: Error?, stage: String) {
        var details = [
            "stage": stage,
            "enginePolicy": plan.enginePolicy.rawValue,
            "routeKind": plan.primaryRoute.routeKind.rawValue,
            "sourceKind": plan.intent.sourceKind.rawValue,
            "contentKind": plan.intent.contentKind.rawValue,
            "addressKind": plan.intent.connectionContext.addressKind.rawValue,
            "ksPlayerLinked": "\(PlaybackEngineAvailability.ksPlayerLinked)",
            "target": DiagnosticLogStore.redactedURL(plan.primaryRoute.url)
        ]
        if let error {
            let nsError = error as NSError
            details["errorDomain"] = nsError.domain
            details["errorCode"] = "\(nsError.code)"
            details["error"] = nsError.localizedDescription
        }
        DiagnosticLogStore.shared.record(
            .error,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.playback.next.playback_failed",
            details: details
        )
    }
}
