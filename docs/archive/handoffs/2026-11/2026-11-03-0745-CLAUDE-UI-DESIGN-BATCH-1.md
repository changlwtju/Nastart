# Claude（本地会话）：设计项第一批（#7、#9、#15）

2026-11-03 07:45（Asia/Shanghai）。用户确认按[设计项方案](2026-11-03-0000-CLAUDE-UI-DESIGN-PROPOSALS.md)的建议顺序推进。没有访问 NAS、没有局域网发现、没有操作真机或 Runner。

## 结果

| # | 处理 | 文件 |
| --- | --- | --- |
| 7 | **已改**：清缓存确认从 `confirmationDialog` 改为 `alert`，与重置证书一致。保留了 `onCancel` 回调。 | `Nastart/Core/Design/AppTheme.swift`（`NastartCacheClearPrompt`） |
| 9 | **已改**：媒体侧主操作按钮的禁用态改为灰底（iOS `systemGray4`，tvOS 灰 30%）加次要文字色，不再把强调色透明度降到 0.4。详情“播放”和连接表单“连接并选择文件夹”都用这个样式。 | `Packages/NetworkMedia/Sources/NetworkMedia/MediaDetailPresentation.swift`（`MediaDetailActionFrame`） |
| 15 | **不改**：复核代码，详情大图在 iPad 上是固定最小高度 390pt，不是按宽度铺满。iPad 横屏（820pt 高）占约 48%，第一屏已能看到播放按钮、简介和演职人员标题。方案中“挤出第一屏”的判断偏重，撤销此项。 | — |

改后 SHA-256：
- `AppTheme.swift`：`b38c3fa6…c73fbbf6`
- `MediaDetailPresentation.swift`：`adc983bb…20a5f8ca`

## 验证

- **模拟器复验**：`Claude-PW-iphone`，iOS 27.0，浅色和深色（证据 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/batch1/`）。
  - `privacy-cache`：确认框居中显示，不再盖住页面标题。按钮上下排列是系统根据按钮文字长度决定的。
  - `detail`、`connection`：禁用按钮灰底灰字，可读，也能看出不可点。
  - `privacy-reset`：未改，作为对照。
- **包单测**：`NetworkMedia` 全部 305 项通过，0 失败。之前报告里写的 16 项只是离线场景那一组。
- **六配置**：iOS/tvOS × 模拟器 Debug、真机 Debug、真机 Release 全部 BUILD SUCCEEDED，沿用 Codex 闲置的 SavedPassword 产物目录。日志在 `~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/batch1/six/`。
- **磁盘**：开工前清理到约 18GiB，构建后仍约 18GiB。

## 真机复验（用户授权，iPhone 13 与 iPad A16）

- **安装包**：签名真机 Debug 包，用项目原有的自动签名。
  - 深度严格验签通过。
  - 描述文件 2026-11-08 到期，包含这两台设备。
  - 没有请求新描述文件。
- **iPad A16（iPadOS 26.6）**：
  - 安装前 App 正在运行（PID 11967，路径为上一批安装的 `6D1755F0-…`），先备份 `Library/Preferences`。
  - 用 `devicectl device install app` 保留数据覆盖安装，新路径 `CCFAB52D-…`。
  - 安装前后偏好 SHA-256 前缀都是 `68033ae95b0b2b30`，逐字节一致。
- **iPhone 13（iOS 16.3.1）**：
  - 安装前 App 正在运行（PID 56851，路径 `220CDF95-…`），先用 `ios-deploy --download` 备份偏好。
  - 用 `ios-deploy --nostart --bundle` 覆盖安装，结果 InstallComplete。
  - 安装前后偏好 SHA-256 前缀都是 `e32b3846fdc72f48`，逐字节一致。
- **截图**：两台设备各拍 5 张离线场景：`privacy-cache`、`privacy-reset`、`detail`（浅色和深色）、`connection`。
  - 先单独打开一次，确认是离线页面后才批量执行。
  - 拼图：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/batch1/real/真机效果-第一批.jpg`
- **结论**：
  - iOS 16 和 iPadOS 26 上，清缓存确认都是居中的系统 alert，不再挡住标题。
  - iOS 16 上它的按钮上下排列，重置证书的按钮左右排列，这是系统根据按钮文字长度决定的。
  - 禁用的“播放”和“连接并选择文件夹”两台设备上都是灰底灰字，浅色和深色都可读。
- **收尾**：核对 PID 和路径都属于本批新包后，结束了自己启动的进程，两台设备上都已没有 Nastart 进程。
- **其他**：iPhone 13 截图左侧的绿色条是系统覆盖层，和上一批一致。iPad 当时是倒置摆放，截图已经转正。

## 未执行

- tvOS 上禁用按钮的实际观感：只确认能编译，没有截图。
- 宿主测试：没有跑，改动不涉及 store 和逻辑。

共享状态（PROGRESS、当前交接、需求总账）未改，由 Codex 汇总。需要同步：#7、#9 的视觉变更（同时影响 tvOS 禁用按钮）；#15 撤销。
