package com.shinsoku.mobile.settings

import android.content.Context
import android.content.SharedPreferences
import com.shinsoku.mobile.speechcore.BailianProviderConfig
import com.shinsoku.mobile.speechcore.OpenAiProviderConfig
import com.shinsoku.mobile.speechcore.SonioxProviderConfig
import com.shinsoku.mobile.speechcore.VoiceProviderConfig
import com.shinsoku.mobile.speechcore.VoiceRecognitionProvider

class AndroidVoiceProviderConfigStore(context: Context) {
    private val preferences: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun load(): VoiceProviderConfig {
        val activeProvider = preferences.getString(KEY_ACTIVE_PROVIDER, null)?.let {
            runCatching { VoiceRecognitionProvider.valueOf(it) }.getOrNull()
        } ?: VoiceRecognitionProvider.AndroidSystem
        return VoiceProviderConfig(
            activeRecognitionProvider = activeProvider,
            openAi = OpenAiProviderConfig(
                baseUrl = preferences.getString(KEY_OPENAI_BASE_URL, OpenAiProviderConfig().baseUrl).orEmpty(),
                apiKey = preferences.getString(KEY_OPENAI_API_KEY, "").orEmpty(),
                model = preferences.getString(KEY_OPENAI_MODEL, OpenAiProviderConfig().model).orEmpty(),
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

    fun save(config: VoiceProviderConfig) {
        preferences.edit()
            .putString(KEY_ACTIVE_PROVIDER, config.activeRecognitionProvider.name)
            .putString(KEY_OPENAI_BASE_URL, config.openAi.baseUrl)
            .putString(KEY_OPENAI_API_KEY, config.openAi.apiKey)
            .putString(KEY_OPENAI_MODEL, config.openAi.model)
            .putString(KEY_SONIOX_URL, config.soniox.url)
            .putString(KEY_SONIOX_API_KEY, config.soniox.apiKey)
            .putString(KEY_SONIOX_MODEL, config.soniox.model)
            .putString(KEY_BAILIAN_REGION, config.bailian.region)
            .putString(KEY_BAILIAN_URL, config.bailian.url)
            .putString(KEY_BAILIAN_API_KEY, config.bailian.apiKey)
            .putString(KEY_BAILIAN_MODEL, config.bailian.model)
            .apply()
    }

    private companion object {
        private const val PREFS_NAME = "shinsoku_voice_provider"
        private const val KEY_ACTIVE_PROVIDER = "active_provider"
        private const val KEY_OPENAI_BASE_URL = "openai_base_url"
        private const val KEY_OPENAI_API_KEY = "openai_api_key"
        private const val KEY_OPENAI_MODEL = "openai_model"
        private const val KEY_SONIOX_URL = "soniox_url"
        private const val KEY_SONIOX_API_KEY = "soniox_api_key"
        private const val KEY_SONIOX_MODEL = "soniox_model"
        private const val KEY_BAILIAN_REGION = "bailian_region"
        private const val KEY_BAILIAN_URL = "bailian_url"
        private const val KEY_BAILIAN_API_KEY = "bailian_api_key"
        private const val KEY_BAILIAN_MODEL = "bailian_model"
    }
}
