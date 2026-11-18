import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:shinsoku_mobile/services/capture_types.dart';

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
          : 'Untitled',
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

class VoiceProfileStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'voice_profiles.v1';

  Future<List<VoiceProfile>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) {
      return List<VoiceProfile>.of(defaultVoiceProfiles);
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
