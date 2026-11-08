# Playback Validation Targets

2026-10-19：当前按容量/格式、设备/网络、双入口及问题选择测试的规范见[真机矩阵当前执行版](PLAYBACK-FUNCTION-MATRIX.md)。当前蜂窝等待的阶段证据和待实施方案见[技术路线](../architecture/VIDEO_PLAYBACK_PIPELINE.md)；下文2026-09网络不可用及Auto/Force环境不能覆盖当前现场。

2026-09-14：当前目标、代表集与退出条件见 [播放开发与分层回归流程](../development/playback-development-workflow.md)，产品范围以唯一任务总账为准。以下 9 月 3～5 日 Auto/Force 目标与命令保留为历史证据，不作为现行操作步骤、网络可用性判断或生产选流依据。当前比较以 Greenfield 内设备文件/Jellyfin 的实际路线和同条件样本为准；网络须在执行时确认，本次 NAS 无真机条件。

> 2026-09-06：架构范围遵循 [ADR 0002](../adr/0002-single-playback-optimization-mainline.md)。正式矩阵集中验证新架构；旧架构仅作回退与关键里程碑对照。Force original 是历史策略测试项，不再作为第三种架构或常规 UI 选项。

Date: 2026-09-03

This file defines the concrete real-device targets for the Jellyfin playback
work. It exists to keep the debugging loop hypothesis-driven instead of
trial-and-error driven.

## Debugging model

The route is:

```text
real iPhone/iPad playback
  -> in-app telemetry and diagnostic log
  -> optional WDA screenshot/video evidence
  -> offline trace report and Auto-vs-KSPlayer comparison
  -> targeted code change
```

WDA is useful for operating the device and preserving visual proof. It is not
the primary source for timing, buffering, bitrate, or stall decisions.

## Network matrix (added 2026-09-05)

Current execution constraint: the user reports NAS Internet access is broken.
Only LAN NAS connections are authorized for the current debugging run. External
Wi-Fi/cellular cases remain pending until connectivity is restored; do not retry
public endpoints or use these failures to judge player performance.

Each architecture comparison must stay within one network condition. Run the
same media, audio/subtitle selection, start position and cache condition on both
architectures; record the actual chosen engine and route independently of the
Auto/Force switch.

| Condition | Phone connection | NAS endpoint/path | Status on 2026-09-05 |
| --- | --- | --- | --- |
| LAN Wi-Fi | Same LAN as NAS | Private LAN address | Current iPhone 13 experiments |
| External Wi-Fi | A separate Internet connection | Public NAS endpoint | Pending matched A/B runs |
| External cellular | Wi-Fi disconnected; cellular data | Public NAS endpoint | Pending matched A/B runs |

Accessing a public domain from the NAS LAN may use NAT loopback or split DNS;
record that separately, not as external Wi-Fi. A loopback playback proxy says
nothing about the upstream network. Record its actual NAS route as well. An
artificially throttled LAN is a reproducible stress test, not a cellular result.

For every run record interface, public/private upstream route, TLS/proxy/HLS
policy, measured available throughput and RTT where available, NAS upload load,
other concurrent streams, and warm/cold cache conditions. Mark unavailable
jitter/loss measurements as unknown. Keep credentials and signed URLs out of
shared evidence.

Required outcomes per condition:

- Startup: tap-to-visible-frame evidence plus separately named engine-ready and
  advancing-playback-clock timestamps; do not equate the latter to a visible frame.
- Sustained playback: at least 30 seconds, then a longer representative run;
  stalls/count/total duration, buffer, throughput and failures, including proxy
  continuation boundaries for large files.
- Interaction: single tap reveals controls/settings, double tap pauses/resumes,
  horizontal seek submits once on release, seek-to-visible-frame latency, and
  seeking while paused preserves pause. Verify fit/fill and playback speed.
- Recovery: separate Wi-Fi/cellular transition, interruption and reconnection
  cases; record recovery time and whether the timeline is preserved.

Use at least three matched repeats for exploratory medians and preserve every
failure. Do not present a reliable P95 from three runs; collect at least twenty
per condition before reporting even an exploratory P95. DS one and Lenna should
use the same media/network/cache/start position where supported; document engine
or transport differences rather than inferring their implementation from UI speed.

## Target A: External large Jellyfin MKV

Purpose: decide whether the current first-frame pain is Jellyfin HLS startup,
local proxy startup, KSPlayer open/probe/decode, or sustained WAN throughput.

Known representative sample:

- title: `碟中谍3`
- source file: `Mission.Impossible.III.2006.2160p.BluRay.REMUX.DV.HEVC.TrueHD.5.1.mkv`
- source bitrate: about 62.7 Mbps
- size: about 54 GB
- measured external route: about 10.8 Mbps
- network: cellular/expensive or similarly constrained WAN
- audio: TrueHD-like compatibility-risk track
- subtitle: ASS text subtitle selected

Offline policy prediction:

```sh
python3 scripts/playback_policy_simulator.py --preset jellyfin-external-large-mkv
```

For the Wi-Fi/public-domain Mac run that reproduced the KSPlayer early-end
black screen, use:

```sh
python3 scripts/playback_policy_simulator.py --preset jellyfin-mission-impossible-iii-remux
```

If the device is on Wi-Fi but the Jellyfin endpoint is still a public domain or
WAN route, do not treat that as the LAN sanity target. Before a fresh route
measurement exists, the conservative public-Wi-Fi prediction is:

```sh
python3 scripts/playback_policy_simulator.py --preset jellyfin-wifi-unmeasured-large-mkv
```

Expected policy split:

- Auto: `localHLS / localRemux / systemAVPlayer`, normally because
  `automaticBitrateBudget`, `largeRemoteOriginalRisk`, or audio compatibility
  blocks original playback.
- Force original KSPlayer: `localRangeProxy / directPlay / ksPlayer`. For MKV
  startup, the current diagnostic route uses `continuousRange` local proxy
  responses with `seekable=1`, allowing FFmpeg to probe both the head and the
  Matroska tail/cues. It should still prefer a direct-playable startup audio
  track, for example TrueHD -> AC3, so the test isolates original-video
  KSPlayer startup rather than an unsupported selected-audio startup failure.

Device run:

1. Play once with `Force original KSPlayer` off.
2. Export diagnostics as `auto-log.txt`.
3. Play the same item with `Force original KSPlayer` on.
4. Export diagnostics as `force-ksplayer-log.txt`.
5. Compare:

```sh
python3 scripts/playback_compare_runs.py \
  --auto auto-log.txt \
  --force force-ksplayer-log.txt
```

Current iPhone 13 baseline from 2026-09-04:

- Auto trace `08381CF9`: `localHLS / localRemux / systemAVPlayer`,
  `reason=largeRemoteOriginalRisk`, `tapToFirstFrameMs=7791`, playback stable
  through the 30 second visual checkpoint.
- Force original traces `0E1DE462` and `A2096B61`:
  `localRangeProxy / directPlay / ksPlayer`, first `mkv` Range response was
  valid `206` for `bytes=0-33554431`, but KSPlayer reported
  `ksPlayerFinishedBeforeFirstFrame` with no first frame and no playable
  duration.
- Follow-up Force transport probes:
  `continuousRange` and `seekable=1` let FFmpeg reach
  `avformat_find_stream_info succeeded format=matroska,webm streams=12`, but
  KSPlayer still ended before first frame. The packet-probe trace `F32440AF`
  then showed `KSPlayer: tracks selected video=no audio=no all=[]`, which
  points at Matroska stream-to-`FFmpegAssetTrack` construction rather than
  first-frame latency or raw Range open failure.
- Evidence files:
  `/tmp/nastart-mi3-auto-snapshot.log`,
  `/tmp/nastart-mi3-force-ksplayer-snapshot.log`,
  `/tmp/nastart-mi3-force-ksplayer-seekable-continuous.log`,
  `/tmp/nastart-mi3-force-ksplayer-packet-probe.log`,
  `/tmp/nastart-mi3-auto-snapshot-t30.png`,
  `/tmp/nastart-mi3-force-snapshot2-t30.png`.

Current decision:

- Do not compare Force original first-frame latency yet. The Force route reaches
  KSPlayer, but it does not reach playable startup.
- Keep Auto conservative for this sample until Force original can play.
- The next Force work should follow the competitor-derived playback chain:
  media-source decision, then KSPlayer-compatible IO/cache/preload, then engine
  startup and telemetry. The missing piece is not route selection anymore; the
  current sharp target is why `FFmpegAssetTrack(stream:)` rejects all streams
  after FFmpeg has identified 12 Matroska streams.

Decision rules:

- Auto slow, Force original fast, Force stable:
  consider an explicit original-quality mode.
- Auto HLS plays and Force original shows `ksplayer_premature_end`:
  keep Auto on HLS for this large remote MKV class and continue KSPlayer as an
  explicit diagnostic path only.
- Auto slow, Force original fast, Force stalls:
  original opens quickly but cannot sustain WAN throughput; keep Auto
  conservative and improve HLS startup.
- Auto slow, slowest request is `hlsPlaylist/*` or `hlsChild/mediaPlaylist`:
  target Jellyfin playlist negotiation/fetch timing.
- Auto slow, slowest request is `hlsChild/segment`:
  target first segment delivery, reverse proxy, or Jellyfin remux startup.
- Force original slow, no slow proxy request:
  add deeper KSPlayer open/probe/decode timestamps before changing buffer flags.
- Force original reports `ksplayer_invalid_clock`:
  inspect KSPlayer current/duration propagation before using first-frame timing.
- Force original reports `ksplayer_premature_end`:
  inspect KSPlayer open/probe/decode timing plus the first local Range response.
  If packet-probe logs show `tracks selected video=no audio=no all=[]`, inspect
  codec parameters, codec IDs, format-description creation, and stream filtering
  in `FFmpegAssetTrack`.

## Target B: Remote 4K-ish Jellyfin MKV with better WAN sample

Purpose: see whether the bitrate gate remains too conservative when measured
WAN is better but source bitrate is still above the direct budget.

Offline prediction:

```sh
python3 scripts/playback_policy_simulator.py --preset jellyfin-remote-4k-mkv
```

This target is useful after Target A confirms whether Force original is viable.

## Target C: LAN original route sanity check

Purpose: confirm that the original playback path itself is healthy when the NAS
is reachable on a private route and bandwidth is not the bottleneck.

Offline prediction:

```sh
python3 scripts/playback_policy_simulator.py --preset jellyfin-lan-original
```

Expected result:

- Auto and Force original should both be able to attempt original playback.
- If LAN original is slow or unstable, do not tune WAN HLS yet; first fix the
  direct original/Range/KSPlayer path.

## Required exported-log fields

New logs should include:

- `playbackTraceID`
- `experimentalOriginal`
- `routeKind`
- `playMethod`
- `decodeEngine`
- `largeRemoteOriginalRisk`
- `tapToFirstFrameMs`
- `telemetry_sample`
- `playback_ended`
- `playback_failed`
- `bufferAheadSeconds`
- `stallActive`
- `invalidPlaybackTime`
- `proxyKind`
- `hlsRole`
- `upstreamTaskIndex`
- `ksPlaybackState`
- `ksLoadState`
- `ksReady`
- `ksSeekable`
- `ksCurrentSeconds`
- `ksDurationSeconds`
- `ksPlayableSeconds`
- `ksDisplayFPS`
- `KSPlayer: tracks selected ...`
- `KSPlayer: av_read_frame packet ...`

If any of these are absent from a new DEBUG build, fix instrumentation before
using the run to make playback-policy decisions.
