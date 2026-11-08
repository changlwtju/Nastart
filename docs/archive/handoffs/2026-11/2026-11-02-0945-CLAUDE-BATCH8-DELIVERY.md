# Claude 第八批交付：缓存清理可测化（D）+ 外观偏好正式绑定可测化（A）

2026-11-02 09:45（Asia/Shanghai）。负责人 Claude。**未编译、未运行、未测试**：我的执行环境没有 Swift/Xcode，Mac 终端对我是“只可点击”；本批所有结论仅来自源码阅读、`git apply --check`、括号配平自查。需要 Codex 或用户在 Mac 上跑 §6 的编译脚本。承接 `0925-CLAUDE-OFFLINE-CLOSURES-PLAN` 的 D+A 合批；产品决定：分享（C）按默认“不弹成功、仅失败说明”（本批不含 C）；播放器偏好本批不新增。

## 1 范围与边界
- 工作区：`/Users/lagransun/workspace/Nastart-Claude-Closures-20261102`（由集成目录整体复制，含脏改动；未做任何 git 提交/检出，仅复制）。集成目录**未被改动**。
- 只改 6 个已有文件，**没有新增文件**（避免改 `project.pbxproj`）。偏离方案之处：方案写“新增 `PrivacyCacheCleaner.swift` 与测试文件”，实际放进 `AppStateStores.swift` 与现有 `NonPlaybackPolicyTests.swift`，原因即上。
- 未碰：NAS、设备、模拟器、Runner、PROGRESS、当前交接、资源登记、需求状态；未启动任何 App。

## 2 改动（起止 SHA-256，完整）
| 文件（ios/Nastart/…） | 起 | 止 |
|---|---|---|
| Nastart/Core/Stores/AppStateStores.swift | db181e7eb8ca491bb37bc3b10f53b88843bd8c8dee1f5ff3f4c9d536f18bb5bd | b035f7e9e6e06d1352511a1e2134e1bbe78e7ca520f0ef252e9f776111cca484 |
| Nastart/Features/Mine/MineView.swift | b34f41d2c29c9d3e0a3b05bd23946899f870dead812821e970a5f9f8347cc48b | e9b80b32a886d5e7e3730f17bfc594cee9d0381ae9d8c1bef7ec4f83571625aa |
| Nastart/Core/Design/AppTheme.swift | a8769dc848cf79296af4b891f0bd4ff038aef8290b531a8ea12e5bc96946df7a | 5f95e81f437f60c158c5666bcd42e2d80dd6a7a8e3bf7312134490d92b948b32 |
| Nastart/en.lproj/Localizable.strings | c1f50e858b61f47ad48f12b6e0f8b6de073fa57f4147cc24eb9936f1ef065fc7 | 68e954e2ed17ac3402e4bd69feb5d35a129d0dede4ea4e7bf0829edea72658b9 |
| Nastart/zh-Hans.lproj/Localizable.strings | ba27257081a6c34fcffcc1b295d51f27642331b98fee98bf74fcdb0f021fa412 | 948639deb9a5ac48f176dd30b4292b8b27e3ec81a13ec5cc8bb07e8f27fc0088 |
| NastartTests/NonPlaybackPolicyTests.swift | cdd7e82384c0dce4b7f18e1db9fdcc3d4909a6d99710b08cfa9038ba18353728 | 274eacdfeca54075b8a789f2106c59c0f18d6913d2e5aeedfb3b780dae991637 |

补丁：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-batch8/claude-batch8.patch`，27492 字节，sha256 `5bc9a52ba164b573ade7aeacd5c01bd0a25f6e2be6beafd7c642ffa01378c5fd`，6 文件 +358 −54。`git -C <集成目录> apply --check` exit 0（已实测）。完整文件副本在同目录 `files/`；`files/_to_delete/` 是我误生成的重复副本（沙箱无删除权限，已移入该目录，可由你删除，内容无意义）。

### D 缓存清理（AppStateStores.swift、MineView.swift、AppTheme.swift、两份 Localizable）
- 新增 `PrivacyCacheCleaner`（值类型）：`Step(name, run: @MainActor () async throws -> Void)`；`clear() async -> .cleared | .partial(failedSteps:)`，按序执行，某步失败**不跳过**后面步骤；`removeTemporaryDirectories(named:in:fileManager:)`：目录不存在算成功，其余错误全部尝试后再抛第一个（原来 `try?` 吞错）。
- `PrivacySecurityView`：确认后 `guard !cacheClearing` → `Task { 清理 → 记录是否部分失败 → 解除禁用 → 弹提示 }`；清理期间“清理缓存”入口 `.disabled`，重复确认被忽略；步骤顺序保持：快照 → URLCache → 临时文件 → 网页数据（现用 `async` 版 `removeData`，原为回调+`DispatchQueue.main`）。提示标题新增 `mine.privacy.clear_cache_partial`（中英已加）。
- `NastartCacheClearPrompt` 新增可选 `onCancel`（默认空，所有现有调用不变）。离线 `privacyCache` 场景：计数“确认清理 N 次 / 点击取消 M 次”（`offline.privacy.cache-counters`），仍不清理任何东西。
- **语义**：取消＝零副作用（清理器此时根本未被创建）；确认后的清理不可取消（`WKWebsiteDataStore.removeData` 无取消）。

### A 外观偏好（AppStateStores.swift、MineView.swift、AppTheme.swift）
- `AppearanceStore.init(defaults: UserDefaults = .standard, noteChange: @escaping () -> Void = { CloudSyncStore.noteLocalChange() })`；三个 `@Published` 的 `didSet` 与 `reloadFromDefaults` 改用注入的 defaults/通知。**默认行为与以前逐行等价**（`NastartApp` 仍调用 `AppearanceStore()`）。
- `AppearanceSettingsView` 拆出两个内部视图 `AppearanceModeRows`（语言、显示模式两个 `@AppStorage` Picker）与 `LaunchpadCardOptionRows`（三项卡片开关），正式页面行序不变。
- 离线 `settings → 外观`（仅 iOS）：不再用 `@State` 夹具，改为承载**同一批正式行**，由 `OfflineAppearanceHost`（临时合成偏好域 `nastart.offline-ui.appearance`，创建/销毁时清空；`AppearanceStore(defaults: suite, noteChange: {})`）+ `.defaultAppStorage(suite)` 提供存储。页内“临时偏好域读回”显示：语言/显示/主题原始值、三个开关，以及标准偏好域里卡片副标题键的当前值（应保持不变；`offline.appearance.readback.{choices,toggles,standard}`）。tvOS 分支保持原夹具。
- 离线根的注释已改为如实说明：这是唯一构造 `AppearanceStore` 的离线场景，且只绑定临时域、通知为空。

## 3 新增单测（均在 `NonPlaybackPolicyTests.swift` 末尾，未运行）
`AppearanceStoreInjectionTests` ×5：空域默认值；改动只写入注入域且通知 3 次、标准域同键不变；从注入域恢复；非法主题回落；`reloadFromDefaults` 读注入域。`PrivacyCacheCleanerTests` ×4：按序一次且 `.cleared`；失败步不跳过后续且上报；缺失目录视为成功并删除已有；`FileManager` 子类令 A 删除失败时仍删除 B 后抛错。

## 4 未被证明的东西
- 能否编译：未知。风险点自查：`Step` 的 `@MainActor` 闭包与 Swift 5 并发检查；`UserDefaults(suiteName:)` 强制解包仅在 DEBUG 离线夹具（`preconditionFailure`）；`@AppStorage(…, store:)` 的 `init(wrappedValue:_:store:)` 写法；`#elseif os(iOS)` 分支。以上均须以编译结果为准。
- 取消零副作用：由结构保证（取消路径不调用清理器），**没有**单测或窗口实证；窗口只能观察计数。点击空白处关闭对话框是否也触发取消按钮，是未确认现象（计数文案写“点击取消”而非“已取消”）。
- 真实 `URLCache`/`WKWebsiteDataStore`/临时目录的实际清理、对登录态的影响：未测。
- 偏好真实落盘与云同步：未测；通知只在默认路径调用，注入路径不调用。
- 导出的偏好仍不含卡片副标题与分组偏好（观察项，本批未改，是否有意待定）。

## 5 窗口（待 Codex 额度或用户同意，隔离模拟器，不碰真机/NAS）
1. `--offline-ui settings` → 外观：切语言/显示/三开关 → 返回再进 → 读回文本应与所选一致；标准域同键行始终“未设置”或原值；重启进程后读回应为空（启动即清域）。
2. `--offline-ui privacy-cache`（标准与 large 字号）：对话框自动弹出 → 点取消 → 计数“取消 1”；再进 → 确认 → “确认 1”；离线提示文字出现；未清理任何东西。
3. 手工/Codex：正式页在模拟器里真清一次（模拟器上的缓存），确认提示为“已完成”；制造失败的方法暂无，部分失败提示只由单测覆盖。

## 6 Codex / 用户需要做的（我无法做）
1. 评审并应用补丁到集成目录（或接受独立工作区作为参照），然后在 Mac 终端运行 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-batch8/run-verify-batch8.sh`：**默认只编译**（Debug `build-for-testing`、Release `build`、Release 产物标记扫描：`OfflineAppearanceHost` 等应为 0），不运行测试、不启动 App、不碰设备/NAS。
2. 单测执行（`RUN_TESTS=1`）前请先确认：`Nastart` 测试 bundle 是 app-hosted（`TEST_HOST`），启动会拉起正常根视图；在 NAS 暂停的约束下，需 Codex 确认该宿主启动不会恢复 NAS（之前 Codex 的 `xcodebuild … test` 已在做同样的事，由你们判断）。若不确定，保持不跑。
3. 共享状态更新（Codex 独写）：`PROGRESS`/交接/登记中加入 claudeBatch8、新增 UI 标识符 `offline.appearance.readback.*`、`offline.privacy.cache-counters`、临时偏好域名，以及“偏好导出缺卡片副标题/分组偏好”的观察项。
4. 若编译失败：请把原始错误交回，我按明确原因修正。

## 7 工作区说明
`Nastart-Claude-Closures-20261102` 是 `cp -a` 的整仓复制（含 Pods，约 608MB）；没有 git 提交、没有锁文件产生。需要时可由你整体删除。

## 8 状态
Codex 额度：未知；Claude 额度：未知。第七批补丁仍待 Codex 接入；NAS 暂停、iPhone18 hands off、Apple TV 签名阻塞不变。
