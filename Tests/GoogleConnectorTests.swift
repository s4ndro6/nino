import Foundation
#if canImport(AppAuth)
import AppAuth
#endif

@main struct GoogleDesktopTests {
    @MainActor static func main() throws {
        let client = "fixture-client.apps.googleusercontent.com"
        for values: [String: Any] in [[:], ["client_id":"bad"], ["client_id":"x.apps.googleusercontent.com.evil"], ["client_id":"YOUR.apps.googleusercontent.com"], ["client_id":"a b.apps.googleusercontent.com"], ["client_id":client,"client_secret":"a\nb"]] {
            precondition(GoogleAccount.configurationIssue(info: values) != nil)
        }
        precondition(GoogleAccount.configurationIssue(info:["client_id":client]) == nil)
        precondition(GoogleAccount.configurationIssue(info:["client_id":client,"client_secret":"fixture-public-desktop-value"]) == nil)
        let raw = NSError(domain:"server",code:400,userInfo:[NSLocalizedDescriptionKey:"access_token=SECRET"])
        precondition(!GoogleAccount.safeError(raw).contains("SECRET"))
        let fresh = GoogleAccount()
        precondition(fresh.identity == nil && !fresh.gmailAuthorized && !fresh.busy && fresh.messages.isEmpty)
        let user = GoogleHTTP.User(sub:"fixture-sub",email:"fixture@example.com",email_verified:true,name:"Fixture")
        _ = try user.validated()
        do { _ = try GoogleHTTP.User(sub:"fixture",email:"fixture@example.com",email_verified:false,name:nil).validated(); preconditionFailure("Unverified user accepted") } catch {}
        #if canImport(AppAuth)
        let service = OIDServiceConfiguration(authorizationEndpoint:GoogleHTTP.authorizationURL,tokenEndpoint:GoogleHTTP.tokenURL)
        let request = OIDAuthorizationRequest(configuration:service,clientId:client,clientSecret:nil,scopes:["openid","email","profile"],redirectURL:URL(string:"http://127.0.0.1:12345/")!,responseType:OIDResponseTypeCode,additionalParameters:nil)
        let second = OIDAuthorizationRequest(configuration:service,clientId:client,clientSecret:nil,scopes:["openid","email","profile"],redirectURL:URL(string:"http://127.0.0.1:12345/")!,responseType:OIDResponseTypeCode,additionalParameters:nil)
        precondition(request.state != second.state && request.nonce != second.nonce)
        precondition((request.codeVerifier?.count ?? 0) >= 43 && request.codeChallengeMethod == "S256")
        precondition(!request.scope!.contains("gmail"))
        let authorization = OIDAuthorizationResponse(request: request, parameters: ["code": "fixture-code" as NSString, "state": request.state! as NSString])
        let exchange = authorization.tokenExchangeRequest()!
        let grant = OIDTokenResponse(request: exchange, parameters: ["access_token": "fixture-access" as NSString, "refresh_token": "fixture-refresh" as NSString, "token_type": "Bearer" as NSString, "expires_in": NSNumber(value: 3600), "scope": ("openid email profile " + GoogleAccount.gmailScope) as NSString])
        let state = OIDAuthState(authorizationResponse: authorization, tokenResponse: grant)
        let refresh = OIDTokenResponse(request: state.tokenRefreshRequest()!, parameters: ["access_token": "fixture-new-access" as NSString, "token_type": "Bearer" as NSString, "expires_in": NSNumber(value: 3600)])
        state.update(with: refresh, error: nil)
        precondition(state.lastTokenResponse?.scope == nil)
        precondition(GoogleDesktopAuth.Session(state: state, user: user).gmailAuthorized)
        let reduced = OIDTokenResponse(request: state.tokenRefreshRequest()!, parameters: ["access_token": "fixture-reduced-access" as NSString, "token_type": "Bearer" as NSString, "expires_in": NSNumber(value: 3600), "scope": "openid email profile" as NSString])
        state.update(with: reduced, error: nil)
        precondition(!GoogleDesktopAuth.Session(state: state, user: user).gmailAuthorized)
        print("PASS Google desktop: config, safe errors, verified identity, no fake session, SDK PKCE/state/nonce minimum sign-in scopes, refresh scope preservation/reduction. No network or Keychain used.")
        #else
        print("PASS Google config/identity/fresh-state tests (SDK-specific tests not included)")
        #endif
    }
}
