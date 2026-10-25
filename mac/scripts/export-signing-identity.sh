#!/bin/sh
# Saves the release signing identity (certificate and private key) from the login keychain to
# mac/signing/, which git ignores, so the build can put it back if the keychain ever loses it or
# on another Mac. The keychain asks to allow the export; the file's password goes next to it.
set -eu

MAC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$MAC_DIR/scripts/signing.sh"

mkdir -p "$SIGNING_DIR"
chmod 700 "$SIGNING_DIR"
[ -s "$SIGNING_PASSWORD_FILE" ] || (umask 077; openssl rand -base64 24 > "$SIGNING_PASSWORD_FILE")
swift "$MAC_DIR/scripts/export-identity.swift" "$RELEASE_CERT_SHA1" "$SIGNING_P12" "$(cat "$SIGNING_PASSWORD_FILE")"
chmod 600 "$SIGNING_P12"
echo "Saved: $SIGNING_P12 (keep a copy somewhere safe; it isn't in git)"
