# Cloud Sync 第 1 件交回 Muse

2026-11-21 · 工作区 `/Users/lagransun/workspace/Nastart` · `main/8db1cc64` 加现有未提交修改。实施范围见 [Muse 交接](../../../handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-01-RECORD-SPLIT-2026-11-21.md)。

## 源码

| 文件 | 本批修改 |
| --- | --- |
| [CloudSyncStore.swift](../../../../ios/Nastart/Nastart/Core/Stores/CloudSyncStore.swift) | v2 编解码、按记录合并与成功时间、部分失败重试、v1 迁移及可注入 CloudKit 传输 |
| [AppStateStores.swift](../../../../ios/Nastart/Nastart/Core/Stores/AppStateStores.swift) | 将原整包应用入口拆成服务和任务两个入口，沿用手动服务 URL 脱敏、任务归一化和提醒逻辑；按域标记本地改动 |
| [NastartApp.swift](../../../../ios/Nastart/Nastart/App/NastartApp.swift) | 观察偏好变化，在 iCloud 账号变更时重新检查迁移 |
| [NonPlaybackPolicyTests.swift](../../../../ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift) | 增加 7 项 mock CloudKit 测试，复用现有测试目标 |

| recordType | recordName | `payload` 内的字段 |
| --- | --- | --- |
| `NastartServices` | `services-workspace` | `manualServices`、`serviceVisibilityOverrides` |
| `NastartTasks` | `tasks-workspace` | `pendingTasks`、`completedTasks` |
| `NastartPreferences` | `preferences-workspace` | `stringPreferences`、`booleanPreferences` |

每条记录单独保存 `schemaVersion = 2` 和 `updatedAt`，复用 `CloudSyncMergePolicy.decision`；内容已同步时跳过写入。首次迁移按旧 `updatedAt` 填充缺失的 v2 记录，已存在的 v2 记录继续按各域时间戳同步。三域成功后给 `primary-workspace` 加 `migratedToSchemaVersion = 2`，保留原 payload。完成检查后，常规同步只读写 v2。v1 只有一个本地时间戳，升级时各域尚无自己的时间戳才以它作为初值。

## 验证与接续

Xcode 26.6（17F113）编译并链接 iOS 26.5 模拟器 Debug App 和定向测试目标。iPhone 17e 模拟器最终运行 **9 项通过，0 失败，0 跳过**。7 项新增测试覆盖任务写入隔离、可见性写入隔离、六字段与迁移后重启、各域时间戳、部分迁移失败恢复、上传期间编辑和 CloudKit 冲突重读。另 2 项覆盖既有合并策略和离线夹具隔离。

同一源码于 22:04（北京时间）在 Xcode 26.6 完成 iPhoneOS 26.5 SDK 的无签名 Release 构建。arm64 主程序位于私有证据目录的 `DerivedData/Build/Products/Release-iphoneos/Nastart.app/Nastart`，SHA-256 为 `d88c9f3ed7e85c9510f2266b751fb6698386a15278516a3dd34793ffee216fbc`。

仓库现有 workspace scheme 未绑定测试目标。定向构建通过本机临时 scheme 绑定 `NastartTests`，并用命令行 `EXCLUDED_SOURCE_FILE_NAMES=PlaybackNextCoreTests.swift` 排除已有的 `target` 参数编译错误。首轮定向测试有一项选错预置手动服务，改用本测试新增服务的 ID 后复跑通过。临时模拟器已删除。

测试结果 `CloudSyncFinal.xcresult`、临时 `Nastart-CloudSync.xcworkspace`、编译日志和源码 SHA-256 存在本机私有的 `~/Library/Application Support/Nastart/PrivateHandoff/cloud-sync-v2.nOjO44/`。源代码、测试和项目状态留在当前工作区。

用本批临时 scheme 复跑时，将 `simulator_id` 设为复测用的 iOS 26.5 模拟器 UDID。

```sh
cloud_sync_evidence="$HOME/Library/Application Support/Nastart/PrivateHandoff/cloud-sync-v2.nOjO44"
DEVELOPER_DIR=/Applications/Xcode-26.6.app/Contents/Developer xcodebuild test \
  -workspace "$cloud_sync_evidence/Nastart-CloudSync.xcworkspace" -scheme Nastart-CloudSync \
  -configuration Debug -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$cloud_sync_evidence/DerivedData" -parallel-testing-enabled NO \
  -only-testing:NastartTests/CloudSyncRecordSplitTests \
  -only-testing:NastartTests/NonPlaybackPolicyTests/testCloudSyncMergePolicyProtectsNewerLocalChanges \
  -only-testing:NastartTests/OfflineRootFixtureTests \
  CODE_SIGNING_ALLOWED=NO EXCLUDED_SOURCE_FILE_NAMES=PlaybackNextCoreTests.swift
```

Muse 在 Xcode 26.6 用 `NastartTests` 复跑 `CloudSyncRecordSplitTests`。按当前真机规程检查目标机和 Debug 包身份后保留数据覆盖用户指定的 iPhone 或 iPad，核对正常启动和现有服务、任务、偏好。云同步验收以 mock 为准。失败回传设备/系统、源与包 SHA-256、失败用例、错误和 `.xcresult` 或对应日志。Codex 本批安装数为 0。真实 CloudKit 跨设备同步与生产 schema 部署待后续，tombstone、tvOS 和同步状态 UI 仍属后续交接。
