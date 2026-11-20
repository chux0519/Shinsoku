import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';

import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/region_defaults.dart';

class VoiceProfile {
  const VoiceProfile({
    required this.id,
    required this.name,
    required this.intent,
    required this.commitSuffix,
    required this.autoCommit,
  });

  final String id;
  final String name;
  final String intent;
  final CommitSuffix commitSuffix;
  final bool autoCommit;

  VoiceProfile copyWith({
    String? id,
    String? name,
    String? intent,
    CommitSuffix? commitSuffix,
    bool? autoCommit,
  }) {
    return VoiceProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      intent: intent ?? this.intent,
      commitSuffix: commitSuffix ?? this.commitSuffix,
      autoCommit: autoCommit ?? this.autoCommit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'intent': intent,
      'commitSuffix': commitSuffix.name,
      'autoCommit': autoCommit,
    };
  }

  static VoiceProfile fromJson(Map<String, dynamic> json) {
    final suffixName = json['commitSuffix'];
    return VoiceProfile(
      id: json['id'] is String && (json['id'] as String).trim().isNotEmpty
          ? json['id'] as String
          : DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] is String && (json['name'] as String).trim().isNotEmpty
          ? json['name'] as String
          : 'Untitled', // corrupt data only; the editor never saves blank names
      intent: json['intent'] is String
          ? json['intent'] as String
          : defaultVoiceProfiles.first.intent,
      commitSuffix: CommitSuffix.values.firstWhere(
        (suffix) => suffix.name == suffixName,
        orElse: () => CommitSuffix.space,
      ),
      autoCommit: json['autoCommit'] is bool
          ? json['autoCommit'] as bool
          : true,
    );
  }
}

/// The built-in profiles in English: the seed for tests and the list shown
/// before the stored profiles load. New installs get
/// [localizedDefaultProfiles] instead, written to storage once, so their names
/// are user data from then on (i18n-01).
const defaultVoiceProfiles = [
  VoiceProfile(
    id: 'dictation',
    name: 'Dictation',
    intent: 'Clean speech into natural prose',
    commitSuffix: CommitSuffix.space,
    autoCommit: true,
  ),
  VoiceProfile(
    id: 'chat',
    name: 'Chat',
    intent: 'Make the text concise and conversational',
    commitSuffix: CommitSuffix.newline,
    autoCommit: true,
  ),
  VoiceProfile(
    id: 'review',
    name: 'Review',
    intent: 'Hold transcript for manual review',
    commitSuffix: CommitSuffix.none,
    autoCommit: false,
  ),
  VoiceProfile(
    id: 'zh_to_en',
    name: 'ZH -> EN',
    intent:
        'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.',
    commitSuffix: CommitSuffix.space,
    autoCommit: true,
  ),
];

/// The built-in profiles with names and prompts in [l]'s language, for
/// creating the first stored list. The fourth one translates the device
/// language into English ([translationSource], from `regionDefaultsFor`):
/// `zh` keeps the historic `zh_to_en` profile; `ja`, `ko`, `de`, … get their
/// own ("JA -> EN"); null (English devices, other languages) gets
/// "Translate -> EN", any language in.
List<VoiceProfile> localizedDefaultProfiles(
  AppLocalizations l, {
  String? translationSource = 'zh',
}) => [
  VoiceProfile(
    id: 'dictation',
    name: l.profileDictationName,
    intent: l.profileDictationIntent,
    commitSuffix: CommitSuffix.space,
    autoCommit: true,
  ),
  VoiceProfile(
    id: 'chat',
    name: l.profileChatName,
    intent: l.profileChatIntent,
    commitSuffix: CommitSuffix.newline,
    autoCommit: true,
  ),
  VoiceProfile(
    id: 'review',
    name: l.profileReviewName,
    intent: l.profileReviewIntent,
    commitSuffix: CommitSuffix.none,
    autoCommit: false,
  ),
  translationProfile(l, translationSource),
];

/// The built-in "`<language>` -> EN" profile for [source] (see
/// [localizedDefaultProfiles]).
VoiceProfile translationProfile(AppLocalizations l, String? source) {
  final (String name, String intent) = switch (source) {
    'zh' => (l.profileZhToEnName, l.profileZhToEnIntent),
    'ja' => (l.profileJaToEnName, l.profileJaToEnIntent),
    'ko' => (l.profileKoToEnName, l.profileKoToEnIntent),
    'de' => (l.profileDeToEnName, l.profileDeToEnIntent),
    'es' => (l.profileEsToEnName, l.profileEsToEnIntent),
    'fr' => (l.profileFrToEnName, l.profileFrToEnIntent),
    'pt' => (l.profilePtToEnName, l.profilePtToEnIntent),
    'it' => (l.profileItToEnName, l.profileItToEnIntent),
    _ => (l.profileTranslateToEnName, l.profileTranslateToEnIntent),
  };
  return VoiceProfile(
    id: source == 'zh' ? zhToEnProfileId : translateToEnProfileId,
    name: name,
    intent: intent,
    commitSuffix: CommitSuffix.space,
    autoCommit: true,
  );
}

/// The one-line description of [profile] in profile lists. The built-in
/// translation profiles' instructions are English on purpose (they go to the
/// AI model), so while one is unchanged the list shows a short description in
/// [l]'s language instead; an edited instruction shows as written.
String profileListDescription(AppLocalizations l, VoiceProfile profile) {
  if (profile.id == zhToEnProfileId || profile.id == translateToEnProfileId) {
    final intent = profile.intent.trim();
    final builtIn = {
      for (final source in [...translationSourceLanguages, null])
        translationProfile(l, source).intent.trim(),
    };
    if (builtIn.contains(intent)) return l.profileTranslationDescription;
  }
  return profile.intent;
}

class VoiceProfileStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'voice_profiles.v1';

  /// Storage key of the profile list (first-launch region defaults check it).
  static const storageKey = _key;

  /// Stored profiles; when none are stored, the built-in ones in the system
  /// language ([l10n], or the resolved system locale) with the translation
  /// profile for the device language, saved right away. Normally
  /// `RegionDefaultsStore` has already written them on first launch.
  Future<List<VoiceProfile>> load({AppLocalizations? l10n}) async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) {
      final created = localizedDefaultProfiles(
        l10n ?? await systemAppLocalizations(),
        translationSource: regionDefaultsFor(
          ui.PlatformDispatcher.instance.locales,
        ).translationSource,
      );
      try {
        await save(created);
      } catch (_) {
        // Storage unavailable: the defaults still work this session.
      }
      return created;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return List<VoiceProfile>.of(defaultVoiceProfiles);
      }
      final profiles = decoded
          .whereType<Map>()
          .map((item) => VoiceProfile.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      return profiles.isEmpty
          ? List<VoiceProfile>.of(defaultVoiceProfiles)
          : profiles;
    } catch (_) {
      return List<VoiceProfile>.of(defaultVoiceProfiles);
    }
  }

  Future<void> save(List<VoiceProfile> profiles) {
    final payload = jsonEncode(
      profiles.map((profile) => profile.toJson()).toList(),
    );
    return _storage.write(key: _key, value: payload);
  }
}
