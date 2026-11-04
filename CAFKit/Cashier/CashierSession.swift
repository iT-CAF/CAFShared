import Foundation
import CryptoKit

/// Persisted part of a signed-in cashier session (Keychain only): the signed cookie + the CSRF token.
struct StoredCashierSession: Codable, Equatable, Sendable {
    var cookieName: String
    var cookieValue: String
    var csrf: String
    var staffId: Int
}

/// One branch's API client. An actor: it owns the cookie + CSRF state and serialises refreshes.
///  - Cookies are NOT left to URLSession: the `Set-Cookie` is read from the answer and sent back as a header, and both
///    cookie and CSRF are kept in the Keychain so the session survives relaunches (re-injected at start).
///  - A 419 `csrf` on a POST triggers one silent `me()` re-init and a single retry.
///  - The token (secret link) is never logged.
actor CashierSession {
    let token: String
    private let base: URL
    private let transport: HTTPTransport
    private let secrets: SecretStoring
    private var stored: StoredCashierSession?
    private var language: String = "ar"
    private let account: String

    init(token: String, baseURL: URL = AppConfig.serverBaseURL, transport: HTTPTransport = URLSessionTransport(), secrets: SecretStoring = Keychain()) {
        self.token = token
        self.base = baseURL
        self.transport = transport
        self.secrets = secrets
        self.account = CashierSession.account(for: token)
        if let d = secrets.read(account), let s = try? JSONDecoder().decode(StoredCashierSession.self, from: d) { stored = s }
    }

    static func account(for token: String) -> String {
        let h = SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
        return "cashier.session." + h.prefix(24)
    }

    var hasStoredSession: Bool { stored != nil }
    var storedStaffId: Int? { stored?.staffId }
    func setLanguage(_ code: String) { language = code == "en" ? "en" : "ar" }

    // MARK: session

    func staff() async throws -> StaffListResponse { try await get("staff") }

    func login(staffId: Int, pin: String) async throws -> SessionInfo {
        let info: SessionInfo = try await post("login", ["staff": staffId, "pin": pin], auth: false)
        // The cookie was captured by `perform`; pair it with the CSRF of this answer.
        if var s = stored { s.csrf = info.csrf; s.staffId = info.staff.id; persist(s) }
        return info
    }

    /// Restores the session. `nil` = signed out (the server answers 200 `code:auth` in soft mode; a 401 is treated the same).
    func me() async throws -> SessionInfo? {
        do {
            let info: SessionInfo = try await get("me")
            if var s = stored { s.csrf = info.csrf; s.staffId = info.staff.id; persist(s) }
            return info
        } catch let e as CashierError where e.isAuth {
            clearLocal()
            return nil
        }
    }

    func logout() async {
        _ = try? await perform("logout", method: "POST", body: [:], auth: true, retried: true)
        clearLocal()
    }

    /// Forget everything about this branch session on this device (does not call the server).
    func clearLocal() { stored = nil; secrets.delete(account) }

    // MARK: operations

    func lookup(q: String) async throws -> LookupOutcome {
        let r: LookupResponse = try await post("lookup", ["q": q])
        guard let o = r.outcome else { throw CashierError.api(.notFound, "", status: 404) }
        return o
    }
    func lookup(memberId: Int) async throws -> LookupOutcome {
        let r: LookupResponse = try await post("lookup", ["member": memberId])
        guard let o = r.outcome else { throw CashierError.api(.notFound, "", status: 404) }
        return o
    }
    func quote(memberId: Int, amount: Double?) async throws -> Quote {
        var b: [String: Any] = ["member": memberId]
        if let amount { b["amount"] = amount }
        return (try await post("quote", b) as QuoteResponse).quote
    }
    func earn(memberId: Int, amount: Double?, qty: Int?, idem: String, note: String? = nil, force: Bool = false) async throws -> EarnResult {
        var b: [String: Any] = ["member": memberId, "idem": idem]
        if let amount { b["amount"] = amount }
        if let qty { b["qty"] = qty }
        if let note, !note.isEmpty { b["note"] = note }
        if force { b["force"] = true }
        return try await post("earn", b)
    }
    func redeem(memberId: Int, rewardId: Int?, tier: Int, code: String?, idem: String, note: String? = nil) async throws -> RedeemResult {
        var b: [String: Any] = ["member": memberId, "tier": tier, "idem": idem]
        if let rewardId { b["reward_id"] = rewardId }
        if let code, !code.isEmpty { b["code"] = code }
        if let note, !note.isEmpty { b["note"] = note }
        return try await post("redeem", b)
    }
    func undo(txId: Int, note: String? = nil) async throws -> UndoResult {
        var b: [String: Any] = ["tx": txId]
        if let note, !note.isEmpty { b["note"] = note }
        return try await post("undo", b)
    }
    func sync(ops: [[String: Any]]) async throws -> SyncResponse { try await post("sync", ["ops": ops]) }
    func heartbeat() async throws -> Heartbeat { try await post("biz/heartbeat", [:]) }

    // MARK: plumbing

    func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await perform(path, method: "GET", body: nil, auth: true, retried: true)
        return try decode(data)
    }
    func post<T: Decodable>(_ path: String, _ body: [String: Any], auth: Bool = true) async throws -> T {
        let data = try await perform(path, method: "POST", body: body, auth: auth, retried: false)
        return try decode(data)
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try JSONDecoder.api.decode(T.self, from: data) } catch { throw CashierError.malformed(status: 200) }
    }

    private func request(_ path: String, method: String, body: [String: Any]?, auth: Bool) throws -> URLRequest {
        var url = base.appendingPathComponent("cashier").appendingPathComponent(token).appendingPathComponent("api")
        let halves = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        for part in halves[0].split(separator: "/") { url.appendPathComponent(String(part)) }
        if halves.count > 1, var uc = URLComponents(url: url, resolvingAgainstBaseURL: false) { uc.percentEncodedQuery = String(halves[1]); url = uc.url ?? url }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.httpShouldHandleCookies = false
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue(language, forHTTPHeaderField: "Accept-Language")
        var cookies = ["cly_cl=\(language)"]
        if let s = stored { cookies.append("\(s.cookieName)=\(s.cookieValue)") }
        r.setValue(cookies.joined(separator: "; "), forHTTPHeaderField: "Cookie")
        if method == "POST" {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue("cashier", forHTTPHeaderField: "X-Requested-With")
            if auth, let s = stored { r.setValue(s.csrf, forHTTPHeaderField: "X-Cashier-Csrf") }
            r.httpBody = try JSONSerialization.data(withJSONObject: body ?? [:])
        }
        return r
    }

    @discardableResult
    private func perform(_ path: String, method: String, body: [String: Any]?, auth: Bool, retried: Bool) async throws -> Data {
        let req = try request(path, method: method, body: body, auth: auth)
        let data: Data, http: HTTPURLResponse
        do { (data, http) = try await transport.send(req) } catch is CancellationError { throw CancellationError() } catch { throw CashierError.offline }
        captureCookie(http)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let isErr = (json?["error"] as? Bool) == true || http.statusCode >= 400
        if !isErr { return data }
        guard let json else { throw CashierError.malformed(status: http.statusCode) }
        let err = CashierError.from(json: json, status: http.statusCode)
        // Stale CSRF (or a session renewed elsewhere): re-init once with GET me, then replay the POST.
        if err.code == .csrf, method == "POST", auth, !retried, stored != nil {
            if (try? await me()) != nil { return try await perform(path, method: method, body: body, auth: auth, retried: true) }
        }
        if err.isAuth { clearLocal() }
        throw err
    }

    private func captureCookie(_ http: HTTPURLResponse) {
        guard let url = http.url else { return }
        let fields = http.allHeaderFields.reduce(into: [String: String]()) { if let k = $1.key as? String, let v = $1.value as? String { $0[k] = v } }
        for c in HTTPCookie.cookies(withResponseHeaderFields: fields, for: url) where c.name.hasPrefix("cly_cs_") {
            if c.value.isEmpty || c.value == "deleted" || (c.expiresDate.map { $0 < Date() } ?? false) { clearLocal(); continue }
            var s = stored ?? StoredCashierSession(cookieName: c.name, cookieValue: c.value, csrf: "", staffId: 0)
            s.cookieName = c.name; s.cookieValue = c.value
            persist(s)
        }
    }

    private func persist(_ s: StoredCashierSession) {
        stored = s
        if let d = try? JSONEncoder().encode(s) { secrets.write(d, account: account) }
    }
}
