#!/usr/bin/env python3
"""Encode one generated caption PNG as a small PGS fixture; never reads media.

Requires Pillow. The fixed 1080p canvas/object placement matches
hdr_pip_overlay_probe.swift. Palette alpha is explicitly quantized to 17 levels.
This is a test fixture writer, not an App subtitle encoder or movie sample.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

from PIL import Image


def segment(kind, payload, pts):
    assert len(payload) <= 65535
    return b"PG" + struct.pack(">IIBH", pts, pts, kind, len(payload)) + payload


def run_length(row):
    output = bytearray()
    start = 0
    while start < len(row):
        color = row[start]
        end = start + 1
        while end < len(row) and row[end] == color and end - start < 16383:
            end += 1
        length = end - start
        flags = 0x80 if color else 0
        if length >= 64:
            output.extend([0, flags | 0x40 | (length >> 8), length & 255])
        else:
            output.extend([0, flags | length])
        if color:
            output.append(color)
        start = end
    output.extend([0, 0])
    return bytes(output)


def palette_entry(index, rgba):
    red, green, blue, alpha = rgba
    r, g, b = red / 255, green / 255, blue / 255
    luma = .2126 * r + .7152 * g + .0722 * b
    byte = lambda value: min(255, max(0, round(value)))
    return bytes([index, byte(16 + 219 * luma),
                  byte(128 + 112 * (r - luma) / (1 - .2126)),
                  byte(128 + 112 * (b - luma) / (1 - .0722)), alpha])


def encode(image):
    width, height = image.size
    assert 0 < width <= 512 and 0 < height <= 128
    colors = [(0, 0, 0, 0)]
    lookup = {colors[0]: 0}
    indexes = []
    quantized = []
    rgba = image.convert("RGBA")
    pixels = rgba.get_flattened_data() if hasattr(rgba, "get_flattened_data") else rgba.getdata()
    for red, green, blue, alpha in pixels:
        alpha = min(255, round(alpha / 17) * 17)
        color = (red, green, blue, alpha) if alpha else colors[0]
        if color not in lookup:
            lookup[color] = len(colors)
            colors.append(color)
        indexes.append(lookup[color])
        quantized.append(color)
    assert len(colors) <= 256
    rle = b"".join(run_length(indexes[y * width:(y + 1) * width]) for y in range(height))
    # Epoch start: 1920x1080, 24fps code, palette 0, one object at top-left (400,800).
    pcs = struct.pack(">HHBHBBBB", 1920, 1080, 0x10, 0, 0x80, 0, 0, 1)
    pcs += struct.pack(">HBBHH", 1, 0, 0, 400, 800)
    window = bytes([1, 0]) + struct.pack(">HHHH", 400, 800, width, height)
    palette = bytes([0, 0]) + b"".join(palette_entry(i, color) for i, color in enumerate(colors))
    obj = struct.pack(">HBB", 1, 0, 0xC0) + (len(rle) + 4).to_bytes(3, "big")
    obj += struct.pack(">HH", width, height) + rle
    data = b"".join(segment(kind, value, 90000) for kind, value in
                    [(0x16, pcs), (0x17, window), (0x14, palette), (0x15, obj), (0x80, b"")])
    clear = struct.pack(">HHBHBBBB", 1920, 1080, 0x10, 1, 0, 0, 0, 0)
    data += segment(0x16, clear, 270000) + segment(0x80, b"", 270000)
    expected = Image.new("RGBA", (width, height))
    expected.putdata(quantized)
    return data, expected, len(colors)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("caption_png", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    args.output_directory.mkdir(parents=True, exist_ok=False)
    data, expected, count = encode(Image.open(args.caption_png))
    (args.output_directory / "generated.sup").write_bytes(data)
    expected.save(args.output_directory / "palette-quantized-expected.png")
    summary = {"generatedFixture": True, "movieMediaRead": False,
               "paletteAlphaStep": 17, "paletteEntries": count, "bytes": len(data),
               "sha256": hashlib.sha256(data).hexdigest(), "canvas": [1920, 1080],
               "objectOriginTopLeft": [400, 800], "objectSize": list(expected.size),
               "displayIntervalSeconds": [1, 3]}
    (args.output_directory / "fixture-safe.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
