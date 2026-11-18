# Iteration ios-ui-01 — iOS UI to DESIGN.md, keyboard layout, iPhone Duo

Status: **confirmed by the user 2026-11-18** (DESIGN draft, keyboard layout, plan). Base: `main` @ f201dbd.

## Goal
1. Keyboard extension: a cleaner, denser layout that looks like part of iOS and follows DESIGN.md.
2. Every iOS screen (Record, Drafts, Draft editor, Settings, Nearby, setup guide) audited and migrated to the
   DESIGN.md component layer.
3. iPhone Duo: correct folded/unfolded layouts, nothing across the hinge, recording survives posture changes.

Out of scope: Qt removal, Flutter desktop, Android, new recognition features, TestFlight upload (ask separately).

## Work units (one worker each, one branch/worktree each)

| # | Unit | Files | Model | Depends on | Tier |
|---|---|---|---|---|---|
| U1 | Split `mobile/lib/main.dart` (4091 lines) into `app/`, `services/`, `features/{record,drafts,settings,nearby}/` with no behaviour change; tests stay green | `mobile/lib/**` | sonnet | — | A (analyze + test diff) |
| U2 | Keyboard extension redesign (below) | `mobile/ios/ShinsokuKeyboard/**` only | Opus | — (parallel with U1) | B (keyboard needs a simulator) |
| U3 | Theme tokens + component layer `mobile/lib/ui/` (DESIGN.md §2–§5), golden render harness for tier A, then migrate every screen and write the audit table | `mobile/lib/ui/**`, `features/**`, `test/golden/**` | Opus | U1 | A |
| U4 | iPhone Duo: adaptive shell (compact = bottom bar; regular = two panes split at the hinge), port Shinphony's `division_regions` channel (native + Dart, degrades to "no regions"), keep recording across posture change, asymmetric safe areas | `features/` shell, `ios/Runner/AppDelegate.swift`, new `lib/platform/division_regions.dart` | Opus | U3 | A + B (Duo simulator) |

At most two workers run at once: U1 ‖ U2 first, then U3, then U4.

### U2 keyboard layout (proposal)
Today: a "Shinsoku / Voice input" title row, two coloured buttons, three secondary buttons, and a two-line hint;
hard-coded teal and system grouped colours; no dark-mode tokens; Delete doesn't repeat.

Proposed, top to bottom, with the system keyboard height and DESIGN.md tokens (light/dark from the trait):
1. **Status row** (28 pt): state icon + one short line ("Ready", "Copied text ready to insert", "Turn on Full
   Access to insert"), globe on the right only when `needsInputModeSwitchKey`.
2. **Main row**: a large **Record** key (accent, mic icon, ≥ 56 pt) in the middle; **Insert latest** on the
   left (shows the first words of the latest text when available); **Delete** on the right (repeats while
   held).
3. **Edit row**: Space (wide), Return (label follows `returnKeyType`).
- No title, no permanent hint paragraph; the setup hint shows only when Full Access is off.
- Keys ≥ 44 pt where height allows; pressed state is a fill; light haptic on Record.

## Acceptance criteria
- `python3 tool/review_lint.py` ok; `flutter analyze` with no new issues; `tool/test_diff.sh`: no new failures.
- U1: no visible change (golden/widget tests unchanged), `main.dart` < 200 lines.
- U3: no raw `Color(0x…)`/`ColorScheme.fromSeed` outside `lib/ui/`; every screen has light + dark goldens at
  iPhone 17 and iPhone Duo inner/outer sizes; audit table (screen × DESIGN section × finding × fixed?) in
  `acceptance.md`; Dynamic Type at the largest accessibility size doesn't clip.
- U2: screenshots light/dark on iPhone 17 in a Notes field, with Full Access on and off; insert, delete-repeat,
  return, globe work.
- U4: Duo unfolded shows two panes with no control in the division region; fold/unfold during a recording keeps
  recording (record once, cut frames at PHASE marks); compact still uses the iPhone layout.
- Anything not proven goes to "pending C".

## Decisions
- 2026-11-18: no new simulators (disk); use the shared ones listed in AGENTS.md in turns.
- 2026-11-18: DESIGN.md draft and the U2 keyboard layout confirmed.
