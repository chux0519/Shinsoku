import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/main.dart';

void main() {
  testWidgets('shows the Shinsoku mobile record surface', (tester) async {
    await tester.pumpWidget(const ShinsokuMobileApp());

    expect(find.text('Shinsoku'), findsOneWidget);
    expect(find.text('Ready to record'), findsOneWidget);
    expect(find.text('Dictation'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('creates a draft from the recording flow', (tester) async {
    await tester.pumpWidget(const ShinsokuMobileApp());

    await tester.tap(find.text('Start Recording'));
    await tester.pump();
    expect(find.text('Listening'), findsOneWidget);

    await tester.tap(find.text('Stop and Draft'));
    await tester.pump();
    expect(find.text('Processing transcript'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    expect(
      find.text('Captured a clean mobile voice note with Shinsoku.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
  });

  testWidgets('microphone setting redirects recording to settings', (
    tester,
  ) async {
    await tester.pumpWidget(const ShinsokuMobileApp());

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Microphone access'));
    await tester.pump();

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.tap(find.text('Open Settings'));
    await tester.pump();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Microphone access'), findsOneWidget);
  });
}
