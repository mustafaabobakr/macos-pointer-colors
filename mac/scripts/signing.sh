# Shared by the build scripts: where the signing identity lives and which certificate releases use.
# Sourced, not run.

SIGNING_DIR="$MAC_DIR/signing"
SIGNING_P12="$SIGNING_DIR/PointerColorsDev.p12"
SIGNING_PASSWORD_FILE="$SIGNING_DIR/password"
# The certificate every release since 0.3.0 is signed with. Installed copies only accept updates
# signed by it, so a release signed with anything else can never be installed from the app.
RELEASE_IDENTITY="Pointer Colors Dev"
RELEASE_CERT_SHA1="1E26D5C63E9B0B347162133ED91B41F0115F60FF"
