import SwiftUI
import UIKit
import WebKit
import SafariServices
import AVFoundation
import AVKit
import CoreText
import Network
import JellyfinAPI
#if canImport(MobileVLCKit)
import MobileVLCKit
#endif

struct LaunchpadView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @AppStorage(AppearancePreferenceKeys.showCardSubtitle) private var showCardSubtitle = false
    @AppStorage(AppearancePreferenceKeys.groupFavoritesExpanded) private var groupFavoritesExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupMediaExpanded) private var groupMediaExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupDownloadsExpanded) private var groupDownloadsExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupNetworkExpanded) private var groupNetworkExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupToolsExpanded) private var groupToolsExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupOrder) private var groupOrderRaw = ServiceCategory.defaultOrderStorageValue
    @AppStorage(AppearancePreferenceKeys.groupDefaultVersion) private var groupDefaultVersion = 0
    @State private var showSearch = false
    @State private var showConnectionFlow = false
    @State private var showManualServiceEditor = false
    @State private var showServiceManager = false
    @State private var refreshPulseID = UUID()
    @State private var isToolbarRefreshing = false

    var body: some View {
        NavigationStack {
            Group {
                if connectionStore.isConnected || !dataStore.services.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if dataStore.shouldShowDataStatus {
                                LaunchpadDataStatusBanner(
                                    state: dataStore.dataRefreshState,
                                    sourceKey: dataStore.dataSourceLabelKey,
                                    dsmConnected: connectionStore.dsmSession != nil,
                                    retry: {
                                        if connectionStore.dsmSession == nil {
                                            showConnectionFlow = true
                                        } else {
                                            Task { await refreshLaunchpad() }
                                        }
                                    }
                                )
                            }
                            launchpadContent
                                .id("\(selectedTheme.rawValue)-\(groupExpansionSignature)-\(groupOrderSignature)-\(displayOptionsSignature)")
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                        .padding(.bottom, 18)
                    }
                    .background(launchpadBackground)
                    .refreshable {
                        await refreshLaunchpad()
                    }
                } else {
                    NASConnectionWelcomeView(
                        addNASAction: {
                            showConnectionFlow = true
                        }
                    )
                }
            }
            .navigationTitle(launchpadNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !dataStore.services.isEmpty {
                        Button {
                            showSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel(Text("search.title"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if connectionStore.isConnected {
                        Button {
                            refreshPulseID = UUID()
                            Task(priority: .userInitiated) {
                                await refreshLaunchpad(showToolbarProgress: true)
                            }
                        } label: {
                            if isToolbarRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .id(refreshPulseID)
                                    .transition(.opacity)
                            }
                        }
                        .disabled(dataStore.isRefreshing || isToolbarRefreshing)
                        .accessibilityLabel(Text("action.refresh"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !dataStore.services.isEmpty {
                        Button {
                            showServiceManager = true
                        } label: {
                            LaunchpadVisibilityToolbarIcon(hiddenCount: hiddenLaunchpadServices.count)
                        }
                        .accessibilityLabel(Text("launchpad.services.manage"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("connect.welcome.action") {
                            showConnectionFlow = true
                        }
                        Button("manual.service.add") {
                            showManualServiceEditor = true
                        }
                        if !dataStore.services.isEmpty {
                            Button("launchpad.services.manage") {
                                showServiceManager = true
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("launchpad.add.title"))
                }
            }
            .sheet(isPresented: $showConnectionFlow) {
                NavigationStack {
                    DSMConnectionFlowView {
                        showConnectionFlow = false
                    }
                }
            }
            .sheet(isPresented: $showManualServiceEditor) {
                NavigationStack {
                    ManualServiceEditorView()
                }
            }
            .sheet(isPresented: $showServiceManager) {
                NavigationStack {
                    LaunchpadServiceManagementView()
                }
            }
            .sheet(isPresented: $showSearch) {
                LaunchpadSearchView(services: launchpadServices)
            }
            .onAppear {
                applyGroupDefaultMigrationIfNeeded()
            }
            .task {
                await dataStore.refreshServiceHealth()
            }
        }
    }

    @MainActor
    private func refreshLaunchpad(showToolbarProgress: Bool = false) async {
        guard !dataStore.isRefreshing else { return }
        if showToolbarProgress {
            isToolbarRefreshing = true
        }
        defer {
            if showToolbarProgress {
                isToolbarRefreshing = false
            }
        }
        if let session = connectionStore.dsmSession {
            await dataStore.refreshDSM(session: session, useAgent: connectionStore.usesAgent)
        } else {
            dataStore.refreshAll()
        }
        await dataStore.refreshServiceHealth()
    }

    @ViewBuilder
    private var launchpadContent: some View {
        switch selectedTheme {
        case .cleanGrid:
            ProductLaunchpad(device: dataStore.device, services: launchpadServices, categories: orderedCategories, options: displayOptions, isConnected: liveNASConnectionState, groupDefaultExpanded: isGroupExpandedByDefault)
        case .commandCenter:
            CommandCenterLaunchpad(device: dataStore.device, services: launchpadServices, categories: orderedCategories, options: displayOptions, isConnected: liveNASConnectionState, groupDefaultExpanded: isGroupExpandedByDefault)
        case .glassDeck:
            GlassDeckLaunchpad(device: dataStore.device, services: launchpadServices, categories: orderedCategories, options: displayOptions, isConnected: liveNASConnectionState, groupDefaultExpanded: isGroupExpandedByDefault)
        }
    }

    /// Cached DSM data may be rendered while the app restores its live
    /// session. It must never make the launchpad claim that NAS actions are
    /// online before the same live session has reached the connection store.
    private var liveNASConnectionState: Bool {
        connectionStore.isConnected && dataStore.isDSMAvailableForDisplay
    }

    private var launchpadServices: [LaunchpadService] {
        dataStore.uniqueLaunchpadServices(dataStore.services.filter(dataStore.isServiceVisibleOnLaunchpad))
    }

    private var hiddenLaunchpadServices: [LaunchpadService] {
        dataStore.services.filter { !dataStore.isServiceVisibleOnLaunchpad($0) }
    }

    @ViewBuilder
    private var launchpadBackground: some View {
        switch selectedTheme {
        case .cleanGrid:
            AppTheme.groupedBackground
        case .commandCenter:
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground),
                    Color(.secondarySystemGroupedBackground).opacity(0.72),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .glassDeck:
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemIndigo).opacity(0.13),
                    AppTheme.accent.opacity(0.09),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var selectedTheme: LaunchpadTheme {
        let theme = appearanceStore.launchpadTheme
        if theme == .cleanGrid {
            return theme
        }
        return entitlementStore.canUse(.advancedThemes) ? theme : .cleanGrid
    }

    private var launchpadNavigationTitle: Text {
        if connectionStore.isConnected || !dataStore.services.isEmpty {
            let name = dataStore.device.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return Text(name)
            }
        }
        return Text("tab.launchpad")
    }

    private var displayOptions: LaunchpadDisplayOptions {
        LaunchpadDisplayOptions(
            compactMetrics: appearanceStore.compactMetrics,
            showServiceStatus: appearanceStore.showServiceStatus,
            showSubtitle: showCardSubtitle
        )
    }

    private var groupExpansionSignature: String {
        return [
            groupFavoritesExpanded,
            groupMediaExpanded,
            groupDownloadsExpanded,
            groupNetworkExpanded,
            groupToolsExpanded
        ].map { $0 ? "1" : "0" }.joined()
    }

    private var orderedCategories: [ServiceCategory] {
        ServiceCategory.ordered(from: groupOrderRaw)
    }

    private var groupOrderSignature: String {
        orderedCategories.map(\.rawValue).joined(separator: "-")
    }

    private var displayOptionsSignature: String {
        [
            appearanceStore.compactMetrics,
            appearanceStore.showServiceStatus,
            showCardSubtitle
        ].map { $0 ? "1" : "0" }.joined()
    }

    private func isGroupExpandedByDefault(_ category: ServiceCategory) -> Bool {
        switch category {
        case .favorites:
            return groupFavoritesExpanded
        case .media:
            return groupMediaExpanded
        case .downloads:
            return groupDownloadsExpanded
        case .network:
            return groupNetworkExpanded
        case .tools:
            return groupToolsExpanded
        }
    }

    private func applyGroupDefaultMigrationIfNeeded() {
        guard groupDefaultVersion < 1 else { return }
        groupFavoritesExpanded = true
        groupMediaExpanded = true
        groupDownloadsExpanded = true
        groupNetworkExpanded = true
        groupToolsExpanded = true
        groupDefaultVersion = 1
    }

}

private struct LaunchpadVisibilityToolbarIcon: View {
    let hiddenCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "eye.slash")
                .symbolRenderingMode(.hierarchical)

            if hiddenCount > 0 {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 8, height: 8)
                    .offset(x: 3, y: -3)
            }
        }
        .frame(width: 24, height: 24)
    }
}

private final class MediaPlayerSession: ObservableObject {
    let player: AVPlayer
    @Published private(set) var errorMessage: String?
    @Published private(set) var isReady = false
    @Published private(set) var fallbackReason: String?
    private var request: MediaPlaybackRequest
    private var statusObservation: NSKeyValueObservation?
    private var bufferObservation: NSKeyValueObservation?
    private var presentationObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var periodicTimeObserver: Any?
    private var lastTimeControlStatus: AVPlayer.TimeControlStatus?
    private var lastObservedBufferStart: Double?
    private var lastObservedBufferEnd: Double?
    private var lastObservedBufferPlayhead: Double?
    private var didRecordFirstFrame = false
    private var playbackStartedAt: Date?
    private var didApplyInitialPosition = false
    private var pendingInitialPosition: Double?
    private var autoplayPending = false
    private var didAutoplayAfterReady = false
    private var stallWorkItem: DispatchWorkItem?
    private var startupWorkItem: DispatchWorkItem?

    init(request: MediaPlaybackRequest) {
        self.request = request
        pendingInitialPosition = request.initialPosition
        player = AVPlayer()
    }

    private static func makePlayerItem(for request: MediaPlaybackRequest) -> AVPlayerItem {
        let options: [String: Any]? = request.mimeTypeHint.map {
            ["AVURLAssetOutOfBandMIMETypeKey": $0 as Any]
        }
        let asset = AVURLAsset(url: request.url, options: options)
        let item = AVPlayerItem(asset: asset)
        // AVPlayer's default anti-stall policy deliberately waits for a larger
        // buffer before starting HLS. That is safe for VOD but makes a newly
        // negotiated Jellyfin stream feel frozen. A small explicit forward
        // buffer keeps startup and seeks responsive while VLC remains the
        // engine for raw NAS files.
        item.preferredForwardBufferDuration = request.fileExtensionHint == "m3u8"
            ? 1.5
            : 0.5
        return item
    }

    private static func configure(_ player: AVPlayer, for request: MediaPlaybackRequest) {
        player.automaticallyWaitsToMinimizeStalling = request.fileExtensionHint != "m3u8"
    }

    func replaceRequest(
        _ request: MediaPlaybackRequest,
        normalizedPosition: Double?
    ) {
        pause()
        removeObservers()
        self.request = request
        pendingInitialPosition = normalizedPosition ?? request.initialPosition
        didApplyInitialPosition = false
        didAutoplayAfterReady = false
        lastTimeControlStatus = nil
        lastObservedBufferStart = nil
        lastObservedBufferEnd = nil
        lastObservedBufferPlayhead = nil
        didRecordFirstFrame = false
        playbackStartedAt = nil
        errorMessage = nil
        fallbackReason = nil
        isReady = false
        startupWorkItem?.cancel()
        startupWorkItem = nil
        Self.configure(player, for: request)
        player.replaceCurrentItem(with: Self.makePlayerItem(for: request))
    }

    private func prepareCurrentItemIfNeeded() {
        guard player.currentItem == nil else { return }
        Self.configure(player, for: request)
        player.replaceCurrentItem(with: Self.makePlayerItem(for: request))
    }

    private func activateIfNeeded() {
        guard statusObservation == nil, let item = player.currentItem else { return }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_started",
            details: MediaPlaybackProbe.baseDetails(for: request).merging([
                "engine": "AVPlayer",
                "mimeHint": request.mimeTypeHint ?? "-"
            ]) { current, _ in current }
        )
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    let shouldSeek = !self.didApplyInitialPosition
                        && self.pendingInitialPosition != nil
                        && item.duration.seconds.isFinite
                        && item.duration.seconds > 0
                    if shouldSeek,
                       let progress = self.pendingInitialPosition {
                        self.didApplyInitialPosition = true
                        self.pendingInitialPosition = nil
                        self.player.seek(
                            to: CMTime(seconds: item.duration.seconds * progress, preferredTimescale: 600),
                            toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
                            toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600)
                        ) { [weak self] _ in
                            DispatchQueue.main.async {
                                self?.autoplayAfterReadyIfNeeded(reason: "initialSeekCompleted")
                            }
                        }
                    }
                    self.isReady = true
                    self.errorMessage = nil
                    if !shouldSeek {
                        self.autoplayAfterReadyIfNeeded(reason: "itemReady")
                    }
                    DiagnosticLogStore.shared.record(
                        .info,
                        categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.media.player_ready",
                        details: MediaPlaybackProbe.baseDetails(for: self.request).merging([
                            "engine": "AVPlayer",
                            "durationSeconds": item.duration.seconds.isFinite
                                ? String(format: "%.1f", item.duration.seconds)
                                : "-",
                            "presentationSize": "\(Int(item.presentationSize.width))x\(Int(item.presentationSize.height))",
                            "initialPositionApplied": self.didApplyInitialPosition ? "yes" : "no"
                        ]) { current, _ in current }
                    )
                case .failed:
                    self.isReady = false
                    let error = item.error as NSError?
                    self.errorMessage = item.error?.localizedDescription
                        ?? NSLocalizedString("player.load_failed", comment: "")
                    self.fallbackReason = "playerError"
                    DiagnosticLogStore.shared.record(
                        .error,
                        categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.media.player_failed",
                        details: MediaPlaybackProbe.baseDetails(for: self.request).merging([
                            "engine": "AVPlayer",
                            "errorDomain": error?.domain ?? "-",
                            "errorCode": error.map { "\($0.code)" } ?? "-",
                            "errorDescription": item.error?.localizedDescription ?? "-"
                        ]) { current, _ in current }
                    )
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        bufferObservation = item.observe(\.loadedTimeRanges, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self,
                      let timeRange = Self.bufferRange(for: item),
                      timeRange.isValid,
                      timeRange.start.seconds.isFinite,
                      timeRange.duration.seconds.isFinite else {
                    return
                }
                let bufferedEnd = timeRange.start.seconds + timeRange.duration.seconds
                guard bufferedEnd.isFinite else { return }
                let currentSeconds = self.player.currentTime().seconds
                if let previousStart = self.lastObservedBufferStart,
                   let previousEnd = self.lastObservedBufferEnd,
                   let previousPlayhead = self.lastObservedBufferPlayhead,
                   abs(timeRange.start.seconds - previousStart) < 0.5,
                   abs(bufferedEnd - previousEnd) < 0.5,
                   (!currentSeconds.isFinite || abs(currentSeconds - previousPlayhead) < 1.0) {
                    return
                }
                self.lastObservedBufferStart = timeRange.start.seconds
                self.lastObservedBufferEnd = bufferedEnd
                self.lastObservedBufferPlayhead = currentSeconds.isFinite ? currentSeconds : nil
                let bufferAhead = currentSeconds.isFinite
                    ? max(bufferedEnd - currentSeconds, 0)
                    : 0
                DiagnosticLogStore.shared.record(
                    .info,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.player_state",
                    details: MediaPlaybackProbe.baseDetails(for: self.request).merging([
                        "engine": "AVPlayer",
                        "state": "bufferUpdated",
                        "bufferStartSeconds": String(format: "%.1f", timeRange.start.seconds),
                        "bufferEndSeconds": String(format: "%.1f", bufferedEnd),
                        "bufferAheadSeconds": String(format: "%.1f", bufferAhead),
                        "bufferEmpty": item.isPlaybackBufferEmpty ? "yes" : "no",
                        "likelyToKeepUp": item.isPlaybackLikelyToKeepUp ? "yes" : "no"
                    ]) { current, _ in current }
                )
            }
        }
        presentationObservation = item.observe(\.presentationSize, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self,
                      !self.didRecordFirstFrame,
                      item.presentationSize.width > 0,
                      item.presentationSize.height > 0 else {
                    return
                }
                self.didRecordFirstFrame = true
                DiagnosticLogStore.shared.record(
                    .info,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.first_frame",
                    details: MediaPlaybackProbe.baseDetails(for: self.request).merging([
                        "engine": "AVPlayer",
                        "firstFrameMs": self.playbackStartedAt.map {
                            String(Int(max(Date().timeIntervalSince($0), 0) * 1_000))
                        } ?? "-",
                        "presentationSize": "\(Int(item.presentationSize.width))x\(Int(item.presentationSize.height))"
                    ]) { current, _ in current }
                )
            }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self, player.timeControlStatus != self.lastTimeControlStatus else { return }
                self.lastTimeControlStatus = player.timeControlStatus
                let state: String
                switch player.timeControlStatus {
                case .paused: state = "paused"
                case .playing: state = "playing"
                case .waitingToPlayAtSpecifiedRate: state = "waiting"
                @unknown default: state = "unknown"
                }
                DiagnosticLogStore.shared.record(
                    state == "waiting" ? .warning : .info,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.player_state",
                    details: MediaPlaybackProbe.baseDetails(for: self.request).merging([
                        "engine": "AVPlayer",
                        "state": state,
                        "waitingReason": player.reasonForWaitingToPlay?.rawValue ?? "-",
                        "currentSeconds": player.currentTime().seconds.isFinite
                            ? String(format: "%.1f", player.currentTime().seconds)
                            : "-"
                    ]) { current, _ in current }
                )
                let currentSeconds = player.currentTime().seconds
                if currentSeconds.isFinite {
                    if player.timeControlStatus == .playing {
                        self.request.playbackTracker?.started(positionSeconds: currentSeconds)
                    }
                    self.request.playbackTracker?.progressed(
                        positionSeconds: currentSeconds,
                        isPaused: player.timeControlStatus != .playing,
                        force: true
                    )
                }
                self.updateStallDetection(for: player.timeControlStatus)
            }
        }
        periodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, time.seconds.isFinite else { return }
            if self.player.timeControlStatus == .playing {
                self.request.playbackTracker?.started(positionSeconds: time.seconds)
            }
            self.request.playbackTracker?.progressed(
                positionSeconds: time.seconds,
                isPaused: self.player.timeControlStatus != .playing
            )
        }
    }

    func play(from normalizedPosition: Double? = nil) {
        autoplayPending = true
        didAutoplayAfterReady = false
        if playbackStartedAt == nil {
            playbackStartedAt = Date()
        }
        if let normalizedPosition {
            pendingInitialPosition = min(max(normalizedPosition, 0), 1)
            didApplyInitialPosition = false
        }
        prepareCurrentItemIfNeeded()
        activateIfNeeded()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        applyPendingPositionIfReady()
        player.play()
        scheduleStartupFrameWatchdog()
    }

    func pause() {
        autoplayPending = false
        stallWorkItem?.cancel()
        startupWorkItem?.cancel()
        player.pause()
    }

    private func autoplayAfterReadyIfNeeded(reason: String) {
        guard autoplayPending,
              !didAutoplayAfterReady,
              player.currentItem?.status == .readyToPlay else {
            return
        }
        didAutoplayAfterReady = true
        player.play()
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_autoplay",
            details: MediaPlaybackProbe.baseDetails(for: request).merging([
                "engine": "AVPlayer",
                "reason": reason,
                "position": player.currentTime().seconds.isFinite
                    ? String(format: "%.1f", player.currentTime().seconds)
                    : "-"
            ]) { current, _ in current }
        )
    }

    private func scheduleStartupFrameWatchdog() {
        startupWorkItem?.cancel()
        guard request.fileExtensionHint == "m3u8" else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.fallbackReason == nil,
                  let item = self.player.currentItem,
                  self.player.timeControlStatus != .paused,
                  item.presentationSize == .zero else {
                return
            }
            self.fallbackReason = "startupNoVideoFrame"
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "AVPlayer",
                    "to": "MobileVLCKit",
                    "reason": "startupNoVideoFrame",
                    "watchdogSeconds": "4"
                ]
            )
        }
        startupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }

    var normalizedPosition: Double? {
        guard let item = player.currentItem else { return nil }
        let duration = item.duration.seconds
        let current = player.currentTime().seconds
        guard duration.isFinite, duration > 0, current.isFinite else { return nil }
        return min(max(current / duration, 0), 1)
    }

    private func applyPendingPositionIfReady() {
        guard
            !didApplyInitialPosition,
            let progress = pendingInitialPosition,
            let item = player.currentItem,
            item.status == .readyToPlay,
            item.duration.seconds.isFinite,
            item.duration.seconds > 0
        else {
            return
        }
        didApplyInitialPosition = true
        pendingInitialPosition = nil
        player.seek(
            to: CMTime(seconds: item.duration.seconds * progress, preferredTimescale: 600),
            toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
            toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600)
        )
    }

    private func updateStallDetection(for status: AVPlayer.TimeControlStatus) {
        stallWorkItem?.cancel()
        stallWorkItem = nil
        guard request.fileExtensionHint == "m3u8", hasAlternateTransport else { return }
        guard status == .waitingToPlayAtSpecifiedRate, fallbackReason == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
                  self.fallbackReason == nil else {
                return
            }
            self.fallbackReason = "playbackStall"
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "AVPlayer",
                    "to": "MobileVLCKit",
                    "reason": "playbackStall",
                    "waitingReason": self.player.reasonForWaitingToPlay?.rawValue ?? "-"
                ]
            )
        }
        stallWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: workItem)
    }

    private func removeObservers() {
        stallWorkItem?.cancel()
        stallWorkItem = nil
        startupWorkItem?.cancel()
        startupWorkItem = nil
        statusObservation?.invalidate()
        statusObservation = nil
        bufferObservation?.invalidate()
        bufferObservation = nil
        presentationObservation?.invalidate()
        presentationObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        if let periodicTimeObserver {
            player.removeTimeObserver(periodicTimeObserver)
            self.periodicTimeObserver = nil
        }
    }

    private static func bufferRange(for item: AVPlayerItem) -> CMTimeRange? {
        let currentSeconds = item.currentTime().seconds
        let ranges = item.loadedTimeRanges.compactMap(\.timeRangeValue).filter {
            $0.isValid && $0.start.seconds.isFinite && $0.duration.seconds.isFinite
        }
        guard !ranges.isEmpty else { return nil }
        guard currentSeconds.isFinite else { return ranges.first }
        return ranges.first(where: { range in
            let start = range.start.seconds
            let end = start + range.duration.seconds
            return currentSeconds >= start && currentSeconds <= end
        }) ?? ranges.first
    }

    private var hasAlternateTransport: Bool {
        request.compatibilityResource != nil
            || request.compatibilityResourceLoader != nil
            || request.compatibilityFallbackResource != nil
            || request.compatibilityFallbackResourceLoader != nil
            || request.compatibilityFallbackRequestLoader != nil
    }

    deinit {
        removeObservers()
        player.pause()
    }
}

struct BuiltInMediaPlayerView: View {
    let request: MediaPlaybackRequest
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: MediaPlayerSession
    @State private var activeEngine: MediaPlaybackEngine
    @State private var didAutomaticallyFallback = false
    @State private var showExternalPicker = false
    @State private var sharePayload: ServiceSharePayload?
    @State private var pendingExternalTarget: ExternalOpenTarget?
    @State private var pendingShareHandoff = false
    @State private var showCredentialHandoffWarning = false
    @State private var resolvedCompatibilityRequest: MediaPlaybackRequest?
    @State private var resolvedExternalHandoffRequest: MediaPlaybackRequest?
    @State private var compatibilityLoadTask: Task<MediaPlaybackResource?, Never>?
    @State private var compatibilityFallbackLoadTask: Task<MediaPlaybackResource?, Never>?
    @State private var compatibilityFallbackRequestLoadTask: Task<MediaPlaybackRequest?, Never>?
    @State private var externalHandoffLoadTask: Task<MediaPlaybackResource?, Never>?
    @State private var sourceTrackLoadTask: Task<Void, Never>?
    @State private var serverSeekLoadTask: Task<Void, Never>?
    @State private var qualityLoadTask: Task<Void, Never>?
    @State private var isPreparingAlternative = false
    @State private var didUseCompatibilityFallback = false
    @State private var compatibilityFallbackAttemptCount = 0
    @State private var compatibilityResumePosition: Double?
    @State private var compatibilityDidFail = false
    @State private var systemQualityPanelPresented = false
    @State private var shouldStartPictureInPicture = false

    init(request: MediaPlaybackRequest) {
        self.request = request
        _session = StateObject(wrappedValue: MediaPlayerSession(request: request))
        _activeEngine = State(initialValue: MediaPlaybackPolicy.preferredEngine(for: request))
        if request.compatibilityResourceLoader == nil {
            _resolvedCompatibilityRequest = State(
                initialValue: request.compatibilityPlaybackRequest
            )
        }
    }

    var body: some View {
        if request.isAudioOnly {
            DedicatedAudioPlayerView(request: request)
        } else {
            videoPlayerBody
        }
    }

    private var videoPlayerBody: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch activeEngine {
            case .system:
                ZStack {
                    SystemPlayerController(
                        player: session.player,
                        startPictureInPicture: shouldStartPictureInPicture,
                        onSeekCommitted: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        },
                        onPictureInPictureEvent: { phase, error in
                            var details = ["phase": phase]
                            if let error {
                                details["error"] = error.localizedDescription
                            }
                            DiagnosticLogStore.shared.record(
                                phase == "failed" ? .warning : .info,
                                categoryKey: "diagnostics.category.media",
                                messageKey: "diagnostics.media.player_switch",
                                details: details.merging(["target": "pictureInPicture"]) { _, new in new }
                            )
                            if phase == "didStart" {
                                shouldStartPictureInPicture = false
                            }
                        }
                    )
                    .ignoresSafeArea(edges: .bottom)

                    if request.qualityOptions.count > 1 {
                        VStack {
                            HStack {
                                Spacer()
                                Button {
                                    systemQualityPanelPresented = true
                                } label: {
                                    Image(systemName: "4k.tv")
                                        .font(.title3.weight(.semibold))
                                        .frame(width: 44, height: 44)
                                        .background(.black.opacity(0.48), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .accessibilityLabel(Text("player.quality"))
                            }
                            Spacer()
                        }
                        .padding(.top, 22)
                        .padding(.trailing, 18)
                    }
                }

                if let errorMessage = session.errorMessage {
                    playbackErrorView(
                        (!MediaPlaybackPolicy.hasCompatibilityEngine
                            && MediaPlaybackPolicy.requiresCompatibilityEngine(for: request))
                            ? NSLocalizedString("player.compatibility_unavailable", comment: "")
                            : errorMessage
                    )
                }
            case .compatibility:
#if canImport(MobileVLCKit)
                if let compatibilityRequest = activeCompatibilityRequest {
                    VLCBuiltInPlayerView(
                        request: compatibilityRequest,
                        close: { dismiss() },
                        useSystemPlayer: canPrepareSystemPlayback(from: compatibilityRequest)
                            ? prepareSystemPlayback
                            : nil,
                        compatibilityFailed: handleCompatibilityFailure,
                        sourceTrackChange: compatibilityRequest.sourceTrackRequestLoader == nil
                            ? nil
                            : handleSourceTrackChange,
                        serverSeek: compatibilityRequest.serverSeekRequestLoader == nil
                            ? nil
                            : handleServerSeek,
                        qualityChange: compatibilityRequest.qualityRequestLoader == nil
                            ? nil
                            : handleQualityChange,
                        openExternal: {
                            if request.allowsExternalHandoff {
                                showExternalPicker = true
                            }
                        }
                    )
                    .id(compatibilityRequest.id)
                } else {
                    ProgressView()
                        .tint(.white)
                }
#else
                playbackErrorView(NSLocalizedString("player.compatibility_unavailable", comment: ""))
#endif
            }

            if isPreparingAlternative {
                ProgressView()
                    .tint(.white)
                    .padding(14)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            }

            if showExternalPicker {
                externalPlayerPicker
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(2)
            }

            if showCredentialHandoffWarning {
                credentialHandoffWarning
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(3)
            }

            if systemQualityPanelPresented {
                systemQualityPanel
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(4)
            }
        }
        .navigationTitle(request.title.isEmpty ? "player.title" : request.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(activeEngine == .compatibility ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.done") {
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
#if canImport(MobileVLCKit)
                if MediaPlaybackPolicy.allowsSystemPlayer(for: request)
                    && MediaPlaybackPolicy.allowsCompatibilityPlayer(for: request) {
                    Menu {
                        Button {
                            selectEngine(.system)
                        } label: {
                            Label("player.engine.system", systemImage: activeEngine == .system ? "checkmark" : "play.rectangle")
                        }
                        Button {
                            selectEngine(.compatibility)
                        } label: {
                            Label("player.engine.compatibility", systemImage: activeEngine == .compatibility ? "checkmark" : "rectangle.stack")
                        }
                    } label: {
                        Image(systemName: "rectangle.stack")
                    }
                    .accessibilityLabel(Text("player.engine.choose"))
                }
#endif
                if request.allowsExternalHandoff {
                    Button {
                        showExternalPicker = true
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .accessibilityLabel(Text("devices.files.open_external"))
                }
                if activeEngine == .system {
                    Button {
                        togglePlayerOrientation()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .accessibilityLabel(Text("player.fullscreen"))
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            SystemShareView(items: [payload.url])
        }
        .onAppear {
            PlayerOrientationController.setPlayerActive(
                true,
                initialMode: request.initialOrientationMode
            )
            if activeEngine == .system {
                session.play()
            } else if activeCompatibilityRequest == nil {
                Task { _ = await resolveCompatibilityRequest() }
            }
        }
        .task {
            // Jellyfin and DSM resources are validated while their final playback route is
            // prepared. A second probe would compete with the player's first-frame request.
            if request.source == .directURL, request.url.host != "127.0.0.1" {
                await MediaPlaybackProbe.run(request)
            }
        }
        .onDisappear {
            compatibilityLoadTask?.cancel()
            compatibilityFallbackLoadTask?.cancel()
            compatibilityFallbackRequestLoadTask?.cancel()
            externalHandoffLoadTask?.cancel()
            sourceTrackLoadTask?.cancel()
            serverSeekLoadTask?.cancel()
            qualityLoadTask?.cancel()
            session.pause()
            // A Jellyfin direct-play request can be replaced by a negotiated
            // HLS request before the user enters system AVPlayer/PiP.  The
            // replacement owns the live tracker; using the original direct
            // tracker here reports the stale zero position on close, so the
            // next "Continue Watching" launch starts from the beginning.
            let activeTracker = activeCompatibilityRequest?.playbackTracker
                ?? request.playbackTracker
            activeTracker?.stopped(
                failed: activeEngine == .system
                    ? session.errorMessage != nil
                    : compatibilityDidFail
            )
            PlayerOrientationController.setPlayerActive(false)
        }
        .onChange(of: session.errorMessage) { errorMessage in
            guard
                errorMessage != nil,
                activeEngine == .system,
                MediaPlaybackPolicy.shouldAutomaticallyFallback(for: request),
                !didAutomaticallyFallback
            else {
                return
            }
            didAutomaticallyFallback = true
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "AVPlayer",
                    "to": "MobileVLCKit",
                    "reason": "playerError"
                ]
            )
            selectEngine(.compatibility)
        }
        .onChange(of: session.fallbackReason) { reason in
            guard
                let reason,
                activeEngine == .system,
                MediaPlaybackPolicy.shouldAutomaticallyFallback(for: request),
                !didAutomaticallyFallback
            else {
                return
            }
            didAutomaticallyFallback = true
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "AVPlayer",
                    "to": "MobileVLCKit",
                    "reason": reason
                ]
            )
            selectEngine(.compatibility)
        }
    }

    @ViewBuilder
    private func playbackErrorView(_ errorMessage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
            Text("player.load_failed")
                .font(.headline)
            Text(errorMessage)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(4)
            if request.allowsExternalHandoff {
                Button {
                    showExternalPicker = true
                } label: {
                    Label("devices.files.open_external", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            } else {
                switch request.source {
                case .jellyfin:
                    Text("jellyfin.player.retry_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                case .dsmFile:
                    Text("dsm.player.retry_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                case .directURL:
                    EmptyView()
                }
                Button("action.done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .foregroundStyle(.white)
        .padding(22)
    }

    private var externalPlayerPicker: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { dismissExternalPicker() }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("service.external.title")
                        .font(.headline)
                    Spacer()
                    Button(action: dismissExternalPicker) {
                        Image(systemName: "xmark")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("action.cancel"))
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(ExternalOpenTarget.installedPlayers) { target in
                            externalPickerRow(
                                title: target.displayName,
                                systemImage: "play.rectangle"
                            ) {
                                dismissExternalPicker()
                                requestExternalOpen(target)
                            }
                        }
                        externalPickerRow(
                            title: NSLocalizedString("external.browser", comment: ""),
                            systemImage: "safari"
                        ) {
                            dismissExternalPicker()
                            requestExternalOpen(.safari)
                        }
                        externalPickerRow(
                            title: NSLocalizedString("external.other_apps", comment: ""),
                            systemImage: "square.and.arrow.up"
                        ) {
                            dismissExternalPicker()
                            requestExternalShare()
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(24)
        }
    }

    private var credentialHandoffWarning: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.shield")
                        .font(.title3)
                    Text("external.credential_warning.title")
                        .font(.headline)
                }

                Text("external.credential_warning.message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button("action.cancel") {
                        cancelCredentialHandoff()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("external.credential_warning.continue") {
                        continueCredentialHandoff()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
            }
            .foregroundStyle(.primary)
            .padding(20)
            .frame(maxWidth: 420)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(24)
        }
    }

    @ViewBuilder
    private func externalPickerRow(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                Text(title)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Divider().padding(.leading, 52)
    }

    private func dismissExternalPicker() {
        withAnimation(.easeOut(duration: 0.16)) {
            showExternalPicker = false
        }
    }

    private func continueCredentialHandoff() {
        showCredentialHandoffWarning = false
        if let target = pendingExternalTarget {
            openExternal(target)
        } else if pendingShareHandoff {
            sharePayload = ServiceSharePayload(url: handoffRequest.externalHandoffURL)
        }
        pendingExternalTarget = nil
        pendingShareHandoff = false
    }

    private func cancelCredentialHandoff() {
        showCredentialHandoffWarning = false
        pendingExternalTarget = nil
        pendingShareHandoff = false
    }

    private func selectEngine(
        _ engine: MediaPlaybackEngine,
        resumePosition: Double? = nil
    ) {
        guard activeEngine != engine else { return }
        didAutomaticallyFallback = true
        if engine == .compatibility {
            compatibilityResumePosition = resumePosition
                ?? session.normalizedPosition
                ?? request.initialPosition
        }
        session.pause()
        if engine == .compatibility,
           request.compatibilityResourceLoader != nil,
           resolvedCompatibilityRequest == nil {
            Task {
                _ = await resolveCompatibilityRequest()
                activeEngine = .compatibility
            }
            return
        }
        if engine == .compatibility,
           let currentRequest = resolvedCompatibilityRequest {
            let resource = MediaPlaybackResource(
                url: currentRequest.url,
                fileExtensionOverride: currentRequest.fileExtensionOverride,
                subtitleURL: currentRequest.externalSubtitleURL
            )
            // Build from the active replacement, not the original request.
            // This preserves timelineOffsetSeconds for a transcode stream and
            // carries the selected source tracks/quality into VLC.
            resolvedCompatibilityRequest = currentRequest.playbackRequest(
                using: resource,
                initialPositionOverride: compatibilityResumePosition
            )
        }
        activeEngine = engine
        if engine == .system {
            session.replaceRequest(
                activeCompatibilityRequest ?? request,
                normalizedPosition: resumePosition
            )
            session.play(from: resumePosition)
        }
    }

    private func canPrepareSystemPlayback(from activeRequest: MediaPlaybackRequest) -> Bool {
        MediaPlaybackPolicy.allowsSystemPlayer(for: activeRequest)
            || (activeRequest.source == .jellyfin
                && activeRequest.qualityRequestLoader != nil
                && activeRequest.qualityOptions.contains { $0.id == "12000000" })
    }

    private func prepareSystemPlayback(
        runtimeState: MediaPlaybackRuntimeState,
        startsPictureInPicture: Bool
    ) {
        guard let activeRequest = activeCompatibilityRequest else { return }
        if MediaPlaybackPolicy.allowsSystemPlayer(for: activeRequest) {
            shouldStartPictureInPicture = startsPictureInPicture
            selectEngine(.system, resumePosition: runtimeState.normalizedPosition)
            return
        }
        guard
            activeRequest.source == .jellyfin,
            let loader = activeRequest.qualityRequestLoader,
            activeRequest.qualityOptions.contains(where: { $0.id == "12000000" })
        else {
            return
        }

        sourceTrackLoadTask?.cancel()
        serverSeekLoadTask?.cancel()
        qualityLoadTask?.cancel()
        isPreparingAlternative = true
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_switch",
            details: [
                "from": "MobileVLCKit",
                "to": "AVPlayer",
                "reason": "pictureInPicture",
                "preparation": "serverHLS"
            ]
        )
        qualityLoadTask = Task { @MainActor in
            let startedAt = Date()
            let replacement = await loader("12000000", runtimeState)
            guard !Task.isCancelled else { return }
            qualityLoadTask = nil
            isPreparingAlternative = false
            guard let replacement,
                  MediaPlaybackPolicy.allowsSystemPlayer(for: replacement) else {
                DiagnosticLogStore.shared.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.quality_switch_failed",
                    details: ["target": "pictureInPicture"]
                )
                return
            }
            compatibilityDidFail = false
            compatibilityResumePosition = replacement.initialPosition
            resolvedCompatibilityRequest = replacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.quality_switch_ready",
                details: [
                    "target": "pictureInPicture",
                    "prepareMs": String(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000)),
                    "extension": replacement.fileExtensionHint
                ]
            )
            activateSystemPlayback(
                with: replacement,
                runtimeState: runtimeState,
                startsPictureInPicture: startsPictureInPicture
            )
        }
    }

    private func activateSystemPlayback(
        with replacement: MediaPlaybackRequest,
        runtimeState: MediaPlaybackRuntimeState,
        startsPictureInPicture: Bool
    ) {
        shouldStartPictureInPicture = startsPictureInPicture
        compatibilityResumePosition = replacement.initialPosition
        resolvedCompatibilityRequest = replacement
        let resumePosition = replacement.timelineOffsetSeconds > 0
            ? nil
            : runtimeState.normalizedPosition ?? replacement.initialPosition
        activeEngine = .system
        session.replaceRequest(replacement, normalizedPosition: resumePosition)
        session.play(from: resumePosition)
    }

    private var systemRuntimeState: MediaPlaybackRuntimeState {
        let currentSeconds = session.player.currentTime().seconds
        return MediaPlaybackRuntimeState(
            normalizedPosition: session.normalizedPosition,
            positionSeconds: currentSeconds.isFinite ? currentSeconds : nil,
            playbackRate: session.player.rate,
            audioTrackOrdinal: nil,
            subtitleTrackOrdinal: nil,
            subtitlesDisabled: false,
            subtitleSelectionKnown: false,
            orientationMode: request.initialOrientationMode
        )
    }

    private var systemQualityPanel: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { systemQualityPanelPresented = false }

            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("player.quality")
                            .font(.headline)
                        Spacer()
                        Button {
                            systemQualityPanelPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider()

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach((activeCompatibilityRequest ?? request).qualityOptions) { option in
                                Button {
                                    systemQualityPanelPresented = false
                                    handleQualityChange(
                                        qualityID: option.id,
                                        runtimeState: systemRuntimeState
                                    )
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: (activeCompatibilityRequest ?? request).selectedQualityID == option.id
                                              ? "checkmark.circle.fill"
                                              : "circle")
                                        Text(option.title)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(minHeight: 48)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(width: 320)
                .foregroundStyle(.primary)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.trailing, 18)
            }
        }
    }

    private func handleCompatibilityFailure(runtimeState: MediaPlaybackRuntimeState) {
        compatibilityDidFail = true
        guard
            compatibilityFallbackAttemptCount < 2,
            !isPreparingAlternative,
            let failingRequest = activeCompatibilityRequest,
            failingRequest.compatibilityFallbackResource != nil
                || failingRequest.compatibilityFallbackResourceLoader != nil
                || failingRequest.compatibilityFallbackRequestLoader != nil
        else {
            return
        }

        // The automatic path is intentionally bounded: one direct reconnect
        // may be followed by one server fallback. The replacement itself does
        // not create an unbounded retry loop.
        compatibilityFallbackAttemptCount += 1
        didUseCompatibilityFallback = true
        let resumePosition = runtimeState.normalizedPosition
            ?? failingRequest.initialPosition
            ?? compatibilityResumePosition
        DiagnosticLogStore.shared.record(
            .warning,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_fallback",
            details: [
                "from": "MobileVLCKit",
                "to": "compatibilityReplacement",
                "reason": "originalPlaybackFailed",
                "position": runtimeState.positionSeconds.map { String(format: "%.1f", $0) } ?? "-",
                "attempt": "\(compatibilityFallbackAttemptCount)"
            ]
        )

        // A DSM/direct stream can fail because its HTTP connection was dropped
        // even though the media itself is healthy. Reopen that same resource
        // once at the live playhead. A Jellyfin original has already passed
        // the server probe, so reopening its large Range resource after a
        // decoder/seek failure would repeat the iPad failure; Jellyfin switches
        // to its prepared compatibility request on the first real failure.
        if compatibilityFallbackAttemptCount == 1,
           failingRequest.fileExtensionHint != "m3u8",
           failingRequest.source != .jellyfin {
            let resource = MediaPlaybackResource(
                url: failingRequest.url,
                fileExtensionOverride: failingRequest.fileExtensionOverride,
                subtitleURL: failingRequest.externalSubtitleURL
            )
            let replacement = failingRequest.playbackRequest(
                using: resource,
                initialPositionOverride: resumePosition,
                runtimeState: runtimeState,
                retainsFallback: true
            )
            compatibilityDidFail = false
            compatibilityResumePosition = replacement.initialPosition ?? resumePosition
            resolvedCompatibilityRequest = replacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "MobileVLCKit",
                    "to": "MobileVLCKit",
                    "reason": "directResourceReconnect",
                    "position": resumePosition.map { String(format: "%.1f", $0) } ?? "-"
                ]
            )
            return
        }

        Task { @MainActor in
            let startedAt = Date()
            let replacement = await resolveCompatibilityFallbackRequest(
                from: failingRequest,
                resumePosition: resumePosition,
                runtimeState: runtimeState
            )
            guard !Task.isCancelled else { return }
            guard let replacement else {
                DiagnosticLogStore.shared.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.player_failed",
                    details: [
                        "engine": "MobileVLCKit",
                        "reason": "compatibilityReplacementUnavailable"
                    ]
                )
                return
            }
            compatibilityDidFail = false
            let preparedReplacement = replacement.applyingRuntimePreferences(runtimeState)
            compatibilityResumePosition = preparedReplacement.initialPosition ?? resumePosition
            resolvedCompatibilityRequest = preparedReplacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "MobileVLCKit",
                    "to": "MobileVLCKit",
                    "reason": "compatibilityReplacementReady",
                    "prepareMs": String(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000)),
                    "extension": replacement.fileExtensionHint
                ]
            )

            // A Jellyfin fallback is a negotiated HLS stream. Let AVPlayer own
            // the native HLS playlist/segment pipeline on both iPhone and iPad;
            // keep VLC only as the bounded fallback if AVPlayer cannot produce
            // a frame. Reopening the HLS stream in VLC here can report
            // `playing` while never advancing its playback clock on iPad.
            if preparedReplacement.fileExtensionHint == "m3u8",
               MediaPlaybackPolicy.allowsSystemPlayer(for: preparedReplacement) {
                activateSystemPlayback(
                    with: preparedReplacement,
                    runtimeState: runtimeState,
                    startsPictureInPicture: false
                )
            }
        }
    }

    private func handleSourceTrackChange(
        audioTrackID: Int?,
        subtitleTrackID: Int?,
        runtimeState: MediaPlaybackRuntimeState
    ) {
        guard let activeRequest = activeCompatibilityRequest,
              let loader = activeRequest.sourceTrackRequestLoader,
              activeRequest.selectedSourceAudioTrackID != audioTrackID
                || activeRequest.selectedSourceSubtitleTrackID != subtitleTrackID else {
            return
        }
        sourceTrackLoadTask?.cancel()
        serverSeekLoadTask?.cancel()
        isPreparingAlternative = true
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.source_track_switch_requested",
            details: [
                "audioStreamIndex": audioTrackID.map(String.init) ?? "default",
                "subtitleStreamIndex": subtitleTrackID.map(String.init) ?? "none",
                "position": runtimeState.normalizedPosition.map { String(format: "%.4f", $0) } ?? "-"
            ]
        )
        sourceTrackLoadTask = Task { @MainActor in
            let startedAt = Date()
            let replacement = await loader(audioTrackID, subtitleTrackID, runtimeState)
            guard !Task.isCancelled else { return }
            isPreparingAlternative = false
            sourceTrackLoadTask = nil
            guard let replacement else {
                DiagnosticLogStore.shared.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.source_track_switch_failed"
                )
                return
            }
            compatibilityDidFail = false
            didUseCompatibilityFallback = false
            compatibilityFallbackAttemptCount = 0
            compatibilityResumePosition = replacement.initialPosition
            resolvedCompatibilityRequest = replacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.source_track_switch_ready",
                details: [
                    "audioStreamIndex": audioTrackID.map(String.init) ?? "default",
                    "subtitleStreamIndex": subtitleTrackID.map(String.init) ?? "none",
                    "prepareMs": String(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000)),
                    "extension": replacement.fileExtensionHint
                ]
            )
        }
    }

    private func handleServerSeek(
        targetSeconds: Double,
        runtimeState: MediaPlaybackRuntimeState
    ) {
        guard let activeRequest = activeCompatibilityRequest,
              let loader = activeRequest.serverSeekRequestLoader,
              targetSeconds.isFinite else {
            return
        }
        sourceTrackLoadTask?.cancel()
        serverSeekLoadTask?.cancel()
        isPreparingAlternative = true
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.server_seek_requested",
            details: [
                "fromSeconds": runtimeState.positionSeconds.map { String(format: "%.1f", $0) } ?? "-",
                "targetSeconds": String(format: "%.1f", targetSeconds)
            ]
        )
        serverSeekLoadTask = Task { @MainActor in
            let startedAt = Date()
            let replacement = await loader(targetSeconds, runtimeState)
            guard !Task.isCancelled else { return }
            isPreparingAlternative = false
            serverSeekLoadTask = nil
            guard let replacement else {
                DiagnosticLogStore.shared.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.server_seek_failed"
                )
                return
            }
            compatibilityDidFail = false
            didUseCompatibilityFallback = false
            compatibilityFallbackAttemptCount = 0
            compatibilityResumePosition = replacement.initialPosition
            resolvedCompatibilityRequest = replacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.server_seek_ready",
                details: [
                    "targetSeconds": String(format: "%.1f", targetSeconds),
                    "prepareMs": String(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000)),
                    "extension": replacement.fileExtensionHint
                ]
            )
        }
    }

    private func handleQualityChange(
        qualityID: String,
        runtimeState: MediaPlaybackRuntimeState
    ) {
        guard let activeRequest = activeCompatibilityRequest,
              let loader = activeRequest.qualityRequestLoader,
              activeRequest.selectedQualityID != qualityID else {
            return
        }
        sourceTrackLoadTask?.cancel()
        serverSeekLoadTask?.cancel()
        qualityLoadTask?.cancel()
        isPreparingAlternative = true
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.quality_switch_requested",
            details: [
                "from": activeRequest.selectedQualityID ?? "auto",
                "target": qualityID,
                "positionSeconds": runtimeState.positionSeconds.map {
                    String(format: "%.1f", $0)
                } ?? "-"
            ]
        )
        qualityLoadTask = Task { @MainActor in
            let startedAt = Date()
            let replacement = await loader(qualityID, runtimeState)
            guard !Task.isCancelled else { return }
            isPreparingAlternative = false
            qualityLoadTask = nil
            guard let replacement else {
                DiagnosticLogStore.shared.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.quality_switch_failed",
                    details: ["target": qualityID]
                )
                return
            }
            compatibilityDidFail = false
            didUseCompatibilityFallback = false
            compatibilityFallbackAttemptCount = 0
            compatibilityResumePosition = replacement.initialPosition
            resolvedCompatibilityRequest = replacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.quality_switch_ready",
                details: [
                    "target": qualityID,
                    "prepareMs": String(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000)),
                    "extension": replacement.fileExtensionHint
                ]
            )
        }
    }

    private func openExternal(_ target: ExternalOpenTarget) {
        session.pause()
        guard let targetURL = target.url(
            endpoint: handoffRequest.externalHandoffURL,
            filename: handoffRequest.externalFilename,
            subtitleURL: handoffRequest.externalHandoffSubtitleURL
        ) else {
            sharePayload = ServiceSharePayload(url: handoffRequest.externalHandoffURL)
            return
        }
        UIApplication.shared.open(targetURL, options: [:]) { accepted in
            DiagnosticLogStore.shared.record(
                accepted ? .info : .error,
                categoryKey: "diagnostics.category.media",
                messageKey: accepted
                    ? "diagnostics.media.external_handoff_accepted"
                    : "diagnostics.media.external_handoff_failed",
                details: [
                    "targetApp": target.diagnosticName,
                    "extension": handoffRequest.externalHandoffFileExtensionHint.isEmpty
                        ? "-"
                        : handoffRequest.externalHandoffFileExtensionHint,
                    "mode": externalHandoffMode(for: handoffRequest)
                ]
            )
            guard !accepted else { return }
            DispatchQueue.main.async {
                sharePayload = ServiceSharePayload(url: handoffRequest.externalHandoffURL)
            }
        }
    }

    private func requestExternalOpen(_ target: ExternalOpenTarget) {
        Task {
            _ = await resolveExternalHandoffRequest()
            guard handoffRequest.containsSensitiveCredential else {
                openExternal(target)
                return
            }
            pendingExternalTarget = target
            showCredentialHandoffWarning = true
        }
    }

    private func externalHandoffMode(for request: MediaPlaybackRequest) -> String {
        switch request.externalHandoffFileExtensionHint {
        case "m3u8": return "serverNegotiatedHLS"
        case "ts": return "serverNegotiatedTransportStream"
        default: return "directHandoff"
        }
    }

    private func requestExternalShare() {
        Task {
            _ = await resolveExternalHandoffRequest()
            guard handoffRequest.containsSensitiveCredential else {
                sharePayload = ServiceSharePayload(url: handoffRequest.externalHandoffURL)
                return
            }
            pendingExternalTarget = nil
            pendingShareHandoff = true
            showCredentialHandoffWarning = true
        }
    }

    private var activeCompatibilityRequest: MediaPlaybackRequest? {
        resolvedCompatibilityRequest
    }

    private var handoffRequest: MediaPlaybackRequest {
        resolvedExternalHandoffRequest ?? request
    }

    @MainActor
    private func resolveCompatibilityRequest() async -> MediaPlaybackRequest {
        if let resolvedCompatibilityRequest { return resolvedCompatibilityRequest }
        guard let loader = request.compatibilityResourceLoader else {
            return request.compatibilityPlaybackRequest
        }
        isPreparingAlternative = true
        defer { isPreparingAlternative = false }
        let task: Task<MediaPlaybackResource?, Never>
        if let compatibilityLoadTask {
            task = compatibilityLoadTask
        } else {
            task = Task { await loader() }
            compatibilityLoadTask = task
        }
        let resource = await task.value
        compatibilityLoadTask = nil
        let resolved = resource.map {
            request.playbackRequest(
                using: $0,
                initialPositionOverride: compatibilityResumePosition
            )
        }
            ?? request.compatibilityPlaybackRequest
        resolvedCompatibilityRequest = resolved
        return resolved
    }

    @MainActor
    private func resolveCompatibilityFallbackRequest(
        from failingRequest: MediaPlaybackRequest,
        resumePosition: Double?,
        runtimeState: MediaPlaybackRuntimeState?
    ) async -> MediaPlaybackRequest? {
        if let loader = failingRequest.compatibilityFallbackRequestLoader {
            isPreparingAlternative = true
            defer { isPreparingAlternative = false }
            let task: Task<MediaPlaybackRequest?, Never>
            if let compatibilityFallbackRequestLoadTask {
                task = compatibilityFallbackRequestLoadTask
            } else {
                task = Task { await loader(runtimeState) }
                compatibilityFallbackRequestLoadTask = task
            }
            let replacement = await task.value
            compatibilityFallbackRequestLoadTask = nil
            return replacement
        }
        if let resource = failingRequest.compatibilityFallbackResource {
            return failingRequest.playbackRequest(
                using: resource,
                initialPositionOverride: resumePosition,
                runtimeState: runtimeState,
                retainsFallback: false
            )
        }
        guard let loader = failingRequest.compatibilityFallbackResourceLoader else { return nil }
        isPreparingAlternative = true
        defer { isPreparingAlternative = false }
        let task: Task<MediaPlaybackResource?, Never>
        if let compatibilityFallbackLoadTask {
            task = compatibilityFallbackLoadTask
        } else {
            task = Task { await loader(runtimeState) }
            compatibilityFallbackLoadTask = task
        }
        let resource = await task.value
        compatibilityFallbackLoadTask = nil
        return resource.map {
            failingRequest.playbackRequest(
                using: $0,
                initialPositionOverride: resumePosition,
                runtimeState: runtimeState,
                retainsFallback: false
            )
        }
    }

    @MainActor
    private func resolveExternalHandoffRequest() async -> MediaPlaybackRequest {
        if let resolvedExternalHandoffRequest { return resolvedExternalHandoffRequest }
        if request.externalHandoffResource != nil {
            resolvedExternalHandoffRequest = request
            return request
        }
        guard let loader = request.externalHandoffResourceLoader else {
            return request
        }
        isPreparingAlternative = true
        defer { isPreparingAlternative = false }
        let task: Task<MediaPlaybackResource?, Never>
        if let externalHandoffLoadTask {
            task = externalHandoffLoadTask
        } else {
            task = Task { await loader() }
            externalHandoffLoadTask = task
        }
        let resource = await task.value
        externalHandoffLoadTask = nil
        let resolved = resource.map { resource in
            MediaPlaybackRequest(
                url: request.url,
                title: request.title,
                allowsSelfSignedCertificates: request.allowsSelfSignedCertificates,
                source: request.source,
                fileExtensionOverride: request.fileExtensionOverride,
                initialPosition: request.initialPosition,
                externalSubtitleURL: request.externalSubtitleURL,
                preferredAudioTrackOrdinal: request.preferredAudioTrackOrdinal,
                preferredSubtitleTrackOrdinal: request.preferredSubtitleTrackOrdinal,
                prefersSubtitlesDisabled: request.prefersSubtitlesDisabled,
                initialOrientationMode: request.initialOrientationMode,
                initialPlaybackRate: request.initialPlaybackRate,
                isPrivateNetworkRoute: request.isPrivateNetworkRoute,
                playbackTracker: request.playbackTracker,
                compatibilityResource: request.compatibilityResource,
                compatibilityFallbackResource: request.compatibilityFallbackResource,
                externalHandoffResource: resource,
                compatibilityResourceLoader: request.compatibilityResourceLoader,
                compatibilityFallbackResourceLoader: request.compatibilityFallbackResourceLoader,
                compatibilityFallbackRequestLoader: request.compatibilityFallbackRequestLoader,
                playbackTraceID: request.playbackTraceID
            )
        } ?? request
        resolvedExternalHandoffRequest = resolved
        return resolved
    }

    private func togglePlayerOrientation() {
        let isLandscape = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .contains { $0.interfaceOrientation.isLandscape }
        PlayerOrientationController.requestPlayerOrientation(isLandscape ? .portrait : .landscape)
    }
}

struct PlaybackUITrack: Identifiable, Equatable {
    let id: Int32
    let name: String
}

#if canImport(MobileVLCKit)
private typealias VLCSubtitleTrack = PlaybackUITrack
private typealias VLCAudioTrack = PlaybackUITrack

enum VLCTrustDirectory {
    static func options(for request: MediaPlaybackRequest) -> [String] {
        guard
            request.allowsSelfSignedCertificates,
            let certificateData = CertificatePinStore.shared.trustedCertificateData(
                host: request.url.host,
                port: request.url.port
            ),
            let directory = writePEMCertificate(
                certificateData,
                host: request.url.host,
                port: request.url.port
            )
        else {
            return []
        }
        return ["--gnutls-dir-trust=\(directory.path)"]
    }

    private static func writePEMCertificate(
        _ certificateData: Data,
        host: String?,
        port: Int?
    ) -> URL? {
        guard let cachesURL = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        let safeHost = (host ?? "server").map { character in
            character.isLetter || character.isNumber || character == "." ? character : "_"
        }
        let directory = cachesURL
            .appendingPathComponent("VLCTrust", isDirectory: true)
            .appendingPathComponent("\(String(safeHost))-\(port ?? 443)", isDirectory: true)
        let certificateURL = directory.appendingPathComponent("certificate.pem")
        let base64 = certificateData.base64EncodedString(options: .lineLength64Characters)
        let pem = "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----\n"
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try Data(pem.utf8).write(to: certificateURL, options: .atomic)
            return directory
        } catch {
            return nil
        }
    }
}

private enum VLCPlaybackRuntime {
    static let configureEventDelivery: Void = {
        VLCLibrary.sharedEventsConfiguration = VLCEventsLegacyConfiguration()
    }()
}

private enum VLCTrackSelectionKind: String {
    case audio
    case subtitle
}

private struct PendingVLCTrackSelection {
    let targetID: Int32
    let previousID: Int32
    let startedAt: Date
}

private final class VLCMediaPlayerSession: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    let player: VLCMediaPlayer
    @Published private(set) var isPlaying = false
    @Published private(set) var isMuted = false
    @Published private(set) var position: Double = 0
    @Published private(set) var isSeekable = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var subtitleTracks: [VLCSubtitleTrack] = []
    @Published private(set) var selectedSubtitleTrackID: Int32 = -1
    @Published private(set) var audioTracks: [VLCAudioTrack] = []
    @Published private(set) var selectedAudioTrackID: Int32 = -1
    @Published private(set) var isBuffering = true
    @Published private(set) var hasStartedPlayback = false
    @Published private(set) var currentTimeText = "00:00"
    @Published private(set) var currentTimeSeconds = 0.0
    @Published private(set) var durationText = "--:--"
    @Published private(set) var durationSeconds = 0.0
    @Published private(set) var playbackRate: Float = 1
    private let request: MediaPlaybackRequest
    private let hasCustomTLSRoot: Bool
    private var lastStateDescription = ""
    private let initialPosition: Double?
    private let externalSubtitleURL: URL?
    private let preferredAudioTrackOrdinal: Int?
    private let preferredSubtitleTrackOrdinal: Int?
    private let prefersSubtitlesDisabled: Bool
    private var didApplyInitialPosition = false
    private var didApplyInitialAudioTrack = false
    private var didApplyInitialSubtitleTrack = false
    private var didApplyPlaybackRate = false
    private var desiredAudioTrackID: Int32?
    private var desiredSubtitleTrackID: Int32?
    private var pendingAudioTrackSelection: PendingVLCTrackSelection?
    private var pendingSubtitleTrackSelection: PendingVLCTrackSelection?
    private var audioTrackSelectionCheckWorkItem: DispatchWorkItem?
    private var subtitleTrackSelectionCheckWorkItem: DispatchWorkItem?
    private var desiredPlaybackRate: Float
    private var didApplySubtitleStyle = false
    private var didAddExternalSubtitle = false
    private var externalSubtitleSelectionWorkItem: DispatchWorkItem?
    private var subtitleTrackIDsBeforeExternalAdd: Set<Int32> = []
    private var lastSubtitleTrackIDs: [Int32] = []
    private var lastAudioTrackIDs: [Int32] = []
    private var cachedSubtitleTracks: [VLCSubtitleTrack] = []
    private var cachedAudioTracks: [VLCAudioTrack] = []
    private var trackInventoryNeedsRefresh = true
    private var trackInventoryRefreshDeadline = Date.distantPast
    private var lastTrackInventoryRefreshAt: Date?
    private var pendingJumpSeconds = 0
    private var pendingJumpWorkItem: DispatchWorkItem?
    private var startupPlayRetryWorkItem: DispatchWorkItem?
    private var startupPlayRetryCount = 0
    private var unexpectedPauseRecoveryWorkItem: DispatchWorkItem?
    private var didRecordStart = false
    private var didReissueStartupPlay = false
    private var didReachPlayback = false
    private var didRequestStop = false
    private var didFinishPlaybackNaturally = false
    private var reconnectAttempts = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var isReconnecting = false
    private var reconnectStartedAt: Date?
    private var reconnectRecoveryBaselineSeconds = 0.0
    private var highestPlaybackSeconds = 0.0
    private var lastObservedPlaybackSeconds: Double?
    private var lastPlaybackProgressAt: Date?
    private var pendingResumePosition: Double?
    private var suppressNextClockAdvanceForInitialSeek = false
    private var isUserPaused = false
    private var didRecordFirstFrame = false
    private var pendingSeekStartedAt: Date?
    private var pendingSeekOriginSeconds: Double?
    private var pendingSeekTargetSeconds: Double?
    private var bufferingStartedAt: Date?
    private var lastBufferingState = true
    private var lastTimeStateSyncAt = Date.distantPast
    private var pendingTimeStateSyncWorkItem: DispatchWorkItem?
    private let minimumTimeStateSyncInterval: TimeInterval = 0.25
    private let reconnectTimeout: TimeInterval = 24

    var initialLoadTimeoutNanoseconds: UInt64 {
        let isPrivateHost = request.isPrivateNetworkRoute
            ?? NetworkHostClassifier.isPrivate(request.networkOriginURL.host)
        switch request.source {
        case .jellyfin where request.fileExtensionHint == "m3u8" && hasAlternateTransport:
            return isPrivateHost ? 12_000_000_000 : 15_000_000_000
        case .jellyfin:
            // A Jellyfin original can be a very large Matroska file whose
            // index is near the end of the object. Waiting 10–12 seconds for
            // VLC to open that Range input makes the player look black before
            // the already-available HLS fallback is even requested. Keep a
            // small direct-play grace for fast local files, then hand off to
            // the compatibility HLS route so the first visible frame wins.
            return isPrivateHost ? 6_000_000_000 : 5_000_000_000
        case .dsmFile where hasAlternateTransport:
            // DSM video is direct-first. Once the real player has had a
            // short opportunity to produce a frame, the compatibility loader
            // can take over. This avoids adding a probe delay while keeping a
            // bounded recovery path for a black/never-starting stream.
            return isPrivateHost ? 5_000_000_000 : 4_000_000_000
        case .dsmFile:
            return isPrivateHost ? 8_000_000_000 : 6_000_000_000
        case .directURL:
            return 30_000_000_000
        }
    }

    init(request: MediaPlaybackRequest) {
        _ = VLCPlaybackRuntime.configureEventDelivery
        self.request = request
        initialPosition = request.initialPosition
        externalSubtitleURL = request.externalSubtitleURL
        preferredAudioTrackOrdinal = request.preferredAudioTrackOrdinal
        preferredSubtitleTrackOrdinal = request.preferredSubtitleTrackOrdinal
        prefersSubtitlesDisabled = request.prefersSubtitlesDisabled
        desiredPlaybackRate = request.initialPlaybackRate
        // MobileVLCKit's `VLCMediaPlayer(options:)` is not safe on all iPad
        // runtime/library combinations when passed the GnuTLS trust
        // directory option: the native libvlc constructor can dereference a
        // null pointer before Swift receives an error.  This was the actual
        // device-file crash on iPad.  Keep player construction option-free;
        // self-signed HTTPS is handled by the authenticated URLSession-based
        // Range compatibility proxy, which is already the bounded fallback
        // for DSM files.  Plain HTTP and trusted HTTPS still use the same
        // direct-first player path on both device families.
        hasCustomTLSRoot = false
        player = VLCMediaPlayer()
        super.init()
        player.delegate = self
        player.media = makeMedia()
        resetTrackInventoryRefreshWindow()
    }

    private func makeMedia() -> VLCMedia {
        let media = VLCMedia(url: request.url)
        let networkCaching = networkCachingMilliseconds
        media.addOption(":network-caching=\(networkCaching)")
        media.addOption(":file-caching=\(networkCaching)")
        // Keep finite media as a seekable HTTP file even when it comes from
        // the authenticated localhost Range compatibility transport. VLC's
        // live/continuous HTTP helper is intended for an unbounded stream;
        // enabling it here makes a finite Matroska input look non-seekable
        // and can leave iPadOS waiting on a black surface after a Range hop.
        media.addOption(":http-reconnect")
        media.addOption(":input-fast-seek")
        if usesAVFormatDemux {
            media.addOption(":demux=avformat")
        }
        media.addOption(request.forcesSoftwareDecoding ? ":avcodec-hw=none" : ":avcodec-hw=any")
        // MobileVLCKit's freetype-font option expects a readable font file.
        // Copy the system CJK collection into the app cache once so embedded
        // subtitles can render on iOS without relying on a protected system
        // path. External normalized subtitles use the UIKit overlay below.
        media.addOption(":text-renderer=freetype")
        if let cjkFontPath = Self.cjkFontPath {
            media.addOption(":freetype-font=\(cjkFontPath)")
        }
        if request.externalSubtitleURL != nil {
            // External SRT/ASS is rendered by UIKit with a guaranteed CJK
            // font. Prevent VLC from drawing a second tofu/duplicate line.
            media.addOption(":no-spu")
        }
        // Chinese subtitle files in real NAS libraries are a mixture of UTF-8,
        // GBK and legacy GB18030.  Forcing UTF-8 makes the latter render as
        // mojibake (the problem seen in the Mission: Impossible 3 sample).
        // Keep GB18030 as the fallback while asking VLC to auto-detect UTF-8;
        // this preserves modern ASS/SRT files and decodes older ANSI files.
        media.addOption(":subsdec-encoding=GB18030")
        media.addOption(":subsdec-autodetect-utf8=1")
        // Keep text subtitles inside the safe video area. This prevents the
        // second Chinese line from being clipped by the iPhone/iPad bottom
        // inset while retaining a visible outline on bright scenes.
        media.addOption(":sub-margin=32")
        media.addOption(":freetype-outline-thickness=2")
        media.addOption(":freetype-shadow-opacity=128")
        media.addOption(":freetype-rel-fontsize=18")
        return media
    }

    private var networkCachingMilliseconds: Int {
        let isPrivateRoute = request.isPrivateNetworkRoute
            ?? NetworkHostClassifier.isPrivate(request.networkOriginURL.host)
        // Direct HTTP Range files benefit from a short buffer: it keeps
        // startup and seeking responsive. A Jellyfin HLS fallback, however,
        // gets its data one transcoded segment at a time. The old shared
        // 900 ms private-LAN value made a brief NAS transcoder or Wi-Fi jitter
        // immediately visible as repeated stalls. Give HLS enough runway to
        // bridge several segment boundaries without penalising direct play.
        if isHLSCompatibilityStream {
            return isPrivateRoute ? 5_000 : 7_500
        }
        return isPrivateRoute ? 900 : 1_500
    }

    private var isHLSCompatibilityStream: Bool {
        request.source == .jellyfin && request.fileExtensionHint == "m3u8"
    }

    private static var cjkFontPath: String? {
        var sourcePath: String?
        for family in ["PingFangSC-Regular", "HiraginoSansGB-W3"] {
            let font = CTFontCreateWithName(family as CFString, 18, nil)
            if let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL {
                sourcePath = url.path
                break
            }
        }
        sourcePath = sourcePath ?? [
            "/System/Library/Fonts/LanguageSupport/PingFang.ttc",
            "/System/Library/Fonts/LanguageSupport/Hiragino Sans GB.ttc",
            "/System/Library/Fonts/PingFang.ttc",
            "/System/Library/Fonts/Hiragino Sans GB.ttc"
        ].first { FileManager.default.fileExists(atPath: $0) }
        guard let sourcePath, FileManager.default.fileExists(atPath: sourcePath) else {
            return nil
        }

        let cacheDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Nastart/Fonts", isDirectory: true)
        let cachedFontURL = cacheDirectory.appendingPathComponent("NastartCJK.ttc")
        if !FileManager.default.fileExists(atPath: cachedFontURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: cacheDirectory,
                    withIntermediateDirectories: true
                )
                let fontData = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
                try fontData.write(to: cachedFontURL, options: .atomic)
            } catch {
                return sourcePath
            }
        }
        return cachedFontURL.path
    }

    private var usesAVFormatDemux: Bool {
        request.fileExtensionHint == "ts" || request.fileExtensionHint == "m2ts"
    }

    func attach(to view: UIView) {
        if let drawable = player.drawable as AnyObject?, drawable === view {
            return
        }
        player.drawable = view
        player.scaleFactor = 0
    }

    func detach(from view: UIView) {
        guard let drawable = player.drawable as AnyObject?, drawable === view else {
            return
        }
        player.drawable = nil
    }

    func play() {
        didRequestStop = false
        didFinishPlaybackNaturally = false
        isUserPaused = false
        didReissueStartupPlay = false
        if !didRecordStart {
            didRecordStart = true
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_started",
                details: MediaPlaybackProbe.baseDetails(for: request).merging([
                    "engine": "MobileVLCKit",
                    "customTLSRoot": hasCustomTLSRoot ? "on" : "off",
                    "decoder": request.forcesSoftwareDecoding ? "software" : "automatic",
                    "demux": usesAVFormatDemux ? "avformat" : "default",
                    "networkCachingMs": "\(networkCachingMilliseconds)",
                    "transport": isHLSCompatibilityStream ? "jellyfinHLS" : "directHTTP",
                    "httpMode": "file",
                    "subtitleFont": Self.cjkFontPath ?? "default",
                    "subtitleEncoding": "GB18030+UTF8Autodetect"
                ]) { current, _ in current }
            )
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        // External normalized subtitles are rendered by CJKSubtitleOverlay.
        // Do not add the same file as a VLC playback slave as well: that
        // produces a second subtitle layer (often tofu boxes) underneath the
        // UIKit-rendered Chinese text.
        scheduleStartupPlayRetries()
        syncState()
    }

    func togglePlayback() {
        if player.isPlaying {
            isUserPaused = true
            reconnectWorkItem?.cancel()
            reconnectWorkItem = nil
            startupPlayRetryWorkItem?.cancel()
            startupPlayRetryWorkItem = nil
            unexpectedPauseRecoveryWorkItem?.cancel()
            unexpectedPauseRecoveryWorkItem = nil
            player.pause()
        } else {
            isUserPaused = false
            lastPlaybackProgressAt = Date()
            player.play()
            scheduleStartupPlayRetries()
        }
        syncState()
    }

    func jump(by seconds: Int) {
        isBuffering = true
        cancelPendingReconnectForUserSeek()
        pendingJumpSeconds += seconds
        if pendingJumpWorkItem == nil {
            let originSeconds = max(Double(player.time.intValue) / 1_000, 0)
            beginSeekMeasurement(
                targetSeconds: max(originSeconds + Double(pendingJumpSeconds), 0)
            )
        } else if let pendingSeekOriginSeconds {
            pendingSeekTargetSeconds = max(
                pendingSeekOriginSeconds + Double(pendingJumpSeconds),
                0
            )
        }
        pendingJumpWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let seconds = self.pendingJumpSeconds
            self.pendingJumpSeconds = 0
            self.pendingJumpWorkItem = nil
            if seconds < 0 {
                self.player.jumpBackward(Int32(clamping: -seconds))
            } else if seconds > 0 {
                self.player.jumpForward(Int32(clamping: seconds))
            }
        }
        pendingJumpWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: workItem)
    }

    func seek(to newPosition: Double) {
        guard player.isSeekable else { return }
        isBuffering = true
        cancelPendingReconnectForUserSeek()
        let position = min(max(newPosition, 0), 1)
        let runtime = max(Double(player.media?.length.intValue ?? 0) / 1_000, 0)
        beginSeekMeasurement(targetSeconds: runtime > 0 ? runtime * position : nil)
        player.position = Float(position)
    }

    @discardableResult
    func seek(toAbsoluteSeconds targetSeconds: Double) -> Bool {
        guard player.isSeekable, targetSeconds.isFinite else { return false }
        let rawDuration = max(Double(player.media?.length.intValue ?? 0) / 1_000, 0)
        let rawTarget = targetSeconds - request.timelineOffsetSeconds
        guard rawDuration > 0, rawTarget >= 0, rawTarget <= rawDuration else { return false }
        isBuffering = true
        cancelPendingReconnectForUserSeek()
        beginSeekMeasurement(targetSeconds: targetSeconds)
        player.position = Float(min(max(rawTarget / rawDuration, 0), 1))
        return true
    }

    func setPlaybackRate(_ rate: Float) {
        let normalizedRate = min(max(rate, 0.25), 4)
        desiredPlaybackRate = normalizedRate
        didApplyPlaybackRate = true
        player.rate = normalizedRate
        playbackRate = normalizedRate
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.playback_rate_changed",
            details: ["rate": String(format: "%.2f", normalizedRate)]
        )
    }

    func toggleMute() {
        guard let audio = player.audio else { return }
        let muted = !audio.isMuted
        audio.isMuted = muted
        isMuted = muted
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.mute_changed",
            details: ["muted": muted ? "yes" : "no"]
        )
    }

    func selectSubtitle(_ track: VLCSubtitleTrack) {
        guard pendingSubtitleTrackSelection?.targetID != track.id,
              selectedSubtitleTrackID != track.id else {
            return
        }
        let selection = PendingVLCTrackSelection(
            targetID: track.id,
            previousID: player.currentVideoSubTitleIndex,
            startedAt: Date()
        )
        desiredSubtitleTrackID = track.id
        didApplyInitialSubtitleTrack = true
        pendingSubtitleTrackSelection = selection
        selectedSubtitleTrackID = track.id
        recordTrackSelectionRequested(selection, kind: .subtitle)
        player.currentVideoSubTitleIndex = track.id
        scheduleTrackSelectionCheck(kind: .subtitle)
    }

    @discardableResult
    func selectExternalSubtitle(_ url: URL?) -> Bool {
        didApplyInitialSubtitleTrack = true
        desiredSubtitleTrackID = -1
        selectedSubtitleTrackID = -1
        player.currentVideoSubTitleIndex = -1
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.external_subtitle",
            details: [
                "operation": "runtimeOverlaySelection",
                "selected": url == nil ? "off" : "normalizedUTF8"
            ]
        )
        return true
    }

    func selectAudio(_ track: VLCAudioTrack) {
        guard pendingAudioTrackSelection?.targetID != track.id,
              selectedAudioTrackID != track.id else {
            return
        }
        let selection = PendingVLCTrackSelection(
            targetID: track.id,
            previousID: player.currentAudioTrackIndex,
            startedAt: Date()
        )
        desiredAudioTrackID = track.id
        didApplyInitialAudioTrack = true
        pendingAudioTrackSelection = selection
        selectedAudioTrackID = track.id
        recordTrackSelectionRequested(selection, kind: .audio)
        player.currentAudioTrackIndex = track.id
        scheduleTrackSelectionCheck(kind: .audio)
    }

    func stop() {
        didRequestStop = true
        isUserPaused = false
        reconnectWorkItem?.cancel()
        startupPlayRetryWorkItem?.cancel()
        unexpectedPauseRecoveryWorkItem?.cancel()
        audioTrackSelectionCheckWorkItem?.cancel()
        subtitleTrackSelectionCheckWorkItem?.cancel()
        player.stop()
    }

    private func scheduleStartupPlayRetries() {
        startupPlayRetryWorkItem?.cancel()
        startupPlayRetryWorkItem = nil
        startupPlayRetryCount = 0

        guard !didRequestStop, !isUserPaused, !didReachPlayback else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.startupPlayRetryWorkItem = nil
            guard
                !self.didRequestStop,
                !self.isUserPaused,
                !self.didReachPlayback,
                !self.player.isPlaying,
                self.errorMessage == nil,
                self.startupPlayRetryCount < 12
            else {
                return
            }

            self.startupPlayRetryCount += 1
            self.player.play()
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_state",
                details: [
                    "engine": "MobileVLCKit",
                    "state": "startupPlayRetry",
                    "attempt": "\(self.startupPlayRetryCount)",
                    "reason": "playbackNotStarted"
                ]
            )
            self.scheduleNextStartupPlayRetry()
        }
        startupPlayRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func scheduleNextStartupPlayRetry() {
        guard
            !didRequestStop,
            !isUserPaused,
            !didReachPlayback,
            !player.isPlaying,
            startupPlayRetryCount < 12
        else {
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.startupPlayRetryWorkItem = nil
            guard
                !self.didRequestStop,
                !self.isUserPaused,
                !self.didReachPlayback,
                !self.player.isPlaying,
                self.errorMessage == nil,
                self.startupPlayRetryCount < 12
            else {
                return
            }
            self.startupPlayRetryCount += 1
            self.player.play()
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_state",
                details: [
                    "engine": "MobileVLCKit",
                    "state": "startupPlayRetry",
                    "attempt": "\(self.startupPlayRetryCount)",
                    "reason": "playbackNotStarted"
                ]
            )
            self.scheduleNextStartupPlayRetry()
        }
        startupPlayRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func scheduleUnexpectedPauseRecovery() {
        guard
            unexpectedPauseRecoveryWorkItem == nil,
            !didRequestStop,
            !didFinishPlaybackNaturally,
            !isUserPaused,
            didReachPlayback || player.time.intValue > 500,
            hasAlternateTransport,
            errorMessage == nil
        else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.unexpectedPauseRecoveryWorkItem = nil
            guard
                !self.didRequestStop,
                !self.didFinishPlaybackNaturally,
                !self.isUserPaused,
                self.didReachPlayback || self.player.time.intValue > 500,
                self.hasAlternateTransport,
                self.errorMessage == nil,
                !self.player.isPlaying
            else {
                return
            }
            self.fail(reason: "unexpectedPause")
        }
        unexpectedPauseRecoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }

    func pauseForExternalHandoff() {
        isUserPaused = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        player.pause()
        syncState()
    }

    func runtimeState(orientationMode: PlayerOrientationMode) -> MediaPlaybackRuntimeState {
        let selectableAudioIDs = audioTracks.map(\.id).filter { $0 >= 0 }
        let selectableSubtitleIDs = subtitleTracks.map(\.id).filter { $0 >= 0 }
        let audioOrdinal = selectableAudioIDs.firstIndex(of: selectedAudioTrackID)
        let subtitlesDisabled = selectedSubtitleTrackID < 0
        return MediaPlaybackRuntimeState(
            normalizedPosition: position,
            positionSeconds: currentTimeSeconds,
            playbackRate: desiredPlaybackRate,
            audioTrackOrdinal: audioOrdinal,
            subtitleTrackOrdinal: subtitlesDisabled
                ? nil
                : selectableSubtitleIDs.firstIndex(of: selectedSubtitleTrackID),
            subtitlesDisabled: subtitlesDisabled,
            subtitleSelectionKnown: didApplyInitialSubtitleTrack || !lastSubtitleTrackIDs.isEmpty,
            orientationMode: orientationMode
        )
    }

    func failIfStillLoading() {
        guard !didReachPlayback, errorMessage == nil else { return }
        let state = Self.stateDescription(player.state)
        let reason = player.isPlaying ? "playbackClockTimeout" : "loadTimeout"
        let videoSize = player.videoSize
        let hasVideoOutput = player.hasVideoOut
        errorMessage = NSLocalizedString("player.load_timeout", comment: "")
        isBuffering = false
        player.stop()
        DiagnosticLogStore.shared.record(
            .error,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_failed",
            details: [
                "requestID": String(request.id.uuidString.prefix(8)),
                "title": request.title,
                "engine": "MobileVLCKit",
                "state": state,
                "reason": reason,
                "decoder": request.forcesSoftwareDecoding ? "software" : "automatic",
                "hasVideoOutput": hasVideoOutput ? "yes" : "no",
                "videoSize": "\(Int(videoSize.width))x\(Int(videoSize.height))",
                "playbackClockSeconds": lastObservedPlaybackSeconds.map {
                    String(format: "%.1f", $0)
                } ?? "-",
                "fallbackAvailable": hasAlternateTransport ? "yes" : "no",
                "reconnectAttempts": "\(reconnectAttempts)"
            ]
        )
    }

    func initialLoadGraceNanosecondsIfNeeded() -> UInt64 {
        guard !didReachPlayback, errorMessage == nil else { return 0 }
        // An elementary-stream notification is not a rendered frame for an
        // original file. Only HLS is allowed the longer segment-start grace.
        guard request.fileExtensionHint == "m3u8" else { return 0 }
        let state = Self.stateDescription(player.state).lowercased()
        let hasActiveInput = player.isPlaying
            || state.contains("elementarystreamadded")
        guard hasActiveInput else { return 0 }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_state",
            details: [
                "requestID": String(request.id.uuidString.prefix(8)),
                "title": request.title,
                "engine": "MobileVLCKit",
                "state": "initialLoadGrace",
                "observedState": state,
                "graceSeconds": "20"
            ]
        )
        return 20_000_000_000
    }

    func recoverIfStalled() {
        guard
            !didRequestStop,
            !didFinishPlaybackNaturally,
            !isUserPaused,
            player.state != .paused,
            errorMessage == nil
        else {
            return
        }
        // Jellyfin original playback is deliberately attempted first, but a
        // device-specific decoder or a large Matroska seek can stop after the
        // first frame. In that case the already-negotiated server fallback is
        // the safe recovery. Do not wait forever just because the URL is not
        // an HLS playlist.
        guard hasAlternateTransport,
              request.source == .jellyfin || request.source == .dsmFile else {
            return
        }
        let now = Date()
        if didReachPlayback,
           let lastPlaybackProgressAt,
           now.timeIntervalSince(lastPlaybackProgressAt) >= 1.5,
           !isBuffering {
            isBuffering = true
            recordBufferingTransition(isBuffering: true)
        }
        guard didReachPlayback else { return }
        if isReconnecting {
            guard let reconnectStartedAt,
                  Date().timeIntervalSince(reconnectStartedAt) >= reconnectTimeout else {
                return
            }
            isReconnecting = false
            self.reconnectStartedAt = nil
            if reconnectAttempts < maximumReconnectAttempts {
                scheduleReconnect(reason: "reconnectTimeout")
            } else {
                fail(reason: "reconnectLimit")
            }
            return
        }
        guard let lastPlaybackProgressAt,
              now.timeIntervalSince(lastPlaybackProgressAt) >= stallTimeout,
              isBuffering || !player.isPlaying else {
            return
        }
        fail(reason: request.fileExtensionHint == "m3u8"
            ? "alternateTransportPreferred"
            : "originalPlaybackStall")
    }

    func mediaPlayerStateChanged(_ notification: Notification) {
        if player.state == .esAdded {
            trackInventoryNeedsRefresh = true
        }
        pendingTimeStateSyncWorkItem?.cancel()
        pendingTimeStateSyncWorkItem = nil
        lastTimeStateSyncAt = Date()
        syncState()
    }

    func mediaPlayerTimeChanged(_ notification: Notification) {
        let elapsed = Date().timeIntervalSince(lastTimeStateSyncAt)
        if elapsed >= minimumTimeStateSyncInterval {
            pendingTimeStateSyncWorkItem?.cancel()
            pendingTimeStateSyncWorkItem = nil
            lastTimeStateSyncAt = Date()
            syncState()
            return
        }
        guard pendingTimeStateSyncWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingTimeStateSyncWorkItem = nil
            self.lastTimeStateSyncAt = Date()
            self.syncState()
        }
        pendingTimeStateSyncWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(minimumTimeStateSyncInterval - elapsed, 0),
            execute: workItem
        )
    }

    private func syncState() {
        let isPlaying = player.isPlaying
        let isSeekable = player.isSeekable
        let rawPosition = Double(max(player.position, 0))
        let stateDescription = Self.stateDescription(player.state)
        let normalizedState = stateDescription.lowercased()
        if !isPlaying,
           didReachPlayback || player.time.intValue > 500 {
            scheduleUnexpectedPauseRecovery()
        } else if isPlaying {
            unexpectedPauseRecoveryWorkItem?.cancel()
            unexpectedPauseRecoveryWorkItem = nil
        }
        let inputIsReadyForInitialSeek = isPlaying
            || player.state == .esAdded
            || didReachPlayback
        if !didApplyInitialPosition,
           request.timelineOffsetSeconds == 0,
           isSeekable,
           inputIsReadyForInitialSeek,
           let resumePosition = pendingResumePosition ?? initialPosition,
           resumePosition > 0 {
            didApplyInitialPosition = true
            pendingResumePosition = nil
            suppressNextClockAdvanceForInitialSeek = true
            player.position = Float(resumePosition)
        }
        let reportsBuffering = normalizedState.contains("opening") || normalizedState.contains("buffering")
        if reportsBuffering,
           !didReachPlayback,
           !isUserPaused,
           !didRequestStop,
           !player.isPlaying,
           !didReissueStartupPlay {
            // Some authenticated Jellyfin Range responses enter VLC's
            // buffering state without retaining the initial play command.
            // Reissue it once during startup so the user does not have to
            // tap Play manually after an otherwise valid first response.
            didReissueStartupPlay = true
            player.play()
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_state",
                details: [
                    "engine": "MobileVLCKit",
                    "state": "startupPlayReissued",
                    "reason": "bufferingWithoutPlaying"
                ]
            )
        }
        applySubtitleStyleIfNeeded(isRendererReady: reportsBuffering || player.isPlaying)
        let rawCurrentSeconds = max(Double(player.time.intValue) / 1_000, 0)
        let rawDurationSeconds = max(Double(player.media?.length.intValue ?? 0) / 1_000, 0)
        let durationSeconds = request.totalDurationSeconds ?? rawDurationSeconds
        let currentSeconds = min(
            request.timelineOffsetSeconds + rawCurrentSeconds,
            durationSeconds > 0 ? durationSeconds : .greatestFiniteMagnitude
        )
        let position = durationSeconds > 0
            ? min(max(currentSeconds / durationSeconds, 0), 1)
            : rawPosition
        let currentTimeText = Self.timeText(seconds: currentSeconds)
        let durationText = durationSeconds > 0
            ? Self.timeText(seconds: durationSeconds)
            : "--:--"
        let videoSize = player.videoSize
        let hasVideoOutput = player.hasVideoOut
            && videoSize.width > 0
            && videoSize.height > 0
        let rawPlaybackClockAdvanced = lastObservedPlaybackSeconds.map {
            abs(currentSeconds - $0) >= 0.2
        } ?? false
        let playbackClockAdvanced: Bool
        if suppressNextClockAdvanceForInitialSeek {
            // A resume seek can move VLC's clock by several minutes before a
            // single frame is rendered. Do not count that jump as first-frame
            // evidence; wait for the next real playback tick.
            suppressNextClockAdvanceForInitialSeek = false
            playbackClockAdvanced = false
        } else {
            playbackClockAdvanced = rawPlaybackClockAdvanced
        }
        let now = Date()
        if playbackClockAdvanced {
            lastPlaybackProgressAt = now
            if isReconnecting {
                isReconnecting = false
                reconnectStartedAt = nil
            }
        }
        // hasVideoOut only means that VLC created a video output object. It is
        // not proof that a frame reached the screen. Requiring the media clock
        // to advance prevents a black iPad surface from being marked ready and
        // lets the bounded Jellyfin fallback run.
        let presentedMedia = request.isAudioOnly
            ? playbackClockAdvanced
            : hasVideoOutput && playbackClockAdvanced
        if presentedMedia, !didReachPlayback {
            didReachPlayback = true
            lastPlaybackProgressAt = now
        }
        let playbackClockRecentlyAdvanced = playbackClockAdvanced
            // MobileVLCKit can publish its media clock at roughly one-second
            // intervals for HLS even while decoded frames continue flowing.
            // Keep the grace window above that cadence so the UI and
            // diagnostics do not report a 250 ms "buffer" once per second.
            || lastPlaybackProgressAt.map { now.timeIntervalSince($0) < 1.5 } == true
        let isWaitingForSeekRecovery = pendingSeekStartedAt != nil && !playbackClockAdvanced
        let hasActionableBufferingState = request.fileExtensionHint == "m3u8"
        let isBuffering = reportsBuffering
            && (!didReachPlayback
                || (hasActionableBufferingState
                    && (isWaitingForSeekRecovery || !playbackClockRecentlyAdvanced)))
        if player.isPlaying, !didApplyPlaybackRate {
            didApplyPlaybackRate = true
            player.rate = desiredPlaybackRate
        }
        if didReachPlayback, !didRecordFirstFrame {
            didRecordFirstFrame = true
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_ready",
                details: MediaPlaybackProbe.baseDetails(for: request).merging([
                    "engine": "MobileVLCKit",
                    "readySignal": request.isAudioOnly
                        ? "playbackClock"
                        : "videoOutput+playbackClock",
                    "tapToFirstFrameMs": Self.elapsedMilliseconds(since: request.requestedAt)
                ]) { current, _ in current }
            )
        }
        recordBufferingTransition(isBuffering: isBuffering)
        recordSeekRecoveryIfNeeded(currentSeconds: currentSeconds, isBuffering: isBuffering)
        lastObservedPlaybackSeconds = currentSeconds
        if currentSeconds > highestPlaybackSeconds + 0.2 {
            highestPlaybackSeconds = currentSeconds
            if reconnectAttempts > 0,
               currentSeconds >= reconnectRecoveryBaselineSeconds + 10 {
                reconnectAttempts = 0
                reconnectRecoveryBaselineSeconds = currentSeconds
            }
        }
        if isPlaying {
            request.playbackTracker?.started(positionSeconds: currentSeconds)
        }
        request.playbackTracker?.progressed(
            positionSeconds: currentSeconds,
            isPaused: !isPlaying
        )
        let stateErrorMessage = player.state == .error
            ? NSLocalizedString("player.compatibility_failed", comment: "")
            : nil
        refreshTrackInventoryIfNeeded()
        applyInitialTrackSelectionIfNeeded(
            audioIndexes: lastAudioTrackIDs,
            subtitleIndexes: lastSubtitleTrackIDs
        )
        let actualSubtitleTrackID = player.currentVideoSubTitleIndex
        let actualAudioTrackID = player.currentAudioTrackIndex
        let selectedSubtitleTrackID = reconciledTrackSelectionID(
            actualID: actualSubtitleTrackID,
            kind: .subtitle
        )
        let selectedAudioTrackID = reconciledTrackSelectionID(
            actualID: actualAudioTrackID,
            kind: .audio
        )
        let furthestPlaybackSeconds = max(currentSeconds, highestPlaybackSeconds)
        let naturalEndToleranceSeconds = min(max(durationSeconds * 0.01, 3), 10)
        let reachedNaturalEnd = durationSeconds > 0
            && furthestPlaybackSeconds >= max(
                durationSeconds - naturalEndToleranceSeconds,
                0
            )
        // A finite input can report `ended` when its current HTTP window is
        // exhausted. It is only a natural completion when the duration is
        // unknown; known-duration media must still pass the near-end check
        // above or recovery would be suppressed at a mid-stream EOF.
        let finiteInputEnded = player.state == .ended
            && request.fileExtensionHint != "m3u8"
            && durationSeconds <= 0
        let completedNaturally = reachedNaturalEnd || finiteInputEnded
        if completedNaturally
            && (player.state == .ended || player.state == .stopped) {
            didFinishPlaybackNaturally = true
        }
        let endedPrematurely = player.state == .ended
            && !completedNaturally
            && didRecordStart
            && didReachPlayback
            && !didRequestStop
            && !isUserPaused
            && errorMessage == nil
        if endedPrematurely {
            if hasAlternateTransport {
                fail(reason: "prematureEnd")
            } else if !isReconnecting,
                      reconnectAttempts < maximumReconnectAttempts,
                      reconnectWorkItem == nil {
                scheduleReconnect(reason: "prematureEnd")
            }
        }
        let previousState = lastStateDescription.lowercased()
        let inputEndedBeforeFirstFrame = (player.state == .ended || player.state == .stopped)
            && !didReachPlayback
            && didRecordStart
            && !didRequestStop
            && !isUserPaused
            && errorMessage == nil
            && (!lastAudioTrackIDs.isEmpty
                || previousState.contains("playing")
                || previousState.contains("elementarystreamadded")
                || previousState.contains("opening")
                || previousState.contains("buffering"))
        if inputEndedBeforeFirstFrame {
            if hasAlternateTransport {
                fail(reason: "prematureEndBeforeFirstFrame")
            } else if !isReconnecting,
                      reconnectAttempts < maximumReconnectAttempts,
                      reconnectWorkItem == nil {
                scheduleReconnect(reason: "prematureEndBeforeFirstFrame")
            }
        }
        let stoppedUnexpectedly = player.state == .stopped && !didFinishPlaybackNaturally
        if stoppedUnexpectedly,
           didRecordStart,
           didReachPlayback,
           !didRequestStop,
           errorMessage == nil,
           !isReconnecting {
            if hasAlternateTransport {
                fail(reason: "unexpectedStop")
            } else if reconnectAttempts < maximumReconnectAttempts,
                      reconnectWorkItem == nil {
                scheduleReconnect(reason: "unexpectedStop")
            }
        }

        if stateDescription != lastStateDescription {
            lastStateDescription = stateDescription
            DiagnosticLogStore.shared.record(
                player.state == .error ? .error : .info,
                categoryKey: "diagnostics.category.media",
                messageKey: player.state == .error
                    ? "diagnostics.media.player_failed"
                    : "diagnostics.media.player_state",
                details: [
                    "engine": "MobileVLCKit",
                    "state": stateDescription,
                    "seekable": isSeekable ? "yes" : "no"
                ]
            )
        }

        if self.isPlaying != isPlaying { self.isPlaying = isPlaying }
        let isMuted = player.audio?.isMuted ?? false
        if self.isMuted != isMuted { self.isMuted = isMuted }
        if abs(self.position - position) >= 0.0001 { self.position = position }
        if self.isSeekable != isSeekable { self.isSeekable = isSeekable }
        if let stateErrorMessage {
            if self.errorMessage != stateErrorMessage { self.errorMessage = stateErrorMessage }
        }
        if subtitleTracks != cachedSubtitleTracks {
            subtitleTracks = cachedSubtitleTracks
        }
        if self.selectedSubtitleTrackID != selectedSubtitleTrackID {
            self.selectedSubtitleTrackID = selectedSubtitleTrackID
        }
        if audioTracks != cachedAudioTracks {
            audioTracks = cachedAudioTracks
        }
        if self.selectedAudioTrackID != selectedAudioTrackID {
            self.selectedAudioTrackID = selectedAudioTrackID
        }
        if self.isBuffering != isBuffering { self.isBuffering = isBuffering }
        if hasStartedPlayback != didReachPlayback { hasStartedPlayback = didReachPlayback }
        if self.currentTimeText != currentTimeText { self.currentTimeText = currentTimeText }
        if abs(self.currentTimeSeconds - currentSeconds) >= 0.05 {
            self.currentTimeSeconds = currentSeconds
        }
        if self.durationText != durationText { self.durationText = durationText }
        if abs(self.durationSeconds - durationSeconds) >= 0.05 {
            self.durationSeconds = durationSeconds
        }
        let currentRate = player.rate
        if playbackRate != currentRate { playbackRate = currentRate }
    }

    private static func timeText(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let totalSeconds = Int(seconds.rounded(.down))
        let hours = totalSeconds / 3_600
        let minutes = totalSeconds % 3_600 / 60
        let remainingSeconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func applyInitialTrackSelectionIfNeeded(
        audioIndexes: [Int32],
        subtitleIndexes: [Int32]
    ) {
        let selectableAudioIndexes = audioIndexes.filter { $0 >= 0 }
        if !didApplyInitialAudioTrack {
            if let desiredAudioTrackID,
               selectableAudioIndexes.contains(desiredAudioTrackID) {
                didApplyInitialAudioTrack = true
                player.currentAudioTrackIndex = desiredAudioTrackID
            } else if let preferredAudioTrackOrdinal,
                      selectableAudioIndexes.indices.contains(preferredAudioTrackOrdinal) {
                didApplyInitialAudioTrack = true
                player.currentAudioTrackIndex = selectableAudioIndexes[preferredAudioTrackOrdinal]
            }
        }

        guard !didApplyInitialSubtitleTrack else { return }
        if let desiredSubtitleTrackID {
            guard desiredSubtitleTrackID < 0 || subtitleIndexes.contains(desiredSubtitleTrackID) else {
                return
            }
            didApplyInitialSubtitleTrack = true
            player.currentVideoSubTitleIndex = desiredSubtitleTrackID
            return
        }
        if prefersSubtitlesDisabled {
            didApplyInitialSubtitleTrack = true
            player.currentVideoSubTitleIndex = -1
            return
        }
        guard externalSubtitleURL == nil,
              let preferredSubtitleTrackOrdinal else {
            return
        }
        let selectableSubtitleIndexes = subtitleIndexes.filter { $0 >= 0 }
        guard selectableSubtitleIndexes.indices.contains(preferredSubtitleTrackOrdinal) else {
            return
        }
        didApplyInitialSubtitleTrack = true
        player.currentVideoSubTitleIndex = selectableSubtitleIndexes[preferredSubtitleTrackOrdinal]
    }

    private func resetTrackInventoryRefreshWindow() {
        trackInventoryNeedsRefresh = true
        trackInventoryRefreshDeadline = Date().addingTimeInterval(8)
        lastTrackInventoryRefreshAt = nil
    }

    private func refreshTrackInventoryIfNeeded() {
        let now = Date()
        let isWithinStartupWindow = now < trackInventoryRefreshDeadline
        let startupRetryIsDue = isWithinStartupWindow
            && (lastTrackInventoryRefreshAt.map { now.timeIntervalSince($0) >= 0.75 } ?? true)
        guard trackInventoryNeedsRefresh || startupRetryIsDue else { return }
        trackInventoryNeedsRefresh = false
        lastTrackInventoryRefreshAt = now

        let subtitleNames = player.videoSubTitlesNames.compactMap { $0 as? String }
        let subtitleIndexes = player.videoSubTitlesIndexes.compactMap(Self.subtitleTrackID)
        let selectableSubtitleIndexes = subtitleIndexes.filter { $0 >= 0 }
        let subtitleDisplayNames = trackDisplayNames(
            rawNames: subtitleNames,
            allIndexes: subtitleIndexes,
            selectableIndexes: selectableSubtitleIndexes,
            sourceTracks: request.sourceSubtitleTracks,
            fallbackPrefix: NSLocalizedString("player.subtitles", comment: "")
        )
        let subtitleTracks = [VLCSubtitleTrack(
            id: -1,
            name: NSLocalizedString("player.subtitles.off", comment: "")
        )] + selectableSubtitleIndexes.enumerated().map { ordinal, id in
            VLCSubtitleTrack(id: id, name: subtitleDisplayNames[ordinal])
        }

        let audioNames = player.audioTrackNames.compactMap { $0 as? String }
        let audioIndexes = player.audioTrackIndexes.compactMap(Self.subtitleTrackID)
        let selectableAudioIndexes = audioIndexes.filter { $0 >= 0 }
        let audioDisplayNames = trackDisplayNames(
            rawNames: audioNames,
            allIndexes: audioIndexes,
            selectableIndexes: selectableAudioIndexes,
            sourceTracks: request.sourceAudioTracks,
            fallbackPrefix: NSLocalizedString("player.audio_tracks", comment: "")
        )
        let audioTracks = selectableAudioIndexes.enumerated().map { ordinal, id in
            VLCAudioTrack(id: id, name: audioDisplayNames[ordinal])
        }

        cachedSubtitleTracks = subtitleTracks
        cachedAudioTracks = audioTracks
        if didReachPlayback, !audioIndexes.isEmpty {
            trackInventoryRefreshDeadline = .distantPast
        }
        if subtitleIndexes != lastSubtitleTrackIDs {
            lastSubtitleTrackIDs = subtitleIndexes
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.subtitle_tracks",
                details: [
                    "count": "\(subtitleIndexes.filter { $0 >= 0 }.count)",
                    "selected": "\(player.currentVideoSubTitleIndex)"
                ]
            )
        }
        if audioIndexes != lastAudioTrackIDs {
            lastAudioTrackIDs = audioIndexes
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.audio_tracks",
                details: [
                    "count": "\(selectableAudioIndexes.count)",
                    "selected": "\(player.currentAudioTrackIndex)"
                ]
            )
        }
    }

    private func trackDisplayNames(
        rawNames: [String],
        allIndexes: [Int32],
        selectableIndexes: [Int32],
        sourceTracks: [MediaPlaybackSourceTrack],
        fallbackPrefix: String
    ) -> [String] {
        let indexedNames = Dictionary(
            uniqueKeysWithValues: zip(allIndexes, rawNames).map { ($0.0, $0.1) }
        )
        return selectableIndexes.enumerated().map { ordinal, id in
            if sourceTracks.indices.contains(ordinal) {
                return sourceTracks[ordinal].name
            }
            if let indexedName = indexedNames[id], !indexedName.isEmpty {
                return indexedName
            }
            return "\(fallbackPrefix) \(ordinal + 1)"
        }
    }

    private func reconciledTrackSelectionID(
        actualID: Int32,
        kind: VLCTrackSelectionKind
    ) -> Int32 {
        let pendingSelection = kind == .audio
            ? pendingAudioTrackSelection
            : pendingSubtitleTrackSelection
        guard let pendingSelection else { return actualID }
        if actualID == pendingSelection.targetID {
            finishTrackSelection(pendingSelection, kind: kind, didConfirm: true)
            return actualID
        }
        if Date().timeIntervalSince(pendingSelection.startedAt) >= 4 {
            finishTrackSelection(pendingSelection, kind: kind, didConfirm: false)
            return actualID
        }
        return pendingSelection.targetID
    }

    private func recordTrackSelectionRequested(
        _ selection: PendingVLCTrackSelection,
        kind: VLCTrackSelectionKind
    ) {
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.track_switch_requested",
            details: [
                "requestID": String(request.id.uuidString.prefix(8)),
                "title": request.title,
                "engine": "MobileVLCKit",
                "kind": kind.rawValue,
                "from": "\(selection.previousID)",
                "target": "\(selection.targetID)"
            ]
        )
    }

    private func scheduleTrackSelectionCheck(kind: VLCTrackSelectionKind) {
        let pendingSelection = kind == .audio
            ? pendingAudioTrackSelection
            : pendingSubtitleTrackSelection
        guard pendingSelection != nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if kind == .audio {
                self.audioTrackSelectionCheckWorkItem = nil
            } else {
                self.subtitleTrackSelectionCheckWorkItem = nil
            }
            let actualID = kind == .audio
                ? self.player.currentAudioTrackIndex
                : self.player.currentVideoSubTitleIndex
            let selectedID = self.reconciledTrackSelectionID(actualID: actualID, kind: kind)
            if kind == .audio {
                self.selectedAudioTrackID = selectedID
                if self.pendingAudioTrackSelection != nil {
                    self.scheduleTrackSelectionCheck(kind: kind)
                }
            } else {
                self.selectedSubtitleTrackID = selectedID
                if self.pendingSubtitleTrackSelection != nil {
                    self.scheduleTrackSelectionCheck(kind: kind)
                }
            }
        }
        if kind == .audio {
            audioTrackSelectionCheckWorkItem?.cancel()
            audioTrackSelectionCheckWorkItem = workItem
        } else {
            subtitleTrackSelectionCheckWorkItem?.cancel()
            subtitleTrackSelectionCheckWorkItem = workItem
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private func finishTrackSelection(
        _ selection: PendingVLCTrackSelection,
        kind: VLCTrackSelectionKind,
        didConfirm: Bool
    ) {
        if kind == .audio {
            pendingAudioTrackSelection = nil
            audioTrackSelectionCheckWorkItem?.cancel()
            audioTrackSelectionCheckWorkItem = nil
        } else {
            pendingSubtitleTrackSelection = nil
            subtitleTrackSelectionCheckWorkItem?.cancel()
            subtitleTrackSelectionCheckWorkItem = nil
        }
        DiagnosticLogStore.shared.record(
            didConfirm ? .info : .warning,
            categoryKey: "diagnostics.category.media",
            messageKey: didConfirm
                ? "diagnostics.media.track_switch_confirmed"
                : "diagnostics.media.track_switch_timeout",
            details: [
                "requestID": String(request.id.uuidString.prefix(8)),
                "title": request.title,
                "engine": "MobileVLCKit",
                "kind": kind.rawValue,
                "target": "\(selection.targetID)",
                "selectionMs": Self.elapsedMilliseconds(since: selection.startedAt)
            ]
        )
    }

    private func scheduleReconnect(reason: String) {
        guard
            reconnectWorkItem == nil,
            !isReconnecting,
            !isUserPaused,
            !didRequestStop
        else {
            return
        }
        reconnectAttempts += 1
        let resumePosition = max(Double(player.position), 0)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            guard !self.didRequestStop, !self.isUserPaused else { return }
            self.isReconnecting = true
            self.reconnectStartedAt = Date()
            self.reconnectRecoveryBaselineSeconds = self.highestPlaybackSeconds
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_state",
                details: [
                    "engine": "MobileVLCKit",
                    "state": "reconnecting",
                    "attempt": "\(self.reconnectAttempts)",
                    "reason": reason
                ]
            )
            self.pendingResumePosition = resumePosition
            if self.desiredAudioTrackID == nil, self.player.currentAudioTrackIndex >= 0 {
                self.desiredAudioTrackID = self.player.currentAudioTrackIndex
            }
            if self.desiredSubtitleTrackID == nil {
                self.desiredSubtitleTrackID = self.player.currentVideoSubTitleIndex
            }
            self.desiredPlaybackRate = self.player.rate
            self.lastPlaybackProgressAt = Date()
            self.lastObservedPlaybackSeconds = nil
            self.didApplyInitialPosition = false
            self.didApplyInitialAudioTrack = false
            self.didApplyInitialSubtitleTrack = false
            self.didApplyPlaybackRate = false
            self.didAddExternalSubtitle = false
            self.pendingAudioTrackSelection = nil
            self.pendingSubtitleTrackSelection = nil
            self.audioTrackSelectionCheckWorkItem?.cancel()
            self.subtitleTrackSelectionCheckWorkItem?.cancel()
            self.audioTrackSelectionCheckWorkItem = nil
            self.subtitleTrackSelectionCheckWorkItem = nil
            self.resetTrackInventoryRefreshWindow()
            self.player.stop()
            self.player.media = self.makeMedia()
            self.player.play()
        }
        reconnectWorkItem = workItem
        let delay = min(Double(reconnectAttempts), 3) * 0.75
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func fail(reason: String) {
        guard errorMessage == nil else { return }
        errorMessage = NSLocalizedString("player.compatibility_failed", comment: "")
        isBuffering = false
        player.stop()
        DiagnosticLogStore.shared.record(
            .error,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_failed",
            details: [
                "requestID": String(request.id.uuidString.prefix(8)),
                "title": request.title,
                "engine": "MobileVLCKit",
                "reason": reason,
                "reconnectAttempts": "\(reconnectAttempts)",
                "decoder": request.forcesSoftwareDecoding ? "software" : "automatic"
            ]
        )
    }

    private func cancelPendingReconnectForUserSeek() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        isReconnecting = false
        reconnectStartedAt = nil
        pendingResumePosition = nil
        lastObservedPlaybackSeconds = nil
        lastPlaybackProgressAt = Date()
    }

    private func beginSeekMeasurement(targetSeconds: Double?) {
        pendingSeekStartedAt = Date()
        pendingSeekOriginSeconds = max(Double(player.time.intValue) / 1_000, 0)
        pendingSeekTargetSeconds = targetSeconds
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.seek_requested",
            details: [
                "engine": "MobileVLCKit",
                "fromSeconds": String(format: "%.1f", pendingSeekOriginSeconds ?? 0),
                "targetSeconds": targetSeconds.map { String(format: "%.1f", $0) } ?? "-"
            ]
        )
    }

    private func recordSeekRecoveryIfNeeded(currentSeconds: Double, isBuffering: Bool) {
        guard
            let pendingSeekStartedAt,
            let pendingSeekOriginSeconds,
            !isBuffering,
            player.isPlaying
        else {
            return
        }
        let reachedRequestedRegion = pendingSeekTargetSeconds.map {
            abs(currentSeconds - $0) <= 1.5
        } ?? (abs(currentSeconds - pendingSeekOriginSeconds) >= 0.2)
        guard reachedRequestedRegion else { return }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.seek_ready",
            details: [
                "engine": "MobileVLCKit",
                "recoveryMs": Self.elapsedMilliseconds(since: pendingSeekStartedAt),
                "fromSeconds": String(format: "%.1f", pendingSeekOriginSeconds),
                "targetSeconds": pendingSeekTargetSeconds.map { String(format: "%.1f", $0) } ?? "-",
                "actualSeconds": String(format: "%.1f", currentSeconds)
            ]
        )
        self.pendingSeekStartedAt = nil
        self.pendingSeekOriginSeconds = nil
        self.pendingSeekTargetSeconds = nil
    }

    private func recordBufferingTransition(isBuffering: Bool) {
        guard isBuffering != lastBufferingState else { return }
        lastBufferingState = isBuffering
        if isBuffering {
            if didReachPlayback { bufferingStartedAt = Date() }
            return
        }
        guard let bufferingStartedAt else { return }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.buffer_recovered",
            details: [
                "engine": "MobileVLCKit",
                "bufferingMs": Self.elapsedMilliseconds(since: bufferingStartedAt)
            ]
        )
        self.bufferingStartedAt = nil
    }

    private static func elapsedMilliseconds(since date: Date) -> String {
        String(Int(max(Date().timeIntervalSince(date), 0) * 1_000))
    }

    private var hasAlternateTransport: Bool {
        request.compatibilityFallbackResource != nil
            || request.compatibilityFallbackResourceLoader != nil
            || request.compatibilityFallbackRequestLoader != nil
    }

    private var maximumReconnectAttempts: Int {
        request.source == .directURL ? 2 : 1
    }

    private var stallTimeout: TimeInterval {
        let isPrivateHost = request.isPrivateNetworkRoute
            ?? NetworkHostClassifier.isPrivate(request.networkOriginURL.host)
        switch request.source {
        case .jellyfin:
            if request.fileExtensionHint == "m3u8", hasAlternateTransport {
                return isPrivateHost ? 12 : 10
            }
            // Keep original-stream grace aligned with the proven DSM route.
            // This is a transport policy, not a title-specific tuning knob.
            return isPrivateHost ? 18 : 30
        case .dsmFile:
            return isPrivateHost ? 18 : 30
        case .directURL:
            return 20
        }
    }

    private func applySubtitleStyleIfNeeded(isRendererReady: Bool) {
        guard isRendererReady, !didApplySubtitleStyle else { return }
        let selector = NSSelectorFromString("setTextRendererFontSize:")
        guard player.responds(to: selector) else { return }
        didApplySubtitleStyle = true
        _ = player.perform(selector, with: NSNumber(value: 18))
    }

    private func addExternalSubtitleIfNeeded() {
        guard !didAddExternalSubtitle, let externalSubtitleURL else { return }
        didAddExternalSubtitle = true
        subtitleTrackIDsBeforeExternalAdd = Set(
            player.videoSubTitlesIndexes.compactMap(Self.subtitleTrackID)
        )
        let result = player.addPlaybackSlave(
            externalSubtitleURL,
            type: .subtitle,
            enforce: true
        )
        DiagnosticLogStore.shared.record(
            result == 0 ? .info : .warning,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.external_subtitle",
                details: ["result": "\(result)"]
        )
        if result == 0 {
            selectNewExternalSubtitleTrack(after: 0.35, remainingAttempts: 12)
        }
    }

    private func selectNewExternalSubtitleTrack(
        after delay: TimeInterval,
        remainingAttempts: Int
    ) {
        externalSubtitleSelectionWorkItem?.cancel()
        guard remainingAttempts > 0 else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.didRequestStop else { return }
            let indexes = self.player.videoSubTitlesIndexes
                .compactMap(Self.subtitleTrackID)
                .filter { $0 >= 0 }
            let names = self.player.videoSubTitlesNames.compactMap { $0 as? String }
            let externalFilename = self.externalSubtitleURL?.lastPathComponent.lowercased() ?? ""
            let newIndexes = indexes.filter {
                !self.subtitleTrackIDsBeforeExternalAdd.contains($0)
            }
            var namedExternalIndex: Int32?
            for (ordinal, index) in indexes.enumerated() {
                if names.indices.contains(ordinal) {
                    let name = names[ordinal].lowercased()
                    if (!externalFilename.isEmpty && name.contains(externalFilename))
                        || name.contains("jellyfin.utf8")
                        || name.contains("nastart") {
                        namedExternalIndex = index
                    }
                }
            }
            let onlyTrackIsNew = self.subtitleTrackIDsBeforeExternalAdd.isEmpty
                && indexes.count == 1
            if let externalTrackID = namedExternalIndex
                ?? (onlyTrackIsNew ? indexes.first : newIndexes.last) {
                // When the media stream has not exposed its embedded subtitle
                // IDs before addPlaybackSlave, a transient inventory can make
                // every track look new. Do not select the last embedded track
                // until VLC identifies the added file by name, or until there
                // was a pre-existing inventory to compare against.
                guard !self.subtitleTrackIDsBeforeExternalAdd.isEmpty
                    || namedExternalIndex != nil
                    || onlyTrackIsNew else {
                    self.selectNewExternalSubtitleTrack(
                        after: 0.35,
                        remainingAttempts: remainingAttempts - 1
                    )
                    return
                }
                self.didApplyInitialSubtitleTrack = true
                self.desiredSubtitleTrackID = externalTrackID
                self.selectedSubtitleTrackID = externalTrackID
                self.player.currentVideoSubTitleIndex = externalTrackID
                DiagnosticLogStore.shared.record(
                    .info,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.external_subtitle",
                    details: [
                        "operation": "selectAddedTrack",
                        "trackID": "\(externalTrackID)",
                        "trackCount": "\(indexes.count)"
                    ]
                )
                self.syncState()
                return
            }
            self.selectNewExternalSubtitleTrack(
                after: 0.35,
                remainingAttempts: remainingAttempts - 1
            )
        }
        externalSubtitleSelectionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private static func subtitleTrackID(_ value: Any) -> Int32? {
        if let number = value as? NSNumber { return number.int32Value }
        if let value = value as? Int32 { return value }
        if let value = value as? Int { return Int32(clamping: value) }
        if let value = value as? String, let parsed = Int32(value) { return parsed }
        return nil
    }

    private static func stateDescription(_ state: VLCMediaPlayerState) -> String {
        switch state {
        case .stopped: return "stopped"
        case .opening: return "opening"
        case .buffering: return "buffering"
        case .ended: return "ended"
        case .error: return "error"
        case .playing: return "playing"
        case .paused: return "paused"
        case .esAdded: return "elementaryStreamAdded"
        @unknown default: return "unknown(\(state.rawValue))"
        }
    }

    deinit {
        pendingJumpWorkItem?.cancel()
        pendingTimeStateSyncWorkItem?.cancel()
        reconnectWorkItem?.cancel()
        externalSubtitleSelectionWorkItem?.cancel()
        player.stop()
    }
}

#endif

private struct VLCPlayerTrackOption: Identifiable {
    let id: Int32
    let name: String
}

private enum VLCPlayerPanel: String, Identifiable {
    case settings
    case audio
    case subtitles
    case quality

    var id: String { rawValue }
}

private enum VLCPlayerPanMode {
    case seeking
    case brightness
}

private struct CJKSubtitleCue {
    let start: Double
    let end: Double
    let text: String
}

final class CJKSubtitleOverlayModel: ObservableObject {
    @Published private(set) var text: String?
    @Published private(set) var isEnabled = false
    private var cues: [CJKSubtitleCue] = []
    private var loadTask: Task<Void, Never>?
    private var subtitleURL: URL?
    private var currentTime = 0.0
    private var cueCache: [URL: [CJKSubtitleCue]] = [:]
    private var cachedURLs: [URL] = []

    deinit {
        loadTask?.cancel()
    }

    func setURL(_ url: URL?) {
        guard subtitleURL != url else { return }
        subtitleURL = url
        isEnabled = url != nil
        text = nil
        cues = []
        loadTask?.cancel()
        guard let url else { return }
        if let cached = cueCache[url] {
            cues = cached
            applyCurrentTime()
            return
        }
        loadTask = Task { @MainActor [weak self] in
            let loadedCues = await Self.loadCues(from: url)
            guard !Task.isCancelled, let self, subtitleURL == url else { return }
            if !loadedCues.isEmpty {
                cueCache[url] = loadedCues
                cachedURLs.append(url)
                if cachedURLs.count > 4 { cueCache.removeValue(forKey: cachedURLs.removeFirst()) }
            } else {
                // Permit an explicit retry after a transient request failure.
                subtitleURL = nil
            }
            cues = loadedCues
            applyCurrentTime()
            DiagnosticLogStore.shared.record(loadedCues.isEmpty ? .warning : .info,
                categoryKey: "diagnostics.category.media", messageKey: "diagnostics.playback.subtitle_overlay_loaded",
                details: ["cueCount": String(loadedCues.count), "currentSeconds": String(currentTime),
                          "localFile": String(url.isFileURL), "visible": String(text != nil)])
        }
    }

    func update(time: Double) {
        currentTime = time
        applyCurrentTime()
    }

    private func applyCurrentTime() {
        guard !cues.isEmpty, currentTime.isFinite else {
            text = nil
            return
        }
        text = cues.first(where: { currentTime >= $0.start && currentTime < $0.end })?.text
    }

    private static func loadCues(from url: URL) async -> [CJKSubtitleCue] {
        let task = Task.detached(priority: .userInitiated) { () -> [CJKSubtitleCue] in
            do {
                let data: Data
                if url.isFileURL { data = try Data(contentsOf: url) }
                else {
                    let (body, response) = try await URLSession.shared.data(from: url)
                    guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { return [] }
                    data = body
                }
                guard let value = decode(data) else { return [] }
                return parse(value)
            } catch { return [] }
        }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xFF, 0xFE]) {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        return String(data: data, encoding: .utf8)
    }

    private static func parse(_ value: String) -> [CJKSubtitleCue] {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n\n")
            .compactMap { block in
                let lines = block.components(separatedBy: "\n")
                guard let timeIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                    return nil
                }
                let times = lines[timeIndex].components(separatedBy: "-->")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard times.count == 2,
                      let start = timestamp(times[0]),
                      let end = timestamp(times[1]) else { return nil }
                let text = lines.dropFirst(timeIndex + 1)
                    .joined(separator: "\n")
                    .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\{\\[^}]+\}"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return CJKSubtitleCue(start: start, end: max(end, start), text: text)
            }
            .sorted { $0.start < $1.start }
    }

    private static func timestamp(_ value: String) -> Double? {
        let parts = value.replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else { return nil }
        return hours * 3_600 + minutes * 60 + seconds
    }
}

struct PlaybackSubtitleText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.9), radius: 1, x: 1, y: 1)
            .shadow(color: .black.opacity(0.7), radius: 1, x: -1, y: -1)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 720)
            .allowsHitTesting(false)
    }
}

private struct CJKSubtitleOverlay: View {
    @ObservedObject var model: CJKSubtitleOverlayModel
    var body: some View {
        if let text = model.text, !text.isEmpty { PlaybackSubtitleText(text: text) }
    }
}

#if canImport(MobileVLCKit)
private struct VLCBuiltInPlayerView: View {
    let request: MediaPlaybackRequest
    let close: () -> Void
    let useSystemPlayer: ((MediaPlaybackRuntimeState, Bool) -> Void)?
    let compatibilityFailed: (MediaPlaybackRuntimeState) -> Void
    let sourceTrackChange: ((Int?, Int?, MediaPlaybackRuntimeState) -> Void)?
    let serverSeek: ((Double, MediaPlaybackRuntimeState) -> Void)?
    let qualityChange: ((String, MediaPlaybackRuntimeState) -> Void)?
    let openExternal: () -> Void
    @StateObject private var session: VLCMediaPlayerSession

    init(request: MediaPlaybackRequest, close: @escaping () -> Void,
         useSystemPlayer: ((MediaPlaybackRuntimeState, Bool) -> Void)?,
         compatibilityFailed: @escaping (MediaPlaybackRuntimeState) -> Void,
         sourceTrackChange: ((Int?, Int?, MediaPlaybackRuntimeState) -> Void)?,
         serverSeek: ((Double, MediaPlaybackRuntimeState) -> Void)?,
         qualityChange: ((String, MediaPlaybackRuntimeState) -> Void)?,
         openExternal: @escaping () -> Void) {
        self.request = request; self.close = close; self.useSystemPlayer = useSystemPlayer
        self.compatibilityFailed = compatibilityFailed; self.sourceTrackChange = sourceTrackChange
        self.serverSeek = serverSeek; self.qualityChange = qualityChange; self.openExternal = openExternal
        _session = StateObject(wrappedValue: VLCMediaPlayerSession(request: request))
    }
    var body: some View {
        SharedBuiltInPlayerView(request: request, session: session, close: close,
            useSystemPlayer: useSystemPlayer, compatibilityFailed: compatibilityFailed,
            sourceTrackChange: sourceTrackChange, serverSeek: serverSeek,
            qualityChange: qualityChange, openExternal: openExternal) {
                VLCPlayerSurface(session: session)
            }
    }
}
extension VLCMediaPlayerSession: PlaybackUIEngineSession {}
#endif

@MainActor
protocol PlaybackUIEngineSession: ObservableObject {
    var isPlaying: Bool { get }
    var isMuted: Bool { get }
    var position: Double { get }
    var isSeekable: Bool { get }
    var errorMessage: String? { get }
    var subtitleTracks: [PlaybackUITrack] { get }
    var audioTracks: [PlaybackUITrack] { get }
    var selectedSubtitleTrackID: Int32 { get }
    var selectedAudioTrackID: Int32 { get }
    var isBuffering: Bool { get }
    var hasStartedPlayback: Bool { get }
    var currentTimeText: String { get }
    var currentTimeSeconds: Double { get }
    var durationText: String { get }
    var durationSeconds: Double { get }
    var playbackRate: Float { get }
    var initialLoadTimeoutNanoseconds: UInt64 { get }
    var usesSourceTrackSelectionForRuntimeState: Bool { get }
    var supportsPictureMode: Bool { get }
    var fillsScreen: Bool { get }
    func setFillsScreen(_ fills: Bool)
    func play()
    func stop()
    func togglePlayback()
    func toggleMute()
    func seek(to position: Double)
    func seek(toAbsoluteSeconds seconds: Double) -> Bool
    func jump(by seconds: Int)
    func setPlaybackRate(_ rate: Float)
    func selectAudio(_ track: PlaybackUITrack)
    func selectSubtitle(_ track: PlaybackUITrack)
    func selectExternalSubtitle(_ url: URL?) -> Bool
    func pauseForExternalHandoff()
    func runtimeState(orientationMode: PlayerOrientationMode) -> MediaPlaybackRuntimeState
    func failIfStillLoading()
    func initialLoadGraceNanosecondsIfNeeded() -> UInt64
    func recoverIfStalled()
}
extension PlaybackUIEngineSession {
    var usesSourceTrackSelectionForRuntimeState: Bool { false }
    var supportsPictureMode: Bool { false }
    var fillsScreen: Bool { false }
    func setFillsScreen(_ fills: Bool) {}
}

/// Finger movement is local to the timeline; it must not rebuild the video
/// surface, track menus and subtitle hierarchy for every slider value.
private struct PlaybackSeekBar<Session: PlaybackUIEngineSession>: View {
    @ObservedObject var session: Session
    let canSeek: Bool
    let commit: (Double) -> Void
    let editingChanged: () -> Void
    @State private var position = 0.0
    @State private var editing = false

    private var timeText: String {
        guard editing, session.durationSeconds.isFinite, session.durationSeconds > 0 else {
            return session.currentTimeText
        }
        let seconds = Int((session.durationSeconds * position).rounded(.down))
        return seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(timeText)
            Slider(value: $position, in: 0...1, onEditingChanged: { active in
                editing = active
                if !active { commit(position) }
                editingChanged()
            })
            .disabled(!canSeek)
            .tint(AppTheme.accent)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            Text(session.durationText)
        }
        .font(.caption.monospacedDigit())
        .onAppear { followClock(session.position) }
        .onChange(of: session.position) { followClock($0) }
    }

    private func followClock(_ value: Double) {
        guard !editing, value.isFinite else { return }
        position = min(max(value, 0), 1)
    }
}

struct SharedBuiltInPlayerView<Session: PlaybackUIEngineSession, Surface: View>: View {
    let request: MediaPlaybackRequest
    let close: () -> Void
    let useSystemPlayer: ((MediaPlaybackRuntimeState, Bool) -> Void)?
    let compatibilityFailed: (MediaPlaybackRuntimeState) -> Void
    let sourceTrackChange: ((Int?, Int?, MediaPlaybackRuntimeState) -> Void)?
    let serverSeek: ((Double, MediaPlaybackRuntimeState) -> Void)?
    let qualityChange: ((String, MediaPlaybackRuntimeState) -> Void)?
    let previousEpisode: (() -> Void)?
    let nextEpisode: (() -> Void)?
    let openExternal: () -> Void
    @ObservedObject private var session: Session
    private let surface: () -> Surface
    @State private var didInitializeSubtitleOverlay = false
    @State private var controlsVisible = true
    @State private var controlsLocked = false
    @State private var controlsRevision = 0
    @State private var gestureStartPosition: Double?
    @State private var gestureTargetPosition: Double?
    @State private var panMode: VLCPlayerPanMode?
    @State private var brightnessGestureStart: CGFloat?
    @State private var displayBrightness: CGFloat
    @State private var brightnessHUDVisible = false
    @State private var brightnessHUDRevision = 0
    @State private var activePanel: VLCPlayerPanel?
    @State private var orientationMode: PlayerOrientationMode
    @State private var selectedSourceAudioTrackID: Int?
    @State private var selectedSourceSubtitleTrackID: Int?
    @State private var showPiPUnavailableHint = false
    @StateObject private var subtitleOverlayModel: CJKSubtitleOverlayModel

    init(
        request: MediaPlaybackRequest,
        session: Session,
        close: @escaping () -> Void,
        useSystemPlayer: ((MediaPlaybackRuntimeState, Bool) -> Void)?,
        compatibilityFailed: @escaping (MediaPlaybackRuntimeState) -> Void,
        sourceTrackChange: ((Int?, Int?, MediaPlaybackRuntimeState) -> Void)?,
        serverSeek: ((Double, MediaPlaybackRuntimeState) -> Void)?,
        qualityChange: ((String, MediaPlaybackRuntimeState) -> Void)?,
        previousEpisode: (() -> Void)? = nil,
        nextEpisode: (() -> Void)? = nil,
        openExternal: @escaping () -> Void,
        @ViewBuilder surface: @escaping () -> Surface
    ) {
        self.previousEpisode = previousEpisode
        self.nextEpisode = nextEpisode
        self.request = request
        self.close = close
        self.useSystemPlayer = useSystemPlayer
        self.compatibilityFailed = compatibilityFailed
        self.sourceTrackChange = sourceTrackChange
        self.serverSeek = serverSeek
        self.qualityChange = qualityChange
        self.openExternal = openExternal
        _session = ObservedObject(wrappedValue: session)
        self.surface = surface
        _orientationMode = State(initialValue: request.initialOrientationMode)
        _displayBrightness = State(initialValue: UIScreen.main.brightness)
        _selectedSourceAudioTrackID = State(initialValue: request.selectedSourceAudioTrackID)
        _selectedSourceSubtitleTrackID = State(
            initialValue: request.selectedSourceSubtitleTrackID
        )
        _subtitleOverlayModel = StateObject(
            wrappedValue: CJKSubtitleOverlayModel()
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let landscapeLayout = proxy.size.width > proxy.size.height

            ZStack {
                surface()
                    .ignoresSafeArea()

                if subtitleOverlayModel.isEnabled {
                    VStack {
                        Spacer()
                        CJKSubtitleOverlay(model: subtitleOverlayModel)
                            .padding(.horizontal, 24)
                            .padding(.bottom, landscapeLayout ? 36 : 54)
                    }
                }

                Rectangle()
                    .fill(Color.black.opacity(0.001))
                    .contentShape(Rectangle())
                    .accessibilityElement()
                    .accessibilityLabel(Text("player.controls.toggle"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        toggleControls()
                    }
                    .onTapGesture(count: 2) {
                        session.togglePlayback()
                        revealControls()
                    }
                    .onTapGesture { toggleControls() }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 18)
                            .onChanged { value in
                                updatePlayerGesture(value, playerSize: proxy.size)
                            }
                            .onEnded { _ in
                                finishPlayerGesture()
                            }
                    )
                    .allowsHitTesting(!controlsLocked)

                if brightnessHUDVisible {
                    VStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .font(.title2)
                        Text("\(Int((displayBrightness * 100).rounded()))%")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 82)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }

                if controlsLocked {
                    HStack {
                        playerChromeButton(
                            systemImage: "lock.fill",
                            accessibilityKey: "player.controls.unlock"
                        ) {
                            controlsLocked = false
                            recordControlsLockChange(locked: false)
                            revealControls()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .transition(.opacity)
                }

                if controlsVisible && !controlsLocked {
                    VStack(spacing: 0) {
                        topControls
                        Spacer()
                        playbackControls(isLandscape: landscapeLayout)
                    }
                    .transition(.opacity)
                }

                if let errorMessage = session.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                        Text("player.load_failed")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        if request.allowsExternalHandoff {
                            Button {
                                session.pauseForExternalHandoff()
                                openExternal()
                            } label: {
                                Label("devices.files.open_external", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                        } else if let useSystemPlayer {
                            Button {
                                useSystemPlayer(
                                    runtimeStateForSourceChange(),
                                    false
                                )
                            } label: {
                                Label("player.engine.system", systemImage: "play.rectangle")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                        } else {
                            Text(LocalizedStringKey(request.source == .jellyfin
                                ? "jellyfin.player.retry_hint"
                                : "dsm.player.retry_hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("action.done", action: close)
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accent)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(22)
                } else if session.isBuffering && !session.hasStartedPlayback {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }

                if let activePanel, session.errorMessage == nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            playerPanel(activePanel, isLandscape: landscapeLayout)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, landscapeLayout ? 56 : 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

            }
        }
        .onAppear {
            displayBrightness = UIScreen.main.brightness
            if !didInitializeSubtitleOverlay {
                didInitializeSubtitleOverlay = true
                subtitleOverlayModel.setURL(request.prefersSubtitlesDisabled ? nil : request.externalSubtitleURL)
            }
            session.play()
            revealControls()
        }
        .onDisappear {
            session.stop()
        }
        .onChange(of: session.currentTimeSeconds) { seconds in
            subtitleOverlayModel.update(time: seconds)
        }
        .onChange(of: request.externalSubtitleURL) { url in
            subtitleOverlayModel.setURL(url)
            subtitleOverlayModel.update(time: session.currentTimeSeconds)
        }
        .onChange(of: session.isPlaying) { isPlaying in
            if isPlaying {
                revealControls()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    controlsVisible = true
                }
            }
        }
        .onChange(of: session.errorMessage) { errorMessage in
            if errorMessage != nil {
                compatibilityFailed(runtimeStateForSourceChange())
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: session.initialLoadTimeoutNanoseconds)
            guard !Task.isCancelled else { return }
            let grace = session.initialLoadGraceNanosecondsIfNeeded()
            if grace > 0 {
                try? await Task.sleep(nanoseconds: grace)
                guard !Task.isCancelled else { return }
            }
            session.failIfStillLoading()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                session.recoverIfStalled()
            }
        }
        .task(id: controlsRevision) {
            guard controlsVisible, session.isPlaying, activePanel == nil else { return }
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled, session.isPlaying, activePanel == nil else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                controlsVisible = false
            }
        }
        .task(id: brightnessHUDRevision) {
            guard brightnessHUDVisible, panMode == nil else { return }
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled, panMode == nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                brightnessHUDVisible = false
            }
        }
        .alert("player.picture_in_picture", isPresented: $showPiPUnavailableHint) {
            Button("action.done", role: .cancel) {}
        } message: {
            Text("player.picture_in_picture_unavailable")
        }
    }

    private var topControls: some View {
        HStack(spacing: 12) {
            playerChromeButton(
                systemImage: "xmark",
                accessibilityKey: "action.done",
                action: close
            )

            Text(request.title.isEmpty ? NSLocalizedString("player.title", comment: "") : request.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            playerChromeButton(
                systemImage: session.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                accessibilityKey: session.isMuted ? "player.unmute" : "player.mute"
            ) {
                session.toggleMute()
                revealControls()
            }

            playerChromeButton(
                systemImage: "lock.open",
                accessibilityKey: "player.controls.lock"
            ) {
                activePanel = nil
                controlsLocked = true
                controlsVisible = false
                recordControlsLockChange(locked: true)
            }

            Button {
                presentPanel(.settings)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.46), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("player.more_controls"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.76), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private func playbackControls(isLandscape: Bool) -> some View {
        VStack(spacing: isLandscape ? 6 : 10) {
            PlaybackSeekBar(session: session, canSeek: canSeek,
                commit: commitSeek, editingChanged: { revealControls() })

            HStack(spacing: isLandscape ? 24 : 8) {
                controlButton(
                    systemImage: request.episodeNavigationLoader != nil ? "backward.end.fill" : "gobackward.15",
                    accessibilityKey: request.episodeNavigationLoader != nil ? "player.episode.previous" : "player.seek_backward"
                ) {
                    if request.episodeNavigationLoader != nil { previousEpisode?() }
                    else { jump(by: -15) }
                    revealControls()
                }
                .disabled(request.episodeNavigationLoader != nil && previousEpisode == nil)
                .opacity(request.episodeNavigationLoader != nil && previousEpisode == nil ? 0.35 : 1)

                controlButton(
                    systemImage: session.isPlaying ? "pause.fill" : "play.fill",
                    accessibilityKey: session.isPlaying ? "player.pause" : "player.play",
                    emphasized: true
                ) {
                    session.togglePlayback()
                    revealControls()
                }

                controlButton(
                    systemImage: request.episodeNavigationLoader != nil ? "forward.end.fill" : "goforward.15",
                    accessibilityKey: request.episodeNavigationLoader != nil ? "player.episode.next" : "player.seek_forward"
                ) {
                    if request.episodeNavigationLoader != nil { nextEpisode?() }
                    else { jump(by: 15) }
                    revealControls()
                }
                .disabled(request.episodeNavigationLoader != nil && nextEpisode == nil)
                .opacity(request.episodeNavigationLoader != nil && nextEpisode == nil ? 0.35 : 1)

                Spacer(minLength: 4)

                Button {
                    presentPanel(.audio)
                } label: {
                    Image(systemName: "waveform")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(availableAudioTrackCount <= 1)
                .accessibilityLabel(Text("player.audio_tracks"))

                Button {
                    presentPanel(.subtitles)
                } label: {
                    Image(systemName: hasSelectedSubtitle ? "captions.bubble.fill" : "captions.bubble")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(availableSubtitleTrackCount == 0)
                .accessibilityLabel(Text("player.subtitles"))

                if qualityChange != nil, !request.qualityOptions.isEmpty {
                    Button {
                        presentPanel(.quality)
                    } label: {
                        Image(systemName: "4k.tv")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("player.quality"))
                }

                if showsPictureInPictureControl {
                    Button {
                        if let useSystemPlayer {
                            useSystemPlayer(
                                runtimeStateForSourceChange(),
                                true
                            )
                        } else {
                            showPiPUnavailableHint = true
                        }
                    } label: {
                        Image(systemName: "pip.enter")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(useSystemPlayer == nil ? .white.opacity(0.45) : .white)
                    .accessibilityLabel(Text("player.picture_in_picture"))
                }

                controlButton(
                    systemImage: isLandscape
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right",
                    accessibilityKey: isLandscape ? "player.exit_fullscreen" : "player.fullscreen"
                ) {
                    let mode: PlayerOrientationMode = isLandscape ? .portrait : .landscape
                    orientationMode = mode
                    PlayerOrientationController.applyPlayerOrientationMode(mode)
                    revealControls()
                }
            }
            .font(.title3)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, isLandscape ? 28 : 18)
        .padding(.top, isLandscape ? 24 : 34)
        .padding(.bottom, isLandscape ? 8 : 14)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func playerPanel(
        _ panel: VLCPlayerPanel,
        isLandscape: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: panelSystemImage(panel))
                    .foregroundStyle(.secondary)
                Text(panelTitle(panel))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    dismissPanel()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("action.cancel"))
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(height: 48)

            Divider()

            panelContent(panel)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: isLandscape ? 360 : 420)
        .frame(maxHeight: isLandscape ? 270 : 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func panelContent(_ panel: VLCPlayerPanel) -> some View {
        switch panel {
        case .settings:
            settingsPanel
        case .audio:
            if let sourceTrackChange {
                trackList(
                    tracks: request.sourceAudioTracks.map {
                        VLCPlayerTrackOption(id: Int32(clamping: $0.id), name: $0.name)
                    },
                    selectedID: Int32(clamping: selectedSourceAudioTrackID ?? -1)
                ) { id in
                    selectedSourceAudioTrackID = Int(id)
                    sourceTrackChange(
                        Int(id),
                        selectedSourceSubtitleTrackID,
                        runtimeStateForSourceChange()
                    )
                    dismissPanel()
                }
            } else {
                trackList(
                    tracks: session.audioTracks.map {
                        VLCPlayerTrackOption(id: $0.id, name: $0.name)
                    },
                    selectedID: session.selectedAudioTrackID
                ) { id in
                    guard let track = session.audioTracks.first(where: { $0.id == id }) else { return }
                    session.selectAudio(track)
                    dismissPanel()
                }
            }
        case .subtitles:
            if let sourceTrackChange {
                trackList(
                    tracks: [VLCPlayerTrackOption(
                        id: -1,
                        name: NSLocalizedString("player.subtitles.off", comment: "")
                    )] + request.sourceSubtitleTracks.map {
                        VLCPlayerTrackOption(id: Int32(clamping: $0.id), name: $0.name)
                    },
                    selectedID: Int32(clamping: selectedSourceSubtitleTrackID ?? -1)
                ) { id in
                    let sourceID = id < 0 ? nil : Int(id)
                    let sourceTrack = sourceID.flatMap { selectedID in
                        request.sourceSubtitleTracks.first { $0.id == selectedID }
                    }
                    selectedSourceSubtitleTrackID = sourceID
                    subtitleOverlayModel.setURL(sourceTrack?.externalURL)
                    if sourceTrack?.externalURL == nil {
                        sourceTrackChange(
                            selectedSourceAudioTrackID,
                            sourceID,
                            runtimeStateForSourceChange()
                        )
                    } else {
                        // Text subtitles are already normalized to a local
                        // UTF-8 sidecar and rendered by the common overlay.
                        // Keep the video HLS session and its absolute clock;
                        // only image/burn-in tracks need server renegotiation.
                        _ = session.selectExternalSubtitle(sourceTrack?.externalURL)
                    }
                    dismissPanel()
                }
            } else {
                trackList(
                    tracks: session.subtitleTracks.map {
                        VLCPlayerTrackOption(id: $0.id, name: $0.name)
                    },
                    selectedID: session.selectedSubtitleTrackID
                ) { id in
                    guard let track = session.subtitleTracks.first(where: { $0.id == id }) else { return }
                    session.selectSubtitle(track)
                    dismissPanel()
                }
            }
        case .quality:
            qualityList
        }
    }

    private func runtimeStateForSourceChange() -> MediaPlaybackRuntimeState {
        let state = session.runtimeState(orientationMode: orientationMode)
        guard session.usesSourceTrackSelectionForRuntimeState, sourceTrackChange != nil else { return state }
        // The source menu includes sidecars and server-burned subtitles that
        // never appear in AVPlayer's legible group. Preserve the user's current
        // source selection when a Greenfield request is rebuilt.
        return MediaPlaybackRuntimeState(
            normalizedPosition: state.normalizedPosition,
            positionSeconds: state.positionSeconds,
            playbackRate: state.playbackRate,
            audioTrackOrdinal: request.sourceAudioTracks.firstIndex { $0.id == selectedSourceAudioTrackID },
            subtitleTrackOrdinal: request.sourceSubtitleTracks.firstIndex { $0.id == selectedSourceSubtitleTrackID },
            subtitlesDisabled: selectedSourceSubtitleTrackID == nil,
            subtitleSelectionKnown: true,
            orientationMode: state.orientationMode
        )
    }

    private var qualityList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(request.qualityOptions) { option in
                    Button {
                        qualityChange?(
                            option.id,
                            runtimeStateForSourceChange()
                        )
                        dismissPanel()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: request.selectedQualityID == option.id
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .foregroundStyle(request.selectedQualityID == option.id
                                                 ? AppTheme.accent
                                                 : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.subheadline)
                                if let detail = option.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if option.id != request.qualityOptions.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
    }

    private var availableAudioTrackCount: Int {
        sourceTrackChange == nil ? session.audioTracks.count : request.sourceAudioTracks.count
    }

    private var showsPictureInPictureControl: Bool {
        useSystemPlayer != nil
    }

    private func recordControlsLockChange(locked: Bool) {
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.controls_lock_changed",
            details: ["locked": locked ? "yes" : "no"]
        )
    }

    private var availableSubtitleTrackCount: Int {
        sourceTrackChange == nil
            ? max(session.subtitleTracks.count - 1, 0)
            : request.sourceSubtitleTracks.count
    }

    private var hasSelectedSubtitle: Bool {
        sourceTrackChange == nil
            ? session.selectedSubtitleTrackID >= 0
            : selectedSourceSubtitleTrackID != nil
    }

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("player.speed")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(playbackRates, id: \.self) { rate in
                            Button(playbackRateLabel(rate)) {
                                session.setPlaybackRate(rate)
                                revealControls()
                            }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(
                                abs(session.playbackRate - rate) < 0.01
                                    ? AppTheme.accent
                                    : Color.white.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                        }
                    }
                }

                if session.supportsPictureMode {
                    Picker("player.picture_mode", selection: Binding(
                        get: { session.fillsScreen }, set: { session.setFillsScreen($0) }
                    )) {
                        Text("player.picture_fit").tag(false)
                        Text("player.picture_fill").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Text("player.picture_fill_hint").font(.caption).foregroundStyle(.secondary)
                }

                Text("player.orientation")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 0) {
                    ForEach(PlayerOrientationMode.allCases) { mode in
                        Button {
                            orientationMode = mode
                            PlayerOrientationController.applyPlayerOrientationMode(mode)
                            DiagnosticLogStore.shared.record(
                                .info,
                                categoryKey: "diagnostics.category.media",
                                messageKey: "diagnostics.media.orientation_changed",
                                details: ["mode": mode.rawValue]
                            )
                            revealControls()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: mode.systemImage)
                                Text(mode.localizationKey)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                orientationMode == mode
                                    ? Color.white.opacity(0.18)
                                    : Color.clear
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                if showsPictureInPictureControl || request.allowsExternalHandoff {
                    Divider()
                }

                if showsPictureInPictureControl {
                    panelCommand(
                        titleKey: "player.picture_in_picture",
                        systemImage: "pip.enter"
                    ) {
                        dismissPanel()
                        if let useSystemPlayer {
                            useSystemPlayer(
                                runtimeStateForSourceChange(),
                                true
                            )
                        } else {
                            showPiPUnavailableHint = true
                        }
                    }
                }

                if request.allowsExternalHandoff {
                    panelCommand(
                        titleKey: "devices.files.open_external",
                        systemImage: "arrow.up.forward.app"
                    ) {
                        dismissPanel()
                        session.pauseForExternalHandoff()
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            openExternal()
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func trackList(
        tracks: [VLCPlayerTrackOption],
        selectedID: Int32,
        select: @escaping (Int32) -> Void
    ) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(tracks, id: \.id) { track in
                    Button {
                        select(track.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedID == track.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedID == track.id ? AppTheme.accent : .secondary)
                            Text(track.name)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if track.id != tracks.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
    }

    private func panelCommand(
        titleKey: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(titleKey, systemImage: systemImage)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func panelTitle(_ panel: VLCPlayerPanel) -> LocalizedStringKey {
        switch panel {
        case .settings: return "player.more_controls"
        case .audio: return "player.audio_tracks"
        case .subtitles: return "player.subtitles"
        case .quality: return "player.quality"
        }
    }

    private func panelSystemImage(_ panel: VLCPlayerPanel) -> String {
        switch panel {
        case .settings: return "gearshape"
        case .audio: return "waveform"
        case .subtitles: return "captions.bubble"
        case .quality: return "4k.tv"
        }
    }

    private func controlButton(
        systemImage: String,
        accessibilityKey: String,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(emphasized ? .title2 : .title3)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityKey)))
    }

    private func playerChromeButton(
        systemImage: String,
        accessibilityKey: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.46), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityKey)))
    }

    private func toggleControls() {
        if activePanel != nil {
            dismissPanel()
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible.toggle()
        }
        if controlsVisible {
            controlsRevision += 1
        }
    }

    private func presentPanel(_ panel: VLCPlayerPanel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible = true
            activePanel = activePanel == panel ? nil : panel
        }
        controlsRevision += 1
    }

    private func dismissPanel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            activePanel = nil
            controlsVisible = true
        }
        controlsRevision += 1
    }

    private var playbackRates: [Float] {
        [0.5, 0.75, 1, 1.25, 1.5, 2]
    }

    private func playbackRateLabel(_ rate: Float) -> String {
        switch rate {
        case 0.5: return "0.5x"
        case 0.75: return "0.75x"
        case 1: return "1x"
        case 1.25: return "1.25x"
        case 1.5: return "1.5x"
        case 2: return "2x"
        default: return "\(rate)x"
        }
    }

    private func updatePlayerGesture(_ value: DragGesture.Value, playerSize: CGSize) {
        guard activePanel == nil, session.errorMessage == nil else { return }
        if panMode == nil {
            let horizontalDistance = abs(value.translation.width)
            let verticalDistance = abs(value.translation.height)
            if horizontalDistance > verticalDistance * 1.2 {
                panMode = .seeking
            } else if verticalDistance > horizontalDistance * 1.2 {
                panMode = .brightness
                brightnessGestureStart = UIScreen.main.brightness
                displayBrightness = UIScreen.main.brightness
                withAnimation(.easeInOut(duration: 0.15)) {
                    brightnessHUDVisible = true
                }
            } else {
                return
            }
        }

        switch panMode {
        case .seeking:
            updateSeekGesture(value, playerWidth: playerSize.width)
        case .brightness:
            updateBrightnessGesture(value, playerHeight: playerSize.height)
        case nil:
            break
        }
    }

    private func finishPlayerGesture() {
        let completedMode = panMode
        panMode = nil
        switch completedMode {
        case .seeking:
            finishSeekGesture()
        case .brightness:
            brightnessGestureStart = nil
            brightnessHUDRevision += 1
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.brightness_changed",
                details: [
                    "percent": "\(Int((displayBrightness * 100).rounded()))"
                ]
            )
        case nil:
            break
        }
    }

    private func updateSeekGesture(_ value: DragGesture.Value, playerWidth: CGFloat) {
        guard
            canSeek,
            session.durationSeconds > 0,
            playerWidth > 0
        else {
            return
        }
        let startPosition = gestureStartPosition ?? session.position
        gestureStartPosition = startPosition
        let secondsPerPoint = min(max(session.durationSeconds / 7_200, 0.35), 1.2)
        let rawOffset = Double(value.translation.width) * secondsPerPoint
        let boundedOffset = min(max(rawOffset, -300), 300)
        let targetPosition = min(
            max(startPosition + boundedOffset / session.durationSeconds, 0),
            1
        )
        gestureTargetPosition = targetPosition
        controlsVisible = true
        controlsRevision += 1
    }

    private func finishSeekGesture() {
        defer { gestureStartPosition = nil }
        guard let targetPosition = gestureTargetPosition else { return }
        commitSeek(to: targetPosition)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        revealControls()
        gestureTargetPosition = nil
    }

    private static func formatPlayerTime(_ seconds: Double) -> String {
        let totalSeconds = max(Int(seconds.rounded(.down)), 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let remainder = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    private var canSeek: Bool {
        session.isSeekable || (serverSeek != nil && session.durationSeconds > 0)
    }

    private func commitSeek(to normalizedPosition: Double) {
        let position = min(max(normalizedPosition, 0), 1)
        let targetSeconds = session.durationSeconds * position
        if serverSeek != nil, session.seek(toAbsoluteSeconds: targetSeconds) {
            return
        }
        guard let serverSeek else {
            session.seek(to: position)
            return
        }
        serverSeek(
            targetSeconds,
            runtimeStateForSourceChange()
        )
    }

    private func jump(by seconds: Int) {
        let targetSeconds = min(
            max(session.currentTimeSeconds + Double(seconds), 0),
            session.durationSeconds
        )
        if serverSeek != nil, session.seek(toAbsoluteSeconds: targetSeconds) {
            return
        }
        guard let serverSeek else {
            session.jump(by: seconds)
            return
        }
        serverSeek(
            targetSeconds,
            runtimeStateForSourceChange()
        )
    }

    private func updateBrightnessGesture(_ value: DragGesture.Value, playerHeight: CGFloat) {
        guard playerHeight > 0 else { return }
        let startBrightness = brightnessGestureStart ?? UIScreen.main.brightness
        brightnessGestureStart = startBrightness
        let dragRange = max(playerHeight * 0.7, 180)
        let targetBrightness = min(
            max(startBrightness - value.translation.height / dragRange, 0),
            1
        )
        displayBrightness = targetBrightness
        UIScreen.main.brightness = targetBrightness
        brightnessHUDVisible = true
        brightnessHUDRevision += 1
    }

    private func revealControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible = true
        }
        controlsRevision += 1
    }
}

#if canImport(MobileVLCKit)
private struct VLCPlayerSurface: UIViewRepresentable {
    let session: VLCMediaPlayerSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        session.attach(to: view)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        session.attach(to: view)
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.session?.detach(from: view)
    }

    final class Coordinator {
        weak var session: VLCMediaPlayerSession?

        init(session: VLCMediaPlayerSession) {
            self.session = session
        }
    }
}
#endif

private struct SystemPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer
    let startPictureInPicture: Bool
    let onSeekCommitted: () -> Void
    let onPictureInPictureEvent: (String, Error?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.videoGravity = .resizeAspect
        context.coordinator.installGesture(on: controller)
        context.coordinator.installPictureInPicture(on: controller)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.parent = self
        if controller.player !== player {
            controller.player = player
        }
        // The representable can be created before AVPlayerViewController has
        // its final bounds.  A zero-sized auxiliary layer is still eligible
        // for PiP, so AVPictureInPictureController may report success while
        // capturing a black frame. Keep the PiP source layer in sync with the
        // actual controller bounds on every SwiftUI update.
        controller.view.layoutIfNeeded()
        context.coordinator.updatePictureInPictureLayerFrame(
            controller.view.bounds,
            player: player
        )
        context.coordinator.updatePictureInPictureRequest(startPictureInPicture)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate, AVPictureInPictureControllerDelegate {
        var parent: SystemPlayerController
        private weak var controller: AVPlayerViewController?
        private var gestureStartSeconds: Double?
        private var gestureTargetSeconds: Double?
        private var wasPlaying = false
        private var pictureInPictureController: AVPictureInPictureController?
        private var pictureInPictureLayer: AVPlayerLayer?
        private var pictureInPictureStartWorkItem: DispatchWorkItem?
        private var pictureInPictureStartRequested = false

        init(parent: SystemPlayerController) {
            self.parent = parent
        }

        func installGesture(on controller: AVPlayerViewController) {
            self.controller = controller
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            gesture.maximumNumberOfTouches = 1
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            controller.view.addGestureRecognizer(gesture)
        }

        func installPictureInPicture(on controller: AVPlayerViewController) {
            let layer = AVPlayerLayer(player: parent.player)
            layer.videoGravity = .resizeAspect
            // Keep this as a real rendered layer. A transparent auxiliary
            // layer can make AVPictureInPictureController report a successful
            // transition while capturing a black frame on iPadOS.
            layer.opacity = 1
            layer.frame = controller.view.bounds
            controller.view.layer.insertSublayer(layer, at: 0)
            pictureInPictureLayer = layer

            guard AVPictureInPictureController.isPictureInPictureSupported() else {
                parent.onPictureInPictureEvent("unavailable", nil)
                return
            }
            guard let pictureInPictureController = AVPictureInPictureController(playerLayer: layer) else {
                parent.onPictureInPictureEvent("unavailable", nil)
                return
            }
            pictureInPictureController.delegate = self
            self.pictureInPictureController = pictureInPictureController
            updatePictureInPictureRequest(parent.startPictureInPicture)
        }

        func updatePictureInPictureLayerFrame(_ frame: CGRect, player: AVPlayer) {
            pictureInPictureLayer?.player = player
            guard frame.width > 0, frame.height > 0 else { return }
            pictureInPictureLayer?.frame = frame
        }

        func updatePictureInPictureRequest(_ requested: Bool) {
            guard requested else { return }
            guard let pictureInPictureController,
                  !pictureInPictureController.isPictureInPictureActive,
                  !pictureInPictureStartRequested else {
                return
            }
            pictureInPictureStartRequested = true
            attemptPictureInPictureStart(controller: pictureInPictureController, remainingAttempts: 40)
        }

        private func attemptPictureInPictureStart(
            controller: AVPictureInPictureController,
            remainingAttempts: Int
        ) {
            guard remainingAttempts > 0,
                  !controller.isPictureInPictureActive else {
                pictureInPictureStartRequested = false
                if !controller.isPictureInPictureActive {
                    parent.onPictureInPictureEvent("unavailable", nil)
                }
                return
            }
            let ready = parent.player.currentItem?.status == .readyToPlay
                && (parent.player.currentItem?.presentationSize.width ?? 0) > 0
                && (parent.player.currentItem?.presentationSize.height ?? 0) > 0
                && pictureInPictureLayer?.isReadyForDisplay == true
                && (pictureInPictureLayer?.bounds.width ?? 0) > 0
                && (pictureInPictureLayer?.bounds.height ?? 0) > 0
            if ready, controller.isPictureInPicturePossible {
                parent.onPictureInPictureEvent("willStart", nil)
                controller.startPictureInPicture()
                return
            }
            pictureInPictureStartWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak controller] in
                guard let self, let controller else { return }
                self.attemptPictureInPictureStart(
                    controller: controller,
                    remainingAttempts: remainingAttempts - 1
                )
            }
            pictureInPictureStartWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard
                let pan = gestureRecognizer as? UIPanGestureRecognizer,
                let view = pan.view,
                playbackDuration > 0
            else {
                return false
            }
            let velocity = pan.velocity(in: view)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var view = touch.view
            while let currentView = view, currentView !== controller?.view {
                if currentView is UIControl { return false }
                view = currentView.superview
            }
            return true
        }

        @objc
        private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let duration = playbackDuration
            guard duration > 0 else { return }

            switch gesture.state {
            case .began:
                let currentSeconds = parent.player.currentTime().seconds
                gestureStartSeconds = currentSeconds.isFinite ? max(currentSeconds, 0) : 0
                gestureTargetSeconds = gestureStartSeconds
                wasPlaying = parent.player.timeControlStatus == .playing
            case .changed:
                guard let startSeconds = gestureStartSeconds else { return }
                let translation = gesture.translation(in: view)
                guard abs(translation.x) > abs(translation.y) * 1.2 else { return }
                let secondsPerPoint = min(max(duration / 7_200, 0.35), 1.2)
                let offset = min(max(Double(translation.x) * secondsPerPoint, -300), 300)
                let target = min(max(startSeconds + offset, 0), duration)
                gestureTargetSeconds = target
            case .ended:
                commitSeek()
            case .cancelled, .failed:
                gestureStartSeconds = nil
                gestureTargetSeconds = nil
            default:
                break
            }
        }

        private func commitSeek() {
            defer {
                gestureStartSeconds = nil
                gestureTargetSeconds = nil
            }
            guard
                let startSeconds = gestureStartSeconds,
                let targetSeconds = gestureTargetSeconds,
                abs(targetSeconds - startSeconds) >= 0.5
            else {
                return
            }
            let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
            parent.player.seek(
                to: targetTime,
                toleranceBefore: CMTime(seconds: 0.25, preferredTimescale: 600),
                toleranceAfter: CMTime(seconds: 0.25, preferredTimescale: 600)
            ) { [weak self] _ in
                guard let self, self.wasPlaying else { return }
                self.parent.player.play()
            }
            parent.onSeekCommitted()
        }

        private var playbackDuration: Double {
            guard let item = parent.player.currentItem else { return 0 }
            let seconds = item.duration.seconds
            guard seconds.isFinite, seconds > 0 else { return 0 }
            return seconds
        }

        func pictureInPictureControllerWillStartPictureInPicture(
            _ pictureInPictureController: AVPictureInPictureController
        ) {
            parent.onPictureInPictureEvent("willStart", nil)
        }

        func pictureInPictureControllerDidStartPictureInPicture(
            _ pictureInPictureController: AVPictureInPictureController
        ) {
            pictureInPictureStartRequested = false
            parent.onPictureInPictureEvent("didStart", nil)
        }

        func pictureInPictureController(
            _ pictureInPictureController: AVPictureInPictureController,
            failedToStartPictureInPictureWithError error: Error
        ) {
            pictureInPictureStartRequested = false
            parent.onPictureInPictureEvent("failed", error)
        }

        func pictureInPictureControllerWillStopPictureInPicture(
            _ pictureInPictureController: AVPictureInPictureController
        ) {
            parent.onPictureInPictureEvent("willStop", nil)
        }

        func pictureInPictureControllerDidStopPictureInPicture(
            _ pictureInPictureController: AVPictureInPictureController
        ) {
            pictureInPictureStartRequested = false
            parent.onPictureInPictureEvent("didStop", nil)
        }

        func pictureInPictureController(
            _ pictureInPictureController: AVPictureInPictureController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            parent.onPictureInPictureEvent("restore", nil)
            completionHandler(true)
        }
    }
}

private enum JellyfinEntryKind: String {
    case library
    case movie
    case series
    case episode
    case audio
    case video
    case unknown
}

private struct JellyfinMediaTrack: Identifiable, Hashable {
    let index: Int
    let title: String
    let codec: String?
    let profile: String?
    let audioSpatialFormat: String?
    let isDefault: Bool
    let isForced: Bool

    var id: Int { index }
}

private struct JellyfinPlaybackSelection: Equatable {
    let audioStreamIndex: Int?
    let subtitleStreamIndex: Int?
}

private struct JellyfinPreparedPlayback {
    let resource: MediaPlaybackResource
    let externalHandoffResource: MediaPlaybackResource
    let playSessionID: String?
    let mediaSourceID: String?
    let playMethod: PlayMethod
    let mode: String
    let isPrivateNetworkRoute: Bool
    let allowsSelfSignedCertificates: Bool
    let playbackTraceID: String?
}

private struct JellyfinDirectPlaybackRoute {
    let url: URL
    let handoffURL: URL
    let source: String
    let allowsSelfSignedCertificates: Bool
    let isPrivateNetworkRoute: Bool
}

private struct JellyfinPlaybackBitrateDecision {
    let maximumBitrate: Int
    let directPlayMaximumBitrate: Int
    let isPrivateRoute: Bool
    let basis: String
    let networkKey: String
}

private struct JellyfinPersonEntry: Identifiable, Hashable {
    let id: String
    let imageItemID: String?
    let name: String
    let role: String?
    let type: String?
    let imageTag: String?
}

private struct JellyfinExternalLink: Identifiable, Hashable {
    let name: String
    let url: URL

    var id: String { url.absoluteString }
}

private struct JellyfinMediaEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let overview: String
    let kind: JellyfinEntryKind
    let collectionType: String?
    let imageItemID: String
    let imageTag: String?
    let thumbImageTag: String?
    let backdropImageTag: String?
    let container: String?
    let mediaSourceID: String?
    let defaultAudioStreamIndex: Int?
    let preferredSubtitleStreamIndex: Int?
    let preferredSubtitleCodec: String?
    let audioTracks: [JellyfinMediaTrack]
    let subtitleTracks: [JellyfinMediaTrack]
    var progress: Double?
    var playbackPositionTicks: Int?
    let runTimeTicks: Int?
    let seriesID: String?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let isFavorite: Bool
    let genres: [String]
    let communityRating: Double?
    let officialRating: String?
    let videoDescription: String?
    let audioDescription: String?
    let originalTitle: String?
    let tagline: String?
    let productionYear: Int?
    let premiereDate: Date?
    let people: [JellyfinPersonEntry]
    let studios: [String]
    let externalLinks: [JellyfinExternalLink]
    let mediaPath: String?
    let mediaSize: Int?
    let mediaBitrate: Int?
    let dolbyVideo: PlaybackDolbySourceInfo

    var isPlayable: Bool {
        [.movie, .episode, .audio, .video].contains(kind)
    }

    /// Jellyfin normally returns both playedPercentage and playbackPositionTicks,
    /// but older sessions can contain only one of them. Keep resume behavior
    /// deterministic for both the direct and server-HLS routes.
    var effectivePlaybackProgress: Double? {
        if let progress, progress > 0 {
            return min(max(progress, 0), 1)
        }
        if let positionTicks = playbackPositionTicks,
              let runTimeTicks,
              runTimeTicks > 0,
              positionTicks > 0 {
            return min(max(Double(positionTicks) / Double(runTimeTicks), 0), 1)
        }
        return progress.map { min(max($0, 0), 1) }
    }

    var effectivePlaybackPositionTicks: Int? {
        if let playbackPositionTicks, playbackPositionTicks > 0 {
            return playbackPositionTicks
        }
        guard let effectivePlaybackProgress,
              let runTimeTicks,
              runTimeTicks > 0 else {
            return playbackPositionTicks
        }
        return Int((Double(runTimeTicks) * effectivePlaybackProgress).rounded())
    }
}

private final class JellyfinCertificateTrustDelegate: NSObject, URLSessionDelegate {
    let trustedHost: String?
    let allowsSelfSignedCertificates: Bool

    init(trustedHost: String?, allowsSelfSignedCertificates: Bool) {
        self.trustedHost = trustedHost
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trustedHost,
           challenge.protectionSpace.host.caseInsensitiveCompare(trustedHost) != .orderedSame {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard
            allowsSelfSignedCertificates,
            let credential = CertificatePinStore.shared.credential(
                for: challenge,
                expectedHost: trustedHost
            )
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }
}

/// Jellyfin can expose an ASS/SSA subtitle as an SRT endpoint, but the
/// returned bytes may still carry legacy Chinese encoding or styling that
/// MobileVLCKit renders as tofu on iOS.  Normalize only the problematic text
/// codecs to a local UTF-8 SRT; image subtitles and ordinary SRT tracks keep
/// their original path.
private enum JellyfinSubtitleNormalizer {
    private static let maximumSubtitleBytes = 16 * 1024 * 1024

    static func normalize(
        url: URL,
        sourceCodec: String?,
        allowsSelfSignedCertificates: Bool
    ) async -> URL? {
        let codec = sourceCodec?.lowercased()
        guard codec == "ass" || codec == "ssa" else { return nil }

        let delegate = JellyfinCertificateTrustDelegate(
            trustedHost: url.host,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        let session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: url)
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  data.count <= maximumSubtitleBytes,
                  let decoded = decode(data),
                  let normalized = normalizeToSRT(decoded),
                  !normalized.isEmpty else {
                return nil
            }
            let cacheDirectory = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("Nastart/Subtitles", isDirectory: true)
            try FileManager.default.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true
            )
            let outputURL = cacheDirectory.appendingPathComponent(
                "\(UUID().uuidString).jellyfin.utf8.srt"
            )
            guard let outputData = normalized.data(using: .utf8) else { return nil }
            try outputData.write(to: outputURL, options: .atomic)
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.subtitle_normalized",
                details: [
                    "source": DiagnosticLogStore.redactedURL(url),
                    "sourceCodec": codec ?? "-",
                    "encoding": detectedEncoding(data),
                    "bytes": "\(data.count)",
                    "format": "utf8-srt",
                    "convertedASS": decoded.lowercased().contains("[events]") ? "yes" : "no"
                ]
            )
            return outputURL
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    private static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xFF, 0xFE]) {
            return String(data: data, encoding: .utf16LittleEndian)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16BigEndian)
        }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        ))
        return String(data: data, encoding: gb18030)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private static func detectedEncoding(_ data: Data) -> String {
        if data.starts(with: [0xFF, 0xFE]) { return "UTF-16LE" }
        if data.starts(with: [0xFE, 0xFF]) { return "UTF-16BE" }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return "UTF-8-BOM" }
        if String(data: data, encoding: .utf8) != nil { return "UTF-8" }
        return "GB18030-or-ISO-8859-1"
    }

    private static func normalizeToSRT(_ value: String) -> String? {
        let normalized = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if normalized.contains("-->") {
            // Jellyfin's ASS endpoint can return an SRT-shaped document while
            // retaining ASS override tags such as {\\blur3}. Strip those
            // tags even on the SRT-shaped path; otherwise VLC treats them as
            // literal subtitle text and CJK rendering falls back to tofu.
            return normalized
                .components(separatedBy: "\n")
                .map { assTextToPlainText($0) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        }

        let lines = normalized.components(separatedBy: "\n")
        let formatLine = lines.first {
            $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("format:")
        }
        let formatFields = formatLine.map {
            String($0.drop { $0 != ":" }.dropFirst())
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        } ?? []
        guard let startIndex = formatFields.firstIndex(of: "start"),
              let endIndex = formatFields.firstIndex(of: "end"),
              let textIndex = formatFields.firstIndex(of: "text") else {
            return nil
        }

        var cues: [(start: String, end: String, text: String)] = []
        for line in lines {
            guard line.lowercased().hasPrefix("dialogue:") else { continue }
            let payload = String(line.drop { $0 != ":" }.dropFirst())
            let fields = payload.split(separator: ",", maxSplits: max(formatFields.count - 1, 0))
                .map(String.init)
            guard fields.indices.contains(startIndex),
                  fields.indices.contains(endIndex),
                  fields.indices.contains(textIndex),
                  let start = assTimestamp(fields[startIndex]),
                  let end = assTimestamp(fields[endIndex]) else { continue }
            let text = assTextToPlainText(fields[textIndex])
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            cues.append((start, end, text))
        }
        guard !cues.isEmpty else { return nil }
        return cues.enumerated().map { index, cue in
            "\(index + 1)\n\(cue.start) --> \(cue.end)\n\(cue.text)"
        }.joined(separator: "\n\n") + "\n"
    }

    private static func assTimestamp(_ value: String) -> String? {
        let fields = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard fields.count == 3,
              let hours = Int(fields[0]),
              let minutes = Int(fields[1]) else { return nil }
        let secondParts = fields[2].split(separator: ".", maxSplits: 1).map(String.init)
        guard let seconds = Int(secondParts[0]), seconds < 60 else { return nil }
        let centiseconds = secondParts.count > 1
            ? Int(String(secondParts[1].prefix(2)).padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
            : 0
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, centiseconds * 10)
    }

    private static func assTextToPlainText(_ value: String) -> String {
        var text = value
        while let start = text.firstIndex(of: "{") {
            guard let end = text[start...].firstIndex(of: "}") else { break }
            text.removeSubrange(start...end)
        }
        return text
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\h", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
private final class JellyfinLibraryStore: ObservableObject {
    @Published private(set) var endpoint: URL
    private let configuredPlaybackEndpoint: URL?
    private var verifiedLANPlaybackEndpoint: URL?
    private var lanPlaybackProbeRetryTask: Task<Void, Never>?
    private var lanPlaybackProbePolicy = JellyfinLANPlaybackProbePolicy()
    var playbackEndpoint: URL? { verifiedLANPlaybackEndpoint ?? configuredPlaybackEndpoint }
    let allowsSelfSignedCertificates: Bool

    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = true
    @Published private(set) var username = ""
    @Published private(set) var libraries: [JellyfinMediaEntry] = []
    @Published private(set) var continueWatching: [JellyfinMediaEntry] = []
    @Published private(set) var movies: [JellyfinMediaEntry] = []
    @Published private(set) var series: [JellyfinMediaEntry] = []
    @Published private(set) var recentlyAdded: [JellyfinMediaEntry] = []
    @Published private(set) var favorites: [JellyfinMediaEntry] = []
    @Published private(set) var favoriteItemIDs: Set<String> = []
    @Published var errorMessage: String?

    private let playbackActivity = PlaybackActivityScope()
    private var responseScope = PlaybackResponseScope()
    private var client: JellyfinClient? {
        didSet {
            responseScope.invalidateSession()
            playbackActivity.invalidate()
            playbackStopSnapshot = nil
        }
    }
    private var userID: String?
    private var didRestore = false
    private var trustDelegate: JellyfinCertificateTrustDelegate?
    private let endpointCandidates: [URL]
    private var bitrateMeasurements: [String: (bitrate: Int, rawBitrate: Int, measuredAt: Date, wasMeasured: Bool)] = [:]
    private var bitrateMeasurementTasks: [String: Task<Void, Never>] = [:]
    private var resolvedPlaybackRouteIsPrivate: Bool?
    private var dsmSession: DSMSession?
    private var dsmSharedFolderPaths: [String]
    private var dsmPlaybackContextObserver: JellyfinDSMPlaybackContextObserver?
    private var unavailableDSMPlaybackPaths: [String: Date] = [:]
    @Published private(set) var playbackStopSnapshot: (itemID: String, position: Double, revision: UUID)?
    private var originalRouteWarmup: (itemID: String, startedAt: Date,
        endpoint: URL, network: String, task: Task<URL?, Never>)?

    init(
        endpoint: URL,
        playbackEndpoint: URL?,
        allowsSelfSignedCertificates: Bool,
        dsmSession: DSMSession? = nil,
        dsmSharedFolderPaths: [String] = [],
        fallbackEndpoints: [URL] = [],
        connectionStore: NASConnectionStore? = nil
    ) {
        self.endpoint = endpoint
        self.configuredPlaybackEndpoint = playbackEndpoint.flatMap(Self.originURL)
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.dsmSession = dsmSession
        self.dsmSharedFolderPaths = dsmSharedFolderPaths
        self.endpointCandidates = Self.jellyfinEndpointCandidates(
            from: [endpoint] + fallbackEndpoints
        )
        if let connectionStore {
            dsmPlaybackContextObserver = JellyfinDSMPlaybackContextObserver(
                connectionStore: connectionStore
            ) { [weak self] session in
                guard let self else { return }
                self.updateDSMPlaybackContext(
                    session: session, sharedFolderPaths: self.dsmSharedFolderPaths
                )
            }
        }
        // Start observing while the library opens, before the first Play tap.
        // NWPathMonitor's first update is asynchronous.
        _ = PlaybackNetworkObserver.shared
        Task { @MainActor [weak self] in
            await self?.refreshPlaybackRouteClassification()
            await self?.verifyLANPlaybackEndpoint()
        }
    }

    private func verifyLANPlaybackEndpoint() async {
        guard configuredPlaybackEndpoint == nil,
              verifiedLANPlaybackEndpoint == nil else {
            recordPlaybackRouteState(stage: "probeSkipped")
            return
        }
        let candidate = endpointCandidates.first(where: {
            NetworkHostClassifier.isPrivate($0.host) && $0.host != endpoint.host
        }) ?? Self.defaultLANPlaybackEndpoint(for: dsmSession?.endpoints.lanAddress)
        guard let candidate else {
            recordPlaybackRouteState(stage: "probeSkipped", reason: "noPrivateCandidate")
            return
        }
        let probeStartedAt = ProcessInfo.processInfo.systemUptime
        recordPlaybackRouteState(stage: "probeStarted")
        defer {
            recordPlaybackRouteState(stage: "probeFinished", extra: [
                "probeMs": String(Int(max(ProcessInfo.processInfo.systemUptime - probeStartedAt, 0) * 1_000))
            ])
        }
        guard let publicID = await Self.publicServerID(at: endpoint) else {
            record("diagnostics.jellyfin.playback_route_probe", level: .info,
                   details: ["result": "publicInfoUnavailable"])
            scheduleLANPlaybackProbeRetry(publicID: nil, lanID: nil)
            return
        }
        guard let lanID = await Self.publicServerID(at: candidate) else {
            record("diagnostics.jellyfin.playback_route_probe", level: .info,
                   details: ["result": "lanInfoUnavailable",
                             "target": DiagnosticLogStore.redactedURL(candidate)])
            scheduleLANPlaybackProbeRetry(publicID: publicID, lanID: nil)
            return
        }
        guard lanPlaybackProbePolicy.evaluate(publicID: publicID, lanID: lanID) == .verified else {
            record("diagnostics.jellyfin.playback_route_probe", level: .warning,
                   details: ["result": "differentServer",
                             "target": DiagnosticLogStore.redactedURL(candidate)])
            return
        }
        lanPlaybackProbeRetryTask?.cancel()
        lanPlaybackProbeRetryTask = nil
        verifiedLANPlaybackEndpoint = Self.originURL(for: candidate)
        await refreshPlaybackRouteClassification()
        record("diagnostics.jellyfin.playback_route_verified", level: .info,
               details: ["route": "sameServerLAN", "target": DiagnosticLogStore.redactedURL(candidate)])
    }

    private func recordPlaybackRouteState(stage: String, reason: String? = nil,
                                          extra: [String: String] = [:]) {
        let selected = playbackEndpoint ?? endpoint
        let selection = verifiedLANPlaybackEndpoint != nil ? "verifiedSameServerLAN"
            : (configuredPlaybackEndpoint != nil ? "configuredPlaybackEndpoint" : "libraryEndpoint")
        let details = [
            "stage": stage, "selection": selection, "reason": reason ?? selection,
            "selectedAddressKind": PlaybackConnectionContext.make(url: selected).addressKind.rawValue,
            "selectedScheme": selected.scheme ?? "-", "selectedPort": selected.port.map(String.init) ?? "default",
            "candidateCount": String(endpointCandidates.count),
            "hasPrivateCandidate": String(endpointCandidates.contains { NetworkHostClassifier.isPrivate($0.host) }),
            "hasDSMLANCandidate": String(Self.defaultLANPlaybackEndpoint(for: dsmSession?.endpoints.lanAddress) != nil),
            "retryCount": String(lanPlaybackProbePolicy.retryCount)
        ].merging(extra) { _, new in new }
        record("diagnostics.jellyfin.playback_route_state", level: .info, details: details)
    }

    private func scheduleLANPlaybackProbeRetry(publicID: String?, lanID: String?) {
        guard lanPlaybackProbeRetryTask == nil,
              case let .retryAfter(delay) = lanPlaybackProbePolicy.evaluate(
                publicID: publicID, lanID: lanID) else { return }
        lanPlaybackProbeRetryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard let self else { return }
            self.lanPlaybackProbeRetryTask = nil
            await self.verifyLANPlaybackEndpoint()
        }
    }

    private static func defaultLANPlaybackEndpoint(for dsmLAN: URL?) -> URL? {
        guard let host = dsmLAN?.host, NetworkHostClassifier.isPrivate(host) else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = 8096
        return components.url
    }

    private static func publicServerID(at endpoint: URL) async -> String? {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else { return nil }
        let base = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = (base.isEmpty ? "" : "/\(base)") + "/System/Info/Public"
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = object["Id"] as? String, !id.isEmpty else { return nil }
        return id
    }

    func updateDSMPlaybackContext(
        session: DSMSession?,
        sharedFolderPaths: [String]
    ) {
        let normalizedSharedFolderPaths = Array(Set(sharedFolderPaths)).sorted()
        guard dsmSession?.sid != session?.sid
            || dsmSession?.baseURL != session?.baseURL
            || dsmSession?.endpoints != session?.endpoints
            || dsmSharedFolderPaths != normalizedSharedFolderPaths else {
            return
        }
        dsmSession = session
        dsmSharedFolderPaths = normalizedSharedFolderPaths
        unavailableDSMPlaybackPaths.removeAll()
        Task { await verifyLANPlaybackEndpoint() }
    }

    private static func jellyfinEndpointCandidates(from endpoints: [URL]) -> [URL] {
        var result: [URL] = []
        var seen = Set<String>()
        for endpoint in endpoints {
            for path in [endpoint.path, "/jellyfin", "/emby"] {
                guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
                    continue
                }
                components.path = path == "/" ? "" : path
                components.query = nil
                components.fragment = nil
                guard let candidate = components.url,
                      seen.insert(candidate.absoluteString).inserted else {
                    continue
                }
                result.append(candidate)
            }
        }
        return result
    }

    private static func originURL(for url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    func restoreIfNeeded() async {
        guard !didRestore else { return }
        didRestore = true
        guard let restored = endpointCandidates.compactMap({ candidate in
            KeychainStore.shared.loadJellyfinSession(endpoint: candidate).map {
                (endpoint: candidate, session: $0)
            }
        }).first else {
            isLoading = false
            return
        }
        endpoint = restored.endpoint
        await refreshPlaybackRouteClassification()
        let stored = restored.session
        username = stored.username
        userID = stored.userID
        client = makeClient(accessToken: stored.accessToken)
        isAuthenticated = true
        await refresh()
    }

    func signIn(username: String, password: String) async {
        let cleanedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedUsername.isEmpty else {
            errorMessage = NSLocalizedString("jellyfin.login.required", comment: "")
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            var authenticatedClient: JellyfinClient?
            var authenticatedAccessToken: String?
            var authenticatedUserID: String?
            var authenticatedUsername: String?
            var lastError: Error?
            for candidate in endpointCandidates {
                endpoint = candidate
                let candidateClient = makeClient(accessToken: nil)
                do {
                    let result = try await candidateClient.signIn(
                        username: cleanedUsername,
                        password: password
                    )
                    guard let accessToken = result.accessToken,
                          let userID = result.user?.id else {
                        throw JellyfinLibraryError.missingSession
                    }
                    authenticatedClient = candidateClient
                    authenticatedAccessToken = accessToken
                    authenticatedUserID = userID
                    authenticatedUsername = result.user?.name
                    break
                } catch {
                    lastError = error
                }
            }
            guard
                let newClient = authenticatedClient,
                let accessToken = authenticatedAccessToken,
                let authenticatedUserID
            else {
                throw lastError ?? JellyfinLibraryError.missingSession
            }
            client = newClient
            userID = authenticatedUserID
            self.username = authenticatedUsername ?? cleanedUsername
            isAuthenticated = true
            try KeychainStore.shared.saveJellyfinSession(
                StoredJellyfinSession(
                    endpointString: endpoint.absoluteString,
                    userID: authenticatedUserID,
                    username: self.username,
                    accessToken: accessToken
                ),
                endpoint: endpoint
            )
            record("diagnostics.jellyfin.login_succeeded", level: .info)
            await refreshPlaybackRouteClassification()
            await loadHome()
        } catch {
            try? await client?.signOut()
            client = nil
            userID = nil
            self.username = ""
            isAuthenticated = false
            errorMessage = loginErrorMessage(for: error)
            isLoading = false
            record(
                "diagnostics.jellyfin.login_failed",
                level: .error,
                details: diagnosticDetails(for: error)
            )
        }
    }

    func refresh() async {
        guard isAuthenticated else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        await loadHome()
    }

    func signOut() async {
        originalRouteWarmup?.task.cancel()
        originalRouteWarmup = nil
        playbackStopSnapshot = nil
        let activeClient = client
        KeychainStore.shared.clearJellyfinSession(endpoint: endpoint)
        client = nil
        userID = nil
        username = ""
        isAuthenticated = false
        isLoading = false
        libraries = []
        continueWatching = []
        movies = []
        series = []
        recentlyAdded = []
        favorites = []
        favoriteItemIDs = []
        try? await activeClient?.signOut()
    }

    func loadLibrary(_ library: JellyfinMediaEntry) async throws -> [JellyfinMediaEntry] {
        let kinds: [BaseItemKind]
        switch library.collectionType {
        case CollectionType.tvshows.rawValue:
            kinds = [.series]
        case CollectionType.music.rawValue, CollectionType.musicvideos.rawValue:
            kinds = [.musicAlbum, .audio, .musicVideo]
        default:
            kinds = [.movie, .series, .video]
        }
        let items = try await loadItems(parentID: library.id, kinds: kinds, limit: 250)
        registerFavoriteState(from: items)
        return items
    }

    func loadEpisodes(seriesID: String) async throws -> [JellyfinMediaEntry] {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        var parameters = Paths.GetEpisodesParameters()
        parameters.userID = userID
        parameters.fields = itemFields
        parameters.limit = 500
        parameters.enableImages = true
        parameters.enableImageTypes = [.primary, .thumb, .backdrop]
        parameters.enableUserData = true
        parameters.sortBy = .sortName
        let response = try await client.send(
            Paths.getEpisodes(seriesID: seriesID, parameters: parameters)
        ).value
        let items = (response.items ?? [])
            .compactMap(mapItem)
            .sorted { lhs, rhs in
                let left = (lhs.seasonNumber ?? Int.max, lhs.episodeNumber ?? Int.max, lhs.title)
                let right = (rhs.seasonNumber ?? Int.max, rhs.episodeNumber ?? Int.max, rhs.title)
                if left.0 != right.0 { return left.0 < right.0 }
                if left.1 != right.1 { return left.1 < right.1 }
                return left.2.localizedStandardCompare(right.2) == .orderedAscending
            }
        registerFavoriteState(from: items)
        return items
    }

    func imageURL(
        for entry: JellyfinMediaEntry,
        width: Int = 480,
        landscape: Bool = false,
        prefersBackdrop: Bool = false,
        quality: Int? = nil
    ) -> URL? {
        guard let client else { return nil }
        let useBackdrop = prefersBackdrop && entry.backdropImageTag != nil
        let useThumb = !useBackdrop && landscape && entry.thumbImageTag != nil
        let imageType: ImageType = useBackdrop ? .backdrop : (useThumb ? .thumb : .primary)
        let imageTag = useBackdrop
            ? entry.backdropImageTag
            : (useThumb ? entry.thumbImageTag : entry.imageTag)
        var parameters = Paths.GetItemImageParameters()
        parameters.maxWidth = width
        parameters.quality = quality ?? (prefersBackdrop ? 94 : 88)
        parameters.tag = imageTag
        return client.url(
            with: Paths.getItemImage(
                itemID: useBackdrop || useThumb ? entry.id : entry.imageItemID,
                imageType: imageType.rawValue,
                parameters: parameters
            ),
            queryAPIKey: true
        )
    }

    func isFavorite(_ entry: JellyfinMediaEntry) -> Bool {
        favoriteItemIDs.contains(entry.id)
    }

    func toggleFavorite(_ entry: JellyfinMediaEntry) async {
        guard let client, let userID else { return }
        let shouldFavorite = !isFavorite(entry)
        do {
            if shouldFavorite {
                _ = try await client.send(
                    Paths.markFavoriteItem(itemID: entry.id, userID: userID)
                ).value
                favoriteItemIDs.insert(entry.id)
                if !favorites.contains(where: { $0.id == entry.id }) {
                    favorites.insert(entry, at: 0)
                }
            } else {
                _ = try await client.send(
                    Paths.unmarkFavoriteItem(itemID: entry.id, userID: userID)
                ).value
                favoriteItemIDs.remove(entry.id)
                favorites.removeAll { $0.id == entry.id }
            }
        } catch {
            errorMessage = NSLocalizedString("jellyfin.favorite.failed", comment: "")
        }
    }

    func search(query: String) async throws -> [JellyfinMediaEntry] {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return [] }
        let items = try await loadItems(
            parentID: nil,
            kinds: [.movie, .series, .episode, .audio, .video, .musicAlbum, .musicVideo],
            limit: 80,
            searchTerm: cleanedQuery
        )
        registerFavoriteState(from: items)
        return items
    }

    func loadDetail(itemID: String) async throws -> JellyfinMediaEntry {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        let sessionID = responseScope.sessionID
        let response = try await client.send(
            Paths.getItem(itemID: itemID, userID: userID)
        ).value
        try Task.checkCancellation()
        guard responseScope.acceptsSession(sessionID) else { throw CancellationError() }
        guard let item = mapItem(response) else {
            throw JellyfinLibraryError.missingItem
        }
        registerFavoriteState(from: [item])
        // The detail page is useful lead time for the existing bounded probe.
        // Recheck a stale restrictive sample for this source before Play is tapped.
        if item.kind == .movie || item.kind == .episode || item.kind == .video {
            scheduleBitrateMeasurementIfNeeded(client: client, originalSourceBitrate: item.mediaBitrate)
            // Authenticate the two-byte original route while the detail is being
            // read. No decoder, media download, or transcoding session is opened.
            if playbackRouteIsPrivate || PlaybackNetworkObserver.shared.snapshot().cacheKey == "wifi",
               originalRouteWarmup?.itemID != item.id
                || Date().timeIntervalSince(originalRouteWarmup?.startedAt ?? .distantPast) >= 30 {
                originalRouteWarmup?.task.cancel()
                let task = Task { [weak self] in
                    await self?.probeJellyfinOriginalURL(for: item, client: client, playbackTraceID: nil)
                }
                originalRouteWarmup = (item.id, Date(), playbackEndpoint ?? endpoint,
                    PlaybackNetworkObserver.shared.snapshot().cacheKey, task)
            }
        }
        return item
    }

    func loadSimilarItems(itemID: String) async throws -> [JellyfinMediaEntry] {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        var parameters = Paths.GetSimilarItemsParameters()
        parameters.userID = userID
        parameters.limit = 12
        parameters.fields = itemFields
        let response = try await client.send(
            Paths.getSimilarItems(itemID: itemID, parameters: parameters)
        ).value
        let items = (response.items ?? []).compactMap(mapItem)
        registerFavoriteState(from: items)
        return items
    }

    func personImageURL(for person: JellyfinPersonEntry, width: Int = 320) -> URL? {
        guard let client, let imageItemID = person.imageItemID, person.imageTag != nil else {
            return nil
        }
        var parameters = Paths.GetItemImageParameters()
        parameters.maxWidth = width
        parameters.quality = 88
        parameters.tag = person.imageTag
        return client.url(
            with: Paths.getItemImage(
                itemID: imageItemID,
                imageType: ImageType.primary.rawValue,
                parameters: parameters
            ),
            queryAPIKey: true
        )
    }

    func playbackRequest(
        for entry: JellyfinMediaEntry,
        selection: JellyfinPlaybackSelection? = nil,
        forcedServerBitrate: Int? = nil,
        forcedStartTimeTicks: Int? = nil,
        forcedServerReason: String? = nil,
        forcesOriginalPlayback: Bool = false,
        forcesExperimentalOriginalPlayback: Bool = false,
        prefersFastStartupDirectPlay: Bool = false,
        selectedQualityID: String? = nil,
        usesGreenfieldPlayback: Bool = false
    ) async throws -> MediaPlaybackRequest? {
        let preferenceKey = playbackPreferenceKey(for: entry)
        var effectiveSelection = selection
        if usesGreenfieldPlayback, selection == nil,
           let saved = savedPlaybackTrackSelection(for: entry) {
            effectiveSelection = saved
        }
        var request = try await makePlaybackRequest(for: entry, selection: effectiveSelection,
            forcedServerBitrate: forcedServerBitrate, forcedStartTimeTicks: forcedStartTimeTicks,
            forcedServerReason: forcedServerReason, forcesOriginalPlayback: forcesOriginalPlayback,
            forcesExperimentalOriginalPlayback: forcesExperimentalOriginalPlayback,
            prefersFastStartupDirectPlay: prefersFastStartupDirectPlay, selectedQualityID: selectedQualityID,
            usesGreenfieldPlayback: usesGreenfieldPlayback)
        // Jellyfin remains authoritative for position; this key restores tracks only.
        if usesGreenfieldPlayback { request?.localResumeKey = preferenceKey }
        return request
    }

    private func playbackPreferenceKey(for entry: JellyfinMediaEntry) -> String? {
        userID.map {
            LocalPlaybackResumeStore.key(server: endpoint, account: "jellyfin:\($0)",
                path: "jellyfin:\(entry.id):\(entry.mediaSourceID ?? "")",
                byteLength: entry.mediaSize.map(Int64.init), modifiedAt: nil)
        }
    }

    func savedPlaybackTrackSelection(for entry: JellyfinMediaEntry) -> JellyfinPlaybackSelection? {
        guard let key = playbackPreferenceKey(for: entry),
              let saved = LocalPlaybackResumeStore.shared.entry(for: key) else { return nil }
        let restored = saved.restoredTrackSelection(
            audioIDs: entry.audioTracks.map(\.index), subtitleIDs: entry.subtitleTracks.map(\.index),
            defaultAudio: entry.defaultAudioStreamIndex, defaultSubtitle: entry.preferredSubtitleStreamIndex)
        return JellyfinPlaybackSelection(audioStreamIndex: restored.audio, subtitleStreamIndex: restored.subtitle)
    }

    private func makePlaybackRequest(
        for entry: JellyfinMediaEntry,
        selection: JellyfinPlaybackSelection? = nil,
        forcedServerBitrate: Int? = nil,
        forcedStartTimeTicks: Int? = nil,
        forcedServerReason: String? = nil,
        forcesOriginalPlayback: Bool = false,
        forcesExperimentalOriginalPlayback: Bool = false,
        prefersFastStartupDirectPlay: Bool = false,
        selectedQualityID: String? = nil,
        usesGreenfieldPlayback: Bool = false
    ) async throws -> MediaPlaybackRequest? {
        guard let client, entry.isPlayable else { return nil }
        let requestedAt = Date()
        let playbackTraceID = UUID().uuidString.prefix(8).description
        if entry.kind == .audio {
            var parameters = Paths.GetAudioStreamParameters()
            parameters.container = entry.container
            parameters.isStatic = true
            guard let apiStreamURL = client.url(
                with: Paths.getAudioStream(itemID: entry.id, parameters: parameters),
                queryAPIKey: true
            ) else {
                throw JellyfinLibraryError.missingPlaybackURL
            }
            let streamURL = preferredPlaybackURL(apiStreamURL)
            let extensionHint = entry.container
                .flatMap { $0.split(separator: ",", maxSplits: 1).first }
                .map(String.init)
            return MediaPlaybackRequest(
                requestedAt: requestedAt,
                url: streamURL,
                title: entry.title,
                allowsSelfSignedCertificates: requiresCertificateBypass(for: streamURL),
                source: .jellyfin,
                contentKind: .audio,
                fileExtensionOverride: extensionHint,
                initialPosition: entry.effectivePlaybackProgress,
                initialOrientationMode: .automatic,
                isPrivateNetworkRoute: playbackRouteIsPrivate,
                playbackTracker: makePlaybackTracker(
                    for: entry,
                    playMethod: .directPlay,
                    playSessionID: nil,
                    mediaSourceID: entry.mediaSourceID,
                    subtitleStreamIndex: nil
                ),
                playbackTraceID: playbackTraceID,
                audioLyricsURL: client.url(with: Paths.getLyrics(itemID: entry.id), queryAPIKey: true)
            )
        }

        let isDiscImage = Self.firstContainer(entry.container) == "iso"
            || entry.mediaPath.map { ($0 as NSString).pathExtension.lowercased() == "iso" } == true
        if usesGreenfieldPlayback && isDiscImage {
            guard let route = await preferredOriginalPlaybackRoute(for: entry, client: client,
                playbackTraceID: playbackTraceID) else {
                throw JellyfinLibraryError.missingPlaybackURL
            }
            let prepared = try await ISOPlaybackAdapter.prepare(
                sourceURL: route.handoffURL,
                allowsSelfSignedCertificates: route.allowsSelfSignedCertificates
            )
            return MediaPlaybackRequest(
                requestedAt: requestedAt,
                url: prepared.playbackURL,
                title: entry.title,
                source: .jellyfin,
                contentKind: .discImage,
                fileExtensionOverride: prepared.fileExtension,
                initialPosition: entry.effectivePlaybackProgress,
                initialOrientationMode: .landscape,
                totalDurationSeconds: entry.runTimeTicks.map { Double($0) / 10_000_000 },
                isPrivateNetworkRoute: route.isPrivateNetworkRoute,
                playbackTracker: makePlaybackTracker(for: entry, playMethod: .directPlay,
                    playSessionID: nil, mediaSourceID: entry.mediaSourceID, subtitleStreamIndex: nil),
                externalHandoffResource: MediaPlaybackResource(url: route.handoffURL,
                    fileExtensionOverride: "iso", allowsSelfSignedCertificates: route.allowsSelfSignedCertificates),
                playbackTraceID: playbackTraceID
            )
        }

        let requestedAudioStreamIndex = selection?.audioStreamIndex
            ?? entry.defaultAudioStreamIndex
        let selectedSubtitleStreamIndex = selection == nil
            ? entry.preferredSubtitleStreamIndex
            : selection?.subtitleStreamIndex
        let selectedSubtitleCodec = entry.subtitleTracks
            .first(where: { $0.index == selectedSubtitleStreamIndex })?
            .codec
        let rendersBitmapSubtitleLocally = usesGreenfieldPlayback
            && GreenfieldPlaybackControls.canDecodeBitmapSubtitle(selectedSubtitleCodec)
        var selectedAudioStreamIndex = requestedAudioStreamIndex
        var selectedAudioCodec = entry.audioTracks
            .first(where: { $0.index == selectedAudioStreamIndex })?
            .codec
        let selectedSubtitleTrackOrdinal = selectedSubtitleStreamIndex.flatMap { selectedIndex in
            entry.subtitleTracks.firstIndex { $0.index == selectedIndex }
        }

        // A fresh measurement from browsing the library can rule out an
        // original whose bitrate is far beyond the route's delivery capacity.
        // Never wait for a new probe on the Play path.
        let startupNetwork = PlaybackNetworkObserver.shared.snapshot()
        let startupRoute = playbackEndpoint ?? endpoint
        recordPlaybackRouteState(stage: "playRequested", extra: ["playbackTraceID": playbackTraceID])
        let startupOrigin = Self.originURL(for: startupRoute)?.absoluteString
            ?? startupRoute.absoluteString
        let startupSample = bitrateMeasurements["\(startupOrigin)|\(startupNetwork.cacheKey)"]
        let knownCapacity = startupSample.flatMap { sample -> Int? in
            sample.wasMeasured && Date().timeIntervalSince(sample.measuredAt) < 120
                ? sample.rawBitrate : nil
        }
        let knownInsufficientOriginalBandwidth = usesGreenfieldPlayback
            && forcedServerBitrate == nil
            && PlaybackAdaptiveBitratePolicy.isOriginalClearlyUnsustainable(
                sourceBitrate: entry.mediaBitrate,
                measuredCapacity: knownCapacity,
                isPrivateRoute: playbackRouteIsPrivate,
                forcesOriginal: forcesOriginalPlayback || forcesExperimentalOriginalPlayback)
        let prefersOriginalStream = usesGreenfieldPlayback
            && forcedServerBitrate == nil && !knownInsufficientOriginalBandwidth
        // Probe without creating a proxy or opening a decoder.
        let startsOriginalProbe = usesGreenfieldPlayback
            && !knownInsufficientOriginalBandwidth
            && !playbackRouteIsPrivate
            && !forcesOriginalPlayback && !forcesExperimentalOriginalPlayback
            && forcedServerReason == nil
            && GreenfieldOriginalPlaybackPolicy.allowsOriginal(
                forcedServerBitrate: forcedServerBitrate,
                audioRequiresTranscode: Self.requiresPlaybackAudioTranscode(
                    audioCodec: selectedAudioCodec, usesGreenfieldPlayback: true),
                subtitleRequiresServer: selectedSubtitleStreamIndex != nil
                    && !rendersBitmapSubtitleLocally
                    && !prefersFastStartupDirectPlay
                    && Self.requiresBurnIn(subtitleCodec: selectedSubtitleCodec),
                routeIsPrivate: false, explicitOriginal: false, remoteBitrateFits: true)
        let warmup = originalRouteWarmup.flatMap {
            $0.itemID == entry.id && Date().timeIntervalSince($0.startedAt) < 30 ? $0 : nil
        }
        let originalProbeTask: Task<URL?, Never>? = (startsOriginalProbe || warmup != nil) ? Task {
            if let warmup {
                @MainActor func stillMatches() -> Bool {
                    PlaybackOriginalWarmupPolicy.matches(warmedEndpoint: warmup.endpoint,
                        currentEndpoint: playbackEndpoint ?? endpoint, warmedNetwork: warmup.network,
                        currentNetwork: PlaybackNetworkObserver.shared.snapshot().cacheKey)
                }
                if stillMatches(), let url = await warmup.task.value,
                   !Task.isCancelled, stillMatches() {
                    record("diagnostics.jellyfin.playback_preparing", level: .info,
                        details: ["stage": "originalRouteWarmupReused", "playbackTraceID": playbackTraceID])
                    return url
                }
                warmup.task.cancel()
                record("diagnostics.jellyfin.playback_preparing", level: .info,
                    details: ["stage": "originalRouteWarmupInvalidated",
                              "reason": "routeOrNetworkChangedOrUnavailable", "playbackTraceID": playbackTraceID])
            }
            guard !Task.isCancelled else { return nil }
            return await probeJellyfinOriginalURL(for: entry, client: client,
                playbackTraceID: playbackTraceID)
        } : nil
        defer { originalProbeTask?.cancel() }
        let originalSourceBitrate = startsOriginalProbe ? entry.mediaBitrate : nil

        if !prefersOriginalStream,
           forcedServerBitrate == nil,
           forcedServerReason == nil,
           !forcesOriginalPlayback,
           !forcesExperimentalOriginalPlayback {
            await ensureBitrateMeasurementIfNeeded(client: client,
                originalSourceBitrate: originalSourceBitrate)
        }

        let bitrateDecision = playbackBitrateDecision(originalSourceBitrate: originalSourceBitrate,
            usesGreenfieldPlayback: usesGreenfieldPlayback)
        // Direct-play eligibility and the server transcoding target solve two
        // different problems. A measured 60+ Mbps Wi-Fi route should be allowed
        // to direct-play a matching source instead of being forced through the
        // old 30 Mbps transcoding ceiling. When transcoding really is needed,
        // cap automatic remote HLS at 20 Mbps so the server can produce the first
        // segment quickly; explicit quality choices remain exact.
        let directPlayBudget = bitrateDecision.directPlayMaximumBitrate
        let automaticCeiling = playbackRouteIsPrivate
            ? directPlayBudget
            : min(directPlayBudget, 20_000_000)
#if DEBUG
        // A one-process, explicitly launched test fixture can hold the initial
        // rendition constant while the media proxy changes delivery speed.
        let testStartupCeiling = Int(ProcessInfo.processInfo.environment[
            "NASTART_TEST_STARTUP_HLS_BPS"] ?? "").flatMap {
                (2_000_000...20_000_000).contains($0) ? $0 : nil
            }
#else
        let testStartupCeiling: Int? = nil
#endif
        let maxBitrate = forcedServerBitrate
            ?? (usesGreenfieldPlayback ? testStartupCeiling : nil)
            ?? (knownInsufficientOriginalBandwidth
                ? PlaybackAdaptiveBitratePolicy.target(
                    currentCeiling: automaticCeiling,
                    capacity: knownCapacity,
                    networkKey: startupNetwork.cacheKey) ?? automaticCeiling
                : automaticCeiling)
        let sourceBitrateFitsDirectBudget = entry.mediaBitrate.map {
            $0 <= directPlayBudget
        } ?? false
        let largeRemoteOriginalRisk = !prefersOriginalStream && Self.requiresServerPlaybackForLargeRemoteOriginal(
            container: entry.container,
            bitrate: entry.mediaBitrate,
            byteSize: entry.mediaSize,
            routeIsPrivate: playbackRouteIsPrivate
        ) && (!usesGreenfieldPlayback || GreenfieldOriginalPlaybackPolicy.retainsLargeRemoteGuard(
            networkKey: bitrateDecision.networkKey, bandwidthBasis: bitrateDecision.basis,
            sourceBitrate: entry.mediaBitrate, originalBudget: directPlayBudget))
        let automaticSourceBitrateFitsDirectBudget = sourceBitrateFitsDirectBudget
            && !largeRemoteOriginalRisk
        let canUseExperimentalOriginalPlayback = forcesExperimentalOriginalPlayback
            && forcedServerBitrate == nil
            && forcedServerReason == nil
        let routeCanAttemptOriginalPlayback = prefersOriginalStream || playbackRouteIsPrivate
            || forcesOriginalPlayback
            || canUseExperimentalOriginalPlayback
            || automaticSourceBitrateFitsDirectBudget
        if routeCanAttemptOriginalPlayback,
           forcedServerBitrate == nil,
           forcedServerReason == nil,
           let startupAudioTrack = Self.directPlayableStartupAudioTrack(
               in: entry,
               selectedAudioStreamIndex: selectedAudioStreamIndex,
               usesGreenfieldPlayback: usesGreenfieldPlayback
           ) {
            record(
                "diagnostics.jellyfin.playback_preparing",
                level: .info,
                details: [
                    "mode": "directPlayableAudioSelected",
                    "fromAudioStreamIndex": selectedAudioStreamIndex.map(String.init) ?? "default",
                    "fromAudioCodec": selectedAudioCodec ?? "-",
                    "toAudioStreamIndex": "\(startupAudioTrack.index)",
                    "toAudioCodec": startupAudioTrack.codec ?? "-",
                    "playbackTraceID": playbackTraceID,
                    "reason": "avoidInitialServerHLS",
                    "network": bitrateDecision.networkKey,
                    "sourceBitrate": entry.mediaBitrate.map(String.init) ?? "-"
                ]
            )
            selectedAudioStreamIndex = startupAudioTrack.index
            selectedAudioCodec = startupAudioTrack.codec
        }
        let selectedAudioTrackOrdinal = selectedAudioStreamIndex.flatMap { selectedIndex in
            entry.audioTracks.firstIndex { $0.index == selectedIndex }
        }
        record(
            "diagnostics.jellyfin.playback_preparing",
            level: .info,
            details: [
                "itemKind": entry.kind.rawValue,
                "container": entry.container ?? "-",
                "subtitleCodec": selectedSubtitleCodec ?? "-",
                "audioCodec": selectedAudioCodec ?? "-",
                "subtitleStreamIndex": selectedSubtitleStreamIndex.map(String.init) ?? "none",
                "audioStreamIndex": selectedAudioStreamIndex.map(String.init) ?? "default",
                "bitrateBasis": bitrateDecision.basis,
                "maximumBitrate": "\(maxBitrate)",
                "networkMaximumBitrate": "\(bitrateDecision.maximumBitrate)",
                "directPlayMaximumBitrate": "\(directPlayBudget)",
                    "largeRemoteOriginalRisk": largeRemoteOriginalRisk ? "yes" : "no",
                    "requestReason": forcedServerReason ?? "initialPlayback",
                    "playbackTraceID": playbackTraceID,
                    "allowsDirectPlay": "preferred",
                    "experimentalOriginal": canUseExperimentalOriginalPlayback ? "yes" : "no",
                "defaultMode": prefersOriginalStream ? "originalFirst" : "adaptiveAuto",
                "deviceFamily": MediaPlaybackCapabilities.current.deviceFamily,
                "osVersion": MediaPlaybackCapabilities.current.osVersion
            ]
        )
        do {
            let requestedStartTimeTicks = max(
                forcedStartTimeTicks ?? entry.effectivePlaybackPositionTicks ?? 0,
                0
            )
            let prepared: JellyfinPreparedPlayback
            // Use the same original-stream engine as device files. Explicit quality
            // and unsupported audio/subtitles retain server negotiation.
            let requiresSelectedAudioTranscode = Self.requiresPlaybackAudioTranscode(
                audioCodec: selectedAudioCodec, usesGreenfieldPlayback: usesGreenfieldPlayback)
            let prefersRemoteOriginalPlayback = (prefersOriginalStream || automaticSourceBitrateFitsDirectBudget)
                && !requiresSelectedAudioTranscode
            let requiresDeviceCompatibilityTranscode = !usesGreenfieldPlayback && Self.requiresDeviceCompatibilityTranscode(
                audioCodec: selectedAudioCodec
            )
            let defersServerRenderedSubtitleForFastStartup = prefersFastStartupDirectPlay
                && !rendersBitmapSubtitleLocally
                && forcedServerBitrate == nil
                && forcedServerReason == nil
                && selectedSubtitleStreamIndex != nil
                && Self.requiresBurnIn(subtitleCodec: selectedSubtitleCodec)
            if defersServerRenderedSubtitleForFastStartup {
                record(
                    "diagnostics.jellyfin.playback_preparing",
                    level: .info,
                    details: [
                        "mode": "fastStartupSubtitleDeferred",
                        "playbackTraceID": playbackTraceID,
                        "reason": "avoidInitialServerHLS",
                        "subtitleCodec": selectedSubtitleCodec ?? "-",
                        "subtitleStreamIndex": selectedSubtitleStreamIndex.map(String.init) ?? "none",
                        "network": bitrateDecision.networkKey,
                        "sourceBitrate": entry.mediaBitrate.map(String.init) ?? "-"
                    ]
                )
            }
            let requiresServerSubtitleRendering = selectedSubtitleStreamIndex != nil
                && !rendersBitmapSubtitleLocally
                && !defersServerRenderedSubtitleForFastStartup
                && Self.requiresBurnIn(subtitleCodec: selectedSubtitleCodec)
            // The Debug fixture must hold the starting HLS rendition even if
            // the device has rejoined Wi-Fi or discovered a private NAS route.
            // Otherwise this test can unexpectedly fetch the 82 Mbps original.
            let shouldAttemptDirectPlayback = testStartupCeiling == nil
                && GreenfieldOriginalPlaybackPolicy.allowsOriginal(
                forcedServerBitrate: forcedServerBitrate,
                audioRequiresTranscode: requiresSelectedAudioTranscode || requiresDeviceCompatibilityTranscode,
                subtitleRequiresServer: requiresServerSubtitleRendering,
                routeIsPrivate: playbackRouteIsPrivate, explicitOriginal: forcesOriginalPlayback,
                remoteBitrateFits: prefersRemoteOriginalPlayback,
                experimentalOriginal: canUseExperimentalOriginalPlayback,
                originalFirst: prefersOriginalStream)
            if !shouldAttemptDirectPlayback { originalProbeTask?.cancel() }
            try Task.checkCancellation()
            let directRoute = shouldAttemptDirectPlayback
                ? await preferredOriginalPlaybackRoute(
                    for: entry,
                    client: client,
                    usesGreenfieldPlayback: usesGreenfieldPlayback,
                    playbackTraceID: playbackTraceID,
                    originalProbeTask: originalProbeTask
                )
                : nil
            try Task.checkCancellation()
            if let directRoute {
                let directURL = directRoute.url
                let extensionHint = Self.firstContainer(entry.container) ?? "mp4"
                let directSubtitleSourceURL = Self.requiresBurnIn(subtitleCodec: selectedSubtitleCodec)
                    ? nil
                    : externalSubtitleURL(
                        for: entry,
                        subtitleStreamIndex: selectedSubtitleStreamIndex,
                        client: client
                )
                let directSubtitleURL: URL?
                if let directSubtitleSourceURL,
                   !usesGreenfieldPlayback || requiresCertificateBypass(for: directSubtitleSourceURL) {
                    directSubtitleURL = await JellyfinSubtitleNormalizer.normalize(
                        url: directSubtitleSourceURL,
                        sourceCodec: selectedSubtitleCodec,
                        allowsSelfSignedCertificates: requiresCertificateBypass(
                            for: directSubtitleSourceURL
                        )
                    ) ?? directSubtitleSourceURL
                } else {
                    // Jellyfin's endpoint already returns SRT; Greenfield's
                    // overlay loads/cleans it asynchronously. Do not download
                    // the whole subtitle before opening the video. Keep the
                    // certificate-aware normalizer for self-signed sources.
                    directSubtitleURL = directSubtitleSourceURL
                }
                let externalResource = MediaPlaybackResource(
                    url: directRoute.handoffURL,
                    fileExtensionOverride: extensionHint,
                    subtitleURL: directSubtitleSourceURL
                )
                let internalResource = MediaPlaybackResource(
                    url: directURL,
                    fileExtensionOverride: extensionHint,
                    // Use Jellyfin's UTF-8 SRT conversion for text subtitles
                    // in the in-app VLC path as well as external handoff. This
                    // avoids relying on an embedded ASS font/style that can
                    // render Chinese glyphs as tofu boxes on iOS.
                    subtitleURL: directSubtitleURL,
                    allowsSelfSignedCertificates: directRoute.allowsSelfSignedCertificates
                )
                let mode = "\(directRoute.source)DirectPlay"
                prepared = JellyfinPreparedPlayback(
                    resource: internalResource,
                    externalHandoffResource: externalResource,
                    playSessionID: nil,
                    mediaSourceID: entry.mediaSourceID,
                    playMethod: .directPlay,
                    mode: mode,
                    isPrivateNetworkRoute: directRoute.isPrivateNetworkRoute,
                    allowsSelfSignedCertificates: directRoute.allowsSelfSignedCertificates,
                    playbackTraceID: playbackTraceID
                )
                record(
                    "diagnostics.jellyfin.playback_prepared",
                    level: .info,
                    details: [
                        "mode": mode,
                        "playbackTraceID": playbackTraceID,
                        "container": extensionHint,
                        "playSession": "notRequired",
                        "subtitleCodec": selectedSubtitleCodec ?? "-",
                        "audioCodec": selectedAudioCodec ?? "-",
                        "deviceCompatibilityTranscode": requiresDeviceCompatibilityTranscode ? "yes" : "no",
                        "subtitleStreamIndex": selectedSubtitleStreamIndex.map(String.init) ?? "none",
                        "audioStreamIndex": selectedAudioStreamIndex.map(String.init) ?? "default",
                        "maxBitrate": "unlimitedOriginal",
                        "directPlay": "selected",
                        "remoteOriginalPreferred": prefersRemoteOriginalPlayback ? "yes" : "no",
                        "experimentalOriginal": canUseExperimentalOriginalPlayback ? "yes" : "no",
                        "sourceBitrate": entry.mediaBitrate.map(String.init) ?? "-",
                        "upstream": directRoute.source,
                        "transport": directURL.host == "127.0.0.1" ? "localRangeProxy" : "sourceURL",
                        "prepareMs": Self.elapsedMilliseconds(since: requestedAt)
                    ]
                )
            } else {
                // A failed explicit original switch must leave the previous
                // stream playing, not label a new server transcode as original.
                if usesGreenfieldPlayback && forcesOriginalPlayback {
                    throw JellyfinLibraryError.missingPlaybackURL
                }
                let isForcedServerPlayback = forcedServerBitrate != nil
                let originalRouteWasSkipped = !shouldAttemptDirectPlayback
                let automaticFallbackReason: String
                if knownInsufficientOriginalBandwidth {
                    automaticFallbackReason = "measuredBandwidthInsufficient"
                } else if largeRemoteOriginalRisk,
                   !playbackRouteIsPrivate,
                   !forcesOriginalPlayback,
                   !canUseExperimentalOriginalPlayback {
                    automaticFallbackReason = "largeRemoteOriginalRisk"
                } else if !routeCanAttemptOriginalPlayback {
                    automaticFallbackReason = "automaticBitrateBudget"
                } else if requiresSelectedAudioTranscode {
                    automaticFallbackReason = "audioTranscodeRequired"
                } else if requiresDeviceCompatibilityTranscode {
                    automaticFallbackReason = "deviceCompatibilityTranscode"
                } else if requiresServerSubtitleRendering {
                    automaticFallbackReason = "serverSubtitleRendering"
                } else {
                    automaticFallbackReason = "routeUnavailable"
                }
                record(
                    "diagnostics.jellyfin.playback_preparing",
                    level: originalRouteWasSkipped || isForcedServerPlayback ? .info : .warning,
                    details: [
                        "mode": isForcedServerPlayback
                            ? "serverHLSRequested"
                            : originalRouteWasSkipped
                                ? "originalRangeSkipped"
                                : "originalRangeUnavailable",
                        "reason": isForcedServerPlayback
                            ? forcedServerReason ?? "runtimeReconfigure"
                                : originalRouteWasSkipped
                                    ? automaticFallbackReason
                                : "routeUnavailable",
                        "playbackTraceID": playbackTraceID,
                        "fallback": "serverHLS",
                        "remoteOriginalPreferred": prefersRemoteOriginalPlayback ? "yes" : "no",
                        "experimentalOriginal": canUseExperimentalOriginalPlayback ? "yes" : "no",
                        "routeCanAttemptOriginal": routeCanAttemptOriginalPlayback ? "yes" : "no",
                        "largeRemoteOriginalRisk": largeRemoteOriginalRisk ? "yes" : "no",
                        "audioTranscodeRequired": requiresSelectedAudioTranscode ? "yes" : "no",
                        "deviceCompatibilityTranscode": requiresDeviceCompatibilityTranscode ? "yes" : "no",
                        "serverSubtitleRendering": requiresServerSubtitleRendering ? "yes" : "no",
                        "maximumBitrate": "\(maxBitrate)",
                        "sourceBitrate": entry.mediaBitrate.map(String.init) ?? "-",
                        "audioCodec": selectedAudioCodec ?? "-",
                        "network": bitrateDecision.networkKey,
                        "directSource": directRoute?.source ?? "-"
                    ]
                )
                prepared = try await negotiatedVideoPlayback(
                    for: entry,
                    audioStreamIndex: selectedAudioStreamIndex,
                    subtitleStreamIndex: selectedSubtitleStreamIndex,
                    subtitleCodec: selectedSubtitleCodec,
                    client: client,
                    maxStreamingBitrate: maxBitrate,
                    allowsDirectPlay: false,
                    startTimeTicks: requestedStartTimeTicks,
                    requestedAt: requestedAt,
                    playbackTraceID: playbackTraceID,
                    usesGreenfieldPlayback: usesGreenfieldPlayback,
                    prewarmsCellularVOD: forcedServerReason == nil && forcedServerBitrate == nil
                )
            }
            if usesGreenfieldPlayback {
                var dolby = entry.dolbyVideo
                let audio = entry.audioTracks.first { $0.index == selectedAudioStreamIndex }
                dolby.audioCodec = audio?.codec
                dolby.audioProfile = audio?.profile
                dolby.audioSpatialFormat = audio?.audioSpatialFormat
                record("diagnostics.jellyfin.playback_prepared", level: .info,
                    details: dolby.diagnosticDetails.merging([
                        "stage": "sourceCapabilities", "playbackTraceID": playbackTraceID,
                        "playMethod": prepared.playMethod.rawValue,
                        "audioCodec": audio?.codec ?? "unknown",
                        "audioDecoderAvailable": String(GreenfieldPlaybackControls.canDecodeOriginalAudio(audio?.codec)),
                        "audioPath": prepared.playMethod == .directPlay ? "ksPlayerPCM" : "serverNegotiated",
                        "metadataEvidence": "jellyfinMediaStream"
                    ]) { _, new in new })
            }
            let playbackTracker = makePlaybackTracker(
                for: entry,
                playMethod: prepared.playMethod,
                playSessionID: prepared.playSessionID,
                mediaSourceID: prepared.mediaSourceID ?? entry.mediaSourceID,
                subtitleStreamIndex: selectedSubtitleStreamIndex,
                proxyURL: prepared.resource.url
            )
            // A private original route may carry the 360 Mbps direct-play
            // budget. Feeding half of that value into a compatibility HLS
            // request would ask Jellyfin for an impractical 180 Mbps
            // transcode. Compatibility startup is latency-oriented, so cap
            // the direct-play fallback envelope before applying the one-step
            // bitrate reduction. Explicit quality choices remain unchanged.
            let compatibilityFallbackInitialBitrate = prepared.playMethod == .directPlay
                ? min(maxBitrate, 20_000_000)
                : maxBitrate
            // Direct-play ASS/SSA subtitles are normalized to an external SRT
            // so VLC does not draw tofu glyphs from the embedded styled track.
            // That also makes VLC report the native subtitle track as disabled.
            // A server HLS fallback still needs the original Jellyfin stream
            // index, otherwise the fallback silently starts without subtitles.
            let preservesServerSubtitleSelection = prepared.playMethod == .directPlay
                && prepared.resource.subtitleURL != nil
            let compatibilityFallbackRequestLoader: ((MediaPlaybackRuntimeState?) async -> MediaPlaybackRequest?)? =
                { [weak self] runtimeState in
                    let runtimeAudioStreamIndex: Int?
                    let runtimeSubtitleStreamIndex: Int?
                    if prepared.playMethod == .transcode {
                        runtimeAudioStreamIndex = selectedAudioStreamIndex
                        runtimeSubtitleStreamIndex = selectedSubtitleStreamIndex
                    } else {
                        runtimeAudioStreamIndex = runtimeState?.audioTrackOrdinal.flatMap { ordinal in
                            entry.audioTracks.indices.contains(ordinal)
                                ? entry.audioTracks[ordinal].index
                                : nil
                        } ?? selectedAudioStreamIndex
                        if runtimeState?.subtitlesDisabled == true,
                           runtimeState?.subtitleSelectionKnown == true,
                           (!preservesServerSubtitleSelection || usesGreenfieldPlayback) {
                            runtimeSubtitleStreamIndex = nil
                        } else {
                            runtimeSubtitleStreamIndex = runtimeState?.subtitleTrackOrdinal.flatMap { ordinal in
                                entry.subtitleTracks.indices.contains(ordinal)
                                    ? entry.subtitleTracks[ordinal].index
                                    : nil
                            } ?? selectedSubtitleStreamIndex
                        }
                    }
                    let runtimeSubtitleCodec = entry.subtitleTracks
                        .first(where: { $0.index == runtimeSubtitleStreamIndex })?
                        .codec
                    let fallbackPositionSeconds = runtimeState?.positionSeconds
                        .flatMap { $0 > 0.5 ? $0 : nil }
                        ?? Double(requestedStartTimeTicks) / 10_000_000
                    return await self?.adaptiveFallbackRequest(
                        for: entry,
                        audioStreamIndex: runtimeAudioStreamIndex,
                        subtitleStreamIndex: runtimeSubtitleStreamIndex,
                        subtitleCodec: runtimeSubtitleCodec,
                        initialBitrate: compatibilityFallbackInitialBitrate,
                        sourceTraceID: playbackTraceID,
                        startTimeTicks: Self.jellyfinTicks(for: fallbackPositionSeconds),
                        runtimeState: runtimeState,
                        usesGreenfieldPlayback: usesGreenfieldPlayback
                    )
                }
            // Track changes must use the same negotiated request path for
            // original and transcoded playback. Re-opening the current source
            // with the live playhead prevents a direct-play selection from
            // updating only the VLC menu while the old stream keeps playing.
            let sourceTrackRequestLoader: ((Int?, Int?, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?) = {
                [weak self] audioStreamIndex, subtitleStreamIndex, runtimeState in
                guard let self else { return nil }
                do {
                    let replacement = try await self.playbackRequest(
                        for: entry,
                        selection: JellyfinPlaybackSelection(
                            audioStreamIndex: audioStreamIndex,
                            subtitleStreamIndex: subtitleStreamIndex
                        ),
                        forcedServerBitrate: prepared.playMethod == .transcode
                            ? maxBitrate
                            : nil,
                        forcedStartTimeTicks: runtimeState.positionSeconds.map {
                            Self.jellyfinTicks(for: $0)
                        },
                        forcedServerReason: "sourceTrackSwitch",
                        forcesExperimentalOriginalPlayback: forcesExperimentalOriginalPlayback,
                        usesGreenfieldPlayback: usesGreenfieldPlayback
                    )
                    return replacement?.applyingRuntimePreferences(runtimeState)
                } catch {
                    self.record(
                        "diagnostics.jellyfin.playback_failed",
                        level: .error,
                        details: self.diagnosticDetails(for: error).merging([
                            "stage": "sourceTrackSwitch",
                            "audioStreamIndex": audioStreamIndex.map(String.init) ?? "default",
                            "subtitleStreamIndex": subtitleStreamIndex.map(String.init) ?? "none"
                        ]) { current, _ in current }
                    )
                    return nil
                }
            }
            let serverSeekRequestLoader: ((Double, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?
            if prepared.playMethod == .transcode {
                serverSeekRequestLoader = { [weak self] targetSeconds, runtimeState in
                    guard let self else { return nil }
                    do {
                        let replacement = try await self.playbackRequest(
                            for: entry,
                            selection: JellyfinPlaybackSelection(
                                audioStreamIndex: selectedAudioStreamIndex,
                                subtitleStreamIndex: selectedSubtitleStreamIndex
                            ),
                            forcedServerBitrate: maxBitrate,
                            forcedStartTimeTicks: Self.jellyfinTicks(for: targetSeconds),
                            forcedServerReason: "serverSeek",
                            usesGreenfieldPlayback: usesGreenfieldPlayback
                        )
                        return replacement?.applyingRuntimePreferences(runtimeState)
                    } catch {
                        self.record(
                            "diagnostics.jellyfin.playback_failed",
                            level: .error,
                            details: self.diagnosticDetails(for: error).merging([
                                "stage": "serverSeek",
                                "targetSeconds": String(format: "%.1f", targetSeconds)
                            ]) { current, _ in current }
                        )
                        return nil
                    }
                }
            } else {
                serverSeekRequestLoader = nil
            }
            let qualityOptions = Self.videoQualityOptions(sourceBitrate: entry.mediaBitrate)
            let effectiveQualityID = selectedQualityID ?? "auto"
            let qualityRequestLoader: ((String, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?) = {
                [weak self] qualityID, runtimeState in
                guard let self else { return nil }
                let runtimeAudioStreamIndex = runtimeState.audioTrackOrdinal.flatMap { ordinal in
                    entry.audioTracks.indices.contains(ordinal) ? entry.audioTracks[ordinal].index : nil
                } ?? selectedAudioStreamIndex
                let runtimeSubtitleStreamIndex: Int?
                // Greenfield supplies the live source-menu selection, including
                // an explicit Off. The legacy engine still needs its sidecar
                // preservation rule because it reports that sidecar as disabled.
                if runtimeState.subtitlesDisabled,
                   runtimeState.subtitleSelectionKnown,
                   (!preservesServerSubtitleSelection || usesGreenfieldPlayback) {
                    runtimeSubtitleStreamIndex = nil
                } else {
                    runtimeSubtitleStreamIndex = runtimeState.subtitleTrackOrdinal.flatMap { ordinal in
                        entry.subtitleTracks.indices.contains(ordinal)
                            ? entry.subtitleTracks[ordinal].index
                            : nil
                    } ?? selectedSubtitleStreamIndex
                }
                let bitrate = Int(qualityID)
                do {
                    let replacement = try await self.playbackRequest(
                        for: entry,
                        selection: JellyfinPlaybackSelection(
                            audioStreamIndex: runtimeAudioStreamIndex,
                            subtitleStreamIndex: runtimeSubtitleStreamIndex
                        ),
                        forcedServerBitrate: bitrate,
                        forcedStartTimeTicks: runtimeState.positionSeconds.map(Self.jellyfinTicks(for:)),
                        forcedServerReason: "qualitySwitch",
                        forcesOriginalPlayback: qualityID == "original",
                        selectedQualityID: qualityID,
                        usesGreenfieldPlayback: usesGreenfieldPlayback
                    )
                    return replacement?.applyingRuntimePreferences(runtimeState)
                } catch {
                    self.record(
                        "diagnostics.jellyfin.playback_failed",
                        level: .error,
                        details: self.diagnosticDetails(for: error).merging([
                            "stage": "qualitySwitch",
                            "quality": qualityID
                        ]) { current, _ in current }
                    )
                    return nil
                }
            }
            let timelineOffsetSeconds = prepared.playMethod == .transcode
                ? Double(requestedStartTimeTicks) / 10_000_000
                : 0
            let totalDurationSeconds = entry.runTimeTicks.map { Double($0) / 10_000_000 }
            let usesExternalNormalizedSubtitle = prepared.playMethod == .directPlay
                && prepared.resource.subtitleURL != nil
            let disablesServerRenderedSubtitleForFastStartup = prepared.playMethod == .directPlay
                && defersServerRenderedSubtitleForFastStartup
            return MediaPlaybackRequest(
                requestedAt: requestedAt,
                url: prepared.resource.url,
                title: entry.title,
                allowsSelfSignedCertificates: prepared.allowsSelfSignedCertificates,
                source: .jellyfin,
                contentKind: .video,
                fileExtensionOverride: prepared.resource.fileExtensionOverride,
                initialPosition: prepared.playMethod == .transcode
                    ? nil
                    : forcedStartTimeTicks.map { min(max(Double($0) / Double(max(1, entry.runTimeTicks ?? 1)), 0), 1) }
                        ?? entry.effectivePlaybackProgress,
                externalSubtitleURL: prepared.resource.subtitleURL,
                // Jellyfin has already selected the requested source audio track for HLS.
                // Its single output track can receive a transient VLC identifier while the
                // playlist is opening, so selecting ordinal zero here can abort startup with
                // "Track identifier not found". Let VLC adopt that sole output track itself.
                preferredAudioTrackOrdinal: prepared.playMethod == .transcode
                    ? nil
                    : selectedAudioTrackOrdinal,
                preferredSubtitleTrackOrdinal: prepared.playMethod == .transcode
                    || disablesServerRenderedSubtitleForFastStartup
                    ? nil
                    : selectedSubtitleTrackOrdinal,
                // When Jellyfin supplies a normalized SRT for an ASS/SSA
                // source, disable the embedded styled track first. VLC then
                // renders only the external text track, avoiding tofu boxes
                // and duplicate subtitle lines.
                prefersSubtitlesDisabled: selectedSubtitleStreamIndex == nil
                    || disablesServerRenderedSubtitleForFastStartup
                    || usesExternalNormalizedSubtitle,
                timelineOffsetSeconds: timelineOffsetSeconds,
                totalDurationSeconds: totalDurationSeconds,
                byteLength: entry.mediaSize.map(Int64.init),
                estimatedBitrate: entry.mediaBitrate,
                streamBitrateCeiling: prepared.playMethod == .transcode ? maxBitrate : nil,
                isPrivateNetworkRoute: prepared.isPrivateNetworkRoute,
                playbackTracker: playbackTracker,
                externalHandoffResource: prepared.externalHandoffResource,
                compatibilityFallbackRequestLoader: compatibilityFallbackRequestLoader,
                sourceAudioTracks: entry.audioTracks.map {
                    MediaPlaybackSourceTrack(id: $0.index, name: $0.title)
                },
                sourceSubtitleTracks: entry.subtitleTracks.map { track in
                    MediaPlaybackSourceTrack(
                        id: track.index,
                        name: track.title,
                        externalURL: Self.requiresBurnIn(subtitleCodec: track.codec)
                            ? nil
                            : externalSubtitleURL(
                                for: entry,
                                subtitleStreamIndex: track.index,
                                client: client
                            )
                    )
                },
                selectedSourceAudioTrackID: selectedAudioStreamIndex,
                selectedSourceSubtitleTrackID: disablesServerRenderedSubtitleForFastStartup
                    ? nil
                    : selectedSubtitleStreamIndex,
                sourceTrackRequestLoader: sourceTrackRequestLoader,
                serverSeekRequestLoader: serverSeekRequestLoader,
                qualityOptions: qualityOptions,
                selectedQualityID: effectiveQualityID,
                qualityRequestLoader: qualityRequestLoader,
                playbackTraceID: playbackTraceID,
                episodeNavigationLoader: usesGreenfieldPlayback && entry.kind == .episode ? { [weak self] in
                    guard let self, let seriesID = entry.seriesID,
                          let episodes = try? await self.loadEpisodes(seriesID: seriesID),
                          let index = episodes.firstIndex(where: { $0.id == entry.id }) else { return nil }
                    func loader(at index: Int) -> (() async -> MediaPlaybackRequest?)? {
                        guard episodes.indices.contains(index) else { return nil }
                        let episode = episodes[index]
                        return { [weak self] in
                            guard let self else { return nil }
                            return try? await self.playbackRequest(for: episode,
                                forcedStartTimeTicks: 0, usesGreenfieldPlayback: usesGreenfieldPlayback)
                        }
                    }
                    return MediaPlaybackEpisodeNavigation(previous: loader(at: index - 1), next: loader(at: index + 1))
                } : nil
            )
        } catch {
            record(
                "diagnostics.jellyfin.playback_failed",
                level: .error,
                details: diagnosticDetails(for: error)
            )
            throw error
        }
    }

    private static func videoQualityOptions(sourceBitrate: Int?) -> [MediaPlaybackQualityOption] {
        var options = [
            MediaPlaybackQualityOption(
                id: "auto",
                title: NSLocalizedString("player.quality.auto", comment: ""),
                detail: NSLocalizedString("player.quality.auto.detail", comment: "")
            ),
            MediaPlaybackQualityOption(
                id: "original",
                title: NSLocalizedString("player.quality.original", comment: ""),
                detail: sourceBitrate.map { Self.bitrateLabel($0) }
            )
        ]
        let bitrates = [30_000_000, 20_000_000, 12_000_000,
                        10_000_000, 8_000_000, 4_000_000, 2_000_000]
        options.append(contentsOf: bitrates.map { bitrate in
            MediaPlaybackQualityOption(
                id: String(bitrate),
                title: Self.qualityTitle(for: bitrate),
                detail: Self.bitrateLabel(bitrate)
            )
        })
        return options
    }

    private static func qualityTitle(for bitrate: Int) -> String {
        switch bitrate {
        case 25_000_000...: return "4K"
        case 10_000_000...: return "1080p"
        case 5_000_000...: return "720p"
        default: return "480p"
        }
    }

    private static func bitrateLabel(_ bitrate: Int) -> String {
        String(format: "%.0f Mbps", Double(bitrate) / 1_000_000)
    }

    private func adaptiveFallbackRequest(
        for entry: JellyfinMediaEntry,
        audioStreamIndex: Int?,
        subtitleStreamIndex: Int?,
        subtitleCodec: String?,
        initialBitrate: Int,
        sourceTraceID: String,
        startTimeTicks: Int?,
        runtimeState: MediaPlaybackRuntimeState?,
        usesGreenfieldPlayback: Bool
    ) async -> MediaPlaybackRequest? {
        guard client != nil else { return nil }
        let network = PlaybackNetworkObserver.shared.snapshot()
        let observedCapacity = PlaybackRecentThroughputStore.shared.estimate(
            traceID: sourceTraceID, now: ProcessInfo.processInfo.systemUptime)
        let route = playbackEndpoint ?? endpoint
        let origin = Self.originURL(for: route)?.absoluteString ?? route.absoluteString
        let measuredCapacity = bitrateMeasurements["\(origin)|\(network.cacheKey)"].flatMap {
            sample -> Int? in
            sample.wasMeasured && Date().timeIntervalSince(sample.measuredAt) < 120
                ? sample.rawBitrate : nil
        }
        let capacity = [observedCapacity, measuredCapacity].compactMap { $0 }.min()
        guard let fallbackBitrate = PlaybackAdaptiveBitratePolicy.target(
            currentCeiling: initialBitrate, capacity: capacity,
            networkKey: network.cacheKey) else { return nil }
        do {
            let replacement = try await playbackRequest(
                for: entry,
                selection: JellyfinPlaybackSelection(
                    audioStreamIndex: audioStreamIndex,
                    subtitleStreamIndex: subtitleStreamIndex
                ),
                forcedServerBitrate: fallbackBitrate,
                forcedStartTimeTicks: startTimeTicks,
                forcedServerReason: "bitrateFallback",
                usesGreenfieldPlayback: usesGreenfieldPlayback
            )
            guard let replacement else { return nil }
            record(
                "diagnostics.jellyfin.playback_downshifted",
                level: .warning,
                details: [
                    "fromBitrate": "\(initialBitrate)",
                    "toBitrate": "\(fallbackBitrate)",
                    "capacityBitrate": capacity.map(String.init) ?? "unknown",
                    "capacityBasis": observedCapacity != nil ? "recentTransfer" :
                        (measuredCapacity != nil ? "recentJellyfinProbe" : "conservativeFallback"),
                    "playbackTraceID": replacement.playbackTraceID ?? "-",
                    "network": network.cacheKey,
                    "mode": "serverNegotiatedHLS",
                    "subtitleCodec": subtitleCodec ?? "-"
                ]
            )
            return runtimeState.map { replacement.applyingRuntimePreferences($0) } ?? replacement
        } catch {
            record(
                "diagnostics.jellyfin.playback_downshift_failed",
                level: .error,
                details: diagnosticDetails(for: error).merging([
                    "fromBitrate": "\(initialBitrate)",
                    "toBitrate": "\(fallbackBitrate)",
                    "playbackTraceID": "-",
                    "network": network.cacheKey
                ]) { current, _ in current }
            )
            return nil
        }
    }

    func externalPlaybackRequest(
        for entry: JellyfinMediaEntry,
        selection: JellyfinPlaybackSelection? = nil
    ) async throws -> MediaPlaybackRequest? {
        guard let prepared = try await playbackRequest(for: entry, selection: selection) else {
            return nil
        }
        let resource = prepared.externalHandoffResource ?? MediaPlaybackResource(
            url: prepared.url,
            fileExtensionOverride: prepared.fileExtensionOverride,
            subtitleURL: prepared.externalSubtitleURL
        )
        return MediaPlaybackRequest(
            requestedAt: prepared.requestedAt,
            url: resource.url,
            title: entry.title,
            allowsSelfSignedCertificates: requiresCertificateBypass(for: resource.url),
            source: .jellyfin,
            fileExtensionOverride: resource.fileExtensionOverride,
            initialPosition: entry.effectivePlaybackProgress,
            externalSubtitleURL: resource.subtitleURL,
            preferredAudioTrackOrdinal: prepared.preferredAudioTrackOrdinal,
            preferredSubtitleTrackOrdinal: prepared.preferredSubtitleTrackOrdinal,
            prefersSubtitlesDisabled: prepared.prefersSubtitlesDisabled,
            initialOrientationMode: prepared.initialOrientationMode,
            initialPlaybackRate: prepared.initialPlaybackRate,
            isPrivateNetworkRoute: prepared.isPrivateNetworkRoute,
            playbackTraceID: prepared.playbackTraceID
        )
    }

    private func negotiatedVideoPlayback(
        for entry: JellyfinMediaEntry,
        audioStreamIndex: Int?,
        subtitleStreamIndex: Int?,
        subtitleCodec: String?,
        client: JellyfinClient,
        maxStreamingBitrate: Int,
        allowsDirectPlay: Bool,
        startTimeTicks: Int?,
        requestedAt: Date,
        playbackTraceID: String?,
        usesGreenfieldPlayback: Bool,
        prewarmsCellularVOD: Bool
    ) async throws -> JellyfinPreparedPlayback {
        let usesExternalTextSubtitle = usesGreenfieldPlayback && subtitleStreamIndex != nil
            && !Self.requiresBurnIn(subtitleCodec: subtitleCodec)
        let requestBody = PlaybackInfoDto(
            allowAudioStreamCopy: false,
            allowVideoStreamCopy: false,
            audioStreamIndex: audioStreamIndex,
            deviceProfile: Self.vlcPlaybackProfile(
                maxBitrate: maxStreamingBitrate,
                hlsSegmentContainer: usesGreenfieldPlayback ? "ts" : "mp4"
            ),
            enableDirectPlay: allowsDirectPlay,
            // Public routes must stay on Jellyfin's segmented HLS path. A
            // direct-stream/remux response can still be a long-lived raw
            // connection and defeats the cellular startup policy.
            enableDirectStream: playbackRouteIsPrivate,
            enableTranscoding: true,
            // Greenfield renders normalized text subtitles in its CJK overlay.
            // Only image subtitles and the legacy renderer need server burn-in.
            isAlwaysBurnInSubtitleWhenTranscoding: subtitleStreamIndex != nil && !usesExternalTextSubtitle,
            maxStreamingBitrate: maxStreamingBitrate,
            mediaSourceID: entry.mediaSourceID,
            startTimeTicks: startTimeTicks,
            subtitleStreamIndex: usesExternalTextSubtitle ? nil : subtitleStreamIndex,
            userID: userID
        )
        let response = try await client.send(
            Paths.getPostedPlaybackInfo(
                itemID: entry.id,
                parameters: nil,
                requestBody
            )
        ).value
        let mediaSource = response.mediaSources?.first(where: { source in
            source.id == entry.mediaSourceID
        }) ?? response.mediaSources?.first
        guard let mediaSource else {
            throw JellyfinLibraryError.missingPlaybackURL
        }
        let streamURL: URL
        let extensionHint: String
        let playMethod: PlayMethod
        let mode: String
        if let transcodingPath = mediaSource.transcodingURL,
           let transcodingURL = authenticatedJellyfinURL(path: transcodingPath, client: client) {
            streamURL = transcodingURL
            extensionHint = mediaSource.transcodingSubProtocol == .hls
                ? "m3u8"
                : Self.firstContainer(mediaSource.transcodingContainer) ?? "mp4"
            playMethod = .transcode
            mode = mediaSource.transcodingSubProtocol == .hls
                ? "serverNegotiatedHLS"
                : "serverNegotiatedTranscode"
        } else {
            guard let directURL = negotiatedDirectURL(
                for: entry,
                mediaSource: mediaSource,
                playSessionID: response.playSessionID,
                client: client
            ) else {
                throw JellyfinLibraryError.missingPlaybackURL
            }
            streamURL = directURL
            extensionHint = Self.firstContainer(mediaSource.container)
                ?? Self.firstContainer(entry.container)
                ?? "mp4"
            playMethod = .directPlay
            mode = "serverNegotiatedDirectPlay"
        }
        // AVPlayer must be able to request every child playlist/segment with
        // the Jellyfin credentials. A plain authenticated m3u8 URL is not
        // sufficient on cellular routes because AVPlayer does not inherit the
        // client's X-Emby-Token header for child requests. The local proxy
        // rewrites child URIs and forwards the authenticated requests while
        // keeping external handoff on the original server URL.
        let internalStreamURL: URL
        if playMethod == .transcode,
           extensionHint == "m3u8" {
            internalStreamURL = (try? await AuthenticatedMediaStreamProxy.shared.register(
                upstreamURL: streamURL,
                filename: entry.title + ".m3u8",
                allowsSelfSignedCertificates: requiresCertificateBypass(for: streamURL),
                playbackTraceID: playbackTraceID
            )) ?? streamURL
        } else {
            internalStreamURL = streamURL
        }
        if prewarmsCellularVOD, usesGreenfieldPlayback, playMethod == .transcode,
           extensionHint == "m3u8", internalStreamURL.host == "127.0.0.1",
           PlaybackNetworkObserver.shared.snapshot().cacheKey == "cellular",
           entry.kind == .movie || entry.kind == .episode {
            let started = ProcessInfo.processInfo.systemUptime
            do {
                let warmed = try await AuthenticatedMediaStreamProxy.shared.prewarmVODPlaylist(internalStreamURL)
                try Task.checkCancellation()
                record("diagnostics.jellyfin.playback_preparing", level: .info, details: [
                    "stage": "cellularVODPlaylistPrewarm", "result": warmed ? "cachedVOD" : "notCacheable",
                    "elapsedMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)),
                    "playbackTraceID": playbackTraceID ?? "-", "network": "cellular"
                ])
            } catch {
                AuthenticatedMediaStreamProxy.shared.unregister(internalStreamURL)
                throw error
            }
        }
        let externalHandoffResource = MediaPlaybackResource(
            url: streamURL,
            fileExtensionOverride: extensionHint,
            subtitleURL: Self.requiresBurnIn(subtitleCodec: subtitleCodec)
                ? nil
                : externalSubtitleURL(
                    for: entry,
                    subtitleStreamIndex: subtitleStreamIndex,
                    client: client
                )
        )
        let resource: MediaPlaybackResource
        if playMethod == .directPlay {
            resource = MediaPlaybackResource(
                url: internalStreamURL,
                fileExtensionOverride: extensionHint,
                // Keep direct-play subtitle behavior identical to the
                // handoff path: text tracks use Jellyfin's normalized SRT,
                // image tracks stay on the server burn-in path.
                subtitleURL: externalHandoffResource.subtitleURL,
                allowsSelfSignedCertificates: requiresCertificateBypass(for: streamURL)
            )
        } else {
            resource = MediaPlaybackResource(
                url: internalStreamURL,
                fileExtensionOverride: extensionHint,
                // Preserve the source subtitle choice without forcing video
                // re-encoding through the server's subtitle filter.
                subtitleURL: usesExternalTextSubtitle ? externalHandoffResource.subtitleURL : nil,
                allowsSelfSignedCertificates: false
            )
        }
        record(
            "diagnostics.jellyfin.playback_prepared",
            level: .info,
            details: [
                "mode": mode,
                "playbackTraceID": playbackTraceID ?? "-",
                "container": extensionHint,
                "playSession": response.playSessionID == nil ? "missing" : "present",
                "subtitleCodec": subtitleCodec ?? "-",
                "subtitleStreamIndex": subtitleStreamIndex.map(String.init) ?? "none",
                "audioStreamIndex": audioStreamIndex.map(String.init) ?? "default",
                "startTimeTicks": startTimeTicks.map(String.init) ?? "0",
                "maxBitrate": "\(maxStreamingBitrate)",
                "directPlay": allowsDirectPlay ? "allowed" : "disabled",
                "sourceBitrate": mediaSource.bitrate.map(String.init) ?? "-",
                // The selected ceiling and source bitrate do not establish
                // whether Jellyfin actually encoded or copied the video.
                // Record only allowlisted negotiation fields, never the URL.
                "negotiatedVideoCodec": URLComponents(url: streamURL, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name.caseInsensitiveCompare("VideoCodec") == .orderedSame })?.value ?? "-",
                "negotiatedVideoBitrate": URLComponents(url: streamURL, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name.caseInsensitiveCompare("VideoBitrate") == .orderedSame })?.value ?? "-",
                "negotiatedAudioCodec": URLComponents(url: streamURL, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name.caseInsensitiveCompare("AudioCodec") == .orderedSame })?.value ?? "-",
                "transport": resource.url.host == "127.0.0.1"
                    ? "localHLSProxy"
                    : resource.url.scheme?.lowercased() ?? "serverURL",
                "prepareMs": Self.elapsedMilliseconds(since: requestedAt)
            ]
        )
        return JellyfinPreparedPlayback(
            resource: resource,
            externalHandoffResource: externalHandoffResource,
            playSessionID: response.playSessionID,
            mediaSourceID: mediaSource.id,
            playMethod: playMethod,
            mode: mode,
            isPrivateNetworkRoute: playbackRouteIsPrivate,
            allowsSelfSignedCertificates: requiresCertificateBypass(for: resource.url),
            playbackTraceID: playbackTraceID
        )
    }

    private var playbackRouteIsPrivate: Bool {
        resolvedPlaybackRouteIsPrivate
            ?? NetworkHostClassifier.isPrivate((playbackEndpoint ?? endpoint).host)
    }

    private func refreshPlaybackRouteClassification() async {
        let isPrivate = NetworkHostClassifier.isPrivate((playbackEndpoint ?? endpoint).host)
        resolvedPlaybackRouteIsPrivate = isPrivate
        if isPrivate {
            bitrateMeasurementTasks.values.forEach { $0.cancel() }
            bitrateMeasurementTasks.removeAll()
        }
    }

    private func playbackBitrateDecision(originalSourceBitrate: Int? = nil,
                                         usesGreenfieldPlayback: Bool = false) -> JellyfinPlaybackBitrateDecision {
        let route = playbackEndpoint ?? endpoint
        let network = PlaybackNetworkObserver.shared.snapshot()
        if playbackRouteIsPrivate {
            return JellyfinPlaybackBitrateDecision(
                maximumBitrate: 360_000_000,
                directPlayMaximumBitrate: 360_000_000,
                isPrivateRoute: true,
                basis: "privateRoute",
                networkKey: network.cacheKey
            )
        }
        let originKey = Self.originURL(for: route)?.absoluteString ?? route.absoluteString
        let cacheKey = "\(originKey)|\(network.cacheKey)"
        if let cached = bitrateMeasurements[cacheKey],
           GreenfieldBandwidthSamplePolicy.canReuse(age: Date().timeIntervalSince(cached.measuredAt),
               networkKey: network.cacheKey, wasMeasured: cached.wasMeasured,
               safeBitrate: cached.bitrate, originalSourceBitrate: originalSourceBitrate,
               rawBitrate: cached.rawBitrate) {
            // Greenfield compares original bitrate with measured delivery
            // capacity. Legacy retains its previous capped burst allowance.
            // HLS keeps the separate conservative encoder budget in both cases.
            let directPlayMaximumBitrate: Int
            if usesGreenfieldPlayback {
                directPlayMaximumBitrate = GreenfieldOriginalPlaybackPolicy.maximumOriginalBitrate(
                    networkKey: network.cacheKey, wasMeasured: cached.wasMeasured,
                    rawBitrate: cached.rawBitrate, conservativeBitrate: cached.bitrate)
            } else if network.cacheKey == "wifi" {
                directPlayMaximumBitrate = min(
                    max(Int(Double(cached.rawBitrate) * 1.25), cached.bitrate),
                    network.bitrateCap ?? 80_000_000
                )
            } else {
                directPlayMaximumBitrate = cached.bitrate
            }
            return JellyfinPlaybackBitrateDecision(
                maximumBitrate: cached.bitrate,
                directPlayMaximumBitrate: directPlayMaximumBitrate,
                isPrivateRoute: false,
                basis: cached.wasMeasured ? "measured" : "measurementFailed",
                networkKey: network.cacheKey
            )
        }
        // Initial Auto playback awaits the route probe. If no fresh sample is
        // available here, keep the decision conservative so public Wi-Fi does
        // not mistake the adapter cap for measured WAN throughput.
        let fallbackBitrate = min(
            network.bitrateCap ?? network.fallbackBitrate,
            network.fallbackBitrate
        )
        return JellyfinPlaybackBitrateDecision(
            maximumBitrate: fallbackBitrate,
            directPlayMaximumBitrate: fallbackBitrate,
            isPrivateRoute: false,
            basis: "networkFallback",
            networkKey: network.cacheKey
        )
    }

    private func scheduleBitrateMeasurementIfNeeded(client: JellyfinClient, originalSourceBitrate: Int? = nil,
                                                    networkSnapshot: PlaybackNetworkSnapshot? = nil) {
        let route = playbackEndpoint ?? endpoint
        guard !playbackRouteIsPrivate else { return }
        let network = networkSnapshot ?? PlaybackNetworkObserver.shared.snapshot()
        let originKey = Self.originURL(for: route)?.absoluteString ?? route.absoluteString
        let cacheKey = "\(originKey)|\(network.cacheKey)"
        if let cached = bitrateMeasurements[cacheKey],
           GreenfieldBandwidthSamplePolicy.canReuse(age: Date().timeIntervalSince(cached.measuredAt),
               networkKey: network.cacheKey, wasMeasured: cached.wasMeasured,
               safeBitrate: cached.bitrate, originalSourceBitrate: originalSourceBitrate,
               rawBitrate: cached.rawBitrate) {
            return
        }
        guard bitrateMeasurementTasks[cacheKey] == nil else { return }
        bitrateMeasurementTasks[cacheKey] = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.measureMaximumBitrate(
                client: client,
                network: network,
                cacheKey: cacheKey
            )
            self.bitrateMeasurementTasks[cacheKey] = nil
        }
    }

    private func ensureBitrateMeasurementIfNeeded(client: JellyfinClient, maximumWait: TimeInterval? = nil,
                                                 originalSourceBitrate: Int? = nil) async {
        let route = playbackEndpoint ?? endpoint
        guard !playbackRouteIsPrivate else { return }
        let network = PlaybackNetworkObserver.shared.snapshot()
        let originKey = Self.originURL(for: route)?.absoluteString ?? route.absoluteString
        let cacheKey = "\(originKey)|\(network.cacheKey)"
        if let cached = bitrateMeasurements[cacheKey],
           GreenfieldBandwidthSamplePolicy.canReuse(age: Date().timeIntervalSince(cached.measuredAt),
               networkKey: network.cacheKey, wasMeasured: cached.wasMeasured,
               safeBitrate: cached.bitrate, originalSourceBitrate: originalSourceBitrate,
               rawBitrate: cached.rawBitrate) {
            return
        }
        // Re-reading NWPath here can schedule a Wi-Fi task while this function
        // waits on the old "unknown" key, reporting completed after zero ms.
        scheduleBitrateMeasurementIfNeeded(client: client, originalSourceBitrate: originalSourceBitrate,
            networkSnapshot: network)
        if let maximumWait {
            // The shared measurement continues for later decisions. A slow
            // probe must not hold the first frame behind its network timeout.
            let started = ProcessInfo.processInfo.systemUptime
            while bitrateMeasurementTasks[cacheKey] != nil,
                  ProcessInfo.processInfo.systemUptime - started < maximumWait,
                  !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            record("diagnostics.jellyfin.playback_preparing", level: .info, details: [
                "stage": "bandwidthWait", "waitMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)),
                "network": network.cacheKey,
                "measurement": bitrateMeasurementTasks[cacheKey] == nil ? "completed" : "continuingInBackground"
            ])
            return
        }
        let task = bitrateMeasurementTasks[cacheKey]
        await task?.value
    }

    private func measureMaximumBitrate(
        client: JellyfinClient,
        network: PlaybackNetworkSnapshot,
        cacheKey: String
    ) async {
        let testSize: Int
        switch network.cacheKey {
        case "wifi": testSize = 4 * 1024 * 1024
        case "cellular": testSize = 1024 * 1024
        default: testSize = 512 * 1024
        }
        let startedAt = Date()
        do {
            let data = try await client.send(Paths.getBitrateTestBytes(size: testSize)).value
            guard !data.isEmpty else { throw URLError(.zeroByteResource) }
            let elapsed = max(Date().timeIntervalSince(startedAt), 0.05)
            let measured = Double(data.count * 8) / elapsed
            let measuredSafeBitrate = max(Int(measured * 0.80), 1_500_000)
            let safeBitrate = min(measuredSafeBitrate, network.bitrateCap ?? 80_000_000)
            bitrateMeasurements[cacheKey] = (safeBitrate, Int(measured), Date(), true)
            record(
                "diagnostics.jellyfin.bitrate_measured",
                level: .info,
                details: [
                    "measuredBitrate": "\(Int(measured))",
                    "selectedBitrate": "\(safeBitrate)",
                    "durationMs": Self.elapsedMilliseconds(since: startedAt),
                    "sampleBytes": "\(data.count)",
                    "network": network.cacheKey
                ]
            )
        } catch {
            guard !Task.isCancelled else { return }
            let fallbackBitrate = min(
                network.bitrateCap ?? network.fallbackBitrate,
                network.fallbackBitrate
            )
            bitrateMeasurements[cacheKey] = (fallbackBitrate, fallbackBitrate, Date(), false)
            record(
                "diagnostics.jellyfin.bitrate_measured",
                level: .warning,
                details: diagnosticDetails(for: error).merging([
                    "selectedBitrate": "\(fallbackBitrate)",
                    "mode": "fallback",
                    "network": network.cacheKey
                ]) { current, _ in current }
            )
        }
    }

    private func negotiatedDirectURL(
        for entry: JellyfinMediaEntry,
        mediaSource: MediaSourceInfo,
        playSessionID: String?,
        client: JellyfinClient
    ) -> URL? {
        guard let container = Self.firstContainer(mediaSource.container)
            ?? Self.firstContainer(entry.container) else { return nil }
        var parameters = Paths.GetVideoStreamByContainerParameters()
        parameters.isStatic = true
        parameters.tag = mediaSource.eTag
        parameters.playSessionID = playSessionID
        parameters.mediaSourceID = mediaSource.id ?? entry.mediaSourceID
        return client.url(
            with: Paths.getVideoStreamByContainer(
                itemID: entry.id,
                container: container,
                parameters: parameters
            ),
            queryAPIKey: true
        ).map(preferredPlaybackURL)
    }

    private func originalVideoPlaybackURLs(
        for entry: JellyfinMediaEntry,
        client: JellyfinClient
    ) -> [URL] {
        guard let container = Self.firstContainer(entry.container) else { return [] }
        var parameters = Paths.GetVideoStreamByContainerParameters()
        parameters.isStatic = true
        parameters.mediaSourceID = entry.mediaSourceID
        guard let serverURL = client.url(
            with: Paths.getVideoStreamByContainer(
                itemID: entry.id,
                container: container,
                parameters: parameters
            ),
            queryAPIKey: true
        ) else {
            return []
        }
        var result: [URL] = []
        var seen = Set<String>()
        for candidate in [preferredPlaybackURL(serverURL), serverURL] {
            if seen.insert(candidate.absoluteString).inserted {
                result.append(candidate)
            }
        }
        return result
    }

    private func preferredOriginalPlaybackRoute(
        for entry: JellyfinMediaEntry,
        client: JellyfinClient,
        usesGreenfieldPlayback: Bool = false,
        playbackTraceID: String? = nil,
        originalProbeTask: Task<URL?, Never>? = nil
    ) async -> JellyfinDirectPlaybackRoute? {
        guard !Task.isCancelled else { return nil }
        let originalURL: URL?
        if let originalProbeTask {
            originalURL = await withTaskCancellationHandler {
                await originalProbeTask.value
            } onCancel: {
                originalProbeTask.cancel()
            }
        } else {
            originalURL = await probeJellyfinOriginalURL(for: entry, client: client,
                playbackTraceID: playbackTraceID)
        }
        guard !Task.isCancelled else { return nil }
        if let url = originalURL {
            let requiresLocalProxy = requiresCertificateBypass(for: url)
            let playbackURL = await preferredDirectPlaybackURL(
                    url,
                    filename: entry.title,
                    allowsSelfSignedCertificates: requiresLocalProxy,
                    usesGreenfieldPlayback: usesGreenfieldPlayback,
                    playbackTraceID: playbackTraceID
                )
                return JellyfinDirectPlaybackRoute(
                    url: playbackURL,
                handoffURL: url,
                source: "jellyfinOriginal",
                allowsSelfSignedCertificates: requiresLocalProxy,
                isPrivateNetworkRoute: NetworkHostClassifier.isPrivate(url.host)
            )
        }

        if let dsmSession,
           let mediaPath = entry.mediaPath,
           !shouldSkipDSMPlaybackPath(mediaPath) {
            let candidates = dsmOriginalVideoPlaybackURLs(
                mediaPath: mediaPath,
                session: dsmSession
            )
            if !candidates.isEmpty,
               let url = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
                   candidates: candidates,
                   allowsSelfSignedCertificates: dsmSession.allowsSelfSignedCertificates,
                   diagnosticStage: "jellyfinDSMRange",
                   timeout: 3,
                   expectedContentLength: entry.mediaSize
               ) {
                unavailableDSMPlaybackPaths.removeValue(forKey: mediaPath)
                let playbackURL = await preferredDirectPlaybackURL(
                        url,
                        filename: entry.title,
                        allowsSelfSignedCertificates: dsmSession.allowsSelfSignedCertificates,
                        usesGreenfieldPlayback: usesGreenfieldPlayback,
                        playbackTraceID: playbackTraceID
                    )
                return JellyfinDirectPlaybackRoute(
                    url: playbackURL,
                    handoffURL: url,
                    source: "dsmFileStation",
                    allowsSelfSignedCertificates: dsmSession.allowsSelfSignedCertificates,
                    isPrivateNetworkRoute: NetworkHostClassifier.isPrivate(url.host)
                )
            }
            unavailableDSMPlaybackPaths[mediaPath] = Date()
            record(
                "diagnostics.jellyfin.playback_preparing",
                level: .warning,
                details: [
                    "mode": "dsmPathUnavailable",
                    "fallback": "serverHLS",
                    "candidateCount": "\(candidates.count)"
                ]
            )
        }
        return nil
    }

    private func probeJellyfinOriginalURL(
        for entry: JellyfinMediaEntry, client: JellyfinClient,
        playbackTraceID: String?, overlapsBandwidth: Bool = false
    ) async -> URL? {
        guard !Task.isCancelled else { return nil }
        let started = ProcessInfo.processInfo.systemUptime
        let url = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
            candidates: originalVideoPlaybackURLs(for: entry, client: client),
            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            diagnosticStage: "jellyfinRange", timeout: 4,
            expectedContentLength: entry.mediaSize)
        guard !Task.isCancelled else { return nil }
        record("diagnostics.jellyfin.playback_preparing", level: .info, details: [
            "stage": "originalRouteProbe",
            "probeMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)),
            "overlapsBandwidth": String(overlapsBandwidth),
            "result": url == nil ? "unavailable" : "available",
            "playbackTraceID": playbackTraceID ?? "-"
        ])
        return url
    }

    private func dsmOriginalVideoPlaybackURLs(
        mediaPath: String,
        session: DSMSession
    ) -> [URL] {
        var result: [URL] = []
        var seen = Set<String>()
        for path in Self.dsmFileStationPathCandidates(
            mediaPath,
            sharedFolderPaths: dsmSharedFolderPaths
        ) {
            for url in session.fileStationOpenURLs(path: path)
            where seen.insert(url.absoluteString).inserted {
                result.append(url)
            }
        }
        return result
    }

    private func preferredDirectPlaybackURL(
        _ url: URL,
        filename: String,
        allowsSelfSignedCertificates: Bool,
        usesGreenfieldPlayback: Bool = false,
        playbackTraceID: String? = nil
    ) async -> URL {
        let needsCertificateProxy = url.scheme?.lowercased() == "https"
            && allowsSelfSignedCertificates
        if usesGreenfieldPlayback {
            return (try? await AuthenticatedMediaStreamProxy.shared.registerOriginalStream(
                upstreamURL: url, filename: filename,
                allowsSelfSignedCertificates: allowsSelfSignedCertificates,
                playbackTraceID: playbackTraceID)) ?? url
        }
        guard needsCertificateProxy
                || !NetworkHostClassifier.isPrivate(url.host) else { return url }
        return (try? await AuthenticatedMediaStreamProxy.shared.register(
            upstreamURL: url,
            filename: filename,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            playbackTraceID: playbackTraceID
        )) ?? url
    }

    private func shouldSkipDSMPlaybackPath(_ mediaPath: String) -> Bool {
        guard let failedAt = unavailableDSMPlaybackPaths[mediaPath] else { return false }
        if Date().timeIntervalSince(failedAt) < 5 * 60 {
            return true
        }
        unavailableDSMPlaybackPaths.removeValue(forKey: mediaPath)
        return false
    }

    private static func dsmFileStationPathCandidates(
        _ mediaPath: String,
        sharedFolderPaths: [String]
    ) -> [String] {
        let normalized = mediaPath
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.hasPrefix("/") else { return [] }

        var result: [String] = []
        var seen = Set<String>()
        func append(_ path: String) {
            let cleaned = path.replacingOccurrences(of: "//", with: "/")
            guard cleaned.hasPrefix("/"), seen.insert(cleaned).inserted else { return }
            result.append(cleaned)
        }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: true)
        let isVolumePath: Bool
        if let volume = components.first?.lowercased(),
           volume.hasPrefix("volume"),
           !volume.dropFirst("volume".count).isEmpty,
           volume.dropFirst("volume".count).allSatisfy(\.isNumber),
           components.count > 1 {
            append("/" + components.dropFirst().joined(separator: "/"))
            isVolumePath = true
        } else {
            isVolumePath = false
        }
        append(normalized)
        guard !isVolumePath, components.count > 1 else { return result }

        let sharedRoots = sharedFolderPaths.compactMap { path -> String? in
            let normalizedShare = path
                .replacingOccurrences(of: "\\", with: "/")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedShare.hasPrefix("/") else { return nil }
            let shareComponents = normalizedShare.split(separator: "/", omittingEmptySubsequences: true)
            if let first = shareComponents.first?.lowercased(),
               first.hasPrefix("volume"),
               !first.dropFirst("volume".count).isEmpty,
               first.dropFirst("volume".count).allSatisfy(\.isNumber),
               shareComponents.count > 1 {
                return "/" + shareComponents.dropFirst().joined(separator: "/")
            }
            return normalizedShare
        }
        for sharedRoot in sharedRoots {
            let sharedName = sharedRoot.split(separator: "/").last?.lowercased()
            if let sharedName,
               let matchingIndex = components.firstIndex(where: {
                   $0.lowercased() == sharedName
               }) {
                let suffix = components.dropFirst(matchingIndex + 1).joined(separator: "/")
                append(suffix.isEmpty ? sharedRoot : "\(sharedRoot)/\(suffix)")
            }
            append("\(sharedRoot)/\(components.dropFirst().joined(separator: "/"))")
        }

        let commonContainerRoots: Set<String> = [
            "data", "media", "mnt", "movie", "movies", "storage", "tv", "video", "videos"
        ]
        if components.count > 2,
           let first = components.first?.lowercased(),
           commonContainerRoots.contains(first) {
            for sharedRoot in sharedRoots {
                append("\(sharedRoot)/\(components.dropFirst(2).joined(separator: "/"))")
            }
        }
        return result
    }

    private func externalSubtitleURL(
        for entry: JellyfinMediaEntry,
        subtitleStreamIndex: Int?,
        client: JellyfinClient
    ) -> URL? {
        guard
            let mediaSourceID = entry.mediaSourceID,
            let subtitleIndex = subtitleStreamIndex,
            let url = client.url(
                with: Paths.getSubtitle(
                    routeItemID: entry.id,
                    routeMediaSourceID: mediaSourceID,
                    routeIndex: subtitleIndex,
                    routeFormat: "srt"
                ),
                queryAPIKey: true
            )
        else {
            return nil
        }
        return preferredPlaybackURL(url)
    }

    private static func directPlayableStartupAudioTrack(
        in entry: JellyfinMediaEntry,
        selectedAudioStreamIndex: Int?,
        usesGreenfieldPlayback: Bool = false
    ) -> JellyfinMediaTrack? {
        guard
            let selectedAudioStreamIndex,
            let selectedTrack = entry.audioTracks.first(where: { $0.index == selectedAudioStreamIndex }),
            // Keep the user's/default track when the active engine can decode
            // it, including TrueHD and iPad FLAC under KSPlayer.
            !usesGreenfieldPlayback,
            requiresPlaybackAudioTranscode(audioCodec: selectedTrack.codec,
                usesGreenfieldPlayback: usesGreenfieldPlayback)
        else {
            return nil
        }

        let candidates = entry.audioTracks.filter { track in
            !requiresAudioTranscode(audioCodec: track.codec)
                && !requiresDeviceCompatibilityTranscode(audioCodec: track.codec)
        }
        guard !candidates.isEmpty else { return nil }
        return candidates.first(where: \.isDefault) ?? candidates.first
    }

    private static func requiresBurnIn(subtitleCodec: String?) -> Bool {
        guard let subtitleCodec = subtitleCodec?.lowercased() else { return false }
        return [
            "dvbsub", "dvb_subtitle",
            "pgssub", "hdmv_pgs_subtitle",
            "dvdsub", "dvd_subtitle",
            "xsub"
        ].contains(subtitleCodec)
    }

    private static func requiresServerPlaybackForLargeRemoteOriginal(
        container: String?,
        bitrate: Int?,
        byteSize: Int?,
        routeIsPrivate: Bool
    ) -> Bool {
        guard !routeIsPrivate else { return false }
        let normalizedContainers = container?
            .lowercased()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
        let isMatroska = normalizedContainers.contains("mkv")
            || normalizedContainers.contains("matroska")
            || normalizedContainers.contains("webm")
        guard isMatroska else { return false }

        let highBitrate = bitrate.map { $0 >= 40_000_000 } ?? false
        let largeFile = byteSize.map { $0 >= 20_000_000_000 } ?? false
        return highBitrate || largeFile
    }

    private static func requiresAudioTranscode(audioCodec: String?) -> Bool {
        guard let audioCodec = audioCodec?.lowercased() else { return false }
        // MobileVLCKit on iOS can enumerate these streams but may not expose
        // a usable PCM output, especially for TrueHD/MLP in MKV/BD sources.
        // Ask Jellyfin for AAC HLS so the video keeps its position while the
        // server performs the audio-only compatibility conversion.
        return [
            "truehd", "mlp", "ac4", "dts-hd", "dtshd", "dts-hd ma",
            "eac3-joc", "atmos"
        ].contains(audioCodec)
    }

    private static func requiresPlaybackAudioTranscode(audioCodec: String?, usesGreenfieldPlayback: Bool) -> Bool {
        if usesGreenfieldPlayback {
            return GreenfieldOriginalPlaybackPolicy.requiresAudioTranscode(codec: audioCodec,
                decoderAvailable: GreenfieldPlaybackControls.canDecodeOriginalAudio(audioCodec))
        }
        return requiresAudioTranscode(audioCodec: audioCodec)
            || requiresDeviceCompatibilityTranscode(audioCodec: audioCodec)
    }

    private static func requiresDeviceCompatibilityTranscode(audioCodec: String?) -> Bool {
#if os(iOS)
        // iPad's native playback path is less tolerant of FLAC carried in a
        // remote Matroska stream than iPhone's path. Restrict this decision to
        // that codec/device combination; ordinary MP4/MKV playback remains
        // original-first and can still fall back if the real stream fails.
        return UIDevice.current.userInterfaceIdiom == .pad
            && audioCodec?.lowercased() == "flac"
#else
        return false
#endif
    }

    private func makePlaybackTracker(
        for entry: JellyfinMediaEntry,
        playMethod: PlayMethod,
        playSessionID: String?,
        mediaSourceID: String?,
        subtitleStreamIndex: Int?,
        proxyURL: URL? = nil
    ) -> MediaPlaybackTracker {
        let encodingClient = client
        let reportingSessionID = responseScope.sessionID
        let activity = playbackActivity
        let activityTicket = activity.prepare()
        let reports = MediaPlaybackReportQueue { [weak self] event in
            await self?.reportPlayback(
                event,
                reportingClient: encodingClient,
                reportingSessionID: reportingSessionID,
                activityTicket: activityTicket,
                entry: entry,
                playMethod: playMethod,
                playSessionID: playSessionID,
                mediaSourceID: mediaSourceID,
                subtitleStreamIndex: subtitleStreamIndex
            )
        }
        return MediaPlaybackTracker(releaseResources: {
            if let proxyURL { AuthenticatedMediaStreamProxy.shared.unregister(proxyURL) }
            guard let encodingClient, let playSessionID, playMethod == .transcode else { return }
            Task {
                _ = try? await encodingClient.send(Paths.stopEncodingProcess(
                    deviceID: encodingClient.configuration.deviceID,
                    playSessionID: playSessionID
                )).value
            }
        }) { [weak self] event in
            if case .started = event { activity.activate(activityTicket) }
            // Preserve immediate local exit feedback while earlier HTTP reports drain.
            if case .stopped(let position, _) = event {
                Task { @MainActor [weak self] in
                    guard let self, self.responseScope.acceptsSession(reportingSessionID),
                          activity.isCurrent(activityTicket), position.isFinite, position >= 0 else { return }
                    self.playbackStopSnapshot = (entry.id, position, UUID())
                }
            }
            reports.enqueue(event)
        }
    }

    private func reportPlayback(
        _ event: MediaPlaybackTrackingEvent,
        reportingClient: JellyfinClient?,
        reportingSessionID: UUID,
        activityTicket: PlaybackActivityScope.Ticket,
        entry: JellyfinMediaEntry,
        playMethod: PlayMethod,
        playSessionID: String?,
        mediaSourceID: String?,
        subtitleStreamIndex: Int?
    ) async {
        guard let client = reportingClient, responseScope.acceptsSession(reportingSessionID), !Task.isCancelled else { return }
        do {
            switch event {
            case .started(let positionSeconds):
                let body = PlaybackStateInfo(
                    canSeek: true,
                    isPaused: false,
                    itemID: entry.id,
                    mediaSourceID: mediaSourceID,
                    playMethod: playMethod,
                    playSessionID: playSessionID,
                    positionTicks: Self.jellyfinTicks(for: positionSeconds),
                    subtitleStreamIndex: subtitleStreamIndex,
                    volumeLevel: 100
                )
                _ = try await client.send(Paths.reportPlaybackStart(body)).value
            case .progressed(let positionSeconds, let isPaused):
                let body = PlaybackStateInfo(
                    canSeek: true,
                    isPaused: isPaused,
                    itemID: entry.id,
                    mediaSourceID: mediaSourceID,
                    playMethod: playMethod,
                    playSessionID: playSessionID,
                    positionTicks: Self.jellyfinTicks(for: positionSeconds),
                    subtitleStreamIndex: subtitleStreamIndex,
                    volumeLevel: 100
                )
                _ = try await client.send(Paths.reportPlaybackProgress(body)).value
            case .stopped(let positionSeconds, let failed):
                let body = PlaybackStopInfo(
                    isFailed: failed,
                    itemID: entry.id,
                    mediaSourceID: mediaSourceID,
                    playSessionID: playSessionID,
                    positionTicks: Self.jellyfinTicks(for: positionSeconds)
                )
                _ = try await client.send(Paths.reportPlaybackStopped(body)).value
                guard responseScope.acceptsSession(reportingSessionID), !Task.isCancelled else { return }
                guard playbackActivity.isCurrent(activityTicket) else { return }
                try await refreshResumeItems(sessionID: reportingSessionID, activityTicket: activityTicket)
            }
        } catch {
            guard responseScope.acceptsSession(reportingSessionID) else { return }
            if !isExpectedCancellation(error) {
                record(
                    "diagnostics.jellyfin.playback_report_failed",
                    level: .warning,
                    details: diagnosticDetails(for: error)
                )
            }
        }
    }

    private static func jellyfinTicks(for seconds: Double) -> Int {
        PlaybackPositionPolicy.ticks(for: seconds)
    }

    private static func firstContainer(_ value: String?) -> String? {
        value?
            .split(separator: ",", maxSplits: 1)
            .first
            .map(String.init)
            .flatMap { $0.isEmpty ? nil : $0.lowercased() }
    }

    private static func elapsedMilliseconds(since date: Date) -> String {
        String(Int(max(Date().timeIntervalSince(date), 0) * 1_000))
    }

    private func authenticatedJellyfinURL(path: String, client: JellyfinClient) -> URL? {
        guard
            let url = client.url(path: path),
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        if components.queryItems?.contains(where: { $0.name.caseInsensitiveCompare("api_key") == .orderedSame }) != true,
           let accessToken = client.accessToken {
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "api_key", value: accessToken))
            components.queryItems = queryItems
        }
        return components.url.map(preferredPlaybackURL)
    }

    private func preferredPlaybackURL(_ url: URL) -> URL {
        guard
            let playbackEndpoint,
            var streamComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let playbackComponents = URLComponents(
                url: playbackEndpoint,
                resolvingAgainstBaseURL: false
            )
        else {
            return url
        }
        streamComponents.scheme = playbackComponents.scheme
        streamComponents.host = playbackComponents.host
        streamComponents.port = playbackComponents.port
        let prefix = playbackComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !prefix.isEmpty, !streamComponents.path.hasPrefix("/\(prefix)/") {
            streamComponents.path = "/\(prefix)" + streamComponents.path
        }
        return streamComponents.url ?? url
    }

    private func requiresCertificateBypass(for url: URL) -> Bool {
        guard allowsSelfSignedCertificates, url.scheme?.lowercased() == "https" else {
            return false
        }
        return CertificatePinStore.shared.trustedCertificateData(
            host: url.host,
            port: url.port
        ) != nil
    }

    private static func vlcPlaybackProfile(
        maxBitrate: Int,
        hlsSegmentContainer: String
    ) -> DeviceProfile {
        let audioCodecs = [
            "aac", "ac3", "alac", "amr_nb", "amr_wb", "dts", "eac3", "flac",
            "mp1", "mp2", "mp3", "opus", "pcm_alaw", "pcm_bluray", "pcm_dvd",
            "pcm_mulaw", "pcm_s16be", "pcm_s16le", "pcm_s24be", "pcm_s24le",
            "pcm_u8", "speex", "vorbis", "wavpack", "wmalossless", "wmapro",
            "wmav1", "wmav2"
        ].joined(separator: ",")
        let videoCodecs = [
            "av1", "dirac", "dv", "ffv1", "flv1", "h261", "h263", "h264", "hevc",
            "mjpeg", "mpeg1video", "mpeg2video", "mpeg4", "msmpeg4v1",
            "msmpeg4v2", "msmpeg4v3", "prores", "theora", "vc1", "vp8", "vp9",
            "wmv1", "wmv2", "wmv3"
        ].joined(separator: ",")
        let videoContainers = [
            "3g2", "3gp", "avi", "flv", "m2ts", "m4v", "mkv", "mov", "mp4",
            "mpeg", "mpegts", "mts", "ogm", "ogv", "ts", "vob", "webm", "wmv"
        ].joined(separator: ",")
        let textSubtitles = [
            "ass", "cc_dec", "mov_text", "mpl2", "pjs", "realtext", "sami",
            "srt", "ssa", "subrip", "subviewer", "subviewer1", "text", "ttml",
            "vplayer", "vtt"
        ]
        let imageSubtitles = ["dvbsub", "dvdsub", "pgssub", "xsub"]
        return DeviceProfile(
            codecProfiles: ["h264", "hevc", "vp9", "av1"].map { codec in
                CodecProfile(
                    codec: codec,
                    conditions: (hlsSegmentContainer == "ts" ? [
                        ProfileCondition(condition: .lessThanEqual, isRequired: true, property: .width,
                            value: String(GreenfieldQualityPolicy.maximumVideoSize(bitrate: maxBitrate).width)),
                        ProfileCondition(condition: .lessThanEqual, isRequired: true, property: .height,
                            value: String(GreenfieldQualityPolicy.maximumVideoSize(bitrate: maxBitrate).height))
                    ] : []) + [
                        ProfileCondition(
                            condition: .equalsAny,
                            isRequired: false,
                            property: .videoRangeType,
                            value: "SDR|Unknown"
                        )
                    ],
                    type: .video
                )
            },
            directPlayProfiles: [
                DirectPlayProfile(
                    audioCodec: audioCodecs,
                    container: videoContainers,
                    type: .video,
                    videoCodec: videoCodecs
                ),
                DirectPlayProfile(
                    audioCodec: audioCodecs,
                    container: "aac,ac3,alac,flac,m4a,mp3,ogg,opus,wav,wma",
                    type: .audio
                )
            ],
            maxStaticBitrate: 360_000_000,
            maxStaticMusicBitrate: min(maxBitrate, 8_000_000),
            maxStreamingBitrate: maxBitrate,
            musicStreamingTranscodingBitrate: 320_000,
            name: "Nastart MobileVLCKit \(MediaPlaybackCapabilities.current.deviceFamily)",
            subtitleProfiles: textSubtitles.map {
                SubtitleProfile(format: $0, method: .embed)
            } + textSubtitles.map {
                SubtitleProfile(format: $0, method: .external)
            } + imageSubtitles.map {
                SubtitleProfile(format: $0, method: .embed)
            },
            transcodingProfiles: [
                TranscodingProfile(
                    protocol: .hls,
                    audioCodec: "aac",
                    // Jellyfin fMP4 random starts retain pre-seek keyframes
                    // (-noaccurate_seek), but its VOD playlist starts at the
                    // requested segment time. H.264/AAC TS uses accurate seek
                    // to preserve content position across Greenfield switches.
                    container: hlsSegmentContainer,
                    context: .streaming,
                    isBreakOnNonKeyFrames: true,
                    maxAudioChannels: "8",
                    minSegments: hlsSegmentContainer == "ts" ? 1 : 2,
                    // A one-second VOD segment turns a multi-hour movie into
                    // thousands of entries and delays the first playlist by
                    // tens of seconds. Four seconds keeps seeks responsive
                    // without making the playlist itself a startup bottleneck.
                    segmentLength: hlsSegmentContainer == "ts" ? 4 : nil,
                    transcodeSeekInfo: .auto,
                    type: .video,
                    videoCodec: "h264"
                )
            ]
        )
    }

    private func loadHome() async {
        let sessionID = responseScope.sessionID
        let startedAt = Date()
        record(
            "diagnostics.jellyfin.library_loading",
            level: .info,
            details: ["stage": "started"]
        )
        do {
            let loadedLibraries = try await loadViews()
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            libraries = loadedLibraries
            isLoading = false
            record(
                "diagnostics.jellyfin.library_loaded",
                level: .info,
                details: [
                    "stage": "views",
                    "libraries": "\(loadedLibraries.count)",
                    "durationMs": Self.elapsedMilliseconds(since: startedAt)
                ]
            )
        } catch {
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            isLoading = false
            if isExpectedCancellation(error) {
                return
            }
            errorMessage = NSLocalizedString("jellyfin.library.load_failed", comment: "")
            record(
                "diagnostics.jellyfin.library_failed",
                level: .error,
                details: diagnosticDetails(for: error)
            )
            return
        }

        do {
            let shelfStartedAt = Date()
            try await refreshResumeItems(sessionID: sessionID)
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            recordHomeShelfLoaded("resume", count: continueWatching.count, since: shelfStartedAt)
        } catch {
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            recordHomeShelfFailed("resume", error: error)
        }

        do {
            let shelfStartedAt = Date()
            let loaded = try await loadItems(parentID: nil, kinds: [.movie], limit: 36)
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            movies = loaded
            registerFavoriteState(from: movies)
            recordHomeShelfLoaded("movies", count: movies.count, since: shelfStartedAt)
        } catch {
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            recordHomeShelfFailed("movies", error: error)
        }

        do {
            let shelfStartedAt = Date()
            let loaded = try await loadItems(parentID: nil, kinds: [.series], limit: 36)
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            series = loaded
            registerFavoriteState(from: series)
            recordHomeShelfLoaded("series", count: series.count, since: shelfStartedAt)
        } catch {
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            recordHomeShelfFailed("series", error: error)
        }

        do {
            let shelfStartedAt = Date()
            let loaded = try await loadItems(
                parentID: nil,
                kinds: [.movie, .series],
                limit: 24,
                sortBy: [.dateCreated],
                sortOrder: [.descending]
            )
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            recentlyAdded = loaded
            registerFavoriteState(from: recentlyAdded)
            recordHomeShelfLoaded("recentlyAdded", count: recentlyAdded.count, since: shelfStartedAt)
        } catch {
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            recordHomeShelfFailed("recentlyAdded", error: error)
        }

        do {
            let shelfStartedAt = Date()
            let loaded = try await loadItems(
                parentID: nil,
                kinds: [.movie, .series, .episode, .audio, .video, .musicAlbum, .musicVideo],
                limit: 60,
                favoriteOnly: true
            )
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            favorites = loaded
            registerFavoriteState(from: favorites)
            recordHomeShelfLoaded("favorites", count: favorites.count, since: shelfStartedAt)
        } catch {
            guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { return }
            recordHomeShelfFailed("favorites", error: error)
        }

        let serverFavoriteIDs = (continueWatching + movies + series + recentlyAdded + favorites)
            .filter(\.isFavorite)
            .map(\.id)
        favoriteItemIDs = Set(serverFavoriteIDs + favorites.map(\.id))
        record(
            "diagnostics.jellyfin.library_loaded",
            level: .info,
            details: [
                "stage": "completed",
                "libraries": "\(libraries.count)",
                "resume": "\(continueWatching.count)",
                "movies": "\(movies.count)",
                "series": "\(series.count)",
                "recentlyAdded": "\(recentlyAdded.count)",
                "favorites": "\(favorites.count)",
                "durationMs": Self.elapsedMilliseconds(since: startedAt)
            ]
        )
        if let client {
            scheduleBitrateMeasurementIfNeeded(client: client)
        }
    }

    private func recordHomeShelfLoaded(
        _ shelf: String,
        count: Int,
        since startedAt: Date
    ) {
        record(
            "diagnostics.jellyfin.library_loaded",
            level: .info,
            details: [
                "stage": shelf,
                "count": "\(count)",
                "durationMs": Self.elapsedMilliseconds(since: startedAt)
            ]
        )
    }

    private func recordHomeShelfFailed(_ shelf: String, error: Error) {
        if isExpectedCancellation(error) {
            return
        }
        record(
            "diagnostics.jellyfin.library_failed",
            level: .warning,
            details: diagnosticDetails(for: error).merging([
                "stage": shelf
            ]) { current, _ in current }
        )
    }

    private func isExpectedCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let value = error as NSError
        return value.domain == NSURLErrorDomain && value.code == NSURLErrorCancelled
    }

    private func loadViews() async throws -> [JellyfinMediaEntry] {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        var parameters = Paths.GetUserViewsParameters()
        parameters.userID = userID
        parameters.isIncludeHidden = false
        let response = try await client.send(Paths.getUserViews(parameters: parameters)).value
        return (response.items ?? []).compactMap(mapItem)
    }

    private func refreshResumeItems(
        sessionID: UUID,
        activityTicket: PlaybackActivityScope.Ticket? = nil
    ) async throws {
        guard responseScope.acceptsSession(sessionID), !Task.isCancelled else { throw CancellationError() }
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        if let activityTicket, !playbackActivity.isCurrent(activityTicket) { throw CancellationError() }
        let request = responseScope.beginResumeRequest()
        var parameters = Paths.GetResumeItemsParameters()
        parameters.userID = userID
        parameters.limit = 20
        parameters.fields = itemFields
        parameters.mediaTypes = [.video, .audio]
        parameters.enableUserData = true
        parameters.enableImages = true
        parameters.enableImageTypes = [.primary, .thumb, .backdrop]
        parameters.includeItemTypes = [.movie, .episode, .audio, .video]
        let response = try await client.send(Paths.getResumeItems(parameters: parameters)).value
        try Task.checkCancellation()
        guard responseScope.acceptsResumeResponse(request) else { throw CancellationError() }
        if let activityTicket, !playbackActivity.isCurrent(activityTicket) { throw CancellationError() }
        // Validate and publish in one actor turn; returning an unchecked array
        // to a suspended caller would reopen the stale-response race.
        continueWatching = (response.items ?? []).compactMap(mapItem)
        registerFavoriteState(from: continueWatching)
    }

    private func loadItems(
        parentID: String?,
        kinds: [BaseItemKind],
        limit: Int,
        searchTerm: String? = nil,
        favoriteOnly: Bool? = nil,
        sortBy: [ItemSortBy] = [.sortName],
        sortOrder: [JellyfinAPI.SortOrder] = [.ascending]
    ) async throws -> [JellyfinMediaEntry] {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        var parameters = Paths.GetItemsParameters()
        parameters.userID = userID
        parameters.parentID = parentID
        parameters.limit = limit
        parameters.isRecursive = true
        parameters.searchTerm = searchTerm
        parameters.isFavorite = favoriteOnly
        parameters.fields = itemFields
        parameters.includeItemTypes = kinds
        parameters.sortBy = sortBy
        parameters.sortOrder = sortOrder
        parameters.enableUserData = true
        parameters.enableImages = true
        parameters.imageTypeLimit = 1
        parameters.enableImageTypes = [.primary, .thumb, .backdrop]
        let response = try await client.send(Paths.getItems(parameters: parameters)).value
        return (response.items ?? []).compactMap(mapItem)
    }

    private var itemFields: [ItemFields] {
        [
            .overview,
            .primaryImageAspectRatio,
            .mediaSources,
            .mediaStreams,
            .path,
            .genres,
            .dateCreated
        ]
    }

    private func registerFavoriteState(from items: [JellyfinMediaEntry]) {
        favoriteItemIDs.formUnion(items.filter(\.isFavorite).map(\.id))
    }

    private func mapItem(_ item: BaseItemDto) -> JellyfinMediaEntry? {
        guard let id = item.id, let title = item.name, !title.isEmpty else { return nil }
        let kind: JellyfinEntryKind
        switch item.type {
        case .collectionFolder, .folder: kind = .library
        case .movie: kind = .movie
        case .series: kind = .series
        case .episode: kind = .episode
        case .audio, .musicAlbum: kind = .audio
        case .video, .musicVideo: kind = .video
        default: kind = .unknown
        }
        let imageItemID = item.imageTags?[ImageType.primary.rawValue] == nil
            ? (item.parentPrimaryImageItemID ?? id)
            : id
        let imageTag = item.imageTags?[ImageType.primary.rawValue] ?? item.parentPrimaryImageTag
        let mediaSource = preferredMediaSource(from: item.mediaSources ?? [])
        let mediaStreams = mediaSource?.mediaStreams ?? item.mediaStreams ?? []
        let videoStream = mediaStreams.first { $0.type == .video }
        let audioStreams = mediaStreams.filter { $0.type == .audio }
        let audioStream = audioStreams.first
        let subtitleStreams = mediaStreams.filter { $0.type == .subtitle }
        let audioTracks = audioStreams.compactMap(Self.mediaTrack)
        let subtitleTracks = subtitleStreams.compactMap(Self.mediaTrack)
        let defaultAudioStreamIndex = mediaSource?.defaultAudioStreamIndex
            ?? audioStreams.first(where: { $0.isDefault == true })?.index
            ?? audioStreams.first?.index
        let preferredSubtitle = subtitleStreams.first(where: { $0.index == mediaSource?.defaultSubtitleStreamIndex })
            ?? subtitleStreams.first(where: { $0.isForced == true })
            ?? subtitleStreams.first(where: { $0.isDefault == true })
        let people = (item.people ?? []).compactMap { person -> JellyfinPersonEntry? in
            guard let name = person.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                return nil
            }
            return JellyfinPersonEntry(
                id: person.id ?? "\(name)|\(person.role ?? "")",
                imageItemID: person.id,
                name: name,
                role: person.role,
                type: person.type?.rawValue,
                imageTag: person.primaryImageTag
            )
        }
        return JellyfinMediaEntry(
            id: id,
            title: title,
            subtitle: subtitle(for: item, kind: kind),
            overview: item.overview ?? "",
            kind: kind,
            collectionType: item.collectionType?.rawValue,
            imageItemID: imageItemID,
            imageTag: imageTag,
            thumbImageTag: item.imageTags?[ImageType.thumb.rawValue],
            backdropImageTag: item.backdropImageTags?.first,
            container: item.container ?? mediaSource?.container,
            mediaSourceID: mediaSource?.id,
            defaultAudioStreamIndex: defaultAudioStreamIndex,
            preferredSubtitleStreamIndex: preferredSubtitle?.index,
            preferredSubtitleCodec: preferredSubtitle?.codec,
            audioTracks: audioTracks,
            subtitleTracks: subtitleTracks,
            progress: item.userData?.playedPercentage.map { min(max($0 / 100, 0), 1) },
            playbackPositionTicks: item.userData?.playbackPositionTicks,
            runTimeTicks: item.runTimeTicks ?? mediaSource?.runTimeTicks,
            seriesID: item.seriesID,
            seasonNumber: item.parentIndexNumber,
            episodeNumber: item.indexNumber,
            isFavorite: item.userData?.isFavorite == true,
            genres: item.genres ?? [],
            communityRating: item.communityRating.map(Double.init),
            officialRating: item.officialRating,
            videoDescription: Self.videoDescription(for: videoStream),
            audioDescription: Self.audioDescription(for: audioStream),
            originalTitle: item.originalTitle,
            tagline: item.taglines?.first(where: { !$0.isEmpty }),
            productionYear: item.productionYear,
            premiereDate: item.premiereDate,
            people: people,
            studios: (item.studios ?? []).compactMap(\.name).filter { !$0.isEmpty },
            externalLinks: Self.externalLinks(for: item),
            mediaPath: mediaSource?.path ?? item.path,
            mediaSize: mediaSource?.size,
            mediaBitrate: mediaSource?.bitrate,
            dolbyVideo: PlaybackDolbySourceInfo(visionProfile: videoStream?.dvProfile,
                visionLevel: videoStream?.dvLevel, baseLayerCompatibilityID: videoStream?.dvBlSignalCompatibilityID)
        )
    }

    private func preferredMediaSource(from sources: [MediaSourceInfo]) -> MediaSourceInfo? {
        guard !sources.isEmpty else { return nil }
        // Automatic playback must describe the original asset consistently.
        // Never choose a lower-bitrate MediaSource just because a previous
        // throughput sample was conservative; that silently changes the title
        // before the player has had a chance to try the original route. Manual
        // quality selection is the only place that should request HLS.
        return sources.max { lhs, rhs in
            (lhs.bitrate ?? 0) < (rhs.bitrate ?? 0)
        } ?? sources.first
    }

    private static func externalLinks(for item: BaseItemDto) -> [JellyfinExternalLink] {
        var links: [JellyfinExternalLink] = []
        var seen = Set<String>()

        for link in item.externalURLs ?? [] {
            guard let value = link.url,
                  let url = URL(string: value),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  seen.insert(url.absoluteString).inserted else {
                continue
            }
            links.append(JellyfinExternalLink(name: link.name ?? url.host ?? value, url: url))
        }

        let providers = item.providerIDs ?? [:]
        let providerLinks: [(String, String?)] = [
            ("IMDb", providers.first { $0.key.caseInsensitiveCompare("imdb") == .orderedSame }
                .map { "https://www.imdb.com/title/\($0.value)/" }),
            ("TMDB", providers.first { $0.key.caseInsensitiveCompare("tmdb") == .orderedSame }
                .map { "https://www.themoviedb.org/\(item.type == .series ? "tv" : "movie")/\($0.value)" })
        ]
        for (name, value) in providerLinks {
            guard let value,
                  let url = URL(string: value),
                  seen.insert(url.absoluteString).inserted else {
                continue
            }
            links.append(JellyfinExternalLink(name: name, url: url))
        }
        return links
    }

    private static func mediaTrack(_ stream: MediaStream) -> JellyfinMediaTrack? {
        guard let index = stream.index else { return nil }
        let fallbackTitle = [stream.language, stream.codec?.uppercased()]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let displayTitle = stream.displayTitle
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
        return JellyfinMediaTrack(
            index: index,
            title: displayTitle ?? (fallbackTitle.isEmpty ? "#\(index)" : fallbackTitle),
            codec: stream.codec,
            profile: stream.profile,
            audioSpatialFormat: stream.audioSpatialFormat?.rawValue,
            isDefault: stream.isDefault == true,
            isForced: stream.isForced == true
        )
    }

    private static func videoDescription(for stream: MediaStream?) -> String? {
        guard let stream else { return nil }
        var components: [String] = []
        if let height = stream.height {
            if height >= 2_000 {
                components.append("4K")
            } else if height >= 1_000 {
                components.append("1080p")
            } else if height >= 700 {
                components.append("720p")
            } else {
                components.append("\(height)p")
            }
        }
        if let codec = stream.codec?.uppercased() {
            switch codec {
            case "HEVC", "H265": components.append("H.265")
            case "H264", "AVC": components.append("H.264")
            default: components.append(codec)
            }
        }
        if let videoRangeType = stream.videoRangeType,
           videoRangeType != .unknown,
           videoRangeType != .sdr {
            components.append("HDR")
        }
        let description = components.joined(separator: " · ")
        return description.isEmpty ? stream.displayTitle : description
    }

    private static func audioDescription(for stream: MediaStream?) -> String? {
        guard let stream else { return nil }
        var components: [String] = []
        if let codec = stream.codec?.uppercased() {
            components.append(codec == "EAC3" ? "E-AC3" : codec)
        }
        if let channels = stream.channels {
            switch channels {
            case 1: components.append("Mono")
            case 2: components.append("2.0")
            case 6: components.append("5.1")
            case 8: components.append("7.1")
            default: components.append("\(channels) ch")
            }
        }
        let description = components.joined(separator: " · ")
        return description.isEmpty ? stream.displayTitle : description
    }

    private func subtitle(for item: BaseItemDto, kind: JellyfinEntryKind) -> String {
        if kind == .episode {
            let season = item.parentIndexNumber.map { "S\($0)" } ?? ""
            let episode = item.indexNumber.map { "E\($0)" } ?? ""
            return [item.seriesName, season + episode].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        }
        let duration = item.runTimeTicks.flatMap { ticks -> String? in
            guard ticks > 0 else { return nil }
            let minutes = Int(ticks / 600_000_000)
            guard minutes > 0 else { return nil }
            return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
        }
        return [item.productionYear.map(String.init), duration]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func makeClient(accessToken: String?) -> JellyfinClient {
        let delegate = JellyfinCertificateTrustDelegate(
            trustedHost: endpoint.host,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates
        )
        trustDelegate = delegate
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        let deviceID = Self.persistentDeviceID()
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
        return JellyfinClient(
            configuration: .init(
                url: endpoint,
                accessToken: accessToken,
                client: "Nastart",
                deviceName: UIDevice.current.model,
                deviceID: deviceID,
                version: appVersion
            ),
            sessionConfiguration: configuration,
            sessionDelegate: delegate
        )
    }

    private static func persistentDeviceID() -> String {
        let key = "jellyfin.client.device-id"
        if let current = UserDefaults.standard.string(forKey: key) { return current }
        let value = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }

    private func record(
        _ messageKey: String,
        level: DiagnosticLogLevel,
        details: [String: String] = [:]
    ) {
        DiagnosticLogStore.shared.record(
            level,
            categoryKey: "diagnostics.category.media",
            messageKey: messageKey,
            details: details.merging([
                "target": DiagnosticLogStore.redactedURL(endpoint)
            ]) { current, _ in current }
        )
    }

    private func diagnosticDetails(for error: Error) -> [String: String] {
        let value = error as NSError
        var details = [
            "errorDomain": value.domain,
            "errorCode": "\(value.code)",
            "description": value.localizedDescription,
            "errorType": String(reflecting: type(of: error)),
            "transport": endpoint.scheme?.lowercased() ?? "-"
        ]
        if let status = httpStatusCode(for: error) {
            details["httpStatus"] = "\(status)"
        }
        return details
    }

    private func loginErrorMessage(for error: Error) -> String {
        switch httpStatusCode(for: error) {
        case 401:
            return NSLocalizedString("jellyfin.login.invalid_credentials", comment: "")
        case 403:
            return NSLocalizedString("jellyfin.login.denied", comment: "")
        case 429:
            return NSLocalizedString("jellyfin.login.rate_limited", comment: "")
        default:
            return NSLocalizedString("jellyfin.login.failed", comment: "")
        }
    }

    private func httpStatusCode(for error: Error) -> Int? {
        JellyfinHTTPStatus.code(for: error)
    }
}

private enum JellyfinLibraryError: Error {
    case missingSession
    case missingItem
    case missingPlaybackURL
}

struct JellyfinLibraryView: View {
    let service: LaunchpadService
    let dsmSession: DSMSession?
    let dsmSharedFolderPaths: [String]
    @StateObject private var store: JellyfinLibraryStore

    init(
        service: LaunchpadService,
        endpoint: URL,
        allowsSelfSignedCertificates: Bool,
        dsmSession: DSMSession? = nil,
        dsmSharedFolderPaths: [String] = [],
        fallbackEndpoints: [URL] = [],
        connectionStore: NASConnectionStore? = nil
    ) {
        self.service = service
        self.dsmSession = dsmSession
        self.dsmSharedFolderPaths = dsmSharedFolderPaths
        _store = StateObject(wrappedValue: JellyfinLibraryStore(
            endpoint: endpoint,
            playbackEndpoint: nil,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            dsmSession: dsmSession,
            dsmSharedFolderPaths: dsmSharedFolderPaths,
            fallbackEndpoints: fallbackEndpoints,
            connectionStore: connectionStore
        ))
    }

    var body: some View {
        Group {
            if store.isLoading && !store.isAuthenticated {
                ProgressView("jellyfin.library.connecting")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !store.isAuthenticated {
                JellyfinLoginView(store: store)
            } else {
                JellyfinHomeView(store: store)
            }
        }
        .background(AppTheme.groupedBackground)
        .task(id: dsmPlaybackContextID) {
            store.updateDSMPlaybackContext(
                session: dsmSession,
                sharedFolderPaths: dsmSharedFolderPaths
            )
            await store.restoreIfNeeded()
        }
        .toolbar {
            if store.isAuthenticated {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink {
                        JellyfinFavoritesView(store: store)
                    } label: {
                        Image(systemName: "heart")
                    }
                    .accessibilityLabel(Text("jellyfin.favorites.title"))

                    NavigationLink {
                        JellyfinSearchView(store: store)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel(Text("jellyfin.search.title"))

                    Menu {
                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Label("action.refresh", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) {
                            Task { await store.signOut() }
                        } label: {
                            Label("jellyfin.logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var dsmPlaybackContextID: String {
        ([dsmSession?.sid ?? "-",
          dsmSession?.baseURL.absoluteString ?? "-",
          dsmSession?.endpoints.lanAddress?.absoluteString ?? "-"]
            + dsmSharedFolderPaths.sorted()).joined(separator: "|")
    }
}

private struct JellyfinLoginView: View {
    @ObservedObject var store: JellyfinLibraryStore
    @State private var username = ""
    @State private var password = ""
    @State private var showsPassword = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(AppTheme.accent)
                    Text("jellyfin.login.title")
                        .font(.title2.weight(.bold))
                    Text("jellyfin.login.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    compactLoginTextField(
                        titleKey: "jellyfin.login.username",
                        placeholderKey: "jellyfin.login.username.example",
                        text: $username,
                        keyboardType: .asciiCapable
                    )
                    .textContentType(.username)
                    Divider()
                    HStack(spacing: 12) {
                        Text("jellyfin.login.password")
                            .foregroundStyle(.primary)
                        Group {
                            if showsPassword {
                                TextField("jellyfin.login.password.example", text: $password)
                            } else {
                                SecureField("jellyfin.login.password.example", text: $password)
                            }
                        }
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)

                        Button {
                            showsPassword.toggle()
                        } label: {
                            Image(systemName: showsPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(showsPassword ? "jellyfin.login.password.hide" : "jellyfin.login.password.show"))
                    }
                    .padding(16)
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let errorMessage = store.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await store.signIn(username: username, password: password) }
                } label: {
                    HStack {
                        if store.isLoading { ProgressView().tint(.white) }
                        Text("jellyfin.login.action")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primaryAction)
                .disabled(store.isLoading || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(24)
        }
    }

    private func compactLoginTextField(
        titleKey: LocalizedStringKey,
        placeholderKey: LocalizedStringKey,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        HStack(spacing: 12) {
            Text(titleKey)
                .foregroundStyle(.primary)
            TextField(placeholderKey, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
    }
}

private struct JellyfinHomeView: View {
    @ObservedObject var store: JellyfinLibraryStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.username)
                            .font(.headline.weight(.semibold))
                        Text("jellyfin.library.connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.isLoading { ProgressView() }
                }

                if let errorMessage = store.errorMessage {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                        Button("action.retry") {
                            Task { await store.refresh() }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if !featuredItems.isEmpty {
                    JellyfinHeroCarousel(store: store, items: featuredItems)
                }

                if !store.libraries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        JellyfinShelfHeader(
                            titleKey: "jellyfin.library.mine",
                            count: store.libraries.count
                        )
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(store.libraries) { library in
                                    NavigationLink {
                                        JellyfinCollectionView(store: store, library: library)
                                    } label: {
                                        JellyfinLibraryCard(store: store, library: library)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if !store.continueWatching.isEmpty {
                    JellyfinPosterShelf(
                        store: store,
                        titleKey: "media.continue.title",
                        items: store.continueWatching,
                        posterWidth: 230,
                        landscape: true
                    )
                }

                if !store.favorites.isEmpty {
                    JellyfinPosterShelf(
                        store: store,
                        titleKey: "jellyfin.favorites.title",
                        items: Array(store.favorites.prefix(18)),
                        posterWidth: 128,
                        landscape: false
                    )
                }

                if !store.movies.isEmpty {
                    JellyfinPosterShelf(
                        store: store,
                        titleKey: "media.movies.title",
                        items: store.movies,
                        posterWidth: 128,
                        landscape: false
                    )
                }

                if !store.series.isEmpty {
                    JellyfinPosterShelf(
                        store: store,
                        titleKey: "jellyfin.series.title",
                        items: store.series,
                        posterWidth: 128,
                        landscape: false
                    )
                }

                if !store.isLoading,
                   store.libraries.isEmpty,
                   store.continueWatching.isEmpty,
                   store.movies.isEmpty,
                   store.series.isEmpty,
                   store.errorMessage == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.badge.play")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("jellyfin.library.empty")
                            .font(.headline)
                        Text("jellyfin.library.empty_detail")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                }
            }
            .frame(maxWidth: 960, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
        .refreshable { await store.refresh() }
    }

    private var featuredItems: [JellyfinMediaEntry] {
        var seen = Set<String>()
        let resumableMovies = store.continueWatching.filter { $0.kind == .movie }
        return (resumableMovies + store.recentlyAdded + store.favorites + store.movies + store.series)
            .filter { item in
                guard
                    item.kind == .movie || item.kind == .series,
                    item.backdropImageTag != nil
                else {
                    return false
                }
                return seen.insert(item.id).inserted
            }
            .prefix(6)
            .map { $0 }
    }
}

private struct JellyfinShelfHeader: View {
    let titleKey: LocalizedStringKey
    let count: Int?

    init(titleKey: LocalizedStringKey, count: Int? = nil) {
        self.titleKey = titleKey
        self.count = count
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
                .font(.title2.weight(.bold))
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct JellyfinHeroCarousel: View {
    @ObservedObject var store: JellyfinLibraryStore
    let items: [JellyfinMediaEntry]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                NavigationLink {
                    JellyfinMediaRouteView(store: store, item: item)
                } label: {
                    JellyfinHeroSlide(store: store, item: item)
                }
                .buttonStyle(.plain)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxHeight: horizontalSizeClass == .regular ? 400 : 240)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(items.indices, id: \.self) { index in
                        Capsule()
                            .fill(.white.opacity(index == selection ? 0.95 : 0.48))
                            .frame(width: index == selection ? 18 : 6, height: 6)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.black.opacity(0.32), in: Capsule())
                .padding(14)
                .accessibilityHidden(true)
            }
        }
        .task(id: items.map(\.id)) {
            selection = min(selection, max(items.count - 1, 0))
            guard items.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    selection = (selection + 1) % items.count
                }
            }
        }
    }
}

private struct JellyfinHeroSlide: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            JellyfinPosterImage(
                url: store.imageURL(
                    for: item,
                    width: 1_280,
                    landscape: true,
                    prefersBackdrop: true,
                    quality: 90
                )
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.28),
                    .init(color: .black.opacity(0.18), location: 0.52),
                    .init(color: .black.opacity(0.88), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(LocalizedStringKey(
                    item.kind == .series ? "jellyfin.series.title" : "media.movies.title"
                ))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                Text(item.title)
                    .font(
                        horizontalSizeClass == .regular
                            ? .title2.weight(.bold)
                            : .title3.weight(.bold)
                    )
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }
                Label {
                    Text(LocalizedStringKey(
                        item.isPlayable ? "player.play_in_app" : "jellyfin.view_details"
                    ))
                } icon: {
                    Image(systemName: item.isPlayable ? "play.fill" : "arrow.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(horizontalSizeClass == .regular ? 20 : 14)
        }
        .background(Color.black)
        .contentShape(Rectangle())
    }
}

private struct JellyfinLibraryCard: View {
    @ObservedObject var store: JellyfinLibraryStore
    let library: JellyfinMediaEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            JellyfinPosterImage(
                url: store.imageURL(for: library, width: 560, landscape: true)
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )
            Text(library.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(12)
        }
        .frame(width: 220, height: 124)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct JellyfinPosterShelf: View {
    @ObservedObject var store: JellyfinLibraryStore
    let titleKey: LocalizedStringKey
    let items: [JellyfinMediaEntry]
    let posterWidth: CGFloat
    let landscape: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            JellyfinShelfHeader(titleKey: titleKey, count: items.count)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink {
                            JellyfinMediaRouteView(store: store, item: item)
                        } label: {
                            JellyfinPosterCard(
                                store: store,
                                item: item,
                                width: posterWidth,
                                landscape: landscape
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct JellyfinPosterCard: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry
    let width: CGFloat
    let landscape: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                JellyfinPosterImage(
                    url: store.imageURL(
                        for: item,
                        width: Int(width * 3),
                        landscape: landscape
                    )
                )
                if let progress = item.effectivePlaybackProgress, progress > 0 {
                    GeometryReader { geometry in
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                }
            }
            .frame(width: width, height: landscape ? width * 0.58 : width * 1.48)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(item.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct JellyfinGridPosterCard: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // The grid cell, rather than the downloaded image's natural size,
            // owns layout. Both landscape stills and posters fill this same canvas.
            Rectangle()
                .fill(Color(.tertiarySystemFill))
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay {
                    JellyfinPosterImage(
                        url: store.imageURL(for: item, width: 540)
                    )
                }
                .overlay(alignment: .bottomLeading) {
                    if let progress = item.effectivePlaybackProgress, progress > 0 {
                        GeometryReader { geometry in
                            VStack(spacing: 0) {
                                Spacer()
                                Rectangle()
                                    .fill(AppTheme.accent)
                                    .frame(width: geometry.size.width * progress, height: 4)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(item.title)
                .font(
                    horizontalSizeClass == .compact
                        ? .caption.weight(.semibold)
                        : .subheadline.weight(.semibold)
                )
                .foregroundStyle(.primary)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.subtitle.isEmpty ? " " : item.subtitle)
                .font(horizontalSizeClass == .compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private final class JellyfinImagePipeline: @unchecked Sendable {
    static let shared = JellyfinImagePipeline()

    private let memoryCache = NSCache<NSURL, UIImage>()
    // Serialize eager decompression away from scrolling/layout on the main thread.
    private let decodeQueue = DispatchQueue(label: "com.changliwen.nastart.poster-decode", qos: .userInitiated)
    private let session: URLSession

    private init() {
        memoryCache.countLimit = 240
        memoryCache.totalCostLimit = 64 * 1_024 * 1_024
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1_024 * 1_024,
            diskCapacity: 320 * 1_024 * 1_024,
            diskPath: "nastart-jellyfin-images"
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.httpMaximumConnectionsPerHost = 8
        session = URLSession(configuration: configuration)
    }

    func image(for url: URL) async -> UIImage? {
        let key = url as NSURL
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        do {
            let (data, response) = try await session.data(for: request)
            guard
                let response = response as? HTTPURLResponse,
                (200..<300).contains(response.statusCode),
                !Task.isCancelled
            else {
                return nil
            }
            let image: UIImage? = await withCheckedContinuation { continuation in
                decodeQueue.async {
                    // Preserve UIImage's orientation metadata while preparing pixels.
                    let image = UIImage(data: data)?.preparingForDisplay()
                    continuation.resume(returning: image)
                }
            }
            guard !Task.isCancelled, let image else { return nil }
            // The cache owns decoded pixels, not just the compressed network payload.
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height }
                ?? Int(image.size.width * image.scale * image.size.height * image.scale * 4)
            memoryCache.setObject(image, forKey: key, cost: cost)
            return image
        } catch {
            return nil
        }
    }
}

@MainActor
private final class JellyfinPosterImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var didFail = false
    private var currentURL: URL?

    func load(_ url: URL?) async {
        guard currentURL != url || image == nil else { return }
        currentURL = url
        image = nil
        didFail = false
        guard let url else { return }
        let loadedImage = await JellyfinImagePipeline.shared.image(for: url)
        guard currentURL == url, !Task.isCancelled else { return }
        image = loadedImage
        didFail = loadedImage == nil
    }
}

private struct JellyfinPosterImage: View {
    let url: URL?
    var scalesToFit = false
    @StateObject private var loader = JellyfinPosterImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                if scalesToFit {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            } else if loader.didFail || url == nil {
                placeholder
            } else {
                ZStack {
                    placeholder
                    ProgressView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: url) {
            await loader.load(url)
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemFill))
            .overlay {
                Image(systemName: "play.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}

private struct JellyfinFavoritesView: View {
    @ObservedObject var store: JellyfinLibraryStore

    var body: some View {
        Group {
            if store.favorites.isEmpty {
                JellyfinEmptyState(
                    systemImage: "heart",
                    titleKey: "jellyfin.favorites.empty",
                    detailKey: "jellyfin.favorites.empty_detail"
                )
            } else {
                JellyfinResultGrid(store: store, items: store.favorites)
            }
        }
        .navigationTitle("jellyfin.favorites.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct JellyfinSearchView: View {
    @ObservedObject var store: JellyfinLibraryStore
    @State private var query = ""
    @State private var results: [JellyfinMediaEntry] = []
    @State private var isSearching = false
    @State private var searchFailed = false

    var body: some View {
        Group {
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchFailed {
                JellyfinEmptyState(
                    systemImage: "exclamationmark.magnifyingglass",
                    titleKey: "jellyfin.search.failed",
                    detailKey: "jellyfin.search.failed_detail"
                )
            } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                JellyfinEmptyState(
                    systemImage: "magnifyingglass",
                    titleKey: "jellyfin.search.start",
                    detailKey: "jellyfin.search.start_detail"
                )
            } else if results.isEmpty {
                JellyfinEmptyState(
                    systemImage: "rectangle.stack.badge.minus",
                    titleKey: "jellyfin.search.empty",
                    detailKey: "jellyfin.search.empty_detail"
                )
            } else {
                JellyfinResultGrid(store: store, items: results)
            }
        }
        .navigationTitle("jellyfin.search.title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "jellyfin.search.placeholder")
        .task(id: query) {
            let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedQuery.isEmpty else {
                results = []
                searchFailed = false
                isSearching = false
                return
            }
            isSearching = true
            searchFailed = false
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let matches = try await store.search(query: cleanedQuery)
                guard !Task.isCancelled else { return }
                results = matches
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                searchFailed = true
            }
            isSearching = false
        }
    }
}

private struct JellyfinResultGrid: View {
    @ObservedObject var store: JellyfinLibraryStore
    let items: [JellyfinMediaEntry]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: gridColumns,
                spacing: 18
            ) {
                ForEach(items) { item in
                    NavigationLink {
                        JellyfinMediaRouteView(store: store, item: item)
                    } label: {
                        JellyfinGridPosterCard(store: store, item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 960)
            .padding(.horizontal, horizontalSizeClass == .compact ? 12 : 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
    }

    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return Array(
                repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
                count: 3
            )
        }
        return [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14, alignment: .top)]
    }
}

private struct JellyfinEmptyState: View {
    let systemImage: String
    let titleKey: LocalizedStringKey
    let detailKey: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(titleKey)
                .font(.headline)
            Text(detailKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct JellyfinCollectionView: View {
    @ObservedObject var store: JellyfinLibraryStore
    let library: JellyfinMediaEntry
    @State private var items: [JellyfinMediaEntry] = []
    @State private var isLoading = true
    @State private var failed = false
    @State private var query = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("jellyfin.library.load_failed")
                        .font(.headline)
                    Button("action.retry") { Task { await load() } }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if visibleItems.isEmpty {
                        JellyfinEmptyState(
                            systemImage: query.isEmpty ? "rectangle.stack.badge.minus" : "magnifyingglass",
                            titleKey: query.isEmpty ? "jellyfin.library.empty" : "jellyfin.search.empty",
                            detailKey: query.isEmpty ? "jellyfin.library.empty_detail" : "jellyfin.search.empty_detail"
                        )
                        .frame(minHeight: 420)
                    } else {
                        LazyVGrid(
                            columns: gridColumns,
                            spacing: 20
                        ) {
                            ForEach(visibleItems) { item in
                                NavigationLink {
                                    JellyfinMediaRouteView(store: store, item: item)
                                } label: {
                                    JellyfinGridPosterCard(store: store, item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: 960)
                        .padding(.horizontal, horizontalSizeClass == .compact ? 12 : 18)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle(library.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "jellyfin.search.placeholder")
        .task { await load() }
    }

    private var visibleItems: [JellyfinMediaEntry] {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(cleanedQuery)
                || $0.subtitle.localizedCaseInsensitiveContains(cleanedQuery)
        }
    }

    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return Array(
                repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
                count: 3
            )
        }
        return [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14, alignment: .top)]
    }

    private func load() async {
        isLoading = true
        failed = false
        do {
            items = try await store.loadLibrary(library)
        } catch {
            failed = true
        }
        isLoading = false
    }
}

private struct JellyfinMediaRouteView: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry

    var body: some View {
        if item.kind == .series {
            JellyfinSeriesView(store: store, series: item)
        } else {
            JellyfinMediaDetailView(store: store, item: item)
        }
    }
}

private struct JellyfinSeriesView: View {
    @ObservedObject var store: JellyfinLibraryStore
    let series: JellyfinMediaEntry
    @State private var episodes: [JellyfinMediaEntry] = []
    @State private var isLoading = true
    @State private var failed = false

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(max(proxy.size.width - 36, 0), 820)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    JellyfinDetailHeader(store: store, item: series)

                    LazyVStack(alignment: .leading, spacing: 22) {
                        JellyfinMetadataStrip(item: series)

                        if !series.overview.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("jellyfin.overview.title")
                                    .font(.title3.weight(.bold))
                                Text(series.overview)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        JellyfinShelfHeader(
                            titleKey: "jellyfin.episodes.title",
                            count: isLoading ? nil : episodes.count
                        )

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 36)
                        } else if failed {
                            Button("action.retry") { Task { await loadEpisodes() } }
                                .buttonStyle(.bordered)
                        } else if episodes.isEmpty {
                            JellyfinEmptyState(
                                systemImage: "rectangle.stack.badge.minus",
                                titleKey: "jellyfin.library.empty",
                                detailKey: "jellyfin.library.empty_detail"
                            )
                            .frame(minHeight: 240)
                        } else {
                            ForEach(seasonGroups, id: \.number) { season in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(seasonTitle(season.number))
                                        .font(.headline.weight(.bold))

                                    ForEach(season.episodes) { episode in
                                        NavigationLink {
                                            JellyfinMediaDetailView(store: store, item: episode)
                                        } label: {
                                            JellyfinEpisodeRow(store: store, episode: episode)
                                        }
                                        .buttonStyle(.plain)
                                        if episode.id != season.episodes.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.top, 22)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(series.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEpisodes() }
    }

    private func loadEpisodes() async {
        isLoading = true
        failed = false
        do {
            episodes = try await store.loadEpisodes(seriesID: series.id)
        } catch {
            failed = true
        }
        isLoading = false
    }

    private var seasonGroups: [(number: Int?, episodes: [JellyfinMediaEntry])] {
        let grouped = Dictionary(grouping: episodes, by: \.seasonNumber)
        return grouped
            .map { (number: $0.key, episodes: $0.value) }
            .sorted { ($0.number ?? Int.max) < ($1.number ?? Int.max) }
    }

    private func seasonTitle(_ number: Int?) -> String {
        guard let number else {
            return NSLocalizedString("jellyfin.season.unknown", comment: "")
        }
        if number == 0 {
            return NSLocalizedString("jellyfin.season.specials", comment: "")
        }
        return String.localizedStringWithFormat(
            NSLocalizedString("jellyfin.season.format", comment: ""),
            number
        )
    }
}

private struct JellyfinEpisodeRow: View {
    @ObservedObject var store: JellyfinLibraryStore
    let episode: JellyfinMediaEntry

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                JellyfinPosterImage(
                    url: store.imageURL(for: episode, width: 480, landscape: true)
                )
                if let progress = episode.effectivePlaybackProgress, progress > 0 {
                    GeometryReader { geometry in
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(AppTheme.accent)
                                .frame(width: geometry.size.width * progress, height: 3)
                        }
                    }
                }
            }
            .frame(width: 132, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(episode.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if !episode.subtitle.isEmpty {
                    Text(episode.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct JellyfinMediaDetailView: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry
    @State private var playbackRequest: MediaPlaybackRequest?
#if DEBUG
    @AppStorage(GreenfieldPlaybackDebugSettings.useGreenfieldPlayerKey)
    private var usesGreenfieldPlayer = true
    @State private var greenfieldPlaybackRequest: GreenfieldPlaybackLaunchRequest?
#endif
    @StateObject private var preparation = PlaybackPreparation()
    private var isPreparingPlayback: Bool { preparation.isPreparing }
    @State private var showPlaybackError = false
    @State private var pendingExternalPlayback: PendingExternalPlayback?
    @State private var pendingShareRequest: MediaPlaybackRequest?
    @State private var showCredentialHandoffWarning = false
    @State private var sharePayload: ServiceSharePayload?
    @State private var selectedAudioStreamIndex: Int?
    @State private var selectedSubtitleStreamIndex: Int?
    @State private var didEditDetailTracks = false
    @State private var detailedItem: JellyfinMediaEntry?
    @State private var localPlaybackStopSnapshot: (itemID: String, position: Double, revision: UUID)?
    @State private var similarItems: [JellyfinMediaEntry] = []
    @State private var isLoadingDetails = false
    @State private var isOverviewExpanded = false

    init(store: JellyfinLibraryStore, item: JellyfinMediaEntry) {
        self.store = store
        self.item = item
        _selectedAudioStreamIndex = State(initialValue: item.defaultAudioStreamIndex)
        _selectedSubtitleStreamIndex = State(initialValue: item.preferredSubtitleStreamIndex)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    JellyfinDetailHeader(store: store, item: mediaItem)

                    VStack(alignment: .leading, spacing: 26) {
                        JellyfinMetadataStrip(item: mediaItem)

                    if let tagline = mediaItem.tagline, !tagline.isEmpty {
                        Text(tagline)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if mediaItem.isPlayable {
                        playbackActionRow
#if DEBUG
                        greenfieldPlaybackToggle
#endif

                        if mediaItem.audioTracks.count > 1 || !mediaItem.subtitleTracks.isEmpty {
                            playbackTrackControls
                        }
                    }

                    if !mediaItem.overview.isEmpty {
                        JellyfinDetailSection(titleKey: "jellyfin.overview.title") {
                            Text(mediaItem.overview)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineSpacing(5)
                                .lineLimit(isOverviewExpanded ? nil : 6)
                                .fixedSize(horizontal: false, vertical: true)
                            if mediaItem.overview.count > 180 {
                                Button(isOverviewExpanded ? "jellyfin.overview.collapse" : "jellyfin.overview.expand") {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isOverviewExpanded.toggle()
                                    }
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }

                    if !mediaItem.people.isEmpty {
                        JellyfinPeopleShelf(store: store, people: Array(mediaItem.people.prefix(18)))
                    }

                    if !similarItems.isEmpty {
                        JellyfinSimilarShelf(store: store, items: similarItems)
                    }

                    if !mediaItem.studios.isEmpty {
                        JellyfinDetailSection(titleKey: "jellyfin.studios.title") {
                            Text(mediaItem.studios.joined(separator: " · "))
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !mediaItem.externalLinks.isEmpty {
                        JellyfinExternalLinksSection(links: mediaItem.externalLinks)
                    }

                    if mediaItem.mediaPath != nil || mediaItem.mediaSize != nil || mediaItem.mediaBitrate != nil {
                        JellyfinFileInformation(item: mediaItem)
                    }

                    if isLoadingDetails {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(Text("jellyfin.details.loading"))
                    }
                    }
                    .frame(
                        width: min(820, max(geometry.size.width - 36, 0)),
                        alignment: .leading
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                    .frame(maxWidth: .infinity)
                }
                .frame(width: geometry.size.width, alignment: .leading)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(mediaItem.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.playbackStopSnapshot?.revision) { _ in
            guard let snapshot = store.playbackStopSnapshot else {
                localPlaybackStopSnapshot = nil
                return
            }
            guard snapshot.itemID == item.id else { return }
            localPlaybackStopSnapshot = snapshot
            didEditDetailTracks = false
            restoreSavedTrackSelection()
        }
        .onDisappear { preparation.cancel() }
        .task(id: item.id) {
            await loadDetailContent()
        }
        .alert("jellyfin.player.prepare_failed", isPresented: $showPlaybackError) {
            Button("action.ok", role: .cancel) {}
        } message: {
            Text("jellyfin.player.prepare_failed_detail")
        }
        .confirmationDialog(
            "external.credential_warning.title",
            isPresented: $showCredentialHandoffWarning,
            titleVisibility: .visible
        ) {
            Button("external.credential_warning.continue") {
                if let pendingExternalPlayback {
                    openExternalPlayback(pendingExternalPlayback)
                } else if let pendingShareRequest {
                    sharePayload = ServiceSharePayload(url: pendingShareRequest.url)
                }
                pendingExternalPlayback = nil
                pendingShareRequest = nil
            }
            Button("action.cancel", role: .cancel) {
                pendingExternalPlayback = nil
                pendingShareRequest = nil
            }
        } message: {
            Text("external.credential_warning.message")
        }
        .sheet(item: $sharePayload) { payload in
            SystemShareView(items: [payload.url])
        }
        .fullScreenCover(item: $playbackRequest, onDismiss: {
            PlayerOrientationController.setPlayerActive(false)
        }) { request in
            NavigationStack {
                BuiltInMediaPlayerView(request: request)
            }
        }
#if DEBUG
        .greenfieldPlaybackCover(item: $greenfieldPlaybackRequest)
#endif
    }

    private var mediaItem: JellyfinMediaEntry {
        var result = detailedItem ?? item
        // Keep the confirmed local stop separate from fetched metadata: a
        // request started before exit can finish afterwards with an old position.
        // Retain this view's snapshot even if another item's stop is published.
        // A newly opened detail view uses fresh server data, not a historical
        // store snapshot that might predate playback on another device.
        if let snapshot = localPlaybackStopSnapshot, snapshot.itemID == item.id {
            let ticks = PlaybackPositionPolicy.ticks(for: snapshot.position)
            result.playbackPositionTicks = ticks
            result.progress = result.runTimeTicks.flatMap { duration in
                duration > 0 ? min(Double(ticks) / Double(duration), 1) : nil
            }
        }
        return result
    }

    @MainActor
    private func loadDetailContent() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        do {
            let loadedItem = try await store.loadDetail(itemID: item.id)
            try Task.checkCancellation()
            detailedItem = loadedItem
            if selectedAudioStreamIndex == nil {
                selectedAudioStreamIndex = loadedItem.defaultAudioStreamIndex
            }
            if selectedSubtitleStreamIndex == nil {
                selectedSubtitleStreamIndex = loadedItem.preferredSubtitleStreamIndex
            }
            restoreSavedTrackSelection()
        } catch {
            guard !Task.isCancelled else { return }
            detailedItem = nil
        }
        do {
            let loadedSimilarItems = try await store.loadSimilarItems(itemID: item.id)
            try Task.checkCancellation()
            similarItems = loadedSimilarItems
        } catch {
            guard !Task.isCancelled else { return }
            similarItems = []
        }
    }

    private var playbackActionRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button { preparePlayback() } label: {
                    HStack(spacing: 10) {
                        if isPreparingPlayback {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(
                            LocalizedStringKey(
                                (mediaItem.effectivePlaybackProgress ?? 0) > 0
                                    ? "media.continue.title"
                                    : "player.play_in_app"
                            )
                        )
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Menu {
                    if !ExternalOpenTarget.installedPlayers.isEmpty {
                        Section {
                            ForEach(ExternalOpenTarget.installedPlayers) { target in
                                Button(target.displayName) {
                                    prepareExternalPlayback(target)
                                }
                            }
                        } header: {
                            Text("external.installed_players")
                        }
                    }
                    Section {
                        Button("external.other_apps") {
                            prepareSharePlayback()
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 54, height: 54)
                        .background(AppTheme.secondarySurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .accessibilityLabel(Text("devices.files.open_external"))
            }
            .disabled(isPreparingPlayback)
            if (mediaItem.effectivePlaybackProgress ?? 0) > 0 {
                Button("player.play_from_beginning") { preparePlayback(fromBeginning: true) }
                    .font(.subheadline.weight(.semibold))
                    .disabled(isPreparingPlayback)
            }
#if DEBUG
            if usesGreenfieldPlayer &&
                ProcessInfo.processInfo.environment["NASTART_TEST_STATIC_HLS"] == "1" {
                Button("静态 HLS 弱网测试") { prepareStaticHLSPlayback() }
                    .font(.subheadline.weight(.semibold))
                    .disabled(isPreparingPlayback)
            }
#endif
        }
    }

#if DEBUG
    private func prepareStaticHLSPlayback() {
        preparation.start { preparationID in
            let request = await DebugStaticHLSFixture.makeRequest()
            guard preparation.isCurrent(preparationID) else {
                request?.playbackTracker?.releasePreparedResources()
                return
            }
            guard let request else { showPlaybackError = true; return }
            PlayerOrientationController.prepareForPresentation(request.initialOrientationMode)
            greenfieldPlaybackRequest = request.greenfieldPlaybackLaunchRequest()
        }
    }
#endif

    private func preparePlayback(fromBeginning: Bool = false) {
        var itemToPlay = mediaItem
        if fromBeginning {
            itemToPlay.progress = 0
            itemToPlay.playbackPositionTicks = 0
        }
        let entry = itemToPlay
        preparation.start { preparationID in
            do {
#if DEBUG
                let requestsGreenfield = usesGreenfieldPlayer
#else
                let requestsGreenfield = false
#endif
                let request = try await store.playbackRequest(
                    for: entry,
                    selection: JellyfinPlaybackSelection(
                        audioStreamIndex: selectedAudioStreamIndex,
                        subtitleStreamIndex: selectedSubtitleStreamIndex
                    ),
                    prefersFastStartupDirectPlay: requestsGreenfield,
                    usesGreenfieldPlayback: requestsGreenfield
                )
                if request != nil {
                    await preparation.holdPreparedResultForDebugIfRequested(preparationID, entry: "jellyfin")
                }
                guard preparation.isCurrent(preparationID) else {
                    request?.playbackTracker?.releasePreparedResources()
                    if let request { AuthenticatedMediaStreamProxy.shared.unregister(request.url) }
                    return
                }
                if let request {
#if DEBUG
                    if requestsGreenfield && !request.isAudioOnly {
                        PlayerOrientationController.prepareForPresentation(request.initialOrientationMode)
                        greenfieldPlaybackRequest = request.greenfieldPlaybackLaunchRequest()
                        return
                    }
#endif
                    PlayerOrientationController.prepareForPresentation(
                        request.initialOrientationMode
                    )
                    playbackRequest = request
                }
            } catch {
                guard preparation.isCurrent(preparationID) else { return }
                showPlaybackError = true
            }
        }
    }

    private func restoreSavedTrackSelection() {
#if DEBUG
        guard usesGreenfieldPlayer, !didEditDetailTracks,
              let saved = store.savedPlaybackTrackSelection(for: mediaItem) else { return }
        selectedAudioStreamIndex = saved.audioStreamIndex
        selectedSubtitleStreamIndex = saved.subtitleStreamIndex
#endif
    }

#if DEBUG
    private var greenfieldPlaybackToggle: some View {
        PlaybackArchitecturePicker(usesGreenfieldPlayer: $usesGreenfieldPlayer)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(AppTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
#endif

    private var playbackTrackControls: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 240), spacing: 10, alignment: .leading)],
            alignment: .leading,
            spacing: 10
        ) {
            if mediaItem.audioTracks.count > 1 {
                Menu {
                    ForEach(mediaItem.audioTracks) { track in
                        Button {
                            selectedAudioStreamIndex = track.index
                            didEditDetailTracks = true
                        } label: {
                            if selectedAudioStreamIndex == track.index {
                                Label(track.title, systemImage: "checkmark")
                            } else {
                                Text(track.title)
                            }
                        }
                    }
                } label: {
                    playbackTrackLabel(
                        systemImage: "waveform",
                        titleKey: "player.audio_tracks",
                        value: mediaItem.audioTracks
                            .first(where: { $0.index == selectedAudioStreamIndex })?
                            .title
                    )
                }
                .frame(maxWidth: .infinity)
            }

            if !mediaItem.subtitleTracks.isEmpty {
                Menu {
                    Button {
                        selectedSubtitleStreamIndex = nil
                        didEditDetailTracks = true
                    } label: {
                        if selectedSubtitleStreamIndex == nil {
                            Label("player.subtitles.off", systemImage: "checkmark")
                        } else {
                            Text("player.subtitles.off")
                        }
                    }
                    ForEach(mediaItem.subtitleTracks) { track in
                        Button {
                            selectedSubtitleStreamIndex = track.index
                            didEditDetailTracks = true
                        } label: {
                            if selectedSubtitleStreamIndex == track.index {
                                Label(track.title, systemImage: "checkmark")
                            } else {
                                Text(track.title)
                            }
                        }
                    }
                } label: {
                    playbackTrackLabel(
                        systemImage: "captions.bubble",
                        titleKey: "player.subtitles",
                        value: mediaItem.subtitleTracks
                            .first(where: { $0.index == selectedSubtitleStreamIndex })?
                            .title
                            ?? NSLocalizedString("player.subtitles.off", comment: "")
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func playbackTrackLabel(
        systemImage: String,
        titleKey: LocalizedStringKey,
        value: String?
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            VStack(alignment: .leading, spacing: 1) {
                Text(titleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value ?? "-")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(AppTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func prepareExternalPlayback(_ target: ExternalOpenTarget) {
        preparation.start { preparationID in
            do {
                guard let request = try await store.externalPlaybackRequest(
                    for: mediaItem,
                    selection: JellyfinPlaybackSelection(
                        audioStreamIndex: selectedAudioStreamIndex,
                        subtitleStreamIndex: selectedSubtitleStreamIndex
                    )
                ) else {
                    throw JellyfinLibraryError.missingPlaybackURL
                }
                guard preparation.isCurrent(preparationID) else { return }
                let pending = PendingExternalPlayback(request: request, target: target)
                if request.containsSensitiveCredential {
                    pendingExternalPlayback = pending
                    showCredentialHandoffWarning = true
                } else {
                    openExternalPlayback(pending)
                }
            } catch {
                guard preparation.isCurrent(preparationID) else { return }
                showPlaybackError = true
            }
        }
    }

    private func prepareSharePlayback() {
        preparation.start { preparationID in
            do {
                guard let request = try await store.externalPlaybackRequest(
                    for: mediaItem,
                    selection: JellyfinPlaybackSelection(
                        audioStreamIndex: selectedAudioStreamIndex,
                        subtitleStreamIndex: selectedSubtitleStreamIndex
                    )
                ) else {
                    throw JellyfinLibraryError.missingPlaybackURL
                }
                guard preparation.isCurrent(preparationID) else { return }
                if request.containsSensitiveCredential {
                    pendingExternalPlayback = nil
                    pendingShareRequest = request
                    showCredentialHandoffWarning = true
                } else {
                    sharePayload = ServiceSharePayload(url: request.url)
                }
            } catch {
                guard preparation.isCurrent(preparationID) else { return }
                showPlaybackError = true
            }
        }
    }

    private func openExternalPlayback(_ pending: PendingExternalPlayback) {
        guard let targetURL = pending.target.url(
            endpoint: pending.request.url,
            filename: pending.request.externalFilename,
            subtitleURL: pending.request.externalSubtitleURL
        ) else {
            recordExternalHandoff(accepted: false, pending: pending, reason: "invalidCallbackURL")
            sharePayload = ServiceSharePayload(url: pending.request.url)
            return
        }
        UIApplication.shared.open(targetURL, options: [:]) { accepted in
            recordExternalHandoff(
                accepted: accepted,
                pending: pending,
                reason: accepted ? "accepted" : "applicationRejectedURL"
            )
            if !accepted {
                DispatchQueue.main.async {
                    sharePayload = ServiceSharePayload(url: pending.request.url)
                }
            }
        }
    }

    private func recordExternalHandoff(
        accepted: Bool,
        pending: PendingExternalPlayback,
        reason: String
    ) {
        DiagnosticLogStore.shared.record(
            accepted ? .info : .error,
            categoryKey: "diagnostics.category.media",
            messageKey: accepted
                ? "diagnostics.media.external_handoff_accepted"
                : "diagnostics.media.external_handoff_failed",
            details: [
                "targetApp": pending.target.diagnosticName,
                "extension": pending.request.fileExtensionHint.isEmpty
                    ? "-"
                    : pending.request.fileExtensionHint,
                "mode": pending.request.fileExtensionHint == "m3u8"
                    ? "serverNegotiatedHLS"
                    : "serverNegotiatedMedia",
                "reason": reason
            ]
        )
    }
}

private struct PendingExternalPlayback {
    let request: MediaPlaybackRequest
    let target: ExternalOpenTarget
}

private struct JellyfinDetailHeader: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            JellyfinPosterImage(
                url: store.imageURL(
                    for: item,
                    width: 1600,
                    landscape: true,
                    prefersBackdrop: true
                )
            )
            LinearGradient(
                colors: [.black.opacity(0.08), .clear, .black.opacity(0.86)],
                startPoint: .top,
                endPoint: .bottom
            )
            HStack(alignment: .bottom, spacing: 14) {
                if item.imageTag != nil {
                    JellyfinPosterImage(
                        url: store.imageURL(for: item, width: 360),
                        scalesToFit: true
                    )
                    .frame(width: horizontalSizeClass == .regular ? 118 : 92)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .background(Color.black.opacity(0.24))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(.white.opacity(0.28), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 6, y: 2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(2)
                    }
                    if let originalTitle = item.originalTitle,
                       !originalTitle.isEmpty,
                       originalTitle.caseInsensitiveCompare(item.title) != .orderedSame {
                        Text(originalTitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: horizontalSizeClass == .regular ? 390 : 310)
        .overlay(alignment: .topTrailing) {
            Button {
                Task { await store.toggleFavorite(item) }
            } label: {
                Image(systemName: store.isFavorite(item) ? "heart.fill" : "heart")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(store.isFavorite(item) ? AppTheme.accent : .white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("jellyfin.favorite.toggle"))
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
    }
}

private struct JellyfinMetadataStrip: View {
    let item: JellyfinMediaEntry

    var body: some View {
        if hasMetadata {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: 14, alignment: .leading)],
                alignment: .leading,
                spacing: 12
            ) {
                if let communityRating = item.communityRating {
                    JellyfinMetadataFact(
                        value: communityRating.formatted(.number.precision(.fractionLength(1))),
                        systemImage: "star.fill",
                        iconColor: .yellow
                    )
                }
                if let officialRating = item.officialRating, !officialRating.isEmpty {
                    JellyfinMetadataFact(value: officialRating, systemImage: "person.crop.rectangle")
                }
                if let videoDescription = item.videoDescription, !videoDescription.isEmpty {
                    JellyfinMetadataFact(value: videoDescription, systemImage: "film")
                }
                if let audioDescription = item.audioDescription, !audioDescription.isEmpty {
                    JellyfinMetadataFact(value: audioDescription, systemImage: "speaker.wave.2")
                }
                if let premiereDate = item.premiereDate {
                    JellyfinMetadataFact(
                        value: premiereDate.formatted(date: .abbreviated, time: .omitted),
                        systemImage: "calendar"
                    )
                } else if let productionYear = item.productionYear {
                    JellyfinMetadataFact(value: String(productionYear), systemImage: "calendar")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !item.genres.isEmpty {
                Label(item.genres.joined(separator: " · "), systemImage: "tag")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var hasMetadata: Bool {
        item.communityRating != nil
            || item.officialRating?.isEmpty == false
            || !item.genres.isEmpty
            || item.videoDescription?.isEmpty == false
            || item.audioDescription?.isEmpty == false
            || item.productionYear != nil
            || item.premiereDate != nil
    }
}

private struct JellyfinMetadataFact: View {
    let value: String
    let systemImage: String
    var iconColor: Color = .secondary

    var body: some View {
        Label {
            Text(value)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(iconColor)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct JellyfinDetailSection<Content: View>: View {
    let titleKey: LocalizedStringKey
    let content: Content

    init(titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleKey)
                .font(.title3.weight(.bold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct JellyfinPeopleShelf: View {
    @ObservedObject var store: JellyfinLibraryStore
    let people: [JellyfinPersonEntry]

    var body: some View {
        JellyfinDetailSection(titleKey: "jellyfin.people.title") {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(people) { person in
                        VStack(alignment: .leading, spacing: 7) {
                            JellyfinPosterImage(url: store.personImageURL(for: person, width: 280))
                                .frame(width: 104, height: 132)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Text(person.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(person.role.flatMap { $0.isEmpty ? nil : $0 } ?? (person.type ?? ""))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(width: 104, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct JellyfinSimilarShelf: View {
    @ObservedObject var store: JellyfinLibraryStore
    let items: [JellyfinMediaEntry]

    var body: some View {
        JellyfinDetailSection(titleKey: "jellyfin.similar.title") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink {
                            JellyfinMediaDetailView(store: store, item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                JellyfinPosterImage(url: store.imageURL(for: item, width: 360))
                                    .frame(width: 126, height: 186)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                Text(item.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2, reservesSpace: true)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !item.subtitle.isEmpty {
                                    Text(item.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(width: 126, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct JellyfinExternalLinksSection: View {
    let links: [JellyfinExternalLink]

    var body: some View {
        JellyfinDetailSection(titleKey: "jellyfin.links.title") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(links) { link in
                        Link(destination: link.url) {
                            Label(link.name, systemImage: "arrow.up.right.square")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
            }
        }
    }
}

private struct JellyfinFileInformation: View {
    let item: JellyfinMediaEntry

    var body: some View {
        JellyfinDetailSection(titleKey: "jellyfin.file.title") {
            VStack(spacing: 0) {
                if let path = item.mediaPath, !path.isEmpty {
                    row(titleKey: "jellyfin.file.name", value: URL(fileURLWithPath: path).lastPathComponent)
                }
                if let container = item.container, !container.isEmpty {
                    row(titleKey: "jellyfin.file.container", value: container.uppercased())
                }
                if let size = item.mediaSize, size > 0 {
                    row(
                        titleKey: "jellyfin.file.size",
                        value: ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                    )
                }
                if let bitrate = item.mediaBitrate, bitrate > 0 {
                    row(
                        titleKey: "jellyfin.file.bitrate",
                        value: String(format: "%.1f Mbps", Double(bitrate) / 1_000_000)
                    )
                }
            }
            .background(AppTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func row(titleKey: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

#if DEBUG
/// Explicit test source for exercising adaptive handoff without opening a NAS
/// encoder. Both renditions are pre-encoded Apple HLS example playlists.
@MainActor
enum DebugStaticHLSFixture {
    private static let base = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc"

    static func makeRequest(low: Bool = false,
                            source: MediaPlaybackSource = .jellyfin) async -> MediaPlaybackRequest? {
        let upstream = URL(string: "\(base)/\(low ? "v4" : "v9")/prog_index.m3u8")!
        let traceID = String(UUID().uuidString.prefix(8))
        guard let proxyURL = try? await AuthenticatedMediaStreamProxy.shared.register(
            upstreamURL: upstream, filename: "static-hls-fixture.m3u8",
            allowsSelfSignedCertificates: false, playbackTraceID: traceID) else { return nil }
        let tracker = MediaPlaybackTracker(releaseResources: {
            AuthenticatedMediaStreamProxy.shared.unregister(proxyURL)
        }, eventHandler: { _ in })
        let bitrate = low ? 1_300_000 : 8_000_000
        return MediaPlaybackRequest(
            url: proxyURL, title: "Static HLS fixture", source: source,
            contentKind: .video, fileExtensionOverride: "m3u8",
            prefersSubtitlesDisabled: true, timelineOffsetSeconds: 0,
            totalDurationSeconds: 600, estimatedBitrate: bitrate,
            streamBitrateCeiling: bitrate, isPrivateNetworkRoute: false,
            playbackTracker: tracker,
            compatibilityFallbackRequestLoader: low ? nil : { _ in
                await makeRequest(low: true, source: source)
            },
            selectedQualityID: "auto", playbackTraceID: traceID)
    }
}
#endif
