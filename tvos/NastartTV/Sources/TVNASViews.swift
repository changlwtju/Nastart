import SwiftUI
import NetworkMedia
import KSPlayer
import CryptoKit
import Combine
import CoreImage.CIFilterBuiltins

struct TVHomeView: View {
    @EnvironmentObject private var state: TVAppState
    var initialTab: TVRootTab = .launchpad
    var body: some View {
        TVRootNavigationShell(initialTab: initialTab) { tab in page(tab) }
    }

    @ViewBuilder private func page(_ tab: TVRootTab) -> some View {
        switch tab {
        case .launchpad:
            if let account = state.nasAccount { TVNASOverview(client: TVDSMClient(account: account)) }
            else { TVDisconnectedLaunchpad() }
        case .devices:
            if let account = state.nasAccount { TVDevicesView(client: TVDSMClient(account: account)) }
            else { TVConnectDeviceView() }
        case .tasks: TVTasksView()
        case .mine: TVSettingsView()
        }
    }
}

struct TVJellyfinEntry: View {
    var canGoBack = true
    var initialServer: URL?
    @EnvironmentObject private var state: TVAppState
    @State private var connect = false
    var body: some View {
        Group {
            if let account = state.account,
               initialServer.map({ MediaServiceEndpoint.matches($0, account.server) }) ?? true {
                TVLibraryView(client: TVJellyfinClient(account: account, deviceID: state.deviceID),
                              reconnect: { connect = true })
                    .id(state.jellyfinSessionRevision)
            } else {
                VStack(spacing: 30) {
                    Image(systemName: "play.rectangle.fill").font(.system(size: 90)).foregroundStyle(TVTheme.accent)
                    Text("Jellyfin 媒体库").font(TVType.title)
                    Text("连接 Jellyfin，浏览电影、剧集和音乐。DSM 与 Jellyfin 可以同时保持登录。")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("连接 Jellyfin") { connect = true }.accessibilityIdentifier("tv.connect.jellyfin")
                }.padding(90).frame(maxWidth: .infinity, maxHeight: .infinity).background(TVTheme.background)
            }
        }.tvNavigationBack(enabled: canGoBack).sheet(isPresented: $connect) {
            TVLoginView(initialKind: "Jellyfin", initialServer: initialServer ?? state.account?.server,
                        initialUser: state.account?.userName ?? "")
        }
    }
}

struct TVSettingsView: View {
    @EnvironmentObject private var state: TVAppState
    @State private var disconnectNAS = false
    @State private var disconnectError: String?
    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    TVPageHeading(title: "我的", subtitle: "设置与连接")
                    Text("设置").font(TVType.section)
                    TVFixedFeatureGrid(columns: 3) {
                        ForEach(NastartSettingsDestination.allCases) { destination in
                            NavigationLink { settingsDestination(destination) } label: {
                                NastartSettingsItemLabel(destination: destination)
                            }.accessibilityIdentifier("tv.settings." + destination.rawValue)
                        }
                    }
                    Text("连接与媒体").font(TVType.section)
                    TVFixedFeatureGrid(columns: 2) {
                        NavigationLink { TVConnectionsView() } label: {
                            TVFeatureTile(title: "连接管理", subtitle: state.nasAccount == nil ? "NAS 未连接 · 管理设备与影音授权" : "管理 NAS 与影音授权", symbol: "externaldrive.badge.person.crop")
                        }.accessibilityIdentifier("tv.settings.connections")
                        NavigationLink { TVStorageEntry() } label: {
                            TVFeatureTile(title: "存储与媒体", subtitle: "浏览文件 · 已添加的媒体库", symbol: "externaldrive.badge.wifi")
                        }.accessibilityIdentifier("tv.settings.storage")
                    }
                    if state.nasAccount != nil {
                        Button { disconnectNAS = true } label: {
                            Label("断开 NAS", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(TVType.caption).padding(16)
                        }.buttonStyle(TVServiceInsetStyle()).accessibilityIdentifier("tv.settings.disconnectNAS")
                    }
                    if let disconnectError { Text(disconnectError).font(TVType.caption).foregroundStyle(.red) }
                }.tvPageInsets()
        }.tvPageTheme().tvInformationLayout()
        .tvDisconnectConfirmation(.settingsNAS, isPresented: $disconnectNAS) {
            disconnectError = nil; Task { do { try await state.signOutNAS() } catch { disconnectError = error.localizedDescription } }
        }
    }
    @ViewBuilder private func settingsDestination(_ destination: NastartSettingsDestination) -> some View {
        switch destination {
        case .plus: TVPlusView()
        case .appearance: TVAppearanceSettings()
        case .player: TVPlayerSettingsView()
        case .icloud: TVCloudSyncStatusView()
        case .privacy: TVPrivacySecurity()
        case .help: TVHelpView()
        }
    }
}
struct TVCloudSyncStatusView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: "iCloud 同步", subtitle: "同步范围与数据保存")
                NastartTVSyncOverview(surface: AnyView(Color.clear.tvCardSurface(radius: TVLayout.radius)))
            }.tvPageInsets()
        }.tvPageTheme().tvNavigationBack()
    }
}
struct TVConnectionsView: View {
    @EnvironmentObject private var state: TVAppState
    @Environment(\.dismiss) private var dismiss
    @State private var connect = false
    @State private var kind = "DSM"
    @State private var confirmNAS = false
    @State private var confirmJF = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: "连接管理", subtitle: "管理此电视的设备与媒体访问")
                    .accessibilityIdentifier("tv.connections.back")
                TVFixedFeatureGrid(columns: 2) {
                    TVConnectionPanel(summary: TVSavedConnectionSummary(kind: .nas, server: state.nasAccount?.server)) {
                        Button { kind = "DSM"; connect = true } label: {
                            Label(state.nasAccount == nil ? "连接 NAS" : "更换连接", systemImage: "link")
                        }.accessibilityIdentifier("tv.connections.add")
                        if state.nasAccount != nil {
                            Button("断开连接") { confirmNAS = true }.accessibilityIdentifier("tv.connections.manage-nas")
                        }
                    }
                    TVConnectionPanel(summary: TVSavedConnectionSummary(kind: .jellyfin, server: state.account?.server)) {
                        Button { kind = "Jellyfin"; connect = true } label: {
                            Label(state.account == nil ? "连接 Jellyfin" : "更换授权", systemImage: "link")
                        }.accessibilityIdentifier("tv.connections.connect-jf")
                        if state.account != nil {
                            Button("移除授权") { confirmJF = true }.accessibilityIdentifier("tv.connections.manage-jf")
                        }
                    }
                }
                Text("网络存储").font(TVType.section)
                NavigationLink { TVStorageEntry() } label: {
                    TVFeatureTile(title: "存储与媒体", subtitle: "管理 WebDAV 连接、媒体文件夹和海报墙", symbol: "externaldrive.badge.wifi")
                }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.connections.storage")
                Text("NAS、影音服务与网络存储分别保存连接。DSM 未登录时，仍可使用已添加的 WebDAV 媒体库和独立影音授权。")
                    .font(TVType.caption).foregroundStyle(.secondary)
                if let error { Text(error).font(TVType.caption).foregroundStyle(.red) }
            }.tvPageInsets()
        }.tvPageTheme().onExitCommand { dismiss() }
        .sheet(isPresented: $connect) { TVLoginView(initialKind: kind) }
        .tvDisconnectConfirmation(.connectionNAS, isPresented: $confirmNAS) {
            self.error = nil; Task { do { try await state.signOutNAS() } catch { self.error = error.localizedDescription } }
        }
        .tvDisconnectConfirmation(.jellyfin, isPresented: $confirmJF) {
            self.error = nil; do { try state.signOut() } catch { self.error = error.localizedDescription }
        }
    }
}

/// The same native confirmation UI is used by the real settings and connections pages.
/// Actions remain at the call site; this component never reads accounts or performs logout.
private enum TVDisconnectKind: String, CaseIterable, Identifiable {
    case settingsNAS, connectionNAS, jellyfin
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .settingsNAS: "断开此电视的 NAS 连接？影音授权将保留。"
        case .connectionNAS: "移除此电视上的 NAS 连接？"
        case .jellyfin: "移除此电视上的影音授权？NAS 连接保持不变。"
        }
    }
    var actionTitle: LocalizedStringKey {
        switch self {
        case .settingsNAS: "断开 NAS"
        case .connectionNAS: "断开 DSM 连接"
        case .jellyfin: "移除影音授权"
        }
    }
}

private struct TVDisconnectConfirmation: ViewModifier {
    let kind: TVDisconnectKind
    @Binding var isPresented: Bool
    let confirmed: () -> Void
    func body(content: Content) -> some View {
        content.confirmationDialog(kind.title, isPresented: $isPresented) {
            Button(kind.actionTitle, role: .destructive, action: confirmed)
                .accessibilityIdentifier("tv.disconnect.confirm." + kind.rawValue)
            Button("取消", role: .cancel) {}
                .accessibilityIdentifier("tv.disconnect.cancel." + kind.rawValue)
        }
    }
}

private extension View {
    func tvDisconnectConfirmation(_ kind: TVDisconnectKind, isPresented: Binding<Bool>,
                                  confirmed: @escaping () -> Void) -> some View {
        modifier(TVDisconnectConfirmation(kind: kind, isPresented: isPresented, confirmed: confirmed))
    }
}

struct TVAppearanceSettings: View {
    @AppStorage("appearance.themeMode") private var themeMode = "system"
    @AppStorage("tv.library.posterDensity") private var posterDensity = 4
    @AppStorage("tv.show.service.details") private var showDetails = false
    @AppStorage("appearance.compactMetrics") private var compactMetrics = true
    @AppStorage("appearance.showServiceStatus") private var showServiceStatus = true
    @AppStorage("appearance.card.showSubtitle") private var showCardSubtitle = false
    @AppStorage("appearance.launchpadTheme") private var theme = "cleanGrid"
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: "外观与启动台", subtitle: "Nastart 设置")
                Text("显示模式").font(TVType.section)
                HStack(spacing: TVLayout.gap) {
                    ForEach([("system", "跟随系统"), ("light", "浅色"), ("dark", "深色")], id: \.0) { value, title in
                        Button { themeMode = value } label: { choice(title, selected: themeMode == value) }
                            .accessibilityIdentifier("tv.appearance.mode." + value)
                    }
                }.buttonStyle(TVTileStyle())
                Text("海报大小").font(TVType.section)
                HStack(spacing: TVLayout.gap) {
                    ForEach(TVPosterDensity.allCases) { option in
                        Button { posterDensity = option.rawValue } label: { choice(option.title, selected: posterDensity == option.rawValue) }
                            .accessibilityIdentifier("tv.appearance.posters." + String(option.rawValue))
                    }
                }.buttonStyle(TVTileStyle())
                Text("App 主题").font(TVType.section)
                TVFixedFeatureGrid(columns: 3) {
                  ForEach(TVLaunchpadTheme.allCases) { option in
                    Button { theme = option.rawValue } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) { Text(option.title).font(TVType.body.weight(.semibold)); Text(option.summary).font(TVType.caption).foregroundStyle(.secondary).lineLimit(2) }
                            Spacer(); if theme == option.rawValue { Image(systemName: "checkmark.circle.fill").foregroundStyle(TVTheme.accent) }
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).frame(height: TVLayout.cardHeight)
                    }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.theme." + option.rawValue)
                  }
                }
                Text("主题应用于启动台、设备、事项、我的及其内容页面；播放画面和系统键盘保持原本显示。")
                    .font(TVType.caption).foregroundStyle(.secondary)
                Text("启动台卡片").font(TVType.section)
                VStack(alignment: .leading, spacing: 20) {
                    NastartLaunchpadCardRows(compactMetrics: $compactMetrics,
                        showServiceStatus: $showServiceStatus, showCardSubtitle: $showCardSubtitle,
                        identifierPrefix: "tv.appearance")
                }.font(TVType.body)
                Toggle("显示服务镜像与详细信息", isOn: $showDetails).font(TVType.body)
                Text("默认展示 Docker 容器服务，套件不在启动台展示。可在管理显示中逐项调整；设备页保留完整服务清单。")
                    .font(TVType.caption).foregroundStyle(.secondary)
            }.tvPageInsets()
        }.tvPageTheme().tvNavigationBack()
    }
    private func choice(_ title: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Text(title).font(TVType.body.weight(selected ? .semibold : .regular))
            if selected { Image(systemName: "checkmark").font(TVType.caption).foregroundStyle(TVTheme.accent) }
        }.frame(maxWidth: .infinity).padding(.vertical, 22)
    }
}

struct TVHelpView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: "帮助与关于", subtitle: "了解 Nastart，让电视使用更顺手")
                TVFixedFeatureGrid(columns: 2) {
                    ForEach(NastartHelpTopic.available) { topic in
                        NavigationLink { TVHelpTopicView(topic: topic) }
                            label: { TVFeatureTile(title: topic.title, subtitle: topic.subtitle, symbol: topic.symbol) }
                            .accessibilityIdentifier("tv.help." + topic.rawValue)
                    }
                }
                HStack(spacing: 24) {
                    TVIconBadge(symbol: "externaldrive.fill")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nastart · Apple TV").font(TVType.section)
                        Text("版本 " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"))
                            .font(TVType.caption).foregroundStyle(.secondary)
                        Text("设备、文件与影音，一处掌握。").font(TVType.body).foregroundStyle(.secondary)
                    }
                }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
                    .tvCardSurface(radius: TVLayout.radius)
            }.tvPageInsets()
        }.tvPageTheme().onExitCommand { dismiss() }
    }
}
private struct TVHelpTopicView: View {
    let topic: NastartHelpTopic
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: topic.title, subtitle: topic.subtitle)
                ForEach(topic.sections) { section in
                    NastartHelpSectionBody(section: section).padding(30)
                        .tvCardSurface(radius: TVLayout.radius).focusable()
                }
            }.tvPageInsets()
        }.tvPageTheme().onExitCommand { dismiss() }
    }
}
struct TVConnectDeviceView: View {
    var body: some View { TVDevicesView(client: nil) }
}

/// Display-only snapshot. A saved configuration does not establish reachability.
private struct TVSavedConnectionSummary {
    enum Kind { case nas, jellyfin }
    let kind: Kind
    let server: URL?
    var title: String { kind == .nas ? "NAS 设备" : "Jellyfin" }
    var symbol: String { kind == .nas ? "externaldrive.fill" : "play.rectangle.fill" }
    var status: String {
        guard server != nil else { return "未连接" }
        return kind == .nas ? "已保存登录配置" : "已保存授权"
    }
    var detail: String {
        if let server { return tvDisplayAddress(server) }
        return kind == .nas
            ? "连接 Synology DSM，查看设备资源、文件和服务。"
            : "独立连接媒体服务，浏览海报墙并同步观看进度。"
    }
}

/// The same connection card and page surface are used in saved and empty states.
private struct TVConnectionPanel<Actions: View>: View {
    let summary: TVSavedConnectionSummary
    @ViewBuilder let actions: Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 20) {
                TVIconBadge(symbol: summary.symbol)
                VStack(alignment: .leading, spacing: 8) {
                    Text(summary.title).font(TVType.body.weight(.semibold))
                    Text(summary.status).font(TVType.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Text(summary.detail).font(TVType.caption).foregroundStyle(.secondary)
                .lineLimit(2).truncationMode(.middle).frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 54, alignment: .topLeading)
            HStack(spacing: 18) { actions }
                .font(TVType.caption).buttonStyle(TVServiceInsetStyle(padded: true))
        }.padding(28).frame(maxWidth: .infinity, alignment: .leading).tvCardSurface()
    }
}

#if DEBUG
/// Exercises the production native dialogs with local synthetic results, never TVAppState.
struct TVDisconnectConfirmationsOfflineScene: View {
    let configuration: OfflineUIConfiguration
    @State private var presented: TVDisconnectKind?
    @State private var feedback: String? = "旧错误（合成）"
    @State private var attempts = 0
    @State private var lastKind = "none"
    @State private var clearedAtStart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("断开确认 · 离线合成动作").font(TVType.title)
            Text("仅测试正式确认框，未连接或移除任何服务器。")
                .font(TVType.caption).foregroundStyle(.secondary)
            ForEach(TVDisconnectKind.allCases) { kind in
                Button(kind.actionTitle) { presented = kind }
                    .accessibilityIdentifier("offline.disconnect.open." + kind.rawValue)
                    .tvDisconnectConfirmation(kind, isPresented: Binding(
                        get: { presented == kind },
                        set: { if !$0 && presented == kind { presented = nil } }
                    )) {
                        feedback = nil
                        clearedAtStart = feedback == nil
                        attempts += 1
                        lastKind = kind.rawValue
                        feedback = "本次失败（合成）"
                    }
            }
            if let feedback {
                Text(feedback).font(TVType.caption).foregroundStyle(.red)
                    .accessibilityIdentifier("offline.disconnect.feedback")
            }
            Text("attempts=\(attempts) · kind=\(lastKind) · cleared=\(clearedAtStart ? "true" : "false")")
                .font(TVType.caption).accessibilityIdentifier("offline.disconnect.result")
            Button("恢复合成旧错误") { feedback = "旧错误（合成）"; clearedAtStart = false }
                .accessibilityIdentifier("offline.disconnect.reset")
        }
        .padding(64).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .tvPageTheme()
        .preferredColorScheme(configuration.appearance == .dark ? .dark : .light)
        .dynamicTypeSize(configuration.textSize == .large ? .accessibility2 : .large)
        .font(TVType.body).tint(AppTheme.accent)
    }
}

/// Uses the real connection cards, without TVAppState, accounts or clients.
struct TVAccountConnectionsOfflineScene: View {
    let configuration: OfflineUIConfiguration
    @State private var hasNAS = true
    @State private var hasJellyfin = false
    @State private var feedback: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: "连接管理", subtitle: "离线界面测试 · 合成配置")
                TVFixedFeatureGrid(columns: 2) {
                    TVConnectionPanel(summary: TVSavedConnectionSummary(kind: .nas,
                        server: hasNAS ? URL(string: "https://fixture:fixture-only@nas.invalid:5001/dsm?token=fixture-only#fixture") : nil)) {
                        Button("切换合成 NAS 配置") { hasNAS.toggle(); changed() }
                            .accessibilityIdentifier("offline.accounts.nas")
                    }
                    TVConnectionPanel(summary: TVSavedConnectionSummary(kind: .jellyfin,
                        server: hasJellyfin ? URL(string: "https://fixture:fixture-only@media.invalid:8920/jellyfin?api_key=fixture-only#fixture") : nil)) {
                        Button("切换合成影音授权") { hasJellyfin.toggle(); changed() }
                            .accessibilityIdentifier("offline.accounts.jellyfin")
                    }
                }
                if let feedback { Text(feedback).font(TVType.caption).foregroundStyle(.secondary) }
            }.tvPageInsets()
        }.tvPageTheme()
            .preferredColorScheme(configuration.appearance == .dark ? .dark : .light)
            .dynamicTypeSize(configuration.textSize == .large ? .accessibility2 : .large)
            .font(TVType.body).tint(AppTheme.accent)
    }
    private func changed() { feedback = "离线预览：仅切换合成配置，未连接、授权或移除任何服务器。" }
}

/// The real TV root pages in their disconnected state: a TVAppState without accounts
/// (no Keychain read), an ephemeral preference domain with sample local tasks.
/// The NAS-connected launchpad and devices need a DSM client and are out of scope.
/// Login forms stay reachable; do not submit them in an offline run.
@MainActor final class TVOfflineRootHost: ObservableObject {
    static let suiteName = "nastart.offline-ui.tv-roots"
    let suite: UserDefaults
    let state = TVAppState(offlineFixture: ())
    init(configuration: OfflineUIConfiguration) {
        UserDefaults.standard.removePersistentDomain(forName: Self.suiteName)
        guard let suite = UserDefaults(suiteName: Self.suiteName) else {
            preconditionFailure("离线界面测试：无法创建临时偏好域")
        }
        suite.set(configuration.theme.rawValue, forKey: "appearance.launchpadTheme")
        suite.set(configuration.appearance.rawValue, forKey: "appearance.themeMode")
        let day: TimeInterval = 86_400, now = Date()
        let tasks = [
            TVTaskRecord(title: "证书到期检查（示例）", due: now + 3 * day, kind: "certificate", target: "nas.invalid"),
            TVTaskRecord(title: "域名续费检查（示例）", due: now + 20 * day, kind: "domain"),
            TVTaskRecord(title: "服务运行检查（示例）", due: now - 2 * day, completed: true, kind: "service"),
        ]
        suite.set(try? JSONEncoder().encode(tasks), forKey: "tv.tasks.local.v1")
        self.suite = suite
    }
    deinit { UserDefaults.standard.removePersistentDomain(forName: Self.suiteName) }
}

struct TVOfflineRootScene: View {
    let configuration: OfflineUIConfiguration
    private let tab: TVRootTab
    @StateObject private var host: TVOfflineRootHost
    /// `--offline-ui-tab launchpad|devices|tasks|mine` overrides the scene's tab.
    init(configuration: OfflineUIConfiguration) {
        self.configuration = configuration
        let arguments = ProcessInfo.processInfo.arguments
        let requested = arguments.firstIndex(of: "--offline-ui-tab").flatMap {
            arguments.indices.contains($0 + 1) ? TVRootTab(rawValue: arguments[$0 + 1]) : nil
        }
        switch configuration.scenario {
        case .devicesRoot: tab = requested ?? .devices
        case .tasksRoot: tab = requested ?? .tasks
        default: tab = requested ?? .launchpad
        }
        _host = StateObject(wrappedValue: TVOfflineRootHost(configuration: configuration))
    }
    var body: some View {
        TVHomeView(initialTab: tab)
            .environmentObject(host.state)
            .defaultAppStorage(host.suite)
            .preferredColorScheme(configuration.appearance == .dark ? .dark : .light)
            .dynamicTypeSize(configuration.textSize == .large ? .accessibility2 : .large)
            .tint(TVTheme.accent).buttonStyle(NastartSecondaryButtonStyle()).font(TVType.body)
            .overlay(alignment: .topTrailing) {
                Text("离线界面测试 · 示例数据，未连接 NAS").font(.system(size: 18)).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule()).padding(24).allowsHitTesting(false)
                    .accessibilityIdentifier("offline.tv-roots.banner")
            }
    }
}
#endif

private struct TVNASConnectionBanner: View {
    @State private var connect = false
    var body: some View {
        HStack(spacing: 24) {
            TVIconBadge(symbol: "externaldrive.badge.exclamationmark")
            VStack(alignment: .leading, spacing: 10) {
                Text("NAS 未连接").font(TVType.section)
                Text("连接后查看设备资源和文件；已添加的网络媒体库仍可使用。")
                    .font(TVType.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 24)
            Button { connect = true } label: {
                Label("连接 NAS", systemImage: "link").font(TVType.body.weight(.semibold)).padding(20)
            }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.nas.connect")
        }.padding(28).frame(maxWidth: .infinity, alignment: .leading).tvCardSurface()
        .sheet(isPresented: $connect) { TVLoginView(initialKind: "DSM") }
    }
}

private struct TVDisconnectedLaunchpad: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TVLayout.sectionGap) {
                TVPageHeading(title: "启动台", subtitle: "设备与媒体，一处访问")
                TVNASConnectionBanner()
                Text("媒体").font(TVType.section)
                TVFixedFeatureGrid(columns: 2) {
                    NavigationLink { TVStorageEntry() } label: {
                        TVFeatureTile(title: "存储与媒体", subtitle: "已有媒体库 · 添加媒体文件夹", symbol: "externaldrive.badge.wifi")
                    }.accessibilityIdentifier("tv.open.networkLibrary")
                    NavigationLink { TVJellyfinEntry() } label: {
                        TVFeatureTile(title: "Jellyfin", subtitle: "电影 · 剧集 · 音乐", symbol: "play.rectangle.fill")
                    }.accessibilityIdentifier("tv.open.jellyfin")
                }
                Text("常用功能").font(TVType.section)
                TVFixedFeatureGrid(columns: 2) {
                    NavigationLink { TVConnectionsView() } label: {
                        TVFeatureTile(title: "连接管理", subtitle: "设备登录与影音授权", symbol: "externaldrive.badge.person.crop")
                    }.accessibilityIdentifier("tv.home.connections")
                    NavigationLink { TVHelpView() } label: {
                        TVFeatureTile(title: "帮助与关于", subtitle: "连接、文件与播放说明", symbol: "questionmark.circle")
                    }
                }
            }.tvPageInsets()
        }.tvPageTheme()
    }
}

/// Network media remains independent of the DSM login, using the existing library UI and playback host.
private struct TVStorageEntry: View {
    @EnvironmentObject private var state: TVAppState
    @AppStorage("appearance.launchpadTheme") private var theme = "cleanGrid"
    private var nas: NetworkNASContext? {
        guard let account = state.nasAccount else { return nil }
        return NetworkNASContext(name: "NAS 设备", address: account.server.absoluteString, account: account.user) {
            guard state.nasAccount == account else { throw NetworkMediaError.fileStationUnavailable }
            return try FileStationSource(address: account.server.absoluteString, sid: account.sid) {
                try await MainActor.run {
                    guard state.nasAccount == account else { throw NetworkMediaError.fileStationUnavailable }
                }
            }
        }
    }
    private var credits: NetworkMediaCreditsContext? {
        guard let account = state.account,
              let source = try? JellyfinCreditsSource(endpoint: account.server, userID: account.userID, token: account.token) else { return nil }
        return NetworkMediaCreditsContext(source: source) { state.account == account }
    }
    private var services: NetworkMediaServicesContext {
        let saved = state.account
        let candidates = saved.map { [MediaServiceCandidate(id: "saved-jellyfin", name: "Jellyfin", hint: .jellyfin,
            running: nil, endpoints: [$0.server], savedLoginEndpoints: [$0.server])] } ?? []
        return NetworkMediaServicesContext(candidates: candidates, inventory: .unavailable,
            savedLoginAvailable: { _, endpoint in saved.map { state.account == $0 && MediaServiceEndpoint.matches(endpoint, $0.server) } ?? false },
            reloadInventory: { nil }) { id, endpoint in
                guard id == "saved-jellyfin", let saved, state.account == saved,
                      MediaServiceEndpoint.matches(endpoint, saved.server) else { return nil }
                return AnyView(TVJellyfinEntry(initialServer: endpoint))
            }
    }
    var body: some View {
        networkMediaLibraryView(nas: nas,
            appearance: NetworkMediaAppearance(accent: TVTheme.accent, background: AnyView(TVPageBackground()),
                surface: AnyView(TVTheme.surface), commandStyle: theme == "commandCenter"), services: services,
            destinations: NetworkMediaDestinations(files: AnyView(files), media: AnyView(TVJellyfinEntry()),
                playback: { source, close in AnyView(TVNetworkLibraryPlayer(source: source, close: close)) }, credits: credits))
            .id(state.nasAccount?.sid)
    }
    @ViewBuilder private var files: some View {
        if let account = state.nasAccount { TVNASFiles(client: TVDSMClient(account: account), path: "/", title: "设备文件") }
        else { TVDeviceConnectionPrompt(feature: .files) }
    }
}

struct TVTaskRecord: Codable, Identifiable {
    var id = UUID()
    let title: String
    let due: Date
    var completed = false
    var kind: String? = nil
    var target: String? = nil
    var createdAt: Date? = nil
}
struct TVTaskDraft: Identifiable {
    let id = UUID()
    let initialTitle: String
}
struct TVTasksView: View {
    @AppStorage("tv.tasks.local.v1") private var stored = Data()
    @State private var segment = "watching"
    @State private var draft: TVTaskDraft?
    @State private var selected: TVTaskRecord?
    private var tasks: [TVTaskRecord] { (try? JSONDecoder().decode([TVTaskRecord].self, from: stored)) ?? [] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .bottom) {
                    TVPageHeading(title: "事项", subtitle: "此电视上的待办与完成记录")
                    Spacer()
                    Button("添加事项", systemImage: "plus") { draft = TVTaskDraft(initialTitle: "") }
                }.focusSection()
                HStack(spacing: TVLayout.gap) {
                    ForEach([("watching", "关注"), ("pending", "待办"), ("history", "历史")], id: \.0) { key, title in
                        Button { segment = key } label: {
                            HStack(spacing: 12) {
                                Text(title).font(TVType.body.weight(segment == key ? .semibold : .regular))
                                if segment == key { Image(systemName: "checkmark").font(TVType.caption).foregroundStyle(TVTheme.accent) }
                            }.frame(maxWidth: .infinity).padding(.vertical, 18)
                        }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.tasks." + key)
                    }
                }
                if segment == "watching" {
                  TVFixedFeatureGrid(columns: 3) {
                    ForEach([("certificate", "证书到期检查", "lock.shield"), ("domain", "域名续费检查", "globe"), ("service", "服务运行检查", "server.rack")], id: \.0) { entry in
                        Button { draft = TVTaskDraft(initialTitle: entry.1) } label: {
                            TVFeatureTile(title: entry.1, subtitle: "创建此电视上的检查事项", symbol: entry.2)
                        }.accessibilityIdentifier("tv.tasks.template." + entry.0)
                    }
                  }
                    Text("当前为手动检查事项，不会自动监控证书或发送系统通知。").font(TVType.caption).foregroundStyle(.secondary)
                }
                let visible = segment == "watching" ? [] : tasks.filter { $0.completed == (segment == "history") }.sorted { $0.due < $1.due }
                if segment != "watching" && visible.isEmpty {
                    VStack(spacing: 18) {
                        Image(systemName: segment == "history" ? "archivebox" : "checkmark.circle").font(.system(size: 45)).foregroundStyle(TVTheme.accent)
                        Text(segment == "history" ? "还没有完成记录" : "当前没有待办事项").font(TVType.section)
                        Text("可记录设备维护、服务检查等事项；此处暂不提供系统通知或跨设备同步。")
                            .font(TVType.caption).foregroundStyle(.secondary)
                    }.padding(60).frame(maxWidth: .infinity).tvCardSurface(radius: 20)
                }
                ForEach(visible) { item in
                    Button { selected = item                    } label: {
                        HStack(spacing: 22) {
                            Image(systemName: item.completed ? "checkmark.circle.fill" : "circle").foregroundStyle(TVTheme.accent)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title).font(TVType.body)
                                Text(item.due, style: .date).font(TVType.caption).foregroundStyle(.secondary)
                            }; Spacer()
                            Text("查看详情").font(TVType.caption).foregroundStyle(.secondary)
                        }.padding(28)
                    }.buttonStyle(TVTileStyle())
                }
            }.tvPageInsets()
        }.tvPageTheme().tvInformationLayout()
        .sheet(item: $draft) { draft in
            TVTaskEditor(initialTitle: draft.initialTitle) { item in
                var updated = tasks; updated.append(item)
                stored = (try? JSONEncoder().encode(updated)) ?? stored
                self.draft = nil
            }
        }
        .sheet(item: $selected) { item in
            TVTaskDetail(item: item) { updatedItem in
                var updated = tasks
                if let index = updated.firstIndex(where: { $0.id == item.id }) { updated[index] = updatedItem }
                stored = (try? JSONEncoder().encode(updated)) ?? stored; selected = nil
            }
        }
    }
}

struct TVTaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var target = ""
    @State private var kind: String
    @State private var days = 1
    @State private var advanced = false
    let onSave: (TVTaskRecord) -> Void
    private let kinds = [("certificate", "证书", "lock.shield"), ("domain", "域名", "globe"), ("service", "服务", "server.rack"), ("subscription", "订阅", "calendar")]
    init(initialTitle: String, onSave: @escaping (TVTaskRecord) -> Void) {
        _title = State(initialValue: initialTitle)
        _kind = State(initialValue: initialTitle.contains("域名") ? "domain" : initialTitle.contains("服务") ? "service" : "certificate")
        self.onSave = onSave
    }
    private var due: Date { Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack { TVPageHeading(title: "添加事项", subtitle: "确认名称和日期，即可保存到待办"); Spacer()
                    Button("取消", systemImage: "xmark") { dismiss() }.accessibilityIdentifier("tv.task.cancel")
                }.focusSection()
                TextField("事项名称", text: $title).accessibilityIdentifier("tv.task.title")
                Text("计划日期").font(TVType.section)
                HStack(spacing: TVLayout.gap) {
                    ForEach([(0, "今天"), (1, "明天"), (7, "一周后"), (30, "一个月后")], id: \.0) { value, label in
                        Button { days = value } label: {
                            Text(label).foregroundStyle(days == value ? TVTheme.accent : .primary).frame(maxWidth: .infinity).padding(18)
                        }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.task.date." + String(value))
                    }
                }
                Text(due, style: .date).font(TVType.body).foregroundStyle(.secondary)
                Button { advanced.toggle() } label: { Label(advanced ? "收起更多设置" : "更多设置（选填）", systemImage: advanced ? "chevron.up" : "chevron.down").padding(16) }
                    .buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.task.advanced")
                if advanced {
                    TextField("关联域名、证书或服务（选填）", text: $target).accessibilityIdentifier("tv.task.target")
                    HStack(spacing: TVLayout.gap) {
                        ForEach(kinds, id: \.0) { value, label, symbol in
                            Button { kind = value } label: { Label(label, systemImage: kind == value ? "checkmark.circle.fill" : symbol).frame(maxWidth: .infinity).padding(16) }
                                .buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.task.kind." + value)
                        }
                    }
                    HStack {
                        Button("前一天", systemImage: "minus") { days = max(0, days - 1) }.disabled(days == 0)
                        Spacer(); Text(due, style: .date); Spacer()
                        Button("后一天", systemImage: "plus") { days = min(3650, days + 1) }.disabled(days >= 3650)
                    }
                }
                Text("保存后可在待办中手动跟进，不会自动检查或发送通知。").font(TVType.caption).foregroundStyle(.secondary)
                Button("保存事项", systemImage: "checkmark") {
                    var item = TVTaskRecord(title: title.trimmingCharacters(in: .whitespacesAndNewlines), due: due)
                    item.kind = kind; item.target = target.trimmingCharacters(in: .whitespacesAndNewlines); item.createdAt = Date(); onSave(item)
                }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("tv.task.save")
                    .frame(maxWidth: .infinity, alignment: .leading).focusSection()
            }.tvPageInsets()
        }.font(TVType.body).tvPageTheme().tvInformationLayout().onExitCommand { dismiss() }
    }
}

struct TVTaskDetail: View {
    @Environment(\.dismiss) private var dismiss
    let item: TVTaskRecord
    let onUpdate: (TVTaskRecord) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: "事项详情", subtitle: item.completed ? "历史记录" : "待办事项")
                HStack(spacing: 24) { TVIconBadge(symbol: item.completed ? "checkmark.circle" : "calendar"); Text(item.title).font(TVType.title) }
                TVInformationCard(rows: [("关联对象", item.target.flatMap { $0.isEmpty ? nil : $0 } ?? "未关联"),
                    ("计划日期", item.due.formatted(date: .abbreviated, time: .omitted)),
                    ("创建日期", item.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "旧版事项未记录"),
                    ("状态", item.completed ? "已完成" : "待办")])
                Text("操作").font(TVType.section)
                Button(item.completed ? "恢复待办" : "标记完成", systemImage: item.completed ? "arrow.uturn.backward" : "checkmark.circle") {
                    var updated = item; updated.completed.toggle(); onUpdate(updated)
                }.accessibilityIdentifier("tv.task.complete")
            }.tvPageInsets()
        }.font(TVType.body).tvPageTheme().tvInformationLayout().onExitCommand { dismiss() }
    }

}

struct TVNASOverview: View {
    @EnvironmentObject private var state: TVAppState
    @EnvironmentObject private var serviceSync: TVCloudSyncStore
    let client: TVDSMClient
    @AppStorage("tv.show.service.details") private var showDetails = false
    @AppStorage("appearance.launchpadTheme") private var theme = "cleanGrid"
    @AppStorage("appearance.compactMetrics") private var compactMetrics = true
    @State private var manageServices = false
    private var visibleServices: [TVDiscoveredService] {
        serviceSync.visibleContainers(in: discovery.services)
    }
    @State private var discovery = TVServiceDiscovery()
    @State private var discoveryAccount: TVNASAccount?
    @State private var discoveryRefreshFailed = false
    @State private var discovering = true
    @State private var connectJF = false
    @State private var openJellyfin = false
    @State private var initialJFServer: URL?
    @State private var serviceDetail: TVDiscoveredService?
    @State private var status = TVNASStatusSnapshot()
    @State private var sharedFolderCount: Int?
    @State private var movieCount: Int?
    @State private var error: String?
    @State private var loading = true
    @State private var refresh = UUID()
    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: TVLayout.sectionGap) {
                    HStack(alignment: .bottom) {
                        TVPageHeading(title: "启动台", subtitle: "设备状态与常用服务，一处掌握")
                        Spacer()
                        Button { refresh = UUID() } label: {
                            Label("刷新", systemImage: "arrow.clockwise").font(.system(size: 25, weight: .medium)).padding(20)
                        }.buttonStyle(TVTileStyle()).disabled(loading)
                    }.focusSection()
                    if let error { Text(error).font(TVType.caption).foregroundStyle(.red) }
                    summary.padding(theme == "cleanGrid" ? 0 : 28)
                        .background {
                            if theme == "glassDeck" { RoundedRectangle(cornerRadius: TVLayout.radius).fill(.regularMaterial) }
                            else if theme == "commandCenter" { RoundedRectangle(cornerRadius: TVLayout.radius).fill(TVTheme.surface) }
                        }
                    HStack(spacing: TVLayout.gap) {
                        metric("CPU", symbol: "cpu", value: status.cpu)
                        metric("内存", symbol: "memorychip", value: status.memory)
                        metric("硬盘", symbol: "internaldrive", value: status.storage)
                    }
                    shortcuts
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Text("Docker 服务").font(.system(size: 32, weight: .semibold))
                            Spacer()
                            Text("\(visibleServices.count) / \(discovery.services.filter { $0.kind == "容器" }.count) 项显示").font(TVType.caption).foregroundStyle(.secondary)
                            Button { manageServices = true } label: {
                                Label { Text("管理显示").foregroundStyle(.secondary) }
                                    icon: { Image(systemName: "slider.horizontal.3").foregroundStyle(TVTheme.accent) }
                                    .font(TVType.caption).padding(.horizontal, 16).padding(.vertical, 12)
                            }.buttonStyle(TVServiceInsetStyle()).accessibilityIdentifier("tv.services.manageVisibility")
                        }.focusSection()
                        if discovering { ProgressView("正在发现服务") }
                        ForEach(discovery.warnings, id: \.self) { Text($0).font(TVType.caption).foregroundStyle(.secondary) }
                        if !discovering && discovery.services.isEmpty && discovery.warnings.isEmpty {
                            Text("当前账号没有可见服务。仍可从 Jellyfin 入口手动连接。")
                        }
                        ForEach(TVServiceCategory.allCases) { category in
                            let services = visibleServices.filter { $0.category == category }
                            if !services.isEmpty {
                                TVServiceGroup(category: category, services: services, client: client, showDetails: showDetails)
                            }
                        }

                    }
                }.frame(maxWidth: 1650, alignment: .leading).padding(.horizontal, 70).padding(.top, TVLayout.pageTop).padding(.bottom, 70)
            }.tvPageTheme()
            .navigationDestination(isPresented: $manageServices) {
                TVServiceVisibilityView(services: discovery.services)
            }
            .navigationDestination(isPresented: $openJellyfin) { TVJellyfinEntry() }
            .sheet(isPresented: $connectJF) { TVLoginView(initialKind: "Jellyfin", initialServer: initialJFServer) }
            .task(id: refresh.uuidString + client.server.absoluteString + (client.account?.user ?? "") + (client.account?.sid ?? "")) {
                let expected = client.account
                discovering = true; discoveryAccount = nil; discoveryRefreshFailed = false
                defer { if state.nasAccount == expected { discovering = false } }
                do {
                    let result = try await client.discoverServices()
                    guard !Task.isCancelled, state.nasAccount == expected else { return }
                    serviceSync.migrateLegacyVisibility(using: result)
                    discovery = result; discoveryAccount = expected
                } catch {
                    if !Task.isCancelled, state.nasAccount == expected { discovery = TVServiceDiscovery(warnings: [nasError(error)]) }
                }
            }
            .task(id: refresh) {
                loading = true; error = nil
                defer { loading = false }
                do { status = try await client.statusSnapshot() }
                catch { if !Task.isCancelled { status.reachable = false; self.error = nasError(error) } }
            }
            .task(id: refresh) {
                sharedFolderCount = nil
                if let page = try? await client.files(path: "/"), !Task.isCancelled {
                    sharedFolderCount = page.total.flatMap { $0 >= 0 ? $0 : nil }
                        ?? (page.items.count < 100 ? page.items.filter(\.isdir).count : nil)
                }
            }
            .task(id: state.account.map { [$0.server.absoluteString, $0.userID, $0.token] }) {
                movieCount = nil
                guard let account = state.account else { return }
                let count = try? await TVJellyfinClient(account: account, deviceID: state.deviceID).movieCount()
                guard !Task.isCancelled, state.account == account else { return }
                movieCount = count
            }
        }
    }
    private var summary: some View {
        HStack(spacing: 24) {
                        TVIconBadge(symbol: "externaldrive.connected.to.line.below.fill")
                        VStack(alignment: .leading, spacing: 10) {
                            Text(status.name).font(TVType.section)
                            Text([status.model, status.version].joined(separator: " · ")).font(TVType.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 10) {
                            Label(loading ? "读取中" : (status.reachable ? "在线" : "连接异常"), systemImage: status.reachable ? "checkmark.circle.fill" : "wifi.exclamationmark")
                                .foregroundStyle(status.reachable ? .green : TVTheme.accent)
                            Label("运行 " + status.uptimeText, systemImage: "clock")
                            Text(loading ? "正在检查状态" : (status.warnings.isEmpty && status.cpu != nil && status.memory != nil && status.storage != nil ? "资源状态已更新" : "部分指标未提供 · 在资源概览查看"))
                                .foregroundStyle(.secondary)
                        }.font(TVType.caption)
                    }
    }
    private var networkServicesContext: NetworkMediaServicesContext {
        let account = state.nasAccount
        let current = account != nil && account == discoveryAccount
        let services = current ? discovery.services : []
        var candidates = services.compactMap { service -> MediaServiceCandidate? in
            guard let product = MediaServiceProduct.hint(name: service.name, detail: service.detail) else { return nil }
            var endpoints = service.verifiedJellyfin.map { [$0] } ?? []
            endpoints += service.managementEndpoints
            for port in service.ports.prefix(2) {
                for scheme in [client.server.scheme ?? "https", "http"] {
                    var parts = URLComponents(url: client.server, resolvingAgainstBaseURL: false)!
                    parts.scheme = scheme; parts.port = port; parts.path = ""; parts.query = nil; parts.fragment = nil
                    if let endpoint = parts.url { endpoints.append(endpoint) }
                }
            }
            let saved = product == .jellyfin ? endpoints.filter { endpoint in
                guard let saved = state.account else { return false }
                return MediaServiceEndpoint.matches(endpoint, saved.server) && !saved.token.isEmpty
            } : []
            return MediaServiceCandidate(id: service.id, name: service.name, hint: product, running: service.running,
                endpoints: endpoints, savedLoginEndpoints: saved)
        }
        // A saved media login is its own source. Missing NAS inventory must not hide it
        // or imply that this independently configured server belongs to the NAS.
        if let saved = state.account, !saved.token.isEmpty,
           let endpoint = try? MediaServiceEndpoint(saved.server),
           !candidates.contains(where: { $0.hint == .jellyfin && $0.endpoints.contains(endpoint) }) {
            candidates.insert(MediaServiceCandidate(id: "saved-jellyfin", name: "已保存的 Jellyfin", hint: .jellyfin,
                running: nil, endpoints: [saved.server], savedLoginEndpoints: [saved.server]), at: 0)
        }
        return NetworkMediaServicesContext(candidates: candidates, inventory: !current ? .unavailable : (discoveryRefreshFailed ? .cached : (discovery.complete ? .available : .partial)), savedLoginAvailable: { id, endpoint in
            guard state.nasAccount == account, candidates.contains(where: { $0.id == id && $0.hint == .jellyfin }),
                  let saved = state.account else { return false }
            return MediaServiceEndpoint.matches(endpoint, saved.server) && !saved.token.isEmpty
        }, reloadInventory: {
            guard state.nasAccount == account, let account, client.account == account else { return nil }
            do {
                let result = try await client.discoverServices()
                guard !Task.isCancelled, state.nasAccount == account else { return nil }
                discovery = result; discoveryAccount = account; discoveryRefreshFailed = false
            } catch {
                guard !Task.isCancelled, state.nasAccount == account else { return nil }
                discoveryRefreshFailed = true
            }
            return networkServicesContext
        }) { id, endpoint in
            guard state.nasAccount == account, let candidate = candidates.first(where: { $0.id == id }), candidate.hint == .jellyfin,
                  let key = try? MediaServiceEndpoint(endpoint), candidate.endpoints.contains(key) else { return nil }
            return AnyView(TVJellyfinEntry(initialServer: endpoint))
        }
    }
    @ViewBuilder private var networkRowSurface: some View {
        if theme == "glassDeck" { Rectangle().fill(.regularMaterial) }
        else { TVTheme.surface }
    }
    private var networkNASContext: NetworkNASContext? {
        guard let account = state.nasAccount else { return nil }
        return NetworkNASContext(name: status.name, address: account.server.absoluteString, account: account.user) {
            guard state.nasAccount == account else { throw NetworkMediaError.fileStationUnavailable }
            return try FileStationSource(address: account.server.absoluteString, sid: account.sid) {
                try await MainActor.run {
                    guard state.nasAccount == account else { throw NetworkMediaError.fileStationUnavailable }
                }
            }
        }
    }
    private var networkCreditsContext: NetworkMediaCreditsContext? {
        guard let account = state.account,
              let source = try? JellyfinCreditsSource(endpoint: account.server, userID: account.userID, token: account.token) else { return nil }
        return NetworkMediaCreditsContext(source: source) { state.account == account }
    }
    private var shortcuts: some View {
        VStack(spacing: TVLayout.gap) {
          NavigationLink {
              networkMediaLibraryView(nas: networkNASContext, appearance: NetworkMediaAppearance(accent: TVTheme.accent,
                  background: AnyView(TVPageBackground()), surface: AnyView(networkRowSurface), commandStyle: theme == "commandCenter"), services: networkServicesContext,
                  destinations: NetworkMediaDestinations(files: AnyView(TVNASFiles(client: client, path: "/", title: "设备文件")), media: AnyView(TVJellyfinEntry()),
                      playback: { source, close in AnyView(TVNetworkLibraryPlayer(source: source, close: close)) }, credits: networkCreditsContext))
                  .id(state.nasAccount?.sid)
          }
              label: { TVFeatureTile(title: "存储与媒体", subtitle: "浏览文件 · 整理媒体库", symbol: "externaldrive.badge.wifi") }
              .environment(\.tvCompactInformation, true)
              .buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.open.networkLibrary")
        }
    }
    private func metric(_ name: String, symbol: String, value: Double?) -> some View {
        HStack(spacing: 24) {
            TVIconBadge(symbol: symbol)
            VStack(alignment: .leading, spacing: 10) {
                Text(name).font(TVType.body.weight(.semibold))
                Text(value.map { String(format: "%.0f%%", min(100, max(0, $0))) } ?? "—")
                    .font(TVType.section).monospacedDigit()
                GeometryReader { geometry in
                    Capsule().fill(TVTheme.separator).overlay(alignment: .leading) {
                        Capsule().fill(TVTheme.accent).frame(width: geometry.size.width * min(1, max(0, (value ?? 0) / 100)))
                    }
                }.frame(height: 4)
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).frame(height: compactMetrics ? TVLayout.informationRowHeight : TVLayout.cardHeight)
            .background {
                if theme == "glassDeck" { RoundedRectangle(cornerRadius: TVLayout.radius).fill(.regularMaterial) }
                else { RoundedRectangle(cornerRadius: TVLayout.radius).fill(TVTheme.surface) }
            }
    }

}

struct TVNASFiles: View {
    let client: TVDSMClient
    let path: String
    let title: String
    @State private var files: [TVNASFile] = []
    @State private var loading = true
    @State private var error: String?
    @State private var reload = UUID()
    @State private var hasMore = false
    @State private var offset = 0
    @State private var loadMore: Task<Void, Never>?
    @State private var search = ""
    @State private var playback: TVNASFile?
    @State private var information: TVNASFile?
    @State private var sort = TVNASFileSort.name
    @State private var ascending = true
    @State private var total: Int?
    @State private var showingSort = false
    private struct RequestID: Equatable {
        let reload: UUID
        let sort: TVNASFileSort
        let ascending: Bool
    }
    private var requestID: RequestID { RequestID(reload: reload, sort: sort, ascending: ascending) }
    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var visibleFiles: [TVNASFile] { files.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .bottom) {
                    TVPageHeading(title: title, subtitle: path == "/" ? "共享文件夹" : path)
                    Spacer()
                    Text(total.map { "已加载 \(files.count) / \($0) 项" } ?? "已加载 \(files.count) 项")
                        .font(TVType.caption).monospacedDigit().foregroundStyle(.secondary)
                }
                HStack(spacing: 24) {
                    TextField("筛选已加载的文件", text: $search).accessibilityIdentifier("tv.files.filter")
                    Button { showingSort = true }
                        label: { Label(sort.title + (ascending ? "升序" : "降序"), systemImage: "arrow.up.arrow.down") }
                        .accessibilityIdentifier("tv.files.sort")
                    Button("刷新", systemImage: "arrow.clockwise") { reload = UUID() }.disabled(loading)
                        .accessibilityIdentifier("tv.files.refresh")
                }.font(TVType.caption)
                Text(hasMore ? "筛选仅限已加载项目；继续加载可查看其余文件。长按项目可查看文件信息。" : "长按项目可查看文件信息；视频与音乐可直接播放。")
                    .font(TVType.caption).foregroundStyle(.secondary)
                if loading { ProgressView("正在加载文件") }
                if let error { Text(error).foregroundStyle(.red); Button("重试") { reload = UUID() } }
                LazyVStack(spacing: 14) {
                    ForEach(visibleFiles) { file in
                        Group {
                            if file.isdir {
                                NavigationLink { TVNASFiles(client: client, path: file.path, title: file.name) }
                                    label: { fileRow(file) }
                            } else {
                                Button { if file.isMedia { playback = file } else { information = file } }
                                    label: { fileRow(file) }
                            }
                        }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.files.item." + file.path)
                            .contextMenu { Button("文件信息", systemImage: "info.circle") { information = file } }
                    }
                }
                if !loading && files.isEmpty && error == nil { Text("目录为空。").foregroundStyle(.secondary) }
                if !loading && !files.isEmpty && !query.isEmpty && visibleFiles.isEmpty {
                    Text(hasMore ? "已加载项目中没有匹配项，可继续加载。" : "当前目录没有匹配的文件。")
                        .foregroundStyle(.secondary).accessibilityIdentifier("tv.files.noMatches")
                }
            if hasMore {
                Button(loading ? "正在加载…" : "加载更多") {
                    loading = true; error = nil
                    let generation = requestID
                    loadMore = Task {
                        defer { if generation == requestID { loading = false } }
                        do {
                            let page = try await client.files(path: path, offset: offset, sort: generation.sort, ascending: generation.ascending); try Task.checkCancellation()
                            guard generation == requestID else { return }
                            append(page)
                        } catch { if !Task.isCancelled && generation == requestID { self.error = nasError(error) } }
                    }
                }.disabled(loading).accessibilityIdentifier("tv.files.more")
            }
            }.padding(.horizontal, 80).padding(.top, TVLayout.pageTop).padding(.bottom, 70)
        }.tvPageTheme().tvNavigationBack()
        .task(id: requestID) {
            let generation = requestID
            loadMore?.cancel(); loading = true; error = nil; hasMore = false; files = []; offset = 0; total = nil
            defer { if generation == requestID { loading = false } }
            do {
                let page = try await client.files(path: path, sort: generation.sort, ascending: generation.ascending); try Task.checkCancellation()
                guard generation == requestID else { return }
                append(page)
            } catch { if !Task.isCancelled && generation == requestID { self.error = nasError(error) } }
        }
        .onDisappear { loadMore?.cancel() }
        .fullScreenCover(item: $playback) { file in TVNASPlayerView(client: client, file: file) }
        .sheet(item: $information) { file in TVNASFileInformation(file: file) }
        .sheet(isPresented: $showingSort) {
            TVNASFileSortOptions(sort: $sort, ascending: $ascending, sharedFolders: path == "/")
        }
    }
    private func fileRow(_ file: TVNASFile) -> some View {
        HStack(spacing: 22) {
            Image(systemName: file.isdir ? "folder.fill" : (file.isAudio ? "music.note" : (file.isMedia ? "play.rectangle.fill" : "doc")))
                .font(.system(size: 28)).foregroundStyle(file.isdir ? TVTheme.accent : Color.secondary)
                .frame(width: 58, height: 58).background(TVTheme.separator, in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 6) {
                Text(file.name).font(TVType.body.weight(.medium)).lineLimit(2)
                if let modified = file.modifiedAt {
                    Text(modified, format: .dateTime.year().month().day().hour().minute()).font(TVType.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(file.isdir ? "文件夹" : file.formattedSize).font(.system(size: 22)).foregroundStyle(.secondary)
            Image(systemName: file.isdir ? "chevron.right" : (file.isMedia ? "play.fill" : "info.circle"))
                .font(.system(size: 15)).foregroundStyle(.secondary).frame(width: 24)
        }.padding(.horizontal, 24).padding(.vertical, 15)
    }
    private func append(_ page: TVNASFilePage) {
        var seen = Set(files.map(\.path))
        files += page.items.filter { seen.insert($0.path).inserted }
        offset += page.items.count
        total = page.total.flatMap { $0 >= 0 ? $0 : nil }
        hasMore = page.total.map { offset < $0 } ?? (page.items.count == 100)
        if page.items.isEmpty { hasMore = false }
    }
}

private struct TVNASFileSortOptions: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sort: TVNASFileSort
    @Binding var ascending: Bool
    let sharedFolders: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: "文件排序", subtitle: "按所选顺序重新读取整个目录")
                Text("排序方式").font(TVType.section)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
                    ForEach(TVNASFileSort.allCases.filter { !sharedFolders || $0 == .name || $0 == .modified }) { option in
                        Button { sort = option; dismiss() } label: {
                            Label(option.title, systemImage: option == sort ? "checkmark.circle.fill" : "circle")
                                .font(TVType.body).frame(maxWidth: .infinity, alignment: .leading).padding(24)
                        }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.files.sort." + option.rawValue)
                    }
                }
                Text("顺序").font(TVType.section)
                HStack(spacing: 24) {
                    Button { ascending = true; dismiss() } label: { Label("升序", systemImage: ascending ? "checkmark.circle.fill" : "circle") }
                        .accessibilityIdentifier("tv.files.sort.ascending")
                    Button { ascending = false; dismiss() } label: { Label("降序", systemImage: !ascending ? "checkmark.circle.fill" : "circle") }
                        .accessibilityIdentifier("tv.files.sort.descending")
                }.font(TVType.body)
            }.tvPageInsets()
        }.tvPageTheme().tvNavigationBack()
    }
}

private struct TVNASFileInformation: View {
    let file: TVNASFile
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: "文件信息", subtitle: file.name)
                TVInformationCard(rows: [("类型", file.kindDescription), ("路径", file.path),
                    ("大小", file.isdir ? "未统计文件夹内容" : file.formattedSize),
                    ("修改时间", file.modifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? "未提供")])
                if !file.isdir && !file.isMedia {
                    Text("此类型暂未提供电视端预览，可在 iPhone 或 iPad 上继续查看。")
                        .font(TVType.caption).foregroundStyle(.secondary)
                }
            }.tvPageInsets()
        }.tvPageTheme().tvInformationLayout().tvNavigationBack()
            .accessibilityIdentifier("tv.files.information")
    }
}

private func nasError(_ error: Error) -> String {
    (error as? TVDSMError)?.localizedDescription ?? (error as? TVClientError)?.localizedDescription ?? "无法连接 NAS，请检查地址和网络后重试。"
}

struct TVNASPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    let client: TVDSMClient
    let file: TVNASFile
    var body: some View {
        TVUnifiedPlaybackView(source: .file(client: client, file: file)) { dismiss() }
    }
}

/// Reuses the device-file KS renderer. Source authentication and lifetime are
/// owned by NetworkMedia; no NAS account or credential reaches the decoder.
private struct TVNetworkLibraryPlayer: View {
    let source: NetworkMediaPlaybackSource
    let close: () -> Void
    var body: some View {
        TVUnifiedPlaybackView(source: .network(source), close: close)
    }
}

/// Translates decoder actions into the same model contract used by Jellyfin.
/// It owns no buttons, panels, gestures or source credentials.
@MainActor final class TVKSPlaybackControls: ObservableObject, TVPlaybackControlling {
    let coordinator = KSVideoPlayer.Coordinator()
    @Published private(set) var seconds = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var playing = true
    @Published private(set) var muted = false
    @Published private(set) var rate: Float = 1
    @Published private(set) var audio: [TVPlayerControlsModel.Track] = []
    @Published private(set) var subtitles: [TVPlayerControlsModel.Track] = []
    @Published private(set) var selectedAudio = -1
    @Published private(set) var selectedSubtitle = -1
    @Published var fillsScreen = false
    var canDisableSubtitles: Bool { !subtitles.isEmpty || coordinator.subtitleModel.selectedSubtitleInfo != nil }
    var onReady: (() -> Void)?
    private var timer: AnyCancellable?
    private var seekState = PlaybackSeekState()
    private var pendingSeek: Double? { seekState.pendingTarget }
    var seekGeneration: Int { seekState.generation }
    init() { KSOptions.firstPlayerType = KSMEPlayer.self }
    func restoreIntent(playing: Bool, muted: Bool, rate: Float, fillsScreen: Bool) {
        self.playing = playing; self.muted = muted; self.rate = rate; self.fillsScreen = fillsScreen
        coordinator.onStateChanged = { [weak self] layer, state in
            guard let self, state == .readyToPlay else { return }
            layer.player.isMuted = self.muted
            layer.player.playbackRate = self.rate
            self.coordinator.isMuted = self.muted
            self.coordinator.isScaleAspectFill = self.fillsScreen
            // pause() also clears the layer's autoplay flag before readyToPlay
            // proceeds, so a paused replacement cannot briefly resume itself.
            if !self.playing { layer.pause() }
            self.onReady?()
        }
    }
    func start() {
        guard timer == nil else { return }
        timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        refresh()
    }
    func stop() {
        timer?.cancel(); timer = nil; seekState.invalidate()
        coordinator.playerLayer?.pause(); coordinator.resetPlayer(); onReady = nil
    }
    private func refresh() {
        guard let player = coordinator.playerLayer?.player else { return }
        let t = player.currentPlaybackTime, d = player.duration
        if pendingSeek == nil, t.isFinite { seconds = max(0, t) }
        duration = d.isFinite ? max(0, d) : 0
        muted = player.isMuted; rate = coordinator.playbackRate
        let tracks = player.tracks(mediaType: .audio)
        audio = tracks.enumerated().map { offset, track in
            let name = track.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return TVPlayerControlsModel.Track(id: Int(track.trackID), name: "音轨 \(offset + 1)" + (name.isEmpty ? "" : " · " + name))
        }
        selectedAudio = tracks.first(where: { $0.isEnabled }).map { Int($0.trackID) } ?? -1
        subtitles = coordinator.subtitleModel.subtitleInfos.compactMap { info in
            guard let id = Int(info.subtitleID) else { return nil }
            return TVPlayerControlsModel.Track(id: id, name: info.name)
        }
        selectedSubtitle = coordinator.subtitleModel.selectedSubtitleInfo.flatMap { Int($0.subtitleID) } ?? -1
    }
    func toggle() {
        guard let layer = coordinator.playerLayer else { return }
        playing.toggle()
        if playing { layer.play() } else { layer.pause() }
        refresh()
    }
    func toggleMute() { coordinator.isMuted.toggle(); refresh() }
    func seek(delta: Double) {
        guard let layer = coordinator.playerLayer,
              let target = seekState.target(relative: delta, clock: layer.player.currentPlaybackTime,
                  fallback: seconds, duration: duration),
              let request = seekState.begin(absolute: target, duration: duration) else { return }
        seconds = request.target
        let native = layer.player
        PlaybackSeekCommandExecutor.submit(target: request.target,
            isCurrent: { [weak self, weak layer, weak native] in
                guard let self, let layer, let native else { return false }
                return self.coordinator.playerLayer === layer && layer.player === native
                    && self.seekState.owns(generation: request.generation)
            }, seek: { [weak layer] target, completion in
                guard let layer, layer.player.isReadyToPlay, layer.player.seekable else {
                    completion(false); return
                }
                layer.seek(time: target, autoPlay: false, completion: completion)
            }, willComplete: { [weak self] _ in
                self?.seekState.complete(generation: request.generation)
            }, restoreIntent: { [weak layer] in
                guard let layer else { return }
                if layer.wantsPlayback { layer.play() } else { layer.pause() }
            }, didComplete: { [weak self, weak layer] completed in
                guard let self, let layer else { return }
                if completed { self.playing = layer.wantsPlayback }
                self.refresh()
            })
    }
    func restart() { seek(delta: -seconds) }
    func setRate(_ value: Float) {
        guard value.isFinite, value > 0 else { return }
        coordinator.playbackRate = value; refresh()
    }
    func selectAudio(_ index: Int) {
        guard let id = Int32(exactly: index), let player = coordinator.playerLayer?.player,
              let track = player.tracks(mediaType: .audio).first(where: { $0.trackID == id }) else { return }
        player.select(track: track); refresh()
    }
    func selectSubtitle(_ index: Int) {
        if index == -1 { coordinator.subtitleModel.selectedSubtitleInfo = nil }
        else if let info = coordinator.subtitleModel.subtitleInfos.first(where: { $0.subtitleID == String(index) }) {
            coordinator.subtitleModel.selectedSubtitleInfo = info
            if let track = info as? MediaPlayerTrack { coordinator.playerLayer?.player.select(track: track) }
        }
        refresh()
    }
}


enum TVServiceCategory: String, CaseIterable, Identifiable {
    case favorites, media, downloads, network, tools
    var id: String { rawValue }
    var title: String { switch self { case .favorites: return "收藏"; case .media: return "媒体"; case .downloads: return "下载"; case .network: return "网络"; case .tools: return "工具" } }
    var symbol: String { switch self { case .favorites: return "star"; case .media: return "play.rectangle"; case .downloads: return "arrow.down.circle"; case .network: return "network"; case .tools: return "wrench.and.screwdriver" } }
}
extension TVDiscoveredService {
    var defaultLaunchpadVisible: Bool {
        kind == "容器"
    }
    var symbolName: String {
        NASServiceCategory.symbolName(name: name, detail: detail) ?? (kind == "容器" ? "shippingbox" : "app.dashed")
    }
    var category: TVServiceCategory {
        TVServiceCategory(rawValue: (NASServiceCategory.matching(name: name, detail: detail) ?? .tools).rawValue) ?? .tools
    }
}
struct TVServiceGroup: View {
    let category: TVServiceCategory
    let services: [TVDiscoveredService]
    let client: TVDSMClient
    let showDetails: Bool
    @AppStorage("appearance.showServiceStatus") private var showServiceStatus = true
    @AppStorage("appearance.card.showSubtitle") private var showCardSubtitle = false
    @State private var expanded = true
    @State private var selectedService: TVDiscoveredService?
    @State private var showingService = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { expanded.toggle() } label: {
                HStack(spacing: 14) {
                    Label(category.title, systemImage: category.symbol).font(TVType.section)
                    Text(String(services.count)).font(TVType.caption).foregroundStyle(.secondary)
                    Spacer(); Image(systemName: expanded ? "chevron.up" : "chevron.down").font(TVType.caption)
                }.padding(.horizontal, 18).padding(.vertical, 14)
            }.buttonStyle(TVServiceInsetStyle())
                .accessibilityIdentifier("tv.service.group." + category.rawValue + ".toggle")
                .accessibilityValue(expanded ? "已展开" : "已折叠")
                .accessibilityHint("选择以展开或折叠这一组服务")
            if expanded {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], spacing: 8) {
                    ForEach(services) { service in
                        if let endpoint = service.verifiedJellyfin {
                            NavigationLink { TVJellyfinEntry(initialServer: endpoint) }
                                label: { row(service, action: "打开媒体库", interactive: true) }.buttonStyle(TVServiceInsetStyle(card: true))
                                .accessibilityIdentifier("tv.service.item." + service.id)
                        } else {
                            Button { selectedService = service; showingService = true }
                                label: { row(service, action: "查看状态与连接资料", interactive: true) }.buttonStyle(TVServiceInsetStyle(card: true))
                                .accessibilityIdentifier("tv.service.item." + service.id)

                        }
                    }
                }
            }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .tvCardSurface(radius: TVLayout.radius)
            // Register the destination outside LazyVGrid's cells. The stack
            // owns the presentation and its native Menu pop.
            .navigationDestination(isPresented: $showingService) {
                if let selectedService { TVServiceDetailView(service: selectedService, client: client) }
            }
    }
    private func row(_ service: TVDiscoveredService, action: String, interactive: Bool) -> some View {
        HStack(spacing: 20) {
            TVIconBadge(symbol: service.symbolName)
            VStack(alignment: .leading, spacing: 8) {
                Text(service.name).font(TVType.body).lineLimit(1)
                if showDetails { Text(service.detail).font(TVType.caption).foregroundStyle(.secondary).lineLimit(1) }
                else if interactive && showCardSubtitle { Text(action).font(TVType.caption).foregroundStyle(.secondary) }
            }; Spacer()
            if showServiceStatus {
                Circle().fill(service.running == true ? .green : .gray).frame(width: 8, height: 8)
                Text(service.running.map { $0 ? "运行中" : "已停止" } ?? "未知").font(TVType.caption).foregroundStyle(.secondary)
            }
            if interactive { Image(systemName: "chevron.right").font(.system(size: 15)).foregroundStyle(.secondary) }
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: TVLayout.informationRowHeight)
    }
}

/// Service groups share one surface; focus highlights the selected inset row.
private struct TVServiceInsetStyle: ButtonStyle {
    var card = false
    /// Text-only actions carry no padding of their own; keep the focus ring off the glyphs.
    var padded = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, padded ? 20 : 0).padding(.vertical, padded ? 10 : 0)
            .modifier(TVServiceInsetFocus(card: card))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct TVServiceInsetFocus: ViewModifier {
    let card: Bool
    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.primary)
            .background(Color.primary.opacity(card ? 0.04 : 0), in: RoundedRectangle(cornerRadius: 16))
            .background(TVTheme.accent.opacity(focused ? 0.16 : 0), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(focused ? TVTheme.accent : (card ? Color.primary.opacity(0.18) : .clear), lineWidth: focused ? 3 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: focused)
    }
}
struct TVServiceVisibilityView: View {
    @EnvironmentObject private var serviceSync: TVCloudSyncStore
    let services: [TVDiscoveredService]
    var body: some View {
        GeometryReader { viewport in
            let horizontalInset: CGFloat = 70
            let contentWidth = max(0, viewport.size.width - 2 * horizontalInset)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    TVPageHeading(title: "管理显示", subtitle: "Docker 服务与设备中的容器清单一致")
                    Text("Docker 服务默认显示，可按需隐藏；套件请在设备页面查看。")
                        .font(TVType.caption).foregroundStyle(.secondary)
                    ForEach(TVServiceCategory.allCases) { category in
                        let rows = services.filter { $0.kind == "容器" && $0.category == category }
                        if !rows.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(category.title, systemImage: category.symbol).font(TVType.section).padding(18)
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], spacing: 8) {
                                    ForEach(rows) { service in
                                        Button { Task { await serviceSync.toggle(service) } } label: {
                                            HStack(spacing: 20) {
                                                Image(systemName: service.symbolName).font(.system(size: 28)).foregroundStyle(TVTheme.accent).frame(width: 36)
                                                Image(systemName: serviceSync.isVisible(service) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(TVTheme.accent).frame(width: 36)
                                                Text(service.name).font(TVType.body).lineLimit(2)
                                                Spacer()
                                                Text(serviceSync.isVisible(service) ? "显示" : "隐藏").font(TVType.caption).foregroundStyle(.secondary)
                                            }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                                                .frame(minHeight: TVLayout.informationRowHeight)
                                        }.buttonStyle(TVServiceInsetStyle(card: true))
                                            .disabled(service.launchpadVisibilityKey == nil)
                                            .accessibilityIdentifier("tv.visibility." + service.id)
                                            .accessibilityLabel(service.name)
                                            .accessibilityValue(serviceSync.isVisible(service) ? "显示" : "隐藏")
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tvCardSurface()
                        }
                    }
                    if !services.contains(where: { $0.kind == "容器" }) {
                        Text("未读取到 Docker 容器，可在设备页面重新发现服务。").font(TVType.body).foregroundStyle(.secondary)
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, horizontalInset)
                .padding(.top, TVLayout.pageTop)
                .padding(.bottom, 40)
            }
            .accessibilityIdentifier("tv.services.visibility.page")
        }
        .tvPageTheme()
    }
}
struct TVServiceDetailView: View {
    let service: TVDiscoveredService
    let client: TVDSMClient
    @State private var endpoint: URL?
    var body: some View {
        GeometryReader { viewport in
            // Take the width outside the scroll content, where it is bounded.
            let horizontalInset: CGFloat = 70
            let contentWidth = max(0, viewport.size.width - 2 * horizontalInset)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    TVPageHeading(title: service.name, subtitle: service.kind + " · " + (service.running.map { $0 ? "运行中" : "已停止" } ?? "状态未知"))
                    ForEach(service.managementEndpoints, id: \.self) { url in
                        Button { endpoint = url } label: {
                            TVFeatureTile(title: "在手机上管理", subtitle: url.host ?? "服务管理地址", symbol: "qrcode")
                        }.buttonStyle(TVTileStyle())
                            .frame(width: contentWidth, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 22) {
                        Text("当前服务").font(TVType.section)
                        Text(service.detail.isEmpty ? service.name : service.detail).font(TVType.body)
                        Text("公布端口：" + (service.ports.isEmpty ? "无" : service.ports.map(String.init).joined(separator: "、"))).font(TVType.caption).foregroundStyle(.secondary)
                        Text(service.managementEndpoints.isEmpty ? "当前未提供管理地址，可查看运行状态、服务信息和公布端口。" : "用手机扫码打开当前 NAS 提供的管理地址，访问范围取决于设备所在网络。")
                            .font(TVType.caption).foregroundStyle(.secondary)
                    }
                    .padding(30)
                    .frame(width: contentWidth, alignment: .leading)
                    .tvCardSurface(radius: TVLayout.radius)
                    .contentShape(Rectangle())
                    .focusable()
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("tv.service.info")
                }.frame(width: contentWidth, alignment: .leading)
                    .padding(.horizontal, horizontalInset)
                    .padding(.top, TVLayout.pageTop)
                    .padding(.bottom, 40)
            }
            .accessibilityIdentifier("tv.service.detail")
        }.tvPageTheme()
        .sheet(isPresented: Binding(get: { endpoint != nil }, set: { if !$0 { endpoint = nil } })) {
            if let endpoint { TVServiceQRView(url: endpoint) }
        }
    }
}
private struct TVServiceQRView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    private var code: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8); filter.correctionLevel = "M"
        guard let image = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
    var body: some View {
        VStack(spacing: 28) {
            Text("在手机上管理").font(TVType.title)
            if let code { Image(uiImage: code).interpolation(.none).resizable().scaledToFit().frame(width: 360, height: 360).padding(28).background(.white, in: RoundedRectangle(cornerRadius: 20)) }
            Text("使用手机相机扫描二维码，打开服务管理页。").font(TVType.body)
            Text(url.absoluteString).font(TVType.caption).foregroundStyle(.secondary)
        }.padding(70).frame(maxWidth: .infinity, maxHeight: .infinity).background(TVTheme.background)
            .focusable().onExitCommand { dismiss() }
    }
}

struct TVDeviceOverview: View {
    let client: TVDSMClient
    @State private var status = TVNASStatusSnapshot()
    @State private var loading = true
    @State private var error: String?
    @State private var reload = UUID()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack { TVPageHeading(title: "资源概览", subtitle: "设备状态 · 容量 · 诊断"); Spacer()
                    Button("刷新", systemImage: "arrow.clockwise") { reload = UUID() }.disabled(loading)
                }.focusSection()
                if loading { ProgressView("读取设备状态") }
                if let error { Text(error).foregroundStyle(.red) }
                Text("设备状态").font(TVType.section)
                TVInformationCard(rows: [("设备名称", status.name), ("型号", status.model), ("DSM 版本", status.version),
                    ("开机时长", status.uptimeText), ("连接模式", "DSM 直连"),
                    ("温度", status.temperature.map { String(format: "%.0f °C", $0) } ?? "未提供")])
                Text("资源与容量").font(TVType.section)
                TVInformationCard(rows: [("CPU", percent(status.cpu)), ("内存", percent(status.memory)), ("硬盘", percent(status.storage)),
                    ("已用 / 总容量", status.capacityText),
                    ("可用空间", status.storageTotal.flatMap { total in status.storageUsed.map { TVNASStatusSnapshot.bytes(max(0, total - $0)) } } ?? "未提供")])
                Text("诊断状态").font(TVType.section)
                TVInformationCard(rows: [("设备可达性", loading ? "检查中" : (status.reachable ? "当前请求成功" : "未确认")),
                    ("传输保护", client.server.scheme == "https" ? "HTTPS · 系统证书校验" : "HTTP · 未加密"),
                    ("NAS Agent", "未连接 · 当前使用 DSM 直连")])
                ForEach(status.warnings, id: \.self) { Text($0).font(TVType.caption).foregroundStyle(.secondary) }
            }.tvPageInsets()
        }.font(TVType.body).tvPageTheme().tvInformationLayout().tvNavigationBack()
        .task(id: reload) {
            loading = true; error = nil
            defer { loading = false }
            do { status = try await client.statusSnapshot() }
            catch { if !Task.isCancelled { status.reachable = false; self.error = nasError(error) } }
        }
    }
    private func percent(_ value: Double?) -> String { value.map { String(format: "%.0f%%", min(100, max(0, $0))) } ?? "未提供" }
}

struct TVInformationCard: View {
    let rows: [(String, String)]
    @AppStorage("appearance.launchpadTheme") private var theme = "cleanGrid"
    private var compact: Bool { theme == "commandCenter" }
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 20) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider() }
                HStack(alignment: .top, spacing: 28) {
                    Text(row.0).font(TVType.body).foregroundStyle(.secondary).frame(width: compact ? 220 : 260, alignment: .leading)
                    Text(row.1).font(TVType.body).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                }
            }
        }.padding(compact ? 24 : 30).monospacedDigit().frame(maxWidth: .infinity, alignment: .leading)
            .tvCardSurface(radius: TVLayout.radius).focusable()
    }
}

private enum TVDeviceFeature: String, CaseIterable, Identifiable {
    case overview, services, containers, packages, files, network, security, rediscover, agent
    var id: String { rawValue }
    var isMaintenance: Bool { [.security, .rediscover, .agent].contains(self) }
    var title: String {
        switch self {
        case .overview: return "资源概览"
        case .services: return "服务资源"
        case .containers: return "容器"
        case .packages: return "套件"
        case .files: return "文件"
        case .network: return "网络"
        case .security: return "证书与安全"
        case .rediscover: return "重新发现服务"
        case .agent: return "Nastart Agent"
        }
    }
    var subtitle: String {
        switch self {
        case .overview: return "状态 · 容量 · 诊断"
        case .services: return "Docker 与套件服务汇总"
        case .containers: return "Docker 服务与运行状态"
        case .packages: return "已安装的 NAS 套件"
        case .files: return "共享目录 · 视频与音乐"
        case .network: return "连接 · 接口 · 服务地址"
        case .security: return "连接保护 · NAS 证书"
        case .rediscover: return "重新读取服务清单"
        case .agent: return "发现线索与接入状态"
        }
    }
    var symbol: String {
        switch self {
        case .overview: return "chart.line.uptrend.xyaxis"
        case .services: return "chart.bar.xaxis"
        case .containers: return "shippingbox"
        case .packages: return "square.stack.3d.up"
        case .files: return "folder"
        case .network: return "network"
        case .security: return "lock.shield"
        case .rediscover: return "magnifyingglass"
        case .agent: return "antenna.radiowaves.left.and.right"
        }
    }
}

struct TVDevicesView: View {
    let client: TVDSMClient?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: "设备", subtitle: "设备资源与维护")
                if client == nil { TVNASConnectionBanner() }
                Text("资源").font(TVType.section)
                features(maintenance: false)
                Text("维护").font(TVType.section)
                features(maintenance: true)
            }.tvPageInsets()
        }.tvPageTheme().tvInformationLayout()
    }
    private func features(maintenance: Bool) -> some View {
        TVFixedFeatureGrid(columns: 3) {
            ForEach(TVDeviceFeature.allCases.filter { $0.isMaintenance == maintenance }) { feature in
                NavigationLink { destination(feature) } label: {
                    TVFeatureTile(title: feature.title, subtitle: feature.subtitle, symbol: feature.symbol)
                }.accessibilityIdentifier("tv.device." + feature.id)
            }
        }
    }
    @ViewBuilder private func destination(_ feature: TVDeviceFeature) -> some View {
        if let client {
            switch feature {
            case .overview: TVDeviceOverview(client: client)
            case .services: TVServiceDirectory(client: client, kind: nil, title: "服务资源")
            case .containers: TVServiceDirectory(client: client, kind: "容器", title: "Docker 容器")
            case .packages: TVServiceDirectory(client: client, kind: "套件", title: "套件服务")
            case .files: TVNASFiles(client: client, path: "/", title: "设备文件")
            case .network: TVConnectionInfo(client: client)
            case .security: TVCertificateSecurity(client: client)
            case .rediscover: TVServiceDirectory(client: client, kind: nil, title: "重新发现服务")
            case .agent: TVAgentStatusView(client: client)
            }
        } else { TVDeviceConnectionPrompt(feature: feature) }
    }
}

private struct TVDeviceConnectionPrompt: View {
    let feature: TVDeviceFeature
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: feature.title, subtitle: feature.subtitle)
                TVNASConnectionBanner()
                Text("继续使用").font(TVType.section)
                TVFixedFeatureGrid(columns: 2) {
                    NavigationLink { TVStorageEntry() } label: {
                        TVFeatureTile(title: "存储与媒体", subtitle: "访问已添加的网络媒体库", symbol: "externaldrive.badge.wifi")
                    }
                    NavigationLink { TVConnectionsView() } label: {
                        TVFeatureTile(title: "连接管理", subtitle: "管理设备与影音授权", symbol: "externaldrive.badge.person.crop")
                    }
                }
            }.tvPageInsets()
        }.tvPageTheme().tvNavigationBack()
    }
}

struct TVServiceDirectory: View {
    let client: TVDSMClient
    let kind: String?
    let title: String
    @State private var discovery = TVServiceDiscovery()
    @State private var loading = true
    @State private var error: String?
    @State private var refresh = UUID()
    @State private var search = ""
    @State private var selectedKind = ""
    private var availableServices: [TVDiscoveredService] {
        let filter = kind ?? selectedKind
        return discovery.services.filter { filter.isEmpty || $0.kind == filter }
    }
    private var matchingServices: [TVDiscoveredService] { availableServices.filter { $0.matches(search) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    TVPageHeading(title: title, subtitle: "来自当前 NAS 的只读状态")
                    Spacer(); Button("刷新") { refresh = UUID() }.disabled(loading)
                }.focusSection()
                if kind == nil {
                    HStack(spacing: TVLayout.gap) {
                        ForEach([("", "全部"), ("容器", "Docker"), ("套件", "套件")], id: \.0) { value, title in
                            Button { selectedKind = value } label: {
                                Text(title).font(TVType.body).foregroundStyle(selectedKind == value ? TVTheme.accent : .primary)
                                    .frame(maxWidth: .infinity).padding(18)
                            }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.services.kind." + (value.isEmpty ? "all" : value == "容器" ? "docker" : "packages"))
                        }
                    }
                }
                HStack(spacing: 24) {
                    TextField("筛选服务名称、镜像或类型", text: $search).accessibilityIdentifier("tv.services.filter")
                    if !search.isEmpty {
                        Button("清除筛选") { search = "" }.accessibilityIdentifier("tv.services.clear")
                    }
                    Text("\(matchingServices.count) / \(availableServices.count) 项")
                        .font(TVType.caption).monospacedDigit().foregroundStyle(.secondary)
                        .accessibilityIdentifier("tv.services.count")
                }
                if loading { ProgressView("正在读取服务") }
                if let error { Text(error).foregroundStyle(.red) }
                ForEach(discovery.warnings, id: \.self) { Text($0).font(TVType.caption).foregroundStyle(.secondary) }
                ForEach(TVServiceCategory.allCases) { category in
                    let rows = matchingServices.filter { $0.category == category }
                    if !rows.isEmpty { TVServiceGroup(category: category, services: rows, client: client, showDetails: true) }
                }
                if !loading && error == nil && matchingServices.isEmpty {
                    Text(availableServices.isEmpty ? "当前账号没有可见项目。" : "没有匹配的服务，可清除筛选查看全部项目。")
                        .foregroundStyle(.secondary).accessibilityIdentifier("tv.services.noMatches")
                }
            }.tvPageInsets()
        }.tvPageTheme().tvInformationLayout().tvNavigationBack()
            .task(id: refresh) {
                loading = true; error = nil
                defer { loading = false }
                do { discovery = try await client.discoverServices() }
                catch { if !Task.isCancelled { self.error = nasError(error) } }
            }
    }
}
struct TVConnectionInfo: View {
    let client: TVDSMClient
    @State private var inventory: TVServiceDiscovery?
    @State private var interfaces: [[String: String]] = []
    @State private var networkError: String?
    @State private var inventoryError: String?
    @State private var loading = true
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TVPageHeading(title: "网络信息", subtitle: "此电视的连接配置与 NAS 返回的信息")
                TVInformationCard(rows: [("会话配置地址", tvDisplayAddress(client.server)), ("协议", client.server.scheme?.uppercased() ?? "未提供"),
                    ("端口", String(client.server.port ?? (client.server.scheme == "https" ? 443 : 80))),
                    ("账号", client.account?.user ?? "未登录"), ("连接通道", "DSM API 直连"), ("Agent 通道", "尚未接通")])
                if loading { ProgressView("正在读取网络和服务信息") }
                if let networkError { Text(networkError).font(TVType.caption).foregroundStyle(.secondary) }
                ForEach(Array(interfaces.enumerated()), id: \.offset) { _, fields in
                    TVInformationCard(rows: ["接口", "地址", "子网掩码", "网关", "MAC", "MTU", "速率", "状态"].compactMap { key in fields[key].map { (key, $0) } })
                }
                if let inventory {
                    Text("服务与地址").font(TVType.section)
                    TVInformationCard(rows: [("已发现项目", String(inventory.services.count)),
                        ("提供管理地址", String(inventory.services.filter { !$0.managementEndpoints.isEmpty }.count)),
                        ("已核对 Jellyfin 身份", String(inventory.services.filter { $0.verifiedJellyfin != nil }.count))])
                    ForEach(inventory.services.filter { !$0.managementEndpoints.isEmpty || $0.verifiedJellyfin != nil }) { service in
                        TVInformationCard(rows: [("服务", service.name)] + Array(Set(service.managementEndpoints + [service.verifiedJellyfin].compactMap { $0 })).sorted { $0.absoluteString < $1.absoluteString }.map { ("地址线索", tvDisplayAddress($0)) })
                    }
                    Text("地址线索不代表已登录或可从外网访问；此页不会修改 NAS 的网络配置。").font(TVType.caption).foregroundStyle(.secondary)
                }
                if let inventoryError { Text(inventoryError).font(TVType.caption).foregroundStyle(.secondary) }
            }.tvPageInsets()
        }.tvPageTheme().tvInformationLayout().tvNavigationBack().accessibilityIdentifier("tv.network.info")
        .task {
            defer { loading = false }
            do {
                let reply = try await client.readDiscovered("SYNO.Core.Network.Interface", method: "list")
                try Task.checkCancellation()
                interfaces = (TVDSMClient.serviceRows(reply, keys: ["ifaces", "interfaces", "items", "list"]) ?? []).map { row in
                    let fields = [("接口", ["id", "name", "ifname"]), ("地址", ["ip", "ipaddr", "address"]), ("子网掩码", ["netmask", "mask"]),
                        ("网关", ["gateway"]), ("MAC", ["mac", "macaddr"]), ("MTU", ["mtu"]), ("速率", ["speed"]), ("状态", ["status", "link_status"])]
                    return Dictionary(uniqueKeysWithValues: fields.compactMap { label, keys in TVDSMClient.string(row, keys).map { (label, $0) } })
                }.filter { !$0.isEmpty }
                if interfaces.isEmpty { networkError = "DSM 未返回可展示的接口信息。" }
            } catch { if !Task.isCancelled { networkError = "网络接口信息未能读取：" + nasError(error) } }
            guard !Task.isCancelled else { return }
            do { let result = try await client.discoverServices(); try Task.checkCancellation(); inventory = result }
            catch { if !Task.isCancelled { inventoryError = "服务信息未能读取：" + nasError(error) } }
        }
    }
}
private func tvDisplayAddress(_ url: URL) -> String {
    NetworkConnectionAddress.displayText(for: url) ?? "未提供"
}
struct TVAgentStatusView: View {
    let client: TVDSMClient
    @State private var matches: [TVDiscoveredService] = []
    @State private var loading = true
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TVPageHeading(title: "Nastart Agent", subtitle: "设备能力与接入状态")
                TVInformationCard(rows: [("此电视当前通道", "DSM API 直连"), ("Agent 授权通道", "尚未接通"),
                    ("发现状态", loading ? "读取中" : (matches.isEmpty ? "未发现服务线索" : "发现服务线索"))])
                ForEach(matches) { service in TVInformationCard(rows: [("服务", service.name), ("运行状态", service.running.map { $0 ? "运行中" : "已停止" } ?? "未提供"), ("信息", service.detail)]) }
                if let error { Text(error).font(TVType.caption).foregroundStyle(.secondary) }
                Text("Agent 可为客户端补充设备能力。电视端尚未建立 Agent 授权通道，发现容器不代表已连接；现有设备和文件功能继续通过 DSM 读取。未发现也不能证明 NAS 没有安装。").font(TVType.body).foregroundStyle(.secondary)
            }.tvPageInsets()
        }.tvPageTheme().tvInformationLayout().tvNavigationBack().accessibilityIdentifier("tv.agent.status")
        .task {
            defer { loading = false }
            do { let result = try await client.discoverServices(); try Task.checkCancellation(); matches = result.services.filter { ($0.name + $0.detail).lowercased().filter { $0.isLetter || $0.isNumber }.contains("nastartagent") } }
            catch { if !Task.isCancelled { self.error = nasError(error) } }
        }
    }
}
struct TVPlayerSettingsView: View {
    @EnvironmentObject private var state: TVAppState
    @State private var services: [TVDiscoveredService] = []
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TVPageHeading(title: "播放器", subtitle: "默认行为与服务集成")
                NastartSettingsText(key: "mine.players.defaults", fallback: "默认方式").font(TVType.section)
                VStack(alignment: .leading, spacing: 20) { NastartPlayerDefaultsRows() }
                    .padding(30).frame(maxWidth: .infinity, alignment: .leading)
                    .tvCardSurface(radius: TVLayout.radius).focusable()
                Text("已安装的外部播放器").font(TVType.section)
                TVInformationCard(rows: [("外部打开", "电视端暂未提供外部播放器发现与跳转")])
                Text("服务集成").font(TVType.section)
                VStack(alignment: .leading, spacing: 16) {
                    NastartPlayerIntegrationRows { product in
                        let found = services.contains { ($0.name + " " + $0.detail).localizedCaseInsensitiveContains(product.title) }
                        return product == .jellyfin && state.account != nil ? .savedAuthorization : (found ? .discovered : .notObserved)
                    }
                }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
                    .tvCardSurface(radius: TVLayout.radius).focusable()
                NastartPlayerIntegrationNotice()
            }.tvPageInsets()
        }.tvPageTheme().tvInformationLayout().tvNavigationBack().accessibilityIdentifier("tv.player.settings")
        .task {
            guard let account = state.nasAccount else { return }
            if let result = try? await TVDSMClient(account: account).discoverServices(), !Task.isCancelled { services = result.services }
        }
    }
}
struct TVPlusView: View {
    var body: some View {
        ScrollView {
            NastartPlusOverview(membership: .unavailable,
                surface: AnyView(Color.clear.tvCardSurface(radius: TVLayout.radius)))
                .tvPageInsets()
        }.tvPageTheme().tvInformationLayout().tvNavigationBack().accessibilityIdentifier("tv.plus.info")
    }
}


struct TVPrivacySecurity: View {
    @EnvironmentObject private var state: TVAppState
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVPageHeading(title: "隐私与安全", subtitle: "此电视的访问授权与数据保存")
                Text("凭据与连接").font(TVType.section)
                TVInformationCard(rows: [("NAS 登录配置", state.nasAccount == nil ? "未配置" : "已配置"),
                    ("影音授权配置", state.account == nil ? "未配置" : "已配置"),
                    ("NAS 协议配置", state.nasAccount.map { $0.server.scheme == "https" ? "HTTPS" : "HTTP · 未加密" } ?? "未配置")])
                NavigationLink { TVConnectionsView() } label: { TVFeatureTile(title: "连接管理", subtitle: "查看或移除此电视的授权", symbol: "key") }.buttonStyle(TVTileStyle())
                NastartSettingsText(key: "privacy.summary.title", fallback: "数据保存").font(TVType.section)
                VStack(alignment: .leading, spacing: 16) { NastartPrivacyDataRows() }
                    .padding(30).tvCardSurface(radius: TVLayout.radius).focusable()
            }.tvPageInsets()
        }.tvPageTheme().tvNavigationBack()
    }
}

struct TVCertificateSecurity: View {
    let client: TVDSMClient
    @State private var certificates: [[String: String]] = []
    @State private var error: String?
    @State private var loading = true
    @State private var reload = UUID()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack { TVPageHeading(title: "证书安全", subtitle: "当前连接保护与 NAS 证书清单"); Spacer()
                    Button("检查证书", systemImage: "arrow.clockwise") { reload = UUID() }.disabled(loading)
                }
                TVInformationCard(rows: [("协议", client.server.scheme?.uppercased() ?? "未知"),
                    ("系统校验", client.server.scheme == "https" ? "使用系统 TLS 信任校验" : "当前为 HTTP，不提供 TLS 保护"),
                    ("自定义证书信任", "未配置")])
                Text("NAS 管理证书").font(TVType.section)
                Text("此清单由 DSM 提供；不据此推断当前连接使用了哪张证书。").font(TVType.caption).foregroundStyle(.secondary)
                if loading { ProgressView("正在读取证书") }
                if let error { Text(error).font(TVType.body).foregroundStyle(.secondary) }
                ForEach(Array(certificates.enumerated()), id: \.offset) { _, cert in
                    TVInformationCard(rows: [("证书", cert["name"] ?? "未提供"), ("签发者", cert["issuer"] ?? "未提供"), ("有效期至", cert["until"] ?? "未提供")])
                }
                if !loading && error == nil && certificates.isEmpty { Text("DSM 未返回证书条目。").font(TVType.body) }
            }.tvPageInsets()
        }.tvPageTheme().tvNavigationBack()
        .task(id: reload) {
            loading = true; error = nil
            defer { loading = false }
            do {
                let data = try await client.readDiscovered("SYNO.Core.Certificate.CRT", method: "list"); try Task.checkCancellation()
                let rows = (data["certificates"] ?? data["items"]) as? [[String: Any]] ?? []
                certificates = rows.map { row in
                    func text(_ keys: [String]) -> String {
                        for key in keys {
                            if let value = row[key] as? String, !value.isEmpty { return value }
                            if let date = row[key] as? NSNumber { return Date(timeIntervalSince1970: date.doubleValue).formatted(date: .abbreviated, time: .omitted) }
                        }
                        return "未提供"
                    }
                    return ["name": text(["desc", "subject", "common_name"]), "issuer": text(["issuer", "issuer_name"]), "until": text(["valid_till", "valid_until", "not_after"])]
                }
            } catch { if !Task.isCancelled { self.error = nasError(error) } }
        }
    }
}
