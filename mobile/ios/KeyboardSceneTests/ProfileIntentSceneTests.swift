import XCTest

/// Tier-B scene for the profile App Intents (docs/iterations/profile-01, P2).
///
/// Run by the coordinator only: `SCENE_TEST=KeyboardSceneTests/ProfileIntentSceneTests tool/ios_keyboard_scene.sh
/// <UDID> <out-dir>`. Every step attaches `PHASE-xx-<name>`; a failed wait attaches `FAIL-<step>` (screenshot +
/// element tree of the foreground app).
///
/// Path: Shortcuts › Shinsoku's App Shortcuts (from `ShinsokuShortcuts`) › "Set Profile" → pick a profile →
/// dialog "Shinsoku profile: <name>"; then "Get Profile" → the same dialog, read back from the App Group in the
/// intent's own process. Sets Review then Chat, so a leftover value from an earlier run cannot pass the check.
/// Finally Shinsoku is launched cold and must show Chat (the app reads `activeProfile.v1` at launch).
/// TODO(P3): after the keyboard shows the profile, add: open the Safari field from `KeyboardSceneTests` and assert
/// the keyboard status row shows Chat.
///
/// The App Shortcuts tiles are found without creating a shortcut, so the scene is idempotent and leaves nothing
/// behind in the user's library. System labels are matched in English and Chinese (the shared simulators run in
/// Chinese; Shortcuts is launched with English launch arguments).
final class ProfileIntentSceneTests: XCTestCase {
    private let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private let runner = XCUIApplication()

    private static let englishArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    private static let appName = "Shinsoku"
    private static let setTitles = ["Set Profile", "Set Shinsoku Profile"]
    private static let getTitles = ["Get Profile", "Get Shinsoku Profile"]

    private enum L {
        static let shortcutsTab = ["Shortcuts", "快捷指令"]
        static let allShortcuts = ["All Shortcuts", "所有快捷指令"]
        static let search = ["Search", "搜索"]
        static let done = ["Done", "完成", "OK", "好"]
        static let allow = ["Allow", "允许", "Always Allow", "始终允许"]
    }

    private var phase = 0

    override func setUp() {
        continueAfterFailure = false
        shortcuts.launchArguments = Self.englishArguments
        shortcuts.terminate()
    }

    func testProfileIntentScene() throws {
        // 1. Launch Shinsoku once: Dart publishes `profiles.v1` (the intents' entity list) at launch.
        runner.terminate()
        runner.launch()
        check(runner.wait(for: .runningForeground, timeout: 20), "runner-launch", "Shinsoku did not launch")
        require(runner.descendants(matching: .any).matching(labelContainsAny: ["Record"]).firstMatch,
                "runner-ready", timeout: 15)
        shot("runner-published")
        runner.terminate()

        // 2. Set Review, read it back; then Chat, read it back.
        for name in ["Review", "Chat"] {
            runAppShortcut(Self.setTitles, step: "set-\(name.lowercased())", pick: name)
            expectDialog("Shinsoku profile: \(name)", step: "set-\(name.lowercased())")
            runAppShortcut(Self.getTitles, step: "get-\(name.lowercased())", pick: nil)
            expectDialog("Shinsoku profile: \(name)", step: "get-\(name.lowercased())")
        }
        shortcuts.terminate()

        // 3. Shinsoku, launched cold, uses the profile the intent set.
        runner.launch()
        check(runner.wait(for: .runningForeground, timeout: 20), "runner-relaunch", "Shinsoku did not launch")
        require(runner.descendants(matching: .any).matching(labelContainsAny: ["Chat"]).firstMatch,
                "runner-shows-chat", timeout: 15)
        shot("runner-uses-chat")
        runner.terminate()
    }

    // MARK: Shortcuts

    /// Opens Shinsoku's App Shortcuts in the Shortcuts app and taps the tile; when `pick` is set, chooses that
    /// profile in the parameter picker.
    private func runAppShortcut(_ titles: [String], step: String, pick: String?) {
        openAppShortcuts()
        let tile = shortcuts.descendants(matching: .any).matching(labelContainsAny: titles).firstMatch
        tap(tile, "\(step)-tile")
        if let pick {
            let option = anyApp(labelEquals: [pick])
            require(option, "\(step)-picker-\(pick)", timeout: 10)
            shot("\(step)-picker")
            option.tap()
        }
    }

    /// Shortcuts › Shortcuts tab › the Shinsoku app section. Falls back to the library search.
    private func openAppShortcuts() {
        shortcuts.terminate()
        shortcuts.launch()
        check(shortcuts.wait(for: .runningForeground, timeout: 20), "shortcuts-launch", "Shortcuts did not launch")
        let tab = shortcuts.tabBars.buttons.matching(labelEquals: L.shortcutsTab).firstMatch
        if tab.waitForExistence(timeout: 5) { tab.tap() }
        // Walk back to the root (Shortcuts may restore a folder or an editor).
        for _ in 0..<4 {
            let back = shortcuts.navigationBars.buttons.element(boundBy: 0)
            guard back.exists, back.isHittable, !shortcuts.cells.matching(labelEquals: L.allShortcuts).firstMatch
                .exists else { break }
            back.tap()
        }
        let section = shortcuts.descendants(matching: .any).matching(labelContainsAny: [Self.appName]).firstMatch
        var swipes = 0
        while !section.exists, swipes < 4 {
            shortcuts.swipeUp()
            swipes += 1
        }
        if section.exists {
            tap(section, "shortcuts-app-section")
        } else {
            let search = shortcuts.searchFields.firstMatch
            if !search.exists { shortcuts.swipeDown() }
            tap(search, "shortcuts-search")
            search.typeText(Self.appName)
        }
        shot("shortcuts-app-shortcuts")
    }

    /// The intent's dialog (shown by Shortcuts or as a system snippet). Accepts a first-run permission prompt.
    private func expectDialog(_ text: String, step: String) {
        let dialog = anyApp(labelContainsAny: [text])
        let deadline = Date().addingTimeInterval(20)
        while !dialog.exists, Date() < deadline {
            let allow = [springboard, shortcuts]
                .map { $0.alerts.buttons.matching(labelEquals: L.allow).firstMatch }
                .first { $0.exists }
            if let allow {
                print("SCENE \(step): permission prompt accepted")
                allow.tap()
            }
            _ = dialog.waitForExistence(timeout: 1)
        }
        require(dialog, "\(step)-dialog", timeout: 1)
        print("SCENE \(step): \(dialog.label)")
        shot("\(step)-dialog")
        let done = [springboard, shortcuts]
            .map { $0.buttons.matching(labelEquals: L.done).firstMatch }
            .first { $0.exists }
        done?.tap()
    }

    private func anyApp(labelEquals labels: [String]) -> XCUIElement {
        let inShortcuts = shortcuts.descendants(matching: .any).matching(labelEquals: labels).firstMatch
        return inShortcuts.exists
            ? inShortcuts : springboard.descendants(matching: .any).matching(labelEquals: labels).firstMatch
    }

    private func anyApp(labelContainsAny parts: [String]) -> XCUIElement {
        let inShortcuts = shortcuts.descendants(matching: .any).matching(labelContainsAny: parts).firstMatch
        return inShortcuts.exists
            ? inShortcuts : springboard.descendants(matching: .any).matching(labelContainsAny: parts).firstMatch
    }

    // MARK: Helpers (same contract as KeyboardSceneTests)

    private func tap(_ element: XCUIElement, _ step: String, file: StaticString = #filePath, line: UInt = #line) {
        require(element, step, file: file, line: line)
        var swipes = 0
        while !element.isHittable, shortcuts.state == .runningForeground, swipes < 4 {
            shortcuts.swipeUp()
            swipes += 1
        }
        element.tap()
    }

    private func require(
        _ element: XCUIElement, _ step: String, timeout: TimeInterval = 10,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        check(element.waitForExistence(timeout: timeout), step, "\(step): element not found", file: file, line: line)
    }

    private func check(
        _ condition: Bool, _ step: String, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard !condition else { return }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "FAIL-\(step)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let foreground = [shortcuts, runner, springboard].first { $0.state == .runningForeground } ?? springboard
        let tree = XCTAttachment(string: foreground.debugDescription)
        tree.name = "FAIL-\(step)"
        tree.lifetime = .keepAlways
        add(tree)
        print("SCENE FAIL \(step): \(message)")
        XCTFail(message, file: file, line: line)
    }

    private func shot(_ name: String) {
        phase += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "PHASE-%02d-%@", phase, name)
        attachment.lifetime = .keepAlways
        add(attachment)
        print("SCENE PHASE \(attachment.name ?? name)")
    }
}

private extension XCUIElementQuery {
    func matching(labelContainsAny parts: [String]) -> XCUIElementQuery {
        matching(NSCompoundPredicate(orPredicateWithSubpredicates: parts.map {
            NSPredicate(format: "label CONTAINS %@", $0)
        }))
    }

    func matching(labelEquals labels: [String]) -> XCUIElementQuery {
        matching(NSPredicate(format: "label IN %@", labels))
    }
}
