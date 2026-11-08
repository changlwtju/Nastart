import copy
from dataclasses import replace
import json
import unittest

from pip_pause_evidence import Capture, InsufficientEvidence, assess_native_pause, entries_from_preferences, require_pause_baseline
from wda_usb_session import Scene, UIObservation


OWNER = '12345678-0000-0000-0000-000000000001'
PREFIX = 'diagnostics.playback.next.'


def event(identity, name, date, **metrics):
    details = dict(playbackTraceID='ABCDEF12', planID=OWNER[:8], ownerPlanID=OWNER)
    details.update(metrics)
    return {'id': identity, 'date': date, 'messageKey': PREFIX + name,
            'detail': ', '.join(k + '=' + str(v) for k, v in details.items())}


def capture(start, finish, button, rows):
    xml = f'<App><XCUIElementTypeButton name="{button}" visible="true" enabled="true"/></App>'
    ui = UIObservation(Scene('private-session', 'com.apple.springboard', 123, 'PORTRAIT'),
                       start + 0.1, finish - 0.1, xml, b'\x89PNG\r\n\x1a\nfixture')
    return Capture(start, finish, ui, tuple(rows))


def fixtures():
    baseline = event('before', 'pip_started', 10, enginePlaying='true',
                     runtimeSnapshotUptime='100', currentSeconds='10')
    paused = event('after', 'pip_system_playback_changed', 11, requestedPlaying='false',
                   actualPlaying='false', snapshotUptime='101', currentSeconds='11',
                   observationID='87654321-0000-0000-0000-000000000001')
    return (capture(1, 2, '暂停', [baseline]), capture(3, 4, '播放', [baseline, paused]),
            capture(6.5, 7, '播放', [baseline, copy.deepcopy(paused)]))


class PauseEvidenceTests(unittest.TestCase):
    def reject(self, before, first, held):
        with self.assertRaises(InsufficientEvidence):assess_native_pause(before, first, held)

    def test_new_exact_owner_command_and_separated_native_ui_form_scoped_proof(self):
        proof = assess_native_pause(*fixtures())
        self.assertTrue(proof['nativePauseCommandObserved'])
        self.assertTrue(proof['fullOwnerMatched'])
        self.assertEqual(proof['nativePausedUIObservationGapSeconds'], 2.5)
        for field in ['continuouslyStoppedClockVerified', 'restoredMovieVerified', 'audioVerified', 'framePacingVerified']:
            self.assertFalse(proof[field])
        self.assertNotIn(OWNER, json.dumps(proof))

    def test_unchanged_cached_preferences_never_prove_pause(self):
        before, first, held = fixtures()
        self.reject(before, replace(first, entries=before.entries), replace(held, entries=before.entries))

    def test_same_prefix_another_full_owner_is_rejected(self):
        before, first, held = fixtures()
        for c in (first, held):c.entries[-1]['detail'] = c.entries[-1]['detail'].replace(OWNER, OWNER[:-1] + '2')
        self.reject(before, first, held)

    def test_short_or_missing_baseline_owner_never_promoted_to_full_identity(self):
        for owner in ['12345678', '-', '']:
            before, first, held = fixtures()
            for c in (before, first, held):c.entries[0]['detail'] = c.entries[0]['detail'].replace(OWNER, owner)
            self.reject(before, first, held)

    def test_requested_pause_without_actual_pause_is_rejected(self):
        before, first, held = fixtures()
        for c in (first, held):c.entries[-1]['detail'] = c.entries[-1]['detail'].replace('actualPlaying=false', 'actualPlaying=true')
        self.reject(before, first, held)

    def test_duplicate_new_native_commands_are_ambiguous(self):
        before, first, held = fixtures()
        duplicate = copy.deepcopy(first.entries[-1]);duplicate['id'] = 'another';duplicate['date'] = 12
        self.reject(before, replace(first, entries=first.entries + (duplicate,)),
                    replace(held, entries=held.entries + (copy.deepcopy(duplicate),)))

    def test_old_or_nonfinite_native_snapshot_is_rejected(self):
        for value in ['99', '100', 'nan', 'inf', '-1']:
            before, first, held = fixtures()
            for c in (first, held):c.entries[-1]['detail'] = c.entries[-1]['detail'].replace('snapshotUptime=101', 'snapshotUptime=' + value)
            self.reject(before, first, held)

    def test_invalid_position_or_backwards_seek_is_rejected(self):
        for value in ['nan', 'inf', '-1', '8']:
            before, first, held = fixtures()
            for c in (first, held):c.entries[-1]['detail'] = c.entries[-1]['detail'].replace('currentSeconds=11', 'currentSeconds=' + value)
            self.reject(before, first, held)

    def test_intervening_resume_new_route_restore_stop_and_seek_are_rejected(self):
        for name in ['resumed', 'route_selected', 'pip_started', 'pip_restore_requested', 'pip_stopped',
                     'playback_stopped', 'playback_failed', 'seek_started']:
            before, first, held = fixtures()
            self.reject(before, first, replace(held, entries=held.entries + (event('transition', name, 12),)))

    def test_changed_native_scene_or_playing_ui_is_rejected(self):
        before, first, held = fixtures()
        self.reject(before, first, replace(held, ui=replace(held.ui, scene=replace(held.ui.scene, pid=456))))
        self.reject(before, first, capture(6.5, 7, '暂停', held.entries))
        self.reject(capture(1, 2, '播放', before.entries), first, held)

    def test_missing_ring_anchor_mutated_event_and_duplicate_ids_are_rejected(self):
        before, first, held = fixtures()
        self.reject(before, first, replace(held, entries=(held.entries[-1],)))
        changed = copy.deepcopy(held.entries[-1]);changed['detail'] += ', extra=true'
        self.reject(before, first, replace(held, entries=(held.entries[0], changed)))
        self.reject(before, first, replace(held, entries=held.entries + (held.entries[-1],)))

    def test_out_of_order_dates_old_event_and_incomplete_hold_are_rejected(self):
        before, first, held = fixtures()
        self.reject(before, first, replace(held, entries=tuple(reversed(held.entries))))
        self.reject(before, first, capture(4.5, 5, '播放', held.entries))
        for c in (first, held):c.entries[-1]['date'] = 10
        self.reject(before, first, held)

    def test_ambiguous_metrics_missing_sample_id_or_trace_are_rejected(self):
        for old, new in [('snapshotUptime=101', 'snapshotUptime=101, snapshotUptime=102'),
                         ('observationID=87654321-0000-0000-0000-000000000001', 'observationID=-'),
                         ('playbackTraceID=ABCDEF12', 'playbackTraceID=00000000')]:
            before, first, held = fixtures()
            for c in (first, held):c.entries[-1]['detail'] = c.entries[-1]['detail'].replace(old, new)
            self.reject(before, first, held)

    def test_raw_preferences_are_read_without_rewriting_private_entries(self):
        rows = list(fixtures()[0].entries)
        preferences = {'diagnostics.entries.v1': json.dumps(rows).encode()}
        self.assertEqual(entries_from_preferences(preferences), tuple(rows))
        for value in [{}, {'diagnostics.entries.v1': b'{}'}, {'diagnostics.entries.v1': b'bad'}]:
            with self.assertRaises(InsufficientEvidence):entries_from_preferences(value)

    def test_baseline_missing_clock_or_monotonic_anchor_is_rejected_before_action(self):
        for old, new in [('currentSeconds=10', 'currentSeconds=-'),
                         ('runtimeSnapshotUptime=100', 'runtimeSnapshotUptime=0')]:
            before, _, _ = fixtures()
            before.entries[0]['detail'] = before.entries[0]['detail'].replace(old, new)
            with self.assertRaises(InsufficientEvidence):require_pause_baseline(before)

    def test_existing_native_observation_token_cannot_be_relabelled_as_new(self):
        before, first, held = fixtures()
        old = copy.deepcopy(first.entries[-1]);old['id'] = 'older-native';old['date'] = 9
        self.reject(replace(before, entries=(old,) + before.entries),
                    replace(first, entries=(old,) + first.entries),
                    replace(held, entries=(old,) + held.entries))

    def test_superseded_baseline_is_rejected_before_sending_pause(self):
        for name in ['route_selected', 'seek_started', 'pip_stopped', 'playback_ended']:
            before, _, _ = fixtures()
            before = replace(before, entries=before.entries + (event('intervening', name, 11),))
            with self.assertRaises(InsufficientEvidence):require_pause_baseline(before)


if __name__ == '__main__':unittest.main()
