import SwiftUI
import UniformTypeIdentifiers

struct ManagerView: View {
    @StateObject private var model = ExtensionManagerModel()
    @ObservedObject private var debugLog = DebugLog.shared
    @State private var inspected: UTIInfo?
    @State private var isDropTargeted = false
    @State private var showDebugLog = false

    @State private var appUpdate: ReleaseInfo?
    @State private var appUpdateMessage: String?
    @State private var brewMessage: String?
    @State private var checkingUpdates = false

    /// Qedit's own preview extension, if pluginkit sees it.
    private var ownExtension: QLExtensionInfo? {
        model.extensions.first { $0.isOwnedByQedit }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let own = ownExtension, own.status != .enabled { enableQeditBanner(own) }
                if !model.overlappingExtensions.isEmpty { conflictsCard }
                troubleshootCard
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
                     + "Toggle one on/off below — if macOS still ignores it, approve it once in "
                     + "System Settings.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button { Task { await model.setAllEnabled(true) } } label: { Label("Enable All", systemImage: "checkmark.circle") }
                Button(role: .destructive) { Task { await model.setAllEnabled(false) } } label: { Label("Disable All", systemImage: "xmark.circle") }
            } label: {
                Label("Bulk", systemImage: "switch.2")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(model.isScanning || model.extensions.isEmpty)

            Button { Task { await model.scan() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .disabled(model.isScanning)
        }
    }

    private func enableQeditBanner(_ ext: QLExtensionInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.trianglebadge.exclamationmark").font(.title2).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Qedit Preview isn’t active yet").bold()
                Text("Turn it on to preview Markdown, code, logs and config with Space in Finder.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await model.enableQeditExtensions() } } label: {
                Label("Enable", systemImage: "power").padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            Button("Settings…") { SystemSettings.openExtensions() }
                .buttonStyle(.bordered).buttonBorderShape(.capsule)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.tint.opacity(0.3)))
    }

    // MARK: - Conflicts

    private var conflictsCard: some View {
        let competing = !model.competingExtensions.isEmpty
        return Card(title: competing ? "Another extension wins your Space preview"
                                     : "Qedit is set to win these previews",
                    systemImage: competing ? "exclamationmark.2" : "checkmark.seal") {
            VStack(alignment: .leading, spacing: 12) {
                Text(competing
                     ? "macOS shows **one** Quick Look preview per type. The switched-on extensions "
                       + "below also handle types Qedit does, so Space shows *theirs*. Switch one OFF "
                       + "to hand that type to Qedit:"
                     : "These extensions also handle Qedit’s types but are switched off, so Space "
                       + "shows Qedit. Flip one back on anytime — your choice.")
                    .font(.callout).foregroundStyle(.secondary)

                ForEach(model.overlappingExtensions) { ext in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ext.displayName ?? ext.identifier)
                            Text(sharedTypeSummary(ext)).font(.caption2).foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 12)
                        Toggle("", isOn: Binding(
                            get: { ext.status == .enabled },
                            set: { on in Task { await model.setEnabled(on, for: ext) } }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    .padding(.vertical, 4)
                    Divider().opacity(0.4)
                }

                if competing {
                    HStack {
                        Button { Task { await model.disableCompetitors() } } label: {
                            Label("Switch all off — use Qedit", systemImage: "checkmark.seal")
                        }
                        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                        Spacer()
                    }
                }
                Text("This only changes their Quick Look preview — nothing else about those apps. "
                     + "After flipping a switch, give Finder a second (or use Refresh below).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .disabled(model.isScanning)
    }

    private func sharedTypeSummary(_ ext: QLExtensionInfo) -> String {
        guard let own = ownExtension else { return "" }
        let shared = Set(ext.supportedUTIs).intersection(Set(own.supportedUTIs))
        let names = shared.map { uti -> String in
            if uti.contains("markdown") { return "Markdown" }
            if uti.contains("source-code") || uti.contains("script") || uti.contains("source") { return "code" }
            if uti.contains("json") { return "JSON" }
            if uti.contains("yaml") { return "YAML" }
            if uti.contains("xml") || uti.contains("plist") { return "XML" }
            if uti.contains("log") { return "logs" }
            return uti
        }
        return "Also handles: " + Array(Set(names)).sorted().joined(separator: ", ")
    }

    // MARK: - Troubleshoot

    private var troubleshootCard: some View {
        Card(title: "Troubleshoot “Qedit Preview”", systemImage: "wrench.and.screwdriver") {
            VStack(alignment: .leading, spacing: 12) {
                if let status = model.qeditStatus {
                    Label(statusHeadline(status),
                          systemImage: status.isHealthy ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.callout).bold()
                        .foregroundStyle(status.isHealthy ? Color.green : Color.orange)
                    Text(status.report)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    HStack { ProgressView().controlSize(.small); Text("Checking…").foregroundStyle(.secondary) }
                }
                HStack {
                    if model.qeditStatus?.hasDuplicates == true {
                        Button(role: .destructive) { Task { await model.removeDuplicateRegistrations() } } label: {
                            Label("Remove Duplicate(s)", systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                        Button { revealDuplicates() } label: {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                        .buttonStyle(.bordered).buttonBorderShape(.capsule)
                    }
                    Button { Task { await model.refreshFinderAndQuickLook() } } label: {
                        Label("Refresh Finder & Quick Look", systemImage: "arrow.clockwise.circle")
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)
                    Button { Task { await model.reloadDiagnostics() } } label: {
                        Label("Re-check", systemImage: "stethoscope")
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)
                }
                .disabled(model.isScanning)
                Text("A preview fails when the SAME extension is registered twice (e.g. a second copy "
                     + "of Qedit.app in Downloads or a build folder). “Remove Duplicate(s)” clears the "
                     + "registration — but if that extra copy still exists on disk macOS re-adds it, so "
                     + "“Reveal in Finder” lets you delete it for good. Then Refresh Finder & Quick Look.")
                    .font(.caption).foregroundStyle(.secondary)
                if let msg = model.lastDiagnostic {
                    Text(msg).font(.caption2).foregroundStyle(.secondary)
                }

                DisclosureGroup(isExpanded: $showDebugLog) {
                    VStack(alignment: .leading, spacing: 6) {
                        ScrollView {
                            Text(debugLog.lines.isEmpty ? "No activity yet. Use a button above." : debugLog.text)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 160)
                        .padding(8)
                        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
                        HStack {
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(debugLog.text, forType: .string)
                            }
                            Button("Clear") { debugLog.clear() }
                            Spacer()
                        }
                        .controlSize(.small).buttonStyle(.bordered).buttonBorderShape(.capsule)
                    }
                    .padding(.top, 6)
                } label: {
                    Label("Debug log (\(debugLog.lines.count))", systemImage: "terminal")
                        .font(.callout)
                }
            }
        }
    }

    private func revealDuplicates() {
        guard let dupes = model.qeditStatus?.duplicatePaths, !dupes.isEmpty else { return }
        let urls = dupes.map { path -> URL in
            var bundle = URL(fileURLWithPath: path)        // …/Qedit.app/Contents/PlugIns/X.appex
            for _ in 0..<3 { bundle.deleteLastPathComponent() }  // → …/Qedit.app
            return bundle.pathExtension == "app" ? bundle : URL(fileURLWithPath: path)
        }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func statusHeadline(_ status: QeditPreviewStatus) -> String {
        if status.registrations.isEmpty { return "Not registered — keep Qedit in /Applications and launch it once" }
        if status.hasDuplicates { return "Duplicate registrations — previews can’t resolve" }
        if !status.isEnabledSomewhere { return "Registered, but not enabled" }
        return "Healthy"
    }

    // MARK: - Updates

    private var updatesCard: some View {
        Card(title: "Updates", systemImage: "arrow.down.circle") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { Task { await checkAppUpdate() } } label: {
                        Label("Check for Qedit Updates", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(checkingUpdates)
                    if UpdateChecker.brewAvailable() {
                        Button { brewMessage = UpdateChecker.brewOutdatedCasks().map(brewSummary) } label: {
                            Label("Check Homebrew Casks", systemImage: "shippingbox")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
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
        Card(title: "System Settings", systemImage: "gearshape") {
            VStack(alignment: .leading, spacing: 10) {
                Button { SystemSettings.openExtensions() } label: {
                    Label("Open Login Items & Extensions", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                Text("Some first-time activations need a one-time approval here: System Settings → "
                     + "General → Login Items & Extensions → Quick Look. No app can flip that switch for you.")
                    .font(.caption).foregroundStyle(.secondary)
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
                        ExtensionRow(ext: ext) { enabled in
                            Task { await model.setEnabled(enabled, for: ext) }
                        }
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
    let onSetEnabled: (Bool) -> Void

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
                if ext.status == .enabled {
                    Button("Disable") { onSetEnabled(false) }
                        .controlSize(.small).buttonStyle(.bordered).buttonBorderShape(.capsule)
                } else {
                    Button("Enable") { onSetEnabled(true) }
                        .controlSize(.small).buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
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
