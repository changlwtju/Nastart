import SwiftUI
import NetworkMedia
import AVKit

enum TVTheme {
    private static func adaptive(_ light: (Double, Double, Double), _ dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }
    static let accent = AppTheme.accent
    static let background = adaptive((0.96, 0.96, 0.97), (0.07, 0.075, 0.085))
    static let surface = adaptive((1, 1, 1), (0.13, 0.14, 0.16))
    static let focusSurface = adaptive((0.92, 0.93, 0.94), (0.23, 0.24, 0.26))
    static let glassSurface = adaptive((0.98, 0.98, 1), (0.16, 0.17, 0.20))
    static let glassStart = adaptive((0.94, 0.94, 1), (0.10, 0.10, 0.22))
    static let glassMiddle = adaptive((1.0, 0.86, 0.72), (0.23, 0.13, 0.16))
    static let glassEdge = adaptive((0.72, 0.86, 0.99), (0.06, 0.22, 0.27))
    static let separator = Color.primary.opacity(0.08)
}

// A root-only header stays outside every tab's scroll view. tvOS 18 can leave
// the native scrolling tab bar offscreen even after focus has returned to it.
enum TVRootTab: String, CaseIterable, Identifiable {
    case launchpad, devices, tasks, mine
    var id: String { rawValue }
    var title: String {
        switch self { case .launchpad: return "启动台"; case .devices: return "设备"; case .tasks: return "事项"; case .mine: return "我的" }
    }
    var symbol: String {
        switch self { case .launchpad: return "square.grid.2x2"; case .devices: return "externaldrive"; case .tasks: return "checklist"; case .mine: return "person.crop.circle" }
    }
}

/// Each tab retains its own navigation stack. Only a stack's root participates
/// in the global tab bar; a pushed library/detail/settings page owns Back.
/// Observe the real root lifecycle (view-based NavigationLinks do not populate
/// a bound NavigationPath). Keep the bar mounted to avoid stealing restored focus.
struct TVRootNavigationShell<Root: View>: View {
    @ViewBuilder let root: (TVRootTab) -> Root
    @State private var selectedTab: TVRootTab
    @State private var visitedTabs: Set<TVRootTab>
    @State private var rootTabs = Set(TVRootTab.allCases)
    init(initialTab: TVRootTab = .launchpad, @ViewBuilder root: @escaping (TVRootTab) -> Root) {
        self.root = root
        _selectedTab = State(initialValue: initialTab)
        _visitedTabs = State(initialValue: [initialTab])
    }
    private var showsTabs: Bool { rootTabs.contains(selectedTab) }
    var body: some View {
        VStack(spacing: 0) {
            TVRootTabBar(selection: $selectedTab)
                .frame(height: showsTabs ? nil : 0)
                .opacity(showsTabs ? 1 : 0).clipped()
                .disabled(!showsTabs).allowsHitTesting(showsTabs)
                .accessibilityHidden(!showsTabs)
            ZStack {
                ForEach(TVRootTab.allCases) { tab in
                    if visitedTabs.contains(tab) || selectedTab == tab {
                        NavigationStack {
                            root(tab)
                                .onAppear { rootTabs.insert(tab) }
                                .onDisappear { rootTabs.remove(tab) }
                        }
                        .opacity(selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(selectedTab == tab)
                        .disabled(selectedTab != tab)
                        .accessibilityHidden(selectedTab != tab)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.tvPageTheme()
            .onChange(of: selectedTab) { visitedTabs.insert($0) }
    }
}

struct TVRootTabBar: View {
    @Binding var selection: TVRootTab
    @FocusState private var focusedTab: TVRootTab?
    @Namespace private var tabFocusScope
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TVRootTab.allCases) { tab in
                Button { selection = tab } label: {
                    Label(tab.title, systemImage: tab.symbol)
                        .font(TVType.section).padding(.horizontal, 28).padding(.vertical, 18)
                }
                .buttonStyle(TVRootTabStyle(selected: selection == tab))
                .focused($focusedTab, equals: tab)
                .prefersDefaultFocus(selection == tab, in: tabFocusScope)
                .accessibilityIdentifier("tv.tab." + tab.id)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(8).background(.thinMaterial, in: Capsule())
        .frame(maxWidth: .infinity).padding(.top, 8).padding(.bottom, 18)
        .focusSection()
        .focusScope(tabFocusScope)
        .defaultFocus($focusedTab, selection, priority: .userInitiated)
        .onAppear { focusedTab = selection }
        .onChange(of: focusedTab) { tab in
            if let tab { selection = tab }
        }
    }
}

private struct TVRootTabStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(focused ? Color.black : (selected ? TVTheme.accent : .primary))
            .background(focused ? TVTheme.accent : (selected ? TVTheme.accent.opacity(0.16) : .clear), in: Capsule())
            .overlay(Capsule().stroke(focused ? TVTheme.accent : .clear, lineWidth: 3))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

enum TVPosterDensity: Int, CaseIterable, Identifiable {
    case large = 3, comfortable = 4, compact = 5
    var id: Int { rawValue }
    var title: String { switch self { case .large: return "舒展 · 每排 3 张"; case .comfortable: return "标准 · 每排 4 张"; case .compact: return "紧凑 · 每排 5 张" } }
}

struct TVPosterStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        MediaPosterFocusStyle(accent: TVTheme.accent).makeBody(configuration: configuration)
    }
}


// tvOS uses the remote Back/Menu key. Keep the dismissal boundary without
// adding a duplicate row that consumes space and becomes a focus stop.
private struct TVBackNavigation: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content.onExitCommand { dismiss() }
        } else { content }
    }
}
extension View {
    func tvNavigationBack(enabled: Bool = true) -> some View {
        modifier(TVBackNavigation(enabled: enabled))
    }
}

enum TVType {
    static let title = Font.system(size: 40, weight: .semibold)
    static let section = Font.system(size: 32, weight: .semibold)
    static let body = Font.system(size: 28)
    static let caption = Font.system(size: 24)
}

enum TVLayout {
    static let gap: CGFloat = 24
    static let cardHeight: CGFloat = 160
    static let radius: CGFloat = AppTheme.cardCornerRadius
    static let informationRowHeight: CGFloat = 128
    static let pageTop: CGFloat = 24
    static let sectionGap: CGFloat = 24
}

/// Built-in feature sets keep equal columns across themes. User-managed
/// collections use full-width rows; poster browsing keeps its own density.
struct TVFixedFeatureGrid<Content: View>: View {
    let columns: Int
    @ViewBuilder let content: Content
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TVLayout.gap), count: columns), spacing: TVLayout.gap) {
            content
        }
        .environment(\.tvCompactInformation, false)
        .buttonStyle(TVTileStyle())
        .focusSection()
    }
}

private struct TVCompactInformationKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var tvCompactInformation: Bool {
        get { self[TVCompactInformationKey.self] }
        set { self[TVCompactInformationKey.self] = newValue }
    }
}
private struct TVInformationLayout: ViewModifier {
    @AppStorage("appearance.launchpadTheme") private var theme = "cleanGrid"
    func body(content: Content) -> some View {
        content.environment(\.tvCompactInformation, theme == "commandCenter")
    }
}
extension View {
    func tvInformationLayout() -> some View { modifier(TVInformationLayout()) }

    /// Keep the remote focus clearance at the edges, without a large blank
    /// header above every information page.
    func tvPageInsets() -> some View {
        padding(.horizontal, 70).padding(.top, TVLayout.pageTop).padding(.bottom, 40)
    }
}

private extension View {
    @ViewBuilder func tvUnclippedScroll() -> some View {
        if #available(tvOS 17.0, *) { scrollClipDisabled() } else { self }
    }
}

enum TVLaunchpadTheme: String, CaseIterable, Identifiable {
    case cleanGrid, commandCenter, glassDeck
    var id: String { rawValue }
    var title: String { switch self { case .cleanGrid: return "清流"; case .commandCenter: return "栈列"; case .glassDeck: return "流光" } }
    var summary: String { switch self { case .cleanGrid: return "清晰分组，轻盈卡片"; case .commandCenter: return "紧凑横列，状态一览"; case .glassDeck: return "柔和渐层，通透层次" } }
}

/// Shared graphite/amber hierarchy, with a visible remote focus treatment.
struct TVTileStyle: ButtonStyle {
    @AppStorage("appearance.launchpadTheme") private var theme = "cleanGrid"
    @Environment(\.isFocused) private var focused
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary.opacity(enabled ? 1 : 0.4))
            .background {
                if focused { RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous).fill(TVTheme.surface).overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous).fill(TVTheme.accent.opacity(0.22))) }
                else if theme == "glassDeck" { RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous).fill(.regularMaterial) }
                else { RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous).fill(TVTheme.surface) }
            }
            .overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(focused ? TVTheme.accent : TVTheme.separator, lineWidth: focused ? 3 : 1))
            .scaleEffect(focused && !reduceMotion ? 1.05 : 1)
            .shadow(color: .black.opacity(focused ? 0.3 : 0), radius: 18, y: 10)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: focused)
    }
}

struct TVPageHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        MediaLibraryHeading(title: title, subtitle: subtitle)
    }
}

struct TVFeatureTile: View {
    @Environment(\.tvCompactInformation) private var compact
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        HStack(spacing: 24) {
            TVIconBadge(symbol: symbol)
            if compact {
                Text(title).font(TVType.body.weight(.semibold))
                    .frame(width: 320, alignment: .leading).lineLimit(2)
                Text(subtitle).font(TVType.caption).foregroundStyle(.secondary).lineLimit(2)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title).font(TVType.body.weight(.semibold)).lineLimit(1)
                    Text(subtitle).font(.system(size: 23)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.system(size: 17, weight: .semibold)).foregroundStyle(.secondary)
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: compact ? TVLayout.informationRowHeight : TVLayout.cardHeight)
    }
}

struct TVIconBadge: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol).font(.system(size: 38, weight: .medium))
            .foregroundStyle(TVTheme.accent).frame(width: 76, height: 76)
            .background(TVTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct TVLoginView: View {
    @EnvironmentObject private var state: TVAppState
    @State private var server = ""
    @State private var user = ""
    @State private var password = ""
    @State private var connectionKind = "DSM"
    @State private var otp = ""
    @Environment(\.dismiss) private var dismiss
    @State private var loading = false
    @State private var error: String?
    @State private var quickCode: String?
    @State private var loginTask: Task<Void, Never>?
    @FocusState private var field: Field?
    private enum Field: Hashable { case server, user, password, otp }
    init(initialKind: String = "DSM", initialServer: URL? = nil) {
        _connectionKind = State(initialValue: initialKind)
        _server = State(initialValue: initialServer?.absoluteString ?? "")
    }
    var body: some View {
        HStack(alignment: .center, spacing: 90) {
            VStack(alignment: .leading, spacing: 28) {
                Label("Nastart", systemImage: "play.rectangle.fill").font(TVType.title).foregroundStyle(TVTheme.accent)
                Text("你的 NAS，\n在大屏上。").font(TVType.title)
                Text("设备文件 · 影音媒体库 · 设备概览").foregroundStyle(.secondary)
                Text("连接后可随时添加其他服务器。") .font(TVType.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: 550, alignment: .leading)
            VStack(alignment: .leading, spacing: 20) {
            Text("连接服务器").font(TVType.section)
            Picker("服务器类型", selection: $connectionKind) {
                Text("Synology DSM").tag("DSM")
                Text("Jellyfin").tag("Jellyfin")
            }.pickerStyle(.segmented).disabled(loading).accessibilityIdentifier("tv.connection.kind")
            Text("选中输入框后，可通过 iPhone 的键盘通知输入。").foregroundStyle(.secondary)
            TextField("服务器地址", text: $server).textInputAutocapitalization(.never).autocorrectionDisabled()
                .textContentType(.URL).keyboardType(.URL).submitLabel(.next)
                .focused($field, equals: .server).onSubmit { field = .user }
                .disabled(loading).accessibilityIdentifier("tv.server")
            TextField("用户名", text: $user).textInputAutocapitalization(.never).autocorrectionDisabled()
                .textContentType(.username).submitLabel(.next)
                .focused($field, equals: .user).onSubmit { field = .password }
                .disabled(loading).accessibilityIdentifier("tv.username")
            SecureField("密码", text: $password).textContentType(.password)
                .focused($field, equals: .password).disabled(loading).accessibilityIdentifier("tv.password")
            if connectionKind == "DSM" {
                TextField("两步验证码（若已开启）", text: $otp).textContentType(.oneTimeCode).keyboardType(.numberPad)
                    .focused($field, equals: .otp).disabled(loading).accessibilityIdentifier("tv.otp")
            }
            if let code = quickCode {
                VStack(alignment: .leading, spacing: 12) {
                    Text(code).font(.system(size: 54, weight: .bold, design: .monospaced)).accessibilityIdentifier("tv.jf.quick.code")
                    Text("在已登录的 Jellyfin 客户端或网页中，打开“快速连接”并输入此码，授权这台电视。")
                        .font(TVType.caption).foregroundStyle(.secondary)
                }
            }
            if let error { Text(error).foregroundStyle(.red).font(TVType.caption) }
            Button(loading ? "正在连接…" : "登录") {
                loading = true; error = nil
                loginTask = Task {
                    defer { loading = false }
                    do {
                        if connectionKind == "DSM" {
                            let url = try TVDSMClient.serverURL(server)
                            let account = try await TVDSMClient(server: url).login(user: user, password: password, otp: otp)
                            guard !Task.isCancelled else { await TVDSMClient(account: account).logout(); return }
                            do { try state.signInNAS(account) }
                            catch { await TVDSMClient(account: account).logout(); throw error }
                        } else {
                            let url = try TVJellyfinClient.serverURL(server)
                            let account = try await TVJellyfinClient(server: url, deviceID: state.deviceID)
                                .login(user: user, password: password)
                            try Task.checkCancellation()
                            try state.signIn(account)
                        }
                        password = ""
                        otp = ""
                        dismiss()
                    } catch {
                        guard !Task.isCancelled else { return }
                        self.error = (error as? TVDSMError)?.localizedDescription
                            ?? (error as? TVClientError)?.localizedDescription ?? "连接失败，请检查地址和网络。"
                    }
                }
            }
            .accessibilityIdentifier("tv.login")
            .disabled(loading || server.isEmpty || user.isEmpty)
            .onChange(of: connectionKind) { _ in loginTask?.cancel(); loading = false; quickCode = nil; error = nil; otp = "" }
            if connectionKind == "Jellyfin" {
                Button(quickCode == nil ? "通过已登录设备授权" : "取消授权") {
                    if quickCode != nil { loginTask?.cancel(); quickCode = nil; loading = false; return }
                    loading = true; error = nil
                    loginTask = Task {
                        defer { loading = false; quickCode = nil }
                        do {
                            let url = try TVJellyfinClient.serverURL(server)
                            let client = TVJellyfinClient(server: url, deviceID: state.deviceID)
                            let pending = try await client.initiateQuickConnect()
                            try Task.checkCancellation(); quickCode = pending.Code
                            for _ in 0..<90 {
                                try await Task.sleep(nanoseconds: 2_000_000_000)
                                if let account = try await client.completeQuickConnect(pending.Secret) {
                                    try Task.checkCancellation(); try state.signIn(account)
                                    password = ""; dismiss(); return
                                }
                            }
                            self.error = "授权等待已超时，请重新生成连接码。"
                        } catch {
                            guard !Task.isCancelled else { return }
                            self.error = "快速连接不可用或已过期，可改用账号密码登录。"
                        }
                    }
                }.disabled(server.isEmpty || (loading && quickCode == nil)).accessibilityIdentifier("tv.jf.quick.connect")
            }
        }
        .padding(38).frame(maxWidth: 880).background(TVTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        }
        .font(TVType.body).padding(70).frame(maxWidth: .infinity, maxHeight: .infinity)
        .tvPageTheme()
        .tvNavigationBack(enabled: state.nasAccount != nil || state.account != nil)
        .onDisappear { loginTask?.cancel(); quickCode = nil; password = ""; otp = "" }
    }
}

struct TVLibraryView: View {
    @EnvironmentObject private var state: TVAppState
    let client: TVJellyfinClient
    @State private var libraries: [TVMediaItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var reload = UUID()
    @State private var resuming: [TVMediaItem] = []
    @State private var recent: [TVMediaItem] = []
    @State private var resumeLoading = true
    @State private var recentLoading = true
    @State private var resumeError = false
    @State private var recentError = false
    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 35) {
                    HStack(alignment: .bottom) {
                        TVPageHeading(title: "影音媒体库", subtitle: "Jellyfin · 电影、剧集与音乐")
                        Spacer()
                        NavigationLink { TVMediaGrid(client: client, title: "搜索", parent: nil, searchMode: true) }
                            label: { Label("搜索媒体", systemImage: "magnifyingglass").font(.system(size: 26, weight: .medium)).padding(20) }
                            .buttonStyle(TVTileStyle())
                        MediaLibraryMenu {
                            Button("刷新", systemImage: "arrow.clockwise") { reload = UUID() }
                                .disabled(loading).accessibilityIdentifier("tv.media.refresh")
                        }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.media.more")
                    }.focusSection()
                    if loading { ProgressView("正在加载媒体库") }
                    if let error {
                        MediaLibraryLoadFailure(hasContent: !libraries.isEmpty || !resuming.isEmpty || !recent.isEmpty,
                            title: Text("媒体库读取未完成"), message: Text(error),
                            accent: TVTheme.accent, messageIdentifier: "tv.media.home.error") {
                            homeRetryAction
                        }
                    }
                    Text("我的媒体库").font(TVType.section)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 32) {
                        ForEach(libraries) { library in
                            NavigationLink {
                                TVMediaGrid(client: client, title: library.Name, parent: library.Id)
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    TVLibraryArtwork(library: library, client: client)
                                    LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(library.Name).font(.system(size: 37, weight: .semibold))
                                        Label("浏览媒体库", systemImage: "arrow.right").font(.system(size: 22)).foregroundStyle(.white.opacity(0.7))
                                    }.foregroundStyle(.white).padding(28)
                                }.frame(height: 290).clipped().clipShape(RoundedRectangle(cornerRadius: 20))
                            }.buttonStyle(TVTileStyle())
                        }
                    }.focusSection()
                    if resumeLoading { ProgressView("正在读取观看进度").font(TVType.caption) }
                    if !resuming.isEmpty { TVMediaShelf(title: "继续观看", items: resuming, client: client, progress: true) }
                    if resumeError {
                        MediaLibraryNotice(title: Text("继续观看"), message: Text("观看进度读取失败"),
                            accent: TVTheme.accent, messageIdentifier: "tv.media.home.resume.error") {
                            homeRetryAction
                        }
                    }
                    if recentLoading { ProgressView("正在读取最近添加").font(TVType.caption) }
                    if !recent.isEmpty { TVMediaShelf(title: "最近添加", items: recent, client: client) }
                    if recentError {
                        MediaLibraryNotice(title: Text("最近添加"), message: Text("最近添加读取失败"),
                            accent: TVTheme.accent, messageIdentifier: "tv.media.home.recent.error") {
                            homeRetryAction
                        }
                    }
                    if !loading && libraries.isEmpty && error == nil {
                        MediaLibraryEmptyState(systemImage: "rectangle.stack", title: Text("暂无可见媒体库"),
                            detail: Text("当前账号没有可见媒体库。"), accent: TVTheme.accent)
                    }
                }.padding(70)
            }
            .tvPageTheme()
            .task(id: reload) {
                loading = true; error = nil
                defer { loading = false }
                do { let result = try await client.libraries(); try Task.checkCancellation(); libraries = result }
                catch { if !Task.isCancelled { self.error = (error as? TVClientError)?.localizedDescription ?? "媒体库加载失败。" } }
            }
            .task(id: reload) {
                resumeLoading = true; resumeError = false
                defer { resumeLoading = false }
                do { let rows = try await client.homeItems(resuming: true); try Task.checkCancellation(); resuming = rows }
                catch { if !Task.isCancelled { resumeError = true } }
            }
            .task(id: reload) {
                recentLoading = true; recentError = false
                defer { recentLoading = false }
                do { let rows = try await client.homeItems(resuming: false); try Task.checkCancellation(); recent = rows }
                catch { if !Task.isCancelled { recentError = true } }
            }
        }
    }
    private var homeRetryAction: some View {
        Button { reload = UUID() } label: {
            Label { Text("重试").foregroundStyle(Color.primary) } icon: {
                Image(systemName: "arrow.clockwise").foregroundStyle(TVTheme.accent)
            }.padding(.horizontal, 18).padding(.vertical, 12)
        }.buttonStyle(TVTileStyle())
    }
}

struct TVMediaGrid: View {
    @AppStorage(MediaPosterGridLayout.televisionDensityPreference) private var posterDensity = MediaPosterGridLayout.defaultTelevisionDensity
    @Environment(\.dynamicTypeSize) private var typeSize
    let client: TVJellyfinClient
    let title: String
    let parent: String?
    var searchMode = false
    @State private var search = ""
    @State private var submittedSearch = ""
    @State private var items: [TVMediaItem] = []
    @State private var loading = true
    @State private var loadingMore = false
    @State private var pageTask: Task<Void, Never>?
    @State private var hasMore = false
    @State private var nextOffset = 0
    @State private var loadedGeneration: UUID?
    @State private var error: String?
    @State private var reload = UUID()
    @FocusState private var focusedItemID: String?
    @State private var requestedItemID: String?
    @State private var columnCount = MediaPosterGridLayout.defaultTelevisionDensity
    var body: some View {
        GeometryReader { geometry in
        let layout = MediaPosterGridLayout.television(viewportWidth: geometry.size.width, density: posterDensity, accessibility: typeSize.isAccessibilitySize)
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 35) {
                HStack {
                    TVPageHeading(title: title, subtitle: searchMode ? "查找电影、剧集与音乐" : "选择喜欢的内容，开始播放")
                    Spacer(minLength: 20)
                    MediaLibraryToolbar {
                        MediaLibraryMenu {
                            Button("刷新", systemImage: "arrow.clockwise") { reload = UUID() }
                                .disabled(loading || loadingMore).accessibilityIdentifier("tv.media.refresh")
                        }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.media.more")
                    }
                }.focusSection()
                if searchMode {
                    MediaLibraryToolbar {
                        TextField("影片、剧集或音乐名称", text: $search)
                            .onSubmit { submittedSearch = search; reload = UUID() }.accessibilityIdentifier("tv.media.search")
                        Button("搜索") { submittedSearch = search; reload = UUID() }.disabled(search.isEmpty)
                    }.focusSection()
                }
                if loading { ProgressView("正在加载") }
                if let error, items.isEmpty {
                    MediaLibraryEmptyState(systemImage: "exclamationmark.triangle",
                        title: Text(searchMode ? "暂时无法完成搜索" : "暂时无法读取媒体库"),
                        detail: Text(error), accent: TVTheme.accent) {
                        Button { reload = UUID() } label: {
                            Label { Text("重试").foregroundStyle(Color.primary) } icon: {
                                Image(systemName: "arrow.clockwise").foregroundStyle(TVTheme.accent)
                            }.padding(.horizontal, 18).padding(.vertical, 12)
                        }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.media.retry")
                    }
                }
                MediaPosterGrid(layout: layout) {
                    ForEach(Array(items.enumerated()), id: \.element.Id) { index, item in
                        NavigationLink {
                            if item.isFolder { TVMediaGrid(client: client, title: item.Name, parent: item.Id) }
                            else { TVDetailView(client: client, initialItem: item) }
                        } label: { TVMediaCard(item: item, client: client).frame(width: max(1, layout.itemWidth - 20), alignment: .topLeading) }
                        .buttonStyle(TVPosterStyle())
                        .id(item.Id)
                        .accessibilityIdentifier("tv.media.item." + item.Id)
                        .focused($focusedItemID, equals: item.Id)
                        .onMoveCommand { direction in move(from: index, direction: direction, proxy: proxy) }
                        .onAppear {
                            if requestedItemID == item.Id { focusedItemID = item.Id; requestedItemID = nil }
                            if index >= items.count - 12 { loadNextPage() }
                        }
                    }
                }
                if loadingMore { ProgressView("正在接续海报").font(TVType.caption) }
                if let error, !items.isEmpty {
                    MediaLibraryNotice(title: Text("后续内容暂未加载"), message: Text(error),
                        detail: Text("已显示的海报仍可浏览。重新加载会从头刷新列表。"),
                        accent: TVTheme.accent, messageIdentifier: "tv.media.error.retained.message") {
                        Button { reload = UUID() } label: {
                            Label { Text("重新加载").foregroundStyle(Color.primary) } icon: {
                                Image(systemName: "arrow.clockwise").foregroundStyle(TVTheme.accent)
                            }.padding(.horizontal, 18).padding(.vertical, 12)
                        }.buttonStyle(TVTileStyle()).accessibilityIdentifier("tv.media.reload.afterFailure")
                    }
                }
                if !loading && items.isEmpty && error == nil {
                    MediaLibraryEmptyState(systemImage: searchMode ? "magnifyingglass" : "film.stack",
                        title: Text(searchMode && submittedSearch.isEmpty ? "开始搜索"
                            : searchMode ? "没有找到影片" : "媒体库暂无作品"),
                        detail: Text(searchMode && submittedSearch.isEmpty ? "输入片名开始搜索。"
                            : searchMode ? "可尝试其他关键词，或返回媒体库浏览。" : "当前媒体库没有可展示的内容。"),
                        accent: TVTheme.accent)
                }
            }.frame(width: layout.contentWidth, alignment: .leading).padding(.vertical, 70).frame(maxWidth: .infinity)
        }
        .tvPageTheme().tvNavigationBack()
        .task(id: reload) {
            guard loadedGeneration != reload else { return }
            pageTask?.cancel(); pageTask = nil; loadingMore = false
            items = []; nextOffset = 0
            error = nil; loading = true; hasMore = false
            defer { loading = false }
            guard !searchMode || !submittedSearch.isEmpty else { return }
            do {
                let page = try await client.items(parent: parent, search: submittedSearch)
                try Task.checkCancellation()
                items = page; nextOffset = page.count; hasMore = page.count == 60; loadedGeneration = reload
            } catch { if !Task.isCancelled { self.error = (error as? TVClientError)?.localizedDescription ?? "加载失败，请检查网络。" } }
        }
        .onDisappear { pageTask?.cancel(); pageTask = nil; loadingMore = false; requestedItemID = nil }
        .onAppear { columnCount = layout.columns }
        .onChange(of: layout.columns) { columnCount = $0 }
        }
        }
    }
    private func move(from index: Int, direction: MoveCommandDirection, proxy: ScrollViewProxy) {
        let logical: TVMediaGridNavigation.Direction
        switch direction {
        case .left: logical = .left
        case .right: logical = .right
        case .up: logical = .up
        case .down: logical = .down
        default: return
        }
        guard let target = TVMediaGridNavigation.target(from: index, count: items.count,
            columns: columnCount, direction: logical) else { return }
        let id = items[target].Id
        requestedItemID = id
        // A nil anchor moves only enough to reveal an offscreen target.
        // Never centre each new row: already visible rows must remain stationary.
        proxy.scrollTo(id)
        DispatchQueue.main.async {
            guard requestedItemID == id else { return }
            focusedItemID = id
        }
    }
    private func loadNextPage() {
        guard hasMore, !loading, !loadingMore, error == nil else { return }
        loadingMore = true
        let generation = reload, query = submittedSearch, offset = nextOffset
        pageTask = Task {
            defer { if reload == generation { loadingMore = false } }
            do {
                let page = try await client.items(parent: parent, search: query, start: offset)
                try Task.checkCancellation()
                guard reload == generation else { return }
                let ids = Set(items.map(\.Id))
                let added = page.filter { !ids.contains($0.Id) }
                items += added; nextOffset += page.count
                hasMore = page.count == 60 && !added.isEmpty
            } catch { if !Task.isCancelled && reload == generation { self.error = "后续海报读取失败，请重试。" } }
        }
    }
}

private struct TVLibraryArtwork: View {
    let library: TVMediaItem
    let client: TVJellyfinClient
    @State private var artwork: TVMediaItem?
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: artwork.map { client.backdropURL($0.Id, width: 1600) } ?? client.imageURL(library.Id, width: 1600)) { image in
                image.resizable().scaledToFill()
            } placeholder: { TVTheme.surface }
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.task(id: library.Id) { artwork = try? await client.libraryArtwork(library.Id) }
    }
}

/// Episode art always belongs to the episode; a series poster is not an episode still.
private struct TVEpisodeArtwork: View {
    let item: TVMediaItem
    let client: TVJellyfinClient
    var body: some View {
        AsyncImage(url: client.imageURL(item.Id)) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else {
                TVTheme.surface.overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "play.rectangle").font(.system(size: 40))
                        Text(item.IndexNumber.map { "第\($0)集" } ?? item.Name).font(TVType.caption)
                    }.foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct TVBackdrop: View {
    let item: TVMediaItem
    let client: TVJellyfinClient
    var blursFallback = true
    var width = 1920
    var body: some View {
        GeometryReader { geometry in
            Group {
                if item.kind == "Episode" { TVEpisodeArtwork(item: item, client: client) }
                else {
                    AsyncImage(url: client.backdropURL(item.Id, width: width)) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else {
                            AsyncImage(url: client.imageURL(item.posterID)) { image in image.resizable().scaledToFill() }
                                placeholder: { Color(white: 0.12) }.blur(radius: blursFallback ? 8 : 0)
                        }
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
    }
}

private struct TVMediaCard: View {
    let item: TVMediaItem
    let client: TVJellyfinClient
    private var episode: Bool { item.kind == "Episode" }
    var body: some View {
        MediaPosterCard(title: episode ? item.Name : item.posterTitle,
                        subtitle: episode ? item.IndexNumber.map { "第\($0)集" } ?? "剧集" : item.posterSubtitle,
                        aspect: episode ? 16.0 / 9.0 : 2.0 / 3.0, canvas: TVTheme.surface, accent: TVTheme.accent) {
            if episode { TVEpisodeArtwork(item: item, client: client) }
            else {
                AsyncImage(url: client.imageURL(item.posterID)) { image in image.resizable().scaledToFill() }
                    placeholder: { TVTheme.surface.overlay(Image(systemName: item.isFolder ? "folder" : "film").font(.system(size: 48)).foregroundStyle(.secondary)) }
            }
        }
    }
}

struct TVMediaShelf: View {
    let title: String
    let items: [TVMediaItem]
    let client: TVJellyfinClient
    var progress = false
    var detailFocus: FocusState<String?>.Binding? = nil
    var requestedDetailFocus: Binding<String?>? = nil
    var moveDetailFocus: ((String, MoveCommandDirection) -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(TVType.section)
            ScrollViewReader { horizontal in
            ScrollView(.horizontal) {
                if detailFocus != nil {
                    // Detail shelves are bounded (12 recommendations). Keep real
                    // focus targets mounted instead of lazy placeholder items.
                    HStack(alignment: .top, spacing: 28) { shelfItems }.padding(12)
                } else {
                    LazyHStack(alignment: .top, spacing: 28) { shelfItems }.padding(12)
                }
            }.tvUnclippedScroll()
                .onChange(of: requestedDetailFocus?.wrappedValue) { target in
                    guard let target, let item = items.first(where: { "tv.detail.similar." + $0.Id == target }), let detailFocus else { return }
                    // Use the ForEach identity so lazy, offscreen items can be realised.
                    horizontal.scrollTo(item.Id)
                    DispatchQueue.main.async {
                        guard requestedDetailFocus?.wrappedValue == target else { return }
                        detailFocus.wrappedValue = target
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).focusSection()
            .tvDetailDefaultFocus(detailFocus, items.first.map { "tv.detail.similar." + $0.Id })
    }
    private var shelfItems: some View {
                    ForEach(items) { item in
                        NavigationLink {
                            if item.isFolder { TVMediaGrid(client: client, title: item.Name, parent: item.Id) }
                            else { TVDetailView(client: client, initialItem: item) }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                if progress {
                                    TVBackdrop(item: item, client: client, blursFallback: false).frame(height: 202).clipShape(RoundedRectangle(cornerRadius: 13))
                                    Text(item.Name).font(TVType.body.weight(.medium)).lineLimit(1)
                                } else { TVMediaCard(item: item, client: client) }
                                if progress, let duration = item.RunTimeTicks, duration > 0 {
                                    ProgressView(value: min(1, max(0, item.resumeSeconds / (Double(duration) / 10_000_000))))
                                        .tint(TVTheme.accent).frame(height: 4)
                                    Text("已观看 \(Int(item.resumeSeconds / 60)) 分钟").font(TVType.caption).foregroundStyle(.secondary)
                                }
                            }.frame(width: progress ? 360 : 300)
                        }.buttonStyle(TVPosterStyle())
                            .modifier(TVDetailShelfFocus(focus: detailFocus, requested: requestedDetailFocus, id: "tv.detail.similar." + item.Id, move: moveDetailFocus))
                            .id(item.Id)
                    }
    }

}

private struct TVDetailShelfFocus: ViewModifier {
    let focus: FocusState<String?>.Binding?
    let requested: Binding<String?>?
    let id: String
    let move: ((String, MoveCommandDirection) -> Void)?
    @ViewBuilder func body(content: Content) -> some View {
        if let focus, let move {
            content.focused(focus, equals: id).accessibilityIdentifier(id)
                .tvDetailFocusFrame(id)
                .onMoveCommand { move(id, $0) }
                .onAppear {
                    guard requested?.wrappedValue == id else { return }
                    DispatchQueue.main.async {
                        guard requested?.wrappedValue == id else { return }
                        focus.wrappedValue = id
                    }
                }
        } else { content }
    }
}

struct TVDetailView: View {
    let client: TVJellyfinClient
    let initialItem: TVMediaItem
    @State private var detail: TVMediaItem?
    @State private var similar: [TVMediaItem] = []
    @State private var error: String?
    @State private var similarError = false
    @State private var detailRead = MediaReadState()
    @State private var expandedOverview = false
    @State private var overviewWidth: CGFloat = 0
    @State private var reload = UUID()
    @State private var playback: TVPlayIntent?
    @FocusState private var focusedDetail: String?
    @State private var requestedDetailFocus: String?
    @State private var lastActionFocus = "tv.play"
    @State private var lastPersonFocus: String?
    @State private var lastRelatedFocus: String?
    private var people: [TVPerson] { Array((item.People ?? []).prefix(20)) }
    private var personFocusIDs: [String] { people.map { "tv.detail.person." + $0.id } }
    private var similarFocusIDs: [String] { similar.map { "tv.detail.similar." + $0.Id } }
    private var personEntryFocus: String? {
        if let focusedDetail, (similarFocusIDs.contains(focusedDetail) || focusedDetail == relatedRetryFocusID),
           let lastPersonFocus, personFocusIDs.contains(lastPersonFocus) { return lastPersonFocus }
        return personFocusIDs.first
    }
    private var actionFocusIDs: [String] {
        ["tv.play"] + (item.resumeSeconds > 0 ? ["tv.play.restart"] : [])
            + (foldsOverview ? ["tv.detail.overview"] : []) + (error == nil ? [] : ["tv.detail.retry"])
    }
    private var item: TVMediaItem { detail ?? initialItem }
    private var fileProperties: MediaDetailFileProperties {
        let source = item.MediaSources?.first
        return MediaDetailFileProperties(path: source?.Path, container: source?.Container,
            size: source?.Size, bitrate: source?.Bitrate)
    }
    private var fileFocusID: String? { fileProperties.hasValues ? "tv.detail.files" : nil }
    private var relatedRetryFocusID: String? { similarError ? "tv.detail.similar.retry" : nil }
    private var focusMap: MediaDetailFocusMap {
        .init(actions: actionFocusIDs, people: personFocusIDs, related: similarFocusIDs,
            relatedRetry: relatedRetryFocusID, files: fileFocusID)
    }

    private var foldsOverview: Bool {
        guard let text = MediaDetailSummary.normalized(item.Overview) else { return false }
        return TVOverviewLayout.shouldCollapse(text, width: overviewWidth)
    }
    var body: some View {
        ScrollViewReader { vertical in
        ScrollView {
            VStack(alignment: .leading, spacing: 38) {
                MediaDetailHero {
                    TVBackdrop(item: item, client: client, width: 2800)
                } poster: {
                    AsyncImage(url: client.imageURL(item.posterID, width: 660)) { image in image.resizable().scaledToFit() }
                        placeholder: { Color.white.opacity(0.06) }
                } content: {
                        VStack(alignment: .leading, spacing: 18) {
                        MediaDetailHeading(title: item.Name)
                        MediaDetailFacts(.init(rating: item.CommunityRating, officialRating: item.OfficialRating,
                            duration: item.duration, video: item.videoDescription, audio: item.audioDescription,
                            date: item.ProductionYear.map(String.init), genres: item.Genres ?? []))
                            .foregroundStyle(.white.opacity(0.88))
                        if let tagline = item.Taglines?.first, !tagline.isEmpty { Text(tagline).font(TVType.caption).foregroundStyle(.white.opacity(0.8)) }
                        MediaDetailSummary(item.Overview ?? "", lines: foldsOverview && !expandedOverview ? 4 : nil)
                            .background(GeometryReader { geometry in
                                Color.clear.onAppear { overviewWidth = geometry.size.width }
                                    .onChange(of: geometry.size.width) { overviewWidth = $0 }
                            })
                        MediaDetailActionRow {
                            Button { playback = TVPlayIntent(item: item, resume: item.resumeSeconds > 0) }
                                label: { Label(item.resumeSeconds > 0 ? "继续播放" : "播放", systemImage: "play.fill").font(TVType.body) }
                                .accessibilityIdentifier("tv.play")
                                .buttonStyle(NastartMediaActionButtonStyle())
                                .focused($focusedDetail, equals: "tv.play")
                                .tvDetailFocusFrame("tv.play")
                                .onMoveCommand { moveDetailFocus(from: "tv.play", direction: $0) }
                            if item.resumeSeconds > 0 {
                                Button { playback = TVPlayIntent(item: item, resume: false) }
                                    label: { Label("从头播放", systemImage: PlaybackControlDesign.restartSymbol).font(TVType.body) }
                                    .buttonStyle(NastartMediaActionButtonStyle())
                                    .accessibilityIdentifier("tv.play.restart")
                                    .focused($focusedDetail, equals: "tv.play.restart")
                                    .tvDetailFocusFrame("tv.play.restart")
                                    .onMoveCommand { moveDetailFocus(from: "tv.play.restart", direction: $0) }
                            }
                            if foldsOverview {
                                Button(expandedOverview ? "收起简介" : "展开简介") { expandedOverview.toggle() }.font(TVType.body)
                                    .accessibilityIdentifier("tv.detail.overview")
                                    .focused($focusedDetail, equals: "tv.detail.overview")
                                    .tvDetailFocusFrame("tv.detail.overview")
                                    .onMoveCommand { moveDetailFocus(from: "tv.detail.overview", direction: $0) }
                            }
                        }
                        if let error {
                            MediaLibraryNotice(title: Text("详情暂未更新"), message: Text(error),
                                accent: TVTheme.accent, messageIdentifier: "tv.detail.error") {
                            retryDetailContent("重试详情", identifier: "tv.detail.retry")
                                .focused($focusedDetail, equals: "tv.detail.retry")
                                .tvDetailFocusFrame("tv.detail.retry")
                                .onMoveCommand { moveDetailFocus(from: "tv.detail.retry", direction: $0) }
                            }.environment(\.colorScheme, .dark)
                        }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                }
                    // The poster occupies the leading column, but actions begin
                    // to its right. Let the whole hero bridge that spatial gap.
                    .focusSection().id("tv.detail.hero")
                    .defaultFocus($focusedDetail, focusMap.preferredAction(lastActionFocus), priority: .userInitiated)
                MediaDetailInformation(studios: (item.Studios ?? []).map(\.Name)) {
                    if !people.isEmpty {
                        MediaDetailSection(title: Text("演职人员")) {
                            ScrollViewReader { horizontal in
                                MediaDetailPeopleScroller {
                                    HStack(alignment: .top, spacing: 28) {
                                        ForEach(people) { person in
                                            let id = "tv.detail.person." + person.id
                                            TVPersonCard(person: person, client: client, focus: $focusedDetail, focusID: id)
                                                .id(person.id).accessibilityIdentifier(id)
                                                .tvDetailFocusFrame(id)
                                                .onMoveCommand { moveDetailFocus(from: id, direction: $0) }
                                                .onAppear {
                                                    guard requestedDetailFocus == id else { return }
                                                    DispatchQueue.main.async {
                                                        guard requestedDetailFocus == id else { return }
                                                        focusedDetail = id
                                                    }
                                                }
                                        }
                                    }
                                }
                                    .onChange(of: requestedDetailFocus) { target in
                                        guard let target, let person = people.first(where: { "tv.detail.person." + $0.id == target }) else { return }
                                        horizontal.scrollTo(person.id)
                                        DispatchQueue.main.async {
                                            guard requestedDetailFocus == target else { return }
                                            focusedDetail = target
                                        }
                                    }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).focusSection().id("tv.detail.cast")
                            .defaultFocus($focusedDetail, personEntryFocus, priority: .userInitiated)
                    } else if let availability = MediaCreditsAvailability.resolve(hasPeople: false,
                        metadata: detailRead.phase(for: initialItem.Id), credits: .ready) {
                        MediaDetailSection(title: Text("演职人员")) {
                            MediaDetailCreditsNotice(availability: availability)
                        }
                    }
                } related: {
                    if !similar.isEmpty {
                        TVMediaShelf(title: "相似影片", items: similar, client: client,
                            detailFocus: $focusedDetail, requestedDetailFocus: $requestedDetailFocus,
                            moveDetailFocus: { moveDetailFocus(from: $0, direction: $1) })
                            .id("tv.detail.related")
                    }
                    if similarError {
                        MediaLibraryNotice(title: Text("相似影片"), message: Text("相似影片读取失败"),
                            accent: TVTheme.accent, messageIdentifier: "tv.detail.similar.error") {
                            retryDetailContent("重试", identifier: "tv.detail.similar.retry")
                                .focused($focusedDetail, equals: "tv.detail.similar.retry")
                                .tvDetailFocusFrame("tv.detail.similar.retry")
                                .onMoveCommand { moveDetailFocus(from: "tv.detail.similar.retry", direction: $0) }
                        }
                        .focusSection().id("tv.detail.related.retry")
                    }
                } supplement: {
                    if let fileFocusID {
                        MediaDetailDisclosure(title: Text("文件信息"), identifier: fileFocusID,
                            focus: $focusedDetail, focusID: fileFocusID) {
                            MediaDetailMetadataRows { fileProperties }
                        }.id("tv.detail.fileInfo")
                            .tvDetailFocusFrame(fileFocusID)
                            .onMoveCommand { moveDetailFocus(from: fileFocusID, direction: $0) }
                    }
                }
            }.padding(70)
        }.tvPageTheme().tvNavigationBack()
        .onChange(of: requestedDetailFocus) { target in
            guard let target else { return }
            // Reveal the destination region only as needed, never centre a row.
            if personFocusIDs.contains(target) { vertical.scrollTo("tv.detail.cast") }
            else if similarFocusIDs.contains(target) { vertical.scrollTo("tv.detail.related") }
            else if target == relatedRetryFocusID {
                vertical.scrollTo("tv.detail.related.retry")
                DispatchQueue.main.async {
                    guard requestedDetailFocus == target, relatedRetryFocusID == target else { return }
                    focusedDetail = target
                }
            }
            else if target == fileFocusID {
                vertical.scrollTo("tv.detail.fileInfo")
                DispatchQueue.main.async {
                    guard requestedDetailFocus == target else { return }
                    focusedDetail = target
                }
            }
            else if actionFocusIDs.contains(target) {
                vertical.scrollTo("tv.detail.hero")
                DispatchQueue.main.async {
                    guard requestedDetailFocus == target, actionFocusIDs.contains(target) else { return }
                    focusedDetail = target
                }
            }
        }
        .onChange(of: focusedDetail) { target in
            guard let target else { return }
            // Native spatial focus may briefly land on an adjacent item while
            // a cross-region request is being realised. Do not remember that
            // intermediate landing as the user's selected actor or movie.
            if requestedDetailFocus == target {
                if personFocusIDs.contains(target) { lastPersonFocus = target }
                else if actionFocusIDs.contains(target) { lastActionFocus = target }
                else if similarFocusIDs.contains(target) { lastRelatedFocus = target }
            }
        }
        .onChange(of: actionFocusIDs) { [previousActions = actionFocusIDs] _ in
            let target = focusMap.recoveryAfterActionChange(previousActions: previousActions,
                focused: focusedDetail, requested: requestedDetailFocus, lastAction: lastActionFocus)
            lastActionFocus = focusMap.preferredAction(lastActionFocus) ?? "tv.play"
            if let target { requestedDetailFocus = target; focusedDetail = target }
        }
        .onChange(of: relatedRetryFocusID) { value in
            guard value == nil, focusedDetail == "tv.detail.similar.retry"
                || (focusedDetail == nil && requestedDetailFocus == "tv.detail.similar.retry") else { return }
            recoverRelatedRetryFocus()
        }
        .task(id: reload) {
            let ticket = detailRead.begin(initialItem.Id)
            error = nil
            do {
                let result = try await client.detail(initialItem.Id); try Task.checkCancellation()
                detail = result
                detailRead.succeed(ticket)
            } catch {
                if !Task.isCancelled {
                    self.error = "影片详情更新失败，仍可尝试播放。"
                    detailRead.fail(ticket)
                } else { detailRead.cancel(ticket) }
            }
        }
        .task(id: reload) {
            similarError = false
            do { let result = try await client.similar(initialItem.Id); try Task.checkCancellation(); similar = result.filter { $0.Id != initialItem.Id } }
            catch { if !Task.isCancelled { similarError = true } }
        }
        .fullScreenCover(item: $playback) { intent in
            TVPlayerView(client: client, intent: intent) { playback = nil }
        }
        }
    }

    private func retryDetailContent(_ title: String, identifier: String) -> some View {
        TVDetailRetryButton(title: title, identifier: identifier) {
            if identifier == "tv.detail.similar.retry" { recoverRelatedRetryFocus() }
            else if identifier == "tv.detail.retry" {
                // The reload immediately clears this error button.
                lastActionFocus = "tv.play"
                requestedDetailFocus = "tv.play"; focusedDetail = "tv.play"
            }
            reload = UUID()
        }
    }
    private func recoverRelatedRetryFocus() {
        let target = focusMap.fallbackAfterRetry(lastAction: lastActionFocus,
            lastPerson: lastPersonFocus, lastRelated: lastRelatedFocus)
        requestedDetailFocus = target; focusedDetail = target
    }
    private func moveDetailFocus(from source: String, direction: MoveCommandDirection) {
        let move: MediaDetailFocusMap.Direction
        switch direction {
        case .up: move = .up
        case .down: move = .down
        case .left: move = .left
        case .right: move = .right
        default: return
        }
        if actionFocusIDs.contains(source) { lastActionFocus = source }
        else if personFocusIDs.contains(source) { lastPersonFocus = source }
        else if similarFocusIDs.contains(source) { lastRelatedFocus = source }
        if let target = focusMap.target(from: source, direction: move, lastAction: lastActionFocus,
            lastPerson: lastPersonFocus, lastRelated: lastRelatedFocus) {
            focusedDetail = target
            requestedDetailFocus = target
        }
    }
}

private struct TVDetailRetryButton: View {
    let title: String
    let identifier: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label { Text(title).foregroundStyle(Color.primary) } icon: {
                Image(systemName: "arrow.clockwise").foregroundStyle(TVTheme.accent)
            }.padding(.horizontal, 18).padding(.vertical, 12)
        }.buttonStyle(TVTileStyle()).accessibilityIdentifier(identifier)
    }
}

#if DEBUG
/// Isolated native focus surface. No account, client, store, media or network tasks.
struct TVDetailFocusOfflineScene: View {
    let configuration: OfflineUIConfiguration
    @FocusState private var focused: String?
    @State private var requested: String?
    @State private var lastPerson: String?
    @State private var lastRelated: String?
    @State private var retryVisible = true
    @State private var retries = 0
    @State private var heroRetryVisible = true
    @State private var overviewVisible = true
    @State private var lastAction = "tv.play"
    private var actionScenario: Bool { configuration.scenario == .detailFocusActions }
    private var actionIDs: [String] {
        ["tv.play"] + (actionScenario && overviewVisible ? ["tv.detail.overview"] : [])
            + (actionScenario && heroRetryVisible ? ["tv.detail.retry"] : [])
    }
    private let retryID = "tv.detail.similar.retry"
    private var full: Bool { configuration.scenario == .detailFocusRetry || actionScenario }
    private var files: String? { configuration.scenario == .detailFocusRetryOnly ? nil : "tv.detail.files" }
    private var map: MediaDetailFocusMap {
        .init(actions: actionIDs, people: full ? ["tv.detail.person.p1", "tv.detail.person.p2"] : [],
            related: full ? ["tv.detail.similar.r1", "tv.detail.similar.r2"] : [],
            relatedRetry: retryVisible && !actionScenario ? retryID : nil, files: files)
    }
    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 38) {
                        Text("离线界面测试 · 合成遥控焦点").font(TVType.section)
                        VStack(alignment: .leading, spacing: 18) {
                            MediaDetailActionRow {
                                Button {} label: { Text("播放（合成操作）").padding(24) }.buttonStyle(TVTileStyle())
                                    .accessibilityIdentifier("tv.play").focused($focused, equals: "tv.play")
                                    .onMoveCommand { move("tv.play", $0) }
                                if actionScenario && overviewVisible {
                                    Button { overviewVisible = false } label: { Text("展开简介（合成更新）").padding(24) }
                                        .buttonStyle(TVTileStyle())
                                        .accessibilityIdentifier("tv.detail.overview").focused($focused, equals: "tv.detail.overview")
                                        .onMoveCommand { move("tv.detail.overview", $0) }
                                }
                            }
                            if actionScenario && heroRetryVisible {
                                TVDetailRetryButton(title: "重试详情", identifier: "tv.detail.retry") {
                                    lastAction = "tv.play"; requested = "tv.play"; focused = "tv.play"
                                    retries += 1; heroRetryVisible = false
                                }.focused($focused, equals: "tv.detail.retry")
                                    .onMoveCommand { move("tv.detail.retry", $0) }
                            }
                        }.focusSection().id("fixture.hero")
                            .defaultFocus($focused, map.preferredAction(lastAction), priority: .userInitiated)
                            .frame(minHeight: 180, alignment: .topLeading)
                        if full {
                            HStack(spacing: 30) {
                                ForEach(Array(map.people.enumerated()), id: \.element) { index, id in
                                    MediaPersonFocusFrame(focused: focused == id, accent: TVTheme.accent) {
                                        MediaDetailPersonCard(name: "合成人物 \(index + 1)", role: "演员") {
                                            MediaPersonPlaceholder()
                                        }
                                    }.focusable().focused($focused, equals: id)
                                        .accessibilityElement(children: .combine).accessibilityIdentifier(id)
                                        .onMoveCommand { move(id, $0) }
                                }
                            }.focusSection().id("fixture.cast")
                            HStack(spacing: 30) {
                                ForEach(Array(map.related.enumerated()), id: \.element) { index, id in
                                    Button {} label: {
                                        MediaPosterCard(title: "合成相关作品 \(index + 1)", subtitle: "离线资料", aspect: 16.0 / 9.0) {
                                            Color.blue.opacity(0.4).overlay(Image(systemName: "film"))
                                        }.frame(width: 260)
                                    }.buttonStyle(TVPosterStyle()).focused($focused, equals: id)
                                        .accessibilityIdentifier(id).onMoveCommand { move(id, $0) }
                                }
                            }.focusSection().id("fixture.related")
                        }
                        if retryVisible && !actionScenario {
                            MediaLibraryNotice(title: Text("相似影片"), message: Text("合成读取失败"), accent: TVTheme.accent) {
                                TVDetailRetryButton(title: "重试", identifier: retryID) {
                                    recover()
                                    retries += 1; retryVisible = false
                                }.focused($focused, equals: retryID)
                                    .onMoveCommand { move(retryID, $0) }
                            }.focusSection().id("fixture.retry")
                        }
                        if let files {
                            MediaDetailDisclosure(title: Text("文件信息"), identifier: files, focus: $focused, focusID: files) {
                                Text("合成文件，不读取源目录")
                            }.onMoveCommand { move(files, $0) }.id("fixture.files")
                        }
                        Text("重试次数：\(retries)").accessibilityIdentifier("offline.focus.receipt")
                    }.padding(70)
                }
                .onChange(of: requested) { target in
                    guard let target else { return }
                    let anchor = map.people.contains(target) ? "fixture.cast"
                        : map.related.contains(target) ? "fixture.related"
                        : target == retryID ? "fixture.retry"
                        : target == files ? "fixture.files" : "fixture.hero"
                    scroll.scrollTo(anchor)
                    DispatchQueue.main.async {
                        guard requested == target, target != retryID || retryVisible,
                              !["tv.play", "tv.detail.overview", "tv.detail.retry"].contains(target) || map.actions.contains(target) else { return }
                        focused = target
                    }
                }
                .onChange(of: actionIDs) { [previousActions = actionIDs] _ in
                    let target = map.recoveryAfterActionChange(previousActions: previousActions,
                        focused: focused, requested: requested, lastAction: lastAction)
                    lastAction = map.preferredAction(lastAction) ?? "tv.play"
                    if let target { requested = target; focused = target }
                }
                .onChange(of: retryVisible) { visible in
                    guard !visible, focused == retryID || (focused == nil && requested == retryID) else { return }
                    recover()
                }
                .onAppear { DispatchQueue.main.async { requested = "tv.play"; focused = "tv.play" } }
            }.tvPageTheme().font(TVType.body).tint(TVTheme.accent)
        }.preferredColorScheme(configuration.appearance == .dark ? .dark : .light)
    }
    private func recover() {
        let target = map.fallbackAfterRetry(lastAction: lastAction, lastPerson: lastPerson, lastRelated: lastRelated)
        requested = target; focused = target
    }
    private func move(_ source: String, _ direction: MoveCommandDirection) {
        let move: MediaDetailFocusMap.Direction
        switch direction {
        case .up: move = .up
        case .down: move = .down
        case .left: move = .left
        case .right: move = .right
        default: return
        }
        if map.actions.contains(source) { lastAction = source }
        if map.people.contains(source) { lastPerson = source }
        if map.related.contains(source) { lastRelated = source }
        if let target = map.target(from: source, direction: move, lastAction: lastAction, lastPerson: lastPerson, lastRelated: lastRelated) {
            requested = target; focused = target
        }
    }
}
#endif

#if DEBUG
struct TVDetailFocusFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
#endif
private extension View {
    @ViewBuilder func tvDetailDefaultFocus(_ focus: FocusState<String?>.Binding?, _ id: String?) -> some View {
        if let focus { defaultFocus(focus, id, priority: .userInitiated) }
        else { self }
    }
    @ViewBuilder func tvDetailFocusFrame(_ id: String) -> some View {
        #if DEBUG
        background(GeometryReader { geometry in
            Color.clear.preference(key: TVDetailFocusFrames.self, value: [id: geometry.frame(in: .global)])
        })
        #else
        self
        #endif
    }
}

/// A short synopsis should not acquire a redundant expansion stop. Collapse
/// only when the measured text would save at least three full lines on this TV.
enum TVOverviewLayout {
    static func shouldCollapse(_ text: String, width: CGFloat) -> Bool {
        guard width > 0, !text.isEmpty else { return false }
        let font = UIFont.systemFont(ofSize: 23)
        let height = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil).height
        return height > font.lineHeight * 6.5
    }
}

/// Cast remains readable and horizontally navigable without a hollow biography
/// destination. A useful filmography can become a destination when supported.
private struct TVPersonCard: View {
    let person: TVPerson
    let client: TVJellyfinClient
    let focus: FocusState<String?>.Binding
    let focusID: String
    private var focused: Bool { focus.wrappedValue == focusID }
    var body: some View {
        MediaPersonFocusFrame(focused: focused, accent: TVTheme.accent) {
            MediaDetailPersonCard(name: person.Name,
                role: person.Role ?? (person.kind == "Director" ? "导演" : "演职人员")) {
                AsyncImage(url: person.Id.map { client.imageURL($0, width: 480) }) { image in image.resizable().scaledToFill() }
                    placeholder: { MediaPersonPlaceholder() }
            }
        }.focusable().focused(focus, equals: focusID)
            .accessibilityElement(children: .combine)
    }
}

struct TVPlayIntent: Identifiable { let id = UUID(); let item: TVMediaItem; let resume: Bool }
struct TVPlayerView: View {
    let client: TVJellyfinClient
    let intent: TVPlayIntent
    let onClose: () -> Void
    var body: some View {
        TVUnifiedPlaybackView(source: .jellyfin(client: client, item: intent.item, resume: intent.resume), close: onClose)
    }
}

/// Shared playback functions with remote-specific chrome: Back closes playback,
/// Play/Pause uses the remote, and audio/settings retain discoverable fallbacks.
@MainActor protocol TVPlaybackControlling: ObservableObject {
    var seekGeneration: Int { get }
    var seconds: Double { get }
    var duration: Double { get }
    var playing: Bool { get }
    var muted: Bool { get }
    var rate: Float { get }
    var audio: [TVPlayerControlsModel.Track] { get }
    var subtitles: [TVPlayerControlsModel.Track] { get }
    var selectedAudio: Int { get }
    var selectedSubtitle: Int { get }
    var canDisableSubtitles: Bool { get }
    var fillsScreen: Bool { get set }
    func toggle()
    func toggleMute()
    func seek(delta: Double)
    func restart()
    func setRate(_ rate: Float)
    func selectAudio(_ index: Int)
    func selectSubtitle(_ index: Int)
}

struct TVNativePlayer: View {
    let player: AVPlayer
    let title: String
    let info: String
    let finish: () -> Void
    @StateObject private var controls: TVPlayerControlsModel
    init(player: AVPlayer, title: String, info: String, controls: TVPlayerControlsModel? = nil, finish: @escaping () -> Void) {
        self.player = player; self.title = title; self.info = info; self.finish = finish
        _controls = StateObject(wrappedValue: controls ?? TVPlayerControlsModel())
    }
    var body: some View {
        TVPlaybackPresentation(title: title, info: info, controls: controls, finish: finish) { fillsScreen in
            TVAVVideoSurface(player: player, fillsScreen: fillsScreen)
        }
        .onAppear { controls.attach(player) }
        .onChange(of: player) { controls.attach($0) }
        .onDisappear { controls.detach() }
    }
}

/// The existing Jellyfin chrome is shared by every source on this terminal.
/// A backend supplies only video pixels, state and control actions.
struct TVPlaybackPresentation<Controls: TVPlaybackControlling, Surface: View>: View {
    let title: String
    let info: String
    let finish: () -> Void
    @ObservedObject var controls: Controls
    let surface: (Bool) -> Surface
    init(title: String, info: String, controls: Controls, finish: @escaping () -> Void,
         @ViewBuilder surface: @escaping (Bool) -> Surface) {
        self.title = title; self.info = info; self.controls = controls
        self.finish = finish; self.surface = surface
    }
    @State private var visible = true
    @State private var panel: Panel?
    @State private var revision = 0
    @FocusState private var focused: String?
    private enum Panel: String { case audio = "音轨", subtitles = "字幕", settings = "更多设置" }

    var body: some View {
        ZStack {
            surface(controls.fillsScreen).ignoresSafeArea()
                .accessibilityIdentifier("tv.player.surface")
            Color.clear.contentShape(Rectangle()).focusable(!visible)
                .focused($focused, equals: "video")
                .onTapGesture { reveal() }

                .onMoveCommand { _ in reveal() }
            if visible {
                VStack {
                    HStack(spacing: 20) {
                        Text(title).font(.system(size: 28, weight: .semibold)).lineLimit(1).frame(maxWidth: .infinity)
                    }.padding(.horizontal, 60).padding(.top, 30)
                        .background(LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom))
                    Spacer()
                    if let panel { panelView(panel) }
                    VStack(spacing: 12) {
                        Button { controls.toggle(); reveal() } label: {
                            VStack(spacing: 10) {
                                TVPlaybackTimeline(seconds: controls.seconds, duration: controls.duration, focused: focused == "seek")
                                HStack { Text(clock(controls.seconds)); Spacer(); Text("−" + clock(max(0, controls.duration - controls.seconds))) }
                                    .font(.system(size: 24, design: .monospaced))
                            }.padding(14)
                        }.buttonStyle(TVPlaybackTimelineStyle()).focused($focused, equals: "seek")
                            .accessibilityLabel("播放进度，左右调整15秒，按确定暂停或继续")
                            .accessibilityIdentifier("tv.player.seek").tvDetailFocusFrame("tv.player.seek")

                            .onMoveCommand { direction in
                                if direction == .left { controls.seek(delta: -Double(PlaybackControlDesign.seekStep)); revision += 1 }
                                if direction == .right { controls.seek(delta: Double(PlaybackControlDesign.seekStep)); revision += 1 }
                            }
                        HStack(spacing: 24) {
                            command("后退15秒", PlaybackControlDesign.backwardSymbol, id: "backward") { controls.seek(delta: -Double(PlaybackControlDesign.seekStep)) }
                            command(controls.playing ? "暂停" : "播放", controls.playing ? "pause.fill" : "play.fill", id: "play") { controls.toggle() }
                            command("前进15秒", PlaybackControlDesign.forwardSymbol, id: "forward") { controls.seek(delta: Double(PlaybackControlDesign.seekStep)) }
                            Spacer()
                            command("音轨", "waveform", id: "audio") { open(.audio) }
                            command("字幕", controls.selectedSubtitle >= 0 ? "captions.bubble.fill" : "captions.bubble", id: "subtitles") { open(.subtitles) }
                            command("更多设置", "gearshape", id: "more") { open(.settings) }
                        }
                    }.padding(.horizontal, 60).padding(.bottom, 28)
                        .background(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                }
            }
        }
        .foregroundStyle(.white).environment(\.colorScheme, .dark)
        .onExitCommand(perform: exit)
        .onAppear { focused = "play" }
        .onPlayPauseCommand { controls.toggle(); reveal() }

        .onChange(of: focused) { _ in
            revision += 1
            #if DEBUG
            TVTransportDiagnostics.record("focus", panel: panel?.rawValue, focus: focused)
            #endif
        }
        .task(id: revision) {
            guard visible, panel == nil else { return }
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled, panel == nil, controls.playing else { return }
            visible = false; focused = "video"
        }
    }
    private func exit() {
        #if DEBUG
        TVTransportDiagnostics.record("back", panel: panel?.rawValue, focus: focused)
        #endif
        if panel != nil { panel = nil; focused = "play"; revision += 1 }
        else { finish() }
    }
    private func reveal() { visible = true; focused = "play"; revision += 1 }
    private func open(_ value: Panel) {
        panel = value; revision += 1; focused = "panel.first"
        #if DEBUG
        TVTransportDiagnostics.record("panel.open", panel: value.rawValue, focus: focused)
        #endif
    }
    private func command(_ label: String, _ symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button { action(); revision += 1 } label: {
            Image(systemName: symbol).font(.system(size: 27, weight: .semibold)).frame(width: 68, height: 68)
        }.buttonStyle(NastartPlaybackButtonStyle(chrome: true))
            .focused($focused, equals: id).accessibilityLabel(label).accessibilityIdentifier("tv.player." + id)
            .tvDetailFocusFrame("tv.player." + id)
            .onExitCommand(perform: exit)
    }
    private func option(_ label: String, id: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button { action(); revision += 1 } label: {
            HStack { Text(label).font(.system(size: 26)); Spacer(); if selected { Image(systemName: "checkmark").foregroundStyle(AppTheme.accent) } }
                .padding(16).frame(maxWidth: .infinity)
        }.buttonStyle(TVTileStyle()).focused($focused, equals: id).accessibilityIdentifier("tv.player.option." + id).accessibilityValue(selected ? "已选择" : "未选择")
            .tvDetailFocusFrame("tv.player.option." + id)
            .onExitCommand(perform: exit)
    }
    private func panelView(_ panel: Panel) -> some View {
        HStack {
            Spacer()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(panel.rawValue).font(.system(size: 30, weight: .semibold))
                    switch panel {
                    case .audio:
                        if controls.audio.isEmpty { Text("当前媒体流未提供可切换的音轨。").font(.system(size: 25)).focusable().focused($focused, equals: "panel.first") }
                        ForEach(Array(controls.audio.enumerated()), id: \.element.id) { offset, track in
                            option(track.name, id: offset == 0 ? "panel.first" : "audio.\(track.id)", selected: controls.selectedAudio == track.id) { controls.selectAudio(track.id) }
                        }
                        option(controls.muted ? "取消静音" : "静音", id: "mute", selected: controls.muted) { controls.toggleMute() }
                    case .subtitles:
                        if controls.subtitles.isEmpty && !controls.canDisableSubtitles {
                            Text("当前媒体流没有独立字幕轨。已烧录进画面的字幕无法在此关闭或改位置。").font(.system(size: 25)).focusable().focused($focused, equals: "panel.first")
                        } else {
                            if controls.canDisableSubtitles {
                                option("关闭字幕", id: "panel.first", selected: controls.selectedSubtitle == -1) { controls.selectSubtitle(-1) }
                            }
                            ForEach(Array(controls.subtitles.enumerated()), id: \.element.id) { offset, track in
                                option(track.name, id: offset == 0 && !controls.canDisableSubtitles ? "panel.first" : "subtitle.\(track.id)", selected: controls.selectedSubtitle == track.id) { controls.selectSubtitle(track.id) }
                            }
                        }
                    case .settings:
                        Text("播放速度").font(.system(size: 24)).foregroundStyle(.secondary)
                        ForEach(Array(PlaybackControlDesign.rates.enumerated()), id: \.offset) { offset, rate in
                            option(String(format: "%gx", rate), id: offset == 0 ? "panel.first" : "rate.\(offset)", selected: abs(controls.rate-rate) < 0.01) { controls.setRate(rate) }
                        }
                        Text("画面比例").font(.system(size: 24)).foregroundStyle(.secondary)
                        option("适合画面", id: "fit", selected: !controls.fillsScreen) { controls.fillsScreen = false }
                        option("填满屏幕（裁切）", id: "fill", selected: controls.fillsScreen) { controls.fillsScreen = true }
                        option("从头播放", id: "restart") { controls.restart() }
                        Text(info).font(.system(size: 24)).foregroundStyle(.secondary).focusable()
                        option("结束播放", id: "finish", action: finish)
                    }
                }.padding(24)
            }.frame(width: 490, height: 380).background(.black.opacity(0.9), in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
        }.padding(.horizontal, 60).padding(.bottom, 25)
    }
    private func clock(_ seconds: Double) -> String {
        let n = Int(seconds.isFinite ? max(0, seconds) : 0)
        return n >= 3600 ? String(format: "%d:%02d:%02d", n/3600, (n/60)%60, n%60) : String(format: "%d:%02d", n/60, n%60)
    }
}

#if DEBUG
private enum TVTransportDiagnostics {
    private static var rows: [[String: String]] = []
    static func record(_ event: String, panel: String?, focus: String?) {
        rows.append(["event": event, "panel": panel ?? "none", "focus": focus ?? "none", "mono": String(ProcessInfo.processInfo.systemUptime)])
        rows = Array(rows.suffix(64))
        let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("tv-transport-interaction-debug.json")
        if let data = try? JSONSerialization.data(withJSONObject: rows) { try? data.write(to: path, options: .atomic) }
    }
}
#endif

/// Returning only our label suppresses tvOS's default filled focus platter.
private struct TVPlaybackTimelineStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct TVPlaybackTimeline: View {
    let seconds: Double
    let duration: Double
    let focused: Bool
    private var fraction: CGFloat { CGFloat(min(1, max(0, seconds / max(1, duration)))) }
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.28)).frame(height: focused ? 6 : 4)
                Capsule().fill(AppTheme.accent).frame(width: width * fraction, height: focused ? 6 : 4)
                Circle().fill(focused ? AppTheme.accent : .white)
                    .frame(width: focused ? 18 : 10, height: focused ? 18 : 10)
                    .shadow(color: focused ? AppTheme.accent.opacity(0.5) : .clear, radius: 6)
                    .offset(x: max(0, min(width - 18, width * fraction - 9)))
            }.frame(height: 22)
        }.frame(height: 22).accessibilityHidden(true)
    }
}

/// A fixed video layer has no system transport menus/safe-area reflow. AV's
/// legible output stays tied to the video rectangle when app panels open.
struct TVAVVideoSurface: UIViewRepresentable {
    let player: AVPlayer
    let fillsScreen: Bool
    final class VideoView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
    func makeUIView(context: Context) -> VideoView { let v = VideoView(); v.backgroundColor = .black; v.isUserInteractionEnabled = false; return v }
    func updateUIView(_ view: VideoView, context: Context) {
        if view.videoLayer.player !== player { view.videoLayer.player = player }
        view.videoLayer.videoGravity = fillsScreen ? .resizeAspectFill : .resizeAspect
    }
    static func dismantleUIView(_ view: VideoView, coordinator: ()) { view.videoLayer.player = nil }
}

struct TVPageBackground: View {
    @Environment(\.colorScheme) private var scheme
    @AppStorage("appearance.launchpadTheme") private var theme = "cleanGrid"
    var body: some View {
        ZStack {
            TVTheme.background
            if theme == "glassDeck" {
                LinearGradient(colors: AppTheme.glassColors(dark: scheme == .dark), startPoint: .topLeading, endPoint: .bottomTrailing)
            } else if theme == "commandCenter" {
                LinearGradient(colors: [TVTheme.background, TVTheme.accent.opacity(0.10)], startPoint: .top, endPoint: .bottom)
            }
        }.ignoresSafeArea()
    }
}
extension View {
    func tvPageTheme() -> some View { background { TVPageBackground() } }
}

private struct TVCardSurface: ViewModifier {
    let radius: CGFloat
    @AppStorage("appearance.launchpadTheme") private var theme = "cleanGrid"
    @ViewBuilder func body(content: Content) -> some View {
        content.background {
            if theme == "glassDeck" { RoundedRectangle(cornerRadius: radius).fill(.regularMaterial) }
            else { RoundedRectangle(cornerRadius: radius).fill(TVTheme.surface) }
        }.overlay(RoundedRectangle(cornerRadius: radius)
            .stroke(theme == "commandCenter" ? TVTheme.accent.opacity(0.20) : TVTheme.separator, lineWidth: 1))
    }
}
extension View {
    func tvCardSurface(radius: CGFloat = TVLayout.radius) -> some View { modifier(TVCardSurface(radius: radius)) }
}
