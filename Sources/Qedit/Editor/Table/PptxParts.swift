import Foundation

/// Shared PresentationML helpers for reading/writing .pptx text, mirroring `XLSXParts`.
///
/// The core safety idea (same as the spreadsheet writer): touch as little as possible. We edit ONLY
/// the inner text of `<a:t>` runs and splice the raw slide XML as a string — we never re-serialize
/// the document through `XMLDocument`, which would expand self-closing DrawingML tags and rewrite
/// the whole slide. The reader and the writer find runs with the SAME regex, in document order, and
/// the writer FAILS CLOSED (refuses to save that slide) if the counts ever disagree.
enum PptxParts {
    /// One `<a:t>` text run inside a slide, in document order.
    struct Run {
        var text: String        // human text (XML-unescaped)
        let editable: Bool      // single-run body paragraph (safe to edit); else shown read-only
    }

    /// Ordered slide part names inside the package, e.g. ["ppt/slides/slide1.xml", …], following the
    /// real presentation order (`<p:sldIdLst>` → relationships), not filename order.
    static func slideOrder(in root: URL) -> [String] {
        let ppt = root.appendingPathComponent("ppt")
        guard let pres = try? XMLDocument(contentsOf: ppt.appendingPathComponent("presentation.xml")),
              let ids = try? pres.nodes(forXPath: "//*[local-name()='sldId']"),
              let rels = try? XMLDocument(contentsOf: ppt.appendingPathComponent("_rels/presentation.xml.rels")),
              let relNodes = try? rels.nodes(forXPath: "//*[local-name()='Relationship']")
        else { return fallbackSlides(in: ppt) }

        var targetByID: [String: String] = [:]
        for case let rel as XMLElement in relNodes {
            if let id = rel.attribute(forName: "Id")?.stringValue,
               let target = rel.attribute(forName: "Target")?.stringValue {
                targetByID[id] = target
            }
        }
        var ordered: [String] = []
        for case let sld as XMLElement in ids {
            guard let rid = sld.attributes?.first(where: { $0.name == "r:id" })?.stringValue
                    ?? sld.attributes?.first(where: { $0.localName == "id" && ($0.name ?? "").contains(":") })?.stringValue,
                  let target = targetByID[rid] else { continue }
            ordered.append(normalize(target))
        }
        return ordered.isEmpty ? fallbackSlides(in: ppt) : ordered
    }

    private static func normalize(_ target: String) -> String {
        var t = target
        while t.hasPrefix("../") { t = String(t.dropFirst(3)) }
        if t.hasPrefix("/") { return String(t.dropFirst()) }
        if t.hasPrefix("ppt/") { return t }
        return "ppt/" + t
    }

    private static func fallbackSlides(in ppt: URL) -> [String] {
        let dir = ppt.appendingPathComponent("slides")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names.filter { $0.hasSuffix(".xml") }
            .sorted { lhs, rhs in
                slideNumber(lhs) < slideNumber(rhs)
            }
            .map { "ppt/slides/\($0)" }
    }

    private static func slideNumber(_ name: String) -> Int {
        Int(name.dropFirst("slide".count).prefix { $0.isNumber }) ?? 0
    }

    // MARK: - Run extraction (one regex, used by reader AND writer)

    /// One compiled regex: matches `<a:t …>inner</a:t>` and self-closing `<a:t …/>`.
    /// Group 1 = opening tag (with attributes) of the paired form; group 2 = inner text;
    /// group 3 = the whole self-closing tag.
    static let runRegex: NSRegularExpression = {
        let pattern = "(<a:t(?:\\s[^>]*)?>)(.*?)</a:t>|(<a:t(?:\\s[^>]*)?/>)"
        return (try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]))
            ?? NSRegularExpression()
    }()

    /// All a:t matches in `xml`, in document order.
    static func matches(in xml: String) -> [NSTextCheckingResult] {
        let ns = xml as NSString
        return runRegex.matches(in: xml, options: [], range: NSRange(location: 0, length: ns.length))
    }

    /// Plain (unescaped) text for a single a:t match.
    static func text(of match: NSTextCheckingResult, in xml: String) -> String {
        let ns = xml as NSString
        let innerRange = match.range(at: 2)
        guard innerRange.location != NSNotFound else { return "" }   // self-closing → empty
        return xmlUnescape(ns.substring(with: innerRange))
    }

    // MARK: - Editability

    /// For each a:t run (in document order), whether it is safe to edit in v1: a body run that is
    /// the ONLY run in its paragraph (so we don't have to reason about mixed inline formatting) and
    /// not inside a field, table, chart or other graphic frame. Returns nil — meaning "treat the
    /// whole slide as read-only" — if the structural parse and the regex disagree on the run count,
    /// because then we can't trust the index alignment the writer relies on.
    static func editability(forSlideXML xml: String) -> [Bool]? {
        guard let doc = try? XMLDocument(xmlString: xml, options: []),
              let tNodes = try? doc.nodes(forXPath: "//*[local-name()='t']") else { return nil }
        guard tNodes.count == matches(in: xml).count else { return nil }
        return tNodes.map { node in
            guard let el = node as? XMLElement else { return false }
            return isEditableRun(el)
        }
    }

    private static func isEditableRun(_ t: XMLElement) -> Bool {
        guard let r = t.parent as? XMLElement, r.localName == "r" else { return false }   // not a:fld etc.
        guard let p = r.parent as? XMLElement, p.localName == "p" else { return false }
        let runs = (try? p.nodes(forXPath: "./*[local-name()='r']")) ?? []
        guard runs.count == 1 else { return false }    // single-run paragraph only (v1)
        var ancestor: XMLNode? = p.parent
        while let el = ancestor as? XMLElement {
            switch el.localName ?? "" {
            case "tbl", "graphicFrame", "graphic": return false   // tables / charts / SmartArt
            default: ancestor = el.parent
            }
        }
        return true
    }

    // MARK: - XML escaping

    static func xmlEscape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default: out.append(ch)
            }
        }
        return out
    }

    static func xmlUnescape(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var result = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "&", let semi = s[i...].firstIndex(of: ";") {
                let entity = String(s[s.index(after: i)..<semi])
                if let decoded = decodeEntity(entity) {
                    result.append(decoded)
                    i = s.index(after: semi)
                    continue
                }
            }
            result.append(s[i])
            i = s.index(after: i)
        }
        return result
    }

    private static func decodeEntity(_ e: String) -> Character? {
        switch e {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        default:
            if e.hasPrefix("#x") || e.hasPrefix("#X"), let v = UInt32(e.dropFirst(2), radix: 16),
               let scalar = Unicode.Scalar(v) { return Character(scalar) }
            if e.hasPrefix("#"), let v = UInt32(e.dropFirst(1)), let scalar = Unicode.Scalar(v) {
                return Character(scalar)
            }
            return nil
        }
    }
}
