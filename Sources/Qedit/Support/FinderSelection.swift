import Foundation

/// Reads the front Finder window's current selection via Apple Events. Requires the
/// app to be unsandboxed (it is) and triggers the one-time Automation permission prompt.
enum FinderSelection {
    static func currentFileURL() -> URL? {
        let source = """
        tell application "Finder"
            set sel to selection
            if (count of sel) is 0 then return ""
            return POSIX path of (item 1 of sel as alias)
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if let error { NSLog("Qedit: Finder selection error: \(error)"); return nil }
        guard let path = result.stringValue, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }
}
