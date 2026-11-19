import XCTest

/// Tier-B scene for live-01 (live transcript, the transcript is the text field), T3.
///
/// Run by the coordinator only: `SCENE_TEST=KeyboardSceneTests/LiveSceneTests tool/ios_keyboard_scene.sh <UDID>
/// <out-dir>`. Every step attaches `PHASE-xx-<name>`; a failed wait attaches `FAIL-<step>` (screenshot + element
/// trees). Helpers live in `SceneSupport.swift`. No Flutter page is scrolled (review rule M07): everything used
/// here is on Record's first screen.
///
/// No microphone and no keys: the Runner (Debug) is launched with `-ShinsokuSceneLiveFixture <name>`, so a
/// recording replays T1's streaming fixture (`mobile/test/fixtures/streaming/<name>.json`) through the real
/// transcription service, one provider message every 800 ms, the rest at Stop. `-ShinsokuSceneResetSelection
/// YES` puts the active profile back to the default, Dictation, whose commit suffix is a space.
///
/// Checks (docs/design/state_invariants.md):
/// 1. `bailian_basic`: committed text shows while listening and only grows (L1, two reads ~1 s apart); Stop →
///    the final text; edit in place + Done → "Saved. Insert it from the keyboard."; the Shinsoku keyboard's
///    Insert in Safari puts the edited text + the profile's suffix (draft stays plain, suffix when published).
/// 2. `soniox_dropped`: the connection drops while listening → "Recording stopped" and the recognised words
///    (committed + pending) stay in the text area (L2/L3).
final class LiveSceneTests: SceneTestCase {
    private enum Fixture {
        static let basic = "bailian_basic"
        /// The first sentence: committed (`sentence_end`) after the third message.
        static let basicCommitted = "示例第一句。"
        static let basicFinal = "示例第一句。Example two."
        static let dropped = "soniox_dropped"
        static let droppedHeard = "Example one"
    }

    private static let edit = " EDITED"
    /// Dictation's commit suffix (the default profile after the selection reset).
    private static let suffix = " "
    private static let transcribed = "Recording transcribed"
    private static let saved = "Saved. Insert it from the keyboard."
    private static let stopped = "Recording stopped"
    private static let recordAgain = "Record again"

    func testLiveScene() throws {
        // 0. Keyboard added, Full Access on (Insert reads the App Group).
        ensureKeyboardAdded()
        setFullAccess(true)
        shot("full-access-on")
        addTeardownBlock { [unowned self] in
            self.runner.terminate()
            self.restoreSystemKeyboard()
        }

        // 1. Live words (L1).
        launchFixture(Fixture.basic)
        tap(runnerButton("Start recording"), "record-start")
        let area = transcriptArea()
        require(area, "transcript-area")
        let first = waitForValue(area, containing: Fixture.basicCommitted, step: "live-committed", timeout: 15)
        shot("live-1")
        Thread.sleep(forTimeInterval: 1)
        let second = value(of: area)
        shot("live-2")
        print("SCENE live: '\(first)' → '\(second)'")
        check(first.hasPrefix(Fixture.basicCommitted), "live-committed-prefix",
              "L1: committed text '\(Fixture.basicCommitted)' should lead the area: '\(first)'")
        check(second.hasPrefix(Fixture.basicCommitted) && second.count >= first.count, "live-grows",
              "L1: the committed text should only grow: '\(first)' → '\(second)'")

        // 2. Stop → the final text (L2).
        tap(runnerButton("Stop recording"), "record-stop")
        require(runnerText(Self.transcribed), "status-transcribed", timeout: 20)
        let final = waitForValue(area, containing: Fixture.basicFinal, step: "final-text", timeout: 5)
        check(final == Fixture.basicFinal, "final-text-exact", "L2: final text '\(final)'")
        shot("done")

        // 3. Edit in place, Done (saved + republished).
        area.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()
        ensureSystemKeyboard(in: runner, step: "runner")
        area.typeText(Self.edit)
        let edited = waitForValue(area, containing: Self.edit, step: "edited", timeout: 5)
        check(edited == Fixture.basicFinal + Self.edit, "edited-text", "edited text '\(edited)'")
        shot("edited")
        tap(runnerButton("Done"), "done-button")
        require(runnerText(Self.saved), "status-saved", timeout: 5)
        shot("saved")

        // 4. Safari: the Shinsoku keyboard's Insert puts the edited text + the profile's suffix.
        focusFieldWithShinsoku()
        key("Delete").press(forDuration: 2.0)
        require(key("Insert latest text"), "insert-key", timeout: 5)
        tap(key("Insert latest text"), "insert-edited")
        require(statusText("Inserted"), "status-inserted", timeout: 5)
        shot("inserted")
        let inserted = fieldValue()
        print("SCENE inserted: '\(inserted)'")
        check(inserted.hasSuffix(Fixture.basicFinal + Self.edit + Self.suffix), "inserted-edited",
              "Insert should end with the edited text + suffix: '\(inserted)'")

        // 5. A dropped connection keeps what was heard (L2/L3).
        launchFixture(Fixture.dropped)
        tap(runnerButton("Start recording"), "dropped-record-start")
        require(runnerText(Self.stopped), "status-stopped", timeout: 15)
        let droppedArea = transcriptArea()
        let heard = waitForValue(droppedArea, containing: Fixture.droppedHeard, step: "dropped-heard", timeout: 5)
        check(heard == Fixture.droppedHeard, "dropped-heard-exact", "L2: heard text '\(heard)'")
        require(runnerButton(Self.recordAgain), "record-again", timeout: 3)
        shot("dropped")
    }

    // MARK: Runner

    private func launchFixture(_ name: String) {
        runner.terminate()
        launchRunner(
            ["-ShinsokuSceneLiveFixture", name, "-ShinsokuSceneResetSelection", "YES"] + Self.englishArguments,
            shotName: "runner-\(name)"
        )
        require(runnerText("Ready to record"), "\(name)-idle", timeout: 15)
    }

    /// The Record area: Flutter exposes the borderless TextField as a text view (multi-line) or text field.
    private func transcriptArea() -> XCUIElement {
        let textView = runner.textViews.firstMatch
        return textView.waitForExistence(timeout: 5) ? textView : runner.textFields.firstMatch
    }

    private func runnerButton(_ label: String) -> XCUIElement {
        runner.buttons.matching(labelEquals: [label]).firstMatch
    }

    /// Status lines merge their text into one label: match by containment.
    private func runnerText(_ text: String) -> XCUIElement {
        runner.descendants(matching: .any).matching(labelContainsAny: [text]).firstMatch
    }

    private func value(of element: XCUIElement) -> String {
        (element.value as? String) ?? ""
    }

    /// Polls the element's value until it contains `part`; returns the last value (fails the step otherwise).
    private func waitForValue(
        _ element: XCUIElement, containing part: String, step: String, timeout: TimeInterval
    ) -> String {
        let deadline = Date().addingTimeInterval(timeout)
        var current = value(of: element)
        while !current.contains(part), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25)
            current = value(of: element)
        }
        check(current.contains(part), step, "\(step): '\(part)' not in '\(current)'")
        return current
    }
}
