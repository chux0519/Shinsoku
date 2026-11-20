# release-01 round-01 — STATE

## Done
- R1 (branch `release-01-r1-app`): iPhone only, 1.0.0 with the keyboard following the app version, privacy
  manifests (app + keyboard), microphone usage string in 10 languages, key scan + M06 guard. Details and
  checks: `R1-implementation.md`. Tier A + builds pass at `db8ddb3`.

## In progress
- R4 (website) — other worker.

## Next
- Coordinator review/merge of R1; R2 (metadata) → R3 (screenshots) → R5.

## Open decisions / user actions
- `REVIEW_SONIOX_API_KEY` is not in `.env` yet.
- Chinese review of the new microphone string (`docs/i18n/review-zh.md`, last section).

## How to verify R1
`cd mobile && flutter build ios --simulator --debug --no-pub`, then check
`build/ios/iphonesimulator/Runner.app{,/PlugIns/ShinsokuKeyboard.appex}/Info.plist` (1.0.0, same build,
`UIDeviceFamily [1]`) and both `PrivacyInfo.xcprivacy`.
