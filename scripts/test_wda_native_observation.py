import copy
import json
import re
import unittest

from wda_command_guard import ProtocolError, SceneChanged, WDAResponseError
from test_wda_usb_session import Wire, wire_response


class NativeObservationTests(unittest.TestCase):
    def make(self):
        w = Wire(); original = w.respond
        w.targets = {'PIP-SBInteractionPassThroughView': 'container', '暂停': 'pause',
                     '关闭画中画': 'close', '恢复全屏幕': 'restore'}
        w.properties = {key: {'displayed': True, 'enabled': True,
            'rect': dict(x=x,y=y,width=width,height=height)} for key,x,y,width,height in [
                ('container',10,20,270,152), ('pause',130,80,30,30),
                ('close',20,25,24,24), ('restore',220,25,24,24)]}
        def respond(method, path, body):
            if path.endswith('/elements'):
                name = json.loads(body['value'].split('name == ',1)[1]);key = w.targets.get(name)
                return wire_response([] if key is None else key if isinstance(key,list) else [{'ELEMENT':key}])
            match = re.search(r'/element/([^/]+)/(displayed|enabled|rect)$', path)
            if match:
                result = w.properties[match[1]][match[2]]
                return result if isinstance(result,bytes) else wire_response(result)
            return original(method,path,body)
        w.respond = respond
        return w

    def test_targeted_native_state_uses_properties_png_and_no_source_or_action(self):
        w = self.make();private=[];observation=w.session.observe_native_pip(private.append)
        self.assertEqual(observation.button_count('暂停'),1)
        self.assertEqual(observation.button_count('播放'),0)
        self.assertEqual(len(observation.controls),3)
        self.assertTrue(private)
        self.assertFalse(any('/source' in path or path.endswith('/click') for _,path,_ in w.calls))
        self.assertEqual(observation.private_summary()['provenance'], 'targeted WDA element reads; not a full UI source')
        self.assertTrue(all(c.closed for c in w.connections))

    def test_no_unique_container_or_ambiguous_control_never_creates_observation(self):
        for name,value in [('PIP-SBInteractionPassThroughView',None),
                           ('暂停',[{'ELEMENT':'a'},{'ELEMENT':'b'}])]:
            w=self.make();w.targets[name]=value
            with self.assertRaises(ProtocolError):w.session.observe_native_pip(lambda row:None)
            self.assertEqual(w.clicks(),[])

    def test_displayed_disabled_and_missing_are_distinct(self):
        w=self.make();w.properties['pause']['enabled']=False
        observation=w.session.observe_native_pip(lambda row:None)
        self.assertEqual(observation.button_count('暂停'),0)
        self.assertEqual(observation.button_count('暂停',visible_only=False),1)
        self.assertEqual(observation.button_count('播放',visible_only=False),0)

    def test_unknown_boolean_or_invalid_rect_is_rejected(self):
        for field,value in [('displayed','true'),('enabled',1),('rect',{}),
                            ('rect',dict(x=1,y=2,width=float('nan'),height=4))]:
            w=self.make();w.properties['pause'][field]=value
            with self.assertRaises(ProtocolError):w.session.observe_native_pip(lambda row:None)

    def test_control_outside_current_pip_container_is_rejected(self):
        w=self.make();w.properties['pause']['rect']['x']=999
        with self.assertRaises(ProtocolError):w.session.observe_native_pip(lambda row:None)

    def test_stale_property_read_is_not_retried(self):
        w=self.make();w.properties['pause']['displayed']=wire_response({'error':'stale element reference'},404)
        with self.assertRaises(WDAResponseError):w.session.observe_native_pip(lambda row:None)
        calls=[p for _,p,_ in w.calls if p.endswith('/element/pause/displayed')]
        self.assertEqual(len(calls),1)
        self.assertEqual(w.clicks(),[])

    def test_scene_change_during_properties_is_rejected(self):
        w=self.make();original=w.respond
        def respond(method,path,body):
            response=original(method,path,body)
            if path.endswith('/element/pause/rect'):w.foreground['pid']=456
            return response
        w.respond=respond
        with self.assertRaises(SceneChanged):w.session.observe_native_pip(lambda row:None)

    def test_private_recorder_failure_prevents_target_query_and_closes_reads(self):
        w=self.make()
        def fail(row):raise OSError('private storage unavailable')
        with self.assertRaises(OSError):w.session.observe_native_pip(fail)
        self.assertEqual(w.queries(),[])
        self.assertTrue(all(c.closed for c in w.connections))

    def test_unexpected_target_or_no_private_recorder_stops_before_io(self):
        w=self.make();w.session.expected_bundle='other.bundle'
        with self.assertRaises(ValueError):w.session.observe_native_pip(lambda row:None)
        w.session.expected_bundle='com.apple.springboard'
        with self.assertRaises(ValueError):w.session.observe_native_pip(None)
        self.assertEqual(w.calls,[])

    def test_targeted_ui_transition_uses_new_targeted_observation(self):
        w=self.make();w.targets={'PIP-SBInteractionPassThroughView':'container'};before=w.session.observe_native_pip(lambda row:None)
        verifier=w.session.ui_transition_verifier(before,appeared=['暂停'],disappeared=[],
                    save_private=lambda ui:None,native_private_recorder=lambda row:None)
        w.targets['暂停']='pause';w.png+=b'changed'
        self.assertTrue(verifier())
        self.assertFalse(any('/source' in path for _,path,_ in w.calls))


if __name__=='__main__':unittest.main()
