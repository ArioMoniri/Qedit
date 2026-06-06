import Foundation

/// Writes edited slide text back into an existing .pptx, in place, with a MINIMAL DIFF: only the
/// inner text of `<a:t>` runs the user actually changed is rewritten; everything else (formatting,
/// images, layouts, other runs) is left byte-for-byte. We splice the raw slide XML as a string
/// rather than re-serializing via `XMLDocument`, which would expand self-closing DrawingML tags and
/// bloat the whole slide.
///
/// Safety discipline (fail-closed): for each slide the writer re-finds runs with the same regex the
/// reader used; if the count doesn't match the edited model, or the spliced XML doesn't re-parse,
/// or the rebuilt package doesn't re-open, it aborts WITHOUT touching the original file.
enum PptxWriter {
    /// - Parameter slideTexts: slide part name → the FULL ordered list of run texts for that slide
    ///   (same length and order as `PptxParts.matches`). Unchanged runs are preserved verbatim.
    @discardableResult
    static func write(_ slideTexts: [String: [String]], to url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "pptx" else { return false }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("qedit-pptxw-\(UInt(bitPattern: url.path.hashValue))")
        try? FileManager.default.removeItem(at: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        guard run("/usr/bin/unzip", ["-o", "-q", url.path, "-d", tmp.path]) else { return false }

        var anyChange = false
        for (slideName, newTexts) in slideTexts {
            let slideURL = tmp.appendingPathComponent(slideName)
            guard let xml = try? String(contentsOf: slideURL, encoding: .utf8) else { return false }
            let ms = PptxParts.matches(in: xml)
            guard ms.count == newTexts.count else { return false }   // FAIL CLOSED — index mismatch
            guard let spliced = splice(xml: xml, matches: ms, newTexts: newTexts) else { return false }
            if spliced != xml {
                // The edited slide must still be well-formed XML before we commit it.
                guard (try? XMLDocument(xmlString: spliced, options: [])) != nil,
                      let data = spliced.data(using: .utf8),
                      (try? data.write(to: slideURL, options: .atomic)) != nil else { return false }
                anyChange = true
            }
        }
        guard anyChange else { return true }   // nothing actually changed → leave original alone

        let out = tmp.appendingPathComponent("out.pptx")
        let script = "cd \(quote(tmp.path)) && /usr/bin/find . -type f ! -name out.pptx "
            + "! -name '.DS_Store' ! -path './__MACOSX/*' "
            + "| /usr/bin/sed 's|^\\./||' | /usr/bin/zip -X -q \(quote(out.path)) -@"
        guard run("/bin/sh", ["-c", script]), FileManager.default.fileExists(atPath: out.path) else { return false }
        // Re-validate the rebuilt package opens as a zip before we replace the original.
        guard run("/usr/bin/unzip", ["-tqq", out.path]) else { return false }
        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: out)
            return true
        } catch { return false }
    }

    /// Rebuild the slide XML, replacing the inner text of only the runs whose text changed. The
    /// i-th match corresponds to the i-th entry of `newTexts` (both in document order).
    private static func splice(xml: String, matches: [NSTextCheckingResult], newTexts: [String]) -> String? {
        let ns = xml as NSString
        var result = ""
        result.reserveCapacity(ns.length + 64)
        var cursor = 0
        for (i, m) in matches.enumerated() {
            let full = m.range
            result += ns.substring(with: NSRange(location: cursor, length: full.location - cursor))
            let original = PptxParts.text(of: m, in: xml)
            let newText = newTexts[i]
            if newText == original {
                result += ns.substring(with: full)   // unchanged → verbatim
            } else {
                let openTag: String
                if m.range(at: 1).location != NSNotFound {
                    openTag = ns.substring(with: m.range(at: 1))           // paired form opening tag
                } else {
                    let selfClosing = ns.substring(with: m.range(at: 3))   // "<a:t …/>" → "<a:t …>"
                    openTag = String(selfClosing.dropLast(2)) + ">"
                }
                result += openTag + PptxParts.xmlEscape(newText) + "</a:t>"
            }
            cursor = full.location + full.length
        }
        result += ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
        return result
    }

    private static func quote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> Bool {
        let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
        p.standardOutput = nil; p.standardError = nil
        do { try p.run(); p.waitUntilExit() } catch { return false }
        return p.terminationStatus == 0
    }
}
