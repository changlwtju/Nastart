#!/usr/bin/env python3
"""Generate an original, quiet stereo PCM sample; no external media needed."""
import argparse
import math
import struct
import wave
from pathlib import Path


def generate(path: Path, seconds: int = 40) -> None:
    rate = 48000
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setparams((2, 2, rate, 0, "NONE", "not compressed"))
        for second in range(seconds):
            samples = bytearray()
            for frame in range(rate):
                t = second + frame / rate
                fade = min(t / 0.1, (seconds - t) / 0.1, 1)
                left = int(32767 * 0.08 * fade * math.sin(2 * math.pi * 440 * t))
                right = int(32767 * 0.08 * fade * math.sin(2 * math.pi * 660 * t))
                samples.extend(struct.pack("<hh", left, right))
            output.writeframes(samples)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    generate(args.output)
    print(f"Created 40 s, 48 kHz, stereo PCM: {args.output}")
