# Playback Offline Diagnostics

2026-11-20 `playback_phase_report.py` 增加 `firstObservedSegmentAttempts`，按 trace 记录观察窗内首次见到的播放器段请求及同一 child 的重试，覆盖从非零段开始的续播。显式预取和内部首帧之后的新请求排除，启动期已发请求的晚返回仍保留。保留原 0 号段字段 `startupSegmentAttempts`。窗口若在请求发出后才开始，最早可见请求只代表现有采样。 [离线回放验证](../archive/handoffs/2026-11/CODEX-2026-11-20-HLS-OBSERVED-SEGMENT-REPORT.md)

2026-11-09 索引等待的阶段依容器与真实读序而变。合成 MP4 的尾部索引等待在初始定位前；合成 Matroska 的 Cues 等待发生在初始定位内。报告应同时核同 trace / plan 的退场和对应 transferID，而不是把 `pending` 直接归为播放器计算开销。 [当轮记录](../archive/handoffs/2026-11/CODEX-2026-11-09-S19-MATROSKA-CUES.md)

2026-11-09 `playback_trace_report.py` 将同 trace / plan 的 `engine_startup_incomplete` 单列为 `incompleteEngineStartups`，输出定位结果、首包、首个接受帧和提交时刻。未知阶段输出空值。未推进退场不会填补成功起播落点、首帧或速度配对；缺任一身份的日志仍列为未归属。

2026-11-09 受控 Range 夹具支持 `playback_lab.py --fault-range-start <字节偏移>`。选项把已有延迟、限速和断流限制到解析后从该偏移开始的有效 GET Range。HEAD、其他范围及 416 不注入。可分别模拟小尾段的响应等待和大尾段的正文慢读。合成空数据可验证 HTTP 供给条件，播放器复现须用可解码片源和独立窗口。

2026-10-20 Debug lab：显式`NASTART_PLAYBACK_LAB_PROXY=1`将HLS URL交现有认证代理，另设`NASTART_PLAYBACK_LAB_PREWARM=1`才预热完整VOD文字，默认均关且不启用首片primer；失败/取消/播放器释放注销同route。`NASTART_PLAYBACK_LAB_POSITION`仍为0～1归一化位置。此注入不是普通入口/Release验收，结束恢复空环境，参见[六窗边界与限制](../archive/handoffs/2026-10/2026-10-20-PROXY-LAB-CONSUMER.md)。

当前两入口对照：[配对校验、三组清单模板与比较工具](../archive/handoffs/2026-09/2026-09-14-NAS-PAIRED-COMPARISON.md)。使用 playback_compare_entries.py；历史 Auto/Force 工具不检查配对条件，不能代替此流程。

2026-11-09 三入口对照：原清单仍可直接使用。要加网络存储，在顶层加 `networkStorageProtocol`（`smb`、`ftp` 或 `webdav`），每个 `pairID` 再加入 `entry: "networkStorage"` 的观测，在其 `conditions.sourceProtocol` 填已核实的实际协议。每批只用一种存储协议，SMB/FTP 只做内网。沿用同片版本、同轨道、同落点、同设备、同网络、同构建和缓存状态，另外要求三个入口记录相同的实际 `routeKind`。至少三组完整记录才汇总内部播放时钟；缺项、失败、重复和跨路线观测不会进入统计。屏幕首帧、续播画面、跳转恢复及音字幕实际输出仍须各自取证。

2026-11-09 落点校验使用同一 trace 和 plan 的 `engine_startup_timing.initialPositionSeconds`。用新版 `playback_trace_report.py` 从原始导出重新生成报告，再运行配对工具。报告起点与清单 `startSeconds` 的误差须在 0.05 秒内，缺失或互相矛盾的起点保留为无效记录。书签快照、滑块比例、首个时钟位置仍可用于诊断，配对起点使用引擎记录。

2026-09-14 报告工具更新：[trace/plan 严格归属与未归属事件清单](../archive/handoffs/2026-09/2026-09-14-NAS-TRACE-ASSOCIATION.md)。缺会话身份的测速不再借用，旧日志兼容模式单独标识；同条件性能比较仍需补齐样本/轨道/断点/网络/构建证据。

2026-09-14：按 [分层流程](playback-development-workflow.md) 执行离线诊断。本文 Auto/Force、旧模拟器和策略假设属于历史工作流，须先与当前 Swift 策略核对；现行两入口比较必须按 trace、轨道、位置、网络、构建及实际原画/HLS 配对。脚本运行成功不等于策略已对齐或真机通过。

This note covers playback work that can be done without Xcode, WDA, or an iOS
device. The goal is to make the next real-device run a validation pass instead
of a trial-and-error session.

## Trace Report

Use `scripts/playback_trace_report.py` on an exported Nastart diagnostic log:

```sh
python3 scripts/playback_trace_report.py 文本.txt
```

The report groups Greenfield playback events into route-level traces and shows:

- `playbackTraceID` when available, so route selection, Jellyfin preparation,
  local proxy IO, and renderer first-frame logs can be tied to one tap;
- selected route, play method, and renderer;
- original-route decision and fallback reason;
- measured, selected, and source bitrate;
- tap-to-first-frame timing;
- slowest pre-first-frame media request, including HLS proxy role when available;
- KSPlayer state, playback-ended stage, playback-failed stage, and runtime
  failure snapshot when present;
- KSPlayer open/probe/track-selection breadcrumbs when present, including
  `avformat_open_input`, `avformat_find_stream_info`, `tracks selected`, early
  `av_read_frame packet`, and read EOF state;
- inferred bottleneck and the next diagnostic action.

Machine-readable output is available for diffing two runs:

```sh
python3 scripts/playback_trace_report.py --json 文本.txt
```

To compare the two intended device runs directly:

```sh
python3 scripts/playback_compare_runs.py \
  --auto auto-log.txt \
  --force force-ksplayer-log.txt
```

## Policy Simulator

Use `scripts/playback_policy_simulator.py` to predict Jellyfin route selection
before a device run:

```sh
python3 scripts/playback_policy_simulator.py --preset jellyfin-external-large-mkv
```

The simulator prints both the normal Auto policy and the DEBUG-only Force
original KSPlayer policy. It mirrors the current Nastart rules:

- private routes use a high direct-play budget;
- measured public routes use an 80% safe bitrate for HLS;
- Wi-Fi direct play gets a short burst allowance;
- oversized public originals fall back to Jellyfin HLS;
- TrueHD/MLP/AC4/DTS-HD/EAC3-JOC/Atmos require compatibility conversion unless
  the DEBUG experimental original path is enabled;
- image subtitles such as PGS require server rendering unless the DEBUG
  experimental original path is enabled.

## Current 2026-09-04 Real-Device Finding

The iPhone 13 run used `碟中谍3`, a roughly 54 GB / 62.7 Mbps 4K REMUX MKV, as
the representative large-file target.

Auto selected `localHLS / localRemux / systemAVPlayer` because of
`largeRemoteOriginalRisk`. It did play, and the trace recorded
`tapToFirstFrameMs=7791`, with playback continuing through the 30 second WDA
checkpoint.

Force original KSPlayer selected the intended diagnostic route,
`localRangeProxy / directPlay / ksPlayer`, and Jellyfin served the first MKV
range as a valid `206` response. KSPlayer still reported
`ksPlayerFinishedBeforeFirstFrame`. The failure snapshot showed `ready=no`,
`playing=no`, `seekable=no`, `duration=0`, `playable=0`, and `displayFPS=0`.

Follow-up Force probes narrowed this further. Presenting the local proxy as
`continuousRange` and allowing `seekable=1` still failed before first frame.
FFmpeg reached `avformat_find_stream_info succeeded format=matroska,webm
streams=12`, but packet-probe logging then reported
`KSPlayer: tracks selected video=no audio=no all=[]`. The current sharp target
is therefore not generic first-frame latency; it is why the vendored KSPlayer
does not construct usable `FFmpegAssetTrack` objects for this Matroska REMUX
after FFmpeg has already identified the streams.

That means this is not yet a first-frame-speed comparison. Force original must
first reach playable startup. The next code work should target the missing
competitor-style IO/cache/preload layer for KSPlayer original playback, with
the immediate next step focused on Matroska stream-to-track construction rather
than more route-selection tweaks.

## Next Device Run Contract

The next device run should compare two explicit modes:

- Auto: validates the production route policy and Jellyfin HLS startup.
- Force original KSPlayer: validates whether KSPlayer can open the same source
  faster, while separately checking whether sustained playback stalls. For MKV
  startup, the current diagnostic route uses local `continuousRange` responses
  with `seekable=1`, so FFmpeg can probe the Matroska head and tail/cues.

The DEBUG Jellyfin playback screen exposes a `Force original KSPlayer` toggle.
Leave it off for the Auto run, then enable it for the A/B run. The exported log
should contain the same `playbackTraceID` across `playback_preparing`,
`playback_prepared`, `route_selected`, proxy transfer events, and
`next.first_frame`. It should also contain `experimentalOriginal=yes` for the
second mode. If that second run still reports `localHLS / systemAVPlayer`, the
original route was either unavailable or the launch did not use the experimental
setting.

## HLS Proxy Timing Fields

Newer builds add these fields to local proxy transfer diagnostics:

- `proxyKind`: `hlsPlaylist`, `hlsChild`, or `mediaRange`.
- `hlsRole`: `masterPlaylist`, `mediaPlaylist`, `segment`, `key`, or `-`.
- `pathExtension`: the upstream URL extension, when visible.
- `upstreamTaskIndex`: the nth upstream request used by one client request.

These fields make it possible to tell whether tap-to-first-frame is dominated
by the initial playlist, a child playlist, the first segment, or a bounded Range
continuation. Older exported logs do not contain these fields; the trace report
will show `-/-` for their slow request role.

## Continuous Telemetry Samples

Newer Greenfield builds also emit `diagnostics.playback.next.telemetry_sample`
roughly once per second during playback, plus forced samples on state changes,
first frame, finish, and view disappearance.

For AVPlayer routes, samples include:

- `timeControlStatus` and `reasonForWaiting`;
- playback `currentSeconds` and `deltaSeconds`;
- `bufferAheadSeconds`, `bufferEmpty`, and `likelyToKeepUp`;
- AVPlayer access-log fields such as `observedBitrate`, `indicatedBitrate`,
  `accessLogStalls`, transferred bytes, and derived throughput.

For KSPlayer routes, samples include:

- `ksPlayerState`;
- sanitized playback `currentSeconds`, `deltaSeconds`, and `durationSeconds`;
- KSPlayer buffer callback values, including `bufferedCount` and `consumeMs`;
- inferred stall state from buffering/state/progress.

The trace report summarizes these samples as `telemetry`, including sample
count, stall sample count, minimum buffer ahead, observed bitrate, and access-log
throughput where available.

KSPlayer-specific failure modes are reported before the generic missing
first-frame bucket:

- `ksplayer_invalid_clock`: KSPlayer emitted an implausible current/duration
  timestamp, so the app ignored that tick for first-frame and progress timing.
- `ksplayer_premature_end`: KSPlayer reported finish before a plausible
  first-frame/progress point, usually worth comparing against local Range status
  and KSPlayer open/probe/decode logs. If the run includes
  `tracks selected video=no audio=no all=[]`, inspect `FFmpegAssetTrack` stream
  filtering and codec/format-description construction before changing buffer
  sizing.
- `large_remote_original_hls`: Auto intentionally avoided remote original
  playback for a large MKV/REMUX source; use this as the systemAVPlayer/HLS
  baseline and keep Force original KSPlayer as the decoder stress test.
