#!/usr/bin/env python3
"""Summarize Nastart playback diagnostics into route-level traces."""

from __future__ import annotations

import argparse
import json
import math
import re
from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path


LINE_RE = re.compile(
    r"\[(?P<time>\d{4}-\d{2}-\d{2} [^\]]+)\]\s+(?P<level>\w+)\s+(?P<category>[^-]+?)\s+-\s+"
    r"(?P<message>.*?)(?:\s+\|\s+(?P<details>.*))?$"
)
DETAIL_RE = re.compile(r"\s*([^=,\s]+)=([^,]*)(?:,|$)")


@dataclass
class Event:
    line: int
    timestamp: datetime | None
    level: str
    category: str
    message: str
    details: dict[str, str]


@dataclass
class PlaybackTrace:
    started: Event
    route: Event
    first_frame: Event | None = None
    decision: Event | None = None
    prepared: Event | None = None
    bitrate: Event | None = None
    transfers: list[Event] = field(default_factory=list)
    warnings: list[Event] = field(default_factory=list)
    telemetry: list[Event] = field(default_factory=list)
    engine_events: list[Event] = field(default_factory=list)
    ended: list[Event] = field(default_factory=list)
    failures: list[Event] = field(default_factory=list)
    engine_start_positions: set[float] = field(default_factory=set)
    incomplete_startups: list[Event] = field(default_factory=list)

    @property
    def trace_id(self) -> str:
        return self.route.details.get("playbackTraceID") or "-"

    @property
    def plan_id(self) -> str:
        return self.route.details.get("planID") or "-"

    @property
    def route_id(self) -> str:
        return self.route.details.get("routeID", "-")


def parse_details(raw: str | None) -> dict[str, str]:
    if not raw:
        return {}
    result: dict[str, str] = {}
    position = 0
    while position < len(raw):
        match = DETAIL_RE.match(raw, position)
        if not match:
            break
        key, value = match.groups()
        result[key] = value.strip()
        position = match.end()
    return result


def parse_log(path: Path) -> list[Event]:
    events: list[Event] = []
    for line_no, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = LINE_RE.search(raw_line)
        if not match:
            continue
        timestamp: datetime | None
        try:
            timestamp = datetime.strptime(match.group("time"), "%Y-%m-%d %H:%M:%S")
        except ValueError:
            timestamp = None
        events.append(
            Event(
                line=line_no,
                timestamp=timestamp,
                level=match.group("level"),
                category=match.group("category").strip(),
                message=match.group("message").strip(),
                details=parse_details(match.group("details")),
            )
        )
    return events


def millis(value: str | None) -> float | None:
    if value in (None, "", "-"):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def integer(value: str | None) -> int | None:
    if value in (None, "", "-"):
        return None
    try:
        return int(value)
    except ValueError:
        return None


def nonnegative_measurement(value: str | None) -> float | None:
    number = millis(value)
    return number if number is not None and math.isfinite(number) and number >= 0 else None


def bitrate_label(value: str | None) -> str:
    if value in (None, "", "-"):
        return "-"
    try:
        return f"{int(value) / 1_000_000:.1f} Mbps"
    except ValueError:
        return value


def format_seconds(value: object) -> str:
    if isinstance(value, (float, int)):
        return f"{value:.1f}s"
    return "-"


def format_bitrate_value(value: object) -> str:
    if isinstance(value, (float, int)):
        return f"{value / 1_000_000:.1f} Mbps"
    return "-"


def format_mbps(value: object) -> str:
    if isinstance(value, (float, int)):
        return f"{value:.1f} Mbps"
    return "-"


def trace_field(trace: PlaybackTrace, source: str, key: str) -> str | None:
    event = {
        "route": trace.route,
        "decision": trace.decision,
        "prepared": trace.prepared,
        "bitrate": trace.bitrate,
        "first_frame": trace.first_frame,
    }.get(source)
    return event.details.get(key) if event else None


def build_traces(events: list[Event], unassigned: list[dict[str, object]] | None = None) -> list[PlaybackTrace]:
    traces: list[PlaybackTrace] = []
    last_decision: Event | None = None
    last_prepared: Event | None = None
    last_bitrate: Event | None = None
    decisions_by_trace_id: dict[str, Event] = {}
    prepared_by_trace_id: dict[str, Event] = {}
    bitrate_by_trace_id: dict[str, Event] = {}
    active_by_identity: dict[tuple[str | None, str | None], list[PlaybackTrace]] = {}
    active_trace: PlaybackTrace | None = None

    for event in events:
        mode = event.details.get("mode")
        trace_id = event.details.get("playbackTraceID")
        trace_id = trace_id if trace_id not in (None, "", "-") else None
        plan_id = event.details.get("planID")
        plan_id = plan_id if plan_id not in (None, "", "-") else None
        if "Jellyfin 连接码率测量完成" in event.message:
            last_bitrate = event
            if trace_id:
                bitrate_by_trace_id[trace_id] = event
        if mode in {
            "originalRangeSkipped",
            "originalRangeUnavailable",
            "serverHLSRequested",
            "fastStartupSubtitleDeferred",
        }:
            last_decision = event
            if trace_id and trace_id != "-":
                decisions_by_trace_id[trace_id] = event
        if mode in {
            "serverNegotiatedHLS",
            "serverNegotiatedTranscode",
            "serverNegotiatedDirectPlay",
        } or mode and mode.endswith("DirectPlay"):
            last_prepared = event
            if trace_id and trace_id != "-":
                prepared_by_trace_id[trace_id] = event

        if event.message == "diagnostics.playback.next.route_selected":
            def context(by_trace: dict[str, Event], legacy: Event | None) -> Event | None:
                candidate = by_trace.get(trace_id) if trace_id else legacy
                if candidate is None:
                    return None
                candidate_trace = candidate.details.get("playbackTraceID")
                candidate_plan = candidate.details.get("planID")
                if not trace_id and candidate_trace not in (None, "", "-"):
                    return None
                if candidate_plan not in (None, "", "-") and candidate_plan != plan_id:
                    return None
                return candidate

            active_trace = PlaybackTrace(
                started=event,
                route=event,
                decision=context(decisions_by_trace_id, last_decision),
                prepared=context(prepared_by_trace_id, last_prepared),
                bitrate=context(bitrate_by_trace_id, last_bitrate),
            )
            traces.append(active_trace)
            active_by_identity.setdefault((trace_id, plan_id), []).append(active_trace)
            # Unidentified legacy context applies only to the next route.
            last_decision = last_prepared = last_bitrate = None
            continue

        candidates = active_by_identity.get((trace_id, plan_id), []) if trace_id and plan_id else [
            trace
            for (known_trace, known_plan), matches in active_by_identity.items()
            if (trace_id is None or known_trace == trace_id)
            and (plan_id is None or known_plan == plan_id)
            for trace in matches
        ] if trace_id or plan_id else []
        if trace_id or plan_id:
            event_trace = candidates[0] if len(candidates) == 1 else None
        else:
            # Legacy fallback is limited to an unlabelled active route. It must
            # never attach an unidentified event to a modern identified session.
            event_trace = active_trace if active_trace and active_trace.trace_id == "-" and active_trace.plan_id == "-" else None

        if event_trace is None:
            if unassigned is not None and (
                event.message.startswith("diagnostics.playback.next.")
                or event.message in {"媒体兼容传输已开始", "媒体兼容传输已结束"}
                or event.level == "WARNING"
            ):
                unassigned.append({"line": event.line, "reason": "ambiguous_or_missing_identity"})
            continue

        if event.message == "diagnostics.playback.next.telemetry_sample":
            event_trace.telemetry.append(event)
            continue

        if event.message == "diagnostics.playback.next.engine_ready":
            event_trace.engine_events.append(event)
            continue

        if event.message == "diagnostics.playback.next.engine_startup_timing":
            position = nonnegative_measurement(event.details.get("initialPositionSeconds"))
            if trace_id and plan_id and position is not None:
                event_trace.engine_start_positions.add(position)
            continue

        if event.message == "diagnostics.playback.next.engine_startup_incomplete":
            if trace_id and plan_id:
                event_trace.incomplete_startups.append(event)
            elif unassigned is not None:
                unassigned.append({"line": event.line, "reason": "ambiguous_or_missing_identity"})
            continue

        if event.message == "diagnostics.playback.next.playback_ended":
            event_trace.ended.append(event)
            continue

        if event.message == "diagnostics.playback.next.playback_failed":
            event_trace.failures.append(event)
            continue

        if event.message == "diagnostics.playback.next.first_frame":
            if event_trace.first_frame is None:
                event_trace.first_frame = event
            continue

        if event.message == "媒体兼容传输已开始" or event.message == "媒体兼容传输已结束":
            if event_trace.first_frame is None:
                event_trace.transfers.append(event)
        if event.level == "WARNING" and event_trace.first_frame is None:
            event_trace.warnings.append(event)

    return traces


def classify_bottleneck(trace: PlaybackTrace) -> tuple[str, str, str]:
    route = trace.route.details
    decision = trace.decision.details if trace.decision else {}
    first = trace.first_frame.details if trace.first_frame else {}
    route_kind = route.get("routeKind", "-")
    engine = route.get("decodeEngine", "-")
    reason = decision.get("reason", "-")
    tap_ms = millis(first.get("tapToFirstFrameMs"))
    target_ms = millis(route.get("firstFrameTargetMs"))
    first_frame_ms = millis(first.get("rendererFirstFrameMs"))
    longest_request = max(
        (millis(event.details.get("requestMs")) or 0 for event in trace.transfers),
        default=0,
    )
    slow_transfer = max(
        trace.transfers,
        key=lambda event: millis(event.details.get("requestMs")) or -1,
        default=None,
    )
    slow_proxy_kind = slow_transfer.details.get("proxyKind", "-") if slow_transfer else "-"
    slow_hls_role = slow_transfer.details.get("hlsRole", "-") if slow_transfer else "-"
    audio_transcode = decision.get("audioTranscodeRequired") == "yes"
    subtitle_burn = decision.get("serverSubtitleRendering") == "yes"
    route_blocked = decision.get("routeCanAttemptOriginal") == "no"
    engine_states = {
        event.details.get("state", "-")
        for event in trace.engine_events
    }
    failure_stages = {
        event.details.get("stage", "-")
        for event in trace.failures
    }
    ended_stages = {
        event.details.get("stage", "-")
        for event in trace.ended
    }
    premature_stages = {
        "ksPlayerFinishedBeforeFirstFrame",
        "ksPlayerPrematureEnd",
    }

    if premature_stages & (failure_stages | ended_stages):
        return (
            "ksplayer_premature_end",
            "high",
            "KSPlayer reported finish before a plausible playback position or first frame.",
        )
    if "invalidPlaybackTime" in engine_states:
        return (
            "ksplayer_invalid_clock",
            "high",
            "KSPlayer emitted an implausible playback timestamp; trace timing from that tick is ignored.",
        )
    if trace.first_frame is None:
        return (
            "missing_first_frame",
            "high",
            "No first-frame event was captured for this playback trace.",
        )
    if route_kind in {"localHLS", "serverHLS"} and reason == "largeRemoteOriginalRisk":
        return (
            "large_remote_original_hls",
            "medium",
            "Auto avoided remote original playback for a large MKV/REMUX source.",
        )
    if route_kind in {"localHLS", "serverHLS"} and reason == "automaticBitrateBudget":
        if tap_ms and target_ms and tap_ms > target_ms * 2:
            return (
                "hls_policy_latency",
                "high",
                "Original stream was skipped before player startup; startup cost is on Jellyfin HLS/proxy/segment delivery.",
            )
        return (
            "hls_policy_route",
            "medium",
            "Original stream was skipped by bitrate policy; HLS route selected before engine startup.",
        )
    if route_kind in {"localHLS", "serverHLS"} and audio_transcode:
        return (
            "audio_compatibility_hls",
            "medium",
            "Selected audio requires compatibility conversion, so the route moved to Jellyfin HLS.",
        )
    if route_kind in {"localHLS", "serverHLS"} and subtitle_burn:
        return (
            "subtitle_burnin_hls",
            "medium",
            "Selected subtitle needs server rendering, so the route moved to Jellyfin HLS.",
        )
    if route_kind in {"localHLS", "serverHLS"} and route_blocked:
        return (
            "original_route_blocked",
            "medium",
            "Original playback was not allowed by route/bandwidth policy.",
        )
    if first_frame_ms is not None and first_frame_ms <= 1 and tap_ms and tap_ms > 3000:
        return (
            "pre_renderer_latency",
            "high",
            "Most latency happened before the renderer reported first frame.",
        )
    if longest_request > 3000:
        return (
            "slow_media_request",
            "high",
            f"A {slow_proxy_kind}/{slow_hls_role} request was slow before first frame.",
        )
    if engine == "ksPlayer":
        return (
            "ksplayer_needs_engine_timing",
            "medium",
            "KSPlayer route selected; compare open/probe/first-frame diagnostics.",
        )
    return ("unknown", "low", "No dominant bottleneck inferred from current fields.")


def recommended_action(code: str) -> str:
    actions = {
        "missing_first_frame": "Check whether playback ended, crashed, or lacked first-frame instrumentation.",
        "hls_policy_latency": "Profile Jellyfin HLS startup and first segment delivery before changing renderer settings.",
        "hls_policy_route": "Use Force original KSPlayer only as an A/B diagnostic, then compare sustained playback.",
        "large_remote_original_hls": "Use this as the Auto baseline; keep Force original KSPlayer as the decoder stress test.",
        "audio_compatibility_hls": "Test an alternate direct-playable audio track, then decide whether KSPlayer can own this codec.",
        "subtitle_burnin_hls": "Test subtitles off or external text subtitles to separate subtitle rendering from video startup.",
        "original_route_blocked": "Revisit remote original policy only after comparing source bitrate with measured throughput.",
        "pre_renderer_latency": "Add or inspect PlaybackInfo/proxy/segment timing; renderer is probably not the first bottleneck.",
        "slow_media_request": "Inspect the slow request line and Jellyfin/reverse-proxy logs for delayed playlist or segment response.",
        "ksplayer_needs_engine_timing": "Add KSPlayer open/probe/ready/decode timestamps before tuning cache or buffer values.",
        "ksplayer_invalid_clock": "Inspect KSPlayer duration/currentTime propagation before trusting renderer timing fields.",
        "ksplayer_premature_end": "Compare KSPlayer open/probe/decode logs with local-range response status to find the early EOF trigger.",
    }
    return actions.get(code, "Collect more segmented timing fields before changing playback policy.")


def trace_record(trace: PlaybackTrace, index: int) -> dict[str, object]:
    route = trace.route.details
    prepared = trace.prepared.details if trace.prepared else {}
    decision = trace.decision.details if trace.decision else {}
    bitrate = trace.bitrate.details if trace.bitrate else {}
    first = trace.first_frame.details if trace.first_frame else {}
    slow_transfer = max(
        trace.transfers,
        key=lambda event: millis(event.details.get("requestMs")) or -1,
        default=None,
    )
    telemetry_buffer_values = [
        value for event in trace.telemetry
        if (value := millis(event.details.get("bufferAheadSeconds"))) is not None
    ]
    telemetry_observed_bitrates = [
        value for event in trace.telemetry
        if (value := millis(event.details.get("observedBitrate"))) is not None
    ]
    telemetry_throughputs = [
        value for event in trace.telemetry
        if (value := millis(event.details.get("accessLogThroughputMbps"))) is not None
    ]
    telemetry_stalls = [
        event for event in trace.telemetry
        if event.details.get("stallActive") == "yes"
    ]
    ksplayer_states = [
        event.details.get("state", "-")
        for event in trace.engine_events
        if event.details.get("state")
    ]
    failure_stages = [
        event.details.get("stage", "-")
        for event in trace.failures
        if event.details.get("stage")
    ]
    ended_stages = [
        event.details.get("stage", "-")
        for event in trace.ended
        if event.details.get("stage")
    ]
    access_log_stalls = [
        value for event in trace.telemetry
        if (value := integer(event.details.get("accessLogStalls"))) is not None
    ]
    code, severity, inference = classify_bottleneck(trace)
    ks_snapshot_source = trace.failures[-1] if trace.failures else (
        trace.ended[-1] if trace.ended else None
    )
    ks_snapshot_keys = [
        "ksPlaybackState",
        "ksLoadState",
        "ksReady",
        "ksPlaying",
        "ksSeekable",
        "ksCurrentSeconds",
        "ksDurationSeconds",
        "ksPlayableSeconds",
        "ksBytesRead",
        "ksAudioBitrate",
        "ksVideoBitrate",
        "ksDisplayFPS",
    ]
    return {
        "index": index,
        "line": trace.route.line,
        "playbackTraceID": trace.trace_id,
        "association": "legacy_unidentified" if trace.trace_id == "-" and trace.plan_id == "-" else "identified",
        "planID": trace.plan_id,
        "routeID": trace.route_id,
        "routeKind": route.get("routeKind", "-"),
        "playMethod": route.get("playMethod", "-"),
        "decodeEngine": route.get("decodeEngine", "-"),
        "decision": decision.get("mode", "-"),
        "reason": decision.get("reason", "-"),
        "prepared": prepared.get("mode", "-"),
        "transport": prepared.get("transport", "-"),
        "measuredBitrate": integer(bitrate.get("measuredBitrate")),
        "selectedBitrate": integer(bitrate.get("selectedBitrate")),
        "sourceBitrate": integer(prepared.get("sourceBitrate") or decision.get("sourceBitrate")),
        "tapToFirstFrameMs": millis(first.get("tapToFirstFrameMs")),
        # Older coordinator logs mislabeled media position (seconds) as
        # firstFrameMs. Never treat that field as renderer latency.
        "firstFramePositionSeconds": millis(first.get("firstFramePositionSeconds", first.get("firstFrameMs"))),
        "engineStartPositionSeconds": (
            next(iter(trace.engine_start_positions)) if len(trace.engine_start_positions) == 1 else None
        ),
        # A retired renderer can have sought or submitted a frame without
        # advancing the clock. Neither observation is a successful startup.
        "incompleteEngineStartups": [
            {
                "line": event.line,
                "initialSeekResult": event.details.get("initialSeekResult"),
                **{
                    key: nonnegative_measurement(event.details.get(key))
                    for key in (
                        "initialPositionSeconds", "initialSeekMs", "firstVideoPacketMs",
                        "acceptedVideoFrameMs", "outputSubmittedMs",
                    )
                },
            }
            for event in trace.incomplete_startups
        ],
        "firstFrameSignal": first.get("firstFrameSignal", "playbackClock" if first else "-"),
        "rendererFirstFrameMs": millis(first.get("rendererFirstFrameMs")),
        "targetMs": millis(route.get("firstFrameTargetMs")),
        "preFirstFrameTransferCount": len(trace.transfers),
        "preFirstFrameWarnings": len(trace.warnings),
        "ksPlayerStates": ksplayer_states,
        "playbackEndedStages": ended_stages,
        "failureStages": failure_stages,
        "telemetry": {
            "sampleCount": len(trace.telemetry),
            "stallSampleCount": len(telemetry_stalls),
            "maxAccessLogStalls": max(access_log_stalls) if access_log_stalls else None,
            "minBufferAheadSeconds": min(telemetry_buffer_values) if telemetry_buffer_values else None,
            "avgBufferAheadSeconds": (
                sum(telemetry_buffer_values) / len(telemetry_buffer_values)
                if telemetry_buffer_values else None
            ),
            "avgObservedBitrate": (
                sum(telemetry_observed_bitrates) / len(telemetry_observed_bitrates)
                if telemetry_observed_bitrates else None
            ),
            "avgAccessLogThroughputMbps": (
                sum(telemetry_throughputs) / len(telemetry_throughputs)
                if telemetry_throughputs else None
            ),
        },
        "ksRuntimeSnapshot": None
        if ks_snapshot_source is None
        else {
            key: ks_snapshot_source.details[key]
            for key in ks_snapshot_keys
            if key in ks_snapshot_source.details
        },
        "slowestRequest": None
        if slow_transfer is None
        else {
            "line": slow_transfer.line,
            "proxyKind": slow_transfer.details.get("proxyKind", "-"),
            "hlsRole": slow_transfer.details.get("hlsRole", "-"),
            "pathExtension": slow_transfer.details.get("pathExtension", "-"),
            "upstreamTaskIndex": integer(slow_transfer.details.get("upstreamTaskIndex")),
            "requestMs": millis(slow_transfer.details.get("requestMs")),
            "durationMs": millis(slow_transfer.details.get("durationMs")),
            "bytes": integer(
                slow_transfer.details.get("deliveredBytes")
                or slow_transfer.details.get("contentLength")
            ),
        },
        "bottleneck": code,
        "severity": severity,
        "inference": inference,
        "recommendedAction": recommended_action(code),
    }


def summarize(records: list[dict[str, object]]) -> list[str]:
    route_counts = Counter(
        f"{record['routeKind']}/{record['decodeEngine']}" for record in records
    )
    reason_counts = Counter(str(record["reason"]) for record in records)
    bottleneck_counts = Counter(str(record["bottleneck"]) for record in records)
    slow_request_roles = Counter(
        f"{slow['proxyKind']}/{slow['hlsRole']}"
        for record in records
        if isinstance((slow := record["slowestRequest"]), dict)
    )
    first_frames = sorted(
        value for record in records
        if isinstance((value := record["tapToFirstFrameMs"]), float)
    )
    telemetry_sample_count = sum(
        int(telemetry.get("sampleCount", 0))
        for record in records
        if isinstance((telemetry := record.get("telemetry")), dict)
    )
    telemetry_stall_sample_count = sum(
        int(telemetry.get("stallSampleCount", 0))
        for record in records
        if isinstance((telemetry := record.get("telemetry")), dict)
    )
    telemetry_min_buffers = [
        value for record in records
        if isinstance((telemetry := record.get("telemetry")), dict)
        and isinstance((value := telemetry.get("minBufferAheadSeconds")), float)
    ]
    lines = [
        "Summary",
        f"  traces: {len(records)}",
        "  routes: "
        + (", ".join(f"{key}={count}" for key, count in route_counts.items()) or "-"),
        "  reasons: "
        + (", ".join(f"{key}={count}" for key, count in reason_counts.items()) or "-"),
        "  bottlenecks: "
        + (", ".join(f"{key}={count}" for key, count in bottleneck_counts.items()) or "-"),
        "  slow_request_roles: "
        + (", ".join(f"{key}={count}" for key, count in slow_request_roles.items()) or "-"),
    ]
    if first_frames:
        average = sum(first_frames) / len(first_frames)
        worst = first_frames[-1]
        lines.append(f"  tap_to_first_frame: avg={average:.0f}ms worst={worst:.0f}ms")
    if telemetry_sample_count:
        min_buffer = (
            f"{min(telemetry_min_buffers):.1f}s"
            if telemetry_min_buffers else "-"
        )
        lines.append(
            "  telemetry: "
            f"samples={telemetry_sample_count} "
            f"stall_samples={telemetry_stall_sample_count} "
            f"min_buffer_ahead={min_buffer}"
        )
    return lines


def render_trace(trace: PlaybackTrace, index: int) -> list[str]:
    record = trace_record(trace, index)
    slow_transfer = record["slowestRequest"]

    lines = [
        (
            f"Trace {index}: trace={record['playbackTraceID']} "
            f"plan={record['planID']} route={record['routeID']} line={record['line']}"
        ),
        (
            "  route: "
            f"{record['routeKind']} / {record['playMethod']} / {record['decodeEngine']}"
        ),
        (
            "  policy: "
            f"decision={record['decision']} reason={record['reason']} "
            f"prepared={record['prepared']} transport={record['transport']}"
        ),
        (
            "  bitrate: "
            f"measured={bitrate_label(str(record['measuredBitrate']) if record['measuredBitrate'] else None)} "
            f"selected={bitrate_label(str(record['selectedBitrate']) if record['selectedBitrate'] else None)} "
            f"source={bitrate_label(str(record['sourceBitrate']) if record['sourceBitrate'] else None)}"
        ),
        (
            "  first_frame: "
            f"tapToFirstFrameMs={record['tapToFirstFrameMs'] or '-'} "
            f"signal={record['firstFrameSignal']} "
            f"positionSeconds={record['firstFramePositionSeconds']} "
            f"rendererFirstFrameMs={record['rendererFirstFrameMs'] or '-'} "
            f"targetMs={record['targetMs'] or '-'}"
        ),
        (
            "  pre_first_frame_io: "
            f"transfers={record['preFirstFrameTransferCount']} "
            f"warnings={record['preFirstFrameWarnings']}"
        ),
    ]
    for startup in record["incompleteEngineStartups"]:
        lines.append(
            "  engine_startup_incomplete: "
            + " ".join(f"{key}={value if value is not None else '-'}" for key, value in startup.items())
        )
    if isinstance(slow_transfer, dict):
        lines.append(
            "  slowest_request: "
            f"line={slow_transfer['line']} "
            f"{slow_transfer['proxyKind']}/{slow_transfer['hlsRole']} "
            f"ext={slow_transfer['pathExtension']} "
            f"task={slow_transfer['upstreamTaskIndex'] or '-'} "
            f"requestMs={slow_transfer['requestMs'] or '-'} "
            f"durationMs={slow_transfer['durationMs'] or '-'} "
            f"bytes={slow_transfer['bytes'] or '-'}"
        )
    telemetry = record["telemetry"]
    if isinstance(telemetry, dict) and telemetry["sampleCount"]:
        lines.append(
            "  telemetry: "
            f"samples={telemetry['sampleCount']} "
            f"stallSamples={telemetry['stallSampleCount']} "
            f"maxAccessLogStalls={telemetry['maxAccessLogStalls'] or '-'} "
            f"minBufferAhead={format_seconds(telemetry['minBufferAheadSeconds'])} "
            f"avgObservedBitrate={format_bitrate_value(telemetry['avgObservedBitrate'])} "
            f"avgThroughput={format_mbps(telemetry['avgAccessLogThroughputMbps'])}"
        )
    if record["ksPlayerStates"] or record["playbackEndedStages"] or record["failureStages"]:
        lines.append(
            "  ksplayer_events: "
            f"states={','.join(record['ksPlayerStates']) or '-'} "
            f"ended={','.join(record['playbackEndedStages']) or '-'} "
            f"failures={','.join(record['failureStages']) or '-'}"
        )
    ks_snapshot = record["ksRuntimeSnapshot"]
    if isinstance(ks_snapshot, dict) and ks_snapshot:
        lines.append(
            "  ksplayer_snapshot: "
            f"state={ks_snapshot.get('ksPlaybackState', '-')} "
            f"load={ks_snapshot.get('ksLoadState', '-')} "
            f"ready={ks_snapshot.get('ksReady', '-')} "
            f"playing={ks_snapshot.get('ksPlaying', '-')} "
            f"seekable={ks_snapshot.get('ksSeekable', '-')} "
            f"current={ks_snapshot.get('ksCurrentSeconds', '-')} "
            f"duration={ks_snapshot.get('ksDurationSeconds', '-')} "
            f"playable={ks_snapshot.get('ksPlayableSeconds', '-')} "
            f"bytesRead={ks_snapshot.get('ksBytesRead', '-')}"
        )
    lines.append(
        f"  bottleneck: {record['bottleneck']} severity={record['severity']}"
    )
    lines.append(f"  inference: {record['inference']}")
    lines.append(f"  next: {record['recommendedAction']}")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    args = parser.parse_args()

    events = parse_log(args.log)
    unassigned: list[dict[str, object]] = []
    traces = build_traces(events, unassigned)
    records = [trace_record(trace, index) for index, trace in enumerate(traces, 1)]
    if args.json:
        print(
            json.dumps(
                {"events": len(events), "associationPolicy": "trace-plan-strict-with-legacy-fallback",
                 "unassignedEvents": unassigned, "playbackTraces": records},
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    print(f"events={len(events)} playback_traces={len(traces)} unassigned_events={len(unassigned)}")
    for event in unassigned:
        print(f"unassigned line={event['line']} reason={event['reason']}")
    print()
    print("\n".join(summarize(records)))
    for index, trace in enumerate(traces, 1):
        print()
        print("\n".join(render_trace(trace, index)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
