import Foundation

/// Reconsider a restrictive Wi-Fi sample on a later playback attempt, without
/// probing on every tap or treating a failed sample as proof of more bandwidth.
enum GreenfieldBandwidthSamplePolicy {
    static func canReuse(age: TimeInterval, networkKey: String, wasMeasured: Bool,
                         safeBitrate: Int, originalSourceBitrate: Int?, rawBitrate: Int? = nil) -> Bool {
        let originalBudget = GreenfieldOriginalPlaybackPolicy.maximumOriginalBitrate(
            networkKey: networkKey, wasMeasured: wasMeasured,
            rawBitrate: rawBitrate ?? safeBitrate, conservativeBitrate: safeBitrate)
        let restrictsOriginal = networkKey == "wifi"
            && originalSourceBitrate.map { $0 > 0 && (!wasMeasured || originalBudget < $0) } == true
        let lifetime: TimeInterval = restrictsOriginal ? 30 : 600
        return age >= 0 && age < lifetime
    }
}

/// Original playback is a decoder decision followed by a network decision.
/// Container size alone must not override measured, sufficient Wi-Fi bandwidth.
enum GreenfieldOriginalPlaybackPolicy {
    static func bitmapSubtitleDecoderName(_ codec: String?) -> String? {
        switch codec?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pgssub", "hdmv_pgs_subtitle": return "pgssub"
        case "dvdsub", "dvd_subtitle": return "dvdsub"
        case "dvbsub", "dvb_subtitle": return "dvbsub"
        default: return nil
        }
    }

    /// HLS encoder ceilings are not limits on measured Wi-Fi file delivery.
    /// Do not inflate the sample; retain conservative budgets off Wi-Fi or
    /// when no successful measurement is available.
    static func maximumOriginalBitrate(networkKey: String, wasMeasured: Bool,
                                       rawBitrate: Int, conservativeBitrate: Int) -> Int {
        guard networkKey == "wifi", wasMeasured, rawBitrate > 0 else { return conservativeBitrate }
        return rawBitrate
    }

    static func allowsOriginal(forcedServerBitrate: Int?, audioRequiresTranscode: Bool,
                               subtitleRequiresServer: Bool, routeIsPrivate: Bool,
                               explicitOriginal: Bool, remoteBitrateFits: Bool,
                               experimentalOriginal: Bool = false) -> Bool {
        forcedServerBitrate == nil
            && (!audioRequiresTranscode || experimentalOriginal)
            && (!subtitleRequiresServer || experimentalOriginal)
            && (routeIsPrivate || explicitOriginal || remoteBitrateFits || experimentalOriginal)
    }

    static func audioDecoderName(_ codec: String?) -> String? {
        guard let codec = codec?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !codec.isEmpty else { return nil }
        switch codec {
        case "eac3-joc": return "eac3"
        case "dts-hd", "dtshd", "dts-hd ma": return "dca"
        case "dts": return "dca"
        // "Atmos" describes an extension, not its underlying audio codec.
        case "atmos": return nil
        default: return codec
        }
    }

    static func requiresAudioTranscode(codec: String?, decoderAvailable: Bool) -> Bool {
        guard let codec, !codec.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false // Missing metadata: let the demuxer discover the track.
        }
        return !decoderAvailable
    }

    static func retainsLargeRemoteGuard(networkKey: String, bandwidthBasis: String,
                                        sourceBitrate: Int?, originalBudget: Int) -> Bool {
        guard networkKey == "wifi", bandwidthBasis == "measured",
              let sourceBitrate, sourceBitrate > 0, originalBudget >= sourceBitrate else { return true }
        return false
    }
}

/// Source evidence only. Neither codec recognition nor PCM decoding certifies
/// Dolby rendering or Atmos object output on the current device/audio route.
struct PlaybackDolbySourceInfo: Hashable, Sendable {
    var visionProfile: Int?
    var visionLevel: Int?
    var baseLayerCompatibilityID: Int?
    var audioCodec: String?
    var audioProfile: String?
    var audioSpatialFormat: String?

    var audioEvidence: String {
        let codec = audioCodec?.lowercased() ?? ""
        let profile = audioProfile?.uppercased() ?? ""
        let declaresAtmos = audioSpatialFormat?.lowercased() == "dolbyatmos"
        if codec == "eac3-joc" || (codec == "eac3" && (profile.contains("JOC") || declaresAtmos)) {
            return "eac3JOC"
        }
        if codec == "truehd" || codec == "mlp" {
            return profile.contains("ATMOS") || declaresAtmos ? "trueHDAtmos" : "trueHDAtmosUnknown"
        }
        if codec == "eac3" { return "eac3AtmosUnknown" }
        return "unknown"
    }

    var diagnosticDetails: [String: String] {
        ["sourceDVProfile": visionProfile.map(String.init) ?? "unknown",
         "sourceDVLevel": visionLevel.map(String.init) ?? "unknown",
         "sourceDVCompatibilityID": baseLayerCompatibilityID.map(String.init) ?? "unknown",
         "sourceDolbyAudio": audioEvidence,
         "sourceAudioSpatialFormat": audioSpatialFormat ?? "unknown",
         "dolbyVisionOutput": "unverified", "dolbyAtmosOutput": "unverified"]
    }
}

enum PlaybackSourceResolverError: Error, Equatable {
    case unsupportedSource(PlaybackSourceKind)
    case missingPlayableURL
}

enum PlaybackPlanningPolicy {
    static func makePlan(
        intent: PlaybackIntent,
        url: URL,
        originURL: URL? = nil,
        fileExtensionHint: String? = nil,
        mimeHint: String? = nil,
        certificatePolicy: PlaybackCertificatePolicy = .systemTrust,
        byteLength: Int64? = nil,
        duration: TimeInterval? = nil,
        estimatedBitrate: Int? = nil,
        tracks: TrackCatalog = TrackCatalog(),
        subtitles: SubtitlePlan? = nil,
        alternateRoutes: [PlaybackRoute] = []
    ) -> PlaybackPlan {
        let extensionHint = normalizedExtension(fileExtensionHint, url: url)
        let routeKind = routeKind(
            sourceKind: intent.sourceKind,
            url: url,
            fileExtensionHint: extensionHint
        )
        let playMethod = playMethod(
            sourceKind: intent.sourceKind,
            routeKind: routeKind,
            timelineOffset: intent.preferredStartTime
        )
        let route = PlaybackRoute(
            routeKind: routeKind,
            playMethod: playMethod,
            url: url,
            originURL: originURL,
            certificatePolicy: certificatePolicy,
            containerHint: extensionHint,
            mimeHint: mimeHint,
            duration: duration,
            byteLength: byteLength,
            rangeCapability: rangeCapability(routeKind: routeKind, fileExtensionHint: extensionHint),
            codecSummary: PlaybackCodecSummary(
                container: extensionHint,
                bitrate: estimatedBitrate
            )
        )
        return PlaybackPlan(
            intent: intent,
            timeline: PlaybackTimeline(
                startTime: intent.preferredStartTime ?? 0,
                duration: duration
            ),
            primaryRoute: route,
            alternateRoutes: alternateRoutes,
            tracks: tracks,
            subtitles: subtitles ?? subtitlePlan(from: tracks),
            cachePolicy: cachePolicy(routeKind: routeKind),
            preloadPolicy: preloadPolicy(routeKind: routeKind, intent: intent),
            startupPolicy: startupPolicy(intent: intent, routeKind: routeKind),
            trackSwitchPolicy: trackSwitchPolicy(routeKind: routeKind, subtitles: subtitles ?? subtitlePlan(from: tracks)),
            pictureInPicturePolicy: pictureInPicturePolicy(routeKind: routeKind),
            recoveryPolicy: recoveryPolicy(intent: intent),
            enginePolicy: engineCandidate(
                preference: intent.playbackModePreference,
                routeKind: routeKind,
                fileExtensionHint: extensionHint
            )
        )
    }

    static func routeKind(
        sourceKind: PlaybackSourceKind,
        url: URL,
        fileExtensionHint: String?
    ) -> PlaybackRouteKind {
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        if scheme == "file" {
            return .localFile
        }
        if host == "127.0.0.1" || host == "localhost" {
            return fileExtensionHint == "m3u8" ? .localHLS : .localRangeProxy
        }
        if fileExtensionHint == "m3u8" {
            return sourceKind == .jellyfin ? .serverHLS : .directHTTP
        }
        return .directHTTP
    }

    static func playMethod(
        sourceKind: PlaybackSourceKind,
        routeKind: PlaybackRouteKind,
        timelineOffset: TimeInterval?
    ) -> PlaybackMethod {
        switch routeKind {
        case .serverHLS:
            return sourceKind == .jellyfin ? .serverTranscode : .directStream
        case .localHLS, .remuxedHLS:
            return .localRemux
        case .directHTTP, .localRangeProxy, .localFile:
            return .directPlay
        }
    }

    static func engineCandidate(
        preference: PlaybackModePreference,
        routeKind: PlaybackRouteKind,
        fileExtensionHint: String?
    ) -> PlaybackEngineCandidate {
        switch preference {
        case .system:
            return .systemAVPlayer
        case .localRemux:
            return .localHLS
        case .automatic, .original, .compatible, .external:
            break
        }

        switch routeKind {
        case .serverHLS, .localHLS, .remuxedHLS:
            return .systemAVPlayer
        case .directHTTP, .localRangeProxy, .localFile:
            return .ksPlayer
        }
    }

    static func rangeCapability(
        routeKind: PlaybackRouteKind,
        fileExtensionHint: String?
    ) -> PlaybackRangeCapability {
        if fileExtensionHint == "m3u8" {
            return .unsupported
        }
        switch routeKind {
        case .directHTTP, .localRangeProxy, .localFile:
            return .supported
        case .serverHLS, .localHLS, .remuxedHLS:
            return .unsupported
        }
    }

    static func cachePolicy(routeKind: PlaybackRouteKind) -> PlaybackCachePolicy {
        switch routeKind {
        case .directHTTP, .localRangeProxy:
            return PlaybackCachePolicy(
                isEnabled: true,
                memoryBudgetBytes: 64 * 1024 * 1024,
                diskBudgetBytes: 2 * 1024 * 1024 * 1024,
                preferredWindowBytes: 32 * 1024 * 1024
            )
        case .localFile:
            return PlaybackCachePolicy(isEnabled: false)
        case .serverHLS, .localHLS, .remuxedHLS:
            return PlaybackCachePolicy(
                isEnabled: true,
                memoryBudgetBytes: 32 * 1024 * 1024,
                diskBudgetBytes: 512 * 1024 * 1024,
                preferredWindowBytes: 8 * 1024 * 1024
            )
        }
    }

    static func preloadPolicy(
        routeKind: PlaybackRouteKind,
        intent: PlaybackIntent
    ) -> PlaybackPreloadPolicy {
        if isWeakNetwork(intent.networkContext) {
            switch routeKind {
            case .directHTTP, .localRangeProxy:
                return PlaybackPreloadPolicy(
                    isEnabled: true,
                    startupBytes: 512 * 1024,
                    seekTargetBytes: 2 * 1024 * 1024,
                    nextItemBytes: 16 * 1024 * 1024
                )
            case .serverHLS, .localHLS, .remuxedHLS:
                return PlaybackPreloadPolicy(
                    isEnabled: true,
                    startupBytes: 0,
                    seekTargetBytes: 512 * 1024,
                    nextItemBytes: 8 * 1024 * 1024
                )
            case .localFile:
                return PlaybackPreloadPolicy(isEnabled: false)
            }
        }

        switch routeKind {
        case .directHTTP, .localRangeProxy:
            return PlaybackPreloadPolicy(
                isEnabled: true,
                startupBytes: 16 * 1024 * 1024,
                seekTargetBytes: 8 * 1024 * 1024,
                nextItemBytes: 200 * 1024 * 1024
            )
        case .serverHLS, .localHLS, .remuxedHLS:
            return PlaybackPreloadPolicy(
                isEnabled: true,
                startupBytes: 4 * 1024 * 1024,
                seekTargetBytes: 2 * 1024 * 1024,
                nextItemBytes: 32 * 1024 * 1024
            )
        case .localFile:
            return PlaybackPreloadPolicy(isEnabled: false)
        }
    }

    static func startupPolicy(
        intent: PlaybackIntent,
        routeKind: PlaybackRouteKind
    ) -> PlaybackStartupPolicy {
        if isWeakNetwork(intent.networkContext) {
            return PlaybackStartupPolicy(
                firstFrameTargetMs: 3_000,
                startupPreloadBytes: routeKind == .localFile ? 0 : 512 * 1024,
                minimumPlayableBufferSeconds: 0.75,
                blocksFirstFrameUntilStartupPreload: false,
                defersNextItemPreloadUntilFirstFrame: true
            )
        }

        switch (routeKind, intent.connectionContext.addressKind) {
        case (.directHTTP, .privateIP), (.directHTTP, .localDomain), (.localRangeProxy, _):
            return PlaybackStartupPolicy(
                firstFrameTargetMs: 1_500,
                startupPreloadBytes: 4 * 1024 * 1024,
                minimumPlayableBufferSeconds: 1,
                blocksFirstFrameUntilStartupPreload: true,
                defersNextItemPreloadUntilFirstFrame: true
            )
        case (.serverHLS, _), (.localHLS, _), (.remuxedHLS, _):
            return PlaybackStartupPolicy(
                firstFrameTargetMs: 2_000,
                startupPreloadBytes: 0,
                minimumPlayableBufferSeconds: 1.25,
                blocksFirstFrameUntilStartupPreload: false,
                defersNextItemPreloadUntilFirstFrame: true
            )
        case (.localFile, _):
            return PlaybackStartupPolicy(
                firstFrameTargetMs: 800,
                startupPreloadBytes: 0,
                minimumPlayableBufferSeconds: 0,
                blocksFirstFrameUntilStartupPreload: false,
                defersNextItemPreloadUntilFirstFrame: false
            )
        default:
            return PlaybackStartupPolicy()
        }
    }

    static func trackSwitchPolicy(
        routeKind: PlaybackRouteKind,
        subtitles: SubtitlePlan
    ) -> PlaybackTrackSwitchPolicy {
        PlaybackTrackSwitchPolicy(
            prefersEngineNativeSwitch: routeKind != .serverHLS,
            allowsRouteRebuild: true,
            targetRecoveryMs: subtitles.mode == .serverBurnIn ? 1_500 : 700,
            prewarmsExternalSubtitles: subtitles.mode == .externalText || subtitles.mode == .uiOverlay
        )
    }

    static func pictureInPicturePolicy(routeKind: PlaybackRouteKind) -> PlaybackPictureInPicturePolicy {
        switch routeKind {
        case .serverHLS, .localHLS, .remuxedHLS:
            return PlaybackPictureInPicturePolicy(
                isEnabled: true,
                requiresSystemRenderer: true,
                allowsRendererSwap: false
            )
        case .directHTTP, .localRangeProxy, .localFile:
            return PlaybackPictureInPicturePolicy(
                isEnabled: true,
                requiresSystemRenderer: true,
                allowsRendererSwap: true
            )
        }
    }

    static func recoveryPolicy(intent: PlaybackIntent) -> PlaybackRecoveryPolicy {
        if isWeakNetwork(intent.networkContext) {
            return PlaybackRecoveryPolicy(
                rebufferWarningSeconds: 1,
                stallBeforeRouteRetrySeconds: 5,
                maximumRouteRetryCount: 3
            )
        }
        return PlaybackRecoveryPolicy()
    }

    static func subtitlePlan(from tracks: TrackCatalog) -> SubtitlePlan {
        guard let selectedID = tracks.selectedSourceSubtitleTrackID else {
            return SubtitlePlan(mode: .disabled)
        }
        let selectedTrack = tracks.sourceSubtitleTracks.first { $0.id == selectedID }
        if selectedTrack?.externalURL != nil {
            return SubtitlePlan(
                mode: .externalText,
                primarySubtitleID: selectedID,
                normalization: "utf8-text"
            )
        }
        return SubtitlePlan(mode: .embedded, primarySubtitleID: selectedID)
    }

    static func normalizedExtension(_ fileExtensionHint: String?, url: URL) -> String? {
        if let fileExtensionHint,
           !fileExtensionHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fileExtensionHint.lowercased()
        }
        let urlExtension = url.pathExtension.lowercased()
        return urlExtension.isEmpty ? nil : urlExtension
    }

    private static func isWeakNetwork(_ context: PlaybackNetworkContext) -> Bool {
        context.networkClass == .cellular
            || context.networkClass == .constrained
            || context.isExpensive
            || context.isConstrained
    }
}
