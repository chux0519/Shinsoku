import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('en', 'XA'),
  ];

  /// Tooltip of back buttons and the accessibility label of the back arrow.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Button that dismisses a sheet or dialog without changing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Button that saves the current edit.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Button or swipe label that deletes an item.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Button label and tooltip that copies text to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// Button that finishes editing the transcript on the Record screen.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Menu item that empties the transcript text.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// Snack bar action that restores something just deleted.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// Button that opens the iOS Settings app.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get commonOpenSettings;

  /// Bottom tab: the recording screen. One word.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get tabRecord;

  /// Bottom tab: the list of saved transcripts. One word.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get tabDrafts;

  /// Bottom tab: use the phone as a microphone for a computer. One word.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get tabDesktop;

  /// Bottom tab: app settings. One word.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// Accessibility label of the switch that chooses which page the second pane shows (Drafts, Desktop, Settings) on a foldable.
  ///
  /// In en, this message translates to:
  /// **'Pane'**
  String get paneSwitcherLabel;

  /// Placeholder in the empty transcript area on the Record screen.
  ///
  /// In en, this message translates to:
  /// **'Tap the microphone and start speaking.'**
  String get recordPlaceholder;

  /// Placeholder in the transcript area while the microphone is open and nothing was heard yet.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get recordListeningPlaceholder;

  /// Status text while the final text is being produced.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get recordProcessing;

  /// Accessibility label of the transcript text area.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get recordTranscriptLabel;

  /// Snack bar after copying the transcript.
  ///
  /// In en, this message translates to:
  /// **'Copied. Insert it from the keyboard or paste it.'**
  String get recordCopied;

  /// Confirmation that an edit was saved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get recordSaved;

  /// Status line after tapping Done on an edited transcript.
  ///
  /// In en, this message translates to:
  /// **'Saved. Insert it from the keyboard.'**
  String get recordSavedInsert;

  /// Status line detail after a recording finished; the text was copied automatically.
  ///
  /// In en, this message translates to:
  /// **'Copied. Paste it anywhere, or insert it from the keyboard.'**
  String get recordResultCopied;

  /// Status when a recording ended early because of a problem.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped'**
  String get recordStopped;

  /// Status detail: the words recognized before a failure are not lost.
  ///
  /// In en, this message translates to:
  /// **'What was heard is kept here and in Drafts.'**
  String get recordHeardTextKept;

  /// Button on the status line that starts a new recording after a failure.
  ///
  /// In en, this message translates to:
  /// **'Record again'**
  String get recordTryAgain;

  /// Status line when idle.
  ///
  /// In en, this message translates to:
  /// **'Ready to record'**
  String get recordStatusReady;

  /// Status line while recording.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get recordStatusListening;

  /// Detail under the Listening status.
  ///
  /// In en, this message translates to:
  /// **'Tap stop when you are done speaking.'**
  String get recordStatusListeningDetail;

  /// Status line and accessibility label while the recording is turned into text.
  ///
  /// In en, this message translates to:
  /// **'Transcribing'**
  String get recordStatusTranscribing;

  /// Status line after a recording was turned into text.
  ///
  /// In en, this message translates to:
  /// **'Recording transcribed'**
  String get recordTranscribed;

  /// Detail while the recording is sent to the speech provider.
  ///
  /// In en, this message translates to:
  /// **'Uploading recorded audio to the selected provider.'**
  String get recordTranscribingDetail;

  /// Status line when a recording could not start or finish.
  ///
  /// In en, this message translates to:
  /// **'Recording failed'**
  String get recordFailed;

  /// Status line when the microphone permission is denied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off'**
  String get recordMicOffLabel;

  /// Detail telling how to fix the denied microphone permission.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access in iOS Settings, then try recording again.'**
  String get recordMicOffDetail;

  /// Detail when the recorder cannot start.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission was granted but the recorder is not ready. Try again.'**
  String get recordRecorderNotReady;

  /// Status line when no speech provider key is saved.
  ///
  /// In en, this message translates to:
  /// **'Provider settings required'**
  String get recordKeyRequiredLabel;

  /// Detail asking for an API key. Bailian and Soniox are provider names.
  ///
  /// In en, this message translates to:
  /// **'Save a Bailian or Soniox API key before recording.'**
  String get recordKeyRequiredDetail;

  /// Accessibility label of the profile selector under the transcript.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get recordProfileLabel;

  /// Accessibility label of the record button when idle.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get recordButtonStart;

  /// Accessibility label of the record button while recording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get recordButtonStop;

  /// Accessibility label of the record button when it cannot be used.
  ///
  /// In en, this message translates to:
  /// **'Recording unavailable'**
  String get recordButtonUnavailable;

  /// Line under the status: the active profile and why it is active. {why} is one of the next three strings.
  ///
  /// In en, this message translates to:
  /// **'{name} · {why}'**
  String profileReasonLine(String name, String why);

  /// Why the profile is active: the user picked it.
  ///
  /// In en, this message translates to:
  /// **'set by you'**
  String get profileReasonManual;

  /// Why the profile is active: a Shortcuts automation set it.
  ///
  /// In en, this message translates to:
  /// **'set by automation'**
  String get profileReasonAutomation;

  /// Why the profile is active: it is the default.
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get profileReasonDefault;

  /// Page title of the saved transcripts list.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get draftsTitle;

  /// Empty state of the Drafts list.
  ///
  /// In en, this message translates to:
  /// **'Your transcripts appear here after you record.'**
  String get draftsEmpty;

  /// Date group heading.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get draftsToday;

  /// Date group heading.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get draftsYesterday;

  /// Tooltip of the copy button on a draft row.
  ///
  /// In en, this message translates to:
  /// **'Copy draft'**
  String get draftsCopyDraft;

  /// Snack bar after deleting a draft.
  ///
  /// In en, this message translates to:
  /// **'Draft deleted'**
  String get draftsDeleted;

  /// Snack bar after copying a draft.
  ///
  /// In en, this message translates to:
  /// **'Draft copied to clipboard.'**
  String get draftsCopied;

  /// Title of the draft editor page.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draftEditorTitle;

  /// Caption in the draft editor: when it was recorded and with which profile.
  ///
  /// In en, this message translates to:
  /// **'{time} · {profile}'**
  String draftEditorCaptured(String time, String profile);

  /// Page title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Section label for speech recognition settings.
  ///
  /// In en, this message translates to:
  /// **'Recognition'**
  String get settingsSectionRecognition;

  /// Settings row title.
  ///
  /// In en, this message translates to:
  /// **'Microphone access'**
  String get settingsMicrophoneTitle;

  /// Row subtitle when the microphone permission is granted.
  ///
  /// In en, this message translates to:
  /// **'Allowed for voice capture'**
  String get settingsMicrophoneAllowed;

  /// Row subtitle when the microphone permission is not granted.
  ///
  /// In en, this message translates to:
  /// **'Tap to allow microphone access'**
  String get settingsMicrophoneTapToAllow;

  /// Accessibility label of the provider switch (Bailian / Soniox).
  ///
  /// In en, this message translates to:
  /// **'Speech provider'**
  String get settingsSpeechProvider;

  /// Settings row: use an AI model to clean up or translate the transcript.
  ///
  /// In en, this message translates to:
  /// **'Text post-processing'**
  String get settingsPostProcessingTitle;

  /// Subtitle of the post-processing row. {model} is a model name.
  ///
  /// In en, this message translates to:
  /// **'Use {model} for cleanup or translation'**
  String settingsPostProcessingSubtitle(String model);

  /// Settings row title.
  ///
  /// In en, this message translates to:
  /// **'Cloud processing'**
  String get settingsCloudTitle;

  /// Row subtitle when an API key is stored.
  ///
  /// In en, this message translates to:
  /// **'Provider credentials are saved'**
  String get settingsCloudSaved;

  /// Row subtitle when no API key is stored.
  ///
  /// In en, this message translates to:
  /// **'Save provider credentials before real transcription'**
  String get settingsCloudNotSaved;

  /// Status while stored settings load.
  ///
  /// In en, this message translates to:
  /// **'Loading saved settings'**
  String get settingsLoading;

  /// Field label for the Soniox real-time model name.
  ///
  /// In en, this message translates to:
  /// **'Realtime model'**
  String get settingsRealtimeModel;

  /// Label and accessibility label of the Bailian mode switch.
  ///
  /// In en, this message translates to:
  /// **'Recognition mode'**
  String get settingsRecognitionMode;

  /// Mode option: text appears while speaking.
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get settingsModeStreaming;

  /// Field label for the streaming recognition model name.
  ///
  /// In en, this message translates to:
  /// **'Streaming ASR model'**
  String get settingsStreamingModel;

  /// Field label for the batch recognition model name.
  ///
  /// In en, this message translates to:
  /// **'Qwen-ASR batch model'**
  String get settingsBatchModel;

  /// Field label for the text model used for post-processing.
  ///
  /// In en, this message translates to:
  /// **'Post-processing OpenAI model'**
  String get settingsPostProcessingModel;

  /// Helper text under the post-processing model field.
  ///
  /// In en, this message translates to:
  /// **'Used only when Text post-processing is on'**
  String get settingsPostProcessingModelHelper;

  /// Field label for the API address.
  ///
  /// In en, this message translates to:
  /// **'OpenAI-compatible base URL'**
  String get settingsBaseUrl;

  /// Field label for the real-time WebSocket address.
  ///
  /// In en, this message translates to:
  /// **'Realtime WebSocket URL'**
  String get settingsRealtimeUrl;

  /// Button that saves the provider settings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get settingsSave;

  /// Button label while saving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get settingsSaving;

  /// Snack bar after saving.
  ///
  /// In en, this message translates to:
  /// **'Provider settings saved'**
  String get settingsSaved;

  /// Snack bar when saving failed. {reason} is a short explanation sentence.
  ///
  /// In en, this message translates to:
  /// **'Settings were not saved. {reason}'**
  String settingsSaveFailed(String reason);

  /// Section label for voice profiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get settingsSectionProfiles;

  /// Row that creates a new profile.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get settingsAddProfile;

  /// Row and page title: switch profile automatically when an app opens.
  ///
  /// In en, this message translates to:
  /// **'Use in apps'**
  String get settingsUseInApps;

  /// Subtitle of the Use in apps row.
  ///
  /// In en, this message translates to:
  /// **'Switch profile when you open an app'**
  String get settingsUseInAppsSubtitle;

  /// Row and page title: choose a profile per kind of text field.
  ///
  /// In en, this message translates to:
  /// **'Field rules'**
  String get settingsFieldRules;

  /// Subtitle listing the field kinds.
  ///
  /// In en, this message translates to:
  /// **'Search, web address, email, message'**
  String get settingsFieldRulesSubtitle;

  /// Section label for the keyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get settingsSectionKeyboard;

  /// Row title: how to add the Shinsoku keyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard setup'**
  String get settingsKeyboardSetup;

  /// Subtitle of the keyboard setup row.
  ///
  /// In en, this message translates to:
  /// **'Add Shinsoku and allow Full Access'**
  String get settingsKeyboardSetupSubtitle;

  /// Field label for the provider API key.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get settingsApiKey;

  /// Tooltip of the button that reveals the API key.
  ///
  /// In en, this message translates to:
  /// **'Show key'**
  String get settingsShowKey;

  /// Tooltip of the button that hides the API key.
  ///
  /// In en, this message translates to:
  /// **'Hide key'**
  String get settingsHideKey;

  /// Page title of the keyboard setup guide.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get keyboardSetupTitle;

  /// Intro line of the keyboard setup guide.
  ///
  /// In en, this message translates to:
  /// **'Use Shinsoku from any text field.'**
  String get keyboardSetupIntro;

  /// Step 1. Use the exact iOS menu names of this language.
  ///
  /// In en, this message translates to:
  /// **'Open Settings › General › Keyboard › Keyboards.'**
  String get keyboardStep1;

  /// Step 2. Use the exact iOS button name of this language.
  ///
  /// In en, this message translates to:
  /// **'Tap Add New Keyboard and choose Shinsoku.'**
  String get keyboardStep2;

  /// Step 3. Use the exact iOS switch name of this language.
  ///
  /// In en, this message translates to:
  /// **'Tap Shinsoku and turn on Allow Full Access, so the keyboard can insert your latest text.'**
  String get keyboardStep3;

  /// Intro of the Use in apps page. Shortcuts is the iOS app name.
  ///
  /// In en, this message translates to:
  /// **'Shinsoku can switch profile by itself when you open an app. Shortcuts watches for the app; Shinsoku sets the profile.'**
  String get useInAppsSummary;

  /// Section label for the automation that runs when an app opens.
  ///
  /// In en, this message translates to:
  /// **'When the app is opened'**
  String get useInAppsWhenOpened;

  /// Section label for the automation that runs when an app closes.
  ///
  /// In en, this message translates to:
  /// **'When the app is closed'**
  String get useInAppsWhenClosed;

  /// Step. Use the exact iOS names of this language.
  ///
  /// In en, this message translates to:
  /// **'In Shortcuts, open Automation and tap New Automation.'**
  String get useInAppsOpenStep1;

  /// Step. Use the exact iOS names of this language.
  ///
  /// In en, this message translates to:
  /// **'Choose App, pick the app, and select Is Opened. Turn on Run Immediately.'**
  String get useInAppsOpenStep2;

  /// Step. 'Set Shinsoku Profile' is the action name shown in Shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Add the action Set Shinsoku Profile and choose the profile for that app.'**
  String get useInAppsOpenStep3;

  /// Step. Use the exact iOS names of this language.
  ///
  /// In en, this message translates to:
  /// **'Add a second automation for the same app and select Is Closed. Turn on Run Immediately.'**
  String get useInAppsCloseStep1;

  /// Step.
  ///
  /// In en, this message translates to:
  /// **'Add Set Shinsoku Profile and choose your default profile, so other apps go back to it.'**
  String get useInAppsCloseStep2;

  /// Note under the steps.
  ///
  /// In en, this message translates to:
  /// **'You can also tap the profile name in the keyboard to switch. It stays until an automation runs again.'**
  String get useInAppsKeyboardNote;

  /// Warning on old iOS versions.
  ///
  /// In en, this message translates to:
  /// **'The Shortcuts actions need iOS 16 or later.'**
  String get useInAppsIosNote;

  /// Button that opens the Shortcuts app.
  ///
  /// In en, this message translates to:
  /// **'Open Shortcuts'**
  String get useInAppsOpenShortcuts;

  /// Page title.
  ///
  /// In en, this message translates to:
  /// **'Field rules'**
  String get fieldRulesTitle;

  /// Intro of the Field rules page.
  ///
  /// In en, this message translates to:
  /// **'Use a profile automatically in certain kinds of field. It applies only when you have not picked a profile in the keyboard and no automation has set one.'**
  String get fieldRulesSummary;

  /// Choice meaning no profile rule for this kind of field.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get fieldRulesNone;

  /// Kind of text field: a search box.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get fieldKindSearch;

  /// Kind of text field: a URL box.
  ///
  /// In en, this message translates to:
  /// **'Web address'**
  String get fieldKindUrl;

  /// Kind of text field: an email address or email body.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldKindEmail;

  /// Kind of text field: a chat message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get fieldKindMessage;

  /// Sheet title.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get profileNewTitle;

  /// Sheet title.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditTitle;

  /// Field label for the profile name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileNameLabel;

  /// Field label for the instruction given to the AI model.
  ///
  /// In en, this message translates to:
  /// **'Post-processing prompt'**
  String get profilePromptLabel;

  /// Helper text with an example instruction.
  ///
  /// In en, this message translates to:
  /// **'Example: Translate Chinese speech into natural English.'**
  String get profilePromptHelper;

  /// Label and accessibility label of what is typed after the inserted text.
  ///
  /// In en, this message translates to:
  /// **'After the text'**
  String get profileAfterText;

  /// Option: add nothing after the text.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get profileSuffixNothing;

  /// Option: add a space after the text.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get profileSuffixSpace;

  /// Option: add a line break after the text.
  ///
  /// In en, this message translates to:
  /// **'New line'**
  String get profileSuffixNewLine;

  /// Switch title: insert the text without a review step.
  ///
  /// In en, this message translates to:
  /// **'Auto commit'**
  String get profileAutoCommit;

  /// Switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Insert without a review step'**
  String get profileAutoCommitSubtitle;

  /// Button and dialog title that deletes a profile.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get profileDelete;

  /// Confirmation question. {name} is the profile name.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String profileDeleteConfirm(String name);

  /// Snack bar when trying to delete the last profile.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one profile'**
  String get profileKeepOne;

  /// Name given to a profile saved without a name.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get profileUntitled;

  /// Default instruction for a new profile. It is sent to an AI model; keep it a clear instruction.
  ///
  /// In en, this message translates to:
  /// **'Clean up the transcript. Return only the final text.'**
  String get profileDefaultIntent;

  /// Name of the built-in profile for plain dictation.
  ///
  /// In en, this message translates to:
  /// **'Dictation'**
  String get profileDictationName;

  /// Instruction of the Dictation profile.
  ///
  /// In en, this message translates to:
  /// **'Clean speech into natural prose'**
  String get profileDictationIntent;

  /// Name of the built-in profile for chat messages.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get profileChatName;

  /// Instruction of the Chat profile.
  ///
  /// In en, this message translates to:
  /// **'Make the text concise and conversational'**
  String get profileChatIntent;

  /// Name of the built-in profile that holds text for manual review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get profileReviewName;

  /// Description of the Review profile.
  ///
  /// In en, this message translates to:
  /// **'Hold transcript for manual review'**
  String get profileReviewIntent;

  /// Name of the built-in Chinese-to-English profile.
  ///
  /// In en, this message translates to:
  /// **'ZH -> EN'**
  String get profileZhToEnName;

  /// Instruction of the ZH -> EN profile. It is sent to an AI model; keep it a clear instruction in English.
  ///
  /// In en, this message translates to:
  /// **'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.'**
  String get profileZhToEnIntent;

  /// Snack bar when a second recording is requested.
  ///
  /// In en, this message translates to:
  /// **'Shinsoku is already recording.'**
  String get shellAlreadyRecording;

  /// Snack bar when a profile needs post-processing and it was switched on. {profile} is the profile name.
  ///
  /// In en, this message translates to:
  /// **'Text post-processing enabled for {profile}.'**
  String shellPostProcessingEnabled(String profile);

  /// Snack bar when switching post-processing on failed. {reason} is a short explanation sentence.
  ///
  /// In en, this message translates to:
  /// **'Post-processing setting was not saved. {reason}'**
  String shellPostProcessingNotSaved(String reason);

  /// Snack bar when copying failed. {reason} is a short explanation sentence.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the text. {reason}'**
  String shellClipboardFailed(String reason);

  /// Friendly error: a request timed out.
  ///
  /// In en, this message translates to:
  /// **'The provider took too long to answer. Check your connection and try again.'**
  String get failureTimeout;

  /// Friendly error: network failure.
  ///
  /// In en, this message translates to:
  /// **'No connection to the provider. Check your network and try again.'**
  String get failureNetwork;

  /// Friendly error: a streaming connection dropped.
  ///
  /// In en, this message translates to:
  /// **'The connection was lost. Try again.'**
  String get failureConnectionLost;

  /// Friendly error: provider key missing.
  ///
  /// In en, this message translates to:
  /// **'No API key is saved. Add one in Settings.'**
  String get failureKeyMissing;

  /// Friendly error: key rejected.
  ///
  /// In en, this message translates to:
  /// **'The provider did not accept your API key. Check it in Settings.'**
  String get failureKeyInvalid;

  /// Friendly error: quota or rate limit.
  ///
  /// In en, this message translates to:
  /// **'The provider reports no quota left or too many requests. Check your account.'**
  String get failureQuota;

  /// Friendly error: empty result.
  ///
  /// In en, this message translates to:
  /// **'No speech was recognized. Try again.'**
  String get failureNothingHeard;

  /// Friendly error: recorder problem.
  ///
  /// In en, this message translates to:
  /// **'The recording could not be completed. Try again.'**
  String get failureRecording;

  /// Friendly error: microphone problem.
  ///
  /// In en, this message translates to:
  /// **'The microphone is not available. Check microphone access in Settings.'**
  String get failureMicrophone;

  /// Fallback friendly error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get failureGeneric;

  /// Title of the Desktop tab page (use the phone as a microphone for a computer).
  ///
  /// In en, this message translates to:
  /// **'Desktop Mic'**
  String get nearbyTitle;

  /// Subtitle of the Desktop page: the connection stays on the local network.
  ///
  /// In en, this message translates to:
  /// **'Private local connection'**
  String get nearbySubtitle;

  /// Section label above the list of desktops.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get nearbySectionDesktop;

  /// Button that searches the local network for Shinsoku desktops.
  ///
  /// In en, this message translates to:
  /// **'Find Desktops'**
  String get nearbyFindDesktops;

  /// Tooltip of the icon button that reveals manual entry.
  ///
  /// In en, this message translates to:
  /// **'Add desktop manually'**
  String get nearbyAddManually;

  /// Field label: a secure WebSocket address such as wss://host:port. Keep 'WSS'.
  ///
  /// In en, this message translates to:
  /// **'WSS endpoint'**
  String get nearbyEndpointLabel;

  /// Field label for the desktop certificate's SHA-256 fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Certificate SHA-256'**
  String get nearbyCertificateLabel;

  /// Button that adds the manually entered desktop.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get nearbyAdd;

  /// Section label for verifying the desktop's certificate.
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get nearbySectionTrust;

  /// Heading when this desktop has been paired before.
  ///
  /// In en, this message translates to:
  /// **'Trusted desktop'**
  String get nearbyTrustedDesktop;

  /// Heading above the desktop certificate fingerprint to verify.
  ///
  /// In en, this message translates to:
  /// **'Certificate fingerprint'**
  String get nearbyCertificateFingerprint;

  /// Switch title: the user confirms the fingerprint equals the one on the desktop.
  ///
  /// In en, this message translates to:
  /// **'Matches desktop Settings'**
  String get nearbyMatchesTitle;

  /// Switch subtitle explaining where to compare the fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Compare it with Settings on the desktop'**
  String get nearbyMatchesSubtitle;

  /// Field label for the two-digit pairing code.
  ///
  /// In en, this message translates to:
  /// **'Pairing code shown on the desktop'**
  String get nearbyPairingCodeLabel;

  /// Button that closes the connection to the desktop.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get nearbyDisconnect;

  /// Button that connects to an already trusted desktop.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get nearbyConnect;

  /// Button that pairs with a new desktop and connects.
  ///
  /// In en, this message translates to:
  /// **'Pair and Connect'**
  String get nearbyPairAndConnect;

  /// Tooltip of the icon button that removes trust of the desktop.
  ///
  /// In en, this message translates to:
  /// **'Forget desktop'**
  String get nearbyForget;

  /// Section label for the dictation controls of the Desktop page.
  ///
  /// In en, this message translates to:
  /// **'Remote input'**
  String get nearbySectionRemoteInput;

  /// Row title for choosing which profile the desktop uses.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get nearbyProfileRow;

  /// Profile choice meaning the desktop picks its own profile.
  ///
  /// In en, this message translates to:
  /// **'Desktop automatic'**
  String get nearbyProfileAutomatic;

  /// Title of the sheet to choose the desktop profile.
  ///
  /// In en, this message translates to:
  /// **'Desktop profile'**
  String get nearbyProfileSheetTitle;

  /// Label of the record button and hint while dictating into the desktop.
  ///
  /// In en, this message translates to:
  /// **'Stop and transcribe'**
  String get nearbyStopAndTranscribe;

  /// Label of the record button and hint when connected.
  ///
  /// In en, this message translates to:
  /// **'Start remote dictation'**
  String get nearbyStartRemote;

  /// Hint below the disabled record button when not connected.
  ///
  /// In en, this message translates to:
  /// **'Connect to a desktop to dictate into it'**
  String get nearbyConnectToDictate;

  /// Status while connecting. {name} is the desktop's name.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {name}'**
  String nearbyConnectingTo(String name);

  /// Status when connected. {name} is the desktop's name.
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}'**
  String nearbyConnectedTo(String name);

  /// Status while the microphone audio is sent to the desktop.
  ///
  /// In en, this message translates to:
  /// **'Streaming microphone audio'**
  String get nearbyStreaming;

  /// Status when some audio frames did not arrive. {count} is the number of missing frames.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Streaming with 1 missing frame} other{Streaming with {count} missing frames}}'**
  String nearbyStreamingGaps(int count);

  /// Status after dictation finished and was delivered.
  ///
  /// In en, this message translates to:
  /// **'Recording sent to desktop'**
  String get nearbyRecordingSent;

  /// Status when there is no connection to a desktop.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get nearbyNotConnected;

  /// Status when the desktop closed the connection.
  ///
  /// In en, this message translates to:
  /// **'Desktop disconnected'**
  String get nearbyDisconnected;

  /// Status while looking for desktops.
  ///
  /// In en, this message translates to:
  /// **'Searching the local network'**
  String get nearbySearching;

  /// Status when the search found nothing.
  ///
  /// In en, this message translates to:
  /// **'No Shinsoku desktop found'**
  String get nearbyNoneFound;

  /// Status after the search. {count} is how many desktops were found.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 desktop found} other{{count} desktops found}}'**
  String nearbyDesktopsFound(int count);

  /// Status after choosing a desktop that was paired before.
  ///
  /// In en, this message translates to:
  /// **'Trusted desktop selected'**
  String get nearbyTrustedSelected;

  /// Status asking the user to compare the certificate fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Verify the desktop fingerprint'**
  String get nearbyVerifyFingerprint;

  /// Status after forgetting a desktop.
  ///
  /// In en, this message translates to:
  /// **'Local trust removed'**
  String get nearbyTrustRemoved;

  /// Error: the pairing code is missing.
  ///
  /// In en, this message translates to:
  /// **'Enter the two-digit code shown on desktop.'**
  String get nearbyErrorPairingCodeRequired;

  /// Error for a malformed certificate fingerprint.
  ///
  /// In en, this message translates to:
  /// **'The certificate fingerprint is not valid. Enter all 64 hexadecimal characters.'**
  String get nearbyErrorFingerprintInvalid;

  /// Error for a malformed address. Keep 'wss://'.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid wss:// host and port.'**
  String get nearbyErrorEndpointInvalid;

  /// Error when the desktop's certificate differs from the trusted one.
  ///
  /// In en, this message translates to:
  /// **'The desktop certificate has changed. Forget it and pair again.'**
  String get nearbyErrorCertificateChanged;

  /// Error: the desktop trusts the phone but the phone lost its credential.
  ///
  /// In en, this message translates to:
  /// **'This desktop remembers this device, but the local credential is missing. Revoke it on the desktop and pair again.'**
  String get nearbyErrorCredentialMissing;

  /// Error: no pairing code is active on the desktop.
  ///
  /// In en, this message translates to:
  /// **'Create a pairing code in desktop Settings, then connect again.'**
  String get nearbyErrorPairingUnavailable;

  /// Error: pairing code expired.
  ///
  /// In en, this message translates to:
  /// **'The desktop pairing code expired. Create a new one.'**
  String get nearbyErrorPairingExpired;

  /// Error: wrong pairing code.
  ///
  /// In en, this message translates to:
  /// **'The pairing code is incorrect.'**
  String get nearbyErrorWrongCode;

  /// Error: too many wrong pairing codes.
  ///
  /// In en, this message translates to:
  /// **'Pairing attempts are used up. Create a new code on the desktop.'**
  String get nearbyErrorAttemptsExhausted;

  /// Error: the desktop cannot start a new dictation.
  ///
  /// In en, this message translates to:
  /// **'The desktop is already recording or processing audio.'**
  String get nearbyErrorDesktopBusy;

  /// Error: tried to record without a connection.
  ///
  /// In en, this message translates to:
  /// **'Connect to a desktop before recording.'**
  String get nearbyErrorConnectFirst;

  /// Error: no answer from the desktop.
  ///
  /// In en, this message translates to:
  /// **'The desktop did not respond in time.'**
  String get nearbyErrorTimeout;

  /// Error: the connection closed or failed.
  ///
  /// In en, this message translates to:
  /// **'The connection to the desktop was lost.'**
  String get nearbyErrorConnectionLost;

  /// Error: microphone permission denied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is required. Allow it in Settings.'**
  String get nearbyErrorMicDenied;

  /// Error: the recorder is not ready.
  ///
  /// In en, this message translates to:
  /// **'The microphone is not ready. Try again.'**
  String get nearbyErrorRecorderNotReady;

  /// Error: the audio stream failed.
  ///
  /// In en, this message translates to:
  /// **'The microphone stopped unexpectedly.'**
  String get nearbyErrorMicStream;

  /// Error: discovery of desktops failed.
  ///
  /// In en, this message translates to:
  /// **'Could not search the local network. Check Wi-Fi and try again.'**
  String get nearbyErrorDiscovery;

  /// Error: protocol mismatch or invalid reply.
  ///
  /// In en, this message translates to:
  /// **'The desktop sent an unexpected response. Update Shinsoku on both devices and try again.'**
  String get nearbyErrorUnexpectedResponse;

  /// Fallback error for the Desktop page.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong with the desktop connection.'**
  String get nearbyErrorGeneric;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'XA':
            return AppLocalizationsEnXa();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
