# 2026-11-11 播放策略核心设计 → 真机调试与优化（给接手模型）

这份文档把"播放路线决策"这一轮的核心设计交给接手的模型，在现有真机环境里验证、调试和优化。设计会话只做了设计、策略代码和模拟器单测，没有碰真机。任务顺序、判定标准和调参规则以本文为准；设计细节在三份批次文档里，本文只列接手用得到的部分。

基线：`main/8db1cc64` 加工作区里全部未提交改动（含本文共 122 个状态路径）。没有提交、暂存或推送。

## 一页结论

- 已完成并通过模拟器单测的三块：
  1. 路线决策模型：原片还是服务端 HLS、HLS 选哪一档。已接入 Jellyfin 入口的起播和播放中降档，以及设备文件入口的蜂窝起播。
  2. SMB 读取分段计时：只加诊断，读取行为没有改。
  3. 换源协调状态机：纯逻辑加单测，**没有接进播放器**。
- **这些代码从未装到任何真机。** 真机上现有的包都早于这批改动。第一步是从当前工作区构建并装包。
- 真机上要回答四个问题：模型的判定是否和日志里的数字对得上；判定对得上时体验是否可接受；SMB 的时间花在哪；状态机接线后 6 处问题是否消失。
- 可以自己做的：验证、按第六节的规则调参、按批次文档的步骤接线。
- 不可以自己定的：第九节列出的决定，以及模型结构的改动。遇到第八节的情况停下来交回。

## 一、开工顺序

1. 读根目录 [CLAUDE](../../../../CLAUDE.md)、[AGENTS](../../../../AGENTS.md)、[PROGRESS](../../../../PROGRESS.md)。
2. 读 [当前交接](../../../handoffs/CURRENT-PLAYBACK-HANDOFF.md)、[播放调试规范](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)、[真机远控手册](../../../development/PHYSICAL-DEVICE-REMOTE-CONTROL.md)、[资源登记](../../../development/AGENT-RESOURCE-STATE.json)、[协作分工](../../../development/CODEX-CLAUDE-COLLABORATION.md)。设备、签名、租用和收尾按这些文档执行，本文不重复。
3. 读本文全文。
4. 做到哪一项，再读对应的批次文档：
   - [路线决策模型](CLAUDE-2026-11-10-ROUTE-DECISION-MODEL.md)：模型全文、12 条行为变化、V1–V10。
   - [SMB 读取分段计时](CLAUDE-2026-11-11-SMB-READ-TIMING.md)：字段口径和读数解释表。
   - [替换源协调状态机](CLAUDE-2026-11-11-SOURCE-CHANGE-STATE-MACHINE.md)：规则表、接线步骤、W1–W10。
   - [S19 实测](CLAUDE-2026-11-10-S19-PROXY-READER-TIMING.md)：此前的真机数字，用作对照。
5. 开工前保存 `git status --short`，核对它仍是 122 个路径、HEAD 仍是 `8db1cc64`。不一致时先弄清是谁改的，再继续。

## 二、真机环境（以现场核对为准）

| 项 | 此前记录 | 接手时要做的 |
| --- | --- | --- |
| iPhone 13（iPhone14,5 / iOS 16.3.1） | USB 加 WDA。装的是早于本批的签名 Debug。11-10 晚的蜂窝窗口里 Jellyfin 可用。蜂窝为用户报告的弱蜂窝 | 蜂窝场景的主力机。fresh 核 USB、App、Runner。登录失效时由用户在 App 内重新登录 |
| A16 iPad（iPad15,7 / iPadOS 26.6） | USB。装的是早于本批的包。SMB、Jellyfin、设备文件三入口可用 | SMB 场景的主力机。不要对 `network.library.source` 做合成点击 |
| iPhone 18 Pro Max | 保持 hands off。DSM 地址必须保持用户原有的域名加端口 | 本批不需要它 |
| Apple TV | 用户已暂停 | 不操作 |
| 描述文件 | 有效期到 11-15 08:30 CST | 过期前完成，或按手册重签 |
| 样本 | S19：128.8 GB，源码率 75.2 Mbps。对照固定用音轨 AC3 2、字幕 PGS 9 | 每个窗口结束前把音轨和字幕恢复到这组 |
| 私有证据 | `~/Library/Application Support/Nastart/DebugEvidence/`，此前的场景脚本在 `claude-s19-proxy-timing-20261110/` | 新批次另建目录。原始偏好、凭据、原图不进仓库 |
| 诊断上限 | 只保留最近 1000 条，HLS 遥测量大 | **每一步之后立即导出** |

导出诊断有两种，脚本各认一种：
- 文本导出（App 内导出）：给 `playback_route_decision_report.py`。
- JSON 条目（`scripts/download_device_diagnostics.py --device <UDID> --output <仓库外的新目录>`，产出 `entries.json`）：给 `playback_reader_timing_report.py`。原始偏好可能含凭据，目录必须在仓库外。

切换网络由用户决定。提前一次性说明整个窗口需要切几次（T2 需要 2 次：切到蜂窝、切回 Wi-Fi）。不要自行改系统设置。蜂窝窗口的收尾按 AGENTS 的蜂窝规则。

## 三、设计要点

记号：B 是源码率，Ĉ 是路线容量。路线 = 服务器源加网络类别。"估计值"可以判定"不够"；"下界"只说明至少有这么多，不能判定"不够"。

**证据**（都只留 600 s，每类最多 16 个样本）：

| 证据 | 来源 | 当作 |
| --- | --- | --- |
| 探测 P | Jellyfin 测速：Wi-Fi 4 MB，蜂窝 1 MB，其余 512 KB | Wi-Fi 是估计值，其余是下界 |
| 原片持续交付 S | 合格的 body window，以及无背压且持续 ≥ 2 s 的原片 Range | 估计值 |
| HLS 分段 H | ≥ 1 MB 的分段，取中位数 | 下界 |

**合并**：有 S 时用 S，只计它之后的分段；之后的分段 ≥ 1.5 × S 时 S 作废。没有 S 时，Wi-Fi 探测是估计值，直到分段 ≥ 1.5 × P。其余只有下界，Ĉ = max(H, P)。

**判定**（公网、自动画质；自上而下取第一条）：

| 条件 | `originalVerdict` | 路线 |
| --- | --- | --- |
| 源码率未知 | `unknownDemand` | 原片 |
| 没有任何证据 | `noEvidence` | 原片 |
| B ≤ 1.5 × Ĉ | `fits` | 原片 |
| Ĉ 是估计值 | `measuredInsufficient` | HLS |
| 只有下界，有 H，且 B ≤ 3 × H | `explore` | 原片（试探） |
| 只有下界，其余 | `lowerBoundTooFar` | HLS |

内网路线和用户指定原画不看证据，始终原片。

**HLS 档位**：档位表（30、20、12、10、8、4、2、1.5、1、0.75、0.5、0.375、0.25 Mbps）中不超过 min(上限, 0.5 × Ĉ) 的最高一档。上限 = min(20 Mbps, 网络类别上限)：Wi-Fi 20，蜂窝 12（计费）或 16，受限网络 6。没有证据时用网络默认值（蜂窝 2，Wi-Fi 8）。

**持久化**：S 和 H 存 `Library/Caches/playback-route-evidence.json`，有效期仍是 600 s，按真实时间算。

## 四、代码地图

| 内容 | 位置 |
| --- | --- |
| 证据合并 `PlaybackRouteCapacityPolicy.assess` | `ios/Nastart/Nastart/Playback/Core/PlaybackPlanningPolicy.swift:902` |
| 证据存取与持久化 `PlaybackRecentThroughputStore` | 同文件 `:1000` |
| 档位表与降档 `PlaybackAdaptiveBitratePolicy` | 同文件 `:1294` |
| 判定与档位 `PlaybackRouteDecisionPolicy` | 同文件 `:1348` |
| 换源状态机 `PlaybackSourceChangeCoordinator`（未接线） | 同文件 `:42` |
| Jellyfin 起播接入：`originalVerdict`、`routeCapacityEvidence` 诊断 | `ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift:7608` |
| 播放中降档 `adaptiveFallbackRequest` | 同文件 `:8365` |
| 评估入口 `routeCapacityAssessment` | 同文件 `:8724` |
| 探测 `measureMaximumBitrate` | 同文件 `:8862` |
| 网络类别上限 | `ios/Nastart/Nastart/Features/Launchpad/LaunchpadPlaybackCore.swift:840` |
| 设备文件蜂窝起播 `JellyfinMatchedFileStream.startupRendition` | `ios/Nastart/Nastart/Features/Devices/DevicesView.swift:1985` |
| 代理计时 `NetworkMediaProxyTransferTimeline` | 同文件 `:4105` |
| SMB 读取计时 `SMBWorker.timed` | `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/SMBConnection.swift:539` |
| SMB 读取循环（每次 1 MiB） | `ios/Nastart/Packages/NetworkMedia/Sources/NetworkMedia/SMBLibrarySource.swift:119` |
| 换源现有实现 `replaceSource` | `ios/Nastart/Nastart/Playback/GreenfieldVideoPlayerView.swift:652` |
| 离线复算 | `scripts/playback_route_decision_report.py`、`scripts/playback_reader_timing_report.py` |

行号是 11-11 的，改动后以符号名为准。

## 五、任务队列

T0、T1 是其余各项的前提。T2 和 T3 互不依赖，T3 可以和 T1 放在同一个内网窗口里做。T4 依赖 T2。T5 依赖 T1 和 T2，放在最后。前提没有结论时不要开始后一项，否则出了回归分不清是谁造成的。

### T0 构建并装包

1. 从当前工作区（含全部未提交改动）构建签名 Debug。记录源码状态、构建时间、主程序和 Debug dylib 的 SHA-256。
2. 按 AGENTS 的七条逐台核对并保留数据覆盖安装。不卸载，不清数据。
3. 默认无测试环境变量启动。`NASTART_TEST_ROUTE_EVIDENCE=memory` 只在需要"每次启动都没有路线证据"时用，用完恢复。
4. 装包后第一次播放没有持久化的路线证据，这是正常的。

### T1 内网回归（V1、V2）

设备：iPad 或 iPhone 13，家中 Wi-Fi，内网地址。不需要切换网络。

- 步骤：S19 起播、续播、从头各一次。续播后如果自然降档，记录一次。
- 判定：三次都是原片。`playback_prepared` 的 `mode` 以 `DirectPlay` 结尾，主记录 `renditionCeiling=legacyBudget`。首帧和此前同量级（起播约 0.6–0.9 s，续播约 2.5–3.6 s）。降档时 `fromBitrate=20000000`。
- 不通过：内网出现了 HLS，或 `renditionCeiling` 不是 `legacyBudget`。这是接入代码的缺陷，不是调参问题。保留诊断，按第八节交回。

### T2 蜂窝窗口（V3–V8、V10）

设备：iPhone 13。需要用户切换网络 2 次。全部蜂窝场景放在同一个窗口。

- 步骤和每一项的判定见 [路线决策模型](CLAUDE-2026-11-10-ROUTE-DECISION-MODEL.md) 第三节的 V3–V8 和 V10。
- 每一步之后导出文本诊断并运行：

```sh
python3 scripts/playback_route_decision_report.py 导出.txt
```

- 退出码 0：日志里的判定和档位都符合规则。退出码 1：有记录不符，脚本会列出是哪一条、差在哪。
- 同时记录每次起播的首帧时间、是否出现 `automatic_downshift_requested`，供 T4 使用。
- 顺带记录 HLS 切音轨和 ±15 s 跳转的耗时。

结果分两类处理，不要混：

| 结果 | 含义 | 做什么 |
| --- | --- | --- |
| 脚本报不符 | 代码没有按模型执行 | 这是缺陷。定位到 `LaunchpadView.swift` 的接入处修复，补单测。不要通过改常数来让它"对上" |
| 脚本通过，但体验不好 | 模型按设计执行了，设计的取舍在这种条件下不合适 | 对照第七节判读。属于第六节可调的就按规则调，否则按第八节交回 |

预期会看到、不算缺陷的两种情况：蜂窝冷起播的 HLS 档位偏低（探测 7–8 Mbps 时是 2 Mbps）；分段下界跨过 25.1 Mbps 前后，S19 的路线从 HLS 变成原片试探。

### T3 SMB 读数

设备：iPad，内网 Wi-Fi。不需要切换网络。

- 步骤和读数解释表见 [SMB 读取分段计时](CLAUDE-2026-11-11-SMB-READ-TIMING.md) 的"下一个 iPad SMB 窗口怎么用"。
- 要拿到的三个数：`readerSplit.wireBitrate`、同一窗口里设备文件（HTTP）的无背压交付速率、`firstReads` 里排队占首块延迟的比例。
- 按解释表选方向。任何改读取大小、并发或连接数的优化都是行为改动：先补单测，再做同条件的真机前后对照。两轮没有改善就停，保留失败记录。
- 预读需要物化字节，受"启动预读默认只观察 IO"约束，不在本批范围。

### T4 校准试探系数

前提：T2 里至少有 5 次 `originalVerdict=explore` 的起播，来自不止一部影片或不止一种信号条件。样本不够就不调。

- 看两件事：首帧时间；起播后 30 s 内是否出现 `automatic_downshift_requested`。
- 多数试探随后降档，或首帧普遍超过 10 s：把系数从 3 调到 2.5，仍然如此再调到 2。
- 很少降档且首帧正常：保持 3。
- 不要调到 3 以上。那需要先有看门狗（第九节第 2 项）。
- 改系数时四处一起改，见第六节。

### T5 状态机接线（W1–W10）

前提：T1、T2 有结论。单独一批，不和其他改动混在一起。

- 步骤、`Target` 到现有加载器的对应、回归清单见 [替换源协调状态机](CLAUDE-2026-11-11-SOURCE-CHANGE-STATE-MACHINE.md) 第三节。
- 接线前先用第七节第 3 小节的判读表，看已有的导出日志里这 6 处问题有没有出现过。出现过的优先回归。
- W4、W5、W6、W7 是行为会变的四项，W3 是新增的取消，其余是回归项。
- 接线后同一项连续两轮不通过：撤回视图里的接线，保留 `PlaybackSourceChangeCoordinator` 类型和它的单测，把现象和诊断写进交接。
- 先确认第九节第 5 项（换集加载中对旧一集的操作）用户是否同意。

### T6 可选：换源重叠核对脚本

把第七节第 3 小节的判读规则写成脚本 `scripts/playback_source_change_report.py`，写法参照 `playback_route_decision_report.py`。设计会话只做了规则分析，没有写脚本，规则也没有用真实导出验证过。先用一份真实导出手工核对一遍规则，再写。

## 六、调参规则

可以调的：

| 参数 | 位置 | 当前 | 允许范围 | 需要的证据 |
| --- | --- | --- | --- | --- |
| 试探系数 | `PlaybackRouteDecisionPolicy.explorationFactor` | 3.0 | 2.0–3.0 | T4 的规则 |
| 切轨提前量初值 | `GreenfieldAVPlayerWarmup.rendererPreparationSeconds` | 11 s | 不低于实测切轨准备时间加 1 s | 用户同意排期后才动（第九节第 3 项）。做同条件前后对照；初值偏小时候选会迟到，反而更慢 |
| SMB 单次读取大小 | `SMBMediaResource.stream` 里的 `1 << 20` | 1 MiB | 不超过协商上限；短 Range 保持小读取 | T3 的读数落在"每次请求固定开销占主导"那一行 |

改 `explorationFactor` 时四处一起改，否则单测或复算脚本会报错：
1. `PlaybackPlanningPolicy.swift` 里的常数。
2. `scripts/playback_route_decision_report.py` 的 `EXPLORATION_FACTOR`。
3. `PlaybackNextCoreTests.swift` 和 `scripts/test_playback_route_decision_report.py` 里按 3 倍写死的数字。
4. [路线决策模型](CLAUDE-2026-11-10-ROUTE-DECISION-MODEL.md) 里的 25.1 Mbps（= 75.2 ÷ 3）等数字。

没有新的真机对照不要调的：

| 参数 | 当前 | 原因 |
| --- | --- | --- |
| 判定余量 `sustainMargin` | 1.5 | 有真机数据支撑，改动影响所有路线 |
| 档位份额 `renditionShare` | 0.5 | 同上 |
| 证伪系数 `refutationFactor` | 1.5 | 和判定余量成对 |
| 证据有效期 `evidenceMaximumAge` | 600 s | 路线键不含具体网络身份，延长会把别处的证据带过来 |
| 持续交付最短时长 | 2 s | 更短会把慢启动里的读数当成估计值 |

不许改的（用户的硬约束）：
- 公网自动 HLS 上限 20 Mbps（`publicRenditionCeiling`）。
- 内网和局域网优先原片。
- 原片探测不创建代理、不打开解码器。
- FTP 和 SMB 只在局域网。

另外，`scripts/preflight.py` 要求 `LaunchpadView.swift` 里保留若干源码片段的原文。改这个文件后运行 `python3 scripts/preflight.py`，输出要和改动前一致（它现有的失败项都是基线里就有的）。

## 七、判读手册

### 1. 路线决策

先看那次起播的 `playback_preparing stage=routeCapacityEvidence` 记录。

| 现象 | 看什么 | 结论和动作 |
| --- | --- | --- |
| 蜂窝起播走了原片，首帧很慢 | `originalVerdict` | `explore`：规则如此，记入 T4。`noEvidence`：探测还没完成就点了播放，看有没有 `bitrate_measured`；记录，不调参。`fits`：看 `capacitySource`，是 `playbackDelivery` 时说明 600 s 内的原片证据偏高，可能是同类别内换了网络（已知局限） |
| 蜂窝 HLS 档位很低 | `capacitySource`、`probeCapacity` | `preplayProbe` 且读数低：已知缺口，1 MB 探测偏弱。再起播两三次，`renditionLowerBound` 应当逐次抬高档位。抬不上去时记录每次的下界和档位，按第八节交回 |
| 同一路线连续两次起播判定不同 | 两条证据记录逐字段比较 | 有新样本，或某类证据满 600 s：符合规则。字段都没变而判定变了：缺陷 |
| 重启后判定变了 | `restoredSamples` | 距上次播放超过 10 分钟：正常。10 分钟内且为 0：持久化没有生效，查 `Library/Caches/playback-route-evidence.json` 是否写出 |
| 内网出现 HLS | 主记录的 `renditionCeiling`、`requestReason` | 音轨需要转码或字幕需要烧录：和路线决策无关。否则是缺陷 |
| 降档后的档位不对 | `playback_downshifted` 的 `fromBitrate`、`toBitrate`、`liveCapacity`、`routeCapacity` | `toBitrate` 应当是严格低于 `fromBitrate`、且不超过 0.5 × min(`liveCapacity`, `routeCapacity`) 的最高一档 |

### 2. SMB

用 [SMB 读取分段计时](CLAUDE-2026-11-11-SMB-READ-TIMING.md) 的读数解释表。读数落不进表里任何一行时，不要自己加一行解释，按第八节交回。

### 3. 换源的 6 处问题在日志里的样子

这些规则由读代码得出，没有用真实导出验证过。先认记录：

- `playback_preparing`（带 `requestReason` 和 `defaultMode`）和 `playback_prepared`（带 `startTimeTicks`）的 `playbackTraceID` 是**候选流**的。`requestReason` 取值：`sourceTrackSwitch` 选轨，`serverSeek` 服务端跳转，`initialPlayback` 起播或换集，`bitrateFallback` 自动降档。
- `replacement_*`、`paused`、`resumed` 的 `playbackTraceID` 是**正在播放的流**的。`replacement_committed` 之后，播放器记录改用候选流的编号。
- `replacement_warmup_failed` 的 `stage` 或 `reason` 是 `candidateInvalidated`：候选是被别的请求顶掉的。其他取值：候选自己失败了。
- 文本导出里，播放器事件的消息就是原始键名 `diagnostics.playback.next.<事件名>`。
- 暂停式请求（跳转、换集）开始时会让旧流记一次 `paused`。这次 `paused` 紧贴在该请求的 `playback_preparing` 之前，不是用户按的。

| # | 问题 | 日志里的样子 |
| --- | --- | --- |
| 1 | 选轨被服务端跳转丢掉 | 一条 `sourceTrackSwitch` 之后没有 `replacement_committed`，30 s 内紧跟一条 `serverSeek`，两条的 `audioStreamIndex` 或 `subtitleStreamIndex` 不同 |
| 2 | 跳转被选轨丢掉 | 一条 `serverSeek` 之后没有 `replacement_committed`，30 s 内紧跟一条 `sourceTrackSwitch`；两条各自 `playback_prepared` 的 `startTimeTicks` 相差超过 5 s（除以 10^7 得秒） |
| 3 | 同一集加载两遍 | 播放器内连续两条 `initialPlayback`，`sourceBitrate` 相同；第一条没有 `replacement_committed`，第二条有 |
| 4 | 两次暂停式替换之间旧流先恢复再暂停 | 两条相邻的暂停式请求，第一条没有提交；两条的 `playback_preparing` 之间旧流又记了一次 `paused`。比较前后两次 `paused` 的 `currentSeconds`，可以知道时钟有没有走 |
| 5 | 准备切轨时暂停，跳转后却自动播放 | 一条未提交的 `sourceTrackSwitch`；其间旧流记了 `paused`，之后没有 `resumed`，并且这次 `paused` 比随后 `serverSeek` 的 `playback_preparing` 早 1 s 以上；该跳转的 `replacement_committed` 里 `startsPaused=false` |
| 6 | 换到一条相同的流 | 一条已提交的 `sourceTrackSwitch`，它的 `audioStreamIndex`、`subtitleStreamIndex`、`requestedServerSubtitleIndex` 和被它替换的那条流完全相同。被替换的流用 `replacement_committed` 的 `playbackTraceID` 去找它的 `playback_prepared` |

候选自己失败（`replacement_warmup_failed` 的其他 `stage`，或带 `stage=sourceTrackSwitch` / `serverSeek` 的 `playback_failed`）时，不算上面任何一条。

## 八、什么时候停下来交回

出现下面任何一条时，保存诊断和现象，写进交接，不要自己改模型：

1. T1 不通过：内网行为变了。
2. 复算脚本通过，但同一类体验问题在两个窗口里都出现，而第六节没有对应的可调参数。
3. 数据和模型的前提矛盾。例如：分段下界经常不到真实速率的一半；`measuredInsufficient` 之后同一路线的原片实际播得很顺；判定在没有新证据时来回翻转。
4. SMB 读数落不进解释表。
5. 需要新增机制才能解决：看门狗、播放中升档、时间盒化的探测、预读。
6. 同一参数调了两轮没有改善。按调试规范停止，不再第三轮。

交回时给出：场景、网络、包身份、导出诊断的路径、相关的 `routeCapacityEvidence` 或 `readerTimingWindow` 记录、已经试过什么。

## 九、等用户决定的事（接手模型不要自行决定）

1. 试探系数 3 是否先按推算值上真机，再按 T4 校准。默认按此执行，用户可以改。
2. 蜂窝冷起播档位偏低，三个方向做哪个、先做哪个：时间盒化的大探测、试探式起播看门狗、播放中升档。
3. "切轨后跳转合并"和"提前量初值"是否排期。前者随 T5 接线自然得到。
4. 设备文件入口的播放中降档，是否也用 20 Mbps 或网络上限作包络。现在从源码率往下降，有单测固定。
5. 换集加载中对旧一集的选轨和跳转：状态机选择忽略；现在的行为是最后一次操作生效，换集会被放弃。
6. 是否允许会话内保留头尾字节。这需要放宽"启动预读不物化字节"。

## 十、硬约束

- 工作区的未提交改动全部保留。不还原，不提交，不推送，除非用户明确要求。
- 密码和 TMDB 令牌只由用户在 App 内输入。不读 Keychain，不点密码眼睛，不猜测或重复旧密码。
- NAS、Jellyfin、远端文件和配置只读。不重启服务，不改 NAS 或 VPN。
- 同一台真机同一时段只有一个操作者。开窗前登记，收窗后核对 App 和 Runner 都已退出。
- 蜂窝窗口结束时恢复原 Wi-Fi 并核对状态栏图标。
- 共享文档（PROGRESS、当前交接、开发状态、需求总账、播放矩阵、资源登记、协作分工）由 Codex 单写。Claude 一侧只写自己的批次交接，列出需要同步的条目。
- 用中文回复，汇报精简，回复末尾附【进度小结】三行。

## 十一、验证现状

| 项 | 结果 |
| --- | --- |
| App 单测（`PlaybackNextCoreTests`、`NonPlaybackPolicyTests`） | 执行 699 项，698 通过，2 项跳过。唯一失败是基线已知的 `testMediaRangePolicyDoesNotTurnMalformedRangesIntoAnOpenResponse` |
| NetworkMedia 包（`swift test`） | 354 项，348 通过，6 项跳过，0 失败 |
| 脚本单测 | 路线复算 6 项、Reader 计时 6 项通过 |
| tvOS | 17 个共享播放核心文件类型检查通过。没有构建完整的 tvOS 目标 |
| `scripts/check_documentation.py` | 缺失链接 0 |
| 真机 | **全部未验证** |

跑单测的方法：`xcrun simctl create` 建一个临时模拟器，在 `ios/Nastart` 下执行 `xcodebuild test -workspace Nastart.xcworkspace -scheme Nastart`，加 `-only-testing:NastartTests/PlaybackNextCoreTests` 和 `-only-testing:NastartTests/NonPlaybackPolicyTests`，跑完删除模拟器。包测试在 `ios/Nastart/Packages/NetworkMedia` 下执行 `swift test`；它的回环集成测试偶尔卡在收尾，结束进程后重跑即可。

## 十二、交付要求

每个窗口或每批改动写一份批次交接，放在 `docs/archive/handoffs/2026-11/`，包含：
- 包身份、设备核对结论、窗口起止时间、收尾结果。
- 每个场景的判定和依据的诊断字段。失败和超时照实记，不丢弃。
- 复算脚本的输出。
- 改了哪些参数或代码，对应的单测结果。
- 没有验证的项，以及需要 Codex 同步到共享文档的条目。

之后运行 `python3 scripts/check_documentation.py`。

## 十三、开工提示词

把下面这段原样发给接手的模型。Claude 和 Codex 通用，区别只在共享文档由谁写，已写在交付一段里。

```text
你接手 Nastart（iOS，Swift）播放策略的真机验证、调试和调参。

背景：上一个设计会话完成了三块工作，都通过了模拟器单测：路线决策模型（原片还是服务端 HLS、HLS 选哪一档）、SMB 读取分段计时（只加诊断）、换源协调状态机（纯逻辑，还没有接进播放器）。这些代码从未装到任何真机。你的工作是在真机上确认代码按模型执行、体验可接受，并在规定范围内调参。模型结构不归你改：发现模型本身不合适时，保存证据交回。

开工先读，读完再动手：
1. CLAUDE.md、AGENTS.md、PROGRESS.md
2. docs/archive/handoffs/2026-11/2026-11-11-1950-CLAUDE-DESIGN-TO-DEVICE-DEBUG.md。这是总交接，任务顺序、判定标准、调参规则、停止条件和硬约束都以它为准。
3. 总交接第一节列出的其余文档。批次文档做到哪一项再读哪一份。

然后核对现场：git status --short 应为 122 个路径，HEAD 应为 8db1cc64，不一致时先弄清原因。签名描述文件 11-15 08:30（北京时间）到期，排期时留意。
核对完先用几行告诉用户你的窗口计划：每个窗口用哪台设备、什么网络、需要用户做什么。

任务按顺序做，前一项没有结论，不要开始依赖它的后一项：
T0 从当前工作区（含全部未提交改动）构建签名 Debug，装到 iPhone 13 和 iPad。逐台核对，保留数据覆盖安装，不卸载，不清数据。
T1 内网回归（V1、V2）。不通过就停下交回。
T2 蜂窝窗口（V3–V8、V10），用 iPhone 13。需要用户切换网络 2 次，开始前一次性告诉用户。
T3 iPad 上取 SMB 读数。不需要切网，可以和 T1 放在同一个内网窗口。
T4 T2 的样本够时校准试探系数，不够就不调。
T5 换源状态机接线并回归 W1–W10。放在最后，单独一批，先请用户确认总交接第九节第 5 项。
T6（换源核对脚本）可选。

容易出错的地方：
- 诊断只保留最近 1000 条。每一步操作后立即导出，否则证据会被覆盖。
- 复算脚本报不符，说明代码没有按模型执行，要修代码并补单测。不要改常数让结果对上。
- 脚本通过但体验不好，才允许调参，而且只调总交接第六节"可以调"的参数，在它给的范围内。
- 总交接第八节列出的情况一律停下交回；第九节的事项等用户决定。同一参数调两轮没有改善就停。
- 每个"通过"都要写出依据的诊断字段和脚本输出。失败、超时、没做的项照实写。
- 不要重构，不要顺手修无关问题。单测 testMediaRangePolicyDoesNotTurnMalformedRangesIntoAnOpenResponse 在基线就失败，与本任务无关，不要修。
- 改了 LaunchpadView.swift 后运行 python3 scripts/preflight.py，输出要和改动前一致。

硬约束：
- 工作区的未提交改动全部保留。不还原，不提交，不推送，除非用户明确要求。
- 不读 Keychain 凭据，不点密码眼睛，不猜测或重复旧密码。需要登录时请用户在 App 内输入。
- NAS、Jellyfin、远端文件和配置只读。
- 公网自动 HLS 上限 20 Mbps；内网和局域网优先原片；原片探测不创建代理、不打开解码器；FTP 和 SMB 只在局域网。
- 碰真机前按 AGENTS 和资源登记核对设备的归属和占用，同一台设备同一时段只有一个操作者。iPhone 18 和 Apple TV 不操作。iPad 上不要对 network.library.source 做合成点击。
- 切换网络由用户来做，你不改系统设置。蜂窝窗口无论怎样结束，都要恢复原来的 Wi-Fi 并核对状态栏图标。

交付：每完成一个任务，就把结果写进 docs/archive/handoffs/2026-11/ 下你自己的批次交接（内容按总交接第十二节），再开始下一个，这样会话中断时可以接续。共享文档（PROGRESS、当前交接、开发状态、需求总账、播放矩阵、资源登记、协作分工）只由 Codex 写：你是 Codex 时按协作分工同步；你是 Claude 时只在批次交接里列出需要同步的条目。写完运行 python3 scripts/check_documentation.py。

用中文回复，汇报精简，回复末尾附【进度小结】三行：做了什么、做到哪、接下来干什么。
```
