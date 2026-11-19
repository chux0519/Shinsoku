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
/// The keyboard side (status row shows the profile the intent set) is `ProfileKeyboardSceneTests` (P3 scene).
/// Helpers live in `SceneSupport.swift`.
///
/// The App Shortcuts tiles are found without creating a shortcut, so the scene is idempotent and leaves nothing
/// behind in the user's library. System labels are matched in English and Chinese (the shared simulators run in
/// Chinese; Shortcuts is launched with English launch arguments).
final class ProfileIntentSceneTests: SceneTestCase {
    func testProfileIntentScene() throws {
        // 1. Launch Shinsoku once: Dart publishes `profiles.v1` (the intents' entity list) at launch.
        //    pricing-01: Set Shinsoku Profile is Shinsoku Pro; the Debug fixture writes the mirror `pro.v1` owned
        //    (the intents read it; later launches without the fixture keep it, E1).
        runner.terminate()
        runner.launchArguments = ["-ShinsokuSceneProFixture", "owned"]
        runner.launch()
        check(runner.wait(for: .runningForeground, timeout: 20), "runner-launch", "Shinsoku did not launch")
        require(runner.descendants(matching: .any).matching(labelContainsAny: Self.recordTab).firstMatch,
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
}
