# S2 — Shinsoku Pro, native side: implementation notes

Branch `pricing-01-s2-native`. Tier A + build; tier B (scene, StoreKit purchase) is the coordinator's. S3 from the
plan is folded in. Source tested: see STATE.md.

## StoreKit service — `mobile/ios/Runner/ProStore.swift`
- `@MainActor` singleton, StoreKit 2 (app minimum iOS 15). `start()` from `didFinishLaunching`: a
  `Transaction.updates` listener for the app lifetime + a reconcile of the mirror. `register(messenger:)` from
  `registerChannels`: MethodChannel `net.potafree.shinsoku/store` and EventChannel
  `net.potafree.shinsoku/store/updates`, exactly as in `S1-implementation.md`.
- `state` → `{owned, price}`: reconcile, then `Product.displayPrice` (product cached; `price` omitted while it
  can't be loaded).
- `purchase` → `purchase(confirmIn: scene)` on iOS 17+ (UIScene app), `purchase()` before. verified → finish,
  mirror `true`, `purchased`; unverified → `failed` (not finished); `pending`; `userCancelled` → `cancelled`;
  thrown error / no product → `failed`. `owned` is the mirror after the call. Errors are maps, not exceptions.
- `restore` → `AppStore.sync()`; `StoreKitError.userCancelled` → `cancelled`, other errors → `failed`;
  otherwise reconcile and `purchased` with `owned`.
- Updates: verified → `finish()`; for the product → reconcile, then emit `{owned}` on the event channel (no
  price: Dart keeps the last one). Unverified updates are ignored.

### Mirror rule (`ProStore.ownedAfter`, E1/E2)
| StoreKit evidence | Mirror |
|---|---|
| verified, unrevoked entitlement in `currentEntitlements` | `owned = true` |
| none live, and `Transaction.latest(for:)` is verified with a `revocationDate` | `owned = false` (E2) |
| anything else: offline, error, no transaction known | unchanged; missing stays missing = not Pro (E1) |

Consequence: deleting a transaction in Xcode's transaction manager (instead of **Refund**) does not remove Pro,
and neither does signing out of the Apple Account. That is the E1 trade-off ("errors never downgrade"); refunds
and Family Sharing removal carry a `revocationDate` and do downgrade. For tier B use **Refund Purchase**.

## App Group mirror `pro.v1` — `ProfileGroup.swift`
`{owned: bool, updatedAt: ISO 8601 UTC}`; `parsePro` / `readPro` / `proOwned` (fail closed: missing or
malformed → not Pro) / `writePro`. In `ProfileGroup.swift` because Runner and the keyboard both compile it
(and `ResolverChecks`). Only `ProStore` calls `writePro` (E4).

## Gates
- **Keyboard:** `KeyboardProfileResolver.readApplicableFieldRules()` = the stored rules only when
  `pro.v1.owned`; `refreshProfile` uses it. Stored rules are never touched (E3); manual switching unchanged.
  The profile log line is unchanged. No new keyboard strings were needed (the keyboard says nothing about Pro).
- **App Intents:** `SetShinsokuProfileIntent.perform` without Pro writes nothing and returns the dialog
  "Switching profiles from Shortcuts needs Shinsoku Pro." The per-profile ready-made shortcuts are the same
  intent, so they are gated too. Get stays free. New catalog key in `Runner/Localizable.xcstrings`, the 9
  translations are the I5-reviewed ARB `proLockedUseInApps` values (same sentence), via `tool/i18n/native.json`
  → `tool/i18n_native.py`.

## StoreKit config — `mobile/ios/Shinsoku.storekit`
`net.potafree.shinsoku.pro`, NonConsumable, 4.99, Family Shareable, en_US / USA. In the project (no target)
and in the Runner scheme's Run action (`StoreKitConfigurationFileReference ../../Shinsoku.storekit`). It applies
only when the app is **run from Xcode** (or `xcodebuild` with the scheme's Run action); `flutter run` and
`simctl launch` don't use it, and XCUITest runs don't either (the scene uses the fixture).

## DEBUG fixture
`-ShinsokuSceneProFixture owned|locked`: `keyboard_bridge` `sceneProFixture` answers it (Dart then uses
`FakeProEntitlement`); `ProStore.start()` writes the mirror from it and never touches StoreKit; the store
channel answers from it too. `#if DEBUG` only.

Existing scenes adjusted: `ProfileKeyboardSceneTests` (field rule + Set Profile) and
`ProfileIntentSceneTests` (Set Profile) now launch the runner with `-ShinsokuSceneProFixture owned`; without it
they would fail on a fresh simulator now that both are Pro.

## Invariants, tests
- E1–E4 in `docs/design/state_invariants.md` (section E).
- `mobile/test/model/pro_model_test.dart`: real `ChannelProEntitlement` over mocked channels + a Dart port of
  `ProStore` writing a mirror; StoreKit world events Buy (success / pending / cancelled), Approve, Refund
  (delivered now or when back online), GoOffline/GoOnline, Restore, Relaunch. Checks after every event: E4 (app
  = mirror, the store writes only `pro.v1`), E1 (entitled ⇒ owned; nothing but a delivered revocation
  downgrades), E2 (delivered revocation ⇒ not owned), E3 (user data keys untouched). Seeds as PR/R
  (`SHINSOKU_MODEL_SEEDS`), a self-check (seeds 0–49) that a store downgrading on "unknown" is caught, 3 named regressions.
- `ResolverChecks/main.swift`: mirror parsing (missing / malformed / non-bool → not Pro), gate on/off, E3 (a
  revoked mirror leaves `fieldRules.v1` alone).

## Scene — `KeyboardSceneTests/ProSceneTests.swift` (build-only here)
owned → set Search → Review (deep link to Field rules) → locked: lock note + rule still listed (PHASE
`field-rules-locked`), Back → Settings Pro row with "$4.99" (`settings-pro-locked`), Safari address bar shows
Dictation (`address-bar-locked-default`) → owned: address bar shows Review (`address-bar-owned-review`).
Teardown: rule back to None with Pro owned. English + Chinese labels.
Run: `SCENE_TEST=KeyboardSceneTests/ProSceneTests tool/ios_keyboard_scene.sh <UDID> <out-dir>`.

## Not covered (for the coordinator)
- Tier B with the StoreKit config (purchase → Pro row Unlocked, field rule applies; Refund in the transaction
  manager → stops, data intact) needs a run from Xcode.
- Done here: `check_xcstrings.py --stringsdata` (M11) on the scene build's Runner output: 0 problems.
