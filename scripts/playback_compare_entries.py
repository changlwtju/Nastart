#!/usr/bin/env python3
"""Compare explicitly paired device-file/Jellyfin playback-clock observations.

A manifest supplies externally verified conditions; report JSON supplies trace
identity and measurements. Unknown or mismatched data blocks aggregate results.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from statistics import median

CONDITIONS = ("sampleID", "fileRevision", "audioTrack", "subtitleTrack",
              "startSeconds", "device", "network", "build", "buildMode", "cache")
ENTRIES = ("dsmFile", "jellyfin")


def known(value: object) -> bool:
    return isinstance(value, str) and value.strip().lower() not in ("", "-", "unknown", "unverified", "null")


def finite_nonnegative(value: object) -> bool:
    try:
        return type(value) in (int, float) and math.isfinite(value) and value >= 0
    except OverflowError:
        return False


def compare(manifest: dict, base: Path) -> dict:
    result = {"eligible": False, "metric": "playbackClockMs_not_screen_first_frame",
              "attempts": 0, "completePairs": 0, "issues": [], "summary": None}
    issues = result["issues"]
    if not isinstance(manifest, dict) or manifest.get("schemaVersion") != 1 or not isinstance(manifest.get("runs"), list):
        issues.append("Expected schemaVersion=1 and a runs array")
        return result
    pairs: dict[str, dict] = {}
    reports: dict[Path, dict] = {}
    used: set[tuple] = set()
    cohort = None
    for index, run in enumerate(manifest["runs"], 1):
        result["attempts"] += 1
        try:
            if not isinstance(run, dict):
                raise ValueError("run must be an object")
            pair, entry = run.get("pairID"), run.get("entry")
            if not known(pair) or entry not in ENTRIES:
                raise ValueError("pairID and entry=dsmFile/jellyfin are required")
            group = pairs.setdefault(pair, {})
            if entry in group:
                raise ValueError("duplicate entry in pair")
            group[entry] = None  # Preserve failed attempts; never silently drop them.
            conditions = run.get("conditions")
            if not isinstance(conditions, dict):
                raise ValueError("conditions object required")
            for field in CONDITIONS:
                value = conditions.get(field)
                valid = finite_nonnegative(value) if field == "startSeconds" else known(value)
                if not valid:
                    raise ValueError(f"missing/invalid condition: {field}")
            if conditions["buildMode"] != "normal":
                raise ValueError("performance comparison requires a normal, non-diagnostic build")
            if conditions["cache"] not in ("cold", "warm"):
                raise ValueError("cache must be cold or warm")
            if not all(known(run.get(key)) for key in ("report", "playbackTraceID", "planID")):
                raise ValueError("report, playbackTraceID and planID required")
            path = (base / run["report"]).resolve()
            identity = (run["playbackTraceID"], run["planID"])
            if identity in used:
                raise ValueError("report trace reused as another observation")
            used.add(identity)
            if path not in reports:
                reports[path] = json.loads(path.read_text(encoding="utf-8"))
            report = reports[path]
            if not isinstance(report, dict) or report.get("associationPolicy") != "trace-plan-strict-with-legacy-fallback":
                raise ValueError("strict trace report required")
            if report.get("unassignedEvents") != []:
                raise ValueError("report has unresolved/missing event-association audit")
            records = report.get("playbackTraces")
            if not isinstance(records, list):
                raise ValueError("playbackTraces array required")
            matches = [r for r in records if isinstance(r, dict)
                       and r.get("playbackTraceID") == run["playbackTraceID"] and r.get("planID") == run["planID"]]
            if len(matches) != 1:
                raise ValueError("trace/plan must identify exactly one record")
            record = matches[0]
            if record.get("association") != "identified":
                raise ValueError("legacy/unidentified record cannot be paired")
            if record.get("failureStages") != []:
                raise ValueError("failed or unaudited playback attempt")
            elapsed = record.get("tapToFirstFrameMs")
            if record.get("firstFrameSignal") != "playbackClock" or not finite_nonnegative(elapsed):
                raise ValueError("finite playbackClock measurement required")
            if not all(known(record.get(key)) for key in ("decodeEngine", "playMethod", "routeKind")):
                raise ValueError("actual route/engine/method required")
            signature = tuple(conditions[key] for key in CONDITIONS) + (record["decodeEngine"], record["playMethod"])
            if cohort is None:
                cohort = signature
            if signature != cohort:
                raise ValueError("conditions/engine/playMethod differ; use a separate cohort")
            group[entry] = elapsed
        except (ValueError, OSError, TypeError) as error:
            issues.append(f"run {index}: {error}")
    complete = [pair for pair in pairs.values() if all(pair.get(entry) is not None for entry in ENTRIES)]
    result["completePairs"] = len(complete)
    if len(complete) != len(pairs):
        issues.append("incomplete or invalid pairs retained; no aggregate comparison")
    if len(complete) < 3:
        issues.append("at least three complete pairs required for exploratory medians")
    if issues:
        return result
    values = {entry: [pair[entry] for pair in complete] for entry in ENTRIES}
    deltas = [pair["jellyfin"] - pair["dsmFile"] for pair in complete]
    result["summary"] = {
        entry: {"medianMs": median(samples), "minMs": min(samples), "maxMs": max(samples)}
        for entry, samples in values.items()
    }
    result["summary"]["medianPairedJellyfinMinusDeviceMs"] = median(deltas)
    result["eligible"] = True
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        result = compare(manifest, args.manifest.resolve().parent)
    except (ValueError, OSError) as error:
        parser.exit(2, f"Invalid input: {error}\n")
    print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
    return 0 if result["eligible"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
