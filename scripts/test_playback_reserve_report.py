"""Evidence regressions: task identity, sparse demand, cancellation and privacy."""
import json
import plistlib
import tempfile
import unittest
from pathlib import Path

from playback_phase_report import APPLE_EPOCH_OFFSET, load_window
from playback_reserve_report import reserve_report, seek_capacity_phases


TRACE = "AAAAAAAA"


def row(t, name="proxy_transfer_finished", trace=TRACE, **fields):
    return {"actionSeconds": t, "event": name,
            "fields": {"playbackTraceID": trace, **fields}}


def telemetry(t, **fields):
    return row(t, "telemetry_sample", engine="AVPlayer", **fields)


def request(t, index=1, transfer="one", **fields):
    return row(t, proxyKind="mediaRange", transferID=transfer,
               upstreamTaskIndex=index, **fields)


def trace(events):
    return reserve_report([telemetry(0), *events])["rendererTraces"][0]


class ReserveReportTests(unittest.TestCase):
    def capacity(self, elapsed=1200, **fields):
        return row(9999, "seek_capacity_sample", planID="privatePlan", seekGeneration=2,
                   videoSeekEpoch=2, **{**{
                       "sampleUptimeSeconds": 100 + elapsed / 1000, "sinceRequestMs": elapsed,
                       "videoSeekSinceFlushMs": elapsed - 200, "videoSeekTargetSeconds": 500,
                       "videoSeekProbeTargetMatchesRequest": "true", "phase": "playable", "playable": "true",
                       "videoSeekFirstCallbackMs": 300, "videoSeekFirstAcceptedMs": 600,
                       "videoSeekQueueSnapshotAvailable": "true", "videoSeekQueueFrames": 16,
                       "videoMaximumFrames": 16, "videoLoadedSeconds": 1.04,
                       "videoSeekQueueUnionSeconds": .656}, **fields})

    def test_capacity_phases_use_monotonic_boundaries_not_event_wall_time(self):
        waiting = self.capacity(1000, phase="waiting", playable="false", videoLoadedSeconds=.875)
        ready = self.capacity(1200)
        ready["actionSeconds"] = -300  # Deliberately incompatible wall-clock order.
        result = seek_capacity_phases([waiting, ready, ready])["requests"][0]
        self.assertEqual(result["sampleCount"], 2)
        self.assertTrue(result["timingConsistent"])
        self.assertEqual(result["requestToObservedCodecFlushMs"], 200)
        self.assertEqual(result["codecFlushToFirstConvertedCallbackMs"], 300)
        self.assertEqual(result["firstConvertedCallbackToFirstAcceptedMs"], 300)
        self.assertEqual(result["requestToFirstAcceptedMs"], 800)
        self.assertEqual(result["firstAcceptedToObservedPlayableMs"], 400)
        self.assertEqual(result["sampledWaitingToPlayableWindowMs"], 200)
        self.assertEqual(result["fullDecodedQueueWhileWaitingSamples"], 1)
        self.assertEqual(result["readyCapacity"]["videoSeekQueueUnionSeconds"], .656)

    def test_same_target_separate_request_epoch_and_plan_do_not_merge(self):
        base = self.capacity()
        others = []
        for key, value in [("seekGeneration", 3), ("videoSeekEpoch", 4), ("planID", "other"), ("playbackTraceID", "other")]:
            others.append({**base, "fields": {**base["fields"], key: value}})
        result = seek_capacity_phases([base, *others])
        self.assertEqual(len(result["requests"]), 5)
        self.assertNotIn("privatePlan", json.dumps(result))

    def test_changed_request_or_flush_clock_suppresses_derived_durations(self):
        for key in ["sampleUptimeSeconds", "videoSeekSinceFlushMs", "videoSeekFirstAcceptedMs", "videoSeekTargetSeconds"]:
            second = self.capacity(1300)
            second["fields"][key] += 1
            result = seek_capacity_phases([self.capacity(), second])["requests"][0]
            self.assertFalse(result["timingConsistent"], key)
            self.assertIsNone(result["firstObservedPlayableSinceRequestMs"])
            self.assertTrue(result["boundaryErrors"])

    def test_invalid_or_missing_probe_boundaries_do_not_invent_durations(self):
        for changes in [{"sampleUptimeSeconds": "NaN"}, {"sinceRequestMs": -1},
                        {"videoSeekSinceFlushMs": 1300}, {"videoSeekFirstCallbackMs": -1},
                        {"videoSeekFirstAcceptedMs": 200}, {"videoSeekFirstAcceptedMs": float("inf")},
                        {"videoSeekProbeTargetMatchesRequest": "false"}, {"videoSeekTargetSeconds": -1},
                        {"sampleUptimeSeconds": True}]:
            result = seek_capacity_phases([self.capacity(**changes)])["requests"][0]
            self.assertFalse(result["timingConsistent"], changes)
            self.assertIsNone(result["requestToObservedCodecFlushMs"])
            self.assertIsNone(result["firstAcceptedToObservedPlayableMs"])

    def test_missing_identity_zero_counts_and_censored_wait_remain_distinct(self):
        base = self.capacity(1000, phase="waiting", playable="false", videoSeekQueueFrames=0,
                             videoSeekFirstCallbackMs=None, videoSeekFirstAcceptedMs=None)
        del base["fields"]["videoSeekFirstCallbackMs"]
        del base["fields"]["videoSeekFirstAcceptedMs"]
        missing = {**base, "fields": {k:v for k,v in base["fields"].items() if k != "videoSeekEpoch"}}
        result = seek_capacity_phases([base, missing])
        self.assertEqual(result["capacitySamplesMissingRequestOrEpochIdentity"], 1)
        r = result["requests"][0]
        self.assertTrue(r["timingConsistent"])
        self.assertTrue(r["rightCensoredAtCapacitySample"])
        self.assertEqual(r["lastWaitingCapacity"]["videoSeekQueueFrames"], 0)
        self.assertIsNone(r["codecFlushToFirstConvertedCallbackMs"])
        self.assertIsNone(r["firstObservedPlayableSinceRequestMs"])

    def test_raw_private_values_are_not_exported_in_capacity_summary(self):
        result = seek_capacity_phases([self.capacity(videoPackets="https://SECRET/?token=SECRET",
                                                     unknownPrivate="SECRET", videoSeekQueueUnionSeconds="unknown")])
        raw = json.dumps(result, allow_nan=False)
        self.assertNotIn("SECRET", raw)
        self.assertNotIn("privatePlan", raw)
        self.assertNotIn("videoSeekQueueUnionSeconds", result["requests"][0]["readyCapacity"])

    def test_same_transfer_separate_tasks_and_callback_gaps(self):
        events = [request(1, stage="upstreamRequestIssued"),
                  request(5, stage="urlSessionTaskMetrics", lastResponseBodyMs=4000,
                          responseBodyBytesAfterDecoding=32_000_000),
                  request(5.01, stage="upstreamTaskCompleted"),
                  request(5.02, index=2, stage="upstreamRequestIssued"),
                  request(7, index=2, stage="urlSessionTaskMetrics", lastResponseBodyMs=2000,
                          responseBodyBytesAfterDecoding=32_000_000),
                  request(7.01, index=2, stage="upstreamTaskCompleted")]
        a, b = trace(events)["rangeRequests"]
        self.assertEqual(a["observedBodyBps"], 64_000_000)
        self.assertEqual(b["observedBodyBps"], 128_000_000)
        self.assertEqual(a["nextIssueAfterCompletionMs"], 10)
        self.assertIsNone(b["nextIssueAfterCompletionMs"])

    def test_duplicates_ambiguity_missing_and_real_zero_stay_distinct(self):
        m = request(1, stage="urlSessionTaskMetrics", lastResponseBodyMs=1000,
                    responseBodyBytesAfterDecoding=0)
        a = trace([m, m])["rangeRequests"][0]
        self.assertEqual(a["metricsIdentity"], "unique")
        self.assertEqual(a["observedBodyBps"], 0)
        b = trace([m, request(2, stage="urlSessionTaskMetrics", lastResponseBodyMs=1000,
                              responseBodyBytesAfterDecoding=50)])["rangeRequests"][0]
        self.assertEqual(b["metricsIdentity"], "ambiguous")
        self.assertIsNone(b["observedBodyBps"])
        c = trace([request(1, stage="upstreamRequestIssued")])["rangeRequests"][0]
        self.assertEqual(c["metricsIdentity"], "missing")
        self.assertIsNone(c["observedBodyBps"])
        self.assertTrue(c["rightCensored"])

    def test_cancellation_not_hidden_or_joined_to_a_new_transfer(self):
        r = trace([request(1, stage="upstreamCancellationRequested"),
                   request(1.001, stage="upstreamTaskCompleted", errorCode=-999),
                   request(1.01, index=2, transfer="different", stage="upstreamRequestIssued"),
                   row(2, proxyKind="mediaRange", stage="urlSessionTaskMetrics")])
        a = r["rangeRequests"][0]
        self.assertEqual(a["completionErrorCode"], -999)
        self.assertEqual(a["cancellationRequestedActionSeconds"], 1)
        self.assertIsNone(a["nextIssueAfterCompletionMs"])
        self.assertEqual(r["rangeEventsMissingIdentity"], 1)

    def test_body_window_uses_in_window_same_trace_runtime_demand(self):
        events = [row(0, "automatic_prediction_decision", runtimeDemand=999),
                  row(2, "automatic_prediction_decision", runtimeDemand=75_000_000),
                  row(2.5, "automatic_prediction_decision", trace="BBBBBBBB", runtimeDemand=1),
                  row(3, stage="upstreamBodyProgress", elapsedMs=2000,
                      effectiveBps=30_000_000, bodyWindowIncludesRangeBoundaries="true"),
                  row(6, stage="upstreamBodyProgress", elapsedMs=2000, effectiveBps=60_000_000)]
        a, b = trace(events)["receivedBodyWindows"]
        self.assertEqual(a["observedRuntimeDemandMinBps"], 75_000_000)
        self.assertEqual(a["observedRuntimeDemandMaxBps"], 75_000_000)
        self.assertEqual(a["runtimeDemandSampleCount"], 1)
        self.assertIsNone(b["observedRuntimeDemandMinBps"])

    def test_post_start_open_stall_remains_censored(self):
        events = [telemetry(1, currentSeconds=20, timeControlStatus="playing", stallActive="no"),
                  telemetry(2, currentSeconds=21, timeControlStatus="playing", stallActive="no"),
                  telemetry(3, currentSeconds=21, timeControlStatus="waitingToPlayAtSpecifiedRate", stallActive="yes")]
        episode = trace(events)["stallEpisodes"][0]
        self.assertEqual(episode["phaseAtStart"], "afterObservedAdvancingClock")
        self.assertIsNone(episode["reportedDurationMs"])
        self.assertIsNone(episode["endActionSeconds"])
        self.assertEqual(episode["rightCensoredAtActionSeconds"], 3)

    def test_private_snapshot_allowlist_preserves_boundary_but_drops_resource(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            p.joinpath("action.json").write_text(json.dumps({"requestStart": APPLE_EPOCH_OFFSET + 100}))
            p.joinpath("observations.json").write_text(json.dumps([
                {"targetSeconds": 5, "responseEnd": APPLE_EPOCH_OFFSET + 105}]))
            entries = [{"id": "one", "date": 101, "messageKey": "diagnostics.playback.next.telemetry_sample",
                        "detail": "playbackTraceID=AAAAAAAA, engine=KSPlayer"},
                       {"id": "two", "date": 103, "messageKey": "diagnostics.media.proxy_transfer_finished",
                        "detail": "playbackTraceID=AAAAAAAA, stage=upstreamBodyProgress, elapsedMs=2000, measurementBoundary=receivedBodyWindow, bodyWindowIncludesRangeBoundaries=true, target=https://private/?token=secret"}]
            p.joinpath("t3-private.plist").write_bytes(plistlib.dumps({
                "diagnostics.entries.v1": json.dumps(entries).encode(), "privatePassword": "secret"}))
            events, _ = load_window(p)
            report = reserve_report(events)
            fields = report["rendererTraces"][0]["receivedBodyWindows"][0]["bodyFields"]
            self.assertEqual(fields["bodyWindowIncludesRangeBoundaries"], "true")
            self.assertEqual(fields["measurementBoundary"], "receivedBodyWindow")
            self.assertNotIn("secret", json.dumps(report))
            self.assertNotIn("privatePassword", json.dumps(report))


if __name__ == "__main__":
    unittest.main()
