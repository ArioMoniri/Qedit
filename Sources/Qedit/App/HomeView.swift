import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                pipelineCard
                openCard
                if !appState.recentFiles.isEmpty { recentsCard }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Qedit")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find & edit any file — without changing its format")
                .font(.title2).bold()
            Text("Rich Quick Look previews for the files macOS renders flat, plus an on-demand "
                 + "editor that writes back in place. A .pdf stays a .pdf; a .md stays a .md.")
                .foregroundStyle(.secondary)
        }
    }

    private var pipelineCard: some View {
        Card(title: "How it works", systemImage: "arrow.triangle.2.circlepath") {
            HStack(alignment: .top, spacing: 18) {
                Step(number: "1", title: "Preview (read)",
                     detail: "Press Space in Finder. Qedit’s Quick Look extension renders Markdown, "
                           + "code, logs and config with highlighting. System types keep Apple’s preview.")
                Divider()
                Step(number: "2", title: "Edit (write)",
                     detail: "Use the Quick Action or the global hotkey to open the same file in the "
                           + "editor. Find, change, save in place — original format preserved.")
            }
        }
    }

    private var openCard: some View {
        Card(title: "Open a file to edit", systemImage: "square.and.pencil") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick any PDF, text, source, Markdown, log or config file. "
                     + "PDFs open in the find/annotate/page editor; everything else in the text editor.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Button {
                    if let url = FileOpener.runOpenPanel() { open(url) }
                } label: {
                    Label("Open File…", systemImage: "folder")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }

    private var recentsCard: some View {
        Card(title: "Recent files", systemImage: "clock") {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(appState.recentFiles, id: \.self) { url in
                    Button {
                        open(url)
                    } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable().frame(width: 18, height: 18)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(url.lastPathComponent)
                                Text(url.deletingLastPathComponent().path)
                                    .font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
                Divider().padding(.vertical, 4)
                Button("Clear Recents") { appState.clearRecents() }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
    }

    private func open(_ url: URL) {
        appState.noteOpened(url)
        openWindow(id: "editor", value: url)
    }
}

// MARK: - Reusable building blocks

struct Card<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct Step: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(number)
                    .font(.caption).bold()
                    .frame(width: 20, height: 20)
                    .background(.tint, in: Circle())
                    .foregroundStyle(.white)
                Text(title).font(.subheadline).bold()
            }
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
