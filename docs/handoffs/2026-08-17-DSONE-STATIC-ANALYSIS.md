# DS One 2.4.0 静态分析阶段记录

日期：2026-08-17

## 分析范围

- IPA：`DSOne_2.4.0_𝐶𝑟𝑎𝑐𝑘_𝑌𝑄𝐶.ipa`
- 外部动态库：`🄷🅆 DS Cloud.dylib`
- 目标：为 Nastart 播放体验改进提取可验证的播放器、缓存、网络和解码线索。
- 本阶段仅做只读静态分析，没有运行 IPA，也没有执行任何 dylib。

## 工具状态

- Ghidra 12.1.2：已安装并导入主程序、内置 Hook 和外部 dylib。
- mitmproxy 12.2.3：已安装。
- Frida CLI 14.10.4：已通过 pipx 安装。
- Xcode/Instruments、ios-deploy：已有并验证可用。
- Ghidra 项目：`/tmp/dsone-analysis.mVOkIC/ghidra-project/DSOneStatic`

## 已确认事实

### 应用基本信息

- Bundle ID：`com.cz.DSCloudStorage`
- 版本：`2.4.0`，Build `8`
- 最低系统：iOS 15.0
- 主程序架构：arm64
- IPA 包体约 260 MB
- 主程序显式依赖 AVFoundation、AVKit、AVFAudio、VideoToolbox、CoreMedia、Metal 和 MetalKit。
- 主程序引用 `AVPlayer`、`AVPlayerItem`、`AVAsset`、`AVPlayerLayer`、`AVPlayerViewController`、`AVPlayerItemAccessLogEvent` 等符号。

### 播放器相关组件

包内存在 KSPlayer 相关协议/类型字符串，包括：

- `MediaPlayerProtocol`
- `MediaPlayback`
- `VideoPipeline`
- `VideoOutput`
- `AudioOutput`
- `PreLoadProtocol`
- `CapacityProtocol`
- `DownloadProtocol`
- `CacheEntryProtocol`
- `MovieStream`
- `PlayerControllerDelegate`
- `MediaPlayerTrack`
- `SubtitleInfo`

同时发现 libmpv/FFmpeg 相关内容：

- `libmpv`，字符串中显示基于 libmpv 0.40.0 构建。
- FFmpeg/libav 组件：avcodec、avformat、avfilter、avutil、swresample、swscale。
- `libplacebo`、`libdav1d`、`libdovi`、`libass`、`libsrt` 等组件。
- 存在 HLS `EXT-X-BYTERANGE`、DASH MPD、字幕轨、seek、cache、preload 等媒体能力字符串。

### Hook 与外部 dylib

IPA 内的 `DSCloudH00k.dylib`：

- 依赖 MobileSubstrate 风格的 `MSHookMessageEx`。
- 暴露类 `YQCDIView`，方法集中在浮层、手势、动画、震动和打开 URL。
- 静态证据暂未显示它是播放器或 Range 下载核心。

外部提供的 `🄷🅆 DS Cloud.dylib`：

- arm64，未设置 Team Identifier，标识为 unsigned。
- 依赖 CydiaSubstrate、UIKit、WebKit。
- 暴露类 `MyViewController`，包含 `WKWebView`、拖拽手势、临时窗口和脚本消息处理。
- 静态证据更像 UI/WebView 注入插件，暂未发现 AVPlayer、KSPlayer、FFmpeg 或 Range 处理符号。
- 它与 IPA 内的 `DSCloudH00k.dylib` 不是同一个二进制，不能直接视为播放链路实现。

## 当前播放链路判断

目前可以确认 DS One 具备至少两层播放能力：

```text
应用业务/播放控制层
        ├─ AVFoundation / AVPlayer 路径
        └─ KSPlayer 抽象层
              └─ libmpv + FFmpeg/libav
                    ├─ VideoToolbox 硬件解码
                    ├─ Metal/libplacebo 渲染
                    ├─ 字幕、音轨、HDR/Dolby Vision
                    └─ HLS/DASH/Range/缓存能力
```

这是静态证据支持的架构模型，不等于已经确认某个具体视频实际走哪条路径。要确认 2.4.5 真机上的实际路径，还需要把同一视频的操作时间点、HTTP Range、首帧时间、seek 后恢复时间和缓冲行为进行动态对齐。

## 对 Nastart 的直接启示

第一优先级不是复制 DS One 的 UI，而是验证以下能力是否缺失：

1. 是否有独立的预加载/容量判断，而不是只依赖播放器默认缓冲。
2. 是否使用 Range 分段读取与可复用缓存。
3. seek 时是否采用精确 seek、关键帧回退和恢复预缓冲。
4. 是否把音频、字幕、轨道和硬件解码能力交给成熟播放内核处理。
5. 是否在首帧前提前完成媒体探测、轨道选择和渲染资源准备。

## 2026-08-18 定向分析新增证据

第二轮分析直接读取主程序的类元数据和媒体相关字符串，确认了比“包含 KSPlayer/FFmpeg”更具体的业务结构：

- `PlaybackInfo` 持有 `mediaSources`、`playSessionId`、`videoId`。
- `MediaSourceInfo` 持有 `supportsDirectPlay`、`supportsDirectStream`、`supportsTranscoding`、`bufferMs`、`requiredHttpHeaders`、`directStreamUrl`、`transcodingUrl`、`defaultAudioStreamIndex`、`defaultSubtitleStreamIndex` 等字段。
- `MediaStream` 持有 codec、mimeType、language、HDR/色彩、分辨率、帧率、音频采样率、字幕和外部轨道信息。
- `DSVideoKsPlayerViewController` 持有 `cacheNextIOContext`、`isPreloadVideo`、`enablePreLoadNext`、`player`、`isLive`、`isTransCode`、音轨/字幕选择和字幕文件集合。
- `KSOptions` 持有 DNS/TCP/打开/探测/就绪/解码/首个可播放时间点，以及 `seekUsePacketCache`、`preferredForwardBufferDuration`、`maxBufferDuration`、`probesize`、`maxAnalyzeDuration`、`nobuffer`、同步解码等配置。
- `CacheIOContext`、`PreLoadIOContext`、`LimitPreLoadIOContext`、`LimitCountPreLoadIOContext`、`ReadCacheIOContext` 组成了独立的缓存/预加载/逻辑文件位置管理层。

定向交叉引用还直接命中了以下运行日志/配置证据：

- 自定义 IO 层调用链附近保留 `ffurl_read2`、`ffurl_seek2`、缓存数据错误清理、`reach maxFileSize` 和 `reach maxReadedFileSize` 文本；这是缓存/Range/seek 行为的强证据。
- `KSAVPlayer.swift` 代码引用 `preferredForwardBufferDuration`，并处于播放项可播放时长更新逻辑附近；这是主动设置系统前向缓冲的强证据，但数值和阈值仍未知。
- `DSVideoKsPlayerViewController` 元数据确认 `reportPlaybackProgress`、`watchingStatusInfoWithCompletionHandler:`、`cacheNextIOContext`、`isPreloadVideo`、`enablePreLoadNext`、`isLive` 和 `isTransCode` 同时存在，说明播放业务层覆盖进度上报、观看状态、下一视频预加载、直播与转码分支。
- KSPlayer 侧另有 `TranscodeProtocol`、`CopyTranscodeContext`、`AudioTranscodeContext`、`SubtitleTranscodeContext` 和 `VideoTranscodeContext` 类型线索，表明转码流可能在播放器内部继续做分轨适配。
- `hasSufficientMediaDataForReliablePlaybackStart` 和 `preferredForwardBufferDuration` 已从字符串引用进一步落到实际机器码调用点，分别对应可靠起播判断和前向缓冲更新；仍不能仅凭静态结果得出实际阈值。
- 主程序还保留 `playbackPositionTicks`、`PlaybackPositionTicks`、`nextPlaybackInfo` 以及 SenPlayer/Open-VidHub/Infuse 的 x-callback 模板，说明断点续播、连续下一项和外部播放器交接需要纳入完整播放功能边界。

上述引用来自 2.4.0 主程序的已保存 Ghidra 项目与 Mach-O 元数据，尚未等价于 2.4.5 真机的实际执行轨迹。

这组证据把当前播放链路从“可能使用 KSPlayer”提升为：业务层先取得播放源和轨道，再配置 KSPlayer，并通过自定义 Cache/PreLoad IO 层提供数据给 AVPlayer 或 MPV 播放器实现。具体条件仍需动态验证。

## 下一步

1. 对主程序的 KSPlayer、AVPlayer、Range、cache、preload 相关交叉引用做定向 Ghidra/Hopper 分析。
2. 使用 mitmproxy 记录 DS One 2.4.5 播放同一视频时的请求和响应头。
3. 用 Instruments 记录 DS One/Nastart 的首帧、缓冲、seek 和恢复时间。
4. 形成“静态证据 + 动态证据 + Nastart 改造项”的播放链路矩阵。

## 超时处理方案

主程序的默认分析超时不是硬性失败。Ghidra 会保存已经完成的分析器结果；当前已从既有项目恢复主程序分析，并将单文件超时提高到 1200 秒，同时限制并发 CPU，避免重新导入。

后续采用分层策略：

1. 主程序单独长时分析，重点保留 Swift、Objective-C、函数入口、调用引用和字符串索引。
2. 内置 Hook 单独分析，不让主程序的 62MB 大型代码段影响 Hook 定位。
3. 外部 dylib 单独分析；它的类和方法规模较小，已完成函数级分析。
4. 不对包内所有第三方框架做完整反编译，只对主程序中指向 KSPlayer、AVPlayer、VideoToolbox、Range、cache 和 preload 的引用做交叉分析。
5. 对 Ghidra 无法处理的 Objective-C 类型编码保留原始符号，并使用 `nm`、`otool`、字符串和 Hopper/Ghidra GUI 交叉验证。

“更全面”不等于把每个 FFmpeg 函数都反编译一遍。对于 Nastart，真正有价值的是确认业务层如何创建媒体 URL、如何选择播放器、何时预加载、如何处理 Range/cache、何时 seek 和恢复；这些必须与 DS One 2.4.5 真机上的网络与性能轨迹结合验证。

本记录只用于在有权分析的文件、设备和账号范围内进行兼容性与体验研究，不包含绕过 DRM 或其他安全保护的步骤。

## 2026-08-18：2.4.5 脱壳 IPA 版本差异分析

用户提供的 `/Users/lagransun/Downloads/DS One-2.4.5.ipa` 已单独解包并核对：Bundle ID 为 `com.cz.DSCloudStorage`，版本 `2.4.5`、Build `4`，主程序 arm64 且 `cryptid 0`。与 2.4.0 对比，2.4.5 新增 `LimitSeparatePreLoadIOContext`、`BSFTranscodeContext`、`isRangeUncached(start:end:)`、`performSeek(time:flags:)`、`preferredRange` 和缓冲容量相关字段；`KSAVPlayer` 的 `io` 类型为 `Either<URL, AVAsset>`，缓存/预加载和播放控制器字段也发生结构变化。

详见：[DS One 2.4.5 播放链路静态差异分析](</Users/lagransun/workspace/Nastart/docs/handoffs/2026-08-18-DSONE-2.4.5-STATIC-DIFF.md>)。

2.4.5 的 Ghidra 主程序分析在 1200 秒单文件上限后保存成功；后续定向交叉引用命中了 `preferredRange`、`setPreferredRange:`、`bufferMiss`、`maxBufferCount`、`maxBufferSize`、`clearBufferWhenStopped`、`handlePlaybackStateChange` 和 `updatePlaybackProgress` 的实际函数引用。`isRangeUncached(start:end:)`、`performSeek(time:flags:)` 则确认存在于播放模块实现线索中，但未在当前部分分析中解析出调用者。

## 2026-08-27：iPhone WDA 已恢复并固化，可继续做 DS One 动态播放分析

用户解锁 iPhone 后，使用已安装的兼容 WDA 包和精确 iOS 16.3 DeviceSupport 重新建立 XCTest 通道。此次不是推测：

1. `ideviceimagemounter list` 返回开发者镜像 `Status: Complete`，DVT 可以读取设备端 XCTest/XCUIAutomation 框架。
2. `tidevice xcuitest -B com.changliwen.nastart.WebDriverAgentRunner.xctrunner -e USE_PORT:8100` 成功启动 WDA。
3. `iproxy 8102:8100 -u 00008110-001E543122E0401E` 后，`GET /status` 返回 `ready: true`、设备 iOS `16.3.1`、WDA `16.8.0`。
4. `POST /session` 成功为 `com.cz.DSCloudStorage` 建立 session；随后 `/source` 返回 XCUI XML，`/screenshot` 返回 1170×2532 PNG。

可复用的包和凭据已经保存到：`/Users/lagransun/Library/Application Support/Nastart/WDA/iPhone-16.3.1`。项目脚本入口为 `scripts/install_wda_iphone_once.sh`、`scripts/start_wda_iphone.sh` 和 `scripts/prepare_wda_recovery.sh`；以后先校验 receipt 和 `/status`，不要重复构建或安装。

这解决的是动态采集工具链，不等于 DS One 播放链路已经被完整还原。下一阶段可以在不绕过 DRM/订阅保护的前提下，使用 WDA 对同一视频执行可重复操作，并把操作时间点与 HTTP Range、播放器日志和首帧/seek 时间对齐，继续验证 2.4.5 的缓存、预加载、转码和 seek 分支。

PiP 动态操作的固定方法已补充到[真机调试运行手册](./PLAYBACK-DEBUG-RUNBOOK.md)：进入使用 DS One 播放器右上角第一按钮；退出时切换到 SpringBoard WDA session，在 `PIP-SBInteractionPassThroughView` 控件树中点击 `恢复全屏幕`。该方法已在 S03《碟中谍3》上自动化验证，不能用 Home 或重新启动 DS One 替代退出按钮验收。
