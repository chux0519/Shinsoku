import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shinsoku_mobile/services/live_transcript.dart';

/// A recorded provider exchange (test/fixtures/streaming/*.json), hand-written in the providers' shapes.
///
/// `on_start`: sent after the client's first message (run-task / config).
/// `during`: sent one by one by [ReplayLiveSocket.replayDuring] while "recording".
/// `on_finish`: sent after the client's finish signal (finish-task / empty frame), then the socket closes.
/// `drop_after_during`: the socket closes right after `during` (a dropped connection).
class StreamingFixture {
  StreamingFixture(this.name, this.json);

  factory StreamingFixture.load(String name) {
    final file = File('test/fixtures/streaming/$name.json');
    return StreamingFixture(
      name,
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  final String name;
  final Map<String, dynamic> json;

  List<dynamic> list(String key) => (json[key] as List?) ?? const [];
  bool get dropAfterDuring => json['drop_after_during'] == true;
  String? string(String key) => json[key] as String?;
}

class ReplayLiveSocket implements LiveSocket {
  ReplayLiveSocket(this.fixture);

  final StreamingFixture fixture;
  final _controller = StreamController<dynamic>();
  final sent = <Object>[];
  Uri? uri;
  Map<String, String>? headers;
  var closed = false;

  LiveSocket connect(Uri uri, {Map<String, String>? headers}) {
    this.uri = uri;
    this.headers = headers;
    return this;
  }

  @override
  Stream<dynamic> get stream => _controller.stream;

  int get audioBytes =>
      sent.whereType<List<int>>().fold(0, (sum, chunk) => sum + chunk.length);

  @override
  void send(Object data) {
    sent.add(data);
    if (data is! String) {
      return;
    }
    final textMessages = sent.whereType<String>().length;
    if (textMessages == 1) {
      _emitAll(fixture.list('on_start'));
    } else if (_isFinishSignal(data)) {
      _emitAll(fixture.list('on_finish'));
      if (!_controller.isClosed) {
        scheduleMicrotask(_controller.close);
      }
    }
  }

  bool _isFinishSignal(String data) {
    if (data.isEmpty) {
      return true;
    }
    final decoded = jsonDecode(data);
    return decoded is Map &&
        (decoded['header'] as Map?)?['action'] == 'finish-task';
  }

  void _emitAll(List<dynamic> messages) {
    for (final message in messages) {
      _controller.add(jsonEncode(message));
    }
  }

  /// Sends the `during` messages one at a time; [afterEach] sees the state after each one.
  Future<void> replayDuring([void Function(int index)? afterEach]) async {
    final messages = fixture.list('during');
    for (var i = 0; i < messages.length; i++) {
      _controller.add(jsonEncode(messages[i]));
      await pump();
      afterEach?.call(i);
    }
    if (fixture.dropAfterDuring) {
      await _controller.close();
      await pump();
    }
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  static Future<void> pump() => Future<void>.delayed(Duration.zero);
}
