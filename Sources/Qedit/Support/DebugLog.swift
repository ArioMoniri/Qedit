import Foundation

/// In-app debug log so the user can SEE what the troubleshooting buttons actually do
/// (every shell command + its exit code and output is recorded here). All `lines` mutation
/// is funnelled to the main queue, so SwiftUI observation is safe.
final class DebugLog: ObservableObject, @unchecked Sendable {
    static let shared = DebugLog()

    @Published private(set) var lines: [String] = []
    private let maxLines = 600

    private init() {}

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Callable from any thread (e.g. background shell runs).
    func log(_ message: String) {
        DispatchQueue.main.async { [weak self] in self?.append(message) }
    }

    private func append(_ message: String) {
        let stamp = DebugLog.formatter.string(from: Date())
        for line in message.split(separator: "\n", omittingEmptySubsequences: false) {
            lines.append("[\(stamp)] \(line)")
        }
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
    }

    func clear() { lines.removeAll() }

    var text: String { lines.joined(separator: "\n") }
}
