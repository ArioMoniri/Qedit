import Foundation
import Combine
import Sparkle

/// Thin SwiftUI-friendly wrapper around Sparkle's standard updater. Sparkle handles the
/// download, EdDSA signature verification, install, and relaunch; this just exposes the
/// bits the Updates page and the menu command need.
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    private let controller: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates: Bool

    private init() {
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var lastUpdateCheckDate: Date? { controller.updater.lastUpdateCheckDate }

    var feedURL: String { Bundle.main.infoDictionary?["SUFeedURL"] as? String ?? "" }

    /// Show Sparkle's "Check for Updates" flow (its own UI takes over from here).
    func checkForUpdates() { controller.checkForUpdates(nil) }

    func setAutomaticChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = enabled
    }
}
