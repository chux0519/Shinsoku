import UniformTypeIdentifiers
import XCTest

/// Tier-B scene for the Shinsoku keyboard extension (docs/iterations/ios-ui-01, U2).
///
/// Run by the coordinator only, through `tool/ios_keyboard_scene.sh <UDID> <out-dir>`, once per appearance.
/// Every step attaches a screenshot named `PHASE-xx-<name>`; the script exports them as PNGs.
/// The scene is idempotent: the keyboard may already be added and Full Access may already be on.
///
/// Language: the shared simulators run in Chinese and must not be changed. Settings and Safari are launched with
/// `-AppleLanguages (en) -AppleLocale en_US`; every system label is still matched in English and Chinese in case
/// an app ignores that. On a failed wait the scene attaches `FAIL-<step>` before asserting.
///
/// Text field host: a Safari `data:` page with a textarea. The app has no free text field that is reachable
/// without recording a draft or editing persisted provider settings.
final class KeyboardSceneTests: XCTestCase {
    private let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    private let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private static let keyboardName = "Shinsoku"
    private static let markerType = "net.potafree.shinsoku.latest"
    private static let latestText = "Shinsoku scene latest 42"
    private static let plainText = "plain clipboard text"
    private static let pageHTML = "<meta name=viewport content='width=device-width'>"
        + "<textarea id=t aria-label='Scene field' style='width:95%;height:30vh;font-size:20px'></textarea>"
    private static let pageURLString = "data:text/html;charset=utf-8,"
        + pageHTML.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!

    /// System labels, English first then Chinese (zh-Hans).
    private enum L {
        static let general = ["General", "通用"]
        static let keyboard = ["Keyboard", "键盘"]
        static let keyboards = ["Keyboards", "键盘"]
        static let addNewKeyboard = ["Add New Keyboard", "添加新键盘"]
        static let allowFullAccess = ["Allow Full Access", "允许完全访问"]
        static let allow = ["Allow", "允许"]
        static let deny = ["Don", "不允许"]
        static let nextKeyboard = ["Next keyboard", "下一个键盘", "切换键盘"]
        static let address = ["Address", "地址"]
        static let pastePrompt = ["Allow Paste", "pasted from", "允许粘贴", "粘贴自", "已粘贴"]
    }

    private static let englishArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]

    private var phase = 0
    private var pasteBannerSeen: [String] = []

    override func setUp() {
        continueAfterFailure = false
        settings.launchArguments = Self.englishArguments
        safari.launchArguments = Self.englishArguments
        // Relaunch both so the English launch arguments apply.
        settings.terminate()
        safari.terminate()
    }

    func testKeyboardScene() throws {
        // 1. Add the keyboard (skipped when it is already in the list).
        openKeyboardsList()
        if !keyboardCell().exists {
            tap(settings.descendants(matching: .any).matching(labelBeginsWith: L.addNewKeyboard).firstMatch,
                "add-new-keyboard")
            tap(settings.cells.matching(labelBeginsWith: [Self.keyboardName]).firstMatch, "shinsoku-in-add-list")
        }
        require(keyboardCell(), "shinsoku-in-keyboards-list")
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

        // 5. Full Access ON, Shinsoku text with the marker → Insert.
        setFullAccess(true)
        shot("full-access-on")
        publishLatest(Self.latestText)
        focusFieldWithShinsoku()
        checkPasteBanner("latest-ready")
        require(key("Insert latest text"), "insert-key-latest", timeout: 5)
        require(statusText("Latest text ready"), "status-latest-ready", timeout: 3)
        shot("latest-ready")
        tap(key("Insert latest text"), "insert-key")
        checkPasteBanner("after-insert")
        require(statusText("Inserted"), "status-inserted", timeout: 5)
        shot("inserted")
        check(fieldValue().contains(Self.latestText), "field-contains-latest", "field: \(fieldValue())")

        // 6. Plain text without the marker → Paste.
        UIPasteboard.general.string = Self.plainText
        focusFieldWithShinsoku()
        checkPasteBanner("paste")
        require(key("Paste"), "paste-key", timeout: 5)
        shot("paste")

        let summary = pasteBannerSeen.isEmpty ? "none" : pasteBannerSeen.joined(separator: ", ")
        print("SCENE paste-banner phases: \(summary)")
        XCTContext.runActivity(named: "paste banner phases: \(summary)") { _ in }
    }

    // MARK: Settings

    private func openKeyboardsList() {
        settings.terminate()
        settings.launch()
        // Settings may restore a deeper page: walk back to the root.
        _ = settings.cells.firstMatch.waitForExistence(timeout: 10)
        for _ in 0..<8 where !settings.cells.matching(labelBeginsWith: L.general).firstMatch.isHittable {
            let back = settings.navigationBars.buttons.element(boundBy: 0)
            guard back.exists else { break }
            back.tap()
        }
        tapCell(L.general, "settings-general")
        tapCell(L.keyboard, "settings-keyboard")
        tapCell(L.keyboards, "settings-keyboards")
    }

    private func keyboardCell() -> XCUIElement {
        settings.cells.matching(labelBeginsWith: [Self.keyboardName]).firstMatch
    }

    private func setFullAccess(_ on: Bool) {
        settings.activate()
        if !settings.switches.matching(labelBeginsWith: L.allowFullAccess).firstMatch.exists {
            openKeyboardsList()
            tap(keyboardCell(), "shinsoku-in-keyboards-list")
        }
        let toggle = settings.switches.matching(labelBeginsWith: L.allowFullAccess).firstMatch
        require(toggle, "allow-full-access-switch")
        let allow = settings.alerts.buttons.matching(labelEquals: L.allow).firstMatch
        if isOn(toggle) != on {
            toggle.tap()
            if on, allow.waitForExistence(timeout: 5) {
                allow.tap()
            }
            if isOn(toggle) != on {
                // Some iOS versions only toggle when the switch itself (right edge) is tapped.
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
                if on, allow.waitForExistence(timeout: 5) {
                    allow.tap()
                }
            }
        }
        check(isOn(toggle) == on, "full-access-\(on ? "on" : "off")", "Allow Full Access should be \(on)")
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    private func tapCell(_ labels: [String], _ step: String) {
        tap(settings.cells.matching(labelBeginsWith: labels).firstMatch, step)
    }

    // MARK: Field and keyboard

    private func focusFieldWithShinsoku() {
        if safari.state == .notRunning {
            safari.launch()
        } else {
            safari.activate()
        }
        if !field().waitForExistence(timeout: 2) {
            safari.open(URL(string: Self.pageURLString)!)
        }
        if !field().waitForExistence(timeout: 15) {
            loadPageThroughAddressBar()
        }
        let area = field()
        require(area, "safari-textarea", timeout: 15)
        area.tap()
        // Cycle input modes until the Shinsoku keyboard (its Record key) is up.
        for _ in 0..<6 {
            if key("Record").waitForExistence(timeout: 2) { return }
            let globe = globeButton()
            if globe.exists {
                globe.tap()
            } else {
                area.tap()
            }
        }
        require(key("Record"), "shinsoku-keyboard", timeout: 2)
    }

    /// Fallback when Safari ignores an externally opened data: URL: type it into the address bar
    /// (needs the system keyboard, so switch away from Shinsoku first).
    private func loadPageThroughAddressBar() {
        let address = safari.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN {'TabBarItemTitle', 'URL', 'Address'} OR label IN %@", L.address
        )).firstMatch
        tap(address, "safari-address-bar")
        for _ in 0..<6 where key("Record").waitForExistence(timeout: 1) {
            globeButton().tap()
        }
        let input = safari.textFields.firstMatch
        require(input, "safari-address-field", timeout: 5)
        input.typeText(Self.pageURLString + "\n")
    }

    private func globeButton() -> XCUIElement {
        safari.buttons.matching(
            NSPredicate(format: "label IN[c] %@ OR identifier IN[c] %@", L.nextKeyboard, L.nextKeyboard)
        ).firstMatch
    }

    private func field() -> XCUIElement {
        safari.webViews.textViews.firstMatch
    }

    private func fieldValue() -> String {
        (field().value as? String) ?? ""
    }

    private func key(_ label: String) -> XCUIElement {
        safari.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func statusText(_ text: String) -> XCUIElement {
        safari.staticTexts.matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    private func returnLabel() -> String {
        for candidate in ["Return", "Go", "Done", "Next", "Send", "Search"] where key(candidate).exists {
            return candidate
        }
        return "Return"
    }

    // MARK: Pasteboard

    /// Same item shape as `AppDelegate.publishLatestText`.
    private func publishLatest(_ text: String) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: text, Self.markerType: Data()]],
            options: [.localOnly: true]
        )
    }

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

    // MARK: Helpers

    /// Waits for the element; in Settings, scrolls until it is hittable.
    private func tap(_ element: XCUIElement, _ step: String, file: StaticString = #filePath, line: UInt = #line) {
        require(element, step, file: file, line: line)
        var swipes = 0
        while !element.isHittable, settings.state == .runningForeground, swipes < 6 {
            settings.swipeUp()
            swipes += 1
        }
        element.tap()
    }

    /// Waits for the element; on timeout attaches `FAIL-<step>` and fails (the scene stops).
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
    func matching(labelBeginsWith prefixes: [String]) -> XCUIElementQuery {
        matching(NSCompoundPredicate(orPredicateWithSubpredicates: prefixes.map {
            NSPredicate(format: "label BEGINSWITH %@", $0)
        }))
    }

    func matching(labelEquals labels: [String]) -> XCUIElementQuery {
        matching(NSPredicate(format: "label IN %@", labels))
    }
}
