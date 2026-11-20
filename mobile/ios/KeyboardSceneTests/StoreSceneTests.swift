import XCTest

/// Tier-B scene for the App Store keyboard screenshot (release-01 R3): the Shinsoku keyboard in a neutral system
/// app, the locale's dictated text inserted. No Safari `data:` page.
///
/// Run by the coordinator only (iPhone 17, clean status bar):
///   SCENE_TEST=KeyboardSceneTests/StoreSceneTests SCENE_STATUS_BAR=clean \
///     tool/ios_keyboard_scene.sh <UDID> build/store/keyboard
/// Host app, first one installed on the simulator (checked under SIMULATOR_ROOT/Applications before launching):
///   1. Messages (com.apple.MobileSMS): the first existing thread (simulator fixture, +1 555 numbers), the text in
///      its message field; never sent, cleared afterwards.
///   2. Safari's start page: the address/search field (start page behind it, no URL loaded).
/// Neither installed → the test is skipped with a message (XCTSkip), nothing fails. Notes is not on the shared
/// iPhone 17 runtime (2026-11-20).
/// Locales: **zh-Hans and zh-Hant only** (coordinator, 2026-11-20). The keyboard extension follows the system
/// language and the shared simulators run in Chinese, which must never be changed (AGENTS.md).
/// `TEST_RUNNER_STORE_LOCALES=zh-Hans` limits the run. Per locale:
///   PHASE-xx-store-<locale>-app       Shinsoku launched in the locale, the text seeded as the latest
///   PHASE-xx-store-<locale>-ready     the field focused, the Shinsoku keyboard up ("Latest text ready")
///   PHASE-xx-store-<locale>-inserted  after Insert: the text in the field (the store frame)
/// tool/store_frames.py picks `light/PHASE-*-store-<locale>-inserted.png`.
/// Messages: the inserted text is deleted (system keyboard) and the thread left (best effort, SCENE line
/// `thread-cleared`). No contacts, keys or real names: the text is the store fixture text
/// (mobile/test/host_review/store_fixtures.dart).
final class StoreSceneTests: SceneTestCase {
    private let messages = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")

    private enum Host: String {
        case messages, safari
    }

    private struct Store {
        let locale: String
        let language: String
        let region: String
        let text: String
    }

    private static let all: [Store] = [
        Store(locale: "zh-Hans", language: "zh-Hans", region: "zh_SG",
              text: "跟大家同步一下：发布改到周四，所以我们周三下午之前要把更新说明写完。"),
        Store(locale: "zh-Hant", language: "zh-Hant", region: "zh_TW",
              text: "跟大家同步一下：發布改到週四，所以我們週三下午之前要把更新說明寫完。"),
    ]

    /// Messages labels (English, zh-Hans, zh-Hant).
    private enum M {
        static let onboarding = ["Continue", "继续", "繼續", "Not Now", "以后", "稍後", "OK", "好"]
        static let body = ["Message", "iMessage", "Text Message", "信息", "訊息", "短信", "簡訊", "文本信息", "文字訊息"]
    }

    /// Whether the app bundle is on the simulator runtime (launching a missing app fails the test outright).
    private static func installed(_ appFolder: String) -> Bool {
        let env = ProcessInfo.processInfo.environment
        let roots = [env["SIMULATOR_ROOT"], env["IPHONE_SIMULATOR_ROOT"], ""].compactMap { $0 }
        return roots.contains { FileManager.default.fileExists(atPath: "\($0)/Applications/\(appFolder)") }
    }

    func testStoreKeyboardScene() throws {
        let wanted = (ProcessInfo.processInfo.environment["STORE_LOCALES"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let stores = wanted.isEmpty ? Self.all : Self.all.filter { wanted.contains($0.locale) }
        check(!stores.isEmpty, "store-locales", "no known locale in STORE_LOCALES=\(wanted) (zh-Hans, zh-Hant)")

        let hasMessages = Self.installed("MobileSMS.app")
        // Without SIMULATOR_ROOT nothing can be checked; Safari is then assumed (the other scenes use it).
        let canCheck = ProcessInfo.processInfo.environment["SIMULATOR_ROOT"] != nil
            || ProcessInfo.processInfo.environment["IPHONE_SIMULATOR_ROOT"] != nil
        let hasSafari = Self.installed("MobileSafari.app") || !canCheck
        print("SCENE store-host: SIMULATOR_ROOT available=\(canCheck)")
        print("SCENE store-host: Messages installed=\(hasMessages), Safari installed=\(hasSafari)")
        guard hasMessages || hasSafari else {
            throw XCTSkip("Neither Messages (com.apple.MobileSMS) nor Safari is installed on this simulator; "
                + "no host app for the keyboard frame")
        }
        let host: Host = hasMessages ? .messages : .safari
        print("SCENE store-host: using \(host.rawValue)")

        ensureKeyboardAdded()
        setFullAccess(true)
        addTeardownBlock { [unowned self] in
            self.runner.terminate()
            self.restoreKeyboard(in: host == .messages ? self.messages : self.safari)
            self.messages.terminate()
            self.safari.terminate()
            self.safari.launchArguments = Self.englishArguments
        }

        for store in stores {
            let arguments = ["-AppleLanguages", "(\(store.language))", "-AppleLocale", store.region]
            // The locale's text becomes the latest, through the app's real publish path.
            runner.terminate()
            launchRunner(["-ShinsokuSceneResetLatest", "YES", "-ShinsokuSceneSeedLatest", store.text] + arguments,
                         shotName: "store-\(store.locale)-app")

            let app = host == .messages ? messages : safari
            let field = host == .messages
                ? messageBody(arguments: arguments, step: store.locale)
                : safariStartField(arguments: arguments, step: store.locale)
            switchToShinsoku(in: app, field, step: "\(store.locale)-shinsoku-keyboard")
            print("SCENE keyboard-language \(store.locale): Record key '\(hostKey(app, "Record").label)'")
            require(hostStatus(app, "Latest text ready"), "\(store.locale)-latest-ready", timeout: 5)
            shot("store-\(store.locale)-ready")

            tap(hostKey(app, "Insert latest text"), "\(store.locale)-insert")
            require(hostStatus(app, "Inserted"), "\(store.locale)-inserted", timeout: 5)
            Thread.sleep(forTimeInterval: 1)  // caret and layout settle
            shot("store-\(store.locale)-inserted")
            let value = (field.value as? String) ?? ""
            print("SCENE inserted \(store.locale): '\(value)'")
            check(value.contains(store.text), "\(store.locale)-field-text", "field: \(value)")
            if host == .messages { leaveThread(field, step: store.locale) }
        }
    }

    // MARK: Messages

    override var extraFailureApps: [XCUIApplication] { [messages] }

    /// Messages in the locale, the first existing thread (the simulator's fixture threads, +1 555 numbers),
    /// its message input focused. iOS 27's list has no compose button in the tree (round 4 run).
    private func messageBody(arguments: [String], step: String) -> XCUIElement {
        messages.terminate()
        messages.launchArguments = arguments
        messages.launch()
        let thread = messages.cells.firstMatch
        for _ in 0..<4 where !thread.waitForExistence(timeout: 3) {
            let next = messages.buttons.matching(labelEquals: M.onboarding).firstMatch
            guard next.exists else { break }
            next.tap()
        }
        if thread.exists {
            thread.tap()
        } else {
            // The list rows may not be exposed as cells: tap the first row (below the large title).
            print("SCENE messages: no cell in the tree, tapping the first row by coordinate")
            messages.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22)).tap()
        }
        let body = messages.descendants(matching: .any).matching(NSPredicate(
            format: "(elementType == %d OR elementType == %d) AND (identifier IN[c] %@ OR label IN %@ "
                + "OR placeholderValue IN %@)",
            XCUIElement.ElementType.textView.rawValue, XCUIElement.ElementType.textField.rawValue,
            ["messageBodyField", "messageBodyView", "MessageEntryView", "entryView"], M.body, M.body
        )).firstMatch
        if !body.waitForExistence(timeout: 8) {
            // Fall back to any text input in the conversation, then to the entry bar's position.
            print("SCENE messages tree:\n\(messages.debugDescription)")
            let any = messages.textViews.firstMatch.exists ? messages.textViews.firstMatch : messages.textFields.firstMatch
            if any.exists {
                any.tap()
                return any
            }
            messages.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.93)).tap()
            require(messages.textViews.firstMatch, "\(step)-message-body", timeout: 5)
            return messages.textViews.firstMatch
        }
        body.tap()
        return body
    }

    /// Best effort, never fails: clear the inserted text (nothing is sent) and leave the thread.
    private func leaveThread(_ field: XCUIElement, step: String) {
        let value = (field.value as? String) ?? ""
        if !value.isEmpty {
            restoreKeyboard(in: messages)
            field.tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count + 2))
        }
        let left = ((field.value as? String) ?? "").isEmpty || (field.value as? String) == field.placeholderValue
        print("SCENE thread-cleared \(step): \(left)")
        messages.navigationBars.buttons.element(boundBy: 0).tap()
    }

    // MARK: Safari start page (fallback)

    /// Safari in the locale, a new start page, its address/search field focused (nothing loaded, no URL shown).
    private func safariStartField(arguments: [String], step: String) -> XCUIElement {
        safari.terminate()
        safari.launchArguments = arguments
        safari.launch()
        tap(safariAddressBar(), "\(step)-safari-address-bar")
        let input = safari.textFields.firstMatch
        require(input, "\(step)-safari-search-field", timeout: 5)
        // Clear a restored URL so only the start page shows.
        let clear = safari.buttons.matching(NSPredicate(
            format: "label IN %@ OR identifier IN[c] %@", ["Clear text", "清除文本", "清除文字"], ["ClearTextButton"]
        )).firstMatch
        if clear.exists { clear.tap() }
        return input
    }

    // MARK: Keyboard in the host app

    private func switchToShinsoku(in app: XCUIApplication, _ target: XCUIElement, step: String) {
        for _ in 0..<6 {
            if hostKey(app, "Record").waitForExistence(timeout: 2) { return }
            let globe = hostGlobe(app)
            if globe.exists { globe.tap() } else { target.tap() }
        }
        require(hostKey(app, "Record"), step, timeout: 2)
    }

    /// Best effort: put the system keyboard back for the next scene.
    private func restoreKeyboard(in app: XCUIApplication) {
        guard app.state == .runningForeground else { return }
        for _ in 0..<6 where hostKey(app, "Record").waitForExistence(timeout: 2) {
            let globe = hostGlobe(app)
            guard globe.exists else { break }
            globe.tap()
        }
        print("SCENE system keyboard restored: \(!hostKey(app, "Record").exists)")
    }

    private func hostGlobe(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label IN[c] %@ OR identifier IN[c] %@", L.nextKeyboard, L.nextKeyboard)
        ).firstMatch
    }

    private func hostKey(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(labelEquals: Self.variants(label)).firstMatch
    }

    private func hostStatus(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.staticTexts.matching(labelEquals: Self.variants(text)).firstMatch
    }
}
