// i18n-01 I3: applies [regionDefaultsFor] once, on first launch (invariants
// R1–R3, docs/design/state_invariants.md).
//
// `ProviderSettingsStore.load` reads absent keys as build-time defaults, so a
// changed default would silently switch existing users. Instead the region
// choice is written once, as stored values, on a fresh install; an install
// that already has any provider setting or profiles keeps what it has and only
// gets the marker.
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/region_defaults.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

/// Written last; once present, region defaults never run again (R2).
const regionDefaultsMarkerKey = 'region_defaults.v1';

/// The key-value storage the settings live in (secure storage in the app, a
/// map in tests).
abstract class SettingsStorage {
  Future<Map<String, String>> readAll();
  Future<void> write(String key, String value);
}

class SecureSettingsStorage implements SettingsStorage {
  const SecureSettingsStorage();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

enum RegionSetupOutcome {
  /// The marker was there: nothing written.
  alreadyDone,

  /// An existing install (stored provider settings or profiles): only the
  /// marker was written; its values stay as they are (R3).
  keptExisting,

  /// A fresh install: provider, language hints and profiles were written.
  applied,
}

/// The writes for one first-launch check, in order (marker last), from the
/// keys already in storage. Pure, so the model test drives it directly.
List<MapEntry<String, String>> planRegionSetup({
  required Set<String> storedKeys,
  required RegionDefaults defaults,
  required List<VoiceProfile> Function() profiles,
}) {
  if (storedKeys.contains(regionDefaultsMarkerKey)) {
    return const [];
  }
  final existing = storedKeys.any(
    (key) =>
        ProviderSettingsStore.isProviderKey(key) ||
        key == VoiceProfileStore.storageKey,
  );
  if (existing) {
    return const [MapEntry(regionDefaultsMarkerKey, 'kept')];
  }
  return [
    MapEntry(
      ProviderSettingsStore.keyFor('speechProvider'),
      defaults.speechProvider,
    ),
    MapEntry(
      ProviderSettingsStore.keyFor('sonioxLanguageHints'),
      ProviderSettingsStore.encodeHints(defaults.sonioxLanguageHints),
    ),
    MapEntry(
      ProviderSettingsStore.keyFor('bailianLanguageHint'),
      defaults.bailianLanguageHint,
    ),
    MapEntry(
      VoiceProfileStore.storageKey,
      jsonEncode([for (final profile in profiles()) profile.toJson()]),
    ),
    const MapEntry(regionDefaultsMarkerKey, 'applied'),
  ];
}

class RegionDefaultsStore {
  const RegionDefaultsStore({this.storage = const SecureSettingsStorage()});

  final SettingsStorage storage;

  /// Runs before the provider settings and profiles load. Never throws: if
  /// storage can't be read nothing is written and the next launch retries;
  /// if a write fails midway, the values already written count as stored
  /// settings next time (R3), so nothing is overwritten.
  Future<RegionSetupOutcome?> applyOnce({
    required List<Locale> locales,
    AppLocalizations? l10n,
  }) async {
    try {
      final stored = await storage.readAll();
      final defaults = regionDefaultsFor(locales);
      final strings = l10n ?? await systemAppLocalizations();
      final plan = planRegionSetup(
        storedKeys: stored.keys.toSet(),
        defaults: defaults,
        profiles: () => localizedDefaultProfiles(
          strings,
          translationSource: defaults.translationSource,
        ),
      );
      for (final write in plan) {
        await storage.write(write.key, write.value);
      }
      if (plan.isEmpty) return RegionSetupOutcome.alreadyDone;
      return plan.length == 1
          ? RegionSetupOutcome.keptExisting
          : RegionSetupOutcome.applied;
    } catch (_) {
      return null;
    }
  }
}
