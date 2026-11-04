import Foundation

/// Answers of the owner API (`/api/app/v1`, plugin cafbio-mobile). Decoded with `JSONDecoder.api`; the PHP side mixes 0/1 and booleans, hence the flex readers.
struct OwnerMe: Codable, Equatable, Sendable { var id: Int; var name: String; var email: String }

struct OwnerTools: Decodable, Equatable, Sendable {
    var drive = false, pager = false, loyalty = false
    init(drive: Bool = false, pager: Bool = false, loyalty: Bool = false) { self.drive = drive; self.pager = pager; self.loyalty = loyalty }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); drive = c.flexBool(.drive) ?? false; pager = c.flexBool(.pager) ?? false; loyalty = c.flexBool(.loyalty) ?? false }
    enum K: String, CodingKey { case drive, pager, loyalty }
}

struct OwnerBusiness: Decodable, Equatable, Identifiable, Sendable {
    var id: Int
    var name: String
    var nameEn: String
    var type: String
    var logo: String
    var currency: String
    var color: String
    var tools: OwnerTools
    var manage: Bool
    var setupStep: Int

    init(id: Int, name: String, nameEn: String = "", type: String = "other", logo: String = "", currency: String = "SAR", color: String = "#0E1113", tools: OwnerTools = .init(), manage: Bool = true, setupStep: Int = 0) {
        self.id = id; self.name = name; self.nameEn = nameEn; self.type = type; self.logo = logo; self.currency = currency; self.color = color; self.tools = tools; self.manage = manage; self.setupStep = setupStep
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; nameEn = c.string(.nameEn) ?? ""; type = c.string(.type) ?? "other"; logo = c.string(.logo) ?? ""
        currency = c.string(.currency) ?? "SAR"; color = c.string(.color) ?? "#0E1113"; tools = (try? c.decode(OwnerTools.self, forKey: .tools)) ?? .init()
        manage = c.flexBool(.manage) ?? false; setupStep = c.flexInt(.setupStep) ?? 0
    }
    enum K: String, CodingKey { case id, name, nameEn, type, logo, currency, color, tools, manage, setupStep }

    /// The name in the app's language, falling back to the other one.
    func displayName(english: Bool) -> String {
        let a = name.trimmingCharacters(in: .whitespaces), e = nameEn.trimmingCharacters(in: .whitespaces)
        return english ? (e.isEmpty ? a : e) : (a.isEmpty ? e : a)
    }
}

struct OwnerCards: Decodable, Equatable, Sendable {
    var orders = 0, waiting = 0, membersNew = 0, stamps = 0, rewards = 0
    var prepAvg: Int?
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        orders = c.flexInt(.orders) ?? 0; waiting = c.flexInt(.waiting) ?? 0; membersNew = c.flexInt(.membersNew) ?? 0; stamps = c.flexInt(.stamps) ?? 0; rewards = c.flexInt(.rewards) ?? 0; prepAvg = c.flexInt(.prepAvg)
    }
    enum K: String, CodingKey { case orders, waiting, membersNew, stamps, rewards, prepAvg }
}

enum OwnerLoad: String, Sendable { case calm, busy, full }

/// A branch on the overview: live state + the private cashier link (shown to the owner only).
struct OwnerLiveBranch: Decodable, Equatable, Identifiable, Sendable {
    var id: Int
    var name: String
    var active: Bool
    var online: Bool
    var seen: Date?
    var by: String?
    var staff: [String]
    var openOrders: Int
    var capacity: Int
    var load: OwnerLoad
    var paused: Bool
    var state: String?
    var cashier: String?

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; active = c.flexBool(.active) ?? true; online = c.flexBool(.online) ?? false
        seen = try? c.decodeIfPresent(Date.self, forKey: .seen); by = c.string(.by); staff = (try? c.decode([String].self, forKey: .staff)) ?? []
        openOrders = c.flexInt(.openOrders) ?? 0; capacity = c.flexInt(.capacity) ?? 0; load = OwnerLoad(rawValue: c.string(.load) ?? "") ?? .calm
        paused = c.flexBool(.paused) ?? false; state = c.string(.state); cashier = c.string(.cashier)
    }
    enum K: String, CodingKey { case id, name, active, online, seen, by, staff, openOrders, capacity, load, paused, state, cashier }
}

struct OwnerOverview: Decodable, Equatable, Sendable {
    var business: OwnerBusiness
    var cards: OwnerCards
    var branches: [OwnerLiveBranch]
    var at: Date?
}

struct OwnerBusinessesResponse: Decodable, Sendable { var businesses: [OwnerBusiness] }

/// A branch in the team list.
struct OwnerBranch: Decodable, Equatable, Identifiable, Sendable {
    var id: Int
    var name: String
    var address: String?
    var active: Bool
    var staffCount: Int
    var lastOp: Date?
    var ops30d: Int
    var cashier: String
    var online: Bool?

    init(id: Int, name: String, address: String? = nil, active: Bool = true, staffCount: Int = 0, lastOp: Date? = nil, ops30d: Int = 0, cashier: String, online: Bool? = nil) {
        self.id = id; self.name = name; self.address = address; self.active = active; self.staffCount = staffCount; self.lastOp = lastOp; self.ops30d = ops30d; self.cashier = cashier; self.online = online
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; address = c.string(.address); active = c.flexBool(.active) ?? true; staffCount = c.flexInt(.staffCount) ?? 0
        lastOp = try? c.decodeIfPresent(Date.self, forKey: .lastOp); ops30d = c.flexInt(.ops30d) ?? 0; cashier = c.string(.cashier) ?? ""; online = c.flexBool(.online)
    }
    enum K: String, CodingKey { case id, name, address, active, staffCount, lastOp, ops30d, cashier, online }
}

struct OwnerStaff: Decodable, Equatable, Identifiable, Sendable {
    var id: Int
    var name: String
    var role: String
    var branchId: Int?
    var branchIds: [Int]
    var branchName: String?
    var active: Bool
    var locked: Bool
    var lastSeen: Date?
    var ops30d: Int

    init(id: Int, name: String, role: String = "cashier", branchId: Int? = nil, branchIds: [Int] = [], branchName: String? = nil, active: Bool = true, locked: Bool = false, lastSeen: Date? = nil, ops30d: Int = 0) {
        self.id = id; self.name = name; self.role = role; self.branchId = branchId; self.branchIds = branchIds; self.branchName = branchName; self.active = active; self.locked = locked; self.lastSeen = lastSeen; self.ops30d = ops30d
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; role = c.string(.role) ?? "cashier"; branchId = c.flexInt(.branchId); branchIds = (try? c.decode([Int].self, forKey: .branchIds)) ?? []
        branchName = c.string(.branchName); active = c.flexBool(.active) ?? true; locked = c.flexBool(.locked) ?? false; lastSeen = try? c.decodeIfPresent(Date.self, forKey: .lastSeen); ops30d = c.flexInt(.ops30d) ?? 0
    }
    enum K: String, CodingKey { case id, name, role, branchId, branchIds, branchName, active, locked, lastSeen, ops30d }
}

struct OwnerLimits: Codable, Equatable, Sendable { var branches: Int; var staff: Int }

struct OwnerTeam: Decodable, Equatable, Sendable {
    var branches: [OwnerBranch]
    var staff: [OwnerStaff]
    var limits: OwnerLimits?
    /// Only on create / PIN reset — shown once, never stored.
    var pin: String?
    /// Only after rotating a link.
    var cashierLink: String?
    var id: Int?
    enum CodingKeys: String, CodingKey { case branches, staff, limits, pin, cashier, id }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        branches = try c.decode([OwnerBranch].self, forKey: .branches); staff = try c.decode([OwnerStaff].self, forKey: .staff); limits = try? c.decode(OwnerLimits.self, forKey: .limits)
        pin = c.string(.pin); cashierLink = c.string(.cashier); id = c.flexInt(.id)
    }
}

struct OwnerDevice: Decodable, Equatable, Identifiable, Sendable {
    var id: Int; var name: String; var created: Date?; var lastUsed: Date?; var current: Bool
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; created = try? c.decodeIfPresent(Date.self, forKey: .created); lastUsed = try? c.decodeIfPresent(Date.self, forKey: .lastUsed); current = c.flexBool(.current) ?? false
    }
    enum K: String, CodingKey { case id, name, created, lastUsed, current }
}
struct OwnerDevicesResponse: Decodable, Sendable { var devices: [OwnerDevice] }

struct OwnerTokenPair: Codable, Equatable, Sendable {
    var access: String
    var refresh: String
    var accessExpiresAt: Date
    var refreshExpiresAt: Date
}

struct OwnerAuthResponse: Decodable, Sendable {
    struct Tokens: Decodable, Sendable { var access: String; var refresh: String; var expiresIn: Int; var refreshExpiresIn: Int }
    var tokens: Tokens
    var me: OwnerMe?
}
struct OwnerMeResponse: Decodable, Sendable { var me: OwnerMe }
