package com.shinsoku.mobile.ime

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.SystemClock
import java.util.concurrent.atomic.AtomicBoolean

class PcmAudioRecorder(
    private val sampleRateHz: Int = 16_000,
    private val channelCount: Int = 1,
) {
    private companion object {
        private const val STARTUP_GRACE_PERIOD_MS = 1_600L
        private const val MAX_CONSECUTIVE_READ_ERRORS = 4
        private const val RETRY_SLEEP_MS = 20L
    }

    private val running = AtomicBoolean(false)
    private var audioRecord: AudioRecord? = null
    private var worker: Thread? = null

    fun start(
        onChunk: (ByteArray) -> Unit,
        onError: (String) -> Unit,
        onStarted: (() -> Unit)? = null,
    ): Boolean {
        if (running.get()) {
            onError("Audio recorder is already running.")
            return false
        }

        val channelConfig = if (channelCount == 1) {
            AudioFormat.CHANNEL_IN_MONO
        } else {
            AudioFormat.CHANNEL_IN_STEREO
        }
        val minBufferSize = AudioRecord.getMinBufferSize(
            sampleRateHz,
            channelConfig,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBufferSize <= 0) {
            onError("Audio recording is unavailable on this device.")
            return false
        }

        val bufferSize = maxOf(minBufferSize * 2, sampleRateHz / 5)
        val recorder = createRecorderWithFallback(channelConfig, bufferSize) ?: run {
            onError("Failed to initialize audio recorder.")
            return false
        }

        audioRecord = recorder
        running.set(true)
        runCatching {
            recorder.startRecording()
        }.onFailure { error ->
            running.set(false)
            recorder.release()
            audioRecord = null
            onError(error.message ?: "Failed to start audio recording.")
            return false
        }
        if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            running.set(false)
            recorder.release()
            audioRecord = null
            onError("Failed to enter recording state.")
            return false
        }

        worker = Thread {
            val buffer = ByteArray(bufferSize)
            val startupDeadline = SystemClock.elapsedRealtime() + STARTUP_GRACE_PERIOD_MS
            var consecutiveReadErrors = 0
            var firstChunkDelivered = false
            try {
                while (running.get()) {
                    val read = recorder.read(buffer, 0, buffer.size)
                    when {
                        read > 0 -> {
                            consecutiveReadErrors = 0
                            if (!firstChunkDelivered) {
                                firstChunkDelivered = true
                                onStarted?.invoke()
                            }
                            onChunk(buffer.copyOf(read))
                        }
                        read == 0 -> {
                            Thread.sleep(RETRY_SLEEP_MS)
                        }
                        read < 0 && running.get() -> {
                            val duringStartup = SystemClock.elapsedRealtime() < startupDeadline
                            consecutiveReadErrors += 1
                            if (duringStartup || consecutiveReadErrors < MAX_CONSECUTIVE_READ_ERRORS) {
                                Thread.sleep(RETRY_SLEEP_MS)
                                continue
                            }
                            onError("Audio capture failed (code=$read).")
                            running.set(false)
                            break
                        }
                    }
                }
            } catch (_: Exception) {
                if (running.get()) {
                    onError("Audio capture failed.")
                }
            }
        }.apply {
            name = "ShinsokuPcmRecorder"
            start()
        }

        return true
    }

    fun stop() {
        if (!running.getAndSet(false)) {
            releaseRecorder()
            return
        }
        runCatching { audioRecord?.stop() }
        worker?.join(1_000)
        releaseRecorder()
    }

    fun cancel() {
        stop()
    }

    private fun releaseRecorder() {
        worker = null
        audioRecord?.release()
        audioRecord = null
    }

    private fun createRecorderWithFallback(channelConfig: Int, bufferSize: Int): AudioRecord? {
        val candidateSources = intArrayOf(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.MIC,
        )
        for (source in candidateSources) {
            val recorder = AudioRecord(
                source,
                sampleRateHz,
                channelConfig,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize,
            )
            if (recorder.state == AudioRecord.STATE_INITIALIZED) {
                return recorder
            }
            recorder.release()
        }
        return null
    }
}
