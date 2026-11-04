import XCTest

/// The owner face against the local rig (scripts/ui-test.sh). Uses the fixture owner; never rotates a branch link (that would invalidate the cashier fixtures).
final class OwnerFlowUITests: XCTestCase {
    var app: XCUIApplication!
    let env = ProcessInfo.processInfo.environment
    var base: String { env["CAF_BASE"] ?? "http://127.0.0.1:8111" }
    let email = "wtest-s3@local.test", password = "LocalTest#2026"

    override func setUp() { continueAfterFailure = false; app = XCUIApplication() }

    private func launch(signedIn: Bool) {
        app.launchArguments = ["-resetSession", "-skipSplash", "-appLanguage", "ar", "-memoryStore"] + (signedIn ? ["-debugOwner", "\(email):\(password)"] : [])
        app.launchEnvironment["CAF_SERVER_BASE"] = base
        app.launch()
    }
    private func el(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    @discardableResult private func wait(_ e: XCUIElement, _ t: TimeInterval = 15, _ what: String = "", line: UInt = #line) -> XCUIElement { XCTAssertTrue(e.waitForExistence(timeout: t), "missing \(what.isEmpty ? e.debugDescription : what)", line: line); return e }
    private func scrollTo(_ id: String) { for _ in 0..<6 where !el(id).isHittable { app.swipeUp() } }
    private func shot(_ name: String) { let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }

    func testRoleChoiceLeadsToLoginAndWrongPasswordIsRefused() {
        launch(signedIn: false)
        wait(el("role.owner")).tap()
        wait(el("owner.email")).tap(); el("owner.email").typeText(email)
        el("owner.password").tap(); el("owner.password").typeText("definitely-wrong")
        el("owner.sign_in").tap()
        wait(el("owner.error"), 15, "an error under the form")
        XCTAssertTrue(el("owner.sign_in").exists, "still on the form")
        shot("owner-login-refused")
    }

    func testOverviewTeamStaffPinAndSignOut() {
        launch(signedIn: true)
        wait(el("owner.tile.orders"), 25, "today's tiles")
        wait(el("owner.tile.members"))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'owner.branch.'")).firstMatch.exists, "a branch card")
        shot("owner-overview")

        // team: add a cashier, the PIN is shown once
        app.tabBars.buttons["الفريق"].tap()
        scrollTo("owner.add_staff"); wait(el("owner.add_staff")).tap()
        let name = wait(el("owner.staff_name")); name.tap(); name.typeText("UI Test Staff")
        el("owner.staff_save").tap()
        let pin = wait(el("owner.pin_value"), 15, "the one-time PIN")
        XCTAssertEqual(pin.label.replacingOccurrences(of: " ", with: "").count, 6, "6-digit PIN")
        shot("owner-pin")
        el("owner.pin_done").tap()
        XCTAssertFalse(el("owner.pin_value").waitForExistence(timeout: 2), "PIN is gone after Done")
        XCTAssertTrue(app.staticTexts["UI Test Staff"].waitForExistence(timeout: 8), "new staff listed")

        // a branch opens its link sheet with a QR (no rotation here)
        app.swipeDown()
        let branch = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'owner.team.branch.'")).firstMatch
        wait(branch).tap()
        wait(el("owner.qr")); wait(el("owner.copy_link")); wait(el("owner.open_cashier"))
        shot("owner-branch-link")
        app.buttons["تم"].tap()

        // account → sign out → the form
        app.tabBars.buttons["حسابي"].tap()
        scrollTo("owner.sign_out"); wait(el("owner.sign_out")).tap()
        app.buttons["تسجيل الخروج"].firstMatch.tap()
        wait(el("owner.sign_in"), 15, "back on the sign-in form")
    }

    func testOwnerCanOpenACashierBranchFromTheApp() {
        launch(signedIn: true)
        wait(el("owner.tile.orders"), 25)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'owner.branch.'")).firstMatch.tap()
        wait(el("owner.open_cashier")).tap()
        // the cashier face asks for the staff list / PIN of that branch
        XCTAssertTrue(app.staticTexts["من أنت؟"].waitForExistence(timeout: 20), "cashier staff picker")
        shot("owner-to-cashier")
    }
}
