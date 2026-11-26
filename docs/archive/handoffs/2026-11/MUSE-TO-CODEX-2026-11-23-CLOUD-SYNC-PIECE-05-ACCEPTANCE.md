# Cloud 同步第 5 件验收记录：本地双设备模拟 + 验收套件（2026-11-23）

## 结论：通过

Muse 复跑 iOS 30 项、tvOS 24 项，全部通过，0 失败。5 类双设备用例全覆盖。Cloud 同步本地部分至此收尾。

## 核对

- 测试文件 SHA-256（复跑脚本校验）：`NonPlaybackPolicyTests.swift` `0e36a6c4…c93`、`ServiceVisibilityIdentityTests.swift` `8d359c9b…ffa`，均 OK。
- 生产代码未动：本件只加测试 harness 与用例（交接要求），Codex 的 production-verification.log 全 OK。

## 复跑结果

- iOS（Xcode 26.6，iPhone 17e 模拟器 iOS 26.5）：**30 项全过，0 失败**，TEST SUCCEEDED。`CloudSyncTwoDeviceTests` 7 项全过：
  - 单域改动隔离：`testTaskEditReachesBWithoutChangingServicesOrPreferences`、`testVisibilityEditReachesBWithoutChangingTasksOrPreferences`
  - v1 迁移：`testASeedsV2FromLegacyAndBReadsAllThreeRecordsWithoutRewriting`
  - 删除不复活：`testADeletesAndBWritesNewerStaleSnapshot`、`testBDeletesAndARepairsNewerVersionTwoSnapshotWithoutDeletedTasksField`、`testHistoryDeletionWinsOverStalePendingAndCompletedCopies`
  - 状态显示：`testPendingAndFailureStayLocalUntilTheSuccessfulRetryReachesB`
  - 其余 23 项为第 1–4 件回归（记录拆分、tombstone、可见性键、状态、合并策略、Agent 身份、历史上限、离线夹具）。
- tvOS（Xcode 27.2，Apple TV 4K 模拟器 tvOS 27.2）：**24 项全过，0 失败**，TEST SUCCEEDED。`ServiceVisibilityIdentityTests` 7 项全过，含电视往返 `testIOSAndTVServicesRecordRoundTrip`；其余为 TVDSMClientTests 回归。
- 证据目录：`~/Library/Application Support/Nastart/PrivateHandoff/cloud-sync-piece-05.kGmWHO/muse-rerun.G5vtHb/`（`ios-build-and-test.log`、`tv-build-and-test.log`、`CloudSyncPiece05iOS.xcresult`、`CloudSyncPiece05TV.xcresult`）。

## 真机

本件只改测试文件，无生产代码变动，无新包可装，无需真机安装。第 1–4 件的包仍在 13 / iPad / 电视 / 18 上（第 4 件）。

## 后续

- Cloud 同步本地部分（第 1–5 件）全部验收通过。
- 下一步按总纲走第 2 号大目标 Agent，等用户发话再定。
- 生产 CloudKit 容器与真机跨设备实测仍暂缓（等付费开发者计划）。
