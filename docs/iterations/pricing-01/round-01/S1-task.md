# S1 — Shinsoku Pro, Dart side (entitlement model, Pro sheet, gates)

Branch `pricing-01-s1-dart`, worktree `/Volumes/ZT/repos/Shinsoku-wt/s1-dart`. Model: Opus. Tier A.
Read AGENTS.md, DESIGN.md, `docs/iterations/pricing-01/plan.md` (decisions, behaviour, E1–E4) first.
I5 (translations) runs in parallel: stay out of `mobile/ios/` and the non-English ARB files; add new keys to
`app_en.arb` only (S3 translates them).

## Work
1. **`mobile/lib/services/pro_entitlement.dart`**: `ProEntitlement` = `ValueListenable<ProState>`
   (`ProState { owned, productPrice (localized string or null), busy, lastError (coded, not raw) }`) with
   `purchase()`, `restore()`, `refresh()`. Two implementations: a fake (tests, host renders, DEBUG fixture) and
   a channel implementation over `net.potafree.shinsoku/store` — methods `state` → `{owned: bool, price:
   String?}`, `purchase` → `{result: purchased|pending|cancelled|failed, owned}`, `restore` → same; event
   channel `net.potafree.shinsoku/store/updates` emitting the state map. Write this contract into
   `S1-implementation.md` exactly — S2 implements it natively. Missing plugin (tests, other platforms) → not
   owned, no crash. Errors never flip `owned` from true to false (E1).
2. **Pro sheet** component `SkProSheet` in `mobile/lib/ui/` (DESIGN.md tokens; no new colours): title, the three
   Pro items (custom profiles, automatic switching per app, Desktop), price from StoreKit on the Buy button
   ("Unlock for $4.99" style, placeholder while loading), Restore Purchases, a one-line note "One-time
   purchase. Family Sharing included." Pending/cancelled/failed states with friendly text (M10). A small
   `SkProBadge` for locked rows.
3. **Gates** (plan §Behaviour):
   - Profile editor: creating a profile and editing any profile's fields need Pro; without Pro the editor is
     read-only with a Pro badge + opens the sheet. Selecting existing custom profiles stays free (E3).
   - Field rules page and the Use in apps automation section: visible, badge, actions open the sheet.
   - Nearby / Desktop tab: shows what it is + the Pro sheet entry instead of pairing.
   - Settings: a "Shinsoku Pro" row (owned → "Unlocked"; else price + opens the sheet; Restore Purchases).
   - Never gate: recording, keys, keyboard setup, built-in profiles and their post-processing, drafts.
4. Tests: gate widget tests (owned / not owned), entitlement fake + channel impl with a mocked channel (E1:
   error after owned keeps owned), no data deleted when Pro is lost (E3) at the store level.
5. Host renders: Pro sheet (price loaded / loading / pending), Settings Pro row, locked profile editor, locked
   field rules, Desktop tab locked — iPhone + Duo, light/dark, en + pseudo.

## Done when
`flutter analyze`, `tool/test_diff.sh` (no new failures), `python3 tool/review_lint.py` pass; renders reviewed by
you for overflow; commit per unit and push; `S1-implementation.md` + `docs/iterations/pricing-01/round-01/
STATE.md`; PR open. Reply with the PR URL. Any `pub get` under `perl -e 'alarm shift; exec @ARGV' 300`.
