package com.shinsoku.mobile.ime

import android.content.Intent
import android.content.IntentFilter
import android.inputmethodservice.InputMethodService
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.core.content.ContextCompat.RECEIVER_NOT_EXPORTED
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
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
    private var editButton: Button? = null
    private var dictationButton: Button? = null
    private var chatButton: Button? = null
    private var reviewButton: Button? = null
    private var translateButton: Button? = null
    private var livePreviewView: TextView? = null
    private var pendingActionsRow: View? = null
    private var controller: VoiceInputController? = null
    private lateinit var configStore: AndroidVoiceInputConfigStore
    private lateinit var providerConfigStore: AndroidVoiceProviderConfigStore
    private lateinit var runtimeConfigStore: AndroidVoiceRuntimeConfigStore
    private lateinit var historyStore: AndroidVoiceInputHistoryStore
    private var pendingDraftText: String? = null
    private val draftInsertReceiver = DraftInsertReceiver { editedText ->
        if (editedText.isBlank()) {
            controller?.discardPending()
            return@DraftInsertReceiver
        }
        currentInputConnection?.commitText(editedText, 1)
        appendHistory(editedText)
        DraftEditorSessionStore.clearDraft(this)
        controller?.discardPending()
    }

    override fun onCreate() {
        super.onCreate()
        TranscriptCommitPlanner.nativeCommitPlanner = NativeTranscriptCleanup::planTranscriptCommit
        configStore = AndroidVoiceInputConfigStore(this)
        providerConfigStore = AndroidVoiceProviderConfigStore(this)
        runtimeConfigStore = AndroidVoiceRuntimeConfigStore(this)
        historyStore = AndroidVoiceInputHistoryStore(this)
        ContextCompat.registerReceiver(
            this,
            draftInsertReceiver,
            IntentFilter(DraftEditorActivity.ACTION_INSERT_DRAFT),
            RECEIVER_NOT_EXPORTED,
        )
        rebuildController()
    }

    override fun onCreateInputView(): View {
        return try {
            val view = LayoutInflater.from(this).inflate(R.layout.input_view, null, false)
            applyImeSafeInsets(view)
            titleView = view.findViewById(R.id.imeTitle)
            subtitleView = view.findViewById(R.id.imeSubtitle)
            micButton = view.findViewById(R.id.micButton)
            insertButton = view.findViewById(R.id.insertButton)
            clearButton = view.findViewById(R.id.clearButton)
            editButton = view.findViewById(R.id.editButton)
            dictationButton = view.findViewById(R.id.imeDictationButton)
            chatButton = view.findViewById(R.id.imeChatButton)
            reviewButton = view.findViewById(R.id.imeReviewButton)
            translateButton = view.findViewById(R.id.imeTranslateButton)
            livePreviewView = view.findViewById(R.id.imeLivePreview)
            pendingActionsRow = view.findViewById(R.id.imePendingActions)
            val moreButton = view.findViewById<Button>(R.id.imeMoreButton)
            val backspaceButton = view.findViewById<Button>(R.id.backspaceButton)
            val enterButton = view.findViewById<Button>(R.id.enterButton)

            titleView?.text = getString(R.string.ime_title_idle)
            subtitleView?.text = getString(R.string.ime_subtitle_ready)
            micButton?.setOnClickListener {
                try {
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
            editButton?.setOnClickListener {
                openDraftEditor()
            }
            dictationButton?.setOnClickListener { applyProfile(VoiceInputProfiles.dictation) }
            chatButton?.setOnClickListener { applyProfile(VoiceInputProfiles.chat) }
            reviewButton?.setOnClickListener { applyProfile(VoiceInputProfiles.review) }
            translateButton?.setOnClickListener { applyProfile(VoiceInputProfiles.translateChineseToEnglish) }
            moreButton.setOnClickListener { anchor ->
                showMoreMenu(anchor)
            }
            backspaceButton.setOnClickListener {
                currentInputConnection?.deleteSurroundingText(1, 0)
            }
            enterButton.setOnClickListener {
                currentInputConnection?.commitText("\n", 1)
            }
            bindPresetButtons(configStore.loadProfile())
            view
        } catch (error: Throwable) {
            Log.e(TAG, "Failed to inflate IME view", error)
            titleView = null
            subtitleView = null
            micButton = null
            insertButton = null
            clearButton = null
            editButton = null
            dictationButton = null
            chatButton = null
            reviewButton = null
            translateButton = null
            livePreviewView = null
            pendingActionsRow = null
            createFallbackInputView(error)
        }
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        super.onFinishInputView(finishingInput)
        controller?.stop()
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        rebuildController()
        onStateChanged(controller?.currentState() ?: VoiceInputUiState.Idle)
    }

    override fun onDestroy() {
        controller?.destroy()
        controller = null
        unregisterReceiver(draftInsertReceiver)
        super.onDestroy()
    }

    override fun onStateChanged(state: VoiceInputUiState) {
        when (state) {
            is VoiceInputUiState.Idle -> {
                pendingDraftText = null
                titleView?.text = getString(R.string.ime_title_idle)
                subtitleView?.text = getString(R.string.ime_subtitle_ready)
                micButton?.text = getString(R.string.ime_mic)
                pendingActionsRow?.visibility = View.GONE
                livePreviewView?.visibility = View.GONE
            }

            is VoiceInputUiState.Listening -> {
                titleView?.text = getString(R.string.ime_title_listening)
                subtitleView?.text = currentProfileLabel()
                micButton?.text = getString(R.string.ime_stop)
                pendingActionsRow?.visibility = View.GONE
                val partial = state.partialTranscript.ifBlank { getString(R.string.ime_live_preview_placeholder) }
                livePreviewView?.text = partial
                livePreviewView?.visibility = View.VISIBLE
            }

            is VoiceInputUiState.Processing -> {
                titleView?.text = getString(R.string.ime_title_processing)
                subtitleView?.text = getString(R.string.ime_subtitle_processing)
                micButton?.text = getString(R.string.ime_stop)
                pendingActionsRow?.visibility = View.GONE
                livePreviewView?.text = getString(R.string.ime_title_processing)
                livePreviewView?.visibility = View.VISIBLE
            }

            is VoiceInputUiState.PendingCommit -> {
                pendingDraftText = state.text
                titleView?.text = currentProfileLabel()
                subtitleView?.text = currentProfileLabel()
                micButton?.text = getString(R.string.ime_mic)
                pendingActionsRow?.visibility = View.VISIBLE
                livePreviewView?.text = state.text.trimEnd('\n', ' ')
                livePreviewView?.visibility = View.VISIBLE
            }

            is VoiceInputUiState.Error -> {
                Log.e(TAG, "IME error: ${state.message}")
                titleView?.text = state.message
                subtitleView?.text = currentProfileLabel()
                micButton?.text = getString(R.string.ime_retry)
                pendingActionsRow?.visibility = View.GONE
                livePreviewView?.visibility = View.GONE
            }
        }
    }

    override fun onCommitRequested(commit: VoiceInputCommit) {
        currentInputConnection?.commitText(commit.text, 1)
        appendHistory(commit.text)
    }

    private fun appendHistory(text: String) {
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
                text = text,
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

    private fun bindPresetButton(button: Button?, active: Boolean) {
        if (button == null) return
        button.setBackgroundResource(
            if (active) R.drawable.bg_ime_button_chip_active else R.drawable.bg_ime_button_chip,
        )
        button.setTextColor(
            ContextCompat.getColor(
                this,
                if (active) R.color.shinsoku_chip_active_text else R.color.shinsoku_text,
            ),
        )
    }

    private fun currentProfileLabel(): String = configStore.loadProfile().displayName

    private fun openDraftEditor() {
        val text = pendingDraftText ?: return
        DraftEditorSessionStore.saveDraft(this, text)
        startActivity(
            Intent(this, DraftEditorActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }

    private fun applyImeSafeInsets(root: View) {
        val panel = root.findViewById<View>(R.id.imePanel) ?: return
        val basePaddingBottom = panel.paddingBottom
        val extraBottomPadding = (12 * resources.displayMetrics.density).toInt()
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val bottomInset = insets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout(),
            ).bottom
            panel.setPadding(
                panel.paddingLeft,
                panel.paddingTop,
                panel.paddingRight,
                basePaddingBottom + bottomInset + extraBottomPadding,
            )
            insets
        }
        ViewCompat.requestApplyInsets(root)
    }

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
