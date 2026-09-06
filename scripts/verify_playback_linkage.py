#!/usr/bin/env python3
"""Reject a device app whose KSPlayer FFmpeg calls bind to MobileVLCKit."""

import argparse
from pathlib import Path
import re
import subprocess
import sys


def inspect(tool, *arguments):
    return subprocess.check_output([tool, *map(str, arguments)], text=True)


def verify(app):
    engine = app / "Frameworks/KSPlayer.framework/KSPlayer"
    if not engine.is_file():
        raise ValueError("KSPlayer.framework is not embedded; dynamic isolation is required")
    dependencies = inspect("otool", "-L", engine)
    symbols = inspect("nm", "-m", engine)
    if "MobileVLCKit" in dependencies or "MobileVLCKit" in symbols:
        raise ValueError("KSPlayer must not link to MobileVLCKit or resolve its symbols there")
    for symbol, provider in {
        "avformat_open_input": "Libavformat",
        "av_read_frame": "Libavformat",
        "avcodec_send_packet": "Libavcodec",
        "av_frame_alloc": "Libavutil",
    }.items():
        lines = [line for line in symbols.splitlines() if re.search(r"_" + symbol + r"(?:\s|$)", line)]
        if not lines or any("(undefined)" in line and f"(from {provider})" not in line for line in lines):
            raise ValueError(f"{symbol}: missing definition or unexpected FFmpeg provider: {lines}")
    # App-side FFmpeg calls would reintroduce the ABI collision even with an
    # isolated engine. The legacy path should use VLC's Objective-C API only.
    for binary in (app / "Nastart", app / "Nastart.debug.dylib"):
        if not binary.exists():
            continue
        bad = [line for line in inspect("nm", "-m", binary).splitlines()
               if "(from MobileVLCKit)" in line and re.search(r"_(?:av\w*_|sw[rs]_|ff_)", line)]
        if bad:
            raise ValueError(f"App imports VLC's FFmpeg ABI: {bad[:5]}")
    print("PASS: embedded KSPlayer has isolated FFmpeg bindings; legacy VLC remains independent")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    try:
        verify(parser.parse_args().app)
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
