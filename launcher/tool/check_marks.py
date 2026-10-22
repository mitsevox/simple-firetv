"""Checks, from a real TV screenshot, that every mark is drawn at its computed size and centred
exactly where tool/marks.py placed it in its dock tile.

Install a check build first, which draws each mark as a dock tile on black:
  flutter build apk --release --target-platform android-arm --dart-define=MARK_CHECK=true
  adb install -r build/app/outputs/flutter-apk/app-release.apk

Then run from the project root:  python3 tool/check_marks.py
It screenshots the TV, finds each mark's ink in its tile, and compares the ink's box against
build/marks.json from tool/marks.py. Exits non-zero if anything is off by more than TOLERANCE px.
"""

import io
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

TV = os.environ.get("TV", "192.168.50.76:5555")
TOLERANCE = 1.0  # px; antialiasing alone can account for up to one pixel at an edge
INK_THRESHOLD = 0.08  # fraction of full brightness counted as ink, as in tool/marks.py

# Must match lib/home_page.dart (mark check sheet) and lib/tiles.dart (dock tile).
ORIGIN_X, ORIGIN_Y, COLUMNS = 64, 64, 8
TILE_W, TILE_H, CENTER_X, CENTER_Y = 224, 176, 112, 88

root = Path(__file__).resolve().parent.parent
expected = json.loads((root / "build" / "marks.json").read_text())


def adb(*args: str) -> bytes:
    return subprocess.run(["adb", "-s", TV, *args], capture_output=True, check=True, stdin=subprocess.DEVNULL).stdout


adb("shell", "am", "force-stop", "com.lucas.tv_home")
adb("logcat", "-c")
adb("shell", "am", "start", "-n", "com.lucas.tv_home/.MainActivity")
time.sleep(6)

log = adb("logcat", "-d", "-s", "flutter:I").decode(errors="replace")
order = re.findall(r"MARKS: (\S+)", log)
if not order:
    sys.exit("No MARKS line in the log: is the MARK_CHECK build installed?")
names = order[-1].split(",")

raw = adb("exec-out", "screencap", "-p")
shot = Image.open(io.BytesIO(raw[raw.find(b"\x89PNG"):])).convert("L")
if shot.size != (1920, 1080):
    sys.exit(f"Expected a 1920x1080 screenshot, got {shot.size}")
pixels = np.asarray(shot).astype(np.float64) / 255
shot.save(root / "build" / "marks-check.png")

failures = 0
print(f"{'mark':14} {'expected w x h':>16} {'measured w x h':>16} {'dx':>6} {'dy':>6} {'dw':>6} {'dh':>6}")
for i, name in enumerate(names):
    ox = ORIGIN_X + (i % COLUMNS) * TILE_W
    oy = ORIGIN_Y + (i // COLUMNS) * TILE_H
    tile = pixels[oy:oy + TILE_H, ox:ox + TILE_W]
    ink = tile > INK_THRESHOLD
    ys, xs = np.nonzero(ink)
    if len(xs) == 0:
        print(f"{name:14} no ink found")
        failures += 1
        continue
    # Box edges at pixel boundaries: a mark spanning columns 10..20 inclusive is 11 px wide.
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    w, h = x1 - x0, y1 - y0
    dx, dy = (x0 + x1) / 2 - CENTER_X, (y0 + y1) / 2 - (CENTER_Y + expected[name]["dy"])
    ew, eh = expected[name]["width"], expected[name]["height"]
    dw, dh = w - ew, h - eh
    ok = all(abs(v) <= TOLERANCE for v in (dx, dy)) and all(abs(v) <= TOLERANCE + 1 for v in (dw, dh))
    failures += not ok
    print(f"{name:14} {ew:7.2f} x {eh:6.2f} {w:7d} x {h:6d} {dx:+6.1f} {dy:+6.1f} {dw:+6.1f} {dh:+6.1f}  {'ok' if ok else 'OFF'}")

print(f"\n{len(names) - failures}/{len(names)} marks within tolerance. Screenshot: build/marks-check.png")
sys.exit(1 if failures else 0)
