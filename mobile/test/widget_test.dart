import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/main.dart';

void main() {
  testWidgets('shows the Shinsoku mobile record surface', (tester) async {
    await tester.pumpWidget(const ShinsokuMobileApp());

    expect(find.text('Shinsoku'), findsOneWidget);
    expect(find.text('Ready to record'), findsOneWidget);
    expect(find.text('Dictation'), findsWidgets);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.tune_outlined), findsOneWidget);
  });

  testWidgets('shows a captured draft with explicit actions', (tester) async {
    await tester.pumpWidget(
      ShinsokuMobileApp(
        initialDrafts: [
          DraftEntry(
            text: 'Captured a clean mobile voice note with Shinsoku.',
            profileName: 'Dictation',
            createdAt: DateTime.now(),
          ),
        ],
        initialTabIndex: 1,
      ),
    );

    expect(
      find.text('Captured a clean mobile voice note with Shinsoku.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Edit draft'), findsOneWidget);
    expect(find.byTooltip('Copy draft'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
  });

  testWidgets('edits a draft before saving and copying it', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const keyboardChannel = MethodChannel(
      'net.potafree.shinsoku/keyboard_bridge',
    );
    final publishedTexts = <String>[];
    messenger.setMockMethodCallHandler(keyboardChannel, (call) async {
      if (call.method == 'publishLatestText') {
        final arguments = Map<String, dynamic>.from(call.arguments as Map);
        publishedTexts.add(arguments['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(keyboardChannel, null),
    );

    await tester.pumpWidget(
      ShinsokuMobileApp(
        initialDrafts: [
          DraftEntry(
            text: 'Original transcript.',
            profileName: 'Dictation',
            createdAt: DateTime.now(),
          ),
        ],
        initialTabIndex: 1,
      ),
    );

    await tester.tap(find.byTooltip('Edit draft'));
    await tester.pumpAndSettle();
    expect(find.text('Edit draft'), findsOneWidget);

    const editedText = 'A revised transcript ready to paste.';
    await tester.enterText(
      find.byKey(const ValueKey('draft-editor-field')),
      editedText,
    );
    await tester.tap(find.byKey(const ValueKey('draft-save-copy-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.widgetWithText(SelectableText, editedText), findsOneWidget);
    expect(find.text('Draft saved and copied to clipboard.'), findsOneWidget);
    expect(publishedTexts.last, editedText);
  });

  testWidgets('microphone setting redirects recording to settings', (
    tester,
  ) async {
    await tester.pumpWidget(const ShinsokuMobileApp());

    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Microphone access'), findsOneWidget);
  });
}
