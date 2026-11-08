"""Guard private-log correlation against false matches and sensitive output."""
import json
import unittest

from playback_server_log_report import APPLE_EPOCH, report, server_commands, timestamp


class ServerCorrelationTests(unittest.TestCase):
    def setUp(self):
        self.start = timestamp("2026-10-15T08:00:00Z")
        self.line = ('[2026-10-15 16:00:01.200 +08:00] [INF] Manager: '
                     '"/secret/ffmpeg" -ss 00:01:40.100 -i "http://private/media?api_key=SECRET" '
                     '-start_number 25 -codec:v:0 h264_vaapi -codec:a:0 libfdk_aac '
                     '-filter_complex "[v][s]overlay_vaapi" -hls_segment_filename "/private/%d.ts"')

    def event(self, at, stage=None, key="proxy_transfer_started", **fields):
        if stage:
            fields["stage"] = stage
        return {"date": self.start + at - APPLE_EPOCH,
                "messageKey": "diagnostics.media." + key,
                "detail": {"transferID": "PRIVATE_TRANSFER", "upstreamTaskIndex": "1",
                           "hlsRole": "segment", "segmentOrdinal": "25", **fields}}

    def result(self, events=(), commands=None, actions=None, **kwargs):
        return report(events, server_commands(self.line) if commands is None else commands,
                      [{"requestStart": self.start}] if actions is None else actions,
                      self.start + 30, **kwargs)

    def keyed_commands(self, key, at="01.200", ordinal=25):
        line = self.line.replace("01.200", at).replace("-start_number 25", "-start_number " + str(ordinal))
        line = line.replace("/private/%d.ts", "/private/" + key + "%d.ts")
        return server_commands(line, retain_output_keys=True)

    def keyed_metrics(self, key, at=2):
        return self.event(at, "urlSessionTaskMetrics", jellyfinOutputKeyCandidate=key,
                          jellyfinOutputKeyBasis="10.11.11FormulaActualMetricsRequest")

    def test_output_key_disambiguates_concurrent_commands_without_exporting_private_key(self):
        key, other = "a" * 32, "b" * 32
        commands = self.keyed_commands(key, at="15.000") + self.keyed_commands(other)
        result = self.result([self.event(0.2, "upstreamRequestIssued"), self.keyed_metrics(key)], commands)
        row = result["operations"][0]
        self.assertEqual(row["association"], "outputKeyAndOrdinalMatch")
        self.assertEqual(row["serverOutputKeyCommandCount"], 1)
        self.assertEqual(row["serverCommand"]["secondsFromAction"], 15)
        self.assertFalse(result["sessionIdentityVerified"])
        self.assertNotIn(key, json.dumps(result))
        self.assertNotIn(other, json.dumps(result))
        self.assertNotIn("_output", json.dumps(result))

    def test_output_key_mismatch_never_falls_back_to_time_match(self):
        result = self.result([self.event(0.2, "upstreamRequestIssued"), self.keyed_metrics("a" * 32)],
                             self.keyed_commands("b" * 32))
        self.assertEqual(result["operations"][0]["association"], "outputKeyUnmatched")
        self.assertIsNone(result["operations"][0]["serverCommand"])

    def test_conflicting_retry_keys_and_multiple_restarts_stay_ambiguous(self):
        key = "a" * 32
        events = [self.event(0.2, "upstreamRequestIssued"), self.keyed_metrics(key),
                  self.keyed_metrics("b" * 32, at=3)]
        row = self.result(events, self.keyed_commands(key))["operations"][0]
        self.assertEqual(row["association"], "ambiguousClientOutputKey")
        self.assertIsNone(row["serverCommand"])
        row = self.result(events[:2], self.keyed_commands(key) + self.keyed_commands(key, at="02.000"))["operations"][0]
        self.assertEqual(row["association"], "ambiguousOutputCommands")
        self.assertEqual(row["serverOutputKeyCommandCount"], 2)

    def test_existing_job_at_other_ordinal_is_retained_without_fabricating_a_launch(self):
        key = "a" * 32
        row = self.result([self.event(0.2, "upstreamRequestIssued"), self.keyed_metrics(key)],
                          self.keyed_commands(key, ordinal=0))["operations"][0]
        self.assertEqual(row["association"], "outputKeyMatchesOtherOrdinal")
        self.assertEqual(row["serverOutputKeyCommandCount"], 1)
        self.assertIsNone(row["serverCommand"])

    def test_optional_primer_is_retained_without_becoming_player_first_segment(self):
        events = [self.event(0.1, "upstreamRequestIssued", transferID="PRIMER", startupPrimer="true", segmentOrdinal="0"),
                  self.event(1, "upstreamCancellationRequested", transferID="PRIMER", startupPrimer="true"),
                  self.event(2, "upstreamRequestIssued", segmentOrdinal="25"), self.event(3, status="200")]
        row = self.result(events)["operations"][0]
        self.assertEqual(len(row["firstSegmentRequests"]), 1)
        self.assertEqual(row["firstSegmentRequests"][0]["segmentOrdinal"], 25)
        excluded = row["excludedSegmentRequests"]
        self.assertEqual(len(excluded), 1)
        self.assertEqual(excluded[0]["exclusionReason"], "optionalStartupPrimer")
        self.assertTrue(excluded[0]["startupPrimer"])
        self.assertEqual(excluded[0]["cancelRequestedSeconds"], 1)

    def test_only_optional_primer_does_not_fabricate_decoder_request(self):
        row = self.result([self.event(1, "upstreamRequestIssued", startupPrimer="true")])["operations"][0]
        self.assertEqual(row["firstSegmentRequests"], [])
        self.assertEqual(row["excludedSegmentRequests"][0]["exclusionReason"], "optionalStartupPrimer")

    def test_timezone_and_dotnet_fraction(self):
        self.assertEqual(timestamp("2026-10-15 16:00:00.1234567 +08:00"),
                         timestamp("2026-10-15T08:00:00.123456Z"))
        with self.assertRaises(ValueError):
            timestamp("2026-10-15T08:00:00")

    def test_fractional_precision_supported_by_python39(self):
        for digits in ["1", "12", "123", "1234", "12345", "123456", "1234567"]:
            self.assertEqual(timestamp("2026-10-15T08:00:00." + digits + "Z"),
                             self.start + float("0." + digits[:6]))

    def test_zero_based_command_without_seek_is_not_discarded(self):
        line = self.line.replace("-ss 00:01:40.100 ", "").replace("-start_number 25", "-start_number 0")
        commands = server_commands(line)
        self.assertEqual(len(commands), 1)
        self.assertEqual(commands[0]["seekSeconds"], 0)
        wrapped = line.split("Manager: ")[0] + "Manager: " + json.dumps(line.split("Manager: ")[1])
        self.assertEqual(server_commands(wrapped), commands)
        row = self.result([self.event(1, "upstreamRequestIssued", segmentOrdinal="0")], commands)["operations"][0]
        self.assertEqual(row["serverCandidateCount"], 1)

    def test_playlist_wait_does_not_hide_matching_segment_command(self):
        command = self.line.replace("00:01.200", "00:11.200")
        result = self.result([self.event(11, "upstreamRequestIssued")], server_commands(command))
        row = result["operations"][0]
        self.assertEqual(row["serverCandidateCount"], 1)
        self.assertEqual(row["serverCommand"]["secondsFromAction"], 11.2)
        self.assertEqual(result["matchingBoundary"], "firstSegmentRequest")
        stale = self.result([self.event(11, "upstreamRequestIssued")])["operations"][0]
        self.assertEqual(stale["association"], "unmatched")

    def test_http_failure_is_headers_not_silence(self):
        events = [self.event(1, "upstreamRequestIssued"), self.event(20, status="504"),
                  self.event(21, "upstreamTaskCompleted", key="proxy_transfer_finished",
                             upstreamHeadersObserved="true", taskReceivedBytes="128", errorCode="-")]
        request = self.result(events)["operations"][0]["firstSegmentRequests"][0]
        self.assertEqual(request["responseStatus"], 504)
        self.assertEqual(request["responseHeadersSeconds"], 20)
        self.assertTrue(request["headersObserved"])
        self.assertEqual(request["bodyBytesObserved"], 128)

    def test_no_body_callback_and_missing_evidence_are_distinct(self):
        events = [self.event(1, "upstreamRequestIssued"),
                  self.event(20, "upstreamTaskCompleted", key="proxy_transfer_finished",
                             upstreamHeadersObserved="false", upstreamTaskBodyBytes="0", errorCode="-999"),
                  self.event(2, "upstreamRequestIssued", transferID="OTHER")]
        first, other = self.result(events)["operations"][0]["firstSegmentRequests"]
        self.assertFalse(first["headersObserved"])
        self.assertEqual(first["bodyBytesObserved"], 0)
        self.assertEqual(first["errorCode"], -999)
        self.assertNotIn("headersObserved", other)
        self.assertNotIn("bodyBytesObserved", other)

    def test_candidate_failure_phase_is_allowlisted_and_bounded(self):
        events = [self.event(10, "decodedFrame", key="replacement_warmup_failed", elapsedMs="40020"),
                  self.event(20, "PRIVATE_SECRET", key="replacement_warmup_failed", elapsedMs="nan"),
                  self.event(31, "alignment", key="replacement_warmup_failed", elapsedMs="5")]
        failures = self.result(events)["operations"][0]["candidateFailures"]
        self.assertEqual(failures, [{"secondsFromAction": 10, "stage": "decodedFrame", "elapsedMs": 40020},
                                    {"secondsFromAction": 20, "stage": "unknown", "elapsedMs": None}])
        self.assertNotIn("SECRET", json.dumps(failures))

    def test_repeated_request_does_not_imply_repeated_transcoder(self):
        es = [self.event(1, "upstreamRequestIssued"),
              self.event(5, "upstreamRequestIssued", transferID="SECOND"),
              self.event(6, status="200"),
              self.event(6.1, "upstreamCancellationRequested", key="proxy_transfer_finished"),
              self.event(6.2, status="200", transferID="SECOND")]
        row = self.result(es)["operations"][0]
        self.assertEqual(row["serverCandidateCount"], 1)
        self.assertEqual(len(row["firstSegmentRequests"]), 2)
        self.assertEqual(row["firstSegmentRequests"][0]["cancelRequestedSeconds"], 6.1)
        self.assertEqual(row["firstSegmentRequests"][1]["responseHeadersSeconds"], 6.2)

    def test_ambiguous_same_ordinal_keeps_unknown(self):
        commands = server_commands(self.line + "\n" + self.line.replace("01.200", "02.200"))
        row = self.result([self.event(1, "upstreamRequestIssued")], commands)["operations"][0]
        self.assertEqual(row["association"], "ambiguous")
        self.assertIsNone(row["serverCommand"])

    def test_duplicate_server_snapshot_is_not_another_start(self):
        self.assertEqual(len(server_commands(self.line + "\n" + self.line)), 1)

    def test_logger_quoted_whole_command_is_parsed_as_data(self):
        prefix, command = self.line.split("Manager: ", 1)
        wrapped = prefix + "Manager: " + json.dumps(command)
        self.assertEqual(server_commands(wrapped), server_commands(self.line))

    def test_same_millisecond_distinct_private_commands_remain_ambiguous(self):
        text = self.line + "\n" + self.line.replace("/private/%d.ts", "/other/%d.ts")
        commands = server_commands(text)
        self.assertEqual(len(commands), 2)
        row = self.result([self.event(1, "upstreamRequestIssued")], commands)["operations"][0]
        self.assertEqual(row["association"], "ambiguous")
        self.assertIsNone(row["serverCommand"])

    def test_other_ordinal_or_missing_client_request_cannot_match(self):
        for es in [[], [self.event(1, "upstreamRequestIssued", segmentOrdinal="26")],
                   [self.event(1, "upstreamRequestIssued", segmentOrdinal="unknown")]]:
            row = self.result(es)["operations"][0]
            self.assertEqual(row["serverCandidateCount"], 0)
            self.assertIsNone(row["serverCommand"])

    def test_next_action_events_never_join_previous_operation(self):
        es = [self.event(1, "upstreamRequestIssued"), self.event(11, key="replacement_committed")]
        rows = self.result(es, actions=[{"requestStart": self.start},
                                       {"requestStart": self.start + 10}])["operations"]
        self.assertEqual(rows[0]["replacement_committedSeconds"], [])
        self.assertEqual(rows[1]["replacement_committedSeconds"], [1.0])
        self.assertEqual(rows[1]["association"], "unmatched")

    def test_transfer_retry_index_is_independent(self):
        es = [self.event(1, "upstreamRequestIssued"),
              self.event(2, "upstreamRequestIssued", upstreamTaskIndex="2")]
        self.assertEqual(len(self.result(es)["operations"][0]["firstSegmentRequests"]), 2)

    def test_headers_without_request_are_not_assumed_first_request(self):
        row = self.result([self.event(1, status="200")])["operations"][0]
        self.assertEqual(row["firstSegmentRequests"], [])
        self.assertIsNone(row["serverCommand"])

    def test_seek_touch_does_not_select_old_stream_request_before_dispatch(self):
        es = [self.event(.05, "upstreamRequestIssued", segmentOrdinal="40", transferID="OLD",
                         playbackTraceID="PRIVATE_TRACE"),
              self.event(.6, key="seek_dispatched", hlsRole="-", playbackTraceID="PRIVATE_TRACE"),
              self.event(.7, "upstreamRequestIssued", playbackTraceID="PRIVATE_TRACE"),
              self.event(.8, status="504", segmentOrdinal="40", transferID="OLD",
                         playbackTraceID="PRIVATE_TRACE")]
        row = self.result(es)["operations"][0]
        self.assertEqual(row["firstSegmentRequests"][0]["segmentOrdinal"], 25)
        self.assertEqual(row["serverCandidateCount"], 1)
        self.assertEqual(row["requestSelectionBoundary"], "seekDispatch")
        self.assertEqual(row["seekDispatchSecondsFromAction"], .6)
        excluded = row["excludedSegmentRequests"]
        self.assertEqual(excluded[0]["exclusionReason"], "beforeSeekDispatch")
        self.assertEqual(excluded[0]["responseStatus"], 504, "Keep old-stream failures")

    def test_seek_dispatch_trace_does_not_adopt_another_playback(self):
        es = [self.event(.6, key="seek_dispatched", hlsRole="-", playbackTraceID="PRIVATE_TRACE"),
              self.event(.65, "upstreamRequestIssued", segmentOrdinal="40", transferID="PEER",
                         playbackTraceID="PRIVATE_PEER"),
              self.event(.7, "upstreamRequestIssued", playbackTraceID="PRIVATE_TRACE")]
        result = self.result(es)
        row = result["operations"][0]
        self.assertEqual(row["firstSegmentRequests"][0]["segmentOrdinal"], 25)
        self.assertEqual(row["excludedSegmentRequests"][0]["exclusionReason"], "differentPlaybackTrace")
        self.assertNotIn("PRIVATE", json.dumps(result))

    def test_multiple_seek_dispatches_keep_operation_ambiguous(self):
        es = [self.event(.6, key="seek_dispatched", hlsRole="-"),
              self.event(.7, "upstreamRequestIssued"),
              self.event(.8, key="seek_dispatched", hlsRole="-")]
        row = self.result(es)["operations"][0]
        self.assertEqual(row["requestSelectionBoundary"], "ambiguousSeekDispatch")
        self.assertEqual(row["firstSegmentRequests"], [])
        self.assertIsNone(row["serverCommand"])
        self.assertEqual(len(row["excludedSegmentRequests"]), 1)

    def test_missing_trace_after_known_seek_dispatch_stays_unattributed(self):
        es = [self.event(.6, key="seek_dispatched", hlsRole="-", playbackTraceID="PRIVATE_TRACE"),
              self.event(.7, "upstreamRequestIssued")]
        row = self.result(es)["operations"][0]
        self.assertEqual(row["firstSegmentRequests"], [])
        self.assertIsNone(row["serverCommand"])
        self.assertEqual(row["excludedSegmentRequests"][0]["exclusionReason"], "missingPlaybackTrace")

    def test_clock_offset_is_explicit_not_silently_fitted(self):
        row = self.result([self.event(1, "upstreamRequestIssued")], server_offset=.125)["operations"][0]
        self.assertEqual(row["serverCommand"]["secondsFromAction"], 1.075)

    def test_bad_bounds_and_action_times_rejected(self):
        for actions in [[{"requestStart": float("nan")}], [{"requestStart": None}],
                        [{"requestStart": self.start}] * 2, [{"requestStart": self.start + 30}]]:
            with self.assertRaises(ValueError):
                self.result(actions=actions)
        with self.assertRaises(ValueError):
            self.result(server_offset=float("inf"))

    def test_sensitive_input_is_never_copied_to_report(self):
        result = self.result([self.event(1, "upstreamRequestIssued", target="http://SECRET")],
                             actions=[{"requestStart": self.start, "targetName": "PRIVATE_DIALOGUE"}])
        text = json.dumps(result)
        for secret in ["SECRET", "PRIVATE", "/private", "http://", "transferID"]:
            self.assertNotIn(secret, text)
        self.assertFalse(result["sessionIdentityVerified"])
        self.assertFalse(result["actualAudibleAccepted"])

    def test_malformed_commands_do_not_create_fake_starts(self):
        for line in [self.line.replace("-ss 00:01:40.100", "-ss nan"),
                     self.line.replace("-start_number 25", "-start_number -1"),
                     self.line + ' "unclosed', self.line.replace("+08:00", "")]:
            self.assertEqual(server_commands(line), [])


if __name__ == "__main__":
    unittest.main()
