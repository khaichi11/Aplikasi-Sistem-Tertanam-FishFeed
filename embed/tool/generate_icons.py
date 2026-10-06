#!/usr/bin/env python3
"""Generate FishFeed launcher icons for Android and iOS.

Draws the same fish-and-pellets mark as lib/ui/widgets/logo.dart.
Usage (from embed/): python3 tool/generate_icons.py
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OCEAN_DEEP = (10, 79, 92)
OCEAN = (14, 110, 126)
CORAL = (232, 163, 61)
WHITE = (255, 255, 255, 255)
SS = 4


def quad(p0, p1, p2, steps=40):
    return [
        ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t**2 * p2[0],
         (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t**2 * p2[1])
        for t in (i / steps for i in range(steps + 1))
    ]


def flat_tile(size):
    """Flat petrol tile, like AppColors.ocean."""
    return Image.new("RGBA", (size, size), OCEAN + (255,))


def draw_mark(draw, s, ox=0.0, oy=0.0):
    def p(x, y):
        return (ox + x * s, oy + y * s)

    tail = [p(0.62, 0.53), p(0.82, 0.40)] + [p(*q) for q in quad((0.82, 0.40), (0.77, 0.53), (0.82, 0.66))]
    draw.polygon(tail, fill=WHITE)
    body = (quad((0.20, 0.56), (0.42, 0.30), (0.66, 0.48))
            + quad((0.66, 0.48), (0.72, 0.53), (0.66, 0.58))
            + quad((0.66, 0.58), (0.42, 0.78), (0.20, 0.56)))
    draw.polygon([p(*q) for q in body], fill=WHITE)
    for cx, cy, r, color in [(0.32, 0.52, 0.035, OCEAN_DEEP), (0.30, 0.20, 0.045, CORAL),
                             (0.42, 0.14, 0.035, CORAL), (0.22, 0.31, 0.03, CORAL)]:
        draw.ellipse((p(cx - r, cy - r), p(cx + r, cy + r)), fill=color)


def render(size, *, rounded, background=True, scale=1.0):
    big = size * SS
    if background:
        img = flat_tile(big)
        if rounded:
            mask = Image.new("L", (big, big), 0)
            ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=0.24 * big, fill=255)
            img.putalpha(mask)
    else:
        img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    side = big * scale
    offset = (big - side) / 2
    draw_mark(ImageDraw.Draw(img), side, offset, offset)
    return img.resize((size, size), Image.LANCZOS)


def android():
    res = ROOT / "android/app/src/main/res"
    for name, factor in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        folder = res / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        render(round(48 * factor), rounded=True).save(folder / "ic_launcher.png")
        render(round(108 * factor), rounded=False, background=False, scale=0.62).save(
            folder / "ic_launcher_foreground.png")
    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@drawable/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n")
    (res / "drawable").mkdir(exist_ok=True)
    (res / "drawable/ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<shape xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <solid android:color="#0E6E7E" />\n'
        "</shape>\n")
    (res / "values").mkdir(exist_ok=True)
    (res / "values/colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="launch_background">#F4F6F7</color>\n'
        "</resources>\n")
    nodpi = res / "drawable-nodpi"
    nodpi.mkdir(exist_ok=True)
    render(288, rounded=True).save(nodpi / "launch_logo.png")
    splash = ('<?xml version="1.0" encoding="utf-8"?>\n'
              '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
              '    <item android:drawable="@color/launch_background" />\n'
              '    <item android:width="96dp" android:height="96dp" android:gravity="center">\n'
              '        <bitmap android:gravity="fill" android:src="@drawable/launch_logo" />\n'
              '    </item>\n'
              "</layer-list>\n")
    for folder in ("drawable", "drawable-v21"):
        (res / folder).mkdir(exist_ok=True)
        (res / folder / "launch_background.xml").write_text(splash)


def ios():
    folder = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((folder / "Contents.json").read_text())
    for entry in contents["images"]:
        if not entry.get("filename"):
            continue
        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        render(round(points * scale), rounded=False).convert("RGB").save(folder / entry["filename"])
    launch = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for name, size in (("LaunchImage.png", 96), ("LaunchImage@2x.png", 192), ("LaunchImage@3x.png", 288)):
        render(size, rounded=True).save(launch / name)


if __name__ == "__main__":
    android()
    ios()
    print("Icons generated.")
