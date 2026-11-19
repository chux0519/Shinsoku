// i18n-01 I3: saving Settings keeps the language hints (they are not edited
// there; R1 — what first launch or the user stored is never dropped).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/features/settings/settings_view.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/ui/theme.dart';

import '../support/l10n.dart' show en;

void main() {
  testWidgets('Save keeps the stored language hints', (tester) async {
    ProviderSettings? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSkTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SettingsView(
            microphoneAllowed: true,
            keyboardExtensionEnabled: false,
            cloudProcessingEnabled: true,
            providerSettings: ProviderSettings.defaults().copyWith(
              speechProvider: 'soniox',
              sonioxLanguageHints: ['ja', 'en'],
              bailianLanguageHint: 'zh',
            ),
            providerSettingsLoading: false,
            providerSettingsSaving: false,
            onMicrophonePressed: () {},
            onKeyboardChanged: (_) {},
            onCloudProcessingChanged: (_) {},
            onProviderSettingsSaved: (settings) async => saved = settings,
          ),
        ),
      ),
    );
    final save = find.text(en.settingsSave);
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.speechProvider, 'soniox');
    expect(saved!.sonioxLanguageHints, ['ja', 'en']);
    expect(saved!.bailianLanguageHint, 'zh');
  });
}
