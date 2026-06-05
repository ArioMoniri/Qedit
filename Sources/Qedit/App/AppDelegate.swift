import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            HotKeyManager.shared.start()          // global hotkey (works in the background too)
            AppState.shared.applyAppearance()     // System / Light / Dark
            _ = UpdaterController.shared          // start Sparkle
            setupStatusItem()
            // Keep the environment safe: drop any stale Qedit extension registrations left by
            // other/old copies, then make sure macOS lists Qedit in "Open With".
            Task.detached(priority: .background) {
                Diagnostics.cleanupStaleQeditRegistrations()
                Diagnostics.registerWithLaunchServices()
            }
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowsChanged(_:)),
                name: NSWindow.willCloseNotification, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowBecameKey(_:)),
                name: NSWindow.didBecomeKeyNotification, object: nil)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Don't quit on last-window-close when "keep running in background" is on — instead we
    /// drop the Dock icon and live in the menu bar (see `updateActivationPolicy`).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let keep = MainActor.assumeIsolated { AppState.shared.keepRunningInBackground }
        if keep { DispatchQueue.main.async { [weak self] in self?.updateActivationPolicy() } }
        return !keep
    }

    /// Clicking the Dock icon (while it's showing) with no windows reopens the dashboard.
    /// We open it ourselves and return false so AppKit doesn't ALSO run its default reopen,
    /// which would spawn a second, duplicate dashboard window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainActor.assumeIsolated { showMainWindow() }
            return false
        }
        return true
    }

    // MARK: - Background agent ↔ regular app

    @objc private func windowsChanged(_ note: Notification) {
        // willClose fires before the window leaves the list — re-evaluate on the next tick.
        DispatchQueue.main.async { [weak self] in self?.updateActivationPolicy() }
    }

    @objc private func windowBecameKey(_ note: Notification) {
        if isContentWindow(note.object as? NSWindow) {
            NSApp.setActivationPolicy(.regular)
        }
    }

    private func isContentWindow(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return window.isVisible
            && window.contentView != nil
            && !(window is NSPanel)
            && window.styleMask.contains(.titled)
            && window.className != "NSStatusBarWindow"
    }

    private func hasContentWindows() -> Bool {
        NSApp.windows.contains { isContentWindow($0) }
    }

    private func updateActivationPolicy() {
        let keepBackground = MainActor.assumeIsolated { AppState.shared.keepRunningInBackground }
        if hasContentWindows() {
            NSApp.setActivationPolicy(.regular)
        } else if keepBackground {
            // No windows: become a menu-bar background agent (no Dock icon, still running).
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        MainActor.assumeIsolated { EditorLauncher.shared.openMainWindow?() }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "Qedit") {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "Qedit"
        }
        item.button?.toolTip = "Qedit — find & edit any file"

        let menu = NSMenu()
        add(menu, "Open Qedit", #selector(menuOpen))
        add(menu, "Check for Updates…", #selector(menuCheckUpdates))
        add(menu, "Settings…", #selector(menuSettings), key: ",")
        menu.addItem(.separator())
        add(menu, "Quit Qedit", #selector(menuQuit), key: "q")
        item.menu = menu
        statusItem = item
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func menuOpen() { showMainWindow() }
    @objc private func menuQuit() { NSApp.terminate(nil) }
    @objc private func menuCheckUpdates() {
        MainActor.assumeIsolated { UpdaterController.shared.checkForUpdates() }
    }
    @objc private func menuSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        MainActor.assumeIsolated {
            if let openSettings = EditorLauncher.shared.openSettings {
                openSettings()
            } else if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
    }
}
