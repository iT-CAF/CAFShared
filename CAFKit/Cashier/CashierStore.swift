import Foundation
import Observation
import SwiftData

struct MemberContext: Equatable {
    var card: MemberCard
    /// Present when the scan was a one-time reward code (`LOYR:…`): the reward is decided by the code.
    var code: RedeemCodeInfo?
    var rawCode: String?
}

struct OperationResult: Equatable, Identifiable {
    enum Kind { case earned, redeemed, undone, queued, failure }
    let id = UUID()
    var kind: Kind
    var title: String
    var detail: String
    var memberName: String = ""
    var balance: Int?
    var txId: Int?
    var undoUntil: Date?
    var rewardUnlocked = false
    var isSuccess: Bool { kind != .failure }
    static func == (l: OperationResult, r: OperationResult) -> Bool { l.id == r.id }
}

enum ScanFlow: Equatable {
    case idle
    case searching
    case matches([MemberMatch])
    case member(MemberContext)
    /// Smart scan (full app): an order, a pager ticket, an invoice nobody has a pager for yet, or several candidates to choose from.
    case order(OrderCard)
    case ticket(PagerTicket)
    case invoice(String)
    case choices([ScanHit])
    case result(OperationResult)
}

/// Everything the cashier face needs for ONE branch: session, permissions, recent operations, heartbeat, offline queue and the scan flow.
@Observable
@MainActor
final class CashierStore {
    enum Phase: Equatable { case loading, linkInvalid, unreachable, pickStaff, pin(StaffEntry), ready }

    let token: String
    let branchKey: String
    let session: CashierSession
    private let book: BranchBook
    private let queue: OfflineQueue?

    private(set) var phase: Phase = .loading
    private(set) var staff: [StaffEntry] = []
    private(set) var program = CashierProgramInfo()
    private(set) var branch: BranchInfo?
    private(set) var me: SessionInfo?
    private(set) var recent: [LedgerTx] = []
    func updateRecent(_ r: [LedgerTx]) { recent = r }
    private(set) var heartbeat: Heartbeat?
    private(set) var bizAvailable = true
    private(set) var pendingCount = 0
    private(set) var reviewCount = 0
    private(set) var lastSyncNote: String?
    /// Set when the server refused an earn with `cooldown` (a stamp was just given): the cashier may confirm "add anyway".
    private(set) var forceCandidate: (member: MemberCard, amount: Double?, qty: Int?)?
    var pinState = PinLockState()
    var pinError: String?
    var pinBusy = false
    /// Two tabs can show the outcome screen (Scan and Recent); exactly one of them presents it, or SwiftUI dismisses the loser and its binding wipes the flow.
    var recentTabActive = false
    var flow: ScanFlow = .idle
    var isOnline = true

    /// Drive-Thru board (orders lanes, actions). Nothing starts until the cashier opens a Drive screen or the dashboard asks.
    let drive: DriveBoard
    private var heartbeatTask: Task<Void, Never>?
    /// Shell hooks (push registration, realtime): the store knows nothing about them.
    @ObservationIgnored var onSignedIn: (@MainActor () -> Void)?
    @ObservationIgnored var beforeSignOut: (@MainActor () async -> Void)?
    private var attempt: (signature: String, idem: String)?

    init(token: String, session: CashierSession? = nil, book: BranchBook, queue: OfflineQueue?) {
        self.token = token
        self.branchKey = CashierSession.account(for: token)
        let sess = session ?? CashierSession(token: token)
        self.session = sess
        self.drive = DriveBoard(session: sess)
        self.book = book
        self.queue = queue
        self.drive.onSessionLost = { [weak self] in self?.sessionLost() }
    }

    var perms: CashierPerms { me?.staff.perms ?? CashierPerms() }
    var staffName: String { me?.staff.name ?? "" }
    var branchName: String { branch?.name ?? book.snapshot.branches.first { $0.token == token }?.branchName ?? "" }
    var businessName: String { program.name }
    var isReady: Bool { phase == .ready }

    // MARK: start / session

    func bootstrap() async {
        await session.setLanguage(L10n.language.rawValue)
        phase = .loading
        do {
            let list = try await session.staff()
            apply(list)
        } catch let e as CashierError {
            phase = e.code == .notFound ? .linkInvalid : .unreachable
            if e.code == .notFound { book.remove(token: token) }
            return
        } catch { phase = .unreachable; return }
        if await session.hasStoredSession, let info = (try? await session.me()) ?? nil {
            activate(info)
        } else if let last = book.snapshot.branches.first(where: { $0.token == token })?.lastStaffId, let s = staff.first(where: { $0.id == last }) {
            phase = .pin(s)
        } else {
            phase = .pickStaff
        }
    }

    private func apply(_ list: StaffListResponse) {
        staff = list.staff; program = list.program; branch = list.branch
        var rec = book.snapshot.branches.first { $0.token == token } ?? BranchRecord(token: token)
        rec.branchName = list.branch.name; rec.businessName = list.program.name
        book.upsert(rec, makeActive: false)
    }

    func choose(_ s: StaffEntry) { pinError = nil; pinState.reset(); phase = .pin(s) }
    func backToStaff() { pinError = nil; pinState.reset(); phase = .pickStaff }

    @discardableResult
    func login(staff s: StaffEntry, pin: String) async -> Bool {
        guard PinRules.isValid(pin), !pinState.isLocked() else { return false }
        pinBusy = true; defer { pinBusy = false }
        do {
            let info = try await session.login(staffId: s.id, pin: pin)
            pinState.reset(); pinError = nil
            activate(info)
            return true
        } catch let e as CashierError {
            pinState.apply(e)
            pinError = e.userMessage
            return false
        } catch { return false }
    }

    private func activate(_ info: SessionInfo) {
        me = info; program = info.program; branch = info.branch; recent = info.recent; phase = .ready
        var rec = book.snapshot.branches.first { $0.token == token } ?? BranchRecord(token: token)
        rec.branchName = info.branch.name; rec.businessName = info.program.name; rec.lastStaffId = info.staff.id; rec.lastStaffName = info.staff.name
        book.upsert(rec, makeActive: true)
        refreshQueueCounts()
        Task { await flushQueue() }
        onSignedIn?()
    }

    func logout() async {
        stopHeartbeat()
        await beforeSignOut?()      // the push device is revoked while the session can still authorise it
        await session.logout()
        me = nil; heartbeat = nil; flow = .idle; recent = []
        phase = .pickStaff
    }

    /// Session lost (cookie expired / revoked): back to the PIN pad of the same person, branch kept.
    func sessionLost() {
        stopHeartbeat()
        let s = me.map { StaffEntry(id: $0.staff.id, name: $0.staff.name, role: $0.staff.role) }
        me = nil; flow = .idle
        pinError = L10n.string("err.auth")
        if let s { phase = .pin(s) } else { phase = .pickStaff }
    }

    // MARK: scan flow

    func resetFlow() { flow = .idle; attempt = nil; forceCandidate = nil }

    /// The scanner's single entry: the full app routes a reading to the right page (member, reward code, order, pager ticket, invoice); the App Clip only knows members.
    func scan(_ raw: String) async {
        #if APPCLIP
        await lookup(raw)
        #else
        await smartScan(raw)
        #endif
    }

    func lookup(_ raw: String) async {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        flow = .searching
        do {
            switch try await session.lookup(q: q) {
            case .member(let c): flow = .member(MemberContext(card: c))
            case .code(let info, let c): flow = .member(MemberContext(card: c, code: info, rawCode: q))
            case .matches(let m): flow = .matches(m)
            }
            Haptics.light()
        } catch { fail(error) }
    }

    func pick(_ match: MemberMatch) async {
        flow = .searching
        do {
            if case .member(let c) = try await session.lookup(memberId: match.id) { flow = .member(MemberContext(card: c)) } else { flow = .idle }
        } catch { fail(error) }
    }

    func quote(member: MemberCard, amount: Double?) async -> Quote? { try? await session.quote(memberId: member.id, amount: amount) }

    func earn(member: MemberCard, amount: Double?, qty: Int?, force: Bool = false) async {
        let sig = "earn|\(member.id)|\(amount ?? 0)|\(qty ?? 0)"
        let idem = idemFor(sig)
        do {
            let r = try await session.earn(memberId: member.id, amount: amount, qty: qty, idem: idem, force: force)
            attempt = nil; forceCandidate = nil
            let tx = decorate(r.tx, member: r.member)
            remember(tx)
            Haptics.success()
            let unit = unitLabel(for: r.member)
            flow = .result(OperationResult(kind: .earned, title: r.duplicate ? L10n.string("op.already_done") : L10n.string("op.earned_title", r.added, unit),
                                           detail: r.rewardUnlocked ? L10n.string("op.reward_unlocked") : L10n.string("op.balance_now", r.member.balance, unit),
                                           memberName: r.member.name, balance: r.member.balance, txId: r.tx.id, undoUntil: r.undoUntil, rewardUnlocked: r.rewardUnlocked))
        } catch let e as CashierError where e.isOffline {
            enqueue(OfflineOp(idem: idem, branchKey: branchKey, type: "earn", staffId: me?.staff.id ?? 0, memberId: member.id, memberName: member.name, amount: amount, qty: qty))
            queuedResult(member.name)
        } catch {
            attempt = nil
            if let e = error as? CashierError, e.code == .cooldown { forceCandidate = (member, amount, qty) }
            fail(error)
        }
    }

    func redeem(member: MemberCard, option: RedeemOption?, code: String?) async {
        let sig = "redeem|\(member.id)|\(option?.key ?? "-")|\(code ?? "-")"
        let idem = idemFor(sig)
        do {
            let r = try await session.redeem(memberId: member.id, rewardId: option?.id, tier: option?.tier ?? 0, code: code, idem: idem)
            attempt = nil
            remember(decorate(r.tx, member: r.member))
            Haptics.success()
            flow = .result(OperationResult(kind: .redeemed, title: L10n.string("op.redeemed_title"), detail: r.reward + (r.cost.map { " · " + L10n.string("op.cost_n", $0) } ?? ""),
                                           memberName: r.member.name, balance: r.member.balance, txId: r.tx.id, undoUntil: r.tx.undoUntil))
        } catch let e as CashierError where e.isOffline {
            enqueue(OfflineOp(idem: idem, branchKey: branchKey, type: "redeem", staffId: me?.staff.id ?? 0, memberId: member.id, memberName: member.name, rewardId: option?.id, tier: option?.tier ?? 0, code: code))
            queuedResult(member.name)
        } catch { attempt = nil; fail(error) }
    }

    func undo(_ tx: LedgerTx) async {
        do {
            let r = try await session.undo(txId: tx.id)
            if let i = recent.firstIndex(where: { $0.id == tx.id }) { recent[i].reversedBy = r.tx.id }
            Haptics.success()
            flow = .result(OperationResult(kind: .undone, title: L10n.string("op.undone_title"), detail: L10n.string("op.balance_now", r.member.balance, unitLabel(for: r.member)), memberName: r.member.name, balance: r.member.balance))
        } catch { fail(error) }
    }

    private func idemFor(_ signature: String) -> String {
        if let a = attempt, a.signature == signature { return a.idem }
        let id = UUID().uuidString
        attempt = (signature, id)
        return id
    }

    private func decorate(_ tx: LedgerTx, member: MemberCard) -> LedgerTx {
        var t = tx
        t.memberName = member.name; t.memberId = member.id; t.memberNo = Int(member.no.filter(\.isNumber))
        return t
    }
    private func remember(_ tx: LedgerTx) { recent.removeAll { $0.id == tx.id }; recent.insert(tx, at: 0); recent = Array(recent.prefix(30)) }
    func unitLabel(for m: MemberCard) -> String { m.isPoints ? (program.pointsLabel.isEmpty ? L10n.string("unit.points") : program.pointsLabel) : L10n.string("unit.stamps") }

    func fail(_ error: Error) {
        guard let e = error as? CashierError else { flow = .idle; return }
        if e.isAuth { sessionLost(); return }
        Haptics.error()
        flow = .result(OperationResult(kind: .failure, title: e.isOffline ? L10n.string("err.offline_title") : L10n.string("op.failed_title"), detail: e.userMessage))
    }

    // MARK: offline queue

    private func enqueue(_ op: OfflineOp) { queue?.enqueue(op); refreshQueueCounts() }
    private func queuedResult(_ name: String) {
        Haptics.warning()
        flow = .result(OperationResult(kind: .queued, title: L10n.string("op.queued_title"), detail: L10n.string("op.queued_detail"), memberName: name))
    }
    func refreshQueueCounts() {
        pendingCount = queue?.pendingCount(branchKey: branchKey) ?? 0
        reviewCount = queue?.reviewItems(branchKey: branchKey).count ?? 0
    }
    var queuedOps: [OfflineOp] { queue?.all(branchKey: branchKey) ?? [] }
    func discard(_ op: OfflineOp) { queue?.discard(op); refreshQueueCounts() }

    func flushQueue() async {
        guard let queue, let sid = me?.staff.id, pendingCount > 0 || reviewCount >= 0 else { return }
        guard queue.pendingCount(branchKey: branchKey) > 0 else { refreshQueueCounts(); return }
        let s = await queue.flush(branchKey: branchKey, staffId: sid, session: session)
        refreshQueueCounts()
        if !s.recent.isEmpty { recent = s.recent }
        if s.didSendAnything { lastSyncNote = L10n.string("queue.synced_n", s.sent + s.duplicates); Haptics.success() }
        if s.review > 0 { lastSyncNote = L10n.string("queue.review_n", s.review) }
    }

    // MARK: heartbeat (20–30 s while the app is in the foreground)

    func startHeartbeat(interval: Duration = .seconds(25)) {
        guard heartbeatTask == nil, isReady else { return }
        drive.start()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.beat()
                try? await Task.sleep(for: interval)
            }
        }
    }
    func stopHeartbeat() { heartbeatTask?.cancel(); heartbeatTask = nil; drive.stop() }

    func beat() async {
        guard bizAvailable else { return }
        do {
            let hb = try await session.heartbeat()
            heartbeat = hb
            let recovered = !isOnline
            isOnline = true
            if recovered || pendingCount > 0 { Task { await flushQueue() } }
            if var m = me, hb.perms.raw != m.staff.perms.raw, !hb.perms.raw.isEmpty { m.staff.perms = hb.perms; me = m }
        } catch let e as CashierError {
            if e.isOffline { isOnline = false }
            else if e.isAuth { sessionLost() }
            else if e.code == .notFound || e.code == .plan || e.code == .disabled { bizAvailable = false; heartbeat = nil }   // module off → hide, not an error
        } catch {}
    }
}

extension CashierStore {
    /// Pull-to-refresh of "my recent operations" (`GET api/me` returns them).
    @discardableResult
    func refreshRecent() async -> Bool {
        do { if let info = try await session.me() { updateRecent(info.recent); return true } else { sessionLost(); return false } } catch { return false }
    }
}

