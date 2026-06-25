import SwiftUI

struct OnboardingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set up Qedit").font(.title2).bold()
                    Text("Qedit finds and edits any file without changing its format. "
                         + "Here’s the one thing to know, plus an optional permission.")
                        .foregroundStyle(.secondary)
                }

                // The reliable, always-works path: the editor.
                Card(title: "Edit & find — Open With → Qedit", systemImage: "square.and.pencil") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Right-click any file in Finder → **Open With → Qedit** (or select it and "
                             + "press **⌥⌘E**). It opens in Qedit’s editor — **⌘F** finds, and saving "
                             + "writes back in place. No spacebar, no format change.")
                            .font(.callout).foregroundStyle(.secondary)
                        Text("Editor: " + SupportedFormats.short
                             + ". Word, RTF and OpenDocument open read-only for reading & find.")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }

                // Space previews are owned by your own Quick Look plugins now.
                Card(title: "Press Space to preview — handled by your plugins", systemImage: "eye") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Qedit **doesn’t install its own Quick Look preview** — it edits in its own "
                             + "window, so the apps you already have (QLMarkdown, Syntax Highlight, …) "
                             + "keep your Space previews. Qedit instead gives you a **manager** for all "
                             + "of them: enable/disable any plugin, see which one previews a type, and "
                             + "fix conflicts.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button {
                            NotificationCenter.default.post(name: .qeditShowExtensions, object: nil)
                        } label: {
                            Label("Open Quick Look Plugins", systemImage: "puzzlepiece.extension")
                        }
                        .buttonStyle(.bordered).buttonBorderShape(.capsule)
                    }
                }

                PermissionsCard()
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("Setup")
    }
}
