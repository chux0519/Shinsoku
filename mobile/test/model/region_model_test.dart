// i18n-01 I3: seeded model test for first-launch region defaults (R1–R3,
// docs/design/state_invariants.md). The system under test is the real
// RegionDefaultsStore over a map storage; events are app launches (with any
// device language, a crash after n writes, or unreadable storage) and user /
// older-build writes of provider settings and profiles.
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/region_defaults_store.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

import '../support/l10n.dart';
import '../support/map_storage.dart';
import 'harness.dart';

sealed class RegionEvent {
  const RegionEvent();
}

class Launch extends RegionEvent {
  const Launch(this.language, {this.failAfter, this.readFails = false});
  final String language;
  final int? failAfter;
  final bool readFails;

  @override
  String toString() =>
      "Launch('$language'${failAfter == null ? '' : ', failAfter: $failAfter'}"
      "${readFails ? ', readFails: true' : ''})";
}

/// The user (or a build from before I3) stores a value.
class UserWrite extends RegionEvent {
  const UserWrite(this.key, this.value);
  final String key;
  final String value;

  @override
  String toString() => "UserWrite('$key', '$value')";
}

final _userKeys = [
  ProviderSettingsStore.keyFor('speechProvider'),
  ProviderSettingsStore.keyFor('sonioxLanguageHints'),
  ProviderSettingsStore.keyFor('bailianApiKey'),
  VoiceProfileStore.storageKey,
];
const _languages = ['en', 'ja', 'zh', 'de', 'ko', 'yue'];

RegionEvent genEvent(Random rng, List<RegionEvent> sofar) {
  if (rng.nextInt(3) == 0) {
    final key = _userKeys[rng.nextInt(_userKeys.length)];
    return UserWrite(key, 'user-${sofar.length}');
  }
  return Launch(
    _languages[rng.nextInt(_languages.length)],
    failAfter: rng.nextInt(5) == 0 ? rng.nextInt(5) : null,
    readFails: rng.nextInt(8) == 0,
  );
}

final _regionKeys = {
  ProviderSettingsStore.keyFor('speechProvider'),
  ProviderSettingsStore.keyFor('sonioxLanguageHints'),
  ProviderSettingsStore.keyFor('bailianLanguageHint'),
  VoiceProfileStore.storageKey,
};

Future<ModelFailure?> runRegionSequence(
  List<RegionEvent> seq, {
  RegionDefaultsStore Function(MapStorage)? makeStore,
}) async {
  final storage = MapStorage();
  final store = (makeStore ?? (s) => RegionDefaultsStore(storage: s))(storage);
  // Reference model.
  final userValues = <String, String>{};
  var userSettingsBeforeApply = false; // R3
  var regionWriteLaunches = 0; // R2

  for (var i = 0; i < seq.length; i++) {
    final event = seq[i];
    switch (event) {
      case UserWrite(:final key, :final value):
        storage.values[key] = value;
        userValues[key] = value;
        if (regionWriteLaunches == 0) userSettingsBeforeApply = true;
      case Launch(:final language, :final failAfter, :final readFails):
        final before = Map.of(storage.values);
        storage
          ..failAfter = failAfter == null ? null : storage.writes + failAfter
          ..readFails = readFails;
        await store.applyOnce(locales: [Locale(language)], l10n: en);
        storage
          ..failAfter = null
          ..readFails = false;
        final changed = {
          for (final key in storage.values.keys)
            if (before[key] != storage.values[key]) key,
        };
        if (before.containsKey(regionDefaultsMarkerKey) && changed.isNotEmpty) {
          return ModelFailure(i, 'R2', 'wrote $changed after the marker');
        }
        if (changed.any(_regionKeys.contains)) {
          regionWriteLaunches++;
          if (regionWriteLaunches > 1) {
            return ModelFailure(i, 'R2', 'region defaults written twice');
          }
          if (userSettingsBeforeApply) {
            return ModelFailure(
              i,
              'R3',
              'existing install got region values: $changed',
            );
          }
        }
    }
    // R1: whatever the user stored is still there.
    for (final MapEntry(:key, :value) in userValues.entries) {
      if (storage.values[key] != value) {
        return ModelFailure(
          i,
          'R1',
          '$key is "${storage.values[key]}", the user stored "$value"',
        );
      }
    }
  }
  return null;
}

String regionCaseToDart(String name, List<RegionEvent> seq) =>
    "test('$name', () async {\n"
    '  expect(await runRegionSequence(const [\n'
    '${seq.map((e) => '    $e,').join('\n')}\n'
    '  ]), isNull);\n'
    '});';

Iterable<int> _seeds() {
  final n = int.tryParse(Platform.environment['SHINSOKU_MODEL_SEEDS'] ?? '');
  return n == null
      ? const [1, 7, 42, 99, 123, 2026, 31337]
      : [for (var i = 0; i < n; i++) i];
}

/// A broken store that ignores the marker and the existing-install check.
class _AlwaysApply extends RegionDefaultsStore {
  const _AlwaysApply({required super.storage});

  @override
  Future<RegionSetupOutcome?> applyOnce({
    required List<Locale> locales,
    AppLocalizations? l10n,
  }) async {
    await storage.write(ProviderSettingsStore.keyFor('speechProvider'), 'x');
    return RegionSetupOutcome.applied;
  }
}

void main() {
  test('R1–R3 hold for seeded random event sequences', () async {
    await check<RegionEvent>(
      gen: genEvent,
      run: runRegionSequence,
      toDart: regionCaseToDart,
      seeds: _seeds(),
      length: 40,
    );
  });

  test('the harness catches a store that applies every launch', () async {
    Object? caught;
    try {
      await check<RegionEvent>(
        gen: genEvent,
        run: (seq) =>
            runRegionSequence(seq, makeStore: (s) => _AlwaysApply(storage: s)),
        toDart: regionCaseToDart,
        seeds: const [1, 7, 42],
        length: 40,
      );
    } on ModelCheckError catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    expect(caught.toString(), matches(RegExp(r'R[123] broke')));
  });

  // Named regressions.
  test(
    'R3: upgrade with a saved key keeps Bailian (provider stays absent)',
    () async {
      expect(
        await runRegionSequence(const [
          UserWrite('provider_settings.bailianApiKey', 'example-key'),
          Launch('en'),
          Launch('ja'),
        ]),
        isNull,
      );
    },
  );

  test('R1: crash after the first write, user change, relaunch', () async {
    expect(
      await runRegionSequence(const [
        Launch('ja', failAfter: 1),
        UserWrite('provider_settings.speechProvider', 'bailian'),
        Launch('ja'),
      ]),
      isNull,
    );
  });
}
