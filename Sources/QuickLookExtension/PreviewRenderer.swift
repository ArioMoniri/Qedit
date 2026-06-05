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
        let prefs = RenderPrefs.load()
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
        \(findBarCSS)
        \(themeStyle(prefs.theme, light: lightCSS, dark: darkCSS))
        </style>
        </head>
        <body data-kind="\(kind.displayName)">
        \(findBarHTML)
        <div class="qe-brand" title="Rendered by Qedit">&#9906; Qedit · \(kind.displayName)</div>
        \(banner)
        \(body)
        <script>\(hljsJS)</script>
        <script>\(markedJS)</script>
        <script>\(purifyJS)</script>
        <script>
        (function () {
          const FILE_KEY = "\(fileKey)";
          const LANG = "\(lang)";
          const GFM = \(prefs.gfm);
          const HARD_BREAKS = \(prefs.hardBreaks);
          const SYNTAX = \(prefs.syntaxHighlighting);
          const ANCHORS = \(prefs.headingAnchors);
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
        <script>\(findBarJS)</script>
        </body>
        </html>
        """
    }

    private var findBarHTML: String {
        """
        <div id="qf-bar" class="qf-bar" hidden>
          <input id="qf-input" type="search" placeholder="Find" autocomplete="off" spellcheck="false">
          <span id="qf-count" class="qf-count"></span>
          <button id="qf-prev" title="Previous (⇧⏎)">&#8593;</button>
          <button id="qf-next" title="Next (⏎)">&#8595;</button>
          <button id="qf-close" title="Close (Esc)">&#10005;</button>
        </div>
        """
    }

    private var findBarCSS: String {
        """
        .qf-bar { position: fixed; top: 8px; right: 8px; z-index: 50; display: flex; gap: 4px;
          align-items: center; padding: 5px 7px; border-radius: 10px;
          background: rgba(244,244,247,0.94); box-shadow: 0 3px 14px rgba(0,0,0,0.25);
          -webkit-backdrop-filter: blur(12px); backdrop-filter: blur(12px);
          font: 12px -apple-system, sans-serif; color: #111; }
        .qf-bar[hidden] { display: none; }
        .qf-bar input { border: 1px solid #0002; border-radius: 6px; padding: 3px 7px;
          font: 12px -apple-system; width: 160px; background: #fff; color: #111; outline: none; }
        .qf-bar button { border: none; background: #0001; border-radius: 6px; width: 22px; height: 22px;
          cursor: pointer; color: #111; font-size: 12px; line-height: 1; }
        .qf-bar button:hover { background: #0002; }
        .qf-count { font-variant-numeric: tabular-nums; opacity: .65; min-width: 40px; text-align: center; }
        mark.qf { background: #ffd23f99; color: inherit; border-radius: 2px; }
        mark.qf-current { background: #ff9f0a; color: #000; }
        @media (prefers-color-scheme: dark) {
          .qf-bar { background: rgba(44,44,48,0.94); color: #eee; }
          .qf-bar input { background: #1118; color: #eee; border-color: #fff2; }
          .qf-bar button { background: #fff1; color: #eee; }
          .qf-bar button:hover { background: #fff3; }
        }
        """
    }

    private var findBarJS: String {
        """
        (function () {
          var bar, input, countEl, marks = [], cur = -1;
          function ensure() {
            bar = document.getElementById('qf-bar');
            input = document.getElementById('qf-input');
            countEl = document.getElementById('qf-count');
            if (!bar || bar.__wired) return;
            bar.__wired = true;
            input.addEventListener('input', function () { doSearch(input.value); });
            input.addEventListener('keydown', function (e) {
              if (e.key === 'Enter') { e.preventDefault(); e.shiftKey ? step(-1) : step(1); }
              else if (e.key === 'Escape') { e.preventDefault(); hide(); }
            });
            document.getElementById('qf-next').addEventListener('click', function () { step(1); });
            document.getElementById('qf-prev').addEventListener('click', function () { step(-1); });
            document.getElementById('qf-close').addEventListener('click', hide);
          }
          function clearMarks() {
            document.querySelectorAll('mark.qf').forEach(function (m) {
              m.parentNode.replaceChild(document.createTextNode(m.textContent), m);
            });
            document.body.normalize();
            marks = []; cur = -1;
          }
          function doSearch(q) {
            clearMarks();
            if (!q) { updateCount(); return; }
            var ql = q.toLowerCase();
            var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
              acceptNode: function (n) {
                if (!n.nodeValue || !n.parentElement) return NodeFilter.FILTER_REJECT;
                if (n.parentElement.closest('#qf-bar')) return NodeFilter.FILTER_REJECT;
                var tag = n.parentElement.tagName;
                if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'MARK') return NodeFilter.FILTER_REJECT;
                return n.nodeValue.toLowerCase().indexOf(ql) !== -1 ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
              }
            });
            var nodes = []; while (walker.nextNode()) nodes.push(walker.currentNode);
            nodes.forEach(function (node) {
              var text = node.nodeValue, lower = text.toLowerCase();
              var frag = document.createDocumentFragment(), i = 0, idx;
              while ((idx = lower.indexOf(ql, i)) !== -1) {
                if (idx > i) frag.appendChild(document.createTextNode(text.slice(i, idx)));
                var m = document.createElement('mark'); m.className = 'qf';
                m.textContent = text.slice(idx, idx + q.length);
                frag.appendChild(m); marks.push(m); i = idx + q.length;
              }
              if (i < text.length) frag.appendChild(document.createTextNode(text.slice(i)));
              node.parentNode.replaceChild(frag, node);
            });
            cur = marks.length ? 0 : -1; highlightCurrent(); updateCount();
          }
          function highlightCurrent() {
            marks.forEach(function (m) { m.classList.remove('qf-current'); });
            if (cur >= 0 && marks[cur]) {
              marks[cur].classList.add('qf-current');
              marks[cur].scrollIntoView({ block: 'center' });
            }
          }
          function step(d) {
            if (!marks.length) return;
            cur = (cur + d + marks.length) % marks.length; highlightCurrent(); updateCount();
          }
          function updateCount() {
            countEl.textContent = marks.length ? (cur + 1) + '/' + marks.length : (input.value ? '0/0' : '');
          }
          function hide() { if (bar) { bar.hidden = true; clearMarks(); updateCount(); } }
          window.__qfShow = function () {
            ensure();
            if (!bar) return;
            bar.hidden = false; input.focus(); input.select();
            if (input.value) doSearch(input.value);
          };
          document.addEventListener('keydown', function (e) {
            if ((e.metaKey || e.ctrlKey) && (e.key === 'f' || e.key === 'F')) {
              e.preventDefault(); window.__qfShow();
            }
          });
        })();
        """
    }

    private func renderScriptJS(for kind: PreviewKind) -> String {
        switch kind {
        case .markdown:
            return """
            try {
              if (window.marked) { marked.setOptions({ gfm: GFM, breaks: HARD_BREAKS }); }
              const dirty = window.marked ? marked.parse(SRC) : SRC;
              const clean = window.DOMPurify ? DOMPurify.sanitize(dirty) : dirty;
              const el = document.getElementById("content");
              el.innerHTML = clean;
              if (SYNTAX) {
                el.querySelectorAll("pre code").forEach(function (c) {
                  try { hljs.highlightElement(c); } catch (e) {}
                });
              }
              if (ANCHORS) {
                el.querySelectorAll("h1,h2,h3,h4,h5,h6").forEach(function (h) {
                  if (!h.id) {
                    h.id = (h.textContent || "").toLowerCase().trim()
                      .replace(/[^\\w\\s-]/g, "").replace(/\\s+/g, "-");
                  }
                  if (h.id) {
                    var a = document.createElement("a");
                    a.href = "#" + h.id; a.className = "qe-anchor";
                    a.setAttribute("aria-hidden", "true"); a.textContent = "#";
                    h.appendChild(a);
                  }
                });
              }
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
            if (SYNTAX) {
              try {
                if (LANG && hljs.getLanguage(LANG)) {
                  code.className = "language-" + LANG;
                  hljs.highlightElement(code);
                } else {
                  hljs.highlightElement(code);
                }
              } catch (e) {}
            }
            """
        }
    }

    /// Choose the theme CSS: `auto` keeps the system light/dark media queries; `light`/`dark`
    /// force one theme (and lock `color-scheme` + a base background so it doesn't flash).
    private func themeStyle(_ theme: RenderPrefs.Theme, light: String, dark: String) -> String {
        switch theme {
        case .auto:
            return """
            :root { color-scheme: light dark; }
            @media (prefers-color-scheme: light) { \(light) }
            @media (prefers-color-scheme: dark)  { \(dark) }
            """
        case .light:
            return ":root { color-scheme: light; } html, body { background: #ffffff; }\n\(light)"
        case .dark:
            return ":root { color-scheme: dark; } html, body { background: #0d1117; color: #e6edf3; }\n\(dark)"
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
        .markdown-body .qe-anchor { margin-left: .4em; opacity: 0; text-decoration: none;
          color: #6b9bff; font-weight: 400; }
        .markdown-body h1:hover .qe-anchor, .markdown-body h2:hover .qe-anchor,
        .markdown-body h3:hover .qe-anchor, .markdown-body h4:hover .qe-anchor,
        .markdown-body h5:hover .qe-anchor, .markdown-body h6:hover .qe-anchor { opacity: .7; }
        pre { margin: 0; padding: 16px 20px; overflow: auto; line-height: 1.5;
          font-family: "SF Mono", Menlo, monospace; font-size: 12px; }
        pre code.hljs { padding: 0; background: none; }
        .qe-log .ll { display: block; white-space: pre-wrap; }
        .qe-log .e { color: #e5534b; }
        .qe-log .w { color: #c69026; }
        .qe-log .i { color: #4c8eda; }
        .qe-log .d { opacity: .6; }
        .qe-brand { position: fixed; left: 10px; bottom: 8px; z-index: 40;
          font: 11px -apple-system, sans-serif; font-weight: 600; letter-spacing: .2px;
          padding: 3px 9px; border-radius: 999px; color: #fff; opacity: .85;
          background: linear-gradient(135deg, #5b9bff, #2563eb);
          box-shadow: 0 1px 6px rgba(37,99,235,.35); pointer-events: none; }
        @media (prefers-color-scheme: dark) { .qe-brand { opacity: .8; } }
        """
    }
}
