#!/usr/bin/env python3
"""Correlate saved Jellyfin commands with bounded client subtitle operations.

Reads private inputs; emits only allowlisted numbers and codec names. Matching
by time and first segment ordinal is supporting evidence, not session identity.
No server requests, media requests or changes to the app are performed.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import re
import shlex
from pathlib import Path

APPLE_EPOCH = 978307200
CODECS = {"h264_vaapi", "hevc_vaapi", "h264_qsv", "hevc_qsv", "libx264",
          "libx265", "copy", "aac", "libfdk_aac", "ac3", "eac3"}


def number(value):
    try:
        n = float(value)
        return n if math.isfinite(n) else None
    except (ValueError, TypeError, OverflowError):
        return None


def timestamp(text):
    # Python 3.9 accepts only 3 or 6 fractional digits; .NET emits 1–7.
    text = re.sub(r" ([-+]\d\d:\d\d)$", r"\1", text.strip())
    text = re.sub(r"\.(\d+)(?=Z|[+-])",
                  lambda m: "." + m[1][:6].ljust(6, "0"), text).replace("Z", "+00:00")
    value = dt.datetime.fromisoformat(text)
    if value.tzinfo is None:
        raise ValueError("A timezone is required for server correlation")
    return value.timestamp()


def server_commands(text, *, retain_output_keys=False):
    commands = []
    seen_lines = set()
    for line in text.splitlines():
        match = re.match(r"\[([^]]+)\]", line)
        if not match or " -start_number " not in line:
            continue
        if line in seen_lines:
            continue
        seen_lines.add(line)
        try:
            at = timestamp(match[1])
            args = shlex.split(line[match.end():])
            # Serilog can quote the complete command as one escaped string.
            # Unwrap that string as data; never invoke a shell or execute it.
            for _ in range(2):
                if "-start_number" in args:
                    break
                wrapped = [a for a in args if " -start_number " in a]
                if len(wrapped) != 1:
                    break
                args = shlex.split(wrapped[0])
            def option(name):
                i = args.index(name)
                return args[i + 1]
            ordinal = int(option("-start_number"))
            # A zero-based transcode legitimately omits -ss. Do not silently
            # discard it and then report that no server process was found.
            components = option("-ss").split(":") if "-ss" in args else ["0"]
            seek = sum(float(v) * (60 ** i) for i, v in enumerate(reversed(components)))
            if ordinal < 0 or not math.isfinite(seek) or seek < 0:
                continue
            codecs = {}
            for name, key in [("-codec:v:0", "videoCodec"), ("-codec:a:0", "audioCodec")]:
                if name in args:
                    codec = option(name)
                    codecs[key] = codec if codec in CODECS else "other"
            filters = option("-filter_complex") if "-filter_complex" in args else ""
            command = {"at": at, "startSegmentOrdinal": ordinal,
                             "seekSeconds": seek, **codecs,
                             "subtitleOverlayFilter": bool(re.search(
                                 r"\b(?:overlay|overlay_vaapi|overlay_qsv|subtitles)\b", filters))}
            if retain_output_keys and "-hls_segment_filename" in args:
                stem = option("-hls_segment_filename").rsplit("/", 1)[-1]
                key = re.fullmatch(r"([a-f0-9]{32})%\d*d\.(?:ts|m4s)", stem)
                if key:
                    command["_outputKey"] = key[1]
            commands.append(command)
        except (ValueError, IndexError, OverflowError):
            continue
    # An exported server log may overlap another downloaded snapshot.
    # Distinct raw commands at the same millisecond remain distinct even when
    # their allowlisted fields match; otherwise concurrency becomes a false match.
    return sorted(commands, key=lambda c: c["at"])


def details(event):
    value = event.get("detail", "")
    if isinstance(value, dict):
        return value
    return dict(part.split("=", 1) for part in value.split(", ") if "=" in part)


def trace_identity(fields):
    value = fields.get("playbackTraceID")
    return value if isinstance(value, str) and value not in ("", "-", "unknown") else None


def report(events, commands, actions, end, server_offset=0.0, match_window=5.0):
    if any(number(v) is None for v in [end, server_offset, match_window]) or match_window <= 0:
        raise ValueError("Finite bounds and a positive matching window are required")
    starts = [number(a.get("requestStart")) for a in actions]
    if any(v is None for v in starts) or len(set(starts)) != len(starts) or any(v >= end for v in starts):
        raise ValueError("Distinct finite action times before the observation end are required")
    starts.sort()
    rows = []
    for index, start in enumerate(starts):
        stop = starts[index + 1] if index + 1 < len(starts) else end
        window = sorted((e for e in events if number(e.get("date")) is not None
                         and start <= number(e["date"]) + APPLE_EPOCH < stop), key=lambda e: number(e["date"]))
        transfers = {}
        for event in window:
            f = details(event)
            if f.get("hlsRole") != "segment" or not f.get("transferID"):
                continue
            identity = (trace_identity(f), f["transferID"],
                        str(f.get("upstreamTaskIndex", "unknown")))
            transfer = transfers.setdefault(identity, {})
            if f.get("startupPrimer") == "true":
                transfer["startupPrimer"] = True
            stage = f.get("stage")
            t = round(number(event["date"]) + APPLE_EPOCH - start, 6)
            if stage == "upstreamRequestIssued":
                transfer.setdefault("requestSeconds", t)
                ordinal = number(f.get("segmentOrdinal"))
                transfer["segmentOrdinal"] = int(ordinal) if ordinal is not None and ordinal >= 0 and ordinal.is_integer() else None
            status = number(f.get("status"))
            if event.get("messageKey", "").endswith(".proxy_transfer_started") and status is not None and status.is_integer() and 100 <= status <= 599:
                transfer.setdefault("responseHeadersSeconds", t)
                transfer.setdefault("responseStatus", int(status))
                transfer["headersObserved"] = True
            # Keep absent evidence unknown. A 504 is a response, and explicit
            # zero-body/no-header callbacks are different from missing logs.
            if f.get("upstreamHeadersObserved") in ("true", "false"):
                observed = f["upstreamHeadersObserved"] == "true"
                transfer["headersObserved"] = transfer.get("headersObserved", False) or observed
            for field in ("upstreamTaskBodyBytes", "taskReceivedBytes"):
                count = number(f.get(field))
                if count is not None and count.is_integer() and count >= 0:
                    transfer["bodyBytesObserved"] = max(transfer.get("bodyBytesObserved", 0), int(count))
            if stage == "upstreamTaskCompleted":
                transfer["completionSeconds"] = t
                transfer["errorCode"] = number(f.get("errorCode"))
            if stage == "upstreamCancellationRequested":
                transfer["cancelRequestedSeconds"] = t
            if stage == "urlSessionTaskMetrics":
                transfer["requestMs"] = number(f.get("requestMs"))
                key = f.get("jellyfinOutputKeyCandidate", "")
                if (f.get("jellyfinOutputKeyBasis") == "10.11.11FormulaActualMetricsRequest"
                        and isinstance(key, str) and re.fullmatch(r"[a-f0-9]{32}", key)):
                    transfer.setdefault("_outputKeys", set()).add(key)
        # A touch starts before the gesture commits a seek. The existing
        # player may legitimately request another old-position segment in
        # that interval, including on the same playback trace.
        dispatches = [e for e in window if e.get("messageKey", "").endswith(".seek_dispatched")]
        boundary = "actionStart"
        dispatch_seconds = None
        dispatch_trace = None
        if len(dispatches) == 1:
            boundary = "seekDispatch"
            dispatch_seconds = round(number(dispatches[0]["date"]) + APPLE_EPOCH - start, 6)
            dispatch_trace = trace_identity(details(dispatches[0]))
        elif len(dispatches) > 1:
            boundary = "ambiguousSeekDispatch"
        requests, excluded = [], []
        for identity, transfer in sorted(transfers.items(),
                                         key=lambda pair: pair[1].get("requestSeconds", math.inf)):
            if "requestSeconds" not in transfer:
                continue
            reason = None
            if transfer.get("startupPrimer"):
                reason = "optionalStartupPrimer"
            elif boundary == "ambiguousSeekDispatch":
                reason = "ambiguousSeekDispatch"
            elif dispatch_seconds is not None:
                if transfer["requestSeconds"] < dispatch_seconds:
                    reason = "beforeSeekDispatch"
                elif dispatch_trace is not None and identity[0] is None:
                    reason = "missingPlaybackTrace"
                elif dispatch_trace is not None and identity[0] != dispatch_trace:
                    reason = "differentPlaybackTrace"
            if reason:
                # Retain all observed status/body/cancellation evidence while
                # omitting private trace/transfer identifiers from output.
                excluded.append({**transfer, "exclusionReason": reason})
            else:
                requests.append(transfer)
        first = requests[0] if requests else None
        ordinal = first.get("segmentOrdinal") if first else None
        request_start = start + first["requestSeconds"] if first else start
        candidates = [c for c in commands if ordinal is not None
                      and c["startSegmentOrdinal"] == ordinal
                      and 0 <= c["at"] - server_offset - request_start < min(match_window, stop - request_start)]
        output_keys = set().union(*(q.get("_outputKeys", set()) for q in requests
                                   if q.get("segmentOrdinal") == ordinal))
        output_commands = []
        association = "timeAndOrdinalOnly" if len(candidates) == 1 else ("ambiguous" if candidates else "unmatched")
        if output_keys:
            # An explicit candidate that conflicts or fails to match must not
            # silently fall back to a coincidental timestamp/ordinal match.
            candidates = []
            association = "ambiguousClientOutputKey"
            if len(output_keys) == 1:
                output_commands = [c for c in commands if c.get("_outputKey") in output_keys]
                candidates = [c for c in output_commands if c["startSegmentOrdinal"] == ordinal]
                association = ("outputKeyAndOrdinalMatch" if len(candidates) == 1 else
                               "ambiguousOutputCommands" if len(candidates) > 1 else
                               "outputKeyMatchesOtherOrdinal" if output_commands else "outputKeyUnmatched")
        matched = candidates[0] if len(candidates) == 1 else None
        def public_transfer(value):
            return {k: v for k, v in value.items() if not k.startswith("_")}
        row = {"operation": index + 1, "observationSeconds": round(stop - start, 6),
               "requestSelectionBoundary": boundary,
               "seekDispatchSecondsFromAction": dispatch_seconds,
               "seekDispatchTraceAvailable": dispatch_trace is not None,
               "excludedSegmentRequests": [public_transfer(q) for q in excluded],
               "firstSegmentRequests": [public_transfer(q) for q in requests if q.get("segmentOrdinal") == ordinal] if first else [],
               "serverCandidateCount": len(candidates),
               "clientOutputKeyCandidateCount": len(output_keys),
               "serverOutputKeyCommandCount": len(output_commands),
               "association": association,
               "serverCommand": ({**{k: v for k, v in matched.items() if k != "at" and not k.startswith("_")},
                                   "secondsFromAction": round(matched["at"] - server_offset - start, 6)} if matched else None)}
        for key in ["replacement_candidate_decoded", "replacement_committed"]:
            row[key + "Seconds"] = [round(number(e["date"]) + APPLE_EPOCH - start, 6) for e in window
                                    if e.get("messageKey", "").endswith("." + key)]
        row["candidateFailures"] = [
            {"secondsFromAction": round(number(e["date"]) + APPLE_EPOCH - start, 6),
             "stage": details(e).get("stage") if details(e).get("stage") in {
                 "initialSeek", "decodedFrame", "alignment", "bufferedSeek",
                 "bufferedSeekDecodedFrame", "candidateInvalidated", "commitRevalidation"} else "unknown",
             "elapsedMs": number(details(e).get("elapsedMs"))}
            for e in window if e.get("messageKey", "").endswith(".replacement_warmup_failed")]
        rows.append(row)
    return {"operations": rows, "serverMinusClientOffsetSecondsUsed": server_offset,
            "matchingWindowSeconds": match_window, "matchingBoundary": "firstSegmentRequest",
            "sessionIdentityVerified": False,
            "firstVisibleFrameAccepted": False, "actualAudibleAccepted": False,
            "limitations": ["Server command times are log records, not exact process or segment readiness.",
                            "Time and ordinal correlation does not exclude unrelated concurrent sessions.",
                            "Output-key candidates use a version-specific formula; a match is not segment readiness or clock synchronization.",
                            "Pre-dispatch requests are retained separately; touch start is not seek dispatch.",
                            "Missing events or commands stay unknown; request intervals may overlap."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server-log", action="append", required=True, type=Path)
    parser.add_argument("--client-events", required=True, type=Path)
    parser.add_argument("--actions", required=True, type=Path, help="JSON array with requestStart Unix seconds")
    parser.add_argument("--observation-end", required=True, type=float)
    parser.add_argument("--server-offset", type=float, default=0.0, help="server minus client seconds; historical proof required")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    commands = server_commands("\n".join(p.read_text(errors="replace") for p in args.server_log), retain_output_keys=True)
    result = report(json.loads(args.client_events.read_text()), commands,
                    json.loads(args.actions.read_text()), args.observation_end, args.server_offset)
    args.output.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
