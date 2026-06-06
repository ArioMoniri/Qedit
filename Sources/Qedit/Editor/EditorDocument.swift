import Foundation
import Combine
import AppKit

/// A single open file in the editor (Module B).
///
/// Core guarantee: edits are written back **in place, in the original format**. We never
/// rename or convert. Rich formats (RTF/RTFD/ODT) round-trip losslessly through
/// NSAttributedString, so they're editable in native form; Word (DOCX/DOC) renders natively
/// but stays read-only because re-serializing it can drop tables/images/styles.
@MainActor
final class EditorDocument: ObservableObject, Identifiable {
    nonisolated let id: URL
    let url: URL
    let kind: PreviewKind

    /// Plain-text content (used by the code/text editor).
    @Published var text: String = ""
    /// The text as it was on disk when opened/last saved — used to highlight what changed.
    @Published private(set) var originalText: String = ""
    /// Native rich content (used by the rich editor for RTF/Word/ODT…).
    @Published var attributedText = NSAttributedString(string: "")
    @Published var isDirty = false
    @Published var loadError: String?
    @Published var isBinary = false
    @Published var lastSaved: Date?
    /// True when this document is shown with the rich (native-formatted) editor.
    @Published var isRich = false
    /// True when the document is view-only (Word/web archive — lossy to rewrite).
    @Published var isReadOnly = false
    /// Friendly name for a rich document ("Word document", "Rich text"…).
    @Published var richFormatName: String?

    /// Editable as text/rich in the editor (not a view-only rich doc, not opaque binary).
    var isTextEditable: Bool { !isBinary && !isReadOnly }

    /// Label shown in the editor subtitle.
    var kindLabel: String { richFormatName ?? kind.displayName }

    /// Rich formats that round-trip losslessly → editable in native form.
    private static let richEditableExtensions: Set<String> = ["rtf", "rtfd", "odt"]
    /// Rich formats we render natively but won't rewrite (re-serialize is lossy).
    private static let richReadOnlyExtensions: Set<String> = ["docx", "doc", "wordml", "webarchive"]

    private var encoding: String.Encoding = .utf8
    private var richDocType: NSAttributedString.DocumentType?
    private var didBackupThisSession = false
    private var autoSaveWork: DispatchWorkItem?

    init(url: URL) {
        self.id = url.standardizedFileURL
        self.url = url
        self.kind = FileTypeClassifier.kind(for: url)
        load()
    }

    // MARK: - Loading

    func load() {
        loadError = nil
        let ext = url.pathExtension.lowercased()
        if Self.richEditableExtensions.contains(ext) {
            loadRich(ext: ext, editable: true)
        } else if Self.richReadOnlyExtensions.contains(ext) {
            // Word is read-only unless the user opts into editing (it can simplify formatting).
            let wordEditable = (ext == "docx" || ext == "doc") && AppState.shared.allowWordEditing
            loadRich(ext: ext, editable: wordEditable)
        } else {
            loadPlainText()
        }
        originalText = text   // snapshot for change-highlighting
    }

    /// Schedule an auto-save (debounced) if the user has auto-save on. Call after each edit.
    func scheduleAutoSave() {
        guard AppState.shared.autoSave, isTextEditable, isDirty else { return }
        autoSaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isDirty else { return }
            try? self.save(makeBackup: AppState.shared.makeBackupBeforeFirstWrite)
        }
        autoSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func loadPlainText() {
        do {
            let data = try Data(contentsOf: url)

            // Probe a real text encoding FIRST. UTF-16/UTF-32 text contains a NUL byte per
            // ASCII character, so the NUL "looks binary" heuristic must NOT run before we've
            // tried to decode the bytes as text — otherwise UTF-16 .md/.json/.csv "can't open".
            var probed: UInt = 0
            if let decoded = try? NSString(contentsOf: url, usedEncoding: &probed) {
                text = decoded as String
                encoding = String.Encoding(rawValue: probed)
                isBinary = false; isRich = false; isReadOnly = false; isDirty = false
                return
            }
            // No text encoding decoded it. A NUL byte now means it's genuinely binary.
            if Self.looksBinary(data) {
                isBinary = true; isRich = false; isReadOnly = false; text = ""
                return
            }
            if let decoded = String(data: data, encoding: .utf8) {
                text = decoded; encoding = .utf8
            } else if let decoded = String(data: data, encoding: .isoLatin1) {
                text = decoded; encoding = .isoLatin1
            } else {
                text = String(decoding: data, as: UTF8.self); encoding = .utf8
            }
            isBinary = false; isRich = false; isReadOnly = false; isDirty = false
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Read a rich document into native attributed text. Editable formats can be saved back
    /// losslessly; read-only ones (Word) are rendered for viewing + ⌘F find only.
    private func loadRich(ext: String, editable: Bool) {
        richFormatName = Self.richName(for: ext)
        richDocType = Self.docType(for: ext)
        do {
            let attr = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
            attributedText = attr
            text = attr.string
            isRich = true
            isReadOnly = !editable
            isBinary = false
            isDirty = false
        } catch {
            // Couldn't parse it — fall back to the binary notice.
            isRich = false; isReadOnly = true; isBinary = true; text = ""
        }
    }

    private static func richName(for ext: String) -> String {
        switch ext {
        case "docx", "doc", "wordml": return "Word document"
        case "rtf": return "Rich text"
        case "rtfd": return "Rich text"
        case "odt": return "OpenDocument text"
        case "webarchive": return "Web archive"
        default: return "Document"
        }
    }

    private static func docType(for ext: String) -> NSAttributedString.DocumentType? {
        switch ext {
        case "rtf": return .rtf
        case "rtfd": return .rtfd
        case "odt": return .openDocument
        case "docx": return .officeOpenXML
        case "doc": return .docFormat
        case "wordml": return .wordML
        case "webarchive": return .webArchive
        default: return nil
        }
    }

    /// Heuristic of last resort: a NUL byte means binary (PDF, images, etc.). Only consulted
    /// AFTER every text-encoding probe fails, so UTF-16/UTF-32 text is never misclassified.
    private static func looksBinary(_ data: Data) -> Bool {
        data.prefix(8192).contains(0x00)
    }

    // MARK: - Saving

    /// Writes the current content back to the original file, atomically, in the same format.
    /// - Parameter makeBackup: if true, copies the original to a timestamped `.bak` once per session.
    func save(makeBackup: Bool) throws {
        guard isTextEditable else { throw EditorError.notTextEditable }

        // Word re-serialization is lossy (it can simplify tables/images/headers), and Word is now
        // editable by default — so ALWAYS keep one safety copy on the first write of a session for
        // Word, regardless of the global backup setting. This also covers the auto-save path, which
        // calls straight through here. Other formats follow the user's global preference.
        let forceBackup = (richFormatName == "Word document")
        if (makeBackup || forceBackup) && !didBackupThisSession {
            try FileBackup.make(for: url)
            didBackupThisSession = true
        }

        if isRich {
            try saveRich()
        } else {
            guard let data = text.data(using: encoding) ?? text.data(using: .utf8) else {
                throw EditorError.encodingFailed
            }
            try data.write(to: url, options: .atomic)
        }
        isDirty = false
        lastSaved = Date()
        originalText = text   // changes are now the baseline — clear change highlights
    }

    /// Save the attributed text back in the original rich format. RTFD is a file package, so it
    /// goes through an NSFileWrapper; RTF/ODT are flat data.
    private func saveRich() throws {
        guard let docType = richDocType else { throw EditorError.notTextEditable }
        let range = NSRange(location: 0, length: attributedText.length)
        if docType == .rtfd {
            let wrapper = try attributedText.fileWrapper(
                from: range, documentAttributes: [.documentType: docType])
            try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
        } else {
            let data = try attributedText.data(
                from: range, documentAttributes: [.documentType: docType])
            try data.write(to: url, options: .atomic)
        }
    }
}

enum EditorError: LocalizedError {
    case notTextEditable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .notTextEditable:
            return "This file can’t be edited as text. PDFs open in the PDF editor; Word documents are read-only."
        case .encodingFailed:
            return "Couldn’t encode the text for saving."
        }
    }
}
