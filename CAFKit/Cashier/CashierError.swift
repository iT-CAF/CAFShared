import Foundation

/// Server error codes of the cashier API. Decisions are made on `code`, never on the (localized, changeable) `message`.
enum CashierErrorCode: Equatable, Sendable {
    case csrf, rate, locked, badPin, notFound, disabled, perm, auth, idem, duplicate, otherStaff, server
    case amount, insufficient, codeInvalid, codeUsed, codeExpired, invalidCode, cooldown, maxPerDay, maxPerTx, minAmount
    case blocked, plan, window, already, notOwn, note, redeemed, choose, noneAvailable, otherProgram
    case badLogin, twofa, noProgram, team, reuse, invalid
    case other(String)

    init(_ raw: String) {
        switch raw {
        case "csrf": self = .csrf
        case "rate": self = .rate
        case "locked": self = .locked
        case "bad_pin": self = .badPin
        case "not_found": self = .notFound
        case "disabled": self = .disabled
        case "perm": self = .perm
        case "auth": self = .auth
        case "idem": self = .idem
        case "duplicate": self = .duplicate
        case "other_staff": self = .otherStaff
        case "server": self = .server
        case "amount": self = .amount
        case "insufficient": self = .insufficient
        case "code_invalid": self = .codeInvalid
        case "code_used": self = .codeUsed
        case "code_expired": self = .codeExpired
        case "invalid_code": self = .invalidCode
        case "cooldown": self = .cooldown
        case "max_per_day": self = .maxPerDay
        case "max_per_tx": self = .maxPerTx
        case "min_amount": self = .minAmount
        case "blocked": self = .blocked
        case "plan": self = .plan
        case "window": self = .window
        case "already": self = .already
        case "not_own": self = .notOwn
        case "note": self = .note
        case "redeemed": self = .redeemed
        case "choose", "choose_reward": self = .choose
        case "none_available": self = .noneAvailable
        case "other_program": self = .otherProgram
        case "bad_login": self = .badLogin
        case "twofa": self = .twofa
        case "no_program": self = .noProgram
        case "team": self = .team
        case "reuse": self = .reuse
        case "invalid": self = .invalid
        default: self = .other(raw)
        }
    }

    /// Localization key (`err.<name>`); nil → fall back to the server's message.
    var l10nKey: String? {
        switch self {
        case .csrf: "err.csrf"; case .rate: "err.rate"; case .locked: "err.locked"; case .badPin: "err.bad_pin"; case .notFound: "err.not_found"
        case .disabled: "err.disabled"; case .perm: "err.perm"; case .auth: "err.auth"; case .idem: "err.idem"; case .duplicate: "err.duplicate"
        case .otherStaff: "err.other_staff"; case .server: "err.server"; case .amount: "err.amount"; case .insufficient: "err.insufficient"
        case .codeInvalid, .invalidCode: "err.code_invalid"; case .codeUsed: "err.code_used"; case .codeExpired: "err.code_expired"
        case .cooldown: "err.cooldown"; case .maxPerDay: "err.max_per_day"; case .maxPerTx: "err.max_per_tx"; case .minAmount: "err.min_amount"
        case .blocked: "err.blocked"; case .plan: "err.plan"; case .window: "err.window"; case .already: "err.already"; case .notOwn: "err.not_own"
        case .note: "err.note"; case .redeemed: "err.redeemed"; case .choose: "err.choose"; case .noneAvailable: "err.none_available"; case .otherProgram: "err.other_program"
        case .badLogin: "err.bad_login"; case .twofa: "err.twofa"; case .noProgram: "err.no_program"; case .team: "err.team"; case .reuse: "err.reuse"; case .invalid: "err.invalid_login"
        case .other: nil
        }
    }
}

enum CashierError: Error, Equatable, Sendable {
    /// The server answered `{error:true, code, message, …}`.
    case api(code: CashierErrorCode, message: String, status: Int, left: Int?, wait: Int?, needed: Int?, minutes: Int?, lastActor: String?, canOverride: Bool)
    /// No connection / timeout (the request may or may not have reached the server → retry with the same idem).
    case offline
    /// Unreadable answer (not our JSON).
    case malformed(status: Int)

    static func api(_ code: CashierErrorCode, _ message: String = "", status: Int = 400) -> CashierError {
        .api(code: code, message: message, status: status, left: nil, wait: nil, needed: nil, minutes: nil, lastActor: nil, canOverride: false)
    }

    var code: CashierErrorCode? { if case .api(let c, _, _, _, _, _, _, _, _) = self { c } else { nil } }
    var isOffline: Bool { self == .offline }
    /// The session is gone (cookie expired / signed out elsewhere) → show the PIN pad again, keep the branch.
    var isAuth: Bool { code == .auth }
    var wait: Int? { if case .api(_, _, _, _, let w, _, _, _, _) = self { w } else { nil } }
    var left: Int? { if case .api(_, _, _, let l, _, _, _, _, _) = self { l } else { nil } }

    /// Text for the user: our translation for known codes, else the server's message, else a generic line.
    var userMessage: String {
        switch self {
        case .offline: return L10n.string("err.offline")
        case .malformed: return L10n.string("err.server")
        case .api(let code, let message, _, let left, let wait, let needed, let minutes, let lastActor, _):
            if let key = code.l10nKey {
                switch code {
                case .badPin: return left.map { L10n.string("err.bad_pin_left", $0) } ?? L10n.string(key)
                case .locked: return wait.map { L10n.string("err.locked_wait", max(1, Int((Double($0) / 60).rounded(.up)))) } ?? L10n.string(key)
                case .insufficient: return needed.map { L10n.string("err.insufficient_n", $0) } ?? L10n.string(key)
                case .cooldown: return L10n.string("err.cooldown_n", lastActor ?? "—", minutes ?? 0)
                default: return L10n.string(key)
                }
            }
            return message.isEmpty ? L10n.string("err.server") : message
        }
    }
}

extension CashierError {
    /// Builds the error from an answer body `{error:true, code, message, left?, wait?, …}`.
    static func from(json: [String: Any], status: Int) -> CashierError {
        func int(_ k: String) -> Int? { (json[k] as? Int) ?? (json[k] as? Double).map(Int.init) ?? (json[k] as? String).flatMap(Int.init) }
        let raw = (json["code"] as? String) ?? (status == 404 ? "not_found" : status == 419 ? "csrf" : status == 429 ? "rate" : status == 401 ? "auth" : "server")
        return .api(code: CashierErrorCode(raw), message: (json["message"] as? String) ?? "", status: status, left: int("left"), wait: int("wait"), needed: int("needed"),
                    minutes: int("minutes"), lastActor: json["last_actor"] as? String, canOverride: (json["can_override"] as? Bool) ?? false)
    }
}
