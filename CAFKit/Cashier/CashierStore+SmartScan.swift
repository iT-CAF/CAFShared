#if !APPCLIP
import Foundation

/// Routes a scanned/typed reading to its page. Explicit shapes go straight to their page; plain text asks, in a fixed order and only where the person has the permission:
/// loyalty members → Drive orders (open) → pager tickets (by invoice / number / token). One hit opens; several are offered as a list; none that looks like an invoice offers a new pager.
extension CashierStore {
    private var allPerms: CashierPerms { CashierPerms(perms.raw.merging(drive.perms.raw) { $0 || $1 }) }
    private var canLoyalty: Bool { program.loyalty && allPerms.canScan }
    private var canOrders: Bool { drive.available == true && (allPerms.has("drive.view") || allPerms.has("drive.deliver")) }
    private var canPager: Bool { bizAvailable && (allPerms.canPager || allPerms.has("pager.deliver")) }

    func smartScan(_ raw: String) async {
        let intent = ScanIntent.classify(raw)
        flow = .searching
        switch intent {
        case .redeemCode(let q):
            guard canLoyalty else { return deny() }
            await lookup(q)
        case .orderToken(let tok):
            guard canOrders else { return deny() }
            do { flow = .order(try await session.driveResolve(text: tok).order); Haptics.light() } catch { fail(error) }
        case .ticketToken(let tok):
            guard canPager else { return deny() }
            do {
                let t = try await session.pagerState().tickets.first { $0.token == tok && $0.source != "drive" }
                if let t { flow = .ticket(t); Haptics.light() } else { notFound() }
            } catch { fail(error) }
        case .text(let q):
            await resolveText(q)
        }
    }

    private func resolveText(_ q: String) async {
        guard !q.isEmpty else { flow = .idle; return }
        var hits: [ScanHit] = []
        var matches: [MemberMatch] = []
        var lastError: Error?
        if canLoyalty {
            do {
                switch try await session.lookup(q: q) {
                case .member(let c): hits.append(.member(c))
                case .code(let info, let c): flow = .member(MemberContext(card: c, code: info, rawCode: q)); Haptics.light(); return
                case .matches(let m): matches = m
                }
            } catch let e as CashierError { if e.isOffline || e.isAuth { return fail(e) }; if !isMiss(e) { lastError = e } } catch {}
        }
        if canOrders {
            do { hits += try await session.driveHistory(query: q, status: "open").rows.prefix(6).map(ScanHit.order) }
            catch let e as CashierError { if e.isOffline || e.isAuth { return fail(e) }; if !isMiss(e) { lastError = e } } catch {}
        }
        if canPager {
            do {
                let key = q.lowercased()
                hits += try await session.pagerState().tickets.filter { $0.source != "drive" && ($0.invoice.lowercased() == key || $0.number.lowercased() == key || $0.token == key) }.map(ScanHit.ticket)
            } catch let e as CashierError { if e.isOffline || e.isAuth { return fail(e) }; if !isMiss(e) { lastError = e } } catch {}
        }
        switch hits.count {
        case 1: open(hits[0])
        case 2...: flow = .choices(hits); Haptics.light()
        default:
            if !matches.isEmpty { flow = .matches(matches); Haptics.light() }
            else if canPager && allPerms.has("pager.use") && ScanIntent.looksLikeInvoice(q) { flow = .invoice(q); Haptics.light() }
            else if let lastError { fail(lastError) }
            else { notFound() }
        }
    }

    /// Opens one hit on its own page.
    func open(_ hit: ScanHit) {
        switch hit {
        case .member(let c): flow = .member(MemberContext(card: c))
        case .order(let o): flow = .order(o)
        case .ticket(let t): flow = .ticket(t)
        }
        Haptics.light()
    }

    private func isMiss(_ e: CashierError) -> Bool { [.notFound, .invalidCode, .codeInvalid, .perm, .disabled, .plan].contains(e.code ?? .server) || { if case .other(let c)? = e.code { return c == "other_branch" }; return false }() }
    private func notFound() { Haptics.error(); flow = .result(OperationResult(kind: .failure, title: L10n.string("scan.nothing_title"), detail: L10n.string("scan.nothing_detail"))) }
    private func deny() { Haptics.error(); flow = .result(OperationResult(kind: .failure, title: L10n.string("op.failed_title"), detail: L10n.string("err.perm"))) }
}
#endif
