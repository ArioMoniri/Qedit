import Foundation

/// Reads the front Finder window's current selection via Apple Events. Requires the
/// app to be unsandboxed (it is) and triggers the one-time Automation permission prompt.
enum FinderSelection {
    private static let source = """
    tell application "Finder"
        set sel to selection
        if (count of sel) is 0 then return ""
        return POSIX path of (item 1 of sel as alias)
    end tell
    """

    /// One compiled script, reused across calls — the "follow Finder selection" poller invokes this
    /// repeatedly, so we avoid recompiling the AppleScript each time. NSAppleScript is main-thread.
    private static let cached: NSAppleScript? = NSAppleScript(source: source)

    static func currentFileURL() -> URL? {
        var error: NSDictionary?
        guard let script = cached ?? NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if let error { NSLog("Qedit: Finder selection error: \(error)"); return nil }
        guard let path = result.stringValue, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }
}
