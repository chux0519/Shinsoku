import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

void main() {
  runApp(const ShinsokuMobileApp());
}

class ShinsokuMobileApp extends StatelessWidget {
  const ShinsokuMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF256D7B);

    return MaterialApp(
      title: 'Shinsoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MobileShell(),
    );
  }
}

enum CaptureState { idle, listening, processing }

enum CommitSuffix { none, space, newline }

class KeyboardBridge {
  static const MethodChannel _channel = MethodChannel(
    'net.potafree.shinsoku/keyboard_bridge',
  );

  static Future<void> publishText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await _channel.invokeMethod<void>('publishLatestText', {'text': trimmed});
  }
}

class SmokeTestConfig {
  static const mode = String.fromEnvironment('SHINSOKU_SMOKE_TEST');
  static const sonioxApiKey = String.fromEnvironment('SONIOX_API_KEY');
  static const bailianApiBase = String.fromEnvironment(
    'BAILIAN_API_BASE',
    defaultValue: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  );
  static const bailianApiKey = String.fromEnvironment('BAILIAN_API_KEY');
  static const bailianOpenAiModel = String.fromEnvironment(
    'BAILIAN_OPENAI_MODEL',
    defaultValue: 'qwen3.5-flash',
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

class SmokeTestStatus {
  const SmokeTestStatus({
    required this.label,
    required this.detail,
    this.transcript,
    this.failed = false,
    this.finished = false,
  });

  final String label;
  final String detail;
  final String? transcript;
  final bool failed;
  final bool finished;
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
      throw StateError('Missing SONIOX_API_KEY dart define.');
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
      throw StateError('Missing BAILIAN_API_KEY dart define.');
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
    final wav = _parseWavPcm16(audioBytes);
    final taskId = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final channel = IOWebSocketChannel.connect(
      Uri.parse(realtimeUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'user-agent': 'Shinsoku-Mobile-Bailian-Smoke/1.0',
      },
    );

    final started = Completer<void>();
    final finished = Completer<void>();
    final sentences = <int, ({String text, bool finalSentence})>{};
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
            sentences[id] = (
              text: text,
              finalSentence: sentence['sentence_end'] == true,
            );
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
            'model': realtimeModel,
            'parameters': {'format': 'pcm', 'sample_rate': wav.sampleRate},
            'input': <String, dynamic>{},
          },
        }),
      );
      await started.future.timeout(const Duration(seconds: 20));

      final chunkSize = (wav.sampleRate * 2 * 0.1).round();
      for (var offset = 0; offset < wav.pcm.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, wav.pcm.length);
        channel.sink.add(wav.pcm.sublist(offset, end));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
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
    } finally {
      unawaited(subscription.cancel());
      unawaited(channel.sink.close());
    }

    final ordered = sentences.keys.toList()..sort();
    final text = ordered.map((id) => sentences[id]!.text).join().trim();
    return (
      step: BailianSmokeStep(
        name: 'Fun-ASR realtime',
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

  _WavPcm16 _parseWavPcm16(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 44 ||
        ascii.decode(bytes.sublist(0, 4)) != 'RIFF' ||
        ascii.decode(bytes.sublist(8, 12)) != 'WAVE') {
      throw StateError('Realtime ASR smoke audio must be a WAV file.');
    }
    final channels = data.getUint16(22, Endian.little);
    final sampleRate = data.getUint32(24, Endian.little);
    final bitsPerSample = data.getUint16(34, Endian.little);
    if (channels != 1 || bitsPerSample != 16) {
      throw StateError('Realtime ASR smoke audio must be mono PCM16 WAV.');
    }

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = ascii.decode(bytes.sublist(offset, offset + 4));
      final size = data.getUint32(offset + 4, Endian.little);
      final payloadStart = offset + 8;
      final payloadEnd = payloadStart + size;
      if (id == 'data') {
        return _WavPcm16(
          sampleRate: sampleRate,
          pcm: bytes.sublist(payloadStart, payloadEnd.clamp(0, bytes.length)),
        );
      }
      offset = payloadEnd + (size.isOdd ? 1 : 0);
    }
    throw StateError('WAV data chunk not found.');
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

class _WavPcm16 {
  const _WavPcm16({required this.sampleRate, required this.pcm});

  final int sampleRate;
  final Uint8List pcm;
}

class ProviderSettings {
  const ProviderSettings({
    required this.speechProvider,
    required this.textTransformEnabled,
    required this.bailianApiBase,
    required this.bailianApiKey,
    required this.bailianTextModel,
    required this.bailianAsrModel,
    required this.bailianRealtimeUrl,
    required this.bailianRealtimeModel,
    required this.sonioxApiKey,
    required this.sonioxModel,
  });

  factory ProviderSettings.defaults() {
    return const ProviderSettings(
      speechProvider: 'bailian',
      textTransformEnabled: true,
      bailianApiBase: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      bailianApiKey: '',
      bailianTextModel: 'qwen3.5-flash',
      bailianAsrModel: 'qwen3-asr-flash',
      bailianRealtimeUrl: 'wss://dashscope.aliyuncs.com/api-ws/v1/inference',
      bailianRealtimeModel: 'fun-asr-realtime',
      sonioxApiKey: '',
      sonioxModel: 'stt-rt-v4',
    );
  }

  final String speechProvider;
  final bool textTransformEnabled;
  final String bailianApiBase;
  final String bailianApiKey;
  final String bailianTextModel;
  final String bailianAsrModel;
  final String bailianRealtimeUrl;
  final String bailianRealtimeModel;
  final String sonioxApiKey;
  final String sonioxModel;

  ProviderSettings copyWith({
    String? speechProvider,
    bool? textTransformEnabled,
    String? bailianApiBase,
    String? bailianApiKey,
    String? bailianTextModel,
    String? bailianAsrModel,
    String? bailianRealtimeUrl,
    String? bailianRealtimeModel,
    String? sonioxApiKey,
    String? sonioxModel,
  }) {
    return ProviderSettings(
      speechProvider: speechProvider ?? this.speechProvider,
      textTransformEnabled: textTransformEnabled ?? this.textTransformEnabled,
      bailianApiBase: bailianApiBase ?? this.bailianApiBase,
      bailianApiKey: bailianApiKey ?? this.bailianApiKey,
      bailianTextModel: bailianTextModel ?? this.bailianTextModel,
      bailianAsrModel: bailianAsrModel ?? this.bailianAsrModel,
      bailianRealtimeUrl: bailianRealtimeUrl ?? this.bailianRealtimeUrl,
      bailianRealtimeModel: bailianRealtimeModel ?? this.bailianRealtimeModel,
      sonioxApiKey: sonioxApiKey ?? this.sonioxApiKey,
      sonioxModel: sonioxModel ?? this.sonioxModel,
    );
  }

  bool get activeProviderConfigured {
    return switch (speechProvider) {
      'soniox' => sonioxApiKey.trim().isNotEmpty,
      _ => bailianApiKey.trim().isNotEmpty,
    };
  }
}

class ProviderSettingsStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _prefix = 'provider_settings.';

  Future<ProviderSettings> load() async {
    final defaults = ProviderSettings.defaults();

    Future<String> readString(String key, String fallback) async {
      return await _storage.read(key: '$_prefix$key') ?? fallback;
    }

    Future<bool> readBool(String key, bool fallback) async {
      final value = await _storage.read(key: '$_prefix$key');
      if (value == null) {
        return fallback;
      }
      return value == 'true';
    }

    return ProviderSettings(
      speechProvider: await readString(
        'speechProvider',
        defaults.speechProvider,
      ),
      textTransformEnabled: await readBool(
        'textTransformEnabled',
        defaults.textTransformEnabled,
      ),
      bailianApiBase: await readString(
        'bailianApiBase',
        defaults.bailianApiBase,
      ),
      bailianApiKey: await readString('bailianApiKey', defaults.bailianApiKey),
      bailianTextModel: await readString(
        'bailianTextModel',
        defaults.bailianTextModel,
      ),
      bailianAsrModel: await readString(
        'bailianAsrModel',
        defaults.bailianAsrModel,
      ),
      bailianRealtimeUrl: await readString(
        'bailianRealtimeUrl',
        defaults.bailianRealtimeUrl,
      ),
      bailianRealtimeModel: await readString(
        'bailianRealtimeModel',
        defaults.bailianRealtimeModel,
      ),
      sonioxApiKey: await readString('sonioxApiKey', defaults.sonioxApiKey),
      sonioxModel: await readString('sonioxModel', defaults.sonioxModel),
    );
  }

  Future<void> save(ProviderSettings settings) async {
    Future<void> write(String key, String value) {
      return _storage.write(key: '$_prefix$key', value: value);
    }

    await Future.wait([
      write('speechProvider', settings.speechProvider),
      write('textTransformEnabled', settings.textTransformEnabled.toString()),
      write('bailianApiBase', settings.bailianApiBase),
      write('bailianApiKey', settings.bailianApiKey),
      write('bailianTextModel', settings.bailianTextModel),
      write('bailianAsrModel', settings.bailianAsrModel),
      write('bailianRealtimeUrl', settings.bailianRealtimeUrl),
      write('bailianRealtimeModel', settings.bailianRealtimeModel),
      write('sonioxApiKey', settings.sonioxApiKey),
      write('sonioxModel', settings.sonioxModel),
    ]);
  }
}

class VoiceProfile {
  const VoiceProfile({
    required this.name,
    required this.intent,
    required this.commitSuffix,
    required this.autoCommit,
  });

  final String name;
  final String intent;
  final CommitSuffix commitSuffix;
  final bool autoCommit;
}

class DraftEntry {
  DraftEntry({
    required this.text,
    required this.profileName,
    required this.createdAt,
  });

  final String text;
  final String profileName;
  final DateTime createdAt;
}

class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  final ProviderSettingsStore _providerSettingsStore = ProviderSettingsStore();

  final List<VoiceProfile> _profiles = const [
    VoiceProfile(
      name: 'Dictation',
      intent: 'Clean speech into natural prose',
      commitSuffix: CommitSuffix.space,
      autoCommit: true,
    ),
    VoiceProfile(
      name: 'Chat',
      intent: 'Make the text concise and conversational',
      commitSuffix: CommitSuffix.newline,
      autoCommit: true,
    ),
    VoiceProfile(
      name: 'Review',
      intent: 'Hold transcript for manual review',
      commitSuffix: CommitSuffix.none,
      autoCommit: false,
    ),
  ];

  final List<DraftEntry> _drafts = [
    DraftEntry(
      text: 'Follow up with the release notes after the desktop build passes.',
      profileName: 'Review',
      createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
    ),
    DraftEntry(
      text:
          'The mobile rewrite should keep provider setup lightweight at first.',
      profileName: 'Dictation',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  int _tabIndex = 0;
  int _selectedProfileIndex = 0;
  CaptureState _captureState = CaptureState.idle;
  bool _microphoneAllowed = true;
  bool _keyboardExtensionEnabled = false;
  bool _cloudProcessingEnabled = false;
  bool _providerSettingsLoading = true;
  bool _providerSettingsSaving = false;
  ProviderSettings _providerSettings = ProviderSettings.defaults();
  SmokeTestStatus? _smokeTestStatus;

  VoiceProfile get _activeProfile => _profiles[_selectedProfileIndex];

  @override
  void initState() {
    super.initState();

    if (SmokeTestConfig.mode == 'soniox') {
      unawaited(_runSonioxSmokeTest());
    } else if (SmokeTestConfig.mode == 'bailian') {
      unawaited(_runBailianSmokeTest());
    }
    unawaited(_loadProviderSettings());
  }

  void _selectTab(int index) {
    setState(() {
      _tabIndex = index;
    });
  }

  Future<void> _toggleCapture() async {
    if (!_microphoneAllowed) {
      setState(() {
        _tabIndex = 2;
      });
      return;
    }

    if (_captureState == CaptureState.idle) {
      setState(() {
        _captureState = CaptureState.listening;
      });
      return;
    }

    setState(() {
      _captureState = CaptureState.processing;
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) {
      return;
    }

    final draft = DraftEntry(
      text: _sampleTranscriptFor(_activeProfile),
      profileName: _activeProfile.name,
      createdAt: DateTime.now(),
    );

    unawaited(KeyboardBridge.publishText(draft.text));

    setState(() {
      _captureState = CaptureState.idle;
      _drafts.insert(0, draft);
      _tabIndex = 1;
    });
  }

  String _sampleTranscriptFor(VoiceProfile profile) {
    return switch (profile.name) {
      'Chat' =>
        'Can you send me the current build status when you have a minute?',
      'Review' =>
        'Draft captured for review before inserting into the active field.',
      _ => 'Captured a clean mobile voice note with Shinsoku.',
    };
  }

  void _deleteDraft(DraftEntry draft) {
    setState(() {
      _drafts.remove(draft);
    });
  }

  Future<void> _loadProviderSettings() async {
    try {
      final settings = await _providerSettingsStore.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _providerSettings = settings;
        _providerSettingsLoading = false;
        _cloudProcessingEnabled = settings.activeProviderConfigured;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _providerSettingsLoading = false;
      });
    }
  }

  Future<void> _saveProviderSettings(ProviderSettings settings) async {
    setState(() {
      _providerSettingsSaving = true;
    });
    try {
      await _providerSettingsStore.save(settings);
      if (!mounted) {
        return;
      }
      setState(() {
        _providerSettings = settings;
        _providerSettingsSaving = false;
        _cloudProcessingEnabled = settings.activeProviderConfigured;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _providerSettingsSaving = false;
      });
      rethrow;
    }
  }

  Future<void> _runSonioxSmokeTest() async {
    setState(() {
      _captureState = CaptureState.processing;
      _smokeTestStatus = const SmokeTestStatus(
        label: 'Real Soniox smoke test',
        detail: 'Streaming public WAV audio to Soniox from the iOS simulator.',
      );
    });

    try {
      final result = await SonioxSmokeTestRunner(
        apiKey: SmokeTestConfig.sonioxApiKey,
        audioUrl: SmokeTestConfig.audioUrl,
        audioFormat: SmokeTestConfig.audioFormat,
      ).run();

      if (!mounted) {
        return;
      }

      setState(() {
        _captureState = CaptureState.idle;
        _tabIndex = 0;
        _smokeTestStatus = SmokeTestStatus(
          label: 'Soniox smoke test passed',
          detail: result.partial
              ? 'Received realtime tokens after sending ${result.bytesSent} bytes.'
              : 'Sent ${result.bytesSent} bytes and received a finished result.',
          transcript: result.transcript,
          finished: true,
        );
        final draft = DraftEntry(
          text: result.transcript,
          profileName: 'Soniox',
          createdAt: DateTime.now(),
        );
        unawaited(KeyboardBridge.publishText(draft.text));
        _drafts.insert(0, draft);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _captureState = CaptureState.idle;
        _tabIndex = 0;
        _smokeTestStatus = SmokeTestStatus(
          label: 'Soniox smoke test failed',
          detail: error.toString(),
          failed: true,
          finished: true,
        );
      });
    }
  }

  Future<void> _runBailianSmokeTest() async {
    setState(() {
      _captureState = CaptureState.processing;
      _smokeTestStatus = const SmokeTestStatus(
        label: 'Real Bailian smoke test',
        detail:
            'Calling Bailian text, ASR, and realtime APIs from the iOS simulator.',
      );
    });

    try {
      final result = await BailianSmokeTestRunner(
        apiBase: SmokeTestConfig.bailianApiBase,
        apiKey: SmokeTestConfig.bailianApiKey,
        textModel: SmokeTestConfig.bailianOpenAiModel,
        asrModel: SmokeTestConfig.bailianAsrModel,
        asrAudioUrl: SmokeTestConfig.bailianAsrAudioUrl,
        realtimeUrl: SmokeTestConfig.bailianRealtimeUrl,
        realtimeModel: SmokeTestConfig.bailianRealtimeModel,
        realtimeAudioUrl: SmokeTestConfig.audioUrl,
      ).run();

      if (!mounted) {
        return;
      }

      setState(() {
        _captureState = CaptureState.idle;
        _tabIndex = 0;
        _smokeTestStatus = SmokeTestStatus(
          label: 'Bailian smoke test passed',
          detail: result.steps
              .map((step) => '${step.name}: ${step.detail}')
              .join('\n'),
          transcript: result.transcript,
          finished: true,
        );
        if (result.transcript.isNotEmpty) {
          final draft = DraftEntry(
            text: result.transcript,
            profileName: 'Bailian',
            createdAt: DateTime.now(),
          );
          unawaited(KeyboardBridge.publishText(draft.text));
          _drafts.insert(0, draft);
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _captureState = CaptureState.idle;
        _tabIndex = 0;
        _smokeTestStatus = SmokeTestStatus(
          label: 'Bailian smoke test failed',
          detail: error.toString(),
          failed: true,
          finished: true,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.mic_none),
        selectedIcon: Icon(Icons.mic),
        label: 'Record',
      ),
      NavigationDestination(
        icon: Icon(Icons.description_outlined),
        selectedIcon: Icon(Icons.description),
        label: 'Drafts',
      ),
      NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune),
        label: 'Settings',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final body = IndexedStack(
          index: _tabIndex,
          children: [
            RecordView(
              profiles: _profiles,
              selectedProfileIndex: _selectedProfileIndex,
              captureState: _captureState,
              microphoneAllowed: _microphoneAllowed,
              smokeTestStatus: _smokeTestStatus,
              onProfileSelected: (index) {
                setState(() {
                  _selectedProfileIndex = index;
                });
              },
              onCapturePressed: _toggleCapture,
            ),
            DraftsView(drafts: _drafts, onDelete: _deleteDraft),
            SettingsView(
              microphoneAllowed: _microphoneAllowed,
              keyboardExtensionEnabled: _keyboardExtensionEnabled,
              cloudProcessingEnabled: _cloudProcessingEnabled,
              providerSettings: _providerSettings,
              providerSettingsLoading: _providerSettingsLoading,
              providerSettingsSaving: _providerSettingsSaving,
              onMicrophoneChanged: (value) {
                setState(() {
                  _microphoneAllowed = value;
                });
              },
              onKeyboardChanged: (value) {
                setState(() {
                  _keyboardExtensionEnabled = value;
                });
              },
              onCloudProcessingChanged: (value) {
                setState(() {
                  _cloudProcessingEnabled = value;
                });
              },
              onProviderSettingsSaved: _saveProviderSettings,
            ),
          ],
        );

        if (wide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _tabIndex,
                    onDestinationSelected: _selectTab,
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 18),
                      child: ShinsokuMark(),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.mic_none),
                        selectedIcon: Icon(Icons.mic),
                        label: Text('Record'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.description_outlined),
                        selectedIcon: Icon(Icons.description),
                        label: Text('Drafts'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.tune_outlined),
                        selectedIcon: Icon(Icons.tune),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(child: body),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: _selectTab,
            destinations: destinations,
          ),
        );
      },
    );
  }
}

class RecordView extends StatelessWidget {
  const RecordView({
    required this.profiles,
    required this.selectedProfileIndex,
    required this.captureState,
    required this.microphoneAllowed,
    required this.smokeTestStatus,
    required this.onProfileSelected,
    required this.onCapturePressed,
    super.key,
  });

  final List<VoiceProfile> profiles;
  final int selectedProfileIndex;
  final CaptureState captureState;
  final bool microphoneAllowed;
  final SmokeTestStatus? smokeTestStatus;
  final ValueChanged<int> onProfileSelected;
  final VoidCallback onCapturePressed;

  @override
  Widget build(BuildContext context) {
    final profile = profiles[selectedProfileIndex];
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppHeader(title: 'Shinsoku', subtitle: 'Mobile voice input'),
        const SizedBox(height: 20),
        if (smokeTestStatus != null) ...[
          SmokeTestPanel(status: smokeTestStatus!),
          const SizedBox(height: 18),
        ],
        InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.graphic_eq, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusTitle(captureState),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _statusCopy(captureState, microphoneAllowed),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: captureState == CaptureState.processing
                      ? null
                      : onCapturePressed,
                  icon: Icon(_captureIcon(captureState, microphoneAllowed)),
                  label: Text(_captureLabel(captureState, microphoneAllowed)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Profile', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          segments: [
            for (var index = 0; index < profiles.length; index += 1)
              ButtonSegment<int>(
                value: index,
                label: Text(profiles[index].name),
                icon: Icon(_profileIcon(profiles[index])),
              ),
          ],
          selected: {selectedProfileIndex},
          onSelectionChanged: (selection) => onProfileSelected(selection.first),
        ),
        const SizedBox(height: 12),
        InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.intent,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(
                    icon: profile.autoCommit
                        ? Icons.flash_on_outlined
                        : Icons.rate_review_outlined,
                    label: profile.autoCommit ? 'Auto commit' : 'Review first',
                  ),
                  StatusChip(
                    icon: Icons.keyboard_return,
                    label: _suffixLabel(profile.commitSuffix),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusTitle(CaptureState state) {
    return switch (state) {
      CaptureState.idle => 'Ready to record',
      CaptureState.listening => 'Listening',
      CaptureState.processing => 'Processing transcript',
    };
  }

  String _statusCopy(CaptureState state, bool microphoneAllowed) {
    if (!microphoneAllowed) {
      return 'Microphone access is disabled. Enable it in Settings before recording.';
    }

    return switch (state) {
      CaptureState.idle => 'Choose a profile, then capture a note or message.',
      CaptureState.listening => 'Tap stop when you are done speaking.',
      CaptureState.processing => 'Preparing a draft with the selected profile.',
    };
  }

  IconData _captureIcon(CaptureState state, bool microphoneAllowed) {
    if (!microphoneAllowed) {
      return Icons.mic_off_outlined;
    }

    return switch (state) {
      CaptureState.idle => Icons.mic,
      CaptureState.listening => Icons.stop,
      CaptureState.processing => Icons.hourglass_top,
    };
  }

  String _captureLabel(CaptureState state, bool microphoneAllowed) {
    if (!microphoneAllowed) {
      return 'Open Settings';
    }

    return switch (state) {
      CaptureState.idle => 'Start Recording',
      CaptureState.listening => 'Stop and Draft',
      CaptureState.processing => 'Processing',
    };
  }

  IconData _profileIcon(VoiceProfile profile) {
    return switch (profile.name) {
      'Chat' => Icons.chat_bubble_outline,
      'Review' => Icons.fact_check_outlined,
      _ => Icons.notes,
    };
  }

  String _suffixLabel(CommitSuffix suffix) {
    return switch (suffix) {
      CommitSuffix.none => 'No suffix',
      CommitSuffix.space => 'Trailing space',
      CommitSuffix.newline => 'New line',
    };
  }
}

class DraftsView extends StatelessWidget {
  const DraftsView({required this.drafts, required this.onDelete, super.key});

  final List<DraftEntry> drafts;
  final ValueChanged<DraftEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppHeader(title: 'Drafts', subtitle: 'Captured mobile text'),
        const SizedBox(height: 20),
        if (drafts.isEmpty)
          const InfoPanel(child: EmptyState())
        else
          for (final draft in drafts) ...[
            DraftCard(draft: draft, onDelete: () => onDelete(draft)),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.microphoneAllowed,
    required this.keyboardExtensionEnabled,
    required this.cloudProcessingEnabled,
    required this.providerSettings,
    required this.providerSettingsLoading,
    required this.providerSettingsSaving,
    required this.onMicrophoneChanged,
    required this.onKeyboardChanged,
    required this.onCloudProcessingChanged,
    required this.onProviderSettingsSaved,
    super.key,
  });

  final bool microphoneAllowed;
  final bool keyboardExtensionEnabled;
  final bool cloudProcessingEnabled;
  final ProviderSettings providerSettings;
  final bool providerSettingsLoading;
  final bool providerSettingsSaving;
  final ValueChanged<bool> onMicrophoneChanged;
  final ValueChanged<bool> onKeyboardChanged;
  final ValueChanged<bool> onCloudProcessingChanged;
  final Future<void> Function(ProviderSettings settings)
  onProviderSettingsSaved;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late String _speechProvider;
  late bool _textTransformEnabled;
  bool _showBailianKey = false;
  bool _showSonioxKey = false;

  late final TextEditingController _bailianBaseController;
  late final TextEditingController _bailianKeyController;
  late final TextEditingController _bailianTextModelController;
  late final TextEditingController _bailianAsrModelController;
  late final TextEditingController _bailianRealtimeUrlController;
  late final TextEditingController _bailianRealtimeModelController;
  late final TextEditingController _sonioxKeyController;
  late final TextEditingController _sonioxModelController;

  @override
  void initState() {
    super.initState();
    _bailianBaseController = TextEditingController();
    _bailianKeyController = TextEditingController();
    _bailianTextModelController = TextEditingController();
    _bailianAsrModelController = TextEditingController();
    _bailianRealtimeUrlController = TextEditingController();
    _bailianRealtimeModelController = TextEditingController();
    _sonioxKeyController = TextEditingController();
    _sonioxModelController = TextEditingController();
    _applySettings(widget.providerSettings);
  }

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerSettings != widget.providerSettings) {
      _applySettings(widget.providerSettings);
    }
  }

  @override
  void dispose() {
    _bailianBaseController.dispose();
    _bailianKeyController.dispose();
    _bailianTextModelController.dispose();
    _bailianAsrModelController.dispose();
    _bailianRealtimeUrlController.dispose();
    _bailianRealtimeModelController.dispose();
    _sonioxKeyController.dispose();
    _sonioxModelController.dispose();
    super.dispose();
  }

  void _applySettings(ProviderSettings settings) {
    _speechProvider = settings.speechProvider;
    _textTransformEnabled = settings.textTransformEnabled;
    _bailianBaseController.text = settings.bailianApiBase;
    _bailianKeyController.text = settings.bailianApiKey;
    _bailianTextModelController.text = settings.bailianTextModel;
    _bailianAsrModelController.text = settings.bailianAsrModel;
    _bailianRealtimeUrlController.text = settings.bailianRealtimeUrl;
    _bailianRealtimeModelController.text = settings.bailianRealtimeModel;
    _sonioxKeyController.text = settings.sonioxApiKey;
    _sonioxModelController.text = settings.sonioxModel;
  }

  Future<void> _save() async {
    final settings = ProviderSettings(
      speechProvider: _speechProvider,
      textTransformEnabled: _textTransformEnabled,
      bailianApiBase: _bailianBaseController.text.trim(),
      bailianApiKey: _bailianKeyController.text.trim(),
      bailianTextModel: _bailianTextModelController.text.trim(),
      bailianAsrModel: _bailianAsrModelController.text.trim(),
      bailianRealtimeUrl: _bailianRealtimeUrlController.text.trim(),
      bailianRealtimeModel: _bailianRealtimeModelController.text.trim(),
      sonioxApiKey: _sonioxKeyController.text.trim(),
      sonioxModel: _sonioxModelController.text.trim(),
    );

    try {
      await widget.onProviderSettingsSaved(settings);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Provider settings saved')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerConfigured = switch (_speechProvider) {
      'soniox' => _sonioxKeyController.text.trim().isNotEmpty,
      _ => _bailianKeyController.text.trim().isNotEmpty,
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppHeader(title: 'Settings', subtitle: 'Providers and workflow'),
        const SizedBox(height: 20),
        InfoPanel(
          child: Column(
            children: [
              SwitchListTile(
                value: widget.microphoneAllowed,
                onChanged: widget.onMicrophoneChanged,
                secondary: const Icon(Icons.mic_none),
                title: const Text('Microphone access'),
                subtitle: const Text('Required for voice capture'),
              ),
              const Divider(),
              SwitchListTile(
                value: widget.keyboardExtensionEnabled,
                onChanged: widget.onKeyboardChanged,
                secondary: const Icon(Icons.keyboard_alt_outlined),
                title: const Text('Keyboard insertion surface'),
                subtitle: const Text(
                  'Use the iOS keyboard to paste the latest Shinsoku text',
                ),
              ),
              const Divider(),
              SwitchListTile(
                value: widget.cloudProcessingEnabled,
                onChanged: widget.onCloudProcessingChanged,
                secondary: const Icon(Icons.cloud_outlined),
                title: const Text('Cloud processing'),
                subtitle: Text(
                  providerConfigured
                      ? 'Provider credentials are saved'
                      : 'Save provider credentials before real transcription',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Speech Provider', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.providerSettingsLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'bailian',
                    label: Text('Bailian'),
                    icon: Icon(Icons.cloud_queue),
                  ),
                  ButtonSegment<String>(
                    value: 'soniox',
                    label: Text('Soniox'),
                    icon: Icon(Icons.graphic_eq),
                  ),
                ],
                selected: {_speechProvider},
                onSelectionChanged: (selection) {
                  setState(() {
                    _speechProvider = selection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _textTransformEnabled,
                onChanged: (value) {
                  setState(() {
                    _textTransformEnabled = value;
                  });
                },
                secondary: const Icon(Icons.translate),
                title: const Text('Text post-processing'),
                subtitle: const Text(
                  'Use the text model for cleanup or translation',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SaveSettingsButton(
          saving: widget.providerSettingsSaving,
          onPressed: _save,
        ),
        const SizedBox(height: 18),
        Text('Bailian', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        InfoPanel(
          child: Column(
            children: [
              ConfigTextField(
                controller: _bailianBaseController,
                icon: Icons.link,
                label: 'OpenAI-compatible base URL',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _bailianKeyController,
                icon: Icons.key,
                label: 'API key',
                obscureText: !_showBailianKey,
                trailing: IconButton(
                  tooltip: _showBailianKey ? 'Hide key' : 'Show key',
                  onPressed: () {
                    setState(() {
                      _showBailianKey = !_showBailianKey;
                    });
                  },
                  icon: Icon(
                    _showBailianKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _bailianTextModelController,
                icon: Icons.text_fields,
                label: 'Text model',
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _bailianAsrModelController,
                icon: Icons.hearing,
                label: 'Qwen-ASR model',
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _bailianRealtimeUrlController,
                icon: Icons.hub_outlined,
                label: 'Realtime WebSocket URL',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _bailianRealtimeModelController,
                icon: Icons.multitrack_audio,
                label: 'Realtime ASR model',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Soniox', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        InfoPanel(
          child: Column(
            children: [
              ConfigTextField(
                controller: _sonioxKeyController,
                icon: Icons.key,
                label: 'API key',
                obscureText: !_showSonioxKey,
                trailing: IconButton(
                  tooltip: _showSonioxKey ? 'Hide key' : 'Show key',
                  onPressed: () {
                    setState(() {
                      _showSonioxKey = !_showSonioxKey;
                    });
                  },
                  icon: Icon(
                    _showSonioxKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _sonioxModelController,
                icon: Icons.multitrack_audio,
                label: 'Realtime model',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SaveSettingsButton(
          saving: widget.providerSettingsSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _SaveSettingsButton extends StatelessWidget {
  const _SaveSettingsButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: saving ? null : onPressed,
        icon: saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(saving ? 'Saving' : 'Save Settings'),
      ),
    );
  }
}

class ConfigTextField extends StatelessWidget {
  const ConfigTextField({
    required this.controller,
    required this.icon,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.trailing,
    super.key,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: !obscureText,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        suffixIcon: trailing,
        labelText: label,
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ShinsokuMark(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class ShinsokuMark extends StatelessWidget {
  const ShinsokuMark({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/app-icon.png',
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.surface,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class SmokeTestPanel extends StatelessWidget {
  const SmokeTestPanel({required this.status, super.key});

  final SmokeTestStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = status.failed
        ? Icons.error_outline
        : status.finished
        ? Icons.check_circle_outline
        : Icons.cloud_sync_outlined;
    final color = status.failed ? scheme.error : scheme.primary;

    return InfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(status.detail),
          if (status.transcript != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              status.transcript!,
              key: const ValueKey('soniox-smoke-transcript'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }
}

class DraftCard extends StatelessWidget {
  const DraftCard({required this.draft, required this.onDelete, super.key});

  final DraftEntry draft;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(
                icon: Icons.person_search_outlined,
                label: draft.profileName,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Delete draft',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(draft.text, style: textTheme.bodyLarge),
          const SizedBox(height: 10),
          Text(_relativeTime(draft.createdAt), style: textTheme.bodySmall),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} min ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} hr ago';
    }
    return '${diff.inDays} days ago';
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.inbox_outlined, size: 44),
        SizedBox(height: 12),
        Text('No drafts yet'),
      ],
    );
  }
}
