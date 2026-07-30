#!/usr/bin/env python3
"""Prepare Olivia's portrait for the app from the original photo.

The avatar shows the whole photograph — her at the desk with the app on screen
behind her — so this only converts to PNG and trims any stray border. Nothing is
cropped away.

Run:  python3 tool/crop_olivia.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "brand", "olivia_source.jpeg")
OUT = os.path.join(ROOT, "assets", "brand", "olivia.png")


def main() -> int:
    src = Image.open(SRC).convert("RGB")
    # Keep the full frame and its aspect ratio; the widget letterboxes it.
    src.save(OUT, "PNG")
    print(f"wrote {OUT} at {src.size} (full frame, nothing cropped)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
