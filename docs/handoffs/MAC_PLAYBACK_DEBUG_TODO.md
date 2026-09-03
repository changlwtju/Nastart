# Mac Playback Debug Handoff

Date: 2026-09-03

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
  - Force original KSPlayer: direct original/Range-proxy attempt using KSPlayer.
- Greenfield playback now emits continuous
  `diagnostics.playback.next.telemetry_sample` events.
- Local proxy transfer diagnostics now classify slow requests with
  `proxyKind`, `hlsRole`, `pathExtension`, and `upstreamTaskIndex`.
- Offline scripts were added/updated:
  - `scripts/playback_trace_report.py`
  - `scripts/playback_policy_simulator.py`
  - `scripts/playback_compare_runs.py`
  - `docs/handoffs/PLAYBACK_OFFLINE_DIAGNOSTICS.md`
  - `docs/handoffs/PLAYBACK_VALIDATION_TARGETS.md`

## What to do on the Mac

1. Open the iOS project in Xcode and build the DEBUG app.
2. If Xcode reports compile errors, fix those first; this NAS environment cannot
   run Swift/Xcode.
3. Install on the same iPhone/iPad used for Jellyfin testing.
4. Pick one large external-network Jellyfin video, preferably the previous
   62.7 Mbps MKV sample.
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

## What to look for

- If Auto shows `localHLS / systemAVPlayer` with
  `reason=automaticBitrateBudget`, that is expected for oversized external
  videos. The bottleneck is Jellyfin HLS/proxy startup, not KSPlayer.
- If Force original shows `localRangeProxy / directPlay / ksPlayer`, then
  KSPlayer is finally being tested against the original source.
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
- Direct original fast but stalls later: keep Auto conservative and consider
  an explicit user-facing "original quality" mode instead of making it default.
