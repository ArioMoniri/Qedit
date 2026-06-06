import SwiftUI
import AppKit

/// The Qedit Browser: a Finder-style folder list on the left and a LIVE, EDITABLE editor on the
/// right. Clicking a file opens it for editing immediately — no Space, no hotkey, no extra click.
///
/// This is the legitimate macOS answer to "edit the file in the preview": Apple's Quick Look
/// preview region (Space / Finder's preview pane) is read-only and receives no keystrokes, so no
/// app can edit there. This window is Qedit's OWN pane, where the right side is a real editor that
/// reuses every existing per-type editor (text, rich, spreadsheet, PDF, presentation) plus ⌘F and
/// save-in-place. Switching files while you have unsaved edits asks before discarding them.
struct BrowserView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var model = BrowserModel()
    @ObservedObject private var active = ActiveEditor.shared

    /// A file the user clicked while the current editor has unsaved edits — held until they
    /// resolve the Save / Discard / Cancel prompt.
    @State private var pendingSwitch: URL?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 420)
        } detail: {
            detail
        }
        .frame(minWidth: 900, minHeight: 560)
        .confirmationDialog(
            "Save changes to “\(active.url?.lastPathComponent ?? "this file")” before switching?",
            isPresented: pendingBinding, titleVisibility: .visible
        ) {
            Button("Save") { resolvePending(save: true) }
            Button("Discard Changes", role: .destructive) { resolvePending(save: false) }
            Button("Cancel", role: .cancel) { pendingSwitch = nil }
        } message: {
            Text("You edited this file but haven’t saved it yet.")
        }
    }

    // MARK: - Sidebar (folder list)

    private var sidebar: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if model.entries.isEmpty {
                ContentUnavailableView("Empty folder", systemImage: "folder",
                                       description: Text("Nothing to edit here."))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.entries) { entry in
                        row(entry)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button { model.goUp() } label: { Image(systemName: "chevron.up") }
                    .disabled(!model.canGoUp).help("Go to the enclosing folder")
                Button { model.chooseFolder() } label: { Label("Choose Folder…", systemImage: "folder") }
                    .controlSize(.small)
                Spacer()
                Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh")
            }
            if let folder = model.folder {
                Text(folder.path)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
                    .help(folder.path)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
    }

    @ViewBuilder
    private func row(_ entry: BrowserModel.Entry) -> some View {
        let isLoaded = entry.url.standardizedFileURL == model.loadedURL?.standardizedFileURL
        Button {
            if entry.isDirectory { model.setFolder(entry.url) }
            else { requestLoad(entry.url) }
        } label: {
            HStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: entry.url.path))
                    .resizable().frame(width: 18, height: 18)
                Text(entry.name).lineLimit(1)
                Spacer(minLength: 4)
                if entry.isDirectory {
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                } else if isLoaded && active.isDirty {
                    Circle().fill(.orange).frame(width: 7, height: 7).help("Unsaved changes")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isLoaded ? Color.accentColor.opacity(0.18) : Color.clear)
    }

    // MARK: - Detail (live editor)

    @ViewBuilder
    private var detail: some View {
        if let url = model.loadedURL {
            EditorWindowView(url: url)
                .environmentObject(appState)
                .id(url.standardizedFileURL)
        } else {
            ContentUnavailableView {
                Label("Select a file to edit", systemImage: "sidebar.right")
            } description: {
                Text("Click any file on the left. It opens here ready to edit — find with ⌘F, "
                     + "save in place. No Space, no shortcut needed.")
            }
        }
    }

    // MARK: - Selection + dirty guard

    /// Load `url` into the editor pane, but if the current editor has unsaved edits, ask first.
    private func requestLoad(_ url: URL) {
        if url.standardizedFileURL == model.loadedURL?.standardizedFileURL { return }
        if active.url != nil && active.isDirty {
            pendingSwitch = url
        } else {
            load(url)
        }
    }

    private func load(_ url: URL) {
        model.loadedURL = url
        appState.noteOpened(url)
    }

    private func resolvePending(save: Bool) {
        if save { _ = active.saveNow() }
        if let next = pendingSwitch { load(next) }
        pendingSwitch = nil
    }

    private var pendingBinding: Binding<Bool> {
        Binding(get: { pendingSwitch != nil }, set: { if !$0 { pendingSwitch = nil } })
    }
}
