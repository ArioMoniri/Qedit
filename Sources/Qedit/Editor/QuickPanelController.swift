import AppKit
import SwiftUI

/// Owns the single, reused Quick Panel and swaps the previewed file's editor into it.
///
/// The panel hosts the EXISTING `EditorWindowView` (PDF → PDFEditorView, else the text editor
/// with ⌘F + save-in-place) via an `NSHostingView`. The hosting view is kept alive while the
/// panel is hidden, and reused when the same file is re-summoned, so an accidental Esc never
/// drops unsaved edits.
@MainActor
final class QuickPanelController {
    static let shared = QuickPanelController()

    private var panel: QuickPanel?
    private var hosting: NSView?
    private var currentURL: URL?

    /// Show `url` in the Quick Panel, front and key, without activating the app.
    func present(_ url: URL) {
        AppState.shared.noteOpened(url)
        let panel = ensurePanel()

        // Reuse the live editor if the same file is re-summoned (preserves in-progress edits);
        // otherwise build a fresh editor so there's no stale document/scroll/dirty state.
        if currentURL?.standardizedFileURL != url.standardizedFileURL || hosting == nil {
            mountEditor(for: url, in: panel)
            currentURL = url
        }

        panel.title = url.lastPathComponent
        if !panel.isVisible {
            panel.setContentSize(AppState.shared.quickPanelSize.size)
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        // Put the caret in the editor so typing / ⌘F work immediately.
        DispatchQueue.main.async { [weak panel] in
            guard let panel, let content = panel.contentView,
                  let textView = Self.firstTextView(in: content) else { return }
            panel.makeFirstResponder(textView)
        }
        FinderSelectionObserver.shared.refresh()
    }

    func hide() {
        panel?.orderOut(nil)
        FinderSelectionObserver.shared.refresh()
    }

    // MARK: - Follow Finder selection

    /// Swap the previewed file WITHOUT stealing key focus or moving first responder — so the user
    /// can keep arrowing through files in Finder while the panel tracks the selection. They click
    /// into the panel (making it key) when they actually want to type. Only swaps when the panel
    /// is already visible and the file differs from what's shown.
    func follow(_ url: URL) {
        guard let panel, panel.isVisible else { return }
        if currentURL?.standardizedFileURL != url.standardizedFileURL || hosting == nil {
            mountEditor(for: url, in: panel)
            currentURL = url
            AppState.shared.noteOpened(url)
        }
        panel.title = url.lastPathComponent
        panel.orderFrontRegardless()
    }

    /// Whether the panel is on screen.
    var isPanelVisible: Bool { panel?.isVisible ?? false }
    /// Whether the panel is the key window (i.e. the user is typing in it — don't swap then).
    var isPanelKey: Bool { panel?.isKeyWindow ?? false }
    /// The file currently shown in the panel.
    var currentPanelURL: URL? { currentURL }

    // MARK: - Internals

    private func mountEditor(for url: URL, in panel: QuickPanel) {
        // Re-inject AppState — EditorView reads it via @EnvironmentObject (omitting it crashes).
        let root = EditorWindowView(url: url).environmentObject(AppState.shared)
        let view = NSHostingView(rootView: root)
        view.translatesAutoresizingMaskIntoConstraints = false
        guard let container = panel.contentView else { return }
        hosting?.removeFromSuperview()
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        hosting = view
    }

    private func ensurePanel() -> QuickPanel {
        if let panel { return panel }
        let p = QuickPanel()
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        p.contentView = effect
        panel = p
        return p
    }

    private static func firstTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView { return textView }
        for sub in view.subviews {
            if let found = firstTextView(in: sub) { return found }
        }
        return nil
    }
}
