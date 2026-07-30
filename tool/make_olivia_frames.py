#!/usr/bin/env python3
"""Cut Olivia's mouth-shape frames out of her video clip.

The clip is her face in the app. If it cannot play — an old web view, a codec
problem — the next best thing is a small set of mouth shapes from that same
clip, swapped in time with her speech, which is what lib/widgets/olivia/
olivia_lipsync.dart does. Both come from one source so they look identical.

Picking the frames by hand is fiddly and easy to get wrong: frames far apart in
time have different head positions, so swapping between them makes her head
jump. This does it properly:

  1. ffmpeg every frame of the clip.
  2. Find her mouth by measuring which pixels vary most across the clip.
  3. Score each frame for how open the mouth is (contrast plus dark area —
     an open mouth has a dark interior against bright teeth).
  4. Slide a window over the clip and pick the one with the widest range of
     mouth openness and the least movement everywhere else, so only her mouth
     differs between the chosen frames.
  5. Export four frames from that window: closed, barely parted, mid, wide.

Run:  python3 tool/make_olivia_frames.py
"""
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND = os.path.join(ROOT, "assets", "brand")
CLIP = os.path.join(BRAND, "olivia_source.mp4")

# Her mouth and head in the 464x688 clip. Re-measure if the clip is reframed;
# step 2 below prints what it found so you can sanity-check these.
MOUTH = (185, 398, 290, 462)
HEAD = (140, 250, 330, 520)
WINDOW = 8


def openness(path):
    im = Image.open(path).convert("L").crop(MOUTH)
    d = list(im.getdata())
    n = len(d)
    mean = sum(d) / n
    sd = (sum((v - mean) ** 2 for v in d) / n) ** 0.5
    dark = sum(1 for v in d if v < 70) / n
    return sd * 0.5 + dark * 260


def head_movement(a, b):
    """How much the head moved between two frames, ignoring the mouth."""
    ia = Image.open(a).convert("L").crop(HEAD)
    ib = Image.open(b).convert("L").crop(HEAD)
    diff = ImageChops.difference(ia, ib)
    px = diff.load()
    mx0, my0 = MOUTH[0] - HEAD[0], MOUTH[1] - HEAD[1]
    mx1, my1 = MOUTH[2] - HEAD[0], MOUTH[3] - HEAD[1]
    total = count = 0
    for y in range(0, diff.height, 3):
        for x in range(0, diff.width, 3):
            if mx0 <= x <= mx1 and my0 <= y <= my1:
                continue
            total += px[x, y]
            count += 1
    return total / count


def main() -> int:
    if not os.path.exists(CLIP):
        print(f"missing {CLIP}", file=sys.stderr)
        return 1
    if not shutil.which("ffmpeg"):
        print("ffmpeg is required (brew install ffmpeg)", file=sys.stderr)
        return 1

    work = tempfile.mkdtemp(prefix="olivia-frames-")
    try:
        subprocess.run(
            ["ffmpeg", "-v", "error", "-i", CLIP, "-vsync", "0",
             os.path.join(work, "f%04d.png")],
            check=True)
        frames = sorted(
            os.path.join(work, f) for f in os.listdir(work) if f.endswith(".png"))
        print(f"{len(frames)} frames")

        scores = [openness(f) for f in frames]
        best = None
        for start in range(len(frames) - WINDOW):
            window = range(start, start + WINDOW)
            spread = max(scores[i] for i in window) - min(scores[i] for i in window)
            drift = head_movement(frames[start], frames[start + WINDOW - 1])
            rank = spread / (1 + drift * 1.5)
            if best is None or rank > best[0]:
                best = (rank, start, spread, drift)
        _, start, spread, drift = best
        window = sorted(range(start, start + WINDOW), key=lambda i: scores[i])
        print(f"window {start + 1}-{start + WINDOW}: "
              f"mouth range {spread:.1f}, head drift {drift:.2f}")

        chosen = [window[0], window[len(window) // 3],
                  window[2 * len(window) // 3], window[-1]]
        for n, i in enumerate(chosen):
            out = os.path.join(BRAND, f"olivia_mouth{n}.jpg")
            Image.open(frames[i]).convert("RGB").save(
                out, "JPEG", quality=88, optimize=True)
            label = ["closed", "small", "mid", "open"][n]
            print(f"  olivia_mouth{n}.jpg  {label:7} frame {i + 1} "
                  f"openness {scores[i]:.1f}")

        # The still-image fallback is the closed-mouth frame.
        Image.open(frames[chosen[0]]).convert("RGB").save(
            os.path.join(BRAND, "olivia.png"), "PNG")
        print("  olivia.png    still fallback")
        return 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
