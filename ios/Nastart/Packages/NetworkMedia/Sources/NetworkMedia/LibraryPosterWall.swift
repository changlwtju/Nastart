#if os(iOS) || os(tvOS)
import SwiftUI
import ImageIO
import UIKit

@MainActor struct NetworkLibraryPosterWall: View {
    let library: NetworkLibrary
    @ObservedObject var model: NetworkLibrariesModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.networkAppearance) private var appearance
    @Environment(\.dynamicTypeSize) private var typeSize
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var widthClass
    #else
    @AppStorage(MediaPosterGridLayout.televisionDensityPreference) private var posterDensity = MediaPosterGridLayout.defaultTelevisionDensity
    @State private var showingSearch = false
    @FocusState private var searchFocused: Bool
    @FocusState private var focusedPoster: String?
    #endif
    @State private var search = ""
    @State private var editingFolder = false
    @State private var editingTMDB = false
    @State private var confirmingRemoval = false
    @State private var selected: RemoteMediaEntry?
    @State private var managementExpanded = false
    @State private var supplementsExpanded = false
    @State private var category: MediaCategory?
    @State private var selectedSeries: MediaSeries?
    @State private var localReadRetry: UUID?
    private func title(_ file: RemoteMediaEntry) -> String {
        if let correction = library.correction(for: file), correction.applies(to: file) { return correction.values.title }
        return file.metadata?.title ?? MediaFilenameParser.identify(file.path).title
    }
    private func layout(_ width: CGFloat) -> MediaPosterGridLayout {
        #if os(tvOS)
        return .television(viewportWidth: width, density: posterDensity, accessibility: typeSize.isAccessibilitySize)
        #else
        return .mobile(viewportWidth: width, compact: widthClass == .compact, accessibility: typeSize.isAccessibilitySize)
        #endif
    }
    private var posterTitleFont: Font {
        #if os(tvOS)
        .system(size: 28, weight: .medium)
        #else
        widthClass == .compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold)
        #endif
    }
    private var posterCaptionFont: Font {
        #if os(tvOS)
        NetworkType.caption
        #else
        widthClass == .compact ? .caption2 : .caption
        #endif
    }
    private var posterTitleLines: Int {
        #if os(tvOS)
        1
        #else
        2
        #endif
    }
    private func posterWidth(_ layout: MediaPosterGridLayout) -> CGFloat {
        #if os(tvOS)
        max(1, layout.itemWidth - 20)
        #else
        layout.itemWidth
        #endif
    }
    var body: some View {
        let library = model.libraries.first { $0.id == self.library.id } ?? self.library
        let catalog = model.catalogs[library.id] ?? []
        let selection = MediaWallSelection(catalog: catalog, preferredCategory: category, query: search,
            includesSupplements: supplementsExpanded, fileTitle: title)
        let items = selection.matches
        GeometryReader { geometry in
            let layout = layout(geometry.size.width)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    #if os(tvOS)
                    header(compact: layout.contentWidth < 1100 || typeSize.isAccessibilitySize)
                    #else
                    if showsStatus {
                        header(compact: true)
                    }
                    #endif
                    #if os(tvOS)
                    if showingSearch {
                        TextField("片名、剧名或文件名", text: $search).modifier(NetworkInputStyle())
                            .focused($searchFocused).onSubmit { searchFocused = false; showingSearch = false }
                            .accessibilityIdentifier("network.library.search")
                    }
                    #endif
                    categories(catalog, selection: selection)
                    if selection.emptyState != .none {
                        NetworkLibraryWallEmptyState(state: selection.emptyState, clearSearch: clearSearch)
                    } else {
                        MediaPosterGrid(layout: layout) {
                            ForEach(selection.visibleItems) { item in
                                let file = item.movie?.representative ?? item.files.first { $0.metadata?.artwork != nil } ?? item.files[0]
                                Button { if let series = item.series { selectedSeries = series } else { selected = file } } label: {
                                    MediaPosterCard(
                                        title: item.movie?.kind == .video || item.movie?.kind == .supplement ? title(file) : item.title,
                                        subtitle: item.series.map { networkL("\($0.seasons.count) 季 · \($0.files.count) 个视频文件") } ?? (item.movie?.kind == .bluRay ? networkL("蓝光原盘 · \(item.files.count) 个文件") : item.movie?.kind == .segments ? networkL("分段影片 · \(item.files.count) 个文件") : file.metadata?.year.map(String.init) ?? (file.metadata?.origin == .nfo ? networkL("已有资料") : networkL("待确认"))),
                                        accent: appearance.accent) {
                                        NetworkLocalPoster(library: library, file: file, model: model, series: item.series?.info, seriesMode: item.series != nil,
                                            tmdb: item.series?.tmdbLookup ?? item.movie.flatMap { library.tmdbLookup(group: $0) })
                                    }.frame(width: posterWidth(layout), alignment: .topLeading)
                                }.buttonStyle(NetworkPosterCardStyle(poster: true)).accessibilityIdentifier(item.series == nil ? "network.file.open" : "network.series.open")
                                #if os(tvOS)
                                .focused($focusedPoster, equals: item.id)
                                #endif
                            }
                        }.accessibilityIdentifier("network.library.posterWall").accessibilityValue("\(layout.columns) 列")
                    }
                    if items.contains(where: { $0.movie?.kind == .supplement }) {
                        Button { supplementsExpanded.toggle() } label: {
                            Label(supplementsExpanded ? "收起附加视频" : "显示附加视频（\(items.filter { $0.movie?.kind == .supplement }.count)）", systemImage: supplementsExpanded ? "chevron.up" : "chevron.down")
                        }.accessibilityIdentifier("network.library.supplements")
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Button { managementExpanded.toggle() } label: {
                            HStack {
                                Text("来源与管理")
                                Spacer()
                                Image(systemName: managementExpanded ? "chevron.up" : "chevron.down")
                            }.padding(12).contentShape(Rectangle())
                        }.buttonStyle(NetworkPosterCardStyle()).accessibilityValue(managementExpanded ? "已展开" : "已折叠")
                        .accessibilityIdentifier("network.library.management")
                        if managementExpanded {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("\(catalog.filter { $0.movie?.kind != .supplement }.count) 部作品 · \(library.files.count) 个文件")
                                .font(NetworkType.caption).foregroundStyle(.secondary)
                            Text("\(Set(library.files.compactMap { $0.metadata?.nfoPath }).count) 份 NFO · \(Set(library.files.compactMap { $0.metadata?.artwork?.path }).count) 张已有图片")
                                .font(NetworkType.caption).foregroundStyle(.secondary)
                            Text(library.folderPath).foregroundStyle(.secondary)
                            if let date = library.lastCompletedScan { Text("上次整理：\(date.formatted())").font(NetworkType.caption) }
                            Text("已有资料与图片只读导入，索引和图片缓存保存在本机。")
                                .font(NetworkType.caption).foregroundStyle(.secondary)
                            editFolderAction
                            tmdbAction
                            Button(role: .destructive) { confirmingRemoval = true } label: { Text("移除此媒体库（仅本机）") }
                                .accessibilityIdentifier("network.library.remove")
                                .modifier(NetworkLibraryRemovalConfirmation(isPresented: $confirmingRemoval, name: library.name) {
                                    Task { await model.remove(library); if !model.libraries.contains(where: { $0.id == library.id }) { dismiss() } }
                                })
                        }.padding(.top, 14)
                        }
                    }.padding(18).background { appearance.surface }.clipShape(RoundedRectangle(cornerRadius: 18))
                }.frame(width: layout.contentWidth, alignment: .leading).padding(.vertical, posterPageInset).frame(maxWidth: .infinity)
            }
        }
        .modifier(NetworkPageStyle())
        #if os(iOS)
        .navigationTitle(library.name).navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "片名、剧名或文件名")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                MediaLibraryMenu {
                    scanAction
                    editFolderAction
                    tmdbAction
                }.accessibilityIdentifier("network.library.more")
            }
        }
        #else
        .navigationTitle("")
        #endif
        .sheet(isPresented: $editingTMDB) {
            NetworkTMDBSettingsView(model: model).environment(\.networkAppearance, appearance)
        }
        .onAppear { retainCategory(selection.activeCategory) }
        .onChange(of: selection.activeCategory, perform: retainCategory)
        .sheet(isPresented: $editingFolder) {
            NetworkLibraryFolderEditor(library: library, model: model) { dismiss() }
                .environment(\.networkAppearance, appearance)
        }
        .navigationDestination(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            if let file = selected {
                NetworkLocalMediaDetail(library: library, file: file, group: catalog.compactMap(\.movie).first { $0.files.contains(where: { $0.path == file.path }) }, model: model)
                    .environment(\.networkAppearance, appearance)
            }
        }
        .navigationDestination(isPresented: Binding(get: { selectedSeries != nil }, set: { if !$0 { selectedSeries = nil } })) {
            if let series = selectedSeries {
                NetworkSeriesPage(library: library, series: series, model: model)
                    .environment(\.networkAppearance, appearance)
            }
        }
        .onDisappear { localReadRetry = nil }
        .task(id: localReadRetry) {
            guard let requested = localReadRetry else { return }
            // Consume only this request, including on exit. Returning to the
            // wall must not replay a previous retry or enter its scan task.
            defer { if localReadRetry == requested { localReadRetry = nil } }
            guard !Task.isCancelled else { return }
            await model.refresh()
        }
        .task(id: library.id) {
            #if os(tvOS)
            if focusedPoster == nil, let first = items.first(where: { $0.movie?.kind != .supplement }) {
                await Task.yield()
                focusedPoster = first.id
            }
            #endif
            // Upgrade an already indexed library once, using the same bounded,
            // cancellable transaction. Failure keeps the complete previous index.
            if (library.artworkScanVersion ?? 0) < 5 && library.lastCompletedScan != nil && model.scanning == nil {
                model.scan(library)
            }
        }
    }
    private var posterPageInset: CGFloat {
        #if os(tvOS)
        70
        #else
        18
        #endif
    }
    private func categories(_ items: [MediaCatalogItem], selection: MediaWallSelection) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(selection.categories) { kind in
                    Button {
                        category = kind; supplementsExpanded = false
                        #if os(tvOS)
                        if let first = items.first(where: { $0.category == kind && $0.movie?.kind != .supplement }) {
                            Task { await Task.yield(); focusedPoster = first.id }
                        }
                        #endif
                    } label: {
                        Text(kind.title)
                    }.buttonStyle(MediaLibraryCategoryStyle(selected: selection.activeCategory == kind, accent: appearance.accent))
                        .accessibilityIdentifier("network.category." + kind.rawValue)
                        .accessibilityValue(selection.activeCategory == kind ? "已选择" : "未选择")
                }
            }.padding(3)
        }
    }
    private var showsStatus: Bool {
        model.scanning == library.id || model.error != nil || model.localRead.phase != .ready
    }
    private func retainCategory(_ resolved: MediaCategory?) {
        guard category != resolved else { return }
        category = resolved; supplementsExpanded = false
    }
    private func clearSearch() {
        search = ""
        #if os(tvOS)
        showingSearch = false; searchFocused = false
        #endif
    }
    private func retryLocalRead() {
        guard model.localRead.phase == .failed || model.localRead.phase == .idle else { return }
        localReadRetry = UUID()
    }
    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            #if os(tvOS)
            if compact {
                heading
                actions
            } else {
                HStack { heading; Spacer(minLength: 12); actions }
            }
            #endif
            if showsStatus {
                NetworkLibraryWallStatus(scanID: model.scanning == library.id ? model.scanning : nil,
                    discovered: model.discovered, canCancel: model.canCancelScan,
                    error: model.error, cancel: model.cancel,
                    localReadPhase: model.localRead.phase, localReadMessage: model.localRead.failureMessage,
                    retryRead: retryLocalRead)
            }
        }
    }
    private var heading: some View {
        MediaLibraryHeading(title: library.name, subtitle: "")
    }
    private var actions: some View {
        MediaLibraryToolbar {
            #if os(tvOS)
            Button {
                showingSearch = true
                Task { await Task.yield(); searchFocused = true }
            } label: { Label(search.isEmpty ? "搜索" : "搜索中", systemImage: "magnifyingglass") }
                .accessibilityIdentifier("network.library.search.open")
            if !search.isEmpty {
                Button(action: clearSearch) { Label("清除搜索", systemImage: "xmark.circle") }
                    .accessibilityIdentifier("network.library.search.clear")
            }
            #endif
            MediaLibraryMenu {
                scanAction
                editFolderAction
                tmdbAction
            }.accessibilityIdentifier("network.library.more")
        }
    }
    private var tmdbAction: some View {
        Button { editingTMDB = true } label: { Label("TMDB 资料补全", systemImage: "text.badge.plus") }
            .accessibilityIdentifier("network.library.tmdb")
    }
    private var editFolderAction: some View {
        Button { editingFolder = true } label: { Label("修改文件夹", systemImage: "folder.badge.gearshape") }
            .disabled(model.scanning != nil).accessibilityIdentifier("network.library.editFolder")
    }
    @ViewBuilder private var scanAction: some View {
        if model.scanning == library.id {
            if model.canCancelScan {
                Button("取消扫描") { model.cancel() }.accessibilityIdentifier("network.library.cancel")
            } else {
                Text("正在更新资料")
            }
        } else {
            Button { model.scan(library) } label: { Label("刷新", systemImage: "arrow.clockwise") }
                .disabled(model.scanning != nil).accessibilityIdentifier("network.library.rescan")
        }
    }

}

struct NetworkLibraryWallEmptyState: View {
    let state: MediaWallSelection.EmptyState
    let clearSearch: () -> Void
    @Environment(\.networkAppearance) private var appearance
    var body: some View {
        if state != .none {
            MediaLibraryEmptyState(systemImage: state == .noResults ? "magnifyingglass" : "film.stack",
                title: Text(networkText(title)), detail: Text(networkText(detail)), accent: appearance.accent) {
                if state == .noResults {
                    Button(action: clearSearch) {
                        Label {
                            Text("清除搜索").foregroundStyle(Color.primary)
                        } icon: {
                            Image(systemName: "xmark.circle").foregroundStyle(appearance.accent)
                        }
                    }.accessibilityIdentifier("network.library.search.clear.empty")
                    #if os(tvOS)
                    .buttonStyle(NetworkTVCompactStyle())
                    #else
                    .buttonStyle(.borderless)
                    #endif
                }
            }.accessibilityIdentifier("network.library.emptyState")
        }
    }
    private var title: String {
        switch state {
        case .libraryEmpty: "媒体库暂无作品"
        case .noResults: "当前分类没有匹配的作品"
        case .supplementsHidden: "附加视频已收起"
        case .none: ""
        }
    }
    private var detail: String {
        switch state {
        case .libraryEmpty: "当前本机索引还没有可展示的作品。"
        case .noResults: "可更换关键词，或切换分类继续查找。"
        case .supplementsHidden: "展开附加视频后即可查看。"
        case .none: ""
        }
    }
}

struct NetworkPosterCardStyle: ButtonStyle {
    var poster = false
    @Environment(\.networkAppearance) private var appearance
    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        #if os(tvOS)
        if poster {
            MediaPosterFocusStyle(accent: appearance.accent).makeBody(configuration: configuration)
        } else { otherBody(configuration) }
        #else
        otherBody(configuration)
        #endif
    }
    private func otherBody(_ configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(.primary)
            #if os(tvOS)
            .padding(poster ? 10 : 0)
            #endif
            // A poster's artwork carries its own corner clip; clipping the whole card would cut the
            // first glyph of the caption that sits in the bottom-leading corner.
            .background { if poster { RoundedRectangle(cornerRadius: 13, style: .continuous).fill(focused ? appearance.accent.opacity(0.20) : .clear) } else { appearance.surface } }
            .clipShape(poster ? AnyShape(Rectangle()) : AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
            .overlay { RoundedRectangle(cornerRadius: poster ? 13 : 16).stroke(focused ? appearance.accent : poster ? .clear : Color.primary.opacity(0.08), lineWidth: focused ? 3 : 1) }
            .scaleEffect(poster && focused && !reduceMotion ? 1.035 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

@MainActor struct NetworkLocalPoster: View {
    let library: NetworkLibrary
    let file: RemoteMediaEntry
    @ObservedObject var model: NetworkLibrariesModel
    var series: LocalSeriesMetadata? = nil
    var seriesMode = false
    var aspect: CGFloat = 2.0 / 3.0
    var tmdb: TMDBLookup? = nil
    @Environment(\.networkAppearance) private var appearance
    @State private var image: UIImage?
    @State private var imageIdentity: String?
    @State private var failed = false
    /// Only where the NAS has no poster of its own. An episode still standing in for a show counts as none.
    private var tmdbCandidate: TMDBLookup? {
        guard model.tmdbEnabled, (seriesMode ? series?.artwork : file.metadata?.artwork) == nil else { return nil }
        return tmdb
    }
    /// A series without its own poster shows its earliest episode's image rather than nothing.
    private var reference: LocalArtworkReference? { seriesMode ? (series?.artwork ?? file.metadata?.artwork) : file.metadata?.artwork }
    private var identity: String {
        if let tmdbCandidate { return "tmdb|" + tmdbCandidate.identity }
        return reference.flatMap { try? LocalArtworkCache.key(library: library, reference: $0) } ?? library.id.uuidString + file.id
    }
    private var displayedImage: UIImage? {
        if imageIdentity == identity, let image { return image }
        guard reference?.hasVersionHint == true || tmdbCandidate != nil,
              let decoded = DecodedArtworkCache.shared.image(for: identity) else { return nil }
        return UIImage(cgImage: decoded)
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [appearance.accent.opacity(0.22), Color.primary.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let image = displayedImage {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: seriesMode || file.metadata?.kind == .episode ? "tv" : "film").font(.largeTitle)
                        Text(failed ? "封面暂不可用" : seriesMode ? "暂无剧集海报" : "暂无封面").font(NetworkType.caption)
                    }.foregroundStyle(appearance.accent)
                }
            }
        }.aspectRatio(aspect, contentMode: .fit).accessibilityLabel(displayedImage == nil ? (failed ? "封面暂不可用" : "暂无封面") : "已有海报")
        .task(id: identity) {
            let requested = identity
            if imageIdentity != requested { image = nil; imageIdentity = requested }
            if reference?.hasVersionHint == true || tmdbCandidate != nil, let cached = displayedImage {
                image = cached; failed = false; return
            }
            failed = false
            var remote: Data?
            if let tmdbCandidate {
                remote = await model.tmdbImage(await model.tmdbMatch(tmdbCandidate)?.posterPath, size: .poster)
            }
            guard remote != nil || reference != nil else { return }
            do {
                try Task.checkCancellation()
                let data: Data
                if let remote { data = remote }
                else if seriesMode, let series, series.artwork != nil { data = try await model.artwork(library: library, series: series) }
                else { data = try await model.artwork(library: library, file: file) }
                let result = await Task.detached(priority: .utility) { () -> CGImage? in
                    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
                    return CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 768, kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
                }.value
                try Task.checkCancellation()
                if let result {
                    // A local stand-in must not occupy the TMDB identity, or TMDB would never be asked again.
                    if remote != nil || (tmdbCandidate == nil && reference?.hasVersionHint == true) { DecodedArtworkCache.shared.insert(result, for: requested) }
                    image = UIImage(cgImage: result)
                }
            } catch is CancellationError { }
            catch { failed = true }
        }
    }
}

/// A real listed backdrop when available; Jellyfin's poster fallback otherwise.
@MainActor private struct NetworkDetailBackdrop: View {
    let library: NetworkLibrary
    let file: RemoteMediaEntry
    @ObservedObject var model: NetworkLibrariesModel
    var tmdb: TMDBLookup? = nil
    @State private var image: UIImage?
    @State private var imageIdentity: String?
    private var identity: String {
        // Reuse only within this indexed snapshot. A rescan/file revision
        // invalidates the backdrop even when the video path is unchanged.
        [library.id.uuidString, file.id, file.etag ?? "", file.modified ?? "",
         String(file.size ?? -1), String(library.lastCompletedScan?.timeIntervalSince1970 ?? 0),
         model.tmdbEnabled ? (tmdb?.identity ?? "") : ""].joined(separator: "|")
    }
    private var displayedImage: UIImage? {
        if imageIdentity == identity, let image { return image }
        return DecodedArtworkCache.shared.image(for: identity).map { UIImage(cgImage: $0) }
    }
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image = displayedImage { Image(uiImage: image).resizable().scaledToFill() }
                else {
                    // Match the hero's real shape; a fixed 16:9 fit left blank bands in taller heroes.
                    NetworkLocalPoster(library: library, file: file, model: model,
                        aspect: geometry.size.height > 0 ? geometry.size.width / geometry.size.height : 16.0 / 9.0, tmdb: tmdb)
                        #if os(tvOS)
                        .blur(radius: 8)
                        #endif
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.accessibilityHidden(true)
        .task(id: identity) {
            let requested = identity
            if imageIdentity != requested { image = nil; imageIdentity = requested }
            if let cached = displayedImage { image = cached; return }
            do {
                var local: Data?
                do { local = try await model.backdrop(library: library, file: file) }
                catch is CancellationError { throw CancellationError() }
                catch { if !model.tmdbEnabled || tmdb == nil { throw error } }
                var found = local
                if found == nil { found = await model.tmdbImage(await model.tmdbMatch(tmdb)?.backdropPath, size: .backdrop) }
                guard let data = found else { return }
                try Task.checkCancellation()
                let decoded = await Task.detached(priority: .utility) { () -> CGImage? in
                    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
                    return CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 1536, kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
                }.value
                try Task.checkCancellation()
                if let decoded {
                    DecodedArtworkCache.shared.insert(decoded, for: requested)
                    image = UIImage(cgImage: decoded)
                }
            } catch { /* The already visible poster remains the fallback. */ }
        }
    }
}

@MainActor struct NetworkLocalMediaDetail: View {
    let library: NetworkLibrary
    let file: RemoteMediaEntry
    let group: MediaPresentationGroup?
    @ObservedObject var model: NetworkLibrariesModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.networkAppearance) private var appearance
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var editing = false
    @State private var playing: RemoteMediaEntry?
    @State private var playsFromBeginning = false
    @State private var resumeSeconds: Double?
    private func refreshResume() {
        let library = model.libraries.first { $0.id == self.library.id } ?? self.library
        let id = try? current.size.map { try NetworkMediaPlaybackSource.stableID(library: library, file: current, byteCount: $0) }
        resumeSeconds = id.flatMap { $0 }.flatMap { model.resumeSeconds?($0) }.flatMap { $0 > 0 ? $0 : nil }
    }
    private var current: RemoteMediaEntry { model.indexedFile(libraryID: library.id, path: file.path) ?? file }
    private var correction: LocalMediaCorrection.Values? {
        guard let saved = model.libraries.first(where: { $0.id == library.id })?.correction(for: current), saved.applies(to: current) else { return nil }
        return saved.values
    }
    @State private var loadedMetadata: LocalMediaMetadata?
    @State private var loadedMetadataIdentity: String?
    @State private var metadataRead = MediaDetailReadState()
    @State private var creditsRead = MediaDetailReadState()
    @State private var overviewExpanded = false
    @State private var serverPeople: [MediaCredit] = []
    @State private var serverPeopleIdentity: String?
    @State private var tmdbMatch: TMDBMatch?
    private var tmdbLookup: TMDBLookup? { group.flatMap { (model.libraries.first { $0.id == library.id } ?? library).tmdbLookup(group: $0) } }
    private var creditsIdentity: String {
        detailIdentity + "|" + (model.credits?.source.identity ?? "") + "|" + metadata.providerIDs.sorted { $0.key < $1.key }.map { $0.key + ":" + $0.value }.joined(separator: "|") + "|" + (correction == nil ? "original" : "corrected")
    }
    private var detailIdentity: String {
        [library.id.uuidString, current.id, current.etag ?? "", current.modified ?? "", String(current.size ?? -1),
         String(library.lastCompletedScan?.timeIntervalSince1970 ?? 0)].joined(separator: "|")
    }
    private var metadata: LocalMediaMetadata {
        (loadedMetadataIdentity == detailIdentity ? loadedMetadata : nil) ?? current.metadata ?? MediaFilenameParser.identify(current.path)
    }
    private var details: LocalMediaDetails? {
        let local = correction == nil ? metadata.details : nil
        return tmdbMatch?.filling(local, displayTitle: displayTitle) ?? local
    }
    private var displayTitle: String { correction?.title ?? group?.title ?? metadata.title }
    private var plot: String? { (correction == nil ? MediaDetailSummary.normalized(metadata.plot) : nil) ?? MediaDetailSummary.normalized(tmdbMatch?.overview) }
    private var sourceLabel: String {
        let local = correction != nil ? networkL("本机修改") : (metadata.origin == .nfo ? networkL("已有 NFO 资料") : tmdbMatch != nil ? networkL("文件名识别") : networkL("文件名识别 · 待确认"))
        return tmdbMatch == nil ? local : local + " · " + networkL("缺失部分来自 TMDB")
    }
    private var displayedPeople: [MediaCredit] {
        Array((serverPeopleIdentity == creditsIdentity && !serverPeople.isEmpty ? serverPeople
            : (details?.displayPeople ?? []).map { MediaCredit(name: $0.name, role: $0.role, imageID: nil, imageTag: nil) }).prefix(18))
    }
    private var personFocusIDs: [String] {
        MediaDetailFocusMap.personIDs(for: displayedPeople)
    }
    private func memberFocusID(_ file: RemoteMediaEntry) -> String { "network.file.member." + file.id }
    private var detailFocusMap: MediaDetailFocusMap {
        let actions = (canPlay(current) && (group?.files.count ?? 1) == 1 ? ["network.file.play"] + (resumeSeconds == nil ? [] : ["network.file.restart"]) : [])
            + ((plot?.count ?? 0) > 180 ? ["network.file.overview"] : [])
        let members = (group?.files.count ?? 0) > 1 ? (group?.files ?? []).filter { canPlay($0) }.map(memberFocusID) : []
        return .init(actions: actions, people: personFocusIDs, related: [], relatedRetry: nil,
            files: "network.file.information", fileChoices: members)
    }
    var body: some View {
        #if os(tvOS)
        MediaDetailFocusScope(map: detailFocusMap, nativeIDs: ["network.file.edit"]) { focus in detailPage(focus: focus) }
        #else
        detailPage(focus: nil)
        #endif
    }
    private func detailPage(focus: MediaDetailFocusContext?) -> some View {

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        detailHero(focus: focus)
                        VStack(alignment: .leading, spacing: 22) {
                            #if os(iOS)
                            metadataFacts
                            if let tagline = details?.tagline { Text(tagline).font(.subheadline).foregroundStyle(.secondary) }
                            actions(focus: focus)
                            playbackNotice
                            if let plot {
                                MediaDetailSection(title: Text("影片简介")) {
                                    MediaDetailSummary(plot, lines: overviewExpanded ? nil : 6)
                                    if plot.count > 180 && !typeSize.isAccessibilitySize { overviewButton(focus: focus) }
                                }
                            }
                            #endif
                            fileSelection(focus: focus)
                            detailInformation(focus: focus)
                        }
                        #if os(iOS)
                        .frame(width: min(820, max(geometry.size.width - 36, 0)), alignment: .leading)
                        .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 36)
                        .frame(maxWidth: .infinity).background { appearance.background }.zIndex(1)
                        #else
                        .padding(.top, 38)
                        #endif
                    }
                    #if os(tvOS)
                    .padding(70)
                    #endif
                    .frame(width: geometry.size.width, alignment: .leading)
                }
            }.modifier(NetworkPageStyle()).navigationTitle("")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .onChange(of: playing?.id) { value in if value == nil { refreshResume() } }
                .task(id: detailIdentity) {
                    refreshResume()
                    let requested = detailIdentity
                    // Returning from playback keeps previously accepted metadata.
                    guard loadedMetadataIdentity != requested || metadataRead.phase(for: requested) == .failed else { return }
                    if loadedMetadataIdentity != requested { loadedMetadata = nil }
                    let ticket = metadataRead.begin(requested)
                    do {
                        let value = try await model.detailMetadata(library: library, file: current)
                        try Task.checkCancellation()
                        guard requested == detailIdentity, metadataRead.succeed(ticket) else { return }
                        loadedMetadata = value; loadedMetadataIdentity = requested
                    } catch is CancellationError { metadataRead.cancel(ticket) }
                    catch {
                        guard !Task.isCancelled, requested == detailIdentity else { metadataRead.cancel(ticket); return }
                        metadataRead.fail(ticket)
                    }
                }
                .task(id: model.tmdbEnabled ? tmdbLookup?.identity : nil) {
                    guard let lookup = tmdbLookup else { tmdbMatch = nil; return }
                    let match = await model.tmdbMatch(lookup)
                    guard !Task.isCancelled else { return }
                    tmdbMatch = match
                }
                .task(id: creditsIdentity) {
                    let requested = creditsIdentity
                    guard serverPeopleIdentity != requested else { return }
                    serverPeople = []; serverPeopleIdentity = nil
                    CreditReadDiagnostics.record("detail", ["corrected": String(correction != nil), "context": String(model.credits != nil), "providerCount": String(metadata.providerIDs.count)])
                    guard correction == nil, let context = model.credits else { creditsRead = MediaDetailReadState(); return }
                    let ticket = creditsRead.begin(requested)
                    do {
                        let people = try await context.people(for: metadata)
                        try Task.checkCancellation()
                        guard requested == creditsIdentity, creditsRead.succeed(ticket) else { return }
                        CreditReadDiagnostics.record("people", ["count": String(people.count), "withImages": String(people.filter { $0.imageID != nil && $0.imageTag != nil }.count)])
                        serverPeople = people; serverPeopleIdentity = requested
                    } catch is CancellationError { creditsRead.cancel(ticket) }
                    catch {
                        guard !Task.isCancelled, requested == creditsIdentity else { creditsRead.cancel(ticket); return }
                        creditsRead.fail(ticket)
                        CreditReadDiagnostics.record("peopleError", ["type": String(describing: type(of: error))])
                    }
                }
                .sheet(isPresented: $editing) { NetworkMediaCorrectionView(id: library.id, file: current,
                    correction: model.libraries.first { $0.id == library.id }?.correction(for: current), model: model) }
                .fullScreenCover(item: $playing) { file in
                    if let playback = model.playback {
                        NetworkLibraryPlaybackView(libraryID: library.id, expected: file, fromBeginning: playsFromBeginning, destination: playback)
                    }
                }
    }
    private func detailHero(focus: MediaDetailFocusContext?) -> some View {
        MediaDetailHero {
            NetworkDetailBackdrop(library: library, file: current, model: model, tmdb: tmdbLookup)
        } poster: {
            NetworkLocalPoster(library: library, file: current, model: model, tmdb: tmdbLookup)
        } content: {
            VStack(alignment: .leading, spacing: 18) {
                MediaDetailHeading(title: displayTitle,
                    subtitle: detailSubtitle, originalTitle: details?.originalTitle)
                #if os(tvOS)
                metadataFacts
                if let tagline = details?.tagline { Text(tagline).font(.system(size: 24)).foregroundStyle(.white.opacity(0.8)) }
                MediaDetailSummary(plot ?? "", lines: overviewExpanded ? nil : 4)
                actions(focus: focus)
                playbackNotice
                #endif
            }
        }
    }
    private var detailSubtitle: String {
        #if os(tvOS)
        ""
        #else
        (correction?.year ?? metadata.year).map(String.init) ?? ""
        #endif
    }
    private func actions(focus: MediaDetailFocusContext?) -> some View {
        MediaDetailActionRow {
            if canPlay(current), (group?.files.count ?? 1) == 1 {
                Button { playsFromBeginning = false; playing = current } label: {
                    Label(resumeSeconds == nil ? "播放" : "继续观看", systemImage: "play.fill")
                        #if os(tvOS)
                        .font(.system(size: 28))
                        #else
                        .font(.subheadline.weight(.semibold))
                        #endif
                }
                    .buttonStyle(MediaDetailActionStyle(accent: appearance.accent))
                    .accessibilityIdentifier("network.file.play")
                    .modifier(MediaDetailFocusTarget(context: focus, id: "network.file.play"))
                if resumeSeconds != nil {
                    Button { playsFromBeginning = true; playing = current } label: {
                        Label("从头播放", systemImage: "arrow.counterclockwise")
                            #if os(tvOS)
                            .font(.system(size: 28))
                            #else
                            .font(.subheadline.weight(.semibold))
                            #endif
                    }
                        .buttonStyle(MediaDetailActionStyle(accent: appearance.accent))
                        .accessibilityIdentifier("network.file.restart")
                        .modifier(MediaDetailFocusTarget(context: focus, id: "network.file.restart"))
                }
            }
            #if os(tvOS)
            if let plot, plot.count > 180 { overviewButton(focus: focus) }
            #endif
        }
    }
    @ViewBuilder private var playbackNotice: some View {
        if (group?.files.count ?? 1) == 1, let reason = playbackLimitation(current) {
            MediaDetailPlaybackNotice(reason: reason, accent: appearance.accent)
        }
    }
    private func playbackLimitation(_ file: RemoteMediaEntry) -> MediaDetailPlaybackNotice.Reason? {
        guard !canPlay(file) else { return nil }
        if (file.path.name as NSString).pathExtension.lowercased() == "iso" { return .discImage }
        if library.fileStationAccount != nil || model.playback == nil { return .sourceUnavailable }
        return .unsupportedFile
    }
    private func overviewButton(focus: MediaDetailFocusContext?) -> some View {
        Button(overviewExpanded ? "收起简介" : "展开简介") {
            withAnimation(.easeInOut(duration: 0.2)) { overviewExpanded.toggle() }
        }
        #if os(tvOS)
        .font(.system(size: 28))
        #else
        .font(.subheadline.weight(.semibold))
        #endif
        .foregroundStyle(appearance.accent)
        .accessibilityIdentifier("network.file.overview")
        .modifier(MediaDetailFocusTarget(context: focus, id: "network.file.overview"))
    }
    private var metadataFacts: some View {
        MediaDetailFacts(.init(rating: details?.rating, officialRating: details?.officialRating,
            duration: details?.runtimeMinutes.map { networkL("\($0) 分钟") }, video: details?.video, audio: details?.audio,
            date: (correction?.year ?? metadata.year ?? tmdbMatch?.year).map(String.init), genres: details?.genres ?? []))
    }
    private func detailInformation(focus: MediaDetailFocusContext?) -> some View {
        MediaDetailInformation(studios: details?.studios ?? []) {
            creditsSection(focus: focus)
        } related: {
            EmptyView()
        } supplement: {
            fileInformation(focus: focus)
        }
    }
    private func creditsSection(focus: MediaDetailFocusContext?) -> some View {
        MediaDetailSection(title: Text("演职人员")) {
            let people = displayedPeople
            if people.isEmpty {
                if let availability = MediaCreditsAvailability.resolve(hasPeople: false,
                    metadata: loadedMetadataIdentity == detailIdentity ? .ready : metadataRead.phase(for: detailIdentity),
                    credits: correction != nil || model.credits == nil ? .ready : creditsRead.phase(for: creditsIdentity)) {
                    MediaDetailCreditsNotice(availability: availability)
                }
            } else {
                MediaDetailFocusedPeople(context: focus, ids: personFocusIDs) {
                    LazyHStack(alignment: .top, spacing: creditSpacing) {
                        ForEach(Array(people.enumerated()), id: \.offset) { index, person in
                            let id = personFocusIDs[index]
                            MediaFocusablePerson(accent: appearance.accent, focus: focus?.focus, focusID: id) {
                                MediaDetailPersonCard(name: person.name, role: person.role) {
                                    NetworkCreditPortrait(person: person, context: model.credits)
                                }
                            }.modifier(MediaDetailFocusTarget(context: focus, id: id, bindsFocus: false))
                        }
                    }
                }
            }
        }
    }
    private var creditSpacing: CGFloat {
        #if os(tvOS)
        28
        #else
        12
        #endif
    }
    @ViewBuilder private func fileSelection(focus: MediaDetailFocusContext?) -> some View {
        if let group, group.files.count > 1 {
            MediaDetailFileSelection(kind: group.kind == .bluRay ? .disc : .segments, count: group.files.count) {
                ForEach(Array(group.files.enumerated()), id: \.element.id) { index, member in
                    MediaDetailFileRow(name: member.path.name,
                        subtitle: memberDescription(member, segment: group.kind == .segments ? index + 1 : nil),
                        accent: appearance.accent, select: canPlay(member) ? { playing = member } : nil,
                        unavailability: playbackLimitation(member) ?? .unsupportedFile,
                        focus: focus?.focus, focusID: memberFocusID(member))
                        .accessibilityIdentifier("network.file.playMember")
                        .modifier(MediaDetailFocusTarget(context: focus, id: memberFocusID(member), bindsFocus: false))
                }
            }.accessibilityIdentifier("network.file.selection")
        }
    }
    private func memberDescription(_ file: RemoteMediaEntry, segment: Int?) -> String {
        var values = segment.map { [networkL("分段 \($0)")] } ?? []
        let format = (file.path.name as NSString).pathExtension.uppercased()
        if !format.isEmpty { values.append(format) }
        if let size = file.size, size >= 0 { values.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) }
        return values.joined(separator: " · ")
    }
    private func fileInformation(focus: MediaDetailFocusContext?) -> some View {
        MediaDetailDisclosure(title: Text("文件信息"), identifier: "network.file.information",
            focus: focus?.focus, focusID: "network.file.information") {
            if metadataRead.phase(for: detailIdentity) == .failed {
                Text("补充资料暂未读取，已保留现有信息。").font(NetworkType.caption).foregroundStyle(.secondary)
            }
            MediaDetailMetadataRows {
                MediaDetailMetadataRow(title: Text("资料来源"), value: sourceLabel)
                MediaDetailFileProperties(path: current.path.displayPath,
                    container: (current.path.name as NSString).pathExtension, size: current.size,
                    containerLabel: Text("扩展名"))
                if let folder = current.path.parent {
                    MediaDetailMetadataRow(title: Text("文件夹"), value: folder.displayPath)
                }
                if metadata.artwork != nil {
                    MediaDetailMetadataRow(title: Text(networkL("封面来源")), value: networkL("源文件夹已有图片"))
                }
            }
            Button("修改本机资料") { editing = true }.font(NetworkType.caption)
                .accessibilityIdentifier("network.file.edit")
                .modifier(MediaDetailFocusTarget(context: focus, id: "network.file.edit"))
        }.modifier(MediaDetailFocusTarget(context: focus, id: "network.file.information", bindsFocus: false))
    }
    private func canPlay(_ file: RemoteMediaEntry) -> Bool {
        library.fileStationAccount == nil && model.playback != nil && file.isVideo
            && (file.path.name as NSString).pathExtension.lowercased() != "iso"
    }
}
/// The same person-card frame is used by Jellyfin and network details. Only
/// this image loader differs because the host keeps authorization in headers.
@MainActor private struct NetworkCreditPortrait: View {
    let person: MediaCredit
    let context: NetworkMediaCreditsContext?
    @State private var image: UIImage?
    @State private var loadedIdentity: String?
    private var identity: String { "credit|" + (context?.source.identity ?? "") + "|" + (person.imageID ?? "") + "|" + (person.imageTag ?? "") }
    private var displayedImage: UIImage? {
        if loadedIdentity == identity, let image { return image }
        return DecodedArtworkCache.shared.image(for: identity).map { UIImage(cgImage: $0) }
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = displayedImage {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else { MediaPersonPlaceholder() }
            }
        }.accessibilityLabel(displayedImage == nil ? "暂无人物照片" : "人物照片")
        .task(id: identity) {
            let requested = identity
            if let cached = displayedImage { image = cached; loadedIdentity = requested; return }
            guard let context, person.imageID != nil, person.imageTag != nil else { return }
            do {
                guard let data = try await context.artwork(for: person) else { return }
                let decoded = await Task.detached(priority: .utility) { () -> CGImage? in
                    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
                    return CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: 320, kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
                }.value
                try Task.checkCancellation()
                guard requested == identity, let decoded else { return }
                DecodedArtworkCache.shared.insert(decoded, for: requested)
                image = UIImage(cgImage: decoded); loadedIdentity = requested
            } catch { /* No fabricated portrait on missing/denied artwork. */ }
        }
    }
}
#endif
