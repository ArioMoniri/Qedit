#!/usr/bin/env bash
#
# Build a Developer-ID-signed Qedit.app and a signed .dmg.
# Notarization is a separate step — see scripts/notarize.sh.
#
# Requires: Xcode, xcodegen, and a "Developer ID Application" certificate in the keychain.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Qedit"
# Identity + team come from env in CI (APPLE_SIGNING_IDENTITY / APPLE_TEAM_ID),
# falling back to the local defaults for hands-on builds.
SIGN_IDENTITY="${APPLE_SIGNING_IDENTITY:-Developer ID Application}"
TEAM_ID="${APPLE_TEAM_ID:-FF68N39FU5}"
DIST="$ROOT/dist"
ARCHIVE="$DIST/$APP_NAME.xcarchive"
EXPORT="$DIST/export"
APP="$EXPORT/$APP_NAME.app"
DMG="$DIST/$APP_NAME.dmg"
STAGING="$DIST/dmg-staging"

echo "==> Cleaning $DIST"
rm -rf "$DIST"
mkdir -p "$DIST"

if command -v xcodegen >/dev/null 2>&1; then
  echo "==> Regenerating project"
  xcodegen generate
fi

echo "==> Archiving (Release, Developer ID, Hardened Runtime)"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  archive

echo "==> Exporting signed app"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$ROOT/Config/ExportOptions.plist" \
  -exportPath "$EXPORT"

echo "==> Verifying code signature"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "==> Gatekeeper assessment (will only fully pass after notarization)"
spctl -a -vvv --type exec "$APP" || true

echo "==> Building DMG"
rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG"

echo "==> Done: $DMG"
echo "    Next: scripts/notarize.sh \"$DMG\""
