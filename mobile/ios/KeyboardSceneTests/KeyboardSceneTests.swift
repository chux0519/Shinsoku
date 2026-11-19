import XCTest

/// Tier-B scene for the Shinsoku keyboard extension (docs/iterations/ios-ui-01, U2).
///
/// Run by the coordinator only, through `tool/ios_keyboard_scene.sh <UDID> <out-dir>`, once per appearance.
/// Every step attaches a screenshot named `PHASE-xx-<name>`; the script exports them as PNGs. Helpers live in
/// `SceneSupport.swift`.
/// The scene is idempotent: the keyboard may already be added and Full Access may already be on.
///
/// Language: the shared simulators run in Chinese and must not be changed. Settings and Safari are launched with
/// `-AppleLanguages (en) -AppleLocale en_US`; every system label is still matched in English and Chinese in case
/// an app ignores that. On a failed wait the scene attaches `FAIL-<step>` before asserting.
///
/// Text field host: a Safari `data:` page with a textarea. The app has no free text field that is reachable
/// without recording a draft or editing persisted provider settings.
final class KeyboardSceneTests: SceneTestCase {
    private static let latestText = "Scene text 1"
    private static let dictationURL = URL(string: "shinsoku://dictation")!

    private var pasteBannerSeen: [String] = []

    func testKeyboardScene() throws {
        // 1. Add the keyboard (skipped when it is already in the list).
        ensureKeyboardAdded()
        shot("keyboard-added")

        // 2. Full Access OFF.
        setFullAccess(false)
        shot("full-access-off")

        // 3. Field + Shinsoku keyboard, no Full Access.
        focusFieldWithShinsoku()
        require(key("Insert latest text"), "insert-key-no-full-access", timeout: 3)
        checkPasteBanner("no-full-access")
        shot("no-full-access")

        // 4. Edit keys: Return, Space, Delete tap, 2 s Delete hold.
        tap(key(returnLabel()), "return-key")
        tap(key("Space"), "space-key")
        tap(key("Delete"), "delete-key")
        shot("edit-keys")
        key("Delete").press(forDuration: 2.0)
        shot("delete-hold")
        check(fieldValue().isEmpty, "delete-hold-field-empty", "Delete hold should clear the field: '\(fieldValue())'")

        // 5. Full Access ON, App Group empty → "Ready", Insert says "Nothing yet".
        setFullAccess(true)
        shot("full-access-on")
        launchRunner(["-ShinsokuSceneResetLatest", "YES"])
        focusFieldWithShinsoku()
        checkPasteBanner("no-latest")
        require(statusText("Ready"), "status-ready", timeout: 5)
        shot("no-latest")
        tap(key("Insert latest text"), "insert-key-empty")
        require(statusText("Nothing yet — tap Record"), "status-nothing-yet", timeout: 5)
        shot("nothing-yet")

        // 6. The app publishes through the real path (Debug launch argument) → Insert.
        launchRunner(["-ShinsokuSceneSeedLatest", Self.latestText])
        focusFieldWithShinsoku()
        checkPasteBanner("latest-ready")
        require(statusText("Latest text ready"), "status-latest-ready", timeout: 5)
        shot("latest-ready")
        tap(key("Insert latest text"), "insert-key")
        require(statusText("Inserted"), "status-inserted", timeout: 5)
        shot("inserted")
        check(fieldValue().contains(Self.latestText), "field-contains-latest", "field: \(fieldValue())")

        // 7. Nothing new: Insert re-inserts the latest.
        tap(key("Insert latest text"), "insert-key-again")
        require(statusText("Inserted again"), "status-inserted-again", timeout: 5)
        shot("inserted-again")

        // 8. Deep link shinsoku://dictation, cold (Runner not running) and warm (Runner in the background).
        runner.terminate()
        openDeepLink(Self.dictationURL, step: "deeplink-cold")
        expectDictationStarted(runner, step: "deeplink-cold")
        shot("deeplink-cold")

        runner.launch()  // fresh and idle, so a status change below can only come from the link
        check(runner.wait(for: .runningForeground, timeout: 20), "deeplink-warm-launch", "Shinsoku did not launch")
        require(runner.descendants(matching: .any).matching(labelContainsAny: Self.idleStatus).firstMatch,
                "deeplink-warm-idle", timeout: 15)
        XCUIDevice.shared.press(.home)
        // Home Screen in front counts (the runner's reported state can lag behind); else wait up to 5 s for
        // Runner to report background or suspended.
        let runner = self.runner
        let inBackground = NSPredicate { _, _ in
            [.runningBackground, .runningBackgroundSuspended].contains(runner.state)
        }
        let homeInFront = springboard.wait(for: .runningForeground, timeout: 5)
        let reportedBackground = homeInFront || XCTWaiter().wait(
            for: [XCTNSPredicateExpectation(predicate: inBackground, object: nil)], timeout: 5
        ) == .completed
        print("SCENE deeplink-warm: home in front=\(homeInFront) runner state=\(runner.state.rawValue)")
        check(reportedBackground, "deeplink-warm-background", "Shinsoku did not go to the background")
        openDeepLink(Self.dictationURL, step: "deeplink-warm")
        expectDictationStarted(runner, step: "deeplink-warm")
        shot("deeplink-warm")
        runner.terminate()

        // 9. Leave the system keyboard selected, so the next scene (ProfileIntentSceneTests) can type.
        restoreSystemKeyboard()

        let summary = pasteBannerSeen.isEmpty ? "none" : pasteBannerSeen.joined(separator: ", ")
        print("SCENE paste-banner phases: \(summary)")
        XCTContext.runActivity(named: "paste banner phases: \(summary)") { _ in }
    }

    // MARK: Paste banner

    /// Records (screenshot + log) any paste prompt or "pasted from" banner; does not fail the scene.
    private func checkPasteBanner(_ where_: String) {
        let prompt = NSCompoundPredicate(orPredicateWithSubpredicates: L.pastePrompt.map {
            NSPredicate(format: "label CONTAINS[c] %@", $0)
        })
        let candidates = [
            safari.alerts.firstMatch,
            springboard.alerts.firstMatch,
            safari.buttons.matching(prompt).firstMatch,
            springboard.descendants(matching: .any).matching(prompt).firstMatch,
            safari.staticTexts.matching(prompt).firstMatch,
        ]
        _ = candidates[0].waitForExistence(timeout: 1.5)
        guard let hit = candidates.first(where: { $0.exists }) else {
            print("SCENE paste-banner \(where_): none")
            return
        }
        print("SCENE paste-banner \(where_): \(hit.label)")
        pasteBannerSeen.append(where_)
        shot("paste-banner-\(where_)")
        let deny = safari.alerts.buttons.matching(labelBeginsWith: L.deny).firstMatch
        if deny.exists { deny.tap() }
    }
}
