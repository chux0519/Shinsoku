import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/main.dart';
import 'package:shinsoku_mobile/services/drafts.dart';
import 'package:shinsoku_mobile/ui/strings.dart';

/// An iPhone-sized window: these flows test the compact (phone) shell. The
/// default 800 × 600 test window is a regular (two-pane) size.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shows the Shinsoku mobile record surface', (tester) async {
    _phone(tester);
    await tester.pumpWidget(const ShinsokuMobileApp());

    expect(find.text('Shinsoku'), findsOneWidget);
    expect(find.text('Ready to record'), findsOneWidget);
    expect(find.text('Dictation'), findsWidgets);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.tune_outlined), findsOneWidget);
  });

  testWidgets('shows a captured draft with explicit actions', (tester) async {
    _phone(tester);
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

    const text = 'Captured a clean mobile voice note with Shinsoku.';
    expect(find.text(text), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.byTooltip('Copy draft'), findsOneWidget);

    // Swipe to delete, then undo (DESIGN §7).
    await tester.drag(find.text(text), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text(text), findsNothing);
    expect(find.text('Draft deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text(text), findsOneWidget);
  });

  testWidgets('edits a draft before saving and copying it', (tester) async {
    _phone(tester);
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

    // Tapping the row opens it in the borderless editor (live-01).
    await tester.tap(find.text('Original transcript.'));
    await tester.pumpAndSettle();
    expect(find.text(SkStrings.draftEditorTitle), findsOneWidget);

    const editedText = 'A revised transcript ready to paste.';
    await tester.enterText(
      find.byKey(const ValueKey('draft-editor-field')),
      editedText,
    );
    await tester.tap(find.byKey(const ValueKey('draft-editor-copy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(SkStrings.copied), findsOneWidget);
    expect(publishedTexts.last, editedText);

    // Back: the list shows the same draft, edited (L3: no second draft).
    await tester.tap(find.byKey(const ValueKey('draft-editor-back')));
    await tester.pumpAndSettle();
    expect(find.text(editedText), findsOneWidget);
    expect(find.text('Original transcript.'), findsNothing);
  });

  testWidgets('microphone setting redirects recording to settings', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(const ShinsokuMobileApp());

    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Microphone access'), findsOneWidget);
  });

  testWidgets('shows the pinned local desktop microphone workflow', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(const ShinsokuMobileApp());

    await tester.tap(find.byIcon(Icons.wifi_tethering));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Desktop Mic'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('nearby-discover-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('nearby-profile-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('nearby-record-button')), findsOneWidget);
  });
}
