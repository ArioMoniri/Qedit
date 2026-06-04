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

    @Published var config: HotKeyConfig {
        didSet { save(); HotKeyManager.shared.reregister() }
    }
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "qe.globalHotKeyEnabled")
            HotKeyManager.shared.reregister()
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(HotKeyConfig.self, from: data) {
            config = decoded
        } else {
            config = .default
        }
        enabled = UserDefaults.standard.object(forKey: "qe.globalHotKeyEnabled") as? Bool ?? true
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
