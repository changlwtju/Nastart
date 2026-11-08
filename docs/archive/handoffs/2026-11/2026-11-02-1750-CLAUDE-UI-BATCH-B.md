# Claude（本地会话）：UI 清单 B 批（测试横幅修复 + 三个根页面离线方案）

2026-11-02 17:50（Asia/Shanghai）。对应 [UI 清单](2026-11-02-1735-CLAUDE-UI-INVENTORY-IPHONE-PORTRAIT.md) 的 #10 和覆盖缺口。没有访问 NAS、没有局域网发现、没有操作真机或 Runner。

## B1：测试横幅遮挡正文（已修，已复验）

- 根因：
  - 6 个离线场景的底部横幅（`LibraryViews.swift` 中的连接管理、文件夹、资料、添加页、连接状态、文件夹选择）用了 `safeAreaInset`，但横幅本身没有背景。滚动内容会画到底部安全区下面，大字号时正文透出来和横幅叠在一起。
  - `MineView.swift` 的“Offline fixture”横幅同样没有背景，而且不限字号。
  - 分享探针条（系统面板/完成/取消/失败）的文字随大字号放大，占掉大片屏幕。
- 修复：
  - 6 个横幅补上 `.frame(maxWidth: .infinity).background(.background)`，与其余横幅一致。
  - “Offline fixture”横幅补上背景并限制在 `.large` 字号。
  - 分享探针条限制在 `.large` 字号。
- 只影响 DEBUG 离线场景，不影响正式界面。
- 复验：大字号重拍 12 个受影响场景，正文在横幅上沿干净截断，探针条恢复紧凑（证据 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/batchB1-large/`）。

| 文件 | 改前 SHA-256 | 改后 SHA-256 |
| --- | --- | --- |
| `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/LibraryViews.swift` | 47b7e4e7…43e0（A 批之后） | eded1386…89bc |
| `ios/Nastart/Nastart/Features/Mine/MineView.swift` | 0caad256…28c5 | b88e537b…60b |

- iOS 模拟器 Debug（ad-hoc 签名）增量构建通过，debug.dylib `f50b63bde78b2723b7ffe078c1c3ad431f4217d18d26b10b55b34a0d5dec7f1f`。
- **未执行**：tvOS 构建、六配置全量、Release 检查。

## B2：启动台、设备、事项根页面的离线场景（只出方案，未实施）

不能直接加场景，原因：

1. 三个根页面都依赖 `AppDataStore` 和 `NASConnectionStore`（启动台还依赖 `EntitlementStore`、`AppearanceStore`）。
2. `AppDataStore(provider:)` 即使传入 `MockAppDataProvider`，也会：
   - 读取本机持久化的待办，以及启动台显示/排序设置和手动添加的服务；
   - 给待办排系统通知；
   - 没有传 provider 时，还会读回本机保存的 NAS 快照。
3. `NASConnectionStore()` 初始化时会从钥匙串读代理连接。
4. 启动台出现时调用 `dataStore.refreshServiceHealth()` 探测服务地址；`onAppear` 还会写分组迁移设置。服务列表一旦来自本机保存的 NAS 快照，这一步就会访问真实 NAS，违反 NAS 暂停边界。

**建议方案**（需要你确认后才实施）：

- `AppDataStore` 加一个仅 DEBUG 的隔离初始化，只用内存合成数据：不读写持久化，不排通知，`refreshServiceHealth` 和刷新直接返回。
- `NASConnectionStore` 加一个仅 DEBUG 的空初始化，不读钥匙串。
- 新增三个离线场景 `launchpad-root`、`devices-root`、`tasks-root`，由 `NastartOfflineUIRoot` 注入上述隔离 store 后承载正式根视图。
- 启动台的分组迁移、设备页的目录加载、事项的通知授权，在隔离 store 下都应是空操作；需要逐一核对。
- 涉及文件：`AppStateStores.swift`、`NASConnectionStore.swift`、`AppTheme.swift`、`OfflineUIScenario.swift`、`OfflineMediaScene.swift`、`OfflineUIScenarioTests.swift`，可能还有 `LaunchpadView.swift`。
- 风险：改动触及核心 store，需要单测证明正常启动路径不变（不传参时行为与现在一致），并跑一次六配置全量。

共享状态（PROGRESS、当前交接、需求总账）未改，由 Codex 汇总。
