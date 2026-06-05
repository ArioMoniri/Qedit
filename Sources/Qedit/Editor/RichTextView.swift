import SwiftUI
import AppKit

/// An `NSTextView`-backed RICH editor for RTF / RTFD / ODT / Word — it shows the document in
/// its native formatted shape (fonts, bold, lists…) and, when editable, writes it back in the
/// same format. ⌘F opens the native find bar (reusing `FindableTextView`).
struct RichTextView: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var isEditable: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = FindableTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        let big = CGFloat.greatestFiniteMagnitude
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: big, height: big)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: big)
        textView.textContainer?.widthTracksTextView = true

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 10, height: 12)
        textView.textStorage?.setAttributedString(attributedText)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.isEditable != isEditable { textView.isEditable = isEditable }
        // Only replace the storage on an EXTERNAL change (e.g. Reload), never while the user is
        // typing — that would reset the caret and selection.
        if !context.coordinator.isUpdatingFromTextView,
           textView.textStorage?.isEqual(to: attributedText) == false {
            let selected = textView.selectedRange()
            textView.textStorage?.setAttributedString(attributedText)
            if selected.location <= (textView.string as NSString).length {
                textView.setSelectedRange(selected)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextView
        var isUpdatingFromTextView = false
        init(_ parent: RichTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdatingFromTextView = true
            parent.attributedText = textView.attributedString()
            isUpdatingFromTextView = false
        }
    }
}
