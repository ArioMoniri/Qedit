import SwiftUI
import UniformTypeIdentifiers

struct ManagerView: View {
    @StateObject private var model = ExtensionManagerModel()
    @State private var inspected: UTIInfo?
    @State private var isDropTargeted = false

    @State private var appUpdate: ReleaseInfo?
    @State private var appUpdateMessage: String?
    @State private var brewMessage: String?
    @State private var checkingUpdates = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                updatesCard
                diagnosticsCard
                inspectorCard
                extensionsCard
            }
            .padding(28)
            .frame(maxWidth: 840, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Extensions")
        .task { if model.extensions.isEmpty { await model.scan() } }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Look Extensions").font(.title2).bold()
                Text("Installed Quick Look **preview** extensions and the file types they claim. "
                     + "macOS won’t let any app enable another app’s extension — use the buttons below "
                     + "to open the approval pane yourself.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await model.scan() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(model.isScanning)
        }
    }

    // MARK: - Updates

    private var updatesCard: some View {
        Card(title: "Updates", systemImage: "arrow.down.circle") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { Task { await checkAppUpdate() } } label: {
                        Label("Check for Qedit Updates", systemImage: "sparkles")
                    }
                    .disabled(checkingUpdates)
                    if UpdateChecker.brewAvailable() {
                        Button { brewMessage = UpdateChecker.brewOutdatedCasks().map(brewSummary) } label: {
                            Label("Check Homebrew Casks", systemImage: "shippingbox")
                        }
                    }
                    if checkingUpdates { ProgressView().controlSize(.small) }
                }
                Text("Qedit checks its own GitHub Releases. For extensions installed via Homebrew, "
                     + "it surfaces `brew outdated --cask` — it can’t update third-party apps it "
                     + "didn’t install.")
                    .font(.caption).foregroundStyle(.secondary)

                Text("Current version: \(UpdateChecker.currentVersion())")
                    .font(.caption).foregroundStyle(.secondary)

                if let update = appUpdate {
                    HStack(spacing: 8) {
                        Image(systemName: update.isNewer ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(update.isNewer ? Color.accentColor : .green)
                        Text(update.isNewer ? "Update available: \(update.name)" : "You’re up to date (\(update.tag)).")
                            .font(.callout)
                        if update.isNewer { Link("Download", destination: update.url).font(.callout) }
                    }
                } else if let message = appUpdateMessage {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }

                if let brew = brewMessage {
                    Text(brew)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsCard: some View {
        Card(title: "Diagnostics", systemImage: "stethoscope") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { Task { await model.resetQuickLookCache() } } label: {
                        Label("Reset Quick Look Cache", systemImage: "arrow.clockwise.circle")
                    }
                    .disabled(model.isScanning)
                    Button { SystemSettings.openExtensions() } label: {
                        Label("Open Login Items & Extensions", systemImage: "gearshape")
                    }
                }
                Text("“Reset” runs `qlmanage -r` and `qlmanage -r cache` to reload generators and "
                     + "clear stale thumbnails — handy after enabling an extension.")
                    .font(.caption).foregroundStyle(.secondary)
                if let diagnostic = model.lastDiagnostic {
                    Text(diagnostic)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - UTI inspector

    private var inspectorCard: some View {
        Card(title: "What previews this file?", systemImage: "doc.viewfinder") {
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
                    .frame(height: 84)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.down.doc").font(.title2)
                            Text("Drop a file here, or").foregroundStyle(.secondary)
                            Button("Choose File…") { chooseFileToInspect() }.buttonStyle(.link)
                        }
                    }
                    .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                        handleDrop(providers)
                    }

                if let info = inspected {
                    inspectorResult(info)
                }
            }
        }
    }

    @ViewBuilder
    private func inspectorResult(_ info: UTIInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("File", info.url.lastPathComponent)
            row("UTI", info.identifier)
            if let mime = info.preferredMIME { row("MIME", mime) }
            if !info.conformsTo.isEmpty { row("Conforms to", info.conformsTo.joined(separator: ", ")) }
            Divider().padding(.vertical, 2)
            if info.claimingExtensions.isEmpty {
                Label("No installed Quick Look extension claims this type — Apple’s built-in "
                      + "preview handles it (this is expected for PDF, images, etc.).",
                      systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Claimed by:").font(.callout).bold()
                ForEach(info.claimingExtensions) { ext in
                    Label("\(ext.displayName ?? ext.identifier) — \(ext.status.label)",
                          systemImage: ext.status.systemImage)
                        .font(.callout)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key).font(.caption).foregroundStyle(.secondary).frame(width: 86, alignment: .leading)
            Text(value).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
        }
    }

    // MARK: - Extensions list

    private var extensionsCard: some View {
        Card(title: "Installed (\(model.extensions.count))", systemImage: "puzzlepiece.extension") {
            if model.isScanning && model.extensions.isEmpty {
                HStack { ProgressView().controlSize(.small); Text("Scanning…").foregroundStyle(.secondary) }
            } else if model.extensions.isEmpty {
                Text("No Quick Look preview extensions found.").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.extensions) { ext in
                        ExtensionRow(ext: ext)
                        if ext.id != model.extensions.last?.id { Divider() }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func checkAppUpdate() async {
        checkingUpdates = true
        appUpdateMessage = nil
        defer { checkingUpdates = false }
        do {
            appUpdate = try await UpdateChecker.latestRelease()
        } catch {
            appUpdate = nil
            appUpdateMessage = error.localizedDescription
        }
    }

    private func brewSummary(_ output: String) -> String {
        output.isEmpty
            ? "All Homebrew casks are up to date."
            : "Outdated casks (run `brew upgrade --cask <name>`):\n\(output)"
    }

    private func chooseFileToInspect() {
        if let url = FileOpener.runOpenPanel() {
            inspected = Diagnostics.inspect(url, among: model.extensions)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                inspected = Diagnostics.inspect(url, among: model.extensions)
            }
        }
        return true
    }
}

private struct ExtensionRow: View {
    let ext: QLExtensionInfo

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                if let path = ext.path {
                    Text(path).font(.caption2).foregroundStyle(.tertiary).textSelection(.enabled)
                }
                if ext.supportedUTIs.isEmpty {
                    Text("No declared QLSupportedContentTypes.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Supported types").font(.caption).bold()
                    Text(ext.supportedUTIs.joined(separator: ", "))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Button {
                    if let path = ext.path {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                } label: { Label("Reveal in Finder", systemImage: "folder") }
                    .controlSize(.small)
                    .disabled(ext.path == nil)
            }
            .padding(.leading, 26).padding(.vertical, 4)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: ext.status.systemImage)
                    .foregroundStyle(statusColor)
                    .help(ext.status.label)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(ext.displayName ?? ext.identifier).bold()
                        if ext.isOwnedByQedit {
                            Text("This app").font(.caption2).padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.tint.opacity(0.2), in: Capsule())
                        }
                    }
                    Text(ext.identifier).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                if !ext.supportedUTIs.isEmpty {
                    Text("\(ext.supportedUTIs.count) type\(ext.supportedUTIs.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var statusColor: Color {
        switch ext.status {
        case .enabled: return .green
        case .disabled: return .red
        case .notEnabled: return .secondary
        }
    }
}
