import Foundation

enum PlaybackEngineCandidate: String, Codable, Sendable {
    case ksPlayer
    case systemAVPlayer
    case localHLS
}

enum PlaybackSeekMode: String, Codable, Sendable {
    case fast
    case accurate
    case keyframeBackward
}

enum PlaybackSubtitleMode: String, Codable, Sendable {
    case embedded
    case externalText
    case serverBurnIn
    case uiOverlay
    case disabled
}

struct PlaybackTimeline: Codable, Equatable, Sendable {
    var startTime: TimeInterval
    var duration: TimeInterval?
    var offset: TimeInterval

    init(startTime: TimeInterval = 0, duration: TimeInterval? = nil, offset: TimeInterval = 0) {
        self.startTime = max(startTime, 0)
        self.duration = duration.flatMap { $0 > 0 ? $0 : nil }
        self.offset = max(offset, 0)
    }
}

struct PlaybackTrack: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var index: Int?
    var title: String
    var languageCode: String?
    var codec: String?
    var isDefault: Bool
    var isForced: Bool
    var externalURL: URL?

    init(
        id: String,
        index: Int? = nil,
        title: String,
        languageCode: String? = nil,
        codec: String? = nil,
        isDefault: Bool = false,
        isForced: Bool = false,
        externalURL: URL? = nil
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.languageCode = languageCode
        self.codec = codec
        self.isDefault = isDefault
        self.isForced = isForced
        self.externalURL = externalURL
    }
}

struct TrackCatalog: Codable, Equatable, Sendable {
    var sourceAudioTracks: [PlaybackTrack]
    var sourceSubtitleTracks: [PlaybackTrack]
    var selectedSourceAudioTrackID: String?
    var selectedSourceSubtitleTrackID: String?

    init(
        sourceAudioTracks: [PlaybackTrack] = [],
        sourceSubtitleTracks: [PlaybackTrack] = [],
        selectedSourceAudioTrackID: String? = nil,
        selectedSourceSubtitleTrackID: String? = nil
    ) {
        self.sourceAudioTracks = sourceAudioTracks
        self.sourceSubtitleTracks = sourceSubtitleTracks
        self.selectedSourceAudioTrackID = selectedSourceAudioTrackID
        self.selectedSourceSubtitleTrackID = selectedSourceSubtitleTrackID
    }
}

struct SubtitlePlan: Codable, Equatable, Sendable {
    var mode: PlaybackSubtitleMode
    var primarySubtitleID: String?
    var secondarySubtitleID: String?
    var normalization: String?
    var fontPolicy: String?
    var safeAreaPolicy: String?

    init(
        mode: PlaybackSubtitleMode = .embedded,
        primarySubtitleID: String? = nil,
        secondarySubtitleID: String? = nil,
        normalization: String? = nil,
        fontPolicy: String? = nil,
        safeAreaPolicy: String? = nil
    ) {
        self.mode = mode
        self.primarySubtitleID = primarySubtitleID
        self.secondarySubtitleID = secondarySubtitleID
        self.normalization = normalization
        self.fontPolicy = fontPolicy
        self.safeAreaPolicy = safeAreaPolicy
    }
}

struct PlaybackCachePolicy: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var memoryBudgetBytes: Int64
    var diskBudgetBytes: Int64
    var preferredWindowBytes: Int64

    init(
        isEnabled: Bool = true,
        memoryBudgetBytes: Int64 = 64 * 1024 * 1024,
        diskBudgetBytes: Int64 = 2 * 1024 * 1024 * 1024,
        preferredWindowBytes: Int64 = 32 * 1024 * 1024
    ) {
        self.isEnabled = isEnabled
        self.memoryBudgetBytes = max(memoryBudgetBytes, 0)
        self.diskBudgetBytes = max(diskBudgetBytes, 0)
        self.preferredWindowBytes = max(preferredWindowBytes, 0)
    }
}

struct PlaybackPreloadPolicy: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var startupBytes: Int64
    var seekTargetBytes: Int64
    var nextItemBytes: Int64

    init(
        isEnabled: Bool = true,
        startupBytes: Int64 = 16 * 1024 * 1024,
        seekTargetBytes: Int64 = 8 * 1024 * 1024,
        nextItemBytes: Int64 = 200 * 1024 * 1024
    ) {
        self.isEnabled = isEnabled
        self.startupBytes = max(startupBytes, 0)
        self.seekTargetBytes = max(seekTargetBytes, 0)
        self.nextItemBytes = max(nextItemBytes, 0)
    }
}

struct PlaybackStartupPolicy: Codable, Equatable, Sendable {
    var firstFrameTargetMs: Int
    var startupPreloadBytes: Int64
    var minimumPlayableBufferSeconds: TimeInterval
    var blocksFirstFrameUntilStartupPreload: Bool
    var defersNextItemPreloadUntilFirstFrame: Bool

    init(
        firstFrameTargetMs: Int = 2_000,
        startupPreloadBytes: Int64 = 4 * 1024 * 1024,
        minimumPlayableBufferSeconds: TimeInterval = 1.5,
        blocksFirstFrameUntilStartupPreload: Bool = false,
        defersNextItemPreloadUntilFirstFrame: Bool = true
    ) {
        self.firstFrameTargetMs = max(firstFrameTargetMs, 250)
        self.startupPreloadBytes = max(startupPreloadBytes, 0)
        self.minimumPlayableBufferSeconds = max(minimumPlayableBufferSeconds, 0)
        self.blocksFirstFrameUntilStartupPreload = blocksFirstFrameUntilStartupPreload
        self.defersNextItemPreloadUntilFirstFrame = defersNextItemPreloadUntilFirstFrame
    }
}

struct PlaybackTrackSwitchPolicy: Codable, Equatable, Sendable {
    var prefersEngineNativeSwitch: Bool
    var allowsRouteRebuild: Bool
    var targetRecoveryMs: Int
    var prewarmsExternalSubtitles: Bool

    init(
        prefersEngineNativeSwitch: Bool = true,
        allowsRouteRebuild: Bool = true,
        targetRecoveryMs: Int = 700,
        prewarmsExternalSubtitles: Bool = true
    ) {
        self.prefersEngineNativeSwitch = prefersEngineNativeSwitch
        self.allowsRouteRebuild = allowsRouteRebuild
        self.targetRecoveryMs = max(targetRecoveryMs, 100)
        self.prewarmsExternalSubtitles = prewarmsExternalSubtitles
    }
}

struct PlaybackPictureInPicturePolicy: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var requiresSystemRenderer: Bool
    var allowsRendererSwap: Bool

    init(
        isEnabled: Bool = true,
        requiresSystemRenderer: Bool = false,
        allowsRendererSwap: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.requiresSystemRenderer = requiresSystemRenderer
        self.allowsRendererSwap = allowsRendererSwap
    }
}

struct PlaybackRecoveryPolicy: Codable, Equatable, Sendable {
    var rebufferWarningSeconds: TimeInterval
    var stallBeforeRouteRetrySeconds: TimeInterval
    var maximumRouteRetryCount: Int

    init(
        rebufferWarningSeconds: TimeInterval = 2,
        stallBeforeRouteRetrySeconds: TimeInterval = 8,
        maximumRouteRetryCount: Int = 2
    ) {
        self.rebufferWarningSeconds = max(rebufferWarningSeconds, 0)
        self.stallBeforeRouteRetrySeconds = max(stallBeforeRouteRetrySeconds, 0)
        self.maximumRouteRetryCount = max(maximumRouteRetryCount, 0)
    }
}

struct PlaybackDiagnosticsContext: Codable, Equatable, Sendable {
    var planID: UUID
    var sourceKind: PlaybackSourceKind
    var routeKind: PlaybackRouteKind
    var playMethod: PlaybackMethod
    var engineCandidate: PlaybackEngineCandidate
    var networkClass: PlaybackNetworkClass

    init(
        planID: UUID,
        sourceKind: PlaybackSourceKind,
        routeKind: PlaybackRouteKind,
        playMethod: PlaybackMethod,
        engineCandidate: PlaybackEngineCandidate,
        networkClass: PlaybackNetworkClass
    ) {
        self.planID = planID
        self.sourceKind = sourceKind
        self.routeKind = routeKind
        self.playMethod = playMethod
        self.engineCandidate = engineCandidate
        self.networkClass = networkClass
    }
}

struct PlaybackPlan: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var intent: PlaybackIntent
    var timeline: PlaybackTimeline
    var primaryRoute: PlaybackRoute
    var alternateRoutes: [PlaybackRoute]
    var tracks: TrackCatalog
    var subtitles: SubtitlePlan
    var cachePolicy: PlaybackCachePolicy
    var preloadPolicy: PlaybackPreloadPolicy
    var startupPolicy: PlaybackStartupPolicy
    var trackSwitchPolicy: PlaybackTrackSwitchPolicy
    var pictureInPicturePolicy: PlaybackPictureInPicturePolicy
    var recoveryPolicy: PlaybackRecoveryPolicy
    var enginePolicy: PlaybackEngineCandidate
    var diagnostics: PlaybackDiagnosticsContext

    init(
        id: UUID = UUID(),
        intent: PlaybackIntent,
        timeline: PlaybackTimeline,
        primaryRoute: PlaybackRoute,
        alternateRoutes: [PlaybackRoute] = [],
        tracks: TrackCatalog = TrackCatalog(),
        subtitles: SubtitlePlan = SubtitlePlan(),
        cachePolicy: PlaybackCachePolicy = PlaybackCachePolicy(),
        preloadPolicy: PlaybackPreloadPolicy = PlaybackPreloadPolicy(),
        startupPolicy: PlaybackStartupPolicy = PlaybackStartupPolicy(),
        trackSwitchPolicy: PlaybackTrackSwitchPolicy = PlaybackTrackSwitchPolicy(),
        pictureInPicturePolicy: PlaybackPictureInPicturePolicy = PlaybackPictureInPicturePolicy(),
        recoveryPolicy: PlaybackRecoveryPolicy = PlaybackRecoveryPolicy(),
        enginePolicy: PlaybackEngineCandidate = .ksPlayer
    ) {
        self.id = id
        self.intent = intent
        self.timeline = timeline
        self.primaryRoute = primaryRoute
        self.alternateRoutes = alternateRoutes
        self.tracks = tracks
        self.subtitles = subtitles
        self.cachePolicy = cachePolicy
        self.preloadPolicy = preloadPolicy
        self.startupPolicy = startupPolicy
        self.trackSwitchPolicy = trackSwitchPolicy
        self.pictureInPicturePolicy = pictureInPicturePolicy
        self.recoveryPolicy = recoveryPolicy
        self.enginePolicy = enginePolicy
        diagnostics = PlaybackDiagnosticsContext(
            planID: id,
            sourceKind: intent.sourceKind,
            routeKind: primaryRoute.routeKind,
            playMethod: primaryRoute.playMethod,
            engineCandidate: enginePolicy,
            networkClass: intent.networkContext.networkClass
        )
    }
}
