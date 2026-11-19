# S1 — Shinsoku Pro, Dart side: implementation notes

Branch `pricing-01-s1-dart`. Tier A. Source: see STATE.md for the commit that was tested.

## Store channel contract (S2 implements this natively)

Product id `net.potafree.shinsoku.pro` (non-consumable, Family Sharing on).

### MethodChannel `net.potafree.shinsoku/store`

| Method | Arguments | Answer |
|---|---|---|
| `state` | none | `{owned: bool, price: String?}` |
| `purchase` | none | `{result: "purchased" \| "pending" \| "cancelled" \| "failed", owned: bool}` |
| `restore` | none | `{result: "purchased" \| "pending" \| "cancelled" \| "failed", owned: bool}` |

- `owned`: Pro from StoreKit 2's verified `Transaction.currentEntitlements` for the product; when StoreKit cannot
  answer (offline, error) the native side answers from the App Group mirror `pro.v1` (E1, E4). Unverified
  transactions never count.
- `price`: `Product.displayPrice` (localized, e.g. `"$4.99"`, `"¥800"`); `null` (or the key missing) while the
  product cannot be loaded. Dart keeps the last non-empty price.
- `purchase`: `Product.purchase()`. `success` + verified → finish the transaction, write the mirror, answer
  `purchased, owned: true`; `success` + unverified → `failed`; `pending` (Ask to Buy / SCA) → `pending`;
  `userCancelled` → `cancelled`; a thrown StoreKit error → `failed` (or a `PlatformException`, which Dart maps to
  `failed`). `owned` is the entitlement after the call.
- `restore`: `AppStore.sync()`, then re-read the entitlements; answer `result: "purchased"` when the sync ran
  (whether or not Pro was found; `owned` says which), `cancelled` when the user cancelled the Apple Account
  sign-in, `failed` on an error.
- Errors: a `FlutterError`/`PlatformException` with any code is fine; Dart never shows its message (M10).
- Missing plugin (tests, Android, desktop) → Dart treats Pro as not owned and shows "The App Store isn't
  available right now" on Buy/Restore.

### EventChannel `net.potafree.shinsoku/store/updates`

Emits the same map as `state` (`{owned: bool, price: String?}`) whenever `Transaction.updates` delivers a
change (purchase approved later, refund, Family Sharing revoked) and after the native side rewrote the mirror.
Dart subscribes only after `state` answered once.

### How Dart applies answers (E1/E2)

- Only `state` answers and update events can set `owned` to false (E2: revocation). A map without a bool
  `owned` leaves `owned` unchanged.
- `purchase`/`restore` answers only upgrade: `owned: false` after a failed purchase never downgrades (E1).
- Exceptions, timeouts and malformed answers never change `owned` (E1).
- `state` that does not answer within 10 s stops the "Loading price…" placeholder (Buy shows "Unlock Shinsoku
  Pro" and stays usable); a late answer is still applied.
- One purchase/restore at a time; a second tap while one runs is ignored.

### DEBUG fixture (for scenes, S3)

Dart asks `net.potafree.shinsoku/keyboard_bridge` method `sceneProFixture` (DEBUG builds only), expecting
`"owned"`, `"locked"` or `nil`, exactly like `sceneLiveFixture`. S2/S3: answer it from the launch argument
`-ShinsokuSceneProFixture owned|locked`. With a fixture the app uses `FakeProEntitlement` and never touches
StoreKit. Release builds never call it.

## Dart pieces

- `mobile/lib/services/pro_entitlement.dart`: `ProState {owned, productPrice, busy, notice}`, `ProEntitlement`
  (`ValueListenable<ProState>` + `purchase`/`restore`/`refresh`/`clearNotice`), `ChannelProEntitlement`,
  `FakeProEntitlement`, `ProScope` (an `InheritedNotifier` in `MaterialApp.builder`, so pushed routes and sheets
  see it; without a scope everything is locked).
  - Deviation from the brief: `lastError` is called `notice` (`ProNotice`: pending, cancelled, failed,
    unavailable, restored, nothingToRestore), because pending/cancelled/restored are not errors. Still coded.
- `mobile/lib/ui/sk_pro.dart`: `SkProBadge` (lock + "Pro", accent-subtle pill = `SkBadge`), `SkProSheet` +
  `showProSheet`, `SkProLockedNote` (badge + one line + optional "Unlock Shinsoku Pro" text button). Tokens
  only; one primary button per sheet.
- `mobile/lib/main.dart`: `ShinsokuMobileApp` is stateful, owns the entitlement (or takes `proEntitlement:` in
  tests), installs `ProScope`.
- `mobile/lib/nearby/nearby_tab.dart`: `NearbyTab` = pairing with Pro, otherwise what Desktop is + Unlock.

## Gates

| Where | Without Pro | With Pro |
|---|---|---|
| Settings › Shinsoku Pro (first section) | row: price + chevron → sheet; Restore Purchases row | row: "Unlocked" → sheet (status) |
| Settings › Add profile | Pro badge; opens the Pro sheet | opens the editor |
| Profile editor (any profile) | fields/segments/toggle disabled, badge + note, Cancel / "Get Pro"; Delete stays | editable |
| Field rules | rules shown, badge + note + Unlock; rows open the sheet; nothing written | picker |
| Use in apps | steps shown, badge + note; primary button = Unlock | Open Shortcuts |
| Desktop tab | title, what it is, badge, Unlock | pairing page |
| Never gated | recording, keys, keyboard setup, selecting any profile (Record selector, keyboard), built-in profiles' post-processing, drafts | |

Buying from the sheet opened over the editor unlocks the editor live (it listens to `ProScope`).
Deleting a profile is not gated (it is not editing a field); flag if the coordinator wants it gated.

## Tests (tier A)

- `test/services/pro_entitlement_test.dart` (16): state/price, purchase results → notices, platform error →
  coded failure, E1 (state throws / garbage / failed purchase+restore with `owned:false` / update stream error
  keep owned), E2 (update revokes and grants), restore outcomes, one action at a time, no plugin, the fake.
- `test/features/pro_gates_test.dart` (20): every gate owned / not owned, buying from the sheet unlocks
  Settings and the editor live, sheet states (loading, pending, cancelled, failed, closed clears the notice),
  no plugin, a store that never answers, E3 (revocation in the running app: profiles and field rules storage
  untouched, no deletes, custom profile still listed).
- Existing tests that exercise Pro features now run with an owned fake (`posture_test`, `settings_deep_link_test`,
  `field_rules_test`, the Desktop case in `widget_test`); `settings_save_test` scrolls the Save button fully
  on screen (the Pro section moved it).

## Renders

`tool/host_review.sh pricing-01/round-01/s1 <scenes> '' '' en|pseudo` — scenes `pro-sheet`, `pro-sheet-loading`,
`pro-sheet-pending`, `pro-sheet-owned`, `settings-pro-locked`, `profile-editor-locked`, `field-rules-locked`,
`use-in-apps-locked`, `nearby-locked`, plus the owned `settings`, `field-rules`, `profile-editor`, `nearby`,
`nearby-pair`, `use-in-apps`; iPhone + Duo outer/inner portrait/landscape (+ folds where listed), dark/light;
126 images per locale, no overflow, no clipped pseudo text. Fixed in review: the Settings Pro row's price
squeezed the subtitle (now a trailing label); "Unlock Shinsoku Pro" wrapped in the half-width editor button
(now "Get Pro"); the Desktop scenes built the pairing view directly (now `NearbyTab`).

## Not in S1

- Native StoreKit, mirror `pro.v1`, keyboard field-rule gate, Set Profile intent gate → S2.
- Translations of the 27 new keys (`pro*`: proName … proUnlockShort) → S3. E1–E4 in `state_invariants.md` + model test → S3.
