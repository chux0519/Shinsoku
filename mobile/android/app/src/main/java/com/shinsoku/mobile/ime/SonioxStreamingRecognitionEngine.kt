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
import java.util.ArrayDeque

class SonioxStreamingRecognitionEngine(
    @Suppress("UNUSED_PARAMETER") private val context: Context,
    private val providerConfig: VoiceProviderConfig,
) : VoiceInputEngine {
    private val client = OkHttpClient.Builder()
        .dns(ShinsokuDns)
        .build()
    private val recorder = PcmAudioRecorder()
    private val transcriptAccumulator = SonioxTranscriptAccumulator()
    private var socket: WebSocket? = null
    private var listener: VoiceInputEngine.Listener? = null
    private var profile: VoiceInputProfile? = null
    private var lastPartialText = ""
    private var finalCandidateText = ""
    private var finalDelivered = false
    private var finalized = false
    private var recorderStarted = false
    private var streamReady = false
    private val pendingAudio = ArrayDeque<ByteArray>()
    private val sendLock = Any()

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
        recorderStarted = false
        streamReady = false
        transcriptAccumulator.reset()
        pendingAudio.clear()

        if (!startRecorder()) {
            return
        }

        val request = Request.Builder()
            .url(providerConfig.soniox.url)
            .build()
        socket = client.newWebSocket(request, ListenerAdapter())
    }

    override fun stop() {
        if (finalized) return
        finalized = true
        stopRecorder()
        synchronized(sendLock) {
            if (streamReady) {
                sendFinalize(socket)
            }
        }
    }

    override fun cancel() {
        stopRecorder()
        synchronized(sendLock) {
            pendingAudio.clear()
            streamReady = false
        }
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
            synchronized(sendLock) {
                streamReady = true
                flushPendingAudio(webSocket)
                if (finalized) {
                    sendFinalize(webSocket)
                }
            }
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
                emitError(
                    RecognitionEndpointDebug.formatFailure(
                        providerName = "Soniox",
                        endpoint = providerConfig.soniox.url,
                        throwable = t,
                    ) + "\n" + NetworkPreflight.resolveEndpoint(providerConfig.soniox.url).detail,
                )
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
        stopRecorder()
        synchronized(sendLock) {
            pendingAudio.clear()
            streamReady = false
        }
        listener = null
        profile = null
        socket = null
    }

    private fun startRecorder(): Boolean {
        val started = recorder.start(
            onChunk = { bytes ->
                synchronized(sendLock) {
                    val webSocket = socket
                    if (streamReady && webSocket != null) {
                        if (!webSocket.send(bytes.toByteString())) {
                            emitError("Failed to stream audio to Soniox.")
                            webSocket.close(1011, "audio send failed")
                        }
                    } else {
                        pendingAudio.addLast(bytes)
                    }
                }
            },
            onStarted = {
                listener?.onReady()
            },
            onError = { error ->
                emitError(error)
                socket?.close(1011, error)
            },
        )
        if (!started) {
            return false
        }
        recorderStarted = true
        return true
    }

    private fun stopRecorder() {
        if (!recorderStarted) return
        recorderStarted = false
        recorder.stop()
    }

    private fun flushPendingAudio(webSocket: WebSocket) {
        while (pendingAudio.isNotEmpty()) {
            val chunk = pendingAudio.removeFirst()
            if (!webSocket.send(chunk.toByteString())) {
                pendingAudio.clear()
                emitError("Failed to stream audio to Soniox.")
                webSocket.close(1011, "audio send failed")
                return
            }
        }
    }

    private fun sendFinalize(webSocket: WebSocket?) {
        if (webSocket == null) return
        webSocket.send("""{"type":"finalize"}""")
        webSocket.send(ByteArray(0).toByteString())
    }
}
