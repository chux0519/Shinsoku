import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/ui/ui.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,

  theme: buildSkTheme(Brightness.dark),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('controls meet the 44 pt target', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkButton.text(label: 'A', onPressed: () {}, key: const Key('t')),
            SkIconButton(
              icon: Icons.add,
              tooltip: 'Add',
              onPressed: () {},
              key: const Key('i'),
            ),
            SkSegmented<int>(
              key: const Key('s'),
              segments: const [
                SkSegment(value: 0, label: 'One'),
                SkSegment(value: 1, label: 'Two'),
              ],
              selected: 0,
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );
    for (final k in ['t', 'i', 's']) {
      final size = tester.getSize(find.byKey(Key(k)));
      expect(size.height, greaterThanOrEqualTo(44), reason: k);
      expect(size.width, greaterThanOrEqualTo(44), reason: k);
    }
  });

  testWidgets('icon button and record button expose labels', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkIconButton(
              icon: Icons.copy,
              tooltip: 'Copy draft',
              onPressed: () => taps++,
            ),
            SkRecordButton(state: SkRecordState.idle, onPressed: () => taps++),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Copy draft'), findsOneWidget);
    expect(find.bySemanticsLabel('Start recording'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy draft'));
    await tester.tap(find.bySemanticsLabel('Start recording'));
    expect(taps, 2);
    handle.dispose();
  });

  testWidgets('segmented selection is a fill and is reported selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var value = 0;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => SkSegmented<int>(
            segments: const [
              SkSegment(value: 0, label: 'One'),
              SkSegment(value: 1, label: 'Two'),
            ],
            selected: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Two'));
    await tester.pump();
    expect(value, 1);
    final node = tester.getSemantics(find.text('Two'));
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('processing record button is not tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SkRecordButton(
          state: SkRecordState.processing,
          onPressed: () => taps++,
        ),
        reduceMotion: true,
      ),
    );
    await tester.tap(find.byType(SkRecordButton));
    expect(taps, 0);
  });

  testWidgets('Reduce Motion makes motion instant', (tester) async {
    late Duration d;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            d = SkMotion.of(context);
            return const SizedBox();
          },
        ),
        reduceMotion: true,
      ),
    );
    expect(d, Duration.zero);
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            d = SkMotion.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(d, SkMotion.normal);
  });

  testWidgets('toggle row toggles from anywhere on the row', (tester) async {
    var on = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => SkListRow.toggle(
            title: 'Auto commit',
            value: on,
            onChanged: (v) => setState(() => on = v),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Auto commit'));
    await tester.pump();
    expect(on, isTrue);
  });
}
