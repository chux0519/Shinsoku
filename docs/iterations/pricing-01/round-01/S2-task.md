# S2 — Shinsoku Pro, native side (StoreKit 2) + wiring + scene

Branch `pricing-01-s2-native`, worktree `/Volumes/ZT/repos/Shinsoku-wt/s2-native`. Model: Opus. Tier A + build;
the coordinator runs tier B. Read AGENTS.md, `docs/iterations/pricing-01/plan.md`, and
`docs/iterations/pricing-01/round-01/S1-implementation.md` (**the channel contract — implement it exactly**).
S3 from the plan is folded into this task.

## Work
1. **StoreKit service** (`ios/Runner/ProStore.swift`, iOS 15+ StoreKit 2): load `net.potafree.shinsoku.pro`,
   `state` / `purchase` / `restore` (`AppStore.sync()`), a `Transaction.updates` listener started at launch,
   `currentEntitlements` (verified only; honour `revocationDate`), finish transactions. Channel
   `net.potafree.shinsoku/store` + EventChannel `net.potafree.shinsoku/store/updates`, registered where the
   other channels are (`registerChannels` in the scene delegate).
2. **App Group mirror `pro.v1`** (`group.net.potafree.shinsoku`): `{owned, updatedAt}` written only by this
   service (E4); StoreKit errors/offline never write `owned=false` (E1); a verified revocation does (E2).
3. **Keyboard gate**: field rules apply only when `pro.v1.owned` (`KeyboardProfileResolver`); manual switching
   unchanged. Missing mirror = not Pro.
4. **App Intents gate**: Set Shinsoku Profile (incl. the per-profile ready-made shortcuts) without Pro does
   nothing and returns a dialog "Switching profiles from Shortcuts needs Shinsoku Pro." (new catalog key, all
   10 languages — use `docs/i18n/glossary.md`); Get stays free. New keyboard strings likewise in all 10.
   `check_xcstrings.py` / R06 / R07 pass.
5. **StoreKit config** `ios/Shinsoku.storekit` (product id above, non-consumable, $4.99, Family Sharing) wired
   into the Runner scheme for Debug runs, so the simulator can buy without App Store Connect.
6. **DEBUG fixture**: answer `sceneProFixture` on `keyboard_bridge` from `-ShinsokuSceneProFixture
   owned|locked`, and also write the mirror accordingly (so the keyboard follows) — DEBUG builds only.
7. **Invariants**: add E1–E4 (plan §Invariants) to `docs/design/state_invariants.md`; a model test
   (`mobile/test/model/`, seeded like the PR/R tests) over Dart's entitlement + a mirror model: events
   purchase / pending→approved / refund / offline error / restore / relaunch; check E1–E3.
8. **Scene** (`KeyboardSceneTests/ProSceneTests.swift`, build-only for you): launch with
   `-ShinsokuSceneProFixture locked` → Settings shows the Pro row with a price, Field rules page shows the lock,
   keyboard in Safari ignores the Search → Review rule; relaunch with `owned` → the rule applies. Use the deep
   links (M07), PHASE screenshots, English + Chinese label matching like the other scenes.

## Done when
`flutter build ios --simulator --debug --no-pub` (under `perl -e 'alarm shift; exec @ARGV' 900`),
`tool/ios_keyboard_scene.sh --build-only`, `flutter analyze`, `tool/test_diff.sh`, `python3 tool/review_lint.py`
pass; restore Flutter-regenerated tracked files before committing; commit per unit and push;
`S2-implementation.md` + STATE.md; PR open. Reply with the PR URL.
