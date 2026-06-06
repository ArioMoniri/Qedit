import Foundation

/// Reads a spreadsheet into rows of string cells. XLSX is unzipped (the host app is unsandboxed,
/// so it can spawn /usr/bin/unzip) and parsed as SpreadsheetML; CSV/TSV are parsed directly.
/// Read-only by design — re-writing XLSX losslessly is infeasible, so we don't pretend to.
enum SpreadsheetReader {
    static func read(_ url: URL) -> [[String]]? {
        switch url.pathExtension.lowercased() {
        case "csv": return readCSV(url, delimiter: ",")
        case "tsv": return readCSV(url, delimiter: "\t")
        case "xlsx": return readXLSX(url)
        default: return nil
        }
    }

    // MARK: - CSV / TSV

    static func readCSV(_ url: URL, delimiter: Character) -> [[String]]? {
        let text = (try? String(contentsOf: url, encoding: .utf8))
            ?? (try? String(contentsOf: url, encoding: .isoLatin1))
        guard let text else { return nil }
        return parseCSV(text, delimiter: delimiter)
    }

    /// RFC-4180-ish parser: handles quoted fields, escaped quotes ("") and embedded newlines.
    static func parseCSV(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { inQuotes = false }
                } else { field.append(c) }
            } else {
                switch c {
                case "\"": inQuotes = true
                case delimiter: row.append(field); field = ""
                case "\n", "\r":
                    if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                    row.append(field); field = ""; rows.append(row); row = []
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }

    // MARK: - XLSX

    private static func readXLSX(_ url: URL) -> [[String]]? {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("qedit-xlsx-\(UInt(bitPattern: url.path.hashValue))")
        try? FileManager.default.removeItem(at: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-o", "-q", url.path, "-d", tmp.path]
        unzip.standardOutput = nil; unzip.standardError = nil
        do { try unzip.run(); unzip.waitUntilExit() } catch { return nil }
        guard unzip.terminationStatus == 0 else { return nil }

        let shared = XLSXParts.sharedStrings(in: tmp)
        guard let sheet = XLSXParts.firstSheetURL(in: tmp) else { return nil }
        return parseSheet(sheet, shared: shared)
    }

    private static func parseSheet(_ url: URL, shared: [String]) -> [[String]]? {
        guard let doc = try? XMLDocument(contentsOf: url),
              let rowNodes = try? doc.nodes(forXPath: "//*[local-name()='row']") else { return nil }
        var grid: [[String]] = []
        var maxCols = 0
        for rowNode in rowNodes {
            let cells = (try? rowNode.nodes(forXPath: "./*[local-name()='c']")) ?? []
            var dict: [Int: String] = [:]
            for cell in cells {
                guard let el = cell as? XMLElement else { continue }
                let col = columnIndex(fromRef: el.attribute(forName: "r")?.stringValue ?? "")
                let type = el.attribute(forName: "t")?.stringValue
                let raw = ((try? el.nodes(forXPath: "./*[local-name()='v']"))?.first?.stringValue) ?? ""
                var value = raw
                if type == "s", let idx = Int(raw), idx >= 0, idx < shared.count {
                    value = shared[idx]
                } else if type == "inlineStr" {
                    let ts = (try? el.nodes(forXPath: ".//*[local-name()='t']")) ?? []
                    value = ts.compactMap { $0.stringValue }.joined()
                }
                dict[col] = value
                maxCols = max(maxCols, col + 1)
            }
            let width = max(maxCols, (dict.keys.max() ?? -1) + 1)
            grid.append((0..<width).map { dict[$0] ?? "" })
        }
        // Pad every row to the widest, so columns line up.
        return grid.map { $0 + Array(repeating: "", count: max(0, maxCols - $0.count)) }
    }

    /// "A1" → 0, "B7" → 1, "AA1" → 26.
    private static func columnIndex(fromRef ref: String) -> Int {
        var col = 0
        for ch in ref {
            guard let a = ch.asciiValue else { break }
            if a >= 65, a <= 90 { col = col * 26 + Int(a - 64) }
            else if a >= 97, a <= 122 { col = col * 26 + Int(a - 96) }
            else { break }
        }
        return max(0, col - 1)
    }
}
