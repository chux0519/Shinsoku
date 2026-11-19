import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:shinsoku_mobile/services/transcription_service.dart';

class ProviderSettings {
  const ProviderSettings({
    required this.speechProvider,
    required this.textTransformEnabled,
    required this.bailianAsrMode,
    required this.bailianApiBase,
    required this.bailianApiKey,
    required this.bailianTextModel,
    required this.bailianAsrModel,
    required this.bailianRealtimeUrl,
    required this.bailianRealtimeModel,
    required this.sonioxApiKey,
    required this.sonioxModel,
    this.sonioxLanguageHints = const [],
    this.bailianLanguageHint = '',
  });

  factory ProviderSettings.defaults() {
    return const ProviderSettings(
      speechProvider: 'bailian',
      textTransformEnabled: true,
      bailianAsrMode: String.fromEnvironment(
        'BAILIAN_ASR_MODE',
        defaultValue: bailianAsrModeRealtime,
      ),
      bailianApiBase: String.fromEnvironment(
        'BAILIAN_API_BASE',
        defaultValue: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      ),
      bailianApiKey: '',
      bailianTextModel: String.fromEnvironment(
        'BAILIAN_OPENAI_MODEL',
        defaultValue: 'qwen-flash',
      ),
      bailianAsrModel: String.fromEnvironment(
        'BAILIAN_OPENAI_ASR_MODEL',
        defaultValue: 'qwen3-asr-flash',
      ),
      bailianRealtimeUrl: String.fromEnvironment(
        'BAILIAN_REALTIME_URL',
        defaultValue: 'wss://dashscope.aliyuncs.com/api-ws/v1/inference',
      ),
      bailianRealtimeModel: String.fromEnvironment(
        'BAILIAN_REALTIME_MODEL',
        defaultValue: 'fun-asr-realtime',
      ),
      sonioxApiKey: '',
      sonioxModel: String.fromEnvironment(
        'SONIOX_MODEL',
        defaultValue: 'stt-rt-v4',
      ),
    );
  }

  final String speechProvider;
  final bool textTransformEnabled;
  final String bailianAsrMode;
  final String bailianApiBase;
  final String bailianApiKey;
  final String bailianTextModel;
  final String bailianAsrModel;
  final String bailianRealtimeUrl;
  final String bailianRealtimeModel;
  final String sonioxApiKey;
  final String sonioxModel;

  /// Soniox `language_hints` (ISO 639-1, bias only). Empty = auto. Set once
  /// on first launch from the device languages (i18n-01 I3); an absent key
  /// (installs from before I3) reads as empty, i.e. today's behaviour.
  final List<String> sonioxLanguageHints;

  /// Fun-ASR realtime `language_hints` (one value). Empty = auto-detect.
  final String bailianLanguageHint;

  ProviderSettings copyWith({
    String? speechProvider,
    bool? textTransformEnabled,
    String? bailianAsrMode,
    String? bailianApiBase,
    String? bailianApiKey,
    String? bailianTextModel,
    String? bailianAsrModel,
    String? bailianRealtimeUrl,
    String? bailianRealtimeModel,
    String? sonioxApiKey,
    String? sonioxModel,
    List<String>? sonioxLanguageHints,
    String? bailianLanguageHint,
  }) {
    return ProviderSettings(
      speechProvider: speechProvider ?? this.speechProvider,
      textTransformEnabled: textTransformEnabled ?? this.textTransformEnabled,
      bailianAsrMode: bailianAsrMode ?? this.bailianAsrMode,
      bailianApiBase: bailianApiBase ?? this.bailianApiBase,
      bailianApiKey: bailianApiKey ?? this.bailianApiKey,
      bailianTextModel: bailianTextModel ?? this.bailianTextModel,
      bailianAsrModel: bailianAsrModel ?? this.bailianAsrModel,
      bailianRealtimeUrl: bailianRealtimeUrl ?? this.bailianRealtimeUrl,
      bailianRealtimeModel: bailianRealtimeModel ?? this.bailianRealtimeModel,
      sonioxApiKey: sonioxApiKey ?? this.sonioxApiKey,
      sonioxModel: sonioxModel ?? this.sonioxModel,
      sonioxLanguageHints: sonioxLanguageHints ?? this.sonioxLanguageHints,
      bailianLanguageHint: bailianLanguageHint ?? this.bailianLanguageHint,
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

  /// Storage key (without prefix) → full key, for code that writes single
  /// settings (first-launch region defaults).
  static String keyFor(String name) => '$_prefix$name';

  /// Whether [key] (a full storage key) belongs to the provider settings.
  static bool isProviderKey(String key) => key.startsWith(_prefix);

  static String encodeHints(List<String> hints) => hints.join(',');

  static List<String> decodeHints(String? raw) => [
    for (final part in (raw ?? '').split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];

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
      bailianAsrMode: await readString(
        'bailianAsrMode',
        defaults.bailianAsrMode,
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
      sonioxLanguageHints: decodeHints(
        await _storage.read(key: '${_prefix}sonioxLanguageHints'),
      ),
      bailianLanguageHint: await readString(
        'bailianLanguageHint',
        defaults.bailianLanguageHint,
      ),
    );
  }

  Future<void> save(ProviderSettings settings) async {
    Future<void> write(String key, String value) {
      return _storage.write(key: '$_prefix$key', value: value);
    }

    await Future.wait([
      write('speechProvider', settings.speechProvider),
      write('textTransformEnabled', settings.textTransformEnabled.toString()),
      write('bailianAsrMode', settings.bailianAsrMode),
      write('bailianApiBase', settings.bailianApiBase),
      write('bailianApiKey', settings.bailianApiKey),
      write('bailianTextModel', settings.bailianTextModel),
      write('bailianAsrModel', settings.bailianAsrModel),
      write('bailianRealtimeUrl', settings.bailianRealtimeUrl),
      write('bailianRealtimeModel', settings.bailianRealtimeModel),
      write('sonioxApiKey', settings.sonioxApiKey),
      write('sonioxModel', settings.sonioxModel),
      write('sonioxLanguageHints', encodeHints(settings.sonioxLanguageHints)),
      write('bailianLanguageHint', settings.bailianLanguageHint),
    ]);
  }
}
