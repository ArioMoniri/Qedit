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
        context.coordinator.parent = self   // keep the coordinator's settings fresh (style/colors/toggle)
        if textView.string != text {
            textView.string = text
            highlight(textView)
        } else if context.coordinator.highlightKey != highlightKey {
            // Text unchanged but a highlight setting changed (toggle/style/colors) — re-apply.
            highlight(textView)
        }
        context.coordinator.highlightKey = highlightKey
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
    }

    /// A signature of everything that affects highlighting, so we re-render when any of it changes.
    private var highlightKey: String {
        "\(highlightChanges)|\(changeStyle.rawValue)|\(language ?? "")|\(colors.change.hashValue)|\(originalText.hashValue)"
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
        // Always clear OUR previous marks first, so stale highlights never linger.
        storage.removeAttribute(.backgroundColor, range: full)
        storage.removeAttribute(.underlineStyle, range: full)
        storage.removeAttribute(.underlineColor, range: full)
        if needsSyntax {
            SyntaxHighlighter.apply(to: storage, language: language, font: font, colors: colors)
        } else {
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)
        }
        guard highlightChanges else { return }
        let marks = ChangeDiff.marks(original: original, current: storage.string)
        Self.applyMarks(marks, style: changeStyle, color: colors.change, length: full.length) { attr, value, range in
            storage.addAttribute(attr, value: value, range: range)
        }
    }

    /// Apply change marks to any backing store via `add` (used for both NSTextStorage and, in the
    /// rich editor, an NSLayoutManager's temporary attributes). Inserted/changed spans use the
    /// chosen style; deletion seams get a dashed underline (nothing remains there to color).
    static func applyMarks(_ marks: ChangeDiff.Marks, style: ChangeHighlightStyle, color: NSColor,
                           length: Int, add: (NSAttributedString.Key, Any, NSRange) -> Void) {
        for r in marks.changed {
            let clamped = NSRange(location: min(r.location, length),
                                  length: min(r.length, max(0, length - r.location)))
            guard clamped.length > 0 else { continue }
            switch style {
            case .background:
                add(.backgroundColor, color.withAlphaComponent(0.40), clamped)
            case .underline:
                add(.underlineStyle, NSUnderlineStyle.thick.rawValue, clamped)
                add(.underlineColor, color, clamped)
            case .color:
                add(.foregroundColor, color, clamped)
            }
        }
        for offset in marks.deletions {
            let loc = offset < length ? offset : length - 1
            guard loc >= 0, length > 0 else { continue }
            let r = NSRange(location: loc, length: 1)
            add(.underlineStyle, NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDash.rawValue, r)
            add(.underlineColor, color, r)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeTextView
        var highlightKey = ""
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
