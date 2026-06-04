import SwiftUI
import PDFKit
import AppKit

/// A `PDFView` subclass that adds annotation tools (highlight, note, text box, signature
/// placement) on top of PDFKit's built-in text selection. All annotations are added to the
/// in-memory `PDFDocument`; saving writes them back into the original `.pdf` (no conversion).
final class AnnotatingPDFView: PDFView {
    weak var model: PDFEditorModel?

    // MARK: - Mouse routing by tool

    override func mouseDown(with event: NSEvent) {
        guard let model else { super.mouseDown(with: event); return }
        switch model.tool {
        case .select, .highlight:
            super.mouseDown(with: event)        // let PDFKit drive text selection
        case .note:
            addNote(at: event)
        case .text:
            addTextBox(at: event)
        case .signature:
            stampSignature(at: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let model else { super.mouseUp(with: event); return }
        if model.tool == .highlight {
            super.mouseUp(with: event)
            addHighlightFromSelection()
        } else {
            super.mouseUp(with: event)
        }
    }

    // MARK: - Geometry

    private func pageAndPoint(for event: NSEvent) -> (PDFPage, NSPoint)? {
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: true) else { return nil }
        return (page, convert(viewPoint, to: page))
    }

    // MARK: - Highlight

    private func addHighlightFromSelection() {
        guard let model, let selection = currentSelection else { return }
        let color = NSColor(model.inkColor).withAlphaComponent(0.45)
        var added = false
        for line in selection.selectionsByLine() {
            for page in line.pages {
                let bounds = line.bounds(for: page)
                guard bounds.width > 1, bounds.height > 1 else { continue }
                let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = color
                page.addAnnotation(annotation)
                added = true
            }
        }
        clearSelection()
        if added { model.markDirty() }
    }

    // MARK: - Note (sticky)

    private func addNote(at event: NSEvent) {
        guard let model, let (page, point) = pageAndPoint(for: event),
              let text = TextPrompt.run(title: "Add Note", message: "Note text:") else { return }
        let size: CGFloat = 22
        let bounds = NSRect(x: point.x, y: point.y - size, width: size, height: size)
        let annotation = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
        annotation.contents = text
        annotation.color = NSColor(model.inkColor)
        annotation.iconType = .note
        page.addAnnotation(annotation)
        model.markDirty()
        model.tool = .select
    }

    // MARK: - Text box (free text)

    private func addTextBox(at event: NSEvent) {
        guard let model, let (page, point) = pageAndPoint(for: event),
              let text = TextPrompt.run(title: "Add Text Box", message: "Text:"),
              !text.isEmpty else { return }
        let font = NSFont.systemFont(ofSize: 14)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let bounds = NSRect(x: point.x, y: point.y - textSize.height - 6,
                            width: max(textSize.width + 14, 60), height: textSize.height + 10)
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = font
        annotation.fontColor = NSColor(model.inkColor)
        annotation.color = .clear
        page.addAnnotation(annotation)
        model.markDirty()
        model.tool = .select
    }

    // MARK: - Signature (ink annotation from a drawn path)

    private func stampSignature(at event: NSEvent) {
        guard let model, let path = model.pendingSignature,
              let (page, point) = pageAndPoint(for: event) else { return }
        let src = path.bounds
        guard src.width > 1, src.height > 1 else { model.clearPendingSignature(); return }

        let targetWidth: CGFloat = 180
        let scale = targetWidth / src.width
        let targetHeight = src.height * scale
        let bounds = NSRect(x: point.x - targetWidth / 2, y: point.y,
                            width: targetWidth, height: targetHeight)

        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.color = NSColor(model.inkColor)
        let border = PDFBorder(); border.lineWidth = 1.6; annotation.border = border

        // Move the drawn path into annotation-local space (origin 0,0) and scale to fit.
        let local = path.copy() as! NSBezierPath
        local.transform(using: AffineTransform(translationByX: -src.origin.x, byY: -src.origin.y))
        local.transform(using: AffineTransform(scaleByX: scale, byY: scale))
        annotation.add(local)

        page.addAnnotation(annotation)
        model.markDirty()
        model.clearPendingSignature()
    }
}

/// Hosts the model's shared `PDFView` in SwiftUI.
struct PDFKitView: NSViewRepresentable {
    @ObservedObject var model: PDFEditorModel

    func makeNSView(context: Context) -> AnnotatingPDFView {
        model.pdfView
    }

    func updateNSView(_ nsView: AnnotatingPDFView, context: Context) {
        if nsView.document !== model.document {
            nsView.document = model.document
        }
    }
}
