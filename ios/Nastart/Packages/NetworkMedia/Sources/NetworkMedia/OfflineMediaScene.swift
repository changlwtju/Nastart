#if DEBUG && (os(iOS) || os(tvOS))
import SwiftUI

/// Uses production media components, but owns only ephemeral synthetic state.
/// It deliberately never constructs NetworkLibrariesModel or a source client. The one scene
/// that does (`local-library`) is hosted by the iOS app root and never reaches this view there.
public struct OfflineMediaScene: View {
    let configuration: OfflineUIConfiguration
    let appearance: NetworkMediaAppearance
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var refreshes = 0
    public init(configuration: OfflineUIConfiguration, appearance: NetworkMediaAppearance) {
        self.configuration = configuration; self.appearance = appearance
    }
    public var body: some View {
        NavigationStack {
            Group {
                switch configuration.scenario {
                case .library, .missing: library
                case .episodes: episodePreview
                case .segmentFiles, .discFiles: fileSelectionPreview
                case .fileInformation, .emptyFileInformation: fileInformationPreview
                case .playbackISO, .playbackSource, .playbackUnsupported: playbackNoticePreview
                case .overview, .emptyOverview: overviewPreview
                case .detail: detail(OfflineMediaFixture.items[0], missing: false)
                case .longDetail: detail(OfflineMediaFixture.items[1], missing: false)
                case .missingDetail: detail(OfflineMediaFixture.items[2], missing: true)
                case .credits, .missingCredits, .creditsLoading, .creditsEmpty, .creditsError: creditsPreview
                case .connection, .connectionHTTP, .connectionEdit, .connectionError, .connectionBusy, .connectionActions:
                    OfflineWebDAVFormScene(configuration: configuration, appearance: appearance)
                case .passwordProbeSwiftUI, .passwordProbeUIKit:
                    #if os(iOS)
                    OfflinePasswordProbeScene(configuration: configuration, appearance: appearance)
                    #else
                    state(title: "此场景仅适用于 iPhone 和 iPad", symbol: "iphone", message: "已保持隔离，没有进入正常登录或连接流程。")
                    #endif
                case .correctionMovie, .correctionEpisode, .correctionError, .correctionBusy:
                    OfflineCorrectionFormScene(configuration: configuration)
                case .connections, .connectionsEmpty, .connectionsStorage:
                    OfflineConnectionsScene(configuration: configuration)
                case .sourceAdd, .sourceAddEmpty, .sourceAddConnection:
                    OfflineSourceAddScene(configuration: configuration)
                case .existingPreparing, .existingError, .existingUnavailable:
                    OfflineExistingConnectionStatusScene(configuration: configuration)
                case .connectionDetail, .connectionDetailEmpty, .connectionDetailLong:
                    OfflineConnectionDetailsScene(configuration: configuration)
                case .libraryScanning, .libraryUpdating, .libraryNotice:
                    OfflineLibraryStatusScene(configuration: configuration)
                case .wallScanning, .wallUpdating, .wallNotice, .wallReadError, .wallReadLoading,
                     .wallReadIdle, .wallReadCombined, .wallReadReady, .wallReadScanning:
                    OfflineWallStatusScene(configuration: configuration)
                case .readLoading, .readError, .readMissing, .readIdle:
                    OfflineLibraryAccessStateScene(configuration: configuration)
                case .homeReadError, .homeReadLoading, .homeReadIdle, .homeReadCombined, .homeReadReady:
                    OfflineHomeReadStatusScene(configuration: configuration)
                case .wallCategoryFallback, .wallSearchEmpty, .wallIndexEmpty, .wallExtrasHidden:
                    selectionPreview
                case .mediaEmptyLibrary, .mediaEmptySearch, .mediaEmptyError, .mediaEmptyLong:
                    emptyPresentationPreview
                case .mediaFailureInitial, .mediaFailureRetained, .mediaFailureLong:
                    failurePresentationPreview
                case .homeLoadEmpty, .homeLoadRetained, .homeLoadShelf:
                    homeLoadFailurePreview
                case .contentLoading, .contentLoadingRetained, .contentError, .contentErrorRetained,
                     .contentErrorSearch, .contentEmpty:
                    cachedContentPreview
                case .searchRetry:
                    searchRetryPreview
                case .detailNotice:
                    detailNoticePreview
                case .relatedNotice:
                    relatedNoticePreview
                case .networkFocusPresentation:
                    #if os(tvOS)
                    OfflineDetailPresentationScene(accent: appearance.accent)
                    #else
                    state(title: "电视弹层返回测试", symbol: "tv", message: "该隔离场景仅在电视模拟器提供，无网络或媒体请求。")
                    #endif
                case .networkFocusDynamic, .networkFocusLong:
                    #if os(tvOS)
                    OfflineNetworkFocusStressScene(long: configuration.scenario == .networkFocusLong, accent: appearance.accent)
                    #else
                    state(title: "电视内容变化测试", symbol: "tv", message: "该隔离场景仅在电视模拟器提供，无网络请求。")
                    #endif
                case .networkFocusFiles, .networkFocusReadOnly:
                    #if os(tvOS)
                    OfflineNetworkDetailFocusScene(readOnly: configuration.scenario == .networkFocusReadOnly, accent: appearance.accent)
                    #else
                    state(title: "电视文件选择测试", symbol: "tv", message: "该隔离场景仅在电视模拟器提供，无网络请求。")
                    #endif
                case .detailFocusRetry, .detailFocusRetryEmpty, .detailFocusRetryOnly, .detailFocusActions:
                    state(title: "电视遥控焦点测试", symbol: "tv", message: "该隔离场景仅在电视模拟器提供，无网络请求。")
                case .folderPicker, .folderPickerEmpty, .folderPickerRoot, .folderPickerLoading,
                     .folderPickerError, .folderPickerSelectionError, .folderPickerBusy:
                    OfflineFolderPickerScene(configuration: configuration)
                case .folderEdit, .folderEditChanged, .folderEditError, .folderEditBusy:
                    OfflineFolderEditorScene(configuration: configuration)
                case .empty: state(title: "媒体库暂无作品", symbol: "film", message: "添加媒体文件夹后，作品将在这里显示。")
                case .disconnected: state(title: "存储暂未连接", symbol: "externaldrive.badge.wifi", message: "已保存的媒体资料会保留。连接恢复后可继续浏览文件。")
                case .error: state(title: "暂时无法读取目录", symbol: "wifi.exclamationmark", message: "本次读取失败，原媒体库已保留。")
                case .localLibrary, .launchpadRoot, .devicesRoot, .tasksRoot: state(title: "此场景仅适用于 iPhone 与 iPad", symbol: "iphone", message: "已保持隔离，没有进入正常登录或连接流程。")
                case .accountConnections: state(title: "此场景仅适用于 Apple TV", symbol: "tv", message: "已保持隔离，没有进入正常登录或连接流程。")
                case .invalid, .mineInfo, .diagnostics, .themeGallery, .settings, .syncSettings, .privacy, .privacyReset, .privacyCache, .privacyExport, .playerSettings, .help, .helpDetail, .plus, .plusActive, .plusExpired, .plusFeatures: state(title: "离线场景参数无效", symbol: "exclamationmark.triangle", message: "已保持隔离，没有进入正常登录或连接流程。")
                }
            }
            .modifier(NetworkPageStyle())
            .background { appearance.background.ignoresSafeArea() }
            // tvOS: the content already carries the offline label; a nav title would float over
            // focused, scrolled content, most visibly at large text sizes.
            #if os(iOS)
            .navigationTitle("离线媒体测试")
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .automatic) {
                MediaLibraryMenu {
                    Button("模拟刷新") { refreshes += 1 }
                    Text("仅更新内存，不发送网络请求")
                }
            } }
        }
        .tint(appearance.accent)
        .modifier(NetworkPageStyle())
        .environment(\.networkAppearance, appearance)
        .accessibilityIdentifier("offline.ui." + configuration.scenario.rawValue)
    }
    private var banner: some View {
        Text("离线界面测试 · 合成资料" + (refreshes > 0 ? " · 已模拟刷新 \(refreshes) 次" : ""))
            .font(.caption).foregroundStyle(.secondary)
            .accessibilityIdentifier("offline.ui.banner")
    }
    private func layout(_ width: CGFloat) -> MediaPosterGridLayout {
        #if os(tvOS)
        .television(viewportWidth: width, accessibility: typeSize.isAccessibilitySize)
        #else
        .mobile(viewportWidth: width, compact: widthClass == .compact, accessibility: typeSize.isAccessibilitySize)
        #endif
    }
    private var relatedNoticePreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("合成已加载作品").font(NetworkType.caption).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 16) {
                    ForEach(OfflineMediaFixture.items.prefix(2)) { item in
                        MediaPosterCard(title: "已加载作品 \(item.id)", subtitle: "合成资料", accent: appearance.accent) {
                            OfflineFixtureArtwork(id: item.id, missing: false)
                        }.frame(width: fixturePosterWidth)
                    }
                }
                MediaLibraryNotice(title: Text("相似影片"), message: Text("相似影片读取失败"), accent: appearance.accent) {
                    fixtureFailureAction("重试")
                }
            }.frame(maxWidth: 1500, alignment: .leading).padding(24).frame(maxWidth: .infinity)
        }.navigationTitle("")
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成相关内容提示").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
    private var searchRetryPreview: some View {
        ScrollView {
            MediaLibraryEmptyState(systemImage: "exclamationmark.magnifyingglass",
                title: Text("暂时无法搜索"), detail: Text("请检查连接后重试。"), accent: appearance.accent) {
                fixtureFailureAction("重试")
            }.frame(minHeight: 320).padding(24)
        }.navigationTitle("")
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成搜索重试").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
    private var detailNoticePreview: some View {
        ScrollView {
            MediaDetailHero {
                LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
            } poster: {
                OfflineFixtureArtwork(id: 1, missing: false)
            } content: {
                VStack(alignment: .leading, spacing: 18) {
                    MediaDetailHeading(title: "山海之间", subtitle: "合成影片")
                    MediaLibraryNotice(title: Text("详情暂未更新"), message: Text("影片详情更新失败，仍可尝试播放。"),
                        accent: appearance.accent) { fixtureFailureAction("重试详情") }
                        .environment(\.colorScheme, .dark)
                }
            }.padding(24)
        }.navigationTitle("")
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成详情提示").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
    private var cachedContentPreview: some View {
        let loading = [.contentLoading, .contentLoadingRetained].contains(configuration.scenario)
        let failed = [.contentError, .contentErrorRetained, .contentErrorSearch].contains(configuration.scenario)
        let retained = [.contentLoadingRetained, .contentErrorRetained, .contentErrorSearch].contains(configuration.scenario)
        let searching = configuration.scenario == .contentErrorSearch
        return ScrollView {
            MediaLibraryContent(isLoading: loading, hasContent: retained,
                failure: failed ? Text("合成读取失败，请稍后重试。") : nil,
                failureTitle: Text("内容读取未完成"), accent: appearance.accent) {
                if searching {
                    MediaLibraryEmptyState(systemImage: "magnifyingglass", title: Text("合成搜索无结果"),
                        detail: Text("已有内容保留，当前关键词没有匹配作品。"), accent: appearance.accent)
                } else if retained {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("合成已加载内容").font(NetworkType.caption).foregroundStyle(.secondary)
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(OfflineMediaFixture.items.prefix(2)) { item in
                                MediaPosterCard(title: "已加载作品 \(item.id)", subtitle: "合成资料", accent: appearance.accent) {
                                    OfflineFixtureArtwork(id: item.id, missing: false)
                                }.frame(width: fixturePosterWidth)
                            }
                        }
                    }
                } else {
                    MediaLibraryEmptyState(systemImage: "film", title: Text("合成空内容"),
                        detail: Text("本次读取完成，列表中没有作品。"), accent: appearance.accent)
                }
            } recovery: { fixtureFailureAction("重试") }
                .frame(minHeight: retained ? nil : 300)
                .frame(maxWidth: 1500).padding(24).frame(maxWidth: .infinity)
        }.navigationTitle("")
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成内容状态").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
    private var homeLoadFailurePreview: some View {
        let retained = configuration.scenario != .homeLoadEmpty
        let shelf = configuration.scenario == .homeLoadShelf
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if retained {
                    Text("合成已加载作品").font(NetworkType.caption).foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(OfflineMediaFixture.items.prefix(2)) { item in
                            MediaPosterCard(title: "已加载作品 \(item.id)", subtitle: "合成资料", accent: appearance.accent) {
                                OfflineFixtureArtwork(id: item.id, missing: false)
                            }.frame(width: fixturePosterWidth)
                        }
                    }
                }
                if shelf {
                    MediaLibraryNotice(title: Text("继续观看"), message: Text("观看进度读取失败"),
                        accent: appearance.accent) { fixtureFailureAction("重试") }
                } else {
                    MediaLibraryLoadFailure(hasContent: retained, title: homeLoadFailureTitle,
                        message: Text("本次读取未完成，请稍后重试。"), accent: appearance.accent) {
                        fixtureFailureAction("重试")
                    }
                }
            }.frame(maxWidth: 1500, alignment: .leading).padding(24).frame(maxWidth: .infinity)
        }.navigationTitle("")
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成首页加载提示").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
    private var homeLoadFailureTitle: Text {
        #if os(tvOS)
        Text("媒体库读取未完成")
        #else
        Text("jellyfin.library.load_incomplete")
        #endif
    }
    private var failurePresentationPreview: some View {
        let retained = configuration.scenario != .mediaFailureInitial
        let long = configuration.scenario == .mediaFailureLong
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if retained {
                    Text("合成已加载作品").font(NetworkType.caption).foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(OfflineMediaFixture.items.prefix(2)) { item in
                            MediaPosterCard(title: "已加载作品 \(item.id)", subtitle: "合成资料", accent: appearance.accent) {
                                OfflineFixtureArtwork(id: item.id, missing: false)
                            }.frame(width: fixturePosterWidth)
                        }
                    }
                    MediaLibraryNotice(title: Text("后续内容暂未加载"),
                        message: Text(long ? "这是一段用于检查文字换行和错误区域布局的合成提示。后续内容本次未能读取，已显示的作品仍然保留，可继续浏览。" : "后续海报读取失败，请重试。"),
                        detail: Text("已显示的海报仍可浏览。重新加载会从头刷新列表。"), accent: appearance.accent) {
                        fixtureFailureAction("重新加载")
                    }
                } else {
                    MediaLibraryEmptyState(systemImage: "exclamationmark.triangle", title: Text("暂时无法读取媒体库"),
                        detail: Text("本次读取未完成，请稍后重试。"), accent: appearance.accent) {
                        fixtureFailureAction("重试")
                    }
                }
            }.frame(maxWidth: 1500, alignment: .leading).padding(24).frame(maxWidth: .infinity)
        }.navigationTitle("")
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成加载提示").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
    private var fixturePosterWidth: CGFloat {
        #if os(tvOS)
        150
        #else
        90
        #endif
    }
    private func fixtureFailureAction(_ title: String) -> some View {
        Button {} label: {
            Label { Text(title).foregroundStyle(Color.primary) } icon: {
                Image(systemName: "arrow.clockwise").foregroundStyle(appearance.accent)
            }
        }.accessibilityIdentifier("offline.failure.action")
        #if os(tvOS)
        .buttonStyle(NetworkTVCompactStyle())
        #else
        .buttonStyle(.borderless)
        #endif
    }
    private var emptyPresentationPreview: some View {
        let search = configuration.scenario == .mediaEmptySearch
        let error = configuration.scenario == .mediaEmptyError
        let long = configuration.scenario == .mediaEmptyLong
        return ScrollView {
            MediaLibraryEmptyState(systemImage: error ? "exclamationmark.triangle" : search ? "magnifyingglass" : "film.stack",
                title: Text(error ? "暂时无法读取媒体库" : search ? "没有找到匹配的作品"
                    : long ? "这是一个用于检查长标题与大字号换行的合成媒体库状态" : "媒体库暂无作品"),
                detail: Text(error ? "已保存的媒体资料会保留，可稍后重试。"
                    : search ? "尝试其他关键词，或返回媒体库浏览。"
                    : long ? "这是一段用于检查三端主题、文字换行和可读性的合成说明。没有连接服务器，也没有读取已保存的账号或媒体文件。"
                    : "已整理的作品会显示在这里。"), accent: appearance.accent) {
                if error || search {
                    Button {} label: {
                        Label {
                            Text(error ? "重试" : "清除搜索").foregroundStyle(Color.primary)
                        } icon: {
                            Image(systemName: error ? "arrow.clockwise" : "xmark.circle").foregroundStyle(appearance.accent)
                        }
                    }.accessibilityIdentifier("offline.empty.action")
                    #if os(tvOS)
                    .buttonStyle(NetworkTVCompactStyle())
                    #else
                    .buttonStyle(.borderless)
                    #endif
                }
            }
        }.navigationTitle("")
            .safeAreaInset(edge: .bottom) {
                Text("离线界面测试 · 合成共用空态").font(.caption2).dynamicTypeSize(.large)
                    .foregroundStyle(.secondary).padding(.vertical, 8)
                    .frame(maxWidth: .infinity).background(.background)
            }
    }
    private var selectionPreview: some View {
        let extras = configuration.scenario == .wallExtrasHidden
        let file = RemoteMediaEntry(path: try! DAVPath("Synthetic/Film.mkv"), isDirectory: false,
            metadata: .init(title: "山海之间", kind: .movie))
        let group = MediaPresentationGroup(id: "offline-selection", kind: extras ? .supplement : .video,
            files: [file], folder: nil)
        let catalog: [MediaCatalogItem] = configuration.scenario == .wallIndexEmpty ? []
            : [.init(id: group.id, category: .movies, movie: group, series: nil)]
        let selection = MediaWallSelection(catalog: catalog,
            preferredCategory: configuration.scenario == .wallCategoryFallback ? .television : .movies,
            query: configuration.scenario == .wallSearchEmpty ? "不存在的关键词" : "", includesSupplements: false,
            fileTitle: { $0.metadata?.title ?? $0.path.name })
        return GeometryReader { geometry in
            let grid = layout(geometry.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MediaLibraryHeading(title: "合成媒体库", subtitle: "")
                    if let category = selection.activeCategory {
                        Text("当前分类：" + category.title).font(NetworkType.caption).foregroundStyle(.secondary)
                    }
                    if selection.emptyState != .none {
                        NetworkLibraryWallEmptyState(state: selection.emptyState, clearSearch: {})
                    } else {
                        MediaPosterGrid(layout: grid) {
                            ForEach(selection.visibleItems) { item in
                                MediaPosterCard(title: item.title, subtitle: "合成作品", accent: appearance.accent) {
                                    OfflineFixtureArtwork(id: 1, missing: false)
                                }
                            }
                        }
                    }
                    if extras {
                        Button {} label: { Label("显示附加视频（1）", systemImage: "chevron.down") }
                            .buttonStyle(NetworkPosterCardStyle()).accessibilityIdentifier("offline.library.supplements")
                    }
                }.frame(width: grid.contentWidth).padding(.vertical, 24).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
        .safeAreaInset(edge: .bottom) {
            Text("离线界面测试 · 合成分类与搜索").font(.caption2).dynamicTypeSize(.large)
                .foregroundStyle(.secondary).padding(.vertical, 8)
                .frame(maxWidth: .infinity).background(.background)
        }
    }
    private var library: some View {
        GeometryReader { geometry in
            let grid = layout(geometry.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    banner
                    MediaLibraryHeading(title: "电影", subtitle: "")
                    MediaPosterGrid(layout: grid) {
                        ForEach(OfflineMediaFixture.items) { item in
                            NavigationLink { detail(item, missing: configuration.scenario == .missing) } label: {
                                MediaPosterCard(title: item.title, subtitle: item.year,
                                    canvas: .primary.opacity(0.06), accent: appearance.accent) {
                                    OfflineFixtureArtwork(id: item.id,
                                        missing: configuration.scenario == .missing || !item.hasArtwork)
                                }
                            }.buttonStyle(MediaPosterFocusStyle(accent: appearance.accent))
                                .accessibilityIdentifier("offline.poster.\(item.id)")
                        }
                    }
                }.frame(width: grid.contentWidth).padding(.vertical, 24).frame(maxWidth: .infinity)
            }
        }
    }
    private func detail(_ item: OfflineMediaFixture, missing: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner
                MediaDetailHero {
                    LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                } poster: {
                    OfflineFixtureArtwork(id: item.id, missing: missing || !item.hasArtwork)
                } content: {
                    MediaDetailHeading(title: item.title, subtitle: item.year, originalTitle: "A Synthetic Journey")
                }
                MediaDetailFacts(.init(rating: missing ? nil : 8.2, duration: "112 分钟"))
                MediaDetailActionRow {
                    Button {} label: { Label("播放", systemImage: "play.fill") }
                        .disabled(true)
                }.buttonStyle(MediaDetailActionStyle(accent: appearance.accent))
                if !missing {
                    MediaDetailSection(title: Text("影片简介")) {
                        MediaDetailSummary("这是一份用于检验文字层级、长简介换行和页面间距的合成资料。所有内容均保存在当前页面内，不对应任何服务器文件。")
                    }
                }
                MediaDetailInformation(studios: missing ? [] : ["合成资料工作室"]) {
                    credits(missing: missing)
                } related: { EmptyView() } supplement: {
                    MediaDetailDisclosure(title: Text("文件信息"), identifier: "offline.detail.files") {
                        Text("合成样本.mkv · HEVC · 3840×2160").font(.caption)
                    }
                }
            }.padding(pagePadding).frame(maxWidth: 1500, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
    private var playbackNoticePreview: some View {
        let reason: MediaDetailPlaybackNotice.Reason = configuration.scenario == .playbackISO ? .discImage
            : configuration.scenario == .playbackSource ? .sourceUnavailable : .unsupportedFile
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner
                VStack(alignment: .leading, spacing: 8) {
                    Text("山海之间").font(.title.weight(.bold)).foregroundStyle(.primary)
                    Text("合成影片").font(.subheadline).foregroundStyle(.secondary)
                }
                MediaDetailPlaybackNotice(reason: reason, accent: appearance.accent)
                MediaDetailFileRow(name: configuration.scenario == .playbackISO ? "山海之间.iso"
                        : configuration.scenario == .playbackSource ? "山海之间 · 合成文件.mkv" : "山海之间 · 合成文件.bin",
                    subtitle: configuration.scenario == .playbackISO ? "ISO · 48 GB" : "合成资料",
                    accent: appearance.accent, unavailability: reason)
            }.frame(maxWidth: 1100, alignment: .leading).padding(pagePadding).frame(maxWidth: .infinity)
        }
    }
    private var fileInformationPreview: some View {
        let empty = configuration.scenario == .emptyFileInformation
        let properties = MediaDetailFileProperties(path: empty ? " \n " : "/合成媒体/山海之间 The Journey Beyond the Mountains.mkv",
            container: empty ? "  " : "mkv", size: empty ? -1 : 24_000_000_000, bitrate: empty ? 0 : 48_000_000)
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner
                if properties.hasValues {
                    MediaDetailDisclosure(title: Text("文件信息"), identifier: "offline.file.information", initiallyExpanded: true) {
                        MediaDetailMetadataRows {
                            MediaDetailMetadataRow(title: Text("资料来源"), value: "合成 NFO 资料")
                            properties
                            MediaDetailMetadataRow(title: Text("文件夹"), value: "/合成媒体/影片分类/一段用于检查长路径阅读的合成目录")
                        }
                    }
                }
                Text("下一段资料 · 合成样本").font(.headline)
            }.frame(maxWidth: 1100, alignment: .leading).padding(pagePadding).frame(maxWidth: .infinity)
        }
    }
    private var fileSelectionPreview: some View {
        let disc = configuration.scenario == .discFiles
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner
                MediaDetailFileSelection(kind: disc ? .disc : .segments, count: disc ? 3 : 2) {
                    MediaDetailFileRow(name: disc ? "00001.m2ts" : "山海之间：一段很长的合成影片名称 The Journey Beyond the Mountains.CD1.mkv",
                        subtitle: disc ? "M2TS · 36 GB" : "分段 1 · MKV · 24 GB", accent: appearance.accent,
                        select: { refreshes += 1 })
                    MediaDetailFileRow(name: disc ? "00002.m2ts" : "山海之间.CD2.mkv",
                        subtitle: disc ? "M2TS · 2 GB" : "分段 2 · MKV", accent: appearance.accent,
                        select: { refreshes += 1 })
                    if disc {
                        MediaDetailFileRow(name: "合成原盘.Disc3.iso", subtitle: "ISO · 48 GB", accent: appearance.accent, unavailability: .discImage)
                    }
                }
                MediaDetailDisclosure(title: Text("文件信息"), identifier: "offline.files.information") {
                    Text("仅为合成文件，不连接存储或播放。")
                }
            }.frame(maxWidth: 1100, alignment: .leading).padding(pagePadding).frame(maxWidth: .infinity)
        }
    }
    private var episodePreview: some View {
        #if os(tvOS)
        GeometryReader { geometry in
            let grid = layout(geometry.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 35) {
                    banner
                    MediaLibraryHeading(title: "山海之间 · 第 1 季", subtitle: "")
                    MediaPosterGrid(layout: grid) {
                        ForEach(0..<7) { index in
                            Button {} label: {
                                MediaPosterCard(title: index == 1 ? "沿着星河前行：一段用于阅读测试的长标题 The Journey Beyond the Mountains" : (index == 0 ? "初到山城" : "山海之间 · 合成剧集 \(index + 1)"),
                                    subtitle: index == 2 ? "" : "第 \(index + 1) 集", aspect: 16.0 / 9.0,
                                    accent: appearance.accent) {
                                    OfflineFixtureArtwork(id: index, missing: index == 2)
                                }.frame(width: max(1, grid.itemWidth - 20), alignment: .topLeading)
                            }.buttonStyle(MediaPosterFocusStyle(accent: appearance.accent))
                                .accessibilityIdentifier("offline.episode.\(index)")
                        }
                    }.accessibilityIdentifier("offline.season.episodeGrid").accessibilityValue("\(grid.columns) 列")
                }.frame(width: grid.contentWidth, alignment: .leading)
                    .padding(.vertical, 70).frame(maxWidth: .infinity)
            }
        }
        #else
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                banner
                MediaDetailSection(title: Text("剧集")) {
                    ForEach(0..<4) { index in
                        MediaEpisodeRow(title: index == 1 ? "沿着星河前行：一段用于阅读测试的长标题 The Journey Beyond the Mountains" : ["初到山城", "", "未编号的合成剧集", "再见，山海"][index],
                            subtitle: index == 2 ? "" : "第 1 季 · 第 \(index + 1) 集",
                            progress: index == 0 ? 0.42 : (index == 3 ? 1.3 : nil), accent: appearance.accent) {
                            OfflineFixtureArtwork(id: index, missing: index == 2)
                        }.accessibilityIdentifier("offline.episode.\(index)")
                        if index < 3 { Divider() }
                    }
                }
            }.frame(maxWidth: 960, alignment: .leading).padding(pagePadding).frame(maxWidth: .infinity)
        }
        #endif
    }
    private var overviewPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner
                if configuration.scenario == .emptyOverview {
                    MediaDetailSummary(" \n \t ")
                    Text("下一段资料 · 合成样本").font(.headline)
                } else {
                    MediaDetailSection(title: Text("影片简介")) {
                        MediaDetailSummary("这是用于检查简介阅读的合成故事。旅人离开熟悉的小城，沿河流寻找记忆中的灯塔。途中有人选择停留，有人重新出发，旧信件和沿途的风景逐渐拼成完整的地图。多年以后，他们在山海尽头再次相逢。", lines: 3)
                    }
                }
            }.padding(pagePadding).frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
    private func state(title: String, symbol: String, message: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner
                Label(title, systemImage: symbol).font(.title2.weight(.semibold))
                Text(message).foregroundStyle(.secondary)
                if configuration.scenario == .error {
                    Button("重试（本地模拟）") { refreshes += 1 }
                }
            }.frame(maxWidth: 1000, alignment: .leading).padding(pagePadding).frame(maxWidth: .infinity)
        }
    }
    private var creditsPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                banner
                if let availability = creditsAvailability {
                    MediaDetailSection(title: Text("演职人员")) { MediaDetailCreditsNotice(availability: availability) }
                } else { credits(missing: configuration.scenario == .missingCredits) }
            }.padding(pagePadding)
        }
    }
    private var creditsAvailability: MediaCreditsAvailability? {
        switch configuration.scenario {
        case .creditsLoading: return .loading
        case .creditsEmpty: return .missing
        case .creditsError: return .unavailable
        default: return nil
        }
    }
    private func credits(missing: Bool) -> some View {
        MediaDetailSection(title: Text("演职人员")) {
            MediaDetailPeopleScroller {
                LazyHStack(alignment: .top, spacing: creditSpacing) {
                    ForEach(Array(creditFixtures.enumerated()), id: \.offset) { index, person in
                        MediaFocusablePerson(accent: appearance.accent) {
                            MediaDetailPersonCard(name: person.0, role: person.1) {
                                if missing || index == 1 { MediaPersonPlaceholder() }
                                else { OfflineFixtureArtwork(id: index, missing: false, person: true) }
                            }
                        }.accessibilityIdentifier("offline.person.\(index)")
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
    private var creditFixtures: [(String, String)] {
        [("克里斯托弗·诺兰 Christopher Nolan", "导演 · 编剧 · Executive Producer"),
         ("合成演员 · Alexandra Montgomery", "特别出演 · A very long character name"),
         ("未提供角色的合成人物", ""), ("测试演员 4", "演员"), ("测试演员 5", "客串"),
         ("测试演员 6", "演员"), ("测试演员 7", "演员"), ("测试演员 8", "演员"),
         ("测试演员 9", "演员"), ("测试演员 10", "演员"), ("测试演员 11", "演员"), ("人物末项 12", "客串")]
    }
    private var pagePadding: CGFloat {
        #if os(tvOS)
        70
        #else
        18
        #endif
    }
}
private struct OfflineFixtureArtwork: View {
    let id: Int
    let missing: Bool
    var person = false
    var body: some View {
        ZStack {
            if missing {
                Color.primary.opacity(0.06)
                Image(systemName: person ? "person.fill" : "photo").font(.largeTitle).foregroundStyle(.secondary)
            } else {
                LinearGradient(colors: id.isMultiple(of: 2) ? [.indigo, .teal] : [.brown, .orange],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: person ? "person.crop.square.fill" : "film")
                    .font(.largeTitle).foregroundStyle(.white.opacity(0.8))
            }
        }.accessibilityHidden(true)
    }
}
#endif

#if DEBUG && os(tvOS)
/// Uses the production focus scope and file/person/disclosure controls; no source model.
private struct OfflineNetworkDetailFocusScene: View {
    let readOnly: Bool
    let accent: Color
    @State private var selections = 0
    @State private var overviewVisible = true
    private let choiceIDs = ["network.file.member.one", "network.file.member.two"]
    private let personIDs = ["network.detail.person.one", "network.detail.person.two"]
    private var map: MediaDetailFocusMap {
        .init(actions: readOnly || !overviewVisible ? [] : ["network.file.overview"], people: readOnly ? [] : personIDs,
            related: [], relatedRetry: nil, files: "network.file.information",
            fileChoices: readOnly ? [] : choiceIDs)
    }
    var body: some View {
        MediaDetailFocusScope(map: map, nativeIDs: ["network.file.edit"]) { focus in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("离线界面测试 · 合成文件选择").font(.system(size: 25, weight: .semibold))
                    if !readOnly && overviewVisible {
                        MediaDetailActionRow {
                            Button("更新简介（合成操作）") { overviewVisible = false }.buttonStyle(MediaDetailActionStyle(accent: accent))
                                .accessibilityIdentifier("network.file.overview")
                                .modifier(MediaDetailFocusTarget(context: focus, id: "network.file.overview"))
                        }
                    }
                    MediaDetailFileSelection(kind: .segments, count: readOnly ? 1 : 3) {
                        if !readOnly {
                            ForEach(Array(choiceIDs.enumerated()), id: \.element) { index, id in
                                MediaDetailFileRow(name: "合成分段 \(index + 1).mkv", subtitle: "仅验证选择，不播放媒体",
                                    accent: accent, select: { selections += 1 }, focus: focus.focus, focusID: id)
                                    .accessibilityIdentifier(id)
                                    .modifier(MediaDetailFocusTarget(context: focus, id: id, bindsFocus: false))
                            }
                        }
                        MediaDetailFileRow(name: "合成原盘.iso", subtitle: "只读说明", accent: accent,
                            unavailability: .discImage)
                            .accessibilityIdentifier("network.file.readOnly")
                    }
                    if !readOnly {
                        MediaDetailSection(title: Text("演职人员")) {
                            MediaDetailFocusedPeople(context: focus, ids: personIDs) {
                                LazyHStack(spacing: 28) {
                                    ForEach(Array(personIDs.enumerated()), id: \.element) { index, id in
                                        MediaFocusablePerson(accent: accent, focus: focus.focus, focusID: id) {
                                            MediaDetailPersonCard(name: "合成人物 \(index + 1)", role: "演员") { MediaPersonPlaceholder() }
                                        }.accessibilityElement(children: .combine).accessibilityIdentifier(id)
                                            .modifier(MediaDetailFocusTarget(context: focus, id: id, bindsFocus: false))
                                    }
                                }
                            }
                        }
                    }
                    MediaDetailDisclosure(title: Text("文件信息"), identifier: "network.file.information",
                        focus: focus.focus, focusID: "network.file.information") {
                        Text("合成文件，不读取源目录").font(.system(size: 20))
                        Button("修改本机资料（合成操作）") {}.accessibilityIdentifier("network.file.edit")
                            .modifier(MediaDetailFocusTarget(context: focus, id: "network.file.edit"))
                    }.modifier(MediaDetailFocusTarget(context: focus, id: "network.file.information", bindsFocus: false))
                    Text("选择次数：\(selections)").font(.system(size: 20)).accessibilityIdentifier("offline.file.receipt")
                    Text("合成焦点：" + (focus.focus.wrappedValue ?? "无") + "；请求：" + (focus.requested.wrappedValue ?? "无"))
                        .font(.system(size: 16)).accessibilityIdentifier("offline.file.focus")
                }.padding(70)
            }
        }
    }
}
#endif

#if DEBUG && os(tvOS)
/// Synthetic capability/metadata changes and long rows, sharing the production scope.
private struct OfflineNetworkFocusStressScene: View {
    let long: Bool
    let accent: Color
    @State private var phase = 0
    @State private var secondDisabled = false
    private var fileIDs: [String] { (1...(long ? 12 : 2)).map { "offline.change.file.\($0)" } }
    private func selectable(_ index: Int) -> Bool { long || (phase < 3 && (index != 1 || !secondDisabled)) }
    private var names: [String] {
        if long { return (1...18).map(String.init) }
        switch phase {
        case 0: return ["A", "B", "C"]
        case 1: return ["C", "A", "B"]
        case 2, 3: return ["C", "B"]
        default: return []
        }
    }
    private var people: [MediaCredit] {
        names.map { MediaCredit(name: "合成人物 " + $0, role: "演员",
            imageID: phase == 0 ? nil : "synthetic-portrait-" + $0, imageTag: phase == 0 ? nil : "synthetic-version") }
    }
    private var personIDs: [String] { MediaDetailFocusMap.personIDs(for: people) }
    private var map: MediaDetailFocusMap {
        .init(actions: ["offline.change.overview"], people: personIDs, related: [], relatedRetry: nil,
            files: "offline.change.info", fileChoices: fileIDs.enumerated().filter { selectable($0.offset) }.map(\.element))
    }
    var body: some View {
        MediaDetailFocusScope(map: map, nativeIDs: ["offline.change.edit"], diagnosticsEnabled: ProcessInfo.processInfo.arguments.contains("--offline-focus-trace")) { focus in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(long ? "离线界面测试 · 长列表" : "离线界面测试 · 合成资料变化")
                        .font(.system(size: 25, weight: .semibold))
                    Button("简介（合成操作）") {}.buttonStyle(MediaDetailActionStyle(accent: accent))
                        .accessibilityIdentifier("offline.change.overview")
                        .modifier(MediaDetailFocusTarget(context: focus, id: "offline.change.overview"))
                    MediaDetailFileSelection(kind: .segments, count: fileIDs.count) {
                        ForEach(Array(fileIDs.enumerated()), id: \.element) { index, id in
                            MediaDetailFileRow(name: "合成分段 \(index + 1).mkv", subtitle: "仅合成选择，无媒体请求",
                                accent: accent, select: selectable(index) ? {
                                    if !long && index == 1 { secondDisabled = true }
                                } : nil, unavailability: .sourceUnavailable, focus: focus.focus, focusID: id)
                                .accessibilityIdentifier(id)
                                .modifier(MediaDetailFocusTarget(context: focus, id: id, bindsFocus: false))
                        }
                    }
                    if !people.isEmpty {
                        MediaDetailSection(title: Text("演职人员")) {
                            MediaDetailFocusedPeople(context: focus, ids: personIDs) {
                                LazyHStack(spacing: 28) {
                                    ForEach(Array(people.enumerated()), id: \.offset) { index, person in
                                        let id = personIDs[index]
                                        MediaFocusablePerson(accent: accent, focus: focus.focus, focusID: id) {
                                            MediaDetailPersonCard(name: person.name, role: person.role) { MediaPersonPlaceholder() }
                                        }.accessibilityElement(children: .combine)
                                            .accessibilityIdentifier("offline.change.person." + names[index])
                                            .modifier(MediaDetailFocusTarget(context: focus, id: id, bindsFocus: false))
                                    }
                                }
                            }
                        }
                    }
                    MediaDetailDisclosure(title: Text("文件信息"), identifier: "offline.change.info",
                        focus: focus.focus, focusID: "offline.change.info") {
                        Text("合成信息，不读取源文件").font(.system(size: 20))
                        Button("修改资料（合成操作）") {}.accessibilityIdentifier("offline.change.edit")
                            .modifier(MediaDetailFocusTarget(context: focus, id: "offline.change.edit"))
                    }.modifier(MediaDetailFocusTarget(context: focus, id: "offline.change.info", bindsFocus: false))
                    Text("资料版本：\(phase)").font(.system(size: 20)).accessibilityIdentifier("offline.change.version")
                    Text("合成焦点：" + (focus.focus.wrappedValue ?? "无") + "；请求：" + (focus.requested.wrappedValue ?? "无") + "；记录：" + focus.diagnostic)
                        .font(.system(size: 16)).accessibilityIdentifier("offline.change.focus")
                }.padding(70)
            }.onPlayPauseCommand { if !long && phase < 4 { phase += 1 } }
        }
    }
}

/// Only system presentations and production detail controls; no editor or player.
private struct OfflineDetailPresentationScene: View {
    let accent: Color
    @State private var editing = false
    @State private var selected: OfflinePresentationFile?
    @State private var sheetReturns = 0
    @State private var coverReturns = 0
    private let choices = ["offline.presentation.file.1", "offline.presentation.file.2"]
    private var map: MediaDetailFocusMap {
        .init(actions: ["offline.presentation.overview"], people: [], related: [], relatedRetry: nil,
            files: "offline.presentation.info", fileChoices: choices)
    }
    var body: some View {
        MediaDetailFocusScope(map: map, nativeIDs: ["offline.presentation.edit"], diagnosticsEnabled: ProcessInfo.processInfo.arguments.contains("--offline-focus-trace")) { focus in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("离线界面测试 · 弹层返回").font(.system(size: 25, weight: .semibold))
                    Button("简介（合成操作）") {}.buttonStyle(MediaDetailActionStyle(accent: accent))
                        .accessibilityIdentifier("offline.presentation.overview")
                        .modifier(MediaDetailFocusTarget(context: focus, id: "offline.presentation.overview"))
                    MediaDetailFileSelection(kind: .segments, count: choices.count) {
                        ForEach(Array(choices.enumerated()), id: \.element) { index, id in
                            MediaDetailFileRow(name: "合成分段 \(index + 1).mkv", subtitle: "仅打开无播放器的全屏占位页",
                                accent: accent, select: { selected = OfflinePresentationFile(id: id) },
                                focus: focus.focus, focusID: id)
                                .accessibilityIdentifier(id)
                                .modifier(MediaDetailFocusTarget(context: focus, id: id, bindsFocus: false))
                        }
                    }
                    MediaDetailDisclosure(title: Text("文件信息"), identifier: "offline.presentation.info",
                        focus: focus.focus, focusID: "offline.presentation.info") {
                        Text("合成信息，不读取或保存资料").font(.system(size: 20))
                        Button("修改资料（合成弹层）") { editing = true }
                            .accessibilityIdentifier("offline.presentation.edit")
                            .modifier(MediaDetailFocusTarget(context: focus, id: "offline.presentation.edit"))
                    }.modifier(MediaDetailFocusTarget(context: focus, id: "offline.presentation.info", bindsFocus: false))
                    Text("编辑返回：\(sheetReturns)；全屏返回：\(coverReturns)")
                        .font(.system(size: 20)).accessibilityIdentifier("offline.presentation.receipt")
                    Text("合成焦点：" + (focus.focus.wrappedValue ?? "无") + "；请求：" + (focus.requested.wrappedValue ?? "无"))
                        .font(.system(size: 16)).accessibilityIdentifier("offline.presentation.focus")
                }.padding(70)
            }
            .sheet(isPresented: $editing, onDismiss: { sheetReturns += 1 }) {
                OfflineDetailPresentationDestination(kind: "sheet", accent: accent)
            }
            .fullScreenCover(item: $selected, onDismiss: { coverReturns += 1 }) { _ in
                OfflineDetailPresentationDestination(kind: "cover", accent: accent)
            }
        }
    }
}
private struct OfflinePresentationFile: Identifiable { let id: String }
private struct OfflineDetailPresentationDestination: View {
    let kind: String
    let accent: Color
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 28) {
            Text(kind == "sheet" ? "合成编辑弹层" : "合成全屏占位页").font(.title2)
            Text("只验证系统呈现与焦点返回，无资料提交或媒体播放").font(.system(size: 24))
            Button("关闭") { dismiss() }.buttonStyle(MediaDetailActionStyle(accent: accent))
                .accessibilityIdentifier("offline.presentation." + kind + ".close")
        }.padding(70).onExitCommand { dismiss() }
    }
}

#endif
