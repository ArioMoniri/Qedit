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

    /// Apply syntax colors (text storage) + change marks (display-only). Never touches text bytes.
    private func highlight(_ textView: NSTextView) {
        Self.applyAll(to: textView, language: language, highlightChanges: highlightChanges,
                      changeStyle: changeStyle, original: originalText, colors: colors,
                      font: textView.font ?? .monospacedSystemFont(ofSize: 12, weight: .regular))
    }

    static func applyAll(to textView: NSTextView, language: String?, highlightChanges: Bool,
                         changeStyle: ChangeHighlightStyle, original: String,
                         colors: SyntaxColors, font: NSFont) {
        guard let storage = textView.textStorage else { return }
        // Syntax coloring lives on the text storage (foreground/font).
        if language != nil {
            SyntaxHighlighter.apply(to: storage, language: language, font: font, colors: colors)
        } else {
            let full = NSRange(location: 0, length: (storage.string as NSString).length)
            storage.removeAttribute(.backgroundColor, range: full)
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)
        }
        // Change marks live on the layout manager as TEMPORARY attributes — display-only and fully
        // independent of the syntax pass, so re-coloring code can never wipe them.
        applyChangeMarks(to: textView, highlightChanges: highlightChanges,
                         style: changeStyle, original: original, color: colors.change)
    }

    static func applyChangeMarks(to textView: NSTextView, highlightChanges: Bool,
                                 style: ChangeHighlightStyle, original: String, color: NSColor) {
        let len = (textView.string as NSString).length
        let full = NSRange(location: 0, length: len)
        let keys: [NSAttributedString.Key] = [.backgroundColor, .underlineStyle, .underlineColor, .foregroundColor]

        if let lm = textView.layoutManager {
            // Preferred: TEMPORARY attributes — display-only, independent of the syntax pass.
            for key in keys { lm.removeTemporaryAttribute(key, forCharacterRange: full) }
            guard highlightChanges, len > 0 else { return }
            let marks = ChangeDiff.marks(original: original, current: textView.string)
            applyMarks(marks, style: style, color: color, length: len) { attr, value, range in
                lm.addTemporaryAttributes([attr: value], forCharacterRange: range)
            }
        } else if let storage = textView.textStorage {
            // Fallback (no layout manager / TextKit 2): mark on the storage. Always runs AFTER the
            // syntax pass in applyAll(), so it isn't wiped.
            for key in keys where key != .foregroundColor { storage.removeAttribute(key, range: full) }
            guard highlightChanges, len > 0 else { return }
            let marks = ChangeDiff.marks(original: original, current: textView.string)
            applyMarks(marks, style: style, color: color, length: len) { attr, value, range in
                storage.addAttribute(attr, value: value, range: range)
            }
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
                guard let textView, textView.hasMarkedText() == false else { return }
                CodeTextView.applyAll(to: textView, language: self.parent.language,
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
