import Foundation

// The account area of the owner app (cafbio-mobile: AccountApi, AuthApi identities/password/delete, PushApi prefs, IntegrationsApi).
// Every answer is {error:false, …}; refusals carry codes such as bad_password, last_method, subscription, admin, disabled, rate (CashierError keeps them).

/// «Used of limit». `limit` -1 = the plan does not include it, 0 = no limit.
struct OwnerMeter: Decodable, Equatable, Sendable {
    var used = 0, limit = 0
    init(used: Int = 0, limit: Int = 0) { self.used = used; self.limit = limit }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); used = c.flexInt(.used) ?? 0; limit = c.flexInt(.limit) ?? 0 }
    enum K: String, CodingKey { case used, limit }
    var isIncluded: Bool { limit >= 0 }
    var isUnlimited: Bool { limit == 0 }
    /// 0...1 for a finite limit.
    var fraction: Double { limit > 0 ? min(1, Double(used) / Double(limit)) : 0 }
}

/// `GET account`: who, the plan, and how much of it is used. `usage` keeps the server's order (links, bios, qrs, team, loyalty_members, whatsapp_messages).
struct OwnerAccountInfo: Decodable, Equatable, Sendable {
    struct Plan: Decodable, Equatable, Sendable {
        var name = "", slug = "", free = false, trial = false, admin = false, expiresAt: Date?
        init() {}
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            name = c.string(.name) ?? ""; slug = c.string(.slug) ?? ""; free = c.flexBool(.free) ?? false; trial = c.flexBool(.trial) ?? false; admin = c.flexBool(.admin) ?? false
            expiresAt = try? c.decodeIfPresent(Date.self, forKey: .expiresAt)
        }
        enum K: String, CodingKey { case name, slug, free, trial, admin, expiresAt }
    }
    struct Me: Decodable, Equatable, Sendable {
        var name = "", email = "", username = "", language = "ar"
        init() {}
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            name = c.string(.name) ?? ""; email = c.string(.email) ?? ""; username = c.string(.username) ?? ""; language = c.string(.language) ?? "ar"
        }
        enum K: String, CodingKey { case name, email, username, language }
    }
    struct UsageRow: Equatable, Identifiable, Sendable { var key: String; var meter: OwnerMeter; var id: String { key } }

    var me = Me()
    var plan = Plan()
    var usage: [UsageRow] = []
    var showBilling = false

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        me = (try? c.decode(Me.self, forKey: .me)) ?? Me()
        plan = (try? c.decode(Plan.self, forKey: .plan)) ?? Plan()
        showBilling = c.flexBool(.showBilling) ?? false
        usage = Self.usageRows(in: c, forKey: .usage)
    }
    enum K: String, CodingKey { case me, plan, usage, showBilling }
    private struct AnyKey: CodingKey { var stringValue: String; var intValue: Int? { nil }; init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { nil } }

    /// The `usage` object of `GET account` and `GET account/billing`. The decoder's snake_case strategy also rewrites dictionary keys ("loyalty_members" → "loyaltyMembers");
    /// rows are keyed back to the server's spelling and ordered like the plan page.
    static func usageRows<Key: CodingKey>(in c: KeyedDecodingContainer<Key>, forKey key: Key) -> [UsageRow] {
        guard let u = try? c.nestedContainer(keyedBy: AnyKey.self, forKey: key) else { return [] }
        return u.allKeys.compactMap { k in (try? u.decode(OwnerMeter.self, forKey: k)).map { UsageRow(key: snake(k.stringValue), meter: $0) } }
            .sorted { order($0.key) < order($1.key) }
    }

    static func snake(_ s: String) -> String {
        var out = ""
        for ch in s { if ch.isUppercase { out.append("_"); out.append(contentsOf: ch.lowercased()) } else { out.append(ch) } }
        return out
    }
    private static let known = ["links", "bios", "qrs", "team", "loyalty_members", "whatsapp_messages"]
    static func order(_ key: String) -> Int { known.firstIndex(of: key) ?? known.count }
}

/// One notification switch (`GET notifications/prefs` → `events`). The label is already in the language the session sent.
struct OwnerNotificationPref: Decodable, Equatable, Identifiable, Sendable {
    var key: String, label: String, on: Bool, group: String
    var id: String { key }
    init(key: String, label: String, on: Bool, group: String) { self.key = key; self.label = label; self.on = on; self.group = group }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        key = c.string(.key) ?? ""; label = c.string(.label) ?? key; on = c.flexBool(.on) ?? false; group = c.string(.group) ?? "account"
    }
    enum K: String, CodingKey { case key, label, on, group }
}
private struct OwnerNotificationPrefsResponse: Decodable { var events: [OwnerNotificationPref] }

/// A sign-in method linked to the account (`GET auth/identities`).
struct OwnerIdentity: Decodable, Equatable, Identifiable, Sendable {
    var provider: String, email: String?, linkedAt: Date?
    var id: String { provider }
    init(provider: String, email: String? = nil, linkedAt: Date? = nil) { self.provider = provider; self.email = email; self.linkedAt = linkedAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        provider = c.string(.provider) ?? ""; email = c.string(.email); linkedAt = try? c.decodeIfPresent(Date.self, forKey: .linkedAt)
    }
    enum K: String, CodingKey { case provider, email, linkedAt }
}
struct OwnerIdentities: Decodable, Equatable, Sendable {
    var identities: [OwnerIdentity] = []
    var hasPassword = false
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        identities = ((try? c.decode([OwnerIdentity].self, forKey: .identities)) ?? []).filter { !$0.provider.isEmpty }
        hasPassword = c.flexBool(.hasPassword) ?? false
    }
    enum K: String, CodingKey { case identities, hasPassword }
    /// The providers the server knows (Identities::PROVIDERS), in the order the sign-in screen shows them.
    static let providers = ["apple", "google", "x", "snapchat", "microsoft"]
}

/// One card of the integrations hub (`GET integrations`). `status`: none | connected | broken | ready | setup | locked.
struct OwnerIntegration: Decodable, Equatable, Identifiable, Sendable {
    var key: String, name: String, category: String, categoryName: String, connected: Bool, status: String, detail: String, locked: Bool, plan: String?, connectUrl: String
    var id: String { key }
    init(key: String, name: String, category: String = "", categoryName: String = "", connected: Bool = false, status: String = "none", detail: String = "", locked: Bool = false, plan: String? = nil, connectUrl: String = "/user/integrations") {
        self.key = key; self.name = name; self.category = category; self.categoryName = categoryName; self.connected = connected; self.status = status; self.detail = detail; self.locked = locked; self.plan = plan; self.connectUrl = connectUrl
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        key = c.string(.key) ?? ""; name = c.string(.name) ?? key; category = c.string(.category) ?? ""; categoryName = c.string(.categoryName) ?? category
        connected = c.flexBool(.connected) ?? false; status = c.string(.status) ?? "none"; detail = c.string(.detail) ?? ""; locked = c.flexBool(.locked) ?? false
        plan = c.string(.plan); connectUrl = c.string(.connectUrl) ?? "/user/integrations"
    }
    enum K: String, CodingKey { case key, name, category, categoryName, connected, status, detail, locked, plan, connectUrl }
}
struct OwnerIntegrations: Decodable, Equatable, Sendable {
    var items: [OwnerIntegration] = []
    var connectedCount = 0
    init() {}
    init(items: [OwnerIntegration]) { self.items = items; connectedCount = items.filter(\.connected).count }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        items = ((try? c.decode([OwnerIntegration].self, forKey: .items)) ?? []).filter { !$0.key.isEmpty }
        connectedCount = c.flexInt(.connectedCount) ?? items.filter(\.connected).count
    }
    enum K: String, CodingKey { case items, connectedCount }
}

extension OwnerSession {
    func accountInfo() async throws -> OwnerAccountInfo { try decode(OwnerAccountInfo.self, try await get("account")) }

    /// Name and/or language (`ar` | `en`; the language also decides the language of the pushes this account receives).
    @discardableResult
    func updateAccount(name: String? = nil, language: String? = nil) async throws -> OwnerAccountInfo {
        var body: [String: Any] = [:]
        if let name { body["name"] = name }
        if let language { body["language"] = language }
        return try decode(OwnerAccountInfo.self, try await perform("account", method: "PUT", body: body, auth: true))
    }

    /// `branch` 0 = the account's answer for all branches; a branch id = what that branch overrides.
    func notificationPrefs(branch: Int = 0) async throws -> [OwnerNotificationPref] {
        let path = branch > 0 ? "notifications/prefs?branch_id=\(branch)" : "notifications/prefs"
        return try decode(OwnerNotificationPrefsResponse.self, try await get(path)).events
    }

    func saveNotificationPrefs(_ events: [String: Bool], branch: Int = 0) async throws -> [OwnerNotificationPref] {
        var body: [String: Any] = ["events": events]
        if branch > 0 { body["branch_id"] = branch }
        return try decode(OwnerNotificationPrefsResponse.self, try await perform("notifications/prefs", method: "PUT", body: body, auth: true)).events
    }

    /// Pushes a test notification to this account's phones. Returns how many phones were queued.
    func sendTestNotification() async throws -> Int {
        struct Ack: Decodable { var queued: Int }
        return try decode(Ack.self, try await post("notifications/test", [:])).queued
    }

    func identities() async throws -> OwnerIdentities { try decode(OwnerIdentities.self, try await get("auth/identities")) }

    func unlinkIdentity(_ provider: String) async throws -> OwnerIdentities {
        try decode(OwnerIdentities.self, try await post("auth/identities/\(provider)/unlink", [:]))
    }

    /// An account created by Apple / Google has no password yet: `current` is empty then. Other app sign-ins end, this one stays.
    func setPassword(current: String?, new: String) async throws {
        var body: [String: Any] = ["new": new]
        if let current, !current.isEmpty { body["current"] = current }
        _ = try await post("auth/password", body)
    }

    /// Deletes the account and all its data. `password` is required when the account has one.
    func deleteAccount(password: String?) async throws {
        var body: [String: Any] = ["confirm": "DELETE"]
        if let password, !password.isEmpty { body["password"] = password }
        _ = try await post("auth/delete", body)
    }

    func integrations() async throws -> OwnerIntegrations { try decode(OwnerIntegrations.self, try await get("integrations")) }
}
