import SwiftUI

/// Placeholder for Module C (the Quick Look Extension Manager). The real enumeration +
/// diagnostics (pluginkit, qlmanage -r, UTI inspector, brew/GitHub updates) land in
/// milestone 3; this keeps the navigation structure stable until then.
struct ManagerPlaceholderView: View {
    private let upcoming = [
        ("list.bullet.rectangle", "List installed Quick Look extensions and the UTIs they claim"),
        ("arrow.clockwise", "Reset the Quick Look cache (qlmanage -r) and re-register"),
        ("doc.viewfinder", "Drop a file to see its UTI and which extension would preview it"),
        ("arrow.down.circle", "Check for updates (Homebrew casks + this app’s GitHub Releases)")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Extensions Manager").font(.title2).bold()
                    Text("Arriving in milestone 3.").foregroundStyle(.secondary)
                }
                Card(title: "Planned", systemImage: "puzzlepiece.extension") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(upcoming, id: \.1) { icon, text in
                            Label(text, systemImage: icon)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Extensions")
    }
}
