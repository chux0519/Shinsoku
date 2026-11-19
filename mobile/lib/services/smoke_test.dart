import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

import 'package:shinsoku_mobile/services/transcription_service.dart';
import 'package:shinsoku_mobile/services/wav.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';

/// Smoke runs read API keys from the saved provider settings (entered in Settings), never from
/// compile-time constants: no key may be compiled into the app binary (review rule R04).
class SmokeTestConfig {
  static const mode = String.fromEnvironment('SHINSOKU_SMOKE_TEST');
  static const bailianApiBase = String.fromEnvironment(
    'BAILIAN_API_BASE',
    defaultValue: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  );
  static const bailianOpenAiModel = String.fromEnvironment(
    'BAILIAN_OPENAI_MODEL',
    defaultValue: 'qwen-flash',
  );
  static const bailianAsrModel = String.fromEnvironment(
    'BAILIAN_OPENAI_ASR_MODEL',
    defaultValue: 'qwen3-asr-flash',
  );
  static const bailianRealtimeUrl = String.fromEnvironment(
    'BAILIAN_REALTIME_URL',
    defaultValue: 'wss://dashscope.aliyuncs.com/api-ws/v1/inference',
  );
  static const bailianRealtimeModel = String.fromEnvironment(
    'BAILIAN_REALTIME_MODEL',
    defaultValue: 'fun-asr-realtime',
  );
  static const bailianAsrAudioUrl = String.fromEnvironment(
    'BAILIAN_ASR_AUDIO_URL',
    defaultValue:
        'https://dashscope.oss-cn-beijing.aliyuncs.com/audios/welcome.mp3',
  );
  static const audioUrl = String.fromEnvironment(
    'SHINSOKU_SMOKE_AUDIO_URL',
    defaultValue:
        'https://raw.githubusercontent.com/mozilla/DeepSpeech/master/data/smoke_test/LDC93S1.wav',
  );
  static const audioFormat = String.fromEnvironment(
    'SHINSOKU_SMOKE_AUDIO_FORMAT',
    defaultValue: 'auto',
  );

  static bool get enabled => mode == 'soniox' || mode == 'bailian';
}

/// The fix a failed status offers (DESIGN §7: errors carry their fix).
enum StatusFix { none, microphone, providerSettings }

class SmokeTestStatus {
  const SmokeTestStatus({
    required this.label,
    required this.detail,
    this.transcript,
    this.failed = false,
    this.finished = false,
    this.fix = StatusFix.none,
  });

  final String label;
  final String detail;
  final String? transcript;
  final bool failed;
  final bool finished;
  final StatusFix fix;
}

class SonioxSmokeTestResult {
  const SonioxSmokeTestResult({
    required this.transcript,
    required this.bytesSent,
    required this.partial,
  });

  final String transcript;
  final int bytesSent;
  final bool partial;
}

class SonioxSmokeTestRunner {
  SonioxSmokeTestRunner({
    required this.apiKey,
    required this.audioUrl,
    required this.audioFormat,
    this.maxAudioBytes = 2097152,
  });

  final String apiKey;
  final String audioUrl;
  final String audioFormat;
  final int maxAudioBytes;

  Future<SonioxSmokeTestResult> run() async {
    if (apiKey.trim().isEmpty) {
      throw StateError('Missing Soniox API key: save it in Settings.');
    }

    final client = http.Client();
    late final Uint8List audioBytes;
    try {
      audioBytes = await _downloadAudio(client);
    } catch (_) {
      client.close();
      rethrow;
    }
    final channel = IOWebSocketChannel.connect(
      Uri.parse('wss://stt-rt.soniox.com/transcribe-websocket'),
    );
    final transcript = StringBuffer();
    final resultCompleter = Completer<SonioxSmokeTestResult>();
    var latestTranscript = '';
    var bytesSent = 0;

    SonioxSmokeTestResult currentResult({required bool partial}) {
      final finalTranscript = _cleanTranscript(transcript.toString());
      return SonioxSmokeTestResult(
        transcript: finalTranscript.isNotEmpty
            ? finalTranscript
            : _cleanTranscript(latestTranscript),
        bytesSent: bytesSent,
        partial: partial,
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
            if (current.transcript.isNotEmpty) {
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
            if (token['text'] is String) {
              latest.write(token['text'] as String);
            }
            if (token['is_final'] == true && token['text'] is String) {
              transcript.write(token['text'] as String);
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
          'api_key': apiKey,
          'model': 'stt-rt-v4',
          'audio_format': audioFormat,
          'enable_endpoint_detection': true,
          'max_endpoint_delay_ms': 500,
          'language_hints': ['en'],
          'client_reference_id': 'shinsoku-mobile-ios-simulator-smoke',
          'context': {
            'general': [
              {'key': 'domain', 'value': 'speech recognition test audio'},
            ],
            'text':
                'Open Speech Repository American English Harvard sentence recording.',
          },
        }),
      );

      const chunkSize = 8192;
      for (var offset = 0; offset < audioBytes.length; offset += chunkSize) {
        final remaining = maxAudioBytes - bytesSent;
        if (remaining <= 0) {
          break;
        }

        final end = (offset + chunkSize).clamp(0, audioBytes.length);
        final chunk = audioBytes.sublist(offset, end);
        final payload = remaining >= chunk.length
            ? chunk
            : Uint8List.fromList(chunk.take(remaining).toList());
        channel.sink.add(payload);
        bytesSent += payload.length;

        if (bytesSent >= maxAudioBytes) {
          break;
        }

        await Future<void>.delayed(const Duration(milliseconds: 35));
      }

      channel.sink.add(jsonEncode({'type': 'finalize'}));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      channel.sink.add(Uint8List(0));
      final result = await resultCompleter.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          final current = currentResult(partial: true);
          if (current.transcript.isNotEmpty) {
            return current;
          }
          throw TimeoutException('No Soniox transcript received.');
        },
      );
      if (result.transcript.isEmpty) {
        throw StateError('Soniox returned no transcript.');
      }
      return result;
    } finally {
      client.close();
      unawaited(subscription.cancel());
      unawaited(channel.sink.close());
    }
  }

  Future<Uint8List> _downloadAudio(http.Client client) async {
    final request = http.Request('GET', Uri.parse(audioUrl));
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Audio download failed: HTTP ${response.statusCode}.');
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      builder.add(chunk);
      if (builder.length >= maxAudioBytes) {
        break;
      }
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      throw StateError('Audio download returned no data.');
    }
    return bytes;
  }

  String _cleanTranscript(String value) {
    return value.replaceAll('<fin>', '').trim();
  }
}

class BailianSmokeStep {
  const BailianSmokeStep({
    required this.name,
    required this.passed,
    required this.detail,
  });

  final String name;
  final bool passed;
  final String detail;
}

class BailianSmokeTestResult {
  const BailianSmokeTestResult({required this.steps, required this.transcript});

  final List<BailianSmokeStep> steps;
  final String transcript;

  bool get passed => steps.every((step) => step.passed);
}

class BailianSmokeTestRunner {
  BailianSmokeTestRunner({
    required this.apiBase,
    required this.apiKey,
    required this.textModel,
    required this.asrModel,
    required this.asrAudioUrl,
    required this.realtimeUrl,
    required this.realtimeModel,
    required this.realtimeAudioUrl,
  });

  final String apiBase;
  final String apiKey;
  final String textModel;
  final String asrModel;
  final String asrAudioUrl;
  final String realtimeUrl;
  final String realtimeModel;
  final String realtimeAudioUrl;

  Future<BailianSmokeTestResult> run() async {
    if (apiKey.trim().isEmpty) {
      throw StateError('Missing Bailian API key: save it in Settings.');
    }

    final client = http.Client();
    final steps = <BailianSmokeStep>[];
    final transcript = StringBuffer();
    try {
      steps.add(await _runChatCompletion(client));
      steps.add(await _runChatStream(client));
      steps.add(await _runResponses(client));
      final asr = await _runQwenAsr(client);
      steps.add(asr.step);
      if (asr.text.isNotEmpty) {
        transcript.writeln('Qwen-ASR: ${asr.text}');
      }
      final localAsr = await _runQwenAsrDataUri(client);
      steps.add(localAsr.step);
      if (localAsr.text.isNotEmpty) {
        transcript.writeln('Qwen-ASR local: ${localAsr.text}');
      }
      final realtime = await _runRealtimeAsr(client);
      steps.add(realtime.step);
      if (realtime.text.isNotEmpty) {
        transcript.writeln('Fun-ASR: ${realtime.text}');
      }
      final translationInput = realtime.text.isNotEmpty
          ? realtime.text
          : 'She had your dark suit in greasy wash water all year.';
      final postProcess = await _runEnglishToChinesePostProcess(
        client,
        translationInput,
      );
      steps.add(postProcess.step);
      if (postProcess.text.isNotEmpty) {
        transcript.writeln('Post-process zh: ${postProcess.text}');
      }
    } finally {
      client.close();
    }

    final result = BailianSmokeTestResult(
      steps: steps,
      transcript: transcript.toString().trim(),
    );
    if (!result.passed) {
      final failed = result.steps.firstWhere((step) => !step.passed);
      throw StateError('${failed.name} failed: ${failed.detail}');
    }
    return result;
  }

  Future<BailianSmokeStep> _runChatCompletion(http.Client client) async {
    final response = await _postJson(client, '/chat/completions', {
      'model': textModel,
      'messages': [
        {'role': 'system', 'content': 'Return a compact JSON object only.'},
        {
          'role': 'user',
          'content': 'Respond with {"status":"ok","provider":"bailian"}.',
        },
      ],
      'temperature': 0,
    });
    final content =
        (((response['choices'] as List?)?.firstOrNull as Map?)?['message']
                as Map?)?['content']
            as String?;
    return BailianSmokeStep(
      name: 'Chat',
      passed: content != null && content.isNotEmpty,
      detail: content ?? 'empty response',
    );
  }

  Future<BailianSmokeStep> _runChatStream(http.Client client) async {
    final request = http.Request('POST', _endpoint('/chat/completions'))
      ..headers.addAll(_jsonHeaders)
      ..body = jsonEncode({
        'model': textModel,
        'messages': [
          {'role': 'user', 'content': '用四个字回答：百炼可用'},
        ],
        'stream': true,
        'temperature': 0,
      });
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return BailianSmokeStep(
        name: 'Chat stream',
        passed: false,
        detail: 'HTTP ${response.statusCode}',
      );
    }

    final content = StringBuffer();
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) {
        continue;
      }
      final data = line.substring(5).trim();
      if (data == '[DONE]') {
        break;
      }
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      final delta =
          ((decoded['choices'] as List?)?.firstOrNull as Map?)?['delta']
              as Map?;
      final piece = delta?['content'];
      if (piece is String) {
        content.write(piece);
      }
    }

    return BailianSmokeStep(
      name: 'Chat stream',
      passed: content.isNotEmpty,
      detail: content.toString().trim().isEmpty
          ? 'empty stream'
          : content.toString().trim(),
    );
  }

  Future<BailianSmokeStep> _runResponses(http.Client client) async {
    final response = await _postJson(client, '/responses', {
      'model': textModel,
      'input': 'Return exactly: Bailian responses ok',
      'temperature': 0,
    });
    final text = _responseOutputText(response);
    return BailianSmokeStep(
      name: 'Responses',
      passed: text.isNotEmpty,
      detail: text.isEmpty ? 'empty response' : text,
    );
  }

  Future<({BailianSmokeStep step, String text})> _runQwenAsr(
    http.Client client,
  ) async {
    final response = await _postJson(client, '/chat/completions', {
      'model': asrModel,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_audio',
              'input_audio': {'data': asrAudioUrl},
            },
          ],
        },
      ],
      'stream': false,
      'asr_options': {'enable_itn': false},
    }, timeout: const Duration(seconds: 120));
    final content =
        (((response['choices'] as List?)?.firstOrNull as Map?)?['message']
            as Map?)?['content'];
    final text = content is String ? content.trim() : '';
    return (
      step: BailianSmokeStep(
        name: 'Qwen-ASR',
        passed: text.isNotEmpty,
        detail: text.isEmpty ? 'empty transcript' : text,
      ),
      text: text,
    );
  }

  Future<({BailianSmokeStep step, String text})> _runRealtimeAsr(
    http.Client client,
  ) async {
    final audioBytes = await _downloadBytes(client, realtimeAudioUrl);
    final wav = parseWavPcm16(audioBytes);
    if (wav.sampleRate != bailianRealtimeSampleRate) {
      throw StateError(
        'Realtime ASR smoke audio must be ${bailianRealtimeSampleRate}Hz PCM.',
      );
    }

    final settings = ProviderSettings(
      speechProvider: 'bailian',
      textTransformEnabled: false,
      bailianAsrMode: bailianAsrModeRealtime,
      bailianApiBase: apiBase,
      bailianApiKey: apiKey,
      bailianTextModel: textModel,
      bailianAsrModel: asrModel,
      bailianRealtimeUrl: realtimeUrl,
      bailianRealtimeModel: realtimeModel,
      sonioxApiKey: '',
      sonioxModel: '',
    );
    final session = await BailianRealtimeLiveSession.start(settings);

    final uploadWatch = Stopwatch()..start();
    try {
      final chunkSize =
          (wav.sampleRate * 2 * bailianRealtimeAudioChunkMs / 1000).round();
      for (var offset = 0; offset < wav.pcm.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, wav.pcm.length);
        session.addPcm(wav.pcm.sublist(offset, end));
        await Future<void>.delayed(bailianRealtimeSendDelay);
      }
      uploadWatch.stop();
      final result = await session.finish();
      final detail =
          '${result.detail}, smokeUpload=${uploadWatch.elapsedMilliseconds}ms';
      return (
        step: BailianSmokeStep(
          name: 'Fun-ASR realtime',
          passed: result.text.isNotEmpty,
          detail: result.text.isEmpty
              ? 'empty transcript; $detail'
              : '${result.text}; $detail',
        ),
        text: result.text,
      );
    } catch (_) {
      await session.close();
      rethrow;
    }
  }

  Future<({BailianSmokeStep step, String text})> _runQwenAsrDataUri(
    http.Client client,
  ) async {
    final audioBytes = await _downloadBytes(client, realtimeAudioUrl);
    final dataUrl = 'data:audio/wav;base64,${base64Encode(audioBytes)}';
    final response = await _postJson(client, '/chat/completions', {
      'model': asrModel,
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
    }, timeout: const Duration(seconds: 120));
    final content =
        (((response['choices'] as List?)?.firstOrNull as Map?)?['message']
            as Map?)?['content'];
    final text = content is String ? content.trim() : '';
    return (
      step: BailianSmokeStep(
        name: 'Qwen-ASR data URI',
        passed: text.isNotEmpty,
        detail: text.isEmpty ? 'empty transcript' : text,
      ),
      text: text,
    );
  }

  Future<({BailianSmokeStep step, String text})>
  _runEnglishToChinesePostProcess(http.Client client, String inputText) async {
    final response = await _postJson(client, '/chat/completions', {
      'model': textModel,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a transcription post-processor. Translate the provided English transcript into natural Simplified Chinese. Return only the Chinese translation, with no explanation.',
        },
        {'role': 'user', 'content': inputText},
      ],
      'temperature': 0,
    });
    final content =
        (((response['choices'] as List?)?.firstOrNull as Map?)?['message']
                as Map?)?['content']
            as String?;
    final text = content?.trim() ?? '';
    final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    return (
      step: BailianSmokeStep(
        name: 'Post-process en->zh',
        passed: text.isNotEmpty && hasChinese,
        detail: text.isEmpty ? 'empty translation' : text,
      ),
      text: text,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    http.Client client,
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final response = await client
        .post(_endpoint(path), headers: _jsonHeaders, body: jsonEncode(body))
        .timeout(timeout);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      throw StateError(
        error is Map && error['message'] is String
            ? error['message'] as String
            : 'HTTP ${response.statusCode}',
      );
    }
    return decoded;
  }

  Future<Uint8List> _downloadBytes(http.Client client, String url) async {
    const assetScheme = 'asset://';
    if (url.startsWith(assetScheme)) {
      final data = await rootBundle.load(url.substring(assetScheme.length));
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }

    late final http.Response response;
    try {
      response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 90));
    } on TimeoutException catch (error) {
      throw TimeoutException(
        'Audio download timed out for $url',
        error.duration,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Audio download failed: HTTP ${response.statusCode}.');
    }
    if (response.bodyBytes.isEmpty) {
      throw StateError('Audio download returned no data.');
    }
    return response.bodyBytes;
  }

  WavPcm16 parseWavPcm16(Uint8List bytes) {
    return parseWavPcm16Bytes(bytes, source: 'Realtime ASR smoke audio');
  }

  String _responseOutputText(Map<String, dynamic> response) {
    final direct = response['output_text'];
    if (direct is String) {
      return direct.trim();
    }
    final output = response['output'];
    if (output is! List) {
      return '';
    }
    final buffer = StringBuffer();
    for (final item in output) {
      if (item is! Map) {
        continue;
      }
      final content = item['content'];
      if (content is! List) {
        continue;
      }
      for (final part in content) {
        if (part is Map && part['text'] is String) {
          buffer.write(part['text'] as String);
        }
      }
    }
    return buffer.toString().trim();
  }

  Uri _endpoint(String path) {
    final normalizedBase = apiBase.endsWith('/')
        ? apiBase.substring(0, apiBase.length - 1)
        : apiBase;
    return Uri.parse('$normalizedBase$path');
  }

  Map<String, String> get _jsonHeaders => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };
}
