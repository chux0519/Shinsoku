// Invariants D1 / D2 (docs/design/state_invariants.md): posture and size
// changes never change capture state, and folding mid-capture lands on Record.
// The real MobileShell, with the recorder replaced by a DebugCapture fake.
import 'dart:math';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/app/mobile_shell.dart';
import 'package:shinsoku_mobile/services/pro_entitlement.dart';
import 'package:shinsoku_mobile/app/shell_scaffold.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/features/settings/settings_view.dart';
import 'package:shinsoku_mobile/nearby/nearby_microphone_view.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/ui/ui.dart';
import '../support/l10n.dart';

class _FakeCapture implements DebugCapture {
  int starts = 0;
  int stops = 0;

  String transcriptFor(int take) => 'Take $take: move the review to Thursday.';

  @override
  Future<void> start() async => starts++;

  @override
  Future<String> stop() async => transcriptFor(++stops);
}

/// A window the test can reshape: size, safe insets and a fold.
class _Window {
  const _Window(this.name, this.size, this.padding, [this.fold]);

  final String name;
  final Size size;
  final EdgeInsets padding;
  final Rect? fold;

  bool get regular => ShellScaffold.splitFor(size, features) != null;

  List<DisplayFeature> get features => [
    if (fold != null)
      DisplayFeature(
        bounds: fold!,
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureHalfOpened,
      ),
  ];

  @override
  String toString() => name;
}

const _phone = _Window(
  'duo-outer',
  Size(402, 874),
  EdgeInsets.only(top: 62, bottom: 34),
);
const _windows = [
  _phone,
  _Window('duo-outer-466', Size(466, 678), EdgeInsets.only(right: 84)),
  _Window('inner-landscape', Size(951, 669), EdgeInsets.only(right: 84)),
  _Window(
    'inner-book',
    Size(951, 669),
    EdgeInsets.only(right: 84),
    Rect.fromLTWH(462, 0, 27, 669),
  ),
  _Window(
    'inner-portrait',
    Size(669, 951),
    EdgeInsets.only(top: 84, bottom: 95),
  ),
  _Window(
    'inner-tabletop',
    Size(669, 951),
    EdgeInsets.only(top: 84, bottom: 95),
    Rect.fromLTWH(0, 462, 669, 27),
  ),
];

class _Harness {
  _Harness(this.t, this.capture);

  final WidgetTester t;
  final _FakeCapture capture;
  final window = ValueNotifier<_Window>(_phone);

  Future<void> pump() async {
    _apply(window.value);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        theme: buildSkTheme(Brightness.dark),
        builder: (context, child) => ProScope(
          entitlement: _owned,
          child: ValueListenableBuilder(
            valueListenable: window,
            builder: (context, w, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: w.padding,
                viewPadding: w.padding,
                displayFeatures: w.features,
              ),
              child: child!,
            ),
          ),
        ),
        home: MobileShell(debugCapture: capture),
      ),
    );
    await t.pump();
  }

  void _apply(_Window w) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = w.size;
  }

  Future<void> resize(_Window w) async {
    _apply(w);
    window.value = w;
    await t.pump();
    await t.pump();
  }

  // Desktop Mic has a record button of its own; this is Record's.
  Finder get _button => find.descendant(
    of: find.byType(RecordView, skipOffstage: false),
    matching: find.byType(SkRecordButton, skipOffstage: false),
  );

  /// [text] on the Record page (Drafts lists the same take).
  Finder recordText(String text, {bool skipOffstage = true}) => find.descendant(
    of: find.byType(RecordView, skipOffstage: false),
    matching: find.text(text, skipOffstage: skipOffstage),
    skipOffstage: skipOffstage,
  );

  SkRecordState get recordState => t.widget<SkRecordButton>(_button).state;

  bool get recordVisible => _button.hitTestable().evaluate().isNotEmpty;

  Future<void> toggle() async {
    await t.tap(_button);
    await t.pump();
    await t.pump();
  }

  State nearbyState() =>
      t.state(find.byType(NearbyMicrophoneView, skipOffstage: false));
  State settingsState() =>
      t.state(find.byType(SettingsView, skipOffstage: false));
}

/// Desktop is Pro (pricing-01); D1 checks its pairing state survives.
final _owned = FakeProEntitlement(owned: true);

void main() {
  testWidgets('D1: a recording and its transcript survive 402 → 951 → 402 '
      '(and a fold)', (t) async {
    final capture = _FakeCapture();
    final h = _Harness(t, capture);
    await h.pump();
    final nearby = h.nearbyState();
    final settings = h.settingsState();

    await h.toggle();
    expect(capture.starts, 1);
    expect(h.recordState, SkRecordState.listening);
    expect(find.text('Listening'), findsOneWidget);

    for (final w in [_windows[2], _windows[3], _windows[5], _phone]) {
      await h.resize(w);
      expect(h.recordState, SkRecordState.listening, reason: '$w');
      expect(find.text('Listening'), findsOneWidget, reason: '$w');
      expect(h.recordVisible, isTrue, reason: '$w');
      expect(capture.stops, 0, reason: 'the recorder was never stopped ($w)');
    }

    await h.toggle();
    final transcript = capture.transcriptFor(1);
    expect(h.recordText(transcript), findsOneWidget);
    for (final w in [_windows[2], _phone, _windows[4], _phone]) {
      await h.resize(w);
      expect(h.recordText(transcript), findsOneWidget, reason: '$w');
      expect(h.recordState, SkRecordState.idle, reason: '$w');
    }

    // Stateful pages kept their State objects through every switch.
    expect(identical(h.nearbyState(), nearby), isTrue);
    expect(identical(h.settingsState(), settings), isTrue);
  });

  testWidgets('D2: picking a pane mid-recording, then folding, shows Record', (
    t,
  ) async {
    final h = _Harness(t, _FakeCapture());
    await h.pump();
    await h.resize(_windows[2]);
    await h.toggle();
    await t.tap(
      find.descendant(
        of: find.byKey(const ValueKey('pane-switcher')),
        matching: find.text('Settings'),
      ),
    );
    await t.pump();
    await h.resize(_phone);
    expect(h.recordVisible, isTrue);
    expect(h.recordState, SkRecordState.listening);

    // Idle: the phone layout follows the last pane picked.
    await h.toggle();
    await h.resize(_windows[2]);
    await t.tap(
      find.descendant(
        of: find.byKey(const ValueKey('pane-switcher')),
        matching: find.text('Drafts'),
      ),
    );
    await t.pump();
    await h.resize(_phone);
    expect(h.recordVisible, isFalse);
    expect(find.text('Drafts').hitTestable(), findsWidgets);
  });

  // Named regression from the model (seed 7): the user leaves Record on the
  // phone mid-recording, unfolds, folds again; Stop must be in reach.
  testWidgets('D2 regression: tab away on the phone, unfold, fold', (t) async {
    final h = _Harness(t, _FakeCapture());
    await h.pump();
    await h.toggle();
    await t.tap(
      find.descendant(of: find.byType(SkTabBar), matching: find.text('Drafts')),
    );
    await t.pump();
    expect(h.recordVisible, isFalse);
    await h.resize(_windows[2]);
    await h.resize(_windows[1]);
    expect(h.recordVisible, isTrue);
    expect(h.recordState, SkRecordState.listening);
    // The tab bar agrees, and leaving Record again still works.
    await t.tap(
      find.descendant(of: find.byType(SkTabBar), matching: find.text('Drafts')),
    );
    await t.pump();
    expect(h.recordVisible, isFalse);
  });

  // Model-based: seeded random sequences of posture changes, pane / tab picks
  // and record taps; D1 and D2 are checked after every event.
  for (final seed in [1, 7, 42]) {
    testWidgets('D1/D2 model, seed $seed', (t) async {
      final random = Random(seed);
      final capture = _FakeCapture();
      final h = _Harness(t, capture);
      await h.pump();
      var expected = CaptureState.idle;
      String? transcript;
      final log = <String>[];

      for (var step = 0; step < 40; step++) {
        final roll = random.nextInt(10);
        final before = h.window.value;
        if (roll < 5) {
          final w = _windows[random.nextInt(_windows.length)];
          log.add('resize($w)');
          await h.resize(w);
          // D2: regular → compact while capturing shows Record.
          if (before.regular && !w.regular && expected != CaptureState.idle) {
            expect(h.recordVisible, isTrue, reason: log.join(' '));
          }
        } else if (roll < 8) {
          final page = 1 + random.nextInt(3);
          final label = ShellScaffold.tabsFor(en)[page].label;
          log.add('pick($label)');
          final scope = before.regular
              ? find.byKey(const ValueKey('pane-switcher'))
              : find.byType(SkTabBar);
          await t.tap(find.descendant(of: scope, matching: find.text(label)));
          await t.pump();
        } else {
          if (!h.recordVisible) {
            log.add('tab(Record)');
            await t.tap(
              find.descendant(
                of: find.byType(SkTabBar),
                matching: find.text('Record'),
              ),
            );
            await t.pump();
          }
          log.add('toggle');
          await h.toggle();
          if (expected == CaptureState.idle) {
            // A new take replaces the previous result.
            expected = CaptureState.listening;
            transcript = null;
          } else {
            expected = CaptureState.idle;
            transcript = capture.transcriptFor(capture.stops);
          }
        }
        // D1: only record taps change capture state; the transcript stays.
        final reason = 'seed $seed: ${log.join(' ')}';
        expect(
          h.recordState,
          expected == CaptureState.listening
              ? SkRecordState.listening
              : SkRecordState.idle,
          reason: reason,
        );
        if (transcript != null) {
          expect(
            h.recordText(transcript, skipOffstage: false),
            findsOneWidget,
            reason: reason,
          );
        }
      }
    });
  }
}
