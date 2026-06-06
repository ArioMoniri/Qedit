import SwiftUI
import AppKit

/// Read-only slide-by-slide viewer for .pptx — each slide's text in a card, with ⌘F find.
/// Re-saving PowerPoint losslessly isn't safe, so this is view + find; "Open in Default App" to edit.
struct PptxView: View {
    let url: URL
    @State private var slides: [PptxReader.Slide] = []
    @State private var loaded = false

    @State private var showFind = false
    @State private var query = ""
    @State private var matches: [String] = []   // paragraph ids "slide.para"
    @State private var matchIdx = 0

    var body: some View {
        VStack(spacing: 0) {
            banner
            if loaded && slides.isEmpty {
                ContentUnavailableView("Couldn’t read this presentation", systemImage: "rectangle.on.rectangle",
                                       description: Text("Open it in Keynote or PowerPoint."))
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(slides) { slide in
                                slideCard(slide)
                            }
                        }
                        .padding(18).frame(maxWidth: 820).frame(maxWidth: .infinity)
                    }
                    .onChange(of: matchIdx) { _, _ in
                        guard !matches.isEmpty else { return }
                        withAnimation { proxy.scrollTo(matches[matchIdx], anchor: .center) }
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if showFind {
                FindBar(query: $query, count: matches.count, index: matches.isEmpty ? 0 : matchIdx + 1,
                        onNext: { step(1) }, onPrev: { step(-1) }, onClose: { showFind = false; query = "" })
            }
        }
        .background(Button("") { showFind.toggle() }.keyboardShortcut("f", modifiers: .command).opacity(0))
        .onChange(of: query) { _, _ in recompute() }
        .navigationTitle(url.lastPathComponent)
        .navigationSubtitle("Presentation · Read-only")
        .task {
            let result = await Task.detached { PptxReader.read(url) }.value
            slides = result ?? []
            loaded = true
        }
    }

    @ViewBuilder
    private func slideCard(_ slide: PptxReader.Slide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Slide \(slide.id)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(slide.paragraphs.indices, id: \.self) { i in
                let pid = "\(slide.id).\(i)"
                let isMatch = !query.isEmpty && slide.paragraphs[i].localizedCaseInsensitiveContains(query)
                let isCurrent = isMatch && !matches.isEmpty && matches[matchIdx] == pid
                Text(slide.paragraphs[i])
                    .font(i == 0 ? .title3.weight(.semibold) : .body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(isCurrent ? Color.orange.opacity(0.4) : (isMatch ? Color.yellow.opacity(0.35) : .clear))
                    .id(pid)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }

    private func recompute() {
        guard !query.isEmpty else { matches = []; matchIdx = 0; return }
        var found: [String] = []
        for slide in slides {
            for i in slide.paragraphs.indices where slide.paragraphs[i].localizedCaseInsensitiveContains(query) {
                found.append("\(slide.id).\(i)")
            }
        }
        matches = found; matchIdx = 0
    }

    private func step(_ d: Int) {
        guard !matches.isEmpty else { return }
        matchIdx = (matchIdx + d + matches.count) % matches.count
    }

    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle").foregroundStyle(.secondary)
            Text("Presentation — read-only. **⌘F** to find across slides; open in Keynote/PowerPoint to edit.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button("Open in Default App") { NSWorkspace.shared.open(url) }.controlSize(.small)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.10))
    }
}
