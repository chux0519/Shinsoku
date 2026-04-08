package com.shinsoku.mobile.ime

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import com.shinsoku.mobile.speechcore.VoiceInputEngine
import com.shinsoku.mobile.speechcore.VoiceInputProfile

class AndroidSpeechRecognizerEngine(
    private val context: Context,
) : VoiceInputEngine {
    private var speechRecognizer: SpeechRecognizer? = null
    private var activeListener: VoiceInputEngine.Listener? = null

    override fun start(profile: VoiceInputProfile, listener: VoiceInputEngine.Listener) {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            listener.onError("Speech recognition is unavailable on this device.")
            return
        }

        runCatching {
            activeListener = listener
            val recognizer = speechRecognizer ?: SpeechRecognizer.createSpeechRecognizer(context).also {
                speechRecognizer = it
                it.setRecognitionListener(ListenerAdapter())
            }

            recognizer.startListening(
                Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                    )
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    profile.languageTag?.takeIf { it.isNotBlank() }?.let {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, it)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, it)
                    }
                },
            )
        }.onFailure { error ->
            listener.onError(error.message ?: "Failed to start Android speech recognition.")
            activeListener = null
        }
    }

    override fun stop() {
        runCatching {
            speechRecognizer?.stopListening()
        }.onFailure {
            activeListener?.onError("Failed to stop Android speech recognition.")
        }
    }

    override fun cancel() {
        runCatching {
            speechRecognizer?.cancel()
        }
    }

    override fun destroy() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        activeListener = null
    }

    private inner class ListenerAdapter : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            activeListener?.onReady()
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val text = partialResults.bestResult()
            if (text.isNotBlank()) {
                activeListener?.onPartialResult(text)
            }
        }

        override fun onResults(results: Bundle?) {
            val text = results.bestResult()
            if (text.isBlank()) {
                activeListener?.onError("No speech recognized.")
            } else {
                activeListener?.onFinalResult(text)
            }
        }

        override fun onError(error: Int) {
            activeListener?.onError(errorMessage(error))
        }

        override fun onBeginningOfSpeech() = Unit
        override fun onBufferReceived(buffer: ByteArray?) = Unit
        override fun onEndOfSpeech() = Unit
        override fun onEvent(eventType: Int, params: Bundle?) = Unit
        override fun onRmsChanged(rmsdB: Float) = Unit

        private fun errorMessage(error: Int): String = when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording failed."
            SpeechRecognizer.ERROR_CLIENT -> "Speech recognizer client error."
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission is missing."
            SpeechRecognizer.ERROR_NETWORK -> "Network error while recognizing speech."
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Speech recognition timed out."
            SpeechRecognizer.ERROR_NO_MATCH -> "No speech recognized."
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognizer is busy."
            SpeechRecognizer.ERROR_SERVER -> "Speech recognition server error."
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Listening timed out."
            else -> "Speech recognition failed."
        }

        private fun Bundle?.bestResult(): String {
            val values = this?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            return values?.firstOrNull().orEmpty()
        }
    }
}
