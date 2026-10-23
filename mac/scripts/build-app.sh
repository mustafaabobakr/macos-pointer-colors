#!/bin/sh
# Builds "Pointer Colors.app" into mac/build/ from the Swift package.
# Usage: mac/scripts/build-app.sh [debug|release]   (default: release)
set -eu

CONFIG="${1:-release}"
MAC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$MAC_DIR/build/Pointer Colors.app"

cd "$MAC_DIR"
# Record the real SDK in the binary. SwiftPM otherwise stamps the deployment target (14.0) as
# the SDK, and AppKit then draws pre-Liquid Glass controls for compatibility.
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
LINK_FLAGS="-Xlinker -platform_version -Xlinker macos -Xlinker 14.0 -Xlinker $SDK_VERSION"
swift build -c "$CONFIG" $LINK_FLAGS
BIN_DIR="$(swift build -c "$CONFIG" $LINK_FLAGS --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PointerColors" "$APP/Contents/MacOS/PointerColors"
cp "$MAC_DIR/Resources/Info.plist" "$APP/Contents/Info.plist"
cp -R "$MAC_DIR/Resources/en.lproj" "$MAC_DIR/Resources/ar.lproj" "$APP/Contents/Resources/"
# The pair list shared with the website lives at the repo root.
cp "$MAC_DIR/../pairs.json" "$APP/Contents/Resources/pairs.json"

# Compile the Icon Composer icon: Assets.car carries the Liquid Glass version,
# AppIcon.icns is the flat fallback for older macOS. Needs Xcode 26 or later.
xcrun actool "$MAC_DIR/Resources/AppIcon.icon" \
  --compile "$APP/Contents/Resources" \
  --platform macosx --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$MAC_DIR/build/icon-partial.plist" \
  --output-format human-readable-text >/dev/null

# Fail loudly if the icon didn't make it into the bundle, so a build never ships without it.
for f in Assets.car AppIcon.icns; do
  [ -s "$APP/Contents/Resources/$f" ] || { echo "error: app icon missing ($f); actool failed" >&2; exit 1; }
done

# Sign with a stable local identity so macOS keeps Full Disk Access across rebuilds.
# Override with SIGN_IDENTITY=... ; falls back to ad-hoc ("-") if it isn't in the keychain.
IDENTITY="${SIGN_IDENTITY:-Pointer Colors Dev}"
if ! security find-identity -v -p codesigning | grep -q "\"$IDENTITY\""; then
  echo "Signing identity \"$IDENTITY\" not found; signing ad-hoc." >&2
  IDENTITY="-"
fi
codesign --force --sign "$IDENTITY" --options runtime "$APP"

# Tell Finder and System Settings to drop their cached copy of the icon.
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

echo "Built: $APP"
