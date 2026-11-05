import AppKit
import Combine
import Foundation
#if canImport(AppAuth)
import AppAuth
#endif

/// Explicit Google desktop sign-in. Initialization never reads tokens, mail, or the network.
@MainActor final class GoogleAccount: ObservableObject {
    struct Identity: Equatable { let name: String; let email: String }
    struct MailPreview: Identifiable, Equatable { let id: String; let sender: String; let subject: String; let snippet: String }
    @Published private(set) var identity: Identity?
    @Published private(set) var gmailAuthorized = false
    @Published private(set) var busy = false
    @Published private(set) var activity = ""
    @Published private(set) var loadingMail = false
    @Published private(set) var canCancel = false
    @Published private(set) var messages: [MailPreview] = []
    @Published private(set) var message: String?
    @Published private(set) var issue: String?
    private var operation: Task<Void, Never>?
    private var generation = UUID()
    private let bundle: Bundle
    #if canImport(AppAuth)
    private var desktop: GoogleDesktopAuth?
    #endif
    nonisolated static let gmailScope = "https://www.googleapis.com/auth/gmail.readonly"
    init(bundle: Bundle = .main) { self.bundle = bundle }
    static func configurationIssue(info: [String: Any]) -> String? {
        do { _ = try GoogleDesktopConfiguration(values: info); return nil }
        catch { return safeError(error) }
    }
    var unavailableReason: String? {
        do { _ = try GoogleDesktopConfiguration.load(bundle: bundle) } catch { return Self.safeError(error) }
        #if canImport(AppAuth)
        return nil
        #else
        return "Le connecteur Google n’est pas inclus dans cette compilation."
        #endif
    }
    var canConnect: Bool { unavailableReason == nil && !busy }
    // The desktop flow returns through its one-shot loopback listener, never a custom scheme.
    func handle(_ url: URL) -> Bool { false }
    func signIn() { authenticate(restoring: false, gmail: false) }
    func restore() { authenticate(restoring: true, gmail: false) }
    func connectGmail() { guard identity != nil else { return }; authenticate(restoring: false, gmail: true) }
    private func authenticate(restoring: Bool, gmail: Bool) {
        guard begin(restoring ? "Reconnexion à ton compte Google…" : gmail ? "Autorise Gmail pour le compte déjà connecté…" : "Choisis ton compte dans la fenêtre Google…") else { return }
        #if canImport(AppAuth)
        let id = generation
        operation = Task { [weak self] in
            guard let self else { return }
            defer { if generation == id { busy = false; canCancel = false; activity = ""; operation = nil } }
            do {
                let auth = try transport()
                let result = try await (restoring ? auth.restore() : auth.signIn(gmail: gmail))
                try Task.checkCancellation(); guard generation == id else { return }
                identity = Identity(name: result.user.name ?? "Compte Google", email: result.user.email)
                gmailAuthorized = result.gmailAuthorized; messages = []; issue = nil
                message = gmail ? (gmailAuthorized ? "Gmail est connecté en lecture. Charge les aperçus quand tu le souhaites." : "L’accès Gmail n’a pas été accordé. Ton compte reste connecté.") : "Compte Google connecté sur ce Mac. Aucun mail n’est chargé automatiquement."
            } catch { if !Task.isCancelled && generation == id { issue = Self.safeError(error) } }
        }
        #endif
    }
    func signOut() {
        guard !busy else { return }
        #if canImport(AppAuth)
        do { try transport().signOut(); clear(); message = "Déconnecté sur ce Mac. Tu peux aussi révoquer les autorisations depuis ton compte Google." }
        catch { issue = Self.safeError(error) }
        #endif
    }
    func disconnect() {
        guard identity != nil, begin("Révocation des accès Google…", cancellable: false) else { return }
        #if canImport(AppAuth)
        let id = generation
        operation = Task { [weak self] in
            guard let self else { return }
            defer { if generation == id { busy = false; canCancel = false; activity = ""; operation = nil } }
            do {
                try await transport().disconnect(); try Task.checkCancellation(); guard generation == id else { return }
                clear(); message = "Compte déconnecté et accès Google révoqués."
            } catch { if !Task.isCancelled && generation == id { issue = Self.safeError(error) } }
        }
        #endif
    }
    func loadMail() {
        guard gmailAuthorized, begin("Lecture des cinq derniers aperçus de la boîte de réception…") else { return }
        #if canImport(AppAuth)
        let id = generation; loadingMail = true
        operation = Task { [weak self] in
            guard let self else { return }
            defer { if generation == id { busy = false; canCancel = false; loadingMail = false; activity = ""; operation = nil } }
            do {
                let auth = try transport()
                let token = try await auth.accessToken(); try Task.checkCancellation()
                guard generation == id else { return }
                gmailAuthorized = auth.session?.gmailAuthorized == true
                guard gmailAuthorized else { throw NinoError("L’accès Gmail a changé. Reconnecte Gmail pour autoriser la lecture.") }
                let loaded = try await GmailReadClient().inbox(token: token)
                try Task.checkCancellation(); guard generation == id else { return }
                messages = loaded; message = loaded.isEmpty ? "Ta boîte de réception est vide." : "Aperçus chargés en mémoire uniquement. Aucun message n’a été modifié."
            } catch { if !Task.isCancelled && generation == id { issue = Self.safeError(error) } }
        }
        #endif
    }
    func cancel() {
        guard busy, canCancel else { return }
        generation = UUID(); operation?.cancel(); operation = nil
        #if canImport(AppAuth)
        desktop?.cancel()
        #endif
        busy = false; canCancel = false; loadingMail = false; activity = ""
        message = "Action annulée. Les connexions existantes sont conservées."
    }
    func cancelMail() { if loadingMail { cancel() } }
    func clearMail() { cancelMail(); messages = []; message = "Aperçus effacés de Nino. Les mails restent dans Gmail." }
    private func begin(_ text: String, cancellable: Bool = true) -> Bool {
        guard !busy else { return false }
        if let unavailableReason { issue = unavailableReason; return false }
        generation = UUID(); busy = true; canCancel = cancellable; activity = text; message = nil; issue = nil; return true
    }
    private func clear() { identity = nil; gmailAuthorized = false; messages = []; issue = nil; activity = "" }
    static func safeError(_ error: Error) -> String {
        if let error = error as? NinoError { return error.message }
        return "La connexion a échoué. Vérifie Internet, puis réessaie."
    }
    #if canImport(AppAuth)
    private func transport() throws -> GoogleDesktopAuth {
        if let desktop { return desktop }
        guard let bundleID = bundle.bundleIdentifier else { throw NinoError("Cette version de Nino n’a pas d’identifiant d’application.") }
        let result = GoogleDesktopAuth(configuration: try GoogleDesktopConfiguration.load(bundle: bundle), bundleID: bundleID)
        desktop = result; return result
    }
    #endif
}

/// Fixed Google host, read-only methods, no cookies, caching or automatic redirects.
private final class GmailReadClient: NSObject, URLSessionTaskDelegate {
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.urlCache = nil
        config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 40
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    struct List: Decodable { var messages: [Reference]? }
    struct Reference: Decodable { var id: String }
    struct Mail: Decodable {
        var id: String; var snippet: String?; var payload: Payload?
        struct Payload: Decodable { var headers: [Header]? }
        struct Header: Decodable { var name: String; var value: String }
    }
    func inbox(token: String) async throws -> [GoogleAccount.MailPreview] {
        defer { session.invalidateAndCancel() }
        let list: List = try await get(path: "messages", query: [URLQueryItem(name: "labelIds", value: "INBOX"), URLQueryItem(name: "maxResults", value: "5")], token: token)
        var result: [GoogleAccount.MailPreview] = []
        for reference in (list.messages ?? []).prefix(5) {
            try Task.checkCancellation()
            guard !reference.id.isEmpty, reference.id.allSatisfy({ $0.isHexDigit }), reference.id.count < 128 else { throw NinoError("Réponse Gmail invalide.") }
            let mail: Mail = try await get(path: "messages/" + reference.id, query: [URLQueryItem(name: "format", value: "metadata"), URLQueryItem(name: "metadataHeaders", value: "Subject"), URLQueryItem(name: "metadataHeaders", value: "From")], token: token)
            let headers = mail.payload?.headers ?? []
            result.append(.init(id: mail.id, sender: String((headers.first { $0.name.lowercased() == "from" }?.value ?? "Expéditeur inconnu").prefix(500)), subject: String((headers.first { $0.name.lowercased() == "subject" }?.value ?? "Sans objet").prefix(500)), snippet: String((mail.snippet ?? "").prefix(1000))))
        }
        return result
    }
    private func get<T: Decodable>(path: String, query: [URLQueryItem], token: String) async throws -> T {
        var url = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/" + path)!
        url.queryItems = query
        var request = URLRequest(url: url.url!); request.httpMethod = "GET"
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NinoError("Réponse Gmail invalide.") }
        if http.statusCode == 401 { throw NinoError("La session Google a expiré. Reconnecte ton compte.") }
        if http.statusCode == 403 { throw NinoError("Gmail n’a pas autorisé la lecture. Vérifie l’autorisation du compte ; l’éditeur doit aussi activer Gmail pour cette version.") }
        guard (200..<300).contains(http.statusCode), data.count <= 1_000_000 else { throw NinoError("Gmail est indisponible pour le moment. Réessaie plus tard.") }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
