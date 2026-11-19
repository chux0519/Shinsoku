import XCTest

/// Tier-B scene for the keyboard's profile switch (docs/iterations/profile-01, P3 scene).
///
/// Run by the coordinator only: `SCENE_TEST=KeyboardSceneTests/ProfileKeyboardSceneTests tool/ios_keyboard_scene.sh
/// <UDID> <out-dir>`. Every step attaches `PHASE-xx-<name>`; a failed wait attaches `FAIL-<step>` (screenshot +
/// element trees). Helpers live in `SceneSupport.swift`.
///
/// Checks PR1 (Record uses the shown profile), PR2 (strict precedence: manual > automation > field rule >
/// default) and PR4 (read-only without Full Access) of `docs/design/state_invariants.md`.
///
/// Profiles: the app's built-in list (`defaultVoiceProfiles`): Dictation (`dictation`, the default), Chat,
/// Review, ZH -> EN. A simulator whose profiles were edited in the app fails at the first name check.
///
/// Seed (Runner Debug launch arguments, `AppDelegate.applySceneProfileArguments`): the selection is removed, so
/// Dart's launch sync publishes the list and writes the default selection; `fieldRules.v1` = `{search: review}`.
///
/// The keyboard's profile control is a button labelled "Profile" whose accessibility value is the profile name
/// (`"<name>, read only"` without Full Access).
final class ProfileKeyboardSceneTests: SceneTestCase {
    private enum Profile {
        static let names = ["Dictation", "Chat", "Review", "ZH -> EN"]
        static let defaultName = "Dictation"
        static let chat = "Chat"
        static let review = "Review"
        static let reviewId = "review"
    }

    private static let fieldRules = "{\"search\":\"\(Profile.reviewId)\"}"
    private static let seedArguments = [
        "-ShinsokuSceneResetSelection", "YES", "-ShinsokuSceneFieldRules", fieldRules,
    ]
    private static let lockedStatus = "Turn on Full Access to switch profiles"
    private static let cancel = ["Cancel", "取消"]

    /// Non-fatal findings (the long-press menu may not draw inside the keyboard window); reported at the end.
    private var softFailures: [String] = []

    func testProfileKeyboardScene() throws {
        // 0. Keyboard added, Full Access on (idempotent).
        ensureKeyboardAdded()
        setFullAccess(true)
        shot("full-access-on")

        // 1. Seed: profiles published, selection reset to default, field rules {search: review}.
        launchSeededRunner("seed")

        // 2. Textarea (kind other): no rule applies → the default profile.
        focusFieldWithShinsoku()
        expectProfile(Profile.defaultName, step: "textarea-default")
        shot("textarea-default")

        // 3. Tap cycles in list order (manual pick); long-press lists all profiles; pick Chat.
        tap(profileButton(), "profile-tap-1")
        expectProfile(Profile.chat, step: "tap-next-chat")
        shot("tap-chat")
        tap(profileButton(), "profile-tap-2")
        expectProfile(Profile.review, step: "tap-next-review")
        shot("tap-review")
        pickFromMenu(Profile.chat)
        expectProfile(Profile.chat, step: "picked-chat")
        shot("picked-chat")

        // 4. Record → shinsoku://dictation?profile=chat → the app records with Chat (PR1).
        tap(key("Record"), "keyboard-record")
        acceptOpenConfirmation(step: "keyboard-record")
        expectDictationStarted(runner, step: "keyboard-record")
        let chatSelected = runner.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@ AND selected == YES", Profile.chat
        )).firstMatch
        require(chatSelected, "record-shows-chat", timeout: 5)
        shot("record-chat")
        runner.terminate()

        // 5. Selection back to default; Safari's address bar (kind search) → the field rule: Review.
        launchSeededRunner("reset")
        focusAddressBarWithShinsoku(step: "address-bar-rule")
        expectProfile(Profile.review, step: "address-bar-rule")
        shot("address-bar-rule-review")

        // 6. "Set Shinsoku Profile: Chat" (automation) → the address bar shows Chat, not Review (PR2).
        runAppShortcut(Self.setTitles, step: "set-chat", pick: Profile.chat)
        expectDialog("Shinsoku profile: \(Profile.chat)", step: "set-chat")
        shortcuts.terminate()
        focusAddressBarWithShinsoku(step: "address-bar-automation")
        expectProfile(Profile.chat, step: "address-bar-automation")
        shot("address-bar-automation-chat")
        leaveAddressBar()

        // 7. Full Access off → last shown name, read-only with the lock; tap explains why (PR4).
        setFullAccess(false)
        shot("full-access-off")
        focusFieldWithShinsoku()
        expectProfile("\(Profile.chat), read only", step: "read-only-chat")
        shot("read-only-chat")
        tap(profileButton(), "read-only-tap")
        require(statusText(Self.lockedStatus), "read-only-status", timeout: 5)
        shot("read-only-explained")
        profileButton().press(forDuration: 1.0)
        if waitMenuItem(Profile.review, timeout: 2) != nil {
            softFail("read-only-menu", "a profile menu opened without Full Access")
        }
        setFullAccess(true)
        shot("full-access-restored")

        // 8. Leave the system keyboard selected for the next scene.
        restoreSystemKeyboard()

        print("SCENE soft failures: \(softFailures.isEmpty ? "none" : softFailures.joined(separator: ", "))")
        XCTAssertTrue(softFailures.isEmpty, "soft failures: \(softFailures.joined(separator: ", "))")
    }

    // MARK: Steps

    /// Launches Shinsoku with the seed arguments and waits for the Record tab (Dart's launch sync has run by
    /// then: the profile list is published and the default selection written).
    private func launchSeededRunner(_ name: String) {
        launchRunner(Self.seedArguments, shotName: "runner-\(name)")
        require(runner.descendants(matching: .any).matching(labelContainsAny: ["Record"]).firstMatch,
                "runner-\(name)-ready", timeout: 15)
        runner.terminate()
    }

    /// Safari's address bar focused (keyboard type `.webSearch` → field kind search) with Shinsoku up.
    /// iOS 27: while the page's textarea has focus the bar is a minimized, unlabelled capsule; end the page edit
    /// (form toolbar Done), then tap the bar (capsule → expanded → editing may take two taps) until an address
    /// text field has keyboard focus.
    private func focusAddressBarWithShinsoku(step: String) {
        if safari.state == .notRunning {
            safari.launch()
        } else {
            safari.activate()
        }
        var input = focusedAddressInput()
        if input == nil {
            let done = safari.buttons.matching(labelEquals: L.done).firstMatch
            if done.waitForExistence(timeout: 2), field().exists, hasKeyboardFocus(field()) {
                done.tap()
            }
        }
        for _ in 0..<4 where input == nil {
            let bar = safariAddressBar()
            if bar.waitForExistence(timeout: 3) {
                bar.tap()
            } else {
                // Bars can stay hidden after a scroll: a small drag down brings them back.
                safari.swipeDown()
            }
            Thread.sleep(forTimeInterval: 1)
            input = focusedAddressInput()
        }
        guard let input else {
            check(false, "\(step)-address-field", "\(step): no focused address field")
            return
        }
        print("SCENE \(step): address field '\(input.label)' focused")
        switchToShinsoku(retapping: input, step: "\(step)-shinsoku-keyboard")
    }

    /// The address bar's text field (or search field) when it has keyboard focus.
    private func focusedAddressInput() -> XCUIElement? {
        for query in [safari.textFields, safari.searchFields] {
            let focused = query.matching(NSPredicate(format: "hasKeyboardFocus == YES")).firstMatch
            if focused.exists { return focused }
        }
        return nil
    }

    private func hasKeyboardFocus(_ element: XCUIElement) -> Bool {
        (element.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    /// Ends address-bar editing (Cancel), so the page's textarea is reachable again.
    private func leaveAddressBar() {
        let cancel = safari.buttons.matching(labelEquals: Self.cancel).firstMatch
        if cancel.waitForExistence(timeout: 2) {
            cancel.tap()
        }
    }

    /// Long-press opens the profile menu (all profiles); picks `name`. If the menu does not show (it may not draw
    /// inside the keyboard window), records a soft failure and cycles with taps instead.
    private func pickFromMenu(_ name: String) {
        profileButton().press(forDuration: 1.0)
        let missing = Profile.names.filter { waitMenuItem($0, timeout: 3) == nil }
        if missing.isEmpty, let item = waitMenuItem(name, timeout: 1) {
            shot("profile-menu")
            item.tap()
            return
        }
        softFail("profile-menu", "long-press menu missing \(missing)")
        // Dismiss whatever opened, then reach `name` by tapping.
        if !profileButton().isHittable { safari.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap() }
        for _ in 0..<Profile.names.count where !profileShows(name) {
            tap(profileButton(), "profile-cycle-to-\(name)")
        }
    }

    // MARK: Elements

    private func profileButton() -> XCUIElement {
        safari.buttons.matching(NSPredicate(format: "label == 'Profile'")).firstMatch
    }

    private func profileShows(_ value: String) -> Bool {
        (profileButton().value as? String) == value
    }

    private func expectProfile(_ value: String, step: String) {
        let shown = safari.buttons.matching(NSPredicate(format: "label == 'Profile' AND value == %@", value)).firstMatch
        if !shown.waitForExistence(timeout: 5) {
            let actual = profileButton().exists ? (profileButton().value as? String ?? "nil") : "no profile button"
            check(false, step, "\(step): keyboard should show '\(value)', shows '\(actual)'")
        }
        print("SCENE \(step): profile \(value)")
    }

    /// A menu item labelled exactly `name`, in Safari (the keyboard's window) or SpringBoard; polls both.
    private func waitMenuItem(_ name: String, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for app in [safari, springboard] {
                let item = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch
                if item.exists { return item }
            }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < deadline
        return nil
    }

    private func softFail(_ step: String, _ message: String) {
        attachFailure(step)
        print("SCENE SOFT-FAIL \(step): \(message)")
        softFailures.append(step)
    }
}
