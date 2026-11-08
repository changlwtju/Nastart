import base64
import io
import json
import unittest

from wda_command_guard import (ActionUnconfirmed, ObservationExpired, ProtocolError,
                               SceneChanged, WDAResponseError)
from wda_usb_session import (FAST_SOURCE_ROUTE, OrientationChanged, Scene,
                             UIObservation, USBSession, USBTransport)


SELECTOR = {'using': 'predicate string', 'value': 'name == "暂停"'}
PNG = b'\x89PNG\r\n\x1a\n'
STALE = {'error': 'stale element reference', 'message': 'PRIVATE_SYSTEM_TREE'}


def wire_response(value, status=200, session='test-session'):
    body = json.dumps({'value': value, 'sessionId': session}, ensure_ascii=False).encode()
    return (f'HTTP/1.1 {status} Reply\r\nContent-Length: {len(body)}\r\n'
            'Connection: close\r\n\r\n').encode() + body


def source(*names):
    return '<App>' + ''.join('<XCUIElementTypeButton name="' + n
        + '" visible="true" enabled="true"/>' for n in names) + '</App>'


class Socket:
    def __init__(self, wire): self.wire = wire
    def settimeout(self, value): self.wire.timeouts.append(value)
    def sendall(self, data): self.data = data
    def makefile(self, *args):
        header, body = self.data.split(b'\r\n\r\n', 1)
        lines = header.decode().split('\r\n')
        method, path, _ = lines[0].split(' ')
        size = int(next(x.split(': ')[1] for x in lines if x.startswith('Content-Length:')))
        if size != len(body): raise AssertionError('Content length is not byte length')
        call = (method, path, None if method == 'GET' else json.loads(body))
        self.wire.calls.append(call)
        result = self.wire.respond(*call)
        if isinstance(result, Exception):
            class FailingReader(io.BytesIO):
                def readline(self, *args): raise result
            return FailingReader()
        return io.BytesIO(result)


class Connection:
    def __init__(self, wire): self.wire, self.closed = wire, False
    def get_socket(self): return Socket(self.wire)
    def close(self): self.closed = True


class Wire:
    def __init__(self):
        self.calls, self.connections, self.timeouts = [], [], []
        self.elements = [[{'ELEMENT': 'fresh-element'}]]
        self.click = wire_response(None)
        self.settings = {'defaultActiveApplication': 'auto'}
        self.foreground = {'bundleId': 'com.apple.springboard', 'pid': 123}
        self.orientation = 'PORTRAIT'
        self.xml, self.png = source(), PNG + b'before-fixture'
        self.after_click = lambda: None
        self.clock_value = 0
        self.transport = USBTransport(self.connect)
        self.session = USBSession(self.transport, 'test-session', 'com.apple.springboard', 123,
                                  clock=self.clock)
        self.guard = self.session.guard()

    def clock(self):
        self.clock_value += 1
        return self.clock_value

    def connect(self):
        connection = Connection(self)
        self.connections.append(connection)
        return connection

    def respond(self, method, path, body):
        if path.endswith('/appium/settings'): return wire_response(self.settings)
        if path.endswith('/wda/activeAppInfo'): return wire_response(self.foreground)
        if path.endswith('/orientation'): return wire_response(self.orientation)
        if path.endswith('/elements'):
            value = self.elements.pop(0)
            return value if isinstance(value, (bytes, Exception)) else wire_response(value)
        if path.endswith('/click'):
            self.after_click()
            return self.click
        if path.endswith('/source'): return wire_response(self.xml)
        if path.endswith('/screenshot'): return wire_response(base64.b64encode(self.png).decode())
        raise AssertionError('Unexpected route')

    def clicks(self): return [c for c in self.calls if c[1].endswith('/click')]
    def queries(self): return [c for c in self.calls if c[1].endswith('/elements')]


class USBIntegrationTests(unittest.TestCase):
    def assert_closed(self, wire):
        self.assertTrue(wire.connections)
        self.assertTrue(all(c.closed for c in wire.connections))

    def test_raw_404_survives_usb_and_only_query_is_retried(self):
        w = Wire()
        w.elements = [wire_response(STALE, 404), []]
        self.assertEqual(w.guard.query_elements(SELECTOR), [])
        self.assertEqual(len(w.queries()), 2)
        self.assertEqual(len(w.clicks()), 0)
        self.assertEqual(w.queries()[0][2], SELECTOR)
        self.assertTrue(all(t == 15 for t in w.timeouts))
        self.assert_closed(w)

    def test_session_guard_uses_the_bound_clock_for_selection_expiry(self):
        w = Wire()
        with self.assertRaises(ObservationExpired):
            w.guard.click_unique(SELECTOR, lambda: True, max_observation_age_seconds=2)
        self.assertEqual((len(w.queries()), len(w.clicks())), (1, 0))
        self.assertFalse(w.guard.action_blocked)
        self.assert_closed(w)

    def test_explicit_post_rotation_read_keeps_bound_owner_and_sends_no_action(self):
        for old, target in [('LANDSCAPE', 'PORTRAIT'), ('PORTRAIT', 'LANDSCAPE')]:
            with self.subTest(old=old, target=target):
                w = Wire(); w.orientation = target
                before = Scene('test-session', 'com.apple.springboard', 123, old)
                observed = w.session.observe_ui_after_rotation(before, target)
                self.assertEqual(observed.scene.orientation, target)
                self.assertEqual((observed.scene.bundle, observed.scene.pid), (before.bundle, before.pid))
                self.assertEqual((len(w.queries()), len(w.clicks())), (0, 0))
                self.assert_closed(w)

    def test_rotation_read_rejects_unknown_owner_or_no_explicit_orientation_change(self):
        for scene, target in [
                (Scene('other', 'com.apple.springboard', 123, 'LANDSCAPE'), 'PORTRAIT'),
                (Scene('test-session', 'other.bundle', 123, 'LANDSCAPE'), 'PORTRAIT'),
                (Scene('test-session', 'com.apple.springboard', 456, 'LANDSCAPE'), 'PORTRAIT'),
                (Scene('test-session', 'com.apple.springboard', 123, 'PORTRAIT'), 'PORTRAIT'),
                (Scene('test-session', 'com.apple.springboard', 123, 'LANDSCAPE'), 'UNKNOWN')]:
            w = Wire()
            with self.subTest(scene=scene, target=target), self.assertRaises(ValueError):
                w.session.observe_ui_after_rotation(scene, target)
            self.assertEqual(w.calls, [])

    def test_unsettled_rotation_sends_no_source_screenshot_or_action(self):
        w = Wire(); w.orientation = 'LANDSCAPE'
        before = Scene('test-session', 'com.apple.springboard', 123, 'LANDSCAPE')
        with self.assertRaises(OrientationChanged):
            w.session.observe_ui_after_rotation(before, 'PORTRAIT')
        self.assertFalse(any(path.endswith(('/source', '/screenshot', '/click')) for _, path, _ in w.calls))

    def test_rotation_during_capture_is_classified_without_automatic_retry(self):
        w = Wire(); original = w.respond
        def respond(method, path, body):
            result = original(method, path, body)
            if path.endswith('/source'):w.orientation = 'LANDSCAPE'
            return result
        w.respond = respond
        before = Scene('test-session', 'com.apple.springboard', 123, 'LANDSCAPE')
        with self.assertRaises(OrientationChanged):
            w.session.observe_ui_after_rotation(before, 'PORTRAIT')
        self.assertEqual(sum(path.endswith('/source') for _, path, _ in w.calls), 1)
        self.assertEqual(w.clicks(), [])

    def test_rotation_read_cannot_accept_a_changed_pid_or_pinned_target(self):
        for changed in ['pid', 'bundle', 'pinned']:
            w = Wire()
            if changed == 'pid':w.foreground['pid'] = 456
            elif changed == 'bundle':w.foreground['bundleId'] = 'other.bundle'
            else:w.settings['defaultActiveApplication'] = 'com.apple.springboard'
            before = Scene('test-session', 'com.apple.springboard', 123, 'LANDSCAPE')
            with self.subTest(changed=changed), self.assertRaises(SceneChanged):
                w.session.observe_ui_after_rotation(before, 'PORTRAIT')
            self.assertEqual(w.clicks(), [])

    def test_rotation_read_rejects_a_second_change_before_capture_starts(self):
        w = Wire(); original = w.respond; reads = []
        def respond(method, path, body):
            if path.endswith('/orientation'):
                reads.append(1)
                if len(reads) > 1:w.orientation = 'LANDSCAPE'
            return original(method, path, body)
        w.respond = respond
        before = Scene('test-session', 'com.apple.springboard', 123, 'LANDSCAPE')
        with self.assertRaises(OrientationChanged):
            w.session.observe_ui_after_rotation(before, 'PORTRAIT')
        self.assertEqual(w.clicks(), [])

    def test_action_404_never_reselects_or_resends(self):
        w = Wire(); w.click = wire_response(STALE, 404)
        for _ in range(2):
            with self.assertRaises(ActionUnconfirmed):w.guard.click_unique(SELECTOR, lambda: True)
        self.assertEqual((len(w.queries()), len(w.clicks())), (1, 1))
        self.assert_closed(w)

    def test_action_timeout_after_send_blocks_more_actions(self):
        w = Wire(); w.click = TimeoutError('PRIVATE_TRANSPORT_CONTEXT')
        with self.assertRaises(ActionUnconfirmed):w.guard.click_unique(SELECTOR, lambda: True)
        with self.assertRaises(ActionUnconfirmed):w.guard.click_unique(SELECTOR, lambda: True)
        self.assertEqual(len(w.clicks()), 1)
        self.assert_closed(w)

    def test_read_timeout_is_not_retried_and_connection_closes(self):
        w = Wire(); w.elements = [TimeoutError('PRIVATE_TRANSPORT_CONTEXT')]
        with self.assertRaises(TimeoutError):w.guard.query_elements(SELECTOR)
        self.assertEqual(len(w.queries()), 1)
        self.assert_closed(w)

    def test_bad_http_response_still_closes_connection(self):
        w = Wire(); w.elements = [b'not an HTTP response\r\n']
        with self.assertRaises(Exception):w.guard.query_elements(SELECTOR)
        self.assert_closed(w)

    def test_utf8_body_uses_byte_length(self):
        w = Wire(); w.guard.query_elements(SELECTOR)
        self.assertEqual(w.queries()[0][2], SELECTOR)

    def test_invalid_session_or_path_never_opens_connection(self):
        w = Wire()
        for sid in ['', '../other', 'id\r\nInjected']:
            with self.assertRaises(ValueError):USBSession(w.transport, sid, 'bundle', 1)
        for path in ['/session/x/../click', '/a\r\nHost: bad', '//a', '/a%2fb']:
            with self.assertRaises(ValueError):w.transport.request(path)
        self.assertEqual(w.connections, [])

    def test_adapter_rejects_mutations_outside_guard_routes(self):
        w = Wire()
        for route, data in [('/wda/apps/activate', {}), ('/appium/settings', {}),
                            ('/orientation', {'orientation': 'LANDSCAPE'}), ('/session', {})]:
            with self.assertRaises(ValueError):w.session.send(route, data)
        self.assertEqual(w.connections, [])

    def test_pinned_active_app_cannot_masquerade_as_foreground(self):
        w = Wire(); w.settings['defaultActiveApplication'] = 'com.apple.springboard'
        with self.assertRaises(SceneChanged):w.guard.query_elements(SELECTOR)
        self.assertEqual(len(w.queries()), 0)

    def test_wrong_bundle_pid_or_orientation_blocks_selection(self):
        for field, value in [('bundleId', 'other.bundle'), ('pid', 456), ('pid', True)]:
            w = Wire(); w.foreground[field] = value
            with self.subTest(field=field), self.assertRaises(SceneChanged):
                w.guard.query_elements(SELECTOR)
            self.assertEqual(w.queries(), [])
        w = Wire(); w.orientation = 'UNKNOWN'
        with self.assertRaises(ProtocolError):w.guard.query_elements(SELECTOR)
        self.assertEqual(w.queries(), [])

    def test_scene_change_after_query_prevents_click(self):
        w = Wire()
        original = w.respond
        def respond(method, path, body):
            response = original(method, path, body)
            if path.endswith('/elements'):w.orientation = 'LANDSCAPE'
            return response
        w.respond = respond
        with self.assertRaises(SceneChanged):w.guard.click_unique(SELECTOR, lambda: True)
        self.assertEqual(w.clicks(), [])

    def test_response_session_mismatch_cannot_be_accepted(self):
        w = Wire(); w.elements = [wire_response([], session='another-session')]
        with self.assertRaises(SceneChanged):w.guard.query_elements(SELECTOR)
        self.assertEqual(len(w.queries()), 1)

    def test_actual_ui_transition_uses_new_source_image_and_scene(self):
        w = Wire(); before = w.session.observe_ui(); saved = []
        verify = w.session.ui_transition_verifier(before, appeared=['播放'], disappeared=[],
                                                 save_private=saved.append)
        def change():w.xml, w.png = source('播放'), PNG + b'after-fixture'
        w.after_click = change
        w.guard.click_unique(SELECTOR, verify)
        self.assertFalse(w.guard.action_blocked)
        self.assertEqual(len(saved), 1)
        self.assertEqual(saved[0].button_count('播放'), 1)
        self.assertGreater(saved[0].started, before.finished)
        self.assertNotIn('after-fixture', repr(saved[0]))
        self.assert_closed(w)

    def test_http200_unchanged_ui_is_not_effect_confirmation(self):
        w = Wire(); before = w.session.observe_ui()
        verify = w.session.ui_transition_verifier(before, appeared=['播放'], disappeared=[],
                                                 save_private=lambda observation: None)
        with self.assertRaises(ActionUnconfirmed):w.guard.click_unique(SELECTOR, verify)
        with self.assertRaises(ActionUnconfirmed):w.guard.click_unique(SELECTOR, verify)
        self.assertEqual(len(w.clicks()), 1)

    def test_changed_tree_without_changed_image_remains_unconfirmed(self):
        w = Wire(); before = w.session.observe_ui()
        verify = w.session.ui_transition_verifier(before, appeared=['播放'], disappeared=[],
                                                 save_private=lambda observation: None)
        w.after_click = lambda: setattr(w, 'xml', source('播放'))
        with self.assertRaises(ActionUnconfirmed):w.guard.click_unique(SELECTOR, verify)
        self.assertTrue(w.guard.action_blocked)

    def test_bad_screenshot_or_scene_change_during_observation_rejects(self):
        w = Wire(); w.png = b'not PNG'
        with self.assertRaises(ProtocolError):w.session.observe_ui()
        w = Wire(); original = w.respond
        def respond(method, path, body):
            response = original(method, path, body)
            if path.endswith('/screenshot'):w.foreground['pid'] = 456
            return response
        w.respond = respond
        with self.assertRaises(SceneChanged):w.session.observe_ui()

    def test_effect_save_failure_blocks_next_action(self):
        w = Wire(); before = w.session.observe_ui()
        def failed_save(observation):raise OSError('private disk unavailable')
        verify = w.session.ui_transition_verifier(before, appeared=['播放'], disappeared=[],
                                                 save_private=failed_save)
        def change():w.xml, w.png = source('播放'), PNG + b'after-fixture'
        w.after_click = change
        with self.assertRaises(ActionUnconfirmed):w.guard.click_unique(SELECTOR, verify)
        self.assertTrue(w.guard.action_blocked)

    def test_ui_verifier_cannot_be_reused_for_another_action(self):
        w = Wire(); before = w.session.observe_ui()
        verify = w.session.ui_transition_verifier(before, appeared=['播放'], disappeared=[],
                                                 save_private=lambda observation: None)
        def change():w.xml, w.png = source('播放'), PNG + b'after-fixture'
        w.after_click = change
        w.guard.click_unique(SELECTOR, verify)
        calls = len(w.calls)
        with self.assertRaises(ProtocolError):verify()
        self.assertEqual(len(w.calls), calls)

    def test_private_reply_saver_receives_raw_error_and_failure_closes_connection(self):
        w = Wire(); raw = wire_response(STALE, 404); w.elements = [raw]
        saved = []
        w.transport.save_reply = saved.append
        from wda_command_guard import decode_reply
        with self.assertRaises(WDAResponseError):decode_reply(w.session.send('/elements', SELECTOR))
        self.assertEqual(saved[0].body, raw.split(b'\r\n\r\n', 1)[1])
        self.assertEqual(saved[0].status, 404)
        self.assert_closed(w)
        w = Wire()
        def failed_save(reply):raise OSError('private disk unavailable')
        w.transport.save_reply = failed_save
        with self.assertRaises(OSError):w.guard.query_elements(SELECTOR)
        self.assertEqual(len(w.queries()), 0)
        self.assert_closed(w)

    def test_navigation_source_preserves_existing_fixed_fast_query(self):
        w = Wire(); original = w.respond
        xml = '<App><XCUIElementTypeButton name="播放" enabled="true"/></App>'
        def respond(method, path, body):
            return wire_response(xml) if path.endswith(FAST_SOURCE_ROUTE) else original(method, path, body)
        w.respond = respond
        self.assertEqual(w.session.read_navigation_source(), xml)
        self.assertEqual([c[:2] for c in w.calls if c[1].endswith(FAST_SOURCE_ROUTE)],
                         [('GET', '/session/test-session' + FAST_SOURCE_ROUTE)])
        observation = UIObservation(w.session.live_scene(), 1, 2, xml, PNG)
        self.assertEqual(observation.button_count('播放'), 0, 'Missing visibility is not proof of visible UI')
        self.assertEqual(observation.button_count('播放', visible_only=False), 1)
        self.assert_closed(w)

    def test_fast_query_does_not_open_arbitrary_queries_or_mutations(self):
        w = Wire()
        for path in ['/session/x/source?foo=bar', '/session/x/source?excluded_attributes=visible',
                     '/session/x/source?excluded_attributes=visible,accessible,traits&foo=bar',
                     '/wda/apps/terminate?excluded_attributes=visible,accessible,traits',
                     '/session/x/source?excluded_attributes=visible,accessible,traits\r\nInjected']:
            with self.assertRaises(ValueError):w.transport.request(path)
        with self.assertRaises(ValueError):w.transport.request('/session/x' + FAST_SOURCE_ROUTE, {})
        with self.assertRaises(ValueError):w.session.send(FAST_SOURCE_ROUTE, {})
        self.assertEqual(w.connections, [])

    def test_navigation_source_requires_valid_xml_without_retry(self):
        for invalid in [None, '<App>']:
            w = Wire();original = w.respond
            w.respond = lambda method,path,body: wire_response(invalid) if path.endswith(FAST_SOURCE_ROUTE) else original(method,path,body)
            with self.assertRaises(ProtocolError):w.session.read_navigation_source()
            self.assertEqual(sum(path.endswith(FAST_SOURCE_ROUTE) for _,path,_ in w.calls), 1)
            self.assert_closed(w)

    def test_native_ui_observation_keeps_full_visibility_source(self):
        w = Wire();w.session.observe_ui()
        sources = [path for _,path,_ in w.calls if '/source' in path]
        self.assertEqual(sources, ['/session/test-session/source'])

    def test_navigation_read_rejects_foreground_change_during_source(self):
        w = Wire();original = w.respond
        def respond(method, path, body):
            if path.endswith(FAST_SOURCE_ROUTE):
                w.foreground['pid'] = 456
                return wire_response('<App/>')
            return original(method, path, body)
        w.respond = respond
        with self.assertRaises(SceneChanged):w.session.read_navigation_source()


if __name__ == '__main__':unittest.main()
