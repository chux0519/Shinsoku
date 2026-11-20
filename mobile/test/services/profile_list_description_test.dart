// Built-in translation profiles: the list shows a localized one-line
// description while the (English) instruction is unchanged (release-01 R3).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/services/region_defaults.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

void main() {
  const tags = [
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ja'),
    Locale('ko'),
    Locale('de'),
    Locale('fr'),
    Locale('es'),
    Locale('pt', 'BR'),
    Locale('it'),
  ];

  for (final locale in tags) {
    test(
      '$locale: built-in translation profiles show the localized description',
      () async {
        final l = await AppLocalizations.delegate.load(locale);
        for (final source in [...translationSourceLanguages, null]) {
          final profile = translationProfile(l, source);
          expect(
            profileListDescription(l, profile),
            l.profileTranslationDescription,
            reason: 'source $source',
          );
          // The instruction sent to the model stays English.
          expect(profile.intent, startsWith('Translate '));
        }
        // Other built-ins keep their own (localized) description.
        for (final profile in localizedDefaultProfiles(l).take(3)) {
          expect(profileListDescription(l, profile), profile.intent);
        }
        if (locale.languageCode != 'en') {
          expect(
            l.profileTranslationDescription,
            isNot(contains('Translate')),
            reason: 'not translated',
          );
        }
      },
    );
  }

  test('an edited translation instruction shows as written', () async {
    final l = await AppLocalizations.delegate.load(const Locale('ja'));
    final edited = translationProfile(l, 'ja').copyWith(intent: '敬語で英訳する');
    expect(profileListDescription(l, edited), '敬語で英訳する');
  });

  test(
    'the legacy English ZH -> EN seed is recognised in any language',
    () async {
      final l = await AppLocalizations.delegate.load(const Locale('de'));
      final seed = defaultVoiceProfiles.firstWhere(
        (p) => p.id == zhToEnProfileId,
      );
      expect(profileListDescription(l, seed), l.profileTranslationDescription);
    },
  );
}
