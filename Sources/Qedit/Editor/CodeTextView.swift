import SwiftUI
import AppKit

/// An `NSTextView`-backed editor. Using AppKit (rather than SwiftUI `TextEditor`) gives us
/// the native find/replace bar, undo, and monospaced layout. `FindableTextView` maps ⌘F to
/// the find bar locally (no app-wide Find command, so it never clashes with the PDF editor's ⌘F).
struct CodeTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    /// When non-nil, fenced code is syntax-colored for this highlight.js language id
    /// ("swift", "python", "json"…, or "code" for an unknown source language).
    var language: String? = nil
    /// The on-disk text, for highlighting what you've changed.
    var originalText: String = ""
    var highlightChanges: Bool = false
    var changeStyle: ChangeHighlightStyle = .background
    var colors: SyntaxColors = .system

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
        textView.isEditable = isEditable
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.string = text
        highlight(textView)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            highlight(textView)
        }
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
    }

    /// Apply syntax colors + change marks (display-only; never touches the text bytes).
    private func highlight(_ textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        Self.applyHighlight(storage, language: language, highlightChanges: highlightChanges,
                            changeStyle: changeStyle, original: originalText, colors: colors,
                            font: textView.font ?? .monospacedSystemFont(ofSize: 12, weight: .regular))
    }

    static func applyHighlight(_ storage: NSTextStorage, language: String?, highlightChanges: Bool,
                              changeStyle: ChangeHighlightStyle, original: String,
                              colors: SyntaxColors, font: NSFont) {
        let needsSyntax = language != nil
        guard needsSyntax || highlightChanges else { return }
        let full = NSRange(location: 0, length: (storage.string as NSString).length)
        if needsSyntax {
            SyntaxHighlighter.apply(to: storage, language: language, font: font, colors: colors)
        } else {
            // Plain text: clear our previous marks, restore default color.
            storage.removeAttribute(.backgroundColor, range: full)
            storage.removeAttribute(.underlineStyle, range: full)
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)
        }
        guard highlightChanges,
              let range = changedRange(original: original as NSString, current: storage.string as NSString)
        else { return }
        switch changeStyle {
        case .background:
            storage.addAttribute(.backgroundColor, value: colors.change.withAlphaComponent(0.34), range: range)
        case .underline:
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            storage.addAttribute(.underlineColor, value: colors.change, range: range)
        case .color:
            storage.addAttribute(.foregroundColor, value: colors.change, range: range)
        }
    }

    /// The single span (in the current text) that differs from `original`, via common
    /// prefix/suffix — coarse but cheap, and shows "what you changed".
    static func changedRange(original: NSString, current: NSString) -> NSRange? {
        let oLen = original.length, cLen = current.length
        var prefix = 0
        while prefix < oLen && prefix < cLen
            && original.character(at: prefix) == current.character(at: prefix) { prefix += 1 }
        var suffix = 0
        while suffix < (oLen - prefix) && suffix < (cLen - prefix)
            && original.character(at: oLen - 1 - suffix) == current.character(at: cLen - 1 - suffix) { suffix += 1 }
        let start = prefix
        let end = cLen - suffix
        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeTextView
        private var rehighlight: DispatchWorkItem?
        init(_ parent: CodeTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            // Re-color shortly after typing settles (skip during IME composition).
            guard parent.language != nil || parent.highlightChanges,
                  textView.hasMarkedText() == false else { return }
            rehighlight?.cancel()
            let work = DispatchWorkItem { [weak textView] in
                guard let textView, let storage = textView.textStorage,
                      textView.hasMarkedText() == false else { return }
                CodeTextView.applyHighlight(storage, language: self.parent.language,
                                            highlightChanges: self.parent.highlightChanges,
                                            changeStyle: self.parent.changeStyle,
                                            original: self.parent.originalText,
                                            colors: self.parent.colors,
                                            font: textView.font ?? .monospacedSystemFont(ofSize: 12, weight: .regular))
            }
            rehighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }
}

/// NSTextView that shows the find bar on ⌘F (the standard binding needs a menu item that
/// SwiftUI apps don't ship, so we wire it here, scoped to this view).
final class FindableTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods == .command, event.charactersIgnoringModifiers?.lowercased() == "f" {
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.showFindInterface.rawValue
            performTextFinderAction(item)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
