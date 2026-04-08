package com.shinsoku.mobile.ime

import android.content.Intent
import android.inputmethodservice.InputMethodService
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.Spinner
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.shinsoku.mobile.R
import com.shinsoku.mobile.history.AndroidVoiceInputHistoryStore
import com.shinsoku.mobile.settings.SettingsActivity
import com.shinsoku.mobile.settings.AndroidVoiceProviderConfigStore
import com.shinsoku.mobile.settings.AndroidVoiceInputConfigStore
import com.shinsoku.mobile.settings.AndroidVoiceRuntimeConfigStore
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
    private var micButton: Button? = null
    private var insertButton: Button? = null
    private var clearButton: Button? = null
    private var presetSpinner: Spinner? = null
    private var pendingActionsRow: View? = null
    private var controller: VoiceInputController? = null
    private lateinit var configStore: AndroidVoiceInputConfigStore
    private lateinit var providerConfigStore: AndroidVoiceProviderConfigStore
    private lateinit var runtimeConfigStore: AndroidVoiceRuntimeConfigStore
    private lateinit var historyStore: AndroidVoiceInputHistoryStore
    private var suppressPresetSelection = false

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
        return try {
            val view = LayoutInflater.from(this).inflate(R.layout.input_view, null, false)
            titleView = view.findViewById(R.id.imeTitle)
            subtitleView = view.findViewById(R.id.imeSubtitle)
            micButton = view.findViewById(R.id.micButton)
            insertButton = view.findViewById(R.id.insertButton)
            clearButton = view.findViewById(R.id.clearButton)
            presetSpinner = view.findViewById(R.id.imePresetSpinner)
            pendingActionsRow = view.findViewById(R.id.imePendingActions)
            val moreButton = view.findViewById<Button>(R.id.imeMoreButton)

            titleView?.text = getString(R.string.ime_title_idle)
            subtitleView?.text = getString(R.string.ime_subtitle_ready)
            bindPresetSelector()
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
            moreButton.setOnClickListener { anchor ->
                showMoreMenu(anchor)
            }
            bindPresetSelection(configStore.loadProfile())
            view
        } catch (error: Throwable) {
            Log.e(TAG, "Failed to inflate IME view", error)
            titleView = null
            subtitleView = null
            micButton = null
            insertButton = null
            clearButton = null
            presetSpinner = null
            pendingActionsRow = null
            createFallbackInputView(error)
        }
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
                pendingActionsRow?.visibility = View.GONE
            }

            is VoiceInputUiState.Listening -> {
                titleView?.text = if (state.partialTranscript.isBlank()) {
                    getString(R.string.ime_title_listening)
                } else {
                    state.partialTranscript
                }
                subtitleView?.text = currentProfileLabel()
                micButton?.text = getString(R.string.ime_stop)
                pendingActionsRow?.visibility = View.GONE
            }

            is VoiceInputUiState.Processing -> {
                titleView?.text = getString(R.string.ime_title_processing)
                subtitleView?.text = getString(R.string.ime_subtitle_processing)
                micButton?.text = getString(R.string.ime_stop)
                pendingActionsRow?.visibility = View.GONE
            }

            is VoiceInputUiState.PendingCommit -> {
                titleView?.text = state.text.trimEnd('\n', ' ')
                subtitleView?.text = currentProfileLabel()
                micButton?.text = getString(R.string.ime_mic)
                pendingActionsRow?.visibility = View.VISIBLE
            }

            is VoiceInputUiState.Error -> {
                Log.e(TAG, "IME error: ${state.message}")
                titleView?.text = state.message
                subtitleView?.text = currentProfileLabel()
                micButton?.text = getString(R.string.ime_retry)
                pendingActionsRow?.visibility = View.GONE
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
        bindPresetSelection(configStore.loadProfile())
    }

    private fun applyProfile(profile: VoiceInputProfile) {
        configStore.saveProfile(profile)
        rebuildController()
        onStateChanged(controller?.currentState() ?: VoiceInputUiState.Idle)
    }

    private fun bindPresetSelector() {
        val spinner = presetSpinner ?: return
        val labels = listOf(
            getString(R.string.ime_profile_dictation_short),
            getString(R.string.ime_profile_chat_short),
            getString(R.string.ime_profile_review_short),
            getString(R.string.ime_profile_translate_short),
        )
        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, labels).apply {
            setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        }
        spinner.adapter = adapter
        spinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                if (suppressPresetSelection) {
                    return
                }
                val profile = when (position) {
                    1 -> VoiceInputProfiles.chat
                    2 -> VoiceInputProfiles.review
                    3 -> VoiceInputProfiles.translateChineseToEnglish
                    else -> VoiceInputProfiles.dictation
                }
                if (configStore.loadProfile().id != profile.id) {
                    applyProfile(profile)
                }
            }

            override fun onNothingSelected(parent: AdapterView<*>?) = Unit
        }
    }

    private fun bindPresetSelection(profile: VoiceInputProfile) {
        val spinner = presetSpinner ?: return
        val index = when (profile.id) {
            VoiceInputProfiles.chat.id -> 1
            VoiceInputProfiles.review.id -> 2
            VoiceInputProfiles.translateChineseToEnglish.id -> 3
            else -> 0
        }
        suppressPresetSelection = true
        spinner.setSelection(index, false)
        suppressPresetSelection = false
    }

    private fun currentProfileLabel(): String = configStore.loadProfile().displayName

    private fun showMoreMenu(anchor: View) {
        PopupMenu(this, anchor).apply {
            menu.add(0, 1, 0, getString(R.string.ime_space))
            menu.add(0, 2, 1, getString(R.string.ime_delete))
            menu.add(0, 3, 2, getString(R.string.ime_settings))
            setOnMenuItemClickListener { item ->
                when (item.itemId) {
                    1 -> currentInputConnection?.commitText(" ", 1)
                    2 -> currentInputConnection?.deleteSurroundingText(1, 0)
                    3 -> startActivity(
                        Intent(this@ShinsokuImeService, SettingsActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                    )
                }
                true
            }
            show()
        }
    }

    private fun createFallbackInputView(error: Throwable): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
        }
        val title = TextView(this).apply {
            text = getString(R.string.ime_title_idle)
        }
        val message = TextView(this).apply {
            text = error.message ?: "Input view failed to load."
        }
        val retry = Button(this).apply {
            text = getString(R.string.ime_retry)
            setOnClickListener { rebuildController() }
        }
        root.addView(title)
        root.addView(message)
        root.addView(retry)
        return root
    }
}
