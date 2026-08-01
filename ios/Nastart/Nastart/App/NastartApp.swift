import SwiftUI
import UIKit

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

@MainActor
enum PlayerOrientationController {
    static func setPlayerActive(_ isActive: Bool) {
        let mask: UIInterfaceOrientationMask
        if UIDevice.current.userInterfaceIdiom == .pad {
            mask = .all
        } else {
            mask = isActive ? .allButUpsideDown : .portrait
        }
        NastartAppDelegate.supportedOrientations = mask

        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.first(where: \.isKeyWindow)?
                .rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
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

@main
struct NastartApp: App {
    @UIApplicationDelegateAdaptor(NastartAppDelegate.self) private var appDelegate
    @StateObject private var appDataStore = AppDataStore()
    @StateObject private var connectionStore = NASConnectionStore()
    @StateObject private var entitlementStore = EntitlementStore()
    @StateObject private var appearanceStore = AppearanceStore()
    @StateObject private var diagnosticLogStore = DiagnosticLogStore.shared
    @State private var didAttemptRestore = false
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @AppStorage(AppThemeMode.storageKey) private var appThemeModeRaw = AppThemeMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            AppTabRootView()
                .environmentObject(appDataStore)
                .environmentObject(connectionStore)
                .environmentObject(entitlementStore)
                .environmentObject(appearanceStore)
                .environmentObject(diagnosticLogStore)
                .environment(\.locale, selectedLanguage.locale)
                .preferredColorScheme(preferredColorScheme)
                .task {
                    guard !didAttemptRestore else { return }
                    didAttemptRestore = true
                    await appDataStore.restoreDSMConnection(using: connectionStore)
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
