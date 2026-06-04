import SwiftUI
import AppKit

/// Opens editor windows from places that don't have the SwiftUI view environment —
/// the `qedit://` URL handler and the global hotkey. `RootView` injects the actual
/// `openWindow` action on appear.
@MainActor
final class EditorLauncher: ObservableObject {
    static let shared = EditorLauncher()

    /// Set by `RootView.onAppear`. Captures `@Environment(\.openWindow)`.
    var openEditorWindow: ((URL) -> Void)?
    /// Reopen the dashboard window (used when the Dock icon is clicked with no windows open).
    var openMainWindow: (() -> Void)?

    func open(_ url: URL) {
        AppState.shared.noteOpened(url)
        // Coming from the hotkey/Quick Action: restore the regular app (Dock icon) and front it.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let openEditorWindow {
            openEditorWindow(url)
        }
    }

    /// Open whatever is selected in Finder (used by the global hotkey).
    @discardableResult
    func openFinderSelection() -> Bool {
        guard let url = FinderSelection.currentFileURL() else {
            NSSound.beep()
            return false
        }
        open(url)
        return true
    }
}
