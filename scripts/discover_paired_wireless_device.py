#!/usr/bin/python3
"""Resolve a paired device with macOS DNS-SD and verify its live Wi-Fi identity.

The private config contains udid and bonjourInstance (the instance part of
BonjourFullServiceName previously read from the target). No pairing, app launch,
installation, VPN change or subnet scan is performed. Raw endpoints and device
values are saved only to a new evidence directory outside the repository.
"""
import argparse
import asyncio
import ipaddress
import json
import os
from pathlib import Path
import re
import subprocess
import traceback


SERVICE = '_apple-mobdev2._tcp'
MAX_CURRENT_INSTANCES = 4


def current_instances(text):
    """Track current DNS-SD entries; a removed instance is no longer a candidate."""
    active = {}
    for line in text.splitlines():
        match = re.search(
            r'\b(Add|Rmv)\b\s+\S+\s+(\d+)\s+local\.\s+'
            r'_apple-mobdev2\._tcp\.\s+(.+)$', line)
        if not match:
            continue
        action, interface, name = match.groups()
        key = (interface, name.strip())
        if action == 'Add':
            active[key] = name.strip()
        else:
            active.pop(key, None)
    return list(dict.fromkeys(active.values()))


def bounded_dns(arguments, output, name):
    try:
        result = subprocess.run(['/usr/bin/dns-sd', *arguments],
                                capture_output=True, timeout=5)
        data = result.stdout + result.stderr
    except subprocess.TimeoutExpired as error:
        # DNS-SD keeps watching after a result; its normal watch timeout is not
        # a device failure. Preserve the complete output before parsing it.
        data = (error.stdout or b'') + (error.stderr or b'')
    (output / name).write_bytes(data)
    return data.decode(errors='replace')


def service_endpoint(text):
    match = re.search(r'can be reached at (\S+):(\d+) \(interface (\d+)\)', text)
    if not match:
        raise ValueError('Target service did not resolve')
    host, port, interface = match.groups()
    port = int(port)
    if not 1 <= port <= 65535:
        raise ValueError('Invalid advertised port')
    return host, port, int(interface)


def ipv4_addresses(text):
    result = []
    for line in text.splitlines():
        # Only current DNS-SD additions; removals must not become candidates.
        if not re.search(r'\bAdd\b', line):
            continue
        for token in line.split():
            try:
                address = ipaddress.ip_address(token)
            except ValueError:
                continue
            if address.version == 4 and str(address) not in result:
                result.append(str(address))
    return result


async def verify_candidates(addresses, advertised_port, udid, record, output):
    from pymobiledevice3.lockdown import create_using_tcp
    attempts = []
    for address in addresses:
        # Modern advertised services may not speak plaintext lockdownd. Try
        # the standard lockdownd endpoint on the SAME resolved device address.
        for port in dict.fromkeys([advertised_port, 62078]):
            client = None
            attempt = {'address': address, 'port': port}
            try:
                client = await asyncio.wait_for(create_using_tcp(
                    address, port=port, identifier=udid, autopair=False,
                    pair_record=record), timeout=6)
                attempt.update(identityMatches=client.udid == udid,
                               paired=client.paired)
                if client.udid == udid and client.paired:
                    (output / 'device-values-private.json').write_text(
                        json.dumps(client.all_values, default=str))
                    attempts.append(attempt)
                    (output / 'attempts-private.json').write_text(json.dumps(attempts))
                    (output / 'verified-endpoint-private.json').write_text(json.dumps({
                        'host': address, 'port': port, 'udid': udid}))
                    return {'identityMatches': True, 'paired': True,
                            'model': client.product_type,
                            'system': client.all_values.get('ProductVersion'),
                            'verifiedPort': port}
                # Never accept a reachable but different device as the target.
            except Exception as error:
                attempt['failureType'] = type(error).__name__
            finally:
                if client is not None:
                    await client.close()
            attempts.append(attempt)
    (output / 'attempts-private.json').write_text(json.dumps(attempts))
    raise RuntimeError('No paired endpoint matched the intended device')


async def discover(config, output):
    from pymobiledevice3.pair_records import get_preferred_pair_record
    udid = config['udid']
    instance = config['bonjourInstance'].removesuffix('.' + SERVICE + '.local.')
    if not udid or not instance:
        raise ValueError('Missing target identity or service instance')
    record = await get_preferred_pair_record(udid, Path.home() / '.pymobiledevice3')
    if record is None:
        raise RuntimeError('Existing pairing record unavailable; automatic pairing disabled')
    host, port, interface = service_endpoint(bounded_dns(
        ['-L', instance, SERVICE, 'local.'], output, 'service-resolution-private.log'))
    addresses = ipv4_addresses(bounded_dns(
        ['-G', 'v4', host], output, 'address-resolution-private.log'))
    if not addresses:
        raise RuntimeError('Target service has no current resolved IPv4 address')
    usb = subprocess.run(['idevice_id', '-l'], capture_output=True, text=True, timeout=4)
    if usb.returncode:
        raise RuntimeError('Cannot verify current USB inventory')
    result = await verify_candidates(addresses, port, udid, record, output)
    result.update(connection='direct Wi-Fi TCP',
                  targetAbsentFromUSB=udid not in usb.stdout.splitlines(),
                  systemDNSServiceResolved=True, resolvedInterfaceIndex=interface,
                  pairingRecordChanged=False, networkConfigurationChanged=False,
                  appInstalledOrLaunched=False)
    return result


async def discover_current(config, output):
    """Use current advertisements when the target's saved instance has changed.

    Names are discovery hints only. Each address must authenticate with the
    intended device's existing pair record and return its live UDID. No old IPs,
    subnet scan, pairing, app launch or installation is involved.
    """
    names = current_instances(bounded_dns(
        ['-B', SERVICE, 'local.'], output, 'current-browser-private.log'))
    if len(names) > MAX_CURRENT_INSTANCES:
        raise RuntimeError('Too many current instances for a bounded identity check')
    if not names:
        raise RuntimeError('No current wireless device advertisements')
    attempts = []
    for index, name in enumerate(names):
        child = output / ('current-instance-' + str(index))
        child.mkdir(mode=0o700)
        candidate = {**config, 'bonjourInstance': name}
        (child / 'discovery-config-private.json').write_text(json.dumps(candidate))
        try:
            result = await discover(candidate, child)
        except Exception as error:
            attempts.append({'instanceIndex': index, 'failureType': type(error).__name__})
            (child / 'failure-private.log').write_text(traceback.format_exc())
            (output / 'current-attempts-safe.json').write_text(json.dumps(attempts))
            continue
        (output / 'verified-endpoint-private.json').write_bytes(
            (child / 'verified-endpoint-private.json').read_bytes())
        (output / 'device-values-private.json').write_bytes(
            (child / 'device-values-private.json').read_bytes())
        result.update(currentAdvertisementsChecked=index + 1,
                      discoveryMode='current advertisements; authenticated target identity')
        return result
    raise RuntimeError('No current advertised device authenticated as the intended target')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--browse-current', action='store_true',
                        help='Authenticate up to four currently advertised instances; no name assumption')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    output = args.output.expanduser().resolve()
    if output == repo or repo in output.parents:
        parser.error('Private wireless evidence must be saved outside the repository')
    os.umask(0o077)
    output.mkdir(mode=0o700, parents=True, exist_ok=False)
    try:
        config = json.loads(args.config.expanduser().read_text())
        operation = discover_current(config, output) if args.browse_current else discover(config, output)
        result = asyncio.run(asyncio.wait_for(operation, 100))
        result['outcome'] = 'verified'
        exit_code = 0
    except Exception as error:
        (output / 'failure-private.log').write_text(traceback.format_exc())
        result = {'outcome': 'unverified', 'failureType': type(error).__name__,
                  'pairingRecordChanged': False, 'networkConfigurationChanged': False}
        exit_code = 1
    (output / 'summary-safe.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result))
    return exit_code


if __name__ == '__main__':
    raise SystemExit(main())
