import Foundation
import Observation
import AudioToolbox

/// The live Drive-Thru board of one branch: polls `drive/state` (4 s visible, 15 s otherwise), keeps the lanes, runs order actions.
/// Alerts are derived on the device exactly as the web cashier does: new orders chime, an arrived customer sirens (only after «ابدأ الاستقبال»).
@Observable
@MainActor
final class DriveBoard {
    private let session: CashierSession
    private(set) var state: DriveState?
    private(set) var lanes = DriveLanes()
    private(set) var counts = DriveCounts()
    /// nil = not known yet; false = the store is off / not in the plan → hide every Drive entry (never an error).
    private(set) var available: Bool?
    private(set) var lastError: String?
    private(set) var isLoading = false
    var receptionStarted = false
    var onSessionLost: (() -> Void)?
    private var rev: Int?
    private var task: Task<Void, Never>?
    private var knownNew: Set<Int> = []
    private var knownArrived: Set<Int> = []
    private var primed = false

    init(session: CashierSession) { self.session = session }

    var perms: CashierPerms { state?.perms ?? CashierPerms() }
    var pay: DrivePayConfig { state?.pay ?? DrivePayConfig() }
    var branch: DriveBranchState { state?.branch ?? DriveBranchState() }
    var deliverEnabled: Bool { state?.deliverEnabled ?? false }
    var badge: Int { counts.new + counts.making + counts.ready }

    func start(visible: Bool = true) {
        stop()
        task = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                // `late`/`stale` flags and the release of booked orders do not bump `rev`: ask for the full board now and then.
                tick += 1
                if tick % 8 == 0 || (self?.releaseDue ?? false) { self?.invalidate() }
                await self?.refresh()
                try? await Task.sleep(for: .seconds(visible ? 4 : 15))
            }
        }
    }
    func stop() { task?.cancel(); task = nil }
    private var releaseDue: Bool { state?.nextReleaseAt.map { $0 <= .now } ?? false }

    func refresh() async {
        do {
            let s = try await session.driveState(rev: rev)
            lastError = nil
            guard s.drive else { available = false; state = s; return }
            available = true
            state = s
            if s.changed || rev == nil { rev = s.rev; if let l = s.lanes { lanes = l }; if let c = s.counts { counts = c }; alerts() }
        } catch let e as CashierError {
            if e.isAuth { onSessionLost?() }
            else if e.code == .notFound || e.code == .plan || e.code == .perm { if available == nil { available = false } }
            else if !e.isOffline { lastError = e.userMessage }
        } catch {}
    }

    /// Forces the next poll to return the full lanes (after an action).
    func invalidate() { rev = nil }

    private func alerts() {
        let newIds = Set(lanes.new.map(\.id)), arrivedIds = Set(lanes.arrived.map(\.id))
        defer { knownNew = newIds; knownArrived = arrivedIds; primed = true }
        guard primed, receptionStarted else { return }
        if !arrivedIds.subtracting(knownArrived).isEmpty { AudioServicesPlaySystemSound(1304); Haptics.warning(); return }
        if perms.has("drive.receive"), !newIds.subtracting(knownNew).isEmpty { AudioServicesPlaySystemSound(1315); Haptics.success() }
    }

    // MARK: actions

    func act(_ order: OrderCard, _ action: String, body: [String: Any] = [:]) async -> Result<OrderActionResult, CashierError> {
        do {
            let r = try await session.driveAct(id: order.id, action: action, body: body)
            invalidate(); await refresh()
            return .success(r)
        } catch let e as CashierError {
            if e.isAuth { onSessionLost?() }
            invalidate(); await refresh()
            return .failure(e)
        } catch { return .failure(.malformed(status: 0)) }
    }

    func pause(minutes: Int, manual: Bool = false) async -> CashierError? {
        do { try await session.drivePause(minutes: minutes, manual: manual); invalidate(); await refresh(); return nil } catch let e as CashierError { return e } catch { return nil }
    }
    func setPrep(minutes: Int) async -> CashierError? {
        do { try await session.drivePrep(minutes: minutes); invalidate(); await refresh(); return nil } catch let e as CashierError { return e } catch { return nil }
    }
}
