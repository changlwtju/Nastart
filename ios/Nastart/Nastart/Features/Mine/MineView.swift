import SwiftUI

struct MineView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        HStack(spacing: 14) {
                            Text(profileStore.avatarInitial)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 54, height: 54)
                                .background(AppTheme.secondarySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(profileStore.nickname)
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
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(AppTheme.accent)
                                .clipShape(Capsule())
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
                } header: {
                    Text("mine.section.settings")
                }

                Section {
                    NavigationLink {
                        HelpAboutView()
                    } label: {
                        Label("mine.about.title", systemImage: "questionmark.circle")
                    }
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
            .confirmationDialog("mine.sign_out.confirm", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("mine.sign_out", role: .destructive) {
                    connectionStore.signOut()
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
                    Text("plus.action.subscribe")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
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
        .alert("plus.subscribe_hint", isPresented: $showSubscribeHint) {
            Button("action.ok", role: .cancel) {}
        }
        .alert("plus.restore_hint", isPresented: $showRestoreHint) {
            Button("action.ok", role: .cancel) {}
        }
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
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @AppStorage(LaunchpadTheme.storageKey) private var launchpadThemeRaw = LaunchpadTheme.cleanGrid.rawValue

    var body: some View {
        Form {
            Section {
                Picker("mine.appearance.theme", selection: $launchpadThemeRaw) {
                    ForEach(LaunchpadTheme.allCases) { theme in
                        Text(LocalizedStringKey(theme.titleKey)).tag(theme.rawValue)
                    }
                }
                .disabled(!entitlementStore.canUse(.advancedThemes))
                .onChange(of: launchpadThemeRaw) { newValue in
                    appearanceStore.launchpadTheme = LaunchpadTheme(rawValue: newValue) ?? .cleanGrid
                }
                Toggle("mine.appearance.compact_metrics", isOn: $appearanceStore.compactMetrics)
                Toggle("mine.appearance.status_dot", isOn: $appearanceStore.showServiceStatus)
                if !entitlementStore.hasPlus {
                    NavigationLink {
                        PlusView()
                    } label: {
                        Label("plus.locked.themes", systemImage: "lock")
                    }
                }
            } header: {
                Text("mine.appearance.launchpad")
            }

            Section {
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
                Text("mine.appearance.cards")
            }
        }
        .navigationTitle("mine.appearance.title")
    }
}

private struct CardItemsSettingsView: View {
    @State private var showStatus = true
    @State private var showSubtitle = true
    @State private var showCPU = true
    @State private var showMemory = true
    @State private var showPorts = false
    @State private var showLibraryCounts = true

    var body: some View {
        Form {
            Section {
                Toggle("mine.appearance.item.status", isOn: $showStatus)
                Toggle("mine.appearance.item.subtitle", isOn: $showSubtitle)
                Toggle("mine.appearance.item.cpu", isOn: $showCPU)
                Toggle("mine.appearance.item.memory", isOn: $showMemory)
                Toggle("mine.appearance.item.ports", isOn: $showPorts)
                Toggle("mine.appearance.item.library", isOn: $showLibraryCounts)
            } header: {
                Text("mine.appearance.card_items")
            } footer: {
                Text("mine.appearance.card_items_footer")
            }
        }
        .navigationTitle("mine.appearance.card_items")
    }
}

private struct LaunchpadGroupOrderView: View {
    @State private var expandedFavorites = true
    @State private var expandedMedia = true
    @State private var expandedDownloads = false
    @State private var expandedNetwork = false
    @State private var expandedTools = false

    var body: some View {
        Form {
            Section {
                Toggle("category.favorites", isOn: $expandedFavorites)
                Toggle("category.media", isOn: $expandedMedia)
                Toggle("category.downloads", isOn: $expandedDownloads)
                Toggle("category.network", isOn: $expandedNetwork)
                Toggle("category.tools", isOn: $expandedTools)
            } header: {
                Text("mine.appearance.group_default")
            } footer: {
                Text("mine.appearance.group_footer")
            }

            Section {
                ForEach(ServiceCategory.allCases) { category in
                    HStack {
                        Text(LocalizedStringKey(category.titleKey))
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("mine.appearance.group_order")
            }
        }
        .navigationTitle("mine.appearance.group_order")
    }
}

private struct PlayerSettingsView: View {
    @State private var defaultVideo = "Infuse"
    @State private var defaultAudio = "Navidrome"
    @State private var preferExternal = true

    var body: some View {
        Form {
            Section {
                Picker("mine.players.video", selection: $defaultVideo) {
                    Text("Infuse").tag("Infuse")
                    Text("VidHub").tag("VidHub")
                    Text("VLC").tag("VLC")
                    Text("player.system").tag("System Player")
                }
                Picker("mine.players.audio", selection: $defaultAudio) {
                    Text("Navidrome").tag("Navidrome")
                    Text("player.system").tag("System Player")
                    Text("player.custom_scheme").tag("Custom Scheme")
                }
                Toggle("mine.players.prefer_external", isOn: $preferExternal)
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
    }
}

private struct PlayerIntegrationRow: View {
    let name: String
    let detailKey: LocalizedStringKey

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(detailKey)
                .foregroundStyle(.secondary)
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
                Toggle("mine.sync.enable", isOn: $iCloudSync)
                    .disabled(!entitlementStore.canUse(.iCloudSync))
                Toggle("mine.sync.launchpad", isOn: $syncLaunchpad)
                    .disabled(!entitlementStore.canUse(.iCloudSync))
                Toggle("mine.sync.reminders", isOn: $syncReminders)
                    .disabled(!entitlementStore.canUse(.iCloudSync))
            } header: {
                Text("mine.sync.icloud")
            }

            Section {
                LabeledContent("mine.sync.devices", value: "2")
                LabeledContent("mine.sync.last") {
                    Text("state.just_now")
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
    }
}

private struct PrivacySecurityView: View {
    @State private var biometricUnlock = true
    @State private var clipboardCheck = true
    @State private var showCacheHint = false

    var body: some View {
        Form {
            Section {
                Toggle("mine.privacy.faceid", isOn: $biometricUnlock)
                Toggle("mine.privacy.clipboard", isOn: $clipboardCheck)
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
                Button("mine.privacy.clear_cache") {
                    showCacheHint = true
                }
            } header: {
                Text("mine.privacy.data")
            }
        }
        .navigationTitle("mine.privacy.title")
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
                Button("mine.privacy.keychain.rotate") {
                    show("mine.privacy.keychain_rotate_hint")
                }
                Button("mine.privacy.keychain.clear", role: .destructive) {
                    show("mine.privacy.keychain_clear_hint")
                }
            } header: {
                Text("mine.privacy.keychain_actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("mine.privacy.keychain")
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
                Toggle("mine.privacy.export.launchpad", isOn: $includeLaunchpad)
                Toggle("mine.privacy.export.reminders", isOn: $includeReminders)
                Toggle("mine.privacy.export.settings", isOn: $includeSettings)
                Toggle("mine.privacy.export.secrets", isOn: $includeSecrets)
            } header: {
                Text("mine.privacy.export_scope")
            } footer: {
                Text("mine.privacy.export_footer")
            }

            Section {
                Button {
                    showExportHint = true
                } label: {
                    Text("mine.privacy.export")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .navigationTitle("mine.privacy.export")
        .alert("mine.privacy.export_hint", isPresented: $showExportHint) {
            Button("action.ok", role: .cancel) {}
        }
    }
}

private struct HelpAboutView: View {
    @State private var messageKey = "mine.about.feedback_hint"
    @State private var showHint = false

    var body: some View {
        List {
            Section {
                LabeledContent("Nastart", value: "0.1.0")
                LabeledContent("mine.about.compatibility", value: "DSM 7.2+")
            }

            Section {
                Button("mine.about.feedback") {
                    show("mine.about.feedback_hint")
                }
                Button("mine.about.privacy") {
                    show("mine.about.privacy_hint")
                }
                Button("mine.about.terms") {
                    show("mine.about.terms_hint")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("mine.about.title")
        .alert(LocalizedStringKey(messageKey), isPresented: $showHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func show(_ key: String) {
        messageKey = key
        showHint = true
    }
}
