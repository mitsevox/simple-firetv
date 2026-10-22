"""Measures every brand mark and lays them out optically, by kind, with per-mark nudges.

For each SVG in assets/icons (except the utility icons), this renders it at high resolution,
crops a copy to its ink (assets/marks), and measures it. Then it sizes and places each mark by
what kind of mark it is, because people read wordmarks like text and symbols like shapes:

  word    Lowercase wordmarks (max, hulu, tubi). Every one gets the same x-height and sits on a
          shared baseline, with the x-height band centred in the tile. Ascenders rise above it.
  symbol  Shapes. Sized so their silhouette (the convex hull of their ink, the shape a rubber
          band around them makes, so an outline icon counts as the shape it draws) has the same
          area, capped in height so tall, narrow marks don't tower. Centred between their box
          and their silhouette's centre of mass.
  width   Marks with no real area, like Prime's smile: given a width directly.

NUDGES then adjusts individual marks by eye: `scale` multiplies the size, `dy` moves the mark
down (design px). These are the case-by-case optical corrections no rule captures. A scaled
wordmark keeps the shared baseline.

Writes lib/mark_sizes.dart, build/marks.json, and build/marks-sheet.png: the marks in a dock row
at true size, with the tile centre line (red) and the wordmark baseline and x-height (blue).

Run from the launcher folder:  python3 tool/marks.py
"""

from __future__ import annotations

import io
import json
import re
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

X_HEIGHT = 27.0  # every wordmark's lowercase height, design px
SYMBOL_AREA = 2500.0  # silhouette area of every symbol, design px²
SYMBOL_MAX_H = 58.0
MAX_W = 136.0
CENTROID_PULL = 0.5  # 0 centres a symbol by its box, 1 by its silhouette's centre of mass

KINDS = {
    "hbomax": "word",
    "hulu": "word",
    "tubi": "word",
    "primevideo": "width",
}
WIDTHS = {"primevideo": 112.0}
NUDGES: dict[str, dict[str, float]] = {
    "netflix": {"scale": 0.945},  # tall and solid: reads larger than its area
    "youtube": {"scale": 1.1},  # wide and short: reads smaller than its area
    "jellyfin": {"scale": 0.9},  # bold triangle at full height towers over the row
    "disneyplus": {"scale": 1.08},  # thin script reads lighter than its silhouette
    "hulu": {"scale": 0.875},  # heavy letters and tall ascenders read bigger than max
    "primevideo": {"scale": 0.9},  # a long swoosh reads wider than its width
}

RENDER_PX = 2048
ALPHA_THRESHOLD = 8  # of 255; ignores the faintest antialiasing
UTILITY = {"apps", "art", "settings", "home"}

# Must match the dock tile in lib/tiles.dart.
TILE_W, TILE_H, CENTER_Y = 224, 176, 88

root = Path(__file__).resolve().parent.parent
src_dir = root / "assets" / "icons"
out_dir = root / "assets" / "marks"
build_dir = root / "build"
out_dir.mkdir(exist_ok=True)
build_dir.mkdir(exist_ok=True)


def render(svg: Path, width: int, height: int | None = None) -> np.ndarray:
    args = ["rsvg-convert", "-w", str(width)] + (["-h", str(height)] if height else [])
    png = subprocess.run(args + [str(svg)], capture_output=True, check=True).stdout
    return np.asarray(Image.open(io.BytesIO(png)).convert("RGBA"))


def viewbox(text: str) -> list[float]:
    return [float(v) for v in re.search(r'viewBox="([^"]+)"', text).group(1).replace(",", " ").split()]


def silhouette(ink: np.ndarray) -> np.ndarray:
    """The convex hull of the ink, filled."""
    ys, xs = np.nonzero(ink)
    # Each row's leftmost and rightmost ink is enough to find the hull.
    points = sorted({(int(x), int(y)) for y in np.unique(ys)
                     for x in (xs[ys == y].min(), xs[ys == y].max() + 1)})

    def half(pts):
        out = []
        for p in pts:
            while len(out) >= 2 and (out[-1][0] - out[-2][0]) * (p[1] - out[-2][1]) - (out[-1][1] - out[-2][1]) * (p[0] - out[-2][0]) <= 0:
                out.pop()
            out.append(p)
        return out

    hull = half(points)[:-1] + half(points[::-1])[:-1]
    mask = Image.new("1", (ink.shape[1], ink.shape[0]))
    ImageDraw.Draw(mask).polygon(hull, fill=1)
    return np.asarray(mask)


def x_height_fraction(ink: np.ndarray) -> float:
    """Fraction of a wordmark's height taken by its lowercase letters, from the row profile: the
    x-height band is where rows are densely inked, ascenders above it are sparse stems."""
    rows = ink.mean(1)
    dense = rows > 0.6 * np.median(rows[len(rows) // 2:])
    top = int(np.argmax(dense))
    return (len(rows) - top) / len(rows)


marks = {}
for svg in sorted(src_dir.glob("*.svg")):
    name = svg.stem
    if name in UTILITY:
        continue
    text = svg.read_text()
    vx, vy, vw, vh = viewbox(text)
    alpha = render(svg, RENDER_PX)[:, :, 3]
    scale = alpha.shape[1] / vw
    ys, xs = np.nonzero(alpha > ALPHA_THRESHOLD)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    ink = alpha[y0:y1, x0:x1] > ALPHA_THRESHOLD

    crop = [vx + x0 / scale, vy + y0 / scale, (x1 - x0) / scale, (y1 - y0) / scale]
    cropped = re.sub(r'viewBox="[^"]+"', 'viewBox="%s"' % " ".join(f"{v:.4f}" for v in crop), text, count=1)
    (out_dir / svg.name).write_text(cropped)

    kind = KINDS.get(name, "symbol")
    aspect = crop[2] / crop[3]
    m = {"kind": kind, "aspect": aspect}
    if kind == "word":
        m["x_height"] = x_height_fraction(ink)
        h = X_HEIGHT / m["x_height"]
        w = h * aspect
        # Put the baseline X_HEIGHT/2 below the tile centre: box-centred top is -h/2.
        dy = X_HEIGHT / 2 - h / 2
    elif kind == "width":
        w = WIDTHS[name]
        h = w / aspect
        dy = 0.0
    else:
        shape = silhouette(ink)
        m["fill"] = float(shape.mean())
        h = (SYMBOL_AREA / (aspect * m["fill"])) ** 0.5
        h = min(h, SYMBOL_MAX_H)
        w = h * aspect
        cy = np.nonzero(shape)[0].mean() / shape.shape[0]  # 0.5 is the box centre
        dy = -CENTROID_PULL * (cy - 0.5) * h
    if w > MAX_W:
        h, w, dy = h * MAX_W / w, MAX_W, dy * MAX_W / w

    nudge = NUDGES.get(name, {})
    k = nudge.get("scale", 1.0)
    # Symbols scale about their own placement; wordmarks stay on the shared baseline.
    dy = X_HEIGHT / 2 - h * k / 2 if kind == "word" else dy * k
    m["width"], m["height"] = round(w * k, 2), round(h * k, 2)
    m["dy"] = round(dy + nudge.get("dy", 0.0), 2)
    marks[name] = m

lines = [
    "// Generated by tool/marks.py from assets/icons. Do not edit; rerun the script instead.",
    "",
    "/// Each mark in assets/marks: its size, and how far below the tile centre to place its box's",
    "/// centre, in design px.",
    "const markLayouts = <String, ({double width, double height, double dy})>{",
    *[f"  '{n}': (width: {m['width']}, height: {m['height']}, dy: {m['dy']})," for n, m in marks.items()],
    "};",
    "",
]
(root / "lib" / "mark_sizes.dart").write_text("\n".join(lines))
(build_dir / "marks.json").write_text(json.dumps(marks, indent=2))

# Sheet: the dock's marks in a row at true size on dock glass, with guides.
order = ["netflix", "youtube", "disneyplus", "hbomax", "hulu", "primevideo", "spotify", "airplay",
         "jellyfin", "peacock", "paramountplus", "tubi", "appletv", "stremio"]
order = [n for n in order if n in marks]
sheet = Image.new("RGB", (len(order) * TILE_W, TILE_H), (34, 40, 48))
draw = ImageDraw.Draw(sheet)
baseline = CENTER_Y + X_HEIGHT / 2
for y, color in ((CENTER_Y, (110, 50, 50)), (baseline, (50, 70, 120)), (baseline - X_HEIGHT, (50, 70, 120))):
    draw.line([0, y, sheet.width, y], fill=color)
for i, name in enumerate(order):
    m = marks[name]
    w, h = round(m["width"]), round(m["height"])
    glyph = render(out_dir / f"{name}.svg", w, h)
    white = Image.new("RGBA", (w, h), (244, 244, 241, 255))
    white.putalpha(Image.fromarray(glyph[:, :, 3]))
    left = i * TILE_W + (TILE_W - w) // 2
    top = round(CENTER_Y + m["dy"] - h / 2)
    sheet.paste(white, (left, top), white)
    draw.text((i * TILE_W + 8, TILE_H - 16), name, fill=(110, 116, 122))
sheet.save(build_dir / "marks-sheet.png")

for n, m in marks.items():
    extra = f"x-height {m['x_height']:.2f}" if "x_height" in m else (f"fill {m['fill']:.2f}" if "fill" in m else "")
    print(f"{n:14} {m['kind']:6} {m['width']:6.1f} x {m['height']:5.1f}  dy {m['dy']:+5.1f}   {extra}")
