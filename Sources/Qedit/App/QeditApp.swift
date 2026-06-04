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

    /// Handle `qedit://open?path=...` coming from the Quick Action / global hotkey.
    private func handleOpenURL(_ url: URL) {
        guard let path = AppInfo.path(fromOpenURL: url) else { return }
        let fileURL = URL(fileURLWithPath: path)
        appState.noteOpened(fileURL)
        OpenEditorRequest.shared.send(fileURL)
    }
}

/// Bridges the App-level `onOpenURL` to a SwiftUI `openWindow` action, which is only
/// available inside the view environment. `RootView` subscribes and opens the window.
@MainActor
final class OpenEditorRequest: ObservableObject {
    static let shared = OpenEditorRequest()
    @Published var pending: URL?
    func send(_ url: URL) { pending = url }
}

struct AppMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
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
