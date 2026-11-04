import Foundation
import Security

/// Thin generic-password Keychain wrapper (service-scoped). Everything secret lives here and nowhere else:
/// cashier link tokens, session cookies/CSRF, the optional Face-ID-protected PIN.
struct Keychain: Sendable {
    var service = AppConfig.keychainService
    /// Shared access group (App Group) so the full app and the App Clip can hand a branch over. nil = app-private.
    var accessGroup: String? = nil

    func read(_ account: String) -> Data? {
        var q = base(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    @discardableResult
    func write(_ data: Data, account: String) -> Bool {
        let q = base(account)
        let attrs: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let st = SecItemUpdate(q as CFDictionary, attrs as CFDictionary)
        if st == errSecItemNotFound {
            var add = q; add.merge(attrs) { $1 }
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return st == errSecSuccess
    }

    func delete(_ account: String) { SecItemDelete(base(account) as CFDictionary) }

    func accounts(prefix: String) -> [String] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitAll]
        if let g = accessGroup { q[kSecAttrAccessGroup as String] = g }
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let rows = out as? [[String: Any]] else { return [] }
        return rows.compactMap { $0[kSecAttrAccount as String] as? String }.filter { $0.hasPrefix(prefix) }
    }

    func deleteAll() {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        if let g = accessGroup { q[kSecAttrAccessGroup as String] = g }
        SecItemDelete(q as CFDictionary)
    }

    private func base(_ account: String) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        if let g = accessGroup { q[kSecAttrAccessGroup as String] = g }
        return q
    }
}

/// Key/value secret storage; the Keychain in the app, a dictionary in tests.
protocol SecretStoring: Sendable {
    func read(_ account: String) -> Data?
    @discardableResult func write(_ data: Data, account: String) -> Bool
    func delete(_ account: String)
    func accounts(prefix: String) -> [String]
}

extension Keychain: SecretStoring {}

final class MemorySecretStore: SecretStoring, @unchecked Sendable {
    private let lock = NSLock(); private var items: [String: Data] = [:]
    init() {}
    func read(_ a: String) -> Data? { lock.lock(); defer { lock.unlock() }; return items[a] }
    @discardableResult func write(_ d: Data, account: String) -> Bool { lock.lock(); items[account] = d; lock.unlock(); return true }
    func delete(_ a: String) { lock.lock(); items[a] = nil; lock.unlock() }
    func accounts(prefix: String) -> [String] { lock.lock(); defer { lock.unlock() }; return items.keys.filter { $0.hasPrefix(prefix) } }
}
