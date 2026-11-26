import SwiftUI
import Combine
import UIKit
import NetworkMedia
#if DEBUG
import AVKit
import KSPlayer
#endif

private struct TVWindowAppearance: UIViewRepresentable {
    let mode: String
    final class StyleView: UIView {
        var style: UIUserInterfaceStyle = .unspecified
        override func didMoveToWindow() { super.didMoveToWindow(); apply() }
        func apply() {
            if window?.overrideUserInterfaceStyle != style { window?.overrideUserInterfaceStyle = style }
        }
    }
    func makeUIView(context: Context) -> StyleView { StyleView() }
    func updateUIView(_ view: StyleView, context: Context) {
        view.style = mode == "light" ? .light : (mode == "dark" ? .dark : .unspecified)
        view.apply()
    }
}

@MainActor
final class TVAppState: ObservableObject {
    @Published var account: TVAccount?
    @Published var nasAccount: TVNASAccount?
    @Published private(set) var jellyfinSessionRevision = UUID()
    private var silentlyRenewedToken: String?
    private var renewingJellyfin = false
    let deviceID: String
    init() {
        account = TVAccountVault.load()
        nasAccount = TVAccountVault.load(TVNASAccount.self, nas: true)
        if let id = UserDefaults.standard.string(forKey: "tv.installation.id") { deviceID = id }
        else {
            deviceID = UUID().uuidString
            UserDefaults.standard.set(deviceID, forKey: "tv.installation.id")
        }
    }
#if DEBUG
    /// Offline UI only: no accounts, no Keychain read, no installation id written.
    init(offlineFixture: Void) { deviceID = "offline-ui-fixture" }
#endif
    func signIn(_ account: TVAccount, password: String? = nil) throws {
        try TVAccountVault.save(account)
        TVJellyfinClient.trace("session_saved", token: account.token)
        if let password, !password.isEmpty {
            do { try TVAccountVault.savePassword(password, for: account) }
            catch { TVJellyfinClient.trace("password_save_failed") }
        }
        if let previous = self.account, previous.server != account.server || previous.userID != account.userID {
            try? TVAccountVault.clearPassword(for: previous)
        }
        self.account = account
        silentlyRenewedToken = nil
        jellyfinSessionRevision = UUID()
    }
    func renewJellyfinSession(rejected client: TVJellyfinClient) async -> Bool {
        TVJellyfinClient.trace("renew_requested", token: client.token)
        // A different homepage request may have already renewed this session.
        if let held = account, held.server == client.server, held.userID == client.userID,
           held.token != client.token { return true }
        guard let held = account, held.server == client.server,
              held.userID == client.userID, held.token == client.token else {
            TVJellyfinClient.trace("renew_skipped_identity")
            return false
        }
        guard !renewingJellyfin else { TVJellyfinClient.trace("renew_skipped_in_progress"); return false }
        guard held.token != silentlyRenewedToken else {
            TVJellyfinClient.trace("renewed_token_rejected_no_login_loop", token: held.token); return false
        }
        guard let password = TVAccountVault.password(for: held) else {
            TVJellyfinClient.trace("renew_skipped_no_saved_password"); return false
        }
        renewingJellyfin = true
        TVJellyfinClient.trace("renew_login_started", token: held.token)
        defer { renewingJellyfin = false }
        do {
            let renewed = try await TVJellyfinClient(server: held.server, deviceID: deviceID)
                .login(user: held.userName, password: password)
            TVJellyfinClient.trace("renew_login_succeeded", token: renewed.token)
            try Task.checkCancellation()
            guard account == held, renewed.userID == held.userID else { return false }
            try signIn(renewed)
            silentlyRenewedToken = renewed.token
            TVJellyfinClient.trace("renew_persisted_reload", token: renewed.token)
            return true
        } catch TVClientError.http(401) {
            TVJellyfinClient.trace("renew_login_rejected_401")
            return false
        } catch {
            TVJellyfinClient.trace("renew_failed_or_cancelled")
            return false
        }
    }
    func signOut() throws {
        let previous = account
        try TVAccountVault.clear()
        account = nil
        silentlyRenewedToken = nil
        if let previous { try TVAccountVault.clearPassword(for: previous) }
    }
    func signInNAS(_ account: TVNASAccount) throws {
        try TVAccountVault.save(account, nas: true)
        nasAccount = account
    }
    func signOutNAS() async throws {
        let previous = nasAccount
        try TVAccountVault.clear(nas: true)
        nasAccount = nil
        if let previous { await TVDSMClient(account: previous).logout() }
    }
}

#if DEBUG
/// Sets the window scene's Bold Text trait, which navigation hosts read back, unlike a
/// SwiftUI environment override. Only for offline UI runs.
private struct TVOfflineBoldText: UIViewRepresentable {
    final class TraitView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if #available(tvOS 17.0, *) { window?.windowScene?.traitOverrides.legibilityWeight = .bold }
        }
    }
    func makeUIView(context: Context) -> TraitView { TraitView() }
    func updateUIView(_ view: TraitView, context: Context) {}
}
#endif

@main
struct NastartTVApp: App {
    var body: some Scene {
        WindowGroup {
#if DEBUG
            if let configuration = OfflineUIConfiguration.requested(arguments: ProcessInfo.processInfo.arguments) {
                // `--offline-ui-bold` stands in for the system Bold Text setting (tvOS has no Larger Text).
                Group {
                if configuration.scenario == .accountConnections {
                    if ProcessInfo.processInfo.arguments.contains("--offline-ui-confirmations") {
                        TVDisconnectConfirmationsOfflineScene(configuration: configuration)
                    } else {
                        TVAccountConnectionsOfflineScene(configuration: configuration)
                    }
                } else if [.launchpadRoot, .devicesRoot, .tasksRoot].contains(configuration.scenario) {
                    TVOfflineRootScene(configuration: configuration)
                } else if [.detailFocusRetry, .detailFocusRetryEmpty, .detailFocusRetryOnly, .detailFocusActions].contains(configuration.scenario) {
                    TVDetailFocusOfflineScene(configuration: configuration)
                } else { NastartOfflineUIRoot(configuration: configuration) }
                }.background {
                    if ProcessInfo.processInfo.arguments.contains("--offline-ui-bold") {
                        TVOfflineBoldText().frame(width: 0, height: 0)
                    }
                }
            } else { NastartTVApplicationContent() }
#else
            NastartTVApplicationContent()
#endif
        }
    }
}

private struct NastartTVApplicationContent: View {
    @StateObject private var state = TVAppState()
    @StateObject private var serviceSync = TVCloudSyncStore.forCurrentInstallation()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance.themeMode") private var themeMode = "system"
    private var preferredScheme: ColorScheme? { themeMode == "light" ? .light : (themeMode == "dark" ? .dark : nil) }
    var body: some View {
        Group {
            Group {
                #if DEBUG
                if let probe = TVExitProbeRoot.requestedMode {
                    TVExitProbeRoot(mode: probe)
                } else {
                    applicationRoot
                }
                #else
                applicationRoot
                #endif
            }
            .environmentObject(state)
            .environmentObject(serviceSync)
            .task(id: scenePhase) {
                if scenePhase == .active { await serviceSync.applicationBecameActive() }
            }
            .preferredColorScheme(preferredScheme)
            .background(TVWindowAppearance(mode: themeMode).frame(width: 0, height: 0))
            .tint(TVTheme.accent)
            .buttonStyle(NastartSecondaryButtonStyle())
            .font(TVType.body)
        }
    }

    @ViewBuilder private var applicationRoot: some View {
        if state.nasAccount != nil || state.account != nil { TVHomeView() }
        else { TVLoginView() }
    }
}

#if DEBUG
/// Explicit, network-free UI regression surface. Normal launch and Release
/// never enter this branch; no NAS account, preference or media is changed.
private struct TVExitProbeRoot: View {
    static var requestedMode: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--tv-exit-probe"), args.indices.contains(index + 1),
              ["button", "slider", "player-av", "player-ks", "player-ks-nested", "button-nested", "player-ks-edge", "player-ks-edge-nested", "player-ks-delayed", "player-ks-delayed-nested", "player-ks-local", "player-ks-local-edge", "player-ks-local-edge-nested", "player-ks-local-lazy", "player-ks-local-lazy-edge", "player-ks-local-lazy-edge-nested", "player-ks-local-lazy-async-edge", "player-ks-local-lazy-async-edge-nested", "player-native-av", "player-native-tracks", "navigation", "detail-focus"].contains(args[index + 1]) else { return nil }
        return args[index + 1]
    }
    let mode: String
    @State private var presented = false
    @State private var received = 0
    @State private var disappeared = 0
    @StateObject private var events = TVExitProbeEvents()
    @StateObject private var detailEvents = TVDetailNativeFocusEvents()
    var body: some View {
        if mode.hasSuffix("-nested") {
            TVNestedExitProbeRoot(mode: String(mode.dropLast("-nested".count)))
        } else if mode == "detail-focus" {
            NavigationStack {
                TVDetailView(client: TVDetailFocusFixture.client, initialItem: TVDetailFocusFixture.item)
                    .onPreferenceChange(TVDetailFocusFrames.self) { detailEvents.frames = $0 }
            }
                .overlay(alignment: .topLeading) {
                    Text(detailEvents.trace).font(.system(size: 1)).allowsHitTesting(false)
                        .accessibilityIdentifier("tv.detail.focus.events")
                }
        } else if mode == "navigation" {
            TVRootNavigationShell { tab in
                VStack(spacing: 30) {
                    Text(tab.title).accessibilityIdentifier("tv.nav.probe.root")
                    NavigationLink { TVNavigationProbeChild(depth: 1) } label: { Text("打开子页面").frame(width: 1400, height: 120) }
                        .accessibilityIdentifier("tv.nav.probe.open")
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
        VStack(spacing: 30) {
            Text("无媒体返回测试").font(.title)
            Button("打开全屏") { presented = true }.accessibilityIdentifier("tv.exit.probe.open")
            Text("received=\(received) disappeared=\(disappeared)")
                .accessibilityIdentifier("tv.exit.probe.receipt")
            Text(events.trace).accessibilityIdentifier("tv.exit.probe.events")
        }
        .fullScreenCover(isPresented: $presented) {
            TVExitProbeSurface(mode: mode, events: events) {
                received += 1
                presented = false
            }.onDisappear { disappeared += 1 }
        }
        }
    }
}

/// Same network-free player/control surface, with the library's extra detail
/// sheet and navigation stack. Only the presentation hierarchy differs.
private struct TVNestedExitProbeRoot: View {
    let mode: String
    @State private var detail = false
    @State private var presented = false
    @State private var received = 0
    @State private var disappeared = 0
    @StateObject private var events = TVExitProbeEvents()
    var body: some View {
        Button("打开资料页") { detail = true }
            .accessibilityIdentifier("tv.exit.probe.openDetail")
            .sheet(isPresented: $detail) {
                NavigationStack {
                    VStack(spacing: 30) {
                        Text("无媒体资料页").accessibilityIdentifier("tv.exit.probe.detail")
                        Button("打开全屏") { presented = true }.accessibilityIdentifier("tv.exit.probe.open")
                        Text("received=\(received) disappeared=\(disappeared)")
                            .accessibilityIdentifier("tv.exit.probe.receipt")
                        Text(events.trace).accessibilityIdentifier("tv.exit.probe.events")
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .fullScreenCover(isPresented: $presented) {
                            TVExitProbeSurface(mode: mode, events: events) {
                                received += 1; presented = false
                            }.onDisappear { disappeared += 1 }
                        }
                }
            }
    }
}

/// Capture actual focus-engine commits, including transient landings that an
/// eventual hasFocus assertion cannot detect. Only mounted in the DEBUG fixture.
private final class TVDetailNativeFocusEvents: ObservableObject {
    @Published var trace = ""
    var frames: [String: CGRect] = [:]
    private var observer: NSObjectProtocol?
    init() {
        observer = NotificationCenter.default.addObserver(forName: UIFocusSystem.didUpdateNotification,
            object: nil, queue: .main) { [weak self] notification in
            guard let context = notification.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext,
                  let item = context.nextFocusedItem else { return }
            var view = item as? UIView
            var id = (item as? UIAccessibilityIdentification)?.accessibilityIdentifier
            while id == nil, let parent = view?.superview {
                view = parent
                id = parent.accessibilityIdentifier
            }
            var environment: (any UIFocusEnvironment)? = item
            var space = item.focusItemContainer?.coordinateSpace
            while space == nil, let parent = environment?.parentFocusEnvironment {
                environment = parent
                space = parent.focusItemContainer?.coordinateSpace ?? (parent as? UIView)
            }
            if id == nil, let space {
                let rect = space.convert(item.frame, to: UIScreen.main.coordinateSpace)
                let centre = CGPoint(x: rect.midX, y: rect.midY)
                id = self?.frames.filter { $0.value.contains(centre) }
                    .min(by: { $0.value.width * $0.value.height < $1.value.width * $1.value.height })?.key
            }
            let event = id ?? "unidentified:\(type(of: item)):frame=\(item.frame):mapped=\(self?.frames.count ?? -1):global=\(space?.convert(item.frame, to: UIScreen.main.coordinateSpace) ?? .zero)"
            self?.trace += (self?.trace.isEmpty == true ? "" : "|") + event
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}

/// Uses the production detail view with in-memory metadata; no NAS/media access.
private enum TVDetailFocusFixture {
    static let payload: [String: Any] = [
        "Id": "focus-film", "Name": "方向键回归影片", "Type": "Movie", "ProductionYear": 2026,
        "Overview": "用于核对海报左侧留空时，从首位演员向上返回播放操作，以及横向列表末端的上下衔接。",
        "RunTimeTicks": 7_200_000_000, "UserData": ["PlaybackPositionTicks": 600_000_000],
        "People": (0..<12).map { ["Id": "cast-\($0)", "Name": "演员 \($0)", "Role": "角色 \($0)", "Type": "Actor"] }
    ]
    static let item = try! JSONDecoder().decode(TVMediaItem.self, from: JSONSerialization.data(withJSONObject: payload))
    static let client: TVJellyfinClient = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TVDetailFocusProtocol.self]
        return TVJellyfinClient(server: URL(string: "http://127.0.0.1:9")!, userID: "focus-user", deviceID: "focus-test",
            session: URLSession(configuration: configuration))
    }()
}
private final class TVDetailFocusProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let object: [String: Any]
        if request.url!.path.contains("Similar") {
            let rows: [[String: String]] = (0..<7).map { ["Id": "related-\($0)", "Name": "相似影片 \($0)", "Type": "Movie"] }
            object = ["Items": rows]
        } else { object = TVDetailFocusFixture.payload }
        let data = try! JSONSerialization.data(withJSONObject: object)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private struct TVNavigationProbeChild: View {
    let depth: Int
    var body: some View {
        VStack(spacing: 30) {
            Text("子页面 \(depth)").accessibilityIdentifier("tv.nav.probe.child.\(depth)")
            if depth == 1 {
                NavigationLink { TVNavigationProbeChild(depth: 2) } label: { Text("下一层").frame(width: 1400, height: 120) }
                    .accessibilityIdentifier("tv.nav.probe.next")
            } else { Button("末层焦点") {} }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).tvNavigationBack()
    }
}

private struct TVExitProbeSurface: View {
    let mode: String
    @ObservedObject var events: TVExitProbeEvents
    let onExit: () -> Void
    @State private var value: Float = 0.5
    @FocusState private var focused: Bool
    @State private var nativePlayer = AVPlayer()
    @StateObject private var sourceControls = TVPlayerControlsModel()
    @StateObject private var playerFocusEvents = TVDetailNativeFocusEvents()
    var body: some View {
        if mode.contains("-async") {
            TVExitProbeAsyncSurface(mode: mode, events: events, onExit: onExit)
        } else if mode.contains("-edge") && mode.hasPrefix("player-ks") {
            TVExitProbePlayer(usesKS: true, playsLocalFixture: mode.contains("-local"), createsPlayerInView: mode.contains("-lazy"), events: events, onClose: onExit)
                .ignoresSafeArea()
                .overlay(alignment: .topLeading) {
                    Text("全屏测试 · " + mode).font(.system(size: 1))
                        .accessibilityIdentifier("tv.exit.probe.cover").allowsHitTesting(false)
                }
                .onExitCommand(perform: onExit)
        } else if mode == "player-native-av" || mode == "player-native-tracks" {
            ZStack(alignment: .top) {
                TVNativePlayer(player: nativePlayer, title: "无媒体原生播放器", info: "无网络媒体", controls: sourceControls, finish: onExit)
                Text("全屏测试 · " + mode).accessibilityIdentifier("tv.exit.probe.cover").allowsHitTesting(false)
            }.onPreferenceChange(TVDetailFocusFrames.self) { playerFocusEvents.frames = $0 }
            .overlay(alignment: .topLeading) {
                Text(playerFocusEvents.trace).font(.system(size: 1)).allowsHitTesting(false).accessibilityIdentifier("tv.player.focus.events")
            }.onAppear {
                if mode == "player-native-tracks" {
                    let data = Data(#"[{"Index":1,"Type":"Audio","DisplayTitle":"原声音轨"},{"Index":4,"Type":"Subtitle","DisplayTitle":"中文字幕"}]"#.utf8)
                    sourceControls.sourceRoute = TVPlaybackRoute(url: URL(string: "http://127.0.0.1:9/never-requested")!,
                        sourceID: "fixture-source", playSessionID: nil, playMethod: "Transcode",
                        tracks: try! JSONDecoder().decode([TVSourceTrack].self, from: data), audioIndex: 1, subtitleIndex: 4)
                    sourceControls.onSelectSource = { choice in
                        guard var route = sourceControls.sourceRoute else { return }
                        route.audioIndex = choice.audioIndex; route.subtitleIndex = choice.subtitleIndex
                        sourceControls.sourceRoute = route
                    }
                }
            }
        } else { legacySurface }
    }
    private var legacySurface: some View {
        VStack(spacing: 50) {
            Text("全屏测试 · " + mode).accessibilityIdentifier("tv.exit.probe.cover")
            if mode == "player-native-av" {
                TVNativePlayer(player: nativePlayer, title: "无媒体原生播放器", info: "无网络媒体", finish: onExit)
            } else if mode.hasPrefix("player-") {
                TVExitProbePlayer(usesKS: mode.hasPrefix("player-ks"), initiallyVisibleControls: mode == "player-ks-delayed", playsLocalFixture: mode.contains("-local"), createsPlayerInView: mode.contains("-lazy"), events: events, onClose: onExit)
            } else if mode == "slider" {
                KSPlayer.Slider(value: $value)
                    .frame(width: 800, height: 50)
                    .accessibilityIdentifier("tv.exit.probe.focus")
                    .focused($focused)
            } else {
                Button("焦点对照") { }
                    .accessibilityIdentifier("tv.exit.probe.focus")
                    .focused($focused)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .onAppear { focused = true }
            .onExitCommand(perform: onExit)
    }
}

/// Reproduce preparation-to-renderer replacement without credentials or NAS.
/// The preparation button is present long enough to become native focus first.
private struct TVExitProbeAsyncSurface: View {
    let mode: String
    @ObservedObject var events: TVExitProbeEvents
    let onExit: () -> Void
    @State private var ready = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if ready {
                AnyView(TVExitProbePlayer(usesKS: true, playsLocalFixture: true,
                    createsPlayerInView: true, events: events, onClose: onExit).ignoresSafeArea())
            } else {
                VStack(spacing: 24) {
                    ProgressView("正在准备播放")
                    Button("取消", action: onExit).accessibilityIdentifier("tv.exit.probe.preparing")
                }.padding(40).foregroundStyle(.white).tint(.orange)
            }
        }.preferredColorScheme(.dark)
            .overlay(alignment: .topLeading) {
                Text("全屏测试 · " + mode).font(.system(size: 1))
                    .accessibilityIdentifier("tv.exit.probe.cover").allowsHitTesting(false)
            }
            .task {
                do { try await Task.sleep(nanoseconds: 4_000_000_000) } catch { return }
                ready = true
            }
            .onExitCommand(perform: onExit)
    }
}

@MainActor
private final class TVExitProbeEvents: ObservableObject {
    @Published private(set) var trace = ""
    func record(_ event: String, _ values: [String: String]) {
        let row = event + ":" + values.keys.sorted().map { $0 + "=" + values[$0]! }.joined(separator: ",")
        trace = (trace.components(separatedBy: " | ") + [row]).suffix(16).joined(separator: " | ")
    }
}

private struct TVExitProbePlayer: View {
    let onClose: () -> Void
    let initiallyVisibleControls: Bool
    @StateObject private var session: TVExitProbePlayerSession
    init(usesKS: Bool, initiallyVisibleControls: Bool = false, playsLocalFixture: Bool = false, createsPlayerInView: Bool = false, events: TVExitProbeEvents, onClose: @escaping () -> Void) {
        self.onClose = onClose
        self.initiallyVisibleControls = initiallyVisibleControls
        _session = StateObject(wrappedValue: TVExitProbePlayerSession(usesKS: usesKS, initiallyVisibleControls: initiallyVisibleControls, playsLocalFixture: playsLocalFixture, createsPlayerInView: createsPlayerInView, events: events))
    }
    var body: some View {
        ZStack(alignment: .topTrailing) {
            KSVideoPlayerView(coordinator: session.coordinator, url: session.url, options: session.options, title: "无媒体播放器返回测试")
            Button("完成", action: onClose).padding(35).accessibilityIdentifier("tv.exit.probe.done")
        }.onDisappear { session.stop() }
            .task {
                if initiallyVisibleControls {
                    do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                    session.coordinator.isMaskShow = false
                }
            }
    }
}

@MainActor
private final class TVExitProbePlayerSession: ObservableObject {
    let url: URL
    let options: KSOptions
    let coordinator: KSVideoPlayer.Coordinator
    private let previousPlayerType: MediaPlayerProtocol.Type
    init(usesKS: Bool, initiallyVisibleControls: Bool = false, playsLocalFixture: Bool = false, createsPlayerInView: Bool = false, events: TVExitProbeEvents) {
        url = playsLocalFixture
            ? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("tv-network-exit-owned-fixture.mp4")
            : URL(fileURLWithPath: "/nonexistent/tv-exit-probe.mp4")
        let options = KSOptions()
        options.registerRemoteControll = playsLocalFixture
        options.viewInteractionObserved = { [weak events] in events?.record($0, $1) }
        self.options = options
        coordinator = KSVideoPlayer.Coordinator()
        previousPlayerType = KSOptions.firstPlayerType
        KSOptions.firstPlayerType = usesKS ? KSMEPlayer.self : KSAVPlayer.self
        // Default controls never decode; the explicit local mode reads only the
        // task-owned cache fixture, with no NAS or other network endpoint.
        if !createsPlayerInView {
            coordinator.playerLayer = KSPlayerLayer(url: url, isAutoPlay: playsLocalFixture, options: options, delegate: coordinator)
            KSOptions.firstPlayerType = previousPlayerType
        }
        coordinator.isMaskShow = initiallyVisibleControls || playsLocalFixture
    }
    func stop() {
        coordinator.resetPlayer()
        KSOptions.firstPlayerType = previousPlayerType
    }
}
#endif
