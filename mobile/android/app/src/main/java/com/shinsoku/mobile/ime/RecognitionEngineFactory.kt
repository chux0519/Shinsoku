package com.shinsoku.mobile.ime

import android.content.Context
import com.shinsoku.mobile.settings.AndroidVoiceProviderConfigStore
import com.shinsoku.mobile.speechcore.VoiceInputEngine
import com.shinsoku.mobile.speechcore.VoiceRecognitionProvider

object RecognitionEngineFactory {
    fun create(context: Context): VoiceInputEngine {
        val providerConfig = AndroidVoiceProviderConfigStore(context).load()
        return when (providerConfig.activeRecognitionProvider) {
            VoiceRecognitionProvider.AndroidSystem ->
                AndroidSpeechRecognizerEngine(context)

            VoiceRecognitionProvider.OpenAiCompatible ->
                OpenAiBatchRecognitionEngine(context, providerConfig)

            VoiceRecognitionProvider.Soniox ->
                UnsupportedRecognitionEngine("Soniox streaming is not wired yet on Android.")

            VoiceRecognitionProvider.Bailian ->
                UnsupportedRecognitionEngine("Bailian streaming is not wired yet on Android.")
        }
    }
}

private class UnsupportedRecognitionEngine(
    private val message: String,
) : VoiceInputEngine {
    override fun start(
        profile: com.shinsoku.mobile.speechcore.VoiceInputProfile,
        listener: VoiceInputEngine.Listener,
    ) {
        listener.onError(message)
    }

    override fun stop() = Unit
    override fun cancel() = Unit
    override fun destroy() = Unit
}
