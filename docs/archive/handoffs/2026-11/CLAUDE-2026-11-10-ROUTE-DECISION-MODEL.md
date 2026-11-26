# 2026-11-10 Claude：播放路线决策模型（原片 / 服务端 HLS / HLS 档位）

真机验证、调试和调参从 [给接手模型的总交接](2026-11-11-1950-CLAUDE-DESIGN-TO-DEVICE-DEBUG.md) 开始，本文是其中路线决策部分的全文。

接续 [任务简报](CLAUDE-2026-11-10-HARD-PROBLEMS-BRIEF.md) 和 [S19 实测](CLAUDE-2026-11-10-S19-PROXY-READER-TIMING.md)。基线 `main/8db1cc64` 加已有未提交改动。本批只做设计、策略代码和模拟器单测。没有操作真机，没有访问 NAS 或 Jellyfin，没有读取 Keychain，没有提交、暂存或推送。

## 结论

- 路线决策收敛到一处。一条路线的全部证据先合并成一个容量数字，再由一个函数判定"原片还是 HLS"，另一个函数给出 HLS 档位。起播、续播、从头播放和播放中回退读同一份评估。
- 简报的两个待决问题：
  1. "只剩下界、源码率超过下界 3 倍时跳过原片"成立，已实现。它只对 HLS 分段下界生效；单次探测的读数不触发试探。
  2. 路线证据要跨重启保留，已实现。有效期和内存中相同（600 s），按真实流逝时间计算。
- 单测：`PlaybackNextCoreTests` 与 `NonPlaybackPolicyTests` 共 689 项，688 项通过。唯一失败是已知的 `testMediaRangePolicyDoesNotTurnMalformedRangesIntoAnOpenResponse`，改动前的基线同样失败。
- 11-11 补做：设备文件入口在蜂窝上改走 Jellyfin 转码的起播判定，改为调用同一组函数。判定不变，档位多了公网上限。
- 全部真机行为未验证。验证清单在第三节。

## 一、决策模型

记号：B 是源码率；Ĉ 是路线评估给出的容量数字。"估计值"指读数可能偏高也可能偏低，可以用来判定"不够"。"下界"只说明路线至少能交付这么多，不能用来判定"不够"。

路线 = 服务器源（协议、主机、端口）+ 网络类别（wifi / cellular / …），与现有路线键相同。

### 1. 四类证据

| 证据 | 测的是什么 | 当作 | 偏差 | 有效期 | 持久化 |
| --- | --- | --- | --- | --- | --- |
| 播放前探测 P | Jellyfin 测速字节（服务端内存生成，不读盘）。Wi-Fi 4 MB，蜂窝 1 MB，其余 512 KB。只用按响应体计时的样本，只留最新一次 | Wi-Fi：估计值。其余：下界 | 小样本可能在 TCP 慢启动内结束。按初始窗口 10 个报文、每往返翻倍估算，1 MB 的读数上限约为 1.4 / RTT(秒) Mbps：RTT 100 ms 约 14 Mbps，175 ms 约 7.7 Mbps；4 MB 约为 4.1 / RTT。这是估算，没有在真机上核对 RTT。另外它是单次瞬时值，也不经过原片的读盘路径 | 600 s | 否，重启后由资料库加载重新测 |
| 原片持续交付 S | 合格的 body window（相邻两个 2–4 s、无代理背压、速率相差不超过 2 倍），以及无背压且持续 ≥ 2 s 的原片 Range 完成。取中位数 | 估计值 | 最接近原片真实可得的速率。播放器吃饱时有背压，不产生样本；跟不上时没有背压，几秒内就有样本 | 600 s | 是 |
| HLS 分段交付 H | ≥ 1 MB 的分段，从发起请求到收完。取中位数 | 下界 | 受档位（分段大小）、转码速度和请求等待限制。实测 2 Mbps 档读到 5.2–12.2 Mbps，20:2x 的会话读到 20.1–22.8 Mbps | 600 s | 是 |
| 播放中估计 E | 当前这一次播放：60 s 内完成传输的下四分位，最近 3 次的中位数（用于预测），6 s 内的 body window | 当前流的估计值 | 只描述当前这条流；HLS 时含等待时间 | 6 s / 60 s | 否 |

E 不直接参与起播。它的合格样本同时写入路线的 S 或 H，这是 E 和路线证据之间唯一的通道。E 只用于播放中的降档触发和降档档位，这两处的规则本批没有改。

本批对证据口径做了一处修正：原片的短读取（头部、尾部、索引，持续不足 2 s）不再计入路线证据。它们和 1 MB 探测一样会落在慢启动内，在快线路上读数偏低。旧代码把它们算作"直接证据"，一次只播了几秒的原片会留下偏低的估计值，随后 10 分钟内把原片判成带宽不足。这些短读取仍然进入 E。

### 2. 合并规则

按证据强弱排序：原片持续交付 > HLS 分段 > 探测。

1. 有 S：S 是估计值。只有在最新一个 S 样本**之后**交付的分段才计入。更早的分段描述的是那次交付之前的线路。探测不参与，单次探测不推翻真实交付。
   - 之后的分段中位数 ≥ 1.5 × S：S 作废，只剩这个下界。说明线路变好了，或 S 读低了。
   - 否则 Ĉ = max(S, 之后的分段中位数)，仍是估计值。
2. 没有 S、探测是估计值（Wi-Fi）：探测是估计值，直到分段中位数 ≥ 1.5 × P。对探测不要求分段在它之后：详情页会重测探测，要求先后会让分段永远无效。
3. 其余：只有下界，Ĉ = max(H, P)。

"下界只升不降"在这里的含义：下界可以抬高 Ĉ，可以推翻一个明显偏低的估计值，但不能压低任何东西。

### 3. 原片判定

公网路线、自动画质、音轨和字幕都能在本机解码时，自上而下取第一条命中的规则：

| 条件 | `originalVerdict` | 路线 |
| --- | --- | --- |
| 源码率未知 | `unknownDemand` | 原片 |
| 路线没有任何证据 | `noEvidence` | 原片 |
| B ≤ 1.5 × Ĉ | `fits` | 原片 |
| Ĉ 是估计值 | `measuredInsufficient` | HLS |
| 只有下界，有分段下界 H，且 B ≤ 3 × H | `explore` | 原片（有界试探） |
| 只有下界，其余情况 | `lowerBoundTooFar` | HLS |

内网路线和用户指定原画不看证据，始终原片。用户指定画质、音频需要服务端转码、字幕需要服务端烧录这些条件在判定之前由原有代码处理，没有改。

### 4. HLS 档位

- 起播：档位表中不超过 min(上限, 0.5 × Ĉ) 的最高一档，含上限本身。上限 = min(20 Mbps, 网络类别上限)：公网 Wi-Fi 20，蜂窝 12（计费）或 16，受限网络 6。
- 没有任何证据：用网络类别的保守默认值（蜂窝 2 Mbps，Wi-Fi 8 Mbps），不超过上限。
- 播放中降档：规则不变，选严格低于当前档、且不超过 0.5 × min(E, Ĉ) 的最高一档。从原片降档时"当前档"取上限。

0.5 和 1.5 两个系数没有改。它们有真机数据支撑，改动需要真机对照。

### 5. 失效规则

1. 时间：三类路线证据统一 600 s。旧代码探测 120 s、其余 600 s，探测过期后在无其他证据时会直接试原片，这是 08:5x "首播 HLS、127 秒后从头却走原片"的原因。
2. 时钟：样本同时记单调时钟和墙上时钟，年龄取两者中较大的。单调时钟在设备休眠时停走，旧代码里挂起两小时的 App 会把两小时前的证据当成刚测的。墙上时钟被往回拨时退回单调时钟；被往前拨时证据提前失效。
3. 证伪：估计值被之后明显更高（≥ 1.5 倍）的分段下界推翻。
4. 取代：新探测替换旧探测。
5. 数量：每条路线每类最多 16 个样本。
6. 路线变化：Wi-Fi 与蜂窝是两个路线键，互不影响。同一类别内换了网络（另一个 Wi-Fi）不会立即失效，最长影响 600 s。这是已知局限，路线键里没有具体网络的身份。

### 6. 持久化

要持久化。理由：证据是否有效只取决于它的年龄和线路，与进程是否重启无关。不持久化等于隐含一条"进程退出即失效"的规则，结果是重启后的第一次播放只能看 1 MB 探测，和重启前的选择可能不同。App 在后台被系统回收后再回来续播是常见情况。

实现：
- 只写 S 和 H。文件在 `Library/Caches/playback-route-evidence.json`，不进偏好设置，也不进 Keychain，所以装包前后的偏好比对不受影响。
- 内容只有路线键的 SHA-256 摘要、码率和时间。没有地址、账号、路径或媒体身份。
- 有效期不延长，仍是 600 s，按墙上时钟计算。时间在未来的样本丢弃。
- 更长的保留期没有采用：路线键不区分具体网络，把昨天咖啡店 Wi-Fi 的证据用到今天的办公室 Wi-Fi 上是错的。
- 写盘在后台队列，合并 5 s 内的样本。写失败只意味着下次重新测。
- 测试需要每次启动都没有路线证据时，Debug 包可设环境变量 `NASTART_TEST_ROUTE_EVIDENCE=memory`。默认不设。

### 7. 四个目标

**选择一致。** 判定函数的输入只有源码率和路线评估，没有播放位置，所以起播、续播、从头播放在同一份证据下结果相同。证据统一有效期后，不再有"一类证据先过期"造成的翻转。重启后恢复同一份证据。判定只在两种情况下改变：来了新证据，或证据满 600 s。

**不被低估锁死。**
- 下界只能抬高 Ĉ，不能压低。
- 偏低的估计值会被之后的分段下界推翻，不必等它过期。
- 原片的短读取不再产生估计值。
- HLS 档位不再受探测预算限制。旧代码里档位还要低于"0.8 × 探测值"换算出的预算，实播证据 48 Mbps、旧探测 7.7 Mbps 时只能到 4 Mbps；没有探测缓存的蜂窝上限是 2 Mbps。
- 分段下界在 3 倍以内时会试探原片，试探会留下估计值。
- 仍有缺口，见第 9 小节第 1 条。

**首帧延迟。**
- 分段下界离源码率超过 3 倍时不再试原片。20:2x 的 q2（下界 22.8 Mbps，S19 75.2 Mbps，3.3 倍）现在直接走 HLS。
- 探测存在时不再有"探测过期就盲试原片"。
- Greenfield 走 HLS 前不再等待一次新探测。旧代码在没有可复用样本时会先等 1–4 MB 的测速完成。
- 试探的最坏情况有界：下界就是真实速率时，原片首帧时间大致与 B / Ĉ 成正比，3 倍处约为 S19 续播的 10–15 s（由 16.9 s @ 3.3–5 倍推算）。

**网络变好能回到原片。**
- Wi-Fi 与蜂窝之间切换：路线键不同，立即按新路线的证据判定。
- 同一路线变好：之后的分段下界 ≥ 1.5 × S 时 S 作废，下一次起播按下界判定为 `fits` 或 `explore`。
- 证据满 600 s 后回到探测或无证据状态，重新判定。
- 局限：正在播放的 HLS 档位低时，分段下界读不高，看不出线路变好；一次播放之内也没有升档。

### 8. 两个待决问题

**"只剩下界且源码率超过下界 3 倍时跳过原片"是否成立，阈值怎么定。**

成立，限定为分段下界。阈值 3 来自两个约束，它们在 3 附近相交：
- 可能性。原片够用需要真实速率 ≥ B / 1.5。分段下界读到真实速率的一半左右是常见的，所以 B ≤ 1.5 × 2 × H 时原片仍可能够用。超过 3 倍则要求下界低估两倍以上。
- 代价。下界就是真实速率时，首帧时间随 B / H 增长。S19 在 3.3 倍处实测 16.9 s，这已经被认定为过慢。

探测下界不适用这条规则。弱蜂窝上单次探测在几分钟内读出过 6.8、22.3、31.4 Mbps，瞬时高读数不代表持续速率；用它触发试探会把 16.9 s 的情况换个入口带回来。分段下界是多个分段的中位数，稳得多。探测只在 B ≤ 1.5 × P 时放行原片，与旧代码相同。

3 是推算值，需要真机校准。校准方法：统计 `originalVerdict=explore` 的起播，看首帧时间分布和随后是否降档。若大多降档，把系数调低到 2–2.5；若很少降档且首帧正常，可以保持。

**路线证据要不要跨 App 重启持久化。** 要，见第 6 小节。

### 9. 已知缺口和后续选项

1. **蜂窝 1 MB 探测是最弱的仪器。** 冷启动只有它时，读数低会让第一次 HLS 档位偏低（P = 7.7 → 2 Mbps），之后要靠分段下界一次次起播往上抬（低档位时每升一级，下界需读到当前档的 4 倍：2 → 4 → 8 Mbps）。旧代码在探测满 120 s 后盲试原片，对这种情况是意外的出路，代价是弱网下 16.9 s 的首帧；新模型去掉了这条路。三个互补的后续方向，都需要真机数据：
   - 时间盒化的大探测：按时长而不是固定 1 MB 结束，取后半段速率。直接改善仪器。
   - 试探式起播看门狗：`explore` / `noEvidence` 的原片在 4–5 s 内没有首帧就立即转 HLS。把"证据不可靠"的代价限制在机制上，之后可以放宽试探条件。实现时有一处要先核对：现有的替换流程按"旧播放器的当前位置 + 提前量"给候选定起点，而原片还没就绪时旧播放器的时钟可能还是 0。看门狗触发的替换应当是阻塞式的，候选从请求的起点（续播位置）起播。
   - 播放中升档：HLS 稳定且分段下界远高于当前档时换更高一档或原片。这是"起播保守、随后爬升"的标准做法，也是一次播放内摆脱低档的唯一办法。
2. **设备文件入口只收敛了一半。** 它在蜂窝上起播时改走已核实的 Jellyfin 转码，这一步的判定和档位现在与 Jellyfin 入口共用同一组函数（11-11 补做，见第二节）。没有收敛的部分：
   - 它只有自己那次 1 MB 探测，不读也不写路线证据。原片来自 DSM、转码来自 Jellyfin，是两个源，要先决定证据挂在哪条路线上。
   - 播放中降档的包络仍是源码率（Jellyfin 入口是 20 Mbps 或网络上限）。有单测固定了这个行为（40 Mbps 时降到 20 Mbps），而且这段代码分不清内网和公网，改它需要用户决定。
3. **路线键不含具体网络身份。** 见失效规则第 6 条。
4. **服务端受限的情况。** 探测和分段测的是网络，原片还要经过 NAS 读盘。如果原片交付被服务端限制而网络很快，之后的分段下界会反复推翻 S，每次起播都会先试一次原片。公网路线上通常是网络受限，这种情况没有实测依据，先记为风险。
5. **试探会重复。** 试探失败留下的估计值 600 s 后过期。如果分段下界仍在 3 倍以内，下一次起播会再试一次原片。对码率略高于线路能力的影片（S19 在约 50 Mbps 的线路上），间隔超过 10 分钟的每次起播都会先放一小段原片再换 HLS。可以给失败的试探加退避（下一次试探的间隔翻倍），先看 V5、V6 的数据再定。

## 二、代码改动和单测

### 改动文件

| 文件 | 内容 |
| --- | --- |
| `ios/Nastart/Nastart/Playback/Core/PlaybackPlanningPolicy.swift` | `PlaybackRouteCapacityPolicy` 重写为证据合并：`assess(sustained:rendition:probe:)` 返回 `Assessment`，`probeBoundsBothSides(networkKey:)`；原 `effective(direct:lowerBound:probe:)` 删除。新增 `PlaybackRouteDecisionPolicy`：`originalVerdict`、`renditionCeiling`、`startupBitrate`、`fallbackCapacity`。`PlaybackRecentThroughputStore`：路线样本带双时钟，新增 `routeEvidence(routeKey:now:)`，路线键改存摘要，新增持久化（`Persistence`、`persistRouteEvidence()`、`restoredRouteSampleCount`），原片短读取不再计入路线证据。`PlaybackAdaptiveBitratePolicy` 新增常量 `renditionShare`，`target` 行为不变。该文件同时被 tvOS 目标编译，新增代码只依赖 Foundation 和 CryptoKit |
| `ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift` | 新增 `routeCapacityAssessment(routeKey:networkKey:)`，起播和 `adaptiveFallbackRequest` 共用。起播：判定改用 `originalVerdict`；Greenfield 公网路线的档位改用 `startupBitrate`；Greenfield 不再等待新探测；判定带宽不足后不再被旧预算旁路放行；原片降档包络改为策略上限。诊断字段见下。`scripts/preflight.py` 要求保留的源码片段都在，"Playback routing invariants" 仍只有改动前就有的 1 条错误 |
| `ios/Nastart/Nastart/Features/Devices/DevicesView.swift`（11-11 补做） | 设备文件入口在蜂窝上改走 Jellyfin 转码的起播判定：新增 `JellyfinMatchedFileStream.startupRendition`，判定和档位调用同一组策略函数。判定结果与原来的谓词逐项相同；档位多了公网上限。两处降档加载器改用 `fallbackCapacity`，行为不变。起播诊断增加 `sourceBitrate`、`probeCapacity` |
| `ios/Nastart/NastartTests/PlaybackNextCoreTests.swift` | 改写 1 个测试（原来断言已删除的 `effective`），新增 9 个 |
| `scripts/playback_route_decision_report.py`、`scripts/test_playback_route_decision_report.py`（新增） | 离线复算工具：读导出的诊断文本，按第一节的规则逐次播放复算判定和 HLS 档位，列出不符的记录。用于第三节的真机验证。不发任何设备或网络请求 |

### 行为变化（Greenfield、公网路线、自动画质）

| # | 旧 | 新 |
| --- | --- | --- |
| 1 | 探测只在 120 s 内当证据；过期且无其他证据时直接试原片 | 探测 600 s 内有效，判定不随它的年龄翻转 |
| 2 | 只有分段下界：一律试原片 | B ≤ 3 × H 试原片，否则 HLS |
| 3 | 蜂窝探测与分段下界：取较大值当估计值，B > 1.5 × Ĉ 走 HLS | 两者都是下界；B ≤ 3 × H 时试原片 |
| 4 | 原片交付与分段下界：取较大值，不看先后 | 只计之后的分段；≥ 1.5 × S 时 S 作废 |
| 5 | 原片的短读取计入"直接证据" | 不计入路线证据 |
| 6 | HLS 起播档位低于 min(20 Mbps, 探测预算)，且不超过 0.5 × Ĉ | 不超过 min(策略上限, 0.5 × Ĉ)，含上限。蜂窝 Ĉ = 48：旧 10 Mbps（探测 7.7 时 4 Mbps），新 12 Mbps。公网 Wi-Fi Ĉ ≥ 40：旧 12，新 20 |
| 7 | 非带宽原因的 HLS（音频需转码、原片路由不可用）直接用探测预算 | 用同一个档位函数 |
| 8 | 走 HLS 前等待新探测完成 | 不等 |
| 9 | 原片降档包络 = min(20 Mbps, 探测预算)；无探测缓存的蜂窝是 2 Mbps，首次降档 ≤ 1.5 Mbps | 包络 = 策略上限；蜂窝首次降档 ≤ 10 Mbps，公网 Wi-Fi ≤ 12 Mbps |
| 10 | 判定带宽不足后，源码率不超过探测预算时仍试原片 | 一次请求只有一个判定 |
| 11 | 证据随进程消失；按单调时钟老化 | 600 s 内跨重启保留；按真实时间老化 |
| 12 | 设备文件入口在蜂窝上起播转码：档位是 0.5 × 探测值，没有上限，探测 ≥ 40 Mbps 时 20 Mbps，≥ 60 Mbps 时 30 Mbps | 同样受 min(20 Mbps, 网络类别上限) 约束：计费蜂窝最高 12 Mbps。是否转码的判定不变 |

内网路线和旧播放器（非 Greenfield）路径不变：内网仍始终原片，降档包络仍是 20 Mbps、首次降到 12 Mbps。第 1–11 条是 Jellyfin 入口，第 12 条是设备文件入口。

### 诊断字段

- `playback_preparing stage=routeCapacityEvidence`：`capacitySource`（`playbackDelivery` / `preplayProbe` / `renditionLowerBound` / `none`）、`capacity`、`capacityBoundsBothSides`、`playbackCapacity`（S）、`renditionLowerBound`（计入的 H）、`probeCapacity`、`probeAgeSeconds`、`sourceBitrate`、`originalVerdict`、`restoredSamples`。
- `playback_preparing`（主记录）：新增 `originalVerdict`、`renditionCeiling`（内网和旧播放器为 `legacyBudget`）。
- `playback_preparing mode=originalRangeSkipped`：`reason` 新增 `lowerBoundFarBelowSource`；`measuredBandwidthInsufficient` 保留。
- `playback_downshifted`：`capacityBasis` 的 `recentJellyfinProbe` 改为 `routeEvidence`；新增 `liveCapacity`、`routeCapacity`、`routeCapacitySource`。

### 单测

- 模拟器：临时创建的 `Claude-RoutePolicy-20261110` 和 11-11 补做时的 `Claude-RoutePolicy-20261111`（iPhone 17 Pro / iOS 27.0，空白，均已删除）。构建缓存复用今天 Claude 的 `Nastart-Claude-ProxyTiming-20261110`（磁盘只剩约 20 GB，没有另建）。
- 改动前基线：680 项，679 通过，1 失败（已知项）。
- 最终代码（含 11-11 的补做）：689 项，688 通过，同一个已知项失败。新增和改写的 10 项全部通过。
- 中途的一次完整运行里，`NonPlaybackPolicyTests.testDiagnosticErrorFlushesPendingBatchAndClearDoesNotResurrectIt` 失败过一次。它测的是诊断日志必须在 0.5 s 内落盘，被测的 `DiagnosticLogStore` 本批没有改动。单独重跑 25 次失败 1 次，最终运行通过。判断为既有的计时偶发；没有在基线代码上统计它的失败率。
- 新增测试覆盖：证据排序与证伪、探测的两种口径、判定表（含 08:5x、q2、q3 三个实测场景）、起播档位与上限、降档容量、休眠后的老化、重启保留与隐私、短读取不成为估计值、设备文件入口的判定与原谓词逐项相同且档位受上限约束。
- tvOS：`PlaybackPlanningPolicy.swift` 被 tvOS 目标编译。对 tvOS 目标共用的 17 个播放核心文件做了 tvOS 模拟器类型检查，Debug 和 Release 条件下都通过。tvOS 目标自己的源文件不引用本批改动的任何符号。没有做完整的 tvOS 目标构建：它要为 tvOS 重新编 KSPlayer 和 FFmpegKit，磁盘只剩约 19 GB，而上面两项已经覆盖了本批改动能影响到的部分。
- 脚本：新脚本的 6 项测试和 `test_playback_trace_report` 通过。`check_documentation.py` 通过（721 份文档，缺失链接 0）。
- 没有运行：NetworkMedia 包测试、其余 Python 脚本测试。它们的代码本批没有改动。

## 三、真机验证清单

由 Claude 或 Codex 执行。先按 AGENTS.md 核对设备与安装包身份。诊断只保留最近 1000 条，每一步之后立即导出。

需要用户切换网络 2 次：切到蜂窝 1 次，切回 Wi-Fi 1 次。蜂窝场景全部放在同一个窗口里。V9 需要另一个外部 Wi-Fi，可以改天做。

通用判定标准是复算：每条 `routeCapacityEvidence` 记录里的数字决定了判定和档位。用脚本核对导出的诊断文本，有不符记录时退出码为 1：

```sh
python3 scripts/playback_route_decision_report.py 导出.txt
```

脚本按下面的式子计算，也可以手工核对：
- `fits` ⇔ `sourceBitrate` ≤ 1.5 × `capacity`
- `measuredInsufficient` ⇔ 不满足上式，且 `capacityBoundsBothSides=true`
- `explore` ⇔ 不满足第一式，`capacityBoundsBothSides=false`，`renditionLowerBound` 有值且 `sourceBitrate` ≤ 3 × `renditionLowerBound`
- `lowerBoundTooFar` ⇔ 其余有 `capacity` 的情况
- 自动选择 HLS 时，`playback_prepared` 的 `maxBitrate` = 档位表（20、12、10、8、4、2、1.5、1 Mbps…）中不超过 min(`renditionCeiling`, `capacity` / 2) 的最高一档

S19 的源码率是 75.2 Mbps：`fits` 需要 `capacity` ≥ 50.2 Mbps，`explore` 需要 `renditionLowerBound` ≥ 25.1 Mbps。

| # | 场景 | 网络 | 步骤 | 判定标准 |
| --- | --- | --- | --- | --- |
| V1 | 内网回归 | 家中 Wi-Fi，内网地址 | S19 起播、续播、从头，各一次 | 都是原片：`playback_prepared` 的 `mode` 以 `DirectPlay` 结尾，`maxBitrate=unlimitedOriginal`，主记录 `renditionCeiling=legacyBudget`。首帧与此前内网数据同量级（起播约 0.6–0.9 s，续播约 2.5–3.6 s） |
| V2 | 内网降档不变 | 同上 | 续播后若像此前一样自然降档，记录一次 | `playback_downshifted` 的 `fromBitrate=20000000`，`toBitrate` 是低于 20 Mbps、不超过 0.5 × `capacityBitrate` 的最高档（此前两台都是 12 Mbps） |
| V3 | 蜂窝冷起播 | 蜂窝（第 1 次切换后）。距上次蜂窝播放超过 10 分钟 | 新进程，进资料库等测速完成，S19 续播 | `capacitySource=preplayProbe`，`capacityBoundsBothSides=false`，`playbackCapacity=none`，`renditionLowerBound=none`。探测 < 50.2 Mbps 时 `originalVerdict=lowerBoundTooFar`，`mode=originalRangeSkipped`、`reason=lowerBoundFarBelowSource`，走 HLS，档位符合复算式。记录首帧 |
| V4 | 探测过 120 s 后不翻转 | 蜂窝，同一进程 | 正常退出播放，等到距测速超过 130 s（不超过 600 s），续播，再从头播放 | 两次的 `probeAgeSeconds` > 120。路线只由复算式决定：没有因为探测变旧而改走原片。两次判定相同，除非中间的分段下界跨过了 25.1 Mbps |
| V5 | 分段下界规则 | 蜂窝，接 V4 | 看 V4 及之后每次起播的 `renditionLowerBound` | 下界 < 25.1 Mbps：走 HLS，首帧是 HLS 的量级（此前 4–6 s），没有 16.9 s 的原片尝试。下界 ≥ 25.1 Mbps：`explore`，走原片；记录首帧，预期不超过约 15 s |
| V6 | 试探之后 | 蜂窝，出现 `explore` 或 `fits` 时 | 原片播放 30 s 以上，退出，再续播 | 原片撑不住时出现 `automatic_downshift_requested`，`playback_downshifted` 的 `fromBitrate` 等于主记录的 `renditionCeiling`（计费蜂窝是 12000000），`toBitrate` 低于它且不超过 0.5 × min(`liveCapacity`, `routeCapacity`)。下一次起播 `capacitySource=playbackDelivery`、`measuredInsufficient`，不再重复试原片 |
| V7 | 中等码率影片 | 蜂窝 | 选一部 15–40 Mbps 的影片起播 | 判定符合复算式。用它主动覆盖 `fits` 或 `explore` |
| V8 | 重启后一致 | 蜂窝 | 距上一次播放 10 分钟内结束进程，重新启动，S19 续播 | 新进程第一次起播时 `restoredSamples` > 0，且 `playbackCapacity` 或 `renditionLowerBound` 已有值。`originalVerdict` 和档位与重启前最后一次相同（除非新测速让 `fits` 成立） |
| V9 | 公网 Wi-Fi（可选） | 另一个外部 Wi-Fi，走外网域名 | S19 起播两次；一部低码率影片一次 | `capacitySource=preplayProbe` 时 `capacityBoundsBothSides=true`。HLS 档位最高可到 20 Mbps（`capacity` ≥ 40 Mbps 时） |
| V10 | 设备文件入口 | 蜂窝，同一窗口。Jellyfin 外网地址已登录 | 从设备文件进 S19 起播一次 | 匹配成功且 `sourceBitrate` > 1.5 × `probeCapacity` 时：`preview_stream_started` 的 `transport=verifiedJellyfinHLS`，`bitrate` 是不超过 min(12 Mbps, `probeCapacity` / 2) 的最高档。否则走原片，与改动前相同 |

蜂窝窗口里顺带记录 HLS 切音轨和 ±15 s 跳转的耗时，供第四节使用。本批没有改这部分代码。

收尾按 AGENTS.md 的蜂窝规则：停止播放和采集，恢复原 Wi-Fi 并核对状态栏图标。

预期会看到、但不算缺陷的情况：
- 蜂窝冷起播的 HLS 档位仍然偏低（探测 7–8 Mbps 时 2 Mbps）。这是第一节第 9 小节第 1 条的缺口。
- 同一部影片在分段下界跨过 25.1 Mbps 前后，路线从 HLS 变为原片试探。这是规则本身，不是不一致。

## 四、简报 B 节：切音轨、替换源与跳转

只有分析和方案，没有改代码。

### HLS 切音轨约 8 s

耗时构成（蜂窝 HLS，实测）：重新协商 0.35 s，主、子播放列表约 1.0 s，新位置第一个分段首字节 4.2–5.2 s，传输约 0.8 s，解码出帧，然后等当前播放走到候选的起点。

- 首字节 4–5 s 是服务端重启转码：ffmpeg 要先编出一个完整的 4 s 分段。客户端没有办法缩短。分段长度 4 s 是此前为大播放列表定下的，改短会让播放列表变大。
- 候选起点 = 当前位置 + 预备提前量。提前量在进程内第一次是固定的 11 s，之后取上一次实际耗时 + 0.15 s（限制在 3–15 s）。按代码推算，每个进程第一次切轨要多等约 5 s（总计约 12 s），之后约 8 s，与实测的 8.1 s 相符。
- 建议一（小改动，需真机对照）：用本次播放 HLS 起播的实测耗时加余量，给第一次提前量设初值，代替固定的 11 s。11-09 的 11 s 对 6.5 s 对照里，对齐等待确实短了 3.9 s；那次是原片换 HLS，播放列表准备占了 10–14 s，所以总时长没变。HLS 换 HLS 时播放列表只要 1 s，提前量才是可省的部分。但切轨的准备（实测 6–8.6 s）比起播首帧（4–6 s）长，初值必须留余量，估计只能省 2–4 s。初值偏小时候选会迟到，要靠 2 倍速追赶，反而更慢，所以没有真机数据不改。
- 建议二：切轨期间旧流一直在播，用户感到的是"新音轨晚 8 s 生效"。界面给出"正在切换"的状态比继续压缩耗时更划算。

### 切轨后马上跳转（实测约 17 s）

现状：HLS 上的跳转是播放器本地跳转，服务端为**旧音轨**在新位置重启一次转码；跳转同时让切轨候选作废，候选从头重来，服务端为**新音轨**再重启一次。两次转码先后压在 NAS 上。

建议：切轨候选未提交时发生跳转，合并成一次阻塞式替换，直接用新选择在跳转目标处起播。旧流不跳转。`sourceTrackRequestLoader` 本来就按传入的位置起播，所需的件都在。预期从约 17 s 降到约 8 s，服务端转码少一次。需要改 `SharedBuiltInPlayerView` 的跳转入口和 `replaceSource`，没有真机不改。

### 替换源状态机

`replaceSource` 现在用 6 个状态量加若干闭包协调：是否在替换、深度为 1 的待办、选轨去重、是否阻塞播放、替换前是否在播、加载任务。读代码时发现一个缺口：

- 切轨候选准备期间，如果跳转走的是服务端重新协商（本地跳转不可用时的后备路径），待办被跳转占用，选轨不会重试。跳转用的是已提交流的音轨和字幕，用户刚选的轨道被丢掉。本地跳转可用时不会走到这里，所以少见。

建议把协调逻辑抽成一个纯的状态机（状态：空闲、准备中、提交中；事件：选轨、跳转、画质、自动降档、画中画、加载完成、失败），用表写清合并规则，再让视图只执行它给出的动作：

| 进行中 | 新事件 | 结果 |
| --- | --- | --- |
| 选轨 | 选轨 | 取最新的选择 |
| 选轨 | 跳转 | 合并为在跳转目标处、带新选择的一次阻塞式替换 |
| 自动降档 | 任何用户操作 | 用户操作优先，降档放弃，由采样循环之后重新评估 |
| 任何非阻塞替换 | 画中画接管 | 放弃替换 |
| 阻塞式替换 | 选轨 | 排队，替换完成后执行 |

这样上面的缺口和"切轨后跳转"是同一条规则。状态机可以先用单测覆盖，再接线。

2026-11-11 更新：纯逻辑和单测已落地，尚未接线，见 [替换源协调状态机](CLAUDE-2026-11-11-SOURCE-CHANGE-STATE-MACHINE.md)。落地时把上表改成了按"下一条流想要什么"合并请求，并补了换集和暂停归属的规则。

### 大文件原片续播首帧

S19 续播时播放器先串行做 4 次结构读取（头 1 MB、尾 16 KB、头 3 MB、尾部索引 4.8 MB，共约 9 MB），之后才读续播位置。蜂窝 50 Mbps 下这部分约 1.5 s 外加 4 次请求往返；SMB 上约 1.7 s。

- 第二次头部读取与第一次重叠。会话内保留已经交付过的头部和尾部字节，可以省掉一次往返和约 3 MB。
- 跨会话缓存文件结构（按文件身份保存头部和索引）可以让续播、重开都跳过这 9 MB。Jellyfin 的 206 没有 ETag，文件身份要另找依据。
- 两者都是"物化字节"，受"启动预读默认只观察 IO"的约束，应作为单独一批并先用现有的代理计时诊断确认收益。

## 五、简报 C 节：SMB 缓冲

只有分析。依据是读代码加上 [S19 实测](CLAUDE-2026-11-10-S19-PROXY-READER-TIMING.md) 的数字，没有新测量。

### 读取路径

`SMBMediaResource.stream` → `SMBWorker.run` → `SMBConnection.read`：
- 每次只发一个 READ，最多 1 MiB，收完整块才返回。下一次读取要等上一块送进本地套接字之后才发出。这是停等式，线上同一时刻最多一个请求。
- 一次播放一个 `SMBWorker`，一条连接，一个串行队列。播放器的所有 Range 请求共用它。
- 取消的读取有 1.5 s 宽限：快收完的读取会收完，以免跳转后重新登录。
- 强制签名，回包由 libsmb2 的软件实现校验。服务端要求时还会加密。
- `TCP_NODELAY` 已开，轮询在数据可读时立即返回，这两处不是延迟来源。

### 和实测对照

- 稳态 10–11.5 MB/s，每秒约 1000 ms 在等 Reader：相当于每 1 MiB 约 90–100 ms。这段时间里有请求往返、服务端读盘、1 MiB 的传输和签名校验，现有诊断分不开。
- 每个新 Range 的首块延迟 90–300 ms，16 KB 的尾部也要 141 ms。16 KB 的传输时间可以忽略，所以这是等待。最可能的来源是排在上一个 Range 尚未收完的 1 MiB 读取后面（队头阻塞），其次是大文件尾部的磁盘寻道。

### 下一步先测什么

1. 在 `SMBWorker.run` 里记录入队、开始、完成三个时刻，把"排队等待"和"线上读取"分开，按现有的 `readerTimingWindow` 汇总（读取次数、两段时间的合计和最大值）。只加诊断，不改行为。
2. 同一台 iPad、同一窗口里测设备文件（HTTP）原片的无背压交付速率，作为这条 Wi-Fi 链路的参照。

第 1 项已在 11-11 实现，见 [SMB 读取分段计时](CLAUDE-2026-11-11-SMB-READ-TIMING.md)。第 2 项要在设备窗口里做。

### 按结果选方向

| 测量结果 | 含义 | 方向 |
| --- | --- | --- |
| 线上读取时间 ≈ 1 MiB ÷ 链路速率，HTTP 参照也在 90–100 Mbps | 链路本身就这么快，SMB 没有多余开销 | Reader 无可优化；S19 在这条链路上余量本来就小 |
| 线上读取时间明显大于传输时间，HTTP 参照快得多 | 每次请求的固定开销占主导 | 顺序读取时把单次 READ 提到协商上限（通常 8 MiB；现在固定 1 MiB），短 Range 保持小读取。或在同一连接上保持 2 个在途 READ |
| 排队等待占首块延迟的大部分 | 队头阻塞 | 结构读取和跳转探测走第二条连接，或让新 Range 能更快抢占已取消的读取 |

预读策略要等这些数字。只把"读下一块"提前到"送出当前块"的同时，收益很小：实测等播放器套接字的时间每秒只有个位数毫秒。真正的预读需要物化字节，受现有约束，应另批验证。

## 六、需要同步和需要决定的事

需要 Codex 同步到共享文档（本批没有写这些文件）：
- `docs/architecture/VIDEO_PLAYBACK_PIPELINE.md`：路线决策一节改为本文第一节的规则。
- `docs/development/PLAYBACK_OFFLINE_DIAGNOSTICS.md`：新增和改名的诊断字段，以及 `playback_route_decision_report.py` 的用法。`scripts/README.md` 的工具表同样没有加这一项。
- `docs/project/DEVELOPMENT_STATUS.md`、需求总账和矩阵：本批没有关闭任何需求项，全部待真机验证。

需要用户决定：
1. 试探系数 3 是否先按推算值上真机，再按 V5、V6 的数据校准。
2. 第一节第 9 小节第 1 条的三个方向做哪个、先做哪个。它们决定蜂窝冷起播低档的问题能否解决。
3. 第四节的"切轨后跳转合并"和"提前量初值"是否排入下一批。
4. 设备文件入口的播放中降档是否也用 20 Mbps（或网络上限）作包络。现在它从源码率往下降，有单测固定；改了之后内网上的设备文件降档会从最高 20–30 Mbps 变成 12 Mbps，与 Jellyfin 入口一致。
5. 是否允许会话内保留头尾字节（第四节最后一条），这需要放宽"启动预读不物化字节"。
