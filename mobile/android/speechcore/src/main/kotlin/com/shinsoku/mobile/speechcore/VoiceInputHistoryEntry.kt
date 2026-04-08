package com.shinsoku.mobile.speechcore

data class VoiceInputHistoryEntry(
    val id: String,
    val text: String,
    val committedAtEpochMillis: Long,
    val provider: String,
    val profileName: String,
    val transformMode: String,
    val postProcessingMode: String,
    val autoCommit: Boolean,
    val commitSuffixMode: CommitSuffixMode,
    val languageTag: String?,
    val debugDetail: String? = null,
)
