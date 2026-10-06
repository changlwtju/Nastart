#!/usr/bin/python3
"""Read App diagnostics through USB House Arrest; never alter App data.

Uses the existing private tidevice runtime when Apple's device enumeration
cannot see a USB device that lockdown can still reach. Raw preferences may
contain credentials: the output must be a new directory outside this repo.
"""
import argparse
import json
import os
from pathlib import Path
import plistlib
import runpy


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--bundle', default='com.changliwen.nastart')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    output = args.output.expanduser().resolve()
    if output == repo or repo in output.parents:
        parser.error('Raw preferences must be saved outside the repository')
    os.umask(0o077)
    output.mkdir(mode=0o700, parents=True, exist_ok=False)
    runpy.run_path(str(repo / 'scripts/tidevice_private.py'))
    import tidevice
    device = tidevice.Device(args.device)
    # VendDocuments cannot read Library/Preferences. Explicitly request the
    # development App's container; no installation, launch or write occurs.
    sync = device.app_sync(args.bundle, command='VendContainer')
    data = bytes(sync.pull_content('Library/Preferences/' + args.bundle + '.plist'))
    (output / 'preferences.plist').write_bytes(data)
    entries = json.loads(plistlib.loads(data).get('diagnostics.entries.v1', b'[]'))
    if not isinstance(entries, list):
        raise ValueError('Unexpected diagnostics format; original plist retained')
    (output / 'entries.json').write_text(json.dumps(entries, ensure_ascii=False))
    print(json.dumps({'device': args.device, 'bundle': args.bundle,
                      'preferenceBytes': len(data), 'diagnosticEntries': len(entries)}))


if __name__ == '__main__':
    main()
