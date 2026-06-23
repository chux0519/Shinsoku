# Shinsoku App Review Checklist

## Screenshots

iPhone 6.9-inch screenshots:
- `screenshots/iphone/01-voice-input.png`
- `screenshots/iphone/02-custom-profiles.png`
- `screenshots/iphone/03-profile-editor.png`
- `screenshots/iphone/04-provider-settings.png`
- `screenshots/iphone/05-draft-history.png`

iPad 13-inch screenshots:
- `screenshots/ipad/01-ipad-voice-input.png`
- `screenshots/ipad/02-ipad-custom-profiles.png`
- `screenshots/ipad/03-ipad-provider-settings.png`

Raw simulator captures:
- `source-captures/`

## App Privacy Suggestions

This is not legal advice. It is a conservative implementation-based starting point for App Store Connect's App Privacy questionnaire.

Tracking:
- No.

Data used to track users:
- None.

Data linked to the user:
- Generally none collected by Shinsoku itself.

Data not linked to the user:
- User Content > Audio Data: used for App Functionality when cloud transcription is enabled.
- User Content > Other User Content: transcript text and post-processing prompts used for App Functionality.
- Diagnostics: only declare if you add crash or analytics SDKs later.

Notes:
- Shinsoku does not currently include analytics or advertising SDKs.
- Provider settings and API keys are stored locally on device.
- User-selected cloud providers may process audio, transcript text, prompts, API keys, IP address, and request metadata under their own policies.
- Apple's guidance says you should know what data you and third-party partners collect, and data collected only for app functionality still needs to be declared when applicable.

## Review Information

Suggested review note:

Shinsoku is a voice input utility with an optional keyboard extension. Users configure their own speech/text provider credentials in Settings. The app records audio only after microphone permission is granted. Recorded audio is sent to the selected provider for transcription. Optional post-processing sends transcript text and the selected profile prompt to the configured text model. The keyboard extension inserts the latest Shinsoku text from the system clipboard when the user taps the insert control.

Sign-in required:
- No.

Demo account:
- Not required.

Reviewer configuration:
- If you want reviewers to test real transcription, provide temporary provider credentials in Review Notes or ship a default review configuration. Otherwise explain that users bring their own provider credentials.

## Remaining Manual Items

- Host the final privacy policy on a public HTTPS URL.
- Add a real support URL.
- Complete App Privacy answers.
- Complete age rating questionnaire.
- Confirm pricing and U.S. availability.
- Confirm screenshots are assigned to the U.S. English localization.
- Submit build `0.1.0 (13)` or a newer build if you make more code changes.
