import SwiftUI
import Quartz   // QuickLookUI — QLPreviewView

/// Wraps a URL as a QLPreviewItem.
final class QLItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    init(_ url: URL) { self.previewItemURL = url }
}

/// Hosts the system QLPreviewView so we render a file's REAL Quick Look (e.g. actual PowerPoint
/// slides with images/layout) read-only, instead of only extracting its text.
struct QLPreview: NSViewRepresentable {
    let url: URL
    /// Bump this to force the rendered preview to reload after the file changes on disk
    /// (e.g. after saving an edit) even though the URL is unchanged.
    var refreshToken: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var url: URL?
        var token = Int.min
    }

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.autostarts = true
        view.previewItem = QLItem(url)
        context.coordinator.url = url
        context.coordinator.token = refreshToken
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        let c = context.coordinator
        if c.url != url {
            view.previewItem = QLItem(url)
            c.url = url
            c.token = refreshToken
        } else if c.token != refreshToken {
            view.refreshPreviewItem()
            c.token = refreshToken
        }
    }
}
