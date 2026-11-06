import Foundation

/// Exact heard passages, never model output. Bounded RAM, reset for each call.
struct CallMemory {
    private(set) var passages: [String] = []
    private(set) var discarded = 0
    private var count = 0
    mutating func append(_ text: String) {
        var rest = text.trimmingCharacters(in: .whitespacesAndNewlines)[...]
        while !rest.isEmpty {
            let end = rest.index(rest.startIndex, offsetBy: min(700, rest.count))
            let passage = String(rest[..<end])
            passages.append(passage); count += passage.count
            rest = rest[end...]
        }
        while count > 100_000 || passages.count > 250 {
            count -= passages.removeFirst().count; discarded += 1
        }
    }
    /// Beginning + related older quotes, ordered chronologically. Recent text is supplied separately.
    func evidence(for question: String, recent: String) -> String {
        let terms = Self.terms(question + " " + String(recent.suffix(700)))
        let candidates = passages.indices.filter { !recent.contains(passages[$0]) }
        let ranked = candidates.sorted {
            let a = Self.terms(passages[$0]).intersection(terms).count
            let b = Self.terms(passages[$1]).intersection(terms).count
            return a == b ? $0 > $1 : a > b
        }
        var selected: Set<Int> = []
        if let first = candidates.first { selected.insert(first) }
        for index in ranked where selected.count < 3 {
            if !Self.terms(passages[index]).intersection(terms).isEmpty { selected.insert(index) }
        }
        return String(selected.sorted().map { "[Passage \($0 + discarded + 1)] " + passages[$0] }.joined(separator: "\n").prefix(1800))
    }
    private static func terms(_ text: String) -> Set<String> {
        let stop: Set<String> = ["avec", "dans", "pour", "cette", "vous", "nous", "quel", "quelle", "comment", "pourquoi", "peux", "plus", "sans", "question", "alors", "donc", "sont", "etre", "cela", "notre", "comme"]
        return Set(text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
            .split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 4 && !stop.contains($0) })
    }
}
