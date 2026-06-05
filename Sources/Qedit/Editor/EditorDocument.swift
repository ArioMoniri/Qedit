import Foundation
import Combine
import AppKit

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
    /// True for rich documents (Word, RTF, ODT…) we can READ for find but won't rewrite,
    /// because re-serializing would risk changing their formatting/format.
    @Published var isReadOnly = false
    /// Friendly name for a rich/read-only document ("Word document", "Rich text"…).
    @Published var richFormatName: String?

    /// Whether this document is editable as text in the current (milestone 1) text editor.
    /// PDFs and other binaries are handed to dedicated editors in later milestones.
    var isTextEditable: Bool { !isBinary && !isReadOnly }

    /// Label shown in the editor subtitle.
    var kindLabel: String { richFormatName ?? kind.displayName }

    /// Word / RTF / OpenDocument files AppKit can read into text via NSAttributedString.
    private static let richTextExtensions: Set<String> = [
        "docx", "doc", "rtf", "rtfd", "odt", "wordml", "webarchive"
    ]

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

        // Rich documents (Word, RTF, ODT…): extract text for reading + ⌘F find, read-only.
        if Self.richTextExtensions.contains(url.pathExtension.lowercased()) {
            loadRichDocument()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            if Self.looksBinary(data) {
                isBinary = true
                isReadOnly = false
                text = ""
                return
            }
            isBinary = false
            isReadOnly = false

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

    /// Read a Word/RTF/ODT file's text via AppKit so the user can read it and ⌘F-find.
    /// Read-only: Qedit won't re-serialize Word formatting (that could change the file).
    private func loadRichDocument() {
        let ext = url.pathExtension.lowercased()
        richFormatName = Self.richName(for: ext)
        isReadOnly = true
        do {
            let attributed = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
            text = attributed.string
            isBinary = false
            isDirty = false
        } catch {
            // Couldn't decode it as a rich document — treat as an opaque binary.
            isBinary = true
            text = ""
        }
    }

    private static func richName(for ext: String) -> String {
        switch ext {
        case "docx", "doc", "wordml": return "Word document"
        case "rtf", "rtfd": return "Rich text"
        case "odt": return "OpenDocument text"
        case "webarchive": return "Web archive"
        default: return "Document"
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
            try FileBackup.make(for: url)
            didBackupThisSession = true
        }

        guard let data = text.data(using: encoding) ?? text.data(using: .utf8) else {
            throw EditorError.encodingFailed
        }
        try data.write(to: url, options: .atomic)
        isDirty = false
        lastSaved = Date()
    }
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
