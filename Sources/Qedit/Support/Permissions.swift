import SwiftUI
import AppKit
import Carbon

enum PermissionState: Equatable {
    case granted, denied, notDetermined, unknown

    var label: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Denied — turn on in Settings"
        case .notDetermined: return "Not granted yet"
        case .unknown: return "Unknown"
        }
    }
    var systemImage: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "circle.dashed"
        case .unknown: return "questionmark.circle"
        }
    }
    var color: Color {
        switch self {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        case .unknown: return .secondary
        }
    }
}

/// Permission checks + requests, surfaced as buttons inside the app.
enum Permissions {
    /// Whether Qedit may control Finder (the global hotkey reads the Finder selection via this).
    /// `prompt: true` shows the macOS consent dialog (call off the main thread — it blocks).
    static func finderAutomation(prompt: Bool) -> PermissionState {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
        guard let desc = target.aeDesc else { return .unknown }
        switch AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, prompt) {
        case noErr: return .granted
        case -1743: return .denied          // errAEEventNotPermitted
        case -1744: return .notDetermined   // errAEEventWouldRequireUserConsent
        default: return .unknown
        }
    }

    static func requestFinderAutomation(_ completion: @escaping (PermissionState) -> Void) {
        DebugLog.shared.log("Requesting Finder Automation permission…")
        DispatchQueue.global().async {
            let state = finderAutomation(prompt: true)
            DebugLog.shared.log("Finder Automation: \(state.label)")
            DispatchQueue.main.async { completion(state) }
        }
    }

    // MARK: - System Settings deep-links

    static func openAutomationSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation", "Privacy → Automation")
    }
    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility", "Privacy → Accessibility")
    }
    static func openFullDiskSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles", "Privacy → Full Disk Access")
    }
    static func openKeyboardSettings() {
        open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension", "Keyboard")
    }
    static func openLoginItemsAndExtensions() {
        open("x-apple.systempreferences:com.apple.LoginItems-Settings.extension", "Login Items & Extensions")
    }

    private static func open(_ string: String, _ name: String) {
        DebugLog.shared.log("Opening System Settings: \(name)")
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
