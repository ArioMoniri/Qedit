import Foundation
import AppKit

/// Backs the Qedit Browser window: a Finder-style list of one folder's contents plus the file the
/// user picked to edit. Navigation is column-style (click a folder to descend, ⌘↑ / Up to ascend),
/// which keeps loading lazy and cheap — only the current directory is ever read.
@MainActor
final class BrowserModel: ObservableObject {
    /// The directory whose contents are listed.
    @Published var folder: URL?
    /// Entries in `folder` (sub-folders first, then files), hidden files omitted.
    @Published var entries: [Entry] = []
    /// The file currently loaded in the editor pane.
    @Published var loadedURL: URL?

    struct Entry: Identifiable, Hashable {
        let url: URL
        let isDirectory: Bool
        var id: URL { url }
        var name: String { url.lastPathComponent }
    }

    private static let rootKey = "qe.browserFolderPath"

    init() {
        if let path = UserDefaults.standard.string(forKey: Self.rootKey),
           isDirectory(path) {
            setFolder(URL(fileURLWithPath: path))
        } else {
            setFolder(FileManager.default.homeDirectoryForCurrentUser)
        }
    }

    /// Prompt for a folder to browse.
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Browse"
        panel.message = "Choose a folder to browse and edit files in."
        if panel.runModal() == .OK, let url = panel.url { setFolder(url) }
    }

    func setFolder(_ url: URL) {
        folder = url
        UserDefaults.standard.set(url.path, forKey: Self.rootKey)
        reload()
    }

    /// Go up to the parent directory (no-op at the filesystem root).
    func goUp() {
        guard let folder, folder.path != "/" else { return }
        setFolder(folder.deletingLastPathComponent())
    }

    var canGoUp: Bool { (folder?.path ?? "/") != "/" }

    /// Path components from root to the current folder, for the breadcrumb.
    var breadcrumb: [URL] {
        guard let folder else { return [] }
        var parts: [URL] = []
        var u = folder
        while true {
            parts.insert(u, at: 0)
            let parent = u.deletingLastPathComponent()
            if parent.path == u.path { break }
            u = parent
        }
        return parts
    }

    func reload() {
        guard let folder else { entries = []; return }
        let keys: [URLResourceKey] = [.isDirectoryKey]
        let items = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        entries = items.map { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return Entry(url: url, isDirectory: isDir)
        }
        .sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    private func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}
