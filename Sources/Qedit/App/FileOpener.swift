import AppKit

/// Small wrapper around `NSOpenPanel` used by the dashboard and the ⌘O menu command.
@MainActor
enum FileOpener {
    static func runOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a file to find & edit — Qedit never changes its format."
        panel.prompt = "Open"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
