import SwiftUI
import AppKit

/// A non-flipped (y-up, matching PDF page space) canvas the user draws a signature on.
final class SignatureCanvasView: NSView {
    private var paths: [NSBezierPath] = []
    private var current: NSBezierPath?

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let path = NSBezierPath()
        path.lineWidth = 2.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: point)
        current = path
        paths.append(path)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let current else { return }
        current.line(to: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) { current = nil }

    func clear() {
        paths.removeAll()
        current = nil
        needsDisplay = true
    }

    /// The combined drawn path in view coordinates, or nil if nothing was drawn.
    func combinedPath() -> NSBezierPath? {
        guard !paths.isEmpty else { return nil }
        let combined = NSBezierPath()
        for path in paths { combined.append(path) }
        return combined.isEmpty ? nil : combined
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        dirtyRect.fill()

        NSColor.separatorColor.setStroke()
        let baseline = NSBezierPath()
        baseline.move(to: NSPoint(x: 14, y: bounds.height * 0.3))
        baseline.line(to: NSPoint(x: bounds.width - 14, y: bounds.height * 0.3))
        baseline.lineWidth = 1
        baseline.stroke()

        NSColor.labelColor.setStroke()
        for path in paths { path.stroke() }
    }
}

@MainActor
final class SignatureController: ObservableObject {
    weak var canvas: SignatureCanvasView?
    func clear() { canvas?.clear() }
    func path() -> NSBezierPath? { canvas?.combinedPath() }
}

struct SignatureCanvas: NSViewRepresentable {
    let controller: SignatureController
    func makeNSView(context: Context) -> SignatureCanvasView {
        let view = SignatureCanvasView()
        controller.canvas = view
        return view
    }
    func updateNSView(_ nsView: SignatureCanvasView, context: Context) {}
}

struct SignatureSheet: View {
    var onComplete: (NSBezierPath) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = SignatureController()

    var body: some View {
        VStack(spacing: 14) {
            Text("Draw your signature").font(.headline)
            Text("Use your trackpad or mouse. You’ll click on the page to place it.")
                .font(.caption).foregroundStyle(.secondary)
            SignatureCanvas(controller: controller)
                .frame(width: 420, height: 180)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
            HStack {
                Button("Clear") { controller.clear() }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Place Signature") {
                    if let path = controller.path() { onComplete(path) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
