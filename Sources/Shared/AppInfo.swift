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
