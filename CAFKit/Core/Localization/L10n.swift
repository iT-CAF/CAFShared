import Foundation
import SwiftUI
import UIKit

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case ar, en
    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var layoutDirection: LayoutDirection { self == .ar ? .rightToLeft : .leftToRight }
    var nativeName: String { self == .ar ? "العربية" : "English" }
    /// Latin digits + Gregorian calendar in both languages (policy: prices/IDs/dates stay Latin).
    /// NOTE: plain `ar@numbers=latn` / `en_US` identifiers. BCP-47 extension forms (`en-u-nu-latn-ca-gregory`) trap inside
    /// ICU on iOS 17.5 when used with `String(format:locale:)` / `Date.FormatStyle`.
    var formattingLocale: Locale { Locale(identifier: self == .ar ? "ar@numbers=latn" : "en_US") }
}

/// Runtime string lookup for non-`Text` call sites. SwiftUI `Text("key")` is resolved through the
/// environment locale (see `LanguageManager`), this resolves the same catalog for plain `String`s.
enum L10n {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _language: AppLanguage = .ar
    nonisolated(unsafe) private static var bundles: [AppLanguage: Bundle] = [:]

    static var language: AppLanguage {
        get { lock.lock(); defer { lock.unlock() }; return _language }
        set { lock.lock(); _language = newValue; lock.unlock() }
    }

    private static func bundle(_ lang: AppLanguage) -> Bundle {
        lock.lock(); defer { lock.unlock() }
        if let b = bundles[lang] { return b }
        let b = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        bundles[lang] = b
        return b
    }

    static func string(_ key: String, in lang: AppLanguage? = nil) -> String {
        bundle(lang ?? language).localizedString(forKey: key, value: key, table: nil)
    }

    /// Localized format string with arguments. Safe in every language/OS:
    ///  • Swift `String` arguments are bridged to `NSString` (a bare `String` is not a valid `%@` vararg and crashes),
    ///  • no `locale:` is passed to `String(format:)`, so digits stay Latin (numbers are formatted by `Fmt`).
    static func string(_ key: String, _ args: Any..., in lang: AppLanguage? = nil) -> String {
        format(string(key, in: lang ?? language), args)
    }

    static func format(_ template: String, _ args: [Any]) -> String {
        let mapped: [CVarArg] = args.map { a in
            switch a {
            case let s as String: return s as NSString
            case let i as Int: return i
            case let i as Int64: return i
            case let u as UInt: return u
            case let d as Double: return d
            case let b as Bool: return b ? 1 : 0
            case let n as NSNumber: return n
            default: return String(describing: a) as NSString
            }
        }
        return String(format: template, arguments: mapped)
    }
}

/// Source of truth for the in-app language. Persists to UserDefaults; default is Arabic.
@Observable
@MainActor
final class LanguageManager {
    static let shared = LanguageManager()
    private static let key = "app.language"
    var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.key)
            L10n.language = language
            Self.applyUIKitDirection(language)
            BrandAppearance.install(language: language)
        }
    }

    /// UIKit-backed SwiftUI containers (List cells, nav bars, swipe-back) read the *trait* direction, not the SwiftUI
    /// environment — so we also set the UIKit semantic direction, and `AppleLanguages` so the next cold launch is native.
    static func applyUIKitDirection(_ language: AppLanguage) {
        UIView.appearance().semanticContentAttribute = language == .ar ? .forceRightToLeft : .forceLeftToRight
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
    }
    init() {
        var stored = UserDefaults.standard.string(forKey: Self.key).flatMap(AppLanguage.init(rawValue:)) ?? .ar
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments   // `-appLanguage en|ar` for UI tests / screenshots
        if let i = a.firstIndex(of: "-appLanguage"), a.indices.contains(i + 1), let l = AppLanguage(rawValue: a[i + 1]) { stored = l }
        #endif
        language = stored
        L10n.language = stored
        Self.applyUIKitDirection(stored)
    }
    var locale: Locale { language.locale }
    var layoutDirection: LayoutDirection { language.layoutDirection }
}

/// Number/date/price formatting with the Latin-digits policy.
enum Fmt {
    /// Amount with Latin digits and no currency (`1,234.50`).
    static func amount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US"); f.numberStyle = .decimal
        f.minimumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }
    static func symbol(_ currency: String, lang: AppLanguage = L10n.language) -> String {
        currency.uppercased() == "SAR" ? (lang == .ar ? "ر.س" : "SAR") : currency
    }

    static func isRiyal(_ currency: String) -> Bool { currency.uppercased() == "SAR" }

    /// VoiceOver wording: "50 ريال سعودي" / "50 Saudi riyals" (the visual mark is a vector, never read).
    static func spokenPrice(_ value: Double, currency: String = "SAR", lang: AppLanguage = L10n.language) -> String {
        guard isRiyal(currency) else { return price(value, currency: currency, lang: lang) }
        return "\(amount(value)) " + (lang == .ar ? "ريال سعودي" : "Saudi riyals")
    }

    static func price(_ value: Double, currency: String = "SAR", lang: AppLanguage = L10n.language) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")   // Latin digits, "." decimal
        f.numberStyle = .decimal
        f.minimumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        f.maximumFractionDigits = 2
        let n = f.string(from: NSNumber(value: value)) ?? String(value)
        let symbol = currency.uppercased() == "SAR" ? (lang == .ar ? "ر.س" : "SAR") : currency
        return lang == .ar ? "\(n) \(symbol)" : "\(symbol) \(n)"
    }

    static func number(_ value: Int) -> String {
        let f = NumberFormatter(); f.locale = Locale(identifier: "en_US"); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func relative(_ date: Date, lang: AppLanguage = L10n.language) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = lang.formattingLocale
        f.unitsStyle = .short
        return f.localizedString(for: min(date, .now), relativeTo: .now)
    }

    /// `8 Oct 2026` / `٨ أكتوبر` with Latin digits, Gregorian. DateFormatter (cached) — `Date.FormatStyle` with custom locales traps on iOS 17.5.
    static func date(_ date: Date, lang: AppLanguage = L10n.language) -> String { formatter("d MMM y", lang).string(from: date) }
    static func time(_ date: Date, lang: AppLanguage = L10n.language) -> String { formatter("jm", lang).string(from: date) }
    static func dayLabel(_ date: Date, lang: AppLanguage = L10n.language) -> String { formatter("EEE d MMM", lang).string(from: date) }
    static func dateTime(_ date: Date, lang: AppLanguage = L10n.language) -> String { formatter("d MMM y jm", lang).string(from: date) }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: DateFormatter] = [:]
    private static func formatter(_ template: String, _ lang: AppLanguage) -> DateFormatter {
        lock.lock(); defer { lock.unlock() }
        let key = "\(template)|\(lang.rawValue)"
        if let f = cache[key] { return f }
        let f = DateFormatter()
        f.locale = lang.formattingLocale
        f.calendar = Calendar(identifier: .gregorian)
        f.setLocalizedDateFormatFromTemplate(template)
        cache[key] = f
        return f
    }

    static func mmss(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
    /// Latin integer with grouping: `1,250`.
    static func int(_ v: Int) -> String { number(v) }
}

extension String {
    /// Forces a left-to-right run (emails, codes, IDs) inside RTL text.
    var ltr: String { "\u{2066}\(self)\u{2069}" }
}

/// Re-applies the in-app language to presented content (sheets / full-screen covers). UIKit presentations can reset
/// SwiftUI's layout-direction override to the *device* language, so every presentation root uses this.
struct AppLocalized: ViewModifier {
    func body(content: Content) -> some View {
        let lang = LanguageManager.shared.language
        #if APPCLIP
        content
            .brandFontScope()
            .environment(\.locale, lang.locale)
            .environment(\.layoutDirection, lang.layoutDirection)
            .environment(LanguageManager.shared)
            .readsAccessibility()
            .tint(Color.accent)
        #else
        let env = AppEnvironment.shared
        content
            .brandFontScope()
            .environment(\.locale, lang.locale)
            .environment(\.layoutDirection, lang.layoutDirection)
            .environment(env.language)
            .environment(env)
            .readsAccessibility()
            .tint(Color.accent)
        #endif
    }
}
extension View { func appLocalized() -> some View { modifier(AppLocalized()) } }
