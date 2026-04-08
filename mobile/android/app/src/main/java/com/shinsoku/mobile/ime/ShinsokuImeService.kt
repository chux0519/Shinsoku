package com.shinsoku.mobile.ime

import android.content.Intent
import android.content.res.ColorStateList
import android.inputmethodservice.InputMethodService
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.shinsoku.mobile.R
import com.shinsoku.mobile.history.AndroidVoiceInputHistoryStore
import com.shinsoku.mobile.settings.SettingsActivity
import com.shinsoku.mobile.settings.AndroidVoiceProviderConfigStore
import com.shinsoku.mobile.settings.AndroidVoiceInputConfigStore
import com.shinsoku.mobile.settings.AndroidVoiceRuntimeConfigStore
import com.google.android.material.button.MaterialButton
import com.shinsoku.mobile.speechcore.TranscriptCommitPlanner
import com.shinsoku.mobile.speechcore.VoiceInputCommit
import com.shinsoku.mobile.speechcore.VoiceInputController
import com.shinsoku.mobile.speechcore.VoiceInputControllerObserver
import com.shinsoku.mobile.speechcore.VoiceInputProfile
import com.shinsoku.mobile.speechcore.VoiceInputProfiles
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
    private var subtitleView: TextView? = null
    private var micButton: MaterialButton? = null
    private var insertButton: MaterialButton? = null
    private var clearButton: MaterialButton? = null
    private var dictationButton: MaterialButton? = null
    private var chatButton: MaterialButton? = null
    private var reviewButton: MaterialButton? = null
    private var translateButton: MaterialButton? = null
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
        subtitleView = view.findViewById(R.id.imeSubtitle)
        micButton = view.findViewById(R.id.micButton)
        insertButton = view.findViewById(R.id.insertButton)
        clearButton = view.findViewById(R.id.clearButton)
        dictationButton = view.findViewById(R.id.imeDictationButton)
        chatButton = view.findViewById(R.id.imeChatButton)
        reviewButton = view.findViewById(R.id.imeReviewButton)
        translateButton = view.findViewById(R.id.imeTranslateButton)
        val space = view.findViewById<MaterialButton>(R.id.spaceButton)
        val backspace = view.findViewById<MaterialButton>(R.id.backspaceButton)
        val settingsButton = view.findViewById<MaterialButton>(R.id.imeSettingsButton)

        titleView?.text = getString(R.string.ime_title_idle)
        subtitleView?.text = getString(R.string.ime_subtitle_ready)
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
        settingsButton.setOnClickListener {
            startActivity(
                Intent(this, SettingsActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        }
        dictationButton?.setOnClickListener {
            applyProfile(VoiceInputProfiles.dictation)
        }
        chatButton?.setOnClickListener {
            applyProfile(VoiceInputProfiles.chat)
        }
        reviewButton?.setOnClickListener {
            applyProfile(VoiceInputProfiles.review)
        }
        translateButton?.setOnClickListener {
            applyProfile(VoiceInputProfiles.translateChineseToEnglish)
        }
        bindPresetButtons(configStore.loadProfile())

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
                subtitleView?.text = getString(R.string.ime_subtitle_ready)
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
                subtitleView?.text = currentProfileLabel()
                micButton?.text = getString(R.string.ime_stop)
                insertButton?.visibility = View.GONE
                clearButton?.visibility = View.GONE
            }

            is VoiceInputUiState.Processing -> {
                titleView?.text = getString(R.string.ime_title_processing)
                subtitleView?.text = getString(R.string.ime_subtitle_processing)
                micButton?.text = getString(R.string.ime_stop)
                insertButton?.visibility = View.GONE
                clearButton?.visibility = View.GONE
            }

            is VoiceInputUiState.PendingCommit -> {
                titleView?.text = state.text.trimEnd('\n', ' ')
                subtitleView?.text = currentProfileLabel()
                micButton?.text = getString(R.string.ime_mic)
                insertButton?.visibility = View.VISIBLE
                clearButton?.visibility = View.VISIBLE
            }

            is VoiceInputUiState.Error -> {
                Log.e(TAG, "IME error: ${state.message}")
                titleView?.text = state.message
                subtitleView?.text = currentProfileLabel()
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
        bindPresetButtons(configStore.loadProfile())
    }

    private fun applyProfile(profile: VoiceInputProfile) {
        configStore.saveProfile(profile)
        rebuildController()
        onStateChanged(controller?.currentState() ?: VoiceInputUiState.Idle)
    }

    private fun bindPresetButtons(profile: VoiceInputProfile) {
        bindPresetButton(dictationButton, profile.id == VoiceInputProfiles.dictation.id)
        bindPresetButton(chatButton, profile.id == VoiceInputProfiles.chat.id)
        bindPresetButton(reviewButton, profile.id == VoiceInputProfiles.review.id)
        bindPresetButton(translateButton, profile.id == VoiceInputProfiles.translateChineseToEnglish.id)
    }

    private fun bindPresetButton(button: MaterialButton?, active: Boolean) {
        if (button == null) {
            return
        }
        val background = if (active) {
            R.color.shinsoku_chip_active
        } else {
            R.color.shinsoku_chip_bg
        }
        val foreground = if (active) {
            R.color.shinsoku_chip_active_text
        } else {
            R.color.shinsoku_text
        }
        button.backgroundTintList = ColorStateList.valueOf(ContextCompat.getColor(this, background))
        button.strokeColor = ColorStateList.valueOf(ContextCompat.getColor(this, R.color.shinsoku_border))
        button.setTextColor(ContextCompat.getColor(this, foreground))
    }

    private fun currentProfileLabel(): String = configStore.loadProfile().displayName
}
