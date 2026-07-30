import SwiftUI
import UIKit

struct MineView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(profileStore.avatarInitial)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 54, height: 54)
                            .background(AppTheme.secondarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(connectionStore.connectedDevice?.name ?? profileStore.nickname)
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            HStack(spacing: 6) {
                                Text(LocalizedStringKey(connectionStore.profileSubtitleKey))
                                Text("-")
                                Text(LocalizedStringKey(entitlementStore.plusStatus.titleKey))
                            }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                        .layoutPriority(1)
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    NavigationLink {
                        PlusView()
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("mine.plus.title")
                                    .font(.headline.weight(.medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                Text("mine.plus.subtitle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.82)
                            }
                            .layoutPriority(1)

                            Spacer(minLength: 12)

                            Text("mine.plus.action")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(AppTheme.primaryAction)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("mine.appearance.title", systemImage: "paintpalette")
                    }
                    NavigationLink {
                        PlayerSettingsView()
                    } label: {
                        Label("mine.players.title", systemImage: "play.rectangle")
                    }
                    NavigationLink {
                        SyncSettingsView()
                    } label: {
                        Label("mine.sync.title", systemImage: "icloud")
                    }
                    NavigationLink {
                        PrivacySecurityView()
                    } label: {
                        Label("mine.privacy.title", systemImage: "lock.shield")
                    }
                    NavigationLink {
                        HelpAboutView()
                    } label: {
                        Label("mine.about.title", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("mine.section.settings")
                }

                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Label("mine.sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .disabled(!connectionStore.isConnected)
                } footer: {
                    Text("mine.sign_out.footer")
                }
            }
            .navigationTitle("tab.mine")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("mine.sign_out.confirm", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("mine.sign_out", role: .destructive) {
                    connectionStore.signOut()
                    dataStore.clearConnectionData()
                }
                Button("action.cancel", role: .cancel) {}
            } message: {
                Text("mine.sign_out.message")
            }
        }
    }
}

private struct ProfileEditView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @State private var showAvatarSheet = false
    @State private var showSavedHint = false

    var body: some View {
        List {
            Section {
                Button {
                    showAvatarSheet = true
                } label: {
                    VStack(spacing: 12) {
                        Text(profileStore.avatarInitial)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 82, height: 82)
                            .background(AppTheme.secondarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        Text("mine.profile.avatar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
                .buttonStyle(.plain)
            }

            Section {
                TextField("mine.profile.nickname", text: $profileStore.nickname)
            }

            Section {
                Button {
                    showSavedHint = true
                } label: {
                    Text("action.save")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("mine.profile.edit")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("mine.profile.avatar", isPresented: $showAvatarSheet) {
            Button("mine.profile.use_system_avatar") {
                profileStore.avatarInitial = "N"
            }
            Button("mine.profile.choose_photo") {
                profileStore.avatarInitial = "P"
            }
            Button("mine.profile.take_photo") {
                profileStore.avatarInitial = "C"
            }
            Button("action.cancel", role: .cancel) {}
        }
        .alert("mine.profile.saved_hint", isPresented: $showSavedHint) {
            Button("action.ok", role: .cancel) {}
        }
    }
}

private struct PlusView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @State private var showSubscribeHint = false
    @State private var showRestoreHint = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("mine.plus.title")
                        .font(.title2.weight(.bold))
                    Text("plus.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey(entitlementStore.plusStatus.titleKey))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(entitlementStore.hasPlus ? AppTheme.accent : .secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                PlusPlanRow(
                    titleKey: "plus.plan.monthly",
                    priceKey: "plus.plan.monthly.price",
                    badgeKey: nil
                )
                PlusPlanRow(
                    titleKey: "plus.plan.yearly",
                    priceKey: "plus.plan.yearly.price",
                    badgeKey: "plus.plan.yearly.badge"
                )
            } header: {
                Text("plus.pricing")
            } footer: {
                Text("plus.pricing.note")
            }

            Section {
                PlusFeatureRow(titleKey: "plus.feature.cards", symbol: "square.grid.2x2")
                PlusFeatureRow(titleKey: "plus.feature.icloud", symbol: "icloud")
                PlusFeatureRow(titleKey: "plus.feature.themes", symbol: "paintpalette")
                PlusFeatureRow(titleKey: "plus.feature.reminders", symbol: "bell.badge")
            } header: {
                Text("plus.includes")
            }

            Section {
                Button {
                    showSubscribeHint = true
                } label: {
                    HStack {
                        Text("plus.action.subscribe")
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.headline.weight(.semibold))
                    }
                }
                .buttonStyle(NastartPrimaryButtonStyle())
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            Section {
                Button("plus.action.restore") {
                    entitlementStore.restorePurchases()
                    showRestoreHint = true
                }
                Button("plus.action.manage") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                }
            } header: {
                Text("plus.subscription")
            } footer: {
                Text("plus.subscription.footer")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("mine.plus.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("plus.subscribe_hint", isPresented: $showSubscribeHint) {
            Button("action.ok", role: .cancel) {}
        }
        .alert("plus.restore_hint", isPresented: $showRestoreHint) {
            Button("action.ok", role: .cancel) {}
        }
    }
}

private struct PlusPlanRow: View {
    let titleKey: String
    let priceKey: String
    let badgeKey: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(titleKey))
                    .font(.body.weight(.medium))
                Text(LocalizedStringKey(priceKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            Spacer(minLength: 12)
            if let badgeKey {
                Text(LocalizedStringKey(badgeKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PlusFeatureRow: View {
    let titleKey: LocalizedStringKey
    let symbol: String

    var body: some View {
        Label(titleKey, systemImage: symbol)
            .padding(.vertical, 3)
    }
}

private struct AppearanceSettingsView: View {
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @AppStorage(LaunchpadTheme.storageKey) private var launchpadThemeRaw = LaunchpadTheme.cleanGrid.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @AppStorage(AppThemeMode.storageKey) private var appThemeModeRaw = AppThemeMode.system.rawValue

    var body: some View {
        Form {
            Section {
                Picker(selection: $appLanguageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.titleKey)).tag(language.rawValue)
                    }
                } label: {
                    Label("mine.appearance.language", systemImage: "globe")
                }

                Picker(selection: $appThemeModeRaw) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.titleKey)).tag(mode.rawValue)
                    }
                } label: {
                    Label("mine.appearance.display", systemImage: "circle.lefthalf.filled")
                }

                NavigationLink {
                    LaunchpadThemeGalleryView()
                } label: {
                    HStack(spacing: 12) {
                        Label("mine.appearance.theme", systemImage: "paintpalette")
                        Spacer()
                        Text(LocalizedStringKey(selectedTheme.titleKey))
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $appearanceStore.compactMetrics) {
                    Label("mine.appearance.compact_metrics", systemImage: "rectangle.compress.vertical")
                }
                Toggle(isOn: $appearanceStore.showServiceStatus) {
                    Label("mine.appearance.status_dot", systemImage: "circle.circle")
                }
                NavigationLink {
                    CardItemsSettingsView()
                } label: {
                    Label("mine.appearance.card_items", systemImage: "list.bullet.rectangle")
                }
                NavigationLink {
                    LaunchpadGroupOrderView()
                } label: {
                    Label("mine.appearance.group_order", systemImage: "line.3.horizontal.decrease")
                }
            } header: {
                Text("mine.appearance.launchpad")
            }
        }
        .navigationTitle("mine.appearance.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedTheme: LaunchpadTheme {
        LaunchpadTheme(rawValue: launchpadThemeRaw) ?? .cleanGrid
    }
}

private struct LaunchpadThemeGalleryView: View {
    @AppStorage(LaunchpadTheme.storageKey) private var launchpadThemeRaw = LaunchpadTheme.cleanGrid.rawValue

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(LaunchpadTheme.allCases) { theme in
                    NavigationLink {
                        LaunchpadThemePreviewDetailView(theme: theme)
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            LaunchpadThemePreviewArtwork(theme: theme, expanded: false)

                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(LocalizedStringKey(theme.titleKey))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(LocalizedStringKey(theme.descriptionKey))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                }
                                .layoutPriority(1)

                                Spacer(minLength: 8)

                                if theme.rawValue == launchpadThemeRaw {
                                    Text("mine.appearance.theme.active")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.accent)
                                } else if theme.isPremium {
                                    Text("mine.appearance.theme.plus_badge")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(AppTheme.primaryAction)
                                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(AppTheme.hairline, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("mine.appearance.theme.gallery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LaunchpadThemePreviewDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @AppStorage(LaunchpadTheme.storageKey) private var launchpadThemeRaw = LaunchpadTheme.cleanGrid.rawValue

    let theme: LaunchpadTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LaunchpadThemePreviewArtwork(theme: theme, expanded: true)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: theme.symbolName)
                            .foregroundStyle(AppTheme.accent)
                        Text(LocalizedStringKey(theme.titleKey))
                            .font(.title3.weight(.semibold))
                        if theme.isPremium {
                            Text("mine.appearance.theme.plus_badge")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(LocalizedStringKey(theme.descriptionKey))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                if isActive {
                    Text("mine.appearance.theme.active")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else if canApply {
                    Button("mine.appearance.theme.apply") {
                        applyTheme()
                    }
                    .buttonStyle(NastartPrimaryButtonStyle())
                } else {
                    NavigationLink {
                        PlusView()
                    } label: {
                        HStack {
                            Text("mine.appearance.theme.unlock")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(NastartPrimaryButtonStyle())

                    Text("mine.appearance.theme.locked_hint")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(16)
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("mine.appearance.theme.preview")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isActive: Bool {
        launchpadThemeRaw == theme.rawValue
    }

    private var canApply: Bool {
        !theme.isPremium || entitlementStore.canUse(.advancedThemes)
    }

    private func applyTheme() {
        launchpadThemeRaw = theme.rawValue
        appearanceStore.launchpadTheme = theme
        dismiss()
    }
}

private struct LaunchpadThemePreviewArtwork: View {
    let theme: LaunchpadTheme
    let expanded: Bool

    var body: some View {
        Group {
            switch theme {
            case .cleanGrid:
                cleanPreview
            case .commandCenter:
                commandPreview
            case .glassDeck:
                glassPreview
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: expanded ? 390 : 190)
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 26 : 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: expanded ? 26 : 18, style: .continuous)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        }
    }

    private var cleanPreview: some View {
        VStack(alignment: .leading, spacing: expanded ? 14 : 8) {
            previewHeader(inverted: false)
            HStack(spacing: 7) {
                previewMetric(symbol: "cpu", value: "11%")
                previewMetric(symbol: "memorychip", value: "32%")
                previewMetric(symbol: "internaldrive", value: "2.9 TB")
            }
            VStack(spacing: expanded ? 10 : 6) {
                previewService(symbol: "server.rack", title: "DSM", inverted: false)
                previewService(symbol: "play.rectangle", title: "Jellyfin", inverted: false)
                if expanded {
                    previewService(symbol: "arrow.down.circle", title: "Downloads", inverted: false)
                }
            }
        }
        .padding(expanded ? 20 : 12)
        .background(Color(.systemGroupedBackground))
    }

    private var commandPreview: some View {
        HStack(alignment: .top, spacing: expanded ? 14 : 8) {
            VStack(spacing: expanded ? 18 : 10) {
                previewRailMetric(symbol: "cpu", value: "11%")
                previewRailMetric(symbol: "memorychip", value: "32%")
                previewRailMetric(symbol: "internaldrive", value: "2.9T")
            }
            .padding(.vertical, expanded ? 18 : 10)
            .frame(width: expanded ? 74 : 48)
            .background(AppTheme.primaryAction)
            .clipShape(RoundedRectangle(cornerRadius: expanded ? 20 : 14, style: .continuous))

            VStack(alignment: .leading, spacing: expanded ? 12 : 7) {
                previewHeader(inverted: false)
                previewService(symbol: "server.rack", title: "DSM", inverted: false)
                previewService(symbol: "shippingbox", title: "Container", inverted: false)
                previewService(symbol: "play.rectangle", title: "Jellyfin", inverted: false)
                if expanded {
                    previewService(symbol: "network", title: "Network", inverted: false)
                }
            }
        }
        .padding(expanded ? 20 : 12)
        .background(
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color(.secondarySystemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var glassPreview: some View {
        VStack(alignment: .leading, spacing: expanded ? 14 : 8) {
            VStack(alignment: .leading, spacing: 10) {
                previewHeader(inverted: false)
                HStack(spacing: 7) {
                    previewMetric(symbol: "cpu", value: "11%")
                    previewMetric(symbol: "memorychip", value: "32%")
                    previewMetric(symbol: "internaldrive", value: "2.9 TB")
                }
            }
            .padding(expanded ? 16 : 10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: expanded ? 22 : 14, style: .continuous))

            previewService(symbol: "play.rectangle", title: "Jellyfin", inverted: false)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: expanded ? 18 : 12, style: .continuous))
            previewService(symbol: "music.note", title: "Navidrome", inverted: false)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: expanded ? 18 : 12, style: .continuous))
            if expanded {
                previewService(symbol: "network", title: "Network", inverted: false)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(expanded ? 20 : 12)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemIndigo).opacity(0.16),
                    AppTheme.accent.opacity(0.11),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func previewHeader(inverted: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("DS918+")
                    .font((expanded ? Font.headline : Font.caption).weight(.semibold))
                Text("DSM 7.2")
                    .font(expanded ? .caption : .caption2)
                    .opacity(0.58)
            }
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(expanded ? .body : .caption)
        }
        .foregroundStyle(inverted ? Color.white : Color.primary)
    }

    private func previewMetric(symbol: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: expanded ? 7 : 4) {
            Image(systemName: symbol)
                .font(expanded ? .caption : .caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font((expanded ? Font.subheadline : Font.caption2).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(expanded ? 11 : 7)
        .background(Color(.systemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 14 : 9, style: .continuous))
    }

    private func previewRailMetric(symbol: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(expanded ? .caption : .caption2)
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font((expanded ? Font.caption : Font.caption2).weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func previewService(symbol: String, title: String, inverted: Bool) -> some View {
        HStack(spacing: expanded ? 11 : 7) {
            Image(systemName: symbol)
                .font(expanded ? .subheadline : .caption2)
                .frame(width: expanded ? 32 : 22, height: expanded ? 32 : 22)
                .background((inverted ? Color.white : Color.primary).opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: expanded ? 9 : 6, style: .continuous))
            Text(title)
                .font((expanded ? Font.subheadline : Font.caption2).weight(.medium))
                .lineLimit(1)
            Spacer()
            Circle()
                .fill(Color.green)
                .frame(width: expanded ? 7 : 5, height: expanded ? 7 : 5)
        }
        .foregroundStyle(inverted ? Color.white : Color.primary)
        .padding(.horizontal, expanded ? 12 : 8)
        .frame(minHeight: expanded ? 52 : 30)
        .background(inverted ? Color.white.opacity(0.08) : Color(.systemBackground).opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 16 : 10, style: .continuous))
    }
}

private struct CardItemsSettingsView: View {
    @AppStorage(AppearancePreferenceKeys.showCardSubtitle) private var showSubtitle = false
    @AppStorage(AppearancePreferenceKeys.showCardCPU) private var showCPU = true
    @AppStorage(AppearancePreferenceKeys.showCardMemory) private var showMemory = true
    @AppStorage(AppearancePreferenceKeys.showCardPorts) private var showPorts = false
    @AppStorage(AppearancePreferenceKeys.showCardLibraryCounts) private var showLibraryCounts = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $showSubtitle) {
                    Label("mine.appearance.item.subtitle", systemImage: "text.alignleft")
                }
                Toggle(isOn: $showCPU) {
                    Label("mine.appearance.item.cpu", systemImage: "cpu")
                }
                Toggle(isOn: $showMemory) {
                    Label("mine.appearance.item.memory", systemImage: "memorychip")
                }
                Toggle(isOn: $showPorts) {
                    Label("mine.appearance.item.ports", systemImage: "network")
                }
                Toggle(isOn: $showLibraryCounts) {
                    Label("mine.appearance.item.library", systemImage: "rectangle.stack")
                }
            } header: {
                Text("mine.appearance.card_items")
            } footer: {
                Text("mine.appearance.card_items_footer")
            }
        }
        .navigationTitle("mine.appearance.card_items")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LaunchpadGroupOrderView: View {
    @AppStorage(AppearancePreferenceKeys.groupFavoritesExpanded) private var expandedFavorites = true
    @AppStorage(AppearancePreferenceKeys.groupMediaExpanded) private var expandedMedia = true
    @AppStorage(AppearancePreferenceKeys.groupDownloadsExpanded) private var expandedDownloads = true
    @AppStorage(AppearancePreferenceKeys.groupNetworkExpanded) private var expandedNetwork = true
    @AppStorage(AppearancePreferenceKeys.groupToolsExpanded) private var expandedTools = true
    @AppStorage(AppearancePreferenceKeys.groupOrder) private var groupOrderRaw = ServiceCategory.defaultOrderStorageValue

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $expandedFavorites) {
                    Label("category.favorites", systemImage: ServiceCategory.favorites.symbolName)
                }
                Toggle(isOn: $expandedMedia) {
                    Label("category.media", systemImage: ServiceCategory.media.symbolName)
                }
                Toggle(isOn: $expandedDownloads) {
                    Label("category.downloads", systemImage: ServiceCategory.downloads.symbolName)
                }
                Toggle(isOn: $expandedNetwork) {
                    Label("category.network", systemImage: ServiceCategory.network.symbolName)
                }
                Toggle(isOn: $expandedTools) {
                    Label("category.tools", systemImage: ServiceCategory.tools.symbolName)
                }
            } header: {
                Text("mine.appearance.group_default")
            } footer: {
                Text("mine.appearance.group_footer")
            }

            Section {
                ForEach(orderedCategories) { category in
                    HStack {
                        Label(LocalizedStringKey(category.titleKey), systemImage: category.symbolName)
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                    }
                }
                .onMove(perform: moveGroup)
            } header: {
                Text("mine.appearance.group_order")
            }
        }
        .navigationTitle("mine.appearance.group_order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
    }

    private var orderedCategories: [ServiceCategory] {
        ServiceCategory.ordered(from: groupOrderRaw)
    }

    private func moveGroup(from source: IndexSet, to destination: Int) {
        var categories = orderedCategories
        categories.move(fromOffsets: source, toOffset: destination)
        groupOrderRaw = ServiceCategory.storageValue(for: categories)
    }
}

private struct PlayerSettingsView: View {
    @State private var defaultVideo = "Infuse"
    @State private var defaultAudio = "Navidrome"
    @State private var preferExternal = true

    var body: some View {
        Form {
            Section {
                Picker(selection: $defaultVideo) {
                    Text("Infuse").tag("Infuse")
                    Text("VidHub").tag("VidHub")
                    Text("VLC").tag("VLC")
                    Text("player.system").tag("System Player")
                } label: {
                    Label("mine.players.video", systemImage: "play.rectangle")
                }
                Picker(selection: $defaultAudio) {
                    Text("Navidrome").tag("Navidrome")
                    Text("player.system").tag("System Player")
                    Text("player.custom_scheme").tag("Custom Scheme")
                } label: {
                    Label("mine.players.audio", systemImage: "music.note")
                }
                Toggle(isOn: $preferExternal) {
                    Label("mine.players.prefer_external", systemImage: "arrow.up.forward.app")
                }
            } header: {
                Text("mine.players.defaults")
            }

            Section {
                PlayerIntegrationRow(name: "Jellyfin", detailKey: "state.connected")
                PlayerIntegrationRow(name: "Emby", detailKey: "state.not_connected")
                PlayerIntegrationRow(name: "Plex", detailKey: "state.planned")
                PlayerIntegrationRow(name: "Navidrome", detailKey: "state.connected")
            } header: {
                Text("mine.players.integrations")
            }
        }
        .navigationTitle("mine.players.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlayerIntegrationRow: View {
    let name: String
    let detailKey: LocalizedStringKey

    var body: some View {
        HStack {
            Label(name, systemImage: symbolName)
            Spacer()
            Text(detailKey)
                .foregroundStyle(.secondary)
        }
    }

    private var symbolName: String {
        switch name.lowercased() {
        case "jellyfin": return "play.rectangle"
        case "emby": return "play.tv"
        case "plex": return "play.circle"
        case "navidrome": return "music.note.list"
        default: return "app.connected.to.app.below.fill"
        }
    }
}

private struct SyncSettingsView: View {
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @State private var iCloudSync = true
    @State private var syncLaunchpad = true
    @State private var syncReminders = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $iCloudSync) {
                    Label("mine.sync.enable", systemImage: "icloud")
                }
                    .disabled(!entitlementStore.canUse(.iCloudSync))
                Toggle(isOn: $syncLaunchpad) {
                    Label("mine.sync.launchpad", systemImage: "square.grid.2x2")
                }
                    .disabled(!entitlementStore.canUse(.iCloudSync))
                Toggle(isOn: $syncReminders) {
                    Label("mine.sync.reminders", systemImage: "bell")
                }
                    .disabled(!entitlementStore.canUse(.iCloudSync))
            } header: {
                Text("mine.sync.icloud")
            }

            Section {
                HStack {
                    Label("mine.sync.devices", systemImage: "iphone.and.arrow.forward")
                    Spacer()
                    Text("2")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("mine.sync.last", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Text("state.just_now")
                        .foregroundStyle(.secondary)
                }
                if !entitlementStore.hasPlus {
                    NavigationLink {
                        PlusView()
                    } label: {
                        Label("plus.locked.icloud", systemImage: "lock")
                    }
                }
            } header: {
                Text("mine.sync.scope")
            }
        }
        .navigationTitle("mine.sync.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacySecurityView: View {
    @State private var biometricUnlock = true
    @State private var clipboardCheck = true
    @State private var showCacheHint = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $biometricUnlock) {
                    Label("mine.privacy.faceid", systemImage: "faceid")
                }
                Toggle(isOn: $clipboardCheck) {
                    Label("mine.privacy.clipboard", systemImage: "doc.on.clipboard")
                }
                NavigationLink {
                    KeychainSettingsView()
                } label: {
                    Label("mine.privacy.keychain", systemImage: "key")
                }
            } header: {
                Text("mine.privacy.security")
            }

            Section {
                NavigationLink {
                    DataExportView()
                } label: {
                    Label("mine.privacy.export", systemImage: "square.and.arrow.up")
                }
                Button {
                    showCacheHint = true
                } label: {
                    Label("mine.privacy.clear_cache", systemImage: "trash")
                }
            } header: {
                Text("mine.privacy.data")
            }
        }
        .navigationTitle("mine.privacy.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("mine.privacy.clear_cache_hint", isPresented: $showCacheHint) {
            Button("action.ok", role: .cancel) {}
        }
    }
}

private struct KeychainSettingsView: View {
    @State private var messageKey = "mine.privacy.keychain_rotate_hint"
    @State private var showHint = false

    var body: some View {
        List {
            Section {
                Text("mine.privacy.keychain_desc")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }

            Section {
                SecureItemRow(titleKey: "mine.privacy.keychain.dsm", detailKey: "state.connected")
                SecureItemRow(titleKey: "mine.privacy.keychain.agent", detailKey: "state.connected")
                SecureItemRow(titleKey: "mine.privacy.keychain.media", detailKey: "state.not_connected")
            } header: {
                Text("mine.privacy.keychain_items")
            }

            Section {
                Button {
                    show("mine.privacy.keychain_rotate_hint")
                } label: {
                    Label("mine.privacy.keychain.rotate", systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive) {
                    KeychainStore.shared.clearNASCredentials()
                    show("mine.privacy.keychain_clear_hint")
                } label: {
                    Label("mine.privacy.keychain.clear", systemImage: "trash")
                }
            } header: {
                Text("mine.privacy.keychain_actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("mine.privacy.keychain")
        .navigationBarTitleDisplayMode(.inline)
        .alert(LocalizedStringKey(messageKey), isPresented: $showHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func show(_ key: String) {
        messageKey = key
        showHint = true
    }
}

private struct SecureItemRow: View {
    let titleKey: LocalizedStringKey
    let detailKey: LocalizedStringKey

    var body: some View {
        HStack {
            Label(titleKey, systemImage: "key")
            Spacer()
            Text(detailKey)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DataExportView: View {
    @State private var includeLaunchpad = true
    @State private var includeReminders = true
    @State private var includeSettings = true
    @State private var includeSecrets = false
    @State private var showExportHint = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $includeLaunchpad) {
                    Label("mine.privacy.export.launchpad", systemImage: "square.grid.2x2")
                }
                Toggle(isOn: $includeReminders) {
                    Label("mine.privacy.export.reminders", systemImage: "bell")
                }
                Toggle(isOn: $includeSettings) {
                    Label("mine.privacy.export.settings", systemImage: "gearshape")
                }
                Toggle(isOn: $includeSecrets) {
                    Label("mine.privacy.export.secrets", systemImage: "key")
                }
            } header: {
                Text("mine.privacy.export_scope")
            } footer: {
                Text("mine.privacy.export_footer")
            }

            Section {
                Button {
                    showExportHint = true
                } label: {
                    Label("mine.privacy.export", systemImage: "square.and.arrow.up")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .navigationTitle("mine.privacy.export")
        .navigationBarTitleDisplayMode(.inline)
        .alert("mine.privacy.export_hint", isPresented: $showExportHint) {
            Button("action.ok", role: .cancel) {}
        }
    }
}

private struct HelpAboutView: View {
    @EnvironmentObject private var diagnostics: DiagnosticLogStore
    @State private var messageKey = "mine.about.feedback_hint"
    @State private var showHint = false

    var body: some View {
        List {
            Section {
                LabeledContent("Nastart", value: "0.1.0")
                LabeledContent("mine.about.compatibility", value: "DSM 7.2+")
            }

            Section {
                NavigationLink {
                    DiagnosticLogsView()
                } label: {
                    Label("diagnostics.title", systemImage: "stethoscope")
                }
                Button {
                    show("mine.about.feedback_hint")
                } label: {
                    Label("mine.about.feedback", systemImage: "bubble.left.and.bubble.right")
                }
                Button {
                    show("mine.about.privacy_hint")
                } label: {
                    Label("mine.about.privacy", systemImage: "hand.raised")
                }
                Button {
                    show("mine.about.terms_hint")
                } label: {
                    Label("mine.about.terms", systemImage: "doc.text")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("mine.about.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert(LocalizedStringKey(messageKey), isPresented: $showHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func show(_ key: String) {
        messageKey = key
        showHint = true
    }
}

private struct DiagnosticLogsView: View {
    @EnvironmentObject private var diagnostics: DiagnosticLogStore
    @State private var showCopiedHint = false

    private var reversedEntries: [DiagnosticLogEntry] {
        Array(diagnostics.entries.reversed())
    }

    var body: some View {
        List {
            Section {
                if reversedEntries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("diagnostics.empty")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                } else {
                    ForEach(reversedEntries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(LocalizedStringKey(entry.messageKey))
                                    .font(.headline.weight(.medium))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.82)
                                Spacer(minLength: 8)
                                Text(entry.displayTime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 8) {
                                Text(LocalizedStringKey(entry.categoryKey))
                                Text(LocalizedStringKey(entry.level.titleKey))
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(levelColor(entry.level))

                            if !entry.detail.isEmpty {
                                Text(entry.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            } header: {
                Text("diagnostics.recent")
            } footer: {
                Text("diagnostics.footer")
            }

            Section {
                ShareLink(item: diagnostics.exportText()) {
                    Label("diagnostics.export", systemImage: "square.and.arrow.up")
                }
                Button {
                    UIPasteboard.general.string = diagnostics.exportText()
                    showCopiedHint = true
                } label: {
                    Label("diagnostics.copy", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) {
                    diagnostics.clear()
                } label: {
                    Label("diagnostics.clear", systemImage: "trash")
                }
                .disabled(diagnostics.entries.isEmpty)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("diagnostics.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("diagnostics.copy_done", isPresented: $showCopiedHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func levelColor(_ level: DiagnosticLogLevel) -> Color {
        switch level {
        case .info: return .secondary
        case .warning: return AppTheme.accent
        case .error: return .red
        }
    }
}
