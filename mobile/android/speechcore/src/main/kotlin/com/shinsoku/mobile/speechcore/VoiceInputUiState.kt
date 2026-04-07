package com.shinsoku.mobile.speechcore

sealed interface VoiceInputUiState {
    data object Idle : VoiceInputUiState
    data class Listening(val partialTranscript: String = "") : VoiceInputUiState
    data object Processing : VoiceInputUiState
    data class Error(val message: String) : VoiceInputUiState
}
