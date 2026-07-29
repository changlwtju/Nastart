#!/usr/bin/env python3
"""Export the selected Nastart icon direction into an iOS AppIcon set."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[3]
ASSET_ROOT = ROOT / "ios/Nastart/Nastart/Assets.xcassets"
ICON_SET = ASSET_ROOT / "AppIcon.appiconset"


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def lerp(a: int, b: int, t: float) -> int:
    return int(round(a + (b - a) * t))


def gradient(size: tuple[int, int], stops: list[tuple[float, str]]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size)
    pixels = image.load()
    rgb_stops = [(float(pos), hex_to_rgb(color)) for pos, color in stops]

    for y in range(height):
        for x in range(width):
            t = ((x / max(width - 1, 1)) + (y / max(height - 1, 1))) / 2
            left = rgb_stops[0]
            right = rgb_stops[-1]
            for index in range(len(rgb_stops) - 1):
                if rgb_stops[index][0] <= t <= rgb_stops[index + 1][0]:
                    left = rgb_stops[index]
                    right = rgb_stops[index + 1]
                    break

            span = max(right[0] - left[0], 1e-6)
            local = min(max((t - left[0]) / span, 0), 1)
            pixels[x, y] = tuple(lerp(left[1][channel], right[1][channel], local) for channel in range(3))

    return image.convert("RGBA")


def rounded_rect_gradient(
    base: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    stops: list[tuple[float, str]],
    opacity: int = 255,
    shadow: tuple[int, int, int, tuple[int, int, int], int] | None = None,
) -> None:
    x, y, width, height = box

    if shadow:
        dx, dy, blur, color, alpha = shadow
        mask = Image.new("L", base.size, 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.rounded_rectangle((x + dx, y + dy, x + width + dx, y + height + dy), radius=radius, fill=alpha)
        shadow_image = Image.new("RGBA", base.size, color + (255,))
        shadow_image.putalpha(mask.filter(ImageFilter.GaussianBlur(blur)))
        base.alpha_composite(shadow_image)

    rect = gradient((width, height), stops)
    if opacity < 255:
        rect.putalpha(Image.new("L", (width, height), opacity))

    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width, height), radius=radius, fill=255)
    base.paste(rect, (x, y), mask)


def draw_master() -> Image.Image:
    canvas = gradient((1024, 1024), [(0, "#fbf8ef"), (0.58, "#ece5d9"), (1, "#d5c7b3")])

    rounded_rect_gradient(
        canvas,
        (108, 170, 808, 684),
        154,
        [(0, "#fffdf8"), (0.52, "#ece8df"), (1, "#b9b4aa")],
        shadow=(0, 30, 30, hex_to_rgb("#40372f"), 42),
    )
    rounded_rect_gradient(canvas, (214, 282, 452, 460), 70, [(0, "#4d535c"), (1, "#20252d")])

    for x, opacity in [(256, 248), (390, 238), (524, 228)]:
        rounded_rect_gradient(canvas, (x, 334, 82, 354), 30, [(0, "#fffaf0"), (1, "#cfc7ba")], opacity=opacity)

    draw = ImageDraw.Draw(canvas)
    for x in (297, 431, 565):
        draw.line((x, 388, x, 632), fill="#5d626b", width=9)

    power_color = "#a76638"
    draw.line((786, 332, 786, 388), fill=power_color, width=18)
    draw.arc((739, 358, 833, 452), start=124, end=416, fill=power_color, width=18)
    draw.ellipse((742, 612, 772, 642), fill="#648e70")
    draw.ellipse((806, 612, 836, 642), fill="#ad7948")

    return canvas.convert("RGB")


def main() -> None:
    ICON_SET.mkdir(parents=True, exist_ok=True)
    ASSET_ROOT.mkdir(parents=True, exist_ok=True)

    (ASSET_ROOT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

    specs = [
        ("iphone", "20x20", "2x", 40),
        ("iphone", "20x20", "3x", 60),
        ("iphone", "29x29", "2x", 58),
        ("iphone", "29x29", "3x", 87),
        ("iphone", "40x40", "2x", 80),
        ("iphone", "40x40", "3x", 120),
        ("iphone", "60x60", "2x", 120),
        ("iphone", "60x60", "3x", 180),
        ("ipad", "20x20", "1x", 20),
        ("ipad", "20x20", "2x", 40),
        ("ipad", "29x29", "1x", 29),
        ("ipad", "29x29", "2x", 58),
        ("ipad", "40x40", "1x", 40),
        ("ipad", "40x40", "2x", 80),
        ("ipad", "76x76", "1x", 76),
        ("ipad", "76x76", "2x", 152),
        ("ipad", "83.5x83.5", "2x", 167),
        ("ios-marketing", "1024x1024", "1x", 1024),
    ]

    master = draw_master()
    master.save(Path(__file__).resolve().with_name("nastart-app-icon-v3-11-clear-nas.png"), "PNG", optimize=True)
    images = []

    for idiom, point_size, scale, pixels in specs:
        safe_size = point_size.replace(".", "-")
        filename = f"AppIcon-{idiom}-{safe_size}@{scale}.png"
        icon = master if pixels == 1024 else master.resize((pixels, pixels), Image.Resampling.LANCZOS)
        icon.save(ICON_SET / filename, "PNG", optimize=True)
        images.append({"size": point_size, "idiom": idiom, "filename": filename, "scale": scale})

    (ICON_SET / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
