import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

/// Where a recording's text is in its life. See docs/iterations/live-01/plan.md.
enum LivePhase {
  idle,
  connecting,
  listening,
  finishing,
  processing,
  done,
  failed,
}

/// What the Record screen shows while (and right after) recording.
///
/// `committed` is text the provider has marked final; during [LivePhase.listening] it only grows (L1).
/// `pending` is the provider's current interim guess and may change on every message.
/// In [LivePhase.done], `committed` is the final text (post-processed when the profile does that) without
/// the profile's commit suffix, and `pending` is empty.
@immutable
class LiveTranscript {
  const LiveTranscript({
    this.committed = '',
    this.pending = '',
    this.phase = LivePhase.idle,
    this.error,
  });

  static const idle = LiveTranscript();

  final String committed;
  final String pending;
  final LivePhase phase;
  final String? error;

  /// committed + pending, as one string.
  String get text => '$committed$pending';

  LiveTranscript copyWith({
    String? committed,
    String? pending,
    LivePhase? phase,
    String? error,
  }) {
    return LiveTranscript(
      committed: committed ?? this.committed,
      pending: pending ?? this.pending,
      phase: phase ?? this.phase,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LiveTranscript &&
      other.committed == committed &&
      other.pending == pending &&
      other.phase == phase &&
      other.error == error;

  @override
  int get hashCode => Object.hash(committed, pending, phase, error);

  @override
  String toString() =>
      'LiveTranscript(${phase.name}, committed: "$committed", pending: "$pending"'
      '${error == null ? '' : ', error: $error'})';
}

/// Bailian (Fun-ASR / Paraformer realtime) `result-generated` sentences → committed / pending.
///
/// A sentence is final when the payload says `sentence_end: true`; models without that field mark the end
/// with a non-null `end_time`. Final sentences are committed in `sentence_id` order, but only while every
/// lower known id is final too, so committed never changes in the middle (L1). Once committed, a sentence
/// is never rewritten: repeated or late updates for it are ignored. A final sentence that arrives with an
/// id below already-committed text is appended (nothing lost, nothing reordered under the user's eyes).
class BailianSentenceTracker {
  final _texts = <int, String>{};
  final _ended = <int>{};
  final _committedIds = <int>{};
  final _committed = StringBuffer();

  String get committed => _committed.toString();

  String get pending {
    final ids = _texts.keys.where((id) => !_committedIds.contains(id)).toList()
      ..sort();
    return ids.map((id) => _texts[id]!).join();
  }

  /// All text, committed first, then everything not yet final (what a stop returns).
  String get finalText => '$committed$pending';

  /// Applies one `payload.output.sentence` map. Returns true when committed or pending changed.
  bool apply(Map<dynamic, dynamic> sentence) {
    final id = sentence['sentence_id'];
    final text = sentence['text'];
    if (id is! int || text is! String) {
      return false;
    }
    if (_committedIds.contains(id)) {
      return false;
    }
    final before = '$committed\u0000$pending';
    if (text.isNotEmpty) {
      _texts[id] = text;
    }
    final sentenceEnd = sentence['sentence_end'];
    final ended = sentenceEnd is bool
        ? sentenceEnd
        : sentence['end_time'] is num;
    if (ended && _texts.containsKey(id)) {
      _ended.add(id);
    }
    _advance();
    return before != '$committed\u0000$pending';
  }

  void _advance() {
    final open = _texts.keys.where((id) => !_committedIds.contains(id)).toList()
      ..sort();
    for (final id in open) {
      if (!_ended.contains(id)) {
        break;
      }
      _committed.write(_texts[id]);
      _committedIds.add(id);
    }
  }
}

/// Soniox realtime tokens → committed / pending.
///
/// Final tokens (`is_final: true`) are appended to committed once; every message's non-final tokens replace
/// pending. Control tokens (`<fin>`, `<end>`) are dropped. A final token that starts before the end of the
/// last committed final token (a repeated message) is skipped, so nothing is counted twice (L2).
class SonioxTokenTracker {
  final _committed = StringBuffer();
  var _pending = '';
  num? _lastFinalEndMs;

  String get committed => _committed.toString();
  String get pending => _pending;
  String get finalText => '$committed$pending';

  /// Applies one message's `tokens` list. Returns true when committed or pending changed.
  bool apply(List<dynamic> tokens) {
    final before = '$committed\u0000$_pending';
    final pending = StringBuffer();
    for (final token in tokens) {
      if (token is! Map) {
        continue;
      }
      final text = token['text'];
      if (text is! String || text.isEmpty || _isControl(text)) {
        continue;
      }
      if (token['is_final'] == true) {
        final start = token['start_ms'];
        final end = token['end_ms'];
        final last = _lastFinalEndMs;
        if (last != null && start is num && start < last) {
          continue;
        }
        _committed.write(text);
        if (end is num) {
          _lastFinalEndMs = end;
        }
      } else {
        pending.write(text);
      }
    }
    _pending = pending.toString();
    return before != '$committed\u0000$_pending';
  }

  static bool _isControl(String text) => text == '<fin>' || text == '<end>';
}

/// The few socket operations the live sessions need, so tests can replay recorded messages.
abstract class LiveSocket {
  Stream<dynamic> get stream;
  void send(Object data);
  Future<void> close();
}

typedef LiveSocketConnector =
    LiveSocket Function(Uri uri, {Map<String, String>? headers});

LiveSocket connectIoLiveSocket(Uri uri, {Map<String, String>? headers}) =>
    _IoLiveSocket(IOWebSocketChannel.connect(uri, headers: headers));

class _IoLiveSocket implements LiveSocket {
  _IoLiveSocket(this._channel);

  final IOWebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  void send(Object data) => _channel.sink.add(data);

  @override
  Future<void> close() async {
    await _channel.sink.close();
  }
}
