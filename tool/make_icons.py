#!/usr/bin/env python3
"""Build LocalHive's app icon set from the vector mark.

Renders assets/brand/localhive_mark.svg into the two source PNGs that
flutter_launcher_icons consumes:

  assets/brand/icon_1024.png        the mark on white, for iOS and web
  assets/brand/icon_foreground.png  the mark padded and transparent, for
                                    Android's adaptive icon

Android crops an adaptive icon's foreground to a circle and can zoom it, so
the foreground gets generous padding — roughly 60% of the canvas — or the
hexagon's corners get shaved off on round-icon launchers.

Run:  python3 tool/make_icons.py
Then: dart run flutter_launcher_icons
"""
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND = os.path.join(ROOT, "assets", "brand")
SVG = os.path.join(BRAND, "localhive_mark.svg")

# The app's ink colour, used as the flat backdrop behind the mark.
WHITE = (255, 255, 255, 255)

CANVAS = 1024
# Fraction of the canvas the mark occupies.
FULL_SCALE = 0.82
ADAPTIVE_SCALE = 0.58


def render_svg(px: int) -> Image.Image:
    """Rasterise the mark at px × px with transparency."""
    out = os.path.join(BRAND, f".tmp_{px}.png")
    subprocess.run(
        ["rsvg-convert", "-w", str(px), "-h", str(px), SVG, "-o", out],
        check=True,
    )
    img = Image.open(out).convert("RGBA")
    os.remove(out)
    return img


def centred(mark: Image.Image, canvas: int, background) -> Image.Image:
    base = Image.new("RGBA", (canvas, canvas), background)
    x = (canvas - mark.width) // 2
    y = (canvas - mark.height) // 2
    base.alpha_composite(mark, (x, y))
    return base


def main() -> int:
    if not os.path.exists(SVG):
        print(f"missing {SVG}", file=sys.stderr)
        return 1
    os.makedirs(BRAND, exist_ok=True)

    # iOS and web: opaque white behind the mark. iOS rejects icons with alpha,
    # and flutter_launcher_icons strips it, so start from something sensible.
    full = render_svg(int(CANVAS * FULL_SCALE))
    centred(full, CANVAS, WHITE).save(
        os.path.join(BRAND, "icon_1024.png"), "PNG"
    )

    # Android adaptive foreground: transparent, heavily padded.
    small = render_svg(int(CANVAS * ADAPTIVE_SCALE))
    centred(small, CANVAS, (0, 0, 0, 0)).save(
        os.path.join(BRAND, "icon_foreground.png"), "PNG"
    )

    for name in ("icon_1024.png", "icon_foreground.png"):
        path = os.path.join(BRAND, name)
        with Image.open(path) as im:
            print(f"  {name}: {im.size[0]}x{im.size[1]} {im.mode}")

    print("\nNow run:  dart run flutter_launcher_icons")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
