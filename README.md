# Qedit — non-destructive find / edit for any file (macOS)

Qedit adds Peek-style **find, edit, navigate, annotate** to files macOS otherwise renders
flat — including PDFs — **without ever changing or renaming the file's format**. It also
ships a manager for installed Quick Look extensions.

A `.pdf` stays a `.pdf` (edited via PDFKit). A `.md` stays a `.md`. No conversion, no
`.ePDF` tricks, no fighting Apple's built-in previews.

> Status: **Milestones 1–2 complete** — Xcode project (host app + Quick Look preview
> extension + Quick Action), rich previews for non-system types, an in-place text editor,
> a full **PDFKit editor** (find, annotate, page ops, save-in-place), the Finder Quick
> Action, and a configurable **global hotkey** (⌥⌘E). Extension manager and notarized
> release follow in milestones 3–4 (see [Roadmap](#roadmap)).

## Why it's built this way (real macOS limits)

These are hard constraints, not preferences:

1. **Never change a file's format.** All edits write back in place, in the original
   format.
2. **Don't register the preview extension for system-owned UTIs** (`com.adobe.pdf`,
   `public.jpeg`, `public.png`, `public.tiff`, …). macOS gives its built-in handlers
   priority and App Store validation rejects system UTIs in `QLSupportedContentTypes`.
   So Qedit's preview only covers types Apple renders poorly (Markdown, source code,
   logs, config) and **never replaces Apple's spacebar PDF preview**.
3. **The Quick Look preview is sandboxed, read-only, non-interactive.** No save buttons
   in the preview. All writing happens in the editor (Module B), which gets write access
   via the Quick Action and (later) security-scoped bookmarks.
4. **A manager can't toggle another app's Quick Look extension.** Qedit deep-links you to
   System Settings → Login Items & Extensions and guides you. It never claims auto-enable.

## Architecture — one host `.app`, three targets

| Target | Kind | Role |
|---|---|---|
| `Qedit` | Application (SwiftUI/AppKit) | Module B editor, Module C manager, onboarding, hotkey |
| `QeditQuickLook` | Quick Look preview app-extension | **Module A** — rich read-only previews for non-system UTIs |
| `QeditQuickAction` | Action / Services app-extension | **Module B entry** — hands the Finder selection to the editor |

- **Module A** (`Sources/QuickLookExtension`): a `QLPreviewingController` hosting a
  `WKWebView`. Markdown (marked), source/config (highlight.js), and logs render as
  self-contained HTML — all JS/CSS is **bundled** (offline + sandbox safe) and the file
  text is base64-embedded so arbitrary content can't break the page. Scroll position is
  restored per file; light/dark themes via `prefers-color-scheme`.
- **Module B** (`Sources/Qedit/Editor`): opens a file from Finder (Quick Action or the
  global hotkey, via `qedit://open?path=…`). Text/source/Markdown/config open in an
  `NSTextView`-backed editor (native find bar, original-encoding save). **PDFs** open in
  a PDFKit editor with find + jump-to-result, highlight/note/text-box/signature
  annotations, page ops (rotate/delete/insert/reorder/extract) and copy-as-plain-text.
  Both save **in place** in the original format, with an optional timestamped backup
  before the first write.
- **Module C** (`Sources/Qedit/Manager`): the extension manager + diagnostics — landing
  in milestone 3.

The host app is intentionally **not sandboxed** (Developer ID distribution) so the manager
can shell out to `pluginkit` / `qlmanage` / `brew` and the hotkey can read the Finder
selection. Both app-extensions **are** sandboxed (required), read-only.

## Build

Requires Xcode 26+, macOS 14+ SDK, and [XcodeGen](https://github.com/yonsm/XcodeGen).

```bash
brew install xcodegen        # one-time
xcodegen generate            # project.yml → Qedit.xcodeproj (git-ignored)
open Qedit.xcodeproj         # or build from the CLI:

xcodebuild -project Qedit.xcodeproj -scheme Qedit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build build
```

The `.xcodeproj` is generated and **not** committed — edit `project.yml`, then
`xcodegen generate`.

### Try the preview (after building)

1. Move `Qedit.app` to `/Applications` and launch it once so macOS registers the extensions.
2. System Settings → General → Login Items & Extensions → Quick Look → enable **Qedit Preview**.
3. Select a `.md`, `.swift`, `.log`, or `.json` file in Finder and press **Space**.

(The in-app **Setup** tab walks through this.)

## Distribution

Developer ID + notarization, shipped as a DMG on GitHub Releases (+ optional Homebrew
cask). Wired up in milestone 4.

## Roadmap

- [x] **M1** — Xcode project (host + QL preview + Quick Action); rich Markdown/code/log/config
  previews; in-place text editor with find bar + backup.
- [x] **M2** — PDFKit editor: find/search, highlight/note/text/signature annotations, page
  ops (rotate/delete/insert/reorder/extract), copy-as-text, save-in-place; Finder Quick
  Action + configurable global hotkey (⌥⌘E).
- [ ] **M3** — Extension manager: list extensions + UTIs, `qlmanage -r`, UTI inspector,
  Settings deep-link.
- [ ] **M4** — Updates (brew + GitHub Releases), theming, signing + notarization, release.

## License

TBD.
