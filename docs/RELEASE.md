# Releasing Qedit

Qedit ships as a **Developer ID-signed, notarized** `.dmg` on GitHub Releases (no App
Store). This avoids install friction while keeping the manager/diagnostics features that an
App Store sandbox would forbid.

## Prerequisites (one time)

- Xcode + command-line tools, `xcodegen` (`brew install xcodegen`).
- A **Developer ID Application** certificate in your login keychain
  (Team ID `FF68N39FU5`).
- An app-specific password from <https://appleid.apple.com>, stored for `notarytool`:

  ```bash
  xcrun notarytool store-credentials qedit-notary \
    --apple-id "you@example.com" --team-id FF68N39FU5 \
    --password "abcd-efgh-ijkl-mnop"
  ```

## Steps

1. **Bump the version** in `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`),
   then `xcodegen generate`.

2. **Build + sign + package** (produces `dist/Qedit.dmg`):

   ```bash
   ./scripts/build_release.sh
   ```

   This archives the Release configuration (Developer ID, Hardened Runtime), exports the
   signed `.app`, verifies the signature, and builds a signed DMG.

3. **Notarize + staple**:

   ```bash
   ./scripts/notarize.sh dist/Qedit.dmg
   ```

4. **Verify Gatekeeper** accepts it as if freshly downloaded:

   ```bash
   spctl -a -vvv --type install dist/Qedit.dmg
   xcrun stapler validate dist/Qedit.dmg
   ```

5. **Publish the GitHub Release** (tag `vX.Y.Z`):

   ```bash
   gh release create vX.Y.Z dist/Qedit.dmg \
     --repo ArioMoniri/Qedit --title "Qedit X.Y.Z" --notes "…"
   ```

   The in-app updater (Extensions → Updates) reads
   `api.github.com/repos/ArioMoniri/Qedit/releases/latest` and compares the tag to the
   running `CFBundleShortVersionString`.

## Optional: Homebrew cask

After the release is live, a cask formula can point at the DMG URL + SHA. Users then get
updates via `brew upgrade --cask qedit`. Qedit surfaces `brew outdated --cask` for
extensions it didn't install, but it never updates third-party apps itself.

## Notes on signing

- The **host app is not sandboxed** (it shells out to `pluginkit`/`qlmanage`/`brew` and
  reads the Finder selection). It carries the `com.apple.security.automation.apple-events`
  entitlement, which Hardened Runtime requires for the Finder query.
- The **two app-extensions are sandboxed**, read-only, and signed with the same identity.
- All targets build with Hardened Runtime + `--timestamp` in Release, which notarization
  requires.
