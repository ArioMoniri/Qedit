import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Opt in to secure state restoration (silences the macOS warning and is good practice).
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Keep the app alive when the last editor window closes; the dashboard remains reachable.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
