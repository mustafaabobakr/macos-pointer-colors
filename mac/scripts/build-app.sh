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
# Universal: one binary for Apple silicon and Intel Macs. Override with ARCHS="arm64" for a quicker
# local build.
ARCH_FLAGS=""
for arch in ${ARCHS:-arm64 x86_64}; do ARCH_FLAGS="$ARCH_FLAGS --arch $arch"; done
swift build -c "$CONFIG" $ARCH_FLAGS $LINK_FLAGS
BIN_DIR="$(swift build -c "$CONFIG" $ARCH_FLAGS $LINK_FLAGS --show-bin-path)"

# Quit a copy running from this bundle first. Replacing an app's files while it runs breaks its
# signature check, so its update button would refuse every download.
RUNNING_BIN="$APP/Contents/MacOS/PointerColors"
if pkill -f "^$RUNNING_BIN" 2>/dev/null; then
  echo "Quit the copy running from $APP." >&2
  while pgrep -f "^$RUNNING_BIN" >/dev/null; do sleep 0.2; done
fi
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

# Sign with the release identity so macOS keeps Full Disk Access across rebuilds and installed
# copies accept the build as an update. A git-ignored copy in mac/signing/ (made by
# export-signing-identity.sh) goes back into the keychain if it's missing there.
. "$MAC_DIR/scripts/signing.sh"
IDENTITY="${SIGN_IDENTITY:-$RELEASE_IDENTITY}"
has_identity() { security find-identity -v -p codesigning | grep -q "\"$IDENTITY\""; }
if ! has_identity && [ "$IDENTITY" = "$RELEASE_IDENTITY" ] && [ -s "$SIGNING_P12" ]; then
  echo "Importing \"$IDENTITY\" from $SIGNING_P12 into the login keychain." >&2
  security import "$SIGNING_P12" -k login.keychain-db -P "$(cat "$SIGNING_PASSWORD_FILE")" -T /usr/bin/codesign >/dev/null
fi
if ! has_identity; then
  # A release signed ad-hoc could never be installed as an update, so only debug builds fall back.
  [ "$CONFIG" = release ] && { echo "error: signing identity \"$IDENTITY\" not found; run scripts/export-signing-identity.sh on a Mac that has it" >&2; exit 1; }
  echo "Signing identity \"$IDENTITY\" not found; signing ad-hoc." >&2
  IDENTITY="-"
fi
codesign --force --sign "$IDENTITY" --options runtime "$APP"

if [ "$CONFIG" = release ]; then
  LEAF="$(codesign -dr - "$APP" 2>&1 | sed -n 's/.*certificate leaf = H"\([0-9a-fA-F]*\)".*/\1/p' | tr a-f A-F)"
  [ "$LEAF" = "$RELEASE_CERT_SHA1" ] || { echo "error: signed with certificate ${LEAF:-none}, not the release one ($RELEASE_CERT_SHA1)" >&2; exit 1; }
fi

# Tell Finder and System Settings to drop their cached copy of the icon.
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

echo "Built: $APP ($(lipo -archs "$APP/Contents/MacOS/PointerColors"))"
