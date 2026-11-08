#if os(iOS) || os(tvOS)
import SwiftUI

@MainActor public struct NetworkMediaServicesContext {
    public let candidates: [MediaServiceCandidate]
    public let inventory: MediaServiceInventory
    let transport: any PublicMediaServiceTransport
    private let savedLoginAvailable: (@MainActor (String, URL) -> Bool)?
    public let reloadInventory: (@MainActor () async -> NetworkMediaServicesContext?)?
    public let nativeDestination: @MainActor (String, URL) -> AnyView?
    public init(candidates: [MediaServiceCandidate], inventory: MediaServiceInventory, transport: any PublicMediaServiceTransport = PublicMediaServiceHTTP(),
                savedLoginAvailable: (@MainActor (String, URL) -> Bool)? = nil,
                reloadInventory: (@MainActor () async -> NetworkMediaServicesContext?)? = nil,
                nativeDestination: @escaping @MainActor (String, URL) -> AnyView? = { _, _ in nil }) {
        self.candidates = Array(MediaServiceCatalog.coalesced(candidates).prefix(16)); self.inventory = inventory; self.transport = transport; self.savedLoginAvailable = savedLoginAvailable; self.reloadInventory = reloadInventory
        self.nativeDestination = nativeDestination
    }
    public func withInventory(_ inventory: MediaServiceInventory) -> Self {
        Self(candidates: candidates, inventory: inventory, transport: transport, savedLoginAvailable: savedLoginAvailable,
             reloadInventory: reloadInventory, nativeDestination: nativeDestination)
    }
    func resolveLogin(_ candidate: MediaServiceCandidate) -> MediaServiceCandidate {
        guard let savedLoginAvailable else { return candidate }
        return MediaServiceCandidate(id: candidate.id, name: candidate.name, hint: candidate.hint, running: candidate.running,
            endpoints: candidate.endpoints.map(\.url), savedLoginEndpoints: candidate.endpoints.map(\.url).filter { savedLoginAvailable(candidate.id, $0) })
    }
    var revision: String {
        inventory.rawValue + candidates.map { candidate in
            candidate.id + candidate.hint.rawValue + String(describing: candidate.running) + candidate.endpoints.map { $0.url.absoluteString + (candidate.savedLoginEndpoints.contains($0) ? "|saved" : "") }.joined()
        }.joined(separator: "|")
    }
}

@MainActor private final class MediaServicesModel: ObservableObject {
    @Published var results = MediaServiceResults()
    @Published var checking = false
    @Published var candidates: [MediaServiceCandidate] = []
    private var task: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    func refresh(_ context: NetworkMediaServicesContext) {
        stop(); let round = results.begin(); checking = true
        let candidates = context.candidates.map { context.resolveLogin($0) }
        self.candidates = candidates
        let transport = context.transport
        task = Task { [weak self] in
            await withTaskGroup(of: (String, MediaServiceObservation?).self) { group in
                var next = 0
                func enqueue(_ candidate: MediaServiceCandidate) {
                    group.addTask {
                        do { return (candidate.id, try await MediaServiceProbe(transport: transport).inspect(candidate)) }
                        catch { return (candidate.id, nil) }
                    }
                }
                for _ in 0..<min(3, candidates.count) { enqueue(candidates[next]); next += 1 }
                for await (id, observation) in group {
                    guard !Task.isCancelled else { group.cancelAll(); break }
                    if let observation { self?.results.accept(observation, id: id, round: round) }
                    if next < candidates.count { enqueue(candidates[next]); next += 1 }
                }
            }
            guard !Task.isCancelled else { return }
            self?.checking = false; self?.deadline?.cancel(); self?.deadline = nil; self?.task = nil
        }
        deadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 12_000_000_000) } catch { return }
            self?.stop()
        }
    }
    func stop() { task?.cancel(); task = nil; deadline?.cancel(); deadline = nil; results.stop(); checking = false }
    deinit { task?.cancel(); deadline?.cancel() }
}

struct NetworkMediaServicesSection: View {
    let context: NetworkMediaServicesContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = MediaServicesModel()
    @State private var resolved: NetworkMediaServicesContext?
    @State private var reloadID = UUID()
    @State private var loadingInventory = false
    @State private var forceInventory = false
    private var effective: NetworkMediaServicesContext { resolved ?? context }
    var body: some View {
        NetworkContentSection(title: "媒体服务") {
            #if os(tvOS)
            HStack(alignment: .top, spacing: 24) { productRows(music: false); productRows(music: true) }
            #else
            productRows(music: false)
            productRows(music: true)
            #endif
            if loadingInventory { ProgressView("正在更新服务清单") }
            else if model.checking { ProgressView("正在确认服务身份") }
            Button("刷新服务清单") { forceInventory = true; reloadID = UUID() }.disabled(model.checking || loadingInventory)
                .accessibilityIdentifier("network.service.refresh")
            Text("未发现不代表未安装；各服务使用自己的连接授权。")
                .font(NetworkType.caption).foregroundStyle(.secondary)

        }
            .task(id: context.revision + reloadID.uuidString + String(describing: scenePhase)) {
                guard scenePhase == .active else { model.stop(); return }
                resolved = nil
                if forceInventory || context.inventory == .unavailable, let reload = context.reloadInventory {
                    loadingInventory = true
                    let next = await reload()
                    guard !Task.isCancelled else { loadingInventory = false; return }
                    resolved = next; loadingInventory = false; forceInventory = false
                }
                model.refresh(effective)
            }
            .onDisappear { model.stop() }
            .onChange(of: scenePhase) { phase in if phase != .active { model.stop() } }
    }
    private func productRows(music: Bool) -> some View {
        NetworkGroupedRows {
            Text(music ? "音乐" : "影视").font(NetworkType.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 12)
            ForEach(MediaServiceProduct.allCases.filter { $0.isMusic == music }, id: \.self) { product in
                let candidates = model.candidates.filter { $0.hint == product }
                NavigationLink {
                    NetworkServiceProductView(product: product, candidates: candidates, results: model.results.values, context: effective)
                } label: {
                    NetworkActionLabel(title: product.title, symbol: product.isMusic ? "music.note" : "play.rectangle.fill",
                        subtitle: productSummary(product, candidates: candidates))
                }.accessibilityIdentifier("network.service.product." + product.rawValue)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func productSummary(_ product: MediaServiceProduct, candidates: [MediaServiceCandidate]) -> String {
    if candidates.contains(where: \.hasSavedLogin) { return networkL("已有保存的连接") }
    if !candidates.isEmpty { return networkL("已发现服务线索") + (product == .jellyfin ? "" : networkL(" · 原生接入待完成")) }
    return networkL("尚未发现") + (product == .jellyfin ? networkL(" · 可从影音媒体库连接") : networkL(" · 原生接入待完成"))
}

private struct NetworkServiceProductView: View {
    let product: MediaServiceProduct
    let candidates: [MediaServiceCandidate]
    let results: [String: MediaServiceObservation]
    let context: NetworkMediaServicesContext
    var body: some View {
        NetworkContentPage(title: product.title) {
            if candidates.isEmpty {
                NetworkContentSection(title: "连接状态") {
                    Text("本轮尚未发现此服务。未广播或隐藏的服务仍可能存在。")
                    Text(product == .jellyfin ? "可返回存储与媒体，从影音媒体库添加 Jellyfin 连接。" : "此版本尚未接入该服务的独立授权、媒体库浏览与播放。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                }
            } else {
                NetworkContentSection(title: "连接与发现") {
                    NetworkGroupedRows {
                        ForEach(candidates.sorted { $0.hasSavedLogin && !$1.hasSavedLogin }) { candidate in
                            NavigationLink {
                                NetworkMediaServiceDetail(candidate: candidate, observation: results[candidate.id] ?? .init(reachability: .notChecked), context: context)
                            } label: {
                                NetworkActionLabel(title: candidate.hasSavedLogin ? "已保存的连接" : candidate.name,
                                    symbol: candidate.hasSavedLogin ? "checkmark.circle" : "network",
                                    subtitle: serviceStatus(candidate, results[candidate.id] ?? .init(reachability: .notChecked)))
                            }.accessibilityIdentifier("network.service.row")
                        }
                    }
                    if candidates.count > 1 {
                        Text("发现线索与已保存连接分别保留，确认同一服务器前不会自动合并账号。")
                            .font(NetworkType.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private func serviceStatus(_ candidate: MediaServiceCandidate, _ value: MediaServiceObservation) -> String {
    if value.conflicts(with: candidate) { return networkL("服务类型与清单线索不同，请核对") }
    if value.identity != nil { return candidate.hasSavedLogin ? networkL("已识别 · 已保存登录，进入时验证") : networkL("已识别 · 首次连接需单独授权") }
    if candidate.running == false { return networkL("清单显示未运行 · 尚未检查接口") }
    if candidate.endpoints.isEmpty { return networkL("已发现线索 · 访问入口尚未确认") }
    switch value.reachability {
    case .notChecked: return candidate.hasSavedLogin ? networkL("已保存登录 · 本轮身份尚未确认") : networkL("已发现线索 · 等待确认身份")
    case .reachable: return value.requiresAuthorization ? networkL("接口要求授权 · 产品身份待确认") : networkL("地址可达 · 产品身份待确认")
    case .redirect: return networkL("地址发生跳转 · 尚未确认身份")
    case .unavailable: return networkL("本轮连接未完成 · 保留已有来源")
    case .invalidResponse: return networkL("接口返回无法识别 · 保留已有来源")
    }
}

private struct NetworkMediaServiceDetail: View {
    @State private var candidate: MediaServiceCandidate
    let observation: MediaServiceObservation
    let context: NetworkMediaServicesContext
    @State private var updated: MediaServiceObservation?
    private var value: MediaServiceObservation { updated ?? observation }
    init(candidate: MediaServiceCandidate, observation: MediaServiceObservation, context: NetworkMediaServicesContext) {
        _candidate = State(initialValue: candidate); self.observation = observation; self.context = context
    }
    var body: some View {
        NetworkContentPage(title: value.identity?.product.title ?? candidate.hint.title, subtitle: "媒体服务与连接状态") {
            NetworkContentSection(title: "连接状态") {
                Text(candidate.name)
                Text(serviceStatus(candidate, value)).accessibilityIdentifier("network.service.status")
                Text((value.identity?.product ?? candidate.hint).isMusic ? "音乐服务" : "影视服务")
                if let endpoint = value.endpoint ?? candidate.endpoints.first {
                    #if os(iOS)
                    Text(NetworkConnectionAddress.displayText(for: endpoint.url) ?? "未提供").font(NetworkType.caption).textSelection(.enabled)
                    #else
                    Text(NetworkConnectionAddress.displayText(for: endpoint.url) ?? "未提供").font(NetworkType.caption)
                    #endif
                }
            }
            NetworkContentSection(title: "进入媒体库") {
                if let endpoint = value.nativeEndpoint(for: candidate), let destination = context.nativeDestination(candidate.id, endpoint.url) {
                    NavigationLink { destination } label: { Text(candidate.hasSavedLogin ? "使用已有登录进入媒体库" : "连接此媒体库") }
                        .accessibilityIdentifier("network.service.open")
                    Text("进入后验证此服务的登录状态；不会使用 NAS 密码代替媒体服务授权。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                } else if candidate.hint == .jellyfin {
                    Text("先返回来源页面确认服务身份，再连接媒体库。已有登录和资料仍保留。")
                } else {
                    Text("此服务的原生媒体库浏览与播放尚未接入。识别到服务不代表已经支持播放。")
                    if candidate.hint == .audioStation { Text("还需确认 Audio Station 接口及应用权限，不能直接把 DSM 登录当成音乐服务授权。") }
                    if [.navidrome, .subsonic].contains(candidate.hint) { Text("将按专辑和艺术家展示；不会把音乐库当电影目录处理。") }
                }
            }
        }
            .accessibilityIdentifier("network.service.detail")
            .task {
                candidate = context.resolveLogin(candidate)
                guard observation.identity == nil else { return }
                if let result = try? await MediaServiceProbe(transport: context.transport).inspect(candidate), !Task.isCancelled { updated = result }
            }
    }
}
#endif
