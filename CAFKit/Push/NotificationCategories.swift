import Foundation
import UserNotifications

/// Notification categories the server names in `aps.category` (`cafbio-mobile/src/Push`). Identifiers are a wire contract.
enum NotificationCategory {
    static let cashierOrder = "CASHIER_ORDER"
    static let ownerBranch = "OWNER_BRANCH"
    static let pagerReady = "PAGER_READY"
}

enum NotificationActionID {
    static let prepare = "prepare", ready = "ready"        // CASHIER_ORDER
    static let pause = "pause", open = "open"              // OWNER_BRANCH
    static let picked = "picked"                           // PAGER_READY
}

enum NotificationCategories {
    /// Every category; an app registers them all (an unused one is harmless) so a push never arrives without its buttons.
    static func all(language: AppLanguage = L10n.language) -> Set<UNNotificationCategory> {
        func action(_ id: String, _ key: String, foreground: Bool, destructive: Bool = false) -> UNNotificationAction {
            var o: UNNotificationActionOptions = []
            if foreground { o.insert(.foreground) }
            if destructive { o.insert(.destructive) }
            return UNNotificationAction(identifier: id, title: L10n.string(key, in: language), options: o)
        }
        func category(_ id: String, _ actions: [UNNotificationAction]) -> UNNotificationCategory {
            UNNotificationCategory(identifier: id, actions: actions, intentIdentifiers: [], options: [])
        }
        return [
            // Prepare / ready run in the background through the cashier session; the app opens only when the session needs the PIN.
            category(NotificationCategory.cashierOrder, [action(NotificationActionID.prepare, "push.action.prepare", foreground: false),
                                                          action(NotificationActionID.ready, "push.action.ready", foreground: false)]),
            category(NotificationCategory.ownerBranch, [action(NotificationActionID.pause, "push.action.pause", foreground: false, destructive: true),
                                                         action(NotificationActionID.open, "push.action.open", foreground: true)]),
            category(NotificationCategory.pagerReady, [action(NotificationActionID.picked, "push.action.picked", foreground: false)]),
        ]
    }

    @MainActor static func register(language: AppLanguage = L10n.language, center: UNUserNotificationCenter = .current()) {
        center.setNotificationCategories(all(language: language))
    }
}
