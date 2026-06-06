import Foundation

/// User-configurable rendering options for Qedit's Markdown / code preview.
///
/// Shared between the (non-sandboxed) host app, which WRITES them from Settings, and the
/// (sandboxed) Quick Look extension, which READS them at render time.
///
/// We avoid App Groups (they'd force a provisioning profile, which the Developer-ID CI build
/// has none of). Instead, because the host app is unsandboxed, it writes the JSON straight into
/// the Quick Look extension's own sandbox **container**; the extension then reads it as a file
/// in its own home. Same physical file, no entitlement needed. Missing file → defaults.
struct RenderPrefs: Codable, Equatable {
    enum Theme: String, Codable, CaseIterable, Identifiable {
        case auto, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .auto: return "Auto"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    /// Preview color theme (GitHub light/dark CSS). `auto` follows the system appearance.
    var theme: Theme = .auto
    /// GitHub-Flavored Markdown: tables, task lists, strikethrough, autolinks.
    var gfm: Bool = true
    /// Treat single newlines as line breaks (`<br>`).
    var hardBreaks: Bool = false
    /// Syntax-highlight fenced code blocks (highlight.js).
    var syntaxHighlighting: Bool = true
    /// Add clickable anchor links to headings.
    var headingAnchors: Bool = false
    /// Render LaTeX math ($…$ / $$…$$) via KaTeX (MathML output — no fonts needed).
    var math: Bool = false
    /// Replace :shortcode: with emoji.
    var emoji: Bool = false
    /// Curly quotes / dashes (typographic).
    var smartQuotes: Bool = false

    /// Bundle id of the Quick Look extension, whose container holds the shared prefs file.
    private static let quickLookBundleID = "com.ariomoniri.Qedit.QuickLook"
    /// Path of the prefs file relative to the Quick Look extension's container `Data` root.
    private static let relativePath = "Library/Application Support/Qedit/render-prefs.json"

    /// The prefs file inside the Quick Look extension's sandbox container.
    /// - In the extension, `NSHomeDirectory()` already IS that container.
    /// - In the (unsandboxed) host app, we reach the same place under `~/Library/Containers/…`.
    static var fileURL: URL {
        let home = NSHomeDirectory()
        if Bundle.main.bundleIdentifier == quickLookBundleID {
            return URL(fileURLWithPath: home).appendingPathComponent(relativePath)
        }
        return URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Containers/\(quickLookBundleID)/Data")
            .appendingPathComponent(relativePath)
    }

    /// Read shared prefs, falling back to defaults when the file is missing/unreadable.
    static func load() -> RenderPrefs {
        guard let data = try? Data(contentsOf: fileURL),
              let prefs = try? JSONDecoder().decode(RenderPrefs.self, from: data)
        else { return RenderPrefs() }
        return prefs
    }

    /// Persist to the Quick Look extension's container. Returns true on success.
    @discardableResult
    func save() -> Bool {
        let url = Self.fileURL
        guard let data = try? JSONEncoder().encode(self) else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
