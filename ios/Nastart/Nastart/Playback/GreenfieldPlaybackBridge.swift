import Foundation
import CryptoKit
import Combine

/// The player and tests use this same save boundary. Observation does not change
/// the existing guards, selection derivation, cadence or UserDefaults durability.
@MainActor
enum PlaybackLocalResumeCheckpoint {
    struct Observation {
        /// Preserve the player's existing meaning: its guards permitted a store call.
        let enteredStore: Bool
        let fields: [String: String]
    }

    static func save(controls: GreenfieldPlaybackControls, request: MediaPlaybackRequest,
                     store: LocalPlaybackResumeStore = .shared, observeMemory: Bool = false) -> Observation {
        var fields = controls.resumePersistenceDiagnostics
        fields["sourceKind"] = request.source.rawValue
        fields["hasResumeKey"] = String(request.localResumeKey != nil)
        guard (request.source != .directURL || request.networkSource != nil), let key = request.localResumeKey,
              controls.canPersistResumeProgress else {
            fields["saveOutcome"] = "skipped"
            fields["skipReason"] = request.source == .directURL ? "directURL"
                : request.localResumeKey == nil ? "missingResumeKey" : "unconfirmedTimeline"
            fields["memoryReadback"] = "notObserved"
            return Observation(enteredStore: false, fields: fields)
        }
        let state = controls.runtimeState(orientationMode: request.initialOrientationMode)
        let subtitleTrackID: Int?
        if let externalURL = state.activeExternalSubtitleURL {
            subtitleTrackID = request.sourceSubtitleTrackID(forExternalURL: externalURL)
        } else {
            subtitleTrackID = state.sourceSubtitleStreamIndex ?? (!request.sourceSubtitleTracks.isEmpty
                ? state.subtitleTrackOrdinal.flatMap { request.sourceSubtitleTracks.indices.contains($0) && request.sourceSubtitleTracks[$0].id >= 0 ? request.sourceSubtitleTracks[$0].id : nil }
                : (controls.selectedSubtitleTrackID >= 0 ? Int(controls.selectedSubtitleTrackID) : nil))
        }
        let audioTrackID = state.sourceAudioStreamIndex ?? (!request.sourceAudioTracks.isEmpty
            ? state.audioTrackOrdinal.flatMap { request.sourceAudioTracks.indices.contains($0) ? request.sourceAudioTracks[$0].id : nil }
            : (controls.selectedAudioTrackID >= 0 ? Int(controls.selectedAudioTrackID) : nil))
        let disabled = state.subtitleSelectionKnown && state.subtitlesDisabled && !controls.pipExternalSubtitle.isEnabled
        let observation = store.save(key: key, position: controls.preciseCurrentSeconds,
            duration: controls.durationSeconds, audioTrackID: audioTrackID,
            subtitleTrackID: subtitleTrackID, subtitlesDisabled: disabled, observeMemory: observeMemory)
        fields["saveOutcome"] = observation.status.rawValue
        fields["skipReason"] = "none"
        fields["memoryReadback"] = observation.memoryReadbackMatches.map { $0 ? "match" : "mismatch" } ?? "notObserved"
        fields["entryUpdatedAtReferenceSeconds"] = observation.entryUpdatedAt.map { String($0.timeIntervalSinceReferenceDate) } ?? "unknown"
        fields["audioTrackID"] = audioTrackID.map(String.init) ?? "none"
        fields["subtitleTrackID"] = subtitleTrackID.map(String.init) ?? "none"
        fields["subtitleSelectionKnown"] = String(state.subtitleSelectionKnown)
        fields["subtitlesDisabled"] = String(disabled)
        fields["externalSubtitleActive"] = String(state.activeExternalSubtitleURL != nil)
        fields["durabilityEvidence"] = "sameProcessOnly"
        return Observation(enteredStore: true, fields: fields)
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

#endif

extension MediaPlaybackRequest {
    func greenfieldPlaybackLaunchRequest(
        playbackModePreference: PlaybackModePreference = .automatic,
        resumeStore: LocalPlaybackResumeStore = .shared,
        proxyRouteLease: PlaybackProxyRouteLease? = nil
    ) -> GreenfieldPlaybackLaunchRequest {
        let sourceKind: PlaybackSourceKind
        switch source {
        case .directURL:
            sourceKind = networkSource == nil ? .directURL : .webDAVFile
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
        // Only an original entry restores the saved selection. A negotiated
        // replacement already carries the live position and exact source tracks.
        let saved = (source == .dsmFile || networkSource != nil) && sourceTrackRequestLoader == nil && timelineOffsetSeconds == 0
            ? localResumeKey.flatMap { resumeStore.entry(for: $0) } : nil
        let playbackDuration = totalDurationSeconds ?? saved?.durationSeconds
        let startTime = playbackDuration.flatMap { duration in
            initialPosition.map { duration * $0 }
        } ?? (timelineOffsetSeconds > 0 ? timelineOffsetSeconds : saved?.positionSeconds)
        let audioTrackID = (selectedSourceAudioTrackID ?? saved?.audioTrackID).map(String.init)
        let disablesSubtitles = greenfieldSubtitlesDisabled || saved?.subtitlesDisabled == true
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
                stablePath: networkSource?.stableID ?? (networkOriginURL.path.isEmpty ? nil : networkOriginURL.path)
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
            mediaRequest: restoredRequest,
            proxyRouteLease: proxyRouteLease
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
        if greenfieldSubtitlesDisabled {
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
        // File/direct entries may not know their embedded tracks until the
        // demuxer opens. Absence of metadata is not an explicit Off selection.
        return SubtitlePlan(mode: .embedded)
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
