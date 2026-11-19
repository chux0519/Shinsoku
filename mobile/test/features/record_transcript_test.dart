// live-01 T2: the transcript is the text field. Read-only while live,
// editable after; Done and a new recording save into the same draft (L3);
// Copy hands the text to the publish path.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/services/live_transcript.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/ui.dart';
import '../support/l10n.dart';

const _field = ValueKey('record-transcript-field');

class _World {
  final live = ValueNotifier<LiveTranscript>(LiveTranscript.idle);
  final saved = <String>[];
  final copied = <String>[];
  final events = <String>[];
  CaptureState state = CaptureState.idle;

  Widget build() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,

    theme: buildSkTheme(Brightness.dark),
    home: Scaffold(
      body: RecordView(
        profiles: defaultVoiceProfiles,
        selectedProfileIndex: 0,
        captureState: state,
        microphoneAllowed: true,
        smokeTestStatus: null,
        transcript: live,
        onProfileSelected: (_) {},
        onCapturePressed: () => events.add('capture'),
        onSaveText: (text) {
          saved.add(text);
          events.add('save');
        },
        onCopyText: copied.add,
      ),
    ),
  );
}

TextField _textField(WidgetTester t) => t.widget<TextField>(find.byKey(_field));

SkTranscriptController _controller(WidgetTester t) =>
    _textField(t).controller! as SkTranscriptController;

Future<void> _phone(WidgetTester t, _World w) async {
  t.view.physicalSize = const Size(402, 874);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(w.build());
}

/// listening → done with [text], as the service reports it.
Future<void> _recordTake(WidgetTester t, _World w, String text) async {
  w.state = CaptureState.listening;
  w.live.value = const LiveTranscript(phase: LivePhase.listening);
  await t.pumpWidget(w.build());
  w.state = CaptureState.idle;
  w.live.value = LiveTranscript(committed: text, phase: LivePhase.done);
  await t.pumpWidget(w.build());
  await t.pump();
}

void main() {
  testWidgets('live words: read-only, pending lighter, committed grows', (
    t,
  ) async {
    final w = _World();
    await _phone(t, w);
    expect(find.text(en.recordPlaceholder), findsOneWidget);
    expect(_textField(t).readOnly, isFalse);

    w.state = CaptureState.listening;
    w.live.value = const LiveTranscript(phase: LivePhase.listening);
    await t.pumpWidget(w.build());
    expect(_textField(t).readOnly, isTrue);
    expect(find.text(en.recordListeningPlaceholder), findsOneWidget);

    w.live.value = const LiveTranscript(
      committed: 'Move the review ',
      pending: 'to Thurs',
      phase: LivePhase.listening,
    );
    await t.pump();
    expect(_controller(t).text, 'Move the review to Thurs');
    expect(_controller(t).hasPending, isTrue);
    // Pending words paint in text-tertiary.
    final span = _controller(t).buildTextSpan(
      context: t.element(find.byKey(_field)),
      withComposing: false,
    );
    final pending = span.children!.last as TextSpan;
    expect(pending.text, 'to Thurs');
    expect(pending.style!.color, SkColors.dark.textTertiary);

    w.live.value = const LiveTranscript(
      committed: 'Move the review to Thursday. ',
      pending: 'Send',
      phase: LivePhase.listening,
    );
    await t.pump();
    expect(_controller(t).text, 'Move the review to Thursday. Send');
    // Copy and Done are not offered while live.
    expect(
      find.byKey(const ValueKey('record-copy')).hitTestable(),
      findsNothing,
    );

    // Processing: raw words, dimmed, still read-only.
    w.state = CaptureState.processing;
    w.live.value = const LiveTranscript(
      committed: 'Move the review to Thursday. Send it.',
      phase: LivePhase.processing,
    );
    await t.pumpWidget(w.build());
    expect(_textField(t).readOnly, isTrue);
    expect(_textField(t).style!.color, SkColors.dark.textSecondary);
    expect(find.text(en.recordProcessing), findsOneWidget);

    // Done: the processed text replaces it once, editable.
    w.state = CaptureState.idle;
    w.live.value = const LiveTranscript(
      committed: 'Move the review to Thursday and send it.',
      phase: LivePhase.done,
    );
    await t.pumpWidget(w.build());
    expect(_textField(t).readOnly, isFalse);
    expect(_controller(t).text, 'Move the review to Thursday and send it.');
    expect(_controller(t).hasPending, isFalse);
  });

  testWidgets('L3: Done saves the edit once, into the same draft', (t) async {
    final w = _World();
    await _phone(t, w);
    await _recordTake(t, w, 'First take.');
    expect(w.saved, isEmpty, reason: 'the result itself is not an edit');

    await t.enterText(find.byKey(_field), 'First take, edited.');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('record-done')));
    await t.pump();
    expect(w.saved, ['First take, edited.']);
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );

    // Nothing changed since: Done is gone, rebuilds do not save again.
    await t.pumpWidget(w.build());
    expect(
      find.byKey(const ValueKey('record-done')).hitTestable(),
      findsNothing,
    );
    expect(w.saved, hasLength(1));
  });

  testWidgets('L3/L4: a new recording over unsaved edits saves them first', (
    t,
  ) async {
    final w = _World();
    await _phone(t, w);
    await _recordTake(t, w, 'Take one.');
    await t.enterText(find.byKey(_field), 'Take one, fixed.');
    await t.pump();

    await t.tap(find.bySemanticsLabel('Start recording'));
    await t.pump();
    expect(w.events, ['save', 'capture']);
    expect(w.saved, ['Take one, fixed.']);

    // The service starts the next take: the area is reused, nothing saved twice.
    w.state = CaptureState.listening;
    w.live.value = const LiveTranscript(phase: LivePhase.connecting);
    await t.pumpWidget(w.build());
    await t.pump();
    expect(w.saved, hasLength(1));
    expect(_controller(t).text, isEmpty);
  });

  testWidgets('a recording started elsewhere still keeps unsaved edits', (
    t,
  ) async {
    final w = _World();
    await _phone(t, w);
    await _recordTake(t, w, 'Take one.');
    await t.enterText(find.byKey(_field), 'Take one, fixed.');
    await t.pump();
    // e.g. started from the keyboard: the phase changes without a tap here.
    w.state = CaptureState.listening;
    w.live.value = const LiveTranscript(phase: LivePhase.listening);
    await t.pumpWidget(w.build());
    await t.pump();
    expect(w.saved, ['Take one, fixed.']);
  });

  testWidgets('Copy hands the current text to the publish path', (t) async {
    final w = _World();
    await _phone(t, w);
    await _recordTake(t, w, 'Copy me.');
    await t.enterText(find.byKey(_field), 'Copy me, edited.');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('record-copy')));
    await t.pump();
    expect(w.copied, ['Copy me, edited.']);
    // Copy saved it too (the shell saves before publishing): no later save.
    await t.tap(find.byKey(const ValueKey('record-done')));
    await t.pump();
    expect(w.saved, isEmpty);
  });

  testWidgets('Clear lives in the context menu of editable text', (t) async {
    final w = _World();
    await _phone(t, w);
    await _recordTake(t, w, 'Some words to clear.');
    await t.longPress(find.byKey(_field));
    await t.pumpAndSettle();
    // The Material toolbar on the test host folds extra items behind More.
    if (find.text(en.commonClear).evaluate().isEmpty) {
      await t.tap(find.byTooltip('More'));
      await t.pumpAndSettle();
    }
    expect(find.text(en.commonClear), findsOneWidget);
    await t.tap(find.text(en.commonClear));
    await t.pumpAndSettle();
    expect(_controller(t).text, isEmpty);
    expect(find.text(en.commonClear), findsNothing);
  });
}
