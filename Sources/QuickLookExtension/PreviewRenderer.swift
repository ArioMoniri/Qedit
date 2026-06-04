import Foundation

/// Builds a fully self-contained HTML document for a previewed file.
///
/// Design choices that matter for a *sandboxed, offline* Quick Look extension:
///  - All JS/CSS (highlight.js, marked, DOMPurify, themes) is read from the extension
///    bundle at render time and inlined — no network, no external resource loads.
///  - The file's text is base64-embedded and decoded in JS, so arbitrary file contents
///    can never break out of the HTML or inject script (no escaping edge cases).
///  - Light & dark highlight themes are both inlined under `prefers-color-scheme`.
struct PreviewRenderer {

    struct Rendered {
        let html: String
        let kind: PreviewKind
        let truncated: Bool
        let byteCount: Int
    }

    enum RenderError: Error { case unreadable, emptyAssets }

    let bundle: Bundle

    func render(fileAt url: URL) throws -> Rendered {
        let (text, truncated, byteCount) = try Self.readText(at: url)
        let kind = FileTypeClassifier.kind(for: url)
        let html = buildHTML(text: text, kind: kind, fileURL: url, truncated: truncated)
        return Rendered(html: html, kind: kind, truncated: truncated, byteCount: byteCount)
    }

    // MARK: - Reading

    /// Reads a file's text (resolving .textbundle packages), capped at `maxPreviewBytes`.
    static func readText(at url: URL) throws -> (text: String, truncated: Bool, bytes: Int) {
        let source = textSourceURL(for: url)
        guard let handle = try? FileHandle(forReadingFrom: source) else {
            throw RenderError.unreadable
        }
        defer { try? handle.close() }

        let cap = AppInfo.maxPreviewBytes
        let data = (try? handle.read(upToCount: cap + 1)) ?? Data()
        let truncated = data.count > cap
        let slice = truncated ? data.prefix(cap) : data
        let text = decodeText(Data(slice))
        return (text, truncated, data.count)
    }

    /// For a `.textbundle` package the actual markdown lives inside; otherwise the file itself.
    private static func textSourceURL(for url: URL) -> URL {
        guard url.pathExtension.lowercased() == "textbundle" else { return url }
        let candidates = ["text.markdown", "text.md", "text.txt", "text.text"]
        for name in candidates {
            let candidate = url.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return url
    }

    /// Best-effort text decoding: UTF-8 → UTF-16 (BOM) → ISO Latin-1 → lossy UTF-8.
    private static func decodeText(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .utf16) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Web assets

    private func asset(_ name: String, _ ext: String) -> String {
        guard let assetURL = bundle.url(forResource: name, withExtension: ext, subdirectory: "web"),
              let contents = try? String(contentsOf: assetURL, encoding: .utf8) else {
            return ""
        }
        return contents
    }

    // MARK: - HTML

    private func buildHTML(text: String, kind: PreviewKind, fileURL: URL, truncated: Bool) -> String {
        let hljsJS = asset("highlight.min", "js")
        let lightCSS = asset("github.min", "css")
        let darkCSS = asset("github-dark.min", "css")
        let markedJS = asset("marked.min", "js")
        let purifyJS = asset("purify.min", "js")

        let b64 = Data(text.utf8).base64EncodedString()
        let lang = kind.hljsLanguage ?? ""
        let fileKey = stableKey(for: fileURL)

        let banner = truncated
            ? "<div class='qe-banner'>Preview truncated to \(AppInfo.maxPreviewBytes / (1024 * 1024)) MB — open in Qedit to edit the whole file.</div>"
            : ""

        let body: String
        switch kind {
        case .markdown:
            body = "<article id='content' class='markdown-body'></article>"
        case .log:
            body = "<pre id='log' class='qe-log'></pre>"
        case .sourceCode, .config, .plainText:
            body = "<pre><code id='code'></code></pre>"
        }

        let renderScript = renderScriptJS(for: kind)

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(baseCSS)
        @media (prefers-color-scheme: light) { \(lightCSS) }
        @media (prefers-color-scheme: dark)  { \(darkCSS) }
        </style>
        </head>
        <body data-kind="\(kind.displayName)">
        \(banner)
        \(body)
        <script>\(hljsJS)</script>
        <script>\(markedJS)</script>
        <script>\(purifyJS)</script>
        <script>
        (function () {
          const FILE_KEY = "\(fileKey)";
          const LANG = "\(lang)";
          function b64ToString(b64) {
            const bin = atob(b64);
            const bytes = new Uint8Array(bin.length);
            for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
            return new TextDecoder("utf-8").decode(bytes);
          }
          const SRC = b64ToString("\(b64)");
          \(renderScript)
          \(scrollRestoreJS)
        })();
        </script>
        </body>
        </html>
        """
    }

    private func renderScriptJS(for kind: PreviewKind) -> String {
        switch kind {
        case .markdown:
            return """
            try {
              if (window.marked) { marked.setOptions({ gfm: true, breaks: false }); }
              const dirty = window.marked ? marked.parse(SRC) : SRC;
              const clean = window.DOMPurify ? DOMPurify.sanitize(dirty) : dirty;
              const el = document.getElementById("content");
              el.innerHTML = clean;
              el.querySelectorAll("pre code").forEach(function (c) {
                try { hljs.highlightElement(c); } catch (e) {}
              });
            } catch (e) {
              document.getElementById("content").textContent = SRC;
            }
            """
        case .log:
            return """
            const lines = SRC.split("\\n");
            const frag = document.createDocumentFragment();
            const rx = { error: /\\b(error|err|fatal|critical|fail(ed|ure)?)\\b/i,
                         warn: /\\b(warn(ing)?)\\b/i,
                         info: /\\b(info|notice)\\b/i,
                         debug: /\\b(debug|trace|verbose)\\b/i };
            for (const line of lines) {
              const span = document.createElement("span");
              span.className = "ll" +
                (rx.error.test(line) ? " e" : rx.warn.test(line) ? " w" :
                 rx.info.test(line) ? " i" : rx.debug.test(line) ? " d" : "");
              span.textContent = line + "\\n";
              frag.appendChild(span);
            }
            document.getElementById("log").appendChild(frag);
            """
        case .sourceCode, .config, .plainText:
            return """
            const code = document.getElementById("code");
            code.textContent = SRC;
            try {
              if (LANG && hljs.getLanguage(LANG)) {
                code.className = "language-" + LANG;
                hljs.highlightElement(code);
              } else {
                hljs.highlightElement(code);
              }
            } catch (e) {}
            """
        }
    }

    /// Persist & restore scroll position per file via the native message handler.
    private var scrollRestoreJS: String {
        """
        try {
          const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.qedit;
          window.addEventListener("qedit-restore-scroll", function (ev) {
            const y = ev.detail | 0;
            if (y > 0) window.scrollTo(0, y);
          });
          let ticking = false;
          window.addEventListener("scroll", function () {
            if (ticking) return;
            ticking = true;
            requestAnimationFrame(function () {
              ticking = false;
              if (handler) handler.postMessage({ key: FILE_KEY, y: window.scrollY });
            });
          }, { passive: true });
          if (handler) handler.postMessage({ key: FILE_KEY, request: "restore" });
        } catch (e) {}
        """
    }

    private func stableKey(for url: URL) -> String {
        let path = url.standardizedFileURL.path
        return "f" + String(UInt64(bitPattern: Int64(path.hashValue)))
    }

    private var baseCSS: String {
        """
        :root { color-scheme: light dark; }
        html, body { margin: 0; padding: 0; }
        body {
          font: 13px -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
          -webkit-text-size-adjust: 100%;
        }
        .qe-banner {
          position: sticky; top: 0; z-index: 5;
          padding: 6px 14px; font-size: 12px; font-weight: 600;
          background: #ffcc0033; border-bottom: 1px solid #ffcc0066;
          backdrop-filter: blur(8px);
        }
        .markdown-body { padding: 20px 26px; line-height: 1.6; max-width: 920px; }
        .markdown-body h1, .markdown-body h2 { border-bottom: 1px solid #8884; padding-bottom: .3em; }
        .markdown-body code { font-family: "SF Mono", Menlo, monospace; font-size: 90%;
          background: #8881; padding: .15em .35em; border-radius: 4px; }
        .markdown-body pre { padding: 14px; border-radius: 8px; overflow: auto; background: #8881; }
        .markdown-body pre code { background: none; padding: 0; }
        .markdown-body table { border-collapse: collapse; }
        .markdown-body th, .markdown-body td { border: 1px solid #8884; padding: 6px 10px; }
        .markdown-body img { max-width: 100%; }
        .markdown-body blockquote { margin: 0; padding-left: 1em; border-left: 3px solid #8886; color: #8889; }
        pre { margin: 0; padding: 16px 20px; overflow: auto; line-height: 1.5;
          font-family: "SF Mono", Menlo, monospace; font-size: 12px; }
        pre code.hljs { padding: 0; background: none; }
        .qe-log .ll { display: block; white-space: pre-wrap; }
        .qe-log .e { color: #e5534b; }
        .qe-log .w { color: #c69026; }
        .qe-log .i { color: #4c8eda; }
        .qe-log .d { opacity: .6; }
        """
    }
}
