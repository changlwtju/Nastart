"""Bounded evidence, identity separation and privacy regressions."""
import json
import plistlib
import tempfile
import unittest
from pathlib import Path

from playback_phase_report import APPLE_EPOCH_OFFSET, analyze, candidate_preparation, load_window, safe_fields, startup_segment_attempts, syslog_capacity_coverage


def event(time, trace="AAAAAAAA", **fields):
    return {"actionSeconds": time, "event": "telemetry_sample",
            "fields": {"playbackTraceID": trace, "engine": "AVPlayer", **fields}}


class PhaseReportTests(unittest.TestCase):
    def test_manifest_cache_and_failure_stage_remain_separate_from_decode(self):
        self.assertEqual(safe_fields("stage=manifestPreparation, cachedVOD=false, elapsedMs=120, url=https://private/?token=secret"),
                         {"stage": "manifestPreparation", "cachedVOD": "false", "elapsedMs": 120})

    def test_predictive_capacity_is_distinct_from_budget_hint_and_unknown(self):
        fields = safe_fields("deliveryCapacity=59997013, predictiveDeliveryCapacity=49559678, target=https://private/?token=secret")
        self.assertEqual(fields["deliveryCapacity"], 59997013)
        self.assertEqual(fields["predictiveDeliveryCapacity"], 49559678)
        self.assertNotIn("secret", json.dumps(fields))
        self.assertEqual(safe_fields({"predictiveDeliveryCapacity": "0"}), {"predictiveDeliveryCapacity": 0})
        for missing in ["unknown", "NaN", "inf"]:
            self.assertNotIn("predictiveDeliveryCapacity", safe_fields({"predictiveDeliveryCapacity": missing}))

    def test_syslog_disconnected_collector_is_not_complete_capacity_evidence(self):
        e = {"event": "seek_capacity_sample", "fields": safe_fields({"playbackTraceID": "AAAAAAAA",
             "planID": "BBBBBBBB", "seekGeneration": "2", "sampleUptimeSeconds": "100", "phase": "waiting"})}
        report = syslog_capacity_coverage("Oct 23 18:07:45.996064 Nastart log\n[disconnected:private-device-id]\n", [e])
        self.assertTrue(report["collectorDisconnectMarkerSeen"])
        self.assertFalse(report["allIdentifiedPersistentCapacityCopiesSeen"])
        self.assertEqual(report["missingCapacityCopies"], 1)
        self.assertEqual(report["lastDeviceLogTimestamp"], "Oct 23 18:07:45.996064")
        self.assertNotIn("private-device-id", json.dumps(report))

    def test_syslog_duplicate_copies_and_other_trace_do_not_hide_missing_fields(self):
        detail = "playbackTraceID=AAAAAAAA, planID=BBBBBBBB, seekGeneration=2, sampleUptimeSeconds=100, phase=waiting"
        e = {"event": "seek_capacity_sample", "fields": safe_fields(detail)}
        line = "diagnostics.playback.next.seek_capacity_sample | " + detail + ", url=https://private/?token=secret\n"
        other = line.replace("AAAAAAAA", "CCCCCCCC")
        report = syslog_capacity_coverage(line + line + other, [e])
        self.assertTrue(report["allIdentifiedPersistentCapacityCopiesSeen"])
        self.assertEqual(report["matchingCapacityCopies"], 1)
        self.assertEqual(report["uniqueLiveCapacityCopiesForObservedTraces"], 1)
        self.assertNotIn("secret", json.dumps(report))
        changed = {**e, "fields": {**e["fields"], "videoSeekDiscardedBeforeTarget": 12}}
        report = syslog_capacity_coverage(line, [changed])
        self.assertFalse(report["allIdentifiedPersistentCapacityCopiesSeen"])
        self.assertEqual(report["missingCapacityCopies"], 1)

    def test_syslog_partial_fields_keep_event_presence_separate_from_full_match(self):
        detail = "playbackTraceID=AAAAAAAA, planID=BBBBBBBB, seekGeneration=2, sampleUptimeSeconds=100, phase=waiting"
        e = {"event": "seek_capacity_sample", "fields": {**safe_fields(detail), "videoSeekDiscardedBeforeTarget": 19}}
        line = "diagnostics.playback.next.seek_capacity_sample | " + detail + "\n"
        report = syslog_capacity_coverage(line, [e])
        self.assertEqual(report["matchingCapacityEventIdentities"], 1)
        self.assertEqual(report["missingCapacityEventIdentities"], 0)
        self.assertEqual(report["partialSafeFieldCopiesWithoutConflict"], 1)
        self.assertEqual(report["conflictingSafeFieldCopies"], 0)
        self.assertFalse(report["allIdentifiedPersistentCapacityCopiesSeen"])
        report = syslog_capacity_coverage(line.replace("phase=waiting", "phase=playable"), [e])
        self.assertEqual(report["matchingCapacityEventIdentities"], 1)
        self.assertEqual(report["partialSafeFieldCopiesWithoutConflict"], 0)
        self.assertEqual(report["conflictingSafeFieldCopies"], 1)

    def test_syslog_missing_file_or_missing_identity_stays_unknown(self):
        e = {"event": "seek_capacity_sample", "fields": {"phase": "waiting"}}
        report = syslog_capacity_coverage(None, [e])
        self.assertFalse(report["rawLogAvailable"])
        self.assertIsNone(report["allIdentifiedPersistentCapacityCopiesSeen"])
        self.assertIsNone(report["matchingCapacityCopies"])
        self.assertEqual(report["unidentifiedPersistentCapacityEvents"], 1)
        self.assertIsNone(syslog_capacity_coverage("", [])["allIdentifiedPersistentCapacityCopiesSeen"])

    def test_seek_frame_units_zero_counts_and_unknown_queue_coverage(self):
        fields = safe_fields({"videoSeekDiscardedBeforeTarget": "0", "videoSeekAcceptedBeforePush": "16",
                              "videoSeekTimebaseNum": "1", "videoSeekTimebaseDen": "90000",
                              "videoSeekQueueInvalidIntervals": "1", "videoSeekQueueUnionSeconds": "unknown",
                              "videoSeekCountsCapped": "false", "videoSeekQueueSnapshotAvailable": "true",
                              "videoSeekProbeTargetMatchesRequest": "true", "videoSeekFirstAcceptedMs": "NaN",
                              "videoSeekQueueFirstStartSeconds": "https://private/?token=secret"})
        self.assertEqual(fields["videoSeekDiscardedBeforeTarget"], 0)
        self.assertEqual(fields["videoSeekTimebaseDen"], 90000)
        self.assertEqual(fields["videoSeekQueueInvalidIntervals"], 1)
        self.assertEqual(fields["videoSeekCountsCapped"], "false")
        self.assertNotIn("videoSeekQueueUnionSeconds", fields)
        self.assertNotIn("videoSeekFirstAcceptedMs", fields)
        self.assertNotIn("videoSeekQueueFirstStartSeconds", fields)
        self.assertNotIn("secret", json.dumps(fields))

    def test_seek_capacity_zero_queue_and_missing_media_remain_distinct(self):
        fields = safe_fields("phase=waiting, isSeek=true, isFirst=false, playable=false, seekGeneration=2, sinceRequestMs=500, loadedSeconds=0, audioCapacityTracks=1, audioPackets=0, audioFrames=0, audioFPS=31.25, audioLoadedSeconds=0, videoCapacityTracks=0, target=https://private/?token=secret")
        self.assertEqual(fields["audioLoadedSeconds"], 0)
        self.assertEqual(fields["audioFrames"], 0)
        self.assertEqual(fields["videoCapacityTracks"], 0)
        self.assertNotIn("videoFrames", fields)
        self.assertNotIn("secret", json.dumps(fields))
        missing = safe_fields({"audioLoadedSeconds": "unknown", "audioFPS": "NaN"})
        self.assertEqual(missing, {})

    def test_seek_capacity_terminal_does_not_become_file_preparation(self):
        for phase in ["waiting", "playable", "expired"]:
            e = {"actionSeconds": 1, "event": "seek_capacity_sample",
                 "fields": safe_fields({"phase": phase, "playable": "false"})}
            self.assertEqual(e["fields"]["phase"], phase)
            self.assertEqual(analyze([e])["startupTimeline"]["filePreparationEvents"], [])

    def test_audio_shared_seek_numbers_survive_without_claiming_sound(self):
        fields = safe_fields("engineTrackID=4, requestedTrackID=4, selectionDispatchMs=0, seekTargetSeconds=3962.398, seekRecoveryMs=3956, seekDeltaSeconds=-0.1, mainThreadSubmissionMs=0.25, completed=true, target=https://private/?token=secret")
        self.assertEqual(fields, {"engineTrackID": 4, "requestedTrackID": 4,
            "selectionDispatchMs": 0, "seekTargetSeconds": 3962.398,
            "seekRecoveryMs": 3956, "seekDeltaSeconds": -0.1,
            "mainThreadSubmissionMs": 0.25, "completed": "true"})
        self.assertNotIn("secret", json.dumps(fields))
        missing = safe_fields({"seekRecoveryMs": "unknown", "seekTargetSeconds": "NaN"})
        self.assertEqual(missing, {})

    def test_manifest_timing_numbers_are_allowlisted_without_resource_text(self):
        fields = safe_fields({"playlistTargetDurationSeconds": "5",
                              "playlistFirstSegmentDurationSeconds": "4.004",
                              "resource": "https://private.example/movie?token=secret"})
        self.assertEqual(fields["playlistTargetDurationSeconds"], 5)
        self.assertEqual(fields["playlistFirstSegmentDurationSeconds"], 4.004)
        self.assertNotIn("secret", json.dumps(fields))
        missing = safe_fields({"playlistTargetDurationSeconds": "unknown",
                               "playlistFirstSegmentDurationSeconds": "NaN"})
        self.assertNotIn("playlistTargetDurationSeconds", missing)
        self.assertNotIn("playlistFirstSegmentDurationSeconds", missing)

    def test_first_segment_keeps_overlapping_retry_and_late_send_failure(self):
        def row(t, transfer, stage=None, **fields):
            return {"actionSeconds": t, "event": "proxy_transfer_finished",
                    "fields": {"playbackTraceID": "AAAAAAAA", "transferID": transfer,
                               "playlistChildID": "BBBBBBBB", "hlsRole": "segment",
                               "segmentOrdinal": 0, "upstreamTaskIndex": 1,
                               **({"stage": stage} if stage else {}), **fields}}
        events = [row(2, "first", "upstreamRequestIssued"),
                  row(6, "first", "clientReadEnded"),
                  row(6.1, "retry", "upstreamRequestIssued"),
                  row(6.5, "retry", "urlSessionTaskMetrics", requestMs=300, responseMs=100),
                  row(6.6, "retry", finishSource="clientTerminalSend", deliveredBytes=100),
                  row(7, "first", finishSource="clientFailed", deliveredBytes=0),
                  row(7.1, "first", "upstreamCancellationRequested")]
        report = startup_segment_attempts(events)
        a, b = report["requests"]
        self.assertEqual(a["localChildGroup"], b["localChildGroup"])
        self.assertEqual(a["readEndActionSeconds"], 6)
        self.assertEqual(a["cancelRequestedActionSeconds"], 7.1)
        self.assertEqual(a["finishSource"], "clientFailed")
        self.assertEqual(a["deliveredBytes"], 0)
        self.assertEqual(b["finishSource"], "clientTerminalSend")
        self.assertEqual(b["bodyMs"], 100)
        self.assertNotIn("first", json.dumps(report["requests"]))

    def test_first_segment_does_not_merge_different_or_unknown_children(self):
        events = []
        for i, child in enumerate(["BBBBBBBB", "CCCCCCCC", None]):
            events.append({"actionSeconds": i + 1, "event": "proxy_transfer_started",
                           "fields": {"playbackTraceID": "AAAAAAAA", "transferID": str(i),
                                      "playlistChildID": child, "hlsRole": "segment",
                                      "segmentOrdinal": 0, "stage": "upstreamRequestIssued"}})
        rows = startup_segment_attempts(events)["requests"]
        self.assertNotEqual(rows[0]["localChildGroup"], rows[1]["localChildGroup"])
        self.assertIsNone(rows[2]["localChildGroup"])
        self.assertEqual(rows[2]["retryIdentity"], "unknown")
        self.assertTrue(all(row["terminalActionSeconds"] is None for row in rows))
        self.assertTrue(all(row["requestMs"] is None for row in rows))

    def test_first_segment_missing_transfer_and_prior_requests_stay_explicit(self):
        rows = [{"actionSeconds": t, "event": "proxy_transfer_started", "fields": f}
                for t, f in [(-1, {"transferID": "old", "hlsRole": "segment",
                                   "segmentOrdinal": 0, "stage": "upstreamRequestIssued"}),
                              (1, {"hlsRole": "segment", "segmentOrdinal": 0}),
                              (2, {"transferID": "later", "hlsRole": "segment",
                                   "segmentOrdinal": 1, "stage": "upstreamRequestIssued"})]]
        report = startup_segment_attempts(rows)
        self.assertEqual(report["requests"], [])
        self.assertEqual(report["unidentifiedEvents"], 1)

    def test_first_segment_child_join_rejects_private_identifiers(self):
        self.assertEqual(safe_fields({"playlistChildID": "0.ts"}),
                         {"playlistChildID": "0.ts"})
        self.assertEqual(safe_fields({"playlistChildID": "https://private/?token=secret"}), {})

    def test_first_observed_resume_segment_keeps_retries_and_late_terminals(self):
        def row(time, transfer, ordinal, child, trace="AAAAAAAA", **details):
            return {"actionSeconds": time, "event": "proxy_transfer_finished" if "finishSource" in details
                    else "proxy_transfer_started", "fields": {"playbackTraceID": trace,
                    "transferID": transfer, "playlistChildID": child, "hlsRole": "segment",
                    "segmentOrdinal": ordinal, "upstreamTaskIndex": 1, **details}}

        issued = {"stage": "upstreamRequestIssued"}
        events = [row(1, "primer", 0, "0.ts", startupPrimer="true", **issued),
                  row(2, "original", 166, "16.ts", **issued),
                  row(2.1, "parallel", 166, "26.ts", **issued),
                  row(2.2, "other", 0, "0.ts", "BBBBBBBB", **issued),
                  row(5, "retry", 166, "16.ts", **issued),
                  row(6, "retry", 166, "16.ts", status=200),
                  {"actionSeconds": 7, "event": "first_frame", "fields": {"playbackTraceID": "AAAAAAAA"}},
                  row(7.1, "original", 166, "16.ts", finishSource="clientBodySend"),
                  row(8, "seek", 166, "16.ts", **issued),
                  row(9, "seek", 166, "16.ts", status=200)]

        report = analyze(list(reversed(events)))
        by_trace = {r["traceID"]: r for r in report["firstObservedSegmentAttempts"]}
        resume = by_trace["AAAAAAAA"]
        self.assertEqual(resume["segmentOrdinal"], 166)
        self.assertEqual(resume["firstIssueActionSeconds"], 2)
        a, b = resume["requests"]
        self.assertEqual(a["localChildGroup"], b["localChildGroup"])
        self.assertEqual(a["terminalActionSeconds"], 7.1)
        self.assertEqual(b["headersActionSeconds"], 6)
        self.assertEqual(by_trace["BBBBBBBB"]["segmentOrdinal"], 0)
        self.assertEqual(len(report["startupSegmentAttempts"]["requests"]), 2)
        self.assertEqual(safe_fields("startupPrimer=true"), {"startupPrimer": "true"})

    def test_first_observed_does_not_assume_retry_when_child_identity_is_missing(self):
        def issue(time, transfer, **fields):
            return {"actionSeconds": time, "event": "proxy_transfer_started",
                    "fields": {"playbackTraceID": "AAAAAAAA", "transferID": transfer,
                               "hlsRole": "segment", "stage": "upstreamRequestIssued", **fields}}

        events = [issue(1, "original"), issue(2, "unknown-retry", segmentOrdinal=166)]
        result, = analyze(events)["firstObservedSegmentAttempts"]
        self.assertIsNone(result["segmentOrdinal"])
        request, = result["requests"]
        self.assertEqual(request["issuedActionSeconds"], 1)
        self.assertEqual(request["retryIdentity"], "unknown")

    def test_library_auth_attempts_survive_private_snapshot_to_startup_timeline(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            p.joinpath("action.json").write_text(json.dumps({"requestStart": APPLE_EPOCH_OFFSET + 100}))
            p.joinpath("observations.json").write_text(json.dumps([
                {"targetSeconds": 10, "responseEnd": APPLE_EPOCH_OFFSET + 110}]))
            details = [
                "stage=preparedLibraryRevalidationStarted, reason=freshSameOriginAfterCellularPathChange",
                "stage=preparedLibraryRevalidationAttempt, reason=pathChanged, attempt=1, maximumAttempts=2, willRetry=true",
                "stage=preparedLibraryRevalidationAttempt, reason=authenticatedCurrentPath, attempt=2, maximumAttempts=2, willRetry=false",
                "stage=preparedLibraryRevalidated, reason=sameServerAndAccountOnCurrentPath, mediaRenegotiated=false",
                "stage=preparedPublicationRejected, reason=certificateOverrideEnabled",
            ]
            entries = [{"id": str(i), "date": 101 + i,
                        "messageKey": "diagnostics.jellyfin.playback_route_state",
                        "detail": detail + ", target=https://private/?api_key=secret, userID=secret"}
                       for i, detail in enumerate(details)]
            p.joinpath("t10-private.plist").write_bytes(plistlib.dumps({
                "diagnostics.entries.v1": json.dumps(entries).encode()}))
            events, _ = load_window(p)
            rows = analyze(events)["startupTimeline"]["preparationEvents"]
            self.assertEqual(len(rows), 5)
            self.assertEqual([r["fields"]["reason"] for r in rows], [
                "freshSameOriginAfterCellularPathChange", "pathChanged", "authenticatedCurrentPath",
                "sameServerAndAccountOnCurrentPath", "certificateOverrideEnabled"])
            self.assertEqual(rows[1]["fields"]["maximumAttempts"], 2)
            self.assertEqual(rows[1]["fields"]["willRetry"], "true")
            self.assertEqual(rows[2]["fields"]["willRetry"], "false")
            self.assertNotIn("secret", json.dumps(rows))
        for reason in ["cancelled", "ownershipChanged", "unknownPath", "nonCellularPath",
                       "missingIdentity", "identityMismatch", "pathChanged"]:
            self.assertEqual(safe_fields({"reason": reason})["reason"], reason)
        private = safe_fields({"reason": "private?token=secret", "willRetry": "secret"})
        self.assertNotIn("secret", json.dumps(private))

    def test_response_body_evidence_preserves_compression_counts_and_unknowns_safely(self):
        fields = safe_fields({"responseBodyBytesReceivedIncludingProtocol": "1200",
            "responseBodyBytesAfterDecoding": "3000", "responseContentLength": "1200",
            "responseContentEncoding": "gzip,br", "responseStatusCode": "200"})
        self.assertEqual(fields, {"responseBodyBytesReceivedIncludingProtocol": 1200,
            "responseBodyBytesAfterDecoding": 3000, "responseContentLength": 1200,
            "responseContentEncoding": "gzip,br", "responseStatusCode": 200})
        for value in ["unknown", "NaN", "-1"]:
            fields = safe_fields({"responseContentLength": value,
                "responseBodyBytesReceivedIncludingProtocol": value,
                "responseBodyBytesAfterDecoding": value})
            self.assertEqual(fields, {})
        self.assertEqual(safe_fields({"responseBodyBytesAfterDecoding": "0"}),
                         {"responseBodyBytesAfterDecoding": 0})
        for encoding in ["identity", "gzip", "deflate", "br", "zstd", "other", "unspecified"]:
            self.assertEqual(safe_fields({"responseContentEncoding": encoding}),
                             {"responseContentEncoding": encoding})
        for encoding in ["gzip,private-token=secret", "https://private/?sid=secret", "gzip," * 100]:
            fields = safe_fields({"responseContentEncoding": encoding, "Content-Encoding": "secret"})
            self.assertEqual(fields, {"responseContentEncoding": "unrecognized"})

    def test_file_preparation_keeps_route_wait_and_cumulative_time_separate(self):
        fields = safe_fields({"phase": "localRange", "result": "unavailable",
                              "elapsedMs": "6187", "sinceRequestMs": "9800"})
        row = {"actionSeconds": 9.8, "event": "playback_preparation_phase", "fields": fields}
        timeline = analyze([row])["startupTimeline"]
        self.assertEqual(timeline["filePreparationEvents"], [row])
        self.assertEqual(fields["elapsedMs"], 6187)
        self.assertEqual(fields["sinceRequestMs"], 9800)
        self.assertEqual(timeline["preparationEvents"], [])

    def test_file_preparation_rejects_private_phase_and_unrelated_event(self):
        fields = safe_fields({"phase": "private/file.mkv?sid=secret", "result": "secret"})
        self.assertNotIn("secret", json.dumps(fields))
        rows = [{"actionSeconds": 1, "event": "playback_preparation_phase", "fields": fields},
                {"actionSeconds": 2, "event": "folder_response", "fields": {"phase": "remoteRange"}}]
        self.assertEqual(analyze(rows)["startupTimeline"]["filePreparationEvents"], [])

    def test_network_wait_and_body_times_remain_distinct_without_private_request_data(self):
        fields = safe_fields({"stage": "urlSessionTaskMetrics", "totalMs": "4112",
            "lastRequestEndToFirstByteMs": "3725", "lastResponseBodyMs": "386",
            "upstreamIssueToFirstBodyCallbackMs": "3727", "upstreamTaskBodyBytes": "1355480",
            "lastResponseEndToMetricsCallbackMs": "NaN", "requestURL": "https://private/?sid=secret"})
        self.assertEqual(fields["lastRequestEndToFirstByteMs"], 3725)
        self.assertEqual(fields["lastResponseBodyMs"], 386)
        self.assertEqual(fields["totalMs"], 4112)
        self.assertNotIn("lastResponseEndToMetricsCallbackMs", fields)
        self.assertNotIn("secret", json.dumps(fields))

    def test_preparation_stages_retain_fresh_proof_but_reject_private_details(self):
        fields = safe_fields({"stage": "preparedFallbackRevalidated",
            "reason": "sameServerAndAccountOnCurrentPath", "networkPathGeneration": "4",
            "startedPathGeneration": "2", "elapsedMs": "120", "mediaRenegotiated": "false",
            "selectedEndpoint": "https://private/?api_key=secret", "userID": "secret"})
        self.assertEqual(fields["stage"], "preparedFallbackRevalidated")
        self.assertEqual(fields["networkPathGeneration"], 4)
        self.assertEqual(fields["mediaRenegotiated"], "false")
        self.assertNotIn("secret", json.dumps(fields))
        unknown = safe_fields({"stage": "secret", "reason": "secret", "selection": "secret",
                               "networkPathGeneration": "NaN", "hasFreshPrimaryIdentity": "secret"})
        self.assertNotIn("secret", json.dumps(unknown))
        self.assertNotIn("networkPathGeneration", unknown)

    def test_touch_timeline_does_not_replace_total_wait_with_renderer_timer(self):
        prepared = {"actionSeconds": 6.2, "event": "playback_route_state",
                    "fields": {"stage": "playbackContextDiscarded", "reason": "ownershipChanged"}}
        frames = [{"actionSeconds": 22.7, "event": "first_frame",
                   "fields": {"playbackTraceID": "AAAAAAAA", "tapToFirstFrameMs": 6017}},
                  {"actionSeconds": 43.9, "event": "first_frame",
                   "fields": {"playbackTraceID": "BBBBBBBB", "tapToFirstFrameMs": 11270}}]
        timeline = analyze([prepared, *frames])["startupTimeline"]
        self.assertEqual(timeline["preparationEvents"], [prepared])
        self.assertEqual(timeline["engineFirstFrameMarkers"], frames)
        self.assertEqual(timeline["engineFirstFrameMarkers"][0]["actionSeconds"], 22.7)
        self.assertEqual(timeline["engineFirstFrameMarkers"][0]["fields"]["tapToFirstFrameMs"], 6017)

    def test_no_player_failure_stays_censored_without_reusing_previous_marker(self):
        previous = {"actionSeconds": -.5, "event": "first_frame", "fields": {}}
        rejected = {"actionSeconds": 8, "event": "playback_route_state",
                    "fields": {"stage": "preparedFallbackRevalidationRejected"}}
        timeline = analyze([previous, rejected])["startupTimeline"]
        self.assertEqual(timeline["engineFirstFrameMarkers"], [])
        self.assertEqual(timeline["preparationEvents"], [rejected])

    def test_preparation_timeline_does_not_admit_same_stage_from_other_events(self):
        unrelated = {"actionSeconds": 1, "event": "folder_response",
                     "fields": {"stage": "playRequested"}}
        self.assertEqual(analyze([unrelated])["startupTimeline"]["preparationEvents"], [])

    def test_client_read_eof_is_separate_from_reset_and_never_implies_client_finish(self):
        eof = safe_fields({"stage": "clientReadEnded", "clientReadComplete": "true",
            "clientReadAfterFinish": "false", "clientReadErrorKind": "none",
            "clientReadErrorCode": "unknown", "requestReceivedToReadEndMs": "4000",
            "clientReadObservation": "afterRequest", "clientReadBytes": "0"})
        self.assertEqual(eof["clientReadErrorKind"], "none")
        self.assertEqual(eof["clientReadAfterFinish"], "false")
        self.assertNotIn("clientReadErrorCode", eof)
        reset = safe_fields({"clientReadComplete": "false", "clientReadErrorKind": "posix",
            "clientReadErrorCode": "54", "clientReadObservation": "private URL",
            "clientReadErrorDescription": "secret"})
        self.assertEqual(reset["clientReadErrorCode"], 54)
        self.assertEqual(reset["clientReadObservation"], "unrecognized")
        self.assertNotIn("secret", json.dumps(reset))

    def test_cancel_callback_fields_keep_unknown_latency_and_reject_private_error_text(self):
        fields = safe_fields({"callbackAfterClientFinish": "true", "upstreamCancellationRequested": "true",
            "upstreamCancelToCallbackMs": "unknown", "taskIntervalMs": "100", "transactionCount": "0",
            "transportErrorKind": "posix", "transportErrorCode": "54", "errorDescription": "secret"})
        self.assertNotIn("upstreamCancelToCallbackMs", fields)
        self.assertEqual(fields["transactionCount"], 0)
        self.assertEqual(fields["transportErrorCode"], 54)
        self.assertNotIn("secret", json.dumps(fields))

    def test_late_task_cancel_callback_does_not_replace_client_failure_with_success(self):
        e = self.preparation_event
        identity = "12345678-1234-1234-1234-123456789ABC"
        p = candidate_preparation([e(1, "automatic_downshift_requested"), e(2, "replacement_warmup_started"),
            e(3, "proxy_transfer_started", trace="BBBBBBBB", transferID=identity,
                proxyKind="hlsChild", stage="upstreamRequestIssued"),
            e(4, "proxy_transfer_finished", trace="BBBBBBBB", transferID=identity,
                proxyKind="hlsChild", result="failed", transportErrorKind="posix", transportErrorCode=54),
            e(4.01, "proxy_transfer_finished", trace="BBBBBBBB", transferID=identity,
                proxyKind="hlsChild", stage="upstreamCancellationRequested"),
            e(4.1, "proxy_transfer_finished", trace="BBBBBBBB", transferID=identity,
                proxyKind="hlsChild", stage="upstreamTaskCompleted", callbackAfterClientFinish="true",
                errorCode=-999, upstreamCancelToCallbackMs=90),
            e(5, "replacement_warmup_failed")])[0]
        self.assertEqual(p["transfers"][0]["result"], "failed")
        self.assertEqual(p["transfers"][0]["terminalActionSeconds"], 4)
        self.assertEqual(len(p["transfers"][0]["evidence"]), 4)

    def test_transfer_identity_and_directory_origin_reject_private_strings(self):
        identity = "12345678-1234-1234-1234-123456789ABC"
        fields = safe_fields({"transferID": identity, "folderOperationID": "ABCDEF12",
                              "folderOrigin": "browserRoot", "sessionRole": "fileStation",
                              "diagnosticClientID": "credentials", "apiVersion": "2",
                              "target": "https://private/?sid=secret", "sessionID": "secret"})
        self.assertEqual(fields, {"transferID": identity, "folderOperationID": "ABCDEF12",
                                 "folderOrigin": "browserRoot", "sessionRole": "fileStation", "apiVersion": 2})
        self.assertNotIn("secret", json.dumps(safe_fields({"transferID": "secret", "folderOrigin": "secret"})))
        self.assertEqual(safe_fields({"finishSource": "clientBodySend"}), {"finishSource": "clientBodySend"})
        self.assertNotIn("secret", json.dumps(safe_fields({"finishSource": "https://private/?sid=secret"})))

    def test_authentication_generations_export_only_uuid_and_bounded_stage(self):
        identity = "12345678-1234-1234-1234-123456789ABC"
        for key in ["authenticationGeneration", "fileStationGeneration", "requestAuthenticationGeneration"]:
            self.assertEqual(safe_fields({key: identity}), {key: identity})
            for private in ["sid-secret", identity + "?sid=secret", "https://private/?sid=secret"]:
                self.assertEqual(safe_fields({key: private}), {})
        self.assertEqual(safe_fields({"authenticationStage": "sourcePrepared", "authenticationObservedMonoMs": "42"}),
                         {"authenticationStage": "sourcePrepared", "authenticationObservedMonoMs": 42})
        self.assertEqual(safe_fields({"authenticationStage": "sid-secret"}), {"authenticationStage": "unrecognized"})

    @staticmethod
    def preparation_event(time, name, trace="AAAAAAAA", **fields):
        return {"actionSeconds": time, "event": name, "fields": {"playbackTraceID": trace, **fields}}

    def test_candidate_phase_join_retains_original_and_overlapping_transfers(self):
        e = self.preparation_event
        identity = "12345678-1234-1234-1234-123456789ABC"
        events = [e(1, "automatic_downshift_requested"), e(2, "replacement_warmup_started"),
                  e(2.1, "proxy_transfer_started", trace="BBBBBBBB", transferID=identity,
                    proxyKind="hlsChild", hlsRole="segment", stage="upstreamRequestIssued"),
                  e(2.5, "proxy_transfer_started", trace="AAAAAAAA", transferID=identity,
                    proxyKind="mediaRange", status=206),
                  e(4, "proxy_transfer_started", trace="BBBBBBBB", transferID=identity,
                    proxyKind="hlsChild", status=200),
                  e(5, "replacement_candidate_decoded"), e(6, "replacement_committed"),
                  e(7, "proxy_transfer_finished", trace="BBBBBBBB", transferID=identity,
                    proxyKind="hlsChild", result="complete")]
        p = candidate_preparation(events)[0]
        self.assertEqual((p["requestToWarmupSeconds"], p["warmupToDecodedSeconds"], p["requestToCommitSeconds"]), (1, 3, 5))
        self.assertIsNone(p["decodedToAlignedSeconds"])
        self.assertEqual(p["candidateIdentity"], "unique")
        self.assertEqual(p["transfers"][0]["issuedToHeadersSeconds"], 1.9)
        self.assertEqual(p["transfers"][0]["terminalActionSeconds"], 7)
        self.assertEqual(len(p["transfers"][0]["evidence"]), 3)

    def test_missing_commit_and_failed_transfer_remain_censored(self):
        e = self.preparation_event
        identity = "12345678-1234-1234-1234-123456789ABC"
        p = candidate_preparation([e(1, "automatic_downshift_requested"),
            e(2, "replacement_warmup_started"), e(3, "proxy_transfer_started", trace="BBBBBBBB",
                proxyKind="hlsChild", transferID=identity, stage="upstreamRequestIssued"),
            e(4, "proxy_transfer_finished", trace="BBBBBBBB", proxyKind="hlsChild",
                transferID=identity, result="failed")])[0]
        self.assertEqual(p["terminal"], "unobserved")
        self.assertEqual(p["rightCensoredAtActionSeconds"], 4)
        self.assertIsNone(p["requestToCommitSeconds"])
        self.assertEqual(p["transfers"][0]["result"], "failed")
        self.assertIsNone(p["transfers"][0]["issuedToHeadersSeconds"])

    def test_ambiguous_candidate_traces_are_not_chosen_by_time(self):
        e = self.preparation_event
        p = candidate_preparation([e(1, "automatic_downshift_requested"),
            e(2, "replacement_warmup_started"),
            e(3, "proxy_transfer_started", trace="BBBBBBBB", proxyKind="hlsPlaylist"),
            e(4, "proxy_transfer_started", trace="CCCCCCCC", proxyKind="hlsChild"),
            e(5, "replacement_warmup_failed")])[0]
        self.assertEqual(p["candidateIdentity"], "ambiguous")
        self.assertEqual(p["candidateTraceIDs"], ["BBBBBBBB", "CCCCCCCC"])
        self.assertEqual(p["transfers"], [])
        self.assertEqual(p["terminal"], "replacement_warmup_failed")

    def test_prediction_and_folder_fields_are_bounded_and_keep_unknown_capacity(self):
        fields = safe_fields({"predictiveEligible": "false", "graceAllowsPrediction": "true",
                              "qualifiedBodyCapacity": "unknown", "deliveryCapacitySource": "bodyWindow",
                              "sourceBitrate": "NaN", "httpStatus": "502", "responseKind": "httpFailure",
                              "contentType": "html", "bodyBytes": "6", "sid": "secret",
                              "method": "list", "stage": "upstreamBodyProgress"})
        self.assertEqual(fields, {"predictiveEligible": "false", "graceAllowsPrediction": "true",
                                 "deliveryCapacitySource": "bodyWindow", "httpStatus": 502,
                                 "responseKind": "httpFailure", "contentType": "html", "bodyBytes": 6,
                                 "method": "list", "stage": "upstreamBodyProgress"})
        self.assertNotIn("secret", json.dumps(safe_fields({"method": "secret", "playing": "secret"})))

    def test_rejected_prediction_and_folder_failure_do_not_erase_stalls(self):
        decision = {"actionSeconds": .5, "event": "automatic_prediction_decision",
                    "fields": {"playbackTraceID": "AAAAAAAA", "predictiveEligible": "false"}}
        folder = {"actionSeconds": -.5, "event": "folder_response",
                  "fields": {"httpStatus": 502, "responseKind": "httpFailure"}}
        report = analyze([folder, event(0, stallActive="no", stallCount=0), decision,
                          event(1, stallActive="yes", stallCount=1)])
        trace = report["rendererTraces"][0]
        self.assertEqual(trace["predictionDecisions"], [decision])
        self.assertEqual(report["directoryResponses"], [folder])
        self.assertEqual(trace["maxReportedStallCount"], 1)
        self.assertIsNone(trace["stallEpisodes"][0]["endActionSeconds"])

    def test_configuration_boundaries_are_safe_and_do_not_change_stall_accounting(self):
        boundary = {"actionSeconds": 1, "event": "av_handoff_boundary", "fields": safe_fields({
            "playbackTraceID": "AAAAAAAA", "engine": "AVPlayer", "stage": "afterTextStyle",
            "avTimeControlState": "0", "videoOutputCount": "1", "automaticallyWaits": "yes",
            "preferredForwardBufferSeconds": "3", "URL": "https://private.example/?secret=value"})}
        report = analyze([boundary, event(2, currentSeconds=120, timeControlStatus="paused",
                                         stallCount=0, stallActive="no")])["rendererTraces"][0]
        self.assertEqual(report["handoffConfiguration"], [boundary])
        self.assertEqual(report["maxReportedStallCount"], 0)
        self.assertIsNone(report["firstObservedAdvancingClockActionSeconds"])
        self.assertNotIn("URL", boundary["fields"])

    def test_failure_without_renderer_samples_is_retained(self):
        failure = {"actionSeconds": 1, "event": "playback_failed", "fields": {
            "playbackTraceID": "AAAAAAAA", "errorCode": -12889}}
        report = analyze([failure])
        self.assertEqual(report["failureSignals"], [failure])
        self.assertEqual(report["tracesWithoutTelemetry"], ["AAAAAAAA"])
        self.assertEqual(report["rendererTraces"], [])

    def test_ks_state_events_supply_state_when_tick_omits_it(self):
        ready = {"actionSeconds": 0, "event": "engine_ready", "fields": {
            "playbackTraceID": "AAAAAAAA", "state": "bufferFinished"}}
        report = analyze([ready,
            event(.1, engine="KSPlayer", currentSeconds=.03, ksPlayerState="-", stallActive="no"),
            event(1.1, engine="KSPlayer", currentSeconds=1.03, ksPlayerState="-", stallActive="no"),
            event(3, engine="KSPlayer", currentSeconds=1.03, ksPlayerState="-", stallActive="yes", stallCount=1),
        ])["rendererTraces"][0]
        self.assertEqual(report["firstObservedAdvancingClockActionSeconds"], 1.1)
        self.assertEqual(report["stallEpisodes"][0]["phaseAtStart"], "afterObservedAdvancingClock")

    def test_paused_prepared_position_and_initial_wait_are_not_advancing_clock(self):
        report = analyze([
            event(0, currentSeconds=120, timeControlStatus="paused", stallActive="no", stallCount=0),
            event(.1, currentSeconds=120, timeControlStatus="waitingToPlayAtSpecifiedRate",
                  reasonForWaiting="evaluatingBufferingRate", bufferAheadSeconds=18,
                  stallActive="yes", stallCount=1),
            event(1, currentSeconds=120, timeControlStatus="playing", stallActive="no", stallCount=1),
            event(2, currentSeconds=121, timeControlStatus="playing", stallActive="no", stallCount=1),
        ])["rendererTraces"][0]
        self.assertEqual(report["firstObservedAdvancingClockActionSeconds"], 2)
        self.assertEqual(report["stallEpisodes"][0]["phaseAtStart"], "beforeObservedAdvancingClock")
        self.assertEqual(report["maxReportedStallCount"], 1)
        self.assertEqual(report["stallEpisodes"][0]["startFields"]["bufferAheadSeconds"], 18)

    def test_renderer_counter_reset_does_not_erase_original_stalls_or_censored_wait(self):
        report = analyze([
            event(0, engine="KSPlayer", stallActive="yes", stallCount=2),
            event(1, trace="BBBBBBBB", stallActive="no", stallCount=0),
            event(2, trace="BBBBBBBB", stallActive="yes", stallCount=1),
        ])["rendererTraces"]
        self.assertEqual([r["maxReportedStallCount"] for r in report], [2, 1])
        self.assertIsNone(report[0]["stallEpisodes"][0]["endActionSeconds"])
        self.assertIn("rightCensoredAtActionSeconds", report[1]["stallEpisodes"][0])

    def test_seek_jump_does_not_establish_playback_and_later_stall_is_retained(self):
        report = analyze([
            event(0, currentSeconds=0, timeControlStatus="paused", stallActive="no"),
            event(.1, currentSeconds=120, timeControlStatus="playing", stallActive="no"),
            event(1.1, currentSeconds=121, timeControlStatus="playing", stallActive="no"),
            event(3, currentSeconds=121, timeControlStatus="waitingToPlayAtSpecifiedRate",
                  stallActive="yes", stallCount=1),
        ])["rendererTraces"][0]
        self.assertEqual(report["firstObservedAdvancingClockActionSeconds"], 1.1)
        self.assertEqual(report["stallEpisodes"][0]["phaseAtStart"], "afterObservedAdvancingClock")

    def test_sensitive_or_nonfinite_values_are_not_exported(self):
        fields = safe_fields({"url": "https://private.invalid?api_key=secret",
                              "password": "secret", "currentSeconds": "NaN",
                              "reasonForWaiting": "secret", "engine": "AVPlayer",
                              "playbackTraceID": "secret", "stallCount": "2"})
        self.assertEqual(fields, {"reasonForWaiting": "unrecognized", "engine": "AVPlayer", "stallCount": 2})
        self.assertNotIn("secret", json.dumps(fields))

    def test_union_restores_early_events_but_excludes_later_resume_and_raw_preferences(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            p.joinpath("action.json").write_text(json.dumps({"requestStart": APPLE_EPOCH_OFFSET + 100}))
            p.joinpath("observations.json").write_text(json.dumps([
                {"targetSeconds": 30, "responseEnd": APPLE_EPOCH_OFFSET + 131}]))
            a = {"id": "one", "date": 101, "messageKey": "diagnostics.playback.next.telemetry_sample",
                 "detail": "playbackTraceID=AAAAAAAA, engine=KSPlayer, stallCount=1"}
            b = {"id": "two", "date": 130, "messageKey": "diagnostics.playback.next.telemetry_sample",
                 "detail": "playbackTraceID=BBBBBBBB, engine=AVPlayer, stallCount=0"}
            later = {"id": "resume", "date": 200, "messageKey": a["messageKey"], "detail": a["detail"]}
            for name, entries in [("t3", [a]), ("t30", [a, b]), ("closed", [b, later])]:
                p.joinpath(name + "-private.plist").write_bytes(plistlib.dumps({
                    "password": "secret", "diagnostics.entries.v1": json.dumps(entries).encode()}))
            events, window = load_window(p)
            self.assertEqual(len(events), 2)
            self.assertEqual(window["boundedEndActionSeconds"], 31)
            self.assertEqual([e["actionSeconds"] for e in events], [1, 30])
            self.assertNotIn("secret", json.dumps(events))
            p.joinpath("conflict-private.plist").write_bytes(plistlib.dumps({
                "diagnostics.entries.v1": json.dumps([{**a, "date": 102}]).encode()}))
            with self.assertRaises(ValueError):
                load_window(p)


if __name__ == "__main__":
    unittest.main()
