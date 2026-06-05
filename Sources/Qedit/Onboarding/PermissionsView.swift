import SwiftUI

/// The single optional permission Qedit can use: controlling Finder so the ⌥⌘E hotkey can
/// read the selected file. Everything else (Open With, the editor) works without it.
struct PermissionsCard: View {
    @State private var automation: PermissionState = .unknown
    @State private var lastAction: String?

    var body: some View {
        Card(title: "Optional: ⌥⌘E hotkey", systemImage: "lock.shield") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: automation.systemImage)
                    .foregroundStyle(automation.color).font(.title3).frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Control Finder").bold()
                    Text("Lets the **⌥⌘E** hotkey open whatever file is selected in Finder. "
                         + "Optional — Open With → Qedit works without it. Status: \(automation.label).")
                        .font(.callout).foregroundStyle(.secondary)
                    if let lastAction {
                        Text(lastAction).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(spacing: 6) {
                    Button("Allow") { grantAutomation() }
                        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    Button("Settings…") { Permissions.openAutomationSettings() }
                        .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
                }
            }
        }
        .onAppear { refresh() }
    }

    private func refresh() {
        DispatchQueue.global().async {
            let state = Permissions.finderAutomation(prompt: false)
            DispatchQueue.main.async { automation = state }
        }
    }

    private func grantAutomation() {
        Permissions.requestFinderAutomation { state in
            automation = state
            lastAction = "Finder control: \(state.label)"
        }
    }
}
