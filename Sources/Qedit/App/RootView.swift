import SwiftUI
import AppKit

extension Notification.Name {
    /// Posted (e.g. from Setup) to jump the dashboard to the Extensions tab.
    static let qeditShowExtensions = Notification.Name("qedit.showExtensions")
    /// Posted (from ⌘, / the menu-bar) to jump the dashboard to the Settings tab.
    static let qeditShowSettings = Notification.Name("qedit.showSettings")
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
    case settings = "Settings"
    case extensions = "Quick Look Plugins"
    case updates = "Updates"
    case setup = "Setup"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .home: return "house"
        case .settings: return "gearshape"
        case .extensions: return "puzzlepiece.extension"
        case .updates: return "arrow.down.circle"
        case .setup: return "checklist"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
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
            case .settings: SettingsView()
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
        .onReceive(NotificationCenter.default.publisher(for: .qeditShowSettings)) { _ in
            selection = .settings
        }
        .onAppear {
            // Give the launcher (URL handler + global hotkey + Dock reopen) ways to open windows.
            EditorLauncher.shared.openEditorWindow = { url in
                openWindow(id: "editor", value: url.standardizedFileURL)
            }
            EditorLauncher.shared.openMainWindow = {
                openWindow(id: "main")
            }
            // Settings now lives INSIDE the dashboard — open the window and select the Settings tab.
            EditorLauncher.shared.openSettings = {
                openWindow(id: "main")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(name: .qeditShowSettings, object: nil)
                }
            }
            EditorLauncher.shared.openBrowser = {
                openWindow(id: "browser")
            }
        }
    }
}
