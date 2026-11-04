import Foundation

// Drive-Thru / preparation / pager DTOs of the cashier API (docs/DRIVE-API-orders.md, docs/API-EXT.md). Money is integer hundredths (halalas).

/// Decodes a value that may be an Int, a numeric string or a Double.
private extension KeyedDecodingContainer {
    func date(_ key: Key) -> Date? { try? decodeIfPresent(Date.self, forKey: key) }
}

struct DriveMoney: Decodable, Equatable, Sendable {
    var subtotal = 0, tax = 0, fee = 0, total = 0, refund = 0
    var currency = "SAR"
    var decimals = 2
    var fmtTotal = ""
    private enum K: String, CodingKey { case subtotal, tax, fee, total, refund, currency, decimals, fmt }
    private enum F: String, CodingKey { case total }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        subtotal = c.flexInt(.subtotal) ?? 0; tax = c.flexInt(.tax) ?? 0; fee = c.flexInt(.fee) ?? 0; total = c.flexInt(.total) ?? 0; refund = c.flexInt(.refund) ?? 0
        currency = c.string(.currency) ?? "SAR"; decimals = c.flexInt(.decimals) ?? 2
        if let f = try? c.nestedContainer(keyedBy: F.self, forKey: .fmt) { fmtTotal = f.string(.total) ?? "" }
    }
    /// "15.00" from cents.
    func text(_ cents: Int) -> String { Fmt.amount(Double(cents) / pow(10, Double(decimals))) }
    var totalText: String { fmtTotal.isEmpty ? text(total) : fmtTotal }
}

struct OrderLine: Decodable, Equatable, Sendable, Identifiable {
    var id: Int; var name: String; var nameEn: String?; var qty: Int; var total: Int; var opts: [String]; var note: String
    private enum K: String, CodingKey { case id, name, nameEn, qty, total, opts, note }
    private struct Opt: Decodable { var name: String?; var n: String?
        init(from d: Decoder) throws { if let s = try? d.singleValueContainer().decode(String.self) { name = s; n = nil } else { let c = try d.container(keyedBy: Keys.self); name = try? c.decodeIfPresent(String.self, forKey: .name); n = try? c.decodeIfPresent(String.self, forKey: .n) } }
        enum Keys: String, CodingKey { case name, n } }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; nameEn = c.string(.nameEn); qty = c.flexInt(.qty) ?? 1; total = c.flexInt(.total) ?? 0
        opts = ((try? c.decode([Opt].self, forKey: .opts)) ?? []).compactMap { $0.name ?? $0.n }; note = c.string(.note) ?? ""
    }
    var title: String { L10n.language == .en ? (nameEn ?? name) : name }
}

struct OrderCar: Decodable, Equatable, Sendable {
    var type = "", color = "", colorHex = "", plate = "", plateLetters = "", plateDigits = ""
    private enum K: String, CodingKey { case type, color, colorHex, plate, plateLetters, plateDigits }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        type = c.string(.type) ?? ""; color = c.string(.color) ?? ""; colorHex = c.string(.colorHex) ?? ""; plate = c.string(.plate) ?? ""
        plateLetters = c.string(.plateLetters) ?? ""; plateDigits = c.string(.plateDigits) ?? ""
    }
    var isEmpty: Bool { plate.isEmpty && type.isEmpty && color.isEmpty }
}

struct OrderPay: Decodable, Equatable, Sendable {
    var status = "unpaid"; var method: String?
    private enum K: String, CodingKey { case status, method }
    init() {}
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); status = c.string(.status) ?? "unpaid"; method = c.string(.method) }
}

struct OrderTimes: Decodable, Equatable, Sendable {
    var createdAt: Date?, pickupAt: Date?, etaAt: Date?, dueAt: Date?, startBy: Date?, acceptedAt: Date?, readyAt: Date?, deliveredAt: Date?, arrivedAt: Date?
    private enum K: String, CodingKey { case createdAt, pickupAt, etaAt, dueAt, startBy, acceptedAt, readyAt, deliveredAt, arrivedAt }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        createdAt = c.date(.createdAt); pickupAt = c.date(.pickupAt); etaAt = c.date(.etaAt); dueAt = c.date(.dueAt); startBy = c.date(.startBy)
        acceptedAt = c.date(.acceptedAt); readyAt = c.date(.readyAt); deliveredAt = c.date(.deliveredAt); arrivedAt = c.date(.arrivedAt)
    }
}

struct OrderFlags: Decodable, Equatable, Sendable {
    var upcoming = false, arrived = false, late = false, stale = false, notifyFailed = false, newCustomer = false, flagged = false
    var out: [Int] = []; var sameCar: [String] = []
    private enum K: String, CodingKey { case upcoming, arrived, late, stale, notifyFailed, newCustomer, flagged, out, sameCar }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        upcoming = c.flexBool(.upcoming) ?? false; arrived = c.flexBool(.arrived) ?? false; late = c.flexBool(.late) ?? false; stale = c.flexBool(.stale) ?? false
        notifyFailed = c.flexBool(.notifyFailed) ?? false; newCustomer = c.flexBool(.newCustomer) ?? false; flagged = c.flexBool(.flagged) ?? false
        out = (try? c.decode([Int].self, forKey: .out)) ?? []; sameCar = (try? c.decode([String].self, forKey: .sameCar)) ?? []
    }
}

struct LoyaltyAward: Decodable, Equatable, Sendable {
    var status: String?; var qty: Int; var unit: String?; var balance: Int?; var rewardUnlocked: Bool
    private enum K: String, CodingKey { case status, qty, unit, balance, rewardUnlocked }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        status = c.string(.status); qty = c.flexInt(.qty) ?? 0; unit = c.string(.unit); balance = c.flexInt(.balance); rewardUnlocked = c.flexBool(.rewardUnlocked) ?? false
    }
}

/// One order as the cashier sees it (`Dto::staff`).
struct OrderCard: Decodable, Equatable, Sendable, Identifiable {
    var id: Int
    var code: String
    var display: String
    var status: String
    var source: String
    var trust: String
    var branchName: String
    var name: String
    var phone: String?
    var phoneLast4: String
    var car: OrderCar
    var note: String
    var staffNote: String
    var lines: [OrderLine]
    var itemCount: Int
    var money: DriveMoney
    var pay: OrderPay
    var times: OrderTimes
    var prepMin: Int?
    var lane: String
    var flags: OrderFlags
    var actions: [String]
    var undoUntil: Date?
    var cancelCode: String?
    var cancelReason: String?
    var loyaltyAward: LoyaltyAward?
    var deliverEnabled: Bool

    func can(_ a: String) -> Bool { actions.contains(a) }
    var isPaid: Bool { pay.status == "paid" }
    var customerTitle: String { name.isEmpty ? (car.plate.isEmpty ? display : car.plate) : name }

    private enum K: String, CodingKey { case id, code, display, status, source, trust, branch, name, phone, phoneLast4, car, note, staffNote, lines, itemCount, money, pay, times, prepMin, lane, flags, actions, undoUntil, cancel, loyaltyAward, deliverEnabled }
    private struct B: Decodable { var name: String? }
    private struct Cn: Decodable { var code: String?; var reason: String? }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; code = c.string(.code) ?? ""; display = c.string(.display) ?? ""; status = c.string(.status) ?? "new"; source = c.string(.source) ?? "page"; trust = c.string(.trust) ?? "new"
        branchName = (try? c.decode(B.self, forKey: .branch))?.name ?? ""; name = c.string(.name) ?? ""; phone = c.string(.phone); phoneLast4 = c.string(.phoneLast4) ?? ""
        car = (try? c.decode(OrderCar.self, forKey: .car)) ?? OrderCar(); note = c.string(.note) ?? ""; staffNote = c.string(.staffNote) ?? ""
        lines = (try? c.decode([OrderLine].self, forKey: .lines)) ?? []; itemCount = c.flexInt(.itemCount) ?? lines.reduce(0) { $0 + $1.qty }
        money = (try? c.decode(DriveMoney.self, forKey: .money)) ?? DriveMoney(); pay = (try? c.decode(OrderPay.self, forKey: .pay)) ?? OrderPay()
        times = (try? c.decode(OrderTimes.self, forKey: .times)) ?? OrderTimes(); prepMin = c.flexInt(.prepMin); lane = c.string(.lane) ?? ""
        flags = (try? c.decode(OrderFlags.self, forKey: .flags)) ?? OrderFlags(); actions = (try? c.decode([String].self, forKey: .actions)) ?? []
        undoUntil = c.date(.undoUntil); let cn = try? c.decode(Cn.self, forKey: .cancel); cancelCode = cn?.code; cancelReason = cn?.reason
        loyaltyAward = try? c.decodeIfPresent(LoyaltyAward.self, forKey: .loyaltyAward); deliverEnabled = c.flexBool(.deliverEnabled) ?? false
    }
}

struct DrivePayConfig: Decodable, Equatable, Sendable {
    var methods: [String] = ["cash"]; var single: String?; var required = false
    private enum K: String, CodingKey { case methods, single, required }
    init() {}
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); methods = (try? c.decode([String].self, forKey: .methods)) ?? ["cash"]; single = c.string(.single); required = c.flexBool(.required) ?? false }
}

struct DriveBranchState: Decodable, Equatable, Sendable {
    var name = ""; var open = true; var reason = "open"; var receiving = false; var prepMin = 0; var pausedUntil: Date?; var avgPrepMin: Int?
    private enum K: String, CodingKey { case name, open, reason, receiving, prepMin, pausedUntil, avgPrepMin }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        name = c.string(.name) ?? ""; open = c.flexBool(.open) ?? true; reason = c.string(.reason) ?? "open"; receiving = c.flexBool(.receiving) ?? false
        prepMin = c.flexInt(.prepMin) ?? 0; pausedUntil = c.date(.pausedUntil); avgPrepMin = c.flexInt(.avgPrepMin)
    }
    var isPaused: Bool { reason == "paused" }
}

struct DriveCounts: Decodable, Equatable, Sendable {
    var new = 0, making = 0, ready = 0, upcoming = 0, arrived = 0
    private enum K: String, CodingKey { case new, making, ready, upcoming, arrived }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        new = c.flexInt(.new) ?? 0; making = c.flexInt(.making) ?? 0; ready = c.flexInt(.ready) ?? 0; upcoming = c.flexInt(.upcoming) ?? 0; arrived = c.flexInt(.arrived) ?? 0
    }
}

/// `GET drive/state`: the lanes of the board. `changed == false` means the lanes/counts were omitted (same `rev`).
struct DriveState: Decodable, Equatable, Sendable {
    var drive: Bool
    var perms: CashierPerms
    var rev: Int
    var changed: Bool
    var deliverEnabled: Bool
    var pay: DrivePayConfig
    var branch: DriveBranchState
    var counts: DriveCounts?
    var lanes: DriveLanes?
    var loyalty: Bool
    var autoAward: Bool
    var nextReleaseAt: Date?

    private enum K: String, CodingKey { case drive, perms, rev, changed, deliverEnabled, pay, branch, counts, lanes, loyalty, autoAward, nextReleaseAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        drive = c.flexBool(.drive) ?? false; perms = (try? c.decode(CashierPerms.self, forKey: .perms)) ?? CashierPerms(); rev = c.flexInt(.rev) ?? 0; changed = c.flexBool(.changed) ?? true
        deliverEnabled = c.flexBool(.deliverEnabled) ?? false; pay = (try? c.decode(DrivePayConfig.self, forKey: .pay)) ?? DrivePayConfig()
        branch = (try? c.decode(DriveBranchState.self, forKey: .branch)) ?? DriveBranchState(); counts = try? c.decodeIfPresent(DriveCounts.self, forKey: .counts)
        lanes = try? c.decodeIfPresent(DriveLanes.self, forKey: .lanes); loyalty = c.flexBool(.loyalty) ?? false; autoAward = c.flexBool(.autoAward) ?? false; nextReleaseAt = c.date(.nextReleaseAt)
    }
}

struct DriveLanes: Decodable, Equatable, Sendable {
    var arrived: [OrderCard] = [], new: [OrderCard] = [], making: [OrderCard] = [], ready: [OrderCard] = [], upcoming: [OrderCard] = []
    private enum K: String, CodingKey { case arrived, new, making, ready, upcoming }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        arrived = (try? c.decode([OrderCard].self, forKey: .arrived)) ?? []; new = (try? c.decode([OrderCard].self, forKey: .new)) ?? []
        making = (try? c.decode([OrderCard].self, forKey: .making)) ?? []; ready = (try? c.decode([OrderCard].self, forKey: .ready)) ?? []
        upcoming = (try? c.decode([OrderCard].self, forKey: .upcoming)) ?? []
    }
    var all: [OrderCard] { arrived + new + making + ready + upcoming }
}

struct OrderLogEntry: Decodable, Equatable, Sendable, Identifiable {
    var id = UUID()
    var action: String; var actorName: String; var note: String; var at: Date?
    private enum K: String, CodingKey { case action, actor, note, at }
    private struct A: Decodable { var name: String? }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        action = c.string(.action) ?? ""; actorName = (try? c.decode(A.self, forKey: .actor))?.name ?? ""; note = c.string(.note) ?? ""; at = c.date(.at)
    }
    static func == (l: OrderLogEntry, r: OrderLogEntry) -> Bool { l.action == r.action && l.at == r.at && l.actorName == r.actorName }
}
struct OrderDetail: Decodable, Equatable, Sendable { var order: OrderCard; var log: [OrderLogEntry] }
struct HistoryPage: Decodable, Equatable, Sendable { var rows: [OrderCard]; var total: Int; var page: Int; var pages: Int }

/// Answer of `POST order/{id}/{action}`.
struct OrderActionResult: Decodable, Equatable, Sendable {
    var order: OrderCard; var instruction: String?; var loyalty: LoyaltyAward?; var undoUntil: Date?
    private enum K: String, CodingKey { case order, instruction, loyalty, undoUntil }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        order = try c.decode(OrderCard.self, forKey: .order); instruction = c.string(.instruction); loyalty = try? c.decodeIfPresent(LoyaltyAward.self, forKey: .loyalty); undoUntil = c.date(.undoUntil)
    }
}

// MARK: menu / stock

/// Menu prices are DECIMAL units (15, 2.5) — unlike orders, whose money is integer hundredths.
struct MenuChoice: Decodable, Equatable, Sendable, Identifiable { var id: String; var name: String; var price: Double; var isDefault: Bool; var out: Bool
    private enum K: String, CodingKey { case id, name, price, `default`, out }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); id = c.string(.id) ?? ""; name = c.string(.name) ?? ""; price = c.flexDouble(.price) ?? 0; isDefault = c.flexBool(.default) ?? false; out = c.flexBool(.out) ?? false }
}
struct MenuGroup: Decodable, Equatable, Sendable, Identifiable { var id: String; var name: String; var type: String; var required: Bool; var max: Int; var choices: [MenuChoice]
    private enum K: String, CodingKey { case id, name, type, required, max, choices }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); id = c.string(.id) ?? ""; name = c.string(.name) ?? ""; type = c.string(.type) ?? "single"; required = c.flexBool(.required) ?? false; max = c.flexInt(.max) ?? 1; choices = (try? c.decode([MenuChoice].self, forKey: .choices)) ?? [] }
}
struct MenuItem: Decodable, Equatable, Sendable, Identifiable { var id: Int; var name: String; var desc: String; var price: Double; var out: Bool; var opts: [MenuGroup]
    private enum K: String, CodingKey { case id, name, desc, price, out, opts }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; desc = c.string(.desc) ?? ""; price = c.flexDouble(.price) ?? 0; out = c.flexBool(.out) ?? false; opts = (try? c.decode([MenuGroup].self, forKey: .opts)) ?? [] }
}
struct MenuCategory: Decodable, Equatable, Sendable, Identifiable { var id: Int; var name: String; var items: [MenuItem]
    private enum K: String, CodingKey { case id, name, items }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; items = (try? c.decode([MenuItem].self, forKey: .items)) ?? [] }
}
struct DriveMenu: Decodable, Equatable, Sendable { var categories: [MenuCategory]; var currency: String
    private enum K: String, CodingKey { case menu, currency }
    private enum M: String, CodingKey { case categories }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); currency = c.string(.currency) ?? "SAR"; categories = (try? c.nestedContainer(keyedBy: M.self, forKey: .menu).decode([MenuCategory].self, forKey: .categories)) ?? [] }
}

// MARK: summary (manager)

struct DriveToday: Decodable, Equatable, Sendable {
    var day = ""; var orders = 0, delivered = 0, closed = 0, lost = 0, valueC = 0; var avgPrepMin: Int?
    var cashC: Int?, cardC: Int?, refundsC: Int?, refundN: Int?, unpaidN: Int?, unpaidC: Int?; var deliverEnabled = false
    private enum K: String, CodingKey { case day, orders, delivered, closed, lost, valueC, avgPrepMin, cashC, cardC, refundsC, refundN, unpaidN, unpaidC, deliverEnabled }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        day = c.string(.day) ?? ""; orders = c.flexInt(.orders) ?? 0; delivered = c.flexInt(.delivered) ?? 0; closed = c.flexInt(.closed) ?? 0; lost = c.flexInt(.lost) ?? 0; valueC = c.flexInt(.valueC) ?? 0
        avgPrepMin = c.flexInt(.avgPrepMin); cashC = c.flexInt(.cashC); cardC = c.flexInt(.cardC); refundsC = c.flexInt(.refundsC); refundN = c.flexInt(.refundN); unpaidN = c.flexInt(.unpaidN); unpaidC = c.flexInt(.unpaidC)
        deliverEnabled = c.flexBool(.deliverEnabled) ?? false
    }
}
struct PeakHour: Equatable, Sendable, Identifiable { var hour: Int; var count: Int; var id: Int { hour } }
struct TopItem: Decodable, Equatable, Sendable, Identifiable { var id: Int; var name: String; var qty: Int; var valueC: Int
    private enum K: String, CodingKey { case id, name, qty, valueC }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; qty = c.flexInt(.qty) ?? 0; valueC = c.flexInt(.valueC) ?? 0 }
}
struct DriveReport: Decodable, Equatable, Sendable {
    var avgTicketC = 0; var avgPrepMin: Int?; var cancelRate: Double = 0; var peak: [PeakHour] = []; var topItems: [TopItem] = []; var currency = "SAR"
    var total = 0, completed = 0, cancelled = 0, rejected = 0
    private enum K: String, CodingKey { case avgTicketC, avgPrepMin, cancelRate, peak, topItems, currency, orders }
    private enum O: String, CodingKey { case total, completed, cancelled, rejected }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        avgTicketC = c.flexInt(.avgTicketC) ?? 0; avgPrepMin = c.flexInt(.avgPrepMin); cancelRate = c.flexDouble(.cancelRate) ?? 0; currency = c.string(.currency) ?? "SAR"
        peak = ((try? c.decode([Int].self, forKey: .peak)) ?? []).enumerated().map { PeakHour(hour: $0.offset, count: $0.element) }
        topItems = (try? c.decode([TopItem].self, forKey: .topItems)) ?? []
        if let o = try? c.nestedContainer(keyedBy: O.self, forKey: .orders) { total = o.flexInt(.total) ?? 0; completed = o.flexInt(.completed) ?? 0; cancelled = o.flexInt(.cancelled) ?? 0; rejected = o.flexInt(.rejected) ?? 0 }
    }
}
struct DriveSummary: Decodable, Equatable, Sendable { var today: DriveToday; var report: DriveReport }

// MARK: preparation screen + pager

struct PrepLine: Decodable, Equatable, Sendable, Identifiable { var id = UUID(); var qty: Int; var name: String; var opts: [String]; var note: String
    private enum K: String, CodingKey { case qty, name, opts, note }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); qty = c.flexInt(.qty) ?? 1; name = c.string(.name) ?? ""; opts = (try? c.decode([String].self, forKey: .opts)) ?? []; note = c.string(.note) ?? "" }
    static func == (l: PrepLine, r: PrepLine) -> Bool { l.qty == r.qty && l.name == r.name && l.opts == r.opts && l.note == r.note }
}
struct PrepItem: Decodable, Equatable, Sendable, Identifiable {
    var kind: String; var itemId: Int; var number: String; var status: String; var lines: [PrepLine]; var note: String; var since: Date?; var eta: Date?; var etaMin: Int?
    var id: String { "\(kind)-\(itemId)" }
    private enum K: String, CodingKey { case kind, id, number, status, lines, note, since, eta, etaMin }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        kind = c.string(.kind) ?? "order"; itemId = c.flexInt(.id) ?? 0; number = c.string(.number) ?? ""; status = c.string(.status) ?? ""; lines = (try? c.decode([PrepLine].self, forKey: .lines)) ?? []
        note = c.string(.note) ?? ""; since = c.date(.since); eta = c.date(.eta); etaMin = c.flexInt(.etaMin)
    }
}
struct PrepResponse: Decodable, Sendable { var items: [PrepItem] }

struct PagerTicket: Decodable, Equatable, Sendable, Identifiable {
    var id: Int; var token: String; var number: String; var status: String; var source: String; var note: String; var etaMin: Int?; var createdAt: Date?; var readyAt: Date?; var phone: String?; var invoice: String
    private enum K: String, CodingKey { case id, token, number, status, source, note, etaMin, createdAt, readyAt, phone, invoice, eta_min, created_at, ready_at }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; token = c.string(.token) ?? ""; number = c.string(.number) ?? ""; status = c.string(.status) ?? ""; source = c.string(.source) ?? "manual"; note = c.string(.note) ?? ""; invoice = c.string(.invoice) ?? ""
        etaMin = c.flexInt(.etaMin) ?? c.flexInt(.eta_min); createdAt = c.date(.createdAt) ?? c.date(.created_at); readyAt = c.date(.readyAt) ?? c.date(.ready_at); phone = c.string(.phone)
    }
}
struct PagerBoard: Decodable, Equatable, Sendable { var tickets: [PagerTicket]; var etaMin: Int?
    private enum K: String, CodingKey { case tickets, etaMin }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); tickets = (try? c.decode([PagerTicket].self, forKey: .tickets)) ?? []; etaMin = c.flexInt(.etaMin) }
}
