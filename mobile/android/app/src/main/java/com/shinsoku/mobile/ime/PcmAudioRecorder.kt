package com.shinsoku.mobile.ime

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.util.concurrent.atomic.AtomicBoolean

class PcmAudioRecorder(
    private val sampleRateHz: Int = 16_000,
    private val channelCount: Int = 1,
) {
    private val running = AtomicBoolean(false)
    private var audioRecord: AudioRecord? = null
    private var worker: Thread? = null

    fun start(
        onChunk: (ByteArray) -> Unit,
        onError: (String) -> Unit,
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
        val recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRateHz,
            channelConfig,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize,
        )
        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
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

        worker = Thread {
            val buffer = ByteArray(bufferSize)
            try {
                while (running.get()) {
                    val read = recorder.read(buffer, 0, buffer.size)
                    when {
                        read > 0 -> onChunk(buffer.copyOf(read))
                        read < 0 && running.get() -> {
                            onError("Audio capture failed.")
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
}
