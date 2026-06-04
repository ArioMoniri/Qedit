# Changelog

All notable changes to Qedit. This file feeds both the GitHub release notes and the
in-app Sparkle updater. 🪄

## v0.1.4
- 🩺 **Troubleshoot Quick Look** — the Extensions tab now spots the #1 reason a preview silently fails: the *same* extension registered twice (e.g. a build folder **and** /Applications). One click removes the stale copy.
- 🔁 **Refresh Finder & Quick Look** button, and enabling an extension now reloads Quick Look automatically so it takes effect right away.
- 🔎 **Find in a preview** — press **⌘F** inside a Quick Look preview to search the rendered file (highlight + next/prev/Esc). Previews stay read-only by macOS design — editing happens in the editor.
- 🐍 Confirmed **JSON** & **Python** previews (alongside YAML, XML, shell, and 30+ languages).

## v0.1.3
- ⬇️ In-app **download buttons** on the Updates page — grab the latest `.dmg`, open the release notes, or copy the Homebrew command. They always point at the newest release.

## v0.1.2
- 🧩 **Enable / disable Quick Look extensions** right from the app — per-extension toggles plus Enable All / Disable All.
- ⚡️ One-tap **“Enable Qedit Preview”** in Setup and a banner in Extensions when it’s off.
- 🪟 The app now **stays in the Dock** after you close its window and keeps running (hotkey + background update checks alive); clicking the Dock icon reopens the dashboard.
- 🆕 In-app **update notes** — the updater and each release now show a friendly changelog.
- 🎨 Refreshed README, richer animated banners, and proper **Download for macOS** / **Homebrew** buttons.

## v0.1.1
- 🔄 **Automatic updates** via Sparkle — checked, EdDSA-verified, installed in the background.
- 🆕 New **Updates** page and a “Check for Updates…” menu item.
- 🔘 Nicer capsule buttons across the app.

## v0.1.0
- 🎉 **First release.** Native macOS app: rich Quick Look previews (Markdown / code / logs / config), a PDFKit editor (find · highlight · note · text · signature · page ops), an in-place text editor, the Finder Quick Action + ⌥⌘E global hotkey, and a Quick Look extension manager.
- 🔏 Developer-ID signed & notarized.
