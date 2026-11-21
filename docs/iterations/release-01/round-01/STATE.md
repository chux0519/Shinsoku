# release-01 round-01 — STATE

## Done (2026-11-21)
- R1 (#47) iPhone only, 1.0.0, privacy manifests, M06 key guard. R2 (#48) store metadata in 10 languages, pushed.
  R3 (#49) 61 screenshots (zh-Hans 7, others 6), uploaded. R4 privacy/support pages live on potafree.net
  (potafree.net repo #5, deployed by the user). tf-22/23: build 1.0.0 (23), VALID.
- App Store Connect: price free (Pro IAP $4.99), 175 territories without China mainland, App Privacy
  "Data Not Collected" (published 2026-11-21), review detail with the dedicated review Soniox key (notes only).
- **Submitted for review 2026-11-21 00:09 (local)**: submission 53ecdd57, iOS 1.0.0 (23) + IAP Shinsoku Pro,
  both WAITING_FOR_REVIEW. Release type MANUAL.

- **Approved and released 2026-11-21** (user: "通过了 可以发了"): 1.0.0 READY_FOR_SALE, IAP APPROVED.
  https://apps.apple.com/app/id6779534781

## Lesson (R5)
- The first non-consumable IAP cannot be submitted through the API (FIRST_NON_CONSUMABLE_MUST_BE_SUBMITTED_ON_VERSION).
  A first API submit went out without the IAP; it was cancelled before review and redone: IAP page > Add for Review
  (creates the draft), version added to that draft, submitted. `tool/asc_submit.py` now stops if the IAP has not
  been added for review yet.

## Next
- Check the product page in a few hours (stores roll out gradually); then iteration close-out.
- Known script bug: `tool/store_metadata.py` first push gives 409s until rerun (fetch version localizations again
  after creating app info localizations).

## Open user actions
- Chinese review tables: `docs/store/review-zh.md`, `docs/i18n/review-zh.md`.
