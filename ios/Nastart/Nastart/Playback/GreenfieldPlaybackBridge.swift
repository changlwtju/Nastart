import Foundation

enum GreenfieldPlaybackDebugSettings {
    static let useGreenfieldPlayerKey = "debug.playback.use_greenfield_player"
}

#if DEBUG
extension MediaPlaybackRequest {
    func greenfieldPlaybackLaunchRequest() -> GreenfieldPlaybackLaunchRequest {
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

        let startTime = totalDurationSeconds.flatMap { duration in
            initialPosition.map { duration * $0 }
        } ?? (timelineOffsetSeconds > 0 ? timelineOffsetSeconds : nil)
        let audioTrackID = selectedSourceAudioTrackID.map(String.init)
        let subtitleTrackID = prefersSubtitlesDisabled
            ? nil
            : selectedSourceSubtitleTrackID.map(String.init)
        let connectionContext = PlaybackConnectionContext.make(url: networkOriginURL)
        let networkContext = PlaybackNetworkContext(
            networkClass: playbackNetworkClass(
                connectionContext: connectionContext,
                isPrivateRoute: isPrivateNetworkRoute
            ),
            isPrivateRoute: isPrivateNetworkRoute
                ?? isPrivateConnection(connectionContext.addressKind),
            estimatedBitrate: nil,
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
            directURL: url,
            preferredStartTime: startTime,
            preferredAudioTrackID: audioTrackID,
            preferredSubtitleTrackID: subtitleTrackID,
            playbackModePreference: .automatic,
            playbackRate: initialPlaybackRate,
            connectionContext: connectionContext,
            networkContext: networkContext
        )
        return GreenfieldPlaybackLaunchRequest(
            id: intent.id,
            intent: intent,
            fileExtensionHint: fileExtensionHint,
            mimeHint: mimeTypeHint,
            certificatePolicy: allowsSelfSignedCertificates ? .allowPinnedSelfSigned : .systemTrust,
            duration: totalDurationSeconds,
            tracks: tracks,
            subtitles: subtitlePlan(tracks: tracks, selectedSubtitleTrackID: subtitleTrackID)
        )
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
