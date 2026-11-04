import Foundation

/// UI state of the PIN pad derived from the server's answers: attempts left, lock countdown (15 min after 5 wrong PINs).
struct PinLockState: Equatable, Sendable {
    private(set) var attemptsLeft: Int?
    private(set) var lockedUntil: Date?

    /// Feed every login failure here.
    mutating func apply(_ error: CashierError, now: Date = .now) {
        switch error.code {
        case .badPin: attemptsLeft = error.left; lockedUntil = nil
        case .locked: attemptsLeft = nil; lockedUntil = now.addingTimeInterval(TimeInterval(error.wait ?? 900))
        default: break
        }
    }
    mutating func reset() { attemptsLeft = nil; lockedUntil = nil }

    func isLocked(now: Date = .now) -> Bool { (lockedUntil ?? .distantPast) > now }
    func remainingSeconds(now: Date = .now) -> Int { max(0, Int((lockedUntil ?? now).timeIntervalSince(now).rounded(.up))) }
}

/// PIN entry rules: 4–8 Latin digits.
enum PinRules {
    static let minLength = 4, maxLength = 8
    static func isValid(_ pin: String) -> Bool { (minLength...maxLength).contains(pin.count) && pin.allSatisfy { $0.isASCII && $0.isNumber } }
}
