import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/theme.dart';

Widget _record({
  SmokeTestStatus? status,
  CaptureState state = CaptureState.idle,
  VoidCallback? onMic,
  VoidCallback? onSettings,
  VoidCallback? onCapture,
  ValueChanged<int>? onProfile,
}) => MaterialApp(
  theme: buildSkTheme(Brightness.dark),
  home: Scaffold(
    body: RecordView(
      profiles: defaultVoiceProfiles,
      selectedProfileIndex: 0,
      captureState: state,
      microphoneAllowed: false,
      smokeTestStatus: status,
      onProfileSelected: onProfile ?? (_) {},
      onCapturePressed: onCapture ?? () {},
      onOpenMicrophoneSettings: onMic,
      onOpenSettings: onSettings,
    ),
  ),
);

void main() {
  testWidgets('microphone error offers its fix inline', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _record(
        status: const SmokeTestStatus(
          label: 'Microphone access is off',
          detail: 'Allow microphone access in iOS Settings.',
          failed: true,
          finished: true,
          fix: StatusFix.microphone,
        ),
        onMic: () => opened++,
      ),
    );
    expect(find.text('Microphone access is off'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('record-status-fix')));
    expect(opened, 1);
  });

  testWidgets('missing provider settings links to Settings', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _record(
        status: const SmokeTestStatus(
          label: 'Provider settings required',
          detail: 'Save an API key.',
          failed: true,
          finished: true,
          fix: StatusFix.providerSettings,
        ),
        onSettings: () => opened++,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('record-status-fix')));
    expect(opened, 1);
  });

  testWidgets('idle shows one empty-state line and one record button', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_record(onCapture: () => taps++));
    expect(find.text('Ready to record'), findsOneWidget);
    expect(find.text('Tap the microphone and start speaking.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Start recording'));
    expect(taps, 1);
  });

  testWidgets('profiles cannot change while listening', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _record(state: CaptureState.listening, onProfile: selected.add),
    );
    expect(find.text('Listening'), findsOneWidget);
    await tester.tap(find.text('Chat'));
    expect(selected, isEmpty);
    await tester.pumpWidget(_record(onProfile: selected.add));
    await tester.tap(find.text('Chat'));
    expect(selected, [1]);
  });
}
