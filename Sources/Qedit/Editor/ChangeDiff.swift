import Foundation

/// Computes what changed between the on-disk text and the current text, so editors can highlight
/// exactly the inserted/edited spans (e.g. "hi" → "hi asfas" highlights just " asfas"), plus mark
/// where text was removed. Word/token-level LCS, so multiple separate edits each highlight rather
/// than collapsing into one giant span. Bounded: very large inputs fall back to a single span.
enum ChangeDiff {
    /// Display marks against the CURRENT string (all offsets are UTF-16, matching NSString/NSRange
    /// and NSTextStorage indices).
    struct Marks: Equatable {
        /// Spans of current text that were inserted or changed.
        var changed: [NSRange]
        /// Offsets in current text where text was deleted (nothing remains to color there).
        var deletions: [Int]
        var isEmpty: Bool { changed.isEmpty && deletions.isEmpty }
        static let none = Marks(changed: [], deletions: [])
    }

    /// Token = a run of word characters, or a single other character; with its UTF-16 range.
    private struct Token { let text: Substring; let location: Int; let length: Int }

    static func marks(original: String, current: String) -> Marks {
        if original == current { return .none }
        let curLen = (current as NSString).length
        if original.isEmpty { return Marks(changed: curLen > 0 ? [NSRange(location: 0, length: curLen)] : [], deletions: []) }
        if current.isEmpty { return Marks(changed: [], deletions: [0]) }

        let o = tokenize(original)
        let c = tokenize(current)
        // Cost guard: LCS is O(n·m). Fall back to a single prefix/suffix span on big inputs.
        if o.count * c.count > 3_000_000 {
            return singleSpan(original: original, current: current)
        }

        let ops = diffOps(o, c)
        return assemble(ops: ops, current: c, currentLength: curLen)
    }

    // MARK: - Tokenize

    private static func isWord(_ ch: Character) -> Bool { ch.isLetter || ch.isNumber || ch == "_" }

    private static func tokenize(_ s: String) -> [Token] {
        var tokens: [Token] = []
        var utf16 = 0
        var i = s.startIndex
        while i < s.endIndex {
            let start = utf16
            if isWord(s[i]) {
                var j = i
                while j < s.endIndex, isWord(s[j]) { utf16 += s[j].utf16.count; j = s.index(after: j) }
                tokens.append(Token(text: s[i..<j], location: start, length: utf16 - start))
                i = j
            } else {
                utf16 += s[i].utf16.count
                tokens.append(Token(text: s[i...i], location: start, length: utf16 - start))
                i = s.index(after: i)
            }
        }
        return tokens
    }

    // MARK: - LCS diff → ops

    private enum Op { case equal(Int), insert(Int), delete(Int) }   // index into c (insert/equal) or o (delete)

    private static func diffOps(_ o: [Token], _ c: [Token]) -> [Op] {
        let n = o.count, m = c.count
        // dp[i][j] = LCS length of o[i...], c[j...]
        var dp = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    dp[i][j] = o[i].text == c[j].text
                        ? dp[i + 1][j + 1] + 1
                        : max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }
        var ops: [Op] = []
        var i = 0, j = 0
        while i < n && j < m {
            if o[i].text == c[j].text { ops.append(.equal(j)); i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { ops.append(.delete(i)); i += 1 }
            else { ops.append(.insert(j)); j += 1 }
        }
        while i < n { ops.append(.delete(i)); i += 1 }
        while j < m { ops.append(.insert(j)); j += 1 }
        return ops
    }

    // MARK: - Assemble marks

    private static func assemble(ops: [Op], current c: [Token], currentLength: Int) -> Marks {
        var changed: [NSRange] = []
        var deletions: [Int] = []

        var k = 0
        while k < ops.count {
            switch ops[k] {
            case .equal:
                k += 1
            default:
                // Gather a contiguous change block (consecutive insert/delete ops).
                var insertTokens: [Int] = []
                var hasDelete = false
                while k < ops.count {
                    if case .insert(let ci) = ops[k] { insertTokens.append(ci); k += 1 }
                    else if case .delete = ops[k] { hasDelete = true; k += 1 }
                    else { break }
                }
                if let first = insertTokens.first, let last = insertTokens.last {
                    // Inserted/changed text present → one span covering it.
                    let start = c[first].location
                    let end = c[last].location + c[last].length
                    changed.append(NSRange(location: start, length: end - start))
                } else if hasDelete {
                    // Pure deletion: mark the seam in the current text.
                    let at = k < ops.count ? currentTokenLocation(ops[k], c) : currentLength
                    deletions.append(min(max(at, 0), currentLength))
                }
            }
        }
        return Marks(changed: mergeAdjacent(changed), deletions: deletions)
    }

    private static func currentTokenLocation(_ op: Op, _ c: [Token]) -> Int {
        if case .equal(let ci) = op { return c[ci].location }
        if case .insert(let ci) = op { return c[ci].location }
        return 0
    }

    /// Merge ranges that touch or overlap (e.g. two adjacent inserted tokens).
    private static func mergeAdjacent(_ ranges: [NSRange]) -> [NSRange] {
        guard ranges.count > 1 else { return ranges }
        let sorted = ranges.sorted { $0.location < $1.location }
        var out = [sorted[0]]
        for r in sorted.dropFirst() {
            let last = out[out.count - 1]
            if r.location <= last.location + last.length {
                let end = max(last.location + last.length, r.location + r.length)
                out[out.count - 1] = NSRange(location: last.location, length: end - last.location)
            } else { out.append(r) }
        }
        return out
    }

    // MARK: - Fallback

    private static func singleSpan(original: String, current: String) -> Marks {
        let o = original as NSString, c = current as NSString
        let oLen = o.length, cLen = c.length
        var prefix = 0
        while prefix < oLen, prefix < cLen, o.character(at: prefix) == c.character(at: prefix) { prefix += 1 }
        var suffix = 0
        while suffix < oLen - prefix, suffix < cLen - prefix,
              o.character(at: oLen - 1 - suffix) == c.character(at: cLen - 1 - suffix) { suffix += 1 }
        let start = prefix, end = cLen - suffix
        if end > start { return Marks(changed: [NSRange(location: start, length: end - start)], deletions: []) }
        if oLen > cLen { return Marks(changed: [], deletions: [min(prefix, cLen)]) }  // net deletion
        return .none
    }
}
