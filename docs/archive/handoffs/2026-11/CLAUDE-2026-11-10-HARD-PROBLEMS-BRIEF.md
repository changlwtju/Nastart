# 高阶模型任务简报：播放核心难点（2026-11-10，Claude）

用途：只把真正需要深度设计的问题交给更高阶的模型。装包、租用设备、切网络、跑脚本、提取诊断、写文档这类工作，由用户、Claude 或 Codex 照常完成，不占用高阶模型。

## 一、交给高阶模型的核心难点

### A. 播放路线决策模型（最高优先级）

问题：容量证据不确定时，决定播原片（KSPlayer + `localRangeProxy`）还是服务端 HLS（AVPlayer + `localHLS`），以及 HLS 选哪个码率档。现有规则是一次次补丁叠起来的，没有统一的模型。

已知的证据类型及其偏差：

| 证据 | 来源 | 偏差 |
|---|---|---|
| 播放前探测 | `measureMaximumBitrate`；蜂窝取 1 MB，结果 120 s 内复用 | 新建 TLS 连接受慢启动影响，可能低估好几倍（实测 7.7 Mbps，而播放时实际交付 48 Mbps） |
| 原片交付 | `PlaybackRecentThroughputStore.record` 加 body window；按路线取中位数，保留 600 s，最多 16 条 | 最接近真实容量；只在进程内存里，App 重启就丢 |
| HLS 分段交付 | `record(isServerRendition: true)` → `routeLowerBound` | 受码率档和转码速度限制，只能当下界 |
| 播放中按 trace 的估计 | `estimateSample` | 用于播放中回退 |

当前规则在 `PlaybackRouteCapacityPolicy.effective`：
- 有直接证据时，取 max(直接证据, 下界)；
- 只有探测值时，取 max(探测值, 下界)；
- 只有下界时，视为容量未知。

判定原片播不动用 `isOriginalClearlyUnsustainable`：源码率 > 1.5 × 容量。HLS 档位用 `target`：取 0.5 × 容量，再向下对齐到档位表。

需要权衡的几个目标：
1. 起播、续播、从头播放在同一路线上要选得一致；
2. 不能被低估的证据长期锁在低画质；
3. 首帧延迟：只剩下界时会先试一次原片，S19 实测出首帧要 16.9 s，之后又立即回退；
4. 网络真正变好时要能回到原片。

待决定：只剩下界、且源码率超过下界 3 倍时，是否跳过原片直接选 HLS（Claude 建议这样做，但需要从整体模型出发论证）。另一个待决定的问题：路线证据要不要持久化到 App 重启之后。

### B. 起播首帧、切音轨字幕、跳转的响应

- HLS 切音轨会让服务端重启转码：拿到第一字节要 4.2–5.2 s，之后还要对齐，总共约 8 s。需要判断能否预热、复用会话或换策略。
- 替换源的预热（`GreenfieldAVPlayerWarmup.prepare`）在跳转时会因 `seekGeneration` 变化而作废。目前已补"跳转后重试切轨"（`shouldRetryAfterSeek`），但整套替换流程的状态机仍偏复杂。
- 大文件原片（S19：128.8 GB、75 Mbps）续播时的首帧时间。

### C. SMB 与本地代理的缓冲

iPad 上走 SMB 时会卡顿缓冲。目前已有计时诊断，能区分"读取慢"和"播放器消费慢"（`NetworkMediaProxyTransfer`，[DevicesView.swift:4199](../../../../ios/Nastart/Nastart/Features/Devices/DevicesView.swift)）。但还没区分是队列等待还是网络本身慢，也还没形成预读策略。约束：启动预读默认只观察 IO，不物化字节。

## 二、不交给高阶模型的事（前置条件由其他人完成）

| 事项 | 负责人 | 现状 |
|---|---|---|
| 切换 Wi-Fi / 蜂窝 | 用户 | 每轮测试只切一次，Claude 提前通知 |
| 输入 Jellyfin 密码、TMDB 令牌 | 用户 | 不读取 Keychain，不猜测、不重复密码 |
| NAS、Docker、硬盘维护 | 用户 | NAS 只读，不重启任何服务 |
| 构建签名包、保留数据装机、租用设备 | Claude / Codex | 当前 iPhone 13 上是 dylib `9e7b0944…`，描述文件到 11-15 08:30+08 |
| WDA 场景脚本、诊断提取、单测运行、写交接 | Claude / Codex | 脚本在私有证据目录 `phone/sample-iphone13/`（`celltest4.py` 等） |

## 三、交付给高阶模型的输入

- 代码位置：
  - [PlaybackPlanningPolicy.swift](../../../../ios/Nastart/Nastart/Playback/Core/PlaybackPlanningPolicy.swift)：`PlaybackRouteCapacityPolicy` 在 648 行，`PlaybackRecentThroughputStore` 在 663 行，`PlaybackAdaptiveBitratePolicy` 在 806 行；
  - [LaunchpadView.swift](../../../../ios/Nastart/Nastart/Features/Launchpad/LaunchpadView.swift)：起播决策在 7600 行附近，`adaptiveFallbackRequest` 在 8353 行，`playbackBitrateDecision` 在 8711 行；
  - [GreenfieldVideoPlayerView.swift](../../../../ios/Nastart/Nastart/Playback/GreenfieldVideoPlayerView.swift)：`replaceSource` 在 652 行。
- 实测数据：[S19 代理计时与蜂窝复测](CLAUDE-2026-11-10-S19-PROXY-READER-TIMING.md)，含 Wi-Fi 与蜂窝的首帧、切轨、跳转表格，以及 20:2x 的三次续播表。
- 约束：
  - 播放链路按网络环境统一，FTP/SMB 只在局域网使用；
  - 原片探测不创建代理、不打开解码器；
  - 内网 / 局域网优先播原片；
  - 公网自动 HLS 上限 20 Mbps。
- 验证手段：模拟器单测（`PlaybackNextCoreTests`、`NonPlaybackPolicyTests`），加上真机脚本场景（Claude 或 Codex 执行）。

## 四、期望的产出

1. 一份统一的路线决策模型：明确证据的语义、合并规则、失效规则和一致性保证，并逐条回答 A 节的四个权衡目标。
2. 按这个模型重写或收敛相关代码，附带单测。
3. 一份真机验证清单（场景、每个场景切几次网络、判定标准），由 Claude 或 Codex 执行。
