package com.shinsoku.mobile.ime

import android.content.Context
import android.media.MediaRecorder
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
import java.io.File
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
    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null
    private var activeListener: VoiceInputEngine.Listener? = null
    private var activeProfile: VoiceInputProfile? = null
    private val transcriptionEndpoint: String
        get() = providerConfig.openAi.baseUrl.trimEnd('/') + "/audio/transcriptions"

    override fun start(profile: VoiceInputProfile, listener: VoiceInputEngine.Listener) {
        if (providerConfig.openAi.apiKey.isBlank()) {
            listener.onError("OpenAI-compatible API key is missing.")
            return
        }
        if (providerConfig.openAi.model.isBlank()) {
            listener.onError("OpenAI-compatible model is missing.")
            return
        }

        runCatching {
            activeListener = listener
            activeProfile = profile
            val tempFile = File.createTempFile("shinsoku-", ".m4a", context.cacheDir)
            outputFile = tempFile
            val mediaRecorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(64_000)
                setAudioSamplingRate(16_000)
                setOutputFile(tempFile.absolutePath)
                prepare()
                start()
            }
            recorder = mediaRecorder
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
        val mediaRecorder = recorder
        if (profile == null || file == null || mediaRecorder == null) {
            listener.onError("Recording session is not active.")
            cleanupRecording(deleteFile = true)
            return
        }

        runCatching {
            mediaRecorder.stop()
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

        mediaRecorder.reset()
        mediaRecorder.release()
        recorder = null

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
        runCatching {
            recorder?.stop()
        }
        cleanupRecording(deleteFile = true)
    }

    override fun destroy() {
        cancel()
        executor.shutdownNow()
    }

    private fun transcribe(file: File, profile: VoiceInputProfile): String {
        val requestBody = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("model", providerConfig.openAi.model)
            .addFormDataPart(
                "file",
                file.name,
                file.asRequestBody("audio/mp4".toMediaType()),
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
            .addHeader("Authorization", "Bearer ${providerConfig.openAi.apiKey}")
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
        recorder?.runCatching {
            reset()
            release()
        }
        recorder = null
        activeListener = null
        activeProfile = null
        val file = outputFile
        outputFile = null
        if (deleteFile) {
            file?.delete()
        }
    }
}
