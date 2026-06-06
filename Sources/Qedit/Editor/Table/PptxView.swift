import SwiftUI
import AppKit

/// Read-only PowerPoint viewer. Renders the REAL slides via the system Quick Look (QLPreviewView)
/// — actual layout, images and text — instead of plain extracted text. Re-saving .pptx losslessly
/// isn't safe, so it's view-only; "Open in Default App" to edit in Keynote/PowerPoint.
struct PptxView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 0) {
            banner
            QLPreview(url: url)
        }
        .navigationTitle(url.lastPathComponent)
        .navigationSubtitle("Presentation · Read-only")
    }

    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle").foregroundStyle(.secondary)
            Text("Presentation — read-only native preview. Open in Keynote/PowerPoint to edit.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button("Open in Default App") { NSWorkspace.shared.open(url) }.controlSize(.small)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.10))
    }
}
