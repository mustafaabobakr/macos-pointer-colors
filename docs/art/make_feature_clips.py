#!/usr/bin/env python3
"""Turns the app's feature recordings into the clips in docs/features.

Run through mac/scripts/feature-clips.sh, which records the app first. By hand:

    python3 -I docs/art/make_feature_clips.py seed <demo.json> <out.plist>
    python3 -I docs/art/make_feature_clips.py list [feature id ...]
    python3 -I docs/art/make_feature_clips.py make <raw dir> [feature id ...]

`seed` turns the demo settings into a plist for `defaults import`. `list` prints "id screen spot" for each feature in docs/features/features.json (or only the ids
given), for the recorder. `make` reads each feature's recording from <raw dir>/<id> and writes
docs/features/<id>.webp, a looping clip of a Mac desktop: the menu open under its menu bar icon,
or a Preferences window scrolled to the feature. It starts on the whole desktop with the
feature's title, what it does and when to use it, zooms into the feature for its demo, with the
pointer drawn in the pair's colors and size, and zooms back out.

The desktop picture is macOS Sonoma's, read from this Mac at render time, so the repo never holds
Apple's file. Needs rsvg-convert and img2webp (brew install librsvg webp).
"""
import json
import os
import plistlib
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from xml.sax.saxutils import escape

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_readme_art import ARROW  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
FEATURES = ROOT / "docs" / "features"
CATALOG = FEATURES / "features.json"
WALLPAPER = Path("/System/Library/Desktop Pictures/Sonoma.heic")

WIDTH, HEIGHT = 1280, 800        # the clip, in pixels
DESK_W, DESK_H = 1440, 900       # the desktop it shows, in points: a 16:10 Mac screen
ASPECT = DESK_W / DESK_H
MENU_BAR, TITLE_BAR = 24, 28
ICON_X = 1262                    # the app's menu bar icon, left edge
FPS = 25
INTRO, ZOOM_IN, ZOOM_OUT, OUTRO = 3.6, 0.9, 0.8, 0.6   # seconds
TEXT_IN, TEXT_OUT = 0.35, 0.45   # the text fades in, then out before the zoom
QUALITY = 72
FONT = "SF Pro, SF Pro Text, Helvetica Neue, Arial, sans-serif"
ACCENT = "#00FFDA"
WINDOW_BG = "#1e1e1e"
TITLES = {"menu": "", "update": "Software Update"}


def features(only):
    catalog = json.loads(CATALOG.read_text())["features"]
    return [f for f in catalog if not only or f["id"] in only]


def seed(demo_path, out_path):
    demo = json.loads(Path(demo_path).read_text())
    settings = dict(demo["settings"])
    for key, value in demo.get("jsonData", {}).items():
        settings[key] = json.dumps(value, separators=(",", ":")).encode()
    Path(out_path).write_bytes(plistlib.dumps(settings, fmt=plistlib.FMT_XML))


def list_features(only):
    for feature in features(only):
        print(feature["id"], feature["screen"], feature["spot"])


# MARK: Layout

def scroll_for(clip, view_h):
    """How far a tall tab is scrolled so the feature shows under the tab bar."""
    sh = clip["screen"][1]
    if sh <= view_h:
        return 0
    header = clip["header"]
    fy, fh = clip["focus"][1], clip["focus"][3]
    if fh > view_h - header - 32:
        wanted = fy - header - 16
    else:
        wanted = fy + fh / 2 - (header + view_h) / 2
    return min(max(wanted, 0), sh - view_h)


def layout(clip, screen):
    """Where the menu or window sits on the desktop: its frame, where its content starts, the
    part of the content showing and how far that's scrolled."""
    sw, sh = clip["screen"]
    is_menu = screen == "menu"
    title = 0 if is_menu else TITLE_BAR
    view_h = min(sh, DESK_H - MENU_BAR - title - (14 if is_menu else 60))
    x = min(ICON_X - 14, DESK_W - sw - 8) if is_menu else (DESK_W - sw) / 2
    top = MENU_BAR + 6 if is_menu else MENU_BAR + (DESK_H - MENU_BAR - title - view_h) / 2
    return {"menu": is_menu, "title": TITLES.get(screen, "Preferences"), "window": (x, top, sw, title + view_h),
            "view": (x, top + title, sw, view_h), "scroll": scroll_for(clip, view_h), "header": clip["header"]}


def on_desktop(place, x, y):
    """A point on the rendered screen, on the desktop."""
    vx, vy = place["view"][:2]
    return vx + x, vy + y - (place["scroll"] if y >= place["header"] else 0)


# MARK: Camera

def fitted(rect):
    """`rect` (x, y, w, h in points) grown to the clip's shape around its center."""
    x, y, w, h = rect
    if w / h < ASPECT:
        return x - (h * ASPECT - w) / 2, y, h * ASPECT, h
    return x, y - (w / ASPECT - h) / 2, w, w / ASPECT


def close_up(clip, place):
    fx, fy, fw, fh = clip["focus"]
    x, y = on_desktop(place, fx, fy)
    return fitted((x, y, fw, fh))


def eased(t):
    return 2 * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 2 / 2


def between(a, b, t):
    """A camera part way from `a` to `b`: the center slides, and the zoom changes evenly."""
    e = eased(t)
    ax, ay = a[0] + a[2] / 2, a[1] + a[3] / 2
    bx, by = b[0] + b[2] / 2, b[1] + b[3] / 2
    cx, cy = ax + (bx - ax) * e, ay + (by - ay) * e
    w = a[2] * (b[2] / a[2]) ** e
    return cx - w / 2, cy - w / ASPECT / 2, w, w / ASPECT


# MARK: The desktop

def menu_bar(place):
    front = ["Finder", "File", "Edit", "View", "Go", "Window", "Help"] if place["menu"] \
        else ["Pointer Colors", "Edit", "Window", "Help"]
    items, x = [], 46
    for index, name in enumerate(front):
        weight = "700" if index == 0 else "400"
        items.append(f'<text x="{x}" y="16.5" font-size="13" font-weight="{weight}">{escape(name)}</text>')
        x += len(name) * (8.2 if index == 0 else 7.4) + 20
    open_icon = (f'<rect x="{ICON_X - 7}" y="2.5" width="29" height="19" rx="5" fill="#ffffff" fill-opacity=".22"/>'
                 if place["menu"] else "")
    return f'''<rect width="{DESK_W}" height="{MENU_BAR}" fill="#000" fill-opacity=".28"/>
  <g font-family="{FONT}" fill="#fff">
    <text x="18" y="17" font-size="15">&#xF8FF;</text>
    {"".join(items)}
    <text x="{DESK_W - 16}" y="16.5" font-size="13" text-anchor="end">Wed Oct 28  9:41</text>
  </g>
  {open_icon}'''


def window_chrome(place):
    x, y, w, h = place["window"]
    radius = 12 if place["menu"] else 10
    shadow = (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="#000" '
              f'filter="url(#shadow)"/>')
    body = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{WINDOW_BG}"/>'
    return shadow + body


def title_bar(place, dark):
    """A window's title bar, light or dark with the app's theme. A menu has none."""
    if place["menu"]:
        return ""
    x, y, w, _ = place["window"]
    lights = "".join(f'<circle cx="{x + 20 + 20 * i}" cy="{y + 14}" r="6" fill="{color}"/>'
                     for i, color in enumerate(["#ff5f57", "#febc2e", "#28c840"]))
    title = (f'<text x="{x + w / 2}" y="{y + 18.5}" font-family="{FONT}" font-size="13" font-weight="600" '
             f'fill="{"#e6e6e6" if dark else "#262626"}" text-anchor="middle">{escape(place["title"])}</text>')
    bar = (f'<path d="M{x} {y + TITLE_BAR}V{y + 10}a10 10 0 0 1 10-10H{x + w - 10}a10 10 0 0 1 10 10'
           f'V{y + TITLE_BAR}Z" fill="{"#2c2c2c" if dark else "#ececec"}"/>')
    return bar + lights + title


def stage(place):
    """Everything that stays put through the clip, drawn once."""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{DESK_W}" height="{DESK_H}">
  <defs><filter id="shadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="18" stdDeviation="24" flood-color="#000" flood-opacity=".55"/></filter></defs>
  <image width="{DESK_W}" height="{DESK_H}" preserveAspectRatio="xMidYMid slice" xlink:href="wallpaper.jpg"/>
  {menu_bar(place)}
  {window_chrome(place)}
</svg>'''


# MARK: Each frame

def wrap(text, limit):
    lines, line = [], ""
    for word in text.split():
        if line and len(line) + 1 + len(word) > limit:
            lines.append(line)
            line = word
        else:
            line = f"{line} {word}".strip()
    return lines + [line] if line else lines


def text_block(feature, opacity):
    """Title, what the feature does and when to use it, over the bottom of the clip."""
    if opacity <= 0:
        return ""
    x = 64
    blocks = [(wrap(feature["title"], 34), 56, 64, "800", "url(#hl)"),
              (wrap(feature["caption"], 74), 28, 38, "500", "#f2f4f7")]
    if feature.get("use"):
        blocks.append((wrap(feature["use"], 80), 25, 35, "600", ACCENT))
    height = sum(line * len(lines) + 14 for lines, _, line, _, _ in blocks)
    y = HEIGHT - 60 - height + 10 * (1 - opacity)
    parts = []
    for lines, size, line, weight, fill in blocks:
        for text in lines:
            y += line
            parts.append(f'<text x="{x}" y="{y:.1f}" font-family="{FONT}" font-size="{size}" '
                         f'font-weight="{weight}" fill="{fill}">{escape(text)}</text>')
        y += 14
    return f'<g opacity="{opacity:.3f}"><rect width="{WIDTH}" height="{HEIGHT}" fill="url(#scrim)"/>{"".join(parts)}</g>'


def cursor(place, frame):
    """The pointer at its spot, in the pair's colors and size, a little smaller while pressed."""
    x, y, pressed, scale, outline, fill = frame[:6]
    x, y = on_desktop(place, x, y)
    size = scale * (0.88 if pressed else 1)
    shape = f'd="{ARROW}" stroke-width="2" stroke-linejoin="round"'
    return (f'<g transform="translate({x:.2f} {y:.2f}) scale({size:.3f}) translate(-3 -2)">'
            f'<path {shape} transform="translate(1.2 1.6)" fill="#000" fill-opacity=".35"/>'
            f'<path {shape} fill="#{fill}" stroke="#{outline}"/></g>')


def keycaps(label):
    """A shortcut being pressed, as keycaps near the bottom of the clip."""
    if not label:
        return ""
    keys = label.split()
    widths = [max(96, 36 * len(key) + 44) for key in keys]
    x = (WIDTH - sum(widths) - 18 * (len(keys) - 1)) / 2
    parts = []
    for key, w in zip(keys, widths):
        parts.append(f'<rect x="{x:.1f}" y="{HEIGHT - 170}" width="{w}" height="96" rx="20" fill="#1c1c1e" '
                     f'fill-opacity=".94" stroke="#ffffff" stroke-opacity=".3" stroke-width="2"/>'
                     f'<text x="{x + w / 2:.1f}" y="{HEIGHT - 106}" font-family="{FONT}" font-size="50" '
                     f'font-weight="600" fill="#fff" text-anchor="middle">{escape(key)}</text>')
        x += w + 18
    return "".join(parts)


def content(clip, place, screen_png, live_png):
    """The menu's or window's content, scrolled, with the live frame over the feature. A tab's
    tab bar stays at the top while the rest scrolls."""
    sw, sh = clip["screen"]
    vx, vy, vw, vh = place["view"]
    cx, cy, cw, ch = clip["capture"]
    live = f'<image x="{cx}" y="{cy}" width="{cw}" height="{ch}" xlink:href="{live_png}"/>' if live_png else ""
    pictures = f'<image width="{sw}" height="{sh}" xlink:href="{screen_png}"/>{live}'
    radius = 12 if place["menu"] else 10
    body = f'<svg x="{vx}" y="{vy}" width="{vw}" height="{vh}" viewBox="0 {place["scroll"]:.2f} {vw} {vh}">{pictures}</svg>'
    header = ""
    if place["scroll"] and place["header"]:
        h = place["header"]
        header = f'<svg x="{vx}" y="{vy}" width="{vw}" height="{h}" viewBox="0 0 {vw} {h}">{pictures}</svg>'
    shape = f'<clipPath id="win"><rect x="{vx}" y="{vy - radius}" width="{vw}" height="{vh + radius}" rx="{radius}"/></clipPath>'
    return f'{shape}<g clip-path="url(#win)">{body}{header}</g>'


def scene(clip, place, camera, screen_png, live_png, frame, text):
    """One frame: the desktop seen through `camera`, with the pointer and the text."""
    scale = WIDTH / camera[2]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">
  <defs>
    <linearGradient id="hl" x1="0" x2="1"><stop offset=".05" stop-color="{ACCENT}"/><stop offset=".95" stop-color="#ffffff"/></linearGradient>
    <linearGradient id="scrim" x1="0" x2="0" y1="0" y2="1"><stop offset=".3" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".85"/></linearGradient>
  </defs>
  <g transform="scale({scale:.5f}) translate({-camera[0]:.3f} {-camera[1]:.3f})">
    <image width="{DESK_W}" height="{DESK_H}" xlink:href="stage.jpg"/>
    {title_bar(place, frame[7])}
    {content(clip, place, screen_png, live_png)}
    <image x="{ICON_X}" y="3" width="15" height="18" xlink:href="{frame[6]}"/>
    {cursor(place, frame)}
  </g>
  {keycaps(frame[8])}
  {text}
</svg>'''


# MARK: Timeline

def text_opacity(t):
    fade_out = INTRO - 0.25 - TEXT_OUT
    if t < TEXT_IN:
        return t / TEXT_IN
    if t < fade_out:
        return 1
    return max(0, 1 - (t - fade_out) / TEXT_OUT)


def timeline(feature, clip, place):
    """Every frame of the clip as its SVG."""
    wide = (0, 0, DESK_W, DESK_H)
    tight = close_up(clip, place)
    frames = clip["frames"]

    def shot(camera, screen_png, live_png, frame, text=""):
        return scene(clip, place, camera, screen_png, live_png, frame, text)

    shots = [shot(wide, "start.png", None, frames[0], text_block(feature, text_opacity(i / FPS)))
             for i in range(round(INTRO * FPS))]
    steps = round(ZOOM_IN * FPS)
    shots += [shot(between(wide, tight, i / steps), "start.png", None, frames[0]) for i in range(1, steps + 1)]
    shots += [shot(tight, "start.png", f"frames/{i:05d}.png", frame) for i, frame in enumerate(frames)]
    steps = round(ZOOM_OUT * FPS)
    shots += [shot(between(tight, wide, i / steps), "end.png", None, frames[-1]) for i in range(1, steps + 1)]
    return shots + [shots[-1]] * round(OUTRO * FPS)


def merged(shots):
    """Runs of identical frames become one frame shown for longer: [(svg, milliseconds)]."""
    out = []
    for svg in shots:
        if out and out[-1][0] == svg:
            out[-1][1] += 1000 // FPS
        else:
            out.append([svg, 1000 // FPS])
    return out


# MARK: Files

def wallpaper(folder):
    """The desktop picture, cut to the screen's shape at twice its size."""
    if not WALLPAPER.exists():
        sys.exit(f"error: no {WALLPAPER}; the clips use macOS Sonoma's desktop picture")
    side = 6016
    subprocess.run(["sips", "-s", "format", "jpeg", "-c", str(round(side / ASPECT)), str(side),
                    "-z", str(DESK_H * 2), str(DESK_W * 2), str(WALLPAPER), "--out", str(folder / "wallpaper.jpg")],
                   check=True, stdout=subprocess.DEVNULL)


def draw_stage(folder, place):
    (folder / "stage.svg").write_text(stage(place))
    subprocess.run(["rsvg-convert", "--zoom", "2", "-o", str(folder / "stage.png"), str(folder / "stage.svg")],
                   check=True)
    subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "90", str(folder / "stage.png"),
                    "--out", str(folder / "stage.jpg")], check=True, stdout=subprocess.DEVNULL)


def render(folder, index, svg):
    path = folder / f"out-{index:05d}.svg"
    path.write_text(svg)
    png = path.with_suffix(".png")
    subprocess.run(["rsvg-convert", "-o", str(png), str(path)], check=True)
    return png


def make_clip(feature, folder):
    clip = json.loads((folder / "clip.json").read_text())
    place = layout(clip, feature["screen"])
    wallpaper(folder)
    draw_stage(folder, place)
    shots = merged(timeline(feature, clip, place))
    with ThreadPoolExecutor(max_workers=os.cpu_count()) as pool:
        pngs = list(pool.map(lambda job: render(folder, *job), [(i, svg) for i, (svg, _) in enumerate(shots)]))
    args = ["img2webp", "-loop", "0", "-mixed"]
    for png, (_, ms) in zip(pngs, shots):
        args += ["-d", str(ms), "-lossy", "-q", str(QUALITY), "-m", "4", str(png)]
    out = FEATURES / f"{feature['id']}.webp"
    subprocess.run(args + ["-o", str(out)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"Wrote {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KB, {len(clip['frames'])} demo frames)")


def make(raw_dir, only):
    raw = Path(raw_dir)
    missing = [f["id"] for f in features(only) if not (raw / f["id"] / "clip.json").exists()]
    if missing:
        sys.exit(f"error: no recording for {', '.join(missing)}")
    for feature in features(only):
        make_clip(feature, raw / feature["id"])


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "seed":
        seed(sys.argv[2], sys.argv[3])
    elif len(sys.argv) >= 2 and sys.argv[1] == "list":
        list_features(set(sys.argv[2:]))
    elif len(sys.argv) >= 3 and sys.argv[1] == "make":
        make(sys.argv[2], set(sys.argv[3:]))
    else:
        sys.exit(__doc__)
