# Mac Playback Debug Handoff

> **新对话从这里继续：[2026-09-06 最新任务交接](2026-09-06-NEXT-CHAT-PLAYBACK.md)**。HLS 内容时间映射仍未关闭，包含代码/设备/凭据证据边界与下一步。

> 2026-09-06 已确定：[新架构唯一优化主线](../adr/0002-single-playback-optimization-mainline.md)。旧架构仅作回退，验收后移除；新旧两项选择取代此前 Greenfield/Force 调试开关。后文历史测试记录不改变此决策。

Date: 2026-09-03

## 2026-09-05 continuation — read first

The empty KSPlayer tracks were traced to FFmpeg ABI mixing: app-side calls
bound to MobileVLCKit's FFmpeg while using FFmpegKit headers. KSPlayer now has
a separate dynamic framework and an install-time linkage check. Device MKV
startup works. S03 Force/localRangeProxy reaches first frame (1648 ms on LAN)
but stalls near 14 seconds; legacy direct playback advances past 3 minutes.
Final DEBUG Auto uses validated private source URLs directly (HTTPS certificate
compatibility and Force still use the proxy). S03 resume trace 9326BF97 reaches
startup at 1599 ms, passes the 30-second checkpoint, and has 55 telemetry samples
with no stalls. This resume run does not close the Force/from-start stall.
Do not keep tuning stream filtering for the old empty-track symptom.

See [the device evidence and architecture migration gates](./2026-09-05-IPHONE13-PLAYBACK-ARCHITECTURE-REVIEW.md).
This also defines the evaluation beyond startup and recommends focusing
development on greenfield while retaining legacy as a frozen baseline until
correctness, stability, coverage, and lifecycle gates pass.

This handoff is intentionally written into the repo so the next Mac/Xcode
session continues the playback work from the telemetry path, not from the old
"control device with WDA and infer from screenshots" loop.

## Principle

Screenshots are only visual evidence. They are useful for confirming black
screen, wrong orientation, subtitles, or obvious UI state. They are not precise
enough to diagnose first-frame latency, HLS segment startup, Range proxy stalls,
or decoder buffering.

The main loop should be:

1. Play on a real iPhone/iPad.
2. Let Nastart emit playback telemetry inside the app.
3. Export the diagnostic log.
4. Analyze it locally with `scripts/playback_trace_report.py`.
5. Change code only after the trace points at a specific bottleneck.

## What changed before the Mac session

- Jellyfin playback now creates a short `playbackTraceID` per playback tap.
- `playbackTraceID` is carried through Jellyfin route decision logs, prepared
  playback logs, Greenfield route selection, renderer diagnostics, and local
  proxy transfer logs.
- DEBUG Jellyfin playback has a `Force original KSPlayer` toggle so the same
  source can be tested in two explicit modes:
  - Auto policy: production route selection.
  - Force original KSPlayer: direct original/local Range proxy attempt using
    KSPlayer. The current debug route uses a local Range proxy with
    `continuousRange` responses and seekable MKV startup, so FFmpeg can probe
    both the file head and Matroska tail/cues before the first frame.
- Greenfield playback now emits continuous
  `diagnostics.playback.next.telemetry_sample` events.
- KSPlayer playback ticks are sanitized before they can count as first-frame or
  progress evidence, so implausible timestamps are logged as
  `invalidPlaybackTime` instead of poisoning the trace.
- KSPlayer `playedToTheEnd` before a plausible first frame is treated as
  `ksPlayerFinishedBeforeFirstFrame`/`ksPlayerPrematureEnd`, which can trigger
  alternate-route fallback and is visible in offline trace reports.
- Local proxy transfer diagnostics now classify slow requests with
  `proxyKind`, `hlsRole`, `pathExtension`, and `upstreamTaskIndex`.
- Offline scripts were added/updated:
  - `scripts/playback_trace_report.py`
  - `scripts/playback_policy_simulator.py`
  - `scripts/playback_compare_runs.py`
  - `docs/handoffs/PLAYBACK_OFFLINE_DIAGNOSTICS.md`
  - `docs/handoffs/PLAYBACK_VALIDATION_TARGETS.md`

## 2026-09-04 iPhone 13 Result

The DEBUG build was compiled and installed on iPhone 13
(`00008110-001E543122E0401E`, iOS 16.3.1). WDA was used only to operate the UI
and preserve visual evidence; the decision source is still the in-app playback
trace.

Target sample:

- `碟中谍3`
- `Mission.Impossible.III.2006.2160p.BluRay.REMUX.DV.HEVC.TrueHD.5.1.mkv`
- about 54 GB / 62.7 Mbps

Auto baseline:

- trace: `08381CF9`
- route: `localHLS / localRemux / systemAVPlayer`
- decision: `originalRangeSkipped`, `reason=largeRemoteOriginalRisk`
- prepared stream: `serverNegotiatedHLS`, `transport=localHLSProxy`
- first frame: `tapToFirstFrameMs=7791`
- playback stayed live past the 30 second screenshot checkpoint
- evidence:
  - log: `/tmp/nastart-mi3-auto-snapshot.log`
  - screenshots: `/tmp/nastart-mi3-auto-snapshot-t5.png`,
    `/tmp/nastart-mi3-auto-snapshot-t15.png`,
    `/tmp/nastart-mi3-auto-snapshot-t30.png`

Force original KSPlayer:

- traces: `0E1DE462`, `A2096B61`
- route: `localRangeProxy / directPlay / ksPlayer`
- prepared stream: `jellyfinOriginalDirectPlay`, `transport=localRangeProxy`
- compatible startup audio was selected: TrueHD -> AC3
- first local response was valid HTTP Range:
  `bytes 0-33554431/54005939750`, `status=206`
- first frame: none
- failure: `ksPlayerFinishedBeforeFirstFrame`
- KSPlayer snapshot at failure:
  `state=idle`, `load=idle`, `ready=no`, `playing=no`, `seekable=no`,
  `current=0`, `duration=0`, `playable=0`, `displayFPS=0`
- 5/15/30 second WDA screenshots all stayed on `无法播放媒体` with
  `KSPlayer ended early`
- evidence:
  - log: `/tmp/nastart-mi3-force-ksplayer-snapshot.log`
  - screenshots: `/tmp/nastart-mi3-force-snapshot2-t5.png`,
    `/tmp/nastart-mi3-force-snapshot2-t15.png`,
    `/tmp/nastart-mi3-force-snapshot2-t30.png`

Follow-up Force transport probes:

- `continuousRange` local proxy response did not fix startup by itself.
- `seekable=1` for MKV startup allowed FFmpeg to open and probe the file:
  `avformat_open_input` started successfully, `avformat_find_stream_info`
  succeeded with `format=matroska,webm` and `streams=12`.
- The failure still happened before first frame. KSPlayer snapshots showed
  `seekable=yes`, `duration=0`, `playable=0`, and then `playedToTheEnd`.
- Packet-probe evidence from trace `F32440AF` showed the sharper failure:
  `KSPlayer: tracks selected video=no audio=no all=[]`. In other words, FFmpeg
  recognized the container, but Nastart's vendored KSPlayer did not materialize
  usable `FFmpegAssetTrack` instances for this Matroska REMUX.
- evidence:
  - `/tmp/nastart-mi3-force-ksplayer-continuous.log`
  - `/tmp/nastart-mi3-force-ksplayer-seekable-continuous.log`
  - `/tmp/nastart-mi3-force-ksplayer-packet-probe.log`

Conclusion:

- The current question cannot yet be "is Force KSPlayer faster than Auto?".
  Force KSPlayer does reach the intended original-video route, but it does not
  reach playable startup or emit `first_frame`.
- The immediate target is to make `localRangeProxy / directPlay / ksPlayer`
  play the large MKV at all. Only after it records first frame should it be
  compared against Auto's 7791 ms baseline.
- The competitor-derived architecture should guide the next code change:
  `PlaybackInfo/MediaSource decision -> IO/cache/preload -> engine -> unified
  telemetry`. Nastart currently has the decision and telemetry layers; the
  next missing piece is now narrower than generic route selection: inspect why
  KSPlayer/`FFmpegAssetTrack` rejects all Matroska streams after FFmpeg reports
  12 streams, then continue toward a KSPlayer-compatible IO/cache/preload path.

## What to do next

1. Open the iOS project in Xcode and build the DEBUG app.
2. If Xcode reports compile errors, fix those first; this NAS environment cannot
   run Swift/Xcode.
3. Install on the same iPhone/iPad used for Jellyfin testing.
4. Pick one large external-network Jellyfin video. Prefer `碟中谍3`
   (`Mission.Impossible.III.2006.2160p.BluRay.REMUX.DV.HEVC.TrueHD.5.1.mkv`),
   the 54 GB / roughly 62.7 Mbps 4K REMUX sample that reproduced the
   KSPlayer early-end black screen.
5. Run the Auto policy test:
   - Leave `Force original KSPlayer` off.
   - Start playback.
   - Wait until first frame and then keep it playing for at least 30 seconds.
   - If it stalls, wait through the stall rather than stopping immediately.
   - Export diagnostics.
6. Run the Force original KSPlayer test:
   - Enable `Force original KSPlayer`.
   - Start the same video from the same network condition.
   - Again capture first frame plus at least 30 seconds.
   - Export diagnostics.
7. Copy both exported logs back to the repo/workspace and run:

```sh
python3 scripts/playback_trace_report.py auto-log.txt
python3 scripts/playback_trace_report.py force-ksplayer-log.txt
```

Use `--json` if comparing two runs programmatically:

```sh
python3 scripts/playback_trace_report.py --json auto-log.txt
python3 scripts/playback_trace_report.py --json force-ksplayer-log.txt
```

For the intended Auto-vs-Force comparison, run:

```sh
python3 scripts/playback_compare_runs.py \
  --auto auto-log.txt \
  --force force-ksplayer-log.txt
```

Before running on device, confirm the expected route split with:

```sh
python3 scripts/playback_policy_simulator.py --preset jellyfin-external-large-mkv
```

If the iPhone is on Wi-Fi but the Jellyfin endpoint is still the public/WAN
domain, also check the no-fresh-sample fallback:

```sh
python3 scripts/playback_policy_simulator.py --preset jellyfin-wifi-unmeasured-large-mkv
```

For the current `碟中谍3` Wi-Fi/public-domain target:

```sh
python3 scripts/playback_policy_simulator.py --preset jellyfin-mission-impossible-iii-remux
```

## What to look for

- If Auto shows `localHLS / systemAVPlayer` with
  `reason=automaticBitrateBudget` or `reason=largeRemoteOriginalRisk`, that is
  expected for oversized external videos. The bottleneck is Jellyfin HLS/proxy
  startup, not KSPlayer.
- If Force original shows `localRangeProxy / directPlay / ksPlayer`, then
  KSPlayer is being tested against the original source through the authenticated
  Range proxy.
- If Force original logs `avformat_find_stream_info succeeded` but then
  `tracks selected video=no audio=no all=[]`, focus on
  `FFmpegAssetTrack(stream:)` and codec/format-description construction before
  changing buffering or route policy.
- Compare:
  - `tapToFirstFrameMs`
  - `telemetry.sampleCount`
  - `telemetry.stallSampleCount`
  - `telemetry.minBufferAheadSeconds`
  - slowest pre-first-frame `proxyKind/hlsRole`
  - AVPlayer `accessLogStalls` and observed bitrate when Auto uses AVPlayer
- A faster first frame with many later stalls means direct original opens fast
  but cannot sustain the external-network bitrate.
- A slow first frame where the slowest request is a playlist or first segment
  means Jellyfin HLS startup is the target.
- A slow first frame with `localRangeProxy / ksPlayer` and no slow proxy request
  points toward KSPlayer open/probe/decode timing.
- `ksplayer_invalid_clock` means KSPlayer returned an impossible current/duration
  value; inspect time propagation before trusting renderer timing.
- `ksplayer_premature_end` means KSPlayer finished before a plausible first
  frame/progress point; compare KSPlayer open/probe/decode logs with local-range
  response status.

## Do not regress to this old loop

Do not optimize by repeatedly changing cache/buffer/player flags based only on
WDA screenshots. WDA can still start playback and capture visual proof, but the
decision source should be the exported diagnostic trace.

The next useful code changes should be driven by the trace:

- HLS playlist/first-segment slow: optimize Jellyfin PlaybackInfo/HLS startup
  path or prefetch the first child playlist/segment.
- Range proxy slow: inspect upstream request windowing, authentication, and
  Range continuation timing.
- KSPlayer selected but slow before first frame: add KSPlayer-specific open,
  probe, ready, and first-frame timestamps before tuning FFmpeg options.
- KSPlayer invalid clock or premature end after `tracks selected ... all=[]`:
  inspect Matroska stream-to-`FFmpegAssetTrack` construction, codec IDs, codec
  parameters, and VideoToolbox format-description creation before changing cache
  sizes.
- Direct original fast but stalls later: keep Auto conservative and consider
  an explicit user-facing "original quality" mode instead of making it default.


## 2026-09-05 10:05 follow-up

Proxy diagnostics now preserve client-close versus upstream-completion origin and
per-task received bytes/Range boundaries. Force trace `EB157F5B` resumed at about
467 seconds, recorded 1964 ms startup and passed the 30-second checkpoint. Several
32 MiB upstream windows completed with contiguous offsets. This does not close the
from-zero 14-second stall. See the [architecture review](./2026-09-05-IPHONE13-PLAYBACK-ARCHITECTURE-REVIEW.md)
for evidence and the remaining track-selection and timing limitations.


## 2026-09-05 共用控制层与 LAN 限制

用户要求新架构复用原播放 UI。VLC/KSPlayer 现共用 `SharedBuiltInPlayerView`，字幕 ID 选择、暂停 seek 的时间/画面刷新和交互统计正在完成专项回归。NAS 外网当前异常，仅连接局域网；不要继续公网探测或把外网异常计作引擎性能失败。

继续前先读 [共用控制层专项记录](./2026-09-05-SHARED-PLAYBACK-CONTROLS.md)。正式 18×4 仍不能沿用旧构建的通过项；AVPlayer/HLS、PiP、续播与听测等未完成项保持待测。

- 2026-09-06 13:26：已完成连续统计修正的 iPhone LAN S01 复测及同条件旧 VLC 单次启动对照；另修复首帧位置被标为毫秒的指标错误，3 项报告回归测试通过，构建安装完成。最终 trace D45A3FF7：clock 1107 ms，恢复后 30.009637 秒 checkpoint，37 样本/0 stall；仍缺真实显示首帧测量。详见 `2026-09-05-SHARED-PLAYBACK-CONTROLS.md` 最新章节。下一步优先 S01 HLS/AVPlayer 完整 UI 与切换保位，四入口与其他网络条件未完成。

- 2026-09-06 14:54 新架构下一步：AVPlayer 已共用完整控件；修正 Jellyfin HLS 绝对时间轴、暂停空缓冲 stall 误判、切回 KS 的控制栏时间残留。最新构建 build-cross-engine-clock 已安装，LAN S01 实测 HLS 恢复/连续30秒/后退15秒/切回KS保留UI进度。仍有 **同一 clock 下 KS/AV 实际画面不同**，Q不能通过；下一步核对源帧PTS与暂停preview，再修跨引擎 pauseDuration 计时残留。详见 SHARED-PLAYBACK-CONTROLS 最新章节，证据 cross-final-*。

- 2026-09-06 15:28：新架构跨引擎会话计时修复已构建安装并完成 S01 LAN KS→HLS→KS 实测。最终 KS trace 59F0A45F 的暂停时长 9.493 秒，已验证属于本计划，不再沿用之前会话的 82 秒。HLS trace 543CAAB3 连续 30 秒、反向 seek clock 恢复 145 ms，含 1 waiting 样本。Q 仍被同一进度画面不同阻塞；下一步独立核对原始流参考帧与解码输出 PTS，详见共用控件交接最新段。不要重新实现已经存在的 HLS 控件，也不要回到旧架构优化。

- 2026-09-06 15:38：新架构 KS 帧 PTS 诊断发现暂停 seek 可提交目标之后 5.752 秒关键帧，已收紧 accurate demux 的 max_ts 并去掉秒数截断，构建安装完成。S01 11 个初始/正向/反向提交帧与目标最大偏差 30.665 ms（一帧内），HLS 持续 checkpoint 通过但仍有 1 waiting 样本。跨引擎同时间画面差异仍未关闭，下一步取 HLS 输出帧/源帧对照；见共享控件交接末尾。全程 LAN、新架构主线。
