# Cloud 同步第 1 件：按域拆记录 + v1 迁移（给 Codex）

**日期**：2026-11-21
**总纲**：`docs/project/BIG-TARGETS-ROADMAP.md`；拆分见 `docs/project/CLOUD-SYNC-BREAKDOWN.md`。
**范围**：只做第 1 件。不碰生产 CloudKit 容器、不做删除 tombstone、不做电视端、不做状态 UI。

## 背景

现在同步是一条大记录：`CloudSyncSnapshot`（schemaVersion 1），recordType `NastartSnapshot`、recordName `primary-workspace`，六个字段全打在一起。改一个任务也要整包上传，还可能覆盖另一台刚改的可见性。本件把它拆成三条按域记录，各自独立同步。

## 改哪些文件

- 主改：`ios/Nastart/Nastart/Core/Stores/CloudSyncStore.swift`。
- 调用点如需调整：`ios/Nastart/Nastart/App/NastartApp.swift`（`syncNow(dataStore:appearanceStore:)` 的调用处）。
- 其余文件不动。

## 做到什么

1. 三条新记录，各自带 `updatedAt`：
   - `NastartServices`：`manualServices: [StoredManualLaunchpadService]` + `serviceVisibilityOverrides: [String: Bool]`。
   - `NastartTasks`：`pendingTasks: [TaskItem]` + `completedTasks: [TaskItem]`。
   - `NastartPreferences`：`stringPreferences: [String: String]` + `booleanPreferences: [String: Bool]`。
   - recordName 沿用同一规则：`services-workspace` / `tasks-workspace` / `preferences-workspace`（命名可按既有风格微调，交回时注明）。
2. 合并仍按时间戳，每条记录独立判断（复用现有 `CloudSyncMergePolicy.decision` 的逻辑，按记录分别调用）。
3. schemaVersion 升到 2。
4. v1 迁移：读到旧的 `NastartSnapshot`（`primary-workspace`）时，把六个字段分写入三条新记录，上传新记录，并删除旧记录或标记已迁移（选一种，交回时注明）。迁移后不再读写旧记录。
5. `syncNow` 按记录分别同步：每条记录独立上传/下载、独立记成功时间；一条失败不阻塞其他两条。

## 不做什么

- 不加删除 tombstone（第 2 件）。
- 不做电视端（第 3 件）。
- 不做同步状态 UI（第 4 件）。
- 不启用生产 CloudKit 容器、不改 entitlements、不碰付费开发者计划相关的配置。
- 不改快照字段本身的含义（六个字段原样拆，不增不减）。

## 测试与验收

- 实现方自己编过（Xcode 26.6，iOS）、跑过相关测试再交回，不交“看着对但没编过”的代码。
- 用 mock CloudKit 写单元测试，至少覆盖：
  - 只改任务时，services 记录不动（不上传、不覆盖）。
  - 只改可见性时，tasks 记录不动。
  - v1 旧记录迁移后，三条新记录内容与旧记录一致。
  - 每条记录的合并按各自时间戳独立判断。
- 交回时说明：改了哪些文件、编过没有、测试通过几项、recordName 最终命名、迁移方式（删旧记录还是标记）。

## Muse 验收

Muse 在真机（Debug 构建，CloudKit 不可用时以 mock/本地验证为准）核对上述测试与行为；失败写回本文档打回重改。
