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

## S2 — native StoreKit 2, mirror, gates, scene (branch `pricing-01-s2-native`, implementer, 2026-11-19)
- **Done:** `ProStore.swift` (StoreKit 2: products, purchase, restore = `AppStore.sync`, `Transaction.updates`
  from launch, `currentEntitlements`, revocation), store channels per the S1 contract, App Group mirror
  `pro.v1` (only writer; E1 keep-on-unknown rule), keyboard field-rule gate, Set Profile intent gate + dialog
  (10 languages), `Shinsoku.storekit` in the Runner scheme's Run action, DEBUG `-ShinsokuSceneProFixture`, E1–E4
  in `state_invariants.md`, seeded model test, `ProSceneTests` (build-only), the two profile scenes now launch
  with the owned fixture. Details: `S2-implementation.md`.
- **Tested source:** branch head after the commit that adds this section: `flutter analyze` clean;
  `tool/test_diff.sh` no new failures (0 known); `flutter test test/model/pro_model_test.dart` (also with
  `SHINSOKU_MODEL_SEEDS=300`); `ResolverChecks/run.sh` all passed; `flutter build ios --simulator --debug
  --no-pub` built; `tool/ios_keyboard_scene.sh --build-only` built; `check_xcstrings.py --stringsdata` 0
  problems; `python3 tool/review_lint.py` all ok. Flutter-regenerated files restored before committing.
- **In progress:** nothing; awaiting coordinator review.
- **Next (coordinator, tier B):** `SCENE_TEST=KeyboardSceneTests/ProSceneTests tool/ios_keyboard_scene.sh`;
  rerun ProfileKeyboardSceneTests / ProfileIntentSceneTests (now with the fixture); StoreKit-config purchase
  and **Refund** from Xcode (Run action) → Pro row, field rule, Shortcuts.
- **Open decisions (coordinator):**
  1. E1 rule: Pro is removed only by a verified revoked transaction. Deleting a transaction in Xcode's manager,
     or signing out of the Apple Account, keeps Pro (no evidence). OK, or downgrade when StoreKit knows no
     transaction at all while online?
  2. The keyboard shows nothing about Pro (rules silently don't apply). Add a hint?
- **How to verify:** `cd mobile && flutter analyze && flutter test test/model/pro_model_test.dart`;
  `mobile/ios/ShinsokuKeyboard/ResolverChecks/run.sh`; `tool/test_diff.sh`; `python3 tool/review_lint.py`;
  `tool/ios_keyboard_scene.sh --build-only`.

## Coordinator — acceptance round 01 (2026-11-19)
- **Merged:** S1 (#40), S2 (#42); I5 (#41) translated the S1 strings. S3 folded into S2 (E1–E4, model test,
  scene). DESIGN.md §5/§7 updated (Pro components, Settings › Shinsoku Pro first, Pro sheet).
- **Tier A (main `5e85124`):** `flutter analyze` clean; `tool/test_diff.sh` no new failures; `review_lint.py`
  all ok (R05–R07); host renders of the Pro screens (S1, I5 in ja/de/zh-Hans).
- **Tier B (iPhone 17 iOS 27.2, `9080FE77`, main `5e85124`, light + dark):** `ProSceneTests` passed (1 test, 0
  failures each look). Locked: Settings Pro row shows "$4.99", Field rules page shows the Pro lock with the
  rules kept, Safari address bar stays on the default profile (Dictation). Owned: the same field picks
  Review. Rule reset afterwards. Evidence: `build/ui-review/pricing-01/round-01/tierB-pro/{light,dark}/`.
  The keyboard UI was in Chinese (simulator language) in all phases.
- **Not covered by tier B:** a real StoreKit purchase and refund. The `.storekit` config applies only to Xcode
  Run, not to XCUITest; the scene uses the DEBUG fixture, which drives the same `pro.v1` mirror. Purchase →
  refund through StoreKit is covered by the model test (E1/E2) and goes to tier C: sandbox purchase on
  TestFlight (user).
- **IAP (App Store Connect):** `net.potafree.shinsoku.pro` id 6836728985, state **READY_TO_SUBMIT** (10
  localizations, $4.99 USA, all territories except CHN, review screenshot 1290×2796 from the host render). It
  is submitted together with the next app version.
- **Decisions kept (coordinator, user may change):** Pro is removed only by a verified refund/revocation (not
  when StoreKit simply knows no transaction); the keyboard skips a field rule silently without Pro; Settings ›
  Shinsoku Pro first; deleting a profile is not gated.
- **Next:** TestFlight build with sandbox purchase (ask the user first); release-01 plan.

## Tier C — sandbox purchase (user, 2026-11-19)
- TestFlight 0.1.0 (22) (`e91c8b6`, delivery 8398a16c-…): the user tested the sandbox purchase on their iPhone —
  **passed**. pricing-01 is done. Next: release-01 (App Store submission), separate plan.
