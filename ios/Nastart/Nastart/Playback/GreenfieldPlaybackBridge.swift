import Foundation

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
        playbackModePreference: PlaybackModePreference = .automatic
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
        let startTime = totalDurationSeconds.flatMap { duration in
            initialPosition.map { duration * $0 }
        } ?? (timelineOffsetSeconds > 0 ? timelineOffsetSeconds : nil)
        let audioTrackID = selectedSourceAudioTrackID.map(String.init)
        let subtitleTrackID = prefersSubtitlesDisabled
            ? nil
            : selectedSourceSubtitleTrackID.map(String.init)
        let connectionContext = PlaybackConnectionContext.make(url: primaryURL)
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
            duration: totalDurationSeconds,
            estimatedBitrate: estimatedBitrate,
            tracks: tracks,
            subtitles: subtitlePlan(tracks: tracks, selectedSubtitleTrackID: subtitleTrackID),
            mediaRequest: self
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
        if isPrivateRoute == true || isPrivateConnection(connectionContext.addressKind) {
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
