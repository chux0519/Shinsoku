import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/features/settings/field_rules_view.dart';
import 'package:shinsoku_mobile/features/settings/use_in_apps_view.dart';
import 'package:shinsoku_mobile/services/active_profile.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/field_rules.dart';
import 'package:shinsoku_mobile/services/profile_reason.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/theme.dart';

class _Storage implements FieldRulesStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async => value = v;
}

class _Bridge implements FieldRulesBridge {
  Map<String, String>? mirrored;
  @override
  Future<void> setFieldRules(Map<String, String> rules) async =>
      mirrored = rules;
}

Widget _app(Widget home) =>
    MaterialApp(theme: buildSkTheme(Brightness.dark), home: home);

void main() {
  group('FieldRulesStore', () {
    test('saves, reloads and mirrors {kind: profileId}', () async {
      final storage = _Storage();
      final bridge = _Bridge();
      final store = FieldRulesStore(storage: storage, bridge: bridge);
      await store.save(const FieldRules().set(FieldKind.search, 'chat'));
      expect(bridge.mirrored, {'search': 'chat'});
      final reloaded = await FieldRulesStore(
        storage: storage,
        bridge: bridge,
      ).load();
      expect(reloaded[FieldKind.search], 'chat');
      expect(reloaded[FieldKind.url], isNull);
    });

    test('deleting a profile removes the rules that point to it', () async {
      final storage = _Storage();
      final bridge = _Bridge();
      final store = FieldRulesStore(storage: storage, bridge: bridge);
      await store.save(
        const FieldRules()
            .set(FieldKind.search, 'chat')
            .set(FieldKind.email, 'review'),
      );
      final now = await store.pruneTo(['dictation', 'review']);
      expect(now.toJson(), {'email': 'review'});
      expect(bridge.mirrored, {'email': 'review'});
      expect((await store.load()).toJson(), {'email': 'review'});
    });

    test('unknown kinds and empty ids are ignored; None clears', () {
      final rules = FieldRules.decode('{"search":"a","bogus":"b","url":""}');
      expect(rules.toJson(), {'search': 'a'});
      expect(rules.set(FieldKind.search, null).toJson(), isEmpty);
      expect(FieldRules.decode('not json').toJson(), isEmpty);
    });
  });

  testWidgets('field rules screen picks a profile and None', (tester) async {
    FieldRules? saved;
    await tester.pumpWidget(
      _app(
        FieldRulesView(
          profiles: defaultVoiceProfiles,
          rules: const FieldRules(),
          onChanged: (r) async => saved = r,
        ),
      ),
    );
    for (final label in ['Search', 'Web address', 'Email', 'Message']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(saved?[FieldKind.search], 'chat');
    expect(find.text('Chat'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    expect(saved?[FieldKind.search], isNull);
  });

  testWidgets('use in apps: steps, one action, iOS 16 note', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _app(UseInAppsView(onOpenShortcuts: () async => ++opened > 0)),
    );
    expect(find.text('Open Shortcuts'), findsOneWidget);
    expect(find.text(UseInAppsView.iosNote), findsNothing);
    await tester.tap(find.text('Open Shortcuts'));
    expect(opened, 1);

    await tester.pumpWidget(
      _app(
        UseInAppsView(onOpenShortcuts: () async => true, iosMajorVersion: 15),
      ),
    );
    expect(find.text(UseInAppsView.iosNote), findsOneWidget);
  });

  group('profile reason', () {
    test('wording per source', () {
      expect(
        activeProfileReason('Chat', ProfileSource.manual),
        'Chat · set by you',
      );
      expect(
        activeProfileReason('Chat', ProfileSource.automation),
        'Chat · set by automation',
      );
      expect(
        activeProfileReason('Dictation', ProfileSource.byDefault),
        'Dictation · default',
      );
      expect(
        activeProfileReason('Dictation', ProfileSource.fieldRule),
        'Dictation · default',
      );
    });

    testWidgets('Record shows the reason under the status line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: RecordView(
              profiles: defaultVoiceProfiles,
              selectedProfileIndex: 1,
              captureState: CaptureState.idle,
              microphoneAllowed: true,
              smokeTestStatus: null,
              onProfileSelected: (_) {},
              onCapturePressed: () {},
              profileReason: 'Chat · set by you',
            ),
          ),
        ),
      );
      expect(find.text('Chat · set by you'), findsOneWidget);
    });
  });
}
