// A RecordingPipeline the test drives event by event: partial and final
// words, a dropped connection, and when the result (or post-processing)
// comes back after Stop.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shinsoku_mobile/app/recording_pipeline.dart';
import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/live_transcript.dart';
import 'package:shinsoku_mobile/services/transcription_service.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

class ScriptedPipeline implements RecordingPipeline {
  ScriptedPipeline({this.postProcess});

  /// Post-processing: the raw text → the processed text (null: none).
  final String Function(String raw)? postProcess;

  final _live = ValueNotifier<LiveTranscript>(LiveTranscript.idle);
  Completer<RealTranscriptionResult>? _result;
  VoiceProfile? _profile;
  var disposed = false;

  @override
  ValueListenable<LiveTranscript> get live => _live;

  LiveTranscript get value => _live.value;

  bool get stopping => _result != null && !_result!.isCompleted;

  @override
  Future<void> start() async {
    _live.value = const LiveTranscript(phase: LivePhase.connecting);
    _live.value = const LiveTranscript(phase: LivePhase.listening);
  }

  bool get _accepting =>
      value.phase == LivePhase.listening || value.phase == LivePhase.finishing;

  /// The provider's interim words replace the pending tail.
  void partial(String words) {
    if (!_accepting) return;
    _live.value = value.copyWith(pending: words);
  }

  /// Final words: appended to committed; pending clears.
  void finalWords(String words) {
    if (!_accepting) return;
    _live.value = LiveTranscript(
      committed: value.committed + words,
      phase: value.phase,
    );
  }

  /// The connection drops (while listening or while finishing).
  void drop() {
    if (!_accepting) return;
    _live.value = value.copyWith(
      phase: LivePhase.failed,
      error: 'example connection closed',
    );
    final result = _result;
    if (result != null && !result.isCompleted) {
      result.completeError(StateError('example connection closed'));
    }
  }

  @override
  Future<RealTranscriptionResult> stop(VoiceProfile profile) {
    final result = Completer<RealTranscriptionResult>();
    _result = result;
    _profile = profile;
    if (value.phase == LivePhase.failed) {
      result.completeError(StateError('example connection closed'));
    } else {
      _live.value = value.copyWith(phase: LivePhase.finishing);
    }
    return result.future;
  }

  /// The provider's result arrives (L2: committed + pending at the end).
  /// With post-processing it takes two calls: raw text (processing), then
  /// the processed text replaces it once. Returns false when there is no
  /// stop waiting.
  Future<bool> process() async {
    final result = _result;
    if (result == null || result.isCompleted) return false;
    final raw = value.text.trim();
    if (raw.isEmpty) {
      _live.value = value.copyWith(
        phase: LivePhase.failed,
        error: 'no transcript',
      );
      result.completeError(StateError('Example returned no transcript.'));
      return true;
    }
    var text = raw;
    final post = postProcess;
    if (post != null) {
      if (value.phase != LivePhase.processing) {
        // First step: the raw text, dimmed, while the profile processes it.
        _live.value = LiveTranscript(
          committed: raw,
          phase: LivePhase.processing,
        );
        return true;
      }
      text = post(raw);
    }
    _live.value = LiveTranscript(committed: text, phase: LivePhase.done);
    result.complete(
      // Like the service: done.committed is plain, result.text has the
      // profile's suffix.
      RealTranscriptionResult(
        text: withCommitSuffix(
          text,
          _profile?.commitSuffix ?? CommitSuffix.none,
        ),
        provider: 'Example',
        detail: '',
      ),
    );
    return true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _live.dispose();
  }
}
