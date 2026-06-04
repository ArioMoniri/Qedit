import SwiftUI
import AppKit

/// Wrapper resolving the window's optional URL value into a concrete editor.
struct EditorWindowView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                EditorView(url: url)
            } else {
                ContentUnavailableView("No file", systemImage: "doc",
                                       description: Text("Open a file from the dashboard or Finder."))
            }
        }
    }
}

struct EditorView: View {
    @StateObject private var doc: EditorDocument
    @EnvironmentObject private var appState: AppState
    @State private var errorMessage: String?

    init(url: URL) {
        _doc = StateObject(wrappedValue: EditorDocument(url: url))
    }

    var body: some View {
        content
            .navigationTitle(doc.url.lastPathComponent)
            .navigationSubtitle(statusText)
            .toolbar { toolbarContent }
            .alert("Couldn’t save", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError = doc.loadError {
            ContentUnavailableView("Couldn’t open file", systemImage: "exclamationmark.triangle",
                                   description: Text(loadError))
        } else if doc.isBinary {
            binaryNotice
        } else {
            CodeTextView(
                text: Binding(get: { doc.text }, set: { doc.text = $0; doc.isDirty = true }),
                isEditable: true
            )
        }
    }

    private var binaryNotice: some View {
        VStack(spacing: 16) {
            Image(systemName: doc.url.pathExtension.lowercased() == "pdf" ? "doc.richtext" : "doc.zipper")
                .font(.system(size: 48)).foregroundStyle(.secondary)
            Text(doc.url.pathExtension.lowercased() == "pdf"
                 ? "PDF editing arrives in milestone 2"
                 : "This file isn’t plain text")
                .font(.headline)
            Text("Qedit never changes a file’s format. The dedicated PDFKit editor (find, annotate, "
                 + "page ops, save-in-place) is coming next.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 420)
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([doc.url])
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                save()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!doc.isDirty || !doc.isTextEditable)
            .help("Save in place — original format preserved")
        }
        ToolbarItem(placement: .secondaryAction) {
            Button {
                doc.load()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .help("Discard changes and reload from disk")
        }
        ToolbarItem(placement: .secondaryAction) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([doc.url])
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
        }
    }

    private var statusText: String {
        if doc.isBinary { return doc.kind.displayName }
        var parts = [doc.kind.displayName]
        if doc.isDirty { parts.append("Edited") }
        else if doc.lastSaved != nil { parts.append("Saved") }
        return parts.joined(separator: " · ")
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func save() {
        do {
            try doc.save(makeBackup: appState.makeBackupBeforeFirstWrite)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
