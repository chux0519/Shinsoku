package com.shinsoku.mobile.speechcore

interface VoiceInputHistoryStore {
    fun listEntries(limit: Int = 50): List<VoiceInputHistoryEntry>

    fun appendEntry(entry: VoiceInputHistoryEntry)

    fun clear()
}
