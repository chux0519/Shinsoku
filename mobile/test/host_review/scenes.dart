// Scenes for the tier-A host review (see host_review_test.dart). Each scene
// builds a real screen with fake data: no network, no plugins.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/app/shell_scaffold.dart';
import 'package:shinsoku_mobile/features/drafts/draft_editor_page.dart';
import 'package:shinsoku_mobile/features/drafts/drafts_view.dart';
import 'package:shinsoku_mobile/features/record/live_transcript.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/features/settings/field_rules_view.dart';
import 'package:shinsoku_mobile/features/settings/keyboard_setup_view.dart';
import 'package:shinsoku_mobile/features/settings/use_in_apps_view.dart';
import 'package:shinsoku_mobile/services/field_rules.dart';
import 'package:shinsoku_mobile/features/settings/profile_editor_sheet.dart';
import 'package:shinsoku_mobile/features/settings/settings_view.dart';
import 'package:shinsoku_mobile/nearby/nearby_microphone_view.dart';
import 'package:shinsoku_mobile/nearby/nearby_models.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

typedef SceneBuilder = Widget Function();

const sampleTranscript =
    'Let us move the design review to Thursday afternoon, and send the '
    'updated keyboard screenshots to the team before then.';

final _now = DateTime.now();

List<DraftEntry> sampleDrafts() => [
  DraftEntry(
    text: sampleTranscript,
    profileName: 'Bailian',
    createdAt: _now.subtract(const Duration(minutes: 3)),
  ),
  DraftEntry(
    text: 'Pick up the parcel at the front desk after six.',
    profileName: 'Soniox',
    createdAt: _now.subtract(const Duration(hours: 2)),
  ),
  DraftEntry(
    text:
        'Notes for the call: pricing page copy, the iPhone Duo layout, and '
        'whether the keyboard should remember the last profile.',
    profileName: 'Bailian',
    createdAt: _now.subtract(const Duration(days: 1, hours: 1)),
  ),
  DraftEntry(
    text: 'Remind me to renew the example-host certificate on Monday.',
    profileName: 'Bailian',
    createdAt: _now.subtract(const Duration(days: 4)),
  ),
];

/// The real shell with all four pages, [index] selected (and shown in the
/// second pane on regular widths). [record] / [drafts] replace the defaults.
Widget _tab(int index, {Widget? record, Widget? drafts, Widget? nearby}) =>
    ShellScaffold(
      tabIndex: index,
      secondaryIndex: index == 0 ? 1 : index,
      onTabSelected: (_) {},
      pages: [
        record ?? _recordView(),
        drafts ?? _draftsView(sampleDrafts()),
        nearby ?? const NearbyMicrophoneView(profiles: _nearbyProfiles),
        _settingsView(),
      ],
    );

Widget _recordView({
  CaptureState state = CaptureState.idle,
  bool microphoneAllowed = true,
  SmokeTestStatus? status,
  LiveTranscript? live,
}) => RecordView(
  transcript: live == null ? null : ValueNotifier(live),
  onSaveText: (_) {},
  onCopyText: (_) {},
  profiles: defaultVoiceProfiles,
  selectedProfileIndex: 0,
  captureState: state,
  microphoneAllowed: microphoneAllowed,
  smokeTestStatus: status,
  onProfileSelected: (_) {},
  onCapturePressed: () {},
  onOpenMicrophoneSettings: () {},
  onOpenSettings: () {},
  profileReason: 'Dictation · default',
);

Widget _record({
  CaptureState state = CaptureState.idle,
  bool microphoneAllowed = true,
  SmokeTestStatus? status,
  LiveTranscript? live,
}) => _tab(
  0,
  record: _recordView(
    state: state,
    microphoneAllowed: microphoneAllowed,
    status: status,
    live: live,
  ),
);

/// Live words as a streaming provider sends them: committed sentences, then
/// the interim words still being recognised.
const _liveCommitted =
    'Let us move the design review to Thursday afternoon, and send the ';
const _livePending = 'updated keyboard screen';

const _doneStatus = SmokeTestStatus(
  label: 'Recording transcribed',
  detail: 'provider=bailian appStopToDraft=640ms',
  transcript: sampleTranscript,
  finished: true,
);

Widget _draftsView(List<DraftEntry> drafts) => DraftsView(
  drafts: drafts,
  onDelete: (_) {},
  onEdit: (_) {},
  onCopy: (_) {},
);

Widget _settingsView() => SettingsView(
  microphoneAllowed: true,
  keyboardExtensionEnabled: false,
  cloudProcessingEnabled: true,
  providerSettings: ProviderSettings.defaults().copyWith(
    bailianApiKey: 'example-key-0000',
  ),
  providerSettingsLoading: false,
  providerSettingsSaving: false,
  onMicrophonePressed: () {},
  onKeyboardChanged: (_) {},
  onCloudProcessingChanged: (_) {},
  onProviderSettingsSaved: (_) async {},
  profiles: defaultVoiceProfiles,
  onProfileAdded: () {},
  onProfileOpened: (_) {},
);

Widget _settings() => _tab(3);

const _dictation = VoiceProfile(
  id: 'dictation',
  name: 'Dictation',
  intent: 'Clean speech into natural prose',
  commitSuffix: CommitSuffix.space,
  autoCommit: true,
);

/// A sheet as the modal route shows it: page behind, scrim, sheet at the
/// bottom inside the top safe area.
Widget _sheetOver(Widget page, Widget sheet) => Builder(
  builder: (context) {
    final c = SkColors.of(context);
    return Stack(
      children: [
        page,
        const ModalBarrier(color: Colors.black54),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: Material(
              color: c.raised,
              elevation: 8,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(SkShape.sheet),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: sheet,
            ),
          ),
        ),
      ],
    );
  },
);

final scenes = <String, SceneBuilder>{
  'record-idle': () => _record(),
  // Batch provider: no live words, the area says Listening….
  'record-listening': () => _record(state: CaptureState.listening),
  'record-listening-live': () => _record(
    state: CaptureState.listening,
    live: const LiveTranscript(
      committed: _liveCommitted,
      pending: _livePending,
      phase: LivePhase.listening,
    ),
  ),
  'record-result': () => _record(status: _doneStatus),
  // Batch provider waiting for the text.
  'record-processing': () => _record(
    state: CaptureState.processing,
    status: const SmokeTestStatus(
      label: 'Transcribing recording',
      detail: 'Uploading recorded audio to the selected provider.',
    ),
  ),
  // Post-processing profile: the raw words dimmed until the result swaps in.
  'record-processing-live': () => _record(
    state: CaptureState.processing,
    live: const LiveTranscript(
      committed: '$_liveCommitted$_livePending.',
      phase: LivePhase.processing,
    ),
  ),
  // Editing the result with the software keyboard up (see sceneSetups).
  'record-editing': () => _record(status: _doneStatus),
  'record-error': () => _record(
    microphoneAllowed: false,
    status: const SmokeTestStatus(
      label: 'Microphone access is off',
      detail:
          'Allow microphone access in iOS Settings, then try recording again.',
      failed: true,
      finished: true,
      fix: StatusFix.microphone,
    ),
  ),
  'drafts-empty': () => _tab(1, drafts: _draftsView(const [])),
  'drafts-list': () => _tab(1),
  'draft-editor': () => DraftEditorPage(
    draft: sampleDrafts().first,
    onSave: (_) {},
    onCopy: (_) {},
  ),
  'settings': _settings,
  'keyboard-setup': () => KeyboardSetupView(onOpenSettings: () async => true),
  'use-in-apps': () => UseInAppsView(onOpenShortcuts: () async => true),
  'field-rules': () => FieldRulesView(
    profiles: defaultVoiceProfiles,
    rules: const FieldRules({
      FieldKind.search: 'chat',
      FieldKind.email: 'review',
    }),
    onChanged: (_) async {},
  ),
  'profile-editor': () => _sheetOver(
    _settings(),
    const ProfileEditorSheet(profile: _dictation, canDelete: true),
  ),
  'nearby': () => _tab(2),
  'nearby-pair': () => _tab(
    2,
    nearby: const NearbyMicrophoneView(
      profiles: _nearbyProfiles,
      initialDesktops: [
        NearbyDesktop(
          serviceName: 'example-desktop',
          host: '192.0.2.10',
          port: 39273,
          certificateSha256:
              '3f9a1c2b7d4e8f60a1b2c3d4e5f60718293a4b5c6d7e8f9012a3b4c5d6e7f809',
          instanceId: 'example-instance',
        ),
        NearbyDesktop(
          serviceName: 'example-laptop',
          host: '192.0.2.11',
          port: 39273,
          certificateSha256:
              'aa11bb22cc33dd44ee55ff6600778899aabbccddeeff00112233445566778899',
          instanceId: 'example-instance-2',
        ),
      ],
    ),
  ),
};

const _nearbyProfiles = [
  NearbyProfileOption(id: 'default', label: 'Dictation'),
  NearbyProfileOption(id: 'chat', label: 'Chat'),
];

/// Scenes also rendered at the Dynamic Type review size.
const largeTextScenes = {'record-idle', 'settings'};

/// Scenes also rendered on the inner display with a fake fold.
const foldScenes = {
  'record-idle',
  'record-listening',
  'record-listening-live',
  'record-result',
  'record-editing',
  'drafts-list',
  'settings',
};

/// Simulated software keyboard height for [device] (logical points): the
/// iPhone 17 keyboard with its predictive bar; about 40 % of the height
/// elsewhere (real heights are tier B).
double keyboardHeight(String device, Size size) =>
    device.startsWith('iphone') ? 336 : (size.height * 0.4).roundToDouble();

/// Steps run after a scene settles, before the screenshot.
final sceneSetups =
    <String, Future<void> Function(WidgetTester t, String device)>{
      'record-editing': (t, device) async {
        final size = t.view.physicalSize / t.view.devicePixelRatio;
        final inset = keyboardHeight(device, size);
        // The keyboard covers the bottom safe area.
        final padding = t.view.padding;
        final keyboard = FakeViewPadding(
          bottom: inset * t.view.devicePixelRatio,
        );
        final noBottom = FakeViewPadding(
          left: padding.left,
          top: padding.top,
          right: padding.right,
        );
        t.view.padding = noBottom;
        t.view.viewInsets = keyboard;
        await t.tap(find.byKey(const ValueKey('record-transcript-field')));
        await t.pumpAndSettle();
      },
    };
