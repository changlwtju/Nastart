# ADR 0001: Design Video Playback as a Greenfield Architecture

Date: 2026-09-01

## Status

Proposed

## Context

Nastart's current playback implementation can remain available in the app, but
it should no longer define the architecture direction for video playback.

Competitor analysis of DS One and Lenna shows a shared playback model:

- media-source negotiation before player creation;
- explicit `PlaybackInfo` / `MediaSource` / `MediaStream` modeling;
- an IO layer for Range, cache, seek, and preload;
- a player engine layer that can choose AVPlayer or FFmpeg-backed rendering;
- unified subtitle, audio-track, PiP, progress, logging, and diagnostics
  coordination.

The current task is to design Nastart's video playback as a new subsystem,
using those competitor-derived playback ideas as the primary reference.

## Decision

Create a new greenfield video playback architecture.

The new architecture will be centered on:

- `PlaybackIntent`
- `SourceResolver`
- `PlaybackPlan`
- `PlaybackRoute`
- `PlaybackIOContext`
- `RangeCacheStore`
- `PreloadCoordinator`
- `PlaybackEngine`
- `TrackCatalog`
- `SubtitlePlan`
- `PlaybackDiagnostics`

Playback plans will also carry explicit performance and experience policies for
startup, track switching, Picture in Picture, and weak-network recovery. In
particular, cold start must prioritize first frame over large startup preload on
cellular or constrained networks.

KSPlayer will be treated as the first serious engine candidate. System AVPlayer
will remain part of the architecture for HLS, MP4, PiP, AirPlay, background
playback, and local HLS/remux outputs. A Lenna-style local HLS/remux path will
be evaluated after the core plan/IO/engine boundaries are in place.

The existing playback path is not the design foundation. During exploration it
must run as a separate A/B experience, not as an in-process fallback inside the
new player. DEBUG builds can expose a switch that launches either the existing
player or the greenfield player from the same media detail page. Once launched,
each path owns its own session, policy, diagnostics, controls, and engine
integration.

## Consequences

Positive:

- The new design can model Range/cache/preload directly instead of inheriting
  page-level playback workarounds.
- KSPlayer and local HLS/remux can be evaluated with a clean contract.
- Media-source decisions, tracks, subtitles, and diagnostics become first-class
  concepts.
- First-frame latency, weak-network behavior, audio/subtitle switch latency, and
  PiP capability become measurable plan-level policies instead of ad hoc UI
  behavior.
- Future DSM, SMB, WebDAV, local file, URL, and cloud-drive playback can enter
  the same model.

Negative:

- The first usable prototype takes longer than another targeted patch.
- Some current fixes may need to be rediscovered and revalidated as general
  rules.
- Third-party engine licensing, package size, build stability, and App Store
  review risk must be assessed before release use.

## First Milestone

1. Add pure Swift playback model types.
2. Generate a `PlaybackPlan` for Jellyfin S01/S03 inside a separate greenfield
   player experience without taking over release playback.
3. Add diagnostics for route selection, Range probe, first frame, seek recovery,
   and cache/preload observations.
4. Build a KSPlayer spike against `PlaybackPlan.primaryRoute` inside the
   greenfield path.
5. Compare against existing playback through the DEBUG A/B switch, using the
   existing player only as a measurement baseline.

## References

- [Nastart 视频播放新架构设计草案](../handoffs/2026-09-01-NASTART-GREENFIELD-PLAYBACK-ARCHITECTURE.md)
- [Lenna 1.0.17 静态分析阶段记录](../handoffs/2026-09-01-LENNA-1.0.17-STATIC-ANALYSIS.md)
- [DS One 视频播放链路证据基线](../handoffs/2026-08-27-DSONE-PLAYBACK-CHAIN-BASELINE.md)
