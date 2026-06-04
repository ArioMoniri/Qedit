import Foundation
import Combine

/// A single open file in the editor (Module B).
///
/// Core guarantee: edits are written back **in place, in the original format**. We never
/// rename or convert. A timestamped backup is taken once, before the first write, when enabled.
@MainActor
final class EditorDocument: ObservableObject, Identifiable {
    nonisolated let id: URL
    let url: URL
    let kind: PreviewKind

    @Published var text: String = ""
    @Published var isDirty = false
    @Published var loadError: String?
    @Published var isBinary = false
    @Published var lastSaved: Date?

    /// Whether this document is editable as text in the current (milestone 1) text editor.
    /// PDFs and other binaries are handed to dedicated editors in later milestones.
    var isTextEditable: Bool { !isBinary }

    private var encoding: String.Encoding = .utf8
    private var didBackupThisSession = false

    init(url: URL) {
        self.id = url.standardizedFileURL
        self.url = url
        self.kind = FileTypeClassifier.kind(for: url)
        load()
    }

    // MARK: - Loading

    func load() {
        loadError = nil
        do {
            let data = try Data(contentsOf: url)
            if Self.looksBinary(data) {
                isBinary = true
                text = ""
                return
            }
            isBinary = false

            // Preserve the file's on-disk encoding so we can write it back faithfully.
            var probed: UInt = 0
            if let decoded = try? NSString(contentsOf: url, usedEncoding: &probed) {
                text = decoded as String
                encoding = String.Encoding(rawValue: probed)
            } else if let decoded = String(data: data, encoding: .utf8) {
                text = decoded; encoding = .utf8
            } else if let decoded = String(data: data, encoding: .isoLatin1) {
                text = decoded; encoding = .isoLatin1
            } else {
                text = String(decoding: data, as: UTF8.self); encoding = .utf8
            }
            isDirty = false
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Heuristic: a NUL byte in the first 8 KB means binary (PDF, images, etc.).
    private static func looksBinary(_ data: Data) -> Bool {
        let window = data.prefix(8192)
        return window.contains(0x00)
    }

    // MARK: - Saving

    /// Writes the current text back to the original file, atomically, in the same encoding.
    /// - Parameter makeBackup: if true, copies the original to a timestamped `.bak` once per session.
    func save(makeBackup: Bool) throws {
        guard isTextEditable else { throw EditorError.notTextEditable }

        if makeBackup && !didBackupThisSession {
            try createBackup()
            didBackupThisSession = true
        }

        guard let data = text.data(using: encoding) ?? text.data(using: .utf8) else {
            throw EditorError.encodingFailed
        }
        try data.write(to: url, options: .atomic)
        isDirty = false
        lastSaved = Date()
    }

    private func createBackup() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let stamp = Self.backupFormatter.string(from: Date())
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let backupName = ext.isEmpty ? "\(base).\(stamp).bak" : "\(base).\(stamp).\(ext).bak"
        let backupURL = url.deletingLastPathComponent().appendingPathComponent(backupName)
        if !FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.copyItem(at: url, to: backupURL)
        }
    }

    private static let backupFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

enum EditorError: LocalizedError {
    case notTextEditable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .notTextEditable:
            return "This file isn’t plain text. PDF and other formats open in their dedicated editor."
        case .encodingFailed:
            return "Couldn’t encode the text for saving."
        }
    }
}
