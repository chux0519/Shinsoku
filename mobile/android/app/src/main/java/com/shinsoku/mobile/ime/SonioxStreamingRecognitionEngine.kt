package com.shinsoku.mobile.ime

import android.content.Context
import com.shinsoku.mobile.speechcore.VoiceInputEngine
import com.shinsoku.mobile.speechcore.VoiceInputProfile
import com.shinsoku.mobile.speechcore.VoiceProviderConfig
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString.Companion.toByteString
import org.json.JSONArray
import org.json.JSONObject

class SonioxStreamingRecognitionEngine(
    @Suppress("UNUSED_PARAMETER") private val context: Context,
    private val providerConfig: VoiceProviderConfig,
) : VoiceInputEngine {
    private val client = OkHttpClient()
    private val recorder = PcmAudioRecorder()
    private val transcriptAccumulator = SonioxTranscriptAccumulator()
    private var socket: WebSocket? = null
    private var listener: VoiceInputEngine.Listener? = null
    private var profile: VoiceInputProfile? = null
    private var lastPartialText = ""
    private var finalCandidateText = ""
    private var finalDelivered = false
    private var finalized = false

    override fun start(profile: VoiceInputProfile, listener: VoiceInputEngine.Listener) {
        RecognitionProviderDiagnostics.requireReady(
            providerConfig.copy(activeRecognitionProvider = com.shinsoku.mobile.speechcore.VoiceRecognitionProvider.Soniox),
        )?.let {
            listener.onError(it)
            return
        }
        this.listener = listener
        this.profile = profile
        lastPartialText = ""
        finalCandidateText = ""
        finalDelivered = false
        finalized = false
        transcriptAccumulator.reset()

        val request = Request.Builder()
            .url(providerConfig.soniox.url)
            .build()
        socket = client.newWebSocket(request, ListenerAdapter())
    }

    override fun stop() {
        if (finalized) return
        finalized = true
        recorder.stop()
        socket?.send("""{"type":"finalize"}""")
        socket?.send(ByteArray(0).toByteString())
    }

    override fun cancel() {
        recorder.cancel()
        socket?.close(1000, "cancel")
        cleanup()
    }

    override fun destroy() {
        cancel()
    }

    private inner class ListenerAdapter : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            val currentProfile = profile
            val start = JSONObject()
                .put("api_key", providerConfig.soniox.apiKey)
                .put("model", providerConfig.soniox.model)
                .put("audio_format", "s16le")
                .put("num_channels", 1)
                .put("sample_rate", 16_000)
            currentProfile?.languageTag
                ?.takeIf { it.isNotBlank() }
                ?.let { start.put("language_hints", JSONArray().put(it)) }
            if (!webSocket.send(start.toString())) {
                emitError("Failed to send Soniox start message.")
                webSocket.close(1011, "start failed")
                return
            }
            recorder.start(
                onChunk = { bytes ->
                    if (!webSocket.send(bytes.toByteString())) {
                        emitError("Failed to stream audio to Soniox.")
                        webSocket.close(1011, "audio send failed")
                    }
                },
                onError = { error ->
                    emitError(error)
                    webSocket.close(1011, error)
                },
            )
            listener?.onReady()
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            val payload = runCatching { JSONObject(text) }.getOrElse {
                emitError("Invalid Soniox message.")
                webSocket.close(1011, "invalid json")
                return
            }

            val update = transcriptAccumulator.consume(payload)
            if (update.errorMessage != null) {
                emitError(update.errorMessage)
                webSocket.close(1011, "soniox error")
                return
            }

            if (update.partialText.isNotBlank() && update.partialText != lastPartialText && !finalDelivered) {
                lastPartialText = update.partialText
                listener?.onPartialResult(update.partialText)
            }
            val candidateText = if (update.finalText.isNotBlank()) update.finalText else update.partialText
            finalCandidateText = candidateText
            if (update.finished && candidateText.isNotBlank() && !finalDelivered) {
                finalDelivered = true
                listener?.onFinalResult(candidateText)
                webSocket.close(1000, "done")
            }
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            if (!finalDelivered) {
                emitError(t.message ?: "Soniox connection failed.")
            }
            cleanup()
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            if (finalized && !finalDelivered && finalCandidateText.isNotBlank()) {
                finalDelivered = true
                listener?.onFinalResult(finalCandidateText)
            } else if (finalized && !finalDelivered) {
                emitError("No speech recognized.")
            }
            cleanup()
        }
    }

    private fun emitError(message: String) {
        listener?.onError(message)
    }

    private fun cleanup() {
        recorder.cancel()
        listener = null
        profile = null
        socket = null
    }
}
