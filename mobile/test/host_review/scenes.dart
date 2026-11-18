// Scenes for the tier-A host review (see host_review_test.dart). Each scene
// builds a real screen with fake data: no network, no plugins.
import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/app/shell_scaffold.dart';
import 'package:shinsoku_mobile/features/drafts/drafts_view.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/features/settings/settings_view.dart';
import 'package:shinsoku_mobile/nearby/nearby_microphone_view.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

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

Widget _tab(int index, Widget body) =>
    ShellScaffold(tabIndex: index, onTabSelected: (_) {}, body: body);

Widget _record({
  CaptureState state = CaptureState.idle,
  bool microphoneAllowed = true,
  SmokeTestStatus? status,
}) => _tab(
  0,
  RecordView(
    profiles: defaultVoiceProfiles,
    selectedProfileIndex: 0,
    captureState: state,
    microphoneAllowed: microphoneAllowed,
    smokeTestStatus: status,
    onProfileSelected: (_) {},
    onProfileAdded: () {},
    onProfileEdited: (_) {},
    onProfileDeleted: (_) {},
    onCapturePressed: () {},
  ),
);

Widget _settings() => _tab(
  3,
  SettingsView(
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
  ),
);

final scenes = <String, SceneBuilder>{
  'record-idle': () => _record(),
  'record-listening': () => _record(state: CaptureState.listening),
  'record-result': () => _record(
    status: const SmokeTestStatus(
      label: 'Recording transcribed',
      detail: 'provider=bailian appStopToDraft=640ms',
      transcript: sampleTranscript,
      finished: true,
    ),
  ),
  'record-error': () => _record(
    microphoneAllowed: false,
    status: const SmokeTestStatus(
      label: 'Microphone permission required',
      detail:
          'Allow microphone access in iOS Settings, then try recording again.',
      failed: true,
      finished: true,
    ),
  ),
  'drafts-empty': () => _tab(
    1,
    DraftsView(
      drafts: const [],
      onDelete: (_) {},
      onEdit: (_) {},
      onCopy: (_) {},
    ),
  ),
  'drafts-list': () => _tab(
    1,
    DraftsView(
      drafts: sampleDrafts(),
      onDelete: (_) {},
      onEdit: (_) {},
      onCopy: (_) {},
    ),
  ),
  'draft-editor': () => DraftEditorScreen(draft: sampleDrafts().first),
  'settings': _settings,
  'nearby': () => _tab(
    2,
    const NearbyMicrophoneView(
      profiles: [
        NearbyProfileOption(id: 'default', label: 'Dictation'),
        NearbyProfileOption(id: 'chat', label: 'Chat'),
      ],
    ),
  ),
};

/// Scenes also rendered at the Dynamic Type review size.
const largeTextScenes = {'record-idle', 'settings'};
