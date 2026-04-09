package com.shinsoku.mobile.ime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class DraftInsertReceiver(
    private val onInsert: (String) -> Unit,
) : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != DraftEditorActivity.ACTION_INSERT_DRAFT) {
            return
        }
        onInsert(intent.getStringExtra(DraftEditorActivity.EXTRA_TEXT).orEmpty())
    }
}
