import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Bridges the iPhone Duo division regions (the fold) from UIKit
/// (`UIView.reservedRegions(kind: .division)`, iOS 27.1+, see
/// `ios/Runner/AppDelegate.swift`) into Flutter.
///
/// Flutter fills `MediaQuery.displayFeatures` only on Android, so this widget
/// adds each active region as a hinge [DisplayFeature]. Layout code (the
/// shell, dialogs and sheets through `DisplayFeatureSubScreen`) then reads one
/// API everywhere, and host renders can fake a fold the same way.
///
/// Regions are in the Flutter view's logical coordinates. Every other
/// platform, older iOS and a failing channel report no regions.
class DivisionRegions extends StatefulWidget {
  const DivisionRegions({required this.child, this.testEvents, super.key});

  static const channelName = 'net.potafree.shinsoku/division_regions';

  /// At most this many regions are kept from one event.
  static const maxRegions = 8;

  final Widget child;

  /// Replaces the platform channel in tests.
  @visibleForTesting
  final Stream<dynamic>? testEvents;

  /// Active regions in global logical coordinates; empty when none.
  static List<Rect> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_DivisionRegionScope>()
          ?.regions ??
      const <Rect>[];

  /// Parses one channel event: a list of `{left, top, width, height}` maps.
  /// Malformed entries are skipped; anything else means no regions.
  @visibleForTesting
  static List<Rect> parse(dynamic value) {
    final regions = <Rect>[];
    if (value is! List) return regions;
    for (final item in value.take(maxRegions)) {
      if (item is! Map) continue;
      final numbers = [
        item['left'],
        item['top'],
        item['width'],
        item['height'],
      ];
      if (numbers.any((n) => n is! num || !n.isFinite)) continue;
      final [left, top, width, height] = [
        for (final n in numbers) (n as num).toDouble(),
      ];
      if (width < 0 || height < 0 || (width == 0 && height == 0)) continue;
      regions.add(Rect.fromLTWH(left, top, width, height));
    }
    return regions;
  }

  @override
  State<DivisionRegions> createState() => _DivisionRegionsState();
}

class _DivisionRegionsState extends State<DivisionRegions> {
  StreamSubscription<dynamic>? _subscription;
  List<Rect> _regions = const [];

  @override
  void initState() {
    super.initState();
    final events =
        widget.testEvents ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? const EventChannel(
                DivisionRegions.channelName,
              ).receiveBroadcastStream()
            : null);
    _subscription = events?.listen(
      _update,
      onError: (Object _) => _update(null),
    );
  }

  void _update(dynamic value) {
    final next = DivisionRegions.parse(value);
    if (!mounted || listEquals(next, _regions)) return;
    setState(() => _regions = next);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    final media = MediaQuery.maybeOf(context);
    // Always the same tree shape: a fold appearing must not rebuild the app.
    if (media != null) {
      child = MediaQuery(
        data: media.copyWith(
          displayFeatures: [
            ...media.displayFeatures,
            for (final region in _regions)
              DisplayFeature(
                bounds: region,
                type: DisplayFeatureType.hinge,
                // Only active (folded) regions are reported.
                state: DisplayFeatureState.postureHalfOpened,
              ),
          ],
        ),
        child: child,
      );
    }
    return _DivisionRegionScope(regions: _regions, child: child);
  }
}

class _DivisionRegionScope extends InheritedWidget {
  const _DivisionRegionScope({required this.regions, required super.child});

  final List<Rect> regions;

  @override
  bool updateShouldNotify(_DivisionRegionScope oldWidget) =>
      !listEquals(regions, oldWidget.regions);
}
