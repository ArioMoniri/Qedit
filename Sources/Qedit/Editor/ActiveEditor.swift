import Foundation
import Combine

/// A tiny cross-cutting bridge so a *container* — the Qedit Browser window, or the Quick Panel's
/// "follow Finder selection" auto-swap — can know whether the editor it currently hosts has
/// unsaved edits, and can flush them, WITHOUT owning each per-type editor's private document state.
///
/// Every editable editor (text/rich, spreadsheet, PDF, …) registers itself while it is on screen
/// and resigns when it leaves. Only one editor is "active" at a time (the front editing surface),
/// keyed by URL. The container consults `isDirty` before swapping files and calls `saveNow()` to
/// persist, so switching files in a single pane never silently discards unsaved work.
@MainActor
final class ActiveEditor: ObservableObject {
    static let shared = ActiveEditor()

    /// URL of the editor currently registered, or nil when nothing editable is on screen.
    @Published private(set) var url: URL?
    /// Whether that editor has unsaved edits right now.
    @Published private(set) var isDirty = false

    /// Synchronous save provided by the active editor. Returns true on success (or nothing to do).
    private var saveAction: (() -> Bool)?

    private init() {}

    /// Publish the active editor's live dirty state + a synchronous save closure. Safe to call
    /// repeatedly (e.g. on every change) — the latest registration wins.
    func register(url: URL, isDirty: Bool, save: @escaping () -> Bool) {
        self.url = url
        self.isDirty = isDirty
        self.saveAction = save
    }

    /// Called by an editor as it leaves the screen — but only clears state if it is still the
    /// active one (a freshly-mounted editor may already have registered itself by then).
    func resign(url: URL) {
        guard self.url?.standardizedFileURL == url.standardizedFileURL else { return }
        self.url = nil
        self.isDirty = false
        self.saveAction = nil
    }

    /// Synchronously save the active editor's edits. Returns true if saved (or there was nothing
    /// to save); false if a save was attempted and failed.
    @discardableResult
    func saveNow() -> Bool {
        guard isDirty, let saveAction else { return true }
        let ok = saveAction()
        if ok { isDirty = false }
        return ok
    }
}
