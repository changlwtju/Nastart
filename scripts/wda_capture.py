#!/usr/bin/env python3
"""Timestamped WDA screenshots/XML. Observes content, never certifies frame pacing.
Run only after the per-device latest-package gate. Omit --session to create a
normal, no-reset session; supplying --session preserves the existing session.
"""
import argparse
import base64
import json
from pathlib import Path
import time
import urllib.request


def request(base, route, data=None):
    req = urllib.request.Request(base + route,
        data=None if data is None else json.dumps(data).encode(),
        headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as response:
        result = json.load(response)
    if isinstance(result.get('value'), dict) and result['value'].get('error'):
        raise RuntimeError(result['value']['error'])
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--wda', default='http://127.0.0.1:8102')
    p.add_argument('--bundle', default='com.changliwen.nastart')
    p.add_argument('--session', help='Existing session ID (does not launch app)')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--times', default='0,3,10,30', help='Seconds from capture invocation, NOT play tap')
    a = p.parse_args()
    times = [float(x) for x in a.times.split(',')]
    if not times or times[0] < 0 or times != sorted(times) or times[-1] > 300:
        p.error('times must be sorted, within 0..300 seconds')
    a.output.mkdir(mode=0o700, parents=True, exist_ok=False)
    status = request(a.wda, '/status')
    (a.output/'status.json').write_text(json.dumps(status, indent=2))
    if not status['value'].get('ready'):
        raise RuntimeError('WDA not ready')
    sid = a.session
    if not sid:
        value = request(a.wda, '/session', {'capabilities': {'alwaysMatch': {
            'platformName':'iOS', 'appium:bundleId':a.bundle, 'appium:noReset':True}}})
        sid = value.get('sessionId') or value['value']['sessionId']
    (a.output/'session-id').write_text(sid)
    base = '/session/' + sid
    request(a.wda, base+'/appium/settings', {'settings': {'waitForIdleTimeout':0, 'animationCoolOffTimeout':0}})
    start = time.monotonic()
    result = {'bundle':a.bundle, 'capture_start_unix':time.time(), 'samples':[],
              'scope':'Sparse screen observations; not exact first-frame or frame-pacing measurement'}
    try:
        for i, target in enumerate(times):
            time.sleep(max(0, start + target - time.monotonic()))
            row = {'target_seconds':target, 'request_unix':time.time(),
                   'request_elapsed':time.monotonic()-start}
            result['samples'].append(row)
            active = request(a.wda, base+'/wda/activeAppInfo')['value']
            row['foreground_bundle'] = active.get('bundleId')
            if row['foreground_bundle'] != a.bundle:
                raise RuntimeError('Expected app is not foreground')
            png = base64.b64decode(request(a.wda, base+'/screenshot')['value'], validate=True)
            if not png.startswith(b'\x89PNG\r\n\x1a\n'):
                raise RuntimeError('Response is not PNG')
            (a.output/f'{i:02d}.png').write_bytes(png)
            row['response_unix'] = time.time()
            row['response_elapsed'] = time.monotonic()-start
            (a.output/f'{i:02d}.xml').write_text(request(a.wda, base+'/source')['value'])
    except Exception as error:
        result['error'] = str(error)
        raise
    finally:
        (a.output/'capture.json').write_text(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
