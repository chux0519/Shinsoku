// live-01 T3: the real MobileShell with a scripted pipeline — live words in
// the Record area, the failure path (L2/L3), Done republishing, Drafts ↔
// Record as one source, L4 and the iPhone Duo keyboard rule (D3).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/app/mobile_shell.dart';
import 'package:shinsoku_mobile/features/drafts/drafts_view.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

import '../model/scripted_pipeline.dart';

const _field = ValueKey('record-transcript-field');
const _iphone = Size(402, 874);
const _duoPortrait = Size(669, 951);

class ShellDriver {
  ShellDriver(this.t);

  final WidgetTester t;
  final pipelines = <ScriptedPipeline>[];
  final published = <String>[];
  String Function(String)? postProcess;

  ScriptedPipeline get pipeline => pipelines.last;

  Future<void> pump(Size size) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('net.potafree.shinsoku/keyboard_bridge'),
          (call) async {
            if (call.method == 'publishLatestText') {
              published.add((call.arguments as Map)['text'] as String);
            }
            return null;
          },
        );
    // No host: the profile selection reads as missing (default profile).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('net.potafree.shinsoku/profiles'),
          (call) async => null,
        );
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildSkTheme(Brightness.dark),
        home: MobileShell(
          pipelineFactory: () {
            final p = ScriptedPipeline(postProcess: postProcess);
            pipelines.add(p);
            return p;
          },
        ),
      ),
    );
    await t.pump();
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await t.pump();
    }
  }

  Future<void> toggle() async {
    await t.tap(
      find.descendant(
        of: find.byType(RecordView),
        matching: find.byType(SkRecordButton),
      ),
    );
    await settle();
  }

  SkTranscriptController get controller =>
      t.widget<TextField>(find.byKey(_field, skipOffstage: false)).controller!
          as SkTranscriptController;

  String get area => controller.text;

  List<String> get drafts => t
      .widgetList<DraftRow>(find.byType(DraftRow, skipOffstage: false))
      .map((row) => row.draft.text)
      .toList();

  String get status => t
      .widgetList<SkStatusLine>(
        find.descendant(
          of: find.byType(RecordView),
          matching: find.byType(SkStatusLine),
        ),
      )
      .single
      .text;
}

void main() {
  testWidgets('live words fill the area; stop → result in one draft', (
    t,
  ) async {
    final d = ShellDriver(t);
    await d.pump(_iphone);
    await d.toggle();
    d.pipeline.finalWords('Example one. ');
    d.pipeline.partial('example tw');
    await d.settle();
    expect(d.area, 'Example one. example tw');
    expect(d.controller.hasPending, isTrue);
    await d.toggle(); // stop
    d.pipeline.finalWords('Example two.');
    await d.settle();
    expect(await d.pipeline.process(), isTrue);
    await d.settle();
    expect(d.area, 'Example one. Example two.');
    expect(d.drafts, ['Example one. Example two.']);
    // The draft is plain; Insert and the clipboard get the profile's suffix
    // (Dictation: a space).
    expect(d.published, ['Example one. Example two. ']);
  });

  testWidgets('L2: a drop while listening keeps committed + pending', (
    t,
  ) async {
    final d = ShellDriver(t);
    await d.pump(_iphone);
    await d.toggle();
    d.pipeline.finalWords('Example heard. ');
    d.pipeline.partial('almost');
    await d.settle();
    d.pipeline.drop();
    await d.settle();
    expect(d.area, 'Example heard. almost');
    expect(d.drafts, ['Example heard. almost']);
    expect(d.status, SkStrings.recordingStopped);
    // Editable now; Record again offers a new recording.
    expect(t.widget<TextField>(find.byKey(_field)).readOnly, isFalse);
    await t.tap(find.byKey(const ValueKey('record-status-fix')));
    await d.settle();
    expect(d.pipelines, hasLength(2));
    expect(d.drafts, ['Example heard. almost']);
  });

  testWidgets('L2: a drop after stop (finishing) keeps what was heard', (
    t,
  ) async {
    final d = ShellDriver(t);
    await d.pump(_iphone);
    await d.toggle();
    d.pipeline.finalWords('Example said.');
    await d.toggle();
    d.pipeline.partial(' and more');
    d.pipeline.drop();
    await d.settle();
    expect(d.drafts, ['Example said. and more']);
    expect(d.area, 'Example said. and more');
  });

  testWidgets('post-processing replaces the raw text once', (t) async {
    final d = ShellDriver(t)..postProcess = (raw) => raw.toUpperCase();
    await d.pump(_iphone);
    await d.toggle();
    d.pipeline.finalWords('example raw');
    await d.toggle();
    await d.pipeline.process();
    await d.settle();
    expect(d.area, 'example raw');
    expect(d.status, SkStrings.processing);
    await d.pipeline.process();
    await d.settle();
    expect(d.area, 'EXAMPLE RAW');
    expect(d.drafts, ['EXAMPLE RAW']);
  });

  testWidgets('Done after an edit saves the same draft and republishes', (
    t,
  ) async {
    final d = ShellDriver(t);
    await d.pump(_iphone);
    await d.toggle();
    d.pipeline.finalWords('Example take.');
    await d.toggle();
    await d.pipeline.process();
    await d.settle();
    await t.enterText(find.byKey(_field), 'Example take, edited.');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('record-done')));
    await d.settle();
    expect(d.drafts, ['Example take, edited.']);
    expect(d.published.last, 'Example take, edited. ');
    expect(d.status, SkStrings.savedInsert);
  });

  testWidgets('Drafts editing the Record draft updates the Record area', (
    t,
  ) async {
    final d = ShellDriver(t);
    await d.pump(_iphone);
    await d.toggle();
    d.pipeline.finalWords('Example take.');
    await d.toggle();
    await d.pipeline.process();
    await d.settle();
    // An unsaved Record edit is kept before the editor opens.
    await t.enterText(find.byKey(_field), 'Example take, record edit.');
    await t.tap(find.text('Drafts').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Example take.'));
    await t.pumpAndSettle();
    // The editor opens on the newest text.
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('draft-editor-field')))
          .controller!
          .text,
      'Example take, record edit.',
    );
    await t.enterText(
      find.byKey(const ValueKey('draft-editor-field')),
      'Example take, drafts edit.',
    );
    await t.tap(find.byKey(const ValueKey('draft-editor-back')));
    await t.pumpAndSettle();
    expect(d.drafts, ['Example take, drafts edit.']);
    expect(d.area, 'Example take, drafts edit.');
  });

  testWidgets('L4: an IME composition is committed into the draft before a '
      'new recording', (t) async {
    final d = ShellDriver(t);
    await d.pump(_iphone);
    await d.toggle();
    d.pipeline.finalWords('Example.');
    await d.toggle();
    await d.pipeline.process();
    await d.settle();
    await t.showKeyboard(find.byKey(_field));
    t.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Example.示例',
        selection: TextSelection.collapsed(offset: 10),
        composing: TextRange(start: 8, end: 10),
      ),
    );
    await t.pump();
    await d.toggle(); // a new recording
    expect(d.drafts, ['Example.示例']);
    expect(d.controller.value.composing.isValid, isFalse);
  });

  testWidgets('D3: Duo stacked + keyboard up → Record gets the window', (
    t,
  ) async {
    final d = ShellDriver(t);
    await d.pump(_duoPortrait);
    await d.toggle();
    d.pipeline.finalWords('Example take.');
    await d.toggle();
    await d.pipeline.process();
    await d.settle();
    final paneFirst = find.byKey(const ValueKey('pane-first'));
    expect(paneFirst.hitTestable(), findsOneWidget);

    await t.tap(find.byKey(_field));
    t.view.viewInsets = const FakeViewPadding(bottom: 380);
    await t.pumpAndSettle();
    expect(paneFirst.hitTestable(), findsNothing);
    expect(
      find.byKey(const ValueKey('record-done')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byKey(_field).hitTestable(), findsOneWidget);
    // Drafts kept its state (still built, offstage).
    expect(d.drafts, ['Example take.']);

    FocusManager.instance.primaryFocus?.unfocus();
    t.view.resetViewInsets();
    await t.pumpAndSettle();
    expect(paneFirst.hitTestable(), findsOneWidget);
  });

  testWidgets('drafts store plain text; the suffix comes with publishing '
      '(Copy in Drafts too); old drafts publish as they are', (t) async {
    final d = ShellDriver(t);
    await d.pump(_iphone);
    await d.toggle();
    d.pipeline.finalWords('Example plain.');
    await d.toggle();
    await d.pipeline.process();
    await d.settle();
    expect(d.drafts, ['Example plain.']);
    expect(d.area, 'Example plain.');
    expect(d.published.last, 'Example plain. ');
    await t.tap(find.byKey(const ValueKey('record-copy')));
    await d.settle();
    expect(d.published.last, 'Example plain. ');
    expect(d.drafts, ['Example plain.']);

    // Drafts › editor › Copy publishes with the recording's suffix.
    await t.tap(find.text('Drafts').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Example plain.'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('draft-editor-copy')));
    await t.pump();
    expect(d.published.last, 'Example plain. ');
  });
}
