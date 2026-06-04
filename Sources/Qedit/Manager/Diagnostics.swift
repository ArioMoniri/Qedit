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

/// Quick Look diagnostics: cache reset and the "which extension claims this file" tool.
enum Diagnostics {
    static let qlmanagePath = "/usr/bin/qlmanage"

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
