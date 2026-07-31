import SwiftUI

@main
struct NastartApp: App {
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
