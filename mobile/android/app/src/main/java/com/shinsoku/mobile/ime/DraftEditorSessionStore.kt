package com.shinsoku.mobile.ime

import android.content.Context

object DraftEditorSessionStore {
    private const val PREFS_NAME = "shinsoku_draft_editor"
    private const val KEY_TEXT = "text"

    fun saveDraft(context: Context, text: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_TEXT, text)
            .apply()
    }

    fun loadDraft(context: Context): String {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_TEXT, "")
            .orEmpty()
    }

    fun clearDraft(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_TEXT)
            .apply()
    }
}
