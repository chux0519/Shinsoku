package com.shinsoku.mobile.settings

import android.content.Context
import android.content.SharedPreferences
import com.shinsoku.mobile.speechcore.CommitSuffixMode
import com.shinsoku.mobile.speechcore.VoiceRefineRequestFormat
import com.shinsoku.mobile.speechcore.VoiceInputConfigStore
import com.shinsoku.mobile.speechcore.VoiceInputProfile
import com.shinsoku.mobile.speechcore.VoiceInputProfiles
import com.shinsoku.mobile.speechcore.VoiceTransformConfig
import com.shinsoku.mobile.speechcore.VoiceTransformMode

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
            transform = VoiceTransformConfig(
                enabled = preferences.getBoolean(KEY_TRANSFORM_ENABLED, false),
                mode = preferences.getString(KEY_TRANSFORM_MODE, null)?.let {
                    runCatching { VoiceTransformMode.valueOf(it) }.getOrNull()
                } ?: VoiceTransformMode.Cleanup,
                requestFormat = preferences.getString(KEY_TRANSFORM_REQUEST_FORMAT, null)?.let {
                    runCatching { VoiceRefineRequestFormat.valueOf(it) }.getOrNull()
                } ?: VoiceRefineRequestFormat.SystemAndUser,
                customPrompt = preferences.getString(KEY_TRANSFORM_CUSTOM_PROMPT, "")?.trim().orEmpty(),
                translationSourceLanguage = preferences.getString(KEY_TRANSLATION_SOURCE_LANGUAGE, "Chinese").orEmpty(),
                translationSourceCode = preferences.getString(KEY_TRANSLATION_SOURCE_CODE, "zh").orEmpty(),
                translationTargetLanguage = preferences.getString(KEY_TRANSLATION_TARGET_LANGUAGE, "English").orEmpty(),
                translationTargetCode = preferences.getString(KEY_TRANSLATION_TARGET_CODE, "en").orEmpty(),
                translationExtraInstructions = preferences.getString(KEY_TRANSLATION_EXTRA_INSTRUCTIONS, "")?.trim().orEmpty(),
            ),
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

    fun saveTransform(config: VoiceTransformConfig) {
        val current = loadProfile()
        saveProfile(
            current.copy(
                id = "custom",
                displayName = "Custom",
                transform = config,
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
            .putBoolean(KEY_TRANSFORM_ENABLED, normalized.transform.enabled)
            .putString(KEY_TRANSFORM_MODE, normalized.transform.mode.name)
            .putString(KEY_TRANSFORM_REQUEST_FORMAT, normalized.transform.requestFormat.name)
            .putString(KEY_TRANSFORM_CUSTOM_PROMPT, normalized.transform.customPrompt)
            .putString(KEY_TRANSLATION_SOURCE_LANGUAGE, normalized.transform.translationSourceLanguage)
            .putString(KEY_TRANSLATION_SOURCE_CODE, normalized.transform.translationSourceCode)
            .putString(KEY_TRANSLATION_TARGET_LANGUAGE, normalized.transform.translationTargetLanguage)
            .putString(KEY_TRANSLATION_TARGET_CODE, normalized.transform.translationTargetCode)
            .putString(KEY_TRANSLATION_EXTRA_INSTRUCTIONS, normalized.transform.translationExtraInstructions)
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
        private const val KEY_TRANSFORM_ENABLED = "transform_enabled"
        private const val KEY_TRANSFORM_MODE = "transform_mode"
        private const val KEY_TRANSFORM_REQUEST_FORMAT = "transform_request_format"
        private const val KEY_TRANSFORM_CUSTOM_PROMPT = "transform_custom_prompt"
        private const val KEY_TRANSLATION_SOURCE_LANGUAGE = "translation_source_language"
        private const val KEY_TRANSLATION_SOURCE_CODE = "translation_source_code"
        private const val KEY_TRANSLATION_TARGET_LANGUAGE = "translation_target_language"
        private const val KEY_TRANSLATION_TARGET_CODE = "translation_target_code"
        private const val KEY_TRANSLATION_EXTRA_INSTRUCTIONS = "translation_extra_instructions"
    }
}
