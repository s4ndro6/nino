import Foundation

struct CallCloudRoute: Equatable {
    let provider: IntelligenceProvider
    let model: String
    var title: String { provider.title + " · " + model }
    var valid: Bool { provider != .apple && !model.isEmpty && model.count <= 128 && model.utf8.allSatisfy { $0 >= 33 && $0 <= 126 } }
}

enum CallCloud {
    static func generate(_ request: CallManualRequest, route: CallCloudRoute) async throws -> String {
        try await text(instructions: request.instructions, input: request.prompt, route: route)
    }
    static func understand(_ snapshot: CallAnswerSnapshot, route: CallCloudRoute) async throws -> CallUnderstoodReply {
        let instructions = CallSemanticUnderstanding.instructions + "\nRéponds uniquement avec un objet JSON à trois champs : canAnswer (booléen), understoodQuestion (chaîne), answer (chaîne). Aucun Markdown."
        let output = try await text(instructions: instructions, input: snapshot.automaticPrompt, route: route)
        return try decode(output)
    }
    static func decode(_ text: String) throws -> CallUnderstoodReply {
        guard text.utf8.count <= 10_000, let data = text.data(using: .utf8),
              let reply = try? JSONDecoder().decode(CallUnderstoodReply.self, from: data),
              reply.understoodQuestion.count <= 700,
              !reply.canAnswer || (!reply.understoodQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && CallAnswerLimits.accepted(reply.answer) != nil)
        else { throw NinoError("La réponse du fournisseur n’est pas exploitable. Aucune proposition n’a été publiée.") }
        return reply
    }
    private static func text(instructions: String, input: String, route: CallCloudRoute) async throws -> String {
        try Task.checkCancellation()
        guard route.valid, let key = try IntelligenceKeychain().read(route.provider) else {
            throw NinoError("Configure une clé API et un modèle dans Connexions avant d’activer le cloud pour cet appel.")
        }
        let request = try IntelligenceAPI.request(provider: route.provider, key: key, model: route.model, instructions: instructions, input: input)
        try Task.checkCancellation()
        let data = try await IntelligenceAPI().send(request)
        try Task.checkCancellation()
        return try IntelligenceAPI.text(from: data, provider: route.provider)
    }
}
