package com.shinsoku.mobile.processing

import android.content.Context
import com.shinsoku.mobile.settings.AndroidVoiceRuntimeConfigStore
import com.shinsoku.mobile.speechcore.TranscriptPostProcessingMode
import com.shinsoku.mobile.speechcore.VoiceInputProfile
import com.shinsoku.mobile.speechcore.VoiceTranscriptPostProcessor
import com.shinsoku.mobile.speechcore.VoiceTranscriptPostProcessorCallback
import okhttp3.Dns
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.Executors

class AndroidVoicePostProcessor(
    context: Context,
) : VoiceTranscriptPostProcessor {
    private val runtimeConfigStore = AndroidVoiceRuntimeConfigStore(context)
    private val executor = Executors.newSingleThreadExecutor()
    private val client = OkHttpClient.Builder()
        .dns(com.shinsoku.mobile.ime.ShinsokuDns)
        .build()

    override fun process(
        rawText: String,
        profile: VoiceInputProfile,
        callback: VoiceTranscriptPostProcessorCallback,
    ) {
        val cleaned = NativeTranscriptCleanup.cleanupTranscript(rawText)
        if (cleaned.isEmpty()) {
            callback.onSuccess("")
            return
        }

        val runtimeConfig = runtimeConfigStore.loadRuntimeConfig()
        val providerConfig = runtimeConfig.providerConfig
        if (runtimeConfig.postProcessingConfig.mode != TranscriptPostProcessingMode.ProviderAssisted) {
            callback.onSuccess(cleaned)
            return
        }

        executor.execute {
            runCatching {
                refineWithOpenAi(cleaned, providerConfig.openAi.baseUrl, providerConfig.openAi.apiKey, providerConfig.openAi.model)
            }.onSuccess { refined ->
                callback.onSuccess(refined.ifBlank { cleaned })
            }.onFailure { error ->
                android.util.Log.w(
                    "ShinsokuPostProcess",
                    "Provider-assisted post-processing failed, falling back to local cleanup",
                    error,
                )
                callback.onSuccess(cleaned)
            }
        }
    }

    private fun refineWithOpenAi(
        input: String,
        baseUrl: String,
        apiKey: String,
        model: String,
    ): String {
        val requestBody = JSONObject()
            .put("model", model.ifBlank { "gpt-5.4-nano" })
            .put(
                "messages",
                JSONArray()
                    .put(
                        JSONObject()
                            .put("role", "system")
                            .put(
                                "content",
                                "You are a transcription post-processor. Return only corrected text. Do not translate. Fix only obvious ASR typos, spacing, punctuation, and readability.",
                            ),
                    )
                    .put(
                        JSONObject()
                            .put("role", "user")
                            .put("content", input),
                    ),
            )
            .toString()

        val endpoint = baseUrl.trimEnd('/') + "/chat/completions"
        val request = Request.Builder()
            .url(endpoint)
            .addHeader("Authorization", "Bearer $apiKey")
            .post(requestBody.toRequestBody("application/json".toMediaType()))
            .build()

        client.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw IOException(body.ifBlank { "OpenAI post-processing failed with ${response.code}." })
            }
            val json = JSONObject(body)
            return json.optJSONArray("choices")
                ?.optJSONObject(0)
                ?.optJSONObject("message")
                ?.optString("content")
                ?.trim()
                .orEmpty()
        }
    }
}
