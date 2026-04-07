package com.shinsoku.mobile.ime

import android.inputmethodservice.InputMethodService
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.TextView
import com.shinsoku.mobile.R

class ShinsokuImeService : InputMethodService() {
    override fun onCreateInputView(): View {
        val view = LayoutInflater.from(this).inflate(R.layout.input_view, null, false)
        val title = view.findViewById<TextView>(R.id.imeTitle)
        val mic = view.findViewById<Button>(R.id.micButton)
        val space = view.findViewById<Button>(R.id.spaceButton)
        val backspace = view.findViewById<Button>(R.id.backspaceButton)

        title.text = getString(R.string.ime_title_idle)
        mic.setOnClickListener {
            title.text = getString(R.string.ime_title_listening)
        }
        space.setOnClickListener {
            currentInputConnection?.commitText(" ", 1)
        }
        backspace.setOnClickListener {
            currentInputConnection?.deleteSurroundingText(1, 0)
        }

        return view
    }
}
