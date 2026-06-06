# Changelog

All notable changes to Qedit. This file feeds both the GitHub release notes and the
in-app Sparkle updater. 🪄

## v0.5.4
- 🧹 **Clean environment on launch.** Opening Qedit now **quits any older copy still running** — this is what caused "two windows with different wording" after an update. One Qedit, one registration.
- 🎨 **Custom code colors.** **Settings → Editing → Code colors** lets you set your own colors for keywords, strings, numbers, comments and changed text, with **Classic / GitHub / Solarized** presets. Off by default (the editor keeps system colors that adapt to light/dark).
- 🤝 **Plays nicely with ChangeX.** Qedit no longer flags your **ChangeX** Quick Look extension as a competitor, and "Disable all" never switches it off — the two run side by side.

## v0.5.3
- ✍️ **Edit Word documents (opt-in).** New **Settings → Editing → “Allow editing Word (.docx/.doc)”** makes Word files editable and saves them back in place as `.docx` (verified). Off by default with a clear in-editor warning, because re-saving can simplify complex formatting — keep the `.bak` backup on for important docs.
- 🎞️ **PowerPoint `.pptx` opens** as a native read-only **slide viewer** (per-slide text, selectable, ⌘F find).
- 🟣 **SVG support** — `.svg` opens as editable XML with syntax coloring (it’s text, after all), saved in place.
- 📐 **Quick Panel size** — choose **Small / Medium / Large** in Settings → Shortcut.

## v0.5.2
- 📊 **Spreadsheets open as a native cell grid.** `.xlsx` files now open in a real **table view** — a header row + selectable, monospaced cells you can read and **⌘F find** — instead of “can’t open”. Read-only (re-saving .xlsx losslessly isn’t safe), with a one-click “Open in Default App” to edit in Numbers/Excel. (CSV/TSV parsing is built in too.)
- 🔎 `.xlsx`, `.csv` and `.tsv` are now in the **Open With → Qedit** menu.

## v0.5.1
- 🖍️ **Live change highlighting.** New **Settings → Editing → “Highlight my changes”** marks the text you’ve edited since opening the file, in your chosen style — **Highlight**, **Underline**, or **Color** — and clears when you save. See your edits at a glance.
- 💾 **Auto-save (or manual).** New **Settings → Editing → “Auto-save changes”** saves a moment after you stop typing (⌘S still saves instantly). Off by default — manual ⌘S as before.
- 🗂️ New **Editing** tab groups Saving, change highlighting and the `.bak` option together.

## v0.5.0
- 🎛️ **Redesigned, dynamic Settings.** Cleaner partitioned tabs (General · Shortcut · Preview) where **every option shows a clear `✓ On` / `✗ Off` chip** at a glance, each section shows an “N / M on” count, and the shortcut **preset buttons** sit right alongside the recorder. Much easier to scan than the old plain list.
- 🌈 **Syntax coloring in the editor.** Code & config files (Swift, Python, JS/TS, JSON…) now open with **colored keywords, strings, numbers and comments** — their native “code shape” — and recolor live as you type. Display-only: it never changes the saved bytes.

## v0.4.1
- ⌨️ **Keyboard-shortcut preset buttons** in Settings → Hotkey — one tap to pick ⌥⌘E, ⌃Space, ⌥Space, ⌃⌘Space or ⌘E (or still record your own). A bare Space can’t be a global shortcut without blocking typing, so the Space presets add a modifier.
- 📐 **Aligned the conflict toggles** — every Quick-Look-extension switch now lines up in one right-hand column, with dividers, instead of floating at different positions.
- 🪟 **Same file → one window.** Opening the same file from different places now reuses its window (URLs are normalized) instead of stacking duplicates. (If you see two windows with *different* wording, you have two Qedit versions running — quit all and reopen one.)

## v0.4.0
- ✍️ **RTF, RTFD & OpenDocument are now EDITABLE in native form.** They open showing real formatting (fonts, bold, lists) and save back **losslessly in the same format** — no more “read-only”. ⌘F works; ⌘S saves in place.
- 📄 **Word (.docx/.doc) now renders in its native formatted shape** (read-only), instead of flat plain text. It stays read-only on purpose — re-saving Word through macOS can drop tables/images — with a clear banner pointing you to its app to edit.
- 🐛 **Fixed “can’t open” for UTF-16/UTF-32 text** (`.md`, `.json`, `.csv`, `.txt` saved in those encodings). They were wrongly treated as binary because the encoding check ran after the “looks binary” check — now encoding is probed first, and the original encoding is preserved on save.
- 🧹 **No more leftover `.bak` files.** Saves are atomic (the file can never be left half-written), so backups are **off by default** — turn the `.bak` copy back on in Settings if you want one.

## v0.3.1
- 🖱️ **Edit the Finder selection by button — no Space, no hotkey.** The Home tab has a new “Edit the file selected in Finder” card with **Quick Panel** and **Open Window** buttons, and the menu-bar icon gains **Edit Finder Selection**. Select a file in Finder, click — it opens here. (You can still rebind or turn off the ⌥⌘E shortcut in **Settings → Hotkey**.)

## v0.3.0
- ⚡️ **Quick Panel — press ⌥⌘E to view *and* edit, instantly.** Select a file in Finder and hit **⌥⌘E**: a fast, centered, Quick-Look-style panel appears *in front of Finder* — but unlike Space, it’s the **real editor**. Type to edit, **⌘F** to find, **⌘S** saves in place (format never changes), **Esc** to dismiss. No app-switch, no second “now open it to edit” step.
- 🧩 **Why this, and the honest limit:** macOS makes the *system* Quick Look panel (Space / Finder’s side preview) **read-only** and won’t deliver keystrokes to it — no app can edit or ⌘F *inside* that panel. The Quick Panel is the closest possible: a look-alike that **is** editable. Use **Space** to glance (read-only, now with your render options) and **⌥⌘E** to edit the same file.
- 🎚️ Toggle in **Settings → Hotkey**: “Hotkey opens a Quick Panel (vs. a full window).” PDFs always open as a full window (they need their annotate/page toolbar).
- 🧰 The editor now has a compact bottom action bar (Save · Reload · Reveal · ⌘F hint) that works in both the window and the panel.

## v0.2.1
- 📄 **`.txt` now previews with Qedit.** Plain-text files are handled by Qedit’s Quick Look preview (with the Qedit badge) and by Open With → Qedit, alongside Markdown and code. Note: macOS and Syntax Highlight also handle plain text, so switch them off in the **Extensions** tab for Qedit to win `.txt` on Space.
- ℹ️ **About editing & ⌘F in the Space preview:** macOS Quick Look previews (Space, and Finder’s side preview pane) are **read-only and don’t receive keystrokes** — no app can edit or run ⌘F *inside* that panel. Editing, ⌘F find, highlight and the other tools live in Qedit’s **editor**: right-click → **Open With → Qedit**, press **⌥⌘E**, or double-click if you set Qedit as the default opener.

## v0.2.0
- 🎛️ **Markdown preview options.** New **Settings → Preview** tab lets you tune how Qedit renders Markdown — **Theme** (Auto / Light / Dark), **GitHub-flavored Markdown** (tables, task lists, ~~strikethrough~~, autolinks), **hard line breaks**, **syntax highlighting**, and **clickable heading anchors**. Your choices are shared with the Quick Look extension, so they control the **Space preview** in Finder.
- 🔀 **Right where you need it:** the Preview tab links straight to the **Extensions** tab, where turning off a competing previewer (QLMarkdown, Syntax Highlight) so Qedit wins Space is one reversible tap.
- ♻️ Changing an option refreshes Quick Look automatically so the next Space press shows it.

## v0.1.10
- 🪟 **No more double dashboard.** Reopening Qedit from the Dock or menu bar after closing its window opened *two* identical dashboards — now it’s always one.
- 🧼 **Freshly opened files aren’t marked “Edited.”** Opening a file no longer flips it to a dirty/“Edited” state (which had enabled Save and could trigger a needless backup) — it only marks edited once you actually change something.
- ⬆️ **Open With reliably brings the file’s editor to the front** on a cold launch, instead of leaving it hidden behind the dashboard.

## v0.1.9
- 🖊️ **The editor actually opens now.** “Open With → Qedit” (and ⌥⌘E) reliably brings the file’s editor window to the front — previously it could open *behind* the dashboard or, on a cold launch, not appear at all (the file just landed in “Recent”). Opening a file now surfaces just that file; the dashboard tucks away (reopen it from the menu-bar icon).
- 📄 **Word, RTF & OpenDocument open for reading + ⌘F find.** `.docx`, `.doc`, `.rtf`, `.rtfd` and `.odt` now open read-only in the editor so you can read and search them — Qedit won’t rewrite their formatting, so edit them in their own app. They’re in the **Open With** menu too.
- 🎚️ **One-tap conflict switches.** The “another extension wins your Space preview” card now has a simple **on/off switch per extension** (QLMarkdown, Syntax Highlight…), and it stays visible so you can flip them back on — no more dead-ends.
- 🧹 **Simpler Setup.** Removed the pile of half-working “activate/install” buttons. Setup now says the one thing that matters (Open With → Qedit to edit/find) and is honest about the Space/Quick Look trade-off, with one button to manage it.

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
