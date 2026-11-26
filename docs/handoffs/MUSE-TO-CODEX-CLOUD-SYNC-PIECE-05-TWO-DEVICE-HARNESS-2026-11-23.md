# Cloud 同步第 5 件交接：本地双设备模拟 + 验收套件（2026-11-23）

## 目标

不依赖 CloudKit 容器，本地模拟两台设备同步，跑通第 1–4 件的验收。做完本件，Cloud 同步本地部分收尾。

## 现状（已摸清，Codex 不用再探）

- `CloudSyncDatabase` 协议（`CloudSyncRecord.swift:19`）：`fetch` / `store`；`CKDatabase` 已实现，测试用 mock 注入。
- `MockCloudSyncDatabase`（`ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift:4769`）：内存字典存记录，支持失败写入与 before/afterStore 钩子；是类（引用类型），可被两个 fixture 共享。
- `CloudSyncFixture`（同文件 ~4711）：接受注入的 `database` 参数，已支持 `CloudSyncFixture(database: a.database)` 的双设备模式；各自独立的 UserDefaults suite（即两台设备的本机存储）。
- **双设备模式已有但零散**：只有 `CloudSyncTaskTombstoneTests` 的 3 个测试在用（4294/4332/4366 行），每个测试手动创建 a/b，无统一 harness。
- **其余同步测试全是单 fixture**：记录拆分（第 1 件）、状态显示（第 4 件）都只在单设备上验证，未跑过双设备往返。
- **电视往返的约束**：`TVCloudSyncStore` 只在 tvOS（`tvos/NastartTV/Sources/TVCloudSyncStore.swift`），iOS 测试目标编不到。电视往返目前由 tvOS 的 `ServiceVisibilityIdentityTests`（6 项）覆盖单向（iOS 写→电视读、电视写→保留手动数据），无 iOS 写→电视读→电视写→iOS 读的完整往返。共享测试文件的先例：`ServiceVisibilityIdentityTests.swift` 只一份（`ios/Nastart/NastartTests/`），同时被 iOS 与 tvOS 测试目标引用（tvOS pbxproj 用相对路径），内用 `#if os(tvOS)` / `#if os(iOS)` 区分。

## 本件做

### 1. 新建双设备 harness

在 `ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift` 内（与 `CloudSyncFixture` / `MockCloudSyncDatabase` 同文件，才能复用这两个 private 辅助）新建 `CloudSyncTwoDeviceTests`（或同等名的 harness + 测试类）：两个 `CloudSyncFixture`（A、B）共享一个 `MockCloudSyncDatabase`（即“云”），各自独立的 UserDefaults suite；提供 `syncBoth()` / `syncA()` / `syncB()` 与断言辅助（两端各域内容、待同步状态、失败状态）。若另建新文件，须自行处理 private 辅助的可见性（改为 internal 或一并迁移），不要复制两份 mock。

### 2. 补齐 5 类双设备用例（全部走 harness，不依赖真实 CloudKit）

- **单域改动隔离**：A 只改任务→同步→B 同步→B 只有任务变，服务/偏好不动；反向（A 只改可见性）同理。
- **v1 迁移**：A 持 v1 快照→同步→迁移为 v2→B 同步→B 拿到三条 v2 记录且内容一致。
- **删除不复活**：把现有 3 个 tombstone 双设备测试纳入 harness（逻辑不动，只改组织方式），A 删→B 用旧快照同步→任务不复活。
- **电视服务记录往返**：tvOS 侧用同一 mock 数据库跑完整往返——往 mock 库写一条 iOS 格式的服务记录→电视 store 拉取并应用→电视改一个可见性开关写回→读回记录验开关已按 iOS 键格式写入且 manualServices 原样保留。放在共享测试文件（`ServiceVisibilityIdentityTests.swift`，tvOS 分支）或 tvOS 测试文件内，按实际测试结构定；iOS 侧用共享的 `CloudSyncRecord` 模型验记录内容。
- **状态显示**：A 改动后待同步为真→A 同步成功后待同步清除→B 同步后状态为已是最新；A 同步失败时待同步保留且失败文案可读。

### 3. 收敛为验收套件

上述用例组成一个套件（`CloudSyncTwoDeviceTests` + 电视往返用例），Muse 在真机安装前复跑该套件（与第 1–4 件的复跑命令同形）。交回时附复跑命令。

## 不做

- 改生产代码（`CloudSyncStore`、`TVCloudSyncStore`、`AppDataStore` 等）——本件只加测试 harness 与用例；若 harness 暴露出生产代码的 bug，先报给 Muse，不自行修生产代码。
- 真实 CloudKit 容器 / entitlements / 真机跨设备实测（仍暂缓，等付费开发者计划）。
- 改第 1–4 件已验收的测试逻辑（只做组织上的纳入，不改断言语义）。

## 文件

- `ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift`（harness + iOS 双设备用例；或新建 `CloudSyncTwoDeviceTests.swift`，见上）。
- 电视往返：`ios/Nastart/NastartTests/ServiceVisibilityIdentityTests.swift`（tvOS 分支）或 `tvos/NastartTV/Tests/` 内对应文件。
- 若新建测试文件，加入 Xcode 工程（iOS 与 tvOS 的 project.pbxproj）。

## 验收（mock，不依赖真实 iCloud）

- 5 类用例全部通过（单域隔离、v1 迁移、删除不复活、电视往返、状态显示）。
- 现有第 1–4 件测试全部回归通过（记录拆分、tombstone、可见性键、状态、合并策略、Agent 身份、历史上限、离线夹具）。
- Harness 可被 Muse 直接复跑（提供复跑命令，与第 4 件同形）。

## 构建与测试（沿用前几件）

- iOS：Xcode 26.6，iPhone 17e 模拟器，临时 workspace/scheme + `CODE_SIGNING_ALLOWED=NO` + 排除 `PlaybackNextCoreTests.swift`（既有编译错误）。
- tvOS：Xcode 27.2，Apple TV 4K 模拟器，`ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`（电视往返用例）。
- 交回：更新后的文件 SHA-256 清单、测试结果（xcresult）、构建日志。
