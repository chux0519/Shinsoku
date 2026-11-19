# live-01 round 01 — acceptance (coordinator)

Tested source: main @ fbcf20d (T1 #25, T2 #26, T3 #27) + scene script fix (this PR).

## Tier A
- analyze clean; test_diff no new failures; lint R01–R04 ok.
- T1: 17 provider replay tests (Bailian, Soniox: basic, out-of-order, repeated, unended at finish, dropped,
  provider error) — L1/L2.
- T3: seeded model test (5 seeds default, 300 pass) for L1–L4 + D3; mutation checks catch L2/L3/D3.
- Renders (192): Record idle / listening live / processing / result / editing (incl. Duo stacked + keyboard).

## Tier B — iPhone 17, iOS 27.2, Xcode 27.2, on main, light + dark: all PASS
- KeyboardSceneTests, ProfileIntentSceneTests, ProfileKeyboardSceneTests (regression).
- LiveSceneTests (`-ShinsokuSceneLiveFixture`, DEBUG only): live text grows ('示例第一句。' → '示例第一句。Example'),
  stop → exact final, edit in place → Done → Safari Insert ends with 'Example two. EDITED ' (Dictation suffix);
  soniox_dropped → 'Recording stopped', recognised text kept, Record again.

## Fixed along the way
- Keyboard publish trimmed the text, so profile commit suffixes never reached the keyboard (now kept).
- Drafts store plain text; suffix applied on publish/copy only.

## Process incidents → rules
- M08: PR #26 merge failed on a STATE.md conflict; worktree removed before confirming MERGED.
- M09: a hung implicit `pub get` in the scene script held the shared Flutter lock for 20 min and blocked
  Shinphony; script now uses `--no-pub` and a 10-minute limit.

## Pending
- C (device, user): real streaming with keys on TestFlight; IME marked text vs Record start (L4).
- i18n-01: friendlier failure wording (today shows e.g. "Bad state: …").
