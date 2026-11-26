# Apple TV 两个管理页宽度验收（Muse 真机验收）

**日期**：2026-11-21 18:51–19:04（北京时间）
**交接依据**：`docs/archive/handoffs/2026-11/CODEX-2026-11-21-TV-MANAGEMENT-PAGES-WIDTH.md`；前情见 `docs/handoffs/TV-SHEET-WIDTH-STILL-COMPRESSED-2026-11-21.md`（用户 18:26 实拍：连接管理与管理显示弹窗仍是居中窄卡）。
**工作区**：`/Users/lagransun/workspace/Nastart`，HEAD `8db1cc64`，219 个未提交修改完整保留。

## 构建与安装

- **构建**：Xcode 27.2 GUI Terminal 标准构建（DerivedData `/tmp/NastartTVMgmt20261121Derived`），`BUILD SUCCEEDED`（18:52）。日志 `/tmp/nastart-tv-mgmt-build-20261121.log`。TVNASViews.swift 与 LibraryViews.swift 均在构建日志中。
- **签名**：codesign 通过，Identifier `com.changliwen.nastart.tv`，Team `5436TB5498`；描述文件 `tvOS Team Provisioning Profile`，到期 2026-11-27 12:58:54 UTC。
- **包哈希**：主程序 SHA-256 `77e7f82eca4416d3dd7d42a488cfb1f3ad1e8cde5a592aed9de90c2e0ea88a81`；`NastartTV.debug.dylib` SHA-256 `bb633eba3ef68041eef9d08de6ca768b1d94fe7ab0f5881f7bc49c6238081dd8`（与 Codex 副本 `0ceef64b…` 不同，属不同构建方式的正常差异，源码相同）。
- **安装**：`devicectl device install app` 18:54:25–18:54:30 CST，5 秒，保留数据覆盖安装；安装容器 `D36EB8BF-3A50-4BEC-B95D-28F6F6B1A5E3`，databaseSequenceNumber 656（上一轮 600）。电视上确认 Nastart 0.1.0。
- **启动**：`devicectl device process launch` 正常，PID 966 在跑。

## 验收结果：三项全部通过

### 1. 管理显示（启动台 → 管理显示）——通过

- 探针 `testMgmtManageDisplayAcceptance` **passed**（33.4s）。日志 `/tmp/nastart-tv-mgmt-accept2-20261121.log`（第 383、387 行）。
- 路径：启动台 → 管理显示按钮（`tv.services.manageVisibility`）→ 整页 `tv.services.visibility.page` 已打开（**不再是弹窗**）。
- 收藏分组卡片可见 frame：**(162.0, 349.0, 1596.0, 128.0)**，宽度 **1596pt ≥1400pt**，横向 162–1758 在视口 0–1920 内。
- 两列服务名完整：homepage、homepage-dockerproxy、sonarr、radarr、jellyfin、prowlarr、qbittorrent（7 个，两列排布，名称无截断）。截图与量值一致。
- 按一次 Menu 回到启动台（`backOnLaunchpad=true`）。

### 2. 连接管理（存储与媒体 → 连接管理）——通过

- 探针 `testMgmtConnectionsAcceptance` **passed**（37.5s）。日志 `/tmp/nastart-tv-mgmt-accept2-20261121.log`（第 283、286 行）。
- 路径：启动台 → 存储与媒体（`tv.open.networkLibrary`）→ 右上“+ 连接管理”（`network.connections.manage`）→ 整页 `network.connections.page` 已打开（**不再是弹窗**）。
- 存储连接分组卡片可见 frame：**(210.0, 164.0, 1493.5, 310.5)**，宽度 **1493.5pt ≥1400pt**，横向 210–1703.5 在视口 0–1920 内。
- 行完整显示：Synology DSM 行 “Synology DSM · 当前 NAS 登录配置”；WebDAV 行 “我的 WebDAV、WebDAV · 连接设置与媒体文件夹”。两行均完整，无截断。截图与量值一致。
- 按一次 Menu 回到存储与媒体（`backOnStorage=true`）。

### 3. 服务详情宽度回归——通过

- 探针 `testFixVerificationWidthCleanGrid` **passed**（36.2s）。日志 `/tmp/nastart-tv-mgmt-accept-20261121.log`（第 996 行）。
- `PROBE service-detail-card`：信息卡 frame (150.0, 195.0, 1620.0, 256.0)，视口 (0.0, 0.0, 1920.0, 1080.0)。**仍为上轮 1620pt 基线**，管理页改动未影响服务详情页。

## 探针方法修正（本轮教训，写入记录）

- 旧探针 `testSheetWidthManageDisplay` 取到的层级最大宽度 1840pt 已作废：它量的是 ScrollView/容器，不是可见卡片。
- 本轮新量法：以卡片内锚点元素（管理显示取首个服务开关，连接管理取 DSM 行）为中心，在包含该中心的后代元素中取“宽度 ≥1400pt 且高度最小”的一个——ScrollView（1840pt、整页高）被排除，单节卡片（1596pt/1493.5pt）被正确量到。
- 分组标题（“收藏”）位于卡片上方，不能做锚点；连接管理入口在页面右上 header，焦点扫掠到不了，探针改为先连按 Up 到按钮获焦再选中。
- 探针文件 `tvos/NastartTV/UITests/TVLaunchTests.swift` 现 1509 行，括号 225/225 平衡；含新增 `testMgmtManageDisplayAcceptance`、`testMgmtConnectionsAcceptance`、`visibleCardFrame`（锚点版）及调试探针 `testMgmtDebugManageDisplayTree`。

## 截图位置（Mac 侧）

- 管理显示整页：`/tmp/NastartTVMgmt20261121Derived/Logs/Test/Test-NastartTV-2026.11.21_18-55-38-+0800.xcresult` 内附件（Muse 侧副本 `~/workspace/mgmt-shot-b.png`）。
- 连接管理整页：`/tmp/NastartTVMgmt20261121Derived/Logs/Test/Test-NastartTV-2026.11.21_19-01-46-+0800.xcresult` 内附件（Muse 侧副本 `~/workspace/mgmt-connections.png`）。
- 存储与媒体页（第一轮连接管理探针未打开连接管理时截到）：`~/workspace/mgmt-shot-a.png`。

## 结论

**连接管理与管理显示两个弹窗的宽度问题已修复并验收通过。** 两页现均为整页导航，卡片宽度 1596pt / 1493.5pt 均达标，行内容完整，Menu 返回正常；服务详情页 1620pt 基线未受影响。用户此前实拍的两个窄弹窗问题至此关闭。
