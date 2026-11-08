#!/usr/bin/env python3
"""Read private client events and export bounded, numeric seek/segment evidence.

Does not request media or change playback. Overlapping requests are separate
observations, never additive portions of a seek's wall-clock duration.
"""
import argparse
import json
import math
from pathlib import Path

from playback_server_log_report import APPLE_EPOCH, details


def number(value):
    if isinstance(value, bool):
        return None
    try:
        value = float(value)
        return value if math.isfinite(value) else None
    except (ValueError, TypeError, OverflowError):
        return None


def milliseconds(seconds):
    return round(seconds * 1000, 3)


def report(events, start, end):
    start, end = number(start), number(end)
    if start is None or end is None or start >= end:
        raise ValueError("Distinct finite observation bounds are required")
    rows = []
    for e in events:
        at = number(e.get("date"))
        if at is not None and at + APPLE_EPOCH < end:
            rows.append((at + APPLE_EPOCH, str(e.get("messageKey", "")).rsplit(".", 1)[-1], details(e)))
    rows.sort(key=lambda row: row[0])
    seeks = [r for r in rows if start <= r[0] and r[1] == "seek_started"]
    operations = []
    for index, (at, _, seek_fields) in enumerate(seeks):
        trace = seek_fields.get("playbackTraceID")
        following = next((t for t, _, f in seeks[index + 1:]
                          if f.get("playbackTraceID") == trace), None)
        stop = following if following is not None else end
        window = [r for r in rows if at <= r[0] < stop
                  and (not trace or r[2].get("playbackTraceID") in (None, trace))]
        target = number(seek_fields.get("seekTargetSeconds"))

        def matching(fields):
            other = number(fields.get("seekTargetSeconds", fields.get("targetSeconds")))
            return (other is not None and target is not None and abs(other - target) < .05
                    and (not trace or fields.get("playbackTraceID") == trace)
                    and (not seek_fields.get("planID") or fields.get("planID") == seek_fields["planID"]))

        complete = next((t for t, key, f in window if key == "seek_engine_completed" and matching(f)), None)
        recovered = next((t for t, key, f in window if key == "seek_recovered" and matching(f)), None)
        # This marker is emitted only for a pending paused seek preview. Keep
        # its renderer-output boundary separate from advancing-clock recovery,
        # which can include an arbitrarily long intentional pause. A missing
        # marker does not prove that the seek was requested while playing.
        plan = seek_fields.get("planID")
        preview = next((t for t, key, f in window if key == "seek_preview_ready"
                        and trace and plan and f.get("playbackTraceID") == trace
                        and f.get("planID") == plan and matching(f)
                        and f.get("evidence") == "rendererOutputNotPresentation"), None)
        paused_preview = preview is not None and (recovered is None or preview <= recovered)
        recovery_fields = next((f for t, key, f in window
                                if key == "seek_recovered" and t == recovered and matching(f)), {})
        internal_recovery = number(recovery_fields.get("seekRecoveryMs"))
        # Include events before the seek to preserve identities of old requests
        # cancelled during it. Missing identity is unknown, never one shared task.
        groups = {}
        unidentified = 0
        for t, key, f in rows:
            if t >= stop or f.get("hlsRole") != "segment":
                continue
            if trace and f.get("playbackTraceID") != trace:
                continue
            if not f.get("transferID") or not f.get("upstreamTaskIndex"):
                unidentified += at <= t
                continue
            identity = (f.get("playbackTraceID"), f["transferID"], str(f["upstreamTaskIndex"]))
            groups.setdefault(identity, []).append((t, key, f))
        segments = []
        for entries in groups.values():
            if not any(t >= at for t, _, _ in entries):
                continue
            issued = next((t for t, _, f in entries if f.get("stage") == "upstreamRequestIssued"), None)
            row = {"requestSecondsFromSeek": round(issued - at, 6) if issued is not None else None,
                   "requestStartedBeforeSeek": issued < at if issued is not None else None}
            ordinals = {int(n) for _, _, f in entries
                        if (n := number(f.get("segmentOrdinal"))) is not None
                        and n.is_integer() and 0 <= n <= 2**31 - 1}
            row["segmentOrdinal"] = next(iter(ordinals)) if len(ordinals) == 1 else None
            row["ordinalConflict"] = len(ordinals) > 1
            for t, key, f in entries:
                stage = f.get("stage")
                status = number(f.get("status"))
                if key == "proxy_transfer_started" and status is not None and status.is_integer() and 100 <= status <= 599:
                    row.setdefault("responseHeadersSecondsFromSeek", round(t - at, 6))
                    row["responseStatus"] = int(status)
                if stage == "clientReadEnded":
                    # A clean TCP write-side FIN is not proof the client stopped
                    # reading. Keep this observation distinct from cancellation.
                    row.setdefault("clientReadEndSecondsFromSeek", round(t - at, 6))
                    if f.get("clientReadComplete") == "true" and f.get("clientReadErrorKind") == "none":
                        row["cleanWriteSideEOFObserved"] = True
                if stage == "upstreamCancellationRequested":
                    row.setdefault("cancelRequestedSecondsFromSeek", round(t - at, 6))
                if stage == "upstreamTaskCompleted":
                    row.setdefault("completionSecondsFromSeek", round(t - at, 6))
                    row["completionErrorCode"] = number(f.get("errorCode"))
                for src, dest in [("upstreamTaskBodyBytes", "bodyBytesObserved"),
                                  ("taskReceivedBytes", "bodyBytesObserved")]:
                    n = number(f.get(src))
                    if n is not None and n >= 0:
                        row[dest] = max(row.get(dest, 0), n)
                if stage == "urlSessionTaskMetrics":
                    for src in ["lastRequestEndToFirstByteMs", "lastResponseBodyMs", "totalMs"]:
                        n = number(f.get(src))
                        if n is not None and n >= 0:
                            row[src] = n
                for src, dest in [("upstreamIssueToHeadersCallbackMs", "issueToHeadersCallbackMs"),
                                  ("upstreamIssueToFirstBodyCallbackMs", "issueToFirstBodyCallbackMs")]:
                    n = number(f.get(src))
                    if n is not None and n >= 0:
                        row[dest] = n
            segments.append(row)
        segments.sort(key=lambda r: (r["requestSecondsFromSeek"] is None, r["requestSecondsFromSeek"] or 0))
        fresh = [r for r in segments if r["requestStartedBeforeSeek"] is False]
        operations.append({
            "operation": index + 1,
            "secondsFromObservationStart": round(at - start, 6),
            "observationSeconds": round(stop - at, 6),
            "engine": seek_fields.get("engine") if seek_fields.get("engine") in {"KSPlayer", "AVPlayer", "VLC"} else "unknown",
            "targetSeconds": target,
            "completionMs": milliseconds(complete - at) if complete is not None else None,
            "recoveredMs": milliseconds(recovered - at) if recovered is not None else None,
            "internalClockRecoveryMs": internal_recovery if internal_recovery is not None and internal_recovery >= 0 else None,
            "pausedPreviewOutputMs": milliseconds(preview - at) if preview is not None else None,
            "pausedSeekIntentObserved": True if paused_preview else None,
            "clockRecoveryLatencyScope": "includesPausedSeekIntent" if paused_preview else "advancingClockPauseIntentUnknown",
            "completionToRecoveryMs": milliseconds(recovered - complete) if complete is not None and recovered is not None and recovered >= complete else None,
            "recoveryCensored": recovered is None,
            "censorReason": ("supersededByNextSeek" if following is not None else "observationEnded") if recovered is None else None,
            "firstNewSegmentRequestMs": milliseconds(fresh[0]["requestSecondsFromSeek"]) if fresh else None,
            "segments": segments,
            "unidentifiedSegmentEventCount": unidentified,
        })
    return {"operations": operations, "durationsMustNotBeSummed": True,
            "TCPWriteEOFIsNotCancellation": True, "serverSessionIdentityVerified": False,
            "serverRootCauseAccepted": False, "visibleFrameAccepted": False,
            "limitations": ["Client header wait includes network and upstream processing.",
                            "Completion/advancing clock is not first visible frame.",
                            "A paused preview is renderer output, not screen presentation or buffer readiness; advancing-clock recovery may include intentional pause time.",
                            "Missing paused preview evidence leaves pause intent unknown; do not subtract an inferred pause duration.",
                            "Missing events remain unknown; requests may overlap."]}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--events", type=Path, required=True)
    p.add_argument("--start", type=float, required=True)
    p.add_argument("--end", type=float, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    args.output.write_text(json.dumps(report(json.loads(args.events.read_text()), args.start, args.end),
                                      indent=2, allow_nan=False) + "\n")


if __name__ == "__main__":
    main()
