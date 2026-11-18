import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

import 'package:shinsoku_mobile/services/capture_types.dart';
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

class _BailianRealtimeTiming {
  const _BailianRealtimeTiming({
    required this.audioMs,
    required this.startMs,
    required this.uploadMs,
    required this.finishMs,
    required this.totalMs,
  });

  final int audioMs;
  final int startMs;
  final int uploadMs;
  final int finishMs;
  final int totalMs;

  String toDetail({required int bytes}) {
    return 'Realtime ASR completed with $bytes PCM bytes '
        '(audio=${audioMs}ms, start=${startMs}ms, upload=${uploadMs}ms, '
        'finish=${finishMs}ms, total=${totalMs}ms).';
  }
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

class BailianRealtimeLiveSession {
  BailianRealtimeLiveSession._({
    required this.taskId,
    required this.channel,
    required this.subscription,
    required this.started,
    required this.finished,
    required this.sentences,
    required this.startWatch,
    required this.totalWatch,
  });

  final String taskId;
  final IOWebSocketChannel channel;
  final StreamSubscription<dynamic> subscription;
  final Completer<void> started;
  final Completer<void> finished;
  final Map<int, String> sentences;
  final Stopwatch startWatch;
  final Stopwatch totalWatch;
  final Stopwatch finishWatch = Stopwatch();
  var bytesSent = 0;
  var _finishSent = false;
  var _closed = false;

  static Future<BailianRealtimeLiveSession> start(
    ProviderSettings settings,
  ) async {
    final totalWatch = Stopwatch()..start();
    final startWatch = Stopwatch()..start();
    final taskId = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final channel = IOWebSocketChannel.connect(
      Uri.parse(settings.bailianRealtimeUrl),
      headers: {
        'Authorization': 'Bearer ${settings.bailianApiKey}',
        'user-agent': 'Shinsoku-Mobile/1.0',
      },
    );

    final started = Completer<void>();
    final finished = Completer<void>();
    final sentences = <int, String>{};
    late final StreamSubscription<dynamic> subscription;
    subscription = channel.stream.listen(
      (message) {
        if (message is! String) {
          return;
        }
        final decoded = jsonDecode(message) as Map<String, dynamic>;
        final header = decoded['header'] as Map<String, dynamic>? ?? {};
        final event = header['event'];
        if (event == 'task-failed') {
          final error = StateError(
            header['error_message']?.toString() ?? 'Bailian task failed.',
          );
          if (!started.isCompleted) {
            started.completeError(error);
          }
          if (!finished.isCompleted) {
            finished.completeError(error);
          }
          return;
        }
        if (event == 'task-started' && !started.isCompleted) {
          startWatch.stop();
          started.complete();
          return;
        }
        if (event == 'result-generated') {
          final sentence =
              (((decoded['payload'] as Map?)?['output'] as Map?)?['sentence']
                  as Map?) ??
              {};
          final id = sentence['sentence_id'];
          final text = sentence['text'];
          if (id is int && text is String && text.isNotEmpty) {
            sentences[id] = text;
          }
          return;
        }
        if (event == 'task-finished' && !finished.isCompleted) {
          finished.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!started.isCompleted) {
          started.completeError(error, stackTrace);
        }
        if (!finished.isCompleted) {
          finished.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!finished.isCompleted) {
          finished.complete();
        }
      },
    );

    final session = BailianRealtimeLiveSession._(
      taskId: taskId,
      channel: channel,
      subscription: subscription,
      started: started,
      finished: finished,
      sentences: sentences,
      startWatch: startWatch,
      totalWatch: totalWatch,
    );
    channel.sink.add(
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
          'parameters': {
            'format': 'pcm',
            'sample_rate': bailianRealtimeSampleRate,
          },
          'input': <String, dynamic>{},
        },
      }),
    );
    try {
      await started.future.timeout(const Duration(seconds: 20));
    } catch (_) {
      await session.close();
      rethrow;
    }
    return session;
  }

  void addPcm(Uint8List chunk) {
    if (_closed || _finishSent || chunk.isEmpty) {
      return;
    }
    channel.sink.add(chunk);
    bytesSent += chunk.length;
  }

  Future<RealTranscriptionResult> finish() async {
    if (!_finishSent) {
      _finishSent = true;
      finishWatch.start();
      channel.sink.add(
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
    try {
      await finished.future.timeout(const Duration(seconds: 45));
    } finally {
      finishWatch.stop();
      totalWatch.stop();
      await close();
    }

    final ordered = sentences.keys.toList()..sort();
    final text = ordered.map((id) => sentences[id]!).join().trim();
    final audioMs = (bytesSent * 1000 / (bailianRealtimeSampleRate * 2))
        .round();
    return RealTranscriptionResult(
      text: text,
      provider: 'Bailian',
      detail:
          'Realtime streaming ASR completed with $bytesSent PCM bytes '
          '(audio=${audioMs}ms, start=${startWatch.elapsedMilliseconds}ms, '
          'finish=${finishWatch.elapsedMilliseconds}ms, '
          'total=${totalWatch.elapsedMilliseconds}ms).',
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await subscription.cancel();
    await channel.sink.close();
  }
}

class RealTranscriptionService {
  RealTranscriptionService({required this.settings});

  final ProviderSettings settings;

  Future<RealTranscriptionResult> transcribe({
    required Uint8List wavBytes,
    required VoiceProfile profile,
  }) async {
    final wallWatch = Stopwatch()..start();
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
    var text = raw.text.trim();
    if (text.isEmpty) {
      throw StateError('${raw.provider} returned no transcript.');
    }

    var detail = raw.detail;
    var postProcessTimedOut = false;
    if (settings.textTransformEnabled &&
        settings.bailianApiKey.trim().isNotEmpty) {
      final postWatch = Stopwatch()..start();
      final postProcessed = await _postProcess(text, profile);
      postWatch.stop();
      text = postProcessed.text;
      postProcessTimedOut = postProcessed.timedOut;
      detail =
          '$detail postProcess=${postWatch.elapsedMilliseconds}ms'
          '${postProcessed.timedOut ? " timeoutFallback=true" : ""}';
    }
    wallWatch.stop();

    return RealTranscriptionResult(
      text: _applySuffix(text, profile.commitSuffix),
      provider: raw.provider,
      detail:
          '$detail raw=${rawWatch.elapsedMilliseconds}ms '
          'serviceTotal=${wallWatch.elapsedMilliseconds}ms',
      postProcessTimedOut: postProcessTimedOut,
    );
  }

  Future<RealTranscriptionResult> finishBailianRealtimeSession({
    required BailianRealtimeLiveSession session,
    required VoiceProfile profile,
  }) async {
    final wallWatch = Stopwatch()..start();
    final rawWatch = Stopwatch()..start();
    var raw = await session.finish();
    rawWatch.stop();
    var text = raw.text.trim();
    if (text.isEmpty) {
      throw StateError('${raw.provider} returned no transcript.');
    }

    var detail = raw.detail;
    var postProcessTimedOut = false;
    if (settings.textTransformEnabled &&
        settings.bailianApiKey.trim().isNotEmpty) {
      final postWatch = Stopwatch()..start();
      final postProcessed = await _postProcess(text, profile);
      postWatch.stop();
      text = postProcessed.text;
      postProcessTimedOut = postProcessed.timedOut;
      detail =
          '$detail postProcess=${postWatch.elapsedMilliseconds}ms'
          '${postProcessed.timedOut ? " timeoutFallback=true" : ""}';
    }
    wallWatch.stop();

    return RealTranscriptionResult(
      text: _applySuffix(text, profile.commitSuffix),
      provider: raw.provider,
      detail:
          '$detail finishRaw=${rawWatch.elapsedMilliseconds}ms '
          'serviceTotal=${wallWatch.elapsedMilliseconds}ms',
      postProcessTimedOut: postProcessTimedOut,
    );
  }

  Future<RealTranscriptionResult> _transcribeWithSoniox(Uint8List audio) async {
    final channel = IOWebSocketChannel.connect(
      Uri.parse('wss://stt-rt.soniox.com/transcribe-websocket'),
    );
    final transcript = StringBuffer();
    final resultCompleter = Completer<RealTranscriptionResult>();
    var latestTranscript = '';
    var bytesSent = 0;

    RealTranscriptionResult currentResult({required bool partial}) {
      final finalTranscript = _cleanSonioxTranscript(transcript.toString());
      final text = finalTranscript.isNotEmpty
          ? finalTranscript
          : _cleanSonioxTranscript(latestTranscript);
      return RealTranscriptionResult(
        text: text,
        provider: 'Soniox',
        detail: partial
            ? 'Received realtime tokens after sending $bytesSent bytes.'
            : 'Sent $bytesSent bytes and received a finished result.',
      );
    }

    late final StreamSubscription<dynamic> subscription;
    subscription = channel.stream.listen(
      (message) {
        if (message is! String) {
          return;
        }

        final decoded = jsonDecode(message) as Map<String, dynamic>;
        final errorMessage = decoded['error_message'];
        if (errorMessage is String && errorMessage.isNotEmpty) {
          if (!resultCompleter.isCompleted) {
            final current = currentResult(partial: true);
            if (current.text.isNotEmpty) {
              resultCompleter.complete(current);
            } else {
              resultCompleter.completeError(StateError(errorMessage));
            }
          }
          return;
        }

        final tokens = decoded['tokens'];
        if (tokens is List) {
          final latest = StringBuffer();
          for (final token in tokens) {
            if (token is! Map<String, dynamic>) {
              continue;
            }
            final text = token['text'];
            if (text is String) {
              latest.write(text);
              if (token['is_final'] == true) {
                transcript.write(text);
              }
            }
          }
          if (latest.isNotEmpty) {
            latestTranscript = latest.toString();
          }
        }

        if (decoded['finished'] == true && !resultCompleter.isCompleted) {
          resultCompleter.complete(currentResult(partial: false));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!resultCompleter.isCompleted) {
          resultCompleter.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete(currentResult(partial: true));
        }
      },
    );

    try {
      channel.sink.add(
        jsonEncode({
          'api_key': settings.sonioxApiKey,
          'model': settings.sonioxModel,
          'audio_format': 'wav',
          'enable_endpoint_detection': true,
          'max_endpoint_delay_ms': 900,
          'client_reference_id': 'shinsoku-mobile-live-recording',
        }),
      );

      const chunkSize = 8192;
      for (var offset = 0; offset < audio.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, audio.length);
        final chunk = audio.sublist(offset, end);
        channel.sink.add(chunk);
        bytesSent += chunk.length;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      channel.sink.add('');

      return await resultCompleter.future.timeout(const Duration(seconds: 90));
    } finally {
      unawaited(subscription.cancel());
      unawaited(channel.sink.close());
    }
  }

  Future<RealTranscriptionResult> _transcribeWithBailianRealtime(
    Uint8List wavBytes,
  ) async {
    final totalWatch = Stopwatch()..start();
    final wav = parseWavPcm16(wavBytes);
    final audioMs = (wav.pcm.length * 1000 / (wav.sampleRate * 2)).round();
    final taskId = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final channel = IOWebSocketChannel.connect(
      Uri.parse(settings.bailianRealtimeUrl),
      headers: {
        'Authorization': 'Bearer ${settings.bailianApiKey}',
        'user-agent': 'Shinsoku-Mobile/1.0',
      },
    );

    final started = Completer<void>();
    final finished = Completer<void>();
    final sentences = <int, String>{};
    late final StreamSubscription<dynamic> subscription;
    subscription = channel.stream.listen(
      (message) {
        if (message is! String) {
          return;
        }
        final decoded = jsonDecode(message) as Map<String, dynamic>;
        final header = decoded['header'] as Map<String, dynamic>? ?? {};
        final event = header['event'];
        if (event == 'task-failed') {
          final error = StateError(
            header['error_message']?.toString() ?? 'Bailian task failed.',
          );
          if (!started.isCompleted) {
            started.completeError(error);
          }
          if (!finished.isCompleted) {
            finished.completeError(error);
          }
          return;
        }
        if (event == 'task-started' && !started.isCompleted) {
          started.complete();
          return;
        }
        if (event == 'result-generated') {
          final sentence =
              (((decoded['payload'] as Map?)?['output'] as Map?)?['sentence']
                  as Map?) ??
              {};
          final id = sentence['sentence_id'];
          final text = sentence['text'];
          if (id is int && text is String && text.isNotEmpty) {
            sentences[id] = text;
          }
          return;
        }
        if (event == 'task-finished' && !finished.isCompleted) {
          finished.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!started.isCompleted) {
          started.completeError(error, stackTrace);
        }
        if (!finished.isCompleted) {
          finished.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!finished.isCompleted) {
          finished.complete();
        }
      },
    );

    try {
      final startWatch = Stopwatch()..start();
      channel.sink.add(
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
            'parameters': {'format': 'pcm', 'sample_rate': wav.sampleRate},
            'input': <String, dynamic>{},
          },
        }),
      );
      await started.future.timeout(const Duration(seconds: 20));
      startWatch.stop();

      final uploadWatch = Stopwatch()..start();
      final chunkSize =
          (wav.sampleRate * 2 * bailianRealtimeAudioChunkMs / 1000).round();
      for (var offset = 0; offset < wav.pcm.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, wav.pcm.length);
        channel.sink.add(wav.pcm.sublist(offset, end));
        await Future<void>.delayed(bailianRealtimeSendDelay);
      }
      uploadWatch.stop();

      final finishWatch = Stopwatch()..start();
      channel.sink.add(
        jsonEncode({
          'header': {
            'action': 'finish-task',
            'task_id': taskId,
            'streaming': 'duplex',
          },
          'payload': {'input': <String, dynamic>{}},
        }),
      );
      await finished.future.timeout(const Duration(seconds: 45));
      finishWatch.stop();
      totalWatch.stop();
      final timing = _BailianRealtimeTiming(
        audioMs: audioMs,
        startMs: startWatch.elapsedMilliseconds,
        uploadMs: uploadWatch.elapsedMilliseconds,
        finishMs: finishWatch.elapsedMilliseconds,
        totalMs: totalWatch.elapsedMilliseconds,
      );
      final ordered = sentences.keys.toList()..sort();
      final text = ordered.map((id) => sentences[id]!).join().trim();
      return RealTranscriptionResult(
        text: text,
        provider: 'Bailian',
        detail: timing.toDetail(bytes: wav.pcm.length),
      );
    } finally {
      unawaited(subscription.cancel());
      unawaited(channel.sink.close());
    }
  }

  Future<RealTranscriptionResult> _transcribeWithBailianQwenAsr(
    Uint8List wavBytes,
  ) async {
    final watch = Stopwatch()..start();
    final client = http.Client();
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
    final client = http.Client();
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

  String _cleanSonioxTranscript(String value) {
    return value.replaceAll('<fin>', '').trim();
  }
}
