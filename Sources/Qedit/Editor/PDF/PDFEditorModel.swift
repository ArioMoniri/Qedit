import SwiftUI
import PDFKit

enum PDFTool: String, CaseIterable, Identifiable {
    case select, highlight, note, text, signature
    var id: String { rawValue }
    var label: String {
        switch self {
        case .select: return "Select"
        case .highlight: return "Highlight"
        case .note: return "Note"
        case .text: return "Text Box"
        case .signature: return "Place Signature"
        }
    }
    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .highlight: return "highlighter"
        case .note: return "note.text"
        case .text: return "textbox"
        case .signature: return "signature"
        }
    }
    /// Tools shown as toggle buttons in the toolbar (signature is driven by its own sheet).
    static var pickable: [PDFTool] { [.select, .highlight, .note, .text] }
}

enum PDFEditError: LocalizedError {
    case notLoaded, writeFailed
    var errorDescription: String? {
        switch self {
        case .notLoaded: return "The PDF isn’t loaded."
        case .writeFailed: return "Couldn’t write the PDF back to disk."
        }
    }
}

/// Drives the PDFKit editor (Module B for PDFs). Find/search, annotation state, page
/// operations, copy-as-text, and save-in-place with a one-time backup.
@MainActor
final class PDFEditorModel: ObservableObject {
    let url: URL

    @Published var document: PDFDocument?
    @Published var loadError: String?
    @Published var isDirty = false
    @Published var lastSaved: Date?

    @Published var tool: PDFTool = .select
    @Published var inkColor: Color = .yellow

    /// A signature drawn in the signature sheet, awaiting a click to place it on a page.
    @Published var pendingSignature: NSBezierPath?

    @Published var searchText = ""
    @Published var matches: [PDFSelection] = []
    @Published var currentMatchIndex = 0

    /// The model owns the view so the editor and the thumbnail sidebar share one
    /// reliably-configured instance, regardless of representable creation order.
    let pdfView = AnnotatingPDFView()

    private var didBackup = false

    init(url: URL) {
        self.url = url
        pdfView.model = self
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.wantsLayer = true
        load()
    }

    func load() {
        if let doc = PDFDocument(url: url) {
            document = doc
            pdfView.document = doc
            loadError = nil
        } else {
            loadError = "This file couldn’t be opened as a PDF."
        }
    }

    func markDirty() { isDirty = true }

    func beginSignaturePlacement(_ path: NSBezierPath) {
        pendingSignature = path
        tool = .signature
    }

    func clearPendingSignature() {
        pendingSignature = nil
        if tool == .signature { tool = .select }
    }

    // MARK: - Save in place

    func save(makeBackup: Bool) throws {
        guard let document else { throw PDFEditError.notLoaded }
        if makeBackup && !didBackup {
            try FileBackup.make(for: url)
            didBackup = true
        }
        guard document.write(to: url) else { throw PDFEditError.writeFailed }
        isDirty = false
        lastSaved = Date()
    }

    // MARK: - Find

    func performSearch() {
        guard let document, !searchText.isEmpty else { clearSearch(); return }
        matches = document.findString(searchText, withOptions: [.caseInsensitive])
        currentMatchIndex = 0
        applyHighlights()
        goToCurrentMatch()
    }

    func clearSearch() {
        matches = []
        currentMatchIndex = 0
        pdfView.highlightedSelections = nil
    }

    func nextMatch() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matches.count
        goToCurrentMatch()
    }

    func previousMatch() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matches.count) % matches.count
        goToCurrentMatch()
    }

    private func applyHighlights() {
        for sel in matches { sel.color = .systemYellow }
        pdfView.highlightedSelections = matches.isEmpty ? nil : matches
    }

    private func goToCurrentMatch() {
        guard matches.indices.contains(currentMatchIndex) else { return }
        let sel = matches[currentMatchIndex]
        pdfView.setCurrentSelection(sel, animate: true)
        pdfView.go(to: sel)
        pdfView.scrollSelectionToVisible(nil)
    }

    // MARK: - Replace text (Tier-1 overlay: cover old glyphs + editable text on top)

    /// Whether there is selected text to replace right now.
    var hasTextSelection: Bool { !(pdfView.currentSelection?.string ?? "").isEmpty }

    /// Cover the current text selection with a page-colored box and drop an EDITABLE free-text
    /// annotation pre-filled with that text. Double-click the new text to edit it; Save writes the
    /// PDF back. This is an overlay edit (not reflow); the original glyphs remain underneath, so it
    /// is NOT redaction for privacy.
    @discardableResult
    func replaceSelectedText() -> Bool {
        guard let selection = pdfView.currentSelection,
              let text = selection.string, !text.isEmpty else { return false }
        var didAny = false
        for page in selection.pages {
            let b = selection.bounds(for: page)
            guard b.width > 1, b.height > 1 else { continue }
            let cover = PDFAnnotation(bounds: b.insetBy(dx: -1, dy: -1), forType: .square, withProperties: nil)
            cover.color = .clear
            cover.interiorColor = .white
            let noBorder = PDFBorder(); noBorder.lineWidth = 0; cover.border = noBorder
            page.addAnnotation(cover)

            let ft = PDFAnnotation(bounds: b.insetBy(dx: -2, dy: -2), forType: .freeText, withProperties: nil)
            ft.contents = text
            ft.font = NSFont.systemFont(ofSize: max(8, b.height * 0.72))
            ft.fontColor = .black
            ft.color = .clear
            ft.alignment = .left
            page.addAnnotation(ft)
            didAny = true
        }
        if didAny { pdfView.clearSelection(); markDirty() }
        return didAny
    }

    // MARK: - Copy as plain text

    func copyAllAsPlainText() {
        let string = document?.string ?? ""
        writeToPasteboard(string)
    }

    func copySelectionAsPlainText() {
        guard let string = pdfView.currentSelection?.string, !string.isEmpty else {
            copyAllAsPlainText(); return
        }
        writeToPasteboard(string)
    }

    private func writeToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    // MARK: - Page operations

    var pageCount: Int { document?.pageCount ?? 0 }

    func currentPageIndex() -> Int {
        guard let document, let page = pdfView.currentPage else { return 0 }
        let idx = document.index(for: page)
        return idx == NSNotFound ? 0 : idx
    }

    func rotateCurrentPage(by degrees: Int) {
        guard let page = document?.page(at: currentPageIndex()) else { return }
        page.rotation = normalizedRotation(page.rotation + degrees)
        refreshAfterStructuralChange()
    }

    func deleteCurrentPage() {
        guard let document, document.pageCount > 1 else { return }
        document.removePage(at: currentPageIndex())
        refreshAfterStructuralChange()
    }

    func insertBlankPageAfterCurrent() {
        guard let document else { return }
        let index = currentPageIndex()
        let bounds = document.page(at: index)?.bounds(for: .mediaBox)
            ?? NSRect(x: 0, y: 0, width: 612, height: 792)
        let page = PDFPage()
        page.setBounds(bounds, for: .mediaBox)
        document.insert(page, at: index + 1)
        refreshAfterStructuralChange()
    }

    func insertPages(from otherURL: URL) {
        guard let document, let other = PDFDocument(url: otherURL) else { return }
        var insertAt = currentPageIndex() + 1
        for i in 0..<other.pageCount {
            guard let page = other.page(at: i)?.copy() as? PDFPage else { continue }
            document.insert(page, at: min(insertAt, document.pageCount))
            insertAt += 1
        }
        refreshAfterStructuralChange()
    }

    func extractCurrentPage(to dest: URL) -> Bool {
        guard let document, let page = document.page(at: currentPageIndex())?.copy() as? PDFPage
        else { return false }
        let out = PDFDocument()
        out.insert(page, at: 0)
        return out.write(to: dest)
    }

    func movePage(at index: Int, by offset: Int) {
        guard let document else { return }
        let target = index + offset
        guard (0..<document.pageCount).contains(index),
              (0..<document.pageCount).contains(target),
              let page = document.page(at: index) else { return }
        document.removePage(at: index)
        document.insert(page, at: target)
        refreshAfterStructuralChange()
    }

    private func normalizedRotation(_ value: Int) -> Int {
        let r = value % 360
        return r < 0 ? r + 360 : r
    }

    private func refreshAfterStructuralChange() {
        markDirty()
        // Force PDFView to re-read the (mutated) document.
        if let document {
            let current = pdfView.currentPage
            pdfView.document = document
            if let current, document.index(for: current) != NSNotFound {
                pdfView.go(to: current)
            }
            pdfView.layoutDocumentView()
        }
        objectWillChange.send()
    }
}
