import Foundation

@main struct CallContextTests {
    @MainActor static func wait(_ milliseconds: Int = 100) async { try? await Task.sleep(for: .milliseconds(milliseconds)) }
    @MainActor static func main() async throws {
        var memory = CallMemory()
        memory.append("Le projet Saturne utilise DaVinci et le budget de montage est de 800 euros.")
        for i in 0..<45 { memory.append("Passage \(i) sur une autre discussion. " + String(repeating: "Ceci est un commentaire de réunion. ", count: 20)) }
        let old = memory.evidence(for: "Quel budget pour le montage Saturne ?", recent: "La livraison est mardi.")
        precondition(old.contains("800 euros") && old.count <= 1800)
        for _ in 0..<300 { memory.append(String(repeating: "x", count: 700)) }
        precondition(memory.passages.count <= 250 && memory.passages.joined().count <= 100_000 && memory.discarded > 0)
        precondition(memory.evidence(for: "Saturne", recent: "").count <= 1800)
        var localCalls = 0, cloudCalls = 0
        var snapshots: [CallAnswerSnapshot] = []
        let assistant = CallAssistant(manualGenerator: { request in
            try? await Task.sleep(for: .milliseconds(60))
            return "Une réponse manuelle."
        }, automaticGenerator: { evidence in
            localCalls += 1; snapshots.append(evidence)
            if evidence.question.contains("première") { try? await Task.sleep(for: .milliseconds(200)) }
            return CallUnderstoodReply(canAnswer: true, understoodQuestion: evidence.question, answer: "Réponse à \(evidence.question)")
        }, cloudManualGenerator: { _, _ in cloudCalls += 1; try? await Task.sleep(for: .milliseconds(80)); return "Une réponse cloud." },
           cloudAutomaticGenerator: { evidence, _ in cloudCalls += 1; return CallUnderstoodReply(canAnswer: true, understoodQuestion: evidence.question, answer: "Une réponse cloud.") },
           questionDelay: .milliseconds(10))
        assistant.context = "Projet de montage."
        let route = CallCloudRoute(provider: .openai, model: "test-model")
        precondition(!assistant.authorizeCloud(route, sessionID: assistant.sessionID))
        assistant.beginSession()
        assistant.receive("Le budget Saturne est de 800 euros.", final: true)
        assistant.receive("Quelle est la première étape ?", final: true)
        await wait(40)
        assistant.receive("Quelle est la deuxième étape ?", final: true)
        await wait(300)
        precondition(assistant.question.contains("deuxième") && localCalls == 2 && cloudCalls == 0)
        // Ordinary speech while generation runs should not suppress the stable question.
        assistant.receive("Quelle est la première livraison ?", final: true)
        await wait(40)
        assistant.receive("Je vous écoute maintenant.", final: true)
        await wait(250)
        precondition(assistant.question.contains("première livraison"))
        let revision = assistant.answerRevision
        assistant.receive("Quelle est la première correction ?", final: true)
        await wait(40); assistant.context = "Nouveau sujet"
        await wait(250)
        precondition(assistant.answerRevision == revision && !assistant.understanding)
        assistant.autoSuggest = false
        assistant.receive("Le nouveau budget est confirmé à 950 euros.", final: true)
        precondition(assistant.memoryPassages > 0)
        assistant.autoSuggest = true
        assistant.receive("Quel est le budget confirmé ?", final: true)
        await wait()
        precondition(snapshots.last!.conversation.contains("950 euros"))
        // Cloud configuration alone is irrelevant: only a session grant routes a request.
        precondition(assistant.authorizeCloud(route, sessionID: assistant.sessionID))
        assistant.suggest("Quel est notre budget ?")
        await wait(20); assistant.disableCloud(); let before = assistant.answerRevision
        await wait()
        precondition(assistant.answerRevision == before && assistant.cloudRoute == nil && cloudCalls == 1)
        precondition(assistant.authorizeCloud(route, sessionID: assistant.sessionID))
        assistant.cloudConfigurationChanged()
        precondition(assistant.cloudRoute == nil)
        precondition(assistant.authorizeCloud(route, sessionID: assistant.sessionID))
        assistant.suggest("Quel est le budget actuel ?")
        await wait()
        precondition(assistant.answerSource.contains("OpenAI") && assistant.cloudRequests == 2)
        let oldSession = assistant.sessionID
        assistant.beginSession()
        precondition(!assistant.authorizeCloud(route, sessionID: oldSession))
        precondition(assistant.cloudRoute == nil && assistant.cloudRequests == 0 && assistant.memoryPassages == 0 && assistant.transcript.isEmpty && assistant.suggestion.isEmpty)
        assistant.receive("Quel est le nouveau sujet ?", final: true)
        await wait()
        precondition(!snapshots.last!.automaticPrompt.contains("950 euros") && !snapshots.last!.automaticPrompt.contains("800 euros"))
        precondition(assistant.authorizeCloud(route, sessionID: assistant.sessionID))
        for _ in 0..<20 { assistant.suggest("Quel est le sujet actuel ?") }
        assistant.suggest("Une vingt-et-unième demande refusée")
        await wait()
        precondition(!assistant.thinking && assistant.cloudRequests == 20 && assistant.answerError != nil)
        let delayed = CallAssistant(automaticGenerator: { _ in preconditionFailure("Unexpected local fallback") },
            cloudAutomaticGenerator: { evidence, _ in
                try? await Task.sleep(for: .milliseconds(80))
                return CallUnderstoodReply(canAnswer: true, understoodQuestion: evidence.question, answer: "Une proposition complète.")
            }, questionDelay: .milliseconds(5), cloudInterval: 0.2)
        delayed.beginSession()
        precondition(delayed.authorizeCloud(route, sessionID: delayed.sessionID))
        delayed.receive("Quelle est la première version ?", final: true)
        await wait(25)
        delayed.receive("Quelle est la deuxième version ?", final: true)
        await wait(100)
        delayed.receive("Je vous écoute à nouveau.", final: true)
        await wait(250)
        precondition(delayed.question.contains("deuxième") && delayed.cloudRequests == 2)
        delayed.stop()
        assistant.useExample()
        precondition(!assistant.authorizeCloud(route, sessionID: assistant.sessionID))
        assistant.stop()
        let valid = try CallCloud.decode(#"{"canAnswer":true,"understoodQuestion":"Quel est le sujet ?","answer":"Le montage vidéo."}"#)
        precondition(valid.canAnswer)
        for invalid in ["Not JSON", #"{"canAnswer":"true","understoodQuestion":"X","answer":"Y"}"#, #"{"canAnswer":true,"understoodQuestion":"","answer":"Y"}"#] {
            do { _ = try CallCloud.decode(invalid); preconditionFailure("invalid result accepted") } catch { }
        }
        print("PASS call context: bounded retrieval, latest-question wins, unrelated speech, context invalidation, pause retention, cloud consent/revocation, new-call isolation, strict JSON")
    }
}
