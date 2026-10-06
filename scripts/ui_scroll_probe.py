#!/usr/bin/env python3
"""Record real-device scroll hitches; raw artifacts belong outside the repository.

Uses WDA gestures and Instruments, never treats an HTTP-success gesture as smoothness.
The gate covers the visible app + compositor during a controlled foreground window;
CA commits are separately attributed to Nastart. It is not a universal FPS estimate.
"""
import argparse
import base64
import datetime as dt
import json
from pathlib import Path
import subprocess
import time
import urllib.request
import xml.etree.ElementTree as ET


def request(base, path, data=None):
    # Accessibility eligibility is unused by the page/motion gates and is
    # expensive to compute for every poster on older WDA/iPadOS combinations.
    # Keep visibility, names and geometry so all evidence gates stay intact.
    if path == '/source':
        path += '?excluded_attributes=accessible'
    req = urllib.request.Request(base + path, data=None if data is None else json.dumps(data).encode(),
                                 headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=45) as response:
        result = json.load(response)
    if isinstance(result.get('value'), dict) and result['value'].get('error'):
        raise RuntimeError(result['value']['error'])
    return result


def rows(path):
    root = ET.parse(path).getroot()
    ids = {e.get('id'): e for e in root.iter() if e.get('id')}
    def resolve(e):
        return ids[e.get('ref')] if e.get('ref') else e
    columns = [c.findtext('mnemonic') for c in root.findall('.//schema/col')]
    if not columns:
        raise ValueError('Missing trace schema; empty export is not evidence of zero hitches')
    return [{key: resolve(value) for key, value in zip(columns, row)}
            for row in root.findall('.//row')]


def export(trace, schema, output):
    with output.open('w') as stream:
        subprocess.run(['xcrun', 'xctrace', 'export', '--input', str(trace), '--xpath',
                        f'/trace-toc/run[@number="1"]/data/table[@schema="{schema}"]'], stdout=stream, check=True)


def sampler_preflight(folder, device):
    """Check host sampling capabilities before changing WDA settings or moving UI."""
    checks = {}
    for capability in ('devices', 'instruments', 'templates'):
        try:
            result = subprocess.run(['xcrun', 'xctrace', 'list', capability],
                                    capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            checks[capability] = dict(returncode=result.returncode, output=output)
        except subprocess.TimeoutExpired as error:
            def decoded(value):
                return value.decode(errors='replace') if isinstance(value, bytes) else (value or '')
            output = decoded(error.stdout) + decoded(error.stderr)
            checks[capability] = dict(returncode=None, output=output, timeout=True)
        (folder / f'xctrace-{capability}.log').write_text(output)
    problems = []
    for capability, check in checks.items():
        if check['returncode'] != 0:
            problems.append(f'{capability} enumeration failed or timed out')
    if device not in checks['devices']['output']:
        problems.append('Target UDID absent from Instruments device enumeration')
    instruments = checks['instruments']['output'].strip()
    if not instruments or 'No instruments found' in instruments:
        problems.append('Host Instruments exposes no recording instruments')
    if 'Animation Hitches' not in checks['templates']['output']:
        problems.append('Animation Hitches template unavailable')
    report = dict(device=device, ready=not problems, problems=problems, checks=checks)
    (folder / 'sampler-preflight.json').write_text(json.dumps(report, indent=2))
    if problems:
        raise RuntimeError('Sampling preflight: ' + '; '.join(problems))
    return report


def union_duration(intervals):
    total = 0.0
    end = float('-inf')
    for start, stop in sorted(intervals):
        total += max(0, stop - max(start, end))
        end = max(end, stop)
    return total


def content_positions(source):
    # Stable accessible text is sufficient to prove displacement; images changing
    # in an auto-rotating hero alone are not evidence of scrolling.
    values = {}
    for element in ET.fromstring(source).iter():
        if element.get('type') != 'XCUIElementTypeStaticText':
            continue
        key = element.get('name')
        y = float(element.get('y', '0'))
        if key and y > 80:
            values.setdefault(key, []).append(y)
    return {key: ys[0] for key, ys in values.items() if len(ys) == 1}


def validate_scroll_target(source, x, top, bottom, anchors, verified_visible_anchors=None):
    """Reject another page/orientation even if the app bundle is unchanged."""
    elements = list(ET.fromstring(source).iter())
    app = next((e for e in elements if e.get('type') == 'XCUIElementTypeApplication'), None)
    if app is None:
        raise RuntimeError('Scroll target has no application viewport')
    width, height = float(app.get('width', '0')), float(app.get('height', '0'))
    if not (0 < x < width and 0 < top < bottom < height):
        raise RuntimeError('Scroll coordinates outside current viewport; page/orientation changed')
    visible = ({e.get('name') for e in elements if e.get('visible') == 'true'}
               if verified_visible_anchors is None else set(verified_visible_anchors))
    if not anchors or any(anchor not in visible for anchor in anchors):
        raise RuntimeError('Expected visible page anchors missing; stopping gestures')


def confirm_anchor_rect(source, name, rect, displayed, element_type=None):
    """Bind the live visibility result to one exact node in this snapshot."""
    matches = [e for e in ET.fromstring(source).iter() if e.get('name') == name
               and (element_type is None or e.get('type') == element_type)
               and all(abs(float(e.get(k, 'nan')) - float(rect[k])) < .1
                       for k in ('x', 'y', 'width', 'height'))]
    if displayed is not True or len(matches) != 1:
        raise RuntimeError('Page anchor hidden, ambiguous or moved since snapshot')


def target_snapshot(base, anchors):
    # Computing native visibility for hundreds of offscreen SwiftUI nodes
    # can stall XCTest. Query it only for the page anchors, then bind each
    # live result to the exact name/rect from the geometry snapshot.
    source = request(base, '/source?excluded_attributes=accessible,visible')['value']
    checks = []
    for name in anchors:
        began = time.time()
        element = request(base, '/element', {'using': 'accessibility id', 'value': name})['value']
        element_id = element.get('ELEMENT') or element['element-6066-11e4-a52e-4f735466cecf']
        rect = request(base, '/element/' + element_id + '/rect')['value']
        element_type = request(base, '/element/' + element_id + '/attribute/type')['value']
        displayed = request(base, '/element/' + element_id + '/displayed')['value']
        confirm_anchor_rect(source, name, rect, displayed, element_type)
        checks.append(dict(name=name, rect=rect, type=element_type, displayed=displayed,
                           request_unix=began, response_unix=time.time()))
    return source, checks


def motion_window_complete(manifest, trace_start, trace_seconds):
    start, end = manifest.get('motion_start'), manifest.get('motion_end')
    gestures = manifest.get('gestures', [])
    if start is None or end is None:
        return False
    return (manifest.get('completed_swipes', 0) >= 12 and len(gestures) >= 12
            and len(manifest.get('movement_checks', [])) == len(gestures)
            and sum(manifest.get('movement_checks', [])) >= 12
            and len(manifest.get('foreground_checks', [])) == len(gestures)
            and all(manifest.get('foreground_checks', []))
            and end - start >= 10 and manifest.get('foreground_verified', False)
            and manifest.get('movement_verified', False)
            and trace_start <= start < end <= trace_start + trace_seconds
            and all(start <= began < finished <= end for began, finished in gestures)
            and all(a[1] <= b[0] for a, b in zip(gestures, gestures[1:])))


def display_sampling_complete(manifest, trace_start, timestamps):
    """Require display timing throughout every drag, not just an empty hitch table.

    Conservative 50ms continuity gate for these 60Hz devices. A gap may be a
    capture failure or a real stall; either way it cannot establish a PASS.
    These are compositor vsyncs, not a measurement of the app's rendered FPS.
    """
    points = sorted(set(timestamps))
    if not points or not manifest.get('gestures'):
        return False
    for began, ended in manifest['gestures']:
        low, high = began - trace_start, ended - trace_start
        samples = [t for t in points if low <= t <= high]
        if (len(samples) < (high - low) * 30
                or not samples or samples[0] - low > .05
                or high - samples[-1] > .05
                or any(b - a > .05 for a, b in zip(samples, samples[1:]))):
            return False
    return True


def display_sampling_details(manifest, trace_start, timestamps):
    """Retain the actual gaps when the completeness gate rejects a capture."""
    points = sorted(set(timestamps))
    details = []
    for index, (began, ended) in enumerate(manifest.get('gestures', []), 1):
        low, high = began - trace_start, ended - trace_start
        samples = [t for t in points if low <= t <= high]
        gaps = ([samples[0] - low, high - samples[-1]]
                + [b - a for a, b in zip(samples, samples[1:])] if samples else [])
        details.append(dict(swipe=index, seconds=round(high - low, 6), samples=len(samples),
                            samples_per_second=round(len(samples) / (high - low), 3) if high > low else None,
                            max_gap_ms=round(max(gaps) * 1000, 3) if gaps else None,
                            leading_gap_ms=round(gaps[0] * 1000, 3) if gaps else None,
                            trailing_gap_ms=round(gaps[1] * 1000, 3) if gaps else None))
    return details


def summarize(folder):
    manifest = json.loads((folder / 'run.json').read_text())
    if 'motion_start' not in manifest or 'motion_end' not in manifest:
        result = dict(page=manifest.get('page'), build=manifest.get('build'),
                      verdict='INSUFFICIENT', reason='Motion recording did not complete')
        (folder / 'summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
        print(json.dumps(result, ensure_ascii=False), flush=True)
        return
    trace = folder / 'scroll.trace'
    for schema in ['hitches-summary', 'hitches-ca-commit-interval', 'display-vsyncs-interval']:
        export(trace, schema, folder / (schema + '.xml'))
    toc = subprocess.check_output(['xcrun', 'xctrace', 'export', '--input', str(trace), '--toc'])
    (folder / 'toc.xml').write_bytes(toc)
    start = dt.datetime.fromisoformat(ET.fromstring(toc).findtext('.//start-date')).timestamp()
    low, high = manifest['motion_start'] - start, manifest['motion_end'] - start
    def selected(row):
        return low <= int(row['start'].text) / 1e9 <= high
    hitch_rows = [r for r in rows(folder / 'hitches-summary.xml')
                  if int(r['start'].text) / 1e9 < high
                  and (int(r['start'].text) + int(r['duration'].text)) / 1e9 > low]
    hitches = [int(r['duration'].text) / 1e6 for r in hitch_rows]
    hitch_intervals = [(max(low, int(r['start'].text) / 1e9), min(high, (int(r['start'].text) + int(r['duration'].text)) / 1e9)) for r in hitch_rows]
    hitch_union_ms = union_duration(hitch_intervals) * 1000
    commits = [int(r['duration'].text) / 1e6 for r in rows(folder / 'hitches-ca-commit-interval.xml')
               if selected(r) and r['process'].get('fmt', '').startswith(manifest.get('process_name', 'Nastart') + ' (')]
    seconds = high - low
    # Predeclared engineering gate; all foreground/compositor hitches count, including
    # ones not attributable to an app commit. Missing evidence never yields PASS.
    trace_seconds = float(ET.fromstring(toc).findtext('.//duration'))
    display_times = [int(r['timestamp'].text) / 1e9
                     for r in rows(folder / 'display-vsyncs-interval.xml')]
    display_complete = display_sampling_complete(manifest, start, display_times)
    valid = motion_window_complete(manifest, start, trace_seconds) and display_complete
    ratio = hitch_union_ms / seconds if seconds > 0 else None
    passed = valid and ratio <= 5 and max(hitches, default=0) < 100
    result = dict(page=manifest['page'], build=manifest['build'], seconds=round(seconds, 3),
                  completed_swipes=manifest['completed_swipes'], hitch_count=len(hitches),
                  effective_swipes=sum(manifest.get('movement_checks', [])),
                  hitch_ms=round(hitch_union_ms, 3), hitch_ms_per_second=round(ratio, 3) if ratio is not None else None,
                  max_hitch_ms=round(max(hitches, default=0), 3),
                  app_hitch_commit_count=len(commits), max_app_hitch_commit_ms=round(max(commits, default=0), 3),
                  verdict='PASS' if passed else ('FAIL' if valid else 'INSUFFICIENT'),
                  movement_verified=manifest.get('movement_verified', False), scope='controlled foreground UI + compositor; not all pages or perpetual smoothness',
                  display_sampling_complete=display_complete,
                  display_sampling_details=display_sampling_details(manifest, start, display_times),
                  gate='>=12 displaced swipes, >=10s; each drag has >=30 display timing samples/s and no gap >50ms; hitch <=5ms/s, no hitch >=100ms; foreground verified for every swipe')
    (folder / 'summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print(json.dumps(result, ensure_ascii=False), flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--page')
    p.add_argument('--page-anchor', action='append', default=[],
                   help='Required visible accessibility name identifying the page; repeat for multiple anchors')
    p.add_argument('--build')
    p.add_argument('--device')
    p.add_argument('--record-seconds', type=int, default=120, help='Bounded trace duration; iOS16 XML checks may exceed 60 seconds')
    p.add_argument('--process-name', default='Nastart')
    p.add_argument('--bundle-id', default='com.changliwen.nastart')
    p.add_argument('--wda', default='http://127.0.0.1:8103')
    p.add_argument('--session-file', default='/tmp/nastart-ipad-scroll-session')
    p.add_argument('--summarize', action='store_true')
    p.add_argument('--preflight-only', action='store_true', help='Check sampling tools without WDA or gestures')
    p.add_argument('--x', type=int, default=660)
    p.add_argument('--top', type=int, default=280)
    p.add_argument('--bottom', type=int, default=880)
    args = p.parse_args()
    if not 60 <= args.record_seconds <= 300:
        p.error('--record-seconds must be between 60 and 300')
    if args.summarize:
        summarize(args.output)
        return
    if not args.device or (not args.preflight_only and not all([args.page, args.build, args.page_anchor])):
        p.error('--page, --page-anchor, --build and --device required for recording')
    folder = args.output
    folder.mkdir(parents=True, exist_ok=False)
    manifest = dict(process_name=args.process_name, bundle_id=args.bundle_id, page=args.page, page_anchors=args.page_anchor, record_seconds=args.record_seconds, build=args.build, device=args.device, source_excluded_attributes=['accessible', 'visible'], anchor_visibility_method='live displayed + exact snapshot type/name/rect', anchor_checks=[], maximum_swipe_attempts=24, completed_swipes=0,
                    foreground_verified=False, gestures=[], movement_checks=[], foreground_checks=[])
    (folder / 'run.json').write_text(json.dumps(manifest, indent=2))
    report = sampler_preflight(folder, args.device)
    if args.preflight_only:
        print(json.dumps(report), flush=True)
        return
    base = args.wda + '/session/' + Path(args.session_file).read_text().strip()
    request(base, '/appium/settings', {'settings': {'waitForIdleTimeout': 0, 'animationCoolOffTimeout': 0}})
    active = request(base, '/wda/activeAppInfo')['value']
    if active.get('bundleId') != args.bundle_id:
        raise RuntimeError('Expected app is not foreground')
    (folder / 'before.png').write_bytes(base64.b64decode(request(base, '/screenshot')['value']))
    source_before, anchor_checks = target_snapshot(base, args.page_anchor)
    manifest['anchor_checks'].append(anchor_checks)
    (folder / 'before.xml').write_text(source_before)
    validate_scroll_target(source_before, args.x, args.top, args.bottom, args.page_anchor,
                           [c['name'] for c in anchor_checks])
    positions = content_positions(source_before)
    log = folder / 'record.log'
    with log.open('w') as stream:
        proc = subprocess.Popen(['xcrun', 'xctrace', 'record', '--template', 'Animation Hitches', '--device',
                                 args.device, '--all-processes', '--time-limit', f'{args.record_seconds}s', '--output', str(folder / 'scroll.trace')],
                                stdout=stream, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 45
            while 'Ctrl-C to stop' not in log.read_text():
                if proc.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('trace did not start')
                time.sleep(.25)
            time.sleep(1)
            manifest['motion_start'] = time.time()
            # A boundary bounce is retained but does not count toward the
            # twelve displaced drags. Retry within an explicit finite budget.
            for i in range(manifest['maximum_swipe_attempts']):
                if proc.poll() is not None or 'Reached specified time limit' in log.read_text():
                    raise RuntimeError('Recording ended before all gestures; increase --record-seconds')
                manifest['foreground_checks'].append(
                    request(base, '/wda/activeAppInfo')['value'].get('bundleId') == args.bundle_id)
                if not manifest['foreground_checks'][-1]:
                    raise RuntimeError('Expected app left foreground; stopping gestures')
                current, anchor_checks = target_snapshot(base, args.page_anchor)
                manifest['anchor_checks'].append(anchor_checks)
                (folder / f'pre-swipe-{i + 1:02d}.xml').write_text(current)
                validate_scroll_target(current, args.x, args.top, args.bottom, args.page_anchor,
                                       [c['name'] for c in anchor_checks])
                # Two successive upward drags expose lower shelves; then return.
                y, z = (args.bottom, args.top) if i % 4 < 2 else (args.top, args.bottom)
                actions = [{'type': 'pointerMove', 'duration': 0, 'x': args.x, 'y': y},
                           {'type': 'pointerDown', 'button': 0}, {'type': 'pause', 'duration': 100},
                           {'type': 'pointerMove', 'duration': 650, 'x': args.x, 'y': z},
                           {'type': 'pointerUp', 'button': 0}]
                began = time.time()
                request(base, '/actions', {'actions': [{'type': 'pointer', 'id': 'finger',
                        'parameters': {'pointerType': 'touch'}, 'actions': actions}]})
                manifest['gestures'].append([began, time.time()])
                middle, anchor_checks = target_snapshot(base, args.page_anchor)
                manifest['anchor_checks'].append(anchor_checks)
                (folder / f'swipe-{i + 1:02d}.xml').write_text(middle)
                validate_scroll_target(middle, args.x, args.top, args.bottom, args.page_anchor,
                                       [c['name'] for c in anchor_checks])
                if i == 0:
                    (folder / 'mid.xml').write_text(middle)
                next_positions = content_positions(middle)
                shifted = [key for key, y in next_positions.items()
                           if key in positions and abs(y - positions[key]) >= 40]
                manifest['movement_checks'].append(len(shifted) >= 2)
                manifest['movement_verified'] = sum(manifest['movement_checks']) >= 12
                positions = next_positions
                manifest['completed_swipes'] += 1
                print(f'{args.page}: swipe {i + 1}/24; displaced {sum(manifest["movement_checks"])}/12', flush=True)
                if manifest['movement_verified']:
                    break
                time.sleep(.5)
            manifest['motion_end'] = time.time()
            manifest['foreground_verified'] = request(base, '/wda/activeAppInfo')['value'].get('bundleId') == args.bundle_id
            (folder / 'after.png').write_bytes(base64.b64decode(request(base, '/screenshot')['value']))
        finally:
            (folder / 'run.json').write_text(json.dumps(manifest, indent=2))
            # Let Instruments finish its bounded recording normally; interrupting
            # an iPadOS 18 stream can produce a truncated transferred trace.
            proc.wait(timeout=args.record_seconds + 180)
    if proc.returncode != 0:
        raise RuntimeError('trace recording failed; cannot judge performance')
    summarize(folder)

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Retain tool/export failures as machine-readable results as well as
        # their original traceback. Never leave an earlier PASS in place.
        import sys
        if '--output' in sys.argv:
            folder = Path(sys.argv[sys.argv.index('--output') + 1])
            if folder.is_dir():
                result = dict(verdict='INSUFFICIENT', reason=str(error))
                manifest_path = folder / 'run.json'
                if manifest_path.exists():
                    try:
                        manifest = json.loads(manifest_path.read_text())
                        result.update({key: manifest.get(key) for key in
                                       ('page', 'build', 'device', 'completed_swipes')})
                    except (ValueError, OSError):
                        pass
                (folder / 'summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
        raise
