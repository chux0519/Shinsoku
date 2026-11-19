# pricing-01 round 01 — STATE

## S1 — Dart: entitlement, Pro sheet, gates (branch `pricing-01-s1-dart`, implementer, 2026-11-19)
- **Done:** `ProEntitlement` (channel impl over `net.potafree.shinsoku/store` + fake + DEBUG fixture hook),
  `ProScope` above the navigator, `SkProSheet` / `SkProBadge` / `SkProLockedNote`, gates in Settings (Shinsoku
  Pro section first: price/Unlocked + Restore Purchases; Add profile), profile editor (read-only), field rules,
  Use in apps, Desktop tab; 27 English strings (+ pseudo); 36 new tests (E1/E2 at the entitlement, gates
  owned/not owned, E3 storage intact after revocation); host renders en + pseudo. Channel contract for S2 and
  details: `S1-implementation.md`.
- **Tested source:** branch head after the commit that adds this file (code unchanged since `bba039a` + the
  settings_save_test fix in the same commit): `flutter analyze` clean, `tool/test_diff.sh` no new failures
  (0 known), `python3 tool/review_lint.py` all ok, host review 126 images × (en, pseudo) all pass.
- **In progress:** nothing; awaiting coordinator review.
- **Next:** S2 implements the native side of the contract (after I5 merges); S3 translates the `pro*` keys,
  adds E1–E4 to `state_invariants.md` + model test, scene with a StoreKit config purchase.
- **Open decisions (coordinator):**
  1. Settings › Shinsoku Pro is the **first** section (Restore easy to find for users and App Review). DESIGN §7
     lists Recognition first; move it if you prefer (one line in `settings_view.dart`).
  2. Deleting a profile is **not** gated without Pro (not a field edit). Gate it?
  3. `ProState.lastError` became `notice` (coded `ProNotice`, includes pending/cancelled/restored).
  4. Pre-existing: `SkListRow` value column leaves dead space after short values (Field rules rows); not
     changed here (shared component).
- **How to verify:** `cd mobile && flutter analyze && flutter test test/services/pro_entitlement_test.dart
  test/features/pro_gates_test.dart`; `tool/test_diff.sh`; `python3 tool/review_lint.py`;
  `tool/host_review.sh pricing-01/round-01/s1 pro-sheet,pro-sheet-loading,pro-sheet-pending,pro-sheet-owned,settings-pro-locked,profile-editor-locked,field-rules-locked,use-in-apps-locked,nearby-locked '' '' en`
  (and `pseudo` as 5th argument). Renders: `build/ui-review/pricing-01/round-01/s1{,-pseudo}/index.html`.
