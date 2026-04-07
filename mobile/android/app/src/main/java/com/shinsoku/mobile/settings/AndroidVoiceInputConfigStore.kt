package com.shinsoku.mobile.settings

import android.content.Context
import android.content.SharedPreferences
import com.shinsoku.mobile.speechcore.VoiceInputConfigStore
import com.shinsoku.mobile.speechcore.VoiceInputProfile

class AndroidVoiceInputConfigStore(context: Context) : VoiceInputConfigStore {
    private val preferences: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun loadProfile(): VoiceInputProfile {
        val languageTag = preferences.getString(KEY_LANGUAGE_TAG, "")?.trim().orEmpty()
        return VoiceInputProfile(
            id = "default",
            displayName = "Default Dictation",
            languageTag = languageTag.ifEmpty { null },
            autoCommit = preferences.getBoolean(KEY_AUTO_COMMIT, true),
            appendTrailingSpace = preferences.getBoolean(KEY_APPEND_TRAILING_SPACE, true),
        )
    }

    fun saveAutoCommit(enabled: Boolean) {
        preferences.edit().putBoolean(KEY_AUTO_COMMIT, enabled).apply()
    }

    fun saveAppendTrailingSpace(enabled: Boolean) {
        preferences.edit().putBoolean(KEY_APPEND_TRAILING_SPACE, enabled).apply()
    }

    fun saveLanguageTag(languageTag: String) {
        preferences.edit().putString(KEY_LANGUAGE_TAG, languageTag.trim()).apply()
    }

    companion object {
        private const val PREFS_NAME = "shinsoku_voice_input"
        private const val KEY_AUTO_COMMIT = "auto_commit"
        private const val KEY_APPEND_TRAILING_SPACE = "append_trailing_space"
        private const val KEY_LANGUAGE_TAG = "language_tag"
    }
}
