import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What the last store action left to tell the user (coded; the UI maps it to
/// text, raw platform errors only go to the log, M10).
enum ProNotice {
  /// The purchase waits for approval (Ask to Buy, SCA).
  pending,

  /// The user closed the payment sheet.
  cancelled,

  /// The purchase failed (store error, verification failed).
  failed,

  /// The store is not reachable here (no plugin, no product, offline).
  unavailable,

  /// Restore Purchases found Pro.
  restored,

  /// Restore Purchases finished without finding Pro.
  nothingToRestore,
}

/// Shinsoku Pro as the app sees it (pricing-01).
@immutable
class ProState {
  const ProState({
    this.owned = false,
    this.productPrice,
    this.busy = false,
    this.notice,
  });

  /// Pro is unlocked (StoreKit verified entitlement, via the App Group
  /// mirror `pro.v1`, E1/E4).
  final bool owned;

  /// The localized StoreKit price ("$4.99"), null while loading or when the
  /// store is unreachable.
  final String? productPrice;

  /// A purchase, restore or refresh is running.
  final bool busy;

  /// The outcome of the last purchase/restore, null when there is nothing to
  /// say.
  final ProNotice? notice;

  ProState copyWith({
    bool? owned,
    String? productPrice,
    bool? busy,
    ProNotice? notice,
    bool clearNotice = false,
  }) => ProState(
    owned: owned ?? this.owned,
    productPrice: productPrice ?? this.productPrice,
    busy: busy ?? this.busy,
    notice: clearNotice ? null : (notice ?? this.notice),
  );

  @override
  bool operator ==(Object other) =>
      other is ProState &&
      other.owned == owned &&
      other.productPrice == productPrice &&
      other.busy == busy &&
      other.notice == notice;

  @override
  int get hashCode => Object.hash(owned, productPrice, busy, notice);

  @override
  String toString() =>
      'ProState(owned: $owned, price: $productPrice, busy: $busy, '
      'notice: $notice)';
}

/// The Shinsoku Pro entitlement: one listenable state plus the store actions.
/// Actions never throw; their outcome lands in [ProState.notice].
abstract class ProEntitlement implements ValueListenable<ProState> {
  /// Buys `net.potafree.shinsoku.pro`.
  Future<void> purchase();

  /// Restore Purchases (`AppStore.sync`).
  Future<void> restore();

  /// Re-reads the state and the price.
  Future<void> refresh();

  /// Clears [ProState.notice] (the sheet closed).
  void clearNotice();

  void dispose();
}

/// Shared state handling for both implementations.
abstract class _ProEntitlementBase extends ValueNotifier<ProState>
    implements ProEntitlement {
  _ProEntitlementBase(super.value);

  bool _disposed = false;

  void _set(ProState next) {
    if (!_disposed) value = next;
  }

  @override
  void clearNotice() {
    if (value.notice != null) _set(value.copyWith(clearNotice: true));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Tests, host renders and the DEBUG fixture: a scripted store.
class FakeProEntitlement extends _ProEntitlementBase {
  FakeProEntitlement({
    bool owned = false,
    String? price = r'$4.99',
    this.purchaseResult = ProPurchaseResult.purchased,
    this.restoreFinds = false,
    bool busy = false,
    ProNotice? notice,
  }) : super(
         ProState(
           owned: owned,
           productPrice: price,
           busy: busy,
           notice: notice,
         ),
       );

  /// What [purchase] does.
  ProPurchaseResult purchaseResult;

  /// Whether [restore] finds Pro.
  bool restoreFinds;

  int purchaseCalls = 0;
  int restoreCalls = 0;

  /// Sets the owned flag as a transaction update would (E2: revocation).
  void setOwned(bool owned) => _set(value.copyWith(owned: owned));

  @override
  Future<void> purchase() async {
    purchaseCalls++;
    _set(applyPurchaseResult(value, purchaseResult, ownedAfter: null));
  }

  @override
  Future<void> restore() async {
    restoreCalls++;
    _set(
      applyRestoreResult(
        value,
        ProPurchaseResult.purchased,
        ownedAfter: restoreFinds,
      ),
    );
  }

  @override
  Future<void> refresh() async {}
}

/// `purchase` / `restore` results on the store channel.
enum ProPurchaseResult { purchased, pending, cancelled, failed }

ProPurchaseResult? _parseResult(Object? raw) => switch (raw) {
  'purchased' => ProPurchaseResult.purchased,
  'pending' => ProPurchaseResult.pending,
  'cancelled' => ProPurchaseResult.cancelled,
  'failed' => ProPurchaseResult.failed,
  _ => null,
};

/// The state after a purchase answered [result]. Purchase results only ever
/// upgrade (E1); downgrades come from `state` / transaction updates (E2).
@visibleForTesting
ProState applyPurchaseResult(
  ProState state,
  ProPurchaseResult result, {
  required bool? ownedAfter,
}) {
  final owned =
      state.owned ||
      ownedAfter == true ||
      result == ProPurchaseResult.purchased;
  return state.copyWith(
    owned: owned,
    busy: false,
    notice: switch (result) {
      ProPurchaseResult.purchased => null,
      ProPurchaseResult.pending => ProNotice.pending,
      ProPurchaseResult.cancelled => ProNotice.cancelled,
      ProPurchaseResult.failed => ProNotice.failed,
    },
    clearNotice: result == ProPurchaseResult.purchased,
  );
}

/// The state after Restore Purchases answered [result] / [ownedAfter]; only
/// upgrades (E1).
@visibleForTesting
ProState applyRestoreResult(
  ProState state,
  ProPurchaseResult result, {
  required bool? ownedAfter,
}) {
  final found = ownedAfter == true;
  return state.copyWith(
    owned: state.owned || found,
    busy: false,
    notice: found
        ? ProNotice.restored
        : switch (result) {
            ProPurchaseResult.failed => ProNotice.failed,
            ProPurchaseResult.cancelled => ProNotice.cancelled,
            _ => ProNotice.nothingToRestore,
          },
  );
}

/// The store over `net.potafree.shinsoku/store` (S2 implements it natively;
/// contract in docs/iterations/pricing-01/round-01/S1-implementation.md).
/// No plugin (tests, other platforms) → not owned, never a crash; errors never
/// turn `owned` from true to false (E1).
class ChannelProEntitlement extends _ProEntitlementBase {
  ChannelProEntitlement({
    MethodChannel channel = storeChannel,
    EventChannel updates = storeUpdatesChannel,
  }) : _channel = channel,
       _updates = updates,
       super(const ProState(busy: true)) {
    unawaited(refresh());
  }

  static const storeChannel = MethodChannel('net.potafree.shinsoku/store');
  static const storeUpdatesChannel = EventChannel(
    'net.potafree.shinsoku/store/updates',
  );

  /// How long `state` may take before the UI stops waiting for the price.
  static const stateTimeout = Duration(seconds: 10);

  final MethodChannel _channel;
  final EventChannel _updates;
  StreamSubscription<Object?>? _subscription;

  /// A purchase or restore is running (one at a time).
  bool _acting = false;

  /// Listens for transaction updates once the plugin answered (a missing
  /// plugin would report the failed `listen` as a Flutter error).
  void _listenForUpdates() {
    if (_subscription != null || _disposed) return;
    _subscription = _updates.receiveBroadcastStream().listen(
      _onUpdate,
      onError: (Object error) {
        debugPrint('ShinsokuPro updates error: $error');
      },
    );
  }

  /// Applies a `{owned, price}` map from `state` or the update stream. This
  /// is the only path that may set `owned` to false (E2: revocation);
  /// anything malformed is ignored (E1).
  void _applyStateMap(Object? raw) {
    if (raw is! Map) return;
    final owned = raw['owned'];
    final price = raw['price'];
    _set(
      ProState(
        owned: owned is bool ? owned : value.owned,
        productPrice: price is String && price.isNotEmpty
            ? price
            : value.productPrice,
        busy: value.busy,
        notice: value.notice,
      ),
    );
  }

  void _onUpdate(Object? event) => _applyStateMap(event);

  /// Stops waiting for `state` after [stateTimeout]; cancelled on dispose
  /// so no timer outlives the app (or a test).
  Timer? _stateTimer;

  @override
  Future<void> refresh() async {
    _set(value.copyWith(busy: true));
    final answer = Completer<Object?>();
    _stateTimer?.cancel();
    _stateTimer = Timer(stateTimeout, () {
      if (answer.isCompleted) return;
      // A store that does not answer must not keep "Loading price…" up:
      // Buy falls back to the plain label (E1: owned unchanged).
      debugPrint('ShinsokuPro state timed out');
      answer.complete(null);
    });
    _channel
        .invokeMethod<Object?>('state')
        .then(
          (raw) {
            // A late answer still counts (only the spinner gave up).
            _applyStateMap(raw);
            _listenForUpdates();
            if (!answer.isCompleted) answer.complete(null);
          },
          onError: (Object error) {
            // No plugin here: keep what we have (not owned by default).
            if (error is! MissingPluginException) {
              debugPrint('ShinsokuPro state error: $error');
            }
            if (!answer.isCompleted) answer.complete(null);
          },
        );
    await answer.future;
    _stateTimer?.cancel();
    _set(value.copyWith(busy: _acting));
  }

  @override
  Future<void> purchase() async {
    if (_acting) return;
    _acting = true;
    _set(value.copyWith(busy: true, clearNotice: true));
    try {
      final raw = await _channel.invokeMethod<Object?>('purchase');
      final map = raw is Map ? raw : const {};
      final result = _parseResult(map['result']) ?? ProPurchaseResult.failed;
      final owned = map['owned'];
      _set(
        applyPurchaseResult(
          value,
          result,
          ownedAfter: owned is bool ? owned : null,
        ),
      );
    } on MissingPluginException {
      _set(value.copyWith(busy: false, notice: ProNotice.unavailable));
    } catch (error) {
      debugPrint('ShinsokuPro purchase error: $error');
      _set(value.copyWith(busy: false, notice: ProNotice.failed));
    } finally {
      _acting = false;
    }
  }

  @override
  Future<void> restore() async {
    if (_acting) return;
    _acting = true;
    _set(value.copyWith(busy: true, clearNotice: true));
    try {
      final raw = await _channel.invokeMethod<Object?>('restore');
      final map = raw is Map ? raw : const {};
      final result = _parseResult(map['result']) ?? ProPurchaseResult.failed;
      final owned = map['owned'];
      _set(
        applyRestoreResult(
          value,
          result,
          ownedAfter: owned is bool ? owned : null,
        ),
      );
    } on MissingPluginException {
      _set(value.copyWith(busy: false, notice: ProNotice.unavailable));
    } catch (error) {
      debugPrint('ShinsokuPro restore error: $error');
      _set(value.copyWith(busy: false, notice: ProNotice.failed));
    } finally {
      _acting = false;
    }
  }

  @override
  void dispose() {
    _stateTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

/// DEBUG only: `-ShinsokuSceneProFixture owned|locked` (read by the host
/// through the keyboard bridge, like the live fixture) swaps the store for a
/// fake. Release builds and a missing argument return null.
Future<FakeProEntitlement?> debugProFixtureFromLaunchArgument() async {
  if (!kDebugMode) return null;
  try {
    final name = await const MethodChannel(
      'net.potafree.shinsoku/keyboard_bridge',
    ).invokeMethod<String>('sceneProFixture');
    return switch (name) {
      'owned' => FakeProEntitlement(owned: true),
      'locked' => FakeProEntitlement(),
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

/// Puts a [ProEntitlement] above the navigator so every page, pushed route
/// and sheet sees the same state (E4 on the Dart side).
class ProScope extends InheritedNotifier<ProEntitlement> {
  const ProScope({
    required ProEntitlement entitlement,
    required super.child,
    super.key,
  }) : super(notifier: entitlement);

  /// Fail closed: without a scope nothing is unlocked.
  static final ProEntitlement _locked = FakeProEntitlement(price: null);

  /// The entitlement; rebuilds the caller when its state changes.
  static ProEntitlement of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProScope>()?.notifier ??
      _locked;

  /// Shorthand for `of(context).value.owned`.
  static bool ownedOf(BuildContext context) => of(context).value.owned;
}
