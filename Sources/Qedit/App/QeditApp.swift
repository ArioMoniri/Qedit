import SwiftUI

@main
struct QeditApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Main dashboard window.
        WindowGroup("Qedit", id: "main") {
            RootView()
                .environmentObject(appState)
                .onOpenURL { handleOpenURL($0) }
        }
        .commands { AppMenuCommands() }

        // One editor window per file URL. Reopening the same URL re-focuses its window.
        WindowGroup(id: "editor", for: URL.self) { $url in
            EditorWindowView(url: url)
                .environmentObject(appState)
        }
        .defaultSize(width: 920, height: 660)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }

    /// Handle `qedit://open?path=...` coming from the Quick Action.
    private func handleOpenURL(_ url: URL) {
        guard let path = AppInfo.path(fromOpenURL: url) else { return }
        EditorLauncher.shared.open(URL(fileURLWithPath: path))
    }
}

struct AppMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") { UpdaterController.shared.checkForUpdates() }
        }
        CommandGroup(replacing: .newItem) {
            Button("Open…") {
                if let url = FileOpener.runOpenPanel() {
                    AppState.shared.noteOpened(url)
                    openWindow(id: "editor", value: url)
                }
            }
            .keyboardShortcut("o", modifiers: .command)
        }
        CommandGroup(replacing: .help) {
            Link("Qedit on GitHub", destination: URL(string: "https://github.com/ArioMoniri/Qedit")!)
        }
    }
}
