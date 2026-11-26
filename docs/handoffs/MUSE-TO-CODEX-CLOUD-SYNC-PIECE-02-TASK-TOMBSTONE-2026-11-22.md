# Cloud 同步第 2 件：任务删除 + tombstone（给 Codex）

**日期**：2026-11-22
**总纲**：`docs/project/BIG-TARGETS-ROADMAP.md`；拆分见 `docs/project/CLOUD-SYNC-BREAKDOWN.md`。
**范围**：只做第 2 件。不碰生产 CloudKit 容器、不做电视端、不做状态 UI、不做服务/偏好的删除。

## 背景

第 1 件把同步拆成三条记录，但任务至今**没有删除入口**：`AppDataStore` 只有 `addTask` / `setTask` / `completeTask`（完成是移入历史，不是删除），`TasksView` 只有“完成”按钮，无删除，`LocalTaskStore` 只有 save/load。没有删除，tombstone 就没有触发点；没有 tombstone，加了删除又会在同步时被旧快照复活。所以本件把“加删除”和“加 tombstone”一起做。

## 改哪些文件

- `ios/Nastart/Nastart/Core/Stores/AppStateStores.swift`（新增 `deleteTask`，接 tombstone）。
- `ios/Nastart/Nastart/Core/Stores/LocalTaskStore.swift`（tombstone 本地持久化）。
- `ios/Nastart/Nastart/Core/Stores/CloudSyncStore.swift`（`CloudSyncTasks` 加 `deletedTasks` 字段；合并时应用 tombstone）。
- `ios/Nastart/Nastart/Core/Models/NASModels.swift`（新增 `DeletedTask` 结构，放 `TaskItem` 旁边）。
- `ios/Nastart/Nastart/Features/Tasks/TasksView.swift`（`.onDelete` 接 `deleteTask`）。
- 测试：`ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift`（沿用第 1 件的 mock CloudKit 模式）。

## 做到什么

1. **新增删除入口** `AppDataStore.deleteTask(_ task: TaskItem)`（`@MainActor`，与 `completeTask` 同级）：
   - 从 `tasks`（待处理）和 `completedTasks`（历史）中都移除该 ID。
   - `cancelReminder(task)`。
   - 写一条 tombstone `{id: task.id, deletedAt: Date()}`。
   - `persistTasks()`（保存 + `noteLocalChange(in: .tasks)`）。
   - `completeTask` 保持原样（完成不是删除，不写 tombstone）。
2. **UI**：`TasksView.swift` 的 `ForEach(sortedPendingTasks)`（约 45 行）与 `ForEach(sortedHistoryTasks)`（约 77 行）各加 `.onDelete`，调用 `dataStore.deleteTask`。
3. **tombstone 结构与存储**：
   - `DeletedTask: Codable { let id: UUID; let deletedAt: Date }`。
   - 本地持久化在 `LocalTaskStore`，UserDefaults 新 key `"tasks.deleted.v1"`，随任务状态一起 load/save。
   - 同步载荷：`CloudSyncTasks` 加字段 `deletedTasks: [DeletedTask]`，仍走 `NastartTasks` / `tasks-workspace` 记录；解码时缺失该字段默认为 `[]`（兼容第 1 件已写的 v2 记录）。
4. **合并规则**（应用远端 `NastartTasks` 记录时）：
   - 本地与远端 tombstone 按 ID 取并集，同 ID 保留最早的 `deletedAt`。
   - 从本地待处理与历史中移除 ID 落在合并后 tombstone 里的任务。
   - tombstone 对同 ID 任务恒胜（用户主动删除是终态；任务 UUID 永不复用）。
   - 下次上传带合并后的 tombstone 列表，使其扩散到全部设备。
5. **保留时长**：常量 `tombstoneRetentionDays = 30`（定义在 `CloudSyncStore`，一处定义）。保存/应用时丢弃 `deletedAt` 超过 30 天的 tombstone。
   - 已知局限（接受）：超过 30 天未同步的设备，理论上可用陈旧本地副本复活已删任务；用户设备联网即同步，接受此局限。

## 不做什么

- 不做服务与偏好的删除（走整记录覆盖，不加 tombstone）。
- 不做电视端（第 3 件）、不做状态 UI（第 4 件）。
- 不启用生产 CloudKit 容器、不改 entitlements。
- 不改 `completeTask` 的语义，不改 `maxHistoryCount = 500` 的历史截断。

## 测试与验收

- 实现方自己编过（Xcode 26.6，iOS）、跑过相关测试再交回，不交“看着对但没编过”的代码。
- 用 mock CloudKit 写单元测试，至少覆盖：
  - A 删任务并同步后，B 用含该任务的旧快照同步，任务不出现。
  - 反向（B 删，A 有旧快照），任务不出现。
  - 删历史（已完成）任务同样写 tombstone、不复活。
  - 超过 30 天的 tombstone 在保存时被丢弃。
  - `deleteTask` 取消提醒并持久化。
  - 删任务不触动 services 与 preferences 记录（隔离，同第 1 件口径）。
- 交回时说明：改了哪些文件、编过没有、测试通过几项、保留时长常量位置。

## Muse 验收

Muse 复跑 mock 用例；按当前真机规程在用户指定设备上保留数据覆盖安装，核对正常启动、任务删除生效、其余服务/任务/偏好可读。失败写回本文档打回重改。
