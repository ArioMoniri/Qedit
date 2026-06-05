import Foundation

/// User-configurable rendering options for Qedit's Markdown / code preview.
///
/// Shared between the (non-sandboxed) host app, which WRITES them from Settings, and the
/// (sandboxed) Quick Look extension, which READS them at render time — via a JSON file in the
/// shared App Group container. If the container is unavailable, both sides fall back to the
/// defaults, so the preview never breaks.
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

    static let appGroupID = "group.com.ariomoniri.Qedit"
    static let fileName = "render-prefs.json"

    /// The shared JSON file in the App Group container (nil if the entitlement isn't active).
    static var containerFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    /// Read shared prefs, falling back to defaults when the container/file is unavailable.
    static func load() -> RenderPrefs {
        guard let url = containerFileURL,
              let data = try? Data(contentsOf: url),
              let prefs = try? JSONDecoder().decode(RenderPrefs.self, from: data)
        else { return RenderPrefs() }
        return prefs
    }

    /// Persist to the shared container. Returns true on success.
    @discardableResult
    func save() -> Bool {
        guard let url = Self.containerFileURL,
              let data = try? JSONEncoder().encode(self) else { return false }
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
