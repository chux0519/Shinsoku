package com.shinsoku.mobile.speechcore

interface VoiceInputEngine {
    interface Listener {
        fun onReady()
        fun onPartialResult(text: String)
        fun onFinalResult(text: String)
        fun onError(message: String)
    }

    fun start(profile: VoiceInputProfile, listener: Listener)
    fun stop()
    fun cancel()
    fun destroy()
}
