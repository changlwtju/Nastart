import asyncio
from pathlib import Path
import tempfile
import unittest
from unittest.mock import AsyncMock, patch
from types import SimpleNamespace

import discover_paired_wireless_device as discovery


class DiscoveryTests(unittest.TestCase):
    def test_removed_instance_and_other_interface_are_distinct(self):
        self.assertEqual(discovery.current_instances(
            '10:00 Add 2 11 local. _apple-mobdev2._tcp. renamed supportsRP-3\n'
            '10:00 Add 2 12 local. _apple-mobdev2._tcp. renamed supportsRP-3\n'
            '10:01 Rmv 2 11 local. _apple-mobdev2._tcp. renamed supportsRP-3\n'
            '10:01 Add 2 11 local. _apple-mobdev2._tcp. gone\n'
            '10:02 Rmv 2 11 local. _apple-mobdev2._tcp. gone\n'),
            ['renamed supportsRP-3'])

    def test_current_names_do_not_bypass_identity_verification(self):
        async def verify(config, output):
            if config['bonjourInstance'] == 'wrong-device':
                raise RuntimeError('wrong live identity')
            (output / 'verified-endpoint-private.json').write_text('verified endpoint')
            (output / 'device-values-private.json').write_text('verified identity')
            return {'identityMatches': True, 'paired': True}
        with tempfile.TemporaryDirectory() as directory, patch.object(
                discovery, 'bounded_dns', return_value='browser'), patch.object(
                discovery, 'current_instances', return_value=['wrong-device', 'changed-name']), patch.object(
                discovery, 'discover', AsyncMock(side_effect=verify)) as check:
            result = asyncio.run(discovery.discover_current(
                {'udid': 'intended', 'bonjourInstance': 'old-name'}, Path(directory)))
            self.assertTrue(result['identityMatches'])
            self.assertEqual(result['currentAdvertisementsChecked'], 2)
            self.assertEqual([call.args[0]['udid'] for call in check.await_args_list],
                             ['intended', 'intended'])
            self.assertTrue((Path(directory) / 'current-instance-0/failure-private.log').exists())

    def test_excess_advertisements_stop_before_device_requests(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(
                discovery, 'bounded_dns', return_value='browser'), patch.object(
                discovery, 'current_instances', return_value=['a', 'b', 'c', 'd', 'e']), patch.object(
                discovery, 'discover', AsyncMock()) as check:
            with self.assertRaises(RuntimeError):
                asyncio.run(discovery.discover_current({'udid': 'intended'}, Path(directory)))
            check.assert_not_awaited()

    def test_service_and_current_address_parsing(self):
        self.assertEqual(discovery.service_endpoint(
            'target can be reached at phone.local.:32498 (interface 11)'),
            ('phone.local.', 32498, 11))
        self.assertEqual(discovery.ipv4_addresses(
            '07:00 Add 2 11 phone.local. 192.0.2.7 120\n'
            '07:01 Rmv 2 11 phone.local. 192.0.2.8 0\n'
            '07:01 Add 2 11 phone.local. fe80::123 120\n'), ['192.0.2.7'])

    def test_reachable_wrong_device_never_accepted(self):
        client = SimpleNamespace(udid='other-device', paired=True, close=AsyncMock())
        with tempfile.TemporaryDirectory() as directory, patch(
                'pymobiledevice3.lockdown.create_using_tcp', AsyncMock(return_value=client)):
            with self.assertRaises(RuntimeError):
                asyncio.run(discovery.verify_candidates(
                    ['192.0.2.7'], 32498, 'intended-device', {}, Path(directory)))
            self.assertFalse((Path(directory) / 'verified-endpoint-private.json').exists())
            self.assertEqual(client.close.await_count, 2)

    def test_standard_port_fallback_requires_paired_target(self):
        client = SimpleNamespace(udid='intended-device', paired=True,
                                 product_type='test-model', all_values={}, close=AsyncMock())
        connect = AsyncMock(side_effect=[TimeoutError(), client])
        with tempfile.TemporaryDirectory() as directory, patch(
                'pymobiledevice3.lockdown.create_using_tcp', connect):
            result = asyncio.run(discovery.verify_candidates(
                ['192.0.2.7'], 32498, 'intended-device', {}, Path(directory)))
            self.assertEqual(result['verifiedPort'], 62078)
            self.assertTrue(result['identityMatches'])
            self.assertTrue(all(call.kwargs['autopair'] is False
                                for call in connect.await_args_list))
            self.assertEqual([call.args[0] for call in connect.await_args_list],
                             ['192.0.2.7', '192.0.2.7'])


if __name__ == '__main__':
    unittest.main()
