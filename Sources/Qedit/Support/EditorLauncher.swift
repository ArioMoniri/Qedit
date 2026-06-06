import SwiftUI
import AppKit

/// Opens editor windows from places that don't have the SwiftUI view environment —
/// the `qedit://` URL handler, "Open With → Qedit", and the global hotkey. `RootView`
/// injects the actual `openWindow` action on appear.
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
    /// Open the Qedit Browser window (folder list + live editable editor).
    var openBrowser: (() -> Void)?

    /// The dashboard window, captured by `RootView`. When the user opens a file (Open With /
    /// hotkey) their intent is "show me THIS file", so we tuck the dashboard away and surface
    /// only the editor.
    weak var dashboardWindow: NSWindow?

    private var pendingURLs: [URL] = []

    func open(_ url: URL) {
        AppState.shared.noteOpened(url)
        // Restore the regular app (Dock icon).
        NSApp.setActivationPolicy(.regular)
        if openEditorWindow != nil {
            present(url)
        } else {
            // Cold start (e.g. Open With launched us): buffer until RootView wires the opener.
            pendingURLs.append(url)
        }
    }

    private func flushPending() {
        guard openEditorWindow != nil, !pendingURLs.isEmpty else { return }
        let urls = pendingURLs
        pendingURLs.removeAll()
        for url in urls { present(url) }
    }

    /// Defer the actual window open by one runloop tick so SwiftUI's window machinery is ready
    /// even at cold launch (otherwise `openWindow` is silently dropped), then raise the new
    /// editor window above the dashboard.
    private func present(_ url: URL) {
        guard let opener = openEditorWindow else { pendingURLs.append(url); return }
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            opener(url)
            self.surfaceEditor(named: url.lastPathComponent)
        }
    }

    /// Raise the editor window for `name` to the front. The main WindowGroup ("Qedit")
    /// otherwise stays key on a cold launch, hiding the file the user asked to open. We only
    /// raise the editor — never hide/close the dashboard — because programmatically closing a
    /// SwiftUI WindowGroup window and reopening it spawns a duplicate. Leaving it untouched
    /// (just behind the editor) is the reliable choice.
    private func surfaceEditor(named name: String, attempt: Int = 0) {
        if let editor = NSApp.windows.first(where: {
            $0 !== dashboardWindow && $0.title == name && Self.isContentWindow($0)
        }) {
            editor.makeKeyAndOrderFront(nil)
            return
        }
        guard attempt < 15 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.surfaceEditor(named: name, attempt: attempt + 1)
        }
    }

    private static func isContentWindow(_ window: NSWindow) -> Bool {
        window.contentView != nil
            && !(window is NSPanel)
            && window.styleMask.contains(.titled)
            && window.className != "NSStatusBarWindow"
    }

    /// Open whatever is selected in Finder (used by the global hotkey). Routes to the fast
    /// Quick Panel (editable, in front of Finder, no app-switch) unless the user prefers a
    /// full window.
    @discardableResult
    func openFinderSelection() -> Bool {
        guard let url = FinderSelection.currentFileURL() else {
            NSSound.beep()
            return false
        }
        // PDFs/spreadsheets/presentations have their own chrome → always a full window.
        // Text-like files use the Quick Panel.
        if AppState.shared.hotkeyOpensQuickPanel && !EditorWindowView.needsWindow(url) {
            QuickPanelController.shared.present(url)
        } else {
            open(url)
        }
        return true
    }
}
