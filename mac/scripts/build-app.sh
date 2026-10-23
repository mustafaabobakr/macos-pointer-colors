#!/bin/sh
# Builds "Pointer Colors.app" into mac/build/ from the Swift package.
# Usage: mac/scripts/build-app.sh [debug|release]   (default: release)
set -eu

CONFIG="${1:-release}"
MAC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$MAC_DIR/build/Pointer Colors.app"

cd "$MAC_DIR"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PointerColors" "$APP/Contents/MacOS/PointerColors"
cp "$MAC_DIR/Resources/Info.plist" "$APP/Contents/Info.plist"
cp -R "$MAC_DIR/Resources/en.lproj" "$MAC_DIR/Resources/ar.lproj" "$APP/Contents/Resources/"

# Compile the Icon Composer icon: Assets.car carries the Liquid Glass version,
# AppIcon.icns is the flat fallback for older macOS. Needs Xcode 26 or later.
xcrun actool "$MAC_DIR/Resources/AppIcon.icon" \
  --compile "$APP/Contents/Resources" \
  --platform macosx --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$MAC_DIR/build/icon-partial.plist" \
  --output-format human-readable-text >/dev/null

# Ad-hoc signature so macOS can track the app for Full Disk Access and login items.
# For distribution, re-sign with a Developer ID and notarize.
codesign --force --sign - --options runtime "$APP"

echo "Built: $APP"
