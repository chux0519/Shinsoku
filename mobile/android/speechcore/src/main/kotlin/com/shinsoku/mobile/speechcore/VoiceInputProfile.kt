package com.shinsoku.mobile.speechcore

data class VoiceInputProfile(
    val id: String = "default",
    val displayName: String = "Default Dictation",
    val languageTag: String? = null,
    val autoCommit: Boolean = true,
    val appendTrailingSpace: Boolean = true,
)
