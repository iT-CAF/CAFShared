import Foundation

// DTOs of the cashier API (see docs/API.md). Decoded with `JSONDecoder.api` (snake_case → camelCase). PHP is loose with types,
// so numeric fields go through the flex helpers.

struct BranchInfo: Codable, Equatable, Sendable { var id: Int; var name: String }

struct StaffEntry: Codable, Equatable, Sendable, Identifiable { var id: Int; var name: String; var role: String }

struct CashierProgramInfo: Codable, Equatable, Sendable {
    var name: String
    var mode: String
    var currency: String
    var pointsLabel: String
    var perUnit: Double
    var perVisit: Int
    var maxPerTx: Int
    var needed: Int
    var undoMin: Int
    var enabled: Bool
    var loyalty: Bool
    var isPoints: Bool { mode == "points" }

    private enum K: String, CodingKey { case name, mode, currency, pointsLabel, perUnit, perVisit, maxPerTx, needed, undoMin, enabled, loyalty }
    init(name: String = "", mode: String = "stamps", currency: String = "SAR", pointsLabel: String = "", perUnit: Double = 0, perVisit: Int = 1, maxPerTx: Int = 1, needed: Int = 0, undoMin: Int = 10, enabled: Bool = true, loyalty: Bool = true) {
        self.name = name; self.mode = mode; self.currency = currency; self.pointsLabel = pointsLabel; self.perUnit = perUnit; self.perVisit = perVisit
        self.maxPerTx = maxPerTx; self.needed = needed; self.undoMin = undoMin; self.enabled = enabled; self.loyalty = loyalty
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        self.init(name: c.string(.name) ?? "", mode: c.string(.mode) ?? "stamps", currency: c.string(.currency) ?? "SAR", pointsLabel: c.string(.pointsLabel) ?? "",
                  perUnit: c.flexDouble(.perUnit) ?? 0, perVisit: c.flexInt(.perVisit) ?? 1, maxPerTx: c.flexInt(.maxPerTx) ?? 1, needed: c.flexInt(.needed) ?? 0,
                  undoMin: c.flexInt(.undoMin) ?? 10, enabled: c.flexBool(.enabled) ?? true, loyalty: c.flexBool(.loyalty) ?? true)
    }
}

/// `perms` as the server computed them (`Perms::effective`). Unknown keys are kept; a missing key means "not allowed".
struct CashierPerms: Equatable, Sendable, Decodable {
    var raw: [String: Bool]
    init(_ raw: [String: Bool] = [:]) { self.raw = raw }
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if let m = try? c.decode([String: Bool].self) { raw = m; return }
        if let m = try? c.decode([String: Int].self) { raw = m.mapValues { $0 != 0 }; return }
        raw = [:]
    }
    func has(_ key: String) -> Bool { raw[key] == true }
    var canEarn: Bool { has("loyalty.earn") }
    var canRedeem: Bool { has("loyalty.redeem") }
    var canUndo: Bool { has("loyalty.undo") }
    /// The scanner is useful with either key (the server's `lookup` accepts earn OR redeem).
    var canScan: Bool { canEarn || canRedeem }
    var canPrep: Bool { has("prep.view") }
    var canPager: Bool { has("pager.use") || has("orders.pager") }
}

struct CashierStaff: Decodable, Equatable, Sendable, Identifiable {
    var id: Int; var name: String; var role: String; var perms: CashierPerms
    var isManager: Bool { role == "manager" }
    private enum K: String, CodingKey { case id, name, role, perms }
    init(id: Int, name: String, role: String, perms: CashierPerms) { self.id = id; self.name = name; self.role = role; self.perms = perms }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; role = c.string(.role) ?? "cashier"
        perms = (try? c.decode(CashierPerms.self, forKey: .perms)) ?? CashierPerms()
    }
}

struct StaffListResponse: Decodable, Equatable, Sendable {
    var staff: [StaffEntry]; var program: CashierProgramInfo; var branch: BranchInfo
}

struct SessionInfo: Decodable, Equatable, Sendable {
    var csrf: String
    var staff: CashierStaff
    var branch: BranchInfo
    var program: CashierProgramInfo
    var recent: [LedgerTx]
    /// Unix seconds.
    var exp: Int
    var expiresAt: Date { Date(timeIntervalSince1970: TimeInterval(exp)) }
    private enum K: String, CodingKey { case csrf, staff, branch, program, recent, exp }
    init(csrf: String, staff: CashierStaff, branch: BranchInfo, program: CashierProgramInfo, recent: [LedgerTx], exp: Int) {
        self.csrf = csrf; self.staff = staff; self.branch = branch; self.program = program; self.recent = recent; self.exp = exp
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        csrf = try c.decode(String.self, forKey: .csrf)
        staff = try c.decode(CashierStaff.self, forKey: .staff)
        branch = try c.decode(BranchInfo.self, forKey: .branch)
        program = try c.decode(CashierProgramInfo.self, forKey: .program)
        recent = (try? c.decode([LedgerTx].self, forKey: .recent)) ?? []
        exp = c.flexInt(.exp) ?? 0
    }
}

struct LevelInfo: Decodable, Equatable, Sendable {
    var key: String; var name: String; var mult: Double; var levelMult: Double; var color: String?
    private enum K: String, CodingKey { case key, name, mult, levelMult, color }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        key = c.string(.key) ?? ""; name = c.string(.name) ?? ""; mult = c.flexDouble(.mult) ?? 1; levelMult = c.flexDouble(.levelMult) ?? 1; color = c.string(.color)
    }
    init(key: String = "", name: String = "", mult: Double = 1, levelMult: Double = 1, color: String? = nil) { self.key = key; self.name = name; self.mult = mult; self.levelMult = levelMult; self.color = color }
}

struct RedeemOption: Decodable, Equatable, Sendable, Identifiable {
    var id: Int?; var tier: Int; var name: String; var cost: Int
    /// Stable identity for lists (reward id, else tier).
    var key: String { id.map { "r\($0)" } ?? "t\(tier)" }
    private enum K: String, CodingKey { case id, tier, name, cost }
    init(id: Int?, tier: Int, name: String, cost: Int) { self.id = id; self.tier = tier; self.name = name; self.cost = cost }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id); tier = c.flexInt(.tier) ?? 0; name = c.string(.name) ?? ""; cost = c.flexInt(.cost) ?? 0
    }
}

struct MemberCard: Decodable, Equatable, Sendable, Identifiable {
    var id: Int
    /// `#0042`
    var no: String
    var name: String
    var status: String
    var mode: String
    var balance: Int
    var needed: Int
    var left: Int
    var rewardsAvailable: Int
    var level: LevelInfo
    var redeem: [RedeemOption]
    var cooldownLeftS: Int
    var lastStampAt: Date?
    var pointsNeeded: Int
    var isPoints: Bool { mode == "points" }
    var isBlocked: Bool { status == "blocked" }
    /// Goal of the progress bar: points programmes use `points_needed`, stamp programmes `needed`.
    var goal: Int { isPoints ? max(pointsNeeded, 0) : max(needed, 0) }
    /// 0…1 toward the next reward (full once a reward can be redeemed).
    var progress: Double {
        guard goal > 0 else { return 0 }
        let have = isPoints ? balance : max(goal - left, 0)
        return min(1, Double(have) / Double(goal))
    }
    var rewardReady: Bool { isPoints ? (pointsNeeded > 0 && balance >= pointsNeeded) : rewardsAvailable > 0 }
    private enum K: String, CodingKey { case id, no, name, status, mode, balance, needed, left, rewardsAvailable, level, redeem, cooldownLeftS, lastStampAt, pointsNeeded }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; no = c.string(.no) ?? ""; name = c.string(.name) ?? ""; status = c.string(.status) ?? "active"; mode = c.string(.mode) ?? "stamps"
        balance = c.flexInt(.balance) ?? 0; needed = c.flexInt(.needed) ?? 0; left = c.flexInt(.left) ?? 0; rewardsAvailable = c.flexInt(.rewardsAvailable) ?? 0
        level = (try? c.decode(LevelInfo.self, forKey: .level)) ?? LevelInfo()
        redeem = (try? c.decode([RedeemOption].self, forKey: .redeem)) ?? []
        cooldownLeftS = c.flexInt(.cooldownLeftS) ?? 0
        lastStampAt = try? c.decodeIfPresent(Date.self, forKey: .lastStampAt)
        pointsNeeded = c.flexInt(.pointsNeeded) ?? 0
    }
    init(id: Int, no: String, name: String, status: String = "active", mode: String = "points", balance: Int, needed: Int = 0, left: Int = 0, rewardsAvailable: Int = 0,
         level: LevelInfo = LevelInfo(), redeem: [RedeemOption] = [], cooldownLeftS: Int = 0, lastStampAt: Date? = nil, pointsNeeded: Int = 0) {
        self.id = id; self.no = no; self.name = name; self.status = status; self.mode = mode; self.balance = balance; self.needed = needed; self.left = left
        self.rewardsAvailable = rewardsAvailable; self.level = level; self.redeem = redeem; self.cooldownLeftS = cooldownLeftS; self.lastStampAt = lastStampAt; self.pointsNeeded = pointsNeeded
    }
}

struct LedgerTx: Decodable, Equatable, Sendable, Identifiable {
    var id: Int
    /// `points | stamp | redeem | reverse | bonus`
    var type: String
    var qty: Int
    var balanceAfter: Int
    var amount: Double?
    var note: String?
    var actorName: String?
    var createdAt: Date?
    var undoUntil: Date?
    var memberName: String?
    var memberNo: Int?
    var memberId: Int?
    var reversedBy: Int?
    var reverses: Int?
    var isRedeem: Bool { type == "redeem" }
    var isReversed: Bool { reversedBy != nil }
    func canUndo(now: Date = .now) -> Bool { !isReversed && type != "reverse" && (undoUntil.map { $0 > now } ?? false) }
    private enum K: String, CodingKey { case id, type, qty, balanceAfter, amount, note, actorName, createdAt, undoUntil, memberName, memberNo, memberId, reversedBy, reverses }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; type = c.string(.type) ?? ""; qty = c.flexInt(.qty) ?? 0; balanceAfter = c.flexInt(.balanceAfter) ?? 0; amount = c.flexDouble(.amount)
        note = c.string(.note); actorName = c.string(.actorName)
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt); undoUntil = try? c.decodeIfPresent(Date.self, forKey: .undoUntil)
        memberName = c.string(.memberName); memberNo = c.flexInt(.memberNo); memberId = c.flexInt(.memberId); reversedBy = c.flexInt(.reversedBy); reverses = c.flexInt(.reverses)
    }
    init(id: Int, type: String, qty: Int, balanceAfter: Int, amount: Double? = nil, createdAt: Date? = nil, undoUntil: Date? = nil, memberName: String? = nil, memberNo: Int? = nil, memberId: Int? = nil) {
        self.id = id; self.type = type; self.qty = qty; self.balanceAfter = balanceAfter; self.amount = amount; self.createdAt = createdAt; self.undoUntil = undoUntil
        self.memberName = memberName; self.memberNo = memberNo; self.memberId = memberId
    }
}

struct MemberMatch: Decodable, Equatable, Sendable, Identifiable { var id: Int; var name: String; var no: String }

struct RedeemCodeInfo: Decodable, Equatable, Sendable {
    var name: String; var rewardId: Int; var expiresAt: Date?
    private enum K: String, CodingKey { case name, rewardId, expiresAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        name = c.string(.name) ?? ""; rewardId = c.flexInt(.rewardId) ?? 0; expiresAt = try? c.decodeIfPresent(Date.self, forKey: .expiresAt)
    }
}

/// `lookup` answer: a member, a member + one-time reward code, or several candidates.
enum LookupOutcome: Equatable, Sendable {
    case member(MemberCard)
    case code(RedeemCodeInfo, MemberCard)
    case matches([MemberMatch])
}

struct LookupResponse: Decodable, Sendable {
    var member: MemberCard?; var code: RedeemCodeInfo?; var matches: [MemberMatch]?
    var outcome: LookupOutcome? {
        if let m = matches, !m.isEmpty { return .matches(m) }
        if let c = code, let m = member { return .code(c, m) }
        if let m = member { return .member(m) }
        return nil
    }
}

struct Quote: Decodable, Equatable, Sendable {
    var kind: String; var base: Int; var mult: Double; var total: Int; var level: String?
    private enum K: String, CodingKey { case kind, base, mult, total, level }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        kind = c.string(.kind) ?? "points"; base = c.flexInt(.base) ?? 0; mult = c.flexDouble(.mult) ?? 1; total = c.flexInt(.total) ?? 0; level = c.string(.level)
    }
    init(kind: String, base: Int, mult: Double, total: Int, level: String? = nil) { self.kind = kind; self.base = base; self.mult = mult; self.total = total; self.level = level }
}
struct QuoteResponse: Decodable, Sendable { var quote: Quote }

struct EarnResult: Decodable, Equatable, Sendable {
    var member: MemberCard; var tx: LedgerTx; var added: Int; var rewardUnlocked: Bool; var duplicate: Bool; var undoUntil: Date?
    private enum K: String, CodingKey { case member, tx, added, rewardUnlocked, duplicate, undoUntil }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        member = try c.decode(MemberCard.self, forKey: .member); tx = try c.decode(LedgerTx.self, forKey: .tx); added = c.flexInt(.added) ?? tx.qty
        rewardUnlocked = c.flexBool(.rewardUnlocked) ?? false; duplicate = c.flexBool(.duplicate) ?? false; undoUntil = try? c.decodeIfPresent(Date.self, forKey: .undoUntil)
    }
}

struct RedeemResult: Decodable, Equatable, Sendable {
    var member: MemberCard; var tx: LedgerTx; var reward: String; var cost: Int?; var duplicate: Bool
    private enum K: String, CodingKey { case member, tx, reward, cost, duplicate }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        member = try c.decode(MemberCard.self, forKey: .member); tx = try c.decode(LedgerTx.self, forKey: .tx)
        reward = c.string(.reward) ?? ""; cost = c.flexInt(.cost); duplicate = c.flexBool(.duplicate) ?? false
    }
}

struct UndoResult: Decodable, Equatable, Sendable { var member: MemberCard; var tx: LedgerTx }

struct SyncItemResult: Decodable, Equatable, Sendable {
    var idem: String; var ok: Bool; var duplicate: Bool; var added: Int?; var balance: Int?; var name: String?; var permanent: Bool; var code: String?; var message: String?
    private enum K: String, CodingKey { case idem, ok, duplicate, added, balance, name, permanent, code, message }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        idem = c.string(.idem) ?? ""; ok = c.flexBool(.ok) ?? false; duplicate = c.flexBool(.duplicate) ?? false; added = c.flexInt(.added); balance = c.flexInt(.balance)
        name = c.string(.name); permanent = c.flexBool(.permanent) ?? false; code = c.string(.code); message = c.string(.message)
    }
    init(idem: String, ok: Bool, duplicate: Bool = false, permanent: Bool = false, code: String? = nil, message: String? = nil) {
        self.idem = idem; self.ok = ok; self.duplicate = duplicate; self.permanent = permanent; self.code = code; self.message = message
    }
}
struct SyncResponse: Decodable, Sendable { var results: [SyncItemResult]; var recent: [LedgerTx] }

struct HeartbeatCounts: Decodable, Equatable, Sendable {
    var new: Int; var accepted: Int; var preparing: Int; var ready: Int; var pagerPreparing: Int; var pagerReady: Int
    private enum K: String, CodingKey { case new, accepted, preparing, ready, pagerPreparing, pagerReady }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        new = c.flexInt(.new) ?? 0; accepted = c.flexInt(.accepted) ?? 0; preparing = c.flexInt(.preparing) ?? 0; ready = c.flexInt(.ready) ?? 0
        pagerPreparing = c.flexInt(.pagerPreparing) ?? 0; pagerReady = c.flexInt(.pagerReady) ?? 0
    }
    var isEmpty: Bool { new + accepted + preparing + ready + pagerPreparing + pagerReady == 0 }
}
struct HeartbeatBranch: Decodable, Equatable, Sendable {
    var id: Int; var name: String; var state: String; var paused: Bool; var busy: Bool
    private enum K: String, CodingKey { case id, name, state, paused, busy }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; state = c.string(.state) ?? "open"; paused = c.flexBool(.paused) ?? false; busy = c.flexBool(.busy) ?? false
    }
}
struct Heartbeat: Decodable, Equatable, Sendable {
    var branch: HeartbeatBranch; var counts: HeartbeatCounts; var perms: CashierPerms; var loyalty: Bool; var exp: Int
    private enum K: String, CodingKey { case branch, counts, perms, loyalty, exp }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        branch = try c.decode(HeartbeatBranch.self, forKey: .branch); counts = try c.decode(HeartbeatCounts.self, forKey: .counts)
        perms = (try? c.decode(CashierPerms.self, forKey: .perms)) ?? CashierPerms(); loyalty = c.flexBool(.loyalty) ?? true; exp = c.flexInt(.exp) ?? 0
    }
}
