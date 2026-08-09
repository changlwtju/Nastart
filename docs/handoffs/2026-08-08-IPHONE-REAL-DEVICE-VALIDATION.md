# iPhone 真机播放补测记录

日期：2026-08-08
设备：iPhone 13，iOS 16.3.1（20D67），UDID `00008110-001E543122E0401E`
限制：不升级、不抹除、不重启 iPhone；仅通过 USB 进行安装、启动和诊断。

## 本轮可确认的事实

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| iOS 16.3.1 DeviceSupport | 通过 | 本机缓存已补齐 `DeveloperDiskImage.dmg/.signature`；`ios-deploy` 报告 DDI 成功挂载并使用 Symbols |
| Nastart 安装/启动 | 通过 | 既有真机包重新安装成功；`pymobiledevice3 developer dvt launch` 返回进程；截图显示启动台首页 |
| 代码静态回归 | 通过 | `python3 scripts/preflight.py` 全部 PASS |
| DSM 受控 H.264 MP4 | 通过 | iPhone 13 首帧约 610 ms，40% 位置非零 Range，进入 playing/ready |
| Jellyfin 受控 WAN | 通过 | 250 ms/2.5 Mbps 模拟链路首帧约 3.32 s，从约 65% 位置 Range 继续，无错误/替换 |
| 真实 NAS/Jellyfin 元数据链路 | 通过 | 真实域名+端口登录、快照、36 部电影/36 部剧集/3 个媒体库均已加载 |
| 真实 Jellyfin 多样本首帧 | 已记录 | 多个 MKV 首帧约 1.335/1.883/2.063 s；音轨 2/4 条、字幕 5/9 条可由诊断发现 |
| iPhone 蜂窝传输（本轮补测） | 部分通过 | 截图显示 Wi‑Fi“关闭”、状态栏 4G；启动 Nastart 后系统日志记录 `Cellular tcp4 flow`，Wi‑Fi/Wired 均为 0，Nastart 流累计收到约 233 KB 数据并持续约 30 秒 |

## 2026-08-08 最终包专项复测

最终签名包已重新安装到 iPhone 13 和 iPad 9。iPhone WDA 已恢复可用，完成了以下真实操作：

| 项目 | 结果 | 现场证据 |
| --- | --- | --- |
| Jellyfin 中途切换清晰度 | 通过 | `方世玉` 播放中切换到 `1080p / 12 Mbps`；等待转码首帧后恢复真实画面，时间线仍在约 09:53，没有回到 00:00 |
| Jellyfin 快进 | 通过 | 播放中点击“前进 15 秒”，时间从约 08:32 跳到约 09:53，未重建到起点 |
| Jellyfin 音轨/字幕面板 | 通过 | 真实面板显示 FLAC 音轨和两条 ASS 字幕，选择状态保留在当前播放会话 |
| 真实系统 PiP 进入 | 通过 | AVPlayer 原生 `PIP Button` 可见；点击后出现系统画中画窗口，窗口显示影片画面和播放控制 |
| 真实系统 PiP 退出 | 通过 | 点击画中画恢复按钮回到 Nastart 播放页，画面仍为中途连续内容，未回到开头 |
| 当前 DSM/IP 入口 | 未完成 | 网络页确认 DSM 当前为 `https://lagransun.cn:5001`；可见 IP+端口条目是 Docker 服务 `192.168.1.64:3000/9090`，不是 DSM 文件播放入口 |
| ISO 样本 | 未完成 | 当前设备文件浏览到的 `/video/media`、`/video/downloads` 样本未发现 `.iso`；只能继续保证 ISO9660 适配器，不把 MKV Blu-ray REMUX 当作 ISO 证据 |

## 本轮仍不能宣称已通过的项目

| 项目 | 当前状态 | 原因/下一步 |
| --- | --- | --- |
| 蜂窝下实际视频播放 | 未完成 | 已确认过蜂窝 TCP/应用流量，但本次最终包仍未在蜂窝状态下进入具体视频页面并记录首帧、Range 和持续播放 |
| IP+端口 DSM/Jellyfin 播放 | 未完成 | 当前真实配置没有可用的 DSM IP+端口入口；不能用 Docker 端口替代 NAS 文件播放端点 |
| 真机点击快进/回退 | 通过 | WDA 已恢复；真实 Jellyfin 播放中完成快进，时间线未重置 |
| 点击音轨/字幕/清晰度且不中断 | 部分通过 | 音轨/字幕面板和清晰度切换已在最终包实机操作；服务端清晰度切换需等待新 HLS 首帧，不能宣称毫秒级切换 |
| 长时间连续播放 | 未完成 | 已有短时播放与真实首帧证据，但最新受控长时启动未进入实验室环境，不能宣称连续播放通过 |
| ISO 真机首帧 | 未完成 | 当前 NAS 样本没有发现 `.iso`；代码支持 ISO9660 Range 适配器，但没有 UDF/Blu-ray ISO 样本可验证 |
| PiP 实际进入/退出 | 通过 | iPhone 上完成原生 PiP 进入、画中画窗口播放、恢复回 Nastart；未重置播放位置 |
| Infuse/Fileball/Lenna 交接首帧与回跳 | 未完成 | 三个 App 已安装/可列出；尚未完成真实系统分享/URL 交接、第三方首帧和返回 Nastart 的位置恢复验证 |

## WDA/XCTest 阻塞记录

- **历史上 iPhone WDA 确实可用，且曾用于本项目真机调试。** `/tmp/vlc-downgrade-context.tsv` 保存了真实 iPhone 会话：WDA 地址为 `http://127.0.0.1:8100`，会话 ID `9198754F-ABC6-42E3-A6A8-9E31D9C9101A`；记录中实际执行过 `/elements`、`/element/{id}/click`、`/wda/dragfromtoforduration`、`/source`、`/screenshot` 和 `/wda/apps/launch`，并完成“设备 → 文件 → 视频 → 预览”等页面操作。这一证据推翻“WDA 从未可用”的表述。
- Mac 上定位到历史构建产物：`/tmp/Nastart-WDA-Derived/Build/Products/Debug-iphoneos/WebDriverAgentRunner-Runner.app` 与配套 `WebDriverAgentRunner_iphoneos26.5-arm64.xctestrun`，构建时间为 2026-08-06 16:44–16:53。该 Runner 的 Bundle ID 是 `com.changliwen.nastart.WebDriverAgentRunner.xctrunner`；iPhone 历史系统日志也明确记录同一 Bundle ID 在设备上运行，并对应实际的 WDA/XCTest 会话。
- 当前 `Nastart-WDA-iPhone2` 产物的 Bundle ID 被改成了 `com.changliwen.nastart.WDARunner.xctrunner`。两者签名团队相同，但 App/Test Bundle ID、Provisioning application-identifier 和 xctestrun 中的 `TestHostBundleIdentifier`/`BundleIdentifiersForCrashReportEmphasis` 均不同；这会让旧启动链路无法匹配到历史 Runner。当前与历史产物都基于 WDA 16.1.5 和 Xcode 26.x SDK，因此 Bundle ID/启动链路差异是目前更有力的回归原因。
- `.xctestrun` 的另一处差异是历史包的 `TestingEnvironmentVariables.DYLD_INSERT_LIBRARIES` 包含 `libMainThreadChecker.dylib:/usr/lib/libRPAC.dylib`，当前包只有 `/usr/lib/libRPAC.dylib`；该参数也应随历史包一起保留。
- 旧 WDA 包可以安装，`pymobiledevice3 developer dvt screenshot` 在 iOS 16.3.1 上可用。
- 当前 Xcode 为 26.6（XCTest framework version `24904`，SDK 26.4/26.5），而目标设备是 iOS 16.3.1。`pymobiledevice3 ... xcuitest` 在等待 `XCTestDriverInterface` 超时；`xcodebuild test-without-building` 同时报告 `Encountered a build number ""` 和 `Logic Testing Unavailable`。
- 已在 Mac 全新 DerivedData 中统一重建、签名并安装 WDA；安装和 DDI 挂载成功，但同样无法建立 XCTestDriver 通道，说明问题不在 WDA 签名或 DeviceSupport 文件缺失，而在 XCTest 运行时/设备测试服务版本配对。
- 因此当前结论应为“**曾经可用，现已因 Bundle ID/启动链路变更而回归**”，而不是“iOS 16 的 WDA 本身不可用”。历史 `.app/.xctestrun` 已在 Mac 上找到并保留。
- `xcodes` 已安装用于准备旧版 Xcode，但 Apple Developer 下载需要在 Mac 上完成 Apple ID 登录；不会在对话中收集或代填 Apple ID 密码。
- 这不是 iPhone 系统升级问题。要完成触控矩阵，应在 Mac 上安装与 iOS 16.x 匹配的旧版 Xcode/XCTest（推荐 Xcode 14.3.1 或 Xcode 16.3），切换 `DEVELOPER_DIR` 后重建 WDA；整个过程不改 iPhone 系统。

因此，本记录只把已取得的真机证据列为通过，其余项目保持“未完成”，没有把模拟 WAN、代码路径或外部 App 安装状态当成真实功能通过。

## WDA 恢复结果（2026-08-08 08:31）

用户已明确允许恢复 WDA；未升级、重启或修改任一 iPhone 设置。

| 设备 | 方式 | 本机转发 | `/status` |
| --- | --- | --- | --- |
| iPhone 13 / iOS 16.3.1 | 安装历史 `WebDriverAgentRunner-Runner.app`，使用 USB/usbmux DVT 启动 `com.changliwen.nastart.WebDriverAgentRunner.xctrunner` | `127.0.0.1:8100 -> device:8100` | `ready: true`，WDA 16.1.5 |
| iPad 9 / iPadOS 18.3.1 | 保留同一 WDA 包，使用 `--userspace` DVT 启动 | `127.0.0.1:8200 -> device:8100` | `ready: true`，WDA 16.1.5 |

当前两个 DVT 会话和两个 `iproxy` 均由保持前台的独立 Mac 会话承载，避免非交互 shell 回收端口转发。iPad 使用 8200，未占用或停止 iPhone 的 8100。根隧道命令对 iOS 16.3.1 的 iPhone 不需要；终端中出现的 QUIC 警告属于 iOS 18.2+ 的隧道兼容提示，不代表 iPhone 系统被修改。
