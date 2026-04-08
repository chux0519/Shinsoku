package com.shinsoku.mobile.settings

import android.content.Context
import android.content.SharedPreferences
import com.shinsoku.mobile.speechcore.OpenAiPostProcessingConfig
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
        val legacyBaseUrl = preferences.getString(KEY_OPENAI_BASE_URL, OpenAiProviderConfig().baseUrl).orEmpty()
        val legacyApiKey = preferences.getString(KEY_OPENAI_API_KEY, "").orEmpty()
        val legacyModel = preferences.getString(KEY_OPENAI_MODEL, OpenAiProviderConfig().transcriptionModel).orEmpty()
        return VoiceProviderConfig(
            activeRecognitionProvider = activeProvider,
            openAiRecognition = OpenAiProviderConfig(
                baseUrl = preferences.getString(KEY_OPENAI_ASR_BASE_URL, legacyBaseUrl).orEmpty(),
                apiKey = preferences.getString(KEY_OPENAI_ASR_API_KEY, legacyApiKey).orEmpty(),
                transcriptionModel = preferences.getString(
                    KEY_OPENAI_ASR_TRANSCRIPTION_MODEL,
                    preferences.getString(KEY_OPENAI_TRANSCRIPTION_MODEL, legacyModel),
                ).orEmpty(),
                postProcessingModel = preferences.getString(
                    KEY_OPENAI_ASR_POST_PROCESSING_MODEL,
                    preferences.getString(KEY_OPENAI_POST_PROCESSING_MODEL, OpenAiProviderConfig().postProcessingModel),
                ).orEmpty(),
            ),
            openAiPostProcessing = OpenAiPostProcessingConfig(
                baseUrl = preferences.getString(KEY_OPENAI_POST_BASE_URL, legacyBaseUrl).orEmpty(),
                apiKey = preferences.getString(KEY_OPENAI_POST_API_KEY, legacyApiKey).orEmpty(),
                model = preferences.getString(
                    KEY_OPENAI_POST_MODEL,
                    preferences.getString(KEY_OPENAI_POST_PROCESSING_MODEL, legacyModel),
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
            .putString(KEY_OPENAI_BASE_URL, config.openAiRecognition.baseUrl)
            .putString(KEY_OPENAI_API_KEY, config.openAiRecognition.apiKey)
            .putString(KEY_OPENAI_MODEL, config.openAiRecognition.transcriptionModel)
            .putString(KEY_OPENAI_TRANSCRIPTION_MODEL, config.openAiRecognition.transcriptionModel)
            .putString(KEY_OPENAI_POST_PROCESSING_MODEL, config.openAiPostProcessing.model)
            .putString(KEY_OPENAI_ASR_BASE_URL, config.openAiRecognition.baseUrl)
            .putString(KEY_OPENAI_ASR_API_KEY, config.openAiRecognition.apiKey)
            .putString(KEY_OPENAI_ASR_TRANSCRIPTION_MODEL, config.openAiRecognition.transcriptionModel)
            .putString(KEY_OPENAI_ASR_POST_PROCESSING_MODEL, config.openAiRecognition.postProcessingModel)
            .putString(KEY_OPENAI_POST_BASE_URL, config.openAiPostProcessing.baseUrl)
            .putString(KEY_OPENAI_POST_API_KEY, config.openAiPostProcessing.apiKey)
            .putString(KEY_OPENAI_POST_MODEL, config.openAiPostProcessing.model)
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
        private const val KEY_OPENAI_ASR_BASE_URL = "openai_asr_base_url"
        private const val KEY_OPENAI_ASR_API_KEY = "openai_asr_api_key"
        private const val KEY_OPENAI_ASR_TRANSCRIPTION_MODEL = "openai_asr_transcription_model"
        private const val KEY_OPENAI_ASR_POST_PROCESSING_MODEL = "openai_asr_post_processing_model"
        private const val KEY_OPENAI_POST_BASE_URL = "openai_post_base_url"
        private const val KEY_OPENAI_POST_API_KEY = "openai_post_api_key"
        private const val KEY_OPENAI_POST_MODEL = "openai_post_model"
        private const val KEY_SONIOX_URL = "soniox_url"
        private const val KEY_SONIOX_API_KEY = "soniox_api_key"
        private const val KEY_SONIOX_MODEL = "soniox_model"
        private const val KEY_BAILIAN_REGION = "bailian_region"
        private const val KEY_BAILIAN_URL = "bailian_url"
        private const val KEY_BAILIAN_API_KEY = "bailian_api_key"
        private const val KEY_BAILIAN_MODEL = "bailian_model"
    }
}
