import Foundation

// Bookings of the owner (cafbio-mobile: BookingsApi.php, routes-owner-core.php). When the module is off or not in the plan every route answers 404 `module_off`.

/// The five statuses of a booking. `held` rows (a slot kept during checkout) never reach the app.
enum OwnerBookingStatus: String, CaseIterable, Identifiable, Sendable {
    case pending, confirmed, cancelled, completed, noShow = "no_show"
    var id: String { rawValue }
    /// The word the status route accepts for moving a booking here.
    var action: String { switch self { case .pending: "pending"; case .confirmed: "confirm"; case .cancelled: "cancel"; case .completed: "complete"; case .noShow: "no_show" } }
    /// Open ones still occupy a slot and want the owner's attention.
    var isOpen: Bool { self == .pending || self == .confirmed }
}

/// What the owner can press on a booking. Mirrors `Booker::setStatus` on the website.
enum OwnerBookingAction: String, CaseIterable, Identifiable, Sendable {
    case confirm, cancel, complete, noShow = "no_show"
    var id: String { rawValue }
    var target: OwnerBookingStatus { switch self { case .confirm: .confirmed; case .cancel: .cancelled; case .complete: .completed; case .noShow: .noShow } }
    /// Which buttons make sense from a status (a finished booking is final).
    static func available(from s: OwnerBookingStatus) -> [OwnerBookingAction] {
        switch s {
        case .pending: [.confirm, .cancel]
        case .confirmed: [.complete, .noShow, .cancel]
        case .cancelled, .completed, .noShow: []
        }
    }
}

struct OwnerBooking: Decodable, Equatable, Identifiable, Sendable {
    var id: Int
    var code: String
    var customerName: String
    var phoneMasked: String
    var service: String
    var staff: String
    var startsAt: Date?
    var endsAt: Date?
    var status: OwnerBookingStatus
    var paid: Bool
    var people: Int
    var price: Double

    init(id: Int, code: String = "", customerName: String = "", phoneMasked: String = "", service: String = "", staff: String = "", startsAt: Date? = nil, endsAt: Date? = nil,
         status: OwnerBookingStatus = .pending, paid: Bool = false, people: Int = 1, price: Double = 0) {
        self.id = id; self.code = code; self.customerName = customerName; self.phoneMasked = phoneMasked; self.service = service; self.staff = staff
        self.startsAt = startsAt; self.endsAt = endsAt; self.status = status; self.paid = paid; self.people = people; self.price = price
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; code = c.string(.code) ?? ""; customerName = c.string(.customerName) ?? ""; phoneMasked = c.string(.phoneMasked) ?? ""
        service = c.string(.service) ?? ""; staff = c.string(.staff) ?? ""
        startsAt = try? c.decodeIfPresent(Date.self, forKey: .startsAt); endsAt = try? c.decodeIfPresent(Date.self, forKey: .endsAt)
        status = OwnerBookingStatus(rawValue: c.string(.status) ?? "") ?? .pending
        paid = c.flexBool(.paid) ?? false; people = c.flexInt(.people) ?? 1; price = c.flexDouble(.price) ?? 0
    }
    enum K: String, CodingKey { case id, code, customerName, phoneMasked, service, staff, startsAt, endsAt, status, paid, people, price }
}

struct OwnerBookingService: Decodable, Equatable, Identifiable, Sendable {
    var id: Int, name: String, duration: Int, price: Double, color: String, capacity: Int, active: Bool
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; duration = c.flexInt(.duration) ?? 0; price = c.flexDouble(.price) ?? 0
        color = c.string(.color) ?? ""; capacity = c.flexInt(.capacity) ?? 1; active = c.flexBool(.active) ?? true
    }
    enum K: String, CodingKey { case id, name, duration, price, color, capacity, active }
}

struct OwnerBookingStaff: Decodable, Equatable, Identifiable, Sendable {
    var id: Int, name: String, title: String, active: Bool, serviceIds: [Int]
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; title = c.string(.title) ?? ""; active = c.flexBool(.active) ?? true
        serviceIds = (try? c.decode([Int].self, forKey: .serviceIds)) ?? []
    }
    enum K: String, CodingKey { case id, name, title, active, serviceIds }
}

struct OwnerBookingCustomer: Decodable, Equatable, Identifiable, Sendable {
    var id: Int, name: String, phoneMasked: String, email: String, bookingsCount: Int, lastVisit: Date?, nextAt: Date?, spent: Double
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        id = c.flexInt(.id) ?? 0; name = c.string(.name) ?? ""; phoneMasked = c.string(.phoneMasked) ?? ""; email = c.string(.email) ?? ""
        bookingsCount = c.flexInt(.bookingsCount) ?? 0; lastVisit = try? c.decodeIfPresent(Date.self, forKey: .lastVisit); nextAt = try? c.decodeIfPresent(Date.self, forKey: .nextAt)
        spent = c.flexDouble(.spent) ?? 0
    }
    enum K: String, CodingKey { case id, name, phoneMasked, email, bookingsCount, lastVisit, nextAt, spent }
}

/// `GET bookings/summary?range=`: counts of the last N days plus today and what is coming.
struct OwnerBookingsSummary: Decodable, Equatable, Sendable {
    var range = "30d"
    var total = 0, pending = 0, confirmed = 0, completed = 0, cancelled = 0, noShow = 0, today = 0, upcoming = 0
    var revenue = 0.0
    /// The business's time zone (IANA name) when the server sends it; days are cut there, not on the phone's clock.
    var timezone: String?
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        range = c.string(.range) ?? "30d"; total = c.flexInt(.total) ?? 0; pending = c.flexInt(.pending) ?? 0; confirmed = c.flexInt(.confirmed) ?? 0
        completed = c.flexInt(.completed) ?? 0; cancelled = c.flexInt(.cancelled) ?? 0; noShow = c.flexInt(.noShow) ?? 0; today = c.flexInt(.today) ?? 0
        upcoming = c.flexInt(.upcoming) ?? 0; revenue = c.flexDouble(.revenue) ?? 0; timezone = c.string(.timezone) ?? c.string(.tz)
    }
    enum K: String, CodingKey { case range, total, pending, confirmed, completed, cancelled, noShow, today, upcoming, revenue, timezone, tz }
}

struct OwnerBookingPage<Item: Decodable & Sendable>: Decodable, Sendable {
    var items: [Item]
    var nextCursor: String?
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        items = (try? c.decode([Item].self, forKey: .items)) ?? []; nextCursor = c.string(.nextCursor)
    }
    enum K: String, CodingKey { case items, nextCursor }
}

private struct OwnerBookingResponse: Decodable { var booking: OwnerBooking }
private struct OwnerItems<Item: Decodable & Sendable>: Decodable, Sendable {
    var items: [Item]
}

extension OwnerSession {
    /// Day strings (`yyyy-MM-dd`) are in the business's time zone on the server; `from`/`to` are both inclusive.
    func bookings(from: String? = nil, to: String? = nil, status: OwnerBookingStatus? = nil, cursor: String? = nil, limit: Int = 100) async throws -> OwnerBookingPage<OwnerBooking> {
        var q = ["limit=\(limit)"]
        if let from { q.append("from=\(from)") }
        if let to { q.append("to=\(to)") }
        if let status { q.append("status=\(status.rawValue)") }
        if let cursor { q.append("cursor=\(Self.queryEscaped(cursor))") }
        return try decode(OwnerBookingPage<OwnerBooking>.self, try await get("bookings?" + q.joined(separator: "&")))
    }

    /// Moves a booking to a new status; the server sends the customer the same message as the website. Answers the booking as it is now.
    func setBookingStatus(_ id: Int, action: OwnerBookingAction) async throws -> OwnerBooking {
        try decode(OwnerBookingResponse.self, try await post("bookings/\(id)/status", ["status": action.rawValue])).booking
    }

    func bookingServices() async throws -> [OwnerBookingService] { try decode(OwnerItems<OwnerBookingService>.self, try await get("bookings/services")).items }
    func bookingStaff() async throws -> [OwnerBookingStaff] { try decode(OwnerItems<OwnerBookingStaff>.self, try await get("bookings/staff")).items }
    func bookingCustomers(query: String = "", cursor: String? = nil) async throws -> OwnerBookingPage<OwnerBookingCustomer> {
        var q = ["limit=30"]
        if !query.isEmpty { q.append("q=\(Self.queryEscaped(query))") }
        if let cursor { q.append("cursor=\(Self.queryEscaped(cursor))") }
        return try decode(OwnerBookingPage<OwnerBookingCustomer>.self, try await get("bookings/customers?" + q.joined(separator: "&")))
    }
    func bookingsSummary(days: Int = 30) async throws -> OwnerBookingsSummary { try decode(OwnerBookingsSummary.self, try await get("bookings/summary?range=\(days)d")) }

    nonisolated static func queryEscaped(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")) ?? "" }
}
