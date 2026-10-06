#!/usr/bin/env python3
"""Bounded USB/DVT capability probe. Never certifies app scrolling smoothness.

Uses an existing tidevice executable; does not launch apps, move UI or install.
Raw device-wide aggregate FPS is not per-frame timing or app-attributed FPS.
"""
import argparse
import datetime
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import time


def summarize(raw):
    samples = []
    rejected = 0
    for line in raw.splitlines():
        try:
            row = json.loads(line)
            fps, stamp = row['fps'], row['timestamp']
            if not all(type(v) in (int, float) and math.isfinite(v)
                       for v in (fps, stamp)) or fps < 0:
                raise ValueError('invalid sample')
            samples.append((stamp / 1000, fps))
        except (ValueError, KeyError, TypeError):
            rejected += 1
    gaps = [b[0] - a[0] for a, b in zip(samples, samples[1:])]
    return dict(sample_count=len(samples), rejected_lines=rejected,
                aggregate_stream_observed=len(samples) >= 3 and all(g > 0 for g in gaps),
                coverage_seconds=samples[-1][0] - samples[0][0] if samples else 0,
                max_sample_gap_seconds=max(gaps) if gaps else None,
                scroll_verdict='INSUFFICIENT',
                reason='Device-wide aggregate FPS; no per-frame timing, app attribution or movement evidence')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tidevice', default='tidevice')
    parser.add_argument('--device', required=True)
    parser.add_argument('--seconds', type=float, default=15)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not math.isfinite(args.seconds) or not 3 <= args.seconds <= 120:
        parser.error('--seconds must be between 3 and 120')
    args.output.mkdir(mode=0o700, parents=True, exist_ok=False)
    metadata = dict(device=args.device, started_at=datetime.datetime.now().astimezone().isoformat(),
                    scope='sampling capability only; not an app regression',
                    requested_seconds=args.seconds, scroll_verdict='INSUFFICIENT')
    manifest = args.output / 'report.json'
    manifest.write_text(json.dumps(metadata, indent=2))
    command = [args.tidevice, '-u', args.device, 'perf', '-o', 'fps', '--json']
    started = time.monotonic()
    with (args.output / 'graphics.jsonl').open('w') as out, (args.output / 'stderr.log').open('w') as err:
        try:
            proc = subprocess.Popen(command, stdout=out, stderr=err,
                                    env={**os.environ, 'PYTHONUNBUFFERED': '1'})
            try:
                proc.wait(timeout=args.seconds)
                metadata['ended_before_deadline'] = True
            except subprocess.TimeoutExpired:
                metadata['ended_before_deadline'] = False
            finally:
                if proc.poll() is None:
                    proc.send_signal(signal.SIGINT)
                    try:
                        proc.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait()
                        metadata['forced_stop'] = True
                metadata['returncode'] = proc.returncode
        except OSError as error:
            metadata['error'] = str(error)
    metadata['elapsed_seconds'] = time.monotonic() - started
    metadata.update(summarize((args.output / 'graphics.jsonl').read_text()))
    manifest.write_text(json.dumps(metadata, indent=2))
    print(json.dumps(metadata, indent=2))
    return 0 if metadata['aggregate_stream_observed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
