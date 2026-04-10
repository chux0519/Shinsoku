package com.shinsoku.mobile.ime

import com.shinsoku.mobile.speechcore.VoiceProviderConfig
import com.shinsoku.mobile.speechcore.VoiceRecognitionProvider
import java.net.URI

data class ProviderRuntimeStatus(
    val ready: Boolean,
    val summary: String,
    val detail: String,
)

object RecognitionProviderDiagnostics {
    init {
        runCatching { System.loadLibrary("shinsoku_nativecore") }
    }

    fun status(config: VoiceProviderConfig): ProviderRuntimeStatus = when (config.activeRecognitionProvider) {
        else -> nativeStatus(config) ?: fallbackStatus(config)
    }

    fun requireReady(config: VoiceProviderConfig): String? {
        val status = status(config)
        return if (status.ready) null else status.detail
    }

    private fun nativeStatus(config: VoiceProviderConfig): ProviderRuntimeStatus? {
        val result = runCatching {
            describeProviderRuntimeNative(
                activeProviderName = config.activeRecognitionProvider.name,
                openaiBaseUrl = config.openAiRecognition.baseUrl,
                openaiApiKey = config.openAiRecognition.apiKey,
                openaiTranscriptionModel = config.openAiRecognition.transcriptionModel,
                sonioxUrl = config.soniox.url,
                sonioxApiKey = config.soniox.apiKey,
                sonioxModel = config.soniox.model,
                bailianRegion = config.bailian.region,
                bailianUrl = config.bailian.url,
                bailianApiKey = config.bailian.apiKey,
                bailianModel = config.bailian.model,
            )
        }.getOrNull() ?: return null
        if (result.size < 3) return null
        return ProviderRuntimeStatus(
            ready = result[0] == "true",
            summary = result[1],
            detail = result[2],
        )
    }

    private fun fallbackStatus(config: VoiceProviderConfig): ProviderRuntimeStatus = when (config.activeRecognitionProvider) {
        VoiceRecognitionProvider.AndroidSystem -> ProviderRuntimeStatus(
            ready = true,
            summary = "on-device ready",
            detail = "Uses Android system speech recognition. No remote credentials required.",
        )
        VoiceRecognitionProvider.OpenAiCompatible -> buildRemoteStatus(
            providerName = "OpenAI-compatible",
            apiKey = config.openAiRecognition.apiKey,
            model = config.openAiRecognition.transcriptionModel,
            endpoint = config.openAiRecognition.baseUrl,
            allowedSchemes = setOf("http", "https"),
        )
        VoiceRecognitionProvider.Soniox -> buildRemoteStatus(
            providerName = "Soniox",
            apiKey = config.soniox.apiKey,
            model = config.soniox.model,
            endpoint = config.soniox.url,
            allowedSchemes = setOf("ws", "wss"),
        )
        VoiceRecognitionProvider.Bailian -> buildRemoteStatus(
            providerName = "Bailian",
            apiKey = config.bailian.apiKey,
            model = config.bailian.model,
            endpoint = config.bailian.url,
            allowedSchemes = setOf("ws", "wss"),
            extraChecks = {
                if (config.bailian.region.isBlank()) {
                    add("Region is missing.")
                }
            },
        )
    }

    private fun buildRemoteStatus(
        providerName: String,
        apiKey: String,
        model: String,
        endpoint: String,
        allowedSchemes: Set<String>,
        extraChecks: MutableList<String>.() -> Unit = {},
    ): ProviderRuntimeStatus {
        val issues = mutableListOf<String>()
        if (apiKey.isBlank()) {
            issues += "API key is missing."
        }
        if (model.isBlank()) {
            issues += "Model is missing."
        }
        val normalizedEndpoint = endpoint.trim()
        if (normalizedEndpoint.isBlank()) {
            issues += "Endpoint is missing."
        } else {
            val scheme = runCatching { URI(normalizedEndpoint).scheme.orEmpty().lowercase() }.getOrDefault("")
            if (scheme !in allowedSchemes) {
                issues += "Endpoint must use ${allowedSchemes.joinToString("/")}."
            }
        }
        extraChecks(issues)

        return if (issues.isEmpty()) {
            ProviderRuntimeStatus(
                ready = true,
                summary = "credentials ready",
                detail = "$providerName is configured for live recognition.\n${RecognitionEndpointDebug.describe(normalizedEndpoint)}",
            )
        } else {
            ProviderRuntimeStatus(
                ready = false,
                summary = "configuration incomplete",
                detail = "$providerName is not ready: ${issues.joinToString(" ")}\n${RecognitionEndpointDebug.describe(normalizedEndpoint)}",
            )
        }
    }

    private external fun describeProviderRuntimeNative(
        activeProviderName: String,
        openaiBaseUrl: String,
        openaiApiKey: String,
        openaiTranscriptionModel: String,
        sonioxUrl: String,
        sonioxApiKey: String,
        sonioxModel: String,
        bailianRegion: String,
        bailianUrl: String,
        bailianApiKey: String,
        bailianModel: String,
    ): Array<String>
}
