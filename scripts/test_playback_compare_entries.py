"""Reject misleading cohorts before calculating two-entry clock summaries."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from playback_compare_entries import compare


class EntryComparisonTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.base = Path(self.directory.name)
        self.manifest = {"schemaVersion": 1, "runs": []}
        self.report = {"associationPolicy": "trace-plan-strict-with-legacy-fallback",
                       "unassignedEvents": [], "playbackTraces": []}
        for pair in range(3):
            for entry, elapsed in [("dsmFile", 1000 + pair * 100), ("jellyfin", 1400 + pair * 100)]:
                identity = f"{pair}-{entry}"
                self.manifest["runs"].append({
                    "pairID": str(pair), "entry": entry, "report": "report.json",
                    "playbackTraceID": identity, "planID": identity,
                    "conditions": {"sampleID": "synthetic", "fileRevision": "fixture-v1",
                                   "audioTrack": "track-1", "subtitleTrack": "off",
                                   "startSeconds": 100, "device": "test-device",
                                   "network": "controlled-lan", "build": "normal-build-v1", "buildMode": "normal", "cache": "cold"}})
                self.report["playbackTraces"].append({
                    "playbackTraceID": identity, "planID": identity, "association": "identified",
                    "failureStages": [], "tapToFirstFrameMs": elapsed,
                    "firstFrameSignal": "playbackClock", "decodeEngine": "ksPlayer",
                    "playMethod": "directPlay", "routeKind": "localRangeProxy"})

    def evaluate(self):
        (self.base / "report.json").write_text(json.dumps(self.report), encoding="utf-8")
        return compare(self.manifest, self.base)

    def assert_blocked(self):
        result = self.evaluate()
        self.assertFalse(result["eligible"])
        self.assertIsNone(result["summary"])
        self.assertTrue(result["issues"])

    def test_three_verified_pairs_report_medians_and_paired_delta(self):
        result = self.evaluate()
        self.assertTrue(result["eligible"])
        self.assertEqual(result["completePairs"], 3)
        self.assertEqual(result["summary"]["dsmFile"]["medianMs"], 1100)
        self.assertEqual(result["summary"]["jellyfin"]["maxMs"], 1600)
        self.assertEqual(result["summary"]["medianPairedJellyfinMinusDeviceMs"], 400)
        self.assertIn("not_screen", result["metric"])

    def test_each_condition_mismatch_blocks_pooling(self):
        original = copy.deepcopy(self.manifest)
        for key, value in [("sampleID", "other"), ("fileRevision", "new-file"),
                           ("audioTrack", "track-2"), ("subtitleTrack", "PGS"),
                           ("startSeconds", 0), ("device", "ipad"), ("network", "WAN"),
                           ("build", "asan"), ("cache", "warm")]:
            with self.subTest(field=key):
                self.manifest = copy.deepcopy(original)
                self.manifest["runs"][-1]["conditions"][key] = value
                self.assert_blocked()

    def test_even_matching_diagnostic_builds_are_rejected(self):
        for run in self.manifest["runs"]:
            run["conditions"]["buildMode"] = "asan"
        self.assert_blocked()

    def test_unknown_conditions_are_not_equal_evidence(self):
        for run in self.manifest["runs"]:
            del run["conditions"]["fileRevision"]
        self.assert_blocked()

    def test_repeated_trace_cannot_inflate_sample_count(self):
        self.manifest["runs"][-1].update(playbackTraceID="0-jellyfin", planID="0-jellyfin")
        self.assert_blocked()

    def test_failures_and_missing_frames_are_not_silently_excluded(self):
        self.report["playbackTraces"][-1]["failureStages"] = ["decode"]
        result = self.evaluate()
        self.assertEqual(result["attempts"], 6)
        self.assertEqual(result["completePairs"], 2)
        self.assertFalse(result["eligible"])
        self.assertIsNone(result["summary"])
        self.report["playbackTraces"][-1]["failureStages"] = []
        self.report["playbackTraces"][-1]["tapToFirstFrameMs"] = None
        self.assert_blocked()

    def test_unassigned_log_events_block_comparison(self):
        self.report["unassignedEvents"] = [{"line": 7, "reason": "ambiguous"}]
        self.assert_blocked()

    def test_nonfinite_boolean_and_negative_metrics_block_json_summary(self):
        for value in [float("nan"), float("inf"), True, -1]:
            with self.subTest(value=value):
                self.report["playbackTraces"][-1]["tapToFirstFrameMs"] = value
                self.assert_blocked()

    def test_changed_engine_method_or_clock_signal_blocks_comparison(self):
        original = copy.deepcopy(self.report)
        for key, value in [("decodeEngine", "avPlayer"), ("playMethod", "transcode"),
                           ("firstFrameSignal", "rendererSubmission"), ("association", "legacy_unidentified")]:
            self.report = copy.deepcopy(original)
            self.report["playbackTraces"][-1][key] = value
            self.assert_blocked()

    def test_fewer_than_three_pairs_blocks_statistics(self):
        self.manifest["runs"] = self.manifest["runs"][:4]
        self.assert_blocked()

    def test_cli_exit_status_and_relative_paths(self):
        self.evaluate()
        manifest = self.base / "pairs.json"
        manifest.write_text(json.dumps(self.manifest), encoding="utf-8")
        script = Path(__file__).with_name("playback_compare_entries.py")
        command = [sys.executable, str(script.resolve()), str(manifest)]
        result = subprocess.run(command, capture_output=True, text=True, cwd="/")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["eligible"])
        self.manifest["runs"] = self.manifest["runs"][:1]
        manifest.write_text(json.dumps(self.manifest), encoding="utf-8")
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIsNone(json.loads(result.stdout)["summary"])


if __name__ == "__main__":
    unittest.main()
