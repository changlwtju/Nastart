# Cloud 同步第 4 件交接：同步状态 UI（2026-11-22）

## 目标

MineView 的 iCloud 同步页显示三样东西：上次成功时间、待同步、失败原因。开关仍走 `canUse(.iCloudSync)` 门控。

## 现状（已摸清，Codex 不用再探）

- `SyncSettingsView`（`ios/Nastart/Nastart/Features/Mine/MineView.swift:728`）已有：开关（`canUse(.iCloudSync)` 门控）、状态行（`cloudSyncStore.status` + 同步中 ProgressView）、上次成功时间（`lastSuccessfulSyncAt`，relative 格式，**仅当有值时显示**）、失败详情（`syncErrorDetail`，仅当 status 为 `.failed`）、「立即同步」按钮、未开通时 Plus 链接。
- `CloudSyncStore`（`ios/Nastart/Nastart/Core/Stores/CloudSyncStore.swift`）已有：`status`（`CloudSyncAvailability`：disabled/checking/available/syncing/noAccount/restricted/failed）、`lastSuccessfulSyncAt`（全局 + 按域 `lastSuccessfulSyncAt(for:)`）、`lastErrorDetail`（诊断码，非原始错误）、每域 `localChangeAt` 与 `LocalObservation`（fingerprint/updatedAt/syncedRemoteFingerprint）、`observeLocalPayload`、`scheduleSync`（900ms 防抖）。
- `CloudSyncError`（`CloudSyncRecord.swift:107`）4 个诊断码已有可读本地化文案：`payload_too_large`、`conflict_retry_limit`、`incompatible_remote_snapshot`、`local_changes_during_sync`（对应 `mine.sync.error.*`）。
- **缺口**：(a) 无“待同步”概念——`scheduleSync` 无外部调用点，`observeLocalPayload` 只在偏好（UserDefaults 通知，`observePreferencesChange`）与同步过程中被调用，**服务/任务的本地改动未被观测**，UI 无待同步显示；(b) `syncErrorDetail`（MineView.swift:812）只映射了 `missing-icloud-entitlement`，其余 4 个诊断码原样返回给 UI（会显示 `payload_too_large` 这类原始码）；(c) 从未同步过时上次成功行直接不显示，无“等待首次同步”状态。

## 本件做三件事

### 1. 待同步

- `CloudSyncStore` 暴露一个 `@Published` 的待同步状态（按域或全局，选最简形式）。定义：该域本地有改动且尚未成功上传。用现有 `localChangeAt` / `LocalObservation` / `lastSuccessfulSyncAt` 推导（本地 fingerprint 与已同步远端 fingerprint 不同，或本地改动时间晚于该域上次成功时间）。
- 把服务/任务的本地改动接进观测（在 `AppDataStore` 保存服务/任务处调用观测入口；偏好已有 UserDefaults 通知路径，不用动）。
- 同步成功后该域待同步清除；同步失败后待同步保留。
- `SyncSettingsView` 在有待同步时显示“待同步”行（新增本地化 key，文案如“有未同步的更改”）；无待同步时不显示该行（状态行已有“已是最新”）。

### 2. 失败原因可读

- `syncErrorDetail` 把全部诊断码映射为可读本地化文案（复用已有的 `mine.sync.error.*` 四条 + `missing-icloud-entitlement`）。
- 未知码一律显示通用可读文案（新增 key，如“同步失败，请稍后重试”）。**绝不把原始诊断码或原始错误文本显示给用户。**

### 3. 从未同步

- `lastSuccessfulSyncAt` 为 nil 时，上次成功行显示“等待首次同步”（复用已有 key `mine.sync.waiting`），而不是隐藏该行。

## 不做

- 冲突解决界面（按时间戳自动合并，不做人工选择）。
- 改同步触发时机（仍只在启动/前台/账号变化/手动“立即同步”时同步；本件不加“改动后自动同步”，只显示待同步状态）。
- 改 `canUse(.iCloudSync)` 门控与 Plus 链接（行为不变）。
- 改生产容器/entitlements；电视端不动（`TVCloudSyncStore` 不改）。

## 文件

- `ios/Nastart/Nastart/Features/Mine/MineView.swift`（SyncSettingsView + syncErrorDetail）
- `ios/Nastart/Nastart/Core/Stores/CloudSyncStore.swift`（待同步状态暴露 + 服务/任务改动观测接入）
- `ios/Nastart/Nastart/zh-Hans.lproj/Localizable.strings`、`ios/Nastart/Nastart/en.lproj/Localizable.strings`（新增文案 key）
- 测试：新建 `CloudSyncStatusTests.swift`（或并入 `NonPlaybackPolicyTests.swift`），加入 Xcode 工程。

## 验收（mock，不依赖真实 iCloud）

- 本地改动服务/任务/偏好后（未同步），待同步状态为真；同步成功后待同步清除。
- 同步失败后待同步保留，且失败原因显示可读文案（四种诊断码各一条 + missing-icloud-entitlement）；未知码显示通用文案，不出现原始码。
- 从未同步时上次成功行显示“等待首次同步”。
- 开关门控行为不变：无权限时开关禁用、显示 Plus 链接；有权限时开关可用、“立即同步”可用（同步中禁用）。
- 回归：复跑第 1/2/3 件相关测试（记录拆分、tombstone、可见性键），不触动 services/tasks/preferences 记录内容与合并逻辑。

## 构建与测试（沿用前几件）

- iOS：Xcode 26.6，iPhone 17e 模拟器，临时 workspace/scheme + `CODE_SIGNING_ALLOWED=NO` + 排除 `PlaybackNextCoreTests.swift`（既有编译错误）。
- tvOS 不受影响，本件不跑 tvOS 测试。
- 交回：更新后的文件 SHA-256 清单、测试结果（xcresult）、构建日志。
