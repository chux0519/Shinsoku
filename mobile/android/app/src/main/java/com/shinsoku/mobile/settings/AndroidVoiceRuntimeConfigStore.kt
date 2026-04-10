package com.shinsoku.mobile.settings

import android.content.Context
import android.content.SharedPreferences
import com.shinsoku.mobile.processing.NativeVoiceRuntime
import com.shinsoku.mobile.speechcore.TranscriptPostProcessingMode
import com.shinsoku.mobile.speechcore.VoicePostProcessingConfig
import com.shinsoku.mobile.speechcore.VoiceRuntimeConfig
import com.shinsoku.mobile.speechcore.VoiceRuntimeConfigStore

class AndroidVoiceRuntimeConfigStore(
    context: Context,
) : VoiceRuntimeConfigStore {
    private val preferences: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val profileStore = AndroidVoiceInputConfigStore(context)
    private val providerStore = AndroidVoiceProviderConfigStore(context)

    override fun loadRuntimeConfig(): VoiceRuntimeConfig {
        val providerConfig = providerStore.loadProviderConfig()
        val requestedMode = preferences.getString(KEY_POST_PROCESSING_MODE, null)
            ?.let { runCatching { TranscriptPostProcessingMode.valueOf(it) }.getOrNull() }
            ?: TranscriptPostProcessingMode.ProviderAssisted
        val effectiveMode = NativeVoiceRuntime.resolvePostProcessingMode(
            requestedMode = requestedMode,
            activeProviderName = providerConfig.activeRecognitionProvider.name,
            openAiApiKey = providerConfig.openAiPostProcessing.apiKey,
        )

        return VoiceRuntimeConfig(
            profile = profileStore.loadProfile(),
            providerConfig = providerConfig,
            postProcessingConfig = VoicePostProcessingConfig(
                mode = effectiveMode,
            ),
        )
    }

    fun savePostProcessingMode(mode: TranscriptPostProcessingMode) {
        preferences.edit().putString(KEY_POST_PROCESSING_MODE, mode.name).apply()
    }

    companion object {
        private const val PREFS_NAME = "shinsoku_voice_runtime"
        private const val KEY_POST_PROCESSING_MODE = "post_processing_mode"
    }
}
