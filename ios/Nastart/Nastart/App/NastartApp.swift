import SwiftUI
import UIKit
import CloudKit
import NetworkMedia

final class NastartAppDelegate: NSObject, UIApplicationDelegate {
    static var supportedOrientations: UIInterfaceOrientationMask = defaultOrientations

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.supportedOrientations
    }

    private static var defaultOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait
    }
}

enum PlayerOrientationMode: String, CaseIterable, Identifiable {
    case automatic
    case portrait
    case landscape

    var id: String { rawValue }

    var localizationKey: LocalizedStringKey {
        switch self {
        case .automatic: return "player.orientation.automatic"
        case .portrait: return "player.orientation.portrait"
        case .landscape: return "player.orientation.landscape"
        }
    }

    var systemImage: String {
        switch self {
        case .automatic: return "rectangle.portrait.rotate"
        case .portrait: return "rectangle.portrait"
        case .landscape: return "rectangle"
        }
    }
}

@MainActor
enum PlayerOrientationController {
    private static var updateRevision = 0

    static func prepareForPresentation(_ mode: PlayerOrientationMode) {
        let configuration = orientationConfiguration(for: initialMode(mode))
        NastartAppDelegate.supportedOrientations = configuration.supported
        updateScenes(
            preferredOrientation: configuration.preferred,
            // On iPhone, presenting the player can race scene activation (most
            // visibly when launched from Xcode or an external handoff). Give
            // iOS a few more geometry-update opportunities before reporting a
            // real orientation failure.
            retryDelays: [0, 150_000_000, 350_000_000, 700_000_000]
        )
    }

    static func setPlayerActive(
        _ isActive: Bool,
        initialMode: PlayerOrientationMode = .automatic
    ) {
        if isActive {
            applyPlayerOrientationMode(self.initialMode(initialMode))
            return
        }
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        NastartAppDelegate.supportedOrientations = isPad ? .all : .portrait
        updateScenes(
            // iPad windows choose their orientation from the device and window
            // geometry. Forcing portrait here resizes a landscape window on exit.
            preferredOrientation: isPad ? nil : .portrait,
            retryDelays: [0, 150_000_000, 350_000_000, 700_000_000]
        )
    }

    /// A forced landscape request turns a portrait iPad app into a small landscape
    /// window on iPadOS 26, so opening a player on iPad follows the device instead.
    private static func initialMode(_ mode: PlayerOrientationMode) -> PlayerOrientationMode {
        UIDevice.current.userInterfaceIdiom == .pad && mode == .landscape ? .automatic : mode
    }

    static func requestPlayerOrientation(_ orientation: UIInterfaceOrientationMask) {
        applyPlayerOrientationMode(orientation == .portrait ? .portrait : .landscape)
    }

    static func applyPlayerOrientationMode(_ mode: PlayerOrientationMode) {
        let configuration = orientationConfiguration(for: mode)
        NastartAppDelegate.supportedOrientations = configuration.supported
        updateScenes(
            preferredOrientation: configuration.preferred,
            retryDelays: [0, 150_000_000, 350_000_000, 700_000_000]
        )
    }

    private static func orientationConfiguration(
        for mode: PlayerOrientationMode
    ) -> (supported: UIInterfaceOrientationMask, preferred: UIInterfaceOrientationMask?) {
        switch mode {
        case .automatic:
            return (
                UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown,
                nil
            )
        case .portrait:
            return (.portrait, .portrait)
        case .landscape:
            return (.landscape, .landscape)
        }
    }

    private static func updateScenes(
        preferredOrientation: UIInterfaceOrientationMask?,
        retryDelays: [UInt64]
    ) {
        updateRevision += 1
        let revision = updateRevision
        let expectedOrientations = NastartAppDelegate.supportedOrientations
        Task { @MainActor in
            for (index, delay) in retryDelays.enumerated() {
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: delay)
                }
                guard
                    revision == updateRevision,
                    NastartAppDelegate.supportedOrientations == expectedOrientations
                else {
                    return
                }
                let isFinalAttempt = index == retryDelays.count - 1
                for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                    for window in scene.windows {
                        markOrientationUpdate(in: window.rootViewController)
                    }
                    guard let preferredOrientation else { continue }
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: preferredOrientation)) { error in
                        guard isFinalAttempt else { return }
                        DiagnosticLogStore.shared.record(
                            .warning,
                            categoryKey: "diagnostics.category.media",
                            messageKey: "diagnostics.media.orientation_update_failed",
                            details: ["error": error.localizedDescription]
                        )
                    }
                }
            }
        }
    }

    private static func markOrientationUpdate(in viewController: UIViewController?) {
        guard let viewController else { return }
        viewController.setNeedsUpdateOfSupportedInterfaceOrientations()
        viewController.children.forEach { markOrientationUpdate(in: $0) }
        markOrientationUpdate(in: viewController.presentedViewController)
    }
}

@main
struct NastartApp: App {
    @UIApplicationDelegateAdaptor(NastartAppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
#if DEBUG
            if let configuration = OfflineUIConfiguration.requested(arguments: ProcessInfo.processInfo.arguments) {
                NastartOfflineUIRoot(configuration: configuration)
            } else { NastartApplicationContent() }
#else
            NastartApplicationContent()
#endif
        }
    }
}

private struct NastartApplicationContent: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appDataStore = AppDataStore()
    @StateObject private var connectionStore = NASConnectionStore()
    @StateObject private var entitlementStore = EntitlementStore()
    @StateObject private var appearanceStore = AppearanceStore()
    @StateObject private var cloudSyncStore = CloudSyncStore.shared
    @StateObject private var diagnosticLogStore = DiagnosticLogStore.shared
    @State private var didAttemptRestore = false
    @State private var didCompleteRestore = false
#if DEBUG
    @State private var playbackLabRequest = PlaybackLabLaunchRequest.makeRequest()
#endif
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @AppStorage(AppThemeMode.storageKey) private var appThemeModeRaw = AppThemeMode.system.rawValue
    private static let startupRestoreGraceNanoseconds: UInt64 = 12_000_000_000

    var body: some View {
        Group {
            Group {
#if DEBUG
                if let playbackLabRequest {
                    PlaybackLabPlayerView(directRequest: playbackLabRequest)
                } else if canShowMainApp {
                    AppTabRootView()
                } else {
                    DSMConnectionRestoreView()
                }
#else
                if canShowMainApp {
                    AppTabRootView()
                } else {
                    DSMConnectionRestoreView()
                }
#endif
            }
                .environmentObject(appDataStore)
                .environmentObject(connectionStore)
                .environmentObject(entitlementStore)
                .environmentObject(appearanceStore)
                .environmentObject(cloudSyncStore)
                .environmentObject(diagnosticLogStore)
                .environment(\.locale, selectedLanguage.locale)
                .onChange(of: appLanguageRaw) { _ in selectedLanguage.applyToBundleLanguageOnNextLaunch() }
                .preferredColorScheme(preferredColorScheme)
                .onOpenURL { url in
                    ExternalPlaybackCallbackHandler.handle(url)
                }
                .task {
#if DEBUG
                    guard playbackLabRequest == nil else { return }
#endif
                    guard !didAttemptRestore else { return }
                    didAttemptRestore = true
                    // Render the last known NAS state immediately. The login and
                    // snapshot refresh continue in the background and replace it
                    // when the network is ready.
                    let hasCachedSnapshot = appDataStore.hasCachedDSMSnapshot
                    if hasCachedSnapshot {
                        didCompleteRestore = true
                    }

                    Task { @MainActor in
                        await appDataStore.restoreDSMConnection(using: connectionStore)
                        didCompleteRestore = true
                        if cloudSyncStore.isEnabled {
                            await cloudSyncStore.syncNow(
                                dataStore: appDataStore,
                                appearanceStore: appearanceStore
                            )
                        }
                    }

                    guard !hasCachedSnapshot else { return }
                    try? await Task.sleep(nanoseconds: Self.startupRestoreGraceNanoseconds)
                    if !didCompleteRestore {
                        DiagnosticLogStore.shared.record(
                            .warning,
                            categoryKey: "diagnostics.category.connection",
                            messageKey: "diagnostics.connection.restore_timeout",
                            details: ["timeoutSeconds": "12"]
                        )
                        didCompleteRestore = true
                    }
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        if didCompleteRestore {
                            await appDataStore.monitorConnectivity(using: connectionStore)
                        }
                        do { try await Task.sleep(nanoseconds: 15_000_000_000) }
                        catch { return }
                    }
                }
                .onChange(of: connectionStore.isConnected) { connected in
                    if connected { didCompleteRestore = true }
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active, didCompleteRestore else { return }
                    Task {
                        await appDataStore.refreshForForeground(using: connectionStore)
                        if cloudSyncStore.isEnabled {
                            await cloudSyncStore.syncNow(
                                dataStore: appDataStore,
                                appearanceStore: appearanceStore
                            )
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
                    guard cloudSyncStore.isEnabled else { return }
                    Task {
                        await cloudSyncStore.syncNow(
                            dataStore: appDataStore,
                            appearanceStore: appearanceStore
                        )
                    }
                }
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    private var canShowMainApp: Bool {
        appDataStore.hasCachedDSMSnapshot
            || didCompleteRestore
    }

    private var preferredColorScheme: ColorScheme? {
        switch AppThemeMode(rawValue: appThemeModeRaw) ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

#if DEBUG
private struct PlaybackLabPlayerView: View {
    let directRequest: MediaPlaybackRequest
    @State private var proxiedRequest: MediaPlaybackRequest?
    @State private var preparationFailed = false
    @State private var greenfieldRequest: GreenfieldPlaybackLaunchRequest?
    @State private var didPresentGreenfield = false
    private let environment = ProcessInfo.processInfo.environment

    var body: some View {
        Group {
            if !PlaybackLabLaunchRequest.usesProxy(environment: environment) {
                player(directRequest)
            } else if let proxiedRequest {
                player(proxiedRequest)
            } else if preparationFailed {
                Text("Playback Lab preparation failed")
            } else {
                ProgressView()
            }
        }
        .task {
            guard PlaybackLabLaunchRequest.usesProxy(environment: environment),
                  proxiedRequest == nil else { return }
            do {
                proxiedRequest = try await PlaybackLabLaunchRequest.makeProxiedRequest(environment: environment)
            } catch {
                if !Task.isCancelled { preparationFailed = true }
            }
        }
        .onDisappear {
            // Presenting the full-screen host hides this diagnostic root.
            // Its player owns the active route until close/PiP shutdown.
            if environment["NASTART_PLAYBACK_LAB_ARCHITECTURE"] != "greenfield" {
                proxiedRequest?.playbackTracker?.releasePreparedResources()
            }
        }
    }

    private func player(_ request: MediaPlaybackRequest) -> some View {
        Group {
            if environment["NASTART_PLAYBACK_LAB_ARCHITECTURE"] == "greenfield" {
                PlaybackLabGreenfieldPresentation(request: $greenfieldRequest)
                    .onAppear {
                        guard !didPresentGreenfield else { return }
                        didPresentGreenfield = true
                        greenfieldRequest = request.greenfieldPlaybackLaunchRequest()
                    }
            } else {
                NavigationStack { BuiltInMediaPlayerView(request: request) }
            }
        }
    }
}

// Candidate evidence must use the normal full-screen host, including Home
// indicator, dismissal and PiP ownership, rather than a root NavigationStack.
struct PlaybackLabGreenfieldPresentation: View {
    @Binding var request: GreenfieldPlaybackLaunchRequest?

    var body: some View {
        Color.black.ignoresSafeArea()
            .greenfieldPlaybackCover(item: $request)
    }
}

enum PlaybackLabLaunchRequest {
    /// Explicit diagnostic source only. The server supplies failure/supply
    /// conditions; the normal sampler, cooldown and retry budget still decide
    /// whether and when to invoke these negotiation continuations.
    static func automaticRetryConfiguration(environment: [String: String]) -> (url: URL, duration: Double)? {
        guard environment["NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY"] == "1",
              !usesProxy(environment: environment),
              environment["NASTART_PLAYBACK_LAB_CANDIDATE"] != "1" else { return nil }
        var candidate = environment
        candidate["NASTART_PLAYBACK_LAB_CANDIDATE"] = "1"
        candidate["NASTART_PLAYBACK_LAB_CANDIDATE_URL"] = environment["NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_URL"]
        candidate["NASTART_PLAYBACK_LAB_CANDIDATE_DURATION"] = environment["NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY_DURATION"]
        return candidateConfiguration(environment: candidate)
    }

    @MainActor
    static func makeAutomaticRetryCandidate(environment: [String: String], currentCeiling: Int,
        sourceTraceID: String, runtime: MediaPlaybackRuntimeState?) async throws -> MediaPlaybackRequest? {
        guard let configuration = automaticRetryConfiguration(environment: environment) else {
            throw URLError(.unsupportedURL)
        }
        try Task.checkCancellation()
        let capacity = PlaybackRecentThroughputStore.shared.estimate(
            traceID: sourceTraceID, now: ProcessInfo.processInfo.systemUptime)
        guard let lower = PlaybackAdaptiveBitratePolicy.target(currentCeiling: currentCeiling,
            capacity: capacity, networkKey: PlaybackNetworkObserver.shared.snapshot().cacheKey),
              var components = URLComponents(url: configuration.url, resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = (components.queryItems ?? []).filter { $0.name != "ceiling" }
            + [URLQueryItem(name: "ceiling", value: String(lower))]
        guard let upstream = components.url else { throw URLError(.badURL) }
        let trace = String(UUID().uuidString.prefix(8))
        let proxy = AuthenticatedMediaStreamProxy.shared
        let url = try await proxy.register(upstreamURL: upstream, filename: "automatic-retry-lab.m3u8",
            allowsSelfSignedCertificates: false, playbackTraceID: trace)
        let tracker = MediaPlaybackTracker(releaseResources: { proxy.unregister(url) }, eventHandler: { _ in })
        var handedOff = false
        defer { if !handedOff { tracker.releasePreparedResources() } }
        try Task.checkCancellation()
        let source: MediaPlaybackSource = environment["NASTART_PLAYBACK_LAB_SOURCE"] == "jellyfin" ? .jellyfin : .dsmFile
        let request = MediaPlaybackRequest(url: url, title: "Automatic Retry Candidate Lab", source: source,
            fileExtensionOverride: "m3u8", prefersSubtitlesDisabled: true,
            totalDurationSeconds: configuration.duration, estimatedBitrate: lower,
            streamBitrateCeiling: lower, isPrivateNetworkRoute: true, playbackTracker: tracker,
            compatibilityFallbackRequestLoader: { state in
                try? await makeAutomaticRetryCandidate(environment: environment, currentCeiling: lower,
                    sourceTraceID: trace, runtime: state)
            }, selectedQualityID: "auto", playbackTraceID: trace)
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.playback",
            messageKey: "diagnostics.playback.debug_automatic_retry_negotiated", details: [
                "fromCeiling": String(currentCeiling), "toCeiling": String(lower),
                "sourceTraceID": sourceTraceID, "playbackTraceID": trace,
                "capacity": capacity.map(String.init) ?? "unknown"
            ])
        handedOff = true
        return runtime.map { request.applyingRuntimePreferences($0) } ?? request
    }

    /// This manual lab trigger exercises the real replacement path without
    /// changing automatic adaptation rules or fetching a candidate in advance.
    static func candidateConfiguration(environment: [String: String]) -> (url: URL, duration: Double)? {
        guard environment["NASTART_PLAYBACK_LAB_CANDIDATE"] == "1",
              environment["NASTART_PLAYBACK_LAB_ARCHITECTURE"] == "greenfield",
              let original = environment["NASTART_PLAYBACK_LAB_URL"].flatMap(URL.init(string:)),
              let url = environment["NASTART_PLAYBACK_LAB_CANDIDATE_URL"].flatMap(URL.init(string:)),
              let scheme = original.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.scheme?.lowercased() == scheme, let host = original.host, !host.isEmpty,
              url.host == host, url.port == original.port,
              original.user == nil, original.password == nil, url.user == nil, url.password == nil,
              url.pathExtension.lowercased() == "m3u8",
              let duration = environment["NASTART_PLAYBACK_LAB_CANDIDATE_DURATION"].flatMap(Double.init),
              duration.isFinite, duration > 0 else { return nil }
        return (url, duration)
    }

    @MainActor
    static func makeCandidateRequest(environment: [String: String]) async throws -> MediaPlaybackRequest {
        guard let configuration = candidateConfiguration(environment: environment) else {
            throw URLError(.unsupportedURL)
        }
        try Task.checkCancellation()
        let trace = String(UUID().uuidString.prefix(8))
        let proxy = AuthenticatedMediaStreamProxy.shared
        let url = try await proxy.register(upstreamURL: configuration.url,
            filename: "candidate-lab.m3u8", allowsSelfSignedCertificates: false, playbackTraceID: trace)
        let tracker = MediaPlaybackTracker(releaseResources: { proxy.unregister(url) }, eventHandler: { _ in })
        var handedOff = false
        defer { if !handedOff { tracker.releasePreparedResources() } }
        try Task.checkCancellation()
        let request = MediaPlaybackRequest(url: url, title: "Candidate Lab", source: .jellyfin,
            fileExtensionOverride: "m3u8", prefersSubtitlesDisabled: true,
            totalDurationSeconds: configuration.duration, isPrivateNetworkRoute: true,
            playbackTracker: tracker, selectedQualityID: "original", playbackTraceID: trace)
        handedOff = true
        return request
    }

    static func usesProxy(environment: [String: String]) -> Bool {
        environment["NASTART_PLAYBACK_LAB_PROXY"] == "1"
    }

    static func makeRequest(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        playbackURL: URL? = nil,
        tracker: MediaPlaybackTracker? = nil,
        traceID: String? = nil
    ) -> MediaPlaybackRequest? {
        guard let rawURL = environment["NASTART_PLAYBACK_LAB_URL"],
              let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        let title = environment["NASTART_PLAYBACK_LAB_TITLE"] ?? "Playback Lab"
        let fileExtension = environment["NASTART_PLAYBACK_LAB_EXTENSION"]
            ?? url.pathExtension.lowercased()
        let initialPosition = environment["NASTART_PLAYBACK_LAB_POSITION"]
            .flatMap(Double.init)
        let isPrivateNetworkRoute = environment["NASTART_PLAYBACK_LAB_NETWORK"] != "wan"
        let source: MediaPlaybackSource = environment["NASTART_PLAYBACK_LAB_SOURCE"] == "jellyfin"
            ? .jellyfin
            : .dsmFile
        let retryEnabled = environment["NASTART_PLAYBACK_LAB_AUTOMATIC_RETRY"] == "1"
        if retryEnabled && automaticRetryConfiguration(environment: environment) == nil { return nil }
        // The launch bridge converts a resume fraction using known duration.
        // Keep the manual candidate lab's validated duration on its original
        // request too, so a deep-position diagnostic does not start at zero.
        let duration = retryEnabled ? automaticRetryConfiguration(environment: environment)?.duration
            : candidateConfiguration(environment: environment)?.duration
        let effectiveTraceID = traceID ?? (retryEnabled ? String(UUID().uuidString.prefix(8)) : nil)
        let retryLoader: ((MediaPlaybackRuntimeState?) async -> MediaPlaybackRequest?)? =
            retryEnabled ? { state in
                try? await makeAutomaticRetryCandidate(environment: environment, currentCeiling: 20_000_000,
                    sourceTraceID: effectiveTraceID!, runtime: state)
            } : nil
        let directResource = MediaPlaybackResource(
            url: url,
            fileExtensionOverride: fileExtension
        )
        return MediaPlaybackRequest(
            url: playbackURL ?? url,
            title: title,
            source: source,
            fileExtensionOverride: fileExtension,
            initialPosition: initialPosition,
            initialOrientationMode: .landscape,
            totalDurationSeconds: duration,
            estimatedBitrate: retryEnabled ? 20_000_000 : nil,
            streamBitrateCeiling: retryEnabled ? 20_000_000 : nil,
            isPrivateNetworkRoute: isPrivateNetworkRoute,
            playbackTracker: tracker,
            compatibilityFallbackResource: MediaPlaybackResource(
                url: playbackURL ?? url,
                fileExtensionOverride: fileExtension,
                forcesSoftwareDecoding: true
            ),
            externalHandoffResource: directResource,
            compatibilityFallbackRequestLoader: retryLoader,
            selectedQualityID: retryEnabled ? "auto" : nil,
            playbackTraceID: effectiveTraceID
        )
    }

    /// Diagnostic topology only. It uses the production proxy without changing
    /// its request, buffering or cancellation policies or negotiating a media session.
    @MainActor
    static func makeProxiedRequest(
        environment: [String: String],
        traceID: String = String(UUID().uuidString.prefix(8))
    ) async throws -> MediaPlaybackRequest {
        try Task.checkCancellation()
        guard usesProxy(environment: environment),
              let direct = makeRequest(environment: environment),
              direct.fileExtensionOverride?.lowercased() == "m3u8" else {
            throw URLError(.unsupportedURL)
        }
        let proxy = AuthenticatedMediaStreamProxy.shared
        let url = try await proxy.register(
            upstreamURL: direct.url, filename: "playback-lab.m3u8",
            allowsSelfSignedCertificates: false, playbackTraceID: traceID)
        let tracker = MediaPlaybackTracker(releaseResources: {
            proxy.unregister(url)
        }, eventHandler: { _ in })
        var handedOff = false
        defer { if !handedOff { tracker.releasePreparedResources() } }
        try Task.checkCancellation()
        if environment["NASTART_PLAYBACK_LAB_PREWARM"] == "1" {
            guard try await proxy.prewarmVODPlaylist(url) else {
                throw URLError(.cannotParseResponse)
            }
        }
        try Task.checkCancellation()
        guard let request = makeRequest(environment: environment, playbackURL: url,
                                        tracker: tracker, traceID: traceID) else {
            throw URLError(.badURL)
        }
        handedOff = true
        return request
    }
}
#endif

private struct DSMConnectionRestoreView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "server.rack")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(AppTheme.primaryAction)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            ProgressView("connect.review.loading")
                .tint(AppTheme.accent)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.groupedBackground)
    }
}
