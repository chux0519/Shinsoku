package com.shinsoku.mobile.ime

import android.inputmethodservice.InputMethodService
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.TextView
import com.shinsoku.mobile.R
import com.shinsoku.mobile.settings.AndroidVoiceInputConfigStore
import com.shinsoku.mobile.speechcore.VoiceInputCommit
import com.shinsoku.mobile.speechcore.VoiceInputController
import com.shinsoku.mobile.speechcore.VoiceInputControllerObserver
import com.shinsoku.mobile.speechcore.VoiceInputUiState

class ShinsokuImeService : InputMethodService(), VoiceInputControllerObserver {
    private var titleView: TextView? = null
    private var micButton: Button? = null
    private var controller: VoiceInputController? = null

    override fun onCreate() {
        super.onCreate()
        controller = VoiceInputController(
            engine = AndroidSpeechRecognizerEngine(this),
            configStore = AndroidVoiceInputConfigStore(this),
            observer = this,
        )
    }

    override fun onCreateInputView(): View {
        val view = LayoutInflater.from(this).inflate(R.layout.input_view, null, false)
        titleView = view.findViewById(R.id.imeTitle)
        micButton = view.findViewById(R.id.micButton)
        val space = view.findViewById<Button>(R.id.spaceButton)
        val backspace = view.findViewById<Button>(R.id.backspaceButton)

        titleView?.text = getString(R.string.ime_title_idle)
        micButton?.setOnClickListener {
            controller?.onMicTapped()
        }
        space.setOnClickListener {
            currentInputConnection?.commitText(" ", 1)
        }
        backspace.setOnClickListener {
            currentInputConnection?.deleteSurroundingText(1, 0)
        }

        return view
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        super.onFinishInputView(finishingInput)
        controller?.stop()
    }

    override fun onDestroy() {
        controller?.destroy()
        controller = null
        super.onDestroy()
    }

    override fun onStateChanged(state: VoiceInputUiState) {
        when (state) {
            is VoiceInputUiState.Idle -> {
                titleView?.text = getString(R.string.ime_title_idle)
                micButton?.text = getString(R.string.ime_mic)
            }

            is VoiceInputUiState.Listening -> {
                titleView?.text = if (state.partialTranscript.isBlank()) {
                    getString(R.string.ime_title_listening)
                } else {
                    state.partialTranscript
                }
                micButton?.text = getString(R.string.ime_stop)
            }

            is VoiceInputUiState.Processing -> {
                titleView?.text = getString(R.string.ime_title_processing)
                micButton?.text = getString(R.string.ime_stop)
            }

            is VoiceInputUiState.Error -> {
                titleView?.text = state.message
                micButton?.text = getString(R.string.ime_retry)
            }
        }
    }

    override fun onCommitRequested(commit: VoiceInputCommit) {
        currentInputConnection?.commitText(commit.text, 1)
    }
}
