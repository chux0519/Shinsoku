package com.shinsoku.mobile.ime

import android.inputmethodservice.InputMethodService
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.TextView
import com.shinsoku.mobile.R
import com.shinsoku.mobile.history.AndroidVoiceInputHistoryStore
import com.shinsoku.mobile.settings.AndroidVoiceProviderConfigStore
import com.shinsoku.mobile.settings.AndroidVoiceInputConfigStore
import com.shinsoku.mobile.speechcore.VoiceInputCommit
import com.shinsoku.mobile.speechcore.VoiceInputController
import com.shinsoku.mobile.speechcore.VoiceInputControllerObserver
import com.shinsoku.mobile.speechcore.VoiceInputUiState
import com.shinsoku.mobile.speechcore.VoiceInputHistoryEntry
import com.shinsoku.mobile.speechcore.VoiceRecognitionProvider
import java.util.UUID

class ShinsokuImeService : InputMethodService(), VoiceInputControllerObserver {
    private var titleView: TextView? = null
    private var micButton: Button? = null
    private var insertButton: Button? = null
    private var clearButton: Button? = null
    private var controller: VoiceInputController? = null
    private lateinit var configStore: AndroidVoiceInputConfigStore
    private lateinit var providerConfigStore: AndroidVoiceProviderConfigStore
    private lateinit var historyStore: AndroidVoiceInputHistoryStore

    override fun onCreate() {
        super.onCreate()
        configStore = AndroidVoiceInputConfigStore(this)
        providerConfigStore = AndroidVoiceProviderConfigStore(this)
        historyStore = AndroidVoiceInputHistoryStore(this)
        controller = VoiceInputController(
            engine = RecognitionEngineFactory.create(this),
            configStore = configStore,
            observer = this,
        )
    }

    override fun onCreateInputView(): View {
        val view = LayoutInflater.from(this).inflate(R.layout.input_view, null, false)
        titleView = view.findViewById(R.id.imeTitle)
        micButton = view.findViewById(R.id.micButton)
        insertButton = view.findViewById(R.id.insertButton)
        clearButton = view.findViewById(R.id.clearButton)
        val space = view.findViewById<Button>(R.id.spaceButton)
        val backspace = view.findViewById<Button>(R.id.backspaceButton)

        titleView?.text = getString(R.string.ime_title_idle)
        micButton?.setOnClickListener {
            controller?.onMicTapped()
        }
        insertButton?.setOnClickListener {
            controller?.commitPending()
        }
        clearButton?.setOnClickListener {
            controller?.discardPending()
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
                insertButton?.visibility = View.GONE
                clearButton?.visibility = View.GONE
            }

            is VoiceInputUiState.Listening -> {
                titleView?.text = if (state.partialTranscript.isBlank()) {
                    getString(R.string.ime_title_listening)
                } else {
                    state.partialTranscript
                }
                micButton?.text = getString(R.string.ime_stop)
                insertButton?.visibility = View.GONE
                clearButton?.visibility = View.GONE
            }

            is VoiceInputUiState.Processing -> {
                titleView?.text = getString(R.string.ime_title_processing)
                micButton?.text = getString(R.string.ime_stop)
                insertButton?.visibility = View.GONE
                clearButton?.visibility = View.GONE
            }

            is VoiceInputUiState.PendingCommit -> {
                titleView?.text = state.text.trimEnd('\n', ' ')
                micButton?.text = getString(R.string.ime_mic)
                insertButton?.visibility = View.VISIBLE
                clearButton?.visibility = View.VISIBLE
            }

            is VoiceInputUiState.Error -> {
                titleView?.text = state.message
                micButton?.text = getString(R.string.ime_retry)
                insertButton?.visibility = View.GONE
                clearButton?.visibility = View.GONE
            }
        }
    }

    override fun onCommitRequested(commit: VoiceInputCommit) {
        currentInputConnection?.commitText(commit.text, 1)
        val profile = configStore.loadProfile()
        val providerLabel = when (providerConfigStore.load().activeRecognitionProvider) {
            VoiceRecognitionProvider.AndroidSystem -> "Android System"
            VoiceRecognitionProvider.OpenAiCompatible -> "OpenAI-Compatible"
            VoiceRecognitionProvider.Soniox -> "Soniox"
            VoiceRecognitionProvider.Bailian -> "Bailian"
        }
        historyStore.appendEntry(
            VoiceInputHistoryEntry(
                id = UUID.randomUUID().toString(),
                text = commit.text,
                committedAtEpochMillis = System.currentTimeMillis(),
                provider = providerLabel,
                autoCommit = profile.autoCommit,
                commitSuffixMode = profile.commitSuffixMode,
                languageTag = profile.languageTag,
            ),
        )
    }
}
