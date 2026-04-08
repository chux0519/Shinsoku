package com.shinsoku.mobile.speechcore

enum class TranscriptPostProcessingMode {
    Disabled,
    LocalCleanup,
    ProviderAssisted,
}

data class VoicePostProcessingConfig(
    val mode: TranscriptPostProcessingMode = TranscriptPostProcessingMode.LocalCleanup,
)
