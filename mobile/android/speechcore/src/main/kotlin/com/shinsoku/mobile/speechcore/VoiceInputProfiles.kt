package com.shinsoku.mobile.speechcore

object VoiceInputProfiles {
    val dictation = VoiceInputProfile(
        id = "dictation",
        displayName = "Dictation",
        autoCommit = true,
        commitSuffixMode = CommitSuffixMode.Space,
        languageTag = null,
    )

    val chat = VoiceInputProfile(
        id = "chat",
        displayName = "Chat",
        autoCommit = true,
        commitSuffixMode = CommitSuffixMode.Newline,
        languageTag = null,
    )

    val review = VoiceInputProfile(
        id = "review",
        displayName = "Review Before Insert",
        autoCommit = false,
        commitSuffixMode = CommitSuffixMode.None,
        languageTag = null,
    )

    val builtIns: List<VoiceInputProfile> = listOf(dictation, chat, review)

    fun builtInById(id: String?): VoiceInputProfile? =
        builtIns.firstOrNull { it.id == id }

    fun identify(profile: VoiceInputProfile): VoiceInputProfile? =
        builtIns.firstOrNull {
            it.autoCommit == profile.autoCommit &&
                it.commitSuffixMode == profile.commitSuffixMode &&
                it.languageTag == profile.languageTag
        }
}
