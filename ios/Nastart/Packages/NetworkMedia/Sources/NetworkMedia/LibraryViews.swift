#if os(iOS) || os(tvOS)
import SwiftUI

struct NetworkSavedSource: Identifiable {
    let connection: NetworkStorageConnection?
    let library: NetworkLibrary?
    var id: UUID { connection?.id ?? library!.id }
    var name: String { connection?.name ?? library!.name }
    init(connection: NetworkStorageConnection) { self.connection = connection; library = nil }
    init(library: NetworkLibrary) { self.library = library; connection = nil }
}

@MainActor final class NetworkLibrariesModel: ObservableObject {
    @Published var libraries: [NetworkLibrary] = [] { didSet { fileIndexes.removeAll() } }
    /// Detail views read their file many times per render. A library can hold thousands
    /// of files, and a linear search here starved the main thread during playback.
    private var fileIndexes: [UUID: [DAVPath: RemoteMediaEntry]] = [:]
    func indexedFile(libraryID: UUID, path: DAVPath) -> RemoteMediaEntry? {
        if let index = fileIndexes[libraryID] { return index[path] }
        guard let library = libraries.first(where: { $0.id == libraryID }) else { return nil }
        let index = Dictionary(library.files.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        fileIndexes[libraryID] = index
        return index[path]
    }
    @Published var connections: [NetworkStorageConnection] = []
    @Published private(set) var catalogs: [UUID: [MediaCatalogItem]] = [:]
    @Published var error: String?
    @Published var scanning: UUID?
    @Published var discovered = 0
    /// Off until the user turns it on and saves a credential. Nothing reaches TMDB before that.
    @Published var tmdbEnabled = UserDefaults.standard.bool(forKey: TMDBPreference.enabledKey) {
        didSet { UserDefaults.standard.set(tmdbEnabled, forKey: TMDBPreference.enabledKey) }
    }
    func tmdbMatch(_ lookup: TMDBLookup?) async -> TMDBMatch? {
        guard tmdbEnabled, let lookup else { return nil }
        return try? await TMDBService.shared.match(lookup)
    }
    func tmdbImage(_ path: String?, size: TMDBService.ImageSize) async -> Data? {
        guard tmdbEnabled, let path else { return nil }
        return try? await TMDBService.shared.image(path: path, size: size)
    }
    var nas: NetworkNASContext?
    var playback: ((NetworkMediaPlaybackSource, @escaping () -> Void) -> AnyView)?
    var resumeSeconds: ((String) -> Double?)?
    @Published var credits: NetworkMediaCreditsContext?
    let store = NetworkLibraryStore.shared
    private var scanTask: Task<Void, Never>?
    var canCancelScan: Bool { scanTask != nil }
    private let catalogCache = MediaCatalogCache()
    @Published private(set) var localRead = LibraryLocalReadState()
    var displayError: String? { error ?? localRead.failureMessage }
    var savedWebDAVConnections: [NetworkSavedSource] {
        var seen = Set<String>()
        let legacy = libraries.filter { library in
            guard library.fileStationAccount == nil, library.connectionID == nil else { return false }
            let account = (try? NetworkCredentialVault.load(library))?.username
            let key = account.map { library.address + "\u{0}" + $0 } ?? library.id.uuidString
            return seen.insert(key).inserted
        }
        return connections.map(NetworkSavedSource.init(connection:)) + legacy.map(NetworkSavedSource.init(library:))
    }
    func folderBrowser(for library: NetworkLibrary, path: String) throws -> (source: any ReadOnlyDirectorySource, path: DAVPath) {
        let location = try library.folderBrowsingLocation(path: path)
        if library.fileStationAccount != nil {
            guard let nas else { throw NetworkMediaError.fileStationUnavailable }
            return (try nas.source(for: library), location.path)
        }
        return (try networkStorageSource(scope: location.scope, credential: try NetworkCredentialVault.load(library)), location.path)
    }
    func refresh() async {
        let ticket = localRead.begin()
        // Early cancellation settles only this read, never a newer request.
        defer { localRead.cancel(ticket) }
        do {
            let libraries = try await store.libraries()
            guard localRead.isCurrent(ticket), !Task.isCancelled else { return }
            self.libraries = libraries
            let savedConnections = try await store.connections()
            guard localRead.isCurrent(ticket), !Task.isCancelled else { return }
            self.connections = savedConnections
            try await adoptLegacyConnections(libraries)
            guard localRead.isCurrent(ticket), !Task.isCancelled else { return }
            let current = try await store.libraries()
            guard localRead.isCurrent(ticket), !Task.isCancelled else { return }
            let connections = try await store.connections()
            guard localRead.isCurrent(ticket), !Task.isCancelled else { return }
            let catalogs = try await catalogCache.catalogs(for: current)
            guard localRead.isCurrent(ticket), !Task.isCancelled else { return }
            self.catalogs = catalogs
            self.libraries = current; self.connections = connections
            localRead.succeed(ticket)
        }
        catch is CancellationError { }
        catch {
            guard !Task.isCancelled else { return }
            // This path reads client storage, so do not suggest editing a NAS address.
            localRead.fail(ticket, message: networkL("本机媒体资料暂时无法读取，请重试。"))
        }
    }
    private func adoptLegacyConnections(_ expected: [NetworkLibrary]) async throws {
        let legacy = expected.filter { $0.fileStationAccount == nil && $0.connectionID == nil }
        guard !legacy.isEmpty else { return }
        var additions: [NetworkStorageConnection] = [], assignments: [UUID: UUID] = [:]
        var groups: [(address: String, credential: WebDAVCredential, connection: NetworkStorageConnection)] = []
        do {
            for library in legacy {
                // A locked/missing legacy credential keeps its original working entry.
                guard let credential = try? NetworkCredentialVault.load(library) else { continue }
                let connection: NetworkStorageConnection
                if let group = groups.first(where: { $0.address == library.address && $0.credential.username == credential.username && $0.credential.password == credential.password }) {
                    connection = group.connection
                } else {
                    connection = NetworkStorageConnection(name: library.name, scope: try WebDAVScope(storageAddress: library.address))
                    try NetworkCredentialVault.save(credential, connection: connection)
                    additions.append(connection); groups.append((library.address, credential, connection))
                }
                assignments[library.id] = connection.id
            }
            guard !additions.isEmpty else { return }
            try await store.adoptConnections(expected: expected, connections: additions, assignments: assignments)
        } catch {
            for connection in additions { NetworkCredentialVault.remove(connection.id) }
            throw error
        }
    }
    func add(name: String, scope: WebDAVScope, root: DAVPath, credential: WebDAVCredential) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let connection = NetworkStorageConnection(name: name.isEmpty ? networkDefaultConnectionName(scope) : name, scope: scope)
        let library = NetworkLibrary(name: name.isEmpty ? networkL("我的媒体库") : name, scope: scope, root: root, connectionID: connection.id)
        do {
            try NetworkCredentialVault.save(credential, connection: connection)
            try NetworkCredentialVault.save(credential, library: library)
            try await store.addConnection(connection, library: library)
        } catch { NetworkCredentialVault.remove(connection.id); NetworkCredentialVault.remove(library.id); throw error }
        await refresh()
        scan(library)
    }
    func saveConnection(name: String, scope: WebDAVScope, credential: WebDAVCredential) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let connection = NetworkStorageConnection(name: name.isEmpty ? networkDefaultConnectionName(scope) : name, scope: scope)
        do {
            try NetworkCredentialVault.save(credential, connection: connection)
            try await store.addConnection(connection)
        } catch { NetworkCredentialVault.remove(connection.id); throw error }
        await refresh()
    }
    func addFolder(connection: NetworkStorageConnection, name: String, path: DAVPath) async throws {
        let template = try connection.credentialLibrary().replacingFolder(with: "/" + path.displayPath)
        let library = NetworkLibrary(name: name.isEmpty ? (path.name.isEmpty ? networkL("我的媒体库") : path.name) : name, scope: try WebDAVScope(storageAddress: template.address), root: template.root, connectionID: connection.id)
        try NetworkCredentialVault.save(NetworkCredentialVault.load(connection), library: library)
        do { try await store.add(library) }
        catch { NetworkCredentialVault.remove(library.id); throw error }
        await refresh(); scan(library)
    }
    func editConnection(_ original: NetworkStorageConnection, name: String, scope: WebDAVScope, credential: WebDAVCredential) async throws {
        guard scanning == nil else { throw NetworkMediaError.localStore }
        let oldCredential = try NetworkCredentialVault.load(original)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = name.isEmpty ? networkDefaultConnectionName(scope) : name
        if scope.isSameAddress(as: original.address) && credential.username == oldCredential.username && credential.password == oldCredential.password {
            try await store.renameConnection(original, name: cleanName); await refresh(); return
        }
        let replacement = NetworkStorageConnection(name: cleanName, scope: scope)
        let folders = try libraries.filter { $0.connectionID == original.id }.map { (original: $0, replacement: try replacement.replacement(for: $0)) }
        var stagedCredentials: [UUID] = []
        scanning = original.id; discovered = 0
        defer { scanning = nil }
        do {
            try NetworkCredentialVault.save(credential, connection: replacement); stagedCredentials.append(replacement.id)
            for folder in folders { try NetworkCredentialVault.save(credential, library: folder.replacement); stagedCredentials.append(folder.replacement.id) }
            _ = try await networkStorageSource(scope: scope, credential: credential).list(try DAVPath())
            try Task.checkCancellation()
            try await store.replaceConnection(original, replacement: replacement, folders: folders,
                preservingCorrections: credential.username == oldCredential.username,
                source: { try networkStorageSource(scope: try WebDAVScope(storageAddress: $0.address), credential: credential) }) { [weak self] count in await self?.setProgress(count) }
        } catch {
            for id in stagedCredentials { NetworkCredentialVault.remove(id) }
            throw error
        }
        NetworkCredentialVault.remove(original.id)
        for folder in folders { NetworkCredentialVault.remove(folder.original.id); await LocalArtworkCache.shared.remove(folder.original.id) }
        await refresh()
    }
    func addNAS(name: String, root: DAVPath) async throws {
        guard let nas, !root.encodedSegments.isEmpty else { throw NetworkMediaError.fileStationUnavailable }
        _ = try nas.makeSource()
        let library = NetworkLibrary(name: name.isEmpty ? root.name : name, scope: try WebDAVScope(storageAddress: nas.address), root: root, fileStationAccount: nas.account)
        try await store.add(library)
        await refresh(); scan(library)
    }
    func scan(_ library: NetworkLibrary) {
        guard scanning == nil else { return }
        error = nil; scanning = library.id; discovered = 0
        let store = store
        scanTask = Task { [weak self] in
            defer { self?.scanning = nil; self?.scanTask = nil }
            do {
                let client: any ReadOnlyDirectorySource
                if library.fileStationAccount != nil {
                    guard let nas = self?.nas else { throw NetworkMediaError.fileStationUnavailable }
                    client = try nas.source(for: library)
                } else {
                    client = try networkStorageSource(scope: try WebDAVScope(storageAddress: library.address), credential: try NetworkCredentialVault.load(library))
                }
                try await store.scan(library, source: client) { [weak self] count in
                    await self?.setProgress(count)
                }
                await self?.refresh()
            } catch is CancellationError { }
            catch {
                // Only a library that has something to keep can say it was kept.
                let kept = self?.libraries.first { $0.id == library.id }?.files.isEmpty == false
                self?.error = networkMessage(error) + (kept ? " " + networkL("上次的整理结果已保留。") : "")
            }
        }
    }
    private func setProgress(_ count: Int) { discovered = count }
    func cancel() { scanTask?.cancel() }
    func relocate(_ library: NetworkLibrary, path: String) async throws {
        guard scanning == nil else { throw NetworkMediaError.localStore }
        guard let replacement = try library.replacementForFolderEdit(path) else { return }
        guard try WebDAVScope(storageAddress: library.address).sameOrigin(WebDAVScope(storageAddress: replacement.address).baseURL) else { throw NetworkMediaError.outsideRoot }
        // A new local identity lets Keychain and the atomic index commit remain
        // crash-safe: old credentials are removed only after the new index exists.
        if library.fileStationAccount == nil {
            try NetworkCredentialVault.save(NetworkCredentialVault.load(library), library: replacement)
        }
        error = nil; scanning = library.id; discovered = 0
        defer { scanning = nil }
        do {
            try await store.relocate(library, replacement: replacement, source: source(for: replacement)) { [weak self] count in
                await self?.setProgress(count)
            }
        } catch {
            if library.fileStationAccount == nil { NetworkCredentialVault.remove(replacement.id) }
            throw error
        }
        if library.fileStationAccount == nil { NetworkCredentialVault.remove(library.id) }
        await LocalArtworkCache.shared.remove(library.id)
        await refresh()
    }
    func remove(_ library: NetworkLibrary) async {
        if scanning == library.id { cancel() }
        do {
            try await store.remove(library.id)
            NetworkCredentialVault.remove(library.id)
            await LocalArtworkCache.shared.remove(library.id)
            await refresh()
        } catch { self.error = networkMessage(error) }
    }
    func correct(_ id: UUID, expected: RemoteMediaEntry, values: LocalMediaCorrection.Values) async throws {
        try await store.saveCorrection(id, expected: expected, values: values)
        await refresh()
    }
    func restore(_ id: UUID, path: DAVPath) async throws {
        try await store.restoreIdentification(id, path: path)
        await refresh()
    }
    deinit { scanTask?.cancel() }

    private func source(for library: NetworkLibrary) throws -> any ReadOnlyDirectorySource {
        if library.fileStationAccount != nil {
            guard let nas else { throw NetworkMediaError.fileStationUnavailable }
            return try nas.source(for: library)
        }
        return try networkStorageSource(scope: try WebDAVScope(storageAddress: library.address), credential: try NetworkCredentialVault.load(library))
    }
    func artwork(library: NetworkLibrary, file: RemoteMediaEntry) async throws -> Data {
        guard let reader = try source(for: library) as? any ReadOnlyArtworkSource else { throw NetworkMediaError.invalidArtwork }
        return try await LocalArtworkCache.shared.data(library: library, file: file, source: reader)
    }
    func artwork(library: NetworkLibrary, series: LocalSeriesMetadata) async throws -> Data {
        guard let reader = try source(for: library) as? any ReadOnlyArtworkSource else { throw NetworkMediaError.invalidArtwork }
        return try await LocalArtworkCache.shared.seriesData(library: library, info: series, source: reader)
    }
    func detailMetadata(library: NetworkLibrary, file: RemoteMediaEntry) async throws -> LocalMediaMetadata? {
        guard let reader = try source(for: library) as? any ReadOnlyMetadataSource else { return nil }
        return try await LocalMediaDetailReader.load(file: file, root: library.root, source: reader)
    }
    func backdrop(library: NetworkLibrary, file: RemoteMediaEntry) async throws -> Data? {
        guard file.path != library.root, file.path.isWithin(library.root),
              let parent = file.path.parent, parent.isWithin(library.root),
              let reader = try source(for: library) as? any ReadOnlyArtworkSource else { throw NetworkMediaError.invalidArtwork }
        let siblings = try await reader.list(parent)
        try Task.checkCancellation()
        guard siblings.contains(where: { $0.path == file.path && $0.isVideo }),
              let reference = LocalArtworkSelection(siblings: siblings).backdropCandidate(video: file) else { return nil }
        return try await LocalArtworkCache.shared.backdropData(library: library, file: file, reference: reference, source: reader)
    }
}

private func networkMessage(_ error: Error) -> String {
    // Never render the endpoint-bearing system error description.
    if let error = error as? NetworkMediaError { return error.errorDescription ?? networkL("连接未完成。") }
    if let error = error as? FTPReadError { return error.errorDescription ?? networkL("连接未完成。") }
    if let error = error as? SMBReadError { return error.errorDescription ?? networkL("连接未完成。") }
    if error is FTPListingError { return networkL("FTP 目录内容无法识别。") }
    if let error = error as? WebDAVConnectionFields.FieldError { return error.errorDescription ?? networkL("请检查连接信息。") }
    if let error = error as? URLError {
        switch error.code {
        case .appTransportSecurityRequiresSecureConnection: return networkL("系统阻止了此 HTTP 连接，请使用 HTTPS 或更新支持手动 HTTP 地址的客户端。")
        case .timedOut: return networkL("连接超时，请检查协议、端口及当前网络是否可达。")
        case .cannotFindHost, .dnsLookupFailed: return networkL("无法解析域名，请检查地址和当前网络的 DNS。")
        case .cannotConnectToHost: return networkL("无法连接服务器，请核对 WebDAV 端口和服务是否开放。")
        case .notConnectedToInternet, .networkConnectionLost: return networkL("网络不可用或连接已中断，请检查网络后重试。")
        case .secureConnectionFailed: return networkL("HTTPS 握手未完成，请检查协议和端口是否匹配。")
        case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid: return networkL("HTTPS 证书未通过系统校验，请核对证书、有效期和连接域名。")
        case .userAuthenticationRequired, .userCancelledAuthentication: return networkL("服务器未接受本次登录，请检查 WebDAV 授权、账号和目录读取权限。")
        default: return networkL("连接未完成（网络错误 \(error.code.rawValue)）。")
        }
    }
    return networkL("连接未完成，请检查网络和地址后重试。")
}

/// Keep property-wrapper storage inside this module across older SwiftUI runtimes.
/// Hosted in the app's existing navigation stack on iPhone, iPad and Apple TV.
@MainActor public func networkMediaLibraryView(nas: NetworkNASContext? = nil, appearance: NetworkMediaAppearance? = nil, services: NetworkMediaServicesContext? = nil, destinations: NetworkMediaDestinations? = nil) -> AnyView {
    AnyView(NetworkMediaLibraryView(nas: nas, services: services, destinations: destinations)
        .environment(\.networkAppearance, appearance ?? .standard))
}

struct NetworkActionLabel: View {
    let title: String
    let symbol: String
    var subtitle: String? = nil
    var semanticText = false
    var showsDisclosure = true
    @Environment(\.networkAppearance) private var appearance
    var body: some View {
        HStack(spacing: 16) {
            #if os(tvOS)
            Image(systemName: symbol).font(.system(size: 30, weight: .medium))
                .foregroundStyle(appearance.accent).frame(width: 64, height: 64)
                .background(appearance.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
            #else
            Image(systemName: symbol).foregroundStyle(appearance.accent).frame(width: 32)
            #endif
            VStack(alignment: .leading, spacing: 8) {
                if semanticText {
                    Text(networkText(title)).fontWeight(.medium).foregroundStyle(Color.primary)
                } else { Text(networkText(title)).fontWeight(.medium) }
                if let subtitle {
                    if semanticText { Text(networkText(subtitle)).font(NetworkType.caption).foregroundStyle(Color.secondary) }
                    else { Text(networkText(subtitle)).font(NetworkType.caption).foregroundStyle(.secondary) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            #if os(tvOS)
            if showsDisclosure {
                Image(systemName: "chevron.right").font(.system(size: 17, weight: .semibold)).foregroundStyle(.secondary)
            }
            #endif
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}

private struct NetworkMediaLibraryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.networkAppearance) private var appearance
    @StateObject private var model = NetworkLibrariesModel()
    let nas: NetworkNASContext?
    let services: NetworkMediaServicesContext?
    let destinations: NetworkMediaDestinations?
    @State private var managing = false
    @State private var adding = false
    @State private var reusing: NetworkSavedSource?
    @State private var removing: NetworkLibrary?

    @State private var localReadRetry: UUID?
    private struct LocalReadRequest: Equatable {
        let contextIdentity: String?
        let retry: UUID?
    }

    private struct SavedMedia: Identifiable {
        let id: String
        let title: String
        let destination: AnyView
    }
    private var savedMedia: [SavedMedia] {
        guard let services else { return [] }
        return services.candidates.compactMap { candidate in
            // Restore only this service's already saved authorization. A NAS
            // hint, installed package or open port does not create a library.
            guard let endpoint = candidate.endpoints.first(where: { candidate.savedLoginEndpoints.contains($0) }),
                  let destination = services.nativeDestination(candidate.id, endpoint.url) else { return nil }
            return SavedMedia(id: candidate.id, title: candidate.hint.title, destination: destination)
        }
    }
    var body: some View {
        let media = savedMedia
        NetworkContentPage(title: "存储与媒体", headerActionTitle: "连接管理", headerActionIdentifier: "network.connections.manage", headerAction: { managing = true }) {
            NetworkLibraryStatusSections(scanID: model.scanning, discovered: model.discovered,
                canCancel: model.canCancelScan, error: model.error, cancel: model.cancel,
                localReadPhase: model.localRead.phase, localReadMessage: model.localRead.failureMessage,
                retryRead: retryLocalRead)
            if let destinations {
                NetworkContentSection {
                    NavigationLink { destinations.files } label: {
                        NetworkActionLabel(title: "浏览文件", symbol: "folder.fill", subtitle: nas?.name ?? "连接 NAS，浏览和播放文件")
                    }.accessibilityIdentifier("network.browse.files")
                }
            }
            let unassigned = model.connections.filter { connection in !model.libraries.contains { $0.connectionID == connection.id } }
            if !model.libraries.isEmpty || !media.isEmpty || !unassigned.isEmpty {
                NetworkContentSection(title: "媒体库") {
                    ForEach(media) { media in
                        NavigationLink { media.destination } label: {
                            NetworkActionLabel(title: media.title, symbol: "play.rectangle.fill", subtitle: "使用已有登录进入媒体库")
                        }.accessibilityIdentifier("network.browse.media")
                    }
                    // A saved connection with no folder has nothing to browse yet, but must not look lost.
                    ForEach(unassigned) { connection in
                        Button { reusing = NetworkSavedSource(connection: connection) } label: {
                            NetworkActionLabel(title: connection.name, symbol: "externaldrive.badge.plus", subtitle: networkL("尚未选择媒体文件夹"))
                        }.accessibilityIdentifier("network.library.unassigned")
                    }
                    ForEach(model.libraries) { library in
                        NavigationLink {
                            NetworkLibraryFilesView(id: library.id, model: model)
                                .environment(\.networkAppearance, appearance)
                        } label: {
                            NetworkActionLabel(title: library.name, symbol: "rectangle.stack.fill",
                                subtitle: library.lastCompletedScan == nil ? networkL("等待首次整理") : networkL("\(library.files.count) 个视频文件"))
                        }.accessibilityIdentifier("network.library.source")
                        .contextMenu {
                            Button("使用此连接添加文件夹") {
                                if let connection = model.connections.first(where: { $0.id == library.connectionID }) { reusing = NetworkSavedSource(connection: connection) }
                                else { reusing = NetworkSavedSource(library: library) }
                            }
                            Button(role: .destructive) { removing = library }
                                label: { Label("移除此媒体库（仅本机）", systemImage: "trash") }
                        }
                    }
                }
            }
            NetworkContentSection {
                Button {
                    adding = true
                } label: {
                    NetworkActionLabel(title: "添加媒体文件夹", symbol: "folder.badge.plus",
                        subtitle: model.libraries.isEmpty ? "选择要整理的文件夹" : nil)
                }.accessibilityIdentifier("network.library.addFolder")
                if model.libraries.isEmpty {
                    Text("只整理你选择的文件夹，原文件保持不变。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("network.library.home")
        .modifier(NetworkLibraryRemovalConfirmation(
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            name: removing?.name ?? "") {
                if let library = removing { Task { await model.remove(library) } }
            })
        #if os(iOS)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
            Button("连接管理") { managing = true }.accessibilityIdentifier("network.connections.manage")
        } }
        #endif
        .task(id: LocalReadRequest(contextIdentity: destinations?.credits?.source.identity, retry: localReadRetry)) {
            guard !Task.isCancelled else { return }
            model.nas = nas; model.playback = destinations?.playback; model.credits = destinations?.credits
            model.resumeSeconds = destinations?.resumeSeconds
            CreditReadDiagnostics.record("context", ["available": String(model.credits != nil)])
            await model.refresh()
        }
        .sheet(isPresented: $managing) { NetworkConnectionsView(model: model, nas: nas, services: services, destinations: destinations) }
        .sheet(isPresented: $adding) { NetworkSourceAddView(model: model) }
        .sheet(item: $reusing) { NetworkExistingConnectionView(model: model, library: $0.library, connection: $0.connection) }
        // Pushing a library hides this page too. The shared model owns scans
        // across that navigation; cancel explicitly, on background, or deinit.
        .onChange(of: scenePhase) { phase in if phase != .active { model.cancel() } }
    }
    private func retryLocalRead() {
        guard model.localRead.phase == .failed || model.localRead.phase == .idle else { return }
        // Reuse the page-owned task: no detached read or source scan.
        localReadRetry = UUID()
    }
}

private struct NetworkLibraryStatusSections: View {
    let scanID: UUID?
    let discovered: Int
    let canCancel: Bool
    let error: String?
    let cancel: () -> Void
    var localReadPhase: LibraryLocalReadState.Phase = .ready
    var localReadMessage: String? = nil
    var retryRead: (() -> Void)? = nil
    var body: some View {
        if let scanID {
            NetworkContentSection {
                NetworkLibraryActivityContent(discovered: discovered, canCancel: canCancel, cancel: cancel)
            }.id(scanID)
        }
        if let error {
            NetworkContentSection { NetworkLibraryNoticeContent(message: error) }
        }
        if let retryRead, localReadPhase != .ready {
            NetworkContentSection {
                NetworkLibraryLocalReadContent(phase: localReadPhase, message: localReadMessage, retry: retryRead)
            }
        }
    }
}

private struct NetworkLibraryLocalReadContent: View {
    let phase: LibraryLocalReadState.Phase
    let message: String?
    let retry: () -> Void
    var identifierPrefix = "network.library.home.read"
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if phase == .loading {
                ProgressView("正在读取本机媒体资料")
                    .accessibilityIdentifier(identifierPrefix + ".loading")
            } else if phase == .failed {
                NetworkLibraryNoticeContent(message: message ?? networkL("本机媒体资料暂时无法读取，请重试。"),
                    title: "暂时无法读取本机资料", identifier: identifierPrefix + ".error")
            } else {
                NetworkLibraryStatusHeading(title: "本机资料尚未读取完成")
            }
            Text("已读取的媒体库会保留。重新读取本机资料不会重新扫描网络文件夹。")
                .font(NetworkType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if phase != .loading {
                NetworkReadPageActions(retry: retry, retryIdentifier: identifierPrefix + ".retry")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
        #if os(tvOS)
        .font(.system(size: 28))
        #else
        .font(.body)
        #endif
    }
}

/// Content is independent of List sections so the storage home and poster wall
/// use the same text, controls and typography.
struct NetworkLibraryActivityContent: View {
    let discovered: Int
    let canCancel: Bool
    var cancelIdentifier = "network.library.cancel"
    let cancel: () -> Void
    @Environment(\.networkAppearance) private var appearance
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NetworkLibraryStatusHeading(title: canCancel ? "正在整理" : "正在更新资料")
            // Some updates (connection edits) never report a count; "0 found" would read as a failure.
            ProgressView(discovered > 0 ? "已发现 \(discovered) 个视频文件" : "正在读取文件夹")
                .accessibilityIdentifier("network.library.progress")
            if canCancel {
                Button(action: cancel) {
                    Label {
                        Text("取消扫描").foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: "stop.circle").foregroundStyle(appearance.accent)
                    }
                }.accessibilityIdentifier(cancelIdentifier)
                #if os(tvOS)
                .buttonStyle(NetworkTVCompactStyle())
                #else
                .buttonStyle(.borderless)
                #endif
                Text("完整结束后更新资料；取消或失败会保留上次结果。")
                    .font(NetworkType.caption).foregroundStyle(.secondary)
            } else {
                Text("更新操作可在编辑页面取消。")
                    .font(NetworkType.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
        #if os(tvOS)
        .font(.system(size: 28))
        #else
        .font(.body)
        #endif
    }
}

struct NetworkLibraryNoticeContent: View {
    let message: String
    var title = networkL("操作提示")
    var identifier = "network.library.error"
    @Environment(\.networkAppearance) private var appearance
    var body: some View {
        MediaLibraryNotice(title: Text(networkText(title)), message: Text(message), accent: appearance.accent,
            messageIdentifier: identifier)
    }
}

private struct NetworkLibraryStatusHeading: View {
    let title: String
    var body: some View {
        Text(networkText(title)).foregroundStyle(Color.primary)
            #if os(tvOS)
            .font(.system(size: 28, weight: .semibold))
            #else
            .font(.headline)
            #endif
            .accessibilityAddTraits(.isHeader)
    }
}

struct NetworkLibraryWallStatus: View {
    let scanID: UUID?
    let discovered: Int
    let canCancel: Bool
    let error: String?
    let cancel: () -> Void
    var localReadPhase: LibraryLocalReadState.Phase = .ready
    var localReadMessage: String? = nil
    var retryRead: (() -> Void)? = nil
    @Environment(\.networkAppearance) private var appearance
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let scanID {
                panel {
                    NetworkLibraryActivityContent(discovered: discovered, canCancel: canCancel,
                        cancelIdentifier: "network.library.cancel.inline", cancel: cancel)
                }.id(scanID)
            }
            if let error { panel { NetworkLibraryNoticeContent(message: error) } }
            if let retryRead, localReadPhase != .ready {
                panel {
                    NetworkLibraryLocalReadContent(phase: localReadPhase, message: localReadMessage,
                        retry: retryRead, identifierPrefix: "network.library.wall.read")
                }
            }
        }
    }
    private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().padding(16).background { appearance.surface }
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

#if DEBUG
struct OfflineWallStatusScene: View {
    let configuration: OfflineUIConfiguration
    private var notice: Bool { configuration.scenario == .wallNotice }
    private var scanning: Bool {
        [.wallScanning, .wallUpdating, .wallReadScanning].contains(configuration.scenario)
    }
    private var cancellable: Bool {
        [.wallScanning, .wallReadScanning].contains(configuration.scenario)
    }
    private var readPhase: LibraryLocalReadState.Phase {
        switch configuration.scenario {
        case .wallReadLoading: .loading
        case .wallReadIdle: .idle
        case .wallReadError, .wallReadCombined, .wallReadScanning: .failed
        default: .ready
        }
    }
    private var operationMessage: String? {
        if notice { return "连接超时，请检查协议、端口及当前网络是否可达。" }
        if configuration.scenario == .wallReadCombined { return "连接超时。上次的整理结果已保留。" }
        return nil
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                #if os(tvOS)
                MediaLibraryHeading(title: "合成媒体库", subtitle: "")
                #endif
                if scanning || operationMessage != nil || readPhase != .ready {
                    NetworkLibraryWallStatus(scanID: scanning ? UUID(uuidString: "00000000-0000-0000-0000-000000000001")! : nil,
                        discovered: cancellable ? 149 : 0, canCancel: cancellable,
                        error: operationMessage, cancel: {}, localReadPhase: readPhase,
                        localReadMessage: readPhase == .failed ? "本机媒体资料暂时无法读取，请重试。" : nil,
                        retryRead: {})
                }
                Text("合成海报区").font(NetworkType.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: 1500, alignment: .leading).padding(24).frame(maxWidth: .infinity)
        }
        #if os(iOS)
        .navigationTitle("合成媒体库").navigationBarTitleDisplayMode(.inline)
        #else
        .navigationTitle("")
        #endif
        .safeAreaInset(edge: .bottom) {
            Text("离线界面测试 · 合成海报墙状态").font(.caption2).dynamicTypeSize(.large)
                .foregroundStyle(.secondary).padding(.vertical, 8)
                .frame(maxWidth: .infinity).background(.background)
        }
    }
}
#endif

#if DEBUG
struct OfflineLibraryStatusScene: View {
    let configuration: OfflineUIConfiguration
    private var notice: Bool { configuration.scenario == .libraryNotice }
    var body: some View {
        NetworkContentPage(title: "存储与媒体") {
            NetworkLibraryStatusSections(scanID: notice ? nil : UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                discovered: configuration.scenario == .libraryScanning ? 149 : 0,
                canCancel: configuration.scenario == .libraryScanning,
                error: notice ? "连接超时，请检查协议、端口及当前网络是否可达。" : nil, cancel: {})
        }
        .safeAreaInset(edge: .bottom) {
            Text("离线界面测试 · 合成整理状态").font(.caption2).dynamicTypeSize(.large)
                .foregroundStyle(.secondary).padding(.vertical, 8)
                .frame(maxWidth: .infinity).background(.background)
        }
    }
}

struct OfflineHomeReadStatusScene: View {
    let configuration: OfflineUIConfiguration
    private var phase: LibraryLocalReadState.Phase {
        switch configuration.scenario {
        case .homeReadLoading: .loading
        case .homeReadIdle: .idle
        case .homeReadReady: .ready
        default: .failed
        }
    }
    var body: some View {
        NetworkContentPage(title: "存储与媒体") {
            NetworkLibraryStatusSections(scanID: nil, discovered: 0, canCancel: false,
                error: configuration.scenario == .homeReadCombined ? "连接超时。上次的整理结果已保留。" : nil,
                cancel: {}, localReadPhase: phase,
                localReadMessage: phase == .failed ? "本机媒体资料暂时无法读取，请重试。" : nil,
                retryRead: {})
            NetworkContentSection(title: "媒体库") {
                NetworkActionLabel(title: "合成媒体库", symbol: "rectangle.stack.fill", subtitle: "149 个视频文件",
                    semanticText: true, showsDisclosure: false)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("离线界面测试 · 合成首页读取状态").font(.caption2).dynamicTypeSize(.large)
                .foregroundStyle(.secondary).padding(.vertical, 8)
                .frame(maxWidth: .infinity).background(.background)
        }
    }
}
#endif

private struct NetworkConnectionsView: View {
    @ObservedObject var model: NetworkLibrariesModel
    let nas: NetworkNASContext?
    let services: NetworkMediaServicesContext?
    let destinations: NetworkMediaDestinations?
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var reusing: NetworkSavedSource?
    @State private var addedFromSheet = false
    @State private var editingFolder: NetworkLibrary?
    @State private var managingConnection: NetworkStorageConnection?
    var body: some View {
        let savedConnections = model.savedWebDAVConnections
        NavigationStack {
            NetworkConnectionsPage(hasStorage: nas != nil || !savedConnections.isEmpty,
                hasFolders: !model.libraries.isEmpty, hasServices: destinations != nil || services != nil,
                add: { adding = true }) {
                    if let nas { Label(nas.name + networkL(" · 当前 NAS 登录配置"), systemImage: "externaldrive.fill") }
                    ForEach(savedConnections) { library in
                        Button { if let connection = library.connection { managingConnection = connection } else { reusing = library } } label: {
                            NetworkStoredConnectionLabel(name: library.name, managesSettings: library.connection != nil, kind: networkStorageKind(library.connection?.address ?? library.library?.address ?? ""))
                        }.accessibilityIdentifier("network.connection.reuse")
                    }
            } folders: {
                ForEach(model.libraries) { library in
                    Button { editingFolder = library } label: {
                        NetworkMediaFolderLabel(name: library.name, path: library.folderPath, source: sourceName(library))
                    }.accessibilityIdentifier("network.connection.editFolder")
                }
            } services: {
                    if let destinations, services?.candidates.contains(where: \.hasSavedLogin) != true {
                        NavigationLink { destinations.media } label: { NetworkActionLabel(title: "连接 Jellyfin", symbol: "play.rectangle", semanticText: true) }
                            .accessibilityIdentifier("network.connection.media")
                    }
                    if let services {
                        NavigationLink {
                            NetworkContentPage(title: "媒体服务") { NetworkMediaServicesSection(context: services) }
                        } label: { NetworkActionLabel(title: "发现与管理媒体服务", symbol: "network", subtitle: "Jellyfin、Emby、Plex 与音乐服务", semanticText: true) }
                            .accessibilityIdentifier("network.services.manage")
                    }
            }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
        }
        .sheet(isPresented: $adding, onDismiss: { if addedFromSheet { dismiss() } }) {
            NetworkSourceAddView(model: model, showsSavedConnections: false, onAdded: { addedFromSheet = true })
        }
        .sheet(item: $reusing, onDismiss: { if addedFromSheet { dismiss() } }) {
            NetworkExistingConnectionView(model: model, library: $0.library, connection: $0.connection, onAdded: { addedFromSheet = true })
        }
        .sheet(item: $managingConnection) { NetworkConnectionDetails(model: model, connection: $0) }
        .sheet(item: $editingFolder) { library in
            NetworkLibraryFolderEditor(library: library, model: model) {}
        }
    }
    private func sourceName(_ library: NetworkLibrary) -> String {
        if let connection = model.connections.first(where: { $0.id == library.connectionID }) {
            return connection.name + " · " + networkStorageKind(connection.address)
        }
        if library.fileStationAccount != nil, let nas, library.fileStationAccount == nas.account,
           (try? WebDAVScope(storageAddress: nas.address).baseURL.absoluteString) == library.address {
            return nas.name
        }
        // A disconnected or legacy source has no matching friendly name.
        // Display only host/port, never userinfo, query or the full address.
        let kind = library.fileStationAccount == nil ? networkStorageKind(library.address) : "NAS"
        if let parts = URLComponents(string: library.address), let host = parts.host {
            return kind + " · " + host + (parts.port.map { ":\($0)" } ?? "")
        }
        return kind
    }

}

private struct NetworkStoredConnectionLabel: View {
    let name: String
    let managesSettings: Bool
    var kind = "WebDAV"
    var body: some View {
        NetworkActionLabel(title: name, symbol: "externaldrive.badge.wifi",
            subtitle: managesSettings ? networkL("\(kind) · 连接设置与媒体文件夹") : networkL("\(kind) · 选择媒体文件夹"), semanticText: true)
    }
}

private struct NetworkMediaFolderLabel: View {
    let name: String
    let path: String
    let source: String
    var body: some View {
        NetworkActionLabel(title: name, symbol: "folder",
            subtitle: source + "\n" + (path.isEmpty ? "/" : path), semanticText: true)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct NetworkConnectionsPage<Storage: View, Folders: View, Services: View>: View {
    let hasStorage: Bool
    let hasFolders: Bool
    let hasServices: Bool
    var note: String?
    let add: () -> Void
    @ViewBuilder let storage: Storage
    @ViewBuilder let folders: Folders
    @ViewBuilder let services: Services
    var body: some View {
        NetworkContentPage(title: "连接管理") {
            NetworkContentSection(title: "存储连接") {
                if !hasStorage {
                    Text("还没有可管理的存储连接，添加后可选择媒体文件夹。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                }
                NetworkGroupedRows {
                    storage
                    Button(action: add) { NetworkActionLabel(title: "添加存储连接", symbol: "plus", semanticText: true) }
                        .accessibilityIdentifier("network.source.add")
                }
            }
            if hasFolders {
                NetworkContentSection(title: "媒体文件夹") { NetworkGroupedRows { folders } }
            }
            if hasServices {
                NetworkContentSection(title: "媒体服务") { NetworkGroupedRows { services } }
            }
            if let note { NetworkContentSection { Text(networkText(note)).font(NetworkType.caption).foregroundStyle(.secondary) } }
        }
    }
}

#if DEBUG
struct OfflineConnectionsScene: View {
    let configuration: OfflineUIConfiguration
    @State private var message = "离线界面测试 · 合成连接管理；不读取或保存连接。"
    private var empty: Bool { configuration.scenario == .connectionsEmpty }
    private var full: Bool { configuration.scenario == .connections }
    var body: some View {
        NetworkConnectionsPage(hasStorage: !empty, hasFolders: full, hasServices: full, note: message,
            add: { message = "仅预览添加入口，未创建连接。" }) {
                if !empty {
                    Button {} label: { NetworkStoredConnectionLabel(name: "客厅 NAS", managesSettings: true) }
                    Button {} label: { NetworkStoredConnectionLabel(name: "合成旧连接", managesSettings: false) }
                }
            } folders: {
                Button {} label: { NetworkMediaFolderLabel(name: "电影", path: "/video/电影 100%", source: "客厅 NAS · WebDAV") }
                Button {} label: { NetworkMediaFolderLabel(name: "电影", path: "/video/电影 100%", source: "书房 NAS · WebDAV") }
            } services: {
                Button {} label: { NetworkActionLabel(title: "发现与管理媒体服务", symbol: "network", subtitle: "合成媒体服务入口", semanticText: true) }
            }
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成连接管理").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
}
#endif

/// The original source remains usable until a complete replacement is committed.
struct NetworkLibraryFolderEditor: View {
    let library: NetworkLibrary
    @ObservedObject var model: NetworkLibrariesModel
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var path: String
    @State private var task: Task<Void, Never>?
    @State private var failure: String?
    @State private var browsing = false
    init(library: NetworkLibrary, model: NetworkLibrariesModel, onSaved: @escaping () -> Void) {
        self.library = library; self.model = model; self.onSaved = onSaved
        _path = State(initialValue: library.folderPath)
    }
    var body: some View {
        NavigationStack {
            NetworkFolderEditorForm(libraryName: library.name, currentPath: library.folderPath, path: $path,
                busy: task != nil, discovered: model.discovered, failure: failure,
                browse: { browsing = true }, cancel: { task?.cancel(); dismiss() }) {
                    guard task == nil else { return }
                    let submittedPath = path
                    failure = nil
                    task = Task { @MainActor in
                        do {
                            try await model.relocate(library, path: submittedPath)
                            task = nil; dismiss(); onSaved()
                        } catch is CancellationError { task = nil }
                        catch { failure = networkMessage(error); task = nil }
                    }
                }
        }.sheet(isPresented: $browsing) {
            NetworkFolderSelectionView(model: model, library: library, path: path) { selected in
                path = "/" + selected.displayPath
            }
        }.onDisappear { task?.cancel() }
            .onChange(of: path) { _ in failure = nil }
            .interactiveDismissDisabled(task != nil)
    }
}

/// Removal deletes this device's index, artwork cache and saved credential, so it is never one tap.
struct NetworkLibraryRemovalConfirmation: ViewModifier {
    @Binding var isPresented: Bool
    let name: String
    let remove: () -> Void
    func body(content: Content) -> some View {
        content.confirmationDialog("移除媒体库“\(name)”？", isPresented: $isPresented, titleVisibility: .visible) {
            Button("移除", role: .destructive, action: remove).accessibilityIdentifier("network.library.remove.confirm")
            Button("取消", role: .cancel) {}
        } message: {
            Text("只删除本机的整理结果、图片缓存和已保存的密码，NAS 上的文件不受影响。")
        }
    }
}

/// The production editor and isolated previews share bindings and action hierarchy.
private struct NetworkFolderEditorForm: View {
    let libraryName: String
    let currentPath: String
    @Binding var path: String
    var busy = false
    var discovered = 0
    var failure: String?
    var note: String?
    let browse: () -> Void
    let cancel: () -> Void
    let save: () -> Void
    @Environment(\.networkAppearance) private var appearance
    private var hasChange: Bool {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        // An invalid draft can still be submitted for the existing field error.
        guard let next = try? DAVPath(path), let original = try? DAVPath(currentPath) else { return true }
        return next != original
    }
    var body: some View {
        NetworkContentPage(title: "修改文件夹") {
            if let failure {
                NetworkContentSection {
                    Label { Text(failure).fixedSize(horizontal: false, vertical: true) }
                        icon: { Image(systemName: "exclamationmark.circle.fill") }
                        .foregroundStyle(.red).accessibilityElement(children: .combine)
                        .accessibilityIdentifier("network.folderEdit.error")
                    Text("原文件夹和媒体库已保留，可以修改路径后重试。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                }
            }
            NetworkContentSection(title: "当前文件夹") {
                Label(libraryName, systemImage: "folder.fill").font(.headline)
                Text(currentPath).font(NetworkType.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("network.folderEdit.currentPath")
            }
            NetworkContentSection(title: "新路径") {
                TextField("例如 /video/media", text: $path).modifier(NetworkInputStyle())
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .disabled(busy).accessibilityLabel("新的媒体文件夹路径")
                    .accessibilityIdentifier("network.folderEdit.path")
                Button(action: browse) { Label("浏览并选择文件夹", systemImage: "folder") }
                    .disabled(busy).accessibilityIdentifier("network.folderEdit.browse")
                    #if os(tvOS)
                    .buttonStyle(NetworkTVCompactStyle())
                    #endif
                Text("仅更新此媒体库的读取路径，不修改 NAS 文件，也不影响其他媒体库。")
                    .font(NetworkType.caption).foregroundStyle(.secondary)
            }
            NetworkContentSection {
                if busy {
                    ProgressView("正在验证 · 已发现 \(discovered) 个视频")
                        .accessibilityIdentifier("network.folderEdit.progress")
                }
                if !busy && !hasChange {
                    Text("选择不同的文件夹后即可保存。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                }
                Text("新文件夹会重新识别影片；失败或取消时保留原媒体库。")
                    .font(NetworkType.caption).foregroundStyle(.secondary)
                #if os(tvOS)
                Button(action: save) { Label(busy ? "正在验证" : "验证并保存", systemImage: "checkmark.circle") }
                    .disabled(busy || !hasChange).accessibilityIdentifier("network.folderEdit.save")
                    .buttonStyle(MediaDetailActionStyle(accent: appearance.accent))
                Button("取消", action: cancel).accessibilityIdentifier("network.folderEdit.cancel")
                    .buttonStyle(NetworkTVCompactStyle())
                #endif
                if let note {
                    Text(networkText(note)).font(NetworkType.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("network.folderEdit.note")
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Same placement as the app's other sheets, and visible without scrolling on iPad.
            ToolbarItem(placement: .cancellationAction) {
                Button("取消", action: cancel).accessibilityIdentifier("network.folderEdit.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(busy ? "正在验证" : "保存", action: save)
                    .disabled(busy || !hasChange).accessibilityIdentifier("network.folderEdit.save")
            }
        }
        .background { appearance.background.ignoresSafeArea() }
        #endif
    }
}

#if DEBUG
/// No library/model/vault/client: callbacks only inspect a synthetic path in memory.
struct OfflineFolderEditorScene: View {
    let configuration: OfflineUIConfiguration
    @State private var path: String
    @State private var failure: String?
    @State private var message: String?
    init(configuration: OfflineUIConfiguration) {
        self.configuration = configuration
        _path = State(initialValue: configuration.scenario == .folderEdit ? "/video/电影 100%" : "/video/剧集")
        _failure = State(initialValue: configuration.scenario == .folderEditError ? "无法读取所选文件夹，请检查路径或访问权限。" : nil)
    }
    var body: some View {
        NetworkFolderEditorForm(libraryName: "家庭影视", currentPath: "/video/电影 100%", path: $path,
            busy: configuration.scenario == .folderEditBusy, discovered: 12, failure: failure, note: message,
            browse: { path = "/video/合成目录" },
            cancel: { failure = nil; message = "已取消离线草稿，原配置未改动。" }) {
                message = nil
                do { _ = try DAVPath(path); failure = nil; message = "仅完成离线路径检查，未验证服务器或保存媒体库。" }
                catch { failure = "路径无效，请检查文件夹名称。" }
            }
            .onChange(of: path) { _ in failure = nil; message = nil }
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成文件夹").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
}
#endif

private struct NetworkFolderSelectionView: View {
    @ObservedObject var model: NetworkLibrariesModel
    let library: NetworkLibrary
    let path: String
    let select: (DAVPath) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var browser: (source: any ReadOnlyDirectorySource, path: DAVPath)?
    @State private var failure: String?
    var body: some View {
        NavigationStack {
            Group {
                if let browser {
                    NetworkFolderPicker(path: browser.path, client: browser.source, rootBack: { dismiss() }, select: { path in
                        select(path); dismiss()
                    }, allowsRoot: library.fileStationAccount == nil, allowsParentNavigation: true,
                       selectionTitle: "使用此文件夹", selectionIdentifier: "network.folderBrowse.select",
                       cancel: { dismiss() }, cancelIdentifier: "network.folderBrowse.cancel")
                } else {
                    NetworkContentPage(title: "选择文件夹") {
                        if let failure { Text(failure).foregroundStyle(.red) }
                        else { ProgressView("正在读取目录") }
                    }
                }
            }.toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }.accessibilityIdentifier("network.folderBrowse.cancel")
            } }
            .task {
                do { browser = try model.folderBrowser(for: library, path: path) }
                catch { failure = networkMessage(error) }
            }
        }
    }
}

private struct NetworkLibraryFilesView: View {
    let id: UUID
    @ObservedObject var model: NetworkLibrariesModel
    @Environment(\.dismiss) private var dismiss
    @State private var retryTask: Task<Void, Never>?
    private var library: NetworkLibrary? { model.libraries.first { $0.id == id } }
    var body: some View {
        ZStack {
            if let library { NetworkLibraryPosterWall(library: library, model: model) }
            else {
                NetworkLibraryAccessStatePage(phase: model.localRead.phase,
                    message: model.localRead.failureMessage, retry: retry, back: back)
            }
        }
        .onDisappear { retryTask?.cancel(); retryTask = nil }
    }
    private func retry() {
        guard retryTask == nil, model.localRead.phase != .loading else { return }
        retryTask = Task { await model.refresh(); retryTask = nil }
    }
    private func back() {
        retryTask?.cancel(); retryTask = nil
        dismiss()
    }
}

/// The saved library is absent. A retained library continues showing its wall.
private struct NetworkLibraryAccessStatePage: View {
    let phase: LibraryLocalReadState.Phase
    let message: String?
    let retry: () -> Void
    let back: () -> Void
    var body: some View {
        NetworkContentPage(title: "媒体库", backAction: back) {
            NetworkContentSection(title: phase == .failed ? nil : title) {
                if phase == .loading {
                    ProgressView("正在读取本机媒体资料")
                        .accessibilityIdentifier("network.library.read.loading")
                } else if phase == .failed, let message {
                    NetworkLibraryNoticeContent(message: message, title: title)
                }
                Text(explanation).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                NetworkReadPageActions(retry: phase == .idle || phase == .failed ? retry : nil,
                    back: back, retryIdentifier: "network.library.read.retry", backIdentifier: "network.library.read.back")
            }
        }
    }
    private var title: String {
        switch phase {
        case .idle: networkL("资料尚未读取完成")
        case .loading: networkL("正在打开媒体库")
        case .ready: networkL("媒体库已变更")
        case .failed: networkL("暂时无法打开媒体库")
        }
    }
    private var explanation: String {
        switch phase {
        case .idle: networkL("可重新读取已保存在此设备的媒体资料，或返回上一页。")
        case .loading: networkL("正在读取此设备已保存的媒体资料，不会重新扫描网络文件夹。")
        case .ready: networkL("此媒体库入口已移除或更新，请返回上一页重新选择。")
        case .failed: networkL("可重试读取本机资料，或返回上一页。此操作不会修改网络存储中的文件。")
        }
    }
}

#if DEBUG
struct OfflineLibraryAccessStateScene: View {
    let configuration: OfflineUIConfiguration
    private var phase: LibraryLocalReadState.Phase {
        switch configuration.scenario {
        case .readLoading: .loading
        case .readError: .failed
        case .readMissing: .ready
        default: .idle
        }
    }
    var body: some View {
        NetworkLibraryAccessStatePage(phase: phase,
            message: phase == .failed ? "本机媒体资料暂时无法读取，请重试。" : nil, retry: {}, back: {})
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成读取状态").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
}
#endif

private struct NetworkMediaFileSummary: View {
    let file: RemoteMediaEntry
    let correction: LocalMediaCorrection?
    private var active: LocalMediaCorrection.Values? { correction?.applies(to: file) == true ? correction?.values : nil }
    var body: some View {
        let raw = file.metadata ?? MediaFilenameParser.identify(file.path)
        VStack(alignment: .leading, spacing: 6) {
            Text(active?.title ?? raw.title)
            Text(active != nil ? "本机修改 · 未验证在线身份" : (raw.origin == .nfo ? "已有 NFO 资料" : "文件名识别 · 待确认"))
                .font(NetworkType.caption).foregroundStyle(.secondary)
            if let correction, active == nil {
                Text("本机修改待复核：\(correction.values.title)").font(NetworkType.caption).foregroundStyle(.secondary)
            }
            if let year = active != nil ? active?.year : raw.year { Text(String(year)).font(NetworkType.caption) }
            if let season = active != nil ? active?.season : raw.season,
               let episode = active != nil ? active?.episode : raw.episode {
                let end = active != nil ? active?.episodeEnd : raw.episodeEnd
                Text("第 \(season) 季 · 第 \(episode)\(end.map { "–\($0)" } ?? "") 集").font(NetworkType.caption)
            }
            if active == nil {
                if raw.notice != nil { Text("资料文件未采用，保留文件名识别结果").font(NetworkType.caption).foregroundStyle(.secondary) }
                if let plot = raw.plot, !plot.isEmpty { Text(plot).font(NetworkType.caption).lineLimit(4) }
            }
            Text(file.path.displayPath).font(NetworkType.caption).foregroundStyle(.secondary)
            if let size = file.size { Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)).font(NetworkType.caption) }
        }
    }
}

struct NetworkMediaCorrectionView: View {
    let id: UUID
    let file: RemoteMediaEntry
    let correction: LocalMediaCorrection?
    @ObservedObject var model: NetworkLibrariesModel
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var year: String
    @State private var kind: LocalMediaMetadata.Kind
    @State private var season: String
    @State private var episode: String
    @State private var episodeEnd: String
    @State private var error: String?
    @State private var saving = false
    init(id: UUID, file: RemoteMediaEntry, correction: LocalMediaCorrection?, model: NetworkLibrariesModel) {
        self.id = id; self.file = file; self.correction = correction; self.model = model
        let raw = file.metadata ?? MediaFilenameParser.identify(file.path)
        _title = State(initialValue: correction?.values.title ?? raw.title)
        _year = State(initialValue: (correction != nil ? correction?.values.year : raw.year).map(String.init) ?? "")
        _kind = State(initialValue: correction?.values.kind ?? raw.kind)
        _season = State(initialValue: (correction != nil ? correction?.values.season : raw.season).map(String.init) ?? "")
        _episode = State(initialValue: (correction != nil ? correction?.values.episode : raw.episode).map(String.init) ?? "")
        _episodeEnd = State(initialValue: (correction != nil ? correction?.values.episodeEnd : raw.episodeEnd).map(String.init) ?? "")
    }
    var body: some View {
        NavigationStack {
            NetworkMediaCorrectionForm(title: $title, year: $year, kind: $kind, season: $season,
                episode: $episode, episodeEnd: $episodeEnd, saving: saving, error: error,
                reviewMessage: reviewMessage, cancel: { if !saving { dismiss() } }, save: save,
                restore: correction == nil ? nil : restore) {
                    NetworkMediaFileSummary(file: file, correction: nil)
                }
                .onChange(of: [title, year, kind.rawValue, season, episode, episodeEnd]) { _ in error = nil }
        }.interactiveDismissDisabled(saving)
    }
    private var reviewMessage: String? {
        if correction != nil && correction?.applies(to: file) != true {
            return networkL("文件版本信息已变化或不足，请核对下方原识别资料后保存。")
        }
        if !LocalMediaCorrection.Fingerprint(file).hasVersionHint {
            return networkL("文件版本信息不足，保存后仍会标记待复核。")
        }
        return nil
    }
    private func number(_ text: String) throws -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        guard value.utf8.allSatisfy({ (48...57).contains($0) }), let number = Int(value) else { throw NetworkMediaError.invalidCorrection }
        return number
    }
    private func save() {
        guard !saving else { return }
        do {
            let values = try LocalMediaCorrection.Values(title: title, year: number(year), kind: kind,
                season: kind == .episode ? number(season) : nil, episode: kind == .episode ? number(episode) : nil,
                episodeEnd: kind == .episode ? number(episodeEnd) : nil)
            saving = true; error = nil
            Task {
                do { try await model.correct(id, expected: file, values: values); dismiss() }
                catch { self.error = networkMessage(error) }
                saving = false
            }
        } catch { self.error = networkMessage(error) }
    }
    private func restore() {
        guard !saving else { return }
        saving = true; error = nil
        Task {
            do { try await model.restore(id, path: file.path); dismiss() }
            catch { self.error = networkMessage(error) }
            saving = false
        }
    }
}


/// Shared production form. The owner alone validates and persists the overlay.
/// Offline previews bind ephemeral strings and never construct a library model.
private struct NetworkMediaCorrectionForm<Original: View>: View {
    @Binding var title: String
    @Binding var year: String
    @Binding var kind: LocalMediaMetadata.Kind
    @Binding var season: String
    @Binding var episode: String
    @Binding var episodeEnd: String
    var saving = false
    var error: String?
    var reviewMessage: String?
    var note: String?
    let cancel: () -> Void
    let save: () -> Void
    let restore: (() -> Void)?
    @ViewBuilder let original: Original
    @Environment(\.networkAppearance) private var appearance
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.dynamicTypeSize) private var typeSize
    private enum Field: Hashable { case title, year, kind, season, episode, end, save }
    @FocusState private var field: Field?
    private var columns: Bool {
        #if os(tvOS)
        true
        #else
        widthClass == .regular && !typeSize.isAccessibilitySize
        #endif
    }
    var body: some View {
        NetworkContentPage(title: "修改本机资料", backAction: { if !saving { cancel() } }) {
            if let error {
                NetworkContentSection {
                    Label { Text(error).fixedSize(horizontal: false, vertical: true) }
                        icon: { Image(systemName: "exclamationmark.circle.fill") }
                        .foregroundStyle(.red).accessibilityElement(children: .combine)
                        .accessibilityIdentifier("network.correction.error")
                    Text("填写内容已保留，可以修改后重试。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                }
            }
            if saving {
                NetworkContentSection {
                    ProgressView("正在更新本机资料")
                        .accessibilityIdentifier("network.correction.progress")
                }
            }
            NetworkContentSection(title: "影片资料") {
                inputRow("片名") {
                    TextField("填写片名或剧名", text: $title)
                        .accessibilityLabel("片名").accessibilityIdentifier("network.correction.title")
                        .focused($field, equals: .title).submitLabel(.next).onSubmit { field = .year }
                }
                if columns {
                    HStack(alignment: .top, spacing: 24) { yearInput; kindInput }
                } else { yearInput; kindInput }
            }.disabled(saving)
            if kind == .episode {
                NetworkContentSection(title: "季与集") {
                    if columns {
                        HStack(alignment: .top, spacing: 24) { seasonInput; episodeInput; endInput }
                    } else { seasonInput; episodeInput; endInput }
                    Text("季数为 0–9999，特辑填 0；集数为 0–99999，单集的结束集可留空。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                }.disabled(saving)
            }
            NetworkContentSection(title: "本机操作") {
                Text("只修改本机媒体库中的显示资料，不改名、不移动 NAS 文件，也不写入资料文件。")
                    .font(NetworkType.caption).foregroundStyle(.secondary)
                if let reviewMessage {
                    Label { Text(reviewMessage).foregroundStyle(.secondary) }
                        icon: { Image(systemName: "info.circle").foregroundStyle(appearance.accent) }
                        .font(NetworkType.caption).fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                }
                Button { field = nil; save() } label: {
                    Label(saving ? "正在更新" : "保存本机修改", systemImage: "checkmark.circle")
                }.buttonStyle(MediaDetailActionStyle(accent: appearance.accent))
                    .accessibilityIdentifier("network.correction.save").focused($field, equals: .save)
                    .disabled(saving)
                if let restore {
                    Button { field = nil; restore() } label: {
                        Label("恢复原识别结果", systemImage: "arrow.uturn.backward")
                    }.accessibilityIdentifier("network.correction.restore").disabled(saving)
                        #if os(tvOS)
                        .buttonStyle(NetworkTVCompactStyle())
                        #else
                        .buttonStyle(.borderless)
                        #endif
                }
                if let note { Text(networkText(note)).font(NetworkType.caption).foregroundStyle(.secondary) }
            }
            NetworkContentSection(title: "原识别资料（保留）") { original }
        }
        .toolbar { ToolbarItem(placement: .cancellationAction) {
            Button("取消", action: cancel).disabled(saving).accessibilityIdentifier("network.correction.cancel")
        } }
        #if os(iOS)
        .background { appearance.background.ignoresSafeArea() }
        #endif
    }
    private var yearInput: some View {
        inputRow("年份") {
            TextField("可留空，1000–2999", text: $year).keyboardType(.numbersAndPunctuation)
                .accessibilityLabel("年份，可留空").accessibilityIdentifier("network.correction.year")
                .focused($field, equals: .year).submitLabel(.next).onSubmit { field = .kind }
        }
    }
    private var kindInput: some View {
        inputRow("类型") {
            Picker("类型", selection: $kind) {
                Text("未分类").tag(LocalMediaMetadata.Kind.unknown)
                Text("电影").tag(LocalMediaMetadata.Kind.movie)
                Text("剧集").tag(LocalMediaMetadata.Kind.episode)
            }.labelsHidden().accessibilityIdentifier("network.correction.kind").focused($field, equals: .kind)
                #if os(iOS)
                .pickerStyle(.menu)
                #endif
        }
    }
    private var seasonInput: some View {
        inputRow("季数") {
            TextField("特辑填 0", text: $season).keyboardType(.numbersAndPunctuation)
                .accessibilityLabel("季数，特辑填零").accessibilityIdentifier("network.correction.season")
                .focused($field, equals: .season).submitLabel(.next).onSubmit { field = .episode }
        }
    }
    private var episodeInput: some View {
        inputRow("开始集") {
            TextField("填写集数", text: $episode).keyboardType(.numbersAndPunctuation)
                .accessibilityLabel("开始集").accessibilityIdentifier("network.correction.episode")
                .focused($field, equals: .episode).submitLabel(.next).onSubmit { field = .end }
        }
    }
    private var endInput: some View {
        inputRow("结束集") {
            TextField("单集可留空", text: $episodeEnd).keyboardType(.numbersAndPunctuation)
                .accessibilityLabel("结束集，单集可留空").accessibilityIdentifier("network.correction.end")
                .focused($field, equals: .end).submitLabel(.done).onSubmit { field = .save }
        }
    }
    @ViewBuilder private func inputRow<Input: View>(_ label: String, @ViewBuilder input: () -> Input) -> some View {
        if columns || typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text(networkText(label)).font(NetworkType.caption).foregroundStyle(.secondary)
                input().modifier(NetworkInputStyle())
            }.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 16) {
                Text(networkText(label)).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
                input().modifier(NetworkInputStyle())
            }
        }
    }
}

#if DEBUG
struct OfflineCorrectionFormScene: View {
    let configuration: OfflineUIConfiguration
    @State private var title = "山海之间"
    @State private var year = "2024"
    @State private var kind: LocalMediaMetadata.Kind
    @State private var season = "1"
    @State private var episode = "2"
    @State private var episodeEnd = ""
    @State private var error: String?
    @State private var message = "离线界面测试 · 合成资料；不保存媒体库。"
    init(configuration: OfflineUIConfiguration) {
        self.configuration = configuration
        _kind = State(initialValue: configuration.scenario == .correctionMovie ? .movie : .episode)
        _error = State(initialValue: configuration.scenario == .correctionError ? "结束集不能早于开始集，请修改后重试。" : nil)
        _episodeEnd = State(initialValue: configuration.scenario == .correctionError ? "1" : "")
    }
    var body: some View {
        NetworkMediaCorrectionForm(title: $title, year: $year, kind: $kind, season: $season,
            episode: $episode, episodeEnd: $episodeEnd, saving: configuration.scenario == .correctionBusy,
            error: error, reviewMessage: "合成文件版本信息不足，保存后仍会标记待复核。", note: message,
            cancel: { message = "已取消合成草稿，未更改任何媒体库。" },
            save: { message = "仅预览保存入口，未保存或验证媒体库。" },
            restore: { message = "仅预览恢复入口，未更改任何媒体库。" }) {
                Text("合成文件 · 山海之间 S01E02.mkv").font(.subheadline)
                Text("此处仅展示合成原识别资料。").font(NetworkType.caption).foregroundStyle(.secondary)
            }
            .onChange(of: [title, year, kind.rawValue, season, episode, episodeEnd]) { _ in error = nil }
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成资料").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
}
#endif

private struct NetworkSourceAddView: View {
    @ObservedObject var model: NetworkLibrariesModel
    var showsSavedConnections = true
    var onAdded: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var reusing: NetworkSavedSource?
    @State private var choosingNAS = false
    @State private var addedFromSheet = false
    var body: some View {
        let savedConnections = showsSavedConnections ? model.savedWebDAVConnections : []
        NavigationStack {
            NetworkSourceAddPage(showsSavedConnections: showsSavedConnections,
                hasSavedConnections: (showsSavedConnections && model.nas != nil) || !savedConnections.isEmpty) {
                    if showsSavedConnections, let nas = model.nas {
                        Button { choosingNAS = true } label: { NetworkActionLabel(title: nas.name, symbol: "externaldrive.fill", subtitle: "当前 NAS · 选择媒体文件夹", semanticText: true) }
                            .accessibilityIdentifier("network.source.savedNAS")
                    }
                    ForEach(savedConnections) { library in
                        Button { reusing = library } label: { NetworkStoredConnectionLabel(name: library.name, managesSettings: false, kind: networkStorageKind(library.connection?.address ?? library.library?.address ?? "")) }
                            .accessibilityIdentifier("network.source.savedConnection")
                    }
            } newConnection: {
                    NavigationLink { NetworkLibraryAddView(model: model, didAdd: { onAdded(); dismiss() }) } label: {
                        NetworkNewWebDAVLabel()
                    }.accessibilityIdentifier("network.protocol.webdav")
                    NavigationLink { NetworkLibraryAddView(model: model, family: .ftp, didAdd: { onAdded(); dismiss() }) } label: {
                        NetworkNewFTPLabel()
                    }.accessibilityIdentifier("network.protocol.ftp")
                    NavigationLink { NetworkLibraryAddView(model: model, family: .smb, didAdd: { onAdded(); dismiss() }) } label: {
                        NetworkNewSMBLabel()
                    }.accessibilityIdentifier("network.protocol.smb")
            }.toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }.accessibilityIdentifier("network.source.cancel")
            } }
        }
        .sheet(isPresented: $choosingNAS, onDismiss: finishAdding) {
            NetworkExistingConnectionView(model: model, library: nil, onAdded: { addedFromSheet = true })
        }
        .sheet(item: $reusing, onDismiss: finishAdding) {
            NetworkExistingConnectionView(model: model, library: $0.library, connection: $0.connection, onAdded: { addedFromSheet = true })
        }
    }
    private func finishAdding() { if addedFromSheet { onAdded(); dismiss() } }
}

private struct NetworkNewFTPLabel: View {
    var body: some View {
        NetworkActionLabel(title: "添加 FTP / FTPS", symbol: "network",
            subtitle: "FTPS / FTP · 连接后选择媒体文件夹", semanticText: true)
    }
}

private struct NetworkNewSMBLabel: View {
    var body: some View {
        NetworkActionLabel(title: "添加 SMB", symbol: "externaldrive.connected.to.line.below",
            subtitle: "SMB · 连接后选择共享和媒体文件夹", semanticText: true)
    }
}

/// Which connection form a new source starts from; a saved address decides after that.
private enum NetworkStorageFamily {
    case webDAV, ftp, smb
    var defaultName: String {
        switch self {
        case .webDAV: return "我的 WebDAV"
        case .ftp: return "我的 FTP"
        case .smb: return "我的 SMB"
        }
    }
    var addTitle: String {
        switch self {
        case .webDAV: return "添加 WebDAV"
        case .ftp: return "添加 FTP / FTPS"
        case .smb: return "添加 SMB"
        }
    }
    var defaultScheme: WebDAVConnectionFields.Scheme {
        switch self {
        case .webDAV: return .https
        case .ftp: return .ftpes
        case .smb: return .smb
        }
    }
}

private func networkDefaultConnectionName(_ scope: WebDAVScope) -> String {
    if scope.isSMB { return networkL("我的 SMB") }
    return networkL(scope.ftpSecurity == nil ? "我的 WebDAV" : "我的 FTP")
}

private func networkStorageKind(_ address: String) -> String {
    let scope = try? WebDAVScope(storageAddress: address)
    if scope?.isSMB == true { return "SMB" }
    switch scope?.ftpSecurity {
    case .none: return "WebDAV"
    case .plainFTP: return "FTP"
    case .explicitTLS, .implicitTLS: return "FTPS"
    }
}

private func networkPortPlaceholder(_ scheme: WebDAVConnectionFields.Scheme) -> String {
    switch scheme {
    case .https: return networkL("443（留空使用默认）")
    case .http: return networkL("80（留空使用默认）")
    case .ftps: return networkL("990（留空使用默认）")
    case .ftpes, .ftp: return networkL("21（留空使用默认）")
    case .smb: return networkL("445（留空使用默认）")
    }
}

private struct NetworkNewWebDAVLabel: View {
    var body: some View {
        NetworkActionLabel(title: "添加 WebDAV", symbol: "externaldrive.badge.wifi",
            subtitle: "HTTP / HTTPS · 连接后选择媒体文件夹", semanticText: true)
    }
}

private struct NetworkSourceAddPage<Saved: View, NewConnection: View>: View {
    let showsSavedConnections: Bool
    let hasSavedConnections: Bool
    @ViewBuilder let saved: Saved
    @ViewBuilder let newConnection: NewConnection
    var body: some View {
        NetworkContentPage(title: showsSavedConnections ? "添加媒体文件夹" : "添加存储连接") {
            if showsSavedConnections && hasSavedConnections {
                NetworkContentSection(title: "已有连接") { NetworkGroupedRows { saved } }
            }
            NetworkContentSection(title: "新增连接") { NetworkGroupedRows { newConnection } }
            NetworkContentSection {
                Text("只读取所选文件夹，海报和媒体资料保存在本机，不会修改存储中的文件。")
                    .font(NetworkType.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
struct OfflineSourceAddScene: View {
    let configuration: OfflineUIConfiguration
    var body: some View {
        NetworkSourceAddPage(showsSavedConnections: configuration.scenario != .sourceAddConnection,
            hasSavedConnections: configuration.scenario == .sourceAdd) {
                Button {} label: {
                    NetworkActionLabel(title: "客厅 NAS", symbol: "externaldrive.fill",
                        subtitle: "当前 NAS · 选择媒体文件夹", semanticText: true)
                }
                Button {} label: { NetworkStoredConnectionLabel(name: "电影收藏", managesSettings: false) }
                Button {} label: { NetworkStoredConnectionLabel(name: "书房 NAS 与家庭共享媒体收藏", managesSettings: false) }
        } newConnection: {
            Button {} label: { NetworkNewWebDAVLabel() }
            Button {} label: { NetworkNewFTPLabel() }
            Button {} label: { NetworkNewSMBLabel() }
        }
        .safeAreaInset(edge: .bottom) {
            Text("离线界面测试 · 合成添加页").font(.caption2).dynamicTypeSize(.large)
                .foregroundStyle(.secondary).padding(.vertical, 8)
                .frame(maxWidth: .infinity).background(.background)
        }
    }
}
#endif

private struct NetworkWebDAVConnectionForm: View {
    @Binding var name: String
    @Binding var fields: WebDAVConnectionFields
    @Binding var username: String
    @Binding var password: String
    let title: String
    var subtitle = networkL("连接后选择要整理的媒体文件夹")
    var actionLabel = networkL("连接并选择文件夹")
    var busyLabel = networkL("正在读取目录")
    var prefix = "network.add"
    var note: String? = nil
    var busy = false
    var error: String? = nil
    /// True only when editing a connection that already has a saved password. The row then shows
    /// "已保存 · 更改" instead of a prefilled secure field, because iOS replaces a secure field's whole
    /// content on the first keystroke and a prefilled field would look like an append.
    var passwordSaved = false
    var secondaryAction: (() -> Void)? = nil
    let submit: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.networkAppearance) private var appearance
    @State private var passwordVisible = false
    @State private var replacingPassword = false
    @State private var savedPasswordSnapshot: String?
    #if DEBUG && os(iOS)
    var passwordDiagnosticsEnabled = false
    var passwordProbe = PasswordProbeOptions.production
    #endif
    /// Production: always true. Only the DEBUG offline attribution run can switch it off.
    private var contentTypesEnabled: Bool {
        #if DEBUG && os(iOS)
        passwordProbe.contentTypesEnabled
        #else
        true
        #endif
    }
    private enum Field: Hashable { case name, host, port, username, password, path }
    @FocusState private var field: Field?
    var body: some View {
        NetworkContentPage(title: title, subtitle: subtitle) {
            if let error {
                NetworkContentSection {
                    Label { Text(error).fixedSize(horizontal: false, vertical: true) }
                        icon: { Image(systemName: "exclamationmark.circle.fill") }
                        .foregroundStyle(.red).accessibilityElement(children: .combine)
                        .accessibilityIdentifier(prefix + ".error")
                }
            } else if busy {
                NetworkContentSection {
                    ProgressView(networkText(busyLabel)).accessibilityIdentifier(prefix + ".progress")
                }
            }
            NetworkContentSection(title: "连接信息") {
                inputRow("名称") {
                    TextField(networkText(fields.scheme == .smb ? NetworkStorageFamily.smb.defaultName : fields.scheme.isFTP ? NetworkStorageFamily.ftp.defaultName : NetworkStorageFamily.webDAV.defaultName), text: $name).focused($field, equals: .name)
                        .submitLabel(.next).onSubmit { field = .host }.accessibilityLabel("名称").accessibilityIdentifier(prefix + ".name")
                }
                if fields.scheme != .smb {
                inputRow("协议") {
                    Picker("协议", selection: $fields.scheme) {
                        if fields.scheme.isFTP {
                            Text("FTPS").tag(WebDAVConnectionFields.Scheme.ftpes)
                            Text("隐式 FTPS").tag(WebDAVConnectionFields.Scheme.ftps)
                            Text("FTP").tag(WebDAVConnectionFields.Scheme.ftp)
                        } else {
                            Text("HTTPS").tag(WebDAVConnectionFields.Scheme.https); Text("HTTP").tag(WebDAVConnectionFields.Scheme.http)
                        }
                    }
                        .pickerStyle(.segmented).labelsHidden().accessibilityIdentifier(prefix + ".scheme")
                }
                }
                inputRow("地址") {
                    TextField("nas.example.com", text: $fields.host).autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                        .focused($field, equals: .host).submitLabel(.next).onSubmit { field = .port }.accessibilityLabel("地址").accessibilityIdentifier(prefix + ".address").accessibilityHint("只填写域名或 IP，协议、端口和路径请分别填写。")
                }
                inputRow("端口") {
                    TextField(networkPortPlaceholder(fields.scheme), text: $fields.port).keyboardType(.numbersAndPunctuation)
                        .focused($field, equals: .port).submitLabel(.next).onSubmit { field = .username }.accessibilityLabel("端口").accessibilityIdentifier(prefix + ".port").accessibilityHint(fields.scheme == .smb ? "可留空，SMB 默认使用 445。" : fields.scheme.isFTP ? "可留空，FTP 和 FTPS 默认使用 21，隐式 FTPS 默认使用 990。" : "可留空，HTTPS 默认使用 443，HTTP 默认使用 80。")
                }
                inputRow("用户名") {
                    TextField("用户名", text: $username).autocorrectionDisabled().textInputAutocapitalization(.never).textContentType(contentTypesEnabled ? .username : nil)
                        .focused($field, equals: .username).submitLabel(.next).onSubmit { field = .password }.accessibilityLabel("用户名").accessibilityIdentifier(prefix + ".username")
                }
                inputRow("密码") {
                    if passwordSaved && !replacingPassword {
                        savedPasswordRow
                    } else {
                    HStack(spacing: 8) {
                        Group {
                            if passwordVisible { TextField("密码", text: $password) }
                            else { SecureField("密码", text: $password) }
                        }.autocorrectionDisabled().textInputAutocapitalization(.never).textContentType(contentTypesEnabled ? .password : nil)
                            .focused($field, equals: .password).submitLabel(.next).onSubmit { field = .path }
                            .accessibilityLabel("密码").accessibilityIdentifier(prefix + ".password").privacySensitive()
                        Button {
                            passwordTrace("toggle.before")
                            passwordVisible.toggle()
                            passwordTrace("toggle.after")
                        } label: {
                            Image(systemName: passwordVisible ? "eye.slash" : "eye")
                                .frame(width: 44, height: 24)
                        }
                        .accessibilityLabel(Text(passwordVisible ? "隐藏密码" : "显示密码"))
                        .accessibilityIdentifier(prefix + ".togglePassword")
                        .buttonStyle(NetworkPasswordVisibilityStyle())
                        if passwordSaved {
                            Button("取消") { cancelPasswordChange() }
                                .accessibilityIdentifier(prefix + ".cancelPasswordChange")
                                .buttonStyle(NetworkPasswordVisibilityStyle())
                        }
                    }
                    }
                }
                inputRow("路径") {
                    TextField("/video/media", text: $fields.path).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .focused($field, equals: .path).submitLabel(.done).onSubmit { field = nil }.accessibilityLabel("路径").accessibilityIdentifier(prefix + ".path").accessibilityHint("中文和空格按文件夹原名填写，无需手工编码。")
                }
            }
            NetworkContentSection {
                Text("路径按文件夹原名填写，中文和空格无需手工编码。账号仅保存在本机。").font(NetworkType.caption).foregroundStyle(.secondary)
                if fields.scheme == .http { Text("HTTP 不加密传输；服务支持时建议选择 HTTPS。").font(NetworkType.caption).foregroundStyle(.secondary) }
                if fields.scheme == .ftp { Text("FTP 不加密传输，账号、密码和文件内容都可能被同一网络中的设备读取，只建议在可信的局域网使用。").font(NetworkType.caption).foregroundStyle(.secondary) }
                if fields.scheme == .smb { Text("路径可留空，连接后选择共享和文件夹。SMB 无法确认服务器身份，只建议在局域网或 VPN 中使用。").font(NetworkType.caption).foregroundStyle(.secondary) }
                if fields.scheme == .ftpes || fields.scheme == .ftps { Text("FTPS 要求证书与地址匹配，自签名证书或用 IP 连接会被拒绝。").font(NetworkType.caption).foregroundStyle(.secondary) }
                Text("只读取你选择的目录，不会改写服务器文件。").font(NetworkType.caption).foregroundStyle(.secondary)
                if let note { Text(networkText(note)).font(NetworkType.caption).foregroundStyle(.secondary) }
                NetworkConnectionFormActions(actionLabel: actionLabel, busyLabel: busyLabel, prefix: prefix,
                    busy: busy, enabled: !fields.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    secondaryAction: secondaryAction.map { action in { field = nil; action() } },
                    submit: { field = nil; submit() })
            }
        }
        #if DEBUG && os(iOS)
        .background {
            if passwordDiagnosticsEnabled { PasswordInputDiagnosticsProbe() }
        }
        .onChange(of: field) { _ in passwordTrace("swift.focus.changed") }
        .onChange(of: passwordVisible) { _ in passwordTrace("swift.visibility.changed") }
        .onChange(of: password) { _ in passwordTrace("swift.password.changed") }
        .onAppear { passwordTrace("form.appear") }
        #endif
        .onChange(of: busy) { if $0 { passwordVisible = false } }
        .onDisappear { passwordTrace("form.disappear"); passwordVisible = false }
        #if os(iOS)
        .background { appearance.background.ignoresSafeArea() }
        #endif
    }
    private var savedPasswordRow: some View {
        HStack(spacing: 8) {
            Text("已保存").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("密码，已保存").accessibilityIdentifier(prefix + ".passwordSaved")
            Button("更改") { beginPasswordChange() }
                .accessibilityLabel("更改密码").accessibilityIdentifier(prefix + ".changePassword")
                .buttonStyle(NetworkPasswordVisibilityStyle())
        }
    }
    private func beginPasswordChange() {
        savedPasswordSnapshot = password
        password = ""
        passwordVisible = false
        replacingPassword = true
        Task { @MainActor in field = .password }
    }
    private func cancelPasswordChange() {
        password = savedPasswordSnapshot ?? ""
        savedPasswordSnapshot = nil
        passwordVisible = false
        replacingPassword = false
        field = nil
    }
    private func passwordTrace(_ event: String) {
        #if DEBUG && os(iOS)
        guard passwordDiagnosticsEnabled else { return }
        PasswordInputDiagnostics.record(event, focus: field.map { String(describing: $0) } ?? "none", visible: passwordVisible)
        #endif
    }
    @ViewBuilder private func inputRow<Input: View>(_ label: String, @ViewBuilder input: () -> Input) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text(networkText(label)).font(.subheadline).foregroundStyle(.secondary)
                input().modifier(NetworkInputStyle()).disabled(busy)
            }
        } else {
            HStack(spacing: 16) {
                Text(networkText(label)).foregroundStyle(.secondary).frame(width: labelWidth, alignment: .leading)
                input().modifier(NetworkInputStyle()).disabled(busy)
            }
        }
    }
    private var labelWidth: CGFloat {
        #if os(tvOS)
        120
        #else
        64
        #endif
    }
}

#if DEBUG && os(iOS)
private extension NetworkWebDAVConnectionForm {
    func enableOfflinePasswordDiagnostics(_ options: PasswordProbeOptions = .production) -> Self {
        var value = self
        value.passwordDiagnosticsEnabled = ProcessInfo.processInfo.arguments.contains("--offline-password-trace")
        value.passwordProbe = options
        value._passwordVisible = State(initialValue: options.startsVisible)
        return value
    }
}
#endif

private struct NetworkPasswordVisibilityStyle: ButtonStyle {
    @Environment(\.networkAppearance) private var appearance
    @Environment(\.isEnabled) private var enabled
    #if os(tvOS)
    @Environment(\.isFocused) private var focused
    #endif
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(appearance.accent)
            .contentShape(Rectangle().inset(by: -10))
            #if os(tvOS)
            .background(focused ? appearance.accent.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? appearance.accent : .clear, lineWidth: 2))
            #endif
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

/// Shared action hierarchy for add/edit and the isolated UI preview.
private struct NetworkConnectionFormActions: View {
    let actionLabel: String
    let busyLabel: String
    let prefix: String
    let busy: Bool
    let enabled: Bool
    var secondaryAction: (() -> Void)?
    let submit: () -> Void
    @Environment(\.networkAppearance) private var appearance
    var body: some View {
        Button(action: submit) {
            HStack(spacing: 10) {
                if busy { ProgressView().controlSize(.small) }
                Text(networkText(busy ? busyLabel : actionLabel)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if !busy { Image(systemName: "arrow.right") }
            }
            #if os(tvOS)
            .font(.system(size: 28, weight: .semibold))
            #else
            .font(.body.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 6)
            #endif
        }
        .disabled(busy || !enabled).accessibilityIdentifier(prefix + ".connect")
        #if os(iOS)
        .buttonStyle(MediaDetailActionStyle(accent: appearance.accent))
        #endif
        if let secondaryAction {
            Button(action: secondaryAction) { Label("仅保存连接", systemImage: "tray.and.arrow.down") }
                .disabled(busy || !enabled).accessibilityIdentifier(prefix + ".saveOnly")
                #if os(tvOS)
                .buttonStyle(NetworkTVCompactStyle())
                #else
                .font(.subheadline).buttonStyle(.borderless)
                #endif
        }
    }
}

#if DEBUG
/// Exact production form with synthetic bindings and local format validation.
/// No model/store/vault/client is constructed, including on submit or cancel.
public struct OfflineWebDAVFormScene: View {
    let configuration: OfflineUIConfiguration
    let appearance: NetworkMediaAppearance
    @State private var name = "家庭媒体"
    @State private var fields: WebDAVConnectionFields
    @State private var username = "preview-user"
    @State private var password: String
    @State private var message: String?
    @State private var error: String?
    public init(configuration: OfflineUIConfiguration, appearance: NetworkMediaAppearance) {
        self.configuration = configuration; self.appearance = appearance
        _password = State(initialValue: configuration.passwordProbe.isPrefilled ? "preview-only" : "")
        _fields = State(initialValue: WebDAVConnectionFields(
            scheme: configuration.scenario == .connectionHTTP ? .http : .https,
            host: configuration.scenario == .connection ? "" : "nas.example.invalid",
            port: configuration.scenario == .connectionHTTP ? "5005" : (configuration.scenario == .connectionError ? "70000" : "5006"),
            path: "/video/媒体样本"))
        _error = State(initialValue: configuration.scenario == .connectionError ? WebDAVConnectionFields.FieldError.port.errorDescription : nil)
    }
    private var editing: Bool { configuration.scenario == .connectionEdit }
    public var body: some View {
        VStack(spacing: 0) {
            form
            #if os(iOS)
            Text("离线界面测试 · 合成连接").font(.caption2).dynamicTypeSize(.large)
                .foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 8)
            #endif
        }
        .background { appearance.background.ignoresSafeArea() }
        .environment(\.networkAppearance, appearance)
        .toolbar { ToolbarItem(placement: .cancellationAction) {
            Button("取消") { password = ""; error = nil; message = "已取消本次离线草稿，未更改保存的连接。" }
                .accessibilityIdentifier("offline.connection.cancel")
        } }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    private var form: some View {
        Group {
            if configuration.scenario == .connectionActions {
                NetworkContentPage(title: "连接操作", subtitle: "离线界面测试 · 合成连接") {
                    NetworkContentSection {
                        NetworkConnectionFormActions(actionLabel: "连接并选择文件夹", busyLabel: "正在读取目录", prefix: "offline.connection",
                            busy: false, enabled: true, secondaryAction: { message = "离线预览：未写入任何连接。" }, submit: validate)
                        if let message { Text(message) }
                    }
                }
            } else {
                NetworkWebDAVConnectionForm(name: $name, fields: $fields, username: $username, password: $password,
                    title: editing ? "编辑 WebDAV" : "添加 WebDAV", subtitle: "离线界面测试 · 合成连接",
                    actionLabel: editing ? "验证并保存" : "连接并选择文件夹", busyLabel: "正在验证连接",
                    prefix: "offline.connection", note: message ?? "离线预览：不读取已保存账号，不连接服务器。",
                    busy: configuration.scenario == .connectionBusy, error: error,
                    passwordSaved: editing && configuration.passwordProbe.isPrefilled && configuration.passwordProbe.cell == nil,
                    secondaryAction: editing ? nil : { message = "离线预览：未写入任何连接。" }, submit: validate)
                    #if os(iOS)
                    .enableOfflinePasswordDiagnostics(configuration.passwordProbe)
                    #endif
            }
        }
    }
    private func validate() {
        do { _ = try fields.scope(); error = nil; message = "离线预览：格式检查通过，未发送连接请求。" }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "请检查连接信息。" }
    }
}
#endif

private struct NetworkLibraryAddView: View {
    @ObservedObject var model: NetworkLibrariesModel
    var family = NetworkStorageFamily.webDAV
    var didAdd: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var fields = WebDAVConnectionFields()
    @State private var username = ""
    @State private var password = ""
    @State private var folderSaving = false
    @State private var connection: Connection?
    @State private var error: String?
    @State private var connecting = false
    @State private var connectionTask: Task<Void, Never>?
    private struct Connection { let scope: WebDAVScope; let credential: WebDAVCredential; let client: any ReadOnlyDirectorySource; let entries: [RemoteMediaEntry] }
    var body: some View {
        Group {
            #if os(iOS)
            if networkFolderPickerPushesPages {
                // The folder picker is its own page, so back and the edge swipe return to this form.
                connectionForm.navigationDestination(isPresented: Binding(get: { connection != nil },
                    set: { if !$0 { connection = nil } })) {
                    if let connection { folderPicker(connection) }
                }
            } else if let connection { folderPicker(connection) } else { connectionForm }
            #else
            if let connection { folderPicker(connection) } else { connectionForm }
            #endif
        }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消", action: cancel).disabled(folderSaving).accessibilityIdentifier("network.add.cancel") } }
        .interactiveDismissDisabled(folderSaving)
        .onAppear {
            // Only the first appearance; returning from the folder picker keeps what was typed.
            guard name.isEmpty, fields.host.isEmpty else { return }
            name = family.defaultName
            fields.scheme = family.defaultScheme
        }
        .onDisappear { connectionTask?.cancel() }
    }
    private func cancel() {
        guard !folderSaving else { return }
        connectionTask?.cancel(); dismiss()
    }
    private func folderPicker(_ connection: Connection) -> some View {
        #if os(iOS)
        let pushed = networkFolderPickerPushesPages
        #else
        let pushed = false
        #endif
        let rootBack: (() -> Void)? = pushed ? nil : { self.connection = nil }
        return NetworkFolderPicker(path: try! DAVPath(), initial: connection.entries,
            client: connection.client, rootBack: rootBack, select: { path in
                try await model.add(name: name, scope: connection.scope, root: path, credential: connection.credential)
                password = ""; didAdd()
            }, onSavingChanged: { folderSaving = $0 },
            cancel: cancel, cancelIdentifier: "network.add.cancel", showsCancel: pushed)
    }
    private var connectionForm: some View {
        NetworkWebDAVConnectionForm(name: $name, fields: $fields, username: $username, password: $password,
            title: networkText(family.addTitle), busy: connecting, error: error,
            secondaryAction: { connect(saveOnly: true) }, submit: { connect() })
    }
    private func connect(saveOnly: Bool = false) {
        error = nil; connecting = true
        connectionTask = Task {
            defer { connecting = false; connectionTask = nil }
            do {
                let scope = try fields.scope()
                let credential = WebDAVCredential(username: username, password: password)
                let client = try networkStorageSource(scope: scope, credential: username.isEmpty && password.isEmpty ? nil : credential)
                let entries = try await client.list(try DAVPath())
                try Task.checkCancellation()
                if saveOnly {
                    try await model.saveConnection(name: name, scope: scope, credential: credential)
                    password = ""; didAdd()
                } else { connection = Connection(scope: scope, credential: credential, client: client, entries: entries) }
            } catch is CancellationError { }
            catch { self.error = networkMessage(error) }
        }
    }
}

private struct NetworkConnectionDetails: View {
    @ObservedObject var model: NetworkLibrariesModel
    let connection: NetworkStorageConnection
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var adding = false
    @State private var updated = false
    @State private var editingFolder: NetworkLibrary?
    var body: some View {
        let folders = model.libraries.filter { $0.connectionID == connection.id }
        NavigationStack {
            NetworkConnectionDetailsPage(name: connection.name, kind: networkStorageKind(connection.address), hasFolders: !folders.isEmpty,
                edit: { editing = true }, add: { adding = true }) {
                ForEach(folders) { library in
                    Button { editingFolder = library } label: {
                        NetworkMediaFolderLabel(name: library.name, path: library.folderPath, source: connection.name + " · " + networkStorageKind(connection.address))
                    }.accessibilityIdentifier("network.connection.editFolder")
                }
            }.toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("完成") { dismiss() }.accessibilityIdentifier("network.connection.done")
            } }
        }
        .sheet(isPresented: $editing, onDismiss: { if updated { dismiss() } }) {
            NetworkConnectionEditor(model: model, connection: connection) { updated = true }
        }
        .sheet(isPresented: $adding) { NetworkExistingConnectionView(model: model, library: nil, connection: connection) }
        .sheet(item: $editingFolder) { NetworkLibraryFolderEditor(library: $0, model: model) {} }
    }
}

private struct NetworkConnectionDetailsPage<Folders: View>: View {
    let name: String
    var kind = "WebDAV"
    let hasFolders: Bool
    let edit: () -> Void
    let add: () -> Void
    @ViewBuilder let folders: Folders
    var body: some View {
        NetworkContentPage(title: name) {
            NetworkContentSection(title: "连接设置") {
                NetworkGroupedRows {
                    Button(action: edit) {
                        NetworkActionLabel(title: "编辑连接", symbol: "slider.horizontal.3",
                            subtitle: networkL("\(kind) · 名称、协议、地址与账号"), semanticText: true)
                    }.accessibilityIdentifier("network.connection.edit")
                }
            }
            NetworkContentSection(title: "媒体文件夹") {
                if !hasFolders {
                    Text("尚未添加媒体文件夹，使用此连接选择文件夹后即可建立媒体库。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("network.connection.noFolders")
                }
                NetworkGroupedRows {
                    folders
                    Button(action: add) {
                        NetworkActionLabel(title: "添加媒体文件夹", symbol: "folder.badge.plus", semanticText: true)
                    }.accessibilityIdentifier("network.connection.addFolder")
                }
                if hasFolders {
                    Text("选择已有文件夹可修改路径，不会移动或修改远端文件。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#if DEBUG
struct OfflineConnectionDetailsScene: View {
    let configuration: OfflineUIConfiguration
    private var long: Bool { configuration.scenario == .connectionDetailLong }
    private var hasFolders: Bool { configuration.scenario != .connectionDetailEmpty }
    private var name: String { long ? "家庭共享媒体收藏与书房 NAS" : "客厅 NAS" }
    var body: some View {
        NetworkConnectionDetailsPage(name: name, hasFolders: hasFolders, edit: {}, add: {}) {
            if hasFolders {
                Button {} label: {
                    NetworkMediaFolderLabel(name: long ? "电影与家庭收藏的特别收录" : "电影",
                        path: long ? "/video/电影与家庭收藏/特别收录与未完成的夏天/The Journey Beyond the Stars 100%" : "/video/电影",
                        source: name + " · WebDAV")
                }
                if !long {
                    Button {} label: { NetworkMediaFolderLabel(name: "电影", path: "/archive/电影", source: name + " · WebDAV") }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("离线界面测试 · 合成连接详情").font(.caption2).dynamicTypeSize(.large)
                .foregroundStyle(.secondary).padding(.vertical, 8)
                .frame(maxWidth: .infinity).background(.background)
        }
    }
}
#endif

private struct NetworkConnectionEditor: View {
    @ObservedObject var model: NetworkLibrariesModel
    let connection: NetworkStorageConnection
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var fields: WebDAVConnectionFields
    @State private var username: String
    @State private var password: String
    private let hasSavedPassword: Bool
    @State private var failure: String?
    @State private var task: Task<Void, Never>?
    init(model: NetworkLibrariesModel, connection: NetworkStorageConnection, onSaved: @escaping () -> Void) {
        self.model = model; self.connection = connection; self.onSaved = onSaved
        _name = State(initialValue: connection.name)
        _fields = State(initialValue: (try? WebDAVConnectionFields(scope: WebDAVScope(storageAddress: connection.address))) ?? WebDAVConnectionFields())
        let credential = try? NetworkCredentialVault.load(connection)
        _username = State(initialValue: credential?.username ?? "")
        _password = State(initialValue: credential?.password ?? "")
        hasSavedPassword = !(credential?.password ?? "").isEmpty
    }
    var body: some View {
        NavigationStack {
            NetworkWebDAVConnectionForm(name: $name, fields: $fields, username: $username, password: $password,
                title: fields.scheme == .smb ? networkL("编辑 SMB") : fields.scheme.isFTP ? networkL("编辑 FTP") : networkL("编辑 WebDAV"), subtitle: networkL("连接设置"), actionLabel: networkL("验证并保存"), busyLabel: networkL("正在验证 · 已发现 \(model.discovered) 个视频"),
                prefix: "network.connectionEdit", note: "媒体文件夹保留各自的已选路径；路径栏用于添加文件夹时的起始位置。更换地址或账号会先验证并重建关联媒体库，失败或取消保留原配置。",
                busy: task != nil, error: failure, passwordSaved: hasSavedPassword) {
                    failure = nil
                    task = Task { @MainActor in
                        do {
                            try await model.editConnection(connection, name: name, scope: fields.scope(), credential: WebDAVCredential(username: username, password: password))
                            task = nil; password = ""; dismiss(); onSaved()
                        } catch is CancellationError { task = nil }
                        catch { failure = networkMessage(error); task = nil }
                    }
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { task?.cancel(); dismiss() }.accessibilityIdentifier("network.connectionEdit.cancel")
                } }
        }.onDisappear { task?.cancel() }
    }
}

private struct NetworkExistingConnectionView: View {
    @ObservedObject var model: NetworkLibrariesModel
    let library: NetworkLibrary?
    var connection: NetworkStorageConnection? = nil
    var onAdded: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var folderSaving = false
    @State private var source: (any ReadOnlyDirectorySource)?
    @State private var error: String?
    @State private var name = ""
    @State private var startingPath = try! DAVPath()
    @State private var preparationAttempt = 0
    @State private var cancelled = false
    var body: some View {
        let requested = preparationAttempt
        NavigationStack {
            Group {
                if let source {
                    VStack(spacing: 0) {
                        TextField("媒体库名称（可留空）", text: $name).modifier(NetworkInputStyle()).padding()
                            .accessibilityIdentifier("network.existing.name").disabled(folderSaving)
                        NetworkFolderPicker(path: startingPath, client: source, select: { path in
                            if let connection {
                                try await model.addFolder(connection: connection, name: name, path: path)
                            } else if let library, library.fileStationAccount == nil {
                                let selected = try library.replacingFolder(with: "/" + path.displayPath)
                                try await model.add(name: name.isEmpty ? path.name : name, scope: WebDAVScope(storageAddress: selected.address), root: selected.root, credential: NetworkCredentialVault.load(library))
                            } else {
                                if let library {
                                    guard let nas = model.nas else { throw NetworkMediaError.fileStationUnavailable }
                                    _ = try nas.source(for: library)
                                }
                                try await model.addNAS(name: name, root: path)
                            }
                            onAdded(); dismiss()
                        }, allowsRoot: connection != nil || (library?.fileStationAccount == nil && library != nil),
                           allowsParentNavigation: connection != nil || (library?.fileStationAccount == nil && library != nil),
                           onSavingChanged: { folderSaving = $0 }, cancel: cancel, cancelIdentifier: "network.existing.cancel")
                    }
                } else {
                    NetworkExistingConnectionStatusPage(sourceName: connection?.name ?? library?.name ?? model.nas?.name ?? networkL("存储连接"),
                        sourceKind: (connection != nil || (library?.fileStationAccount == nil && library != nil)) ? networkStorageKind(connection?.address ?? library?.address ?? "") : "NAS",
                        error: error, retry: retryPreparation, cancel: cancel)
                }
            }.modifier(NetworkPageStyle())
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancel).disabled(folderSaving).accessibilityIdentifier("network.existing.cancel")
                } }
                .task(id: requested) { prepare(requested) }
        }.interactiveDismissDisabled(folderSaving)
    }
    private func cancel() {
        guard !folderSaving else { return }
        cancelled = true
        dismiss()
    }
    private func retryPreparation() {
        guard !cancelled, !folderSaving, source == nil, error != nil else { return }
        error = nil
        preparationAttempt += 1
    }
    @MainActor private func prepare(_ requested: Int) {
        guard !cancelled, !Task.isCancelled, requested == preparationAttempt, source == nil else { return }
        do {
            let prepared = try makeSource()
            guard !cancelled, !Task.isCancelled, requested == preparationAttempt else { return }
            startingPath = prepared.path
            source = prepared.source
            error = nil
        } catch {
            guard !cancelled, !Task.isCancelled, requested == preparationAttempt else { return }
            self.error = networkMessage(error)
        }
    }
    // Local preparation only; the folder picker owns the actual directory read.
    @MainActor private func makeSource() throws -> (source: any ReadOnlyDirectorySource, path: DAVPath) {
        if let connection {
            let proxy = try connection.credentialLibrary()
            let location = try proxy.folderBrowsingLocation()
            return (try networkStorageSource(scope: location.scope, credential: try NetworkCredentialVault.load(connection)), location.path)
        } else if let library, library.fileStationAccount == nil {
            return try model.folderBrowser(for: library, path: library.folderPath)
        } else if let nas = model.nas {
            return (try library.map { try nas.source(for: $0) } ?? nas.makeSource(), try DAVPath())
        } else { throw NetworkMediaError.fileStationUnavailable }
    }
}

private struct NetworkExistingConnectionStatusPage: View {
    let sourceName: String
    let sourceKind: String
    let error: String?
    let retry: () -> Void
    let cancel: () -> Void
    var body: some View {
        NetworkContentPage(title: "选择媒体文件夹", backAction: cancel) {
            NetworkContentSection(title: "已有连接") {
                NetworkActionLabel(title: sourceName, symbol: "externaldrive.badge.wifi",
                    subtitle: sourceKind, semanticText: true, showsDisclosure: false)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("network.existing.source")
            }
            NetworkContentSection(title: error == nil ? nil : "无法准备连接") {
                if let error {
                    Text(error).foregroundStyle(Color.secondary).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("network.existing.error")
                } else {
                    ProgressView("正在准备已有连接").accessibilityIdentifier("network.existing.loading")
                    Text("准备完成后，即可选择要加入媒体库的文件夹。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                }
                NetworkReadPageActions(retry: error == nil ? nil : retry, back: cancel,
                    retryIdentifier: "network.existing.retry", backIdentifier: "network.existing.back")
            }
        }
    }
}

private struct NetworkReadPageActions: View {
    let retry: (() -> Void)?
    var back: (() -> Void)? = nil
    let retryIdentifier: String
    var backIdentifier = "network.read.back"
    @Environment(\.networkAppearance) private var appearance
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 16) { actions }
        } else {
            HStack(spacing: 20) { actions }
        }
    }
    @ViewBuilder private var actions: some View {
        if let retry {
            action("重试", symbol: "arrow.clockwise", identifier: retryIdentifier, perform: retry)
        }
        if let back {
            action("返回上一页", symbol: "chevron.backward", identifier: backIdentifier, perform: back)
        }
    }
    private func action(_ title: String, symbol: String, identifier: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(appearance.accent)
                Text(networkText(title)).foregroundStyle(Color.primary).fixedSize(horizontal: false, vertical: true)
            }
        }.accessibilityIdentifier(identifier)
        #if os(tvOS)
        .buttonStyle(NetworkTVCompactStyle())
        #else
        .buttonStyle(.borderless)
        #endif
    }
}

#if DEBUG
struct OfflineExistingConnectionStatusScene: View {
    let configuration: OfflineUIConfiguration
    var body: some View {
        NetworkExistingConnectionStatusPage(sourceName: "家庭共享媒体收藏",
            sourceKind: configuration.scenario == .existingUnavailable ? "NAS" : "WebDAV",
            error: configuration.scenario == .existingPreparing ? nil
                : configuration.scenario == .existingUnavailable ? "当前 NAS 未连接，请返回选择其他连接，或连接 NAS 后重试。"
                : "未找到此连接的登录信息，请返回上一页并重新添加 WebDAV。",
            retry: {}, cancel: {})
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成连接状态").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
}
#endif

#if os(iOS)
/// Pushing folder levels with navigationDestination spins SwiftUI at full CPU with
/// growing memory on iOS 16 (iPhone 13, 16.3.1), so it keeps the in-place history there.
private var networkFolderPickerPushesPages: Bool {
    if #available(iOS 17.0, *) { return true } else { return false }
}
#endif

private struct NetworkFolderPicker: View {
    let path: DAVPath
    var initial: [RemoteMediaEntry]? = nil
    let client: any ReadOnlyDirectorySource
    var rootBack: (() -> Void)? = nil
    let select: (DAVPath) async throws -> Void
    var allowsRoot = true
    var allowsParentNavigation = false
    var selectionTitle = networkL("将此文件夹加入媒体库")
    var selectionIdentifier = "network.folder.select"
    var onSavingChanged: (Bool) -> Void = { _ in }
    /// Cancels the whole flow. Pushed iOS levels show it themselves because the
    /// caller's toolbar stays on the page that presented the first level.
    var cancel: (() -> Void)? = nil
    var cancelIdentifier = "network.folder.cancel"
    var showsCancel = false
    @State private var entries: [RemoteMediaEntry] = []
    @State private var loaded = false
    @State private var saving = false
    @State private var listingError: String?
    @State private var selectionError: String?
    @State private var retry = 0
    @State private var current: DAVPath?
    @State private var history: [DAVPath] = []
    @State private var usedInitial = false
    #if os(iOS)
    /// iOS 17+ pushes each subfolder as its own page, so the system back button and the
    /// edge swipe step back one level. iOS 16 and tvOS keep the in-place history above.
    @State private var child: DAVPath?
    #endif
    @FocusState private var folderFocus: String?
    @Environment(\.dismiss) private var dismiss
    private var directory: DAVPath { current ?? path }
    private struct Request: Hashable { let directory: DAVPath; let retry: Int }
    private var request: Request { Request(directory: directory, retry: retry) }
    private var canSelect: Bool { loaded && !saving && (allowsRoot || !directory.encodedSegments.isEmpty) }
    private var backTitle: String? {
        guard !history.isEmpty || rootBack != nil || (allowsParentNavigation && directory.parent != nil) else { return nil }
        return allowsParentNavigation ? (directory.parent == nil && history.isEmpty ? networkL("返回修改页") : networkL("上一级"))
            : (history.isEmpty ? networkL("返回连接设置") : networkL("上一级"))
    }
    private func resetDirectory() {
        loaded = false; entries = []; listingError = nil; selectionError = nil
    }
    private func back() {
        guard !saving else { return }
        if let previous = history.popLast() { current = previous; resetDirectory() }
        else if allowsParentNavigation, let parent = directory.parent { current = parent; resetDirectory() }
        else if let rootBack { rootBack() }
        else { dismiss() }
    }
    private func open(_ entry: RemoteMediaEntry) {
        guard !saving, loaded, entry.isDirectory else { return }
        #if os(iOS)
        if networkFolderPickerPushesPages { child = entry.path; return }
        #endif
        history.append(directory); current = entry.path; resetDirectory()
    }
    #if os(iOS)
    private func childPicker(_ path: DAVPath) -> AnyView {
        // A pushed level only moves down; going up is the system back of this page.
        AnyView(NetworkFolderPicker(path: path, client: client, select: select, allowsRoot: allowsRoot,
            selectionTitle: selectionTitle, selectionIdentifier: selectionIdentifier,
            onSavingChanged: onSavingChanged, cancel: cancel, cancelIdentifier: cancelIdentifier, showsCancel: true))
    }
    #endif
    private func chooseCurrent() {
        guard canSelect else { return }
        let selectedDirectory = directory
        selectionError = nil; saving = true; onSavingChanged(true)
        Task {
            defer { saving = false; onSavingChanged(false) }
            do { try await select(selectedDirectory) }
            catch {
                guard !Task.isCancelled, directory == selectedDirectory else { return }
                selectionError = networkMessage(error)
            }
        }
    }
    var body: some View {
        let requested = request
        NetworkFolderPickerPage(directory: directory, entries: entries, loaded: loaded, saving: saving,
            listingError: listingError, selectionError: selectionError, allowsRoot: allowsRoot,
            selectionTitle: selectionTitle, selectionIdentifier: selectionIdentifier, backTitle: backTitle,
            focus: $folderFocus, back: back, retry: { if !saving { retry += 1 } },
            choose: chooseCurrent, open: open)
            .task(id: requested) { await read(requested) }
            #if os(iOS)
            .toolbar { if showsCancel, let cancel { ToolbarItem(placement: .cancellationAction) {
                Button("取消", action: cancel).disabled(saving).accessibilityIdentifier(cancelIdentifier)
            } } }
            .navigationDestination(isPresented: Binding(get: { child != nil }, set: { if !$0 { child = nil } })) {
                if let child { childPicker(child) }
            }
            #endif
    }
    private func read(_ requested: Request) async {
        guard requested == request, !Task.isCancelled else { return }
        loaded = false; listingError = nil; selectionError = nil
        do {
            let result: [RemoteMediaEntry]
            if requested.directory == path, !usedInitial, let initial { usedInitial = true; result = initial }
            else { result = try await client.list(requested.directory) }
            try Task.checkCancellation()
            guard requested == request else { return }
            entries = result; loaded = true
            #if os(tvOS)
            await Task.yield()
            guard !Task.isCancelled, requested == request else { return }
            // Do not explicitly focus an unavailable root-selection button.
            if canSelect { folderFocus = "select" }
            #endif
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled, requested == request else { return }
            listingError = networkMessage(error)
        }
    }
}

/// One presentation for production folder browsers and ephemeral Debug states.
/// It contains no directory client, credential or persistence operation.
private struct NetworkFolderPickerPage: View {
    let directory: DAVPath
    let entries: [RemoteMediaEntry]
    let loaded: Bool
    var saving = false
    var listingError: String?
    var selectionError: String?
    var allowsRoot = true
    var selectionTitle = networkL("将此文件夹加入媒体库")
    var selectionIdentifier = "network.folder.select"
    var backTitle: String?
    var focus: FocusState<String?>.Binding? = nil
    var note: String?
    let back: () -> Void
    let retry: () -> Void
    let choose: () -> Void
    let open: (RemoteMediaEntry) -> Void
    @Environment(\.networkAppearance) private var appearance
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var widthClass
    #endif
    private var folders: [RemoteMediaEntry] { entries.filter(\.isDirectory) }
    private var rootUnavailable: Bool { !allowsRoot && directory.encodedSegments.isEmpty }
    var body: some View {
        NetworkContentPage(title: "选择媒体文件夹", backAction: back) {
            NetworkContentSection(title: "当前文件夹") {
                Label { Text(directory.displayPath.isEmpty ? "/" : directory.displayPath)
                    .fixedSize(horizontal: false, vertical: true) }
                    icon: { Image(systemName: "folder.fill").foregroundStyle(appearance.accent) }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("network.folder.currentPath")
                Text("只读取此文件夹及其子文件夹内的视频，不修改源文件。")
                    .font(NetworkType.caption).foregroundStyle(.secondary)
                if rootUnavailable && loaded && !folders.isEmpty {
                    Text("此连接不能选择根目录，请进入一个子文件夹。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                }
                if loaded { selectionButton }
            }
            if saving {
                NetworkContentSection {
                    ProgressView("正在处理所选文件夹").accessibilityIdentifier("network.folder.progress")
                }
            }
            if let selectionError {
                NetworkContentSection {
                    failure(selectionError, identifier: "network.folder.selectionError")
                    Text("仍保留当前路径，可以重试或选择其他文件夹。")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                }
            }
            if !loaded {
                NetworkContentSection {
                    if let listingError {
                        failure(listingError, identifier: "network.folder.listingError")
                        Button(action: retry) { Label("重新读取", systemImage: "arrow.clockwise") }
                            .accessibilityIdentifier("network.folder.retry").disabled(saving)
                            #if os(tvOS)
                            .buttonStyle(NetworkTVCompactStyle())
                            #else
                            .buttonStyle(.borderless)
                            #endif
                    } else {
                        ProgressView("正在读取目录").accessibilityIdentifier("network.folder.loading")
                    }
                }
            } else {
                NetworkContentSection(title: "子文件夹") {
                    if folders.isEmpty {
                        Text(rootUnavailable ? "当前根目录不可选，也没有可进入的子文件夹。请返回并选择其他位置。"
                            : "没有子文件夹，仍可选择当前文件夹中的视频。")
                            .font(NetworkType.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("network.folder.noChildren")
                    } else {
                        NetworkGroupedRows {
                            ForEach(folders) { entry in
                                Button { open(entry) } label: { NetworkActionLabel(title: entry.path.name, symbol: "folder") }
                                    .disabled(saving).accessibilityIdentifier("network.folder.child")
                            }
                        }
                    }
                }
            }
            if let note { NetworkContentSection { Text(networkText(note)).font(NetworkType.caption).foregroundStyle(.secondary) } }
        }
        .interactiveDismissDisabled(saving)
        .toolbar { ToolbarItem(placement: .navigationBarLeading) {
            if let backTitle {
                #if os(iOS)
                Button(action: back) {
                    if widthClass == .compact {
                        Image(systemName: "chevron.backward")
                    } else {
                        Text(networkText(backTitle))
                    }
                }
                .accessibilityLabel(networkText(backTitle))
                .disabled(saving).accessibilityIdentifier("network.folder.back")
                #else
                Button(networkText(backTitle), action: back).disabled(saving).accessibilityIdentifier("network.folder.back")
                #endif
            }
        } }
        #if os(iOS)
        // Pushed levels use the system back and edge swipe. A custom back only remains on a
        // sheet's first level, where nothing is below it; saving holds every level in place.
        .navigationBarBackButtonHidden(backTitle != nil || saving)
        .background { appearance.background.ignoresSafeArea() }
        #endif
    }
    @ViewBuilder private var selectionButton: some View {
        let button = Button(action: choose) {
            Label(saving ? networkL("正在处理") : networkText(selectionTitle), systemImage: "folder.badge.plus")
        }.buttonStyle(MediaDetailActionStyle(accent: appearance.accent))
            .disabled(saving || rootUnavailable).accessibilityIdentifier(selectionIdentifier)
        #if os(tvOS)
        if let focus { button.focused(focus, equals: "select") } else { button }
        #else
        button
        #endif
    }
    private func failure(_ message: String, identifier: String) -> some View {
        Label { Text(message).fixedSize(horizontal: false, vertical: true) }
            icon: { Image(systemName: "exclamationmark.circle.fill") }
            .foregroundStyle(.red).accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
struct OfflineFolderPickerScene: View {
    let configuration: OfflineUIConfiguration
    @State private var message = "离线界面测试 · 合成文件夹；不读取或保存连接。"
    private var rootUnavailable: Bool { configuration.scenario == .folderPickerRoot }
    private var directory: DAVPath { try! DAVPath(rootUnavailable ? "" : "合成媒体/电影 100%") }
    private var entries: [RemoteMediaEntry] {
        guard [.folderPicker, .folderPickerBusy, .folderPickerSelectionError].contains(configuration.scenario) else { return [] }
        return ["合成电影", "剧集与动漫"].map { RemoteMediaEntry(path: try! DAVPath("合成媒体/电影 100%/" + $0), isDirectory: true) }
    }
    var body: some View {
        #if os(iOS)
        if configuration.scenario == .folderPicker,
           ProcessInfo.processInfo.arguments.contains("--offline-folder-navigation") {
            OfflineFolderNavigationScene()
        } else { preview }
        #else
        preview
        #endif
    }
    private var preview: some View {
        NetworkFolderPickerPage(directory: directory, entries: entries,
            loaded: ![.folderPickerLoading, .folderPickerError].contains(configuration.scenario),
            saving: configuration.scenario == .folderPickerBusy,
            listingError: configuration.scenario == .folderPickerError ? "无法读取文件夹，请检查路径或访问权限。" : nil,
            selectionError: configuration.scenario == .folderPickerSelectionError ? "未能使用所选文件夹，请重试。" : nil,
            allowsRoot: !rootUnavailable, backTitle: "返回连接设置", note: message,
            back: { message = "已返回合成连接，未改动媒体库。" },
            retry: { message = "仅预览重新读取入口，未发送请求。" },
            choose: { message = "仅预览选择入口，未保存媒体库。" },
            open: { _ in message = "仅预览子文件夹入口，未读取服务器。" })
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成文件夹").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
}

#if os(iOS)
/// Explicit gesture fixture: the real picker, only in-memory folders and draft state.
/// It never creates a library model, connection client, vault, or persistent store.
private struct OfflineFolderNavigationScene: View {
    private enum Flow: String, Identifiable, CaseIterable {
        case add = "新增连接", existing = "已有连接", modify = "修改路径", busy = "保存中"
        var id: String { rawValue }
    }
    @State private var flow: Flow?
    @State private var connected = false
    @State private var saving = false
    @State private var name = "合成媒体库"
    @State private var fields = WebDAVConnectionFields(scheme: .http, host: "127.0.0.1", port: "8089", path: "/")
    @State private var username = ""
    @State private var password = ""
    @State private var result = "尚未选择；只使用内存目录，不连接服务器。"
    private let source = OfflineFolderDirectorySource()
    var body: some View {
        List {
            Section("只读内存目录") {
                ForEach(Flow.allCases) { value in
                    Button(value.rawValue) { connected = false; saving = false; flow = value }
                        .accessibilityIdentifier("offline.folderNavigation." + value.id)
                }
            }
            Section("最近结果") {
                Text(result).accessibilityIdentifier("offline.folderNavigation.result")
            }
        }.navigationTitle("离线逐级返回测试")
        .sheet(item: $flow, onDismiss: { connected = false; saving = false }) { value in
            NavigationStack {
                Group {
                    if value == .add {
                        NetworkWebDAVConnectionForm(name: $name, fields: $fields, username: $username,
                            password: $password, title: "合成连接表单", subtitle: "仅内存目录，不连接服务器",
                            prefix: "offline.folderNavigation.form", submit: { connected = true })
                            .navigationDestination(isPresented: $connected) { picker(value, pushed: true) }
                    } else {
                        VStack(spacing: 0) {
                            if value == .existing || value == .busy {
                                TextField("媒体库名称（可留空）", text: $name).modifier(NetworkInputStyle()).padding()
                                    .accessibilityIdentifier("offline.folderNavigation.name").disabled(saving)
                            }
                            picker(value, pushed: false)
                        }
                    }
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancel).disabled(saving)
                        .accessibilityIdentifier("offline.folderNavigation.cancel")
                } }
            }.interactiveDismissDisabled(saving)
        }
    }
    private func cancel() {
        guard !saving else { return }
        result = "已取消整个合成流程；未更改任何媒体库。"
        flow = nil
    }
    private func picker(_ value: Flow, pushed: Bool) -> some View {
        NetworkFolderPicker(path: try! DAVPath(value == .modify ? "电影" : ""), client: source,
            rootBack: value == .modify ? cancel : nil, select: { path in
                if value == .busy {
                    try await Task.sleep(nanoseconds: 8_000_000_000)
                    throw NetworkMediaError.fileStationUnavailable
                }
                result = "名称：\(name)；路径：/\(path.displayPath)；仅更改内存草稿。"
                flow = nil
            }, allowsParentNavigation: value == .modify || value == .existing,
            selectionTitle: value == .modify ? "使用此文件夹" : "将此文件夹加入媒体库",
            onSavingChanged: { saving = $0 }, cancel: cancel,
            cancelIdentifier: "offline.folderNavigation.cancel", showsCancel: pushed)
    }
}

private struct OfflineFolderDirectorySource: ReadOnlyDirectorySource {
    func list(_ directory: DAVPath) async throws -> [RemoteMediaEntry] {
        let folders = ["": ["电影", "剧集"], "电影": ["精选"], "电影/精选": ["蓝光"], "剧集": ["第一季"]]
        let parent = directory.displayPath
        return try (folders[parent] ?? []).map {
            RemoteMediaEntry(path: try DAVPath(parent.isEmpty ? $0 : parent + "/" + $0), isDirectory: true)
        }
    }
}
#endif
#endif

#endif
