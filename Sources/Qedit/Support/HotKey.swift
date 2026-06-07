import Foundation
import AppKit
import Carbon.HIToolbox

/// A global hotkey combination expressed in Carbon terms (so it can feed RegisterEventHotKey).
struct HotKeyConfig: Equatable, Codable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var keyLabel: String   // e.g. "E", "Space", "F2" — what the recorder captured

    /// Default: ⌥⌘E.
    static let `default` = HotKeyConfig(
        keyCode: UInt32(kVK_ANSI_E),
        carbonModifiers: UInt32(optionKey | cmdKey),
        keyLabel: "E"
    )

    /// Default Browser hotkey: ⌥⌘B (⇧⌘B collides with some system/app shortcuts).
    static let defaultBrowser = HotKeyConfig(
        keyCode: UInt32(kVK_ANSI_B),
        carbonModifiers: UInt32(optionKey | cmdKey),
        keyLabel: "B"
    )

    /// One-tap presets shown in Settings. (Space needs a modifier — a bare Space can't be a
    /// global hotkey without blocking typing — so the "Space" presets pair it with ⌃/⌥/⌘.)
    static let presets: [HotKeyConfig] = [
        .default,
        HotKeyConfig(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(controlKey), keyLabel: "Space"),
        HotKeyConfig(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(optionKey), keyLabel: "Space"),
        HotKeyConfig(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(controlKey | cmdKey), keyLabel: "Space"),
        HotKeyConfig(keyCode: UInt32(kVK_ANSI_E), carbonModifiers: UInt32(cmdKey), keyLabel: "E"),
    ]

    var displayString: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s + keyLabel
    }

    var hasModifier: Bool { carbonModifiers != 0 }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        return m
    }
}

/// Persists the hotkey config in UserDefaults.
@MainActor
final class HotKeyStore: ObservableObject {
    static let shared = HotKeyStore()
    private static let key = "qe.globalHotKey"
    private static let browserKey = "qe.browserHotKey"

    @Published var config: HotKeyConfig {
        didSet { save(config, Self.key); HotKeyManager.shared.reregister() }
    }
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "qe.globalHotKeyEnabled")
            HotKeyManager.shared.reregister()
        }
    }
    /// Configurable global shortcut to open the Browser window.
    @Published var browserConfig: HotKeyConfig {
        didSet { save(browserConfig, Self.browserKey); HotKeyManager.shared.reregister() }
    }
    @Published var browserEnabled: Bool {
        didSet {
            UserDefaults.standard.set(browserEnabled, forKey: "qe.browserHotKeyEnabled")
            HotKeyManager.shared.reregister()
        }
    }

    init() {
        config = Self.decode(Self.key) ?? .default
        enabled = UserDefaults.standard.object(forKey: "qe.globalHotKeyEnabled") as? Bool ?? true
        browserConfig = Self.decode(Self.browserKey) ?? .defaultBrowser
        browserEnabled = UserDefaults.standard.object(forKey: "qe.browserHotKeyEnabled") as? Bool ?? true
    }

    private static func decode(_ key: String) -> HotKeyConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotKeyConfig.self, from: data)
    }

    private func save(_ config: HotKeyConfig, _ key: String) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
