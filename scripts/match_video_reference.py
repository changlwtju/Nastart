#!/usr/bin/env python3
"""Rank local source frames against a device screenshot; no network/credentials.
Reference is ffmpeg gray rawvideo plus its showinfo log. This does NOT prove
unique frame identity, smoothness, or audio sync. Inspect multiple candidates.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--ffmpeg', required=True)
    p.add_argument('--reference-gray', type=Path, required=True)
    p.add_argument('--reference-log', type=Path, required=True)
    p.add_argument('--screenshot', type=Path, required=True)
    p.add_argument('--filter', required=True, help='Verified screenshot rotation/crop/scale, ending format=gray')
    p.add_argument('--width', type=int, default=64)
    p.add_argument('--height', type=int, default=20)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--allow-trailing-pts', type=int, default=0, help='Explicit historical ffmpeg -to tail allowance; default requires exact match')
    a = p.parse_args()
    size = a.width*a.height
    if size <= 0: p.error('positive dimensions required')
    pts = [float(x) for x in re.findall(r'\bn:\s*\d+.*?pts_time:([\d.\-]+)', a.reference_log.read_text())]
    data = a.reference_gray.read_bytes()
    extra = len(pts) - len(data)//size
    if not pts or len(data)%size or extra < 0 or extra > a.allow_trailing_pts:
        raise RuntimeError('Reference frame/PTS count mismatch')
    pts = pts[:len(data)//size]
    result = subprocess.run([a.ffmpeg,'-v','error','-i',str(a.screenshot),'-vf',a.filter,
        '-frames:v','1','-f','rawvideo','-'],capture_output=True,check=True,timeout=30)
    if len(result.stdout) != size: raise RuntimeError('Screenshot filter dimensions mismatch')
    ranks = []
    for i, stamp in enumerate(pts):
        frame = data[i*size:(i+1)*size]
        ranks.append({'pts':stamp,'mae':sum(abs(x-y) for x,y in zip(result.stdout,frame))/size})
    ranks.sort(key=lambda r:r['mae'])
    a.output.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
    a.output.write_text(json.dumps({'matches':ranks[:8], 'reference_frames':len(pts), 'ignored_trailing_pts':extra,
        'scope':'Candidate content matches only; repeated frames can be ambiguous'},indent=2))
    print(json.dumps(ranks[:4]))

if __name__ == '__main__': main()
