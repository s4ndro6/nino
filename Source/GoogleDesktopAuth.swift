import AppKit
import Foundation
import Security
#if canImport(AppAuth)
import AppAuth
#endif

struct GoogleDesktopConfiguration {
    let clientID: String
    let clientSecret: String?
    init(values: [String: Any]) throws {
        guard let id = values["client_id"] as? String,
              id.range(of: "^[A-Za-z0-9_-]+\\.apps\\.googleusercontent\\.com$", options: .regularExpression) != nil,
              !id.contains("YOUR"), !id.contains("REPLACE"), id.count < 300 else {
            throw NinoError("Google n’est pas encore activé dans cette version. Tu peux continuer sans compte.")
        }
        let secret = values["client_secret"] as? String
        guard secret == nil || (secret!.count < 512 && !secret!.contains("\n") && !secret!.contains("\r")) else {
            throw NinoError("La configuration Google de cette version est invalide.")
        }
        clientID = id; clientSecret = secret?.isEmpty == false ? secret : nil
    }
    static func load(bundle: Bundle) throws -> Self {
        // Personal publisher configuration survives an app update outside the bundle.
        // Session tokens remain in Keychain and are never read from this file.
        let local = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Nino/Configuration/GoogleDesktopOAuth.plist")
        let url = bundle.url(forResource: "GoogleDesktopOAuth", withExtension: "plist") ?? local
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.intValue < 8192,
              let data = try? Data(contentsOf: url), data.count < 8192,
              let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw NinoError("Google n’est pas encore activé dans cette version. Tu peux continuer sans compte.")
        }
        return try Self(values: values)
    }
}

/// Fixed Google endpoints. No redirect may forward a bearer token to another origin.
final class GoogleHTTP: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let authorizationURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    static let userInfoURL = URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!
    static let revokeURL = URL(string: "https://oauth2.googleapis.com/revoke")!
    lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.urlCache = nil
        config.timeoutIntervalForRequest = 20; config.timeoutIntervalForResource = 40
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    struct User: Decodable {
        let sub: String; let email: String; let email_verified: Bool; let name: String?
        func validated() throws -> Self {
            guard !sub.isEmpty, sub.count <= 255, email_verified, email.contains("@"), email.count <= 320,
                  (name?.count ?? 0) <= 500 else { throw NinoError("Google n’a pas confirmé l’identité de ce compte.") }
            return self
        }
    }
    func user(token: String) async throws -> User {
        var request = URLRequest(url: Self.userInfoURL)
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 65536 else { throw NinoError("Google n’a pas confirmé la connexion. Réessaie.") }
        return try JSONDecoder().decode(User.self, from: data).validated()
    }
    func revoke(token: String) async throws {
        var request = URLRequest(url: Self.revokeURL); request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents(); body.queryItems = [URLQueryItem(name: "token", value: token)]
        request.httpBody = body.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        let (_, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw NinoError("La révocation n’a pas été confirmée. Réessaie ou gère l’accès dans ton compte Google.") }
    }
}

/// Generic login Keychain, separate for each bundle/client. No shared access group or files.
struct GoogleSessionKeychain {
    let bundleID: String
    let clientID: String
    private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: bundleID + ".google.desktop", kSecAttrAccount as String: clientID,
        kSecAttrSynchronizable as String: false] }
    func read() throws -> Data? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, data.count < 256_000 else { throw NinoError("Le Trousseau n’a pas pu ouvrir la session Google. Réessaie en autorisant Nino dans macOS.") }
        return data
    }
    func write(_ data: Data) throws {
        guard data.count < 256_000 else { throw NinoError("La session Google est trop volumineuse.") }
        let updates = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            q[kSecAttrLabel as String] = "Nino · connexion Google"
            guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw NinoError("Le Trousseau n’a pas pu conserver la connexion Google.") }
        } else if status != errSecSuccess { throw NinoError("Le Trousseau n’a pas pu mettre à jour la connexion Google.") }
    }
    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw NinoError("La session n’a pas pu être effacée du Trousseau. Réessaie.") }
    }
}

#if canImport(AppAuth)
@MainActor final class GoogleDesktopAuth {
    struct Session {
        let state: OIDAuthState
        let user: GoogleHTTP.User
        var gmailAuthorized: Bool {
            Set((state.scope ?? "").split(separator: " ").map(String.init)).contains(GoogleAccount.gmailScope)
        }
    }
    private let configuration: GoogleDesktopConfiguration
    private let keychain: GoogleSessionKeychain
    private let http = GoogleHTTP()
    private var handler: OIDRedirectHTTPHandler?
    private var timeout: Task<Void, Never>?
    private var pending: CheckedContinuation<OIDAuthState, Error>?
    private var flowID: UUID?
    private(set) var session: Session?

    init(configuration: GoogleDesktopConfiguration, bundleID: String) {
        self.configuration = configuration
        keychain = GoogleSessionKeychain(bundleID: bundleID, clientID: configuration.clientID)
        // Only this application's AppAuth transport uses this session; it has no cookies or redirects.
        OIDURLSessionProvider.setSession(http.session)
    }
    func signIn(gmail: Bool = false) async throws -> Session {
        let expectedSubject = gmail ? session?.user.sub : nil
        if gmail && expectedSubject == nil { throw NinoError("Connecte d’abord ton compte Google.") }
        let state = try await authorize(gmail: gmail, hint: gmail ? session?.user.email : nil)
        try Task.checkCancellation()
        let token = try await freshToken(state)
        let user = try await http.user(token: token)
        try Task.checkCancellation()
        guard expectedSubject == nil || expectedSubject == user.sub else {
            throw NinoError("Tu as choisi un autre compte. Ton compte Nino reste inchangé ; reconnecte Gmail avec la même adresse.")
        }
        let result = Session(state: state, user: user)
        try save(state); session = result
        return result
    }
    func restore() async throws -> Session {
        guard let data = try keychain.read(), let state = try NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data) else {
            throw NinoError("Aucune session à reprendre. Choisis Continuer avec Google.")
        }
        guard valid(state) else { throw NinoError("La session enregistrée ne correspond pas à cette version. Reconnecte ton compte.") }
        let token = try await freshToken(state)
        let user = try await http.user(token: token)
        try Task.checkCancellation()
        try save(state)
        let restored = Session(state: state, user: user); session = restored; return restored
    }
    func accessToken() async throws -> String {
        guard let session else { throw NinoError("Reconnecte ton compte Google.") }
        let token = try await freshToken(session.state)
        try Task.checkCancellation(); try save(session.state)
        return token
    }
    func signOut() throws { cancel(); try keychain.remove(); session = nil }
    func disconnect() async throws {
        guard let session else { throw NinoError("Reconnecte ton compte Google pour révoquer ses accès.") }
        let token: String
        if let refresh = session.state.refreshToken { token = refresh } else { token = try await accessToken() }
        try await http.revoke(token: token); try Task.checkCancellation()
        try signOut()
    }
    func cancel() {
        finish(.failure(NinoError("Connexion annulée. Tes connexions existantes sont conservées.")))
    }
    private func save(_ state: OIDAuthState) throws {
        guard valid(state) else { throw NinoError("Session Google invalide.") }
        try keychain.write(NSKeyedArchiver.archivedData(withRootObject: state, requiringSecureCoding: true))
    }
    private func valid(_ state: OIDAuthState) -> Bool {
        let request = state.lastAuthorizationResponse.request
        return request.clientID == configuration.clientID && request.configuration.authorizationEndpoint == GoogleHTTP.authorizationURL
            && request.configuration.tokenEndpoint == GoogleHTTP.tokenURL && state.isAuthorized
    }
    private func freshToken(_ state: OIDAuthState) async throws -> String {
        guard valid(state) else { throw NinoError("Session Google invalide. Reconnecte ton compte.") }
        return try await withCheckedThrowingContinuation { continuation in
            state.performAction { token, _, error in
                if let token, !token.isEmpty, error == nil { continuation.resume(returning: token) }
                else { continuation.resume(throwing: NinoError("La session Google a expiré. Reconnecte ton compte.")) }
            }
        }
    }
    private func authorize(gmail: Bool, hint: String?) async throws -> OIDAuthState {
        guard pending == nil else { throw NinoError("Une connexion Google est déjà en cours.") }
        let listener = OIDRedirectHTTPHandler(successURL: nil)
        // AppAuth 2.1 marks this return nonnull, although its implementation can return nil.
        // Optional ObjC bridging keeps a local listener failure recoverable instead of trapping.
        guard let redirect = listener.perform(NSSelectorFromString("startHTTPListener:"), with: nil)?.takeUnretainedValue() as? URL else {
            listener.cancelHTTPListener(); throw NinoError("Impossible d’ouvrir le retour Google sur ce Mac.")
        }
        guard ["127.0.0.1", "[::1]", "::1"].contains(redirect.host ?? ""), redirect.scheme == "http", redirect.port != nil else {
            listener.cancelHTTPListener(); throw NinoError("Impossible d’ouvrir le retour Google sur ce Mac.")
        }
        let service = OIDServiceConfiguration(authorizationEndpoint: GoogleHTTP.authorizationURL, tokenEndpoint: GoogleHTTP.tokenURL)
        var extras = ["access_type": "offline", "prompt": gmail ? "consent" : "select_account consent"]
        if let hint { extras["login_hint"] = hint }
        let scopes = ["openid", "email", "profile"] + (gmail ? [GoogleAccount.gmailScope] : [])
        let request = OIDAuthorizationRequest(configuration: service, clientId: configuration.clientID,
            clientSecret: configuration.clientSecret, scopes: scopes, redirectURL: redirect,
            responseType: OIDResponseTypeCode, additionalParameters: extras)
        let id = UUID(); flowID = id; handler = listener
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                // Loopback flow intentionally uses the system browser, as recommended for desktop apps.
                listener.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request) { [weak self] state, error in
                    Task { @MainActor in
                        guard let self, self.flowID == id else { return }
                        if let state, error == nil { self.finish(.success(state)) }
                        else { self.finish(.failure(NinoError("Google n’a pas terminé la connexion. Tu peux réessayer."))) }
                    }
                }
                timeout = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(180))
                    guard !Task.isCancelled, let self, self.flowID == id else { return }
                    self.finish(.failure(NinoError("La connexion a expiré après trois minutes. Réessaie.")))
                }
            }
        } onCancel: { Task { @MainActor [weak self] in
            guard let self, self.flowID == id else { return }
            self.cancel()
        } }
    }
    private func finish(_ result: Result<OIDAuthState, Error>) {
        flowID = nil; timeout?.cancel(); timeout = nil
        let continuation = pending; pending = nil
        let listener = handler; handler = nil
        let flow = listener?.currentAuthorizationFlow
        listener?.currentAuthorizationFlow = nil; listener?.cancelHTTPListener(); flow?.cancel()
        continuation?.resume(with: result)
    }
}
#endif
