package com.shinsoku.mobile.ime

import android.inputmethodservice.InputMethodService
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.TextView
import com.shinsoku.mobile.R
import com.shinsoku.mobile.history.AndroidVoiceInputHistoryStore
import com.shinsoku.mobile.settings.AndroidVoiceProviderConfigStore
import com.shinsoku.mobile.settings.AndroidVoiceInputConfigStore
import com.shinsoku.mobile.settings.AndroidVoiceRuntimeConfigStore
import com.shinsoku.mobile.speechcore.TranscriptCommitPlanner
import com.shinsoku.mobile.speechcore.VoiceInputCommit
import com.shinsoku.mobile.speechcore.VoiceInputController
import com.shinsoku.mobile.speechcore.VoiceInputControllerObserver
import com.shinsoku.mobile.speechcore.VoiceInputUiState
import com.shinsoku.mobile.speechcore.VoiceInputHistoryEntry
import com.shinsoku.mobile.speechcore.VoiceRecognitionProvider
import com.shinsoku.mobile.speechcore.VoiceTransformMode
import com.shinsoku.mobile.processing.AndroidVoicePostProcessor
import com.shinsoku.mobile.processing.NativeTranscriptCleanup
import java.util.UUID

class ShinsokuImeService : InputMethodService(), VoiceInputControllerObserver {
    companion object {
        private const val TAG = "ShinsokuImeService"
    }

    private var titleView: TextView? = null
    private var micButton: Button? = null
    private var insertButton: Button? = null
    private var clearButton: Button? = null
    private var controller: VoiceInputController? = null
    private lateinit var configStore: AndroidVoiceInputConfigStore
    private lateinit var providerConfigStore: AndroidVoiceProviderConfigStore
    private lateinit var runtimeConfigStore: AndroidVoiceRuntimeConfigStore
    private lateinit var historyStore: AndroidVoiceInputHistoryStore

    override fun onCreate() {
        super.onCreate()
        TranscriptCommitPlanner.nativeCommitPlanner = NativeTranscriptCleanup::planTranscriptCommit
        configStore = AndroidVoiceInputConfigStore(this)
        providerConfigStore = AndroidVoiceProviderConfigStore(this)
        runtimeConfigStore = AndroidVoiceRuntimeConfigStore(this)
        historyStore = AndroidVoiceInputHistoryStore(this)
        rebuildController()
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
            try {
                if (controller?.currentState() !is VoiceInputUiState.Listening &&
                    controller?.currentState() !is VoiceInputUiState.Processing
                ) {
                    rebuildController()
                }
                controller?.onMicTapped()
            } catch (error: Throwable) {
                Log.e(TAG, "IME mic tap failed", error)
                titleView?.text = error.message ?: "Voice input failed to start."
                micButton?.text = getString(R.string.ime_retry)
                insertButton?.visibility = View.GONE
                clearButton?.visibility = View.GONE
            }
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
                Log.e(TAG, "IME error: ${state.message}")
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
        val runtimeConfig = runtimeConfigStore.loadRuntimeConfig()
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
                profileName = profile.displayName,
                transformMode = profile.transform.mode.name,
                postProcessingMode = runtimeConfig.postProcessingConfig.mode.name,
                autoCommit = profile.autoCommit,
                commitSuffixMode = profile.commitSuffixMode,
                languageTag = profile.languageTag,
                debugDetail = buildString {
                    append("request_format=")
                    append(profile.transform.requestFormat.name)
                    append(", transform_enabled=")
                    append(profile.transform.enabled)
                    if (profile.transform.mode == VoiceTransformMode.Translation) {
                        append(", source=")
                        append(profile.transform.translationSourceLanguage)
                        append(", target=")
                        append(profile.transform.translationTargetLanguage)
                    }
                },
            ),
        )
    }

    private fun rebuildController() {
        controller?.destroy()
        controller = VoiceInputController(
            engine = RecognitionEngineFactory.create(this),
            configStore = configStore,
            observer = this,
            postProcessor = AndroidVoicePostProcessor(this),
        )
    }
}
