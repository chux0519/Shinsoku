import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/app/bridges.dart';
import 'package:shinsoku_mobile/features/settings/field_rules_view.dart';
import 'package:shinsoku_mobile/features/settings/use_in_apps_view.dart';
import 'package:shinsoku_mobile/main.dart';
import 'package:shinsoku_mobile/services/active_profile.dart';
import 'package:shinsoku_mobile/services/pro_entitlement.dart';

/// `shinsoku://settings/<page>` deep links (scene-rules): the shell selects
/// the Settings tab and pushes the page; unknown pages are ignored; a link
/// delivered twice pushes once.
void main() {
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
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
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        MethodChannelProfileGroupBridge.channel,
        DeepLinkBridge.channel,
      ]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  });

  Future<void> pumpPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShinsokuMobileApp(proEntitlement: FakeProEntitlement(owned: true)),
    );
    await tester.pumpAndSettle();
  }

  /// Delivers `openURL` from the host, as `DeepLinkRouter` does.
  Future<void> openUrl(WidgetTester tester, String url) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      DeepLinkBridge.channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('openURL', url)),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  /// The Settings page is the one on screen (other tabs stay built offstage).
  bool settingsTabSelected(WidgetTester tester) =>
      find.text('Microphone access').hitTestable().evaluate().isNotEmpty;

  testWidgets('settings/field-rules opens Field rules on the Settings tab', (
    tester,
  ) async {
    await pumpPhone(tester);
    expect(find.byType(FieldRulesView), findsNothing);

    await openUrl(tester, 'shinsoku://settings/field-rules');
    expect(find.byType(FieldRulesView), findsOneWidget);
    // Search is the first row; its sheet lists the profiles.
    expect(find.text('Search'), findsOneWidget);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsWidgets);

    // Delivered again (openURL retry / consumeInitialURL): no second page.
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    await openUrl(tester, 'shinsoku://settings/field-rules');
    expect(find.byType(FieldRulesView), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(FieldRulesView), findsNothing);
    expect(settingsTabSelected(tester), isTrue);
  });

  testWidgets('settings/use-in-apps opens Use in apps on the Settings tab', (
    tester,
  ) async {
    await pumpPhone(tester);
    await openUrl(tester, 'shinsoku://settings/use-in-apps');
    expect(find.byType(UseInAppsView), findsOneWidget);
    expect(find.byType(FieldRulesView), findsNothing);
    Navigator.of(tester.element(find.byType(UseInAppsView))).pop();
    await tester.pumpAndSettle();
    expect(settingsTabSelected(tester), isTrue);
  });

  testWidgets('unknown settings pages are ignored', (tester) async {
    await pumpPhone(tester);
    await openUrl(tester, 'shinsoku://settings/nope');
    await openUrl(tester, 'shinsoku://settings');
    expect(find.byType(FieldRulesView), findsNothing);
    expect(find.byType(UseInAppsView), findsNothing);
    expect(settingsTabSelected(tester), isFalse);
  });
}
