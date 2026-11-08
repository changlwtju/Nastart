import asyncio
import hashlib
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
import zipfile
from unittest.mock import AsyncMock, Mock, patch

import install_paired_wireless_app as update
from pymobiledevice3.lockdown import LockdownClient


class WirelessUpdateTests(unittest.TestCase):
    def test_clean_ipa_members_are_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            ipa = Path(directory) / 'clean.ipa'
            with zipfile.ZipFile(ipa, 'w') as archive:
                archive.writestr('Payload/Nastart.app/Info.plist', b'info')
                archive.writestr('Payload/Nastart.app/_CodeSignature/CodeResources', b'signature')
            with zipfile.ZipFile(ipa) as archive:
                update.verify_ipa_members(archive)

    def test_appledouble_and_macosx_entries_are_rejected(self):
        for extra in ('Payload/._Nastart.app',
                      'Payload/Nastart.app/Frameworks/._KSPlayer.framework',
                      '__MACOSX/Payload/Nastart.app/Info.plist'):
            with self.subTest(extra=extra), tempfile.TemporaryDirectory() as directory:
                ipa = Path(directory) / 'dirty.ipa'
                with zipfile.ZipFile(ipa, 'w') as archive:
                    archive.writestr('Payload/Nastart.app/Info.plist', b'info')
                    archive.writestr(extra, b'metadata')
                with zipfile.ZipFile(ipa) as archive:
                    with self.assertRaisesRegex(ValueError, 'Mac metadata'):
                        update.verify_ipa_members(archive)

    def test_existing_escrow_keeps_legacy_service_name(self):
        client = Mock(spec=LockdownClient)
        client.pair_record = {'EscrowBag': b'existing-host-authorization'}
        async def make_service():
            return update.PairedHouseArrestService(client)
        service = asyncio.run(make_service())
        self.assertEqual(service.service_name, update.HouseArrestService.SERVICE_NAME)
        self.assertTrue(service._include_escrow_bag)
        self.assertIs(service.lockdown, client)

    def test_rsd_service_name_and_authentication_remain_distinct(self):
        client = SimpleNamespace()
        async def make_service():
            return update.PairedHouseArrestService(client)
        service = asyncio.run(make_service())
        self.assertEqual(service.service_name, update.HouseArrestService.RSD_SERVICE_NAME)
        self.assertFalse(service._include_escrow_bag)
        self.assertIs(service.lockdown, client)

    def test_preference_comparison_preserves_bookmarks_and_missing_keys(self):
        self.assertTrue(update.compare_preferences(
            {'diagnostics.old': 'a', 'login': 'x', 'playback.localResume.v1': b'a'},
            {'diagnostics.new': 'b', 'login': 'x', 'playback.localResume.v1': b'a'}
        )['allNonDiagnosticPreferencesEqual'])
        changed = update.compare_preferences({'login': 'x', 'bookmark': b'a'},
                                             {'login': 'x', 'bookmark': b'b', 'extra': 1})
        self.assertFalse(changed['sameKeys'])
        self.assertFalse(changed['allNonDiagnosticPreferencesEqual'])
        self.assertEqual(changed['changedValues'], 1)
        self.assertFalse(update.compare_preferences({'login': 'x'}, {})['sameKeys'])

    def test_changed_source_fails_before_signing_or_device_access(self):
        with tempfile.TemporaryDirectory() as directory:
            f = Path(directory) / 'input.swift'
            f.write_text('new content')
            with patch.object(update.subprocess, 'check_output') as command:
                with self.assertRaisesRegex(ValueError, 'Source input changed'):
                    update.verify_package({}, {str(f): hashlib.sha256(b'old').hexdigest()}, 'target')
                command.assert_not_called()

    def test_backup_failure_prevents_any_install_service(self):
        result = {}
        with tempfile.TemporaryDirectory() as directory, patch.object(
                update, 'read_preferences', AsyncMock(side_effect=ConnectionError())), patch.object(
                update, 'InstallationProxyService') as proxy:
            with self.assertRaises(ConnectionError):
                asyncio.run(update.install(object(), {}, {}, 'target', Path(directory),
                                           result, lambda: None))
            proxy.assert_not_called()
            self.assertNotIn('installCommandSent', result)

    def test_source_change_during_backup_prevents_upload(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(
                update, 'read_preferences', AsyncMock(return_value={})), patch.object(
                update, 'verify_package', Mock(side_effect=ValueError('source changed'))), patch.object(
                update, 'InstallationProxyService') as proxy:
            with self.assertRaises(ValueError):
                asyncio.run(update.install(object(), {}, {}, 'target', Path(directory),
                                           {}, lambda: None))
            proxy.assert_not_called()

    def test_wrong_live_identity_never_reads_app_data_or_installs(self):
        client = SimpleNamespace(udid='wrong', paired=True, close=AsyncMock())
        with tempfile.TemporaryDirectory() as directory, patch.object(
                update, 'verify_package'), patch.object(
                update, 'get_preferred_pair_record', AsyncMock(return_value={})), patch.object(
                update, 'create_using_tcp', AsyncMock(return_value=client)) as connect, patch.object(
                update, 'install', AsyncMock()) as install:
            with self.assertRaisesRegex(ValueError, 'identity mismatch'):
                asyncio.run(update.run({'udid': 'target', 'host': 'test', 'port': 1}, {}, {},
                                       Path(directory), {}, lambda: None, False))
            install.assert_not_awaited()
            self.assertFalse(connect.call_args.kwargs['autopair'])
            client.close.assert_awaited_once()

    def test_install_complete_survives_post_install_backup_failure(self):
        messages = []

        class Proxy:
            def __init__(self, client):
                self.service = SimpleNamespace(send_plist=AsyncMock(side_effect=messages.append))

            async def __aenter__(self):
                return self

            async def __aexit__(self, *args):
                pass

            async def install_from_local(self, ipa, cmd):
                await self.send_package(cmd, {}, None, 'staged.ipa')

            async def _watch_completion(self, *args):
                pass

            async def lookup(self, options):
                return {update.BUNDLE: {'CFBundleIdentifier': update.BUNDLE}}

        with tempfile.TemporaryDirectory() as directory, patch.object(
                update, 'InstallationProxyService', Proxy), patch.object(
                update, 'verify_package'), patch.object(
                update, 'read_preferences', AsyncMock(side_effect=[{}, ConnectionError()])):
            result = {}
            with self.assertRaises(ConnectionError):
                asyncio.run(update.install(object(), {'ipa': 'test.ipa'}, {}, 'target',
                                           Path(directory), result, lambda: None))
            self.assertTrue(result['installCompleteObserved'])
            self.assertTrue(result['postInstallLookupExists'])
            self.assertEqual([m['Command'] for m in messages], ['Install'])
            self.assertNotIn('preferences', result)


if __name__ == '__main__':
    unittest.main()
