"""Keep media position distinct from elapsed first-frame measurements."""

import unittest
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from playback_trace_report import Event, PlaybackTrace, trace_record, build_traces, render_trace


class FirstFrameMetricsTests(unittest.TestCase):
    def record(self, metrics):
        route = Event(1, None, "INFO", "media", "route", {
            "routeKind": "directHTTP", "decodeEngine": "avPlayer",
        })
        first = Event(2, None, "INFO", "media", "first_frame", metrics)
        return trace_record(PlaybackTrace(route, route, first_frame=first), 1)

    def test_legacy_position_does_not_imply_fast_renderer(self):
        result = self.record({"firstFrameMs": "0.222", "tapToFirstFrameMs": "5000"})
        self.assertEqual(result["firstFramePositionSeconds"], 0.222)
        self.assertIsNone(result["rendererFirstFrameMs"])
        self.assertNotEqual(result["bottleneck"], "pre_renderer_latency")

    def test_resume_position_is_seconds(self):
        result = self.record({"firstFramePositionSeconds": "147.508",
                              "firstFrameSignal": "playbackClock", "tapToFirstFrameMs": "5519"})
        self.assertEqual(result["firstFramePositionSeconds"], 147.508)
        self.assertEqual(result["tapToFirstFrameMs"], 5519)
        self.assertEqual(result["firstFrameSignal"], "playbackClock")
        self.assertIsNone(result["rendererFirstFrameMs"])

    def test_absent_measurement_stays_unknown(self):
        result = self.record({})
        self.assertIsNone(result["rendererFirstFrameMs"])
        self.assertIsNone(result["firstFramePositionSeconds"])


class TraceAssociationTests(unittest.TestCase):
    def event(self, line, kind, trace=None, plan=None, **details):
        if trace is not None:
            details["playbackTraceID"] = trace
        if plan is not None:
            details["planID"] = plan
        return Event(line, None, "INFO", "media", "diagnostics.playback.next." + kind, details)

    def test_engine_start_requires_its_own_full_identity_and_unambiguous_position(self):
        events = [
            self.event(1, "route_selected", "A", "A1"),
            self.event(2, "route_selected", "B", "B1"),
            self.event(3, "engine_startup_timing", "A", initialPositionSeconds="346.993"),
            self.event(4, "engine_startup_timing", "B", "B1", initialPositionSeconds="353.666"),
            self.event(5, "first_frame", "B", "B1", firstFramePositionSeconds="353.762"),
        ]
        a, b = build_traces(events)
        self.assertIsNone(trace_record(a, 1)["engineStartPositionSeconds"])
        self.assertEqual(trace_record(b, 2)["engineStartPositionSeconds"], 353.666)
        events.append(self.event(6, "engine_startup_timing", "B", "B1", initialPositionSeconds="358.072"))
        self.assertIsNone(trace_record(build_traces(events)[1], 2)["engineStartPositionSeconds"])

    def test_retired_renderer_keeps_partial_stages_without_counting_as_first_frame(self):
        events = [
            self.event(1, "route_selected", "A", "old"),
            self.event(2, "route_selected", "A", "new"),
            self.event(3, "engine_startup_incomplete", "A", "old",
                       initialPositionSeconds="14", initialSeekResult="0", initialSeekMs="3.5",
                       firstVideoPacketMs="42", acceptedVideoFrameMs="unknown", outputSubmittedMs="nan"),
            self.event(4, "engine_startup_timing", "A", "new", initialPositionSeconds="15"),
            self.event(5, "first_frame", "A", "new", tapToFirstFrameMs="730"),
            self.event(6, "engine_startup_incomplete", plan="new", initialSeekResult="pending"),
        ]
        unassigned = []
        old, new = build_traces(events, unassigned)
        failed = trace_record(old, 1)
        self.assertEqual(failed["incompleteEngineStartups"], [{
            "line": 3, "initialPositionSeconds": 14, "initialSeekResult": "0", "initialSeekMs": 3.5,
            "firstVideoPacketMs": 42, "acceptedVideoFrameMs": None, "outputSubmittedMs": None,
        }])
        self.assertIsNone(failed["engineStartPositionSeconds"])
        self.assertIsNone(failed["tapToFirstFrameMs"])
        self.assertEqual(failed["bottleneck"], "missing_first_frame")
        self.assertTrue(any("engine_startup_incomplete:" in line for line in render_trace(old, 1)))
        self.assertEqual(trace_record(new, 2)["engineStartPositionSeconds"], 15)
        self.assertFalse(trace_record(new, 2)["incompleteEngineStartups"])
        self.assertEqual([event["line"] for event in unassigned], [6])

    def test_identified_route_never_borrows_another_traces_preparation(self):
        events = [self.event(1, "prepare", "A", mode="serverNegotiatedHLS"),
                  self.event(2, "route_selected", "B", "B1")]
        trace = build_traces(events)[0]
        self.assertIsNone(trace.prepared)
        self.assertEqual(trace_record(trace, 1)["prepared"], "-")

    def test_interleaved_routes_keep_their_own_metadata_and_events(self):
        events = [self.event(1, "prepare", "A", mode="serverNegotiatedHLS"),
                  self.event(2, "prepare", "B", mode="serverNegotiatedDirectPlay"),
                  self.event(3, "route_selected", "A", "A1"),
                  self.event(4, "route_selected", "B", "B1"),
                  self.event(5, "first_frame", "A", "A1", tapToFirstFrameMs="1500"),
                  self.event(6, "playback_failed", "B", "B1")]
        first, second = build_traces(events)
        self.assertEqual(first.prepared.details["mode"], "serverNegotiatedHLS")
        self.assertEqual(second.prepared.details["mode"], "serverNegotiatedDirectPlay")
        self.assertEqual(first.first_frame.line, 5)
        self.assertEqual([e.line for e in second.failures], [6])
        self.assertFalse(first.failures)
        self.assertIsNone(second.first_frame)

    def test_unscoped_bandwidth_is_not_used_for_identified_session(self):
        measurement = Event(1, None, "INFO", "media", "Jellyfin 连接码率测量完成", {"measuredBitrate": "90000000"})
        trace = build_traces([measurement, self.event(2, "route_selected", "A", "P1")])[0]
        self.assertIsNone(trace_record(trace, 1)["measuredBitrate"])

    def test_plan_only_event_requires_a_unique_plan(self):
        events = [self.event(1, "route_selected", "A", "P1"),
                  self.event(2, "route_selected", "B", "P2"),
                  self.event(3, "telemetry_sample", plan="P1")]
        traces = build_traces(events)
        self.assertEqual([e.line for e in traces[0].telemetry], [3])
        self.assertFalse(traces[1].telemetry)

    def test_old_plan_events_do_not_pollute_replacement_plan(self):
        events = [self.event(1, "route_selected", "A", "P1"),
                  self.event(2, "route_selected", "A", "P2"),
                  self.event(3, "playback_failed", "A", "P1"),
                  self.event(4, "telemetry_sample", "A")]
        unassigned = []
        old, new = build_traces(events, unassigned)
        self.assertEqual([e.line for e in old.failures], [3])
        self.assertFalse(new.failures)
        self.assertFalse(old.telemetry + new.telemetry)
        self.assertEqual([e["line"] for e in unassigned], [4])

    def test_missing_or_conflicting_identity_is_reported_not_guessed(self):
        events = [self.event(1, "route_selected", "A", "P1"),
                  self.event(2, "telemetry_sample"),
                  self.event(3, "playback_failed", "B", "P1"),
                  self.event(4, "playback_ended", "A", "P2")]
        unassigned = []
        trace = build_traces(events, unassigned)[0]
        self.assertFalse(trace.telemetry + trace.failures + trace.ended)
        self.assertEqual([e["line"] for e in unassigned], [2, 3, 4])

    def test_reused_identifiers_are_ambiguous_in_concatenated_logs(self):
        events = [self.event(1, "route_selected", "A", "P1"),
                  self.event(2, "route_selected", "A", "P1"),
                  self.event(3, "first_frame", "A", "P1")]
        unassigned = []
        traces = build_traces(events, unassigned)
        self.assertTrue(all(t.first_frame is None for t in traces))
        self.assertEqual(len(unassigned), 1)

    def test_legacy_context_is_consumed_once_and_first_frame_is_preserved(self):
        events = [self.event(1, "prepare", mode="serverNegotiatedHLS"),
                  self.event(2, "route_selected"), self.event(3, "first_frame"),
                  self.event(4, "first_frame"), self.event(5, "route_selected")]
        old, new = build_traces(events)
        self.assertIsNotNone(old.prepared)
        self.assertEqual(old.first_frame.line, 3)
        self.assertIsNone(new.prepared)

    def test_cli_reports_unassigned_lines_without_borrowed_measurements(self):
        lines = [
            "[2026-09-14 10:00:00] INFO media - prepare | playbackTraceID=A, mode=serverNegotiatedHLS",
            "[2026-09-14 10:00:01] INFO media - diagnostics.playback.next.route_selected | playbackTraceID=B, planID=P2",
            "[2026-09-14 10:00:02] INFO media - diagnostics.playback.next.first_frame | playbackTraceID=A, planID=P1, tapToFirstFrameMs=1500",
        ]
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "synthetic.txt"
            log.write_text("\n".join(lines), encoding="utf-8")
            script = Path(__file__).with_name("playback_trace_report.py")
            output = subprocess.check_output([sys.executable, str(script), "--json", str(log)], text=True)
        result = json.loads(output)
        self.assertEqual(result["unassignedEvents"][0]["line"], 3)
        self.assertEqual(result["playbackTraces"][0]["prepared"], "-")
        self.assertIsNone(result["playbackTraces"][0]["tapToFirstFrameMs"])


if __name__ == "__main__":
    unittest.main()
