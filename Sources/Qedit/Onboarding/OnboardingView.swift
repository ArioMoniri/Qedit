import SwiftUI

struct OnboardingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set up Qedit").font(.title2).bold()
                    Text("Two one-time steps. macOS requires you to approve extensions yourself — "
                         + "no app can enable another app’s Quick Look extension for you.")
                        .foregroundStyle(.secondary)
                }

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
                                Task.detached {
                                    _ = PluginKitScanner.setEnabled(true, identifier: AppInfo.quickLookBundleIdentifier)
                                }
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

                Card(title: "3 · Try it", systemImage: "checkmark.seal") {
                    Text("Select a Markdown (.md) or source file in Finder and press the space bar. "
                         + "You should see Qedit’s highlighted preview. Then use the Quick Action "
                         + "(right-click → Quick Actions → Open in Qedit) to edit it.")
                        .foregroundStyle(.secondary).font(.callout)
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Setup")
    }
}
