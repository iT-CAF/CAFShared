import Foundation

// The subscription screen of the owner app (cafbio-mobile: BillingApi). Amounts are integers in halalas (SAR x 100) whatever server driver fills them.
// `renew.available` is the server's last word (switch app_renew_in_app, payment gateway, billing mode): the app adds its own check of `features.app_renew_in_app`.

/// `GET account/billing`.
struct OwnerBilling: Decodable, Equatable, Sendable {
    struct Plan: Decodable, Equatable, Sendable {
        var id = 0, name = "", slug = "", free = false, trial = false, admin = false, lifetime = false, expired = false
        var expiresAt: Date?, daysLeft: Int?
        init() {}
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; slug = c.string(.slug) ?? ""
            free = c.flexBool(.free) ?? false; trial = c.flexBool(.trial) ?? false; admin = c.flexBool(.admin) ?? false; lifetime = c.flexBool(.lifetime) ?? false; expired = c.flexBool(.expired) ?? false
            expiresAt = try? c.decodeIfPresent(Date.self, forKey: .expiresAt); daysLeft = c.flexInt(.daysLeft)
        }
        enum K: String, CodingKey { case id, name, slug, free, trial, admin, lifetime, expired, expiresAt, daysLeft }
    }

    struct Card: Decodable, Equatable, Sendable {
        var brand = "", last4 = ""
        init(brand: String = "", last4: String = "") { self.brand = brand; self.last4 = last4 }
        init(from d: Decoder) throws { let c = try d.container(keyedBy: K.self); brand = c.string(.brand) ?? ""; last4 = c.string(.last4) ?? "" }
        enum K: String, CodingKey { case brand, last4 }
    }

    /// `status`: none | trialing | active | past_due | grace | expired | canceled. `source`: core | cafbio-billing.
    struct Subscription: Decodable, Equatable, Sendable {
        var status = "none", autoRenew = false, cancelAtPeriodEnd = false, cycle: String?, nextAmount = 0, currency = "SAR", source = "core", renewsAt: Date?, card: Card?
        init() {}
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            status = c.string(.status) ?? "none"; autoRenew = c.flexBool(.autoRenew) ?? false; cancelAtPeriodEnd = c.flexBool(.cancelAtPeriodEnd) ?? false
            cycle = c.string(.cycle); nextAmount = c.flexInt(.nextAmount) ?? 0; currency = c.string(.currency) ?? "SAR"; source = c.string(.source) ?? "core"
            renewsAt = try? c.decodeIfPresent(Date.self, forKey: .renewsAt); card = try? c.decodeIfPresent(Card.self, forKey: .card)
        }
        enum K: String, CodingKey { case status, autoRenew, cancelAtPeriodEnd, cycle, nextAmount, currency, source, renewsAt, card }
    }

    /// One payment. `status`: paid | pending | refunded | failed… `receiptPath` is a website path to open in the signed-in web sheet.
    struct Payment: Decodable, Equatable, Identifiable, Sendable {
        var id: String, date: Date?, amount: Int, currency: String, status: String, receiptPath: String?
        init(id: String, date: Date? = nil, amount: Int = 0, currency: String = "SAR", status: String = "paid", receiptPath: String? = nil) {
            self.id = id; self.date = date; self.amount = amount; self.currency = currency; self.status = status; self.receiptPath = receiptPath
        }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            id = c.string(.id) ?? ""; date = try? c.decodeIfPresent(Date.self, forKey: .date); amount = c.flexInt(.amount) ?? 0; currency = c.string(.currency) ?? "SAR"
            status = (c.string(.status) ?? "paid").lowercased(); receiptPath = Self.sitePath(c.string(.receiptPath))
        }
        enum K: String, CodingKey { case id, date, amount, currency, status, receiptPath }
        var value: Double { Double(amount) / 100 }
    }

    struct Invoice: Decodable, Equatable, Identifiable, Sendable {
        var number: String, issuedAt: Date?, total: Int, currency: String, pdfPath: String?, path: String?
        var id: String { number }
        init(number: String, issuedAt: Date? = nil, total: Int = 0, currency: String = "SAR", pdfPath: String? = nil, path: String? = nil) {
            self.number = number; self.issuedAt = issuedAt; self.total = total; self.currency = currency; self.pdfPath = pdfPath; self.path = path
        }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            number = c.string(.number) ?? ""; issuedAt = try? c.decodeIfPresent(Date.self, forKey: .issuedAt); total = c.flexInt(.total) ?? 0; currency = c.string(.currency) ?? "SAR"
            pdfPath = Payment.sitePath(c.string(.pdfPath)); path = Payment.sitePath(c.string(.path))
        }
        enum K: String, CodingKey { case number, issuedAt, total, currency, pdfPath, path }
        var value: Double { Double(total) / 100 }
        /// What a tap opens: the PDF when there is one.
        var openPath: String? { pdfPath ?? path }
    }

    /// `reason` when not available: billing_off | ios_mode | gateway | admin | twofa | no_plan | lifetime | plan | cycle | unavailable.
    struct Renew: Decodable, Equatable, Sendable {
        var available = false, reason: String? = "billing_off", planId: Int?, cycle: String?, amount: Int?, currency = "SAR"
        init() {}
        init(available: Bool, reason: String? = nil, planId: Int? = nil, cycle: String? = nil, amount: Int? = nil, currency: String = "SAR") {
            self.available = available; self.reason = reason; self.planId = planId; self.cycle = cycle; self.amount = amount; self.currency = currency
        }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: K.self)
            available = c.flexBool(.available) ?? false; reason = c.string(.reason); planId = c.flexInt(.planId); cycle = c.string(.cycle)
            if let p = try? c.nestedContainer(keyedBy: P.self, forKey: .price) { amount = p.flexInt(.amount); currency = p.string(.currency) ?? "SAR" }
        }
        enum K: String, CodingKey { case available, reason, planId, cycle, price }
        enum P: String, CodingKey { case amount, currency }
        var value: Double? { amount.map { Double($0) / 100 } }
    }

    var plan = Plan()
    var usage: [OwnerAccountInfo.UsageRow] = []
    var subscription = Subscription()
    var payments: [Payment] = []
    var invoices: [Invoice] = []
    var renew = Renew()
    var currency = "SAR"

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        plan = (try? c.decode(Plan.self, forKey: .plan)) ?? Plan()
        usage = OwnerAccountInfo.usageRows(in: c, forKey: .usage)
        subscription = (try? c.decode(Subscription.self, forKey: .subscription)) ?? Subscription()
        payments = ((try? c.decode([Payment].self, forKey: .payments)) ?? []).filter { !$0.id.isEmpty }
        invoices = ((try? c.decode([Invoice].self, forKey: .invoices)) ?? []).filter { !$0.number.isEmpty }
        renew = (try? c.decode(Renew.self, forKey: .renew)) ?? Renew()
        currency = c.string(.currency) ?? "SAR"
    }
    enum K: String, CodingKey { case plan, usage, subscription, payments, invoices, renew, currency }

    /// The newest payment that went through: a change here after a checkout means the payment landed.
    var lastPaidID: String? { payments.first { $0.status == "paid" }?.id }
}

extension OwnerBilling.Payment {
    /// A path the web sheet may open: site-relative, one leading slash (the server's paths are; anything else is dropped rather than guessed at).
    static func sitePath(_ s: String?) -> String? {
        guard let s, s.hasPrefix("/"), !s.hasPrefix("//"), s.count < 500 else { return nil }
        return s
    }
}

/// Answer of `POST account/billing/renew-link`.
struct OwnerRenewLink: Decodable, Equatable, Sendable {
    var url: URL, expiresIn: Int, returnURL: String, planId: Int?, cycle: String?
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        guard let s = c.string(.url), let u = URL(string: s) else { throw DecodingError.dataCorruptedError(forKey: .url, in: c, debugDescription: "url") }
        url = u; expiresIn = c.flexInt(.expiresIn) ?? 60; returnURL = c.string(.returnUrl) ?? "cafbio://billing/done"; planId = c.flexInt(.planId); cycle = c.string(.cycle)
    }
    enum K: String, CodingKey { case url, expiresIn, returnUrl, planId, cycle }
}

extension OwnerSession {
    /// Plan, usage, subscription, payments, invoices and whether renewing is offered. Reading is always allowed; only `renew` depends on the admin switch.
    func billing() async throws -> OwnerBilling { try decode(OwnerBilling.self, try await get("account/billing")) }

    /// A one-time URL (60 s) into the website checkout. Refused with `billing_off` while the switch is off.
    func renewLink(planId: Int? = nil, cycle: String? = nil) async throws -> OwnerRenewLink {
        var body: [String: Any] = [:]
        if let planId { body["plan_id"] = planId }
        if let cycle { body["cycle"] = cycle }
        return try decode(OwnerRenewLink.self, try await post("account/billing/renew-link", body))
    }
}
