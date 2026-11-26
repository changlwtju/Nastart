import SwiftUI
import NetworkMedia

/// Shared film-detail vocabulary; device layouts keep their own input model.
enum MediaDetailDesign {
    static func videoDescription(height: Int?, codec: String?, isHDR: Bool, fallback: String?) -> String? {
        var parts: [String] = []
        if let height {
            parts.append(height >= 2_000 ? "4K" : height >= 1_000 ? "1080p" : height >= 700 ? "720p" : "\(height)p")
        }
        if let codec = codec?.uppercased() {
            switch codec {
            case "HEVC", "H265": parts.append("H.265")
            case "H264", "AVC": parts.append("H.264")
            default: parts.append(codec)
            }
        }
        if isHDR { parts.append("HDR") }
        return parts.isEmpty ? fallback : parts.joined(separator: " · ")
    }
    static func audioDescription(codec: String?, channels: Int?, fallback: String?) -> String? {
        var parts: [String] = []
        if let codec = codec?.uppercased() { parts.append(codec == "EAC3" ? "E-AC3" : codec) }
        if let channels {
            switch channels {
            case 1: parts.append("Mono")
            case 2: parts.append("2.0")
            case 6: parts.append("5.1")
            case 8: parts.append("7.1")
            default: parts.append("\(channels) ch")
            }
        }
        return parts.isEmpty ? fallback : parts.joined(separator: " · ")
    }
    static let artworkRadius: CGFloat = 12
    static let sectionSpacing: CGFloat = 22
    static let scrim = [Color.black.opacity(0.08), .black.opacity(0.22), .black.opacity(0.94)]
}

struct NastartMediaFact: View {
    let value: String
    let symbol: String
    var accent: Color = .secondary
    var body: some View { MediaDetailFact(value: value, symbol: symbol, accent: accent) }
}

/// One ordered vocabulary for Mine/settings. Destinations retain platform APIs.
enum NastartSettingsDestination: String, CaseIterable, Identifiable {
    case plus, appearance, player, icloud, privacy, help
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .plus: return "mine.plus.title"
        case .appearance: return "mine.appearance.title"
        case .player: return "mine.players.title"
        case .icloud: return "mine.sync.title"
        case .privacy: return "mine.privacy.title"
        case .help: return "mine.about.title"
        }
    }
    var title: String {
        switch self {
        case .plus: return "Nastart Plus"
        case .appearance: return "外观"
        case .player: return "播放器"
        case .icloud: return "iCloud 同步"
        case .privacy: return "隐私与安全"
        case .help: return "帮助与关于"
        }
    }
    var symbol: String {
        switch self {
        case .plus: return "sparkles"
        case .appearance: return "paintpalette"
        case .player: return "play.rectangle"
        case .icloud: return "icloud"
        case .privacy: return "lock.shield"
        case .help: return "questionmark.circle"
        }
    }
    var televisionSubtitle: String {
        switch self {
        case .plus: return "会员与权益"
        case .appearance: return "主题与显示"
        case .player: return "音轨与字幕"
        case .icloud: return "范围与状态"
        case .privacy: return "凭据与连接"
        case .help: return "使用与说明"
        }
    }
}

/// Mobile retains its locale environment; TV retains its existing Chinese copy.
/// Full TV localization is a separate task, not implied by sharing this label.
struct NastartSettingsText: View {
    let key: String
    let fallback: String
    var body: some View {
        #if os(tvOS)
        Text(fallback)
        #else
        Text(LocalizedStringKey(key))
        #endif
    }
}

struct NastartSettingsItemLabel: View {
    let destination: NastartSettingsDestination
    var body: some View {
        #if os(tvOS)
        // Same badge-and-text rhythm as TVFeatureTile, so settings tiles match the other TV cards.
        HStack(spacing: 22) {
            TVIconBadge(symbol: destination.symbol).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                title.font(TVType.body.weight(.semibold)).lineLimit(1)
                Text(destination.televisionSubtitle).font(TVType.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).frame(height: TVLayout.cardHeight)
        #else
        HStack(spacing: 12) {
            symbol(size: 16, side: 28, radius: 8)
            title.foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 2)
        #endif
    }
    private var title: some View { NastartSettingsText(key: destination.titleKey, fallback: destination.title) }
    private func symbol(size: CGFloat, side: CGFloat, radius: CGFloat) -> some View {
        Image(systemName: destination.symbol).font(.system(size: size, weight: .medium))
            .foregroundStyle(AppTheme.accent).frame(width: side, height: side)
            .background(AppTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: radius))
            .accessibilityHidden(true)
    }
}

/// The host owns preferences; previews provide in-memory bindings only.
struct NastartLaunchpadCardRows: View {
    @Binding var compactMetrics: Bool
    @Binding var showServiceStatus: Bool
    @Binding var showCardSubtitle: Bool
    var identifierPrefix = "appearance.cards"
    var body: some View {
        Toggle(isOn: $compactMetrics) {
            option("mine.appearance.compact_metrics", "紧凑指标", "rectangle.compress.vertical")
        }.accessibilityIdentifier(identifierPrefix + ".compactMetrics")
        Toggle(isOn: $showServiceStatus) {
            option("mine.appearance.status_dot", "显示服务状态", "circle.circle")
        }.accessibilityIdentifier(identifierPrefix + ".showServiceStatus")
        Toggle(isOn: $showCardSubtitle) {
            option("mine.appearance.item.subtitle", "显示卡片副标题", "text.alignleft")
        }.accessibilityIdentifier(identifierPrefix + ".showCardSubtitle")
    }
    private func option(_ key: String, _ fallback: String, _ symbol: String) -> some View {
        NastartLaunchpadCardOptionLabel(key: key, fallback: fallback, symbol: symbol)
    }
}

private struct NastartLaunchpadCardOptionLabel: View {
    let key: String
    let fallback: String
    let symbol: String
    @Environment(\.isFocused) private var focused
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(iconColor)
                .frame(width: 28).accessibilityHidden(true)
            NastartSettingsText(key: key, fallback: fallback)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(textColor)
        }
    }
    private var iconColor: Color {
        #if os(tvOS)
        focused ? .black : AppTheme.accent
        #else
        AppTheme.accent
        #endif
    }
    private var textColor: Color {
        #if os(tvOS)
        focused ? .black : .primary
        #else
        .primary
        #endif
    }
}

/// Copy and layout only. Availability and all sync operations stay with the host.
enum NastartSyncScope: String, CaseIterable, Identifiable {
    case preferences, credentials, media
    var id: String { rawValue }
    var title: String {
        switch self {
        case .preferences: return "设置与事项"
        case .credentials: return "账号与授权"
        case .media: return "媒体资料与进度"
        }
    }
    var detail: String {
        switch self {
        case .preferences: return "在支持同步的设备上，可同步启动台卡片、服务显示、提醒、主题和布局。"
        case .credentials: return "密码、登录会话和访问令牌保存在本机，不参与 iCloud 同步。各设备仍需分别授权。"
        case .media: return "网络媒体库索引与海报保存在本机；Jellyfin 观看进度由对应的媒体服务器管理。"
        }
    }
    var symbol: String {
        switch self {
        case .preferences: return "slider.horizontal.3"
        case .credentials: return "key"
        case .media: return "play.rectangle"
        }
    }
}

struct NastartSyncScopeRow: View {
    let scope: NastartSyncScope
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                NastartSettingsText(key: "mine.sync.scope." + scope.id + ".title", fallback: scope.title)
            } icon: {
                Image(systemName: scope.symbol).foregroundStyle(AppTheme.accent).accessibilityHidden(true)
            }.font(titleFont)
            NastartSettingsText(key: "mine.sync.scope." + scope.id + ".detail", fallback: scope.detail)
                .font(bodyFont).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.sync.scope." + scope.id)
    }
    private var titleFont: Font {
        #if os(tvOS)
        TVType.body.weight(.semibold)
        #else
        .headline
        #endif
    }
    private var bodyFont: Font {
        #if os(tvOS)
        TVType.caption
        #else
        .body
        #endif
    }
}

enum NastartSyncUnavailableReason: Equatable {
    case installation, television
    var title: String { self == .television ? "此电视暂未提供 iCloud 同步" : "此版本暂不支持 iCloud 同步" }
    var detail: String {
        self == .television
            ? "此电视目前仅在本机保存设置和事项，不会自动同步手机或平板的内容。"
            : "本机内容会继续保留。请使用支持 iCloud 同步的 App 版本，再开启同步。"
    }
    var titleKey: String { self == .television ? "mine.sync.tv_unavailable" : "mine.sync.installation_unavailable" }
    var detailKey: String { self == .television ? "mine.sync.tv_unavailable_detail" : "mine.sync.error.missing_entitlement" }
}

struct NastartSyncUnavailableNotice: View {
    let reason: NastartSyncUnavailableReason
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                NastartSettingsText(key: reason.titleKey, fallback: reason.title)
            } icon: { Image(systemName: "icloud.slash").foregroundStyle(AppTheme.accent).accessibilityHidden(true) }
            .font(titleFont)
            NastartSettingsText(key: reason.detailKey, fallback: reason.detail)
                .font(bodyFont).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine).accessibilityIdentifier("settings.sync.unavailable")
    }
    private var titleFont: Font {
        #if os(tvOS)
        TVType.section
        #else
        .headline
        #endif
    }
    private var bodyFont: Font {
        #if os(tvOS)
        TVType.body
        #else
        .body
        #endif
    }
}

#if os(tvOS)
/// Shared presentation for the TV settings page and its offline preview.
struct NastartTVSyncOverview: View {
    let surface: AnyView
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Label("服务显示同步", systemImage: "icloud").font(TVType.section)
                Text("配置 iCloud 后可同步启动台的服务显示开关。电视的设置与事项保存在本机。")
                    .font(TVType.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(30)
            .background { surface }.clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .accessibilityElement(children: .combine).accessibilityIdentifier("settings.sync.services").focusable()
            NastartSettingsText(key: "mine.sync.scope.title", fallback: "同步范围与本机数据")
                .font(TVType.section).accessibilityAddTraits(.isHeader)
            if typeSize.isAccessibilitySize {
                VStack(spacing: 24) { scopeCards }
            } else {
                HStack(alignment: .top, spacing: 24) { scopeCards }
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var scopeCards: some View {
        ForEach(NastartSyncScope.allCases) { scope in
            NastartSyncScopeRow(scope: scope).padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background { surface }.clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)).focusable()
        }
    }
}
#endif

/// Presentation only: the owner supplies the current membership, never a receipt.
enum NastartPlusMembership: Equatable {
    case free, active, expired, unavailable
    var key: String {
        switch self {
        case .free: return "plus.status.free"
        case .active: return "plus.status.active"
        case .expired: return "plus.status.expired"
        case .unavailable: return "plus.overview.unavailable_status"
        }
    }
    var title: String {
        switch self {
        case .free: return "免费版"
        case .active: return "Plus 已开通"
        case .expired: return "Plus 已过期"
        case .unavailable: return "会员暂未开放"
        }
    }
}

/// The same read-only overview is mounted by both real Plus pages and previews.
/// Its surface is supplied by the host so it never owns a theme/account store.
struct NastartPlusOverview: View {
    let membership: NastartPlusMembership
    let surface: AnyView
    var showsMembership = true
    @Environment(\.dynamicTypeSize) private var typeSize
    private let features: [(key: String, title: String, symbol: String, detail: String)] = [
        ("cards", "更多启动台卡片", "square.grid.2x2", "按需安排常用服务"),
        ("icloud", "跨设备 iCloud 同步", "icloud", "同步已支持的设置与内容"),
        ("themes", "高级启动台主题", "paintpalette", "选择适合自己的界面风格"),
        ("reminders", "更多提醒与监测项", "bell.badge", "集中查看需要关注的事项")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsMembership {
            panel {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Nastart Plus", systemImage: "sparkles")
                        .font(titleFont).foregroundStyle(AppTheme.accent)
                    NastartSettingsText(key: "plus.overview.intro", fallback: "为常用的设备、服务与日常管理，留出更多可能。")
                        .font(bodyFont).fixedSize(horizontal: false, vertical: true)
                    Label {
                        NastartSettingsText(key: membership.key, fallback: membership.title)
                    } icon: {
                        Image(systemName: membership == .active ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(membership == .active ? Color.green : .secondary)
                    }.font(bodyFont).accessibilityIdentifier("plus.overview.status")
                }
            }
            if membership != .active { panel {
                VStack(alignment: .leading, spacing: 10) {
                    NastartSettingsText(key: "plus.overview.purchase_title", fallback: "购买暂未开放")
                        .font(sectionFont).accessibilityAddTraits(.isHeader)
                    NastartSettingsText(key: "plus.overview.purchase_detail", fallback: "当前版本尚未开放购买与恢复。正式价格和购买方式将在开放时展示。")
                        .font(bodyFont).fixedSize(horizontal: false, vertical: true)
                }.accessibilityIdentifier("plus.overview.availability")
            } }
            }
            featureSection
        }.frame(maxWidth: contentWidth, alignment: .leading).frame(maxWidth: .infinity)
    }
    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            NastartSettingsText(key: "plus.overview.features", fallback: "Plus 功能预览")
                .font(sectionFont).accessibilityAddTraits(.isHeader)
            if typeSize.isAccessibilitySize {
                ForEach(features, id: \.key) { feature in featurePanel(feature) }
            } else {
                ForEach(0..<2, id: \.self) { row in
                    HStack(alignment: .top, spacing: 12) {
                        featurePanel(features[row * 2])
                        featurePanel(features[row * 2 + 1])
                    }.fixedSize(horizontal: false, vertical: true)
                }
            }
            NastartSettingsText(key: "plus.overview.scope", fallback: "具体可用功能以当前设备为准，部分功能仍在完善中。")
                .font(captionFont).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: contentWidth, alignment: .leading).frame(maxWidth: .infinity)
    }
    private func featurePanel(_ feature: (key: String, title: String, symbol: String, detail: String)) -> some View {
        panel {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: feature.symbol).foregroundStyle(AppTheme.accent)
                    .font(sectionFont).accessibilityHidden(true)
                NastartSettingsText(key: "plus.feature." + feature.key, fallback: feature.title)
                    .font(sectionFont).fixedSize(horizontal: false, vertical: true)
                if feature.key == "icloud" {
                    #if os(tvOS)
                    NastartSettingsText(key: "plus.overview.tv_sync", fallback: "此电视暂未提供 iCloud 同步")
                        .font(bodyFont).fixedSize(horizontal: false, vertical: true)
                    #else
                    featureDetail(feature)
                    #endif
                } else { featureDetail(feature) }
                Spacer(minLength: 0)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func featureDetail(_ feature: (key: String, title: String, symbol: String, detail: String)) -> some View {
        NastartSettingsText(key: "plus.overview." + feature.key, fallback: feature.detail)
            .font(bodyFont).fixedSize(horizontal: false, vertical: true)
    }
    private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background { surface }.clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius).stroke(AppTheme.hairline, lineWidth: 1))
            #if os(tvOS)
            .focusable()
            #endif
    }
    private var contentWidth: CGFloat {
        #if os(tvOS)
        1100
        #else
        760
        #endif
    }
    private var titleFont: Font {
        #if os(tvOS)
        TVType.title
        #else
        .title2.weight(.bold)
        #endif
    }
    private var sectionFont: Font {
        #if os(tvOS)
        TVType.body.weight(.semibold)
        #else
        .subheadline.weight(.semibold)
        #endif
    }
    private var bodyFont: Font {
        #if os(tvOS)
        TVType.body
        #else
        .subheadline
        #endif
    }
    private var captionFont: Font {
        #if os(tvOS)
        TVType.caption
        #else
        .caption
        #endif
    }
}

/// Storage scope, not a query of saved accounts or cached media.
struct NastartPrivacyDataRows: View {
    private let rows: [(id: String, title: String, symbol: String, detail: String)] = [
        ("credentials", "登录凭据", "key", "保存在当前设备的系统钥匙串中"),
        ("local", "本机内容", "internaldrive", "媒体索引、设备文件进度、事项与外观保存在本机"),
        ("progress", "Jellyfin 观看进度", "play.rectangle", "由当前授权的 Jellyfin 服务器保存"),
        ("sync", "跨设备同步", "icloud", "以 iCloud 同步设置中支持的项目为准")
    ]
    var body: some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            #if os(tvOS)
            if index > 0 { Divider() }
            #endif
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: row.symbol).foregroundStyle(AppTheme.accent)
                    .frame(width: 26).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    NastartSettingsText(key: "privacy.summary." + row.id + ".title", fallback: row.title)
                        .font(labelFont)
                    if row.id == "sync" {
                        #if os(tvOS)
                        NastartSettingsText(key: "privacy.summary.tv_sync", fallback: "此电视暂未提供 iCloud 同步")
                        #else
                        detail(row)
                        #endif
                    } else { detail(row) }
                }.fixedSize(horizontal: false, vertical: true)
            }.font(bodyFont).foregroundStyle(.primary).padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
        }
    }
    private func detail(_ row: (id: String, title: String, symbol: String, detail: String)) -> some View {
        NastartSettingsText(key: "privacy.summary." + row.id + ".detail", fallback: row.detail)
    }
    private var labelFont: Font {
        #if os(tvOS)
        TVType.body.weight(.semibold)
        #else
        .subheadline.weight(.semibold)
        #endif
    }
    private var bodyFont: Font {
        #if os(tvOS)
        TVType.body
        #else
        .body
        #endif
    }
}

struct NastartPrivacyActionLabel: View {
    let key: String
    let symbol: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(AppTheme.accent)
                .frame(width: 26).accessibilityHidden(true)
            Text(LocalizedStringKey(key)).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if os(iOS)
/// Receives saved-state only; never opens Keychain or checks server reachability.
struct NastartSavedCredentialRow: View {
    let hasCredential: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { label; status }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    label
                    Spacer(minLength: 12)
                    status.fixedSize(horizontal: true, vertical: false)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("privacy.credentials.dsm.status")
    }
    private var label: some View {
        NastartPrivacyActionLabel(key: "mine.privacy.keychain.dsm", symbol: "key")
    }
    private var status: some View {
        Text(LocalizedStringKey(hasCredential ? "privacy.credentials.saved" : "privacy.credentials.unavailable"))
            .foregroundStyle(.secondary)
    }
}

/// Bindings stay with the owner; there is no export, sharing or persistence here.
struct NastartExportSelectionRows: View {
    @Binding var includeLaunchpad: Bool
    @Binding var includeReminders: Bool
    @Binding var includeSettings: Bool
    var body: some View {
        Toggle(isOn: $includeLaunchpad) {
            NastartPrivacyActionLabel(key: "mine.privacy.export.launchpad", symbol: "square.grid.2x2")
        }.accessibilityIdentifier("privacy.export.launchpad")
        Toggle(isOn: $includeReminders) {
            NastartPrivacyActionLabel(key: "mine.privacy.export.reminders", symbol: "bell")
        }.accessibilityIdentifier("privacy.export.reminders")
        Toggle(isOn: $includeSettings) {
            NastartPrivacyActionLabel(key: "mine.privacy.export.settings", symbol: "gearshape")
        }.accessibilityIdentifier("privacy.export.settings")
    }
}

/// Presentation only. The host supplies cleanup; previews only change a memory note.
struct NastartCacheClearPrompt: ViewModifier {
    @Binding var isPresented: Bool
    var note: LocalizedStringKey? = nil
    let onClear: () -> Void
    /// 点击取消按钮时调用（点空白处关闭不一定会调用）；正式页面不需要，离线预览用于计数。
    var onCancel: () -> Void = {}
    /// 与重置证书一致用居中 alert：单个破坏性操作，在各系统版本和 iPad 上位置一致，不会盖住页面标题。
    func body(content: Content) -> some View {
        content.alert("mine.privacy.clear_cache_confirm", isPresented: $isPresented) {
            Button("mine.privacy.clear_cache", role: .destructive, action: onClear)
            Button("action.cancel", role: .cancel, action: onCancel)
        } message: { message }
    }
    private var message: Text {
        if let note { return Text("privacy.cache.clear.detail") + Text("\n\n") + Text(note) }
        return Text("privacy.cache.clear.detail")
    }
}

/// The caller owns the action. Offline previews supply an in-memory no-op.
struct NastartCertificateResetPrompt: ViewModifier {
    @Binding var isPresented: Bool
    var note: LocalizedStringKey? = nil
    let onReset: () -> Void
    func body(content: Content) -> some View {
        content.alert("privacy.reset.title", isPresented: $isPresented) {
            Button("mine.privacy.reset_certificates", role: .destructive, action: onReset)
            Button("action.cancel", role: .cancel) {}
        } message: { message }
    }
    private var message: Text {
        if let note { return Text("privacy.reset.detail") + Text("\n\n") + Text(note) }
        return Text("privacy.reset.detail")
    }
}
#endif

/// Shared, read-only help content. No accounts, transport or persistence required.
enum NastartHelpTopic: String, CaseIterable, Identifiable {
    case connection, media, privacy, remote
    var id: String { rawValue }
    static var available: [Self] {
        #if os(tvOS)
        [.remote, .connection, .media, .privacy]
        #else
        [.connection, .media, .privacy]
        #endif
    }
    var title: String {
        switch self {
        case .connection: return "连接与媒体服务"
        case .media: return "浏览与播放"
        case .privacy: return "隐私与本机数据"
        case .remote: return "遥控器与 iPhone 输入"
        }
    }
    var subtitle: String {
        switch self {
        case .connection: return "DSM、Jellyfin 与媒体文件夹"
        case .media: return "海报、资料与播放控制"
        case .privacy: return "授权、索引与同步范围"
        case .remote: return "选择、返回与键盘协作"
        }
    }
    var symbol: String {
        switch self {
        case .connection: return "network"
        case .media: return "play.rectangle"
        case .privacy: return "lock.shield"
        case .remote: return "appletvremote.gen4"
        }
    }
    var sections: [NastartHelpSection] {
        switch self {
        case .connection: return [
            NastartHelpSection(id: "connection.nas", title: "设备与文件", detail: "连接 DSM 后，可以查看设备状态和共享文件。发现媒体服务后，仍需完成该服务自己的登录授权。"),
            NastartHelpSection(id: "connection.library", title: "媒体库与文件夹", detail: "Jellyfin 使用服务器已有的媒体库。WebDAV 在连接后选择媒体文件夹，也可以在连接管理中复用已有连接，添加其他文件夹。"),
            NastartHelpSection(id: "connection.edit", title: "修改连接或文件夹", detail: "在连接管理中编辑连接信息；更换媒体文件夹时，先验证并读取新目录，成功后再替换客户端索引。未完成验证或取消时保留原资料。")]
        case .media: return [
            NastartHelpSection(id: "media.posters", title: "海报与影片详情", detail: "在海报墙中浏览电影与剧集，进入详情可查看简介和演职人员。内容和图片以媒体库已有资料为准，部分影片可能暂时缺少封面或人物照片。"),
            NastartHelpSection(id: "media.files", title: "本地资料与只读整理", detail: "WebDAV 整理只读取所选目录中的文件、已有 NFO 与海报。索引保存在客户端，不改写 NAS 的文件、文件名或目录；尚未接入独立在线影片资料服务。"),
            NastartHelpSection(id: "media.controls", title: "播放控制", detail: "播放时可以暂停、继续和跳转进度。音轨、字幕及其他选项以片源和当前播放器实际提供的内容为准；首帧与跳转速度还受连接和文件格式影响。")]
        case .privacy: return [
            NastartHelpSection(id: "privacy.accounts", title: "账号与授权", detail: "登录凭据保存在当前设备的系统钥匙串中。DSM、Jellyfin 和 WebDAV 分别授权，识别到 NAS 不代表已经获得所有文件和媒体服务的访问权限。"),
            NastartHelpSection(id: "privacy.transport", title: "连接协议", detail: "WebDAV 可选择 HTTP 或 HTTPS。HTTP 不加密传输；服务支持时建议使用 HTTPS。具体连接地址和证书状态应以连接设置及实际服务为准。"),
            NastartHelpSection(id: "privacy.sync", title: "本机与跨设备", detail: "网络媒体库索引保存在客户端，Jellyfin 观看进度由服务器管理。iCloud 同步仅覆盖已接入的项目；Apple TV 当前未接入 iCloud 同步，不会自动复制手机或平板的账号与资料。")]
        case .remote: return [
            NastartHelpSection(id: "remote.navigation", title: "选择与返回", detail: "滑动遥控器移动焦点，按下确认。按返回键回到上一层。移动到顶部 Tab 即可切换页面，无需额外按下确认。"),
            NastartHelpSection(id: "remote.keyboard", title: "使用 iPhone 输入", detail: "选中输入框并进入 Apple TV 系统键盘后，可使用 iPhone 的 Apple TV 键盘通知输入。通知由系统提供，电视仍保留遥控器输入方式。")]
        }
    }
}
struct NastartHelpSection: Identifiable {
    let id: String
    let title: String
    let detail: String
}
struct NastartHelpTopicLabel: View {
    let topic: NastartHelpTopic
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: topic.symbol).foregroundStyle(AppTheme.accent)
                .frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                NastartSettingsText(key: "help." + topic.id + ".title", fallback: topic.title)
                    .font(titleFont).foregroundStyle(.primary)
                NastartSettingsText(key: "help." + topic.id + ".subtitle", fallback: topic.subtitle)
                    .font(subtitleFont).foregroundStyle(.secondary)
            }.fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
    }
    private var titleFont: Font {
        #if os(tvOS)
        TVType.body.weight(.semibold)
        #else
        .headline
        #endif
    }
    private var subtitleFont: Font {
        #if os(tvOS)
        TVType.caption
        #else
        .subheadline
        #endif
    }
}
/// Real mobile/TV help articles and offline scenes use this exact body.
struct NastartHelpSectionBody: View {
    let section: NastartHelpSection
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NastartSettingsText(key: "help." + section.id + ".title", fallback: section.title)
                .font(titleFont).accessibilityAddTraits(.isHeader)
            NastartSettingsText(key: "help." + section.id + ".body", fallback: section.detail)
                .font(bodyFont).foregroundStyle(.primary).lineSpacing(4)
        }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }
    private var titleFont: Font {
        #if os(tvOS)
        TVType.section
        #else
        .headline
        #endif
    }
    private var bodyFont: Font {
        #if os(tvOS)
        TVType.body
        #else
        .body
        #endif
    }

}

/// Presentation states describe inventory or a saved authorization, not a login probe.
enum NastartPlayerServiceState: String {
    case notObserved, discovered, savedAuthorization, online, installed, warning, stopped, unknown
    var title: String {
        switch self {
        case .notObserved: return "尚未确认"
        case .discovered: return "已发现服务线索"
        case .savedAuthorization: return "已保存独立授权"
        case .online: return "清单显示在线"
        case .installed: return "清单显示已安装"
        case .warning: return "清单状态异常"
        case .stopped: return "清单显示未运行"
        case .unknown: return "清单状态未知"
        }
    }
}

enum NastartPlayerIntegrations {
    static let products: [MediaServiceProduct] = [.jellyfin, .emby, .plex, .navidrome]
    static func symbol(for product: MediaServiceProduct) -> String {
        switch product {
        case .jellyfin: return "play.rectangle"
        case .emby: return "play.tv"
        case .plex: return "play.circle"
        case .navidrome: return "music.note.list"
        case .subsonic: return "music.note"
        case .audioStation: return "hifispeaker"
        }
    }
}

/// Hosts adapt their existing inventory. No credential reads or service discovery here.
struct NastartPlayerIntegrationRows: View {
    let state: (MediaServiceProduct) -> NastartPlayerServiceState
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ForEach(NastartPlayerIntegrations.products, id: \.self) { product in
            VStack(alignment: .leading, spacing: 8) {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) { label(product); status(product) }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        label(product)
                        Spacer(minLength: 8)
                        status(product).multilineTextAlignment(.trailing)
                    }
                }
                if product != .jellyfin {
                    NastartSettingsText(key: "mine.players.integration.native_pending", fallback: "原生媒体库尚未接入")
                        .font(captionFont).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("player.integration." + product.rawValue)
            #if os(tvOS)
            if product != NastartPlayerIntegrations.products.last { Divider() }
            #endif
        }
    }
    private func label(_ product: MediaServiceProduct) -> some View {
        HStack(spacing: 12) {
            Image(systemName: NastartPlayerIntegrations.symbol(for: product))
                .foregroundStyle(AppTheme.accent).frame(width: 28).accessibilityHidden(true)
            Text(product.title).fixedSize(horizontal: false, vertical: true)
        }
        #if os(tvOS)
        .font(TVType.body)
        #endif
    }
    private func status(_ product: MediaServiceProduct) -> some View {
        let value = state(product)
        return NastartSettingsText(key: "mine.players.integration." + value.rawValue, fallback: value.title)
            .font(captionFont).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    private var captionFont: Font {
        #if os(tvOS)
        TVType.caption
        #else
        .caption
        #endif
    }
}

struct NastartPlayerIntegrationNotice: View {
    var body: some View {
        NastartSettingsText(key: "mine.players.integration.notice",
            fallback: "服务清单与登录授权分别管理。清单或发现状态不代表已登录；各媒体服务需单独授权。")
            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            #if os(tvOS)
            .font(TVType.caption)
            #else
            .font(.footnote)
            #endif
    }
}

/// Used by the two real player settings pages and the isolated settings scene.
struct NastartPlayerDefaultsRows: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        row(key: "mine.players.video_engine", title: "视频播放引擎", symbol: "play.rectangle") {
            Text(PlaybackEngineAvailability.videoEngineSummary)
        }
        #if os(tvOS)
        Divider()
        #endif
        row(key: "mine.players.opening_mode", title: "默认打开方式", symbol: "arrow.up.forward.app") {
            NastartSettingsText(key: "mine.players.internal_first", fallback: "App 内优先")
        }
    }
    private func row<Value: View>(key: String, title: String, symbol: String,
                                  @ViewBuilder value: () -> Value) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    label(key: key, title: title, symbol: symbol)
                    value().foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    label(key: key, title: title, symbol: symbol)
                    Spacer(minLength: 4)
                    value().foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
        #if os(tvOS)
        .font(TVType.body)
        #endif
    }
    private func label(key: String, title: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(AppTheme.accent).accessibilityHidden(true)
            NastartSettingsText(key: key, fallback: title)
        }.fixedSize(horizontal: false, vertical: true)
    }
}

enum AppTheme {
    // Nastart's visual language: graphite surfaces, warm amber actions, and
    // restrained translucency. Keep the palette semantic so every feature
    // can share the same hierarchy in light and dark appearance.
    static let accent = Color(red: 0.96, green: 0.56, blue: 0.19)
    static let accentDeep = Color(red: 0.72, green: 0.31, blue: 0.08)
    static let softAccent = Color(red: 1.0, green: 0.94, blue: 0.86)
    static let primaryAction = Color(red: 0.13, green: 0.14, blue: 0.16)
    #if os(tvOS)
    private static func adaptiveSurface(light: Double, dark: Double) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(white: value, alpha: 1)
        })
    }
    static let background = adaptiveSurface(light: 0.96, dark: 0.075)
    static let groupedBackground = background
    static let secondarySurface = adaptiveSurface(light: 1, dark: 0.14)
    static let elevatedSurface = secondarySurface
    static let hairline = Color.primary.opacity(0.08)
    #else
    static let background = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let secondarySurface = Color(.secondarySystemGroupedBackground)
    static let elevatedSurface = Color(.secondarySystemBackground)
    static let hairline = Color(.separator).opacity(0.38)
    #endif
    static let cardCornerRadius: CGFloat = 22
    static let actionCornerRadius: CGFloat = 14
    static func glassColors(dark: Bool) -> [Color] {
        dark
            ? [Color(red: 0.13, green: 0.16, blue: 0.36), Color(red: 0.32, green: 0.15, blue: 0.24), Color(red: 0.07, green: 0.31, blue: 0.34)]
            : [Color(red: 0.90, green: 0.90, blue: 0.99), Color(red: 0.99, green: 0.86, blue: 0.80), Color(red: 0.78, green: 0.90, blue: 0.94)]
    }
    static let screenGradient = LinearGradient(
        colors: [
            groupedBackground,
            accent.opacity(0.035),
            groupedBackground
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// Shared by the mobile transport and the TV remote transport. Keep command
// values, symbols and button hierarchy together instead of copying defaults.
enum PlaybackControlDesign {
    static let seekStep = 15
    static let rates: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2]
    static let backwardSymbol = "gobackward.15"
    static let forwardSymbol = "goforward.15"
    static let restartSymbol = "arrow.counterclockwise"
}

struct NastartPlaybackButtonStyle: ButtonStyle {
    var chrome = false
    @Environment(\.isEnabled) private var enabled
    #if os(tvOS)
    @Environment(\.isFocused) private var focused
    #else
    private let focused = false
    #endif
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(focused ? Color.black : Color.white)
            .background(focused ? AppTheme.accent : (chrome ? Color.black.opacity(0.46) : .clear), in: Circle())
            .overlay(Circle().strokeBorder(focused ? AppTheme.accent : (chrome ? .white.opacity(0.24) : .clear), lineWidth: focused ? 3 : 1))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.35)
    }
}

/// Continue and Start Over are peer playback actions on every terminal.
struct NastartMediaActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MediaDetailActionStyle(accent: AppTheme.accent).makeBody(configuration: configuration)
    }
}

struct NastartPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(tvOS)
    @Environment(\.isFocused) private var focused
    #else
    private let focused = false
    #endif

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .modifier(NastartPrimaryButtonSize())
            .padding(.horizontal, 18)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.actionCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.actionCornerRadius, style: .continuous)
                    .stroke(focused ? AppTheme.accent : Color.primary.opacity(colorScheme == .dark ? 0.16 : 0), lineWidth: focused ? 3 : 1)
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }

    private var foregroundColor: Color {
        guard isEnabled else { return Color(.secondaryLabel) }
        return focused || colorScheme == .dark ? .black : .white
    }

    private var backgroundColor: Color {
        guard isEnabled else {
            #if os(tvOS)
            return Color.gray.opacity(0.3)
            #else
            return Color(.systemGray4)
            #endif
        }
        return focused ? AppTheme.accent : (colorScheme == .dark ? .white : AppTheme.primaryAction)
    }
}

private struct NastartPrimaryButtonSize: ViewModifier {
    func body(content: Content) -> some View {
        #if os(tvOS)
        content.frame(minWidth: 220, minHeight: 56)
        #else
        content.frame(maxWidth: .infinity, minHeight: 50)
        #endif
    }
}

struct NastartSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(tvOS)
    @Environment(\.isFocused) private var focused
    #else
    private let focused = false
    #endif

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(focused && isEnabled ? Color.black : (isEnabled ? AppTheme.accent : .secondary))
            .frame(minHeight: 42)
            .padding(.horizontal, 14)
            .background(focused && isEnabled ? AppTheme.accent : AppTheme.accent.opacity(isEnabled ? 0.10 : 0.05))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.accent.opacity(focused ? 1 : (isEnabled ? 0.28 : 0.12)), lineWidth: focused ? 3 : 1)
            }
            .opacity(configuration.isPressed && !reduceMotion ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
    }
}

struct NastartStatusChip: View {
    let titleKey: LocalizedStringKey
    let symbol: String
    let color: Color

    var body: some View {
        Label(titleKey, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.11))
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(color.opacity(0.20), lineWidth: 1)
            }
    }
}

#if !os(tvOS)

extension View {
    func nastartCard(cornerRadius: CGFloat = 22, elevated: Bool = false) -> some View {
        self
            .modifier(NastartCardSurface())
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
    }

    func nastartScreenBackground() -> some View {
        background(AppTheme.screenGradient.ignoresSafeArea())
    }

    func nastartSectionTitle() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.7)
    }
}

// One theme canvas for root pages and destinations, including modal forms.
struct NastartThemeBackground: View {
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var entitlement: EntitlementStore
    @Environment(\.colorScheme) private var scheme
    private var theme: LaunchpadTheme {
        entitlement.canUse(.advancedThemes) ? appearance.launchpadTheme : .cleanGrid
    }
    var body: some View {
        ZStack {
            AppTheme.groupedBackground
            if theme == .glassDeck {
                LinearGradient(colors: AppTheme.glassColors(dark: scheme == .dark),
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else if theme == .commandCenter {
                LinearGradient(colors: [AppTheme.groupedBackground, AppTheme.accent.opacity(scheme == .dark ? 0.10 : 0.05)], startPoint: .top, endPoint: .bottom)
            }
        }.ignoresSafeArea()
    }
}

private struct NastartPageTheme: ViewModifier {
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var entitlement: EntitlementStore
    @ViewBuilder func body(content: Content) -> some View {
        if appearance.launchpadTheme != .cleanGrid && entitlement.canUse(.advancedThemes) {
            content.scrollContentBackground(.hidden)
                .background { NastartThemeBackground() }
        } else { content }
    }
}

/// iPad 等宽屏上把列表和正文限制在约 720pt 的可读宽度并居中；滚动区域和背景仍铺满整屏，
/// 页边空白处也能滚动。iPhone（紧凑宽度）不变；iOS 16 没有 `contentMargins`，保持原样。
private struct NastartReadableWidth: ViewModifier {
    static let maxWidth: CGFloat = 720
    @Environment(\.horizontalSizeClass) private var widthClass
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 17.0, *), widthClass == .regular {
            GeometryReader { proxy in
                content.contentMargins(.horizontal, max(0, (proxy.size.width - Self.maxWidth) / 2), for: .scrollContent)
            }
        } else { content }
    }
}

extension View {
    func nastartReadableWidth() -> some View { modifier(NastartReadableWidth()) }
    func nastartPageTheme() -> some View { modifier(NastartPageTheme()) }
    func nastartSurface() -> some View { background { NastartSurfaceBackground() } }
    func nastartListSection() -> some View { modifier(NastartListSectionStyle()) }
}

/// Keep native controls and Dynamic Type sizing while giving information lists
/// the same compact status rail used by the command theme on the launchpad.
private struct NastartListSectionStyle: ViewModifier {
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var entitlement: EntitlementStore
    @ViewBuilder func body(content: Content) -> some View {
        if appearance.launchpadTheme == .commandCenter && entitlement.canUse(.advancedThemes) {
            content
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(
                    NastartSurfaceBackground().overlay(alignment: .leading) {
                        Rectangle().fill(AppTheme.accent.opacity(0.40)).frame(width: 2)
                    }
                )
                .listRowSeparatorTint(AppTheme.accent.opacity(0.18))
                .monospacedDigit()
        } else {
            content.listRowBackground(NastartSurfaceBackground())
        }
    }
}

/// The canvas supplies the color; surfaces only separate content from it.
/// System material is deliberately avoided here because its light-mode tint
/// turns large cards into opaque white islands, especially on iOS 16.
struct NastartSurfaceBackground: View {
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var entitlement: EntitlementStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder var body: some View {
        if appearance.launchpadTheme == .glassDeck && entitlement.canUse(.advancedThemes) {
            if reduceTransparency {
                scheme == .dark ? Color(red: 0.16, green: 0.20, blue: 0.30) : Color(red: 0.86, green: 0.88, blue: 0.95)
            } else {
                Color.white.opacity(scheme == .dark ? 0.07 : 0.18)
            }
        } else { AppTheme.secondarySurface }
    }
}

private struct NastartCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.nastartSurface()
    }
}

#endif

#if DEBUG
/// This root never constructs account, sync or discovery stores. The only appearance store it builds is the
/// settings-appearance scene's, bound to a temporary synthetic preferences suite with change notification
/// disabled (see `OfflineAppearanceHost`); it never reads or writes the user's standard defaults.
struct NastartOfflineUIRoot: View {
    let configuration: OfflineUIConfiguration
    private var dark: Bool { configuration.appearance == .dark }
    private var background: AnyView {
        switch configuration.theme {
        case .cleanGrid: return AnyView(AppTheme.background)
        case .commandCenter: return AnyView(AppTheme.screenGradient)
        case .glassDeck: return AnyView(LinearGradient(colors: AppTheme.glassColors(dark: dark),
            startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
    private var surface: AnyView {
        configuration.theme == .glassDeck
            ? AnyView(Color.white.opacity(dark ? 0.07 : 0.18))
            : AnyView(AppTheme.secondarySurface)
    }
    var body: some View {
        Group {
            #if os(iOS)
            if configuration.scenario == .themeGallery {
                NastartOfflineThemeGalleryScene(background: background, surface: surface)
            } else if configuration.scenario == .localLibrary {
                NastartOfflineLocalLibraryScene(configuration: configuration, background: background, surface: surface)
            } else if [.launchpadRoot, .devicesRoot, .tasksRoot].contains(configuration.scenario) {
                NastartOfflineRootScene(configuration: configuration)
            } else if [.mineInfo, .diagnostics].contains(configuration.scenario) {
                NastartOfflineMineComponentsScene(configuration: configuration, background: background, surface: surface)
            } else {
                existingScene
            }
            #else
            existingScene
            #endif
        }
        .preferredColorScheme(dark ? .dark : .light)
        .dynamicTypeSize(configuration.textSize == .large ? .accessibility2 : .large)
        .tint(AppTheme.accent)
    }
    @ViewBuilder private var existingScene: some View {
        if [.settings, .syncSettings, .privacy, .privacyReset, .privacyCache, .privacyExport, .playerSettings, .help, .helpDetail, .plus, .plusActive, .plusExpired, .plusFeatures].contains(configuration.scenario) {
            NastartOfflineSettingsScene(configuration: configuration, background: background, surface: surface)
        } else if [.connection, .connectionHTTP, .connectionEdit, .connectionError, .connectionBusy, .connectionActions].contains(configuration.scenario) {
            NavigationStack {
                OfflineWebDAVFormScene(configuration: configuration, appearance: NetworkMediaAppearance(
                    accent: AppTheme.accent, background: background, surface: surface,
                    commandStyle: configuration.theme == .commandCenter))
            }
        } else {
            OfflineMediaScene(configuration: configuration, appearance: NetworkMediaAppearance(
                accent: AppTheme.accent, background: background,
                surface: surface, commandStyle: configuration.theme == .commandCenter))
        }
    }
}
#if os(iOS)
/// 真实“存储与媒体”页，不带 NAS 上下文、服务或文件入口，因此不会恢复 NAS 会话或做局域网发现。
/// 测试者手动添加本机回环只读 WebDAV（如 http://127.0.0.1:8089）。媒体库与连接写入本安装的
/// 正式存储，仅在自建模拟器上使用。
private struct NastartOfflineLocalLibraryScene: View {
    let configuration: OfflineUIConfiguration
    let background: AnyView
    let surface: AnyView
    var body: some View {
        NavigationStack {
            networkMediaLibraryView(nas: nil, appearance: NetworkMediaAppearance(
                accent: AppTheme.accent, background: background, surface: surface,
                commandStyle: configuration.theme == .commandCenter))
        }
        .safeAreaInset(edge: .bottom) {
            Text("离线界面测试 · 仅连接手动添加的本机 WebDAV").font(.caption2).dynamicTypeSize(.large)
                .foregroundStyle(.secondary).padding(.vertical, 8)
                .frame(maxWidth: .infinity).background(.background)
                .accessibilityIdentifier("offline.local-library.banner")
        }
    }
}

/// 正式的启动台、设备、事项根页面，承载在隔离 store 上：示例数据、临时偏好域（含 `@AppStorage`），
/// 不读写钥匙串，不联网，不排通知，不写同步标记，也不读取本机保存的 NAS 快照。
@MainActor final class OfflineRootStoresHost: ObservableObject {
    static let suiteName = "nastart.offline-ui.roots"
    let suite: UserDefaults
    let dataStore: AppDataStore
    let connectionStore: NASConnectionStore
    let appearanceStore: AppearanceStore
    let entitlementStore = EntitlementStore()
    let mediaLibraryRouter = MediaLibraryRouter()

    /// `theme`/`dark` 来自 `--offline-ui-theme`/`--offline-ui-appearance`，只写进临时域。
    init(theme: LaunchpadTheme = .cleanGrid, dark: Bool = false) {
        UserDefaults.standard.removePersistentDomain(forName: Self.suiteName)
        guard let suite = UserDefaults(suiteName: Self.suiteName) else {
            preconditionFailure("离线界面测试：无法创建临时偏好域")
        }
        suite.set(theme.rawValue, forKey: LaunchpadTheme.storageKey)
        suite.set((dark ? AppThemeMode.dark : .light).rawValue, forKey: AppThemeMode.storageKey)
        self.suite = suite
        dataStore = AppDataStore.offlineFixture(defaults: suite)
        connectionStore = NASConnectionStore(offlineFixture: dataStore.device)
        appearanceStore = AppearanceStore(defaults: suite, noteChange: {})
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: Self.suiteName)
    }
}

private struct NastartOfflineRootScene: View {
    let scenario: OfflineUIConfiguration.Scenario
    @StateObject private var host: OfflineRootStoresHost
    init(configuration: OfflineUIConfiguration) {
        scenario = configuration.scenario
        _host = StateObject(wrappedValue: OfflineRootStoresHost(
            theme: LaunchpadTheme(rawValue: configuration.theme.rawValue) ?? .cleanGrid,
            dark: configuration.appearance == .dark))
    }
    var body: some View {
        Group {
            switch scenario {
            case .devicesRoot: DevicesView()
            case .tasksRoot: TasksView()
            default: LaunchpadView()
            }
        }
        .environmentObject(host.dataStore)
        .environmentObject(host.connectionStore)
        .environmentObject(host.entitlementStore)
        .environmentObject(host.appearanceStore)
        .environmentObject(host.mediaLibraryRouter)
        .defaultAppStorage(host.suite)
        .safeAreaInset(edge: .bottom) {
            Text("离线界面测试 · 示例数据，不联网、不保存").font(.caption2).dynamicTypeSize(.large)
                .foregroundStyle(.secondary).padding(.vertical, 8)
                .frame(maxWidth: .infinity).background(.background)
                .accessibilityIdentifier("offline.roots.banner")
        }
    }
}

/// 临时合成偏好域 + 绑定到它的 `AppearanceStore`。每次创建都先清空同名域（场景启动即为空），
/// 销毁时再清一次；变更通知为空，不写 iCloud 本地改动标记，也不读写标准偏好域。
final class OfflineAppearanceHost: ObservableObject {
    static let suiteName = "nastart.offline-ui.appearance"
    let suite: UserDefaults
    let store: AppearanceStore

    init() {
        UserDefaults.standard.removePersistentDomain(forName: Self.suiteName)
        guard let suite = UserDefaults(suiteName: Self.suiteName) else {
            preconditionFailure("离线界面测试：无法创建临时偏好域")
        }
        self.suite = suite
        self.store = AppearanceStore(defaults: suite, noteChange: {})
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: Self.suiteName)
    }
}

/// 读回临时偏好域的合成取值，并显示标准偏好域同名键（应始终不变）。只含布尔/枚举原始值。
private struct OfflineAppearanceReadback: View {
    @AppStorage private var language: String
    @AppStorage private var mode: String
    @AppStorage private var theme: String
    @AppStorage private var compact: Bool
    @AppStorage private var status: Bool
    @AppStorage private var subtitle: Bool

    init(suite: UserDefaults) {
        _language = AppStorage(wrappedValue: AppLanguage.system.rawValue, AppLanguage.storageKey, store: suite)
        _mode = AppStorage(wrappedValue: AppThemeMode.system.rawValue, AppThemeMode.storageKey, store: suite)
        _theme = AppStorage(wrappedValue: LaunchpadTheme.cleanGrid.rawValue, LaunchpadTheme.storageKey, store: suite)
        _compact = AppStorage(wrappedValue: true, AppearancePreferenceKeys.compactMetrics, store: suite)
        _status = AppStorage(wrappedValue: true, AppearancePreferenceKeys.showServiceStatus, store: suite)
        _subtitle = AppStorage(wrappedValue: false, AppearancePreferenceKeys.showCardSubtitle, store: suite)
    }

    private func onOff(_ value: Bool) -> String { value ? "开" : "关" }

    private var standardSubtitle: String {
        guard let value = UserDefaults.standard.object(forKey: AppearancePreferenceKeys.showCardSubtitle) as? Bool else {
            return "未设置"
        }
        return onOff(value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("临时域 · 语言 \(language) · 显示 \(mode) · 主题 \(theme)")
                .accessibilityIdentifier("offline.appearance.readback.choices")
            Text("临时域 · 紧凑指标 \(onOff(compact)) · 服务状态 \(onOff(status)) · 卡片副标题 \(onOff(subtitle))")
                .accessibilityIdentifier("offline.appearance.readback.toggles")
            Text("标准偏好域同名键（卡片副标题，应保持不变）：\(standardSubtitle)")
                .accessibilityIdentifier("offline.appearance.readback.standard")
        }.font(.caption).foregroundStyle(.secondary)
    }
}
#endif

/// Previews real settings labels and default rows, without instantiating the
/// account-backed Mine/TVSettings roots or their discovery/sync side effects.
private struct NastartOfflineSettingsScene: View {
    let configuration: OfflineUIConfiguration
    let background: AnyView
    let surface: AnyView
    @State private var showPrivacyReset = false
    @State private var showPrivacyCache = false
    @State private var privacyMessage: String?
    @State private var fixtureCompactMetrics = true
    @State private var fixtureShowServiceStatus = true
    @State private var fixtureShowCardSubtitle = false
    @State private var cacheClearRequests = 0
    @State private var cacheCancelRequests = 0
    #if os(iOS)
    @State private var fixtureHasCredential = true
    @StateObject private var appearanceHost = OfflineAppearanceHost()
    #endif
    var body: some View {
        NavigationStack {
            Group {
                if configuration.scenario == .privacyExport {
                    #if os(iOS)
                    exportSelectionPreview
                    #else
                    privacyPreview
                    #endif
                }
                else if [.privacy, .privacyReset, .privacyCache].contains(configuration.scenario) { privacyPreview }
                else if configuration.scenario == .syncSettings { syncPreview }
                else if configuration.scenario == .playerSettings { playerDefaults }
                else if configuration.scenario == .help { helpOverview }
                else if configuration.scenario == .helpDetail { helpArticle(.media) }
                else if [.plus, .plusActive, .plusExpired, .plusFeatures].contains(configuration.scenario) { plusPreview }
                else { settings }
            }
            #if os(iOS)
            .nastartReadableWidth()
            #endif
            .background { background.ignoresSafeArea() }
            .navigationTitle(previewTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }.tint(AppTheme.accent)
    }
    private var banner: some View {
        Text("离线界面测试 · 设置内容预览").font(.caption).foregroundStyle(.secondary)
            .accessibilityIdentifier("offline.settings.banner")
    }
    @ViewBuilder private var settings: some View {
        #if os(tvOS)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner
                Text("设置").font(TVType.section)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TVLayout.gap), count: 3), spacing: TVLayout.gap) {
                    links
                }.buttonStyle(NastartOfflineSettingsTileStyle(glass: configuration.theme == .glassDeck))
            }.padding(70)
        }
        #else
        List {
            Section { links } header: { Text("设置") } footer: { banner }
                .listRowBackground(surface)
        }.scrollContentBackground(.hidden)
        #endif
    }
    private var links: some View {
        ForEach(NastartSettingsDestination.allCases) { destination in
            NavigationLink {
                if destination == .player { playerDefaults.navigationTitle("播放器") }
                else if destination == .icloud { syncPreview.navigationTitle("iCloud 同步") }
                else if destination == .help { helpOverview.navigationTitle("帮助与关于") }
                else if destination == .plus { plusPreview.navigationTitle("Nastart Plus") }
                else if destination == .privacy { privacyPreview.navigationTitle("隐私与安全") }
                else if destination == .appearance { appearanceCardsPreview.navigationTitle("外观") }
                else {
                    VStack(alignment: .leading, spacing: 20) {
                        banner
                        NastartSettingsItemLabel(destination: destination)
                        Text("此场景仅预览设置入口，不打开账户、连接或系统设置。")
                            .foregroundStyle(.secondary)
                    }.padding(24).background { background.ignoresSafeArea() }
                }
            } label: { NastartSettingsItemLabel(destination: destination) }
                .accessibilityIdentifier("offline.settings." + destination.rawValue)
        }
    }
    @ViewBuilder private var appearanceCardsPreview: some View {
        #if os(tvOS)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner
                Text("启动台卡片").font(TVType.section)
                VStack(alignment: .leading, spacing: 20) { appearanceCardRows }
                    .font(TVType.body)
                Text("切换仅用于离线预览，不会保存外观偏好。")
                    .font(TVType.caption).foregroundStyle(.secondary)
            }.padding(70)
        }.background { background.ignoresSafeArea() }
        #elseif os(iOS)
        Form {
            Section {
                AppearanceModeRows()
                LaunchpadCardOptionRows()
            } header: {
                NastartSettingsText(key: "mine.appearance.launchpad", fallback: "启动台")
            } footer: {
                Text("离线界面测试 · 使用正式偏好绑定，只写入临时合成偏好域，不修改已保存的外观。")
            }.listRowBackground(surface)
            Section {
                OfflineAppearanceReadback(suite: appearanceHost.suite)
            } header: {
                Text("临时偏好域读回")
            }.listRowBackground(surface)
        }.scrollContentBackground(.hidden).background { background.ignoresSafeArea() }
            .environmentObject(appearanceHost.store)
            .defaultAppStorage(appearanceHost.suite)
        #endif
    }
    private var appearanceCardRows: some View {
        NastartLaunchpadCardRows(compactMetrics: $fixtureCompactMetrics,
            showServiceStatus: $fixtureShowServiceStatus, showCardSubtitle: $fixtureShowCardSubtitle)
    }
    private var previewTitle: Text {
        if configuration.scenario == .syncSettings {
            #if os(tvOS)
            return Text("iCloud 同步")
            #else
            return Text(LocalizedStringKey("mine.sync.title"))
            #endif
        }
        if configuration.scenario == .privacyExport {
            #if os(iOS)
            return Text(LocalizedStringKey("mine.privacy.export"))
            #else
            return Text("隐私与安全")
            #endif
        }
        if [.privacy, .privacyReset, .privacyCache].contains(configuration.scenario) {
            #if os(tvOS)
            return Text("隐私与安全")
            #else
            return Text(LocalizedStringKey("mine.privacy.title"))
            #endif
        }
        if [.plus, .plusActive, .plusExpired, .plusFeatures].contains(configuration.scenario) { return Text("Nastart Plus") }
        if configuration.scenario == .helpDetail {
            return helpTitle(.media)
        }
        if configuration.scenario == .help {
            #if os(tvOS)
            return Text("帮助与关于")
            #else
            return Text(LocalizedStringKey("mine.about.title"))
            #endif
        }
        return Text(configuration.scenario == .playerSettings ? "播放器" : "我的")
    }
    private var privacyMarker: some View {
        NastartSettingsText(key: "privacy.offline", fallback: "离线界面测试 · 数据保存说明")
            .font(.caption).dynamicTypeSize(.large).foregroundStyle(.secondary)
    }
    @ViewBuilder private var privacyPreview: some View {
        #if os(tvOS)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                privacyMarker
                NastartSettingsText(key: "privacy.summary.title", fallback: "数据保存").font(TVType.section)
                VStack(alignment: .leading, spacing: 16) { NastartPrivacyDataRows() }
                    .padding(30).background { surface.clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)) }
            }.padding(helpInsets)
        }.background { background.ignoresSafeArea() }
        #else
        Form {
            Section { privacyMarker }.listRowBackground(surface)
            Section { NastartPrivacyDataRows() } header: { Text("privacy.summary.title") }.listRowBackground(surface)
            Section {
                NavigationLink { credentialStatusPreview } label: {
                    NastartPrivacyActionLabel(key: "mine.privacy.keychain", symbol: "key")
                }.accessibilityIdentifier("offline.privacy.credentials")
                NavigationLink { exportSelectionPreview } label: {
                    NastartPrivacyActionLabel(key: "mine.privacy.export", symbol: "square.and.arrow.up")
                }.accessibilityIdentifier("offline.privacy.export")
                Button { showPrivacyReset = true } label: {
                    NastartPrivacyActionLabel(key: "mine.privacy.reset_certificates", symbol: "checkmark.shield")
                }.accessibilityIdentifier("offline.privacy.reset")
                if let privacyMessage { Text(privacyMessage) }
            } header: { Text("privacy.preview.actions") }.listRowBackground(surface)
            Section {
                Button { showPrivacyCache = true } label: {
                    NastartPrivacyActionLabel(key: "mine.privacy.clear_cache", symbol: "trash")
                }.accessibilityIdentifier("offline.privacy.clear-cache")
                Text("离线预览 · 确认清理 \(cacheClearRequests) 次 · 点击取消 \(cacheCancelRequests) 次")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("offline.privacy.cache-counters")
            } header: { Text("privacy.management.title") }
                footer: { Text("mine.privacy.cache.footer") }.listRowBackground(surface)
        }.scrollContentBackground(.hidden)
            .modifier(NastartCertificateResetPrompt(isPresented: $showPrivacyReset, note: "privacy.offline", onReset: {
                privacyMessage = "离线预览：未更改任何证书或账号。"
            }))
            .modifier(NastartCacheClearPrompt(isPresented: $showPrivacyCache, note: "privacy.offline", onClear: {
                cacheClearRequests += 1
                privacyMessage = String(localized: "privacy.cache.offline_result")
            }, onCancel: {
                cacheCancelRequests += 1
            }))
            .task {
                if configuration.scenario == .privacyReset { await Task.yield(); showPrivacyReset = true }
                else if configuration.scenario == .privacyCache { await Task.yield(); showPrivacyCache = true }
            }
        #endif
    }
    #if os(iOS)
    private var credentialStatusPreview: some View {
        Form {
            Section {
                privacyMarker
                Toggle("合成已保存凭据", isOn: $fixtureHasCredential)
            }.listRowBackground(surface)
            Section {
                Text("mine.privacy.keychain_desc").font(.subheadline).foregroundStyle(.secondary)
            }.listRowBackground(surface)
            Section { NastartSavedCredentialRow(hasCredential: fixtureHasCredential) }
                header: { Text("mine.privacy.keychain_items") }.listRowBackground(surface)
        }.scrollContentBackground(.hidden).background { background.ignoresSafeArea() }
            .navigationTitle("mine.privacy.keychain")
    }
    private var exportSelectionPreview: some View {
        NastartDataExportContent(isolatedStyle: .init(background: background, surface: surface), launchpad: {
            [.init(name: "合成媒体入口", category: .media, visible: true)]
        }, pending: {
            [TaskItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                      title: "合成提醒", subtitle: "合成目标", symbol: "bell",
                      isUrgent: false, createdAt: Date(timeIntervalSince1970: 0), daysBefore: 7)]
        }, history: { [] }, settings: {
            .init(theme: configuration.theme.rawValue, language: AppLanguage.system.rawValue,
                  displayMode: configuration.appearance.rawValue)
        })
        .safeAreaInset(edge: .top) { privacyMarker.padding(.horizontal) }
        .modifier(NastartOfflineShareProbeHost())
    }
    #endif
    private var plusPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NastartSettingsText(key: "plus.overview.offline", fallback: "离线界面测试 · 合成会员状态")
                    .font(.caption).dynamicTypeSize(.large).foregroundStyle(.secondary)
                if configuration.scenario == .plusFeatures {
                    NastartPlusOverview(membership: .free, surface: surface, showsMembership: false)
                } else {
                    NastartPlusOverview(membership: previewMembership, surface: surface)
                }
            }.padding(helpInsets)
        }.background { background.ignoresSafeArea() }
    }
    private var previewMembership: NastartPlusMembership {
        if configuration.scenario == .plusActive { return .active }
        if configuration.scenario == .plusExpired { return .expired }
        #if os(tvOS)
        return .unavailable
        #else
        return .free
        #endif
    }
    private func helpTitle(_ topic: NastartHelpTopic) -> Text {
        #if os(tvOS)
        Text(topic.title)
        #else
        Text(LocalizedStringKey("help." + topic.id + ".title"))
        #endif
    }
    private var helpMarker: some View {
        NastartSettingsText(key: "help.offline", fallback: "离线界面测试 · 帮助内容预览")
            .font(.caption).dynamicTypeSize(.large).foregroundStyle(.secondary)
    }
    private var helpOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                helpMarker
                ForEach(NastartHelpTopic.available) { topic in
                    NavigationLink { helpArticle(topic).navigationTitle(helpTitle(topic)) }
                        label: { NastartHelpTopicLabel(topic: topic).padding(18)
                            .background { surface.clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)) } }
                        #if os(tvOS)
                        .buttonStyle(NastartOfflineSettingsTileStyle(glass: configuration.theme == .glassDeck))
                        #else
                        .buttonStyle(.plain)
                        #endif
                        .accessibilityIdentifier("offline.help.topic." + topic.id)
                }
            }.padding(helpInsets)
        }
    }
    private func helpArticle(_ topic: NastartHelpTopic) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                helpMarker
                ForEach(topic.sections) { section in
                    NastartHelpSectionBody(section: section).padding(18)
                        .background { surface.clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)) }
                }
            }.padding(helpInsets)
        }.background { background.ignoresSafeArea() }
    }
    private var helpInsets: CGFloat {
        #if os(tvOS)
        70
        #else
        16
        #endif
    }
    @ViewBuilder private var syncPreview: some View {
        #if os(tvOS)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner
                NastartTVSyncOverview(surface: surface)
            }.padding(70)
        }
        #else
        Form {
            Section { NastartSyncUnavailableNotice(reason: .installation) }
                .listRowBackground(surface)
            Section {
                ForEach(NastartSyncScope.allCases) { scope in NastartSyncScopeRow(scope: scope) }
            } header: { Text("mine.sync.scope.title") }.listRowBackground(surface)
            Section { banner }.listRowBackground(surface)
        }.scrollContentBackground(.hidden)
        #endif
    }
    @ViewBuilder private var playerDefaults: some View {
        #if os(tvOS)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner
                NastartSettingsText(key: "mine.players.defaults", fallback: "默认方式").font(TVType.section)
                VStack(alignment: .leading, spacing: 20) { NastartPlayerDefaultsRows() }
                    .padding(30).background { surface.clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)) }
                    .focusable()
                NastartSettingsText(key: "mine.players.integrations", fallback: "服务集成").font(TVType.section)
                VStack(alignment: .leading, spacing: 16) { playerIntegrationFixtureRows }
                    .padding(30).background { surface.clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)) }
                    .focusable()
                NastartPlayerIntegrationNotice().focusable()
            }.padding(70)
        }
        #else
        Form {
            Section { NastartPlayerDefaultsRows() } header: {
                NastartSettingsText(key: "mine.players.defaults", fallback: "默认方式")
            } footer: {
                NastartSettingsText(key: "mine.players.behavior_footer", fallback: "")
            }.listRowBackground(surface)
            Section { playerIntegrationFixtureRows } header: {
                NastartSettingsText(key: "mine.players.integrations", fallback: "服务集成")
            } footer: { NastartPlayerIntegrationNotice() }.listRowBackground(surface)
            Section { banner }.listRowBackground(surface)
        }.scrollContentBackground(.hidden)
        #endif
    }
    private var playerIntegrationFixtureRows: some View {
        NastartPlayerIntegrationRows { product in
            switch product {
            case .jellyfin: return .savedAuthorization
            case .emby: return .notObserved
            case .plex: return .stopped
            case .navidrome: return .installed
            default: return .unknown
            }
        }
    }
}
#if os(tvOS)
/// A store-free preview adapter matching the real TV tile's surface/focus
/// hierarchy. Do not use a solid accent action style for a navigation tile.
private struct NastartOfflineSettingsTileStyle: ButtonStyle {
    let glass: Bool
    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(Color.primary)
            .background {
                if focused {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius).fill(TVTheme.surface)
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius).fill(AppTheme.accent.opacity(0.22)))
                } else if glass {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius).fill(.regularMaterial)
                } else { RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius).fill(TVTheme.surface) }
            }
            .overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .stroke(focused ? AppTheme.accent : AppTheme.hairline, lineWidth: focused ? 3 : 1))
            .scaleEffect(focused && !reduceMotion ? 1.025 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
#endif
#endif
