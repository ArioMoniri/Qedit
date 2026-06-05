import SwiftUI

/// Holds the Markdown-preview options and writes them to the shared App Group container
/// (where the Quick Look extension reads them), refreshing Quick Look so changes show.
@MainActor
final class RenderPrefsStore: ObservableObject {
    @Published var prefs: RenderPrefs { didSet { persist() } }

    init() { prefs = RenderPrefs.load() }

    private func persist() {
        let saved = prefs.save()
        // Drop Quick Look's cached previews so the next Space press re-renders with the change.
        if saved { Task.detached { _ = Diagnostics.resetQuickLookCache() } }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var hotKey = HotKeyStore.shared
    @StateObject private var render = RenderPrefsStore()

    var body: some View {
        TabView {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appState.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("Previews and the code preview follow the system light/dark automatically; "
                         + "this overrides the editor and app windows.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("When the window closes") {
                    Toggle("Keep Qedit running in the menu bar", isOn: $appState.keepRunningInBackground)
                    Text("On: closing the window drops the Dock icon and keeps Qedit running in the "
                         + "background (the global hotkey and Quick Action stay live); use the menu-bar "
                         + "icon to reopen or quit. Off: closing the last window quits Qedit.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Editing safety") {
                    Toggle("Make a timestamped backup before the first save", isOn: $appState.makeBackupBeforeFirstWrite)
                    Text("Editing real files is destructive. When on, Qedit copies the original to a "
                         + "`.bak` file next to it the first time you save in a session.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Recent files") {
                    Button("Clear Recent Files") { appState.clearRecents() }
                        .disabled(appState.recentFiles.isEmpty)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }
            .frame(width: 480, height: 380)

            Form {
                Section("Global hotkey") {
                    Toggle("Open the Finder selection with a hotkey", isOn: $hotKey.enabled)
                    HStack {
                        Text("Shortcut")
                        Spacer()
                        HotKeyRecorder(config: $hotKey.config)
                            .frame(width: 150, height: 24)
                            .disabled(!hotKey.enabled)
                        Button("Reset") { hotKey.config = .default }
                            .controlSize(.small)
                    }
                    Text("Select a file in Finder and press the shortcut to open it in Qedit. "
                         + "The first use prompts macOS for permission to control Finder.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Hotkey", systemImage: "command") }
            .frame(width: 480, height: 240)

            Form {
                Section("Markdown preview") {
                    Picker("Theme", selection: $render.prefs.theme) {
                        ForEach(RenderPrefs.Theme.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("GitHub-flavored Markdown", isOn: $render.prefs.gfm)
                    Toggle("Hard line breaks", isOn: $render.prefs.hardBreaks)
                    Toggle("Syntax highlighting in code", isOn: $render.prefs.syntaxHighlighting)
                    Toggle("Clickable heading anchors", isOn: $render.prefs.headingAnchors)
                    Text("GitHub-flavored Markdown adds tables, task lists, ~~strikethrough~~ and "
                         + "autolinks. These apply to Qedit’s preview.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Showing on Space in Finder") {
                    Text("macOS shows only one Quick Look preview per file type. If QLMarkdown or "
                         + "Syntax Highlight is installed, Qedit’s preview (with these options) only "
                         + "appears once you switch them off — do that in the app’s **Extensions** tab, "
                         + "where it’s one tap and fully reversible.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                        EditorLauncher.shared.openMainWindow?()
                        // Let the dashboard appear, then switch it to the Extensions tab.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            NotificationCenter.default.post(name: .qeditShowExtensions, object: nil)
                        }
                    } label: {
                        Label("Open Extensions tab", systemImage: "puzzlepiece.extension")
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Preview", systemImage: "doc.richtext") }
            .frame(width: 480, height: 420)
        }
    }
}
