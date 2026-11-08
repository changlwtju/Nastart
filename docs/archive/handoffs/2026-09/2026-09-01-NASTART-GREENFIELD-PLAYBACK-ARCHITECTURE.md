# Nastart 视频播放新架构设计草案

日期：2026-09-01

## 设计立场

本设计把 Nastart 的视频播放链路视为一个新的独立任务，而不是对现有播放实现的延续、修补或抽象包装。

现有 AVPlayer/MobileVLCKit/Jellyfin HLS fallback 代码只作为后续效果对照，不作为本架构的决策核心，也不嵌入新播放器的运行时 fallback。新旧播放器在真实体验端保持 A/B 分离：DEBUG 构建里通过调试开关选择进入旧播放器或 greenfield 播放器，进入后各自拥有独立的 session、policy、diagnostics 和后续 engine 接入。

新架构的主要参考对象是 DS One 和 Lenna 静态/动态拆解出来的底层播放逻辑：

- 播放前先完成媒体源和轨道决策。
- 播放器前面有独立 IO/cache/preload 层。
- 播放引擎同时覆盖系统播放器路径和 FFmpeg/VideoToolbox/Metal 路径。
- seek、Range、缓存缺口、下一集预加载不是播放器 UI 的附属逻辑，而是底层能力。
- 字幕、音轨、PiP、日志、统计、进度上报由播放业务层统一协调。

这份设计的目标不是“把当前播放器整理得更好”，而是重新设计 Nastart 应该拥有的一套视频播放底座。

## 竞品证据摘要

### DS One

DS One 的静态和动态证据支持以下模型：

```text
PlaybackInfo / MediaSourceInfo / MediaStream
  ↓
业务播放器控制器
  ↓
KSPlayer
  ├─ KSAVPlayer → AVPlayer / AVAsset
  └─ KSMPVPlayer → libmpv / FFmpeg
  ↓
CacheIOContext / PreLoadIOContext / ReadCacheIOContext
  ↓
VideoToolbox / Metal / libplacebo / libass / HDR/DV / 字幕音轨
```

关键能力：

- `PlaybackInfo`、`MediaSourceInfo`、`MediaStream` 参与直放、直通、转码和轨道选择。
- `KSOptions` 持有 DNS/TCP/open/probe/ready/firstPlayable/decode 等时间点。
- `CacheIOContext`、`PreLoadIOContext`、`ReadCacheIOContext` 管理逻辑位置、Range、seek、缓存和预加载。
- `preferredForwardBufferDuration`、`seekUsePacketCache`、`isRangeUncached(start:end:)`、`performSeek(time:flags:)` 等线索表明播放性能策略在底层建模。
- PiP、进度上报、片头跳过、下一项预加载和音轨/字幕选择由播放器业务层统一处理。

### Lenna

Lenna 1.0.17 静态证据进一步强化了这个方向：

```text
多来源入口
  ├─ 本地 / URL / SMB / WebDAV
  ├─ Emby / Jellyfin / Plex
  └─ 多家网盘
  ↓
PlaybackInfo / MediaSource / MediaStream 预取与排序
  ↓
LnKSOptions / FileServerKSOptions
  ↓
KSPlayer
  ├─ KSAVPlayer
  └─ KSMEPlayer
  ↓
PreLoadIOContext / CacheIOContext / LimitSeparatePreLoadIOContext
  ↓
可选 ProAVPlayer / LocalHLSServer / ConversionToM3U8
```

关键能力：

- 播放设置明确覆盖 `playerType`、`videoDecodeType`、硬解、Metal、精确 seek、PiP、后台播放、日志、MetalFX 超分。
- `Preload Next Episode` 文案明确写出“预加载下一集 200MB 到磁盘缓存”。
- `ProAVPlayer / LocalHLSServer / ConversionToM3U8 / RemuxerIO` 表明其可能还有本地 HLS/fMP4 remux 兼容路径。
- 字幕和弹幕是播放体验的一等能力：外部字幕、在线字幕、双字幕、HDR 字幕、弹幕搜索/调度/统计均有线索。

## Nastart 新播放架构目标

1. 建立一套可长期演进的视频播放底座，而不是继续围绕单个播放器补丁化演进。
2. 支持多来源媒体统一进入同一套播放计划：Jellyfin、DSM、SMB、WebDAV、本地文件、URL、未来云盘。
3. 把播放源决策、Range/cache/preload、播放引擎、字幕/音轨、诊断统计分成独立层。
4. 让 KSPlayer 或等价 FFmpeg/VideoToolbox/Metal 引擎成为核心候选，而不是外围 fallback。
5. 保留 AVPlayer 路径处理系统 HLS、MP4、PiP、AirPlay、后台播放等系统能力。
6. 支持本地 HLS/remux 作为兼容性实验方向。
7. 用真实样本和指标决定最终采用哪条链路。

## 总体架构

```text
Playback Entry
  ├─ Jellyfin item
  ├─ DSM file
  ├─ SMB/WebDAV file
  ├─ Local file
  └─ Direct URL
        ↓
Playback Intent
        ↓
Source Resolver
  ├─ PlaybackInfo fetch
  ├─ MediaSource selection
  ├─ MediaStream / track extraction
  ├─ subtitle source discovery
  └─ route capability probe
        ↓
Playback Plan
  ├─ primary route
  ├─ alternate routes
  ├─ selected tracks
  ├─ subtitle plan
  ├─ cache/preload policy
  └─ diagnostics context
        ↓
Playback IO Layer
  ├─ Range source
  ├─ cache index
  ├─ read cache
  ├─ preload coordinator
  ├─ local authenticated proxy
  └─ optional local HLS/remux server
        ↓
Playback Engine
  ├─ KSPlayer Engine
  │   ├─ AVPlayer-compatible path
  │   └─ FFmpeg/VideoToolbox/Metal path
  ├─ System AVPlayer Engine
  └─ Local HLS Engine
        ↓
Playback Experience Layer
  ├─ controls
  ├─ PiP
  ├─ audio/subtitle menus
  ├─ diagnostics HUD
  ├─ progress reporting
  └─ next episode / continuous playback
```

## 新旧运行时边界

DEBUG 阶段采用显式 A/B：

- 旧入口：`MediaPlaybackRequest -> BuiltInMediaPlayerView -> MediaPlayerSession / MobileVLCKit fallback`
- 新入口：`GreenfieldPlaybackLaunchRequest -> GreenfieldVideoPlayerView -> PlaybackIntent -> SourceResolver -> PlaybackPlan -> PlaybackSessionCoordinator`

两条体验链路不共享播放器 session、不共享 fallback policy、不共享 UI 控制状态。Jellyfin 详情页只在播放按钮前共享业务上下文，用于生成各自的启动请求；进入播放器后，新架构只能依赖 `PlaybackPlan` 和新 coordinator。

当前代码阶段的 greenfield 可见播放面临时使用独立 `AVPlayer` 渲染，以便真实视频可打开、可观察首帧和 30 秒连续播放。KSPlayer 接入后替换的是 greenfield engine/view 内部实现，不回接旧 `BuiltInMediaPlayerView`。

2026-09-01 代码状态：

- `debug.playback.use_greenfield_player` 是 DEBUG 调试开关，当前已覆盖 Jellyfin 媒体详情、DSM 设备文件预览、直接 URL 播放入口。
- `GreenfieldPlaybackBridge` 只在播放器启动前把现有业务请求转换为 `GreenfieldPlaybackLaunchRequest`；进入播放器后，新旧链路不共享 session、fallback policy 或 UI 控制状态。
- `PlaybackConnectionContext` 已区分 `loopback`、`privateIP`、`publicIP`、`localDomain`、`publicDomain`，用于覆盖 IP+端口内网访问、域名+端口外网访问、本地代理等真机验证场景。
- 新架构是 KSPlayer 优先设计：`directHTTP`、`localRangeProxy`、`localFile` 默认规划为 `ksPlayer`；`serverHLS/localHLS/remuxedHLS` 默认规划为 `systemAVPlayer`。当前尚未链接 KSPlayer，greenfield 可见播放面临时使用独立 AVPlayer 以便先跑真实视频体验。

## 分层设计

### 1. Playback Entry

入口只表达用户从哪里发起播放，不决定底层播放器。

入口类型：

- Jellyfin 媒体项
- DSM 文件
- SMB/WebDAV 文件
- 本地文件
- 直接 URL
- 后续云盘文件

入口输出 `PlaybackIntent`。

### 2. PlaybackIntent

表达“用户想播放什么”。

```text
PlaybackIntent
  id
  sourceKind
  itemIdentity
  displayTitle
  preferredStartTime
  preferredAudioTrackID
  preferredSubtitleTrackID
  playbackModePreference
  networkContext
  userContext
```

`PlaybackIntent` 不携带播放器实现细节，不直接保存 AVPlayer/VLC/KSPlayer 专有参数。

### 3. Source Resolver

负责把 intent 解析成可播放计划。

职责：

- 获取 Jellyfin/Emby/Plex 类 `PlaybackInfo`。
- 读取 DSM/SMB/WebDAV 文件大小、扩展名、Range 能力。
- 解析媒体源：DirectPlay、DirectStream、Transcode、LocalRemux。
- 提取音轨、字幕轨、默认轨道、外部字幕地址。
- 判断是否需要服务端烧字幕、是否需要音频转码、是否可原画直放。
- 对远程文件做轻量 Range/Content-Range 探测。

输出 `PlaybackPlan`。

### 4. PlaybackPlan

这是新架构的核心合同。播放器只能消费 plan，不能绕过 plan 自行猜测。

```text
PlaybackPlan
  id
  intent
  mediaIdentity
  timeline
  primaryRoute
  alternateRoutes
  tracks
  subtitles
  cachePolicy
  preloadPolicy
  enginePolicy
  diagnostics
```

### 5. PlaybackRoute

描述实际媒体输入。

```text
PlaybackRoute
  routeKind:
    directHTTP
    localRangeProxy
    serverHLS
    localHLS
    localFile
    remuxedHLS

  playMethod:
    directPlay
    directStream
    serverTranscode
    localRemux

  url
  originURL
  headers
  certificatePolicy
  containerHint
  mimeHint
  duration
  byteLength
  rangeCapability
  codecSummary
```

关键约束：

- 鉴权 header、证书策略、真实 origin URL 必须属于 route。
- 日志记录必须脱敏。
- 外部播放器 handoff 使用单独 route，不能复用内部 loopback URL。

### 6. Playback IO Layer

这是参考 DS One/Lenna 后 Nastart 最应该新建的底层能力。

核心对象：

```text
RangeSource
RangeCacheStore
ReadCacheContext
PreloadContext
LocalMediaProxy
LocalHLSServer
RemuxPipeline
```

能力：

- `open(route)`
- `read(offset:length:)`
- `seek(offset:)`
- `cachedRanges()`
- `isRangeCached(start:end:)`
- `isRangeUncached(start:end:)`
- `preload(range:budget:)`
- `cancelPreload(reason:)`
- `invalidateCache(reason:)`
- `close()`

设计重点：

- 逻辑文件位置和缓存文件位置分开。
- Range 窗口大小由策略决定，不由播放器隐式决定。
- seek 时先判断目标附近是否缓存命中，再决定是否取消旧读取、发新 Range、回退关键帧或继续读。
- 下一集预加载是单独任务，有明确预算和取消条件。
- 本地 loopback proxy 只负责给播放器稳定输入，不拥有业务决策。

### 7. Playback Engine Layer

播放器引擎只负责消费 plan 和 IO 输入。

候选：

- `KSPlayerEngine`
- `SystemAVPlayerEngine`
- `LocalHLSEngine`

暂不把旧 MobileVLCKit 作为新架构核心候选。它可以在评测阶段作为 baseline 对照，但新设计不围绕它展开。

#### KSPlayerEngine

优先候选。

目标能力：

- 原始 MKV/MP4/TS/M2TS 等容器播放。
- FFmpeg demux/decode。
- VideoToolbox 硬解。
- Metal 渲染。
- 音轨/字幕枚举和切换。
- 精确 seek / packet cache seek。
- 与 `PlaybackIOContext` 对接 Range/cache/preload。
- 暴露 first frame、buffer、decode、render、track、error 事件。

需要验证：

- upstream KSPlayer 是否足够稳定。
- 是否使用 KSAVPlayer/KSMEPlayer 两条路径。
- 是否需要 fork 以接入 Nastart 的自定义 IO。
- PiP 是否能覆盖非 AVPlayer 渲染路径。
- App Store、许可证、包体和构建风险。

#### SystemAVPlayerEngine

用于系统兼容路径。

适用场景：

- HLS
- MP4/MOV
- PiP
- AirPlay
- 后台播放
- 本地 HLS/remux 输出

它不是复杂容器的默认答案，但必须作为系统能力保留。

#### LocalHLSEngine

参考 Lenna 的 ProAVPlayer 线索。

目标：

- 对“容器复杂但编码可硬解”的资源做本机 remux。
- 生成本地 HLS/fMP4。
- 交给 AVPlayer 获得 PiP/后台/系统缓冲能力。

风险：

- 首段生成可能拖慢首帧。
- CPU/磁盘消耗不可忽视。
- seek 可能需要索引和分段重建。

### 8. Track and Subtitle Layer

音轨和字幕必须独立建模。

```text
TrackCatalog
  sourceAudioTracks
  sourceSubtitleTracks
  runtimeAudioTracks
  runtimeSubtitleTracks
  mapping

SubtitlePlan
  mode:
    embedded
    externalText
    serverBurnIn
    uiOverlay
    disabled
  primarySubtitle
  secondarySubtitle
  normalization
  fontPolicy
  safeAreaPolicy
```

关键点：

- 源轨道 ID 和播放器 runtime track ID 不能混用。
- ASS/SSA/PGS/SRT/WebVTT 必须进入明确策略。
- CJK 字体、编码归一化、安全区域、双字幕属于播放层能力。
- 服务端烧录字幕和本地渲染字幕要能互相替换，但不能在 UI 层临时拼。

### 9. Diagnostics Layer

诊断是新架构的基础设施，不是最后加的日志。

必要事件：

```text
intent_created
source_resolve_started
playback_info_loaded
route_probe_started
route_probe_succeeded
route_selected
io_open_started
io_opened
range_requested
range_received
cache_hit
cache_miss
preload_started
preload_completed
engine_prepare_started
engine_ready
first_frame
buffer_updated
seek_started
seek_recovered
track_changed
subtitle_changed
pip_started
pip_stopped
fallback_selected
playback_failed
playback_stopped
```

核心指标：

```text
tapToResolveMs
resolveToRouteMs
routeToOpenMs
openToReadyMs
tapToFirstFrameMs
seekRecoveryMs
bufferAheadSeconds
rangeRequestCount
rangeBytesRead
cacheHitBytes
cacheMissBytes
preloadedBytes
decodeEngine
renderEngine
videoCodec
audioCodec
subtitleCodec
routeKind
playMethod
networkClass
```

## 第一阶段设计目标

第一阶段不是迁移，而是搭出新底座的最小可运行样子。

### 范围

只做：

- Jellyfin 视频入口。
- `PlaybackIntent`、`PlaybackPlan`、`PlaybackRoute`、`PlaybackDiagnostics`。
- `SourceResolver` 生成计划。
- KSPlayer 技术 spike 调研和最小集成方案。
- Range/cache/preload 的接口和最小观察实现。

暂不做：

- DSM/SMB/WebDAV/云盘全量接入。
- 完整播放器 UI 重写。
- 外部播放器 handoff。
- Release 默认切换。
- 片头片尾、弹幕、双字幕完整实现。

### 样本

优先验证：

- S01：Jellyfin 普通 H264/720P。
- S03：50GB DV/HEVC/TrueHD/ASS 大文件。
- S18：DSM MKV/FLAC，第二阶段接入 DSM 后使用。

### 第一阶段成功标准

- 新架构能为 S01/S03 生成完整 `PlaybackPlan`。
- 能明确记录 DirectPlay / DirectStream / ServerTranscode / LocalRemux 决策原因。
- 能记录首帧、seek、Range、cache/preload 关键指标。
- KSPlayer 集成风险清单明确。
- 至少一个 Jellyfin 样本能通过新 engine spike 出真实画面。

## 推荐实施顺序

### Step 1：建模

新增目录：

```text
ios/Nastart/Nastart/Playback/
  Core/
  Sources/
  IO/
  Engines/
  Diagnostics/
```

先创建纯 Swift 模型：

- `PlaybackIntent`
- `PlaybackPlan`
- `PlaybackRoute`
- `PlaybackTimeline`
- `TrackCatalog`
- `SubtitlePlan`
- `PlaybackDiagnosticsEvent`

2026-09-01 已开始落地第一批代码：

- `Playback/Core/PlaybackIntent.swift`：定义入口意图、来源、内容类型、用户播放模式偏好和网络上下文。
- `Playback/Core/PlaybackRoute.swift`：定义实际播放路由、播放方法、证书策略、Range 能力和 codec 摘要。
- `Playback/Core/PlaybackPlan.swift`：定义新架构核心合同，聚合 route、timeline、track、subtitle、cache、preload 和 engine policy。
- `Playback/Core/PlaybackEngine.swift`：定义播放器引擎协议、运行态、seek 模式和 source resolver 协议。
- `Playback/IO/PlaybackByteRange.swift`：定义半开区间 `[start, endExclusive)` 和 Range gap。
- `Playback/IO/RangeCacheStore.swift`：实现缓存区间合并、命中判断、缺口计算和 hit/miss 字节统计。
- `Playback/IO/PlaybackIOContext.swift`：定义 IOContext 协议，并提供观察型 IO 原型。
- `Playback/IO/PreloadCoordinator.swift`：定义启动、seek、下一项和恢复预加载任务。
- `Playback/Diagnostics/PlaybackDiagnostics.swift`：定义首帧、seek、音轨、字幕、PiP、弱网、断流等诊断事件和指标键。
- `Playback/Diagnostics/PlaybackScenarioMatrix.swift`：把冷启动、首帧、30 秒连续播放、暂停恢复、快进/快退、播放中音轨/字幕切换、Jellyfin 清晰度切换、后台恢复、PiP 进出、播放结束/下一项、弱网和断流恢复固化为 baseline 场景。
- `Playback/Engines/KSPlayerEngineSpike.swift`：先定义 KSPlayer 候选引擎边界，实际第三方链接未开始。
- `NastartTests/PlaybackNextCoreTests.swift`：覆盖 Range 合并、缺口计算、预加载预算和场景矩阵完整性。

2026-09-02 继续落地：

- `scripts/xcodebuild_nastart.sh`：自动定位完整 Xcode，并将 `DEVELOPER_DIR/usr/bin` 加入 `PATH`，用于当前机器全局 `xcode-select` 仍指向 CommandLineTools 时运行完整 `xcodebuild`。
- `Podfile`：让 `NastartTests` 继承 CocoaPods search paths，修复测试 target 在 `@testable import Nastart` 时解析不到 `MobileVLCKit` 的问题。
- `Playback/Engines/PlaybackEngineAvailability.swift`：新增 engine 链接状态检测，明确区分“计划层选择 KSPlayer”和“当前二进制是否已链接 KSPlayer”。
- `Playback/Engines/GreenfieldKSPlayerRenderer.swift`：新增条件编译 KSPlayer 渲染边界；当前未链接 KSPlayer 时保持可编译，一旦接入依赖可进入 `KSVideoPlayerView(url:options:title:)`。
- `GreenfieldVideoPlayerView`：按 plan 选择实际渲染器。`ksPlayer` 计划在 KSPlayer 未链接前使用 greenfield 内部 AVPlayer fallback 试播，并在 DEBUG badge 中标明实际渲染器。
- `PlaybackPlan`：新增 `PlaybackStartupPolicy`、`PlaybackTrackSwitchPolicy`、`PlaybackPictureInPicturePolicy`、`PlaybackRecoveryPolicy`，把首帧、轨道切换、PiP 和弱网恢复纳入 plan，而不是散落在 UI 层。
- `PlaybackPlanningPolicy`：蜂窝/受限/昂贵网络下，Jellyfin 或远程大文件会生成小启动窗口、非阻塞首帧、缩小下一项预加载预算；内网 DSM/IP 直连则保留更积极的启动预热。
- `PlaybackSessionCoordinator`：启动预加载现在遵守 `blocksFirstFrameUntilStartupPreload`。弱网下会记录 `preload_cancelled(reason=first_frame_priority)` 并优先返回 plan，让播放器尽快打开首帧。
- `PlaybackDiagnostics`：新增首帧目标、启动预加载大小、是否阻塞首帧、轨道切换目标耗时、PiP 系统渲染要求、KSPlayer 链接状态等指标键。
- `PlaybackNextCoreTests`：新增 KSPlayer 链接状态边界、弱蜂窝大文件首帧优先策略，并修正会话级事件与 plan 级事件的测试边界。

## 旧架构真实问题与新架构专项策略

当前旧架构下已观察到的问题：

- 首帧出现时间长，尤其是弱蜂窝网络播放大体积远程视频时，首帧可能非常慢甚至无法加载。
- 播放稳定性不足，弱网/断流下缺少明确的 buffer、Range、cache、route retry 协调。
- 播放中切换字幕和音轨不够流畅，切换延迟较长。
- PiP 尚未形成完整能力闭环。

新架构的对应设计要求：

- 首帧优先：启动阶段不能把“大块预加载完成”作为进入播放器的硬前置。弱网下优先打开播放器和首帧，预加载、下一集缓存和大窗口读取延后。
- 弱网可观测：必须记录 `networkClass`、`bufferAheadSeconds`、`cacheMissBytes`、`rangeRequestCount`、`streamInterrupted` 和 `fallbackSelected`，让真机问题能被复现和量化。
- 轨道切换可控：音轨/字幕切换由 `PlaybackTrackSwitchPolicy` 约束，优先使用 engine native switch；必要时允许 route rebuild，但必须记录目标恢复耗时和实际恢复耗时。
- PiP 明确分层：原始 KSPlayer/FFmpeg 渲染路径可以是主力解码路线，但 PiP 需要通过 `PlaybackPictureInPicturePolicy` 标明是否必须切到系统渲染或本地 HLS/remux 路线。
- 下一项预加载让位：下一集预加载不能抢冷启动首帧、seek 恢复和弱网重连的 IO 预算。

### Step 2：Jellyfin Source Resolver

把 Jellyfin 播放准备从“创建播放器请求”改成“创建播放计划”：

```text
Jellyfin item
  ↓
PlaybackInfo
  ↓
MediaSource selection
  ↓
TrackCatalog
  ↓
PlaybackRoute candidates
  ↓
PlaybackPlan
```

第一版可以只记录 plan，不接管真实播放。

### Step 3：IO/cache 接口

先实现观察型 IO：

- 做 Range probe。
- 记录请求窗口。
- 记录 cache hit/miss 的理论状态。
- 暂不强制播放器走新缓存。

然后再实现可消费的 local proxy/cache。

### Step 4：KSPlayer Spike

做最小闭环：

- 引入 KSPlayer。
- 使用 `PlaybackPlan.primaryRoute` 打开 S01。
- 接收状态、首帧、错误、音轨/字幕列表。
- 再尝试 S03。

### Step 5：本地 HLS/remux Spike

如果 KSPlayer 原始流路径在 PiP/后台/部分格式上不足，再验证本机 remux 到 HLS/fMP4。

## 与现有实现的关系

从设计角度：

- 不继承现有播放决策。
- 不以现有 `MediaPlaybackPolicy` 为核心。
- 不要求新架构兼容旧 session 内部状态。
- 不把旧架构中的 workaround 搬进新架构，除非它被重新验证为通用规则。

从工程落地角度：

- 现有播放链路可以继续存在，作为用户可用路径和 A/B 对照。
- 新架构代码应在独立目录中开发。
- 新架构入口应通过 Debug/实验开关触发。
- 对比指标必须统一，避免主观判断。

## 待决策问题

1. KSPlayer 采用 upstream 还是 fork。
2. 是否需要复刻类似 `PreLoadIOContext` 的自定义 IO，还是先用 KSPlayer 自带能力。
3. FFmpeg/libav 依赖是否由 KSPlayer 引入，还是 Nastart 自己控制。
4. PiP 对非 AVPlayer 渲染路径如何实现。
5. 本地 HLS/remux 是否作为第一阶段并行 spike，还是等 KSPlayer 结果后再做。
6. 新架构是否支持弹幕，若支持应放在字幕层还是体验层。

## 当前结论

Nastart 的视频播放应作为新底层工程重新启动。

最值得参考的竞品共识不是“用了某个播放器”，而是：

```text
先决策媒体源
再管理 IO/cache/preload
再选择播放引擎
最后统一控制、字幕、音轨、PiP 和诊断
```

因此，下一步应先建立新播放模型和 `PlaybackPlan`，再围绕 KSPlayer 与本地 HLS/remux 做真实样本 spike。旧链路不再定义新架构，只负责在实验期间提供对照数据。
