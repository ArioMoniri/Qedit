import SwiftUI

/// Holds the Markdown-preview options and writes them to the shared App Group container
/// (where the Quick Look extension reads them), refreshing Quick Look so changes show.
@MainActor
final class RenderPrefsStore: ObservableObject {
    @Published var prefs: RenderPrefs { didSet { persist() } }

    init() { prefs = RenderPrefs.load() }

    private func persist() {
        let saved = prefs.save()
        if saved { Task.detached { _ = Diagnostics.resetQuickLookCache() } }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var hotKey = HotKeyStore.shared
    @StateObject private var render = RenderPrefsStore()
    @ObservedObject private var syntaxTheme = SyntaxThemeStore.shared

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }
            editingTab.tabItem { Label("Editing", systemImage: "square.and.pencil") }
            shortcutTab.tabItem { Label("Shortcut", systemImage: "command") }
            previewTab.tabItem { Label("Preview", systemImage: "eye") }
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
    }

    private func tab<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView { VStack(spacing: 14) { content() }.padding(18).frame(maxWidth: 600) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - General

    private var generalTab: some View {
        tab {
            SettingsGroup(title: "Appearance") {
                Picker("Theme", selection: $appState.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Light/Dark for Qedit’s windows. Previews follow the system automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            SettingsGroup(title: "Behavior", onCount: appState.keepRunningInBackground ? 1 : 0, total: 1) {
                SettingRow(icon: "menubar.rectangle", title: "Keep running in the menu bar",
                           detail: "Closing the window keeps Qedit alive in the menu bar (hotkey + Quick Action stay live). Off: closing the last window quits.",
                           isOn: $appState.keepRunningInBackground)
            }

            SettingsGroup(title: "Recent files") {
                HStack {
                    Text("\(appState.recentFiles.count) item\(appState.recentFiles.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear Recents") { appState.clearRecents() }
                        .disabled(appState.recentFiles.isEmpty)
                }
            }
        }
    }

    // MARK: - Editing

    private var editingTab: some View {
        tab {
            SettingsGroup(title: "Saving", onCount: appState.autoSave ? 1 : 0, total: 1) {
                SettingRow(icon: "externaldrive.badge.checkmark", tint: .green,
                           title: "Auto-save changes",
                           detail: "Save automatically a moment after you stop typing. ⌘S still saves instantly. Off: save only with ⌘S / the Save button.",
                           isOn: $appState.autoSave)
            }

            SettingsGroup(title: "Live change highlighting",
                          subtitle: "Mark what you’ve changed since opening the file.",
                          onCount: appState.highlightChanges ? 1 : 0, total: 1) {
                SettingRow(icon: "highlighter", tint: .orange,
                           title: "Highlight my changes",
                           detail: "As you edit, exactly the added/changed text is marked (e.g. typing “hi asfas” over “hi” marks just “ asfas”), with a dashed mark where text was removed. Works in text, code, Markdown, Word/RTF, Excel cells and PowerPoint text.",
                           isOn: $appState.highlightChanges)
                if appState.highlightChanges {
                    Picker("Style", selection: $appState.changeHighlightStyle) {
                        ForEach(ChangeHighlightStyle.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }

            SettingsGroup(title: "Code colors",
                          onCount: syntaxTheme.enabled ? 1 : 0, total: 1) {
                SettingRow(icon: "paintpalette", tint: .purple,
                           title: "Customize syntax & change colors",
                           detail: "Off: the editor uses system colors that adapt to light/dark. On: pick your own for keywords, strings, numbers, comments and changed text.",
                           isOn: $syntaxTheme.enabled)
                if syntaxTheme.enabled {
                    HStack(spacing: 8) {
                        Text("Presets").foregroundStyle(.secondary)
                        Spacer()
                        ForEach(SyntaxThemeStore.Preset.allCases) { preset in
                            Button(preset.label) { syntaxTheme.apply(preset) }
                                .controlSize(.small).buttonStyle(.bordered)
                        }
                    }
                    ColorPicker("Keywords", selection: $syntaxTheme.keyword)
                    ColorPicker("Strings", selection: $syntaxTheme.string)
                    ColorPicker("Numbers", selection: $syntaxTheme.number)
                    ColorPicker("Comments", selection: $syntaxTheme.comment)
                    ColorPicker("Changed text", selection: $syntaxTheme.change)
                }
            }

            SettingsGroup(title: "Word documents",
                          onCount: appState.allowWordEditing ? 1 : 0, total: 1) {
                SettingRow(icon: "doc.richtext", tint: .blue,
                           title: "Allow editing Word (.docx/.doc)",
                           detail: "On by default: Word opens ready to edit and saves in place. Re-saving through macOS can simplify complex formatting (tables/images), so Qedit always keeps one .bak backup the first time you save a Word file. Turn off for view-only. (RTF & OpenDocument are always editable.)",
                           isOn: $appState.allowWordEditing)
            }

            SettingsGroup(title: "Spreadsheets",
                          onCount: appState.allowSpreadsheetEditing ? 1 : 0, total: 1) {
                SettingRow(icon: "tablecells", tint: .green,
                           title: "Allow editing spreadsheet cells (.xlsx)",
                           detail: "On by default: edit cell values and Save back to .xlsx. Qedit rewrites only the cells you changed and preserves everything else — styles, number formats, and formulas in other cells. Turn off for a view-only grid.",
                           isOn: $appState.allowSpreadsheetEditing)
            }

            SettingsGroup(title: "Presentations",
                          onCount: appState.allowPptxEditing ? 1 : 0, total: 1) {
                SettingRow(icon: "rectangle.on.rectangle", tint: .orange,
                           title: "Allow editing PowerPoint text (.pptx)",
                           detail: "Off by default. On: a panel lists the simple text lines (titles/bullets) next to the rendered slides — edit one and Save rewrites just that line in place, keeping layout, images and formatting. Mixed-format text and table/chart text stay read-only; open those in Keynote/PowerPoint.",
                           isOn: $appState.allowPptxEditing)
            }

            SettingsGroup(title: "Editor banners",
                          onCount: appState.showEditorBanners ? 1 : 0, total: 1) {
                SettingRow(icon: "info.circle", tint: .blue, title: "Show editor info banners",
                           detail: "The colored notices at the top of the editor (read-only, Word/Excel/PowerPoint tips). Turn off (or click the ✕ on a banner) to hide them; Save and the other buttons stay.",
                           isOn: $appState.showEditorBanners)
            }

            SettingsGroup(title: "Backup",
                          onCount: (appState.makeBackupBeforeFirstWrite ? 1 : 0) + (appState.backupRichBeforeEdit ? 1 : 0),
                          total: 2) {
                SettingRow(icon: "doc.badge.clock", title: "Keep a .bak backup of every file",
                           detail: "Off by default — saves are atomic, so the file is never half-written. On: keep a timestamped .bak copy next to any file before the first save.",
                           isOn: $appState.makeBackupBeforeFirstWrite)
                SettingRow(icon: "doc.badge.clock", tint: .orange,
                           title: "Back up Word/PowerPoint before the first edit",
                           detail: "On by default: because re-saving .docx/.pptx can simplify complex formatting, Qedit keeps one .bak the first time you save one. Turn off if you don’t want any .bak files.",
                           isOn: $appState.backupRichBeforeEdit)
            }
        }
    }

    // MARK: - Shortcut

    private var shortcutTab: some View {
        tab {
            SettingsGroup(title: "Quick-Look → edit hotkey",
                          subtitle: "Select a file in Finder, press the shortcut to open it here.",
                          onCount: hotKey.enabled ? 1 : 0, total: 1) {
                SettingRow(icon: "bolt", title: "Enable the global hotkey",
                           detail: "First use asks macOS for permission to read the Finder selection.",
                           isOn: $hotKey.enabled)

                HStack {
                    Text("Current shortcut").foregroundStyle(.secondary)
                    Spacer()
                    Text(hotKey.enabled ? hotKey.config.displayString : "Off")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                }

                Text("Quick presets").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                HStack(spacing: 8) {
                    ForEach(HotKeyConfig.presets, id: \.displayString) { preset in
                        Button {
                            hotKey.config = preset; hotKey.enabled = true
                        } label: {
                            Text(preset.displayString)
                                .font(.system(.callout, design: .rounded).weight(.semibold))
                                .frame(minWidth: 52)
                        }
                        .buttonStyle(.bordered).buttonBorderShape(.roundedRectangle)
                        .tint(hotKey.config == preset ? .accentColor : .secondary)
                    }
                }
                .disabled(!hotKey.enabled)

                HStack {
                    Text("Or record your own").foregroundStyle(.secondary)
                    Spacer()
                    HotKeyRecorder(config: $hotKey.config)
                        .frame(width: 140, height: 24).disabled(!hotKey.enabled)
                    Button("Reset") { hotKey.config = .default }.controlSize(.small)
                }
                Text("Space alone can’t be a global shortcut (it would block typing), so the Space presets add a modifier.")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    Permissions.openKeyboardSettings()
                } label: { Label("Open macOS Keyboard Settings", systemImage: "keyboard") }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
            }

            SettingsGroup(title: "Space preview (works alongside your other plugins)") {
                Text("Pressing **Space** in Finder is macOS Quick Look, which shows one preview per "
                     + "type. **Qedit coexists with your other Quick Look plugins** (QLMarkdown, Syntax "
                     + "Highlight, …) — you don’t need to disable anything. To **edit** a file, use the "
                     + "**Browser** (⌥⌘B) or **⌥⌘E**, or open it in Qedit. If you’d specifically prefer "
                     + "Qedit’s Space preview for a type, you can toggle plugins in the Extensions "
                     + "manager — entirely optional.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button {
                        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
                        EditorLauncher.shared.openMainWindow?()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            NotificationCenter.default.post(name: .qeditShowExtensions, object: nil)
                        }
                    } label: { Label("Open Extensions Manager", systemImage: "puzzlepiece.extension") }
                        .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
                    Button {
                        Permissions.openLoginItemsAndExtensions()
                    } label: { Label("macOS Extensions Settings", systemImage: "gearshape") }
                        .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
                }
            }

            SettingsGroup(title: "Where it opens",
                          onCount: appState.hotkeyOpensQuickPanel ? 1 : 0, total: 1) {
                SettingRow(icon: "rectangle.center.inset.filled", title: "Open in a Quick Panel",
                           detail: "On: a fast, centered, Quick-Look-style panel that IS the editor (type, ⌘F, ⌘S, Esc), no app-switch. Off: a full editor window.",
                           isOn: $appState.hotkeyOpensQuickPanel)
                if appState.hotkeyOpensQuickPanel {
                    HStack {
                        Text("Panel size").foregroundStyle(.secondary)
                        Spacer()
                        Picker("Panel size", selection: $appState.quickPanelSize) {
                            ForEach(QuickPanelSize.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 240)
                    }
                }
            }

            SettingsGroup(title: "Follow Finder selection",
                          onCount: appState.followFinderSelection ? 1 : 0, total: 1) {
                SettingRow(icon: "filemenu.and.cursorarrow", title: "Track the Finder selection",
                           detail: "While the Quick Panel is open, clicking through files in Finder re-loads each one into the panel — like a live, editable preview pane. It waits while you’re typing in the panel and never swaps away from unsaved edits. Uses the Finder-read permission you already granted.",
                           isOn: $appState.followFinderSelection)
            }

            SettingsGroup(title: "Browse Files shortcut",
                          subtitle: "Open the Qedit Browser (folder list + live editable editor) from anywhere.",
                          onCount: hotKey.browserEnabled ? 1 : 0, total: 1) {
                SettingRow(icon: "sidebar.right", title: "Enable the Browser shortcut",
                           detail: "A global shortcut that opens the Browser window. Default ⌥⌘B (⇧⌘B can clash with system shortcuts) — record your own below.",
                           isOn: $hotKey.browserEnabled)
                HStack {
                    Text("Current shortcut").foregroundStyle(.secondary)
                    Spacer()
                    Text(hotKey.browserEnabled ? hotKey.browserConfig.displayString : "Off")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                }
                HStack {
                    Text("Record your own").foregroundStyle(.secondary)
                    Spacer()
                    HotKeyRecorder(config: $hotKey.browserConfig)
                        .frame(width: 140, height: 24).disabled(!hotKey.browserEnabled)
                    Button("Reset") { hotKey.browserConfig = .defaultBrowser }.controlSize(.small)
                }
            }
        }
    }

    // MARK: - Preview

    private var previewMarkdownOnCount: Int {
        [render.prefs.gfm, render.prefs.hardBreaks, render.prefs.syntaxHighlighting,
         render.prefs.headingAnchors, render.prefs.math, render.prefs.emoji,
         render.prefs.smartQuotes].filter { $0 }.count
    }

    private var previewTab: some View {
        tab {
            SettingsGroup(title: "Theme") {
                Picker("Theme", selection: $render.prefs.theme) {
                    ForEach(RenderPrefs.Theme.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            SettingsGroup(title: "Markdown rendering",
                          subtitle: "Applies to Qedit’s Quick Look (Space) preview.",
                          onCount: previewMarkdownOnCount, total: 7) {
                SettingRow(icon: "tablecells", tint: .blue, title: "GitHub-flavored Markdown",
                           detail: "Tables, task lists, ~~strikethrough~~ and autolinks.",
                           isOn: $render.prefs.gfm)
                SettingRow(icon: "arrow.turn.down.left", tint: .blue, title: "Hard line breaks",
                           detail: "Treat single newlines as line breaks.",
                           isOn: $render.prefs.hardBreaks)
                SettingRow(icon: "curlybraces", tint: .blue, title: "Syntax highlighting in code",
                           detail: "Color fenced code blocks.",
                           isOn: $render.prefs.syntaxHighlighting)
                SettingRow(icon: "number", tint: .blue, title: "Clickable heading anchors",
                           detail: "Add anchor links to headings.",
                           isOn: $render.prefs.headingAnchors)
                SettingRow(icon: "function", tint: .blue, title: "Math (LaTeX)",
                           detail: "Render $…$ and $$…$$ as math (KaTeX → MathML, no extra fonts).",
                           isOn: $render.prefs.math)
                SettingRow(icon: "face.smiling", tint: .blue, title: "Emoji shortcodes",
                           detail: "Turn :rocket: into 🚀.",
                           isOn: $render.prefs.emoji)
                SettingRow(icon: "quote.opening", tint: .blue, title: "Smart quotes",
                           detail: "Curly quotes and en/em dashes.",
                           isOn: $render.prefs.smartQuotes)
            }

            SettingsGroup(title: "Showing on Space") {
                Text("macOS shows one preview per type. If QLMarkdown / Syntax Highlight is on, Qedit’s preview only appears once you switch them off — one tap in Extensions.")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    EditorLauncher.shared.openMainWindow?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        NotificationCenter.default.post(name: .qeditShowExtensions, object: nil)
                    }
                } label: {
                    Label("Open Extensions tab", systemImage: "puzzlepiece.extension")
                }
                .buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
        }
    }
}
