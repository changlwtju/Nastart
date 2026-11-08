import Foundation

struct URLPlaybackSourceResolver: PlaybackSourceResolver {
    let sourceKind: PlaybackSourceKind
    var originURL: URL?
    var fileExtensionHint: String?
    var mimeHint: String?
    var certificatePolicy: PlaybackCertificatePolicy
    var byteLength: Int64?
    var duration: TimeInterval?
    var estimatedBitrate: Int?
    var tracks: TrackCatalog
    var subtitles: SubtitlePlan?
    var alternateRoutes: [PlaybackRoute]

    init(
        sourceKind: PlaybackSourceKind = .directURL,
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
    ) {
        self.sourceKind = sourceKind
        self.originURL = originURL
        self.fileExtensionHint = fileExtensionHint
        self.mimeHint = mimeHint
        self.certificatePolicy = certificatePolicy
        self.byteLength = byteLength
        self.duration = duration
        self.estimatedBitrate = estimatedBitrate
        self.tracks = tracks
        self.subtitles = subtitles
        self.alternateRoutes = alternateRoutes
    }

    func resolve(_ intent: PlaybackIntent) async throws -> PlaybackPlan {
        guard intent.sourceKind == sourceKind else {
            throw PlaybackSourceResolverError.unsupportedSource(intent.sourceKind)
        }
        guard let url = intent.directURL else {
            throw PlaybackSourceResolverError.missingPlayableURL
        }
        return PlaybackPlanningPolicy.makePlan(
            intent: intent,
            url: url,
            originURL: originURL,
            fileExtensionHint: fileExtensionHint,
            mimeHint: mimeHint,
            certificatePolicy: certificatePolicy,
            byteLength: byteLength,
            duration: duration,
            estimatedBitrate: estimatedBitrate,
            tracks: tracks,
            subtitles: subtitles,
            alternateRoutes: alternateRoutes
        )
    }
}
