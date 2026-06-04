<div align="center">

<img src=".github/assets/hero.svg" alt="Qedit — find & edit any file without changing its format" width="820">

<br/>

[![Release](https://github.com/ArioMoniri/Qedit/actions/workflows/release.yml/badge.svg)](https://github.com/ArioMoniri/Qedit/actions/workflows/release.yml)
![Platform](https://img.shields.io/badge/macOS-14%2B-111?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5-f05138?logo=swift&logoColor=white)
![Made with](https://img.shields.io/badge/SwiftUI%20·%20PDFKit-2563eb)
[![Download](https://img.shields.io/github/v/release/ArioMoniri/Qedit?label=download&color=34d27b)](https://github.com/ArioMoniri/Qedit/releases/latest)

</div>

> 🔎 **Qedit** gives macOS the thing it's missing: open *any* file — **including PDFs** — find, edit, annotate, then **save it back in place**. A `.pdf` stays a `.pdf`. A `.md` stays a `.md`. No conversion, no `.ePDF` tricks, ever.

<div align="center">
<img src=".github/assets/pipeline.svg" alt="Preview → Edit → Save in place" width="720">
</div>

## ✨ What you get

- 👀 **Rich Quick Look previews** for the stuff macOS shows as flat text — Markdown, source code, logs, JSON/YAML/XML — with syntax highlighting, dark mode, and remembered scroll position.
- 📄 **A real PDF editor** — find with jump-to-result, highlight, sticky notes, text boxes, ✍️ signatures, and page ops (rotate / delete / insert / reorder / extract). Saves straight back to the same `.pdf`.
- ✏️ **A text/code editor** with the native find bar, your file's original encoding, and an optional timestamped backup before the first write.
- ⌨️ **One keystroke from Finder** — pick a file, hit **⌥⌘E** (rebindable), and it opens in the editor. Or right-click → Quick Actions → *Open in Qedit*.
- 🧩 **A Quick Look extension manager** — see every installed preview extension and the file types it claims, reset the Quick Look cache, drop a file to learn its UTI + which extension previews it, and jump to the right System Settings pane.
- 🌗 Light / Dark / System theme, recent files, in-app update checks (GitHub + Homebrew).

## 🧩 How it works

**Preview (read)** → **Edit (write)**. The Quick Look extension renders non‑system types beautifully; the editor opens the *same* file on demand and writes back in place. Two steps, one keystroke apart.

## 🚫 What it won't do (on purpose — these are real macOS limits)

- ❌ Change or rename your file's format. Edits always write back in the original format.
- ❌ Hijack Apple's built-in PDF/image previews. Qedit only previews types macOS renders poorly, and never registers system UTIs.
- ❌ Pretend it can flip another app's extension on for you — macOS requires *you* to approve extensions. Qedit just deep-links you there and explains it.

## 🛠 Build from source

Needs Xcode 16+ and [XcodeGen](https://github.com/yonsm/XcodeGen).

```bash
brew install xcodegen
xcodegen generate        # project.yml → Qedit.xcodeproj (git-ignored)
open Qedit.xcodeproj      # ⌘R to run
```

First run: move **Qedit.app** to `/Applications`, then **Setup** tab → enable *Qedit Preview* in System Settings → Login Items & Extensions → Quick Look. Press **Space** on a `.md`/`.swift`/`.log` and you'll see it. 🎉

## 📦 Install

Grab the signed, notarized **`.dmg`** from [Releases](https://github.com/ArioMoniri/Qedit/releases/latest), drag Qedit to Applications, done.

## 🚀 Releasing (maintainers)

Pushing a `vX.Y.Z` tag runs [`.github/workflows/release.yml`](.github/workflows/release.yml): it builds, **Developer-ID signs**, **notarizes**, and publishes the DMG — all from the configured `APPLE_*` Actions secrets. Details in [docs/RELEASE.md](docs/RELEASE.md).

```bash
git tag v0.1.0 && git push origin v0.1.0   # 🪄 that's the whole release
```

## 🗺 Roadmap

- [x] **M1** — Quick Look previews (Markdown / code / logs / config) + in-place text editor
- [x] **M2** — PDFKit editor (find · annotate · sign · page ops) + Quick Action + ⌥⌘E hotkey
- [x] **M3** — Quick Look extension manager (`pluginkit` · `qlmanage -r` · UTI inspector)
- [x] **M4** — Updates · theming · Developer-ID signing + notarized release

## 📄 License

TBD.

<div align="center"><sub>Built with Swift, SwiftUI, AppKit & PDFKit on macOS. 🛠</sub></div>
