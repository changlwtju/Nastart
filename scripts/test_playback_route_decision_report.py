"""The offline check must reach the app's verdict from the logged numbers alone."""
import tempfile
import unittest
from pathlib import Path

from playback_route_decision_report import (expected_rendition, expected_verdict, render,
                                            route_decisions)
from playback_trace_report import parse_log

S19 = 75_218_094


def line(**details):
    fields = ", ".join(f"{key}={value}" for key, value in sorted(details.items()))
    return f"[2026-11-10 20:21:00] INFO 媒体 - 开始请求 Jellyfin 播放方案 | {fields}"


def evidence(trace, verdict, capacity="none", two_sided="false", floor="none", source=S19, **extra):
    return line(stage="routeCapacityEvidence", playbackTraceID=trace, network="cellular",
                capacity=capacity, capacityBoundsBothSides=two_sided, renditionLowerBound=floor,
                sourceBitrate=source, originalVerdict=verdict, capacitySource="x",
                probeCapacity="none", probeAgeSeconds="none", restoredSamples=0, **extra)


def request(trace, ceiling="12000000", reason="initialPlayback"):
    return line(playbackTraceID=trace, defaultMode="adaptiveAuto", maximumBitrate=0,
                renditionCeiling=ceiling, requestReason=reason)


def skip(trace, reason, mode="originalRangeSkipped"):
    return line(playbackTraceID=trace, mode=mode, reason=reason)


def prepared(trace, mode="serverNegotiatedHLS", bitrate="10000000"):
    return line(playbackTraceID=trace, mode=mode, maxBitrate=bitrate)


def rows(*lines):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "export.txt"
        path.write_text("\n".join(lines), encoding="utf-8")
        return route_decisions(parse_log(path))


class RouteDecisionReportTests(unittest.TestCase):
    def test_verdict_table_matches_the_policy(self):
        def verdict(source, capacity, two_sided="false", floor="none"):
            return expected_verdict({"sourceBitrate": str(source), "capacity": str(capacity),
                                     "capacityBoundsBothSides": two_sided,
                                     "renditionLowerBound": str(floor)})
        self.assertEqual(verdict("unknown", 48_000_000), "unknownDemand")
        self.assertEqual(verdict(S19, "none"), "noEvidence")
        self.assertEqual(verdict(72_000_000, 48_000_000, "true"), "fits")
        self.assertEqual(verdict(S19, 48_000_000, "true"), "measuredInsufficient")
        # 20:2x q2: a 22.8 Mbps rendition floor alone.
        self.assertEqual(verdict(S19, 22_800_000, floor=22_800_000), "lowerBoundTooFar")
        self.assertEqual(verdict(68_400_000, 22_800_000, floor=22_800_000), "explore")
        self.assertEqual(verdict(68_400_001, 22_800_000, floor=22_800_000), "lowerBoundTooFar")
        # A probe floor never opens a trial, however close it reads.
        self.assertEqual(verdict(S19, 31_400_000), "lowerBoundTooFar")

    def test_rendition_is_half_the_capacity_on_the_ladder_within_the_ceiling(self):
        self.assertEqual(expected_rendition(48_000_000, 20_000_000), 20_000_000)
        self.assertEqual(expected_rendition(48_000_000, 12_000_000), 12_000_000)
        self.assertEqual(expected_rendition(48_000_000, 16_000_000), 12_000_000)
        self.assertEqual(expected_rendition(22_300_000, 12_000_000), 10_000_000)
        self.assertEqual(expected_rendition(6_800_000, 12_000_000), 2_000_000)
        self.assertEqual(expected_rendition(300_000, 12_000_000), 250_000)

    def test_consistent_playbacks_pass(self):
        result = rows(
            evidence("HLS00001", "lowerBoundTooFar", capacity=22_800_000, floor=22_800_000),
            request("HLS00001"), skip("HLS00001", "lowerBoundFarBelowSource"), prepared("HLS00001"),
            evidence("ORIG0001", "explore", capacity=30_000_000, floor=30_000_000),
            request("ORIG0001"), prepared("ORIG0001", "jellyfinOriginalDirectPlay", "unlimitedOriginal"),
            # An original verdict may still end on the server for another reason.
            evidence("AUDIO001", "fits", capacity=60_000_000, two_sided="true"),
            request("AUDIO001", ceiling="20000000"), skip("AUDIO001", "audioTranscodeRequired"),
            prepared("AUDIO001", bitrate="20000000"))
        self.assertEqual([row["problems"] for row in result], [[], [], []])
        self.assertEqual([row["route"] for row in result], ["server", "original", "server"])
        self.assertIn("3 playback(s) with route evidence, 0 to check.", render(result))

    def test_wrong_verdict_route_reason_and_rendition_are_reported(self):
        result = rows(
            evidence("BAD00001", "fits", capacity=22_800_000, floor=22_800_000),
            request("BAD00001"), prepared("BAD00001", "jellyfinOriginalDirectPlay", "unlimitedOriginal"),
            evidence("BAD00002", "measuredInsufficient", capacity=48_000_000, two_sided="true"),
            request("BAD00002"), prepared("BAD00002", "jellyfinOriginalDirectPlay", "unlimitedOriginal"),
            evidence("BAD00003", "measuredInsufficient", capacity=48_000_000, two_sided="true"),
            request("BAD00003"), skip("BAD00003", "lowerBoundFarBelowSource"),
            prepared("BAD00003", bitrate="4000000"))
        self.assertEqual(len(result[0]["problems"]), 1)
        self.assertIn("give lowerBoundTooFar", result[0]["problems"][0])
        self.assertEqual(result[1]["problems"], ["original played although the verdict ruled it out"])
        self.assertEqual(len(result[2]["problems"]), 2)
        self.assertIn("does not match verdict", result[2]["problems"][0])
        self.assertIn("give 12000000", result[2]["problems"][1])

    def test_private_legacy_and_forced_requests_are_not_judged_by_the_verdict(self):
        result = rows(
            # LAN: the verdict is logged but the original always plays.
            evidence("LAN00001", "measuredInsufficient", capacity=25_900_000, two_sided="true"),
            request("LAN00001", ceiling="legacyBudget"),
            prepared("LAN00001", "jellyfinOriginalDirectPlay", "unlimitedOriginal"),
            # A track switch keeps the rendition it was given.
            evidence("TRACK001", "fits", capacity=60_000_000, two_sided="true"),
            request("TRACK001", reason="sourceTrackSwitch"),
            skip("TRACK001", "sourceTrackSwitch", mode="serverHLSRequested"),
            prepared("TRACK001", bitrate="2000000"))
        self.assertEqual([row["problems"] for row in result], [[], []])
        self.assertEqual([row["governedByVerdict"] for row in result], [False, False])

    def test_records_without_evidence_or_identity_are_ignored(self):
        result = rows(request("OLD00001"), prepared("OLD00001"),
                      line(stage="routeCapacityEvidence", playbackTraceID="-", originalVerdict="fits"))
        self.assertEqual(result, [])
        self.assertTrue(any("No routeCapacityEvidence" in text for text in render(result)))


if __name__ == "__main__":
    unittest.main()
