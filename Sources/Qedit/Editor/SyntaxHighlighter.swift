import AppKit

/// A lightweight, dependency-free syntax colorizer for the editable code view. It colors
/// comments, strings, numbers and keywords with system colors (so it adapts to light/dark).
/// Display-only: it changes attributes, never the text — saved bytes are untouched.
enum SyntaxHighlighter {
    /// Languages where `#` starts a line comment.
    private static let hashComment: Set<String> = [
        "python", "ruby", "bash", "perl", "r", "yaml", "ini", "makefile", "properties", "toml"
    ]

    static func apply(to storage: NSTextStorage, language: String?, font: NSFont) {
        let nsText = storage.string as NSString
        let length = nsText.length
        guard length > 0, length < 400_000 else {   // skip very large files to stay responsive
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor,
                                  range: NSRange(location: 0, length: length))
            return
        }
        let full = NSRange(location: 0, length: length)

        storage.beginEditing()
        storage.setAttributes([.foregroundColor: NSColor.labelColor, .font: font], range: full)

        // Numbers
        color(storage, nsText, #"\b\d+(?:\.\d+)?\b"#, .systemBlue)

        // Keywords
        if let words = keywords(for: language), !words.isEmpty {
            let pattern = "\\b(?:" + words.joined(separator: "|") + ")\\b"
            color(storage, nsText, pattern, .systemPink)
        }

        // Strings (after keywords so quoted text wins)
        color(storage, nsText, "\"(?:\\\\.|[^\"\\\\])*\"", .systemRed)
        color(storage, nsText, "'(?:\\\\.|[^'\\\\])*'", .systemRed)

        // Comments (win over everything). Hash-comment languages use `#`; everything else
        // (incl. unknown) gets C-style `//` and `/* */`.
        let lang = language ?? ""
        if hashComment.contains(lang) {
            color(storage, nsText, #"#[^\n]*"#, .systemGreen)
        } else {
            color(storage, nsText, #"//[^\n]*"#, .systemGreen)
            color(storage, nsText, #"/\*[\s\S]*?\*/"#, .systemGreen)
        }
        storage.endEditing()
    }

    private static func color(_ storage: NSTextStorage, _ text: NSString, _ pattern: String, _ nsColor: NSColor) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(location: 0, length: text.length)
        regex.enumerateMatches(in: text as String, range: range) { match, _, _ in
            if let m = match { storage.addAttribute(.foregroundColor, value: nsColor, range: m.range) }
        }
    }

    private static func keywords(for language: String?) -> [String]? {
        guard let language else { return generic }
        switch language {
        case "swift":
            return ["func", "var", "let", "if", "else", "guard", "for", "while", "return", "class",
                    "struct", "enum", "protocol", "extension", "import", "switch", "case", "default",
                    "public", "private", "internal", "static", "self", "nil", "true", "false", "in", "throws", "try", "async", "await"]
        case "python":
            return ["def", "class", "if", "elif", "else", "for", "while", "return", "import", "from",
                    "as", "with", "try", "except", "finally", "lambda", "None", "True", "False", "and", "or", "not", "in", "is", "pass", "yield"]
        case "javascript", "typescript":
            return ["function", "var", "let", "const", "if", "else", "for", "while", "return", "class",
                    "import", "export", "from", "new", "this", "null", "undefined", "true", "false", "async", "await", "try", "catch", "switch", "case", "default", "typeof"]
        case "json":
            return ["true", "false", "null"]
        default:
            return generic
        }
    }

    private static let generic = [
        "if", "else", "for", "while", "return", "function", "func", "def", "class", "struct",
        "var", "let", "const", "import", "public", "private", "static", "true", "false", "null", "nil"
    ]
}
