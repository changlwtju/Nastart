# Cloud 同步第 5 件交回 Muse

2026-11-23 · 工作区 `/Users/lagransun/workspace/Nastart` · `main/8db1cc6491c6e8bce2bc8b41f57e6112142132ba` 加现有未提交修改。[Muse 实施交接](../../../handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-05-TWO-DEVICE-HARNESS-2026-11-23.md)

## 测试源码

- [NonPlaybackPolicyTests.swift](../../../../ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift) 的 `CloudSyncTwoDeviceHarness` 为 A 和 B 各创建一个 `CloudSyncFixture` 和独立的 `UserDefaults` suite，两端使用同一个 `MockCloudSyncDatabase`。提供 `syncA`、`syncB`、按 A 后 B 执行的 `syncBoth`，以及本地三域载荷和同步状态断言。
- `CloudSyncTwoDeviceTests` 新增 4 项。分别验证任务和服务开关只影响目标域、A 迁移 v1 后 B 拉取三条等值 v2 记录、A 失败时保留待同步而 B 仍显示已是最新，以及 A 重试成功后 B 收到任务。原有 3 项双端 tombstone 测试移入该组，复用 harness 并保留原断言和模拟条件。
- [ServiceVisibilityIdentityTests.swift](../../../../ios/Nastart/NastartTests/ServiceVisibilityIdentityTests.swift) 的 tvOS 分支新增 `testIOSAndTVServicesRecordRoundTrip`。以共享编解码器写入 iOS 格式服务记录，真实的电视 store 拉取并隐藏容器，切换后再读回记录，核对 iOS 键、手动服务和其他开关。实际 iOS store 应用电视格式的写回仍由前批 iOS 回归覆盖。

## 构建与结果

| 平台 | 窗口（北京时间） | 工具链与模拟器 | 结果 |
| --- | --- | --- | --- |
| iOS | 14:27:19–14:31:12 | Xcode 26.6（17F113），iPhone 17e，iOS 26.5（23F77），arm64 | Debug App 和宿主测试编译链接，`TEST SUCCEEDED`。30 项通过，0 失败，0 跳过。 |
| tvOS | 14:27:19–14:29:46 | Xcode 27.2（27B52），Apple TV 4K（第 4 代），tvOS 27.2（24K150），arm64 | Debug App 和宿主测试编译链接，`TEST SUCCEEDED`。24 项通过，0 失败，0 跳过。 |

五类双设备验收共 8 项通过。iOS 包含 7 项双设备用例（4 项新增、3 项迁入），以及 23 项记录拆分、tombstone、可见性键及电视写入格式、状态、合并策略、Agent 身份、历史上限和离线夹具回归。tvOS 包含 1 项新增往返、6 项服务同步回归与 17 项 DSM 客户端回归。

iOS 用临时 workspace/scheme，排除已有编译错误的 `PlaybackNextCoreTests.swift`。两端沿用各自已验证的 SwiftPM 固定版本，通过本机检出目录构建。模拟器均为本批创建并在测试后清理。

| 文件 | SHA-256 |
| --- | --- |
| `ios/Nastart/NastartTests/NonPlaybackPolicyTests.swift` | `0e36a6c4c656e48364b6e8e893df9e556f758c5503fa285d38173bc991548c93` |
| `ios/Nastart/NastartTests/ServiceVisibilityIdentityTests.swift` | `8d359c9bc124de4036712795e12805c7931815d4914ab1413aaa6b1428eb1ffa` |

两项清单 `cloud-sync-piece-05-sources.sha256` 的 SHA-256 为 `a3a7bdedae654fb83ce8c0d754254da1dc6322c1765b5f1a8771c19b86183d5d`。新增场景均通过。开工前后核对 74 个 App 产品源码、资源、权限和工程文件的 SHA-256 一致。三个迁入的 tombstone 用例共 28 条原断言逐条一致。

私有证据目录为 `~/Library/Application Support/Nastart/PrivateHandoff/cloud-sync-piece-05.kGmWHO`。

| 证据 | iOS | tvOS |
| --- | --- | --- |
| Xcode 测试结果 | `CloudSyncPiece05iOS.xcresult` | `CloudSyncPiece05TV.xcresult` |
| 构建与测试日志 | `ios-build-and-test.log` | `tv-build-and-test.log` |
| XCTest 摘要 | `ios-test-summary.json` | `tv-test-summary.json` |

同目录的 `rerun-piece-05.sh` 保存下节完整命令，可用 `sh` 从工作区根目录直接执行。

## Muse 复跑命令

从工作区根目录在本机终端运行。命令各建一台独立模拟器，在子 shell 退出时删除这两个实例，构建日志和 `.xcresult` 会留在新证据目录。

```sh
(
  set -eu
  nastart_piece05="$HOME/Library/Application Support/Nastart/PrivateHandoff/cloud-sync-piece-05.kGmWHO"
  nastart_ios_xcode=/Applications/Xcode-26.6.app/Contents/Developer
  nastart_tv_xcode=/Applications/Xcode.app/Contents/Developer
  nastart_run=$(mktemp -d "$nastart_piece05/muse-rerun.XXXXXX")
  printf '证据目录 %s\n' "$nastart_run"
  shasum -a 256 -c "$nastart_piece05/cloud-sync-piece-05-sources.sha256"
  nastart_ios_sim=
  nastart_tv_sim=
  trap 'if [ -n "$nastart_ios_sim" ]; then DEVELOPER_DIR="$nastart_ios_xcode" xcrun simctl delete "$nastart_ios_sim"; fi
        if [ -n "$nastart_tv_sim" ]; then DEVELOPER_DIR="$nastart_tv_xcode" xcrun simctl delete "$nastart_tv_sim"; fi' EXIT
  nastart_ios_sim=$(DEVELOPER_DIR="$nastart_ios_xcode" xcrun simctl create Nastart-Muse-Piece05-iOS \
    com.apple.CoreSimulator.SimDeviceType.iPhone-17e com.apple.CoreSimulator.SimRuntime.iOS-26-5)
  nastart_tv_sim=$(DEVELOPER_DIR="$nastart_tv_xcode" xcrun simctl create Nastart-Muse-Piece05-TV \
    com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K-4th-generation-4K com.apple.CoreSimulator.SimRuntime.tvOS-27-2)
  DEVELOPER_DIR="$nastart_ios_xcode" xcrun simctl boot "$nastart_ios_sim"
  DEVELOPER_DIR="$nastart_tv_xcode" xcrun simctl boot "$nastart_tv_sim"

  nastart_ios_result=0
  DEVELOPER_DIR="$nastart_ios_xcode" xcodebuild test \
    -workspace "$nastart_piece05/Nastart-CloudSync.xcworkspace" -scheme Nastart-CloudSync \
    -configuration Debug -destination "platform=iOS Simulator,id=$nastart_ios_sim" \
    -derivedDataPath "$nastart_run/iOSDerivedData" -parallel-testing-enabled NO \
    -clonedSourcePackagesDirPath "$nastart_piece05/iOSSourcePackages" \
    -disableAutomaticPackageResolution -skipPackageUpdates \
    -resultBundlePath "$nastart_run/CloudSyncPiece05iOS.xcresult" \
    -only-testing:NastartTests/CloudSyncTwoDeviceTests \
    -only-testing:NastartTests/CloudSyncRecordSplitTests \
    -only-testing:NastartTests/CloudSyncTaskTombstoneTests \
    -only-testing:NastartTests/ServiceVisibilityIdentityTests \
    -only-testing:NastartTests/CloudSyncStatusTests \
    -only-testing:NastartTests/NonPlaybackPolicyTests/testCloudSyncMergePolicyProtectsNewerLocalChanges \
    -only-testing:NastartTests/NonPlaybackPolicyTests/testAgentSnapshotMergerUsesSharedServiceRegistryForVisibility \
    -only-testing:NastartTests/NonPlaybackPolicyTests/testLocalTaskStateDeduplicatesAndBoundsHistory \
    -only-testing:NastartTests/OfflineRootFixtureTests \
    CODE_SIGNING_ALLOWED=NO EXCLUDED_SOURCE_FILE_NAMES=PlaybackNextCoreTests.swift \
    > "$nastart_run/ios-build-and-test.log" 2>&1 || nastart_ios_result=$?

  nastart_tv_result=0
  DEVELOPER_DIR="$nastart_tv_xcode" xcodebuild test \
    -project tvos/NastartTV/NastartTV.xcodeproj -scheme NastartTV \
    -configuration Debug -destination "platform=tvOS Simulator,id=$nastart_tv_sim" \
    -derivedDataPath "$nastart_run/TVDerivedData" -parallel-testing-enabled NO \
    -clonedSourcePackagesDirPath "$nastart_piece05/TVSourcePackages" \
    -disableAutomaticPackageResolution -skipPackageUpdates \
    -resultBundlePath "$nastart_run/CloudSyncPiece05TV.xcresult" \
    -only-testing:NastartTVTests/ServiceVisibilityIdentityTests \
    -only-testing:NastartTVTests/TVDSMClientTests \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO \
    > "$nastart_run/tv-build-and-test.log" 2>&1 || nastart_tv_result=$?
  printf 'iOS 退出码 %s，tvOS 退出码 %s\n' "$nastart_ios_result" "$nastart_tv_result"
  [ "$nastart_ios_result" -eq 0 ] && [ "$nastart_tv_result" -eq 0 ]
)
```

若复跑失败，在 [Muse 实施交接](../../../handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-05-TWO-DEVICE-HARNESS-2026-11-23.md) 记录测试文件 SHA-256、工具链和模拟器系统、失败断言、复现步骤及日志或 `.xcresult`。涉及生产逻辑的失败先回传证据，本件验收在 mock 范围内。
