#!/usr/bin/env bash
#
# Notarize and staple a signed Qedit .dmg (or .app/.zip).
#
# One-time credential setup (stores an app-specific password in the keychain):
#   xcrun notarytool store-credentials qedit-notary \
#     --apple-id "you@example.com" --team-id FF68N39FU5 \
#     --password "abcd-efgh-ijkl-mnop"      # app-specific password from appleid.apple.com
#
# Then: scripts/notarize.sh dist/Qedit.dmg
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-$ROOT/dist/Qedit.dmg}"
PROFILE="${NOTARY_PROFILE:-qedit-notary}"

if [[ ! -e "$TARGET" ]]; then
  echo "error: $TARGET not found. Run scripts/build_release.sh first." >&2
  exit 1
fi

echo "==> Submitting $TARGET to Apple notary service (profile: $PROFILE)"
xcrun notarytool submit "$TARGET" --keychain-profile "$PROFILE" --wait

echo "==> Stapling ticket"
xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"

echo "==> Notarized + stapled: $TARGET"
