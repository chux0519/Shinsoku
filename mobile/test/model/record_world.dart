// live-01 T3: model-based test of the Record screen (L1–L4, D3,
// docs/design/state_invariants.md). The system under test is the real
// MobileShell on the iPhone Duo inner display, portrait (stacked panes), with
// a ScriptedPipeline instead of the microphone and provider. A small
// reference model predicts the drafts and the Record area after every event.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shinsoku_mobile/app/mobile_shell.dart';
import 'package:shinsoku_mobile/features/drafts/drafts_view.dart';
import 'package:shinsoku_mobile/features/record/record_view.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

import 'harness.dart';
import 'scripted_pipeline.dart';

// ── Events ────────────────────────────────────────────────────────────────

sealed class RecEvent {
  const RecEvent();

  /// Dart source of this event, for printed regression cases.
  String get dart;

  @override
  String toString() => dart;
}

/// Record tapped in the app ([post]: the profile post-processes).
class NewRecording extends RecEvent {
  const NewRecording({this.post = false});
  final bool post;
  @override
  String get dart => 'NewRecording(post: $post)';
}

/// Record started from the keyboard (`shinsoku://dictation`).
class KeyboardRecord extends RecEvent {
  const KeyboardRecord({this.post = false});
  final bool post;
  @override
  String get dart => 'KeyboardRecord(post: $post)';
}

class Partial extends RecEvent {
  const Partial(this.words);
  final String words;
  @override
  String get dart => "Partial('$words')";
}

class Final extends RecEvent {
  const Final(this.words);
  final String words;
  @override
  String get dart => "Final('$words')";
}

/// The provider connection drops.
class Drop extends RecEvent {
  const Drop();
  @override
  String get dart => 'Drop()';
}

/// Stop tapped.
class Stop extends RecEvent {
  const Stop();
  @override
  String get dart => 'Stop()';
}

/// The provider result (or the post-processed text) arrives.
class Process extends RecEvent {
  const Process();
  @override
  String get dart => 'Process()';
}

/// Typing in the Record area.
class Edit extends RecEvent {
  const Edit(this.suffix);
  final String suffix;
  @override
  String get dart => "Edit('$suffix')";
}

/// IME marked text (not yet committed) at the end of the Record area.
class Compose extends RecEvent {
  const Compose(this.suffix);
  final String suffix;
  @override
  String get dart => "Compose('$suffix')";
}

class Done extends RecEvent {
  const Done();
  @override
  String get dart => 'Done()';
}

/// Drafts opens the Record screen's draft, appends [suffix], goes back.
class OpenDraftElsewhere extends RecEvent {
  const OpenDraftElsewhere(this.suffix);
  final String suffix;
  @override
  String get dart => "OpenDraftElsewhere('$suffix')";
}

/// Tap into the Record area; the software keyboard comes up.
class KeyboardUp extends RecEvent {
  const KeyboardUp();
  @override
  String get dart => 'KeyboardUp()';
}

class KeyboardDown extends RecEvent {
  const KeyboardDown();
  @override
  String get dart => 'KeyboardDown()';
}

const _words = ['Example ', 'one. ', '示例', 'two ', '，', 'three'];
const _typed = [' x', '!', '示', ' edited'];

RecEvent genRecEvent(Random rng, List<RecEvent> sofar) {
  String word() => _words[rng.nextInt(_words.length)];
  String typed() => _typed[rng.nextInt(_typed.length)];
  final roll = rng.nextInt(26);
  return switch (roll) {
    < 3 => NewRecording(post: rng.nextInt(3) == 0),
    < 4 => KeyboardRecord(post: rng.nextInt(3) == 0),
    < 7 => Partial(word()),
    < 10 => Final(word()),
    < 11 => const Drop(),
    < 13 => const Stop(),
    < 16 => const Process(),
    < 19 => Edit(typed()),
    < 20 => Compose(typed()),
    < 22 => const Done(),
    < 23 => OpenDraftElsewhere(typed()),
    < 25 => const KeyboardUp(),
    _ => const KeyboardDown(),
  };
}

String recordCaseToDart(String name, List<RecEvent> seq) {
  final events = seq.map((e) => '    ${e.dart},').join('\n');
  return "  regression('$name', const [\n$events\n  ]);";
}

// ── Reference model ───────────────────────────────────────────────────────

enum ModelCapture { idle, listening, stopping, processing }

class ModelDraft {
  ModelDraft(this.text);
  String text;
}

class RecordModel {
  var capture = ModelCapture.idle;
  var post = false;
  var committed = '';
  var pending = '';
  final drafts = <ModelDraft>[];
  ModelDraft? recordDraft;
  var area = '';
  var baseline = '';
  var focused = false;
  var keyboardUp = false;

  bool get editable => capture == ModelCapture.idle;
  bool get dirty => editable && area.trim().isNotEmpty && area != baseline;
  bool get doneVisible => editable && (focused || dirty);

  void save(String text) {
    final current = recordDraft;
    if (current != null && drafts.contains(current)) {
      current.text = text;
    } else {
      final draft = ModelDraft(text);
      drafts.insert(0, draft);
      recordDraft = draft;
    }
  }

  void _flush() {
    if (dirty) {
      save(area);
      baseline = area;
    }
  }

  void _newDraft(String text) {
    final draft = ModelDraft(text);
    drafts.insert(0, draft);
    recordDraft = draft;
    area = text;
    baseline = text;
  }

  /// Applies [e]; returns false when the event does nothing in this state.
  bool apply(RecEvent e) {
    switch (e) {
      case NewRecording(:final post) || KeyboardRecord(:final post):
        if (capture != ModelCapture.idle) return false;
        _flush();
        this.post = post;
        capture = ModelCapture.listening;
        committed = '';
        pending = '';
        area = '';
        focused = false;
        keyboardUp = false;
      case Partial(:final words):
        if (capture != ModelCapture.listening && capture != ModelCapture.stopping) {
          return false;
        }
        pending = words;
        area = committed + pending;
      case Final(:final words):
        if (capture != ModelCapture.listening && capture != ModelCapture.stopping) {
          return false;
        }
        committed += words;
        pending = '';
        area = committed;
      case Drop():
        if (capture != ModelCapture.listening && capture != ModelCapture.stopping) {
          return false;
        }
        final heard = (committed + pending).trim();
        capture = ModelCapture.idle;
        if (heard.isNotEmpty) {
          _newDraft(heard);
        } else {
          area = committed + pending;
        }
      case Stop():
        if (capture != ModelCapture.listening) return false;
        capture = ModelCapture.stopping;
      case Process():
        if (capture != ModelCapture.stopping && capture != ModelCapture.processing) {
          return false;
        }
        final raw = (committed + pending).trim();
        if (capture == ModelCapture.stopping && raw.isEmpty) {
          capture = ModelCapture.idle; // "no transcript": nothing to keep
          area = committed + pending;
        } else if (capture == ModelCapture.stopping && post) {
          capture = ModelCapture.processing;
          committed = raw;
          pending = '';
          area = raw;
        } else {
          capture = ModelCapture.idle;
          _newDraft(post ? processed(committed) : raw);
        }
      case Edit(:final suffix):
        if (!editable) return false;
        area += suffix;
        focused = true;
      case Compose(:final suffix):
        if (!editable || !focused) return false;
        area += suffix;
      case Done():
        if (!doneVisible) return false;
        _flush();
        focused = false;
        keyboardUp = false;
      case OpenDraftElsewhere(:final suffix):
        final draft = recordDraft;
        if (!editable || draft == null || !drafts.contains(draft)) {
          return false;
        }
        _flush();
        draft.text = draft.text + suffix;
        area = draft.text;
        baseline = draft.text;
        focused = false;
        keyboardUp = false;
      case KeyboardUp():
        if (!editable) return false;
        focused = true;
        keyboardUp = true;
      case KeyboardDown():
        if (!focused && !keyboardUp) return false;
        focused = false;
        keyboardUp = false;
    }
    return true;
  }
}

String processed(String raw) => '[$raw]';

// ── System under test ─────────────────────────────────────────────────────

const _duoPortrait = Size(669, 951);
const _keyboardInset = 380.0;
const _field = ValueKey('record-transcript-field');

class RecordSystem {
  RecordSystem(this.t);

  final WidgetTester t;
  final pipelines = <ScriptedPipeline>[];
  var nextPost = false;

  ScriptedPipeline? get pipeline => pipelines.isEmpty ? null : pipelines.last;

  Future<void> launch() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('net.potafree.shinsoku/keyboard_bridge'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('net.potafree.shinsoku/profiles'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('net.potafree.shinsoku/deep_link'),
      (call) async => null,
    );
    t.view.physicalSize = _duoPortrait;
    t.view.devicePixelRatio = 1;
    t.view.resetViewInsets();
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: buildSkTheme(Brightness.dark),
        home: MobileShell(
          pipelineFactory: () {
            final p = ScriptedPipeline(
              postProcess: nextPost ? processed : null,
            );
            pipelines.add(p);
            return p;
          },
        ),
      ),
    );
    await t.pump();
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await t.pump();
    }
  }

  Future<void> _keyboardDown() async {
    FocusManager.instance.primaryFocus?.unfocus();
    t.view.resetViewInsets();
    await settle();
  }

  Future<void> apply(RecEvent e) async {
    switch (e) {
      case NewRecording(:final post):
        nextPost = post;
        await t.tap(_recordButton, warnIfMissed: false);
        await settle();
        // The keyboard goes down when the field loses focus.
        t.view.resetViewInsets();
        await settle();
      case KeyboardRecord(:final post):
        nextPost = post;
        // Not awaited: the shell answers after its 250 ms delay.
        unawaited(
          t.binding.defaultBinaryMessenger.handlePlatformMessage(
            'net.potafree.shinsoku/deep_link',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('openURL', 'shinsoku://dictation'),
            ),
            (_) {},
          ),
        );
        await t.pump(const Duration(milliseconds: 300));
        await settle();
        t.view.resetViewInsets();
        await settle();
      case Partial(:final words):
        pipeline?.partial(words);
        await settle();
      case Final(:final words):
        pipeline?.finalWords(words);
        await settle();
      case Drop():
        pipeline?.drop();
        await settle();
      case Stop():
        await t.tap(_recordButton, warnIfMissed: false);
        await settle();
      case Process():
        await pipeline?.process();
        await settle();
      case Edit(:final suffix):
        await t.enterText(find.byKey(_field), controller.text + suffix);
        await settle();
      case Compose(:final suffix):
        final text = controller.text + suffix;
        t.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
            composing: TextRange(
              start: text.length - suffix.length,
              end: text.length,
            ),
          ),
        );
        await settle();
      case Done():
        await t.tap(
          find.byKey(const ValueKey('record-done')),
          warnIfMissed: false,
        );
        await settle();
        t.view.resetViewInsets();
        await settle();
      case OpenDraftElsewhere(:final suffix):
        await _keyboardDown();
        final drafts = t.widget<DraftsView>(
          find.byType(DraftsView, skipOffstage: false),
        );
        // The Record draft is the newest one the model points at; the shell
        // decides which entry that is, so open it through Drafts' callback.
        final entry = _recordDraftEntry(drafts);
        if (entry == null) return;
        drafts.onEdit(entry);
        await t.pumpAndSettle();
        final editor = find.byKey(const ValueKey('draft-editor-field'));
        final current = t.widget<TextField>(editor).controller!.text;
        await t.enterText(editor, current + suffix);
        await t.pump();
        await t.tap(find.byKey(const ValueKey('draft-editor-back')));
        await t.pumpAndSettle();
      case KeyboardUp():
        await t.tap(find.byKey(_field), warnIfMissed: false);
        t.view.viewInsets = const FakeViewPadding(bottom: _keyboardInset);
        await settle();
      case KeyboardDown():
        await _keyboardDown();
    }
  }

  /// Set by the runner from the model: which list index is the Record draft.
  int? recordDraftIndex;

  dynamic _recordDraftEntry(DraftsView view) {
    final i = recordDraftIndex;
    if (i == null || i >= view.drafts.length) return null;
    return view.drafts[i];
  }

  Finder get _recordButton => find.descendant(
    of: find.byType(RecordView),
    matching: find.byType(SkRecordButton),
  );

  SkTranscriptController get controller =>
      t.widget<TextField>(find.byKey(_field, skipOffstage: false)).controller!
          as SkTranscriptController;

  List<String> get drafts => t
      .widget<DraftsView>(find.byType(DraftsView, skipOffstage: false))
      .drafts
      .map((d) => d.text)
      .toList();

  bool get paneFirstVisible => find
      .byKey(const ValueKey('pane-first'))
      .hitTestable()
      .evaluate()
      .isNotEmpty;

  bool get doneVisible => find
      .byKey(const ValueKey('record-done'))
      .hitTestable()
      .evaluate()
      .isNotEmpty;
}

// ── Runner ────────────────────────────────────────────────────────────────

/// Runs [seq] on a fresh shell and checks L1–L4 and D3 after every event.
Future<ModelFailure?> runRecordSequence(
  WidgetTester t,
  List<RecEvent> seq,
) async {
  final model = RecordModel();
  final system = RecordSystem(t);
  await system.launch();
  String? committedSoFar;
  for (var i = 0; i < seq.length; i++) {
    final e = seq[i];
    // Composition only exists while focused; the model tracks focus.
    if (e is Compose && !model.focused) continue;
    final before = model.capture;
    if (!model.apply(e)) continue;
    system.recordDraftIndex = model.recordDraft == null
        ? null
        : model.drafts.indexOf(model.recordDraft!);
    await system.apply(e);
    final failure = _check(model, system, e, i, before, committedSoFar);
    if (failure != null) return failure;
    final live =
        model.capture == ModelCapture.listening ||
        model.capture == ModelCapture.stopping;
    committedSoFar = live ? model.committed : null;
  }
  return null;
}

ModelFailure? _check(
  RecordModel model,
  RecordSystem system,
  RecEvent e,
  int i,
  ModelCapture before,
  String? committedSoFar,
) {
  final area = system.controller.text;
  final live =
      model.capture == ModelCapture.listening || model.capture == ModelCapture.stopping;
  if (live) {
    if (committedSoFar != null && !area.startsWith(committedSoFar)) {
      return ModelFailure(
        i,
        'L1',
        'committed "$committedSoFar" is not a prefix of the area "$area"',
      );
    }
    if (area != model.area) {
      return ModelFailure(i, 'L1', 'area "$area" ≠ live "${model.area}"');
    }
  }
  final expected = model.drafts.map((d) => d.text).toList();
  final actual = system.drafts;
  final finishing =
      e is Drop || e is Process || (e is Stop && before != ModelCapture.idle);
  if (!_listEquals(actual, expected)) {
    return ModelFailure(
      i,
      finishing ? 'L2' : 'L3',
      'drafts $actual ≠ expected $expected',
    );
  }
  if (!live && area != model.area) {
    return ModelFailure(
      i,
      finishing ? 'L2' : 'L3',
      'Record area "$area" ≠ expected "${model.area}"',
    );
  }
  if ((e is NewRecording || e is KeyboardRecord) &&
      system.controller.value.composing.isValid) {
    return ModelFailure(i, 'L4', 'a composition survived the record start');
  }
  final collapsed = model.focused && model.keyboardUp;
  if (collapsed == system.paneFirstVisible) {
    return ModelFailure(
      i,
      'D3',
      collapsed
          ? 'keyboard up for Record, the switchable pane still shows'
          : 'the switchable pane is hidden without the keyboard',
    );
  }
  if (collapsed && !system.doneVisible) {
    return ModelFailure(i, 'D3', 'Done is not reachable above the keyboard');
  }
  return null;
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
