"""Keep media position distinct from elapsed first-frame measurements."""

import unittest

from playback_trace_report import Event, PlaybackTrace, trace_record


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


if __name__ == "__main__":
    unittest.main()
