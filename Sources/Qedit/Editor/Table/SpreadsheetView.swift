import SwiftUI
import AppKit

/// A native cell grid for XLSX (and CSV/TSV). Cells are selectable; when spreadsheet editing is
/// turned on (Settings → Editing) the cells are editable and a Save button writes the values back
/// into the .xlsx in place (values only — formulas/styles are dropped, hence opt-in).
struct SpreadsheetView: View {
    let url: URL
    @EnvironmentObject private var appState: AppState
    @State private var rows: [[String]] = []
    @State private var loaded = false
    @State private var dirty = false
    @State private var saveError: String?

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
                ScrollView([.horizontal, .vertical]) {
                    Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(rows.indices, id: \.self) { r in
                            GridRow {
                                ForEach(rows[r].indices, id: \.self) { c in
                                    cell(r, c)
                                }
                            }
                        }
                    }
                    .padding(1)
                }
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationSubtitle(editable ? "Spreadsheet · Editable" : "Spreadsheet · Read-only")
        .task {
            let result = await Task.detached { SpreadsheetReader.read(url) }.value
            rows = result ?? []
            loaded = true
        }
    }

    @ViewBuilder
    private func cell(_ r: Int, _ c: Int) -> some View {
        let bg = r == 0 ? Color.secondary.opacity(0.12)
            : (r % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
        Group {
            if editable {
                TextField("", text: Binding(
                    get: { rows[r][c] },
                    set: { rows[r][c] = $0; dirty = true }
                ))
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

    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "tablecells").foregroundStyle(.secondary)
            if editable {
                Text("Editing cells — **Save** writes values back to the `.xlsx` (formulas/styles are dropped).")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Spreadsheet — read-only. Turn on cell editing in Settings → Editing, or open in Numbers/Excel.")
                    .font(.callout).foregroundStyle(.secondary)
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
        .background(.green.opacity(0.10))
        .overlay(alignment: .bottomLeading) {
            if let saveError {
                Text(saveError).font(.caption).foregroundStyle(.red)
                    .padding(.horizontal, 14).padding(.bottom, 2)
            }
        }
    }

    private func save() {
        // Editing a spreadsheet is risky — always take a safety copy first (respecting the .bak
        // preference), then write the minimal-diff back.
        if appState.makeBackupBeforeFirstWrite { try? FileBackup.make(for: url) }
        if SpreadsheetWriter.write(rows, to: url) {
            dirty = false; saveError = nil
        } else {
            saveError = "Couldn’t save — this workbook has a structure Qedit can’t safely edit yet. "
                + "Open it in Numbers/Excel."
        }
    }
}
