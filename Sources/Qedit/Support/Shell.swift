import Foundation

/// Runs command-line tools (pluginkit, qlmanage, brew) and captures their output.
/// The host app is unsandboxed (Developer ID), so this is permitted. stdout and stderr
/// are drained concurrently to avoid pipe-buffer deadlocks on large output.
enum Shell {
    struct Result {
        let status: Int32
        let stdout: String
        let stderr: String
        var succeeded: Bool { status == 0 }
    }

    /// Blocking — call from a background queue.
    static func run(_ launchPath: String, _ arguments: [String]) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        var outData = Data(), errData = Data()
        let group = DispatchGroup()
        DispatchQueue.global().async(group: group) {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        }
        DispatchQueue.global().async(group: group) {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        }

        do { try process.run() }
        catch {
            return Result(status: -1, stdout: "", stderr: error.localizedDescription)
        }
        process.waitUntilExit()
        group.wait()

        return Result(status: process.terminationStatus,
                      stdout: String(decoding: outData, as: UTF8.self),
                      stderr: String(decoding: errData, as: UTF8.self))
    }

    /// Whether an executable exists at a path (used to probe for brew, etc.).
    static func exists(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }
}
