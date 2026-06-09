# Changelog

All notable changes to Qedit. This file feeds both the GitHub release notes and the
in-app Sparkle updater. 🪄

## v0.7.4
- 🤝 **Qedit coexists with your other Quick Look plugins — no more “switch them off”.** Removed the old “Another extension wins your Space preview / Switch all off — use Qedit” panel from the Extensions tab. Since Qedit edits in its **own** window (Browser ⌥⌘B, ⌥⌘E) and falls back to whatever Quick Look plugins you have installed, there’s no need to disable QLMarkdown, Syntax Highlight, etc. You can still toggle any individual extension in the Extensions list, and the Settings copy now reflects coexistence rather than competition.

## v0.7.3
- 📦 **One-command install for the whole suite.** A single command sets up **Qedit + [ChangeX](https://github.com/ArioMoniri/changex)** and turns on their Quick Look previews — `curl … | bash` on macOS/Linux, `irm … | iex` on Windows. (Windows installs the cross-platform ChangeX + its preview and points you to the QuickLook app; Qedit’s editor is macOS-only.) See the README.
- 📝 **Refreshed README** — now documents the Browser, in-place editing of Word/Excel/PowerPoint, live change highlighting, the configurable Browser shortcut, the Quick Look fallback, and an honest cross-platform install matrix.

## v0.7.2
- 🖍️ **Change highlighting now works in code files too.** Syntax coloring and change-marks were both writing to the same place, so re-coloring code could wipe the change marks. Change marks are now drawn as a separate display-only layer (like in the rich-text editor), so your edits stay highlighted in `.swift`, `.py`, `.js`, `.json` and every other code/config file — alongside syntax colors.
- 🔌 **Qedit’s window now works with all your Quick Look plugins.** For any file Qedit can’t edit as text (images, archives, or anything a third-party Quick Look plugin handles — QLMarkdown, Syntax Highlight, etc.), the editor/Browser now shows a **live macOS Quick Look preview** that uses every plugin you have installed, instead of a “can’t open” dead end. Open it in its app to edit.

## v0.7.1
- 🖍️ **Change highlighting actually works now — and in every editor.** It marks *exactly* what you changed: type “hi asfas” over “hi” and only “ asfas” lights up (a real word-level diff, so several separate edits each highlight instead of one big block), with a dashed mark where text was **removed**. It now runs in **text/code/Markdown, Word/RTF/ODT, Excel cells, CSV and PowerPoint text** — not just plain text. Toggling it (or the style) in Settings now applies to already-open editors immediately.
- 🪟 **One Settings, one window.** Settings moved *inside* the main Qedit window (sidebar → **Settings**); there’s no longer a separate, different-looking preferences window. **⌘,** and the menu-bar item jump straight to it.
- ⌨️ **Browse Files shortcut is yours to choose.** ⇧⌘B clashed with other shortcuts, so the Browser now has its own **configurable global shortcut** (Settings → Shortcut → “Browse Files shortcut”, default **⌥⌘B**) that you can re-record or turn off — and it works whenever Qedit is running, not only when a window is focused.
- 💾 **The Word/PowerPoint backup is now optional.** It’s still on by default (re-saving those formats can simplify formatting), but there’s a switch: **Settings → Editing → “Back up Word/PowerPoint before the first edit.”** Turn it off if you don’t want any `.bak` files.
- 🙈 **Editor banners are dismissible.** Click the **✕** on any editor banner, or turn them all off in **Settings → Editing → “Show editor info banners.”** Save and the other buttons always stay.

## v0.7.0
- 🗂️ **New: the Qedit Browser — edit files from a live preview pane.** A new window (**⇧⌘B**, or the “Browse & edit files” card / menu‑bar item) shows a folder list on the left and a **fully editable editor on the right**: click any file and it opens *right there* ready to edit — find with **⌘F**, save in place — with **no Space and no shortcut**. Switching files while you have unsaved edits asks before discarding. This is the legitimate macOS answer to “edit in the preview”: Apple’s Quick Look pane (Space / Finder’s preview) is read‑only and receives no keystrokes, so no app can edit *inside Finder’s own* pane — this is Qedit’s editable equivalent.
- 🧲 **Quick Panel can follow the Finder selection.** Turn on **Settings → Shortcut → “Follow Finder selection”**: while the Quick Panel is open, clicking through files in Finder re‑loads each one into the panel — a live, editable preview. It waits while you’re typing and never swaps away from unsaved edits. Uses the Finder‑read permission you already granted (no new prompt).
- ✍️ **Word & Excel are editable by default now.** `.docx`/`.doc` and `.xlsx` open ready to edit (no more hunting for a toggle). Word always keeps one `.bak` the first time you save it (re‑saving can simplify complex formatting); Excel still rewrites only the cells you changed and preserves styles/number formats/formulas.
- 🖼️ **Edit PowerPoint text in place (opt‑in).** **Settings → Editing → “Allow editing PowerPoint text (.pptx)”** adds a panel beside the rendered slides listing the simple title/bullet lines — edit one and **Save** rewrites just that line inside the `.pptx`, keeping layout, images and formatting. Mixed‑format and table/chart text stay read‑only. Rewrites only changed runs and refuses to save anything it can’t edit safely.
- 📄 **Better PDF “Replace Text.”** Replacements now match the **original font, size and color** (instead of generic system black) and blend into the page color, plus a new **Save & Flatten** option burns annotations into the page for printing/sharing.
- ℹ️ **An honest limit:** macOS does not allow *any* app to edit inside Finder’s own Quick Look preview region (Space / the preview pane) — it’s read‑only by design and delivers no keystrokes. The Browser window and follow‑Finder Quick Panel above are the closest legitimate substitutes; `.webarchive` stays read‑only (re‑saving it would silently drop images/scripts).

## v0.6.2
- 🎞️ **PowerPoint renders the REAL slides now.** `.pptx` opens in a native Quick Look view (actual layout, images and text) instead of extracted text — fixes blank/incorrect slides for image- or SmartArt-based decks.
- ➗ **Math, emoji & smart quotes in Markdown preview** (Settings → Preview): **LaTeX math** via KaTeX rendered as MathML (offline, no extra fonts), `:shortcode:` → **emoji**, and **curly quotes / en–em dashes**. (These join GFM, hard breaks, syntax highlighting and heading anchors.)
- 🖍️ **Change highlighting is ON by default** — your edits show colored as you type (change the style or turn it off in Settings → Editing).

## v0.6.1
- ⌨️ **Clearer shortcut + macOS settings buttons.** Settings → Shortcut now shows your **current shortcut** in big type, adds an **“Open macOS Keyboard Settings”** button, and a **“Show Qedit when you press Space”** section that explains the Space/Quick-Look rule and gives one‑tap buttons to **make Qedit win Space** (Extensions) and to **open macOS’s Extensions settings**.

## v0.6.0
- 🔎 **⌘F now works in spreadsheets and presentations.** Press **⌘F** in an `.xlsx`/`.csv` grid or a `.pptx` slide view to find — matching cells/paragraphs highlight, **n/N** counts, ↑/↓ step through them and the view scrolls to each. (Text/code/RTF/Word already had ⌘F — so find now spans **every** supported type.)
- ✏️ **PDF text editing (beta).** Select text in a PDF, click **Replace Text** — Qedit covers it and drops an editable text box pre‑filled with the original, so you can **type a correction over it** and Save back into the `.pdf`. It’s an overlay edit (double‑click to edit the text), not full reflow, and the original glyphs stay underneath (so it’s not redaction for privacy).

## v0.5.6
- 🛟 **Much safer spreadsheet editing.** Rewrote how `.xlsx` saves: it now changes **only the cells you actually edited** (everything else — styles, number formats, other sheets, formulas — is preserved byte‑for‑byte), resolves the **correct worksheet** (not just “sheet1”), drops `calcChain` after a formula edit so Excel won’t show a repair prompt, **makes a backup first**, and reports a clear message if a workbook is too complex to edit safely. This replaces v0.5.5’s simpler writer, which could lose formatting on real workbooks.

## v0.5.5
- 📝 **Edit spreadsheet cells.** New **Settings → Editing → “Allow editing spreadsheet cells (.xlsx)”** turns the cell grid editable — change values and **Save** writes them straight back into the `.xlsx` in place (verified: the rewritten file is a valid workbook with other sheets/styles preserved). Off by default; values only (formulas/number formats are dropped), so keep `.bak` on for important sheets.

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
