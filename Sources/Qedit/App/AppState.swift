import Foundation
import Combine
import AppKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// App-wide state: recent files and editor preferences. A shared singleton so the
/// menu commands (which run outside the SwiftUI view environment) can reach it too.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var recentFiles: [URL] = []
    @Published var makeBackupBeforeFirstWrite: Bool {
        didSet { UserDefaults.standard.set(makeBackupBeforeFirstWrite, forKey: Self.backupKey) }
    }
    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
            applyAppearance()
        }
    }

    private static let recentsKey = "qe.recentFiles"
    private static let backupKey = "qe.makeBackupBeforeFirstWrite"
    private static let appearanceKey = "qe.appearance"
    private let maxRecents = 12

    init() {
        if UserDefaults.standard.object(forKey: Self.backupKey) == nil {
            self.makeBackupBeforeFirstWrite = true // safe default: protect real files
        } else {
            self.makeBackupBeforeFirstWrite = UserDefaults.standard.bool(forKey: Self.backupKey)
        }
        self.appearance = UserDefaults.standard.string(forKey: Self.appearanceKey)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        loadRecents()
    }

    /// Apply the chosen appearance to the running app (call once NSApp exists).
    func applyAppearance() {
        NSApp?.appearance = appearance.nsAppearance
    }

    func noteOpened(_ url: URL) {
        let std = url.standardizedFileURL
        recentFiles.removeAll { $0 == std }
        recentFiles.insert(std, at: 0)
        if recentFiles.count > maxRecents {
            recentFiles.removeLast(recentFiles.count - maxRecents)
        }
        saveRecents()
    }

    func clearRecents() {
        recentFiles = []
        saveRecents()
    }

    private func loadRecents() {
        let paths = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
        recentFiles = paths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func saveRecents() {
        UserDefaults.standard.set(recentFiles.map(\.path), forKey: Self.recentsKey)
    }
}
