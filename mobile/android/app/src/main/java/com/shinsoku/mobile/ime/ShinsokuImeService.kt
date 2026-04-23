package com.shinsoku.mobile.ime

import android.content.Intent
import android.content.IntentFilter
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.core.content.ContextCompat.RECEIVER_NOT_EXPORTED
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.shinsoku.mobile.MainActivity
import com.shinsoku.mobile.R
import com.shinsoku.mobile.history.AndroidVoiceInputHistoryStore
import com.shinsoku.mobile.history.HistoryActivity
import com.shinsoku.mobile.settings.SettingsActivity
import com.shinsoku.mobile.settings.AndroidVoiceProviderConfigStore
import com.shinsoku.mobile.settings.AndroidVoiceInputConfigStore
import com.shinsoku.mobile.settings.AndroidVoiceRuntimeConfigStore
import com.shinsoku.mobile.speechcore.TranscriptCommitPlanner
import com.shinsoku.mobile.speechcore.NativeVoiceRuntimeMetadata
import com.shinsoku.mobile.speechcore.TranscriptPostProcessingMode
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
import com.shinsoku.mobile.processing.PostProcessingDiagnostics
import java.util.UUID

class ShinsokuImeService : InputMethodService(), VoiceInputControllerObserver {
    companion object {
        private const val TAG = "ShinsokuImeService"
        private const val BACKSPACE_REPEAT_INTERVAL_MS = 55L
    }

    private var micButton: Button? = null
    private var insertButton: Button? = null
    private var clearButton: Button? = null
    private var editButton: Button? = null
    private var modeButton: Button? = null
    private var spaceButton: Button? = null
    private var livePreviewView: TextView? = null
    private var pendingActionsRow: View? = null
    private var controller: VoiceInputController? = null
    private lateinit var configStore: AndroidVoiceInputConfigStore
    private lateinit var providerConfigStore: AndroidVoiceProviderConfigStore
    private lateinit var runtimeConfigStore: AndroidVoiceRuntimeConfigStore
    private lateinit var historyStore: AndroidVoiceInputHistoryStore
    private var pendingDraftText: String? = null
    private var stickyPreviewMessage: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var backspaceRepeating = false
    private val backspaceRepeatRunnable = object : Runnable {
        override fun run() {
            if (!backspaceRepeating) {
                return
            }
            deletePreviousCharacter()
            mainHandler.postDelayed(this, BACKSPACE_REPEAT_INTERVAL_MS)
        }
    }
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
            micButton = view.findViewById(R.id.micButton)
            insertButton = view.findViewById(R.id.insertButton)
            clearButton = view.findViewById(R.id.clearButton)
            editButton = view.findViewById(R.id.editButton)
            modeButton = view.findViewById(R.id.imeModeButton)
            spaceButton = view.findViewById(R.id.spaceButton)
            livePreviewView = view.findViewById(R.id.imeLivePreview)
            pendingActionsRow = view.findViewById(R.id.imePendingActions)
            val moreButton = view.findViewById<Button>(R.id.imeMoreButton)
            val backspaceButton = view.findViewById<ImageButton>(R.id.backspaceButton)
            val enterButton = view.findViewById<ImageButton>(R.id.enterButton)

            micButton?.setOnClickListener {
                try {
                    controller?.onMicTapped()
                } catch (error: Throwable) {
                    Log.e(TAG, "IME mic tap failed", error)
                    livePreviewView?.text = error.message ?: "Voice input failed to start."
                    livePreviewView?.visibility = View.VISIBLE
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
            modeButton?.setOnClickListener { anchor ->
                showModeMenu(anchor)
            }
            spaceButton?.setOnClickListener {
                currentInputConnection?.commitText(" ", 1)
            }
            moreButton.setOnClickListener { anchor ->
                showMoreMenu(anchor)
            }
            backspaceButton.setOnClickListener {
                deletePreviousCharacter()
            }
            backspaceButton.setOnLongClickListener {
                startBackspaceRepeat()
                true
            }
            backspaceButton.setOnTouchListener { _, event ->
                if (event.actionMasked == MotionEvent.ACTION_UP || event.actionMasked == MotionEvent.ACTION_CANCEL) {
                    stopBackspaceRepeat()
                }
                false
            }
            enterButton.setOnClickListener {
                currentInputConnection?.commitText("\n", 1)
            }
            bindModeButton(configStore.loadProfile())
            view
        } catch (error: Throwable) {
            Log.e(TAG, "Failed to inflate IME view", error)
            micButton = null
            insertButton = null
            clearButton = null
            editButton = null
            modeButton = null
            spaceButton = null
            livePreviewView = null
            pendingActionsRow = null
            createFallbackInputView(error)
        }
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        super.onFinishInputView(finishingInput)
        stopBackspaceRepeat()
        controller?.stop()
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        rebuildController()
        onStateChanged(controller?.currentState() ?: VoiceInputUiState.Idle)
    }

    override fun onDestroy() {
        stopBackspaceRepeat()
        controller?.destroy()
        controller = null
        unregisterReceiver(draftInsertReceiver)
        super.onDestroy()
    }

    override fun onStateChanged(state: VoiceInputUiState) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { onStateChanged(state) }
            return
        }
        when (state) {
            is VoiceInputUiState.Idle -> {
                pendingDraftText = null
                micButton?.text = getString(R.string.ime_mic)
                pendingActionsRow?.visibility = View.GONE
                val sticky = stickyPreviewMessage
                if (sticky.isNullOrBlank()) {
                    livePreviewView?.visibility = View.GONE
                } else {
                    livePreviewView?.text = sticky
                    livePreviewView?.visibility = View.VISIBLE
                }
                bindModeButton(configStore.loadProfile())
            }

            is VoiceInputUiState.Preparing -> {
                stickyPreviewMessage = null
                micButton?.text = getString(R.string.ime_stop)
                pendingActionsRow?.visibility = View.GONE
                livePreviewView?.text = getString(R.string.ime_live_preview_preparing)
                livePreviewView?.visibility = View.VISIBLE
                bindModeButton(configStore.loadProfile())
            }

            is VoiceInputUiState.Listening -> {
                stickyPreviewMessage = null
                micButton?.text = getString(R.string.ime_stop)
                pendingActionsRow?.visibility = View.GONE
                val partial = state.partialTranscript.ifBlank { getString(R.string.ime_live_preview_placeholder) }
                livePreviewView?.text = partial
                livePreviewView?.visibility = View.VISIBLE
                bindModeButton(configStore.loadProfile())
            }

            is VoiceInputUiState.Processing -> {
                stickyPreviewMessage = null
                micButton?.text = getString(R.string.ime_stop)
                pendingActionsRow?.visibility = View.GONE
                livePreviewView?.text = getString(R.string.ime_subtitle_processing)
                livePreviewView?.visibility = View.VISIBLE
                bindModeButton(configStore.loadProfile())
            }

            is VoiceInputUiState.PendingCommit -> {
                stickyPreviewMessage = null
                pendingDraftText = state.text
                micButton?.text = getString(R.string.ime_mic)
                pendingActionsRow?.visibility = View.VISIBLE
                livePreviewView?.text = state.text.trimEnd('\n', ' ')
                livePreviewView?.visibility = View.VISIBLE
                bindModeButton(configStore.loadProfile())
            }

            is VoiceInputUiState.Error -> {
                stickyPreviewMessage = null
                Log.e(TAG, "IME error: ${state.message}")
                micButton?.text = getString(R.string.ime_retry)
                pendingActionsRow?.visibility = View.GONE
                livePreviewView?.text = state.message
                livePreviewView?.visibility = View.VISIBLE
                bindModeButton(configStore.loadProfile())
            }
        }
    }

    override fun onCommitRequested(commit: VoiceInputCommit) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { onCommitRequested(commit) }
            return
        }
        val postProcessDetail = PostProcessingDiagnostics.consume()
        currentInputConnection?.commitText(commit.text, 1)
        appendHistory(commit.text, postProcessDetail)
        maybeShowPostProcessNotice(postProcessDetail)
    }

    private fun appendHistory(text: String, postProcessDetail: String? = null) {
        val profile = configStore.loadProfile()
        val runtimeConfig = runtimeConfigStore.loadRuntimeConfig()
        val runtimeMetadata = NativeVoiceRuntimeMetadata.describe(
            providerConfigStore.load().activeRecognitionProvider,
            runtimeConfig.postProcessingConfig.mode,
        )
        historyStore.appendEntry(
            VoiceInputHistoryEntry(
                id = UUID.randomUUID().toString(),
                text = text,
                committedAtEpochMillis = System.currentTimeMillis(),
                provider = runtimeMetadata.providerLabel,
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
                    if (!postProcessDetail.isNullOrBlank()) {
                        append(", ")
                        append(postProcessDetail)
                    }
                },
            ),
        )
    }

    private fun maybeShowPostProcessNotice(postProcessDetail: String?) {
        if (postProcessDetail.isNullOrBlank()) {
            stickyPreviewMessage = null
            return
        }
        if (!postProcessDetail.contains("status=fallback")) {
            stickyPreviewMessage = null
            return
        }
        val shortReason = Regex("""reason_short=([^\s]+)""")
            .find(postProcessDetail)
            ?.groupValues
            ?.getOrNull(1)
            ?.ifBlank { null }
            ?: "unknown"
        val oneLine = "Post-process fallback: $shortReason. See History for details."
        stickyPreviewMessage =
            if (oneLine.length <= 96) oneLine else oneLine.take(93) + "..."
        livePreviewView?.text = stickyPreviewMessage
        livePreviewView?.visibility = View.VISIBLE
    }

    private fun rebuildController() {
        controller?.destroy()
        controller = VoiceInputController(
            engine = RecognitionEngineFactory.create(this),
            configStore = configStore,
            observer = this,
            postProcessor = AndroidVoicePostProcessor(this),
        )
        bindModeButton(configStore.loadProfile())
    }

    private fun applyProfile(profile: VoiceInputProfile) {
        configStore.saveProfile(profile)
        if (profile.id == "translate_zh_en" ||
            (profile.transform.enabled && profile.transform.mode == VoiceTransformMode.Translation)
        ) {
            runtimeConfigStore.savePostProcessingMode(TranscriptPostProcessingMode.ProviderAssisted)
        }
        rebuildController()
        onStateChanged(controller?.currentState() ?: VoiceInputUiState.Idle)
    }

    private fun bindModeButton(profile: VoiceInputProfile) {
        modeButton?.text = compactProfileLabel(profile)
    }

    private fun compactProfileLabel(profile: VoiceInputProfile): String =
        when (profile.id) {
            "dictation" -> getString(R.string.ime_profile_dictation_short)
            "chat" -> getString(R.string.ime_profile_chat_short)
            "review" -> getString(R.string.ime_profile_review_short)
            "translate_zh_en" -> getString(R.string.ime_profile_translate_short)
            else -> profile.displayName.ifBlank { getString(R.string.ime_mode_button) }
        }

    private fun deletePreviousCharacter() {
        currentInputConnection?.deleteSurroundingText(1, 0)
    }

    private fun startBackspaceRepeat() {
        if (backspaceRepeating) {
            return
        }
        backspaceRepeating = true
        deletePreviousCharacter()
        mainHandler.postDelayed(backspaceRepeatRunnable, BACKSPACE_REPEAT_INTERVAL_MS)
    }

    private fun stopBackspaceRepeat() {
        backspaceRepeating = false
        mainHandler.removeCallbacks(backspaceRepeatRunnable)
    }

    private fun showModeMenu(anchor: View) {
        PopupMenu(this, anchor).apply {
            VoiceInputProfiles.builtIns.forEachIndexed { index, profile ->
                menu.add(0, index + 1, index, profile.displayName)
            }
            setOnMenuItemClickListener { item ->
                VoiceInputProfiles.builtInAt(item.itemId - 1)?.let(::applyProfile)
                true
            }
            show()
        }
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
        val bottomBar = root.findViewById<View>(R.id.imeBottomBar) ?: return
        val extraBottomPadding = (2 * resources.displayMetrics.density).toInt()
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val bottomInset = insets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout(),
            ).bottom
            bottomBar.layoutParams = bottomBar.layoutParams.apply {
                height = bottomInset + extraBottomPadding
            }
            bottomBar.requestLayout()
            insets
        }
        ViewCompat.requestApplyInsets(root)
    }

    private fun showMoreMenu(anchor: View) {
        PopupMenu(this, anchor).apply {
            menu.add(0, 1, 0, getString(R.string.ime_settings))
            menu.add(0, 2, 1, getString(R.string.ime_history))
            menu.add(0, 3, 2, getString(R.string.ime_open_app))
            menu.add(0, 4, 3, getString(R.string.ime_home))
            menu.add(0, 5, 4, getString(R.string.ime_diagnostics))
            setOnMenuItemClickListener { item ->
                when (item.itemId) {
                    1 -> startActivity(
                        Intent(this@ShinsokuImeService, SettingsActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                    )
                    2 -> startActivity(
                        Intent(this@ShinsokuImeService, HistoryActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                    )
                    3 -> startActivity(
                        Intent(this@ShinsokuImeService, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        },
                    )
                    4 -> startActivity(
                        Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        },
                    )
                    5 -> showImeDiagnostics()
                }
                true
            }
            show()
        }
    }

    private fun showImeDiagnostics() {
        val profile = configStore.loadProfile()
        val providerConfig = providerConfigStore.load()
        val runtimeConfig = runtimeConfigStore.loadRuntimeConfig()
        val runtimeMetadata = NativeVoiceRuntimeMetadata.describe(
            providerConfig.activeRecognitionProvider,
            runtimeConfig.postProcessingConfig.mode,
        )
        val requestedPostProcessingMode = getSharedPreferences("shinsoku_voice_runtime", MODE_PRIVATE)
            .getString("post_processing_mode", TranscriptPostProcessingMode.ProviderAssisted.name)
            ?: TranscriptPostProcessingMode.ProviderAssisted.name
        val postBaseUrl = providerConfig.openAiPostProcessing.baseUrl.trim()
        val postModel = providerConfig.openAiPostProcessing.model.trim()
        val postApiKey = providerConfig.openAiPostProcessing.apiKey.trim()
        val diagnostic = buildString {
            append("IME Diagnostics")
            append('\n')
            append("profile.id=")
            append(profile.id)
            append('\n')
            append("profile.name=")
            append(profile.displayName)
            append('\n')
            append("language=")
            append(profile.languageTag ?: "auto")
            append('\n')
            append("transform.enabled=")
            append(profile.transform.enabled)
            append('\n')
            append("transform.mode=")
            append(profile.transform.mode.name)
            append('\n')
            append("post.requested=")
            append(requestedPostProcessingMode)
            append('\n')
            append("post.effective=")
            append(runtimeConfig.postProcessingConfig.mode.name)
            append('\n')
            append("post.base_url_set=")
            append(postBaseUrl.isNotEmpty())
            append('\n')
            append("post.model_set=")
            append(postModel.isNotEmpty())
            append('\n')
            append("post.api_key_set=")
            append(postApiKey.isNotEmpty())
            append('\n')
            append("provider.active=")
            append(providerConfig.activeRecognitionProvider.name)
            append('\n')
            append("provider.label=")
            append(runtimeMetadata.providerLabel)
        }
        Log.w(TAG, diagnostic)
        Toast.makeText(
            this,
            "Diagnostics logged. post=${runtimeConfig.postProcessingConfig.mode.name}, transform=${profile.transform.mode.name}",
            Toast.LENGTH_LONG,
        ).show()
        livePreviewView?.text = diagnostic
        livePreviewView?.visibility = View.VISIBLE
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
