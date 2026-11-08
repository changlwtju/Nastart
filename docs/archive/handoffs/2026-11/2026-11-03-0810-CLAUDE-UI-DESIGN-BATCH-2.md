# Claude（本地会话）：设计项第二批（#13 iPad 可读宽度）

2026-11-03 08:10（Asia/Shanghai）。按[设计项方案](2026-11-03-0000-CLAUDE-UI-DESIGN-PROPOSALS.md)的顺序推进。没有访问 NAS、没有局域网发现；真机只打开离线场景。

## 改动

- **`Nastart/Core/Design/AppTheme.swift`**：
  - 新增 `NastartReadableWidth` 修饰符和 `View.nastartReadableWidth()`；
  - 离线设置场景 `NastartOfflineSettingsScene` 在 iOS 上接入。
- **修饰符行为**：
  - 只在 iOS 17+ 且宽度类为 `regular` 时生效：
    - 用 `GeometryReader` 取容器宽度；
    - 用 `contentMargins(.horizontal, max(0, (宽 − 720) / 2), for: .scrollContent)` 把滚动内容收到约 720pt 并居中；
    - 滚动区域和背景仍铺满，页边空白处也能滚动。
  - iPhone（紧凑宽度）和 iOS 16 保持原样。
  - 容器不足 720pt 时（如 iPad 竖屏表单、弹出表单）边距为 0，没有副作用。
- **只在指定页面接入，没有加进 `nastartPageTheme()`**，以免启动台和海报墙也被限宽：
  - `DevicesView` 根列表；
  - `TasksView` 根列表；
  - `MineView.swift` 里全部 14 处使用 `nastartPageTheme()` 的页面（我的、设置子页、帮助等）。
- **没有新增文件**。

| 文件 | 改后 SHA-256 |
| --- | --- |
| `Nastart/Core/Design/AppTheme.swift` | `0dfba5dc…1b169e4c` |
| `Nastart/Features/Devices/DevicesView.swift` | `51349315…973c04be` |
| `Nastart/Features/Tasks/TasksView.swift` | `03dbf5b7…9cf39e9f` |
| `Nastart/Features/Mine/MineView.swift` | `2b84b49e…c5688f18` |

## 验证

- **iPhone 模拟器**：`Claude-PW-iphone`，iOS 27。设备、事项、设置、帮助详情和改动前一致，没有限宽。
- **iPad A16 模拟器（竖屏 820pt）**：按规则两侧各收 50pt，变化很小，符合预期。
- **iPad 横屏**：新建的 iPad 模拟器换了编号，旋转需要用户在面板授权，用户当时不在电脑前，所以未执行。
- **改用 13 英寸 iPad Pro 模拟器 `Claude-PW-ipadpro13`（竖屏 1032pt）**：
  - 设备（cleanGrid 浅色、glassDeck 深色）、事项、设置、隐私与安全、帮助详情，内容都收在约 720pt 内居中；
  - 渐变背景仍铺满整屏。
  - 证据在 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/batch2/`。
- **截图等待时间**：13 英寸模拟器首次打开某些页面需要约 10 秒。
- **包单测**：`NetworkMedia` 305 项全部通过。
- **六配置**：iOS/tvOS × 模拟器 Debug、真机 Debug、真机 Release 全部 BUILD SUCCEEDED。日志在 `batch2/six/`。
- **iPad A16 真机（iPadOS 26.6）**：
  - **安装**：签名 Debug 包，深度严格验签通过，用 `devicectl` 保留数据覆盖安装，新路径 `C9AC5F42-…`。
  - **安装前**：App 正在运行（PID 12633，路径为第一批安装的 `CCFAB52D-…`），先备份了偏好。
  - **偏好**：安装前后偏好 SHA-256 前缀都是 `68033ae95b0b2b30`，逐字节一致。
  - **截图**：打开设备、事项、设置、隐私与安全、帮助详情这 5 个离线场景截图，显示正常。竖屏 820pt 下两侧各收 50pt，和预期一致。
  - **收尾**：核对 PID 和路径后结束了自己启动的进程。
- **对比图**：`batch2/iPad限宽效果-第二批.jpg`，已发给用户。

## 未执行 / 限制

- iPad 横屏截图（需要授权旋转）。
- iPhone 13 真机：iPhone 是紧凑宽度，限宽不生效，没有重装。
- iOS 16 iPad：没有这类设备，按设计保持原样。
- **页内跳转的子页面**：设备、事项根页面之下的页面没有接入，例如容器、文件、服务详情（在 `DevicesView.swift`、Launchpad 等文件里）。如需要，可以逐页接入。
- **模拟器管理**：`Claude-PW-ipad`（A16）已删除，`Claude-PW-ipadpro13` 已关机保留，供第四批（启动台两列）复用。

共享状态（PROGRESS、当前交接、需求总账）未改，由 Codex 汇总。需要同步：新增 `nastartReadableWidth()` 及接入范围；新增模拟器 `Claude-PW-ipadpro13`。
