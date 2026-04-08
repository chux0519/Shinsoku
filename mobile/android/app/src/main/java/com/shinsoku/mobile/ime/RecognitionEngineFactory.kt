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
                SonioxStreamingRecognitionEngine(context, providerConfig)

            VoiceRecognitionProvider.Bailian ->
                BailianStreamingRecognitionEngine(context, providerConfig)
        }
    }
}
