// pricing-01 S2: seeded model test for Shinsoku Pro (E1–E4,
// docs/design/state_invariants.md). The system under test is the real
// ChannelProEntitlement (Dart) talking over the store channels to a port of
// the native ProStore (`mobile/ios/Runner/ProStore.swift`: `ownedAfter`,
// reconcile, purchase, restore, transaction updates) that writes the App
// Group mirror `pro.v1`. The reference model is a scripted StoreKit world:
// purchases (immediate, Ask to Buy → approved later, cancelled), refunds,
// going offline (every StoreKit call fails or knows nothing), Restore
// Purchases and app relaunches.
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/services/pro_entitlement.dart';

import 'harness.dart';

sealed class ProEvent {
  const ProEvent();
}

enum BuyOutcome { success, pending, cancelled }

/// The user taps Buy; StoreKit answers [outcome] (online only).
class Buy extends ProEvent {
  const Buy(this.outcome);
  final BuyOutcome outcome;

  @override
  String toString() => 'Buy(BuyOutcome.${outcome.name})';
}

/// A pending purchase (Ask to Buy, SCA) is approved: a transaction update.
class Approve extends ProEvent {
  const Approve();

  @override
  String toString() => 'Approve()';
}

/// Apple refunds the purchase (or Family Sharing is removed): the transaction
/// is revoked; the update arrives now, or when the device is back online.
class Refund extends ProEvent {
  const Refund();

  @override
  String toString() => 'Refund()';
}

class GoOffline extends ProEvent {
  const GoOffline();

  @override
  String toString() => 'GoOffline()';
}

class GoOnline extends ProEvent {
  const GoOnline();

  @override
  String toString() => 'GoOnline()';
}

class Restore extends ProEvent {
  const Restore();

  @override
  String toString() => 'Restore()';
}

/// The app is killed and launched again (native reconcile + a new Dart
/// entitlement asking `state`).
class Relaunch extends ProEvent {
  const Relaunch();

  @override
  String toString() => 'Relaunch()';
}

ProEvent genEvent(Random rng, List<ProEvent> sofar) => switch (rng.nextInt(9)) {
  0 => const Buy(BuyOutcome.success),
  1 => const Buy(BuyOutcome.pending),
  2 => const Buy(BuyOutcome.cancelled),
  3 => const Approve(),
  4 => const Refund(),
  5 => rng.nextBool() ? const GoOffline() : const GoOnline(),
  6 => const Restore(),
  _ => const Relaunch(),
};

/// What StoreKit knows (the reference model).
class StoreKitWorld {
  bool offline = false;
  bool awaitingApproval = false;

  /// null: never bought; false: a live verified transaction; true: revoked.
  bool? revoked;

  /// A revocation StoreKit has not delivered yet (it happened offline).
  bool updatePending = false;

  bool get entitled => revoked == false;
}

/// `ProStore.Evidence`.
enum Evidence { owned, revoked, unknown }

/// Port of `ProStore.ownedAfter` (keep the two in step).
bool ownedAfter(Evidence evidence, bool? mirror) => switch (evidence) {
  Evidence.owned => true,
  Evidence.revoked => false,
  Evidence.unknown => mirror ?? false,
};

const proKey = 'pro.v1';

/// Port of the native `ProStore` over [StoreKitWorld]; [group] is the App
/// Group. [downgradeOnUnknown] is a deliberately broken store for the
/// harness self-check.
class NativeStoreModel {
  NativeStoreModel(this.world, this.group, {this.downgradeOnUnknown = false});

  final StoreKitWorld world;
  final Map<String, Object> group;
  final bool downgradeOnUnknown;
  void Function(Object?)? sink;

  bool? get mirror => group[proKey] as bool?;

  /// Offline or a StoreKit error: nothing is known.
  Evidence evidence() {
    if (world.offline) return Evidence.unknown;
    return switch (world.revoked) {
      false => Evidence.owned,
      true => Evidence.revoked,
      null => Evidence.unknown,
    };
  }

  bool reconcile() {
    final found = evidence();
    final owned = downgradeOnUnknown
        ? found == Evidence.owned
        : ownedAfter(found, mirror);
    if (mirror != owned) group[proKey] = owned;
    return owned;
  }

  Map<String, Object?> state() => {
    'owned': reconcile(),
    'price': world.offline ? null : r'$4.99',
  };

  void emit() => sink?.call(<String, Object?>{'owned': reconcile()});

  Map<String, Object?> purchase(BuyOutcome outcome) {
    if (world.offline) return {'result': 'failed', 'owned': mirror ?? false};
    switch (outcome) {
      case BuyOutcome.success:
        world
          ..revoked = false
          ..updatePending = false;
        group[proKey] = true;
        emit();
        return {'result': 'purchased', 'owned': true};
      case BuyOutcome.pending:
        world.awaitingApproval = true;
        return {'result': 'pending', 'owned': mirror ?? false};
      case BuyOutcome.cancelled:
        return {'result': 'cancelled', 'owned': mirror ?? false};
    }
  }

  Map<String, Object?> restore() {
    if (world.offline) return {'result': 'failed', 'owned': mirror ?? false};
    final owned = reconcile();
    emit();
    return {'result': 'purchased', 'owned': owned};
  }

  /// `Transaction.updates` delivered a change for the product.
  void onUpdate() {
    reconcile();
    emit();
  }
}

/// Wires a [NativeStoreModel] to the store channels of the test binding.
void _install(NativeStoreModel native, BuyOutcome Function() nextOutcome) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(ChannelProEntitlement.storeChannel, (
    call,
  ) async {
    switch (call.method) {
      case 'state':
        return native.state();
      case 'purchase':
        return native.purchase(nextOutcome());
      case 'restore':
        return native.restore();
    }
    return null;
  });
  messenger.setMockStreamHandler(
    ChannelProEntitlement.storeUpdatesChannel,
    MockStreamHandler.inline(
      onListen: (arguments, events) => native.sink = events.success,
      onCancel: (arguments) => native.sink = null,
    ),
  );
}

void _uninstall() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(ChannelProEntitlement.storeChannel, null);
  messenger.setMockStreamHandler(
    ChannelProEntitlement.storeUpdatesChannel,
    null,
  );
}

/// User data in the same App Group (E3: never touched by the store).
const _userData = {
  'profiles.v1': '[{"id":"dictation","name":"Dictation"}]',
  'fieldRules.v1': '{"search":"review"}',
  'activeProfile.v1': '{"profileId":"dictation","source":"manual","at":"x"}',
};

Future<ModelFailure?> runProSequence(
  List<ProEvent> seq, {
  bool downgradeOnUnknown = false,
}) async {
  final world = StoreKitWorld();
  final group = <String, Object>{..._userData};
  var buyOutcome = BuyOutcome.success;
  NativeStoreModel launch() {
    final native = NativeStoreModel(
      world,
      group,
      downgradeOnUnknown: downgradeOnUnknown,
    )..reconcile(); // ProStore.start()
    _install(native, () => buyOutcome);
    return native;
  }

  var native = launch();
  var dart = ChannelProEntitlement();
  await pumpEventQueue();
  try {
    for (var i = 0; i < seq.length; i++) {
      final event = seq[i];
      final dartBefore = dart.value.owned;
      final mirrorBefore = native.mirror ?? false;
      var mayDowngrade = false;
      switch (event) {
        case Buy(:final outcome):
          buyOutcome = outcome;
          await dart.purchase();
        case Approve():
          if (world.awaitingApproval && !world.offline) {
            world
              ..awaitingApproval = false
              ..revoked = false
              ..updatePending = false;
            native.onUpdate();
          }
        case Refund():
          if (world.revoked == false) {
            world.revoked = true;
            mayDowngrade = !world.offline;
            if (world.offline) {
              world.updatePending = true;
            } else {
              native.onUpdate();
            }
          }
        case GoOffline():
          world.offline = true;
        case GoOnline():
          world.offline = false;
          if (world.updatePending) {
            world.updatePending = false;
            mayDowngrade = true;
            native.onUpdate();
          }
        case Restore():
          await dart.restore();
        case Relaunch():
          dart.dispose();
          _uninstall();
          native = launch();
          dart = ChannelProEntitlement();
          // A relaunch after a delivered revocation may show not-owned.
          mayDowngrade = world.revoked == true && !world.updatePending;
      }
      await pumpEventQueue();

      final mirror = native.mirror ?? false;
      final owned = dart.value.owned;
      // E4: the app shows what the mirror says (one source of truth).
      if (owned != mirror) {
        return ModelFailure(i, 'E4', 'app owned=$owned, mirror=$mirror');
      }
      // E1: a live purchase is never lost; nothing but a revocation
      // downgrades (errors, offline, cancelled or failed actions).
      if (world.entitled && !mirror) {
        return ModelFailure(i, 'E1', 'entitled but mirror=false after $event');
      }
      if (!mayDowngrade && (mirrorBefore && !mirror || dartBefore && !owned)) {
        return ModelFailure(i, 'E1', 'downgraded by $event');
      }
      // E2: a delivered revocation removes Pro.
      if (world.revoked == true && !world.updatePending && mirror) {
        return ModelFailure(i, 'E2', 'revoked but mirror=true');
      }
      // E3: the store never touches user data.
      for (final MapEntry(:key, :value) in _userData.entries) {
        if (group[key] != value) {
          return ModelFailure(i, 'E3', '$key changed to ${group[key]}');
        }
      }
      if (group.keys.any((k) => k != proKey && !_userData.containsKey(k))) {
        return ModelFailure(i, 'E4', 'store wrote ${group.keys}');
      }
    }
    return null;
  } finally {
    dart.dispose();
    _uninstall();
  }
}

String proCaseToDart(String name, List<ProEvent> seq) =>
    "test('$name', () async {\n"
    '  expect(await runProSequence(const [\n'
    '${seq.map((e) => '    $e,').join('\n')}\n'
    '  ]), isNull);\n'
    '});';

Iterable<int> _seeds() {
  final n = int.tryParse(Platform.environment['SHINSOKU_MODEL_SEEDS'] ?? '');
  return n == null
      ? const [1, 7, 42, 99, 123, 2026, 31337]
      : [for (var i = 0; i < n; i++) i];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('E1–E4 hold for seeded random event sequences', () async {
    await check<ProEvent>(
      gen: genEvent,
      run: runProSequence,
      toDart: proCaseToDart,
      seeds: _seeds(),
      length: 40,
    );
  });

  test('the harness catches a store that downgrades when StoreKit '
      'knows nothing', () async {
    Object? caught;
    try {
      await check<ProEvent>(
        gen: genEvent,
        run: (seq) => runProSequence(seq, downgradeOnUnknown: true),
        toDart: proCaseToDart,
        seeds: const [1, 7, 42],
        length: 40,
      );
    } on ModelCheckError catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    expect(caught.toString(), contains('E1 broke'));
  });

  // Named regressions.
  test('E1: bought, offline relaunch keeps Pro', () async {
    expect(
      await runProSequence(const [
        Buy(BuyOutcome.success),
        GoOffline(),
        Relaunch(),
        Restore(),
        Buy(BuyOutcome.success),
      ]),
      isNull,
    );
  });

  test('E1: Ask to Buy approved later unlocks the running app', () async {
    expect(
      await runProSequence(const [
        Buy(BuyOutcome.pending),
        Buy(BuyOutcome.cancelled),
        Approve(),
        Relaunch(),
      ]),
      isNull,
    );
  });

  test('E2: refund while offline applies once back online', () async {
    expect(
      await runProSequence(const [
        Buy(BuyOutcome.success),
        GoOffline(),
        Refund(),
        Relaunch(),
        GoOnline(),
        Relaunch(),
      ]),
      isNull,
    );
  });

  test('ownedAfter: only evidence changes the mirror', () {
    expect(ownedAfter(Evidence.unknown, true), isTrue);
    expect(ownedAfter(Evidence.unknown, null), isFalse);
    expect(ownedAfter(Evidence.revoked, true), isFalse);
    expect(ownedAfter(Evidence.owned, false), isTrue);
  });
}
