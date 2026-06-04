import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register the configurable global hotkey (default ⌥⌘E → open Finder selection).
        MainActor.assumeIsolated { HotKeyManager.shared.start() }
    }

    /// Opt in to secure state restoration (silences the macOS warning and is good practice).
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Keep the app alive when the last editor window closes; the dashboard remains reachable.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
