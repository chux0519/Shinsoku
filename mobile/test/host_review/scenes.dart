// Scenes for the tier-A host review (see host_review_test.dart). Each scene
// builds a real screen with fake data: no network, no plugins.
import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/app/shell_scaffold.dart';
import 'package:shinsoku_mobile/features/drafts/drafts_view.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/features/settings/keyboard_setup_view.dart';
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
    onCapturePressed: () {},
    onOpenMicrophoneSettings: () {},
    onOpenSettings: () {},
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
    profiles: defaultVoiceProfiles,
    onProfileAdded: () {},
    onProfileOpened: (_) {},
  ),
);

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
  'record-listening': () => _record(state: CaptureState.listening),
  'record-result': () => _record(
    status: const SmokeTestStatus(
      label: 'Recording transcribed',
      detail: 'provider=bailian appStopToDraft=640ms',
      transcript: sampleTranscript,
      finished: true,
    ),
  ),
  'record-processing': () => _record(
    state: CaptureState.processing,
    status: const SmokeTestStatus(
      label: 'Transcribing recording',
      detail: 'Uploading recorded audio to the selected provider.',
    ),
  ),
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
  'keyboard-setup': () => KeyboardSetupView(onOpenSettings: () async => true),
  'profile-editor': () => _sheetOver(
    _settings(),
    const ProfileEditorSheet(profile: _dictation, canDelete: true),
  ),
  'nearby': () =>
      _tab(2, const NearbyMicrophoneView(profiles: _nearbyProfiles)),
  'nearby-pair': () => _tab(
    2,
    const NearbyMicrophoneView(
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
