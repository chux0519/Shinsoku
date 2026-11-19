// live-01 T3: named cases for the Record model test (L1–L4, D3). Paste new
// shrunk sequences printed by record_model_test.dart here.
import 'package:flutter_test/flutter_test.dart';

import 'record_world.dart';

void regression(String name, List<RecEvent> seq) {
  testWidgets(name, (t) async {
    final failure = await runRecordSequence(t, seq);
    expect(failure, isNull, reason: '$failure');
  });
}

void main() {
  regression('L1: committed grows under changing partials', const [
    NewRecording(),
    Partial('Example '),
    Final('Example '),
    Partial('one. '),
    Partial('示例'),
    Final('示例'),
    Stop(),
    Partial('two '),
    Process(),
  ]);

  // The T1 behaviour change: a drop now fails the session; the words heard
  // so far must become the recording's draft (L2), and a drop after Stop too.
  regression('L2: a drop while listening keeps committed + pending', const [
    NewRecording(),
    Final('Example '),
    Partial('one. '),
    Drop(),
    Edit(' edited'),
    Done(),
  ]);

  regression('L2: a drop after Stop keeps what was heard', const [
    NewRecording(),
    Final('Example '),
    Stop(),
    Partial('two '),
    Drop(),
  ]);

  regression('L2: post-processing replaces the raw text once', const [
    NewRecording(post: true),
    Final('Example '),
    Stop(),
    Process(),
    Process(),
  ]);

  regression(
    'L3: a keyboard Record over unsaved edits keeps them in the '
    'old draft',
    const [
      NewRecording(),
      Final('Example '),
      Stop(),
      Process(),
      Edit(' edited'),
      KeyboardRecord(),
      Final('two '),
      Stop(),
      Process(),
    ],
  );

  regression(
    'L3: Drafts edits the Record draft; Record shows it and Done '
    'updates the same draft',
    const [
      NewRecording(),
      Final('Example '),
      Stop(),
      Process(),
      Edit('!'),
      OpenDraftElsewhere(' x'),
      Edit(' edited'),
      Done(),
    ],
  );

  regression('L4: marked text is committed before a new recording', const [
    NewRecording(),
    Final('示例'),
    Stop(),
    Process(),
    KeyboardUp(),
    Compose('示'),
    NewRecording(),
  ]);

  regression('D3: keyboard up for Record on the stacked Duo, then down', const [
    NewRecording(),
    Final('Example '),
    Stop(),
    Process(),
    KeyboardUp(),
    Edit(' edited'),
    KeyboardDown(),
    KeyboardUp(),
    Done(),
  ]);
}
