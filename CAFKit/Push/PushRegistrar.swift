import Foundation
import UIKit
import UserNotifications
import Observation

/// What the server stores for a phone (`POST devices` / `POST /cashier/{token}/api/biz/device`).
struct PushDeviceInfo: Sendable, Equatable {
    var token: String
    /// "sandbox" for development builds, "production" otherwise.
    var env: String
    var bundle: String
    var locale: String
    var tz: String
    var appVersion: String
    var osVersion: String
    var deviceName: String

    /// JSON body with the server's keys.
    var body: [String: String] {
        ["token": token, "env": env, "bundle": bundle, "locale": locale, "tz": tz, "app_version": appVersion, "os_version": osVersion, "device_name": deviceName]
    }
}

/// Each app plugs its own API here (owner: bearer `devices`; cashier: branch link + PIN session `biz/device`).
protocol DeviceRegistering: Sendable {
    /// Returns the server's device id.
    @discardableResult func registerDevice(_ info: PushDeviceInfo) async throws -> Int
    func unregisterDevice(id: Int) async throws
}

/// What the user did with a notification (tap or one of the category buttons).
struct NotificationTap: Sendable, Equatable {
    var actionIdentifier: String
    var categoryIdentifier: String
    /// The server's event key (`e`), e.g. `drive.order.new`.
    var event: String?
    /// Deep link (`url` in the payload), routed by the app's single router.
    var url: URL?
    /// `data` of the payload, flattened to strings (no personal details travel in it).
    var data: [String: String]
    var isDefaultTap: Bool { actionIdentifier == UNNotificationDefaultActionIdentifier }
}

/// Authorisation, APNs token capture and posting the token to the app's API. Created once by the app (`PushRegistrar.shared`).
@Observable
@MainActor
final class PushRegistrar {
    static let shared = PushRegistrar()

    private(set) var status: UNAuthorizationStatus = .notDetermined
    /// Lowercase hex of the APNs token; nil until iOS hands one over.
    private(set) var tokenHex: String?
    private(set) var deviceId: Int?
    private(set) var lastError: String?

    /// The app's API. Set it after sign-in (or after the PIN session opens); setting it posts a token that is already known.
    @ObservationIgnored var registering: (any DeviceRegistering)? {
        didSet { if registering != nil { Task { await registerNow() } } }
    }
    /// A silent push (`content-available`) arrived: wake the realtime client / refresh.
    @ObservationIgnored var onSilentPush: (@MainActor @Sendable () async -> Void)?
    /// The user tapped a notification or one of its buttons.
    @ObservationIgnored var onTap: (@MainActor @Sendable (NotificationTap) async -> Void)?

    private let center: UNUserNotificationCenter
    private var postedKey: String?

    init(center: UNUserNotificationCenter = .current()) { self.center = center }

    var isAuthorised: Bool { status == .authorized || status == .provisional || status == .ephemeral }

    func refreshStatus() async {
        status = await center.notificationSettings().authorizationStatus
        if isAuthorised { UIApplication.shared.registerForRemoteNotifications() }
    }

    /// Asks once (the system prompt appears only while the status is `.notDetermined`), then asks iOS for the APNs token.
    @discardableResult
    func requestAuthorization(provisional: Bool = false) async -> Bool {
        NotificationCategories.register()
        var options: UNAuthorizationOptions = [.alert, .sound, .badge]
        if provisional { options.insert(.provisional) }
        let granted = (try? await center.requestAuthorization(options: options)) ?? false
        await refreshStatus()
        return granted && isAuthorised
    }

    // MARK: token

    nonisolated static func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }

    func didRegister(deviceToken data: Data) {
        tokenHex = Self.hex(data)
        lastError = nil
        Task { await registerNow() }
    }

    func didFailToRegister() { lastError = "apns" }

    /// Posts the token when an API is plugged in. Posts again only when the token or the API's account changed (`force`).
    func registerNow(force: Bool = false) async {
        guard let token = tokenHex, let registering else { return }
        let info = Self.deviceInfo(token: token)
        let key = info.token + "|" + info.locale + "|" + info.appVersion
        if !force, key == postedKey { return }
        do {
            deviceId = try await registering.registerDevice(info)
            postedKey = key
            lastError = nil
        } catch {
            lastError = "register"      // the next launch or sign-in retries; the token itself is never logged
        }
    }

    /// Sign-out: tells the server to stop pushing to this phone, then forgets the registration.
    func unregister() async {
        defer { deviceId = nil; postedKey = nil; registering = nil }
        guard let id = deviceId, let registering else { return }
        try? await registering.unregisterDevice(id: id)
    }

    static func deviceInfo(token: String) -> PushDeviceInfo {
        #if DEBUG
        let env = "sandbox"
        #else
        let env = "production"
        #endif
        return PushDeviceInfo(token: token, env: env, bundle: Bundle.main.bundleIdentifier ?? "", locale: L10n.language.rawValue,
                              tz: TimeZone.current.identifier, appVersion: AppConfig.version, osVersion: UIDevice.current.systemVersion,
                              deviceName: UIDevice.current.model)
    }

    // MARK: payload

    nonisolated static func tap(from response: UNNotificationResponse) -> NotificationTap {
        let c = response.notification.request.content
        let info = c.userInfo
        var data: [String: String] = [:]
        for (k, v) in (info["data"] as? [String: Any]) ?? [:] { data[k] = "\(v)" }
        return NotificationTap(actionIdentifier: response.actionIdentifier, categoryIdentifier: c.categoryIdentifier, event: info["e"] as? String,
                               url: (info["url"] as? String).flatMap(URL.init(string:)), data: data)
    }
}

/// `@UIApplicationDelegateAdaptor(PushAppDelegate.self) var appDelegate` in the app's `App`.
final class PushAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in
            NotificationCategories.register()
            await PushRegistrar.shared.refreshStatus()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushRegistrar.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in PushRegistrar.shared.didFailToRegister() }
    }

    // Completion-handler forms on purpose: the async ones make iOS 17/18 SDKs hop non-Sendable UN* objects across actors.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        nonisolated(unsafe) let done = completionHandler
        Task { @MainActor in
            await PushRegistrar.shared.onSilentPush?()
            done(.newData)
        }
    }

}

// @preconcurrency: UIApplicationDelegate makes the class main-actor isolated; UN* calls arrive on arbitrary threads and only hop to the main actor inside.
extension PushAppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
    // Foreground: show the banner and play the sound like the lock screen would; the app also wakes its realtime feed.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        nonisolated(unsafe) let done = completionHandler
        Task { @MainActor in
            await PushRegistrar.shared.onSilentPush?()
            done([.banner, .list, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let tap = PushRegistrar.tap(from: response)
        nonisolated(unsafe) let done = completionHandler
        Task { @MainActor in
            await PushRegistrar.shared.onTap?(tap)
            done()
        }
    }
}
