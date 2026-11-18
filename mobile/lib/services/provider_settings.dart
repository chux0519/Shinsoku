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
      bailianApiKey: String.fromEnvironment('BAILIAN_API_KEY'),
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
      sonioxApiKey: String.fromEnvironment('SONIOX_API_KEY'),
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
    ]);
  }
}
