# Cloud 同步拆分（大目标 1）

**日期**：2026-11-21
**总纲**：[大目标总纲](./BIG-TARGETS-ROADMAP.md)
**范围**：只做不碰付费服务的部分。生产 CloudKit 容器（`iCloud.com.changliwen.nastart`）与真机跨设备实测需苹果付费开发者计划（$99/年），暂缓；本拆分只做本地可实现、可测试的部分。

## 现状（已核实，2026-11-21 读码）

- 文件：`ios/Nastart/Nastart/Core/Stores/CloudSyncStore.swift`（417 行）。
- 快照：`CloudSyncSnapshot`（schemaVersion 1），单条 CloudKit 记录，recordType `NastartSnapshot`、recordName `primary-workspace`。
- 快照字段：`manualServices: [StoredManualLaunchpadService]`、`serviceVisibilityOverrides: [String: Bool]`、`pendingTasks: [TaskItem]`、`completedTasks: [TaskItem]`、`stringPreferences: [String: String]`、`booleanPreferences: [String: Bool]`，另有 `schemaVersion`、`updatedAt`。
- 合并：`CloudSyncMergePolicy.decision` 只按时间戳，整条快照后写胜出（`.applyRemote` / `.uploadLocal`），无字段级合并、无冲突界面。
- 入口：`CloudSyncStore.shared`，`isEnabled`、`syncNow(dataStore:appearanceStore:)`、`scheduleSync()`、`markLocalChange()`；`NastartApp.swift` 在启动/前台/恢复时触发。
- 开关：MineView 用 `entitlementStore.canUse(.iCloudSync)` 门控（Plus 权益）。
- Entitlements：Release 有 CloudKit（`iCloud.com.changliwen.nastart`），Debug 没有。电视端未接同步。
- 未同步的内容：播放进度/续播点、媒体库索引、收藏（除非落在偏好里）、NAS/Jellyfin 凭据（Keychain，本就不应同步）。

## 拆分件（按序，一件一交接）

### 第 1 件：按域拆记录 + v1 迁移

- **目标**：把单条 `NastartSnapshot` 拆成三条按域记录，各自带 `updatedAt`，各自按时间戳合并。改一域不触动其他域，不再整包覆盖。
  - `NastartServices`：`manualServices` + `serviceVisibilityOverrides`。
  - `NastartTasks`：`pendingTasks` + `completedTasks`。
  - `NastartPreferences`：`stringPreferences` + `booleanPreferences`。
- **文件**：`ios/Nastart/Nastart/Core/Stores/CloudSyncStore.swift`（主改）；`ios/Nastart/Nastart/App/NastartApp.swift`（调用点如需调整）。
- **做到**：三条记录的编解码、上传/下载、按记录合并；schemaVersion 升到 2；v1 单记录能迁移到 v2（读旧记录、分写入新记录、删旧记录或标记已迁移）；`syncNow` 按记录分别同步。
- **不做**：删除 tombstone（第 2 件）、电视端（第 3 件）、状态 UI（第 4 件）、生产容器（暂缓）。
- **验收**：mock CloudKit 的单元测试——只改任务时 services 记录不动；只改可见性时 tasks 记录不动；v1 旧记录迁移后三条新记录内容一致；合并仍按时间戳每记录独立判断。

### 第 2 件：任务删除 + tombstone（目标已定，2026-11-22）

- **关键发现**：任务至今没有删除入口（`AppDataStore` 只有 add/set/complete，`TasksView` 只有“完成”按钮，`LocalTaskStore` 只有 save/load）。没有删除，tombstone 无触发点；没有 tombstone，加删除会被旧快照复活。故本件“加删除 + 加 tombstone”一起做。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-02-TASK-TOMBSTONE-2026-11-22.md`
- **目标**：新增 `AppDataStore.deleteTask`（两表移除 + 取消提醒 + 写 tombstone + 持久化）；`TasksView` 待处理与历史列表加 `.onDelete`；`DeletedTask {id: UUID, deletedAt: Date}` 存 `LocalTaskStore`（key `"tasks.deleted.v1"`），进 `CloudSyncTasks` 载荷（缺失默认 `[]`）；合并时 tombstone 按 ID 取并集、恒胜同 ID 任务；保留 30 天（`tombstoneRetentionDays = 30`）。
- **文件**：`AppStateStores.swift`、`LocalTaskStore.swift`、`CloudSyncStore.swift`、`NASModels.swift`、`TasksView.swift`、测试 `NonPlaybackPolicyTests.swift`。
- **不做**：其他域的删除（服务/偏好删除走整记录覆盖，不加 tombstone）；电视端（第 3 件）；状态 UI（第 4 件）。
- **验收**：mock CloudKit 单元测试——A 删后 B 用旧快照同步不复活及反向、删历史任务不复活、超 30 天 tombstone 被丢弃、删除取消提醒并持久化、删任务不触动 services/preferences 记录。
- **实施进度**：Xcode 26.6 模拟器 Debug 构建及 17 项定向测试通过。已验收（2026-11-22，见验收记录）指定设备上的滑动删除和冷启动。 [Codex 交回](../archive/handoffs/2026-11/CODEX-2026-11-22-CLOUD-SYNC-PIECE-02-TASK-TOMBSTONE.md)

### 第 3 件：电视端同步（服务记录）（**已验收**，2026-11-22）

- **验收**：Muse 复跑 iOS 18 项 + tvOS 23 项 mock 全过；Xcode 27.2 签名 tvOS Debug 包（主程序 SHA `15c5ea2c…ed30d`）保留数据覆盖安装到 Apple TV 客厅，探针 `testPiece03TVServicesAcceptance` 全过——DSM 登录与服务清单、「管理显示」开关（`homepage` 显示→隐藏）、冷启动后保留、开关已恢复原状、iCloud 页服务同步范围文案（无旧“未开通”提示）。跨设备云行为以 mock 验收。验收记录 `docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-22-CLOUD-SYNC-PIECE-03-ACCEPTANCE.md`。

- **关键发现**：电视端目前没有同步（iCloud 页挂 `NastartTVSyncOverview`，注释写明“never creates a CloudKit store”，显示不可用）；`CloudSyncStore.swift` 只在 iOS target 里，电视编不到；电视没有 entitlements。**键不匹配是核心**：iOS 可见性键是 `launchpadVisibilityKey`（容器 `"container|<name>|<detail>"`、套件 `"package|<detail>"`），电视键是 `"container:<id>"` / `"package:<id>"`，直接同步会对不上；且 iOS 容器 `detail` 在 Agent 路径下是 `"Agent · <port>"`，电视容器 `detail` 是镜像名，含义不同。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-03-TV-SERVICES-2026-11-22.md`
- **目标**：电视读写 `NastartServices` 记录的**可见性开关**（只读写 `serviceVisibilityOverrides`，不碰 `manualServices`，上传时原样保留）；抽公共模型到两端共享；iOS 的 `launchpadVisibilityKey` 为准，电视本地 `@AppStorage("tv.service.visibility.v1")` 改用这套键，旧键开关按当前已发现服务重 keyed、一次迁移；电视启动与前台时拉取、改可见性后上传，按 `updatedAt` 合并；iCloud 页服务同步不再显示不可用。
- **文件**：电视端 store（新建）；`CloudSyncStore.swift`（抽公共模型）；`TVNASViews.swift`（启动台过滤与管理显示走新键、iCloud 页）；`TVDSMClient.swift`（如需，键计算对齐）。
- **不做**：电视同步任务与偏好；电视上新建/改/删手动服务；生产容器与 entitlements 变更（真机跨设备实测暂缓，本件以 mock 验收）；同步状态 UI（第 4 件）；改 iOS 键格式。
- **验收**：mock CloudKit 单元测试——iPhone 设隐藏后电视拉取隐藏及反向、电视上传保留 `manualServices`、本地旧键迁移重 keyed、同一容器两端键一致（夹具验证）、电视不写 tasks/preferences 记录、启动/前台拉取与改动后上传。
- **实施进度**：iOS 18 项、tvOS 23 项定向测试通过。电视负责服务显示开关，三组 DSM 容器双端同键，Agent 单独生成的卡片键差异已记录。待 Muse 在正常签名包验收。 [Codex 交回](../archive/handoffs/2026-11/CODEX-2026-11-22-CLOUD-SYNC-PIECE-03-TV-SERVICES.md)

### 第 4 件：同步状态 UI（**已验收**，2026-11-22）

- **验收**：Muse 复跑 26 项 mock 全过；Xcode 26.6 签名 Debug 包（主程序 SHA `28d405c9…e12`）保留数据覆盖安装到 iPhone 13 与 iPad，两台正常启动；WDA 探针确认 iCloud 同步页——状态「已关闭」（开关为关）、上次成功「等待首次同步」（两台从未成功同步过）、待同步「有未同步的更改」（本地数据从未上传过），均与设备现有同步历史一致；开关可点按、Plus 已开通，门控正常。待同步清除、失败文案与权益门控以 mock 验收。验收记录 `docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-22-CLOUD-SYNC-PIECE-04-ACCEPTANCE.md`。

- **目标**：MineView 显示同步状态：上次成功时间、待同步、失败原因；开关仍走 `canUse(.iCloudSync)` 门控。
- **关键发现**：`SyncSettingsView` 已有开关/状态行/上次成功/失败详情/「立即同步」；缺口有三——(a) 无“待同步”概念（`scheduleSync` 无外部调用点，服务/任务改动未被观测）；(b) `syncErrorDetail` 只映射了 `missing-icloud-entitlement`，其余 4 个诊断码原样显示原始码；(c) 从未同步时上次成功行直接隐藏。`CloudSyncError` 四个诊断码的可读文案已存在（`mine.sync.error.*`）。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-04-SYNC-STATUS-UI-2026-11-22.md`
- **文件**：`ios/Nastart/Nastart/Features/Mine/MineView.swift`；`CloudSyncStore.swift`（待同步状态暴露 + 服务/任务改动观测接入）；中英文 `Localizable.strings`；测试 `CloudSyncStatusTests.swift`（或并入 `NonPlaybackPolicyTests.swift`）。
- **做到**：待同步状态（本地改动未上传时显示，成功后清除、失败后保留）、全部诊断码映射为可读文案（未知码通用文案，绝不显示原始码）、从未同步显示“等待首次同步”。
- **不做**：冲突解决界面（按时间戳自动合并，不做人工选择）；改同步触发时机；改门控与 Plus 链接；电视端不动。
- **验收**：mock store 下各状态正确显示；开关门控行为不变。
- **实施进度**：Xcode 26.6 iPhone 17e 模拟器构建和 26 项定向测试通过，其中 6 项覆盖本件，待 Muse 复跑和正式页面验收。 [Codex 交回](../archive/handoffs/2026-11/CODEX-2026-11-22-CLOUD-SYNC-PIECE-04-SYNC-STATUS-UI.md)

### 第 5 件：本地双设备模拟 + 验收套件（**已验收**，2026-11-23）

- **目标**：不依赖 CloudKit 容器，本地模拟两台设备同步，跑通第 1–4 件的验收。
- **关键发现**：双设备模式已有但零散——只有 `CloudSyncTaskTombstoneTests` 的 3 个测试用 `CloudSyncFixture(database: a.database)`，其余同步测试全是单 fixture；`MockCloudSyncDatabase` 是类可共享，`CloudSyncFixture` 接受注入的 database；`TVCloudSyncStore` 只在 tvOS，电视往返须在 tvOS 侧跑（共享测试文件 `ServiceVisibilityIdentityTests.swift` 同时被两端引用是先例）。
- **交接**：`docs/handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-05-TWO-DEVICE-HARNESS-2026-11-23.md`
- **文件**：`ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift`（harness + iOS 双设备用例，或新建 `CloudSyncTwoDeviceTests.swift`）；电视往返在 `ServiceVisibilityIdentityTests.swift`（tvOS 分支）或 tvOS 测试文件内。
- **做到**：两台本地 store + mock 传输（共享一个 `MockCloudSyncDatabase`）；覆盖用例：单域改动隔离、v1 迁移、删除不复活、电视服务记录往返、状态显示。
- **不做**：改生产代码（只加测试；harness 暴露的 bug 先报给 Muse）；真实 CloudKit 容器与真机跨设备实测（仍暂缓）。
- **验收**：全部用例通过；Muse 用同一 harness 做真机前验证。
- **验收结论（2026-11-23）**：Muse 复跑 iOS 30 项、tvOS 24 项全部通过（`CloudSyncTwoDeviceTests` 7 项 + 电视往返 `testIOSAndTVServicesRecordRoundTrip`）；本件只改测试，无生产代码变动，无需真机安装。验收记录 `docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-23-CLOUD-SYNC-PIECE-05-ACCEPTANCE.md`。
- **实施进度**：五类双设备 mock 验收通过。iOS 30 项、tvOS 24 项通过，待 Muse 复跑。 [Codex 交回](../archive/handoffs/2026-11/CODEX-2026-11-23-CLOUD-SYNC-PIECE-05-TWO-DEVICE-HARNESS.md)

## 暂缓（需付费开发者计划后做）

- 生产 CloudKit 容器启用与 schema 部署。
- 真机跨设备实测（13、18、iPad、电视同一 Apple ID）。
- TestFlight/App Store 分发。
