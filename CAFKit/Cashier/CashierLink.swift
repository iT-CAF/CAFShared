import Foundation

/// Parses what the cashier pastes / scans / opens into the 32-hex branch token.
/// Accepts `https://it-caf.com/cashier/<token>` with any suffix (`/app`, query), the bare token, and `<AppConfig.urlScheme>://cashier/<token>` (itcafbiz:// in the cashier app).
/// The token is a secret: this type never logs it and `masked` is the only form meant for the UI.
enum CashierLink {
    static let tokenPattern = #"^[a-f0-9]{32}$"#

    static func isToken(_ s: String) -> Bool { s.range(of: tokenPattern, options: .regularExpression) != nil }

    /// - Returns: the lowercase token, or nil when the text is not a cashier link.
    static func token(from raw: String, allowedHosts: Set<String> = AppConfig.linkHosts, allowLocal: Bool = AppConfig.isDebug) -> String? {
        // Strip every kind of whitespace/newline (pasted links often carry a trailing newline or zero-width marks).
        let cleaned = raw.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) && $0.value != 0x200B && $0.value != 0x200E && $0.value != 0x200F && $0.value != 0xFEFF }
            .map(Character.init).reduce(into: "") { $0.append($1) }
        guard !cleaned.isEmpty, cleaned.count < 600 else { return nil }
        let lower = cleaned.lowercased()
        if isToken(lower) { return lower }
        guard let url = URL(string: cleaned), let scheme = url.scheme?.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch scheme {
        case "https", "http":
            guard let host = url.host?.lowercased() else { return nil }
            let ok = allowedHosts.contains(host) || (allowLocal && (host == "127.0.0.1" || host == "localhost" || host.hasSuffix(".local")))
            guard ok, scheme == "https" || allowLocal, parts.count >= 2, parts[0].lowercased() == "cashier", isToken(parts[1].lowercased()) else { return nil }
            return parts[1].lowercased()
        default:
            // <scheme>://cashier/<token>: the scheme is the app's own (Info.plist CAFURLScheme).
            guard scheme == AppConfig.urlScheme else { return nil }
            let all = ([url.host] + parts).compactMap { $0 }
            guard all.count >= 2, all[0].lowercased() == "cashier", isToken(all[1].lowercased()) else { return nil }
            return all[1].lowercased()
        }
    }

    /// `…a745d3c6e95fc730` — never show the whole secret.
    static func masked(_ token: String) -> String { "…" + token.suffix(16) }
}
