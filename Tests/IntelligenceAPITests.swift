import Foundation

@main struct IntelligenceAPITests {
    static func main() async throws {
        let key = "synthetic-test-only-key"
        for provider in [IntelligenceProvider.openai, .anthropic] {
            let models = try IntelligenceAPI.request(provider: provider, key: key)
            precondition(models.url?.scheme == "https" && models.url?.host == provider.host)
            precondition(models.httpBody == nil && models.url?.path == "/v1/models")
            let request = try IntelligenceAPI.request(provider: provider, key: key, model: "test-model", instructions: "fixed-system", input: "synthetic text only")
            precondition(request.httpMethod == "POST" && request.url?.host == provider.host)
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + key)
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            precondition(body["tools"] == nil && body["model"] as? String == "test-model")
            if provider == .openai { precondition(body["store"] as? Bool == false && body["input"] as? String == "synthetic text only") }
            else { precondition(request.value(forHTTPHeaderField: "anthropic-version") == "2026-10-21" && body["max_tokens"] as? Int == 2048) }
        }
        for bad in ["", "short", "a key with whitespace", "bad\r\ninjected: value", String(repeating: "x", count: 4097)] {
            do { try IntelligenceAPI.validateKey(bad); fatalError("invalid credential accepted") } catch is NinoError {}
        }
        do { _ = try IntelligenceAPI.request(provider: .apple, key: key); fatalError("local routed to network") } catch is NinoError {}
        do { _ = try IntelligenceAPI.request(provider: .openai, key: key, model: "m", input: String(repeating: "x", count: 12001)); fatalError("oversize prompt") } catch is NinoError {}
        let openai = Data(#"{"status":"completed","output":[{"type":"reasoning","summary":[]},{"type":"message","content":[{"type":"output_text","text":"Réponse test"}]}]}"#.utf8)
        let anthropic = Data(#"{"stop_reason":"end_turn","content":[{"type":"text","text":"Réponse test"}]}"#.utf8)
        let a = try IntelligenceAPI.text(from: openai, provider: .openai)
        let b = try IntelligenceAPI.text(from: anthropic, provider: .anthropic)
        precondition(a == "Réponse test" && b == a)
        for (provider, data) in [(IntelligenceProvider.openai, Data(#"{"status":"incomplete","output":[]}"#.utf8)), (.anthropic, Data(#"{"stop_reason":"max_tokens","content":[]}"#.utf8)), (.openai, Data("{}".utf8))] {
            do { _ = try IntelligenceAPI.text(from: data, provider: provider); fatalError("incomplete response accepted") } catch is NinoError {}
        }
        for status in [301, 302, 307, 308, 400, 401, 403, 404, 429, 500] {
            do { try IntelligenceAPI.validateStatus(status); fatalError("HTTP error accepted") } catch is NinoError {}
        }
        let listing = Data(#"{"data":[{"id":"gpt-test"},{"id":"gpt-test"},{"id":"whisper-1"}]}"#.utf8)
        let result = try IntelligenceAPI.models(from: listing, provider: .openai)
        precondition(result == ["gpt-test"])
        let http = IntelligenceAPI()
        let destination = URLRequest(url: URL(string: "https://attacker.invalid")!)
        let response = HTTPURLResponse(url: URL(string: "https://api.openai.com/v1/models")!, statusCode: 302, httpVersion: nil, headerFields: ["Location":"https://attacker.invalid"])!
        let session = URLSession(configuration: .ephemeral); defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: URL(string: "https://api.openai.com/v1/models")!)
        var refused = false
        http.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: destination) { refused = $0 == nil }
        precondition(refused)
        if ProcessInfo.processInfo.environment["NINO_KEYCHAIN_SMOKE"] == "1" {
            let keys = IntelligenceKeychain(service: "app.sandro.nino.test." + UUID().uuidString)
            defer { try? keys.remove(.openai); try? keys.remove(.anthropic) }
            try keys.save(key, for: .openai)
            let read = try keys.read(.openai); let other = try keys.read(.anthropic)
            precondition(read == key && other == nil)
            try keys.save("synthetic-replacement-only", for: .openai)
            let replaced = try keys.read(.openai); precondition(replaced == "synthetic-replacement-only")
            try keys.remove(.openai); let removed = try keys.read(.openai); precondition(removed == nil)
            print("PASS isolated macOS Keychain save/read/replace/remove; synthetic key only")
        }
        print("PASS API contracts, local isolation, credential validation, bounded prompts, errors, parsing and redirect refusal. No provider contacted.")
    }
}
