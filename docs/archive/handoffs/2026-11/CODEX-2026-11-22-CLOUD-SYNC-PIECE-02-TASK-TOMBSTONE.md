# Cloud 同步第 2 件交回 Muse

2026-11-22 · 工作区 `/Users/lagransun/workspace/Nastart` · `main/8db1cc6491c6e8bce2bc8b41f57e6112142132ba` 加现有未提交修改。[Muse 实施交接](../../../handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-02-TASK-TOMBSTONE-2026-11-22.md)

## 源码与 SHA-256

| 文件 | 本批修改 | SHA-256 |
| --- | --- | --- |
| [NASModels.swift](../../../../ios/Nastart/Nastart/Core/Models/NASModels.swift) | 在 `TaskItem` 旁定义 `DeletedTask` | `18dc74438766e3ae0bcdb5b0e461fd3d508843c3ac64d41dadc74b0d8b3ade82` |
| [AppStateStores.swift](../../../../ios/Nastart/Nastart/Core/Stores/AppStateStores.swift) | `deleteTask` 按 ID 移除待处理和历史记录，取消提醒，保存 tombstone，标记 tasks 域已改动 | `97be915389255937e1c1e436e95a8398e7b1ce87ae051134d676fc2c6cbbbfde` |
| [CloudSyncStore.swift](../../../../ios/Nastart/Nastart/Core/Stores/CloudSyncStore.swift) | 任务载荷兼容旧 v2，合并删除标记后修正同 ID 的任务快照 | `d396c2eda4445ca327997c01ea855f0b98642381fa0890f3f90b924255020ec1` |
| [LocalTaskStore.swift](../../../../ios/Nastart/Nastart/Core/Stores/LocalTaskStore.swift) | 在 `tasks.deleted.v1` 存储 tombstone，读取时过滤两张旧列表；取消已排队及正在准备的提醒 | `0771419dedeeea82cd46924bbb14a8cd342a6af272be93fbcae8cb28fb2ffb8f` |
| [TasksView.swift](../../../../ios/Nastart/Nastart/Features/Tasks/TasksView.swift) | 待处理和历史列表均支持滑动删除，按屏幕当时显示的排序取得任务 ID | `56f35949e41ec007d74273e73e5d8a90119fb65b4f7bdc2f00cce4dbad33f67b` |
| [NonPlaybackPolicyTests.swift](../../../../ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift) | 新增 7 项测试，沿用第 1 件 mock CloudKit | `638f98f56773ccfd5254ac5fe650f59b188ac6571d0b7d0139f439bb927b52cd` |

以上六个文件的相对路径校验清单为 `cloud-sync-piece-02-sources.sha256`，清单自身 SHA-256 为 `f48cfcf9295f58e9d8035d017cbf512a06c41320eed49a1dbcac8614e41be6c9`。现有未提交改动随工作区保留；清单范围为表中的六个本批文件。

`NastartTasks` / `tasks-workspace` 的旧 v2 载荷缺少 `deletedTasks` 时按空数组解码。待处理和历史任务仍由快照时间戳选取，再用本地与远端 tombstone 的并集过滤。相同 ID 保留最早删除时间。若云记录需要修正，会先保存本地合并结果，再上传合并后的记录；写入冲突会重新读取。完成任务仍将待处理项移入历史，历史保存上限为 500。

`tombstoneRetentionDays = 30` 定义在 `CloudSyncStore.swift`。本地保存和同步应用清理超过 30 天的标记，恰好 30 天的标记仍保留。离线超过保留窗口的设备可能携带已删任务的旧副本重新同步。

## 构建和模拟器测试

工具链为 `/Applications/Xcode-26.6.app/Contents/Developer`，Xcode 26.6（17F113），iOS SDK 26.5。以下时间为北京时间，产物路径相对于本轮私有证据目录。

| 构建 | 时间与结果 | 产物及 SHA-256 |
| --- | --- | --- |
| iPhoneOS Release，arm64，无签名 | 13:12:11–13:15:27，`BUILD SUCCEEDED` | `DerivedData/Build/Products/Release-iphoneos/Nastart.app/Nastart` · `bb04386cfe584009196194afcac252df5b859f3a28f438c01fb9329a34ff01e2` |
| 模拟器 Debug App 和宿主 `NastartTests` | 13:15:29–13:16:00，`TEST SUCCEEDED`，iPhone 17e，iOS 26.5（23F77） | `DerivedData/Build/Products/Debug-iphonesimulator/Nastart.app/` 下主程序 `8a37b065649b618914d32de6c7ea8ace544f6dfda0aaa7a0c8121fd7696cbae2`，`Nastart.debug.dylib` 为 `011b8e08d4f4cbfe404f756cd314722985b2b3823330cc64d12ed4ef33038207` |

Release 使用原 workspace 和 `Nastart` scheme，参数为 `-configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`。构建日志为 `build-ios-release.log`。最终 Debug 日志为 `test-final.log`，结果为 `CloudSyncPiece02Final.xcresult` 和 `test-summary-final.json`。首轮 17 项也通过，随后消除了提醒提交处的编译警告，并以上表最终源码复跑。两轮的独立模拟器均已清理。

**定向结果为 17 项通过，0 失败，0 跳过。** 其中 7 项为本批新增测试。

| 新用例 | 验证内容 |
| --- | --- |
| `testADeletesAndBWritesNewerStaleSnapshot` | A 删除后，B 按较新时间戳上传时滤掉旧任务，保留 B 的其他任务 |
| `testBDeletesAndARepairsNewerVersionTwoSnapshotWithoutDeletedTasksField` | B 删除后 A 应用，随后修正缺失字段且时钟更新的旧 v2 快照 |
| `testHistoryDeletionWinsOverStalePendingAndCompletedCopies` | 完成后再删除，拦截同 ID 的待处理及已完成副本 |
| `testSavingAndApplyingPrunesExpiredDeletions` | 保存和同步应用清理超期记录，覆盖恰好 30 天的边界 |
| `testDeleteTaskCancelsReminderAndPersistsRemovalFromBothLists` | mock 核对提醒取消调用、两表持久化、旧本地列表解码和重复删除 |
| `testDeleteOnlyWritesTasksRecord` | services 和 preferences 的载荷及时间戳保持一致，仅写 tasks |
| `testUnionKeepsEarliestDeletionAndSurvivesFailedWrite` | 合并标记并保留最早日期，云写入失败后本地仍有标记，重试后稳定 |

另 10 项为第 1 件的 7 项 `CloudSyncRecordSplitTests`，以及既有合并策略、历史 500 项上限和离线夹具隔离各 1 项。提醒测试核对取消调用与保存结果，系统通知实际行为由设备验收。测试使用本机临时 scheme 绑定测试目标；沿用第 1 件的 `EXCLUDED_SOURCE_FILE_NAMES=PlaybackNextCoreTests.swift`，绕开该播放测试文件既有的 `target` 参数编译错误。

私有证据目录为 `~/Library/Application Support/Nastart/PrivateHandoff/cloud-sync-piece-02.zTJ7A9`。其中有临时 workspace、构建和测试日志、`.xcresult`、源码和二进制清单。复跑时设置 `simulator_id` 为当次可用的 iOS 26.5 模拟器 UUID。

```sh
nastart_piece02="$HOME/Library/Application Support/Nastart/PrivateHandoff/cloud-sync-piece-02.zTJ7A9"
shasum -a 256 -c "$nastart_piece02/cloud-sync-piece-02-sources.sha256"
DEVELOPER_DIR=/Applications/Xcode-26.6.app/Contents/Developer xcodebuild test \
  -workspace "$nastart_piece02/Nastart-CloudSync.xcworkspace" -scheme Nastart-CloudSync \
  -configuration Debug -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$nastart_piece02/MuseDerivedData" -parallel-testing-enabled NO \
  -only-testing:NastartTests/CloudSyncTaskTombstoneTests \
  -only-testing:NastartTests/CloudSyncRecordSplitTests \
  -only-testing:NastartTests/NonPlaybackPolicyTests/testCloudSyncMergePolicyProtectsNewerLocalChanges \
  -only-testing:NastartTests/NonPlaybackPolicyTests/testLocalTaskStateDeduplicatesAndBoundsHistory \
  -only-testing:NastartTests/OfflineRootFixtureTests \
  CODE_SIGNING_ALLOWED=NO EXCLUDED_SOURCE_FILE_NAMES=PlaybackNextCoreTests.swift
```

## Muse 接续

1. 在上述工作区核对六文件 SHA-256，按本页命令复跑 17 项测试，并保存 `.xcresult`。
2. 用 Xcode 26.6 构建正常签名 Debug 包。在用户指定的 iPhone 或 iPad 上按真机规程 fresh 核对设备身份和安装包，保留数据覆盖安装，核对正常启动。
3. 使用新建测试事项验证待处理列表左滑删除。另建一项，完成后从历史左滑删除。冷启动确认两项仍已删除，核对其他服务、事项和偏好可读。如通知权限允许，验证删除带将来提醒的测试事项后取消对应系统请求。跨设备冲突由 mock 验收。
4. 失败时在 [Muse 实施交接](../../../handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-02-TASK-TOMBSTONE-2026-11-22.md) 写回源码清单、包 SHA-256、设备与系统、安装和启动证据、复现步骤及截图、相关日志或 `.xcresult`。设备覆盖与真机验收由 Muse 接续。
