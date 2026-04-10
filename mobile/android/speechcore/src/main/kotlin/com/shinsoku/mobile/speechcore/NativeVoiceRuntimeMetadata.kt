package com.shinsoku.mobile.speechcore

object NativeVoiceRuntimeMetadata {
    init {
        runCatching { System.loadLibrary("shinsoku_nativecore") }
    }

    data class Metadata(
        val providerLabel: String,
        val postProcessingLabel: String,
        val compactPostProcessingLabel: String,
    )

    fun describe(
        provider: VoiceRecognitionProvider,
        postProcessingMode: TranscriptPostProcessingMode,
    ): Metadata {
        val native = runCatching {
            describeProviderMetadataNative(provider.name, postProcessingMode.name)
        }.getOrNull()
        if (native != null && native.size >= 3) {
            return Metadata(
                providerLabel = native[0].ifBlank { fallbackProviderLabel(provider) },
                postProcessingLabel = native[1].ifBlank { fallbackPostProcessingLabel(postProcessingMode, compact = false) },
                compactPostProcessingLabel = native[2].ifBlank { fallbackPostProcessingLabel(postProcessingMode, compact = true) },
            )
        }
        return Metadata(
            providerLabel = fallbackProviderLabel(provider),
            postProcessingLabel = fallbackPostProcessingLabel(postProcessingMode, compact = false),
            compactPostProcessingLabel = fallbackPostProcessingLabel(postProcessingMode, compact = true),
        )
    }

    private fun fallbackProviderLabel(provider: VoiceRecognitionProvider): String = when (provider) {
        VoiceRecognitionProvider.AndroidSystem -> "Android System"
        VoiceRecognitionProvider.OpenAiCompatible -> "OpenAI-Compatible"
        VoiceRecognitionProvider.Soniox -> "Soniox"
        VoiceRecognitionProvider.Bailian -> "Bailian"
    }

    private fun fallbackPostProcessingLabel(
        mode: TranscriptPostProcessingMode,
        compact: Boolean,
    ): String = when (mode) {
        TranscriptPostProcessingMode.Disabled -> "Disabled"
        TranscriptPostProcessingMode.LocalCleanup -> if (compact) "Local cleanup" else "Local cleanup"
        TranscriptPostProcessingMode.ProviderAssisted -> if (compact) "Provider-assisted" else "Provider-assisted"
    }

    private external fun describeProviderMetadataNative(
        providerName: String,
        postProcessingModeName: String,
    ): Array<String>
}
