import Foundation

/// Plugs the owner's API into `PushRegistrar`: `POST devices` after sign-in, `DELETE devices/{id}` on sign-out.
struct OwnerDeviceRegistration: DeviceRegistering {
    let session: OwnerSession

    @discardableResult
    func registerDevice(_ info: PushDeviceInfo) async throws -> Int {
        var body: [String: Any] = ["app": "owner"]
        for (k, v) in info.body { body[k] = v }
        struct Ack: Decodable { var deviceId: Int }
        return try await session.decode(Ack.self, try await session.post("devices", body)).deviceId
    }

    func unregisterDevice(id: Int) async throws {
        _ = try await session.perform("devices/\(id)", method: "DELETE", body: nil, auth: true)
    }
}
