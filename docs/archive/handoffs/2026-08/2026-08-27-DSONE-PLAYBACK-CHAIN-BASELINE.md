# DS One 视频播放链路证据基线

日期：2026-08-27  
对象：DS One 2.4.0 / 2.4.5，重点为 2.4.5 Build 4
范围：合法取得的 IPA、已授权账号入口、当前 iPhone 真机和可取得的网络/系统证据

## 1. 结论摘要

目前可以建立一条有证据分层的播放链路：

```text
Jellyfin / DSM 文件入口
  ↓
PlaybackInfo / 媒体文件信息
  ↓
MediaSourceInfo + MediaStream
  ├─ Direct Play
  ├─ Direct Stream
  └─ 服务端或播放器侧转码/分轨适配
  ↓
DSVideoKsPlayerViewController
  ├─ 轨道选择、播放状态、进度上报
  ├─ 断点、片头跳过、下一项预加载
  └─ AVPlayer 或 KSPlayer 播放器实现
        ├─ KSAVPlayer → AVPlayer / AVAsset
        └─ KSMPVPlayer → libmpv / FFmpeg
  ↓
自定义 Cache/PreLoad/ReadCache IO
  ├─ 逻辑文件位置和 EOF
  ├─ Range 缺口、seek 和缓存复用
  └─ 有限预加载/独立预加载
  ↓
VideoToolbox / Metal / libplacebo / libass / 音频与 HDR/DV 处理

PiP 分支（播放中进入后台时）
  KSAVPlayer/KSMPVPlayer + 视频渲染/采样源
    ↓
  KSPictureInPictureController
    （静态元数据：AVPictureInPictureController 子类）
    ↓
  AVPictureInPictureControllerDelegate /
  AVPictureInPictureSampleBufferPlaybackDelegate
    + AVDelegatingPlaybackCoordinator 的 play/pause/seek/buffering command
    ↓
  iOS SpringBoard PiP 窗口（PIPUIView / PIP-SBInteractionPassThroughView）
    ↓
  PiP 控件继续驱动同一播放状态，恢复全屏时回到播放器
```

这张图中，业务对象、播放器实现、自定义 IO 和解码组件由静态证据确认；S01 Jellyfin、S03 Jellyfin 和 S18 DSM 已在 iPhone 上取得真实播放画面，S03 的 PiP 自动进入和自动恢复全屏也已动态确认。当前仍不能声称：某个样本实际必经 AVPlayer 或 MPV、实际 Range 窗口大小、缓冲阈值、音频听测或所有控制项通过。

## 2. 证据等级和边界

| 等级 | 判定规则 | 本文用法 |
|---|---|---|
| 静态已确认 | IPA 的 Mach-O、Swift/ObjC 元数据、符号、字符串或定向交叉引用直接支持 | “存在该组件/能力/业务对象” |
| 真机已观察 | 同一设备、同一入口、同一视频出现可重复的屏幕或系统行为 | “该入口实际出现了该行为” |
| 运行时待补 | 需要 HTTP 请求、播放器内部日志、Instruments 或音频听测 | 不把推断写成事实 |
| 工具/环境受限 | 采集工具失败或入口不可达 | 记录为 `TOOL`/`NA`，不判定播放器失败 |

静态出现 `Range`、`PiP`、`Audio` 或 `Subtitle` 只能证明代码具备相关能力，不能证明当前视频、入口或时刻实际触发了该分支。

## 3. 静态拆解

### 3.1 入口和媒体源协商

2.4.0 和 2.4.5 均存在以下业务模型：

```text
PlaybackInfo
  ├─ mediaSources
  ├─ playSessionId
  └─ videoId

MediaSourceInfo
  ├─ supportsDirectPlay / supportsDirectStream / supportsTranscoding
  ├─ directStreamUrl / transcodingUrl
  ├─ requiredHttpHeaders / bufferMs
  ├─ defaultAudioStreamIndex
  └─ defaultSubtitleStreamIndex

MediaStream
  ├─ codec / mimeType / language
  ├─ resolution / frame rate / audio sample rate
  ├─ HDR / color / subtitle / external delivery information
  └─ audio/video/subtitle stream index
```

2.4.5 还保留了 `/PlaybackInfo?AutoOpenLiveStream=true&IsPlayback=true&UserId=` 形式的请求线索，以及 `CurrentPlaySessionId`、`AudioStreamIndex`、`SubtitleStreamIndex` 和 `MaxStreamingBitrate` 等参数线索。是否 Jellyfin 和 DSM 都使用完全相同的请求模板，仍须运行时请求日志确认。

### 3.2 播放器和渲染层

- `KSAVPlayer`：静态字段包含 `playableTime`、`bufferingProgress`、`isReadyToPlay`、轨道、字幕、自然尺寸和播放状态；2.4.5 的输入抽象为 `Either<URL, AVAsset>`。
- `KSMPVPlayer`：静态字段包含 URL、options、tracks、duration、playbackState 和画中画控制器，底层关联 libmpv/FFmpeg。
- 系统能力：AVFoundation、AVKit、AVFAudio、CoreMedia、VideoToolbox、Metal/MetalKit。
- 媒体组件：libmpv 0.40（2.4.0）到 0.41（2.4.5）的字符串线索，FFmpeg/libav、libplacebo、libdav1d、libdovi、libass 和 libsrt。

因此“DS One 同时具备 AVPlayer 和 MPV 能力”是已确认事实；“某个具体入口使用哪一个”不是静态分析可以单独回答的问题。

### 3.3 自定义 IO、Range、缓存和 seek

已确认的类型和字段包括：

```text
CacheIOContext
  ├─ logicalPos / urlPos / bytesRead / end / eof
  ├─ entryList / entryCache / tmpURL
  ├─ firstSeekTime / seekOffsets
  └─ isReadComplete / download

PreLoadIOContext / LimitPreLoadIOContext / LimitCountPreLoadIOContext
  ├─ loadMoreBuffer / fakeUrlPos
  ├─ maxFileSize / maxReadedFileSize
  └─ maxMoreCount / moreCount

2.4.5: LimitSeparatePreLoadIOContext
  ├─ moreDownload / moreUrlPos
  └─ 独立的文件大小、读取位置和预加载状态

ReadCacheIOContext
  └─ tmpURL / end / logicalPos / entryCache
```

定向静态证据还命中了 `ffurl_read2`、`ffurl_seek2`、`reach maxFileSize`、`reach maxReadedFileSize`、缓存错误清理、`preferredRange`、`isRangeUncached(start:end:)`、`performSeek(time:flags:)`、`bufferMiss`、`maxBufferCount`、`maxBufferSize` 和 `clearBufferWhenStopped`。

这支持以下保守结论：DS One 不是只有“把 URL 交给播放器并使用默认缓存”，而是存在逻辑文件位置、受限读取、缓存缺口和 seek 处理层。它不支持以下未经动态确认的结论：固定窗口大小、固定缓冲秒数、每次 seek 必定重新请求、或所有媒体入口均启用同一个 IO context。

### 3.4 播放状态、性能和业务控制

`KSOptions` 暴露 DNS、TCP、open、probe、ready、音视频读取/解码、`firstPlayableTime` 和 `startPlayTime` 等时间点，同时有 `isAccurateSeek`、`seekFlags`、`seekUsePacketCache`、`preferredForwardBufferDuration`、`maxBufferDuration`、`probesize`、`maxAnalyzeDuration` 和 `nobuffer`。

`DSVideoKsPlayerViewController` 暴露或保存：

- `cacheNextIOContext`、`isPreloadVideo`、`enablePreLoadNext`
- `isLive`、`isTransCode`、媒体源、音轨/字幕集合
- 进度/观看状态上报、断点位置、下一项播放信息
- 片头跳过、音频路由变化、进度缩略图和字幕延迟

`DSVideoKsPlayerView` 还有按钮、单击/双击/拖动、倍速、时间变化和自然尺寸回调线索。它们证明控制层存在，不等于每个控制在当前真机样本上都已通过。

### 3.5 功能到实现机制的对应关系

这里区分“静态知道怎样实现”和“真机知道该样本确实走到了该实现”。以下机制来自 2.4.5 Build 4 的类型/元数据与已取得的 S03 真机证据，不把私有实现细节或未经观测的调用顺序当作事实。

| 功能 | 静态机制线索 | 已观察的运行时链路 | 尚未确认 |
|---|---|---|---|
| 播放/首帧 | `DSVideoKsPlayerViewController` → `KSAVPlayer` 或 `KSMPVPlayer`；`KSOptions` 保存 prepare/open/probe/ready/firstPlayable 时间点 | S01、S03、S18 均出现真实帧并持续推进 | 具体样本选择 AVPlayer 还是 MPV，以及各阶段真实耗时 |
| 暂停/恢复 | `MediaPlayback`/播放器状态；PiP 侧还有 `AVDelegatingPlaybackCoordinatorPauseCommand` | S03 控制层点击后位置停留，再点击后继续推进；PiP 内也有暂停控件 | 暂停时缓存是否保留、后台恢复时是否重新打开上游 |
| seek/快进快退 | `preferredRange`、`isRangeUncached(start:end:)`、`performSeek(time:flags:)`、`seekOffsets`、`seekUsePacketCache`、`ffurl_seek2` | S03 进度条可跳转，PiP 提供前后 10 秒控件；播放器未回到 00:00 | 关键帧回退策略、取消旧请求、seek 前后真实 Range 和恢复时延 |
| 音轨 | `MediaStream` 音频索引/语言/codec；`AudioTranscodeContext`；`AudioStreamIndex` | S03 显示粤语/英语/国语 AC-3 与英语 TrueHD 四条轨道，切换后位置保持 | 是否触发服务端转码、设备扬声器实际输出与路由变化 |
| 字幕 | `MediaStream` 字幕索引/交付信息；`SubtitleInfo`、`SubtitleTranscodeContext`、libass/PGS 线索 | S03 显示 PGS 与 ASS 轨道，切换后仍有字幕画面 | 字幕渲染是在解码器、播放器层还是 UI 合成，外部字幕失败降级方式 |
| Range/缓存 | `CacheIOContext`、`ReadCacheIOContext`、`LimitPreLoadIOContext`、2.4.5 `LimitSeparatePreLoadIOContext`；逻辑位置、EOF、缓存区间和受限预加载字段 | S03 高码率大文件可连续播放至少 30 秒 | 206/Content-Range、窗口大小、缓存命中/缺口和重试顺序 |
| PiP 进入 | `KSPictureInPictureController` 静态元数据的 superclass 是 `AVPictureInPictureController`；存在 `PictureInPictureViewProtocol`、`AVPictureInPictureControllerDelegate` 和 `AVPictureInPictureSampleBufferPlaybackDelegate` | DS One 播放 S03 时点击播放器右上角第一按钮，主界面隐藏并出现系统浮窗 | S03 这一轮实际使用 AVPlayer 采样源还是 MPV 采样源 |
| PiP 控制/退出 | `KSMEPlayer` 与 `KSMPVPlayer` 都有 play/pause/seek/buffering coordinator command；系统控件负责 PiP 窗口交互 | SpringBoard 树出现 `PIP-SBInteractionPassThroughView`，展开后有 `恢复全屏幕`；自动点击后回到 DS One 全屏播放器，画面继续在约 53:36 | DS One 内部 delegate 回调的精确顺序与进入/退出时缓存复用 |

#### PiP 自动化复现记录

本轮纠正了此前的自动化误判。播放器右上角第一按钮的 DS One 坐标由元素树确定为 `x=603..633, y=68..92`，以元素 XPath 定位并点击后，WDA 树出现 `PIPUIView`，屏幕进入竖屏系统 PiP。此时不能继续使用 DS One 会话树点击退出按钮，因为系统浮窗属于 SpringBoard。

随后建立一个仅用于 UI 操作的 SpringBoard WDA 会话（未安装 WDA、未更新或重启设备），点击 PiP 浮窗中心显示控件；SpringBoard 树明确暴露：

```text
PIP-SBInteractionPassThroughView  x=110 y=47 w=270 h=152
关闭画中画                         x=119 y=56 w=32 h=25
恢复全屏幕                         x=339 y=56 w=32 h=25
向后跳10秒钟 / 暂停 / 向前跳10秒钟  y=104
```

通过 XPath `//XCUIElementTypeButton[@name="恢复全屏幕"]` 获取元素并点击，PiP 窗口从系统树消失，屏幕恢复 DS One 全屏播放器，运行时画面仍在约 `53:36`，未回到开头。自动化证据：`/tmp/wda-springboard-controls-2.json`、`/tmp/wda-pip-restore-xpath-element.json`、`/tmp/wda-after-pip-restore-xpath.png`、`/tmp/wda-after-pip-restore-xpath.xml`。这条证据把链路拆成了“播放器 PiP 入口 → SpringBoard 浮窗 → 系统恢复全屏 → 原播放器状态继续”，而不是只记录 PiP 是否可用。

### 3.6 2.4.0 → 2.4.5 的播放相关变化

| 维度 | 2.4.0 | 2.4.5 | 可安全得出的结论 |
|---|---|---|---|
| MPV | libmpv 0.40 线索 | libmpv 0.41 线索 | 内核版本线索发生变化 |
| AVPlayer 输入 | `urlAsset` 等字段 | `io: Either<URL, AVAsset>` | 输入抽象更明确 |
| IO/预加载 | Cache、PreLoad、LimitPreLoad | 增加 `LimitSeparatePreLoadIOContext` | 出现独立预加载/读取建模 |
| seek/Range | seekOffsets、Range 相关线索 | `preferredRange`、`isRangeUncached`、`performSeek` | 缺口判断和 seek API 建模更显著 |
| 缓冲 | `preferredForwardBufferDuration` 等 | 加入 `bufferMiss`、`maxBufferCount`、`maxBufferSize`、`clearBufferWhenStopped` | 缓冲容量/未命中状态建模更显著 |
| 转码/字幕 | 音频/视频/字幕 context | 增加 `BSFTranscodeContext`、Metal 字幕视图、subtitle delay | 转码和字幕适配能力扩大 |

这些是静态版本差异，不是“2.4.5 一定更流畅”的性能结论。

## 4. 2.4.5 真机动态证据

### 4.1 设备和采集约束

- 设备：iPhone 13，iOS 16.3.1，UDID `REDACTED-DEVICE-01`。
- WDA：复用已验证的持久化 WDA 16.8.0，`127.0.0.1:8102/status` 返回 `ready=true`。
- 本轮未重新安装 WDA，未更新或重启 iPhone。
- 屏幕录制、WDA source/screenshot 和入口操作可作为 UI/画面证据；不能代替 HTTP Range、系统音频听测或 Instruments。

### 4.2 Jellyfin / S01《哈尔的移动城堡》

入口：`视频 → Jellyfin 媒体库 → 电影 → 哈尔的移动城堡`。

观察到：

- 详情页有 720P SDR、约 2.8GB、时长 `1:59:25`。
- 播放器出现真实视频帧，画面叠加显示 H264、688P、29FPS、3293kbps，并可见字幕。
- 重入后播放器约从 `33:50` 推进到 `34:17`；操作进度条后播放位置发生改变，说明 seek 控件可达。
- 证据图：`/tmp/dsone-s01-repeat-20260827.png`。

对应矩阵状态只允许写为：`LIB=P`、`FF=P`、`ST=部分观察`、`SK=已触达但未完成 15 秒精度与恢复时延验收`；`PA/AT/SU/Q/PP/EX/MEM/SA=AUD` 仍为 `U`，字幕画面可记录为“已观察”但不能代替完整 `SU` 和 `SA=SUB` 判定。

### 4.3 DSM 文件 / S18《方世玉续集》

入口：`首页 → video → downloads → movie → [方世玉续集]`。

文件：

`[方世玉续集].The.Legend.of.Fong.Sai.Yuk.2.1993.GBR.BluRay.1080p.x264.FLAC.2.0.2Audios-CMCT.mkv`

观察到：

- 取得真实视频帧，播放器叠加显示 H264、1036P、23FPS、20.46Mbps。
- t≈3、10、30 秒截图是不同的真实画面，证明时钟推进，而不是详情页或加载占位。
- 播放器控制条实际出现过暂停/下一项/音轨/字幕/更多等入口图标；图标存在不等于对应功能已经通过。
- 证据图：`/tmp/dsone-s18-play-20260827.png`、`/tmp/dsone-s18-t10-20260827.png`、`/tmp/dsone-s18-t30-20260827.png`、`/tmp/dsone-s18-controls2-20260827.png`。

对应矩阵状态只允许写为：`LIB=P`、`FF=P`、`ST=部分观察`；`PA/SK/AT/SU/PP/EX/MEM/SA` 仍未完成闭环。DSM 入口不具备 Jellyfin 清晰度切换，因此 `Q=N/A`，但应记录明确原因。

### 4.4 Jellyfin / S03《碟中谍3》大体积样本

入口：`视频 → Jellyfin 媒体库 → 本服搜索 → 碟中谍3 → 播放`。

详情和文件信息：

- 时长约 `2小时5分`，文件大小 `50.3 GB`。
- 文件名：`Mission.Impossible.III.2006.2160p.BluRay.REMUX.DV.HEVC.TrueHD.5.1.mkv`。
- 详情标识：4K、HEVC、Dolby Vision Profile 7.6（HDR10 fallback）、Main 10、3840×2160、10-bit、bt2020、57 Mbps、TrueHD 5.1。

动态采集目录：`/tmp/dsone-s03-dynamic-20260827/`。

观察结果：

- 冷启动进入播放器后取得真实画面；t=0/3/10/30 的 PNG 哈希不同，t=30 仍是清晰真实片段，不是黑屏、详情页或加载占位。
- 播放器运行时报告 `HEVC`、`2160P`、`23FPS`、`57.42mbps`；t≈30 时播放位置继续推进，控制条显示约 `02:12` 至后续时间点。
- 控制条可以显示滑块、锁定、暂停、下一项、音轨、字幕、更多等按钮。暂停按钮点击后约 4 秒仍在 `03:00` 附近，再次点击后约推进到 `03:01`，证明暂停/恢复行为可观察；仍需按矩阵补做更严格的停止时长和恢复时间记录。
- 音轨菜单实际列出 4 条：粤语 AC-3 6ch、英语 AC-3 6ch、国语 AC-3 6ch、英语 TrueHD 6ch；选择英语 TrueHD 后播放器未回到 00:00，之后仍在约 `07:49` 继续播放。该结果证明菜单、轨道选择和位置保持可触达，但 `AUD` 仍未完成设备扬声器听测。
- 内嵌字幕菜单实际列出 2 条 `HDMV_PGS_SUBTITLE` 和 2 条 `ASS`；切换到另一条 PGS 后画面仍显示中英字幕，之后约在 `09:18` 继续播放。该结果证明字幕轨道切换可触达并有画面结果，完整 `SU`/`SA=SUB` 仍需逐帧检查多个自然字幕帧。
- PiP 已通过真实设备复现：播放中点击播放器右上角第一按钮后，主界面隐藏并出现系统浮动 PiP 窗口；WDA 树出现隐藏的 `PIPUIView`，尺寸 `270×152`，trait 为 `StartsMediaSession`。之后用 SpringBoard 会话点击浮窗中心显示系统控件，树中出现 `PIP-SBInteractionPassThroughView` 及 `恢复全屏幕`，再自动点击该按钮后回到 DS One 全屏播放器，运行时画面仍在约 `53:36`，未回到开头。证据图：`/tmp/dsone-pip-after-element.png`、`/tmp/wda-springboard-controls-2.json`、`/tmp/wda-after-pip-restore-xpath.png`；证据树：`/tmp/dsone-pip-after-element.xml`、`/tmp/wda-pip-restore-xpath-element.json`、`/tmp/wda-after-pip-restore-xpath.xml`。
- 这条 PiP 证据现在是自动化闭环：DS One 会话定位右上角第一按钮并点击进入；SpringBoard 会话定位 `//XCUIElementTypeButton[@name="恢复全屏幕"]` 并点击退出。此前通过重新启动 DS One 结束 PiP 的做法只证明断点保存，不能代替退出按钮验证；随后导出的崩溃报告未发现 DS One 崩溃文件。

本样本的动态结论：大文件已证明可以在该 Jellyfin 入口实际解码并连续推进至少 30 秒，PiP 进入已确认；真实的播放器分支、Range 窗口、缓冲阈值、TrueHD 实际音频输出和 PiP 退出/回 App 状态仍未完全证明。该样本应作为 Nastart 后续内存/Jetsam、有限 Range 和高码率解码回归的首要基准。

## 5. 网络和性能证据缺口

本轮不能从 DS One 画面中的吞吐叠加信息推导 Range。已尝试的设备端链路没有取得原始请求：`rvictl -s` 未能建立 `rvi0`，`idevicesyslog` 只提供系统级网络摘要；没有修改设备代理、证书或安全校验，也没有使用破解 dylib。故以下项目必须保持未判定：

- 请求是否为 `206`，以及每个 `Content-Range` 的起止偏移和总长度。
- 首段/续段窗口大小、真实交付 bytes、短 EOF、取消和重试。
- 首帧前 DNS/TCP/open/probe/ready/decode 各阶段耗时。
- 缓冲起止、buffer miss、seek 后恢复时间和内存峰值。
- Jellyfin 与 DSM 是否共用同一实际 IO/播放器分支。

S03 还新增两个重要边界：详情页声明的是 Dolby Vision/TrueHD，而播放器运行时可见的是 HEVC/2160P/57.42 Mbps，音轨菜单同时出现 AC-3 和 TrueHD；不能仅凭界面判断这是原始直放、服务端转码、播放器内部适配还是多轨展示。另一个已确认事实是 PiP 可以在播放中脱离 DS One 继续显示，并能通过 SpringBoard 的 `恢复全屏幕` 回到 DS One 播放器；但 DS One 内部 delegate 回调顺序、实际播放器后端和 PiP 期间的 Range/缓存行为仍需用 PlaybackInfo、HTTP 请求和播放器日志继续对齐。

这些缺口不能用播放画面、吞吐速度或进度条代替。下一轮需要在合法可观测条件下接入服务端访问日志、现有网络代理或 Instruments；若环境仍不可观测，应继续写 `TOOL`，而不是猜测 DS One 参数。

## 6. 与 Nastart 的对比边界

Nastart 当前已有可独立实现的候选能力：媒体源协商、有限上游 Range 窗口、连续 chunked 客户端响应、seek 请求取消/续接、轨道状态保持、首帧/缓冲/卡顿诊断和 PiP 降级记录。这些是基于通用播放器工程和当前源码的独立实现，不是 DS One 私有代码的复制。

本轮新增的源码改动只增强 AVPlayer 缓冲观测：记录缓冲区起点、终点和当前 playhead，避免 seek 后因缓冲终点不变而丢失诊断事件。构建、安装和 preflight 均成功，但在 DS One 的 Range、缓冲阈值、音频、PiP 和真实分支尚未补齐前，不应继续据此扩展 Nastart 播放策略，也不应宣称 Nastart 已完成全方位优化。

## 7. 下一轮取证顺序

严格按同一视频、同一入口、同一设备对齐：

1. DS One S18 DSM：冷启动、首帧、t=3/10/30、暂停/恢复、±15 秒 seek、音轨/字幕实际结果、后台恢复、退出/断点、下一项。
2. DS One S01 Jellyfin：重复以上项目，增加清晰度切换和 PiP 进入/退出；记录返回 App 后位置和状态。
3. 代表格式族：S03（DV/HEVC/TrueHD/ASS）、S08（HDR HEVC MP4）、S11（10-bit HEVC/TrueHD）。
4. 在 iPhone 与 iPad 上分别完成单端，再做 S01 双端并发；不得用单端结果替代并发结果。
5. 每个操作同步记录 WDA 时间、屏幕时间、客户端请求、服务端日志、播放器/系统日志和内存轨迹。
6. 只有动态证据形成后，才将 Nastart 的实现项逐一映射、构建、单元测试、真机回归并更新 `PLAYBACK-FUNCTION-MATRIX.md`。

## 8. 关联文档

- [2026-08-17 DS One 静态分析](2026-08-17-DSONE-STATIC-ANALYSIS.md)
- [DS One 2.4.5 静态差异](2026-08-18-DSONE-2.4.5-STATIC-DIFF.md)
- [DS One 视频播放说明](../../../research/DSONE-VIDEO-PLAYBACK-SPEC.md)
- [播放功能矩阵](../../../testing/PLAYBACK-FUNCTION-MATRIX.md)
- [真机调试运行手册](../../../handoffs/PLAYBACK-DEBUG-RUNBOOK.md)
- [2026-08-27 DS One / Nastart 对比取证](2026-08-27-DSONE-NASTART-PLAYBACK-COMPARISON.md)
