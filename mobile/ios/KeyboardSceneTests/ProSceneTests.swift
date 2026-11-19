import XCTest

/// Tier-B scene for Shinsoku Pro (docs/iterations/pricing-01, S2/S3).
///
/// Run by the coordinator only: `SCENE_TEST=KeyboardSceneTests/ProSceneTests tool/ios_keyboard_scene.sh <UDID>
/// <out-dir>`. Every step attaches `PHASE-xx-<name>`; a failed wait attaches `FAIL-<step>`. Helpers live in
/// `SceneSupport.swift`.
///
/// Checks E4 (the keyboard follows the mirror `pro.v1`) and E3 (rules stay stored while locked) of
/// `docs/design/state_invariants.md`, plus the locked UI:
/// 1. `owned`: set the field rule Search → Review in the app (Field rules is Pro).
/// 2. `locked`: Field rules shows the lock note and still lists Search → Review; Settings shows the Shinsoku Pro
///    row with the price; the keyboard in Safari's address bar ignores the rule (default profile).
/// 3. `owned` again: the same address bar shows Review.
///
/// Pro comes from the Debug fixture `-ShinsokuSceneProFixture owned|locked` (`ProStore` writes the mirror from
/// it, Dart uses a fake store with the price "$4.99"); StoreKit is not used. A teardown sets the rule back to
/// None with Pro owned (the mirror stays owned for the other scenes).
/// Runner pages are reached by deep links (M07): `shinsoku://settings/field-rules` selects the Settings tab and
/// pushes Field rules; Back shows Settings with the Pro section first.
final class ProSceneTests: SceneTestCase {
    private enum Profile {
        static let defaultName = "Dictation"
        static let review = "Review"
    }

    private static let resetSelection = ["-ShinsokuSceneResetSelection", "YES"]
    private static let owned = ["-ShinsokuSceneProFixture", "owned"]
    private static let locked = ["-ShinsokuSceneProFixture", "locked"]
    private static let fieldRulesURL = URL(string: "shinsoku://settings/field-rules")!
    private static let searchKind = "Search"
    private static let noRule = "None"
    private static let lockedNote = ["Field rules need Shinsoku Pro", "输入框规则需要 Shinsoku Pro"]
    private static let proName = "Shinsoku Pro"
    private static let fixturePrice = "4.99"
    private static let back = ["Back", "返回"]

    func testProScene() throws {
        ensureKeyboardAdded()
        setFullAccess(true)
        shot("full-access-on")

        // 1. Pro owned: Search → Review.
        launchRunner(Self.owned + Self.resetSelection, shotName: "runner-owned")
        waitRunnerReady("owned")
        setSearchRule(Profile.review, step: "field-rules-owned")
        runner.terminate()
        addTeardownBlock { [unowned self] in
            self.launchRunner(Self.owned, shotName: "runner-rule-reset")
            self.setSearchRule(Self.noRule, step: "field-rules-reset")
            self.runner.terminate()
        }

        // 2. Locked: lock note, rule still listed; Settings Pro row with the price.
        launchRunner(Self.locked + Self.resetSelection, shotName: "runner-locked")
        waitRunnerReady("locked")
        openDeepLink(Self.fieldRulesURL, step: "field-rules-locked-link")
        require(runner.descendants(matching: .any).matching(labelContainsAny: Self.lockedNote).firstMatch,
                "field-rules-lock-note", timeout: 10)
        let keptRule = runner.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label CONTAINS %@", Self.searchKind, Profile.review
        )).firstMatch
        require(keptRule, "field-rules-rule-kept", timeout: 5)
        shot("field-rules-locked")
        let back = runner.buttons.matching(labelEquals: Self.back).firstMatch
        if back.waitForExistence(timeout: 3) { back.tap() }
        let proRow = runner.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@", Self.proName, Self.fixturePrice
        )).firstMatch
        require(proRow, "settings-pro-row-price", timeout: 10)
        print("SCENE settings-pro-row: \(proRow.label.replacingOccurrences(of: "\n", with: " | "))")
        shot("settings-pro-locked")
        runner.terminate()

        // 3. Locked keyboard: the address bar (kind search) ignores the rule → the default profile.
        focusAddressBarWithShinsoku(step: "address-bar-locked")
        expectProfile(Profile.defaultName, step: "address-bar-locked")
        shot("address-bar-locked-default")
        leaveAddressBar()

        // 4. Owned again: the rule applies.
        launchRunner(Self.owned + Self.resetSelection, shotName: "runner-owned-again")
        waitRunnerReady("owned-again")
        runner.terminate()
        focusAddressBarWithShinsoku(step: "address-bar-owned")
        expectProfile(Profile.review, step: "address-bar-owned")
        shot("address-bar-owned-review")
        leaveAddressBar()

        restoreSystemKeyboard()
    }

    // MARK: Steps

    private func waitRunnerReady(_ name: String) {
        require(runner.descendants(matching: .any).matching(labelContainsAny: Self.recordTab).firstMatch,
                "runner-\(name)-ready", timeout: 15)
    }

    /// Field rules page (deep link) → Search → `profile` (a profile name or None); then Back.
    private func setSearchRule(_ profile: String, step: String) {
        openDeepLink(Self.fieldRulesURL, step: "\(step)-link")
        let search = runner.buttons.matching(NSPredicate(
            format: "label == %@ OR label BEGINSWITH %@", Self.searchKind, "\(Self.searchKind)\n"
        )).firstMatch
        waitHittable(search, "\(step)-search-row")
        if !search.label.contains(profile) {
            search.tap()
            let option = runner.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@",
                                                             profile, "\(profile)\n")).firstMatch
            waitHittable(option, "\(step)-option-\(profile)")
            option.tap()
        }
        let picked = runner.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label CONTAINS %@", Self.searchKind, profile
        )).firstMatch
        require(picked, "\(step)-shows-\(profile)", timeout: 5)
        shot(step)
        let back = runner.buttons.matching(labelEquals: Self.back).firstMatch
        if back.exists { back.tap() }
    }

    private func waitHittable(_ element: XCUIElement, _ step: String, timeout: TimeInterval = 10) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !(element.exists && !element.frame.isEmpty && element.isHittable) {
            Thread.sleep(forTimeInterval: 0.3)
        }
        check(element.exists && !element.frame.isEmpty && element.isHittable, step, "\(step): not hittable")
    }

    /// Safari's address bar focused with Shinsoku up (same approach as `ProfileKeyboardSceneTests`).
    private func focusAddressBarWithShinsoku(step: String) {
        if safari.state == .notRunning {
            safari.launch()
        } else {
            safari.activate()
        }
        var input = focusedAddressInput()
        for _ in 0..<4 where input == nil {
            let bar = safariAddressBar()
            if bar.waitForExistence(timeout: 3) {
                bar.tap()
            } else {
                safari.swipeDown()
            }
            Thread.sleep(forTimeInterval: 1)
            input = focusedAddressInput()
        }
        guard let input else {
            check(false, "\(step)-address-field", "\(step): no focused address field")
            return
        }
        switchToShinsoku(retapping: input, step: "\(step)-shinsoku-keyboard")
    }

    private func focusedAddressInput() -> XCUIElement? {
        for query in [safari.textFields, safari.searchFields] {
            let focused = query.matching(NSPredicate(format: "hasKeyboardFocus == YES")).firstMatch
            if focused.exists { return focused }
        }
        return nil
    }

    private func leaveAddressBar() {
        let cancel = safari.buttons.matching(labelEquals: ["Cancel", "取消"]).firstMatch
        if cancel.waitForExistence(timeout: 2) { cancel.tap() }
    }

    private func expectProfile(_ value: String, step: String) {
        let shown = safari.buttons.matching(NSPredicate(
            format: "label IN %@ AND value IN %@", Self.variants("Profile"), Self.variants(value)
        )).firstMatch
        if !shown.waitForExistence(timeout: 5) {
            let button = safari.buttons.matching(labelEquals: Self.variants("Profile")).firstMatch
            let actual = button.exists ? (button.value as? String ?? "nil") : "no profile button"
            check(false, step, "\(step): keyboard should show '\(value)', shows '\(actual)'")
        }
        print("SCENE \(step): profile \(value)")
    }
}
