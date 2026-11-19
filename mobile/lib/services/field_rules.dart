import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The kinds of text field the keyboard can tell apart (profile-01 P3). Wire
/// names are shared with the keyboard through `fieldRules.v1`.
enum FieldKind {
  search('search', 'Search'),
  url('url', 'Web address'),
  email('email', 'Email'),
  message('message', 'Message');

  const FieldKind(this.wireName, this.label);

  final String wireName;
  final String label;
}

/// Field kind → profile id. A kind without an entry has no rule ("None").
@immutable
class FieldRules {
  const FieldRules([this.byKind = const {}]);

  final Map<FieldKind, String> byKind;

  String? operator [](FieldKind kind) => byKind[kind];

  FieldRules set(FieldKind kind, String? profileId) {
    final next = Map<FieldKind, String>.of(byKind);
    if (profileId == null || profileId.trim().isEmpty) {
      next.remove(kind);
    } else {
      next[kind] = profileId;
    }
    return FieldRules(next);
  }

  /// Drops rules that point at a profile that no longer exists.
  FieldRules pruned(Iterable<String> existingProfileIds) {
    final ids = existingProfileIds.toSet();
    return FieldRules({
      for (final entry in byKind.entries)
        if (ids.contains(entry.value)) entry.key: entry.value,
    });
  }

  /// `{kind: profileId}`, only known kinds and non-empty ids.
  Map<String, String> toJson() => {
    for (final entry in byKind.entries) entry.key.wireName: entry.value,
  };

  String encode() => jsonEncode(toJson());

  static FieldRules fromJson(Object? json) {
    if (json is! Map) return const FieldRules();
    final rules = <FieldKind, String>{};
    for (final kind in FieldKind.values) {
      final id = json[kind.wireName];
      if (id is String && id.trim().isNotEmpty) rules[kind] = id;
    }
    return FieldRules(rules);
  }

  static FieldRules decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const FieldRules();
    try {
      return fromJson(jsonDecode(raw));
    } on FormatException {
      return const FieldRules();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FieldRules && mapEquals(other.byKind, byKind);

  @override
  int get hashCode => Object.hashAllUnordered(
    byKind.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// Where the rules are kept on the Dart side.
abstract interface class FieldRulesStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureFieldRulesStorage implements FieldRulesStorage {
  const SecureFieldRulesStorage();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'field_rules.v1';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}

/// Native side: the App Group key `fieldRules.v1`.
abstract interface class FieldRulesBridge {
  Future<void> setFieldRules(Map<String, String> rules);
}

class MethodChannelFieldRulesBridge implements FieldRulesBridge {
  const MethodChannelFieldRulesBridge();

  static const MethodChannel channel = MethodChannel(
    'net.potafree.shinsoku/profiles',
  );

  @override
  Future<void> setFieldRules(Map<String, String> rules) =>
      channel.invokeMethod<void>('setFieldRules', {'rules': jsonEncode(rules)});
}

/// Persists the rules in Dart (the owner) and mirrors them to the App Group
/// for the keyboard. The mirror is best-effort, like the active selection.
class FieldRulesStore {
  FieldRulesStore({
    FieldRulesStorage storage = const SecureFieldRulesStorage(),
    FieldRulesBridge bridge = const MethodChannelFieldRulesBridge(),
  }) : _storage = storage,
       _bridge = bridge;

  final FieldRulesStorage _storage;
  final FieldRulesBridge _bridge;

  Future<FieldRules> load() async {
    try {
      return FieldRules.decode(await _storage.read());
    } on PlatformException {
      return const FieldRules();
    } on MissingPluginException {
      return const FieldRules();
    }
  }

  Future<void> save(FieldRules rules) async {
    try {
      await _storage.write(rules.encode());
    } on MissingPluginException {
      // No native storage (tests, other platforms).
    }
    await mirror(rules);
  }

  Future<void> mirror(FieldRules rules) async {
    try {
      await _bridge.setFieldRules(rules.toJson());
    } on MissingPluginException {
      // Best-effort.
    } on PlatformException catch (error) {
      debugPrint('field rules: ${error.code}');
    }
  }

  /// Deleting a profile removes the rules that point to it. Returns the rules
  /// now in effect.
  Future<FieldRules> pruneTo(Iterable<String> profileIds) async {
    final current = await load();
    final pruned = current.pruned(profileIds);
    if (pruned != current) await save(pruned);
    return pruned;
  }
}
