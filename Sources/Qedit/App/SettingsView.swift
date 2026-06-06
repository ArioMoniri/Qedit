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
        .frame(width: 520)
    }

    private func tab<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView { VStack(spacing: 14) { content() }.padding(18) }
            .frame(width: 520, height: 470)
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
                           detail: "As you edit, the changed text is marked so you can see your edits at a glance.",
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
                           detail: "Off by default: Word opens read-only because re-saving through macOS can simplify complex formatting (tables/images). On: edit & save in place — turn on the .bak backup below if the doc is complex. (RTF & OpenDocument are always editable.)",
                           isOn: $appState.allowWordEditing)
            }

            SettingsGroup(title: "Spreadsheets",
                          onCount: appState.allowSpreadsheetEditing ? 1 : 0, total: 1) {
                SettingRow(icon: "tablecells", tint: .green,
                           title: "Allow editing spreadsheet cells (.xlsx)",
                           detail: "Off by default: .xlsx opens as a read-only grid. On: edit cell values and Save back to .xlsx — values only (formulas/styles are dropped). Keep .bak on for important files.",
                           isOn: $appState.allowSpreadsheetEditing)
            }

            SettingsGroup(title: "Backup",
                          onCount: appState.makeBackupBeforeFirstWrite ? 1 : 0, total: 1) {
                SettingRow(icon: "doc.badge.clock", title: "Keep a .bak backup file",
                           detail: "Off by default — saves are atomic, so the file is never half-written and no .bak files are left behind. On: keep a timestamped .bak copy next to the file.",
                           isOn: $appState.makeBackupBeforeFirstWrite)
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
        }
    }

    // MARK: - Preview

    private var previewMarkdownOnCount: Int {
        [render.prefs.gfm, render.prefs.hardBreaks,
         render.prefs.syntaxHighlighting, render.prefs.headingAnchors].filter { $0 }.count
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
                          onCount: previewMarkdownOnCount, total: 4) {
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
