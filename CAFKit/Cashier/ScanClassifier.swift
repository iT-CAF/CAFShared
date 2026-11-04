import Foundation

/// What a scanned / typed string most likely is. Pure and unit-tested; the SERVER stays the authority (this only picks where to ask first).
enum ScanIntent: Equatable, Sendable {
    /// `LOYR:<code>` — a one-time reward code from a member's card.
    case redeemCode(String)
    /// A Drive order's tracking token / link (40 hex) → the order.
    case orderToken(String)
    /// A pager ticket link (`/p/<slug>/<32 hex>` or `/rannah/t/<32 hex>`) → the ticket.
    case ticketToken(String)
    /// Anything else (member card, phone, `#0042`, plate, order number, POS invoice, ticket number…): ask every source the person may use.
    case text(String)

    static func classify(_ raw: String) -> ScanIntent {
        let q = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) && $0.value != 0x200E && $0.value != 0x200F && $0.value != 0x200B }.map(Character.init).reduce(into: "") { $0.append($1) }.trimmed
        if q.range(of: #"^LOYR[:\s]"#, options: [.regularExpression, .caseInsensitive]) != nil { return .redeemCode(q) }
        if let m = q.range(of: #"(?<![a-f0-9])[a-f0-9]{40}(?![a-f0-9])"#, options: [.regularExpression, .caseInsensitive]) { return .orderToken(String(q[m]).lowercased()) }
        if let m = q.range(of: #"/(?:rannah/t|p)/(?:[a-z0-9]{6,24}/)?[a-f0-9]{32}(?![a-f0-9])"#, options: [.regularExpression, .caseInsensitive]),
           let t = q[m].range(of: #"[a-f0-9]{32}$"#, options: [.regularExpression, .caseInsensitive]) { return .ticketToken(String(q[m][t]).lowercased()) }
        return .text(q)
    }

    /// A POS invoice / reference worth creating a pager for when nothing matches: has letters or a separator plus digits, ≥ 3 characters, not a phone number or a member number.
    static func looksLikeInvoice(_ s: String) -> Bool {
        let q = s.trimmed
        guard q.count >= 3, q.count <= 60, q.contains(where: \.isNumber), !q.hasPrefix("#") else { return false }
        let digits = q.filter(\.isNumber)
        if digits.count == q.count { return q.count <= 8 && !(q.hasPrefix("05") || q.hasPrefix("966") || q.hasPrefix("5")) }   // plain digits: a short number, not a phone
        if q.hasPrefix("+") || (digits.count >= 9 && digits.count >= q.count - 2 && (q.hasPrefix("05") || q.hasPrefix("966"))) { return false }
        return true
    }
}

/// One thing a scan can open.
enum ScanHit: Equatable, Identifiable, Sendable {
    case member(MemberCard)
    case order(OrderCard)
    case ticket(PagerTicket)

    var id: String { switch self { case .member(let m): "m\(m.id)"; case .order(let o): "o\(o.id)"; case .ticket(let t): "t\(t.id)" } }
}
