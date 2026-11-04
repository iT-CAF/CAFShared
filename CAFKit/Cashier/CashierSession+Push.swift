import Foundation

/// `GET /cashier/{t}/api/biz/events?since=` — the branch's newest bus events past the id the app holds. The same answer also carries the
/// top-bar counts (the heartbeat's shape); the app only needs the rows and the cursor.
struct CashierEventsPage: Decodable, Equatable, Sendable {
    var items: [RealtimeEvent]
    var cursor: Int
    var serverTime: String?

    private enum K: String, CodingKey { case items, cursor, serverTime }
    init(items: [RealtimeEvent], cursor: Int, serverTime: String? = nil) { self.items = items; self.cursor = cursor; self.serverTime = serverTime }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        items = (try? c.decodeIfPresent([RealtimeEvent].self, forKey: .items)) ?? []
        cursor = (try? c.decodeIfPresent(Int.self, forKey: .cursor)) ?? 0
        serverTime = try? c.decodeIfPresent(String.self, forKey: .serverTime)
    }
}

/// Push devices and the realtime poll of the cashier app (`cafbio-mobile` routes-cashier.php). Session = branch link + PIN cookie, like every other call.
extension CashierSession {
    func pushEvents(since: Int) async throws -> CashierEventsPage { try await get("biz/events" + cashierQuery([("since", String(max(0, since)))])) }

    /// Files this phone's APNs token under the signed-in person and branch; returns the server's device id.
    func registerPushDevice(_ fields: [String: String]) async throws -> Int {
        struct Reply: Decodable { var deviceId: Int }
        let body = fields.reduce(into: [String: Any]()) { $0[$1.key] = $1.value }
        return (try await post("biz/device", body) as Reply).deviceId
    }

    /// Sign-out or branch change: the server stops pushing to this phone for this branch.
    func revokePushDevice(id: Int) async throws { let _: Ack = try await post("biz/device/revoke", ["device_id": id]) }
}
