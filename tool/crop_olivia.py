#!/usr/bin/env python3
"""Regenerate Olivia's portrait from the original photo.

The avatar clips to a circle, so the crop has to put her face slightly above
centre with her shoulders filling the lower half — otherwise the app mock-ups
either side of her in the original photo end up inside the circle.

Run:  python3 tool/crop_olivia.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "brand", "olivia_source.jpeg")
OUT = os.path.join(ROOT, "assets", "brand", "olivia.png")

# Her face centre in the source photo, and how tightly to frame it.
FACE_X, FACE_Y, SIDE = 566, 196, 330
# Fraction of the crop height above her face centre; below 0.5 lifts her up.
FACE_HEIGHT_FRACTION = 0.42


def main() -> int:
    src = Image.open(SRC).convert("RGB")
    left = FACE_X - SIDE // 2
    top = int(FACE_Y - FACE_HEIGHT_FRACTION * SIDE)
    box = (left, top, left + SIDE, top + SIDE)
    src.crop(box).resize((640, 640), Image.LANCZOS).save(OUT, "PNG")
    print(f"wrote {OUT} from crop {box} of {src.size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
