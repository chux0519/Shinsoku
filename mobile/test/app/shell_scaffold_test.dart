import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/app/shell_scaffold.dart';
import 'package:shinsoku_mobile/ui/ui.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';

DisplayFeature _hinge(Rect bounds) => DisplayFeature(
  bounds: bounds,
  type: DisplayFeatureType.hinge,
  state: DisplayFeatureState.postureHalfOpened,
);

void main() {
  group('ShellScaffold.splitFor', () {
    test('compact unless both sides are regular', () {
      for (final size in const [
        Size(402, 874), // iPhone
        Size(874, 402), // iPhone landscape
        Size(466, 678), // Duo outer
        Size(678, 466), // Duo outer landscape (compact × compact)
        Size(475, 669), // Duo inner, Split View half
      ]) {
        expect(ShellScaffold.splitFor(size, const []), isNull, reason: '$size');
      }
    });

    test('flat inner display: centre split along the long side', () {
      final landscape = ShellScaffold.splitFor(const Size(951, 669), const []);
      expect(landscape!.sideBySide, isTrue);
      expect(landscape.firstEnd, 951 / 2 - 12);
      expect(landscape.secondStart, 951 / 2 + 12);
      expect(landscape.fromFold, isFalse);

      final portrait = ShellScaffold.splitFor(const Size(669, 951), const []);
      expect(portrait!.sideBySide, isFalse);
      expect(portrait.firstEnd, 951 / 2 - 12);
    });

    test('a reported fold wins: its axis and its width', () {
      // Book: vertical fold wider than the minimum gap.
      final book = ShellScaffold.splitFor(const Size(951, 669), [
        _hinge(const Rect.fromLTWH(455, 0, 40, 669)),
      ]);
      expect(book, isNotNull);
      expect(book!.sideBySide, isTrue);
      expect((book.firstEnd, book.secondStart), (455.0, 495.0));
      expect(book.fromFold, isTrue);

      // Tabletop on a landscape-sized window: the horizontal fold decides.
      final tabletop = ShellScaffold.splitFor(const Size(951, 669), [
        _hinge(const Rect.fromLTWH(0, 330, 951, 10)),
      ]);
      expect(tabletop!.sideBySide, isFalse);
      expect((tabletop.firstEnd, tabletop.secondStart), (323.0, 347.0));

      // A zero-width hinge line still gets the minimum gap.
      final line = ShellScaffold.splitFor(const Size(951, 669), [
        _hinge(const Rect.fromLTWH(475.5, 0, 0, 669)),
      ]);
      expect((line!.firstEnd, line.secondStart), (463.5, 487.5));
    });

    test('ignores cutouts and features that do not cross the window', () {
      final split = ShellScaffold.splitFor(const Size(951, 669), [
        DisplayFeature(
          bounds: const Rect.fromLTWH(100, 0, 30, 669),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
        _hinge(const Rect.fromLTWH(300, 100, 20, 200)),
      ]);
      expect(split!.fromFold, isFalse);
      expect(split.firstEnd, 951 / 2 - 12);
    });

    test('a fold that leaves a sliver falls back to compact', () {
      expect(
        ShellScaffold.splitFor(const Size(951, 669), [
          _hinge(const Rect.fromLTWH(200, 0, 10, 669)),
        ]),
        isNull,
      );
    });
  });

  group('ShellScaffold layout', () {
    Future<void> pump(
      WidgetTester t,
      Size size, {
      EdgeInsets padding = EdgeInsets.zero,
      List<DisplayFeature> features = const [],
      int tab = 0,
      int secondary = 1,
    }) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = size;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: buildSkTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: padding, displayFeatures: features),
            child: child!,
          ),
          home: ShellScaffold(
            tabIndex: tab,
            secondaryIndex: secondary,
            onTabSelected: (_) {},
            pages: [
              for (final name in ['Record', 'Drafts', 'Desktop', 'Settings'])
                Builder(
                  builder: (context) => SizedBox.expand(
                    key: ValueKey('page-$name'),
                    child: ColoredBox(
                      color: SkColors.of(context).canvas,
                      child: Text('$name body'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    testWidgets('compact: one page and the bottom tab bar', (t) async {
      await pump(t, const Size(402, 874), tab: 1);
      expect(find.byType(SkTabBar), findsOneWidget);
      expect(find.byKey(const ValueKey('pane-switcher')), findsNothing);
      expect(find.text('Drafts body'), findsOneWidget);
      expect(find.text('Record body').hitTestable(), findsNothing);
    });

    testWidgets('regular landscape: Record left, switchable pane right, '
        'trailing inset only on the right pane', (t) async {
      await pump(
        t,
        const Size(951, 669),
        padding: const EdgeInsets.only(right: 84),
        secondary: 3,
      );
      expect(find.byType(SkTabBar), findsNothing);
      final record = t.getRect(find.byKey(const ValueKey('page-Record')));
      final settings = t.getRect(find.byKey(const ValueKey('page-Settings')));
      expect(record.left, 0);
      expect(record.right, 951 / 2 - 12);
      expect(settings.left, 951 / 2 + 12);
      expect(settings.right, 951 - 84);
      expect(find.text('Settings body').hitTestable(), findsOneWidget);
      expect(find.text('Drafts body').hitTestable(), findsNothing);
    });

    testWidgets('regular portrait: switchable pane up, Record down; top and '
        'bottom insets go to their own pane', (t) async {
      await pump(
        t,
        const Size(669, 951),
        padding: const EdgeInsets.only(top: 84, bottom: 95),
      );
      final record = t.getRect(find.byKey(const ValueKey('page-Record')));
      final switcher = t.getRect(find.byKey(const ValueKey('pane-switcher')));
      expect(switcher.top, greaterThanOrEqualTo(84));
      expect(switcher.bottom, lessThan(951 / 2));
      expect(record.top, 951 / 2 + 12);
      expect(record.bottom, 951 - 95);
    });

    testWidgets('nothing interactive or text-bearing in the fold', (t) async {
      const fold = Rect.fromLTWH(460, 0, 31, 669);
      await pump(t, const Size(951, 669), features: [_hinge(fold)]);
      // No hit in the fold reaches either pane's content (or the seam's
      // own semantics): the gap is inert.
      final panes = {
        t.renderObject(find.byKey(const ValueKey('pane-first'))),
        t.renderObject(find.byKey(const ValueKey('pane-second'))),
      };
      bool insidePane(RenderObject? node) {
        for (; node != null; node = node.parent) {
          if (panes.contains(node)) return true;
        }
        return false;
      }

      for (var y = 0.0; y < 669; y += 20) {
        final result = HitTestResult();
        t.binding.hitTestInView(
          result,
          Offset(fold.center.dx, y),
          t.view.viewId,
        );
        for (final entry in result.path) {
          final target = entry.target;
          if (target is RenderObject) {
            expect(insidePane(target), isFalse, reason: 'y=$y');
            expect(target, isNot(isA<RenderParagraph>()), reason: 'y=$y');
          }
        }
      }
      expect(
        t.getRect(find.byKey(const ValueKey('page-Record'))).right,
        lessThanOrEqualTo(fold.left),
      );
      expect(
        t.getRect(find.byKey(const ValueKey('pane-switcher'))).left,
        greaterThanOrEqualTo(fold.right),
      );
    });
  });
}
