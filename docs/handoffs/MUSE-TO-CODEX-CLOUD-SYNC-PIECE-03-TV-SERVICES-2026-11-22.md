# Cloud 同步第 3 件交接：电视端同步服务记录

2026-11-22 · Muse → Codex · 大目标 1（Cloud 同步本地部分）第 3 件 · 前置：第 1 件（按域拆记录 + v1 迁移）与第 2 件（任务删除 + tombstone）已验收通过。拆分见 `docs/project/CLOUD-SYNC-BREAKDOWN.md`。

## 现状（已核实，2026-11-22 读码）

- iOS 的服务记录是 `NastartServices`（recordName `services-workspace`），载荷 `CloudSyncServices { manualServices: [StoredManualLaunchpadService], serviceVisibilityOverrides: [String: Bool] }`（`CloudSyncStore.swift:45`），按 `updatedAt` 各自合并。
- 电视端**目前没有同步**：iCloud 设置页 `TVCloudSyncStatusView`（`TVNASViews.swift:106`）挂的是 `NastartTVSyncOverview`，其注释写明“never creates a CloudKit store”，显示 `NastartSyncUnavailableNotice(reason: .television)`。`CloudSyncStore.swift` 只在 iOS app target 里，电视 target 编不到；电视没有 entitlements 文件。
- 电视有自己的可见性模型：`TVServiceVisibilityView`（“管理显示”）用 `@AppStorage("tv.service.visibility.v1")` 存 JSON `[String: Bool]`，键是 `TVDiscoveredService.id`（容器 `"container:<docker id 或 name>"`、套件 `"package:<id>"`）；启动台按 `overrides[id] ?? defaultLaunchpadVisible` 过滤（`TVNASViews.swift:767`）。
- **关键不匹配（本件的核心）**：iOS 的可见性键是 `LaunchpadService.launchpadVisibilityKey`（`NASModels.swift:680`），容器为 `"container|<name>|<detail>"`、套件为 `"package|<detail>"`、DSM 为 `"dsm"`、手动为 `"manual|<uuid>"`；电视的键是 `"container:<id>"` / `"package:<id>"`。两边键格式不同，**直接同步 `[String: Bool]` 会对不上，必须先统一键**。另注意 iOS 容器 `detail` 在 Agent 路径下是 `"Agent · <port>"`（`AgentClient.swift:429` 附近），电视容器 `detail` 是镜像名，两边 `detail` 含义不同，算键时不能直接混用。

## 目标

电视读写 `NastartServices` 记录的**可见性开关**，与 iPhone/iPad 同一套模型、同一套键；电视不碰 `manualServices`，只读写 `serviceVisibilityOverrides`。

1. **抽公共模型**：把电视需要的同步模型抽到 iOS 与 tvOS 都能编到的位置（加文件进电视 target 或抽共享模块，按实际结构选）：`CloudSyncServices` 载荷、`NastartServices` 记录读写、`CloudSyncMergePolicy`（按 `updatedAt` 合并）、以及 `launchpadVisibilityKey` 的键计算。`CloudSyncStore.swift` 目前只在 iOS target 里，不要在电视端另写一套 CloudKit 读写。
2. **统一键（iOS 的 `launchpadVisibilityKey` 为准）**：电视为每个已发现服务算 iOS 风格的键——容器 `"container|<name>|<detail>"`、套件 `"package|<detail>"`、DSM `"dsm"`（name/detail 均 trim 后小写）。电视本地 `@AppStorage("tv.service.visibility.v1")` 改用这套键；启动台过滤与 `TVServiceVisibilityView` 的开关都走新键。**必须先验证**：用实际发现数据做单测，证明同一服务在电视端算出的键与 iOS 端一致；若电视的 `name`/`detail` 与 iOS 的对不上（例如容器 `detail` 一边是镜像名、一边是 `"Agent · <port>"`），把电视的键计算对齐到 iOS 用的字段，不许悄悄用另一套键，也不要改 iOS 的键格式（会丢弃 iOS 现有开关）。
3. **电视读**：电视启动与前台时拉取 `NastartServices` 记录，把 `serviceVisibilityOverrides` 应用到本地（写进 `tv.service.visibility.v1`），启动台按新开关显示/隐藏。拉取失败不清空本地开关。
4. **电视写**：电视上在“管理显示”里改可见性后上传：读当前云记录，**只改 `serviceVisibilityOverrides`，原样保留 `manualServices`**，再上传；按 `updatedAt` 合并，冲突时按现有 `CloudSyncMergePolicy`（新者胜）。电视不新建、不改、不删 `manualServices`。
5. **本地迁移**：首次运行后，把电视本地已有的旧键开关（`"container:<id>"` / `"package:<id>"`）按当前已发现服务重 keyed 到新键；对不上的旧开关丢弃（服务已不在，开关无意义）。迁移只做一次。
6. **iCloud 页**：电视 iCloud 设置页不再对“服务同步”显示不可用；只改服务同步这一项的文案/状态，完整的同步状态 UI（上次成功时间、失败原因）是第 4 件，不做。

## 文件（按实际结构，新增文件列出）

- 电视端 store（新建，如 `TVCloudSyncStore`，或复用现有 TV store）：包 CloudKit 记录读写、拉取/上传触发、本地开关对齐。
- `CloudSyncStore.swift`（如需抽公共模型）：把记录读写、载荷、合并策略抽到两端共享。
- `TVNASViews.swift`：启动台过滤与 `TVServiceVisibilityView` 走新键；iCloud 页服务同步不再显示不可用。
- `TVDSMClient.swift`（如需）：`TVDiscoveredService` 的键计算对齐到 iOS。
- 测试：沿用第 1、2 件的 mock CloudKit 模式（`NonPlaybackPolicyTests.swift` 或电视端测试目标，按实际结构）。

## 验收（mock CloudKit 单元测试，实现方须编过跑过再交回）

1. iPhone 设某服务隐藏后，电视拉取到同一开关，该服务在电视启动台隐藏。
2. 电视上改某服务可见性后，iPhone 拉取到同一开关。
3. 电视上传时 `manualServices` 原样保留，不被清空或改写。
4. 本地迁移：旧键 `"container:<id>"` 的开关重 keyed 到新键 `"container|<name>|<detail>"`；对不上的旧开关丢弃。
5. 键一致：同一容器在电视端与 iOS 端算出的键相同（用实际发现数据做夹具）。
6. 电视不写 tasks/preferences 记录；只读写 `NastartServices`。
7. 拉取触发：电视启动与前台时调用同步；开关改动后触发上传。

## 不做

- 电视同步任务与偏好（第 3 件只做服务记录）。
- 电视上新建/改/删手动服务。
- 生产 CloudKit 容器与 entitlements 变更（电视真机跨设备实测需付费开发者计划，暂缓；本件验收以 mock 为准）。
- 同步状态 UI（上次成功时间、失败原因，第 4 件）。
- 改 iOS 的键格式或 iOS 现有开关的存储。

## 交回要求

用 Xcode 26.6（电视用 Xcode 27.2）自己编过、跑过上述 mock 测试再交回，不交“看着对但没编过”的代码。交回时写一份 handoff 到 `docs/archive/handoffs/2026-11/CODEX-2026-11-22-CLOUD-SYNC-PIECE-03-TV-SERVICES.md`，说明改了哪些文件、公共模型抽到哪里、键对齐的验证结果（若电视与 iOS 的 `name`/`detail` 有出入，写明对齐方法）、构建记录、测试通过几项、源码 SHA-256。失败或键对不上时如实写，不许绕过。
