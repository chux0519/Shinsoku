package com.shinsoku.mobile.speechcore

class VoiceInputController(
    private val engine: VoiceInputEngine,
    private val configStore: VoiceInputConfigStore,
    private val observer: VoiceInputControllerObserver,
    private val postProcessor: VoiceTranscriptPostProcessor = LocalTranscriptCleanupPostProcessor(),
) : VoiceInputEngine.Listener {
    private var state: VoiceInputUiState = VoiceInputUiState.Idle
    private var pendingCommit: VoiceInputCommit? = null

    fun currentState(): VoiceInputUiState = state

    fun onMicTapped() {
        when (state) {
            is VoiceInputUiState.Idle, is VoiceInputUiState.Error -> startListening()
            is VoiceInputUiState.PendingCommit -> {
                pendingCommit = null
                startListening()
            }
            is VoiceInputUiState.Listening -> finishListening()
            is VoiceInputUiState.Processing -> cancel()
        }
    }

    fun commitPending() {
        val commit = pendingCommit ?: return
        observer.onCommitRequested(commit)
        pendingCommit = null
        updateState(VoiceInputUiState.Idle)
    }

    fun discardPending() {
        pendingCommit = null
        updateState(VoiceInputUiState.Idle)
    }

    fun dismissError() {
        updateState(VoiceInputUiState.Idle)
    }

    fun stop() {
        engine.stop()
        pendingCommit = null
        updateState(VoiceInputUiState.Idle)
    }

    fun destroy() {
        pendingCommit = null
        engine.destroy()
    }

    override fun onReady() {
        updateState(VoiceInputUiState.Listening())
    }

    override fun onPartialResult(text: String) {
        updateState(VoiceInputUiState.Listening(partialTranscript = text))
    }

    override fun onFinalResult(text: String) {
        updateState(VoiceInputUiState.Processing)
        val profile = configStore.loadProfile()
        postProcessor.process(text, profile, object : VoiceTranscriptPostProcessorCallback {
            override fun onSuccess(text: String) {
                val normalized = text.trim()
                if (normalized.isEmpty()) {
                    updateState(VoiceInputUiState.Error("No speech recognized."))
                    return
                }

                val commit = TranscriptCommitPlanner.plan(normalized, profile)
                if (profile.autoCommit) {
                    observer.onCommitRequested(commit)
                    pendingCommit = null
                    updateState(VoiceInputUiState.Idle)
                } else {
                    pendingCommit = commit
                    updateState(VoiceInputUiState.PendingCommit(commit.text))
                }
            }

            override fun onError(message: String) {
                pendingCommit = null
                updateState(VoiceInputUiState.Error(message))
            }
        })
    }

    override fun onError(message: String) {
        pendingCommit = null
        updateState(VoiceInputUiState.Error(message))
    }

    private fun startListening() {
        pendingCommit = null
        updateState(VoiceInputUiState.Listening())
        engine.start(configStore.loadProfile(), this)
    }

    private fun cancel() {
        engine.cancel()
        pendingCommit = null
        updateState(VoiceInputUiState.Idle)
    }

    private fun finishListening() {
        engine.stop()
        updateState(VoiceInputUiState.Processing)
    }

    private fun updateState(next: VoiceInputUiState) {
        state = next
        observer.onStateChanged(next)
    }
}
