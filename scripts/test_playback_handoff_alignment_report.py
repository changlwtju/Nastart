"""Boundaries, identity separation, unknown states, and private-data rejection."""
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from playback_handoff_alignment_report import analyze, obstructions, safe_snapshot
from playback_phase_report import APPLE_EPOCH_OFFSET

START = APPLE_EPOCH_OFFSET + 100


def event(t, name, trace="AAAAAAAA", **detail):
    return {"id": f"{trace}-{name}-{t}", "date": 100 + t,
            "messageKey": "diagnostics.playback.next." + name,
            "detail": {"playbackTraceID": trace, **detail}}


class AlignmentTests(unittest.TestCase):
    def test_manifest_preparation_is_not_decoded_or_a_completed_candidate(self):
        raw = [event(0, "replacement_warmup_started"),
               event(.1, "replacement_candidate_manifest_preparing"),
               event(2, "replacement_candidate_manifest_prepared", cachedVOD="true", elapsedMs="1900"),
               event(3, "replacement_candidate_decoded"),
               event(4, "replacement_committed")]
        r = analyze(raw, START, START + 5)["attempts"][0]
        self.assertEqual(r["manifestPreparationSeconds"], 1.9)
        self.assertTrue(r["manifestSnapshots"][-1]["snapshot"]["cachedVOD"])
        failed = analyze(raw[:2] + [event(2, "replacement_warmup_failed", stage="manifestPreparation")],
                         START, START + 5)["attempts"][0]
        self.assertEqual(failed["decodeCount"], 0)
        self.assertIsNone(failed["manifestPreparationSeconds"])
        self.assertEqual(failed["manifestSnapshots"][-1]["snapshot"]["stage"], "manifestPreparation")

    def test_realistic_delayed_candidate_preserves_negative_constraints_and_phase_durations(self):
        raw = [event(1, "replacement_warmup_started"),
               event(13, "replacement_candidate_decoded", candidateSeconds=235.9,
                     liveSeconds=241.5, framePTS=235.86, candidateBufferAheadSeconds=.25),
               event(19, "replacement_candidate_buffered_seek_started"),
               event(20.9, "replacement_candidate_aligned"),
               event(21, "replacement_committed")]
        d = analyze(raw, START, START + 30)["attempts"][0]
        self.assertEqual(d["decodedToCommitSeconds"], 8)
        self.assertEqual(d["decodedToAlignedSeconds"], 7.9)
        self.assertEqual(d["alignedToCommitSeconds"], .1)
        self.assertEqual(d["bufferedSeekStarts"], 1)
        s = d["postDecodeSnapshots"][0]
        self.assertEqual(s["candidateMinusLiveSeconds"], -5.6)
        self.assertEqual(s["observedObstructions"],
                         ["clockDistanceOver0.1s", "maximumReportedForwardReserveUnder0.5s"])
        self.assertFalse(d["fullReadinessOrContinuousBlockedTimeAccepted"])

    def test_thresholds_and_missing_obstructions_never_create_a_pass(self):
        self.assertEqual(obstructions({"candidateSeconds": 0, "liveSeconds": .1,
                                      "framePTS": .15, "candidateBufferAheadSeconds": .5}), [])
        d = analyze([event(0, "replacement_warmup_started"),
                     event(1, "replacement_candidate_decoded")], START, START + 2)
        self.assertFalse(d["screenFirstFrameOrActualSoundAccepted"])
        self.assertEqual(d["attempts"][0]["terminal"], "unobserved")

    def test_disjoint_range_is_not_treated_as_usable_forward_buffer(self):
        s = {"candidateSeconds": 10, "liveSeconds": 10, "framePTS": 10,
             "candidateBufferAheadSeconds": 20, "loadedRangeCount": 1,
             "loadedRangeFirstStart": 20, "loadedRangeFirstEnd": 30}
        self.assertEqual(obstructions(s), ["singleReportedRangeDoesNotCoverCommitReserve"])
        s["loadedRangeCount"] = 2
        self.assertEqual(obstructions(s), [])  # Other ranges unknown; never declare readiness.

    def test_clock_and_frame_staleness_and_empty_buffer_are_independent(self):
        self.assertEqual(obstructions({"candidateSeconds": 10, "liveSeconds": 10.5,
                                      "framePTS": 9, "bufferEmpty": True}),
                         ["clockDistanceOver0.1s", "frameDistanceOver0.15s", "bufferEmpty"])

    def test_nonfinite_unknown_and_invalid_clocks_are_not_zero_filled(self):
        s = safe_snapshot({"candidateSeconds": "nan", "liveSeconds": "private",
                           "framePTS": "inf", "candidateRate": True,
                           "candidateBufferAheadSeconds": "unknown"})
        self.assertEqual(s, {})
        self.assertEqual(obstructions({"candidateSeconds": -1, "liveSeconds": 7}), [])

    def test_different_source_traces_do_not_share_decoded_or_commit_events(self):
        raw = [event(0, "replacement_warmup_started"),
               event(1, "replacement_candidate_decoded"),
               event(1.1, "replacement_warmup_started", "BBBBBBBB"),
               event(3, "replacement_committed", "BBBBBBBB")]
        a, b = analyze(raw, START, START + 4)["attempts"]
        self.assertIsNone(a["decodedToCommitSeconds"])
        self.assertEqual(a["terminal"], "unobserved")
        self.assertEqual(b["decodeCount"], 0)

    def test_repeated_warmup_censors_first_instead_of_joining_later_commit(self):
        raw = [event(0, "replacement_warmup_started"), event(1, "replacement_candidate_decoded"),
               event(2, "replacement_warmup_started"), event(3, "replacement_candidate_decoded"),
               event(4, "replacement_committed")]
        a, b = analyze(raw, START, START + 5)["attempts"]
        self.assertEqual(a["terminal"], "unobserved")
        self.assertIsNone(a["decodedToCommitSeconds"])
        self.assertEqual(a["rightCensoredAtActionSeconds"], 2)
        self.assertEqual(b["decodedToCommitSeconds"], 1)

    def test_failure_stops_attempt_and_does_not_consume_later_commit(self):
        raw = [event(0, "replacement_warmup_started"), event(1, "replacement_candidate_decoded"),
               event(2, "replacement_warmup_failed"), event(3, "replacement_committed")]
        result = analyze(raw, START, START + 4)
        d = result["attempts"][0]
        self.assertEqual(d["terminal"], "replacement_warmup_failed")
        self.assertIsNone(d["decodedToCommitSeconds"])
        self.assertEqual(result["unassignedOwnedReplacementEventCount"], 1)

    def test_missing_warmup_does_not_hide_unassigned_owned_events(self):
        d = analyze([event(1, "replacement_candidate_decoded")], START, START + 2)
        self.assertEqual(d["attempts"], [])
        self.assertEqual(d["unassignedOwnedReplacementEventCount"], 1)

    def test_incomplete_phases_keep_null_and_right_censor(self):
        d = analyze([event(0, "replacement_warmup_started"),
                     event(1, "replacement_candidate_decoded")], START, START + 40)["attempts"][0]
        self.assertIsNone(d["decodedToAlignedSeconds"])
        self.assertEqual(d["rightCensoredAtActionSeconds"], 40)

    def test_multiple_decoded_markers_do_not_select_a_convenient_one(self):
        raw = [event(0, "replacement_warmup_started"), event(1, "replacement_candidate_decoded"),
               event(2, "replacement_candidate_decoded"), event(3, "replacement_committed")]
        d = analyze(raw, START, START + 4)["attempts"][0]
        self.assertEqual(d["decodeCount"], 2)
        self.assertIsNone(d["decodedToCommitSeconds"])
        self.assertEqual(d["postDecodeSnapshots"], [])

    def test_half_open_window_excludes_previous_and_next_actions(self):
        raw = [event(-1, "replacement_warmup_started"), event(0, "replacement_warmup_started"),
               event(1, "replacement_candidate_decoded"), event(2, "replacement_committed")]
        d = analyze(raw, START, START + 2)
        self.assertEqual(d["boundedReplacementEventCount"], 2)
        self.assertEqual(d["attempts"][0]["terminal"], "unobserved")

    def test_duplicate_snapshots_are_unioned_and_conflicts_fail_closed(self):
        e = event(0, "replacement_warmup_started")
        self.assertEqual(analyze([e, e], START, START + 2)["boundedReplacementEventCount"], 1)
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            analyze([e, {**e, "date": 101}], START, START + 2)
        with self.assertRaisesRegex(ValueError, "deduplication"):
            analyze([{**e, "id": None}], START, START + 2)

    def test_private_text_and_malformed_source_identity_are_never_exported(self):
        secret = "https://private/?token=secret"
        raw = [event(0, "replacement_warmup_started", secret),
               event(1, "replacement_warmup_started"),
               event(2, "replacement_candidate_decoded", url=secret, framePTS=secret,
                     stage=secret, errorDescription=secret, candidateSeconds=3)]
        result = analyze(raw, START, START + 4)
        text = json.dumps(result)
        self.assertNotIn(secret, text)
        self.assertNotIn("AAAAAAAA", text)
        self.assertEqual(result["unownedReplacementEvents"], 1)
        self.assertEqual(result["attempts"][0]["postDecodeSnapshots"][0]["snapshot"],
                         {"candidateSeconds": 3})

    def test_invalid_window_and_input_are_rejected(self):
        for start, end in [(START, START), (START, math.inf), (True, START)]:
            with self.assertRaisesRegex(ValueError, "window"):
                analyze([], start, end)
        with self.assertRaisesRegex(ValueError, "array"):
            analyze({}, START, START + 1)

    def test_cli_writes_only_safe_report_for_private_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory)
            raw = [event(0, "replacement_warmup_started"),
                   event(1, "replacement_candidate_decoded", candidateSeconds=2,
                         liveSeconds=4, url="https://private/?token=secret")]
            (p / "events.json").write_text(json.dumps(raw))
            (p / "action.json").write_text(json.dumps({"requestStart": START, "targetName": "secret"}))
            result = subprocess.run([sys.executable,
                str(Path(__file__).with_name("playback_handoff_alignment_report.py")),
                str(p / "events.json"), "--action", str(p / "action.json"),
                "--end-unix", str(START + 3), "--output", str(p / "safe.json")],
                capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "")
            text = (p / "safe.json").read_text()
            self.assertNotIn("secret", text)
            self.assertEqual(json.loads(text)["attempts"][0]["rightCensoredAtActionSeconds"], 3)


if __name__ == "__main__":
    unittest.main()
