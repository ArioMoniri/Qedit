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
                } else if Self.isSpreadsheet(url) {
                    SpreadsheetView(url: url)
                } else if Self.isPresentation(url) {
                    PptxView(url: url)
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

    /// Spreadsheets get a read-only cell grid in a full window (tables need room).
    static func isSpreadsheet(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "xlsx"
    }

    /// Presentations get a read-only slide viewer in a full window.
    static func isPresentation(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "pptx"
    }

    /// Types that need a full window (not the Quick Panel) because they have their own chrome.
    static func needsWindow(_ url: URL) -> Bool {
        isPDF(url) || isSpreadsheet(url) || isPresentation(url)
    }

    /// Quick-Panel-able and worth auto-previewing in "follow Finder selection" mode: text/code/
    /// data/rich files, but not the full-window types and not opaque binaries (images, archives).
    static func isTextLike(_ url: URL) -> Bool {
        if needsWindow(url) { return false }
        let rich: Set<String> = ["rtf", "rtfd", "odt", "docx", "doc", "wordml", "webarchive"]
        if rich.contains(url.pathExtension.lowercased()) { return true }
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return true   // no recognized type → most likely an extensionless text file
        }
        let textyTypes: [UTType] = [.text, .plainText, .sourceCode, .script, .shellScript,
                                    .json, .xml, .yaml, .propertyList, .delimitedText, .svg]
        return textyTypes.contains { type.conforms(to: $0) }
    }
}

struct EditorView: View {
    @StateObject private var doc: EditorDocument
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var theme = SyntaxThemeStore.shared
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
            .onAppear { registerActive() }
            .onChange(of: doc.isDirty) { _, _ in registerActive() }
            .onDisappear { ActiveEditor.shared.resign(url: doc.url) }
    }

    /// Publish this document's dirty state + a synchronous save to the shared bridge, so the
    /// Browser / follow-Finder containers can flush unsaved edits before swapping files.
    private func registerActive() {
        let canEdit = doc.isTextEditable
        ActiveEditor.shared.register(url: doc.url, isDirty: canEdit && doc.isDirty) { [doc, appState] in
            guard doc.isTextEditable, doc.isDirty else { return true }
            do { try doc.save(makeBackup: appState.makeBackupBeforeFirstWrite); return true }
            catch { return false }
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
                if appState.showEditorBanners {
                    if doc.isReadOnly {
                        readOnlyBanner
                    } else if doc.richFormatName == "Word document" {
                        wordEditWarningBanner
                    }
                }
                if doc.isRich {
                    // RTF/RTFD/ODT/Word: native formatted rendering (editable when lossless).
                    RichTextView(
                        attributedText: Binding(
                            get: { doc.attributedText },
                            set: { newValue in
                                guard !newValue.isEqual(to: doc.attributedText) else { return }
                                doc.attributedText = newValue
                                doc.isDirty = true
                                doc.scheduleAutoSave()
                            }
                        ),
                        isEditable: !doc.isReadOnly,
                        originalText: doc.originalText,
                        highlightChanges: appState.highlightChanges,
                        changeStyle: appState.changeHighlightStyle,
                        changeColor: theme.activeColors.change
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
                                doc.scheduleAutoSave()
                            }
                        ),
                        isEditable: !doc.isReadOnly,
                        language: codeLanguage,
                        originalText: doc.originalText,
                        highlightChanges: appState.highlightChanges,
                        changeStyle: appState.changeHighlightStyle,
                        colors: theme.activeColors
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
            bannerCloseButton
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.12))
    }

    /// Hides editor banners (the setting; re-enable in Settings → Editing).
    private var bannerCloseButton: some View {
        Button { appState.showEditorBanners = false } label: { Image(systemName: "xmark") }
            .buttonStyle(.borderless).controlSize(.small)
            .help("Hide editor banners (turn back on in Settings → Editing)")
    }

    private var wordEditWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
            Text("Editing a Word document — **saving may simplify complex formatting** (tables, images). "
                 + "Qedit keeps a `.bak` on first save (toggle in Settings → Editing).")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            bannerCloseButton
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12))
    }

    /// Files Qedit can't edit as text fall back to a macOS Quick Look preview — which uses EVERY
    /// Quick Look plugin you have installed (QLMarkdown, Syntax Highlight, etc.), so Qedit's window
    /// can show any file type, read-only, instead of a dead end.
    private var binaryNotice: some View {
        VStack(spacing: 0) {
            if appState.showEditorBanners {
                HStack(spacing: 10) {
                    Image(systemName: "eye").foregroundStyle(.secondary)
                    Text("Preview via macOS Quick Look (read-only) — uses every Quick Look plugin you "
                         + "have installed. Qedit can’t edit this type as text; open it in its app to edit.")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button("Open in Default App") { NSWorkspace.shared.open(doc.url) }
                        .controlSize(.small)
                    bannerCloseButton
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.blue.opacity(0.08))
            }
            QLPreview(url: doc.url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
