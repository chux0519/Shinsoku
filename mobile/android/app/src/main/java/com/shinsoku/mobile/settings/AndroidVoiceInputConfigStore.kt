package com.shinsoku.mobile.settings

import android.content.Context
import android.content.SharedPreferences
import com.shinsoku.mobile.speechcore.CommitSuffixMode
import com.shinsoku.mobile.speechcore.VoiceInputConfigStore
import com.shinsoku.mobile.speechcore.VoiceInputProfile
import com.shinsoku.mobile.speechcore.VoiceInputProfiles

class AndroidVoiceInputConfigStore(context: Context) : VoiceInputConfigStore {
    private val preferences: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun loadProfile(): VoiceInputProfile {
        val storedProfileId = preferences.getString(KEY_PROFILE_ID, null)
        val storedProfileName = preferences.getString(KEY_PROFILE_NAME, null)
        val languageTag = preferences.getString(KEY_LANGUAGE_TAG, "")?.trim().orEmpty()
        val legacyAppendTrailingSpace = preferences.getBoolean(KEY_APPEND_TRAILING_SPACE, true)
        val suffixMode = preferences.getString(KEY_COMMIT_SUFFIX_MODE, null)?.let {
            runCatching { CommitSuffixMode.valueOf(it) }.getOrNull()
        } ?: if (legacyAppendTrailingSpace) {
            CommitSuffixMode.Space
        } else {
            CommitSuffixMode.None
        }
        val manualProfile = VoiceInputProfile(
            id = storedProfileId ?: "custom",
            displayName = storedProfileName ?: "Custom",
            languageTag = languageTag.ifEmpty { null },
            autoCommit = preferences.getBoolean(KEY_AUTO_COMMIT, true),
            commitSuffixMode = suffixMode,
        )
        return VoiceInputProfiles.identify(manualProfile)
            ?: VoiceInputProfiles.builtInById(storedProfileId)
            ?: manualProfile
    }

    fun saveAutoCommit(enabled: Boolean) {
        val current = loadProfile()
        saveProfile(
            current.copy(
                id = "custom",
                displayName = "Custom",
                autoCommit = enabled,
            ),
        )
    }

    fun saveAppendTrailingSpace(enabled: Boolean) {
        preferences.edit().putBoolean(KEY_APPEND_TRAILING_SPACE, enabled).apply()
    }

    fun saveCommitSuffixMode(mode: CommitSuffixMode) {
        val current = loadProfile()
        saveProfile(
            current.copy(
                id = "custom",
                displayName = "Custom",
                commitSuffixMode = mode,
            ),
        )
    }

    fun saveLanguageTag(languageTag: String) {
        val current = loadProfile()
        saveProfile(
            current.copy(
                id = "custom",
                displayName = "Custom",
                languageTag = languageTag.trim().ifEmpty { null },
            ),
        )
    }

    fun saveProfile(profile: VoiceInputProfile) {
        val normalized = VoiceInputProfiles.identify(profile) ?: profile
        preferences.edit()
            .putString(KEY_PROFILE_ID, normalized.id)
            .putString(KEY_PROFILE_NAME, normalized.displayName)
            .putBoolean(KEY_AUTO_COMMIT, normalized.autoCommit)
            .putString(KEY_LANGUAGE_TAG, normalized.languageTag?.trim().orEmpty())
            .putString(KEY_COMMIT_SUFFIX_MODE, normalized.commitSuffixMode.name)
            .putBoolean(KEY_APPEND_TRAILING_SPACE, normalized.commitSuffixMode == CommitSuffixMode.Space)
            .apply()
    }

    companion object {
        private const val PREFS_NAME = "shinsoku_voice_input"
        private const val KEY_PROFILE_ID = "profile_id"
        private const val KEY_PROFILE_NAME = "profile_name"
        private const val KEY_AUTO_COMMIT = "auto_commit"
        private const val KEY_APPEND_TRAILING_SPACE = "append_trailing_space"
        private const val KEY_COMMIT_SUFFIX_MODE = "commit_suffix_mode"
        private const val KEY_LANGUAGE_TAG = "language_tag"
    }
}
