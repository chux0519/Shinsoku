package com.shinsoku.mobile.history

import android.content.Context
import android.content.SharedPreferences
import com.shinsoku.mobile.speechcore.CommitSuffixMode
import com.shinsoku.mobile.speechcore.VoiceInputHistoryEntry
import com.shinsoku.mobile.speechcore.VoiceInputHistoryStore
import org.json.JSONArray
import org.json.JSONObject

class AndroidVoiceInputHistoryStore(context: Context) : VoiceInputHistoryStore {
    private val preferences: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun listEntries(limit: Int): List<VoiceInputHistoryEntry> {
        val raw = preferences.getString(KEY_HISTORY_JSON, "[]").orEmpty()
        val json = runCatching { JSONArray(raw) }.getOrElse { JSONArray() }
        val entries = mutableListOf<VoiceInputHistoryEntry>()
        for (index in 0 until json.length()) {
            val item = json.optJSONObject(index) ?: continue
            entries += VoiceInputHistoryEntry(
                id = item.optString("id"),
                text = item.optString("text"),
                committedAtEpochMillis = item.optLong("committedAtEpochMillis"),
                autoCommit = item.optBoolean("autoCommit"),
                commitSuffixMode = item.optString("commitSuffixMode")
                    .takeIf { it.isNotBlank() }
                    ?.let { runCatching { CommitSuffixMode.valueOf(it) }.getOrNull() }
                    ?: CommitSuffixMode.Space,
                languageTag = item.optString("languageTag").takeIf { it.isNotBlank() },
            )
        }
        return entries.sortedByDescending { it.committedAtEpochMillis }.take(limit)
    }

    override fun appendEntry(entry: VoiceInputHistoryEntry) {
        val updated = listEntries(limit = MAX_ENTRIES - 1).toMutableList()
        updated.add(0, entry)
        persist(updated.take(MAX_ENTRIES))
    }

    override fun clear() {
        preferences.edit().remove(KEY_HISTORY_JSON).apply()
    }

    private fun persist(entries: List<VoiceInputHistoryEntry>) {
        val json = JSONArray()
        entries.forEach { entry ->
            json.put(
                JSONObject()
                    .put("id", entry.id)
                    .put("text", entry.text)
                    .put("committedAtEpochMillis", entry.committedAtEpochMillis)
                    .put("autoCommit", entry.autoCommit)
                    .put("commitSuffixMode", entry.commitSuffixMode.name)
                    .put("languageTag", entry.languageTag ?: ""),
            )
        }
        preferences.edit().putString(KEY_HISTORY_JSON, json.toString()).apply()
    }

    companion object {
        private const val PREFS_NAME = "shinsoku_voice_input_history"
        private const val KEY_HISTORY_JSON = "history_json"
        private const val MAX_ENTRIES = 100
    }
}
