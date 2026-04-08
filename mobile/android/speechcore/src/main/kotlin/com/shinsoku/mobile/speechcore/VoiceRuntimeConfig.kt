package com.shinsoku.mobile.speechcore

data class VoiceRuntimeConfig(
    val profile: VoiceInputProfile,
    val providerConfig: VoiceProviderConfig,
    val postProcessingConfig: VoicePostProcessingConfig = VoicePostProcessingConfig(),
)
