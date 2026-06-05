import Foundation

/// Constants shared across the host app and both app extensions.
enum AppInfo {
    /// Custom URL scheme the Quick Action / global hotkey use to hand a file to the editor.
    /// Format: `qedit://open?path=<percent-encoded-absolute-path>`
    static let urlScheme = "qedit"
    static let openHost = "open"

    static let hostBundleIdentifier = "com.ariomoniri.Qedit"
    static let quickLookBundleIdentifier = "com.ariomoniri.Qedit.QuickLook"
    static let quickActionBundleIdentifier = "com.ariomoniri.Qedit.QuickAction"

    /// Upper bound on bytes rendered in a Quick Look preview. Larger files are read up to
    /// this cap and visibly marked as truncated, so previews stay fast and memory-safe.
    static let maxPreviewBytes = 5 * 1024 * 1024

    /// Build a `qedit://open` URL for an absolute file path.
    static func openURL(forPath path: String) -> URL? {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = openHost
        components.queryItems = [URLQueryItem(name: "path", value: path)]
        return components.url
    }

    /// Extract the file path from a `qedit://open?path=...` URL, if present.
    static func path(fromOpenURL url: URL) -> String? {
        guard url.scheme == urlScheme else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "path" })?.value
    }
}

/// One place to describe what Qedit supports, so every screen says the same thing.
enum SupportedFormats {
    /// Types the Quick Look preview renders richly (non-system UTIs).
    static let preview = "Markdown (.md, .markdown, .textbundle), source code in 30+ languages "
        + "(Swift, Python, JavaScript/TypeScript, Go, Rust, C/C++, Objective-C, Java, Kotlin, "
        + "Ruby, PHP, shell, SQL, R, Swift, …), logs (.log), and config (JSON, YAML, XML, TOML, "
        + "INI, .properties, .plist)."

    /// Types the editor can open and save back in place.
    static let edit = "PDF — find, highlight, notes, text boxes, signature, and page ops — plus "
        + "every text, source-code, Markdown, log and config type Qedit previews. PDFs save via "
        + "PDFKit; text saves in its original encoding; nothing ever changes format. Word (.docx, "
        + ".doc), RTF and OpenDocument (.odt) open read-only for reading and find."

    /// Short inline list.
    static let short = "PDF, Markdown, source code, logs, JSON / YAML / XML / TOML, and plain text"
}
