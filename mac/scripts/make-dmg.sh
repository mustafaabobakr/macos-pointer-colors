#!/bin/sh
# Builds the release app and packs it into mac/build/Pointer-Colors.dmg, with an Applications
# shortcut for drag-to-install. The file name is stable so the website can link to
# releases/latest/download/Pointer-Colors.dmg.
#
# Not notarized: that needs a paid Apple Developer account. Until then, people open the app the
# first time with right-click › Open, or allow it in System Settings › Privacy & Security.
set -eu

MAC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$MAC_DIR/build/Pointer Colors.app"
DMG="$MAC_DIR/build/Pointer-Colors.dmg"
STAGE="$(mktemp -d)"

"$MAC_DIR/scripts/build-app.sh" release

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Pointer Colors" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"

# The DMG stays unsigned. macOS runs the full notarization check on a downloaded disk image that
# carries a signature, so one signed with the local self-signed identity is refused with
# "Apple could not verify…" and never mounts. An unsigned DMG mounts, and Gatekeeper checks the
# app inside instead. Sign it again only with a Developer ID, once the app is notarized.

echo "Built: $DMG ($(du -h "$DMG" | cut -f1))"
