import Foundation

/// Candidate detection stays deterministic; the local model interprets it with the recent context.
enum CallQuestions {
    static func candidate(in text: String) -> String? {
        let tail = String(text.suffix(1600)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard tail.split(whereSeparator: \.isWhitespace).count >= 3 else { return nil }
        // A dot inside a token (e.g. an address or a recognition artifact) is not a sentence.
        let pieces = tail.replacingOccurrences(of: "([.!?])\\s+", with: "$1\n", options: .regularExpression)
            .components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for sentence in pieces.reversed() {
            guard sentence.split(whereSeparator: \.isWhitespace).count >= 3 else { continue }
            if sentence.hasSuffix("?") { return String(sentence.prefix(700)) }
            let lower = sentence.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
                .replacingOccurrences(of: "^(?:(?:et|alors|donc|mais|du coup)\\s+)+", with: "", options: .regularExpression)
            // Bare 'quand', 'comment' inside a statement are too ambiguous for an automatic answer.
            let starts = ["est-ce", "est ce", "qu'est", "qu est", "pourquoi ", "comment ", "combien ", "quel ", "quelle ", "quels ", "quelles ", "peux-tu", "peux tu", "pouvez-vous", "pouvez vous", "tu peux ", "vous pouvez ", "qu'en penses", "what ", "why ", "how ", "could you", "can you", "do you", "would you", "when "]
            if starts.contains(where: lower.hasPrefix) { return String(sentence.prefix(700)) }
            // Speech often omits punctuation after a lead-in. Preserve that context rather than
            // matching any occurrence of a question word in an ordinary explanatory sentence.
            let leadIns = ["j'ai une question", "j’avais une question", "j'avais une question", "pour confirmer", "ma question", "on me demande"]
            if leadIns.contains(where: lower.contains), sentence.split(whereSeparator: \.isWhitespace).count >= 9 {
                return String(sentence.prefix(700))
            }
        }
        return nil
    }
    /// Conservative syntax guard before the model: it must never finish an interrupted question.
    static func isClearlyIncomplete(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleaned.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
            .split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard words.count >= 4 else { return true }
        let dangling: Set<String> = ["le", "la", "les", "un", "une", "des", "de", "du", "au", "aux", "si", "que", "qui", "pour", "avec", "dans", "et", "ou", "est", "sont", "serait", "donc", "alors"]
        if let last = words.last, dangling.contains(last) { return true }
        // Without its main clause, an 'est-ce que si…' lead-in is not safely answerable.
        // Prefer waiting for punctuation/the next complete phrasing over inventing its continuation.
        if key(cleaned).hasPrefix("estcequesi") && (!cleaned.hasSuffix("?") || words.last == "la") { return true }
        return false
    }
    static func key(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr")).filter { $0.isLetter || $0.isNumber }
    }
}

/// Suppresses repeated Speech snapshots without restarting the delay for unrelated appended words.
struct CallQuestionTracker {
    private(set) var pending: String?
    private var accepted: [(key: String, time: TimeInterval)] = []
    private var attempted: [(key: String, time: TimeInterval)] = []

    mutating func update(_ candidate: String?, now: TimeInterval) -> Bool {
        guard let candidate else { let changed = pending != nil; pending = nil; return changed }
        let key = CallQuestions.key(candidate)
        accepted.removeAll { now - $0.time > 90 }
        attempted.removeAll { now - $0.time > 12 }
        if attempted.contains(where: { $0.key == key }) || accepted.contains(where: { $0.key == key || (now - $0.time < 12 && min(key.count, $0.key.count) >= 35 && (key.hasPrefix($0.key) || $0.key.hasPrefix(key))) }) {
            let changed = pending != nil; pending = nil; return changed
        }
        if pending.map(CallQuestions.key) == key { return false }
        pending = candidate; return true
    }
    mutating func consume(_ candidate: String, now: TimeInterval) -> Bool {
        guard pending.map(CallQuestions.key) == CallQuestions.key(candidate) else { return false }
        pending = nil
        attempted.append((CallQuestions.key(candidate), now)); attempted = Array(attempted.suffix(80))
        return true
    }
    mutating func accept(_ candidate: String, now: TimeInterval) {
        accepted.append((CallQuestions.key(candidate), now)); accepted = Array(accepted.suffix(80))
    }
    mutating func cancelPending() { pending = nil }
    mutating func reset() { pending = nil; accepted = []; attempted = [] }
}

/// Reject oversize model output rather than slicing a sentence into a misleading answer.
enum CallAnswerLimits {
    static func accepted(_ raw: String, maxWords: Int = 120) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 1600, text.split(whereSeparator: \.isWhitespace).count <= maxWords else { return nil }
        return text
    }
}
