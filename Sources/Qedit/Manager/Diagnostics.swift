import Foundation
import UniformTypeIdentifiers

struct UTIInfo {
    let url: URL
    let identifier: String
    let conformsTo: [String]
    let preferredMIME: String?
    let preferredExtension: String?
    let claimingExtensions: [QLExtensionInfo]
}

/// Quick Look diagnostics for the plugin manager: cache/daemon refresh and the
/// "which extension claims this file" UTI inspector.
enum Diagnostics {
    static let qlmanagePath = "/usr/bin/qlmanage"
    static let killallPath = "/usr/bin/killall"
    static let lsregisterPath =
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    /// Re-register Qedit with LaunchServices so it appears in "Open With" (macOS often
    /// doesn't re-index document types after a Sparkle update until this runs).
    static func registerWithLaunchServices() {
        guard Shell.exists(lsregisterPath) else { return }
        _ = Shell.run(lsregisterPath, ["-f", Bundle.main.bundleURL.path])
    }

    /// Reload Quick Look generators + cache and relaunch Finder so changes take effect now.
    static func refreshFinderAndQuickLook() -> String {
        guard Shell.exists(qlmanagePath) else { return "qlmanage not found." }
        _ = Shell.run(qlmanagePath, ["-r"])
        _ = Shell.run(qlmanagePath, ["-r", "cache"])
        restartQuickLookDaemons()
        if Shell.exists(killallPath) { _ = Shell.run(killallPath, ["Finder"]) }
        return "Reloaded Quick Look, cleared its cache, and relaunched Finder. Press Space on a file to test."
    }

    /// Restart the daemons that actually host/resolve Quick Look **preview extensions**. Enabling
    /// or disabling an extension via `pluginkit` only records the flag — `quicklookd` keeps serving
    /// the previous (cached) resolution of which extension wins a type until it's restarted, which
    /// is why a just-re-enabled extension's preview wouldn't show. launchd relaunches both on demand.
    static func restartQuickLookDaemons() {
        guard Shell.exists(killallPath) else { return }
        _ = Shell.run(killallPath, ["quicklookd"])
        _ = Shell.run(killallPath, ["QuickLookUIService"])
    }

    /// Lighter refresh used right after toggling an extension on/off: reload generators + cache and
    /// restart the Quick Look daemons (so the new enabled state takes effect) — without relaunching
    /// Finder on every click.
    static func reloadQuickLookAfterToggle() -> String {
        guard Shell.exists(qlmanagePath) else { return "qlmanage not found." }
        _ = Shell.run(qlmanagePath, ["-r"])
        _ = Shell.run(qlmanagePath, ["-r", "cache"])
        restartQuickLookDaemons()
        return "Applied. Press Space on a file to test (Finder may need a moment)."
    }

    /// Runs `qlmanage -r` (reload generators) and `qlmanage -r cache` (reset thumbnail cache).
    static func resetQuickLookCache() -> String {
        guard Shell.exists(qlmanagePath) else { return "qlmanage not found." }
        let reload = Shell.run(qlmanagePath, ["-r"])
        let cache = Shell.run(qlmanagePath, ["-r", "cache"])
        let lines = [reload.stderr, reload.stdout, cache.stderr, cache.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? "Quick Look cache reset and generators reloaded." : lines.joined(separator: "\n")
    }

    /// Resolve a file's UTI and figure out which scanned extensions would preview it.
    static func inspect(_ url: URL, among extensions: [QLExtensionInfo]) -> UTIInfo {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: url.pathExtension)
        let conforms = type.map { Array($0.supertypes).map(\.identifier).sorted() } ?? []
        let claimers = type.map { claimingExtensions(for: $0, among: extensions) } ?? []
        return UTIInfo(url: url,
                       identifier: type?.identifier ?? "unknown",
                       conformsTo: conforms,
                       preferredMIME: type?.preferredMIMEType,
                       preferredExtension: type?.preferredFilenameExtension,
                       claimingExtensions: claimers)
    }

    static func claimingExtensions(for type: UTType, among extensions: [QLExtensionInfo]) -> [QLExtensionInfo] {
        extensions.filter { ext in
            ext.supportedUTIs.contains { supported in
                if supported == type.identifier { return true }
                if let supportedType = UTType(supported) { return type.conforms(to: supportedType) }
                return false
            }
        }
    }
}
