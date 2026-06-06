import SwiftUI
import AppKit

/// Read-only slide-by-slide viewer for .pptx — shows each slide's text in a card. Re-saving
/// PowerPoint losslessly isn't safe, so this is view + ⌘F find; "Open in Default App" to edit.
struct PptxView: View {
    let url: URL
    @State private var slides: [PptxReader.Slide] = []
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            banner
            if loaded && slides.isEmpty {
                ContentUnavailableView("Couldn’t read this presentation", systemImage: "rectangle.on.rectangle",
                                       description: Text("Open it in Keynote or PowerPoint."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(slides) { slide in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Slide \(slide.id)")
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                ForEach(slide.paragraphs.indices, id: \.self) { i in
                                    Text(slide.paragraphs[i])
                                        .font(i == 0 ? .title3.weight(.semibold) : .body)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationSubtitle("Presentation · Read-only")
        .task {
            let result = await Task.detached { PptxReader.read(url) }.value
            slides = result ?? []
            loaded = true
        }
    }

    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle").foregroundStyle(.secondary)
            Text("Presentation — read-only. Read the slide text and ⌘F find here; "
                 + "open in Keynote/PowerPoint to edit.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button("Open in Default App") { NSWorkspace.shared.open(url) }
                .controlSize(.small)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.10))
    }
}
