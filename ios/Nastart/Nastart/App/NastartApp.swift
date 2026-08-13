import SwiftUI
import UIKit
import CloudKit

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
        let configuration = orientationConfiguration(for: mode)
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
            applyPlayerOrientationMode(initialMode)
            return
        }
        NastartAppDelegate.supportedOrientations = .portrait
        updateScenes(
            preferredOrientation: .portrait,
            retryDelays: [0, 150_000_000, 350_000_000, 700_000_000]
        )
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
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(NastartAppDelegate.self) private var appDelegate
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

    var body: some Scene {
        WindowGroup {
            Group {
#if DEBUG
                if let playbackLabRequest {
                    NavigationStack {
                        BuiltInMediaPlayerView(request: playbackLabRequest)
                    }
                } else if didCompleteRestore || appDataStore.hasCachedDSMSnapshot {
                    AppTabRootView()
                } else {
                    DSMConnectionRestoreView()
                }
#else
                if didCompleteRestore || appDataStore.hasCachedDSMSnapshot {
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
                    if appDataStore.hasCachedDSMSnapshot {
                        didCompleteRestore = true
                    }
                    await appDataStore.restoreDSMConnection(using: connectionStore)
                    didCompleteRestore = true
                    if cloudSyncStore.isEnabled {
                        await cloudSyncStore.syncNow(
                            dataStore: appDataStore,
                            appearanceStore: appearanceStore
                        )
                    }
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

    private var preferredColorScheme: ColorScheme? {
        switch AppThemeMode(rawValue: appThemeModeRaw) ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

#if DEBUG
private enum PlaybackLabLaunchRequest {
    static func makeRequest(
        environment: [String: String] = ProcessInfo.processInfo.environment
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
        let directResource = MediaPlaybackResource(
            url: url,
            fileExtensionOverride: fileExtension
        )
        return MediaPlaybackRequest(
            url: url,
            title: title,
            source: source,
            fileExtensionOverride: fileExtension,
            initialPosition: initialPosition,
            initialOrientationMode: .landscape,
            isPrivateNetworkRoute: isPrivateNetworkRoute,
            compatibilityFallbackResource: MediaPlaybackResource(
                url: url,
                fileExtensionOverride: fileExtension,
                forcesSoftwareDecoding: true
            ),
            externalHandoffResource: directResource
        )
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
