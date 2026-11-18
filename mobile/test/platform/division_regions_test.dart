import 'dart:async';
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/platform/division_regions.dart';

Map<String, Object?> _region(Object? l, Object? t, Object? w, Object? h) => {
  'left': l,
  'top': t,
  'width': w,
  'height': h,
};

void main() {
  group('DivisionRegions.parse', () {
    test('reads well-formed regions', () {
      expect(DivisionRegions.parse([_region(462, 0, 27, 669)]), [
        const Rect.fromLTWH(462, 0, 27, 669),
      ]);
      // A zero-width hinge line is still a region.
      expect(DivisionRegions.parse([_region(475.5, 0, 0, 669)]), [
        const Rect.fromLTWH(475.5, 0, 0, 669),
      ]);
    });

    test('empty and non-list input mean no regions', () {
      expect(DivisionRegions.parse(const []), isEmpty);
      expect(DivisionRegions.parse(null), isEmpty);
      expect(DivisionRegions.parse('x'), isEmpty);
      expect(DivisionRegions.parse({'left': 1}), isEmpty);
    });

    test('skips malformed entries and keeps the rest', () {
      final regions = DivisionRegions.parse([
        'not a map',
        _region('1', 0, 10, 10),
        _region(0, 0, double.nan, 10),
        _region(0, 0, double.infinity, 10),
        _region(0, 0, -1, 10),
        _region(0, 0, 0, 0),
        {'left': 0, 'top': 0, 'width': 10},
        _region(10, 20, 30, 40),
      ]);
      expect(regions, [const Rect.fromLTWH(10, 20, 30, 40)]);
    });

    test('caps the number of regions', () {
      final many = [for (var i = 0; i < 20; i++) _region(i, 0, 1, 1)];
      expect(
        DivisionRegions.parse(many),
        hasLength(DivisionRegions.maxRegions),
      );
    });
  });

  testWidgets('streams regions into MediaQuery display features', (t) async {
    final events = StreamController<dynamic>();
    addTearDown(events.close);
    late BuildContext inner;
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(951, 669)),
        child: DivisionRegions(
          testEvents: events.stream,
          child: Builder(
            builder: (context) {
              inner = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(DivisionRegions.of(inner), isEmpty);
    expect(MediaQuery.displayFeaturesOf(inner), isEmpty);

    // Stream events arrive in a microtask after the pump that flushes them;
    // the next frame shows them.
    Future<void> deliver(void Function() send) async {
      send();
      await t.pump();
      await t.pump();
    }

    await deliver(() => events.add([_region(462, 0, 27, 669)]));
    expect(DivisionRegions.of(inner), [const Rect.fromLTWH(462, 0, 27, 669)]);
    final features = MediaQuery.displayFeaturesOf(inner);
    expect(features.single.bounds, const Rect.fromLTWH(462, 0, 27, 669));
    expect(features.single.type, DisplayFeatureType.hinge);

    // Malformed events and channel errors clear the regions.
    await deliver(() => events.add('garbage'));
    expect(DivisionRegions.of(inner), isEmpty);
    await deliver(() => events.add([_region(462, 0, 27, 669)]));
    await deliver(() => events.addError(StateError('channel gone')));
    expect(MediaQuery.displayFeaturesOf(inner), isEmpty);
  });

  testWidgets('no channel off iOS: no regions', (t) async {
    late BuildContext inner;
    await t.pumpWidget(
      DivisionRegions(
        child: Builder(
          builder: (context) {
            inner = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(DivisionRegions.of(inner), isEmpty);
  });
}
