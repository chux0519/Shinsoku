import XCTest

/// Tier-B scene for the App Store keyboard screenshot (release-01 R3): the Shinsoku keyboard in a new note in
/// Notes, the locale's dictated text inserted. Notes, not a Safari page: no `data:` URL in the frame.
///
/// Run by the coordinator only (iPhone 17, clean status bar):
///   SCENE_TEST=KeyboardSceneTests/StoreSceneTests SCENE_STATUS_BAR=clean \
///     tool/ios_keyboard_scene.sh <UDID> build/store/keyboard
/// Locales: **zh-Hans and zh-Hant only** (coordinator, 2026-11-20). The keyboard extension follows the system
/// language and the shared simulators run in Chinese, which must never be changed (AGENTS.md); other store
/// locales ship without a keyboard frame. `TEST_RUNNER_STORE_LOCALES=zh-Hans` limits the run.
/// Per locale:
///   PHASE-xx-store-<locale>-app       Shinsoku launched in the locale, the text seeded as the latest
///   PHASE-xx-store-<locale>-ready     a new note, the Shinsoku keyboard up ("Latest text ready")
///   PHASE-xx-store-<locale>-inserted  after Insert: the text in the note (the store frame)
/// tool/store_frames.py picks `light/PHASE-*-store-<locale>-inserted.png`.
/// The note is deleted afterwards (best effort; SCENE line `note-deleted`).
/// No keys and no real names: the text is the store fixture text (mobile/test/host_review/store_fixtures.dart).
final class StoreSceneTests: SceneTestCase {
    private let notes = XCUIApplication(bundleIdentifier: "com.apple.mobilenotes")

    private struct Store {
        let locale: String
        let language: String
        let region: String
        let title: String
        let body: String
        /// Title line + body: Notes shows the first line as the note's title.
        var text: String { title + "\n" + body }
    }

    private static let all: [Store] = [
        Store(locale: "zh-Hans", language: "zh-Hans", region: "zh_SG", title: "周四发布",
              body: "跟大家同步一下：发布改到周四，所以我们周三下午之前要把更新说明写完。"),
        Store(locale: "zh-Hant", language: "zh-Hant", region: "zh_TW", title: "週四發布",
              body: "跟大家同步一下：發布改到週四，所以我們週三下午之前要把更新說明寫完。"),
    ]

    /// Notes labels (English, zh-Hans, zh-Hant).
    private enum N {
        static let compose = ["New Note", "Compose", "新建备忘录", "新增備忘錄", "撰写", "撰寫"]
        static let onboarding = ["Continue", "继续", "繼續", "Not Now", "以后", "稍後", "Done", "完成"]
        static let delete = ["Delete", "删除", "刪除"]
        static let back = ["Notes", "备忘录", "備忘錄", "Back", "返回"]
    }

    func testStoreKeyboardScene() throws {
        let wanted = (ProcessInfo.processInfo.environment["STORE_LOCALES"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let stores = wanted.isEmpty ? Self.all : Self.all.filter { wanted.contains($0.locale) }
        check(!stores.isEmpty, "store-locales", "no known locale in STORE_LOCALES=\(wanted) (zh-Hans, zh-Hant)")

        ensureKeyboardAdded()
        setFullAccess(true)
        addTeardownBlock { [unowned self] in
            self.runner.terminate()
            self.restoreNotesKeyboard()
            self.notes.terminate()
        }

        for store in stores {
            let arguments = ["-AppleLanguages", "(\(store.language))", "-AppleLocale", store.region]
            // The locale's text becomes the latest, through the app's real publish path.
            runner.terminate()
            launchRunner(["-ShinsokuSceneResetLatest", "YES", "-ShinsokuSceneSeedLatest", store.text] + arguments,
                         shotName: "store-\(store.locale)-app")

            notes.terminate()
            notes.launchArguments = arguments
            notes.launch()
            let body = newNote(step: store.locale)
            switchNotesToShinsoku(body, step: "\(store.locale)-shinsoku-keyboard")
            print("SCENE keyboard-language \(store.locale): Record key '\(noteKey("Record").label)'")
            require(noteStatus("Latest text ready"), "\(store.locale)-latest-ready", timeout: 5)
            shot("store-\(store.locale)-ready")

            tap(noteKey("Insert latest text"), "\(store.locale)-insert")
            require(noteStatus("Inserted"), "\(store.locale)-inserted", timeout: 5)
            Thread.sleep(forTimeInterval: 1)  // caret and layout settle
            shot("store-\(store.locale)-inserted")
            let value = (body.value as? String) ?? ""
            check(value.contains(store.body), "\(store.locale)-note-text", "note: \(value)")
            deleteCurrentNote(step: store.locale)
        }
    }

    // MARK: Notes

    /// Dismisses first-run sheets, creates a note and returns its text view (focused, keyboard up).
    private func newNote(step: String) -> XCUIElement {
        let compose = notes.buttons.matching(labelEquals: N.compose).firstMatch
        for _ in 0..<4 where !compose.waitForExistence(timeout: 3) {
            let next = notes.buttons.matching(labelEquals: N.onboarding).firstMatch
            guard next.exists else { break }
            next.tap()
        }
        if compose.exists {
            compose.tap()
        } else {
            // Fallback: the compose button is the last toolbar button.
            let last = notes.toolbars.buttons.element(boundBy: max(0, notes.toolbars.buttons.count - 1))
            require(last, "\(step)-notes-compose", timeout: 5)
            last.tap()
        }
        let body = notes.textViews.firstMatch
        require(body, "\(step)-note-body", timeout: 10)
        if !body.hasKeyboardFocusCompat { body.tap() }
        return body
    }

    /// Cycles input modes with the globe until the Shinsoku keyboard (its Record key) is up.
    private func switchNotesToShinsoku(_ target: XCUIElement, step: String) {
        for _ in 0..<6 {
            if noteKey("Record").waitForExistence(timeout: 2) { return }
            let globe = notesGlobe()
            if globe.exists { globe.tap() } else { target.tap() }
        }
        require(noteKey("Record"), step, timeout: 2)
    }

    /// Best effort, never fails: swipe the newest note away in the list.
    private func deleteCurrentNote(step: String) {
        let back = notes.navigationBars.buttons.matching(labelEquals: N.back).firstMatch
        if back.waitForExistence(timeout: 3) {
            back.tap()
        } else {
            notes.navigationBars.buttons.element(boundBy: 0).tap()
        }
        let first = notes.cells.firstMatch
        guard first.waitForExistence(timeout: 5) else {
            print("SCENE note-deleted \(step): false (list not found)")
            return
        }
        first.swipeLeft()
        let delete = notes.buttons.matching(labelEquals: N.delete).firstMatch
        if delete.waitForExistence(timeout: 3) { delete.tap() }
        print("SCENE note-deleted \(step): \(delete.exists ? "unknown" : "true")")
    }

    /// Best effort: put the system keyboard back for the next scene.
    private func restoreNotesKeyboard() {
        guard notes.state == .runningForeground else { return }
        for _ in 0..<6 where noteKey("Record").waitForExistence(timeout: 2) {
            let globe = notesGlobe()
            guard globe.exists else { break }
            globe.tap()
        }
        print("SCENE system keyboard restored (notes): \(!noteKey("Record").exists)")
    }

    private func notesGlobe() -> XCUIElement {
        notes.buttons.matching(
            NSPredicate(format: "label IN[c] %@ OR identifier IN[c] %@", L.nextKeyboard, L.nextKeyboard)
        ).firstMatch
    }

    private func noteKey(_ label: String) -> XCUIElement {
        notes.descendants(matching: .any).matching(labelEquals: Self.variants(label)).firstMatch
    }

    private func noteStatus(_ text: String) -> XCUIElement {
        notes.staticTexts.matching(labelEquals: Self.variants(text)).firstMatch
    }
}

private extension XCUIElement {
    /// `hasKeyboardFocus` via KVC (not public API on every SDK).
    var hasKeyboardFocusCompat: Bool {
        (value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }
}
