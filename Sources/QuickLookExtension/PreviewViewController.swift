import Cocoa
import Quartz
import WebKit

/// Principal class of the Quick Look preview extension (Module A).
///
/// Renders Markdown / source code / logs / config as rich HTML in a WKWebView.
/// Read-only and non-interactive by design — no editing here; the editor lives in the
/// host app (Module B). Links are blocked and scroll position is restored per file.
final class PreviewViewController: NSViewController, QLPreviewingController {

    private var webView: WKWebView!
    private let scrollDefaultsPrefix = "qe.scroll."

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = false
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pagePrefs

        let controller = WKUserContentController()
        controller.add(WeakScriptMessageHandler(self), name: "qedit")
        config.userContentController = controller

        let web = FindableWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground") // transparent → matches QL panel
        webView = web
        view = web
    }

    // MARK: - QLPreviewingController

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let renderer = PreviewRenderer(bundle: Bundle(for: Self.self))
            let rendered = try renderer.render(fileAt: url)
            webView.loadHTMLString(rendered.html, baseURL: nil)
            // Content is laid out by the navigation delegate; report ready immediately so
            // Quick Look shows the panel without a perceptible stall.
            handler(nil)
        } catch {
            let escaped = url.lastPathComponent
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            webView.loadHTMLString(Self.errorHTML(filename: escaped), baseURL: nil)
            handler(nil)
        }
    }

    private static func errorHTML(filename: String) -> String {
        """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <style>:root{color-scheme:light dark}
        body{font:13px -apple-system,sans-serif;display:flex;height:100vh;margin:0;
        align-items:center;justify-content:center;opacity:.7}</style></head>
        <body>Couldn’t read “\(filename)” for preview.</body></html>
        """
    }

    // MARK: - Scroll persistence

    fileprivate func saveScroll(key: String, y: Double) {
        UserDefaults.standard.set(y, forKey: scrollDefaultsPrefix + key)
    }

    fileprivate func restoreScroll(key: String) {
        let y = UserDefaults.standard.double(forKey: scrollDefaultsPrefix + key)
        guard y > 0 else { return }
        webView.evaluateJavaScript(
            "window.dispatchEvent(new CustomEvent('qedit-restore-scroll',{detail:\(Int(y))}));",
            completionHandler: nil
        )
    }
}

// MARK: - Navigation: block link clicks, allow only the initial in-memory load.

extension PreviewViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        switch navigationAction.navigationType {
        case .other, .reload:
            decisionHandler(.allow) // our loadHTMLString
        default:
            decisionHandler(.cancel) // link clicks, form submits, etc. — previews are read-only
        }
    }
}

// MARK: - Scroll messages from the page.

extension PreviewViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                              didReceive message: WKScriptMessage) {
        guard message.name == "qedit",
              let body = message.body as? [String: Any],
              let key = body["key"] as? String else { return }
        if let request = body["request"] as? String, request == "restore" {
            restoreScroll(key: key)
        } else if let y = body["y"] as? Double {
            saveScroll(key: key, y: y)
        } else if let yInt = body["y"] as? Int {
            saveScroll(key: key, y: Double(yInt))
        }
    }
}

/// Breaks the WKUserContentController → handler → controller retain cycle.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(_ delegate: WKScriptMessageHandler) { self.delegate = delegate }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        delegate?.userContentController(c, didReceive: m)
    }
}

/// WKWebView that maps ⌘F to the in-page find bar, so you can search inside a Quick Look
/// preview (previews are read-only by macOS design — this adds find, not editing).
final class FindableWebView: WKWebView {
    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "f" {
            evaluateJavaScript("window.__qfShow && window.__qfShow();", completionHandler: nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
