import json
import unittest

from playback_seek_phase_report import APPLE_EPOCH, report


class SeekPhasesTests(unittest.TestCase):
    def test_paused_preview_and_later_clock_recovery_are_distinct(self):
        fields = {"playbackTraceID": "own", "planID": "plan", "seekTargetSeconds": "100"}
        result = report([self.e(10, "seek_started", **fields),
                         self.e(10.5, "seek_engine_completed", **fields),
                         self.e(10.8, "seek_preview_ready", **fields, evidence="rendererOutputNotPresentation"),
                         self.e(24, "seek_recovered", **fields, seekRecoveryMs="14001")], 0, 30)
        operation = result["operations"][0]
        self.assertEqual(operation["pausedPreviewOutputMs"], 800)
        self.assertEqual(operation["recoveredMs"], 14000)
        self.assertEqual(operation["internalClockRecoveryMs"], 14001)
        self.assertTrue(operation["pausedSeekIntentObserved"])
        self.assertEqual(operation["clockRecoveryLatencyScope"], "includesPausedSeekIntent")
        self.assertFalse(result["visibleFrameAccepted"])

    def test_missing_or_other_plan_preview_does_not_prove_playing_or_paused(self):
        fields = {"playbackTraceID": "own", "planID": "plan", "seekTargetSeconds": "100"}
        result = report([self.e(10, "seek_started", **fields),
                         self.e(11, "seek_preview_ready", **{**fields, "planID": "other"}, evidence="rendererOutputNotPresentation"),
                         self.e(12, "seek_recovered", **{**fields, "planID": "other"})], 0, 30)["operations"][0]
        self.assertIsNone(result["pausedPreviewOutputMs"])
        self.assertIsNone(result["pausedSeekIntentObserved"])
        self.assertTrue(result["recoveryCensored"])

    def test_superseded_same_target_paused_seek_keeps_preview_but_no_old_clock_recovery(self):
        fields = {"playbackTraceID": "own", "planID": "plan", "seekTargetSeconds": "100"}
        rows = report([self.e(10, "seek_started", **fields),
                       self.e(11, "seek_preview_ready", **fields, evidence="rendererOutputNotPresentation"),
                       self.e(20, "seek_started", **fields),
                       self.e(21, "seek_preview_ready", **fields, evidence="rendererOutputNotPresentation"),
                       self.e(33, "seek_recovered", **fields, seekRecoveryMs="13000")], 0, 40)["operations"]
        self.assertTrue(rows[0]["recoveryCensored"])
        self.assertEqual(rows[0]["censorReason"], "supersededByNextSeek")
        self.assertEqual(rows[0]["pausedPreviewOutputMs"], 1000)
        self.assertEqual(rows[1]["recoveredMs"], 13000)
        self.assertTrue(rows[1]["pausedSeekIntentObserved"])

    def test_unidentified_or_unproven_preview_marker_stays_unknown(self):
        for extra in [{}, {"playbackTraceID": "own", "planID": "plan", "evidence": "notProven"}]:
            row = self.e(10, "seek_started", seekTargetSeconds="100", **{k:v for k,v in extra.items() if k != "evidence"})
            preview = self.e(11, "seek_preview_ready", seekTargetSeconds="100", **extra)
            result = report([row, preview], 0, 30)["operations"][0]
            self.assertIsNone(result["pausedSeekIntentObserved"])

    def e(self, t, key="proxy_transfer_started", **fields):
        return {"date": t - APPLE_EPOCH, "messageKey": "d." + key, "detail": fields}

    def segment(self, t, stage=None, **fields):
        return self.e(t, **{"hlsRole": "segment", "transferID": "SECRET", "upstreamTaskIndex": "1",
                            "stage": stage, **fields})

    def result(self, events, end=40):
        return report([self.e(10, "seek_started", engine="AVPlayer", seekTargetSeconds="100"), *events], 0, end)

    def test_header_wait_body_and_recovery_remain_separate(self):
        result = self.result([
            self.segment(10.01, "upstreamRequestIssued", segmentOrdinal="25"),
            self.segment(18, status="200"),
            self.segment(20, "urlSessionTaskMetrics", lastRequestEndToFirstByteMs="7900", lastResponseBodyMs="1900", upstreamTaskBodyBytes="5000000"),
            self.e(27, "seek_engine_completed", targetSeconds="100"),
            self.e(30, "seek_recovered", seekTargetSeconds="100")])
        r = result["operations"][0]
        self.assertEqual((r["completionMs"], r["recoveredMs"], r["completionToRecoveryMs"]), (17000, 20000, 3000))
        self.assertEqual(r["segments"][0]["lastRequestEndToFirstByteMs"], 7900)
        self.assertTrue(result["durationsMustNotBeSummed"])

    def test_half_close_does_not_become_cancellation(self):
        r = self.result([self.segment(9, "upstreamRequestIssued"), self.segment(14, "clientReadEnded", clientReadComplete="true", clientReadErrorKind="none")])["operations"][0]["segments"][0]
        self.assertTrue(r["cleanWriteSideEOFObserved"])
        self.assertTrue(r["requestStartedBeforeSeek"])
        self.assertNotIn("cancelRequestedSecondsFromSeek", r)

    def test_partial_read_is_not_write_eof(self):
        r = self.result([self.segment(11, "clientReadEnded", clientReadComplete="false", clientReadErrorKind="none")])["operations"][0]["segments"][0]
        self.assertNotIn("cleanWriteSideEOFObserved", r)

    def test_old_cancelled_request_not_first_new_target_request(self):
        rows = self.result([self.segment(8, "upstreamRequestIssued", segmentOrdinal="3"),
                            self.segment(10.02, "upstreamCancellationRequested"),
                            self.segment(10.1, "upstreamRequestIssued", transferID="OTHER", segmentOrdinal="25")])["operations"][0]
        self.assertEqual(rows["firstNewSegmentRequestMs"], 100)
        self.assertEqual(len(rows["segments"]), 2)

    def test_duplicate_metrics_do_not_add_bytes(self):
        e = self.segment(20, "urlSessionTaskMetrics", upstreamTaskBodyBytes="100")
        r = self.result([self.segment(11, "upstreamRequestIssued"), e, e])["operations"][0]
        self.assertEqual(r["segments"][0]["bodyBytesObserved"], 100)

    def test_superseded_seek_and_stale_target_stay_censored(self):
        rows = self.result([self.e(12, "seek_started", engine="AVPlayer", seekTargetSeconds="200"),
                            self.e(15, "seek_recovered", seekTargetSeconds="100")])["operations"]
        self.assertEqual(rows[0]["censorReason"], "supersededByNextSeek")
        self.assertTrue(rows[1]["recoveryCensored"])

    def test_http_error_zero_bytes_and_missing_are_distinct(self):
        r = self.result([self.segment(11, "upstreamRequestIssued"), self.segment(14, status="504"),
                         self.segment(15, "upstreamTaskCompleted", errorCode="-1001", upstreamTaskBodyBytes="0")])["operations"][0]["segments"][0]
        self.assertEqual((r["responseStatus"], r["bodyBytesObserved"], r["completionErrorCode"]), (504, 0, -1001))
        self.assertNotIn("issueToFirstBodyCallbackMs", r)

    def test_missing_identity_is_not_merged(self):
        r = self.result([self.e(11, hlsRole="segment", stage="upstreamRequestIssued")])["operations"][0]
        self.assertEqual(r["unidentifiedSegmentEventCount"], 1)
        self.assertEqual(r["segments"], [])

    def test_unknown_and_private_fields_never_export(self):
        result = self.result([self.segment(11, "upstreamRequestIssued", segmentOrdinal="nan", target="https://SECRET/path?token=SECRET"),
                              self.segment(12, "urlSessionTaskMetrics", totalMs="inf", upstreamTaskBodyBytes="-1")])
        raw = json.dumps(result, allow_nan=False)
        self.assertNotIn("SECRET", raw)
        self.assertNotIn("totalMs", raw)
        self.assertIsNone(result["operations"][0]["segments"][0]["segmentOrdinal"])

    def test_invalid_bounds_rejected(self):
        for start, end in [(1, 1), (2, 1), (float("nan"), 3), (1, float("inf"))]:
            with self.assertRaises(ValueError):
                report([], start, end)

    def test_another_playback_trace_cannot_complete_same_target(self):
        rows = report([self.e(10, "seek_started", playbackTraceID="own", seekTargetSeconds="100"),
                       self.e(12, "seek_recovered", playbackTraceID="other", seekTargetSeconds="100"),
                       self.segment(11, "upstreamRequestIssued", playbackTraceID="other")], 0, 30)["operations"]
        self.assertTrue(rows[0]["recoveryCensored"])
        self.assertEqual(rows[0]["segments"], [])

    def test_another_trace_seek_does_not_truncate_this_seek(self):
        rows = report([self.e(10, "seek_started", playbackTraceID="own", seekTargetSeconds="100"),
                       self.e(12, "seek_started", playbackTraceID="other", seekTargetSeconds="200"),
                       self.e(15, "seek_recovered", playbackTraceID="own", seekTargetSeconds="100")], 0, 30)["operations"]
        self.assertEqual(rows[0]["recoveredMs"], 5000)
        self.assertEqual(rows[0]["observationSeconds"], 20)

    def test_missing_target_cannot_prove_recovery(self):
        rows = self.result([self.e(15, "seek_recovered")])["operations"]
        self.assertTrue(rows[0]["recoveryCensored"])


if __name__ == "__main__":
    unittest.main()
