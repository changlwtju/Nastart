import SwiftUI

@main
struct NastartApp: App {
    @StateObject private var appDataStore = AppDataStore()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var connectionStore = NASConnectionStore()
    @StateObject private var entitlementStore = EntitlementStore()
    @StateObject private var appearanceStore = AppearanceStore()

    var body: some Scene {
        WindowGroup {
            AppTabRootView()
                .environmentObject(appDataStore)
                .environmentObject(profileStore)
                .environmentObject(connectionStore)
                .environmentObject(entitlementStore)
                .environmentObject(appearanceStore)
        }
    }
}
