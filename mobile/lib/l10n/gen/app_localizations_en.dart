// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonDone => 'Done';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonOpenSettings => 'Open Settings';

  @override
  String get tabRecord => 'Record';

  @override
  String get tabDrafts => 'Drafts';

  @override
  String get tabDesktop => 'Desktop';

  @override
  String get tabSettings => 'Settings';

  @override
  String get paneSwitcherLabel => 'Pane';

  @override
  String get recordPlaceholder => 'Tap the microphone and start speaking.';

  @override
  String get recordListeningPlaceholder => 'Listening…';

  @override
  String get recordProcessing => 'Processing…';

  @override
  String get recordTranscriptLabel => 'Transcript';

  @override
  String get recordCopied => 'Copied. Insert it from the keyboard or paste it.';

  @override
  String get recordSavedInsert => 'Saved. Insert it from the keyboard.';

  @override
  String get recordResultCopied =>
      'Copied. Paste it anywhere, or insert it from the keyboard.';

  @override
  String get recordStopped => 'Recording stopped';

  @override
  String get recordHeardTextKept =>
      'What was heard is kept here and in Drafts.';

  @override
  String get recordTryAgain => 'Record again';

  @override
  String get recordStatusReady => 'Ready to record';

  @override
  String get recordStatusListening => 'Listening';

  @override
  String get recordStatusListeningDetail =>
      'Tap stop when you are done speaking.';

  @override
  String get recordStatusTranscribing => 'Transcribing';

  @override
  String get recordTranscribed => 'Recording transcribed';

  @override
  String get recordTranscribingDetail =>
      'Uploading recorded audio to the selected provider.';

  @override
  String get recordFailed => 'Recording failed';

  @override
  String get recordMicOffLabel => 'Microphone access is off';

  @override
  String get recordMicOffDetail =>
      'Allow microphone access in iOS Settings, then try recording again.';

  @override
  String get recordRecorderNotReady =>
      'Microphone permission was granted but the recorder is not ready. Try again.';

  @override
  String get recordKeyRequiredLabel => 'Provider settings required';

  @override
  String get recordKeyRequiredDetail =>
      'Save a Bailian or Soniox API key before recording.';

  @override
  String get recordProfileLabel => 'Profile';

  @override
  String get recordButtonStart => 'Start recording';

  @override
  String get recordButtonStop => 'Stop recording';

  @override
  String get recordButtonUnavailable => 'Recording unavailable';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => 'set by you';

  @override
  String get profileReasonAutomation => 'set by automation';

  @override
  String get profileReasonDefault => 'default';

  @override
  String get draftsTitle => 'Drafts';

  @override
  String get draftsEmpty => 'Your transcripts appear here after you record.';

  @override
  String get draftsToday => 'Today';

  @override
  String get draftsYesterday => 'Yesterday';

  @override
  String get draftsCopyDraft => 'Copy draft';

  @override
  String get draftsDeleted => 'Draft deleted';

  @override
  String get draftsCopied => 'Draft copied to clipboard.';

  @override
  String get draftEditorTitle => 'Draft';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionRecognition => 'Recognition';

  @override
  String get settingsMicrophoneTitle => 'Microphone access';

  @override
  String get settingsMicrophoneAllowed => 'Allowed for voice capture';

  @override
  String get settingsMicrophoneTapToAllow => 'Tap to allow microphone access';

  @override
  String get settingsSpeechProvider => 'Speech provider';

  @override
  String get settingsPostProcessingTitle => 'Text post-processing';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return 'Use $model for cleanup or translation';
  }

  @override
  String get settingsCloudTitle => 'Cloud processing';

  @override
  String get settingsCloudSaved => 'Provider credentials are saved';

  @override
  String get settingsCloudNotSaved =>
      'Save provider credentials before real transcription';

  @override
  String get settingsLoading => 'Loading saved settings';

  @override
  String get settingsRealtimeModel => 'Realtime model';

  @override
  String get settingsRecognitionMode => 'Recognition mode';

  @override
  String get settingsModeStreaming => 'Streaming';

  @override
  String get settingsStreamingModel => 'Streaming ASR model';

  @override
  String get settingsBatchModel => 'Qwen-ASR batch model';

  @override
  String get settingsPostProcessingModel => 'Post-processing OpenAI model';

  @override
  String get settingsPostProcessingModelHelper =>
      'Used only when Text post-processing is on';

  @override
  String get settingsBaseUrl => 'OpenAI-compatible base URL';

  @override
  String get settingsRealtimeUrl => 'Realtime WebSocket URL';

  @override
  String get settingsSave => 'Save Settings';

  @override
  String get settingsSaving => 'Saving';

  @override
  String get settingsSaved => 'Provider settings saved';

  @override
  String settingsSaveFailed(String reason) {
    return 'Settings were not saved. $reason';
  }

  @override
  String get settingsSectionProfiles => 'Profiles';

  @override
  String get settingsAddProfile => 'Add profile';

  @override
  String get settingsUseInApps => 'Use in apps';

  @override
  String get settingsUseInAppsSubtitle => 'Switch profile when you open an app';

  @override
  String get settingsFieldRules => 'Field rules';

  @override
  String get settingsFieldRulesSubtitle =>
      'Search, web address, email, message';

  @override
  String get settingsSectionKeyboard => 'Keyboard';

  @override
  String get settingsKeyboardSetup => 'Keyboard setup';

  @override
  String get settingsKeyboardSetupSubtitle =>
      'Add Shinsoku and allow Full Access';

  @override
  String get settingsApiKey => 'API key';

  @override
  String get settingsShowKey => 'Show key';

  @override
  String get settingsHideKey => 'Hide key';

  @override
  String get keyboardSetupTitle => 'Keyboard';

  @override
  String get keyboardSetupIntro => 'Use Shinsoku from any text field.';

  @override
  String get keyboardStep1 => 'Open Settings › General › Keyboard › Keyboards.';

  @override
  String get keyboardStep2 => 'Tap Add New Keyboard and choose Shinsoku.';

  @override
  String get keyboardStep3 =>
      'Tap Shinsoku and turn on Allow Full Access, so the keyboard can insert your latest text.';

  @override
  String get useInAppsSummary =>
      'Shinsoku can switch profile by itself when you open an app. Shortcuts watches for the app; Shinsoku sets the profile.';

  @override
  String get useInAppsWhenOpened => 'When the app is opened';

  @override
  String get useInAppsWhenClosed => 'When the app is closed';

  @override
  String get useInAppsOpenStep1 =>
      'In Shortcuts, open Automation and tap New Automation.';

  @override
  String get useInAppsOpenStep2 =>
      'Choose App, pick the app, and select Is Opened. Turn on Run Immediately.';

  @override
  String get useInAppsOpenStep3 =>
      'Add the action Set Shinsoku Profile and choose the profile for that app.';

  @override
  String get useInAppsCloseStep1 =>
      'Add a second automation for the same app and select Is Closed. Turn on Run Immediately.';

  @override
  String get useInAppsCloseStep2 =>
      'Add Set Shinsoku Profile and choose your default profile, so other apps go back to it.';

  @override
  String get useInAppsKeyboardNote =>
      'You can also tap the profile name in the keyboard to switch. It stays until an automation runs again.';

  @override
  String get useInAppsReadyMade =>
      'Each profile also has a ready-made action in the Shortcuts app, such as “Switch Shinsoku to Chat”. No setup needed.';

  @override
  String get useInAppsIosNote => 'The Shortcuts actions need iOS 16 or later.';

  @override
  String get useInAppsOpenShortcuts => 'Open Shortcuts';

  @override
  String get fieldRulesTitle => 'Field rules';

  @override
  String get fieldRulesSummary =>
      'Use a profile automatically in certain kinds of field. It applies only when you have not picked a profile in the keyboard and no automation has set one.';

  @override
  String get fieldRulesNone => 'None';

  @override
  String get fieldKindSearch => 'Search';

  @override
  String get fieldKindUrl => 'Web address';

  @override
  String get fieldKindEmail => 'Email';

  @override
  String get fieldKindMessage => 'Message';

  @override
  String get profileNewTitle => 'New profile';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileNameLabel => 'Name';

  @override
  String get profilePromptLabel => 'Post-processing prompt';

  @override
  String get profilePromptHelper =>
      'Example: Translate Chinese speech into natural English.';

  @override
  String get profileAfterText => 'After the text';

  @override
  String get profileSuffixNothing => 'Nothing';

  @override
  String get profileSuffixSpace => 'Space';

  @override
  String get profileSuffixNewLine => 'New line';

  @override
  String get profileAutoCommit => 'Auto commit';

  @override
  String get profileAutoCommitSubtitle => 'Insert without a review step';

  @override
  String get profileDelete => 'Delete profile';

  @override
  String profileDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get profileKeepOne => 'Keep at least one profile';

  @override
  String get profileUntitled => 'Untitled';

  @override
  String get profileDefaultIntent =>
      'Clean up the transcript. Return only the final text.';

  @override
  String get profileDictationName => 'Dictation';

  @override
  String get profileDictationIntent => 'Clean speech into natural prose';

  @override
  String get profileChatName => 'Chat';

  @override
  String get profileChatIntent => 'Make the text concise and conversational';

  @override
  String get profileReviewName => 'Review';

  @override
  String get profileReviewIntent => 'Hold transcript for manual review';

  @override
  String get profileZhToEnName => 'ZH -> EN';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => 'Translate -> EN';

  @override
  String get profileTranslateToEnIntent =>
      'Translate the speech into natural English, whatever language it is in. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileJaToEnName => 'JA -> EN';

  @override
  String get profileJaToEnIntent =>
      'Translate Japanese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileKoToEnName => 'KO -> EN';

  @override
  String get profileKoToEnIntent =>
      'Translate Korean speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileDeToEnName => 'DE -> EN';

  @override
  String get profileDeToEnIntent =>
      'Translate German speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileEsToEnName => 'ES -> EN';

  @override
  String get profileEsToEnIntent =>
      'Translate Spanish speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileFrToEnName => 'FR -> EN';

  @override
  String get profileFrToEnIntent =>
      'Translate French speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profilePtToEnName => 'PT -> EN';

  @override
  String get profilePtToEnIntent =>
      'Translate Portuguese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileItToEnName => 'IT -> EN';

  @override
  String get profileItToEnIntent =>
      'Translate Italian speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get shellAlreadyRecording => 'Shinsoku is already recording.';

  @override
  String shellPostProcessingEnabled(String profile) {
    return 'Text post-processing enabled for $profile.';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return 'Post-processing setting was not saved. $reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return 'Could not copy the text. $reason';
  }

  @override
  String get failureTimeout =>
      'The provider took too long to answer. Check your connection and try again.';

  @override
  String get failureNetwork =>
      'No connection to the provider. Check your network and try again.';

  @override
  String get failureConnectionLost => 'The connection was lost. Try again.';

  @override
  String get failureKeyMissing => 'No API key is saved. Add one in Settings.';

  @override
  String get failureKeyInvalid =>
      'The provider did not accept your API key. Check it in Settings.';

  @override
  String get failureQuota =>
      'The provider reports no quota left or too many requests. Check your account.';

  @override
  String get failureNothingHeard => 'No speech was recognized. Try again.';

  @override
  String get failureRecording =>
      'The recording could not be completed. Try again.';

  @override
  String get failureMicrophone =>
      'The microphone is not available. Check microphone access in Settings.';

  @override
  String get failureGeneric => 'Something went wrong. Try again.';

  @override
  String get nearbyTitle => 'Desktop Mic';

  @override
  String get nearbySubtitle => 'Private local connection';

  @override
  String get nearbySectionDesktop => 'Desktop';

  @override
  String get nearbyFindDesktops => 'Find Desktops';

  @override
  String get nearbyAddManually => 'Add desktop manually';

  @override
  String get nearbyEndpointLabel => 'WSS endpoint';

  @override
  String get nearbyCertificateLabel => 'Certificate SHA-256';

  @override
  String get nearbyAdd => 'Add';

  @override
  String get nearbySectionTrust => 'Trust';

  @override
  String get nearbyTrustedDesktop => 'Trusted desktop';

  @override
  String get nearbyCertificateFingerprint => 'Certificate fingerprint';

  @override
  String get nearbyMatchesTitle => 'Matches desktop Settings';

  @override
  String get nearbyMatchesSubtitle => 'Compare it with Settings on the desktop';

  @override
  String get nearbyPairingCodeLabel => 'Pairing code shown on the desktop';

  @override
  String get nearbyDisconnect => 'Disconnect';

  @override
  String get nearbyConnect => 'Connect';

  @override
  String get nearbyPairAndConnect => 'Pair and Connect';

  @override
  String get nearbyForget => 'Forget desktop';

  @override
  String get nearbySectionRemoteInput => 'Remote input';

  @override
  String get nearbyProfileRow => 'Profile';

  @override
  String get nearbyProfileAutomatic => 'Desktop automatic';

  @override
  String get nearbyProfileSheetTitle => 'Desktop profile';

  @override
  String get nearbyStopAndTranscribe => 'Stop and transcribe';

  @override
  String get nearbyStartRemote => 'Start remote dictation';

  @override
  String get nearbyConnectToDictate =>
      'Connect to a desktop to dictate into it';

  @override
  String nearbyConnectingTo(String name) {
    return 'Connecting to $name';
  }

  @override
  String nearbyConnectedTo(String name) {
    return 'Connected to $name';
  }

  @override
  String get nearbyStreaming => 'Streaming microphone audio';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Streaming with $countString missing frames',
      one: 'Streaming with 1 missing frame',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => 'Recording sent to desktop';

  @override
  String get nearbyNotConnected => 'Not connected';

  @override
  String get nearbyDisconnected => 'Desktop disconnected';

  @override
  String get nearbySearching => 'Searching the local network';

  @override
  String get nearbyNoneFound => 'No Shinsoku desktop found';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString desktops found',
      one: '1 desktop found',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => 'Trusted desktop selected';

  @override
  String get nearbyVerifyFingerprint => 'Verify the desktop fingerprint';

  @override
  String get nearbyTrustRemoved => 'Local trust removed';

  @override
  String get nearbyErrorPairingCodeRequired =>
      'Enter the two-digit code shown on desktop.';

  @override
  String get nearbyErrorFingerprintInvalid =>
      'The certificate fingerprint is not valid. Enter all 64 hexadecimal characters.';

  @override
  String get nearbyErrorEndpointInvalid =>
      'Enter a valid wss:// host and port.';

  @override
  String get nearbyErrorCertificateChanged =>
      'The desktop certificate has changed. Forget it and pair again.';

  @override
  String get nearbyErrorCredentialMissing =>
      'This desktop remembers this device, but the local credential is missing. Revoke it on the desktop and pair again.';

  @override
  String get nearbyErrorPairingUnavailable =>
      'Create a pairing code in desktop Settings, then connect again.';

  @override
  String get nearbyErrorPairingExpired =>
      'The desktop pairing code expired. Create a new one.';

  @override
  String get nearbyErrorWrongCode => 'The pairing code is incorrect.';

  @override
  String get nearbyErrorAttemptsExhausted =>
      'Pairing attempts are used up. Create a new code on the desktop.';

  @override
  String get nearbyErrorDesktopBusy =>
      'The desktop is already recording or processing audio.';

  @override
  String get nearbyErrorConnectFirst =>
      'Connect to a desktop before recording.';

  @override
  String get nearbyErrorTimeout => 'The desktop did not respond in time.';

  @override
  String get nearbyErrorConnectionLost =>
      'The connection to the desktop was lost.';

  @override
  String get nearbyErrorMicDenied =>
      'Microphone access is required. Allow it in Settings.';

  @override
  String get nearbyErrorRecorderNotReady =>
      'The microphone is not ready. Try again.';

  @override
  String get nearbyErrorMicStream => 'The microphone stopped unexpectedly.';

  @override
  String get nearbyErrorDiscovery =>
      'Could not search the local network. Check Wi-Fi and try again.';

  @override
  String get nearbyErrorUnexpectedResponse =>
      'The desktop sent an unexpected response. Update Shinsoku on both devices and try again.';

  @override
  String get nearbyErrorGeneric =>
      'Something went wrong with the desktop connection.';

  @override
  String get proName => 'Shinsoku Pro';

  @override
  String get proBadge => 'Pro';

  @override
  String get proFeatureProfilesTitle => 'Custom profiles';

  @override
  String get proFeatureProfilesBody =>
      'Create your own profiles and edit any profile\'s prompt and settings.';

  @override
  String get proFeatureAutoTitle => 'Automatic switching per app';

  @override
  String get proFeatureAutoBody =>
      'Field rules and Shortcuts pick the profile for the app you\'re typing in.';

  @override
  String get proFeatureDesktopTitle => 'Desktop';

  @override
  String get proFeatureDesktopBody =>
      'Use this iPhone as the microphone for Shinsoku on your computer.';

  @override
  String get proNote => 'One-time purchase. Family Sharing included.';

  @override
  String proBuyWithPrice(String price) {
    return 'Unlock for $price';
  }

  @override
  String get proBuy => 'Unlock Shinsoku Pro';

  @override
  String get proPriceLoading => 'Loading price…';

  @override
  String get proRestore => 'Restore Purchases';

  @override
  String get proOwned => 'Shinsoku Pro is unlocked. Thank you!';

  @override
  String get proStatusUnlocked => 'Unlocked';

  @override
  String get proSettingsSubtitle =>
      'Custom profiles, per-app switching, Desktop';

  @override
  String get proNoticePending =>
      'Waiting for approval. Pro unlocks as soon as the purchase is approved.';

  @override
  String get proNoticeCancelled => 'Purchase cancelled. Nothing was charged.';

  @override
  String get proNoticeFailed =>
      'The purchase didn\'t go through. Please try again.';

  @override
  String get proNoticeUnavailable =>
      'The App Store isn\'t available right now. Try again later.';

  @override
  String get proNoticeRestored =>
      'Purchase restored. Shinsoku Pro is unlocked.';

  @override
  String get proNoticeNothingToRestore =>
      'No earlier purchase of Shinsoku Pro was found for this Apple Account.';

  @override
  String get proLockedProfileEditor =>
      'Editing profiles needs Shinsoku Pro. You can still pick this profile on the Record screen and in the keyboard.';

  @override
  String get proLockedFieldRules =>
      'Field rules need Shinsoku Pro. Rules you set are kept and apply again once Pro is unlocked.';

  @override
  String get proLockedUseInApps =>
      'Switching profiles from Shortcuts needs Shinsoku Pro.';

  @override
  String get proLockedDesktop =>
      'Use this iPhone as a wireless microphone for Shinsoku on your Mac or PC: speak here, the text lands on the computer. Desktop is part of Shinsoku Pro.';
}

/// The translations for English (`en_XA`).
class AppLocalizationsEnXa extends AppLocalizationsEn {
  AppLocalizationsEnXa() : super('en_XA');

  @override
  String get commonBack => '[Bàçk lö]';

  @override
  String get commonCancel => '[Çàñçél lö]';

  @override
  String get commonSave => '[Šàvé lö]';

  @override
  String get commonDelete => '[Đéléţé lö]';

  @override
  String get commonCopy => '[Çöpý lö]';

  @override
  String get commonDone => '[Đöñé lö]';

  @override
  String get commonClear => '[Çléàr lö]';

  @override
  String get commonUndo => '[Üñđö lö]';

  @override
  String get commonOpenSettings => '[Öpéñ Šéţţîñĝš löré]';

  @override
  String get tabRecord => '[Réçörđ lö]';

  @override
  String get tabDrafts => '[Đràfţš lö]';

  @override
  String get tabDesktop => '[Đéškţöp lö]';

  @override
  String get tabSettings => '[Šéţţîñĝš lö]';

  @override
  String get paneSwitcherLabel => '[Pàñé lö]';

  @override
  String get recordPlaceholder =>
      '[Ţàp ţhé mîçröphöñé àñđ šţàrţ špéàkîñĝ. lörém îpšüm đö]';

  @override
  String get recordListeningPlaceholder => '[Lîšţéñîñĝ… lör]';

  @override
  String get recordProcessing => '[Pröçéššîñĝ… lör]';

  @override
  String get recordTranscriptLabel => '[Ţràñšçrîpţ lör]';

  @override
  String get recordCopied =>
      '[Çöpîéđ. Îñšérţ îţ fröm ţhé kéýböàrđ ör pàšţé îţ. lörém îpšüm đölör]';

  @override
  String get recordSavedInsert =>
      '[Šàvéđ. Îñšérţ îţ fröm ţhé kéýböàrđ. lörém îpšüm đ]';

  @override
  String get recordResultCopied =>
      '[Çöpîéđ. Pàšţé îţ àñýwhéré, ör îñšérţ îţ fröm ţhé kéýböàrđ. lörém îpšüm đölör šîţ]';

  @override
  String get recordStopped => '[Réçörđîñĝ šţöppéđ lörém]';

  @override
  String get recordHeardTextKept =>
      '[Whàţ wàš héàrđ îš képţ héré àñđ îñ Đràfţš. lörém îpšüm đölö]';

  @override
  String get recordTryAgain => '[Réçörđ àĝàîñ löré]';

  @override
  String get recordStatusReady => '[Réàđý ţö réçörđ lörém]';

  @override
  String get recordStatusListening => '[Lîšţéñîñĝ lör]';

  @override
  String get recordStatusListeningDetail =>
      '[Ţàp šţöp whéñ ýöü àré đöñé špéàkîñĝ. lörém îpšüm đ]';

  @override
  String get recordStatusTranscribing => '[Ţràñšçrîbîñĝ löré]';

  @override
  String get recordTranscribed => '[Réçörđîñĝ ţràñšçrîbéđ lörém î]';

  @override
  String get recordTranscribingDetail =>
      '[Üplöàđîñĝ réçörđéđ àüđîö ţö ţhé šéléçţéđ prövîđér. lörém îpšüm đölör š]';

  @override
  String get recordFailed => '[Réçörđîñĝ fàîléđ lörém]';

  @override
  String get recordMicOffLabel => '[Mîçröphöñé àççéšš îš öff lörém îpš]';

  @override
  String get recordMicOffDetail =>
      '[Àllöw mîçröphöñé àççéšš îñ îÖŠ Šéţţîñĝš, ţhéñ ţrý réçörđîñĝ àĝàîñ. lörém îpšüm đölör šîţ àmé]';

  @override
  String get recordRecorderNotReady =>
      '[Mîçröphöñé pérmîššîöñ wàš ĝràñţéđ büţ ţhé réçörđér îš ñöţ réàđý. Ţrý àĝàîñ. lörém îpšüm đölör šîţ àméţ çö]';

  @override
  String get recordKeyRequiredLabel => '[Prövîđér šéţţîñĝš réqüîréđ lörém îpš]';

  @override
  String get recordKeyRequiredDetail =>
      '[Šàvé à Bàîlîàñ ör Šöñîöx ÀPÎ kéý béföré réçörđîñĝ. lörém îpšüm đölör š]';

  @override
  String get recordProfileLabel => '[Pröfîlé lö]';

  @override
  String get recordButtonStart => '[Šţàrţ réçörđîñĝ lörém]';

  @override
  String get recordButtonStop => '[Šţöp réçörđîñĝ lörém]';

  @override
  String get recordButtonUnavailable => '[Réçörđîñĝ üñàvàîlàblé lörém î]';

  @override
  String profileReasonLine(String name, String why) {
    return '[$name ·  lö$why]';
  }

  @override
  String get profileReasonManual => '[šéţ bý ýöü lör]';

  @override
  String get profileReasonAutomation => '[šéţ bý àüţömàţîöñ lörém]';

  @override
  String get profileReasonDefault => '[đéfàülţ lö]';

  @override
  String get draftsTitle => '[Đràfţš lö]';

  @override
  String get draftsEmpty =>
      '[Ýöür ţràñšçrîpţš àppéàr héré àfţér ýöü réçörđ. lörém îpšüm đölör]';

  @override
  String get draftsToday => '[Ţöđàý lö]';

  @override
  String get draftsYesterday => '[Ýéšţérđàý lör]';

  @override
  String get draftsCopyDraft => '[Çöpý đràfţ lör]';

  @override
  String get draftsDeleted => '[Đràfţ đéléţéđ löré]';

  @override
  String get draftsCopied => '[Đràfţ çöpîéđ ţö çlîpböàrđ. lörém îpš]';

  @override
  String get draftEditorTitle => '[Đràfţ lö]';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '[$time ·  lö$profile]';
  }

  @override
  String get settingsTitle => '[Šéţţîñĝš lö]';

  @override
  String get settingsSectionRecognition => '[Réçöĝñîţîöñ lör]';

  @override
  String get settingsMicrophoneTitle => '[Mîçröphöñé àççéšš lörém]';

  @override
  String get settingsMicrophoneAllowed =>
      '[Àllöwéđ för vöîçé çàpţüré lörém îpš]';

  @override
  String get settingsMicrophoneTapToAllow =>
      '[Ţàp ţö àllöw mîçröphöñé àççéšš lörém îpšüm]';

  @override
  String get settingsSpeechProvider => '[Špééçh prövîđér lörém]';

  @override
  String get settingsPostProcessingTitle => '[Ţéxţ pöšţ-pröçéššîñĝ lörém î]';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return '[Üšé  lö$model för çléàñüp ör ţràñšlàţîöñ lörém îpšü]';
  }

  @override
  String get settingsCloudTitle => '[Çlöüđ pröçéššîñĝ lörém]';

  @override
  String get settingsCloudSaved =>
      '[Prövîđér çréđéñţîàlš àré šàvéđ lörém îpšüm]';

  @override
  String get settingsCloudNotSaved =>
      '[Šàvé prövîđér çréđéñţîàlš béföré réàl ţràñšçrîpţîöñ lörém îpšüm đölör š]';

  @override
  String get settingsLoading => '[Löàđîñĝ šàvéđ šéţţîñĝš lörém îp]';

  @override
  String get settingsRealtimeModel => '[Réàlţîmé möđél lörém]';

  @override
  String get settingsRecognitionMode => '[Réçöĝñîţîöñ möđé lörém]';

  @override
  String get settingsModeStreaming => '[Šţréàmîñĝ lör]';

  @override
  String get settingsStreamingModel => '[Šţréàmîñĝ ÀŠR möđél lörém î]';

  @override
  String get settingsBatchModel => '[Qwéñ-ÀŠR bàţçh möđél lörém î]';

  @override
  String get settingsPostProcessingModel =>
      '[Pöšţ-pröçéššîñĝ ÖpéñÀÎ möđél lörém îpšü]';

  @override
  String get settingsPostProcessingModelHelper =>
      '[Üšéđ öñlý whéñ Ţéxţ pöšţ-pröçéššîñĝ îš öñ lörém îpšüm đöl]';

  @override
  String get settingsBaseUrl => '[ÖpéñÀÎ-çömpàţîblé bàšé ÜRL lörém îpš]';

  @override
  String get settingsRealtimeUrl => '[Réàlţîmé WébŠöçkéţ ÜRL lörém îp]';

  @override
  String get settingsSave => '[Šàvé Šéţţîñĝš löré]';

  @override
  String get settingsSaving => '[Šàvîñĝ lö]';

  @override
  String get settingsSaved => '[Prövîđér šéţţîñĝš šàvéđ lörém îp]';

  @override
  String settingsSaveFailed(String reason) {
    return '[Šéţţîñĝš wéré ñöţ šàvéđ.  lörém îpš$reason]';
  }

  @override
  String get settingsSectionProfiles => '[Pröfîléš lö]';

  @override
  String get settingsAddProfile => '[Àđđ pröfîlé lör]';

  @override
  String get settingsUseInApps => '[Üšé îñ àppš lör]';

  @override
  String get settingsUseInAppsSubtitle =>
      '[Šwîţçh pröfîlé whéñ ýöü öpéñ àñ àpp lörém îpšüm đ]';

  @override
  String get settingsFieldRules => '[Fîélđ rüléš lör]';

  @override
  String get settingsFieldRulesSubtitle =>
      '[Šéàrçh, wéb àđđréšš, émàîl, méššàĝé lörém îpšüm đ]';

  @override
  String get settingsSectionKeyboard => '[Kéýböàrđ lö]';

  @override
  String get settingsKeyboardSetup => '[Kéýböàrđ šéţüp lörém]';

  @override
  String get settingsKeyboardSetupSubtitle =>
      '[Àđđ Šhîñšökü àñđ àllöw Füll Àççéšš lörém îpšüm đ]';

  @override
  String get settingsApiKey => '[ÀPÎ kéý lö]';

  @override
  String get settingsShowKey => '[Šhöw kéý lö]';

  @override
  String get settingsHideKey => '[Hîđé kéý lö]';

  @override
  String get keyboardSetupTitle => '[Kéýböàrđ lö]';

  @override
  String get keyboardSetupIntro =>
      '[Üšé Šhîñšökü fröm àñý ţéxţ fîélđ. lörém îpšüm]';

  @override
  String get keyboardStep1 =>
      '[Öpéñ Šéţţîñĝš › Ĝéñéràl › Kéýböàrđ › Kéýböàrđš. lörém îpšüm đölör]';

  @override
  String get keyboardStep2 =>
      '[Ţàp Àđđ Ñéw Kéýböàrđ àñđ çhööšé Šhîñšökü. lörém îpšüm đöl]';

  @override
  String get keyboardStep3 =>
      '[Ţàp Šhîñšökü àñđ ţürñ öñ Àllöw Füll Àççéšš, šö ţhé kéýböàrđ çàñ îñšérţ ýöür làţéšţ ţéxţ. lörém îpšüm đölör šîţ àméţ çöñšéçţ]';

  @override
  String get useInAppsSummary =>
      '[Šhîñšökü çàñ šwîţçh pröfîlé bý îţšélf whéñ ýöü öpéñ àñ àpp. Šhörţçüţš wàţçhéš för ţhé àpp; Šhîñšökü šéţš ţhé pröfîlé. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšç]';

  @override
  String get useInAppsWhenOpened => '[Whéñ ţhé àpp îš öpéñéđ lörém îp]';

  @override
  String get useInAppsWhenClosed => '[Whéñ ţhé àpp îš çlöšéđ lörém îp]';

  @override
  String get useInAppsOpenStep1 =>
      '[Îñ Šhörţçüţš, öpéñ Àüţömàţîöñ àñđ ţàp Ñéw Àüţömàţîöñ. lörém îpšüm đölör šî]';

  @override
  String get useInAppsOpenStep2 =>
      '[Çhööšé Àpp, pîçk ţhé àpp, àñđ šéléçţ Îš Öpéñéđ. Ţürñ öñ Rüñ Îmméđîàţélý. lörém îpšüm đölör šîţ àméţ ç]';

  @override
  String get useInAppsOpenStep3 =>
      '[Àđđ ţhé àçţîöñ Šéţ Šhîñšökü Pröfîlé àñđ çhööšé ţhé pröfîlé för ţhàţ àpp. lörém îpšüm đölör šîţ àméţ ç]';

  @override
  String get useInAppsCloseStep1 =>
      '[Àđđ à šéçöñđ àüţömàţîöñ för ţhé šàmé àpp àñđ šéléçţ Îš Çlöšéđ. Ţürñ öñ Rüñ Îmméđîàţélý. lörém îpšüm đölör šîţ àméţ çöñšéçţ]';

  @override
  String get useInAppsCloseStep2 =>
      '[Àđđ Šéţ Šhîñšökü Pröfîlé àñđ çhööšé ýöür đéfàülţ pröfîlé, šö öţhér àppš ĝö bàçk ţö îţ. lörém îpšüm đölör šîţ àméţ çöñšéç]';

  @override
  String get useInAppsKeyboardNote =>
      '[Ýöü çàñ àlšö ţàp ţhé pröfîlé ñàmé îñ ţhé kéýböàrđ ţö šwîţçh. Îţ šţàýš üñţîl àñ àüţömàţîöñ rüñš àĝàîñ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür]';

  @override
  String get useInAppsReadyMade =>
      '[Éàçh pröfîlé àlšö hàš à réàđý-màđé àçţîöñ îñ ţhé Šhörţçüţš àpp, šüçh àš “Šwîţçh Šhîñšökü ţö Çhàţ”. Ñö šéţüp ñééđéđ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîš]';

  @override
  String get useInAppsIosNote =>
      '[Ţhé Šhörţçüţš àçţîöñš ñééđ îÖŠ 16 ör làţér. lörém îpšüm đölö]';

  @override
  String get useInAppsOpenShortcuts => '[Öpéñ Šhörţçüţš lörém]';

  @override
  String get fieldRulesTitle => '[Fîélđ rüléš lör]';

  @override
  String get fieldRulesSummary =>
      '[Üšé à pröfîlé àüţömàţîçàllý îñ çérţàîñ kîñđš öf fîélđ. Îţ àpplîéš öñlý whéñ ýöü hàvé ñöţ pîçkéđ à pröfîlé îñ ţhé kéýböàrđ àñđ ñö àüţömàţîöñ hàš šéţ öñé. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšçîñĝ élîţ šéđ đ]';

  @override
  String get fieldRulesNone => '[Ñöñé lö]';

  @override
  String get fieldKindSearch => '[Šéàrçh lö]';

  @override
  String get fieldKindUrl => '[Wéb àđđréšš lör]';

  @override
  String get fieldKindEmail => '[Émàîl lö]';

  @override
  String get fieldKindMessage => '[Méššàĝé lö]';

  @override
  String get profileNewTitle => '[Ñéw pröfîlé lör]';

  @override
  String get profileEditTitle => '[Éđîţ pröfîlé löré]';

  @override
  String get profileNameLabel => '[Ñàmé lö]';

  @override
  String get profilePromptLabel => '[Pöšţ-pröçéššîñĝ prömpţ lörém îp]';

  @override
  String get profilePromptHelper =>
      '[Éxàmplé: Ţràñšlàţé Çhîñéšé špééçh îñţö ñàţüràl Éñĝlîšh. lörém îpšüm đölör šîţ]';

  @override
  String get profileAfterText => '[Àfţér ţhé ţéxţ lörém]';

  @override
  String get profileSuffixNothing => '[Ñöţhîñĝ lö]';

  @override
  String get profileSuffixSpace => '[Špàçé lö]';

  @override
  String get profileSuffixNewLine => '[Ñéw lîñé lö]';

  @override
  String get profileAutoCommit => '[Àüţö çömmîţ lör]';

  @override
  String get profileAutoCommitSubtitle =>
      '[Îñšérţ wîţhöüţ à révîéw šţép lörém îpšü]';

  @override
  String get profileDelete => '[Đéléţé pröfîlé lörém]';

  @override
  String profileDeleteConfirm(String name) {
    return '[Đéléţé \" lö$name\"? lö]';
  }

  @override
  String get profileKeepOne => '[Kéép àţ léàšţ öñé pröfîlé lörém îpš]';

  @override
  String get profileUntitled => '[Üñţîţléđ lö]';

  @override
  String get profileDefaultIntent =>
      '[Çléàñ üp ţhé ţràñšçrîpţ. Réţürñ öñlý ţhé fîñàl ţéxţ. lörém îpšüm đölör šî]';

  @override
  String get profileDictationName => '[Đîçţàţîöñ lör]';

  @override
  String get profileDictationIntent =>
      '[Çléàñ špééçh îñţö ñàţüràl pröšé lörém îpšüm]';

  @override
  String get profileChatName => '[Çhàţ lö]';

  @override
  String get profileChatIntent =>
      '[Màké ţhé ţéxţ çöñçîšé àñđ çöñvéršàţîöñàl lörém îpšüm đöl]';

  @override
  String get profileReviewName => '[Révîéw lö]';

  @override
  String get profileReviewIntent =>
      '[Hölđ ţràñšçrîpţ för màñüàl révîéw lörém îpšüm]';

  @override
  String get profileZhToEnName => '[ZH -> ÉÑ lö]';

  @override
  String get profileZhToEnIntent =>
      '[Ţràñšlàţé Çhîñéšé špééçh îñţö ñàţüràl Éñĝlîšh. Préšérvé ţhé méàñîñĝ, kéép îţ çöñçîšé, àñđ réţürñ öñlý ţhé Éñĝlîšh ţéxţ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšçî]';

  @override
  String get profileTranslateToEnName => '[Ţràñšlàţé -> ÉÑ lörém]';

  @override
  String get profileTranslateToEnIntent =>
      '[Ţràñšlàţé ţhé špééçh îñţö ñàţüràl Éñĝlîšh, whàţévér làñĝüàĝé îţ îš îñ. Préšérvé ţhé méàñîñĝ, kéép îţ çöñçîšé, àñđ réţürñ öñlý ţhé Éñĝlîšh ţéxţ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšçîñĝ élîţ š]';

  @override
  String get profileJaToEnName => '[JÀ -> ÉÑ lö]';

  @override
  String get profileJaToEnIntent =>
      '[Ţràñšlàţé Jàpàñéšé špééçh îñţö ñàţüràl Éñĝlîšh. Préšérvé ţhé méàñîñĝ, kéép îţ çöñçîšé, àñđ réţürñ öñlý ţhé Éñĝlîšh ţéxţ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšçî]';

  @override
  String get profileKoToEnName => '[KÖ -> ÉÑ lö]';

  @override
  String get profileKoToEnIntent =>
      '[Ţràñšlàţé Köréàñ špééçh îñţö ñàţüràl Éñĝlîšh. Préšérvé ţhé méàñîñĝ, kéép îţ çöñçîšé, àñđ réţürñ öñlý ţhé Éñĝlîšh ţéxţ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšç]';

  @override
  String get profileDeToEnName => '[ĐÉ -> ÉÑ lö]';

  @override
  String get profileDeToEnIntent =>
      '[Ţràñšlàţé Ĝérmàñ špééçh îñţö ñàţüràl Éñĝlîšh. Préšérvé ţhé méàñîñĝ, kéép îţ çöñçîšé, àñđ réţürñ öñlý ţhé Éñĝlîšh ţéxţ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšç]';

  @override
  String get profileEsToEnName => '[ÉŠ -> ÉÑ lö]';

  @override
  String get profileEsToEnIntent =>
      '[Ţràñšlàţé Špàñîšh špééçh îñţö ñàţüràl Éñĝlîšh. Préšérvé ţhé méàñîñĝ, kéép îţ çöñçîšé, àñđ réţürñ öñlý ţhé Éñĝlîšh ţéxţ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšçî]';

  @override
  String get profileFrToEnName => '[FR -> ÉÑ lö]';

  @override
  String get profileFrToEnIntent =>
      '[Ţràñšlàţé Fréñçh špééçh îñţö ñàţüràl Éñĝlîšh. Préšérvé ţhé méàñîñĝ, kéép îţ çöñçîšé, àñđ réţürñ öñlý ţhé Éñĝlîšh ţéxţ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšç]';

  @override
  String get profilePtToEnName => '[PŢ -> ÉÑ lö]';

  @override
  String get profilePtToEnIntent =>
      '[Ţràñšlàţé Pörţüĝüéšé špééçh îñţö ñàţüràl Éñĝlîšh. Préšérvé ţhé méàñîñĝ, kéép îţ çöñçîšé, àñđ réţürñ öñlý ţhé Éñĝlîšh ţéxţ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšçîñ]';

  @override
  String get profileItToEnName => '[ÎŢ -> ÉÑ lö]';

  @override
  String get profileItToEnIntent =>
      '[Ţràñšlàţé Îţàlîàñ špééçh îñţö ñàţüràl Éñĝlîšh. Préšérvé ţhé méàñîñĝ, kéép îţ çöñçîšé, àñđ réţürñ öñlý ţhé Éñĝlîšh ţéxţ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšçî]';

  @override
  String get shellAlreadyRecording =>
      '[Šhîñšökü îš àlréàđý réçörđîñĝ. lörém îpšüm]';

  @override
  String shellPostProcessingEnabled(String profile) {
    return '[Ţéxţ pöšţ-pröçéššîñĝ éñàbléđ för  lörém îpšüm$profile. lö]';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return '[Pöšţ-pröçéššîñĝ šéţţîñĝ wàš ñöţ šàvéđ.  lörém îpšüm đöl$reason]';
  }

  @override
  String shellClipboardFailed(String reason) {
    return '[Çöülđ ñöţ çöpý ţhé ţéxţ.  lörém îpš$reason]';
  }

  @override
  String get failureTimeout =>
      '[Ţhé prövîđér ţöök ţöö löñĝ ţö àñšwér. Çhéçk ýöür çöññéçţîöñ àñđ ţrý àĝàîñ. lörém îpšüm đölör šîţ àméţ çö]';

  @override
  String get failureNetwork =>
      '[Ñö çöññéçţîöñ ţö ţhé prövîđér. Çhéçk ýöür ñéţwörk àñđ ţrý àĝàîñ. lörém îpšüm đölör šîţ àmé]';

  @override
  String get failureConnectionLost =>
      '[Ţhé çöññéçţîöñ wàš löšţ. Ţrý àĝàîñ. lörém îpšüm đ]';

  @override
  String get failureKeyMissing =>
      '[Ñö ÀPÎ kéý îš šàvéđ. Àđđ öñé îñ Šéţţîñĝš. lörém îpšüm đöl]';

  @override
  String get failureKeyInvalid =>
      '[Ţhé prövîđér đîđ ñöţ àççépţ ýöür ÀPÎ kéý. Çhéçk îţ îñ Šéţţîñĝš. lörém îpšüm đölör šîţ àm]';

  @override
  String get failureQuota =>
      '[Ţhé prövîđér répörţš ñö qüöţà léfţ ör ţöö màñý réqüéšţš. Çhéçk ýöür àççöüñţ. lörém îpšüm đölör šîţ àméţ çö]';

  @override
  String get failureNothingHeard =>
      '[Ñö špééçh wàš réçöĝñîzéđ. Ţrý àĝàîñ. lörém îpšüm đ]';

  @override
  String get failureRecording =>
      '[Ţhé réçörđîñĝ çöülđ ñöţ bé çömpléţéđ. Ţrý àĝàîñ. lörém îpšüm đölör]';

  @override
  String get failureMicrophone =>
      '[Ţhé mîçröphöñé îš ñöţ àvàîlàblé. Çhéçk mîçröphöñé àççéšš îñ Šéţţîñĝš. lörém îpšüm đölör šîţ àméţ]';

  @override
  String get failureGeneric => '[Šöméţhîñĝ wéñţ wröñĝ. Ţrý àĝàîñ. lörém îpšüm]';

  @override
  String get nearbyTitle => '[Đéškţöp Mîç lör]';

  @override
  String get nearbySubtitle => '[Prîvàţé löçàl çöññéçţîöñ lörém îpš]';

  @override
  String get nearbySectionDesktop => '[Đéškţöp lö]';

  @override
  String get nearbyFindDesktops => '[Fîñđ Đéškţöpš löré]';

  @override
  String get nearbyAddManually => '[Àđđ đéškţöp màñüàllý lörém î]';

  @override
  String get nearbyEndpointLabel => '[WŠŠ éñđpöîñţ löré]';

  @override
  String get nearbyCertificateLabel => '[Çérţîfîçàţé ŠHÀ-256 lörém î]';

  @override
  String get nearbyAdd => '[Àđđ lö]';

  @override
  String get nearbySectionTrust => '[Ţrüšţ lö]';

  @override
  String get nearbyTrustedDesktop => '[Ţrüšţéđ đéškţöp lörém]';

  @override
  String get nearbyCertificateFingerprint =>
      '[Çérţîfîçàţé fîñĝérprîñţ lörém îp]';

  @override
  String get nearbyMatchesTitle => '[Màţçhéš đéškţöp Šéţţîñĝš lörém îpš]';

  @override
  String get nearbyMatchesSubtitle =>
      '[Çömpàré îţ wîţh Šéţţîñĝš öñ ţhé đéškţöp lörém îpšüm đöl]';

  @override
  String get nearbyPairingCodeLabel =>
      '[Pàîrîñĝ çöđé šhöwñ öñ ţhé đéškţöp lörém îpšüm]';

  @override
  String get nearbyDisconnect => '[Đîšçöññéçţ lör]';

  @override
  String get nearbyConnect => '[Çöññéçţ lö]';

  @override
  String get nearbyPairAndConnect => '[Pàîr àñđ Çöññéçţ lörém]';

  @override
  String get nearbyForget => '[Förĝéţ đéškţöp lörém]';

  @override
  String get nearbySectionRemoteInput => '[Rémöţé îñpüţ löré]';

  @override
  String get nearbyProfileRow => '[Pröfîlé lö]';

  @override
  String get nearbyProfileAutomatic => '[Đéškţöp àüţömàţîç lörém]';

  @override
  String get nearbyProfileSheetTitle => '[Đéškţöp pröfîlé lörém]';

  @override
  String get nearbyStopAndTranscribe => '[Šţöp àñđ ţràñšçrîbé lörém î]';

  @override
  String get nearbyStartRemote => '[Šţàrţ rémöţé đîçţàţîöñ lörém îp]';

  @override
  String get nearbyConnectToDictate =>
      '[Çöññéçţ ţö à đéškţöp ţö đîçţàţé îñţö îţ lörém îpšüm đöl]';

  @override
  String nearbyConnectingTo(String name) {
    return '[Çöññéçţîñĝ ţö  lörém$name]';
  }

  @override
  String nearbyConnectedTo(String name) {
    return '[Çöññéçţéđ ţö  löré$name]';
  }

  @override
  String get nearbyStreaming => '[Šţréàmîñĝ mîçröphöñé àüđîö lörém îpš]';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Šţréàmîñĝ wîţh  lörém$countString mîššîñĝ fràméš lörém',
      one: 'Šţréàmîñĝ wîţh 1 mîššîñĝ fràmé lörém îpšüm',
    );
    return '[$_temp0]';
  }

  @override
  String get nearbyRecordingSent => '[Réçörđîñĝ šéñţ ţö đéškţöp lörém îpš]';

  @override
  String get nearbyNotConnected => '[Ñöţ çöññéçţéđ löré]';

  @override
  String get nearbyDisconnected => '[Đéškţöp đîšçöññéçţéđ lörém î]';

  @override
  String get nearbySearching => '[Šéàrçhîñĝ ţhé löçàl ñéţwörk lörém îpšü]';

  @override
  String get nearbyNoneFound => '[Ñö Šhîñšökü đéškţöp föüñđ lörém îpš]';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString đéškţöpš föüñđ lörém',
      one: '1 đéškţöp föüñđ lörém',
    );
    return '[$_temp0]';
  }

  @override
  String get nearbyTrustedSelected => '[Ţrüšţéđ đéškţöp šéléçţéđ lörém îpš]';

  @override
  String get nearbyVerifyFingerprint =>
      '[Vérîfý ţhé đéškţöp fîñĝérprîñţ lörém îpšüm]';

  @override
  String get nearbyTrustRemoved => '[Löçàl ţrüšţ rémövéđ lörém î]';

  @override
  String get nearbyErrorPairingCodeRequired =>
      '[Éñţér ţhé ţwö-đîĝîţ çöđé šhöwñ öñ đéškţöp. lörém îpšüm đölö]';

  @override
  String get nearbyErrorFingerprintInvalid =>
      '[Ţhé çérţîfîçàţé fîñĝérprîñţ îš ñöţ vàlîđ. Éñţér àll 64 héxàđéçîmàl çhàràçţérš. lörém îpšüm đölör šîţ àméţ çöñ]';

  @override
  String get nearbyErrorEndpointInvalid =>
      '[Éñţér à vàlîđ wšš:// höšţ àñđ pörţ. lörém îpšüm đ]';

  @override
  String get nearbyErrorCertificateChanged =>
      '[Ţhé đéškţöp çérţîfîçàţé hàš çhàñĝéđ. Förĝéţ îţ àñđ pàîr àĝàîñ. lörém îpšüm đölör šîţ àm]';

  @override
  String get nearbyErrorCredentialMissing =>
      '[Ţhîš đéškţöp rémémbérš ţhîš đévîçé, büţ ţhé löçàl çréđéñţîàl îš mîššîñĝ. Révöké îţ öñ ţhé đéškţöp àñđ pàîr àĝàîñ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpî]';

  @override
  String get nearbyErrorPairingUnavailable =>
      '[Çréàţé à pàîrîñĝ çöđé îñ đéškţöp Šéţţîñĝš, ţhéñ çöññéçţ àĝàîñ. lörém îpšüm đölör šîţ àm]';

  @override
  String get nearbyErrorPairingExpired =>
      '[Ţhé đéškţöp pàîrîñĝ çöđé éxpîréđ. Çréàţé à ñéw öñé. lörém îpšüm đölör š]';

  @override
  String get nearbyErrorWrongCode =>
      '[Ţhé pàîrîñĝ çöđé îš îñçörréçţ. lörém îpšüm]';

  @override
  String get nearbyErrorAttemptsExhausted =>
      '[Pàîrîñĝ àţţémpţš àré üšéđ üp. Çréàţé à ñéw çöđé öñ ţhé đéškţöp. lörém îpšüm đölör šîţ àm]';

  @override
  String get nearbyErrorDesktopBusy =>
      '[Ţhé đéškţöp îš àlréàđý réçörđîñĝ ör pröçéššîñĝ àüđîö. lörém îpšüm đölör šî]';

  @override
  String get nearbyErrorConnectFirst =>
      '[Çöññéçţ ţö à đéškţöp béföré réçörđîñĝ. lörém îpšüm đö]';

  @override
  String get nearbyErrorTimeout =>
      '[Ţhé đéškţöp đîđ ñöţ réšpöñđ îñ ţîmé. lörém îpšüm đ]';

  @override
  String get nearbyErrorConnectionLost =>
      '[Ţhé çöññéçţîöñ ţö ţhé đéškţöp wàš löšţ. lörém îpšüm đöl]';

  @override
  String get nearbyErrorMicDenied =>
      '[Mîçröphöñé àççéšš îš réqüîréđ. Àllöw îţ îñ Šéţţîñĝš. lörém îpšüm đölör šî]';

  @override
  String get nearbyErrorRecorderNotReady =>
      '[Ţhé mîçröphöñé îš ñöţ réàđý. Ţrý àĝàîñ. lörém îpšüm đöl]';

  @override
  String get nearbyErrorMicStream =>
      '[Ţhé mîçröphöñé šţöppéđ üñéxpéçţéđlý. lörém îpšüm đ]';

  @override
  String get nearbyErrorDiscovery =>
      '[Çöülđ ñöţ šéàrçh ţhé löçàl ñéţwörk. Çhéçk Wî-Fî àñđ ţrý àĝàîñ. lörém îpšüm đölör šîţ àm]';

  @override
  String get nearbyErrorUnexpectedResponse =>
      '[Ţhé đéškţöp šéñţ àñ üñéxpéçţéđ réšpöñšé. Üpđàţé Šhîñšökü öñ böţh đévîçéš àñđ ţrý àĝàîñ. lörém îpšüm đölör šîţ àméţ çöñšéçţ]';

  @override
  String get nearbyErrorGeneric =>
      '[Šöméţhîñĝ wéñţ wröñĝ wîţh ţhé đéškţöp çöññéçţîöñ. lörém îpšüm đölör š]';

  @override
  String get proName => '[Šhîñšökü Prö löré]';

  @override
  String get proBadge => '[Prö lö]';

  @override
  String get proFeatureProfilesTitle => '[Çüšţöm pröfîléš lörém]';

  @override
  String get proFeatureProfilesBody =>
      '[Çréàţé ýöür öwñ pröfîléš àñđ éđîţ àñý pröfîlé\'š prömpţ àñđ šéţţîñĝš. lörém îpšüm đölör šîţ àméţ]';

  @override
  String get proFeatureAutoTitle => '[Àüţömàţîç šwîţçhîñĝ pér àpp lörém îpšü]';

  @override
  String get proFeatureAutoBody =>
      '[Fîélđ rüléš àñđ Šhörţçüţš pîçk ţhé pröfîlé för ţhé àpp ýöü\'ré ţýpîñĝ îñ. lörém îpšüm đölör šîţ àméţ ç]';

  @override
  String get proFeatureDesktopTitle => '[Đéškţöp lö]';

  @override
  String get proFeatureDesktopBody =>
      '[Üšé ţhîš îPhöñé àš ţhé mîçröphöñé för Šhîñšökü öñ ýöür çömpüţér. lörém îpšüm đölör šîţ àmé]';

  @override
  String get proNote =>
      '[Öñé-ţîmé pürçhàšé. Fàmîlý Šhàrîñĝ îñçlüđéđ. lörém îpšüm đölö]';

  @override
  String proBuyWithPrice(String price) {
    return '[Üñlöçk för  lör$price]';
  }

  @override
  String get proBuy => '[Üñlöçk Šhîñšökü Prö lörém î]';

  @override
  String get proPriceLoading => '[Löàđîñĝ prîçé… lörém]';

  @override
  String get proRestore => '[Réšţöré Pürçhàšéš lörém]';

  @override
  String get proOwned => '[Šhîñšökü Prö îš üñlöçkéđ. Ţhàñk ýöü! lörém îpšüm đ]';

  @override
  String get proStatusUnlocked => '[Üñlöçkéđ lö]';

  @override
  String get proSettingsSubtitle =>
      '[Çüšţöm pröfîléš, pér-àpp šwîţçhîñĝ, Đéškţöp lörém îpšüm đölö]';

  @override
  String get proNoticePending =>
      '[Wàîţîñĝ för àpprövàl. Prö üñlöçkš àš šööñ àš ţhé pürçhàšé îš àpprövéđ. lörém îpšüm đölör šîţ àméţ]';

  @override
  String get proNoticeCancelled =>
      '[Pürçhàšé çàñçélléđ. Ñöţhîñĝ wàš çhàrĝéđ. lörém îpšüm đöl]';

  @override
  String get proNoticeFailed =>
      '[Ţhé pürçhàšé đîđñ\'ţ ĝö ţhröüĝh. Pléàšé ţrý àĝàîñ. lörém îpšüm đölör š]';

  @override
  String get proNoticeUnavailable =>
      '[Ţhé Àpp Šţöré îšñ\'ţ àvàîlàblé rîĝhţ ñöw. Ţrý àĝàîñ làţér. lörém îpšüm đölör šîţ]';

  @override
  String get proNoticeRestored =>
      '[Pürçhàšé réšţöréđ. Šhîñšökü Prö îš üñlöçkéđ. lörém îpšüm đölör]';

  @override
  String get proNoticeNothingToRestore =>
      '[Ñö éàrlîér pürçhàšé öf Šhîñšökü Prö wàš föüñđ för ţhîš Àpplé Àççöüñţ. lörém îpšüm đölör šîţ àméţ]';

  @override
  String get proLockedProfileEditor =>
      '[Éđîţîñĝ pröfîléš ñééđš Šhîñšökü Prö. Ýöü çàñ šţîll pîçk ţhîš pröfîlé öñ ţhé Réçörđ šçrééñ àñđ îñ ţhé kéýböàrđ. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîp]';

  @override
  String get proLockedFieldRules =>
      '[Fîélđ rüléš ñééđ Šhîñšökü Prö. Rüléš ýöü šéţ àré képţ àñđ àpplý àĝàîñ öñçé Prö îš üñlöçkéđ. lörém îpšüm đölör šîţ àméţ çöñšéçţé]';

  @override
  String get proLockedUseInApps =>
      '[Šwîţçhîñĝ pröfîléš fröm Šhörţçüţš ñééđš Šhîñšökü Prö. lörém îpšüm đölör šî]';

  @override
  String get proLockedDesktop =>
      '[Üšé ţhîš îPhöñé àš à wîréléšš mîçröphöñé för Šhîñšökü öñ ýöür Màç ör PÇ: špéàk héré, ţhé ţéxţ làñđš öñ ţhé çömpüţér. Đéškţöp îš pàrţ öf Šhîñšökü Prö. lörém îpšüm đölör šîţ àméţ çöñšéçţéţür àđîpîšçîñĝ élîţ šéđ]';
}
