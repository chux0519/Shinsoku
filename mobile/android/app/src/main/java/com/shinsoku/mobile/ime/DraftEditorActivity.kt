package com.shinsoku.mobile.ime

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import androidx.appcompat.app.AppCompatActivity
import com.shinsoku.mobile.R

class DraftEditorActivity : AppCompatActivity() {
    companion object {
        const val ACTION_INSERT_DRAFT = "com.shinsoku.mobile.action.INSERT_DRAFT"
        const val EXTRA_TEXT = "text"
    }

    private lateinit var editor: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_draft_editor)

        editor = findViewById(R.id.draftEditorText)
        val cancelButton = findViewById<Button>(R.id.draftCancelButton)
        val insertButton = findViewById<Button>(R.id.draftInsertButton)

        editor.setText(DraftEditorSessionStore.loadDraft(this))
        editor.setSelection(editor.text?.length ?: 0)

        cancelButton.setOnClickListener { finish() }
        insertButton.setOnClickListener {
            val text = editor.text?.toString().orEmpty()
            DraftEditorSessionStore.saveDraft(this, text)
            sendBroadcast(
                Intent(ACTION_INSERT_DRAFT).apply {
                    setPackage(packageName)
                    putExtra(EXTRA_TEXT, text)
                },
            )
            finish()
        }
    }
}
