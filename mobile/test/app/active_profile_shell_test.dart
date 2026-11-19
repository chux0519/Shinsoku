import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/main.dart';
import 'package:shinsoku_mobile/services/active_profile.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// profile-01 P1: the app shell against a fake App Group (the profiles
/// channel), secure storage answering "nothing stored".
void main() {
  late Map<String, String> group;
  late List<String> setActiveCalls;

  setUp(() {
    group = {};
    setActiveCalls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      MethodChannelProfileGroupBridge.channel,
      (call) async {
        final args = call.arguments as Map?;
        switch (call.method) {
          case 'publishProfiles':
            group['profiles.v1'] = args!['profiles'] as String;
          case 'setActive':
            group['activeProfile.v1'] = args!['selection'] as String;
            setActiveCalls.add(args['selection'] as String);
          case 'readActive':
            return group['activeProfile.v1'];
        }
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(
        MethodChannelProfileGroupBridge.channel,
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
    });
  });

  Future<void> pumpPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ShinsokuMobileApp());
    await tester.pumpAndSettle();
  }

  int selectedIndex(WidgetTester tester) =>
      tester.widget<SkSegmented<int>>(find.byType(SkSegmented<int>)).selected;

  testWidgets('launch migrates: publishes ids/names and a default selection', (
    tester,
  ) async {
    await pumpPhone(tester);
    final list = jsonDecode(group['profiles.v1']!) as List;
    expect(list, hasLength(4));
    for (final item in list) {
      expect((item as Map).keys.toSet(), {'id', 'name'});
    }
    final selection = ProfileSelection.decode(group['activeProfile.v1']);
    expect(selection?.profileId, 'dictation');
    expect(selection?.source, ProfileSource.byDefault);
  });

  testWidgets('the Record selector writes a manual selection', (tester) async {
    await pumpPhone(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    final selection = ProfileSelection.decode(setActiveCalls.last);
    expect(selection?.profileId, 'review');
    expect(selection?.source, ProfileSource.manual);
    expect(selectedIndex(tester), 2);
  });

  testWidgets('a selection written by the keyboard shows after resume', (
    tester,
  ) async {
    group['activeProfile.v1'] = ProfileSelection(
      profileId: 'review',
      source: ProfileSource.automation,
      at: DateTime.utc(2026, 11, 19),
    ).encode();
    await pumpPhone(tester);
    expect(selectedIndex(tester), 2, reason: 'kept on launch (no rewrite)');
    expect(setActiveCalls, isEmpty);

    group['activeProfile.v1'] = ProfileSelection(
      profileId: 'chat',
      source: ProfileSource.automation,
      at: DateTime.utc(2026, 11, 19, 1),
    ).encode();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(selectedIndex(tester), 1);
  });

  testWidgets('PR3: a selection pointing at a missing profile is repaired', (
    tester,
  ) async {
    group['activeProfile.v1'] = ProfileSelection(
      profileId: 'deleted-profile',
      source: ProfileSource.manual,
      at: DateTime.utc(2026, 11, 19),
    ).encode();
    await pumpPhone(tester);
    expect(selectedIndex(tester), 0);
    final selection = ProfileSelection.decode(group['activeProfile.v1']);
    expect(selection?.profileId, 'dictation');
    expect(selection?.source, ProfileSource.byDefault);
  });
}
