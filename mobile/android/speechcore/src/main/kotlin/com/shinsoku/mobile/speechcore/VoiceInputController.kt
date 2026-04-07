package com.shinsoku.mobile.speechcore

class VoiceInputController(
    private val engine: VoiceInputEngine,
    private val configStore: VoiceInputConfigStore,
    private val observer: VoiceInputControllerObserver,
) : VoiceInputEngine.Listener {
    private var state: VoiceInputUiState = VoiceInputUiState.Idle

    fun currentState(): VoiceInputUiState = state

    fun onMicTapped() {
        when (state) {
            is VoiceInputUiState.Idle, is VoiceInputUiState.Error -> startListening()
            is VoiceInputUiState.Listening, is VoiceInputUiState.Processing -> cancel()
        }
    }

    fun dismissError() {
        updateState(VoiceInputUiState.Idle)
    }

    fun stop() {
        engine.stop()
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

        val committedText = buildString {
            append(normalized)
            if (profile.appendTrailingSpace) {
                append(' ')
            }
        }

        if (profile.autoCommit) {
            observer.onCommitRequested(VoiceInputCommit(committedText))
        }
        updateState(VoiceInputUiState.Idle)
    }

    override fun onError(message: String) {
        updateState(VoiceInputUiState.Error(message))
    }

    private fun startListening() {
        updateState(VoiceInputUiState.Listening())
        engine.start(configStore.loadProfile(), this)
    }

    private fun cancel() {
        engine.cancel()
        updateState(VoiceInputUiState.Idle)
    }

    private fun updateState(next: VoiceInputUiState) {
        state = next
        observer.onStateChanged(next)
    }
}
