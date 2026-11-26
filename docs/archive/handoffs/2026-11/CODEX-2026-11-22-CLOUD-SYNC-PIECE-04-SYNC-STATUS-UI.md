# Cloud 同步第 4 件交回 Muse

2026-11-22 · 工作区 `/Users/lagransun/workspace/Nastart` · `main/8db1cc6491c6e8bce2bc8b41f57e6112142132ba` 加现有未提交修改。[Muse 实施交接](../../../handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-04-SYNC-STATUS-UI-2026-11-22.md)

## 改动与源码校验

- `AppDataStore` 在服务和任务的原保存点通知同步存储。待同步沿用各域的本地改动时间、同步观测与成功时间。每个域成功后独立清除，失败的域保留待同步，重启时可从本地记录恢复状态。
- 「iCloud 同步」页在有待同步内容时显示「待同步／有未同步的更改」。「上次成功同步」始终显示，首次完成前为「等待首次同步」，成功后显示相对时间。有待同步内容且账户可用时，状态行显示「可同步」。
- 失败原因只在预设的本地化键中选取。四个同步引擎诊断码与缺少 iCloud 能力分别使用对应文案，其他输入统一使用「同步失败，请稍后重试」。界面使用当前失败状态选择文案。
- 开关、Plus 链接和「立即同步」仍从原来的 `canUse(.iCloudSync)`、启用状态与同步中状态推导。本批验收范围为 iOS。

| 文件 | 本批修改 | SHA-256 |
| --- | --- | --- |
| [AppStateStores.swift](../../../../ios/Nastart/Nastart/Core/Stores/AppStateStores.swift) | 接入服务和任务保存通知，供 mock 注入同步存储 | `23287bf2642b84d981cb06a630aa58ef9faa6d54441c98d69d029f32dee59ced` |
| [CloudSyncStore.swift](../../../../ios/Nastart/Nastart/Core/Stores/CloudSyncStore.swift) | 发布 `hasPendingChanges`，按域时间与观测计算 | `fa94f1fbde6ef9a94da27b444512ed3be63f8967e6548da1d6b9aa19dce14dd2` |
| [MineView.swift](../../../../ios/Nastart/Nastart/Features/Mine/MineView.swift) | 待同步、首次同步和本地化失败行 | `fbcf6c189e7aa85750269012400f8cb0bcd1bfd44af9593a2a87c91998ba3b91` |
| [英文 Localizable.strings](../../../../ios/Nastart/Nastart/en.lproj/Localizable.strings) | 增加待同步、可同步和通用失败文案 | `685dd512bb2873372f62cd42e578dae2c252d9ac814a0acf17ad7e7b5e0fd903` |
| [简体中文 Localizable.strings](../../../../ios/Nastart/Nastart/zh-Hans.lproj/Localizable.strings) | 增加待同步、可同步和通用失败文案 | `fb83295812ed07af8fc803620e8c7050dd848e122580f65d361fd422c5277cbc` |
| [NonPlaybackPolicyTests.swift](../../../../ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift) | 6 项新增 mock 和页面呈现逻辑测试 | `7725ceb2100618a6e8994ea4e4b9e41acd5e09dbd79ce8e5d36b73cbe162527b` |

六项清单为 `cloud-sync-piece-04-sources.sha256`，清单自身 SHA-256 为 `c31cddb186f514708040f343e539f48b2056d998ecb7b47d9c09dafeeddc3953`。

## 构建与测试

Xcode 26.6（17F113）在独立 iPhone 17e 模拟器（iOS 26.5，23F77，arm64）编译链接 Debug App 和宿主测试。北京时间 17:02:02–17:03:23，`TEST SUCCEEDED`。**26 项通过，0 失败，0 跳过**。其中第 4 件新增 6 项，其余 20 项覆盖三域拆分、任务 tombstone、iOS 服务键及电视写入格式、合并策略、Agent 身份、历史任务上限和离线夹具。独立模拟器已清理。

使用临时 workspace 和 `Nastart-CloudSync` scheme，构建参数为 `CODE_SIGNING_ALLOWED=NO EXCLUDED_SOURCE_FILE_NAMES=PlaybackNextCoreTests.swift`。后者用于避开该播放测试文件既有的参数编译错误。

新增测试覆盖服务、任务和偏好分别变为待同步、成功清除、部分失败与重启保持、上传途中持续编辑、远端归一化后已确认、已知和未知失败的中英文文案，以及页面首次同步和开关门控分支。开关及 Plus 链接的界面交互由 Muse 在指定设备验收。

私有证据目录为 `~/Library/Application Support/Nastart/PrivateHandoff/cloud-sync-piece-04.8GnYSn`。首轮 SwiftPM 更新遇到 GitHub TLS 连接错误，停止后复制第 3 件已验证的依赖检出目录，按原 `Package.resolved` 跳过更新。最终构建与测试日志为 `build-and-test-offline.log`，测试结果为 `CloudSyncPiece04Final.xcresult`，摘要为 `test-summary.json`。模拟器主程序与调试 dylib 的 SHA-256 见 `simulator-binaries.sha256`。

从工作区根目录复跑时，设置 `simulator_id` 为当次 iOS 26.5 模拟器 UUID。

```sh
nastart_piece04="$HOME/Library/Application Support/Nastart/PrivateHandoff/cloud-sync-piece-04.8GnYSn"
shasum -a 256 -c "$nastart_piece04/cloud-sync-piece-04-sources.sha256"
DEVELOPER_DIR=/Applications/Xcode-26.6.app/Contents/Developer xcodebuild test \
  -workspace "$nastart_piece04/Nastart-CloudSync.xcworkspace" -scheme Nastart-CloudSync \
  -configuration Debug -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$nastart_piece04/MuseDerivedData" -parallel-testing-enabled NO \
  -clonedSourcePackagesDirPath "$nastart_piece04/CachedSourcePackages" \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -only-testing:NastartTests/CloudSyncStatusTests \
  -only-testing:NastartTests/CloudSyncRecordSplitTests \
  -only-testing:NastartTests/CloudSyncTaskTombstoneTests \
  -only-testing:NastartTests/ServiceVisibilityIdentityTests \
  -only-testing:NastartTests/NonPlaybackPolicyTests/testCloudSyncMergePolicyProtectsNewerLocalChanges \
  -only-testing:NastartTests/NonPlaybackPolicyTests/testAgentSnapshotMergerUsesSharedServiceRegistryForVisibility \
  -only-testing:NastartTests/NonPlaybackPolicyTests/testLocalTaskStateDeduplicatesAndBoundsHistory \
  -only-testing:NastartTests/OfflineRootFixtureTests \
  CODE_SIGNING_ALLOWED=NO EXCLUDED_SOURCE_FILE_NAMES=PlaybackNextCoreTests.swift
```

## Muse 接续

1. 核对源码 SHA-256，按上述命令复跑 mock，保存自己的 `.xcresult`。
2. 用 Xcode 26.6 构建正常签名 Debug 包，按真机流程核对用户指定 iPhone 或 iPad、源码和包身份后保留数据覆盖。核对正常启动、iCloud 同步页在首次同步前的文字，以及编辑测试事项后出现「待同步」。清除待同步、各失败文案与权益分支以 mock 验收。
3. 失败时在 [Muse 实施交接](../../../handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-04-SYNC-STATUS-UI-2026-11-22.md) 写回设备与系统、源码及包 SHA-256、复现步骤、截图、相关日志或 `.xcresult`。
