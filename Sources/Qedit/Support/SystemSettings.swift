import AppKit

/// Deep-links into System Settings. A plugin manager can't toggle another app's Quick Look
/// extension programmatically — we can only take the user to the right pane and explain.
enum SystemSettings {
    static func openExtensions() {
        let candidates = [
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) { return }
        }
    }
}
