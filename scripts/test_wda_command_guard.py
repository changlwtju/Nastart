import json
import unittest
from wda_command_guard import (ActionUnconfirmed, GuardedWDA, ProtocolError,
                               ObservationExpired, Reply, SceneChanged, SelectionError,
                               WDAResponseError, decode_reply)


SELECTOR = {'using': 'predicate string', 'value': 'name == "暂停"'}
STALE = Reply(404, json.dumps({'value': {'error': 'stale element reference',
    'message': 'PRIVATE_SPRINGBOARD_TREE_AND_DEVICE_DATA'}}).encode())


def reply(value=None, status=200):
    return Reply(status, json.dumps({'value': value}).encode())


class Fake:
    def __init__(self, responses, scenes=None):
        self.responses = iter(responses)
        self.scenes = iter(scenes) if scenes else None
        self.calls, self.events = [], []
        self.client = GuardedWDA(self.send, self.scene, self.events.append)

    def scene(self):
        return next(self.scenes) if self.scenes else ('session', 'springboard', 123, 'portrait')

    def send(self, route, body):
        self.calls.append((route, body))
        result = next(self.responses)
        if isinstance(result, Exception):
            raise result
        return result


class BoundaryTests(unittest.TestCase):
    def test_real_error_shape_classified_without_printing_tree(self):
        with self.assertRaises(WDAResponseError) as caught:
            decode_reply(STALE)
        self.assertEqual((caught.exception.status, caught.exception.code),
                         (404, 'stale element reference'))
        self.assertNotIn('PRIVATE_', str(caught.exception))

    def test_invalid_element_state_keeps_code_without_private_app_details(self):
        response = reply({'error': 'invalid element state',
                          'message': 'PRIVATE_APP_NOT_RUNNING_AND_DEVICE_DATA'}, 400)
        with self.assertRaises(WDAResponseError) as caught:
            decode_reply(response)
        self.assertEqual((caught.exception.status, caught.exception.code),
                         (400, 'invalid element state'))
        self.assertNotIn('PRIVATE_', str(caught.exception))
        self.assertEqual(caught.exception.private_payload['value']['message'],
                         'PRIVATE_APP_NOT_RUNNING_AND_DEVICE_DATA')

    def test_stale_reads_can_recover_without_replaying_actions(self):
        f = Fake([STALE, STALE, reply([{'ELEMENT': 'fresh'}])])
        self.assertEqual(f.client.query_elements(SELECTOR), [{'ELEMENT': 'fresh'}])
        self.assertEqual([route for route, _ in f.calls], ['/elements'] * 3)

    def test_stale_read_budget_exhaustion_sends_no_action(self):
        f = Fake([STALE] * 3)
        with self.assertRaises(WDAResponseError):f.client.click_unique(SELECTOR, lambda: True)
        self.assertEqual(len(f.calls), 3)
        self.assertFalse(f.client.action_blocked)

    def test_other_errors_are_not_retried(self):
        for response in [reply({'error': 'no such element'}, 404),
                         reply({'error': 'invalid session id'}, 404),
                         reply({'error': 'invalid element state'}, 400),
                         reply({'error': 'unknown error'}, 500),
                         reply({'error': 'stale element reference'}, 200),
                         Reply(502, b'not JSON'), TimeoutError('private host')]:
            with self.subTest(response=type(response).__name__):
                f = Fake([response])
                with self.assertRaises(Exception):f.client.query_elements(SELECTOR)
                self.assertEqual(len(f.calls), 1)

    def test_scene_change_aborts_before_read_retry(self):
        f = Fake([STALE], ['same', 'same', 'changed'])
        with self.assertRaises(SceneChanged):f.client.query_elements(SELECTOR)
        self.assertEqual(len(f.calls), 1)

    def test_scene_change_between_selection_and_action_sends_no_click(self):
        f = Fake([reply([{'ELEMENT': 'fresh'}])], ['same', 'same', 'changed'])
        with self.assertRaises(SceneChanged):f.client.click_unique(SELECTOR, lambda: True)
        self.assertEqual([r for r, _ in f.calls], ['/elements'])

    def test_missing_ambiguous_or_malformed_selection_sends_no_click(self):
        for rows in [[], [{'ELEMENT': 'a'}, {'ELEMENT': 'b'}], [{}],
                     [{'ELEMENT': 'a/click'}], [{'ELEMENT': 'a%2Fclick'}],
                     [{'ELEMENT': 'a\r\nInjected'}], [{'ELEMENT': '..'}],
                     {'ELEMENT': 'not-a-list'}]:
            with self.subTest(rows=rows):
                f = Fake([reply(rows)])
                with self.assertRaises((SelectionError, ProtocolError)):
                    f.client.click_unique(SELECTOR, lambda: True)
                self.assertEqual([r for r, _ in f.calls], ['/elements'])

    def test_click_stale_response_is_never_reselected_or_resent(self):
        f = Fake([reply([{'ELEMENT': 'fresh'}]), STALE])
        with self.assertRaises(ActionUnconfirmed):f.client.click_unique(SELECTOR, lambda: True)
        with self.assertRaises(ActionUnconfirmed):f.client.click_unique(SELECTOR, lambda: True)
        self.assertEqual([r for r, _ in f.calls], ['/elements', '/element/fresh/click'])

    def test_click_timeout_after_possible_execution_is_not_repeated(self):
        f = Fake([reply([{'ELEMENT': 'fresh'}]), TimeoutError('lost response')])
        with self.assertRaises(ActionUnconfirmed):f.client.click_unique(SELECTOR, lambda: True)
        self.assertTrue(f.client.action_blocked)
        self.assertEqual(len(f.calls), 2)

    def test_http_success_without_actual_effect_still_blocks_next_action(self):
        f = Fake([reply([{'ELEMENT': 'fresh'}]), reply()])
        with self.assertRaises(ActionUnconfirmed):f.client.click_unique(SELECTOR, lambda: False)
        with self.assertRaises(ActionUnconfirmed):f.client.click_unique(SELECTOR, lambda: True)
        self.assertEqual(len(f.calls), 2)

    def test_effect_verification_error_leaves_action_blocked(self):
        f = Fake([reply([{'ELEMENT': 'fresh'}]), reply()])
        def failed_observation():raise TimeoutError('screenshot unavailable')
        with self.assertRaises(ActionUnconfirmed):f.client.click_unique(SELECTOR, failed_observation)
        self.assertTrue(f.client.action_blocked)

    def test_effect_requires_literal_true_not_truthy_payload(self):
        f = Fake([reply([{'ELEMENT': 'fresh'}]), reply()])
        with self.assertRaises(ActionUnconfirmed):f.client.click_unique(SELECTOR, lambda: {'ok': True})
        self.assertTrue(f.client.action_blocked)

    def test_confirmed_action_allows_next_action_with_fresh_query(self):
        f = Fake([reply([{'ELEMENT': 'old'}]), reply(), reply([{'ELEMENT': 'new'}]), reply()])
        f.client.click_unique(SELECTOR, lambda: True)
        f.client.click_unique(SELECTOR, lambda: True)
        self.assertEqual([r for r, _ in f.calls],
                         ['/elements', '/element/old/click', '/elements', '/element/new/click'])

    def test_error_trace_does_not_contain_raw_message_selector_or_element_id(self):
        f = Fake([STALE, reply([{'ELEMENT': 'PRIVATE_ID'}]), STALE])
        with self.assertRaises(ActionUnconfirmed):f.client.click_unique(SELECTOR, lambda: True)
        trace = json.dumps(f.events, ensure_ascii=False)
        self.assertNotIn('PRIVATE_', trace)
        self.assertNotIn('暂停', trace)

    def test_malformed_envelopes_are_rejected(self):
        for raw in [b'[]', b'{}', b'null', b'bad', b'\xff']:
            with self.subTest(raw=raw), self.assertRaises(ProtocolError):
                decode_reply(Reply(200, raw))

    def test_unknown_error_text_is_not_printed(self):
        with self.assertRaises(WDAResponseError) as caught:
            decode_reply(reply({'error': 'PRIVATE_DATA', 'message': 'PRIVATE_TREE'}, 404))
        self.assertNotIn('PRIVATE_', str(caught.exception))

    def test_retry_budget_is_finite_and_cannot_be_bool(self):
        for count in [0, 4, True, 1.5]:
            with self.subTest(count=count), self.assertRaises(ValueError):
                GuardedWDA(lambda *_: None, lambda: 'scene', read_attempts=count)


class ObservationAgeTests(unittest.TestCase):
    def make(self):
        f = Fake([reply([{'ELEMENT': 'current'}]), reply()])
        f.now = 0.0
        f.client.clock = lambda: f.now
        return f

    def test_slow_selection_is_rejected_before_properties_or_click(self):
        f = self.make(); original = f.client.send; validated = []
        def slow(route, body):
            result = original(route, body); f.now = 1.1; return result
        f.client.send = slow
        with self.assertRaises(ObservationExpired):
            f.client.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=1,
                                  validate_target=lambda key: validated.append(key))
        self.assertEqual([r for r, _ in f.calls], ['/elements'])
        self.assertEqual(validated, [])
        self.assertFalse(f.client.action_blocked)

    def test_stale_query_retries_share_the_original_age_budget(self):
        f = Fake([STALE, reply([{'ELEMENT': 'current'}])]); f.now = 0
        f.client.clock = lambda: f.now; original = f.client.send
        def slow(route, body):
            result = original(route, body); f.now += .6; return result
        f.client.send = slow
        with self.assertRaises(ObservationExpired):
            f.client.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=1)
        self.assertEqual([r for r, _ in f.calls], ['/elements', '/elements'])

    def test_target_validation_delay_counts_toward_age(self):
        f = self.make()
        def validate(key):
            self.assertEqual(key, 'current'); f.now = 1; return True
        with self.assertRaises(ObservationExpired):
            f.client.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=1,
                                  validate_target=validate)
        self.assertEqual(len(f.calls), 1)

    def test_scene_check_delay_counts_toward_age(self):
        f = self.make(); calls = []
        def scene():
            calls.append(1)
            if len(calls) == 3:f.now = 1
            return 'same'
        f.client.live_scene = scene
        with self.assertRaises(ObservationExpired):
            f.client.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=1)
        self.assertEqual(len(f.calls), 1)

    def test_slow_recorder_cannot_dispatch_an_expired_selection(self):
        f = self.make()
        def record(event):
            f.events.append(event)
            if event.get('state') == 'sendingOnce':f.now = 1.01
        f.client.record = record
        with self.assertRaises(ObservationExpired):
            f.client.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=1)
        self.assertEqual(len(f.calls), 1)
        self.assertFalse(f.client.action_blocked)
        self.assertEqual(f.events[-1]['state'], 'observationExpiredBeforeDispatch')

    def test_disabled_or_unknown_target_validation_sends_no_action(self):
        for value in [False, None, 1, {'displayed': True}]:
            f = self.make()
            with self.subTest(value=value), self.assertRaises(SelectionError):
                f.client.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=1,
                                      validate_target=lambda key: value)
            self.assertEqual(len(f.calls), 1)

    def test_validation_error_sends_no_action(self):
        f = self.make()
        def validate(key):raise TimeoutError('private target')
        with self.assertRaises(TimeoutError):
            f.client.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=1,
                                  validate_target=validate)
        self.assertEqual(len(f.calls), 1)
        self.assertFalse(f.client.action_blocked)

    def test_fresh_action_still_requires_independent_effect_and_never_replays(self):
        f = self.make()
        with self.assertRaises(ActionUnconfirmed):
            f.client.click_unique(SELECTOR, lambda: False, max_observation_age_seconds=1,
                                  validate_target=lambda key: True)
        with self.assertRaises(ActionUnconfirmed):
            f.client.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=1)
        self.assertEqual([r for r, _ in f.calls], ['/elements', '/element/current/click'])

    def test_fresh_action_with_confirmed_effect_can_complete(self):
        f = self.make()
        def validate(key):f.now = .25; return True
        f.client.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=1,
                              validate_target=validate)
        self.assertFalse(f.client.action_blocked)
        self.assertEqual(len(f.calls), 2)
        dispatched = next(e for e in f.events if e.get('state') == 'responseReceivedEffectUnknown')
        self.assertEqual(dispatched['selectionAgeAtDispatchSeconds'], .25)
        self.assertEqual(dispatched['maximumObservationAgeSeconds'], 1)

    def test_invalid_budget_is_rejected_before_any_io(self):
        for value in [True, 0, -1, 2.01, float('inf'), float('nan'), '1']:
            f = self.make()
            with self.subTest(value=value), self.assertRaises(ValueError):
                f.client.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=value)
            self.assertEqual(f.calls, [])

    def test_invalid_clock_age_is_rejected_before_dispatch(self):
        for value in [-1, float('inf'), float('nan')]:
            f = self.make(); original = f.client.send
            def query(route, body):
                result = original(route, body); f.now = value; return result
            f.client.send = query
            with self.subTest(value=value), self.assertRaises(ObservationExpired):
                f.client.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=1)
            self.assertEqual(len(f.calls), 1)


if __name__ == '__main__':unittest.main()
