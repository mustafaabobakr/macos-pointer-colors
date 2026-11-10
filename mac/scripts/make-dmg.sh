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
WORK="$(mktemp -d)"
RW="$WORK/rw.dmg"
MOUNT="$WORK/mount"

BUILD_ENV=prod "$MAC_DIR/scripts/build-app.sh" release

# Packed by hand rather than with `hdiutil create -srcfolder`: that one unmounts its own temporary
# volume at the end and fails with "Resource busy" whenever something on the Mac opens the volume
# as it mounts. Here the volume is mounted hidden, filled, then force-detached before compressing.
cleanup() {
  [ -d "$MOUNT" ] && hdiutil detach "$MOUNT" -force >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

SIZE_MB=$(( $(du -sm "$APP" | cut -f1) + 20 ))
hdiutil create -size "${SIZE_MB}m" -fs HFS+ -volname "Pointer Colors" -type UDIF "$RW" >/dev/null
mkdir "$MOUNT"
hdiutil attach "$RW" -nobrowse -noautoopen -mountpoint "$MOUNT" >/dev/null
ditto "$APP" "$MOUNT/Pointer Colors.app"
ln -s /Applications "$MOUNT/Applications"
hdiutil detach "$MOUNT" -force >/dev/null
rmdir "$MOUNT"
rm -f "$DMG"
hdiutil convert "$RW" -format UDZO -o "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null 2>&1 || { echo "error: $DMG failed hdiutil verify" >&2; exit 1; }

# The DMG stays unsigned. macOS runs the full notarization check on a downloaded disk image that
# carries a signature, so one signed with the local self-signed identity is refused with
# "Apple could not verify…" and never mounts. An unsigned DMG mounts, and Gatekeeper checks the
# app inside instead. Sign it again only with a Developer ID, once the app is notarized.

echo "Built: $DMG ($(du -h "$DMG" | cut -f1))"
