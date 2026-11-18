import UniformTypeIdentifiers
import XCTest

/// Tier-B scene for the Shinsoku keyboard extension (docs/iterations/ios-ui-01, U2).
///
/// Run by the coordinator only, through `tool/ios_keyboard_scene.sh <UDID> <out-dir>`, once per appearance.
/// Every step attaches a screenshot named `PHASE-xx-<name>`; the script exports them as PNGs.
/// The scene is idempotent: the keyboard may already be added and Full Access may already be on.
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

    private var phase = 0
    private var pasteBannerSeen: [String] = []

    override func setUp() {
        continueAfterFailure = false
    }

    func testKeyboardScene() throws {
        // 1. Add the keyboard (skipped when it is already in the list).
        openKeyboardsList()
        if !keyboardCell().exists {
            tap(settings.descendants(matching: .any).matching(labelBeginsWith: "Add New Keyboard").firstMatch,
                "Add New Keyboard…")
            tap(settings.cells.matching(labelBeginsWith: Self.keyboardName).firstMatch, "Shinsoku in Add list")
        }
        XCTAssertTrue(keyboardCell().waitForExistence(timeout: 10), "Shinsoku not in Keyboards list")
        shot("keyboard-added")

        // 2. Full Access OFF.
        setFullAccess(false)
        shot("full-access-off")

        // 3. Field + Shinsoku keyboard, no Full Access.
        focusFieldWithShinsoku()
        XCTAssertTrue(key("Insert latest text").exists)
        checkPasteBanner("no-full-access")
        shot("no-full-access")

        // 4. Edit keys: Return, Space, Delete tap, 2 s Delete hold.
        tap(key(returnLabel()), "Return")
        tap(key("Space"), "Space")
        tap(key("Delete"), "Delete")
        shot("edit-keys")
        key("Delete").press(forDuration: 2.0)
        shot("delete-hold")
        XCTAssertEqual(fieldValue(), "", "Delete hold should clear the field")

        // 5. Full Access ON, Shinsoku text with the marker → Insert.
        setFullAccess(true)
        shot("full-access-on")
        publishLatest(Self.latestText)
        focusFieldWithShinsoku()
        checkPasteBanner("latest-ready")
        XCTAssertTrue(key("Insert latest text").waitForExistence(timeout: 5), "Insert key not labelled for latest")
        XCTAssertTrue(statusText("Latest text ready").exists, "status should say Latest text ready")
        shot("latest-ready")
        tap(key("Insert latest text"), "Insert")
        checkPasteBanner("after-insert")
        XCTAssertTrue(statusText("Inserted").waitForExistence(timeout: 5))
        shot("inserted")
        XCTAssertTrue(fieldValue().contains(Self.latestText), "field: \(fieldValue())")

        // 6. Plain text without the marker → Paste.
        UIPasteboard.general.string = Self.plainText
        focusFieldWithShinsoku()
        checkPasteBanner("paste")
        XCTAssertTrue(key("Paste").waitForExistence(timeout: 5), "Insert key should read Paste without marker")
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
        for _ in 0..<8 where !settings.cells.matching(labelBeginsWith: "General").firstMatch.isHittable {
            let back = settings.navigationBars.buttons.element(boundBy: 0)
            guard back.exists else { break }
            back.tap()
        }
        tapCell("General")
        tapCell("Keyboard")
        tapCell("Keyboards")
    }

    private func keyboardCell() -> XCUIElement {
        settings.cells.matching(labelBeginsWith: Self.keyboardName).firstMatch
    }

    private func setFullAccess(_ on: Bool) {
        settings.activate()
        if !settings.switches.matching(labelBeginsWith: "Allow Full Access").firstMatch.exists {
            openKeyboardsList()
            tap(keyboardCell(), "Shinsoku in Keyboards list")
        }
        let toggle = settings.switches.matching(labelBeginsWith: "Allow Full Access").firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Allow Full Access switch missing")
        if isOn(toggle) != on {
            toggle.tap()
            if on {
                let allow = settings.alerts.buttons["Allow"]
                if allow.waitForExistence(timeout: 5) {
                    allow.tap()
                }
            }
            if isOn(toggle) != on {
                // Some iOS versions only toggle when the switch itself (right edge) is tapped.
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
                if on, settings.alerts.buttons["Allow"].waitForExistence(timeout: 5) {
                    settings.alerts.buttons["Allow"].tap()
                }
            }
        }
        XCTAssertEqual(isOn(toggle), on, "Allow Full Access should be \(on)")
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    private func tapCell(_ label: String) {
        let cell = settings.cells.matching(labelBeginsWith: label).firstMatch
        tap(cell, label)
    }

    // MARK: Field and keyboard

    private func focusFieldWithShinsoku() {
        safari.activate()
        if !field().waitForExistence(timeout: 2) {
            safari.open(URL(string: Self.pageURLString)!)
        }
        if !field().waitForExistence(timeout: 15) {
            loadPageThroughAddressBar()
        }
        let area = field()
        XCTAssertTrue(area.waitForExistence(timeout: 15), "textarea did not load in Safari")
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
        XCTAssertTrue(key("Record").exists, "Shinsoku keyboard did not appear")
    }

    /// Fallback when Safari ignores an externally opened data: URL: type it into the address bar
    /// (needs the system keyboard, so switch away from Shinsoku first).
    private func loadPageThroughAddressBar() {
        let address = safari.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN {'TabBarItemTitle', 'URL', 'Address'} OR label ==[c] 'Address'"
        )).firstMatch
        tap(address, "Safari address bar")
        for _ in 0..<6 where key("Record").waitForExistence(timeout: 1) {
            globeButton().tap()
        }
        let input = safari.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5), "Safari address field missing")
        input.typeText(Self.pageURLString + "\n")
    }

    private func globeButton() -> XCUIElement {
        safari.buttons.matching(
            NSPredicate(format: "label ==[c] 'Next keyboard' OR identifier ==[c] 'Next keyboard'")
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
        let prompt = NSPredicate(format: "label CONTAINS[c] 'Allow Paste' OR label CONTAINS[c] 'pasted from'")
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
        let deny = safari.alerts.buttons.matching(labelBeginsWith: "Don").firstMatch
        if deny.exists { deny.tap() }
    }

    // MARK: Helpers

    /// Waits for the element; in Settings, scrolls until it is hittable.
    private func tap(_ element: XCUIElement, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(name) not found", file: file, line: line)
        var swipes = 0
        while !element.isHittable, settings.state == .runningForeground, swipes < 6 {
            settings.swipeUp()
            swipes += 1
        }
        element.tap()
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
    func matching(labelBeginsWith prefix: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
    }
}
