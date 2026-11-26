# Apple TV 弹窗宽度仍被压缩：连接管理与管理显示（给 Codex）

**日期**：2026-11-21 18:26–18:31（北京时间）
**背景**：服务详情页（Docker 容器详情，整页）宽度已修好并验收通过（信息卡 1620pt，三主题全过）。但用户 18:26 拍了两张电视照片，证明**连接管理与管理显示两个弹窗仍是窄条**，问题没有完全修复。Muse 随即用探针与截图核实，确认用户说得对。

## 用户照片（地面真值）

用户 18:26 发来两张电视实拍（已存项目外，Muse 侧有副本）：

1. **管理显示弹窗**（启动台 → 管理显示）：居中窄卡，约占屏宽 1/3，两侧露出变暗的启动台。卡内“收藏”“媒体”两组开关被挤成两列窄格。
2. **连接管理弹窗**（存储与媒体 → 连接管理）：同样居中窄卡，约占屏宽 1/3。卡内“存储连接”“Synology DSM”“我的 WebDAV”“添加存储连接”“媒体文件夹”逐项竖排，文字被截断（“Synology DSM · 当前 NAS 登录配置”只显示一半）。

两张照片的共同点：弹窗是居中窄卡，不是整页；卡内内容被压窄。

## Muse 探针核实（18:27–18:31）

- 探针 `testSheetWidthManageDisplay` 打开管理显示弹窗，截图与用户照片一致：**弹窗是居中窄卡**，目测约 620pt 宽（屏宽 1920pt）。探针截图见 `/tmp/tv-sheet-small.png`（Muse 侧副本 `~/workspace/tv-sheet-small.png`）。
- 注意：该探针曾误报 `sheetWidth=1840` 通过——它量的是层级里最宽的元素（ScrollView/容器，frame 高达 2143pt），不是肉眼可见的弹窗卡片。**该 1840 数值作废，不代表弹窗宽度。** 正确的量法是量弹窗卡片本身的可见 frame，约 620pt。
- 服务详情页（整页）不受影响：18:39 刚复跑 `testFixVerificationWidthCleanGrid` 仍通过，信息卡 (150, 195, 1620, 256)。**只有弹窗这两处仍窄。**

## 根因（已定位到代码）

两个弹窗都是 tvOS `.sheet` 弹出，系统默认给窄宽居中卡；但卡内视图按整页布局写（`tvPageInsets` 左右各 70pt，预期 1920pt 视口），两者冲突，内容被压窄。

| 弹窗 | 入口 | 弹出点 | 视图 |
|------|------|--------|------|
| 连接管理 | “我的” → 连接管理（`tv.settings.connections`）或存储与媒体 → 连接管理 | `TVNASViews.swift:50` `.sheet(isPresented: $connect)` | `TVConnectionsView`（:116），`ScrollView + tvPageInsets() + tvPageTheme()`（:39–40） |
| 管理显示 | 启动台 → 管理显示（`tv.services.manageVisibility`） | `TVNASViews.swift:833` `.sheet(isPresented: $manageServices) { NavigationStack { TVServiceVisibilityView(...) } }` | `TVServiceVisibilityView`（:1421），`ScrollView + tvPageInsets() + tvPageTheme()` |

## 给实现方的任务

1. 让两个弹窗的内容宽度达到与服务详情页一致的水平（卡片 ≥1400pt，横向在视口内），或改成整页导航（`navigationDestination`，与服务详情页同一路数）。任选其一，以实测为准。
   - 若保留 `.sheet`：给弹窗内容设定明确宽度（参考服务详情页在 ScrollView 外读视口宽度、扣 70pt 的做法），并确认 tvOS sheet 容器本身允许该宽度；若系统 sheet 宽度有上限，改用整页导航。
   - 若改整页导航：连接管理与管理显示均改为 `navigationDestination` 压入 NavigationStack，返回用原生 Menu（与服务详情页已验证的机制一致）。
2. 两个弹窗都要修，不要只修一个。修完后两处都要实测。
3. 探针由 Muse 负责：Muse 将量弹窗卡片本身的可见 frame（不是层级最宽元素），要求单卡片 ≥1400pt 且横向在视口内。连接管理弹窗在“我的”tab，XCTest 焦点到不了，Muse 会改用其他方式验证或请用户遥控复核。

## 验收标准

- 管理显示弹窗：从启动台打开，卡片宽度 ≥1400pt，横向在视口内；卡内“收藏”“媒体”两组开关排布舒展，不挤不截断。
- 连接管理弹窗：从存储与媒体（或“我的”）打开，卡片宽度 ≥1400pt，横向在视口内；“Synology DSM · 当前 NAS 登录配置”“我的 WebDAV”等行完整显示不截断。
- 服务详情页不受影响：复跑 `testFixVerificationWidthCleanGrid` 仍通过（1620pt）。

## 交回要求（沿用既定规则）

实现方改完后必须自己编过（Xcode 27.2，tvOS）、跑过相关测试再交回，不交“看着对但没编过”的代码。交回时说明：改了哪些文件、是否编过、两个弹窗宽度是否复测通过。Muse 随后在真机电视上验收，失败写回本文档打回重改。
