import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shinsoku_mobile/app/debug_live_fixtures.dart';
import 'package:shinsoku_mobile/app/recording_pipeline.dart';
import 'package:shinsoku_mobile/services/live_transcript.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/transcription_service.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

/// A recorded provider exchange (T1's streaming fixtures, `example` content,
/// no keys): `on_start` after the client's first message, `during` while the
/// user "speaks", `on_finish` after the finish signal, `drop_after_during`
/// for a dropped connection.
class LiveFixture {
  const LiveFixture(this.name, this.json);

  final String name;
  final Map<String, dynamic> json;

  /// `bailian_*` → Bailian realtime, `soniox_*` → Soniox.
  String get provider => name.startsWith('soniox') ? 'soniox' : 'bailian';

  List<dynamic> list(String key) => (json[key] as List?) ?? const [];
  bool get dropAfterDuring => json['drop_after_during'] == true;

  /// DEBUG builds only: the fixture named by the launch argument
  /// `-ShinsokuSceneLiveFixture <name>` (read by the host, DEBUG only), or
  /// null. Release builds never ask and never replay (`kDebugMode` is a
  /// compile-time false there, so this code and the fixtures are dropped).
  static Future<LiveFixture?> fromLaunchArgument() async {
    if (!kDebugMode) return null;
    try {
      final name = await const MethodChannel(
        'net.potafree.shinsoku/keyboard_bridge',
      ).invokeMethod<String>('sceneLiveFixture');
      return name == null ? null : named(name);
    } catch (_) {
      return null;
    }
  }

  static LiveFixture? named(String name) {
    if (!kDebugMode) return null;
    final raw = debugLiveFixtures[name];
    if (raw == null) return null;
    return LiveFixture(name, jsonDecode(raw) as Map<String, dynamic>);
  }
}

/// DEBUG: the next recordings replay [fixture] through the real
/// [RealTranscriptionService] (same session, trackers and phases as a real
/// provider) instead of the microphone and the network. `during` messages
/// arrive one every [interval]; Stop sends whatever is left, then
/// `on_finish`.
class LiveFixturePipeline implements RecordingPipeline {
  LiveFixturePipeline(
    this.fixture, {
    this.interval = const Duration(milliseconds: 450),
  }) : _socket = _ReplaySocket(fixture, interval) {
    service = RealTranscriptionService(
      settings: ProviderSettings.defaults().copyWith(
        speechProvider: fixture.provider,
        bailianAsrMode: bailianAsrModeRealtime,
        textTransformEnabled: false,
        bailianApiKey: 'example-key',
        sonioxApiKey: 'example-key',
        bailianRealtimeUrl: 'wss://example-provider.invalid/ws',
      ),
      connect: _socket.connect,
    );
  }

  final LiveFixture fixture;
  final Duration interval;
  final _ReplaySocket _socket;
  late final RealTranscriptionService service;
  LiveAsrSession? _session;

  @override
  ValueListenable<LiveTranscript> get live => service.live;

  @override
  Future<void> start() async {
    _session = await service.startLiveSession();
    _socket.startDuring();
  }

  @override
  Future<RealTranscriptionResult> stop(VoiceProfile profile) async {
    final session = _session;
    if (session == null) throw StateError('The fixture never started.');
    _socket.flushDuring();
    return service.finishLiveSession(session: session, profile: profile);
  }

  @override
  Future<void> dispose() async {
    _socket.cancel();
    await _session?.close();
    service.dispose();
  }
}

class _ReplaySocket implements LiveSocket {
  _ReplaySocket(this.fixture, this.interval);

  final LiveFixture fixture;
  final Duration interval;
  final _controller = StreamController<dynamic>();
  var _textMessages = 0;
  var _next = 0;
  Timer? _timer;

  LiveSocket connect(Uri uri, {Map<String, String>? headers}) => this;

  @override
  Stream<dynamic> get stream => _controller.stream;

  void startDuring() {
    _timer = Timer.periodic(interval, (_) => _emitNext());
  }

  void _emitNext() {
    final during = fixture.list('during');
    if (_next < during.length) {
      _add(during[_next++]);
      return;
    }
    _timer?.cancel();
    if (fixture.dropAfterDuring && !_controller.isClosed) {
      unawaited(_controller.close());
    }
  }

  /// Stop: what the provider still had in flight arrives before the result.
  void flushDuring() {
    _timer?.cancel();
    final during = fixture.list('during');
    while (_next < during.length) {
      _add(during[_next++]);
    }
    if (fixture.dropAfterDuring && !_controller.isClosed) {
      unawaited(_controller.close());
    }
  }

  void cancel() => _timer?.cancel();

  void _add(dynamic message) {
    if (!_controller.isClosed) _controller.add(jsonEncode(message));
  }

  @override
  void send(Object data) {
    if (data is! String) return;
    _textMessages++;
    if (_textMessages == 1) {
      for (final m in fixture.list('on_start')) {
        _add(m);
      }
    } else if (_isFinish(data)) {
      for (final m in fixture.list('on_finish')) {
        _add(m);
      }
      if (!_controller.isClosed) scheduleMicrotask(_controller.close);
    }
  }

  static bool _isFinish(String data) {
    if (data.isEmpty) return true;
    final decoded = jsonDecode(data);
    return decoded is Map &&
        (decoded['header'] as Map?)?['action'] == 'finish-task';
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
  }
}
