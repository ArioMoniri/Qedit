import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            // Register the configurable global hotkey (default ⌥⌘E → open Finder selection).
            HotKeyManager.shared.start()
            // Apply the saved appearance override (System / Light / Dark).
            AppState.shared.applyAppearance()
            // Start Sparkle so scheduled background update checks run.
            _ = UpdaterController.shared
        }
    }

    /// Opt in to secure state restoration (silences the macOS warning and is good practice).
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Keep the app alive when the last window closes — the global hotkey and background
    /// update checks keep working, and the app stays in the Dock.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Clicking the Dock icon with no windows open reopens the dashboard.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainActor.assumeIsolated { EditorLauncher.shared.openMainWindow?() }
        }
        return true
    }
}
