import Foundation

/// Writes an edited cell grid back into an existing .xlsx, in place. It unzips the original,
/// replaces ONLY `xl/worksheets/sheet1.xml` with the edited values (as inline strings), and
/// re-zips — every other part of the workbook (other sheets, styles, docProps) is preserved.
/// Lossy by design for sheet 1: cell formulas/number-formats become plain values. Opt-in.
enum SpreadsheetWriter {
    @discardableResult
    static func write(_ grid: [[String]], to url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "xlsx" else { return false }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("qedit-xlsxw-\(UInt(bitPattern: url.path.hashValue))")
        try? FileManager.default.removeItem(at: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        guard run("/usr/bin/unzip", ["-o", "-q", url.path, "-d", tmp.path]) else { return false }
        let sheet = tmp.appendingPathComponent("xl/worksheets/sheet1.xml")
        guard FileManager.default.fileExists(atPath: sheet.path) else { return false }

        let xml = sheetXML(from: grid)
        guard (try? xml.data(using: .utf8)?.write(to: sheet, options: .atomic)) != nil else { return false }

        // Re-zip the workbook with clean relative paths (no "./" prefix) into a temp file.
        let out = tmp.appendingPathComponent("out.xlsx")
        let script = "cd \(shellQuote(tmp.path)) && /usr/bin/find . -type f ! -name out.xlsx "
            + "| /usr/bin/sed 's|^\\./||' | /usr/bin/zip -X -q \(shellQuote(out.path)) -@"
        guard run("/bin/sh", ["-c", script]), FileManager.default.fileExists(atPath: out.path) else { return false }

        // Replace the original atomically.
        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: out)
            return true
        } catch {
            return (try? FileManager.default.removeItem(at: url)) != nil
                && (try? FileManager.default.copyItem(at: out, to: url)) != nil
        }
    }

    private static func sheetXML(from grid: [[String]]) -> String {
        var rows = ""
        for (r, row) in grid.enumerated() {
            var cells = ""
            for (c, value) in row.enumerated() where !value.isEmpty {
                let ref = "\(columnLetters(c))\(r + 1)"
                cells += "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(value))</t></is></c>"
            }
            if !cells.isEmpty { rows += "<row r=\"\(r + 1)\">\(cells)</row>" }
        }
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            + "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">"
            + "<sheetData>\(rows)</sheetData></worksheet>"
    }

    /// 0 → "A", 25 → "Z", 26 → "AA".
    private static func columnLetters(_ index: Int) -> String {
        var n = index, s = ""
        repeat {
            s = String(UnicodeScalar(UInt8(65 + n % 26))) + s
            n = n / 26 - 1
        } while n >= 0
        return s
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = nil; p.standardError = nil
        do { try p.run(); p.waitUntilExit() } catch { return false }
        return p.terminationStatus == 0
    }
}
