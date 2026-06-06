import SwiftUI
import PDFKit
import AppKit
import UniformTypeIdentifiers

struct PDFEditorView: View {
    @StateObject private var model: PDFEditorModel
    @EnvironmentObject private var appState: AppState
    @State private var showFind = false
    @State private var showSignature = false
    @State private var errorMessage: String?

    init(url: URL) {
        _model = StateObject(wrappedValue: PDFEditorModel(url: url))
    }

    var body: some View {
        Group {
            if let loadError = model.loadError {
                ContentUnavailableView("Couldn’t open PDF", systemImage: "doc.richtext",
                                       description: Text(loadError))
            } else {
                HSplitView {
                    PDFThumbnailList(model: model)
                        .frame(minWidth: 132, idealWidth: 150, maxWidth: 240)
                    VStack(spacing: 0) {
                        if showFind { findBar; Divider() }
                        if model.tool == .signature { signatureHint; Divider() }
                        PDFKitView(model: model)
                    }
                }
            }
        }
        .navigationTitle(model.url.lastPathComponent)
        .navigationSubtitle(subtitle)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showSignature) {
            SignatureSheet { path in model.beginSignaturePlacement(path) }
        }
        .alert("Couldn’t save", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .onAppear { registerActive() }
        .onChange(of: model.isDirty) { _, _ in registerActive() }
        .onDisappear { ActiveEditor.shared.resign(url: model.url) }
    }

    /// Publish dirty state + a synchronous save to the shared bridge for the Browser / follow-Finder.
    private func registerActive() {
        ActiveEditor.shared.register(url: model.url, isDirty: model.isDirty) { [model, appState] in
            guard model.isDirty else { return true }
            do { try model.save(makeBackup: appState.makeBackupBeforeFirstWrite); return true }
            catch { return false }
        }
    }

    // MARK: - Find bar

    private var findBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Find in PDF", text: $model.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
                .onSubmit { model.performSearch() }
            if !model.matches.isEmpty {
                Text("\(model.currentMatchIndex + 1) of \(model.matches.count)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            } else if !model.searchText.isEmpty {
                Text("No matches").font(.caption).foregroundStyle(.secondary)
            }
            Button { model.previousMatch() } label: { Image(systemName: "chevron.up") }
                .disabled(model.matches.isEmpty)
            Button { model.nextMatch() } label: { Image(systemName: "chevron.down") }
                .disabled(model.matches.isEmpty)
            Spacer()
            Button("Done") { showFind = false; model.clearSearch(); model.searchText = "" }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private var signatureHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.point.up.left").foregroundStyle(.tint)
            Text("Click on the page to place your signature.").font(.callout)
            Spacer()
            Button("Cancel") { model.clearPendingSignature() }.controlSize(.small)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.tint.opacity(0.1))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            ForEach(PDFTool.pickable) { tool in
                Toggle(isOn: toolBinding(tool)) {
                    Label(tool.label, systemImage: tool.systemImage)
                }
                .toggleStyle(.button)
                .help(tool.label)
            }
            ColorPicker("Annotation color", selection: $model.inkColor, supportsOpacity: false)
                .labelsHidden()
            Button { showSignature = true } label: { Label("Signature", systemImage: "signature") }
                .help("Draw a signature and place it on the page")
        }

        ToolbarItemGroup(placement: .automatic) {
            Button { showFind.toggle() } label: { Label("Find", systemImage: "magnifyingglass") }
                .keyboardShortcut("f", modifiers: .command)
                .help("Find in PDF")

            Menu {
                Button("Copy All as Plain Text") { model.copyAllAsPlainText() }
                Button("Copy Selection as Plain Text") { model.copySelectionAsPlainText() }
            } label: { Label("Copy Text", systemImage: "doc.on.clipboard") }

            Button {
                if !model.replaceSelectedText() { NSSound.beep() }
            } label: { Label("Replace Text", systemImage: "character.cursor.ibeam") }
                .help("Select text in the PDF, then Replace Text — covers it and lets you type a correction over it (double-click to edit; overlay, not reflow).")

            Menu {
                Button { model.rotateCurrentPage(by: -90) } label: { Label("Rotate Left", systemImage: "rotate.left") }
                Button { model.rotateCurrentPage(by: 90) } label: { Label("Rotate Right", systemImage: "rotate.right") }
                Divider()
                Button { model.movePage(at: model.currentPageIndex(), by: -1) } label: { Label("Move Page Up", systemImage: "arrow.up") }
                Button { model.movePage(at: model.currentPageIndex(), by: 1) } label: { Label("Move Page Down", systemImage: "arrow.down") }
                Divider()
                Button { model.insertBlankPageAfterCurrent() } label: { Label("Insert Blank Page", systemImage: "doc.badge.plus") }
                Button { insertFromFile() } label: { Label("Insert Pages from PDF…", systemImage: "doc.on.doc") }
                Button { extractPage() } label: { Label("Extract Current Page…", systemImage: "square.and.arrow.up") }
                Divider()
                Button(role: .destructive) { model.deleteCurrentPage() } label: { Label("Delete Current Page", systemImage: "trash") }
                    .disabled(model.pageCount <= 1)
            } label: { Label("Pages", systemImage: "doc.on.doc") }

            Button { NSWorkspace.shared.activateFileViewerSelecting([model.url]) } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Menu {
                Button("Save") { save() }
                    .keyboardShortcut("s", modifiers: .command)
                Divider()
                Button("Save & Flatten (for printing/sharing)…") { save(flatten: true) }
                    .help("Burn highlights, notes and replacement text into the page so every viewer "
                          + "shows them. Flattened edits can’t be moved later, and text under a "
                          + "replacement is hidden, not removed.")
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            } primaryAction: {
                save()
            }
            .menuStyle(.button)
            .disabled(!model.isDirty)
            .help("Save in place — stays a .pdf")
        }
    }

    // MARK: - Helpers

    private func toolBinding(_ tool: PDFTool) -> Binding<Bool> {
        Binding(get: { model.tool == tool },
                set: { if $0 { model.tool = tool } else if model.tool == tool { model.tool = .select } })
    }

    private var subtitle: String {
        var parts = ["PDF · \(model.pageCount) page\(model.pageCount == 1 ? "" : "s")"]
        if model.isDirty { parts.append("Edited") }
        else if model.lastSaved != nil { parts.append("Saved") }
        return parts.joined(separator: " · ")
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func save(flatten: Bool = false) {
        do { try model.save(makeBackup: appState.makeBackupBeforeFirstWrite, flatten: flatten) }
        catch { errorMessage = error.localizedDescription }
    }

    private func insertFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { model.insertPages(from: url) }
    }

    private func extractPage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(model.url.deletingPathExtension().lastPathComponent)-page-\(model.currentPageIndex() + 1).pdf"
        if panel.runModal() == .OK, let dest = panel.url {
            if !model.extractCurrentPage(to: dest) { errorMessage = "Couldn’t extract the page." }
        }
    }
}

/// PDFKit thumbnail sidebar, bound to the model's shared PDFView for navigation.
struct PDFThumbnailList: NSViewRepresentable {
    let model: PDFEditorModel

    func makeNSView(context: Context) -> PDFThumbnailView {
        let thumb = PDFThumbnailView()
        thumb.pdfView = model.pdfView
        thumb.thumbnailSize = NSSize(width: 96, height: 124)
        thumb.backgroundColor = .clear
        return thumb
    }

    func updateNSView(_ nsView: PDFThumbnailView, context: Context) {
        nsView.pdfView = model.pdfView
    }
}
