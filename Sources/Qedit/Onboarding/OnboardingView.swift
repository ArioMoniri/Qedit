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

                // Honest about the Space/Quick Look trade-off.
                Card(title: "Preview on Space (optional)", systemImage: "eye") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("macOS shows **one** Quick Look preview per file type. If you also have "
                             + "QLMarkdown or Syntax Highlight installed, *they* win Space — Qedit’s "
                             + "preview only shows once you turn those off. That’s your call.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button {
                            NotificationCenter.default.post(name: .qeditShowExtensions, object: nil)
                        } label: {
                            Label("Manage previews in Extensions", systemImage: "puzzlepiece.extension")
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
