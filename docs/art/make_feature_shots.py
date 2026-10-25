#!/usr/bin/env python3
"""Frames the app's raw renders into the feature screenshots in docs/features.

Run through mac/scripts/feature-screenshots.sh, which renders the app first. By hand:

    python3 -I docs/art/make_feature_shots.py seed <demo.json> <out.plist>
    python3 -I docs/art/make_feature_shots.py frame <raw dir> [feature id ...]

`seed` turns the demo settings into a plist for `defaults import`. `frame` reads spots.json from
the raw renders and writes docs/features/<id>.png for each feature in docs/features/features.json
(or only the ids given): the whole window or menu on the left, and the feature magnified on the
right under its title and caption. Needs rsvg-convert (brew install librsvg).
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
SCREEN_BOX = (90, 70, 640, 860)   # x, y, width, height the whole window or menu fits in
COLUMN = (820, 1510)             # left and right edge of the text and the magnifier
SPOT_PADDING = 10                # points of the screen kept around the feature in the lens
MAX_ZOOM = 3.0                   # canvas pixels per screen point in the lens
TITLE_LINE, CAPTION_LINE = 66, 38
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
    """The spot with a little room around it, kept inside the screen, in points."""
    x, y, w, h = spot
    left, top = max(0, x - SPOT_PADDING), max(0, y - SPOT_PADDING)
    return left, top, min(screen[2], x + w + SPOT_PADDING) - left, min(screen[3], y + h + SPOT_PADDING) - top


def wrap(text, limit):
    lines, line = [], ""
    for word in text.split():
        if line and len(line) + 1 + len(word) > limit:
            lines.append(line)
            line = word
        else:
            line = f"{line} {word}".strip()
    return lines + [line] if line else lines


def text_block(feature):
    """Eyebrow, title and caption at the top of the right column; returns (svg, bottom y)."""
    x = COLUMN[0]
    titles = wrap(feature["title"], 22)
    captions = wrap(feature["caption"], 44)
    title_y = 190
    caption_y = title_y + TITLE_LINE * (len(titles) - 1) + 62
    title = "".join(f'<tspan x="{x}" dy="{0 if i == 0 else TITLE_LINE}">{escape(t)}</tspan>' for i, t in enumerate(titles))
    caption = "".join(f'<tspan x="{x}" dy="{0 if i == 0 else CAPTION_LINE}">{escape(c)}</tspan>' for i, c in enumerate(captions))
    svg = f'''<text x="{x}" y="120" font-family="{FONT}" font-size="20" font-weight="700" letter-spacing="5" fill="{ACCENT}">POINTER COLORS</text>
  <text y="{title_y}" font-family="{FONT}" font-size="58" font-weight="800" fill="url(#hl)">{title}</text>
  <text y="{caption_y}" font-family="{FONT}" font-size="27" fill="#aab3c0">{caption}</text>'''
    return svg, caption_y + CAPTION_LINE * (len(captions) - 1) + 20


def placed(view_pt, box, zoom_limit):
    """Where a view of `view_pt` points sits, centered in `box`, and its zoom."""
    zoom = min(box[2] / view_pt[2], box[3] / view_pt[3], zoom_limit)
    w, h = view_pt[2] * zoom, view_pt[3] * zoom
    return box[0] + (box[2] - w) / 2, box[1] + (box[3] - h) / 2, w, h, zoom


def image(shot, pw, ph, view_pt, x, y, w, h, p):
    return (f'<svg x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
            f'viewBox="{view_pt[0] * p} {view_pt[1] * p} {view_pt[2] * p} {view_pt[3] * p}" preserveAspectRatio="none">'
            f'<image width="{pw}" height="{ph}" xlink:href="{shot}"/></svg>')


def svg_for(feature, shot_png, spot, screen, p):
    pw, ph = png_size(shot_png)
    shot = "data:image/png;base64," + base64.b64encode(shot_png).decode()
    text, text_bottom = text_block(feature)
    # The whole screen on the left, small enough to fit.
    x, y, w, h, scale = placed(screen, SCREEN_BOX, 1.0)
    lens_pt = padded(spot, screen)
    sx, sy = x + lens_pt[0] * scale, y + lens_pt[1] * scale
    sw, sh = lens_pt[2] * scale, lens_pt[3] * scale
    # The feature up close on the right, under the text.
    box = (COLUMN[0], text_bottom + 30, COLUMN[1] - COLUMN[0], HEIGHT - 70 - text_bottom - 30)
    lx, ly, lw, lh, _ = placed(lens_pt, box, MAX_ZOOM)
    lx = COLUMN[0]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">
  {backdrop(WIDTH, HEIGHT)}
  <defs>
    <linearGradient id="hl" x1="0" x2="1"><stop offset=".05" stop-color="{ACCENT}"/><stop offset=".95" stop-color="#ffffff"/></linearGradient>
    <linearGradient id="beam" x1="0" x2="1"><stop offset="0" stop-color="#ffffff" stop-opacity=".16"/><stop offset="1" stop-color="#ffffff" stop-opacity=".04"/></linearGradient>
    <clipPath id="screen"><rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="14"/></clipPath>
    <clipPath id="lens"><rect x="{lx:.1f}" y="{ly:.1f}" width="{lw:.1f}" height="{lh:.1f}" rx="20"/></clipPath>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="28" stdDeviation="30" flood-color="#000" flood-opacity=".7"/></filter>
  </defs>
  {text}
  <rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="14" fill="{BG}" filter="url(#shadow)"/>
  <g clip-path="url(#screen)">{image(shot, pw, ph, screen, x, y, w, h, p)}</g>
  <rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="14" fill="none" stroke="#ffffff" stroke-opacity=".12" stroke-width="2"/>
  <path d="M{sx + sw:.1f} {sy:.1f} L{lx:.1f} {ly:.1f} L{lx:.1f} {ly + lh:.1f} L{sx + sw:.1f} {sy + sh:.1f} Z" fill="url(#beam)"/>
  <line x1="{sx + sw:.1f}" y1="{sy:.1f}" x2="{lx:.1f}" y2="{ly:.1f}" stroke="#ffffff" stroke-opacity=".35" stroke-width="1.5"/>
  <line x1="{sx + sw:.1f}" y1="{sy + sh:.1f}" x2="{lx:.1f}" y2="{ly + lh:.1f}" stroke="#ffffff" stroke-opacity=".35" stroke-width="1.5"/>
  <rect x="{sx:.1f}" y="{sy:.1f}" width="{sw:.1f}" height="{sh:.1f}" rx="6" fill="#ffffff" fill-opacity=".08" stroke="#ffffff" stroke-opacity=".85" stroke-width="2"/>
  <rect x="{lx:.1f}" y="{ly:.1f}" width="{lw:.1f}" height="{lh:.1f}" rx="20" fill="{BG}" filter="url(#shadow)"/>
  <g clip-path="url(#lens)">{image(shot, pw, ph, lens_pt, lx, ly, lw, lh, p)}</g>
  <rect x="{lx:.1f}" y="{ly:.1f}" width="{lw:.1f}" height="{lh:.1f}" rx="20" fill="none" stroke="#ffffff" stroke-opacity=".9" stroke-width="4"/>
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
