package com.shinsoku.mobile.speechcore

interface VoiceProviderConfigStore {
    fun loadProviderConfig(): VoiceProviderConfig

    fun saveProviderConfig(config: VoiceProviderConfig)
}
