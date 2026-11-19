# Hisoka — privacy-first offline dictation app — plan

Status: **decisions taken 2026-11-19** (name, price, free tier, minimum OS — see the end); name availability check and Windows payment choice still open. User decisions so far (2026-11-19): a separate app with its own
name; focus = privacy (audio and text never leave the device); paid; **macOS and iOS are both first
priority**; Windows also paid, sold directly with the user's Stripe account. Shinsoku itself stays key-first
(cloud providers, Free + Pro). Research: `research-20261119.md` next to this file.

## Positioning
"Speak, get clean text where you type — nothing leaves your device." Works in Airplane Mode, no account, App
Store label "Data Not Collected". The gap competitors leave: offline speech **and** offline AI cleanup, on
iPhone **and** Mac, with a dependable iOS keyboard and per-app profiles, for one fair one-time price
(VoiceInk: Mac only, cleanup mostly cloud; Superwhisper/Spokenly: cleanup needs cloud or keys; Wispr Flow:
cloud only).

## Name (user picks; then App Store / trademark / domain check)
| Candidate | Meaning | Note |
|---|---|---|
| **Hisoka** | 密か — privately, in secret | pairs with Shinsoku's Japanese naming; short |
| **Shizuka** | 静か — quiet | soft, but common word (search noise) |
| **Komoru** | 籠る — to stay inside | "stays on your device"; less known |
| *(user's own)* | | |

## Stack (recommendation)
- **One Flutter app** for iOS, macOS, Windows (same stack and pfstack practices as Shinsoku), new repo.
  Start by copying the Dart pieces it needs from Shinsoku (profiles, field rules, live transcript, record UI,
  keyboard extension) — no shared package yet; extract one later if both apps keep changing the same code.
- **Speech (engine interface in Dart, native plugins underneath):**
  - Apple (iOS/macOS 26+): **SpeechAnalyzer / SpeechTranscriber** — real live partials, all 10 languages,
    model supplied by the OS (one-time OS download per language), free. Default.
  - Optional downloads via **sherpa-onnx** (official Flutter plugin on all three platforms): **SenseVoice**
    (zh/yue/ja/ko, fast) and **Qwen3-ASR 0.6B** (all 10 languages; Mac and ≥6 GB iPhones, as a final pass);
    **Parakeet v3** for European languages. Licences checked per model before shipping (some FunASR models
    are labelled two ways; Parakeet needs CC BY attribution).
  - Windows default: sherpa-onnx + VAD with Qwen3-ASR 0.6B (all languages) and streaming Paraformer for zh/en
    live text.
- **Cleanup / translation:**
  - Apple (iOS/macOS 26+, Apple Intelligence devices): **Foundation Models** for cleanup (guided generation),
    **Translation framework** for zh/ja/ko → en. Free, zero download.
  - Fallback / older devices / Windows: a small open model (**Qwen3.5 0.8B–2B or Qwen3 0.6B–1.7B**, Apache 2.0)
    through **MLX Swift** (Apple) or **llama.cpp** (Windows; also Apple if memory matters).
  - Rules: never lose the user's words (any refusal/failure → raw transcript), stream output, skip the model
    for short utterances, low temperature. Expected: Mac < 1.5 s per paragraph; iPhone 15 Pro/16 several
    seconds → sentence-by-sentence + streaming.
- **Minimum OS:** iOS 26 / macOS 26 (both Apple engines need it; keeps one code path). Windows 10+.
- **iOS:** the keyboard can't use the microphone and has ~50–70 MB, so the app records and runs the models
  (same handoff as Shinsoku; make it the most reliable part — competitors' main complaint).
- **macOS:** menu-bar app, global hotkey, paste into the front app, per-app profiles by front app.
  Risk to verify first: pasting/Accessibility inside the Mac App Store sandbox.

## Pricing and sales (recommendation)
- **iOS + Mac: universal purchase** (one purchase covers both), free download with a limited free tier
  (e.g. speech only, no AI cleanup / one profile) and a one-time **"Lifetime" unlock, $19.99 (launch $14.99)**.
  Family Sharing on. No timed trial (converts poorly).
- **Windows: $24.99 one-time, sold directly.** Plain Stripe makes us the seller: EU VAT (non-Union OSS) from the
  first sale, UK registration, etc. Recommended: **Stripe Managed Payments** (Stripe as merchant of record —
  check our country is supported) or Polar/Paddle; licence = an **offline-verified signed licence** (Ed25519,
  public key in the app), so the app never phones home. Lemon Squeezy is closing (2027-03) — not an option.

## Iterations (proposed order)
| # | Iteration | Goal |
|---|---|---|
| P0 | Repo + pfstack init, name, copy of Shinsoku's Dart core, CI | builds an empty app on iOS + macOS |
| P1 | **Engine spike** (decides the defaults) | Apple SpeechTranscriber + Foundation Models + Translation vs SenseVoice / Qwen3-ASR / Qwen3.5 small: accuracy on our own clips in en/zh/yue/ja/ko/de, latency, memory, on Mac + iPhone (tier C) |
| P2 | macOS MVP | menu bar, hotkey, record → live text → cleanup → paste; profiles; sandbox check |
| P3 | iOS MVP | app + keyboard handoff, same engines |
| P4 | Purchase | StoreKit 2 universal unlock, free tier limits |
| P5 | Windows | sherpa-onnx + llama.cpp, Stripe licence |
| P6 | i18n (10 languages, reusing Shinsoku's glossary), store listing, privacy label | |

## Open decisions for the user
1. Name (table above, or your own).
2. Price: $19.99 universal (launch $14.99) + free tier, Windows $24.99 — or different.
3. Free tier: "speech only, no AI cleanup" vs "N dictations" vs no free tier (paid upfront).
4. Minimum OS 26 on Apple platforms (drops older iPhones/Macs).
5. Windows payments: Stripe Managed Payments (Stripe handles VAT) vs plain Stripe + our own VAT filing.

## User decisions (2026-11-19)
- Name: **Hisoka** (密か) — pending App Store / trademark / domain check.
- Price: universal iOS + Mac unlock **$9.99 (launch $6.99)**; Windows proposed **$12.99** (to confirm).
- Free tier: **speech recognition only**, unlimited; the unlock adds AI cleanup, translation, multiple profiles,
  per-app switching.
- Minimum OS: **iOS 26 / macOS 26**.
- Still open: Windows payments (Stripe Managed Payments recommended).
