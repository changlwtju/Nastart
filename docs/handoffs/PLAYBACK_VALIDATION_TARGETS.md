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

- source bitrate: about 62.7 Mbps
- measured external route: about 10.8 Mbps
- network: cellular/expensive or similarly constrained WAN
- audio: TrueHD-like compatibility-risk track
- subtitle: ASS text subtitle selected

Offline policy prediction:

```sh
python3 scripts/playback_policy_simulator.py --preset jellyfin-external-large-mkv
```

Expected policy split:

- Auto: `localHLS / localRemux / systemAVPlayer`, normally because
  `automaticBitrateBudget` blocks original playback.
- Force original KSPlayer: `localRangeProxy / directPlay / ksPlayer`.

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

Decision rules:

- Auto slow, Force original fast, Force stable:
  consider an explicit original-quality mode.
- Auto slow, Force original fast, Force stalls:
  original opens quickly but cannot sustain WAN throughput; keep Auto
  conservative and improve HLS startup.
- Auto slow, slowest request is `hlsPlaylist/*` or `hlsChild/mediaPlaylist`:
  target Jellyfin playlist negotiation/fetch timing.
- Auto slow, slowest request is `hlsChild/segment`:
  target first segment delivery, reverse proxy, or Jellyfin remux startup.
- Force original slow, no slow proxy request:
  add deeper KSPlayer open/probe/decode timestamps before changing buffer flags.

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
- `tapToFirstFrameMs`
- `telemetry_sample`
- `bufferAheadSeconds`
- `stallActive`
- `proxyKind`
- `hlsRole`
- `upstreamTaskIndex`

If any of these are absent from a new DEBUG build, fix instrumentation before
using the run to make playback-policy decisions.
