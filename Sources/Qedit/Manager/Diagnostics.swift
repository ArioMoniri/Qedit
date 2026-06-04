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

/// Health of Qedit's own Quick Look preview extension.
struct QeditPreviewStatus {
    var registrations: [QLExtensionInfo]
    var runningExtensionPath: String?
    var duplicatePaths: [String]
    var isEnabledSomewhere: Bool
    var report: String

    var hasDuplicates: Bool { !duplicatePaths.isEmpty }
    var isHealthy: Bool { isEnabledSomewhere && !hasDuplicates && registrations.count == 1 }
}

/// Quick Look diagnostics: cache reset, the "which extension claims this file" tool, and
/// self-troubleshooting for Qedit's own preview extension.
enum Diagnostics {
    static let qlmanagePath = "/usr/bin/qlmanage"
    static let killallPath = "/usr/bin/killall"
    static let qeditQuickLookID = "com.ariomoniri.Qedit.QuickLook"

    /// Path of *this* running app's bundled QL extension (the registration we want to keep).
    static func runningExtensionPath() -> String? {
        Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("QeditQuickLook.appex").standardizedFileURL.path
    }

    private static func canonical(_ path: String?) -> String? {
        path.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
    }

    /// Inspect every registration of Qedit's preview extension and explain what's wrong.
    static func qeditPreviewStatus() -> QeditPreviewStatus {
        let regs = PluginKitScanner.registrations(of: qeditQuickLookID)
        let running = canonical(runningExtensionPath())
        let duplicates = regs.compactMap { canonical($0.path) }
            .filter { running == nil || $0 != running }
        let enabled = regs.contains { $0.status == .enabled }

        var lines: [String] = []
        lines.append("Extension: \(qeditQuickLookID)")
        lines.append("Registrations: \(regs.count)")
        for reg in regs {
            let isThis = canonical(reg.path) == running
            lines.append("  • [\(reg.status.label)] v\(reg.version)\(isThis ? "  ← this app" : "")")
            lines.append("    \(reg.path ?? "unknown path")")
            lines.append("    declared types: \(reg.supportedUTIs.count)")
        }
        lines.append("")
        if regs.isEmpty {
            lines.append("❌ macOS hasn’t registered the extension. Make sure Qedit is in /Applications and launch it once.")
        } else if duplicates.count > 0 {
            lines.append("⚠️ \(duplicates.count) duplicate registration(s) of the SAME extension exist (e.g. a build folder + /Applications). macOS can’t choose between them, so previews silently do nothing. Remove the stale one(s), then refresh Finder.")
        } else if !enabled {
            lines.append("⚠️ The extension is registered but not enabled. Click Enable, then refresh Finder.")
        } else {
            lines.append("✅ Looks healthy: one enabled registration. If a preview still doesn’t show, refresh Finder & Quick Look.")
        }

        return QeditPreviewStatus(registrations: regs,
                                  runningExtensionPath: running,
                                  duplicatePaths: duplicates,
                                  isEnabledSomewhere: enabled,
                                  report: lines.joined(separator: "\n"))
    }

    /// Reload Quick Look generators + cache and relaunch Finder so changes take effect now.
    static func refreshFinderAndQuickLook() -> String {
        guard Shell.exists(qlmanagePath) else { return "qlmanage not found." }
        _ = Shell.run(qlmanagePath, ["-r"])
        _ = Shell.run(qlmanagePath, ["-r", "cache"])
        if Shell.exists(killallPath) {
            _ = Shell.run(killallPath, ["Finder"])
            _ = Shell.run(killallPath, ["QuickLookUIService"])
        }
        return "Reloaded Quick Look, cleared its cache, and relaunched Finder. Press Space on a file to test."
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
