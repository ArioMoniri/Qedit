<div align="center">

<img src=".github/assets/hero.svg" alt="Qedit — find & edit any file without changing its format" width="820">

<br/><br/>

<a href="https://github.com/ArioMoniri/Qedit/releases/latest/download/Qedit.dmg"><img src=".github/assets/download-mac.svg" alt="Download for macOS" height="54"></a>
&nbsp;
<a href="#-install"><img src=".github/assets/download-brew.svg" alt="Install with Homebrew" height="54"></a>

<br/><br/>

[![Release](https://github.com/ArioMoniri/Qedit/actions/workflows/release.yml/badge.svg)](https://github.com/ArioMoniri/Qedit/actions/workflows/release.yml)
![Platform](https://img.shields.io/badge/macOS-14%2B-111?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5-f05138?logo=swift&logoColor=white)
![Made with](https://img.shields.io/badge/SwiftUI%20·%20PDFKit-2563eb)
[![License](https://img.shields.io/badge/license-MIT-22c55e)](LICENSE)

</div>

> ### 🔎 macOS can *preview* almost anything — but it can't *edit* it.
> **Qedit fixes that.** Open any file — **including PDFs** — find, edit, annotate, then **save it straight back in place**. A `.pdf` stays a `.pdf`. A `.md` stays a `.md`. No conversion, no `.ePDF` tricks, ever.

<div align="center">
<img src=".github/assets/pipeline.svg" alt="Preview → Edit → Save in place" width="760">
</div>

## ✨ What you get

| | Feature |
|---|---|
| 👀 | **Rich Quick Look previews** — Markdown, source code, logs, JSON/YAML/XML rendered with syntax highlighting, dark mode & remembered scroll position |
| 📄 | **A real PDF editor** — find + jump-to-result, highlight, sticky notes, text boxes, ✍️ signatures, and page ops (rotate / delete / insert / reorder / extract) |
| ✏️ | **A text & code editor** — native find bar, your file's original encoding, optional timestamped backup before the first write |
| ⌨️ | **One keystroke from Finder** — select a file, hit **⌥⌘E** (rebindable), or right-click → *Open in Qedit* |
| 🧩 | **Extension manager** — list every Quick Look extension + the types it claims, **enable/disable them**, reset the QL cache, and inspect any file's UTI |
| 🔄 | **Auto-updates** — [Sparkle](https://sparkle-project.org), EdDSA-verified, installed in the background, with an in-app **Updates** page |

## 🧩 How it works

Two steps, one keystroke apart:

1. **Preview (read)** — press <kbd>Space</kbd> in Finder. Qedit's Quick Look extension renders the types macOS shows as flat text. System types keep Apple's preview.
2. **Edit (write)** — the Quick Action or the global hotkey opens that *same* file in the editor. Change it, <kbd>⌘S</kbd>, done — original format preserved.

## 🚫 What it won't do (on purpose — these are real macOS limits)

- **Never** changes or renames your file's format. Edits write back in the original format.
- **Never** hijacks Apple's built-in PDF/image previews — Qedit only previews types macOS renders poorly, and never registers system UTIs.
- **Never** silently overrides system security — extensions you toggle may still need a one-time approval in System Settings (Qedit takes you straight there).

## 📦 Install

<div align="center">
<a href="https://github.com/ArioMoniri/Qedit/releases/latest/download/Qedit.dmg"><img src=".github/assets/download-mac.svg" alt="Download for macOS" height="50"></a>
</div>

**Direct** — download the signed, notarized [**`Qedit.dmg`**](https://github.com/ArioMoniri/Qedit/releases/latest), drag it to Applications.

**Homebrew**

```bash
brew tap ariomoniri/qedit https://github.com/ArioMoniri/Qedit
brew install --cask qedit
```

Then open the app once, go to **Setup**, and tap **Enable Qedit Preview**. Press <kbd>Space</kbd> on a `.md`/`.swift`/`.log` to see it. 🎉

## 🛠 Build from source

Needs Xcode 16+ and [XcodeGen](https://github.com/yonsm/XcodeGen).

```bash
brew install xcodegen
xcodegen generate        # project.yml → Qedit.xcodeproj (git-ignored)
open Qedit.xcodeproj      # ⌘R to run
```

<details>
<summary><b>Project layout</b></summary>

```
Sources/
  Qedit/              host app — editor (Module B), manager (Module C), updates, onboarding
  QuickLookExtension/ Module A — the Quick Look preview (sandboxed, read-only)
  QuickActionExtension/ Finder Quick Action → hands the file to the editor
  Shared/             code compiled into all three targets
scripts/              build_release.sh + notarize.sh
.github/              release workflow + README assets
```
The host app is **unsandboxed** (Developer ID) so the manager can shell out to `pluginkit`/`qlmanage`/`brew` and the hotkey can read the Finder selection. Both extensions **are** sandboxed.
</details>

## 🚀 Releasing

Pushing a `vX.Y.Z` tag runs [`.github/workflows/release.yml`](.github/workflows/release.yml): build → **Developer-ID sign** → **notarize** → EdDSA-sign the Sparkle appcast → publish the DMG, all from the `APPLE_*` secrets. Release notes come from [`CHANGELOG.md`](CHANGELOG.md).

```bash
git tag v0.2.0 && git push origin v0.2.0   # 🪄 that's the whole release
```

## 🗺 Roadmap

- [x] **M1** — Quick Look previews + in-place text editor
- [x] **M2** — PDFKit editor + Quick Action + ⌥⌘E hotkey
- [x] **M3** — Quick Look extension manager (enable/disable · `qlmanage -r` · UTI inspector)
- [x] **M4** — Sparkle auto-updates · theming · Developer-ID notarized release

See [**CHANGELOG.md**](CHANGELOG.md) for what changed in each version. 📝

## 📄 License

[MIT](LICENSE) © 2026 **Ariorad Moniri**.

<div align="center"><sub>Built with Swift, SwiftUI, AppKit & PDFKit on macOS. 🛠</sub></div>
