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
import java.util.concurrent.atomic.AtomicInteger

class BailianStreamingRecognitionEngine(
    @Suppress("UNUSED_PARAMETER") private val context: Context,
    private val providerConfig: VoiceProviderConfig,
) : VoiceInputEngine {
    private val client = OkHttpClient()
    private val recorder = PcmAudioRecorder()
    private val transcriptAccumulator = BailianTranscriptAccumulator()
    private var socket: WebSocket? = null
    private var listener: VoiceInputEngine.Listener? = null
    private var finalDelivered = false
    private var finalized = false
    private var taskId = ""

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
        transcriptAccumulator.reset()

        val request = Request.Builder()
            .url(providerConfig.bailian.url)
            .addHeader("Authorization", "bearer ${providerConfig.bailian.apiKey}")
            .build()
        socket = client.newWebSocket(request, ListenerAdapter())
    }

    override fun stop() {
        if (finalized) return
        finalized = true
        recorder.stop()
        socket?.send(
            JSONObject()
                .put("header", JSONObject().put("action", "finish-task").put("task_id", taskId).put("streaming", "duplex"))
                .put("payload", JSONObject().put("input", JSONObject()))
                .toString(),
        )
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
                    recorder.start(
                        onChunk = { bytes ->
                            if (!webSocket.send(bytes.toByteString())) {
                                emitError("Failed to stream audio to Bailian.")
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
                emitError(t.message ?: "Bailian connection failed.")
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
        recorder.cancel()
        listener = null
        socket = null
    }

    private companion object {
        private val nextTaskId = AtomicInteger(1)

        fun makeTaskId(): String =
            "android-${Integer.toHexString(System.currentTimeMillis().toInt())}-${nextTaskId.getAndIncrement().toString(16).lowercase(Locale.US)}"
    }
}
