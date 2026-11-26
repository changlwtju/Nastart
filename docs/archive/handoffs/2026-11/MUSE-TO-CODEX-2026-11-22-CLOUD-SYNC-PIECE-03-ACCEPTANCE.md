# Cloud 同步第 3 件验收：电视端同步服务记录

2026-11-22 · Muse 验收 · 结论：**通过**。交接：`docs/handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-03-TV-SERVICES-2026-11-22.md`；Codex 交回：`docs/archive/handoffs/2026-11/CODEX-2026-11-22-CLOUD-SYNC-PIECE-03-TV-SERVICES.md`。

## 源码核对（14/14 OK）

工作区源码与 Codex 清单 `cloud-sync-piece-03-sources.sha256` 逐项一致（清单自身 SHA `09f4ad2e…b7b0` 已核对）。14 文件：`LaunchpadServiceIdentity.swift`、`NASModels.swift`、`CloudSyncRecord.swift`、`CloudSyncStore.swift`、`DSMClient.swift`、`ManualLaunchpadServiceStore.swift`、`AppTheme.swift`、`TVCloudSyncStore.swift`、`TVDSMClient.swift`、`NastartTVApp.swift`、`TVNASViews.swift`、`ServiceVisibilityIdentityTests.swift`、iOS 与 tvOS `project.pbxproj`。

## 复跑测试（mock，全部通过）

- **iOS 18 项全过**（Xcode 26.6，iPhone 17e 模拟器 AA9731E7，`TEST SUCCEEDED`）：`ServiceVisibilityIdentityTests` 2 项（容器键与 iOS 一致、iOS 发布可见性并应用电视写入的开关）+ `CloudSyncRecordSplitTests` 7 项（第 1 件回归）+ `CloudSyncTaskTombstoneTests` 7 项（第 2 件回归）+ 合并策略与 Agent 快照合并各 1 项。xcresult：Mac 上 `/tmp/CloudSyncPiece03iOSRerun20261122.xcresult`。
- **tvOS 23 项全过**（Xcode 27.2，Apple TV 4K 模拟器 arm64，`TEST SUCCEEDED`）：`ServiceVisibilityIdentityTests` 6 项（容器键与 iOS 一致、启动与前台读 iOS 开关并隐藏启动台容器、迁移等发现后重 keyed 仅匹配旧键、缺记录时留待 iOS 迁移且冲突重读手动数据、电视开关只写服务记录并保留手动载荷与其他开关、拉取失败保留开关且新远端重启后胜出）+ `TVDSMClientTests` 17 项（既有回归）。xcresult：Mac 上 `/tmp/CloudSyncPiece03TVRerun20261122.xcresult`。注：复跑时新建 Apple TV 4K（第 4 代）tvOS 27.2 模拟器（Codex 的两台模拟器已清理），跑完已删除。
- 键一致性：mock 夹具（2026-10-13 iPhone 13 DSM 发现快照）三容器两端键一致——`homepage` → `container|homepage|ghcr.io/gethomepage/homepage:latest`、`homepage-dockerproxy` → `container|homepage-dockerproxy|ghcr.io/tecnativa/docker-socket-proxy:latest`、`jellyfin` → `container|jellyfin|jellyfin/jellyfin:latest`；套件 `package|download station`、DSM `dsm`。Agent 仅生成卡片而 iOS 缺 DSM 卡片时两端键不同（mock 明确验证此差异，电视按 DSM 键处理、无推测匹配），本次真机未触发。

## 签名 tvOS Debug 包

Xcode 27.2，GUI Terminal 构建，`BUILD SUCCEEDED`。主程序 SHA-256 `15c5ea2cfeebb1d75fba7682e6987010060291229f23c3a5d8a67374a42ed30d`，dylib `89db73e353490f185eab34b5cf120e4e8d439656e764a02743f63038192e79c1`；codesign 通过，Team `5436TB5498`，描述文件到 2026-11-27T12:58:54Z；包路径 Mac 上 `/tmp/NastartTVCloudSyncPiece03Derived/Build/Products/Debug-appletvos/NastartTV.app`（Mac /tmp 重启则丢）。

## 真机验收（Apple TV 客厅）

设备：Apple TV 4K（第 3 代）`00008110-000235903E99801E`，tvOS 27.2，devicectl `available (paired)`。devicectl 保留数据覆盖安装，`com.changliwen.nastart.tv` 0.1.0，安装后 PID 1444 前台运行；验收后重新启动，PID 1485 前台运行。

真机探针 `testPiece03TVServicesAcceptance`（`TVLaunchTests.swift`，`TEST SUCCEEDED`，PROBE_EXIT=0），xcresult：Mac 上 `/tmp/CloudSyncPiece03TVProbe20261122.xcresult`，日志 `/tmp/nastart-tv-piece03-probe7-20261122.log`：

- **启动**：通过，启动台页出现。
- **已有 DSM 登录与服务清单**：通过，设备页“管理显示”入口出现，DSM 已发现服务，无“当前账号没有可见服务”。
- **「管理显示」显隐开关**：通过，取 `homepage`（`tv.visibility.container:f970515508f207ed3019858ac30302e5bac3f457fc4aed4966295ef02b50f4c9`）初始 `显示`，点按后变 `隐藏`。
- **冷启动后开关保留**：通过，terminate + relaunch 后 `homepage` 仍为 `隐藏`。
- **开关已恢复原状**：探针随后把 `homepage` 改回 `显示` 并验证，电视未留改动。
- **iCloud 页服务同步范围文案**：通过，“我的 → iCloud”页显示 `服务显示同步` 与文案“配置 iCloud 后可同步启动台的服务显示开关。电视的设置与事项保存在本机。”，无旧“未开通”提示，`settings.sync.services` 分区存在。
- 跨设备云行为以 mock 验收（本批电视未启用 `NASTART_TV_ICLOUD`，生产容器暂缓，见交接）。

## 探针说明（可复用）

- 探针导航沿用 `testMgmtManageDisplayAcceptance` 的直接聚焦模式（不切 tab，启动后静置 8 秒直接聚焦“管理显示”按钮）；切 tab 后再用通用聚焦会到不了按钮（焦点落在服务卡片下方）。
- 焦点在“我的”页沿最右列走（播放器 → 帮助 → 存储与媒体），iCloud 在第 2 行第 1 列，须按 下、下、左、左 到达；纯向下走不到。
- 探针与诊断函数已留在 `TVLaunchTests.swift`：`testPiece03TVServicesAcceptance`、`testPiece03MineFocusDiag`、`focusTab`、`focusByDown`、`focusICloudTile`。SSH 会话无法代码签名，电视 UI 探针须经 GUI Terminal 跑（SSH 跑会在 `nettle`/`libzvbi` 签名处失败）。
- v5/v6 两轮探针曾因 `otherElements` 取不到页面标识与 iCloud 焦点路径不对而失败，属探针问题非产品问题；v7 全部通过。探针开关在 v5/v6 均已恢复原状，电视当前 `homepage` 为显示。

## 未做 / 待办

- iPhone 18 仍未装第 2 件包（不在家）；回家连家里 Wi-Fi 后直接装第 2 件签名包验收，无需为第 3 件重装 iOS（第 3 件只改电视端，iOS 侧仅共享模型重构，mock 已覆盖）。
- 第 4 件（同步状态 UI）未开始，等用户发话。
