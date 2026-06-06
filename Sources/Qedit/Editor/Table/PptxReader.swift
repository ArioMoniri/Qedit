import Foundation

/// Reads a .pptx into per-slide text (read-only). Unzips ppt/slides/slideN.xml and pulls the
/// `<a:t>` runs grouped by paragraph. Read-only — rewriting pptx losslessly isn't safe.
enum PptxReader {
    struct Slide: Identifiable {
        let id: Int
        let paragraphs: [String]
    }

    static func read(_ url: URL) -> [Slide]? {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("qedit-pptx-\(UInt(bitPattern: url.path.hashValue))")
        try? FileManager.default.removeItem(at: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-o", "-q", url.path, "-d", tmp.path]
        unzip.standardOutput = nil; unzip.standardError = nil
        do { try unzip.run(); unzip.waitUntilExit() } catch { return nil }
        guard unzip.terminationStatus == 0 else { return nil }

        let slidesDir = tmp.appendingPathComponent("ppt/slides")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: slidesDir.path) else { return nil }
        let slideFiles = files
            .filter { $0.hasPrefix("slide") && $0.hasSuffix(".xml") }
            .sorted { slideNumber($0) < slideNumber($1) }
        guard !slideFiles.isEmpty else { return nil }

        var slides: [Slide] = []
        for (i, name) in slideFiles.enumerated() {
            let paras = paragraphs(in: slidesDir.appendingPathComponent(name))
            slides.append(Slide(id: i + 1, paragraphs: paras))
        }
        return slides
    }

    private static func slideNumber(_ name: String) -> Int {
        let digits = name.drop { !$0.isNumber }.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }

    private static func paragraphs(in url: URL) -> [String] {
        guard let doc = try? XMLDocument(contentsOf: url),
              let pNodes = try? doc.nodes(forXPath: "//*[local-name()='p']") else { return [] }
        return pNodes.compactMap { p in
            let ts = (try? p.nodes(forXPath: ".//*[local-name()='t']")) ?? []
            let text = ts.compactMap { $0.stringValue }.joined()
            return text.isEmpty ? nil : text
        }
    }
}
