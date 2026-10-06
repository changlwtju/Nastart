import tempfile
import unittest
from unittest.mock import patch
import subprocess
from pathlib import Path
from ui_scroll_probe import (union_duration, content_positions, rows,
                             motion_window_complete, display_sampling_complete, sampler_preflight,
                             validate_scroll_target, confirm_anchor_rect)


class ScrollEvidenceTests(unittest.TestCase):
    def test_live_anchor_visibility_must_match_exact_snapshot_node(self):
        xml = '<e type="XCUIElementTypeApplication" width="810" height="1080"><e name="完成" x="20" y="31" width="42" height="29"/></e>'
        rect = dict(x=20, y=31, width=42, height=29)
        confirm_anchor_rect(xml, '完成', rect, True)
        validate_scroll_target(xml, 650, 310, 850, ['完成'], ['完成'])
        for displayed, actual in [(False, rect), (True, dict(rect, y=90))]:
            with self.assertRaisesRegex(RuntimeError, 'anchor'):
                confirm_anchor_rect(xml, '完成', actual, displayed)
        with self.assertRaisesRegex(RuntimeError, 'anchor'):
            confirm_anchor_rect(xml.replace('</e>', '<e name="完成" x="20" y="31" width="42" height="29"/></e>'),
                                '完成', rect, True)

    def test_swiftui_wrapper_and_button_bound_by_live_element_type(self):
        xml = '<e><e type="XCUIElementTypeOther" name="完成" x="20" y="31" width="42" height="29"><e type="XCUIElementTypeButton" name="完成" x="20" y="31" width="42" height="29"/></e></e>'
        rect = dict(x=20, y=31, width=42, height=29)
        confirm_anchor_rect(xml, '完成', rect, True, 'XCUIElementTypeButton')
        with self.assertRaisesRegex(RuntimeError, 'anchor'):
            confirm_anchor_rect(xml, '完成', rect, True, 'XCUIElementTypeStaticText')

    def test_same_app_landscape_player_rejected_before_drag(self):
        xml = '<e type="XCUIElementTypeApplication" width="844" height="390"><e name="启动台" visible="true"/></e>'
        with self.assertRaisesRegex(RuntimeError, 'viewport'):
            validate_scroll_target(xml, 300, 250, 650, ['启动台'])

    def test_same_app_wrong_page_or_hidden_anchor_rejected(self):
        xml = '<e type="XCUIElementTypeApplication" width="390" height="844"><e name="启动台" visible="true"/><e name="媒体" visible="false"/></e>'
        validate_scroll_target(xml, 300, 250, 650, ['启动台'])
        for anchors in ([], ['电影'], ['启动台', '媒体']):
            with self.assertRaisesRegex(RuntimeError, 'anchors'):
                validate_scroll_target(xml, 300, 250, 650, anchors)

    def test_zero_exit_empty_sampler_is_not_ready(self):
        with tempfile.TemporaryDirectory() as folder, patch('ui_scroll_probe.subprocess.run') as run:
            run.side_effect = [subprocess.CompletedProcess([], 0, output, '') for output in
                               ('No devices available for the recording', 'No instruments found', 'Allocations')]
            with self.assertRaisesRegex(RuntimeError, 'Host Instruments exposes no'):
                sampler_preflight(Path(folder), 'test-udid')
            self.assertTrue((Path(folder) / 'sampler-preflight.json').exists())

    def test_sampler_enumeration_timeout_retains_evidence(self):
        with tempfile.TemporaryDirectory() as folder, patch('ui_scroll_probe.subprocess.run') as run:
            run.side_effect = [subprocess.TimeoutExpired(['xcrun'], 15, output=b'partial devices'),
                               subprocess.CompletedProcess([], 0, 'Animation Hitches', ''),
                               subprocess.CompletedProcess([], 0, 'Animation Hitches', '')]
            with self.assertRaisesRegex(RuntimeError, 'timed out'):
                sampler_preflight(Path(folder), 'test-udid')
            self.assertEqual((Path(folder) / 'xctrace-devices.log').read_text(), 'partial devices')

    def complete_manifest(self):
        return dict(motion_start=101, motion_end=126, completed_swipes=12,
                    foreground_verified=True, movement_verified=True,
                    movement_checks=[True]*12, foreground_checks=[True]*12,
                    gestures=[[101 + 2*i, 102 + 2*i] for i in range(12)])

    def test_twelve_actions_required_even_when_hitches_are_zero(self):
        manifest = self.complete_manifest()
        self.assertTrue(motion_window_complete(manifest, 100, 60))
        for count in (10, 11):
            manifest['completed_swipes'] = count
            self.assertFalse(motion_window_complete(manifest, 100, 60))

    def test_missing_or_out_of_trace_actions_cannot_pass(self):
        manifest = self.complete_manifest()
        manifest['gestures'].pop()
        self.assertFalse(motion_window_complete(manifest, 100, 60))
        manifest = self.complete_manifest()
        self.assertFalse(motion_window_complete(manifest, 110, 60))
        self.assertFalse(motion_window_complete(manifest, 100, 20))
        del manifest['motion_end']
        self.assertFalse(motion_window_complete(manifest, 100, 60))

    def test_reversed_or_overlapping_actions_cannot_pass(self):
        manifest = self.complete_manifest()
        manifest['gestures'][0] = [102, 101]
        self.assertFalse(motion_window_complete(manifest, 100, 60))
        manifest['gestures'][0] = [101, 104]
        self.assertFalse(motion_window_complete(manifest, 100, 60))

    def test_boundary_swipe_or_app_switch_cannot_pass(self):
        manifest = self.complete_manifest()
        manifest['movement_checks'][4] = False
        self.assertFalse(motion_window_complete(manifest, 100, 60))
        manifest = self.complete_manifest()
        manifest['foreground_checks'][4] = False
        self.assertFalse(motion_window_complete(manifest, 100, 60))

    def test_extra_displaced_drag_can_replace_retained_boundary_bounce(self):
        manifest = self.complete_manifest()
        manifest['movement_checks'][4] = False
        self.assertFalse(motion_window_complete(manifest, 100, 60))
        manifest['gestures'].append([125, 126])
        manifest['completed_swipes'] += 1
        manifest['movement_checks'].append(True)
        manifest['foreground_checks'].append(True)
        self.assertTrue(motion_window_complete(manifest, 100, 60))

    def test_overlapping_hitches_not_double_counted(self):
        self.assertAlmostEqual(union_duration([(1, 3), (2, 4), (4, 5), (7, 8)]), 5)

    def test_empty_hitches(self):
        self.assertEqual(union_duration([]), 0)

    def test_empty_or_sparse_display_stream_cannot_prove_smoothness(self):
        manifest = self.complete_manifest()
        self.assertFalse(display_sampling_complete(manifest, 100, []))
        self.assertFalse(display_sampling_complete(manifest, 100, range(30)))
        points = [i / 60 for i in range(1800)]
        self.assertTrue(display_sampling_complete(manifest, 100, points))
        # Missing frames in one drag must fail even with ample samples elsewhere.
        points = [t for t in points if not 9.3 < t < 9.5]
        self.assertFalse(display_sampling_complete(manifest, 100, points))

    def test_display_stream_must_cover_last_drag(self):
        self.assertFalse(display_sampling_complete(
            self.complete_manifest(), 100, [i / 60 for i in range(1300)]))

    def test_toolbar_and_duplicate_labels_cannot_prove_motion(self):
        xml = '<app><e type="XCUIElementTypeStaticText" name="title" y="35"/><e type="XCUIElementTypeStaticText" name="same" y="100"/><e type="XCUIElementTypeStaticText" name="same" y="200"/><e type="XCUIElementTypeStaticText" name="shelf" y="400"/></app>'
        self.assertEqual(content_positions(xml), {'shelf': 400})

    def test_missing_trace_schema_is_not_zero_hitches(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder) / 'empty.xml'
            p.write_text('<trace-query-result/>')
            with self.assertRaises(ValueError):
                rows(p)

    def test_instruments_reference_cells_resolve(self):
        xml = '<root><schema><col><mnemonic>duration</mnemonic></col></schema><row><duration id="1">150</duration></row><row><duration ref="1"/></row></root>'
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder) / 'trace.xml'
            p.write_text(xml)
            self.assertEqual([r['duration'].text for r in rows(p)], ['150', '150'])


if __name__ == '__main__':
    unittest.main()
