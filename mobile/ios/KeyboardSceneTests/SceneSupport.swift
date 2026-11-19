import XCTest

/// Shared helpers of the tier-B scenes (KeyboardSceneTests, ProfileIntentSceneTests, ProfileKeyboardSceneTests).
/// Moved here unchanged from the first two scenes (profile-01 P3 scene) so the profile keyboard scene can reuse
/// the Settings, Safari-field, Shortcuts and Runner helpers.
///
/// Contract: every step attaches `PHASE-xx-<name>` (`shot`); a failed wait attaches `FAIL-<step>` (screenshot +
/// element tree of the foreground app and of SpringBoard) before failing (`check`, `require`). The script
/// `tool/ios_keyboard_scene.sh` exports both.
///
/// Language: the shared simulators run in Chinese and must not be changed. System apps are launched with
/// `-AppleLanguages (en) -AppleLocale en_US`; every system label is still matched in English and Chinese.
class SceneTestCase: XCTestCase {
    let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
    let siri = XCUIApplication(bundleIdentifier: "com.apple.siri")
    let runner = XCUIApplication()

    static let englishArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    static let keyboardName = "Shinsoku"
    static let appName = "Shinsoku"
    static let setTitles = ["Set Profile", "Set Shinsoku Profile"]
    static let getTitles = ["Get Profile", "Get Shinsoku Profile"]
    static let idleStatus = ["Ready to record"]
    /// Statuses the record path reaches after `shinsoku://dictation` (mobile_shell `_startRecording`):
    /// recording, or a stop on the way (no provider on the simulator, permission off, recorder not ready),
    /// or the warm-path note when a recording is already running.
    static let dictationStatuses = [
        "Listening", "Provider settings required", "Microphone access is off", "Recording failed",
        "already recording",
    ]
    static let pageHTML = "<meta name=viewport content='width=device-width'>"
        + "<textarea id=t aria-label='Scene field' style='width:95%;height:30vh;font-size:20px'></textarea>"
    static let pageURLString = "data:text/html;charset=utf-8,"
        + pageHTML.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!

    /// System labels, English first then Chinese (zh-Hans).
    enum L {
        static let general = ["General", "通用"]
        static let keyboard = ["Keyboard", "键盘"]
        static let keyboards = ["Keyboards", "键盘"]
        static let addNewKeyboard = ["Add New Keyboard", "添加新键盘"]
        static let allowFullAccess = ["Allow Full Access", "允许完全访问"]
        static let allow = ["Allow", "允许"]
        static let deny = ["Don", "不允许"]
        static let nextKeyboard = ["Next keyboard", "下一个键盘", "切换键盘"]
        static let address = ["Address", "地址"]
        static let addressPlaceholder = ["Search or enter website name", "搜索或输入网站名称"]
        static let open = ["Open", "打开"]
        static let allowExact = ["Allow", "允许", "OK", "好"]
        static let pastePrompt = ["Allow Paste", "pasted from", "允许粘贴", "粘贴自", "已粘贴"]
        static let back = ["Back", "返回", "Shortcuts", "快捷指令"]
        static let done = ["Done", "完成", "OK", "好"]
        static let intentAllow = ["Allow", "允许", "Always Allow", "始终允许"]
    }

    private var phase = 0

    override func setUp() {
        continueAfterFailure = false
        settings.launchArguments = Self.englishArguments
        safari.launchArguments = Self.englishArguments
        shortcuts.launchArguments = Self.englishArguments
        // Relaunch so the English launch arguments apply.
        settings.terminate()
        safari.terminate()
        shortcuts.terminate()
    }

    // MARK: Settings › Keyboards

    func openKeyboardsList() {
        settings.terminate()
        settings.launch()
        // Settings may restore a deeper page: walk back to the root.
        _ = settings.navigationBars.firstMatch.waitForExistence(timeout: 10)
        for _ in 0..<8 where !settingsItem(L.general).isHittable {
            let back = settings.navigationBars.buttons.element(boundBy: 0)
            guard back.exists else { break }
            back.tap()
        }
        navTap(L.general, "settings-general")
        navTap(L.keyboard, "settings-keyboard")
        navTap(L.keyboards, "settings-keyboards")
    }

    func keyboardCell() -> XCUIElement {
        settingsItem([Self.keyboardName], prefix: true)
    }

    /// Adds the Shinsoku keyboard unless it is already in the list.
    func ensureKeyboardAdded() {
        openKeyboardsList()
        if !keyboardCell().exists {
            navTap(L.addNewKeyboard, "add-new-keyboard", prefix: true)
            navTap([Self.keyboardName], "shinsoku-in-add-list", prefix: true)
        }
        require(keyboardCell(), "shinsoku-in-keyboards-list")
    }

    func setFullAccess(_ on: Bool) {
        settings.activate()
        if !fullAccessToggle().exists {
            openKeyboardsList()
            navTap([Self.keyboardName], "shinsoku-in-keyboards-list", prefix: true)
        }
        require(settings.descendants(matching: .any).matching(labelBeginsWith: L.allowFullAccess).firstMatch,
                "allow-full-access-switch")
        let toggle = fullAccessToggle()
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

    /// The switch if Settings exposes one, otherwise whatever element carries the label.
    private func fullAccessToggle() -> XCUIElement {
        let toggle = settings.switches.matching(labelBeginsWith: L.allowFullAccess).firstMatch
        return toggle.exists ? toggle : settingsItem(L.allowFullAccess, prefix: true)
    }

    /// A Settings row by label, whatever its element type (iOS 27 rows are not always cells).
    /// Exact label or "<label>, <value>"; with `prefix`, any label starting with one of `labels`.
    /// Skips matches inside the navigation bar (e.g. the page title 键盘 on the 键盘 page).
    func settingsItem(_ labels: [String], prefix: Bool = false) -> XCUIElement {
        let predicates = labels.flatMap { label -> [NSPredicate] in
            prefix
                ? [NSPredicate(format: "label BEGINSWITH %@", label)]
                : [NSPredicate(format: "label == %@", label), NSPredicate(format: "label BEGINSWITH %@", label + ",")]
        }
        let query = settings.descendants(matching: .any)
            .matching(NSCompoundPredicate(orPredicateWithSubpredicates: predicates))
        guard query.firstMatch.exists else { return query.firstMatch }
        let bar = settings.navigationBars.firstMatch
        let barBottom = bar.exists ? bar.frame.maxY : 0
        let count = min(query.count, 12)
        for index in 0..<count {
            let candidate = query.element(boundBy: index)
            if candidate.frame.minY >= barBottom - 1 {
                return candidate
            }
        }
        return query.firstMatch
    }

    /// Waits for a Settings row, scrolls it into view and taps it (coordinate tap at its centre as fallback).
    func navTap(
        _ labels: [String], _ step: String, prefix: Bool = false,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(10)
        while !settingsItem(labels, prefix: prefix).exists, Date() < deadline {
            _ = settingsItem(labels, prefix: prefix).waitForExistence(timeout: 1)
        }
        var item = settingsItem(labels, prefix: prefix)
        check(item.exists, step, "\(step): \(labels) not found", file: file, line: line)
        var swipes = 0
        while !item.isHittable, swipes < 6 {
            settings.swipeUp()
            swipes += 1
            item = settingsItem(labels, prefix: prefix)
        }
        if item.isHittable {
            item.tap()
        } else {
            let frame = item.frame
            settings.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
                .tap()
        }
    }

    // MARK: Safari field and keyboard

    /// Opens the Safari `data:` page and focuses its textarea with the Shinsoku keyboard up.
    func focusFieldWithShinsoku() {
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
        switchToShinsoku(retapping: area, step: "shinsoku-keyboard")
    }

    /// Cycles input modes with the globe until the Shinsoku keyboard (its Record key) is up.
    func switchToShinsoku(retapping target: XCUIElement, step: String) {
        for _ in 0..<6 {
            if key("Record").waitForExistence(timeout: 2) { return }
            let globe = globeButton()
            if globe.exists {
                globe.tap()
            } else {
                target.tap()
            }
        }
        require(key("Record"), step, timeout: 2)
    }

    /// Safari's address bar before editing: the tab bar item, iOS 27's minimized capsule (`CapsuleNavigationBar?…`,
    /// no label; shown while a page field has focus), or any element labelled Address / the search placeholder.
    func safariAddressBar() -> XCUIElement {
        safari.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN {'TabBarItemTitle', 'URL', 'Address'}"
                + " OR identifier BEGINSWITH 'CapsuleNavigationBar' OR label IN %@ OR label IN %@",
            L.address, L.addressPlaceholder
        )).firstMatch
    }

    /// Fallback when Safari ignores an externally opened data: URL: type it into the address bar
    /// (needs the system keyboard, so switch away from Shinsoku first).
    func loadPageThroughAddressBar() {
        tap(safariAddressBar(), "safari-address-bar")
        for _ in 0..<6 where key("Record").waitForExistence(timeout: 1) {
            globeButton().tap()
        }
        let input = safari.textFields.firstMatch
        require(input, "safari-address-field", timeout: 5)
        input.typeText(Self.pageURLString + "\n")
    }

    /// Best effort, never fails the scene: focuses the Safari field and taps the globe until the Shinsoku
    /// keyboard (its Record key) is gone.
    func restoreSystemKeyboard() {
        safari.activate()
        guard field().waitForExistence(timeout: 5) else {
            print("SCENE system keyboard: field not found, not restored")
            return
        }
        field().tap()
        for _ in 0..<6 where key("Record").waitForExistence(timeout: 2) {
            let globe = globeButton()
            guard globe.exists else { break }
            globe.tap()
        }
        print("SCENE system keyboard restored: \(!key("Record").exists)")
    }

    func globeButton() -> XCUIElement {
        safari.buttons.matching(
            NSPredicate(format: "label IN[c] %@ OR identifier IN[c] %@", L.nextKeyboard, L.nextKeyboard)
        ).firstMatch
    }

    func field() -> XCUIElement {
        safari.webViews.textViews.firstMatch
    }

    func fieldValue() -> String {
        (field().value as? String) ?? ""
    }

    func key(_ label: String) -> XCUIElement {
        safari.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    func statusText(_ text: String) -> XCUIElement {
        safari.staticTexts.matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    func returnLabel() -> String {
        for candidate in ["Return", "Go", "Done", "Next", "Send", "Search"] where key(candidate).exists {
            return candidate
        }
        return "Return"
    }

    // MARK: Runner

    /// Launches Shinsoku (Debug build) with scene launch arguments handled in `AppDelegate`.
    func launchRunner(_ arguments: [String], shotName: String? = nil) {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        check(app.wait(for: .runningForeground, timeout: 20), "runner-launch", "Shinsoku did not launch")
        // The seed/reset runs in didFinishLaunching; give the app a moment on screen before leaving it.
        _ = app.windows.firstMatch.waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 2)
        print("SCENE runner launched with \(arguments.first ?? "")")
        shot(shotName ?? "runner-\(arguments.first?.contains("Reset") == true ? "reset" : "seed")")
    }

    /// Opens shinsoku://dictation through the system (as another app would) and accepts the
    /// 'Open in "Shinsoku"?' confirmation if SpringBoard shows one.
    func openDeepLink(_ url: URL, step: String) {
        XCUIDevice.shared.system.open(url)
        acceptOpenConfirmation(step: step)
    }

    func acceptOpenConfirmation(step: String) {
        let open = springboard.buttons.matching(labelEquals: L.open).firstMatch
        if open.waitForExistence(timeout: 5) {
            print("SCENE \(step): open-in confirmation accepted")
            open.tap()
        } else {
            print("SCENE \(step): no open-in confirmation")
        }
    }

    /// Runner in front on Record, and the dictation path ran: a status from that path shows up. Accepts the
    /// microphone permission alert (SpringBoard) on the way; the alert itself gets no PHASE screenshot.
    func expectDictationStarted(_ runner: XCUIApplication, step: String) {
        check(runner.wait(for: .runningForeground, timeout: 20), "\(step)-foreground", "Shinsoku not in front")
        let status = runner.descendants(matching: .any).matching(labelContainsAny: Self.dictationStatuses).firstMatch
        let deadline = Date().addingTimeInterval(20)
        while !status.exists, Date() < deadline {
            let allow = [springboard, runner]
                .map { $0.alerts.buttons.matching(labelEquals: L.allowExact).firstMatch }
                .first { $0.exists }
            if let allow {
                print("SCENE \(step): microphone permission alert accepted")
                allow.tap()
            }
            _ = status.waitForExistence(timeout: 1)
        }
        require(status, "\(step)-dictation-status", timeout: 1)
        print("SCENE \(step): status \(status.label)")
        require(runner.descendants(matching: .any).matching(labelContainsAny: ["Record"]).firstMatch,
                "\(step)-record-tab", timeout: 3)
    }

    // MARK: Shortcuts (profile App Intents, P2)

    /// Opens Shinsoku's App Shortcuts in the Shortcuts app and taps the tile's icon button (the tile container
    /// itself does not react); when `pick` is set, chooses that profile in the parameter picker.
    func runAppShortcut(_ titles: [String], step: String, pick: String?) {
        openAppShortcuts(step: step)
        let tile = shortcuts.descendants(matching: .any).matching(labelEquals: titles).firstMatch
        require(tile, "\(step)-tile")
        let button = tile.buttons.firstMatch
        tap(button.exists ? button : tile, "\(step)-tile-button")
        if let pick {
            // The parameter picker: a list in Shortcuts, or a system snippet (SpringBoard / Siri).
            guard let option = waitInApps(labelEquals: [pick], timeout: 15) else {
                check(false, "\(step)-picker-\(pick)", "\(step): picker with \(pick) not shown")
                return
            }
            shot("\(step)-picker")
            option.tap()
        }
    }

    /// Shortcuts › the Shinsoku app section (on the root page, next to the library). Shortcuts restores the
    /// last page (e.g. "All Shortcuts"), so walk back by tapping (back button, else an edge swipe) until the
    /// section shows; no typing needed. The section appears once the system has indexed the app's App Shortcuts
    /// (a few seconds after install). Last resort: the library search.
    func openAppShortcuts(step: String) {
        shortcuts.terminate()
        shortcuts.launch()
        check(shortcuts.wait(for: .runningForeground, timeout: 20), "shortcuts-launch", "Shortcuts did not launch")
        let section = shortcuts.buttons.matching(labelContainsAny: [Self.appName]).firstMatch
        for attempt in 0..<6 where !section.waitForExistence(timeout: attempt == 0 ? 5 : 2) {
            let back = shortcuts.navigationBars.buttons.matching(
                NSPredicate(format: "identifier == 'BackButton' OR label IN %@", L.back)
            ).firstMatch
            if back.exists, back.isHittable {
                back.tap()
            } else if attempt % 2 == 0 {
                // Interactive pop: drag from the left edge.
                let start = shortcuts.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
                start.press(forDuration: 0.05, thenDragTo: shortcuts.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
            } else {
                shortcuts.swipeUp()
            }
        }
        if section.exists {
            tap(section, "\(step)-app-section")
        } else {
            print("SCENE \(step): Shinsoku section not found, using search")
            search(Self.appName, step: step)
        }
        shot("\(step)-app-shortcuts")
    }

    /// Focuses the search field, makes sure the system keyboard is up (not the Shinsoku keyboard, which an
    /// earlier scene may have left selected and which cannot type letters), then types.
    private func search(_ text: String, step: String) {
        let field = shortcuts.searchFields.firstMatch
        if !field.waitForExistence(timeout: 3) { shortcuts.swipeDown() }
        require(field, "\(step)-search-field")
        for _ in 0..<3 where !hasFocus(field) {
            field.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        check(hasFocus(field), "\(step)-search-focus", "\(step): search field has no keyboard focus")
        ensureSystemKeyboard(in: shortcuts, step: step)
        field.typeText(text)
    }

    private func hasFocus(_ element: XCUIElement) -> Bool {
        (element.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    /// If the Shinsoku keyboard is up (its Record key exists), taps the globe until it is gone.
    func ensureSystemKeyboard(in app: XCUIApplication, step: String) {
        let record = app.keys.matching(labelEquals: ["Record"]).firstMatch
        let globe = app.buttons.matching(labelEquals: L.nextKeyboard).firstMatch
        for _ in 0..<6 where record.waitForExistence(timeout: 1) {
            guard globe.exists else { break }
            globe.tap()
        }
        check(!record.exists, "\(step)-system-keyboard", "\(step): Shinsoku keyboard still selected")
    }

    /// The intent's dialog (shown by Shortcuts or as a system snippet). Accepts a first-run permission prompt.
    func expectDialog(_ text: String, step: String) {
        var dialog: XCUIElement?
        let deadline = Date().addingTimeInterval(20)
        while dialog == nil, Date() < deadline {
            let allow = [springboard, shortcuts]
                .map { $0.alerts.buttons.matching(labelEquals: L.intentAllow).firstMatch }
                .first { $0.exists }
            if let allow {
                print("SCENE \(step): permission prompt accepted")
                allow.tap()
            }
            dialog = waitInApps(labelContainsAny: [text], timeout: 1)
        }
        guard let dialog else {
            check(false, "\(step)-dialog", "\(step): dialog '\(text)' not shown")
            return
        }
        print("SCENE \(step): \(dialog.label)")
        shot("\(step)-dialog")
        let done = [shortcuts, springboard, siri]
            .map { $0.buttons.matching(labelEquals: L.done).firstMatch }
            .first { $0.exists }
        done?.tap()
    }

    /// Apps that can host the picker or the dialog snippet.
    private var hosts: [XCUIApplication] { [shortcuts, springboard, siri] }

    private func waitInApps(labelEquals labels: [String], timeout: TimeInterval) -> XCUIElement? {
        waitInApps(timeout: timeout) { $0.descendants(matching: .any).matching(labelEquals: labels).firstMatch }
    }

    private func waitInApps(labelContainsAny parts: [String], timeout: TimeInterval) -> XCUIElement? {
        waitInApps(timeout: timeout) { $0.descendants(matching: .any).matching(labelContainsAny: parts).firstMatch }
    }

    /// Polls every host app (an element query on one app does not see the others).
    private func waitInApps(timeout: TimeInterval, _ query: (XCUIApplication) -> XCUIElement) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for app in hosts {
                let element = query(app)
                if element.exists { return element }
            }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < deadline
        return nil
    }

    // MARK: Reporting

    /// Waits for the element; scrolls Settings or Shortcuts (whichever is in front) until it is hittable.
    func tap(_ element: XCUIElement, _ step: String, file: StaticString = #filePath, line: UInt = #line) {
        require(element, step, file: file, line: line)
        if settings.state == .runningForeground {
            var swipes = 0
            while !element.isHittable, settings.state == .runningForeground, swipes < 6 {
                settings.swipeUp()
                swipes += 1
            }
        } else if shortcuts.state == .runningForeground {
            var swipes = 0
            while !element.isHittable, shortcuts.state == .runningForeground, swipes < 4 {
                shortcuts.swipeUp()
                swipes += 1
            }
        }
        element.tap()
    }

    /// Waits for the element; on timeout attaches `FAIL-<step>` and fails (the scene stops).
    func require(
        _ element: XCUIElement, _ step: String, timeout: TimeInterval = 10,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        check(element.waitForExistence(timeout: timeout), step, "\(step): element not found", file: file, line: line)
    }

    func check(
        _ condition: Bool, _ step: String, _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard !condition else { return }
        attachFailure(step)
        print("SCENE FAIL \(step): \(message)")
        XCTFail(message, file: file, line: line)
    }

    /// `FAIL-<step>`: screenshot, element tree of the foreground app, and SpringBoard's (system snippets, alerts).
    func attachFailure(_ step: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "FAIL-\(step)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let foreground = [safari, settings, shortcuts, runner, springboard]
            .first { $0.state == .runningForeground } ?? springboard
        let trees = [("", foreground), ("-springboard", springboard)]
        for (suffix, app) in trees where suffix.isEmpty || app != foreground {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "FAIL-\(step)\(suffix)"
            tree.lifetime = .keepAlways
            add(tree)
        }
    }

    func shot(_ name: String) {
        phase += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "PHASE-%02d-%@", phase, name)
        attachment.lifetime = .keepAlways
        add(attachment)
        print("SCENE PHASE \(attachment.name ?? name)")
    }
}

extension XCUIElementQuery {
    func matching(labelBeginsWith prefixes: [String]) -> XCUIElementQuery {
        matching(NSCompoundPredicate(orPredicateWithSubpredicates: prefixes.map {
            NSPredicate(format: "label BEGINSWITH %@", $0)
        }))
    }

    func matching(labelContainsAny parts: [String]) -> XCUIElementQuery {
        matching(NSCompoundPredicate(orPredicateWithSubpredicates: parts.map {
            NSPredicate(format: "label CONTAINS %@", $0)
        }))
    }

    func matching(labelEquals labels: [String]) -> XCUIElementQuery {
        matching(NSPredicate(format: "label IN %@", labels))
    }
}
