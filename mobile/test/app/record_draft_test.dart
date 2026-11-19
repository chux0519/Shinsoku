// L3 through the real shell: a recording's edits land in its own draft, in
// place; Copy saves and publishes; Drafts edits the same entry.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/app/mobile_shell.dart';
import 'package:shinsoku_mobile/app/shell_scaffold.dart';
import 'package:shinsoku_mobile/features/drafts/drafts_view.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

class _Capture implements DebugCapture {
  int takes = 0;

  @override
  Future<void> start() async {}

  @override
  Future<String> stop() async => 'Take ${++takes}.';
}

const _field = ValueKey('record-transcript-field');

void main() {
  late List<String> published;

  setUp(() {
    published = [];
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
  });

  Future<void> pumpShell(WidgetTester t) async {
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildSkTheme(Brightness.dark),
        home: MobileShell(debugCapture: _Capture()),
      ),
    );
    await t.pump();
  }

  Future<void> toggle(WidgetTester t) async {
    await t.tap(
      find.descendant(
        of: find.byType(RecordView),
        matching: find.byType(SkRecordButton),
      ),
    );
    await t.pump();
    await t.pump();
  }

  List<String> draftTexts(WidgetTester t) => t
      .widgetList<DraftRow>(find.byType(DraftRow, skipOffstage: false))
      .map((row) => row.draft.text)
      .toList();

  Future<void> openTab(WidgetTester t, String label) async {
    await t.tap(
      find.descendant(of: find.byType(SkTabBar), matching: find.text(label)),
    );
    await t.pumpAndSettle();
  }

  testWidgets('Done and Copy edit the recording\'s own draft', (t) async {
    await pumpShell(t);
    await toggle(t);
    await toggle(t);
    // The result stays on Record, editable; it made one draft.
    expect(find.byType(RecordView).hitTestable(), findsOneWidget);
    expect(draftTexts(t), ['Take 1.']);

    await t.enterText(find.byKey(_field), 'Take 1, edited.');
    await t.tap(find.byKey(const ValueKey('record-done')));
    await t.pump();
    expect(draftTexts(t), ['Take 1, edited.']);

    await t.enterText(find.byKey(_field), 'Take 1, edited twice.');
    await t.tap(find.byKey(const ValueKey('record-copy')));
    await t.pump();
    expect(draftTexts(t), ['Take 1, edited twice.']);
    expect(published.last, 'Take 1, edited twice.');

    // A second take gets its own draft; editing it leaves the first alone.
    await t.enterText(find.byKey(_field), 'Take 1, unsaved.');
    await toggle(t); // start: unsaved edits are kept first
    expect(draftTexts(t), ['Take 1, unsaved.']);
    await toggle(t);
    expect(draftTexts(t), ['Take 2.', 'Take 1, unsaved.']);
    await t.enterText(find.byKey(_field), 'Take 2, edited.');
    await t.tap(find.byKey(const ValueKey('record-done')));
    await t.pump();
    expect(draftTexts(t), ['Take 2, edited.', 'Take 1, unsaved.']);
  });

  testWidgets('Drafts opens the same editor; Save updates that draft', (
    t,
  ) async {
    await pumpShell(t);
    await toggle(t);
    await toggle(t);
    await openTab(t, ShellScaffold.tabs[1].label);
    await t.tap(find.text('Take 1.'));
    await t.pumpAndSettle();
    expect(find.byType(SkTranscriptArea), findsOneWidget);
    await t.enterText(
      find.byKey(const ValueKey('draft-editor-field')),
      'Take 1, from Drafts.',
    );
    await t.tap(find.byKey(const ValueKey('draft-editor-save')));
    await t.pumpAndSettle();
    expect(draftTexts(t), ['Take 1, from Drafts.']);

    // Record still edits that same draft (L3), not a new one.
    await openTab(t, ShellScaffold.tabs[0].label);
    await t.enterText(find.byKey(_field), 'Take 1, from Record.');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('record-done')));
    await t.pump();
    expect(draftTexts(t), ['Take 1, from Record.']);
  });
}
