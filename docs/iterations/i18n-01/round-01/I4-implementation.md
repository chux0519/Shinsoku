# I4 — ready-made App Shortcuts per profile: implementation notes

Branch `i18n-01-i4-shortcuts`, base `main` @ e539779. Tested source state: the PR head (see STATE.md).

## What changed
- **`Runner/ProfileIntents.swift`**: the existing *Set Shinsoku Profile* App Shortcut gets two parameterized
  phrases over `ProfileEntity`, placed first: `"Switch \(.applicationName) to \(\.$profile)"` and
  `"Use \(\.$profile) in \(.applicationName)"`. The plain phrases ("Set/Switch Shinsoku profile") and the
  *Get* shortcut are unchanged. `ProfileEntityQuery.suggestedEntities()` already returned the saved profiles
  (App Group `profiles.v1`), so iOS builds one ready-made action per profile from it.
  - Why one AppShortcut and not a second one for the same intent: the Shortcuts app titles an App Shortcut
    tile by its first phrase; with the parameterized phrase first, each profile tile reads "Switch Shinsoku
    to Chat", while Siri still accepts the plain phrases (it then asks for the profile). Avoids two entries
    for the same intent.
  - New `ShinsokuShortcutParameters.refresh()` wraps `ShinsokuShortcuts.updateAppShortcutParameters()` behind
    `#available(iOS 16.0, *)` (Runner targets iOS 15).
- **`Runner/AppDelegate.swift`**: `refresh()` on launch (`didFinishLaunching`) and in `publishProfiles` when the
  sanitized list differs from the stored one (add / rename / delete / reorder). Dart is untouched (I3 owns
  `mobile/lib/services/`).
- **Strings**: `en.lproj/AppShortcuts.strings` +2 phrases. The parameter is written `${profile}` in the key —
  confirmed against the compiler-extracted `ExtractedAppShortcutsMetadata.stringsdata` (values:
  `Switch ${applicationName} to ${profile}`, `Use ${profile} in ${applicationName}`). No new
  `Localizable.xcstrings` key: the short title ("Set Profile"), title and description are reused.
- **Use in apps** (`use_in_apps_view.dart`): one secondary-text line under the keyboard note, ARB
  `useInAppsReadyMade`: "Each profile also has a ready-made action in the Shortcuts app, such as “Switch
  Shinsoku to Chat”. No setup needed." Its ARB description tells I5 the quoted part must match the translated
  phrase. Pseudo ARB + gen-l10n regenerated.

## Verified (tier A)
- `flutter analyze` clean; `tool/test_diff.sh` no new failures.
- `flutter build ios --simulator --debug --no-pub` ✓; `tool/ios_keyboard_scene.sh --build-only` → TEST BUILD
  SUCCEEDED.
- `python3 tool/review_lint.py` all ok (R05, R06); `check_xcstrings.py --stringsdata <DerivedData
  Runner-auekkax…>/…/Runner.build/Debug-iphonesimulator` → 0 problems, 0 warnings.
- Host renders `use-in-apps`, en + pseudo, 4 devices × 2 themes: `build/ui-review/i18n-01/round-01/i4{,-pseudo}/`.
  No clipping; the pseudo text scrolls above the pinned button as before.
- Flutter-regenerated tracked files restored (`AppFrameworkInfo.plist`, `Podfile.lock`, `Runner.xcscheme`).

## Tier B scene note (coordinator; not run)
On the `iPhone 17` simulator (UDID 9080FE77-…), dev bundle id, after opening the app once:
1. Shortcuts app › Shinsoku (App Shortcuts section): one tile per saved profile, titled "Switch Shinsoku to
   <name>"; plus the *Get Shinsoku Profile* tile. Tapping a tile runs without opening the app and shows the
   dialog "Shinsoku profile: <name>"; the keyboard then shows that profile.
2. Spotlight: typing a profile name or "Switch Shinsoku" lists the same actions.
3. Rename a profile in the app (Settings › Profiles), background the app, reopen Shortcuts: the tile shows the
   new name. Add and delete a profile: a tile appears / disappears. (iOS can cache for a few seconds; relaunch
   Shortcuts if needed.)
4. Siri phrase check is optional (simulator Siri is unreliable).
5. In zh-Hans / ja (after I5): tiles use the translated phrase; the profile name stays as the user typed it.

## For I5
- Translate the two new phrases in each `<lang>.lproj/AppShortcuts.strings` keeping both `${applicationName}`
  and `${profile}`; `useInAppsReadyMade` must quote the translated "Switch … to Chat" phrase.
