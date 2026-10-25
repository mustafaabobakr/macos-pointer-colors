#!/usr/bin/env python3
"""Frames the app's raw renders into the feature screenshots in docs/features.

Run through mac/scripts/feature-screenshots.sh, which renders the app first. By hand:

    python3 -I docs/art/make_feature_shots.py seed <demo.json> <out.plist>
    python3 -I docs/art/make_feature_shots.py frame <raw dir> [feature id ...]

`seed` turns the demo settings into a plist for `defaults import`. `frame` reads spots.json from
the raw renders and writes docs/features/<id>.png for each feature in docs/features/features.json
(or only the ids given): the screen cropped around the feature, everything else dimmed, the
feature ringed, under its title and caption. Needs rsvg-convert (brew install librsvg).
"""
import base64
import json
import plistlib
import struct
import subprocess
import sys
from pathlib import Path
from xml.sax.saxutils import escape

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_readme_art import BG, FONT, backdrop  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
FEATURES = ROOT / "docs" / "features"
CATALOG = FEATURES / "features.json"

WIDTH, HEIGHT = 1600, 1000
CONTEXT = 30                   # points of the screen kept around the feature
SPOT_PADDING = 8               # points between the feature and its ring
IMAGE_BOX = (100, 300, 1400, 640)  # x, y, width, height the zoomed screen fits in
CAPTION_LINE = 40
MAX_ZOOM = 2.4                 # canvas pixels per screen point
ACCENT = "#00FFDA"


def seed(demo_path, out_path):
    demo = json.loads(Path(demo_path).read_text())
    settings = dict(demo["settings"])
    for key, value in demo.get("jsonData", {}).items():
        settings[key] = json.dumps(value, separators=(",", ":")).encode()
    Path(out_path).write_bytes(plistlib.dumps(settings, fmt=plistlib.FMT_XML))


def png_size(data):
    return struct.unpack(">II", data[16:24])


def padded(spot, screen):
    """The spot with room for its ring, kept inside the screen, in points."""
    x, y, w, h = spot
    left, top = max(0, x - SPOT_PADDING), max(0, y - SPOT_PADDING)
    return left, top, min(screen[2], x + w + SPOT_PADDING) - left, min(screen[3], y + h + SPOT_PADDING) - top


def crop_for(spot, screen):
    """The spot plus some context, kept inside the screen, in points."""
    x, y, w, h = spot
    left, top = max(0, x - CONTEXT), max(0, y - CONTEXT)
    right, bottom = min(screen[2], x + w + CONTEXT), min(screen[3], y + h + CONTEXT)
    return left, top, right - left, bottom - top


def wrap(text, limit):
    lines, line = [], ""
    for word in text.split():
        if line and len(line) + 1 + len(word) > limit:
            lines.append(line)
            line = word
        else:
            line = f"{line} {word}".strip()
    return lines + [line] if line else lines


def svg_for(feature, shot_png, spot, screen, p):
    spot = padded(spot, screen)
    cx, cy, cw, ch = crop_for(spot, screen)
    lines = wrap(feature["caption"], 84)
    # A second caption line pushes the screen down.
    extra = CAPTION_LINE * (len(lines) - 1)
    box_x, box_y, box_w, box_h = IMAGE_BOX[0], IMAGE_BOX[1] + extra, IMAGE_BOX[2], IMAGE_BOX[3] - extra
    zoom = min(box_w / cw, box_h / ch, MAX_ZOOM)
    w, h = cw * zoom, ch * zoom
    x, y = box_x + (box_w - w) / 2, box_y + (box_h - h) / 2
    # The feature inside the zoomed screen, in canvas pixels.
    sx, sy = x + (spot[0] - cx) * zoom, y + (spot[1] - cy) * zoom
    sw, sh = spot[2] * zoom, spot[3] * zoom
    pw, ph = png_size(shot_png)
    shot = "data:image/png;base64," + base64.b64encode(shot_png).decode()
    caption = "".join(f'<tspan x="100" dy="{0 if i == 0 else CAPTION_LINE}">{escape(line)}</tspan>'
                      for i, line in enumerate(lines))
    return f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">
  {backdrop(WIDTH, HEIGHT)}
  <defs>
    <linearGradient id="hl" x1="0" x2="1"><stop offset=".05" stop-color="{ACCENT}"/><stop offset=".95" stop-color="#ffffff"/></linearGradient>
    <clipPath id="card"><rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="22"/></clipPath>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="30" stdDeviation="34" flood-color="#000" flood-opacity=".65"/></filter>
    <filter id="glow" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="9" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  </defs>
  <text x="100" y="118" font-family="{FONT}" font-size="22" font-weight="700" letter-spacing="5" fill="{ACCENT}">POINTER COLORS</text>
  <text x="100" y="196" font-family="{FONT}" font-size="66" font-weight="800" fill="url(#hl)">{escape(feature["title"])}</text>
  <text y="252" font-family="{FONT}" font-size="30" fill="#aab3c0">{caption}</text>
  <rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="22" fill="{BG}" filter="url(#shadow)"/>
  <g clip-path="url(#card)">
    <svg x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" viewBox="{cx * p} {cy * p} {cw * p} {ch * p}" preserveAspectRatio="none">
      <image width="{pw}" height="{ph}" xlink:href="{shot}"/>
    </svg>
    <path fill-rule="evenodd" fill="#000" fill-opacity=".5"
          d="M{x:.1f} {y:.1f}h{w:.1f}v{h:.1f}h{-w:.1f}Z M{sx:.1f} {sy:.1f}h{sw:.1f}v{sh:.1f}h{-sw:.1f}Z"/>
  </g>
  <rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="22" fill="none" stroke="#ffffff" stroke-opacity=".12" stroke-width="2"/>
  <rect x="{sx:.1f}" y="{sy:.1f}" width="{sw:.1f}" height="{sh:.1f}" rx="16" fill="none" stroke="{ACCENT}" stroke-width="3.5" filter="url(#glow)"/>
</svg>'''


def frame(raw_dir, only):
    raw = Path(raw_dir)
    spots = json.loads((raw / "spots.json").read_text())
    pixels_per_point = spots.pop("_render")["pixelsPerPoint"][0]
    features = json.loads(CATALOG.read_text())["features"]
    wanted = [f for f in features if not only or f["id"] in only]
    missing = [f["id"] for f in wanted if f["spot"] not in spots.get(f["screen"], {})]
    if missing:
        sys.exit(f"error: no .featureSpot found for {', '.join(missing)}; mark the view in the app")
    for feature in wanted:
        screen_spots = spots[feature["screen"]]
        svg = svg_for(feature, (raw / f"{feature['screen']}.png").read_bytes(),
                      screen_spots[feature["spot"]], screen_spots["_screen"], pixels_per_point)
        out = FEATURES / f"{feature['id']}.png"
        subprocess.run(["rsvg-convert", "-o", str(out)], input=svg.encode(), check=True)
        print(f"Wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "seed":
        seed(sys.argv[2], sys.argv[3])
    elif len(sys.argv) >= 3 and sys.argv[1] == "frame":
        frame(sys.argv[2], set(sys.argv[3:]))
    else:
        sys.exit(__doc__)
