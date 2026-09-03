# Playback Offline Diagnostics

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
