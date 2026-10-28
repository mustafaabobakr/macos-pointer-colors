#!/bin/sh
# Records the feature clips in docs/features (see docs/features/features.json and CLAUDE.md).
# Usage: mac/scripts/feature-clips.sh [feature id ...]   (default: every feature)
#
# For each feature, the app plays its demo (FeatureClipScripts.swift) offscreen with the demo
# settings in feature-demo-settings.json, fresh each time, and docs/art/make_feature_clips.py
# turns the recording into docs/features/<id>.webp. The bare build keeps its settings in its own
# "PointerColors" domain, so the installed app's settings are never touched, and the recording
# never changes the real pointer. That domain is saved first and put back afterwards.
# Needs rsvg-convert and img2webp (brew install librsvg webp).
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
# The bare build has no icon, and the update window shows it.
mkdir -p "$WORK/icon"
xcrun actool "$MAC_DIR/Resources/AppIcon.icon" --compile "$WORK/icon" --platform macosx \
  --minimum-deployment-target 14.0 --app-icon AppIcon --output-partial-info-plist "$WORK/icon.plist" >/dev/null

defaults export "$DOMAIN" "$WORK/saved.plist" 2>/dev/null || : > "$WORK/saved.plist"
saved=true
python3 -I "$ROOT/docs/art/make_feature_clips.py" seed "$MAC_DIR/scripts/feature-demo-settings.json" "$WORK/demo.plist"

python3 -I "$ROOT/docs/art/make_feature_clips.py" list "$@" > "$WORK/features.txt"
while read -r id screen spot; do
  defaults delete "$DOMAIN" 2>/dev/null || true
  defaults import "$DOMAIN" "$WORK/demo.plist"
  "$BIN" --record-feature "$id" "$screen" "$spot" "$WORK/raw/$id" --app-icon "$WORK/icon/AppIcon.icns" < /dev/null
done < "$WORK/features.txt"
restore

python3 -I "$ROOT/docs/art/make_feature_clips.py" make "$WORK/raw" "$@"
