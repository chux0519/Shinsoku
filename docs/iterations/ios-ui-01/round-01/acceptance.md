# ios-ui-01 round 01 — acceptance (coordinator)

Tested source: main @ 2d957ab (U1 #4, U3 #5, U4 #6, U2 #3 merged 2026-11-18/19).

## Tier A (host) — all units
- `flutter analyze`: no issues. `tool/test_diff.sh`: no new failures (baseline 0). `review_lint` R01–R03 ok.
- U1: moved code identical to the old main.dart line-for-line (import/underscore-normalised multiset diff = 0).
- U3: 108 host renders (iphone, iphone 2.0× text, duo-outer, duo-inner portrait/landscape × dark/light);
  reviewed record (idle/listening/result/error), drafts, editor, settings, nearby, keyboard setup.
- U4: 124 renders incl. fake-fold variants; two panes split at the fold, nothing interactive in it; D1/D2
  invariants + seeded model test + named regression (tab switch → unfold → fold kept Stop reachable).

## Tier B — iPhone 17, iOS 27.2, Xcode 27.2 (shared sim 9080FE77)
`bash /Volumes/ZT/dev/Xcode/with-xcode.sh 27.2 bash tool/ios_keyboard_scene.sh <UDID> <out>` — PASS light + dark:
keyboard add, Full Access off/on, edit keys + delete repeat, App Group latest-ready → Insert asserted →
insert again, deep link shinsoku://dictation cold + warm (Record, mic alert, "Provider settings required").
No paste banner in any phase.

## Findings fixed during the round
- P1 privacy: keyboard read and previewed arbitrary clipboard content → removed.
- P1: iOS 27 redacts pasteboard content for keyboard extensions (types visible, values nil) → App Group
  (user decision 2026-11-18; App IDs + profiles updated in the developer portal, profiles reinstalled).
- P0: Runner crashed at launch with the iOS 27 SDK (no UIScene adoption) → migrated to UIScene.
- Harness: Xcode 26.0.1 cannot drive iOS 27 simulators; use Xcode 27.2.

## Pending
- **B (Duo)**: real division-region values, posture changes via DeviceHub, layout after fold/unfold. Needs
  DeviceHub in front, Automation + Screen Recording permissions, and the Flutter SDK patch check
  (see Shinphony docs/ui_review_process.md §2). Waiting for the user to schedule.
- **C**: live recording across fold (needs a provider key / device), VoiceOver, largest accessibility text
  size, haptics, TestFlight build with Xcode 27.2.

## Design conflicts for the user
| Item | DESIGN.md | Implemented | Recommendation |
|---|---|---|---|
| Section rows background | frame | raised | adopt |
| Draft row lines | first line | two lines | adopt |
| §5 component list | 10 components | + TabBar, TopBar, Page, EmptyLine, Switch | adopt |
| Duo portrait/tabletop order | Record left | Record bottom pane | adopt (tabletop: content up, controls down) |
| Duo second pane navigation | rail | top switcher | adopt |

## Known follow-ups
- Flutter rewrites pbxproj/scheme/Podfile.lock for Swift Package Manager on every build; accept the
  migration in its own PR so builds stop producing churn (flutter_secure_storage lacks SPM support).
