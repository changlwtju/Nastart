#!/usr/bin/python3
"""Install the verified current Nastart IPA over an existing paired Wi-Fi link.

All inputs/outputs containing identities, endpoints or preferences belong outside
the repository. Use discover_paired_wireless_device.py to obtain --endpoint.
No pairing, uninstall, network change, WDA install or implicit retry is performed.
"""
import argparse
import asyncio
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import traceback
import zipfile

from pymobiledevice3.lockdown import create_using_tcp
from pymobiledevice3.pair_records import get_preferred_pair_record
from pymobiledevice3.services.house_arrest import HouseArrestService
from pymobiledevice3.services.installation_proxy import InstallationProxyService

BUNDLE = 'com.changliwen.nastart'
REPO = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def now():
    return datetime.now(timezone.utc).isoformat()


def verify_ipa_members(archive):
    """Reject Mac archive metadata before a package reaches installation_proxy."""
    for name in archive.namelist():
        parts = Path(name).parts
        require('__MACOSX' not in parts
                and not any(part.startswith('._') for part in parts),
                'IPA contains Mac metadata; rebuild the archive without AppleDouble files')


def verify_package(manifest, inputs, udid):
    """Fail closed before device mutation, including source changes during backup."""
    require(bool(inputs), 'Empty source manifest')
    require(all(sha(f) == h for f, h in inputs.items()), 'Source input changed')
    diff = subprocess.check_output(['git', 'diff', '--', 'ios'], cwd=REPO)
    require(hashlib.sha256(diff).hexdigest() == manifest['sourceDiffSHA256'],
            'Current iOS diff differs from frozen build')
    require(subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO,
                                    text=True).strip() == manifest['head'],
            'HEAD differs from frozen build')
    app, ipa = Path(manifest['package']), Path(manifest['ipa'])
    require(sha(ipa) == manifest['ipaSHA256'], 'IPA hash mismatch')
    require(bool(manifest['binaries']), 'Empty binary manifest')
    for name, digest in manifest['binaries'].items():
        require(sha(app / name) == digest, 'App binary hash mismatch')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)],
                   check=True, capture_output=True)
    libraries = [p for p in app.rglob('*') if p.is_file() and (
        p.suffix == '.dylib' or p.parent.suffix == '.framework'
        and p.name == p.parent.stem)]
    require(len(libraries) == manifest['individuallyVerifiedLibraries'],
            'Library inventory mismatch')
    for library in libraries:
        subprocess.run(['codesign', '--verify', '--strict', str(library)],
                       check=True, capture_output=True)
    profile = plistlib.loads(subprocess.check_output(
        ['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')]))
    require(udid in profile.get('ProvisionedDevices', []), 'Device not provisioned')
    require(profile['ExpirationDate'].replace(tzinfo=timezone.utc)
            > datetime.now(timezone.utc), 'Provisioning profile expired')
    with zipfile.ZipFile(ipa) as archive:
        verify_ipa_members(archive)
        require(archive.testzip() is None, 'IPA CRC failed')
        info = plistlib.loads(archive.read('Payload/Nastart.app/Info.plist'))
        require(info['CFBundleIdentifier'] == BUNDLE, 'Wrong app bundle')
        for name, digest in manifest['binaries'].items():
            require(hashlib.sha256(archive.read('Payload/Nastart.app/' + name))
                    .hexdigest() == digest, 'IPA binary hash mismatch')


class PairedHouseArrestService(HouseArrestService):
    """Keep the real provider type so legacy versus RSD service names stay correct."""
    def __init__(self, client, documents_only=False):
        super().__init__(client, documents_only=documents_only)
        record = getattr(client, 'pair_record', None)
        # HouseArrestService 11.1.0 doesn't expose this inherited option in its
        # constructor. Set the existing LockdownService request flag only.
        if record and record.get('EscrowBag'):
            self._include_escrow_bag = True


async def read_preferences(client, output, label):
    # RSD authenticates its own services. On direct lockdown, reuse the existing
    # host's escrow when available; do not create or replace pairing material.
    service = await asyncio.wait_for(PairedHouseArrestService.create(client, BUNDLE), 8)
    async with service:
        raw = await asyncio.wait_for(service.get_file_contents(
            'Library/Preferences/' + BUNDLE + '.plist'), 8)
    (output / (label + '-preferences-private.plist')).write_bytes(raw)
    return plistlib.loads(raw)


def compare_preferences(before, after):
    clean = lambda values: {k: v for k, v in values.items()
                            if not k.startswith('diagnostics.')}
    a, b = clean(before), clean(after)
    return {'beforeKeys': len(a), 'afterKeys': len(b),
            'sameKeys': set(a) == set(b),
            'changedValues': sum(k not in b or b[k] != v for k, v in a.items()),
            'allNonDiagnosticPreferencesEqual': a == b}


async def install(client, manifest, inputs, udid, output, result, save):
    # Backup is a required gate. A failed HouseArrest handshake must not proceed
    # to AFC upload or installation_proxy, even when lockdown identity worked.
    result['stage'] = 'savingPreferences'
    save()
    before = await read_preferences(client, output, 'before-install')
    result['preferencesSavedBeforeInstall'] = True
    verify_package(manifest, inputs, udid)

    class RecordedInstallationProxy(InstallationProxyService):
        async def send_package(self, cmd, options, handler, package_path, *args):
            require(cmd == 'Install', 'Only data-preserving Install is allowed')
            result['stage'] = 'dispatchingInstall'
            result['installDispatchAttempted'] = True
            save()
            await self.service.send_plist({'Command': cmd, 'ClientOptions': options,
                                          'PackagePath': package_path})
            result['installCommandSent'] = True
            save()
            await self._watch_completion(handler, *args)
            # Preserve Complete even if subsequent AFC staging cleanup fails.
            result['installCompleteObserved'] = True
            result['installedAtUTC'] = now()
            save()

    proxy = RecordedInstallationProxy(client)
    await asyncio.wait_for(proxy.__aenter__(), 8)
    try:
        result['stage'] = 'uploadingAndInstalling'
        save()
        await asyncio.wait_for(proxy.install_from_local(
            manifest['ipa'], cmd='Install'), 120)
        lookup = await asyncio.wait_for(proxy.lookup(
            options={'BundleIDs': [BUNDLE]}), 8)
        (output / 'installed-lookup-private.json').write_text(
            json.dumps(lookup, default=str))
        result['postInstallLookupExists'] = bool(lookup and BUNDLE in lookup)
        require(result['postInstallLookupExists'], 'Installed bundle lookup missing')
    finally:
        await proxy.__aexit__(None, None, None)
    result['stage'] = 'checkingPreferences'
    save()
    after = await read_preferences(client, output, 'after-install')
    result['preferences'] = compare_preferences(before, after)
    result['stage'] = 'installed; normal launch and actual UI review pending'
    save()


async def normal_launch(client, udid, output, result, save):
    """Optional iOS 17+ userspace RSD/DVT launch, independent of WDA."""
    from contextlib import AsyncExitStack
    from pymobiledevice3.remote import tunnel_service
    from pymobiledevice3.remote.userspace_tunnel import UserspaceDialPlane
    from pymobiledevice3.remote.remote_service_discovery import RemoteServiceDiscoveryService
    from pymobiledevice3.services.dvt.instruments.dvt_provider import DvtProvider
    from pymobiledevice3.services.dvt.instruments.process_control import ProcessControl
    from pymobiledevice3.services.dvt.instruments.screenshot import Screenshot

    result['stage'] = 'normalLaunchViaUserspaceRSD'
    save()
    old_mode = tunnel_service.USE_USERSPACE_TUNNEL
    tunnel_service.USE_USERSPACE_TUNNEL = True
    try:
        async with AsyncExitStack() as stack:
            provider = await tunnel_service.CoreDeviceTunnelProxy.create(client)
            stack.push_async_callback(provider.close)
            tunnel = await stack.enter_async_context(provider.start_tcp_tunnel())
            tun = tunnel.client.tun
            tun.set_peer(tunnel.address)
            dial = await stack.enter_async_context(UserspaceDialPlane(tun, tunnel.address))
            rsd = RemoteServiceDiscoveryService((tunnel.address, tunnel.port),
                open_connection=dial.dial, auxiliary_metadata=tunnel.auxiliary_metadata)
            stack.push_async_callback(rsd.close)
            await rsd.connect()
            require(rsd.udid == udid, 'RSD target identity mismatch')
            result['RSDTargetVerified'] = True
            async with DvtProvider(rsd) as dvt:
                async with ProcessControl(dvt) as control:
                    pid = await control.launch(BUNDLE, arguments=[], environment={},
                                               kill_existing=True)
                    result.update(normalLaunchRequested=True,
                                  requestedEnvironment={}, requestedArguments=[])
                    (output / 'launch-pid-private.json').write_text(json.dumps({'pid': pid}))
                    save()
                await asyncio.sleep(6)
                async with Screenshot(dvt) as screenshot:
                    (output / 'normal-launch-private.png').write_bytes(
                        await screenshot.get_screenshot())
            result['actualScreenCaptured'] = True
            after = await read_preferences(rsd, output, 'after-launch')
            before = plistlib.loads((output / 'before-install-preferences-private.plist').read_bytes())
            result['preferencesAfterLaunch'] = compare_preferences(before, after)
            result['stage'] = 'installed; launch requested; actual screenshot review required'
            save()
    finally:
        tunnel_service.USE_USERSPACE_TUNNEL = old_mode


async def run(endpoint, manifest, inputs, output, result, save, probe_only, launch=False):
    udid = endpoint['udid']
    verify_package(manifest, inputs, udid)
    result['packageVerified'] = True
    record = await get_preferred_pair_record(udid, Path.home() / '.pymobiledevice3')
    require(record is not None, 'Existing pairing record missing; no automatic pairing')
    result['stage'] = 'connectingPairedLockdown'
    save()
    client = await asyncio.wait_for(create_using_tcp(
        endpoint['host'], port=int(endpoint['port']), identifier=udid,
        autopair=False, pair_record=record), 6)
    try:
        require(client.udid == udid and client.paired, 'Live paired identity mismatch')
        require(client.product_type == 'iPhone19,7', 'Unexpected target model')
        (output / 'fresh-device-values-private.json').write_text(
            json.dumps(client.all_values, default=str))
        result.update(targetLiveVerified=True, model=client.product_type,
                      system=client.all_values.get('ProductVersion'), connection='NETWORK')
        result['existingEscrowUsedForContainerRequest'] = bool(
            client.pair_record and client.pair_record.get('EscrowBag'))
        if probe_only:
            await read_preferences(client, output, 'probe')
            result['stage'] = 'probe: paired identity and container verified; no install'
            result['containerReadable'] = True
            return
        await install(client, manifest, inputs, udid, output, result, save)
        if launch:
            await asyncio.wait_for(normal_launch(client, udid, output, result, save), 50)
    finally:
        await client.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['endpoint', 'manifest', 'inputs', 'output']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--probe-only', action='store_true')
    parser.add_argument('--launch', action='store_true',
                        help='After InstallComplete, request empty-env launch and save actual screen via RSD/DVT')
    args = parser.parse_args()
    if args.probe_only and args.launch:
        parser.error('--probe-only cannot launch an app')
    os.umask(0o077)
    output = args.output.expanduser().resolve()
    if output == REPO or REPO in output.parents:
        parser.error('Raw evidence must be outside the repository')
    output.mkdir(mode=0o700, parents=True, exist_ok=False)
    result = {'startedAtUTC': now(), 'stage': 'verifyingPackage',
              'packageVerified': False, 'targetLiveVerified': False,
              'preferencesSavedBeforeInstall': False,
              'installDispatchAttempted': False, 'installCommandSent': False,
              'installCompleteObserved': False, 'postInstallLookupExists': False,
              'actualForegroundUIVerified': False, 'newPairingAttempted': False,
              'networkOrVPNChanged': False, 'WDARequiredForInstallation': False}

    def save():
        (output / 'summary-safe.json').write_text(json.dumps(result, indent=2))

    save()
    try:
        endpoint = json.loads(args.endpoint.expanduser().read_text())
        manifest = json.loads(args.manifest.expanduser().read_text())
        inputs = json.loads(args.inputs.expanduser().read_text())
        result.update(sourceDiffSHA256=manifest['sourceDiffSHA256'],
                      binaries=manifest['binaries'], ipaSHA256=manifest['ipaSHA256'])
        async def execute():
            # Some library connection failures also complete a shared Future.
            # Keep any late exception details private, including device IDs.
            def private_async_error(loop, context):
                error = context.get('exception')
                text = ''.join(traceback.format_exception(type(error), error, error.__traceback__)) \
                    if error is not None else str(context.get('message', 'Async service failure'))
                with (output / 'async-background-failure-private.log').open('a') as log:
                    log.write(text + '\n')
            asyncio.get_running_loop().set_exception_handler(private_async_error)
            await asyncio.wait_for(run(endpoint, manifest, inputs, output, result,
                                       save, args.probe_only, args.launch), 240)
        asyncio.run(execute())
        code = 0
    except Exception as error:
        result['failedAtStage'] = result['stage']
        result['failureType'] = type(error).__name__
        result['stage'] = ('installed; post-install verification incomplete'
                           if result['installCompleteObserved'] else 'blocked; install not confirmed')
        (output / 'failure-private.log').write_text(traceback.format_exc())
        code = 1
    result['finishedAtUTC'] = now()
    save()
    print(json.dumps(result))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
