package com.shinsoku.mobile.speechcore

data class VoiceInputProfile(
    val id: String = "default",
    val displayName: String = "Default Dictation",
    val languageTag: String? = null,
    val autoCommit: Boolean = true,
    val commitSuffixMode: CommitSuffixMode = CommitSuffixMode.Space,
    val transform: VoiceTransformConfig = VoiceTransformConfig(),
)

enum class CommitSuffixMode {
    None,
    Space,
    Newline,
}

enum class VoiceTransformMode {
    Cleanup,
    Translation,
    CustomPrompt,
}

enum class VoiceRefineRequestFormat {
    SystemAndUser,
    SingleUserMessage,
}

data class VoiceTransformConfig(
    val enabled: Boolean = false,
    val mode: VoiceTransformMode = VoiceTransformMode.Cleanup,
    val requestFormat: VoiceRefineRequestFormat = VoiceRefineRequestFormat.SystemAndUser,
    val customPrompt: String = "",
    val translationSourceLanguage: String = "Chinese",
    val translationSourceCode: String = "zh",
    val translationTargetLanguage: String = "English",
    val translationTargetCode: String = "en",
    val translationExtraInstructions: String = "",
)
