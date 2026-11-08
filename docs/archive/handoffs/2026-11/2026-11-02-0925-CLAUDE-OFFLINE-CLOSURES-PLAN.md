# Claude 接续：下一批离线闭环方案（设置/偏好绑定、缓存清理取消、分享完成取消、返回保位）

2026-11-02 09:20（Asia/Shanghai）。负责人：Claude；Codex 仅负责集成、构建与窗口。**本报告只读产品源码，唯一写入本报告；没有任何编译、测试、模拟器、真机或 NAS 操作。** 所读源码是用 `device_stage_files` 取得的集成目录快照（时间约 09:11–09:20），哈希见 §6；我的 Mac 文件 shell 仍卡死，所以没有用 `grep` 全仓扫描，下列“已读”仅指实际读到的文件，其余写“待读”。承接用户 09:11“开始第 3 项”（并行排队、各出带文件范围的方案）。

## 0 排序与依赖

| 序 | 批 | 主题 | 价值/成本 | 与第七批文件冲突 |
|---|---|---|---|---|
| 1 | 第八批 | 缓存清理：确认/取消/部分失败的可测事务（D） | 小、边界清晰、能单测 | 无 |
| 1 | 第八批 | 真实偏好绑定：外观/设置在隔离偏好域内用**同一正式绑定代码**（A） | 中，依赖两条产品决定 | 无（复用既有 `.settings` 场景，不新增枚举） |
| 2 | 第九批 | 分享完成/取消的可观察状态（C） | 中，需先定产品语义 | 无 |
| 3 | 第十批 | 海报墙返回保位：先做匿名诊断而不是修复（B） | 证据不足，先观察 | **有**：要加场景，须等第七批接入后再排 |

建议把 D 与 A 合成**一个第八批**：两者都改 MineView.swift，合并能少一次“完整 App 构建+窗口”（Codex 额度紧，完整构建是主要成本）。C 与 B 之后各自成批。每批都沿用：Codex 先准备含脏改动的同源独立工作区并登记完整文件；我实施后导出补丁；Codex 做六配置构建、单测与窗口。**这些批都需要一次完整 App 构建，我在 Linux 沙箱里无法替代。**

## 1 D：缓存清理的确认/取消/部分失败

**已读事实**：`PrivacySecurityView`（MineView.swift:821–907）。点“清除缓存”只置 `showCacheConfirmation`；`NastartCacheClearPrompt`（AppTheme.swift:574）是 `confirmationDialog`，取消按钮为空闭包（`Button("action.cancel", role: .cancel) {}`），确认才调用宿主 `onClear`。`onClear` 内联在视图里，依次做：`dataStore.clearCachedSnapshot()`、`URLCache.shared.removeAllCachedResponses()`、`clearTemporaryDownloads()`（`try? removeItem` 吞错）、`WKWebsiteDataStore.default().removeData`，完成回调后才弹 `showCacheHint`。预览态 `note` 只改说明文字，不执行清理。
**缺口（均为源码观察，未运行）**：①清理逻辑与视图/单例绑死，无法单测“取消=零副作用、确认=按序执行”；②没有“清理中”状态：确认后到 `WKWebsiteDataStore` 回调之间可再次确认，提示可能重复；③`try?` 吞错，部分失败也显示成功提示；④临时目录名 `NastartDownloads/NastartPreviews` 写死在视图内。
**产品语义（待确认，默认如下）**：取消＝只在确认前有意义，零副作用；确认后的清理**不可取消**（`WKWebsiteDataStore.removeData` 不提供取消），界面在清理中禁用入口；任一步失败要在提示里说明“部分未清除”，不再一律“已清除”。
**最小方案**：新增 `PrivacyCacheCleaner`（值类型，注入四个效果闭包与步骤名；`clear() async -> Outcome(.cleared / .partial(failedSteps))`）+ 一个很小的 `CacheClearPhase` 状态（idle/confirming/clearing/done）；`PrivacySecurityView` 只换成调用它，**默认行为与步骤顺序不变**。离线夹具复用已有 `privacyCache` 场景，把注入的效果换成计数器并显示“调用次数”。
**拟改完整文件**：MineView.swift（改）、新增 `PrivacyCacheCleaner.swift`（app 目标内）、`NastartTests` 下新增 `PrivacyCacheCleanerTests.swift`；AppTheme.swift 仅在预览要显示计数时才改（拟不改）。起始哈希见 §6。
**测试**：取消零调用；确认按序一次；任一步抛错→`.partial` 且后续步骤仍执行；清理中重复确认被忽略。**窗口**：隔离合成宿主一次取消/一次确认的静态/操作观察，不动用户真实缓存（预览态）；真实清理不在本批窗口内做。
**不能证明**：真实 WKWebsiteDataStore/URLCache 的实际清除、对用户登录态的影响。

## 2 A：真实偏好绑定

**已读事实**：①正式 `AppearanceSettingsView`（MineView.swift:156）用 `@AppStorage` 绑定 `language/themeMode/showCardSubtitle`，另两个开关绑定 `AppearanceStore`；`AppearanceStore`（AppStateStores.swift:2393）的 `didSet` 与 `init` **直接写/读 `UserDefaults.standard`**，并调用 `CloudSyncStore.noteLocalChange()`。②离线设置场景（AppTheme.swift `NastartOfflineSettingsScene`，:1217 起）用 `@State fixture…`（:1226–1228）绑定，不是同一条绑定代码。③全仓没有 `defaultAppStorage`。④`NastartPlayerDefaultsRows`（AppTheme.swift:824）只显示文字（引擎摘要、“App 内优先”），**没有任何可调偏好**。⑤导出的偏好（MineView.swift:998 `Preferences.read`）只含主题/语言/显示模式/compactMetrics/showServiceStatus，不含 `showCardSubtitle` 与分组偏好（观察，是否有意未核）。
**缺口**：离线预览不能证明“真实绑定”，原因就是 `AppearanceStore` 写标准偏好域，所以才用夹具；播放器“偏好”目前不存在，不是“未绑定”。
**最小方案**：①`AppearanceStore.init(defaults: UserDefaults = .standard, noteChange: @escaping () -> Void = { CloudSyncStore.noteLocalChange() })`，`didSet` 改用注入的 defaults 与 noteChange，**默认行为不变**；②`AppearanceSettingsView`（及其跳转的主题/分组页）改为 internal，离线 `.settings` 场景改为用**临时 suite**（`UserDefaults(suiteName:)`，场景退出即删）+ `.defaultAppStorage(suite)` + `AppearanceStore(defaults: suite, noteChange: {})` 承载**正式视图**，不碰用户数据、不触发云同步；③保留夹具作为回退。
**产品决定（需你/Codex 确认）**：播放器要不要有真实偏好？候选：记住音轨/字幕（`LocalPlaybackResumeStore` 已按文件存音轨/字幕，见其 Entry）、自动续播、默认外部播放器。**未确认前不新增偏好**，本批只做外观的正式绑定可测化。
**拟改完整文件**：AppStateStores.swift（改，仅 `AppearanceStore`）、MineView.swift（改，可见性与宿主）、AppTheme.swift（改，离线设置场景换宿主）；**待读**：`NastartOfflineSettingsScene` 全文与 `LaunchpadThemeGalleryView` 对 `AppearanceStore` 的依赖，范围可能再加 1–2 个文件，开工前我会按登记哈希重核。
**测试**：`AppearanceStore` 注入 suite 的读写/默认值/非法值回落（NastartTests）；`noteChange` 默认路径仍调用 `CloudSyncStore.noteLocalChange`（用注入计数验证注入路径，不验云）。**窗口**：隔离模拟器上改开关→返回→重进，读临时 suite 中的值（匿名布尔，不读真实偏好域）；退出后 suite 已删、标准偏好域哨兵未变。
**不能证明**：真实用户偏好域迁移、云同步实际行为、Pad/大字号以外的布局。

## 3 C：分享完成/取消

**已读事实**：数据导出用 `ShareLink(item: exportText)`（MineView.swift:1112），诊断导出同类（:1423）。`ShareLink` 本身**不提供完成/取消回调**，现有记录只证明“合成宿主里呈现/取消一条流程成立”（见 11-01 导出宿主证据），不能得知用户是否真的发送。
**产品语义（待确认）**：是否需要在界面反馈“已分享/已取消”？推荐**不弹成功**（分享目标不一定产生导出），只在**失败**时说明；若要显示完成，必须换成 `UIActivityViewController` 包装以拿到 `completionWithItemsHandler`（`completed`、`activityType`、`error`），并保持“不记录导出内容与目标应用名”。
**最小方案（仅在产品确认需要反馈时）**：新增 iOS 专用 `NastartShareSheet`（`UIViewControllerRepresentable`，注入呈现与完成闭包，便于离线夹具用假呈现器模拟 completed/cancelled/failed）；三态只影响一条瞬时提示，不写盘。tvOS 无此入口，保持不变。
**拟改完整文件**：MineView.swift（两处 ShareLink）、新增 `NastartShareSheet.swift`、NastartTests 新增测试；**待读**：`exportText` 的求值时机（`ShareLink(item: exportText)` 在每次 body 求值时都会重新生成文本，是否该改成点击时才生成，我尚未核）。
**不能证明**：用户在系统分享面板里的真实选择、各目标应用的接收结果。

## 4 B：海报墙“返回保位”（先诊断，不修）

**已读事实**：`LibraryPosterWall` 的选择/分类/搜索/系列都在其 `@State`（LibraryPosterWall.swift:16–27），详情用 `navigationDestination(isPresented:)` 推入（:168、:174），`onAppear { retainCategory }`（:162）、`onDisappear { localReadRetry = nil }`（:180）；`MediaWallSelection` 每次由目录与查询重算。该文件**没有**显式滚动位置保存（`ScrollViewReader/scrollTo/scrollPosition/.id(` 均无命中），保位完全依赖 SwiftUI 默认行为。
**判断**：源码上没有看到必然丢位的写法，也没有证据证明丢位；丢位若发生，更可能来自**身份重建**（父视图 `.id`、数据整体重载、分类回落）。**离线无法判断，先做观察**：在 ≥40 项的合成目录夹具里，匿名记录“推入详情→返回”前后可见区间的粗分类（未变/回顶/跳变）与墙视图出现次数，不做帧时间结论；位移与帧时间属真机窗口。
**文件**：OfflineUIScenario.swift、OfflineMediaScene.swift（新增场景）、LibraryPosterWall.swift（仅在需要探针时）。**与第七批同文件，必须等第七批接入后再排。**

## 5 Codex 额度下的执行方式

- 我能独立完成：实现、静态自查、补丁、单测编写与交付报告。
- 需要 Codex 或你：每批一次完整 App 构建与测试（第八批含 NastartTests）、模拟器窗口、把补丁接入集成目录、同步共享状态。额度恢复前，我只做**实现与补丁**；不启动窗口。
- 起步建议：Codex 准备第八批同源独立工作区并登记 §1+§2 的文件；你先回答两个产品问题：①播放器是否要真实偏好（默认“不新增”）；②分享是否要“完成反馈”（默认“不弹成功，仅失败说明”）。

## 6 起始哈希（集成目录快照，09:1x 读取；开工前必须重核）

| 文件 | SHA-256 |
|---|---|
| ios/Nastart/Nastart/Features/Mine/MineView.swift | b34f41d2c29c9d3e0a3b05bd23946899f870dead812821e970a5f9f8347cc48b |
| ios/Nastart/Nastart/Core/Design/AppTheme.swift | a8769dc848cf79296af4b891f0bd4ff038aef8290b531a8ea12e5bc96946df7a |
| ios/Nastart/Nastart/Core/Stores/AppStateStores.swift | db181e7eb8ca491bb37bc3b10f53b88843bd8c8dee1f5ff3f4c9d536f18bb5bd |
| ios/Nastart/Nastart/Playback/Core/LocalPlaybackResumeStore.swift（只读） | acc9871c135eca65cb3dba4b6de1acfdece9a2d92fa4035604bbcdabced3a70b |
| ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryPosterWall.swift | e6a9dd46b18a4c28b4c122ade5bb0c807a04a58b4fe24a43169fc004316d0835 |
| ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryViews.swift（第七批已改，仅作参照） | a8282d4eb5d1e98e3d034f182aa1f9bab039c04a111355f1818eb5bd8f4e0b56 |

## 7 未证 / 未运行

全部为源码阅读结论，未编译、未运行、未在设备上观察。未读：`NastartOfflineSettingsScene` 全文、`LaunchpadThemeGalleryView` 依赖、`exportText` 实现、TV 侧设置页对共享行的使用、`NastartTests` 现有结构。Codex 额度：未知（界面显示本周约 10%，11 月 4 日重置）；Claude 额度：未知。NAS 暂停、iPhone18 hands off 不变；不改共享摘要、登记或需求状态。
