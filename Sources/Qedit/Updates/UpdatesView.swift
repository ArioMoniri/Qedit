import SwiftUI

struct UpdatesView: View {
    @StateObject private var updater = UpdaterController.shared
    @State private var lastChecked: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Updates").font(.title2).bold()
                    Text("Qedit keeps itself up to date with Sparkle — the native macOS updater.")
                        .foregroundStyle(.secondary)
                }

                Card(title: "Automatic updates", systemImage: "arrow.down.circle") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Check for updates automatically", isOn: Binding(
                            get: { updater.automaticallyChecksForUpdates },
                            set: { updater.setAutomaticChecks($0) }))

                        Button {
                            updater.checkForUpdates()
                            lastChecked = Date()
                        } label: {
                            Label("Check for Updates Now", systemImage: "sparkles")
                                .padding(.horizontal, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .disabled(!updater.canCheckForUpdates)

                        Text("Updates are downloaded, verified against Qedit’s EdDSA key, then "
                             + "installed and relaunched. Every build is Developer-ID signed and notarized.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Card(title: "Details", systemImage: "info.circle") {
                    VStack(alignment: .leading, spacing: 8) {
                        detailRow("Current version", updater.currentVersion)
                        detailRow("Last checked",
                                  lastChecked.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never")
                        detailRow("Update feed", updater.feedURL)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Updates")
        .onAppear { lastChecked = updater.lastUpdateCheckDate }
    }

    private func detailRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(key).font(.caption).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
            Text(value).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            Spacer()
        }
    }
}
