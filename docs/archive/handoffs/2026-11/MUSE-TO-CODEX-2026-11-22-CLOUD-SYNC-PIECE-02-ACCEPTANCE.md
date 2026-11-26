# Cloud 同步第 2 件验收通过（任务删除 + tombstone）

2026-11-22 · Muse 验收 · Codex 交接见 `CODEX-2026-11-22-CLOUD-SYNC-PIECE-02-TASK-TOMBSTONE.md` · 实施交接见 `docs/handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-02-TASK-TOMBSTONE-2026-11-22.md`。

## 结论

**通过。** 六文件 SHA 与交接一致；mock 17 项复跑全过；签名 Debug 包在 iPhone 13 与 iPad 上保留数据覆盖安装、正常启动；两台各用新建测试事项验证待处理与历史左滑删除，冷启动后两项仍已删除；服务（7/7）、事项与偏好可读；通知权限已允许，删除后系统提醒请求按标识符取消（syslog 实证）。

## 源码核对

六文件 SHA-256 与交接清单一致（`cloud-sync-piece-02-sources.sha256` 校验 6/6 OK，清单自身 SHA `f48cfcf9295f58e9d8035d017cbf512a06c41320eed49a1dbcac8614e41be6c9`）：

| 文件 | SHA-256（前 12 位） |
| --- | --- |
| NASModels.swift | `18dc74438766…` |
| AppStateStores.swift | `97be91538925…` |
| CloudSyncStore.swift | `d396c2eda444…` |
| LocalTaskStore.swift | `0771419dedee…` |
| TasksView.swift | `56f35949e41e…` |
| NonPlaybackPolicyTests.swift | `638f98f56773…` |

## 测试复跑

Xcode 26.6，iPhone 17e 模拟器（AA9731E7-B98F-4721-914C-7BFD0337FD33，iOS 26.5），临时 workspace `Nastart-CloudSync`，`CODE_SIGNING_ALLOWED=NO`，`EXCLUDED_SOURCE_FILE_NAMES=PlaybackNextCoreTests.swift`。**17 项，0 失败，0 跳过，TEST SUCCEEDED。** 其中 7 项本批新增 `CloudSyncTaskTombstoneTests`（A 删后 B 新快照不复活、旧 v2 缺字段修复、历史删除胜过陈旧副本、30 天超期清理、删除取消提醒并持久化、仅写 tasks 记录、并集合并最早日期且写失败后重试稳定）、7 项第 1 件 `CloudSyncRecordSplitTests` 回归、既有合并策略与历史 500 上限各 1 项、离线夹具 1 项。xcresult：Mac 上 `/tmp/CloudSyncPiece02Rerun20261122.xcresult`。

## 签名包

Xcode 26.6，GUI Terminal 构建，`BUILD SUCCEEDED`。路径 Mac 上 `/tmp/NastartCloudSyncPiece02Derived/Build/Products/Debug-iphoneos/Nastart.app`（Mac 重启则丢，需重建）。主程序 SHA-256 `7042cb8f61fb0329e3489b5328e0c43e651adf90ea1ff8849fd584e4c8703a5e`，dylib `931c7bea4b89fd18e6bda6b4d2d76083124a4188122d414dc74f8f73aa8261ae`；codesign 通过，Team `5436TB5498`，描述文件到 2026-11-26 23:27 UTC；`libswiftCompatibilitySpan.dylib` 已嵌（172,064 字节）；`verify_playback_linkage` PASS。

## 真机安装与启动（两台均 InstallComplete，保留数据覆盖）

| 设备 | 系统 | 安装 | 启动 |
| --- | --- | --- | --- |
| iPhone 13（00008110-001E543122E0401E，USB） | iOS 16.3.1 | InstallComplete | 前台运行（state 4），启动台服务可见 |
| iPad（00008120-000865400C920032，USB） | iPadOS 26.6 | InstallComplete | 前台运行（state 4），启动台服务可见 |

iPhone 18 未装（用户不在家，检测不到；回家连 Wi-Fi 后用同包安装，无需重建）。

## 左滑删除验证（新建测试事项，WDA 坐标左滑 + 点删除）

iPhone 13：新建「验收测试-待删-001」两次（首次保存时系统通知权限弹窗，点 允许 后任务落盘；两次保存各建一项，共 2 项）。待处理左滑删除 1 项后剩 1 项；剩余 1 项点 标记完成 进入历史，历史左滑删除后剩 0 项。冷启动（terminate + relaunch）后待处理与历史均无该任务，显示 暂无。

iPad：新建「验收测试-iPad-001」，待处理左滑删除后剩 0 项；新建「验收测试-iPad-002」，点 标记完成 进入历史，历史左滑删除后剩 0 项。冷启动后待处理与历史均无两项，显示 暂无。

注意：iPad 上任务行标签用「、」分隔（`验收测试-iPad-002、DS918+`），iPhone 13 用「,」分隔；探针按标签点按时须按设备取分隔符。

## 提醒取消（系统级实证）

通知权限已允许（iPhone 13 上点 允许）。另建带提醒测试事项「验收测试-提醒-001」并删除，全程抓 `idevicesyslog`（Mac 上 `/tmp/nastart-reminder-syslog-20261122.log`）：

- 建任务 13:48:11：`Adding notification request 5B04-BD6E`，SpringBoard 确认触发时间 `2027-01-20 23:24:00.000 +0800`（与任务详情「下次提醒 2027年1月20日」一致）。
- 删任务 13:48:22：`Removing 1 pending notification requests with identifiers ("5B04-BD6E")`，SpringBoard 确认 `Removing pending notification requests`。

同一标识符建时入队、删时移除，删除取消提醒在系统层得证。

## 其他数据可读（冷启动后，两台一致）

启动台 7/7 服务：Jellyfin、DSM、Homepage、Prowlarr、Radarr、Sonarr、qBittorrent。我的 tab：iCloud 同步、Nastart Plus（Plus 已开通）、外观、播放器等可读。截图副本在助手侧 `~/workspace/cloudsync-piece02-iphone13-launch.png`、`cloudsync-piece02-iphone13-after-coldstart.png`、`cloudsync-piece02-ipad-launch.png`、`cloudsync-piece02-ipad-after-coldstart.png`。

## 未做

跨设备防复活以 mock 结果验收（未做真实 CloudKit 跨设备同步）；iPhone 18 补装待用户回家；第 3 件（电视端同步服务记录）未开始，须等用户发话。
