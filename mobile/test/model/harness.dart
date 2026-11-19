// Dart port of tool/model_check.py (pfstack model-based testing pattern).
//
// You provide: a generator of random events, a runner that applies a
// sequence to a reference model and to the system under test and checks
// every invariant after every event. The harness runs seeded sequences, and
// on failure shrinks the sequence and prints it as a Dart regression case.
import 'dart:math';

/// One broken invariant: which event broke it, which rule, and why.
class ModelFailure {
  const ModelFailure(this.index, this.rule, this.why);

  final int index;
  final String rule;
  final String why;

  @override
  String toString() => '$rule broke at event $index: $why';
}

/// Applies [seq] and returns the first failure, or null when every invariant
/// held after every event.
typedef SequenceRunner<E> = Future<ModelFailure?> Function(List<E> seq);

/// Removes chunks, then single events, while the sequence still fails.
Future<List<E>> shrink<E>(
  List<E> seq,
  Future<bool> Function(List<E>) fails,
) async {
  var n = 2;
  while (seq.length >= 2) {
    final chunk = max(1, seq.length ~/ n);
    var removed = false;
    for (var start = 0; start < seq.length; start += chunk) {
      final cand = [
        ...seq.sublist(0, start),
        ...seq.sublist(min(seq.length, start + chunk)),
      ];
      if (await fails(cand)) {
        seq = cand;
        n = max(n - 1, 2);
        removed = true;
        break;
      }
    }
    if (!removed) {
      if (chunk == 1) break;
      n = min(n * 2, seq.length);
    }
  }
  return seq;
}

class ModelCheckError extends Error {
  ModelCheckError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Runs [seeds] sequences of [length] events. On the first failing seed,
/// shrinks it and throws a [ModelCheckError] whose message ends with the
/// shrunk sequence as Dart source ([toDart]).
Future<void> check<E>({
  required E Function(Random rng, List<E> sofar) gen,
  required SequenceRunner<E> run,
  required String Function(String name, List<E> seq) toDart,
  required Iterable<int> seeds,
  int length = 200,
}) async {
  for (final seed in seeds) {
    final rng = Random(seed);
    final seq = <E>[];
    for (var i = 0; i < length; i++) {
      seq.add(gen(rng, seq));
    }
    if (await run(seq) == null) continue;
    final small = await shrink(seq, (s) async => await run(s) != null);
    final failure = (await run(small))!;
    throw ModelCheckError(
      'seed $seed: $failure\n'
      'keep as a named case in test/model/regressions_test.dart:\n'
      '${toDart('seed $seed: ${failure.rule}', small)}',
    );
  }
}
