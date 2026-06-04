# Changelog

All notable changes to Qedit. This file feeds both the GitHub release notes and the
in-app Sparkle updater. 🪄

## v0.1.8
- ⚔️ **Conflict detection** — if another Quick Look extension (e.g. QLMarkdown, Syntax Highlight) also handles your Markdown/code, the Extensions tab flags it and offers **“Use Qedit for these types”** (one click disables the competitors so macOS shows *Qedit’s* preview). macOS only allows one previewer per file type — this is why “Space” sometimes showed a different preview.
- 🏷️ **Qedit badge** on every preview (“⌕ Qedit · Markdown”) so you can instantly tell Qedit rendered it, not another extension.
- 🧹 **Self-healing registrations** — on launch Qedit removes stale registrations left by old or duplicate copies of itself, so a duplicate can never silently break the preview again.
- 💻 Confirmed **code-file** previews (Swift, Python, JS/TS, Go, Rust, C/C++, Java, Ruby, PHP, shell, SQL… via `public.source-code`).

## v0.1.7
- 🔐 **Permissions panel** in Setup — one-tap buttons to grant **Finder control** (so the ⌥⌘E hotkey actually works), enable the preview + “Open With Qedit”, and jump to the exact System Settings panes (Automation, Accessibility, Full Disk Access), each with a live status.
- 🪵 **Debug log** (Extensions → Troubleshoot) — see exactly what every button runs (`pluginkit`, `qlmanage`, `lsregister`…) and its output, so “Enable” is never a black box. Copy it with one click.
- 🧷 **“Open With → Qedit” registers automatically** on launch — macOS often skips re-indexing document types after a Sparkle update, which is why it sometimes didn’t appear.
- 📃 Descriptions now list **all** supported formats (Markdown, 30+ source languages, logs, JSON/YAML/XML/TOML/INI/plist, plain text, and PDF) — not just “.md or .pdf”.

## v0.1.6
- 📝 **Open With → Qedit** — Qedit now registers as an editor, so right-click → **Open With → Qedit** (or set it as default) opens any text / Markdown / code / PDF straight in the editor — **no spacebar needed**. ⌘F finds, and saving writes back in place.
- 🔎 **⌘F now works in the text editor** (it didn’t before) — the native find/replace bar.
- ⚙️ **Settings opens from the menu-bar icon** (previously did nothing).
- 🩺 Better duplicate fix: a preview silently fails when a second copy of Qedit.app exists (e.g. in Downloads). “Remove Duplicate(s)” clears the registration, and new **“Reveal in Finder”** shows the extra copy so you can delete it for good. Enabling also turns on the Quick Action and flushes the Services cache.
- ℹ️ Honest about limits: Quick Look previews are **read-only** and can’t take ⌘F (macOS owns that panel) — find & edit live in the editor.

## v0.1.5
- 🪟➡️🫥 **Runs in the background, out of the Dock.** Close the window and Qedit drops its Dock icon and keeps running as a **menu-bar agent** — the global hotkey and Quick Action stay live. A menu-bar icon (Open / Check for Updates / Settings / Quit) is your control; opening a file from the hotkey or Finder brings the Dock icon back. Toggle it in **Settings → When the window closes**.

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
