import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Wrapper resolving the window's optional URL value into the right editor: PDFs go to the
/// PDFKit editor (Module B core), everything text-like to the text editor.
struct EditorWindowView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                if Self.isPDF(url) {
                    PDFEditorView(url: url)
                } else {
                    EditorView(url: url)
                }
            } else {
                ContentUnavailableView("No file", systemImage: "doc",
                                       description: Text("Open a file from the dashboard or Finder."))
            }
        }
    }

    static func isPDF(_ url: URL) -> Bool {
        if url.pathExtension.lowercased() == "pdf" { return true }
        if let type = UTType(filenameExtension: url.pathExtension) { return type.conforms(to: .pdf) }
        return false
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
            VStack(spacing: 0) {
                if doc.isReadOnly { readOnlyBanner }
                if doc.isRich {
                    // RTF/RTFD/ODT/Word: native formatted rendering (editable when lossless).
                    RichTextView(
                        attributedText: Binding(
                            get: { doc.attributedText },
                            set: { newValue in
                                guard !newValue.isEqual(to: doc.attributedText) else { return }
                                doc.attributedText = newValue
                                doc.isDirty = true
                            }
                        ),
                        isEditable: !doc.isReadOnly
                    )
                } else {
                    CodeTextView(
                        text: Binding(
                            get: { doc.text },
                            set: { newValue in
                                // Ignore no-op echoes (the text view re-emitting its initial value),
                                // so simply opening a file never marks it "Edited".
                                guard newValue != doc.text else { return }
                                doc.text = newValue
                                doc.isDirty = true
                            }
                        ),
                        isEditable: !doc.isReadOnly,
                        language: codeLanguage
                    )
                }
                editorFooter
            }
        }
    }

    /// Action bar shown under the editor. Lives in the content (not the window toolbar) so it —
    /// and the ⌘S shortcut — work both in a full window AND in the borderless Quick Panel,
    /// which has no window toolbar.
    private var editorFooter: some View {
        HStack(spacing: 10) {
            Text(statusText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            Text("⌘F to find").font(.caption2).foregroundStyle(.tertiary)
            Button { doc.load() } label: { Label("Reload", systemImage: "arrow.clockwise") }
                .help("Discard changes and reload from disk")
            Button { NSWorkspace.shared.activateFileViewerSelecting([doc.url]) } label: {
                Label("Reveal", systemImage: "folder")
            }
            Button { save() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!doc.isDirty || !doc.isTextEditable)
                .help("Save in place — original format preserved")
                .buttonStyle(.borderedProminent)
        }
        .controlSize(.small)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.bar)
    }

    private var readOnlyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye").foregroundStyle(.secondary)
            Text("\(doc.richFormatName ?? "This document") — read-only. Read and **⌘F find** here; "
                 + "Qedit won’t re-save Word formatting (it could drop tables/images). "
                 + "Edit it in its default app. (RTF & OpenDocument files ARE editable here.)")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button("Open in Default App") { NSWorkspace.shared.open(doc.url) }
                .controlSize(.small)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.12))
    }

    private var binaryNotice: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 48)).foregroundStyle(.secondary)
            Text("This file isn’t plain text").font(.headline)
            Text("Qedit never changes a file’s format, and it only edits text and PDF files. "
                 + "Open this one in its default app instead.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 420)
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([doc.url])
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Syntax-coloring language for code/config files (nil = plain text/markdown/log, no coloring).
    private var codeLanguage: String? {
        switch doc.kind {
        case .sourceCode(let lang): return lang ?? "code"
        case .config(let lang): return lang ?? "code"
        default: return nil
        }
    }

    private var statusText: String {
        if doc.isReadOnly { return doc.kindLabel + " · Read-only" }
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
