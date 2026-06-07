import SwiftUI
import AppKit

/// A native cell grid for XLSX (and CSV/TSV). Cells are selectable; ⌘F finds across cells. When
/// spreadsheet editing is on (Settings → Editing) cells are editable and Save writes values back
/// into the .xlsx in place (values only — formulas/styles dropped, hence opt-in).
struct SpreadsheetView: View {
    let url: URL
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var theme = SyntaxThemeStore.shared
    @State private var rows: [[String]] = []
    @State private var original: [[String]] = []   // on-load snapshot, for change highlighting
    @State private var loaded = false
    @State private var dirty = false
    @State private var saveError: String?

    // Find
    @State private var showFind = false
    @State private var query = ""
    @State private var matches: [Coord] = []
    @State private var matchIdx = 0
    private struct Coord: Equatable { let r: Int; let c: Int }

    private var editable: Bool {
        appState.allowSpreadsheetEditing && url.pathExtension.lowercased() == "xlsx"
    }

    var body: some View {
        VStack(spacing: 0) {
            banner
            if loaded && rows.isEmpty {
                ContentUnavailableView("Couldn’t read this spreadsheet", systemImage: "tablecells",
                                       description: Text("Open it in Numbers or Excel."))
            } else {
                ScrollViewReader { proxy in
                    ScrollView([.horizontal, .vertical]) {
                        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                            ForEach(rows.indices, id: \.self) { r in
                                GridRow {
                                    ForEach(rows[r].indices, id: \.self) { c in
                                        cell(r, c).id("\(r)-\(c)")
                                    }
                                }
                            }
                        }
                        .padding(1)
                    }
                    .onChange(of: matchIdx) { _, _ in scrollToCurrent(proxy) }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if showFind {
                FindBar(query: $query, count: matches.count, index: matches.isEmpty ? 0 : matchIdx + 1,
                        onNext: { step(1) }, onPrev: { step(-1) }, onClose: { showFind = false; query = "" })
            }
        }
        .background(
            Button("") { showFind.toggle() }.keyboardShortcut("f", modifiers: .command).opacity(0)
        )
        .onChange(of: query) { _, _ in recomputeMatches() }
        .navigationTitle(url.lastPathComponent)
        .navigationSubtitle(editable ? "Spreadsheet · Editable" : "Spreadsheet · Read-only")
        .task {
            let result = await Task.detached { SpreadsheetReader.read(url) }.value
            rows = result ?? []
            original = rows
            loaded = true
        }
        .onAppear { registerActive() }
        .onChange(of: dirty) { _, _ in registerActive() }
        .onChange(of: rows) { _, _ in if dirty { registerActive() } }
        .onDisappear { ActiveEditor.shared.resign(url: url) }
    }

    /// Publish a fresh snapshot + save to the shared bridge (re-run on every edit since `rows` is
    /// value-typed, so a save closure must capture the current grid, not a stale one).
    private func registerActive() {
        guard editable else { ActiveEditor.shared.resign(url: url); return }
        let snapshot = rows
        let backup = appState.makeBackupBeforeFirstWrite
        ActiveEditor.shared.register(url: url, isDirty: dirty) {
            if backup { try? FileBackup.make(for: url) }
            return SpreadsheetWriter.write(snapshot, to: url)
        }
    }

    @ViewBuilder
    private func cell(_ r: Int, _ c: Int) -> some View {
        let isMatch = !query.isEmpty && rows[r][c].localizedCaseInsensitiveContains(query)
        let isCurrent = isMatch && !matches.isEmpty && matches[matchIdx] == Coord(r: r, c: c)
        let changed = appState.highlightChanges && cellChanged(r, c)
        let bg: Color = isCurrent ? .orange.opacity(0.5)
            : isMatch ? .yellow.opacity(0.35)
            : changed ? Color(theme.activeColors.change).opacity(0.34)
            : (r == 0 ? .secondary.opacity(0.12) : (r % 2 == 0 ? .clear : .secondary.opacity(0.05)))
        Group {
            if editable {
                TextField("", text: Binding(get: { rows[r][c] }, set: { rows[r][c] = $0; dirty = true }))
                    .textFieldStyle(.plain)
                    .font(.system(.callout, design: r == 0 ? .default : .monospaced))
            } else {
                Text(rows[r][c])
                    .font(.system(.callout, design: r == 0 ? .default : .monospaced))
                    .fontWeight(r == 0 ? .semibold : .regular)
                    .lineLimit(1).textSelection(.enabled)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .frame(minWidth: 90, alignment: .leading)
        .background(bg)
        .overlay(Rectangle().stroke(Color.secondary.opacity(0.18), lineWidth: 0.5))
    }

    /// True when a cell differs from its on-load value (or is a brand-new non-empty cell).
    private func cellChanged(_ r: Int, _ c: Int) -> Bool {
        guard editable else { return false }
        if r < original.count, c < original[r].count { return rows[r][c] != original[r][c] }
        return !rows[r][c].isEmpty
    }

    private func recomputeMatches() {
        guard !query.isEmpty else { matches = []; matchIdx = 0; return }
        var found: [Coord] = []
        for r in rows.indices {
            for c in rows[r].indices where rows[r][c].localizedCaseInsensitiveContains(query) {
                found.append(Coord(r: r, c: c))
            }
        }
        matches = found; matchIdx = 0
    }

    private func step(_ d: Int) {
        guard !matches.isEmpty else { return }
        matchIdx = (matchIdx + d + matches.count) % matches.count
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard !matches.isEmpty else { return }
        let m = matches[matchIdx]
        withAnimation { proxy.scrollTo("\(m.r)-\(m.c)", anchor: .center) }
    }

    private var banner: some View {
        HStack(spacing: 10) {
            if appState.showEditorBanners {
                Image(systemName: "tablecells").foregroundStyle(.secondary)
                Text(editable
                     ? "Editing cells — **Save** writes values back to the `.xlsx`. ⌘F to find."
                     : "Spreadsheet — read-only. **⌘F** to find. Turn on cell editing in Settings → Editing.")
                    .font(.callout).foregroundStyle(.secondary)
                Button { appState.showEditorBanners = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).controlSize(.small)
                    .help("Hide editor banners (turn back on in Settings → Editing)")
            }
            Spacer()
            if editable {
                Button { save() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!dirty).buttonStyle(.borderedProminent).controlSize(.small)
            }
            Button("Open in Default App") { NSWorkspace.shared.open(url) }.controlSize(.small)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appState.showEditorBanners ? Color.green.opacity(0.10) : Color.clear)
        .overlay(alignment: .bottomLeading) {
            if let saveError {
                Text(saveError).font(.caption).foregroundStyle(.red).padding(.horizontal, 14).padding(.bottom, 2)
            }
        }
    }

    private func save() {
        if appState.makeBackupBeforeFirstWrite { try? FileBackup.make(for: url) }
        if SpreadsheetWriter.write(rows, to: url) {
            dirty = false; saveError = nil; original = rows   // saved values are the new baseline
        } else {
            saveError = "Couldn’t save — this workbook has a structure Qedit can’t safely edit yet. "
                + "Open it in Numbers/Excel."
        }
    }
}
