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
    fun status(config: VoiceProviderConfig): ProviderRuntimeStatus = when (config.activeRecognitionProvider) {
        VoiceRecognitionProvider.AndroidSystem -> ProviderRuntimeStatus(
            ready = true,
            summary = "on-device ready",
            detail = "Uses Android system speech recognition. No remote credentials required.",
        )

        VoiceRecognitionProvider.OpenAiCompatible -> buildRemoteStatus(
            providerName = "OpenAI-compatible",
            apiKey = config.openAi.apiKey,
            model = config.openAi.transcriptionModel,
            endpoint = config.openAi.baseUrl,
            allowedSchemes = setOf("http", "https"),
            extraChecks = {
                if (config.openAi.postProcessingModel.isBlank()) {
                    add("Post-processing model is missing.")
                }
            },
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

    fun requireReady(config: VoiceProviderConfig): String? {
        val status = status(config)
        return if (status.ready) null else status.detail
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
}
