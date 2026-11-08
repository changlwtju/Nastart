# Claude（本地会话）：iPad 横屏与弹层补查

2026-11-03 17:15（Asia/Shanghai）。接[iPad 宽屏批次](2026-11-03-1450-CLAUDE-IPAD-WIDE-LAYOUT.md)的“未执行”项。基线为 Codex 集成分支 `codex/ui-integration-20261103`（c89c2a0 含 Claude 28 文件，已核对与工作区一致）。

- 没有访问 NAS，没有局域网发现（“添加 NAS”里的“局域网发现”没有点）；
- 只在 `Claude-PW-ipadpro13` 上用 `--offline-ui` 场景，现有 Debug 包（iPad 宽屏批次后构建）；
- 结束后已转回竖屏并关闭 App。

## 横屏检查结果

证据：`~/Downloads/Nastart-ClaudeEvidence-2026-11-02-uisweep/ipadland/`

| 页面 | 结果 |
| --- | --- |
| 启动台（指挥中心 深色） | 设备卡片横向指标条、服务两列，正常（`lp-cmd-dark.jpg`） |
| “+”菜单 | 添加 NAS / 手动添加服务 / 管理启动页服务，正常（`plus.jpg`） |
| 管理启动页服务弹层 | 居中表单弹层，搜索、开关、恢复推荐都完整（`manage.jpg`） |
| 手动添加服务弹层 | 正常（`manual.jpg`） |
| 添加 NAS 弹层 | 表单可滚动，“连接”按钮固定在底部，正常（`addnas.jpg`） |
| Jellyfin 服务详情 | 内容约 720pt 居中，正常（`service-detail.jpg`） |
| 访问地址编辑弹层 | 正常，弹层内只有一个输入框，下方留白较多（`address-edit.jpg`） |
| 打开媒体串流 | 约 720pt 居中，正常（`direct-stream.jpg`） |
| 设备 / 事项根页面 | 浅色、深色、深色大字号都居中正常（`land--*.jpg`） |
| 启动台浅色大字号 | 服务改为单列整行，可读（`land--launchpad-root--cleanGrid-light-large.jpg`） |

## 改动

- `ios/Nastart/Nastart/zh-Hans.lproj/Localizable.strings` 第 102、120 行：“WebUI”统一为“Web UI”（同文件其余 4 处已是“Web UI”，手动添加服务与访问地址编辑两个弹层的提示不一致）。
  - SHA-256 前 16 位：`2007a5fb9a27283c` → `508d8b05041afd04`
  - `plutil -lint` 通过。
  - 17:43 补：iOS 模拟器 Debug 构建成功（日志 `ipadland/ios-sim-debug.log`），包内 zh-Hans 已无“WebUI”。ad-hoc 签名后保留数据装到 `Claude-PW-ipadpro13`。
  - 访问地址编辑弹层截图确认显示“Web UI 地址”（`ipadland/v-address-edit.jpg`）。
  - `service.open.hint` 在 iOS / tvOS 源码里没有引用，界面上看不到，只改了文案。

## 观察（未改）

- 设备根页面第一个分节标题“资源”贴着导航栏，竖屏也一样，不是横屏问题。NAS 未连接时顶部没有设备摘要，所以显得紧。需要连接态对比后再决定，暂不改。
- 访问地址编辑弹层在 iPad 上是固定大小的表单弹层，内容少时留白多；属于系统表单弹层行为，暂不改。

## 未执行

- 局域网发现、SSH 安装、Agent 指南等连接流程弹层：需要发现网络或连接态，NAS 暂停期间不做。
- 需要连接 Jellyfin 的媒体页面横屏。
- 文案改动后的其余五配置构建（只跑了 iOS 模拟器 Debug）。
- 真机。

共享状态（PROGRESS、当前交接、需求总账）未改，由 Codex 汇总。需要同步：Localizable.strings 两处文案；iPad 横屏检查结论。
