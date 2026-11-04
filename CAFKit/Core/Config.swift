import Foundation

/// Build-time configuration, injected from `Config/*.xcconfig` through Info.plist.
enum AppConfig {
    private static func plist(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    /// The Info.plist value, or nil when the key is missing/empty (an unresolved `$(VAR)` counts as missing too).
    private static func plistValue(_ key: String) -> String? {
        let v = plist(key)
        return v.isEmpty || v.hasPrefix("$(") ? nil : v
    }

    /// `https://it-caf.com` (Release) or the local rig `http://127.0.0.1:8111` (Debug).
    static let serverBaseURL: URL = {
        #if DEBUG
        // `SIMCTL_CHILD_CAF_SERVER_BASE=http://127.0.0.1:8111 xcrun simctl launch …`
        if let o = ProcessInfo.processInfo.environment["CAF_SERVER_BASE"], let u = URL(string: o), u.scheme?.hasPrefix("http") == true { return u }
        #endif
        return URL(string: plist("ServerBaseURL")) ?? URL(string: "https://it-caf.com")!
    }()
    static let privacyURL = URL(string: "https://it-caf.com/privacy")!
    static let termsURL = URL(string: "https://it-caf.com/terms")!
    // Per-app values come from Info.plist so this folder stays app-agnostic (the fallbacks are the cashier app's: com.itcaf.biz).
    static let appGroup = plistValue("CAFAppGroup") ?? "group.com.itcaf.biz"
    /// The App Clip keeps its own keychain items (own service name) so the full app can tell them apart and migrate them
    /// (iOS 15.4+: the full app can READ items its App Clip created; the reverse is not possible).
    static let clipKeychainService = plistValue("CAFClipKeychainService") ?? "com.itcaf.biz.clip"
    #if APPCLIP
    static let keychainService = clipKeychainService
    #else
    static let keychainService = plistValue("CAFKeychainService") ?? "com.itcaf.biz"
    #endif
    /// Custom URL scheme of the app (`itcafbiz://…`, `cafbio://…`), without `://`.
    static let urlScheme = (plistValue("CAFURLScheme") ?? "itcafbiz").lowercased()
    /// Hosts whose universal links (`/cashier/<token>`, `/p/<token>`…) the app accepts.
    static let linkHosts: Set<String> = {
        let listed = (plistValue("CAFLinkHosts") ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        return listed.isEmpty ? ["it-caf.com", "www.it-caf.com"] : Set(listed)
    }()

    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }

    #if DEBUG
    static let isDebug = true
    #else
    static let isDebug = false
    #endif
}

extension JSONDecoder {
    /// snake_case JSON, ISO-8601 UTC dates (with or without fractional seconds).
    static let api: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let date = ISO8601.parse(s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "bad date \(s)"))
        }
        return d
    }()
}

enum ISO8601 {
    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }()
    nonisolated(unsafe) private static let frac: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
    private static let lock = NSLock()
    static func parse(_ s: String) -> Date? { lock.lock(); defer { lock.unlock() }; return plain.date(from: s) ?? frac.date(from: s) }
}

extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }
