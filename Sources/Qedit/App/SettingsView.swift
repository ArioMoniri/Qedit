import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            Form {
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
            .frame(width: 460, height: 280)
        }
    }
}
