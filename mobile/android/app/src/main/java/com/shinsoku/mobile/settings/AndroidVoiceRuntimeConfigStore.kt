package com.shinsoku.mobile.settings

import android.content.Context
import com.shinsoku.mobile.processing.NativeVoiceRuntime
import com.shinsoku.mobile.speechcore.VoicePostProcessingConfig
import com.shinsoku.mobile.speechcore.VoiceRuntimeConfig
import com.shinsoku.mobile.speechcore.VoiceRuntimeConfigStore

class AndroidVoiceRuntimeConfigStore(
    context: Context,
) : VoiceRuntimeConfigStore {
    private val profileStore = AndroidVoiceInputConfigStore(context)
    private val providerStore = AndroidVoiceProviderConfigStore(context)

    override fun loadRuntimeConfig(): VoiceRuntimeConfig {
        val providerConfig = providerStore.loadProviderConfig()
        return VoiceRuntimeConfig(
            profile = profileStore.loadProfile(),
            providerConfig = providerConfig,
            postProcessingConfig = VoicePostProcessingConfig(
                mode = NativeVoiceRuntime.derivePostProcessingMode(
                    activeProviderName = providerConfig.activeRecognitionProvider.name,
                    openAiApiKey = providerConfig.openAi.apiKey,
                ),
            ),
        )
    }
}
