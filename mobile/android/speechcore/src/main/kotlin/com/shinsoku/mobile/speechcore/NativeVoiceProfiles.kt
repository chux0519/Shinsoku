package com.shinsoku.mobile.speechcore

import org.json.JSONArray

object NativeVoiceProfiles {
    init {
        runCatching { System.loadLibrary("shinsoku_nativecore") }
    }

    fun loadBuiltIns(): List<VoiceInputProfile>? {
        val raw = runCatching { builtinProfilesJsonNative() }.getOrNull().orEmpty()
        if (raw.isBlank()) {
            return null
        }

        return runCatching {
            val json = JSONArray(raw)
            buildList {
                for (index in 0 until json.length()) {
                    val item = json.optJSONObject(index) ?: continue
                    val transformJson = item.optJSONObject("transform")
                    add(
                        VoiceInputProfile(
                            id = item.optString("id"),
                            displayName = item.optString("display_name"),
                            summary = item.optString("summary"),
                            nativeBehaviorSummary = item.optString("behavior_summary"),
                            languageTag = item.optString("language_tag").ifBlank { null },
                            autoCommit = item.optBoolean("auto_commit", true),
                            commitSuffixMode = runCatching {
                                CommitSuffixMode.valueOf(item.optString("commit_suffix_mode"))
                            }.getOrDefault(CommitSuffixMode.Space),
                            transform = VoiceTransformConfig(
                                enabled = transformJson?.optBoolean("enabled", false) ?: false,
                                mode = runCatching {
                                    VoiceTransformMode.valueOf(transformJson?.optString("mode").orEmpty())
                                }.getOrDefault(VoiceTransformMode.Cleanup),
                                requestFormat = runCatching {
                                    VoiceRefineRequestFormat.valueOf(transformJson?.optString("request_format").orEmpty())
                                }.getOrDefault(VoiceRefineRequestFormat.SystemAndUser),
                                customPrompt = transformJson?.optString("custom_prompt").orEmpty(),
                                translationSourceLanguage = transformJson?.optString("translation_source_language").orEmpty().ifBlank { "Chinese" },
                                translationSourceCode = transformJson?.optString("translation_source_code").orEmpty().ifBlank { "zh" },
                                translationTargetLanguage = transformJson?.optString("translation_target_language").orEmpty().ifBlank { "English" },
                                translationTargetCode = transformJson?.optString("translation_target_code").orEmpty().ifBlank { "en" },
                                translationExtraInstructions = transformJson?.optString("translation_extra_instructions").orEmpty(),
                            ),
                        ),
                    )
                }
            }
        }.getOrNull()
    }

    fun identifyBuiltIn(profile: VoiceInputProfile): String? {
        return runCatching {
            identifyBuiltInProfileIdNative(
                autoCommit = profile.autoCommit,
                commitSuffixMode = profile.commitSuffixMode.name,
                languageTag = profile.languageTag.orEmpty(),
                transformEnabled = profile.transform.enabled,
                transformMode = profile.transform.mode.name,
                requestFormat = profile.transform.requestFormat.name,
                customPrompt = profile.transform.customPrompt,
                translationSourceLanguage = profile.transform.translationSourceLanguage,
                translationSourceCode = profile.transform.translationSourceCode,
                translationTargetLanguage = profile.transform.translationTargetLanguage,
                translationTargetCode = profile.transform.translationTargetCode,
                translationExtraInstructions = profile.transform.translationExtraInstructions,
            )
        }.getOrNull()?.ifBlank { null }
    }

    fun describeBehavior(profile: VoiceInputProfile): String {
        return runCatching {
            describeProfileBehaviorNative(
                autoCommit = profile.autoCommit,
                commitSuffixMode = profile.commitSuffixMode.name,
            )
        }.getOrNull()?.ifBlank { null } ?: fallbackBehaviorSummary(profile)
    }

    private fun fallbackBehaviorSummary(profile: VoiceInputProfile): String {
        val commitDescription = if (profile.autoCommit) "Auto-insert on" else "Review before insert"
        return "$commitDescription · ${profile.commitSuffixMode.title}"
    }

    private external fun builtinProfilesJsonNative(): String
    private external fun identifyBuiltInProfileIdNative(
        autoCommit: Boolean,
        commitSuffixMode: String,
        languageTag: String,
        transformEnabled: Boolean,
        transformMode: String,
        requestFormat: String,
        customPrompt: String,
        translationSourceLanguage: String,
        translationSourceCode: String,
        translationTargetLanguage: String,
        translationTargetCode: String,
        translationExtraInstructions: String,
    ): String
    private external fun describeProfileBehaviorNative(
        autoCommit: Boolean,
        commitSuffixMode: String,
    ): String
}
