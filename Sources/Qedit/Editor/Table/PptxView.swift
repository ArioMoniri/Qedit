import SwiftUI
import AppKit

/// PowerPoint viewer + opt-in text editor. The slides themselves are always rendered faithfully via
/// the system Quick Look (QLPreviewView) — real layout, images and fonts. When "Edit PowerPoint
/// text" is on (Settings → Editing), a side panel lists the editable lines (simple, single-style
/// titles/bullets); changing one and saving rewrites just that run's text inside the .pptx, in
/// place, and refreshes the rendered slides. Mixed-format or table/chart text stays read-only.
struct PptxView: View {
    let url: URL
    @EnvironmentObject private var appState: AppState
    @StateObject private var doc: PptxDocument

    init(url: URL) {
        self.url = url
        _doc = StateObject(wrappedValue: PptxDocument(url: url))
    }

    private var editing: Bool { appState.allowPptxEditing && doc.hasEditableText }

    var body: some View {
        VStack(spacing: 0) {
            banner
            if editing {
                HSplitView {
                    QLPreview(url: url, refreshToken: doc.previewToken)
                        .frame(minWidth: 360)
                    editPanel
                        .frame(minWidth: 280, idealWidth: 340, maxWidth: 460)
                }
            } else {
                QLPreview(url: url, refreshToken: doc.previewToken)
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationSubtitle(editing ? "Presentation · Text editable" : "Presentation · Read-only")
        .task { doc.load() }
        .onAppear { registerActive() }
        .onChange(of: doc.dirty) { _, _ in registerActive() }
        .onDisappear { ActiveEditor.shared.resign(url: url) }
    }

    // MARK: - Banner

    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle").foregroundStyle(.secondary)
            if editing {
                Text("Editing slide text — change a line on the right and **Save**. Formatting, "
                     + "images and layout are preserved; complex lines stay read-only.")
                    .font(.callout).foregroundStyle(.secondary)
            } else if appState.allowPptxEditing && doc.loaded && !doc.hasEditableText {
                Text("Presentation — no simple text lines to edit here (this deck’s text is in "
                     + "tables/charts or mixed formatting). Open in Keynote/PowerPoint to edit.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Presentation — read-only native preview. Turn on “Edit PowerPoint text” in "
                     + "Settings → Editing, or open in Keynote/PowerPoint.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if editing {
                Button { save() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!doc.dirty).buttonStyle(.borderedProminent).controlSize(.small)
            }
            Button("Open in Default App") { NSWorkspace.shared.open(url) }.controlSize(.small)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((editing ? Color.green : Color.orange).opacity(0.10))
        .overlay(alignment: .bottomLeading) {
            if let saveError = doc.saveError {
                Text(saveError).font(.caption).foregroundStyle(.red)
                    .padding(.horizontal, 14).padding(.bottom, 2)
            }
        }
    }

    // MARK: - Edit panel

    private var editPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(doc.slides) { slide in
                    if !slide.editableIndices.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Slide \(slide.number)")
                                .font(.caption).bold().foregroundStyle(.secondary)
                            ForEach(slide.editableIndices, id: \.self) { ri in
                                TextField("", text: binding(slideID: slide.id, run: ri), axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(1...4)
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(.background)
    }

    private func binding(slideID: String, run ri: Int) -> Binding<String> {
        Binding(
            get: { doc.text(slideID: slideID, run: ri) },
            set: { doc.setText($0, slideID: slideID, run: ri) }
        )
    }

    private func save() {
        doc.save(makeBackup: appState.makeBackupBeforeFirstWrite)
    }

    private func registerActive() {
        guard editing else { ActiveEditor.shared.resign(url: url); return }
        ActiveEditor.shared.register(url: url, isDirty: doc.dirty) { [doc, appState] in
            guard doc.dirty else { return true }
            return doc.save(makeBackup: appState.makeBackupBeforeFirstWrite)
        }
    }
}

/// Loads a .pptx's editable text runs and writes edits back via `PptxWriter`.
@MainActor
final class PptxDocument: ObservableObject {
    let url: URL
    @Published var slides: [Slide] = []
    @Published var loaded = false
    @Published var dirty = false
    @Published var saveError: String?
    /// Bumped after a successful save so the QLPreview re-renders the changed slides.
    @Published var previewToken = 0

    private var didBackup = false

    struct Slide: Identifiable {
        let id: String                 // slide part name, e.g. "ppt/slides/slide1.xml"
        let number: Int
        var runs: [PptxParts.Run]      // ALL a:t runs in order (writer needs the full list)
        let editableIndices: [Int]     // indices into `runs` the UI exposes as text fields
    }

    var hasEditableText: Bool { slides.contains { !$0.editableIndices.isEmpty } }

    init(url: URL) { self.url = url }

    func load() {
        guard !loaded else { return }
        let parsed = Self.readSlides(url)
        slides = parsed
        loaded = true
    }

    func text(slideID: String, run ri: Int) -> String {
        guard let si = slides.firstIndex(where: { $0.id == slideID }),
              slides[si].runs.indices.contains(ri) else { return "" }
        return slides[si].runs[ri].text
    }

    func setText(_ value: String, slideID: String, run ri: Int) {
        guard let si = slides.firstIndex(where: { $0.id == slideID }),
              slides[si].runs.indices.contains(ri) else { return }
        if slides[si].runs[ri].text != value {
            slides[si].runs[ri].text = value
            dirty = true
        }
    }

    @discardableResult
    func save(makeBackup: Bool) -> Bool {
        // PPTX editing is opt-in; always keep one safety copy on the first write of a session,
        // regardless of the global backup setting (the `makeBackup` parameter).
        _ = makeBackup
        if !didBackup {
            try? FileBackup.make(for: url)
            didBackup = true
        }
        var payload: [String: [String]] = [:]
        for slide in slides { payload[slide.id] = slide.runs.map(\.text) }
        if PptxWriter.write(payload, to: url) {
            dirty = false
            saveError = nil
            previewToken += 1
            return true
        } else {
            saveError = "Couldn’t save — this slide has a structure Qedit can’t safely edit. "
                + "Open it in Keynote/PowerPoint."
            return false
        }
    }

    // MARK: - Reading

    private static func readSlides(_ url: URL) -> [Slide] {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("qedit-pptxr-\(UInt(bitPattern: url.path.hashValue))")
        try? FileManager.default.removeItem(at: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        guard runUnzip(url, into: tmp) else { return [] }

        var result: [Slide] = []
        for (n, name) in PptxParts.slideOrder(in: tmp).enumerated() {
            let slideURL = tmp.appendingPathComponent(name)
            guard let xml = try? String(contentsOf: slideURL, encoding: .utf8) else { continue }
            let ms = PptxParts.matches(in: xml)
            guard !ms.isEmpty else { continue }
            let texts = ms.map { PptxParts.text(of: $0, in: xml) }
            let editable = PptxParts.editability(forSlideXML: xml) ?? Array(repeating: false, count: texts.count)
            let runs = zip(texts, editable).map { PptxParts.Run(text: $0.0, editable: $0.1) }
            let editableIndices = runs.indices.filter { runs[$0].editable }
            result.append(Slide(id: name, number: n + 1, runs: runs, editableIndices: editableIndices))
        }
        return result
    }

    private static func runUnzip(_ url: URL, into dir: URL) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-o", "-q", url.path, "-d", dir.path]
        p.standardOutput = nil; p.standardError = nil
        do { try p.run(); p.waitUntilExit() } catch { return false }
        return p.terminationStatus == 0
    }
}
