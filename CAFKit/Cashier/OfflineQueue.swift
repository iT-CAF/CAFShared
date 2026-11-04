import Foundation
import SwiftData

/// An earn/redeem taken while the network was down. Replayed in order via `POST api/sync` with the SAME idem (the server dedupes).
@Model
final class OfflineOp {
    @Attribute(.unique) var idem: String
    var branchKey: String
    var type: String            // earn | redeem
    var staffId: Int
    var memberId: Int
    var memberName: String
    var amount: Double?
    var qty: Int?
    var rewardId: Int?
    var tier: Int
    var code: String?
    var ts: Date
    /// pending | review (the server refused for good) | waiting (queued by someone else)
    var state: String
    var failCode: String?
    var failMessage: String?

    init(idem: String, branchKey: String, type: String, staffId: Int, memberId: Int, memberName: String, amount: Double? = nil, qty: Int? = nil,
         rewardId: Int? = nil, tier: Int = 0, code: String? = nil, ts: Date = .now) {
        self.idem = idem; self.branchKey = branchKey; self.type = type; self.staffId = staffId; self.memberId = memberId; self.memberName = memberName
        self.amount = amount; self.qty = qty; self.rewardId = rewardId; self.tier = tier; self.code = code; self.ts = ts; self.state = "pending"
    }

    /// Body of one entry of `sync.ops`.
    var syncBody: [String: Any] {
        var b: [String: Any] = ["idem": idem, "type": type, "staff": staffId, "member": memberId, "tier": tier, "ts": Int(ts.timeIntervalSince1970)]
        if let amount { b["amount"] = amount }
        if let qty { b["qty"] = qty }
        if let rewardId { b["reward_id"] = rewardId }
        if let code, !code.isEmpty { b["code"] = code }
        return b
    }
}

struct FlushSummary: Equatable, Sendable {
    var sent = 0, duplicates = 0, review = 0, waiting = 0, kept = 0
    var recent: [LedgerTx] = []
    var didSendAnything: Bool { sent + duplicates > 0 }
}

/// Pure decision of what happens to an op given the server's per-op answer (unit-tested).
enum OfflineDecision: Equatable {
    case done(duplicate: Bool)
    case review(code: String?, message: String?)
    case waiting
    case keep
    static func decide(_ r: SyncItemResult) -> OfflineDecision {
        if r.ok { return .done(duplicate: r.duplicate) }
        if r.code == "other_staff" { return .waiting }
        return r.permanent ? .review(code: r.code, message: r.message) : .keep
    }
}

@MainActor
final class OfflineQueue {
    static let batchSize = 25
    /// The queue keeps its container alive (a ModelContext without its container crashes).
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init(container: ModelContainer) { self.container = container }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        // The queue holds only member ids + amounts, never PINs or link tokens (branch is a hash).
        if !inMemory {
            // A fresh install may not have Application Support yet (SwiftData would fail to open its store).
            if let dir = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) { _ = dir }
            if let c = try? ModelContainer(for: OfflineOp.self, configurations: ModelConfiguration(isStoredInMemoryOnly: false)) { return c }
        }
        // Last resort (never crash at launch): memory only — the queue then lasts for this run.
        return try! ModelContainer(for: OfflineOp.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func enqueue(_ op: OfflineOp) {
        if let existing = all(branchKey: op.branchKey).first(where: { $0.idem == op.idem }) { _ = existing; return }
        context.insert(op); try? context.save()
    }

    func all(branchKey: String) -> [OfflineOp] {
        let d = FetchDescriptor<OfflineOp>(predicate: #Predicate { $0.branchKey == branchKey }, sortBy: [SortDescriptor(\.ts)])
        return (try? context.fetch(d)) ?? []
    }
    func pendingCount(branchKey: String) -> Int { all(branchKey: branchKey).filter { $0.state == "pending" || $0.state == "waiting" }.count }
    func reviewItems(branchKey: String) -> [OfflineOp] { all(branchKey: branchKey).filter { $0.state == "review" } }

    func discard(_ op: OfflineOp) { context.delete(op); try? context.save() }
    func wipe(branchKey: String) { for o in all(branchKey: branchKey) { context.delete(o) }; try? context.save() }

    /// Sends this person's pending ops, oldest first, in batches of 25.
    func flush(branchKey: String, staffId: Int, session: CashierSession) async -> FlushSummary {
        var summary = FlushSummary()
        let mine = all(branchKey: branchKey).filter { $0.staffId == staffId && ($0.state == "pending" || $0.state == "waiting") }
        summary.waiting = all(branchKey: branchKey).filter { $0.staffId != staffId && $0.state != "review" }.count
        var index = 0
        while index < mine.count {
            let batch = Array(mine[index..<min(index + Self.batchSize, mine.count)])
            index += Self.batchSize
            guard let resp = try? await session.sync(ops: batch.map(\.syncBody)) else { summary.kept += mine.count - (index - Self.batchSize); break }
            let byIdem = Dictionary(resp.results.map { ($0.idem, $0) }, uniquingKeysWith: { a, _ in a })
            for op in batch {
                guard let r = byIdem[op.idem] else { summary.kept += 1; continue }
                switch OfflineDecision.decide(r) {
                case .done(let dup): if dup { summary.duplicates += 1 } else { summary.sent += 1 }; context.delete(op)
                case .review(let c, let m): op.state = "review"; op.failCode = c; op.failMessage = m; summary.review += 1
                case .waiting: op.state = "waiting"; summary.waiting += 1
                case .keep: summary.kept += 1
                }
            }
            summary.recent = resp.recent
        }
        try? context.save()
        return summary
    }
}
