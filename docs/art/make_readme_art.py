#!/usr/bin/env python3
"""Draws the README images from pairs.json and the app screenshot.

    python3 -I docs/art/make_readme_art.py

Writes docs/readme-hero.png, docs/readme-pairs.png, docs/readme-download.png and docs/og-image.png
(the 1200 x 630 link preview the website names in its og:image and twitter:image tags).
Needs rsvg-convert (brew install librsvg). Re-run it after changing pairs.json or docs/mac-app.png.
"""
import base64
import json
import subprocess
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"
ARROW = "M3 2 L3 24 L8.6 18.8 L12.2 27.2 L16 25.6 L12.4 17.4 L19.8 17.4 Z"
FONT = "SF Pro Display, Helvetica Neue, Arial, sans-serif"
BG = "#08090c"
GROUP_TITLES = {"default": "DEFAULT", "neon": "NEON", "colors": "COLORS"}


def pointer(x, y, scale, outline, fill, stroke=2.0):
    return (f'<g transform="translate({x} {y}) scale({scale})">'
            f'<path d="{ARROW}" fill="#{fill}" stroke="#{outline}" stroke-width="{stroke}" '
            f'stroke-linejoin="round"/></g>')


def backdrop(width, height, glow_a="#00FFDA", glow_b="#008A59", rx=40):
    """Dark ground, two soft glows and a faint grid, like the website's Mac section."""
    return f'''
  <defs>
    <radialGradient id="ga" cx="0.82" cy="0.18" r="0.55"><stop offset="0" stop-color="{glow_a}" stop-opacity=".45"/><stop offset="1" stop-color="{glow_a}" stop-opacity="0"/></radialGradient>
    <radialGradient id="gb" cx="0.62" cy="1.0" r="0.6"><stop offset="0" stop-color="{glow_b}" stop-opacity=".55"/><stop offset="1" stop-color="{glow_b}" stop-opacity="0"/></radialGradient>
    <pattern id="grid" width="56" height="56" patternUnits="userSpaceOnUse"><path d="M56 0H0V56" fill="none" stroke="#ffffff" stroke-opacity=".05"/></pattern>
    <radialGradient id="gridfade" cx="0.3" cy="0.45" r="0.65"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
    <mask id="gridmask"><rect width="{width}" height="{height}" fill="url(#gridfade)"/></mask>
  </defs>
  <rect width="{width}" height="{height}" rx="{rx}" fill="{BG}"/>
  <rect width="{width}" height="{height}" rx="{rx}" fill="url(#ga)"/>
  <rect width="{width}" height="{height}" rx="{rx}" fill="url(#gb)"/>
  <rect width="{width}" height="{height}" rx="{rx}" fill="url(#grid)" mask="url(#gridmask)"/>
  <rect x="1" y="1" width="{width - 2}" height="{height - 2}" rx="{max(rx - 1, 0)}" fill="none" stroke="#ffffff" stroke-opacity=".08" stroke-width="2"/>'''


def hero(pairs, h=820, rx=40, out_w=None):
    """The README hero; the link preview draws it square-cornered at 1600 x 840 (1.91:1), shown at 1200 x 630."""
    w = 1600
    out_w = out_w or w
    out_h = round(h * out_w / w)
    # Embedded as data: rsvg-convert refuses file links outside the SVG's own folder.
    shot = "data:image/png;base64," + base64.b64encode((DOCS / "mac-app.png").read_bytes()).decode()
    strip = [p for p in pairs if p.get("group") == "neon"][:9]
    strip_svg = "".join(pointer(130 + i * 58, 600, 1.55, p["outline"], p["fill"]) for i, p in enumerate(strip))
    return f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{out_w}" height="{out_h}" viewBox="0 0 {w} {h}">
  {backdrop(w, h, rx=rx)}
  <defs>
    <linearGradient id="hl" x1="0" x2="1"><stop offset=".05" stop-color="#00FFDA"/><stop offset=".95" stop-color="#ffffff"/></linearGradient>
    <clipPath id="shotclip"><rect x="0" y="0" width="560" height="760" rx="28"/></clipPath>
    <linearGradient id="shotfade" x1="0" y1="0" x2="0" y2="1"><stop offset=".7" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <mask id="shotmask"><rect width="560" height="760" fill="url(#shotfade)"/></mask>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="40" stdDeviation="40" flood-color="#000" flood-opacity=".7"/></filter>
  </defs>

  <g font-family="{FONT}">
    <rect x="130" y="120" width="392" height="42" rx="21" fill="#ffffff" fill-opacity=".04" stroke="#ffffff" stroke-opacity=".16"/>
    <circle cx="156" cy="141" r="5" fill="#00FFDA" filter="url(#glow)"/>
    <text x="174" y="147" font-size="15" font-weight="600" letter-spacing="2.4" fill="#ffffff" fill-opacity=".75">POINTER COLORS FOR MAC · FREE</text>

    <text font-size="96" font-weight="800" letter-spacing="-4" fill="#ffffff">
      <tspan x="124" y="290">Your pointer,</tspan>
      <tspan x="124" y="388" fill="url(#hl)">one click</tspan>
      <tspan x="124" y="486">away.</tspan>
    </text>
    <text x="130" y="548" font-size="24" fill="#ffffff" fill-opacity=".7">Apply any pointer color pair from the menu bar.</text>
    {strip_svg}
    <text x="130" y="720" font-size="18" font-weight="600" fill="#ffffff" fill-opacity=".5">macOS 14+  ·  English &amp; العربية  ·  macos-pointer-colors.pages.dev</text>
  </g>

  <g transform="translate(940 64) rotate(3)" filter="url(#shadow)">
    <g clip-path="url(#shotclip)" mask="url(#shotmask)">
      <image xlink:href="{shot}" x="0" y="0" width="560" height="1241" preserveAspectRatio="xMidYMin slice"/>
    </g>
    <rect x="0" y="0" width="560" height="760" rx="28" fill="none" stroke="#ffffff" stroke-opacity=".12" stroke-width="2"/>
  </g>
  <g filter="url(#glow)">{pointer(860, 430, 5.2, "00FFDA", "008A59", 1.4)}</g>
</svg>'''


def pairs_grid(pairs):
    cols, cell_w, cell_h, pad = 8, 200, 112, 64
    rows, y, groups = [], 0, []
    for p in pairs:
        if not groups or groups[-1][0] != p.get("group"):
            groups.append((p.get("group"), []))
        groups[-1][1].append(p)
    parts = []
    y = pad
    for name, items in groups:
        parts.append(f'<text x="{pad}" y="{y + 18}" font-size="15" font-weight="700" letter-spacing="2.4" fill="#ffffff" fill-opacity=".55">{GROUP_TITLES.get(name, "COLORS")}</text>')
        y += 40
        for i, p in enumerate(items):
            col, row = i % cols, i // cols
            cx, cy = pad + col * cell_w, y + row * cell_h
            parts.append(f'<rect x="{cx}" y="{cy}" width="{cell_w - 12}" height="{cell_h - 12}" rx="18" fill="#ffffff" fill-opacity=".035" stroke="#ffffff" stroke-opacity=".08"/>')
            parts.append(pointer(cx + 18, cy + 20, 2.1, p["outline"], p["fill"]))
            parts.append(f'<text x="{cx + 68}" y="{cy + 44}" font-size="17" font-weight="600" fill="#ffffff">{escape(p["name"])}</text>')
            parts.append(f'<text x="{cx + 68}" y="{cy + 68}" font-size="13" fill="#ffffff" fill-opacity=".5">{p["outline"]} / {p["fill"]}</text>')
        y += ((len(items) - 1) // cols + 1) * cell_h + 28
    w, h = pad * 2 + cols * cell_w - 12, y + pad - 28
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  {backdrop(w, h, "#7C3AED", "#00FFDA")}
  <g font-family="{FONT}">{"".join(parts)}</g>
</svg>'''


def download_button():
    w, h = 620, 120
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <defs><filter id="s" x="-20%" y="-40%" width="140%" height="200%"><feDropShadow dx="0" dy="14" stdDeviation="16" flood-color="#00FFDA" flood-opacity=".45"/></filter></defs>
  <rect x="20" y="14" width="{w - 40}" height="84" rx="42" fill="#ffffff" filter="url(#s)"/>
  <g transform="translate(78 36)" fill="none" stroke="#0b0c10" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"><path d="M20 4v24M10 18l10 10 10-10M6 38h28"/></g>
  <text x="134" y="68" font-family="{FONT}" font-size="30" font-weight="700" fill="#0b0c10">Download for macOS</text>
  <text x="446" y="68" font-family="{FONT}" font-size="22" font-weight="600" fill="#0b0c10" fill-opacity=".5">.dmg</text>
</svg>'''


def render(name, svg, scale=2):
    out = DOCS / f"{name}.png"
    subprocess.run(["rsvg-convert", "--zoom", str(scale), "-o", str(out)], input=svg.encode(), check=True)
    print("Wrote", out.relative_to(ROOT))


def main():
    pairs = json.loads((ROOT / "pairs.json").read_text(encoding="utf-8"))["pairs"]
    render("readme-hero", hero(pairs))
    render("readme-pairs", pairs_grid(pairs))
    render("readme-download", download_button())
    render("og-image", hero(pairs, h=840, rx=0, out_w=1200), scale=1)


if __name__ == "__main__":
    main()
