import Foundation

struct PlaybackSessionStartupResult: Equatable, Sendable {
    var plan: PlaybackPlan
    var completedPreloadBytes: Int64
    var openedRouteID: UUID
}

actor PlaybackSessionCoordinator {
    private let resolver: any PlaybackSourceResolver
    private let diagnostics: PlaybackDiagnosticsRecorder
    private let preloadCoordinator: PreloadCoordinator
    private let ioContextFactory: (PlaybackRoute) -> any PlaybackIOContext

    private(set) var activePlan: PlaybackPlan?
    private(set) var lastRuntimeState = PlaybackRuntimeState()

    init(
        resolver: any PlaybackSourceResolver,
        diagnostics: PlaybackDiagnosticsRecorder = PlaybackDiagnosticsRecorder(),
        preloadCoordinator: PreloadCoordinator = PreloadCoordinator(),
        ioContextFactory: @escaping (PlaybackRoute) -> any PlaybackIOContext = {
            ObservingPlaybackIOContext(route: $0)
        }
    ) {
        self.resolver = resolver
        self.diagnostics = diagnostics
        self.preloadCoordinator = preloadCoordinator
        self.ioContextFactory = ioContextFactory
    }

    func prepare(
        _ intent: PlaybackIntent,
        engine: (any PlaybackEngine)? = nil,
        onPrimaryRouteSelected: (@Sendable (PlaybackPlan) -> Void)? = nil
    ) async throws -> PlaybackSessionStartupResult {
        let requestedAt = Date()
        await diagnostics.record(
            .intentCreated,
            metrics: [
                "intentID": intent.id.uuidString,
                "sourceKind": intent.sourceKind.rawValue
            ]
        )
        await diagnostics.record(.sourceResolveStarted)
        let resolveStartedAt = Date()
        let plan = try await resolver.resolve(intent)
        activePlan = plan
        await diagnostics.record(
            .routeSelected,
            plan: plan,
            route: plan.primaryRoute,
            metrics: [
                PlaybackMetricKeys.tapToResolveMs: elapsedMilliseconds(since: requestedAt),
                PlaybackMetricKeys.resolveToRouteMs: elapsedMilliseconds(since: resolveStartedAt),
                PlaybackMetricKeys.routeKind: plan.primaryRoute.routeKind.rawValue,
                PlaybackMetricKeys.playMethod: plan.primaryRoute.playMethod.rawValue,
                PlaybackMetricKeys.decodeEngine: plan.enginePolicy.rawValue,
                "plannedStartSeconds": String(plan.timeline.startTime),
                PlaybackMetricKeys.connectionAddressKind: plan.intent.connectionContext.addressKind.rawValue,
                PlaybackMetricKeys.connectionScheme: plan.intent.connectionContext.scheme ?? "-",
                PlaybackMetricKeys.connectionPort: plan.intent.connectionContext.port.map(String.init) ?? "-",
                PlaybackMetricKeys.firstFrameTargetMs: String(plan.startupPolicy.firstFrameTargetMs),
                PlaybackMetricKeys.startupPreloadBytes: String(plan.startupPolicy.startupPreloadBytes),
                PlaybackMetricKeys.blocksFirstFrameUntilStartupPreload: String(plan.startupPolicy.blocksFirstFrameUntilStartupPreload),
                PlaybackMetricKeys.trackSwitchTargetRecoveryMs: String(plan.trackSwitchPolicy.targetRecoveryMs),
                PlaybackMetricKeys.pipRequiresSystemRenderer: String(plan.pictureInPicturePolicy.requiresSystemRenderer),
                PlaybackMetricKeys.ksPlayerLinked: String(PlaybackEngineAvailability.ksPlayerLinked)
            ]
        )
        if !Task.isCancelled { onPrimaryRouteSelected?(plan) }

        let ioOpenStartedAt = Date()
        let ioContext = ioContextFactory(plan.primaryRoute)
        await diagnostics.record(.ioOpenStarted, plan: plan, route: plan.primaryRoute)
        try await ioContext.open()
        await diagnostics.record(
            .ioOpened,
            plan: plan,
            route: plan.primaryRoute,
            metrics: [PlaybackMetricKeys.routeToOpenMs: elapsedMilliseconds(since: ioOpenStartedAt)]
        )

        let completedPreloadBytes = try await preloadStartupWindow(
            for: plan,
            ioContext: ioContext
        )

        if let engine {
            let prepareStartedAt = Date()
            await diagnostics.record(
                .enginePrepareStarted,
                plan: plan,
                engineName: engine.name
            )
            try await engine.prepare(plan)
            lastRuntimeState = await engine.snapshotRuntimeState()
            await diagnostics.record(
                .engineReady,
                plan: plan,
                engineName: engine.name,
                metrics: [PlaybackMetricKeys.openToReadyMs: elapsedMilliseconds(since: prepareStartedAt)]
            )
        }

        return PlaybackSessionStartupResult(
            plan: plan,
            completedPreloadBytes: completedPreloadBytes,
            openedRouteID: plan.primaryRoute.id
        )
    }

    func play(engine: any PlaybackEngine) async throws {
        try await engine.play()
        lastRuntimeState = await engine.snapshotRuntimeState()
    }

    func pause(plan: PlaybackPlan, engine: (any PlaybackEngine)? = nil) async {
        let startedAt = Date()
        await engine?.pause()
        if let engine {
            lastRuntimeState = await engine.snapshotRuntimeState()
        } else {
            lastRuntimeState = PlaybackRuntimeState(
                state: .paused,
                position: lastRuntimeState.position,
                duration: lastRuntimeState.duration,
                playbackRate: lastRuntimeState.playbackRate,
                selectedAudioTrackID: lastRuntimeState.selectedAudioTrackID,
                selectedSubtitleTrackID: lastRuntimeState.selectedSubtitleTrackID
            )
        }
        await diagnostics.record(
            .paused,
            plan: plan,
            engineName: engine?.name,
            metrics: [PlaybackMetricKeys.pauseDurationMs: elapsedMilliseconds(since: startedAt)]
        )
    }

    func resume(plan: PlaybackPlan, engine: (any PlaybackEngine)? = nil) async throws {
        let startedAt = Date()
        try await engine?.play()
        if let engine {
            lastRuntimeState = await engine.snapshotRuntimeState()
        } else {
            lastRuntimeState = PlaybackRuntimeState(
                state: .playing,
                position: lastRuntimeState.position,
                duration: lastRuntimeState.duration,
                playbackRate: lastRuntimeState.playbackRate,
                selectedAudioTrackID: lastRuntimeState.selectedAudioTrackID,
                selectedSubtitleTrackID: lastRuntimeState.selectedSubtitleTrackID
            )
        }
        await diagnostics.record(
            .resumed,
            plan: plan,
            engineName: engine?.name,
            metrics: [PlaybackMetricKeys.resumeRecoveryMs: elapsedMilliseconds(since: startedAt)]
        )
    }

    func seek(
        plan: PlaybackPlan,
        to seconds: TimeInterval,
        mode: PlaybackSeekMode,
        engine: (any PlaybackEngine)? = nil
    ) async throws {
        let safeSeconds = max(seconds, 0)
        let delta = safeSeconds - lastRuntimeState.position
        let startedAt = Date()
        await diagnostics.record(
            .seekStarted,
            plan: plan,
            engineName: engine?.name,
            metrics: [
                PlaybackMetricKeys.seekTargetSeconds: metricString(safeSeconds),
                PlaybackMetricKeys.seekDeltaSeconds: metricString(delta)
            ]
        )
        if plan.preloadPolicy.isEnabled,
           plan.primaryRoute.rangeCapability == .supported {
            let approximateOffset = approximateByteOffset(
                route: plan.primaryRoute,
                timeline: plan.timeline,
                targetSeconds: safeSeconds
            )
            if let approximateOffset {
                let range = PlaybackByteRange(
                    start: approximateOffset,
                    length: plan.preloadPolicy.seekTargetBytes
                )
                let ioContext = ioContextFactory(plan.primaryRoute)
                try await preloadCoordinator.schedule(
                    PlaybackPreloadRequest(
                        planID: plan.id,
                        routeID: plan.primaryRoute.id,
                        range: range,
                        budgetBytes: plan.preloadPolicy.seekTargetBytes,
                        reason: .seekTarget
                    ),
                    ioContext: ioContext
                )
            }
        }
        try await engine?.seek(to: safeSeconds, mode: mode)
        if let engine {
            lastRuntimeState = await engine.snapshotRuntimeState()
        } else {
            lastRuntimeState = PlaybackRuntimeState(
                state: lastRuntimeState.state,
                position: safeSeconds,
                duration: lastRuntimeState.duration,
                playbackRate: lastRuntimeState.playbackRate,
                selectedAudioTrackID: lastRuntimeState.selectedAudioTrackID,
                selectedSubtitleTrackID: lastRuntimeState.selectedSubtitleTrackID
            )
        }
        await diagnostics.record(
            .seekRecovered,
            plan: plan,
            engineName: engine?.name,
            metrics: [PlaybackMetricKeys.seekRecoveryMs: elapsedMilliseconds(since: startedAt)]
        )
    }

    func selectAudioTrack(
        plan: PlaybackPlan,
        id: String?,
        engine: (any PlaybackEngine)? = nil
    ) async throws {
        try await engine?.selectAudioTrack(id: id)
        lastRuntimeState = PlaybackRuntimeState(
            state: lastRuntimeState.state,
            position: lastRuntimeState.position,
            duration: lastRuntimeState.duration,
            playbackRate: lastRuntimeState.playbackRate,
            selectedAudioTrackID: id,
            selectedSubtitleTrackID: lastRuntimeState.selectedSubtitleTrackID
        )
        let track = plan.tracks.sourceAudioTracks.first { $0.id == id }
        await diagnostics.record(
            .audioTrackChanged,
            plan: plan,
            engineName: engine?.name,
            metrics: [
                "audioTrackID": id ?? "default",
                PlaybackMetricKeys.audioCodec: track?.codec ?? "-"
            ]
        )
    }

    func selectSubtitleTrack(
        plan: PlaybackPlan,
        id: String?,
        engine: (any PlaybackEngine)? = nil
    ) async throws {
        try await engine?.selectSubtitleTrack(id: id)
        lastRuntimeState = PlaybackRuntimeState(
            state: lastRuntimeState.state,
            position: lastRuntimeState.position,
            duration: lastRuntimeState.duration,
            playbackRate: lastRuntimeState.playbackRate,
            selectedAudioTrackID: lastRuntimeState.selectedAudioTrackID,
            selectedSubtitleTrackID: id
        )
        let track = plan.tracks.sourceSubtitleTracks.first { $0.id == id }
        await diagnostics.record(
            .subtitleChanged,
            plan: plan,
            engineName: engine?.name,
            metrics: [
                "subtitleTrackID": id ?? "off",
                PlaybackMetricKeys.subtitleCodec: track?.codec ?? "-"
            ]
        )
    }

    func switchQuality(
        from currentPlan: PlaybackPlan,
        to replacementPlan: PlaybackPlan,
        qualityID: String
    ) async {
        activePlan = replacementPlan
        await diagnostics.record(
            .qualityChanged,
            plan: currentPlan,
            route: currentPlan.primaryRoute,
            metrics: [
                "qualityID": qualityID,
                PlaybackMetricKeys.seekTargetSeconds: metricString(lastRuntimeState.position)
            ]
        )
        await diagnostics.record(
            .routeSelected,
            plan: replacementPlan,
            route: replacementPlan.primaryRoute,
            metrics: [
                PlaybackMetricKeys.routeKind: replacementPlan.primaryRoute.routeKind.rawValue,
                PlaybackMetricKeys.playMethod: replacementPlan.primaryRoute.playMethod.rawValue
            ]
        )
    }

    func markFirstFrame(plan: PlaybackPlan, position: TimeInterval = 0) async {
        await diagnostics.record(
            .firstFrame,
            plan: plan,
            metrics: [
                PlaybackMetricKeys.tapToFirstFrameMs: elapsedMilliseconds(since: plan.intent.requestedAt),
                PlaybackMetricKeys.firstFramePositionSeconds: metricString(position),
                PlaybackMetricKeys.firstFrameSignal: "playbackClock"
            ]
        )
    }

    func markContinuousPlayback(plan: PlaybackPlan, seconds: TimeInterval) async {
        await diagnostics.record(
            .continuousPlaybackCheckpoint,
            plan: plan,
            metrics: [PlaybackMetricKeys.continuousPlaybackSeconds: metricString(seconds)]
        )
    }

    func enterBackground(plan: PlaybackPlan) async {
        await diagnostics.record(.backgroundEntered, plan: plan)
    }

    func recoverFromBackground(plan: PlaybackPlan) async {
        let startedAt = Date()
        await diagnostics.record(
            .backgroundRecovered,
            plan: plan,
            metrics: [PlaybackMetricKeys.resumeRecoveryMs: elapsedMilliseconds(since: startedAt)]
        )
    }

    func enterPictureInPicture(plan: PlaybackPlan, engine: (any PlaybackEngine)? = nil) async throws {
        let startedAt = Date()
        try await engine?.enterPictureInPicture()
        await diagnostics.record(
            .pipStarted,
            plan: plan,
            engineName: engine?.name,
            metrics: [PlaybackMetricKeys.seekRecoveryMs: elapsedMilliseconds(since: startedAt)]
        )
    }

    func leavePictureInPicture(plan: PlaybackPlan, engine: (any PlaybackEngine)? = nil) async {
        await engine?.leavePictureInPicture()
        await diagnostics.record(.pipStopped, plan: plan, engineName: engine?.name)
    }

    func finishPlayback(plan: PlaybackPlan, nextIntent: PlaybackIntent? = nil) async {
        await diagnostics.record(.playbackEnded, plan: plan)
        guard let nextIntent else { return }
        await diagnostics.record(
            .nextItemStarted,
            metrics: [
                "intentID": nextIntent.id.uuidString,
                PlaybackMetricKeys.preloadedBytes: "0",
                "nextItemBudgetBytes": metricString(plan.preloadPolicy.nextItemBytes)
            ]
        )
    }

    func updateNetwork(plan: PlaybackPlan, context: PlaybackNetworkContext) async {
        await diagnostics.record(
            .networkConditionChanged,
            plan: plan,
            metrics: [
                PlaybackMetricKeys.networkClass: context.networkClass.rawValue,
                "estimatedBitrate": context.estimatedBitrate.map(String.init) ?? "-"
            ]
        )
    }

    func updateBuffer(plan: PlaybackPlan, bufferAheadSeconds: TimeInterval) async {
        await diagnostics.record(
            .bufferUpdated,
            plan: plan,
            metrics: [PlaybackMetricKeys.bufferAheadSeconds: metricString(bufferAheadSeconds)]
        )
    }

    func markStreamInterrupted(
        plan: PlaybackPlan,
        reason: String,
        fallbackRoute: PlaybackRoute? = nil
    ) async {
        await diagnostics.record(
            .streamInterrupted,
            plan: plan,
            metrics: ["reason": reason]
        )
        guard let fallbackRoute else { return }
        await diagnostics.record(
            .fallbackSelected,
            plan: plan,
            route: fallbackRoute,
            metrics: [
                PlaybackMetricKeys.routeKind: fallbackRoute.routeKind.rawValue,
                PlaybackMetricKeys.playMethod: fallbackRoute.playMethod.rawValue
            ]
        )
    }

    private func preloadStartupWindow(
        for plan: PlaybackPlan,
        ioContext: any PlaybackIOContext
    ) async throws -> Int64 {
        guard plan.preloadPolicy.isEnabled,
              plan.primaryRoute.rangeCapability == .supported,
              plan.preloadPolicy.startupBytes > 0,
              plan.startupPolicy.startupPreloadBytes > 0 else {
            return 0
        }
        guard plan.startupPolicy.blocksFirstFrameUntilStartupPreload else {
            await diagnostics.record(
                .preloadCancelled,
                plan: plan,
                route: plan.primaryRoute,
                metrics: [
                    "reason": "first_frame_priority",
                    PlaybackMetricKeys.preloadedBytes: "0"
                ]
            )
            return 0
        }
        let startupBudget = min(
            plan.preloadPolicy.startupBytes,
            plan.startupPolicy.startupPreloadBytes
        )
        let requestedLength = plan.primaryRoute.byteLength.map {
            min($0, startupBudget)
        } ?? startupBudget
        guard requestedLength > 0 else { return 0 }
        let range = PlaybackByteRange(start: 0, length: requestedLength)
        await diagnostics.record(
            .preloadStarted,
            plan: plan,
            route: plan.primaryRoute,
            metrics: ["requestedBytes": metricString(requestedLength)]
        )
        let completedBytes = try await preloadCoordinator.schedule(
            PlaybackPreloadRequest(
                planID: plan.id,
                routeID: plan.primaryRoute.id,
                range: range,
                budgetBytes: requestedLength,
                reason: .startup
            ),
            ioContext: ioContext
        )
        guard completedBytes > 0 else {
            await diagnostics.record(.preloadCancelled, plan: plan, route: plan.primaryRoute,
                metrics: ["reason": "bytesNotMaterialized", "requestedBytes": metricString(requestedLength),
                          PlaybackMetricKeys.preloadedBytes: "0"])
            return 0
        }
        await diagnostics.record(
            .preloadCompleted,
            plan: plan,
            route: plan.primaryRoute,
            metrics: [PlaybackMetricKeys.preloadedBytes: metricString(completedBytes)]
        )
        return completedBytes
    }

    private func approximateByteOffset(
        route: PlaybackRoute,
        timeline: PlaybackTimeline,
        targetSeconds: TimeInterval
    ) -> Int64? {
        guard let byteLength = route.byteLength,
              let duration = timeline.duration,
              byteLength > 0,
              duration > 0 else {
            return nil
        }
        let ratio = min(max(targetSeconds / duration, 0), 1)
        return Int64((Double(byteLength) * ratio).rounded(.down))
    }

    private func elapsedMilliseconds(since date: Date) -> String {
        String(Int(max(Date().timeIntervalSince(date), 0) * 1_000))
    }

    private func metricString(_ value: TimeInterval) -> String {
        String(format: "%.3f", value)
    }

    private func metricString(_ value: Int64) -> String {
        String(value)
    }
}
