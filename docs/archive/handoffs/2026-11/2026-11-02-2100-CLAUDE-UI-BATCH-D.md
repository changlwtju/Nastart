# Claude（本地会话）：UI 清单 D 批（主题、深色、iPad）

2026-11-02 21:00（Asia/Shanghai）。对应 [UI 清单](2026-11-02-1735-CLAUDE-UI-INVENTORY-IPHONE-PORTRAIT.md) 的 D 批，并补齐[根页面离线场景](2026-11-02-1930-CLAUDE-OFFLINE-ROOT-SCENES.md)未覆盖的主题与设备。没有访问 NAS、没有局域网发现、没有操作真机或 Runner。

## 代码改动（仅 DEBUG）

根页面场景此前忽略 `--offline-ui-theme` 与 `--offline-ui-appearance`，只能看到 cleanGrid。

- `Nastart/Core/Design/AppTheme.swift`：
  - `OfflineRootStoresHost.init(theme:dark:)` 在创建 `AppearanceStore` 前，把主题和显示模式写进临时偏好域 `nastart.offline-ui.roots`；参数有默认值，原测试的 `OfflineRootStoresHost()` 不变。
  - `NastartOfflineRootScene` 改为接收整个 `OfflineUIConfiguration`。
- 改后 SHA-256 前缀 `a13c11f3`（改前 `936f932e`）。
- 标准偏好域仍不写入：iPhone 模拟器上，本批截图前后 `Library/Preferences` 里都只有临时域的 plist，没有 `com.changliwen.nastart.plist`。

## 覆盖

| 设备 | 内容 | 张数 |
| --- | --- | --- |
| `Claude-PW-iphone`（iPhone 17 Pro / iOS 27.0）竖屏 | 三个根页面 × 3 主题 × 浅/深 | 18 |
| 新建 `Claude-PW-ipad`（iPad A16 / iOS 27.0）竖屏 | 三个根页面 × {浅、深、glassDeck 深、大字号}；library、detail、settings、help-detail、connection、privacy-cache | 18 |
| 同一 iPad 横屏（21:10 补拍，用户授权旋转后） | 三个根页面 × {浅、commandCenter 深、大字号}；同上 6 个场景 | 15 |

证据：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/dbatch/`。

## 结论

### 不是缺陷
- **iPhone 横屏**：`NastartAppDelegate` 在 iPhone 上只允许竖屏（播放器除外），iPad 才允许全方向。这是现有设计，iPhone 横屏不纳入清单。
- **首次截图空白**：安装后第一次启动、以及 iPad 模拟器上的部分场景，3 秒等待不够；等待 7 秒重拍后全部正常。截图脚本要给 iPad 至少 7 秒。

### 新问题

| # | 级别 | 页面 | 现象 | 状态 |
| --- | --- | --- | --- | --- |
| 12 | P3 | iPad 启动台 | 服务卡片单列铺满整屏宽，竖屏下一行只放一张；宽屏没有利用 | 待设计决定 |
| 13 | P3 | iPad 设备、事项、设置、帮助详情 | 列表和正文铺满约 800pt 宽，行太长（与上次 iPad 真机观察一致） | 待设计决定：限制可读宽度，或改用分栏 |
| 15 | P3 | iPad 横屏详情页 | 背景大图铺满约 1180pt 宽，第一屏只看到大图和简介，播放按钮下方的演职人员被挤到折叠线外 | 待设计决定：横屏限制大图高度，或左右分栏 |
| 14 | P4·测试夹具 | commandCenter、glassDeck 下的根页面 | 底部“离线界面测试”横幅用系统背景色，在渐变主题上是一条白/黑色带 | 仅 DEBUG，可不改 |

### 已确认正常
- 三个根页面在三种主题 × 浅/深色下都可读：
  - 强调色与分段控件对比度够；
  - glassDeck 深色下的列表文字清楚；
  - commandCenter 启动台的竖排指标正常。
- iPad 横屏：没有错位、截断或重叠；#12、#13 在横屏下更明显（列表和卡片铺满约 1180pt）。海报墙横屏每行 5 张，正常。
- iPad 上：
  - 详情页和离线海报墙的版式正常；
  - 清缓存确认是锚定在按钮上的弹出框，不再盖住标题，和 iOS 27 iPhone 上的现象不同；
  - 大字号根页面换行正常。

## 未执行

- **其他未执行项**：
  - iPad 上 commandCenter 浅色、glassDeck 浅色；
  - 126 个媒体场景在 iPad 上的全量清单；
  - 真机。
- **构建与测试**：只编译了 iOS 模拟器 Debug，没跑六配置和宿主测试。改动只在 `#if DEBUG` 的 iOS 分支，Release 不受影响，但这一点仍需下次六配置确认。
- **磁盘**：补拍后剩余降到约 5.6GiB，低于 6GiB 构建阈值。已删除自建的 `Claude-PW-ipad`，但剩余只到约 5.5GiB，说明空间不是被它占的；来源没有查，下次构建前要先腾出空间。

共享状态（PROGRESS、当前交接、需求总账）未改，由 Codex 汇总。需要同步：根页面场景现在支持主题和深浅色参数；临时 iPad 模拟器 `Claude-PW-ipad` 已删除；磁盘低于构建阈值。
