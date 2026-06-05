import SwiftUI
import AppKit

extension Notification.Name {
    /// Posted (e.g. from Setup) to jump the dashboard to the Extensions tab.
    static let qeditShowExtensions = Notification.Name("qedit.showExtensions")
}

/// Reports the hosting `NSWindow` once the view is in the window hierarchy.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { if let window = view.window { onWindow(window) } }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case extensions = "Extensions"
    case updates = "Updates"
    case setup = "Setup"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .home: return "house"
        case .extensions: return "puzzlepiece.extension"
        case .updates: return "arrow.down.circle"
        case .setup: return "checklist"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var selection: SidebarItem? = .home

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.systemImage).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            switch selection ?? .home {
            case .home: HomeView()
            case .extensions: ManagerView()
            case .updates: UpdatesView()
            case .setup: OnboardingView()
            }
        }
        .frame(minWidth: 840, minHeight: 560)
        .background(WindowAccessor { window in
            EditorLauncher.shared.dashboardWindow = window
        })
        .onReceive(NotificationCenter.default.publisher(for: .qeditShowExtensions)) { _ in
            selection = .extensions
        }
        .onAppear {
            // Give the launcher (URL handler + global hotkey + Dock reopen) ways to open windows.
            EditorLauncher.shared.openEditorWindow = { url in
                openWindow(id: "editor", value: url)
            }
            EditorLauncher.shared.openMainWindow = {
                openWindow(id: "main")
            }
            EditorLauncher.shared.openSettings = {
                openSettings()
            }
        }
    }
}
