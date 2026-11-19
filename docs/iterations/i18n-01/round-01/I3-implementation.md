# I3 — region defaults: implementation notes

Branch `i18n-01-i3-region`, base `main` @ e539779. Source state tested: the PR head (see PR).

## Provider findings (checked 2026-11-19, before coding)
| | Fun-ASR realtime (`fun-asr-realtime`) | Soniox (`stt-rt-v4`) |
|---|---|---|
| Parameter | run-task `payload.parameters.language_hints`: `array[string]`, **one value** (more → only the first counts); absent = auto-detect | config message `language_hints`: list of ISO 639-1 codes; **bias only**, other languages still recognised |
| Languages | `fun-asr-realtime` (alias, = `-2025-11-07`): zh, en, ja, ko, vi, th, id, ms, tl, hi, ar, fr, de, es, pt, ru, it, nl, sv, da, fi, no, el, pl, cs, hu, ro, bg, hr, sk (30). Older snapshots: `-2026-02-28` zh/en/ja; `-2025-09-15` zh/en; `flash-8k` zh only | 60+: af … cy (list in `sonioxLanguages`) |
| Chinese | Mandarin, **Cantonese**, Wu, Hokkien, Hakka, Gan, Xiang, Jin + regional accents (incl. HK/TW) — all under `zh` | `zh` (no separate Cantonese code) |
| Regions | Singapore (`dashscope-intl.aliyuncs.com` / `{WorkspaceId}.ap-southeast-1.maas.aliyuncs.com`) and Beijing | global |

Sources:
- Fun-ASR WebSocket client events (run-task parameters, `language_hints`, per-model codes):
  https://www.alibabacloud.com/help/en/model-studio/fun-asr-client-events
- Fun-ASR realtime WebSocket API (endpoints, Singapore/Beijing):
  https://www.alibabacloud.com/help/en/model-studio/fun-asr-realtime-websocket-api
- Model Studio speech-to-text model list (languages/dialects per model):
  https://www.alibabacloud.com/help/en/model-studio/asr-model
- Soniox language hints: https://docs.soniox.com/stt/concepts/language-hints
- Soniox supported languages: https://docs.soniox.com/stt/concepts/supported-languages

Note: the docs disagree in places (an older iOS SDK page lists only zh/en/ja for `fun-asr-realtime`). That is one
more reason not to default non-Chinese locales to Fun-ASR (not done).

## What changed
- **`region_defaults.dart`** (pure): `regionDefaultsFor(PlatformDispatcher.locales)` →
  `{speechProvider, sonioxLanguageHints, bailianLanguageHint, translationSource}`.
  - Provider: first device language Chinese (`zh` any script/region, `yue`) → `bailian`; everything else →
    `soniox`. The language decides, not the region: `en-HK`, `en-SG`, `ms-MY` → Soniox.
  - Soniox hints: first two preferred languages Soniox knows + `en` (`ja-JP` → `[ja, en]`; `en-US` → `[en]`).
  - Fun-ASR hint: `zh` for Chinese devices, otherwise empty (auto). Fun-ASR takes one hint and treats it as the
    audio language, so a guess for a user who later switches to Bailian would hurt more than auto-detect.
  - Translation profile: `zh` → `zh_to_en` (unchanged id/strings); ja, ko, de, es, fr, pt, it →
    `translate_to_en` named "JA -> EN" etc.; English and other languages → `translate_to_en` "Translate -> EN"
    (any language in). 16 new ARB messages (English only, I5 translates; descriptions tell translators to use
    their short form, e.g. 日→英).
- **Language hints wired:** two new provider settings, `sonioxLanguageHints` (stored comma-separated) and
  `bailianLanguageHint`; absent = empty = nothing sent (today's requests). Soniox config gets
  `language_hints`; Fun-ASR run-task gets `parameters.language_hints: [hint]` (`bailianRunTaskParameters`).
  Not wired: the Qwen-ASR batch mode (different API; out of the task's two providers).
- **First launch only:** `RegionDefaultsStore.applyOnce` runs before provider settings and profiles load
  (`mobile_shell.dart`). `planRegionSetup` (pure): marker present → nothing; any `provider_settings.*` key or
  `voice_profiles.v1` → marker `kept` only; else writes `speechProvider`, both hints, the localized profile list,
  then the marker (`applied`) last. Never throws; unreadable storage writes nothing. `VoiceProfileStore.load`'s
  own first-create also uses the region translation profile (same result if it ever runs first).
- **Bug found and fixed:** Settings → Save built a fresh `ProviderSettings` and would have dropped the hints;
  the two fields are now `required` (the compiler finds every constructor) and Save carries them over
  (`test/features/settings_save_test.dart`).
- **Invariants R1–R3** in `docs/design/state_invariants.md`; unit tests (`test/services/region_defaults_test.dart`),
  seeded model test with a "broken store is caught" check and two named regressions
  (`test/model/region_model_test.dart`; also ran 1000 seeds), hint-sent replay tests.
- **Settings UI:** none added (task: only if needed). The hints are not visible; see open decision 2.

## Keyboard `PrimaryLanguage` (I2 open point) — recommendation, not changed
Currently `en-US`. Recommend **`mul`**: the keyboard has no character keys and inserts dictated text in whatever
language the user speaks; `mul` is Apple's value for multilingual keyboards and avoids iOS treating it as an
English keyboard (e.g. English-only grouping under Settings › Keyboards and `textInputMode.primaryLanguage` =
`en-US` for apps that adapt to it). A per-region value would need one build per region — not worth it. I4 owns
native files this round; change it there or in I5, then check the keyboard list on the simulator (tier B).

## Verification (PR head)
- `flutter analyze`: no issues. `tool/test_diff.sh`: no new failures (0 known).
- `python3 tool/review_lint.py`: R01–R06 ok.
- `tool/host_review.sh i18n-01/round-01/i3 record-idle,record-result,record-listening-live,settings` (52 images)
  and the same with `pseudo` (52, no overflow/clipping): Settings and Record unchanged (no UI change; scenes use the
  English seed profiles). Pre-existing pseudo artifact (I1): "[Üšé  löqwen-flash …" — the placeholder sits inside
  the pseudo padding; not from this change.

## Open decisions (for the coordinator / user)
1. **Bailian endpoint for new installs.** The default base/WebSocket URLs are the Beijing ones
   (`dashscope.aliyuncs.com`). We never sell in mainland China, so HK/TW/SG/MY users will create keys in the
   Singapore (international) region, and those keys don't work on the Beijing endpoint. Suggest: region defaults
   (or simply the build defaults for new installs) use `dashscope-intl.aliyuncs.com` for both
   `bailianApiBase` and `bailianRealtimeUrl`. Not changed here (outside the brief; it affects post-processing too).
2. **Hints in Settings.** Today a user who changes language later keeps the first-launch hints. Options: a
   read-only "Speech languages" row, or a simple picker. Recommend deferring until Free/Pro and on-device
   engines settle the Settings layout.
3. Pre-I1 TestFlight installs that never saved a setting or profile count as fresh and get region defaults.
   They had no API key, so nothing they used changes; flag if that's not acceptable.
4. Nearby: `translate_to_en` is sent to the desktop as-is (like custom profile ids); the frozen Qt app only
   knows `zh-to-en`.
