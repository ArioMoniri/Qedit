import SwiftUI

/// One-stop card to request/open every macOS permission Qedit needs, with status.
struct PermissionsCard: View {
    @State private var automation: PermissionState = .unknown
    @State private var lastAction: String?

    var body: some View {
        Card(title: "Permissions", systemImage: "lock.shield") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Qedit needs a couple of one-time macOS approvals. Grant them right here.")
                    .font(.callout).foregroundStyle(.secondary)

                // 1 — Finder automation (powers the ⌥⌘E hotkey)
                permissionRow(
                    icon: automation.systemImage,
                    iconColor: automation.color,
                    title: "Control Finder — for the ⌥⌘E hotkey",
                    detail: "Lets the global hotkey read which file is selected in Finder. Status: \(automation.label).",
                    primary: ("Allow", { grantAutomation() }),
                    secondary: ("Settings…", { Permissions.openAutomationSettings() }))

                Divider()

                // 2 — Quick Look preview + Quick Action + Open With registration
                permissionRow(
                    icon: "eye",
                    iconColor: .accentColor,
                    title: "Quick Look preview + “Open With Qedit”",
                    detail: "Turns on the preview and Quick Action and registers Qedit for Open With.",
                    primary: ("Enable", { enableExtensions() }),
                    secondary: ("Settings…", { SystemSettings.openExtensions() }))

                Divider()

                HStack(spacing: 14) {
                    Button("Accessibility…") { Permissions.openAccessibilitySettings() }
                    Button("Full Disk Access…") { Permissions.openFullDiskSettings() }
                    Spacer()
                    Button { refresh() } label: { Label("Re-check", systemImage: "arrow.clockwise") }
                }
                .controlSize(.small)
                .buttonStyle(.link)

                if let lastAction {
                    Text(lastAction).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { refresh() }
    }

    @ViewBuilder
    private func permissionRow(icon: String, iconColor: Color, title: String, detail: String,
                               primary: (String, () -> Void),
                               secondary: (String, () -> Void)) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(iconColor).font(.title3).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).bold()
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 6) {
                Button(primary.0) { primary.1() }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                Button(secondary.0) { secondary.1() }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.small)
            }
        }
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

    private func enableExtensions() {
        lastAction = "Enabling… (see the Debug Log in Extensions for details)"
        Task.detached { _ = Diagnostics.enableAllQeditExtensions() }
    }
}
