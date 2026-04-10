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
import org.json.JSONObject
import java.util.Locale
import java.util.ArrayDeque
import java.util.concurrent.atomic.AtomicInteger

class BailianStreamingRecognitionEngine(
    @Suppress("UNUSED_PARAMETER") private val context: Context,
    private val providerConfig: VoiceProviderConfig,
) : VoiceInputEngine {
    private val client = OkHttpClient.Builder()
        .dns(ShinsokuDns)
        .build()
    private val recorder = PcmAudioRecorder()
    private val transcriptAccumulator = BailianTranscriptAccumulator()
    private var socket: WebSocket? = null
    private var listener: VoiceInputEngine.Listener? = null
    private var finalDelivered = false
    private var finalized = false
    private var taskId = ""
    private var recorderStarted = false
    private var streamReady = false
    private val pendingAudio = ArrayDeque<ByteArray>()
    private val sendLock = Any()

    override fun start(profile: VoiceInputProfile, listener: VoiceInputEngine.Listener) {
        RecognitionProviderDiagnostics.requireReady(
            providerConfig.copy(activeRecognitionProvider = com.shinsoku.mobile.speechcore.VoiceRecognitionProvider.Bailian),
        )?.let {
            listener.onError(it)
            return
        }
        this.listener = listener
        finalDelivered = false
        finalized = false
        taskId = makeTaskId()
        recorderStarted = false
        streamReady = false
        transcriptAccumulator.reset()
        pendingAudio.clear()

        if (!startRecorder()) {
            return
        }

        val request = Request.Builder()
            .url(providerConfig.bailian.url)
            .addHeader("Authorization", "bearer ${providerConfig.bailian.apiKey}")
            .build()
        socket = client.newWebSocket(request, ListenerAdapter())
    }

    override fun stop() {
        if (finalized) return
        finalized = true
        stopRecorder()
        synchronized(sendLock) {
            if (streamReady) {
                sendFinishTask(socket)
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
            val runTask = JSONObject()
                .put(
                    "header",
                    JSONObject()
                        .put("action", "run-task")
                        .put("task_id", taskId)
                        .put("streaming", "duplex"),
                )
                .put(
                    "payload",
                    JSONObject()
                        .put("task_group", "audio")
                        .put("task", "asr")
                        .put("function", "recognition")
                        .put("model", providerConfig.bailian.model)
                        .put(
                            "parameters",
                            JSONObject()
                                .put("format", "pcm")
                                .put("sample_rate", 16_000),
                        )
                        .put("input", JSONObject()),
                )
            if (!webSocket.send(runTask.toString())) {
                emitError("Failed to send Bailian run-task.")
                webSocket.close(1011, "run-task failed")
            }
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            val payload = runCatching { JSONObject(text) }.getOrElse {
                emitError("Invalid Bailian message.")
                webSocket.close(1011, "invalid json")
                return
            }
            when (val event = transcriptAccumulator.consume(payload)) {
                is BailianTranscriptAccumulator.Event.Failed -> {
                    emitError(event.message)
                    webSocket.close(1011, "task-failed")
                }

                is BailianTranscriptAccumulator.Event.TaskStarted -> {
                    synchronized(sendLock) {
                        streamReady = true
                        flushPendingAudio(webSocket)
                        if (finalized) {
                            sendFinishTask(webSocket)
                        }
                    }
                }

                is BailianTranscriptAccumulator.Event.Partial -> {
                    if (event.text.isNotBlank()) {
                        listener?.onPartialResult(event.text)
                    }
                }

                is BailianTranscriptAccumulator.Event.Finished -> {
                    val finalText = event.text
                    if (!finalDelivered && finalText.isNotBlank()) {
                        finalDelivered = true
                        listener?.onFinalResult(finalText)
                    } else if (!finalDelivered) {
                        emitError("No speech recognized.")
                    }
                    webSocket.close(1000, "done")
                }

                BailianTranscriptAccumulator.Event.Ignored -> Unit
            }
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            if (!finalDelivered) {
                emitError(
                    RecognitionEndpointDebug.formatFailure(
                        providerName = "Bailian",
                        endpoint = providerConfig.bailian.url,
                        throwable = t,
                    ) + "\n" + NetworkPreflight.resolveEndpoint(providerConfig.bailian.url).detail,
                )
            }
            cleanup()
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
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
        socket = null
    }

    private fun startRecorder(): Boolean {
        val started = recorder.start(
            onChunk = { bytes ->
                synchronized(sendLock) {
                    val webSocket = socket
                    if (streamReady && webSocket != null) {
                        if (!webSocket.send(bytes.toByteString())) {
                            emitError("Failed to stream audio to Bailian.")
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
                emitError("Failed to stream audio to Bailian.")
                webSocket.close(1011, "audio send failed")
                return
            }
        }
    }

    private fun sendFinishTask(webSocket: WebSocket?) {
        if (webSocket == null) return
        webSocket.send(
            JSONObject()
                .put("header", JSONObject().put("action", "finish-task").put("task_id", taskId).put("streaming", "duplex"))
                .put("payload", JSONObject().put("input", JSONObject()))
                .toString(),
        )
    }

    private companion object {
        private val nextTaskId = AtomicInteger(1)

        fun makeTaskId(): String =
            "android-${Integer.toHexString(System.currentTimeMillis().toInt())}-${nextTaskId.getAndIncrement().toString(16).lowercase(Locale.US)}"
    }
}
