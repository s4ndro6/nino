import Foundation

@main struct CallQuestionTests {
    static func main() {
        precondition(CallQuestions.candidate(in: "Voici comment nous allons procéder pour notre étude.") == nil)
        precondition(CallQuestions.candidate(in: "Quand on agrandit un échantillon, la précision change.") == nil)
        precondition(CallQuestions.candidate(in: "Comment diminuer la marge d’erreur ? La méthode commence par") == "Comment diminuer la marge d’erreur ?")
        precondition(CallQuestions.candidate(in: "Pourquoi augmenter la taille ? Combien de personnes faut-il interroger ?") == "Combien de personnes faut-il interroger ?")
        precondition(CallQuestions.candidate(in: "Quelle est la différence entre segment et persona") != nil)
        precondition(CallQuestions.candidate(in: "J'avais une question pour confirmer, augmenter l’échantillon réduit la marge") != nil)
        var tracker = CallQuestionTracker()
        let question = "Comment diminuer la marge d’erreur dans une enquête ?"
        precondition(tracker.update(question, now: 0))
        // Continuous cumulative Speech results keep the same timer alive, not postpone it.
        for instant in [0.1,0.2,0.3,0.4] { precondition(!tracker.update(question, now: instant)) }
        precondition(tracker.consume(question, now: 0.5))
        tracker.accept(question, now: 0.5)
        precondition(!tracker.update(question, now: 0.6))
        precondition(!tracker.update("Comment diminuer la marge d’erreur dans une enquête nationale ?", now: 1))
        let newer = "Quel outil utiliser pour créer un persona ?"
        precondition(tracker.update(newer, now: 2))
        precondition(!tracker.consume(question, now: 2.1)) // superseded callback cannot start an old answer
        precondition(tracker.consume(newer, now: 2.2))
        precondition(tracker.update(question, now: 91)) // deliberately repeated later can be answered again
        tracker.reset()
        precondition(tracker.pending == nil && tracker.update(question, now: 92))
        precondition(tracker.update(nil, now: 93) && tracker.pending == nil)
        tracker.reset()
        let fragment = "Est-ce que si vous avez un problème le SAV là"
        precondition(tracker.update(fragment, now: 0))
        precondition(tracker.consume(fragment, now: 2))
        precondition(!tracker.update(fragment, now: 3))
        // A rejected fragment is not accepted: its completed extension must still be analyzed.
        precondition(tracker.update(fragment + " est efficace pour fidéliser le client ?", now: 4))
        precondition(CallQuestions.candidate(in: "Et ensuite le poste d’achat, c’est une fois que j’ai payé, qu’est-ce qui se passe ?")?.hasPrefix("Et ensuite") == true)
        precondition(CallQuestions.candidate(in: ".com") == nil)
        precondition(CallQuestions.candidate(in: "Quel est le rôle de exemple.com dans ce processus ?")?.contains("exemple.com") == true)
        precondition(CallQuestions.isClearlyIncomplete(".com"))
        precondition(CallQuestions.isClearlyIncomplete("Est-ce que si vous avez un problème le SAV là"))
        precondition(CallQuestions.isClearlyIncomplete("Est-ce que si vous avez un problème le SAV là ?"))
        precondition(CallQuestions.isClearlyIncomplete("Quelle est la différence entre le"))
        precondition(!CallQuestions.isClearlyIncomplete("Et ensuite le poste d’achat, c’est une fois que j’ai payé, qu’est-ce qui se passe ?"))
        precondition(!CallQuestions.isClearlyIncomplete("Est-ce que si le produit est défectueux, le service client intervient ?"))
        print("PASS call questions: extraction, false-positive cues, stable cumulative snapshots, extension suppression, replacement race, reset and expiry")
    }
}
