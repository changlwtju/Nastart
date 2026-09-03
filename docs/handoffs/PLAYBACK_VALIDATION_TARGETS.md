# Playback Validation Targets

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
