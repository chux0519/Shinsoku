package com.shinsoku.mobile.speechcore

fun interface VoiceTranscriptPostProcessor {
    fun process(
        rawText: String,
        profile: VoiceInputProfile,
        callback: VoiceTranscriptPostProcessorCallback,
    )
}

interface VoiceTranscriptPostProcessorCallback {
    fun onSuccess(text: String)

    fun onError(message: String)
}
