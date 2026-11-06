import Foundation
import Security

enum IntelligenceProvider: String, CaseIterable, Identifiable {
    case apple, openai, anthropic
    var id: String { rawValue }
    var title: String { switch self { case .apple: return "Apple Intelligence · local"; case .openai: return "OpenAI · clé API"; case .anthropic: return "Claude · clé API" } }
    var host: String? { switch self { case .apple: return nil; case .openai: return "api.openai.com"; case .anthropic: return "api.anthropic.com" } }
    var keyURL: URL { URL(string: self == .anthropic ? "https://platform.claude.com/settings/keys" : "https://platform.openai.com/api-keys")! }
}

/// Separate from login sessions and never shared through iCloud, defaults or the library.
struct IntelligenceKeychain {
    let service: String
    init(service: String = (Bundle.main.bundleIdentifier ?? "app.sandro.nino") + ".intelligence.api") { self.service = service }
    private func query(_ provider: IntelligenceProvider) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: provider.rawValue, kSecAttrSynchronizable as String: false]
    }
    func read(_ provider: IntelligenceProvider) throws -> String? {
        var q = query(provider); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?; let result = SecItemCopyMatching(q as CFDictionary, &value)
        if result == errSecItemNotFound { return nil }
        guard result == errSecSuccess, let data = value as? Data, data.count <= 4096, let key = String(data: data, encoding: .utf8) else { throw NinoError("Impossible de lire la clé dans le Trousseau. Autorise Nino dans macOS puis réessaie.") }
        return key
    }
    func save(_ key: String, for provider: IntelligenceProvider) throws {
        guard provider != .apple else { throw NinoError("Apple Intelligence ne nécessite pas de clé.") }
        try IntelligenceAPI.validateKey(key)
        let value = [kSecValueData as String: Data(key.utf8)]
        let result = SecItemUpdate(query(provider) as CFDictionary, value as CFDictionary)
        if result == errSecItemNotFound {
            var q = query(provider); q.merge(value) { _, new in new }
            // Classic macOS login Keychain: protected by its access control and lock state.
            q[kSecAttrLabel as String] = "Nino · " + provider.title
            guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw NinoError("Le Trousseau n’a pas enregistré la clé.") }
        } else if result != errSecSuccess { throw NinoError("Le Trousseau n’a pas mis à jour la clé.") }
    }
    func remove(_ provider: IntelligenceProvider) throws {
        let result = SecItemDelete(query(provider) as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else { throw NinoError("La clé n’a pas pu être retirée du Trousseau.") }
    }
}

/// Fixed HTTPS origins, no redirects/cookies/cache/retries, bounded response, no tools.
final class IntelligenceAPI: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let responseLimit = 1_048_576
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    static func validateKey(_ key: String) throws {
        guard (12...4096).contains(key.utf8.count), key.utf8.allSatisfy({ $0 >= 33 && $0 <= 126 }) else { throw NinoError("La clé doit contenir uniquement des caractères ASCII sans espace ni retour à la ligne.") }
    }
    static func request(provider: IntelligenceProvider, key: String, model: String? = nil, instructions: String = "", input: String? = nil) throws -> URLRequest {
        try validateKey(key)
        guard let host = provider.host else { throw NinoError("Le fournisseur local n’utilise pas le réseau.") }
        var request = URLRequest(url: URL(string: "https://\(host)/v1/\(input == nil ? "models" : provider == .openai ? "responses" : "messages")")!)
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if provider == .anthropic { request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version") }
        if let input {
            guard let model, !model.isEmpty, model.count <= 128, model.utf8.allSatisfy({ $0 >= 33 && $0 <= 126 }), input.count <= 12000, instructions.count <= 4000 else { throw NinoError("Choisis un modèle et limite le texte à 12 000 caractères.") }
            request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = provider == .openai
                ? ["model": model, "instructions": instructions, "input": input, "max_output_tokens": 2048, "store": false]
                : ["model": model, "system": instructions, "messages": [["role": "user", "content": input]], "max_tokens": 2048]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }
    func send(_ request: URLRequest) async throws -> Data {
        let config = URLSessionConfiguration.ephemeral; config.httpCookieStorage = nil; config.urlCache = nil
        config.timeoutIntervalForRequest = 60; config.timeoutIntervalForResource = 90
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw NinoError("Réponse API invalide.") }
        try Self.validateStatus(response.statusCode)
        guard response.expectedContentLength <= Self.responseLimit else { throw NinoError("Réponse API trop volumineuse.") }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < Self.responseLimit else { throw NinoError("Réponse API trop volumineuse.") }
            data.append(byte)
        }
        return data
    }
    static func validateStatus(_ status: Int) throws {
        guard (200..<300).contains(status) else {
            let message: String
            switch status {
            case 401: message = "Clé refusée. Vérifie la clé API du fournisseur."
            case 402, 429: message = "Quota, crédit API ou limite de fréquence atteint. Vérifie ton compte fournisseur ; Nino ne réessaie pas automatiquement."
            case 403: message = "Ce compte API n’a pas accès à cette ressource."
            case 400, 404: message = "Le modèle ou la demande n’est pas accepté. Choisis un modèle de texte compatible."
            case 300..<400: message = "Redirection API refusée pour protéger ta clé."
            default: message = "Service API indisponible (HTTP \(status)). Réessaie plus tard."
            }
            throw NinoError(message)
        }
    }
    static func text(from data: Data, provider: IntelligenceProvider) throws -> String {
        guard data.count <= responseLimit, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw NinoError("Réponse API invalide.") }
        var blocks: [[String: Any]] = []
        if provider == .openai {
            guard object["status"] as? String == "completed" else { throw NinoError("Réponse OpenAI incomplète ou refusée. Raccourcis la demande avant de réessayer.") }
            blocks = (object["output"] as? [[String: Any]] ?? []).filter { $0["type"] as? String == "message" }.flatMap { $0["content"] as? [[String: Any]] ?? [] }
        } else {
            guard object["stop_reason"] as? String != "max_tokens" else { throw NinoError("Réponse Claude tronquée. Raccourcis la demande avant de réessayer.") }
            blocks = object["content"] as? [[String: Any]] ?? []
        }
        let text = blocks.filter { $0["type"] as? String == (provider == .openai ? "output_text" : "text") }.compactMap { $0["text"] as? String }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw NinoError("Le fournisseur n’a renvoyé aucun texte utilisable.") }
        return text
    }
    static func models(from data: Data, provider: IntelligenceProvider) throws -> [String] {
        guard data.count <= responseLimit, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let rows = object["data"] as? [[String: Any]] else { throw NinoError("Liste de modèles invalide.") }
        return Array(Set(rows.compactMap { $0["id"] as? String }.filter {
            $0.count <= 128 && (provider == .anthropic || $0.hasPrefix("gpt-") || $0.hasPrefix("o1") || $0.hasPrefix("o3") || $0.hasPrefix("o4"))
        })).sorted()
    }
}
