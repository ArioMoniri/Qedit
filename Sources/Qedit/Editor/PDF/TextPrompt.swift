import AppKit

/// A tiny modal text prompt (used when placing a note or text-box annotation).
enum TextPrompt {
    @MainActor
    static func run(title: String, message: String, initial: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = initial
        field.placeholderString = "Type here…"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }
}
