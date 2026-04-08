package com.shinsoku.mobile.ime

import android.content.Context
import com.shinsoku.mobile.speechcore.VoiceInputEngine
import com.shinsoku.mobile.speechcore.VoiceInputProfile
import com.shinsoku.mobile.speechcore.VoiceProviderConfig
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.Executors

class OpenAiBatchRecognitionEngine(
    private val context: Context,
    private val providerConfig: VoiceProviderConfig,
) : VoiceInputEngine {
    private val client = OkHttpClient.Builder()
        .dns(ShinsokuDns)
        .build()
    private val executor = Executors.newSingleThreadExecutor()
    private val pcmRecorder = PcmAudioRecorder()
    private val pcmBuffer = ByteArrayOutputStream()
    private var recordingActive = false
    private var outputFile: File? = null
    private var activeListener: VoiceInputEngine.Listener? = null
    private var activeProfile: VoiceInputProfile? = null
    private val transcriptionEndpoint: String
        get() = providerConfig.openAiRecognition.baseUrl.trimEnd('/') + "/audio/transcriptions"

    override fun start(profile: VoiceInputProfile, listener: VoiceInputEngine.Listener) {
        if (providerConfig.openAiRecognition.apiKey.isBlank()) {
            listener.onError("OpenAI-compatible API key is missing.")
            return
        }
        if (providerConfig.openAiRecognition.transcriptionModel.isBlank()) {
            listener.onError("OpenAI-compatible transcription model is missing.")
            return
        }

        runCatching {
            activeListener = listener
            activeProfile = profile
            pcmBuffer.reset()
            val tempFile = File.createTempFile("shinsoku-", ".wav", context.cacheDir)
            outputFile = tempFile
            recordingActive = true
            pcmRecorder.start(
                onChunk = { chunk -> synchronized(pcmBuffer) { pcmBuffer.write(chunk) } },
                onError = { message ->
                    if (recordingActive) {
                        cleanupRecording(deleteFile = true)
                        listener.onError(message)
                    }
                },
            )
            listener.onReady()
        }.onFailure { error ->
            cleanupRecording(deleteFile = true)
            listener.onError(
                RecognitionEndpointDebug.formatFailure(
                    providerName = "OpenAI-compatible",
                    endpoint = transcriptionEndpoint,
                    throwable = error,
                ),
            )
        }
    }

    override fun stop() {
        val listener = activeListener ?: return
        val profile = activeProfile
        val file = outputFile
        if (profile == null || file == null || !recordingActive) {
            listener.onError("Recording session is not active.")
            cleanupRecording(deleteFile = true)
            return
        }

        runCatching {
            recordingActive = false
            pcmRecorder.stop()
            writeWavFile(file)
        }.onFailure { error ->
            cleanupRecording(deleteFile = true)
            listener.onError(
                RecognitionEndpointDebug.formatFailure(
                    providerName = "OpenAI-compatible",
                    endpoint = transcriptionEndpoint,
                    throwable = error,
                ),
            )
            return
        }

        executor.execute {
            try {
                val text = transcribe(file, profile)
                if (text.isBlank()) {
                    listener.onError("No speech recognized.")
                } else {
                    listener.onFinalResult(text)
                }
            } catch (error: Exception) {
                listener.onError(
                    RecognitionEndpointDebug.formatFailure(
                        providerName = "OpenAI-compatible",
                        endpoint = transcriptionEndpoint,
                        throwable = error,
                    ),
                )
            } finally {
                cleanupRecording(deleteFile = true)
            }
        }
    }

    override fun cancel() {
        recordingActive = false
        runCatching { pcmRecorder.stop() }
        cleanupRecording(deleteFile = true)
    }

    override fun destroy() {
        cancel()
        executor.shutdownNow()
    }

    private fun transcribe(file: File, profile: VoiceInputProfile): String {
        val requestBody = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("model", providerConfig.openAiRecognition.transcriptionModel)
            .addFormDataPart(
                "file",
                file.name,
                file.asRequestBody("audio/wav".toMediaType()),
            )
            .apply {
                profile.languageTag
                    ?.substringBefore('-')
                    ?.takeIf { it.isNotBlank() }
                    ?.let { addFormDataPart("language", it) }
            }
            .addFormDataPart("response_format", "json")
            .build()

        val request = Request.Builder()
            .url(transcriptionEndpoint)
            .addHeader("Authorization", "Bearer ${providerConfig.openAiRecognition.apiKey}")
            .post(requestBody)
            .build()

        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw IOException(
                    if (body.isBlank()) "OpenAI transcription request failed with ${response.code}."
                    else body,
                )
            }
            return JSONObject(body).optString("text").orEmpty()
        }
    }

    private fun cleanupRecording(deleteFile: Boolean) {
        recordingActive = false
        runCatching { pcmRecorder.stop() }
        synchronized(pcmBuffer) { pcmBuffer.reset() }
        activeListener = null
        activeProfile = null
        val file = outputFile
        outputFile = null
        if (deleteFile) {
            file?.delete()
        }
    }

    private fun writeWavFile(file: File) {
        val pcm = synchronized(pcmBuffer) {
            pcmBuffer.toByteArray().also { pcmBuffer.reset() }
        }
        FileOutputStream(file).use { output ->
            output.write(buildWavHeader(pcm.size, sampleRateHz = 16_000, channelCount = 1, bitsPerSample = 16))
            output.write(pcm)
        }
    }

    private fun buildWavHeader(
        dataSize: Int,
        sampleRateHz: Int,
        channelCount: Int,
        bitsPerSample: Int,
    ): ByteArray {
        val byteRate = sampleRateHz * channelCount * bitsPerSample / 8
        val blockAlign = channelCount * bitsPerSample / 8
        val chunkSize = 36 + dataSize
        return ByteArray(44).apply {
            writeAscii(0, "RIFF")
            writeIntLE(4, chunkSize)
            writeAscii(8, "WAVE")
            writeAscii(12, "fmt ")
            writeIntLE(16, 16)
            writeShortLE(20, 1)
            writeShortLE(22, channelCount)
            writeIntLE(24, sampleRateHz)
            writeIntLE(28, byteRate)
            writeShortLE(32, blockAlign)
            writeShortLE(34, bitsPerSample)
            writeAscii(36, "data")
            writeIntLE(40, dataSize)
        }
    }

    private fun ByteArray.writeAscii(offset: Int, value: String) {
        value.forEachIndexed { index, char -> this[offset + index] = char.code.toByte() }
    }

    private fun ByteArray.writeIntLE(offset: Int, value: Int) {
        this[offset] = (value and 0xFF).toByte()
        this[offset + 1] = ((value shr 8) and 0xFF).toByte()
        this[offset + 2] = ((value shr 16) and 0xFF).toByte()
        this[offset + 3] = ((value shr 24) and 0xFF).toByte()
    }

    private fun ByteArray.writeShortLE(offset: Int, value: Int) {
        this[offset] = (value and 0xFF).toByte()
        this[offset + 1] = ((value shr 8) and 0xFF).toByte()
    }
}
