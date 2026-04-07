package com.shinsoku.mobile.speechcore

interface VoiceInputControllerObserver {
    fun onStateChanged(state: VoiceInputUiState)
    fun onCommitRequested(commit: VoiceInputCommit)
}
