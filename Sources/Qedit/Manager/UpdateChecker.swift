import Foundation

struct ReleaseInfo {
    let tag: String
    let name: String
    let url: URL
    let isNewer: Bool
}

enum UpdateError: LocalizedError {
    case noReleases, parse
    var errorDescription: String? {
        switch self {
        case .noReleases: return "No releases have been published yet."
        case .parse: return "Couldn’t read the release information."
        }
    }
}

/// Update checks: this app via GitHub Releases, and third-party extensions via Homebrew casks.
/// We can update our own app and surface brew-managed updates, but we're explicit that we
/// can't update apps we didn't install.
enum UpdateChecker {
    static let repo = "ArioMoniri/Qedit"

    static func currentVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func latestRelease() async throws -> ReleaseInfo {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Qedit", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            throw UpdateError.noReleases
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let htmlString = json["html_url"] as? String,
              let htmlURL = URL(string: htmlString) else {
            throw UpdateError.parse
        }
        let name = (json["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? tag
        return ReleaseInfo(tag: tag, name: name, url: htmlURL,
                           isNewer: isNewer(tag, than: currentVersion()))
    }

    /// Compares dotted numeric versions, tolerating a leading "v".
    static func isNewer(_ tag: String, than current: String) -> Bool {
        func components(_ string: String) -> [Int] {
            string.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                .split(separator: ".")
                .map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let new = components(tag), cur = components(current)
        for index in 0..<max(new.count, cur.count) {
            let lhs = index < new.count ? new[index] : 0
            let rhs = index < cur.count ? cur[index] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }

    static let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    static func brewAvailable() -> Bool { brewPaths.contains(where: Shell.exists) }

    /// Returns outdated cask names (one per line), "" if all up to date, or nil if no brew.
    static func brewOutdatedCasks() -> String? {
        guard let brew = brewPaths.first(where: Shell.exists) else { return nil }
        let result = Shell.run(brew, ["outdated", "--cask", "--quiet"])
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
