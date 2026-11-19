// live-01 T3: seeded model test for the Record screen (L1–L4, D3,
// docs/design/state_invariants.md). Fixed seeds by default; a longer run
// with SHINSOKU_MODEL_SEEDS=<n> in the environment.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import 'record_world.dart';

Iterable<int> _seeds() {
  final n = int.tryParse(Platform.environment['SHINSOKU_MODEL_SEEDS'] ?? '');
  return n == null
      ? const [1, 7, 42, 99, 2026]
      : [for (var i = 0; i < n; i++) i];
}

void main() {
  testWidgets('L1–L4 and D3 hold for seeded random event sequences', (t) async {
    await check<RecEvent>(
      gen: genRecEvent,
      run: (seq) => runRecordSequence(t, seq),
      toDart: recordCaseToDart,
      seeds: _seeds(),
      length: 80,
    );
  });
}
