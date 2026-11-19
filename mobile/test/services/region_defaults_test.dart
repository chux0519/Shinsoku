// i18n-01 I3: locale → defaults, and the first-launch applier (R1–R3).
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/region_defaults.dart';
import 'package:shinsoku_mobile/services/region_defaults_store.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

import '../support/l10n.dart';
import '../support/map_storage.dart';

Locale _l(String tag) {
  final parts = tag.split('-');
  return Locale.fromSubtags(
    languageCode: parts.first,
    scriptCode: parts.length > 2
        ? parts[1]
        : (parts.length == 2 && parts[1].length == 4 ? parts[1] : null),
    countryCode: parts.length > 2
        ? parts[2]
        : (parts.length == 2 && parts[1].length == 2 ? parts[1] : null),
  );
}

RegionDefaults _for(List<String> tags) =>
    regionDefaultsFor([for (final t in tags) _l(t)]);

String _p(String name) => ProviderSettingsStore.keyFor(name);

void main() {
  group('regionDefaultsFor', () {
    test('Chinese in every script and region → Fun-ASR with the zh hint', () {
      for (final tag in [
        'zh-Hans-CN',
        'zh-Hans-SG',
        'zh-Hans-MY',
        'zh-Hant-HK',
        'zh-Hant-MO',
        'zh-Hant-TW',
        'yue-Hant-HK',
        'zh',
      ]) {
        final d = _for([tag]);
        expect(d.speechProvider, speechProviderBailian, reason: tag);
        expect(d.bailianLanguageHint, 'zh', reason: tag);
        expect(d.sonioxLanguageHints, ['zh', 'en'], reason: tag);
        expect(d.translationSource, 'zh', reason: tag);
        expect(d.translationProfileId, zhToEnProfileId, reason: tag);
      }
    });

    test('a Chinese region with a non-Chinese language → Soniox', () {
      for (final tag in ['en-HK', 'en-SG', 'ms-MY', 'en-TW']) {
        expect(_for([tag]).speechProvider, speechProviderSoniox, reason: tag);
      }
    });

    test('everything else → Soniox, never Fun-ASR, no Fun-ASR hint', () {
      final cases = {
        'ja-JP': (['ja', 'en'], 'ja'),
        'ko-KR': (['ko', 'en'], 'ko'),
        'de-DE': (['de', 'en'], 'de'),
        'es-MX': (['es', 'en'], 'es'),
        'fr-CA': (['fr', 'en'], 'fr'),
        'pt-BR': (['pt', 'en'], 'pt'),
        'it-IT': (['it', 'en'], 'it'),
        'en-US': (['en'], null),
        'en-GB': (['en'], null),
        'nl-NL': (['nl', 'en'], null),
        'nb-NO': (['no', 'en'], null),
      };
      cases.forEach((tag, expected) {
        final d = _for([tag]);
        expect(d.speechProvider, speechProviderSoniox, reason: tag);
        expect(d.bailianLanguageHint, '', reason: tag);
        expect(d.sonioxLanguageHints, expected.$1, reason: tag);
        expect(d.translationSource, expected.$2, reason: tag);
      });
    });

    test('Soniox hints: first two known preferred languages, then en', () {
      expect(_for(['ja-JP', 'zh-Hant-TW', 'ko-KR']).sonioxLanguageHints, [
        'ja',
        'zh',
        'en',
      ]);
      expect(_for(['en-US', 'es-US']).sonioxLanguageHints, ['en', 'es']);
      // A language Soniox does not list is skipped.
      expect(_for(['xx-ZZ', 'de-AT']).sonioxLanguageHints, ['de', 'en']);
      // The device's first language decides the provider, not later ones.
      expect(
        _for(['en-US', 'zh-Hans-CN']).speechProvider,
        speechProviderSoniox,
      );
    });

    test('no locales → Soniox, English', () {
      final d = regionDefaultsFor(const []);
      expect(d.speechProvider, speechProviderSoniox);
      expect(d.sonioxLanguageHints, ['en']);
      expect(d.translationSource, isNull);
    });

    test('every hint is a value the provider accepts', () {
      for (final tag in [
        'zh-Hant-HK',
        'ja-JP',
        'pt-BR',
        'en-US',
        'fil-PH',
        'he-IL',
      ]) {
        final d = _for([tag]);
        expect(
          d.sonioxLanguageHints.every(sonioxLanguages.contains),
          isTrue,
          reason: tag,
        );
        expect(
          d.bailianLanguageHint.isEmpty ||
              funAsrRealtimeLanguages.contains(d.bailianLanguageHint),
          isTrue,
          reason: tag,
        );
      }
    });
  });

  group('built-in translation profile', () {
    test('zh keeps zh_to_en and its strings', () {
      final p = translationProfile(en, 'zh');
      expect(p.id, 'zh_to_en');
      expect(p.name, en.profileZhToEnName);
    });

    test('ja/ko/de/… get their own; English and others the generic one', () {
      expect(translationProfile(en, 'ja').name, 'JA -> EN');
      expect(translationProfile(en, 'ja').id, translateToEnProfileId);
      expect(translationProfile(en, 'pt').intent, contains('Portuguese'));
      expect(translationProfile(en, null).name, en.profileTranslateToEnName);
      expect(translationProfile(en, null).id, translateToEnProfileId);
    });

    test('the set keeps Dictation / Chat / Review first', () {
      final profiles = localizedDefaultProfiles(en, translationSource: 'ko');
      expect(profiles.map((p) => p.id), [
        'dictation',
        'chat',
        'review',
        'translate_to_en',
      ]);
      expect(profiles.last.name, 'KO -> EN');
    });
  });

  group('RegionDefaultsStore (R1–R3)', () {
    Future<RegionSetupOutcome?> apply(MapStorage s, List<String> tags) =>
        RegionDefaultsStore(
          storage: s,
        ).applyOnce(locales: [for (final t in tags) _l(t)], l10n: en);

    test(
      'fresh install: provider, hints and profiles written, marker last',
      () async {
        final s = MapStorage();
        expect(await apply(s, ['ja-JP']), RegionSetupOutcome.applied);
        expect(s.values[_p('speechProvider')], 'soniox');
        expect(s.values[_p('sonioxLanguageHints')], 'ja,en');
        expect(s.values[_p('bailianLanguageHint')], '');
        final profiles = jsonDecode(s.values[VoiceProfileStore.storageKey]!);
        expect((profiles as List).map((p) => p['name']), [
          'Dictation',
          'Chat',
          'Review',
          'JA -> EN',
        ]);
        expect(s.values.keys.last, regionDefaultsMarkerKey);
        // No API key or other setting is written.
        expect(s.values.containsKey(_p('sonioxApiKey')), isFalse);
      },
    );

    test('fresh Hong Kong install gets Fun-ASR', () async {
      final s = MapStorage();
      await apply(s, ['zh-Hant-HK']);
      expect(s.values[_p('speechProvider')], 'bailian');
      expect(s.values[_p('bailianLanguageHint')], 'zh');
    });

    test(
      'R3: an existing install keeps its provider; only the marker',
      () async {
        // Upgraded from a build before I3 with a saved key: provider key absent
        // (reads as bailian) — stays absent.
        final s = MapStorage({_p('bailianApiKey'): 'example-key'});
        expect(await apply(s, ['en-US']), RegionSetupOutcome.keptExisting);
        expect(s.values, {
          _p('bailianApiKey'): 'example-key',
          regionDefaultsMarkerKey: 'kept',
        });
      },
    );

    test(
      'R3: stored profiles alone also count as an existing install',
      () async {
        final s = MapStorage({VoiceProfileStore.storageKey: '[]'});
        expect(await apply(s, ['de-DE']), RegionSetupOutcome.keptExisting);
        expect(s.values.containsKey(_p('speechProvider')), isFalse);
      },
    );

    test(
      'R2: applied once; later launches (other language) write nothing',
      () async {
        final s = MapStorage();
        await apply(s, ['ja-JP']);
        final after = Map.of(s.values);
        expect(await apply(s, ['zh-Hant-TW']), RegionSetupOutcome.alreadyDone);
        expect(s.values, after);
      },
    );

    test('R1: a crash mid-apply never overwrites what was written', () async {
      final s = MapStorage(null, 1); // only the provider gets written
      expect(await apply(s, ['ja-JP']), isNull);
      expect(s.values, {_p('speechProvider'): 'soniox'});
      // The user picks Bailian before the next launch.
      s.values[_p('speechProvider')] = 'bailian';
      s.failAfter = null;
      expect(await apply(s, ['ja-JP']), RegionSetupOutcome.keptExisting);
      expect(s.values[_p('speechProvider')], 'bailian');
    });

    test('unreadable storage: nothing written, retried next launch', () async {
      final s = MapStorage()..readFails = true;
      expect(await apply(s, ['ja-JP']), isNull);
      expect(s.values, isEmpty);
      s.readFails = false;
      expect(await apply(s, ['ja-JP']), RegionSetupOutcome.applied);
    });
  });

  test('hint encoding round-trips and tolerates blanks', () {
    expect(ProviderSettingsStore.decodeHints(null), isEmpty);
    expect(ProviderSettingsStore.decodeHints(''), isEmpty);
    expect(ProviderSettingsStore.decodeHints('ja, en,'), ['ja', 'en']);
    expect(
      ProviderSettingsStore.decodeHints(
        ProviderSettingsStore.encodeHints(['zh', 'en']),
      ),
      ['zh', 'en'],
    );
  });
}
