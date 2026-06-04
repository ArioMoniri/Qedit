import SwiftUI
import AppKit

/// Opens editor windows from places that don't have the SwiftUI view environment —
/// the `qedit://` URL handler and the global hotkey. `RootView` injects the actual
/// `openWindow` action on appear.
@MainActor
final class EditorLauncher: ObservableObject {
    static let shared = EditorLauncher()

    /// Set by `RootView.onAppear`. Captures `@Environment(\.openWindow)`. When it becomes
    /// available we flush any opens that arrived during launch (Open With at cold start).
    var openEditorWindow: ((URL) -> Void)? {
        didSet { flushPending() }
    }
    /// Reopen the dashboard window (used when the Dock icon is clicked with no windows open).
    var openMainWindow: (() -> Void)?
    /// Open the SwiftUI Settings scene (used by the menu-bar item).
    var openSettings: (() -> Void)?

    private var pendingURLs: [URL] = []

    func open(_ url: URL) {
        AppState.shared.noteOpened(url)
        // Restore the regular app (Dock icon) and front it.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let openEditorWindow {
            openEditorWindow(url)
        } else {
            // Cold start (e.g. Open With launched us): buffer until RootView wires the opener.
            pendingURLs.append(url)
        }
    }

    private func flushPending() {
        guard let openEditorWindow, !pendingURLs.isEmpty else { return }
        let urls = pendingURLs
        pendingURLs.removeAll()
        for url in urls { openEditorWindow(url) }
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
