package com.shinsoku.mobile.speechcore

class VoiceInputController(
    private val engine: VoiceInputEngine,
    private val configStore: VoiceInputConfigStore,
    private val observer: VoiceInputControllerObserver,
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
            is VoiceInputUiState.Listening, is VoiceInputUiState.Processing -> cancel()
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
        val normalized = text.trim()
        if (normalized.isEmpty()) {
            updateState(VoiceInputUiState.Error("No speech recognized."))
            return
        }

        val committedText = normalized + when (profile.commitSuffixMode) {
            CommitSuffixMode.None -> ""
            CommitSuffixMode.Space -> " "
            CommitSuffixMode.Newline -> "\n"
        }

        if (profile.autoCommit) {
            observer.onCommitRequested(VoiceInputCommit(committedText))
            pendingCommit = null
            updateState(VoiceInputUiState.Idle)
        } else {
            pendingCommit = VoiceInputCommit(committedText)
            updateState(VoiceInputUiState.PendingCommit(committedText))
        }
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

    private fun updateState(next: VoiceInputUiState) {
        state = next
        observer.onStateChanged(next)
    }
}
