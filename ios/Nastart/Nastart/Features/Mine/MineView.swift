import SwiftUI
import UIKit
import WebKit
import NetworkMedia

struct MineView: View {
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(NastartSettingsDestination.allCases) { destination in
                        NavigationLink { settingsDestination(destination) } label: {
                            HStack {
                                NastartSettingsItemLabel(destination: destination)
                                Spacer(minLength: 8)
                                if destination == .plus && entitlementStore.hasPlus {
                                    Text(LocalizedStringKey(entitlementStore.plusStatus.titleKey))
                                        .font(.caption).foregroundStyle(AppTheme.accent).lineLimit(1)
                                }
                            }
                        }.accessibilityIdentifier("mine.settings." + destination.rawValue)
                    }
                } header: {
                    Text("mine.section.settings")
                }.nastartListSection()

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        MineSignOutRow(canSignOut: connectionStore.isConnected, message: signOutInfoText) {
                            showSignOutConfirm = true
                        }

                        if !connectionStore.isConnected && dataStore.isRestoringConnection {
                            Label("mine.sign_out.restoring", systemImage: "arrow.triangle.2.circlepath")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if !connectionStore.isConnected && dataStore.connectionRecoveryState == .failed {
                            Label(dataStore.connectionRecoveryRejection?.errorDescription
                                    ?? NSLocalizedString("connect.restore.failed_detail", comment: ""),
                                  systemImage: "wifi.exclamationmark")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                    }
                }.nastartListSection()
            }
            .padding(.top, -12)
            .nastartReadableWidth().nastartPageTheme()
            .navigationTitle("tab.mine")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("mine.sign_out.confirm", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("mine.sign_out", role: .destructive) {
                    Task {
                        dataStore.clearConnectionData()
                        await connectionStore.signOut()
                    }
                }
                Button("action.cancel", role: .cancel) {}
            } message: {
                Text("mine.sign_out.message")
            }
        }
    }

    @ViewBuilder private func settingsDestination(_ destination: NastartSettingsDestination) -> some View {
        switch destination {
        case .plus: PlusView()
        case .appearance: AppearanceSettingsView()
        case .player: PlayerSettingsView()
        case .icloud: SyncSettingsView()
        case .privacy: PrivacySecurityView()
        case .help: HelpAboutView()
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

/// The account-backed root owns the action; the row itself never reads account state.
private struct MineSignOutRow: View {
    let canSignOut: Bool
    let message: String
    let requestSignOut: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(role: .destructive, action: requestSignOut) {
                Label("mine.sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(!canSignOut)
            .accessibilityIdentifier("mine.sign_out.action")
            ContextInfoButton(message: message)
        }
    }
}

private struct ContextInfoButton: View {
    let message: String
    @State private var showMessage = false

    var body: some View {
        Button {
            showMessage = true
        } label: {
            Image(systemName: "exclamationmark.circle")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.accent)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        // Borderless keeps this a separate tap target from the sign-out button in the same List row.
        .buttonStyle(.borderless)
        .accessibilityLabel(Text("action.info"))
        .accessibilityIdentifier("mine.sign_out.info")
        .alert(Text("action.info"), isPresented: $showMessage) {
            Button("action.ok", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

private struct PlusView: View {
    @EnvironmentObject private var entitlementStore: EntitlementStore
    private var membership: NastartPlusMembership {
        switch entitlementStore.plusStatus {
        case .free: return .free
        case .active: return .active
        case .expired: return .expired
        }
    }
    var body: some View {
        ScrollView {
            NastartPlusOverview(membership: membership, surface: AnyView(NastartSurfaceBackground()))
                .padding(16).padding(.bottom, 12)
        }.background { NastartThemeBackground() }.nastartReadableWidth().nastartPageTheme()
            .navigationTitle("mine.plus.title").navigationBarTitleDisplayMode(.inline)
    }
}

/// 语言与显示模式两行。正式设置页与离线界面测试共用同一份绑定代码；
/// 存储位置由宿主的 `defaultAppStorage` 决定（正式环境为标准偏好域）。
struct AppearanceModeRows: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @AppStorage(AppThemeMode.storageKey) private var appThemeModeRaw = AppThemeMode.system.rawValue

    var body: some View {
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
    }
}

/// 启动台卡片三项开关。紧凑指标/服务状态走 `AppearanceStore`，卡片副标题走 `@AppStorage`，
/// 与以往的绑定方式一致；宿主决定偏好域。
struct LaunchpadCardOptionRows: View {
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @AppStorage(AppearancePreferenceKeys.showCardSubtitle) private var showCardSubtitle = false

    var body: some View {
        NastartLaunchpadCardRows(compactMetrics: $appearanceStore.compactMetrics,
            showServiceStatus: $appearanceStore.showServiceStatus, showCardSubtitle: $showCardSubtitle)
    }
}

private struct AppearanceSettingsView: View {
    @EnvironmentObject private var appearanceStore: AppearanceStore

    var body: some View {
        Form {
            Section {
                AppearanceModeRows()

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
                LaunchpadCardOptionRows()
                NavigationLink {
                    LaunchpadGroupOrderView()
                } label: {
                    Label("mine.appearance.group_order", systemImage: "line.3.horizontal.decrease")
                }
            } header: {
                Text("mine.appearance.launchpad")
            } footer: {
                Text("mine.appearance.theme.scope")
            }.nastartListSection()
        }
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("mine.appearance.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedTheme: LaunchpadTheme {
        appearanceStore.launchpadTheme
    }
}

private struct LaunchpadThemeGalleryView: View {
    @EnvironmentObject private var appearanceStore: AppearanceStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(LaunchpadTheme.allCases) { theme in
                    NavigationLink {
                        LaunchpadThemePreviewDetailView(theme: theme)
                    } label: {
                        LaunchpadThemeCardLabel(
                            theme: theme,
                            isSelected: theme == appearanceStore.launchpadTheme
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background { NastartThemeBackground() }
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("mine.appearance.theme.gallery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Gallery card content. Isolated hosts inject surfaces to avoid the production theme stores.
/// The decorative artwork is hidden from accessibility; title, description and status are read
/// together as one element of the surrounding link. At accessibility sizes the description is no
/// longer truncated and the status moves below the text instead of competing for the same row.
private struct LaunchpadThemeCardLabel: View {
    let theme: LaunchpadTheme
    let isSelected: Bool
    var isolatedSurface: AnyView? = nil
    var isolatedArtworkBackground: AnyView? = nil

    @Environment(\.dynamicTypeSize) private var typeSize

    private var textLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LaunchpadThemePreviewArtwork(theme: theme, expanded: false, isolatedBackground: isolatedArtworkBackground)

            textLayout {
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(theme.titleKey))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(LocalizedStringKey(theme.descriptionKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
                }
                .layoutPriority(1)

                if !typeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }

                if isSelected {
                    Text("mine.appearance.theme.active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .fixedSize()
                } else if theme.isPremium {
                    Text("mine.appearance.theme.plus_badge")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.primaryAction)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
        }
        .padding(14)
        .background {
            if let isolatedSurface { isolatedSurface }
            else { NastartSurfaceBackground() }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LaunchpadThemePreviewDetailView: View {
    @Environment(\.showLaunchpad) private var showLaunchpad
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var appearanceStore: AppearanceStore

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
                        .nastartSurface()
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
        .background { NastartThemeBackground() }
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("mine.appearance.theme.preview")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isActive: Bool {
        appearanceStore.launchpadTheme == theme
    }

    private var canApply: Bool {
        !theme.isPremium || entitlementStore.canUse(.advancedThemes)
    }

    private func applyTheme() {
        appearanceStore.launchpadTheme = theme
        dismiss()
        showLaunchpad()
    }
}

private struct LaunchpadThemePreviewArtwork: View {
    let theme: LaunchpadTheme
    let expanded: Bool
    var isolatedBackground: AnyView? = nil

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
        // This is a miniature illustration, not readable UI. Keep its composition stable while
        // the separate title, description and status continue to follow the user's text size.
        .dynamicTypeSize(.large)
        .frame(maxWidth: .infinity)
        .frame(height: expanded ? 390 : 190)
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 26 : 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: expanded ? 26 : 18, style: .continuous)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        }
        // Decorative mock-up with fixed sample values (DSM, 11%, 2.9 TB); never real NAS state.
        .accessibilityHidden(true)
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
        .background {
            if let isolatedBackground { isolatedBackground }
            else { NastartThemeBackground() }
        }
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
            }.nastartListSection()

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
            }.nastartListSection()
        }
        .nastartReadableWidth().nastartPageTheme()
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
                NastartPlayerDefaultsRows()
            } header: {
                Text("mine.players.defaults")
            } footer: {
                Text("mine.players.behavior_footer")
            }.nastartListSection()

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
            }.nastartListSection()

            Section {
                NastartPlayerIntegrationRows(state: integrationState)
            } header: {
                Text("mine.players.integrations")
            } footer: { NastartPlayerIntegrationNotice() }.nastartListSection()
        }
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("mine.players.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func integrationState(for product: MediaServiceProduct) -> NastartPlayerServiceState {
        guard let status = dataStore.services.first(where: {
            $0.name.localizedCaseInsensitiveContains(product.rawValue)
        })?.status else { return .notObserved }
        switch status {
        case .online: return .online
        case .installed: return .installed
        case .warning: return .warning
        case .offline: return .stopped
        case .unknown: return .unknown
        }
    }
}

struct SyncSettingsPresentation {
    enum LastSuccess: Equatable { case waiting, time(Date) }
    enum SyncNow: Equatable { case hidden, ready, syncing }

    let canUseSync: Bool
    let isEnabled: Bool
    let status: CloudSyncAvailability
    let lastSuccessfulSyncAt: Date?
    let hasPendingChanges: Bool

    var isToggleDisabled: Bool { !canUseSync }
    var showsPlusLink: Bool { !canUseSync }
    var syncNow: SyncNow {
        guard isEnabled else { return .hidden }
        return status == .syncing ? .syncing : .ready
    }
    var lastSuccess: LastSuccess {
        lastSuccessfulSyncAt.map(LastSuccess.time) ?? .waiting
    }
    var statusTitleKey: String {
        status == .available && hasPendingChanges ? "mine.sync.status.ready" : status.titleKey
    }

    var syncErrorDetailKey: String? {
        guard case .failed(let code) = status else { return nil }
        switch code {
        case "missing-icloud-entitlement": return "mine.sync.error.missing_entitlement"
        case CloudSyncError.payloadTooLarge.diagnosticCode: return "mine.sync.error.payload_too_large"
        case CloudSyncError.conflictRetryLimit.diagnosticCode: return "mine.sync.error.conflict_retry_limit"
        case CloudSyncError.incompatibleRemoteSnapshot.diagnosticCode: return "mine.sync.error.incompatible_remote_snapshot"
        case CloudSyncError.localChangesDuringSync.diagnosticCode: return "mine.sync.error.local_changes_during_sync"
        default: return "mine.sync.error.generic"
        }
    }
}

private struct SyncSettingsView: View {
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var cloudSyncStore: CloudSyncStore
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var appearanceStore: AppearanceStore

    var body: some View {
        let presentation = SyncSettingsPresentation(
            canUseSync: entitlementStore.canUse(.iCloudSync),
            isEnabled: cloudSyncStore.isEnabled,
            status: cloudSyncStore.status,
            lastSuccessfulSyncAt: cloudSyncStore.lastSuccessfulSyncAt,
            hasPendingChanges: cloudSyncStore.hasPendingChanges
        )
        Form {
            Section {
                Toggle(isOn: syncBinding) {
                    Label("mine.sync.enable", systemImage: "icloud")
                }
                .disabled(presentation.isToggleDisabled)

                LabeledContent("mine.sync.status") {
                    HStack(spacing: 7) {
                        if cloudSyncStore.status == .checking || cloudSyncStore.status == .syncing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(LocalizedStringKey(presentation.statusTitleKey))
                            .foregroundStyle(syncStatusColor)
                    }
                }

                LabeledContent("mine.sync.last_success") {
                    Group {
                        switch presentation.lastSuccess {
                        case .waiting: Text("mine.sync.waiting")
                        case .time(let lastSync): Text(lastSync, style: .relative)
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                if presentation.hasPendingChanges {
                    LabeledContent("mine.sync.pending") {
                        Text("mine.sync.pending_detail").foregroundStyle(.secondary)
                    }
                }

                if let detail = presentation.syncErrorDetailKey {
                    Text(LocalizedStringKey(detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("mine.sync.icloud")
            }.nastartListSection()

            Section {
                ForEach(NastartSyncScope.allCases) { scope in NastartSyncScopeRow(scope: scope) }
            } header: {
                Text("mine.sync.scope.title")
            }.nastartListSection()

            if presentation.syncNow != .hidden {
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
                    .disabled(presentation.syncNow == .syncing)
                }.nastartListSection()
            }

            if presentation.showsPlusLink {
                Section {
                    NavigationLink {
                        PlusView()
                    } label: {
                        Label("plus.locked.icloud", systemImage: "lock")
                    }
                } header: {
                    Text("mine.sync.scope")
                }.nastartListSection()
            }
        }
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("mine.sync.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await cloudSyncStore.refreshAccountStatus()
        }
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
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var showCacheHint = false
    @State private var cacheClearPartial = false
    @State private var cacheClearing = false
    @State private var showCertificateResetHint = false
    @State private var showCacheConfirmation = false
    @State private var showCertificateResetConfirmation = false

    var body: some View {
        Form {
            Section { NastartPrivacyDataRows() } header: { Text("privacy.summary.title") }.nastartListSection()
            Section {
                NavigationLink {
                    KeychainSettingsView()
                } label: {
                    NastartPrivacyActionLabel(key: "mine.privacy.keychain", symbol: "key")
                }
                Button {
                    showCertificateResetConfirmation = true
                } label: {
                    NastartPrivacyActionLabel(key: "mine.privacy.reset_certificates", symbol: "checkmark.shield")
                }
            } header: {
                Text("mine.privacy.security")
            }.nastartListSection()

            Section {
                NavigationLink {
                    DataExportView()
                } label: {
                    NastartPrivacyActionLabel(key: "mine.privacy.export", symbol: "square.and.arrow.up")
                }
                LabeledContent("mine.privacy.cache.status") {
                    Text(LocalizedStringKey(dataStore.cachedSnapshotStatusKey))
                        .foregroundStyle(.secondary)
                }
                if let savedAt = dataStore.cachedDSMSnapshotSavedAt {
                    LabeledContent("mine.privacy.cache.updated") {
                        Text(savedAt, style: .relative)
                    }
                }
                Button {
                    showCacheConfirmation = true
                } label: {
                    NastartPrivacyActionLabel(key: "mine.privacy.clear_cache", symbol: "trash")
                }.disabled(cacheClearing)
            } header: {
                Text("privacy.management.title")
            } footer: {
                Text("mine.privacy.cache.footer")
            }.nastartListSection()
        }
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("mine.privacy.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert(cacheHintTitle, isPresented: $showCacheHint) {
            Button("action.ok", role: .cancel) {}
        }
        .modifier(NastartCacheClearPrompt(isPresented: $showCacheConfirmation, onClear: {
            // 取消不会走到这里；清理开始后不可取消，期间入口禁用并忽略重复确认。
            guard !cacheClearing else { return }
            cacheClearing = true
            Task { @MainActor in
                let outcome = await PrivacyCacheCleaner.live(dataStore: dataStore).clear()
                cacheClearPartial = outcome != .cleared
                cacheClearing = false
                showCacheHint = true
            }
        }))
        .modifier(NastartCertificateResetPrompt(isPresented: $showCertificateResetConfirmation, onReset: {
            CertificatePinStore.shared.clearAll()
            showCertificateResetHint = true
        }))
        .alert("mine.privacy.reset_certificates_hint", isPresented: $showCertificateResetHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private var cacheHintTitle: LocalizedStringKey {
        cacheClearPartial ? "mine.privacy.clear_cache_partial" : "mine.privacy.clear_cache_hint"
    }
}

private extension PrivacyCacheCleaner {
    /// 正式清理步骤，顺序与以往一致：快照 → URLCache → 临时文件 → 网页数据。
    @MainActor
    static func live(dataStore: AppDataStore) -> PrivacyCacheCleaner {
        PrivacyCacheCleaner(steps: [
            Step(name: "snapshot") { dataStore.clearCachedSnapshot() },
            Step(name: "urlCache") { URLCache.shared.removeAllCachedResponses() },
            Step(name: "temporaryFiles") {
                try PrivacyCacheCleaner.removeTemporaryDirectories(
                    named: ["NastartDownloads", "NastartPreviews"],
                    in: FileManager.default.temporaryDirectory)
            },
            Step(name: "webData") {
                await WKWebsiteDataStore.default().removeData(
                    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                    modifiedSince: .distantPast)
            }
        ])
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
            }.nastartListSection()

            Section {
                NastartSavedCredentialRow(hasCredential: hasDSMCredential)
            } header: {
                Text("mine.privacy.keychain_items")
            }.nastartListSection()

            Section {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label("mine.privacy.keychain.clear", systemImage: "trash")
                }
                .disabled(!hasDSMCredential)
            } header: {
                Text("mine.privacy.keychain_actions")
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
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

/// Generates the existing export schema from explicit, lazily supplied snapshots.
/// It never reads preferences, accounts or storage itself.
enum DataExportPayload {
    struct Selection {
        let launchpad: Bool
        let reminders: Bool
        let settings: Bool
        var hasSelection: Bool { launchpad || reminders || settings }
    }

    struct Service {
        let name: String
        let category: ServiceCategory
        let visible: Bool
    }

    struct Preferences {
        let theme: LaunchpadTheme
        let language: AppLanguage
        let displayMode: AppThemeMode
        let compactMetrics: Bool
        let showServiceStatus: Bool

        init(theme: String? = nil, language: String? = nil, displayMode: String? = nil,
             compactMetrics: Bool? = nil, showServiceStatus: Bool? = nil) {
            self.theme = LaunchpadTheme(rawValue: theme ?? "") ?? .cleanGrid
            self.language = AppLanguage(rawValue: language ?? "") ?? .system
            self.displayMode = AppThemeMode(rawValue: displayMode ?? "") ?? .system
            self.compactMetrics = compactMetrics ?? true
            self.showServiceStatus = showServiceStatus ?? true
        }

        static func read(from defaults: UserDefaults) -> Self {
            .init(theme: defaults.string(forKey: LaunchpadTheme.storageKey),
                  language: defaults.string(forKey: AppLanguage.storageKey),
                  displayMode: defaults.string(forKey: AppThemeMode.storageKey),
                  compactMetrics: defaults.object(forKey: AppearancePreferenceKeys.compactMetrics) as? Bool,
                  showServiceStatus: defaults.object(forKey: AppearancePreferenceKeys.showServiceStatus) as? Bool)
        }
    }

    static func text(selection: Selection, exportedAt: Date,
                     launchpad: () -> [Service], pending: () -> [TaskItem],
                     history: () -> [TaskItem], settings: () -> Preferences) -> String {
        var payload: [String: Any] = [
            "formatVersion": 1,
            "exportedAt": ISO8601DateFormatter().string(from: exportedAt)
        ]
        if selection.launchpad {
            payload["launchpad"] = launchpad().map { service in
                ["name": DiagnosticLogStore.redactedExportText(service.name),
                 "category": service.category.rawValue, "visible": service.visible] as [String: Any]
            }
        }
        if selection.reminders {
            payload["reminders"] = ["pending": pending().map(taskValue), "history": history().map(taskValue)]
        }
        if selection.settings {
            let preferences = settings()
            payload["settings"] = [
                "launchpadTheme": preferences.theme.rawValue,
                "language": preferences.language.rawValue,
                "displayMode": preferences.displayMode.rawValue,
                "compactMetrics": preferences.compactMetrics,
                "showServiceStatus": preferences.showServiceStatus
            ] as [String: Any]
        }
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    private static func taskValue(_ task: TaskItem) -> [String: Any] {
        var value: [String: Any] = [
            "id": task.id.uuidString,
            "title": DiagnosticLogStore.redactedExportText(task.title),
            "target": DiagnosticLogStore.redactedExportText(task.subtitle),
            "createdAt": ISO8601DateFormatter().string(from: task.createdAt),
            "daysBefore": task.daysBefore,
            "muted": task.isMuted
        ]
        if let raw = task.kindRawValue, let kind = ReminderKind(rawValue: raw) { value["kind"] = kind.rawValue }
        if let date = task.completedAt { value["completedAt"] = ISO8601DateFormatter().string(from: date) }
        if let date = task.targetDate { value["targetDate"] = ISO8601DateFormatter().string(from: date) }
        return value
    }
}

private struct DataExportView: View {
    @EnvironmentObject private var dataStore: AppDataStore

    var body: some View {
        NastartDataExportContent(launchpad: {
            dataStore.services.map { service in
                .init(name: service.name, category: service.category,
                      visible: dataStore.isServiceVisibleOnLaunchpad(service))
            }
        }, pending: { dataStore.tasks }, history: { dataStore.completedTasks }, settings: {
            .read(from: UserDefaults.standard)
        })
    }
}

/// The production form receives lazy snapshots. The isolated host supplies only fixtures.
struct NastartDataExportContent: View {
    struct IsolatedStyle {
        let background: AnyView
        let surface: AnyView
    }
    var isolatedStyle: IsolatedStyle? = nil
    let launchpad: () -> [DataExportPayload.Service]
    let pending: () -> [TaskItem]
    let history: () -> [TaskItem]
    let settings: () -> DataExportPayload.Preferences
    @State private var includeLaunchpad = true
    @State private var includeReminders = true
    @State private var includeSettings = true

    var body: some View {
        themedForm
            .navigationTitle("mine.privacy.export")
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var themedForm: some View {
        if let isolatedStyle {
            form.scrollContentBackground(.hidden)
                .background { isolatedStyle.background.ignoresSafeArea() }
        } else {
            form.nastartReadableWidth().nastartPageTheme()
        }
    }

    private var form: some View {
        Form {
            Section {
                NastartExportSelectionRows(includeLaunchpad: $includeLaunchpad,
                    includeReminders: $includeReminders, includeSettings: $includeSettings)
            } header: {
                Text("mine.privacy.export_scope")
            } footer: {
                Text("mine.privacy.export_footer")
            }.modifier(SectionStyle(surface: isolatedStyle?.surface))

            Section {
                NastartShareButton(text: { exportText }) {
                    Label("mine.privacy.export", systemImage: "square.and.arrow.up")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(!hasExportSelection)
            } footer: {
                if !hasExportSelection { Text("privacy.export.no_selection") }
            }.modifier(SectionStyle(surface: isolatedStyle?.surface))
        }
    }

    private struct SectionStyle: ViewModifier {
        let surface: AnyView?
        @ViewBuilder func body(content: Content) -> some View {
            if let surface { content.listRowBackground(surface) }
            else { content.nastartListSection() }
        }
    }

    private var exportSelection: DataExportPayload.Selection {
        .init(launchpad: includeLaunchpad, reminders: includeReminders, settings: includeSettings)
    }

    private var hasExportSelection: Bool { exportSelection.hasSelection }

    private var exportText: String {
        DataExportPayload.text(selection: exportSelection, exportedAt: Date(),
            launchpad: launchpad, pending: pending, history: history, settings: settings)
    }
}

// MARK: - 分享：完成 / 取消 / 失败

/// 系统分享面板的三种结果。完成与取消不提示（分享目标不一定产生导出，不能当作“已送达”）；
/// 只有失败才向用户说明。结果不含导出内容、目标应用名或任何标识。
enum NastartShareOutcome: Equatable {
    case completed, cancelled, failed

    /// 对应 `UIActivityViewController.completionWithItemsHandler`：有错误即失败，
    /// 否则按 `completed` 区分完成与取消。
    init(completed: Bool, error: Error?) {
        if error != nil {
            self = .failed
        } else {
            self = completed ? .completed : .cancelled
        }
    }
}

/// 宿主可注入的探针。正式环境为 `.production`（不模拟、不记录）；
/// 离线界面测试用它不打开系统面板，直接走同一条结果处理路径并计数。
struct NastartShareProbe {
    var simulated: NastartShareOutcome? = nil
    var record: (NastartShareOutcome) -> Void = { _ in }
    static let production = NastartShareProbe()
}

private struct NastartShareProbeKey: EnvironmentKey {
    static let defaultValue = NastartShareProbe.production
}

extension EnvironmentValues {
    var nastartShareProbe: NastartShareProbe {
        get { self[NastartShareProbeKey.self] }
        set { self[NastartShareProbeKey.self] = newValue }
    }
}

/// 替代 `ShareLink` 的按钮：点击时才生成要分享的文本，并通过系统分享面板拿到结果。
/// 失败时在面板收起后弹出说明；完成/取消不弹任何提示。
struct NastartShareButton<ButtonLabel: View>: View {
    let text: () -> String
    @ViewBuilder let label: () -> ButtonLabel
    @Environment(\.nastartShareProbe) private var probe
    @State private var presented = false
    @State private var payload = ""
    @State private var failurePending = false
    @State private var showFailure = false

    var body: some View {
        Button {
            if let simulated = probe.simulated {
                handle(simulated)
                presentPendingFailure()
            } else {
                payload = text()
                presented = true
            }
        } label: {
            label()
        }
        .sheet(isPresented: $presented, onDismiss: presentPendingFailure) {
            NastartActivitySheet(items: [payload]) { outcome in
                handle(outcome)
                presented = false
            }
            .presentationDetents([.medium, .large])
            .ignoresSafeArea()
        }
        .alert("mine.share.failed", isPresented: $showFailure) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func handle(_ outcome: NastartShareOutcome) {
        probe.record(outcome)
        if outcome == .failed { failurePending = true }
    }

    private func presentPendingFailure() {
        guard failurePending else { return }
        failurePending = false
        showFailure = true
    }
}

private struct NastartActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    let onFinish: (NastartShareOutcome) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, error in
            let outcome = NastartShareOutcome(completed: completed, error: error)
            DispatchQueue.main.async { onFinish(outcome) }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct HelpAboutView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                ForEach(NastartHelpTopic.available) { topic in
                    NavigationLink { HelpTopicView(topic: topic) } label: { NastartHelpTopicLabel(topic: topic) }
                        .accessibilityIdentifier("help.topic." + topic.id)
                }
            } header: { Text("help.guide") }.nastartListSection()
            Section {
                LabeledContent("Nastart", value: versionText)
                LabeledContent("mine.about.compatibility", value: "DSM 7.2+")
            }.nastartListSection()

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
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("mine.about.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }
}

private struct HelpTopicView: View {
    let topic: NastartHelpTopic
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(topic.sections) { section in
                    NastartHelpSectionBody(section: section).padding(18)
                        .nastartSurface().clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                }
            }.padding(16)
        }.nastartReadableWidth().nastartPageTheme()
            .navigationTitle(Text(LocalizedStringKey("help." + topic.id + ".title")))
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("help.article." + topic.id)
    }
}

private struct DiagnosticLogsView: View {
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var diagnostics: DiagnosticLogStore
    @State private var showCopiedHint = false
    @State private var showClearConfirmation = false
    @State private var selectedLevelFilter: DiagnosticLevelFilter = .all
    @State private var selectedCategoryKey = DiagnosticCategoryFilter.allKey

    private var reversedEntries: [DiagnosticLogEntry] {
        Array(diagnostics.entries.reversed())
    }

    private var filteredEntries: [DiagnosticLogEntry] {
        reversedEntries.filter { entry in
            selectedLevelFilter.includes(entry.level)
                && DiagnosticCategoryFilter.includes(entry.categoryKey, selected: selectedCategoryKey)
        }
    }

    private var availableCategoryKeys: [String] {
        Array(Set(diagnostics.entries.map(\.categoryKey))).sorted {
            NSLocalizedString($0, comment: "").localizedCaseInsensitiveCompare(
                NSLocalizedString($1, comment: "")
            ) == .orderedAscending
        }
    }

    private var diagnosticExportText: String {
        diagnostics.exportText(context: diagnosticExportContext)
    }

    private var diagnosticExportContext: DiagnosticExportContext {
        DiagnosticExportContext(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-",
            deviceName: dataStore.device.name,
            dsmVersion: dataStore.device.dsmVersion,
            connectionMode: dataStore.device.mode.rawValue,
            activeRoute: connectionStore.actualRoute?.rawValue ?? "-",
            cachedSnapshotSavedAt: dataStore.cachedDSMSnapshotSavedAt
        )
    }

    var body: some View {
        List {
            Section {
                DiagnosticActions(exportText: diagnosticExportText, isEmpty: diagnostics.entries.isEmpty,
                    copy: {
                        UIPasteboard.general.string = diagnosticExportText
                        showCopiedHint = true
                    }, clear: { showClearConfirmation = true })
            } header: {
                Text("diagnostics.actions")
            }.nastartListSection()

            Section {
                DiagnosticSummaryView(
                    total: diagnostics.entries.count,
                    warnings: diagnostics.entries.filter { $0.level == .warning }.count,
                    errors: diagnostics.entries.filter { $0.level == .error }.count,
                    latestTime: reversedEntries.first?.displayTime
                )
            } header: {
                Text("diagnostics.summary")
            }.nastartListSection()

            Section {
                Picker("diagnostics.filter.level", selection: $selectedLevelFilter) {
                    ForEach(DiagnosticLevelFilter.allCases) { filter in
                        Text(filter.titleKey).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Picker("diagnostics.filter.category", selection: $selectedCategoryKey) {
                    Text("diagnostics.filter.category.all")
                        .tag(DiagnosticCategoryFilter.allKey)
                    ForEach(availableCategoryKeys, id: \.self) { categoryKey in
                        Text(LocalizedStringKey(categoryKey)).tag(categoryKey)
                    }
                }
            } header: {
                Text("diagnostics.filter")
            }.nastartListSection()

            Section {
                if filteredEntries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(LocalizedStringKey(
                            reversedEntries.isEmpty ? "diagnostics.empty" : "diagnostics.empty_filtered"
                        ))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                } else {
                    ForEach(filteredEntries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(DiagnosticLogDisplay.title(forKey: entry.messageKey))
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
                                Text(DiagnosticLogStore.redactedDetail(entry.detail))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 5)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint(Text("diagnostics.entry.hint"))
                    }
                }
            } header: {
                Text("diagnostics.recent")
            } footer: {
                Text("diagnostics.footer")
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("diagnostics.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("diagnostics.copy_done", isPresented: $showCopiedHint) {
            Button("action.ok", role: .cancel) {}
        }
        .confirmationDialog(
            "diagnostics.clear.confirm",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("diagnostics.clear", role: .destructive) {
                diagnostics.clear()
            }
            Button("action.cancel", role: .cancel) {}
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

private enum DiagnosticLevelFilter: String, CaseIterable, Identifiable {
    case all
    case warnings
    case errors

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: return "diagnostics.filter.all"
        case .warnings: return "diagnostics.filter.warnings"
        case .errors: return "diagnostics.filter.errors"
        }
    }

    func includes(_ level: DiagnosticLogLevel) -> Bool {
        switch self {
        case .all: return true
        case .warnings: return level == .warning
        case .errors: return level == .error
        }
    }
}

private enum DiagnosticCategoryFilter {
    static let allKey = "__all__"

    static func includes(_ categoryKey: String, selected: String) -> Bool {
        selected == allKey || categoryKey == selected
    }
}

/// Production supplies its existing side effects; isolated fixtures supply local counters.
private struct DiagnosticActions: View {
    var isolatedSurface: AnyView? = nil
    let exportText: String
    let isEmpty: Bool
    let copy: () -> Void
    let clear: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Stack the three actions at accessibility sizes so each short title keeps its own full-width tile.
    private var actionLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    var body: some View {
        actionLayout {
            NastartShareButton(text: { exportText }) {
                DiagnosticActionTile(
                    isolatedSurface: isolatedSurface, titleKey: "diagnostics.export.short",
                    systemImage: "square.and.arrow.up"
                )
            }
            .accessibilityLabel(Text("diagnostics.export"))
            .accessibilityIdentifier("diagnostics.action.export")
            .disabled(isEmpty)

            Button(action: copy) {
                DiagnosticActionTile(
                    isolatedSurface: isolatedSurface, titleKey: "diagnostics.copy.short",
                    systemImage: "doc.on.doc"
                )
            }
            .accessibilityLabel(Text("diagnostics.copy"))
            .accessibilityIdentifier("diagnostics.action.copy")
            .disabled(isEmpty)

            Button(role: .destructive, action: clear) {
                DiagnosticActionTile(
                    isolatedSurface: isolatedSurface, titleKey: "diagnostics.clear.short",
                    systemImage: "trash",
                    foregroundColor: .red
                )
            }
            .disabled(isEmpty)
            .accessibilityLabel(Text("diagnostics.clear"))
            .accessibilityIdentifier("diagnostics.action.clear")
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

private struct DiagnosticActionTile: View {
    var isolatedSurface: AnyView? = nil
    let titleKey: LocalizedStringKey
    let systemImage: String
    var foregroundColor: Color = .primary

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(titleKey)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(foregroundColor)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background {
            if let isolatedSurface { isolatedSurface }
            else { AnyView(NastartSurfaceBackground()) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }
}

private struct DiagnosticSummaryView: View {
    let total: Int
    let warnings: Int
    let errors: Int
    let latestTime: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Stack the three counters at accessibility sizes instead of squeezing three columns.
    private var metricLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            metricLayout {
                DiagnosticSummaryMetric(
                    titleKey: "diagnostics.summary.total",
                    value: total,
                    color: .secondary
                )
                DiagnosticSummaryMetric(
                    titleKey: "diagnostics.summary.warnings",
                    value: warnings,
                    color: AppTheme.accent
                )
                DiagnosticSummaryMetric(
                    titleKey: "diagnostics.summary.errors",
                    value: errors,
                    color: .red
                )
            }

            if let latestTime {
                Label {
                    Text(latestTime)
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("diagnostics.summary.latest"))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DiagnosticSummaryMetric: View {
    let titleKey: LocalizedStringKey
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
/// 离线界面测试：选择“系统面板/完成/取消/失败”。后三者不打开系统面板，直接走与正式相同的结果处理并计数。
struct NastartOfflineShareProbeHost: ViewModifier {
    var enabled = true
    @State private var choice = 0
    @State private var counts = [0, 0, 0]

    private var simulated: NastartShareOutcome? {
        let options: [NastartShareOutcome?] = [nil, .completed, .cancelled, .failed]
        return options[choice]
    }

    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content
                .environment(\.nastartShareProbe, NastartShareProbe(simulated: simulated, record: { outcome in
                    switch outcome {
                    case .completed: counts[0] += 1
                    case .cancelled: counts[1] += 1
                    case .failed: counts[2] += 1
                    }
                }))
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 4) {
                        Picker("合成分享结果", selection: $choice) {
                            Text("系统面板").tag(0)
                            Text("完成").tag(1)
                            Text("取消").tag(2)
                            Text("失败").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("offline.share.outcome")
                        Text("合成分享 · 完成 \(counts[0]) · 取消 \(counts[1]) · 失败 \(counts[2])")
                            .font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("offline.share.counts")
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .dynamicTypeSize(.large)
                    .background(.regularMaterial)
                }
        } else {
            content
        }
    }
}

/// Uses the production components with fixture-only closures, without constructing
/// account, diagnostics, appearance, discovery, sync or persistence stores.
struct NastartOfflineMineComponentsScene: View {
    let configuration: OfflineUIConfiguration
    let background: AnyView
    let surface: AnyView
    @State private var fixtureConnected = true
    @State private var fixtureEmpty = false
    @State private var signOutRequests = 0
    @State private var copyRequests = 0
    @State private var clearRequests = 0

    var body: some View {
        NavigationStack {
            List {
                if configuration.scenario == .mineInfo {
                    Section {
                        MineSignOutRow(canSignOut: fixtureConnected, message: fixtureMessage) {
                            signOutRequests += 1
                        }
                    }.listRowBackground(surface)
                    Section {
                        Toggle("Connected fixture", isOn: $fixtureConnected)
                            .accessibilityIdentifier("offline.mine.connected")
                        Text("Sign-out requests: \(signOutRequests)")
                            .accessibilityIdentifier("offline.mine.sign-out-count")
                    }.listRowBackground(surface)
                } else {
                    Section {
                        DiagnosticActions(isolatedSurface: surface,
                            exportText: "Nastart synthetic diagnostic fixture", isEmpty: fixtureEmpty,
                            copy: { copyRequests += 1 }, clear: { clearRequests += 1 })
                    } header: {
                        Text("diagnostics.actions")
                    }.listRowBackground(surface)
                    Section {
                        DiagnosticSummaryView(total: 123, warnings: 4, errors: 2, latestTime: "12:34:56")
                    } header: {
                        Text("diagnostics.summary")
                    }.listRowBackground(surface)
                    Section {
                        Toggle("Empty fixture", isOn: $fixtureEmpty)
                            .accessibilityIdentifier("offline.diagnostics.empty")
                        Text("Copy requests: \(copyRequests); clear requests: \(clearRequests)")
                            .accessibilityIdentifier("offline.diagnostics.action-counts")
                    }.listRowBackground(surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background { background.ignoresSafeArea() }
            .modifier(NastartOfflineShareProbeHost(enabled: configuration.scenario != .mineInfo))
            .navigationTitle(LocalizedStringKey(configuration.scenario == .mineInfo ? "tab.mine" : "diagnostics.title"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("Offline fixture · production components")
                    .font(.caption).dynamicTypeSize(.large).foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
                    .accessibilityIdentifier("offline.mine-components.banner")
            }
        }
    }

    private var fixtureMessage: String {
        fixtureConnected
            ? String(format: NSLocalizedString("mine.sign_out.connected_footer %@", comment: ""), "Nastart Fixture")
            : NSLocalizedString("mine.sign_out.footer", comment: "")
    }
}

/// Uses the production card and artwork with static surfaces and local selection only.
struct NastartOfflineThemeGalleryScene: View {
    let background: AnyView
    let surface: AnyView
    @State private var selectedFixture: LaunchpadTheme? = .cleanGrid
    @State private var nextFixtureIndex = 0

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(LaunchpadTheme.allCases) { theme in
                        NavigationLink {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 18) {
                                    LaunchpadThemePreviewArtwork(theme: theme, expanded: true, isolatedBackground: background)
                                    Text(LocalizedStringKey(theme.titleKey)).font(.title2)
                                    Text(LocalizedStringKey(theme.descriptionKey)).font(.body)
                                    Text("Offline fixture · no theme applied").font(.caption)
                                }.padding(16)
                            }
                            .background { background.ignoresSafeArea() }
                            .navigationTitle("mine.appearance.theme.preview")
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            LaunchpadThemeCardLabel(theme: theme, isSelected: selectedFixture == theme,
                                isolatedSurface: surface, isolatedArtworkBackground: background)
                        }
                        .buttonStyle(.plain)
                        .id(theme.rawValue)
                        .accessibilityIdentifier("offline.theme.card." + theme.rawValue)
                    }
                    Text("Fixture selection: " + (selectedFixture?.rawValue ?? "none"))
                        .font(.caption)
                        .accessibilityIdentifier("offline.theme.selection")
                    Text("Offline fixture · production theme cards")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16)
            }
            .background { background.ignoresSafeArea() }
            .navigationTitle("mine.appearance.theme.gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        switch selectedFixture {
                        case .some(.cleanGrid): selectedFixture = .commandCenter
                        case .some(.commandCenter): selectedFixture = .glassDeck
                        case .some(.glassDeck): selectedFixture = nil
                        case nil: selectedFixture = .cleanGrid
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Cycle selected fixture")
                    .accessibilityIdentifier("offline.theme.cycle-selection")
                    Button {
                        nextFixtureIndex = (nextFixtureIndex + 1) % LaunchpadTheme.allCases.count
                        proxy.scrollTo(LaunchpadTheme.allCases[nextFixtureIndex].rawValue, anchor: .center)
                    } label: {
                        Image(systemName: "arrow.down.to.line")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Show next card fixture")
                    .accessibilityIdentifier("offline.theme.next-card")
                }
            }
            }
        }
    }
}
#endif

enum DiagnosticLogDisplay {
    /// Playback event keys are generated from event names and have no table entry,
    /// so a missing translation shows the event name rather than the full internal key.
    static func title(forKey key: String) -> String {
        let text = NSLocalizedString(key, comment: "")
        guard text == key, key.hasPrefix("diagnostics.") else { return text }
        return (key.split(separator: ".").last.map(String.init) ?? key).replacingOccurrences(of: "_", with: " ")
    }
}
