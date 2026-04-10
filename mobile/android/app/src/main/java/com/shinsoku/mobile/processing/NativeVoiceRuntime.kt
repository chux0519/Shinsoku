package com.shinsoku.mobile.processing

import com.shinsoku.mobile.speechcore.TranscriptPostProcessingMode

object NativeVoiceRuntime {
    fun resolvePostProcessingMode(
        requestedMode: TranscriptPostProcessingMode,
        activeProviderName: String,
        openAiApiKey: String,
    ): TranscriptPostProcessingMode {
        val modeName = runCatching {
            resolvePostProcessingModeNative(requestedMode.name, activeProviderName, openAiApiKey)
        }.getOrElse {
            if (requestedMode == TranscriptPostProcessingMode.Disabled) {
                TranscriptPostProcessingMode.Disabled.name
            } else if (requestedMode == TranscriptPostProcessingMode.ProviderAssisted &&
                openAiApiKey.isBlank()) {
                TranscriptPostProcessingMode.LocalCleanup.name
            } else {
                requestedMode.name
            }
        }

        return runCatching { TranscriptPostProcessingMode.valueOf(modeName) }
            .getOrDefault(TranscriptPostProcessingMode.LocalCleanup)
    }

    private external fun resolvePostProcessingModeNative(
        requestedModeName: String,
        activeProviderName: String,
        openAiApiKey: String,
    ): String
}
