import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:shinsoku_mobile/services/capture_types.dart';
import 'package:shinsoku_mobile/services/live_transcript.dart';
import 'package:shinsoku_mobile/services/wav.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';

class RealTranscriptionResult {
  const RealTranscriptionResult({
    required this.text,
    required this.provider,
    required this.detail,
    this.postProcessTimedOut = false,
  });

  final String text;
  final String provider;
  final String detail;
  final bool postProcessTimedOut;
}

class _PostProcessResult {
  const _PostProcessResult({required this.text, required this.timedOut});

  final String text;
  final bool timedOut;
}

const bailianRealtimeAudioChunkMs = 100;
const bailianRealtimeSendDelay = Duration(milliseconds: 10);
const bailianRealtimeSampleRate = 16000;
const bailianRealtimeChannels = 1;
const bailianRealtimeBytesPerSample = 2;
const bailianRealtimeStreamBufferSize =
    bailianRealtimeSampleRate *
    bailianRealtimeChannels *
    bailianRealtimeBytesPerSample ~/
    10;
const _postProcessTimeout = Duration(seconds: 8);
const bailianAsrModeRealtime = 'realtime';
const bailianAsrModeQwen = 'qwen';

/// A provider session that receives PCM while the user records and reports live text.
///
/// Phases reported through [onUpdate]: connecting → listening → finishing, or failed (committed kept).
/// The service that finishes the session reports processing / done.
abstract class LiveAsrSession {
  String get provider;

  /// The latest live state of this session.
  LiveTranscript get current;

  /// Called on every change of [current]. May be replaced (the service attaches itself).
  ValueChanged<LiveTranscript>? onUpdate;

  void addPcm(Uint8List chunk);

  /// Ends the audio and waits for the provider's final result (raw text, no post-processing).
  /// Throws when the session failed; [current] then still holds the committed text.
  Future<RealTranscriptionResult> finish();

  Future<void> close();
}

abstract class _SocketLiveSession implements LiveAsrSession {
  _SocketLiveSession(this.socket, {this.onUpdate});

  final LiveSocket socket;
  @override
  ValueChanged<LiveTranscript>? onUpdate;

  final finished = Completer<void>();
  final totalWatch = Stopwatch()..start();
  final finishWatch = Stopwatch();
  StreamSubscription<dynamic>? subscription;
  var bytesSent = 0;
  var finishSent = false;
  var closed = false;
  Object? failure;
  LiveTranscript _current = const LiveTranscript(phase: LivePhase.connecting);

  @override
  LiveTranscript get current => _current;

  String get committedText;
  String get pendingText;

  void emit({LivePhase? phase, String? error}) {
    final next = _current.copyWith(
      committed: committedText,
      pending: pendingText,
      phase: phase,
      error: error,
    );
    if (next == _current) {
      return;
    }
    _current = next;
    onUpdate?.call(next);
  }

  void fail(Object error, [StackTrace? stackTrace]) {
    if (failure != null) {
      return;
    }
    failure = error;
    emit(phase: LivePhase.failed, error: error.toString());
    onFailed(error, stackTrace);
    if (!finished.isCompleted) {
      finished.completeError(error, stackTrace);
      // Nobody may be waiting yet (the user is still talking); finish() rethrows it.
      finished.future.ignore();
    }
  }

  void onFailed(Object error, StackTrace? stackTrace) {}

  void listen() {
    subscription = socket.stream.listen(
      (message) {
        if (message is! String || failure != null) {
          return;
        }
        final Object? decoded;
        try {
          decoded = jsonDecode(message);
        } on FormatException catch (error, stackTrace) {
          fail(error, stackTrace);
          return;
        }
        if (decoded is Map<String, dynamic>) {
          onMessage(decoded);
        }
      },
      onError: (Object error, StackTrace stackTrace) => fail(error, stackTrace),
      onDone: () {
        if (!finished.isCompleted) {
          fail(StateError('$provider connection closed before the result.'));
        }
      },
    );
  }

  void onMessage(Map<String, dynamic> message);

  @override
  void addPcm(Uint8List chunk) {
    if (closed || finishSent || failure != null || chunk.isEmpty) {
      return;
    }
    socket.send(chunk);
    bytesSent += chunk.length;
  }

  void sendFinish();

  Duration get finishTimeout;

  String resultDetail();

  @override
  Future<RealTranscriptionResult> finish() async {
    if (failure == null && !finishSent && !closed) {
      finishSent = true;
      finishWatch.start();
      emit(phase: LivePhase.finishing);
      sendFinish();
    }
    try {
      await finished.future.timeout(finishTimeout);
    } on TimeoutException catch (error, stackTrace) {
      fail(error, stackTrace);
      rethrow;
    } finally {
      finishWatch.stop();
      totalWatch.stop();
      await close();
    }
    return RealTranscriptionResult(
      text: '$committedText$pendingText'.trim(),
      provider: provider,
      detail: resultDetail(),
    );
  }

  @override
  Future<void> close() async {
    if (closed) {
      return;
    }
    closed = true;
    await subscription?.cancel();
    await socket.close();
  }
}

class BailianRealtimeLiveSession extends _SocketLiveSession {
  BailianRealtimeLiveSession._(
    super.socket, {
    required this.taskId,
    super.onUpdate,
  });

  final String taskId;
  final tracker = BailianSentenceTracker();
  final started = Completer<void>();
  final startWatch = Stopwatch()..start();

  @override
  String get provider => 'Bailian';
  @override
  String get committedText => tracker.committed;
  @override
  String get pendingText => tracker.pending;
  @override
  Duration get finishTimeout => const Duration(seconds: 45);

  static Future<BailianRealtimeLiveSession> start(
    ProviderSettings settings, {
    LiveSocketConnector connect = connectIoLiveSocket,
    ValueChanged<LiveTranscript>? onUpdate,
    int sampleRate = bailianRealtimeSampleRate,
  }) async {
    final taskId = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final socket = connect(
      Uri.parse(settings.bailianRealtimeUrl),
      headers: {
        'Authorization': 'Bearer ${settings.bailianApiKey}',
        'user-agent': 'Shinsoku-Mobile/1.0',
      },
    );
    final session = BailianRealtimeLiveSession._(
      socket,
      taskId: taskId,
      onUpdate: onUpdate,
    );
    onUpdate?.call(session.current);
    session.listen();
    socket.send(
      jsonEncode({
        'header': {
          'action': 'run-task',
          'task_id': taskId,
          'streaming': 'duplex',
        },
        'payload': {
          'task_group': 'audio',
          'task': 'asr',
          'function': 'recognition',
          'model': settings.bailianRealtimeModel,
          'parameters': {'format': 'pcm', 'sample_rate': sampleRate},
          'input': <String, dynamic>{},
        },
      }),
    );
    try {
      await session.started.future.timeout(const Duration(seconds: 20));
    } catch (error, stackTrace) {
      session.fail(error, stackTrace);
      await session.close();
      rethrow;
    }
    return session;
  }

  @override
  void onFailed(Object error, StackTrace? stackTrace) {
    if (!started.isCompleted) {
      started.completeError(error, stackTrace);
    }
  }

  @override
  void onMessage(Map<String, dynamic> message) {
    final header = message['header'] as Map<String, dynamic>? ?? const {};
    switch (header['event']) {
      case 'task-failed':
        fail(
          StateError(
            header['error_message']?.toString() ?? 'Bailian task failed.',
          ),
        );
      case 'task-started':
        if (!started.isCompleted) {
          startWatch.stop();
          started.complete();
          emit(phase: LivePhase.listening);
        }
      case 'result-generated':
        final sentence =
            ((message['payload'] as Map?)?['output'] as Map?)?['sentence'];
        if (sentence is Map && tracker.apply(sentence)) {
          emit();
        }
      case 'task-finished':
        if (!finished.isCompleted) {
          finished.complete();
        }
    }
  }

  @override
  void sendFinish() {
    socket.send(
      jsonEncode({
        'header': {
          'action': 'finish-task',
          'task_id': taskId,
          'streaming': 'duplex',
        },
        'payload': {'input': <String, dynamic>{}},
      }),
    );
  }

  @override
  String resultDetail() {
    final audioMs = (bytesSent * 1000 / (bailianRealtimeSampleRate * 2))
        .round();
    return 'Realtime streaming ASR completed with $bytesSent PCM bytes '
        '(audio=${audioMs}ms, start=${startWatch.elapsedMilliseconds}ms, '
        'finish=${finishWatch.elapsedMilliseconds}ms, '
        'total=${totalWatch.elapsedMilliseconds}ms).';
  }
}

const sonioxRealtimeUrl = 'wss://stt-rt.soniox.com/transcribe-websocket';

class SonioxLiveSession extends _SocketLiveSession {
  SonioxLiveSession._(super.socket, {super.onUpdate});

  final tracker = SonioxTokenTracker();

  @override
  String get provider => 'Soniox';
  @override
  String get committedText => tracker.committed;
  @override
  String get pendingText => tracker.pending;
  @override
  Duration get finishTimeout => const Duration(seconds: 90);

  /// [audioFormat] `pcm_s16le` streams raw PCM while recording; `wav` uploads a finished file.
  static Future<SonioxLiveSession> start(
    ProviderSettings settings, {
    LiveSocketConnector connect = connectIoLiveSocket,
    ValueChanged<LiveTranscript>? onUpdate,
    String audioFormat = 'pcm_s16le',
    int sampleRate = bailianRealtimeSampleRate,
    int numChannels = bailianRealtimeChannels,
  }) async {
    final socket = connect(Uri.parse(sonioxRealtimeUrl));
    final session = SonioxLiveSession._(socket, onUpdate: onUpdate);
    onUpdate?.call(session.current);
    session.listen();
    socket.send(
      jsonEncode({
        'api_key': settings.sonioxApiKey,
        'model': settings.sonioxModel,
        'audio_format': audioFormat,
        if (audioFormat != 'wav') ...{
          'sample_rate': sampleRate,
          'num_channels': numChannels,
        },
        'enable_endpoint_detection': true,
        'max_endpoint_delay_ms': 900,
        'client_reference_id': 'shinsoku-mobile-live-recording',
      }),
    );
    // Soniox sends no start acknowledgement; audio may follow the config right away.
    session.emit(phase: LivePhase.listening);
    return session;
  }

  @override
  void onMessage(Map<String, dynamic> message) {
    final errorMessage = message['error_message'];
    if (errorMessage is String && errorMessage.isNotEmpty) {
      fail(StateError(errorMessage));
      return;
    }
    final tokens = message['tokens'];
    if (tokens is List && tracker.apply(tokens)) {
      emit();
    }
    if (message['finished'] == true && !finished.isCompleted) {
      finished.complete();
    }
  }

  @override
  void sendFinish() => socket.send('');

  @override
  String resultDetail() =>
      'Sent $bytesSent bytes and received a finished result '
      '(finish=${finishWatch.elapsedMilliseconds}ms, '
      'total=${totalWatch.elapsedMilliseconds}ms).';
}

class RealTranscriptionService {
  RealTranscriptionService({
    required this.settings,
    LiveSocketConnector connect = connectIoLiveSocket,
    http.Client Function()? httpClient,
  }) : _connect = connect,
       _httpClient = httpClient ?? http.Client.new;

  final ProviderSettings settings;
  final LiveSocketConnector _connect;
  final http.Client Function() _httpClient;
  final _live = ValueNotifier<LiveTranscript>(LiveTranscript.idle);

  /// Pinned phase while a finished recording is uploaded (batch path): provider text still flows in, the
  /// phase stays [LivePhase.finishing].
  LivePhase? _pinnedPhase;

  /// Live text of the current recording. One service instance serves one recording at a time.
  ValueListenable<LiveTranscript> get live => _live;

  /// Whether the selected provider shows words while the user speaks.
  bool get streamsLive =>
      settings.speechProvider == 'soniox' ||
      (settings.speechProvider == 'bailian' &&
          settings.bailianAsrMode == bailianAsrModeRealtime);

  /// Back to [LiveTranscript.idle] (before a new recording).
  void reset() {
    _pinnedPhase = null;
    _live.value = LiveTranscript.idle;
  }

  /// Batch providers: the recording started; no words until the result.
  void beginBatchListening() {
    _pinnedPhase = null;
    _live.value = const LiveTranscript(phase: LivePhase.listening);
  }

  void dispose() => _live.dispose();

  void _forward(LiveTranscript update) {
    final current = _live.value.phase;
    if (current == LivePhase.processing || current == LivePhase.done) {
      return;
    }
    final pinned = _pinnedPhase;
    _live.value = pinned != null && update.phase != LivePhase.failed
        ? update.copyWith(phase: pinned)
        : update;
  }

  void _failLive(Object error) {
    if (_live.value.phase == LivePhase.failed) {
      return;
    }
    _live.value = _live.value.copyWith(
      phase: LivePhase.failed,
      error: error.toString(),
    );
  }

  /// Streaming providers: opens the provider session; feed it PCM while recording, then call
  /// [finishLiveSession].
  Future<LiveAsrSession> startLiveSession() async {
    reset();
    if (!settings.activeProviderConfigured) {
      final error = StateError(
        'Provider credentials are missing. Save them in Settings first.',
      );
      _failLive(error);
      throw error;
    }
    try {
      return settings.speechProvider == 'soniox'
          ? await SonioxLiveSession.start(
              settings,
              connect: _connect,
              onUpdate: _forward,
            )
          : await BailianRealtimeLiveSession.start(
              settings,
              connect: _connect,
              onUpdate: _forward,
            );
    } catch (error) {
      _failLive(error);
      rethrow;
    }
  }

  Future<RealTranscriptionResult> finishLiveSession({
    required LiveAsrSession session,
    required VoiceProfile profile,
  }) async {
    final wallWatch = Stopwatch()..start();
    session.onUpdate = _forward;
    _forward(session.current);
    final rawWatch = Stopwatch()..start();
    try {
      final raw = await session.finish();
      rawWatch.stop();
      return await _completeResult(
        raw,
        profile,
        timing:
            'finishRaw=${rawWatch.elapsedMilliseconds}ms '
            'serviceTotal=${wallWatch.elapsedMilliseconds}ms',
      );
    } catch (error) {
      _failLive(error);
      rethrow;
    }
  }

  /// Kept for the current shell; same as [finishLiveSession].
  Future<RealTranscriptionResult> finishBailianRealtimeSession({
    required BailianRealtimeLiveSession session,
    required VoiceProfile profile,
  }) => finishLiveSession(session: session, profile: profile);

  /// Batch path: transcribes a finished WAV recording.
  Future<RealTranscriptionResult> transcribe({
    required Uint8List wavBytes,
    required VoiceProfile profile,
  }) async {
    final wallWatch = Stopwatch()..start();
    _pinnedPhase = LivePhase.finishing;
    _live.value = const LiveTranscript(phase: LivePhase.finishing);
    try {
      if (!settings.activeProviderConfigured) {
        throw StateError(
          'Provider credentials are missing. Save them in Settings first.',
        );
      }
      final rawWatch = Stopwatch()..start();
      final raw = switch (settings.speechProvider) {
        'soniox' => await _transcribeWithSoniox(wavBytes),
        _ =>
          settings.bailianAsrMode == bailianAsrModeQwen
              ? await _transcribeWithBailianQwenAsr(wavBytes)
              : await _transcribeWithBailianRealtime(wavBytes),
      };
      rawWatch.stop();
      return await _completeResult(
        raw,
        profile,
        timing:
            'raw=${rawWatch.elapsedMilliseconds}ms '
            'serviceTotal=${wallWatch.elapsedMilliseconds}ms',
      );
    } catch (error) {
      _failLive(error);
      rethrow;
    } finally {
      _pinnedPhase = null;
    }
  }

  /// Raw provider text → (processing →) done. The processed text replaces the raw text once (L2).
  Future<RealTranscriptionResult> _completeResult(
    RealTranscriptionResult raw,
    VoiceProfile profile, {
    required String timing,
  }) async {
    var text = raw.text.trim();
    if (text.isEmpty) {
      throw StateError('${raw.provider} returned no transcript.');
    }

    var detail = raw.detail;
    var postProcessTimedOut = false;
    if (settings.textTransformEnabled &&
        settings.bailianApiKey.trim().isNotEmpty) {
      _live.value = LiveTranscript(
        committed: text,
        phase: LivePhase.processing,
      );
      final postWatch = Stopwatch()..start();
      final postProcessed = await _postProcess(text, profile);
      postWatch.stop();
      text = postProcessed.text;
      postProcessTimedOut = postProcessed.timedOut;
      detail =
          '$detail postProcess=${postWatch.elapsedMilliseconds}ms'
          '${postProcessed.timedOut ? " timeoutFallback=true" : ""}';
    }
    _live.value = LiveTranscript(committed: text, phase: LivePhase.done);

    return RealTranscriptionResult(
      text: _applySuffix(text, profile.commitSuffix),
      provider: raw.provider,
      detail: '$detail $timing',
      postProcessTimedOut: postProcessTimedOut,
    );
  }

  Future<RealTranscriptionResult> _transcribeWithSoniox(Uint8List audio) async {
    final session = await SonioxLiveSession.start(
      settings,
      connect: _connect,
      onUpdate: _forward,
      audioFormat: 'wav',
    );
    try {
      const chunkSize = 8192;
      for (var offset = 0; offset < audio.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, audio.length);
        session.addPcm(audio.sublist(offset, end));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return await session.finish();
    } finally {
      await session.close();
    }
  }

  Future<RealTranscriptionResult> _transcribeWithBailianRealtime(
    Uint8List wavBytes,
  ) async {
    final wav = parseWavPcm16(wavBytes);
    final session = await BailianRealtimeLiveSession.start(
      settings,
      connect: _connect,
      onUpdate: _forward,
      sampleRate: wav.sampleRate,
    );
    try {
      final uploadWatch = Stopwatch()..start();
      final chunkSize =
          (wav.sampleRate * 2 * bailianRealtimeAudioChunkMs / 1000).round();
      for (var offset = 0; offset < wav.pcm.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, wav.pcm.length);
        session.addPcm(wav.pcm.sublist(offset, end));
        await Future<void>.delayed(bailianRealtimeSendDelay);
      }
      uploadWatch.stop();
      final raw = await session.finish();
      return RealTranscriptionResult(
        text: raw.text,
        provider: raw.provider,
        detail: '${raw.detail} upload=${uploadWatch.elapsedMilliseconds}ms',
      );
    } finally {
      await session.close();
    }
  }

  Future<RealTranscriptionResult> _transcribeWithBailianQwenAsr(
    Uint8List wavBytes,
  ) async {
    final watch = Stopwatch()..start();
    final client = _httpClient();
    try {
      final dataUrl = 'data:audio/wav;base64,${base64Encode(wavBytes)}';
      final response = await client
          .post(
            _bailianEndpoint('/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${settings.bailianApiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': settings.bailianAsrModel,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'input_audio',
                      'input_audio': {'data': dataUrl},
                    },
                  ],
                },
              ],
              'stream': false,
              'asr_options': {'enable_itn': false},
            }),
          )
          .timeout(const Duration(seconds: 45));
      watch.stop();
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'];
        throw StateError(
          error is Map && error['message'] is String
              ? error['message'] as String
              : 'HTTP ${response.statusCode}',
        );
      }
      final content =
          (((decoded['choices'] as List?)?.firstOrNull as Map?)?['message']
                  as Map?)?['content']
              as String?;
      return RealTranscriptionResult(
        text: content?.trim() ?? '',
        provider: 'Bailian Qwen-ASR',
        detail:
            'Qwen-ASR batch completed with ${wavBytes.length} WAV bytes '
            '(total=${watch.elapsedMilliseconds}ms).',
      );
    } finally {
      client.close();
    }
  }

  Future<_PostProcessResult> _postProcess(
    String transcript,
    VoiceProfile profile,
  ) async {
    final client = _httpClient();
    try {
      final response = await client
          .post(
            _bailianEndpoint('/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${settings.bailianApiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': settings.bailianTextModel,
              'messages': [
                {
                  'role': 'system',
                  'content': '${profile.intent}\nReturn only the final text.',
                },
                {'role': 'user', 'content': transcript},
              ],
              'enable_thinking': false,
              'temperature': 0,
            }),
          )
          .timeout(_postProcessTimeout);
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'];
        throw StateError(
          error is Map && error['message'] is String
              ? error['message'] as String
              : 'HTTP ${response.statusCode}',
        );
      }
      final content =
          (((decoded['choices'] as List?)?.firstOrNull as Map?)?['message']
                  as Map?)?['content']
              as String?;
      return _PostProcessResult(
        text: content?.trim().isNotEmpty == true ? content!.trim() : transcript,
        timedOut: false,
      );
    } on TimeoutException {
      return _PostProcessResult(text: transcript, timedOut: true);
    } finally {
      client.close();
    }
  }

  Uri _bailianEndpoint(String path) {
    final base = settings.bailianApiBase.endsWith('/')
        ? settings.bailianApiBase.substring(
            0,
            settings.bailianApiBase.length - 1,
          )
        : settings.bailianApiBase;
    return Uri.parse('$base$path');
  }

  String _applySuffix(String text, CommitSuffix suffix) {
    final trimmed = text.trim();
    return switch (suffix) {
      CommitSuffix.none => trimmed,
      CommitSuffix.space => '$trimmed ',
      CommitSuffix.newline => '$trimmed\n',
    };
  }
}
