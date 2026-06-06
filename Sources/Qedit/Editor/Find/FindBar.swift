import SwiftUI

/// A small find bar overlay reused by the read-only/grid views (XLSX, PPTX) that don't have an
/// NSTextView find. Shows the query field, an "n / N" count, prev/next and close.
struct FindBar: View {
    @Binding var query: String
    let count: Int
    let index: Int            // 1-based index of the current match (0 if none)
    var onNext: () -> Void
    var onPrev: () -> Void
    var onClose: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
            TextField("Find", text: $query)
                .textFieldStyle(.plain).frame(width: 170).focused($focused)
                .onSubmit(onNext)
            Text(count == 0 ? (query.isEmpty ? "" : "0") : "\(index)/\(count)")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .frame(minWidth: 38, alignment: .trailing)
            Button(action: onPrev) { Image(systemName: "chevron.up") }.disabled(count == 0)
            Button(action: onNext) { Image(systemName: "chevron.down") }.disabled(count == 0)
            Button(action: onClose) { Image(systemName: "xmark") }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.secondary.opacity(0.25)))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
        .padding(10)
        .onAppear { focused = true }
        .onExitCommand(perform: onClose)   // Esc
    }
}
