import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case extensions = "Extensions"
    case setup = "Setup"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .home: return "house"
        case .extensions: return "puzzlepiece.extension"
        case .setup: return "checklist"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var openRequest = OpenEditorRequest.shared
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
            case .extensions: ManagerPlaceholderView()
            case .setup: OnboardingView()
            }
        }
        .frame(minWidth: 840, minHeight: 560)
        .onReceive(openRequest.$pending.compactMap { $0 }) { url in
            openWindow(id: "editor", value: url)
            openRequest.pending = nil
        }
    }
}
