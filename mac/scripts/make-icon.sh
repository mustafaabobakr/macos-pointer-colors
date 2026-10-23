#!/bin/sh
# Regenerates mac/Resources/AppIcon.icns from AppIcon.svg. Needs rsvg-convert (brew install librsvg).
# The .icns is committed, so building the app doesn't need this.
set -eu

RES="$(cd "$(dirname "$0")/../Resources" && pwd)"
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"

for size in 16 32 128 256 512; do
  rsvg-convert -w "$size" -h "$size" "$RES/AppIcon.svg" -o "$SET/icon_${size}x${size}.png"
  rsvg-convert -w $((size * 2)) -h $((size * 2)) "$RES/AppIcon.svg" -o "$SET/icon_${size}x${size}@2x.png"
done

iconutil -c icns "$SET" -o "$RES/AppIcon.icns"
echo "Wrote $RES/AppIcon.icns"
