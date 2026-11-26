#!/usr/bin/env python3
"""Report bounded playback phases without exporting raw preferences or URLs.

Input is one device observation directory (action.json, observations.json and
*-private.plist). Union snapshots by event ID before restricting the time window.
This reports sampled engine signals, never screen presentation or sound quality.
Candidate phases join only one HLS trace inside the source's warmup interval;
network intervals may overlap and must not be added into an inferred cause.
"""
from __future__ import annotations

import argparse
import json
import math
import plistlib
import re
from collections import defaultdict
from pathlib import Path

APPLE_EPOCH_OFFSET = 978307200
NUMERIC_KEYS = set("""
elapsedMs tapToFirstFrameMs firstFramePositionSeconds currentSeconds deltaSeconds
durationSeconds stallCount stallDurationMs lastStallDurationMs bufferAheadSeconds
bufferedAheadSeconds bufferTargetSeconds bufferLimitSeconds videoBitrate audioBitrate
bytesRead rate accessLogStalls accessLogBytes accessLogTransferMs accessLogThroughputMbps
observedBitrate indicatedBitrate loadedRangeCount candidateBufferAheadSeconds
candidateSeconds seconds current liveSeconds framePTS outputPTSSeconds rawClockSeconds
controlSeconds requestMs responseMs totalMs adaptiveTransferMs durationMs deliveredBytes
cumulativeReceivedBytes taskReceivedBytes expectedBytes contentLength retries status
upstreamTaskIndex segmentOrdinal proxyBackpressureMs proxyQueuedBytes proxySuspendCount
requestReceivedToIssueMs prepareMs measuredBitrate bitrate elapsed errorCode
audioStreamIndex subtitleStreamIndex returnedAudioIndex returnedSubtitleIndex
target preparationLeadSeconds availableReserveSeconds deadlineRemainingMs
deliveryCapacity predictiveDeliveryCapacity runtimeDemand attempt avTimeControlState preferredForwardBufferSeconds videoOutputCount
sourceBitrate seekGeneration qualifiedBodyCapacity effectiveBps bytes bodyBytes httpStatus apiErrorCode
seekTargetSeconds seekRecoveryMs seekDeltaSeconds mainThreadSubmissionMs selectionDispatchMs engineTrackID requestedTrackID
sinceRequestMs sampleUptimeSeconds loadedSeconds audioCapacityTracks videoCapacityTracks
audioPackets videoPackets audioFrames videoFrames audioMaximumFrames videoMaximumFrames
audioFPS videoFPS audioLoadedSeconds videoLoadedSeconds
apiVersion folderAttempt rewriteMs inputBytes outputBytes playlistSegments playlistDurationSeconds
playlistTargetDurationSeconds playlistFirstSegmentDurationSeconds
responseStartOffset responseEndOffset upstreamCancelToCallbackMs upstreamIssuedToCallbackMs
taskIntervalMs transactionCount transportErrorCode dnsMs tcpMs tlsMs
clientReadBytes clientReadErrorCode requestReceivedToReadEndMs
""".split())
NUMERIC_KEYS.update("""
videoSeekEpoch videoSeekTargetSeconds videoSeekCallbacks videoSeekDiscardedBeforeTarget
videoSeekAcceptedBeforePush videoSeekPushReturned videoSeekInvalidIntervals videoSeekSinceFlushMs
videoSeekFirstCallbackMs videoSeekFirstAcceptedMs videoSeekFirstPushReturnedMs
videoSeekLastAcceptedStartSeconds videoSeekLastAcceptedEndSeconds videoSeekTimebaseNum videoSeekTimebaseDen
videoSeekTimestampOriginSeconds videoSeekQueueFrames videoSeekQueueValidIntervals videoSeekQueueInvalidIntervals
videoSeekQueueSpanSeconds videoSeekQueueUnionSeconds videoSeekQueueGapSeconds
videoSeekQueueFirstStartSeconds videoSeekQueueLastEndSeconds
""".split())
ENUMS = {
    "engine": {"KSPlayer", "AVPlayer"},
    "timeControlStatus": {"paused", "playing", "waitingToPlayAtSpecifiedRate"},
    "reasonForWaiting": {"evaluatingBufferingRate", "toMinimizeStalls", "noItemToPlay", "-"},
    "waitingReason": {"AVPlayerWaitingWhileEvaluatingBufferingRateReason",
                      "AVPlayerWaitingToMinimizeStallsReason", "AVPlayerWaitingWithNoItemToPlayReason", "-"},
    "stallActive": {"yes", "no"}, "bufferEmpty": {"yes", "no", "true", "false"},
    "likelyToKeepUp": {"yes", "no", "true", "false"},
    "ksPlayerState": {"initialized", "preparing", "readyToPlay", "buffering", "bufferFinished",
                      "playing", "paused", "playedToTheEnd", "error", "-"},
    "state": {"initialized", "preparing", "readyToPlay", "buffering", "bufferFinished",
              "playing", "paused", "playedToTheEnd", "error", "rendererAppeared"},
    "stage": {"urlSessionTaskMetrics", "upstreamRequestIssued", "upstreamTaskCompleted",
              "clientTerminalSend", "decodedFrame", "initialSeek", "alignment", "preroll",
              "commitRevalidation", "bufferedSeek", "bufferedSeekDecodedFrame",
              "beforeConfiguration", "afterWaitingPolicy", "afterForwardBuffer",
              "afterTextStyle", "afterVideoOutput", "beforeResume", "afterResume"},
    "automaticallyWaits": {"yes", "no"},
    "proxyKind": {"hlsChild", "mediaRange", "hlsPlaylist"},
    "hlsRole": {"segment", "playlist", "master", "media", "masterPlaylist", "mediaPlaylist", "init", "key", "-"},
    "adaptiveMeasurementBoundary": {"responseBody", "fetchToResponseEnd"},
    "protocol": {"http/1.1", "h2", "h3", "-"}, "connectionReused": {"yes", "no"},
    "cellular": {"yes", "no"}, "sampleReason": {"itemInstalled", "itemStatusChanged",
        "timeControlChanged", "playbackTick", "firstFrame", "planReady", "bufferChanged",
        "stateChanged", "stop", "replacement", "ended"},
    "result": {"complete", "cancelled", "failed", "playbackInfoPrepared", "verifiedMatch"},
    "reason": {"sustainedRebuffering", "deliveryBelowSourceBitrate", "depletingOriginalReserve"},
    "deliveryCapacitySource": {"completedTransfer", "bodyWindow", "unknown"},
    "responseKind": {"nonHTTP", "httpFailure", "malformedEnvelope", "apiFailure", "success"},
    "contentType": {"json", "html", "plainText", "other", "unknown"},
    "method": {"list", "list_share"},
    "folderOrigin": {"snapshot", "browserRoot", "browserFolder"},
    "sessionRole": {"fileStation", "dsmFallback"},
    "authenticationStage": {"fileStationAttached", "fileStationUnavailable", "connectionPublished",
                            "sourcePrepared", "logoutStarted", "logoutSucceeded", "logoutFailed"},
    "finishSource": {"clientCancelled", "clientFailed", "clientHeaderSend", "clientBodySend",
                     "clientTerminalSend", "sendPlaylist()"},
    "transportErrorKind": {"none", "posix", "dns", "tls", "other", "unknown"},
    "clientReadErrorKind": {"none", "posix", "dns", "tls", "other", "unknown"},
    "clientReadObservation": {"requestHeader", "afterRequest"},
    "errorDomain": {"NSURLErrorDomain", "NSCocoaErrorDomain", "AVFoundationErrorDomain",
                    "CoreMediaErrorDomain", "kCFErrorDomainCFNetwork", "-"},
}
for key in ("eligible ready playing buffering pendingSeek changingSource clockAdvanced "
            "graceAllowsPrediction cooldownAllowsPrediction predictiveEligible "
            "predictsReserveDepletion predictsUnsustainableDelivery repeatedStalls "
            "recordedForAdaptiveEstimate bodyWindowPressured envelopeSuccess hasData callbackAfterClientFinish upstreamCancellationRequested upstreamCompletionObserved clientReadComplete clientReadAfterFinish startupPrimer").split():
    ENUMS[key] = {"true", "false"}
ENUMS["bodyWindowIncludesRangeBoundaries"] = {"true", "false"}
ENUMS["measurementBoundary"] = {"receivedBodyWindow"}
ENUMS["completed"] = {"true", "false"}
ENUMS["cachedVOD"] = {"true", "false"}
ENUMS["stage"].add("manifestPreparation")
for key in ("videoSeekCountsCapped", "videoSeekQueueSnapshotAvailable", "videoSeekProbeTargetMatchesRequest"):
    ENUMS[key] = {"true", "false"}
ENUMS["stage"].add("upstreamBodyProgress")
ENUMS["stage"].update({"playlistRewritten", "vodPlaylistCacheHit", "continuationResponse", "upstreamCancellationRequested", "clientReadEnded"})
PREPARATION_STAGES = {
    "playbackContextRequested", "playbackContextDiscarded", "playbackPathSettled",
    "publicCellularPreparationRetained", "preparedFallbackRevalidationStarted",
    "preparedFallbackRevalidationRejected", "preparedFallbackRevalidated",
    "preparedPublicationRejected", "preparedLibraryRevalidationStarted",
    "preparedLibraryRevalidationAttempt", "preparedLibraryRevalidationRejected", "preparedLibraryRevalidated",
    "contextResolutionRejected", "authenticatedPlaybackContext", "authenticatedOriginProbe",
    "authenticatedOriginProbesStarted", "authenticatedOriginProbeDiscarded",
    "authenticatedOriginProbeCompleted", "playbackPreparation", "playRequested",
}
ENUMS["stage"].update(PREPARATION_STAGES)
ENUMS["reason"].update({
    "ownershipChanged", "freshPreparationAfterPathChange", "pathDidNotSettleWithinBudget",
    "freshOwnOriginAfterCellularPathChange", "identityPathOrOwnershipChanged",
    "sameServerAndAccountOnCurrentPath", "missingLibraryClient", "cachedCurrentNetworkOwnSession",
    "overlapFirstOwnPublicSession", "primaryReachable", "primaryNotTransportFailureOrIdentityUnavailable",
    "overlapOwnershipChanged", "candidatePathChanged", "sameServerAndAccountCurrentPublicReachable",
    "libraryEndpoint", "verifiedSameServerLAN", "authenticatedOwnSessionFallback",
    "freshSameOriginAfterCellularPathChange", "authenticatedCurrentPath", "pathChanged",
    "cancelled", "unknownPath", "nonCellularPath", "missingIdentity", "identityMismatch",
    "taskCancelled", "credentialsOrSessionChanged", "networkBucketChanged", "connectionNotCellular",
    "pathIdentityUnknown", "pathGenerationUnchanged", "alternateEndpointSelection",
    "certificateOverrideEnabled", "libraryEndpointMismatch", "httpsRequired", "hostMissing", "privateHost",
})
ENUMS["selection"] = {"libraryEndpoint", "verifiedSameServerLAN", "authenticatedOwnSessionFallback"}
for key in ("credentialsCurrent", "sessionCurrent", "cancelled", "mediaRenegotiated", "hasFreshPrimaryIdentity",
            "willRetry", "ownEndpointTokenUsed"):
    ENUMS[key] = {"true", "false"}
NUMERIC_KEYS.update({"contextAttempt", "networkPathGeneration", "startedPathGeneration",
                     "preparedPathGeneration", "candidateHTTPStatus", "primaryHTTPStatus",
                     "lastFetchToRequestMs", "lastRequestSendMs", "lastRequestEndToFirstByteMs",
                     "lastResponseBodyMs", "lastResponseEndToMetricsCallbackMs",
                     "upstreamIssueToHeadersCallbackMs", "upstreamIssueToFirstBodyCallbackMs",
                     "upstreamIssueToLastBodyCallbackMs", "upstreamTaskBodyBytes"})
FILE_PREPARATION_PHASES = {"siblingDirectory", "sidecarSubtitle", "verifiedStreamMatch",
                           "verifiedOriginalRoute", "localRange", "remoteRange"}
ENUMS["phase"] = FILE_PREPARATION_PHASES | {"waiting", "playable", "expired"}
for key in ("isSeek", "isFirst", "playable", "audioEOF", "videoEOF"):
    ENUMS[key] = {"true", "false"}
ENUMS["result"].update({"started", "completed", "matched", "unavailable", "validated", "skipped"})
NUMERIC_KEYS.add("sinceRequestMs")

# These counters are not billing bytes. Missing/invalid values stay absent,
# while a real zero remains zero; response coding is allowlisted separately.
RESPONSE_BYTE_KEYS = {"responseBodyBytesReceivedIncludingProtocol", "responseBodyBytesAfterDecoding",
                      "responseContentLength"}
NUMERIC_KEYS.update(RESPONSE_BYTE_KEYS | {"responseStatusCode", "maximumAttempts"})


def number(value):
    try:
        n = float(value)
        return n if math.isfinite(n) else None
    except (ValueError, TypeError):
        return None


NUMERIC_KEYS.add("authenticationObservedMonoMs")

def safe_fields(detail):
    fields = detail if isinstance(detail, dict) else dict(
        part.split("=", 1) for part in detail.split(", ") if "=" in part)
    out = {}
    for key, value in fields.items():
        if key in NUMERIC_KEYS:
            n = number(value)
            if n is not None:
                if key in RESPONSE_BYTE_KEYS and (n < 0 or not n.is_integer()):
                    continue
                if key == "responseStatusCode" and (not n.is_integer() or not 100 <= n <= 599):
                    continue
                out[key] = int(n) if n.is_integer() else n
        elif key == "responseContentEncoding":
            codings = str(value).split(",")
            known = {"identity", "gzip", "deflate", "br", "zstd"}
            out[key] = value if (value in {"other", "unspecified"} or
                len(str(value)) <= 48 and all(c in known for c in codings)) else "unrecognized"
        elif key in ENUMS:
            out[key] = value if value in ENUMS[key] else "unrecognized"
        elif key == "playlistChildID":
            # PlaybackPlaylistChildren uses a base-36 slot plus safe extension,
            # not a URL, filename, or UUID. Retain only this generated form.
            if re.fullmatch(r"[0-9a-z]{1,12}(?:\.[0-9a-z]{1,8})?", str(value)):
                out[key] = value
        elif key in {"transferID", "authenticationGeneration", "fileStationGeneration", "requestAuthenticationGeneration"}:
            if re.fullmatch(r"[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}", str(value)):
                out[key] = value
        elif key in {"playbackTraceID", "planID", "routeID", "folderOperationID", "diagnosticClientID"}:
            if re.fullmatch(r"[A-Fa-f0-9]{8}", str(value)):
                out[key] = value
    return out


def load_window(directory):
    action = json.loads((directory / "action.json").read_text())
    observations = json.loads((directory / "observations.json").read_text())
    start = action["requestStart"] - APPLE_EPOCH_OFFSET
    end = max(o["responseEnd"] for o in observations) - APPLE_EPOCH_OFFSET
    seen = {}
    conflicts = set()
    for path in sorted(directory.glob("*-private.plist")):
        preferences = plistlib.loads(path.read_bytes())
        entries = preferences.get("diagnostics.entries.v1", b"[]")
        for entry in json.loads(entries):
            identity = entry.get("id")
            if identity is None:
                continue
            if identity in seen and entry != seen[identity]:
                conflicts.add(identity)
            seen[identity] = entry
    if conflicts:
        raise ValueError("Conflicting copies of a diagnostic event; refusing ambiguous union")
    events = []
    for entry in seen.values():
        date = number(entry.get("date"))
        key = entry.get("messageKey", "")
        if date is None or not start - 1 <= date <= end:
            continue
        if not re.fullmatch(r"diagnostics\.[A-Za-z0-9_.]{1,100}", key):
            continue
        events.append({"actionSeconds": round(date - start, 6),
                       "event": key.rsplit(".", 1)[-1],
                       "fields": safe_fields(entry.get("detail", ""))})
    events.sort(key=lambda e: e["actionSeconds"])
    return events, {"boundedEndActionSeconds": end - start,
                    "plannedWindowSeconds": max(o["targetSeconds"] for o in observations),
                    "deduplicatedWindowEventCount": len(events),
                    "snapshotsRead": len(list(directory.glob("*-private.plist")))}


def candidate_preparation(events):
    """Separate observed handoff intervals; do not add overlapping transfer times.

    Original-renderer events own the attempt. Join network events only when one
    different HLS trace is observed inside its warmup interval. Missing phases,
    ambiguous candidates and unfinished requests stay explicit.
    """
    result = []
    requests = [e for e in events if e["event"] == "automatic_downshift_requested"]
    for index, request in enumerate(requests):
        trace = request["fields"].get("playbackTraceID")
        if not trace:
            continue
        start = request["actionSeconds"]
        stop = requests[index + 1]["actionSeconds"] if index + 1 < len(requests) else float("inf")
        owned = [e for e in events if start <= e["actionSeconds"] < stop
                 and e["fields"].get("playbackTraceID") == trace]
        def first(name):
            return next((e for e in owned if e["event"] == name), None)
        phases = {name: first(name) for name in (
            "replacement_warmup_started", "replacement_candidate_decoded",
            "replacement_candidate_aligned", "replacement_committed")}
        warmup = phases["replacement_warmup_started"]
        terminal = next((e for e in owned if e["event"] in {
            "replacement_committed", "replacement_warmup_failed", "automatic_downshift_abandoned"}), None)
        boundary = terminal["actionSeconds"] if terminal else min(stop, events[-1]["actionSeconds"])
        times = {"requested": start, **{k: v["actionSeconds"] if v else None for k, v in phases.items()}}
        def span(a, b):
            return round(times[b] - times[a], 6) if times[a] is not None and times[b] is not None else None
        item = {"sourceTraceID": trace, "phasesActionSeconds": times,
                "requestToWarmupSeconds": span("requested", "replacement_warmup_started"),
                "warmupToDecodedSeconds": span("replacement_warmup_started", "replacement_candidate_decoded"),
                "decodedToAlignedSeconds": span("replacement_candidate_decoded", "replacement_candidate_aligned"),
                "requestToCommitSeconds": span("requested", "replacement_committed"),
                "terminal": terminal["event"] if terminal else "unobserved",
                "rightCensoredAtActionSeconds": None if terminal else boundary,
                "transfers": []}
        candidates = set()
        if warmup:
            candidates = {e["fields"]["playbackTraceID"] for e in events
                          if warmup["actionSeconds"] <= e["actionSeconds"] <= boundary
                          and e["fields"].get("proxyKind") in {"hlsChild", "hlsPlaylist"}
                          and e["fields"].get("playbackTraceID") not in {None, trace}}
        item["candidateTraceIDs"] = sorted(candidates)
        item["candidateIdentity"] = "unique" if len(candidates) == 1 else "ambiguous" if candidates else "unobserved"
        if len(candidates) == 1:
            candidate = next(iter(candidates))
            grouped = defaultdict(list)
            unidentified = 0
            for e in events:
                f = e["fields"]
                if f.get("playbackTraceID") != candidate or f.get("proxyKind") not in {"hlsChild", "hlsPlaylist"}:
                    continue
                if "transferID" in f:
                    grouped[f["transferID"]].append(e)
                elif warmup["actionSeconds"] <= e["actionSeconds"] <= boundary:
                    unidentified += 1
            item["unidentifiedTransferEvents"] = unidentified
            for identity, group in grouped.items():
                issued = next((e for e in group if e["fields"].get("stage") == "upstreamRequestIssued"), None)
                cached = next((e for e in group if e["fields"].get("stage") == "vodPlaylistCacheHit"), None)
                began = issued or cached
                if not began or not warmup["actionSeconds"] <= began["actionSeconds"] <= boundary:
                    continue
                headers = next((e for e in group if e["event"] == "proxy_transfer_started"
                                and "status" in e["fields"]), None)
                finished = next((e for e in group if e["event"] == "proxy_transfer_finished"
                                 and "result" in e["fields"]), None)
                item["transfers"].append({"transferID": identity,
                    "proxyKind": began["fields"].get("proxyKind"), "hlsRole": began["fields"].get("hlsRole"),
                    "segmentOrdinal": began["fields"].get("segmentOrdinal"),
                    "issuedActionSeconds": began["actionSeconds"],
                    "headersActionSeconds": headers["actionSeconds"] if headers else None,
                    "issuedToHeadersSeconds": round(headers["actionSeconds"] - began["actionSeconds"], 6) if headers else None,
                    "terminalActionSeconds": finished["actionSeconds"] if finished else None,
                    "result": finished["fields"]["result"] if finished else "unobserved",
                    "rightCensoredAtActionSeconds": None if finished else events[-1]["actionSeconds"],
                    "evidence": group})
        result.append(item)
    return result


def startup_segment_attempts(events, *, segment_ordinal=0):
    """Keep requests for one segment ordinal; child identity distinguishes retries.

    A receive EOF and a send failure are independent observations. In particular,
    do not promote receive EOF to a cancellation or discard a late failed request
    when a concurrent retry succeeds. The returned rows omit join identifiers.
    """
    grouped = defaultdict(list)
    missing = 0
    for event in sorted(events, key=lambda e: e["actionSeconds"]):
        f = event["fields"]
        if f.get("hlsRole") != "segment" or f.get("segmentOrdinal") != segment_ordinal:
            continue
        if not f.get("transferID"):
            missing += 1
            continue
        grouped[(f.get("playbackTraceID"), f["transferID"],
                 f.get("upstreamTaskIndex"))].append(event)
    rows, children = [], {}
    for (trace, _, _), group in grouped.items():
        def first(predicate):
            return next((e for e in group if predicate(e)), None)
        def stage(name):
            return first(lambda e: e["fields"].get("stage") == name)
        issued = stage("upstreamRequestIssued")
        if not issued or issued["actionSeconds"] < 0:
            continue
        f = issued["fields"]
        child = f.get("playlistChildID")
        identity = (trace, child) if trace and child else None
        if identity is not None and identity not in children:
            children[identity] = len(children) + 1
        headers = first(lambda e: e["event"] == "proxy_transfer_started"
                        and 100 <= e["fields"].get("status", -1) <= 599)
        read_end, cancel = stage("clientReadEnded"), stage("upstreamCancellationRequested")
        terminal = first(lambda e: e["event"] == "proxy_transfer_finished"
                         and e["fields"].get("finishSource") is not None)
        metrics = stage("urlSessionTaskMetrics")
        mf = metrics["fields"] if metrics else {}
        def at(e):
            return e["actionSeconds"] if e else None
        row = {"requestOrdinal": len(rows) + 1,
               "localChildGroup": children.get(identity) if identity else None,
               "retryIdentity": "same trace and local child" if identity else "unknown",
               "issuedActionSeconds": at(issued), "headersActionSeconds": at(headers),
               "readEndActionSeconds": at(read_end), "cancelRequestedActionSeconds": at(cancel),
               "terminalActionSeconds": at(terminal),
               "finishSource": terminal["fields"].get("finishSource") if terminal else None,
               "deliveredBytes": terminal["fields"].get("deliveredBytes") if terminal else None,
               "requestMs": mf.get("requestMs"), "bodyMs": mf.get("responseMs"),
               "protocol": mf.get("protocol"), "connectionReused": mf.get("connectionReused"),
               "cellular": mf.get("cellular")}
        rows.append(row)
    return {"requests": rows, "unidentifiedEvents": missing,
            "meaning": "Read EOF is receive-direction completion, not proof of full peer closure or cancellation. Overlapping attempts must not be summed. Missing child identity cannot prove retry ownership."}


def first_observed_segment_attempts(traces):
    reports = []
    for trace, events in traces.items():
        segments = sorted((e for e in events if e["fields"].get("hlsRole") == "segment"
                           and e["fields"].get("startupPrimer") != "true"),
                          key=lambda e: e["actionSeconds"])
        frame = min((e["actionSeconds"] for e in events if e["event"] == "first_frame"
                     and e["actionSeconds"] >= 0), default=float("inf"))
        issues = [e for e in segments if 0 <= e["actionSeconds"] < frame
                  and e["fields"].get("stage") == "upstreamRequestIssued"]
        if not issues:
            continue
        initial = issues[0]["fields"]
        ordinal = initial.get("segmentOrdinal")
        child = initial.get("playlistChildID")
        if child:
            selected = [e for e in segments if e["fields"].get("playlistChildID") == child]
        else:
            transfer = initial.get("transferID")
            selected = [e for e in segments if transfer and e["fields"].get("transferID") == transfer]
            if not transfer:
                selected = [issues[0]]
        # Keep late headers and terminals for attempts issued during startup.
        # New requests after the frame marker may be caused by a seek or replay.
        selected = [e for e in selected if e["fields"].get("stage") != "upstreamRequestIssued"
                    or e["actionSeconds"] < frame]
        evidence = startup_segment_attempts(selected, segment_ordinal=ordinal)
        reports.append({"traceID": trace, "segmentOrdinal": ordinal,
                        "firstIssueActionSeconds": issues[0]["actionSeconds"], **evidence})
    return reports


def analyze(events):
    traces = defaultdict(list)
    unassigned = 0
    for event in events:
        trace = event["fields"].get("playbackTraceID")
        if trace:
            traces[trace].append(event)
        else:
            unassigned += 1
    reports = []
    for trace, items in traces.items():
        telemetry = [e for e in items if e["event"] == "telemetry_sample"]
        if not telemetry:
            continue
        engines = {e["fields"].get("engine") for e in telemetry} - {None}
        engine = next(iter(engines)) if len(engines) == 1 else "ambiguous"
        episodes = []
        active = None
        advancing = None
        last = None
        ks_state = None
        transitions = []
        for event in items:
            f = event["fields"]
            if event["event"] == "engine_ready" and f.get("state") not in {None, "unrecognized"}:
                ks_state = f["state"]
            if event["event"] != "telemetry_sample":
                continue
            if f.get("ksPlayerState") not in {None, "-", "unrecognized"}:
                ks_state = f["ksPlayerState"]
            # Seek/installation jumps and rate intent alone do not establish progress.
            if advancing is None and last and number(f.get("currentSeconds")) is not None:
                previous = last["fields"]
                before = number(previous.get("currentSeconds"))
                delta = f["currentSeconds"] - before if before is not None else 0
                wall = event["actionSeconds"] - last["actionSeconds"]
                playing = f.get("timeControlStatus") == "playing" if engine == "AVPlayer" else (
                    ks_state in {"playing", "bufferFinished"})
                if playing and 0.05 < delta and 0 < wall and delta <= wall * 4 + 0.5:
                    advancing = event["actionSeconds"]
            state = (f.get("timeControlStatus"), f.get("stallActive"))
            if not last or state != (last["fields"].get("timeControlStatus"),
                                     last["fields"].get("stallActive")):
                transitions.append(event)
            if f.get("stallActive") == "yes" and active is None:
                active = {"startActionSeconds": event["actionSeconds"],
                          "phaseAtStart": "beforeObservedAdvancingClock" if advancing is None else "afterObservedAdvancingClock",
                          "startFields": f, "endActionSeconds": None,
                          "sampledSpanSeconds": None, "reportedDurationMs": None}
            elif f.get("stallActive") == "no" and active is not None:
                active["endActionSeconds"] = event["actionSeconds"]
                active["sampledSpanSeconds"] = event["actionSeconds"] - active["startActionSeconds"]
                active["reportedDurationMs"] = f.get("lastStallDurationMs")
                episodes.append(active)
                active = None
            last = event
        if active is not None:
            active["rightCensoredAtActionSeconds"] = telemetry[-1]["actionSeconds"]
            episodes.append(active)
        counters = [e["fields"]["stallCount"] for e in telemetry if "stallCount" in e["fields"]]
        metrics = [e for e in items if e["fields"].get("stage") == "urlSessionTaskMetrics"]
        hls = [e for e in metrics if e["fields"].get("hlsRole") == "segment"]
        hls.sort(key=lambda e: e["fields"].get("totalMs", -1), reverse=True)
        ranges = [e for e in metrics if e["fields"].get("proxyKind") == "mediaRange"]
        ranges.sort(key=lambda e: e["fields"].get("totalMs", -1), reverse=True)
        reports.append({"traceID": trace, "engine": engine,
                        "firstClockSignal": next((e for e in items if e["event"] == "first_frame"), None),
                        "firstObservedAdvancingClockActionSeconds": advancing,
                        "maxReportedStallCount": max(counters) if counters else None,
                        "counterDecreaseWithinTrace": any(b < a for a, b in zip(counters, counters[1:])),
                        "stallEpisodes": episodes, "stateTransitions": transitions,
                        "handoffConfiguration": [e for e in items if e["event"] == "av_handoff_boundary"],
                        "handoffEvents": [e for e in items if e["event"] in {
                            "replacement_warmup_started", "replacement_candidate_aligned",
                            "replacement_committed", "replacement_warmup_failed",
                            "automatic_downshift_requested", "automatic_downshift_abandoned"}],
                        "predictionDecisions": [e for e in items if e["event"] == "automatic_prediction_decision"],
                        "bodyProgress": [e for e in items if e["fields"].get("stage") == "upstreamBodyProgress"],
                        "segmentMetricCount": len(hls), "slowestThreeSegmentMetrics": hls[:3],
                        "rangeMetricCount": len(ranges), "slowestThreeRangeMetrics": ranges[:3],
                        "urlMetricsCellularYes": sum(e["fields"].get("cellular") == "yes" for e in metrics)})
    return {"rendererTraces": reports, "eventsWithoutTraceIdentity": unassigned,
            "startupTimeline": {
                "preparationEvents": [e for e in events if e["event"] == "playback_route_state"
                                      and e["fields"].get("stage") in PREPARATION_STAGES],
                "filePreparationEvents": [e for e in events if e["event"] == "playback_preparation_phase"
                                          and e["fields"].get("phase") in FILE_PREPARATION_PHASES],
                "engineFirstFrameMarkers": [e for e in events
                                            if e["event"] == "first_frame" and e["actionSeconds"] >= 0],
                "meaning": "actionSeconds is relative to action.json requestStart (the host's recorded action boundary), not a confirmed physical touch. tapToFirstFrameMs may start later at the renderer. Neither proves screen presentation.",
                "missingMarker": "No engine marker is unknown or censored, never zero startup time.",
            },
            "startupSegmentAttempts": startup_segment_attempts(events),
            "firstObservedSegmentAttempts": first_observed_segment_attempts(traces),
            "candidatePreparation": candidate_preparation(events),
            "directoryResponses": [e for e in events if e["event"] == "folder_response"],
            "tracesWithoutTelemetry": [trace for trace, items in traces.items()
                                       if not any(e["event"] == "telemetry_sample" for e in items)],
            "failureSignals": [e for e in events if e["event"].endswith(("_failed", "_failure"))
                               or (e["fields"].get("errorCode") not in {None, 0})],
            "acceptance": "Unchanged: recorded waits/stalls retained, no playback quality PASS or causal speed claim.",
            "limits": ["Engine waiting/empty is not proof of network starvation; retain waiting reason and reserve.",
                       "A unique HLS trace within warmup is a temporal association, not proof of a network or server root cause.",
                       "Transfer intervals overlap; late terminals stay bounded. Unrecognized result strings do not mean success.",
                       "First clock marker may reflect a prepared paused position, not advancing output or presentation.",
                       "First observed progress is limited by sparse telemetry; phase is descriptive, not an exact startup boundary.",
                       "Sampled stall intervals are observation spans, not display hitches or precise buffer durations.",
                       "Stalls are per trace; never subtract counters across renderers. Open episodes remain censored.",
                       "Missing metrics remain unknown; no screen, audio, full-frame, cache or competitor acceptance."]}


def syslog_capacity_coverage(raw_text, events):
    """Describe saved log copies, never infer collector lifetime from process exit.

    Device log timestamps stay in their own domain. A disconnect marker does
    not prove a hardware failure or whole-device disconnection. Only compare
    identified safe capacity fields; do not export log lines or marker IDs.
    """
    def identified(fields):
        return all(fields.get(k) is not None for k in
                   ("playbackTraceID", "planID", "seekGeneration", "sampleUptimeSeconds"))
    def canonical(fields):
        return json.dumps(fields, sort_keys=True)
    persisted = [e["fields"] for e in events if e["event"] == "seek_capacity_sample"]
    known = [f for f in persisted if identified(f)]
    wanted = {canonical(f) for f in known}
    traces = {f["playbackTraceID"] for f in known}
    live = set()
    timestamps = []
    disconnected = False
    if raw_text is not None:
        for line in raw_text.splitlines():
            stamp = re.match(r"([A-Za-z]{3} +[0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6}) ", line)
            if stamp:
                timestamps.append(stamp[1])
            if line.startswith("[disconnected:"):
                disconnected = True
            marker = "diagnostics.playback.next.seek_capacity_sample | "
            if marker not in line:
                continue
            fields = safe_fields(line.split(marker, 1)[1])
            if identified(fields) and fields["playbackTraceID"] in traces:
                live.add(canonical(fields))
    available = raw_text is not None
    identity_keys = ("playbackTraceID", "planID", "seekGeneration", "sampleUptimeSeconds")
    identity = lambda f: tuple(f[k] for k in identity_keys)
    persisted_by_identity = defaultdict(list)
    live_by_identity = defaultdict(list)
    for fields in known:
        persisted_by_identity[identity(fields)].append(fields)
    for copy in live:
        fields = json.loads(copy)
        live_by_identity[identity(fields)].append(fields)
    partial = conflicts = 0
    for key, copies in live_by_identity.items():
        expected = persisted_by_identity.get(key, [])
        for fields in copies:
            if fields in expected:
                continue
            if any(fields.items() <= full.items() for full in expected):
                partial += 1
            elif expected:
                conflicts += 1
    return {"rawLogAvailable": available,
            "firstDeviceLogTimestamp": timestamps[0] if timestamps else None,
            "lastDeviceLogTimestamp": timestamps[-1] if timestamps else None,
            "collectorDisconnectMarkerSeen": disconnected if available else None,
            "persistentCapacityEvents": len(persisted),
            "unidentifiedPersistentCapacityEvents": len(persisted) - len(known),
            "uniqueLiveCapacityCopiesForObservedTraces": len(live) if available else None,
            "matchingCapacityCopies": len(wanted & live) if available else None,
            "matchingCapacityEventIdentities": len(persisted_by_identity.keys() & live_by_identity.keys()) if available else None,
            "missingCapacityEventIdentities": len(persisted_by_identity.keys() - live_by_identity.keys()) if available else None,
            "partialSafeFieldCopiesWithoutConflict": partial if available else None,
            "conflictingSafeFieldCopies": conflicts if available else None,
            "missingCapacityCopies": len(wanted - live) if available else None,
            "unexpectedCapacityCopiesForObservedTraces": len(live - wanted) if available else None,
            "allIdentifiedPersistentCapacityCopiesSeen": wanted <= live if available and wanted else None,
            "scope": "Safe capacity fields only; a partial copy may be truncated and is not a full-field match. A disconnect marker can occur on intentional collector stop. Even exact matches do not prove complete media/log lifetime, screen presentation or sound. Device log time is not a host action clock."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("window", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    events, window = load_window(args.window)
    report = {"window": window, **analyze(events)}
    log = args.window / "syslog-private.log"
    report["syslogCapacityCoverage"] = syslog_capacity_coverage(log.read_text(errors="replace") if log.exists() else None, events)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("Renderer traces:", len(report["rendererTraces"]), "; bounded events:", len(events))


if __name__ == "__main__":
    main()
