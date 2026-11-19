import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/services/active_profile.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

final _t0 = DateTime.utc(2026, 11, 19, 10);
DateTime _at(int seconds) => _t0.add(Duration(seconds: seconds));

ProfileSelection _sel(String id, ProfileSource source, int seconds) =>
    ProfileSelection(profileId: id, source: source, at: _at(seconds));

class _FakeBridge implements ProfileGroupBridge {
  String? active;
  String? profiles;
  int setActiveCalls = 0;
  bool missing = false;

  @override
  Future<void> publishProfiles(List<Map<String, String>> list) async {
    if (missing) throw MissingPluginException();
    profiles = jsonEncode(list);
  }

  @override
  Future<String?> readActive() async {
    if (missing) throw MissingPluginException();
    return active;
  }

  @override
  Future<void> setActive(ProfileSelection selection) async {
    if (missing) throw MissingPluginException();
    setActiveCalls++;
    active = selection.encode();
  }
}

void main() {
  const profiles = defaultVoiceProfiles;

  group('resolveActive', () {
    test('no selection → default profile', () {
      final r = resolveActive(null, profiles);
      expect(r.profile.id, 'dictation');
      expect(r.source, ProfileSource.byDefault);
    });

    test('manual and automation selections apply', () {
      for (final source in [ProfileSource.manual, ProfileSource.automation]) {
        final r = resolveActive(_sel('chat', source, 0), profiles);
        expect(r.profile.id, 'chat');
        expect(r.source, source);
      }
    });

    test('PR3: missing id falls back to the default profile', () {
      final r = resolveActive(
        _sel('deleted', ProfileSource.automation, 0),
        profiles,
      );
      expect(r.profile.id, 'dictation');
      expect(r.source, ProfileSource.byDefault);
    });

    test('PR3: default is the first profile of the current list', () {
      final reordered = [profiles[2], profiles[0]];
      final r = resolveActive(_sel('gone', ProfileSource.manual, 0), reordered);
      expect(r.profile.id, 'review');
    });

    test('PR2: a field rule never overrides a manual or automation '
        'selection, whatever its time', () {
      for (final source in [ProfileSource.manual, ProfileSource.automation]) {
        // Old and new timestamps alike: strict precedence, no clocks.
        for (final seconds in [0, 5]) {
          final r = resolveActive(
            _sel('chat', source, seconds),
            profiles,
            fieldRuleMatch: const FieldRuleMatch('review'),
          );
          expect(r.profile.id, 'chat', reason: '${source.wireName} $seconds');
          expect(r.source, source);
        }
      }
    });

    test('field rule applies over a default selection', () {
      final r = resolveActive(
        _sel('dictation', ProfileSource.byDefault, 9),
        profiles,
        fieldRuleMatch: const FieldRuleMatch('zh_to_en'),
      );
      expect(r.profile.id, 'zh_to_en');
      expect(r.source, ProfileSource.fieldRule);
    });

    test('field rule applies without a stored selection', () {
      final r = resolveActive(
        null,
        profiles,
        fieldRuleMatch: const FieldRuleMatch('review'),
      );
      expect(r.profile.id, 'review');
      expect(r.source, ProfileSource.fieldRule);
    });

    test('field rule applies when the explicit selection points at a '
        'deleted profile (PR3: no explicit selection is in effect)', () {
      final r = resolveActive(
        _sel('gone', ProfileSource.manual, 9),
        profiles,
        fieldRuleMatch: const FieldRuleMatch('review'),
      );
      expect(r.profile.id, 'review');
      expect(r.source, ProfileSource.fieldRule);
    });

    test('field rule pointing at a missing profile is ignored', () {
      final r = resolveActive(
        _sel('dictation', ProfileSource.byDefault, 0),
        profiles,
        fieldRuleMatch: const FieldRuleMatch('gone'),
      );
      expect(r.profile.id, 'dictation');
      expect(r.source, ProfileSource.byDefault);
    });

    test('empty list still resolves to a profile', () {
      expect(resolveActive(null, const []).profile.id, 'dictation');
    });
  });

  group('ProfileSelection', () {
    test('round-trips through JSON with the wire names', () {
      final s = _sel('chat', ProfileSource.byDefault, 3);
      final json = jsonDecode(s.encode()) as Map<String, dynamic>;
      expect(json, {
        'profileId': 'chat',
        'source': 'default',
        'at': '2026-11-19T10:00:03.000Z',
      });
      expect(ProfileSelection.decode(s.encode()), s);
    });

    test('invalid payloads decode to null', () {
      for (final raw in [
        null,
        '',
        'not json',
        '[]',
        '{"profileId":"chat","source":"bogus","at":"2026-11-19T10:00:00Z"}',
        '{"profileId":"","source":"manual","at":"2026-11-19T10:00:00Z"}',
        '{"profileId":"chat","source":"manual","at":"yesterday"}',
      ]) {
        expect(ProfileSelection.decode(raw), isNull, reason: raw);
      }
    });
  });

  group('ActiveProfileStore', () {
    late _FakeBridge bridge;
    late ActiveProfileStore store;
    var now = _at(100);

    setUp(() {
      bridge = _FakeBridge();
      now = _at(100);
      store = ActiveProfileStore(bridge: bridge, clock: () => now);
    });

    test('publishes ids and names only (no prompt text)', () async {
      await store.sync(profiles);
      final list = jsonDecode(bridge.profiles!) as List;
      expect(list.first, {'id': 'dictation', 'name': 'Dictation'});
      expect(bridge.profiles, isNot(contains('Translate')));
      expect(bridge.profiles, isNot(contains('intent')));
    });

    test('migration writes a default selection once (idempotent)', () async {
      final first = await store.sync(profiles);
      expect(first, _sel('dictation', ProfileSource.byDefault, 100));
      now = _at(200);
      final second = await store.sync(profiles);
      expect(second, first);
      expect(bridge.setActiveCalls, 1);
    });

    test('migration keeps a selection written by the keyboard', () async {
      bridge.active = _sel('chat', ProfileSource.automation, 50).encode();
      final s = await store.sync(profiles);
      expect(s.profileId, 'chat');
      expect(bridge.setActiveCalls, 0);
    });

    test(
      'PR3: sync repairs a selection pointing at a deleted profile',
      () async {
        bridge.active = _sel('gone', ProfileSource.manual, 50).encode();
        final s = await store.sync(profiles);
        expect(s, _sel('dictation', ProfileSource.byDefault, 100));
        expect(ProfileSelection.decode(bridge.active), s);
      },
    );

    test('a manual pick is written with source manual and the clock', () async {
      await store.selectManually('review');
      expect(
        ProfileSelection.decode(bridge.active),
        _sel('review', ProfileSource.manual, 100),
      );
    });

    test('refresh picks up a newer automation set', () async {
      await store.selectManually('review');
      bridge.active = _sel('chat', ProfileSource.automation, 150).encode();
      final s = await store.refresh();
      expect(s?.profileId, 'chat');
      expect(s?.source, ProfileSource.automation);
    });

    test('without the native channel the selection stays in memory', () async {
      bridge.missing = true;
      final s = await store.sync(profiles);
      expect(s.profileId, 'dictation');
      await store.selectManually('chat');
      expect((await store.refresh())?.profileId, 'chat');
    });
  });
}
