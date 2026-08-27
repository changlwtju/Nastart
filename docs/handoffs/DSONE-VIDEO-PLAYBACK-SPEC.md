# DS One 视频播放功能完整拆解说明

状态：进行中

日期：2026-08-17

> 2026-08-27 证据基线：本说明的静态模型和真机边界已汇总到[DS One 视频播放链路证据基线](./2026-08-27-DSONE-PLAYBACK-CHAIN-BASELINE.md)。后续新增结论必须区分静态已确认、真机已观察、运行时待补和工具/环境受限。

> PiP 自动化固定流程：DS One 播放器右上角第一按钮负责进入；进入后必须切换到 SpringBoard WDA session，通过系统树的 `恢复全屏幕` 按钮退出。不要在 DS One session 中猜测 PiP 退出坐标。完整命令、元素几何和证据要求见 [真机调试运行手册](./PLAYBACK-DEBUG-RUNBOOK.md) 的“DS One PiP 自动化进入与退出”。

## 1. 目标与边界

本说明只关注 DS One 的视频播放链路，目标是为 Nastart 提炼可验证、可实现的播放能力和策略。

本阶段明确排除：

- 订阅破解、付费状态和授权逻辑
- 外部破解 dylib 的实现细节
- Hook/UI 注入本身
- 绕过 DRM、证书保护或其他安全机制

分析对象优先使用 DS One 2.4.0 IPA 的静态证据，并使用当前 iPhone 上安装的 DS One 2.4.5 进行动态行为验证。2.4.0 与 2.4.5 的差异必须单独记录，不能直接混为同一版本结论。

## 2. 证据等级

- **已确认**：由 Mach-O 依赖、符号、字符串、资源或真机日志直接证明。
- **高概率推断**：多个静态或动态证据相互支持，但尚未定位到实际运行调用点。
- **待验证**：需要 Proxyman/mitmproxy、Instruments、真机屏幕时间点或运行时日志确认。
- **不可得**：IPA 无法提供源代码、服务端内部策略或未触发的运行分支。

## 3. 当前已确认的播放相关组件

### 3.1 系统播放与音视频能力

主程序显式引用：

- AVFoundation
- AVKit
- AVFAudio
- CoreMedia
- VideoToolbox
- Metal / MetalKit

主程序还引用 `AVPlayer`、`AVPlayerItem`、`AVAsset`、`AVPlayerLayer`、`AVPlayerViewController`、`AVPlayerItemAccessLogEvent` 等符号。

### 3.2 KSPlayer/FFmpeg 播放能力

主程序包含 KSPlayer 相关协议和类型线索：

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

包内还包含或引用：

- libmpv
- FFmpeg/libav：avcodec、avformat、avfilter、avutil、swresample、swscale
- libass
- libdav1d
- libdovi
- libplacebo
- libsrt

静态字符串显示 HLS `EXT-X-BYTERANGE`、DASH MPD、字幕轨、seek、cache、preload 等媒体能力。

### 3.3 当前架构模型

当前静态证据支持以下模型，但实际分支仍需真机验证：

```text
视频业务层
  ├─ 媒体 URL / 请求参数 / 播放状态
  ├─ 播放器选择与控制
  └─ 播放进度、错误、后台和远程控制
        │
        ├─ AVFoundation / AVPlayer 路径
        │
        └─ KSPlayer 抽象层
              └─ libmpv + FFmpeg/libav
                    ├─ VideoToolbox 硬件解码
                    ├─ Metal/libplacebo 渲染
                    ├─ 字幕、音轨、HDR/Dolby Vision
                    └─ HLS/DASH/Range/缓存
```

## 3.4 2026-08-18 第二轮静态证据

第二轮没有继续处理订阅破解 dylib，而是直接从主程序的 Swift/Objective-C 元数据中提取视频播放业务对象和字段。

### 播放请求与媒体源模型

主程序包含以下业务对象字段：

```text
PlaybackInfo
  ├─ mediaSources
  ├─ playSessionId
  └─ videoId

MediaSourceInfo
  ├─ mediaProtocol / path / probePath / container
  ├─ isRemote / hasMixedProtocols
  ├─ supportsDirectPlay
  ├─ supportsDirectStream
  ├─ supportsTranscoding
  ├─ bufferMs
  ├─ requiresOpening / openToken / requiresClosing
  ├─ mediaStreams / playableStreamFileNames / formats
  ├─ requiredHttpHeaders
  ├─ directStreamUrl
  ├─ addApiKeyToDirectStreamUrl
  ├─ transcodingUrl / transcodingSubProtocol / transcodingContainer
  ├─ defaultAudioStreamIndex
  └─ defaultSubtitleStreamIndex
```

主程序字符串还出现 `/PlaybackInfo?AutoOpenLiveStream=`，以及 `CurrentPlaySessionId`、`AudioStreamIndex`、`SubtitleStreamIndex`、`MaxStreamingBitrate` 等请求参数。这说明播放前存在“获取 PlaybackInfo → 选择 MediaSource → 选择音轨/字幕/直通或转码 URL”的业务阶段。

### 媒体轨道模型

`MediaStream` 保存了视频、音频和字幕轨道的选择依据，包括 codec、mimeType、language、HDR/色彩、分辨率、帧率、音频采样率、字幕、外部轨道和 delivery URL 等字段。

因此，音轨、字幕、HDR/色彩和编码降级不是单纯由播放器自动决定，业务层至少会参与默认轨道和媒体源选择。

### 播放器实现

主程序同时保留两套 KSPlayer 实现：

- `KSAVPlayer`：包含 `urlAsset`、`periodicTimeObserver`、`mediaPlayerTracks`、`subtitleTracks`、`bufferingProgress`、`playableTime`、`loadState`、`isReadyToPlay`、`playbackState`、`chapters` 和 `naturalSize`。
- `KSMPVPlayer`：包含 `url`、`options`、`tracks`、`duration`、`playbackState` 和画中画控制器。

当前只能确认两套实现都被编译进包内；具体视频走 AVPlayer 还是 MPV，需要通过媒体格式、MediaSource 能力和真机运行轨迹确认。

### 播放选项与性能时间点

`KSOptions` 中存在一组直接对应播放体验的字段：`prepareTime`、`dnsStartTime`、`tcpStartTime`、`tcpConnectedTime`、`openTime`、`findTime`、`readyTime`、`readAudioTime`、`readVideoTime`、`decodeAudioTime`、`decodeVideoTime`、`firstPlayableTime`、`startPlayTime`、`isAccurateSeek`、`seekFlags`、`seekUsePacketCache`、`preferredForwardBufferDuration`、`maxBufferDuration`、`probesize`、`maxAnalyzeDuration`、`nobuffer`、`codecLowDelay`、`syncDecodeAudio` 和 `syncDecodeVideo`。

这表明 DS One/KSPlayer 具备主动采集“网络建立 → 媒体打开 → 可播放 → 首个可播放时间 → 解码”的分段耗时能力。后续应优先检查这些指标是否写入日志或诊断上报，而不是只依赖屏幕录制估算首帧时间。

### 自定义缓存与预加载 IO 层

主程序中发现一组自定义 IO 类型：

```text
CacheIOContext
  ├─ download / urlPos / logicalPos / end / eof
  ├─ entryList / tmpURL
  ├─ saveFile / isReadComplete
  ├─ firstSeekTime / seekOffsets
  └─ isInterleaved / isFirstFileSize

PreLoadIOContext
  ├─ loadMoreBuffer
  └─ fakeUrlPos

LimitPreLoadIOContext
  ├─ maxFileSize
  └─ maxReadedFileSize

LimitCountPreLoadIOContext
  ├─ maxMoreCount
  └─ moreCount

ReadCacheIOContext
  ├─ download / tmpURL
  └─ eof / end / logicalPos
```

这是目前最有价值的播放体验线索：DS One 很可能在播放器和远端文件之间插入了自定义 IO 层，用于管理逻辑文件位置、Range 下载、临时文件、已下载区间、seek 偏移和受限预加载。它不是简单把 URL 交给播放器后完全依赖系统默认缓存。

### 当前静态链路模型

```text
视频入口
  ↓
PlaybackInfo(videoId, playSessionId)
  ↓
MediaSourceInfo 选择
  ├─ DirectPlay
  ├─ DirectStream
  └─ Transcoding
  ↓
MediaStream 选择音轨/字幕/编码/色彩
  ↓
KSOptions 配置缓冲、seek、探测、低延迟和同步策略
  ↓
自定义 CacheIO/PreLoadIO/ReadCacheIO
  ↓
KSAVPlayer 或 KSMPVPlayer
  ↓
VideoToolbox / FFmpeg / libmpv / Metal
  ↓
状态、缓冲、进度和错误回调
```

其中“自定义 IO 层是否对所有视频启用”“AVPlayer/MPV 的选择条件”“预加载大小和触发阈值”仍属于待真机或定向函数分析确认的内容。

### 3.5 2026-08-18 交叉引用与播放控制证据

对 Ghidra 已保存的部分分析结果执行了定向字符串交叉引用导出，并用 Mach-O 反汇编和 Objective-C 元数据复核。得到以下更具体的证据：

- `CacheIOContext`、`PreLoadIOContext`、`LimitPreLoadIOContext`、`LimitCountPreLoadIOContext` 和 `ReadCacheIOContext` 的类/初始化器引用存在；日志字符串明确包含 `ffurl_read2`、`ffurl_seek2`、`reach maxFileSize`、`reach maxReadedFileSize`、缓存数据错误清理和 seek 回退失败。这支持“播放器前面有可限制的自定义 IO/缓存层”，而不是只有类名残留。
- `/PlaybackInfo?AutoOpenLiveStream=`、`CurrentPlaySessionId`、`AudioStreamIndex`、`SubtitleStreamIndex` 位于同一组请求字符串中，说明 PlaybackInfo 请求会携带播放会话和轨道选择参数。是否所有入口都使用同一请求模板仍待运行时确认。
- `PlaybackInfo`、`MediaSourceInfo`、`MediaStream` 的 Codable/元数据字段引用成组出现，且 `supportsDirectPlay`、`supportsDirectStream`、`supportsTranscoding`、`directStreamUrl`、`transcodingUrl`、`bufferMs`、默认音轨/字幕索引均有引用。这进一步支持“媒体源能力判断发生在业务层”的判断，但还不能从 IPA 单独确定优先级算法。
- `KSAVPlayer.swift` 的一处实际代码引用了 `preferredForwardBufferDuration`，并在播放时长/可播放时长变化后更新播放项相关状态；这说明系统播放器路径确实会主动调整前向缓冲，而不是完全使用默认值。具体数值和触发阈值尚未确认。
- `DSVideoKsPlayerViewController` 的 ObjC 暴露方法包含 `reportPlaybackProgress`、`watchingStatusInfoWithCompletionHandler:`、`viewDidLoad`、`skipPiantouAction`、音频路由变化回调和开始/结束时间设置动作；其字段还包含 `cacheNextIOContext`、`isPreloadVideo`、`enablePreLoadNext`、`isLive`、`isTransCode`、音轨/字幕索引。这说明预加载下一视频、播放进度上报、片头跳过、直播/转码状态和音频路由都属于业务控制层的一部分。
- `DSVideoKsPlayerView` 暴露 `onButtonPressed:`、`onPan:` 等交互入口，并保存长按倍速、快速点击、双击、跳过片头、播放时间变化和自然尺寸回调，说明拖动/倍速/片头跳过与播放器状态回调之间存在独立 UI 适配层。
- KSPlayer 侧还保留 `TranscodeProtocol`、`CopyTranscodeContext`、`AudioTranscodeContext`、`SubtitleTranscodeContext` 和 `VideoTranscodeContext` 类型线索。这说明“服务端转码媒体源”进入播放器后，仍可能经过播放器内部按音频/字幕/视频拆分的转码适配层；它不能证明每个转码视频都同时启用三类 context。
- 在已保存分析结果对应的机器码中，`hasSufficientMediaDataForReliablePlaybackStart` 的调用点会读取播放器对象状态并据此继续处理；`preferredForwardBufferDuration` 的调用点位于可播放时长更新附近。两者分别对应首播起播门槛和前向缓冲控制，是比字符串存在更强的播放器状态证据。
- 主程序还保留 `playbackPositionTicks`、`PlaybackPositionTicks` 和 `nextPlaybackInfo` 线索，并包含 SenPlayer、Open-VidHub、Infuse 的 x-callback 播放 URL 模板。因此断点续播、连续播放下一项和外部播放器交接属于播放业务边界，但外部播放器模板不代表默认播放一定会跳出 DS One。

据此，当前最可信的播放控制关系可以细化为：

```text
DSVideoKsPlayerViewController
  ├─ 构造 PlaybackInfo 请求并维护 playSessionId
  ├─ 选择 MediaSourceInfo / MediaStream
  ├─ 决定转码、直播、预加载下一视频和片头跳过状态
  ├─ 创建 KSOptions 与 Cache/PreLoad IO
  ├─ 驱动 KSAVPlayer 或 KSMPVPlayer
  └─ 上报进度、观看状态、错误和音频路由变化
        ↓
DSVideoKsPlayerView
  └─ 手势/控制条/倍速/拖动/片头跳过与时间尺寸回调
```

本节仍不把“存在的备用实现”当作“实际播放必经路径”：2.4.0 IPA 静态结果尚不能证明某一视频一定经过 MPV、某一 Range 大小或某一预加载阈值。

### 3.6 2026-08-26 Ghidra 交叉验证与实现边界

对 2.4.5 脱壳主程序进行了新一轮定向核对。Ghidra headless 导入成功并保存了项目，但自动分析在每文件 300 秒上限处结束，因此本节只采纳已经由多种独立静态来源支持的结论：

- Swift 符号直接暴露 `KSAVPlayer.playableTime`、`bufferingProgress`、`isReadyToPlay`、`mediaPlayerTracks` 和 `KSAVPlayer.io`，说明系统播放器封装自身维护可播放区间、缓冲状态、轨道和输入对象。
- `KSOptions` 直接暴露 `dnsStartTime`、`tcpStartTime`、`tcpConnectedTime`、`findTime`、`readyTime`、`readAudioTime`、`readVideoTime`、`decodeAudioTime`、`decodeVideoTime` 和 `firstPlayableTime`，说明播放链路具备分段耗时观测点；IPA 静态分析不能证明这些指标最终是否上报到服务端。
- ObjC 元数据中的 `CacheIOContext` 保存 `logicalPos`、`bytesRead`、`entryList`、`urlPos`、`tmpURL`、`firstSeekTime`、`seekOffsets`、`isReadComplete` 和 EOF 状态；`LimitSeparatePreLoadIOContext` 还保存 `maxFileSize`、`maxReadedFileSize`、`loadMoreBuffer`、`moreDownload` 和 `moreUrlPos`。这比单独出现类名更能支持“有限窗口 + 缓存区间 + seek 复用”的模型。
- `DSVideoKsPlayerViewController` 元数据保存 `cacheNextIOContext`、`isPreloadVideo`、`enablePreLoadNext`、`isLive`、`isTransCode`、`mediaSources`、`player`、进度/上报定时器和音轨/字幕集合，并暴露进度上报、观看状态和片头跳过相关入口。由此可确认业务控制层覆盖“播放、进度、预加载下一项和观看状态”，但不能据此确定具体预加载阈值。

因此，当前对 Nastart 的实现映射只采用可独立实现的能力：媒体源协商、有限 Range 窗口、可取消/续接的请求、轨道状态保持、起播/卡顿/seek 恢复指标和清晰的降级路径。不会复制 DS One 的私有代码、授权逻辑或未被运行时证实的固定参数。

### 3.7 Nastart 基线核对

在任何 Nastart 源码修改前已执行远端核对：当时本地 `main` 与 GitHub `origin/main` 均为 `197dba40b0a8bc9e7110f456bf591ec1dd3ac152`，双方没有提交差异，也不存在本地落后、超前或分叉。后续播放诊断与 WDA 恢复改动已在 `e759a4507375f018be2174ab9768be438b90abad` 纳入并同步到 `origin/main`；本段历史基线不应再被当作当前 HEAD。

本节结论的含义是“可以在最新源码基线上继续独立实现和验证”，不是 DS One 源码已经恢复，也不是 DS One 2.4.5 的运行时调用顺序已经完全证明。

基于上述证据，Nastart 已先落地一项低风险实现：AVPlayer 路径现在观测
`loadedTimeRanges`，以 0.5 秒变化阈值记录缓冲起点、缓冲终点、前向缓冲秒数、
`isPlaybackBufferEmpty` 和 `isPlaybackLikelyToKeepUp`。该观测只增强诊断，不改变
现有播放器路由、Range 窗口、账户授权或安全校验；后续真机数据可据此决定是否需要
调整起播门槛或卡顿降级阈值。

### 3.8 进一步逆向分析工作流

仅凭 IPA 不能准确给出服务端策略、实际网络时序或每个视频的必经分支。为了继续
降低不确定性，后续按以下证据链推进：

1. **定向静态分析**：以 `DSVideoKsPlayerViewController`、`PlaybackInfo`、
   `MediaSourceInfo`、`CacheIOContext`、`LimitSeparatePreLoadIOContext`、
   `KSAVPlayer` 和 `KSMPVPlayer` 为中心做函数/字符串交叉引用，逐段标记
   `prepare → open → read/seek → ready/first frame → progress/report` 的候选调用点。
2. **运行时黑盒取证**：在同一账号、同一视频、同一网络下记录 DS One 2.4.5 的
   操作时间点、请求顺序、HTTP 状态、`Range`/`Content-Range`、取消/重试、首帧、
   seek 恢复和后台恢复。服务端日志优先于客户端代理推断。
3. **性能交叉验证**：用 Instruments 对 CPU、网络、磁盘、解码、内存和卡顿时间
   进行采样，并与屏幕时间线对齐。动态数据只描述被实际触发的分支，不能外推到
   所有格式或所有账号状态。
4. **独立实现映射**：只有被运行时或多来源静态证据支持的行为才进入 Nastart；
   Nastart 使用自己的请求模型、缓存策略和播放器适配，不复制 DS One 的私有代码。

Frida 仅作为可选的观测工具，范围限定为播放器/网络 API 的调用时序、参数形态和
状态变化；若设备或 App 环境不允许附加，则以 Proxyman/服务端日志/Instruments/
屏幕时间线替代，不通过修改订阅、DRM、证书校验或其他安全逻辑来取得数据。

当前设备条件：Mac 已识别一台已配对的 iPad（可用于 Nastart 真机回归），尚未识别
安装 DS One 2.4.5 的 iPhone。因此当前可以继续静态分析和 Nastart 的本地构建；要
完成 DS One 运行时取证，需让那台 iPhone 在 Xcode/`devicectl` 中显示为可用，并在
测试前保持与 Mac 的稳定连接。

## 4. 需要完整覆盖的播放生命周期

后续分析必须逐项回答以下问题：

### 4.1 播放入口

- 从列表点击、继续观看、外部 URL、分享、后台恢复分别如何进入播放。
- 播放前是否先请求媒体详情、播放授权或媒体元数据。
- 视频 URL 是直接文件 URL、HLS、DASH，还是经过服务端转换。
- 播放器在什么时机初始化，是否提前初始化渲染视图。

### 4.2 媒体探测与轨道选择

- 是否在播放前读取媒体时长、分辨率、编码、帧率和音视频轨道。
- 默认音轨、字幕轨和画质如何选择。
- 多音轨、多字幕、HDR、Dolby Vision、AV1 等能力如何降级。
- 探测阶段是否产生额外 Range 请求。

### 4.3 首帧与预加载

- 点击播放到首个画面的时间。
- 首帧前发生哪些请求，首个 Range 的大小和顺序是什么。
- 是否存在独立的 preload、capacity 或 buffer threshold 策略。
- 首帧后是否立即补充后续数据。

### 4.4 连续播放与缓存

- 请求是否按固定大小、关键帧或播放器自适应策略分段。
- 是否使用本地磁盘缓存、内存缓存或播放器内部缓存。
- 缓存键是否包含 URL、Range、响应头或媒体版本。
- 暂停后恢复是否复用已有缓存。
- 网络变慢时是等待、扩大 Range、重试还是切换路径。

### 4.5 Seek 与拖动

- 拖动过程中是否实时请求，还是松手后才请求。
- seek 是否回退到关键帧。
- seek 前后 Range 请求的区间变化。
- seek 后首帧恢复时间和缓冲恢复时间。
- 连续快速拖动是否取消旧请求。

### 4.6 暂停、后台和恢复

- 锁屏、切后台、来电、耳机和蓝牙路由切换时的行为。
- 后台恢复是否重建播放器或复用原播放器。
- App 从冷启动进入“继续观看”时是否恢复进度和缓存。
- 播放进度何时写入服务端或本地数据库。

### 4.7 错误与降级

- URL 失效、Range 不支持、网络超时、服务端 416、解码失败分别如何处理。
- 是否有重试次数、退避时间和替代请求方式。
- 硬件解码失败时是否切换软件解码。
- 字幕、音轨或 HDR 失败是否影响主视频播放。
- 错误提示和可恢复操作是否分层处理。

### 4.8 播放控制与渲染

- 倍速、全屏、画中画、AirPlay、锁屏控制、音量和亮度。
- 控制栏显隐、方向切换和安全区域处理。
- 视频画面是否使用 AVPlayerLayer、Metal、OpenGL 或自定义渲染层。
- 字幕是在解码器内合成、播放器内合成还是 UI 层覆盖。

## 5. 动态验证矩阵

同一视频、同一账号、同一网络环境下，分别记录 DS One 2.4.5 和 Nastart：

| 场景 | 屏幕时间点 | 网络/Range | 性能轨迹 | 输出结论 |
|---|---|---|---|---|
| 冷启动点击播放 | 待采集 | 待采集 | 待采集 | 首帧链路 |
| 播放 30 秒 | 待采集 | 待采集 | 待采集 | 连续缓冲策略 |
| 暂停 10 秒后恢复 | 待采集 | 待采集 | 待采集 | 缓存复用 |
| 拖动到中段 | 待采集 | 待采集 | 待采集 | seek 策略 |
| 连续快速拖动 | 待采集 | 待采集 | 待采集 | 请求取消/合并 |
| 弱网播放 | 待采集 | 待采集 | 待采集 | 重试/降级 |
| 切后台再恢复 | 待采集 | 待采集 | 待采集 | 生命周期处理 |
| 切换音轨/字幕 | 待采集 | 待采集 | 待采集 | 轨道管理 |
| 播放结束 | 待采集 | 待采集 | 待采集 | 进度保存/下一集 |

## 6. 证据采集方式

### 静态

- Ghidra：主程序的 Swift/Objective-C 函数、调用引用和字符串交叉引用。
- `nm` / `otool`：系统 API、播放器符号、动态依赖和加载路径。
- 资源与配置：媒体 URL 模板、默认参数、播放器选项、字幕和缓存相关键名。

### 网络

- mitmproxy：请求顺序、Range、响应状态、Content-Range、缓存头、重试和取消。
- 服务端日志：作为 Range 和响应行为的权威记录。

### 性能

- Instruments：首帧前 CPU/磁盘/网络活动、解码负载、内存、卡顿和恢复耗时。
- 屏幕录制时间点：把用户动作与网络/性能事件对齐。

## 7. Nastart 最终交付物

本说明完成后应形成：

1. DS One 视频播放链路图。
2. 播放生命周期状态机。
3. 请求/Range/缓存行为表。
4. 首帧、缓冲、seek、恢复和错误处理指标表。
5. DS One 与 Nastart 的差异矩阵。
6. Nastart 的分阶段改造清单和验证用例。

所有结论必须标注版本、证据来源和置信度，避免把 2.4.0 IPA 的静态线索误写成 2.4.5 真机事实。
