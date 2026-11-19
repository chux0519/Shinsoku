# I3 — region defaults (first launch only)

Branch `i18n-01-i3-region`, worktree `/Volumes/ZT/repos/Shinsoku-wt/i3-region`, base `main` @ e539779 (I1 + I2
merged). Model: Opus. Tier A only. Read AGENTS.md, `docs/iterations/i18n-01/plan.md` (I3 row) and
`I1-implementation.md` first.

## Goal
A new install picks sensible defaults from the device's language and region. Existing installs and anything the
user has set are never changed.

## Work
1. **Region profile** (`mobile/lib/services/region_defaults.dart`, pure Dart, unit-tested): input = the device
   locales (`PlatformDispatcher.locales`, incl. region such as `zh-Hant-HK`, `zh-Hans-SG`, `ja-JP`, `pt-BR`);
   output = { default speech provider, ASR language hints per provider, the built-in profile set }.
   - Provider: Bailian (Fun-ASR realtime) for Chinese (zh-Hans, zh-Hant, yue / HK / MO / TW / SG / MY); Soniox
     for everything else.
   - **Verify before coding** which languages `fun-asr-realtime` supports (Alibaba Model Studio international
     docs) and which language-hint parameters both providers accept (Soniox `language_hints`; Fun-ASR
     `language_hints` or equivalent). Write the findings with source URLs into `I3-implementation.md`. Do not
     default a non-Chinese locale to Fun-ASR.
   - Profiles: keep Dictation / Chat / Review; replace the fixed `ZH -> EN` with a translation profile from the
     device language into English (中→英, 日→英, 한→영, DE→EN, …; for English devices: "Translate → EN", any
     language in, English out). Stable ids (e.g. `translate_to_en`; keep `zh_to_en` for zh so existing data
     and tests stay valid). Names/prompts come from the ARB (`app_en.arb`, English values only; I5 translates).
2. **Language hints wired to the providers** in `transcription_service.dart` (Soniox config message, Fun-ASR run
   task parameters), stored per install like other provider settings; replay tests still pass and a test shows
   the hint is sent.
3. **First launch only.** `ProviderSettings` reads absent keys as defaults, so changing a default would silently
   switch existing users. Fix: on first launch write the region choice once (a `region_defaults.v1` marker);
   an install that already has any stored provider setting or profiles keeps today's values (`bailian`, current
   profiles) and only gets the marker. Add invariant **R1–R3** to `docs/design/state_invariants.md` (user
   settings always win; defaults applied once; an upgrade never changes the provider) and unit/model tests.
4. Settings: no new UI unless needed; if the hint is shown, it is a read-only row or a simple picker, via ARB.
5. Keyboard `PrimaryLanguage` (I2 open point): recommend en-US vs `mul` in the notes; do not change the
   keyboard target (I4 owns native files in this round).

## Out of scope
Native files (`ios/`), pricing/Pro gating, on-device engines, translations other than English ARB values.

## Done when
`flutter analyze`, `tool/test_diff.sh` (no new failures), `python3 tool/review_lint.py` pass; host renders of
Settings and Record in en + pseudo unchanged or reviewed; `I3-implementation.md` + STATE.md section written;
PR open. Reply with the PR URL. `pub get` only under a time limit (`perl -e 'alarm shift; exec @ARGV' 300 ...`).
