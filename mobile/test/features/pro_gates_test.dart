import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/app/bridges.dart';
import 'package:shinsoku_mobile/features/settings/field_rules_view.dart';
import 'package:shinsoku_mobile/features/settings/profile_editor_sheet.dart';
import 'package:shinsoku_mobile/features/settings/settings_view.dart';
import 'package:shinsoku_mobile/features/settings/use_in_apps_view.dart';
import 'package:shinsoku_mobile/main.dart';
import 'package:shinsoku_mobile/nearby/nearby_microphone_view.dart';
import 'package:shinsoku_mobile/nearby/nearby_tab.dart';
import 'package:shinsoku_mobile/services/active_profile.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/field_rules.dart';
import 'package:shinsoku_mobile/services/pro_entitlement.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

import '../support/l10n.dart';

/// pricing-01 gates: locked features stay visible with a Pro mark and open
/// the Pro sheet; with Pro they work as before.
Widget _app(Widget home, ProEntitlement pro) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildSkTheme(Brightness.dark),
  builder: (context, child) => ProScope(entitlement: pro, child: child!),
  home: home,
);

const _custom = VoiceProfile(
  id: 'profile_example',
  name: 'Example notes',
  intent: 'Bullet points',
  commitSuffix: CommitSuffix.newline,
  autoCommit: false,
);

/// Tall enough that Settings builds every row (its list is lazy).
void _phone(WidgetTester tester, {double height = 874}) {
  tester.view.physicalSize = Size(402, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder get _sheetTitle => find.text(en.proName);
Finder get _badges => find.byType(SkProBadge);

void main() {
  group('Settings', () {
    late int added;

    Widget settings(ProEntitlement pro) => _app(
      Scaffold(
        body: SettingsView(
          microphoneAllowed: true,
          keyboardExtensionEnabled: false,
          cloudProcessingEnabled: true,
          providerSettings: ProviderSettings.defaults(),
          providerSettingsLoading: false,
          providerSettingsSaving: false,
          onMicrophonePressed: () {},
          onKeyboardChanged: (_) {},
          onCloudProcessingChanged: (_) {},
          onProviderSettingsSaved: (_) async {},
          profiles: const [...defaultVoiceProfiles, _custom],
          onProfileAdded: () => added++,
          onProfileOpened: (_) {},
        ),
      ),
      pro,
    );

    setUp(() => added = 0);

    testWidgets('without Pro: badges, Add profile opens the Pro sheet', (
      tester,
    ) async {
      _phone(tester, height: 3000);
      await tester.pumpWidget(settings(FakeProEntitlement()));
      // Add profile, Use in apps, Field rules.
      expect(_badges, findsNWidgets(3));
      // The custom profile stays listed (E3).
      expect(find.text('Example notes'), findsOneWidget);
      final add = find.byKey(const ValueKey('settings-add-profile'));
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(added, 0);
      expect(find.byType(SkProSheet), findsOneWidget);
      expect(find.text(en.proBuyWithPrice(r'$4.99')), findsOneWidget);
      expect(find.text(en.proNote), findsOneWidget);
      expect(find.text(en.proRestore), findsWidgets);
    });

    testWidgets('Pro row: price without Pro, Unlocked with it', (tester) async {
      _phone(tester, height: 3000);
      final pro = FakeProEntitlement();
      await tester.pumpWidget(settings(pro));
      final row = find.byKey(const ValueKey('settings-pro'));
      expect(
        find.descendant(of: row, matching: find.text(r'$4.99')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-pro-restore')),
        findsOneWidget,
      );

      // Buying from the sheet unlocks everything live.
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pro-buy')));
      await tester.pumpAndSettle();
      expect(pro.value.owned, isTrue);
      expect(find.text(en.proOwned), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pro-done')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: row, matching: find.text(en.proStatusUnlocked)),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('settings-pro-restore')), findsNothing);
      expect(_badges, findsNothing);
    });

    testWidgets('with Pro: Add profile opens the editor callback', (
      tester,
    ) async {
      _phone(tester, height: 3000);
      await tester.pumpWidget(settings(FakeProEntitlement(owned: true)));
      expect(_badges, findsNothing);
      final add = find.byKey(const ValueKey('settings-add-profile'));
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(added, 1);
      expect(find.byType(SkProSheet), findsNothing);
    });

    testWidgets('Restore Purchases row shows the outcome in the sheet', (
      tester,
    ) async {
      _phone(tester, height: 3000);
      final pro = FakeProEntitlement();
      await tester.pumpWidget(settings(pro));
      final restore = find.byKey(const ValueKey('settings-pro-restore'));
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(pro.restoreCalls, 1);
      expect(find.text(en.proNoticeNothingToRestore), findsOneWidget);
    });
  });

  group('Profile editor', () {
    Widget editor(ProEntitlement pro) =>
        _app(const Scaffold(body: ProfileEditorSheet(profile: _custom)), pro);

    testWidgets('without Pro: read-only, Unlock opens the sheet; buying '
        'makes it editable', (tester) async {
      _phone(tester);
      final pro = FakeProEntitlement();
      await tester.pumpWidget(editor(pro));
      expect(_badges, findsOneWidget);
      expect(find.text(en.proLockedProfileEditor), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-save')), findsNothing);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.enabled, isFalse);
      }
      expect(
        tester
            .widget<SkSegmented<CommitSuffix>>(
              find.byType(SkSegmented<CommitSuffix>),
            )
            .onChanged,
        isNull,
      );
      // The stored values are shown unchanged.
      expect(find.text('Example notes'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile-unlock')));
      await tester.pumpAndSettle();
      expect(find.byType(SkProSheet), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pro-buy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pro-done')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('profile-save')), findsOneWidget);
      expect(_badges, findsNothing);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.enabled, isTrue);
      }
    });

    testWidgets('with Pro: editable, no badge', (tester) async {
      _phone(tester);
      await tester.pumpWidget(editor(FakeProEntitlement(owned: true)));
      expect(_badges, findsNothing);
      expect(find.byKey(const ValueKey('profile-save')), findsOneWidget);
    });
  });

  group('Field rules', () {
    testWidgets('without Pro: rules shown, rows open the Pro sheet, nothing '
        'changes', (tester) async {
      _phone(tester);
      final changes = <FieldRules>[];
      await tester.pumpWidget(
        _app(
          FieldRulesView(
            profiles: defaultVoiceProfiles,
            rules: const FieldRules({FieldKind.search: 'chat'}),
            onChanged: (rules) async => changes.add(rules),
          ),
          FakeProEntitlement(),
        ),
      );
      expect(find.text(en.proLockedFieldRules), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      await tester.tap(find.text(en.fieldKindSearch));
      await tester.pumpAndSettle();
      expect(find.byType(SkProSheet), findsOneWidget);
      expect(find.text('Review'), findsNothing); // no profile picker
      expect(changes, isEmpty);
    });

    testWidgets('with Pro: rows open the picker', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          FieldRulesView(
            profiles: defaultVoiceProfiles,
            rules: const FieldRules(),
            onChanged: (_) async {},
          ),
          FakeProEntitlement(owned: true),
        ),
      );
      expect(find.text(en.proLockedFieldRules), findsNothing);
      await tester.tap(find.text(en.fieldKindSearch));
      await tester.pumpAndSettle();
      expect(find.byType(SkProSheet), findsNothing);
      expect(find.text('Review'), findsOneWidget);
    });
  });

  group('Use in apps', () {
    testWidgets('without Pro: steps stay, the action opens the Pro sheet', (
      tester,
    ) async {
      _phone(tester);
      var opened = 0;
      await tester.pumpWidget(
        _app(
          UseInAppsView(onOpenShortcuts: () async => ++opened > 0),
          FakeProEntitlement(),
        ),
      );
      expect(find.text(en.proLockedUseInApps), findsOneWidget);
      expect(find.text(en.useInAppsOpenStep1), findsOneWidget);
      expect(find.text(en.useInAppsOpenShortcuts), findsNothing);
      await tester.tap(find.byKey(const ValueKey('use-in-apps-unlock')));
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(find.byType(SkProSheet), findsOneWidget);
    });

    testWidgets('with Pro: opens Shortcuts', (tester) async {
      _phone(tester);
      var opened = 0;
      await tester.pumpWidget(
        _app(
          UseInAppsView(onOpenShortcuts: () async => ++opened > 0),
          FakeProEntitlement(owned: true),
        ),
      );
      await tester.tap(find.text(en.useInAppsOpenShortcuts));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('Desktop tab', () {
    const profiles = [NearbyProfileOption(id: 'default', label: 'Dictation')];

    testWidgets('without Pro: what it is and the Pro sheet, no pairing', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          const Scaffold(body: NearbyTab(profiles: profiles)),
          FakeProEntitlement(),
        ),
      );
      expect(find.byType(NearbyMicrophoneView), findsNothing);
      expect(find.text(en.proLockedDesktop), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nearby-unlock')));
      await tester.pumpAndSettle();
      expect(find.byType(SkProSheet), findsOneWidget);
    });

    testWidgets('with Pro: the pairing page', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          const Scaffold(body: NearbyTab(profiles: profiles)),
          FakeProEntitlement(owned: true),
        ),
      );
      expect(find.byType(NearbyMicrophoneView), findsOneWidget);
      expect(find.text(en.proLockedDesktop), findsNothing);
    });
  });

  group('Pro sheet states', () {
    Future<void> open(WidgetTester tester, ProEntitlement pro) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: SkButton(
                  label: 'open', // i18n-ignore
                  onPressed: () => showProSheet(context),
                ),
              ),
            ),
          ),
          pro,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('loading price: placeholder, Buy disabled', (tester) async {
      await open(tester, FakeProEntitlement(price: null, busy: true));
      expect(_sheetTitle, findsOneWidget);
      expect(find.text(en.proPriceLoading), findsOneWidget);
      final buy = tester.widget<SkButton>(
        find.byKey(const ValueKey('pro-buy')),
      );
      expect(buy.busy, isTrue);
    });

    for (final (result, text) in [
      (ProPurchaseResult.pending, en.proNoticePending),
      (ProPurchaseResult.cancelled, en.proNoticeCancelled),
      (ProPurchaseResult.failed, en.proNoticeFailed),
    ]) {
      testWidgets('purchase $result shows friendly text', (tester) async {
        final pro = FakeProEntitlement(purchaseResult: result);
        await open(tester, pro);
        await tester.tap(find.byKey(const ValueKey('pro-buy')));
        await tester.pumpAndSettle();
        expect(find.text(text), findsOneWidget);
        expect(pro.value.owned, isFalse);
      });
    }

    testWidgets('closing the sheet clears the notice', (tester) async {
      final pro = FakeProEntitlement(
        purchaseResult: ProPurchaseResult.cancelled,
      );
      await open(tester, pro);
      await tester.tap(find.byKey(const ValueKey('pro-buy')));
      await tester.pumpAndSettle();
      expect(pro.value.notice, ProNotice.cancelled);
      await tester.tapAt(const Offset(200, 40)); // the scrim
      await tester.pumpAndSettle();
      expect(pro.value.notice, isNull);
    });

    testWidgets('no store plugin: plain Buy label, unavailable on tap', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        ChannelProEntitlement.storeChannel,
        (call) async => throw MissingPluginException(),
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          ChannelProEntitlement.storeChannel,
          null,
        ),
      );
      final pro = ChannelProEntitlement();
      addTearDown(pro.dispose);
      await open(tester, pro);
      await tester.pumpAndSettle();
      expect(find.text(en.proBuy), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pro-buy')));
      await tester.pumpAndSettle();
      expect(find.text(en.proNoticeUnavailable), findsOneWidget);
      expect(pro.value.owned, isFalse);
    });

    testWidgets('a store that never answers stops "Loading price…"', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        ChannelProEntitlement.storeChannel,
        (call) => Completer<Object?>().future,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          ChannelProEntitlement.storeChannel,
          null,
        ),
      );
      final pro = ChannelProEntitlement();
      addTearDown(pro.dispose);
      await open(tester, pro);
      expect(find.text(en.proPriceLoading), findsOneWidget);
      await tester.pump(ChannelProEntitlement.stateTimeout);
      await tester.pump(ChannelProEntitlement.stateTimeout);
      await tester.pumpAndSettle();
      expect(find.text(en.proBuy), findsOneWidget);
      final buy = tester.widget<SkButton>(
        find.byKey(const ValueKey('pro-buy')),
      );
      expect(buy.busy, isFalse);
      expect(buy.onPressed, isNotNull);
    });
  });

  group('E3: losing Pro never deletes data', () {
    late Map<String, String> stored;
    late List<String> deletes;
    const secure = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );

    setUp(() {
      deletes = [];
      stored = {
        'voice_profiles.v1': jsonEncode([
          for (final p in [...defaultVoiceProfiles, _custom]) p.toJson(),
        ]),
        'field_rules.v1': jsonEncode({'search': _custom.id}),
      };
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(secure, (call) async {
        final args = (call.arguments as Map?) ?? const {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return stored[key];
          case 'write':
            stored[key!] = args['value'] as String;
          case 'delete':
            deletes.add(key!);
            stored.remove(key);
          case 'deleteAll':
            deletes.add('*');
            stored.clear();
          case 'readAll':
            return Map.of(stored);
          case 'containsKey':
            return stored.containsKey(key);
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
        MethodChannelProfileGroupBridge.channel,
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        DeepLinkBridge.channel,
        (_) async => null,
      );
      addTearDown(() {
        for (final channel in [
          secure,
          MethodChannelProfileGroupBridge.channel,
          DeepLinkBridge.channel,
        ]) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
    });

    testWidgets('revocation keeps custom profiles and field rules stored and '
        'listed', (tester) async {
      _phone(tester, height: 3000);
      final pro = FakeProEntitlement(owned: true);
      await tester.pumpWidget(ShinsokuMobileApp(proEntitlement: pro));
      await tester.pumpAndSettle();
      final before = Map.of(stored);
      expect(before['voice_profiles.v1'], contains(_custom.id));

      pro.setOwned(false); // E2: refund / Family Sharing removed
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.tune_outlined));
      await tester.pumpAndSettle();

      expect(deletes, isEmpty);
      expect(stored['voice_profiles.v1'], before['voice_profiles.v1']);
      expect(stored['field_rules.v1'], before['field_rules.v1']);
      // Still listed and selectable, now behind the Pro mark for editing.
      expect(find.text('Example notes'), findsWidgets);
      expect(_badges, findsWidgets);
    });
  });
}
