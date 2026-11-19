// TEMPORARY copy of T1's interface (live-01 plan, unit T1). T3 deletes this
// file and points the imports at the real one under lib/services/.
import 'package:flutter/foundation.dart';

enum LivePhase {
  idle,
  connecting,
  listening,
  finishing,
  processing,
  done,
  failed,
}

@immutable
class LiveTranscript {
  const LiveTranscript({
    this.committed = '',
    this.pending = '',
    this.phase = LivePhase.idle,
    this.error,
  });

  static const idle = LiveTranscript();

  /// Final words: they only grow while listening (L1).
  final String committed;

  /// The provider's interim words; they may change.
  final String pending;
  final LivePhase phase;
  final String? error;
}
