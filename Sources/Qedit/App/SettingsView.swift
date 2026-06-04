import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var hotKey = HotKeyStore.shared

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
        }
    }
}
