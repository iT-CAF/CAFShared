import Testing
import Foundation
@testable import CAFBusiness

private let base = URL(string: "http://x.test")!
private func tokens(_ a: String, _ r: String, ttl: Int = 900) -> [String: Any] { ["error": false, "tokens": ["access": a, "refresh": r, "expires_in": ttl, "refresh_expires_in": 5_184_000], "me": ["id": 1, "name": "Owner", "email": "o@x.test"]] }
private func authErr() -> [String: Any] { ["error": true, "code": "auth", "message": "Sign in again."] }

@Suite("Owner API models (recorded rig answers)")
struct OwnerFixtureTests {
    private func decode<T: Decodable>(_ t: T.Type, _ name: String) throws -> T { try JSONDecoder.api.decode(T.self, from: Fixture.data(name)) }

    @Test func businesses() throws {
        let r = try decode(OwnerBusinessesResponse.self, "owner_businesses")
        #expect(r.businesses.count == 1 && r.businesses[0].tools.drive && r.businesses[0].tools.loyalty && r.businesses[0].manage)
        #expect(r.businesses[0].displayName(english: false) == "مقهى اختبار S3" && r.businesses[0].displayName(english: true) == "S3 Test Cafe")
    }
    @Test func overview() throws {
        let o = try decode(OwnerOverview.self, "owner_overview")
        #expect(o.cards.orders > 0 && o.cards.prepAvg != nil)
        #expect(o.branches.count >= 2 && o.branches[0].online && !o.branches[1].online)
        #expect(o.branches[0].cashier?.contains("/cashier/") == true && o.branches[0].capacity > 0)
    }
    @Test func team() throws {
        let t = try decode(OwnerTeam.self, "owner_team")
        #expect(t.branches.count >= 2 && t.staff.count >= 2 && t.limits?.staff == 150)
        #expect(t.staff[0].active && t.staff[0].branchIds == [903] && t.staff[1].role == "manager" && t.staff[1].branchId == nil)
        #expect(t.pin == nil && t.cashierLink == nil)
    }
    @Test func staffCreatedCarriesThePinOnce() throws {
        let t = try decode(OwnerTeam.self, "owner_staff_created")
        #expect(t.pin?.count == 6 && (t.id ?? 0) > 0 && t.staff.contains { $0.id == t.id })
    }
    @Test func devices() throws {
        let d = try decode(OwnerDevicesResponse.self, "owner_devices").devices
        #expect(d.count == 1 && d[0].current && d[0].name == "Recorder")
    }
    @Test func errorsMapToOwnerCodes() {
        let e = CashierError.from(json: Fixture.body("owner_login_bad"), status: Fixture.http("owner_login_bad"))
        #expect(e.code == .badLogin && !e.userMessage.isEmpty)
        #expect(CashierError.from(json: Fixture.body("owner_unauth"), status: 401).isAuth)
        #expect(CashierErrorCode("twofa").l10nKey == "err.twofa" && CashierErrorCode("reuse").l10nKey == "err.reuse")
    }
}

@Suite("OwnerSession (stubbed transport)")
struct OwnerSessionTests {
    private func make(_ steps: [StubTransport.Step], secrets: MemorySecretStore = MemorySecretStore(), now: @escaping @Sendable () -> Date = { Date() }) -> (OwnerSession, StubTransport, MemorySecretStore) {
        let t = StubTransport(steps); return (OwnerSession(baseURL: base, transport: t, secrets: secrets, now: now), t, secrets)
    }

    @Test func loginSendsDeviceAndStoresOnlyTokens() async throws {
        let (s, t, secrets) = make([.json(200, tokens("cba_A", "cbr_A"))])
        let me = try await s.login(email: "o@x.test", password: "pw-secret", deviceName: "iPhone")
        #expect(me.email == "o@x.test")
        #expect(t.requests[0].url?.path == "/api/app/v1/auth/login" && t.requests[0].value(forHTTPHeaderField: "Authorization") == nil)
        #expect(t.bodyJSON(0)?["device_name"] as? String == "iPhone" && (t.bodyJSON(0)?["device_id"] as? String)?.isEmpty == false)
        let blob = String(decoding: secrets.read(OwnerSession.account)!, as: UTF8.self)
        #expect(blob.contains("cba_A") && blob.contains("cbr_A") && !blob.contains("pw-secret") && !blob.contains("o@x.test"))
        #expect(await s.isSignedIn)
    }

    @Test func requestsCarryBearerAndFallbackHeader() async throws {
        let (s, t, _) = make([.json(200, tokens("cba_A", "cbr_A")), .json(200, Fixture.body("owner_businesses"))])
        _ = try await s.login(email: "o@x.test", password: "p", deviceName: "d")
        let list = try await s.businesses()
        #expect(list.count == 1)
        #expect(t.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer cba_A" && t.requests[1].value(forHTTPHeaderField: "X-Caf-Token") == "cba_A")
        #expect(t.requests[1].url?.path == "/api/app/v1/businesses")
    }

    @Test func expiredAccessRefreshesFirstAndPersistsTheRotatedPair() async throws {
        let clock = Clock(); 
        let (s, t, secrets) = make([.json(200, tokens("cba_A", "cbr_A", ttl: 900)), .json(200, tokens("cba_B", "cbr_B")), .json(200, Fixture.body("owner_businesses"))], now: { clock.now })
        _ = try await s.login(email: "o@x.test", password: "p", deviceName: "d")
        clock.advance(890)                                   // < 20 s left
        _ = try await s.businesses()
        #expect(t.requests[1].url?.path.hasSuffix("auth/refresh") == true && t.bodyJSON(1)?["refresh"] as? String == "cbr_A")
        #expect(t.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer cba_B")
        let stored = try JSONDecoder().decode(OwnerTokenPair.self, from: secrets.read(OwnerSession.account)!)
        #expect(stored.refresh == "cbr_B")
    }

    @Test func aRejectedRequestRefreshesOnceAndReplays() async throws {
        let (s, t, _) = make([.json(200, tokens("cba_A", "cbr_A")), .json(401, authErr()), .json(200, tokens("cba_B", "cbr_B")), .json(200, Fixture.body("owner_businesses"))])
        _ = try await s.login(email: "o@x.test", password: "p", deviceName: "d")
        let list = try await s.businesses()
        #expect(list.count == 1 && t.requests.count == 4)
        #expect(t.requests[3].value(forHTTPHeaderField: "Authorization") == "Bearer cba_B")
    }

    @Test func concurrentCallsShareOneRefresh() async throws {
        let clock = Clock()
        let t = StubTransport([.json(200, tokens("cba_A", "cbr_A"))])
        t.fallback = .json(200, Fixture.body("owner_businesses"))
        let s = OwnerSession(baseURL: base, transport: t, secrets: MemorySecretStore(), now: { clock.now })
        _ = try await s.login(email: "o@x.test", password: "p", deviceName: "d")
        clock.advance(895)
        t.push(.json(200, tokens("cba_B", "cbr_B")))        // the only refresh that may happen
        await withTaskGroup(of: Void.self) { g in for _ in 0..<5 { g.addTask { _ = try? await s.businesses() } } }
        let refreshes = t.requests.filter { $0.url?.path.hasSuffix("auth/refresh") == true }
        #expect(refreshes.count == 1)
    }

    @Test func refusedRefreshSignsOutAndClearsTheKeychain() async throws {
        let (s, _, secrets) = make([.json(200, tokens("cba_A", "cbr_A")), .json(401, authErr()), .json(401, ["error": true, "code": "reuse", "message": ""])])
        _ = try await s.login(email: "o@x.test", password: "p", deviceName: "d")
        await #expect(throws: CashierError.self) { _ = try await s.businesses() }
        #expect(!(await s.isSignedIn) && secrets.read(OwnerSession.account) == nil)
    }

    @Test func offlineDuringRefreshKeepsTheSignIn() async throws {
        let clock = Clock()
        let (s, _, secrets) = make([.json(200, tokens("cba_A", "cbr_A")), .fail(.notConnectedToInternet)], now: { clock.now })
        _ = try await s.login(email: "o@x.test", password: "p", deviceName: "d")
        clock.advance(899)
        await #expect(throws: CashierError.offline) { _ = try await s.businesses() }
        #expect(await s.isSignedIn && secrets.read(OwnerSession.account) != nil)
    }

    @Test func wrongPasswordSurfacesTheCodeAndStoresNothing() async throws {
        let (s, _, secrets) = make([.json(Fixture.http("owner_login_bad"), Fixture.body("owner_login_bad"))])
        do { _ = try await s.login(email: "o@x.test", password: "nope", deviceName: "d"); Issue.record("should throw") }
        catch let e as CashierError { #expect(e.code == .badLogin) }
        #expect(secrets.read(OwnerSession.account) == nil)
    }

    @Test func logoutCallsServerThenForgets() async throws {
        let (s, t, secrets) = make([.json(200, tokens("cba_A", "cbr_A")), .json(200, ["error": false])])
        _ = try await s.login(email: "o@x.test", password: "p", deviceName: "d")
        await s.logout()
        #expect(t.requests[1].url?.path.hasSuffix("auth/logout") == true && secrets.read(OwnerSession.account) == nil)
    }

    @Test func staffCreationSendsRoleAndBranchAndReturnsPin() async throws {
        let (s, t, _) = make([.json(200, tokens("cba_A", "cbr_A")), .json(201, Fixture.body("owner_staff_created"))])
        _ = try await s.login(email: "o@x.test", password: "p", deviceName: "d")
        let team = try await s.createStaff(109, name: "علي", role: "cashier", branch: 903)
        #expect(team.pin?.count == 6)
        #expect(t.requests[1].url?.path == "/api/app/v1/businesses/109/staff" && t.bodyJSON(1)?["branch_id"] as? Int == 903 && t.bodyJSON(1)?["role"] as? String == "cashier")
    }
}

/// Test clock the session reads through `now`.
final class Clock: @unchecked Sendable {
    private let lock = NSLock(); private var t = Date(timeIntervalSince1970: 1_800_000_000)
    var now: Date { lock.lock(); defer { lock.unlock() }; return t }
    func advance(_ s: TimeInterval) { lock.lock(); t = t.addingTimeInterval(s); lock.unlock() }
}

@MainActor
@Suite("OwnerStore")
struct OwnerStoreTests {
    private func make(_ steps: [StubTransport.Step]) -> (OwnerStore, StubTransport) {
        let t = StubTransport(steps)
        let d = UserDefaults(suiteName: "owner.tests.\(UUID().uuidString)")!
        return (OwnerStore(session: OwnerSession(baseURL: base, transport: t, secrets: MemorySecretStore()), defaults: d), t)
    }

    @Test func signInLoadsBusinessesAndOverview() async {
        let (s, _) = make([.json(200, tokens("cba_A", "cbr_A")), .json(200, Fixture.body("owner_me")), .json(200, Fixture.body("owner_businesses")), .json(200, Fixture.body("owner_overview"))])
        await s.signIn(email: "o@x.test", password: "p")
        #expect(s.phase == .ready && s.selected?.id == 109 && s.overview?.branches.count ?? 0 >= 2 && s.loginError == nil)
    }

    @Test func wrongPasswordShowsAMessageAndStaysSignedOut() async {
        let (s, _) = make([.json(401, Fixture.body("owner_login_bad"))])
        await s.signIn(email: "o@x.test", password: "x")
        #expect(s.phase != .ready && s.loginError?.isEmpty == false)
    }

    @Test func emptyFieldsNeverReachTheNetwork() async {
        let (s, t) = make([])
        await s.signIn(email: " ", password: "")
        #expect(t.requests.isEmpty && s.loginError != nil)
    }

    @Test func aPinIsHeldOnlyUntilDismissed() async {
        let (s, _) = make([.json(200, tokens("cba_A", "cbr_A")), .json(200, Fixture.body("owner_me")), .json(200, Fixture.body("owner_businesses")), .json(200, Fixture.body("owner_overview")),
                           .json(201, Fixture.body("owner_staff_created")), .json(200, Fixture.body("owner_overview"))])
        await s.signIn(email: "o@x.test", password: "p")
        let ok = await s.createStaff(name: "موظف", role: "cashier", branch: nil)
        #expect(ok && s.revealedPin?.pin.count == 6 && s.team?.staff.contains { $0.name == "موظف مسجّل" } == true)
        s.revealedPin = nil
        #expect(s.revealedPin == nil)
    }

    @Test func signOutWipesEverythingOnScreen() async {
        let (s, _) = make([.json(200, tokens("cba_A", "cbr_A")), .json(200, Fixture.body("owner_me")), .json(200, Fixture.body("owner_businesses")), .json(200, Fixture.body("owner_overview")), .json(200, ["error": false])])
        await s.signIn(email: "o@x.test", password: "p")
        await s.signOut()
        #expect(s.phase == .signedOut && s.businesses.isEmpty && s.overview == nil && s.me == nil)
    }

    @Test func aRevokedSessionReturnsToTheForm() async {
        let (s, _) = make([.json(200, tokens("cba_A", "cbr_A")), .json(200, Fixture.body("owner_me")), .json(200, Fixture.body("owner_businesses")), .json(200, Fixture.body("owner_overview")),
                           .json(401, authErr()), .json(401, authErr())])
        await s.signIn(email: "o@x.test", password: "p")
        await s.refreshOverview()
        #expect(s.phase == .signedOut && s.loginError != nil && s.businesses.isEmpty)
    }
}
