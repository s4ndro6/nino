import Foundation

@main struct CallContextTests {
    @MainActor static func wait(_ milliseconds: Int = 100) async { try? await Task.sleep(for: .milliseconds(milliseconds)) }
    @MainActor static func eventually(_ condition: () -> Bool, file: StaticString = #file, line: UInt = #line) async {
        for _ in 0..<1000 {
            if condition() { return }
            await wait(10)
        }
        preconditionFailure("Expected state did not arrive", file: file, line: line)
    }
    @MainActor static func main() async throws {
        var memory = CallMemory()
        memory.append("Le projet Saturne utilise DaVinci et le budget de montage est de 800 euros.")
        for i in 0..<45 { memory.append("Passage \(i) sur une autre discussion. " + String(repeating: "Ceci est un commentaire de réunion. ", count: 20)) }
        let old = memory.evidence(for: "Quel budget pour le montage Saturne ?", recent: "La livraison est mardi.")
        precondition(old.contains("800 euros") && old.count <= 1800)
        for _ in 0..<300 { memory.append(String(repeating: "x", count: 700)) }
        precondition(memory.passages.count <= 250 && memory.passages.joined().count <= 100_000 && memory.discarded > 0)
        precondition(memory.evidence(for: "Saturne", recent: "").count <= 1800)
        var localCalls = 0, cloudCalls = 0, localFinished = 0, cloudFinished = 0
        var localGate: CheckedContinuation<Void, Never>?
        var cloudGate: CheckedContinuation<Void, Never>?
        var snapshots: [CallAnswerSnapshot] = []
        let assistant = CallAssistant(manualGenerator: { request in
            try? await Task.sleep(for: .milliseconds(60))
            return "Une réponse manuelle."
        }, automaticGenerator: { evidence in
            localCalls += 1; snapshots.append(evidence)
            if evidence.question.contains("première") { await withCheckedContinuation { localGate = $0 } }
            localFinished += 1
            return CallUnderstoodReply(canAnswer: true, understoodQuestion: evidence.question, answer: "Réponse à \(evidence.question)")
        }, cloudManualGenerator: { _, _ in
            cloudCalls += 1
            if cloudCalls == 1 { await withCheckedContinuation { cloudGate = $0 } }
            cloudFinished += 1
            return "Une réponse cloud."
        },
           cloudAutomaticGenerator: { evidence, _ in cloudCalls += 1; return CallUnderstoodReply(canAnswer: true, understoodQuestion: evidence.question, answer: "Une réponse cloud.") },
           questionDelay: .milliseconds(10))
        assistant.context = "Projet de montage."
        let route = CallCloudRoute(provider: .openai, model: "test-model")
        precondition(!assistant.authorizeCloud(route, sessionID: assistant.sessionID))
        assistant.beginSession()
        assistant.receive("Le budget Saturne est de 800 euros.", final: true)
        assistant.receive("Quelle est la première étape ?", final: true)
        await eventually { localGate != nil }
        assistant.receive("Quelle est la deuxième étape ?", final: true)
        localGate?.resume(); localGate = nil
        await eventually { assistant.question.contains("deuxième") && !assistant.understanding }
        precondition(assistant.question.contains("deuxième") && localCalls == 2 && cloudCalls == 0)
        // Ordinary speech while generation runs should not suppress the stable question.
        assistant.receive("Quelle est la première livraison ?", final: true)
        await eventually { localGate != nil }
        assistant.receive("Je vous écoute maintenant.", final: true)
        localGate?.resume(); localGate = nil
        await eventually { assistant.question.contains("première livraison") && !assistant.understanding }
        precondition(assistant.question.contains("première livraison"))
        let revision = assistant.answerRevision
        assistant.receive("Quelle est la première correction ?", final: true)
        await eventually { localGate != nil }
        let completedBeforeChange = localFinished
        assistant.context = "Nouveau sujet"
        localGate?.resume(); localGate = nil
        await eventually { localFinished > completedBeforeChange }
        await Task.yield()
        precondition(assistant.answerRevision == revision && !assistant.understanding)
        assistant.autoSuggest = false
        assistant.receive("Le nouveau budget est confirmé à 950 euros.", final: true)
        precondition(assistant.memoryPassages > 0)
        assistant.autoSuggest = true
        assistant.receive("Quel est le budget confirmé ?", final: true)
        await eventually { assistant.question.contains("budget confirmé") && !assistant.understanding }
        precondition(snapshots.last!.conversation.contains("950 euros"))
        // Cloud configuration alone is irrelevant: only a session grant routes a request.
        precondition(assistant.authorizeCloud(route, sessionID: assistant.sessionID))
        assistant.suggest("Quel est notre budget ?")
        await eventually { cloudGate != nil }
        assistant.disableCloud(); let before = assistant.answerRevision
        cloudGate?.resume(); cloudGate = nil
        await eventually { cloudFinished == 1 }
        await Task.yield()
        precondition(assistant.answerRevision == before && assistant.cloudRoute == nil && cloudCalls == 1)
        precondition(assistant.authorizeCloud(route, sessionID: assistant.sessionID))
        assistant.cloudConfigurationChanged()
        precondition(assistant.cloudRoute == nil)
        precondition(assistant.authorizeCloud(route, sessionID: assistant.sessionID))
        assistant.suggest("Quel est le budget actuel ?")
        await eventually { !assistant.thinking }
        precondition(assistant.answerSource.contains("OpenAI") && assistant.cloudRequests == 2)
        let oldSession = assistant.sessionID
        assistant.beginSession()
        precondition(!assistant.authorizeCloud(route, sessionID: oldSession))
        precondition(assistant.cloudRoute == nil && assistant.cloudRequests == 0 && assistant.memoryPassages == 0 && assistant.transcript.isEmpty && assistant.suggestion.isEmpty)
        assistant.receive("Quel est le nouveau sujet ?", final: true)
        await eventually { assistant.question.contains("nouveau sujet") && !assistant.understanding }
        precondition(!snapshots.last!.automaticPrompt.contains("950 euros") && !snapshots.last!.automaticPrompt.contains("800 euros"))
        precondition(assistant.authorizeCloud(route, sessionID: assistant.sessionID))
        for _ in 0..<20 { assistant.suggest("Quel est le sujet actuel ?") }
        assistant.suggest("Une vingt-et-unième demande refusée")
        await wait()
        precondition(!assistant.thinking && assistant.cloudRequests == 20 && assistant.answerError != nil)
        var delayedGate: CheckedContinuation<Void, Never>?
        let delayed = CallAssistant(automaticGenerator: { _ in preconditionFailure("Unexpected local fallback") },
            cloudAutomaticGenerator: { evidence, _ in
                if evidence.question.contains("première") { await withCheckedContinuation { delayedGate = $0 } }
                return CallUnderstoodReply(canAnswer: true, understoodQuestion: evidence.question, answer: "Une proposition complète.")
            }, questionDelay: .milliseconds(5), cloudInterval: 0.2)
        delayed.beginSession()
        precondition(delayed.authorizeCloud(route, sessionID: delayed.sessionID))
        delayed.receive("Quelle est la première version ?", final: true)
        await eventually { delayedGate != nil }
        delayed.receive("Quelle est la deuxième version ?", final: true)
        delayed.receive("Je vous écoute à nouveau.", final: true)
        delayedGate?.resume(); delayedGate = nil
        await eventually { delayed.question.contains("deuxième") && !delayed.understanding }
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
