import Foundation

// Everything the sign-in screen and the app shell need beyond e-mail + password (cafbio-mobile: routes-auth.php, routes-push.php, routes-owner-core.php).
// Endpoints answer {error:false, tokens, me, …}; a refused sign-in answers {error:true, code, message} with codes such as provider_off,
// invalid_identity, no_account, unlinked, email_unverified, closed, disabled, twofa, bad_code, invalid_code, rate (CashierError carries them; the message is already in the app's language).

/// Which sign-in methods the admin switched on (`GET config` → `social`). Buttons appear only for the ones that are true.
struct OwnerSocialFlags: Decodable, Equatable, Sendable {
    var apple = false, google = false, x = false, snapchat = false, microsoft = false, whatsappOtp = false, email = true
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        apple = c.flexBool(.apple) ?? false; google = c.flexBool(.google) ?? false; x = c.flexBool(.x) ?? false; snapchat = c.flexBool(.snapchat) ?? false
        microsoft = c.flexBool(.microsoft) ?? false; whatsappOtp = c.flexBool(.whatsappOtp) ?? false; email = c.flexBool(.email) ?? true
    }
    enum K: String, CodingKey { case apple, google, x, snapchat, microsoft, whatsappOtp, email }
    /// The OAuth providers that use the server-side flow (PKCE in the browser sheet, one-time code back through the app scheme).
    var oauthProviders: [OwnerOAuthProvider] { OwnerOAuthProvider.allCases.filter { enabled($0) } }
    func enabled(_ p: OwnerOAuthProvider) -> Bool { switch p { case .x: x; case .snapchat: snapchat; case .microsoft: microsoft } }
}

enum OwnerOAuthProvider: String, CaseIterable, Identifiable, Sendable {
    case x, snapchat, microsoft
    var id: String { rawValue }
}

/// One app's version rules (`config.apps.owner`). `min` is the oldest build the server still talks to; `force` makes `latest` mandatory too.
struct OwnerAppVersion: Decodable, Equatable, Sendable {
    var min = "1.0.0", latest = "1.0.0", force = false, notesAr = "", notesEn = ""
    init() {}
    init(min: String, latest: String, force: Bool, notesAr: String = "", notesEn: String = "") { self.min = min; self.latest = latest; self.force = force; self.notesAr = notesAr; self.notesEn = notesEn }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        min = c.string(.min) ?? "1.0.0"; latest = c.string(.latest) ?? min; force = c.flexBool(.force) ?? false; notesAr = c.string(.notesAr) ?? ""; notesEn = c.string(.notesEn) ?? ""
    }
    enum K: String, CodingKey { case min, latest, force, notesAr, notesEn }
}

/// `GET /api/app/v1/config`: public, no sign-in needed.
struct OwnerServerConfig: Decodable, Equatable, Sendable {
    var api = 1
    var site = ""
    var owner = OwnerAppVersion()
    var features: [String: Bool] = [:]
    var social = OwnerSocialFlags()
    var googleIosClientId = ""

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        api = c.flexInt(.api) ?? 1; site = c.string(.site) ?? ""
        if let apps = try? c.decode([String: OwnerAppVersion].self, forKey: .apps), let o = apps["owner"] { owner = o }
        features = (try? c.decode([String: FlexFlag].self, forKey: .features))?.mapValues(\.value) ?? [:]
        social = (try? c.decode(OwnerSocialFlags.self, forKey: .social)) ?? OwnerSocialFlags()
        googleIosClientId = c.string(.googleIosClientId) ?? ""
    }
    enum K: String, CodingKey { case api, site, apps, features, social, googleIosClientId }

    private struct FlexFlag: Decodable { let value: Bool
        init(from d: Decoder) throws { let c = try d.singleValueContainer(); value = (try? c.decode(Bool.self)) ?? ((try? c.decode(Int.self)).map { $0 != 0 } ?? false) } }

    func feature(_ key: String, default value: Bool = false) -> Bool { features[key] ?? value }
}

/// Answer of `auth/otp/send`.
struct OwnerOTPChallenge: Decodable, Equatable, Sendable {
    var challenge: String
    var expiresIn: Int
    var masked: String
}

/// A shortcut for the floating button (`GET quick-actions` → `items`).
struct OwnerQuickAction: Decodable, Equatable, Identifiable, Sendable {
    var key: String
    var title: String
    var icon: String
    var url: String
    var hint: String
    var kind: String
    var id: String { key }
    init(key: String, title: String, icon: String = "zap", url: String = "", hint: String = "", kind: String = "link") { self.key = key; self.title = title; self.icon = icon; self.url = url; self.hint = hint; self.kind = kind }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        key = c.string(.key) ?? ""; title = c.string(.title) ?? key; icon = c.string(.icon) ?? "zap"; url = c.string(.url) ?? ""; hint = c.string(.hint) ?? ""; kind = c.string(.kind) ?? "link"
    }
    enum K: String, CodingKey { case key, title, icon, url, hint, kind }
}
private struct OwnerQuickActionsResponse: Decodable { var items: [OwnerQuickAction] }
private struct OwnerOAuthStart: Decodable { var url: String; var state: String }
private struct OwnerWebSession: Decodable { var url: String }

extension OwnerSession {
    // MARK: public configuration

    func config() async throws -> OwnerServerConfig { try decode(OwnerServerConfig.self, try await perform("config", method: "GET", body: nil, auth: false)) }

    // MARK: sign in with an identity from the phone

    /// Sign in with Apple. `identityToken` is the JWT, `nonce` the RAW nonce whose SHA-256 went into the request (the server accepts either form).
    func loginWithApple(identityToken: String, authorizationCode: String?, nonce: String, givenName: String?, familyName: String?, deviceName: String) async throws -> OwnerMe {
        var body: [String: Any] = ["identity_token": identityToken, "nonce": nonce, "device_id": deviceId, "device_name": deviceName, "app": "owner"]
        if let authorizationCode { body["authorization_code"] = authorizationCode }
        // Apple sends the name only on the very first authorisation; the server stores it when it creates the account.
        if givenName != nil || familyName != nil { body["full_name"] = ["given": givenName ?? "", "family": familyName ?? ""] }
        return try await adoptSignIn(try await perform("auth/apple", method: "POST", body: body, auth: false))
    }

    /// Google: the `id_token` comes from the PKCE exchange done by the app (no Google SDK); `nonce` is the raw value sent in the authorisation request.
    func loginWithGoogle(idToken: String, nonce: String, deviceName: String) async throws -> OwnerMe {
        let body: [String: Any] = ["id_token": idToken, "nonce": nonce, "device_id": deviceId, "device_name": deviceName, "app": "owner"]
        return try await adoptSignIn(try await perform("auth/google", method: "POST", body: body, auth: false))
    }

    // MARK: OAuth through the server (X, Snapchat, Microsoft)

    /// The provider's authorisation page. The browser sheet ends on `<scheme>://auth?code=…` (or `?error=…`).
    /// `codeChallenge` is the S256 challenge of a verifier the app keeps for `oauthFinish`: the custom URL scheme is not exclusive on iOS,
    /// so the one-time code alone must be worthless to another app (the server refuses a start without it).
    func oauthStart(_ provider: OwnerOAuthProvider, codeChallenge: String) async throws -> URL {
        let challenge = codeChallenge.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? codeChallenge
        let data = try await perform("auth/oauth/\(provider.rawValue)/start?device_id=\(deviceId)&code_challenge=\(challenge)", method: "GET", body: nil, auth: false)
        guard let url = URL(string: try decode(OwnerOAuthStart.self, data).url), url.scheme == "https" else { throw CashierError.malformed(status: 200) }
        return url
    }

    func oauthFinish(code: String, codeVerifier: String, deviceName: String) async throws -> OwnerMe {
        let body: [String: Any] = ["code": code, "code_verifier": codeVerifier, "device_id": deviceId, "device_name": deviceName, "app": "owner"]
        return try await adoptSignIn(try await perform("auth/oauth/finish", method: "POST", body: body, auth: false))
    }

    // MARK: WhatsApp code (no session needed)

    func otpSend(phone: String) async throws -> OwnerOTPChallenge {
        try decode(OwnerOTPChallenge.self, try await perform("auth/otp/send", method: "POST", body: ["phone": phone], auth: false))
    }

    func otpVerify(challenge: String, code: String, deviceName: String) async throws -> OwnerMe {
        let body: [String: Any] = ["challenge": challenge, "code": code, "device_id": deviceId, "device_name": deviceName, "app": "owner"]
        return try await adoptSignIn(try await perform("auth/otp/verify", method: "POST", body: body, auth: false))
    }

    private func adoptSignIn(_ data: Data) async throws -> OwnerMe {
        let r = try decode(OwnerAuthResponse.self, data)
        adopt(r.tokens)
        guard let me = r.me else { throw CashierError.malformed(status: 200) }
        return me
    }

    // MARK: website hand-off and shortcuts

    /// One-time URL that opens the website already signed in, on `path` (e.g. `/user/bio`). The page is shown in a web view.
    func webSessionURL(path: String) async throws -> URL {
        let data = try await post("auth/web-session", ["path": path])
        guard let url = URL(string: try decode(OwnerWebSession.self, data).url) else { throw CashierError.malformed(status: 200) }
        return url
    }

    func quickActions() async throws -> [OwnerQuickAction] {
        try decode(OwnerQuickActionsResponse.self, try await get("quick-actions")).items.filter { !$0.key.isEmpty }
    }
}
