import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:shinsoku_mobile/services/voice_profiles.dart';

/// Who set the active profile (profile-01, invariants PR1–PR4 in
/// docs/design/state_invariants.md). Wire names are stable: they are shared
/// with the keyboard extension and the App Intents through the App Group.
enum ProfileSource {
  manual('manual'),
  automation('automation'),
  fieldRule('fieldRule'),
  byDefault('default');

  const ProfileSource(this.wireName);

  final String wireName;

  /// Manual picks and automation sets are explicit events; they are ordered
  /// by time against each other (newest wins, PR2).
  bool get isExplicit =>
      this == ProfileSource.manual || this == ProfileSource.automation;

  static ProfileSource? fromWire(Object? value) {
    for (final source in values) {
      if (source.wireName == value) return source;
    }
    return null;
  }
}

/// The active selection as stored in the App Group (`activeProfile.v1`).
@immutable
class ProfileSelection {
  const ProfileSelection({
    required this.profileId,
    required this.source,
    required this.at,
  });

  final String profileId;
  final ProfileSource source;
  final DateTime at;

  Map<String, Object> toJson() => {
    'profileId': profileId,
    'source': source.wireName,
    'at': at.toUtc().toIso8601String(),
  };

  /// Null when [json] is not a valid selection (unknown source, empty id,
  /// unparseable time): callers treat that like no selection.
  static ProfileSelection? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['profileId'];
    final source = ProfileSource.fromWire(json['source']);
    final at = json['at'] is String
        ? DateTime.tryParse(json['at'] as String)
        : null;
    if (id is! String || id.trim().isEmpty || source == null || at == null) {
      return null;
    }
    return ProfileSelection(profileId: id, source: source, at: at.toUtc());
  }

  static ProfileSelection? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is ProfileSelection &&
      other.profileId == profileId &&
      other.source == source &&
      other.at.isAtSameMomentAs(at);

  @override
  int get hashCode => Object.hash(profileId, source, at.microsecondsSinceEpoch);

  @override
  String toString() =>
      'ProfileSelection($profileId, ${source.wireName}, ${toJson()['at']})';
}

/// The keyboard matched the focused field to a profile (P3 sets this).
@immutable
class FieldRuleMatch {
  const FieldRuleMatch(this.profileId);

  final String profileId;
}

/// What recording uses, and why.
@immutable
class ResolvedProfile {
  const ResolvedProfile(this.profile, this.source);

  final VoiceProfile profile;
  final ProfileSource source;

  @override
  String toString() => 'ResolvedProfile(${profile.id}, ${source.wireName})';
}

/// The default profile: the first one in the user's list.
VoiceProfile defaultProfileOf(List<VoiceProfile> profiles) =>
    profiles.isNotEmpty ? profiles.first : defaultVoiceProfiles.first;

/// Pure precedence resolver (plan profile-01; PR2, PR3). Kept free of I/O so
/// the P5 model test can drive it.
///
/// 1. A field rule applies only when the stored selection is not an explicit
///    event made at or after [keyboardAppearedAt]. Without
///    [keyboardAppearedAt] (no keyboard session, e.g. recording in the app)
///    a field rule never overrides an explicit selection.
/// 2. Otherwise the stored selection, if its profile still exists.
/// 3. Otherwise the default profile (missing id → default, PR3).
ResolvedProfile resolveActive(
  ProfileSelection? selection,
  List<VoiceProfile> profiles, {
  FieldRuleMatch? fieldRuleMatch,
  DateTime? keyboardAppearedAt,
}) {
  VoiceProfile? find(String id) {
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  final fieldProfile = fieldRuleMatch == null
      ? null
      : find(fieldRuleMatch.profileId);
  if (fieldProfile != null) {
    final explicit = selection != null && selection.source.isExplicit;
    final explicitIsNewer =
        explicit &&
        (keyboardAppearedAt == null ||
            !selection.at.isBefore(keyboardAppearedAt));
    if (!explicitIsNewer) {
      return ResolvedProfile(fieldProfile, ProfileSource.fieldRule);
    }
  }

  final selected = selection == null ? null : find(selection.profileId);
  if (selected != null) {
    return ResolvedProfile(selected, selection!.source);
  }
  return ResolvedProfile(defaultProfileOf(profiles), ProfileSource.byDefault);
}

/// Native side of the App Group mirror. Keys: `profiles.v1` (JSON array of
/// `{id, name}`), `activeProfile.v1` (JSON object, [ProfileSelection]).
abstract interface class ProfileGroupBridge {
  /// Only ids and names: never prompt text or API keys.
  Future<void> publishProfiles(List<Map<String, String>> profiles);

  Future<void> setActive(ProfileSelection selection);

  /// The raw stored selection, or null.
  Future<String?> readActive();
}

class MethodChannelProfileGroupBridge implements ProfileGroupBridge {
  const MethodChannelProfileGroupBridge();

  static const MethodChannel channel = MethodChannel(
    'net.potafree.shinsoku/profiles',
  );

  @override
  Future<void> publishProfiles(List<Map<String, String>> profiles) =>
      channel.invokeMethod<void>('publishProfiles', {
        'profiles': jsonEncode(profiles),
      });

  @override
  Future<void> setActive(ProfileSelection selection) => channel
      .invokeMethod<void>('setActive', {'selection': selection.encode()});

  @override
  Future<String?> readActive() => channel.invokeMethod<String>('readActive');
}

/// Mirrors the profile list (ids and names only) and the active selection to
/// the App Group. Dart owns the list (secure storage, with prompt text); the
/// keyboard and App Intents may write the selection, so it is re-read before
/// recording and on resume. Every call is best-effort: without the native
/// channel (tests, other platforms) the last known selection is kept in
/// memory.
class ActiveProfileStore {
  ActiveProfileStore({
    ProfileGroupBridge bridge = const MethodChannelProfileGroupBridge(),
    DateTime Function()? clock,
  }) : _bridge = bridge,
       _clock = clock ?? DateTime.now;

  final ProfileGroupBridge _bridge;
  final DateTime Function() _clock;
  ProfileSelection? _selection;

  ProfileSelection? get selection => _selection;

  static List<Map<String, String>> publicList(List<VoiceProfile> profiles) => [
    for (final profile in profiles) {'id': profile.id, 'name': profile.name},
  ];

  /// Migration and launch sync (idempotent): publishes the list; writes a
  /// default selection only when the group has none; repairs a selection
  /// that points at a deleted profile (PR3).
  Future<ProfileSelection> sync(List<VoiceProfile> profiles) async {
    await _guard(() => _bridge.publishProfiles(publicList(profiles)));
    await refresh();
    final current = _selection;
    final exists =
        current != null && profiles.any((p) => p.id == current.profileId);
    if (!exists) {
      await _write(
        ProfileSelection(
          profileId: defaultProfileOf(profiles).id,
          source: ProfileSource.byDefault,
          at: _clock().toUtc(),
        ),
      );
    }
    return _selection!;
  }

  /// Reads the group's selection (the keyboard or an App Intent may have
  /// written it). Keeps the last known selection when the read fails.
  Future<ProfileSelection?> refresh() async {
    final raw = await _guard(_bridge.readActive);
    final stored = ProfileSelection.decode(raw);
    if (stored != null) _selection = stored;
    return _selection;
  }

  /// A pick in the app's Record selector.
  Future<ProfileSelection> selectManually(String profileId) {
    return _write(
      ProfileSelection(
        profileId: profileId,
        source: ProfileSource.manual,
        at: _clock().toUtc(),
      ),
    );
  }

  Future<ProfileSelection> _write(ProfileSelection selection) async {
    _selection = selection;
    await _guard(() => _bridge.setActive(selection));
    return selection;
  }

  static Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('profile group: ${error.code}');
      return null;
    }
  }
}
