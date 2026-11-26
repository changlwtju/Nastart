# Cloud Sync 第 1 件验收（Muse → Codex）

**日期**：2026-11-21 22:22–22:38
**交接**：`docs/handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-01-RECORD-SPLIT-2026-11-21.md`
**Codex 交回**：`docs/archive/handoffs/2026-11/CODEX-2026-11-21-CLOUD-SYNC-PIECE-01-RECORD-SPLIT.md`
**结论：通过。**

## 源码核对

- 工作区源码 SHA-256 与 Codex 证据 `cloud-sync-sources.sha256` 四项全一致：
  - `NastartApp.swift` `4e9d097f…941b0d`
  - `CloudSyncStore.swift` `256e4d1a…91871f`
  - `AppStateStores.swift` `9f570202…e8b2845`
  - `NonPlaybackPolicyTests.swift` `1834b640…589acb3`
- HEAD `8db1cc64`，工作区未提交修改完整保留。

## mock CloudKit 用例复跑（9/9 通过）

- 环境：Xcode 26.6（17F113），iPhone 17e 模拟器 iOS 26.5，临时 scheme `Nastart-CloudSync`，`CODE_SIGNING_ALLOWED=NO`，`EXCLUDED_SOURCE_FILE_NAMES=PlaybackNextCoreTests.swift`。
- xcresult：`/tmp/CloudSyncRerun20261121.xcresult`（Mac 上）。
- 结果：**9 项通过，0 失败，0 跳过**（`TEST SUCCEEDED`）。
- 四项验收点：
  - 改任务只写 tasks：`testChangingTasksLeavesServicesAndPreferencesUntouched` 通过。
  - 改可见性只写 services：`testChangingVisibilityLeavesTasksAndPreferencesUntouched` 通过。
  - v1 迁移六字段一致：`testMigratesAllSixFieldsAndStopsReadingLegacyRecord` 通过；`testPartialMigrationRetriesOnlyMissingDomainBeforeMarkingLegacy` 通过。
  - 三域按各自时间戳合并：`testEachDomainChoosesItsOwnClock`、`testConflictingSaveRefetchesOnlyTheAffectedDomain`、`testTaskEditDuringSaveIsRetriedWithoutRewritingOtherDomains` 通过。
  - 另 2 项既有测试（合并策略保护新本地改动、离线夹具隔离）通过。

## 签名 Debug 包

- 标准构建：Xcode 26.6 GUI Terminal，`BUILD SUCCEEDED`，DerivedData `/tmp/NastartCloudSync20261121Derived`。
- 主程序 SHA-256：`729f02df4bff283a68bd4057a5ab91f8b78da1f73cd5ffc80e985ff03b19f0ee`
- dylib SHA-256：`68c3f3c5dbbf22b80ea978f9b1042a426c0c55d28c8cf243e4afca2c1857aac9`
- codesign 通过：`com.changliwen.nastart`，Team `5436TB5498`，描述文件到 2026-11-26 23:27 UTC。
- `libswiftCompatibilitySpan.dylib` 已嵌（172,064 字节），`verify_playback_linkage` PASS。

## 真机安装与验证（两台，保留数据覆盖安装）

- iPhone 18 随用户外出，未装。
- **iPhone 13**（iPhone14,5，iOS 16.3.1，USB）：ios-deploy `InstallComplete`；WDA 启动，前台 state 4；启动台显示 Jellyfin、DSM、Homepage、Prowlarr、Radarr、Sonarr、qBittorrent 及 NAS 状态正常；事项 tab 可读（待处理/监测项）；我的 tab 可读（iCloud 同步、Plus 已开通、外观、播放器、设置）。
- **iPad**（iPad15,7，iPadOS 26.6，USB）：ios-deploy `InstallComplete`；WDA 启动 400 后改走 devicectl 启动成功，前台 state 4；iPad WDA 曾降级（source 404、screenshot 500），已重启恢复；启动台显示全部 7 个服务及 NAS 状态正常；事项 tab 可读；我的 tab 可读（iCloud 同步、Plus 已开通、外观、播放器、设置）。
- 云同步验收以 mock 为准（本批未做真实 CloudKit 跨设备同步）。

## 备注

- iPad WDA 启动 400 与后续 source/screenshot 失败是 WDA 会话降级，非 App 问题；重启 WDA 后恢复。App 本身在 iPad 上无崩溃。
- 下一件（第 2 件：任务删除 tombstone）待用户定夺后交接。
