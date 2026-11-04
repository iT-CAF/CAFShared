import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// What the owner face shows and does. UI-facing, main-actor; all I/O goes through `OwnerSession`.
@Observable
@MainActor
final class OwnerStore {
    enum Phase: Equatable { case checking, signedOut, offline, ready }

    /// A staff PIN the server revealed once (create / reset). Held in memory only until the sheet is dismissed.
    struct RevealedPin: Identifiable, Equatable { let id = UUID(); let staffName: String; let pin: String }

    let session: OwnerSession
    private(set) var phase: Phase = .checking
    private(set) var me: OwnerMe?
    private(set) var businesses: [OwnerBusiness] = []
    private(set) var overview: OwnerOverview?
    private(set) var team: OwnerTeam?
    private(set) var devices: [OwnerDevice] = []
    private(set) var selectedId: Int?
    private(set) var isBusy = false
    private(set) var isSigningIn = false
    var loginError: String?
    var banner: String?
    var revealedPin: RevealedPin?

    private let defaults: UserDefaults
    private static let selectedKey = "owner.selected"

    init(session: OwnerSession = OwnerSession(), defaults: UserDefaults = .standard) {
        self.session = session; self.defaults = defaults
        let saved = defaults.integer(forKey: Self.selectedKey); selectedId = saved > 0 ? saved : nil
    }

    var selected: OwnerBusiness? { businesses.first { $0.id == selectedId } ?? businesses.first }
    var canManage: Bool { selected?.manage ?? false }

    // MARK: session

    /// Launch / return to the owner face: restores the stored sign-in or asks for one.
    func bootstrap() async {
        await session.setLanguage(L10n.language == .en ? "en" : "ar")
        guard await session.isSignedIn else { phase = .signedOut; return }
        phase = .checking
        await loadAccount()
    }

    func loadAccount() async {
        do {
            let me = try await session.me()
            let list = try await session.businesses()
            self.me = me; businesses = list
            if !list.contains(where: { $0.id == selectedId }) { setSelected(list.first?.id) }
            phase = .ready
            banner = nil
            await refreshOverview()
        } catch { fail(error, whenOffline: .offline) }
    }

    func signIn(email: String, password: String) async {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty, !password.isEmpty else { loginError = L10n.string("owner.login_missing"); return }
        let name = Self.deviceName
        await signIn { try await $0.login(email: e, password: password, deviceName: name) }
    }

    /// Any sign-in method (password, Apple, Google, OAuth, WhatsApp code): `work` obtains the tokens from the server, then the account is loaded like on a normal launch.
    @discardableResult
    func signIn(using work: (OwnerSession) async throws -> OwnerMe) async -> Bool {
        isSigningIn = true; loginError = nil
        defer { isSigningIn = false }
        do {
            await session.setLanguage(L10n.language == .en ? "en" : "ar")
            me = try await work(session)
            await loadAccount()
            if phase != .ready { loginError = banner; return false }
            return true
        } catch let err as CashierError {
            loginError = err.userMessage
        } catch { loginError = L10n.string("err.server") }
        return false
    }

    /// Shows a message under the sign-in form (cancelled browser sheets stay silent; other failures land here).
    func reportSignInFailure(_ message: String) { loginError = message }

    func signOut() async {
        await session.logout()
        reset()
        phase = .signedOut
    }

    private func reset() { me = nil; businesses = []; overview = nil; team = nil; devices = []; banner = nil; revealedPin = nil }

    func setSelected(_ id: Int?) {
        selectedId = id
        if let id { defaults.set(id, forKey: Self.selectedKey) } else { defaults.removeObject(forKey: Self.selectedKey) }
        overview = nil; team = nil
    }

    func select(_ id: Int) async { setSelected(id); await refreshOverview(); if canManage { await loadTeam() } }

    static var deviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name.isEmpty ? "iPhone" : UIDevice.current.name
        #else
        return "iPhone"
        #endif
    }

    // MARK: data

    func refreshOverview() async {
        guard let b = selected else { return }
        do { let o = try await session.overview(b.id); if b.id == selected?.id { overview = o; banner = nil } }
        catch { fail(error, whenOffline: nil) }
    }

    /// Live loop while the overview is on screen (cancelled with the view's task).
    func pollOverview(every seconds: Double = 20) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(seconds))
            if Task.isCancelled { break }
            await refreshOverview()
        }
    }

    func loadTeam() async {
        guard let b = selected, b.manage else { return }
        do { let t = try await session.team(b.id); if b.id == selected?.id { team = t; banner = nil } }
        catch { fail(error, whenOffline: nil) }
    }

    func loadDevices() async {
        do { devices = try await session.devices() } catch { fail(error, whenOffline: nil) }
    }

    func revokeDevice(_ id: Int) async {
        do { try await session.revokeDevice(id); await loadDevices() } catch { fail(error, whenOffline: nil) }
    }

    // MARK: changes — each answer carries the fresh team, so the screen never has to guess

    @discardableResult
    private func change(_ work: (OwnerSession, Int) async throws -> OwnerTeam) async -> OwnerTeam? {
        guard let b = selected else { return nil }
        isBusy = true; defer { isBusy = false }
        do { let t = try await work(session, b.id); team = t; banner = nil; await refreshOverview(); return t }
        catch { fail(error, whenOffline: nil); return nil }
    }

    func createBranch(name: String, address: String) async -> Bool {
        await change { try await $0.createBranch($1, name: name, address: address) } != nil
    }
    func toggleBranch(_ id: Int) async { await change { try await $0.toggleBranch($1, branch: id) } }
    func rotateLink(_ branch: OwnerBranch) async { await change { try await $0.rotateBranchLink($1, branch: branch.id) } }
    func createStaff(name: String, role: String, branch: Int?) async -> Bool {
        guard let t = await change({ try await $0.createStaff($1, name: name, role: role, branch: branch) }) else { return false }
        if let pin = t.pin { revealedPin = RevealedPin(staffName: name, pin: pin) }
        return true
    }
    func resetPin(_ s: OwnerStaff) async {
        if let t = await change({ try await $0.resetStaffPin($1, staff: s.id) }), let pin = t.pin { revealedPin = RevealedPin(staffName: s.name, pin: pin) }
    }
    func toggleStaff(_ id: Int) async { await change { try await $0.toggleStaff($1, staff: id) } }

    // MARK: errors

    /// A refused sign-in sends the owner back to the form; no network keeps what is on screen.
    private func fail(_ error: Error, whenOffline: Phase?) {
        if error is CancellationError { return }
        guard let e = error as? CashierError else { banner = L10n.string("err.server"); return }
        if e.isAuth { reset(); phase = .signedOut; loginError = L10n.string("owner.session_ended"); return }
        if e.isOffline, let whenOffline, phase != .ready { phase = whenOffline; return }
        banner = e.userMessage
    }
}
