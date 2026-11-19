// profile-01 P5: seeded model test for the active profile (PR1–PR4,
// docs/design/state_invariants.md). Fixed seeds by default (fast); a longer
// run with SHINSOKU_MODEL_SEEDS=<n> (e.g. 2000) in the environment.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/services/active_profile.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

import 'harness.dart';
import 'profile_world.dart';

Iterable<int> _seeds() {
  final n = int.tryParse(Platform.environment['SHINSOKU_MODEL_SEEDS'] ?? '');
  return n == null
      ? const [1, 7, 42, 99, 123, 2026, 31337]
      : [for (var i = 0; i < n; i++) i];
}

void main() {
  test('PR1–PR4 hold for seeded random event sequences', () async {
    await check<ProfileEvent>(
      gen: genEvent,
      run: runProfileSequence,
      toDart: profileCaseToDart,
      seeds: _seeds(),
    );
  });

  group('the harness catches a broken system', () {
    Future<String> failureOf(ProfileSystem Function() make) async {
      try {
        await check<ProfileEvent>(
          gen: genEvent,
          run: (seq) => runProfileSequence(seq, makeSystem: make),
          toDart: profileCaseToDart,
          seeds: const [1, 7, 42],
        );
      } on ModelCheckError catch (e) {
        return e.message;
      }
      return '';
    }

    test('recording that re-resolves at stop (PR1)', () async {
      final message = await failureOf(_ResolvesAtStop.new);
      expect(message, contains('PR1'));
      expect(message, contains("regression('seed"));
    });

    test('a keyboard that ignores field rules (PR2)', () async {
      final message = await failureOf(_NoFieldRules.new);
      expect(message, contains('PR2'));
    });

    test('a keyboard on the old rule: a field rule beats an automation made '
        'before the keyboard appeared (PR2)', () async {
      final message = await failureOf(
        () => ProfileSystem(makeKeyboard: _OldTimingKeyboard.new),
      );
      expect(message, contains('PR2'));
    });

    test('a delete that does not repair the selection (PR3)', () async {
      final message = await failureOf(_NoRepair.new);
      expect(message, contains('PR3'));
    });

    test('a keyboard that forgets its last profile (PR4)', () async {
      final message = await failureOf(_ForgetsLastShown.new);
      expect(message, contains('PR4'));
    });
  });
}

/// Records with whatever is active at each event, not what was captured.
class _ResolvesAtStop extends ProfileSystem {
  @override
  Future<void> apply(ProfileEvent ev) async {
    await super.apply(ev);
    if (recording != null) recording = await appRecordStart();
  }
}

class _NoFieldRules extends ProfileSystem {
  @override
  Future<void> apply(ProfileEvent ev) async {
    await super.apply(
      ev is KeyboardAppear ? KeyboardAppear(FieldKind.message, at: ev.at) : ev,
    );
  }
}

/// The rule before 2026-11-19: a field rule yields only to an explicit event
/// made after the keyboard appeared.
class _OldTimingKeyboard extends KeyboardStandIn {
  _OldTimingKeyboard(super.group, super.clock);

  ProfileSelection? _atAppear;

  @override
  void appear(FieldKind k) {
    super.appear(k);
    _atAppear = this.group.active;
  }

  @override
  VoiceProfile? get shows {
    final rule = fieldRules[kind];
    final ruleProfile = this.group.listed
        .where((p) => p.id == rule)
        .firstOrNull;
    if (up &&
        fullAccess &&
        ruleProfile != null &&
        this.group.active == _atAppear) {
      return lastShown = ruleProfile;
    }
    return super.shows;
  }
}

class _NoRepair extends ProfileSystem {
  @override
  Future<void> apply(ProfileEvent ev) async {
    if (ev is ProfileDelete) {
      final before = this.group.activeRaw;
      await super.apply(ev);
      this.group.activeRaw = before;
      return;
    }
    await super.apply(ev);
  }
}

class _ForgetsLastShown extends ProfileSystem {
  @override
  Future<void> apply(ProfileEvent ev) async {
    await super.apply(ev);
    if (ev is FullAccess && !ev.on) keyboard.lastShown = null;
  }
}
