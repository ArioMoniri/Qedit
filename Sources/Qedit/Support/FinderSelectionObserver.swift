import AppKit

/// Drives the Quick Panel to follow the Finder selection, so it behaves like a live editable
/// preview pane: click through files in Finder and the open panel re-loads each one — no Space and
/// no hotkey per file. This is the closest legitimate substitute for editing inside Finder's own
/// preview region (which is read-only and receives no keystrokes — no app can edit there).
///
/// Designed to be cheap and unsurprising:
/// - Runs ONLY while the panel is visible AND the user enabled "Follow Finder selection".
/// - SUSPENDS while the panel is the key window (you're typing — don't yank the file out).
/// - DWELL-debounces: a new selection must hold steady for two ticks before we swap, so arrowing
///   through a folder doesn't thrash the editor.
/// - HARD-SKIPS while the open editor has unsaved edits (never discard your work silently).
/// - Acts only on single, text-like files (skips PDFs/sheets/slides/binaries — they need a window).
/// - Uses only the already-granted Finder-read (Automation) permission — no new TCC prompt.
@MainActor
final class FinderSelectionObserver {
    static let shared = FinderSelectionObserver()

    private var timer: Timer?
    private var candidate: URL?     // selection seen last tick, awaiting a confirming second tick
    private let interval: TimeInterval = 0.6

    private init() {}

    /// Re-evaluate whether the poller should be running. Call when the toggle changes or the panel
    /// shows/hides. Running == feature on AND panel visible.
    func refresh() {
        let shouldRun = AppState.shared.followFinderSelection && QuickPanelController.shared.isPanelVisible
        if shouldRun { start() } else { stop() }
    }

    private func start() {
        guard timer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.2
        timer = t
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        candidate = nil
    }

    private func tick() {
        let panel = QuickPanelController.shared
        // Conditions can change between ticks; bail (and stop) if we shouldn't be running.
        guard AppState.shared.followFinderSelection, panel.isPanelVisible else { stop(); return }
        guard !panel.isPanelKey else { candidate = nil; return }   // user is typing — leave it alone
        guard !ActiveEditor.shared.isDirty else { candidate = nil; return }  // unsaved edits — never swap

        guard let url = FinderSelection.currentFileURL(),
              EditorWindowView.isTextLike(url) else { candidate = nil; return }
        if url.standardizedFileURL == panel.currentPanelURL?.standardizedFileURL { candidate = nil; return }

        // Dwell: only swap once the same new file has been selected for two consecutive ticks.
        if candidate?.standardizedFileURL == url.standardizedFileURL {
            candidate = nil
            panel.follow(url)
        } else {
            candidate = url
        }
    }
}
