import Foundation

/// One row of the business event bus (`Bus::recent`): the same shape for the owner feed (`businesses/{id}/events`) and the
/// cashier feed (`/cashier/{token}/api/biz/events` → `items`). Decode with `JSONDecoder.api` (snake_case).
struct RealtimeEvent: Codable, Sendable, Identifiable, Equatable {
    let id: Int
    let branchId: Int?
    /// Stable event key, e.g. `drive.order.new`, `drive.customer.arrived`, `branch.offline`.
    let event: String
    let source: String?
    let label: String?
    let actor: String?
    /// True while the event is an unseen notice.
    let notice: Bool
    let at: String?

    init(id: Int, branchId: Int? = nil, event: String, source: String? = nil, label: String? = nil, actor: String? = nil, notice: Bool = false, at: String? = nil) {
        self.id = id; self.branchId = branchId; self.event = event; self.source = source; self.label = label; self.actor = actor; self.notice = notice; self.at = at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        branchId = try c.decodeIfPresent(Int.self, forKey: .branchId)
        event = try c.decode(String.self, forKey: .event)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        actor = try c.decodeIfPresent(String.self, forKey: .actor)
        notice = (try? c.decodeIfPresent(Bool.self, forKey: .notice)) ?? false   // the server sends a bool; older rows an int
        at = try c.decodeIfPresent(String.self, forKey: .at)
    }
}

/// Realtime without sockets: the app asks "what is newer than `since`". A WebSocket client can replace the polling one later
/// without touching the screens.
protocol RealtimeClient: Sendable {
    /// Events with an id greater than `since` (any order; callers sort by id).
    func events(since: Int) async throws -> [RealtimeEvent]
}

/// Polls a fetch closure every `interval`, backs off exponentially while it fails, and polls at once when a silent push arrives.
actor PollingRealtimeClient: RealtimeClient {
    typealias Fetch = @Sendable (_ since: Int) async throws -> [RealtimeEvent]
    typealias Handler = @Sendable (_ eventsOldestFirst: [RealtimeEvent]) async -> Void

    private let fetch: Fetch
    private let interval: Duration
    private let maxBackoff: Duration
    private var loop: Task<Void, Never>?
    private var pause: Task<Void, Never>?
    private var wakePending = false
    private(set) var cursor = 0
    private(set) var consecutiveFailures = 0

    init(interval: Duration = .seconds(8), maxBackoff: Duration = .seconds(120), fetch: @escaping Fetch) {
        self.interval = interval; self.maxBackoff = maxBackoff; self.fetch = fetch
    }

    func events(since: Int) async throws -> [RealtimeEvent] { try await fetch(since) }

    var isRunning: Bool { loop != nil }

    /// Starts the loop after `since` (the biggest event id the app already holds). Calling it again restarts from the new cursor.
    func start(since: Int, onEvents: @escaping Handler) {
        stop()
        cursor = since
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let wait = await self.pollOnce(onEvents)
                await self.sleep(for: wait)
            }
        }
    }

    func stop() {
        loop?.cancel(); loop = nil
        pause?.cancel(); pause = nil
    }

    /// A silent push (`content-available`) says "something changed": cut the current wait short and poll now.
    func onSilentPush() { if let pause, !pause.isCancelled { pause.cancel() } else { wakePending = true } }

    /// One poll; returns how long to wait before the next one.
    private func pollOnce(_ onEvents: Handler) async -> Duration {
        do {
            let got = try await fetch(cursor)
            consecutiveFailures = 0
            let fresh = got.filter { $0.id > cursor }.sorted { $0.id < $1.id }
            if let top = fresh.last { cursor = top.id; await onEvents(fresh) }
        } catch is CancellationError {
            return interval
        } catch {
            consecutiveFailures += 1
        }
        return Self.delay(base: interval, failures: consecutiveFailures, cap: maxBackoff)
    }

    private func sleep(for d: Duration) async {
        if wakePending { wakePending = false; return }   // a push landed while we were polling
        let t = Task<Void, Never> { _ = try? await Task.sleep(for: d) }
        pause = t
        await t.value
        pause = nil
    }

    /// `base`, doubled for every consecutive failure, never above `cap`.
    static func delay(base: Duration, failures: Int, cap: Duration) -> Duration {
        guard failures > 0 else { return base }
        var d = base
        for _ in 0..<min(failures, 10) { d = d * 2; if d >= cap { return cap } }
        return d
    }
}
