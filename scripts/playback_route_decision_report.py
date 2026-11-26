#!/usr/bin/env python3
"""Recompute original-versus-rendition decisions from an exported diagnostic log.

Every `routeCapacityEvidence` record carries the merged capacity figure and the
verdict the app reached. This report recomputes that verdict, and the bitrate
of an automatically started server rendition, from the logged numbers alone,
and lists each playback whose route does not follow the rules in
docs/archive/handoffs/2026-11/CLAUDE-2026-11-10-ROUTE-DECISION-MODEL.md.

It reads a saved text export. It makes no device, media or network request,
and it prints no address, account or path: the records it reads hold none.
The constants below mirror PlaybackRouteDecisionPolicy and must change with it.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from playback_trace_report import Event, parse_log

SUSTAIN_MARGIN = 1.5
EXPLORATION_FACTOR = 3.0
RENDITION_SHARE = 0.5
LADDER = [30_000_000, 20_000_000, 12_000_000, 10_000_000, 8_000_000, 4_000_000,
          2_000_000, 1_500_000, 1_000_000, 750_000, 500_000, 375_000, 250_000]
SERVER_VERDICTS = {"measuredInsufficient", "lowerBoundTooFar"}
SERVER_REASONS = {"measuredInsufficient": "measuredBandwidthInsufficient",
                  "lowerBoundTooFar": "lowerBoundFarBelowSource"}
SERVER_MODES = {"serverNegotiatedHLS", "serverNegotiatedTranscode"}


def positive(value: str | None) -> int | None:
    """A logged bitrate, or None for `none`, `unknown`, `-` and bad numbers."""
    try:
        number = int(value) if value is not None else 0
    except ValueError:
        return None
    return number if number > 0 else None


def expected_verdict(details: dict[str, str]) -> str:
    source = positive(details.get("sourceBitrate"))
    capacity = positive(details.get("capacity"))
    if source is None:
        return "unknownDemand"
    if capacity is None:
        return "noEvidence"
    if source <= capacity * SUSTAIN_MARGIN:
        return "fits"
    if details.get("capacityBoundsBothSides") == "true":
        return "measuredInsufficient"
    floor = positive(details.get("renditionLowerBound"))
    if floor is not None and source <= floor * EXPLORATION_FACTOR:
        return "explore"
    return "lowerBoundTooFar"


def expected_rendition(capacity: int, ceiling: int) -> int:
    limit = min(ceiling, capacity * RENDITION_SHARE)
    return next((rung for rung in LADDER if rung <= limit), LADDER[-1])


def route_decisions(events: list[Event]) -> list[dict[str, object]]:
    """One row per playback trace that logged route evidence, in log order."""
    traces: dict[str, dict[str, Event]] = {}
    order: list[str] = []
    for event in events:
        details = event.details
        trace = details.get("playbackTraceID")
        if not trace or trace == "-":
            continue
        mode = details.get("mode", "")
        if details.get("stage") == "routeCapacityEvidence":
            kind = "evidence"
        elif "defaultMode" in details:
            kind = "request"
        elif mode in {"originalRangeSkipped", "originalRangeUnavailable", "serverHLSRequested"}:
            kind = "skip"
        elif mode in SERVER_MODES or mode.endswith("DirectPlay"):
            kind = "prepared"
        else:
            continue
        if trace not in traces:
            traces[trace] = {}
            order.append(trace)
        # A retried preparation logs again; the last record is the one used.
        traces[trace][kind] = event

    rows: list[dict[str, object]] = []
    for trace in order:
        found = traces[trace]
        evidence = found.get("evidence")
        if evidence is None:
            continue
        details = evidence.details
        request = found["request"].details if "request" in found else {}
        skip = found["skip"].details if "skip" in found else {}
        prepared = found["prepared"].details if "prepared" in found else {}
        logged = details.get("originalVerdict", "missing")
        expected = expected_verdict(details)
        problems: list[str] = []
        if logged != expected:
            problems.append(f"verdict {logged} but the logged numbers give {expected}")

        ceiling = positive(request.get("renditionCeiling"))
        forced = skip.get("mode") == "serverHLSRequested"
        mode = prepared.get("mode", "")
        route = "server" if mode in SERVER_MODES else "original" if mode.endswith("DirectPlay") else "unknown"
        # Private routes and the legacy player log `legacyBudget`: the verdict
        # does not decide their route. A forced bitrate or reason bypasses it too.
        governed = ceiling is not None and not forced
        if governed and logged in SERVER_VERDICTS:
            if route == "original":
                problems.append("original played although the verdict ruled it out")
            if skip and skip.get("reason") != SERVER_REASONS[logged]:
                problems.append(f"skip reason {skip.get('reason')} does not match verdict {logged}")
        capacity = positive(details.get("capacity"))
        rendition = positive(prepared.get("maxBitrate"))
        if (governed and route == "server" and capacity is not None and ceiling is not None
                and request.get("requestReason") == "initialPlayback"):
            wanted = expected_rendition(capacity, ceiling)
            if rendition != wanted:
                problems.append(f"rendition {rendition} but capacity and ceiling give {wanted}")

        rows.append({
            "playbackTraceID": trace,
            "line": evidence.line,
            "network": details.get("network", "-"),
            "sourceBitrate": positive(details.get("sourceBitrate")),
            "capacity": capacity,
            "capacitySource": details.get("capacitySource", "-"),
            "capacityBoundsBothSides": details.get("capacityBoundsBothSides", "-"),
            "playbackCapacity": positive(details.get("playbackCapacity")),
            "renditionLowerBound": positive(details.get("renditionLowerBound")),
            "probeCapacity": positive(details.get("probeCapacity")),
            "probeAgeSeconds": details.get("probeAgeSeconds", "-"),
            "restoredSamples": details.get("restoredSamples", "-"),
            "originalVerdict": logged,
            "expectedVerdict": expected,
            "governedByVerdict": governed,
            "route": route,
            "skipReason": skip.get("reason", "-"),
            "renditionCeiling": request.get("renditionCeiling", "-"),
            "renditionBitrate": rendition,
            "problems": problems,
        })
    return rows


def mbps(value: object) -> str:
    return f"{value / 1_000_000:.1f}" if isinstance(value, int) else "-"


def render(rows: list[dict[str, object]]) -> list[str]:
    lines = ["trace     net       source  capacity (basis, 2-sided)       floor  probe(age)   "
             "verdict               route     rendition  result"]
    for row in rows:
        basis = f"{mbps(row['capacity'])} ({row['capacitySource']}, {row['capacityBoundsBothSides']})"
        probe = f"{mbps(row['probeCapacity'])}({row['probeAgeSeconds']})"
        lines.append(
            f"{str(row['playbackTraceID']):<9} {str(row['network']):<9} {mbps(row['sourceBitrate']):>6}  "
            f"{basis:<31} {mbps(row['renditionLowerBound']):>6} {probe:<12} "
            f"{str(row['originalVerdict']):<21} {str(row['route']):<9} {mbps(row['renditionBitrate']):>9}  "
            + ("ok" if not row["problems"] else "CHECK: " + "; ".join(row["problems"])))
    failures = sum(1 for row in rows if row["problems"])
    lines.append(f"{len(rows)} playback(s) with route evidence, {failures} to check.")
    if not rows:
        lines.append("No routeCapacityEvidence record: the export may predate this build, "
                     "or the 1000-entry log limit dropped it.")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("log", type=Path, help="exported Nastart diagnostic text")
    parser.add_argument("--json", action="store_true", help="print the rows as JSON")
    arguments = parser.parse_args()
    rows = route_decisions(parse_log(arguments.log))
    print(json.dumps(rows, ensure_ascii=False, indent=2) if arguments.json else "\n".join(render(rows)))
    return 1 if any(row["problems"] for row in rows) else 0


if __name__ == "__main__":
    raise SystemExit(main())
