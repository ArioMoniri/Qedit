import Foundation

/// One installed Quick Look preview extension, as reported by `pluginkit`.
struct QLExtensionInfo: Identifiable {
    enum Status {
        case enabled, disabled, notEnabled
        var label: String {
            switch self {
            case .enabled: return "Enabled"
            case .disabled: return "Disabled"
            case .notEnabled: return "Not enabled"
            }
        }
        var systemImage: String {
            switch self {
            case .enabled: return "checkmark.circle.fill"
            case .disabled: return "xmark.circle.fill"
            case .notEnabled: return "circle.dashed"
            }
        }
    }

    let id = UUID()
    var identifier: String
    var version: String
    var status: Status
    var path: String?
    var displayName: String?
    var parentName: String?
    var parentBundlePath: String?
    var supportedUTIs: [String] = []

    /// Sibling apps by the same author that are meant to run ALONGSIDE the user's setup (e.g.
    /// ChangeX) — never swept up by "Disable all".
    var isKnownSibling: Bool { identifier.hasPrefix("dev.changex.") }
}

/// Parses `pluginkit -mAvvv -p com.apple.quicklook.preview` and enriches each entry with
/// the `QLSupportedContentTypes` read from the extension's own Info.plist.
enum PluginKitScanner {
    static let pluginkitPath = "/usr/bin/pluginkit"

    static func scanQuickLookPreviewExtensions() -> [QLExtensionInfo] {
        guard Shell.exists(pluginkitPath) else { return [] }
        let result = Shell.run(pluginkitPath, ["-mAvvv", "-p", "com.apple.quicklook.preview"])
        var extensions = parse(result.stdout)
        for index in extensions.indices {
            if let path = extensions[index].path {
                extensions[index].supportedUTIs = supportedUTIs(appexPath: path)
            }
        }
        return extensions.sorted {
            ($0.displayName ?? $0.identifier).localizedCaseInsensitiveCompare($1.displayName ?? $1.identifier) == .orderedAscending
        }
    }

    static func parse(_ output: String) -> [QLExtensionInfo] {
        var results: [QLExtensionInfo] = []
        var current: QLExtensionInfo?

        func flush() { if let current { results.append(current) }; current = nil }

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix("\t") || line.first == " " && line.contains(" = ") {
                // Detail line: "<tab/spaces>Key = Value"
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard let range = trimmed.range(of: " = ") else { continue }
                let key = String(trimmed[..<range.lowerBound])
                let value = String(trimmed[range.upperBound...])
                switch key {
                case "Path": current?.path = value
                case "Display Name": current?.displayName = value
                case "Parent Name": current?.parentName = value
                case "Parent Bundle": current?.parentBundlePath = value
                default: break
                }
            } else if let header = parseHeader(line) {
                flush()
                current = header
            }
        }
        flush()
        return results
    }

    private static func parseHeader(_ line: String) -> QLExtensionInfo? {
        guard !line.isEmpty else { return nil }
        let statusChar = line.first
        let status: QLExtensionInfo.Status
        switch statusChar {
        case "+": status = .enabled
        case "-": status = .disabled
        default: status = .notEnabled
        }
        let body = line.drop { "+-?! ".contains($0) }
        guard let open = body.lastIndex(of: "("), body.hasSuffix(")") else { return nil }
        let identifier = String(body[..<open]).trimmingCharacters(in: .whitespaces)
        let version = String(body[body.index(after: open)..<body.index(before: body.endIndex)])
        guard !identifier.isEmpty, identifier.contains(".") else { return nil }
        return QLExtensionInfo(identifier: identifier, version: version, status: status)
    }

    /// Enable (`use`) or disable (`ignore`) an extension via pluginkit. Returns true on success.
    /// macOS may still require a one-time approval in System Settings for first activation.
    static func setEnabled(_ enabled: Bool, identifier: String) -> Bool {
        guard Shell.exists(pluginkitPath) else { return false }
        let action = enabled ? "use" : "ignore"
        return Shell.run(pluginkitPath, ["-e", action, "-i", identifier]).succeeded
    }

    /// All registrations for a single bundle id (there can be more than one — that's the bug).
    static func registrations(of identifier: String) -> [QLExtensionInfo] {
        guard Shell.exists(pluginkitPath) else { return [] }
        var found = parse(Shell.run(pluginkitPath, ["-mAvvv", "-i", identifier]).stdout)
        for index in found.indices {
            if let path = found[index].path {
                found[index].supportedUTIs = supportedUTIs(appexPath: path)
            }
        }
        return found
    }

    /// Unregister a plugin at a specific path (used to clear stale duplicate registrations).
    static func removeRegistration(appexPath: String) -> Bool {
        guard Shell.exists(pluginkitPath) else { return false }
        return Shell.run(pluginkitPath, ["-r", appexPath]).succeeded
    }

    static func supportedUTIs(appexPath: String) -> [String] {
        let plistURL = URL(fileURLWithPath: appexPath).appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let ext = dict["NSExtension"] as? [String: Any],
              let attrs = ext["NSExtensionAttributes"] as? [String: Any],
              let types = attrs["QLSupportedContentTypes"] as? [String] else { return [] }
        return types
    }
}

/// Backing model for the Extension Manager view.
@MainActor
final class ExtensionManagerModel: ObservableObject {
    @Published var extensions: [QLExtensionInfo] = []
    @Published var isScanning = false
    @Published var lastDiagnostic: String?

    func scan() async {
        isScanning = true
        let found = await Task.detached { PluginKitScanner.scanQuickLookPreviewExtensions() }.value
        extensions = found
        isScanning = false
    }

    func resetQuickLookCache() async {
        isScanning = true
        let result = await Task.detached { Diagnostics.resetQuickLookCache() }.value
        lastDiagnostic = result
        isScanning = false
    }

    /// Reload Quick Look + restart its daemons + relaunch Finder so a just-changed extension
    /// state takes effect immediately.
    func refreshFinderAndQuickLook() async {
        isScanning = true
        let result = await Task.detached { Diagnostics.refreshFinderAndQuickLook() }.value
        lastDiagnostic = result
        await scan()
    }

    func setEnabled(_ enabled: Bool, for ext: QLExtensionInfo) async {
        let id = ext.identifier
        let name = ext.displayName ?? id
        isScanning = true
        // Flip the flag, then restart the Quick Look daemons so the change actually takes effect.
        _ = await Task.detached { () -> Bool in
            let ok = PluginKitScanner.setEnabled(enabled, identifier: id)
            _ = Diagnostics.reloadQuickLookAfterToggle()
            return ok
        }.value
        await scan()

        // Verify it actually took — pluginkit can report success while macOS keeps the user's own
        // System Settings choice, which no app can override.
        let nowEnabled = extensions.first { $0.identifier == id }?.status == .enabled
        if enabled && !nowEnabled {
            lastDiagnostic = "macOS didn’t turn “\(name)” back on — it was likely disabled in System "
                + "Settings, and only you can re-enable it there: System Settings → General → Login "
                + "Items & Extensions → Quick Look. (No app can flip that switch for you.)"
        } else if enabled && nowEnabled {
            lastDiagnostic = "“\(name)” is on. If its Space preview still doesn’t show, another enabled "
                + "extension may claim the same type (macOS shows one per type), or give Finder a moment."
        } else {
            lastDiagnostic = nil
        }
    }

    func setAllEnabled(_ enabled: Bool) async {
        // Never bulk-DISABLE a known sibling (ChangeX) — it's meant to run alongside Qedit.
        let ids = extensions.filter { enabled || !$0.isKnownSibling }.map(\.identifier)
        isScanning = true
        await Task.detached {
            for id in ids { _ = PluginKitScanner.setEnabled(enabled, identifier: id) }
            _ = Diagnostics.reloadQuickLookAfterToggle()
        }.value
        await scan()
    }
}
