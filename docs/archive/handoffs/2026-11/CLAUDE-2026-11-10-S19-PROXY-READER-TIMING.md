# 2026-11-10 Claude：S19 Reader 供给计时与 iPad / iPhone 13 同包对照

接续 [Codex → Claude 接续](2026-11-10-0645-CODEX-TRANSITION-TO-CLAUDE.md)。基线 `main/8db1cc64` 加既有未提交改动（开工状态快照在本机私有证据 `claude-s19-proxy-timing-20261110/git-status-start.txt`）。本批未提交、未暂存、未推送。缓冲阈值、Reader 并发、播放与降档策略均未改。

## 改动

| 文件 | 内容 |
| --- | --- |
| `ios/Nastart/Nastart/Features/Devices/DevicesView.swift` | 新增 `NetworkMediaProxyTransferTimeline`。`NetworkMediaProxyTransfer.run()` 把每块的等待拆成两段：等 Reader 返回下一块（`readerWait`）和等本地播放器套接字接收（`consumerWait`）。每满 1 秒用单调时钟写一条 `proxy_transfer_progress / readerTimingWindow`，字段含窗口起止 uptime、块数、字节、交付偏移、两段等待合计/最大值和 `dominantWait`。传输结束时写一条收尾窗口；`readerTransferFinished` 增加 `total*` 汇总、`terminalKind`（`rangeComplete / playerClosedRequest / idleTimeout / readerFailure / playerSocketError / cancelled`）、`finishedUptimeMs`，Reader 错误另记脱敏的 `errorKind`。旧的 `readerOrClientError` 拆分为 `readerError / invalidReaderChunk / shortReaderWindow / clientSendError / cancelled`。不记录 URL、账号、路径或正文。 |
| `ios/Nastart/Nastart/Playback/Diagnostics/PlaybackDiagnostics.swift` | `telemetry_sample` 增加 `uptimeMs`，与代理窗口使用同一单调时钟。 |
| `ios/Nastart/Nastart/{en,zh-Hans}.lproj/Localizable.strings` | 新增 `diagnostics.media.proxy_transfer_progress`。 |
| `ios/Nastart/NastartTests/PlaybackNextCoreTests.swift` | 新增 2 个测试：纯计时归因（reader / consumer / mixed / 结束时挂起的等待）；真实代理在正常供给、慢 Reader（每 128 KiB 等 150 ms）和慢消费者（64 KiB 接收缓冲、1.5 s 不读）三种条件下能分清等待位置，并覆盖播放器在等 Reader 时断开、真实 Reader 错误。新增 `ProxyPacedReader`；`PlaybackRawHTTPClient` 加可选接收缓冲和 `drainBody()`。 |
| `scripts/playback_reader_timing_report.py` 及其测试 | 按同一 trace，把代理窗口与播放器时钟、缓冲、`bytesRead` 按 uptime 对齐，按重叠比例分摊到每个遥测区间；每段停顿归因为 `readerBound / playerNotReading / deliveredWithoutClock / noReaderTransfer`。 |

## 验证

- 空白模拟器 `Claude-ProxyTiming-20261110`（iPhone 17 Pro / iOS 27.0，无凭据和服务地址，已删除）上运行 app-hosted 测试：新增 2 个与既有 4 个 Reader 代理测试共 6/6 通过（首轮纯计时测试的期望块数写错，修正后通过）。`python3 -m unittest test_playback_reader_timing_report` 4/4 通过。
- 签名 Debug：主程序 `acd3f3b25cf5025e2a3f7defe87f63a0e6486a7ddb63e46d74059f4a25fec659`，dylib `851e161921a4de2f1fb7956fa90288e4fc7b263c68d694dfa7b920387e668b5d`，07:30:15 CST 构建，描述文件到 11-15 08:30 CST，含 iPad 与 iPhone 13。冻结在私有证据 `product/Nastart.app`。
- iPad（iPad15,7 / 26.6，USB）07:31:00 保留数据覆盖安装；iPhone 13（iPhone14,5 / 16.3.1，USB）08:05:34 保留数据覆盖安装。两台安装前后全部偏好相等。iPad 安装前有 Nastart 进程，核实路径后停止。每个窗口结束时 App/Runner 剩余 0，转发结束。

## 真机结果（同包、普通启动、内网 Wi-Fi，S19，AC3 2 / PGS 9）

App 内部计时，`tapToFirstFrameMs` 从点击到播放时钟开始推进。实际画面另有截图，没有逐帧计时。服务端和系统缓存命中情况未知，入口按 Jellyfin → SMB → 设备文件串行执行，因此不做速度排名。跳转响应用 `seekRecoveryMs`：从提交跳转到引擎完成且时钟恢复推进。切换音轨和 PGS 字幕在 KSPlayer 中通过原位跳转实现，所以也用 `seekRecoveryMs` 计时。

| 指标（ms） | iPad Jellyfin | iPad SMB | iPad 设备文件 | 13 Jellyfin |
| --- | --- | --- | --- | --- |
| 首次起播（0 s） | 640 | 未取得 | 844 | 938 |
| 断点续播 | 2495（411 s） | 5429（349 s） | 3617（378 s） | 3563（533 s） |
| 从头播放 | 551 | 2317 | 1435 | 696 |
| 切 DTS / 再切 AC3 | 1400 / 721 | 2015 / 623 | 4369 / 1836 | 3570 / 975 |
| 开 PGS 9 | 1137 | 2061 | 已选中，无切换 | 1242 |
| 拖动约 +294 s | 5160 | 1106 | 1860 | 3648 |
| +15 s / −15 s | 1910 / 3092 | 2803 / 2517 | 3091 / 2738 | 4157 / 3229 |

- 四个窗口都完成了重开、断点退出、续播、从头和普通退出。续播与从头后，音轨 2 和字幕 9 在菜单中均为已选中。字幕是否真正显示在画面上，只有截图证据。
- SMB 的字幕菜单没有"关闭字幕"项，Jellyfin 有，这是入口之间的不一致。SMB 第一次尝试因此停在这一步，第二次去掉该步骤后完成。
- **iPad 和 13 的 Jellyfin 续播后都触发了自动降档**，切到服务端 HLS 12 Mbps（`localHLS / systemAVPlayer`）。iPad 原因是 `deliveryBelowSourceBitrate`，交付能力 25.9 Mbps，需求 80.9 Mbps；13 原因是 `depletingOriginalReserve`，交付能力 52.5 Mbps。

## SMB 缓冲归因（新诊断首次真机证据）

- 稳态时，代理每秒约 1000 ms 都在等 Reader，等播放器套接字的时间只有个位数毫秒。交付稳定在约 10–11.5 MB/s（≈85–95 Mbps）。S19 当前码率 65–84 Mbps，余量很小；码率升高时出现约 1 秒停顿，报告归因 `readerBound`。播放器缓冲到约 15 秒后停止读取，这时转为等播放器，属于正常背压，不是停顿。
- 续播 5.4 s 的拆解：播放器先串行发起 4 个结构读取（头 1 MB、尾 16 KB、头部 3 MB、尾部 Cues 4.8 MB）。每个 SMB 请求的首块延迟约 90–300 ms，16 KB 的尾部也要 141 ms。约 1.7 s 后才开始读续播位置，随后约 3 s 以 Reader 限速填缓冲。播放器侧 `openMs` 514、`initialSeekMs` 1031、`acceptedVideoFrameMs` 2172。
- 结论：SMB 的慢在 Reader 供给侧，代理和解码器都不是主因。同一 iPad 上 SMB 能拿到约 90 Mbps，所以 Wi-Fi 链路不是 Jellyfin 所测 25.9 Mbps 的瓶颈。Jellyfin 的交付测量口径需要单独核对。

## iPhone 13 蜂窝窗（用户报告的弱蜂窝）

用户 08:40 前后手动关闭 13 的 Wi-Fi；系统设置不由 Claude 自动改动。08:43 截图显示状态栏 4G、信号 3 格、没有 Wi-Fi 图标。App 记录 `network=cellular, expensive=true`。RSRP/RSRQ 等无线指标未测。DSM 通过外网域名 `:5001` 登录成功。开窗前发现一个 08:27 由用户手动启动的 Nastart 进程，先保存偏好，核对路径与本批安装一致后再停止。

- **Jellyfin 被登录阻塞**：库入口进入"连接 Jellyfin"登录页。诊断显示只有 3 个外网域名候选（`:8097`，root / jellyfin / emby），每个都是 `hasStoredSession=false`、没有令牌。Wi-Fi 下已保存的会话只绑定在内网 `:8096` 地址上，换到同一服务器的外网地址无法沿用。这是产品缺陷：同一 Jellyfin 服务器的内外网地址之间，登录身份不能复用。没有输入凭据，Jellyfin 的蜂窝播放未测。
- **设备文件（DSM，`publicDomain` https，`localRangeProxy / ksPlayer` 原画）完整周期通过**：

| 指标（ms） | 13 设备文件·蜂窝 |
| --- | --- |
| 首次起播 | 2301（首帧位置 2.099 s） |
| 断点续播 | 6339（481 s） |
| 从头播放 | 2250 |
| 切 AC3 / 开 PGS 9 | 3811（含跳转恢复）/ 菜单已选中 |
| 拖动约 +500 s | 3810 |
| +15 s / −15 s | 2774 / 2884 |

- 播放器实际读取速率中位数约 52–54 Mbps，最高约 82 Mbps；源码率 71–88 Mbps。首播阶段 58 个遥测样本里有 42 个处于停顿，续播阶段 21 个里有 16 个，从头阶段 16 个里有 8 个。自动降档在续播和从头阶段各请求过一次（交付能力 49.9–53.9 Mbps，需求 71–88 Mbps），但设备文件路线没有可降的版本，所以一直以原画缓冲播放。本窗没有出现播放器读取为 0 字节的整秒。用户在 iPhone 18 上看到的"0K"未在本窗复现，信号条件不同。
- 蜂窝窗 08:48:34 收窗，App 和 Runner 剩余 0。

### 蜂窝 Jellyfin（用户 08:5x 在 App 内自行登录后）

开测前先保存偏好，并核对用户登录用的 Nastart 进程路径一致，然后停止它；登录状态保留。Runner 窗 08:58–09:13，结束时 App 和 Runner 剩余 0。

- **蜂窝下首播和"继续"都没有走原画**，直接规划服务端 HLS（`publicDomain / localHLS / systemAVPlayer / localRemux`）。首帧分别为 5308、4638、4113 ms（三次尝试）。"从头播放"却选了原画 `localRangeProxy / ksPlayer / directPlay`，首帧 2619 ms。同一网络条件下路线不一致，需要核对规划策略。
- **切音轨要重建整条 HLS 会话**：提交后约 7 s 才选出新路线，切到 AC3 后又过了 8139 ms 才重新出画（第 2 次尝试）。
- 在 HLS 路线上跳转：拖动约 +510 s 为 4856 ms，+15 s / −15 s 为 736 / 733 ms。
- HLS 播放器的字幕菜单没有"关闭字幕"项。续播后，字幕 9 **没有**保持选中（`resumeSubtitleSelected=false`）；从头后字幕状态未核。
- **真正的蜂窝断点续播没有测成**：服务端返回的续播位置为 0（`entryPositionTicks=0`）。之前几次退出时 WDA 读取界面超时，App 被强制重启，所以上报的位置可能没有保存。不能据此断定是产品缺陷。
- 诊断记录只保留最近 1000 条，蜂窝 HLS 的遥测量大，前几轮的事件被挤掉了。补跑的短流程在每一步之后立即导出诊断。建议加大保留上限，或者降低 HLS 遥测的频率。
- Wi-Fi 恢复：用户手动打开 Wi-Fi，Codex 已开设置窗核对。10:29 Claude 又用只读 DVT 截图复核：设置页显示 CU_2Cmr 已勾选，状态栏有 Wi-Fi 图标。Claude 没有改动任何系统设置。没有启动 Runner：预检发现一个用户打开的 Nastart 进程，保持原样未动。13 的租约已于 10:30 释放。

## 未完成与下一步

1. Jellyfin 内外网共用登录：代码与单元测试已完成（见下节），待真机验证。
2. 蜂窝 Jellyfin 路线不一致：已改为用实际播放速度做依据（见下节），待真机复测。切音轨与续播丢字幕的分析和修复见下文"蜂窝转码下切音轨与续播丢字幕"一节。
3. 在不强制结束 App 的条件下，重测蜂窝断点续播（服务端续播位置这次为 0）。
4. 诊断保留上限（1000 条）或 HLS 遥测频率。
5. SMB：在 `SMBMediaResource.stream` 和串行 `SMBWorker` 中把排队时间和网络读取时间分开测。再评估结构读取（头/尾/Cues）能否复用或并行，以及单请求延迟。本批未改。
6. Jellyfin：核对 `bodyWindow` 交付能力的口径（是否把播放器背压算进了容量），以及续播后降档的必要性。代理 HTTP 路径尚无 Reader 那样的两段计时。
7. 共享文档同步（由 Codex 写）：`VIDEO_PLAYBACK_PIPELINE.md` 诊断字段、PLAYBACK_OFFLINE_DIAGNOSTICS、矩阵中 S19 iPad 三入口、13 Wi-Fi 与 13 蜂窝的单窗证据。本批没有关闭需求项。


## 后续：Jellyfin 内外网共用登录（2026-11-10 用户选定方案）

用户选择"核对服务器 ID 后共用"。改动（未提交）：

- `StoredJellyfinSession` 新增可选 `serverID`；旧钥匙串数据仍可解码。
- 登录成功或恢复登录后，用该登录自己地址上的 `/Users/Me` 补记服务器 ID。令牌未变才写回。旧登录需要在内网打开一次 App 才会补记。
- 恢复时如果没有任何候选地址有自己的登录（例如蜂窝下只有外网 HTTPS 候选），按以下顺序处理：
  1. 对每个已配置的 HTTPS 外网候选，先读公开的 `/System/Info/Public` 服务器 ID。
  2. 找到记录了相同服务器 ID 的已存登录，用它的令牌请求该候选的 `/Users/Me`，用户和服务器都一致才接受。
  3. 为该候选另存一份自己的登录，然后按正常流程恢复。
  - 明文 HTTP、内网地址、未记录服务器 ID 的登录，一律不借用。
- 诊断：`playback_route_state` 新增 `stage=crossEndpointRestore`，`result` 取值为 accepted / differentServer / publicInfoUnavailable / httpRejected / identityMismatch / noSavedServerID / serverIDRecorded 等，不记录账号或令牌。
- 验证：新增 `testJellyfinPublicCandidateBorrowsOnlySameServerLoginWithRecordedServerID`，连同 2 个已有的拒绝恢复测试，3 个均通过（专用模拟器已删除）。
- 未做：真机验证。13 已有用户在蜂窝下手动登录留下的外网登录，所以无法直接验证"借用"这条路径。验证需要一台只有内网登录的设备，并且要先在 Wi-Fi 下打开一次 App 补记服务器 ID，再切到蜂窝。
- 行为变化：借用成功后外网地址也有了自己的登录；回到 Wi-Fi 时，恢复会按保存时间选较新的那份，资料库请求可能走外网域名，播放仍由已验证的内网路线决定。


## 后续：蜂窝 Jellyfin 选路改用实际播放速度（2026-11-10 用户选定方案）

**根因（基于 13 蜂窝证据）**：选路取决于点播放时 120 秒内有没有新鲜的 1 MB 测速。
- 首播 AA17B911：距上次测速 62 秒，测得 7.8 Mbps，判定原画（75 Mbps）跑不动，走转码 HLS，上限 2 Mbps（实际视频 1.6 Mbps）。
- 从头 A465F1EE：距上次测速 127 秒，已过期，直接试原画。首帧 2.0 秒，在 5.5 秒处卡顿约 7 秒，之后缓冲涨到 16 秒。
- 再次从 0 开始的 7DCDBACC 又遇到新鲜测速，走了 HLS。可见分叉与"从头还是续播"无关。
- 4 次 1 MB 测速在 8–34 Mbps 之间；同一路线原画播放实际稳定交付约 48–49 Mbps（播放器测得 48 Mbps）。小样本测速受新连接 TCP 慢启动影响，明显偏低。

**改动**（未提交）：
- `PlaybackRecentThroughputStore` 新增按路线（服务器地址 + 网络类型）保存的播放交付证据。
  - 只收已绑定路线的播放：合格的数据窗口样本，以及至少 1 MB、无回压的完整传输。
  - 保留 10 分钟、最多 16 个样本，取中位数。
  - 设备文件等未绑定路线的播放不计入。
- Jellyfin 点播放时把本次播放绑定到这条路线，有播放证据就优先用它，否则仍用 1 MB 测速。自动降档也同样优先用播放证据。
- 新增诊断 `playback_preparing stage=routeCapacityEvidence`，记录 capacitySource（playbackDelivery / preplayProbe / none）以及两种容量值。
- 阈值和档位规则未改，仍是：原画码率超过容量 1.5 倍判为跑不动；转码目标取容量的一半，再向下取档位。

**按 13 蜂窝数据推算的效果**（推算，未在真机复测）：
- 证据约 48 Mbps 时，S19（75 Mbps）仍走转码，但档位从 2 Mbps 升到 12 Mbps。
- 码率在约 72 Mbps 以下的片子走原画。
- 10 分钟内的首播、续播、从头选择一致。超过 10 分钟没有播放、也没有新鲜测速时，仍会先试原画。

**验证**：新增 `testRouteCapacityKeepsPlaybackDeliveryPerRouteAndDrivesTheSameChoice`，连同 11 个已有的吞吐、容量、降档和代理计时测试，12 个均通过。没有打包，没有做蜂窝真机复测。

**风险**：
- 网络在 10 分钟内变差时，旧证据可能偏高，导致先试原画，之后依赖运行中自动降档。
- 第一次播放仍取决于 1 MB 测速，结果偏低时第一次仍是低档转码，要等播放产生证据后才会纠正。


## 后续：蜂窝转码下切音轨与续播丢字幕

**切音轨耗时拆解**（2B06C902，AC3→DTS，蜂窝 HLS 2 Mbps）：
- 服务端重新协商 347 ms。
- 主、子播放列表约 1.0 s。
- 候选播放器按"当前位置 + 11 s 预备提前量"定位到 580 s，请求第 144 段，**首字节等了 4166 ms**（Jellyfin 在新位置重启转码），传输 788 ms。
- 第 6.0 s 解码出首帧，之后等当前播放走到 580 s 再无缝切换。
- 主要耗时在服务端转码重启和对齐等待，客户端本批未改；码率提高到 12 Mbps 后需要复测。

**续播丢 PGS 的根因**：蜂窝 HLS 下切到 PGS 9（3FF43771，服务端烧录）后，候选还在准备（约 3 s），测试脚本就发起了跳转（528.75 s）。跳转把这次切换作废（`replacement_warmup_failed stage=candidateInvalidated`），之后没有重试，所以字幕从未生效，续播自然没有字幕。这一步是测试操作过快触发的，但产品行为有缺陷：用户选完字幕马上拖进度，选择会被悄悄丢掉。

**改动**（未提交）：用户手动切换音轨或字幕时，如果只是因为跳转没能生效，替换结束后会按同样的选择从新位置自动重新准备一次。新增诊断事件 `source_track_retry_after_seek`。
- 不重试的情况：自动降档、画中画接管、真实失败（没有发生跳转）、用户又发起了新的切换。
- 判断逻辑在 `PlaybackSourceChangeRequestTracker.shouldRetryAfterSeek`，新增测试 `testTrackSwitchInvalidatedOnlyBySeekIsRetriedButAutomaticOrPiPChangesAreNot`。
- 该测试与 3 个本批新增测试及 5 个已有替换相关测试，共 9 个均通过。


## 蜂窝真机复测（2026-11-10 12:13–12:26，13，新包 main c205460c0a5f）

本次安装保留了 App 数据，安装前后偏好一致。Wi-Fi 下打开 Jellyfin 后，`serverIDRecorded` 写到了恢复出的外网登录上：该登录是用户此前在蜂窝下手动登录生成的，比内网登录更新，所以被优先恢复。因此"蜂窝下沿用内网登录"这条路径在 13 上无法触发，**未验证**。之后用户手动关闭 Wi-Fi。每次开窗前，如有用户自己打开的 Nastart 进程，都先保存偏好，再停止进程，停止前后偏好一致。

| 播放 | 选路依据 | 容量 | 路线 / 上限 | 首帧 |
|---|---|---|---|---|
| 首播（P1，独立进程） | 1 MB 测速 | 22.3 Mbps | HLS 10 Mbps（视频 9.36） | 5761 ms |
| 续播（P2） | 1 MB 测速 | 31.4 Mbps | HLS 10 Mbps | 4883 ms |
| 续播（Q1，新进程） | 1 MB 测速 | 6.8 Mbps | HLS 2 Mbps | 8441 ms |
| 从头（Q2，同进程） | 播放交付 | 5.2 Mbps | HLS 2 Mbps | 4123 ms |
| 续播（Q3，同进程） | 播放交付 | 12.2 Mbps | HLS 4 Mbps | 4405 ms |

- **选路一致**：同一进程内续播、从头、续播都走 HLS，没有再出现"过期后直接试原画"的分叉。
- **新风险**：HLS 播放产生的"播放交付"证据，来自低档转码片段的传输速度，会受服务端转码速度和片段大小限制（Q2 只有 5.2 Mbps），可能让低档一直维持低档。当时 1 MB 测速也只有 6.8 Mbps，蜂窝本身偏弱，两种因素无法区分。建议下一步只把原画数据窗口和较大的完整传输计入路线证据，或者让 HLS 证据只能升档、不能压低。
- **局限**：路线证据只保存在内存里，App 进程重启后就没有了，第一次播放仍依赖 1 MB 测速。
- **切字幕后马上跳转**：PGS 9 切换准备了 4073 ms 时被跳转作废，随即触发 `source_track_retry_after_seek`。新候选 8DC7691B 在 12.6 s 后提交，从点选到切换共约 17 s。之后菜单显示 PGS"已选择"；下一次续播（Q1）请求里带着 subtitleStreamIndex=9，菜单仍是"已选择"。**修复有效。**
- **切 AC3（DTS→AC3）**：服务端第一段数据等待 5237 ms，8596 ms 解码出画面，随后进入对齐阶段；快照截止时还没提交，之后 App 被测试窗口停止，切换没有生效。所以音轨保存的仍是 DTS 3，这是 Claude 测试留下的状态，待 Wi-Fi 下切回 AC3 2。
- 本轮没有复现"0K"。


**收尾（12:32–12:36）**：用户恢复 Wi-Fi 后，Claude 用只读 DVT 截图核对：CU_2Cmr 已勾选，状态栏有 Wi-Fi 图标，13 的租约已释放。

计划在 Wi-Fi 下把音轨切回 AC3 2，但 Jellyfin 资料库报 HTTP 502、搜索不可用，没能完成。从 Mac 只读探测：NAS 内网 :8096 连接被拒，DSM :5000 正常，说明 Jellyfin 服务当时没有在监听。11:51 时它还正常；12:13–12:26 的蜂窝测试发起过多次 4K→H.264 服务端转码，原因未确认。NAS 由用户管理，Claude 没有重启任何服务。

待办：Jellyfin 恢复后，把 S19 保存的音轨切回 AC3 2（字幕 PGS 9 已是选中状态）。


**Jellyfin 停止的原因（用户 12:39 确认）**：DSM 存储管理器显示存储池 5 状态为"丢失"。该池为 Basic（无数据保护），只有一块 SSD（硬盘 9，465.8 GiB），存放 Docker，所以 Jellyfin 容器不可用。原因是硬盘问题，并非播放测试造成的服务端故障。用户回家修复硬盘后再继续调试，本批暂停。

**恢复后续接**：
1. 确认 Jellyfin 内网 :8096 和外网 :8097 都可访问。
2. 把 S19 保存的音轨切回 AC3 2。
3. 按"未完成与下一步"推进：限制 HLS 证据只能升档、不能压低；路线证据是否持久化；在只有内网登录的设备上验证跨地址登录。

私有证据：`~/Library/Application Support/Nastart/DebugEvidence/claude-s19-proxy-timing-20261110/`（`pad-*-run/`、`phone-wifi-run/` 各含场景标记和偏好快照，`extract.py` 用于复算）。

**17:39 恢复核对**：用户整机断电后硬盘 9 恢复（Samsung 870 EVO 500GB，接在 Marvell 88SE9235 扩展卡上，ata9 链路 6.0 Gbps）。从 Mac 只读探测：内网 :8096 与外网 :8097 均返回 200，版本 12.4.0，服务器 ID 一致。iPhone 13 恢复 AC3 未完成：外网会话加载资料库时被拒（HTTP 401，`storedLibraryRecovery=httpRejected`），之后路线改回内网，但搜索仍失败（"暂时无法搜索"）。怀疑掉盘后 Jellyfin 数据回退或会话失效，需要用户在 App 内重新登录。产品问题：已保存会话收到 401 后，页面只显示搜索失败，没有引导用户重新登录。

**17:5x 已恢复**：用户在 iPhone 13 上重新登录 Jellyfin 后，Claude 进入 S19 续播，切回音轨 2（AC3 5.1），字幕 PGS 9 保持选中，验证通过后退出播放器。Runner 已收窗（remaining 0），iPhone 13 租用已释放。

## HLS 路线证据只升不降（2026-11-10 晚）

问题：之前服务端 HLS 分段的交付速度也作为路线证据。但这个速度受当前码率档位和服务端转码速度限制，读出来偏低（蜂窝下 5.2–12.2 Mbps）。下一次播放据此会继续选 HLS，而且档位更低，形成"越测越低"的锁定。

改动：
- `PlaybackRecentThroughputStore.record(..., isServerRendition:)`：来自 HLS 分段的样本单独存为下界证据，用 `routeLowerBound` 读取。原片字节范围传输和 body window 的样本仍是直接证据，用 `routeCapacity` 读取。
- `PlaybackRouteCapacityPolicy.effective(direct:lowerBound:probe:)`：有直接证据时，取 max(直接证据, 下界)；只有探测值时，取 max(探测值, 下界)；只有下界时，视为容量未知，交给原片探测去决定，不能单凭下界判定原片不可持续。
- 起播（`routeCapacityEvidence` 诊断新增 `capacity`、`renditionLowerBound`）和播放中回退两个入口统一走这套规则。
- 代价：只用过 HLS、探测又已超过 120 s 时，续播会重新尝试原片探测。所以同一路线下"续播 / 从头"的选择可能不一致，但不会再被低码率锁死。
- 单测：`testServerRenditionDeliveryOnlyRaisesRouteCapacity`。真机未验证，需要蜂窝或弱网环境。

## 登录失效后回到登录页（2026-11-10 晚）

问题：用户修好硬盘后，iPhone 13 保存的 Jellyfin 登录被服务器拒绝（401）。资源库只显示载入失败，搜索显示"暂时无法搜索"，没有引导用户重新登录。

改动：
- `JellyfinSessionRejectionPolicy.requiresSignIn(after:)`：只有 HTTP 401 才判定为登录失效；403、5xx、超时、取消都不算。
- `JellyfinLibraryStore.expireRejectedSession(stage:)`：资源库首页载入时如果收到 401，且同一服务器的内网会话恢复没有成功；或者搜索时收到 401，就回到登录页。登录页的错误提示为"登录已失效，请重新输入密码。"，用户名自动保留。Keychain 中被拒的令牌不删除，用户重新登录成功后会覆盖它。`userID` 保留，所以之后内网身份验证完成时，仍可以自动恢复同一账号的会话。新增诊断记录 `diagnostics.jellyfin.session_rejected`。
- 单测 `testOnlyAServer401SendsTheJellyfinLibraryBackToSignIn` 通过。`NonPlaybackPolicyTests` 共 193 项通过、1 项失败。失败的 `testMediaRangePolicyDoesNotTurnMalformedRangesIntoAnOpenResponse` 是 HEAD `d3dbc9c4` 中已有的旧断言：它期望 `boundedRange("invalid")` 兜底返回首段范围，而现实现按 Range 语义前置约束返回 nil。与本批改动无关，留待 Codex 或用户决定是改测试还是改实现。
- 真机未验证：需要一个会话被服务端拒绝的场景，不会主动去制造。

### 蜂窝真机验证（20:2x，iPhone 13，新包 dylib `9e7b0944…`，同一进程连续续播 3 次）

| 次序 | 路线证据（`routeCapacityEvidence`） | 选择 | 首帧 |
|---|---|---|---|
| q1 续播 | 被 1000 条诊断上限挤掉 | — | 有（BE49BB39） |
| q2 续播（等 130 s，探测已过期） | 只有 HLS 下界 22.8 Mbps → `capacitySource=none` | 先尝试原片 DirectPlay；出首帧 16.9 s 后因 `bitrateFallback` 切到 HLS 4 Mbps，又过 7.7 s 出首帧 | 16.9 s / 7.7 s |
| q3 续播（紧接着） | 直接证据 15.0 Mbps（来自 q2 的原片尝试）、下界 20.1 Mbps → 20.1 Mbps | HLS 10 Mbps（`measuredBandwidthInsufficient`） | 11.0 s |

结论：
- 下界规则生效。HLS 证据单独存在时，不会让系统断定原片播不动；它和直接证据同时存在时，会把容量估计往上抬。q3 选的是 10 Mbps 档，此前蜂窝测试同类情况只选到 2–4 Mbps。
- 代价也确认了。只剩 HLS 下界时，会尝试一次原片（q2 首帧 16.9 s，之后立即回退）。原片尝试留下的直接证据会保留 600 s，之后同路线不会再重复尝试。
- 未尽事项：
  - 原片尝试阶段的首帧太慢（16.9 s）。可考虑在只有下界、且源码率远高于下界（例如超过 3 倍）时，跳过原片、直接选 HLS，但这需要用户决定取舍。
  - 诊断上限 1000 条，q1 的数据被挤掉，仍待处理。
  - 全程音轨保持 AC3 2，字幕保持 PGS 9，没有点"从头播放"。
