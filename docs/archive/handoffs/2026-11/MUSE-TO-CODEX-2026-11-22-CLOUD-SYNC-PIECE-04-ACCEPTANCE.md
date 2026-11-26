# Cloud 同步第 4 件验收：同步状态 UI

2026-11-22 · Muse 验收 · 结论：**通过**。交接：`docs/handoffs/MUSE-TO-CODEX-CLOUD-SYNC-PIECE-04-SYNC-STATUS-UI-2026-11-22.md`；Codex 交回：`docs/archive/handoffs/2026-11/CODEX-2026-11-22-CLOUD-SYNC-PIECE-04-SYNC-STATUS-UI.md`。

## 源码核对（6/6 OK）

工作区源码与 Codex 清单 `cloud-sync-piece-04-sources.sha256` 逐项一致（清单自身 SHA `c31cddb186f514708040f343e539f48b2056d998ecb7b47d9c09dafeeddc3953` 已核对）。6 文件：`AppStateStores.swift`、`CloudSyncStore.swift`、`MineView.swift`、英文与简体中文 `Localizable.strings`、`NonPlaybackPolicyTests.swift`（内含新增 `CloudSyncStatusTests`）。

## 复跑测试（mock，26 项全过）

Xcode 26.6，iPhone 17e 模拟器（iOS 26.5，临时新建，跑完已删除），`TEST SUCCEEDED`，**26 项通过，0 失败**。含第 4 件新增 6 项（服务/任务/偏好分别变为待同步、成功清除、部分失败与重启保持、上传途中持续编辑、远端归一化后已确认、已知和未知失败的中英文文案、页面首次同步与开关门控分支）+ 20 项回归（记录拆分、tombstone、iOS 服务键及电视写入格式、合并策略、Agent 身份、历史任务上限、离线夹具）。xcresult：Mac 上 `/tmp/CloudSyncPiece04Rerun20261122.xcresult`。待同步清除、失败文案与权益门控按交接以 mock 验收（见上）。

## 签名 Debug 包

Xcode 26.6，GUI Terminal 构建（workspace `ios/Nastart/Nastart.xcworkspace`，scheme `Nastart`），`BUILD SUCCEEDED`。主程序 SHA-256 `28d405c99089c67b64e740e5a927416d49dcdb1019cc80fb3baa8ec1bbf67e12`；codesign 通过，Identifier `com.changliwen.nastart`，Team `5436TB5498`，描述文件到 2026-11-26T23:27:01Z；包路径 Mac 上 `/tmp/NastartCloudSyncPiece04Derived/Build/Products/Debug-iphoneos/Nastart.app`（Mac /tmp 重启则丢）。注：构建时 GitHub SwiftPM 拉取失败（SSL），按 Codex 的离线办法用证据目录的 `CachedSourcePackages` + `-disableAutomaticPackageResolution -skipPackageUpdates` 解决；另首次构建误用 `-project`（该工程无 Nastart scheme），须用 `-workspace`。

## 真机验收（iPhone 13 + iPad，保留数据覆盖安装）

- **iPhone 13**（`00008110-001E543122E0401E`，iOS 16.3.1）：devicectl 未发现该设备（CoreDevice 未列出），改用 `ios-deploy` 安装，100% InstallComplete；`ios-deploy --justlaunch` 启动成功。WDA 16.1.5（端口 8168）探针。
- **iPad A16**（`00008120-000865400C920032`，iPadOS 26.6）：devicectl 保留数据覆盖安装成功（数据库序号 2948），`devicectl device process launch` 启动，PID 1948 前台运行。WDA 16.1.5（Wi-Fi 192.168.1.26:8100）探针。
- 两台均正常启动，无崩溃；数据保留（服务、事项、偏好可读，与第 2 件验收一致）。

## iCloud 同步页（两台一致，WDA 探针 + 截图）

- **状态**：`已关闭`——开关 `开启 iCloud 同步` 为关（value=0），与设备实际一致（用户从未在本机开过同步）。
- **上次成功同步**：`等待首次同步`——正确。两台从未成功同步过（同步开关一直是关的，且生产 CloudKit 容器暂缓、本机无 entitlements），`lastSuccessfulSyncAt` 为 nil，首次提示与设备现有同步历史一致。
- **待同步**：`有未同步的更改`——正确。两台本地有服务/任务/偏好数据且从未上传过，`hasPendingChanges` 为真；与设备现有同步历史一致。
- **权益门控**：开关 `enabled=true`（可点按，未被禁用）；「我的」页显示 `Nastart Plus，Plus 已开通`，`canUse(.iCloudSync)` 门控通过；因同步未开启，「立即同步」按钮不显示（符合 `isEnabled` 门控）。
- 失败文案行未在真机出现（无失败状态），按 mock 验收（26 项含已知/未知失败中英文文案）。
- 截图：助手侧 `~/workspace/cloudsync-piece04-iphone13-sync.png`、`cloudsync-piece04-ipad-sync.png`。

## 未做 / 待办

- iPhone 18 仍未装第 4 件包（也不在本次指令的设备范围内）；回家连家里 Wi-Fi 后直接装本件签名包即可（第 4 件只改 iOS，电视端不受影响）。
- 第 5 件（本地双设备模拟 + 验收套件）未开始，等用户发话。
