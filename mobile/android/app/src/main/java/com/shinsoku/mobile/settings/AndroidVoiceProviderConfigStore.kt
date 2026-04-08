package com.shinsoku.mobile.settings

import android.content.Context
import android.content.SharedPreferences
import com.shinsoku.mobile.speechcore.BailianProviderConfig
import com.shinsoku.mobile.speechcore.OpenAiProviderConfig
import com.shinsoku.mobile.speechcore.SonioxProviderConfig
import com.shinsoku.mobile.speechcore.VoiceProviderConfig
import com.shinsoku.mobile.speechcore.VoiceRecognitionProvider
import com.shinsoku.mobile.speechcore.VoiceProviderConfigStore

class AndroidVoiceProviderConfigStore(context: Context) : VoiceProviderConfigStore {
    private val preferences: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun loadProviderConfig(): VoiceProviderConfig {
        val activeProvider = preferences.getString(KEY_ACTIVE_PROVIDER, null)?.let {
            runCatching { VoiceRecognitionProvider.valueOf(it) }.getOrNull()
        } ?: VoiceRecognitionProvider.AndroidSystem
        return VoiceProviderConfig(
            activeRecognitionProvider = activeProvider,
            openAi = OpenAiProviderConfig(
                baseUrl = preferences.getString(KEY_OPENAI_BASE_URL, OpenAiProviderConfig().baseUrl).orEmpty(),
                apiKey = preferences.getString(KEY_OPENAI_API_KEY, "").orEmpty(),
                transcriptionModel = preferences.getString(
                    KEY_OPENAI_TRANSCRIPTION_MODEL,
                    preferences.getString(KEY_OPENAI_MODEL, OpenAiProviderConfig().transcriptionModel),
                ).orEmpty(),
                postProcessingModel = preferences.getString(
                    KEY_OPENAI_POST_PROCESSING_MODEL,
                    preferences.getString(KEY_OPENAI_MODEL, OpenAiProviderConfig().postProcessingModel),
                ).orEmpty(),
            ),
            soniox = SonioxProviderConfig(
                url = preferences.getString(KEY_SONIOX_URL, SonioxProviderConfig().url).orEmpty(),
                apiKey = preferences.getString(KEY_SONIOX_API_KEY, "").orEmpty(),
                model = preferences.getString(KEY_SONIOX_MODEL, SonioxProviderConfig().model).orEmpty(),
            ),
            bailian = BailianProviderConfig(
                region = preferences.getString(KEY_BAILIAN_REGION, BailianProviderConfig().region).orEmpty(),
                url = preferences.getString(KEY_BAILIAN_URL, BailianProviderConfig().url).orEmpty(),
                apiKey = preferences.getString(KEY_BAILIAN_API_KEY, "").orEmpty(),
                model = preferences.getString(KEY_BAILIAN_MODEL, BailianProviderConfig().model).orEmpty(),
            ),
        )
    }

    override fun saveProviderConfig(config: VoiceProviderConfig) {
        preferences.edit()
            .putString(KEY_ACTIVE_PROVIDER, config.activeRecognitionProvider.name)
            .putString(KEY_OPENAI_BASE_URL, config.openAi.baseUrl)
            .putString(KEY_OPENAI_API_KEY, config.openAi.apiKey)
            .putString(KEY_OPENAI_MODEL, config.openAi.transcriptionModel)
            .putString(KEY_OPENAI_TRANSCRIPTION_MODEL, config.openAi.transcriptionModel)
            .putString(KEY_OPENAI_POST_PROCESSING_MODEL, config.openAi.postProcessingModel)
            .putString(KEY_SONIOX_URL, config.soniox.url)
            .putString(KEY_SONIOX_API_KEY, config.soniox.apiKey)
            .putString(KEY_SONIOX_MODEL, config.soniox.model)
            .putString(KEY_BAILIAN_REGION, config.bailian.region)
            .putString(KEY_BAILIAN_URL, config.bailian.url)
            .putString(KEY_BAILIAN_API_KEY, config.bailian.apiKey)
            .putString(KEY_BAILIAN_MODEL, config.bailian.model)
            .apply()
    }

    fun load(): VoiceProviderConfig = loadProviderConfig()

    fun save(config: VoiceProviderConfig) = saveProviderConfig(config)

    private companion object {
        private const val PREFS_NAME = "shinsoku_voice_provider"
        private const val KEY_ACTIVE_PROVIDER = "active_provider"
        private const val KEY_OPENAI_BASE_URL = "openai_base_url"
        private const val KEY_OPENAI_API_KEY = "openai_api_key"
        private const val KEY_OPENAI_MODEL = "openai_model"
        private const val KEY_OPENAI_TRANSCRIPTION_MODEL = "openai_transcription_model"
        private const val KEY_OPENAI_POST_PROCESSING_MODEL = "openai_post_processing_model"
        private const val KEY_SONIOX_URL = "soniox_url"
        private const val KEY_SONIOX_API_KEY = "soniox_api_key"
        private const val KEY_SONIOX_MODEL = "soniox_model"
        private const val KEY_BAILIAN_REGION = "bailian_region"
        private const val KEY_BAILIAN_URL = "bailian_url"
        private const val KEY_BAILIAN_API_KEY = "bailian_api_key"
        private const val KEY_BAILIAN_MODEL = "bailian_model"
    }
}
