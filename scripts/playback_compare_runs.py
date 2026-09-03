#!/usr/bin/env python3
"""Compare two Nastart playback diagnostic exports.

The intended device workflow is:

1. Run the same Jellyfin video with Auto policy.
2. Run it again with DEBUG Force original KSPlayer enabled.
3. Compare both exported logs with this script.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import playback_trace_report as trace_report  # noqa: E402


@dataclass
class RunSummary:
    label: str
    path: str
    trace_count: int
    route_counts: dict[str, int]
    reason_counts: dict[str, int]
    bottleneck_counts: dict[str, int]
    avg_first_frame_ms: float | None
    worst_first_frame_ms: float | None
    telemetry_sample_count: int
    telemetry_stall_sample_count: int
    min_buffer_ahead_seconds: float | None
    max_access_log_stalls: int | None
    slow_request_roles: dict[str, int]
    premature_ksplayer_end_count: int
    missing_first_frame_count: int
    records: list[dict[str, Any]]


def load_records(path: Path) -> list[dict[str, Any]]:
    events = trace_report.parse_log(path)
    traces = trace_report.build_traces(events)
    return [
        trace_report.trace_record(trace, index)
        for index, trace in enumerate(traces, 1)
    ]


def numeric_values(records: list[dict[str, Any]], key: str) -> list[float]:
    values: list[float] = []
    for record in records:
        value = record.get(key)
        if isinstance(value, (float, int)):
            values.append(float(value))
    return values


def telemetry_values(records: list[dict[str, Any]], key: str) -> list[float]:
    values: list[float] = []
    for record in records:
        telemetry = record.get("telemetry")
        if not isinstance(telemetry, dict):
            continue
        value = telemetry.get(key)
        if isinstance(value, (float, int)):
            values.append(float(value))
    return values


def summarize(label: str, path: Path) -> RunSummary:
    records = load_records(path)
    first_frames = numeric_values(records, "tapToFirstFrameMs")
    min_buffers = telemetry_values(records, "minBufferAheadSeconds")
    access_log_stalls = [
        int(value)
        for value in telemetry_values(records, "maxAccessLogStalls")
    ]
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
    premature_ksplayer_end_count = sum(
        1 for record in records
        if record.get("bottleneck") == "ksplayer_premature_end"
    )
    missing_first_frame_count = sum(
        1 for record in records
        if record.get("tapToFirstFrameMs") is None
    )
    slow_request_roles = Counter(
        f"{slow['proxyKind']}/{slow['hlsRole']}"
        for record in records
        if isinstance((slow := record.get("slowestRequest")), dict)
    )
    return RunSummary(
        label=label,
        path=str(path),
        trace_count=len(records),
        route_counts=dict(Counter(
            f"{record['routeKind']}/{record['decodeEngine']}"
            for record in records
        )),
        reason_counts=dict(Counter(str(record["reason"]) for record in records)),
        bottleneck_counts=dict(Counter(str(record["bottleneck"]) for record in records)),
        avg_first_frame_ms=(
            sum(first_frames) / len(first_frames)
            if first_frames else None
        ),
        worst_first_frame_ms=max(first_frames) if first_frames else None,
        telemetry_sample_count=telemetry_sample_count,
        telemetry_stall_sample_count=telemetry_stall_sample_count,
        min_buffer_ahead_seconds=min(min_buffers) if min_buffers else None,
        max_access_log_stalls=max(access_log_stalls) if access_log_stalls else None,
        slow_request_roles=dict(slow_request_roles),
        premature_ksplayer_end_count=premature_ksplayer_end_count,
        missing_first_frame_count=missing_first_frame_count,
        records=records,
    )


def dominant_key(counts: dict[str, int]) -> str:
    if not counts:
        return "-"
    return max(counts.items(), key=lambda item: item[1])[0]


def format_ms(value: float | None) -> str:
    return "-" if value is None else f"{value:.0f}ms"


def format_seconds(value: float | None) -> str:
    return "-" if value is None else f"{value:.1f}s"


def route_contains(summary: RunSummary, route: str, engine: str) -> bool:
    expected = f"{route}/{engine}"
    return any(key == expected for key in summary.route_counts)


def compare(auto: RunSummary, force: RunSummary) -> list[str]:
    lines = [
        "Comparison",
        (
            f"  {auto.label}: traces={auto.trace_count} "
            f"route={dominant_key(auto.route_counts)} "
            f"reason={dominant_key(auto.reason_counts)} "
            f"avg_first_frame={format_ms(auto.avg_first_frame_ms)} "
            f"stall_samples={auto.telemetry_stall_sample_count} "
            f"min_buffer={format_seconds(auto.min_buffer_ahead_seconds)}"
        ),
        (
            f"  {force.label}: traces={force.trace_count} "
            f"route={dominant_key(force.route_counts)} "
            f"reason={dominant_key(force.reason_counts)} "
            f"avg_first_frame={format_ms(force.avg_first_frame_ms)} "
            f"stall_samples={force.telemetry_stall_sample_count} "
            f"min_buffer={format_seconds(force.min_buffer_ahead_seconds)} "
            f"premature_ks_ends={force.premature_ksplayer_end_count}"
        ),
    ]

    if auto.avg_first_frame_ms is not None and force.avg_first_frame_ms is not None:
        delta = force.avg_first_frame_ms - auto.avg_first_frame_ms
        if abs(delta) < 1:
            lines.append("  first_frame_delta: force and auto are effectively equal")
        else:
            direction = "slower" if delta > 0 else "faster"
            lines.append(
                f"  first_frame_delta: force is {abs(delta):.0f}ms {direction} than auto"
            )

    auto_hls = route_contains(auto, "localHLS", "systemAVPlayer")
    force_ks = route_contains(force, "localRangeProxy", "ksPlayer") or route_contains(
        force,
        "directHTTP",
        "ksPlayer",
    )
    valid_route_split = auto_hls and force_ks
    if valid_route_split and force.premature_ksplayer_end_count:
        lines.append(
            "  verdict: A/B route separation is valid, but Force KSPlayer did not reach playable startup."
        )
    elif valid_route_split:
        lines.append("  verdict: A/B route separation is valid.")
    elif not force_ks:
        lines.append(
            "  verdict: Force run did not reach KSPlayer original playback; inspect experimentalOriginal and route availability."
        )
    else:
        lines.append("  verdict: Route split is unusual; inspect both trace summaries.")

    if not force_ks:
        lines.append(
            "  next: Fix the validation run first; do not use this Force log to judge KSPlayer performance."
        )
    elif force.premature_ksplayer_end_count:
        lines.append(
            "  next: Fix Force KSPlayer startup first; first-frame speed is not comparable until it records a first_frame event."
        )
    elif force.telemetry_stall_sample_count > auto.telemetry_stall_sample_count:
        lines.append(
            "  next: Force original has more stall samples; check whether original bitrate exceeds sustained WAN throughput."
        )
    elif force.avg_first_frame_ms is not None and auto.avg_first_frame_ms is not None:
        if force.avg_first_frame_ms < auto.avg_first_frame_ms:
            lines.append(
                "  next: Force original starts faster; decide whether to expose it as an explicit quality mode after stability checks."
            )
        else:
            lines.append(
                "  next: Force original does not improve first frame; inspect KSPlayer open/probe/decode timing before tuning buffers."
            )
    else:
        lines.append(
            "  next: Missing first-frame data; verify telemetry_sample and first_frame events in exported logs."
        )
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--auto", required=True, type=Path, help="Auto policy exported log")
    parser.add_argument(
        "--force",
        required=True,
        type=Path,
        help="Force original KSPlayer exported log",
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    auto = summarize("auto", args.auto)
    force = summarize("forceOriginalKSPlayer", args.force)
    if args.json:
        print(
            json.dumps(
                {
                    "auto": auto.__dict__,
                    "forceOriginalKSPlayer": force.__dict__,
                    "comparison": compare(auto, force),
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    print("\n".join(compare(auto, force)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
