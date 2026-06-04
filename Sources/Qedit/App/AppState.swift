import Foundation
import Combine

/// App-wide state: recent files and editor preferences. A shared singleton so the
/// menu commands (which run outside the SwiftUI view environment) can reach it too.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var recentFiles: [URL] = []
    @Published var makeBackupBeforeFirstWrite: Bool {
        didSet { UserDefaults.standard.set(makeBackupBeforeFirstWrite, forKey: Self.backupKey) }
    }

    private static let recentsKey = "qe.recentFiles"
    private static let backupKey = "qe.makeBackupBeforeFirstWrite"
    private let maxRecents = 12

    init() {
        if UserDefaults.standard.object(forKey: Self.backupKey) == nil {
            self.makeBackupBeforeFirstWrite = true // safe default: protect real files
        } else {
            self.makeBackupBeforeFirstWrite = UserDefaults.standard.bool(forKey: Self.backupKey)
        }
        loadRecents()
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
