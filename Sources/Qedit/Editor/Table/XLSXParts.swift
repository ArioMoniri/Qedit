import Foundation

/// Resolves the correct worksheet part inside an unzipped .xlsx. The first tab is NOT always
/// `xl/worksheets/sheet1.xml` — it's whatever `workbook.xml`'s first `<sheet r:id>` points to via
/// `workbook.xml.rels`. Used by both the reader and the writer so they agree on the same part.
enum XLSXParts {
    /// URL of the first worksheet's XML inside `root` (the unzipped package), or nil.
    static func firstSheetURL(in root: URL) -> URL? {
        let xl = root.appendingPathComponent("xl")
        // 1) first <sheet>'s relationship id
        guard let wb = try? XMLDocument(contentsOf: xl.appendingPathComponent("workbook.xml")),
              let sheets = try? wb.nodes(forXPath: "//*[local-name()='sheet']"),
              let first = sheets.first as? XMLElement else {
            return fallback(in: xl)
        }
        let rid = first.attributes?.first { ($0.name ?? "").hasSuffix("id") || $0.localName == "id" }?.stringValue
        // 2) map rId → Target via workbook.xml.rels
        guard let rid,
              let rels = try? XMLDocument(contentsOf: xl.appendingPathComponent("_rels/workbook.xml.rels")),
              let relNodes = try? rels.nodes(forXPath: "//*[local-name()='Relationship']") else {
            return fallback(in: xl)
        }
        for case let rel as XMLElement in relNodes
        where rel.attribute(forName: "Id")?.stringValue == rid {
            if let target = rel.attribute(forName: "Target")?.stringValue {
                let clean = target.hasPrefix("/") ? String(target.dropFirst()) : target
                let url = xl.appendingPathComponent(clean)   // Targets are relative to xl/
                if FileManager.default.fileExists(atPath: url.path) { return url }
            }
        }
        return fallback(in: xl)
    }

    private static func fallback(in xl: URL) -> URL? {
        let s1 = xl.appendingPathComponent("worksheets/sheet1.xml")
        if FileManager.default.fileExists(atPath: s1.path) { return s1 }
        // any worksheet
        let dir = xl.appendingPathComponent("worksheets")
        if let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path),
           let any = names.filter({ $0.hasSuffix(".xml") }).sorted().first {
            return dir.appendingPathComponent(any)
        }
        return nil
    }

    static func sharedStrings(in root: URL) -> [String] {
        let url = root.appendingPathComponent("xl/sharedStrings.xml")
        guard let doc = try? XMLDocument(contentsOf: url),
              let sis = try? doc.nodes(forXPath: "//*[local-name()='si']") else { return [] }
        return sis.map { si in
            let ts = (try? si.nodes(forXPath: ".//*[local-name()='t']")) ?? []
            return ts.compactMap { $0.stringValue }.joined()
        }
    }

    /// "A1" → (row 0, col 0).
    static func cellCoord(_ ref: String) -> (row: Int, col: Int)? {
        var col = 0, i = ref.startIndex
        while i < ref.endIndex, let a = ref[i].asciiValue, a >= 65, a <= 90 {
            col = col * 26 + Int(a - 64); i = ref.index(after: i)
        }
        guard let row = Int(ref[i...]), row > 0, col > 0 else { return nil }
        return (row - 1, col - 1)
    }

    static func columnLetters(_ index: Int) -> String {
        var n = index, s = ""
        repeat { s = String(UnicodeScalar(UInt8(65 + n % 26))) + s; n = n / 26 - 1 } while n >= 0
        return s
    }
}
