import SwiftUI
import UIKit
import WebKit

struct MineView: View {
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @State private var showSignOutConfirm = false
    @State private var showSignOutInfo = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PlusView()
                    } label: {
                        HStack(alignment: .center, spacing: 14) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.primaryAction)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 5) {
                                Text("mine.plus.title")
                                    .font(.headline.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                Text(LocalizedStringKey(entitlementStore.hasPlus ? entitlementStore.plusStatus.titleKey : "mine.plus.subtitle"))
                                    .font(.caption)
                                    .foregroundStyle(entitlementStore.hasPlus ? AppTheme.accent : Color.secondary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.82)
                            }
                            .layoutPriority(1)
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Button(role: .destructive) {
                                showSignOutConfirm = true
                            } label: {
                                Label("mine.sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .disabled(!connectionStore.isConnected)

                            ContextInfoButton(
                                isPresented: $showSignOutInfo,
                                message: signOutInfoText
                            )
                        }

                        if !connectionStore.isConnected && dataStore.isRefreshing {
                            Label("mine.sign_out.restoring", systemImage: "arrow.triangle.2.circlepath")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if showSignOutInfo {
                            Text(signOutInfoText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.secondarySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showSignOutInfo)
                }
            }
            .padding(.top, -12)
            .navigationTitle("tab.mine")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("mine.sign_out.confirm", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("mine.sign_out", role: .destructive) {
                    Task {
                        await connectionStore.signOut()
                        dataStore.clearConnectionData()
                    }
                }
                Button("action.cancel", role: .cancel) {}
            } message: {
                Text("mine.sign_out.message")
            }
        }
    }

    private var signOutInfoText: String {
        if connectionStore.isConnected {
            return String(
                format: NSLocalizedString("mine.sign_out.connected_footer %@", comment: ""),
                dataStore.device.name
            )
        }
        return NSLocalizedString("mine.sign_out.footer", comment: "")
    }
}

private struct ContextInfoButton: View {
    @Binding var isPresented: Bool
    let message: String

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .onHover { isHovering in
            isPresented = isHovering
        }
        .accessibilityLabel(Text("action.info"))
        .accessibilityHint(Text(message))
    }
}

private struct PlusView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @State private var selectedPlan: PlusBillingPlan = .yearly

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PlusHeroPanel(
                    statusKey: entitlementStore.plusStatus.titleKey,
                    isActive: entitlementStore.hasPlus
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("plus.pricing")
                        .font(.headline.weight(.semibold))

                    HStack(alignment: .top, spacing: 10) {
                        ForEach(PlusBillingPlan.allCases) { plan in
                            Button {
                                selectedPlan = plan
                            } label: {
                                PlusPlanOption(
                                    plan: plan,
                                    isSelected: !entitlementStore.hasPlus && selectedPlan == plan
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(entitlementStore.hasPlus)
                        }
                    }

                    Text("plus.pricing.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("plus.includes")
                        .font(.headline.weight(.semibold))

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        PlusFeatureTile(titleKey: "plus.feature.cards", symbol: "square.grid.2x2")
                        PlusFeatureTile(titleKey: "plus.feature.icloud", symbol: "icloud")
                        PlusFeatureTile(titleKey: "plus.feature.themes", symbol: "paintpalette")
                        PlusFeatureTile(titleKey: "plus.feature.reminders", symbol: "bell.badge")
                    }
                }

                VStack(spacing: 12) {
                    if entitlementStore.hasPlus {
                        Button {
                            openSubscriptionManagement()
                        } label: {
                            HStack {
                                Text("plus.action.manage")
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(NastartPrimaryButtonStyle())
                    } else {
                        Label("plus.purchase.unavailable", systemImage: "hammer")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(AppTheme.secondarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    Text("plus.subscription.footer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.groupedBackground.ignoresSafeArea())
        .navigationTitle("mine.plus.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            openURL(url)
        }
    }
}

private enum PlusBillingPlan: String, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .monthly: return "plus.plan.monthly"
        case .yearly: return "plus.plan.yearly"
        }
    }

    var priceKey: String {
        switch self {
        case .monthly: return "plus.plan.monthly.price"
        case .yearly: return "plus.plan.yearly.price"
        }
    }

    var detailKey: String {
        switch self {
        case .monthly: return "plus.plan.monthly.detail"
        case .yearly: return "plus.plan.yearly.detail"
        }
    }

    var badgeKey: String? {
        self == .yearly ? "plus.plan.yearly.badge" : nil
    }
}

private struct PlusHeroPanel: View {
    let statusKey: String
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(isActive ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(LocalizedStringKey(statusKey))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.09))
                .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("mine.plus.title")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                Text("plus.description")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(AppTheme.primaryAction)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PlusPlanOption: View {
    let plan: PlusBillingPlan
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(LocalizedStringKey(plan.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityHidden(true)
                }
            }

            Text(LocalizedStringKey(plan.priceKey))
                .font(.title3.weight(.bold))
                .foregroundStyle(isSelected ? AppTheme.accent : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(LocalizedStringKey(plan.detailKey))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let badgeKey = plan.badgeKey {
                Text(LocalizedStringKey(badgeKey))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.accent.opacity(0.1))
                    .clipShape(Capsule())
            } else {
                Spacer(minLength: 22)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? AppTheme.accent : AppTheme.hairline, lineWidth: isSelected ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PlusFeatureTile: View {
    let titleKey: LocalizedStringKey
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            Text(titleKey)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }
}

private struct AppearanceSettingsView: View {
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @AppStorage(LaunchpadTheme.storageKey) private var launchpadThemeRaw = LaunchpadTheme.cleanGrid.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @AppStorage(AppThemeMode.storageKey) private var appThemeModeRaw = AppThemeMode.system.rawValue
    @AppStorage(AppearancePreferenceKeys.showCardSubtitle) private var showCardSubtitle = false

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
                Toggle(isOn: $showCardSubtitle) {
                    Label("mine.appearance.item.subtitle", systemImage: "text.alignleft")
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
                Text("Nastart NAS")
                    .font((expanded ? Font.headline : Font.caption).weight(.semibold))
                Text("DSM")
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
    @EnvironmentObject private var dataStore: AppDataStore

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text("MobileVLCKit")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("mine.players.builtin_engine", systemImage: "play.rectangle")
                }
                LabeledContent {
                    Text("mine.players.internal_first")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("mine.players.opening_mode", systemImage: "arrow.up.forward.app")
                }
            } header: {
                Text("mine.players.defaults")
            } footer: {
                Text("mine.players.behavior_footer")
            }

            Section {
                if ExternalOpenTarget.installedPlayers.isEmpty {
                    Label("mine.players.external_none", systemImage: "app.dashed")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ExternalOpenTarget.installedPlayers) { target in
                        Label(target.displayName, systemImage: "checkmark.circle")
                    }
                }
            } header: {
                Text("mine.players.external_installed")
            }

            Section {
                PlayerIntegrationRow(name: "Jellyfin", status: integrationStatus(for: "jellyfin"))
                PlayerIntegrationRow(name: "Emby", status: integrationStatus(for: "emby"))
                PlayerIntegrationRow(name: "Plex", status: integrationStatus(for: "plex"))
                PlayerIntegrationRow(name: "Navidrome", status: integrationStatus(for: "navidrome"))
            } header: {
                Text("mine.players.integrations")
            }
        }
        .navigationTitle("mine.players.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func integrationStatus(for serviceName: String) -> ServiceStatus? {
        dataStore.services.first {
            $0.name.localizedCaseInsensitiveContains(serviceName)
        }?.status
    }
}

private struct PlayerIntegrationRow: View {
    let name: String
    let status: ServiceStatus?

    var body: some View {
        HStack(spacing: 10) {
            Label(name, systemImage: symbolName)
            Spacer()
            StatusDot(status: status ?? .unknown)
            Text(LocalizedStringKey(detailKey))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var detailKey: String {
        guard let status else { return "state.not_connected" }
        switch status {
        case .online: return "status.online"
        case .installed: return "status.installed"
        case .warning: return "status.warning"
        case .offline: return "status.offline"
        case .unknown: return "status.unknown"
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
    @EnvironmentObject private var cloudSyncStore: CloudSyncStore
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var appearanceStore: AppearanceStore

    var body: some View {
        Form {
            Section {
                Toggle(isOn: syncBinding) {
                    Label("mine.sync.enable", systemImage: "icloud")
                }
                .disabled(!entitlementStore.canUse(.iCloudSync))

                LabeledContent("mine.sync.status") {
                    HStack(spacing: 7) {
                        if cloudSyncStore.status == .checking || cloudSyncStore.status == .syncing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(LocalizedStringKey(cloudSyncStore.status.titleKey))
                            .foregroundStyle(syncStatusColor)
                    }
                }

                if let lastSync = cloudSyncStore.lastSuccessfulSyncAt {
                    LabeledContent("mine.sync.last_success") {
                        Text(lastSync, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }

                if case .failed = cloudSyncStore.status,
                   let detail = syncErrorDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("mine.sync.icloud")
            } footer: {
                Text("mine.sync.scope_detail")
            }

            if cloudSyncStore.isEnabled {
                Section {
                    Button {
                        Task {
                            await cloudSyncStore.syncNow(
                                dataStore: dataStore,
                                appearanceStore: appearanceStore
                            )
                        }
                    } label: {
                        Label("mine.sync.now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(cloudSyncStore.status == .syncing)
                }
            }

            if !entitlementStore.canUse(.iCloudSync) {
                Section {
                    NavigationLink {
                        PlusView()
                    } label: {
                        Label("plus.locked.icloud", systemImage: "lock")
                    }
                } header: {
                    Text("mine.sync.scope")
                }
            }
        }
        .navigationTitle("mine.sync.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await cloudSyncStore.refreshAccountStatus()
        }
    }

    private var syncErrorDetail: String? {
        guard let detail = cloudSyncStore.lastErrorDetail else { return nil }
        if detail == "missing-icloud-entitlement" {
            return NSLocalizedString("mine.sync.error.missing_entitlement", comment: "")
        }
        return detail
    }

    private var syncBinding: Binding<Bool> {
        Binding(
            get: { cloudSyncStore.isEnabled },
            set: { enabled in
                cloudSyncStore.setEnabled(
                    enabled,
                    dataStore: dataStore,
                    appearanceStore: appearanceStore
                )
            }
        )
    }

    private var syncStatusColor: Color {
        switch cloudSyncStore.status {
        case .available: return .green
        case .failed, .noAccount, .restricted: return .orange
        case .disabled, .checking, .syncing: return .secondary
        }
    }
}

private struct PrivacySecurityView: View {
    @State private var showCacheHint = false
    @State private var showCertificateResetHint = false

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    KeychainSettingsView()
                } label: {
                    Label("mine.privacy.keychain", systemImage: "key")
                }
                Button {
                    CertificatePinStore.shared.clearAll()
                    showCertificateResetHint = true
                } label: {
                    Label("mine.privacy.reset_certificates", systemImage: "checkmark.shield")
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
                    URLCache.shared.removeAllCachedResponses()
                    clearTemporaryDownloads()
                    WKWebsiteDataStore.default().removeData(
                        ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                        modifiedSince: .distantPast
                    ) {
                        DispatchQueue.main.async {
                            showCacheHint = true
                        }
                    }
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
        .alert("mine.privacy.reset_certificates_hint", isPresented: $showCertificateResetHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func clearTemporaryDownloads() {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        for name in ["NastartDownloads", "NastartPreviews"] {
            try? FileManager.default.removeItem(
                at: temporaryDirectory.appendingPathComponent(name, isDirectory: true)
            )
        }
    }
}

private struct KeychainSettingsView: View {
    @State private var hasDSMCredential = false
    @State private var showClearConfirmation = false
    @State private var showClearedHint = false

    var body: some View {
        List {
            Section {
                Text("mine.privacy.keychain_desc")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }

            Section {
                SecureItemRow(
                    titleKey: "mine.privacy.keychain.dsm",
                    detailKey: hasDSMCredential ? "state.connected" : "state.not_connected"
                )
            } header: {
                Text("mine.privacy.keychain_items")
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label("mine.privacy.keychain.clear", systemImage: "trash")
                }
                .disabled(!hasDSMCredential)
            } header: {
                Text("mine.privacy.keychain_actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("mine.privacy.keychain")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hasDSMCredential = KeychainStore.shared.loadNASCredential() != nil
        }
        .confirmationDialog(
            "mine.privacy.keychain.clear_confirm",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("mine.privacy.keychain.clear", role: .destructive) {
                KeychainStore.shared.clearNASCredentials()
                hasDSMCredential = false
                showClearedHint = true
            }
            Button("action.cancel", role: .cancel) {}
        }
        .alert("mine.privacy.keychain_clear_hint", isPresented: $showClearedHint) {
            Button("action.ok", role: .cancel) {}
        }
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
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var includeLaunchpad = true
    @State private var includeReminders = true
    @State private var includeSettings = true

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
            } header: {
                Text("mine.privacy.export_scope")
            } footer: {
                Text("mine.privacy.export_footer")
            }

            Section {
                ShareLink(item: exportText) {
                    Label("mine.privacy.export", systemImage: "square.and.arrow.up")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(!hasExportSelection)
            }
        }
        .navigationTitle("mine.privacy.export")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasExportSelection: Bool {
        includeLaunchpad || includeReminders || includeSettings
    }

    private var exportText: String {
        var payload: [String: Any] = [
            "formatVersion": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date())
        ]

        if includeLaunchpad {
            payload["launchpad"] = dataStore.services.map { service in
                [
                    "name": service.name,
                    "category": service.category.rawValue,
                    "visible": dataStore.isServiceVisibleOnLaunchpad(service)
                ] as [String: Any]
            }
        }

        if includeReminders {
            payload["reminders"] = [
                "pending": dataStore.tasks.map { taskExportValue($0) },
                "history": dataStore.completedTasks.map { taskExportValue($0) }
            ]
        }

        if includeSettings {
            payload["settings"] = [
                "launchpadTheme": UserDefaults.standard.string(forKey: LaunchpadTheme.storageKey) ?? LaunchpadTheme.cleanGrid.rawValue,
                "language": UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.system.rawValue,
                "displayMode": UserDefaults.standard.string(forKey: AppThemeMode.storageKey) ?? AppThemeMode.system.rawValue,
                "compactMetrics": UserDefaults.standard.object(forKey: AppearancePreferenceKeys.compactMetrics) as? Bool ?? true,
                "showServiceStatus": UserDefaults.standard.object(forKey: AppearancePreferenceKeys.showServiceStatus) as? Bool ?? true
            ] as [String: Any]
        }

        guard
            JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return text
    }

    private func taskExportValue(_ task: TaskItem) -> [String: Any] {
        var value: [String: Any] = [
            "id": task.id.uuidString,
            "title": task.title,
            "target": task.subtitle,
            "createdAt": ISO8601DateFormatter().string(from: task.createdAt),
            "daysBefore": task.daysBefore,
            "muted": task.isMuted
        ]
        if let completedAt = task.completedAt {
            value["completedAt"] = ISO8601DateFormatter().string(from: completedAt)
        }
        if let targetDate = task.targetDate {
            value["targetDate"] = ISO8601DateFormatter().string(from: targetDate)
        }
        return value
    }
}

private struct HelpAboutView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                LabeledContent("Nastart", value: versionText)
                LabeledContent("mine.about.compatibility", value: "DSM 7.2+")
            }

            Section {
                NavigationLink {
                    DiagnosticLogsView()
                } label: {
                    Label("diagnostics.title", systemImage: "stethoscope")
                }
                Button {
                    if let url = URL(string: "https://github.com/changlwtju/Nastart/issues") {
                        openURL(url)
                    }
                } label: {
                    Label("mine.about.feedback", systemImage: "bubble.left.and.bubble.right")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("mine.about.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
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
