import Foundation

/// Query string with percent-encoding for the few GET filters.
func cashierQuery(_ items: [(String, String?)]) -> String {
    let parts = items.compactMap { k, v -> String? in
        guard let v, !v.isEmpty else { return nil }
        return k + "=" + (v.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? v)
    }
    return parts.isEmpty ? "" : "?" + parts.joined(separator: "&")
}

/// Drive-Thru orders, counter, stock/pause/speed, summary — `/cashier/{t}/api/drive/…`.
extension CashierSession {
    func driveState(rev: Int?) async throws -> DriveState { try await get("drive/state" + cashierQuery([("rev", rev.map(String.init))])) }
    func driveHistory(query: String, status: String, page: Int = 1) async throws -> HistoryPage {
        try await get("drive/history" + cashierQuery([("q", query), ("status", status), ("page", String(page))]))
    }
    func driveOrder(id: Int) async throws -> OrderDetail { try await get("drive/order/\(id)") }
    func driveAct(id: Int, action: String, body: [String: Any] = [:]) async throws -> OrderActionResult { try await post("drive/order/\(id)/\(action)", body) }
    func driveResolve(text: String) async throws -> OrderActionResult { try await post("drive/resolve", ["text": text]) }
    func driveCreate(items: [[String: Any]], fields: [String: String], idem: String) async throws -> OrderActionResult {
        try await post("drive/order", ["items": items, "fields": fields, "idem": idem])
    }
    func driveMenu() async throws -> DriveMenu { try await get("drive/menu") }
    func driveStock(item: Int, choice: String?, off: Bool, until: String? = nil) async throws {
        var b: [String: Any] = ["item": item, "off": off]
        if let choice { b["choice"] = choice }
        if let until { b["until"] = until }
        let _: Ack = try await post("drive/stock", b)
    }
    /// `minutes` 0 resumes; managers may pass `manual` (until resumed).
    func drivePause(minutes: Int, manual: Bool = false) async throws { let _: Ack = try await post("drive/pause", ["minutes": manual ? "manual" : minutes]) }
    func drivePrep(minutes: Int) async throws { let _: Ack = try await post("drive/prep", ["prep_min": minutes]) }
    func driveSummary() async throws -> DriveSummary { try await get("drive/summary") }
}

/// Preparation screen and smart pager — `/cashier/{t}/api/biz/prep`, `…/api/pager/*`.
extension CashierSession {
    func prepItems() async throws -> [PrepItem] { (try await get("biz/prep") as PrepResponse).items }
    func prepReady(kind: String, id: Int) async throws { let _: Ack = try await post("biz/prep/\(kind)/\(id)/ready", [:]) }
    func pagerState() async throws -> PagerBoard { try await get("pager/state") }
    func pagerHandover() async throws -> PagerBoard { try await get("pager/handover") }
    func pagerCreate(code: String, etaMin: Int?, note: String, phone: String) async throws -> PagerBoard {
        var b: [String: Any] = ["code": code, "note": note, "phone": phone]
        if let etaMin { b["eta_min"] = etaMin }
        return try await post("pager/create", b)
    }
    func pagerOp(id: Int, op: String) async throws -> PagerBoard { try await post("pager/t/\(id)/\(op)", [:]) }
}

/// `{error:false}` answers.
struct Ack: Decodable, Sendable {}
