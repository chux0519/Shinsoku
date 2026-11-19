import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/services/pro_entitlement.dart';

/// pricing-01: the entitlement over `net.potafree.shinsoku/store` (contract in
/// docs/iterations/pricing-01/round-01/S1-implementation.md) and the fake.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const store = ChannelProEntitlement.storeChannel;
  const updatesName = 'net.potafree.shinsoku/store/updates';

  late List<String> calls;
  late Future<Object?> Function(MethodCall call) handler;

  /// Pushes [event] on the updates stream as the native side would.
  Future<void> emitUpdate(Object? event) async {
    await messenger.handlePlatformMessage(
      updatesName,
      const StandardMethodCodec().encodeSuccessEnvelope(event),
      (_) {},
    );
  }

  setUp(() {
    calls = [];
    handler = (call) async => {'owned': false, 'price': r'$4.99'};
    messenger.setMockMethodCallHandler(store, (call) {
      calls.add(call.method);
      return handler(call);
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel(updatesName),
      (call) async => null, // listen / cancel
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(store, null);
      messenger.setMockMethodCallHandler(
        const MethodChannel(updatesName),
        null,
      );
    });
  });

  Future<ChannelProEntitlement> started() async {
    final pro = ChannelProEntitlement();
    addTearDown(pro.dispose);
    await pumpEventQueue();
    return pro;
  }

  test('loads state and the localized price', () async {
    final pro = await started();
    expect(calls, contains('state'));
    expect(pro.value.owned, isFalse);
    expect(pro.value.productPrice, r'$4.99');
    expect(pro.value.busy, isFalse);
  });

  test('purchase: purchased → owned, no notice', () async {
    final pro = await started();
    handler = (call) async => call.method == 'purchase'
        ? {'result': 'purchased', 'owned': true}
        : {'owned': false, 'price': r'$4.99'};
    await pro.purchase();
    expect(pro.value.owned, isTrue);
    expect(pro.value.notice, isNull);
    expect(pro.value.busy, isFalse);
  });

  for (final (result, notice) in [
    ('pending', ProNotice.pending),
    ('cancelled', ProNotice.cancelled),
    ('failed', ProNotice.failed),
    ('nonsense', ProNotice.failed),
  ]) {
    test('purchase: $result → $notice, not owned', () async {
      final pro = await started();
      handler = (call) async => {'result': result, 'owned': false};
      await pro.purchase();
      expect(pro.value.owned, isFalse);
      expect(pro.value.notice, notice);
    });
  }

  test('purchase: a platform error is a coded failure, never raw', () async {
    final pro = await started();
    handler = (call) async =>
        throw PlatformException(code: 'store', message: 'raw text');
    await pro.purchase();
    expect(pro.value.notice, ProNotice.failed);
    expect(pro.value.busy, isFalse);
  });

  group('E1: errors never downgrade', () {
    Future<ChannelProEntitlement> owned() async {
      handler = (call) async => {'owned': true, 'price': r'$4.99'};
      final pro = await started();
      expect(pro.value.owned, isTrue);
      return pro;
    }

    test('state throws', () async {
      final pro = await owned();
      handler = (call) async => throw PlatformException(code: 'offline');
      await pro.refresh();
      expect(pro.value.owned, isTrue);
    });

    test('state answers garbage', () async {
      final pro = await owned();
      handler = (call) async => 'garbage';
      await pro.refresh();
      expect(pro.value.owned, isTrue);
      handler = (call) async => {'price': r'$4.99'};
      await pro.refresh();
      expect(pro.value.owned, isTrue);
    });

    test('purchase / restore fail with owned: false', () async {
      final pro = await owned();
      handler = (call) async => {'result': 'failed', 'owned': false};
      await pro.purchase();
      expect(pro.value.owned, isTrue);
      await pro.restore();
      expect(pro.value.owned, isTrue);
      handler = (call) async => throw PlatformException(code: 'x');
      await pro.restore();
      expect(pro.value.owned, isTrue);
    });

    test('the update stream reports an error', () async {
      final pro = await owned();
      await messenger.handlePlatformMessage(
        updatesName,
        const StandardMethodCodec().encodeErrorEnvelope(code: 'boom'),
        (_) {},
      );
      await emitUpdate('garbage');
      expect(pro.value.owned, isTrue);
    });
  });

  test('E2: a transaction update can revoke and grant', () async {
    final pro = await started();
    await emitUpdate({'owned': true, 'price': r'$4.99'});
    expect(pro.value.owned, isTrue);
    await emitUpdate({'owned': false, 'price': r'$4.99'});
    expect(pro.value.owned, isFalse);
  });

  test('restore: found → restored; nothing → nothingToRestore', () async {
    final pro = await started();
    handler = (call) async => {'result': 'purchased', 'owned': false};
    await pro.restore();
    expect(pro.value.owned, isFalse);
    expect(pro.value.notice, ProNotice.nothingToRestore);
    handler = (call) async => {'result': 'purchased', 'owned': true};
    await pro.restore();
    expect(pro.value.owned, isTrue);
    expect(pro.value.notice, ProNotice.restored);
    pro.clearNotice();
    expect(pro.value.notice, isNull);
  });

  test('one store action at a time', () async {
    final pro = await started();
    final gate = Completer<Object?>();
    var purchases = 0;
    handler = (call) {
      if (call.method == 'purchase') purchases++;
      return gate.future;
    };
    final first = pro.purchase();
    await pumpEventQueue();
    expect(pro.value.busy, isTrue);
    await pro.purchase();
    await pro.restore();
    expect(purchases, 1);
    gate.complete({'result': 'purchased', 'owned': true});
    await first;
    expect(pro.value.owned, isTrue);
    expect(pro.value.busy, isFalse);
  });

  test('no plugin: not owned, no crash, unavailable on buy', () async {
    messenger.setMockMethodCallHandler(store, null);
    messenger.setMockMethodCallHandler(const MethodChannel(updatesName), null);
    final pro = ChannelProEntitlement();
    addTearDown(pro.dispose);
    await pumpEventQueue();
    expect(pro.value.owned, isFalse);
    expect(pro.value.busy, isFalse);
    expect(pro.value.productPrice, isNull);
    await pro.purchase();
    expect(pro.value.notice, ProNotice.unavailable);
    await pro.restore();
    expect(pro.value.notice, ProNotice.unavailable);
  });

  test('fake: scripted purchase, restore and revocation', () async {
    final fake = FakeProEntitlement(
      purchaseResult: ProPurchaseResult.cancelled,
    );
    await fake.purchase();
    expect(fake.value.owned, isFalse);
    expect(fake.value.notice, ProNotice.cancelled);
    fake.restoreFinds = true;
    await fake.restore();
    expect(fake.value.owned, isTrue);
    fake.setOwned(false);
    expect(fake.value.owned, isFalse);
    expect(fake.purchaseCalls, 1);
    expect(fake.restoreCalls, 1);
  });
}
