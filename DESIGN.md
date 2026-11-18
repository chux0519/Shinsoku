# DESIGN — Shinsoku

Single source of truth for visual and interaction rules. Only the coordinator edits this file; user decisions
are written here with their date.

> Status: **draft 2026-11-18**, derived from Shinphony's DESIGN.md principles with Shinsoku's own palette
> (user decision 2026-11-18: "沿用 Shinphony 的原则，配色独立"). The first UI iteration confirms or corrects it.
> Where current code disagrees, new work follows this file and old screens migrate per §8.

## 1. Character
**"The quiet microphone."** Shinsoku is something you reach for mid-sentence: open, speak, the text lands where
you were typing. Its quality comes from restraint and precision: few colours, a clear hierarchy, one obvious
action per screen. The words you dictated are the content; the interface only says what state the microphone
is in (idle, listening, processing, done, failed) and gets out of the way.

Refuses: the default Material look (seeded `ColorScheme`, elevated cards, FABs), decorative gradients,
illustrations and mascots, colour that means two things, more than one primary action per screen, animation
that is not feedback.

## 2. Colour
Neutral surfaces + one accent (teal, the brand colour from the app icon). Status colours appear only with text
or an icon. Contrast is checked in every theme: 4.5:1 for body text, 3:1 for icons and large text.

| Token | Dark (default) | Light | Use |
|---|---|---|---|
| canvas | `#101314` | `#F7F8F8` | page background, transcript area |
| frame | `#161A1B` | `#EEF1F1` | grouped sections, keyboard background |
| raised | `#1D2224` | `#FFFFFF` | cards, sheets, menus, keys |
| text | `#E3E9EA` | `#1C2426` | primary text |
| text-secondary | `#AEB9BB` | `#4A5659` | labels, metadata |
| text-tertiary | `#848E90` | `#5F6A6D` | hints, timestamps (≥ 12 px) |
| hairline | `rgba(227,233,234,0.08)` | `rgba(28,36,38,0.12)` | separators |
| border | `#2E3739` | `#D5DBDC` | input outlines only when needed |
| accent | `#6CC3CF` | `#1F6470` | primary action, focus, selection |
| accent-subtle | `#23464C` | `#D6ECEF` | selected fills, badges |
| success | `#A6D189` | `#4F7A1F` | done (with icon) |
| warning | `#E5C890` | `#8A6400` | needs permission / setup |
| danger | `#E78284` | `#B3261E` | errors, destructive, **recording** indicator |

- Text on an accent button: canvas colour (dark) / white (light).
- Selection is a fill (accent-subtle or raised + text 8%), never an outline.
- Theme follows the system; dark is the design reference.

## 3. Type, spacing, shape
- System font (SF Pro via the platform default); never bundle a font for UI text.
- Type scale: page-title 17/600, title 15/600, body 15/400, secondary 13/400, caption 12/400,
  section-label 11/600 tracking 0.6, transcript 17/400 line-height 1.45. Honour Dynamic Type; layouts must
  survive the largest accessibility size without clipping.
- Spacing: 4 / 8 / 12 / 16 / 24. Screen margins 16 (20 on widths ≥ 600).
- Touch targets ≥ 44×44; keyboard keys ≥ 44 high where height allows, never below 40.
- Radii: control 10, card 14, sheet 28, pill 999. Hairlines 0.5 pt (1 px on 2×).
- No shadows except on floating sheets/menus.

## 4. Motion
- 150–250 ms, ease-out for entering, ease-in for leaving. Reduce Motion → instant.
- The only loop allowed: the listening level meter while the microphone is live. Processing uses a single
  indeterminate indicator, not a custom animation.
- Haptics: light impact on record start/stop, success notification on insert; none elsewhere.

## 5. Components
Own component layer (`mobile/lib/ui/`), new UI uses it, not raw Material widgets:
`SkButton` (primary / secondary / text), `SkIconButton`, `SkRecordButton` (the one big control),
`SkCard`, `SkSection` + `SkListRow`, `SkSegmented`, `SkSheet`, `SkTextArea`, `SkStatusLine`
(state text + icon), `SkBadge`, `SkKey` (keyboard extension mirrors it in SwiftUI/UIKit with the same tokens).

## 6. Layout and form factors
- iPhone (compact width): single column, primary action in the bottom third (thumb reach).
- **iPhone Duo** (2026-11-18): folded = iPhone rules. Unfolded = two panes split at the hinge: left = record
  and current transcript, right = drafts/history or settings detail. Nothing interactive or text-bearing
  crosses the hinge; use the display-feature APIs, not a width guess. Posture changes keep state (an active
  recording never stops because the device folded). Follow the `iphone-duo-*` skills.
- Keyboard extension: fixed height that fits the system keyboard; top row status + mode; primary row
  Record (largest key) and Insert/Paste; edit row Return, Delete, Next keyboard (globe). No scrolling, no
  settings inside the keyboard beyond mode switching.

## 7. Screens
- **Record (home):** status line, transcript area, one record button. Empty state: one line on how to start.
  Errors: inline status line with the fix (e.g. "Microphone access is off — Open Settings").
- **Drafts / history:** date-grouped list, row = first line + time + source; tap to edit; swipe to delete
  with undo.
- **Settings:** grouped sections (Recognition, Profiles, Keyboard, Nearby, About); one detail per row.
- **Nearby microphone:** pairing code large and mono, connection state as status line.
- **Keyboard setup guide:** numbered steps, one "Open Settings" action.

## 8. Migration
Existing screens use Material defaults (`ColorScheme.fromSeed(0xFF256D7B)`). They move to the component layer
screen by screen; each migrated screen is reviewed against this file. Until then, do not add new raw Material
widgets.

## 9. Exceptions (dated)
- (none yet)
