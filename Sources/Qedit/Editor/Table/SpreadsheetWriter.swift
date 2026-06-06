import Foundation

/// Writes an edited cell grid back into an existing .xlsx, in place, with a MINIMAL DIFF:
/// only the cells the user actually changed are touched, and each keeps its style index (`s`)
/// and reference (`r`). Numeric-looking values stay numbers; everything else becomes an inline
/// string. Unchanged cells, other sheets, sharedStrings, styles and docProps are left byte-for-
/// byte. Editing a formula cell drops `calcChain.xml` so Excel doesn't show a repair dialog.
enum SpreadsheetWriter {
    @discardableResult
    static func write(_ grid: [[String]], to url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "xlsx" else { return false }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("qedit-xlsxw-\(UInt(bitPattern: url.path.hashValue))")
        try? FileManager.default.removeItem(at: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        guard run("/usr/bin/unzip", ["-o", "-q", url.path, "-d", tmp.path]) else { return false }
        guard let sheetURL = XLSXParts.firstSheetURL(in: tmp),
              let doc = try? XMLDocument(contentsOf: sheetURL) else { return false }
        let shared = XLSXParts.sharedStrings(in: tmp)

        // Index existing cells + their original resolved values.
        guard let cellNodes = try? doc.nodes(forXPath: "//*[local-name()='c']") else { return false }
        var cellByRef: [String: XMLElement] = [:]
        var origByRef: [String: String] = [:]
        for case let c as XMLElement in cellNodes {
            guard let ref = c.attribute(forName: "r")?.stringValue else { continue }
            cellByRef[ref] = c
            origByRef[ref] = resolvedValue(c, shared: shared)
        }

        var changed = false, formulaEdited = false
        for (r, row) in grid.enumerated() {
            for (col, newVal) in row.enumerated() {
                let ref = "\(XLSXParts.columnLetters(col))\(r + 1)"
                if newVal == (origByRef[ref] ?? "") { continue }   // unchanged → leave it alone
                changed = true
                if let c = cellByRef[ref] {
                    if hasFormula(c) { formulaEdited = true }
                    setValue(c, newVal)
                } else if !newVal.isEmpty, let rowEl = ensureRow(doc, rowIndex: r + 1) {
                    let c = XMLElement(name: "c")
                    c.addAttribute(attr("r", ref))
                    setValue(c, newVal)
                    insertCellInOrder(c, into: rowEl, col: col)
                    cellByRef[ref] = c
                }
            }
        }
        guard changed else { return true }   // nothing edited → original untouched

        if formulaEdited { removeCalcChain(in: tmp) }
        guard (try? doc.xmlData().write(to: sheetURL, options: .atomic)) != nil else { return false }

        let out = tmp.appendingPathComponent("out.xlsx")
        let script = "cd \(quote(tmp.path)) && /usr/bin/find . -type f ! -name out.xlsx "
            + "! -name '.DS_Store' ! -path './__MACOSX/*' "
            + "| /usr/bin/sed 's|^\\./||' | /usr/bin/zip -X -q \(quote(out.path)) -@"
        guard run("/bin/sh", ["-c", script]), FileManager.default.fileExists(atPath: out.path) else { return false }
        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: out)
            return true
        } catch { return false }
    }

    // MARK: - Cell helpers

    private static func resolvedValue(_ c: XMLElement, shared: [String]) -> String {
        let t = c.attribute(forName: "t")?.stringValue
        if t == "inlineStr" {
            let ts = (try? c.nodes(forXPath: ".//*[local-name()='t']")) ?? []
            return ts.compactMap { $0.stringValue }.joined()
        }
        let raw = ((try? c.nodes(forXPath: "./*[local-name()='v']"))?.first?.stringValue) ?? ""
        if t == "s", let i = Int(raw), i >= 0, i < shared.count { return shared[i] }
        return raw
    }

    private static func hasFormula(_ c: XMLElement) -> Bool {
        ((try? c.nodes(forXPath: "./*[local-name()='f']"))?.isEmpty == false)
    }

    /// Replace a cell's value, preserving its `r`/`s` attributes. Numeric → bare `<v>`; text →
    /// `t="inlineStr"` with `<is><t>`; empty → cleared.
    private static func setValue(_ c: XMLElement, _ value: String) {
        if let kids = c.children { for _ in kids { c.removeChild(at: 0) } }
        c.removeAttribute(forName: "t")
        if value.isEmpty { return }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed == value, let d = Double(value), d.isFinite {
            let v = XMLElement(name: "v"); v.stringValue = value; c.addChild(v)
        } else {
            c.addAttribute(attr("t", "inlineStr"))
            let isEl = XMLElement(name: "is")
            let tEl = XMLElement(name: "t"); tEl.stringValue = value
            tEl.addAttribute(attr("xml:space", "preserve"))
            isEl.addChild(tEl); c.addChild(isEl)
        }
    }

    private static func ensureRow(_ doc: XMLDocument, rowIndex: Int) -> XMLElement? {
        guard let sheetData = (try? doc.nodes(forXPath: "//*[local-name()='sheetData']"))?.first as? XMLElement
        else { return nil }
        let rows = (try? sheetData.nodes(forXPath: "./*[local-name()='row']")) ?? []
        for case let row as XMLElement in rows
        where Int(row.attribute(forName: "r")?.stringValue ?? "") == rowIndex { return row }
        let newRow = XMLElement(name: "row"); newRow.addAttribute(attr("r", "\(rowIndex)"))
        for case let row as XMLElement in rows {
            if let ri = Int(row.attribute(forName: "r")?.stringValue ?? ""), ri > rowIndex {
                sheetData.insertChild(newRow, at: row.index); return newRow
            }
        }
        sheetData.addChild(newRow); return newRow
    }

    private static func insertCellInOrder(_ cell: XMLElement, into row: XMLElement, col: Int) {
        let existing = (try? row.nodes(forXPath: "./*[local-name()='c']")) ?? []
        for case let c as XMLElement in existing {
            if let ref = c.attribute(forName: "r")?.stringValue,
               let coord = XLSXParts.cellCoord(ref), coord.col > col {
                row.insertChild(cell, at: c.index); return
            }
        }
        row.addChild(cell)
    }

    private static func removeCalcChain(in tmp: URL) {
        try? FileManager.default.removeItem(at: tmp.appendingPathComponent("xl/calcChain.xml"))
        detachMatching(tmp.appendingPathComponent("[Content_Types].xml"),
                       xpath: "//*[local-name()='Override']", attr: "PartName", contains: "calcChain")
        detachMatching(tmp.appendingPathComponent("xl/_rels/workbook.xml.rels"),
                       xpath: "//*[local-name()='Relationship']", attr: "Target", contains: "calcChain")
    }

    private static func detachMatching(_ url: URL, xpath: String, attr: String, contains: String) {
        guard let doc = try? XMLDocument(contentsOf: url),
              let nodes = try? doc.nodes(forXPath: xpath) else { return }
        var any = false
        for case let el as XMLElement in nodes
        where (el.attribute(forName: attr)?.stringValue ?? "").contains(contains) { el.detach(); any = true }
        if any { try? doc.xmlData().write(to: url, options: .atomic) }
    }

    private static func attr(_ name: String, _ value: String) -> XMLNode {
        (XMLNode.attribute(withName: name, stringValue: value) as? XMLNode) ?? XMLNode(kind: .attribute)
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
