#!/usr/bin/env python3
"""Inspect bounded replacement snapshots; never infer continuous blocked time.

Reads a private diagnostics event array and a private action JSON containing
requestStart. Output uses an explicit field allowlist and anonymous attempts.
Observed negative readiness constraints are evidence; their absence is not PASS.
"""
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

from playback_phase_report import APPLE_EPOCH_OFFSET

EVENTS = {
    "replacement_warmup_started", "replacement_candidate_preparing",
    "replacement_candidate_manifest_preparing", "replacement_candidate_manifest_prepared",
    "replacement_candidate_decoded", "replacement_candidate_progress",
    "replacement_candidate_buffered_seek_started",
    "replacement_candidate_buffered_seek_completed",
    "replacement_candidate_aligned", "replacement_warmup_completed",
    "replacement_warmup_failed", "replacement_committed",
}
NUMBERS = {
    "candidateSeconds", "liveSeconds", "framePTS", "candidateBufferAheadSeconds",
    "candidateRate", "candidateStatus", "itemStatus", "loadedRangeCount",
    "loadedRangeFirstStart", "loadedRangeFirstEnd", "target",
    "preparationLeadSeconds", "availableReserveSeconds", "elapsedMs",
    "bufferedTarget", "fromSeconds",
}
STAGES = {"initialSeek", "decodedFrame", "alignment", "bufferedSeek",
          "bufferedSeekDecodedFrame", "commitRevalidation", "candidateInvalidated", "manifestPreparation"}


def number(value):
    if isinstance(value, bool):
        return None
    try:
        v = float(value)
        return v if math.isfinite(v) else None
    except (TypeError, ValueError, OverflowError):
        return None


def fields(detail):
    if isinstance(detail, dict):
        return detail
    if isinstance(detail, str):
        return dict(p.split("=", 1) for p in detail.split(", ") if "=" in p)
    return {}


def safe_snapshot(detail):
    raw = fields(detail)
    out = {k: v for k in NUMBERS if (v := number(raw.get(k))) is not None}
    for k in ("bufferEmpty", "likelyToKeepUp", "seekResult", "cachedVOD"):
        if raw.get(k) in ("true", "false"):
            out[k] = raw[k] == "true"
    if raw.get("stage") in STAGES:
        out["stage"] = raw["stage"]
    return out


def obstructions(snapshot):
    """Only record known violations of the source's existing readiness gates."""
    out = []
    c, live, frame = (snapshot.get(k) for k in ("candidateSeconds", "liveSeconds", "framePTS"))
    if c is not None and live is not None and min(c, live) >= 0 and abs(c - live) > .1:
        out.append("clockDistanceOver0.1s")
    if c is not None and frame is not None and min(c, frame) >= 0 and abs(frame - c) > .15:
        out.append("frameDistanceOver0.15s")
    if snapshot.get("bufferEmpty") is True:
        out.append("bufferEmpty")
    ahead = snapshot.get("candidateBufferAheadSeconds")
    if ahead is not None and 0 <= ahead < .5:
        out.append("maximumReportedForwardReserveUnder0.5s")
    # warmup's ahead metric is max(range.end - clock), and can count a disjoint
    # future range. Only a single fully described range permits this extra test.
    start, end = snapshot.get("loadedRangeFirstStart"), snapshot.get("loadedRangeFirstEnd")
    if (snapshot.get("loadedRangeCount") == 1 and c is not None
            and start is not None and end is not None and min(c, start, end) >= 0
            and not (start <= c and end >= c + .5)):
        out.append("singleReportedRangeDoesNotCoverCommitReserve")
    return out


def bounded_events(raw, start_unix, end_unix):
    start, end = number(start_unix), number(end_unix)
    if start is None or end is None or end <= start:
        raise ValueError("A finite increasing observation window is required")
    if not isinstance(raw, list):
        raise ValueError("Expected a diagnostics event array")
    seen, out = {}, []
    for e in raw:
        if not isinstance(e, dict):
            continue
        date = number(e.get("date"))
        if date is None or not start <= date + APPLE_EPOCH_OFFSET < end:
            continue
        key = e.get("messageKey", "")
        if key not in {"diagnostics.playback.next." + k for k in EVENTS}:
            continue
        identity = e.get("id")
        if not isinstance(identity, str) or not identity:
            raise ValueError("A replacement event has no deduplication identity")
        if identity in seen:
            if seen[identity] != e:
                raise ValueError("Conflicting diagnostic event copies")
            continue
        seen[identity] = e
        trace = fields(e.get("detail")).get("playbackTraceID")
        out.append({"time": round(date + APPLE_EPOCH_OFFSET - start, 6),
                    "event": key.rsplit(".", 1)[-1],
                    "trace": trace if isinstance(trace, str) and re.fullmatch(r"[A-Fa-f0-9]{8}", trace) else None,
                    "snapshot": safe_snapshot(e.get("detail"))})
    return sorted(out, key=lambda e: e["time"])


def analyze(raw, start_unix, end_unix):
    events = bounded_events(raw, start_unix, end_unix)
    start_unix, end_unix = number(start_unix), number(end_unix)
    attempts = []
    assigned = set()
    for trace in dict.fromkeys(e["trace"] for e in events if e["trace"] is not None):
        own = [e for e in events if e["trace"] == trace]
        starts = [i for i, e in enumerate(own) if e["event"] == "replacement_warmup_started"]
        for index, begin in enumerate(starts):
            window = own[begin:starts[index + 1] if index + 1 < len(starts) else len(own)]
            terminal = next((i for i, e in enumerate(window) if e["event"] in
                             {"replacement_committed", "replacement_warmup_failed"}), None)
            if terminal is not None:
                window = window[:terminal + 1]
            assigned.update(id(e) for e in window)
            decoded = [e for e in window if e["event"] == "replacement_candidate_decoded"]
            aligned = [e for e in window if e["event"] == "replacement_candidate_aligned"]
            commit = [e for e in window if e["event"] == "replacement_committed"]
            manifest_start = [e for e in window if e["event"] == "replacement_candidate_manifest_preparing"]
            manifest_ready = [e for e in window if e["event"] == "replacement_candidate_manifest_prepared"]
            first_decode = decoded[0] if len(decoded) == 1 else None
            rows = []
            for e in window:
                if first_decode is None or e["time"] < first_decode["time"]:
                    continue
                s = e["snapshot"]
                if not s:
                    continue
                row = {"actionSeconds": e["time"], "event": e["event"], "snapshot": s,
                       "observedObstructions": obstructions(s)}
                if all(k in s for k in ("candidateSeconds", "liveSeconds")):
                    row["candidateMinusLiveSeconds"] = round(s["candidateSeconds"] - s["liveSeconds"], 6)
                rows.append(row)

            def elapsed(a, b):
                return round(b[0]["time"] - a[0]["time"], 6) if len(a) == len(b) == 1 and b[0]["time"] >= a[0]["time"] else None

            attempts.append({"attempt": len(attempts) + 1,
                "warmupStartActionSeconds": window[0]["time"],
                "terminal": window[-1]["event"] if terminal is not None else "unobserved",
                "rightCensoredAtActionSeconds": None if terminal is not None else (
                    own[starts[index + 1]]["time"] if index + 1 < len(starts)
                    else round(end_unix - start_unix, 6)),
                "decodeCount": len(decoded), "alignedCount": len(aligned),
                "decodedToAlignedSeconds": elapsed(decoded, aligned),
                "alignedToCommitSeconds": elapsed(aligned, commit),
                "decodedToCommitSeconds": elapsed(decoded, commit),
                "manifestPreparationSeconds": elapsed(manifest_start, manifest_ready),
                "manifestSnapshots": [{"actionSeconds": e["time"], "event": e["event"], "snapshot": e["snapshot"]}
                    for e in window if e in manifest_start or e in manifest_ready
                    or e["snapshot"].get("stage") == "manifestPreparation"],
                "bufferedSeekStarts": sum(e["event"] == "replacement_candidate_buffered_seek_started" for e in window),
                "postDecodeSnapshots": rows,
                "sourceTraceJoin": "exactWithinBoundedWarmup",
                "fullReadinessOrContinuousBlockedTimeAccepted": False})
    return {"attempts": attempts,
        "unownedReplacementEvents": sum(e["trace"] is None for e in events),
        "unassignedOwnedReplacementEventCount": sum(
            e["trace"] is not None and id(e) not in assigned for e in events),
        "boundedReplacementEventCount": len(events),
        "screenFirstFrameOrActualSoundAccepted": False,
        "limits": ["Snapshots are not atomic AV state and do not cover time between events.",
                   "Reported max forward reserve does not establish a contiguous commit range.",
                   "Negative constraints do not partition elapsed time into exclusive causes.",
                   "No observed obstruction does not imply ready or successful playback.",
                   "Source trace identity is not proof of a server session or candidate network owner."]}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("events", type=Path)
    ap.add_argument("--action", required=True, type=Path)
    ap.add_argument("--end-unix", required=True, type=float)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()
    action = json.loads(args.action.read_text())
    report = analyze(json.loads(args.events.read_text()), action["requestStart"], args.end_unix)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
