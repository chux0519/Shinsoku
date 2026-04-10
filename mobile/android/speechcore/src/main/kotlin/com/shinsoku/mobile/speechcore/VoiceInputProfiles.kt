package com.shinsoku.mobile.speechcore

object VoiceInputProfiles {
    private val fallbackBuiltIns: List<VoiceInputProfile> = listOf(
        VoiceInputProfile(
            id = "dictation",
            displayName = "Dictation",
            autoCommit = true,
            commitSuffixMode = CommitSuffixMode.Space,
            languageTag = null,
        ),
        VoiceInputProfile(
            id = "chat",
            displayName = "Chat",
            autoCommit = true,
            commitSuffixMode = CommitSuffixMode.Newline,
            languageTag = null,
        ),
        VoiceInputProfile(
            id = "review",
            displayName = "Review",
            autoCommit = false,
            commitSuffixMode = CommitSuffixMode.None,
            languageTag = null,
        ),
        VoiceInputProfile(
            id = "translate_zh_en",
            displayName = "Zh→En",
            autoCommit = true,
            commitSuffixMode = CommitSuffixMode.Space,
            languageTag = "zh-CN",
            transform = VoiceTransformConfig(
                enabled = true,
                mode = VoiceTransformMode.Translation,
                requestFormat = VoiceRefineRequestFormat.SystemAndUser,
                translationSourceLanguage = "Chinese",
                translationSourceCode = "zh",
                translationTargetLanguage = "English",
                translationTargetCode = "en",
            ),
        ),
    )

    val builtIns: List<VoiceInputProfile> = NativeVoiceProfiles.loadBuiltIns() ?: fallbackBuiltIns

    val dictation: VoiceInputProfile = builtInById("dictation") ?: fallbackBuiltIns[0]
    val chat: VoiceInputProfile = builtInById("chat") ?: fallbackBuiltIns[1]
    val review: VoiceInputProfile = builtInById("review") ?: fallbackBuiltIns[2]
    val translateChineseToEnglish: VoiceInputProfile = builtInById("translate_zh_en") ?: fallbackBuiltIns[3]

    fun builtInById(id: String?): VoiceInputProfile? =
        builtIns.firstOrNull { it.id == id }

    fun identify(profile: VoiceInputProfile): VoiceInputProfile? =
        builtIns.firstOrNull {
                it.autoCommit == profile.autoCommit &&
                it.commitSuffixMode == profile.commitSuffixMode &&
                it.languageTag == profile.languageTag &&
                it.transform == profile.transform
        }
}
