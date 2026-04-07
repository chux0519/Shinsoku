package com.shinsoku.mobile.settings

import android.content.Context
import android.content.SharedPreferences
import com.shinsoku.mobile.speechcore.CommitSuffixMode
import com.shinsoku.mobile.speechcore.VoiceInputConfigStore
import com.shinsoku.mobile.speechcore.VoiceInputProfile

class AndroidVoiceInputConfigStore(context: Context) : VoiceInputConfigStore {
    private val preferences: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun loadProfile(): VoiceInputProfile {
        val languageTag = preferences.getString(KEY_LANGUAGE_TAG, "")?.trim().orEmpty()
        val legacyAppendTrailingSpace = preferences.getBoolean(KEY_APPEND_TRAILING_SPACE, true)
        val suffixMode = preferences.getString(KEY_COMMIT_SUFFIX_MODE, null)?.let {
            runCatching { CommitSuffixMode.valueOf(it) }.getOrNull()
        } ?: if (legacyAppendTrailingSpace) {
            CommitSuffixMode.Space
        } else {
            CommitSuffixMode.None
        }
        return VoiceInputProfile(
            id = "default",
            displayName = "Default Dictation",
            languageTag = languageTag.ifEmpty { null },
            autoCommit = preferences.getBoolean(KEY_AUTO_COMMIT, true),
            commitSuffixMode = suffixMode,
        )
    }

    fun saveAutoCommit(enabled: Boolean) {
        preferences.edit().putBoolean(KEY_AUTO_COMMIT, enabled).apply()
    }

    fun saveAppendTrailingSpace(enabled: Boolean) {
        preferences.edit().putBoolean(KEY_APPEND_TRAILING_SPACE, enabled).apply()
    }

    fun saveCommitSuffixMode(mode: CommitSuffixMode) {
        preferences.edit()
            .putString(KEY_COMMIT_SUFFIX_MODE, mode.name)
            .putBoolean(KEY_APPEND_TRAILING_SPACE, mode == CommitSuffixMode.Space)
            .apply()
    }

    fun saveLanguageTag(languageTag: String) {
        preferences.edit().putString(KEY_LANGUAGE_TAG, languageTag.trim()).apply()
    }

    fun saveProfile(profile: VoiceInputProfile) {
        preferences.edit()
            .putBoolean(KEY_AUTO_COMMIT, profile.autoCommit)
            .putString(KEY_LANGUAGE_TAG, profile.languageTag?.trim().orEmpty())
            .putString(KEY_COMMIT_SUFFIX_MODE, profile.commitSuffixMode.name)
            .putBoolean(KEY_APPEND_TRAILING_SPACE, profile.commitSuffixMode == CommitSuffixMode.Space)
            .apply()
    }

    companion object {
        private const val PREFS_NAME = "shinsoku_voice_input"
        private const val KEY_AUTO_COMMIT = "auto_commit"
        private const val KEY_APPEND_TRAILING_SPACE = "append_trailing_space"
        private const val KEY_COMMIT_SUFFIX_MODE = "commit_suffix_mode"
        private const val KEY_LANGUAGE_TAG = "language_tag"
    }
}
