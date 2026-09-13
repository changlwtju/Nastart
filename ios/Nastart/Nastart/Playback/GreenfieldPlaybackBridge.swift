import Foundation
import CryptoKit


/// Only file identity hashes and playback preferences are persisted, never URLs
/// carrying DSM sessions. Different accounts/files/revisions cannot share a bookmark.
final class LocalPlaybackResumeStore {
    struct Entry: Codable {
        let positionSeconds: Double
        let durationSeconds: Double
        let audioTrackID: Int?
        let subtitleTrackID: Int?
        let subtitlesDisabled: Bool
        let updatedAt: Date
    }
    static let shared = LocalPlaybackResumeStore()
    private let defaults: UserDefaults
    private let lock = NSLock()
    private let storageKey = "playback.localResume.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    static func key(server: URL, account: String, path: String, byteLength: Int64?, modifiedAt: Date?) -> String {
        var components = URLComponents(url: server, resolvingAgainstBaseURL: false)
        components?.user = nil; components?.password = nil
        components?.query = nil; components?.fragment = nil
        let host = components?.host?.lowercased()
        components?.host = host
        let identity = [components?.string ?? "", account, path,
                        byteLength.map(String.init) ?? "", modifiedAt.map { String($0.timeIntervalSince1970) } ?? ""]
        let data = (try? JSONEncoder().encode(identity)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func entry(for key: String) -> Entry? {
        lock.lock(); defer { lock.unlock() }
        return entries()[key]
    }

    func save(key: String, position: Double, duration: Double, audioTrackID: Int?, subtitleTrackID: Int?, subtitlesDisabled: Bool) {
        guard position.isFinite, position >= 0, duration.isFinite, duration > 0 else { return }
        lock.lock(); defer { lock.unlock() }
        var values = entries()
        let finished = duration - position <= min(30, duration * 0.02)
        values[key] = Entry(positionSeconds: finished ? 0 : min(position, duration), durationSeconds: duration,
                            audioTrackID: audioTrackID, subtitleTrackID: subtitleTrackID,
                            subtitlesDisabled: subtitlesDisabled, updatedAt: Date())
        if values.count > 128 {
            for key in values.sorted(by: { $0.value.updatedAt > $1.value.updatedAt }).dropFirst(128).map(\.key) { values.removeValue(forKey: key) }
        }
        if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: storageKey) }
    }

    private func entries() -> [String: Entry] {
        guard let data = defaults.data(forKey: storageKey),
              let values = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return values.filter { $0.value.positionSeconds.isFinite && $0.value.positionSeconds >= 0
            && $0.value.durationSeconds.isFinite && $0.value.durationSeconds > 0 }
    }
}

enum GreenfieldPlaybackDebugSettings {
    static let useGreenfieldPlayerKey = "debug.playback.use_greenfield_player"
}

#if DEBUG
import SwiftUI

/// One shared architecture choice for Jellyfin, device files, and direct URLs.
/// Original-stream selection belongs to routing policy, not architecture UI.
struct PlaybackArchitecturePicker: View {
    @Binding var usesGreenfieldPlayer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("player.architecture.title")
                .font(.subheadline.weight(.semibold))
            Picker("player.architecture.title", selection: $usesGreenfieldPlayer) {
                Text("player.architecture.new").tag(true)
                Text("player.architecture.legacy").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("playbackArchitecturePicker")
            Text("player.architecture.hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

extension MediaPlaybackRequest {
    func greenfieldPlaybackLaunchRequest(
        playbackModePreference: PlaybackModePreference = .automatic,
        resumeStore: LocalPlaybackResumeStore = .shared
    ) -> GreenfieldPlaybackLaunchRequest {
        let sourceKind: PlaybackSourceKind
        switch source {
        case .directURL:
            sourceKind = .directURL
        case .dsmFile:
            sourceKind = .dsmFile
        case .jellyfin:
            sourceKind = .jellyfin
        }

        let contentKind: PlaybackContentKind
        switch self.contentKind {
        case .automatic:
            contentKind = .automatic
        case .video:
            contentKind = .video
        case .audio:
            contentKind = .audio
        case .discImage:
            contentKind = .discImage
        }

        let primaryResource = greenfieldPrimaryResource()
        let primaryURL = primaryResource?.url ?? url
        let primaryExtensionHint = primaryResource?.fileExtensionOverride ?? fileExtensionHint
        let primaryCertificatePolicy = certificatePolicy(for: primaryResource)
        let saved = source == .dsmFile ? localResumeKey.flatMap { resumeStore.entry(for: $0) } : nil
        let playbackDuration = totalDurationSeconds ?? saved?.durationSeconds
        let startTime = playbackDuration.flatMap { duration in
            initialPosition.map { duration * $0 }
        } ?? (timelineOffsetSeconds > 0 ? timelineOffsetSeconds : saved?.positionSeconds)
        let audioTrackID = (selectedSourceAudioTrackID ?? saved?.audioTrackID).map(String.init)
        let disablesSubtitles = prefersSubtitlesDisabled || saved?.subtitlesDisabled == true
        let subtitleTrackID = disablesSubtitles
            ? nil
            : (selectedSourceSubtitleTrackID ?? saved?.subtitleTrackID).map(String.init)
        // A loopback renderer URL describes our transport adapter, not the
        // network delivering the video. Preserve the NAS origin for policy.
        let connectionContext = PlaybackConnectionContext.make(
            url: isLoopbackProxy(primaryURL) ? networkOriginURL : primaryURL
        )
        let networkContext = PlaybackNetworkContext(
            networkClass: playbackNetworkClass(
                connectionContext: connectionContext,
                isPrivateRoute: isPrivateNetworkRoute
            ),
            isPrivateRoute: isPrivateNetworkRoute
                ?? isPrivateConnection(connectionContext.addressKind),
            estimatedBitrate: estimatedBitrate,
            isExpensive: false,
            isConstrained: false
        )
        var restoredRequest = self
        if saved != nil {
            restoredRequest.prefersSubtitlesDisabled = disablesSubtitles
            restoredRequest.selectedSourceAudioTrackID = audioTrackID.flatMap(Int.init)
            restoredRequest.selectedSourceSubtitleTrackID = subtitleTrackID.flatMap(Int.init)
            if let playbackDuration, let startTime, playbackDuration > 0 {
                restoredRequest.totalDurationSeconds = playbackDuration
                restoredRequest.initialPosition = startTime / playbackDuration
            }
        }
        let tracks = TrackCatalog(
            sourceAudioTracks: sourceAudioTracks.map {
                PlaybackTrack(
                    id: String($0.id),
                    index: $0.id,
                    title: $0.name,
                    externalURL: $0.externalURL
                )
            },
            sourceSubtitleTracks: sourceSubtitleTracks.map {
                PlaybackTrack(
                    id: String($0.id),
                    index: $0.id,
                    title: $0.name,
                    externalURL: $0.externalURL
                )
            },
            selectedSourceAudioTrackID: audioTrackID,
            selectedSourceSubtitleTrackID: subtitleTrackID
        )

        let intent = PlaybackIntent(
            sourceKind: sourceKind,
            contentKind: contentKind,
            itemIdentity: PlaybackItemIdentity(
                sourceKind: sourceKind,
                stablePath: networkOriginURL.path.isEmpty ? nil : networkOriginURL.path
            ),
            displayTitle: title,
            directURL: primaryURL,
            preferredStartTime: startTime,
            preferredAudioTrackID: audioTrackID,
            preferredSubtitleTrackID: subtitleTrackID,
            playbackModePreference: playbackModePreference,
            playbackRate: initialPlaybackRate,
            connectionContext: connectionContext,
            networkContext: networkContext
        )
        return GreenfieldPlaybackLaunchRequest(
            id: intent.id,
            intent: intent,
            orientationMode: initialOrientationMode,
            playbackTraceID: playbackTraceID ?? String(intent.id.uuidString.prefix(8)),
            fileExtensionHint: primaryExtensionHint,
            mimeHint: mimeTypeHint,
            certificatePolicy: primaryCertificatePolicy,
            alternateRoutes: greenfieldAlternateRoutes(
                intent: intent,
                primaryURL: primaryURL,
                sourceKind: sourceKind
            ),
            byteLength: byteLength,
            duration: playbackDuration,
            estimatedBitrate: estimatedBitrate,
            tracks: tracks,
            subtitles: disablesSubtitles ? SubtitlePlan(mode: .disabled) : subtitlePlan(tracks: tracks, selectedSubtitleTrackID: subtitleTrackID),
            mediaRequest: restoredRequest
        )
    }

    private func greenfieldPrimaryResource() -> MediaPlaybackResource? {
        let extensionHint = fileExtensionHint
        guard source == .directURL,
              extensionHint != "m3u8",
              isLoopbackProxy(url),
              let externalHandoffResource,
              isHTTPPlaybackURL(externalHandoffResource.url)
        else {
            return nil
        }
        return externalHandoffResource
    }

    private func greenfieldAlternateRoutes(
        intent: PlaybackIntent,
        primaryURL: URL,
        sourceKind: PlaybackSourceKind
    ) -> [PlaybackRoute] {
        var resources: [MediaPlaybackResource] = []
        if source == .directURL, let externalHandoffResource {
            resources.append(externalHandoffResource)
        }
        if let compatibilityResource {
            resources.append(compatibilityResource)
        }
        if let compatibilityFallbackResource {
            resources.append(compatibilityFallbackResource)
        }
        resources.append(
            MediaPlaybackResource(
                url: url,
                fileExtensionOverride: fileExtensionHint.isEmpty ? nil : fileExtensionHint,
                subtitleURL: externalSubtitleURL,
                allowsSelfSignedCertificates: allowsSelfSignedCertificates
            )
        )

        var seen = Set([primaryURL.absoluteString])
        return resources.compactMap { resource -> PlaybackRoute? in
            let extensionHint = resource.fileExtensionOverride
                ?? (fileExtensionHint.isEmpty ? nil : fileExtensionHint)
            guard isHTTPPlaybackURL(resource.url),
                  !(extensionHint != "m3u8" && isLoopbackProxy(resource.url)),
                  seen.insert(resource.url.absoluteString).inserted
            else {
                return nil
            }
            let routeKind = PlaybackPlanningPolicy.routeKind(
                sourceKind: sourceKind,
                url: resource.url,
                fileExtensionHint: extensionHint
            )
            let playMethod = PlaybackPlanningPolicy.playMethod(
                sourceKind: sourceKind,
                routeKind: routeKind,
                timelineOffset: intent.preferredStartTime
            )
            return PlaybackRoute(
                routeKind: routeKind,
                playMethod: playMethod,
                url: resource.url,
                originURL: networkOriginURL,
                certificatePolicy: certificatePolicy(for: resource),
                containerHint: extensionHint,
                mimeHint: mimeTypeHint,
                duration: resource.totalDurationSeconds ?? totalDurationSeconds,
                byteLength: byteLength,
                rangeCapability: PlaybackPlanningPolicy.rangeCapability(
                    routeKind: routeKind,
                    fileExtensionHint: extensionHint
                ),
                codecSummary: PlaybackCodecSummary(
                    container: extensionHint,
                    bitrate: estimatedBitrate
                )
            )
        }
    }

    private func certificatePolicy(for resource: MediaPlaybackResource?) -> PlaybackCertificatePolicy {
        (resource?.allowsSelfSignedCertificates ?? allowsSelfSignedCertificates)
            ? .allowPinnedSelfSigned
            : .systemTrust
    }

    private func isLoopbackProxy(_ url: URL) -> Bool {
        let host = url.host?.lowercased()
        return host == "127.0.0.1" || host == "localhost"
    }

    private func isHTTPPlaybackURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https" || scheme == "file"
    }

    private func subtitlePlan(
        tracks: TrackCatalog,
        selectedSubtitleTrackID: String?
    ) -> SubtitlePlan {
        if prefersSubtitlesDisabled {
            return SubtitlePlan(mode: .disabled)
        }
        if let selectedSubtitleTrackID {
            let selectedSubtitle = tracks.sourceSubtitleTracks.first {
                $0.id == selectedSubtitleTrackID
            }
            return SubtitlePlan(
                mode: selectedSubtitle?.externalURL == nil ? .embedded : .externalText,
                primarySubtitleID: selectedSubtitleTrackID,
                normalization: selectedSubtitle?.externalURL == nil ? nil : "utf8-text"
            )
        }
        if externalSubtitleURL != nil {
            return SubtitlePlan(
                mode: .externalText,
                primarySubtitleID: "external",
                normalization: "utf8-text"
            )
        }
        return SubtitlePlan(mode: .disabled)
    }

    private func playbackNetworkClass(
        connectionContext: PlaybackConnectionContext,
        isPrivateRoute: Bool?
    ) -> PlaybackNetworkClass {
        if let isPrivateRoute { return isPrivateRoute ? .local : .unknown }
        if isPrivateConnection(connectionContext.addressKind) {
            return .local
        }
        return .unknown
    }

    private func isPrivateConnection(_ addressKind: PlaybackConnectionAddressKind) -> Bool {
        switch addressKind {
        case .loopback, .privateIP, .localDomain:
            return true
        case .publicIP, .publicDomain, .unknown:
            return false
        }
    }
}
#endif
