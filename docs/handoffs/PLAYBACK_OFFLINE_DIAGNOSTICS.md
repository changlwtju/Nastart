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

## Current 2026-09-03 Log Finding

For the attached `文本.txt`, the trace report found seven Greenfield playback
traces. All seven selected `localHLS / localRemux / systemAVPlayer`, and all
seven skipped original playback with `automaticBitrateBudget`.

The 62.7 Mbps MKV sample on a roughly 10.8 Mbps measured cellular route is
therefore not evidence that KSPlayer is slow. It is evidence that Nastart's Auto
policy selected Jellyfin HLS before KSPlayer had a chance to open the original
stream.

## Next Device Run Contract

The next device run should compare two explicit modes:

- Auto: validates the production route policy and Jellyfin HLS startup.
- Force original KSPlayer: validates whether KSPlayer can open the same source
  faster, while separately checking whether sustained playback stalls.

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
- playback `currentSeconds`, `deltaSeconds`, and `durationSeconds`;
- KSPlayer buffer callback values, including `bufferedCount` and `consumeMs`;
- inferred stall state from buffering/state/progress.

The trace report summarizes these samples as `telemetry`, including sample
count, stall sample count, minimum buffer ahead, observed bitrate, and access-log
throughput where available.
