import Foundation

/// Timestamped, in-place-safe backups. Editing real files is destructive, so both the
/// text and PDF editors copy the original to a sibling `.bak` once, before the first write.
enum FileBackup {
    /// Copies `url` to `name.yyyyMMdd-HHmmss.ext.bak` next to it. Returns the backup URL
    /// if one was made (no-op if the file is missing or that backup already exists).
    @discardableResult
    static func make(for url: URL) throws -> URL? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let stamp = formatter.string(from: Date())
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let name = ext.isEmpty ? "\(base).\(stamp).bak" : "\(base).\(stamp).\(ext).bak"
        let dest = url.deletingLastPathComponent().appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: dest.path) else { return nil }
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
