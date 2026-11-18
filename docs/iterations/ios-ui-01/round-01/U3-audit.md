# U3 audit: screens against DESIGN.md (tier A)

Source: before = `53e05f7` (harness on unmigrated screens, already on the token theme from U3.1; the seeded
Material theme itself was not rendered), after = `5b99840`. Renders: `build/ui-review/ios-ui-01/round-01/u3-before/`
and `.../u3-after/` (`index.html` in each; 76 before, 108 after: 4 devices × 2 themes, plus the 2.0× Dynamic Type
variant of record-idle and settings on the iPhone). Reviewed by eye against DESIGN.md and HIG; host SF Pro, synthetic
safe areas, no keyboard extension, no hinge.

## Findings

| Screen | DESIGN § | Finding (before) | Fixed? How |
|---|---|---|---|
| All | §2 | Seeded `ColorScheme.fromSeed(0xFF256D7B)`, light-only scaffold literal | Yes: `buildSkTheme` from tokens, light + dark, follows the system; R03 lint blocks literals outside `lib/ui/` |
| All | §2 | Contrast never checked | Yes: `test/ui/tokens_test.dart` checks every text/status token on canvas/frame/raised (≥ 4.5 / ≥ 3), all pass |
| All | §1, §3 | App-icon mark in every page header (decoration), `headlineSmall` 24 pt titles + subtitles | Yes: `SkPageHeader`, page-title 17/600, no mark |
| All | §5 | Material cards with outlines, `Chip`, `NavigationBar` pill, `SwitchListTile`, `SegmentedButton`, floating-label outlined `TextField`s | Yes: Sk components; no raw Material controls left outside `lib/ui/` (Scaffold/SnackBar only) |
| Shell | §5 | Material `NavigationBar` / `NavigationRail` (rail with the app-icon mark) | Yes: `SkTabBar` (bottom / side), selection = accent-subtle fill; left/right safe insets handled independently |
| Shell | §4 | Hidden tabs kept animating (offstage spinner ticked forever) | Yes: `TickerMode` off for hidden tabs |
| Record | §7 | Record button was a full-width pill at the top inside a card; not in the bottom third | Yes: `SkRecordButton` (88 pt) in the bottom third, profile choice right above it |
| Record | §7 | Profile add/edit/delete, intent text and two chips on the home screen | Yes: moved to Settings › Profiles; Record keeps only the profile choice (locked while recording) |
| Record | §7 | No transcript area; result shown in a panel with a timing debug string (`appRecorderStop=…ms`) | Yes: transcript area (transcript 17/1.45, selectable); debug detail only in smoke-test builds |
| Record | §7 | Errors were a panel; a denied microphone or missing key jumped to tab 2, which is Desktop since Nearby was added | Yes: inline status line with the fix ("Microphone access is off — Open Settings", provider → Settings tab) |
| Record | §7 | "Microphone access is disabled" copy shown before the first permission prompt | Yes: idle shows "Ready to record"; the error appears only after a denial |
| Record | §4 | Two indeterminate indicators while processing (status + button) | Yes: one, on the record button |
| Record | §3 | Status icon stayed 22 pt at 2.0× text | Yes: status icon scales with text up to 1.5× |
| Drafts | §7 | Cards with chips, relative times ("1 days ago"), three icon buttons per card, no grouping | Yes: date groups (Today / Yesterday / date), row = text + time + source, tap to edit, swipe to delete with Undo, copy on the row; VoiceOver Copy/Delete actions |
| Drafts | §7 | Empty state: inbox icon in a card | Yes: one line, no icon |
| Draft editor | §5 | Material `AppBar`, outlined field with floating label, two equal-weight buttons | Yes: `SkTopBar`, filled `SkTextArea` in transcript style, Save (secondary) + Save & Copy (primary) |
| Settings | §7 | One long card list; Save Settings shown twice (two primaries); both providers' fields always shown | Yes: sections Recognition / provider / Profiles / Keyboard; one Save; only the selected provider's fields |
| Settings | §7 | Keyboard setup was an inline card; the "Keyboard setup" row opened iOS Settings directly | Yes: new `KeyboardSetupView` (numbered steps + one Open Settings), opened from Settings › Keyboard |
| Settings | §3 | List row subtitles truncated at 2 lines at 2.0× text | Yes: subtitles wrap freely unless a row opts in |
| Profile editor | §5 | `AlertDialog` with outlined fields and `SegmentedButton` | Yes: `SkSheet` (radius 28, grabber, shadow), Delete inside the sheet + confirm sheet |
| Nearby | §7 | Status banner in Material containers; pairing code a small outlined field | Yes: status line per connection state; pairing code 34 pt Menlo, centred; fingerprint in mono |
| Nearby | §2 | Radio tiles for desktops (selection = radio outline) | Yes: rows with accent-subtle fill + check |
| Nearby | §5 | Dropdown for the desktop profile; double `SafeArea`; app-icon header | Yes: row → sheet picker; single safe area; `SkPageHeader` |
| Nearby | §7 | Connect stays a disabled primary after connecting | Yes: becomes "Disconnect" (secondary) when connected |

## Not fixed / pending

| Item | Why | Next |
|---|---|---|
| iPhone Duo two panes, hinge avoidance | U4 scope; screens are constraint-driven and centre at 600 pt on wide windows | U4 |
| Real device rendering, haptics, VoiceOver pass, Dynamic Type AX5 (≈ 3.1×) | Tier A renders 2.0× only (task brief); no clipping or overflow at 2.0× | Tier B/C |
| `Cloud processing` switch has no effect beyond its own state | Behaviour, not UI; kept as is | Coordinator decides |
| Settings › Nearby and About sections (DESIGN §7) | No content for them yet (Nearby is its own tab; no version API dependency) | Later iteration |
| Level meter on the record button | `SkRecordButton.level` is ready; the shell does not read the recorder amplitude yet | Wire `onAmplitudeChanged` (small, behaviour change) |
| Profile segmented control at 2.0× text scrolls horizontally (last profile off-screen) | Scroll is the intended overflow for an open-ended list | Review on device |

## Design conflicts (for the coordinator; DESIGN.md not edited)

| DESIGN.md says | What I did | Why |
|---|---|---|
| §2 `frame` = "grouped sections" | Section rows sit on `raised`; `frame` is used for wells inside them (segmented track, text fields) and the keyboard | With `frame` sections, light mode is grey-on-grey (`#EEF1F1` on `#F7F8F8`) and fields inside have no contrast; `raised` rows on `canvas` match iOS grouped lists in both themes. Please confirm or reword §2. |
| §7 Drafts "row = first line + time + source" | Two lines, ellipsised | Dictations are usually one paragraph; one line hides most of it. One line is a one-word change if preferred. |
| §5 lists the components | Added `SkTabBar`, `SkTopBar`, `SkPage`/`SkPageHeader`, `SkEmptyLine`, `SkSwitch`, `SkActivityIndicator` | Needed by every screen; same tokens and rules. Add to §5 if accepted. |
| §4 "Reduce Motion → instant" | `SkActivityIndicator` shows a still arc under Reduce Motion | iOS keeps spinners under Reduce Motion; the still arc also lets host renders settle. Acceptable either way. |
| §7 Record "one record button" | Profile choice sits above the button | Profile must be chosen before recording; DESIGN does not place it. |
