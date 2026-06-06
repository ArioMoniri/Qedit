import SwiftUI
import AppKit

/// The concrete colors the highlighter applies.
struct SyntaxColors {
    var keyword: NSColor
    var string: NSColor
    var number: NSColor
    var comment: NSColor
    var change: NSColor   // live change-highlight mark

    static let system = SyntaxColors(keyword: .systemPink, string: .systemRed,
                                     number: .systemBlue, comment: .systemGreen,
                                     change: .systemYellow)
}

/// User-customizable code/diff colors, persisted as hex in UserDefaults. SwiftUI `Color` for the
/// pickers; `nsColors` feeds `SyntaxHighlighter`.
@MainActor
final class SyntaxThemeStore: ObservableObject {
    static let shared = SyntaxThemeStore()

    /// Off by default → the editor uses the dynamic system colors (which adapt to light/dark).
    /// Custom colors are static, so they only apply when the user opts in.
    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: Self.prefix + "enabled") } }
    @Published var keyword: Color { didSet { save("kw", keyword) } }
    @Published var string: Color { didSet { save("str", string) } }
    @Published var number: Color { didSet { save("num", number) } }
    @Published var comment: Color { didSet { save("cmt", comment) } }
    @Published var change: Color { didSet { save("chg", change) } }

    private static let prefix = "qe.syntax."

    init() {
        enabled = UserDefaults.standard.object(forKey: Self.prefix + "enabled") as? Bool ?? false
        keyword = Self.load("kw", fallback: "#D6336C")
        string = Self.load("str", fallback: "#C92A2A")
        number = Self.load("num", fallback: "#1971C2")
        comment = Self.load("cmt", fallback: "#2F9E44")
        change = Self.load("chg", fallback: "#F2C037")
    }

    /// The colors to use right now: custom (if opted in) else the dynamic system palette.
    var activeColors: SyntaxColors {
        guard enabled else { return .system }
        return SyntaxColors(keyword: NSColor(keyword), string: NSColor(string),
                            number: NSColor(number), comment: NSColor(comment),
                            change: NSColor(change))
    }

    /// Built-in presets.
    enum Preset: String, CaseIterable, Identifiable {
        case classic, github, solarized
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var colors: (kw: String, str: String, num: String, cmt: String, chg: String) {
            switch self {
            case .classic:   return ("#D6336C", "#C92A2A", "#1971C2", "#2F9E44", "#F2C037")
            case .github:    return ("#CF222E", "#0A3069", "#0550AE", "#6E7781", "#FFF8C5")
            case .solarized: return ("#859900", "#2AA198", "#D33682", "#93A1A1", "#B58900")
            }
        }
    }

    func apply(_ preset: Preset) {
        let c = preset.colors
        keyword = Color(hex: c.kw); string = Color(hex: c.str)
        number = Color(hex: c.num); comment = Color(hex: c.cmt); change = Color(hex: c.chg)
    }

    private func save(_ key: String, _ color: Color) {
        UserDefaults.standard.set(color.hexString, forKey: Self.prefix + key)
    }
    private static func load(_ key: String, fallback: String) -> Color {
        Color(hex: UserDefaults.standard.string(forKey: prefix + key) ?? fallback)
    }
}

extension Color {
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self = Color(.sRGB,
                     red: Double((rgb >> 16) & 0xff) / 255,
                     green: Double((rgb >> 8) & 0xff) / 255,
                     blue: Double(rgb & 0xff) / 255)
    }
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02X%02X%02X",
                      Int(round(ns.redComponent * 255)),
                      Int(round(ns.greenComponent * 255)),
                      Int(round(ns.blueComponent * 255)))
    }
}
