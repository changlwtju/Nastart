# 2026-11-10 Nastart 播放调试：Codex → Claude 接续

用户决定将后续调试转到 Claude。第一优先是 S19 大文件在 iPad 上原画起播后反复缓冲，先查清 SMB 收到的数据经过 Reader、共享代理到播放器的时间和去向，再补同包三入口对照。Apple TV 已由用户暂停。iPhone 18 这次只更新和核离线启动，窗口已归还。本文供用户在 Claude 打开，不代表已向 Claude 发送消息或已打开真机、模拟器、构建或源码写入窗口。

开工读根目录 [CLAUDE](../../../../CLAUDE.md)、[AGENTS](../../../../AGENTS.md)、[PROGRESS](../../../../PROGRESS.md)、[当前交接](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)、[播放调试规范](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)、[真机远控手册](../../../development/PHYSICAL-DEVICE-REMOTE-CONTROL.md) 和 [资源登记](../../../development/AGENT-RESOURCE-STATE.json)。以下内容覆盖 11 月 8 日旧交接的负责人、包身份及实现状态，旧交接仍可查样本和来历。

## 源码与最新包

- 本机工作区 `/Users/lagransun/workspace/Nastart`，`main/8db1cc6491c6e8bce2bc8b41f57e6112142132ba` 加现有未提交改动。本批没有修改产品源码、提交、暂存、推送或改签。必须使用含现有改动的同源基线；只取 Git HEAD 或远端 main 会遗漏当前播放和认证实现。开始新批前保存 `git status --short`，按完整文件登记范围。若两边并行，先准备包含当前修改的独立同源目录，不接管旧工作树和缓存。
- 当前签名 Debug 构建于 11 月 10 日 03:41:18 CST，498 项冻结 iOS 输入逐项相同，清单 SHA-256 `29dd2eccfe692d9d2079ac2e825209d66f155fcb4518e1e7537a8269de9f0eab`。主程序 `5e97386a67441070c5305c4abc65c96b2ee6bc8fa27e4837d983b13edfc8069a`；Debug dylib `01a6ec564dbc666db22a32687792b94e8d09b38875de760eb9bc1d3cdd991175`。有效期至 11 月 15 日 08:30:17 CST。私有指针 `/tmp/nastart-jellyfin-standard-header-current` 指向目录，目录内 `product/Nastart.app`、`source-inputs-private.json`、构建日志与签名元数据可复核。下一次现场重新核设备、签名、源码和安装回执，版本号相同不能代替；源码变化后先构建再测。
- 本次 iPhone 18 已对目标覆盖、签名团队/Bundle ID、深度签名、主程序与 dylib 重新验证。首次签名解析遇新版工具的文本输出，切换成 XML 后正常通过；未改签或重建。

## 真机现场

| 设备 | 最近确证 | 下一窗边界 |
| --- | --- | --- |
| iPhone 13（iPhone14,5 / iOS 16.3.1） | 03:41:47 已保留装 `01a6ec56…`。用户授权重登一次后，Jellyfin 资源库、S19 原画出画和普通退出成功，再次冷启动仍能读库。 | 本批未再操作，fresh 核 USB、App 与 Runner。若 401，先留故障并区分域名库、内网身份和令牌恢复；用已授权账号流程处理，凭据只在私有渠道/应用内，不写文档、命令日志或证据。旧会话反复被拒的原因仍开放。 |
| A16 iPad（iPad15,7 / iPadOS 26.6） | 05:09:49 已保留装 `01a6ec56…`，06:19 同安装回执匹配，正常首页、Wi-Fi、SMB 实图已核。临时索引撤回，原 3 库、4 连接 JSON 等值，06:29:10 确认收窗。 | 更新 18 时 iPad 已在设备列表不可用。先 fresh 核 USB，必要时先做本机诊断。原生恢复和同条件触控分开取证；避开对 `network.library.source` 的合成点击。 |
| iPhone 18 Pro Max（iPhone19,7 / iOS 27.0） | 06:42:57 CST 通过 USB 对 `01a6ec56…` 保留数据覆盖成功，有安装服务回执和新的安装查询。全部 28 项偏好从安装前到离线启动后等值。离线“添加媒体文件夹”有前台实图，06:43:25 自有 App / Runner 为零。 | 本轮没有启动普通账户根、没有 NAS 登录或媒体请求，没有部署 Runner；保持 hands off。原 DSM 固定域名＋端口偏好保留，实际 DSM 会话地址和媒体请求路线本次未查。 |
| 客厅 Apple TV | tvOS 27.2，历史已认证配对，开发隧道仍不可用。 | 按用户要求暂停，保留配对和网络。无当轮安装或设备窗口。 |

13 与 iPad 的最近触控 Runner 签名分别到 11 月 11 日 08:42:31 与 08:39:52 CST，仅历史记录，使用前仍须现场核。18 本轮未启动测试工具。所有本轮占用已释放，未给任何设备持续远控。Claude 开新窗前登记每台独占和开始/结束边界，重构建和模拟器同样先核独占。仅当前顺序接续；共享摘要由 Codex 维护，Claude 将自己批次结果写入月度接续。实际额度不在项目记录中推断。

## 已确认的实现与未解决项

- 用户原则：按**实际网络环境**统一播放链路。Jellyfin、设备文件、SMB、FTP、WebDAV 的入口只负责如何取字节；同一网络下优先复用规划、引擎、原画代理与降档决策。FTP / SMB 限内网。USB 调试连接、App 网络类型、实际媒体地址和实际 DSM 登录地址分别记录。NAS 业务已恢复，任何真实媒体和索引只读；不改 NAS/VPN、源目录、账号保存配置或用户网络。
- 第一阶段共享原画代理已经接入；第二阶段也已实现直接 Reader 路由，勿从 11 月 8 日方案从头做。阅读 [Reader 接入](CODEX-2026-11-09-NETWORK-READER-PROXY.md) 和 [13 SMB / WebDAV](CODEX-2026-11-09-IPHONE13-READER-SMB-WEBDAV.md)。核心为 `AuthenticatedMediaStreamProxy.registerOriginalStream/registerNetworkReader` 和 `NetworkMediaProxyTransfer`（`Features/Devices/DevicesView.swift`），网络库接入在 `Packages/NetworkMedia`，Reader 协议现位于 `WebDAVMediaResource.swift`。保留 Range/HEAD/206/416、长度校验、版本身份、取消与路由所有权。Reader 的本地交付数据不冒充可用于自适应决策的上游测量。
- 启动预读的 0 字节已定位：`PlaybackSessionCoordinator.preloadStartupWindow` 调用默认观察型 IO，未物化、也没有可供播放器消费的真实启动字节，所以是当前实现的能力缺口。另有优先首帧主动取消的独立分支。Range 支持和首段元数据不能记成缓存。已有 [原画前缀证明](CODEX-2026-11-09-ORIGINAL-PREFIX-PROOF.md) 与 [iPad 前缀对照](CODEX-2026-11-09-IPAD-ASYNC-PREFIX-AB.md)；未证明可作为生产提速。完成 SMB 供给定位后，再比较共享、限量、可取消且可复用的异步预读，要求证明实际少读或更快出画。默认关闭的 HLS 候选首段复用在 [合成与真机对照](CODEX-2026-11-09-S19-CANDIDATE-SEGMENT-DEVICE.md) 有复用证据，真机没有证明提速，继续保持默认关闭。
- S19 为《指环王：护戒使者》128,795,641,934 字节 4K UHD Remux，下载目录与媒体库是同一份数据的硬链接。样本含 Dolby Vision P7/HDR10 底层、TrueHD 7.1；完整源路径留本机私有交接。当前对照选 AC3 2 / PGS 9，不代表 TrueHD、HDR 或杜比视界真实输出。DTS、DV P5/P8、音乐样本缺口及 Safari 转码约 60% CPU 且黑屏的历史观察见 [总交接新样本](2026-11-08-0130-CLAUDE-TRANSITION-TO-CODEX.md#新样本11-08-1720用户经-radarr-下载)。Safari 根因与原画 NAS 同窗负载对照未完成。

## 下一批怎么做

1. 先复核 [本轮 SMB 缓冲证据](CODEX-2026-11-10-S19-SAME-BUILD-TRIAD.md) 和 [结构化结果](../../../testing/results/2026-11/CODEX-S19-SAME-BUILD-TRIAD-20261110.json)。同包 iPad 在 346.993 秒起播后，时钟停在 348.392 秒约 9.57 秒；其间 8 个完整一秒桶仍收到约 28 MB SMB 入站载荷。尾段完整交付早于停顿；这批既没有取得等条件三路结果，也不能由网卡计数推断有效字节已进入解码器。首窗 Jellyfin 到播放器但未核普通退出，设备文件在长目录滚动超时，SMB 未核音轨 2；补窗未发媒体请求。旧包出画证据与本轮不合并排名。
2. 建议第一批只做诊断，不先改变缓冲阈值或协议并发。在 `NetworkMediaProxyTransfer` 按匿名 trace / transfer / 区间偏移，用单调时钟低频汇总两段耗时：上一块送完到下一块到达 Reader 回调，以及本地 socket send 完成等待。联结播放器缓冲、时钟和实际取图，记录实际交付字节/区间、终态、取消，不写 URL、账号、路径或逐包正文。若 Reader 等待是主要时间，再在 `SMBMediaResource.stream` 和串行 `SMBWorker` 分开排队与网络读取；先用正常供给和人工慢 Reader / 慢消费者两种合成夹具验证归因。区分有限 Range 正常结束、播放器改请求主动断开和真正的读错误。建议首批产品文件从 `DevicesView.swift` 开始，测试定位后再登记；播放器字段够用时不改引擎。
3. 有设备窗后先独占 iPad，同包同片内网 Wi-Fi，从 346.993 秒及 AC3 2 / PGS 9 逐路复测，再用 13 验证代表性入口。用当前画面找唯一退出控件，设备文件优先目录内精确搜索，保留导航失败。每入口独立取证起播、重开、正常退出、前后各一次跳转、实际画面与字幕。固定时间点可先用于诊断；正式续播/从头走空环境，实际缓存命中未知则注明。记录网络、有效字节、内部时钟和实际画面；听音和实际 HDR 另取证。两轮无改善即停止同参数反复试验，保留失败。
4. 同 LAN 样本可复现后扩 WebDAV、FTP，再测外部 Wi-Fi 和弱蜂窝；用相同开始/结束定义覆盖断点续播、从头首帧、跳转、音字幕切换、长时和服务器负载。13 的用户报告弱蜂窝单列，结束在最外层清理恢复原 Wi-Fi 并核图标，VPN 不改。验收依据 [唯一需求总账](../../../project/PLAYBACK_EXPERIENCE_PRIORITIES.md) 与 [播放矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md)；本批没有关闭需求或矩阵格。

## 本机证据索引

`/tmp/nastart-s19-same-build-triad-current` 指向 iPad 私有记录，`pad/first-triad-timeline-safe.json` 含相对时钟与流量桶；`/tmp/nastart-iphone18-claude-transition-current` 指向 18 本轮安装回执和离线前台截图；`/tmp/nastart-jellyfin13-authorized-reauth-current` 指向 13 最近重登窗。指针失效时按本机 `~/Library/Application Support/Nastart/DebugEvidence` 下相应批次名找，私有报告、偏好、凭据与原图不进入仓库或对话。可以直接发送给 Claude：「先读这份接续，从同一 Range 的 Reader 等待、代理送出和播放缓冲对齐开始。」
