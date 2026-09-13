# Jellyfin 原画链路统一与杜比能力识别

用户授权：按设备文件入口的链路优化 Jellyfin 新架构播放，同时考虑 Dolby Vision / Dolby Atmos。仅调整 Greenfield 持续优化主线，清晰度档位继续由 Jellyfin 提供。

## 行为变化

1. 自动原画按已链接 KSPlayer 的音频解码能力判断，保留用户/默认音轨；TrueHD、FLAC 不再继承其他引擎的转码限制。未知编码仍需兼容处理；只有缺失编码元数据时让解复用器继续识别。实验选流分支的原有范围保留。
2. 设备文件初播/兼容代理与 Jellyfin 初播/切回原画共用 `registerOriginalStream`。对上游按 32 MiB 窗口读取，对播放器的开放 Range 请求返回带 Content-Length 的连续 206，避免初播、证书代理和清晰度切换混用不同响应模式。代理注册失败仍保留已有直连退路。
3. 非私网大 MKV 仅在实测 Wi-Fi 安全码率足够时解除体积门槛；蜂窝、受限、未知网络及测速失败保留保护。失败测速缓存标明 `measurementFailed`，不冒充实测带宽。
4. 新架构首次播放对共享测速最多等待约 800 ms（正常调度条件），超时使用保守网络预算，测速继续在后台供后续决策使用。旧架构继续等待原有测速任务。此取舍可能让首次公网大视频在尚无有效测速时进入较低码率 HLS；不会在播放中偷偷自动换流。
5. 正常证书的 Jellyfin SRT 交给已有字幕覆盖层异步读取和清理 ASS 文本样式，不再在打开原画前重复下载整个字幕。自签名来源保留原有证书感知的归一化路径。
6. 明确选择较低清晰度仍强制 Jellyfin 转码。显式原画请求如果不满足解码/字幕条件或找不到有效原流，返回失败，由候选交接逻辑保留旧流，不再把新的转码流显示成原画。
7. 新增源 DV Profile/Level/基础层、音频 Profile/AudioSpatialFormat/JOC 识别与实际 KS 轨道诊断。实际 Dolby Vision/Atmos 输出均保持未验证；没有加入未经验证的原生音频输出或重封装分支。详见 [杜比路线](../project/DOLBY_PLAYBACK_ROADMAP.md)。

## 验证

- 最终 `PlaybackNextCoreTests`：32 项通过。新增自动原画解码能力与显式清晰度约束、实测 Wi-Fi 大文件边界、源杜比信息与输出分离、真实 HTTP 跨 32 MiB 窗口/反向 Range、远端双语 SRT 覆盖层加载测试。既有 AV/KS 实际视频预热与定位测试同轮通过。
- `bash scripts/preflight.sh` 通过；测速静态规则更新为有上限等待及保守失败缓存。
- iOS 设备 Debug 构建成功（generic iOS，未签名/未安装）；最终设备包通过 FFmpeg/KSPlayer/VLC 链接隔离检查。模拟器包的链接隔离检查也通过。
- 原有用户工作区改动（Package.resolved 删除及 KSPlayer 未跟踪附属文件）未纳入本次修改。

本机最终日志：`/tmp/nastart-original-dolby-spatial-tests.log`、`/tmp/nastart-original-dolby-device-spatial-build.log`；最终测试结果 `/tmp/NastartGreenfieldABSimulatorDerived/Logs/Test/Test-Nastart-2026.09.10_19-24-20-+0800.xcresult`，xcresulttool 确认 32 passed / 0 failed / 0 skipped。设备构建先后遇到旧 DerivedData 缺失 FFmpegKit checkout、旧 PCM 缓存丢失；使用已通过模拟器构建的依赖缓存及新的 `/tmp/NastartOriginalDolbyDeviceDerived` 构建目录后成功，未修改项目依赖声明。失败构建日志保留。

## 真机边界与下一轮

19:26 前仅依据 CoreDevice 的 unavailable 错判 iPhone 离线，因此当时未安装。用户纠正后，usbmux、配对、设备信息和 ios-deploy 四项交叉检查确认 iPhone 13 / iOS 16.3.1 已通过 USB 连接；19:28 复用已安装的 WDA，XCTest / iproxy 取得 ready。应区分工具状态与物理连接，后续不得只用 devicectl 判定该设备离线。已开始覆盖安装和真机验证，结果在后续记录中补充；未取得同条件对照前不宣称性能提升百分比。

固定同一物理文件、网络、音轨、字幕、起点和清晰度，对照设备文件与 Jellyfin 自动/原画；分别测从头播放、断点续播、±15 秒和远距离未缓存 seek。单列 HLS 20→12→20 Mbps、原画往返，以及切换后的暂停/恢复、音字幕、PiP/退出续播。关键日志：`bandwidthWait`、`sourceCapabilities`、`proxy_transfer_started.clientResponse=continuousRange`、既有首帧提交与 seek 恢复事件。播放时钟推进/渲染器提交不冒充屏幕实际呈现。

清晰度服务端首分片生成延迟仍需真机与 NAS 同时间线测量；此次统一原画读取方式不会消除转码成本。杜比真机矩阵需分别覆盖 DV P5/P8/P7、普通 DD+、明确 JOC 与 TrueHD Atmos，并取得输出端证据。

## 9 月 10 日晚真机补录（9 月 11 日合并日志核对）

最终设备包已签名并通过 USB 覆盖安装到 iPhone 13 / iOS 16.3.1。上文“未签名/未安装”描述的是此前 generic build 阶段，不是最终安装状态。

合并 `tmp/playback-20260908/evening-*-diagnostics.json` 的 date >= 810733056 记录，按 date/messageKey/detail 去重得到 1587 条。不能只用最后一次导出：诊断环形缓冲会淘汰启动记录。样本为《碟中谍 3》约 54 GB、63 Mbps、HEVC / TrueHD；手机使用 Wi-Fi，通过 HTTPS 域名端点读取，不能当作蜂窝验收。

| 项目 | 观测值 | 口径 |
| --- | --- | --- |
| Jellyfin 自动原画测速等待 | 547 ms | 初播关键路径实际等待 |
| 自动原画首帧事件 | 3005 ms | 播放时钟推进信号；不是屏幕呈现测量 |
| 原画前进 / 后退 15 秒 | 124 / 63 ms | 引擎完成与时钟恢复；未证明未缓存远距离 seek |
| 原画 → 20 Mbps HLS | 15.09 s | 候选预热开始到交接提交，未计此前请求准备 |
| HLS 20 → 12 / 12 → 20 Mbps | 6.02 / 3.85 s | 同上；旧流预热期间继续播放 |
| 暂停时 HLS → 原画 | 2.04 s | 交接后仍暂停在原位置 |

上述为单次探索性记录，尚无同条件设备文件 A/B 数据，不能据此宣称两个入口已经同速。切回原画后因人为暂停记录到的 15379 ms 首帧事件不可作为启动性能数据。

音轨切换前后全屏双语字幕、关闭/恢复字幕已通过截图检查。画中画已启动并持续送帧，但 HDR 原画的 PiP 字幕未合成：现有合成器遇到 PQ/HLG 主动跳过，以避免降为 8-bit SDR。桌面稳定呈现、返回全屏及退出续播尚未完整验收；后续 UI 会话曾被设备锁屏阻断，USB 连接仍在线。未取得用户听音确认，不能用 Speaker/decodedPCM 日志代替声音或 Atmos 验收。

用户 9 月 11 日要求基础播放速度优先，下一阶段执行方向见 [播放体验优先级](../project/PLAYBACK_EXPERIENCE_PRIORITIES.md)。
