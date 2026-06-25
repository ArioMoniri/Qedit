import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var finderMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                pipelineCard
                browserCard
                finderSelectionCard
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
            Text("Open any file in an editor panel or window, change it, and save straight back in "
                 + "place. A .pdf stays a .pdf; a .docx stays a .docx. Plus a manager for all your "
                 + "Quick Look preview plugins.")
                .foregroundStyle(.secondary)
        }
    }

    private var pipelineCard: some View {
        Card(title: "How it works", systemImage: "arrow.triangle.2.circlepath") {
            HStack(alignment: .top, spacing: 18) {
                Step(number: "1", title: "Open",
                     detail: "Open a file in Qedit — the Browser (⌥⌘B), the hotkey (⌥⌘E) on the Finder "
                           + "selection, or right-click → Open With → Qedit. It opens in a panel or "
                           + "window — nothing on disk changes yet.")
                Divider()
                Step(number: "2", title: "Edit & save in place",
                     detail: "Find with ⌘F, edit, and save straight back in the original format — text, "
                           + "code, Markdown, Word, Excel, PowerPoint, PDF. No conversion.")
            }
        }
    }

    /// Browse a folder and edit files inline — the closest thing to "edit in the preview" macOS
    /// allows (Finder's own preview pane is read-only and can't take keystrokes).
    private var browserCard: some View {
        Card(title: "Browse & edit files (live preview)", systemImage: "sidebar.right") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Open a folder and **click any file to edit it right there** in the side-by-side "
                     + "editor — no Space, no shortcut. Find with ⌘F, save in place. This is Qedit’s "
                     + "own editable preview pane (macOS won’t let any app edit inside Finder’s).")
                    .foregroundStyle(.secondary).font(.callout)
                Button { openWindow(id: "browser") } label: {
                    Label("Open Browser", systemImage: "sidebar.right").padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
            }
        }
    }

    /// Edit whatever is selected in Finder right now — by button, no Space and no hotkey needed.
    private var finderSelectionCard: some View {
        Card(title: "Edit the file selected in Finder", systemImage: "filemenu.and.selection") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Select a file in Finder, then click below to open it here — **no Space, no "
                     + "⌥⌘E needed.** (macOS asks once for permission to read the Finder selection.)")
                    .foregroundStyle(.secondary).font(.callout)
                HStack(spacing: 10) {
                    Button { editFinderSelection(inPanel: true) } label: {
                        Label("Quick Panel", systemImage: "bolt").padding(.horizontal, 4)
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
                    Button { editFinderSelection(inPanel: false) } label: {
                        Label("Open Window", systemImage: "macwindow").padding(.horizontal, 4)
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.large)
                }
                if let finderMessage {
                    Text(finderMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func editFinderSelection(inPanel: Bool) {
        guard let url = FinderSelection.currentFileURL() else {
            NSSound.beep()
            finderMessage = "No file is selected in Finder (or permission was denied). "
                + "Select a file in Finder and try again."
            return
        }
        finderMessage = nil
        appState.noteOpened(url)
        if inPanel && !EditorWindowView.needsWindow(url) {
            QuickPanelController.shared.present(url)
        } else {
            openWindow(id: "editor", value: url.standardizedFileURL)
        }
    }

    private var openCard: some View {
        Card(title: "Open a file to edit", systemImage: "square.and.pencil") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Or right-click any file in Finder → **Open With → Qedit** (no spacebar needed). "
                     + "PDFs open in the find/annotate/page editor; everything else in the text editor "
                     + "with ⌘F find.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Text("Supported: " + SupportedFormats.short + ".")
                    .font(.caption).foregroundStyle(.tertiary)
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
        openWindow(id: "editor", value: url.standardizedFileURL)
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
