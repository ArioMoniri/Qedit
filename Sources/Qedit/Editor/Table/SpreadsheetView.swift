import SwiftUI
import AppKit

/// A read-only, native cell grid for XLSX (and CSV/TSV). Cells are individually selectable.
/// Spreadsheets are read-only here on purpose — rewriting XLSX losslessly isn't safe — so a
/// banner points to Numbers/Excel for editing.
struct SpreadsheetView: View {
    let url: URL
    @State private var rows: [[String]] = []
    @State private var loaded = false

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
                                    Text(rows[r][c])
                                        .font(.system(.callout, design: r == 0 ? .default : .monospaced))
                                        .fontWeight(r == 0 ? .semibold : .regular)
                                        .lineLimit(1)
                                        .textSelection(.enabled)
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                        .frame(minWidth: 90, alignment: .leading)
                                        .background(r == 0 ? Color.secondary.opacity(0.12)
                                                    : (r % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05)))
                                        .overlay(Rectangle().stroke(Color.secondary.opacity(0.18), lineWidth: 0.5))
                                }
                            }
                        }
                    }
                    .padding(1)
                }
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationSubtitle("Spreadsheet · Read-only")
        .task {
            let result = await Task.detached { SpreadsheetReader.read(url) }.value
            rows = result ?? []
            loaded = true
        }
    }

    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "tablecells").foregroundStyle(.secondary)
            Text("Spreadsheet — read-only. Select cells and ⌘F find here; "
                 + "open in Numbers or Excel to edit.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button("Open in Default App") { NSWorkspace.shared.open(url) }
                .controlSize(.small)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.green.opacity(0.10))
    }
}
