package com.shinsoku.mobile.speechcore

enum class VoiceRecognitionProvider {
    AndroidSystem,
    OpenAiCompatible,
    Soniox,
    Bailian,
}

data class OpenAiProviderConfig(
    val baseUrl: String = "https://api.openai.com/v1",
    val apiKey: String = "",
    val transcriptionModel: String = "gpt-4o-mini-transcribe",
    val postProcessingModel: String = "gpt-5.4-nano",
)

data class OpenAiPostProcessingConfig(
    val baseUrl: String = "https://api.openai.com/v1",
    val apiKey: String = "",
    val model: String = "gpt-5.4-nano",
)

data class SonioxProviderConfig(
    val url: String = "wss://stt-rt.soniox.com/transcribe-websocket",
    val apiKey: String = "",
    val model: String = "stt-rt-preview",
)

data class BailianProviderConfig(
    val region: String = "cn-beijing",
    val url: String = "wss://dashscope.aliyuncs.com/api-ws/v1/inference/",
    val apiKey: String = "",
    val model: String = "fun-asr-realtime",
)

data class VoiceProviderConfig(
    val activeRecognitionProvider: VoiceRecognitionProvider = VoiceRecognitionProvider.AndroidSystem,
    val openAiRecognition: OpenAiProviderConfig = OpenAiProviderConfig(),
    val openAiPostProcessing: OpenAiPostProcessingConfig = OpenAiPostProcessingConfig(),
    val soniox: SonioxProviderConfig = SonioxProviderConfig(),
    val bailian: BailianProviderConfig = BailianProviderConfig(),
)
