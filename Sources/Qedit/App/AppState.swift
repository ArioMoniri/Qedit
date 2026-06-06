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

/// How edited text is marked when "highlight my changes" is on.
enum ChangeHighlightStyle: String, CaseIterable, Identifiable {
    case background, underline, color
    var id: String { rawValue }
    var label: String {
        switch self {
        case .background: return "Highlight"
        case .underline: return "Underline"
        case .color: return "Color"
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
    /// When true, closing the last window drops the Dock icon and keeps Qedit running as a
    /// menu-bar background agent (hotkey + Quick Action stay live). When false, it quits.
    @Published var keepRunningInBackground: Bool {
        didSet { UserDefaults.standard.set(keepRunningInBackground, forKey: Self.backgroundKey) }
    }
    /// When true, the ⌥⌘E hotkey opens the file in the fast, Quick-Look-style **Quick Panel**
    /// (editable, in front of Finder). When false, it opens a full editor window.
    @Published var hotkeyOpensQuickPanel: Bool {
        didSet { UserDefaults.standard.set(hotkeyOpensQuickPanel, forKey: Self.quickPanelKey) }
    }
    /// Save edits automatically (after a short pause) instead of requiring ⌘S.
    @Published var autoSave: Bool {
        didSet { UserDefaults.standard.set(autoSave, forKey: Self.autoSaveKey) }
    }
    /// Highlight the parts of the document you've changed since opening it.
    @Published var highlightChanges: Bool {
        didSet { UserDefaults.standard.set(highlightChanges, forKey: Self.highlightChangesKey) }
    }
    /// How to mark changed text.
    @Published var changeHighlightStyle: ChangeHighlightStyle {
        didSet { UserDefaults.standard.set(changeHighlightStyle.rawValue, forKey: Self.changeStyleKey) }
    }

    private static let recentsKey = "qe.recentFiles"
    private static let backupKey = "qe.makeBackupBeforeFirstWrite"
    private static let appearanceKey = "qe.appearance"
    private static let backgroundKey = "qe.keepRunningInBackground"
    private static let quickPanelKey = "qe.hotkeyOpensQuickPanel"
    private static let autoSaveKey = "qe.autoSave"
    private static let highlightChangesKey = "qe.highlightChanges"
    private static let changeStyleKey = "qe.changeHighlightStyle"
    private let maxRecents = 12

    init() {
        if UserDefaults.standard.object(forKey: Self.backupKey) == nil {
            // Off by default: saves are atomic (the file can't be left half-written), so we
            // don't litter `.bak` siblings. Users who want a keepable copy can turn it on.
            self.makeBackupBeforeFirstWrite = false
        } else {
            self.makeBackupBeforeFirstWrite = UserDefaults.standard.bool(forKey: Self.backupKey)
        }
        self.appearance = UserDefaults.standard.string(forKey: Self.appearanceKey)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        self.keepRunningInBackground = UserDefaults.standard.object(forKey: Self.backgroundKey) as? Bool ?? true
        self.hotkeyOpensQuickPanel = UserDefaults.standard.object(forKey: Self.quickPanelKey) as? Bool ?? true
        self.autoSave = UserDefaults.standard.object(forKey: Self.autoSaveKey) as? Bool ?? false
        self.highlightChanges = UserDefaults.standard.object(forKey: Self.highlightChangesKey) as? Bool ?? false
        self.changeHighlightStyle = UserDefaults.standard.string(forKey: Self.changeStyleKey)
            .flatMap(ChangeHighlightStyle.init(rawValue:)) ?? .background
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
