"""Reader delivery windows and player samples align on one monotonic clock."""

import unittest

from playback_reader_timing_report import build_report


def window(trace, start, end, reader, consumer, size=1_000_000, reads=None, queue=0, read=0):
    fields = {
        "stage": "readerTimingWindow", "playbackTraceID": trace,
        "windowStartUptimeMs": str(start), "windowEndUptimeMs": str(end),
        "readerWaitMs": str(reader), "consumerWaitMs": str(consumer), "windowBytes": str(size),
        "transferID": "T", "range": "bytes=0-99"}
    if reads is not None:
        # Only a Reader that times its own reads (SMB) logs these.
        fields.update({"readerReads": str(reads), "readerQueueWaitMs": str(queue),
                       "readerReadMs": str(read)})
    return {"messageKey": "diagnostics.media.proxy_transfer_progress", "fields": fields}


def first_chunk(trace, transfer, delay, queue=None, read=None, size=16_384):
    fields = {"stage": "readerFirstChunkDelivered", "playbackTraceID": trace,
              "transferID": transfer, "bytes": str(size), "readerToDeliveryMs": str(delay)}
    if queue is not None:
        fields.update({"firstReadQueueWaitMs": str(queue), "firstReadMs": str(read)})
    return {"messageKey": "diagnostics.media.proxy_transfer_started", "fields": fields}


def sample(trace, uptime, seconds, stalled, read, state="playing"):
    return {"messageKey": "diagnostics.playback.next.telemetry_sample", "fields": {
        "playbackTraceID": trace, "uptimeMs": str(uptime), "currentSeconds": str(seconds),
        "stallActive": "yes" if stalled else "no", "ksPlayerState": state, "bytesRead": str(read),
        "videoBitrate": "80000000", "audioBitrate": "640000"}}


class ReaderTimingReportTests(unittest.TestCase):
    def stall_report(self, reader, consumer, **timing):
        trace = "abc"
        entries = [sample(trace, 0, 10.0, False, 0), sample(trace, 1000, 11.0, False, 1_000_000)]
        for second in range(1, 5):
            entries.append(window(trace, second * 1000, second * 1000 + 1000, reader, consumer, **timing))
            entries.append(sample(trace, second * 1000 + 1000, 11.0, True, 1_000_000 + second * 1000, "buffering"))
        entries.append(sample(trace, 6000, 12.0, False, 9_000_000))
        entries.append(window("other", 0, 9000, 9000, 0))
        return build_report(entries, trace)

    def test_reader_bound_stall(self):
        report = self.stall_report(reader=900, consumer=20)
        self.assertEqual(report["verdict"], "readerBound")
        stall = report["stalls"][0]
        self.assertEqual(stall["intervals"], 4)
        self.assertEqual(stall["proxyDeliveredBytes"], 4_000_000)
        self.assertEqual(stall["readerWaitMs"], 3600)
        self.assertEqual(stall["playerBytesRead"], 4000)

    def test_player_not_reading_stall(self):
        self.assertEqual(self.stall_report(reader=10, consumer=950)["verdict"], "playerNotReading")

    def test_delivered_without_clock(self):
        self.assertEqual(self.stall_report(reader=100, consumer=100)["verdict"], "deliveredWithoutClock")

    def test_no_reader_window_and_missing_uptime(self):
        trace = "x"
        entries = [sample(trace, 0, 1.0, False, 0), sample(trace, 1000, 1.0, True, 0, "buffering"),
                   sample(trace, 2000, 2.0, False, 0)]
        self.assertEqual(build_report(entries, trace)["verdict"], "noReaderTransfer")
        legacy = [{"messageKey": "telemetry_sample", "fields": {"playbackTraceID": trace, "currentSeconds": "1"}}]
        self.assertEqual(build_report(legacy, trace)["verdict"], "insufficientEvidence")

    def test_reader_bound_stall_is_split_by_the_readers_own_timing(self):
        # S19 over SMB: ten 1 MiB reads a second, each about 95 ms on the connection.
        wire = self.stall_report(reader=980, consumer=5, size=10 * 1_048_576, reads=10, queue=0, read=950)
        stall = wire["stalls"][0]
        self.assertEqual(stall["attribution"], "readerBound")
        self.assertEqual(stall["readerDetail"], "onTheConnection")
        self.assertEqual(stall["readerReadMs"], 3800)
        split = wire["readerSplit"]
        self.assertEqual(split["reads"], 40)
        self.assertEqual(split["readMs"], 3800)
        self.assertEqual(split["queueWaitMs"], 0)
        self.assertEqual(split["otherMs"], 120)
        self.assertEqual(split["meanReadMs"], 95.0)
        # 40 MiB over 3.8 s of reading: about 88 Mbps one read at a time.
        self.assertEqual(split["wireBitrate"], round(40 * 1_048_576 * 8 / 3.8))

        # The same wait, spent behind another request's read instead.
        queued = self.stall_report(reader=980, consumer=5, reads=4, queue=800, read=150)
        self.assertEqual(queued["stalls"][0]["readerDetail"], "queuedBehindAnotherRead")
        self.assertEqual(self.stall_report(reader=980, consumer=5, reads=4, queue=450,
                                           read=450)["stalls"][0]["readerDetail"], "mixed")

        # A Reader that does not time its reads leaves the split unknown.
        silent = self.stall_report(reader=900, consumer=20)
        self.assertEqual(silent["stalls"][0]["readerDetail"], "notReported")
        self.assertIsNone(silent["readerSplit"])
        # The split belongs to Reader-bound stalls only.
        self.assertNotIn("readerDetail", self.stall_report(reader=10, consumer=950, reads=4, queue=0,
                                                           read=10)["stalls"][0])

    def test_first_reads_show_a_wait_behind_another_read(self):
        trace = "abc"
        entries = [sample(trace, 0, 1.0, False, 0), sample(trace, 1000, 2.0, False, 1_000_000),
                   first_chunk(trace, "body", 96, queue=0, read=95, size=1_048_576),
                   # A 16 KB tail read: 141 ms to deliver, most of it queued.
                   first_chunk(trace, "tail", 141, queue=92, read=47),
                   first_chunk(trace, "webdav", 80),
                   first_chunk("other", "x", 5, queue=1, read=2)]
        firsts = build_report(entries, trace)["firstReads"]
        self.assertEqual([row["transferID"] for row in firsts], ["body", "tail", "webdav"])
        self.assertEqual(firsts[1], {"transferID": "tail", "bytes": 16_384.0, "readerToDeliveryMs": 141.0,
                                     "queueWaitMs": 92.0, "readMs": 47.0})
        self.assertIsNone(firsts[2]["queueWaitMs"])


if __name__ == "__main__":
    unittest.main()
