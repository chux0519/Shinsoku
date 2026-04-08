package com.shinsoku.mobile.processing

import com.shinsoku.mobile.speechcore.TranscriptPostProcessingMode

object NativeVoiceRuntime {
    fun derivePostProcessingMode(
        activeProviderName: String,
        openAiApiKey: String,
    ): TranscriptPostProcessingMode {
        val modeName = runCatching {
            derivePostProcessingModeNative(activeProviderName, openAiApiKey)
        }.getOrElse {
            if (activeProviderName == "OpenAiCompatible" && openAiApiKey.isNotBlank()) {
                TranscriptPostProcessingMode.ProviderAssisted.name
            } else {
                TranscriptPostProcessingMode.LocalCleanup.name
            }
        }

        return runCatching { TranscriptPostProcessingMode.valueOf(modeName) }
            .getOrDefault(TranscriptPostProcessingMode.LocalCleanup)
    }

    private external fun derivePostProcessingModeNative(
        activeProviderName: String,
        openAiApiKey: String,
    ): String
}
