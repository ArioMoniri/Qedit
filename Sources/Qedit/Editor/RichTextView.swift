import SwiftUI
import AppKit

/// An `NSTextView`-backed RICH editor for RTF / RTFD / ODT / Word — it shows the document in
/// its native formatted shape (fonts, bold, lists…) and, when editable, writes it back in the
/// same format. ⌘F opens the native find bar (reusing `FindableTextView`).
///
/// Change-highlighting is drawn with the layout manager's TEMPORARY attributes, which are
/// display-only — so highlighting what you changed never becomes part of the saved document.
struct RichTextView: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var isEditable: Bool
    /// The plain text as it was on disk, for highlighting what changed.
    var originalText: String = ""
    var highlightChanges: Bool = false
    var changeStyle: ChangeHighlightStyle = .background
    var changeColor: NSColor = .systemYellow

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
        applyChangeMarks(textView)
        context.coordinator.highlightKey = highlightKey
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
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
            applyChangeMarks(textView)
        } else if context.coordinator.highlightKey != highlightKey {
            applyChangeMarks(textView)
        }
        context.coordinator.highlightKey = highlightKey
    }

    private var highlightKey: String {
        "\(highlightChanges)|\(changeStyle.rawValue)|\(changeColor.hashValue)|\(originalText.hashValue)"
    }

    /// Draw change marks as display-only temporary attributes (never saved into the document).
    func applyChangeMarks(_ textView: NSTextView) {
        guard let lm = textView.layoutManager else { return }
        let len = (textView.string as NSString).length
        let full = NSRange(location: 0, length: len)
        for key in [NSAttributedString.Key.backgroundColor, .underlineStyle, .underlineColor, .foregroundColor] {
            lm.removeTemporaryAttribute(key, forCharacterRange: full)
        }
        guard highlightChanges, len > 0 else { return }
        let marks = ChangeDiff.marks(original: originalText, current: textView.string)
        CodeTextView.applyMarks(marks, style: changeStyle, color: changeColor, length: len) { attr, value, range in
            lm.addTemporaryAttributes([attr: value], forCharacterRange: range)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextView
        var isUpdatingFromTextView = false
        var highlightKey = ""
        private var rehighlight: DispatchWorkItem?
        init(_ parent: RichTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdatingFromTextView = true
            parent.attributedText = textView.attributedString()
            isUpdatingFromTextView = false
            guard parent.highlightChanges else { return }
            rehighlight?.cancel()
            let work = DispatchWorkItem { [weak textView] in
                guard let textView else { return }
                self.parent.applyChangeMarks(textView)
            }
            rehighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }
}
