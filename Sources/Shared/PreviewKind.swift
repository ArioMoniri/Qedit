import Foundation
import UniformTypeIdentifiers

/// How a non-system file should be presented in a rich preview / editor.
enum PreviewKind: Equatable {
    case markdown
    /// Syntax-highlighted source code. `language` is a highlight.js language id (may be nil → auto-detect).
    case sourceCode(language: String?)
    case log
    /// Structured config (json/yaml/toml/ini/xml). `language` is a highlight.js id.
    case config(language: String?)
    case plainText

    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .sourceCode(let lang): return lang.map { "Code (\($0))" } ?? "Source code"
        case .log: return "Log"
        case .config(let lang): return lang.map { "Config (\($0))" } ?? "Config"
        case .plainText: return "Plain text"
        }
    }

    /// highlight.js language id to use when rendering, or nil to let hljs auto-detect.
    var hljsLanguage: String? {
        switch self {
        case .markdown: return "markdown"
        case .sourceCode(let lang), .config(let lang): return lang
        case .log: return "accesslog"
        case .plainText: return nil
        }
    }
}

/// Classifies files into `PreviewKind` by extension (primary) and UTType (fallback).
/// Extension-first matches how editors actually behave and avoids the plain-text
/// resolution problem where many code files collapse to `public.plain-text`.
enum FileTypeClassifier {

    static func kind(for url: URL, contentType: UTType? = nil) -> PreviewKind {
        let ext = url.pathExtension.lowercased()

        if markdownExtensions.contains(ext) || url.pathExtension.lowercased() == "textbundle" {
            return .markdown
        }
        if logExtensions.contains(ext) {
            return .log
        }
        if let configLang = configLanguages[ext] {
            return .config(language: configLang)
        }
        if let lang = languageByExtension[ext] {
            return .sourceCode(language: lang)
        }

        // Fall back to UTType conformance when the extension is unknown.
        if let type = contentType ?? UTType(filenameExtension: ext) {
            if type.conforms(to: .sourceCode) { return .sourceCode(language: nil) }
            if type.conforms(to: UTType("net.daringfireball.markdown") ?? .plainText) { return .markdown }
            if type.conforms(to: .json) { return .config(language: "json") }
            if type.conforms(to: .xml) { return .config(language: "xml") }
            if type.conforms(to: .yaml) { return .config(language: "yaml") }
        }
        return .plainText
    }

    // MARK: - Tables

    private static let markdownExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "mkdn", "mdwn", "mdtext", "rmd", "qmd"
    ]

    private static let logExtensions: Set<String> = ["log"]

    /// Config types map to a highlight.js language for nicer rendering.
    private static let configLanguages: [String: String] = [
        "json": "json", "json5": "json", "jsonc": "json",
        "yaml": "yaml", "yml": "yaml",
        "toml": "ini",
        "ini": "ini", "cfg": "ini", "conf": "ini", "properties": "properties",
        "xml": "xml", "plist": "xml", "storyboard": "xml", "xib": "xml",
        "env": "bash", "dotenv": "bash",
        "gradle": "groovy"
    ]

    /// Source-code extension → highlight.js language id.
    private static let languageByExtension: [String: String] = [
        "swift": "swift",
        "c": "c", "h": "c",
        "cpp": "cpp", "cc": "cpp", "cxx": "cpp", "hpp": "cpp", "hh": "cpp", "hxx": "cpp",
        "m": "objectivec", "mm": "objectivec",
        "js": "javascript", "mjs": "javascript", "cjs": "javascript", "jsx": "javascript",
        "ts": "typescript", "tsx": "typescript",
        "py": "python", "pyw": "python",
        "rb": "ruby", "erb": "ruby",
        "go": "go",
        "rs": "rust",
        "java": "java",
        "kt": "kotlin", "kts": "kotlin",
        "cs": "csharp",
        "php": "php",
        "pl": "perl", "pm": "perl",
        "sh": "bash", "bash": "bash", "zsh": "bash", "fish": "bash",
        "sql": "sql",
        "r": "r",
        "scala": "scala",
        "dart": "dart",
        "lua": "lua",
        "html": "xml", "htm": "xml",
        "css": "css", "scss": "scss", "sass": "scss", "less": "less",
        "vue": "xml",
        "dockerfile": "dockerfile",
        "makefile": "makefile", "mk": "makefile",
        "groovy": "groovy",
        "tex": "latex",
        "diff": "diff", "patch": "diff"
    ]
}
