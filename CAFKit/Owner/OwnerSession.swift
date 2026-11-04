import Foundation

/// The owner's API client (`/api/app/v1`). An actor: it owns the token pair and serialises refreshes.
///  - Access tokens live 15 minutes; refresh tokens are ROTATED on every use. The new pair is written to the Keychain before anything else happens,
///    and concurrent callers share one refresh (a second use of an old refresh token would make the server revoke the whole sign-in).
///  - A 401 `auth` on a request triggers one refresh and one replay; a failed refresh signs the owner out.
///  - Tokens, e-mail and password are never logged.
actor OwnerSession {
    private let base: URL
    private let transport: HTTPTransport
    private let secrets: SecretStoring
    private let now: @Sendable () -> Date
    private var tokens: OwnerTokenPair?
    private var language = "ar"
    private var refreshing: Task<Void, Error>?
    static let account = "owner.tokens"
    let deviceId: String

    init(baseURL: URL = AppConfig.serverBaseURL, transport: HTTPTransport = URLSessionTransport(), secrets: SecretStoring = Keychain(), now: @escaping @Sendable () -> Date = { Date() }) {
        self.base = baseURL; self.transport = transport; self.secrets = secrets; self.now = now
        if let d = secrets.read(Self.account), let t = try? JSONDecoder().decode(OwnerTokenPair.self, from: d) { tokens = t }
        if let d = secrets.read("owner.device"), let s = String(data: d, encoding: .utf8) { deviceId = s }
        else { let s = UUID().uuidString; secrets.write(Data(s.utf8), account: "owner.device"); deviceId = s }
    }

    var isSignedIn: Bool { tokens != nil }
    /// Cheap synchronous hint for the cashier's «More» screen (is there an owner sign-in on this device?).
    nonisolated static func hasStoredTokens(secrets: SecretStoring = Keychain()) -> Bool { secrets.read(account) != nil }
    func setLanguage(_ code: String) { language = code == "en" ? "en" : "ar" }

    // MARK: sign in / out

    func login(email: String, password: String, deviceName: String) async throws -> OwnerMe {
        let data = try await perform("auth/login", method: "POST", body: ["email": email, "password": password, "device_id": deviceId, "device_name": deviceName], auth: false)
        let r = try decode(OwnerAuthResponse.self, data)
        adopt(r.tokens)
        guard let me = r.me else { throw CashierError.malformed(status: 200) }
        return me
    }

    func logout() async {
        if tokens != nil { _ = try? await perform("auth/logout", method: "POST", body: [:], auth: true, retried: true) }
        clearLocal()
    }

    func clearLocal() { tokens = nil; secrets.delete(Self.account) }

    // MARK: data

    func me() async throws -> OwnerMe { try decode(OwnerMeResponse.self, try await get("me")).me }
    func businesses() async throws -> [OwnerBusiness] { try decode(OwnerBusinessesResponse.self, try await get("businesses")).businesses }
    func overview(_ business: Int) async throws -> OwnerOverview { try decode(OwnerOverview.self, try await get("businesses/\(business)/overview")) }
    func team(_ business: Int) async throws -> OwnerTeam { try decode(OwnerTeam.self, try await get("businesses/\(business)/team")) }
    func devices() async throws -> [OwnerDevice] { try decode(OwnerDevicesResponse.self, try await get("auth/devices")).devices }
    func revokeDevice(_ id: Int) async throws { _ = try await post("auth/devices/\(id)/revoke", [:]) }

    func createBranch(_ business: Int, name: String, address: String?) async throws -> OwnerTeam {
        var b: [String: Any] = ["name": name]; if let address, !address.isEmpty { b["address"] = address }
        return try decode(OwnerTeam.self, try await post("businesses/\(business)/branches", b))
    }
    func toggleBranch(_ business: Int, branch: Int) async throws -> OwnerTeam { try decode(OwnerTeam.self, try await post("businesses/\(business)/branches/\(branch)/toggle", [:])) }
    func rotateBranchLink(_ business: Int, branch: Int) async throws -> OwnerTeam { try decode(OwnerTeam.self, try await post("businesses/\(business)/branches/\(branch)/rotate-link", [:])) }
    func createStaff(_ business: Int, name: String, role: String, branch: Int?) async throws -> OwnerTeam {
        var b: [String: Any] = ["name": name, "role": role]; if let branch { b["branch_id"] = branch }
        return try decode(OwnerTeam.self, try await post("businesses/\(business)/staff", b))
    }
    func resetStaffPin(_ business: Int, staff: Int) async throws -> OwnerTeam { try decode(OwnerTeam.self, try await post("businesses/\(business)/staff/\(staff)/pin-reset", [:])) }
    func toggleStaff(_ business: Int, staff: Int) async throws -> OwnerTeam { try decode(OwnerTeam.self, try await post("businesses/\(business)/staff/\(staff)/toggle", [:])) }

    // MARK: plumbing

    private func get(_ path: String) async throws -> Data { try await perform(path, method: "GET", body: nil, auth: true) }
    private func post(_ path: String, _ body: [String: Any]) async throws -> Data { try await perform(path, method: "POST", body: body, auth: true) }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder.api.decode(T.self, from: data) } catch { throw CashierError.malformed(status: 200) }
    }

    private func request(_ path: String, method: String, body: [String: Any]?, token: String?) throws -> URLRequest {
        var url = base.appendingPathComponent("api/app/v1")
        for part in path.split(separator: "/") { url.appendPathComponent(String(part)) }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.httpShouldHandleCookies = false
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue(language, forHTTPHeaderField: "Accept-Language")
        if let token {
            r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            r.setValue(token, forHTTPHeaderField: "X-Caf-Token")        // some hosts strip Authorization before PHP; the server reads either
        }
        if method == "POST" {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body ?? [:])
        }
        return r
    }

    @discardableResult
    private func perform(_ path: String, method: String, body: [String: Any]?, auth: Bool, retried: Bool = false) async throws -> Data {
        var token: String?
        if auth {
            guard tokens != nil else { throw CashierError.api(.auth, "", status: 401) }
            if let t = tokens, t.accessExpiresAt.timeIntervalSince(now()) < 20 { try await refreshTokens() }       // proactive: no wasted 401
            token = tokens?.access
        }
        let req = try request(path, method: method, body: body, token: token)
        let data: Data, http: HTTPURLResponse
        do { (data, http) = try await transport.send(req) } catch is CancellationError { throw CancellationError() } catch { throw CashierError.offline }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if !((json?["error"] as? Bool) == true || http.statusCode >= 400) { return data }
        guard let json else { throw CashierError.malformed(status: http.statusCode) }
        let err = CashierError.from(json: json, status: http.statusCode)
        if err.code == .auth, auth, !retried, tokens != nil {
            try await refreshTokens(after: token)
            return try await perform(path, method: method, body: body, auth: auth, retried: true)
        }
        throw err
    }

    /// One refresh at a time. `after` = the access token that just failed: when another caller already rotated past it, just retry with the new one.
    private func refreshTokens(after failed: String? = nil) async throws {
        if let failed, let cur = tokens?.access, cur != failed { return }
        if let r = refreshing { return try await r.value }
        let task = Task { try await self.doRefresh() }
        refreshing = task
        defer { refreshing = nil }
        try await task.value
    }

    private func doRefresh() async throws {
        guard let refresh = tokens?.refresh else { throw CashierError.api(.auth, "", status: 401) }
        let req = try request("auth/refresh", method: "POST", body: ["refresh": refresh], token: nil)
        let data: Data, http: HTTPURLResponse
        do { (data, http) = try await transport.send(req) } catch { throw CashierError.offline }          // offline: keep the tokens, try again later
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if (json?["error"] as? Bool) == true || http.statusCode >= 400 {
            let err = json.map { CashierError.from(json: $0, status: http.statusCode) } ?? CashierError.malformed(status: http.statusCode)
            if http.statusCode >= 500 || err.code == .rate { throw err }
            clearLocal()                                                                                  // refused (expired / revoked / reused): signed out
            throw CashierError.api(.auth, "", status: 401)
        }
        adopt(try decode(OwnerAuthResponse.self, data).tokens)
    }

    private func adopt(_ t: OwnerAuthResponse.Tokens) {
        let pair = OwnerTokenPair(access: t.access, refresh: t.refresh, accessExpiresAt: now().addingTimeInterval(TimeInterval(t.expiresIn)), refreshExpiresAt: now().addingTimeInterval(TimeInterval(t.refreshExpiresIn)))
        tokens = pair
        if let d = try? JSONEncoder().encode(pair) { secrets.write(d, account: Self.account) }
    }
}
