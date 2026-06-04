import SwiftUI

struct OnboardingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set up Qedit").font(.title2).bold()
                    Text("Grant the permissions below, then you’re ready. Qedit previews and edits "
                         + SupportedFormats.short + ".")
                        .foregroundStyle(.secondary)
                }

                PermissionsCard()

                Card(title: "1 · Keep Qedit in Applications", systemImage: "app.badge") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("macOS only registers the Quick Look and Quick Action extensions for an "
                             + "app it can find — ideally in /Applications. Move Qedit there if you "
                             + "ran it from Downloads.")
                            .foregroundStyle(.secondary).font(.callout)
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                        } label: {
                            Label("Reveal Qedit in Finder", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle)
                        .controlSize(.large)
                    }
                }

                Card(title: "2 · Enable the Quick Look preview extension", systemImage: "eye") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Click Enable below. If macOS still doesn’t show the preview, open "
                             + "System Settings → General → Login Items & Extensions → Quick Look and "
                             + "switch on “Qedit Preview” (the one-time approval some macOS versions require).")
                            .foregroundStyle(.secondary).font(.callout)
                        HStack {
                            Button {
                                Task.detached { _ = Diagnostics.enableAllQeditExtensions() }
                            } label: {
                                Label("Enable Qedit Preview", systemImage: "power")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle)
                            .controlSize(.large)
                            Button {
                                SystemSettings.openExtensions()
                            } label: {
                                Label("Open Settings", systemImage: "gearshape")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle)
                            .controlSize(.large)
                        }
                    }
                }

                Card(title: "3 · Preview, then edit", systemImage: "checkmark.seal") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("**Preview (read):** select a file in Finder and press Space for Qedit’s "
                             + "highlighted preview. Previews are read-only (a macOS rule) — no edit or "
                             + "find in the preview itself.")
                            .foregroundStyle(.secondary).font(.callout)
                        Text("**Edit & find (no Space needed):** right-click → **Open With → Qedit**, or "
                             + "select the file and press **⌥⌘E**. That opens the editor, where **⌘F** "
                             + "finds and you can change & save in place.")
                            .foregroundStyle(.secondary).font(.callout)
                        Text("**Previews:** " + SupportedFormats.preview)
                            .font(.caption).foregroundStyle(.tertiary)
                        Text("**Editor:** " + SupportedFormats.edit)
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Setup")
    }
}
