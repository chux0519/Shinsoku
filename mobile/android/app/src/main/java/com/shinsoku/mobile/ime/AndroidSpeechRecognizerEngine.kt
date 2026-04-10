package com.shinsoku.mobile.ime

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Bundle
import android.os.Looper
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import com.shinsoku.mobile.speechcore.VoiceInputEngine
import com.shinsoku.mobile.speechcore.VoiceInputProfile

class AndroidSpeechRecognizerEngine(
    private val context: Context,
) : VoiceInputEngine {
    companion object {
        private const val INITIAL_START_DELAY_MS = 220L
        private const val RETRY_DELAY_MS = 260L
        private const val EARLY_FAILURE_WINDOW_MS = 1500L
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private var activeListener: VoiceInputEngine.Listener? = null
    private var activeProfile: VoiceInputProfile? = null
    private var hasRetriedCurrentSession = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sessionStartUptimeMs: Long = 0L

    init {
        warmUpRecognizer()
    }

    override fun start(profile: VoiceInputProfile, listener: VoiceInputEngine.Listener) {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            listener.onError("Speech recognition is unavailable on this device.")
            return
        }

        runCatching {
            activeListener = listener
            activeProfile = profile
            hasRetriedCurrentSession = false
            sessionStartUptimeMs = SystemClock.elapsedRealtime()
            ensureRecognizer()
            mainHandler.removeCallbacksAndMessages(null)
            mainHandler.postDelayed(
                {
                    runCatching {
                        ensureRecognizer().startListening(createRecognizerIntent(profile))
                    }.onFailure { error ->
                        activeListener?.onError(
                            error.message ?: "Failed to start Android speech recognition.",
                        )
                        activeListener = null
                        activeProfile = null
                    }
                },
                INITIAL_START_DELAY_MS,
            )
        }.onFailure { error ->
            listener.onError(error.message ?: "Failed to start Android speech recognition.")
            activeListener = null
            activeProfile = null
        }
    }

    override fun stop() {
        mainHandler.removeCallbacksAndMessages(null)
        runCatching {
            speechRecognizer?.stopListening()
        }.onFailure {
            activeListener?.onError("Failed to stop Android speech recognition.")
        }
    }

    override fun cancel() {
        mainHandler.removeCallbacksAndMessages(null)
        runCatching {
            speechRecognizer?.cancel()
        }
    }

    override fun destroy() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        activeListener = null
        activeProfile = null
        hasRetriedCurrentSession = false
        mainHandler.removeCallbacksAndMessages(null)
    }

    private inner class ListenerAdapter : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            hasRetriedCurrentSession = false
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
            activeProfile = null
        }

        override fun onError(error: Int) {
            val isEarlyFailure =
                SystemClock.elapsedRealtime() - sessionStartUptimeMs <= EARLY_FAILURE_WINDOW_MS
            val shouldRetry =
                !hasRetriedCurrentSession &&
                    isEarlyFailure &&
                    (error == SpeechRecognizer.ERROR_CLIENT ||
                        error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY ||
                        error == SpeechRecognizer.ERROR_NO_MATCH ||
                        error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT)

            if (shouldRetry) {
                val profile = activeProfile
                val listener = activeListener
                if (profile != null && listener != null) {
                    hasRetriedCurrentSession = true
                    mainHandler.postDelayed(
                        {
                            runCatching {
                                ensureRecognizer().startListening(createRecognizerIntent(profile))
                            }.onFailure {
                                activeListener?.onError("Speech recognizer client error.")
                            }
                        },
                        RETRY_DELAY_MS,
                    )
                    return
                }
            }
            activeListener?.onError(errorMessage(error))
            activeProfile = null
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

    private fun warmUpRecognizer() {
        runCatching {
            ensureRecognizer()
        }
    }

    private fun ensureRecognizer(): SpeechRecognizer {
        return speechRecognizer ?: SpeechRecognizer.createSpeechRecognizer(context).also {
            speechRecognizer = it
            it.setRecognitionListener(ListenerAdapter())
        }
    }

    private fun createRecognizerIntent(profile: VoiceInputProfile): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            profile.languageTag?.takeIf { it.isNotBlank() }?.let {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, it)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, it)
            }
        }
    }
}
