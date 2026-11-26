# 2026-11-12 播放策略 T2 · 4G 续播与试探

- iPhone 13（iPhone14,5 / iOS 16.3.1 / USB），13:36–13:43，复核设备、包安装路径、Runner 与原 Wi-Fi。HEAD `8db1cc64`，499 个 iOS 输入无漂移。[T0 普通签名 Debug](CODEX-2026-11-12-PLAYBACK-POLICY-T0.md) dylib `8025285b9141bd85171c012bd083047af66a0c340c4fe4093f8a0d344897d1b0`，主程序 `f1849639f264e1defff99650b4e0837dfd7aedc60c13beaba23fa753269b7e8d`。无测试启动参数。原生 Wi-Fi 关闭，状态栏 4G，未测无线定量指标。公网 Jellyfin 既有会话正常载入，未重新登录。
- S19 片源码率 75,218,094 bps，AC3 2 / PGS 9。每次播放和输入后立即导出，保留原图、诊断及脚本输出。

| 场景 | 判定与证据 |
| --- | --- |
| V3 4G 冷续播 `11B97B0E` | 1 MiB 探测正文 242 ms，`probeCapacity=34655511 capacitySource=preplayProbe capacityBoundsBothSides=false probeAgeSeconds=32 restoredSamples=0`，`playbackCapacity=none renditionLowerBound=none`。2960.041 秒续播，`originalVerdict=lowerBoundTooFar mode=originalRangeSkipped reason=lowerBoundFarBelowSource`，协商 HLS 12 Mbps。内部首帧 7,046 ms，30 秒实图见电影。 |
| V5 上阈值侧、V8 样本恢复 `6E7E223A` | 正常退出后换新进程，在同一 4G 窗口续播。`restoredSamples=16 renditionLowerBound=33616603`，跨过 25.1 Mbps，`originalVerdict=explore mode=jellyfinOriginalDirectPlay`，内部首帧 6,645 ms。重启前首次起播无已采的 HLS 下界，之后新增证据触发路线变化。V8 样本恢复成立，严格重启前后同证据对照尚未完成。 |
| V6 自动降档 `731EC62C` | 原片约 8 秒时发 `automatic_downshift_requested reason=deliveryBelowSourceBitrate`，`fromBitrate=12000000 toBitrate=10000000 liveCapacity=47443892 routeCapacity=47443892`。在候选对齐后实际 `replacement_committed`。候选内部首帧 10,096 ms。原片在 30 秒前即触发自动降档，未人为阻止。 |
| V6 正常重开 `420FD6C8` | `capacitySource=playbackDelivery playbackCapacity=38656662 renditionLowerBound=29020873 probeAgeSeconds=113 originalVerdict=measuredInsufficient`，`reason=measuredBandwidthInsufficient`，直接走 12 Mbps HLS，未再试探原片。内部首帧 7,458 ms。 |
| HLS 前后 15 秒 | 同一 `420FD6C8` 的 AVPlayer，`seekDeltaSeconds=15.0 / -15.0`，均 `seek_engine_completed completed=true` 和 `seek_recovered`。内部时钟恢复 697 / 784 ms。未测 HLS 换音轨。 |

`playback_route_decision_report.py` 最终输出 `4 playback(s) with route evidence, 0 to check.`。自动降档候选在表格的初始档位列留空，实际档位由 `playback_downshifted` 和候选提交记录确认。

V4 两次超龄起播沿用 [此前记录](CODEX-2026-11-12-PLAYBACK-POLICY-T2.md)，本窗没有新增该场景。V7、V10 以及严格配对的 V8 待补。已取得 1 次 `explore`，未达到 T4 样本门槛，无调参或产品代码修改。

13:43:25 正常关闭播放器。13:43:42 核对恢复原 Wi-Fi 的连接勾选和状态栏图标，App、Runner、采集和转发均结束。私有证据从 `/tmp/nastart-codex-playback-device-20261112-current` 进入 `phone/t2-after-public-login/`。
