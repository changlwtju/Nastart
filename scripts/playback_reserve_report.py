#!/usr/bin/env python3
"""Correlate saved reserve, body delivery and request boundaries, without a device.

Input is the same bounded private snapshot directory as playback_phase_report.
Use the existing privacy allowlist; do not export resource URLs or preferences.
Overlapping body windows, URL metrics and decoder bytes are separate measures.
This report describes observations, never a network root cause or a buffer fix.
"""
from __future__ import annotations

import argparse
import json
import math
from collections import defaultdict
from pathlib import Path

from playback_phase_report import analyze, load_window, number


def at(event):
    return event["actionSeconds"] if event else None


def seek_capacity_phases(events):
    """Use only each probe's process-monotonic clock, not event wall time.

    The track epoch is local to its probe. It must never join two request
    generations, plans or renderers, even when they share a content target.
    These are sampled phase boundaries, not additive network/CPU costs.
    """
    def finite(value):
        if isinstance(value, bool):
            return None
        try:
            result = float(value)
            return result if math.isfinite(result) else None
        except (ValueError, TypeError, OverflowError):
            return None

    groups = defaultdict(list)
    missing_identity = 0
    for event in events:
        if event.get("event") != "seek_capacity_sample":
            continue
        fields = event["fields"]
        generation, epoch = finite(fields.get("seekGeneration")), finite(fields.get("videoSeekEpoch"))
        if (not isinstance(fields.get("playbackTraceID"), str) or not fields["playbackTraceID"]
                or not isinstance(fields.get("planID"), str) or not fields["planID"]
                or generation is None or generation < 0 or not generation.is_integer()
                or epoch is None or epoch < 0 or not epoch.is_integer()):
            missing_identity += 1
            continue
        groups[(fields["playbackTraceID"], fields["planID"], generation, epoch)].append(fields)

    requests = []
    for (_, _, generation, epoch), copies in groups.items():
        # Snapshot union should already deduplicate event IDs. Also avoid
        # counting identical safe samples twice if a caller supplies copies.
        samples = list({json.dumps(f, sort_keys=True): f for f in copies}.values())
        errors = set()
        timed = []
        for f in samples:
            uptime = finite(f.get("sampleUptimeSeconds"))
            request_ms = finite(f.get("sinceRequestMs"))
            flush_ms = finite(f.get("videoSeekSinceFlushMs"))
            if (uptime is None or uptime < 0 or request_ms is None or not 0 <= request_ms <= 10000
                    or flush_ms is None or not 0 <= flush_ms <= request_ms + .001
                    or f.get("videoSeekProbeTargetMatchesRequest") != "true"):
                errors.add("missingOrInvalidMonotonicBoundaryOrTargetMatch")
                continue
            callback = finite(f.get("videoSeekFirstCallbackMs"))
            accepted = finite(f.get("videoSeekFirstAcceptedMs"))
            if (any(k in f and finite(f[k]) is None for k in ("videoSeekFirstCallbackMs", "videoSeekFirstAcceptedMs"))
                    or (callback is not None and not 0 <= callback <= flush_ms + .001)
                    or (accepted is not None and (callback is None or not callback <= accepted <= flush_ms + .001))):
                errors.add("invalidCallbackOrAcceptanceOrder")
                continue
            timed.append((request_ms, uptime - request_ms / 1000, uptime - flush_ms / 1000, f))
        timed.sort(key=lambda row: row[0])
        for index, label in ((1, "requestClockChangedWithinIdentity"), (2, "flushClockChangedWithinEpoch")):
            if timed and (max(row[index] for row in timed) - min(row[index] for row in timed)) * 1000 > .5:
                errors.add(label)
        targets = {finite(f.get("videoSeekTargetSeconds")) for f in samples}
        if None in targets or any(t is not None and t < 0 for t in targets) or len(targets) != 1:
            errors.add("missingOrConflictingTarget")
        for key in ("videoSeekFirstCallbackMs", "videoSeekFirstAcceptedMs"):
            values = [finite(row[3][key]) for row in timed if key in row[3]]
            if values and max(values) - min(values) > .5:
                errors.add("firstCallbackOrAcceptanceChangedWithinEpoch")

        ready = next((row for row in timed if row[3].get("phase") == "playable"
                      and row[3].get("playable") == "true"), None)
        waiting = [row for row in timed if row[3].get("phase") == "waiting"
                   and row[3].get("playable") == "false" and (ready is None or row[0] < ready[0])]
        reference = ready or (timed[-1] if timed else None)
        fields = reference[3] if reference else {}
        callback = finite(fields.get("videoSeekFirstCallbackMs"))
        accepted = finite(fields.get("videoSeekFirstAcceptedMs"))
        flush_from_request = reference[0] - finite(fields["videoSeekSinceFlushMs"]) if reference else None
        valid = not errors and reference is not None

        def rounded(value):
            return round(value, 3) if valid and value is not None else None

        full_waiting = [row for row in waiting
                        if row[3].get("videoSeekQueueSnapshotAvailable") == "true"
                        and finite(row[3].get("videoMaximumFrames")) is not None
                        and finite(row[3]["videoMaximumFrames"]) > 0
                        and finite(row[3].get("videoSeekQueueFrames")) is not None
                        and finite(row[3]["videoSeekQueueFrames"]) >= finite(row[3]["videoMaximumFrames"])]
        summary_keys = ("audioLoadedSeconds", "videoLoadedSeconds", "audioPackets", "videoPackets",
                        "audioFrames", "videoFrames", "videoSeekQueueFrames", "videoMaximumFrames",
                        "bufferTargetSeconds", "videoSeekQueueUnionSeconds", "videoSeekQueueSpanSeconds")
        requests.append({
            "operation": len(requests) + 1, "seekGeneration": int(generation), "trackLocalEpoch": int(epoch),
            "sampleCount": len(samples), "validTimedSampleCount": len(timed),
            "timingConsistent": valid, "boundaryErrors": sorted(errors),
            "targetSeconds": next(iter(targets)) if len(targets) == 1 and None not in targets and min(targets) >= 0 else None,
            "requestToObservedCodecFlushMs": rounded(flush_from_request),
            "codecFlushToFirstConvertedCallbackMs": rounded(callback),
            "firstConvertedCallbackToFirstAcceptedMs": rounded(accepted - callback if accepted is not None and callback is not None else None),
            "requestToFirstAcceptedMs": rounded(flush_from_request + accepted if accepted is not None else None),
            "firstAcceptedToObservedPlayableMs": rounded(ready[0] - flush_from_request - accepted if ready is not None and accepted is not None else None),
            "firstObservedPlayableSinceRequestMs": rounded(ready[0] if ready else None),
            "lastObservedWaitingSinceRequestMs": rounded(waiting[-1][0] if waiting else None),
            "sampledWaitingToPlayableWindowMs": rounded(ready[0] - waiting[-1][0] if ready and waiting else None),
            "fullDecodedQueueWhileWaitingSamples": len(full_waiting),
            "lastWaitingCapacity": {k: n for k in summary_keys if waiting
                                    and (n := finite(waiting[-1][3].get(k))) is not None},
            "readyCapacity": {k: n for k in summary_keys if ready and (n := finite(ready[3].get(k))) is not None},
            "rightCensoredAtCapacitySample": ready is None,
        })
    return {"requests": requests, "capacitySamplesMissingRequestOrEpochIdentity": missing_identity,
            "clockBoundary": "Per-sample process monotonic uptime and request/flush elapsed only; no host or event wall-clock subtraction.",
            "limits": ["Codec flush timing is the observed local epoch, not demux completion or the App request generation.",
                       "First converted callback to acceptance includes supply, decode and scheduling; it is not filter CPU time.",
                       "Acceptance-to-playable includes further reserve formation and capacity checking; it is not proven redundant waiting.",
                       "The waiting-to-playable interval is a sample gap, not a configured polling delay or a time saving.",
                       "A full decoded queue need not meet the existing packet-plus-frame buffer criterion; PTS union is separate.",
                       "Missing or inconsistent boundaries stay unknown. No sound, screen, root cause or performance improvement is inferred."]}


def reserve_report(events):
    events = sorted(events, key=lambda e: e["actionSeconds"])
    traces = []
    for renderer in analyze(events)["rendererTraces"]:
        trace = renderer["traceID"]
        owned = [e for e in events if e["fields"].get("playbackTraceID") == trace]
        decisions = [e for e in owned if e["event"] == "automatic_prediction_decision"]
        windows = []
        for e in owned:
            f = e["fields"]
            if f.get("stage") != "upstreamBodyProgress":
                continue
            elapsed = number(f.get("elapsedMs"))
            start = e["actionSeconds"] - elapsed / 1000 if elapsed and elapsed > 0 else None
            # Only actual in-window demand observations; never assume rate=1,
            # use the whole-file average, or carry a demand across a seek.
            demands = [d["fields"]["runtimeDemand"] for d in decisions
                       if start is not None and start <= d["actionSeconds"] <= e["actionSeconds"]
                       and number(d["fields"].get("runtimeDemand")) is not None]
            windows.append({"reportedWindowStartActionSeconds": round(start, 6) if start is not None else None,
                            "callbackActionSeconds": at(e), "bodyFields": f,
                            "observedRuntimeDemandMinBps": min(demands) if demands else None,
                            "observedRuntimeDemandMaxBps": max(demands) if demands else None,
                            "runtimeDemandSampleCount": len(demands)})

        groups = defaultdict(list)
        missing = 0
        for e in owned:
            f = e["fields"]
            if f.get("proxyKind") != "mediaRange":
                continue
            if not f.get("transferID") or f.get("upstreamTaskIndex") is None:
                missing += 1
                continue
            groups[(f["transferID"], f["upstreamTaskIndex"])].append(e)
        requests = []
        for (transfer, index), group in groups.items():
            def first_stage(stage):
                return next((e for e in group if e["fields"].get("stage") == stage), None)
            issued = first_stage("upstreamRequestIssued")
            headers = next((e for e in group if e["event"] == "proxy_transfer_started"
                            and number(e["fields"].get("status")) is not None), None)
            completed = first_stage("upstreamTaskCompleted")
            metrics = [e for e in group if e["fields"].get("stage") == "urlSessionTaskMetrics"]
            unique_metrics = {json.dumps(e["fields"], sort_keys=True) for e in metrics}
            # Repeated snapshots must not double-count bodies. Conflicting
            # metrics stay ambiguous instead of silently taking the fastest.
            mf = metrics[0]["fields"] if len(unique_metrics) == 1 else {}
            body_ms = number(mf.get("lastResponseBodyMs"))
            body_bytes = number(mf.get("responseBodyBytesAfterDecoding"))
            body_bps = body_bytes * 8000 / body_ms if body_bytes is not None and body_ms and body_ms > 0 else None
            next_issued = next((e for e in owned if e["fields"].get("stage") == "upstreamRequestIssued"
                                and e["fields"].get("transferID") == transfer
                                and e["fields"].get("upstreamTaskIndex") == index + 1), None)
            gap = (at(next_issued) - at(completed)) * 1000 if next_issued and completed else None
            requests.append({"transferID": transfer, "upstreamTaskIndex": index,
                             "issuedActionSeconds": at(issued), "headersActionSeconds": at(headers),
                             "completedActionSeconds": at(completed),
                             "completionErrorCode": completed["fields"].get("errorCode") if completed else None,
                             "metricsIdentity": "unique" if len(unique_metrics) == 1 else "ambiguous" if metrics else "missing",
                             "metricsFields": mf, "observedBodyBps": round(body_bps) if body_bps is not None else None,
                             "nextIssueAfterCompletionMs": round(gap, 3) if gap is not None else None,
                             "cancellationRequestedActionSeconds": at(first_stage("upstreamCancellationRequested")),
                             "rightCensored": completed is None})
        traces.append({"traceID": trace, "engine": renderer["engine"],
                       "firstObservedAdvancingClockActionSeconds": renderer["firstObservedAdvancingClockActionSeconds"],
                       "stallEpisodes": renderer["stallEpisodes"],
                       "bufferPolicyChanges": [e for e in owned if e["event"] == "steady_state_buffer"],
                       "telemetry": [e for e in owned if e["event"] == "telemetry_sample"],
                       "predictionDecisions": decisions, "receivedBodyWindows": windows,
                       "rangeRequests": requests, "rangeEventsMissingIdentity": missing})
    return {"rendererTraces": traces, "seekCapacityPhases": seek_capacity_phases(events),
            "timeBoundary": "action.json requestStart is a host action boundary, not physical touch. Body-window starts are derived from rounded monotonic elapsedMs and event wall time.",
            "limits": ["Body windows may cross Range task boundaries; their current task index does not assign all bytes to that task.",
                       "Do not add body windows, task metrics or decoder bytes together, or treat these as total billed traffic.",
                       "Only in-window runtimeDemand samples are compared; missing demand is unknown, not zero.",
                       "A completed or cancelled task is not proof of a network fault; retain cancellation and completion errors.",
                       "No root-cause, screen, audio, fluid-model counterfactual or playback PASS is inferred."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("window", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    events, window = load_window(args.window)
    report = {"window": window, **reserve_report(events)}
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("Reserve traces:", len(report["rendererTraces"]), "; bounded events:", len(events))


if __name__ == "__main__":
    main()
