#!/usr/bin/env python3
"""Align local Reader delivery timing with player clock and buffer samples.

Input is one or more exported diagnostics snapshots: a JSON list of
``{date, messageKey, detail}`` entries, or a preferences plist that holds
``diagnostics.entries.v1``. Entries are de-duplicated across snapshots.

For one playback trace the report joins, on the same monotonic uptime clock:

* ``readerTimingWindow`` records from ``NetworkMediaProxyTransfer``: time
  spent waiting for the Reader's next chunk and time spent waiting for the
  local player socket to accept it, plus delivered bytes and offsets;
* ``telemetry_sample`` records from the player: clock, stall flag, buffered
  seconds ahead and the demuxer's cumulative ``bytesRead``.

Proxy windows are prorated into each telemetry interval by overlap. Each
stall segment then gets one attribution:

* ``readerBound``: the proxy mostly waited for the Reader (SMB/FTP/WebDAV
  supply or its queue), so bytes did not reach the player in time. When the
  Reader reports its own timing (SMB does), ``readerDetail`` says whether its
  reads were ``queuedBehindAnotherRead`` on the same connection or spent the
  time ``onTheConnection`` (request sent to reply complete);
* ``playerNotReading``: the proxy mostly waited on the player socket, so the
  player stopped pulling bytes it had been offered (demux/decode/buffer);
* ``deliveredWithoutClock``: bytes reached the player without dominant waits
  but the clock did not move (compare delivered bitrate with demand);
* ``noReaderTransfer``: no Reader window overlapped the stall;
* ``insufficientEvidence``: samples lack the monotonic uptime field.

``readerSplit`` totals the Reader's own timing over the whole trace.
``wireBitrate`` is delivered bytes over the time reads spent on the connection:
what the link, the server and signing give one read at a time. Compare it with
the same device's HTTP delivery before changing how the Reader reads.
``firstReads`` lists each request's first chunk, where a wait behind another
read shows up as queue time rather than read time.

This is local delivery evidence only. It does not measure the NAS or the
Wi-Fi link and does not prove that delivered bytes were decodable.
"""

from __future__ import annotations

import argparse
import json
import plistlib
import sys
from pathlib import Path

from playback_trace_report import parse_details

APPLE_EPOCH = 978307200


def load_entries(paths: list[Path]) -> list[dict]:
    seen: set[tuple] = set()
    entries: list[dict] = []
    for path in paths:
        raw = path.read_bytes()
        if path.suffix == ".plist":
            blob = plistlib.loads(raw).get("diagnostics.entries.v1", b"[]")
            items = json.loads(blob)
        else:
            items = json.loads(raw)
        for item in items:
            key = (item.get("date"), item.get("messageKey"), item.get("detail", ""))
            if key in seen:
                continue
            seen.add(key)
            entries.append({"date": item.get("date"), "messageKey": item.get("messageKey", ""),
                            "fields": parse_details(item.get("detail", ""))})
    return entries


def number(value, default=None):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def overlap(a0: float, a1: float, b0: float, b1: float) -> float:
    return max(0.0, min(a1, b1) - max(a0, b0))


def proxy_windows(entries: list[dict], trace: str) -> list[dict]:
    windows = []
    for entry in entries:
        f = entry["fields"]
        if f.get("stage") != "readerTimingWindow" or f.get("playbackTraceID") != trace:
            continue
        start, end = number(f.get("windowStartUptimeMs")), number(f.get("windowEndUptimeMs"))
        if start is None or end is None:
            continue
        windows.append({
            "start": start / 1000, "end": max(end, start) / 1000,
            "transferID": f.get("transferID"), "range": f.get("range"),
            "bytes": number(f.get("windowBytes"), 0), "readerWait": number(f.get("readerWaitMs"), 0) / 1000,
            "consumerWait": number(f.get("consumerWaitMs"), 0) / 1000,
            "dominantWait": f.get("dominantWait"), "pendingWait": f.get("pendingWait"),
            # Present only for a Reader that reports its own timing.
            "readerReads": number(f.get("readerReads"), 0),
            "readerQueueWait": number(f.get("readerQueueWaitMs"), 0) / 1000,
            "readerRead": number(f.get("readerReadMs"), 0) / 1000,
        })
    return sorted(windows, key=lambda w: w["start"])


def reader_split(windows: list[dict]) -> dict | None:
    """The Reader's own account of its wait, summed over every window."""
    reads = sum(w["readerReads"] for w in windows)
    if reads <= 0:
        return None
    wait = sum(w["readerWait"] for w in windows)
    queue = sum(w["readerQueueWait"] for w in windows)
    read = sum(w["readerRead"] for w in windows)
    size = sum(w["bytes"] for w in windows if w["readerReads"] > 0)
    return {
        "reads": round(reads), "bytes": round(size),
        "readerWaitMs": round(wait * 1000), "queueWaitMs": round(queue * 1000),
        "readMs": round(read * 1000),
        # Hops between the proxy, the Reader and its worker.
        "otherMs": round(max(0.0, wait - queue - read) * 1000),
        "meanReadMs": round(read / reads * 1000, 1),
        "meanQueueWaitMs": round(queue / reads * 1000, 1),
        "wireBitrate": round(size * 8 / read) if read > 0 else None,
    }


def first_reads(entries: list[dict], trace: str) -> list[dict]:
    """Each request's first chunk: total delay, and the Reader's split of it."""
    rows = []
    for entry in entries:
        f = entry["fields"]
        if f.get("stage") != "readerFirstChunkDelivered" or f.get("playbackTraceID") != trace:
            continue
        rows.append({
            "transferID": f.get("transferID"), "bytes": number(f.get("bytes")),
            "readerToDeliveryMs": number(f.get("readerToDeliveryMs")),
            "queueWaitMs": number(f.get("firstReadQueueWaitMs")),
            "readMs": number(f.get("firstReadMs")),
        })
    return rows


def player_samples(entries: list[dict], trace: str) -> list[dict]:
    samples = []
    for entry in entries:
        f = entry["fields"]
        if not entry["messageKey"].endswith("telemetry_sample") or f.get("playbackTraceID") != trace:
            continue
        uptime = number(f.get("uptimeMs"))
        samples.append({
            "uptime": None if uptime is None else uptime / 1000,
            "currentSeconds": number(f.get("currentSeconds")),
            "stallActive": f.get("stallActive") == "yes",
            "state": f.get("ksPlayerState"),
            "bufferedAheadSeconds": number(f.get("bufferedAheadSeconds")),
            "bytesRead": number(f.get("bytesRead")),
            "demandBitrate": (number(f.get("videoBitrate"), 0) or 0) + (number(f.get("audioBitrate"), 0) or 0),
        })
    timed = [s for s in samples if s["uptime"] is not None]
    return sorted(timed, key=lambda s: s["uptime"]) if timed else samples


def interval_supply(windows: list[dict], t0: float, t1: float) -> dict:
    out = {"proxyBytes": 0.0, "readerWait": 0.0, "consumerWait": 0.0,
           "readerReads": 0.0, "readerQueueWait": 0.0, "readerRead": 0.0}
    for w in windows:
        span = w["end"] - w["start"]
        if span <= 0:
            share = 1.0 if t0 < w["end"] <= t1 else 0.0
        else:
            share = overlap(t0, t1, w["start"], w["end"]) / span
        if share <= 0:
            continue
        out["proxyBytes"] += w["bytes"] * share
        out["readerWait"] += w["readerWait"] * share
        out["consumerWait"] += w["consumerWait"] * share
        out["readerReads"] += w["readerReads"] * share
        out["readerQueueWait"] += w["readerQueueWait"] * share
        out["readerRead"] += w["readerRead"] * share
    return out


def reader_detail(supply: dict) -> str:
    """Where a Reader-bound wait went, by the Reader's own timing."""
    if supply["readerReads"] <= 0:
        return "notReported"
    wait, queue, read = supply["readerWait"], supply["readerQueueWait"], supply["readerRead"]
    if queue >= wait * 0.5 and queue >= read * 2:
        return "queuedBehindAnotherRead"
    if read >= wait * 0.5 and read >= queue * 2:
        return "onTheConnection"
    return "mixed"


def attribute(seconds: float, supply: dict, windows_overlapped: bool) -> str:
    if not windows_overlapped:
        return "noReaderTransfer"
    reader, consumer = supply["readerWait"], supply["consumerWait"]
    if reader >= seconds * 0.5 and reader >= consumer * 2:
        return "readerBound"
    if consumer >= seconds * 0.5 and consumer >= reader * 2:
        return "playerNotReading"
    return "deliveredWithoutClock"


def build_report(entries: list[dict], trace: str) -> dict:
    windows = proxy_windows(entries, trace)
    samples = player_samples(entries, trace)
    if not samples or samples[0]["uptime"] is None:
        return {"trace": trace, "readerWindows": len(windows), "playerSamples": len(samples),
                "stalls": [], "verdict": "insufficientEvidence",
                "readerSplit": reader_split(windows), "firstReads": first_reads(entries, trace)}
    rows = []
    for prev, cur in zip(samples, samples[1:]):
        t0, t1 = prev["uptime"], cur["uptime"]
        if t1 <= t0:
            continue
        supply = interval_supply(windows, t0, t1)
        bytes_read = None
        if cur["bytesRead"] is not None and prev["bytesRead"] is not None:
            bytes_read = max(0.0, cur["bytesRead"] - prev["bytesRead"])
        clock = None
        if cur["currentSeconds"] is not None and prev["currentSeconds"] is not None:
            clock = cur["currentSeconds"] - prev["currentSeconds"]
        rows.append({
            "startUptimeMs": round(t0 * 1000), "endUptimeMs": round(t1 * 1000),
            "clockDeltaSeconds": None if clock is None else round(clock, 3),
            "stallActive": cur["stallActive"], "state": cur["state"],
            "bufferedAheadSeconds": cur["bufferedAheadSeconds"],
            "playerBytesRead": None if bytes_read is None else round(bytes_read),
            "proxyDeliveredBytes": round(supply["proxyBytes"]),
            "readerWaitMs": round(supply["readerWait"] * 1000),
            "consumerWaitMs": round(supply["consumerWait"] * 1000),
            "readerReads": round(supply["readerReads"], 2),
            "readerQueueWaitMs": round(supply["readerQueueWait"] * 1000),
            "readerReadMs": round(supply["readerRead"] * 1000),
            "demandBitrate": cur["demandBitrate"] or None,
            "_t0": t0, "_t1": t1, "_overlap": any(overlap(t0, t1, w["start"], w["end"]) > 0
                                                  or t0 < w["end"] <= t1 for w in windows),
        })
    stalls = []
    current: list[dict] = []
    for row in rows + [None]:
        stalled = row is not None and (row["stallActive"] or (row["clockDeltaSeconds"] is not None
                                                              and row["clockDeltaSeconds"] < 0.05
                                                              and row["state"] == "buffering"))
        if stalled:
            current.append(row)
            continue
        if current:
            seconds = current[-1]["_t1"] - current[0]["_t0"]
            supply = {"proxyBytes": sum(r["proxyDeliveredBytes"] for r in current),
                      "readerWait": sum(r["readerWaitMs"] for r in current) / 1000,
                      "consumerWait": sum(r["consumerWaitMs"] for r in current) / 1000,
                      "readerReads": sum(r["readerReads"] for r in current),
                      "readerQueueWait": sum(r["readerQueueWaitMs"] for r in current) / 1000,
                      "readerRead": sum(r["readerReadMs"] for r in current) / 1000}
            read = [r["playerBytesRead"] for r in current if r["playerBytesRead"] is not None]
            demand = max((r["demandBitrate"] or 0) for r in current) or None
            stalls.append({
                "startUptimeMs": current[0]["startUptimeMs"], "endUptimeMs": current[-1]["endUptimeMs"],
                "seconds": round(seconds, 3), "intervals": len(current),
                "proxyDeliveredBytes": round(supply["proxyBytes"]),
                "proxyDeliveredBitrate": round(supply["proxyBytes"] * 8 / seconds) if seconds > 0 else None,
                "playerBytesRead": round(sum(read)) if read else None,
                "demandBitrate": demand,
                "readerWaitMs": round(supply["readerWait"] * 1000),
                "consumerWaitMs": round(supply["consumerWait"] * 1000),
                "attribution": attribute(seconds, supply, any(r["_overlap"] for r in current)),
            })
            if stalls[-1]["attribution"] == "readerBound":
                stalls[-1]["readerQueueWaitMs"] = round(supply["readerQueueWait"] * 1000)
                stalls[-1]["readerReadMs"] = round(supply["readerRead"] * 1000)
                stalls[-1]["readerDetail"] = reader_detail(supply)
            current = []
    for row in rows:
        for key in ("_t0", "_t1", "_overlap"):
            row.pop(key)
    kinds = {s["attribution"] for s in stalls}
    return {"trace": trace, "readerWindows": len(windows), "playerSamples": len(samples),
            "intervals": rows, "stalls": stalls,
            "readerSplit": reader_split(windows), "firstReads": first_reads(entries, trace),
            "verdict": "noStall" if not stalls else (kinds.pop() if len(kinds) == 1 else "mixed"),
            "boundary": "localReaderDeliveryAndPlayerSamples"}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("trace")
    parser.add_argument("snapshots", nargs="+", type=Path)
    args = parser.parse_args(argv)
    report = build_report(load_entries(args.snapshots), args.trace)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
