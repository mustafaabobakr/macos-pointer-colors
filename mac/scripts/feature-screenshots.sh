#!/bin/sh
# Takes the feature screenshots in docs/features (see docs/features/features.json and CLAUDE.md).
# Usage: mac/scripts/feature-screenshots.sh [feature id ...]   (default: every feature)
#
# Renders the menu and every Preferences tab offscreen with the demo settings in
# feature-demo-settings.json, then frames each feature with docs/art/make_feature_shots.py.
# The bare build keeps its settings in its own "PointerColors" domain, so the installed app's
# settings are never touched, and the render never changes the real pointer. That domain is
# saved first and put back afterwards. Needs rsvg-convert (brew install librsvg).
set -eu

MAC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$MAC_DIR/.." && pwd)"
DOMAIN="PointerColors"
WORK="$(mktemp -d)"
trap 'restore; rm -rf "$WORK"' EXIT

saved=false
restore() {
  $saved || return 0
  defaults delete "$DOMAIN" 2>/dev/null || true
  [ -s "$WORK/saved.plist" ] && defaults import "$DOMAIN" "$WORK/saved.plist"
  saved=false
}

cd "$MAC_DIR"
swift build
BIN="$(swift build --show-bin-path)/PointerColors"

defaults export "$DOMAIN" "$WORK/saved.plist" 2>/dev/null || : > "$WORK/saved.plist"
saved=true
python3 -I "$ROOT/docs/art/make_feature_shots.py" seed "$MAC_DIR/scripts/feature-demo-settings.json" "$WORK/demo.plist"
defaults delete "$DOMAIN" 2>/dev/null || true
defaults import "$DOMAIN" "$WORK/demo.plist"

"$BIN" --render-features "$WORK/raw"
restore

python3 -I "$ROOT/docs/art/make_feature_shots.py" frame "$WORK/raw" "$@"
