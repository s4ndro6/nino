import Foundation

@main struct CallAnswerSnapshotTests {
    @MainActor static func settle(_ assistant: CallAssistant) async {
        for _ in 0..<200 {
            if !assistant.thinking { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        preconditionFailure("Generation did not settle")
    }
    @MainActor static func main() async {
        var requests: [CallManualRequest] = []
        var mode = "normal"
        let assistant = CallAssistant(manualGenerator: { request in
            requests.append(request)
            if mode == "error" { throw NinoError("Synthetic failure") }
            if mode == "long" { return String(repeating: "mot ", count: 150) }
            if mode == "slow" { try? await Task.sleep(for: .milliseconds(120)) }
            return request.kind == .simplify ? "Le client vérifie si son achat lui convient." : "Après l’achat, le client évalue sa satisfaction. Cela peut contribuer à sa fidélité."
        })
        assistant.context = "Contexte origine marketing"
        assistant.committed = "Extrait origine parcours d’achat"
        assistant.suggest("Que se passe-t-il après un achat ?")
        await settle(assistant)
        precondition(assistant.canSimplifyAnswer && assistant.answerUpdatedAt != nil)
        let originalQuestion = assistant.question
        let originalRevision = assistant.answerRevision
        let originalAnswer = assistant.suggestion
        assistant.context = "Nouveau contexte physique"
        assistant.committed = "Nouveau transcript orbital"
        assistant.simplifyAnswer()
        await settle(assistant)
        precondition(requests.last?.kind == .simplify)
        precondition(requests.last?.snapshot.context == "Contexte origine marketing")
        precondition(requests.last?.snapshot.conversation == "Extrait origine parcours d’achat")
        precondition(requests.last?.snapshot.answer == originalAnswer)
        precondition(assistant.question == originalQuestion && assistant.answerRevision != originalRevision)
        let simpleRevision = assistant.answerRevision
        let simpleAnswer = assistant.suggestion
        let simpleDate = assistant.answerUpdatedAt
        let count = requests.count
        precondition(!assistant.correctQuestion("Question du brouillon ancien", expectedRevision: originalRevision))
        precondition(requests.count == count && assistant.answerRevision == simpleRevision)
        precondition(assistant.correctQuestion("Quel rôle joue la satisfaction après l’achat ?", expectedRevision: simpleRevision))
        await settle(assistant)
        precondition(requests.last?.snapshot.context == "Contexte origine marketing")
        precondition(requests.last?.snapshot.conversation == "Extrait origine parcours d’achat")
        let correctedRevision = assistant.answerRevision
        let correctedQuestion = assistant.question
        let correctedAnswer = assistant.suggestion
        let correctedDate = assistant.answerUpdatedAt
        mode = "error"
        assistant.suggest("Une question qui échoue")
        await settle(assistant)
        precondition(assistant.question == correctedQuestion && assistant.suggestion == correctedAnswer)
        precondition(assistant.answerRevision == correctedRevision && assistant.answerUpdatedAt == correctedDate && assistant.answerError != nil)
        assistant.simplifyAnswer()
        await settle(assistant)
        precondition(assistant.question == correctedQuestion && assistant.suggestion == correctedAnswer)
        precondition(requests.last?.snapshot.context == "Contexte origine marketing")
        mode = "long"
        assistant.suggest("Une proposition trop longue")
        await settle(assistant)
        precondition(assistant.question == correctedQuestion && assistant.suggestion == correctedAnswer && assistant.answerRevision == correctedRevision)
        mode = "slow"
        assistant.suggest("Une question annulée")
        try? await Task.sleep(for: .milliseconds(10))
        assistant.stop()
        try? await Task.sleep(for: .milliseconds(180))
        precondition(assistant.question == correctedQuestion && assistant.suggestion == correctedAnswer && assistant.answerRevision == correctedRevision)
        // No unrelated context leaked into simplification, no revision/timestamp changed on any failure.
        precondition(!simpleAnswer.isEmpty && simpleDate != nil)
        precondition(CallAnswerLimits.accepted("  ") == nil)
        precondition(CallAnswerLimits.accepted("Une phrase courte.") == "Une phrase courte.")
        print("PASS answer snapshots: pinned evidence, simplify, correction, stale edit rejection, manual/simplify failure retention, output bounds, cancelled late result")
    }
}
