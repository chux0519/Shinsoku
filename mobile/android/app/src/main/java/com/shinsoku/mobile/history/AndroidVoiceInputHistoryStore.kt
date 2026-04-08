package com.shinsoku.mobile.history

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.shinsoku.mobile.speechcore.CommitSuffixMode
import com.shinsoku.mobile.speechcore.VoiceInputHistoryEntry
import com.shinsoku.mobile.speechcore.VoiceInputHistorySchema
import com.shinsoku.mobile.speechcore.VoiceInputHistoryStore
import org.json.JSONArray

class AndroidVoiceInputHistoryStore(context: Context) : VoiceInputHistoryStore {
    private val appContext = context.applicationContext
    private val database = HistoryDatabase(appContext)

    override fun listEntries(limit: Int): List<VoiceInputHistoryEntry> {
        migrateLegacyHistoryIfNeeded()

        val entries = mutableListOf<VoiceInputHistoryEntry>()
        database.readableDatabase.query(
            VoiceInputHistorySchema.TABLE_HISTORY,
            null,
            null,
            null,
            null,
            null,
            "${VoiceInputHistorySchema.COLUMN_COMMITTED_AT_EPOCH_MILLIS} DESC",
            limit.toString(),
        ).use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(VoiceInputHistorySchema.COLUMN_ID)
            val textIndex = cursor.getColumnIndexOrThrow(VoiceInputHistorySchema.COLUMN_TEXT)
            val committedAtIndex = cursor.getColumnIndexOrThrow(VoiceInputHistorySchema.COLUMN_COMMITTED_AT_EPOCH_MILLIS)
            val providerIndex = cursor.getColumnIndexOrThrow(VoiceInputHistorySchema.COLUMN_PROVIDER)
            val autoCommitIndex = cursor.getColumnIndexOrThrow(VoiceInputHistorySchema.COLUMN_AUTO_COMMIT)
            val suffixModeIndex = cursor.getColumnIndexOrThrow(VoiceInputHistorySchema.COLUMN_COMMIT_SUFFIX_MODE)
            val languageTagIndex = cursor.getColumnIndexOrThrow(VoiceInputHistorySchema.COLUMN_LANGUAGE_TAG)

            while (cursor.moveToNext()) {
                entries += VoiceInputHistoryEntry(
                    id = cursor.getString(idIndex),
                    text = cursor.getString(textIndex),
                    committedAtEpochMillis = cursor.getLong(committedAtIndex),
                    provider = cursor.getString(providerIndex),
                    autoCommit = cursor.getInt(autoCommitIndex) != 0,
                    commitSuffixMode = cursor.getString(suffixModeIndex)
                        ?.takeIf { it.isNotBlank() }
                        ?.let { runCatching { CommitSuffixMode.valueOf(it) }.getOrNull() }
                        ?: CommitSuffixMode.Space,
                    languageTag = cursor.getString(languageTagIndex)?.takeIf { it.isNotBlank() },
                )
            }
        }
        return entries
    }

    override fun appendEntry(entry: VoiceInputHistoryEntry) {
        migrateLegacyHistoryIfNeeded()

        database.writableDatabase.beginTransaction()
        try {
            database.writableDatabase.insertWithOnConflict(
                VoiceInputHistorySchema.TABLE_HISTORY,
                null,
                entry.toContentValues(),
                SQLiteDatabase.CONFLICT_REPLACE,
            )

            database.writableDatabase.execSQL(
                """
                DELETE FROM ${VoiceInputHistorySchema.TABLE_HISTORY}
                WHERE ${VoiceInputHistorySchema.COLUMN_ID} NOT IN (
                    SELECT ${VoiceInputHistorySchema.COLUMN_ID}
                    FROM ${VoiceInputHistorySchema.TABLE_HISTORY}
                    ORDER BY ${VoiceInputHistorySchema.COLUMN_COMMITTED_AT_EPOCH_MILLIS} DESC
                    LIMIT $MAX_ENTRIES
                )
                """.trimIndent(),
            )

            database.writableDatabase.setTransactionSuccessful()
        } finally {
            database.writableDatabase.endTransaction()
        }
    }

    override fun clear() {
        database.writableDatabase.delete(VoiceInputHistorySchema.TABLE_HISTORY, null, null)
        clearLegacyHistory()
    }

    private fun migrateLegacyHistoryIfNeeded() {
        val legacyPreferences = appContext.getSharedPreferences(LEGACY_PREFS_NAME, Context.MODE_PRIVATE)
        val raw = legacyPreferences.getString(LEGACY_KEY_HISTORY_JSON, null).orEmpty()
        if (raw.isBlank()) {
            return
        }

        val existingCount = database.readableDatabase.rawQuery(
            "SELECT COUNT(*) FROM ${VoiceInputHistorySchema.TABLE_HISTORY}",
            null,
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                cursor.getLong(0)
            } else {
                0L
            }
        }
        if (existingCount > 0L) {
            clearLegacyHistory()
            return
        }

        val json = runCatching { JSONArray(raw) }.getOrNull() ?: return
        database.writableDatabase.beginTransaction()
        try {
            for (index in 0 until json.length()) {
                val item = json.optJSONObject(index) ?: continue
                val entry = VoiceInputHistoryEntry(
                    id = item.optString("id"),
                    text = item.optString("text"),
                    committedAtEpochMillis = item.optLong("committedAtEpochMillis"),
                    provider = item.optString("provider"),
                    autoCommit = item.optBoolean("autoCommit"),
                    commitSuffixMode = item.optString("commitSuffixMode")
                        .takeIf { it.isNotBlank() }
                        ?.let { runCatching { CommitSuffixMode.valueOf(it) }.getOrNull() }
                        ?: CommitSuffixMode.Space,
                    languageTag = item.optString("languageTag").takeIf { it.isNotBlank() },
                )
                database.writableDatabase.insertWithOnConflict(
                    VoiceInputHistorySchema.TABLE_HISTORY,
                    null,
                    entry.toContentValues(),
                    SQLiteDatabase.CONFLICT_REPLACE,
                )
            }
            database.writableDatabase.setTransactionSuccessful()
        } finally {
            database.writableDatabase.endTransaction()
        }

        clearLegacyHistory()
    }

    private fun clearLegacyHistory() {
        appContext.getSharedPreferences(LEGACY_PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(LEGACY_KEY_HISTORY_JSON)
            .apply()
    }

    private fun VoiceInputHistoryEntry.toContentValues(): ContentValues =
        ContentValues().apply {
            put(VoiceInputHistorySchema.COLUMN_ID, id)
            put(VoiceInputHistorySchema.COLUMN_TEXT, text)
            put(VoiceInputHistorySchema.COLUMN_COMMITTED_AT_EPOCH_MILLIS, committedAtEpochMillis)
            put(VoiceInputHistorySchema.COLUMN_PROVIDER, provider)
            put(VoiceInputHistorySchema.COLUMN_AUTO_COMMIT, if (autoCommit) 1 else 0)
            put(VoiceInputHistorySchema.COLUMN_COMMIT_SUFFIX_MODE, commitSuffixMode.name)
            put(VoiceInputHistorySchema.COLUMN_LANGUAGE_TAG, languageTag.orEmpty())
        }

    private class HistoryDatabase(
        context: Context,
    ) : SQLiteOpenHelper(
        context,
        VoiceInputHistorySchema.DATABASE_NAME,
        null,
        VoiceInputHistorySchema.DATABASE_VERSION,
    ) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE ${VoiceInputHistorySchema.TABLE_HISTORY} (
                    ${VoiceInputHistorySchema.COLUMN_ID} TEXT PRIMARY KEY NOT NULL,
                    ${VoiceInputHistorySchema.COLUMN_TEXT} TEXT NOT NULL,
                    ${VoiceInputHistorySchema.COLUMN_COMMITTED_AT_EPOCH_MILLIS} INTEGER NOT NULL,
                    ${VoiceInputHistorySchema.COLUMN_PROVIDER} TEXT NOT NULL,
                    ${VoiceInputHistorySchema.COLUMN_AUTO_COMMIT} INTEGER NOT NULL,
                    ${VoiceInputHistorySchema.COLUMN_COMMIT_SUFFIX_MODE} TEXT NOT NULL,
                    ${VoiceInputHistorySchema.COLUMN_LANGUAGE_TAG} TEXT NOT NULL
                )
                """.trimIndent(),
            )
            db.execSQL(
                """
                CREATE INDEX idx_voice_input_history_committed_at
                ON ${VoiceInputHistorySchema.TABLE_HISTORY} (${VoiceInputHistorySchema.COLUMN_COMMITTED_AT_EPOCH_MILLIS} DESC)
                """.trimIndent(),
            )
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            if (oldVersion == newVersion) {
                return
            }
            db.execSQL("DROP TABLE IF EXISTS ${VoiceInputHistorySchema.TABLE_HISTORY}")
            onCreate(db)
        }
    }

    companion object {
        private const val MAX_ENTRIES = 100
        private const val LEGACY_PREFS_NAME = "shinsoku_voice_input_history"
        private const val LEGACY_KEY_HISTORY_JSON = "history_json"
    }
}
