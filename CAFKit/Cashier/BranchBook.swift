import Foundation

/// A branch this device knows. The link token is a secret → the whole book lives in the Keychain.
struct BranchRecord: Codable, Equatable, Sendable, Identifiable {
    var token: String
    var branchName: String?
    var businessName: String?
    var lastStaffId: Int?
    var lastStaffName: String?
    var id: String { token }
}

struct BranchBookData: Codable, Equatable, Sendable {
    var active: String?
    var branches: [BranchRecord] = []
}

/// Saved branches + which one is active. Several branches can be signed in on one device (quick switcher).
final class BranchBook: @unchecked Sendable {
    private let secrets: SecretStoring
    private let account = "cashier.book"
    private let lock = NSLock()
    private var data: BranchBookData

    init(secrets: SecretStoring = Keychain()) {
        self.secrets = secrets
        data = secrets.read(account).flatMap { try? JSONDecoder().decode(BranchBookData.self, from: $0) } ?? BranchBookData()
    }

    var snapshot: BranchBookData { lock.lock(); defer { lock.unlock() }; return data }
    var active: BranchRecord? { let s = snapshot; return s.branches.first { $0.token == s.active } }

    func upsert(_ r: BranchRecord, makeActive: Bool = true) {
        mutate {
            if let i = $0.branches.firstIndex(where: { $0.token == r.token }) { $0.branches[i] = r } else { $0.branches.append(r) }
            if makeActive { $0.active = r.token }
        }
    }
    func update(token: String, _ f: (inout BranchRecord) -> Void) {
        mutate { if let i = $0.branches.firstIndex(where: { $0.token == token }) { f(&$0.branches[i]) } }
    }
    func setActive(_ token: String?) { mutate { $0.active = token } }
    func remove(token: String) {
        mutate {
            $0.branches.removeAll { $0.token == token }
            if $0.active == token { $0.active = $0.branches.first?.token }
        }
        secrets.delete(CashierSession.account(for: token))
    }
    func removeAll() {
        for b in snapshot.branches { secrets.delete(CashierSession.account(for: b.token)) }
        mutate { $0 = BranchBookData() }
    }

    private func mutate(_ f: (inout BranchBookData) -> Void) {
        lock.lock(); f(&data); let d = data; lock.unlock()
        if let enc = try? JSONEncoder().encode(d) { secrets.write(enc, account: account) }
    }
}
